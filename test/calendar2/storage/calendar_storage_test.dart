import 'dart:io';

import 'package:axichat/src/calendar2/storage/auth_calendar_storage.dart';
import 'package:axichat/src/calendar2/storage/guest_calendar_storage.dart';
import 'package:axichat/src/calendar2/storage/calendar_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('calendar2_storage_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('calendar2_auth');
    await Hive.deleteBoxFromDisk('calendar2_guest');
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('guest storage persists and retrieves values', () async {
    final storage = await buildGuestCalendarStorage();

    await storage.write('state', {'foo': 'bar'});
    expect(storage.read('state'), {'foo': 'bar'});

    await storage.delete('state');
    expect(storage.read('state'), isNull);

    await storage.close();
  });

  test('auth storage encrypts data with provided key', () async {
    final key = deriveCalendarStorageKey('secret');
    final storage = await buildAuthCalendarStorage(encryptionKey: key);

    await storage.write('state', {'secret': true});
    expect(storage.read('state'), {'secret': true});

    await storage.clear();
    expect(storage.read('state'), isNull);

    await storage.close();
  });

  test('guest and auth storage share box without clobbering keys', () async {
    final guest = await buildGuestCalendarStorage();
    final auth = await buildAuthCalendarStorage(
      encryptionKey: deriveCalendarStorageKey('another secret'),
    );

    await guest.write('state', {'guest': 1});
    await auth.write('state', {'auth': 2});

    expect(guest.read('state'), {'guest': 1});
    expect(auth.read('state'), {'auth': 2});

    await guest.close();
    await auth.close();
  });

  test('calendar storage namespaces keys', () async {
    final storage = await Calendar2HydratedStorage.open(
      boxName: 'guest_calendar',
      keyPrefix: 'custom',
    );

    await storage.write('key', 42);
    await storage.write('other', 7);
    await storage.clear();

    expect(storage.read('key'), isNull);
    expect(storage.read('other'), isNull);

    await storage.close();
  });
}
