## 0.1.6
- Deprecated this package name in favor of
  `tencent_cos_cloud_storage_serverpod`
- Turn this package into a compatibility wrapper that re-exports the renamed
  package
- Add migration guidance to help existing users switch to the new package name

## 0.1.5
- **Breaking**: Separate sensitive and non-sensitive configuration
  - `CosPasswordKeys` now only contains credential keys (secretId, secretKey)
  - Non-sensitive config (bucket, region, customDomain) should be passed directly to constructor
  - Rename constructor parameter `keys` to `passwordKeys` for clarity
- Constructor now requires `bucket` and `region` as direct parameters (no longer read from passwords.yaml)

## 0.1.4
- Fix README: separate English and Chinese versions properly

## 0.1.3
- Switch README to English as default, Chinese as README.zh.md

## 0.1.2

- Update repository URL.

## 0.1.1

- Update README to bilingual (ZH/EN).

## 0.1.0

- Initial release: COS adapter for Serverpod CloudStorage.
