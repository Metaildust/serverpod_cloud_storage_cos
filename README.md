# serverpod_cloud_storage_cos

[中文文档](README.zh.md)

Tencent COS adapter for Serverpod `CloudStorage`.

Compatible with Serverpod's official upload flow
(`createDirectFileUploadDescription` / `FileUploader`).

```yaml
dependencies:
  serverpod_cloud_storage_cos: ^0.1.4
```

## passwords.yaml

Add COS credentials in `config/passwords.yaml`:

```yaml
shared:
  tencentCosSecretId: '<TENCENT_SECRET_ID>'
  tencentCosSecretKey: '<TENCENT_SECRET_KEY>'
  tencentCosBucket: '<COS_BUCKET_NAME>'
  tencentCosRegion: '<COS_REGION>'
  tencentCosCustomDomain: 'https://my-cdn.example.com' # optional
```

## server.dart

```dart
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_cloud_storage_cos/serverpod_cloud_storage_cos.dart'
    as cos;

void run(List<String> args) async {
  final pod = Serverpod(args, Protocol(), Endpoints());

  final cosBucket = pod.getPassword('tencentCosBucket');
  if (cosBucket == null || cosBucket.isEmpty) {
    throw StateError('tencentCosBucket must be configured in passwords.');
  }

  pod.addCloudStorage(
    cos.CosCloudStorage(
      serverpod: pod,
      storageId: 'public',
      public: true,
      region: pod.getPassword('tencentCosRegion') ?? 'ap-guangzhou',
      bucket: cosBucket,
      customDomain: pod.getPassword('tencentCosCustomDomain'),
    ),
  );

  cos.registerCosCloudStorageEndpoint(pod);

  await pod.start();
}
```

## Client usage

```dart
final desc = await client.myEndpoint.getUploadDescription('path/to/file.png');
if (desc != null) {
  final uploader = FileUploader(desc);
  await uploader.uploadByteData(byteData);
  await client.myEndpoint.verifyUpload('path/to/file.png');
}
```

## Notes
- Uses Serverpod `CloudStorage` API.
- Upload goes through a Serverpod upload endpoint, then to COS.

## Maintenance
- Versioning: SemVer
- Feedback: issue / PR

## Reference
- https://docs.serverpod.dev/concepts/file-uploads
