class SafeLogging {
  static const String redactedAccount = '<account>';
  static const String redactedPath = '<path>';
  static const String redactedSecret = '<secret>';

  static const int _minSecretLength = 32;
  static const int _minSecretPreviewLength = 8;
  static const int _secretPreviewPrefixLength = 4;

  static final RegExp _xmlBodyPattern = RegExp(
    r'(<body\b[^>]*>).*?(</body>)',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _jsonPasswordPattern = RegExp(
    r'("(?:(?:old_|new_)?password|password2|passphrase)"\s*:\s*")[^"]*"',
    caseSensitive: false,
  );
  static final RegExp _keyValuePasswordPattern = RegExp(
    r'(\b(?:(?:old_|new_)?password|password2|passphrase)\b\s*[:=]\s*)\S+',
    caseSensitive: false,
  );
  static final RegExp _authorizationHeaderPattern = RegExp(
    r'(\bAuthorization\b\s*:\s*)([^\r\n]+)',
    caseSensitive: false,
  );
  static final RegExp _xAuthTokenHeaderPattern = RegExp(
    r'(\bX-Auth-Token\b\s*:\s*)([^\r\n]+)',
    caseSensitive: false,
  );

  static final RegExp _fileUriPattern = RegExp(r'\bfile://\S+');
  static final RegExp _absolutePathTokenPattern = RegExp(
    r'''(^|[\s\(\[\{<'"=,:])(?:~/|/|[A-Za-z]:\\|\\\\)\S+''',
  );
  static final RegExp _pathTrailingPunctuationPattern =
      RegExp(r'''[)\]\},;.'"]+$''');
  static final RegExp _accountIdentifierTokenPattern = RegExp(r'\S*@\S*');
  static final RegExp _hexSecretPattern =
      RegExp('\\b[a-fA-F0-9]{$_minSecretLength,}\\b');
  static final RegExp _tokenSecretPattern =
      RegExp('\\b[A-Za-z0-9_-]{$_minSecretLength,}\\b');

  static String sanitizeMessage(String message) => _sanitize(message);

  static String sanitizeError(Object? error) =>
      error == null ? '' : _sanitize(error.toString());

  static String sanitizeStackTrace(StackTrace? stackTrace) =>
      stackTrace == null ? '' : _sanitize(stackTrace.toString());

  static String _sanitize(String input) {
    var output = input;
    output = output.replaceAllMapped(
      _xmlBodyPattern,
      (m) => '${m.group(1)}$redactedSecret${m.group(2)}',
    );
    output = output.replaceAllMapped(
      _jsonPasswordPattern,
      (m) => '${m.group(1)}$redactedSecret"',
    );
    output = output.replaceAllMapped(
      _keyValuePasswordPattern,
      (m) => '${m.group(1)}$redactedSecret',
    );
    output = output.replaceAllMapped(
      _authorizationHeaderPattern,
      (m) => '${m.group(1)}$redactedSecret',
    );
    output = output.replaceAllMapped(
      _xAuthTokenHeaderPattern,
      (m) => '${m.group(1)}$redactedSecret',
    );
    output = output.replaceAll(_fileUriPattern, redactedPath);
    output = output.replaceAllMapped(
      _absolutePathTokenPattern,
      (m) {
        final matchText = m.group(0) ?? '';
        final leading = m.group(1) ?? '';
        final pathWithSuffix = matchText.substring(leading.length);
        final suffixMatch = _pathTrailingPunctuationPattern.firstMatch(
          pathWithSuffix,
        );
        final suffix = suffixMatch?.group(0) ?? '';
        return '$leading$redactedPath$suffix';
      },
    );
    output = output.replaceAllMapped(
      _accountIdentifierTokenPattern,
      (_) => redactedAccount,
    );
    output = output.replaceAllMapped(_hexSecretPattern, _redactSecretMatch);
    output = output.replaceAllMapped(_tokenSecretPattern, _redactSecretMatch);
    return output;
  }

  static String _redactSecretMatch(Match match) {
    final value = match.group(0);
    if (value == null || value.isEmpty) return redactedSecret;
    if (value.length <= _minSecretPreviewLength) return redactedSecret;
    final prefix = value.substring(0, _secretPreviewPrefixLength);
    return '$redactedSecret($prefix…len=${value.length})';
  }
}
