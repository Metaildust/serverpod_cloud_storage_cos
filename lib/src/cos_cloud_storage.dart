import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';
import 'package:serverpod/src/generated/cloud_storage_direct_upload.dart';
import 'package:tencent_cos_dart/tencent_cos_dart.dart';

import 'cos_upload_endpoint.dart';

class CosPasswordKeys {
  final String secretId;
  final String secretKey;
  final String bucket;
  final String region;
  final String customDomain;

  const CosPasswordKeys({
    this.secretId = 'tencentCosSecretId',
    this.secretKey = 'tencentCosSecretKey',
    this.bucket = 'tencentCosBucket',
    this.region = 'tencentCosRegion',
    this.customDomain = 'tencentCosCustomDomain',
  });
}

/// Tencent COS storage adapter for Serverpod's CloudStorage API.
class CosCloudStorage extends CloudStorage {
  final bool public;
  final String bucket;
  final String region;
  final String? customDomain;

  late final CosSigner _signer;

  CosCloudStorage({
    required Serverpod serverpod,
    required String storageId,
    required this.public,
    required this.region,
    required this.bucket,
    this.customDomain,
    CosPasswordKeys keys = const CosPasswordKeys(),
  }) : super(storageId) {
    final secretId = serverpod.getPassword(keys.secretId);
    final secretKey = serverpod.getPassword(keys.secretKey);
    final cfgBucket = serverpod.getPassword(keys.bucket) ?? bucket;
    final cfgRegion = serverpod.getPassword(keys.region) ?? region;
    final cfgCustomDomain = serverpod.getPassword(keys.customDomain);

    if (secretId == null) {
      throw StateError('${keys.secretId} must be configured in passwords.');
    }
    if (secretKey == null) {
      throw StateError('${keys.secretKey} must be configured in passwords.');
    }

    _signer = CosSigner.fromConfig(
      CosConfig(
        secretId: secretId,
        secretKey: secretKey,
        bucket: cfgBucket,
        region: cfgRegion,
        customDomain: cfgCustomDomain ?? customDomain,
      ),
    );
  }

  @override
  Future<void> storeFile({
    required Session session,
    required String path,
    required ByteData byteData,
    DateTime? expiration,
    bool verified = true,
  }) async {
    try {
      final url = _signer.generatePresignedUrl(
        'PUT',
        _normalizePath(path),
        expires: 3600,
      );
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/octet-stream'},
        body: byteData.buffer.asUint8List(),
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw CloudStorageException(
          'Failed to store file. (status: ${response.statusCode})',
        );
      }
    } catch (e) {
      throw CloudStorageException('Failed to store file. ($e)');
    }
  }

  @override
  Future<ByteData?> retrieveFile({
    required Session session,
    required String path,
  }) async {
    try {
      final url = _signer.generatePresignedUrl(
        'GET',
        _normalizePath(path),
        expires: 3600,
      );
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return ByteData.view(response.bodyBytes.buffer);
      }
      return null;
    } catch (e) {
      throw CloudStorageException('Failed to retrieve file. ($e)');
    }
  }

  @override
  Future<Uri?> getPublicUrl({
    required Session session,
    required String path,
  }) async {
    if (!public) return null;
    if (!await fileExists(session: session, path: path)) return null;
    return _buildPublicUri(path);
  }

  @override
  Future<bool> fileExists({
    required Session session,
    required String path,
  }) async {
    try {
      final url = _signer.generatePresignedUrl(
        'HEAD',
        _normalizePath(path),
        expires: 3600,
      );
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      throw CloudStorageException('Failed to check if file exists. ($e)');
    }
  }

  @override
  Future<void> deleteFile({
    required Session session,
    required String path,
  }) async {
    try {
      final url = _signer.generatePresignedUrl(
        'DELETE',
        _normalizePath(path),
        expires: 3600,
      );
      final response = await http.delete(Uri.parse(url));
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw CloudStorageException(
          'Failed to delete file. (status: ${response.statusCode})',
        );
      }
    } catch (e) {
      throw CloudStorageException('Failed to delete file. ($e)');
    }
  }

  @override
  Future<String?> createDirectFileUploadDescription({
    required Session session,
    required String path,
    Duration expirationDuration = const Duration(minutes: 10),
    int maxFileSize = 10 * 1024 * 1024,
  }) async {
    final expiration = DateTime.now().toUtc().add(expirationDuration);

    final uploadEntry = CloudStorageDirectUploadEntry(
      storageId: storageId,
      path: path,
      expiration: expiration,
      authKey: _generateAuthKey(),
    );
    final inserted = await CloudStorageDirectUploadEntry.db.insertRow(
      session,
      uploadEntry,
    );

    final config = session.server.serverpod.config;
    final uri = Uri(
      scheme: config.apiServer.publicScheme,
      host: config.apiServer.publicHost,
      port: config.apiServer.publicPort,
      path: '/$cosUploadEndpointName',
      queryParameters: {
        'method': 'upload',
        'storage': storageId,
        'path': path,
        'key': inserted.authKey,
      },
    );

    final uploadDescriptionData = {'url': uri.toString(), 'type': 'binary'};

    return SerializationManager.encode(uploadDescriptionData);
  }

  @override
  Future<bool> verifyDirectFileUpload({
    required Session session,
    required String path,
  }) async {
    return fileExists(session: session, path: path);
  }

  Uri _buildPublicUri(String path) {
    final normalizedPath = _normalizePath(path);
    final raw = customDomain;
    if (raw != null && raw.trim().isNotEmpty) {
      final trimmed = raw.trim();
      final parsed = Uri.tryParse(trimmed);
      if (parsed != null && parsed.host.isNotEmpty) {
        final scheme = parsed.scheme.isEmpty ? 'https' : parsed.scheme;
        return Uri(
          scheme: scheme,
          host: parsed.host,
          port: parsed.hasPort ? parsed.port : null,
          path: '/$normalizedPath',
        );
      }
      return Uri(scheme: 'https', host: trimmed, path: '/$normalizedPath');
    }

    return Uri(
      scheme: 'https',
      host: '$bucket.cos.$region.myqcloud.com',
      path: '/$normalizedPath',
    );
  }

  String _normalizePath(String path) {
    if (path.startsWith('/')) return path.substring(1);
    return path;
  }

  static String _generateAuthKey() {
    const len = 16;
    const chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(
        len,
        (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
      ),
    );
  }
}
