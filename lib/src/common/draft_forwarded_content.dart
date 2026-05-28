// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/email/util/synthetic_forward_html.dart';
import 'package:axichat/src/storage/models.dart';

final class DraftForwardedContent {
  const DraftForwardedContent({required this.plainText, this.htmlBody});

  final String plainText;
  final String? htmlBody;

  static DraftForwardedContent compose({
    required String introText,
    required List<DraftForwardedBlock> forwardedBlocks,
  }) {
    final trimmedIntro = introText.trim();
    if (forwardedBlocks.isEmpty) {
      return DraftForwardedContent(plainText: trimmedIntro);
    }
    final plainParts = <String>[];
    final htmlParts = <String>[];
    if (trimmedIntro.isNotEmpty) {
      plainParts.add(trimmedIntro);
      htmlParts.add(HtmlContentCodec.fromPlainText(trimmedIntro));
    }
    for (final block in forwardedBlocks) {
      if (block.isConverted) {
        final convertedText = block.convertedText ?? '';
        if (convertedText.trim().isEmpty) {
          continue;
        }
        plainParts.add(convertedText.trim());
        htmlParts.add(HtmlContentCodec.fromPlainText(convertedText));
        continue;
      }
      final plainBlock = plainForwardedBlock(block);
      if (plainBlock.isNotEmpty) {
        plainParts.add(plainBlock);
      }
      final htmlHeader = _htmlForwardedHeader(block);
      final normalizedOriginalHtml = HtmlContentCodec.normalizeHtml(
        block.originalHtml,
      );
      final htmlBlock = normalizedOriginalHtml == null
          ? HtmlContentCodec.fromPlainText(plainBlock)
          : '$htmlHeader${_htmlQuotedContext(block)}<br /><br />'
                '${injectSyntheticForwardHtmlMarker(normalizedOriginalHtml)}';
      if (htmlBlock.trim().isNotEmpty) {
        htmlParts.add(htmlBlock);
      }
    }
    final html = htmlParts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join('<br /><br />');
    return DraftForwardedContent(
      plainText: plainParts
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join('\n\n'),
      htmlBody: HtmlContentCodec.normalizeHtml(html),
    );
  }

  static String plainForwardedBlock(DraftForwardedBlock block) {
    final lines = <String>[..._plainForwardedHeaderLines(block), ''];
    final quotedContext = block.quotedContext;
    if (quotedContext != null) {
      lines.add('Quoted reply from ${quotedContext.senderLabel.trim()}:');
      for (final line in quotedContext.plainText.trim().split('\n')) {
        lines.add('> ${line.trimRight()}');
      }
      lines.add('');
    }
    final body = block.originalPlainText.trim();
    if (body.isNotEmpty) {
      lines.add(body);
    }
    return lines.join('\n').trim();
  }

  static List<String> _plainForwardedHeaderLines(DraftForwardedBlock block) {
    return <String>[
      '-------- Forwarded message --------',
      'From: ${_senderLine(block)}',
      if (block.timestamp != null)
        'Date: ${block.timestamp!.toUtc().toIso8601String()}',
      if (block.originalSubject?.trim().isNotEmpty == true)
        'Subject: ${block.originalSubject!.trim()}',
    ];
  }

  static String _htmlForwardedHeader(DraftForwardedBlock block) {
    return HtmlContentCodec.fromPlainText(
      _plainForwardedHeaderLines(block).join('\n'),
    );
  }

  static String _htmlQuotedContext(DraftForwardedBlock block) {
    final quotedContext = block.quotedContext;
    if (quotedContext == null) {
      return '';
    }
    return '<br /><br />${HtmlContentCodec.fromPlainText('Quoted reply from ${quotedContext.senderLabel.trim()}:\n'
    '${quotedContext.plainText.trim()}')}';
  }

  static String _senderLine(DraftForwardedBlock block) {
    final senderLabel = block.senderLabel.trim();
    final senderJid = block.senderJid.trim();
    if (senderJid.isEmpty || senderLabel == senderJid) {
      return senderLabel;
    }
    if (senderLabel.isEmpty) {
      return senderJid;
    }
    return '$senderLabel <$senderJid>';
  }
}
