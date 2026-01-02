import 'package:axichat/src/email/util/email_header_safety.dart';

const String emailMessageIdHeaderName = 'message-id';
const String _emailHeaderSeparator = ':';
const String _emailHeaderLineBreak = '\n';
const String _emailHeaderContinuationSeparator = ' ';
const String _emailMessageIdWrapperStart = '<';
const String _emailMessageIdWrapperEnd = '>';
const String _emailHeaderContinuationPattern = r'^[ \t]+';
const String _emailMessageIdTokenPattern = r'<([^>]+)>';
const int _emailHeaderSeparatorOffset = 1;
const int _emailMessageIdWrapperOffset = 1;
const int _emailMessageIdWrapperLength = 2;
const int _emailHeaderSeparatorMissingIndex = 0;
const int _emailNextLineOffset = 1;
const int _emailStartIndex = 0;

final RegExp _emailHeaderContinuationRegex =
    RegExp(_emailHeaderContinuationPattern);
final RegExp _emailMessageIdTokenRegex = RegExp(_emailMessageIdTokenPattern);

String? parseEmailMessageId(String? rawHeaders) {
  final sanitized = sanitizeRawEmailHeaders(rawHeaders);
  if (sanitized == null) return null;
  final lines = sanitized.split(_emailHeaderLineBreak);
  for (int index = _emailStartIndex; index < lines.length; index++) {
    final String line = lines[index];
    if (line.trim().isEmpty) continue;
    final separatorIndex = line.indexOf(_emailHeaderSeparator);
    if (separatorIndex <= _emailHeaderSeparatorMissingIndex) continue;
    final String headerName =
        line.substring(0, separatorIndex).trim().toLowerCase();
    if (headerName != emailMessageIdHeaderName) {
      continue;
    }
    String value =
        line.substring(separatorIndex + _emailHeaderSeparatorOffset).trim();
    while (index + _emailNextLineOffset < lines.length &&
        _emailHeaderContinuationRegex
            .hasMatch(lines[index + _emailNextLineOffset])) {
      value = '$value$_emailHeaderContinuationSeparator'
          '${lines[index + _emailNextLineOffset].trim()}';
      index += _emailNextLineOffset;
    }
    return normalizeEmailMessageId(value);
  }
  return null;
}

String? normalizeEmailMessageId(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final token = _extractMessageIdToken(trimmed);
  final normalized = token.trim();
  if (normalized.isEmpty) return null;
  return normalized.toLowerCase();
}

String _extractMessageIdToken(String value) {
  final match = _emailMessageIdTokenRegex.firstMatch(value);
  if (match != null) {
    final candidate = match.group(1);
    if (candidate != null && candidate.trim().isNotEmpty) {
      return candidate;
    }
  }
  final startsWithWrapper = value.startsWith(_emailMessageIdWrapperStart);
  final endsWithWrapper = value.endsWith(_emailMessageIdWrapperEnd);
  if (startsWithWrapper &&
      endsWithWrapper &&
      value.length > _emailMessageIdWrapperLength) {
    return value.substring(
      _emailMessageIdWrapperOffset,
      value.length - _emailMessageIdWrapperOffset,
    );
  }
  return value;
}
