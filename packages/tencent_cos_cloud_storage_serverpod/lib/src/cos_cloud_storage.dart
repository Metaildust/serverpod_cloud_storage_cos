import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';
import 'package:serverpod/src/generated/cloud_storage_direct_upload.dart';
import 'package:tencent_cos_dart/tencent_cos_dart.dart';

import 'cos_upload_gate.dart';

/// Keys for sensitive COS credentials in passwords.yaml.
///
/// Only credentials that should be kept secret.
class CosPasswordKeys {
  /// Key for Tencent Cloud Secret ID.
  final String secretId;

  /// Key for Tencent Cloud Secret Key.
  final String secretKey;

  const CosPasswordKeys({
    this.secretId = 'tencentCosSecretId',
    this.secretKey = 'tencentCosSecretKey',
  });
}

/// Tencent COS storage adapter for Serverpod's CloudStorage API.
///
/// ## Recommended Usage
///
/// Pass non-sensitive config directly in constructor, only credentials from passwords.yaml:
///
/// ```dart
/// pod.addCloudStorage(
///   CosCloudStorage(
///     serverpod: pod,
///     storageId: 'public',
///     public: true,
///     bucket: 'my-bucket',           // Direct value
///     region: 'ap-guangzhou',        // Direct value
///     customDomain: 'https://cdn.example.com', // Direct value
///   ),
/// );
/// ```
///
/// ### passwords.yaml (only credentials)
///
/// ```yaml
/// shared:
///   tencentCosSecretId: 'your-secret-id'
///   tencentCosSecretKey: 'your-secret-key'
/// ```
class CosCloudStorage extends CloudStorage with CloudStorageWithOptions {
  final bool public;
  final String bucket;
  final String region;
  final String? customDomain;

  late final CosSigner _signer;

  /// Creates a COS cloud storage instance.
  ///
  /// [serverpod] Serverpod instance for reading credentials from passwords.yaml.
  /// [storageId] Unique identifier for this storage (e.g., 'public', 'private').
  /// [public] Whether files are publicly accessible.
  /// [bucket] COS bucket name. Pass directly, not from passwords.yaml.
  /// [region] COS region (e.g., 'ap-guangzhou'). Pass directly.
  /// [customDomain] Optional custom domain for public URLs. Pass directly.
  /// [passwordKeys] Keys for credential lookup in passwords.yaml.
  CosCloudStorage({
    required Serverpod serverpod,
    required String storageId,
    required this.public,
    required this.bucket,
    required this.region,
    this.customDomain,
    CosPasswordKeys passwordKeys = const CosPasswordKeys(),
  }) : super(storageId) {
    final secretId = serverpod.getPassword(passwordKeys.secretId);
    final secretKey = serverpod.getPassword(passwordKeys.secretKey);

    if (secretId == null) {
      throw StateError(
        '${passwordKeys.secretId} must be configured in passwords.yaml',
      );
    }
    if (secretKey == null) {
      throw StateError(
        '${passwordKeys.secretKey} must be configured in passwords.yaml',
      );
    }

    _bindSigner(secretId, secretKey);
  }

  /// 测试构造：不读口令文件，直接使用传入凭据。
  CosCloudStorage.test({
    required String storageId,
    required this.public,
    required this.bucket,
    required this.region,
    required String secretId,
    required String secretKey,
    this.customDomain,
  }) : super(storageId) {
    _bindSigner(secretId, secretKey);
  }

  /// 直传口令与过期都通过之后再写入。
  ///
  /// [preventOverwrite] 为真且该路径已有对象时返回 false，不覆盖原对象。
  /// 写入的对象标成未校验，要等 [verifyDirectFileUpload] 成功后才能读。
  Future<bool> acceptDirectFile({
    required Session session,
    required String path,
    required ByteData byteData,
    required bool preventOverwrite,
  }) async {
    if (preventOverwrite) {
      try {
        await _rejectIfPresent(
          path: path,
          options: const CloudStorageOptions(preventOverwrite: true),
        );
      } on CloudStorageException {
        return false;
      }
    }
    await storeFile(
      session: session,
      path: path,
      byteData: byteData,
      verified: false,
    );
    return true;
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
      final verifiedHeaders = _verifiedHeaders(verified);
      final url = _signer.generatePresignedUrl(
        'PUT',
        _normalizePath(path),
        expires: 3600,
        headers: verifiedHeaders,
      );
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/octet-stream',
          ...verifiedHeaders,
        },
        body: byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
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
        if (!_objectReadsAsVerified(response)) return null;
        return ByteData.sublistView(response.bodyBytes);
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
    try {
      final url = _signer.generatePresignedUrl(
        'HEAD',
        _normalizePath(path),
        expires: 3600,
      );
      final response = await http.head(Uri.parse(url));
      if (response.statusCode != 200) return null;
      if (!_objectReadsAsVerified(response)) return null;
      return _buildPublicUri(path);
    } catch (e) {
      throw CloudStorageException('Failed to check if file exists. ($e)');
    }
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
    return _insertDirectUpload(
      session: session,
      path: path,
      expirationDuration: expirationDuration,
      preventOverwrite: false,
    );
  }

  @override
  Future<void> storeFileWithOptions({
    required Session session,
    required String path,
    required ByteData byteData,
    DateTime? expiration,
    bool verified = true,
    required CloudStorageOptions options,
  }) async {
    await _rejectIfPresent(path: path, options: options);
    await storeFile(
      session: session,
      path: path,
      byteData: byteData,
      expiration: expiration,
      verified: verified,
    );
  }

  @override
  Future<String?> createDirectFileUploadDescriptionWithOptions({
    required Session session,
    required String path,
    Duration expirationDuration = const Duration(minutes: 10),
    int maxFileSize = 10 * 1024 * 1024,
    required CloudStorageOptions options,
  }) async {
    await _rejectIfPresent(path: path, options: options);
    return _insertDirectUpload(
      session: session,
      path: path,
      expirationDuration: expirationDuration,
      preventOverwrite: options.preventOverwrite,
    );
  }

  /// preventOverwrite 为真时拒绝覆盖。
  ///
  /// HEAD 404 才当成不存在并继续写入；200 当成已存在。
  /// 其它状态无法确认对象是否在，按失败关闭抛错，不再 PUT，也不签发直传。
  /// 给公开地址用的 [fileExists] 仍把非 200 当成不存在，不走这里。
  Future<void> _rejectIfPresent({
    required String path,
    required CloudStorageOptions options,
  }) async {
    if (!options.preventOverwrite) return;
    final status = await _headStatusForOverwrite(path);
    if (status == 404) return;
    if (status != 200) {
      throw CloudStorageException(
        'Cannot confirm whether a file exists at path "$path" '
        '(HEAD status: $status).',
      );
    }
    throw CloudStorageException(
      'File already exists at path "$path" and preventOverwrite is enabled.',
    );
  }

  /// 防覆盖专用 HEAD。不要复用 [fileExists]：那边非 200 会当成不存在。
  Future<int> _headStatusForOverwrite(String path) async {
    try {
      final url = _signer.generatePresignedUrl(
        'HEAD',
        _normalizePath(path),
        expires: 3600,
      );
      final response = await http.head(Uri.parse(url));
      return response.statusCode;
    } catch (e) {
      throw CloudStorageException(
        'Failed to check whether file exists before write. ($e)',
      );
    }
  }

  @override
  Future<bool> verifyDirectFileUpload({
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
      if (response.statusCode == 404) return false;
      if (response.statusCode != 200) {
        throw CloudStorageException(
          'Failed to verify direct upload. (status: ${response.statusCode})',
        );
      }
      if (_objectReadsAsVerified(response)) return true;
      await storeFile(
        session: session,
        path: path,
        byteData: ByteData.sublistView(response.bodyBytes),
        verified: true,
      );
      return true;
    } on CloudStorageException {
      rethrow;
    } catch (e) {
      throw CloudStorageException('Failed to verify direct upload. ($e)');
    }
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

  void _bindSigner(String secretId, String secretKey) {
    final id = secretId.trim();
    final key = secretKey.trim();
    if (id.isEmpty || key.isEmpty) {
      throw StateError(
        'COS secretId and secretKey must be non-empty after trim',
      );
    }
    _signer = CosSigner.fromConfig(
      CosConfig(
        secretId: id,
        secretKey: key,
        bucket: bucket,
        region: region,
        customDomain: customDomain,
      ),
    );
  }

  /// 未校验标记写在对象元数据上，不另开本地表。
  /// 没有该头的旧对象仍视为已校验，避免把历史文件藏起来。
  static const _verifiedHeader = 'x-cos-meta-verified';

  Map<String, String> _verifiedHeaders(bool verified) {
    return {_verifiedHeader: verified ? 'true' : 'false'};
  }

  bool _objectReadsAsVerified(http.Response response) {
    final raw = response.headers[_verifiedHeader];
    if (raw == null || raw.trim().isEmpty) return true;
    return raw.trim().toLowerCase() != 'false';
  }

  Future<String?> _insertDirectUpload({
    required Session session,
    required String path,
    required Duration expirationDuration,
    required bool preventOverwrite,
  }) async {
    final expiration = DateTime.now().toUtc().add(expirationDuration);
    final uploadEntry = CloudStorageDirectUploadEntry(
      storageId: storageId,
      path: path,
      expiration: expiration,
      authKey: buildDirectUploadAuthKey(
        preventOverwrite: preventOverwrite,
        randomKey: _generateAuthKey(),
      ),
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
