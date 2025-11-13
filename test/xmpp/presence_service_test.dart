import 'package:axichat/main.dart';
import 'package:axichat/src/storage/models.dart' hide uuid;
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks.dart';

main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(Presence.unknown);
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeUserAgent());
    registerOmemoFallbacks();
    resetForegroundNotifier(value: false);
  });

  late XmppService xmppService;
  late XmppStateStore stateStore;

  setUp(() async {
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockDatabase = MockXmppDatabase();
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

    Hive.init('temporaryPath');
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PresenceAdapter());
    }
    await Hive.openBox(
      XmppStateStore.boxName,
    );

    stateStore = XmppStateStore();

    xmppService = XmppService(
      buildConnection: () => mockConnection,
      buildStateStore: (_, __) => stateStore,
      buildDatabase: (_, __) => mockDatabase,
      notificationService: mockNotificationService,
    );

    prepareMockConnection();
  });

  tearDown(() async {
    await xmppService.close();
    await Hive.deleteFromDisk();
  });

  tearDown(() {
    resetMocktailState();
  });

  test(
    'When the user\'s presence changes, presenceStream emits the new presence.',
    () async {
      expectLater(
        xmppService.presenceStream,
        emitsInOrder(Presence.values),
      );

      await connectSuccessfully(xmppService);

      for (final presence in Presence.values) {
        await stateStore.write(
          key: xmppService.presenceStorageKey,
          value: presence,
        );
      }
    },
  );

  test(
    'receivePresence updates the database.',
    () async {
      await connectSuccessfully(xmppService);

      when(
        () => mockDatabase.updatePresence(
          jid: any(named: 'jid'),
          presence: any(named: 'presence'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) async {});

      final jid = generateRandomJid();

      for (final presence in Presence.values) {
        await xmppService.receivePresence(jid, presence);

        verify(
          () => mockDatabase.updatePresence(
            jid: jid,
            presence: presence,
            status: any(named: 'status'),
          ),
        ).called(1);
      }
    },
  );

  test(
    'receivePresence prefers english status strings when available',
    () async {
      await connectSuccessfully(xmppService);

      const jid = 'alice@axi.im';
      when(
        () => mockDatabase.updatePresence(
          jid: jid,
          presence: Presence.chat,
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) async {});

      await xmppService.receivePresence(
        jid,
        Presence.chat,
        statuses: {
          'es': 'Conectada',
          'en': 'Online now',
        },
      );

      verify(
        () => mockDatabase.updatePresence(
          jid: jid,
          presence: Presence.chat,
          status: 'Online now',
        ),
      ).called(1);
    },
  );
}
