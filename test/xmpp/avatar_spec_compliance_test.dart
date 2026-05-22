import 'dart:io';
import 'dart:typed_data';
import 'package:axichat/main.dart';
import 'package:axichat/src/common/event_manager.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

Uint8List _tinyPngAvatarBytes() => Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeUserAgent());
    registerFallbackValue(MessageNotificationChannel.chat);
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
      buildStateStore: (_, _) => mockStateStore,
      buildDatabase: (_, _) => database,
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

  test('XEP-0084 empty metadata clears cached avatar', () async {
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
  });

  test('XEP-0060 retract of current avatar clears cached avatar', () async {
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
  });

  test('XEP-0060 node purge clears cached avatar', () async {
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
  });

  test(
    'Self avatar publish emits avatar publish operation failure when PubSub is unavailable',
    () async {
      final events = <XmppOperationEvent>[];
      final subscription = xmppService.xmppOperationStream.listen(events.add);
      addTearDown(subscription.cancel);
      await xmppService.runBootstrapOperations(
        XmppBootstrapTrigger.fullNegotiation,
      );

      final payload = AvatarUploadPayload(
        bytes: Uint8List.fromList(const <int>[
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0x00,
        ]),
        mimeType: 'image/png',
        width: 1,
        height: 1,
        hash: 'self-avatar-hash',
        jid: 'jid@axi.im',
      );

      await expectLater(
        xmppService.publishAvatar(payload),
        throwsA(isA<XmppAvatarException>()),
      );
      await pumpEventQueue();

      final publishEvents = events
          .where((event) => event.kind == XmppOperationKind.selfAvatarPublish)
          .toList(growable: false);

      expect(publishEvents, hasLength(2));
      expect(publishEvents.first.stage, XmppOperationStage.start);
      expect(publishEvents.last.stage, XmppOperationStage.end);
      expect(publishEvents.last.isSuccess, isFalse);
    },
  );

  test('Corrupted cached avatar clears stale roster and chat paths', () async {
    const contactJid = 'contact@example.com';
    final originalPathProvider = PathProviderPlatform.instance;
    final tempDir = await Directory.systemTemp.createTemp('axichat-avatar-');
    final supportDir = Directory(p.join(tempDir.path, 'support'));
    await supportDir.create(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);

    try {
      await database.saveRosterItems([
        const RosterItem(
          jid: contactJid,
          title: 'contact',
          presence: Presence.chat,
          subscription: Subscription.both,
        ),
      ]);

      await xmppService.storeAvatarBytesForJid(
        jid: contactJid,
        bytes: _tinyPngAvatarBytes(),
        hash: 'avatar-hash',
      );

      final storedRoster = await database.getRosterItem(contactJid);
      final storedPath = storedRoster?.avatarPath;
      expect(storedPath, isNotNull);

      final corruptPath = p.join(File(storedPath!).parent.path, 'corrupt.enc');
      final avatarFile = File(corruptPath);
      await avatarFile.writeAsBytes(const <int>[1, 2, 3, 4], flush: true);
      await database.updateRosterAvatar(
        jid: contactJid,
        avatarPath: corruptPath,
        avatarHash: 'avatar-hash',
      );
      await database.updateChatAvatar(
        jid: contactJid,
        avatarPath: corruptPath,
        avatarHash: 'avatar-hash',
      );

      final bytes = await xmppService.loadAvatarBytes(corruptPath);

      expect(bytes, isNull);
      expect(await avatarFile.exists(), isFalse);

      final updatedRoster = await database.getRosterItem(contactJid);
      final updatedChat = await database.getChat(contactJid);
      expect(updatedRoster?.avatarPath, isNull);
      expect(updatedRoster?.avatarHash, isNull);
      expect(updatedChat?.avatarPath, isNull);
      expect(updatedChat?.avatarHash, isNull);
    } finally {
      PathProviderPlatform.instance = originalPathProvider;
      await tempDir.delete(recursive: true);
    }
  });

  test('New cached avatar writes use account scoped directory', () async {
    const contactJid = 'contact@example.com';
    final originalPathProvider = PathProviderPlatform.instance;
    final tempDir = await Directory.systemTemp.createTemp('axichat-avatar-');
    final supportDir = Directory(p.join(tempDir.path, 'support'));
    await supportDir.create(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);

    try {
      await database.saveRosterItems([
        const RosterItem(
          jid: contactJid,
          title: 'contact',
          presence: Presence.chat,
          subscription: Subscription.both,
        ),
      ]);

      await xmppService.storeAvatarBytesForJid(
        jid: contactJid,
        bytes: _tinyPngAvatarBytes(),
        hash: 'avatar-hash',
      );

      final storedPath = (await database.getRosterItem(contactJid))?.avatarPath;
      expect(storedPath, isNotNull);
      final relative = p.relative(
        storedPath!,
        from: p.join(supportDir.path, 'avatars'),
      );
      final segments = p.split(relative);
      expect(segments.first, 'v2');
      expect(segments, hasLength(4));
      expect(await File(storedPath).exists(), isTrue);
    } finally {
      PathProviderPlatform.instance = originalPathProvider;
      await tempDir.delete(recursive: true);
    }
  });

  test('Valid legacy cached avatar migrates to scoped path', () async {
    const contactJid = 'contact@example.com';
    final originalPathProvider = PathProviderPlatform.instance;
    final tempDir = await Directory.systemTemp.createTemp('axichat-avatar-');
    final supportDir = Directory(p.join(tempDir.path, 'support'));
    await supportDir.create(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);

    try {
      await database.saveRosterItems([
        const RosterItem(
          jid: contactJid,
          title: 'contact',
          presence: Presence.chat,
          subscription: Subscription.both,
        ),
      ]);

      final avatarBytes = _tinyPngAvatarBytes();
      await xmppService.storeAvatarBytesForJid(
        jid: contactJid,
        bytes: avatarBytes,
        hash: 'avatar-hash',
      );

      final scopedPath = (await database.getRosterItem(
        contactJid,
      ))!.avatarPath!;
      final legacyPath = p.join(supportDir.path, 'avatars', 'legacy.enc');
      await File(
        legacyPath,
      ).writeAsBytes(await File(scopedPath).readAsBytes(), flush: true);
      await database.updateRosterAvatar(
        jid: contactJid,
        avatarPath: legacyPath,
        avatarHash: 'avatar-hash',
      );
      await database.updateChatAvatar(
        jid: contactJid,
        avatarPath: legacyPath,
        avatarHash: 'avatar-hash',
      );

      final loaded = await xmppService.loadAvatarBytes(legacyPath);

      expect(loaded, avatarBytes);
      expect(await File(legacyPath).exists(), isTrue);
      expect(
        (await database.getRosterItem(contactJid))?.avatarPath,
        scopedPath,
      );
      expect((await database.getChat(contactJid))?.avatarPath, scopedPath);
    } finally {
      PathProviderPlatform.instance = originalPathProvider;
      await tempDir.delete(recursive: true);
    }
  });

  test('Plain legacy cached avatar migrates to scoped path', () async {
    const contactJid = 'contact@example.com';
    final originalPathProvider = PathProviderPlatform.instance;
    final tempDir = await Directory.systemTemp.createTemp('axichat-avatar-');
    final supportDir = Directory(p.join(tempDir.path, 'support'));
    await supportDir.create(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);

    try {
      await database.saveRosterItems([
        const RosterItem(
          jid: contactJid,
          title: 'contact',
          presence: Presence.chat,
          subscription: Subscription.both,
        ),
      ]);

      final avatarBytes = _tinyPngAvatarBytes();
      final legacyPath = p.join(supportDir.path, 'avatars', 'legacy.png');
      final legacyFile = File(legacyPath);
      await legacyFile.parent.create(recursive: true);
      await legacyFile.writeAsBytes(avatarBytes, flush: true);
      await database.updateRosterAvatar(
        jid: contactJid,
        avatarPath: legacyPath,
        avatarHash: 'avatar-hash',
      );
      await database.updateChatAvatar(
        jid: contactJid,
        avatarPath: legacyPath,
        avatarHash: 'avatar-hash',
      );

      final loaded = await xmppService.loadAvatarBytes(legacyPath);
      final updatedPath = (await database.getRosterItem(
        contactJid,
      ))?.avatarPath;

      expect(loaded, avatarBytes);
      expect(await legacyFile.exists(), isTrue);
      expect(updatedPath, isNotNull);
      expect(updatedPath, isNot(legacyPath));
      final updatedSegments = p.split(
        p.relative(updatedPath!, from: supportDir.path),
      );
      expect(updatedSegments.first, 'avatars');
      expect(updatedSegments[1], 'v2');
      expect(updatedSegments, hasLength(5));
      expect((await database.getChat(contactJid))?.avatarPath, updatedPath);
    } finally {
      PathProviderPlatform.instance = originalPathProvider;
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Invalid legacy cached avatar clears references without deleting file',
    () async {
      const contactJid = 'contact@example.com';
      final originalPathProvider = PathProviderPlatform.instance;
      final tempDir = await Directory.systemTemp.createTemp('axichat-avatar-');
      final supportDir = Directory(p.join(tempDir.path, 'support'));
      await supportDir.create(recursive: true);
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        supportDir.path,
      );

      try {
        await database.saveRosterItems([
          const RosterItem(
            jid: contactJid,
            title: 'contact',
            presence: Presence.chat,
            subscription: Subscription.both,
          ),
        ]);
        final legacyPath = p.join(supportDir.path, 'avatars', 'legacy-bad.enc');
        final legacyFile = File(legacyPath);
        await legacyFile.parent.create(recursive: true);
        await legacyFile.writeAsBytes(const <int>[1, 2, 3, 4], flush: true);
        await database.updateRosterAvatar(
          jid: contactJid,
          avatarPath: legacyPath,
          avatarHash: 'avatar-hash',
        );
        await database.updateChatAvatar(
          jid: contactJid,
          avatarPath: legacyPath,
          avatarHash: 'avatar-hash',
        );

        final loaded = await xmppService.loadAvatarBytes(legacyPath);

        expect(loaded, isNull);
        expect(await legacyFile.exists(), isTrue);
        expect((await database.getRosterItem(contactJid))?.avatarPath, isNull);
        expect((await database.getChat(contactJid))?.avatarPath, isNull);
      } finally {
        PathProviderPlatform.instance = originalPathProvider;
        await tempDir.delete(recursive: true);
      }
    },
  );

  test(
    'Wrong scoped cached avatar clears references without deleting file',
    () async {
      const contactJid = 'contact@example.com';
      final originalPathProvider = PathProviderPlatform.instance;
      final tempDir = await Directory.systemTemp.createTemp('axichat-avatar-');
      final supportDir = Directory(p.join(tempDir.path, 'support'));
      await supportDir.create(recursive: true);
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        supportDir.path,
      );

      try {
        await database.saveRosterItems([
          const RosterItem(
            jid: contactJid,
            title: 'contact',
            presence: Presence.chat,
            subscription: Subscription.both,
          ),
        ]);
        final wrongScopePath = p.join(
          supportDir.path,
          'avatars',
          'v2',
          'other-account',
          'other-key',
          'avatar.enc',
        );
        final wrongScopeFile = File(wrongScopePath);
        await wrongScopeFile.parent.create(recursive: true);
        await wrongScopeFile.writeAsBytes(const <int>[1, 2, 3, 4], flush: true);
        await database.updateRosterAvatar(
          jid: contactJid,
          avatarPath: wrongScopePath,
          avatarHash: 'avatar-hash',
        );
        await database.updateChatAvatar(
          jid: contactJid,
          avatarPath: wrongScopePath,
          avatarHash: 'avatar-hash',
        );

        final loaded = await xmppService.loadAvatarBytes(wrongScopePath);

        expect(loaded, isNull);
        expect(await wrongScopeFile.exists(), isTrue);
        expect((await database.getRosterItem(contactJid))?.avatarPath, isNull);
        expect((await database.getChat(contactJid))?.avatarPath, isNull);
      } finally {
        PathProviderPlatform.instance = originalPathProvider;
        await tempDir.delete(recursive: true);
      }
    },
  );
}
