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

bool isSafeLinkUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (!_safeLinkSchemes.contains(scheme)) return false;
  if (_containsDisallowedControlChars(uri.toString())) return false;
  if (uri.userInfo.isNotEmpty) return false;
  if (_schemeAllowsEmptyHost(scheme)) {
    return uri.path.isNotEmpty;
  }
  return uri.host.isNotEmpty;
}

bool isSafeAttachmentUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (!_safeAttachmentSchemes.contains(scheme)) return false;
  if (_containsDisallowedControlChars(uri.toString())) return false;
  if (uri.userInfo.isNotEmpty) return false;
  return uri.host.isNotEmpty;
}

bool _schemeAllowsEmptyHost(String scheme) =>
    scheme == 'mailto' || scheme == 'xmpp';

bool _containsDisallowedControlChars(String value) {
  for (final codeUnit in value.codeUnits) {
    if (codeUnit == _nullCharCodeUnit ||
        codeUnit == _lineFeedCodeUnit ||
        codeUnit == _carriageReturnCodeUnit) {
      return true;
    }
  }
  return false;
}
