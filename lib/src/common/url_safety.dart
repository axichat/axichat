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

bool isSafeLinkUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (!_safeLinkSchemes.contains(scheme)) return false;
  if (_schemeAllowsEmptyHost(scheme)) {
    return uri.path.isNotEmpty;
  }
  return uri.host.isNotEmpty;
}

bool isSafeAttachmentUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (!_safeAttachmentSchemes.contains(scheme)) return false;
  return uri.host.isNotEmpty;
}

bool _schemeAllowsEmptyHost(String scheme) =>
    scheme == 'mailto' || scheme == 'xmpp';
