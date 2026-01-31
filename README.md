# serverpod_cloud_storage_cos

Tencent COS adapter for Serverpod `CloudStorage`.
把腾讯云 COS 接入 Serverpod 官方 `CloudStorage` 接口的适配包。

Compatible with Serverpod official upload flow
(`createDirectFileUploadDescription` / `FileUploader`).
兼容 Serverpod 官方文件上传流程（`createDirectFileUploadDescription` / `FileUploader`）。

```yaml
dependencies:
  serverpod_cloud_storage_cos: ^0.1.0
```

## passwords.yaml / 配置

```yaml
shared:
  tencentCosSecretId: '<TENCENT_SECRET_ID>'
  tencentCosSecretKey: '<TENCENT_SECRET_KEY>'
  tencentCosBucket: '<COS_BUCKET_NAME>'
  tencentCosRegion: '<COS_REGION>'
  tencentCosCustomDomain: 'https://my-cdn.example.com' # optional / 可选
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

  // required / 必须
  cos.registerCosCloudStorageEndpoint(pod);

  await pod.start();
}
```

## Client usage / 客户端使用

```dart
final desc = await client.myEndpoint.getUploadDescription('path/to/file.png');
if (desc != null) {
  final uploader = FileUploader(desc);
  await uploader.uploadByteData(byteData);
  await client.myEndpoint.verifyUpload('path/to/file.png');
}
```

## Notes / 说明
- Uses Serverpod `CloudStorage` API.
- Upload goes through Serverpod endpoint, then to COS.
- 这是对 Serverpod 官方 `CloudStorage` 的兼容实现。
- 上传会先到服务端上传端点，再写入 COS。

## Maintenance / 维护
- Versioning: SemVer
- Feedback: issue / PR

## Reference / 参考
- https://docs.serverpod.dev/concepts/file-uploads
