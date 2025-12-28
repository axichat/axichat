const int _maxMessageTextBytes = 128 * 1024;
const int _maxMessageHtmlBytes = 256 * 1024;
const int _utf8OneByteMax = 0x7f;
const int _utf8TwoByteMax = 0x7ff;
const int _utf8ThreeByteMax = 0xffff;
const int _utf8OneByteLength = 1;
const int _utf8TwoByteLength = 2;
const int _utf8ThreeByteLength = 3;
const int _utf8FourByteLength = 4;

String? clampMessageText(String? value) =>
    _clampUtf8(value, maxBytes: _maxMessageTextBytes);

String? clampMessageHtml(String? value) =>
    _clampUtf8(value, maxBytes: _maxMessageHtmlBytes);

String? _clampUtf8(String? value, {required int maxBytes}) {
  if (value == null) return null;
  if (value.isEmpty) return value;
  if (_fitsUtf8Limit(value, maxBytes)) return value;
  return _truncateUtf8(value, maxBytes);
}

bool _fitsUtf8Limit(String value, int maxBytes) {
  var count = 0;
  for (final rune in value.runes) {
    count += _utf8ByteLength(rune);
    if (count > maxBytes) return false;
  }
  return true;
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
