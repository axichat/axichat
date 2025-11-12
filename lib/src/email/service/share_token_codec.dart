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
  static final RegExp _pattern =
      RegExp(r'^\s*\[s:([A-Z0-9]{4,8})\]\s*', caseSensitive: false);
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static final Random _random = _secureRandom();

  static Random _secureRandom() {
    try {
      return Random.secure();
    } on UnsupportedError {
      return Random();
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
    final normalized = shareId.replaceAll('-', '').toUpperCase();
    return normalized.length <= 4 ? normalized : normalized.substring(0, 4);
  }

  static String decorateToken(String token) => '[s:${token.toUpperCase()}]';

  static String injectToken({
    required String token,
    required String body,
  }) {
    if (body.trim().isEmpty) {
      return decorateToken(token);
    }
    return '${decorateToken(token)} ${body.trim()}';
  }

  static ShareTokenParseResult? stripToken(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    final token = match.group(1)!.toUpperCase();
    final cleaned = text.substring(match.end);
    return ShareTokenParseResult(
      token: token,
      cleanedBody: cleaned.trimLeft(),
    );
  }
}
