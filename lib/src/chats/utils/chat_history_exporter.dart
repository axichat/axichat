// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:intl/intl.dart' as intl;
import 'package:path_provider/path_provider.dart';

import 'package:axichat/src/storage/models.dart';

typedef ChatHistoryLoader = Future<List<Message>> Function(String jid);
typedef ChatHistoryMessageLineFormatter = String? Function({
  required Chat chat,
  required Message message,
  required intl.DateFormat format,
});

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
    required ChatHistoryLoader loadHistory,
    String? fileLabel,
    intl.DateFormat? dateFormat,
    ChatHistoryMessageLineFormatter? lineFormatter,
  }) async {
    if (chats.isEmpty) return const ChatExportResult.empty();
    final format = dateFormat ?? intl.DateFormat('y-MM-dd HH:mm');
    final buffer = StringBuffer();
    var exportedChats = 0;
    var exportedMessages = 0;
    for (final chat in chats) {
      final history = await loadHistory(chat.jid);
      final appended = _appendChatHistory(
        buffer: buffer,
        chat: chat,
        history: history,
        format: format,
        lineFormatter: lineFormatter,
      );
      if (appended == 0) continue;
      exportedChats++;
      exportedMessages += appended;
      buffer.writeln();
    }
    final text = buffer.toString().trim();
    if (text.isEmpty || exportedMessages == 0) {
      return const ChatExportResult.empty();
    }
    final label = fileLabel ??
        _defaultFileLabel(chats, exportedChats == 1 ? chats.first : null);
    final file = await _writeExportFile(text, label);
    return ChatExportResult._(
      file: file,
      chatCount: exportedChats,
      messageCount: exportedMessages,
    );
  }

  static String sanitizeLabel(String input) {
    final trimmed = input.trim().toLowerCase();
    final sanitized = trimmed.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    return sanitized.isEmpty ? 'thread' : sanitized;
  }

  static Future<File> _writeExportFile(String text, String label) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '$label-$timestamp.txt';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(text);
    return file;
  }

  static int _appendChatHistory({
    required StringBuffer buffer,
    required Chat chat,
    required List<Message> history,
    required intl.DateFormat format,
    ChatHistoryMessageLineFormatter? lineFormatter,
  }) {
    if (history.isEmpty) return 0;
    var appended = 0;
    buffer
      ..writeln('=== ${chat.title} (${chat.jid}) ===')
      ..writeln();
    for (final message in history) {
      final formatted = lineFormatter?.call(
        chat: chat,
        message: message,
        format: format,
      );
      final content = formatted ?? _defaultMessageLine(message, format: format);
      if (content == null || content.isEmpty) continue;
      buffer.writeln(content);
      appended++;
    }
    return appended;
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
