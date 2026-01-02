import 'package:axichat/src/common/html_content.dart';

const int _pendingOutgoingMaxAgeMinutes = 2;
const Duration _pendingOutgoingMaxAge =
    Duration(minutes: _pendingOutgoingMaxAgeMinutes);
const String _pendingOutgoingLineFeed = '\n';
const String _pendingOutgoingCarriageReturnLineFeed = '\r\n';
const String _pendingOutgoingEmpty = '';

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
    final normalizedText = _normalizeText(text);
    final normalizedHtml = _normalizeHtml(html);
    final normalizedFile = _normalizeFileSignature(
      fileName: fileName,
      filePath: filePath,
    );
    if (normalizedText == null &&
        normalizedHtml == null &&
        normalizedFile == null) {
      return;
    }
    final entry = _PendingOutgoingEmailEntry(
      stanzaId: stanzaId,
      accountId: accountId,
      chatId: chatId,
      createdAt: _clock(),
      textSignature: normalizedText,
      htmlSignature: normalizedHtml,
      fileSignature: normalizedFile,
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
    final match = _PendingOutgoingEmailMatch(
      chatId: chatId,
      textSignature: _normalizeText(text),
      htmlSignature: _normalizeHtml(html),
      fileSignature: _normalizeFileSignature(
        fileName: fileName,
        filePath: filePath,
      ),
    );
    final candidates = entries.where((entry) => entry.matches(match)).toList();
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
    required this.textSignature,
    required this.htmlSignature,
    required this.fileSignature,
  });

  final String stanzaId;
  final int accountId;
  final int chatId;
  final DateTime createdAt;
  final String? textSignature;
  final String? htmlSignature;
  final String? fileSignature;

  bool matches(_PendingOutgoingEmailMatch match) {
    if (chatId != match.chatId) {
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
    return false;
  }
}

class _PendingOutgoingEmailMatch {
  const _PendingOutgoingEmailMatch({
    required this.chatId,
    required this.textSignature,
    required this.htmlSignature,
    required this.fileSignature,
  });

  final int chatId;
  final String? textSignature;
  final String? htmlSignature;
  final String? fileSignature;
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
  return normalized;
}

String? _normalizeHtml(String? value) {
  final normalized = HtmlContentCodec.normalizeHtml(value);
  return _normalizeText(normalized);
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
