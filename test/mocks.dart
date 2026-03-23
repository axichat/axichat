// ignore_for_file: depend_on_referenced_packages

import 'dart:core';
import 'dart:isolate';

import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/main.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/authentication/bloc/email_provisioning_client.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/pubsub/conversation_index_manager.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:http/http.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:moxxmpp/src/managers/attributes.dart';
import 'package:uuid/uuid.dart';

class MockXmppService extends Mock implements XmppService {}

class MockXmppConnection extends Mock implements XmppConnection {}

class MockCredentialStore extends Mock implements CredentialStore {}

class MockXmppStateStore extends Mock implements XmppStateStore {}

class MockXmppDatabase extends Mock implements XmppDatabase {}

class MockNotificationService extends Mock implements NotificationService {}

class MockMessageService extends Mock implements MessageService {}

class MockChatsService extends Mock implements ChatsService {}

class MockMucService extends Mock implements MucService {}

class MockEmailService extends Mock implements EmailService {}

class MockCalendarReminderController extends Mock
    implements CalendarReminderController {}

class MockCalendarStorageManager extends Mock
    implements CalendarStorageManager {}

class MockHydratedStorage extends Mock implements Storage {}

class MockEmailProvisioningClient extends Mock
    implements EmailProvisioningClient {}

class MockOmemoService extends Mock implements OmemoService {}

class MockSettingsCubit extends Mock implements SettingsCubit {}

class MockDeltaContextHandle extends Mock implements DeltaContextHandle {}

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

class FakeOmemoTrust extends Fake implements OmemoTrust {}

class FakeOmemoBundleCache extends Fake implements OmemoBundleCache {}

final OmemoDeviceList fallbackOmemoDeviceList = OmemoDeviceList(
  jid: 'fallback@example.com',
  devices: const <int>[],
);

final Chat fallbackChat = Chat.fromJid('fallback@example.com');

final Message fallbackMessage = Message(
  stanzaID: 'fallback-stanza',
  senderJid: 'fallback@example.com',
  chatJid: 'fallback@example.com',
);

void registerOmemoFallbacks() {
  registerFallbackValue(FakeOmemoDevice());
  registerFallbackValue(FakeOmemoRatchet());
  registerFallbackValue(fallbackOmemoDeviceList);
  registerFallbackValue(FakeOmemoTrust());
  registerFallbackValue(FakeOmemoBundleCache());
}

void resetForegroundNotifier({required bool value}) {
  foregroundServiceActive.value = value;
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
  final managersById = <String, mox.XmppManagerBase>{};
  final reconnectionPolicy = XmppReconnectionPolicy.exponential();

  T? lookupManagerById<T extends mox.XmppManagerBase>(String id) =>
      managersById[id] as T?;
  T? lookupNegotiatorById<T extends mox.XmppFeatureNegotiatorBase>(String id) =>
      null;

  when(() => mockConnection.hasConnectionSettings).thenReturn(false);
  when(() => mockConnection.socketWrapper).thenReturn(XmppSocketWrapper());

  when(
    () => mockConnection.registerFeatureNegotiators(any()),
  ).thenAnswer((_) async {});
  when(() => mockConnection.registerManagers(any())).thenAnswer((
    invocation,
  ) async {
    final managers =
        invocation.positionalArguments.first as List<mox.XmppManagerBase>;
    final attributes = XmppManagerAttributes(
      sendStanza: (details) async => await mockConnection.sendStanza(details),
      sendNonza: (_) {},
      getManagerById: lookupManagerById,
      sendEvent: (_) {},
      getConnectionSettings: () => mockConnection.connectionSettings,
      getFullJID: () => mockConnection.connectionSettings.jid,
      getSocket: () => mockConnection.socketWrapper,
      getConnection: () => mockConnection,
      getNegotiatorById: lookupNegotiatorById,
    );

    for (final manager in managers) {
      managersById[manager.id] = manager;
      manager.register(attributes);
    }
    for (final manager in managers) {
      await manager.postRegisterCallback();
    }
  });

  when(() => mockConnection.loadStreamState()).thenAnswer((_) async {});
  when(() => mockConnection.reconnectionPolicy).thenReturn(reconnectionPolicy);
  when(
    () => mockConnection.isReconnecting(),
  ).thenAnswer((_) => reconnectionPolicy.getIsReconnecting());
  when(() => mockConnection.setShouldReconnect(any())).thenAnswer((
    invocation,
  ) async {
    await reconnectionPolicy.setShouldReconnect(
      invocation.positionalArguments.first as bool,
    );
  });
  for (final trigger in ReconnectTrigger.values) {
    when(
      () => mockConnection.requestReconnect(trigger),
    ).thenAnswer((_) async {});
  }
  when(() => mockConnection.setUserAgent(any())).thenAnswer((_) {});
  when(() => mockConnection.setFastToken(any())).thenAnswer((_) {});

  when(
    () => mockConnection.asBroadcastStream(),
  ).thenAnswer((_) => const Stream<mox.XmppEvent>.empty());
  when(() => mockConnection.enableCarbons()).thenAnswer((_) async => true);
  when(() => mockConnection.sendStanza(any())).thenAnswer((_) async => null);
  when(() => mockConnection.requestRoster()).thenAnswer(
    (_) =>
        Future<moxlib.Result<mox.RosterRequestResult, mox.RosterError>?>.value(
          null,
        ),
  );
  when(
    () => mockConnection.requestBlocklist(),
  ).thenAnswer((_) => Future<List<String>?>.value(null));

  when(() => mockConnection.discoInfoQuery(any())).thenAnswer((_) async {
    final discoInfo = mox.DiscoInfo(
      const [mox.mamXmlns],
      const [],
      const [],
      null,
      mox.JID.fromString(jid),
    );
    return moxlib.Result<mox.StanzaError, mox.DiscoInfo>(discoInfo);
  });

  when(() => mockConnection.saltedPassword).thenReturn('');
  when(
    () => mockConnection.getManager<mox.PubSubManager>(),
  ).thenAnswer((_) => lookupManagerById<mox.PubSubManager>(mox.pubsubManager));
  when(
    () => mockConnection.getManager<mox.DiscoManager>(),
  ).thenAnswer((_) => lookupManagerById<mox.DiscoManager>(mox.discoManager));
  when(() => mockConnection.getManager<mox.MessageManager>()).thenAnswer(
    (_) => lookupManagerById<mox.MessageManager>(mox.messageManager),
  );
  when(
    () => mockConnection.getManager<mox.MAMManager>(),
  ).thenAnswer((_) => lookupManagerById<mox.MAMManager>(mox.mamManager));
  when(() => mockConnection.getManager<mox.CarbonsManager>()).thenAnswer(
    (_) => lookupManagerById<mox.CarbonsManager>(mox.carbonsManager),
  );
  when(() => mockConnection.getManager<mox.UserAvatarManager>()).thenAnswer(
    (_) => lookupManagerById<mox.UserAvatarManager>(mox.userAvatarManager),
  );
  when(
    () => mockConnection.getManager<mox.VCardManager>(),
  ).thenAnswer((_) => lookupManagerById<mox.VCardManager>(mox.vcardManager));
  when(() => mockConnection.getManager<ConversationIndexManager>()).thenAnswer(
    (_) => lookupManagerById<ConversationIndexManager>(
      ConversationIndexManager.managerId,
    ),
  );
  when(() => mockConnection.getManager<mox.BlockingManager>()).thenAnswer(
    (_) => lookupManagerById<mox.BlockingManager>(mox.blockingManager),
  );
  when(
    () => mockConnection.getManager<MUCManager>(),
  ).thenAnswer((_) => lookupManagerById<MUCManager>(mox.mucManager));
  when(() => mockConnection.getManager<XmppPresenceManager>()).thenAnswer(
    (_) => lookupManagerById<XmppPresenceManager>(mox.presenceManager),
  );
  when(
    () => mockConnection.getManager<XmppStreamManagementManager>(),
  ).thenAnswer(
    (_) => lookupManagerById<XmppStreamManagementManager>(mox.smManager),
  );
  when(
    () => mockConnection.omemoActivityStream,
  ).thenAnswer((_) => const Stream<mox.OmemoActivityEvent>.empty());
}

Future<void> connectSuccessfully(
  XmppService xmppService, {
  String accountJid = jid,
}) async {
  final parsedJid = mox.JID.fromString(accountJid);
  final settings = XmppConnectionSettings(
    jid: parsedJid.resource.isEmpty
        ? parsedJid.withResource('test-resource')
        : parsedJid,
    password: password,
  );

  when(
    () => mockNotificationService.notificationPreviewsEnabled,
  ).thenReturn(false);
  when(
    () => mockNotificationService.sendMessageNotification(
      title: any(named: 'title'),
      body: any(named: 'body'),
      senderName: any(named: 'senderName'),
      senderKey: any(named: 'senderKey'),
      conversationTitle: any(named: 'conversationTitle'),
      sentAt: any(named: 'sentAt'),
      isGroupConversation: any(named: 'isGroupConversation'),
      extraConditions: any(named: 'extraConditions'),
      allowForeground: any(named: 'allowForeground'),
      payload: any(named: 'payload'),
      threadKey: any(named: 'threadKey'),
      showPreviewOverride: any(named: 'showPreviewOverride'),
      channel: any(named: 'channel'),
    ),
  ).thenAnswer((_) async {});

  when(
    () => mockStateStore.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
    ),
  ).thenAnswer((_) async => true);
  when(
    () => mockStateStore.writeAll(data: any(named: 'data')),
  ).thenAnswer((_) async => true);
  when(
    () => mockStateStore.delete(key: any(named: 'key')),
  ).thenAnswer((_) async => true);

  when(() => mockDatabase.getOmemoDevice(any())).thenAnswer((_) async => null);
  when(() => mockDatabase.saveOmemoDevice(any())).thenAnswer((_) async {});
  when(() => mockDatabase.deleteOmemoDevice(any())).thenAnswer((_) async {});
  when(
    () => mockDatabase.getOmemoRatchets(any()),
  ).thenAnswer((_) async => <OmemoRatchet>[]);
  when(() => mockDatabase.saveOmemoRatchet(any())).thenAnswer((_) async {});
  when(() => mockDatabase.removeOmemoRatchets(any())).thenAnswer((_) async {});
  when(
    () => mockDatabase.getOmemoBundleCache(any(), any()),
  ).thenAnswer((_) async => null);
  when(() => mockDatabase.saveOmemoBundleCache(any())).thenAnswer((_) async {});
  when(
    () => mockDatabase.removeOmemoBundleCache(any(), any()),
  ).thenAnswer((_) async {});
  when(() => mockDatabase.clearOmemoBundleCache()).thenAnswer((_) async {});
  when(
    () => mockDatabase.getOmemoDeviceList(any()),
  ).thenAnswer((_) async => null);
  when(() => mockDatabase.saveOmemoDeviceList(any())).thenAnswer((_) async {});
  when(
    () => mockDatabase.deleteOmemoDeviceList(any()),
  ).thenAnswer((_) async {});
  when(() => mockDatabase.setOmemoTrust(any())).thenAnswer((_) async {});
  when(
    () => mockDatabase.getOmemoTrusts(any()),
  ).thenAnswer((_) async => <OmemoTrust>[]);
  when(
    () => mockDatabase.getAllOmemoTrusts(),
  ).thenAnswer((_) async => <OmemoTrust>[]);
  when(
    () => mockDatabase.replaceDeltaPlaceholderSelfJids(
      deltaAccountId: any(named: 'deltaAccountId'),
      resolvedAddress: any(named: 'resolvedAddress'),
      placeholderJids: any(named: 'placeholderJids'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => mockDatabase.removeDeltaPlaceholderDuplicates(
      deltaAccountId: any(named: 'deltaAccountId'),
      placeholderJids: any(named: 'placeholderJids'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => mockDatabase.getChats(
      start: any(named: 'start'),
      end: any(named: 'end'),
    ),
  ).thenAnswer((_) async => <Chat>[]);

  when(
    () => mockConnection.connect(
      shouldReconnect: false,
      waitForConnection: true,
      waitUntilLogin: true,
    ),
  ).thenAnswer((_) async => const Result<bool, mox.XmppError>(true));
  when(() => mockConnection.connectionSettings).thenReturn(settings);
  when(() => mockConnection.hasConnectionSettings).thenReturn(true);

  when(() => mockStateStore.close()).thenAnswer((_) async {});
  when(() => mockDatabase.close()).thenAnswer((_) async {});

  await xmppService.connect(
    jid: accountJid,
    password: password,
    databasePrefix: '',
    databasePassphrase: '',
  );
}

Future<void> connectUnsuccessfully(XmppService xmppService) async {
  when(
    () => mockNotificationService.notificationPreviewsEnabled,
  ).thenReturn(false);
  when(
    () => mockNotificationService.sendMessageNotification(
      title: any(named: 'title'),
      body: any(named: 'body'),
      senderName: any(named: 'senderName'),
      senderKey: any(named: 'senderKey'),
      conversationTitle: any(named: 'conversationTitle'),
      sentAt: any(named: 'sentAt'),
      isGroupConversation: any(named: 'isGroupConversation'),
      extraConditions: any(named: 'extraConditions'),
      allowForeground: any(named: 'allowForeground'),
      payload: any(named: 'payload'),
      threadKey: any(named: 'threadKey'),
      showPreviewOverride: any(named: 'showPreviewOverride'),
      channel: any(named: 'channel'),
    ),
  ).thenAnswer((_) async {});

  when(
    () => mockStateStore.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
    ),
  ).thenAnswer((_) async => true);
  when(
    () => mockStateStore.delete(key: any(named: 'key')),
  ).thenAnswer((_) async => true);

  when(() => mockDatabase.getOmemoDevice(any())).thenAnswer((_) async => null);
  when(() => mockDatabase.saveOmemoDevice(any())).thenAnswer((_) async {});
  when(() => mockDatabase.deleteOmemoDevice(any())).thenAnswer((_) async {});
  when(
    () => mockDatabase.getOmemoRatchets(any()),
  ).thenAnswer((_) async => <OmemoRatchet>[]);
  when(() => mockDatabase.saveOmemoRatchet(any())).thenAnswer((_) async {});
  when(() => mockDatabase.removeOmemoRatchets(any())).thenAnswer((_) async {});
  when(
    () => mockDatabase.getOmemoBundleCache(any(), any()),
  ).thenAnswer((_) async => null);
  when(() => mockDatabase.saveOmemoBundleCache(any())).thenAnswer((_) async {});
  when(
    () => mockDatabase.removeOmemoBundleCache(any(), any()),
  ).thenAnswer((_) async {});
  when(() => mockDatabase.clearOmemoBundleCache()).thenAnswer((_) async {});
  when(
    () => mockDatabase.getOmemoDeviceList(any()),
  ).thenAnswer((_) async => null);
  when(() => mockDatabase.saveOmemoDeviceList(any())).thenAnswer((_) async {});
  when(
    () => mockDatabase.deleteOmemoDeviceList(any()),
  ).thenAnswer((_) async {});
  when(() => mockDatabase.setOmemoTrust(any())).thenAnswer((_) async {});
  when(
    () => mockDatabase.getOmemoTrusts(any()),
  ).thenAnswer((_) async => <OmemoTrust>[]);
  when(
    () => mockDatabase.getAllOmemoTrusts(),
  ).thenAnswer((_) async => <OmemoTrust>[]);

  when(
    () => mockConnection.connect(
      shouldReconnect: false,
      waitForConnection: true,
      waitUntilLogin: true,
    ),
  ).thenAnswer((_) async => const Result<bool, mox.XmppError>(false));

  when(() => mockStateStore.close()).thenAnswer((_) async {});
  when(() => mockDatabase.close()).thenAnswer((_) async {});

  await xmppService.connect(
    jid: jid,
    password: password,
    databasePrefix: '',
    databasePassphrase: '',
  );
}
