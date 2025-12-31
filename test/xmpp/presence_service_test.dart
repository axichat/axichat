import 'dart:io';

import 'package:axichat/main.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart' hide uuid;
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeUserAgent());
    registerOmemoFallbacks();
    resetForegroundNotifier(value: false);
  });

  late XmppService xmppService;
  late XmppDatabase database;
  late XmppStateStore stateStore;
  late Directory tempDir;

  setUp(() async {
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockNotificationService = MockNotificationService();
    when(
      () => mockNotificationService.sendNotification(
        title: any(named: 'title'),
        body: any(named: 'body'),
        extraConditions: any(named: 'extraConditions'),
        allowForeground: any(named: 'allowForeground'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
    database = XmppDrift(
      file: File(''),
      passphrase: '',
      executor: NativeDatabase.memory(),
    );

    tempDir = await Directory.systemTemp.createTemp('axichat_presence');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PresenceAdapter());
    }
    await Hive.openBox(XmppStateStore.boxName);
    stateStore = XmppStateStore();

    xmppService = XmppService(
      buildConnection: () => mockConnection,
      buildStateStore: (_, __) => stateStore,
      buildDatabase: (_, __) => database,
      notificationService: mockNotificationService,
    );

    prepareMockConnection();
  });

  tearDown(() async {
    await xmppService.close();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  tearDown(() {
    resetMocktailState();
  });

  test(
    'receivePresence updates roster presence and status for contacts.',
    () async {
      await connectSuccessfully(xmppService);

      final contactJid = generateRandomJid();
      await database.saveRosterItem(
        RosterItem.fromJid(contactJid).copyWith(
          subscription: Subscription.both,
          presence: Presence.unavailable,
        ),
      );

      await xmppService.receivePresence(
        contactJid,
        Presence.away,
        status: 'Away',
      );

      final updated = await database.getRosterItem(contactJid);
      expect(updated?.presence, equals(Presence.away));
      expect(updated?.status, equals('Away'));
    },
  );

  test(
    'receivePresence prefers English status text when available.',
    () async {
      await connectSuccessfully(xmppService);

      final contactJid = generateRandomJid();
      await database.saveRosterItem(
        RosterItem.fromJid(contactJid).copyWith(
          subscription: Subscription.both,
          presence: Presence.unavailable,
        ),
      );

      await xmppService.receivePresence(
        contactJid,
        Presence.chat,
        statuses: {
          'es': 'Conectado',
          'en': 'Online',
        },
      );

      final updated = await database.getRosterItem(contactJid);
      expect(updated?.status, equals('Online'));
    },
  );

  test(
    'receivePresence stores self presence and status in state store.',
    () async {
      await connectSuccessfully(xmppService);

      final selfJid = xmppService.myJid!;
      await xmppService.receivePresence(
        selfJid,
        Presence.dnd,
        status: 'Busy',
      );

      final storedPresence =
          stateStore.read(key: xmppService.presenceStorageKey) as Presence?;
      final storedStatus =
          stateStore.read(key: xmppService.statusStorageKey) as String?;

      expect(storedPresence, equals(Presence.dnd));
      expect(storedStatus, equals('Busy'));
      expect(xmppService.presence, equals(Presence.dnd));
      expect(xmppService.status, equals('Busy'));
    },
  );
}
