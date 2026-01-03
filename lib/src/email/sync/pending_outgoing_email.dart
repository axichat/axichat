// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/email/util/share_token_html.dart';
import 'package:axichat/src/storage/models.dart';

const String _pendingOutgoingLineFeed = '\n';
const String _pendingOutgoingCarriageReturnLineFeed = '\r\n';
const String _pendingOutgoingEmpty = '';

class PendingOutgoingEmailSignature {
  const PendingOutgoingEmailSignature({
    required this.textSignature,
    required this.htmlSignature,
    required this.fileSignature,
  });

  factory PendingOutgoingEmailSignature.fromOutgoing({
    String? text,
    String? html,
    String? fileName,
    String? filePath,
  }) {
    final String? normalizedText = _normalizeText(text);
    final String? normalizedHtml = _normalizeHtml(html);
    final String? normalizedFile = _normalizeFileSignature(
      fileName: fileName,
      filePath: filePath,
    );
    return PendingOutgoingEmailSignature(
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
      text: message.body,
      html: message.htmlBody,
      fileName: metadata?.filename,
      filePath: metadata?.path,
    );
  }

  final String? textSignature;
  final String? htmlSignature;
  final String? fileSignature;

  bool get isEmpty =>
      textSignature == null && htmlSignature == null && fileSignature == null;

  bool matches(PendingOutgoingEmailSignature match) {
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
    return false;
  }
}

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

String? _normalizeFileSignature({
  String? fileName,
  String? filePath,
}) {
  final normalizedFileName = _normalizeText(fileName);
  if (normalizedFileName != null) {
    return normalizedFileName;
  }
  return _normalizeText(filePath);
}
