import 'dart:convert';

import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/database_extensions.dart';

class DayEventRepository {
  DayEventRepository({required Future<XmppDatabase> database})
      : _databaseFuture = database;

  final Future<XmppDatabase> _databaseFuture;

  Future<XmppDatabase> get _database => _databaseFuture;

  Stream<List<DayEvent>> watchDayEvents(
    DateTime start,
    DateTime end,
  ) async* {
    final XmppDatabase db = await _database;
    yield* db
        .watchDayEvents(
          start: _normalizeDate(start),
          end: _normalizeDate(end),
        )
        .map(_mapEntries);
  }

  Future<List<DayEvent>> loadDayEvents(
    DateTime start,
    DateTime end,
  ) async {
    final XmppDatabase db = await _database;
    final List<DayEventEntry> entries = await db.getDayEvents(
      start: _normalizeDate(start),
      end: _normalizeDate(end),
    );
    return _mapEntries(entries);
  }

  Future<void> upsert(DayEvent event) async {
    final XmppDatabase db = await _database;
    final DayEvent normalized = event.normalizedCopy();
    await db.executeOperation(
      operationName: 'save day event ${event.id}',
      operation: () => db.saveDayEvent(_toEntry(normalized)),
    );
  }

  Future<void> delete(String id) async {
    final XmppDatabase db = await _database;
    await db.executeOperation(
      operationName: 'delete day event $id',
      operation: () => db.deleteDayEvent(id),
    );
  }

  Future<void> replaceAll(Iterable<DayEvent> events) async {
    final XmppDatabase db = await _database;
    final List<DayEventEntry> entries =
        events.map(_toEntry).toList(growable: false);
    await db.executeOperation(
      operationName: 'replace day events',
      operation: () => db.replaceDayEvents(entries),
    );
  }

  List<DayEvent> _mapEntries(Iterable<DayEventEntry> entries) {
    final List<DayEvent> mapped =
        entries.map(_fromEntry).toList(growable: false);
    mapped.sort((DayEvent a, DayEvent b) => a.startDate.compareTo(b.startDate));
    return mapped;
  }

  DayEventEntry _toEntry(DayEvent event) {
    final DayEvent normalized = event.normalizedCopy();
    return DayEventEntry(
      id: normalized.id,
      title: normalized.title,
      startDate: _normalizeDate(normalized.startDate),
      endDate: _normalizeDate(normalized.normalizedEnd),
      description: normalized.description,
      reminders: jsonEncode(normalized.effectiveReminders.toJson()),
      createdAt: normalized.createdAt,
      modifiedAt: normalized.modifiedAt,
    );
  }

  DayEvent _fromEntry(DayEventEntry entry) {
    final ReminderPreferences reminders = _parseReminders(entry.reminders);
    return DayEvent(
      id: entry.id,
      title: entry.title,
      startDate: entry.startDate,
      endDate: entry.endDate,
      description: entry.description,
      reminders: reminders,
      createdAt: entry.createdAt,
      modifiedAt: entry.modifiedAt,
    );
  }

  ReminderPreferences _parseReminders(String raw) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ReminderPreferences.fromJson(decoded).normalized();
      }
    } catch (_) {
      // Swallow and fall back to defaults below.
    }
    return ReminderPreferences.defaults();
  }
}

DateTime _normalizeDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);
