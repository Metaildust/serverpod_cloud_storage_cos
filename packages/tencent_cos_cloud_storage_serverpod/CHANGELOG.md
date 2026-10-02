## 0.2.1

- Honor `CloudStorageOptions.preventOverwrite`: an existing object fails the
  upload and no overwrite is sent or signed
- When `preventOverwrite` is set, a HEAD response other than 404 or 200 fails
  closed instead of continuing the upload or signing a direct upload
- Trim `secretId` and `secretKey` before use. Blank credentials after trim are
  a configuration error
- Check overwrite again when a direct upload finishes, after the token and
  expiry checks pass. A rejected finish leaves the existing object in place.
  A bad token or an expired token does not delete the upload entry
- Objects stored as unverified cannot be read or given a public URL until
  `verifyDirectFileUpload` succeeds
- `storeFile` uploads only the `ByteData` view, not bytes outside that view
- Require `serverpod` 3.4.1 or newer

## 0.2.0
- **Breaking**: Rename package from `serverpod_cloud_storage_cos` to
  `tencent_cos_cloud_storage_serverpod`
- Keep the same `CosCloudStorage` API while avoiding name collision with the
  official Serverpod integration package

## 0.1.5
- **Breaking**: Separate sensitive and non-sensitive configuration
  - `CosPasswordKeys` now only contains credential keys (secretId, secretKey)
  - Non-sensitive config (bucket, region, customDomain) should be passed directly
    to constructor
  - Rename constructor parameter `keys` to `passwordKeys` for clarity
- Constructor now requires `bucket` and `region` as direct parameters (no longer
  read from passwords.yaml)

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
