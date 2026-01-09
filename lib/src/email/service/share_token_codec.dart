// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math';

class ShareTokenParseResult {
  const ShareTokenParseResult({
    required this.token,
    required this.cleanedBody,
  });

  final String token;
  final String cleanedBody;
}

class ShareTokenCodec {
  static const int _minCapabilityLength = 16;
  static const int _maxCapabilityLength = 64;
  static const String _secureRandomUnavailableMessage =
      'Secure random unavailable for share token generation.';
  static final RegExp _pattern = RegExp(
    '^\\s*\\[s:([A-Z0-9]{$_minCapabilityLength,$_maxCapabilityLength})\\]\\s*',
    caseSensitive: false,
  );
  static final RegExp _footerPattern = RegExp(
    '^(.*?)(?:\\n\\n)?(?:--\\s*\\n)?\\s*Please do not remove:\\s*\\[s:'
    '([A-Z0-9]{$_minCapabilityLength,$_maxCapabilityLength})\\]\\s*\$',
    dotAll: true,
    caseSensitive: false,
  );
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static final Random _random = _secureRandom();

  static Random _secureRandom() {
    try {
      return Random.secure();
    } on UnsupportedError {
      throw StateError(_secureRandomUnavailableMessage);
    }
  }

  static String generateShareId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final timePart = _encodeInt(timestamp, 10);
    final randomPart = List<int>.generate(16, (_) => _random.nextInt(32));
    final buffer = StringBuffer();
    for (final index in [...timePart, ...randomPart]) {
      buffer.write(_alphabet[index]);
    }
    return buffer.toString();
  }

  static List<int> _encodeInt(int value, int length) {
    final buffer = List<int>.filled(length, 0);
    var remaining = value;
    for (var i = length - 1; i >= 0; i--) {
      buffer[i] = remaining % 32;
      remaining ~/= 32;
    }
    return buffer;
  }

  static String subjectToken(String shareId) {
    final normalized =
        shareId.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    if (normalized.length < _minCapabilityLength) {
      throw ArgumentError(
        'shareId must contain at least $_minCapabilityLength base32 characters.',
      );
    }
    if (normalized.length > _maxCapabilityLength) {
      return normalized.substring(0, _maxCapabilityLength);
    }
    return normalized;
  }

  static String decorateToken(String token) => '[s:${token.toUpperCase()}]';

  static String _decorateFooter(String token) =>
      'Please do not remove: ${decorateToken(token)}';

  static String injectToken({
    required String token,
    required String body,
    bool asSignature = false,
  }) {
    if (asSignature) {
      final trimmed = body.trimRight();
      final buffer = StringBuffer()..write(trimmed);
      if (trimmed.isNotEmpty) {
        buffer.write('\n\n');
      }
      buffer.writeln(_decorateFooter(token));
      return buffer.toString().trimRight();
    }
    if (body.trim().isEmpty) {
      return decorateToken(token);
    }
    return '${decorateToken(token)} ${body.trim()}';
  }

  static ShareTokenParseResult? stripToken(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = _pattern.firstMatch(text);
    if (match != null) {
      final token = match.group(1)!.toUpperCase();
      final cleaned = text.substring(match.end);
      return ShareTokenParseResult(
        token: token,
        cleanedBody: cleaned.trimLeft(),
      );
    }
    final footerMatch = _footerPattern.firstMatch(text);
    if (footerMatch != null) {
      final token = footerMatch.group(2)!.toUpperCase();
      final cleaned = footerMatch.group(1) ?? '';
      return ShareTokenParseResult(
        token: token,
        cleanedBody: cleaned.trimRight(),
      );
    }
    return null;
  }
}
