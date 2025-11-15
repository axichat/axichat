import 'dart:io';

import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_registry.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:hive/hive.dart';
import 'package:test/test.dart';

class _InMemoryStorage implements Storage {
  final Map<String, dynamic> _store = {};

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> close() async => _store.clear();

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  dynamic read(String key) => _store[key];

  @override
  Future<void> write(String key, dynamic value) async => _store[key] = value;
}

void main() {
  group('CalendarStorageManager', () {
    late Directory tempDir;
    late CalendarStorageRegistry registry;
    late CalendarStorageManager manager;
    late _InMemoryStorage fallbackStorage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('calendar_storage_test');
      Hive.init(tempDir.path);
      fallbackStorage = _InMemoryStorage();
      registry = CalendarStorageRegistry(fallback: fallbackStorage);
      HydratedBloc.storage = registry;
      manager = CalendarStorageManager(registry: registry);
    });

    tearDown(() async {
      await manager.guestStorage?.clear();
      await manager.guestStorage?.close();
      await manager.authStorage?.clear();
      await manager.authStorage?.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('ensureGuestStorage registers guest storage once', () async {
      final storage = await manager.ensureGuestStorage();

      expect(registry.storageForPrefix(guestStoragePrefix), same(storage));

      final secondCall = await manager.ensureGuestStorage();
      expect(identical(storage, secondCall), isTrue);
    });

    test('ensureAuthStorage registers encrypted storage once', () async {
      final storage = await manager.ensureAuthStorage(
        passphrase: 'secret-passphrase',
      );

      expect(registry.storageForPrefix(authStoragePrefix), same(storage));

      final secondCall = await manager.ensureAuthStorage(
        passphrase: 'secret-passphrase',
      );
      expect(identical(storage, secondCall), isTrue);
    });
  });
}
