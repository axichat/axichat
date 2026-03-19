// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';
import 'dart:typed_data';

const syntheticForwardSubjectMarker = '\u2060';
const syntheticForwardSubjectPrefix = 'FWD:';
const forwardedBodySubjectPrefix = 'Subject:';
const List<String> _syntheticForwardSubjectPrefixes = <String>['fwd:', 'fw:'];

String syntheticForwardVisibleSubject({required String senderLabel}) {
  final trimmedSenderLabel = senderLabel.trim();
  return trimmedSenderLabel.isEmpty
      ? syntheticForwardSubjectPrefix
      : '$syntheticForwardSubjectPrefix $trimmedSenderLabel';
}

String markSyntheticForwardSubject(String subject) {
  final normalizedSubject = subject.trim();
  return '$normalizedSubject$syntheticForwardSubjectMarker';
}

String? stripSyntheticForwardSubjectMarker(String? subjectLabel) {
  final trimmedSubject = subjectLabel?.trim();
  if (trimmedSubject == null || trimmedSubject.isEmpty) {
    return null;
  }
  if (!trimmedSubject.endsWith(syntheticForwardSubjectMarker)) {
    return trimmedSubject;
  }
  final visibleSubject = trimmedSubject
      .substring(
        0,
        trimmedSubject.length - syntheticForwardSubjectMarker.length,
      )
      .trimRight();
  return visibleSubject.isEmpty ? null : visibleSubject;
}

String? syntheticForwardMarkedVisibleSubject(String? subjectLabel) {
  final trimmedSubject = subjectLabel?.trim();
  if (trimmedSubject == null || trimmedSubject.isEmpty) {
    return null;
  }
  if (!trimmedSubject.endsWith(syntheticForwardSubjectMarker)) {
    return null;
  }
  return stripSyntheticForwardSubjectMarker(trimmedSubject);
}

String? syntheticForwardSenderLabel(String? subjectLabel) {
  final normalizedSubject = stripSyntheticForwardSubjectMarker(subjectLabel);
  if (normalizedSubject == null) {
    return null;
  }
  final lowerCaseSubject = normalizedSubject.toLowerCase();
  for (final prefix in _syntheticForwardSubjectPrefixes) {
    if (!lowerCaseSubject.startsWith(prefix)) {
      continue;
    }
    final senderLabel = normalizedSubject.substring(prefix.length).trim();
    return senderLabel.isEmpty ? null : senderLabel;
  }
  return null;
}

String? syntheticForwardDisplaySenderLabel({
  required String? subjectLabel,
  required bool emailMarkerPresent,
}) {
  final markedSubject = syntheticForwardMarkedVisibleSubject(subjectLabel);
  if (markedSubject != null) {
    return syntheticForwardSenderLabel(markedSubject);
  }
  if (!emailMarkerPresent) {
    return null;
  }
  return syntheticForwardSenderLabel(subjectLabel);
}

String? preferredForwardedPreviewSenderLabel({
  required String? forwardedOriginalSenderLabel,
  required String? forwardedSubjectSenderLabel,
  required String? forwardedFromJid,
}) {
  final originalSender = forwardedOriginalSenderLabel?.trim();
  if (originalSender != null && originalSender.isNotEmpty) {
    return originalSender;
  }
  final subjectSender = forwardedSubjectSenderLabel?.trim();
  if (subjectSender != null && subjectSender.isNotEmpty) {
    return subjectSender;
  }
  final forwarder = forwardedFromJid?.trim();
  if (forwarder != null && forwarder.isNotEmpty) {
    return forwarder;
  }
  return null;
}

bool hasForwardedBodyHeader(String? body) {
  final normalizedBody = _normalizedForwardedBody(body);
  if (normalizedBody == null || normalizedBody.trim().isEmpty) {
    return false;
  }
  return _forwardedBodyHeaderIndex(normalizedBody.split('\n')) != null;
}

String? forwardedBodySenderLabel(String? body) {
  final normalizedBody = _normalizedForwardedBody(body);
  if (normalizedBody == null || normalizedBody.trim().isEmpty) {
    return null;
  }
  final lines = normalizedBody.split('\n');
  final headerIndex = _forwardedBodyHeaderIndex(lines);
  if (headerIndex == null) {
    return null;
  }
  final headerLinesStartIndex = _isForwardedBodyHeaderLine(lines[headerIndex])
      ? headerIndex + 1
      : headerIndex;
  final rawValue = _forwardedBodyHeaders(
    lines.skip(headerLinesStartIndex),
  )['from'];
  if (rawValue == null || rawValue.isEmpty) {
    return null;
  }
  final match = RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  ).firstMatch(rawValue);
  if (match == null) {
    return rawValue;
  }
  final email = match.group(0)?.trim();
  return email == null || email.isEmpty ? rawValue : email;
}

String? _normalizedForwardedBody(String? body) {
  final normalizedBody = body?.replaceAll('\r\n', '\n');
  if (normalizedBody == null || normalizedBody.isEmpty) {
    return normalizedBody;
  }
  return _decodeQuotedPrintable(normalizedBody);
}

Map<String, String> _forwardedBodyHeaders(Iterable<String> lines) {
  final headers = <String, String>{};
  String? currentHeaderName;
  var currentHeaderValue = '';

  void commitCurrentHeader() {
    final headerName = currentHeaderName;
    if (headerName == null) {
      return;
    }
    final resolvedValue = currentHeaderValue.trim();
    if (resolvedValue.isNotEmpty) {
      headers[headerName] = resolvedValue;
    }
    currentHeaderName = null;
    currentHeaderValue = '';
  }

  for (final line in lines) {
    if (line.trim().isEmpty) {
      break;
    }
    if (currentHeaderName != null &&
        (line.startsWith(' ') || line.startsWith('\t'))) {
      currentHeaderValue = currentHeaderValue.isEmpty
          ? line.trim()
          : '$currentHeaderValue ${line.trim()}';
      continue;
    }
    final trimmedLine = line.trimLeft();
    final separatorIndex = trimmedLine.indexOf(':');
    if (separatorIndex == -1) {
      if (currentHeaderName != null && currentHeaderValue.isNotEmpty) {
        currentHeaderValue = '$currentHeaderValue$trimmedLine';
      }
      continue;
    }
    commitCurrentHeader();
    currentHeaderName = trimmedLine
        .substring(0, separatorIndex)
        .trim()
        .toLowerCase();
    currentHeaderValue = trimmedLine.substring(separatorIndex + 1).trim();
  }
  commitCurrentHeader();
  return headers;
}

String _decodeQuotedPrintable(String value) {
  if (!value.contains('=')) {
    return value;
  }
  final normalized = value.replaceAll('\r\n', '\n');
  final bytes = BytesBuilder(copy: false);
  var segmentStart = 0;
  for (var index = 0; index < normalized.length; index += 1) {
    if (normalized.codeUnitAt(index) != _asciiEquals) {
      continue;
    }
    if (index + 1 < normalized.length &&
        normalized.codeUnitAt(index + 1) == _asciiLineFeed) {
      _appendForwardedBodySegment(
        bytes,
        normalized,
        start: segmentStart,
        end: index,
      );
      segmentStart = index + 2;
      index += 1;
      continue;
    }
    if (index + 2 >= normalized.length) {
      continue;
    }
    final decodedByte = _decodeQuotedPrintableByte(
      normalized.codeUnitAt(index + 1),
      normalized.codeUnitAt(index + 2),
    );
    if (decodedByte == null) {
      continue;
    }
    _appendForwardedBodySegment(
      bytes,
      normalized,
      start: segmentStart,
      end: index,
    );
    bytes.addByte(decodedByte);
    segmentStart = index + 3;
    index += 2;
  }
  _appendForwardedBodySegment(
    bytes,
    normalized,
    start: segmentStart,
    end: normalized.length,
  );
  return utf8.decode(bytes.takeBytes(), allowMalformed: true);
}

void _appendForwardedBodySegment(
  BytesBuilder bytes,
  String source, {
  required int start,
  required int end,
}) {
  if (start >= end) {
    return;
  }
  bytes.add(utf8.encode(source.substring(start, end)));
}

int? _decodeQuotedPrintableByte(int first, int second) {
  final firstNibble = _hexNibble(first);
  final secondNibble = _hexNibble(second);
  if (firstNibble == null || secondNibble == null) {
    return null;
  }
  return (firstNibble << 4) | secondNibble;
}

int? _hexNibble(int codeUnit) {
  if (codeUnit >= _asciiZero && codeUnit <= _asciiNine) {
    return codeUnit - _asciiZero;
  }
  final lowerCaseCodeUnit = codeUnit >= _asciiUpperA && codeUnit <= _asciiUpperF
      ? codeUnit + (_asciiLowerA - _asciiUpperA)
      : codeUnit;
  if (lowerCaseCodeUnit >= _asciiLowerA && lowerCaseCodeUnit <= _asciiLowerF) {
    return lowerCaseCodeUnit - _asciiLowerA + 10;
  }
  return null;
}

int? _forwardedBodyHeaderIndex(List<String> lines) {
  const maxHeaderSearchLines = 48;
  final limit = lines.length < maxHeaderSearchLines
      ? lines.length
      : maxHeaderSearchLines;
  for (var index = 0; index < limit; index += 1) {
    if (_isForwardedBodyHeaderLine(lines[index])) {
      return index;
    }
  }
  return _inlineForwardedHeaderBlockIndex(lines, limit: limit);
}

int? _inlineForwardedHeaderBlockIndex(
  List<String> lines, {
  required int limit,
}) {
  for (var index = 0; index < limit; index += 1) {
    if (!_isInlineForwardedHeaderStart(lines[index])) {
      continue;
    }
    final headers = _forwardedBodyHeaders(lines.skip(index));
    final fromHeader = headers['from'];
    if (fromHeader == null || fromHeader.isEmpty) {
      continue;
    }
    const supportingHeaderNames = <String>{
      'date',
      'sent',
      'subject',
      'to',
      'cc',
    };
    final supportingHeaderCount = supportingHeaderNames
        .where((name) => headers[name]?.isNotEmpty == true)
        .length;
    if (supportingHeaderCount > 0) {
      return index;
    }
  }
  return null;
}

bool _isInlineForwardedHeaderStart(String line) {
  final normalized = line.trimLeft().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  return normalized.startsWith('from:') ||
      normalized.startsWith('date:') ||
      normalized.startsWith('sent:') ||
      normalized.startsWith('subject:') ||
      normalized.startsWith('to:') ||
      normalized.startsWith('cc:');
}

bool _isForwardedBodyHeaderLine(String line) {
  final normalized = line.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  if (normalized == 'begin forwarded message:' ||
      normalized == 'forwarded message:' ||
      normalized == 'forwarded message' ||
      normalized == 'original message:' ||
      normalized == 'original message') {
    return true;
  }
  return RegExp(
    r'^-{2,}\s*(?:forwarded|original)\s+message\s*-{0,}:?$',
  ).hasMatch(normalized);
}

const _asciiZero = 0x30;
const _asciiNine = 0x39;
const _asciiUpperA = 0x41;
const _asciiUpperF = 0x46;
const _asciiEquals = 0x3D;
const _asciiLineFeed = 0x0A;
const _asciiLowerA = 0x61;
const _asciiLowerF = 0x66;

({String? subject, String body}) splitSyntheticForwardBody(String body) {
  final trimmedBody = body.trimLeft();
  final lowerCasePrefix = forwardedBodySubjectPrefix.toLowerCase();
  if (!trimmedBody.toLowerCase().startsWith(lowerCasePrefix)) {
    return (subject: null, body: body);
  }
  final lineBreakIndex = trimmedBody.indexOf('\n');
  if (lineBreakIndex == -1) {
    final subject = trimmedBody.substring(lowerCasePrefix.length).trim();
    return (subject: subject.isEmpty ? null : subject, body: '');
  }
  final subjectLine = trimmedBody.substring(0, lineBreakIndex);
  final subject = subjectLine.substring(lowerCasePrefix.length).trim();
  var remainder = trimmedBody.substring(lineBreakIndex + 1);
  if (remainder.startsWith('\n')) {
    remainder = remainder.substring(1);
  }
  return (subject: subject.isEmpty ? null : subject, body: remainder);
}
