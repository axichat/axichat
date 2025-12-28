final RegExp _emailHeaderCrlfPattern = RegExp(r'[\r\n]+');
const int _emailHeaderMaxLength = 998;
const int _emailHeaderSubstringStart = 0;

String? sanitizeEmailHeaderValue(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final sanitized = trimmed.replaceAll(_emailHeaderCrlfPattern, '');
  if (sanitized.length > _emailHeaderMaxLength) {
    return sanitized.substring(
        _emailHeaderSubstringStart, _emailHeaderMaxLength);
  }
  return sanitized;
}
