# tencent_cos_cloud_storage_serverpod

[English](README.md)

Serverpod `CloudStorage` 接口的腾讯云 COS 实现。

本包已从 `serverpod_cloud_storage_cos` 改名，
以避免与官方同名集成包发生冲突。

兼容 Serverpod 官方上传流程（`createDirectFileUploadDescription` / `FileUploader`）。

```yaml
dependencies:
  tencent_cos_cloud_storage_serverpod: ^0.2.0
```

## 配置

### 推荐：分离敏感和非敏感配置

**passwords.yaml**（仅凭据）：

```yaml
shared:
  tencentCosSecretId: '<TENCENT_SECRET_ID>'
  tencentCosSecretKey: '<TENCENT_SECRET_KEY>'
```

**server.dart**（非敏感配置直接传入）：

```dart
import 'package:serverpod/serverpod.dart';
import 'package:tencent_cos_cloud_storage_serverpod/tencent_cos_cloud_storage_serverpod.dart'
    as cos;

void run(List<String> args) async {
  final pod = Serverpod(args, Protocol(), Endpoints());

  pod.addCloudStorage(
    cos.CosCloudStorage(
      serverpod: pod,
      storageId: 'public',
      public: true,
      bucket: 'my-bucket',                    // 直接传入
      region: 'ap-guangzhou',                 // 直接传入
      customDomain: 'https://cdn.example.com', // 直接传入（可选）
    ),
  );

  cos.registerCosCloudStorageEndpoint(pod);

  await pod.start();
}
```

### 旧方式：全部放在 passwords.yaml（仍支持）

```yaml
shared:
  tencentCosSecretId: '<TENCENT_SECRET_ID>'
  tencentCosSecretKey: '<TENCENT_SECRET_KEY>'
  tencentCosBucket: '<COS_BUCKET_NAME>'
  tencentCosRegion: '<COS_REGION>'
  tencentCosCustomDomain: 'https://my-cdn.example.com' # 可选
```

```dart
final cosBucket = pod.getPassword('tencentCosBucket')!;

pod.addCloudStorage(
  cos.CosCloudStorage(
    serverpod: pod,
    storageId: 'public',
    public: true,
    bucket: cosBucket,
    region: pod.getPassword('tencentCosRegion') ?? 'ap-guangzhou',
    customDomain: pod.getPassword('tencentCosCustomDomain'),
  ),
);
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

## 客户端使用

```dart
final desc = await client.myEndpoint.getUploadDescription('path/to/file.png');
if (desc != null) {
  final uploader = FileUploader(desc);
  await uploader.uploadByteData(byteData);
  await client.myEndpoint.verifyUpload('path/to/file.png');
}
```

## API 参考

### CosPasswordKeys

自定义凭据键名：

```dart
CosCloudStorage(
  serverpod: pod,
  storageId: 'public',
  public: true,
  bucket: 'my-bucket',
  region: 'ap-guangzhou',
  passwordKeys: CosPasswordKeys(
    secretId: 'mySecretIdKey',   // 默认: tencentCosSecretId
    secretKey: 'mySecretKeyKey', // 默认: tencentCosSecretKey
  ),
)
```

## 说明
- 使用 Serverpod `CloudStorage` API
- 上传会先到服务端上传端点，再写入 COS

## Web 平台（Flutter Web）- CORS 跨域配置

> **重要提示**：如果您的 Flutter Web 客户端直接访问 COS URL（例如显示图片），**必须**在 COS 存储桶上配置 CORS。否则浏览器会阻止跨域请求。

### 在腾讯云控制台配置 CORS

1. 进入 [COS 控制台](https://console.cloud.tencent.com/cos5)
2. 选择存储桶 → **安全管理** → **跨域访问 CORS 设置**
3. 点击 **添加规则**，按以下配置：

| 配置项 | 值 |
|--------|-----|
| **来源 Origin** | `*`（或指定域名） |
| **操作 Methods** | `GET, POST, PUT, DELETE, HEAD` |
| **Allow-Headers** | `*` |
| **Expose-Headers** | `ETag, Content-Length` |
| **Max-Age** | `600` |

### 缺少 CORS 配置的常见症状

- `HTTP request failed, statusCode: 0`
- `NetworkImageLoadException`（加载图片时）
- `DioException [connection error]`

## 维护
- 版本：SemVer
- 反馈：issue / PR

## 参考
- https://docs.serverpod.dev/concepts/file-uploads
