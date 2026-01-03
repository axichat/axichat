// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/unicode_safety.dart';

const String _httpScheme = 'http';
const String _httpsScheme = 'https';
const String _mailtoScheme = 'mailto';
const String _xmppScheme = 'xmpp';
const String _punycodePrefix = 'xn--';
const String _schemeHostSeparator = '://';

const Set<String> _safeLinkSchemes = <String>{
  _httpScheme,
  _httpsScheme,
  _mailtoScheme,
  _xmppScheme,
};
const Set<String> _safeAttachmentSchemes = <String>{
  _httpScheme,
  _httpsScheme,
};
const int _nullCharCodeUnit = 0x00;
const int _lineFeedCodeUnit = 0x0a;
const int _carriageReturnCodeUnit = 0x0d;
const int _maxSafeLinkLength = 2048;
const int _maxSafeAttachmentUriLength = 2048;
const String _encodedNull = '%00';
const String _encodedLineFeed = '%0a';
const String _encodedCarriageReturn = '%0d';
const String _linkWarningHeader = 'Warnings:';
const String _linkWarningSeparator = '\n\n';
const String _linkWarningBullet = '- ';
const String _linkWarningPunycode = 'Address uses IDN/punycode.';
const String _linkWarningMixedScript = 'Address mixes scripts.';
const String _linkWarningBidiControl =
    'Address has direction-control characters.';
const String _linkWarningZeroWidth = 'Address has hidden characters.';
const String _linkWarningShortener = 'Short link service.';
final RegExp _asciiLetterPattern = RegExp(r'[A-Za-z]');
final RegExp _nonAsciiPattern = RegExp(r'[^\x00-\x7F]');
const Set<String> _multiLabelPublicSuffixes = <String>{
  'co.uk',
  'org.uk',
  'gov.uk',
  'ac.uk',
  'com.au',
  'net.au',
  'org.au',
  'co.nz',
  'org.nz',
  'com.br',
  'com.mx',
  'com.ar',
  'com.tr',
  'co.jp',
  'co.kr',
  'co.in',
  'com.sg',
  'com.hk',
  'com.tw',
  'com.cn',
  'com.vn',
  'co.za',
  'co.id',
  'co.th',
  'com.my',
  'com.ph',
  'com.sa',
  'com.eg',
};
const Set<String> _shortenerHosts = <String>{
  'bit.ly',
  't.co',
  'tinyurl.com',
  'goo.gl',
  'ow.ly',
  'is.gd',
  'buff.ly',
  'cutt.ly',
  'bit.do',
  'rebrand.ly',
  'shorturl.at',
  'lnkd.in',
  's.id',
  'rb.gy',
  't.ly',
  'trib.al',
};

enum LinkSafetyKind {
  message,
  attachment;
}

enum LinkSafetyWarning {
  punycode,
  mixedScript,
  bidiControl,
  zeroWidth,
  shortener;
}

class LinkSafetyReport {
  const LinkSafetyReport({
    required this.uri,
    required this.displayUri,
    required this.displayHost,
    required this.host,
    required this.effectiveDomain,
    required this.warnings,
    required this.isSafe,
  });

  final Uri uri;
  final String displayUri;
  final String displayHost;
  final String host;
  final String effectiveDomain;
  final Set<LinkSafetyWarning> warnings;
  final bool isSafe;

  bool get hasWarnings => warnings.isNotEmpty;

  bool get needsWarning => warnings.isNotEmpty;
}

extension LinkSafetyWarningText on LinkSafetyWarning {
  String get message => switch (this) {
        LinkSafetyWarning.punycode => _linkWarningPunycode,
        LinkSafetyWarning.mixedScript => _linkWarningMixedScript,
        LinkSafetyWarning.bidiControl => _linkWarningBidiControl,
        LinkSafetyWarning.zeroWidth => _linkWarningZeroWidth,
        LinkSafetyWarning.shortener => _linkWarningShortener,
      };
}

bool containsUnsafeUriText(String value) =>
    _containsDisallowedControlChars(value);

bool containsSuspiciousUriText(String value) =>
    containsUnicodeControlCharacters(value);

bool isSafeLinkUri(Uri uri) {
  final raw = uri.toString();
  if (!_isWithinMaxLength(raw, _maxSafeLinkLength)) {
    return false;
  }
  final scheme = uri.scheme.toLowerCase();
  if (!_safeLinkSchemes.contains(scheme)) return false;
  if (containsUnsafeUriText(raw)) return false;
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
  if (containsUnsafeUriText(raw)) return false;
  if (uri.userInfo.isNotEmpty) return false;
  return uri.host.isNotEmpty;
}

bool _schemeAllowsEmptyHost(String scheme) =>
    scheme == _mailtoScheme || scheme == _xmppScheme;

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

LinkSafetyReport? assessLinkSafety({
  required String raw,
  required LinkSafetyKind kind,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  final allowed = kind == LinkSafetyKind.attachment
      ? isSafeAttachmentUri(uri)
      : isSafeLinkUri(uri);
  final isSafe = allowed && !containsUnsafeUriText(trimmed);
  final displayUri = uri.toString();
  final host = uri.host.trim();
  final normalizedHost = host.toLowerCase();
  final effectiveDomain =
      normalizedHost.isEmpty ? '' : _effectiveDomain(normalizedHost);
  final warnings = _detectLinkWarnings(
    rawUri: trimmed,
    host: normalizedHost,
  );
  final displayHost = _formatHostLabel(
    host: host,
    effectiveDomain: effectiveDomain,
    displayUri: displayUri,
  );
  return LinkSafetyReport(
    uri: uri,
    displayUri: displayUri,
    displayHost: displayHost,
    host: host,
    effectiveDomain: effectiveDomain,
    warnings: warnings,
    isSafe: isSafe,
  );
}

String formatLinkHostLabel(LinkSafetyReport report) {
  return _formatHostLabel(
    host: report.host,
    effectiveDomain: report.effectiveDomain,
    displayUri: report.displayUri,
  );
}

String formatLinkSchemeHostLabel(LinkSafetyReport report) {
  final hostLabel = formatLinkHostLabel(report);
  if (report.host.isEmpty) {
    return hostLabel;
  }
  final scheme = report.uri.scheme.trim();
  if (scheme.isEmpty) {
    return hostLabel;
  }
  return '$scheme$_schemeHostSeparator$hostLabel';
}

String formatLinkWarningText(Set<LinkSafetyWarning> warnings) {
  if (warnings.isEmpty) {
    return '';
  }
  final lines = <String>[];
  for (final warning in LinkSafetyWarning.values) {
    if (!warnings.contains(warning)) continue;
    lines.add('$_linkWarningBullet${warning.message}');
  }
  return '$_linkWarningSeparator$_linkWarningHeader\n${lines.join('\n')}';
}

String _effectiveDomain(String host) {
  final labels = host.split('.');
  if (labels.length <= 1) {
    return host;
  }
  final lastTwo = labels.sublist(labels.length - 2).join('.');
  if (_multiLabelPublicSuffixes.contains(lastTwo) && labels.length >= 3) {
    return labels.sublist(labels.length - 3).join('.');
  }
  return lastTwo;
}

Set<LinkSafetyWarning> _detectLinkWarnings({
  required String rawUri,
  required String host,
}) {
  final warnings = <LinkSafetyWarning>{};
  if (containsBidiControlCharacters(rawUri)) {
    warnings.add(LinkSafetyWarning.bidiControl);
  }
  if (containsZeroWidthCharacters(rawUri)) {
    warnings.add(LinkSafetyWarning.zeroWidth);
  }
  if (_hasPunycodeLabel(host)) {
    warnings.add(LinkSafetyWarning.punycode);
  }
  if (_hasMixedScripts(host)) {
    warnings.add(LinkSafetyWarning.mixedScript);
  }
  if (host.isNotEmpty && _shortenerHosts.contains(host)) {
    warnings.add(LinkSafetyWarning.shortener);
  }
  return Set.unmodifiable(warnings);
}

bool _hasPunycodeLabel(String host) {
  if (host.isEmpty) return false;
  final labels = host.split('.');
  for (final label in labels) {
    if (label.startsWith(_punycodePrefix)) {
      return true;
    }
  }
  return false;
}

bool _hasMixedScripts(String host) {
  if (host.isEmpty) return false;
  if (!_nonAsciiPattern.hasMatch(host)) return false;
  if (!_asciiLetterPattern.hasMatch(host)) return false;
  return true;
}

String _formatHostLabel({
  required String host,
  required String effectiveDomain,
  required String displayUri,
}) {
  if (host.isEmpty) {
    return displayUri;
  }
  if (effectiveDomain.isEmpty || effectiveDomain == host) {
    return host;
  }
  return '$host ($effectiveDomain)';
}
