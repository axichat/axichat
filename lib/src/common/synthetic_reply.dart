// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

const syntheticReplySubjectPrefix = 'Re:';

String syntheticReplySubject({
  required String? subject,
  required String? quotedSubject,
  required String? quotedSenderLabel,
}) {
  final normalizedSubject = _trimmedOrNull(subject);
  if (normalizedSubject != null) {
    return normalizedSubject;
  }
  final normalizedQuotedSubject = _trimmedOrNull(quotedSubject);
  if (normalizedQuotedSubject != null) {
    if (normalizedQuotedSubject.toLowerCase().startsWith('re:')) {
      return normalizedQuotedSubject;
    }
    return '$syntheticReplySubjectPrefix $normalizedQuotedSubject';
  }
  final normalizedQuotedSenderLabel = _trimmedOrNull(quotedSenderLabel);
  if (normalizedQuotedSenderLabel != null) {
    return '$syntheticReplySubjectPrefix $normalizedQuotedSenderLabel';
  }
  return syntheticReplySubjectPrefix;
}

String syntheticReplyQuotedText({
  required String? quotedSubject,
  required String quotedBody,
}) {
  final normalizedQuotedSubject = _trimmedOrNull(quotedSubject);
  final normalizedQuotedBody = quotedBody.trim();
  if (normalizedQuotedSubject != null && normalizedQuotedBody.isNotEmpty) {
    return '$normalizedQuotedSubject\n\n$normalizedQuotedBody';
  }
  if (normalizedQuotedSubject != null) {
    return normalizedQuotedSubject;
  }
  return normalizedQuotedBody;
}

String composeSyntheticReplyBody({
  required String body,
  required String quotedText,
}) {
  final normalizedBody = body.trim();
  final normalizedQuotedText = quotedText.trim();
  if (normalizedQuotedText.isEmpty) {
    return normalizedBody;
  }
  final quotedBlock = normalizedQuotedText
      .split('\n')
      .map((line) => line.isEmpty ? '>' : '> $line')
      .join('\n');
  if (normalizedBody.isEmpty) {
    return quotedBlock;
  }
  return '$normalizedBody\n\n$quotedBlock';
}

({String subject, String body}) syntheticReplyEnvelope({
  required String body,
  required String? subject,
  required String? quotedSubject,
  required String quotedBody,
  required String? quotedSenderLabel,
}) {
  final resolvedSubject = syntheticReplySubject(
    subject: subject,
    quotedSubject: quotedSubject,
    quotedSenderLabel: quotedSenderLabel,
  );
  final resolvedQuotedText = syntheticReplyQuotedText(
    quotedSubject: quotedSubject,
    quotedBody: quotedBody,
  );
  return (
    subject: resolvedSubject,
    body: composeSyntheticReplyBody(body: body, quotedText: resolvedQuotedText),
  );
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
