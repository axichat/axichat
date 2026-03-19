// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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
  required String? forwardedSubjectSenderLabel,
  required String? forwardedFromJid,
}) {
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
