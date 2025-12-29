import 'package:axichat/src/common/unicode_safety.dart';
import 'package:path/path.dart' as p;

const String _posixPathSeparator = '/';
const String _windowsPathSeparator = '\\';
const int _minFileNameLength = 1;
const int _substringStartIndex = 0;

String sanitizeAttachmentFileName({
  required String? rawName,
  required String fallbackName,
  required int maxLength,
}) {
  final candidate = _resolveCandidate(
    rawName: rawName,
    fallbackName: fallbackName,
  );
  final sanitizedCandidate = _sanitizeBaseName(candidate);
  final sanitizedFallback = _sanitizeBaseName(fallbackName);
  final resolved =
      sanitizedCandidate.isNotEmpty ? sanitizedCandidate : sanitizedFallback;
  final safeName = resolved.isNotEmpty ? resolved : fallbackName;
  return _truncateFileName(
    name: safeName,
    maxLength: maxLength,
  );
}

String _resolveCandidate({
  required String? rawName,
  required String fallbackName,
}) {
  final trimmed = rawName?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    return trimmed;
  }
  return fallbackName;
}

String _sanitizeBaseName(String name) {
  final normalized = _normalizePathSeparators(name).trim();
  final baseName = p.posix.basename(normalized).trim();
  return sanitizeUnicodeControls(baseName).value.trim();
}

String _normalizePathSeparators(String name) =>
    name.replaceAll(_windowsPathSeparator, _posixPathSeparator);

String _truncateFileName({
  required String name,
  required int maxLength,
}) {
  final safeMaxLength =
      maxLength < _minFileNameLength ? _minFileNameLength : maxLength;
  if (name.length <= safeMaxLength) {
    return name;
  }
  final extension = p.extension(name);
  if (extension.isEmpty || extension.length >= safeMaxLength) {
    return name.substring(_substringStartIndex, safeMaxLength);
  }
  final maxBaseLength = safeMaxLength - extension.length;
  final base = name.substring(_substringStartIndex, maxBaseLength);
  return '$base$extension';
}
