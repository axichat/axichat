import 'dart:isolate';

import 'package:chat/src/common/policy.dart';
import 'package:chat/src/notifications/bloc/notification_service.dart';
import 'package:chat/src/storage/credential_store.dart';
import 'package:chat/src/storage/state_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:moxlib/moxlib.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

class MockXmppService extends Mock implements XmppService {}

class MockXmppConnection extends Mock implements XmppConnection {}

class MockCredentialStore extends Mock implements CredentialStore {}

class MockXmppStateStore extends Mock implements XmppStateStore {}

class MockNotificationService extends Mock implements NotificationService {}

class MockCapability extends Mock implements Capability {}

class MockPolicy extends Mock implements Policy {}

class FakeCredentialKey extends Fake implements RegisteredCredentialKey {}

class FakeStateKey extends Fake implements RegisteredStateKey {}

class FakeUserAgent extends Fake implements mox.UserAgent {}

var mockXmppService= MockXmppService();
var mockConnection = MockXmppConnection();
var mockCredentialStore = MockCredentialStore();
var mockStateStore = MockXmppStateStore();

void mockSuccessfulConnection() {
  when(() => mockStateStore.write(
    key: any(named: 'key'),
    value: any(named: 'value'),
  )).thenAnswer((_) async => true);

  when(() => mockConnection.connect(
    shouldReconnect: false,
    waitForConnection: true,
    waitUntilLogin: true,
  )).thenAnswer((_) async => const Result<bool, mox.XmppError>(true));

  when(() => mockStateStore.close()).thenAnswer((_) async {});
}

void mockUnsuccessfulConnection() {
  when(() => mockStateStore.write(
    key: any(named: 'key'),
    value: any(named: 'value'),
  )).thenAnswer((_) async => true);

  when(() => mockConnection.connect(
    shouldReconnect: false,
    waitForConnection: true,
    waitUntilLogin: true,
  )).thenAnswer((_) async => const Result<bool, mox.XmppError>(false));

  when(() => mockStateStore.close()).thenAnswer((_) async {});
}
