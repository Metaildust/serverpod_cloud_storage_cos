import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod/src/generated/cloud_storage_direct_upload.dart';

const cosUploadEndpointName = 'serverpod_cos_storage';

/// Direct upload endpoint for COS-backed CloudStorage.
@doNotGenerate
class CosCloudStorageUploadEndpoint extends Endpoint {
  @override
  bool get sendAsRaw => true;

  Future<bool> upload(
    MethodCallSession session,
    String storageId,
    String path,
    String key,
  ) async {
    var uploadInfo = await CloudStorageDirectUploadEntry.db.findFirstRow(
      session,
      where: (t) => t.storageId.equals(storageId) & t.path.equals(path),
    );

    if (uploadInfo == null) return false;

    await CloudStorageDirectUploadEntry.db.deleteRow(session, uploadInfo);

    if (uploadInfo.authKey != key) return false;
    if (uploadInfo.expiration.isBefore(DateTime.now().toUtc())) {
      return false;
    }

    var body = await _readBinaryBody(session.request);
    if (body == null) return false;

    var byteData = ByteData.sublistView(body);

    var storage = server.serverpod.storage[storageId];
    if (storage == null) return false;

    await storage.storeFile(
      session: session,
      path: path,
      byteData: byteData,
      verified: false,
    );

    return true;
  }

  Future<Uint8List?> _readBinaryBody(Request request) async {
    int len = 0;
    var builder = BytesBuilder(copy: false);

    await for (var chunk in request.read()) {
      len += chunk.length;
      if (len > server.serverpod.config.maxRequestSize) return null;
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// Registers the endpoint with the Serverpod by manually adding an
  /// [EndpointConnector].
  void register(Serverpod serverpod) {
    initialize(serverpod.server, cosUploadEndpointName, null);

    serverpod.endpoints.connectors[cosUploadEndpointName] = EndpointConnector(
      name: cosUploadEndpointName,
      endpoint: this,
      methodConnectors: {
        'upload': MethodConnector(
          name: name,
          params: {
            'storage': ParameterDescription(
              name: 'storage',
              type: String,
              nullable: false,
            ),
            'path': ParameterDescription(
              name: 'path',
              type: String,
              nullable: false,
            ),
            'key': ParameterDescription(
              name: 'key',
              type: String,
              nullable: false,
            ),
          },
          call: (Session session, Map<String, dynamic> params) async {
            return upload(
              session as MethodCallSession,
              params['storage'],
              params['path'],
              params['key'],
            );
          },
        ),
      },
    );
  }
}

void registerCosCloudStorageEndpoint(Serverpod serverpod) {
  CosCloudStorageUploadEndpoint().register(serverpod);
}
