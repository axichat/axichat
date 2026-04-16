// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:axichat/main.dart';
import 'package:axichat/src/notifications/notification_service.dart';
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
      items.indexed.every((e) {
        final (index, contact) = e;
        return compareRosterItems(contacts[index], contact);
      });
}

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
  late XmppDatabase database;
  late List<RosterItem> contacts;
  late StreamController<mox.XmppEvent> eventStreamController;

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

    contacts = List.generate(3, (_) => generateRandomRosterItem());
    eventStreamController = StreamController<mox.XmppEvent>.broadcast();

    prepareMockConnection();

    when(
      () => mockConnection.asBroadcastStream(),
    ).thenAnswer((_) => eventStreamController.stream);
  });

  tearDown(() async {
    await eventStreamController.close();
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
          emitsInOrder(
            List.generate(
              contacts.length,
              (index) => RosterMatcher(contacts.sublist(0, index + 1)),
            ),
          ),
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
          emitsInOrder(List.filled(contacts.length, RosterMatcher(contacts))),
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

  group('subscription requests', () {
    test(
      'Unknown contact subscription request is saved as an invite.',
      () async {
        await connectSuccessfully(xmppService);

        final requester = generateRandomJid();
        eventStreamController.add(
          mox.SubscriptionRequestReceivedEvent(
            from: mox.JID.fromString(requester),
          ),
        );

        await pumpEventQueue();

        final invites = await database.getInvites(
          start: 0,
          end: double.maxFinite.toInt(),
        );
        expect(
          invites,
          contains(
            Invite(jid: requester, title: mox.JID.fromString(requester).local),
          ),
        );
      },
    );

    test(
      'Known contact subscription request is auto-accepted and requested back.',
      () async {
        await connectSuccessfully(xmppService);

        final requester = generateRandomJid();
        await database.saveRosterItem(
          RosterItem.fromJid(requester).copyWith(
            subscription: Subscription.none,
            presence: Presence.unavailable,
          ),
        );

        when(
          () => mockConnection.acceptSubscriptionRequest(requester),
        ).thenAnswer((_) async => true);
        when(
          () => mockConnection.requestSubscription(requester),
        ).thenAnswer((_) async => true);

        eventStreamController.add(
          mox.SubscriptionRequestReceivedEvent(
            from: mox.JID.fromString(requester),
          ),
        );

        await pumpEventQueue();

        verify(
          () => mockConnection.acceptSubscriptionRequest(requester),
        ).called(1);
        verify(() => mockConnection.requestSubscription(requester)).called(1);

        final updated = await database.getRosterItem(requester);
        expect(updated?.subscription, equals(Subscription.from));
        expect(updated?.ask, equals(Ask.subscribe));

        final invites = await database.getInvites(
          start: 0,
          end: double.maxFinite.toInt(),
        );
        expect(invites, isEmpty);
      },
    );
  });

  test(
    'Given a valid roster result, requestRoster adds it to the database.',
    () async {
      await connectSuccessfully(xmppService);

      when(() => mockConnection.requestRoster()).thenAnswer(
        (_) async => moxlib.Result(
          mox.RosterRequestResult(contacts.map((e) => e.toMox()).toList(), ''),
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

  test('requestRoster persists the roster version', () async {
    await connectSuccessfully(xmppService);

    when(() => mockConnection.requestRoster()).thenAnswer(
      (_) async => moxlib.Result(mox.RosterRequestResult(const [], 'v42')),
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
  });

  test('requestRoster does not create direct chats for room JIDs', () async {
    await connectSuccessfully(xmppService);
    await xmppService.setMucServiceHost('conference.axi.im');
    final roomItem = RosterItem.fromJid('room@conference.axi.im');
    when(() => mockConnection.requestRoster()).thenAnswer(
      (_) async =>
          moxlib.Result(mox.RosterRequestResult([roomItem.toMox()], '')),
    );

    await xmppService.requestRoster();

    expect(await database.getChat(roomItem.jid), isNull);
  });

  group('addToRoster', () {
    final jid = generateRandomJid();

    setUp(() {
      when(
        () => mockConnection.addToRoster(any(), title: any(named: 'title')),
      ).thenAnswer((_) async => true);
      when(() => mockConnection.requestRoster()).thenAnswer(
        (_) async => moxlib.Result(
          mox.RosterRequestResult([RosterItem.fromJid(jid).toMox()], ''),
        ),
      );
    });

    test('Requests connection to add contact.', () async {
      await connectSuccessfully(xmppService);

      when(
        () => mockConnection.preApproveSubscription(any()),
      ).thenAnswer((_) async => true);

      final beforeRequest = await database.getRoster();
      expect(beforeRequest, isEmpty);

      await xmppService.addToRoster(jid: jid);

      await pumpEventQueue();

      verify(
        () => mockConnection.addToRoster(jid, title: any(named: 'title')),
      ).called(1);
    });

    test('Refreshes roster after a successful add.', () async {
      await connectSuccessfully(xmppService);
      final rosterItem = RosterItem(
        jid: jid,
        title: 'Alice',
        presence: Presence.unavailable,
        subscription: Subscription.none,
      );

      when(
        () => mockConnection.preApproveSubscription(any()),
      ).thenAnswer((_) async => false);
      when(
        () => mockConnection.requestSubscription(any()),
      ).thenAnswer((_) async => true);
      when(() => mockConnection.requestRoster()).thenAnswer(
        (_) async =>
            moxlib.Result(mox.RosterRequestResult([rosterItem.toMox()], '')),
      );

      await xmppService.addToRoster(jid: '$jid/test-resource', title: 'Alice');

      await pumpEventQueue();

      final saved = await database.getRosterItem(jid);
      expect(saved, isNotNull);
      expect(saved!.jid, jid);
      expect(saved.title, 'Alice');
      expect(saved.subscription, Subscription.none);
      expect(saved.ask, Ask.subscribe);
      verify(() => mockConnection.requestRoster()).called(1);
    });

    test('Requests roster in the background after a successful add.', () async {
      await connectSuccessfully(xmppService);
      final rosterItem = RosterItem.fromJid(jid).copyWith(title: 'Alice');
      final rosterRequest =
          Completer<moxlib.Result<mox.RosterRequestResult, mox.RosterError>>();
      var completed = false;
      Object? failure;

      when(
        () => mockConnection.preApproveSubscription(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockConnection.requestRoster(),
      ).thenAnswer((_) => rosterRequest.future);

      final addFuture = xmppService.addToRoster(jid: jid, title: 'Alice');
      addFuture.then(
        (_) => completed = true,
        onError: (Object error, StackTrace _) => failure = error,
      );

      await pumpEventQueue();

      expect(failure, isNull);
      expect(completed, isTrue);
      expect(await database.getRosterItem(jid), isNull);
      verify(() => mockConnection.requestRoster()).called(1);

      rosterRequest.complete(
        moxlib.Result(mox.RosterRequestResult([rosterItem.toMox()], '')),
      );

      await pumpEventQueue();

      final saved = await database.getRosterItem(jid);
      expect(saved, isNotNull);
      expect(saved!.title, 'Alice');
    });

    test('Retries roster refresh until the added contact appears.', () async {
      await connectSuccessfully(xmppService);
      final rosterItem = RosterItem.fromJid(jid).copyWith(title: 'Alice');
      var rosterRequests = 0;

      when(
        () => mockConnection.preApproveSubscription(any()),
      ).thenAnswer((_) async => false);
      when(
        () => mockConnection.requestSubscription(any()),
      ).thenAnswer((_) async => true);
      when(() => mockConnection.requestRoster()).thenAnswer((_) async {
        rosterRequests += 1;
        if (rosterRequests == 1) {
          return moxlib.Result(mox.RosterRequestResult(const [], ''));
        }
        return moxlib.Result(mox.RosterRequestResult([rosterItem.toMox()], ''));
      });

      await runZoned(
        () => xmppService.addToRoster(jid: jid, title: 'Alice'),
        zoneValues: <String, Object>{
          'roster_refresh_retry_delays': <Duration>[
            Duration.zero,
            const Duration(milliseconds: 1),
            const Duration(milliseconds: 1),
            const Duration(milliseconds: 1),
          ],
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(rosterRequests, 2);

      final saved = await database.getRosterItem(jid);
      expect(saved, isNotNull);
      expect(saved!.title, 'Alice');
      expect(saved.ask, Ask.subscribe);
    });

    test(
      'Does not throw when roster refresh does not include the added contact.',
      () async {
        await connectSuccessfully(xmppService);

        when(
          () => mockConnection.preApproveSubscription(any()),
        ).thenAnswer((_) async => true);
        when(() => mockConnection.requestRoster()).thenAnswer(
          (_) async => moxlib.Result(mox.RosterRequestResult(const [], '')),
        );

        await runZoned(
          () => xmppService.addToRoster(jid: jid),
          zoneValues: <String, Object>{
            'roster_refresh_retry_delays': <Duration>[
              Duration.zero,
              const Duration(milliseconds: 1),
              const Duration(milliseconds: 1),
              const Duration(milliseconds: 1),
            ],
          },
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(await database.getRosterItem(jid), isNull);
        verify(() => mockConnection.requestRoster()).called(4);
      },
    );

    test('Does not create a direct chat when adding a room JID.', () async {
      await connectSuccessfully(xmppService);
      final roomJid = 'room@conference.custom.example';
      final roomItem = RosterItem.fromJid(roomJid);

      when(
        () => mockConnection.preApproveSubscription(any()),
      ).thenAnswer((_) async => true);
      when(() => mockConnection.requestRoster()).thenAnswer(
        (_) async =>
            moxlib.Result(mox.RosterRequestResult([roomItem.toMox()], '')),
      );

      await xmppService.addToRoster(jid: roomJid, title: 'Room');

      await pumpEventQueue();

      final saved = await database.getRosterItem(roomJid);
      expect(saved, isNotNull);
      expect(await database.getChat(roomJid), isNull);
    });

    test(
      'Given successful network calls, pre-approves request from the contact.',
      () async {
        await connectSuccessfully(xmppService);

        when(
          () => mockConnection.preApproveSubscription(any()),
        ).thenAnswer((_) async => true);

        await xmppService.addToRoster(jid: jid);

        await pumpEventQueue();

        verify(() => mockConnection.preApproveSubscription(jid)).called(1);
      },
    );

    test(
      'Given pre-approval failure, request normal subscription to the contact.',
      () async {
        await connectSuccessfully(xmppService);

        when(
          () => mockConnection.preApproveSubscription(any()),
        ).thenAnswer((_) async => false);

        when(
          () => mockConnection.requestSubscription(any()),
        ).thenAnswer((_) async => true);

        await xmppService.addToRoster(jid: jid);

        await pumpEventQueue();

        verify(() => mockConnection.requestSubscription(jid)).called(1);
      },
    );

    test(
      'Given unsuccessful network calls, throws XmppRosterException.',
      () async {
        await connectSuccessfully(xmppService);

        when(
          () => mockConnection.preApproveSubscription(any()),
        ).thenAnswer((_) async => false);

        when(
          () => mockConnection.requestSubscription(any()),
        ).thenAnswer((_) async => false);

        expectLater(
          () => xmppService.addToRoster(jid: jid),
          throwsA(isA<XmppRosterException>()),
        );
      },
    );
  });

  group('removeFromRoster', () {
    final jid = generateRandomJid();

    test('Given success result, returns normally.', () async {
      await connectSuccessfully(xmppService);

      when(
        () => mockConnection.removeFromRoster(any()),
      ).thenAnswer((_) async => mox.RosterRemovalResult.okay);

      await xmppService.removeFromRoster(jid: jid);

      await pumpEventQueue();

      verify(() => mockConnection.removeFromRoster(jid)).called(1);
    });

    test(
      'Given not found result, removes contact from the database.',
      () async {
        await connectSuccessfully(xmppService);

        when(
          () => mockConnection.removeFromRoster(any()),
        ).thenAnswer((_) async => mox.RosterRemovalResult.itemNotFound);

        await database.saveRosterItem(RosterItem.fromJid(jid));

        await xmppService.removeFromRoster(jid: jid);

        await pumpEventQueue();

        expect(await database.getRosterItem(jid), isNull);
      },
    );

    test('Given error result, throws XmppRosterException.', () async {
      await connectSuccessfully(xmppService);

      when(
        () => mockConnection.removeFromRoster(any()),
      ).thenAnswer((_) async => mox.RosterRemovalResult.error);

      expectLater(
        () => xmppService.removeFromRoster(jid: jid),
        throwsA(isA<XmppRosterException>()),
      );
    });
  });

  group('rejectSubscriptionRequest', () {
    final jid = generateRandomJid();
    final invite = Invite(jid: jid, title: mox.JID.fromString(jid).local);

    setUp(() async {
      await database.saveInvite(invite);
    });

    test(
      'Given successful network calls, deletes invite from database.',
      () async {
        await connectSuccessfully(xmppService);

        when(
          () => mockConnection.rejectSubscriptionRequest(any()),
        ).thenAnswer((_) async => true);

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

        when(
          () => mockConnection.rejectSubscriptionRequest(any()),
        ).thenAnswer((_) async => false);

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
