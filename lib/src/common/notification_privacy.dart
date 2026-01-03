// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

const int _notificationPreviewMaxLength = 160;
const int _notificationTokenMinLength = 20;
const int _notificationHexTokenMinLength = 32;
const int _notificationNumericTokenMinLength = 6;
const String _notificationLinkPlaceholder = '[link]';
const String _notificationTokenPlaceholder = '[redacted]';
const String _notificationWhitespaceReplacement = ' ';
const String _notificationTruncationSuffix = '...';
const String _notificationUrlPattern =
    r'((https?:\/\/|mailto:|xmpp:|www\.)[^\s<>()\[\]{}]+)';
const String _notificationTokenPattern = r'\b[A-Za-z0-9+/_-]+\b';
const String _notificationHexTokenPattern = r'\b[A-Fa-f0-9]+\b';
const String _notificationNumericTokenPattern = r'\b\d+\b';
const String _notificationWhitespacePattern = r'\s+';

final RegExp _notificationUrlRegex = RegExp(
  _notificationUrlPattern,
  caseSensitive: false,
);
final RegExp _notificationTokenRegex = RegExp(_notificationTokenPattern);
final RegExp _notificationHexTokenRegex = RegExp(_notificationHexTokenPattern);
final RegExp _notificationNumericTokenRegex = RegExp(
  _notificationNumericTokenPattern,
);
final RegExp _notificationWhitespaceRegex = RegExp(
  _notificationWhitespacePattern,
);

String? sanitizeNotificationPreview(String? body) {
  final String trimmed = body?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  String sanitized = trimmed.replaceAll(
    _notificationWhitespaceRegex,
    _notificationWhitespaceReplacement,
  );
  sanitized = sanitized.replaceAllMapped(
    _notificationUrlRegex,
    (_) => _notificationLinkPlaceholder,
  );
  sanitized = _redactLongTokens(
    sanitized,
    pattern: _notificationHexTokenRegex,
    minLength: _notificationHexTokenMinLength,
  );
  sanitized = _redactLongTokens(
    sanitized,
    pattern: _notificationTokenRegex,
    minLength: _notificationTokenMinLength,
  );
  sanitized = _redactLongTokens(
    sanitized,
    pattern: _notificationNumericTokenRegex,
    minLength: _notificationNumericTokenMinLength,
  );
  sanitized = sanitized
      .replaceAll(
          _notificationWhitespaceRegex, _notificationWhitespaceReplacement)
      .trim();
  if (sanitized.isEmpty) return null;
  if (sanitized.length <= _notificationPreviewMaxLength) {
    return sanitized;
  }
  final String truncated =
      sanitized.substring(0, _notificationPreviewMaxLength).trimRight();
  if (truncated.isEmpty) return null;
  return '$truncated$_notificationTruncationSuffix';
}

String _redactLongTokens(
  String input, {
  required RegExp pattern,
  required int minLength,
}) {
  return input.replaceAllMapped(pattern, (match) {
    final value = match.group(0) ?? '';
    if (value.length < minLength) {
      return value;
    }
    return _notificationTokenPlaceholder;
  });
}
