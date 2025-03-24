import 'dart:isolate';

import 'package:chat/src/common/policy.dart';
import 'package:chat/src/notifications/bloc/notification_service.dart';
import 'package:chat/src/storage/credential_store.dart';
import 'package:chat/src/storage/state_store.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:uuid/uuid.dart';

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

const uuid = Uuid();

var mockXmppService = MockXmppService();
var mockConnection = MockXmppConnection();
var mockCredentialStore = MockCredentialStore();
var mockStateStore = MockXmppStateStore();
var mockNotificationService = MockNotificationService();

const jid = 'jid@axi.im/resource';
const password = 'password';
const from = 'from@axi.im';

mox.MessageEvent generateRandomMessageEvent() {
  final messageStanzaID = uuid.v4();
  const characters =
      ' !"#\$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~';
  return mox.MessageEvent(
    mox.JID.fromString(from),
    mox.JID.fromString(jid),
    false,
    mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
      mox.MessageBodyData(
        String.fromCharCodes(characters.runes.toList()..shuffle()),
      ),
      const mox.MarkableData(true),
      mox.MessageIdData(messageStanzaID),
      mox.ChatState.active,
    ]),
    id: messageStanzaID,
  );
}

void prepareMockConnection() {
  when(() => mockConnection.hasConnectionSettings).thenReturn(false);

  when(() => mockConnection.registerFeatureNegotiators(any()))
      .thenAnswer((_) async {});

  when(() => mockConnection.registerManagers(any())).thenAnswer((_) async {});

  when(() => mockConnection.loadStreamState()).thenAnswer((_) async {});
  when(() => mockConnection.setUserAgent(any())).thenAnswer((_) {});
  when(() => mockConnection.setFastToken(any())).thenAnswer((_) {});

  when(() => mockConnection.asBroadcastStream())
      .thenAnswer((_) => const Stream<mox.XmppEvent>.empty());

  when(() => mockConnection.saltedPassword).thenReturn('');
}

void connectSuccessfully() {
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

void connectUnsuccessfully() {
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
