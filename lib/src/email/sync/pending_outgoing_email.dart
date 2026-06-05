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
    required this.fileMimeSignature,
    required this.fileSizeBytes,
  });

  factory PendingOutgoingEmailSignature.fromOutgoing({
    String? subject,
    String? text,
    String? html,
    String? fileName,
    String? filePath,
    String? fileMime,
    int? fileSizeBytes,
  }) {
    final String? normalizedSubject = _normalizeSubject(subject);
    final String? normalizedText = _normalizeText(text);
    final String? normalizedHtml = _normalizeHtml(html);
    final String? normalizedFile = _normalizeFileSignature(
      fileName: fileName,
      filePath: filePath,
    );
    final String? normalizedFileMime = _normalizeFileMime(fileMime);
    final int? normalizedFileSize = _normalizeFileSizeBytes(fileSizeBytes);
    return PendingOutgoingEmailSignature(
      subjectSignature: normalizedSubject,
      textSignature: normalizedText,
      htmlSignature: normalizedHtml,
      fileSignature: normalizedFile,
      fileMimeSignature: normalizedFileMime,
      fileSizeBytes: normalizedFileSize,
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
      fileMime: metadata?.mimeType,
      fileSizeBytes: metadata?.sizeBytes,
    );
  }

  final String? subjectSignature;
  final String? textSignature;
  final String? htmlSignature;
  final String? fileSignature;
  final String? fileMimeSignature;
  final int? fileSizeBytes;

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

  bool matchesAttachmentFileFallback(PendingOutgoingEmailSignature match) {
    if (fileSignature == null || match.fileSignature == null) {
      return false;
    }
    if (fileMimeSignature == null ||
        match.fileMimeSignature == null ||
        fileMimeSignature != match.fileMimeSignature) {
      return false;
    }
    if (fileSizeBytes == null ||
        match.fileSizeBytes == null ||
        fileSizeBytes != match.fileSizeBytes) {
      return false;
    }
    if (!_signaturesMatch(subjectSignature, match.subjectSignature)) {
      return false;
    }
    final normalizedText = _stripSubjectEchoFromTextSignature(
      value: textSignature,
      subject: subjectSignature,
    );
    final normalizedMatchText = _stripSubjectEchoFromTextSignature(
      value: match.textSignature,
      subject: match.subjectSignature,
    );
    if (normalizedText != null &&
        normalizedMatchText != null &&
        normalizedText == normalizedMatchText) {
      return true;
    }
    if (htmlSignature != null &&
        match.htmlSignature != null &&
        htmlSignature == match.htmlSignature) {
      return true;
    }
    if (normalizedText != null ||
        normalizedMatchText != null ||
        htmlSignature != null ||
        match.htmlSignature != null) {
      return false;
    }
    return true;
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

String? _stripSubjectEchoFromTextSignature({
  required String? value,
  required String? subject,
}) {
  if (value == null) {
    return null;
  }
  if (subject != null && value == subject) {
    return null;
  }
  return value;
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

String? _normalizeFileMime(String? value) =>
    _normalizeText(sanitizeEmailMimeType(value));

int? _normalizeFileSizeBytes(int? value) {
  if (value == null || value <= 0) {
    return null;
  }
  return value;
}
