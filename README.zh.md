# serverpod_cloud_storage_cos

[English](README.md)

Serverpod `CloudStorage` 接口的腾讯云 COS 实现。

兼容 Serverpod 官方上传流程（`createDirectFileUploadDescription` / `FileUploader`）。

```yaml
dependencies:
  serverpod_cloud_storage_cos: ^0.1.0
```

## passwords.yaml 配置

在 `config/passwords.yaml` 中添加 COS 凭据：

```yaml
shared:
  tencentCosSecretId: '<TENCENT_SECRET_ID>'
  tencentCosSecretKey: '<TENCENT_SECRET_KEY>'
  tencentCosBucket: '<COS_BUCKET_NAME>'
  tencentCosRegion: '<COS_REGION>'
  tencentCosCustomDomain: 'https://my-cdn.example.com' # 可选
```

## 权限说明

您的腾讯云凭据需要 Put、Get 和 Delete 对象的权限。

```json
{
    "version": "2.0",
    "statement": [
        {
            "effect": "allow",
            "action": [
                "name/cos:PutObject",
                "name/cos:GetObject",
                "name/cos:DeleteObject",
                "name/cos:HeadObject"
            ],
            "resource": [
                "qcs::cos:ap-guangzhou:uid/1250000000:examplebucket-1250000000/*"
            ]
        }
    ]
}
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

  // 必须注册端点
  cos.registerCosCloudStorageEndpoint(pod);

  await pod.start();
}
```

## 客户端使用

```dart
final desc = await client.myEndpoint.getUploadDescription('path/to/file.png');
if (desc != null) {
  final uploader = FileUploader(desc);
  await uploader.uploadByteData(byteData);
  await client.myEndpoint.verifyUpload('path/to/file.png');
}
```

## 说明
- 使用 Serverpod `CloudStorage` API
- 上传会先到服务端上传端点，再写入 COS

## 维护
- 版本：SemVer
- 反馈：issue / PR

## 参考
- https://docs.serverpod.dev/concepts/file-uploads
