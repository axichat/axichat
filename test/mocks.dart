import 'dart:core';
import 'dart:isolate';

import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/main.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:uuid/uuid.dart';

class MockXmppService extends Mock implements XmppService {}

class MockXmppConnection extends Mock implements XmppConnection {}

class MockCredentialStore extends Mock implements CredentialStore {}

class MockXmppStateStore extends Mock implements XmppStateStore {}

class MockXmppDatabase extends Mock implements XmppDatabase {}

class MockNotificationService extends Mock implements NotificationService {}

class MockCapability extends Mock implements Capability {}

class MockPolicy extends Mock implements Policy {}

class MockHttpClient extends Mock implements Client {}

class FakeCredentialKey extends Fake implements RegisteredCredentialKey {}

class FakeStateKey extends Fake implements RegisteredStateKey {}

class FakeMessageEvent extends Fake implements mox.MessageEvent {}

class FakeUserAgent extends Fake implements mox.UserAgent {}

class FakeStanzaDetails extends Fake implements mox.StanzaDetails {}

class FakeOmemoDevice extends Fake implements OmemoDevice {}

class FakeOmemoRatchet extends Fake implements OmemoRatchet {}

class FakeOmemoDeviceList extends Fake implements OmemoDeviceList {}

class FakeOmemoTrust extends Fake implements OmemoTrust {}

class FakeOmemoBundleCache extends Fake implements OmemoBundleCache {}

void registerOmemoFallbacks() {
  registerFallbackValue(FakeOmemoDevice());
  registerFallbackValue(FakeOmemoRatchet());
  registerFallbackValue(FakeOmemoDeviceList());
  registerFallbackValue(FakeOmemoTrust());
  registerFallbackValue(FakeOmemoBundleCache());
}

var _foregroundInitialized = false;

void resetForegroundNotifier({required bool value}) {
  if (!_foregroundInitialized) {
    foregroundServiceActive = ValueNotifier(value);
    _foregroundInitialized = true;
  } else {
    foregroundServiceActive.value = value;
  }
}

extension RoundableDateTime on DateTime {
  DateTime get floorSeconds => copyWith(millisecond: 0, microsecond: 0);
}

const uuid = Uuid();

late MockXmppService mockXmppService;
late MockXmppConnection mockConnection;
late MockCredentialStore mockCredentialStore;
var mockStateStore = MockXmppStateStore();
var mockDatabase = MockXmppDatabase();
late MockNotificationService mockNotificationService;

const jid = 'jid@axi.im/resource';
const password = 'password';
const from = 'from@axi.im';

String generateRandomJid() {
  final name = generateRandomString(length: 6);
  return '$name@axi.im';
}

mox.MessageEvent generateRandomMessageEvent({String senderJid = from}) {
  final messageStanzaID = uuid.v4();
  const characters =
      ' !"#\$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~';
  return mox.MessageEvent(
    mox.JID.fromString(senderJid),
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

RosterItem generateRandomRosterItem({
  Presence presence = Presence.unavailable,
  Subscription subscription = Subscription.none,
}) {
  final jid = generateRandomJid();
  return RosterItem(
    jid: jid,
    title: mox.JID.fromString(jid).local,
    presence: presence,
    subscription: subscription,
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
  when(() => mockConnection.omemoActivityStream)
      .thenAnswer((_) => const Stream<mox.OmemoActivityEvent>.empty());
}

Future<void> connectSuccessfully(XmppService xmppService) async {
  when(() => mockStateStore.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      )).thenAnswer((_) async => true);

  when(() => mockDatabase.getOmemoDevice(any())).thenAnswer((_) async => null);
  when(() => mockDatabase.saveOmemoDevice(any())).thenAnswer((_) async {});
  when(() => mockDatabase.deleteOmemoDevice(any())).thenAnswer((_) async {});
  when(() => mockDatabase.getOmemoRatchets(any()))
      .thenAnswer((_) async => <OmemoRatchet>[]);
  when(() => mockDatabase.saveOmemoRatchet(any())).thenAnswer((_) async {});
  when(() => mockDatabase.removeOmemoRatchets(any())).thenAnswer((_) async {});
  when(() => mockDatabase.getOmemoBundleCache(any(), any()))
      .thenAnswer((_) async => null);
  when(() => mockDatabase.saveOmemoBundleCache(any())).thenAnswer((_) async {});
  when(() => mockDatabase.removeOmemoBundleCache(any(), any()))
      .thenAnswer((_) async {});
  when(() => mockDatabase.clearOmemoBundleCache()).thenAnswer((_) async {});
  when(() => mockDatabase.getOmemoDeviceList(any()))
      .thenAnswer((_) async => null);
  when(() => mockDatabase.saveOmemoDeviceList(any())).thenAnswer((_) async {});
  when(() => mockDatabase.deleteOmemoDeviceList(any()))
      .thenAnswer((_) async {});
  when(() => mockDatabase.setOmemoTrust(any())).thenAnswer((_) async {});
  when(() => mockDatabase.getOmemoTrusts(any()))
      .thenAnswer((_) async => <OmemoTrust>[]);
  when(() => mockDatabase.getAllOmemoTrusts())
      .thenAnswer((_) async => <OmemoTrust>[]);

  when(() => mockConnection.connect(
        shouldReconnect: false,
        waitForConnection: true,
        waitUntilLogin: true,
      )).thenAnswer((_) async => const Result<bool, mox.XmppError>(true));

  when(() => mockStateStore.close()).thenAnswer((_) async {});
  when(() => mockDatabase.close()).thenAnswer((_) async {});

  await xmppService.connect(
    jid: jid,
    password: password,
    databasePrefix: '',
    databasePassphrase: '',
  );
}

Future<void> connectUnsuccessfully(XmppService xmppService) async {
  when(() => mockStateStore.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      )).thenAnswer((_) async => true);

  when(() => mockDatabase.getOmemoDevice(any())).thenAnswer((_) async => null);
  when(() => mockDatabase.saveOmemoDevice(any())).thenAnswer((_) async {});
  when(() => mockDatabase.deleteOmemoDevice(any())).thenAnswer((_) async {});
  when(() => mockDatabase.getOmemoRatchets(any()))
      .thenAnswer((_) async => <OmemoRatchet>[]);
  when(() => mockDatabase.saveOmemoRatchet(any())).thenAnswer((_) async {});
  when(() => mockDatabase.removeOmemoRatchets(any())).thenAnswer((_) async {});
  when(() => mockDatabase.getOmemoBundleCache(any(), any()))
      .thenAnswer((_) async => null);
  when(() => mockDatabase.saveOmemoBundleCache(any())).thenAnswer((_) async {});
  when(() => mockDatabase.removeOmemoBundleCache(any(), any()))
      .thenAnswer((_) async {});
  when(() => mockDatabase.clearOmemoBundleCache()).thenAnswer((_) async {});
  when(() => mockDatabase.getOmemoDeviceList(any()))
      .thenAnswer((_) async => null);
  when(() => mockDatabase.saveOmemoDeviceList(any())).thenAnswer((_) async {});
  when(() => mockDatabase.deleteOmemoDeviceList(any()))
      .thenAnswer((_) async {});
  when(() => mockDatabase.setOmemoTrust(any())).thenAnswer((_) async {});
  when(() => mockDatabase.getOmemoTrusts(any()))
      .thenAnswer((_) async => <OmemoTrust>[]);
  when(() => mockDatabase.getAllOmemoTrusts())
      .thenAnswer((_) async => <OmemoTrust>[]);

  when(() => mockConnection.connect(
        shouldReconnect: false,
        waitForConnection: true,
        waitUntilLogin: true,
      )).thenAnswer((_) async => const Result<bool, mox.XmppError>(false));

  when(() => mockStateStore.close()).thenAnswer((_) async {});
  when(() => mockDatabase.close()).thenAnswer((_) async {});

  await xmppService.connect(
    jid: jid,
    password: password,
    databasePrefix: '',
    databasePassphrase: '',
  );
}
