// ignore_for_file: depend_on_referenced_packages

import 'package:axichat/main.dart';
import 'package:axichat/src/storage/database.dart';
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
    registerFallbackValue(FakeUserAgent());
    registerOmemoFallbacks();
  });

  late XmppService xmppService;
  late XmppDatabase database;

  setUp(() {
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockNotificationService = MockNotificationService();
    database = XmppDrift.inMemory();

    prepareMockConnection();

    xmppService = XmppService(
      buildConnection: () => mockConnection,
      buildStateStore: (_, __) => mockStateStore,
      buildDatabase: (_, __) => database,
      notificationService: mockNotificationService,
    );
  });

  tearDown(() async {
    await xmppService.close();
  });

  tearDown(() {
    resetMocktailState();
  });

  test('registers TLS requirement negotiator before StartTLS', () async {
    final captured = <mox.XmppFeatureNegotiatorBase>[];
    when(() => mockConnection.registerFeatureNegotiators(any()))
        .thenAnswer((invocation) async {
      final negotiators = invocation.positionalArguments.first
          as List<mox.XmppFeatureNegotiatorBase>;
      captured
        ..clear()
        ..addAll(negotiators);
    });

    await connectSuccessfully(xmppService);

    final tlsIndex = captured
        .indexWhere((negotiator) => negotiator is XmppTlsRequirementNegotiator);
    final startTlsIndex = captured
        .indexWhere((negotiator) => negotiator is mox.StartTlsNegotiator);
    expect(tlsIndex, isNot(equals(-1)));
    expect(startTlsIndex, isNot(equals(-1)));
    expect(tlsIndex, lessThan(startTlsIndex));
  });
}
