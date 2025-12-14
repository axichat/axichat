class SafeLogging {
  static const String redactedAccount = '<account>';
  static const String redactedPath = '<path>';
  static const String redactedSecret = '<secret>';

  static const int _minSecretLength = 32;
  static const int _minSecretPreviewLength = 8;
  static const int _secretPreviewPrefixLength = 4;

  static final RegExp _fileUriPattern = RegExp(r'\bfile://\S+');
  static final RegExp _absolutePathAfterWhitespacePattern =
      RegExp(r'(^|\s)(?:~/|/|[A-Za-z]:\\)\S+');
  static final RegExp _absolutePathAfterEqualsPattern =
      RegExp(r'=(?:~/|/|[A-Za-z]:\\)\S+');
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
    output = output.replaceAll(_fileUriPattern, redactedPath);
    output = output.replaceAllMapped(_absolutePathAfterWhitespacePattern, (m) {
      final leadingWhitespace = m.group(1) ?? '';
      return '$leadingWhitespace$redactedPath';
    });
    output = output.replaceAllMapped(
      _absolutePathAfterEqualsPattern,
      (_) => '=$redactedPath',
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
