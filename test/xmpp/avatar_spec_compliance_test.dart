import 'dart:io';

import 'package:axichat/main.dart';
import 'package:axichat/src/common/event_manager.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

import '../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeUserAgent());
    registerOmemoFallbacks();
  });

  late XmppService xmppService;
  late XmppDatabase database;
  late EventManager<mox.XmppEvent> eventManager;

  setUp(() async {
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockNotificationService = MockNotificationService();
    database = XmppDrift(
      file: File(''),
      passphrase: '',
      executor: NativeDatabase.memory(),
    );
    xmppService = XmppService(
      buildConnection: () => mockConnection,
      buildStateStore: (_, __) => mockStateStore,
      buildDatabase: (_, __) => database,
      notificationService: mockNotificationService,
    );
    eventManager = EventManager<mox.XmppEvent>();
    xmppService.configureEventHandlers(eventManager);

    prepareMockConnection();
    await connectSuccessfully(xmppService);
  });

  tearDown(() async {
    await database.deleteAll();
    await xmppService.close();
  });

  tearDown(() {
    resetMocktailState();
  });

  test(
    'XEP-0084 empty metadata clears cached avatar',
    () async {
      const contactJid = 'contact@example.com';
      const avatarHash = 'avatar-hash';

      await database.saveRosterItems([
        const RosterItem(
          jid: contactJid,
          title: 'contact',
          presence: Presence.chat,
          subscription: Subscription.both,
          avatarHash: avatarHash,
        ),
      ]);

      await eventManager.executeHandlers(
        mox.UserAvatarUpdatedEvent(
          mox.JID.fromString(contactJid),
          const <mox.UserAvatarMetadata>[],
        ),
      );

      final updated = await database.getRosterItem(contactJid);
      expect(updated?.avatarHash, isNull);
      expect(updated?.avatarPath, isNull);
    },
  );

  test(
    'XEP-0060 retract of current avatar clears cached avatar',
    () async {
      const contactJid = 'contact@example.com';
      const avatarHash = 'avatar-hash';

      await database.saveRosterItems([
        const RosterItem(
          jid: contactJid,
          title: 'contact',
          presence: Presence.chat,
          subscription: Subscription.both,
          avatarHash: avatarHash,
        ),
      ]);

      await eventManager.executeHandlers(
        mox.PubSubItemsRetractedEvent(
          from: contactJid,
          node: mox.userAvatarMetadataXmlns,
          itemIds: const [avatarHash],
        ),
      );

      final updated = await database.getRosterItem(contactJid);
      expect(updated?.avatarHash, isNull);
      expect(updated?.avatarPath, isNull);
    },
  );

  test(
    'XEP-0060 node purge clears cached avatar',
    () async {
      const contactJid = 'contact@example.com';
      const avatarHash = 'avatar-hash';

      await database.saveRosterItems([
        const RosterItem(
          jid: contactJid,
          title: 'contact',
          presence: Presence.chat,
          subscription: Subscription.both,
          avatarHash: avatarHash,
        ),
      ]);

      await eventManager.executeHandlers(
        mox.PubSubNodePurgedEvent(
          from: contactJid,
          node: mox.userAvatarMetadataXmlns,
        ),
      );

      final updated = await database.getRosterItem(contactJid);
      expect(updated?.avatarHash, isNull);
      expect(updated?.avatarPath, isNull);
    },
  );
}
