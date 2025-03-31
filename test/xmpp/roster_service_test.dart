import 'dart:io';

import 'package:chat/src/storage/database.dart';
import 'package:chat/src/storage/models.dart' hide uuid;
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;

import '../mocks.dart';

bool compareRosterItems(RosterItem a, RosterItem b) =>
    a.jid == b.jid &&
    a.title == b.title &&
    a.presence == b.presence &&
    a.subscription == b.subscription;

class RosterMatcher extends Matcher {
  const RosterMatcher(this.contacts);

  final List<RosterItem> contacts;

  @override
  Description describe(Description description) =>
      description.add('a roster with identical contacts');

  @override
  bool matches(covariant List<RosterItem> items, Map matchState) =>
      items.indexed.every(
        (e) {
          final (index, contact) = e;
          return compareRosterItems(contacts[index], contact);
        },
      );
}

main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeMessageEvent());
    registerFallbackValue(FakeUserAgent());
  });

  late XmppService xmppService;
  late XmppDatabase database;

  setUp(() {
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

    prepareMockConnection();
  });

  tearDown(() async {
    await database.deleteAll();
    await xmppService.close();
  });

  tearDown(() {
    resetMocktailState();
  });

  group('rosterStream', () {
    test(
      'When roster items are added to the database, emits the new roster.',
      () async {
        final contacts = List.generate(3, (_) => generateRandomRosterItem());

        expectLater(
          xmppService.rosterStream(),
          emitsInOrder(List.filled(
            contacts.length,
            RosterMatcher(contacts),
          )),
        );

        await connectSuccessfully(xmppService);

        for (final contact in contacts) {
          await database.saveRosterItem(contact);
        }
      },
    );

    test(
      'When contacts are edited in the chat\'s database, emits the updated contact history in order.',
      () async {
        final contacts = List.generate(3, (_) => generateRandomRosterItem());

        await connectSuccessfully(xmppService);

        for (final contact in contacts) {
          await database.saveRosterItem(contact);
        }

        await pumpEventQueue();

        expectLater(
          xmppService.rosterStream(),
          emitsInOrder(List.filled(
            contacts.length,
            RosterMatcher(contacts),
          )),
        );

        contacts[0] = contacts[0].copyWith(
          presence: Presence.away,
          subscription: Subscription.from,
        );
        await database.updateRosterItem(contacts[0]);

        await pumpEventQueue();
        contacts[1] = contacts[1].copyWith(
          presence: Presence.dnd,
          subscription: Subscription.to,
        );
        await database.updateRosterItem(contacts[1]);

        await pumpEventQueue();
        contacts[2] = contacts[2].copyWith(
          presence: Presence.unavailable,
          subscription: Subscription.both,
        );
        await database.updateRosterItem(contacts[2]);

        contacts[0] = contacts[0].copyWith(
          presence: Presence.chat,
          subscription: Subscription.none,
        );
        await database.updateRosterItem(contacts[0]);
      },
    );
  });

  group('requestRoster', () {
    test(
      'Given a valid roster result, adds the roster to the database.',
      () async {
        final contacts = List.generate(3, (_) => generateRandomRosterItem());

        await connectSuccessfully(xmppService);

        when(() => mockConnection.requestRoster()).thenAnswer(
          (_) async => moxlib.Result(
            mox.RosterRequestResult(
              contacts.map((e) => e.toMox()).toList(),
              '',
            ),
          ),
        );

        final beforeRequest = await database.getRoster();
        expect(beforeRequest, isEmpty);

        await pumpEventQueue();

        await xmppService.requestRoster();

        final afterRequest = await database.getRoster();
        expect(afterRequest, RosterMatcher(contacts));
      },
    );
  });
}
