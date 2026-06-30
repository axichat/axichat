// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:axichat/src/chats/utils/chat_history_exporter.dart';
import 'package:axichat/src/chats/utils/email_eml_exporter.dart';
import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:path/path.dart' as p;

const String messageExportTempDirectoryName = 'message_exports';
const int _emailExportContentPreparationConcurrency = 6;

enum MessageExportOutcome { success, empty, incomplete, failure }

class MessageExportResult {
  const MessageExportResult._({
    required this.outcome,
    this.file,
    this.itemCount = 0,
    this.warnings = const <String>[],
  });

  const MessageExportResult.success({
    required File file,
    required int itemCount,
    List<String> warnings = const <String>[],
  }) : this._(
         outcome: MessageExportOutcome.success,
         file: file,
         itemCount: itemCount,
         warnings: warnings,
       );

  const MessageExportResult.empty()
    : this._(outcome: MessageExportOutcome.empty);

  const MessageExportResult.incomplete({
    File? file,
    int itemCount = 0,
    List<String> warnings = const <String>[],
  }) : this._(
         outcome: MessageExportOutcome.incomplete,
         file: file,
         itemCount: itemCount,
         warnings: warnings,
       );

  const MessageExportResult.failure()
    : this._(outcome: MessageExportOutcome.failure);

  final MessageExportOutcome outcome;
  final File? file;
  final int itemCount;
  final List<String> warnings;

  bool get hasFile => file != null;
}

class MessageExporter {
  const MessageExporter({
    required XmppService xmppService,
    EmailService? emailService,
    EmailEmlExportProgressCallback? onEmailProgress,
  }) : _xmppService = xmppService,
       _emailService = emailService,
       _onEmailProgress = onEmailProgress;

  final XmppService _xmppService;
  final EmailService? _emailService;
  final EmailEmlExportProgressCallback? _onEmailProgress;

  Future<MessageExportResult> exportAllXmppMessages() async {
    const int chatExportStart = 0;
    const int chatExportEnd = 0;
    final chats = await _xmppService.loadChats(
      start: chatExportStart,
      end: chatExportEnd,
    );
    return exportXmppMessages(chats: chats, fileLabel: 'xmpp-messages');
  }

  Future<MessageExportResult> exportAllEmailMessages() async {
    const int chatExportStart = 0;
    const int chatExportEnd = 0;
    final chats = await _xmppService.loadChats(
      start: chatExportStart,
      end: chatExportEnd,
    );
    return exportEmailMessages(chats: chats);
  }

  Future<MessageExportResult> exportSelectedMessages({
    required List<Chat> chats,
  }) async {
    final emailChats = _emailMessageChats(chats).toList(growable: false);
    final xmppChats = _xmppMessageChats(chats).toList(growable: false);
    if (xmppChats.isEmpty && emailChats.isEmpty) {
      return const MessageExportResult.empty();
    }
    if (xmppChats.isEmpty) {
      return exportEmailMessages(chats: emailChats);
    }
    if (emailChats.isEmpty) {
      return exportXmppMessages(chats: xmppChats);
    }
    return _exportMixedMessages(xmppChats: xmppChats, emailChats: emailChats);
  }

  Future<MessageExportResult> exportXmppMessages({
    required List<Chat> chats,
    String? fileLabel,
    bool Function(Message message)? messageFilter,
  }) async {
    final selectedChats = _xmppMessageChats(chats).toList(growable: false);
    if (selectedChats.isEmpty) {
      return const MessageExportResult.empty();
    }
    final exportResult = await ChatHistoryExporter.exportChats(
      chats: selectedChats,
      loadHistory: (jid) => _xmppService.loadCompleteChatHistory(jid: jid),
      countHistory: _xmppService.countChatMessages,
      loadHistoryPage: ({required jid, required offset, required limit}) =>
          _xmppService.loadChatMessagesPage(jid, start: offset, end: limit),
      fileLabel: fileLabel,
      messageFilter: messageFilter,
    );
    final file = exportResult.file;
    if (!exportResult.hasContent || file == null) {
      return const MessageExportResult.empty();
    }
    return MessageExportResult.success(
      file: file,
      itemCount: exportResult.messageCount,
    );
  }

  Future<MessageExportResult> exportEmailMessages({
    required List<Chat> chats,
  }) async {
    final emailService = _emailService;
    if (emailService == null) {
      return const MessageExportResult.failure();
    }
    final selectedChats = _emailMessageChats(chats).toList(growable: false);
    if (selectedChats.isEmpty) {
      return const MessageExportResult.empty();
    }
    try {
      final exportResult = await EmailEmlExporter.exportMessages(
        chats: selectedChats,
        loadHistory: (jid) => _xmppService.loadCompleteChatHistory(jid: jid),
        countHistory: _xmppService.countChatMessages,
        loadHistoryPage: ({required jid, required offset, required limit}) =>
            _xmppService.loadChatMessagesPage(jid, start: offset, end: limit),
        prepareEmailContentPage: _prepareEmailEmlPage,
        loadRfcEmailGroup: _xmppService.loadEmailMessagesByRfcGroup,
        loadMessageAttachmentsForMessages:
            _xmppService.loadMessageAttachmentsForMessages,
        loadMessageAttachmentsForGroup:
            _xmppService.loadMessageAttachmentsForGroup,
        loadFileMetadataByIds: _xmppService.loadFileMetadataByIds,
        loadEmailContent: _loadEmailEmlContent,
        onProgress: _onEmailProgress,
      );
      if (exportResult.warnings.isNotEmpty) {
        return MessageExportResult.incomplete(
          file: exportResult.file,
          itemCount: exportResult.messageCount,
          warnings: exportResult.warnings,
        );
      }
      return MessageExportResult.success(
        file: exportResult.file,
        itemCount: exportResult.messageCount,
      );
    } on EmailEmlExportEmptyException {
      return const MessageExportResult.empty();
    } on EmailEmlExportIncompleteException catch (error) {
      return MessageExportResult.incomplete(warnings: error.warnings);
    } on Exception {
      return const MessageExportResult.failure();
    }
  }

  Iterable<Chat> _xmppMessageChats(List<Chat> chats) =>
      chats.where((chat) => chat.transport == MessageTransport.xmpp);

  Iterable<Chat> _emailMessageChats(List<Chat> chats) => chats.where(
    (chat) => chat.transport == MessageTransport.email || chat.isEmailBacked,
  );

  Future<MessageExportResult> _exportMixedMessages({
    required List<Chat> xmppChats,
    required List<Chat> emailChats,
  }) async {
    final xmppResult = await exportXmppMessages(
      chats: xmppChats,
      fileLabel: 'xmpp-messages',
      messageFilter: _isXmppTranscriptMessage,
    );
    final emailResult = await exportEmailMessages(chats: emailChats);
    final warnings = _mixedExportWarnings(
      xmppResult: xmppResult,
      emailResult: emailResult,
    );
    final incompleteWithFile =
        xmppResult.outcome == MessageExportOutcome.incomplete ||
        emailResult.outcome == MessageExportOutcome.incomplete ||
        xmppResult.outcome == MessageExportOutcome.failure ||
        emailResult.outcome == MessageExportOutcome.failure;
    final parts = <({String path, File file})>[];
    if (xmppResult.file case final File file) {
      parts.add((path: 'xmpp/${p.basename(file.path)}', file: file));
    }
    if (emailResult.file case final File file) {
      parts.add((path: 'email/${p.basename(file.path)}', file: file));
    }
    if (parts.isEmpty) {
      if (xmppResult.outcome == MessageExportOutcome.failure ||
          emailResult.outcome == MessageExportOutcome.failure) {
        return const MessageExportResult.failure();
      }
      if (xmppResult.outcome == MessageExportOutcome.incomplete ||
          emailResult.outcome == MessageExportOutcome.incomplete) {
        return MessageExportResult.incomplete(warnings: warnings);
      }
      return const MessageExportResult.empty();
    }
    final directory = await appOwnedTemporaryDirectory(
      messageExportTempDirectoryName,
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipFile = File(p.join(directory.path, 'messages-$timestamp.zip'));
    final warningsFile = File(
      p.join(directory.path, 'warnings-$timestamp.txt'),
    );
    final encoder = ZipFileEncoder();
    var zipOpen = false;
    try {
      encoder.create(zipFile.path);
      zipOpen = true;
      for (final part in parts) {
        await encoder.addFile(part.file, part.path);
      }
      if (incompleteWithFile) {
        await _writeMessageWarningsFile(file: warningsFile, warnings: warnings);
        await encoder.addFile(warningsFile, 'warnings.txt');
      }
      await encoder.close();
      zipOpen = false;
    } catch (_) {
      if (zipOpen) {
        try {
          await encoder.close();
        } on Exception {
          // Preserve the export failure.
        }
      }
      try {
        if (await zipFile.exists()) {
          await zipFile.delete();
        }
      } on Exception {
        // Preserve the export failure.
      }
      return const MessageExportResult.failure();
    } finally {
      try {
        if (await warningsFile.exists()) {
          await warningsFile.delete();
        }
      } on Exception {
        // Best-effort temp cleanup.
      }
      for (final part in parts) {
        try {
          if (await part.file.exists()) {
            await part.file.delete();
          }
        } on Exception {
          // Best-effort temp cleanup.
        }
      }
    }
    final itemCount = xmppResult.itemCount + emailResult.itemCount;
    if (incompleteWithFile) {
      return MessageExportResult.incomplete(
        file: zipFile,
        itemCount: itemCount,
        warnings: warnings,
      );
    }
    return MessageExportResult.success(
      file: zipFile,
      itemCount: itemCount,
      warnings: warnings,
    );
  }

  bool _isXmppTranscriptMessage(Message message) => !message.isEmailBacked;

  Future<List<Message>> _prepareEmailEmlPage({
    required Chat chat,
    required List<Message> messages,
  }) async {
    final emailService = _emailService;
    if (emailService == null || messages.isEmpty) {
      return messages;
    }
    final candidates = messages
        .where(_messageNeedsEmailEmlPreparation)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return _refreshEmailEmlMessages(messages);
    }
    emailService.reportVisibleEmailContentMessages(
      chatJid: chat.jid,
      messages: candidates,
    );
    try {
      await _prepareEmailEmlMessages(emailService, candidates);
    } finally {
      emailService.clearVisibleEmailContentMessages(chat.jid);
    }
    return _refreshEmailEmlMessages(messages);
  }

  bool _messageNeedsEmailEmlPreparation(Message message) {
    final deltaMsgId = message.deltaMsgId;
    return message.isEmailBacked &&
        deltaMsgId != null &&
        deltaMsgId > 0 &&
        !message.rfc822BodyContentUnavailable;
  }

  Future<void> _prepareEmailEmlMessages(
    EmailService emailService,
    List<Message> messages,
  ) async {
    var nextIndex = 0;
    final workerCount = _boundedEmailExportWorkerCount(messages.length);
    Future<void> runWorker() async {
      while (true) {
        final index = nextIndex;
        nextIndex++;
        if (index >= messages.length) {
          return;
        }
        try {
          await emailService.requestEmailContentPreparation(
            messages[index],
            priority: EmailContentPreparationPriority.manual,
          );
        } on Exception {
          // Export resolution will record any missing content warning.
        }
      }
    }

    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => runWorker()),
    );
  }

  int _boundedEmailExportWorkerCount(int messageCount) {
    if (messageCount <= 0) {
      return 0;
    }
    if (messageCount < _emailExportContentPreparationConcurrency) {
      return messageCount;
    }
    return _emailExportContentPreparationConcurrency;
  }

  Future<List<Message>> _refreshEmailEmlMessages(List<Message> messages) async {
    final refreshed = <Message>[];
    for (final message in messages) {
      try {
        refreshed.add(
          await _xmppService.loadMessageByStanzaId(message.stanzaID) ?? message,
        );
      } on Exception {
        refreshed.add(message);
      }
    }
    return refreshed;
  }

  Future<EmailEmlContent> _loadEmailEmlContent(Message message) async {
    final emailService = _emailService;
    if (emailService == null || !message.isEmailBacked) {
      return const EmailEmlContent();
    }
    var preparedMessage = message;
    try {
      preparedMessage =
          await _xmppService.loadMessageByStanzaId(message.stanzaID) ?? message;
    } catch (_) {
      // Keep the original row if a best-effort refresh is unavailable.
    }

    String? mimeHeaders;
    try {
      mimeHeaders = await emailService.getMessageRawHeadersForMessage(
        preparedMessage,
      );
    } on Exception {
      // Synthesized headers are still valid for export.
    }

    String? rfc822PlainText;
    String? rfc822HtmlBody;
    final bodyUnavailable = preparedMessage.rfc822BodyContentUnavailable;
    final canReadDeltaBody =
        preparedMessage.hasRfc822BodyContent ||
        bodyUnavailable ||
        !preparedMessage.rfc822BodyStatus.isPendingDownload;
    if (canReadDeltaBody) {
      try {
        final rfc822Body = await emailService.getMessageRfc822Body(
          preparedMessage,
        );
        rfc822PlainText = rfc822Body?.plainText;
        rfc822HtmlBody = rfc822Body?.htmlBody;
      } on Exception {
        // Fall back to stored body or full HTML below.
      }
    }
    final deltaMsgId = preparedMessage.deltaMsgId;
    if (preparedMessage.hasRfc822BodyContent ||
        deltaMsgId == null ||
        deltaMsgId <= 0) {
      rfc822PlainText ??= preparedMessage.body;
      rfc822HtmlBody ??= preparedMessage.htmlBody;
    }

    String? fullHtml;
    final hasRfc822Body =
        rfc822PlainText?.trim().isNotEmpty == true ||
        rfc822HtmlBody?.trim().isNotEmpty == true;
    final hasStoredHydratedBody =
        preparedMessage.hasRfc822BodyContent &&
        (preparedMessage.body?.trim().isNotEmpty == true ||
            preparedMessage.htmlBody?.trim().isNotEmpty == true);
    if (canReadDeltaBody &&
        !hasRfc822Body &&
        !hasStoredHydratedBody &&
        !bodyUnavailable) {
      try {
        fullHtml = await emailService.getMessageFullHtml(preparedMessage);
      } on Exception {
        // Missing body content is reported after fallback resolution.
      }
    }

    return EmailEmlContent(
      mimeHeaders: mimeHeaders,
      rfc822PlainText: rfc822PlainText,
      rfc822HtmlBody: rfc822HtmlBody,
      fullHtml: fullHtml,
      bodyUnavailable: bodyUnavailable,
    );
  }
}

List<String> _mixedExportWarnings({
  required MessageExportResult xmppResult,
  required MessageExportResult emailResult,
}) {
  final warnings = <String>[...xmppResult.warnings, ...emailResult.warnings];
  if (xmppResult.outcome == MessageExportOutcome.failure) {
    warnings.add('XMPP message export failed.');
  }
  if (emailResult.outcome == MessageExportOutcome.failure) {
    warnings.add('Email message export failed.');
  }
  return warnings;
}

Future<void> _writeMessageWarningsFile({
  required File file,
  required List<String> warnings,
}) async {
  final sink = file.openWrite();
  try {
    sink.writeln('Axichat message export warnings');
    sink.writeln();
    for (final warning in warnings) {
      sink.writeln('- $warning');
    }
  } finally {
    await sink.flush();
    await sink.close();
  }
}
