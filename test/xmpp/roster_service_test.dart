// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:axichat/main.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart' hide uuid;
import 'package:axichat/src/xmpp/xmpp_service.dart';
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
      description.add('matches ${contacts.toString()}');

  @override
  bool matches(covariant List<RosterItem> items, Map matchState) =>
      items.length == contacts.length &&
      items.indexed.every(
        (e) {
          final (index, contact) = e;
          return compareRosterItems(contacts[index], contact);
        },
      );
}

main() {
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
  late List<RosterItem> contacts;

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
      buildStateStore: (_, __) => mockStateStore,
      buildDatabase: (_, __) => database,
      notificationService: mockNotificationService,
    );

    contacts = List.generate(3, (_) => generateRandomRosterItem());

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
        expectLater(
          xmppService.rosterStream().where((items) => items.isNotEmpty),
          emitsInOrder(List.generate(
            contacts.length,
            (index) => RosterMatcher(contacts.sublist(0, index + 1)),
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

  test(
    'Given a valid roster result, requestRoster adds it to the database.',
    () async {
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

  test(
    'requestRoster persists the roster version',
    () async {
      await connectSuccessfully(xmppService);

      when(() => mockConnection.requestRoster()).thenAnswer(
        (_) async => moxlib.Result(
          mox.RosterRequestResult(const [], 'v42'),
        ),
      );

      when(
        () => mockStateStore.write(
          key: XmppRosterStateManager.versionStateKey,
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async => true);

      await xmppService.requestRoster();

      verify(
        () => mockStateStore.write(
          key: XmppRosterStateManager.versionStateKey,
          value: 'v42',
        ),
      ).called(1);
    },
  );

  group('addToRoster', () {
    final jid = generateRandomJid();

    setUp(() {
      when(() => mockConnection.addToRoster(
            any(),
            title: any(named: 'title'),
          )).thenAnswer((_) async => true);
    });

    test(
      'Requests connection to add contact.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.preApproveSubscription(any()))
            .thenAnswer((_) async => true);

        final beforeRequest = await database.getRoster();
        expect(beforeRequest, isEmpty);

        await xmppService.addToRoster(jid: jid);

        await pumpEventQueue();

        verify(() => mockConnection.addToRoster(
              jid,
              title: any(named: 'title'),
            )).called(1);
      },
    );

    test(
      'Given successful network calls, pre-approves request from the contact.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.preApproveSubscription(any()))
            .thenAnswer((_) async => true);

        await xmppService.addToRoster(jid: jid);

        await pumpEventQueue();

        verify(() => mockConnection.preApproveSubscription(jid)).called(1);
      },
    );

    test(
      'Given pre-approval failure, request normal subscription to the contact.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.preApproveSubscription(any()))
            .thenAnswer((_) async => false);

        when(() => mockConnection.requestSubscription(any()))
            .thenAnswer((_) async => true);

        await xmppService.addToRoster(jid: jid);

        await pumpEventQueue();

        verify(() => mockConnection.requestSubscription(jid)).called(1);
      },
    );

    test(
      'Given unsuccessful network calls, throws XmppRosterException.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.preApproveSubscription(any()))
            .thenAnswer((_) async => false);

        when(() => mockConnection.requestSubscription(any()))
            .thenAnswer((_) async => false);

        expectLater(
          () => xmppService.addToRoster(jid: jid),
          throwsA(isA<XmppRosterException>()),
        );
      },
    );
  });

  group('removeFromRoster', () {
    final jid = generateRandomJid();

    test(
      'Given success result, returns normally.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.removeFromRoster(
              any(),
            )).thenAnswer((_) async => mox.RosterRemovalResult.okay);

        await xmppService.removeFromRoster(jid: jid);

        await pumpEventQueue();

        verify(() => mockConnection.removeFromRoster(jid)).called(1);
      },
    );

    test(
      'Given not found result, removes contact from the database.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.removeFromRoster(
              any(),
            )).thenAnswer((_) async => mox.RosterRemovalResult.itemNotFound);

        await database.saveRosterItem(RosterItem.fromJid(jid));

        await xmppService.removeFromRoster(jid: jid);

        await pumpEventQueue();

        expect(await database.getRosterItem(jid), isNull);
      },
    );

    test(
      'Given error result, throws XmppRosterException.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.removeFromRoster(
              any(),
            )).thenAnswer((_) async => mox.RosterRemovalResult.error);

        expectLater(
          () => xmppService.removeFromRoster(jid: jid),
          throwsA(isA<XmppRosterException>()),
        );
      },
    );
  });

  group('rejectSubscriptionRequest', () {
    final jid = generateRandomJid();
    final invite = Invite(
      jid: jid,
      title: mox.JID.fromString(jid).local,
    );

    setUp(() async {
      await database.saveInvite(invite);
    });

    test(
      'Given successful network calls, deletes invite from database.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.rejectSubscriptionRequest(any()))
            .thenAnswer((_) async => true);

        await xmppService.rejectSubscriptionRequest(jid);

        await pumpEventQueue();

        expect(
          await database.getInvites(start: 0, end: double.maxFinite.toInt()),
          isEmpty,
        );
      },
    );

    test(
      'Given unsuccessful network calls, throws XmppRosterException.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.rejectSubscriptionRequest(any()))
            .thenAnswer((_) async => false);

        expectLater(
          () => xmppService.rejectSubscriptionRequest(jid),
          throwsA(isA<XmppRosterException>()),
        );

        await pumpEventQueue();

        expect(
          await database.getInvites(start: 0, end: double.maxFinite.toInt()),
          containsAllInOrder([invite]),
        );
      },
    );
  });
}
