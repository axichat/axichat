import 'dart:io';

import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
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

    test('ensureGuestStorage registers and seeds legacy model', () async {
      final legacyTask = CalendarTask.create(title: 'legacy');
      final legacyModel = CalendarModel.empty().addTask(legacyTask);

      final storage =
          await manager.ensureGuestStorage(legacyModel: legacyModel);

      expect(registry.storageForPrefix(guestStoragePrefix), same(storage));
      final token = '${guestStoragePrefix}state';
      final cached = storage.read(token) as Map<String, dynamic>?;
      expect(cached, isNotNull);
      final modelJson = cached!['model'] as Map<String, dynamic>;
      final tasksJson = modelJson['tasks'] as Map<String, dynamic>;
      expect(tasksJson.values, isNotEmpty);
    });

    test('ensureAuthStorage registers encrypted storage and seeds once',
        () async {
      final legacyTask = CalendarTask.create(title: 'auth-legacy');
      final legacyModel = CalendarModel.empty().addTask(legacyTask);

      final storage = await manager.ensureAuthStorage(
        passphrase: 'secret-passphrase',
        legacyModel: legacyModel,
      );

      expect(registry.storageForPrefix(authStoragePrefix), same(storage));
      final token = '${authStoragePrefix}state';
      final cached = storage.read(token) as Map<String, dynamic>?;
      expect(cached, isNotNull);
      final modelJson = cached!['model'] as Map<String, dynamic>;
      final tasksJson = modelJson['tasks'] as Map<String, dynamic>;
      expect(tasksJson.values, isNotEmpty);

      // Subsequent calls reuse the same storage without reseeding.
      final secondCall = await manager.ensureAuthStorage(
        passphrase: 'secret-passphrase',
        legacyModel: CalendarModel.empty(),
      );
      expect(identical(storage, secondCall), isTrue);
      final reseeded = secondCall.read(token) as Map<String, dynamic>?;
      expect(reseeded, cached);
    });
  });
}
