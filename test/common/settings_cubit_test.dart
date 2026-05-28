import 'dart:async';

import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockXmppService extends Mock implements XmppService {}

class _InMemoryStorage implements Storage {
  final Map<String, dynamic> _store = {};

  @override
  dynamic read(String key) => _store[key];

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<void> close() async {}
}

void main() {
  group('SettingsCubit account scoped settings sync', () {
    test('does not seed settings sync before account activation', () async {
      HydratedBloc.storage = _InMemoryStorage();
      final service = _MockXmppService();
      when(
        () => service.settingsSyncUpdateStream,
      ).thenAnswer((_) => const Stream<Map<String, dynamic>>.empty());
      when(
        () => service.seedSettingsSyncSnapshot(any()),
      ).thenAnswer((_) async {});

      final cubit = SettingsCubit(xmppService: service);
      addTearDown(cubit.close);

      verifyNever(() => service.seedSettingsSyncSnapshot(any()));

      await cubit.activateAccountSettings('user@example.com');

      verify(() => service.seedSettingsSyncSnapshot(any())).called(1);
    });

    test('merges remote settings sync only after account activation', () async {
      HydratedBloc.storage = _InMemoryStorage();
      final service = _MockXmppService();
      final settingsSyncController =
          StreamController<Map<String, dynamic>>.broadcast();
      addTearDown(settingsSyncController.close);
      when(
        () => service.settingsSyncUpdateStream,
      ).thenAnswer((_) => settingsSyncController.stream);
      when(
        () => service.seedSettingsSyncSnapshot(any()),
      ).thenAnswer((_) async {});

      final cubit = SettingsCubit(xmppService: service);
      addTearDown(cubit.close);

      settingsSyncController.add(const {'chat_read_receipts': false});
      await pumpEventQueue();

      expect(cubit.state.chatReadReceipts, isTrue);

      await cubit.activateAccountSettings('user@example.com');
      settingsSyncController.add(const {'chat_read_receipts': false});
      await pumpEventQueue();

      expect(cubit.state.chatReadReceipts, isFalse);
    });

    test(
      'buffers remote settings sync before matching account activation',
      () async {
        HydratedBloc.storage = _InMemoryStorage();
        final service = _MockXmppService();
        final settingsSyncController =
            StreamController<Map<String, dynamic>>.broadcast();
        addTearDown(settingsSyncController.close);
        when(() => service.myJid).thenReturn('user@example.com');
        when(
          () => service.settingsSyncUpdateStream,
        ).thenAnswer((_) => settingsSyncController.stream);
        when(
          () => service.seedSettingsSyncSnapshot(any()),
        ).thenAnswer((_) async {});

        final cubit = SettingsCubit(xmppService: service);
        addTearDown(cubit.close);

        settingsSyncController.add(const {'chat_read_receipts': false});
        await pumpEventQueue();

        expect(cubit.state.chatReadReceipts, isTrue);

        await cubit.activateAccountSettings('user@example.com');

        expect(cubit.state.chatReadReceipts, isFalse);
        final seeded =
            verify(
                  () => service.seedSettingsSyncSnapshot(captureAny()),
                ).captured.single
                as Map<String, dynamic>;
        expect(seeded['chat_read_receipts'], isFalse);
      },
    );

    test(
      'does not apply buffered remote settings sync to another account',
      () async {
        HydratedBloc.storage = _InMemoryStorage();
        final service = _MockXmppService();
        final settingsSyncController =
            StreamController<Map<String, dynamic>>.broadcast();
        addTearDown(settingsSyncController.close);
        when(() => service.myJid).thenReturn('user@example.com');
        when(
          () => service.settingsSyncUpdateStream,
        ).thenAnswer((_) => settingsSyncController.stream);
        when(
          () => service.seedSettingsSyncSnapshot(any()),
        ).thenAnswer((_) async {});

        final cubit = SettingsCubit(xmppService: service);
        addTearDown(cubit.close);

        settingsSyncController.add(const {'chat_read_receipts': false});
        await pumpEventQueue();

        await cubit.activateAccountSettings('other@example.com');

        expect(cubit.state.chatReadReceipts, isTrue);

        await cubit.activateAccountSettings('user@example.com');

        expect(cubit.state.chatReadReceipts, isFalse);
      },
    );

    test(
      'does not apply another account remote sync over active state',
      () async {
        HydratedBloc.storage = _InMemoryStorage();
        final service = _MockXmppService();
        final settingsSyncController =
            StreamController<Map<String, dynamic>>.broadcast();
        addTearDown(settingsSyncController.close);
        var serviceJid = 'first@example.com';
        when(() => service.myJid).thenAnswer((_) => serviceJid);
        when(
          () => service.settingsSyncUpdateStream,
        ).thenAnswer((_) => settingsSyncController.stream);
        when(
          () => service.seedSettingsSyncSnapshot(any()),
        ).thenAnswer((_) async {});

        final cubit = SettingsCubit(xmppService: service);
        addTearDown(cubit.close);

        await cubit.activateAccountSettings('first@example.com');

        serviceJid = 'second@example.com';
        settingsSyncController.add(const {'chat_read_receipts': false});
        await pumpEventQueue();

        expect(cubit.state.chatReadReceipts, isTrue);

        await cubit.activateAccountSettings('second@example.com');

        expect(cubit.state.chatReadReceipts, isFalse);
      },
    );

    test(
      'does not clear sync state on a different account after account switch',
      () async {
        HydratedBloc.storage = _InMemoryStorage();
        final service = _MockXmppService();
        final publishCompleter = Completer<bool>();
        when(
          () => service.settingsSyncUpdateStream,
        ).thenAnswer((_) => const Stream<Map<String, dynamic>>.empty());
        when(
          () => service.seedSettingsSyncSnapshot(any()),
        ).thenAnswer((_) async {});
        when(
          () => service.updateSettingsSyncSnapshot(any()),
        ).thenAnswer((_) => publishCompleter.future);

        final cubit = SettingsCubit(xmppService: service);
        addTearDown(cubit.close);

        await cubit.activateAccountSettings('first@example.com');
        final updateFuture = cubit.toggleChatReadReceipts(false);
        await pumpEventQueue();

        await cubit.activateAccountSettings('second@example.com');

        expect(cubit.state.chatReadReceipts, isTrue);

        publishCompleter.complete(true);
        await updateFuture;

        expect(cubit.state.chatReadReceipts, isTrue);

        await cubit.activateAccountSettings('first@example.com');

        expect(cubit.state.chatReadReceipts, isFalse);
      },
    );
  });

  group('SettingsCubit attachment auto-download updates', () {
    test('applies runtime flags before settings sync completes', () async {
      HydratedBloc.storage = _InMemoryStorage();
      final service = _MockXmppService();
      final syncCompleter = Completer<bool>();
      when(
        () => service.settingsSyncUpdateStream,
      ).thenAnswer((_) => const Stream<Map<String, dynamic>>.empty());
      when(
        () => service.seedSettingsSyncSnapshot(any()),
      ).thenAnswer((_) async {});
      when(
        () => service.updateSettingsSyncSnapshot(any()),
      ).thenAnswer((_) => syncCompleter.future);

      final cubit = SettingsCubit(xmppService: service);
      addTearDown(cubit.close);
      await cubit.activateAccountSettings('user@example.com');
      clearInteractions(service);

      final updateFuture = cubit.setAttachmentAutoDownloadSettings(
        imagesEnabled: true,
        videosEnabled: false,
        documentsEnabled: false,
        archivesEnabled: false,
      );
      var updateCompleted = false;
      unawaited(updateFuture.then((_) => updateCompleted = true));
      await pumpEventQueue();

      verify(
        () => service.updateAttachmentAutoDownloadSettings(
          imagesEnabled: true,
          videosEnabled: false,
          documentsEnabled: false,
          archivesEnabled: false,
        ),
      ).called(1);
      expect(updateCompleted, isFalse);

      syncCompleter.complete(true);
      await updateFuture;
    });
  });
}
