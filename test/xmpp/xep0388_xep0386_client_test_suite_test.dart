import 'package:axichat/main.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;

import '../mocks.dart';

const bool _foregroundDisabled = false;
const bool _operationSuccess = true;
const bool _connectionSucceeded = true;
const bool _shouldReconnect = false;
const bool _waitForConnection = true;
const bool _waitUntilLogin = true;

const int _singleItem = 1;
const int _expectedSingleNegotiator = 1;

const String _testJidFull = 'user@example.com/resource';
const String _testJidBare = 'user@example.com';
const String _testPassword = 'password';
const String _databasePrefix = '';
const String _databasePassphrase = '';
const String _userAgentKeyName = 'user_agent';
const String _storedUserAgentId = '7d3b4d49-3c7a-4d38-9b84-3b1a9bdc40ab';
const String _uuidV4Pattern =
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
const String _resourceSafeTagPattern = r'^[a-z0-9]+$';
const String _emptyString = '';

final RegisteredStateKey _userAgentKey =
    XmppStateStore.registerKey(_userAgentKeyName);
final RegExp _uuidV4Regex = RegExp(_uuidV4Pattern);
final RegExp _resourceSafeTagRegex = RegExp(_resourceSafeTagPattern);

class _StateStoreWrite {
  const _StateStoreWrite({
    required this.key,
    required this.value,
  });

  final RegisteredStateKey key;
  final Object? value;
}

class _StateStoreHarness {
  _StateStoreHarness({
    Map<RegisteredStateKey, Object?>? initialValues,
  })  : values = initialValues ?? <RegisteredStateKey, Object?>{},
        writes = <_StateStoreWrite>[];

  final Map<RegisteredStateKey, Object?> values;
  final List<_StateStoreWrite> writes;

  void seedValue(RegisteredStateKey key, Object? value) {
    values[key] = value;
  }

  void seedUserAgent(String userAgentId) {
    seedValue(_userAgentKey, userAgentId);
  }

  void register(MockXmppStateStore store) {
    when(() => store.read(key: any(named: 'key'))).thenAnswer((invocation) {
      final RegisteredStateKey key =
          invocation.namedArguments[#key] as RegisteredStateKey;
      return values[key];
    });
    when(
      () => store.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      final RegisteredStateKey key =
          invocation.namedArguments[#key] as RegisteredStateKey;
      final Object? value = invocation.namedArguments[#value] as Object?;
      values[key] = value;
      writes.add(
        _StateStoreWrite(
          key: key,
          value: value,
        ),
      );
      return _operationSuccess;
    });
    when(() => store.delete(key: any(named: 'key'))).thenAnswer((invocation) {
      final RegisteredStateKey key =
          invocation.namedArguments[#key] as RegisteredStateKey;
      values.remove(key);
      return Future<bool>.value(_operationSuccess);
    });
    when(() => store.close()).thenAnswer((_) async {});
  }
}

class _XmppHarness {
  _XmppHarness({
    required this.xmppService,
    required this.connection,
    required this.database,
  });

  final XmppService xmppService;
  final MockXmppConnection connection;
  final XmppDatabase database;

  Future<void> connect({required String jid}) async {
    await xmppService.connect(
      jid: jid,
      password: _testPassword,
      databasePrefix: _databasePrefix,
      databasePassphrase: _databasePassphrase,
    );
  }

  Future<void> close() async {
    await xmppService.close();
    await database.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    withForeground = _foregroundDisabled;
    resetForegroundNotifier(value: _foregroundDisabled);
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeUserAgent());
    registerOmemoFallbacks();
    registerFallbackValue(
      XmppConnectionSettings(
        jid: mox.JID.fromString(_testJidBare),
        password: _testPassword,
      ),
    );
  });

  tearDown(() {
    resetMocktailState();
  });

  group('SASL2 negotiator registration', () {
    test('SASL2-FEAT-001 registers SASL2 negotiator', () async {
      final _StateStoreHarness stateStoreHarness = _StateStoreHarness();
      final _XmppHarness harness =
          _createHarness(stateStoreHarness: stateStoreHarness);
      try {
        await harness.connect(jid: _testJidFull);

        final List<mox.XmppFeatureNegotiatorBase> negotiators =
            _captureNegotiators(harness.connection);
        expect(
          negotiators.whereType<mox.Sasl2Negotiator>(),
          hasLength(_expectedSingleNegotiator),
        );
      } finally {
        await harness.close();
      }
    });
  });

  group('SASL2 user agent', () {
    test('SASL2-INIT-004 includes user-agent software', () async {
      final _StateStoreHarness stateStoreHarness = _StateStoreHarness();
      final _XmppHarness harness =
          _createHarness(stateStoreHarness: stateStoreHarness);
      try {
        await harness.connect(jid: _testJidFull);

        final mox.UserAgent userAgent = _captureUserAgent(harness.connection);
        expect(userAgent.software, equals(appDisplayName));
      } finally {
        await harness.close();
      }
    });

    test('SASL2-INIT-005 user-agent id is UUIDv4', () async {
      final _StateStoreHarness stateStoreHarness = _StateStoreHarness();
      final _XmppHarness harness =
          _createHarness(stateStoreHarness: stateStoreHarness);
      try {
        await harness.connect(jid: _testJidFull);

        final mox.UserAgent userAgent = _captureUserAgent(harness.connection);
        final String? userAgentId = userAgent.id;
        expect(userAgentId, isNotNull);
        expect(_uuidV4Regex.hasMatch(userAgentId ?? _emptyString), isTrue);
      } finally {
        await harness.close();
      }
    });

    test('SASL2-INIT-006 reuses persisted user-agent id', () async {
      final _StateStoreHarness stateStoreHarness = _StateStoreHarness()
        ..seedUserAgent(_storedUserAgentId);
      final _XmppHarness harness =
          _createHarness(stateStoreHarness: stateStoreHarness);
      try {
        await harness.connect(jid: _testJidFull);

        final mox.UserAgent userAgent = _captureUserAgent(harness.connection);
        expect(userAgent.id, equals(_storedUserAgentId));

        final List<_StateStoreWrite> userAgentWrites = stateStoreHarness.writes
            .where((write) => write.key == _userAgentKey)
            .toList();
        expect(userAgentWrites, isEmpty);
      } finally {
        await harness.close();
      }
    });

    test('SEC-UA-002 persists user-agent id across sessions', () async {
      final _StateStoreHarness stateStoreHarness = _StateStoreHarness();
      final _XmppHarness firstHarness =
          _createHarness(stateStoreHarness: stateStoreHarness);
      String? firstId;
      try {
        await firstHarness.connect(jid: _testJidFull);

        final mox.UserAgent firstUserAgent =
            _captureUserAgent(firstHarness.connection);
        firstId = firstUserAgent.id;
        expect(firstId, isNotNull);
      } finally {
        await firstHarness.close();
      }

      final _XmppHarness secondHarness =
          _createHarness(stateStoreHarness: stateStoreHarness);
      try {
        await secondHarness.connect(jid: _testJidFull);

        final mox.UserAgent secondUserAgent =
            _captureUserAgent(secondHarness.connection);
        expect(secondUserAgent.id, equals(firstId));

        final List<_StateStoreWrite> userAgentWrites = stateStoreHarness.writes
            .where((write) => write.key == _userAgentKey)
            .toList();
        expect(userAgentWrites, hasLength(_singleItem));
      } finally {
        await secondHarness.close();
      }
    });
  });

  group('SASL2 connection settings', () {
    test('SASL2-INIT-014 uses bare JID for stream settings', () async {
      final _StateStoreHarness stateStoreHarness = _StateStoreHarness();
      final _XmppHarness harness =
          _createHarness(stateStoreHarness: stateStoreHarness);
      try {
        await harness.connect(jid: _testJidFull);

        final XmppConnectionSettings settings =
            _captureConnectionSettings(harness.connection);
        expect(settings.jid.toString(), equals(_testJidBare));
      } finally {
        await harness.close();
      }
    });
  });

  group('Bind2 configuration', () {
    test('BIND2-REQ-001 registers Bind2 negotiator', () async {
      final _StateStoreHarness stateStoreHarness = _StateStoreHarness();
      final _XmppHarness harness =
          _createHarness(stateStoreHarness: stateStoreHarness);
      try {
        await harness.connect(jid: _testJidFull);

        final List<mox.XmppFeatureNegotiatorBase> negotiators =
            _captureNegotiators(harness.connection);
        expect(
          negotiators.whereType<mox.Bind2Negotiator>(),
          hasLength(_expectedSingleNegotiator),
        );
      } finally {
        await harness.close();
      }
    });

    test('BIND2-REQ-002/003 uses a safe generic bind tag', () async {
      final _StateStoreHarness stateStoreHarness = _StateStoreHarness();
      final _XmppHarness harness =
          _createHarness(stateStoreHarness: stateStoreHarness);
      try {
        await harness.connect(jid: _testJidFull);

        final List<mox.XmppFeatureNegotiatorBase> negotiators =
            _captureNegotiators(harness.connection);
        final List<mox.Bind2Negotiator> bind2Negotiators =
            negotiators.whereType<mox.Bind2Negotiator>().toList();
        expect(bind2Negotiators, hasLength(_expectedSingleNegotiator));

        final mox.Bind2Negotiator bind2Negotiator = bind2Negotiators.single;
        expect(bind2Negotiator.tag, equals(appDisplayName));
        final String tagValue = bind2Negotiator.tag ?? _emptyString;
        expect(_resourceSafeTagRegex.hasMatch(tagValue), isTrue);
      } finally {
        await harness.close();
      }
    });
  });
}

_XmppHarness _createHarness({
  required _StateStoreHarness stateStoreHarness,
}) {
  mockConnection = MockXmppConnection();
  mockStateStore = MockXmppStateStore();
  mockNotificationService = MockNotificationService();
  prepareMockConnection();
  _registerNotificationStubs(mockNotificationService);

  when(
    () => mockConnection.connect(
      shouldReconnect: _shouldReconnect,
      waitForConnection: _waitForConnection,
      waitUntilLogin: _waitUntilLogin,
    ),
  ).thenAnswer(
    (_) async => const moxlib.Result<bool, mox.XmppError>(_connectionSucceeded),
  );

  final XmppDatabase database = XmppDrift.inMemory();
  stateStoreHarness.register(mockStateStore);

  final XmppService xmppService = XmppService(
    buildConnection: () => mockConnection,
    buildStateStore: (_, __) => mockStateStore,
    buildDatabase: (_, __) => database,
    notificationService: mockNotificationService,
  );

  return _XmppHarness(
    xmppService: xmppService,
    connection: mockConnection,
    database: database,
  );
}

mox.UserAgent _captureUserAgent(MockXmppConnection connection) {
  final List<dynamic> captured = verify(
    () => connection.setUserAgent(captureAny()),
  ).captured;
  expect(captured, hasLength(_singleItem));
  return captured.single as mox.UserAgent;
}

XmppConnectionSettings _captureConnectionSettings(
    MockXmppConnection connection) {
  final List<dynamic> captured = verify(
    () => connection.connectionSettings = captureAny(),
  ).captured;
  expect(captured, hasLength(_singleItem));
  return captured.single as XmppConnectionSettings;
}

List<mox.XmppFeatureNegotiatorBase> _captureNegotiators(
  MockXmppConnection connection,
) {
  final List<dynamic> captured = verify(
    () => connection.registerFeatureNegotiators(captureAny()),
  ).captured;
  expect(captured, hasLength(_singleItem));
  return captured.single as List<mox.XmppFeatureNegotiatorBase>;
}

void _registerNotificationStubs(MockNotificationService notificationService) {
  when(
    () => notificationService.sendMessageNotification(
      title: any(named: 'title'),
      body: any(named: 'body'),
      extraConditions: any(named: 'extraConditions'),
      allowForeground: any(named: 'allowForeground'),
      payload: any(named: 'payload'),
      threadKey: any(named: 'threadKey'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => notificationService.sendNotification(
      title: any(named: 'title'),
      body: any(named: 'body'),
      extraConditions: any(named: 'extraConditions'),
      allowForeground: any(named: 'allowForeground'),
      payload: any(named: 'payload'),
    ),
  ).thenAnswer((_) async {});
}
