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

enum CalendarSyncDispatchOutcome {
  applied,
  handledNoChange,
  unavailable,
  failed;

  static CalendarSyncDispatchOutcome fromApplied(bool applied) {
    return applied
        ? CalendarSyncDispatchOutcome.applied
        : CalendarSyncDispatchOutcome.handledNoChange;
  }

  bool get didApply => this == CalendarSyncDispatchOutcome.applied;

  bool get wasHandled =>
      this == CalendarSyncDispatchOutcome.applied ||
      this == CalendarSyncDispatchOutcome.handledNoChange;
}

class CalendarSyncDispatch {
  CalendarSyncDispatch({
    required this.inbound,
    Completer<CalendarSyncDispatchOutcome>? completer,
  }) : _completer = completer ?? Completer<CalendarSyncDispatchOutcome>();

  final CalendarSyncInbound inbound;
  final Completer<CalendarSyncDispatchOutcome> _completer;

  Future<CalendarSyncDispatchOutcome> get result => _completer.future;

  void complete(bool applied) {
    completeOutcome(CalendarSyncDispatchOutcome.fromApplied(applied));
  }

  void completeOutcome(CalendarSyncDispatchOutcome outcome) {
    if (_completer.isCompleted) {
      return;
    }
    _completer.complete(outcome);
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (_completer.isCompleted) {
      return;
    }
    _completer.completeError(error, stackTrace);
  }
}

class ChatCalendarSyncDispatch {
  ChatCalendarSyncDispatch({required this.envelope, Completer<bool>? completer})
    : _completer = completer ?? Completer<bool>();

  final ChatCalendarSyncEnvelope envelope;
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

typedef ChatCalendarSyncHandler =
    Future<bool> Function(ChatCalendarSyncEnvelope envelope);
