/// 直传完成端点的路径名。
const cosUploadEndpointName = 'serverpod_cos_storage';

/// 口令不匹配或已过期时不得删除上传条目。
bool mayDeleteDirectUploadEntry({
  required bool found,
  required bool keyMatches,
  required bool expired,
}) {
  return found && keyMatches && !expired;
}

/// 完成时是否禁止覆盖。
///
/// 只看口令记下的选择：`ow1-` 禁止覆盖，`ow0-` 允许覆盖。
/// 没有 `ow0-` 或 `ow1-` 前缀的旧口令，完成时不查覆盖。
bool directUploadPreventsOverwrite(String authKey) {
  return authKey.startsWith('ow1-');
}

/// 生成带覆盖标记的直传口令。
String buildDirectUploadAuthKey({
  required bool preventOverwrite,
  required String randomKey,
}) {
  final flag = preventOverwrite ? '1' : '0';
  return 'ow$flag-$randomKey';
}
