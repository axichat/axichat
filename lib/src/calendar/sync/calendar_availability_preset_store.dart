// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/storage/state_store.dart';

const String _availabilityPresetStoreKey = 'calendar_availability_preset_v1';

class CalendarAvailabilityPresetStore {
  CalendarAvailabilityPresetStore({
    XmppStateStore? stateStore,
  }) : _stateStore = stateStore ?? XmppStateStore();

  final XmppStateStore _stateStore;
  static final RegisteredStateKey _storeKey =
      XmppStateStore.registerKey(_availabilityPresetStoreKey);

  Map<String, CalendarAvailabilityPreset> readAll() {
    final raw = _stateStore.read(key: _storeKey);
    if (raw is! Map) {
      return <String, CalendarAvailabilityPreset>{};
    }
    final records = <String, CalendarAvailabilityPreset>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! Map) {
        continue;
      }
      final record = CalendarAvailabilityPreset.fromJson(
        Map<String, dynamic>.from(value),
      );
      if (record == null) {
        continue;
      }
      records[key] = record;
    }
    return records;
  }

  Future<void> writeAll(
    Map<String, CalendarAvailabilityPreset> records,
  ) async {
    final encoded = records.map(
      (key, record) => MapEntry(key, record.toJson()),
    );
    await _stateStore.write(key: _storeKey, value: encoded);
  }

  Future<void> upsert(CalendarAvailabilityPreset record) async {
    final records = readAll()..[record.id] = record;
    await writeAll(records);
  }

  Future<void> remove(String id) async {
    final records = readAll()..remove(id);
    await writeAll(records);
  }
}
