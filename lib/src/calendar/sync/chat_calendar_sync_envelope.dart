// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/storage/models/chat_models.dart';

class ChatCalendarSyncEnvelope {
  const ChatCalendarSyncEnvelope({
    required this.chatJid,
    required this.chatType,
    required this.senderJid,
    required this.inbound,
  });

  final String chatJid;
  final ChatType chatType;
  final String senderJid;
  final CalendarSyncInbound inbound;
}

class CalendarSyncDispatch {
  CalendarSyncDispatch({required this.inbound, Completer<bool>? completer})
    : _completer = completer ?? Completer<bool>();

  final CalendarSyncInbound inbound;
  final Completer<bool> _completer;

  Future<bool> get result => _completer.future;

  void complete(bool applied) {
    if (_completer.isCompleted) {
      return;
    }
    _completer.complete(applied);
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (_completer.isCompleted) {
      return;
    }
    _completer.completeError(error, stackTrace);
  }
}

class ChatCalendarSyncDispatch {
  ChatCalendarSyncDispatch({required this.envelope, Completer<void>? completer})
    : _completer = completer ?? Completer<void>();

  final ChatCalendarSyncEnvelope envelope;
  final Completer<void> _completer;

  Future<void> get result => _completer.future;

  void complete() {
    if (_completer.isCompleted) {
      return;
    }
    _completer.complete();
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (_completer.isCompleted) {
      return;
    }
    _completer.completeError(error, stackTrace);
  }
}

typedef ChatCalendarSyncHandler =
    Future<void> Function(ChatCalendarSyncEnvelope envelope);
