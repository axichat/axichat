const int _maxMessageTextBytes = 128 * 1024;
const int _maxMessageHtmlBytes = 256 * 1024;
const int _maxXmppStanzaBytes = 1024 * 1024;
const int _maxXmppStanzaDepth = 64;
const int _maxReactionEmojisPerMessage = 32;
const int _maxReactionEmojiBytes = 32;
const int _utf8OneByteMax = 0x7f;
const int _utf8TwoByteMax = 0x7ff;
const int _utf8ThreeByteMax = 0xffff;
const int _utf8OneByteLength = 1;
const int _utf8TwoByteLength = 2;
const int _utf8ThreeByteLength = 3;
const int _utf8FourByteLength = 4;

const int maxMessageTextBytes = _maxMessageTextBytes;
const int maxMessageHtmlBytes = _maxMessageHtmlBytes;
const int maxXmppStanzaBytes = _maxXmppStanzaBytes;
const int maxXmppStanzaDepth = _maxXmppStanzaDepth;
const int maxReactionEmojisPerMessage = _maxReactionEmojisPerMessage;
const int maxReactionEmojiBytes = _maxReactionEmojiBytes;

String? clampMessageText(String? value) =>
    _clampUtf8(value, maxBytes: _maxMessageTextBytes);

String? clampMessageHtml(String? value) =>
    _clampUtf8(value, maxBytes: _maxMessageHtmlBytes);

String? clampUtf8Value(String? value, {required int maxBytes}) =>
    _clampUtf8(value, maxBytes: maxBytes);

bool isMessageTextWithinLimit(String? value) =>
    _isWithinLimit(value, maxBytes: _maxMessageTextBytes);

bool isMessageHtmlWithinLimit(String? value) =>
    _isWithinLimit(value, maxBytes: _maxMessageHtmlBytes);

bool isWithinUtf8ByteLimit(String? value, {required int maxBytes}) =>
    _isWithinLimit(value, maxBytes: maxBytes);

int utf8ByteLength(String value) => _utf8Length(value);

extension ReactionEmojiLimits on Iterable<String> {
  List<String> clampReactionEmojis() {
    final unique = <String>{};
    final limited = <String>[];
    for (final emoji in this) {
      final trimmed = emoji.trim();
      if (trimmed.isEmpty) continue;
      if (!isWithinUtf8ByteLimit(trimmed, maxBytes: _maxReactionEmojiBytes)) {
        continue;
      }
      if (!unique.add(trimmed)) {
        continue;
      }
      limited.add(trimmed);
      if (limited.length >= _maxReactionEmojisPerMessage) {
        break;
      }
    }
    return List<String>.unmodifiable(limited);
  }
}

String? _clampUtf8(String? value, {required int maxBytes}) {
  if (value == null) return null;
  if (value.isEmpty) return value;
  if (_fitsUtf8Limit(value, maxBytes)) return value;
  return _truncateUtf8(value, maxBytes);
}

bool _isWithinLimit(String? value, {required int maxBytes}) {
  if (value == null || value.isEmpty) return true;
  return _fitsUtf8Limit(value, maxBytes);
}

bool _fitsUtf8Limit(String value, int maxBytes) {
  return _utf8Length(value) <= maxBytes;
}

int _utf8Length(String value) {
  var count = 0;
  for (final rune in value.runes) {
    count += _utf8ByteLength(rune);
  }
  return count;
}

String _truncateUtf8(String value, int maxBytes) {
  var count = 0;
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final length = _utf8ByteLength(rune);
    if (count + length > maxBytes) break;
    count += length;
    buffer.writeCharCode(rune);
  }
  return buffer.toString();
}

int _utf8ByteLength(int rune) {
  if (rune <= _utf8OneByteMax) return _utf8OneByteLength;
  if (rune <= _utf8TwoByteMax) return _utf8TwoByteLength;
  if (rune <= _utf8ThreeByteMax) return _utf8ThreeByteLength;
  return _utf8FourByteLength;
}
