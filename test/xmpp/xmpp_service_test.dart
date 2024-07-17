import 'dart:async';

import 'package:chat/src/common/capability.dart';
import 'package:chat/src/common/policy.dart';
import 'package:chat/src/storage/credential_store.dart';
import 'package:chat/src/storage/database.dart';
import 'package:chat/src/storage/state_store.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

class MockXmppConnection extends Mock implements XmppConnection {}

class MockCredentialStore extends Mock implements CredentialStore {}

class MockXmppStateStore extends Mock implements XmppStateStore {}

class MockCapability extends Mock implements Capability {}

class MockPolicy extends Mock implements Policy {}

class FakeCredentialKey extends Fake implements RegisteredCredentialKey {}

const domain = 'draugr.de';

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
  });

  late XmppDatabase database;

  setUp(() {
    database = XmppDatabase(
      username: '',
      passphrase: '',
      executor: NativeDatabase.memory(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('XmppService authentication', () {
    const username = 'username';
    const password = 'password';

    test(
        'Login succeeds with new valid credentials '
        'and writes user to storage.', () async {
      final connection = MockXmppConnection();
      final credentialStore = MockCredentialStore();
      final stateStore = MockXmppStateStore();

      final xmppService = XmppService(
        domain,
        buildConnection: () => connection,
        buildCredentialStore: () => credentialStore,
        buildStateStore: (_, __) => stateStore,
        buildDatabase: (_, __) => database,
        capability: Capability(),
        policy: Policy(),
      );

      when(() => connection.hasConnectionSettings).thenReturn(false);

      when(() => connection.registerFeatureNegotiators(any()))
          .thenAnswer((_) async {});

      when(() => connection.registerManagers(any())).thenAnswer((_) async {});

      when(() => connection.asBroadcastStream())
          .thenAnswer((_) => StreamController<mox.XmppEvent>().stream);

      when(() => connection.connect(
            shouldReconnect: false,
            waitForConnection: true,
            waitUntilLogin: true,
          )).thenAnswer((_) async => const Result<bool, mox.XmppError>(true));

      when(() => credentialStore.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);

      when(() => credentialStore.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async => true);

      when(() => stateStore.close()).thenAnswer((_) async {});

      final result =
          await xmppService.authenticateAndConnect(username, password);

      verify(() => connection.connect(
            shouldReconnect: false,
            waitForConnection: true,
            waitUntilLogin: true,
          )).called(1);

      verify(() => credentialStore.write(
            key: xmppService.usernameStorageKey,
            value: username,
          )).called(1);

      verify(() => credentialStore.write(
            key: xmppService.passwordStorageKey,
            value: password,
          )).called(1);

      await xmppService.close();
    });
  });
}
