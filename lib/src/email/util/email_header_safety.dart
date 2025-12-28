import 'package:axichat/src/common/message_content_limits.dart';

final RegExp _emailHeaderCrlfPattern = RegExp(r'[\r\n]+');
const int _emailHeaderMaxBytes = 998;

String? sanitizeEmailHeaderValue(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final sanitized = trimmed.replaceAll(_emailHeaderCrlfPattern, '');
  return clampUtf8Value(sanitized, maxBytes: _emailHeaderMaxBytes);
}
