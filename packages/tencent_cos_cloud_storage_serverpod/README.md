# tencent_cos_cloud_storage_serverpod

[中文文档](README.zh.md)

Tencent COS adapter for Serverpod `CloudStorage`.

Renamed from `serverpod_cloud_storage_cos` to avoid colliding with the official
Serverpod integration package of the same name.

Compatible with Serverpod's official upload flow
(`createDirectFileUploadDescription` / `FileUploader`).

```yaml
dependencies:
  tencent_cos_cloud_storage_serverpod: ^0.2.0
```

## Configuration

### Recommended: Separate Sensitive and Non-sensitive Config

**passwords.yaml** (credentials only):

```yaml
shared:
  tencentCosSecretId: '<TENCENT_SECRET_ID>'
  tencentCosSecretKey: '<TENCENT_SECRET_KEY>'
```

**server.dart** (non-sensitive config passed directly):

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
      bucket: 'my-bucket',                    // Direct value
      region: 'ap-guangzhou',                 // Direct value
      customDomain: 'https://cdn.example.com', // Direct value (optional)
    ),
  );

  cos.registerCosCloudStorageEndpoint(pod);

  await pod.start();
}
```

### Legacy: All in passwords.yaml (still supported)

```yaml
shared:
  tencentCosSecretId: '<TENCENT_SECRET_ID>'
  tencentCosSecretKey: '<TENCENT_SECRET_KEY>'
  tencentCosBucket: '<COS_BUCKET_NAME>'
  tencentCosRegion: '<COS_REGION>'
  tencentCosCustomDomain: 'https://my-cdn.example.com' # optional
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

## Client usage

```dart
final desc = await client.myEndpoint.getUploadDescription('path/to/file.png');
if (desc != null) {
  final uploader = FileUploader(desc);
  await uploader.uploadByteData(byteData);
  await client.myEndpoint.verifyUpload('path/to/file.png');
}
```

## API Reference

### CosPasswordKeys

Customize credential keys:

```dart
CosCloudStorage(
  serverpod: pod,
  storageId: 'public',
  public: true,
  bucket: 'my-bucket',
  region: 'ap-guangzhou',
  passwordKeys: CosPasswordKeys(
    secretId: 'mySecretIdKey',   // Default: tencentCosSecretId
    secretKey: 'mySecretKeyKey', // Default: tencentCosSecretKey
  ),
)
```

## Notes
- Uses Serverpod `CloudStorage` API.
- Upload goes through a Serverpod upload endpoint, then to COS.

## Web Platform (Flutter Web) - CORS Configuration

> **Important**: If your Flutter Web client directly accesses COS URLs (e.g., displaying images), you **MUST** configure CORS on your COS bucket. Otherwise, browsers will block cross-origin requests.

### Configure CORS in Tencent Cloud Console

1. Go to [COS Console](https://console.cloud.tencent.com/cos5)
2. Select your bucket → **Security Management** → **CORS (Cross-Origin Resource Sharing)**
3. Click **Add Rule** with the following settings:

| Setting | Value |
|---------|-------|
| **Origin** | `*` (or specific domains) |
| **Methods** | `GET, POST, PUT, DELETE, HEAD` |
| **Allow-Headers** | `*` |
| **Expose-Headers** | `ETag, Content-Length` |
| **Max-Age** | `600` |

### Common Symptoms of Missing CORS

- `HTTP request failed, statusCode: 0`
- `NetworkImageLoadException` when loading images
- `DioException [connection error]`

## Maintenance
- Versioning: SemVer
- Feedback: issue / PR

## Reference
- https://docs.serverpod.dev/concepts/file-uploads
