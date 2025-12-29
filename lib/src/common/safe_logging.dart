import 'package:logging/logging.dart';

class SafeLogging {
  static const String redactedAccount = '<account>';
  static const String redactedPath = '<path>';
  static const String redactedSecret = '<secret>';

  static const int _minSecretLength = 32;
  static const int _minSecretPreviewLength = 8;
  static const int _secretPreviewPrefixLength = 4;

  static const int _maxInputLengthForFullSanitize = 1024;
  static const int _xmppTrafficScanLimit = 512;
  static const int _xmppErrorScanLimit = 2048;
  static const int _notFoundIndex = -1;

  static const String _xmppTrafficOutPrefix = '==>';
  static const String _xmppTrafficInPrefix = '<==';
  static const String _xmppAvatarDataXmlns = 'urn:xmpp:avatar:data';
  static const String _xmppAvatarMetadataXmlns = 'urn:xmpp:avatar:metadata';
  static const String _xmppMamXmlnsPrefix = 'urn:xmpp:mam';
  static const String _xmppErrorTypeValue = 'error';
  static const String _xmppErrorTagStart = '<error';
  static const String _xmppErrorTagEnd = '</error>';
  static const String _xmppErrorTagName = 'error';
  static const String _xmppErrorTextTagName = 'text';
  static const String _calendarSyncTag = 'calendar_sync';

  static final RegExp _xmppTrafficFirstTagPattern =
      RegExp(r'^<\s*([A-Za-z0-9:_-]+)');
  static final RegExp _xmppTrafficTypeAttrPattern =
      RegExp(r'''\btype\s*=\s*['"]([^'"]+)['"]''', caseSensitive: false);
  static final RegExp _xmppErrorTypeAttrPattern = RegExp(
    r'''<error\b[^>]*\btype\s*=\s*['"]([^'"]+)['"]''',
    caseSensitive: false,
  );
  static final RegExp _xmppErrorCodeAttrPattern = RegExp(
    r'''<error\b[^>]*\bcode\s*=\s*['"]([^'"]+)['"]''',
    caseSensitive: false,
  );
  static final RegExp _xmppAnyTagPattern = RegExp(r'<\s*([A-Za-z0-9:_-]+)\b');

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
  static const Set<String> _xmppErrorIgnoredTags = <String>{
    _xmppErrorTagName,
    _xmppErrorTextTagName,
  };

  static String sanitizeMessage(String message) => _sanitize(message);

  static String sanitizeError(Object? error) =>
      error == null ? '' : _sanitize(error.toString());

  static String sanitizeStackTrace(StackTrace? stackTrace) =>
      stackTrace == null ? '' : _sanitize(stackTrace.toString());

  static String _sanitize(String input) {
    if (input.startsWith(_xmppTrafficOutPrefix) ||
        input.startsWith(_xmppTrafficInPrefix)) {
      return _summarizeXmppTraffic(input);
    }

    if (input.length > _maxInputLengthForFullSanitize) {
      return '$redactedSecret (log omitted, ${input.length} chars)';
    }

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

  static String _summarizeXmppTraffic(String input) {
    final totalLength = input.length;
    final direction = input.startsWith(_xmppTrafficInPrefix)
        ? _xmppTrafficInPrefix
        : _xmppTrafficOutPrefix;

    final stanzaStartIndex = input.indexOf('<');
    final headerStart =
        stanzaStartIndex == _notFoundIndex ? 0 : stanzaStartIndex;
    final headerEnd = input.indexOf('>', headerStart);
    final headerLimit = headerEnd == _notFoundIndex
        ? (headerStart + 256).clamp(0, totalLength)
        : (headerEnd + 1).clamp(0, totalLength);
    final header = input.substring(headerStart, headerLimit);

    final tag = _xmppTrafficFirstTagPattern.firstMatch(header)?.group(1);
    final type = _xmppTrafficTypeAttrPattern.firstMatch(header)?.group(1);

    final scanLimit = totalLength < _xmppTrafficScanLimit
        ? totalLength
        : _xmppTrafficScanLimit;
    final scannedPrefix = input.substring(0, scanLimit);
    final flags = <String>[
      if (scannedPrefix.contains(_xmppAvatarDataXmlns)) _xmppAvatarDataXmlns,
      if (scannedPrefix.contains(_xmppAvatarMetadataXmlns))
        _xmppAvatarMetadataXmlns,
      if (scannedPrefix.contains(_xmppMamXmlnsPrefix)) _xmppMamXmlnsPrefix,
      if (scannedPrefix.contains(_calendarSyncTag)) _calendarSyncTag,
    ];
    final renderedTag = tag == null ? '' : ' <$tag>';
    final renderedType = type == null ? '' : ' type=$type';
    final renderedFlags = flags.isEmpty ? '' : ' flags=${flags.join(',')}';
    final errorSummary =
        type == _xmppErrorTypeValue ? _summarizeXmppError(input) : null;
    final renderedError = errorSummary == null ? '' : ' error=$errorSummary';

    return '$direction ($totalLength chars)$renderedTag$renderedType'
        '$renderedFlags$renderedError';
  }

  static String _redactSecretMatch(Match match) {
    final value = match.group(0);
    if (value == null || value.isEmpty) return redactedSecret;
    if (value.length <= _minSecretPreviewLength) return redactedSecret;
    final prefix = value.substring(0, _secretPreviewPrefixLength);
    return '$redactedSecret($prefix…len=${value.length})';
  }

  static String? _summarizeXmppError(String input) {
    final errorStart = input.indexOf(_xmppErrorTagStart);
    if (errorStart == _notFoundIndex) {
      return _xmppErrorTypeValue;
    }
    final errorEnd = input.indexOf(_xmppErrorTagEnd, errorStart);
    final errorLimit =
        (errorStart + _xmppErrorScanLimit).clamp(0, input.length);
    final segmentEnd = errorEnd == _notFoundIndex
        ? errorLimit
        : errorEnd.clamp(0, input.length);
    final errorSegment = input.substring(errorStart, segmentEnd);
    final errorType =
        _xmppErrorTypeAttrPattern.firstMatch(errorSegment)?.group(1);
    final errorCode =
        _xmppErrorCodeAttrPattern.firstMatch(errorSegment)?.group(1);
    final errorCondition = _firstXmppErrorCondition(errorSegment);
    final parts = <String>[
      if (errorType != null && errorType.isNotEmpty) errorType,
      if (errorCode != null && errorCode.isNotEmpty) errorCode,
      if (errorCondition != null && errorCondition.isNotEmpty) errorCondition,
    ];
    if (parts.isEmpty) {
      return _xmppErrorTypeValue;
    }
    return parts.join('/');
  }

  static String? _firstXmppErrorCondition(String input) {
    for (final match in _xmppAnyTagPattern.allMatches(input)) {
      final raw = match.group(1);
      if (raw == null || raw.isEmpty) continue;
      final normalized = raw.toLowerCase();
      if (_xmppErrorIgnoredTags.contains(normalized)) continue;
      return normalized;
    }
    return null;
  }
}

extension SafeLogger on Logger {
  void safeFine(String message, [Object? error, StackTrace? stackTrace]) {
    _safeLog(Level.FINE, message, error, stackTrace);
  }

  void safeWarning(String message, [Object? error, StackTrace? stackTrace]) {
    _safeLog(Level.WARNING, message, error, stackTrace);
  }

  void _safeLog(
    Level level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final safeMessage = SafeLogging.sanitizeMessage(message);
    final safeError = SafeLogging.sanitizeError(error);
    final safeStackTrace = stackTrace == null
        ? null
        : StackTrace.fromString(
            SafeLogging.sanitizeStackTrace(stackTrace),
          );
    log(
      level,
      safeMessage,
      safeError.isEmpty ? null : safeError,
      safeStackTrace,
    );
  }
}
