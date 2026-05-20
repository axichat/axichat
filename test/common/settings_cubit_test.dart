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
