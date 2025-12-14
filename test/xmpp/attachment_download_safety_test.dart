// ignore_for_file: depend_on_referenced_packages

import 'package:axichat/main.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart' hide uuid;
import 'package:axichat/src/xmpp/xmpp_service.dart';
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
    registerFallbackValue(FakeMessageEvent());
    registerFallbackValue(FakeUserAgent());
    registerOmemoFallbacks();
    registerFallbackValue(mox.ChatMarker.received);
    resetForegroundNotifier(value: false);
  });

  late XmppService xmppService;
  late XmppDatabase database;

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

    database = XmppDrift.inMemory();
    xmppService = XmppService(
      buildConnection: () => mockConnection,
      buildStateStore: (_, __) => mockStateStore,
      buildDatabase: (_, __) => database,
      notificationService: mockNotificationService,
    );

    prepareMockConnection();
  });

  tearDown(() async {
    await xmppService.close();
  });

  tearDown(() {
    resetMocktailState();
  });

  group('downloadInboundAttachment', () {
    test('rejects loopback attachment URLs without touching disk', () async {
      await connectSuccessfully(xmppService);

      final metadata = FileMetadataData(
        id: uuid.v4(),
        filename: 'file.txt',
        sourceUrls: const ['http://127.0.0.1/file.txt'],
      );
      await database.saveFileMetadata(metadata);

      expect(
        () => xmppService.downloadInboundAttachment(metadataId: metadata.id),
        throwsA(isA<XmppMessageException>()),
      );
    });

    test('rejects attachment URLs with userinfo', () async {
      await connectSuccessfully(xmppService);

      final metadata = FileMetadataData(
        id: uuid.v4(),
        filename: 'file.txt',
        sourceUrls: const ['https://user:pass@example.com/file.txt'],
      );
      await database.saveFileMetadata(metadata);

      expect(
        () => xmppService.downloadInboundAttachment(metadataId: metadata.id),
        throwsA(isA<XmppMessageException>()),
      );
    });
  });
}
