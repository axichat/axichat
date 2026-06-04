import 'dart:convert';
import 'dart:io';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:axichat/src/calendar/storage/calendar_linked_task_registry.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_registry.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:crypto/crypto.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:hive_ce/hive.dart';
import 'package:flutter_test/flutter_test.dart';

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
      await Hive.close();
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
        accountAddress: 'account-a@example.com',
        passphrase: 'secret-passphrase',
        storageRootPath: tempDir.path,
      );

      expect(registry.storageForPrefix(authStoragePrefix), same(storage));

      final secondCall = await manager.ensureAuthStorage(
        accountAddress: 'account-a@example.com',
        passphrase: 'secret-passphrase',
        storageRootPath: tempDir.path,
      );
      expect(identical(storage, secondCall), isTrue);
    });

    test(
      'switches authenticated storage without leaking account data',
      () async {
        final accountADirectory = await Directory(
          '${tempDir.path}/account-a',
        ).create();
        final accountBDirectory = await Directory(
          '${tempDir.path}/account-b',
        ).create();

        Hive.init(accountADirectory.path);
        final firstStorage = await manager.ensureAuthStorage(
          accountAddress: 'first@example.com',
          passphrase: 'first-passphrase',
          storageRootPath: tempDir.path,
        );
        await firstStorage.write(authStoragePrefix, {'account': 'first'});

        Hive.init(accountBDirectory.path);
        final secondStorage = await manager.ensureAuthStorage(
          accountAddress: 'second@example.com',
          passphrase: 'second-passphrase',
          storageRootPath: tempDir.path,
        );

        expect(identical(firstStorage, secondStorage), isFalse);
        expect(
          registry.storageForPrefix(authStoragePrefix),
          same(secondStorage),
        );
        expect(secondStorage.read(authStoragePrefix), isNull);
        await secondStorage.write(authStoragePrefix, {'account': 'second'});

        Hive.init(accountADirectory.path);
        final restoredFirstStorage = await manager.ensureAuthStorage(
          accountAddress: 'first@example.com',
          passphrase: 'first-passphrase',
          storageRootPath: tempDir.path,
        );

        expect(restoredFirstStorage.read(authStoragePrefix), {
          'account': 'first',
        });
      },
    );

    test(
      'opens empty account storage when database passphrase changes',
      () async {
        final storage = await manager.ensureAuthStorage(
          accountAddress: 'account-a@example.com',
          passphrase: 'first-passphrase',
          storageRootPath: tempDir.path,
        );
        await storage.write(authStoragePrefix, {'account': 'first'});

        final restoredStorage = await manager.ensureAuthStorage(
          accountAddress: 'account-a@example.com',
          passphrase: 'second-passphrase',
          storageRootPath: tempDir.path,
        );

        expect(restoredStorage.read(authStoragePrefix), isNull);
        await restoredStorage.write(authStoragePrefix, {'account': 'second'});

        final originalStorage = await manager.ensureAuthStorage(
          accountAddress: 'account-a@example.com',
          passphrase: 'first-passphrase',
          storageRootPath: tempDir.path,
        );

        expect(originalStorage.read(authStoragePrefix), {'account': 'first'});
      },
    );

    test('isolates accounts that use the same passphrase', () async {
      final sharedPassphrase = 'shared-passphrase';

      final firstStorage = await manager.ensureAuthStorage(
        accountAddress: 'first@example.com',
        passphrase: sharedPassphrase,
        storageRootPath: tempDir.path,
      );
      await firstStorage.write(authStoragePrefix, {'account': 'first'});

      final secondStorage = await manager.ensureAuthStorage(
        accountAddress: 'second@example.com',
        passphrase: sharedPassphrase,
        storageRootPath: tempDir.path,
      );

      expect(secondStorage.read(authStoragePrefix), isNull);
      await secondStorage.write(authStoragePrefix, {'account': 'second'});

      final restoredFirstStorage = await manager.ensureAuthStorage(
        accountAddress: 'first@example.com',
        passphrase: sharedPassphrase,
        storageRootPath: tempDir.path,
      );

      expect(restoredFirstStorage.read(authStoragePrefix), {
        'account': 'first',
      });
    });

    test('scopes linked task registry to authenticated account', () async {
      final linkedTaskRegistry = CalendarLinkedTaskRegistry(storage: registry);

      await manager.ensureAuthStorage(
        accountAddress: 'first@example.com',
        passphrase: 'first-passphrase',
        storageRootPath: tempDir.path,
      );
      await linkedTaskRegistry.addLinks(
        taskId: 'shared-task',
        storageIds: <String>['', 'calendar-chat-a'],
      );
      expect(linkedTaskRegistry.linkedStorageIds('shared-task'), {
        '',
        'calendar-chat-a',
      });

      await manager.ensureAuthStorage(
        accountAddress: 'second@example.com',
        passphrase: 'second-passphrase',
        storageRootPath: tempDir.path,
      );
      expect(linkedTaskRegistry.linkedStorageIds('shared-task'), isEmpty);

      await manager.ensureAuthStorage(
        accountAddress: 'first@example.com',
        passphrase: 'first-passphrase',
        storageRootPath: tempDir.path,
      );
      expect(linkedTaskRegistry.linkedStorageIds('shared-task'), {
        '',
        'calendar-chat-a',
      });
    });

    test('does not copy legacy prefix storage into address storage', () async {
      final legacyDirectory = await Directory(
        '${tempDir.path}/legacy-prefix',
      ).create();
      final legacyBox = await Hive.openBox<dynamic>(
        authStorageBoxName,
        path: legacyDirectory.path,
        encryptionCipher: HiveAesCipher(
          deriveCalendarEncryptionKey('legacy-passphrase'),
        ),
      );
      await legacyBox.put('${authStoragePrefix}_$authStoragePrefix', {
        'account': 'legacy',
      });
      await legacyBox.close();

      final storage = await manager.ensureAuthStorage(
        accountAddress: 'legacy@example.com',
        passphrase: 'legacy-passphrase',
        storageRootPath: tempDir.path,
      );

      expect(storage.read(authStoragePrefix), isNull);
    });

    test('does not reuse previous address-scoped migration storage', () async {
      final String normalized = normalizedAddressKey('legacy@example.com')!;
      final Digest addressHash = sha256.convert(utf8.encode(normalized));
      final oldScopedDirectory = await Directory(
        '${tempDir.path}/'
        '${normalizeAppOwnedPathSegment('calendar_auth_$addressHash')}',
      ).create();
      final oldScopedBox = await Hive.openBox<dynamic>(
        authStorageBoxName,
        path: oldScopedDirectory.path,
        encryptionCipher: HiveAesCipher(
          deriveCalendarEncryptionKey('legacy-passphrase'),
        ),
      );
      await oldScopedBox.put('${authStoragePrefix}_$authStoragePrefix', {
        'account': 'legacy',
      });
      await oldScopedBox.close();

      final storage = await manager.ensureAuthStorage(
        accountAddress: 'legacy@example.com',
        passphrase: 'legacy-passphrase',
        storageRootPath: tempDir.path,
      );

      expect(storage.read(authStoragePrefix), isNull);
    });

    test(
      'does not open old passphrase-keyed storage with a new passphrase',
      () async {
        final String normalized = normalizedAddressKey('legacy@example.com')!;
        final Digest addressHash = sha256.convert(utf8.encode(normalized));
        final oldScopedDirectory = await Directory(
          '${tempDir.path}/'
          '${normalizeAppOwnedPathSegment('calendar_auth_v2_$addressHash')}',
        ).create();
        final oldScopedBox = await Hive.openBox<dynamic>(
          authStorageBoxName,
          path: oldScopedDirectory.path,
          encryptionCipher: HiveAesCipher(
            deriveCalendarEncryptionKey('legacy-passphrase'),
          ),
        );
        await oldScopedBox.put('${authStoragePrefix}_$authStoragePrefix', {
          'account': 'legacy',
        });
        await oldScopedBox.close();

        final storage = await manager.ensureAuthStorage(
          accountAddress: 'legacy@example.com',
          passphrase: 'new-passphrase',
          storageRootPath: tempDir.path,
        );

        expect(storage.read(authStoragePrefix), isNull);
      },
    );
  });
}
