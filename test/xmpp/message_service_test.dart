import 'dart:io';

import 'package:chat/src/storage/database.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

import '../mocks.dart';

main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late XmppService xmppService;
  late XmppDatabase database;

  setUp(() {
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
  });

  tearDown(() async {
    await xmppService.close();
    resetMocktailState();
  });

  group('messageStream', () {
    late mox.MessageEvent messageEvent;

    setUp(() {
      messageEvent = generateRandomMessageEvent();
    });

    test(
      'When message database is updated, emits the new values.',
      () {
        expectLater(
          xmppService.messageStream(jid),
          emitsInOrder([xmppService.generateMessageFromMox(messageEvent)]),
        );
      },
    );
  });
}
