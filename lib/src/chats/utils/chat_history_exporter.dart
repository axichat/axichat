// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:intl/intl.dart' as intl;
import 'package:path_provider/path_provider.dart';

import 'package:axichat/src/storage/models.dart';

class ChatExportResult {
  const ChatExportResult._({
    this.file,
    this.chatCount = 0,
    this.messageCount = 0,
  });

  const ChatExportResult.empty() : this._();

  final File? file;
  final int chatCount;
  final int messageCount;

  bool get hasContent => file != null && messageCount > 0;
}

class ChatHistoryExporter {
  const ChatHistoryExporter._();

  static Future<ChatExportResult> exportChats({
    required List<Chat> chats,
    required Future<List<Message>> Function(String jid) loadHistory,
    String? fileLabel,
    intl.DateFormat? dateFormat,
    String? Function({
      required Chat chat,
      required Message message,
      required intl.DateFormat format,
    })?
    lineFormatter,
    Future<int> Function(String jid)? countHistory,
    Future<List<Message>> Function({
      required String jid,
      required int offset,
      required int limit,
    })?
    loadHistoryPage,
  }) async {
    if (chats.isEmpty) return const ChatExportResult.empty();
    final format = dateFormat ?? intl.DateFormat('y-MM-dd HH:mm');
    final initialLabel =
        fileLabel ??
        _defaultFileLabel(chats, chats.length == 1 ? chats.first : null);
    final file = await _createExportFile(initialLabel);
    final sink = file.openWrite();
    var exportedChats = 0;
    var exportedMessages = 0;
    for (final chat in chats) {
      final appended = await _writeChatHistory(
        sink: sink,
        chat: chat,
        format: format,
        loadHistory: loadHistory,
        countHistory: countHistory,
        loadHistoryPage: loadHistoryPage,
        lineFormatter: lineFormatter,
      );
      if (appended == 0) {
        continue;
      }
      exportedChats++;
      exportedMessages += appended;
      sink.writeln();
    }
    await sink.flush();
    await sink.close();
    if (exportedMessages == 0) {
      await cleanupExportFile(file);
      return const ChatExportResult.empty();
    }
    final finalLabel =
        fileLabel ??
        _defaultFileLabel(chats, exportedChats == 1 ? chats.first : null);
    final resolvedFile = finalLabel == initialLabel
        ? file
        : await _renameExportFile(file, finalLabel);
    return ChatExportResult._(
      file: resolvedFile,
      chatCount: exportedChats,
      messageCount: exportedMessages,
    );
  }

  static Future<void> cleanupExportFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on Exception {
      return;
    }
  }

  static String sanitizeLabel(String input) {
    final trimmed = input.trim().toLowerCase();
    final sanitized = trimmed.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    return sanitized.isEmpty ? 'thread' : sanitized;
  }

  static Future<File> _createExportFile(String label) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${sanitizeLabel(label)}-$timestamp.txt';
    return File('${tempDir.path}/$fileName');
  }

  static Future<File> _renameExportFile(File file, String label) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${sanitizeLabel(label)}-$timestamp.txt';
      return file.rename('${tempDir.path}/$fileName');
    } on Exception {
      return file;
    }
  }

  static Future<int> _writeChatHistory({
    required IOSink sink,
    required Chat chat,
    required intl.DateFormat format,
    required Future<List<Message>> Function(String jid) loadHistory,
    Future<int> Function(String jid)? countHistory,
    Future<List<Message>> Function({
      required String jid,
      required int offset,
      required int limit,
    })?
    loadHistoryPage,
    String? Function({
      required Chat chat,
      required Message message,
      required intl.DateFormat format,
    })?
    lineFormatter,
  }) async {
    if (loadHistoryPage != null && countHistory != null) {
      final total = await countHistory(chat.jid);
      if (total == 0) return 0;
      const pageSize = 200;
      var remaining = total;
      var appended = 0;
      _writeChatHeader(sink, chat);
      while (remaining > 0) {
        final offset = remaining > pageSize ? remaining - pageSize : 0;
        final limit = remaining - offset;
        final page = await loadHistoryPage(
          jid: chat.jid,
          offset: offset,
          limit: limit,
        );
        if (page.isEmpty) break;
        for (final message in page.reversed) {
          final line = lineFormatter?.call(
            chat: chat,
            message: message,
            format: format,
          );
          final content = line ?? _defaultMessageLine(message, format: format);
          if (content == null || content.isEmpty) continue;
          sink.writeln(content);
          appended++;
        }
        remaining = offset;
      }
      return appended;
    }

    final history = await loadHistory(chat.jid);
    if (history.isEmpty) return 0;
    var appended = 0;
    _writeChatHeader(sink, chat);
    for (final message in history) {
      final line = lineFormatter?.call(
        chat: chat,
        message: message,
        format: format,
      );
      final content = line ?? _defaultMessageLine(message, format: format);
      if (content == null || content.isEmpty) continue;
      sink.writeln(content);
      appended++;
    }
    return appended;
  }

  static void _writeChatHeader(IOSink sink, Chat chat) {
    sink
      ..writeln('=== ${chat.title} (${chat.jid}) ===')
      ..writeln();
  }

  static String? _defaultMessageLine(
    Message message, {
    required intl.DateFormat format,
  }) {
    final content = message.body?.trim();
    if (content == null || content.isEmpty) return null;
    final timestampValue =
        message.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
    final timestamp = format.format(timestampValue);
    final author = message.senderJid;
    return '[$timestamp] $author: $content';
  }

  static String _defaultFileLabel(List<Chat> chats, Chat? singleChat) {
    if (singleChat != null) {
      return 'chat-${sanitizeLabel(singleChat.title)}';
    }
    if (chats.length == 1) {
      return 'chat-${sanitizeLabel(chats.single.title)}';
    }
    return 'chats';
  }
}
