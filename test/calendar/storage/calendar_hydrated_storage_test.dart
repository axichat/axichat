import 'package:axichat/src/calendar/storage/calendar_hydrated_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';

class _MockHiveInterface extends Mock implements HiveInterface {}

void main() {
  group('CalendarHydratedStorage', () {
    test('does not delete auth boxes when open fails', () async {
      final hive = _MockHiveInterface();
      when(() => hive.isAdapterRegistered(any())).thenReturn(true);
      when(() => hive.isBoxOpen('auth_calendar')).thenReturn(false);
      when(
        () => hive.openBox<dynamic>(
          'auth_calendar',
          encryptionCipher: null,
          path: null,
        ),
      ).thenThrow(Exception('open failed'));
      when(
        () => hive.deleteBoxFromDisk('auth_calendar'),
      ).thenAnswer((_) async {});

      await expectLater(
        CalendarHydratedStorage.open(
          boxName: 'auth_calendar',
          prefix: 'calendar_auth',
          hive: hive,
        ),
        throwsException,
      );

      verifyNever(() => hive.deleteBoxFromDisk('auth_calendar'));
    });
  });
}
