# serverpod_cloud_storage_cos

> **Deprecated**
>
> This community package has been renamed to
> [`tencent_cos_cloud_storage_serverpod`](https://pub.dev/packages/tencent_cos_cloud_storage_serverpod).
> Please migrate to the new package name.
>
> This rename avoids confusion with the official Serverpod integration package
> using the same `serverpod_cloud_storage_cos` name.

[中文文档](README.zh.md)

This package is now a compatibility wrapper that re-exports
`tencent_cos_cloud_storage_serverpod`.

```yaml
dependencies:
  tencent_cos_cloud_storage_serverpod: ^0.2.0
```

## Migration

1. Replace the dependency name:

```yaml
dependencies:
  tencent_cos_cloud_storage_serverpod: ^0.2.0
```

2. Replace imports:

```dart
import 'package:tencent_cos_cloud_storage_serverpod/tencent_cos_cloud_storage_serverpod.dart';
```

3. Keep using the same public API such as `CosCloudStorage` and
   `registerCosCloudStorageEndpoint`.

## Compatibility

Existing imports from this deprecated package continue to work for now because
this package re-exports the new package.

See the new package page for the full documentation and examples.
