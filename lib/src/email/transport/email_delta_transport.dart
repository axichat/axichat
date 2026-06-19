// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:axichat/src/common/email_validation.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/email/util/email_header_safety.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'chat_transport.dart';

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
const _deltaConfigKeySystemConfigKeys = 'sys.config_keys';
const String _deltaSecurityModeAutomatic = 'automatic';
const String _deltaSecurityModeAuto = 'auto';
const String _deltaSecurityModeSsl = 'ssl';
const String _deltaSecurityModeStartTls = 'starttls';
const String _deltaSecurityModePlain = 'plain';
const String _deltaSecurityModeAutoNumeric = '0';
const String _deltaSecurityModeSslNumeric = '1';
const String _deltaSecurityModeStartTlsNumeric = '2';
const String _deltaSecurityModePlainNumeric = '3';
const int _imapImplicitTlsPort = 993;
const int _smtpImplicitTlsPort = 465;
const String _mailTransportLabel = 'mail';
const String _sendTransportLabel = 'send';
const String _emailSecurityModePlainError =
    'Cleartext email security modes are not allowed.';
const String _emailSecurityModeUnknownPrefix =
    'Unsupported email security mode for ';
const String _emailSecurityModeUnknownSuffix = ' connections.';
const String _emailAccountNotReadyError =
    'Email account not hydrated; wait for email sync.';
const String _accountHydrationFailedLog =
    'Failed to hydrate email account address.';
const int _deltaMessageIdUnset = DeltaMessageId.none;
const bool _defaultScheduleAccountHydration = true;
const Set<String> _deltaSensitiveConfigKeys = <String>{
  _deltaConfigKeyMailPassword,
  _deltaConfigKeySendPassword,
};

enum _DeltaSecurityModeResolution { auto, ssl, startTls, plain, unknown }

enum _DeltaEventDeliveryBlockReason { stopped, logout }

Map<String, String> _sanitizeDeltaConfigForLog(Map<String, String> config) {
  final sanitized = <String, String>{};
  final sortedKeys = config.keys.toList()..sort();
  for (final key in sortedKeys) {
    final normalized = key.trim().toLowerCase();
    sanitized[key] = _deltaSensitiveConfigKeys.contains(normalized)
        ? '<redacted>'
        : config[key] ?? '';
  }
  return sanitized;
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
  final DeltaEventConsumer? consumer;
}

DeltaCoreEvent _deltaEventForAccount({
  required DeltaCoreEvent event,
  required int accountId,
  bool preserveNativeAccountId = false,
}) {
  final eventAccountId = event.accountId;
  if (eventAccountId == accountId) {
    return event;
  }
  if (preserveNativeAccountId &&
      eventAccountId != null &&
      eventAccountId != DeltaAccountDefaults.legacyId) {
    return event;
  }
  return DeltaCoreEvent(
    type: event.type,
    data1: event.data1,
    data2: event.data2,
    data1Text: event.data1Text,
    data2Text: event.data2Text,
    accountId: accountId,
  );
}

class _DeltaBackgroundFetchEventSubscriptions {
  const _DeltaBackgroundFetchEventSubscriptions({
    required this.hadAccountsSubscription,
    required this.existingAccountSubscriptions,
  }) : blockedByLogout = false;

  const _DeltaBackgroundFetchEventSubscriptions.blockedByLogout()
    : hadAccountsSubscription = false,
      existingAccountSubscriptions = const <int>{},
      blockedByLogout = true;

  final bool hadAccountsSubscription;
  final Set<int> existingAccountSubscriptions;
  final bool blockedByLogout;
}

class EmailDeltaImexResult {
  const EmailDeltaImexResult({
    required this.accountId,
    required this.exportedPaths,
  });

  final int accountId;
  final List<String> exportedPaths;
}

final class EmailDeltaImexException implements Exception {
  const EmailDeltaImexException(this.message);

  final String message;

  @override
  String toString() => 'EmailDeltaImexException: $message';
}

final class EmailDeltaImexTimeoutException extends EmailDeltaImexException {
  const EmailDeltaImexTimeoutException()
    : super('Delta import/export timed out.');
}

final class EmailDeltaImexCancelledException extends EmailDeltaImexException {
  const EmailDeltaImexCancelledException()
    : super('Delta import/export was cancelled.');
}

abstract interface class EmailDeltaRuntime implements ChatTransport {
  @override
  Stream<DeltaCoreEvent> get events;
  String? get selfJid;
  bool get accountsSupported;
  bool get accountsActive;
  int get activeAccountId;
  bool get isIoRunning;
  bool get persistsAppStateInternally;

  abstract void Function()? onRuntimeRestarted;

  void updateDatabaseOperationTracker(
    Future<T> Function<T>(Future<T> Function() operation)? tracker,
  );
  void updateEmailEncryptionBetaSettings(Map<String, bool> enabledByAddress);
  void hydrateAccountAddress({required String address, int? accountId});
  void setPrimaryAccountId(int? accountId);
  String? selfJidForAccount(int accountId);
  void addEventListener(void Function(DeltaCoreEvent event) listener);
  void removeEventListener(void Function(DeltaCoreEvent event) listener);

  Future<bool> isConfigured({int? accountId});
  Future<void> deconfigureAccount({int? accountId});
  @override
  Future<void> configureAccount({
    required String address,
    required String password,
    required String displayName,
    Map<String, String> additional = const {},
    int? accountId,
  });
  Future<void> stopEventDeliveryForLogout();
  Future<bool> bootstrapFromCore({int? accountId});
  Future<void> refreshChatlistSnapshot({int? accountId});
  Future<void> notifyNetworkAvailable();
  Future<void> notifyNetworkLost();
  Future<bool> performBackgroundFetch(Duration timeout);
  Future<void> backfillChatHistory({
    required int chatId,
    required String chatJid,
    required int desiredWindow,
    int? beforeMessageId,
    DateTime? beforeTimestamp,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    int? accountId,
  });
  Future<String?> connectivityDetails({int? accountId});
  Future<DeltaChatSendCapabilities> chatSendCapabilities({
    required int chatId,
    int? accountId,
  });
  Future<DeltaContactPublicKeyRemoval> removeContactPublicKey({
    required String address,
    required String fingerprint,
    required int contactId,
    required int chatId,
    int? accountId,
  });
  Future<List<int>> accountIds();
  Future<int> createAccount({bool closed = false});
  Future<void> ensureAccountSession(int? accountId);
  Future<bool> removeAccount(int accountId);
  Future<String?> getCoreConfig(String key, {int? accountId});
  Future<String?> getOauth2Url({
    required String address,
    required String redirectUri,
    int? accountId,
  });
  Future<void> setCoreConfig({
    required String key,
    required String value,
    int? accountId,
  });
  Future<bool> setCoreConfigIfSupported({
    required String key,
    required String value,
    int? accountId,
  });
  Future<DeltaOpenPgpKeyMetadata> inspectOpenPgpKey({
    required String armored,
    required String expectedAddress,
    required DeltaOpenPgpKeyKind expectedKind,
    int? accountId,
  });
  Future<DeltaContactPublicKeyImport> importContactPublicKey({
    required String address,
    required String displayName,
    required String armoredPublicKey,
    int? accountId,
  });
  Future<EmailDeltaImexResult> runImex({
    required int mode,
    required String path,
    int? accountId,
    Duration timeout = const Duration(minutes: 2),
  });
  Future<void> cancelImex({int? accountId});
  Future<void> registerPushToken(String token);
  @override
  Future<int> sendText({
    required int chatId,
    required String body,
    String? subject,
    String? shareId,
    String? localBodyOverride,
    String? htmlBody,
    String? quotingStanzaId,
    int? accountId,
    bool forcePlaintext = false,
    bool skipAutocrypt = false,
  });
  @override
  Future<int> sendAttachment({
    required int chatId,
    required EmailAttachment attachment,
    String? subject,
    String? shareId,
    String? captionOverride,
    String? htmlCaption,
    String? quotingStanzaId,
    int? accountId,
    bool forcePlaintext = false,
    bool skipAutocrypt = false,
  });
  Future<bool> blockContact(String address, {int? accountId});
  Future<bool> unblockContact(String address, {int? accountId});
  Future<bool> markNoticedChat(int chatId, {int? accountId});
  Future<bool> markSeenMessages(List<int> messageIds, {int? accountId});
  Future<int> getFreshMessageCount(int chatId, {int? accountId});
  Future<DeltaFreshMessageCount> getFreshMessageCountSafe(
    int chatId, {
    int? accountId,
  });
  Future<List<DeltaChatlistEntry>> getChatlist({int flags = 0, int? accountId});
  Future<DeltaChat?> getChat(int chatId, {int? accountId});
  Future<List<int>> getFreshMessageIds({int? accountId});
  Future<bool> deleteMessages(List<int> messageIds, {int? accountId});
  Future<List<int>> searchMessages({
    required int chatId,
    required String query,
    int? accountId,
  });
  Future<List<int>> getChatMessageIds({
    required int chatId,
    int? beforeMessageId,
    int? accountId,
  });
  Future<void> hydrateMessages(List<int> messageIds, {int? accountId});
  Future<bool> setChatVisibility({
    required int chatId,
    required int visibility,
    int? accountId,
  });
  Future<bool> downloadFullMessage(int messageId, {int? accountId});
  Future<bool> resendMessages(List<int> messageIds, {int? accountId});
  Future<int> sendTextWithQuote({
    required int chatId,
    required String body,
    required int quotedMessageId,
    String? quotedStanzaId,
    String? subject,
    String? htmlBody,
    int? accountId,
    bool forcePlaintext = false,
    bool skipAutocrypt = false,
  });
  Future<DeltaQuotedMessage?> getQuotedMessage(int messageId, {int? accountId});
  Future<bool> setDraft({
    required int chatId,
    DeltaMessage? message,
    int? accountId,
  });
  Future<DeltaMessage?> getDraft(int chatId, {int? accountId});
  Future<DeltaMessage?> getMessage(int messageId, {int? accountId});
  Future<DeltaMessageStatus?> getMessageStatus(int messageId, {int? accountId});

  Future<List<DeltaMessage>> getMessages(
    List<int> messageIds, {
    int? accountId,
  });
  Future<List<DeltaMessageStatus>> getMessageStatuses(
    List<int> messageIds, {
    int? accountId,
  });
  Future<String?> getMessageMimeHeaders(int messageId, {int? accountId});
  Future<String?> getMessageRfc724Mid(int messageId, {int? accountId});
  Future<String?> getMessageInfo(int messageId, {int? accountId});
  Future<String?> getMessageDebugInfo(int messageId, {int? accountId});
  Future<String?> getMessageFullHtml(int messageId, {int? accountId});
  Future<DeltaMessageRfc822Body?> getMessageRfc822Body(
    int messageId, {
    int? accountId,
  });
  Future<List<int>> getContactIds({
    int flags = 0,
    String? query,
    int? accountId,
  });
  Future<List<int>> getBlockedContactIds({int? accountId});
  Future<bool> deleteContact(int contactId, {int? accountId});
  Future<DeltaContact?> getContact(int contactId, {int? accountId});
  Future<void> deleteStorageArtifacts({String? databasePrefix});
  @override
  Future<void> dispose({bool requestWorkerDispose = true});
}

class EmailDeltaTransport implements EmailDeltaRuntime {
  EmailDeltaTransport({
    required Future<XmppDatabase> Function() databaseBuilder,
    Future<File> Function(String prefix)? deltaDatabaseFileBuilder,
    Future<T> Function<T>(Future<T> Function() operation)?
    databaseOperationTracker,
    DeltaSafe? deltaSafe,
    Logger? logger,
    AppLocalizations Function()? localizationsProvider,
    String? Function()? xmppSelfJidProvider,
    bool persistEvents = true,
    bool useAccounts = false,
  }) : _databaseBuilder = databaseBuilder,
       _deltaDatabaseFileBuilder = deltaDatabaseFileBuilder,
       _databaseOperationTracker = databaseOperationTracker,
       _deltaSafe = deltaSafe,
       _log = logger ?? Logger('EmailDeltaTransport'),
       _localizationsProvider = localizationsProvider,
       _xmppSelfJidProvider = xmppSelfJidProvider,
       _persistEvents = persistEvents,
       _useAccounts = useAccounts;

  final Future<XmppDatabase> Function() _databaseBuilder;
  final Future<File> Function(String prefix)? _deltaDatabaseFileBuilder;
  Future<T> Function<T>(Future<T> Function() operation)?
  _databaseOperationTracker;
  DeltaSafe? _deltaSafe;
  final Logger _log;
  final AppLocalizations Function()? _localizationsProvider;
  final String? Function()? _xmppSelfJidProvider;
  final bool _persistEvents;
  final bool _useAccounts;

  DeltaAccountsHandle? _accounts;
  DeltaContextHandle? _context;
  bool _contextOpened = false;
  Future<void>? _contextOpening;
  bool _ioRunning = false;
  final Map<int, _DeltaAccountSession> _accountSessions = {};
  Map<String, bool> _emailEncryptionBetaEnabledByAddress =
      const <String, bool>{};

  @override
  void Function()? onRuntimeRestarted;

  DeltaSafe get _delta => _deltaSafe ??= DeltaSafe();

  @override
  void updateDatabaseOperationTracker(
    Future<T> Function<T>(Future<T> Function() operation)? tracker,
  ) {
    _databaseOperationTracker = tracker;
  }

  Future<T> _trackDatabaseOperation<T>(Future<T> Function() operation) {
    final tracker = _databaseOperationTracker;
    if (tracker == null) {
      return operation();
    }
    return tracker(operation);
  }

  @override
  void updateEmailEncryptionBetaSettings(Map<String, bool> enabledByAddress) {
    final normalized = <String, bool>{};
    for (final entry in enabledByAddress.entries) {
      if (!entry.value) {
        continue;
      }
      final address = normalizedAddressValue(entry.key);
      if (address == null || address.isEmpty || !address.isValidEmailAddress) {
        continue;
      }
      normalized[address] = true;
    }
    _emailEncryptionBetaEnabledByAddress = Map<String, bool>.unmodifiable(
      normalized,
    );
  }

  final Map<int, StreamSubscription<DeltaCoreEvent>> _eventSubscriptions = {};
  final Map<int, Future<_DeltaAccountSession>> _accountOpening = {};
  final List<void Function(DeltaCoreEvent)> _eventListeners = [];
  final Set<int> _activeImexAccountIds = <int>{};
  StreamSubscription<DeltaCoreEvent>? _accountsEventSubscription;
  final Set<Future<void>> _activeEventOperations = <Future<void>>{};
  final Set<Future<void>> _activeCoreOperations = <Future<void>>{};
  int _coreOperationEpoch = 0;
  _DeltaEventDeliveryBlockReason? _eventDeliveryBlockReason;

  bool get _eventDeliveryBlocked => _eventDeliveryBlockReason != null;

  bool get _eventDeliveryBlockedForLogout =>
      _eventDeliveryBlockReason == _DeltaEventDeliveryBlockReason.logout;

  String? _databasePrefix;
  String? _databasePassphrase;
  final Map<int, String> _accountAddresses = {};
  int? _primaryAccountId;

  Future<T> _trackCoreOperation<T>(Future<T> Function() operation) {
    final future = Future<T>.sync(operation);
    late final Future<void> tracked;
    tracked = future.then<void>((_) {}, onError: (_, _) {});
    _activeCoreOperations.add(tracked);
    tracked.whenComplete(() {
      _activeCoreOperations.remove(tracked);
    });
    return future;
  }

  Future<T> _trackEventOperation<T>(Future<T> Function() operation) {
    final future = Future<T>.sync(operation);
    late final Future<void> tracked;
    tracked = future.then<void>((_) {}, onError: (_, _) {});
    _activeEventOperations.add(tracked);
    tracked.whenComplete(() {
      _activeEventOperations.remove(tracked);
    });
    return future;
  }

  Future<void> _awaitActiveEventOperations() async {
    while (_activeEventOperations.isNotEmpty) {
      await Future.wait(_activeEventOperations.toList(growable: false));
    }
  }

  Future<void> _awaitActiveCoreOperations() async {
    while (_activeCoreOperations.isNotEmpty) {
      await Future.wait(_activeCoreOperations.toList(growable: false));
    }
  }

  void _invalidateCoreOperationEpoch() {
    _coreOperationEpoch += 1;
  }

  bool _isCurrentCoreOperationEpoch(int epoch) => epoch == _coreOperationEpoch;

  @override
  Stream<DeltaCoreEvent> get events =>
      _accounts?.events() ??
      _context?.events() ??
      const Stream<DeltaCoreEvent>.empty();

  @override
  String? get selfJid => _selfJidForAccount(_defaultAccountId);

  @override
  void hydrateAccountAddress({required String address, int? accountId}) {
    if (address.isEmpty) return;
    final resolvedAccountId = _resolveAccountIdForRequest(accountId);
    if (resolvedAccountId == null) return;
    _accountAddresses[resolvedAccountId] = address;
    _primaryAccountId ??= resolvedAccountId;
  }

  Future<void> _scheduleAccountAddressHydration({
    required DeltaContextHandle context,
    required int accountId,
  }) async {
    try {
      await _hydrateAccountAddressFromCore(
        context: context,
        accountId: accountId,
      );
    } on Exception catch (error, stackTrace) {
      _log.fine(_accountHydrationFailedLog, error, stackTrace);
    }
  }

  Future<void> _hydrateAccountAddressFromCore({
    required DeltaContextHandle context,
    required int accountId,
  }) async {
    final String? rawAddress = await context.getConfig(_deltaConfigKeyAddress);
    final String normalizedAddress = rawAddress?.trim() ?? '';
    if (normalizedAddress.isEmpty || normalizedAddress.isDeltaPlaceholderJid) {
      return;
    }
    hydrateAccountAddress(address: normalizedAddress, accountId: accountId);
    if (!_persistEvents) {
      return;
    }
    final db = await _databaseBuilder();
    final xmppSelfJid = _xmppSelfJidProvider?.call();
    await db.replaceDeltaPlaceholderSelfJids(
      deltaAccountId: accountId,
      resolvedAddress: normalizedAddress,
      placeholderJids: deltaPlaceholderJids,
      selfJid: xmppSelfJid,
      emailSelfJid: normalizedAddress,
    );
  }

  @override
  Future<void> ensureInitialized({
    required String databasePrefix,
    required String databasePassphrase,
  }) async {
    final prefixChanged =
        _databasePrefix != null && _databasePrefix != databasePrefix;
    final passphraseChanged =
        _databasePassphrase != null &&
        _databasePassphrase != databasePassphrase;
    final needsReplacement =
        _context != null && (prefixChanged || passphraseChanged);

    if (needsReplacement) {
      await _teardownContext();
    }

    _databasePrefix = databasePrefix;
    _databasePassphrase = databasePassphrase;
  }

  @override
  Future<bool> isConfigured({int? accountId}) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return false;
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    return session?.context.isConfigured ?? false;
  }

  @override
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
    final configureLogConfig = _sanitizeDeltaConfigForLog(<String, String>{
      _deltaConfigKeyAddress: address,
      _deltaConfigKeyDisplayName: displayName,
      ...additional,
    });
    _log.warning(
      'Delta configure start. accountId=$resolvedAccountId '
      'config=$configureLogConfig',
    );
    final completer = Completer<void>();
    StreamSubscription<DeltaCoreEvent>? subscription;
    String? lastErrorDetail;
    try {
      for (final key in _deltaOverrideConfigKeys) {
        if (!overrideKeys.contains(key)) {
          await context.setConfig(key: key, value: _deltaConfigClearedValue);
        }
      }
      subscription = context.events().listen((event) {
        final eventType = DeltaEventType.fromCode(event.type);
        if (eventType == null) {
          return;
        }
        if (eventType == DeltaEventType.error) {
          lastErrorDetail = event.data2Text ?? event.data1Text;
          if (!completer.isCompleted) {
            completer.completeError(
              DeltaOperationException(
                lastErrorDetail ?? 'Failed to configure email account',
              ),
            );
          }
          return;
        }
        if (completer.isCompleted ||
            eventType != DeltaEventType.configureProgress) {
          return;
        }
        if (event.data1 == 1000) {
          completer.complete();
        } else if (event.data1 == 0) {
          completer.completeError(
            DeltaOperationException(
              event.data2Text ??
                  lastErrorDetail ??
                  'Failed to configure email account',
            ),
          );
        }
      });
      await context.configureAccount(
        address: address,
        password: password,
        displayName: displayName,
        additional: additional,
      );
      await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw const DeltaConfigurationTimeoutException();
        },
      );
      await _enforceTransportSecurity(context: context);
    } on DeltaSafeException catch (error, stackTrace) {
      String? supportedConfigKeys;
      try {
        supportedConfigKeys = await context.getConfig(
          _deltaConfigKeySystemConfigKeys,
        );
      } on Exception catch (configError, configStackTrace) {
        _log.fine(
          'Failed to read Delta config keys after configure failure.',
          configError,
          configStackTrace,
        );
      }
      _log.warning(
        'Delta configure failed. accountId=$resolvedAccountId '
        'message=${error.message} '
        'config=$configureLogConfig '
        'supportedKeys=${supportedConfigKeys ?? '<unavailable>'}',
        null,
        stackTrace,
      );
      rethrow;
    } finally {
      await subscription?.cancel();
    }
  }

  @override
  Future<void> start() async {
    await _ensureContextReady();
    final sessions = await _resolveSessions();
    for (final session in sessions) {
      await _enforceTransportSecurity(context: session.context);
    }
    if (_accounts != null) {
      await _accounts!.startIo();
    } else {
      await _context!.startIo();
    }
    _eventDeliveryBlockReason = null;
    for (final session in sessions) {
      _attachEventSubscription(session);
    }
    _ioRunning = true;
  }

  Future<void> _enforceTransportSecurity({DeltaContextHandle? context}) async {
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
        throw const DeltaTransportSecurityException(
          _emailSecurityModePlainError,
        );
      case _DeltaSecurityModeResolution.unknown:
        throw DeltaTransportSecurityException(
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
    final wasIoRunning = _ioRunning;
    Object? stopError;
    StackTrace? stopStackTrace;
    try {
      await stopEventDeliveryAndAwaitActiveOperations();
    } on Exception catch (error, stackTrace) {
      stopError = error;
      stopStackTrace = stackTrace;
    }
    _ioRunning = false;
    if (wasIoRunning) {
      try {
        if (_accounts != null) {
          await _accounts?.stopIo();
        } else {
          await _context?.stopIo();
        }
      } on Exception catch (error, stackTrace) {
        stopError ??= error;
        stopStackTrace ??= stackTrace;
      }
    }
    if (stopError != null) {
      Error.throwWithStackTrace(stopError, stopStackTrace!);
    }
  }

  Future<void> stopEventDeliveryAndAwaitActiveOperations() async {
    Object? eventDeliveryError;
    StackTrace? eventDeliveryStackTrace;
    try {
      await _stopEventDelivery(_DeltaEventDeliveryBlockReason.stopped);
    } on Exception catch (error, stackTrace) {
      eventDeliveryError = error;
      eventDeliveryStackTrace = stackTrace;
    }
    await _awaitActiveCoreOperations();
    if (eventDeliveryError != null) {
      Error.throwWithStackTrace(eventDeliveryError, eventDeliveryStackTrace!);
    }
  }

  @override
  Future<void> stopEventDeliveryForLogout() =>
      _stopEventDelivery(_DeltaEventDeliveryBlockReason.logout);

  Future<void> _stopEventDelivery(_DeltaEventDeliveryBlockReason reason) async {
    if (reason == _DeltaEventDeliveryBlockReason.logout ||
        _eventDeliveryBlockReason == null) {
      _eventDeliveryBlockReason = reason;
    }
    _invalidateCoreOperationEpoch();
    Object? cancellationError;
    StackTrace? cancellationStackTrace;
    try {
      await _cancelAccountsEventSubscription();
    } on Exception catch (error, stackTrace) {
      cancellationError ??= error;
      cancellationStackTrace ??= stackTrace;
    }
    for (final subscription in _eventSubscriptions.values.toList(
      growable: false,
    )) {
      try {
        await subscription.cancel();
      } on Exception catch (error, stackTrace) {
        cancellationError ??= error;
        cancellationStackTrace ??= stackTrace;
      }
    }
    _eventSubscriptions.clear();
    await _awaitActiveEventOperations();
    if (cancellationError != null) {
      Error.throwWithStackTrace(cancellationError, cancellationStackTrace!);
    }
  }

  @override
  Future<void> dispose({bool requestWorkerDispose = true}) async {
    await stop();
    await _teardownContext();
    _eventListeners.clear();
  }

  @override
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
      if (await session.consumer?.bootstrapFromCore() == true) {
        didBootstrap = true;
      }
    }
    return didBootstrap;
  }

  @override
  Future<void> refreshChatlistSnapshot({int? accountId}) =>
      _trackCoreOperation(() => _refreshChatlistSnapshot(accountId: accountId));

  Future<void> _refreshChatlistSnapshot({int? accountId}) async {
    final epoch = _coreOperationEpoch;
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    if (!_isCurrentCoreOperationEpoch(epoch)) {
      return;
    }
    final sessions = await _resolveSessions(accountId: accountId);
    for (final session in sessions) {
      if (!_isCurrentCoreOperationEpoch(epoch)) {
        return;
      }
      await session.consumer?.refreshChatlistSnapshot(
        isCurrent: () => _isCurrentCoreOperationEpoch(epoch),
      );
    }
  }

  @override
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

  @override
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

  @override
  Future<bool> performBackgroundFetch(Duration timeout) async {
    if (_ioRunning || _eventDeliveryBlockedForLogout) {
      return false;
    }
    await _ensureContextReady();
    if (_eventDeliveryBlockedForLogout) {
      return false;
    }
    final temporarySubscriptions =
        await _attachBackgroundFetchEventSubscriptions();
    if (temporarySubscriptions.blockedByLogout) {
      return false;
    }
    final accounts = _accounts;
    try {
      if (accounts == null) {
        final context = _context;
        if (context == null) {
          return false;
        }
        return await context.backgroundFetch(timeout);
      }
      return await accounts.backgroundFetch(timeout);
    } finally {
      await _detachBackgroundFetchEventSubscriptions(temporarySubscriptions);
    }
  }

  Future<_DeltaBackgroundFetchEventSubscriptions>
  _attachBackgroundFetchEventSubscriptions() async {
    if (_eventDeliveryBlockedForLogout) {
      return const _DeltaBackgroundFetchEventSubscriptions.blockedByLogout();
    }
    final hadAccountsSubscription = _accountsEventSubscription != null;
    final existingAccountSubscriptions = Set<int>.of(_eventSubscriptions.keys);
    if (_accounts != null) {
      _ensureAccountsEventSubscription(allowWhileBlocked: true);
    } else {
      final sessions = await _resolveSessions();
      if (_eventDeliveryBlockedForLogout) {
        return const _DeltaBackgroundFetchEventSubscriptions.blockedByLogout();
      }
      for (final session in sessions) {
        _attachEventSubscription(session, allowWhileBlocked: true);
      }
    }
    return _DeltaBackgroundFetchEventSubscriptions(
      hadAccountsSubscription: hadAccountsSubscription,
      existingAccountSubscriptions: existingAccountSubscriptions,
    );
  }

  Future<void> _detachBackgroundFetchEventSubscriptions(
    _DeltaBackgroundFetchEventSubscriptions subscriptions,
  ) async {
    await _awaitActiveEventOperations();
    if (_ioRunning) {
      return;
    }
    if (!subscriptions.hadAccountsSubscription) {
      await _cancelAccountsEventSubscription();
    }
    for (final accountId in _eventSubscriptions.keys.toList(growable: false)) {
      if (subscriptions.existingAccountSubscriptions.contains(accountId)) {
        continue;
      }
      final subscription = _eventSubscriptions.remove(accountId);
      await subscription?.cancel();
    }
  }

  @override
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

  @override
  Future<String?> connectivityDetails({int? accountId}) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return null;
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    return session?.context.connectivityDetails();
  }

  @override
  Future<DeltaChatSendCapabilities> chatSendCapabilities({
    required int chatId,
    int? accountId,
  }) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return const DeltaChatSendCapabilities(exists: false);
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return const DeltaChatSendCapabilities(exists: false);
    }
    return context.chatSendCapabilities(chatId);
  }

  @override
  Future<DeltaContactPublicKeyRemoval> removeContactPublicKey({
    required String address,
    required String fingerprint,
    required int contactId,
    required int chatId,
    int? accountId,
  }) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      throw const DeltaOperationException('Delta account is unavailable');
    }
    return context.removeContactPublicKey(
      address: address,
      fingerprint: fingerprint,
      contactId: contactId,
      chatId: chatId,
    );
  }

  @override
  bool get accountsSupported => _useAccounts;

  @override
  bool get accountsActive => _useAccounts && _accounts != null;

  @override
  int get activeAccountId => _defaultAccountId ?? DeltaAccountDefaults.legacyId;

  @override
  bool get isIoRunning => _ioRunning;

  @override
  bool get persistsAppStateInternally => _persistEvents;

  @override
  void setPrimaryAccountId(int? accountId) {
    _primaryAccountId = _resolveAccountIdForRequest(accountId);
  }

  @override
  String? selfJidForAccount(int accountId) {
    return _selfJidForAccount(accountId);
  }

  @override
  Future<List<int>> accountIds() async {
    await _ensureContextReady();
    final accounts = _accounts;
    if (_useAccounts && accounts != null) {
      final ids = await accounts.accountIds();
      return _singleSupportedAccountIds(ids);
    }
    return const <int>[DeltaAccountDefaults.singleContextId];
  }

  @override
  Future<int> createAccount({bool closed = false}) async {
    await _ensureContextReady();
    if (!_useAccounts) {
      throw const DeltaOperationException('Delta accounts unavailable');
    }
    final accounts = _accounts;
    if (accounts == null) {
      throw const DeltaOperationException('Delta accounts unavailable');
    }
    final accountId = await accounts.addAccount(closed: closed);
    if (accountId == DeltaAccountDefaults.legacyId) {
      throw const DeltaAllocationException('Failed to allocate Delta account');
    }
    return accountId;
  }

  @override
  Future<void> ensureAccountSession(int? accountId) async {
    await _ensureContextReady();
    await _ensureSession(accountId: accountId);
  }

  @override
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

  @override
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

  @override
  Future<String?> getOauth2Url({
    required String address,
    required String redirectUri,
    int? accountId,
  }) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return null;
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return null;
    }
    return context.getOauth2Url(address: address, redirectUri: redirectUri);
  }

  @override
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

  @override
  Future<bool> setCoreConfigIfSupported({
    required String key,
    required String value,
    int? accountId,
  }) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return false;
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return false;
    }
    return context.setConfigIfSupported(key: key, value: value);
  }

  @override
  Future<DeltaOpenPgpKeyMetadata> inspectOpenPgpKey({
    required String armored,
    required String expectedAddress,
    required DeltaOpenPgpKeyKind expectedKind,
    int? accountId,
  }) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      throw StateError('Transport not initialized');
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      throw StateError('Transport not initialized');
    }
    return context.inspectOpenPgpKey(
      armored: armored,
      expectedAddress: expectedAddress,
      expectedKind: expectedKind,
    );
  }

  @override
  Future<DeltaContactPublicKeyImport> importContactPublicKey({
    required String address,
    required String displayName,
    required String armoredPublicKey,
    int? accountId,
  }) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      throw StateError('Transport not initialized');
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      throw StateError('Transport not initialized');
    }
    return context.importContactPublicKey(
      address: address,
      displayName: displayName,
      armoredPublicKey: armoredPublicKey,
    );
  }

  @override
  Future<EmailDeltaImexResult> runImex({
    required int mode,
    required String path,
    int? accountId,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      throw StateError('Transport not initialized');
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    if (session == null) {
      throw StateError('Transport not initialized');
    }
    final resolvedAccountId = session.accountId;
    if (!_activeImexAccountIds.add(resolvedAccountId)) {
      throw EmailDeltaImexException(
        'Delta import/export already running for account $resolvedAccountId.',
      );
    }
    final context = session.context;
    try {
      return await _runImexForContext(
        context: context,
        accountId: resolvedAccountId,
        mode: mode,
        path: path,
        timeout: timeout,
      );
    } finally {
      _activeImexAccountIds.remove(resolvedAccountId);
    }
  }

  @override
  Future<void> cancelImex({int? accountId}) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return;
    }
    await context.stopOngoingProcess();
  }

  @override
  Future<void> registerPushToken(String token) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _ensureContextReady();
    if (!_useAccounts) {
      return;
    }
    final accounts = _accounts;
    if (accounts != null) {
      await accounts.setPushDeviceToken(token);
      return;
    }
    _log.finer('Delta accounts unavailable; deferring push token registration');
  }

  int? get _defaultAccountId {
    if (!_useAccounts) {
      return DeltaAccountDefaults.singleContextId;
    }
    final primary = _primaryAccountId;
    if (primary != null) {
      if (primary != DeltaAccountDefaults.legacyId) {
        return primary;
      }
      return _canonicalSessionAccountId;
    }
    if (_accounts != null) {
      final sessionAccountId = _canonicalSessionAccountId;
      if (sessionAccountId != null) {
        return sessionAccountId;
      }
      final contextAccountId = _context?.accountId;
      if (contextAccountId != null &&
          contextAccountId != DeltaAccountDefaults.legacyId) {
        return contextAccountId;
      }
      return null;
    }
    final sessionAccountId = _canonicalSessionAccountId;
    if (sessionAccountId != null) {
      return sessionAccountId;
    }
    final context = _context;
    if (context == null) return null;
    final contextAccountId = context.accountId;
    if (contextAccountId != null &&
        contextAccountId != DeltaAccountDefaults.legacyId) {
      return contextAccountId;
    }
    return null;
  }

  int? get _canonicalSessionAccountId {
    final ids = _accountSessions.keys
        .where((id) => id != DeltaAccountDefaults.legacyId)
        .toList(growable: false);
    if (ids.isEmpty) {
      return null;
    }
    final primary = _primaryAccountId;
    if (primary != null &&
        primary != DeltaAccountDefaults.legacyId &&
        ids.contains(primary)) {
      return primary;
    }
    return ids.first;
  }

  List<int> _singleSupportedAccountIds(Iterable<int> accountIds) {
    final seen = <int>{};
    final ids = <int>[];
    for (final accountId in accountIds) {
      if (accountId == DeltaAccountDefaults.legacyId) {
        continue;
      }
      if (seen.add(accountId)) {
        ids.add(accountId);
      }
    }
    if (ids.isEmpty) {
      return const <int>[];
    }
    final primary = _primaryAccountId;
    if (primary != null &&
        primary != DeltaAccountDefaults.legacyId &&
        ids.contains(primary)) {
      return List<int>.unmodifiable(<int>[primary]);
    }
    final contextAccountId = _context?.accountId;
    if (contextAccountId != null &&
        contextAccountId != DeltaAccountDefaults.legacyId &&
        ids.contains(contextAccountId)) {
      return List<int>.unmodifiable(<int>[contextAccountId]);
    }
    return List<int>.unmodifiable(<int>[ids.first]);
  }

  int? _resolveAccountIdForRequest(int? accountId) {
    if (!_useAccounts) {
      return DeltaAccountDefaults.singleContextId;
    }
    if (accountId == null) {
      return _defaultAccountId;
    }
    if (accountId != DeltaAccountDefaults.legacyId) {
      return accountId;
    }
    return null;
  }

  String _selfJidForAddress(String? address) {
    final trimmed = address?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return deltaAnonUserJid;
    }
    return trimmed;
  }

  String? _selfJidForAccount(int? accountId) {
    final resolvedId = _resolveAccountIdForRequest(accountId);
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
    final resolvedId = _resolveAccountIdForRequest(accountId);
    if (resolvedId == null) {
      return null;
    }
    final existing = _accountSessions[resolvedId];
    if (existing != null) {
      return existing;
    }
    if (_accounts != null && resolvedId == DeltaAccountDefaults.legacyId) {
      throw StateError('Legacy Delta account is not valid in accounts mode.');
    }
    if (_accounts == null) {
      final context = _context;
      if (context == null) {
        return null;
      }
      return await _registerSession(
        accountId: resolvedId,
        context: context,
        scheduleHydration: _contextOpened,
      );
    }
    return _ensureAccountSession(resolvedId);
  }

  Future<_DeltaAccountSession> _registerSession({
    required int accountId,
    required DeltaContextHandle context,
    bool scheduleHydration = _defaultScheduleAccountHydration,
  }) async {
    if (_accounts != null && accountId == DeltaAccountDefaults.legacyId) {
      throw StateError('Legacy Delta account is not valid in accounts mode.');
    }
    final existing = _accountSessions[accountId];
    if (existing != null) {
      return existing;
    }
    final consumer = _persistEvents
        ? DeltaEventConsumer(
            databaseBuilder: _databaseBuilder,
            core: DeltaContextEventCore(context, accountId: accountId),
            localizationsProvider: _localizationsProvider,
            selfJidProvider: () => _selfJidForAccount(accountId),
            xmppSelfJidProvider: _xmppSelfJidProvider,
            emailEncryptionBetaEnabledForAddress: (_, address) {
              final normalized = normalizedAddressValue(address);
              return normalized != null &&
                  _emailEncryptionBetaEnabledByAddress[normalized] == true;
            },
            logger: _log,
            databaseOperationTracker: _trackDatabaseOperation,
          )
        : null;
    final session = _DeltaAccountSession(
      accountId: accountId,
      context: context,
      consumer: consumer,
    );
    _accountSessions[accountId] = session;
    if (scheduleHydration) {
      await _scheduleAccountAddressHydration(
        context: context,
        accountId: accountId,
      );
    }
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
      return opening;
    }
    final task = _openAccountSession(accountId);
    _accountOpening[accountId] = task;
    try {
      return await task;
    } finally {
      _accountOpening.remove(accountId);
    }
  }

  Future<_DeltaAccountSession> _openAccountSession(int accountId) async {
    if (!_useAccounts) {
      final context = _context;
      if (context == null) {
        throw const DeltaOperationException('Delta context unavailable');
      }
      return _registerSession(
        accountId: DeltaAccountDefaults.singleContextId,
        context: context,
      );
    }
    final accounts = _accounts;
    if (accounts == null) {
      throw DeltaOperationException(
        'Delta accounts unavailable for account $accountId',
      );
    }
    final passphrase = _databasePassphrase;
    if (passphrase == null) {
      throw StateError('Transport not initialized');
    }
    final context = accounts.contextFor(accountId);
    await context.open(passphrase: passphrase);
    final session = await _registerSession(
      accountId: accountId,
      context: context,
    );
    _context ??= context;
    return session;
  }

  void _attachEventSubscription(
    _DeltaAccountSession session, {
    bool allowWhileBlocked = false,
  }) {
    if (_eventDeliveryBlocked && !allowWhileBlocked) {
      return;
    }
    if (_accounts != null) {
      _ensureAccountsEventSubscription(allowWhileBlocked: allowWhileBlocked);
      return;
    }
    if (_eventSubscriptions.containsKey(session.accountId)) {
      return;
    }
    final subscription = session.context.events().listen((event) {
      final scopedEvent = _deltaEventForAccount(
        event: event,
        accountId: session.accountId,
      );
      unawaited(
        _trackEventOperation(
          () => _handleEvent(event: scopedEvent, consumer: session.consumer),
        ),
      );
    });
    _eventSubscriptions[session.accountId] = subscription;
  }

  void _ensureAccountsEventSubscription({bool allowWhileBlocked = false}) {
    if (_eventDeliveryBlocked && !allowWhileBlocked) {
      return;
    }
    if (_accountsEventSubscription != null) {
      return;
    }
    final accounts = _accounts;
    if (accounts == null) {
      return;
    }
    _accountsEventSubscription = accounts.events().listen((event) {
      unawaited(_trackEventOperation(() => _handleAccountsEvent(event)));
    });
  }

  Future<void> _cancelAccountsEventSubscription() async {
    final subscription = _accountsEventSubscription;
    if (subscription == null) {
      return;
    }
    _accountsEventSubscription = null;
    await subscription.cancel();
  }

  int? _eventAccountId(DeltaCoreEvent event) {
    final accountId = event.accountId;
    if (accountId != null && accountId != DeltaAccountDefaults.legacyId) {
      return accountId;
    }
    final sessionIds = _accountSessions.keys
        .where((id) => id != DeltaAccountDefaults.legacyId)
        .toSet();
    const singleSessionCount = 1;
    return sessionIds.length == singleSessionCount ? sessionIds.single : null;
  }

  bool _imexEventBelongsToAccount(DeltaCoreEvent event, int accountId) {
    final eventAccountId = event.accountId;
    return eventAccountId == null ||
        eventAccountId == DeltaAccountDefaults.legacyId ||
        eventAccountId == accountId;
  }

  Future<void> _handleAccountsEvent(DeltaCoreEvent event) async {
    final accountId = _eventAccountId(event);
    if (accountId == null) {
      _log.fine('Delta event missing account id; skipping.');
      return;
    }
    final session = await _ensureSession(accountId: accountId);
    if (session == null) {
      _log.warning('Delta event for account $accountId without session.');
      return;
    }
    await _handleEvent(
      event: _deltaEventForAccount(
        event: event,
        accountId: accountId,
        preserveNativeAccountId: true,
      ),
      consumer: session.consumer,
    );
  }

  Future<void> _handleEvent({
    required DeltaCoreEvent event,
    required DeltaEventConsumer? consumer,
  }) async {
    try {
      final notifyBeforeHandle = event.type == DeltaEventCode.chatDeleted;
      if (notifyBeforeHandle) {
        for (final listener in List.of(_eventListeners)) {
          listener(event);
        }
      }
      await consumer?.handle(event);
      if (!notifyBeforeHandle) {
        for (final listener in List.of(_eventListeners)) {
          listener(event);
        }
      }
    } on Exception catch (error, stackTrace) {
      _log.severe('Failed to handle Delta event', error, stackTrace);
    }
  }

  Future<List<_DeltaAccountSession>> _resolveSessions({int? accountId}) async {
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
    await _cancelAccountsEventSubscription();
    for (final subscription in _eventSubscriptions.values.toList(
      growable: false,
    )) {
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

  bool get _singleContextReady =>
      !_useAccounts &&
      _context != null &&
      _contextOpened &&
      _accountSessions.containsKey(DeltaAccountDefaults.singleContextId);

  Future<void> _ensureContextReady() async {
    final opening = _contextOpening;
    if (opening != null) {
      await opening;
      return;
    }
    if (_singleContextReady) {
      return;
    }
    final task = _openContextReady();
    _contextOpening = task;
    try {
      await task;
    } finally {
      if (identical(_contextOpening, task)) {
        _contextOpening = null;
      }
    }
  }

  Future<void> _openContextReady() async {
    final prefix = _databasePrefix;
    final passphrase = _databasePassphrase;
    if (prefix == null || passphrase == null) {
      throw StateError('Transport not initialized');
    }
    if (_useAccounts) {
      await _openAccountsContext(prefix, passphrase);
      return;
    }
    await _openSingleContext(prefix, passphrase);
  }

  Future<void> _openSingleContext(String prefix, String passphrase) async {
    final databaseFile = await _deltaDatabaseFile(prefix);
    try {
      if (_context == null && !await databaseFile.exists()) {
        await _migrateLegacyAccountsStorageIfNeeded(
          prefix: prefix,
          passphrase: passphrase,
          databaseFile: databaseFile,
        );
      }
      _context ??= await _delta.createContext(
        databasePath: databaseFile.path,
        osName: Platform.operatingSystem,
      );
      if (!_contextOpened) {
        await _context!.open(passphrase: passphrase);
        _contextOpened = true;
      }
      _primaryAccountId ??= DeltaAccountDefaults.singleContextId;
      await _registerSession(
        accountId: DeltaAccountDefaults.singleContextId,
        context: _context!,
      );
    } on DeltaSafeException catch (error, stackTrace) {
      _log.warning(
        'Failed to open Delta context at ${databaseFile.path}',
        error,
        stackTrace,
      );
      await _context?.close();
      _context = null;
      _contextOpened = false;
      await _clearSessions();
      rethrow;
    }
  }

  Future<void> _migrateLegacyAccountsStorageIfNeeded({
    required String prefix,
    required String passphrase,
    required File databaseFile,
  }) async {
    final accountsDirectory = await _accountsDirectory(prefix);
    if (!await _legacyAccountsDirectoryHasEntries(accountsDirectory)) {
      return;
    }

    DeltaAccountsHandle? accounts;
    DeltaContextHandle? sourceContext;
    DeltaContextHandle? targetContext;
    Directory? exportDirectory;
    var targetCreated = false;
    var migrated = false;
    try {
      accounts = await _delta.createAccounts(directory: accountsDirectory.path);
      final selected = await _selectLegacyAccountForSingleContextMigration(
        accounts: accounts,
        passphrase: passphrase,
      );
      if (selected == null) {
        throw const DeltaOperationException(
          'Legacy Delta accounts storage contains files but no accounts.',
        );
      }

      sourceContext = accounts.contextFor(selected.accountId);
      await sourceContext.open(passphrase: passphrase);
      exportDirectory = await _createLegacyMigrationExportDirectory(
        databaseFile,
      );
      final exportResult = await _runImexForContext(
        context: sourceContext,
        accountId: selected.accountId,
        mode: DeltaImexMode.exportBackup,
        path: exportDirectory.path,
        timeout: const Duration(minutes: 5),
      );
      final backupPath = await _legacyMigrationBackupPath(
        exportDirectory: exportDirectory,
        exportResult: exportResult,
      );

      targetContext = await _delta.createContext(
        databasePath: databaseFile.path,
        osName: Platform.operatingSystem,
      );
      targetCreated = true;
      await targetContext.open(passphrase: passphrase);
      await _runImexForContext(
        context: targetContext,
        accountId: DeltaAccountDefaults.singleContextId,
        mode: DeltaImexMode.importBackup,
        path: backupPath,
        timeout: const Duration(minutes: 5),
      );
      migrated = true;
      _log.info(
        'Migrated legacy Delta account ${selected.accountId} to direct '
        'single-context storage.',
      );
    } on EmailDeltaImexException catch (error) {
      throw DeltaOperationException(
        'Failed to migrate legacy Delta accounts storage: ${error.message}',
      );
    } finally {
      await targetContext?.close();
      await sourceContext?.close();
      await accounts?.dispose();
      await _deleteLegacyMigrationExportDirectory(exportDirectory);
      if (targetCreated && !migrated) {
        await _deleteDatabaseArtifacts(databaseFile);
      }
    }
  }

  Future<bool> _legacyAccountsDirectoryHasEntries(Directory directory) async {
    if (!await directory.exists()) {
      return false;
    }
    await for (final _ in directory.list(followLinks: false)) {
      return true;
    }
    return false;
  }

  Future<({int accountId, String? address})?>
  _selectLegacyAccountForSingleContextMigration({
    required DeltaAccountsHandle accounts,
    required String passphrase,
  }) async {
    final accountIds = <int>[];
    final seen = <int>{};
    for (final accountId in await accounts.accountIds()) {
      if (seen.add(accountId)) {
        accountIds.add(accountId);
      }
    }
    if (accountIds.isEmpty) {
      return null;
    }

    final candidates = <({int accountId, String? address})>[];
    for (final accountId in accountIds) {
      final context = accounts.contextFor(accountId);
      await context.open(passphrase: passphrase);
      candidates.add((
        accountId: accountId,
        address: await _configuredAddressForContext(context),
      ));
    }

    final expectedAddress = _singleContextMigrationAddress();
    if (expectedAddress != null) {
      final matching = candidates
          .where((candidate) => candidate.address == expectedAddress)
          .toList(growable: false);
      if (matching.length == 1) {
        return matching.single;
      }
      if (matching.length > 1) {
        throw DeltaOperationException(
          'Legacy Delta accounts storage has multiple accounts for '
          '$expectedAddress.',
        );
      }
    }

    if (candidates.length == 1) {
      final only = candidates.single;
      if (expectedAddress == null || only.address == null) {
        return only;
      }
    }

    final descriptions = candidates
        .map(
          (candidate) =>
              '${candidate.accountId}:${candidate.address ?? '<unknown>'}',
        )
        .join(',');
    throw DeltaOperationException(
      'Legacy Delta accounts storage is ambiguous for direct single-context '
      'migration. expectedAddress=${expectedAddress ?? '<unknown>'} '
      'candidates=$descriptions',
    );
  }

  Future<String?> _configuredAddressForContext(
    DeltaContextHandle context,
  ) async {
    final rawAddress = await context.getConfig(_deltaConfigKeyAddress);
    final normalized = normalizedAddressValue(rawAddress);
    if (normalized == null || normalized.isDeltaPlaceholderJid) {
      return null;
    }
    return normalized;
  }

  String? _singleContextMigrationAddress() {
    final primary = _accountAddresses[DeltaAccountDefaults.singleContextId];
    final normalizedPrimary = normalizedAddressValue(primary);
    if (normalizedPrimary != null && !normalizedPrimary.isDeltaPlaceholderJid) {
      return normalizedPrimary;
    }
    for (final address in _accountAddresses.values) {
      final normalized = normalizedAddressValue(address);
      if (normalized != null && !normalized.isDeltaPlaceholderJid) {
        return normalized;
      }
    }
    return null;
  }

  Future<Directory> _createLegacyMigrationExportDirectory(
    File databaseFile,
  ) async {
    final parent = databaseFile.parent;
    await parent.create(recursive: true);
    return parent.createTemp('${p.basename(databaseFile.path)}_migration_');
  }

  Future<String> _legacyMigrationBackupPath({
    required Directory exportDirectory,
    required EmailDeltaImexResult exportResult,
  }) async {
    for (final path in exportResult.exportedPaths) {
      if (await File(path).exists()) {
        return path;
      }
    }
    final files = <File>[];
    await for (final entity in exportDirectory.list(followLinks: false)) {
      if (entity is File) {
        files.add(entity);
      }
    }
    if (files.isEmpty) {
      throw const EmailDeltaImexException(
        'Delta backup export did not produce a backup file.',
      );
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files.first.path;
  }

  Future<void> _deleteLegacyMigrationExportDirectory(
    Directory? directory,
  ) async {
    if (directory == null) {
      return;
    }
    try {
      final deleted = await deleteAppOwnedDirectoryTree(
        directory: directory,
        expectedPath: directory.path,
      );
      if (!deleted) {
        _log.warning(
          'Skipped legacy Delta migration cleanup for unexpected path '
          '${directory.path}',
        );
      }
    } on IOException catch (error, stackTrace) {
      _log.warning(
        'Failed to clean up legacy Delta migration directory ${directory.path}',
        error,
        stackTrace,
      );
    }
  }

  Future<EmailDeltaImexResult> _runImexForContext({
    required DeltaContextHandle context,
    required int accountId,
    required int mode,
    required String path,
    required Duration timeout,
  }) async {
    final exportedPaths = <String>[];
    final completer = Completer<EmailDeltaImexResult>();
    final subscription = context.events().listen(
      (event) {
        if (!_imexEventBelongsToAccount(event, accountId)) {
          return;
        }
        final eventType = DeltaEventType.fromCode(event.type);
        switch (eventType) {
          case DeltaEventType.imexFileWritten:
            final path = event.data2Text?.trim();
            if (path != null && path.isNotEmpty) {
              exportedPaths.add(path);
            }
          case DeltaEventType.imexProgress:
            if (event.data1 == 1000) {
              if (!completer.isCompleted) {
                completer.complete(
                  EmailDeltaImexResult(
                    accountId: accountId,
                    exportedPaths: List<String>.unmodifiable(exportedPaths),
                  ),
                );
              }
            } else if (event.data1 == 0 && !completer.isCompleted) {
              completer.completeError(
                EmailDeltaImexException(
                  event.data2Text ??
                      event.data1Text ??
                      'Delta import/export failed.',
                ),
              );
            }
          default:
            break;
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(
            const EmailDeltaImexException(
              'Delta import/export event stream failed.',
            ),
            stackTrace,
          );
        }
      },
    );
    try {
      await context.startImex(mode: mode, path: path);
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      await context.stopOngoingProcess();
      throw const EmailDeltaImexTimeoutException();
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _openAccountsContext(String prefix, String passphrase) async {
    var firstFailure = true;
    bool shouldRetry() {
      if (firstFailure) {
        firstFailure = false;
        return true;
      }
      return false;
    }

    while (true) {
      try {
        _accounts ??= await _createAccounts(prefix);
      } on DeltaSafeException catch (error, stackTrace) {
        _log.warning('Delta accounts unavailable', error, stackTrace);
        await _accounts?.dispose();
        _accounts = null;
        _context = null;
        _contextOpened = false;
        await _clearSessions();
        rethrow;
      }
      final databaseFile = await _deltaDatabaseFile(prefix);
      final databasePath = await databaseFile.exists()
          ? databaseFile.path
          : null;
      int accountId;
      try {
        accountId = await _accounts!.ensureAccount(
          legacyDatabasePath: databasePath,
        );
        if (accountId == DeltaAccountDefaults.legacyId) {
          throw const DeltaAllocationException(
            'Failed to allocate Delta account',
          );
        }
      } on DeltaSafeException catch (error, stackTrace) {
        if (!shouldRetry()) {
          _log.warning(
            'Delta accounts ensureAccount failed',
            error,
            stackTrace,
          );
          await _accounts?.dispose();
          _accounts = null;
          _context = null;
          _contextOpened = false;
          await _clearSessions();
          rethrow;
        }
        _log.warning(
          'Delta accounts ensureAccount failed; retrying',
          error,
          stackTrace,
        );
        await _accounts?.dispose();
        _accounts = null;
        _context = null;
        _contextOpened = false;
        await _clearSessions();
        continue;
      }
      _context ??= _accounts!.contextFor(accountId);
      if (!_contextOpened) {
        try {
          await _context!.open(passphrase: passphrase);
          _contextOpened = true;
        } on DeltaSafeException catch (error, stackTrace) {
          if (!shouldRetry()) {
            _log.warning(
              'Failed to open Delta account at ${databaseFile.path}',
              error,
              stackTrace,
            );
            await _accounts?.dispose();
            _accounts = null;
            _context = null;
            _contextOpened = false;
            await _clearSessions();
            rethrow;
          }
          _log.warning(
            'Failed to open Delta account at ${databaseFile.path}; retrying',
            error,
            stackTrace,
          );
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
        await _registerSession(accountId: accountId, context: _context!);
      }
      return;
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
    String? quotingStanzaId,
    int? accountId,
    bool forcePlaintext = false,
    bool skipAutocrypt = false,
  }) async {
    final session = await _ensureSession(accountId: accountId);
    if (session == null) {
      throw StateError('Transport not initialized');
    }
    final context = session.context;
    final resolvedAccountId = session.accountId;
    final sanitizedSubject = sanitizeEmailSubjectValue(subject);
    if (!_persistEvents) {
      return context.sendText(
        chatId: chatId,
        message: body,
        subject: subjectForDeltaCore(subject),
        html: htmlBody,
        forcePlaintext: forcePlaintext,
        skipAutocrypt: skipAutocrypt,
      );
    }
    final Chat chat = await _requireReadyOutgoingChat(
      chatId: chatId,
      accountId: resolvedAccountId,
      context: context,
    );
    final coreSubject = subjectForDeltaCore(subject);
    return _sendAndRecordOutgoing(
      session: session,
      chatId: chatId,
      accountId: resolvedAccountId,
      chat: chat,
      send: () => context.sendText(
        chatId: chatId,
        message: body,
        subject: coreSubject,
        html: htmlBody,
        forcePlaintext: forcePlaintext,
        skipAutocrypt: skipAutocrypt,
      ),
      body: body,
      subject: sanitizedSubject,
      quotingStanzaId: quotingStanzaId,
      shareId: shareId,
      localBodyOverride: localBodyOverride,
      htmlBody: htmlBody,
    );
  }

  @override
  Future<int> sendAttachment({
    required int chatId,
    required EmailAttachment attachment,
    String? subject,
    String? shareId,
    String? captionOverride,
    String? htmlCaption,
    String? quotingStanzaId,
    int? accountId,
    bool forcePlaintext = false,
    bool skipAutocrypt = false,
  }) async {
    final session = await _ensureSession(accountId: accountId);
    if (session == null) {
      throw StateError('Transport not initialized');
    }
    final context = session.context;
    final resolvedAccountId = session.accountId;
    final sanitizedSubject = sanitizeEmailSubjectValue(subject);
    final coreSubject = subjectForDeltaCore(subject);
    final sanitizedFileName = sanitizeEmailAttachmentFilename(
      attachment.fileName,
      fallbackPath: attachment.path,
    );
    final sanitizedMimeType = sanitizeEmailMimeType(attachment.mimeType);
    if (!_persistEvents) {
      return context.sendFileMessage(
        chatId: chatId,
        viewType: _viewTypeFor(attachment),
        filePath: attachment.path,
        fileName: sanitizedFileName,
        mimeType: sanitizedMimeType,
        text: attachment.caption,
        subject: coreSubject,
        html: htmlCaption,
        forcePlaintext: forcePlaintext,
        skipAutocrypt: skipAutocrypt,
      );
    }
    final Chat chat = await _requireReadyOutgoingChat(
      chatId: chatId,
      accountId: resolvedAccountId,
      context: context,
    );
    final int msgId = await _sendAndRecordOutgoing(
      session: session,
      chatId: chatId,
      accountId: resolvedAccountId,
      chat: chat,
      send: () => context.sendFileMessage(
        chatId: chatId,
        viewType: _viewTypeFor(attachment),
        filePath: attachment.path,
        fileName: sanitizedFileName,
        mimeType: sanitizedMimeType,
        text: attachment.caption,
        subject: coreSubject,
        html: htmlCaption,
        forcePlaintext: forcePlaintext,
        skipAutocrypt: skipAutocrypt,
      ),
      body: attachment.caption,
      subject: sanitizedSubject,
      quotingStanzaId: quotingStanzaId,
      shareId: shareId,
      localBodyOverride: captionOverride,
      htmlBody: htmlCaption,
    );
    return msgId;
  }

  @override
  Future<int> createContact({
    required String address,
    String? displayName,
    int? accountId,
  }) async {
    final session = await _ensureSession(accountId: accountId);
    if (session == null) {
      throw StateError('Transport not initialized');
    }
    final context = session.context;
    final trimmedAddress = address.trim();
    final trimmedDisplayName = displayName?.trim();
    final existing = await context.lookupContactIdByAddress(trimmedAddress);
    if (existing != null) {
      return existing;
    }
    return context.createContact(
      address: trimmedAddress,
      displayName: trimmedDisplayName?.isNotEmpty == true
          ? trimmedDisplayName!
          : trimmedAddress,
    );
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
    final trimmedAddress = address.trim();
    final trimmedDisplayName = displayName?.trim();
    final contactId = await createContact(
      address: trimmedAddress,
      displayName: trimmedDisplayName,
      accountId: session.accountId,
    );
    final chatId = await context.createChatByContactId(contactId);
    if (!_persistEvents) {
      return chatId;
    }
    await _ensureChat(chatId, accountId: session.accountId, context: context);
    return chatId;
  }

  Future<Chat> _requireReadyOutgoingChat({
    required int chatId,
    required int accountId,
    required DeltaContextHandle context,
  }) async {
    final Chat chat = await _ensureChat(
      chatId,
      accountId: accountId,
      context: context,
    );
    String senderJid = _resolveOutgoingSenderJid(
      chat: chat,
      accountId: accountId,
    );
    String normalizedSender = senderJid.trim();
    if (normalizedSender.isEmpty || normalizedSender.isDeltaPlaceholderJid) {
      await _hydrateAccountAddressFromCore(
        context: context,
        accountId: accountId,
      );
      senderJid = _resolveOutgoingSenderJid(chat: chat, accountId: accountId);
      normalizedSender = senderJid.trim();
    }
    if (normalizedSender.isEmpty || normalizedSender.isDeltaPlaceholderJid) {
      throw StateError(_emailAccountNotReadyError);
    }
    return chat;
  }

  Future<int> _sendAndRecordOutgoing({
    required _DeltaAccountSession session,
    required int chatId,
    required int accountId,
    required Chat chat,
    required Future<int> Function() send,
    String? body,
    String? subject,
    String? quotingStanzaId,
    String? shareId,
    String? localBodyOverride,
    String? htmlBody,
  }) async {
    final int msgId;
    try {
      msgId = await send();
    } on Exception {
      await _recordFailedOutgoing(
        chatId: chatId,
        accountId: accountId,
        chat: chat,
        body: body,
        subject: subject,
        quotingStanzaId: quotingStanzaId,
        localBodyOverride: localBodyOverride,
        htmlBody: htmlBody,
      );
      rethrow;
    }
    await session.consumer?.hydrateMessage(msgId);
    final db = await _databaseBuilder();
    if (shareId != null) {
      await db.insertMessageCopy(
        shareId: shareId,
        dcMsgId: msgId,
        dcChatId: chatId,
        dcAccountId: accountId,
      );
    }
    if (quotingStanzaId != null) {
      await _patchOutgoingQuote(
        db: db,
        msgId: msgId,
        accountId: accountId,
        chatId: chatId,
        quotingStanzaId: quotingStanzaId,
      );
    }
    return msgId;
  }

  Future<void> _patchOutgoingQuote({
    required XmppDatabase db,
    required int msgId,
    required int accountId,
    required int chatId,
    required String quotingStanzaId,
  }) async {
    final row = await db.getMessageByDeltaId(msgId, deltaAccountId: accountId);
    if (row == null || row.replyStanzaId != null) {
      return;
    }
    await db.updateMessage(row.copyWith(replyStanzaId: quotingStanzaId));
  }

  Future<void> _recordFailedOutgoing({
    required int chatId,
    required int accountId,
    required Chat chat,
    String? body,
    String? subject,
    String? quotingStanzaId,
    String? localBodyOverride,
    String? htmlBody,
  }) async {
    final XmppDatabase db = await _databaseBuilder();
    final displayBody = localBodyOverride ?? body;
    final trimmedBody = displayBody?.trim();
    final senderJid = _resolveOutgoingSenderJid(
      chat: chat,
      accountId: accountId,
    );
    await db.saveMessage(
      Message(
        stanzaID: uuid.v4(),
        senderJid: senderJid,
        chatJid: chat.jid,
        timestamp: DateTime.timestamp(),
        body: trimmedBody?.isNotEmpty == true ? trimmedBody : null,
        htmlBody: HtmlContentCodec.normalizeHtml(htmlBody),
        subject: subject,
        replyStanzaId: quotingStanzaId,
        error: MessageError.emailSendFailure,
        deltaChatId: chatId,
        deltaAccountId: accountId,
      ),
      selfJid: senderJid,
    );
  }

  String _resolveOutgoingSenderJid({
    required Chat chat,
    required int accountId,
  }) {
    final chatSender = chat.emailFromAddress?.trim();
    if (chatSender != null &&
        chatSender.isNotEmpty &&
        !chatSender.isDeltaPlaceholderJid) {
      return chatSender;
    }
    final accountSender = _selfJidForAccount(accountId);
    if (accountSender != null &&
        accountSender.isNotEmpty &&
        !accountSender.isDeltaPlaceholderJid) {
      return accountSender;
    }
    return _selfJidForAddress(null);
  }

  Future<Chat> _ensureChat(
    int chatId, {
    int? accountId,
    DeltaContextHandle? context,
  }) async {
    final db = await _databaseBuilder();
    final resolvedAccountId = _resolveAccountIdForRequest(accountId);
    if (resolvedAccountId == null) {
      throw StateError('Delta account is unavailable');
    }
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
        emailFromAddress:
            existingByAddress.emailFromAddress ?? chat.emailFromAddress,
        contactDisplayName: chat.contactDisplayName,
        contactID: chat.contactID,
        contactJid: existingByAddress.contactJid ?? chat.contactJid,
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
    final emptyTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
    final emailAddress = _normalizedAddress(remote?.contactAddress, chatId);
    final title = remote?.name ?? remote?.contactName ?? emailAddress;
    return Chat(
      jid: emailAddress,
      title: title,
      type: _mapChatType(remote?.type),
      lastChangeTimestamp: emptyTimestamp,
      encryptionProtocol: EncryptionProtocol.none,
      contactDisplayName: remote?.contactName ?? remote?.name ?? emailAddress,
      contactID: emailAddress,
      contactJid: emailAddress,
      emailAddress: emailAddress,
      emailFromAddress: emailFromAddress,
      deltaChatId: chatId,
      transport: MessageTransport.email,
    );
  }

  Future<File> _deltaDatabaseFile(String prefix) async {
    final builder = _deltaDatabaseFileBuilder;
    if (builder != null) {
      return builder(prefix);
    }
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
      try {
        final deleted = await deleteAppOwnedFile(
          file: candidate,
          expectedPath: candidate.path,
        );
        if (!deleted) {
          _log.warning(
            'Skipped Delta database artifact cleanup for unexpected path ${candidate.path}',
          );
        }
      } on IOException catch (error, stackTrace) {
        _log.warning(
          'Failed to delete Delta database artifact ${candidate.path}',
          error,
          stackTrace,
        );
      }
    }
  }

  @override
  void addEventListener(void Function(DeltaCoreEvent event) listener) {
    if (!_eventListeners.contains(listener)) {
      _eventListeners.add(listener);
    }
  }

  @override
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
    await directory.create(recursive: true);
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
      return await _delta.createAccounts(directory: directory.path);
    } on DeltaSafeException catch (error, stackTrace) {
      await logAccountsDirState('initial create');
      _log.warning(
        'Failed to open Delta accounts at ${directory.path}',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<Directory> _accountsDirectory(String prefix) async {
    final databaseFile = await _deltaDatabaseFile(prefix);
    return Directory('${databaseFile.path}.accounts');
  }

  Future<void> _resetAccountsStorage(String prefix) async {
    final directory = await _accountsDirectory(prefix);
    try {
      final deleted = await deleteAppOwnedDirectoryTree(
        directory: directory,
        expectedPath: directory.path,
      );
      if (!deleted) {
        _log.warning(
          'Skipped Delta accounts cleanup for unexpected path ${directory.path}',
        );
      }
    } on IOException catch (error, stackTrace) {
      _log.warning(
        'Failed to delete Delta accounts directory ${directory.path}',
        error,
        stackTrace,
      );
    }
    final databaseFile = await _deltaDatabaseFile(prefix);
    await _deleteDatabaseArtifacts(databaseFile);
  }

  @override
  Future<void> deleteStorageArtifacts({String? databasePrefix}) async {
    final explicitPrefix = databasePrefix?.trim();
    final normalizedExplicitPrefix = tryNormalizeAppOwnedPathSegment(
      explicitPrefix,
    );
    if (explicitPrefix != null &&
        explicitPrefix.isNotEmpty &&
        normalizedExplicitPrefix == null) {
      _log.warning(
        'Ignoring invalid explicit Delta database prefix during storage cleanup.',
      );
    }
    final rawPrefix = normalizedExplicitPrefix ?? _databasePrefix;
    final normalizedPrefix = tryNormalizeAppOwnedPathSegment(rawPrefix);
    if (rawPrefix != null && rawPrefix.isNotEmpty && normalizedPrefix == null) {
      _log.warning(
        'Skipping Delta storage cleanup for invalid database prefix.',
      );
      return;
    }
    if (normalizedPrefix == null) {
      return;
    }
    await _resetAccountsStorage(normalizedPrefix);
  }

  /// Blocks an email contact in DeltaChat core.
  ///
  /// Returns true if the contact was found and blocked.
  @override
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
  @override
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
  @override
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
  @override
  Future<bool> markSeenMessages(List<int> messageIds, {int? accountId}) async {
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
  @override
  Future<int> getFreshMessageCount(int chatId, {int? accountId}) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return 0;
    }
    return context.getFreshMessageCount(chatId);
  }

  @override
  Future<DeltaFreshMessageCount> getFreshMessageCountSafe(
    int chatId, {
    int? accountId,
  }) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return const DeltaFreshMessageCount.unsupported();
    }
    return context.getFreshMessageCountSafe(chatId);
  }

  @override
  Future<List<DeltaChatlistEntry>> getChatlist({
    int flags = 0,
    int? accountId,
  }) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return const <DeltaChatlistEntry>[];
    }
    return context.getChatlist(flags: flags);
  }

  @override
  Future<DeltaChat?> getChat(int chatId, {int? accountId}) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return null;
    }
    return context.getChat(chatId);
  }

  /// Returns all fresh (unread) message IDs across all chats.
  @override
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
  @override
  Future<bool> deleteMessages(List<int> messageIds, {int? accountId}) async {
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
  @override
  /// Searches messages in a chat.
  ///
  /// Pass chatId=0 to search all chats.
  @override
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

  @override
  Future<List<int>> getChatMessageIds({
    required int chatId,
    int? beforeMessageId,
    int? accountId,
  }) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return const <int>[];
    }
    if (beforeMessageId == null) {
      return context.getChatMessageIds(chatId: chatId);
    }
    return context.getChatMessageIds(
      chatId: chatId,
      beforeMessageId: beforeMessageId,
    );
  }

  @override
  Future<void> hydrateMessages(List<int> messageIds, {int? accountId}) async {
    if (messageIds.isEmpty) return;
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final consumer = session?.consumer;
    if (consumer == null) {
      return;
    }
    const int batchSize = 8;
    for (var index = 0; index < messageIds.length; index += batchSize) {
      final chunk = messageIds.skip(index).take(batchSize).toList();
      await Future.wait(chunk.map(consumer.hydrateMessage));
    }
  }

  /// Sets the visibility of a chat (normal, archived, pinned).
  ///
  /// Returns true if the operation succeeded.
  @override
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
  @override
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
  @override
  Future<bool> resendMessages(List<int> messageIds, {int? accountId}) async {
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
  @override
  Future<int> sendTextWithQuote({
    required int chatId,
    required String body,
    required int quotedMessageId,
    String? quotedStanzaId,
    String? subject,
    String? htmlBody,
    int? accountId,
    bool forcePlaintext = false,
    bool skipAutocrypt = false,
  }) async {
    final session = await _ensureSession(accountId: accountId);
    if (session == null) {
      throw StateError('Transport not initialized');
    }
    final context = session.context;
    final resolvedAccountId = session.accountId;
    final sanitizedSubject = sanitizeEmailSubjectValue(subject);
    if (!_persistEvents) {
      return context.sendTextWithQuote(
        chatId: chatId,
        message: body,
        quotedMessageId: quotedMessageId,
        subject: subjectForDeltaCore(subject),
        html: htmlBody,
        forcePlaintext: forcePlaintext,
        skipAutocrypt: skipAutocrypt,
      );
    }
    final Chat chat = await _requireReadyOutgoingChat(
      chatId: chatId,
      accountId: resolvedAccountId,
      context: context,
    );
    final coreSubject = subjectForDeltaCore(subject);
    return _sendAndRecordOutgoing(
      session: session,
      chatId: chatId,
      accountId: resolvedAccountId,
      chat: chat,
      send: () => context.sendTextWithQuote(
        chatId: chatId,
        message: body,
        quotedMessageId: quotedMessageId,
        subject: coreSubject,
        html: htmlBody,
        forcePlaintext: forcePlaintext,
        skipAutocrypt: skipAutocrypt,
      ),
      body: body,
      subject: sanitizedSubject,
      quotingStanzaId: quotedStanzaId,
      htmlBody: htmlBody,
    );
  }

  /// Gets the quoted message info for a message.
  @override
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
  @override
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
  @override
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
  @override
  Future<DeltaMessage?> getMessage(int messageId, {int? accountId}) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return null;
    }
    return context.getMessage(messageId);
  }

  @override
  Future<DeltaMessageStatus?> getMessageStatus(
    int messageId, {
    int? accountId,
  }) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return null;
    }
    return context.getMessageStatus(messageId);
  }

  @override
  Future<List<DeltaMessage>> getMessages(
    List<int> messageIds, {
    int? accountId,
  }) async {
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return const <DeltaMessage>[];
    }
    final messages = <DeltaMessage>[];
    for (final messageId in messageIds) {
      try {
        final message = await context.getMessage(messageId);
        if (message != null) {
          messages.add(message);
        }
      } on Exception catch (error, stackTrace) {
        _log.fine(
          'Skipping unreadable Delta message $messageId in bulk fetch.',
          error,
          stackTrace,
        );
      }
    }
    return messages;
  }

  @override
  Future<List<DeltaMessageStatus>> getMessageStatuses(
    List<int> messageIds, {
    int? accountId,
  }) async {
    if (messageIds.isEmpty) return const <DeltaMessageStatus>[];
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) {
      return const <DeltaMessageStatus>[];
    }
    final statuses = <DeltaMessageStatus>[];
    for (final messageId in messageIds) {
      try {
        final status = await context.getMessageStatus(messageId);
        if (status != null) {
          statuses.add(status);
        }
      } on Exception catch (error, stackTrace) {
        _log.fine(
          'Skipping unreadable Delta message status $messageId in bulk fetch.',
          error,
          stackTrace,
        );
      }
    }
    return statuses;
  }

  /// Gets raw MIME headers by message ID from core.
  @override
  Future<String?> getMessageMimeHeaders(int messageId, {int? accountId}) async {
    if (messageId <= _deltaMessageIdUnset) return null;
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) return null;
    return context.getMessageMimeHeaders(messageId);
  }

  /// Gets the RFC 724 Message-ID stored by Delta Core.
  @override
  Future<String?> getMessageRfc724Mid(int messageId, {int? accountId}) async {
    if (messageId <= _deltaMessageIdUnset) return null;
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) return null;
    return context.getMessageRfc724Mid(messageId);
  }

  @override
  Future<String?> getMessageInfo(int messageId, {int? accountId}) async {
    if (messageId <= _deltaMessageIdUnset) return null;
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) return null;
    return context.getMessageInfo(messageId);
  }

  @override
  Future<String?> getMessageDebugInfo(int messageId, {int? accountId}) async {
    if (messageId <= _deltaMessageIdUnset) return null;
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) return null;
    return context.getMessageDebugInfo(messageId);
  }

  /// Gets HTML synthesized from the stored raw MIME for a message.
  @override
  Future<String?> getMessageFullHtml(int messageId, {int? accountId}) async {
    if (messageId <= _deltaMessageIdUnset) return null;
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) return null;
    return context.getMessageFullHtml(messageId);
  }

  /// Gets body-only plain text and HTML parsed from the stored RFC822 MIME.
  @override
  Future<DeltaMessageRfc822Body?> getMessageRfc822Body(
    int messageId, {
    int? accountId,
  }) async {
    if (messageId <= _deltaMessageIdUnset) return null;
    await _ensureContextReady();
    final session = await _ensureSession(accountId: accountId);
    final context = session?.context;
    if (context == null) return null;
    return context.getMessageRfc822Body(messageId);
  }

  /// Gets contact IDs from core.
  ///
  /// Use flags from [DeltaContactListFlags] to filter results.
  @override
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
  @override
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
  @override
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
  @override
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
