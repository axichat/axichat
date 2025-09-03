import 'dart:io';

import 'package:axichat/main.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks.dart';

main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeUserAgent());
  });

  late XmppService xmppService;
  late XmppDatabase database;
  late List<String> jids;
  late int length;

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
    jids = List.generate(4, (_) => generateRandomJid());
    length = jids.length;

    prepareMockConnection();
  });

  tearDown(() async {
    await database.deleteAll();
    await xmppService.close();
  });

  tearDown(() {
    resetMocktailState();
  });

  group('blocklistStream', () {
    test(
      'When jids are added to or removed from the database, emits the new blocklist in order.',
      () async {
        expectLater(
          xmppService.blocklistStream(),
          emitsInOrder([
            [],
            ...List.generate(
              length,
              (index) =>
                  jids.sublist(0, index).map((e) => BlocklistData(jid: e)),
            ),
            ...List.generate(
              length,
              (index) =>
                  jids.sublist(index, length).map((e) => BlocklistData(jid: e)),
            )
          ]),
        );

        await connectSuccessfully(xmppService);

        for (final jid in jids) {
          await pumpEventQueue();
          await database.blockJid(jid);
        }

        for (final jid in jids) {
          await pumpEventQueue();
          await database.unblockJid(jid);
        }
      },
    );
  });

  test(
    'requestBlocklist adds new blocklist to the database.',
    () async {
      await connectSuccessfully(xmppService);

      when(() => mockConnection.requestBlocklist()).thenAnswer(
        (_) async => jids,
      );

      final beforeRequest = await database.getBlocklist(
        start: 0,
        end: double.maxFinite.toInt(),
      );
      expect(beforeRequest, isEmpty);

      await pumpEventQueue();

      await xmppService.requestBlocklist();

      final afterRequest = await database.getBlocklist(
        start: 0,
        end: double.maxFinite.toInt(),
      );
      expect(afterRequest, jids.map((e) => BlocklistData(jid: e)));

      verify(() => mockConnection.requestBlocklist()).called(1);
    },
  );
}
