import 'package:axichat/src/common/message_content_limits.dart';
import 'package:path/path.dart' as p;

final RegExp _emailHeaderCrlfPattern = RegExp(r'[\r\n]+');
final RegExp _emailFilenameSeparatorPattern = RegExp(r'[\\/]');
final RegExp _emailFilenameWhitespacePattern = RegExp(r'\s+');
final RegExp _emailFilenameUnsafePattern =
    RegExp(r'[^a-zA-Z0-9._() \[\]-]');
final RegExp _emailMimeTypePattern = RegExp(
  r'^[a-z0-9][a-z0-9!#$&^_.+-]*/[a-z0-9][a-z0-9!#$&^_.+-]*$',
);
const int _emailHeaderMaxBytes = 998;
const int _emailAttachmentFilenameMaxBytes = 120;
const int _emailMimeTypeMaxBytes = 128;
const String _emailAttachmentFilenameFallback = 'attachment';

String? sanitizeEmailHeaderValue(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final sanitized = trimmed.replaceAll(_emailHeaderCrlfPattern, '');
  return clampUtf8Value(sanitized, maxBytes: _emailHeaderMaxBytes);
}

String sanitizeEmailAttachmentFilename(
  String? value, {
  String? fallbackPath,
  String fallbackName = _emailAttachmentFilenameFallback,
}) {
  final sanitized = sanitizeEmailHeaderValue(value);
  final fallbackCandidate = fallbackPath == null || fallbackPath.trim().isEmpty
      ? null
      : p.basename(fallbackPath.trim());
  final candidate = sanitized?.isNotEmpty == true
      ? sanitized!
      : (fallbackCandidate ?? '');
  final base = p.basename(candidate).trim();
  final stripped = base.replaceAll(_emailFilenameSeparatorPattern, '_');
  final collapsed =
      stripped.replaceAll(_emailFilenameWhitespacePattern, ' ').trim();
  if (collapsed.isEmpty) {
    return fallbackName;
  }
  final safe = collapsed.replaceAll(_emailFilenameUnsafePattern, '_').trim();
  if (safe.isEmpty) {
    return fallbackName;
  }
  final clamped = clampUtf8Value(
    safe,
    maxBytes: _emailAttachmentFilenameMaxBytes,
  );
  if (clamped == null || clamped.trim().isEmpty) {
    return fallbackName;
  }
  return clamped;
}

String? sanitizeEmailMimeType(String? value) {
  final sanitized = sanitizeEmailHeaderValue(value);
  if (sanitized == null) return null;
  final trimmed = sanitized.trim().toLowerCase();
  if (trimmed.isEmpty) return null;
  if (trimmed.length > _emailMimeTypeMaxBytes) {
    return null;
  }
  if (!_emailMimeTypePattern.hasMatch(trimmed)) {
    return null;
  }
  return trimmed;
}
