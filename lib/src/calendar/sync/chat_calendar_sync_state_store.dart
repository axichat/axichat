// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/sync/calendar_sync_state.dart';
import 'package:axichat/src/calendar/storage/chat_calendar_storage.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

class ChatCalendarSyncStateStore {
  const ChatCalendarSyncStateStore({Storage? storage}) : _storage = storage;

  final Storage? _storage;

  CalendarSyncState read(String chatJid) {
    return readOrNull(chatJid) ?? const CalendarSyncState();
  }

  CalendarSyncState? readOrNull(String chatJid) {
    final storage = _resolvedStorage();
    if (storage == null) {
      return null;
    }
    final raw = storage.read(_storageKey(chatJid));
    if (raw == null || raw is! String) {
      return null;
    }
    try {
      return CalendarSyncState.fromJson(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> write(String chatJid, CalendarSyncState state) async {
    final storage = _resolvedStorage();
    if (storage == null) {
      return;
    }
    await storage.write(_storageKey(chatJid), state.toJson());
  }

  Future<void> delete(String chatJid) async {
    final storage = _resolvedStorage();
    if (storage == null) {
      return;
    }
    await storage.delete(_storageKey(chatJid));
  }

  Storage? _resolvedStorage() {
    try {
      return _storage ?? HydratedBloc.storage;
    } on StorageNotFound {
      return null;
    }
  }

  String _storageKey(String chatJid) {
    return '$authStoragePrefix${chatCalendarSyncStateKey(chatJid)}';
  }
}

class LegacyChatCalendarSyncStateStore {
  const LegacyChatCalendarSyncStateStore();

  CalendarSyncState read(String chatJid) {
    final raw = XmppStateStore().read(key: _stateKey(chatJid));
    if (raw == null || raw is! String) {
      return const CalendarSyncState();
    }
    try {
      return CalendarSyncState.fromJson(raw);
    } on FormatException {
      return const CalendarSyncState();
    }
  }

  RegisteredStateKey _stateKey(String chatJid) {
    return XmppStateStore.registerKey(chatCalendarSyncStateKey(chatJid));
  }
}
