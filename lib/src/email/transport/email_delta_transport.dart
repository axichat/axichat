import 'dart:async';
import 'dart:io';

import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/email/email_metadata.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/email/util/email_header_safety.dart';
import 'package:axichat/src/settings/message_storage_mode.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart'
    show serverOnlyChatMessageCap;
import 'package:delta_ffi/delta_safe.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'chat_transport.dart';

const _selfDomain = 'user.delta.chat';
const _deltaConfigClearedValue = '';
const _deltaConfigKeyAddress = 'addr';
const _deltaConfigKeyMailPassword = 'mail_pw';
const _deltaConfigKeySendPassword = 'send_pw';
const _deltaConfigKeyDisplayName = 'displayname';
const _deltaConfigKeyMailServer = 'mail_server';
const _deltaConfigKeyMailPort = 'mail_port';
const _deltaConfigKeyMailSecurity = 'mail_security';
const _deltaConfigKeyMailUser = 'mail_user';
const _deltaConfigKeySendServer = 'send_server';
const _deltaConfigKeySendPort = 'send_port';
const _deltaConfigKeySendSecurity = 'send_security';
const _deltaConfigKeySendUser = 'send_user';
const String _deltaSecurityModeAutomatic = 'automatic';
const String _deltaSecurityModeAuto = 'auto';
const String _deltaSecurityModeSsl = 'ssl';
const String _deltaSecurityModeStartTls = 'starttls';
const String _deltaSecurityModePlain = 'plain';
const String _deltaSecurityModeAutoNumeric = '0';
const String _deltaSecurityModeSslNumeric = '1';
const String _deltaSecurityModeStartTlsNumeric = '2';
const String _deltaSecurityModePlainNumeric = '3';
const String _deltaMessageStanzaPrefix = 'dc-msg';
const String _deltaMessageStanzaSeparator = '-';
const int _imapImplicitTlsPort = 993;
const int _smtpImplicitTlsPort = 465;
const String _mailTransportLabel = 'mail';
const String _sendTransportLabel = 'send';
const String _emailSecurityModePlainError =
    'Cleartext email security modes are not allowed.';
const String _emailSecurityModeUnknownPrefix =
    'Unsupported email security mode for ';
const String _emailSecurityModeUnknownSuffix = ' connections.';
const int _deltaMessageIdUnset = DeltaMessageId.none;

enum _DeltaSecurityModeResolution {
  auto,
  ssl,
  startTls,
  plain,
  unknown,
}

const _deltaCredentialConfigKeys = <String>[
  _deltaConfigKeyAddress,
  _deltaConfigKeyMailPassword,
  _deltaConfigKeySendPassword,
  _deltaConfigKeyDisplayName,
  _deltaConfigKeyMailServer,
  _deltaConfigKeyMailPort,
  _deltaConfigKeyMailSecurity,
  _deltaConfigKeyMailUser,
  _deltaConfigKeySendServer,
  _deltaConfigKeySendPort,
  _deltaConfigKeySendSecurity,
  _deltaConfigKeySendUser,
];

const _deltaOverrideConfigKeys = <String>[
  _deltaConfigKeySendPassword,
  _deltaConfigKeyMailServer,
  _deltaConfigKeyMailPort,
  _deltaConfigKeyMailSecurity,
  _deltaConfigKeyMailUser,
  _deltaConfigKeySendServer,
  _deltaConfigKeySendPort,
  _deltaConfigKeySendSecurity,
  _deltaConfigKeySendUser,
];

class _DeltaAccountSession {
  const _DeltaAccountSession({
    required this.accountId,
    required this.context,
    required this.consumer,
  });

  final int accountId;
  final DeltaContextHandle context;
  final DeltaEventConsumer consumer;
}

class EmailDeltaTransport implements ChatTransport {
  EmailDeltaTransport({
    required Future<XmppDatabase> Function() databaseBuilder,
    DeltaSafe? deltaSafe,
    Logger? logger,
  })  : _databaseBuilder = databaseBuilder,
        _deltaSafe = deltaSafe ?? DeltaSafe(),
        _log = logger ?? Logger('EmailDeltaTransport');

  final Future<XmppDatabase> Function() _databaseBuilder;
  final DeltaSafe _deltaSafe;
  final Logger _log;

  DeltaAccountsHandle? _accounts;
  DeltaContextHandle? _context;
  bool _contextOpened = false;
  Future<void>? _contextOpening;
  bool _ioRunning = false;
  bool _accountsSupported = true;
  final Map<int, _DeltaAccountSession> _accountSessions = {};
  final Map<int, StreamSubscription<DeltaCoreEvent>> _eventSubscriptions = {};
  final Map<int, Future<void>> _accountOpening = {};
  final List<void Function(DeltaCoreEvent)> _eventListeners = [];

  String? _databasePrefix;
  String? _databasePassphrase;
  final Map<int, String> _accountAddresses = {};
  int? _primaryAccountId;
  MessageStorageMode _messageStorageMode = MessageStorageMode.local;

  @override
  Stream<DeltaCoreEvent> get events =>
      _accounts?.events() ??
      _context?.events() ??
      const Stream<DeltaCoreEvent>.empty();

  String? get selfJid => _selfJidForAccount(_defaultAccountId);

  void hydrateAccountAddress({
    required String address,
    int? accountId,
  }) {
    if (address.isEmpty) return;
    final resolvedAccountId = _resolveAccountId(accountId);
    if (resolvedAccountId == null) return;
    _accountAddresses[resolvedAccountId] = address;
    _primaryAccountId ??= resolvedAccountId;
  }

  void updateMessageStorageMode(MessageStorageMode mode) {
    _messageStorageMode = mode;
    final consumers = <DeltaEventConsumer>{
      for (final session in _accountSessions.values) session.consumer,
    };
    for (final consumer in consumers) {
      consumer.updateMessageStorageMode(mode);
    }
  }

  @override
  Future<void> ensureInitialized({
    required String databasePrefix,
    required String databasePassphrase,
  }) async {
    final prefixChanged =
        _databasePrefix != null && _databasePrefix != databasePrefix;
    final passphraseChanged = _databasePassphrase != null &&
        _databasePassphrase != databasePassphrase;
    final needsReplacement =
        _context != null && (prefixChanged || passphraseChanged);

    if (needsReplacement) {
      await _teardownContext();
    }

    _databasePrefix = databasePrefix;
    _databasePassphrase = databasePassphrase;
  }

  Future<bool> isConfigured({int? accountId}) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return false;
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    return session?.context.isConfigured ?? false;
  }

  Future<void> deconfigureAccount({int? accountId}) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final sessions = await _resolveSessions(accountId: accountId);
    if (sessions.isEmpty) {
      return;
    }
    if (accountId == null) {
      await stop();
    }
    for (final session in sessions) {
      final context = session.context;
      for (final key in _deltaCredentialConfigKeys) {
        try {
          await context.setConfig(key: key, value: _deltaConfigClearedValue);
        } on Exception catch (error, stackTrace) {
          _log.warning(
            'Failed to clear Delta config key $key',
            error,
            stackTrace,
          );
        }
      }
      _accountAddresses.remove(session.accountId);
      if (_primaryAccountId == session.accountId) {
        _primaryAccountId = null;
      }
    }
  }

  @override
  Future<void> configureAccount({
    required String address,
    required String password,
    required String displayName,
    Map<String, String> additional = const {},
    int? accountId,
  }) async {
    if (_context == null) {
      if (_databasePrefix == null || _databasePassphrase == null) {
        throw StateError('Call ensureInitialized before configureAccount');
      }
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    if (session == null) {
      throw StateError('Transport not initialized');
    }
    final resolvedAccountId = session.accountId;
    _accountAddresses[resolvedAccountId] = address;
    _primaryAccountId ??= resolvedAccountId;
    final context = session.context;
    final overrideKeys = additional.keys.toSet();
    for (final key in _deltaOverrideConfigKeys) {
      if (!overrideKeys.contains(key)) {
        await context.setConfig(key: key, value: _deltaConfigClearedValue);
      }
    }
    final completer = Completer<void>();
    late final StreamSubscription<DeltaCoreEvent> subscription;
    subscription = context.events().listen((event) {
      final eventType = DeltaEventType.fromCode(event.type);
      if (eventType == null) {
        return;
      }
      if (completer.isCompleted) {
        return;
      }
      if (eventType == DeltaEventType.configureProgress) {
        if (event.data1 == 1000) {
          completer.complete();
        } else if (event.data1 == 0) {
          completer.completeError(
            DeltaSafeException(
              event.data2Text ?? 'Failed to configure email account',
            ),
          );
        }
        return;
      }
      if (eventType == DeltaEventType.error) {
        completer.completeError(
          DeltaSafeException(
            event.data2Text ??
                event.data1Text ??
                'Failed to configure email account',
          ),
        );
      }
    });
    try {
      await context.configureAccount(
        address: address,
        password: password,
        displayName: displayName,
        additional: additional,
      );
      await completer.future.timeout(const Duration(seconds: 60),
          onTimeout: () {
        throw const DeltaSafeException('Email configuration timed out');
      });
      await _enforceTransportSecurity(context: context);
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> start() async {
    await _ensureContextReady();
    final sessions = await _resolveSessions();
    for (final session in sessions) {
      await _enforceTransportSecurity(context: session.context);
      await session.consumer.purgeDeltaStockMessages();
    }
    if (_accounts != null) {
      await _accounts!.startIo();
    } else {
      await _context!.startIo();
    }
    for (final session in sessions) {
      _attachEventSubscription(session);
    }
    _ioRunning = true;
  }

  Future<void> _enforceTransportSecurity({
    DeltaContextHandle? context,
  }) async {
    final resolvedContext = context ?? _context;
    if (resolvedContext == null) {
      return;
    }
    await _enforceSecurityMode(
      context: resolvedContext,
      securityKey: _deltaConfigKeyMailSecurity,
      portKey: _deltaConfigKeyMailPort,
      implicitTlsPort: _imapImplicitTlsPort,
      transportLabel: _mailTransportLabel,
    );
    await _enforceSecurityMode(
      context: resolvedContext,
      securityKey: _deltaConfigKeySendSecurity,
      portKey: _deltaConfigKeySendPort,
      implicitTlsPort: _smtpImplicitTlsPort,
      transportLabel: _sendTransportLabel,
    );
  }

  Future<void> _enforceSecurityMode({
    required DeltaContextHandle context,
    required String securityKey,
    required String portKey,
    required int implicitTlsPort,
    required String transportLabel,
  }) async {
    final rawMode = await context.getConfig(securityKey);
    final normalizedMode = _normalizeSecurityMode(rawMode);
    if (normalizedMode.isEmpty) {
      final fallbackMode = await _fallbackSecurityMode(
        context: context,
        portKey: portKey,
        implicitTlsPort: implicitTlsPort,
      );
      await context.setConfig(key: securityKey, value: fallbackMode);
      return;
    }
    final resolvedMode = _resolveSecurityMode(normalizedMode);
    switch (resolvedMode) {
      case _DeltaSecurityModeResolution.auto:
        final fallbackMode = await _fallbackSecurityMode(
          context: context,
          portKey: portKey,
          implicitTlsPort: implicitTlsPort,
        );
        await context.setConfig(key: securityKey, value: fallbackMode);
        return;
      case _DeltaSecurityModeResolution.ssl:
      case _DeltaSecurityModeResolution.startTls:
        final mappedMode = resolvedMode == _DeltaSecurityModeResolution.ssl
            ? _deltaSecurityModeSsl
            : _deltaSecurityModeStartTls;
        if (normalizedMode != mappedMode) {
          await context.setConfig(key: securityKey, value: mappedMode);
        }
        return;
      case _DeltaSecurityModeResolution.plain:
        throw const DeltaSafeException(_emailSecurityModePlainError);
      case _DeltaSecurityModeResolution.unknown:
        throw DeltaSafeException(
          '$_emailSecurityModeUnknownPrefix$transportLabel'
          '$_emailSecurityModeUnknownSuffix',
        );
    }
  }

  Future<String> _fallbackSecurityMode({
    required DeltaContextHandle context,
    required String portKey,
    required int implicitTlsPort,
  }) async {
    final rawPort = await context.getConfig(portKey);
    final port = _parsePort(rawPort);
    if (port == implicitTlsPort) {
      return _deltaSecurityModeSsl;
    }
    return _deltaSecurityModeStartTls;
  }

  String _normalizeSecurityMode(String? value) {
    final trimmed = value?.trim().toLowerCase();
    return trimmed ?? '';
  }

  _DeltaSecurityModeResolution _resolveSecurityMode(String value) {
    switch (value) {
      case _deltaSecurityModeAutomatic:
      case _deltaSecurityModeAuto:
      case _deltaSecurityModeAutoNumeric:
        return _DeltaSecurityModeResolution.auto;
      case _deltaSecurityModeSsl:
      case _deltaSecurityModeSslNumeric:
        return _DeltaSecurityModeResolution.ssl;
      case _deltaSecurityModeStartTls:
      case _deltaSecurityModeStartTlsNumeric:
        return _DeltaSecurityModeResolution.startTls;
      case _deltaSecurityModePlain:
      case _deltaSecurityModePlainNumeric:
        return _DeltaSecurityModeResolution.plain;
      default:
        return _DeltaSecurityModeResolution.unknown;
    }
  }

  int? _parsePort(String? value) {
    if (value == null) return null;
    return int.tryParse(value.trim());
  }

  @override
  Future<void> stop() async {
    for (final subscription in _eventSubscriptions.values) {
      await subscription.cancel();
    }
    _eventSubscriptions.clear();
    _ioRunning = false;
    if (_accounts != null) {
      await _accounts?.stopIo();
    } else {
      await _context?.stopIo();
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _teardownContext();
    _eventListeners.clear();
  }

  Future<void> purgeStockMessages({int? accountId}) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final sessions = await _resolveSessions(accountId: accountId);
    for (final session in sessions) {
      await session.consumer.purgeDeltaStockMessages();
    }
  }

  Future<bool> bootstrapFromCore({int? accountId}) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return false;
    }
    await _ensureContextReady();
    final sessions = await _resolveSessions(accountId: accountId);
    if (sessions.isEmpty) {
      return false;
    }
    var didBootstrap = false;
    for (final session in sessions) {
      if (await session.consumer.bootstrapFromCore()) {
        didBootstrap = true;
      }
    }
    return didBootstrap;
  }

  Future<void> refreshChatlistSnapshot({int? accountId}) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final sessions = await _resolveSessions(accountId: accountId);
    for (final session in sessions) {
      await session.consumer.refreshChatlistSnapshot();
    }
  }

  Future<void> notifyNetworkAvailable() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final accounts = _accounts;
    if (accounts != null) {
      await accounts.maybeNetworkAvailable();
      return;
    }
    await _context?.maybeNetworkAvailable();
  }

  Future<void> notifyNetworkLost() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final accounts = _accounts;
    if (accounts != null) {
      await accounts.maybeNetworkLost();
      return;
    }
    await _context?.maybeNetworkLost();
  }

  Future<bool> performBackgroundFetch(Duration timeout) async {
    await _ensureContextReady();
    final accounts = _accounts;
    if (accounts == null) {
      await _context?.maybeNetworkAvailable();
      return false;
    }
    return accounts.backgroundFetch(timeout);
  }

  Future<void> backfillChatHistory({
    required int chatId,
    required String chatJid,
    required int desiredWindow,
    int? beforeMessageId,
    DateTime? beforeTimestamp,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    int? accountId,
  }) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final consumer = session?.consumer;
    if (consumer == null) {
      return;
    }
    await consumer.backfillChatHistory(
      chatId: chatId,
      chatJid: chatJid,
      desiredWindow: desiredWindow,
      beforeMessageId: beforeMessageId,
      beforeTimestamp: beforeTimestamp,
      filter: filter,
    );
  }

  @override
  Future<int?> connectivity({int? accountId}) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return null;
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    return session?.context.connectivity();
  }

  bool get accountsSupported => _accountsSupported;

  bool get accountsActive => _accounts != null;

  int get activeAccountId => _defaultAccountId ?? deltaAccountIdLegacy;

  void setPrimaryAccountId(int? accountId) {
    _primaryAccountId = accountId;
  }

  String? selfJidForAccount(int accountId) {
    return _selfJidForAccount(accountId);
  }

  Future<List<int>> accountIds() async {
    await _ensureContextReady();
    final accounts = _accounts;
    if (accounts != null) {
      return accounts.accountIds();
    }
    if (_context == null) {
      return const <int>[];
    }
    return const <int>[deltaAccountIdLegacy];
  }

  Future<int> createAccount({bool closed = false}) async {
    await _ensureContextReady();
    final accounts = _accounts;
    if (accounts == null) {
      throw StateError('Delta accounts unavailable');
    }
    return accounts.addAccount(closed: closed);
  }

  Future<void> ensureAccountSession(int accountId) async {
    await _ensureContextReady();
    await _ensureAccountSession(accountId);
  }

  Future<bool> removeAccount(int accountId) async {
    await _ensureContextReady();
    final accounts = _accounts;
    if (accounts == null) {
      return false;
    }
    await _removeSession(accountId);
    final removed = await accounts.removeAccount(accountId);
    if (removed) {
      _accountAddresses.remove(accountId);
      if (_primaryAccountId == accountId) {
        _primaryAccountId = null;
      }
    }
    return removed;
  }

  Future<String?> getCoreConfig(String key, {int? accountId}) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return null;
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return null;
    }
    return context.getConfig(key);
  }

  Future<void> setCoreConfig({
    required String key,
    required String value,
    int? accountId,
  }) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return;
    }
    await context.setConfig(key: key, value: value);
  }

  Future<void> registerPushToken(String token) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final accounts = _accounts;
    if (accounts != null) {
      await accounts.setPushDeviceToken(token);
      return;
    }
    _log.finer('Delta accounts unavailable; deferring push token registration');
  }

  int? get _defaultAccountId => _resolveAccountId(null);

  int? _resolveAccountId(int? accountId) {
    if (accountId != null) {
      return accountId;
    }
    final primaryId = _primaryAccountId;
    if (primaryId != null) {
      return primaryId;
    }
    final context = _context;
    if (context == null) {
      if (_accountSessions.isEmpty) {
        return null;
      }
      return _accountSessions.keys.first;
    }
    return context.accountId ?? deltaAccountIdLegacy;
  }

  String _selfJidForAddress(String? address) {
    final trimmed = address?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'dc-anon@$_selfDomain';
    }
    return trimmed;
  }

  String? _selfJidForAccount(int? accountId) {
    final resolvedId = _resolveAccountId(accountId);
    if (resolvedId == null) {
      return null;
    }
    final address = _accountAddresses[resolvedId];
    if (address == null || address.trim().isEmpty) {
      return null;
    }
    return _selfJidForAddress(address);
  }

  Future<_DeltaAccountSession?> _ensureSession({int? accountId}) async {
    final resolvedId = _resolveAccountId(accountId);
    if (resolvedId == null) {
      return null;
    }
    final existing = _accountSessions[resolvedId];
    if (existing != null) {
      return existing;
    }
    if (_accounts == null || resolvedId == deltaAccountIdLegacy) {
      final context = _context;
      if (context == null) {
        return null;
      }
      return _registerSession(accountId: resolvedId, context: context);
    }
    return _ensureAccountSession(resolvedId);
  }

  _DeltaAccountSession _registerSession({
    required int accountId,
    required DeltaContextHandle context,
  }) {
    final existing = _accountSessions[accountId];
    if (existing != null) {
      return existing;
    }
    final consumer = DeltaEventConsumer(
      databaseBuilder: _databaseBuilder,
      context: context,
      messageStorageMode: _messageStorageMode,
      selfJidProvider: () => _selfJidForAccount(accountId),
      logger: _log,
    );
    final session = _DeltaAccountSession(
      accountId: accountId,
      context: context,
      consumer: consumer,
    );
    _accountSessions[accountId] = session;
    if (_ioRunning) {
      _attachEventSubscription(session);
    }
    return session;
  }

  Future<_DeltaAccountSession> _ensureAccountSession(int accountId) async {
    final existing = _accountSessions[accountId];
    if (existing != null) {
      return existing;
    }
    final opening = _accountOpening[accountId];
    if (opening != null) {
      await opening;
      final session = _accountSessions[accountId];
      if (session != null) {
        return session;
      }
    }
    final completer = Completer<void>();
    _accountOpening[accountId] = completer.future;
    try {
      final accounts = _accounts;
      if (accounts == null) {
        throw StateError('Delta accounts unavailable for account $accountId');
      }
      final passphrase = _databasePassphrase;
      if (passphrase == null) {
        throw StateError('Transport not initialized');
      }
      final context = accounts.contextFor(accountId);
      await context.open(passphrase: passphrase);
      final session = _registerSession(
        accountId: accountId,
        context: context,
      );
      _context ??= context;
      completer.complete();
      return session;
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      rethrow;
    } finally {
      _accountOpening.remove(accountId);
    }
  }

  void _attachEventSubscription(_DeltaAccountSession session) {
    if (_eventSubscriptions.containsKey(session.accountId)) {
      return;
    }
    final subscription = session.context.events().listen((event) async {
      await _handleEvent(event: event, consumer: session.consumer);
    });
    _eventSubscriptions[session.accountId] = subscription;
  }

  Future<void> _handleEvent({
    required DeltaCoreEvent event,
    required DeltaEventConsumer consumer,
  }) async {
    try {
      final notifyBeforeHandle = event.type == DeltaEventCode.chatDeleted;
      if (notifyBeforeHandle) {
        for (final listener in List.of(_eventListeners)) {
          listener(event);
        }
      }
      await consumer.handle(event);
      if (!notifyBeforeHandle) {
        for (final listener in List.of(_eventListeners)) {
          listener(event);
        }
      }
    } on Exception catch (error, stackTrace) {
      _log.severe('Failed to handle Delta event', error, stackTrace);
    }
  }

  Future<List<_DeltaAccountSession>> _resolveSessions({
    int? accountId,
  }) async {
    if (accountId != null) {
      final session = await _ensureSession(accountId: accountId);
      return session == null ? const [] : <_DeltaAccountSession>[session];
    }
    if (_accountSessions.isNotEmpty) {
      return _accountSessions.values.toList(growable: false);
    }
    final session = await _ensureSession(accountId: null);
    return session == null ? const [] : <_DeltaAccountSession>[session];
  }

  Future<void> _clearSessions() async {
    for (final subscription in _eventSubscriptions.values) {
      await subscription.cancel();
    }
    _eventSubscriptions.clear();
    _accountSessions.clear();
  }

  Future<void> _removeSession(int accountId) async {
    final subscription = _eventSubscriptions.remove(accountId);
    if (subscription != null) {
      await subscription.cancel();
    }
    _accountSessions.remove(accountId);
  }

  Future<void> _ensureContextReady() async {
    if (_contextOpening != null) {
      await _contextOpening!;
      return;
    }
    final completer = Completer<void>();
    _contextOpening = completer.future;
    try {
      final prefix = _databasePrefix;
      final passphrase = _databasePassphrase;
      if (prefix == null || passphrase == null) {
        throw StateError('Transport not initialized');
      }
      var opened = false;
      if (_accountsSupported) {
        opened = await _tryOpenAccountsContext(prefix, passphrase);
      }
      if (!opened) {
        await _openLegacyContext(prefix, passphrase);
      }
      completer.complete();
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      rethrow;
    } finally {
      _contextOpening = null;
    }
  }

  Future<bool> _tryOpenAccountsContext(
    String prefix,
    String passphrase,
  ) async {
    var firstFailure = true;
    bool shouldRetry(Exception error) {
      final message = error.toString();
      final isAllocFailure = message.contains('allocate Delta accounts');
      final isBadInput = message.contains('No such file or directory');
      if (isAllocFailure || isBadInput) {
        return false;
      }
      if (firstFailure) {
        firstFailure = false;
        return true;
      }
      return false;
    }

    var resetAttempted = false;
    while (true) {
      try {
        _accounts ??= await _createAccounts(prefix);
      } on DeltaSafeException catch (error, stackTrace) {
        _log.warning(
          'Delta accounts unavailable, falling back to legacy mode',
          error,
          stackTrace,
        );
        _accountsSupported = false;
        await _accounts?.dispose();
        _accounts = null;
        _context = null;
        _contextOpened = false;
        await _clearSessions();
        return false;
      }
      final legacyFile = await _deltaDatabaseFile(prefix);
      final legacyPath = await legacyFile.exists() ? legacyFile.path : null;
      int accountId;
      try {
        accountId = await _accounts!.ensureAccount(
          legacyDatabasePath: legacyPath,
        );
      } on DeltaSafeException catch (error, stackTrace) {
        if (!shouldRetry(error)) {
          _log.warning(
            'Delta accounts ensureAccount failed; disabling accounts support',
            error,
            stackTrace,
          );
          _accountsSupported = false;
          await _accounts?.dispose();
          _accounts = null;
          _context = null;
          _contextOpened = false;
          await _clearSessions();
          return false;
        }
        _log.warning(
          'Delta accounts ensureAccount failed, resetting storage',
          error,
          stackTrace,
        );
        await _resetAccountsStorage(prefix);
        await _accounts?.dispose();
        _accounts = null;
        continue;
      }
      _context ??= _accounts!.contextFor(accountId);
      if (!_contextOpened) {
        try {
          await _context!.open(passphrase: passphrase);
          _contextOpened = true;
        } on DeltaSafeException catch (error, stackTrace) {
          final retry = shouldRetry(error) ||
              (resetAttempted == false && !_accountsSupported);
          if (!retry) {
            _log.warning(
              'Failed to open Delta account at ${legacyFile.path}; disabling accounts support',
              error,
              stackTrace,
            );
            _accountsSupported = false;
            await _accounts?.dispose();
            _accounts = null;
            _context = null;
            _contextOpened = false;
            await _clearSessions();
            return false;
          }
          resetAttempted = true;
          _log.warning(
            'Failed to open Delta account at ${legacyFile.path}, resetting storage',
            error,
            stackTrace,
          );
          await _resetAccountsStorage(prefix);
          await _accounts?.dispose();
          _accounts = null;
          _context = null;
          _contextOpened = false;
          await _clearSessions();
          continue;
        }
      }
      _primaryAccountId ??= accountId;
      if (_context != null) {
        _registerSession(accountId: accountId, context: _context!);
      }
      return true;
    }
  }

  Future<void> _openLegacyContext(String prefix, String passphrase) async {
    final file = await _deltaDatabaseFile(prefix);
    await file.parent.create(recursive: true);
    var resetAttempted = false;
    while (true) {
      if (_context == null) {
        _log.fine('Opening legacy Delta context at ${file.path}');
        _context = await _deltaSafe.createContext(
          databasePath: file.path,
          osName: 'dart',
        );
        _contextOpened = false;
        _primaryAccountId ??= deltaAccountIdLegacy;
        _registerSession(
          accountId: deltaAccountIdLegacy,
          context: _context!,
        );
      }
      if (_contextOpened) {
        break;
      }
      try {
        await _context!.open(passphrase: passphrase);
        _contextOpened = true;
      } on DeltaSafeException catch (error, stackTrace) {
        if (resetAttempted) {
          rethrow;
        }
        resetAttempted = true;
        _log.warning(
          'Delta context open failed, resetting mailbox database at ${file.path}',
          error,
          stackTrace,
        );
        await _context?.close();
        _context = null;
        _contextOpened = false;
        await _clearSessions();
        await _deleteDatabaseArtifacts(file);
        continue;
      }
    }
  }

  Future<void> _teardownContext() async {
    final opening = _contextOpening;
    if (opening != null) {
      await opening;
    }
    await _clearSessions();
    _ioRunning = false;
    _contextOpened = false;
    await _context?.close();
    _context = null;
    _accountAddresses.clear();
    _primaryAccountId = null;
    _accountOpening.clear();
    if (_accounts != null) {
      await _accounts!.dispose();
      _accounts = null;
    }
  }

  @override
  Future<int> sendText({
    required int chatId,
    required String body,
    String? subject,
    String? shareId,
    String? localBodyOverride,
    String? htmlBody,
    int? accountId,
  }) async {
    final session = await _ensureSession(accountId: accountId);
    if (session == null) {
      throw StateError('Transport not initialized');
    }
    final context = session.context;
    final sanitizedSubject = sanitizeEmailHeaderValue(subject);
    final msgId = await context.sendText(
      chatId: chatId,
      message: body,
      subject: sanitizedSubject,
      html: htmlBody,
    );
    final deltaMessage = await context.getMessage(msgId);
    await _recordOutgoing(
      chatId: chatId,
      msgId: msgId,
      accountId: session.accountId,
      body: body,
      shareId: shareId,
      localBodyOverride: localBodyOverride,
      htmlBody: htmlBody,
      timestamp: deltaMessage?.timestamp,
    );
    return msgId;
  }

  @override
  Future<int> sendAttachment({
    required int chatId,
    required EmailAttachment attachment,
    String? subject,
    String? shareId,
    String? captionOverride,
    String? htmlCaption,
    int? accountId,
  }) async {
    final session = await _ensureSession(accountId: accountId);
    if (session == null) {
      throw StateError('Transport not initialized');
    }
    final context = session.context;
    final sanitizedSubject = sanitizeEmailHeaderValue(subject);
    final sanitizedFileName = sanitizeEmailAttachmentFilename(
      attachment.fileName,
      fallbackPath: attachment.path,
    );
    final sanitizedMimeType = sanitizeEmailMimeType(attachment.mimeType);
    final msgId = await context.sendFileMessage(
      chatId: chatId,
      viewType: _viewTypeFor(attachment),
      filePath: attachment.path,
      fileName: sanitizedFileName,
      mimeType: sanitizedMimeType,
      text: attachment.caption,
      subject: sanitizedSubject,
      html: htmlCaption,
    );
    final deltaMessage = await context.getMessage(msgId);
    var metadata = _metadataForAttachment(attachment, msgId);
    if (deltaMessage != null) {
      metadata = metadata.copyWith(
        path: deltaMessage.filePath ?? metadata.path,
        mimeType: deltaMessage.fileMime ?? metadata.mimeType,
        sizeBytes: deltaMessage.fileSize ?? metadata.sizeBytes,
        width: deltaMessage.width ?? metadata.width,
        height: deltaMessage.height ?? metadata.height,
      );
    }
    await _recordOutgoing(
      chatId: chatId,
      msgId: msgId,
      accountId: session.accountId,
      body: attachment.caption,
      metadata: metadata,
      shareId: shareId,
      localBodyOverride: captionOverride,
      htmlBody: htmlCaption,
      timestamp: deltaMessage?.timestamp,
    );
    return msgId;
  }

  @override
  Future<int> ensureChatForAddress({
    required String address,
    String? displayName,
    int? accountId,
  }) async {
    final session = await _ensureSession(accountId: accountId);
    if (session == null) {
      throw StateError('Transport not initialized');
    }
    final context = session.context;
    final contactId = await context.createContact(
      address: address,
      displayName: displayName ?? address,
    );
    final chatId = await context.createChatByContactId(contactId);
    await _ensureChat(
      chatId,
      accountId: session.accountId,
      context: context,
    );
    return chatId;
  }

  Future<void> _recordOutgoing({
    required int chatId,
    required int msgId,
    required int accountId,
    String? body,
    FileMetadataData? metadata,
    String? shareId,
    String? localBodyOverride,
    String? htmlBody,
    DateTime? timestamp,
  }) async {
    final db = await _databaseBuilder();
    final chat = await _ensureChat(
      chatId,
      accountId: accountId,
    );
    final int deltaAccountId = accountId;
    if (metadata != null) {
      await db.saveFileMetadata(metadata);
    }
    final displayBody = localBodyOverride ?? body;
    final resolvedBody = (displayBody?.trim().isNotEmpty == true)
        ? displayBody!.trim()
        : (metadata == null ? null : _attachmentLabel(metadata));
    final resolvedTimestamp = timestamp ?? DateTime.timestamp();
    final message = Message(
      stanzaID: _stanzaId(
        msgId,
        accountId: deltaAccountId,
      ),
      senderJid: _selfJidForAccount(deltaAccountId) ?? _selfJidForAddress(null),
      chatJid: chat.jid,
      timestamp: resolvedTimestamp,
      body: resolvedBody,
      htmlBody: HtmlContentCodec.normalizeHtml(htmlBody),
      encryptionProtocol: EncryptionProtocol.none,
      acked: false,
      received: false,
      deltaChatId: chatId,
      deltaMsgId: msgId,
      deltaAccountId: deltaAccountId,
      fileMetadataID: metadata?.id,
    );
    await db.saveMessage(message);
    if (_messageStorageMode.isServerOnly) {
      await db.trimChatMessages(
        jid: chat.jid,
        maxMessages: serverOnlyChatMessageCap,
        deltaAccountId: deltaAccountId,
      );
    }
    await db.updateChat(
      chat.copyWith(lastChangeTimestamp: resolvedTimestamp),
    );
    if (shareId != null) {
      await db.insertMessageCopy(
        shareId: shareId,
        dcMsgId: msgId,
        dcChatId: chatId,
        dcAccountId: deltaAccountId,
      );
    }
  }

  Future<Chat> _ensureChat(
    int chatId, {
    int? accountId,
    DeltaContextHandle? context,
  }) async {
    final db = await _databaseBuilder();
    final resolvedAccountId =
        _resolveAccountId(accountId) ?? deltaAccountIdLegacy;
    final existing = await db.getChatByDeltaChatId(
      chatId,
      accountId: resolvedAccountId,
    );
    if (existing != null) {
      await db.upsertEmailChatAccount(
        chatJid: existing.jid,
        deltaAccountId: resolvedAccountId,
        deltaChatId: chatId,
      );
      return existing;
    }
    final session = context == null
        ? await _ensureSession(accountId: resolvedAccountId)
        : null;
    final resolvedContext = context ?? session?.context;
    if (resolvedContext == null) {
      throw StateError('Transport not initialized');
    }
    final remote = await resolvedContext.getChat(chatId);
    final chat = _chatFromRemote(
      chatId: chatId,
      remote: remote,
      emailFromAddress: _selfJidForAccount(resolvedAccountId),
    );
    final existingByAddress = await db.getChat(chat.jid);
    if (existingByAddress != null) {
      final merged = existingByAddress.copyWith(
        deltaChatId: existingByAddress.deltaChatId ?? chatId,
        emailAddress: chat.emailAddress,
        contactDisplayName: chat.contactDisplayName,
        contactID: chat.contactID,
        contactJid: chat.contactJid,
      );
      await db.updateChat(merged);
      await db.upsertEmailChatAccount(
        chatJid: merged.jid,
        deltaAccountId: resolvedAccountId,
        deltaChatId: chatId,
      );
      return merged;
    }
    await db.createChat(chat);
    await db.upsertEmailChatAccount(
      chatJid: chat.jid,
      deltaAccountId: resolvedAccountId,
      deltaChatId: chatId,
    );
    return chat;
  }

  Chat _chatFromRemote({
    required int chatId,
    required DeltaChat? remote,
    String? emailFromAddress,
  }) {
    final emailAddress = _normalizedAddress(
      remote?.contactAddress,
      chatId,
    );
    final title = remote?.name ?? remote?.contactName ?? emailAddress;
    return Chat(
      jid: emailAddress,
      title: title,
      type: _mapChatType(remote?.type),
      lastChangeTimestamp: DateTime.timestamp(),
      encryptionProtocol: EncryptionProtocol.none,
      contactDisplayName: remote?.contactName ?? remote?.name ?? emailAddress,
      contactID: emailAddress,
      contactJid: emailAddress,
      emailAddress: emailAddress,
      emailFromAddress: emailFromAddress,
      deltaChatId: chatId,
    );
  }

  Future<File> _deltaDatabaseFile(String prefix) async {
    final normalized = '${prefix}_email';
    return dbFileFor(normalized);
  }

  Future<void> _deleteDatabaseArtifacts(File databaseFile) async {
    final candidates = <File>[
      databaseFile,
      File('${databaseFile.path}-wal'),
      File('${databaseFile.path}-shm'),
      File('${databaseFile.path}-journal'),
    ];
    for (final candidate in candidates) {
      if (await candidate.exists()) {
        try {
          await candidate.delete();
        } on IOException catch (error, stackTrace) {
          _log.warning(
            'Failed to delete Delta database artifact ${candidate.path}',
            error,
            stackTrace,
          );
        }
      }
    }
  }

  void addEventListener(void Function(DeltaCoreEvent event) listener) {
    if (!_eventListeners.contains(listener)) {
      _eventListeners.add(listener);
    }
  }

  void removeEventListener(void Function(DeltaCoreEvent event) listener) {
    _eventListeners.remove(listener);
  }

  ChatType _mapChatType(int? type) {
    switch (type) {
      case DeltaChatType.group:
      case DeltaChatType.mailingList:
      case DeltaChatType.outBroadcast:
      case DeltaChatType.inBroadcast:
        return ChatType.groupChat;
      default:
        return ChatType.chat;
    }
  }

  FileMetadataData _metadataForAttachment(
    EmailAttachment attachment,
    int msgId,
  ) {
    final sanitizedFileName = sanitizeEmailAttachmentFilename(
      attachment.fileName,
      fallbackPath: attachment.path,
    );
    final sanitizedMimeType = sanitizeEmailMimeType(attachment.mimeType);
    return FileMetadataData(
      id: deltaFileMetadataId(msgId),
      filename: sanitizedFileName,
      path: attachment.path,
      mimeType: sanitizedMimeType,
      sizeBytes: attachment.sizeBytes,
      width: attachment.width,
      height: attachment.height,
    );
  }

  String _attachmentLabel(FileMetadataData metadata) {
    final sizeBytes = metadata.sizeBytes;
    final label = metadata.filename.trim();
    if (sizeBytes == null) return '📎 $label';
    final sizeLabel = _formatBytes(sizeBytes);
    return '📎 $label ($sizeLabel)';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return 'Unknown size';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final precision = value >= 10 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
  }

  int _viewTypeFor(EmailAttachment attachment) {
    if (attachment.isGif) return DeltaMessageType.gif;
    if (attachment.isImage) return DeltaMessageType.image;
    if (attachment.isVideo) return DeltaMessageType.video;
    if (attachment.isAudio) return DeltaMessageType.audio;
    return DeltaMessageType.file;
  }

  Future<DeltaAccountsHandle> _createAccounts(String prefix) async {
    final directory = await _accountsDirectory(prefix);
    final parent = directory.parent;
    if (parent.path != directory.path) {
      await parent.create(recursive: true);
    }
    Future<void> logAccountsDirState(String reason) async {
      final entries = <String>[];
      if (await directory.exists()) {
        await for (final entity in directory.list()) {
          entries.add(p.basename(entity.path));
        }
      }
      _log.warning(
        'Delta accounts initialization failed during $reason '
        '(dirExists=${await directory.exists()}, contents=$entries)',
      );
    }

    try {
      return await _deltaSafe.createAccounts(directory: directory.path);
    } on DeltaSafeException catch (error, stackTrace) {
      await logAccountsDirState('initial create');
      _log.warning(
        'Failed to open Delta accounts at ${directory.path}, resetting storage',
        error,
        stackTrace,
      );
      await _resetAccountsStorage(prefix);
      if (parent.path != directory.path) {
        await parent.create(recursive: true);
      }
      return _deltaSafe.createAccounts(directory: directory.path);
    }
  }

  Future<Directory> _accountsDirectory(String prefix) async {
    final databaseFile = await _deltaDatabaseFile(prefix);
    return Directory('${databaseFile.path}.accounts');
  }

  Future<void> _resetAccountsStorage(String prefix) async {
    final directory = await _accountsDirectory(prefix);
    if (await directory.exists()) {
      try {
        await directory.delete(recursive: true);
      } on IOException catch (error, stackTrace) {
        _log.warning(
          'Failed to delete Delta accounts directory ${directory.path}',
          error,
          stackTrace,
        );
      }
    }
    final legacy = await _deltaDatabaseFile(prefix);
    await _deleteDatabaseArtifacts(legacy);
  }

  Future<void> deleteStorageArtifacts() async {
    final prefix = _databasePrefix;
    if (prefix == null) {
      return;
    }
    await _resetAccountsStorage(prefix);
  }

  /// Blocks an email contact in DeltaChat core.
  ///
  /// Returns true if the contact was found and blocked.
  Future<bool> blockContact(String address, {int? accountId}) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return false;
    }
    final contactId = await context.lookupContactIdByAddress(address);
    if (contactId == null) return false;
    await context.blockContact(contactId);
    return true;
  }

  /// Unblocks an email contact in DeltaChat core.
  ///
  /// Returns true if the contact was found and unblocked.
  Future<bool> unblockContact(String address, {int? accountId}) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return false;
    }
    final contactId = await context.lookupContactIdByAddress(address);
    if (contactId == null) return false;
    await context.unblockContact(contactId);
    return true;
  }

  /// Marks a chat as noticed in core, clearing unread badges.
  ///
  /// Returns true if the operation succeeded.
  Future<bool> markNoticedChat(int chatId, {int? accountId}) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return false;
    }
    return context.markNoticedChat(chatId);
  }

  /// Marks messages as seen, triggering MDN if enabled.
  ///
  /// Returns true if the operation succeeded.
  Future<bool> markSeenMessages(
    List<int> messageIds, {
    int? accountId,
  }) async {
    if (messageIds.isEmpty) return true;
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return false;
    }
    return context.markSeenMessages(messageIds);
  }

  /// Returns the count of fresh (unread) messages in a chat.
  Future<int> getFreshMessageCount(
    int chatId, {
    int? accountId,
  }) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return 0;
    }
    return context.getFreshMessageCount(chatId);
  }

  /// Returns all fresh (unread) message IDs across all chats.
  Future<List<int>> getFreshMessageIds({int? accountId}) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return const <int>[];
    }
    return context.getFreshMessageIds();
  }

  /// Deletes messages from core and server.
  ///
  /// Returns true if the operation succeeded.
  Future<bool> deleteMessages(
    List<int> messageIds, {
    int? accountId,
  }) async {
    if (messageIds.isEmpty) return true;
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return false;
    }
    return context.deleteMessages(messageIds);
  }

  /// Forwards messages to another chat.
  ///
  /// Returns true if the operation succeeded.
  Future<bool> forwardMessages({
    required List<int> messageIds,
    required int toChatId,
    int? accountId,
  }) async {
    if (messageIds.isEmpty) return true;
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return false;
    }
    return context.forwardMessages(messageIds: messageIds, toChatId: toChatId);
  }

  /// Searches messages in a chat.
  ///
  /// Pass chatId=0 to search all chats.
  Future<List<int>> searchMessages({
    required int chatId,
    required String query,
    int? accountId,
  }) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return const <int>[];
    }
    return context.searchMessages(chatId: chatId, query: query);
  }

  Future<void> hydrateMessages(
    List<int> messageIds, {
    int? accountId,
  }) async {
    if (messageIds.isEmpty) return;
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final consumer = session?.consumer;
    if (consumer == null) {
      return;
    }
    for (final messageId in messageIds) {
      await consumer.hydrateMessage(messageId);
    }
  }

  /// Sets the visibility of a chat (normal, archived, pinned).
  ///
  /// Returns true if the operation succeeded.
  Future<bool> setChatVisibility({
    required int chatId,
    required int visibility,
    int? accountId,
  }) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return false;
    }
    return context.setChatVisibility(chatId: chatId, visibility: visibility);
  }

  /// Triggers download of full message content for partial messages.
  ///
  /// Returns true if the download was initiated.
  Future<bool> downloadFullMessage(int messageId, {int? accountId}) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return false;
    }
    return context.downloadFullMessage(messageId);
  }

  /// Resends failed messages.
  ///
  /// Returns true if the resend was initiated.
  Future<bool> resendMessages(
    List<int> messageIds, {
    int? accountId,
  }) async {
    if (messageIds.isEmpty) return true;
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return false;
    }
    return context.resendMessages(messageIds);
  }

  /// Sends a text message with a quote reference to another message.
  ///
  /// Returns the new message ID.
  Future<int> sendTextWithQuote({
    required int chatId,
    required String body,
    required int quotedMessageId,
    String? subject,
    String? htmlBody,
    int? accountId,
  }) async {
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      throw StateError('Transport not initialized');
    }
    final sanitizedSubject = sanitizeEmailHeaderValue(subject);
    return context.sendTextWithQuote(
      chatId: chatId,
      message: body,
      quotedMessageId: quotedMessageId,
      subject: sanitizedSubject,
      html: htmlBody,
    );
  }

  /// Gets the quoted message info for a message.
  Future<DeltaQuotedMessage?> getQuotedMessage(
    int messageId, {
    int? accountId,
  }) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return null;
    }
    return context.getQuotedMessage(messageId);
  }

  /// Sets the draft for a chat.
  ///
  /// Pass null message to clear the draft.
  Future<bool> setDraft({
    required int chatId,
    DeltaMessage? message,
    int? accountId,
  }) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return false;
    }
    return context.setDraft(chatId: chatId, message: message);
  }

  /// Gets the draft for a chat.
  Future<DeltaMessage?> getDraft(int chatId, {int? accountId}) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return null;
    }
    return context.getDraft(chatId);
  }

  /// Gets a message by ID from core.
  Future<DeltaMessage?> getMessage(int messageId, {int? accountId}) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return null;
    }
    return context.getMessage(messageId);
  }

  /// Gets raw MIME headers by message ID from core.
  Future<String?> getMessageMimeHeaders(int messageId) async {
    if (messageId <= _deltaMessageIdUnset) return null;
    await _ensureContextReady();
    final context = _context;
    if (context == null) return null;
    return context.getMessageMimeHeaders(messageId);
  }

  /// Gets contact IDs from core.
  ///
  /// Use flags from [DeltaContactListFlags] to filter results.
  Future<List<int>> getContactIds({
    int flags = 0,
    String? query,
    int? accountId,
  }) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return const <int>[];
    }
    return context.getContactIds(flags: flags, query: query);
  }

  /// Gets blocked contact IDs from core.
  Future<List<int>> getBlockedContactIds({int? accountId}) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return const <int>[];
    }
    return context.getBlockedContactIds();
  }

  /// Deletes a contact from core.
  ///
  /// Returns true if the contact was deleted.
  Future<bool> deleteContact(int contactId, {int? accountId}) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return false;
    }
    return context.deleteContact(contactId);
  }

  /// Gets a contact by ID from core.
  Future<DeltaContact?> getContact(int contactId, {int? accountId}) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return null;
    }
    return context.getContact(contactId);
  }
}

String _normalizedAddress(String? raw, int chatId) {
  if (raw == null || raw.trim().isEmpty) {
    return fallbackEmailAddressForChat(chatId);
  }
  return normalizeEmailAddress(raw);
}

String _stanzaId(
  int msgId, {
  required int accountId,
}) {
  if (accountId == deltaAccountIdLegacy) {
    return '$_deltaMessageStanzaPrefix$_deltaMessageStanzaSeparator$msgId';
  }
  return '$_deltaMessageStanzaPrefix$_deltaMessageStanzaSeparator'
      '$accountId$_deltaMessageStanzaSeparator$msgId';
}
