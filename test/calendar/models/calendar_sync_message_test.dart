import 'dart:convert';

import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarSyncMessage timestamps', () {
    test('factory constructors emit UTC timestamps', () {
      expect(CalendarSyncMessage.request().timestamp.isUtc, isTrue);
      expect(
        CalendarSyncMessage.full(
          data: const <String, dynamic>{},
          checksum: 'x',
        ).timestamp.isUtc,
        isTrue,
      );
      expect(
        CalendarSyncMessage.update(
          taskId: 'task',
          operation: 'update',
        ).timestamp.isUtc,
        isTrue,
      );
      expect(
        CalendarSyncMessage.snapshot(
          snapshotChecksum: 'checksum',
          snapshotVersion: 1,
          snapshotUrl: 'https://example.com/snapshot.axical.gz',
        ).timestamp.isUtc,
        isTrue,
      );
    });

    test('parsed envelope normalizes timestamp to UTC', () {
      final CalendarSyncMessage localTimestampMessage = CalendarSyncMessage(
        type: CalendarSyncType.update,
        timestamp: DateTime(2024, 3, 5, 9, 30),
        taskId: 'task',
        operation: 'update',
      );
      final String envelope = jsonEncode(<String, dynamic>{
        'calendar_sync': localTimestampMessage.toJson(),
      });

      final CalendarSyncMessage? parsed = CalendarSyncMessage.tryParseEnvelope(
        envelope,
      );

      expect(parsed, isNotNull);
      expect(parsed!.timestamp.isUtc, isTrue);
    });
  });
}
