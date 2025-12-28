const Set<String> _safeLinkSchemes = <String>{
  'http',
  'https',
  'mailto',
  'xmpp',
};
const Set<String> _safeAttachmentSchemes = <String>{
  'http',
  'https',
};
const int _nullCharCodeUnit = 0x00;
const int _lineFeedCodeUnit = 0x0a;
const int _carriageReturnCodeUnit = 0x0d;
const int _maxSafeLinkLength = 2048;
const int _maxSafeAttachmentUriLength = 2048;
const String _encodedNull = '%00';
const String _encodedLineFeed = '%0a';
const String _encodedCarriageReturn = '%0d';

bool isSafeLinkUri(Uri uri) {
  final raw = uri.toString();
  if (!_isWithinMaxLength(raw, _maxSafeLinkLength)) {
    return false;
  }
  final scheme = uri.scheme.toLowerCase();
  if (!_safeLinkSchemes.contains(scheme)) return false;
  if (_containsDisallowedControlChars(raw)) return false;
  if (uri.userInfo.isNotEmpty) return false;
  if (_schemeAllowsEmptyHost(scheme)) {
    return uri.path.isNotEmpty;
  }
  return uri.host.isNotEmpty;
}

bool isSafeAttachmentUri(Uri uri) {
  final raw = uri.toString();
  if (!_isWithinMaxLength(raw, _maxSafeAttachmentUriLength)) {
    return false;
  }
  final scheme = uri.scheme.toLowerCase();
  if (!_safeAttachmentSchemes.contains(scheme)) return false;
  if (_containsDisallowedControlChars(raw)) return false;
  if (uri.userInfo.isNotEmpty) return false;
  return uri.host.isNotEmpty;
}

bool _schemeAllowsEmptyHost(String scheme) =>
    scheme == 'mailto' || scheme == 'xmpp';

bool _isWithinMaxLength(String value, int maxLength) =>
    value.length <= maxLength;

bool _containsDisallowedControlChars(String value) {
  final lower = value.toLowerCase();
  if (lower.contains(_encodedNull) ||
      lower.contains(_encodedLineFeed) ||
      lower.contains(_encodedCarriageReturn)) {
    return true;
  }
  for (final codeUnit in value.codeUnits) {
    if (codeUnit == _nullCharCodeUnit ||
        codeUnit == _lineFeedCodeUnit ||
        codeUnit == _carriageReturnCodeUnit) {
      return true;
    }
  }
  return false;
}
