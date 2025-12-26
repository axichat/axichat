import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/storage/state_store.dart';

const String _availabilityShareStoreKey = 'calendar_availability_share_v1';

class CalendarAvailabilityShareStore {
  CalendarAvailabilityShareStore({
    XmppStateStore? stateStore,
  }) : _stateStore = stateStore ?? XmppStateStore();

  final XmppStateStore _stateStore;
  static final RegisteredStateKey _storeKey =
      XmppStateStore.registerKey(_availabilityShareStoreKey);

  Map<String, CalendarAvailabilityShareRecord> readAll() {
    final raw = _stateStore.read(key: _storeKey);
    if (raw is! Map) {
      return <String, CalendarAvailabilityShareRecord>{};
    }
    final records = <String, CalendarAvailabilityShareRecord>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! Map) {
        continue;
      }
      final record = CalendarAvailabilityShareRecord.fromJson(
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
    Map<String, CalendarAvailabilityShareRecord> records,
  ) async {
    final encoded = records.map(
      (key, record) => MapEntry(key, record.toJson()),
    );
    await _stateStore.write(key: _storeKey, value: encoded);
  }

  Future<void> upsert(CalendarAvailabilityShareRecord record) async {
    final records = readAll()..[record.id] = record;
    await writeAll(records);
  }

  Future<void> remove(String id) async {
    final records = readAll()..remove(id);
    await writeAll(records);
  }
}
