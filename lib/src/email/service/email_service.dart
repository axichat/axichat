// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui';

import 'package:axichat/src/common/anti_abuse_sync.dart';
import 'package:axichat/src/common/email_validation.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/foreground_task_messages.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:axichat/src/common/synthetic_reply.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/demo/demo_chats.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:logging/logging.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:uuid/uuid.dart';

import 'package:axichat/src/email/models/email_account.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/models/email_imap_capabilities.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/email/models/fan_out_recipient_status.dart';
import 'package:axichat/src/email/models/fan_out_send_report.dart';
import 'package:axichat/src/email/models/share_context.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/email/service/email_blocking_service.dart';
import 'package:axichat/src/email/service/email_spam_service.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/email/transport/email_delta_transport.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/email/util/async_queue.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/email/util/delta_message_ids.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/email/util/email_header_safety.dart';
import 'package:axichat/src/email/util/share_token_html.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/notifications/notification_payload.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/connection/foreground_socket.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';

enum _EmailSyncSource {
  unknown,
  coreError,
  selfNotInGroup,
  connectivityConfirm,
  connectivityApply,
  connectivityChangedEvent,
  backgroundFetchDone,
  networkAvailable,
  reconnectRestart,
  channelOverflow,
  channelOverflowFailure,
  channelOverflowComplete,
  bootstrapStart,
  bootstrapRetry,
  bootstrapComplete,
  reconnectCatchUp,
  passwordRefreshPending,
}

extension _EmailSyncSourceLabels on _EmailSyncSource {
  String get logLabel => name;
}

enum _EmailRuntimePhase { stopped, running, stopping, disposing }

enum EmailPasswordRefreshResult {
  confirmed,
  reconnectPending;

  bool get isConfirmed => this == confirmed;
}

final class EmailConnectionConfigBuilder {
  const EmailConnectionConfigBuilder(this._builder);

  final Map<String, String> Function(String address, EndpointConfig config)
  _builder;

  Map<String, String> call(String address, EndpointConfig config) =>
      _builder(address, config);
}

final class _EmailAccountBinding {
  const _EmailAccountBinding({
    required this.address,
    required this.deltaAccountId,
  });

  final String address;
  final int deltaAccountId;

  String senderIdentity(EmailDeltaTransport transport) =>
      transport.selfJidForAccount(deltaAccountId) ?? address;
}

final class _EmailChatBinding {
  const _EmailChatBinding({
    required this.chat,
    required this.deltaChatId,
    required this.account,
  });

  final Chat chat;
  final int deltaChatId;
  final _EmailAccountBinding account;

  int get deltaAccountId => account.deltaAccountId;

  String get accountAddress => account.address;

  String senderIdentity(EmailDeltaTransport transport) =>
      account.senderIdentity(transport);
}

sealed class EmailProvisioningException implements Exception {
  const EmailProvisioningException({
    this.isRecoverable = false,
    this.shouldWipeCredentials = false,
  });

  final bool isRecoverable;
  final bool shouldWipeCredentials;

  @override
  String toString() => runtimeType.toString();
}

final class EmailProvisioningMissingAddressException
    extends EmailProvisioningException {
  const EmailProvisioningMissingAddressException();
}

final class EmailProvisioningMissingPasswordException
    extends EmailProvisioningException {
  const EmailProvisioningMissingPasswordException();
}

final class EmailProvisioningAccountUnavailableException
    extends EmailProvisioningException {
  const EmailProvisioningAccountUnavailableException();
}

final class EmailProvisioningTimeoutException
    extends EmailProvisioningException {
  const EmailProvisioningTimeoutException() : super(isRecoverable: true);
}

final class EmailProvisioningNetworkUnavailableException
    extends EmailProvisioningException {
  const EmailProvisioningNetworkUnavailableException()
    : super(isRecoverable: true);
}

final class EmailProvisioningAuthenticationFailedException
    extends EmailProvisioningException {
  const EmailProvisioningAuthenticationFailedException()
    : super(shouldWipeCredentials: true);
}

final class EmailProvisioningConfigurationException
    extends EmailProvisioningException {
  const EmailProvisioningConfigurationException();
}

sealed class EmailServiceException implements Exception {
  const EmailServiceException();

  @override
  String toString() => runtimeType.toString();
}

final class EmailServiceMissingAddressException extends EmailServiceException {
  const EmailServiceMissingAddressException();
}

final class EmailServiceStoppingException extends EmailServiceException {
  const EmailServiceStoppingException();
}

final class EmailServiceChatPersistTimeoutException
    extends EmailServiceException {
  const EmailServiceChatPersistTimeoutException();
}

final class EmailServiceMissingRecipientMetadataException
    extends EmailServiceException {
  const EmailServiceMissingRecipientMetadataException();
}

sealed class FanOutValidationException implements Exception {
  const FanOutValidationException();

  int? get maxRecipients => null;

  String message(AppLocalizations l10n) => switch (this) {
    FanOutNoRecipientsException() => l10n.fanOutErrorNoRecipients,
    FanOutResolveFailedException() => l10n.fanOutErrorResolveFailed,
    FanOutTooManyRecipientsException(:final maxRecipients) =>
      l10n.fanOutErrorTooManyRecipients(maxRecipients),
    FanOutEmptyMessageException() => l10n.fanOutErrorEmptyMessage,
    FanOutInvalidShareTokenException() => l10n.fanOutErrorInvalidShareToken,
  };

  @override
  String toString() => runtimeType.toString();
}

final class FanOutNoRecipientsException extends FanOutValidationException {
  const FanOutNoRecipientsException();
}

final class FanOutResolveFailedException extends FanOutValidationException {
  const FanOutResolveFailedException();
}

final class FanOutTooManyRecipientsException extends FanOutValidationException {
  const FanOutTooManyRecipientsException(this._maxRecipients);

  final int _maxRecipients;

  @override
  int get maxRecipients => _maxRecipients;
}

final class FanOutEmptyMessageException extends FanOutValidationException {
  const FanOutEmptyMessageException();
}

final class FanOutInvalidShareTokenException extends FanOutValidationException {
  const FanOutInvalidShareTokenException();
}

class EmailService {
  static const int _defaultPageSize = 50;
  static const int _maxFanOutRecipients = 20;
  static const int _fanOutConcurrentOps = 4;
  static const int _contactHydrationConcurrentOps = 6;
  static const int _attachmentFanOutWarningBytes = 8 * 1024 * 1024;
  static const int _deltaMessageIdUnset = DeltaMessageId.none;
  static const int _emptyUnreadCount = 0;
  static const Duration _foregroundKeepaliveInterval = Duration(seconds: 45);
  static const Duration _foregroundFetchTimeout = Duration(seconds: 8);
  static const Duration _notificationFlushDelay = Duration(milliseconds: 500);
  static const Duration _contactsSyncDebounce = Duration(seconds: 2);
  static const int _connectivityConnectedMin = 4000;
  static const int _connectivityWorkingMin = 3000;
  static const int _connectivityConnectingMin = 2000;
  static const int _connectivityLogIntervalSeconds = 5;
  static const Duration _connectivityLogInterval = Duration(
    seconds: _connectivityLogIntervalSeconds,
  );
  static const String _emailConnectivityLogPrefix = 'Email connectivity';
  static const String _emailSyncLogPrefix = 'Email sync state';
  static const String _emailLogSourceLabel = 'source';
  static const String _emailLogValueLabel = 'value';
  static const String _emailLogStateLabel = 'state';
  static const String _emailLogConnectivityLabel = 'connectivity';
  static const String _emailLogHasMessageLabel = 'hasMessage';
  static const String _emailLogUnknownValue = 'unknown';
  static const String _shareTokenInvalidLog =
      'Rejected invalid share identifier for subject token.';
  static const int _connectivityDowngradeGraceSeconds = 2;
  static const Duration _connectivityDowngradeGrace = Duration(
    seconds: _connectivityDowngradeGraceSeconds,
  );
  static const int _coreDraftMessageId = 0;
  static const int _deltaEventMessageUnset = 0;
  static const String _securityModeSsl = 'ssl';
  static const String _securityModeStartTls = 'starttls';
  static const String _emailAddressSeparator = '@';
  static const int _emailAddressSeparatorMissingIndex = -1;
  static const int _emailLocalPartStartIndex = 0;
  static const int _emailLocalPartMinLength = 1;
  static const String _unknownEmailPassword = '';
  static const String _emailBootstrapKeyPrefix = 'email_bootstrap_v1';
  static const String _connectionOverrideKeyPrefix =
      'email_connection_overrides_v1';
  static const String _credentialTrueValue = 'true';
  static const String _credentialFalseValue = 'false';
  static const String _connectionOverrideClearedValue = '';
  static const String _showEmailsConfigKey = 'show_emails';
  static const String _showEmailsAllValue = '2';
  static const String _systemConfigKeysConfigKey = 'sys.config_keys';
  static const String _fetchExistingMsgsConfigKey = 'fetch_existing_msgs';
  static const String _fetchExistingMsgsEnabledValue = '1';
  static const String _emailProvisioningBuildMarker =
      'email-prov-20260309-1329';
  static const String _mdnsEnabledConfigKey = 'mdns_enabled';
  static const String _mdnsEnabledValue = '1';
  static const String _mdnsDisabledValue = '0';
  static const String _mailServerConfigKey = 'mail_server';
  static const String _mailPortConfigKey = 'mail_port';
  static const String _mailSecurityConfigKey = 'mail_security';
  static const String _mailUserConfigKey = 'mail_user';
  static const String _sendServerConfigKey = 'send_server';
  static const String _sendPortConfigKey = 'send_port';
  static const String _sendSecurityConfigKey = 'send_security';
  static const String _sendUserConfigKey = 'send_user';
  static const String _sendPasswordConfigKey = 'send_pw';
  static const int _portUnsetValue = 0;
  static const List<String> _connectionOverrideConfigKeys = <String>[
    _mailServerConfigKey,
    _mailPortConfigKey,
    _mailSecurityConfigKey,
    _mailUserConfigKey,
    _sendServerConfigKey,
    _sendPortConfigKey,
    _sendSecurityConfigKey,
    _sendUserConfigKey,
  ];
  static const List<EmailAttachment> _emptyEmailAttachments =
      <EmailAttachment>[];
  static const String _deltaContactIdPrefix = 'delta_contact_';
  static const int _deltaContactListFlags =
      DeltaContactListFlags.addSelf | DeltaContactListFlags.address;
  static const String _imapIdleConfigKey = 'imap_idle';
  static const String _imapIdleTimeoutConfigKey = 'imap_idle_timeout';
  static const String _imapMaxConnectionsConfigKey = 'imap_max_connections';
  static const Duration _imapIdleKeepaliveInterval = Duration(minutes: 25);
  static const Duration _imapSentPollIntervalSingleConnection = Duration(
    seconds: 60,
  );
  static const Duration _imapPollIntervalNoIdle = Duration(seconds: 30);
  static const Duration _imapSyncFetchTimeout = Duration(seconds: 25);
  static const Duration _imapCapabilityRefreshInterval = Duration(minutes: 10);
  static const Duration _reconnectRestartDelay = Duration(seconds: 2);
  static const int _imapConnectionLimitSingle = 1;
  static const int _imapConnectionLimitMulti = 2;
  static const Set<String> _imapConfigBoolTrueValues = {
    '1',
    'true',
    'yes',
    'on',
  };
  static const Set<String> _imapConfigBoolFalseValues = {
    '0',
    'false',
    'no',
    'off',
  };
  static const int _minimumHistoryWindow = 1;
  static const bool _includePseudoMessagesInBackfill = false;
  static const NotificationPayloadCodec _notificationPayloadCodec =
      NotificationPayloadCodec();

  static const String _deltaQueueOperationNameProcessDeltaEvent =
      'EmailService.processDeltaEvent';
  static const String _deltaQueueOperationNameFlushQueuedNotifications =
      'EmailService.flushQueuedNotifications';
  static const String _deltaQueueOperationNameSyncContactsFromCore =
      'EmailService.syncContactsFromCore';

  EmailService({
    required CredentialStore credentialStore,
    required Future<XmppDatabase> Function() databaseBuilder,
    EmailDeltaTransport? transport,
    EmailConnectionConfigBuilder? connectionConfigBuilder,
    NotificationService? notificationService,
    MessageService? messageService,
    Logger? logger,
    ForegroundTaskBridge? foregroundBridge,
    EndpointConfig endpointConfig = const EndpointConfig(),
    bool emailReadReceiptsEnabled = false,
  }) : _credentialStore = credentialStore,
       _databaseBuilder = databaseBuilder,
       _endpointConfig = endpointConfig,
       _emailReadReceiptsEnabled = emailReadReceiptsEnabled,
       _connectionConfigBuilder =
           connectionConfigBuilder ??
           const EmailConnectionConfigBuilder(_defaultConnectionConfig),
       _log = logger ?? Logger('EmailService'),
       _notificationService = notificationService,
       _messageService = messageService,
       _foregroundBridge = foregroundBridge ?? foregroundTaskBridge {
    _transport =
        transport ??
        EmailDeltaTransport(
          databaseBuilder: databaseBuilder,
          logger: logger,
          localizationsProvider: () => _l10n,
        );
    blocking = EmailBlockingService(
      databaseBuilder: databaseBuilder,
      onBlock: DeltaChatBlockCallback(_transport.blockContact),
      onUnblock: DeltaChatBlockCallback(_transport.unblockContact),
    );
    spam = EmailSpamService(
      databaseBuilder: databaseBuilder,
      onMarkSpam: DeltaChatSpamCallback(_transport.blockContact),
      onUnmarkSpam: DeltaChatSpamCallback(_transport.unblockContact),
    );
    _eventListener = (event) {
      if (!_canProcessDeltaWork) {
        return;
      }
      _enqueueDeltaOperation(
        () => _processDeltaEvent(event),
        operationName: _deltaQueueOperationNameProcessDeltaEvent,
      );
    };
    _transport.addEventListener(_eventListener);
    _listenerAttached = true;
  }

  final CredentialStore _credentialStore;
  final Future<XmppDatabase> Function() _databaseBuilder;
  late final EmailDeltaTransport _transport;
  final EmailConnectionConfigBuilder _connectionConfigBuilder;
  final Logger _log;
  EndpointConfig _endpointConfig;
  bool _emailReadReceiptsEnabled;
  final NotificationService? _notificationService;
  final MessageService? _messageService;
  final ForegroundTaskBridge? _foregroundBridge;
  AppLocalizations? _localizations;
  final _EmailCredentialRuntimeSession _credentialSession =
      _EmailCredentialRuntimeSession();
  final _EmailNotificationQueueSession _notificationQueue =
      _EmailNotificationQueueSession();

  AppLocalizations get _l10n =>
      _localizations ?? lookupAppLocalizations(const Locale('en'));

  void updateLocalizations(AppLocalizations localizations) {
    _localizations = localizations;
  }

  late final EmailBlockingService blocking;
  late final EmailSpamService spam;
  late final void Function(DeltaCoreEvent) _eventListener;
  var _listenerAttached = false;

  Future<void> _deltaOperationQueue = Future<void>.value();
  int _deltaOperationQueueEpoch = 0;

  _EmailRuntimePhase _runtimePhase = _EmailRuntimePhase.stopped;
  Future<void>? _stopFuture;
  final _authFailureController = StreamController<DeltaChatException>.broadcast(
    sync: true,
  );
  bool _foregroundKeepaliveEnabled = false;
  bool _foregroundKeepaliveListenerAttached = false;
  bool _foregroundKeepaliveServiceAcquired = false;
  final EmailAsyncQueue _foregroundKeepaliveQueue = EmailAsyncQueue();
  int _foregroundKeepaliveOperationId = 0;
  final EmailAsyncQueue _reconnectRestartQueue = EmailAsyncQueue();
  Timer? _contactsSyncTimer;
  String? _pendingPushToken;
  final _syncStateController = StreamController<EmailSyncState>.broadcast(
    sync: true,
  );
  final _readyTransitionController = StreamController<void>.broadcast(
    sync: true,
  );
  EmailSyncState _syncState = const EmailSyncState.ready();
  Timer? _connectivityDowngradeTimer;
  int? _pendingConnectivityLevel;
  int? _lastConnectivityValue;
  int? _lastLoggedConnectivityValue;
  DateTime? _lastConnectivityLoggedAt;
  final EmailAsyncQueue _channelOverflowRecoveryQueue = EmailAsyncQueue();
  EmailImapCapabilities _imapCapabilities = const EmailImapCapabilities(
    idleSupported: false,
    connectionLimit: _imapConnectionLimitSingle,
    idleCutoff: _imapIdleKeepaliveInterval,
  );
  DateTime? _imapCapabilitiesCheckedAt;
  bool _imapCapabilitiesResolved = false;
  Timer? _imapSyncTimer;
  Object? _imapSyncLoopToken;
  final EmailAsyncQueue _imapSyncQueue = EmailAsyncQueue();
  final EmailAsyncQueue _reconnectCatchUpQueue = EmailAsyncQueue();
  final EmailAsyncQueue _contactsSyncQueue = EmailAsyncQueue();
  final EmailAsyncQueue _chatlistSyncQueue = EmailAsyncQueue();

  void updateEndpointConfig(EndpointConfig config) {
    _endpointConfig = config;
  }

  Future<void> updateEmailReadReceiptsEnabled(bool enabled) async {
    if (_emailReadReceiptsEnabled == enabled) {
      return;
    }
    _emailReadReceiptsEnabled = enabled;
    await _applyEmailReadReceiptPreference(enabled: enabled);
  }

  void updateDefaultChatAttachmentAutoDownload(AttachmentAutoDownload value) {
    _transport.updateDefaultChatAttachmentAutoDownload(value);
  }

  void cacheSessionCredentials({
    required String address,
    required String? password,
  }) => _credentialSession.cacheSessionCredentials(
    address: address,
    password: password,
  );

  void clearSessionCredentials() =>
      _credentialSession.clearSessionCredentials();

  Map<String, String> _buildConnectionConfig(String address) =>
      _connectionConfigBuilder(address, _endpointConfig);

  Map<String, String> _buildConfigureAccountOverrides({
    required String address,
    required String password,
    bool fetchExistingMessages = false,
  }) {
    final overrides = Map<String, String>.of(_buildConnectionConfig(address));
    overrides[_sendPasswordConfigKey] = password;
    overrides[_mdnsEnabledConfigKey] = _mdnsConfigValue(
      _emailReadReceiptsEnabled,
    );
    if (fetchExistingMessages) {
      overrides[_fetchExistingMsgsConfigKey] = _fetchExistingMsgsEnabledValue;
    }
    return overrides;
  }

  bool _coreAdvertisesConfigKey(String? advertisedConfigKeys, String key) {
    if (advertisedConfigKeys == null || advertisedConfigKeys.trim().isEmpty) {
      return false;
    }
    return advertisedConfigKeys
        .split(RegExp(r'\s+'))
        .where((candidate) => candidate.isNotEmpty)
        .contains(key);
  }

  bool _hasConnectionOverrides(Map<String, String> connectionOverrides) =>
      _connectionOverrideConfigKeys.any(connectionOverrides.containsKey);

  bool _isConfigureTimeout(DeltaSafeException error) =>
      error.message.toLowerCase().contains('timed out');

  Future<bool> _isConnectionOverrideApplied({
    required String scope,
    required bool persistCredentials,
  }) async {
    if (_credentialSession.hasEphemeralConnectionOverride(scope)) {
      return true;
    }
    if (!persistCredentials) {
      return false;
    }
    final stored = await _credentialStore.read(
      key: _connectionOverrideKeyForScope(scope),
    );
    return stored == _credentialTrueValue;
  }

  Future<void> _markConnectionOverridesApplied({
    required String scope,
    required bool persistCredentials,
    required Map<String, String> connectionOverrides,
  }) async {
    if (!_hasConnectionOverrides(connectionOverrides)) {
      return;
    }
    _credentialSession.markEphemeralConnectionOverride(scope);
    if (!persistCredentials) {
      return;
    }
    await _credentialStore.write(
      key: _connectionOverrideKeyForScope(scope),
      value: _credentialTrueValue,
    );
  }

  Future<bool> _shouldReconfigureTransport({
    required String scope,
    required Map<String, String> connectionOverrides,
    required bool persistCredentials,
  }) async {
    if (!_hasConnectionOverrides(connectionOverrides)) {
      return false;
    }
    final overridesApplied = await _isConnectionOverrideApplied(
      scope: scope,
      persistCredentials: persistCredentials,
    );
    if (!overridesApplied) {
      return true;
    }
    try {
      for (final key in _connectionOverrideConfigKeys) {
        final expectedValue = connectionOverrides[key];
        final currentValue = await _transport.getCoreConfig(key);
        final normalizedExpected = _normalizeConnectionConfigValue(
          key: key,
          value: expectedValue,
        );
        final normalizedCurrent = _normalizeConnectionConfigValue(
          key: key,
          value: currentValue,
        );
        if (normalizedExpected == null) {
          if (normalizedCurrent != null) {
            return true;
          }
          continue;
        }
        if (normalizedExpected != normalizedCurrent) {
          return true;
        }
      }
    } on Exception {
      _log.finer(
        'Failed to read email transport overrides for reconfiguration check.',
      );
      return true;
    }
    return false;
  }

  Future<void> _applyConnectionOverridesWithoutPassword({
    required Map<String, String> connectionOverrides,
  }) async {
    if (!_hasConnectionOverrides(connectionOverrides)) {
      return;
    }
    for (final key in _connectionOverrideConfigKeys) {
      final normalizedValue = _normalizeConnectionConfigValue(
        key: key,
        value: connectionOverrides[key],
      );
      await _transport.setCoreConfig(
        key: key,
        value: normalizedValue ?? _connectionOverrideClearedValue,
      );
    }
  }

  String? _normalizeConnectionConfigValue({
    required String key,
    required String? value,
  }) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (_isPortConfigKey(key)) {
      final parsed = int.tryParse(trimmed);
      if (parsed == null || parsed <= _portUnsetValue) {
        return null;
      }
      return parsed.toString();
    }
    return trimmed.toLowerCase();
  }

  bool _isPortConfigKey(String key) =>
      key == _mailPortConfigKey || key == _sendPortConfigKey;

  EmailAccount? get activeAccount => _credentialSession.activeAccount;

  EmailAccount? get sessionCredentials => _credentialSession.sessionCredentials;

  bool get isSmtpOnly =>
      _endpointConfig.smtpEnabled && !_endpointConfig.xmppEnabled;

  bool get _acceptsRuntimeWork => _runtimePhase == _EmailRuntimePhase.running;

  bool get _blocksRuntimeReentry =>
      _runtimePhase == _EmailRuntimePhase.stopping ||
      _runtimePhase == _EmailRuntimePhase.disposing;

  bool get _canProcessDeltaWork => _listenerAttached && !_blocksRuntimeReentry;

  bool get isRunning => _acceptsRuntimeWork;

  bool get hasActiveSession => _credentialSession.hasActiveSession;

  bool get hasInMemoryReconnectContext =>
      _credentialSession.hasInMemoryReconnectContext;

  Stream<DeltaCoreEvent> get events => _transport.events;

  EmailSyncState get syncState => _syncState;

  Stream<EmailSyncState> get syncStateStream => _syncStateController.stream;

  Stream<void> get readyTransitionStream => _readyTransitionController.stream;

  Stream<DeltaChatException> get authFailureStream =>
      _authFailureController.stream;

  String? get _databasePrefix => _credentialSession.databasePrefix;

  String? get _databasePassphrase => _credentialSession.databasePassphrase;

  EmailAccount? get _activeAccount => _credentialSession.activeAccount;

  set _activeAccount(EmailAccount? value) {
    _credentialSession.activeAccount = value;
  }

  String? get _activeCredentialScope =>
      _credentialSession.activeCredentialScope;

  set _activeCredentialScope(String? value) {
    _credentialSession.activeCredentialScope = value;
  }

  Future<void>? _bootstrapFutureForScope(String scope) =>
      _credentialSession.scopeState(scope).bootstrapFuture;

  void _setBootstrapFutureForScope(String scope, Future<void>? value) {
    _credentialSession.scopeState(scope).bootstrapFuture = value;
  }

  int _bootstrapOperationIdForScope(String scope) =>
      _credentialSession.scopeState(scope).bootstrapOperationId;

  int _nextBootstrapOperationIdForScope(String scope) {
    final scopeState = _credentialSession.scopeState(scope);
    scopeState.bootstrapOperationId += 1;
    return scopeState.bootstrapOperationId;
  }

  Future<bool> canReconnectConfiguredSession({String? jid}) async {
    if (!hasActiveSession) {
      return false;
    }
    final scope = _scopeForOptionalJid(jid);
    if (scope == null) {
      return false;
    }
    final EmailAccount? account = _activeCredentialScope == scope
        ? _activeAccount
        : null;
    if (account == null) {
      final storedAccount = await _accountForScope(scope);
      if (storedAccount == null) {
        return false;
      }
    }
    try {
      return await _transport.isConfigured();
    } on Exception {
      return false;
    }
  }

  Future<EmailAccount?> currentAccount(String jid) async {
    final scope = _scopeForJid(jid);
    final address = await _credentialStore.read(
      key: _addressKeyForScope(scope),
    );
    final password = await _credentialStore.read(
      key: _passwordKeyForScope(scope),
    );
    if (address == null ||
        address.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return EmailAccount(address: address, password: password);
  }

  Future<EmailAccount?> _accountForScope(String scope) async {
    final String? address = await _credentialStore.read(
      key: _addressKeyForScope(scope),
    );
    final String? password = await _credentialStore.read(
      key: _passwordKeyForScope(scope),
    );
    if (address == null ||
        address.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return EmailAccount(address: address, password: password);
  }

  Future<EmailAccount> ensureProvisioned({
    required String displayName,
    required String databasePrefix,
    required String databasePassphrase,
    required String jid,
    String? passwordOverride,
    String? addressOverride,
    bool persistCredentials = true,
  }) async {
    _log.warning(
      'Email provisioning marker $_emailProvisioningBuildMarker '
      'entered ensureProvisioned for $jid',
    );
    final scope = _scopeForJid(jid);
    final needsInit =
        _databasePrefix != databasePrefix ||
        _databasePassphrase != databasePassphrase;
    if (needsInit) {
      _credentialSession.bindDatabaseRuntime(
        databasePrefix: databasePrefix,
        databasePassphrase: databasePassphrase,
      );
      _resetImapCapabilities();
      await _transport.ensureInitialized(
        databasePrefix: databasePrefix,
        databasePassphrase: databasePassphrase,
      );
      if (!_listenerAttached) {
        _transport.addEventListener(_eventListener);
        _listenerAttached = true;
      }
    }

    if (!_listenerAttached) {
      _transport.addEventListener(_eventListener);
      _listenerAttached = true;
    }

    _activeCredentialScope = scope;

    final addressKey = _addressKeyForScope(scope);
    final passwordKey = _passwordKeyForScope(scope);
    final provisionedKey = _provisionedKeyForScope(scope);

    var address = await _credentialStore.read(key: addressKey);
    var password = await _credentialStore.read(key: passwordKey);
    final normalizedOverrideAddress = normalizedAddressValue(addressOverride);
    final preferredAddress = _preferredAddressFromJid(jid);
    var credentialsMutated = false;
    final shouldPersistCredentials = persistCredentials;

    final selectedAddress =
        (normalizedOverrideAddress != null &&
            normalizedOverrideAddress.isNotEmpty)
        ? normalizedOverrideAddress
        : ((address != null && address.isNotEmpty)
              ? address
              : preferredAddress);
    if (selectedAddress == null || selectedAddress.isEmpty) {
      throw const EmailProvisioningMissingAddressException();
    }
    if (address == null || address != selectedAddress) {
      address = selectedAddress;
      credentialsMutated = true;
      if (shouldPersistCredentials) {
        await _credentialStore.write(key: addressKey, value: address);
      }
    }

    final connectionOverrides = _buildConnectionConfig(selectedAddress);

    if (passwordOverride != null &&
        passwordOverride.isNotEmpty &&
        (password == null || password != passwordOverride)) {
      password = passwordOverride;
      credentialsMutated = true;
      if (shouldPersistCredentials) {
        await _credentialStore.write(key: passwordKey, value: password);
      }
    }

    final deltaAccountId = await _ensureEmailAccountSession(
      createIfMissing: true,
    );
    var alreadyProvisioned =
        (await _credentialStore.read(key: provisionedKey)) ==
        _credentialTrueValue;
    if (!shouldPersistCredentials &&
        _credentialSession.isEphemerallyProvisioned(scope)) {
      alreadyProvisioned = true;
    }
    var transportConfigured = false;
    final shouldForceProvisioning =
        shouldPersistCredentials && credentialsMutated;
    if (shouldForceProvisioning) {
      alreadyProvisioned = false;
      _credentialSession.clearEphemeralProvisioning(scope);
      if (shouldPersistCredentials) {
        await _credentialStore.write(
          key: provisionedKey,
          value: _credentialFalseValue,
        );
      }
    }
    // Always verify with transport - credential store may be stale after cold start
    if (!shouldForceProvisioning) {
      try {
        transportConfigured = await _transport.isConfigured(
          accountId: deltaAccountId,
        );
        alreadyProvisioned = transportConfigured;
      } on Exception {
        alreadyProvisioned = false;
      }
    }
    var requiresReconfigure = false;
    if (alreadyProvisioned) {
      requiresReconfigure = await _shouldReconfigureTransport(
        scope: scope,
        connectionOverrides: connectionOverrides,
        persistCredentials: shouldPersistCredentials,
      );
      if (requiresReconfigure) {
        alreadyProvisioned = false;
        _credentialSession.clearEphemeralProvisioning(scope);
        if (shouldPersistCredentials) {
          await _credentialStore.write(
            key: provisionedKey,
            value: _credentialFalseValue,
          );
        }
      }
    }

    final hasPassword = password != null && password.isNotEmpty;
    if (!alreadyProvisioned &&
        !hasPassword &&
        requiresReconfigure &&
        transportConfigured) {
      await _applyConnectionOverridesWithoutPassword(
        connectionOverrides: connectionOverrides,
      );
      await _markConnectionOverridesApplied(
        scope: scope,
        persistCredentials: shouldPersistCredentials,
        connectionOverrides: connectionOverrides,
      );
      if (shouldPersistCredentials) {
        await _credentialStore.write(
          key: provisionedKey,
          value: _credentialTrueValue,
        );
      }
      alreadyProvisioned = true;
      requiresReconfigure = false;
    }

    final needsProvisioning = !alreadyProvisioned;
    String? supportedConfigKeys;
    try {
      supportedConfigKeys = await _transport.getCoreConfig(
        _systemConfigKeysConfigKey,
        accountId: deltaAccountId,
      );
    } on Exception catch (error, stackTrace) {
      _log.fine(
        'Failed to read Delta advertised config keys during provisioning.',
        error,
        stackTrace,
      );
    }
    _log.warning(
      'Email provisioning decision: '
      'accountId=$deltaAccountId '
      'transportConfigured=$transportConfigured '
      'requiresReconfigure=$requiresReconfigure '
      'needsProvisioning=$needsProvisioning '
      'advertisedConfigKeys=${supportedConfigKeys ?? '<unavailable>'}',
    );
    final pausedForProvisioning = needsProvisioning && _acceptsRuntimeWork;
    if (pausedForProvisioning) {
      await stop();
    }

    if (needsProvisioning && !hasPassword) {
      throw const EmailProvisioningMissingPasswordException();
    }

    if (needsProvisioning) {
      final provisioningPassword = password!;
      _log.info('Configuring email account credentials');
      try {
        final configureOverrides = _buildConfigureAccountOverrides(
          address: address,
          password: provisioningPassword,
          fetchExistingMessages: _coreAdvertisesConfigKey(
            supportedConfigKeys,
            _fetchExistingMsgsConfigKey,
          ),
        );
        await _transport.configureAccount(
          address: address,
          password: provisioningPassword,
          displayName: displayName,
          additional: configureOverrides,
          accountId: deltaAccountId,
        );
        _resetImapCapabilities();
        await _markConnectionOverridesApplied(
          scope: scope,
          persistCredentials: shouldPersistCredentials,
          connectionOverrides: connectionOverrides,
        );
        if (shouldPersistCredentials) {
          await _credentialStore.write(
            key: provisionedKey,
            value: _credentialTrueValue,
          );
        } else {
          _credentialSession.markEphemerallyProvisioned(scope);
        }
      } on DeltaSafeException catch (error, stackTrace) {
        if (shouldPersistCredentials) {
          await _credentialStore.write(
            key: provisionedKey,
            value: _credentialFalseValue,
          );
        } else {
          _credentialSession.clearEphemeralProvisioning(scope);
        }
        final isTimeout = error.message.toLowerCase().contains('timed out');
        final mapped = DeltaChatExceptionMapper.fromDeltaSafe(
          error,
          operation: 'configure email account',
        );
        final errorType = error.runtimeType;
        _log.warning(
          'Failed to configure email account ($errorType): ${error.message}',
          null,
          stackTrace,
        );
        final shouldClearCredentials =
            credentialsMutated && mapped.code == DeltaChatErrorCode.auth;
        if (shouldClearCredentials) {
          await _clearCredentials(scope);
        }
        if (isTimeout) {
          throw const EmailProvisioningTimeoutException();
        }
        if (mapped.code == DeltaChatErrorCode.network ||
            mapped.code == DeltaChatErrorCode.server) {
          throw const EmailProvisioningNetworkUnavailableException();
        }
        final isAuthFailure =
            mapped.code == DeltaChatErrorCode.permission ||
            mapped.code == DeltaChatErrorCode.auth;
        throw isAuthFailure
            ? const EmailProvisioningAuthenticationFailedException()
            : const EmailProvisioningConfigurationException();
      }
    } else {
      _log.fine(
        'Reusing existing email account credentials without reconfiguration.',
      );
    }

    await _hydrateAccountAddress(
      address: address,
      deltaAccountId: deltaAccountId,
    );
    await start();
    _log.warning(
      'Email provisioning marker $_emailProvisioningBuildMarker '
      'before IMAP capability refresh for $jid',
    );
    await _refreshImapCapabilities(force: true);
    await _applyPendingPushToken();

    final account = EmailAccount(
      address: address,
      password: password ?? _unknownEmailPassword,
    );
    _activeAccount = account;
    _credentialSession.markEphemerallyProvisioned(scope);
    await _bootstrapFromCoreIfNeeded(
      scope: scope,
      databasePrefix: databasePrefix,
    );
    return account;
  }

  Future<int> _ensureEmailAccountSession({
    required bool createIfMissing,
  }) async {
    final existingAccountIds = await _transport.accountIds();
    if (existingAccountIds.isNotEmpty) {
      final preferredAccountId = _transport.activeAccountId;
      final deltaAccountId = existingAccountIds.contains(preferredAccountId)
          ? preferredAccountId
          : existingAccountIds.first;
      await _transport.ensureAccountSession(deltaAccountId);
      _transport.setPrimaryAccountId(deltaAccountId);
      return deltaAccountId;
    }

    if (_transport.accountsActive) {
      if (!createIfMissing) {
        throw const EmailProvisioningAccountUnavailableException();
      }
      final deltaAccountId = await _transport.createAccount();
      await _transport.ensureAccountSession(deltaAccountId);
      _transport.setPrimaryAccountId(deltaAccountId);
      return deltaAccountId;
    }

    const deltaAccountId = DeltaAccountDefaults.legacyId;
    await _transport.ensureAccountSession(deltaAccountId);
    _transport.setPrimaryAccountId(deltaAccountId);
    return deltaAccountId;
  }

  Future<EmailPasswordRefreshResult> updatePassword({
    required String jid,
    required String displayName,
    required String password,
    bool persistCredentials = true,
  }) async {
    await _ensureReady();
    final hadForegroundKeepalive = _foregroundKeepaliveEnabled;
    if (hadForegroundKeepalive) {
      await _stopForegroundKeepalive();
    }
    final scope = _scopeForJid(jid);
    final address = await _credentialStore.read(
      key: _addressKeyForScope(scope),
    );
    if (address == null || address.isEmpty) {
      throw const EmailServiceMissingAddressException();
    }
    final deltaAccountId = await _ensureEmailAccountSession(
      createIfMissing: false,
    );
    if (persistCredentials) {
      await _credentialStore.write(
        key: _passwordKeyForScope(scope),
        value: password,
      );
    }
    final connectionOverrides = _buildConnectionConfig(address);
    final configureOverrides = _buildConfigureAccountOverrides(
      address: address,
      password: password,
    );
    var refreshResult = EmailPasswordRefreshResult.confirmed;
    await stop();
    try {
      try {
        await _transport.configureAccount(
          address: address,
          password: password,
          displayName: displayName,
          additional: configureOverrides,
          accountId: deltaAccountId,
        );
      } on DeltaSafeException catch (error, stackTrace) {
        if (!_isConfigureTimeout(error)) {
          rethrow;
        }
        refreshResult = EmailPasswordRefreshResult.reconnectPending;
        _updateSyncState(
          EmailSyncState.recovering(_l10n.emailSyncMessageSyncing),
          source: _EmailSyncSource.passwordRefreshPending,
        );
        _log.warning(
          'Timed out refreshing live email credentials after password change; '
          'email reconnect remains pending.',
          error,
          stackTrace,
        );
      }
    } finally {
      await start();
      if (hadForegroundKeepalive) {
        await setForegroundKeepalive(true);
      }
    }
    if (persistCredentials && refreshResult.isConfirmed) {
      await _credentialStore.write(
        key: _provisionedKeyForScope(scope),
        value: _credentialTrueValue,
      );
    }
    if (refreshResult.isConfirmed) {
      _resetImapCapabilities();
      await _refreshImapCapabilities(force: true);
    }
    await _hydrateAccountAddress(
      address: address,
      deltaAccountId: deltaAccountId,
    );
    _credentialSession.activateAccount(
      scope: scope,
      account: EmailAccount(address: address, password: password),
    );
    await _markConnectionOverridesApplied(
      scope: scope,
      persistCredentials: persistCredentials,
      connectionOverrides: connectionOverrides,
    );
    return refreshResult;
  }

  Future<void> start() async {
    if (_acceptsRuntimeWork) {
      return;
    }
    if (_blocksRuntimeReentry) {
      throw const EmailServiceStoppingException();
    }
    if (!_listenerAttached) {
      _transport.addEventListener(_eventListener);
      _listenerAttached = true;
    }
    await _transport.start();
    await _applyEmailReadReceiptPreference();
    _runtimePhase = _EmailRuntimePhase.running;
    _startImapSyncLoop();
  }

  Future<void> stop() async {
    final existing = _stopFuture;
    if (existing != null) {
      await existing;
      return;
    }
    if (!_acceptsRuntimeWork && !_listenerAttached) {
      return;
    }
    final future = _runStop();
    _stopFuture = future;
    try {
      await future;
    } finally {
      if (identical(_stopFuture, future)) {
        _stopFuture = null;
      }
    }
  }

  Future<void> _runStop() async {
    if (_runtimePhase != _EmailRuntimePhase.disposing) {
      _runtimePhase = _EmailRuntimePhase.stopping;
    }
    _detachTransportListener();
    await _stopForegroundKeepalive();
    _stopImapSyncLoop();
    _cancelContactsSyncTimer();
    _cancelConnectivityDowngrade();
    _clearNotificationQueue();
    _contactsSyncQueue.reset();
    _chatlistSyncQueue.reset();
    _imapSyncQueue.reset();
    _reconnectCatchUpQueue.reset();
    _reconnectRestartQueue.reset();
    _channelOverflowRecoveryQueue.reset();
    _credentialSession.invalidateBootstrapOperations();
    await _deltaOperationQueue;
    _resetDeltaOperationQueue();
    await _transport.stop();
    if (_runtimePhase == _EmailRuntimePhase.stopping) {
      _runtimePhase = _EmailRuntimePhase.stopped;
    }
  }

  Future<void> ensureEventChannelActive() async {
    if (_blocksRuntimeReentry) {
      return;
    }
    if (!_listenerAttached) {
      _transport.addEventListener(_eventListener);
      _listenerAttached = true;
    }
    final isInitialized =
        _databasePrefix != null && _databasePassphrase != null;
    if (!isInitialized) {
      _log.fine('Email transport start skipped; not provisioned.');
      return;
    }
    if (!_acceptsRuntimeWork) {
      await start();
    }
  }

  Future<void> shutdown({String? jid, bool clearCredentials = false}) async {
    _runtimePhase = _EmailRuntimePhase.disposing;
    await stop();
    _resetImapCapabilities();
    if (clearCredentials) {
      try {
        await _transport.deconfigureAccount();
      } on Exception catch (error, stackTrace) {
        _log.warning('Failed to deconfigure email account', error, stackTrace);
      }
      final scope = _scopeForOptionalJid(jid);
      if (scope != null) {
        await _clearCredentials(scope);
      }
    }
    await _transport.dispose();
    _credentialSession.clearRuntime();
    _pendingPushToken = null;
    _runtimePhase = _EmailRuntimePhase.stopped;
  }

  Future<Chat> ensureChatForAddress({
    required String address,
    String? displayName,
    String? fromAddress,
  }) async {
    await _ensureReady();
    final String scope = _requireActiveScope();
    final _EmailAccountBinding account = await _accountBindingForScope(
      scope: scope,
      fromAddress: fromAddress,
    );
    await _ensureAccountConfigured(scope: scope, account: account);
    final chatId = await _guardDeltaOperation(
      operation: 'ensure email chat',
      body: () => _transport.ensureChatForAddress(
        address: address,
        displayName: displayName,
        accountId: account.deltaAccountId,
      ),
    );
    return _waitForChat(chatId, accountId: account.deltaAccountId);
  }

  Future<Chat> ensureChatForEmailChat(Chat chat) async {
    final binding = await _bindEmailChat(chat);
    final db = await _databaseBuilder();
    return await db.getChat(binding.chat.jid) ?? binding.chat;
  }

  Future<Chat?> resolveForwardTarget(Contact target) async {
    final targetChat = target.chat;
    if (targetChat != null) {
      return ensureChatForEmailChat(targetChat);
    }
    final address = target.address?.trim();
    if (address == null || address.isEmpty) {
      return null;
    }
    return ensureChatForAddress(
      address: address,
      displayName: target.displayName,
    );
  }

  Future<int> sendMessage({
    required Chat chat,
    required String body,
    String? subject,
    String? htmlBody,
    bool forwarded = false,
    String? forwardedFromJid,
    String? quotedStanzaId,
  }) async {
    if (kEnableDemoChats) {
      return _sendDemoEmailMessage(
        chat: chat,
        body: body,
        subject: subject,
        htmlBody: htmlBody,
        forwarded: forwarded,
        forwardedFromJid: forwardedFromJid,
        quotedStanzaId: quotedStanzaId,
      );
    }
    final binding = await _bindEmailChat(chat);
    final chatId = binding.deltaChatId;
    await _ensureReady();
    final normalizedSubject = _normalizeSubject(subject);
    final normalizedHtml = HtmlContentCodec.normalizeHtml(htmlBody);
    final trimmedBody = body.trim();
    final effectiveBody = trimmedBody.isNotEmpty
        ? trimmedBody
        : (normalizedHtml == null
              ? ''
              : HtmlContentCodec.toPlainText(normalizedHtml));
    String? shareId;
    String? subjectToken;
    if (normalizedSubject != null) {
      shareId = ShareTokenCodec.generateShareId();
      // Single-recipient sends do not need a visible subject token.
      subjectToken = null;
      final db = await _databaseBuilder();
      final senderJid = binding.senderIdentity(_transport);
      final participants = await _shareParticipants(
        shareId: shareId,
        chats: [binding.chat],
        senderJid: senderJid,
      );
      final shareRecord = MessageShareData(
        shareId: shareId,
        originatorDcMsgId: null,
        subjectToken: subjectToken,
        subject: normalizedSubject,
        createdAt: DateTime.timestamp(),
        participantCount: participants.length,
      );
      await db.createMessageShare(
        share: shareRecord,
        participants: participants,
      );
    }
    final transmitBody = subjectToken != null
        ? ShareTokenCodec.injectToken(
            token: subjectToken,
            body: _composeSubjectEnvelope(
              subject: normalizedSubject,
              body: effectiveBody,
            ),
          )
        : _composeSubjectEnvelope(
            subject: normalizedSubject,
            body: effectiveBody,
          );
    final localBodyOverride = trimmedBody.isNotEmpty
        ? trimmedBody
        : effectiveBody;
    final msgId = await _guardDeltaOperation(
      operation: 'send email message',
      body: () => _transport.sendText(
        chatId: chatId,
        body: transmitBody,
        subject: normalizedSubject,
        shareId: shareId,
        localBodyOverride: localBodyOverride,
        htmlBody: normalizedHtml,
        quotingStanzaId: quotedStanzaId,
        accountId: binding.deltaAccountId,
      ),
    );
    if (shareId != null) {
      final db = await _databaseBuilder();
      await db.assignShareOriginator(
        shareId: shareId,
        originatorDcMsgId: msgId,
      );
    }
    if (forwarded) {
      final db = await _databaseBuilder();
      final message = await db.getMessageByDeltaId(
        msgId,
        deltaAccountId: binding.deltaAccountId,
      );
      if (message != null && !message.isForwarded) {
        await db.updateMessage(
          message.copyWith(
            pseudoMessageData: message.pseudoMessageDataWithForwarded(
              forwardedFromJid: forwardedFromJid,
            ),
          ),
        );
      }
    }
    return msgId;
  }

  Future<int> sendAttachment({
    required Chat chat,
    required EmailAttachment attachment,
    String? subject,
    String? htmlCaption,
    Message? quotedDraft,
    bool forwarded = false,
    String? forwardedFromJid,
    String? quotedStanzaId,
  }) async {
    final syntheticReply = syntheticEmailReplyEnvelope(
      body: attachment.caption?.trim() ?? '',
      subject: subject,
      quotedDraft: quotedDraft,
    );
    final effectiveSubject = syntheticReply?.subject ?? subject;
    final effectiveHtmlCaption = syntheticReply?.htmlBody ?? htmlCaption;
    final effectiveAttachment = syntheticReply == null
        ? attachment
        : attachment.copyWith(
            caption: syntheticReply.body.isEmpty ? null : syntheticReply.body,
          );
    final effectiveQuotedStanzaId =
        syntheticReply?.quotedStanzaId ?? quotedStanzaId;
    if (kEnableDemoChats) {
      return _sendDemoEmailAttachment(
        chat: chat,
        attachment: effectiveAttachment,
        subject: effectiveSubject,
        htmlCaption: effectiveHtmlCaption,
        forwarded: forwarded,
        forwardedFromJid: forwardedFromJid,
        quotedStanzaId: effectiveQuotedStanzaId,
      );
    }
    final binding = await _bindEmailChat(chat);
    final chatId = binding.deltaChatId;
    await _ensureReady();
    final normalizedSubject = _normalizeSubject(effectiveSubject);
    final normalizedHtml = HtmlContentCodec.normalizeHtml(effectiveHtmlCaption);
    String? shareId;
    if (normalizedSubject != null) {
      shareId = ShareTokenCodec.generateShareId();
      final db = await _databaseBuilder();
      final senderJid = binding.senderIdentity(_transport);
      final participants = await _shareParticipants(
        shareId: shareId,
        chats: [binding.chat],
        senderJid: senderJid,
      );
      final shareRecord = MessageShareData(
        shareId: shareId,
        originatorDcMsgId: null,
        subjectToken: null,
        subject: normalizedSubject,
        createdAt: DateTime.timestamp(),
        participantCount: participants.length,
      );
      await db.createMessageShare(
        share: shareRecord,
        participants: participants,
      );
    }
    var captionText = effectiveAttachment.caption?.trim() ?? '';
    if (captionText.isEmpty && normalizedHtml != null) {
      captionText = HtmlContentCodec.toPlainText(normalizedHtml);
    }
    final captionEnvelope = _composeSubjectEnvelope(
      subject: normalizedSubject,
      body: captionText,
    );
    final sanitizedCaption = captionText.trim();
    final msgId = await _guardDeltaOperation(
      operation: 'send email attachment',
      body: () => _transport.sendAttachment(
        chatId: chatId,
        attachment: effectiveAttachment.copyWith(caption: captionEnvelope),
        subject: normalizedSubject,
        shareId: shareId,
        captionOverride: sanitizedCaption,
        htmlCaption: normalizedHtml,
        quotingStanzaId: effectiveQuotedStanzaId,
        accountId: binding.deltaAccountId,
      ),
    );
    if (shareId != null) {
      final db = await _databaseBuilder();
      await db.assignShareOriginator(
        shareId: shareId,
        originatorDcMsgId: msgId,
      );
    }
    if (forwarded) {
      final db = await _databaseBuilder();
      final message = await db.getMessageByDeltaId(
        msgId,
        deltaAccountId: binding.deltaAccountId,
      );
      if (message != null && !message.isForwarded) {
        await db.updateMessage(
          message.copyWith(
            pseudoMessageData: message.pseudoMessageDataWithForwarded(
              forwardedFromJid: forwardedFromJid,
            ),
          ),
        );
      }
    }
    return msgId;
  }

  Future<FanOutSendReport> fanOutSend({
    required List<Contact> targets,
    String? body,
    String? htmlBody,
    EmailAttachment? attachment,
    String? htmlCaption,
    bool useSubjectToken = true,
    bool tokenAsSignature = true,
    String? shareId,
    String? subject,
    String? quotedStanzaId,
  }) async {
    if (kEnableDemoChats) {
      return _fanOutSendDemo(
        targets: targets,
        body: body,
        htmlBody: htmlBody,
        attachment: attachment,
        htmlCaption: htmlCaption,
        shareId: shareId,
        subject: subject,
        quotedStanzaId: quotedStanzaId,
      );
    }
    await _ensureReady();
    if (targets.isEmpty) {
      throw const FanOutNoRecipientsException();
    }
    final targetChatsByJid = await _resolveFanOutTargets(targets);
    if (targetChatsByJid.isEmpty) {
      throw const FanOutResolveFailedException();
    }
    if (targetChatsByJid.length > _maxFanOutRecipients) {
      throw const FanOutTooManyRecipientsException(_maxFanOutRecipients);
    }
    final trimmedBody = body?.trim() ?? '';
    final normalizedHtmlBody = HtmlContentCodec.normalizeHtml(htmlBody);
    var bodyText = trimmedBody;
    if (bodyText.isEmpty && normalizedHtmlBody != null) {
      bodyText = HtmlContentCodec.toPlainText(normalizedHtmlBody);
    }
    final hasBody = bodyText.isNotEmpty;
    final normalizedSubject = _normalizeSubject(subject);
    final hasSubject = normalizedSubject != null;
    final hasAttachment = attachment != null;
    final normalizedHtmlCaption = HtmlContentCodec.normalizeHtml(htmlCaption);
    if (!hasBody && !hasAttachment && !hasSubject) {
      throw const FanOutEmptyMessageException();
    }
    final db = await _databaseBuilder();
    final existingShare = shareId == null
        ? null
        : await db.getMessageShareById(shareId);
    final existingParticipants = <MessageParticipantData>[];
    final existingShareId = existingShare?.shareId ?? shareId;
    if (existingShareId != null) {
      existingParticipants.addAll(
        await db.getParticipantsForShare(existingShareId),
      );
    }
    final effectiveShareId =
        shareId ?? existingShare?.shareId ?? ShareTokenCodec.generateShareId();
    final shouldUseToken = useSubjectToken && targetChatsByJid.length > 1;
    final subjectShareToken =
        existingShare?.subjectToken ??
        (shouldUseToken ? _shareTokenForShare(effectiveShareId) : null);
    final effectiveSubject = normalizedSubject ?? existingShare?.subject;
    final htmlBodyWithToken = subjectShareToken == null
        ? normalizedHtmlBody
        : ShareTokenHtmlCodec.injectToken(
            html: normalizedHtmlBody,
            token: subjectShareToken,
            asSignature: tokenAsSignature,
            footerLabel: _l10n.shareTokenFooterLabel,
          );
    final htmlCaptionWithToken = subjectShareToken == null
        ? normalizedHtmlCaption
        : ShareTokenHtmlCodec.injectToken(
            html: normalizedHtmlCaption,
            token: subjectShareToken,
            asSignature: tokenAsSignature,
            footerLabel: _l10n.shareTokenFooterLabel,
          );

    final transmitBody = subjectShareToken != null
        ? ShareTokenCodec.injectToken(
            token: subjectShareToken,
            body: _composeSubjectEnvelope(
              subject: effectiveSubject,
              body: bodyText,
            ),
            asSignature: tokenAsSignature,
            footerLabel: _l10n.shareTokenFooterLabel,
          )
        : _composeSubjectEnvelope(subject: effectiveSubject, body: bodyText);
    var captionText = attachment?.caption?.trim() ?? '';
    if (captionText.isEmpty && normalizedHtmlCaption != null) {
      captionText = HtmlContentCodec.toPlainText(normalizedHtmlCaption);
    }
    final transmitCaption = subjectShareToken != null
        ? ShareTokenCodec.injectToken(
            token: subjectShareToken,
            body: _composeSubjectEnvelope(
              subject: effectiveSubject,
              body: captionText,
            ),
            asSignature: tokenAsSignature,
            footerLabel: _l10n.shareTokenFooterLabel,
          )
        : _composeSubjectEnvelope(subject: effectiveSubject, body: captionText);
    final participants = await _shareParticipants(
      shareId: effectiveShareId,
      chats: targetChatsByJid.values,
      existingParticipants: existingParticipants,
    );
    final shareRecord = MessageShareData(
      shareId: effectiveShareId,
      originatorDcMsgId: existingShare?.originatorDcMsgId,
      subjectToken: subjectShareToken,
      subject: effectiveSubject,
      createdAt: existingShare?.createdAt ?? DateTime.timestamp(),
      participantCount: participants.length,
    );
    await db.createMessageShare(share: shareRecord, participants: participants);

    final statuses = <FanOutRecipientStatus>[];
    final bool originatorAlreadyCaptured =
        existingShare?.originatorDcMsgId != null;
    int? originatorMsgId;

    Future<(FanOutRecipientStatus, int?)> sendTo(Chat entry) async {
      try {
        final binding = await _bindEmailChat(entry);
        final chatId = binding.deltaChatId;
        int msgId;
        if (hasAttachment) {
          final updatedAttachment = attachment.copyWith(
            caption: transmitCaption,
          );
          msgId = await _guardDeltaOperation(
            operation: 'fan-out attachment',
            body: () => _transport.sendAttachment(
              chatId: chatId,
              attachment: updatedAttachment,
              subject: effectiveSubject,
              shareId: effectiveShareId,
              captionOverride: captionText,
              htmlCaption: htmlCaptionWithToken,
              quotingStanzaId: quotedStanzaId,
              accountId: binding.deltaAccountId,
            ),
          );
        } else {
          msgId = await _guardDeltaOperation(
            operation: 'fan-out message',
            body: () => _transport.sendText(
              chatId: chatId,
              body: transmitBody,
              subject: effectiveSubject,
              shareId: effectiveShareId,
              localBodyOverride: bodyText,
              htmlBody: htmlBodyWithToken,
              quotingStanzaId: quotedStanzaId,
              accountId: binding.deltaAccountId,
            ),
          );
        }
        return (
          FanOutRecipientStatus(
            chat: binding.chat,
            state: FanOutRecipientState.sent,
            deltaMsgId: msgId,
          ),
          msgId,
        );
      } on Exception catch (error, stackTrace) {
        final targetId = entry.deltaChatId != null
            ? 'dc-${entry.deltaChatId}'
            : 'unresolved-recipient';
        _log.warning(
          'Failed to send fan-out message to $targetId',
          error,
          stackTrace,
        );
        return (
          FanOutRecipientStatus(
            chat: entry,
            state: FanOutRecipientState.failed,
            error: error,
          ),
          null,
        );
      }
    }

    final results = <(FanOutRecipientStatus, int?)>[];
    final targetsToSend = targetChatsByJid.values.toList(growable: false);
    for (
      var index = 0;
      index < targetsToSend.length;
      index += _fanOutConcurrentOps
    ) {
      final chunk = targetsToSend
          .skip(index)
          .take(_fanOutConcurrentOps)
          .toList();
      results.addAll(await Future.wait(chunk.map(sendTo)));
    }

    for (final result in results) {
      statuses.add(result.$1);
      if (!originatorAlreadyCaptured &&
          originatorMsgId == null &&
          result.$2 != null) {
        originatorMsgId = result.$2;
      }
    }

    if (!originatorAlreadyCaptured && originatorMsgId != null) {
      await db.assignShareOriginator(
        shareId: effectiveShareId,
        originatorDcMsgId: originatorMsgId,
      );
    }

    final attachmentWarning =
        hasAttachment &&
        targetChatsByJid.length > 1 &&
        attachment.sizeBytes > _attachmentFanOutWarningBytes;

    return FanOutSendReport(
      shareId: effectiveShareId,
      subjectToken: subjectShareToken,
      subject: effectiveSubject,
      statuses: statuses,
      attachmentWarning: attachmentWarning,
    );
  }

  Future<FanOutSendReport> _fanOutSendDemo({
    required List<Contact> targets,
    String? body,
    String? htmlBody,
    EmailAttachment? attachment,
    String? htmlCaption,
    String? shareId,
    String? subject,
    String? quotedStanzaId,
  }) async {
    if (targets.isEmpty) {
      throw const FanOutNoRecipientsException();
    }
    final effectiveShareId = shareId ?? ShareTokenCodec.generateShareId();
    final statuses = <FanOutRecipientStatus>[];
    for (final target in targets) {
      try {
        final chat = _demoChatForTarget(target);
        if (attachment != null) {
          final captionedAttachment = attachment.copyWith(
            caption: htmlCaption ?? body,
          );
          await _sendDemoEmailAttachment(
            chat: chat,
            attachment: captionedAttachment,
            subject: subject,
            htmlCaption: htmlCaption,
            quotedStanzaId: quotedStanzaId,
          );
          _scheduleDemoCopiedReply(chat);
        } else {
          final normalizedHtml = HtmlContentCodec.normalizeHtml(htmlBody);
          final effectiveBody =
              body ??
              (normalizedHtml == null
                  ? ''
                  : HtmlContentCodec.toPlainText(normalizedHtml));
          await _sendDemoEmailMessage(
            chat: chat,
            body: effectiveBody,
            subject: subject,
            htmlBody: htmlBody,
            quotedStanzaId: quotedStanzaId,
          );
        }
        statuses.add(
          FanOutRecipientStatus(
            chat: chat,
            state: FanOutRecipientState.sent,
            deltaMsgId: demoNow().millisecondsSinceEpoch,
          ),
        );
      } catch (error) {
        final chat = _demoChatForTarget(target);
        statuses.add(
          FanOutRecipientStatus(
            chat: chat,
            state: FanOutRecipientState.failed,
            error: error,
          ),
        );
      }
    }
    return FanOutSendReport(
      shareId: effectiveShareId,
      statuses: statuses,
      subject: subject,
    );
  }

  void _scheduleDemoCopiedReply(Chat chat) {
    if (chat.jid != DemoChats.contact1Jid) return;
    const delay = Duration(milliseconds: 1500);
    unawaited(
      Future<void>.delayed(delay, () async {
        const generator = Uuid();
        final stanzaId = 'demo-email-${generator.v4()}';
        final db = await _databaseBuilder();
        final timestamp = await _resolveDemoTimestampForChat(
          db: db,
          jid: chat.jid,
          candidate: demoNow(),
        );
        final message = Message(
          stanzaID: stanzaId,
          originID: stanzaId,
          senderJid: DemoChats.contact1Jid,
          chatJid: chat.jid,
          body: 'Copied',
          timestamp: timestamp,
          encryptionProtocol: EncryptionProtocol.none,
          acked: true,
          received: true,
          displayed: true,
        );
        await db.saveMessage(message);
      }),
    );
  }

  Chat _demoChatForTarget(Contact target) {
    final address = target.address?.trim();
    if (target.chat != null) {
      return target.chat!;
    }
    final String selectedAddress = address?.isNotEmpty == true
        ? address!
        : kDemoSelfJid;
    final displayName = target.displayName.trim();
    final String resolvedTitle = displayName.isNotEmpty
        ? displayName
        : selectedAddress;
    return Chat.fromJid(selectedAddress).copyWith(
      title: resolvedTitle,
      contactDisplayName: resolvedTitle,
      emailAddress: selectedAddress,
      transport: MessageTransport.email,
      lastChangeTimestamp: demoNow(),
    );
  }

  String? _normalizeSubject(String? subject) {
    return sanitizeEmailHeaderValue(
      stripSyntheticForwardSubjectMarker(subject),
    );
  }

  String? _normalizeReplySubject({
    required String? subject,
    required String? quotedSubject,
    String? quotedSenderLabel,
  }) {
    return _normalizeSubject(
      syntheticReplySubject(
        subject: subject,
        quotedSubject: _normalizeSubject(quotedSubject),
        quotedSenderLabel: quotedSenderLabel,
      ),
    );
  }

  ({String subject, String body, String? htmlBody}) _syntheticReplyEnvelope(
    Message quotedMessage, {
    required String body,
    required String? subject,
  }) {
    final quotedContent = ChatSubjectCodec.splitDisplayBody(
      body: quotedMessage.body,
      subject: quotedMessage.subject,
    );
    final envelope = syntheticReplyEnvelope(
      body: body,
      subject: subject,
      quotedSubject: quotedContent.subject,
      quotedBody: quotedContent.body,
      quotedSenderLabel:
          displaySafeAddress(quotedMessage.senderJid) ??
          quotedMessage.senderJid.trim(),
    );
    final normalizedBody = envelope.body.trim();
    return (
      subject: envelope.subject,
      body: normalizedBody,
      htmlBody: normalizedBody.isEmpty
          ? null
          : HtmlContentCodec.fromPlainText(normalizedBody),
    );
  }

  ({String subject, String body, String? htmlBody, String quotedStanzaId})?
  syntheticEmailReplyEnvelope({
    required String body,
    required String? subject,
    required Message? quotedDraft,
  }) {
    if (quotedDraft == null) {
      return null;
    }
    final quotedContent = ChatSubjectCodec.splitDisplayBody(
      body: quotedDraft.body,
      subject: quotedDraft.subject,
    );
    final envelope = syntheticReplyEnvelope(
      body: body,
      subject: subject,
      quotedSubject: quotedContent.subject,
      quotedBody: quotedContent.body,
      quotedSenderLabel:
          displaySafeAddress(quotedDraft.senderJid) ?? quotedDraft.senderJid,
    );
    final normalizedBody = envelope.body.trim();
    return (
      subject: envelope.subject,
      body: normalizedBody,
      htmlBody: normalizedBody.isEmpty
          ? null
          : HtmlContentCodec.fromPlainText(normalizedBody),
      quotedStanzaId: quotedDraft.stanzaID,
    );
  }

  String? _normalizeDraftHtml({required String text, String? htmlBody}) {
    final normalizedHtml = HtmlContentCodec.normalizeHtml(htmlBody);
    if (normalizedHtml != null) {
      return normalizedHtml;
    }
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return null;
    }
    return HtmlContentCodec.normalizeHtml(HtmlContentCodec.fromPlainText(text));
  }

  EmailAttachment? _draftAttachmentForCore(List<EmailAttachment> attachments) {
    if (attachments.isEmpty) return null;
    return attachments.first;
  }

  int _viewTypeForDraftAttachment(EmailAttachment attachment) {
    if (attachment.isGif) return DeltaMessageType.gif;
    if (attachment.isImage) return DeltaMessageType.image;
    if (attachment.isVideo) return DeltaMessageType.video;
    if (attachment.isAudio) return DeltaMessageType.audio;
    return DeltaMessageType.file;
  }

  String _composeSubjectEnvelope({
    required String? subject,
    required String? body,
  }) {
    final trimmedBody = body?.trim();
    if (trimmedBody?.isNotEmpty == true) {
      return trimmedBody!;
    }
    final trimmedSubject = subject?.trim();
    if (trimmedSubject?.isNotEmpty == true) {
      return trimmedSubject!;
    }
    return '';
  }

  String _shareTokenForShare(String shareId) {
    try {
      return ShareTokenCodec.subjectToken(shareId);
    } on ArgumentError catch (error, stackTrace) {
      _log.warning(_shareTokenInvalidLog, error, stackTrace);
      throw const FanOutInvalidShareTokenException();
    }
  }

  Future<ShareContext?> shareContextForMessage(Message message) async {
    final deltaMsgId = message.deltaMsgId;
    if (deltaMsgId == null) return null;
    await _ensureReady();
    final db = await _databaseBuilder();
    final shareId = await db.getShareIdForDeltaMessage(
      deltaMsgId,
      deltaAccountId: message.deltaAccountId,
    );
    if (shareId == null) return null;
    final participants = await db.getParticipantsForShare(shareId);
    final participantJids = participants
        .map((participant) => participant.contactJid)
        .toList();
    final chatList = await db.getChatsByJids(participantJids);
    final chatByJid = {for (final chat in chatList) chat.jid: chat};
    final chats = <Chat>[
      for (final participant in participants)
        if (chatByJid[participant.contactJid] != null)
          chatByJid[participant.contactJid]!,
    ];
    final shareRecord = await db.getMessageShareById(shareId);
    return ShareContext(
      shareId: shareId,
      participants: chats,
      subject: shareRecord?.subject,
      originatorDeltaMsgId: shareRecord?.originatorDcMsgId,
      participantCount: shareRecord?.participantCount,
    );
  }

  Future<List<EmailAttachment>> attachmentsForMessage(Message message) async {
    final messageId = message.id;
    await _ensureReady();
    final db = await _databaseBuilder();
    final metadataIds = <String>[];
    if (messageId != null && messageId.isNotEmpty) {
      var attachments = await db.getMessageAttachments(messageId);
      if (attachments.isNotEmpty) {
        final transportGroupId = attachments.first.transportGroupId?.trim();
        if (transportGroupId != null && transportGroupId.isNotEmpty) {
          attachments = await db.getMessageAttachmentsForGroup(
            transportGroupId,
          );
        }
        final ordered = attachments.whereType<MessageAttachmentData>().toList(
          growable: false,
        )..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        for (final attachment in ordered) {
          metadataIds.add(attachment.fileMetadataId);
        }
      }
    }
    if (metadataIds.isEmpty) {
      final fallbackId = message.fileMetadataID;
      if (fallbackId != null && fallbackId.isNotEmpty) {
        metadataIds.add(fallbackId);
      }
    }
    final orderedIds = LinkedHashSet<String>.from(metadataIds);
    if (orderedIds.isEmpty) return const [];
    final attachments = <EmailAttachment>[];
    final metadataList = await db.getFileMetadataForIds(orderedIds);
    final metadataById = {
      for (final metadata in metadataList) metadata.id: metadata,
    };
    for (final metadataId in orderedIds) {
      final metadata = metadataById[metadataId];
      final path = metadata?.path;
      if (metadata == null || path == null || path.isEmpty) {
        continue;
      }
      final file = File(path);
      if (!await file.exists()) {
        continue;
      }
      final size = metadata.sizeBytes ?? await file.length();
      attachments.add(
        EmailAttachment(
          path: path,
          fileName: metadata.filename,
          sizeBytes: size,
          mimeType: metadata.mimeType,
          width: metadata.width,
          height: metadata.height,
          metadataId: metadata.id,
        ),
      );
    }
    return attachments;
  }

  Future<EmailAttachment?> attachmentForMessage(Message message) async {
    final attachments = await attachmentsForMessage(message);
    return attachments.isEmpty ? null : attachments.first;
  }

  Future<int> sendToAddress({
    required String address,
    String? displayName,
    required String body,
  }) async {
    final chat = await ensureChatForAddress(
      address: address,
      displayName: displayName,
    );
    return sendMessage(chat: chat, body: body);
  }

  Future<void> registerPushToken(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) return;
    _pendingPushToken = normalized;
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _transport.registerPushToken(normalized);
  }

  Future<void> handleNetworkAvailable() async {
    if (_blocksRuntimeReentry) {
      return;
    }
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await ensureEventChannelActive();
    await _transport.notifyNetworkAvailable();
    await _bootstrapActiveAccountIfNeeded();
    await _runReconnectCatchUp();
    await _refreshConnectivityState(source: _EmailSyncSource.networkAvailable);
    fireAndForget(
      _scheduleReconnectRestartIfOffline,
      operationName: 'EmailService.reconnectRestartIfOffline',
    );
  }

  Future<void> handleNetworkLost() async {
    if (_blocksRuntimeReentry) {
      return;
    }
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _transport.notifyNetworkLost();
  }

  Future<bool> performBackgroundFetch({
    Duration timeout = _imapSyncFetchTimeout,
  }) async {
    if (_blocksRuntimeReentry) {
      return false;
    }
    if (_databasePrefix == null || _databasePassphrase == null) {
      return false;
    }
    return _transport.performBackgroundFetch(timeout);
  }

  Future<bool> _performBackgroundFetchIfIdle({
    Duration timeout = _imapSyncFetchTimeout,
  }) async {
    if (_transport.isIoRunning) {
      return false;
    }
    return performBackgroundFetch(timeout: timeout);
  }

  Future<void> syncContactsFromCore() async {
    if (!hasActiveSession || _blocksRuntimeReentry) {
      return;
    }
    _cancelContactsSyncTimer();
    await _contactsSyncQueue.run(_syncContactsFromCore);
  }

  Future<void> _syncContactsFromCore() async {
    if (!await _ensureBackgroundSyncReady()) {
      return;
    }
    final contactIds = await _transport.getContactIds(
      flags: _deltaContactListFlags,
    );
    if (!_acceptsRuntimeWork || _blocksRuntimeReentry) {
      return;
    }
    final contacts = await _hydrateContactsByIds(contactIds);
    if (!_acceptsRuntimeWork || _blocksRuntimeReentry) {
      return;
    }
    final blockedIds = await _transport.getBlockedContactIds();
    if (!_acceptsRuntimeWork || _blocksRuntimeReentry) {
      return;
    }
    final blocked = await _hydrateContactsByIds(blockedIds);
    if (!_acceptsRuntimeWork || _blocksRuntimeReentry) {
      return;
    }
    final db = await _databaseBuilder();
    final contactsByNativeId = <String, String>{};
    final contactsByAddress = <String, DeltaContact>{};

    for (final contact in contacts) {
      final address = contact.address;
      if (address == null || address.trim().isEmpty) {
        continue;
      }
      final normalized = normalizeEmailAddress(address);
      if (normalized.isEmpty) {
        continue;
      }
      final nativeId = '$_deltaContactIdPrefix${contact.id}';
      contactsByNativeId[nativeId] = normalized;
      contactsByAddress.putIfAbsent(normalized, () => contact);
    }

    await db.replaceContacts(contactsByNativeId);
    await _syncEmailBlocklist(db: db, blockedContacts: blocked);
    await _syncEmailChatMetadata(db: db, contactsByAddress: contactsByAddress);
  }

  Future<void> refreshChatlistFromCore() async {
    await _chatlistSyncQueue.run(() async {
      if (!await _ensureBackgroundSyncReady()) {
        return;
      }
      await _transport.refreshChatlistSnapshot();
    });
  }

  Future<void> syncInboxAndSent() async {
    await _performBackgroundFetchIfIdle(timeout: _imapSyncFetchTimeout);
    await refreshChatlistFromCore();
  }

  Future<bool> recoverForHomeRefresh() async {
    if (!await canReconnectConfiguredSession()) {
      return true;
    }
    try {
      await ensureEventChannelActive();
      await handleNetworkAvailable();
      return !_blocksRuntimeReentry;
    } on Exception {
      _log.fine('Email transport recovery failed.');
      return false;
    }
  }

  Future<bool> refreshUnreadForHomeRefresh() async {
    if (!hasActiveSession) {
      return true;
    }
    try {
      const emailUnreadFetchTimeout = Duration(seconds: 8);
      final fetched = await performBackgroundFetch(
        timeout: emailUnreadFetchTimeout,
      );
      if (!fetched) {
        return false;
      }
      await refreshChatlistFromCore();
      return true;
    } on Exception {
      _log.fine('Email unread sync failed.');
      return false;
    }
  }

  Future<bool> refreshHistoryForHomeRefresh() async {
    if (!hasActiveSession) {
      return true;
    }
    try {
      const emailHistoryFetchTimeout = Duration(seconds: 25);
      final fetched = await performBackgroundFetch(
        timeout: emailHistoryFetchTimeout,
      );
      if (!fetched) {
        return false;
      }
      await refreshChatlistFromCore();
      return true;
    } on Exception {
      _log.fine('Email background sync failed.');
      return false;
    }
  }

  Future<bool> syncContactsForHomeRefresh() async {
    if (!hasActiveSession) {
      return true;
    }
    try {
      await syncContactsFromCore();
      return true;
    } on Exception {
      _log.fine('Email contact sync failed.');
      return false;
    }
  }

  Future<void> _syncEmailBlocklist({
    required XmppDatabase db,
    required List<DeltaContact> blockedContacts,
  }) async {
    final blockedAddresses = <String>{};
    for (final contact in blockedContacts) {
      final address = contact.address;
      if (address == null || address.trim().isEmpty) {
        continue;
      }
      final normalized = normalizeEmailAddress(address);
      if (normalized.isEmpty) {
        continue;
      }
      blockedAddresses.add(normalized);
    }

    final spamEntries = await db.getEmailSpamlist();
    final spamAddresses = spamEntries.map((entry) => entry.address).toSet();
    final filteredBlockedAddresses = blockedAddresses.difference(spamAddresses);

    final existing = await db.getEmailBlocklist();
    final existingAddresses = existing.map((entry) => entry.address).toSet();
    final legacyAddresses = <String>{};
    for (final entry in existing) {
      if (_isLegacyBlocklistSource(entry.sourceId)) {
        legacyAddresses.add(entry.address);
      }
    }

    final toAdd = filteredBlockedAddresses.difference(existingAddresses);
    final toRemove = legacyAddresses.difference(filteredBlockedAddresses);

    for (final address in toAdd) {
      await db.addEmailBlock(address, sourceId: syncLegacySourceId);
    }
    for (final address in toRemove) {
      await db.removeEmailBlock(address);
    }
  }

  bool _isLegacyBlocklistSource(String? sourceId) {
    final normalized = sourceId?.trim();
    return normalized == null ||
        normalized.isEmpty ||
        normalized == syncLegacySourceId;
  }

  Future<void> applySpamSyncUpdate(SpamSyncUpdate update) async {
    final normalized = normalizeEmailAddress(update.address);
    if (normalized.isEmpty || !normalized.isValidEmailAddress) {
      return;
    }
    try {
      await _ensureReady();
      final db = await _databaseBuilder();
      if (update.isSpam) {
        await _transport.blockContact(normalized);
      } else {
        final blocked = await db.isEmailAddressBlocked(normalized);
        if (!blocked) {
          await _transport.unblockContact(normalized);
        }
      }
    } on Exception {
      _log.fine('Failed to apply spam sync update to DeltaChat core.');
    }
  }

  Future<void> applyEmailBlocklistSyncUpdate(
    EmailBlocklistSyncUpdate update,
  ) async {
    final normalized = normalizeEmailAddress(update.address);
    if (normalized.isEmpty || !normalized.isValidEmailAddress) {
      return;
    }
    try {
      await _ensureReady();
      final db = await _databaseBuilder();
      if (update.blocked) {
        await _transport.blockContact(normalized);
      } else {
        final isSpam = await db.isEmailAddressSpam(normalized);
        if (!isSpam) {
          await _transport.unblockContact(normalized);
        }
      }
    } on Exception {
      _log.fine(
        'Failed to apply email blocklist sync update to DeltaChat core.',
      );
    }
  }

  Future<void> _syncEmailChatMetadata({
    required XmppDatabase db,
    required Map<String, DeltaContact> contactsByAddress,
  }) async {
    final addresses = contactsByAddress.keys.toList(growable: false);
    if (addresses.isEmpty) return;
    final chats = await db.getChatsByJids(addresses);
    final chatByJid = {for (final chat in chats) chat.jid: chat};
    for (final entry in contactsByAddress.entries) {
      final address = entry.key;
      final contact = entry.value;
      final chat = chatByJid[address];
      if (chat == null) {
        continue;
      }
      final trimmedName = contact.name?.trim();
      final displayName = trimmedName?.isNotEmpty == true
          ? trimmedName
          : chat.contactDisplayName;
      final updated = chat.copyWith(
        contactDisplayName: displayName,
        contactID: address,
        contactJid: address,
        emailAddress: address,
      );
      if (updated != chat) {
        await db.updateChat(updated);
      }
    }
  }

  Future<void> backfillChatHistory({
    required Chat chat,
    required int desiredWindow,
    int? beforeMessageId,
    DateTime? beforeTimestamp,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    if (chat.defaultTransport != MessageTransport.email) {
      return;
    }
    if (desiredWindow < _minimumHistoryWindow) {
      return;
    }
    if (beforeMessageId == null && beforeTimestamp == null) {
      return;
    }
    await _ensureReady();
    final String scope = _requireActiveScope();
    final _EmailAccountBinding account = await _accountBindingForChat(chat);
    final Chat resolvedChat = await _storedEmailChatForAccount(
      chat: chat,
      deltaAccountId: account.deltaAccountId,
    );
    await _ensureAccountConfigured(scope: scope, account: account);
    final int? chatId = await _deltaChatIdForAccount(
      chat: resolvedChat,
      deltaAccountId: account.deltaAccountId,
    );
    if (chatId == null) {
      return;
    }
    final db = await _databaseBuilder();
    final Chat effectiveChat =
        await db.getChatByDeltaChatId(
          chatId,
          accountId: account.deltaAccountId,
        ) ??
        resolvedChat;
    final localCount = await db.countChatMessages(
      effectiveChat.jid,
      filter: filter,
      includePseudoMessages: _includePseudoMessagesInBackfill,
    );
    if (localCount >= desiredWindow) {
      return;
    }
    await _performBackgroundFetchIfIdle(timeout: _foregroundFetchTimeout);
    await _transport.backfillChatHistory(
      chatId: chatId,
      chatJid: effectiveChat.jid,
      desiredWindow: desiredWindow,
      beforeMessageId: beforeMessageId,
      beforeTimestamp: beforeTimestamp,
      filter: filter,
      accountId: account.deltaAccountId,
    );
  }

  Future<void> setForegroundKeepalive(bool enabled) async {
    if (!enabled) {
      await _stopForegroundKeepalive();
      if (hasActiveSession) {
        _startImapSyncLoop();
      }
      return;
    }
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    if (_foregroundKeepaliveEnabled) {
      return;
    }
    final bridge = _foregroundBridge;
    if (bridge == null) {
      _log.fine('Foreground bridge unavailable, skipping keepalive.');
      if (hasActiveSession) {
        _startImapSyncLoop();
      }
      return;
    }

    final operationId = ++_foregroundKeepaliveOperationId;

    await start();
    if (!_isForegroundKeepaliveOpCurrent(operationId)) {
      return;
    }

    _stopImapSyncLoop();
    _attachForegroundKeepaliveListener();

    try {
      await bridge.acquire(
        clientId: foregroundClientEmailKeepalive,
        config: buildForegroundServiceConfig(
          notificationText: 'Email sync active',
        ),
      );
      _foregroundKeepaliveServiceAcquired = true;
      if (!_isForegroundKeepaliveOpCurrent(operationId)) {
        await _releaseForegroundKeepaliveResources();
        return;
      }
      await bridge.send([
        emailKeepalivePrefix,
        emailKeepaliveStartCommand,
        _foregroundKeepaliveInterval.inMilliseconds,
      ]);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to enable email foreground keepalive',
        error,
        stackTrace,
      );
      _foregroundKeepaliveEnabled = false;
      await _releaseForegroundKeepaliveResources();
      _startImapSyncLoop();
      return;
    }

    if (!_isForegroundKeepaliveOpCurrent(operationId)) {
      await _releaseForegroundKeepaliveResources();
      _startImapSyncLoop();
      return;
    }

    _foregroundKeepaliveEnabled = true;
    Future<void>(() async {
      await _foregroundKeepaliveTick();
    });
  }

  Stream<List<Message>> messageStreamForChat(
    String jid, {
    int start = 0,
    int end = _defaultPageSize,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async* {
    await _ensureReady();
    final db = await _databaseBuilder();
    final initial = await db.getChatMessages(
      jid,
      start: start,
      end: end,
      filter: filter,
    );
    yield initial;
    yield* db.watchChatMessages(jid, start: start, end: end, filter: filter);
  }

  Future<List<Message>> loadChatMessagesBefore({
    required String jid,
    required DateTime beforeTimestamp,
    required String beforeStanzaId,
    int? beforeDeltaMsgId,
    required int limit,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    await _ensureReady();
    final db = await _databaseBuilder();
    return db.getChatMessagesBefore(
      jid,
      beforeTimestamp: beforeTimestamp,
      beforeStanzaId: beforeStanzaId,
      beforeDeltaMsgId: beforeDeltaMsgId,
      limit: limit,
      filter: filter,
    );
  }

  Stream<List<PinnedMessageEntry>> pinnedMessagesStream(String jid) async* {
    await _ensureReady();
    final db = await _databaseBuilder();
    yield await db.getPinnedMessages(jid);
    yield* db.watchPinnedMessages(jid);
  }

  Stream<List<Draft>> draftsStream({
    int start = 0,
    int end = _defaultPageSize,
  }) async* {
    await _ensureReady();
    final db = await _databaseBuilder();
    yield await db.getDrafts(start: start, end: end);
    yield* db.watchDrafts(start: start, end: end);
  }

  Stream<List<Chat>> chatsStream({
    int start = 0,
    int end = _defaultPageSize,
  }) async* {
    await _ensureReady();
    final db = await _databaseBuilder();
    yield await db.getChats(start: start, end: end);
    yield* db.watchChats(start: start, end: end);
  }

  Stream<Chat?> chatStream(String jid) async* {
    await _ensureReady();
    final db = await _databaseBuilder();
    yield await db.getChat(jid);
    yield* db.watchChat(jid);
  }

  Future<void> pinMessage({
    required Chat chat,
    required Message message,
  }) async {
    await _ensureReady();
    final chatJid = chat.jid.trim();
    final stanzaId = message.stanzaID.trim();
    if (chatJid.isEmpty || stanzaId.isEmpty) {
      return;
    }
    final messageService = _messageService;
    if (messageService != null) {
      await messageService.pinMessage(chatJid: chatJid, message: message);
      return;
    }
    final pinnedAt = DateTime.timestamp().toUtc();
    final db = await _databaseBuilder();
    await db.upsertPinnedMessage(
      PinnedMessageEntry(
        messageStanzaId: stanzaId,
        chatJid: chatJid,
        pinnedAt: pinnedAt,
        active: true,
      ),
    );
  }

  Future<void> unpinMessage({
    required Chat chat,
    required Message message,
  }) async {
    await _ensureReady();
    final chatJid = chat.jid.trim();
    final stanzaId = message.stanzaID.trim();
    if (chatJid.isEmpty || stanzaId.isEmpty) {
      return;
    }
    final messageService = _messageService;
    if (messageService != null) {
      await messageService.unpinMessage(chatJid: chatJid, message: message);
      return;
    }
    final db = await _databaseBuilder();
    await db.deletePinnedMessage(chatJid: chatJid, messageStanzaId: stanzaId);
  }

  Future<void> _processDeltaEvent(DeltaCoreEvent event) async {
    final eventType = DeltaEventType.fromCode(event.type);
    if (eventType == null) {
      return;
    }
    switch (eventType) {
      case DeltaEventType.error:
        _handleCoreError(event.data2Text);
        break;
      case DeltaEventType.errorSelfNotInGroup:
        _handleSelfNotInGroup(event.data2Text);
        break;
      case DeltaEventType.incomingMsg:
        if (event.data2 > _deltaEventMessageUnset) {
          _queueNotification(
            chatId: event.data1,
            msgId: event.data2,
            accountId: event.accountId ?? DeltaAccountDefaults.legacyId,
          );
        }
        break;
      case DeltaEventType.incomingMsgBunch:
        _suppressQueuedNotificationsThroughCurrentSequence(
          accountId: event.accountId ?? DeltaAccountDefaults.legacyId,
          chatId: event.data1 > 0 ? event.data1 : null,
        );
        break;
      case DeltaEventType.incomingReaction:
        await _handleIncomingReaction(
          chatId: event.data1,
          msgId: event.data2,
          accountId: event.accountId ?? DeltaAccountDefaults.legacyId,
          reaction: event.data2Text,
        );
        break;
      case DeltaEventType.incomingWebxdcNotify:
        await _handleIncomingWebxdcNotify(
          chatId: event.data1,
          msgId: event.data2,
          accountId: event.accountId ?? DeltaAccountDefaults.legacyId,
          text: event.data2Text,
        );
        break;
      case DeltaEventType.msgRead:
        await _handleMessageRead(
          event.data1,
          accountId: event.accountId ?? DeltaAccountDefaults.legacyId,
        );
        break;
      case DeltaEventType.msgsNoticed:
        await _handleMessagesNoticed(
          event.data1,
          accountId: event.accountId ?? DeltaAccountDefaults.legacyId,
        );
        break;
      case DeltaEventType.chatModified:
        break;
      case DeltaEventType.chatDeleted:
        await _handleChatDeleted(
          event.data1,
          accountId: event.accountId ?? DeltaAccountDefaults.legacyId,
        );
        break;
      case DeltaEventType.contactsChanged:
        _scheduleContactsSyncFromCore();
        break;
      case DeltaEventType.accountsBackgroundFetchDone:
        await _handleBackgroundFetchDone();
        await _bootstrapActiveAccountIfNeeded();
        await refreshChatlistFromCore();
        break;
      case DeltaEventType.connectivityChanged:
        await _refreshConnectivityState(
          source: _EmailSyncSource.connectivityChangedEvent,
        );
        await _bootstrapActiveAccountIfNeeded();
        await _runReconnectCatchUp();
        break;
      case DeltaEventType.channelOverflow:
        await _handleChannelOverflow();
        break;
      default:
        break;
    }
  }

  void _enqueueDeltaOperation(
    Future<void> Function() operation, {
    String? operationName,
  }) {
    if (!_canProcessDeltaWork) {
      return;
    }
    final int epoch = _deltaOperationQueueEpoch;
    _deltaOperationQueue = _runDeltaOperation(
      previous: _deltaOperationQueue,
      epoch: epoch,
      operation: operation,
      operationName: operationName,
    );
  }

  Future<void> _runDeltaOperation({
    required Future<void> previous,
    required int epoch,
    required Future<void> Function() operation,
    String? operationName,
  }) async {
    try {
      await previous;
      if (epoch != _deltaOperationQueueEpoch || !_canProcessDeltaWork) {
        return;
      }
      await operation();
    } on Exception catch (error, stackTrace) {
      final operationLabel = operationName ?? 'delta operation';
      _log.warning(
        'Unhandled $operationLabel failure (${error.runtimeType}).',
        error.runtimeType,
        stackTrace,
      );
    }
  }

  void _resetDeltaOperationQueue() {
    _deltaOperationQueueEpoch += 1;
    _deltaOperationQueue = Future<void>.value();
  }

  void _queueNotification({
    required int chatId,
    required int msgId,
    required int accountId,
  }) {
    if (!_canProcessDeltaWork) {
      return;
    }
    _notificationQueue.enqueue(
      chatId: chatId,
      msgId: msgId,
      accountId: accountId,
      flushDelay: _notificationFlushDelay,
      onFlush: () {
        _enqueueDeltaOperation(
          _flushQueuedNotifications,
          operationName: _deltaQueueOperationNameFlushQueuedNotifications,
        );
      },
    );
  }

  void _suppressQueuedNotificationsThroughCurrentSequence({
    required int accountId,
    int? chatId,
  }) {
    _notificationQueue.suppressThroughCurrentSequence(
      accountId: accountId,
      chatId: chatId,
    );
  }

  void _dropPendingNotificationsForChat(int chatId, {required int accountId}) {
    _notificationQueue.dropForChat(chatId, accountId: accountId);
  }

  void _scheduleContactsSyncFromCore() {
    if (!_canProcessDeltaWork) {
      return;
    }
    if (_contactsSyncTimer != null) {
      return;
    }
    _contactsSyncTimer = Timer(_contactsSyncDebounce, () {
      _contactsSyncTimer = null;
      _enqueueDeltaOperation(
        syncContactsFromCore,
        operationName: _deltaQueueOperationNameSyncContactsFromCore,
      );
    });
  }

  void _cancelContactsSyncTimer() {
    _contactsSyncTimer?.cancel();
    _contactsSyncTimer = null;
  }

  Future<void> _flushQueuedNotifications() async {
    if (!_canProcessDeltaWork) {
      _notificationQueue.clear();
      return;
    }
    final pending = _notificationQueue.drain();
    if (pending.isEmpty) return;
    for (final entry in pending) {
      final scope = _PendingNotificationScope(
        accountId: entry.accountId,
        chatId: entry.chatId,
      );
      final dropThroughSequence = _notificationQueue.dropThroughSequence(scope);
      if (entry.sequence <= dropThroughSequence) {
        continue;
      }
      await _notifyIncoming(
        chatId: entry.chatId,
        msgId: entry.msgId,
        accountId: entry.accountId,
      );
    }
  }

  Future<void> _handleMessagesNoticed(
    int chatId, {
    required int accountId,
  }) async {
    _dropPendingNotificationsForChat(chatId, accountId: accountId);
  }

  Future<void> _handleMessageRead(int chatId, {required int accountId}) async {
    _dropPendingNotificationsForChat(chatId, accountId: accountId);
    final notificationService = _notificationService;
    if (notificationService == null) return;
    final db = await _databaseBuilder();
    final chat = await db.getChatByDeltaChatId(chatId, accountId: accountId);
    if (chat == null) return;
    if (chat.unreadCount != _emptyUnreadCount) {
      return;
    }
    await notificationService.dismissMessageNotification(
      threadKey: _notificationThreadKey(chat.jid),
    );
  }

  Future<void> _handleChatDeleted(int chatId, {required int accountId}) async {
    await _flushQueuedNotifications();
    final notificationService = _notificationService;
    if (notificationService == null) return;
    final db = await _databaseBuilder();
    final chat = await db.getChatByDeltaChatId(chatId, accountId: accountId);
    if (chat == null) return;
    await notificationService.dismissMessageNotification(
      threadKey: _notificationThreadKey(chat.jid),
    );
  }

  Future<_EmailNotificationTarget?> _notificationTargetForMessage({
    required XmppDatabase db,
    required int msgId,
    required int accountId,
    int? chatId,
  }) async {
    final stanzaId = _stanzaId(msgId, accountId: accountId);
    final message =
        await db.getMessageByDeltaId(msgId, deltaAccountId: accountId) ??
        await db.getMessageByStanzaID(stanzaId);
    if (message == null) {
      return null;
    }
    if (message.warning == MessageWarning.emailSpamQuarantined) {
      return null;
    }
    final selfJid = _selfSenderJidForAccount(accountId) ?? selfSenderJid;
    final senderBare = bareAddressValue(message.senderJid);
    final selfBare = bareAddressValue(selfJid);
    if (senderBare != null && selfBare != null && senderBare == selfBare) {
      return null;
    }
    var chat = await db.getChat(message.chatJid);
    if (chat == null && chatId != null) {
      chat = await db.getChatByDeltaChatId(chatId, accountId: accountId);
    }
    if (chat?.muted ?? false) {
      return null;
    }
    final conversationTitle = _notificationConversationTitle(
      message: message,
      chat: chat,
    );
    return _EmailNotificationTarget(
      message: message,
      chat: chat,
      threadKey: _notificationThreadKey(chat?.jid ?? message.chatJid),
      conversationTitle: conversationTitle,
      senderName: _notificationSenderName(
        message: message,
        chat: chat,
        conversationTitle: conversationTitle,
      ),
    );
  }

  String _notificationThreadKey(String chatJid) {
    final normalized = chatJid.trim();
    if (normalized.isEmpty) {
      return normalized;
    }
    return _notificationPayloadCodec.encodeChatJid(normalized) ?? normalized;
  }

  String _notificationConversationTitle({
    required Message message,
    required Chat? chat,
  }) {
    final displayName = chat?.displayName.trim();
    if (displayName?.isNotEmpty == true) {
      return displayName!;
    }
    final sender = normalizeAddress(message.senderJid);
    if (sender != null && sender.isNotEmpty) {
      return _displayNameForAddress(sender);
    }
    return message.chatJid.trim();
  }

  String _notificationSenderName({
    required Message message,
    required Chat? chat,
    required String conversationTitle,
  }) {
    final sender = normalizeAddress(message.senderJid);
    if (sender != null && sender.isNotEmpty) {
      final preferredDisplayName = chat?.type == ChatType.chat
          ? chat?.contactDisplayName ?? chat?.title
          : null;
      return _displayNameForAddress(sender, displayName: preferredDisplayName);
    }
    return conversationTitle;
  }

  Future<void> _notifyIncoming({
    required int chatId,
    required int msgId,
    required int accountId,
  }) async {
    final notificationService = _notificationService;
    if (notificationService == null) return;
    try {
      final db = await _databaseBuilder();
      final target = await _notificationTargetForMessage(
        db: db,
        msgId: msgId,
        accountId: accountId,
        chatId: chatId,
      );
      if (target == null) {
        return;
      }
      if (target.message.displayed || !target.message.hasUnreadContent) {
        return;
      }
      final l10n = _l10n;
      final notificationBody = await _notificationBody(
        db: db,
        message: target.message,
        l10n: l10n,
      );
      if (notificationBody == null) {
        return;
      }
      final previewSetting = target.previewSetting;
      final showPreview = NotificationPreviewSetting.resolveOverride(
        previewSetting,
        notificationService.notificationPreviewsEnabled,
      );
      final threadKey = target.threadKey;
      if (threadKey.isEmpty) {
        return;
      }
      await notificationService.sendMessageNotification(
        title: target.title,
        body: notificationBody,
        senderName: target.senderName,
        senderKey: target.senderKey,
        conversationTitle: target.conversationTitle,
        sentAt: target.sentAt,
        isGroupConversation: target.isGroupConversation,
        payload: threadKey,
        threadKey: threadKey,
        showPreviewOverride: showPreview,
        channel: MessageNotificationChannel.email,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to raise notification for email message ${_stanzaId(msgId, accountId: accountId)}',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _handleIncomingReaction({
    required int chatId,
    required int msgId,
    required int accountId,
    String? reaction,
  }) async {
    final notificationService = _notificationService;
    if (notificationService == null) return;
    try {
      final db = await _databaseBuilder();
      final target = await _notificationTargetForMessage(
        db: db,
        msgId: msgId,
        accountId: accountId,
        chatId: chatId,
      );
      if (target == null) {
        return;
      }
      final l10n = _l10n;
      final normalizedReaction = reaction?.trim();
      final body = normalizedReaction == null || normalizedReaction.isEmpty
          ? l10n.notificationReactionFallback
          : l10n.notificationReactionLabel(normalizedReaction);
      final previewSetting = target.previewSetting;
      final showPreview = NotificationPreviewSetting.resolveOverride(
        previewSetting,
        notificationService.notificationPreviewsEnabled,
      );
      final threadKey = target.threadKey;
      if (threadKey.isEmpty) {
        return;
      }
      await notificationService.sendMessageNotification(
        title: target.title,
        body: body,
        senderName: target.senderName,
        senderKey: target.senderKey,
        conversationTitle: target.conversationTitle,
        sentAt: target.sentAt,
        isGroupConversation: target.isGroupConversation,
        payload: threadKey,
        threadKey: threadKey,
        showPreviewOverride: showPreview,
        channel: MessageNotificationChannel.email,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to raise reaction notification for email message ${_stanzaId(msgId, accountId: accountId)}',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _handleIncomingWebxdcNotify({
    required int chatId,
    required int msgId,
    required int accountId,
    String? text,
  }) async {
    final notificationService = _notificationService;
    if (notificationService == null) return;
    try {
      final db = await _databaseBuilder();
      final target = await _notificationTargetForMessage(
        db: db,
        msgId: msgId,
        accountId: accountId,
        chatId: chatId,
      );
      if (target == null) {
        return;
      }
      final l10n = _l10n;
      final normalizedText = text?.trim();
      final body = normalizedText == null || normalizedText.isEmpty
          ? l10n.notificationWebxdcFallback
          : normalizedText;
      final previewSetting = target.previewSetting;
      final showPreview = NotificationPreviewSetting.resolveOverride(
        previewSetting,
        notificationService.notificationPreviewsEnabled,
      );
      final threadKey = target.threadKey;
      if (threadKey.isEmpty) {
        return;
      }
      await notificationService.sendMessageNotification(
        title: target.title,
        body: body,
        senderName: target.senderName,
        senderKey: target.senderKey,
        conversationTitle: target.conversationTitle,
        sentAt: target.sentAt,
        isGroupConversation: target.isGroupConversation,
        payload: threadKey,
        threadKey: threadKey,
        showPreviewOverride: showPreview,
        channel: MessageNotificationChannel.email,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to raise webxdc notification for email message ${_stanzaId(msgId, accountId: accountId)}',
        error,
        stackTrace,
      );
    }
  }

  void _handleCoreError(String? message) {
    final exception = DeltaChatExceptionMapper.fromCoreMessage(
      operation: 'email transport',
      message: message,
    );
    _log.warning('Email transport error (${exception.code}).');
    if (exception.code == DeltaChatErrorCode.auth ||
        exception.code == DeltaChatErrorCode.permission) {
      _authFailureController.add(exception);
    }
    final syncMessage = exception.code == DeltaChatErrorCode.network
        ? _l10n.emailSyncMessageDisconnected
        : _l10n.emailSyncMessageRetrying;
    if (exception.code == DeltaChatErrorCode.network) {
      _updateSyncState(
        EmailSyncState.offline(syncMessage, exception: exception),
        source: _EmailSyncSource.coreError,
      );
      return;
    }
    _updateSyncState(
      EmailSyncState.error(syncMessage, exception: exception),
      source: _EmailSyncSource.coreError,
    );
  }

  void _handleSelfNotInGroup(String? message) {
    final details = message?.trim();
    _updateSyncState(
      EmailSyncState.error(
        details?.isNotEmpty == true
            ? details!
            : _l10n.emailSyncMessageGroupMembershipChanged,
      ),
      source: _EmailSyncSource.selfNotInGroup,
    );
  }

  Future<void> _refreshConnectivityState({
    _EmailSyncSource source = _EmailSyncSource.unknown,
  }) async {
    if (!_acceptsRuntimeWork) {
      return;
    }
    try {
      final connectivity = await _transport.connectivity();
      if (connectivity == null) return;
      _recordConnectivitySample(connectivity: connectivity, source: source);
      if (connectivity >= _connectivityConnectedMin) {
        _cancelConnectivityDowngrade();
        _updateSyncState(const EmailSyncState.ready(), source: source);
        return;
      }
      if (connectivity >= _connectivityWorkingMin) {
        _cancelConnectivityDowngrade();
        if (_syncState.status == EmailSyncStatus.ready) {
          return;
        }
        _updateSyncState(
          EmailSyncState.recovering(_l10n.emailSyncMessageSyncing),
          source: source,
        );
        return;
      }
      if (_syncState.status == EmailSyncStatus.ready) {
        _scheduleConnectivityDowngrade(connectivity);
        return;
      }
      _applyConnectivityState(
        connectivity,
        source: _EmailSyncSource.connectivityApply,
      );
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to refresh email connectivity', error, stackTrace);
    }
  }

  void _scheduleConnectivityDowngrade(int connectivity) {
    if (!_acceptsRuntimeWork) {
      return;
    }
    _pendingConnectivityLevel = connectivity;
    if (_connectivityDowngradeTimer != null) {
      return;
    }
    _connectivityDowngradeTimer = Timer(_connectivityDowngradeGrace, () async {
      _connectivityDowngradeTimer = null;
      final pending = _pendingConnectivityLevel;
      _pendingConnectivityLevel = null;
      if (pending == null) {
        return;
      }
      await _confirmConnectivityDowngrade(pending);
    });
  }

  Future<void> _confirmConnectivityDowngrade(int fallbackConnectivity) async {
    if (!_acceptsRuntimeWork) {
      return;
    }
    try {
      final connectivity = await _transport.connectivity();
      final connectivityLevel = connectivity ?? fallbackConnectivity;
      _recordConnectivitySample(
        connectivity: connectivityLevel,
        source: _EmailSyncSource.connectivityConfirm,
      );
      if (connectivityLevel >= _connectivityConnectedMin) {
        return;
      }
      if (connectivityLevel >= _connectivityWorkingMin) {
        return;
      }
      _applyConnectivityState(
        connectivityLevel,
        source: _EmailSyncSource.connectivityConfirm,
      );
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to confirm email connectivity', error, stackTrace);
    }
  }

  void _cancelConnectivityDowngrade() {
    _pendingConnectivityLevel = null;
    _connectivityDowngradeTimer?.cancel();
    _connectivityDowngradeTimer = null;
  }

  void _applyConnectivityState(
    int connectivity, {
    required _EmailSyncSource source,
  }) {
    if (connectivity >= _connectivityConnectingMin) {
      _updateSyncState(
        EmailSyncState.recovering(_l10n.emailSyncMessageConnecting),
        source: source,
      );
      return;
    }
    _updateSyncState(
      EmailSyncState.offline(_l10n.emailSyncMessageDisconnected),
      source: source,
    );
  }

  void _recordConnectivitySample({
    required int connectivity,
    required _EmailSyncSource source,
  }) {
    _lastConnectivityValue = connectivity;
    _logConnectivitySample(connectivity: connectivity, source: source);
  }

  void _logConnectivitySample({
    required int connectivity,
    required _EmailSyncSource source,
  }) {
    final now = DateTime.timestamp();
    final lastLoggedAt = _lastConnectivityLoggedAt;
    final shouldLog =
        _lastLoggedConnectivityValue == null ||
        _lastLoggedConnectivityValue != connectivity ||
        lastLoggedAt == null ||
        now.difference(lastLoggedAt) > _connectivityLogInterval;
    if (!shouldLog) {
      return;
    }
    _lastLoggedConnectivityValue = connectivity;
    _lastConnectivityLoggedAt = now;
    _log.fine(
      '$_emailConnectivityLogPrefix: '
      '$_emailLogSourceLabel=${source.logLabel}, '
      '$_emailLogValueLabel=$connectivity, '
      '$_emailLogStateLabel=${_syncState.status.name}',
    );
  }

  void _logSyncStateTransition({
    required EmailSyncState previous,
    required EmailSyncState next,
    required _EmailSyncSource source,
  }) {
    final connectivity = _lastConnectivityValue;
    final connectivityLabel = connectivity == null
        ? _emailLogUnknownValue
        : '$connectivity';
    final hasMessage = next.message?.isNotEmpty == true;
    _log.fine(
      '$_emailSyncLogPrefix: '
      '${previous.status.name} -> ${next.status.name}, '
      '$_emailLogSourceLabel=${source.logLabel}, '
      '$_emailLogConnectivityLabel=$connectivityLabel, '
      '$_emailLogHasMessageLabel=$hasMessage',
    );
  }

  Future<void> _handleBackgroundFetchDone() async {
    if (!_acceptsRuntimeWork) {
      return;
    }
    if (_syncState.status == EmailSyncStatus.ready) {
      return;
    }
    await _refreshConnectivityState(
      source: _EmailSyncSource.backgroundFetchDone,
    );
  }

  Future<void> _handleChannelOverflow() async {
    await _channelOverflowRecoveryQueue.run(() async {
      _updateSyncState(
        EmailSyncState.recovering(_l10n.emailSyncMessageRefreshing),
        source: _EmailSyncSource.channelOverflow,
      );
      try {
        final success = await _transport.performBackgroundFetch(
          _foregroundFetchTimeout,
        );
        if (!success) {
          await _transport.notifyNetworkAvailable();
        }
        await refreshChatlistFromCore();
      } on Exception catch (error, stackTrace) {
        _log.warning(
          'Failed to recover from Delta channel overflow',
          error,
          stackTrace,
        );
        _updateSyncState(
          EmailSyncState.error(_l10n.emailSyncMessageRefreshFailed),
          source: _EmailSyncSource.channelOverflowFailure,
        );
      } finally {
        await _refreshConnectivityState(
          source: _EmailSyncSource.channelOverflowComplete,
        );
      }
    });
  }

  void _updateSyncState(
    EmailSyncState next, {
    _EmailSyncSource source = _EmailSyncSource.unknown,
  }) {
    if (_syncState == next) return;
    final previous = _syncState;
    _syncState = next;
    _syncStateController.add(next);
    if (previous.status != EmailSyncStatus.ready &&
        next.status == EmailSyncStatus.ready) {
      _readyTransitionController.add(null);
    }
    _logSyncStateTransition(previous: previous, next: next, source: source);
  }

  void _detachTransportListener() {
    if (!_listenerAttached) return;
    _transport.removeEventListener(_eventListener);
    _listenerAttached = false;
  }

  void _clearNotificationQueue() {
    _notificationQueue.clear();
  }

  bool _isForegroundKeepaliveOpCurrent(int operationId) =>
      operationId == _foregroundKeepaliveOperationId;

  Future<void> _applyPendingPushToken() async {
    final token = _pendingPushToken;
    if (token == null || token.isEmpty) return;
    await _transport.registerPushToken(token);
  }

  Future<void> _bootstrapActiveAccountIfNeeded() async {
    if (!_acceptsRuntimeWork) {
      return;
    }
    final scope = _activeCredentialScope;
    final prefix = _databasePrefix;
    if (scope == null || prefix == null) {
      return;
    }
    await _bootstrapFromCoreIfNeeded(scope: scope, databasePrefix: prefix);
  }

  Future<void> _bootstrapFromCoreIfNeeded({
    required String scope,
    required String databasePrefix,
  }) async {
    final bootstrapKey = _bootstrapKeyFor(
      scope: scope,
      databasePrefix: databasePrefix,
    );
    final bootstrapped =
        (await _credentialStore.read(key: bootstrapKey)) == true.toString();
    if (bootstrapped) {
      return;
    }
    final existing = _bootstrapFutureForScope(scope);
    if (existing != null) {
      await existing;
      return;
    }
    final operationId = _nextBootstrapOperationIdForScope(scope);
    final future = _runBootstrapFromCore(
      scope: scope,
      operationId: operationId,
      bootstrapKey: bootstrapKey,
    );
    _setBootstrapFutureForScope(scope, future);
    try {
      await future;
    } finally {
      if (identical(_bootstrapFutureForScope(scope), future)) {
        _setBootstrapFutureForScope(scope, null);
      }
    }
  }

  Future<void> _runBootstrapFromCore({
    required String scope,
    required int operationId,
    required RegisteredCredentialKey bootstrapKey,
  }) async {
    if (!_acceptsRuntimeWork) {
      return;
    }
    if (_syncState.status == EmailSyncStatus.ready) {
      _updateSyncState(
        EmailSyncState.recovering(_l10n.emailSyncMessageHistorySyncing),
        source: _EmailSyncSource.bootstrapStart,
      );
    }
    try {
      await _transport.bootstrapFromCore();
      if (operationId != _bootstrapOperationIdForScope(scope) ||
          !_acceptsRuntimeWork) {
        return;
      }
      await _credentialStore.write(key: bootstrapKey, value: true.toString());
      if (operationId != _bootstrapOperationIdForScope(scope) ||
          !_acceptsRuntimeWork) {
        return;
      }
      await _refreshConnectivityState(
        source: _EmailSyncSource.bootstrapComplete,
      );
    } on Exception catch (error, stackTrace) {
      if (operationId != _bootstrapOperationIdForScope(scope)) {
        return;
      }
      _log.warning('Email history bootstrap failed', error, stackTrace);
      if (_syncState.status == EmailSyncStatus.ready ||
          _syncState.status == EmailSyncStatus.recovering) {
        _updateSyncState(
          EmailSyncState.recovering(_l10n.emailSyncMessageRetrying),
          source: _EmailSyncSource.bootstrapRetry,
        );
      }
    }
  }

  Future<void> _stopForegroundKeepalive() async {
    _foregroundKeepaliveOperationId++;
    if (!_foregroundKeepaliveEnabled &&
        !_foregroundKeepaliveListenerAttached &&
        !_foregroundKeepaliveServiceAcquired) {
      return;
    }
    _foregroundKeepaliveEnabled = false;
    _foregroundKeepaliveQueue.reset();
    final bridge = _foregroundBridge;
    if (bridge != null && _foregroundKeepaliveServiceAcquired) {
      try {
        await bridge.send([emailKeepalivePrefix, emailKeepaliveStopCommand]);
      } on Exception catch (error, stackTrace) {
        _log.finer('Failed to stop email keepalive', error, stackTrace);
      }
    }
    await _releaseForegroundKeepaliveResources();
  }

  void _attachForegroundKeepaliveListener() {
    if (_foregroundKeepaliveListenerAttached) {
      return;
    }
    final bridge = _foregroundBridge;
    if (bridge == null) {
      return;
    }
    bridge.registerListener(
      foregroundClientEmailKeepalive,
      _handleForegroundTaskMessage,
    );
    _foregroundKeepaliveListenerAttached = true;
  }

  Future<void> _releaseForegroundKeepaliveResources() async {
    final bridge = _foregroundBridge;
    if (bridge == null) {
      _foregroundKeepaliveListenerAttached = false;
      _foregroundKeepaliveServiceAcquired = false;
      return;
    }
    if (_foregroundKeepaliveServiceAcquired) {
      await bridge.release(foregroundClientEmailKeepalive);
      _foregroundKeepaliveServiceAcquired = false;
    }
    if (_foregroundKeepaliveListenerAttached) {
      bridge.unregisterListener(foregroundClientEmailKeepalive);
      _foregroundKeepaliveListenerAttached = false;
    }
  }

  Future<void> _handleForegroundTaskMessage(String data) async {
    if (!data.startsWith('$emailKeepaliveTickPrefix$join')) {
      return;
    }
    if (!_foregroundKeepaliveEnabled) {
      return;
    }
    _enqueueForegroundKeepaliveTick();
  }

  Future<void> _foregroundKeepaliveTick() async {
    if (!_foregroundKeepaliveEnabled || !_acceptsRuntimeWork) {
      return;
    }
    try {
      await _transport.notifyNetworkAvailable();
      await _refreshConnectivityState(
        source: _EmailSyncSource.connectivityConfirm,
      );
      await _bootstrapActiveAccountIfNeeded();
      final fetched = await _performBackgroundFetchIfIdle(
        timeout: _foregroundFetchTimeout,
      );
      if (fetched) {
        await refreshChatlistFromCore();
        await _refreshConnectivityState(
          source: _EmailSyncSource.backgroundFetchDone,
        );
      }
    } on Exception catch (error, stackTrace) {
      _log.finer('Foreground keepalive tick failed', error, stackTrace);
    }
  }

  void _enqueueForegroundKeepaliveTick() {
    _foregroundKeepaliveQueue.run(() async {
      if (!_foregroundKeepaliveEnabled) {
        return;
      }
      await _foregroundKeepaliveTick();
    });
  }

  void _startImapSyncLoop() {
    if (!hasActiveSession) {
      return;
    }
    if (_transport.isIoRunning) {
      return;
    }
    if (_imapSyncLoopToken != null) {
      return;
    }
    final token = Object();
    _imapSyncLoopToken = token;
    _scheduleNextImapSync(token);
  }

  void _stopImapSyncLoop() {
    _imapSyncLoopToken = null;
    _imapSyncTimer?.cancel();
    _imapSyncTimer = null;
  }

  void _scheduleNextImapSync(Object token) {
    if (_imapSyncLoopToken != token ||
        _foregroundKeepaliveEnabled ||
        !hasActiveSession) {
      return;
    }
    final interval = _imapSyncInterval();
    _imapSyncTimer?.cancel();
    _imapSyncTimer = Timer(interval, () async {
      await _runImapSyncTick(token);
    });
  }

  Future<void> _runImapSyncTick(Object token) async {
    if (_imapSyncLoopToken != token || _foregroundKeepaliveEnabled) {
      return;
    }
    if (!hasActiveSession) {
      _stopImapSyncLoop();
      return;
    }
    if (_transport.isIoRunning) {
      _scheduleNextImapSync(token);
      return;
    }
    await _enqueueImapSync(token);
    _scheduleNextImapSync(token);
  }

  Future<void> _enqueueImapSync(Object token) async {
    await _imapSyncQueue.run(() async {
      if (_imapSyncLoopToken != token || _foregroundKeepaliveEnabled) {
        return;
      }
      await _refreshImapCapabilities();
      await _performBackgroundFetchIfIdle(timeout: _imapSyncFetchTimeout);
      await refreshChatlistFromCore();
    });
  }

  Duration _imapSyncInterval() {
    final capabilities = _imapCapabilities;
    if (!capabilities.idleSupported) {
      return _imapPollIntervalNoIdle;
    }
    if (capabilities.connectionLimit <= _imapConnectionLimitSingle) {
      return _imapSentPollIntervalSingleConnection;
    }
    return capabilities.idleCutoff;
  }

  void _resetImapCapabilities() {
    _imapCapabilities = const EmailImapCapabilities(
      idleSupported: false,
      connectionLimit: _imapConnectionLimitSingle,
      idleCutoff: _imapIdleKeepaliveInterval,
    );
    _imapCapabilitiesCheckedAt = null;
    _imapCapabilitiesResolved = false;
  }

  Future<void> _refreshImapCapabilities({bool force = false}) async {
    final now = DateTime.timestamp();
    final lastChecked = _imapCapabilitiesCheckedAt;
    final shouldReuse =
        !force &&
        _imapCapabilitiesResolved &&
        lastChecked != null &&
        now.difference(lastChecked) < _imapCapabilityRefreshInterval;
    if (shouldReuse) {
      return;
    }
    _imapCapabilities = await _resolveImapCapabilities();
    _imapCapabilitiesCheckedAt = now;
    _imapCapabilitiesResolved = true;
  }

  Future<EmailImapCapabilities> _resolveImapCapabilities() async {
    final idleFlag = await _readImapConfigBool(_imapIdleConfigKey);
    final idleTimeout = await _readImapConfigInt(_imapIdleTimeoutConfigKey);
    final maxConnections = await _readImapConfigInt(
      _imapMaxConnectionsConfigKey,
    );
    final accountsActive =
        _transport.accountsActive || _transport.accountsSupported;
    final defaultLimit = accountsActive
        ? _imapConnectionLimitMulti
        : _imapConnectionLimitSingle;
    final idleSupported = idleFlag ?? accountsActive;
    final connectionLimit = _normalizeConnectionLimit(
      maxConnections ?? defaultLimit,
    );
    final idleCutoff = idleTimeout == null
        ? _imapIdleKeepaliveInterval
        : Duration(seconds: idleTimeout);
    return EmailImapCapabilities(
      idleSupported: idleSupported,
      connectionLimit: connectionLimit,
      idleCutoff: idleCutoff,
    );
  }

  Future<bool?> _readImapConfigBool(String key) async {
    final raw = await _transport.getCoreConfig(key);
    if (raw == null) {
      return null;
    }
    final normalized = raw.trim().toLowerCase();
    if (_imapConfigBoolTrueValues.contains(normalized)) {
      return true;
    }
    if (_imapConfigBoolFalseValues.contains(normalized)) {
      return false;
    }
    return null;
  }

  Future<int?> _readImapConfigInt(String key) async {
    final raw = await _transport.getCoreConfig(key);
    if (raw == null) {
      return null;
    }
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed < _imapConnectionLimitSingle) {
      return null;
    }
    return parsed;
  }

  int _normalizeConnectionLimit(int value) {
    if (value < _imapConnectionLimitSingle) {
      return _imapConnectionLimitSingle;
    }
    return value;
  }

  Future<void> _runReconnectCatchUp() async {
    if (!_acceptsRuntimeWork) {
      return;
    }
    await _reconnectCatchUpQueue.run(() async {
      if (!_acceptsRuntimeWork) {
        return;
      }
      await _refreshImapCapabilities();
      if (!_acceptsRuntimeWork) {
        return;
      }
      await _performBackgroundFetchIfIdle(timeout: _imapSyncFetchTimeout);
      if (!_acceptsRuntimeWork) {
        return;
      }
      await refreshChatlistFromCore();
      if (!_acceptsRuntimeWork) {
        return;
      }
      await _refreshConnectivityState(
        source: _EmailSyncSource.reconnectCatchUp,
      );
    });
  }

  Future<void> _scheduleReconnectRestartIfOffline() async {
    await _reconnectRestartQueue.run(() async {
      if (!_acceptsRuntimeWork) {
        return;
      }
      try {
        await Future.delayed(_reconnectRestartDelay);
        if (!_acceptsRuntimeWork) {
          return;
        }
        final connectivity = await _transport.connectivity();
        if (connectivity == null ||
            connectivity >= _connectivityConnectingMin) {
          return;
        }
        _log.warning(
          'Email transport still offline after network available; restarting.',
        );
        await stop();
        await start();
        await _transport.notifyNetworkAvailable();
        await _bootstrapActiveAccountIfNeeded();
        await _runReconnectCatchUp();
      } on Exception catch (error, stackTrace) {
        _log.warning('Email transport restart failed', error, stackTrace);
      } finally {
        if (_acceptsRuntimeWork) {
          await _refreshConnectivityState(
            source: _EmailSyncSource.reconnectRestart,
          );
        }
      }
    });
  }

  Future<void> _ensureReady() async {
    if (kEnableDemoChats) {
      return;
    }
    if (_databasePrefix == null || _databasePassphrase == null) {
      throw StateError('Call ensureProvisioned before using EmailService.');
    }
    if (_blocksRuntimeReentry) {
      throw const EmailServiceStoppingException();
    }
    if (!_acceptsRuntimeWork) {
      await start();
    }
  }

  Future<bool> _ensureBackgroundSyncReady() async {
    if (_blocksRuntimeReentry || !hasActiveSession) {
      return false;
    }
    await ensureEventChannelActive();
    return _acceptsRuntimeWork && !_blocksRuntimeReentry;
  }

  Future<int> _sendDemoEmailMessage({
    required Chat chat,
    required String body,
    String? subject,
    String? htmlBody,
    bool forwarded = false,
    String? forwardedFromJid,
    String? quotedStanzaId,
  }) async {
    final normalizedSubject = _normalizeSubject(subject);
    final normalizedHtml = HtmlContentCodec.normalizeHtml(htmlBody);
    final trimmedBody = body.trim();
    final effectiveBody = trimmedBody.isNotEmpty
        ? trimmedBody
        : (normalizedHtml == null
              ? ''
              : HtmlContentCodec.toPlainText(normalizedHtml));
    const generator = Uuid();
    final stanzaId = 'demo-email-${generator.v4()}';
    final forwardedFromNormalized = forwardedFromJid?.trim();
    final db = await _databaseBuilder();
    final timestamp = await _resolveDemoTimestampForChat(
      db: db,
      jid: chat.jid,
      candidate: demoNow(),
    );
    final message = Message(
      stanzaID: stanzaId,
      originID: stanzaId,
      senderJid: kDemoSelfJid,
      chatJid: chat.jid,
      body: effectiveBody,
      htmlBody: normalizedHtml,
      subject: normalizedSubject,
      quoting: quotedStanzaId,
      timestamp: timestamp,
      encryptionProtocol: EncryptionProtocol.none,
      acked: false,
      received: false,
      displayed: false,
      pseudoMessageData: forwarded
          ? <String, dynamic>{
              'forwarded': true,
              if (forwardedFromNormalized != null &&
                  forwardedFromNormalized.isNotEmpty)
                'forwardedFromJid': forwardedFromNormalized,
            }
          : null,
    );
    await db.saveMessage(message, selfJid: kDemoSelfJid);
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 500),
        () => db.markMessageAcked(stanzaId),
      ),
    );
    return timestamp.millisecondsSinceEpoch;
  }

  Future<int> _sendDemoEmailAttachment({
    required Chat chat,
    required EmailAttachment attachment,
    String? subject,
    String? htmlCaption,
    bool forwarded = false,
    String? forwardedFromJid,
    String? quotedStanzaId,
  }) async {
    final normalizedSubject = _normalizeSubject(subject);
    final normalizedHtml = HtmlContentCodec.normalizeHtml(htmlCaption);
    var captionText = attachment.caption?.trim() ?? '';
    if (captionText.isEmpty && normalizedHtml != null) {
      captionText = HtmlContentCodec.toPlainText(normalizedHtml);
    }
    final captionBody = _composeSubjectEnvelope(
      subject: normalizedSubject,
      body: captionText,
    );
    const generator = Uuid();
    final metadataId = attachment.metadataId ?? generator.v4();
    final stanzaId = 'demo-email-${generator.v4()}';
    final db = await _databaseBuilder();
    final timestamp = await _resolveDemoTimestampForChat(
      db: db,
      jid: chat.jid,
      candidate: demoNow(),
    );
    final metadata = FileMetadataData(
      id: metadataId,
      filename: attachment.fileName,
      path: attachment.path,
      mimeType: attachment.mimeType,
      sizeBytes: attachment.sizeBytes,
      width: attachment.width,
      height: attachment.height,
      sourceUrls: [Uri.file(attachment.path).toString()],
    );
    final forwardedFromNormalized = forwardedFromJid?.trim();
    final message = Message(
      stanzaID: stanzaId,
      originID: stanzaId,
      senderJid: kDemoSelfJid,
      chatJid: chat.jid,
      body: captionBody,
      htmlBody: normalizedHtml,
      subject: normalizedSubject,
      quoting: quotedStanzaId,
      timestamp: timestamp,
      encryptionProtocol: EncryptionProtocol.none,
      acked: false,
      received: false,
      displayed: false,
      fileMetadataID: metadataId,
      pseudoMessageData: forwarded
          ? <String, dynamic>{
              'forwarded': true,
              if (forwardedFromNormalized != null &&
                  forwardedFromNormalized.isNotEmpty)
                'forwardedFromJid': forwardedFromNormalized,
            }
          : null,
    );
    await db.saveFileMetadata(metadata);
    await db.saveMessage(message, selfJid: kDemoSelfJid);
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 500),
        () => db.markMessageAcked(stanzaId),
      ),
    );
    return timestamp.millisecondsSinceEpoch;
  }

  Future<DateTime> _resolveDemoTimestampForChat({
    required XmppDatabase db,
    required String jid,
    required DateTime candidate,
  }) async {
    final messages = await db.getChatMessages(jid, start: 0, end: 1);
    final DateTime? lastTimestamp = messages.isNotEmpty
        ? messages.first.timestamp
        : null;
    if (lastTimestamp == null || candidate.isAfter(lastTimestamp)) {
      return candidate;
    }
    return lastTimestamp.add(const Duration(minutes: 1));
  }

  Future<String?> _notificationBody({
    required XmppDatabase db,
    required Message message,
    required AppLocalizations l10n,
  }) async {
    final trimmed = message.body?.trim();
    if (trimmed?.isNotEmpty == true) {
      return trimmed;
    }
    final messageId = message.id;
    if (messageId != null && messageId.isNotEmpty) {
      var attachments = await db.getMessageAttachments(messageId);
      if (attachments.isNotEmpty) {
        final transportGroupId = attachments.first.transportGroupId?.trim();
        if (transportGroupId != null && transportGroupId.isNotEmpty) {
          attachments = await db.getMessageAttachmentsForGroup(
            transportGroupId,
          );
        }
        final ordered = attachments.whereType<MessageAttachmentData>().toList(
          growable: false,
        )..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final metadata = await db.getFileMetadata(ordered.first.fileMetadataId);
        if (metadata == null) {
          return l10n.notificationAttachmentLabel;
        }
        final filename = metadata.filename.trim();
        return filename.isEmpty
            ? l10n.notificationAttachmentLabel
            : l10n.notificationAttachmentLabelWithName(filename);
      }
    }
    final metadataId = message.fileMetadataID;
    if (metadataId == null) {
      return null;
    }
    final metadata = await db.getFileMetadata(metadataId);
    if (metadata == null) {
      return l10n.notificationAttachmentLabel;
    }
    final filename = metadata.filename.trim();
    return filename.isEmpty
        ? l10n.notificationAttachmentLabel
        : l10n.notificationAttachmentLabelWithName(filename);
  }

  String? get selfSenderJid => _transport.selfJid;

  String? _selfSenderJidForAccount(int accountId) =>
      _transport.selfJidForAccount(accountId);

  Future<Map<String, Chat>> _resolveFanOutTargets(List<Contact> targets) async {
    final chatByJid = <String, Chat>{};
    final pending = <String, Future<Chat>>{};
    for (final target in targets) {
      if (target.chat != null) {
        pending.putIfAbsent(
          target.key,
          () => ensureChatForEmailChat(target.chat!),
        );
        continue;
      }
      final address = target.address;
      if (address == null || address.isEmpty) {
        continue;
      }
      pending.putIfAbsent(
        target.key,
        () => ensureChatForAddress(
          address: address,
          displayName: target.displayName,
        ),
      );
    }
    final entries = pending.entries.toList(growable: false);
    for (var index = 0; index < entries.length; index += _fanOutConcurrentOps) {
      final chunk = entries.skip(index).take(_fanOutConcurrentOps).toList();
      final results = await Future.wait(
        chunk.map((entry) async => MapEntry(entry.key, await entry.value)),
      );
      for (final result in results) {
        final chat = result.value;
        if (chatByJid.containsKey(chat.jid)) {
          continue;
        }
        chatByJid.putIfAbsent(chat.jid, () => chat);
      }
    }
    return chatByJid;
  }

  Future<List<MessageParticipantData>> _shareParticipants({
    required String shareId,
    required Iterable<Chat> chats,
    Iterable<MessageParticipantData> existingParticipants = const [],
    String? senderJid,
  }) async {
    final participants = <String, MessageParticipantData>{};
    for (final participant in existingParticipants) {
      participants[participant.contactJid] = participant;
    }
    final senderParticipantJid = _senderParticipantJid(senderJid: senderJid);
    if (senderParticipantJid != null && senderParticipantJid.isNotEmpty) {
      participants[senderParticipantJid] = MessageParticipantData(
        shareId: shareId,
        contactJid: senderParticipantJid,
        role: MessageParticipantRole.sender,
      );
    }
    for (final chat in chats) {
      participants.putIfAbsent(
        chat.jid,
        () => MessageParticipantData(
          shareId: shareId,
          contactJid: chat.jid,
          role: MessageParticipantRole.recipient,
        ),
      );
    }
    return participants.values.toList();
  }

  String? _senderParticipantJid({String? senderJid}) {
    final normalized = normalizeAddress(senderJid);
    if (normalized != null) return normalized;
    return selfSenderJid ?? deltaSelfJid;
  }

  Future<Chat> _waitForChat(int chatId, {int? accountId}) async {
    final db = await _databaseBuilder();

    final existing = await db.getChatByDeltaChatId(
      chatId,
      accountId: accountId,
    );
    if (existing != null) {
      return existing;
    }

    try {
      final chat = await db
          .watchChatByDeltaChatId(chatId, accountId: accountId)
          .where((chat) => chat != null)
          .cast<Chat>()
          .first
          .timeout(const Duration(seconds: 10));
      return chat;
    } on TimeoutException {
      throw const EmailServiceChatPersistTimeoutException();
    }
  }

  String? _preferredAddressFromJid(String jid) {
    final normalized = normalizedAddressKey(jid);
    if (normalized == null) {
      return null;
    }
    final local = addressLocalPart(normalized);
    final domain = addressDomainPart(normalized);
    if (local == null || domain == null) {
      return null;
    }
    if (local.isEmpty || domain.isEmpty) {
      return null;
    }
    return normalized;
  }

  static Map<String, String> _defaultConnectionConfig(
    String address,
    EndpointConfig config,
  ) {
    final configValues = <String, String>{
      _showEmailsConfigKey: _showEmailsAllValue,
    };
    final normalizedAddress = address.trim();
    final localPart =
        _localPartFromAddress(normalizedAddress) ?? normalizedAddress;
    final smtpHost = config.smtpHost?.trim();
    final imapHost = config.imapHost?.trim();
    final fallbackHost = _connectionHostFor(normalizedAddress, config);
    final sendHost = (smtpHost != null && smtpHost.isNotEmpty)
        ? smtpHost
        : fallbackHost;
    final mailHost = (imapHost != null && imapHost.isNotEmpty)
        ? imapHost
        : fallbackHost;
    final sendPortValue = config.smtpPort > _portUnsetValue
        ? config.smtpPort
        : EndpointConfig.defaultSmtpPort;
    final sendSecurityMode = _securityModeForPort(
      port: sendPortValue,
      implicitTlsPort: EndpointConfig.defaultSmtpPort,
    );
    configValues
      ..[_sendServerConfigKey] = sendHost
      ..[_sendPortConfigKey] = sendPortValue.toString()
      ..[_sendSecurityConfigKey] = sendSecurityMode
      ..[_sendUserConfigKey] = localPart;
    final mailPortValue = config.imapPort > _portUnsetValue
        ? config.imapPort
        : EndpointConfig.defaultImapPort;
    final mailSecurityMode = _securityModeForPort(
      port: mailPortValue,
      implicitTlsPort: EndpointConfig.defaultImapPort,
    );
    configValues
      ..[_mailServerConfigKey] = mailHost
      ..[_mailPortConfigKey] = mailPortValue.toString()
      ..[_mailSecurityConfigKey] = mailSecurityMode
      ..[_mailUserConfigKey] = localPart;
    return configValues;
  }

  static String _securityModeForPort({
    required int port,
    required int implicitTlsPort,
  }) => port == implicitTlsPort ? _securityModeSsl : _securityModeStartTls;

  static String _connectionHostFor(String address, EndpointConfig config) {
    final customHost = config.smtpHost?.trim();
    if (customHost != null && customHost.isNotEmpty) {
      return customHost;
    }
    final domain = _domainFromAddress(address) ?? config.domain;
    if (domain.isEmpty) {
      throw const EmailProvisioningConfigurationException();
    }
    return domain;
  }

  static String? _domainFromAddress(String address) {
    final domain = addressDomainPart(address)?.toLowerCase();
    return domain == null || domain.isEmpty ? null : domain;
  }

  static String? _localPartFromAddress(String address) {
    final normalized = normalizeAddress(address);
    if (normalized == null) return null;
    final localPart = addressLocalPart(normalized);
    if (localPart != null) {
      return localPart;
    }
    if (addressDomainPart(normalized) != null) {
      return null;
    }
    return normalized;
  }

  static String _mdnsConfigValue(bool enabled) =>
      enabled ? _mdnsEnabledValue : _mdnsDisabledValue;

  Future<void> _applyEmailReadReceiptPreference({
    Iterable<int>? accountIds,
    bool? enabled,
  }) async {
    if (!hasActiveSession) {
      return;
    }
    final resolvedAccountIds =
        accountIds?.toList(growable: false) ?? await _transport.accountIds();
    if (resolvedAccountIds.isEmpty) {
      return;
    }
    final value = _mdnsConfigValue(enabled ?? _emailReadReceiptsEnabled);
    for (final accountId in resolvedAccountIds) {
      await _transport.setCoreConfig(
        key: _mdnsEnabledConfigKey,
        value: value,
        accountId: accountId,
      );
    }
  }

  String _normalizeLinkedAccountAddress(String address) =>
      normalizeEmailAddress(address);

  bool _isSyntheticEmailChatAddress(String address) {
    if (address.isDeltaPlaceholderJid) {
      return true;
    }
    final String? localPart = addressLocalPart(address)?.toLowerCase();
    final String? domain = addressDomainPart(address)?.toLowerCase();
    if (localPart == null || domain == null) {
      return false;
    }
    if (domain != deltaDomain && domain != deltaUserDomain) {
      return false;
    }
    return RegExp(r'^(chat|dc)-\d+$').hasMatch(localPart);
  }

  String? _recipientAddressForChat(Chat chat) {
    final Iterable<String?> candidates = <String?>[
      chat.emailAddress,
      chat.contactJid,
      chat.jid,
    ];
    for (final candidate in candidates) {
      final String? bareAddress = bareAddressOrNull(candidate);
      if (bareAddress == null) {
        continue;
      }
      final String normalized = normalizeEmailAddress(bareAddress);
      if (_isSyntheticEmailChatAddress(normalized)) {
        continue;
      }
      return normalized;
    }
    return null;
  }

  String? _storedRealEmailAddress(Chat chat) {
    final String? bareAddress = bareAddressOrNull(chat.emailAddress);
    if (bareAddress == null) {
      return null;
    }
    final String normalized = normalizeEmailAddress(bareAddress);
    if (_isSyntheticEmailChatAddress(normalized)) {
      return null;
    }
    return normalized;
  }

  Future<Chat> _storedEmailChatForAccount({
    required Chat chat,
    required int deltaAccountId,
  }) async {
    final db = await _databaseBuilder();
    final String? recipientAddress = chat.type == ChatType.chat
        ? _recipientAddressForChat(chat)
        : null;
    if (recipientAddress != null &&
        !sameBareAddress(recipientAddress, chat.jid)) {
      final Chat? storedByAddress = await db.getChat(recipientAddress);
      if (storedByAddress != null) {
        return storedByAddress;
      }
    }
    final int? deltaChatId = chat.deltaChatId;
    if (deltaChatId != null) {
      final Chat? storedByDelta = await db.getChatByDeltaChatId(
        deltaChatId,
        accountId: deltaAccountId,
      );
      if (storedByDelta != null) {
        return storedByDelta;
      }
    }
    final Chat? stored = await db.getChat(chat.jid);
    return stored ?? chat;
  }

  String? _normalizedLocalPartFromAddress(String address) {
    final String normalized = normalizeEmailAddress(address);
    if (normalized.isEmpty) {
      return null;
    }
    final int separatorIndex = normalized.indexOf(_emailAddressSeparator);
    if (separatorIndex == _emailAddressSeparatorMissingIndex ||
        separatorIndex < _emailLocalPartMinLength) {
      return null;
    }
    return normalized.substring(_emailLocalPartStartIndex, separatorIndex);
  }

  String? _normalizeDisplayName(String? displayName) {
    if (displayName == null) {
      return null;
    }
    final String trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _displayNameForAddress(String address, {String? displayName}) {
    final String? normalizedDisplayName = _normalizeDisplayName(displayName);
    if (normalizedDisplayName != null) {
      return normalizedDisplayName;
    }
    final String? localPart = _normalizedLocalPartFromAddress(address);
    if (localPart != null) {
      return localPart;
    }
    return address;
  }

  RegisteredCredentialKey _addressKeyForScope(String scope) {
    return _credentialSession.scopeState(scope).addressKey;
  }

  RegisteredCredentialKey _passwordKeyForScope(String scope) {
    return _credentialSession.scopeState(scope).passwordKey;
  }

  RegisteredCredentialKey _provisionedKeyForScope(String scope) {
    return _credentialSession.scopeState(scope).provisionedKey;
  }

  RegisteredCredentialKey _connectionOverrideKeyForScope(String scope) {
    return _credentialSession.scopeState(scope).connectionOverrideKey;
  }

  RegisteredCredentialKey _bootstrapKeyFor({
    required String scope,
    required String databasePrefix,
  }) {
    return _credentialSession.scopeState(scope).bootstrapKeyFor(databasePrefix);
  }

  String _scopeForJid(String jid) => normalizedAddressKeyOrEmpty(jid);

  String? _scopeForOptionalJid(String? jid) =>
      jid == null ? _activeCredentialScope : _scopeForJid(jid);

  String _requireActiveScope() {
    final scope = _activeCredentialScope;
    if (scope != null) {
      return scope;
    }
    throw StateError('Call ensureProvisioned before using EmailService.');
  }

  Future<void> _updateChatEmailFromAddress(Chat chat, String? address) async {
    if (chat.emailFromAddress == address) {
      return;
    }
    final db = await _databaseBuilder();
    await db.updateChat(chat.copyWith(emailFromAddress: address));
  }

  Future<void> _updateActiveChatDeltaReference({
    required Chat chat,
    required int deltaAccountId,
    required int deltaChatId,
    required String emailAddress,
  }) async {
    if (deltaAccountId != _transport.activeAccountId) {
      return;
    }
    final String resolvedEmailAddress =
        _storedRealEmailAddress(chat) ?? emailAddress;
    if (chat.deltaChatId == deltaChatId &&
        chat.emailAddress == resolvedEmailAddress) {
      return;
    }
    final db = await _databaseBuilder();
    await db.updateChat(
      chat.copyWith(
        deltaChatId: deltaChatId,
        emailAddress: resolvedEmailAddress,
      ),
    );
  }

  Future<void> _hydrateAccountAddress({
    required String address,
    required int deltaAccountId,
  }) async {
    final normalizedAddress = _normalizeLinkedAccountAddress(address);
    if (normalizedAddress.isEmpty || normalizedAddress.isDeltaPlaceholderJid) {
      return;
    }
    _transport.hydrateAccountAddress(
      address: normalizedAddress,
      accountId: deltaAccountId,
    );
    final db = await _databaseBuilder();
    await db.replaceDeltaPlaceholderSelfJids(
      deltaAccountId: deltaAccountId,
      resolvedAddress: normalizedAddress,
      placeholderJids: deltaPlaceholderJids,
    );
    await db.removeDeltaPlaceholderDuplicates(
      deltaAccountId: deltaAccountId,
      placeholderJids: deltaPlaceholderJids,
    );
  }

  Future<_EmailAccountBinding> _accountBindingForScope({
    required String scope,
    String? fromAddress,
  }) async {
    var normalizedAddress = _normalizeLinkedAccountAddress(fromAddress ?? '');
    if (normalizedAddress.isEmpty) {
      normalizedAddress = _normalizeLinkedAccountAddress(
        _activeAccount?.address ?? '',
      );
    }
    if (normalizedAddress.isEmpty) {
      final String? storedAddress = await _credentialStore.read(
        key: _addressKeyForScope(scope),
      );
      normalizedAddress = _normalizeLinkedAccountAddress(storedAddress ?? '');
    }
    if (normalizedAddress.isEmpty) {
      throw const EmailProvisioningMissingAddressException();
    }
    final deltaAccountId = await _ensureEmailAccountSession(
      createIfMissing: false,
    );
    await _hydrateAccountAddress(
      address: normalizedAddress,
      deltaAccountId: deltaAccountId,
    );
    return _EmailAccountBinding(
      address: normalizedAddress,
      deltaAccountId: deltaAccountId,
    );
  }

  Future<_EmailAccountBinding> _accountBindingForChat(Chat chat) async {
    final String scope = _requireActiveScope();
    return _accountBindingForScope(
      scope: scope,
      fromAddress: chat.emailFromAddress,
    );
  }

  Future<void> _ensureAccountConfigured({
    required String scope,
    required _EmailAccountBinding account,
    bool forceProvisioning = false,
  }) async {
    await _transport.ensureAccountSession(account.deltaAccountId);
    final configured = await _transport.isConfigured(
      accountId: account.deltaAccountId,
    );
    if (configured && !forceProvisioning) {
      return;
    }
    final EmailAccount? credentials = await _accountForScope(scope);
    if (credentials == null || credentials.password.isEmpty) {
      throw const EmailProvisioningMissingPasswordException();
    }
    final String displayName = _displayNameForAddress(account.address);
    final Map<String, String> configureOverrides =
        _buildConfigureAccountOverrides(
          address: account.address,
          password: credentials.password,
        );
    try {
      await _transport.configureAccount(
        address: account.address,
        password: credentials.password,
        displayName: displayName,
        additional: configureOverrides,
        accountId: account.deltaAccountId,
      );
    } on DeltaSafeException catch (error, stackTrace) {
      final mapped = DeltaChatExceptionMapper.fromDeltaSafe(
        error,
        operation: 'configure email account',
      );
      final errorType = error.runtimeType;
      _log.warning(
        'Failed to configure email account ($errorType): ${error.message}',
        null,
        stackTrace,
      );
      if (mapped.code == DeltaChatErrorCode.network ||
          mapped.code == DeltaChatErrorCode.server) {
        throw const EmailProvisioningNetworkUnavailableException();
      }
      final isAuthFailure =
          mapped.code == DeltaChatErrorCode.permission ||
          mapped.code == DeltaChatErrorCode.auth;
      throw isAuthFailure
          ? const EmailProvisioningAuthenticationFailedException()
          : const EmailProvisioningConfigurationException();
    }
  }

  Future<int> _ensureDeltaChatIdForAccount({
    required Chat chat,
    required _EmailAccountBinding account,
  }) async => (await _deltaChatIdForAccount(
    chat: chat,
    deltaAccountId: account.deltaAccountId,
    requireRecipientMetadata: true,
  ))!;

  Future<int?> _deltaChatIdForAccount({
    required Chat chat,
    required int deltaAccountId,
    bool requireRecipientMetadata = false,
  }) async {
    final Chat resolvedChat = await _storedEmailChatForAccount(
      chat: chat,
      deltaAccountId: deltaAccountId,
    );
    final db = await _databaseBuilder();
    final int? existing = await db.getDeltaChatIdForAccount(
      chatJid: resolvedChat.jid,
      deltaAccountId: deltaAccountId,
    );
    final int? activeDeltaChatId = resolvedChat.deltaChatId;
    final String? recipientAddress = resolvedChat.type == ChatType.chat
        ? _recipientAddressForChat(resolvedChat)
        : null;
    if (recipientAddress != null) {
      final String displayName =
          resolvedChat.contactDisplayName ?? resolvedChat.title;
      try {
        final int chatId = await _guardDeltaOperation(
          operation: 'ensure email chat',
          body: () => _transport.ensureChatForAddress(
            address: recipientAddress,
            displayName: displayName,
            accountId: deltaAccountId,
          ),
        );
        final Chat targetChat =
            await db.getChatByDeltaChatId(chatId, accountId: deltaAccountId) ??
            resolvedChat;
        await db.upsertEmailChatAccount(
          chatJid: targetChat.jid,
          deltaAccountId: deltaAccountId,
          deltaChatId: chatId,
        );
        await _updateActiveChatDeltaReference(
          chat: targetChat,
          deltaAccountId: deltaAccountId,
          deltaChatId: chatId,
          emailAddress: recipientAddress,
        );
        return chatId;
      } on DeltaChatException {
        if (requireRecipientMetadata) {
          rethrow;
        }
        if (existing != null) {
          return existing;
        }
        if (activeDeltaChatId != null &&
            deltaAccountId == _transport.activeAccountId) {
          await db.upsertEmailChatAccount(
            chatJid: resolvedChat.jid,
            deltaAccountId: deltaAccountId,
            deltaChatId: activeDeltaChatId,
          );
          return activeDeltaChatId;
        }
        return null;
      }
    }
    if (existing != null) {
      return existing;
    }
    if (activeDeltaChatId != null &&
        deltaAccountId == _transport.activeAccountId) {
      await db.upsertEmailChatAccount(
        chatJid: resolvedChat.jid,
        deltaAccountId: deltaAccountId,
        deltaChatId: activeDeltaChatId,
      );
      return activeDeltaChatId;
    }
    if (requireRecipientMetadata) {
      throw const EmailServiceMissingRecipientMetadataException();
    }
    return null;
  }

  Future<_EmailChatBinding> _bindEmailChat(Chat chat) async {
    await _ensureReady();
    final String scope = _requireActiveScope();
    final _EmailAccountBinding account = await _accountBindingForChat(chat);
    final Chat resolvedChat = await _storedEmailChatForAccount(
      chat: chat,
      deltaAccountId: account.deltaAccountId,
    );
    await _updateChatEmailFromAddress(resolvedChat, account.address);
    await _ensureAccountConfigured(scope: scope, account: account);
    final int chatId = await _ensureDeltaChatIdForAccount(
      chat: resolvedChat,
      account: account,
    );
    return _EmailChatBinding(
      chat: resolvedChat,
      deltaChatId: chatId,
      account: account,
    );
  }

  Future<void> _clearCredentials(String scope) async {
    await _credentialStore.delete(key: _addressKeyForScope(scope));
    await _credentialStore.delete(key: _passwordKeyForScope(scope));
    await _credentialStore.delete(key: _provisionedKeyForScope(scope));
    await _credentialStore.delete(key: _connectionOverrideKeyForScope(scope));
    _credentialSession.clearScope(
      scope,
      preserveActiveSession: false,
      clearEphemeralState: true,
    );
  }

  Future<T> _guardDeltaOperation<T>({
    required String operation,
    required Future<T> Function() body,
  }) async {
    try {
      return await body();
    } on DeltaSafeException catch (error) {
      throw DeltaChatExceptionMapper.fromDeltaSafe(error, operation: operation);
    }
  }

  Future<void> persistActiveCredentials({required String jid}) async {
    final String scope = _scopeForJid(jid);
    if (_activeAccount == null || _activeCredentialScope != scope) {
      return;
    }
    if (_activeAccount!.password.isEmpty) {
      return;
    }
    final addressKey = _addressKeyForScope(scope);
    final passwordKey = _passwordKeyForScope(scope);
    final provisionedKey = _provisionedKeyForScope(scope);
    await _credentialStore.write(
      key: addressKey,
      value: _activeAccount!.address,
    );
    await _credentialStore.write(
      key: passwordKey,
      value: _activeAccount!.password,
    );
    await _credentialStore.write(
      key: provisionedKey,
      value: _credentialTrueValue,
    );
    _credentialSession.markEphemerallyProvisioned(scope);
    await _markConnectionOverridesApplied(
      scope: scope,
      persistCredentials: true,
      connectionOverrides: _buildConnectionConfig(_activeAccount!.address),
    );
  }

  Future<void> clearStoredCredentials({
    required String jid,
    bool preserveActiveSession = false,
  }) async {
    final scope = _scopeForJid(jid);
    await _credentialStore.delete(key: _addressKeyForScope(scope));
    await _credentialStore.delete(key: _passwordKeyForScope(scope));
    await _credentialStore.delete(key: _provisionedKeyForScope(scope));
    await _credentialStore.delete(key: _connectionOverrideKeyForScope(scope));
    _credentialSession.clearScope(
      scope,
      preserveActiveSession: preserveActiveSession,
      clearEphemeralState: !preserveActiveSession,
    );
  }

  /// Marks a chat as noticed, clearing unread badges in core.
  ///
  /// Call this when the user opens a chat.
  Future<bool> markNoticedChat(Chat chat) async {
    await _ensureReady();
    final account = await _accountBindingForChat(chat);
    final Chat resolvedChat = await _storedEmailChatForAccount(
      chat: chat,
      deltaAccountId: account.deltaAccountId,
    );
    final chatId = await _deltaChatIdForAccount(
      chat: resolvedChat,
      deltaAccountId: account.deltaAccountId,
    );
    if (chatId == null) {
      return false;
    }
    final noticed = await _transport.markNoticedChat(
      chatId,
      accountId: account.deltaAccountId,
    );
    if (!noticed) {
      return false;
    }
    return true;
  }

  /// Marks messages as seen, triggering MDN if enabled.
  ///
  /// Call this when messages are displayed to the user.
  Future<bool> markSeenMessages(
    List<Message> messages, {
    required bool sendReadReceipts,
  }) async {
    final idsByAccount = <int, List<int>>{};
    for (final message in messages) {
      final deltaId = message.deltaMsgId;
      if (deltaId == null) continue;
      idsByAccount
          .putIfAbsent(message.deltaAccountId, () => <int>[])
          .add(deltaId);
    }
    if (idsByAccount.isEmpty) {
      return true;
    }
    await _ensureReady();
    await _applyEmailReadReceiptPreference(
      accountIds: idsByAccount.keys,
      enabled: sendReadReceipts,
    );
    var success = true;
    for (final entry in idsByAccount.entries) {
      final result = await _transport.markSeenMessages(
        entry.value,
        accountId: entry.key,
      );
      if (!result) {
        success = false;
      }
    }
    return success;
  }

  /// Returns the count of fresh (unread) messages in a chat.
  Future<int> getFreshMessageCount(Chat chat) async {
    await _ensureReady();
    final account = await _accountBindingForChat(chat);
    final chatId = await _deltaChatIdForAccount(
      chat: chat,
      deltaAccountId: account.deltaAccountId,
    );
    if (chatId == null) {
      return 0;
    }
    return _transport.getFreshMessageCount(
      chatId,
      accountId: account.deltaAccountId,
    );
  }

  /// Returns the oldest fresh (unread) message ID for a chat.
  ///
  /// This consults core fresh IDs so the boundary comes from server state.
  Future<int?> getOldestFreshMessageId(Chat chat) async {
    await _ensureReady();
    final account = await _accountBindingForChat(chat);
    final chatId = await _deltaChatIdForAccount(
      chat: chat,
      deltaAccountId: account.deltaAccountId,
    );
    if (chatId == null) {
      return null;
    }
    final freshIds = await _transport.getFreshMessageIds(
      accountId: account.deltaAccountId,
    );
    if (freshIds.isEmpty) {
      return null;
    }
    DeltaMessage? oldest;
    for (final freshId in freshIds) {
      if (freshId <= _deltaMessageIdUnset) {
        continue;
      }
      final message = await _transport.getMessage(
        freshId,
        accountId: account.deltaAccountId,
      );
      if (message == null || message.chatId != chatId) {
        continue;
      }
      if (oldest == null) {
        oldest = message;
        continue;
      }
      final messageTimestamp = message.timestamp;
      final oldestTimestamp = oldest.timestamp;
      if (oldestTimestamp == null && messageTimestamp == null) {
        if (message.id < oldest.id) {
          oldest = message;
        }
        continue;
      }
      if (oldestTimestamp == null ||
          (messageTimestamp != null &&
              messageTimestamp.isBefore(oldestTimestamp))) {
        oldest = message;
      }
    }
    return oldest?.id;
  }

  /// Deletes messages from core and server.
  Future<bool> deleteMessages(List<Message> messages) async {
    final deltaMessages = messages
        .where((message) => message.deltaMsgId != null)
        .toList(growable: false);
    if (deltaMessages.isEmpty) {
      return false;
    }
    final idsByAccount = <int, List<int>>{};
    for (final message in deltaMessages) {
      idsByAccount
          .putIfAbsent(message.deltaAccountId, () => <int>[])
          .add(message.deltaMsgId!);
    }
    await _ensureReady();
    var success = true;
    for (final entry in idsByAccount.entries) {
      final result = await _transport.deleteMessages(
        entry.value,
        accountId: entry.key,
      );
      if (!result) {
        success = false;
      }
    }
    if (success) {
      final db = await _databaseBuilder();
      final stanzaIds = deltaMessages
          .map((message) => message.stanzaID.trim())
          .where((stanzaId) => stanzaId.isNotEmpty)
          .toSet();
      if (stanzaIds.isNotEmpty) {
        await db.deleteMessagesByStanzaIds(stanzaIds);
      }
    }
    return success;
  }

  /// Forwards messages to another chat using core.
  Future<bool> forwardMessages({
    required List<Message> messages,
    required Chat toChat,
  }) async {
    await _ensureReady();
    final account = await _accountBindingForChat(toChat);
    final toChatId = await _ensureDeltaChatIdForAccount(
      chat: toChat,
      account: account,
    );
    final deltaIds = messages
        .where(
          (message) =>
              message.deltaMsgId != null &&
              message.deltaAccountId == account.deltaAccountId,
        )
        .map((message) => message.deltaMsgId!)
        .toList(growable: false);
    if (deltaIds.isEmpty) {
      return false;
    }
    return _transport.forwardMessages(
      messageIds: deltaIds,
      toChatId: toChatId,
      accountId: account.deltaAccountId,
    );
  }

  /// Searches messages using core search.
  ///
  /// Pass null for chat to search all chats.
  Future<List<Message>> searchMessages({
    Chat? chat,
    required String query,
  }) async {
    await _ensureReady();
    final String scope = _requireActiveScope();
    final _EmailAccountBinding account = chat == null
        ? await _accountBindingForScope(scope: scope)
        : await _accountBindingForChat(chat);
    int chatId = 0;
    if (chat != null) {
      final int? resolvedChatId = await _deltaChatIdForAccount(
        chat: chat,
        deltaAccountId: account.deltaAccountId,
      );
      if (resolvedChatId == null) {
        return const <Message>[];
      }
      chatId = resolvedChatId;
    }
    final deltaIds = await _transport.searchMessages(
      chatId: chatId,
      query: query,
      accountId: account.deltaAccountId,
    );
    if (deltaIds.isEmpty) return const [];

    final db = await _databaseBuilder();
    final int deltaAccountId = account.deltaAccountId;
    final messagesByDeltaId = <int, Message>{};
    final deltaIdSet = deltaIds.toSet();
    final existing = await db.getMessagesByDeltaIds(
      deltaIdSet,
      deltaAccountId: deltaAccountId,
    );
    for (final message in existing) {
      final deltaId = message.deltaMsgId;
      if (deltaId != null) {
        messagesByDeltaId[deltaId] = message;
      }
    }

    final missingIds = deltaIdSet
        .where((deltaId) => !messagesByDeltaId.containsKey(deltaId))
        .toList(growable: false);
    if (missingIds.isNotEmpty) {
      final stanzaIds = missingIds
          .map((deltaId) => _stanzaId(deltaId, accountId: deltaAccountId))
          .toList(growable: false);
      final stanzaMatches = await db.getMessagesByStanzaIds(stanzaIds);
      final messagesByStanzaId = <String, Message>{
        for (final message in stanzaMatches) message.stanzaID: message,
      };
      for (final deltaId in missingIds) {
        final stanzaId = _stanzaId(deltaId, accountId: deltaAccountId);
        final message = messagesByStanzaId[stanzaId];
        if (message != null) {
          messagesByDeltaId[deltaId] = message;
        }
      }
    }

    final remainingIds = deltaIdSet
        .where((deltaId) => !messagesByDeltaId.containsKey(deltaId))
        .toList(growable: false);
    if (remainingIds.isNotEmpty) {
      await _transport.hydrateMessages(remainingIds, accountId: deltaAccountId);
      final hydrated = await db.getMessagesByDeltaIds(
        remainingIds,
        deltaAccountId: deltaAccountId,
      );
      for (final message in hydrated) {
        final deltaId = message.deltaMsgId;
        if (deltaId != null) {
          messagesByDeltaId[deltaId] = message;
        }
      }
      final stanzaIds = remainingIds
          .map((deltaId) => _stanzaId(deltaId, accountId: deltaAccountId))
          .toList(growable: false);
      final stanzaMatches = await db.getMessagesByStanzaIds(stanzaIds);
      final messagesByStanzaId = <String, Message>{
        for (final message in stanzaMatches) message.stanzaID: message,
      };
      for (final deltaId in remainingIds) {
        if (messagesByDeltaId.containsKey(deltaId)) {
          continue;
        }
        final stanzaId = _stanzaId(deltaId, accountId: deltaAccountId);
        final message = messagesByStanzaId[stanzaId];
        if (message != null) {
          messagesByDeltaId[deltaId] = message;
        }
      }
    }

    final messages = <Message>[];
    for (final deltaId in deltaIds) {
      final message = messagesByDeltaId[deltaId];
      if (message != null) {
        messages.add(message);
      }
    }
    return messages;
  }

  /// Sets chat visibility (normal, archived, pinned) in core.
  Future<bool> setChatVisibility({
    required Chat chat,
    required int visibility,
  }) async {
    await _ensureReady();
    final account = await _accountBindingForChat(chat);
    final chatId = await _deltaChatIdForAccount(
      chat: chat,
      deltaAccountId: account.deltaAccountId,
    );
    if (chatId == null) {
      return false;
    }
    return _transport.setChatVisibility(
      chatId: chatId,
      visibility: visibility,
      accountId: account.deltaAccountId,
    );
  }

  /// Triggers download of full message content for partial messages.
  Future<bool> downloadFullMessage(Message message) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null) return false;
    await _ensureReady();
    return _transport.downloadFullMessage(
      deltaId,
      accountId: message.deltaAccountId,
    );
  }

  /// Resends failed messages using core retry.
  Future<bool> resendMessages(List<Message> messages) async {
    final idsByAccount = <int, List<int>>{};
    for (final message in messages) {
      final deltaId = message.deltaMsgId;
      if (deltaId == null) continue;
      idsByAccount
          .putIfAbsent(message.deltaAccountId, () => <int>[])
          .add(deltaId);
    }
    if (idsByAccount.isEmpty) {
      return false;
    }
    await _ensureReady();
    var success = true;
    for (final entry in idsByAccount.entries) {
      final result = await _transport.resendMessages(
        entry.value,
        accountId: entry.key,
      );
      if (!result) {
        success = false;
      }
    }
    return success;
  }

  /// Sends a message as a reply to another message.
  ///
  /// Uses core's quote mechanism for proper email threading.
  Future<int> sendReply({
    required Chat chat,
    required String body,
    required Message quotedMessage,
    String? subject,
    String? htmlBody,
  }) async {
    if (kEnableDemoChats) {
      return _sendDemoEmailMessage(
        chat: chat,
        body: body,
        subject: subject,
        htmlBody: htmlBody,
        quotedStanzaId: quotedMessage.stanzaID,
      );
    }
    final quotedMsgId = quotedMessage.deltaMsgId;
    final binding = await _bindEmailChat(chat);
    final chatId = binding.deltaChatId;
    if (quotedMsgId == null ||
        quotedMessage.deltaAccountId != binding.deltaAccountId) {
      final syntheticReply = _syntheticReplyEnvelope(
        quotedMessage,
        body: body,
        subject: subject,
      );
      return sendMessage(
        chat: chat,
        body: syntheticReply.body,
        subject: syntheticReply.subject,
        htmlBody: syntheticReply.htmlBody,
        quotedStanzaId: quotedMessage.stanzaID,
      );
    }
    await _ensureReady();
    final normalizedSubject = _normalizeReplySubject(
      subject: subject,
      quotedSubject: quotedMessage.subject,
      quotedSenderLabel:
          displaySafeAddress(quotedMessage.senderJid) ??
          quotedMessage.senderJid.trim(),
    );
    final normalizedHtml = HtmlContentCodec.normalizeHtml(htmlBody);
    final trimmedBody = body.trim();
    final effectiveBody = trimmedBody.isNotEmpty
        ? trimmedBody
        : (normalizedHtml == null
              ? ''
              : HtmlContentCodec.toPlainText(normalizedHtml));
    final msgId = await _guardDeltaOperation(
      operation: 'send reply',
      body: () => _transport.sendTextWithQuote(
        chatId: chatId,
        body: effectiveBody,
        quotedMessageId: quotedMsgId,
        quotedStanzaId: quotedMessage.stanzaID,
        subject: normalizedSubject,
        htmlBody: normalizedHtml,
        accountId: binding.deltaAccountId,
      ),
    );
    return msgId;
  }

  /// Gets the quoted message info for a message.
  Future<DeltaQuotedMessage?> getQuotedMessage(Message message) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null) return null;
    await _ensureReady();
    return _transport.getQuotedMessage(
      deltaId,
      accountId: message.deltaAccountId,
    );
  }

  /// Gets raw RFC822 headers for a message, if available.
  Future<String?> getMessageRawHeaders(int messageId, {int? accountId}) async {
    if (messageId <= _deltaMessageIdUnset) return null;
    await _ensureReady();
    final headers = await _transport.getMessageMimeHeaders(
      messageId,
      accountId: accountId,
    );
    return sanitizeRawEmailHeaders(headers);
  }

  /// Gets HTML synthesized from the stored MIME for a message, if available.
  Future<String?> getMessageFullHtml(Message message) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) return null;
    await _ensureReady();
    return _transport.getMessageFullHtml(
      deltaId,
      accountId: message.deltaAccountId,
    );
  }

  /// Gets a debug dump for a stored email message and the current Delta view.
  Future<String?> getMessageDebugDump(Message message) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) return null;
    await _ensureReady();
    final deltaMessage = await _transport.getMessage(
      deltaId,
      accountId: message.deltaAccountId,
    );
    final quotedMessage = await _transport.getQuotedMessage(
      deltaId,
      accountId: message.deltaAccountId,
    );
    final fullHtml = await _transport.getMessageFullHtml(
      deltaId,
      accountId: message.deltaAccountId,
    );
    final storedMimeHeaders = await _transport.getMessageMimeHeaders(
      deltaId,
      accountId: message.deltaAccountId,
    );
    return _formatMessageDebugDump(
      storedMessage: message,
      deltaMessage: deltaMessage,
      quotedMessage: quotedMessage,
      fullHtml: fullHtml,
      storedMimeHeaders: storedMimeHeaders,
    );
  }

  String _formatMessageDebugDump({
    required Message storedMessage,
    required DeltaMessage? deltaMessage,
    required DeltaQuotedMessage? quotedMessage,
    required String? fullHtml,
    required String? storedMimeHeaders,
  }) {
    final buffer = StringBuffer();

    void writeSection(String title) {
      if (buffer.length > 0) {
        buffer.writeln();
      }
      buffer.writeln('[$title]');
    }

    void writeField(String label, Object? value) {
      buffer.writeln('$label: ${_debugDumpScalar(value)}');
    }

    void writeTextField(String label, String? value) {
      writeField('$label.length', value?.length);
      buffer.writeln('$label:');
      buffer.writeln(_debugDumpText(value));
    }

    writeSection('Axichat stored message');
    writeField('stanza_id', storedMessage.stanzaID);
    writeField('local_id', storedMessage.id);
    writeField('origin_id', storedMessage.originID);
    writeField('occupant_id', storedMessage.occupantID);
    writeField('chat_jid', storedMessage.chatJid);
    writeField('sender_jid', storedMessage.senderJid);
    writeField('timestamp', storedMessage.timestamp);
    writeField('delta_account_id', storedMessage.deltaAccountId);
    writeField('delta_chat_id', storedMessage.deltaChatId);
    writeField('delta_message_id', storedMessage.deltaMsgId);
    writeTextField('subject', storedMessage.subject);
    writeTextField('body', storedMessage.body);
    writeTextField('html_body', storedMessage.htmlBody);

    writeSection('Delta getMessage');
    if (deltaMessage == null) {
      buffer.writeln('unavailable');
      return buffer.toString();
    }
    writeField('id', deltaMessage.id);
    writeField('chat_id', deltaMessage.chatId);
    writeField('timestamp', deltaMessage.timestamp);
    writeField('is_outgoing', deltaMessage.isOutgoing);
    writeField(
      'view_type',
      _debugDumpLabeledInt(deltaMessage.viewType, _deltaViewTypeName),
    );
    writeField(
      'state',
      _debugDumpLabeledInt(deltaMessage.state, _deltaMessageStateName),
    );
    writeField(
      'download_state',
      _debugDumpLabeledInt(deltaMessage.downloadState, _deltaDownloadStateName),
    );
    writeField('needs_download', deltaMessage.needsDownload);
    writeField('has_file', deltaMessage.hasFile);
    writeField('file_path', deltaMessage.filePath);
    writeField('file_name', deltaMessage.fileName);
    writeField('file_mime', deltaMessage.fileMime);
    writeField('file_size', deltaMessage.fileSize);
    writeField('width', deltaMessage.width);
    writeField('height', deltaMessage.height);
    writeField('error', deltaMessage.error);
    writeTextField('subject', deltaMessage.subject);
    writeTextField('text', deltaMessage.text);
    writeTextField('html', deltaMessage.html);
    writeSection('Delta quoted');
    if (quotedMessage == null) {
      buffer.writeln('unavailable');
    } else {
      writeField('id', quotedMessage.id);
      writeTextField('text', quotedMessage.text);
    }

    writeSection('Delta full html');
    writeTextField('html', fullHtml);

    writeSection('Delta stored mime_headers');
    writeField('present', storedMimeHeaders != null);
    writeTextField('text', storedMimeHeaders);
    return buffer.toString();
  }

  String _debugDumpScalar(Object? value) {
    if (value == null) return '(null)';
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is String) {
      return value.isEmpty ? '(empty)' : value;
    }
    return '$value';
  }

  String _debugDumpText(String? value) {
    if (value == null) return '(null)';
    if (value.isEmpty) return '(empty)';
    return value;
  }

  String _debugDumpLabeledInt(int? value, String Function(int) labelFor) {
    if (value == null) return '(null)';
    return '${labelFor(value)} ($value)';
  }

  String _deltaViewTypeName(int value) => switch (value) {
    DeltaMessageType.undefined => 'undefined',
    DeltaMessageType.text => 'text',
    DeltaMessageType.image => 'image',
    DeltaMessageType.gif => 'gif',
    DeltaMessageType.sticker => 'sticker',
    DeltaMessageType.audio => 'audio',
    DeltaMessageType.voice => 'voice',
    DeltaMessageType.video => 'video',
    DeltaMessageType.file => 'file',
    DeltaMessageType.call => 'call',
    DeltaMessageType.webxdc => 'webxdc',
    DeltaMessageType.vcard => 'vcard',
    _ => 'unknown',
  };

  String _deltaMessageStateName(int value) => switch (value) {
    DeltaMessageState.undefined => 'undefined',
    DeltaMessageState.inFresh => 'in_fresh',
    DeltaMessageState.inNoticed => 'in_noticed',
    DeltaMessageState.inSeen => 'in_seen',
    DeltaMessageState.outPreparing => 'out_preparing',
    DeltaMessageState.outDraft => 'out_draft',
    DeltaMessageState.outPending => 'out_pending',
    DeltaMessageState.outFailed => 'out_failed',
    DeltaMessageState.outDelivered => 'out_delivered',
    DeltaMessageState.outMdnRcvd => 'out_mdn_rcvd',
    _ => 'unknown',
  };

  String _deltaDownloadStateName(int value) => switch (value) {
    DeltaDownloadState.done => 'done',
    DeltaDownloadState.available => 'available',
    DeltaDownloadState.failure => 'failure',
    DeltaDownloadState.undecipherable => 'undecipherable',
    DeltaDownloadState.inProgress => 'in_progress',
    _ => 'unknown',
  };

  /// Saves a draft to core.
  Future<void> mirrorDraftForFallback({
    required List<String> jids,
    required String text,
    String? subject,
    List<EmailAttachment> attachments = _emptyEmailAttachments,
  }) async {
    if (!isSmtpOnly) {
      return;
    }
    final chat = await _draftMirrorChatForRecipients(jids);
    if (chat == null) {
      return;
    }
    await saveDraftToCore(
      chat: chat,
      text: text,
      subject: subject,
      attachments: attachments,
    );
  }

  Future<bool> saveDraftToCore({
    required Chat chat,
    required String text,
    String? subject,
    String? htmlBody,
    List<EmailAttachment> attachments = _emptyEmailAttachments,
  }) async {
    final binding = await _bindEmailChat(chat);
    final chatId = binding.deltaChatId;
    await _ensureReady();
    final normalizedSubject = _normalizeSubject(subject);
    final normalizedHtml = _normalizeDraftHtml(text: text, htmlBody: htmlBody);
    final attachment = _draftAttachmentForCore(attachments);
    final viewType = attachment == null
        ? DeltaMessageType.text
        : _viewTypeForDraftAttachment(attachment);
    final message = DeltaMessage(
      id: _coreDraftMessageId,
      chatId: chatId,
      text: text,
      html: normalizedHtml,
      subject: normalizedSubject,
      viewType: viewType,
      filePath: attachment?.path,
      fileName: attachment?.fileName,
      fileMime: attachment?.mimeType,
      fileSize: attachment?.sizeBytes,
      width: attachment?.width,
      height: attachment?.height,
    );
    return _transport.setDraft(
      chatId: chatId,
      message: message,
      accountId: binding.deltaAccountId,
    );
  }

  /// Clears a draft from core.
  Future<void> clearMirroredDraftForFallback(List<String> jids) async {
    if (!isSmtpOnly) {
      return;
    }
    final chat = await _draftMirrorExistingChatForRecipients(jids);
    if (chat == null) {
      return;
    }
    await clearDraftFromCore(chat);
  }

  Future<bool> clearDraftFromCore(Chat chat) async {
    await _ensureReady();
    final account = await _accountBindingForChat(chat);
    final chatId = await _deltaChatIdForAccount(
      chat: chat,
      deltaAccountId: account.deltaAccountId,
    );
    if (chatId == null) {
      return false;
    }
    return _transport.setDraft(
      chatId: chatId,
      message: null,
      accountId: account.deltaAccountId,
    );
  }

  /// Gets a draft from core.
  Future<DeltaMessage?> getDraftFromCore(Chat chat) async {
    await _ensureReady();
    final account = await _accountBindingForChat(chat);
    final chatId = await _deltaChatIdForAccount(
      chat: chat,
      deltaAccountId: account.deltaAccountId,
    );
    if (chatId == null) {
      return null;
    }
    return _transport.getDraft(chatId, accountId: account.deltaAccountId);
  }

  Future<Chat?> _draftMirrorChatForRecipients(List<String> jids) async {
    final recipient = await _singleDraftMirrorRecipient(jids);
    if (recipient == null) {
      return null;
    }
    final db = await _databaseBuilder();
    final existing = await db.getChat(recipient);
    if (existing != null) {
      return ensureChatForEmailChat(existing);
    }
    return ensureChatForAddress(address: recipient);
  }

  Future<Chat?> _draftMirrorExistingChatForRecipients(List<String> jids) async {
    final recipient = await _singleDraftMirrorRecipient(jids);
    if (recipient == null) {
      return null;
    }
    final db = await _databaseBuilder();
    final existing = await db.getChat(recipient);
    if (existing == null) {
      return null;
    }
    return ensureChatForEmailChat(existing);
  }

  Future<String?> _singleDraftMirrorRecipient(List<String> jids) async {
    const int coreDraftRecipientLimit = 1;
    final normalizedRecipients = <String>{};
    for (final jid in jids) {
      final normalized = normalizeEmailAddress(jid);
      if (normalized.isEmpty) {
        continue;
      }
      normalizedRecipients.add(normalized);
    }
    if (normalizedRecipients.length != coreDraftRecipientLimit) {
      return null;
    }
    final recipient = normalizedRecipients.first;
    final db = await _databaseBuilder();
    final existing = await db.getChat(recipient);
    if (existing == null || !existing.defaultTransport.isEmail) {
      return null;
    }
    return recipient;
  }

  /// Gets all contact IDs from core.
  ///
  /// Use flags from [DeltaContactListFlags] to filter results.
  Future<List<int>> getContactIds({int flags = 0, String? query}) async {
    await _ensureReady();
    return _transport.getContactIds(flags: flags, query: query);
  }

  /// Gets all blocked contact IDs from core.
  Future<List<int>> getBlockedContactIds() async {
    await _ensureReady();
    return _transport.getBlockedContactIds();
  }

  /// Deletes a contact from core.
  ///
  /// Returns true if the contact was deleted.
  Future<bool> deleteContact(int contactId) async {
    await _ensureReady();
    return _transport.deleteContact(contactId);
  }

  /// Deletes a contact by address from core.
  ///
  /// Returns true if the contact was deleted.
  /// Gets a contact by ID from core.
  Future<DeltaContact?> getContact(int contactId) async {
    await _ensureReady();
    return _transport.getContact(contactId);
  }

  Future<List<DeltaContact>> _hydrateContactsByIds(List<int> ids) async {
    if (ids.isEmpty) {
      return const <DeltaContact>[];
    }
    final contacts = <DeltaContact>[];
    for (
      var index = 0;
      index < ids.length;
      index += _contactHydrationConcurrentOps
    ) {
      final chunk = ids
          .skip(index)
          .take(_contactHydrationConcurrentOps)
          .toList();
      final hydratedContacts = await Future.wait(
        chunk.map(_transport.getContact),
      );
      for (final contact in hydratedContacts) {
        if (contact != null) {
          contacts.add(contact);
        }
      }
    }
    return contacts;
  }

  /// Gets all contacts from core as a list.
  ///
  /// Use flags from [DeltaContactListFlags] to filter results.
  Future<List<DeltaContact>> getContacts({int flags = 0, String? query}) async {
    await _ensureReady();
    final ids = await _transport.getContactIds(flags: flags, query: query);
    return _hydrateContactsByIds(ids);
  }

  /// Gets all blocked contacts from core as a list.
  Future<List<DeltaContact>> getBlockedContacts() async {
    await _ensureReady();
    final ids = await _transport.getBlockedContactIds();
    return _hydrateContactsByIds(ids);
  }
}

String _stanzaId(int msgId, {required int accountId}) {
  return deltaMessageStanzaId(msgId);
}

final class _EmailCredentialRuntimeSession {
  final Map<String, _EmailCredentialScopeState> _scopes =
      <String, _EmailCredentialScopeState>{};

  String? databasePrefix;
  String? databasePassphrase;
  EmailAccount? sessionCredentials;
  String? activeCredentialScope;

  bool get hasActiveSession =>
      databasePrefix != null && databasePassphrase != null;

  bool get hasInMemoryReconnectContext =>
      hasActiveSession && activeCredentialScope != null;

  _EmailCredentialScopeState scopeState(String scope) {
    return _scopes.putIfAbsent(
      scope,
      () => _EmailCredentialScopeState(scope: scope),
    );
  }

  _EmailCredentialScopeState? scopeStateOrNull(String? scope) {
    if (scope == null) {
      return null;
    }
    return _scopes[scope];
  }

  _EmailCredentialScopeState? get activeScopeState =>
      scopeStateOrNull(activeCredentialScope);

  EmailAccount? get activeAccount => activeScopeState?.activeAccount;

  set activeAccount(EmailAccount? value) {
    final scope = activeScopeState;
    if (scope == null) {
      return;
    }
    scope.activeAccount = value;
  }

  void bindDatabaseRuntime({
    required String databasePrefix,
    required String databasePassphrase,
  }) {
    this.databasePrefix = databasePrefix;
    this.databasePassphrase = databasePassphrase;
  }

  void cacheSessionCredentials({
    required String address,
    required String? password,
  }) {
    final normalizedAddress = address.trim();
    final normalizedPassword = password?.trim();
    if (normalizedAddress.isEmpty ||
        normalizedPassword == null ||
        normalizedPassword.isEmpty) {
      sessionCredentials = null;
      return;
    }
    sessionCredentials = EmailAccount(
      address: normalizedAddress,
      password: normalizedPassword,
    );
  }

  void clearSessionCredentials() {
    sessionCredentials = null;
  }

  void activateAccount({required String scope, required EmailAccount account}) {
    activeCredentialScope = scope;
    scopeState(scope).activeAccount = account;
  }

  void clearRuntime() {
    databasePrefix = null;
    databasePassphrase = null;
    final activeScope = activeScopeState;
    if (activeScope != null) {
      activeScope.activeAccount = null;
      activeScope.bootstrapFuture = null;
      activeScope.bootstrapOperationId = 0;
    }
    clearSessionCredentials();
    activeCredentialScope = null;
  }

  void invalidateBootstrapOperations() {
    for (final scopeState in _scopes.values) {
      scopeState.bootstrapOperationId += 1;
      scopeState.bootstrapFuture = null;
    }
  }

  void clearScope(
    String scope, {
    required bool preserveActiveSession,
    required bool clearEphemeralState,
  }) {
    final scopeState = _scopes[scope];
    if (scopeState == null) {
      return;
    }
    if (!preserveActiveSession && activeCredentialScope == scope) {
      activeCredentialScope = null;
      scopeState.activeAccount = null;
    }
    if (clearEphemeralState) {
      scopeState.isEphemerallyProvisioned = false;
      scopeState.hasEphemeralConnectionOverride = false;
    }
    if (!preserveActiveSession && !clearEphemeralState) {
      return;
    }
    if (scopeState.isEmpty) {
      _scopes.remove(scope);
    }
  }

  bool hasEphemeralConnectionOverride(String scope) =>
      scopeState(scope).hasEphemeralConnectionOverride;

  void markEphemeralConnectionOverride(String scope) {
    scopeState(scope).hasEphemeralConnectionOverride = true;
  }

  bool isEphemerallyProvisioned(String scope) =>
      scopeState(scope).isEphemerallyProvisioned;

  void markEphemerallyProvisioned(String scope) {
    scopeState(scope).isEphemerallyProvisioned = true;
  }

  void clearEphemeralProvisioning(String scope) {
    scopeState(scope).isEphemerallyProvisioned = false;
  }
}

final class _EmailCredentialScopeState {
  _EmailCredentialScopeState({required this.scope})
    : addressKey = CredentialStore.registerKey('email_address_$scope'),
      passwordKey = CredentialStore.registerKey('email_password_$scope'),
      provisionedKey = CredentialStore.registerKey('email_provisioned_$scope'),
      connectionOverrideKey = CredentialStore.registerKey(
        '${EmailService._connectionOverrideKeyPrefix}_$scope',
      );

  final String scope;
  final RegisteredCredentialKey addressKey;
  final RegisteredCredentialKey passwordKey;
  final RegisteredCredentialKey provisionedKey;
  final RegisteredCredentialKey connectionOverrideKey;
  final Map<String, RegisteredCredentialKey> _bootstrapKeys =
      <String, RegisteredCredentialKey>{};

  bool isEphemerallyProvisioned = false;
  bool hasEphemeralConnectionOverride = false;
  EmailAccount? activeAccount;
  Future<void>? bootstrapFuture;
  int bootstrapOperationId = 0;

  RegisteredCredentialKey bootstrapKeyFor(String databasePrefix) {
    final identifier =
        '${EmailService._emailBootstrapKeyPrefix}'
        '_${databasePrefix}_$scope';
    return _bootstrapKeys.putIfAbsent(
      databasePrefix,
      () => CredentialStore.registerKey(identifier),
    );
  }

  bool get isEmpty =>
      !isEphemerallyProvisioned &&
      !hasEphemeralConnectionOverride &&
      activeAccount == null &&
      bootstrapFuture == null &&
      bootstrapOperationId == 0;
}

final class _EmailNotificationQueueSession {
  final List<_PendingNotification> _pendingNotifications =
      <_PendingNotification>[];
  int _pendingNotificationSequence = 0;
  final Map<_PendingNotificationScope, int>
  _pendingNotificationDropThroughSequenceByScope =
      <_PendingNotificationScope, int>{};
  Timer? _notificationFlushTimer;

  void enqueue({
    required int chatId,
    required int msgId,
    required int accountId,
    required Duration flushDelay,
    required void Function() onFlush,
  }) {
    final sequence = _pendingNotificationSequence + 1;
    _pendingNotificationSequence = sequence;
    _pendingNotifications.add(
      _PendingNotification(
        chatId: chatId,
        msgId: msgId,
        accountId: accountId,
        sequence: sequence,
      ),
    );
    _notificationFlushTimer ??= Timer(flushDelay, () {
      _notificationFlushTimer = null;
      onFlush();
    });
  }

  void suppressThroughCurrentSequence({required int accountId, int? chatId}) {
    if (_pendingNotifications.isEmpty) {
      return;
    }
    final currentSequence = _pendingNotificationSequence;
    if (chatId != null) {
      _pendingNotificationDropThroughSequenceByScope[_PendingNotificationScope(
            accountId: accountId,
            chatId: chatId,
          )] =
          currentSequence;
      return;
    }
    final countsByScope = <_PendingNotificationScope, int>{};
    for (final entry in _pendingNotifications) {
      if (entry.accountId != accountId || entry.sequence > currentSequence) {
        continue;
      }
      final scope = _PendingNotificationScope(
        accountId: entry.accountId,
        chatId: entry.chatId,
      );
      countsByScope.update(scope, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final entry in countsByScope.entries) {
      if (entry.value < 2) {
        continue;
      }
      _pendingNotificationDropThroughSequenceByScope[entry.key] =
          currentSequence;
    }
  }

  void dropForChat(int chatId, {required int accountId}) {
    _pendingNotifications.removeWhere(
      (entry) => entry.chatId == chatId && entry.accountId == accountId,
    );
    if (_pendingNotifications.isNotEmpty) {
      return;
    }
    _notificationFlushTimer?.cancel();
    _notificationFlushTimer = null;
  }

  List<_PendingNotification> drain() {
    _notificationFlushTimer?.cancel();
    _notificationFlushTimer = null;
    if (_pendingNotifications.isEmpty) {
      return const <_PendingNotification>[];
    }
    final pending = List<_PendingNotification>.from(_pendingNotifications);
    _pendingNotifications.clear();
    return pending;
  }

  int dropThroughSequence(_PendingNotificationScope scope) =>
      _pendingNotificationDropThroughSequenceByScope[scope] ?? 0;

  void clear() {
    _notificationFlushTimer?.cancel();
    _notificationFlushTimer = null;
    _pendingNotifications.clear();
    _pendingNotificationSequence = 0;
    _pendingNotificationDropThroughSequenceByScope.clear();
  }
}

class _PendingNotification {
  const _PendingNotification({
    required this.chatId,
    required this.msgId,
    required this.accountId,
    required this.sequence,
  });

  final int chatId;
  final int msgId;
  final int accountId;
  final int sequence;
}

class _PendingNotificationScope {
  const _PendingNotificationScope({
    required this.accountId,
    required this.chatId,
  });

  final int accountId;
  final int chatId;

  @override
  bool operator ==(Object other) {
    return other is _PendingNotificationScope &&
        other.accountId == accountId &&
        other.chatId == chatId;
  }

  @override
  int get hashCode => Object.hash(accountId, chatId);
}

final class _EmailNotificationTarget {
  const _EmailNotificationTarget({
    required this.message,
    required this.chat,
    required this.threadKey,
    required this.conversationTitle,
    required this.senderName,
  });

  final Message message;
  final Chat? chat;
  final String threadKey;
  final String conversationTitle;
  final String senderName;

  NotificationPreviewSetting? get previewSetting =>
      chat?.notificationPreviewSetting;

  String get title => chat?.displayName ?? message.senderJid;

  String get senderKey => message.senderJid;

  DateTime? get sentAt => message.timestamp;

  bool get isGroupConversation => chat?.type == ChatType.groupChat;
}
