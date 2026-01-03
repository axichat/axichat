// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/email/util/share_token_html.dart';
import 'package:axichat/src/storage/models.dart';

const int _pendingOutgoingMaxAgeMinutes = 2;
const Duration _pendingOutgoingMaxAge =
    Duration(minutes: _pendingOutgoingMaxAgeMinutes);
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

class PendingOutgoingEmailStore {
  PendingOutgoingEmailStore({
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.timestamp;

  final DateTime Function() _clock;
  final Map<int, List<_PendingOutgoingEmailEntry>> _entriesByAccount = {};
  final Map<String, _PendingOutgoingEmailEntry> _entriesByStanzaId = {};

  void register({
    required String stanzaId,
    required int accountId,
    required int chatId,
    String? text,
    String? html,
    String? fileName,
    String? filePath,
  }) {
    final PendingOutgoingEmailSignature signature =
        PendingOutgoingEmailSignature.fromOutgoing(
      text: text,
      html: html,
      fileName: fileName,
      filePath: filePath,
    );
    if (signature.isEmpty) {
      return;
    }
    final entry = _PendingOutgoingEmailEntry(
      stanzaId: stanzaId,
      accountId: accountId,
      chatId: chatId,
      createdAt: _clock(),
      signature: signature,
    );
    _entriesByStanzaId[stanzaId] = entry;
    final entries = _entriesByAccount.putIfAbsent(
      accountId,
      () => <_PendingOutgoingEmailEntry>[],
    );
    entries.add(entry);
    _sweep(accountId);
  }

  void resolve(String stanzaId) {
    final entry = _entriesByStanzaId.remove(stanzaId);
    if (entry == null) {
      return;
    }
    final entries = _entriesByAccount[entry.accountId];
    if (entries == null) {
      return;
    }
    entries.remove(entry);
    if (entries.isEmpty) {
      _entriesByAccount.remove(entry.accountId);
    }
  }

  String? claimMatch({
    required int accountId,
    required int chatId,
    String? text,
    String? html,
    String? fileName,
    String? filePath,
  }) {
    _sweep(accountId);
    final entries = _entriesByAccount[accountId];
    if (entries == null || entries.isEmpty) {
      return null;
    }
    final PendingOutgoingEmailSignature match =
        PendingOutgoingEmailSignature.fromOutgoing(
      text: text,
      html: html,
      fileName: fileName,
      filePath: filePath,
    );
    if (match.isEmpty) {
      return null;
    }
    final candidates = entries
        .where((entry) => entry.chatId == chatId && entry.matches(match))
        .toList();
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort(
      (a, b) => a.createdAt.compareTo(b.createdAt),
    );
    final selected = candidates.first;
    resolve(selected.stanzaId);
    return selected.stanzaId;
  }

  void _sweep(int accountId) {
    final entries = _entriesByAccount[accountId];
    if (entries == null || entries.isEmpty) {
      return;
    }
    final cutoff = _clock().subtract(_pendingOutgoingMaxAge);
    final expired =
        entries.where((entry) => entry.createdAt.isBefore(cutoff)).toList();
    if (expired.isEmpty) {
      return;
    }
    for (final entry in expired) {
      _entriesByStanzaId.remove(entry.stanzaId);
      entries.remove(entry);
    }
    if (entries.isEmpty) {
      _entriesByAccount.remove(accountId);
    }
  }
}

class _PendingOutgoingEmailEntry {
  const _PendingOutgoingEmailEntry({
    required this.stanzaId,
    required this.accountId,
    required this.chatId,
    required this.createdAt,
    required this.signature,
  });

  final String stanzaId;
  final int accountId;
  final int chatId;
  final DateTime createdAt;
  final PendingOutgoingEmailSignature signature;

  bool matches(PendingOutgoingEmailSignature match) => signature.matches(match);
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
