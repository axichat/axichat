// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/email/util/email_header_safety.dart';
import 'package:axichat/src/email/util/share_token_html.dart';
import 'package:axichat/src/storage/models.dart';

const String _pendingOutgoingLineFeed = '\n';
const String _pendingOutgoingCarriageReturnLineFeed = '\r\n';
const String _pendingOutgoingEmpty = '';

class PendingOutgoingEmailSignature {
  const PendingOutgoingEmailSignature({
    required this.subjectSignature,
    required this.textSignature,
    required this.htmlSignature,
    required this.fileSignature,
  });

  factory PendingOutgoingEmailSignature.fromOutgoing({
    String? subject,
    String? text,
    String? html,
    String? fileName,
    String? filePath,
  }) {
    final String? normalizedSubject = _normalizeSubject(subject);
    final String? normalizedText = _normalizeText(text);
    final String? normalizedHtml = _normalizeHtml(html);
    final String? normalizedFile = _normalizeFileSignature(
      fileName: fileName,
      filePath: filePath,
    );
    return PendingOutgoingEmailSignature(
      subjectSignature: normalizedSubject,
      textSignature: normalizedText,
      htmlSignature: normalizedHtml,
      fileSignature: normalizedFile,
    );
  }

  factory PendingOutgoingEmailSignature.fromMessage({
    required Message message,
    FileMetadataData? metadata,
  }) {
    return PendingOutgoingEmailSignature.fromOutgoing(
      subject: message.subject,
      text: message.body,
      html: message.htmlBody,
      fileName: metadata?.filename,
      filePath: metadata?.path,
    );
  }

  final String? subjectSignature;
  final String? textSignature;
  final String? htmlSignature;
  final String? fileSignature;

  bool get isEmpty =>
      subjectSignature == null &&
      textSignature == null &&
      htmlSignature == null &&
      fileSignature == null;

  bool matches(PendingOutgoingEmailSignature match) {
    if (!_signaturesMatch(subjectSignature, match.subjectSignature)) {
      return false;
    }
    if (fileSignature != null || match.fileSignature != null) {
      return fileSignature != null &&
          match.fileSignature != null &&
          fileSignature == match.fileSignature;
    }
    if (textSignature != null &&
        match.textSignature != null &&
        textSignature == match.textSignature) {
      return true;
    }
    if (htmlSignature != null &&
        match.htmlSignature != null &&
        htmlSignature == match.htmlSignature) {
      return true;
    }
    if (subjectSignature != null &&
        match.subjectSignature != null &&
        subjectSignature == match.subjectSignature) {
      return true;
    }
    return false;
  }
}

bool _signaturesMatch(String? first, String? second) {
  if (first == null && second == null) {
    return true;
  }
  if (first == null || second == null) {
    return false;
  }
  return first == second;
}

String? _normalizeSubject(String? value) =>
    _normalizeText(sanitizeEmailSubjectValue(value));

String? _normalizeText(String? value) {
  final normalized = value
      ?.replaceAll(
        _pendingOutgoingCarriageReturnLineFeed,
        _pendingOutgoingLineFeed,
      )
      .trim();
  if (normalized == null || normalized == _pendingOutgoingEmpty) {
    return null;
  }
  final cleaned =
      ShareTokenCodec.stripToken(normalized)?.cleanedBody ?? normalized;
  final trimmed = cleaned.trim();
  if (trimmed == _pendingOutgoingEmpty) {
    return null;
  }
  return trimmed;
}

String? _normalizeHtml(String? value) {
  final normalized = HtmlContentCodec.normalizeHtml(value);
  final stripped = ShareTokenHtmlCodec.stripInjectedToken(normalized);
  return _normalizeText(stripped);
}

String? _normalizeFileSignature({String? fileName, String? filePath}) {
  final normalizedFileName = _normalizeText(fileName);
  if (normalizedFileName != null) {
    return normalizedFileName;
  }
  return _normalizeText(filePath);
}
