# serverpod_cloud_storage_cos

> **已弃用**
>
> 这个社区包已经改名为
> [`tencent_cos_cloud_storage_serverpod`](https://pub.dev/packages/tencent_cos_cloud_storage_serverpod)。
> 请尽快迁移到新包名。
>
> 这次改名是为了避免与官方同名的 `serverpod_cloud_storage_cos`
> 集成包发生混淆。

[English](README.md)

本包现在只是一个兼容壳层，会重新导出
`tencent_cos_cloud_storage_serverpod`。

```yaml
dependencies:
  tencent_cos_cloud_storage_serverpod: ^0.2.0
```

## 迁移步骤

1. 把依赖名改成：

```yaml
dependencies:
  tencent_cos_cloud_storage_serverpod: ^0.2.0
```

2. 把 import 改成：

```dart
import 'package:tencent_cos_cloud_storage_serverpod/tencent_cos_cloud_storage_serverpod.dart';
```

3. 其余公开 API 例如 `CosCloudStorage`、
   `registerCosCloudStorageEndpoint` 可以继续原样使用。

## 兼容性说明

当前旧包仍然会继续工作，因为它会重新导出新包。

完整文档和后续更新请查看新包页面。
