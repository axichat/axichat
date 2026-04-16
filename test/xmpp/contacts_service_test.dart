// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:axichat/main.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart' hide uuid;
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeUserAgent());
    registerFallbackValue(FakeStanzaDetails());
    registerFallbackValue(MessageNotificationChannel.chat);
    registerOmemoFallbacks();
    resetForegroundNotifier(value: false);
  });

  late XmppService xmppService;
  late XmppDrift database;

  setUp(() {
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
    xmppService = XmppService(
      buildConnection: () => mockConnection,
      buildStateStore: (_, _) => mockStateStore,
      buildDatabase: (_, _) => database,
      notificationService: mockNotificationService,
    );

    prepareMockConnection();
  });

  tearDown(() async {
    await database.deleteAll();
    await xmppService.close();
  });

  tearDown(() {
    resetMocktailState();
  });

  test('loadContactsSnapshot merges provider contacts only', () async {
    await connectSuccessfully(xmppService);

    await database.saveRosterItem(
      RosterItem.fromJid('Alice@example.com').copyWith(
        title: 'Roster Alice',
        presence: Presence.chat,
        subscription: Subscription.both,
      ),
    );
    await database.replaceContacts([
      Contact.address(
        nativeID: 'dc-contact-1',
        address: 'alice@example.com',
        displayName: 'Email Alice',
        transport: MessageTransport.email,
      ),
      Contact.address(
        nativeID: 'dc-contact-2',
        address: 'bob@example.com',
        displayName: 'Bob Email',
        transport: MessageTransport.email,
      ),
    ]);

    final items = await xmppService.loadContactsSnapshot();

    expect(items, hasLength(2));

    final alice = items.singleWhere(
      (item) => item.address == 'alice@example.com',
    );
    expect(alice.hasXmppRoster, isTrue);
    expect(alice.hasEmailContact, isTrue);
    expect(alice.emailNativeIds, ['dc-contact-1']);
    expect(alice.displayName, 'Roster Alice');

    final bob = items.singleWhere((item) => item.address == 'bob@example.com');
    expect(bob.hasXmppRoster, isFalse);
    expect(bob.hasEmailContact, isTrue);
    expect(bob.displayName, 'Bob Email');
  });

  test('loadContactsSnapshot falls back to chat avatar paths', () async {
    await connectSuccessfully(xmppService);

    await database.saveRosterItem(
      RosterItem.fromJid('alice@example.com').copyWith(title: 'Alice'),
    );
    await database.updateChat(
      Chat.fromJid(
        'alice@example.com',
      ).copyWith(avatarPath: '/avatars/alice.enc'),
    );
    await database.createChat(
      Chat.fromJid('bob@example.com').copyWith(avatarPath: '/avatars/bob.enc'),
    );
    await database.replaceContacts([
      Contact.address(
        nativeID: 'dc-contact-4',
        address: 'bob@example.com',
        displayName: 'Bob',
        transport: MessageTransport.email,
      ),
    ]);
    expect(
      (await database.getChat('alice@example.com'))?.avatarPath,
      '/avatars/alice.enc',
    );

    final items = await xmppService.loadContactsSnapshot();

    expect(
      items
          .singleWhere((item) => item.address == 'alice@example.com')
          .avatarPath,
      '/avatars/alice.enc',
    );
    expect(
      items.singleWhere((item) => item.address == 'bob@example.com').avatarPath,
      '/avatars/bob.enc',
    );
  });

  test(
    'contactsStream updates for saved email contacts without creating chats',
    () async {
      await connectSuccessfully(xmppService);

      final contactsFuture = xmppService.contactsStream().firstWhere(
        (items) => items.any((item) => item.address == 'carol@example.com'),
      );

      await database.replaceContacts([
        Contact.address(
          nativeID: 'dc-contact-3',
          address: 'carol@example.com',
          displayName: 'Carol',
          transport: MessageTransport.email,
        ),
      ]);

      final items = await contactsFuture;
      final carol = items.singleWhere(
        (item) => item.address == 'carol@example.com',
      );

      expect(carol.hasXmppRoster, isFalse);
      expect(carol.hasEmailContact, isTrue);
      expect(carol.displayName, 'Carol');
      expect(await database.getChat('carol@example.com'), isNull);
    },
  );
}
