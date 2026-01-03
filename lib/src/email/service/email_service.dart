// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:axichat/src/common/anti_abuse_sync.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/jid_transport.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/settings/message_storage_mode.dart';
import 'package:logging/logging.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:http/http.dart' as http;

import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/email/service/email_blocking_service.dart';
import 'package:axichat/src/email/service/email_oauth.dart';
import 'package:axichat/src/email/service/email_spam_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/email/transport/email_delta_transport.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/email/util/delta_message_ids.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/email/util/email_header_safety.dart';
import 'package:axichat/src/email/util/share_token_html.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/notification_payload.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';

const _defaultPageSize = 50;
const _maxFanOutRecipients = 20;
const _attachmentFanOutWarningBytes = 8 * 1024 * 1024;
const int _deltaMessageIdUnset = DeltaMessageId.none;
const _foregroundKeepaliveInterval = Duration(seconds: 45);
const _foregroundFetchTimeout = Duration(seconds: 8);
const _notificationFlushDelay = Duration(milliseconds: 500);
const _contactsSyncDebounce = Duration(seconds: 2);
const _connectivityConnectedMin = 4000;
const _connectivityWorkingMin = 3000;
const _connectivityConnectingMin = 2000;
const int _connectivityLogIntervalSeconds = 5;
const _connectivityLogInterval =
    Duration(seconds: _connectivityLogIntervalSeconds);
const _emailConnectivityLogPrefix = 'Email connectivity';
const _emailSyncLogPrefix = 'Email sync state';
const _emailLogSourceLabel = 'source';
const _emailLogValueLabel = 'value';
const _emailLogStateLabel = 'state';
const _emailLogConnectivityLabel = 'connectivity';
const _emailLogHasMessageLabel = 'hasMessage';
const _emailLogUnknownValue = 'unknown';
const int _connectivityDowngradeGraceSeconds = 2;
const _connectivityDowngradeGrace =
    Duration(seconds: _connectivityDowngradeGraceSeconds);
const _emailSyncingMessage = 'Syncing email…';
const _emailConnectingMessage = 'Connecting to email servers…';
const _emailDisconnectedMessage = 'Disconnected from email servers.';
const _coreDraftMessageId = 0;
const int _deltaEventMessageUnset = 0;
const String _securityModeSsl = 'ssl';
const String _securityModeStartTls = 'starttls';
const String _emailAddressSeparator = '@';
const int _emailAddressSeparatorMissingIndex = -1;
const int _emailLocalPartStartIndex = 0;
const int _emailLocalPartMinLength = 1;
const _emailDownloadLimitKey = 'download_limit';
const _emailDownloadLimitDisabledValue = '0';
const _unknownEmailPassword = '';
const String _linkedEmailAccountsKeyPrefix = 'linked_email_accounts_v1';
const String _linkedEmailPrimaryAccountKeyPrefix =
    'linked_email_primary_account_v1';
const String _linkedEmailAccountAddressKeyPrefix =
    'linked_email_account_address_v1';
const String _linkedEmailAccountPasswordKeyPrefix =
    'linked_email_account_password_v1';
const String _linkedEmailAccountDisplayNameKeyPrefix =
    'linked_email_account_display_name_v1';
const String _linkedEmailAccountAuthMethodKeyPrefix =
    'linked_email_account_auth_method_v1';
const String _linkedEmailAccountOauthProviderKeyPrefix =
    'linked_email_account_oauth_provider_v1';
const String _linkedEmailAccountOauthAccessTokenKeyPrefix =
    'linked_email_account_oauth_access_token_v1';
const String _linkedEmailAccountOauthRefreshTokenKeyPrefix =
    'linked_email_account_oauth_refresh_token_v1';
const String _linkedEmailAccountOauthExpiryKeyPrefix =
    'linked_email_account_oauth_access_token_expiry_v1';
const String _linkedEmailAccountDeltaIdKeyPrefix =
    'linked_email_account_delta_id_v1';
const String _linkedEmailAccountProvisionedKeyPrefix =
    'linked_email_account_provisioned_v1';
const String _linkedEmailAccountKeySeparator = '|';
const String _linkedEmailAccountsEmptyJson = '[]';
const String _linkedEmailAccountBoolTrue = 'true';
const String _linkedEmailAccountMissingAddressError =
    'Failed to resolve email address.';
const String _linkedEmailAccountMissingPasswordError =
    'Failed to resolve email password.';
const String _linkedEmailAccountNotLinkedError = 'Email account is not linked.';
const String _linkedEmailAccountsUnsupportedError =
    'Multiple email accounts are not supported on this device.';
const String _linkedEmailAccountAuthMethodPasswordValue = 'password';
const String _linkedEmailAccountAuthMethodOauthValue = 'oauth';
const Set<String> _oauthPreferredDomains = {
  'gmail.com',
  'googlemail.com',
  'outlook.com',
  'hotmail.com',
  'live.com',
  'yahoo.com',
  'ymail.com',
  'rocketmail.com',
};
const String _linkedEmailAccountRemovalFailureLogMessage =
    'Failed to remove linked email account';
const int _linkedEmailAccountsPrimaryCount = 1;
const int _linkedEmailAccountsLimit = 5;
const int _linkedEmailAccountSortPrimary = 0;
const int _linkedEmailAccountSortSecondary = 1;
const int _linkedEmailAccountSortEqual = 0;
const _emailBootstrapKeyPrefix = 'email_bootstrap_v1';
const _connectionOverrideKeyPrefix = 'email_connection_overrides_v1';
const _credentialTrueValue = 'true';
const _credentialFalseValue = 'false';
const _connectionOverrideClearedValue = '';
const _notificationAttachmentLabel = 'Attachment';
const _notificationAttachmentPrefix = 'Attachment: ';
const _reactionNotificationFallback = 'New reaction';
const _reactionNotificationPrefix = 'Reaction: ';
const _webxdcNotificationFallback = 'New update';
const _showEmailsConfigKey = 'show_emails';
const _showEmailsAllValue = '2';
const _mdnsEnabledConfigKey = 'mdns_enabled';
const _mdnsEnabledValue = '1';
const _mailServerConfigKey = 'mail_server';
const _mailPortConfigKey = 'mail_port';
const _mailSecurityConfigKey = 'mail_security';
const _mailUserConfigKey = 'mail_user';
const _serverFlagsConfigKey = 'server_flags';
const _serverFlagsOauthValue = '2';
const _sendServerConfigKey = 'send_server';
const _sendPortConfigKey = 'send_port';
const _sendSecurityConfigKey = 'send_security';
const _sendUserConfigKey = 'send_user';
const String _sendPasswordConfigKey = 'send_pw';
const _portUnsetValue = 0;
const List<String> _connectionOverrideConfigKeys = <String>[
  _mailServerConfigKey,
  _mailPortConfigKey,
  _mailSecurityConfigKey,
  _mailUserConfigKey,
  _sendServerConfigKey,
  _sendPortConfigKey,
  _sendSecurityConfigKey,
  _sendUserConfigKey,
];
const List<EmailAttachment> _emptyEmailAttachments = <EmailAttachment>[];
const _deltaContactIdPrefix = 'delta_contact_';
const _deltaContactListFlags =
    DeltaContactListFlags.addSelf | DeltaContactListFlags.address;
const _imapIdleConfigKey = 'imap_idle';
const _imapIdleTimeoutConfigKey = 'imap_idle_timeout';
const _imapMaxConnectionsConfigKey = 'imap_max_connections';
const _imapIdleKeepaliveInterval = Duration(minutes: 25);
const _imapSentPollIntervalSingleConnection = Duration(seconds: 60);
const _imapPollIntervalNoIdle = Duration(seconds: 30);
const _imapSyncFetchTimeout = Duration(seconds: 25);
const _imapCapabilityRefreshInterval = Duration(minutes: 10);
const _reconnectRestartDelay = Duration(seconds: 2);
const _imapConnectionLimitSingle = 1;
const _imapConnectionLimitMulti = 2;
const int _oauthTokenExpirySkewSeconds = 300;
const Duration _oauthTokenExpirySkew =
    Duration(seconds: _oauthTokenExpirySkewSeconds);
const int _oauthTokenExpiryFallbackSeconds = 3600;
const int _oauthEpochMillisMissing = -1;
const String _oauthTokenContentType = 'application/x-www-form-urlencoded';
const String _oauthGrantTypeAuthorizationCode = 'authorization_code';
const String _oauthGrantTypeRefreshToken = 'refresh_token';
const String _oauthTokenAccessKey = 'access_token';
const String _oauthTokenRefreshKey = 'refresh_token';
const String _oauthTokenExpiresInKey = 'expires_in';
const String _oauthTokenExchangeFailureLog = 'OAuth token exchange failed';
const Set<String> _imapConfigBoolTrueValues = {
  '1',
  'true',
  'yes',
  'on',
};
const Set<String> _imapConfigBoolFalseValues = {
  '0',
  'false',
  'no',
  'off',
};
const int _minimumHistoryWindow = 1;
const bool _includePseudoMessagesInBackfill = false;

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
}

extension _EmailSyncSourceLabels on _EmailSyncSource {
  String get logLabel => name;
}

enum EmailAuthMethod {
  password,
  oauth,
}

extension EmailAuthMethodStorage on EmailAuthMethod {
  static EmailAuthMethod fromStored(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      _linkedEmailAccountAuthMethodOauthValue => EmailAuthMethod.oauth,
      _linkedEmailAccountAuthMethodPasswordValue => EmailAuthMethod.password,
      _ => EmailAuthMethod.password,
    };
  }

  String get storageValue => switch (this) {
        EmailAuthMethod.password => _linkedEmailAccountAuthMethodPasswordValue,
        EmailAuthMethod.oauth => _linkedEmailAccountAuthMethodOauthValue,
      };

  bool get isPassword => this == EmailAuthMethod.password;

  bool get isOauth => this == EmailAuthMethod.oauth;
}

typedef EmailConnectionConfigBuilder = Map<String, String> Function(
  String address,
  EndpointConfig config,
);

final class EmailAccountId {
  const EmailAccountId._(this.value);

  final String value;

  static EmailAccountId? fromAddress(String address) {
    final normalized = normalizeEmailAddress(address);
    if (normalized.isEmpty) {
      return null;
    }
    return EmailAccountId._(normalized);
  }

  static EmailAccountId? fromStored(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return EmailAccountId._(trimmed);
  }

  @override
  bool operator ==(Object other) =>
      other is EmailAccountId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class EmailAccountProfile {
  const EmailAccountProfile({
    required this.id,
    required this.address,
    required this.displayName,
    required this.authMethod,
    required this.isPrimary,
    this.deltaAccountId,
  });

  final EmailAccountId id;
  final String address;
  final String displayName;
  final EmailAuthMethod authMethod;
  final bool isPrimary;
  final int? deltaAccountId;

  EmailAccountProfile copyWith({
    EmailAccountId? id,
    String? address,
    String? displayName,
    EmailAuthMethod? authMethod,
    bool? isPrimary,
    int? deltaAccountId,
  }) {
    return EmailAccountProfile(
      id: id ?? this.id,
      address: address ?? this.address,
      displayName: displayName ?? this.displayName,
      authMethod: authMethod ?? this.authMethod,
      isPrimary: isPrimary ?? this.isPrimary,
      deltaAccountId: deltaAccountId ?? this.deltaAccountId,
    );
  }
}

class EmailAccount {
  const EmailAccount({
    required this.address,
    required this.password,
  });

  final String address;
  final String password;
}

final class _ResolvedEmailAccount {
  const _ResolvedEmailAccount({
    required this.id,
    required this.address,
    required this.deltaAccountId,
  });

  final EmailAccountId id;
  final String address;
  final int deltaAccountId;
}

final class _EmailChatContext {
  const _EmailChatContext({
    required this.chat,
    required this.deltaChatId,
    required this.account,
  });

  final Chat chat;
  final int deltaChatId;
  final _ResolvedEmailAccount account;
}

class EmailImapCapabilities {
  const EmailImapCapabilities({
    required this.idleSupported,
    required this.connectionLimit,
    required this.idleCutoff,
  });

  final bool idleSupported;
  final int connectionLimit;
  final Duration idleCutoff;

  @override
  bool operator ==(Object other) {
    return other is EmailImapCapabilities &&
        other.idleSupported == idleSupported &&
        other.connectionLimit == connectionLimit &&
        other.idleCutoff == idleCutoff;
  }

  @override
  int get hashCode => Object.hash(idleSupported, connectionLimit, idleCutoff);
}

class EmailProvisioningException implements Exception {
  const EmailProvisioningException(
    this.message, {
    this.isRecoverable = false,
    this.shouldWipeCredentials = false,
  });

  final String message;
  final bool isRecoverable;
  final bool shouldWipeCredentials;

  @override
  String toString() => 'EmailProvisioningException: $message';
}

class FanOutValidationException implements Exception {
  const FanOutValidationException(this.message);

  final String message;

  @override
  String toString() => 'FanOutValidationException: $message';
}

class EmailAccountLimitException implements Exception {
  const EmailAccountLimitException({required this.limit});

  final int limit;
}

class EmailService {
  static const NotificationPayloadCodec _notificationPayloadCodec =
      NotificationPayloadCodec();

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
  })  : _credentialStore = credentialStore,
        _databaseBuilder = databaseBuilder,
        _endpointConfig = endpointConfig,
        _transport = transport ??
            EmailDeltaTransport(
              databaseBuilder: databaseBuilder,
              logger: logger,
            ),
        _connectionConfigBuilder =
            connectionConfigBuilder ?? _defaultConnectionConfig,
        _log = logger ?? Logger('EmailService'),
        _notificationService = notificationService,
        _messageService = messageService,
        _foregroundBridge = foregroundBridge ?? foregroundTaskBridge {
    blocking = EmailBlockingService(
      databaseBuilder: databaseBuilder,
      onBlock: _transport.blockContact,
      onUnblock: _transport.unblockContact,
    );
    spam = EmailSpamService(
      databaseBuilder: databaseBuilder,
      onMarkSpam: _transport.blockContact,
      onUnmarkSpam: _transport.unblockContact,
    );
    _eventListener = (event) => unawaited(_processDeltaEvent(event));
    _transport.addEventListener(_eventListener);
    _listenerAttached = true;
  }

  final CredentialStore _credentialStore;
  final Future<XmppDatabase> Function() _databaseBuilder;
  final EmailDeltaTransport _transport;
  final EmailConnectionConfigBuilder _connectionConfigBuilder;
  final Logger _log;
  EndpointConfig _endpointConfig;
  final NotificationService? _notificationService;
  final MessageService? _messageService;
  final ForegroundTaskBridge? _foregroundBridge;
  late final EmailBlockingService blocking;
  late final EmailSpamService spam;
  final Map<String, RegisteredCredentialKey> _provisionedKeys = {};
  final Map<String, RegisteredCredentialKey> _connectionOverrideKeys = {};
  late final void Function(DeltaCoreEvent) _eventListener;
  var _listenerAttached = false;

  String? _databasePrefix;
  String? _databasePassphrase;
  EmailAccount? _activeAccount;
  String? _activeCredentialScope;
  bool _running = false;
  final Map<String, RegisteredCredentialKey> _addressKeys = {};
  final Map<String, RegisteredCredentialKey> _passwordKeys = {};
  final Map<String, RegisteredCredentialKey> _linkedAccountListKeys = {};
  final Map<String, RegisteredCredentialKey> _linkedAccountPrimaryKeys = {};
  final Map<String, RegisteredCredentialKey> _linkedAccountAddressKeys = {};
  final Map<String, RegisteredCredentialKey> _linkedAccountPasswordKeys = {};
  final Map<String, RegisteredCredentialKey> _linkedAccountAuthMethodKeys = {};
  final Map<String, RegisteredCredentialKey> _linkedAccountDisplayNameKeys = {};
  final Map<String, RegisteredCredentialKey> _linkedAccountOauthProviderKeys =
      {};
  final Map<String, RegisteredCredentialKey> _linkedAccountOauthAccessKeys = {};
  final Map<String, RegisteredCredentialKey> _linkedAccountOauthRefreshKeys =
      {};
  final Map<String, RegisteredCredentialKey> _linkedAccountOauthExpiryKeys = {};
  final Map<String, RegisteredCredentialKey> _linkedAccountDeltaIdKeys = {};
  final Map<String, RegisteredCredentialKey> _linkedAccountProvisionedKeys = {};
  final Set<String> _ephemeralProvisionedScopes = {};
  final Set<String> _ephemeralConnectionOverrideScopes = {};
  final _authFailureController =
      StreamController<DeltaChatException>.broadcast(sync: true);
  bool _foregroundKeepaliveEnabled = false;
  bool _foregroundKeepaliveListenerAttached = false;
  bool _foregroundKeepaliveServiceAcquired = false;
  bool _foregroundKeepaliveTickScheduled = false;
  int _foregroundKeepaliveOperationId = 0;
  bool _reconnectRestartInFlight = false;
  final List<_PendingNotification> _pendingNotifications = [];
  Timer? _notificationFlushTimer;
  Timer? _contactsSyncTimer;
  String? _pendingPushToken;
  final _syncStateController =
      StreamController<EmailSyncState>.broadcast(sync: true);
  EmailSyncState _syncState = const EmailSyncState.ready();
  Timer? _connectivityDowngradeTimer;
  int? _pendingConnectivityLevel;
  int? _lastConnectivityValue;
  int? _lastLoggedConnectivityValue;
  DateTime? _lastConnectivityLoggedAt;
  bool _channelOverflowRecoveryInProgress = false;
  final Map<String, RegisteredCredentialKey> _bootstrapKeys = {};
  Future<void>? _bootstrapFuture;
  int _bootstrapOperationId = 0;
  EmailImapCapabilities _imapCapabilities = const EmailImapCapabilities(
    idleSupported: false,
    connectionLimit: _imapConnectionLimitSingle,
    idleCutoff: _imapIdleKeepaliveInterval,
  );
  DateTime? _imapCapabilitiesCheckedAt;
  bool _imapCapabilitiesResolved = false;
  Timer? _imapSyncTimer;
  var _imapSyncLoopActive = false;
  var _imapSyncInFlight = false;
  var _reconnectCatchUpInFlight = false;
  var _contactsSyncInFlight = false;
  var _contactsSyncPending = false;
  var _chatlistSyncInFlight = false;

  void updateEndpointConfig(EndpointConfig config) {
    _endpointConfig = config;
  }

  void updateMessageStorageMode(MessageStorageMode mode) {
    _transport.updateMessageStorageMode(mode);
  }

  Map<String, String> _buildConnectionConfig(String address) =>
      _connectionConfigBuilder(address, _endpointConfig);

  Map<String, String> _buildConnectionConfigForAuth({
    required String address,
    required EmailAuthMethod authMethod,
  }) {
    if (authMethod.isPassword) {
      return _buildConnectionConfig(address);
    }
    final Map<String, String> overrides =
        Map<String, String>.of(_buildConnectionConfig(address))
          ..[_serverFlagsConfigKey] = _serverFlagsOauthValue;
    final EmailOauthProvider? provider = emailOauthProviderForAddress(address);
    if (provider == null || !provider.isConfigured) {
      return overrides;
    }
    return overrides
      ..[_mailServerConfigKey] = provider.imapHost
      ..[_mailPortConfigKey] = provider.imapPort.toString()
      ..[_mailSecurityConfigKey] = provider.imapSecurity
      ..[_mailUserConfigKey] = address
      ..[_sendServerConfigKey] = provider.smtpHost
      ..[_sendPortConfigKey] = provider.smtpPort.toString()
      ..[_sendSecurityConfigKey] = provider.smtpSecurity
      ..[_sendUserConfigKey] = address;
  }

  bool _hasConnectionOverrides(Map<String, String> connectionOverrides) =>
      _connectionOverrideConfigKeys.any(connectionOverrides.containsKey);

  Future<bool> _isConnectionOverrideApplied({
    required String scope,
    required bool persistCredentials,
  }) async {
    if (_ephemeralConnectionOverrideScopes.contains(scope)) {
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
    _ephemeralConnectionOverrideScopes.add(scope);
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

  EmailAccount? get activeAccount => _activeAccount;

  bool get supportsMultipleLinkedAccounts => _transport.accountsSupported;

  int get linkedAccountLimit => _linkedEmailAccountsLimit;

  int get linkedAccountTotalLimit =>
      _linkedEmailAccountsPrimaryCount + _linkedEmailAccountsLimit;

  bool get isSmtpOnly =>
      _endpointConfig.enableSmtp && !_endpointConfig.enableXmpp;

  bool get isRunning => _running;

  bool get hasActiveSession =>
      _databasePrefix != null && _databasePassphrase != null;

  Stream<DeltaCoreEvent> get events => _transport.events;

  EmailSyncState get syncState => _syncState;

  Stream<EmailSyncState> get syncStateStream => _syncStateController.stream;

  Stream<DeltaChatException> get authFailureStream =>
      _authFailureController.stream;

  EmailAuthMethod preferredAuthMethodForAddress(String address) {
    final String normalized = _normalizeLinkedAccountAddress(address);
    if (normalized.isEmpty) {
      return EmailAuthMethod.password;
    }
    final EmailOauthProvider? provider =
        emailOauthProviderForAddress(normalized);
    if (provider != null && provider.isConfigured) {
      return EmailAuthMethod.oauth;
    }
    final String? domain = _domainFromAddress(normalized);
    if (domain == null || domain.isEmpty) {
      return EmailAuthMethod.password;
    }
    if (_oauthPreferredDomains.contains(domain)) {
      return EmailAuthMethod.oauth;
    }
    return EmailAuthMethod.password;
  }

  EmailOauthAuthorization? oauthAuthorizationForAddress({
    required String address,
    required String redirectUri,
  }) {
    final String normalizedAddress = _normalizeLinkedAccountAddress(address);
    if (normalizedAddress.isEmpty) {
      return null;
    }
    final String normalizedRedirect = redirectUri.trim();
    if (normalizedRedirect.isEmpty) {
      return null;
    }
    return buildEmailOauthAuthorization(
      address: normalizedAddress,
      redirectUri: normalizedRedirect,
    );
  }

  Future<String?> oauthUrlForAddress({
    required String address,
    required String redirectUri,
  }) async {
    await _ensureReady();
    final String normalizedAddress = _normalizeLinkedAccountAddress(address);
    if (normalizedAddress.isEmpty) {
      throw StateError(_linkedEmailAccountMissingAddressError);
    }
    final String normalizedRedirect = redirectUri.trim();
    if (normalizedRedirect.isEmpty) {
      return null;
    }
    final EmailOauthAuthorization? authorization = buildEmailOauthAuthorization(
      address: normalizedAddress,
      redirectUri: normalizedRedirect,
    );
    if (authorization != null) {
      return authorization.authorizationUrl;
    }
    return _transport.getOauth2Url(
      address: normalizedAddress,
      redirectUri: normalizedRedirect,
    );
  }

  Future<EmailOauthTokens?> _exchangeOauthCode({
    required EmailOauthProvider provider,
    required String authorizationCode,
    required EmailOauthAuthorization? authorization,
  }) async {
    if (authorization == null || authorization.provider != provider) {
      return null;
    }
    final Map<String, String> body = <String, String>{
      'grant_type': _oauthGrantTypeAuthorizationCode,
      'code': authorizationCode,
      'redirect_uri': authorization.redirectUri,
      'client_id': provider.clientId,
      'code_verifier': authorization.codeVerifier,
    };
    final String clientSecret = provider.clientSecret;
    if (clientSecret.isNotEmpty) {
      body['client_secret'] = clientSecret;
    }
    final Map<String, dynamic> payload = await _requestOauthToken(
      provider: provider,
      body: body,
    );
    return _parseOauthTokens(
      payload: payload,
      fallbackRefreshToken: '',
    );
  }

  Future<EmailOauthTokens> _refreshOauthToken({
    required EmailOauthProvider provider,
    required String refreshToken,
  }) async {
    final Map<String, String> body = <String, String>{
      'grant_type': _oauthGrantTypeRefreshToken,
      'refresh_token': refreshToken,
      'client_id': provider.clientId,
    };
    final String clientSecret = provider.clientSecret;
    if (clientSecret.isNotEmpty) {
      body['client_secret'] = clientSecret;
    }
    final Map<String, dynamic> payload = await _requestOauthToken(
      provider: provider,
      body: body,
    );
    return _parseOauthTokens(
      payload: payload,
      fallbackRefreshToken: refreshToken,
    );
  }

  Future<String?> _ensureOauthAccessToken({
    required String scope,
    required EmailAccountId accountId,
    required EmailOauthProvider provider,
  }) async {
    final String? currentToken = await _readLinkedAccountOauthAccessToken(
      scope: scope,
      accountId: accountId,
    );
    final DateTime? expiresAt = await _readLinkedAccountOauthExpiry(
      scope: scope,
      accountId: accountId,
    );
    final DateTime now = DateTime.now().toUtc();
    if (currentToken != null &&
        currentToken.isNotEmpty &&
        expiresAt != null &&
        expiresAt.isAfter(now.add(_oauthTokenExpirySkew))) {
      return currentToken;
    }
    final String? refreshToken = await _readLinkedAccountOauthRefreshToken(
      scope: scope,
      accountId: accountId,
    );
    if (refreshToken == null || refreshToken.isEmpty) {
      return currentToken;
    }
    final EmailOauthTokens refreshed = await _refreshOauthToken(
      provider: provider,
      refreshToken: refreshToken,
    );
    await _writeLinkedAccountOauthTokens(
      scope: scope,
      accountId: accountId,
      provider: provider,
      tokens: refreshed,
    );
    await _credentialStore.write(
      key: _linkedAccountPasswordKeyFor(
        scope: scope,
        accountId: accountId,
      ),
      value: refreshed.accessToken,
    );
    return refreshed.accessToken;
  }

  Future<Map<String, dynamic>> _requestOauthToken({
    required EmailOauthProvider provider,
    required Map<String, String> body,
  }) async {
    final Uri endpoint = Uri.parse(provider.tokenEndpoint);
    http.Response response;
    try {
      response = await http.post(
        endpoint,
        headers: const <String, String>{
          'Content-Type': _oauthTokenContentType,
        },
        body: body,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(_oauthTokenExchangeFailureLog, error, stackTrace);
      rethrow;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _log.warning(
        _oauthTokenExchangeFailureLog,
        'Status: ${response.statusCode}',
      );
      throw const EmailProvisioningException(
        'Unable to authenticate with the email provider.',
        shouldWipeCredentials: true,
      );
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const EmailProvisioningException(
        'Unable to authenticate with the email provider.',
        shouldWipeCredentials: true,
      );
    }
    return decoded;
  }

  EmailOauthTokens _parseOauthTokens({
    required Map<String, dynamic> payload,
    required String fallbackRefreshToken,
  }) {
    final String? accessToken = payload[_oauthTokenAccessKey] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const EmailProvisioningException(
        'Unable to authenticate with the email provider.',
        shouldWipeCredentials: true,
      );
    }
    final String refreshToken =
        (payload[_oauthTokenRefreshKey] as String?) ?? fallbackRefreshToken;
    final int expiresIn =
        _parseOauthExpiresIn(payload[_oauthTokenExpiresInKey]);
    final DateTime expiresAt =
        DateTime.now().toUtc().add(Duration(seconds: expiresIn));
    return EmailOauthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  int _parseOauthExpiresIn(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is String) {
      final int? parsed = int.tryParse(raw);
      if (parsed != null) {
        return parsed;
      }
    }
    return _oauthTokenExpiryFallbackSeconds;
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
    return EmailAccount(
      address: address,
      password: password,
    );
  }

  Future<List<EmailAccountProfile>> linkedAccounts(String jid) async {
    final String scope = _scopeForJid(jid);
    final List<EmailAccountId> accountIds = await _readLinkedAccountIds(
      scope,
      includeLegacy: true,
    );
    if (accountIds.isEmpty) {
      final EmailAccountProfile? legacy = await _legacyAccountProfileForScope(
        scope,
      );
      if (legacy == null) {
        return const <EmailAccountProfile>[];
      }
      return <EmailAccountProfile>[legacy];
    }
    final EmailAccountId? primaryId = await _readPrimaryAccountId(
      scope,
      fallbackIds: accountIds,
    );
    final List<EmailAccountProfile> profiles = <EmailAccountProfile>[];
    for (final EmailAccountId accountId in accountIds) {
      final EmailAccountProfile? profile = await _readLinkedAccountProfile(
        scope: scope,
        accountId: accountId,
        primaryId: primaryId,
      );
      if (profile != null) {
        profiles.add(profile);
      }
    }
    final List<EmailAccountProfile> sorted = List<EmailAccountProfile>.of(
      profiles,
    )..sort(_compareLinkedAccountProfiles);
    return List<EmailAccountProfile>.unmodifiable(sorted);
  }

  Future<List<EmailAccountProfile>> linkedAccountsForActiveScope() async {
    final String? scope = _activeCredentialScope;
    if (scope == null) {
      return const <EmailAccountProfile>[];
    }
    return linkedAccounts(scope);
  }

  Future<EmailAccountProfile?> primaryLinkedAccount(String jid) async {
    final List<EmailAccountProfile> accounts = await linkedAccounts(jid);
    if (accounts.isEmpty) {
      return null;
    }
    for (final EmailAccountProfile account in accounts) {
      if (account.isPrimary) {
        return account;
      }
    }
    return accounts.first;
  }

  Future<EmailAccountProfile?> linkedAccountProfile({
    required String jid,
    required EmailAccountId accountId,
  }) async {
    final String scope = _scopeForJid(jid);
    final EmailAccountId? primaryId = await _readPrimaryAccountId(scope);
    return _readLinkedAccountProfile(
      scope: scope,
      accountId: accountId,
      primaryId: primaryId,
    );
  }

  Future<EmailAccount?> linkedAccountCredentials({
    required String jid,
    required EmailAccountId accountId,
  }) async {
    final String scope = _scopeForJid(jid);
    String? address = await _credentialStore.read(
      key: _linkedAccountAddressKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
    String? password = await _credentialStore.read(
      key: _linkedAccountPasswordKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
    if (password == null || password.isEmpty) {
      final EmailAccountId? legacyId = await _legacyAccountIdForScope(scope);
      if (legacyId != null && legacyId == accountId) {
        address ??= await _credentialStore.read(
          key: _addressKeyForScope(scope),
        );
        password ??= await _credentialStore.read(
          key: _passwordKeyForScope(scope),
        );
      }
    }
    final String normalizedAddress = _normalizeLinkedAccountAddress(
      address ?? accountId.value,
    );
    if (normalizedAddress.isEmpty) {
      return null;
    }
    final EmailAuthMethod authMethod = await _readLinkedAccountAuthMethod(
      scope: scope,
      accountId: accountId,
    );
    if (authMethod.isOauth) {
      final EmailOauthProvider? provider =
          await _readLinkedAccountOauthProvider(
        scope: scope,
        accountId: accountId,
      );
      final EmailOauthProvider? resolvedProvider = provider ??
          emailOauthProviderForAddress(
            normalizedAddress,
          );
      if (resolvedProvider != null && resolvedProvider.isConfigured) {
        final String? refreshed = await _ensureOauthAccessToken(
          scope: scope,
          accountId: accountId,
          provider: resolvedProvider,
        );
        if (refreshed != null && refreshed.isNotEmpty) {
          password = refreshed;
        }
      }
    }
    if (password == null || password.isEmpty) {
      return null;
    }
    return EmailAccount(
      address: normalizedAddress,
      password: password,
    );
  }

  Future<EmailAccountProfile> linkAccount({
    required String jid,
    required String address,
    required String password,
    String? displayName,
    bool setPrimary = false,
    EmailAuthMethod authMethod = EmailAuthMethod.password,
    EmailOauthAuthorization? oauthAuthorization,
  }) async {
    final String scope = _scopeForJid(jid);
    final String normalizedAddress = _normalizeLinkedAccountAddress(address);
    if (normalizedAddress.isEmpty) {
      throw StateError(_linkedEmailAccountMissingAddressError);
    }
    final String trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) {
      throw StateError(_linkedEmailAccountMissingPasswordError);
    }
    final EmailOauthProvider? oauthProvider = authMethod.isOauth
        ? emailOauthProviderForAddress(normalizedAddress)
        : null;
    final bool oauthConfigured =
        oauthProvider != null && oauthProvider.isConfigured;
    final EmailOauthTokens? oauthTokens = oauthConfigured
        ? await _exchangeOauthCode(
            provider: oauthProvider,
            authorization: oauthAuthorization,
            authorizationCode: trimmedPassword,
          )
        : null;
    final String normalizedPassword = oauthTokens?.accessToken ?? password;
    final EmailAccountId? accountId = EmailAccountId.fromAddress(
      normalizedAddress,
    );
    if (accountId == null) {
      throw StateError(_linkedEmailAccountMissingAddressError);
    }

    await _hydrateLegacyAccountIfNeeded(scope);
    final List<EmailAccountId> currentIds = await _readLinkedAccountIds(
      scope,
      includeLegacy: true,
    );
    final bool alreadyLinked = currentIds.contains(accountId);
    if (!_transport.accountsSupported &&
        !alreadyLinked &&
        currentIds.isNotEmpty) {
      throw StateError(_linkedEmailAccountsUnsupportedError);
    }
    const int maxAccounts =
        _linkedEmailAccountsPrimaryCount + _linkedEmailAccountsLimit;
    if (!alreadyLinked && currentIds.length >= maxAccounts) {
      throw const EmailAccountLimitException(limit: _linkedEmailAccountsLimit);
    }

    final List<EmailAccountId> nextIds = List<EmailAccountId>.of(currentIds)
      ..removeWhere((EmailAccountId entry) => entry == accountId)
      ..add(accountId);
    await _writeLinkedAccountIds(scope, nextIds);

    await _credentialStore.write(
      key: _linkedAccountAddressKeyFor(
        scope: scope,
        accountId: accountId,
      ),
      value: normalizedAddress,
    );
    await _credentialStore.write(
      key: _linkedAccountPasswordKeyFor(
        scope: scope,
        accountId: accountId,
      ),
      value: normalizedPassword,
    );
    if (oauthTokens != null && oauthProvider != null) {
      await _writeLinkedAccountOauthTokens(
        scope: scope,
        accountId: accountId,
        provider: oauthProvider,
        tokens: oauthTokens,
      );
    } else if (authMethod.isOauth) {
      await _clearLinkedAccountOauthTokens(
        scope: scope,
        accountId: accountId,
      );
    } else {
      await _clearLinkedAccountOauthTokens(
        scope: scope,
        accountId: accountId,
      );
    }
    await _credentialStore.write(
      key: _linkedAccountAuthMethodKeyFor(
        scope: scope,
        accountId: accountId,
      ),
      value: authMethod.storageValue,
    );
    final bool displayNameProvided = displayName != null;
    final String? normalizedDisplayName = _normalizeDisplayName(displayName);
    final RegisteredCredentialKey displayNameKey =
        _linkedAccountDisplayNameKeyFor(
      scope: scope,
      accountId: accountId,
    );
    if (displayNameProvided) {
      if (normalizedDisplayName == null) {
        await _credentialStore.delete(key: displayNameKey);
      } else {
        await _credentialStore.write(
          key: displayNameKey,
          value: normalizedDisplayName,
        );
      }
    }
    final bool shouldSetPrimary = setPrimary || currentIds.isEmpty;
    if (shouldSetPrimary) {
      await _credentialStore.write(
        key: _linkedAccountPrimaryKeyForScope(scope),
        value: accountId.value,
      );
    }
    final String? storedDisplayName = displayNameProvided
        ? normalizedDisplayName
        : await _credentialStore.read(key: displayNameKey);
    final String resolvedDisplayName = _displayNameForAddress(
      normalizedAddress,
      displayName: storedDisplayName,
    );
    final int? deltaAccountId = await _readLinkedAccountDeltaId(
      scope: scope,
      accountId: accountId,
    );
    return EmailAccountProfile(
      id: accountId,
      address: normalizedAddress,
      displayName: resolvedDisplayName,
      authMethod: authMethod,
      isPrimary: shouldSetPrimary,
      deltaAccountId: deltaAccountId,
    );
  }

  Future<void> provisionLinkedAccount({
    required String jid,
    required EmailAccountId accountId,
  }) async {
    await _ensureReady();
    final String scope = _scopeForJid(jid);
    final String normalizedAddress = _normalizeLinkedAccountAddress(
      accountId.value,
    );
    if (normalizedAddress.isEmpty) {
      throw StateError(_linkedEmailAccountMissingAddressError);
    }
    final _ResolvedEmailAccount account = await _resolveAccountForAddress(
      scope: scope,
      fromAddress: normalizedAddress,
    );
    await _ensureAccountConfigured(scope: scope, account: account);
    unawaited(syncInboxAndSent());
  }

  Future<void> updateLinkedAccountPassword({
    required String jid,
    required EmailAccountId accountId,
    required String password,
    EmailOauthAuthorization? oauthAuthorization,
  }) async {
    await _ensureReady();
    final String scope = _scopeForJid(jid);
    final String trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) {
      throw StateError(_linkedEmailAccountMissingPasswordError);
    }
    await _ensureLinkedAccountExists(
      scope: scope,
      accountId: accountId,
    );
    final EmailAuthMethod authMethod = await _readLinkedAccountAuthMethod(
      scope: scope,
      accountId: accountId,
    );
    final EmailOauthProvider? oauthProvider = authMethod.isOauth
        ? emailOauthProviderForAddress(accountId.value)
        : null;
    final bool oauthConfigured =
        oauthProvider != null && oauthProvider.isConfigured;
    final EmailOauthTokens? oauthTokens = oauthConfigured
        ? await _exchangeOauthCode(
            provider: oauthProvider,
            authorization: oauthAuthorization,
            authorizationCode: trimmedPassword,
          )
        : null;
    final String storedPassword = oauthTokens?.accessToken ?? password;
    await _credentialStore.write(
      key: _linkedAccountPasswordKeyFor(
        scope: scope,
        accountId: accountId,
      ),
      value: storedPassword,
    );
    if (oauthTokens != null && oauthProvider != null) {
      await _writeLinkedAccountOauthTokens(
        scope: scope,
        accountId: accountId,
        provider: oauthProvider,
        tokens: oauthTokens,
      );
    } else if (authMethod.isOauth) {
      await _clearLinkedAccountOauthTokens(
        scope: scope,
        accountId: accountId,
      );
    } else {
      await _clearLinkedAccountOauthTokens(
        scope: scope,
        accountId: accountId,
      );
    }
    final String normalizedAddress = _normalizeLinkedAccountAddress(
      accountId.value,
    );
    if (normalizedAddress.isEmpty) {
      throw StateError(_linkedEmailAccountMissingAddressError);
    }
    final _ResolvedEmailAccount account = await _resolveAccountForAddress(
      scope: scope,
      fromAddress: normalizedAddress,
    );
    await _ensureAccountConfigured(
      scope: scope,
      account: account,
      forceProvisioning: true,
    );
    unawaited(syncInboxAndSent());
  }

  Future<void> setPrimaryLinkedAccount({
    required String jid,
    required EmailAccountId accountId,
  }) async {
    final String scope = _scopeForJid(jid);
    await _ensureLinkedAccountExists(
      scope: scope,
      accountId: accountId,
    );
    await _credentialStore.write(
      key: _linkedAccountPrimaryKeyForScope(scope),
      value: accountId.value,
    );
    final bool transportReady =
        _databasePrefix != null && _databasePassphrase != null;
    final int? deltaAccountId = transportReady
        ? await _ensureLinkedAccountDeltaId(
            scope: scope,
            accountId: accountId,
          )
        : await _readLinkedAccountDeltaId(
            scope: scope,
            accountId: accountId,
          );
    if (deltaAccountId == null) return;
    _transport.setPrimaryAccountId(deltaAccountId);
    final EmailAccountProfile? profile = await _linkedAccountProfileForScope(
      scope: scope,
      accountId: accountId,
    );
    final String address =
        profile?.address ?? _normalizeLinkedAccountAddress(accountId.value);
    if (address.isEmpty) {
      return;
    }
    await _hydrateAccountAddress(
      address: address,
      deltaAccountId: deltaAccountId,
    );
  }

  Future<void> setChatFromAddress({
    required Chat chat,
    EmailAccountId? accountId,
  }) async {
    await _ensureReady();
    final String scope = _requireActiveScope();
    String? resolvedAddress;
    if (accountId != null) {
      final String normalizedAddress = _normalizeLinkedAccountAddress(
        accountId.value,
      );
      if (normalizedAddress.isEmpty) {
        throw StateError(_linkedEmailAccountMissingAddressError);
      }
      await _ensureLinkedAccountExists(
        scope: scope,
        accountId: accountId,
      );
      final int deltaAccountId = await _ensureLinkedAccountDeltaId(
        scope: scope,
        accountId: accountId,
      );
      await _hydrateAccountAddress(
        address: normalizedAddress,
        deltaAccountId: deltaAccountId,
      );
      resolvedAddress = normalizedAddress;
    }
    await _updateChatEmailFromAddress(chat, resolvedAddress);
  }

  Future<void> unlinkAccount({
    required String jid,
    required EmailAccountId accountId,
  }) async {
    final String scope = _scopeForJid(jid);
    final List<EmailAccountId> accountIds = await _readLinkedAccountIds(
      scope,
      includeLegacy: true,
    );
    if (accountIds.isEmpty) {
      return;
    }
    final int? linkedDeltaAccountId = await _readLinkedAccountDeltaId(
      scope: scope,
      accountId: accountId,
    );
    final List<EmailAccountId> nextIds = List<EmailAccountId>.of(accountIds)
      ..removeWhere((EmailAccountId entry) => entry == accountId);
    await _writeLinkedAccountIds(scope, nextIds);
    final RegisteredCredentialKey addressKey = _linkedAccountAddressKeyFor(
      scope: scope,
      accountId: accountId,
    );
    final String? storedAddress = await _credentialStore.read(
      key: addressKey,
    );
    final String normalizedAddress = _normalizeLinkedAccountAddress(
      storedAddress ?? accountId.value,
    );
    await _credentialStore.delete(
      key: addressKey,
    );
    await _credentialStore.delete(
      key: _linkedAccountPasswordKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
    await _clearLinkedAccountOauthTokens(
      scope: scope,
      accountId: accountId,
    );
    await _credentialStore.delete(
      key: _linkedAccountDisplayNameKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
    await _credentialStore.delete(
      key: _linkedAccountDeltaIdKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
    await _credentialStore.delete(
      key: _linkedAccountProvisionedKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
    final bool hasNormalizedAddress = normalizedAddress.isNotEmpty;
    final bool hasLinkedDeltaId = linkedDeltaAccountId != null;
    if (hasNormalizedAddress || hasLinkedDeltaId) {
      final XmppDatabase db = await _databaseBuilder();
      if (hasNormalizedAddress) {
        await db.clearChatsEmailFromAddress(normalizedAddress);
      }
      if (hasLinkedDeltaId) {
        await db.deleteEmailChatAccountsForAccount(linkedDeltaAccountId);
      }
    }
    final bool transportReady =
        _databasePrefix != null && _databasePassphrase != null;
    if (transportReady &&
        _transport.accountsSupported &&
        linkedDeltaAccountId != null &&
        linkedDeltaAccountId != deltaAccountIdLegacy) {
      try {
        await _transport.removeAccount(linkedDeltaAccountId);
      } on Exception catch (error, stackTrace) {
        _log.warning(
          _linkedEmailAccountRemovalFailureLogMessage,
          error,
          stackTrace,
        );
      }
    }
    final EmailAccountId? primaryId = await _readPrimaryAccountId(scope);
    if (primaryId == null || primaryId != accountId) {
      return;
    }
    if (nextIds.isEmpty) {
      await _credentialStore.delete(
        key: _linkedAccountPrimaryKeyForScope(scope),
      );
      _transport.setPrimaryAccountId(null);
      return;
    }
    await _credentialStore.write(
      key: _linkedAccountPrimaryKeyForScope(scope),
      value: nextIds.first.value,
    );
    await setPrimaryLinkedAccount(
      jid: jid,
      accountId: nextIds.first,
    );
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
    final scope = _scopeForJid(jid);
    final needsInit = _databasePrefix != databasePrefix ||
        _databasePassphrase != databasePassphrase;
    if (needsInit) {
      _databasePrefix = databasePrefix;
      _databasePassphrase = databasePassphrase;
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
    final normalizedOverrideAddress = addressOverride?.trim().toLowerCase();
    final preferredAddress = _preferredAddressFromJid(jid);
    var credentialsMutated = false;
    final shouldPersistCredentials = persistCredentials;

    final resolvedAddress = (normalizedOverrideAddress != null &&
            normalizedOverrideAddress.isNotEmpty)
        ? normalizedOverrideAddress
        : ((address != null && address.isNotEmpty)
            ? address
            : preferredAddress);
    if (resolvedAddress == null || resolvedAddress.isEmpty) {
      throw StateError('Failed to resolve email address.');
    }
    if (address == null || address != resolvedAddress) {
      address = resolvedAddress;
      credentialsMutated = true;
      if (shouldPersistCredentials) {
        await _credentialStore.write(key: addressKey, value: address);
      }
    }

    final connectionOverrides = _buildConnectionConfig(resolvedAddress);

    final resolvedPasswordOverride = passwordOverride;
    if (resolvedPasswordOverride != null &&
        resolvedPasswordOverride.isNotEmpty &&
        (password == null || password != resolvedPasswordOverride)) {
      password = resolvedPasswordOverride;
      credentialsMutated = true;
      if (shouldPersistCredentials) {
        await _credentialStore.write(key: passwordKey, value: password);
      }
    }

    final EmailAccountId? emailAccountId = EmailAccountId.fromAddress(
      resolvedAddress,
    );
    if (emailAccountId == null) {
      throw StateError(_linkedEmailAccountMissingAddressError);
    }
    final int deltaAccountId = await _ensureLinkedAccountDeltaId(
      scope: scope,
      accountId: emailAccountId,
    );
    await _transport.ensureAccountSession(deltaAccountId);
    _transport.setPrimaryAccountId(deltaAccountId);
    final RegisteredCredentialKey linkedProvisionedKey =
        _linkedAccountProvisionedKeyFor(
      scope: scope,
      accountId: emailAccountId,
    );
    var alreadyProvisioned =
        (await _credentialStore.read(key: linkedProvisionedKey)) ==
            _linkedEmailAccountBoolTrue;
    if (!alreadyProvisioned) {
      alreadyProvisioned = (await _credentialStore.read(key: provisionedKey)) ==
          _credentialTrueValue;
    }
    if (!shouldPersistCredentials &&
        _ephemeralProvisionedScopes.contains(scope)) {
      alreadyProvisioned = true;
    }
    var transportConfigured = false;
    final shouldForceProvisioning =
        shouldPersistCredentials && credentialsMutated;
    if (shouldForceProvisioning) {
      alreadyProvisioned = false;
      _ephemeralProvisionedScopes.remove(scope);
      if (shouldPersistCredentials) {
        await _credentialStore.write(
          key: provisionedKey,
          value: _credentialFalseValue,
        );
        await _credentialStore.write(
          key: linkedProvisionedKey,
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
        _ephemeralProvisionedScopes.remove(scope);
        if (shouldPersistCredentials) {
          await _credentialStore.write(
            key: provisionedKey,
            value: _credentialFalseValue,
          );
          await _credentialStore.write(
            key: linkedProvisionedKey,
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
        await _credentialStore.write(
          key: linkedProvisionedKey,
          value: _linkedEmailAccountBoolTrue,
        );
      }
      alreadyProvisioned = true;
      requiresReconfigure = false;
    }

    final needsProvisioning = !alreadyProvisioned;
    final pausedForProvisioning = needsProvisioning && _running;
    if (pausedForProvisioning) {
      await stop();
    }

    final normalizedAddress = address;
    if (needsProvisioning && !hasPassword) {
      throw StateError('Failed to resolve email password.');
    }
    final normalizedPassword = password;

    if (needsProvisioning) {
      _log.info('Configuring email account credentials');
      try {
        await _transport.configureAccount(
          address: normalizedAddress,
          password: normalizedPassword!,
          displayName: displayName,
          additional: connectionOverrides,
          accountId: deltaAccountId,
        );
        _resetImapCapabilities();
        await _transport.purgeStockMessages(accountId: deltaAccountId);
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
          await _credentialStore.write(
            key: linkedProvisionedKey,
            value: _linkedEmailAccountBoolTrue,
          );
        } else {
          _ephemeralProvisionedScopes.add(scope);
        }
      } on DeltaSafeException catch (error, stackTrace) {
        if (shouldPersistCredentials) {
          await _credentialStore.write(
            key: provisionedKey,
            value: _credentialFalseValue,
          );
          await _credentialStore.write(
            key: linkedProvisionedKey,
            value: _credentialFalseValue,
          );
        } else {
          _ephemeralProvisionedScopes.remove(scope);
        }
        final isTimeout = error.message.toLowerCase().contains('timed out');
        final mapped = DeltaChatExceptionMapper.fromDeltaSafe(
          error,
          operation: 'configure email account',
        );
        final errorType = error.runtimeType;
        _log.warning(
          'Failed to configure email account ($errorType)',
          null,
          stackTrace,
        );
        final shouldClearCredentials =
            credentialsMutated && mapped.code == DeltaChatErrorCode.auth;
        if (shouldClearCredentials) {
          await _clearCredentials(scope);
        }
        if (isTimeout) {
          throw const EmailProvisioningException(
            'Setting up email is taking longer than expected. '
            'Please leave Axichat open—we will keep retrying in the background.',
            isRecoverable: true,
          );
        }
        if (mapped.code == DeltaChatErrorCode.network ||
            mapped.code == DeltaChatErrorCode.server) {
          throw const EmailProvisioningException(
            'Unable to reach the email service. Please try again.',
            isRecoverable: true,
          );
        }
        throw EmailProvisioningException(
          'Unable to configure email. Please check your credentials.',
          shouldWipeCredentials: mapped.code == DeltaChatErrorCode.permission ||
              mapped.code == DeltaChatErrorCode.auth,
        );
      }
    } else {
      _log.fine(
        'Reusing existing email account credentials without reconfiguration.',
      );
    }

    await _hydrateAccountAddress(
      address: normalizedAddress,
      deltaAccountId: deltaAccountId,
    );
    await start();
    unawaited(_refreshImapCapabilities(force: true));
    await _applyPendingPushToken();

    final account = EmailAccount(
      address: normalizedAddress,
      password: normalizedPassword ?? _unknownEmailPassword,
    );
    _activeAccount = account;
    _ephemeralProvisionedScopes.add(scope);
    await _credentialStore.write(
      key: _linkedAccountDeltaIdKeyFor(
        scope: scope,
        accountId: emailAccountId,
      ),
      value: deltaAccountId.toString(),
    );
    unawaited(
      _bootstrapFromCoreIfNeeded(scope: scope, databasePrefix: databasePrefix),
    );
    unawaited(
      _ensureLinkedAccountsProvisioned(
        scope: scope,
      ),
    );
    return account;
  }

  Future<void> updatePassword({
    required String jid,
    required String displayName,
    required String password,
  }) async {
    await _ensureReady();
    final scope = _scopeForJid(jid);
    final address = await _credentialStore.read(
      key: _addressKeyForScope(scope),
    );
    if (address == null || address.isEmpty) {
      throw StateError('No email address found.');
    }
    final EmailAccountId? accountId = EmailAccountId.fromAddress(address);
    if (accountId == null) {
      throw StateError(_linkedEmailAccountMissingAddressError);
    }
    final int deltaAccountId = await _ensureLinkedAccountDeltaId(
      scope: scope,
      accountId: accountId,
    );
    _transport.setPrimaryAccountId(deltaAccountId);
    await _credentialStore.write(
      key: _passwordKeyForScope(scope),
      value: password,
    );
    final connectionOverrides = _buildConnectionConfig(address);
    await _credentialStore.write(
      key: _linkedAccountPasswordKeyFor(
        scope: scope,
        accountId: accountId,
      ),
      value: password,
    );
    await _transport.configureAccount(
      address: address,
      password: password,
      displayName: displayName,
      additional: connectionOverrides,
      accountId: deltaAccountId,
    );
    await _credentialStore.write(
      key: _provisionedKeyForScope(scope),
      value: _credentialTrueValue,
    );
    await _credentialStore.write(
      key: _linkedAccountProvisionedKeyFor(
        scope: scope,
        accountId: accountId,
      ),
      value: _linkedEmailAccountBoolTrue,
    );
    _resetImapCapabilities();
    unawaited(_refreshImapCapabilities(force: true));
    await _hydrateAccountAddress(
      address: address,
      deltaAccountId: deltaAccountId,
    );
    _activeCredentialScope = scope;
    _activeAccount = EmailAccount(address: address, password: password);
    await _markConnectionOverridesApplied(
      scope: scope,
      persistCredentials: true,
      connectionOverrides: connectionOverrides,
    );
  }

  Future<void> start() async {
    if (_running) return;
    await _transport.start();
    _running = true;
    await _applyDownloadLimit();
    _startImapSyncLoop();
  }

  Future<void> stop() async {
    if (!_running) return;
    await _transport.stop();
    _running = false;
    _stopImapSyncLoop();
    _cancelContactsSyncTimer();
    _contactsSyncPending = false;
    _cancelConnectivityDowngrade();
  }

  Future<void> ensureEventChannelActive() async {
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
    if (!_running) {
      await start();
    }
  }

  Future<void> shutdown({
    String? jid,
    bool clearCredentials = false,
  }) async {
    await stop();
    await _stopForegroundKeepalive();
    _resetImapCapabilities();
    _clearNotificationQueue();
    if (!clearCredentials) {
      return;
    }
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

  Future<void> burn({String? jid}) async {
    final scope = _scopeForOptionalJid(jid);
    await stop();
    try {
      await _transport.deconfigureAccount();
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to deconfigure email account', error, stackTrace);
    }
    _detachTransportListener();
    await _stopForegroundKeepalive();
    _clearNotificationQueue();
    await _transport.dispose();
    await _transport.deleteStorageArtifacts();
    _running = false;
    if (scope != null) {
      await _clearCredentials(scope);
    }
    _databasePrefix = null;
    _databasePassphrase = null;
    _activeAccount = null;
    _activeCredentialScope = null;
    _pendingPushToken = null;
  }

  Future<Chat> ensureChatForAddress({
    required String address,
    String? displayName,
    String? fromAddress,
  }) async {
    await _ensureReady();
    final String scope = _requireActiveScope();
    final _ResolvedEmailAccount account = await _resolveAccountForAddress(
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
    return _waitForChat(
      chatId,
      accountId: account.deltaAccountId,
    );
  }

  Future<Chat> ensureChatForEmailChat(Chat chat) async {
    final context = await _ensureEmailChatContext(chat);
    final db = await _databaseBuilder();
    return await db.getChat(context.chat.jid) ?? context.chat;
  }

  Future<int> sendMessage({
    required Chat chat,
    required String body,
    String? subject,
    String? htmlBody,
  }) async {
    final context = await _ensureEmailChatContext(chat);
    final chatId = context.deltaChatId;
    await _ensureReady();
    final normalizedSubject = _normalizeSubject(subject);
    final normalizedHtml = HtmlContentCodec.normalizeHtml(htmlBody);
    final trimmedBody = body.trim();
    final resolvedBody = trimmedBody.isNotEmpty
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
      final senderJid = _transport.selfJidForAccount(
            context.account.deltaAccountId,
          ) ??
          context.account.address;
      final participants = await _shareParticipants(
        shareId: shareId,
        chats: [context.chat],
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
              body: resolvedBody,
            ),
          )
        : _composeSubjectEnvelope(
            subject: normalizedSubject,
            body: resolvedBody,
          );
    final localBodyOverride =
        trimmedBody.isNotEmpty ? trimmedBody : resolvedBody;
    final msgId = await _guardDeltaOperation(
      operation: 'send email message',
      body: () => _transport.sendText(
        chatId: chatId,
        body: transmitBody,
        subject: normalizedSubject,
        shareId: shareId,
        localBodyOverride: localBodyOverride,
        htmlBody: normalizedHtml,
        accountId: context.account.deltaAccountId,
      ),
    );
    if (shareId != null) {
      final db = await _databaseBuilder();
      await db.assignShareOriginator(
        shareId: shareId,
        originatorDcMsgId: msgId,
      );
    }
    return msgId;
  }

  Future<int> sendAttachment({
    required Chat chat,
    required EmailAttachment attachment,
    String? subject,
    String? htmlCaption,
  }) async {
    final context = await _ensureEmailChatContext(chat);
    final chatId = context.deltaChatId;
    await _ensureReady();
    final normalizedSubject = _normalizeSubject(subject);
    final normalizedHtml = HtmlContentCodec.normalizeHtml(htmlCaption);
    String? shareId;
    if (normalizedSubject != null) {
      shareId = ShareTokenCodec.generateShareId();
      final db = await _databaseBuilder();
      final senderJid = _transport.selfJidForAccount(
            context.account.deltaAccountId,
          ) ??
          context.account.address;
      final participants = await _shareParticipants(
        shareId: shareId,
        chats: [context.chat],
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
    var captionText = attachment.caption?.trim() ?? '';
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
        attachment: attachment.copyWith(caption: captionEnvelope),
        subject: normalizedSubject,
        shareId: shareId,
        captionOverride: sanitizedCaption,
        htmlCaption: normalizedHtml,
        accountId: context.account.deltaAccountId,
      ),
    );
    if (shareId != null) {
      final db = await _databaseBuilder();
      await db.assignShareOriginator(
        shareId: shareId,
        originatorDcMsgId: msgId,
      );
    }
    return msgId;
  }

  Future<FanOutSendReport> fanOutSend({
    required List<FanOutTarget> targets,
    String? body,
    String? htmlBody,
    EmailAttachment? attachment,
    String? htmlCaption,
    bool useSubjectToken = true,
    bool tokenAsSignature = true,
    String? shareId,
    String? subject,
  }) async {
    await _ensureReady();
    if (targets.isEmpty) {
      throw const FanOutValidationException('Select at least one recipient.');
    }
    final resolvedTargets = await _resolveFanOutTargets(targets);
    if (resolvedTargets.isEmpty) {
      throw const FanOutValidationException('Unable to resolve recipients.');
    }
    if (resolvedTargets.length > _maxFanOutRecipients) {
      throw const FanOutValidationException(
        'Fan-out limited to $_maxFanOutRecipients recipients.',
      );
    }
    final trimmedBody = body?.trim() ?? '';
    final normalizedHtmlBody = HtmlContentCodec.normalizeHtml(htmlBody);
    var resolvedBodyText = trimmedBody;
    if (resolvedBodyText.isEmpty && normalizedHtmlBody != null) {
      resolvedBodyText = HtmlContentCodec.toPlainText(normalizedHtmlBody);
    }
    final hasBody = resolvedBodyText.isNotEmpty;
    final normalizedSubject = _normalizeSubject(subject);
    final hasSubject = normalizedSubject != null;
    final hasAttachment = attachment != null;
    final normalizedHtmlCaption = HtmlContentCodec.normalizeHtml(htmlCaption);
    if (!hasBody && !hasAttachment && !hasSubject) {
      throw const FanOutValidationException('Message cannot be empty.');
    }
    final db = await _databaseBuilder();
    final existingShare =
        shareId == null ? null : await db.getMessageShareById(shareId);
    final existingParticipants = <MessageParticipantData>[];
    final existingShareId = existingShare?.shareId ?? shareId;
    if (existingShareId != null) {
      existingParticipants
          .addAll(await db.getParticipantsForShare(existingShareId));
    }
    final resolvedShareId =
        shareId ?? existingShare?.shareId ?? ShareTokenCodec.generateShareId();
    final shouldUseToken = useSubjectToken && resolvedTargets.length > 1;
    final resolvedToken = existingShare?.subjectToken ??
        (shouldUseToken ? _shareTokenForShare(resolvedShareId) : null);
    final resolvedSubject = normalizedSubject ?? existingShare?.subject;
    final resolvedHtmlBody = resolvedToken == null
        ? normalizedHtmlBody
        : ShareTokenHtmlCodec.injectToken(
            html: normalizedHtmlBody,
            token: resolvedToken,
            asSignature: tokenAsSignature,
          );
    final resolvedHtmlCaption = resolvedToken == null
        ? normalizedHtmlCaption
        : ShareTokenHtmlCodec.injectToken(
            html: normalizedHtmlCaption,
            token: resolvedToken,
            asSignature: tokenAsSignature,
          );

    final transmitBody = resolvedToken != null
        ? ShareTokenCodec.injectToken(
            token: resolvedToken,
            body: _composeSubjectEnvelope(
              subject: resolvedSubject,
              body: resolvedBodyText,
            ),
            asSignature: tokenAsSignature,
          )
        : _composeSubjectEnvelope(
            subject: resolvedSubject,
            body: resolvedBodyText,
          );
    final sanitizedBody = resolvedBodyText;

    var captionText = attachment?.caption?.trim() ?? '';
    if (captionText.isEmpty && normalizedHtmlCaption != null) {
      captionText = HtmlContentCodec.toPlainText(normalizedHtmlCaption);
    }
    final transmitCaption = resolvedToken != null
        ? ShareTokenCodec.injectToken(
            token: resolvedToken,
            body: _composeSubjectEnvelope(
              subject: resolvedSubject,
              body: captionText,
            ),
            asSignature: tokenAsSignature,
          )
        : _composeSubjectEnvelope(
            subject: resolvedSubject,
            body: captionText,
          );
    final sanitizedCaption = captionText;

    final participants = await _shareParticipants(
      shareId: resolvedShareId,
      chats: resolvedTargets.values,
      existingParticipants: existingParticipants,
    );
    final shareRecord = MessageShareData(
      shareId: resolvedShareId,
      originatorDcMsgId: existingShare?.originatorDcMsgId,
      subjectToken: resolvedToken,
      subject: resolvedSubject,
      createdAt: existingShare?.createdAt ?? DateTime.timestamp(),
      participantCount: participants.length,
    );
    await db.createMessageShare(
      share: shareRecord,
      participants: participants,
    );

    final statuses = <FanOutRecipientStatus>[];
    var originatorCaptured = existingShare?.originatorDcMsgId != null;
    for (final entry in resolvedTargets.values) {
      try {
        final context = await _ensureEmailChatContext(entry);
        final chatId = context.deltaChatId;
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
              subject: resolvedSubject,
              shareId: resolvedShareId,
              captionOverride: sanitizedCaption,
              htmlCaption: resolvedHtmlCaption,
              accountId: context.account.deltaAccountId,
            ),
          );
        } else {
          msgId = await _guardDeltaOperation(
            operation: 'fan-out message',
            body: () => _transport.sendText(
              chatId: chatId,
              body: transmitBody,
              subject: resolvedSubject,
              shareId: resolvedShareId,
              localBodyOverride: sanitizedBody,
              htmlBody: resolvedHtmlBody,
              accountId: context.account.deltaAccountId,
            ),
          );
        }
        if (!originatorCaptured) {
          await db.assignShareOriginator(
            shareId: resolvedShareId,
            originatorDcMsgId: msgId,
          );
          originatorCaptured = true;
        }
        statuses.add(
          FanOutRecipientStatus(
            chat: context.chat,
            state: FanOutRecipientState.sent,
            deltaMsgId: msgId,
          ),
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
        statuses.add(
          FanOutRecipientStatus(
            chat: entry,
            state: FanOutRecipientState.failed,
            error: error,
          ),
        );
      }
    }

    final attachmentWarning = hasAttachment &&
        resolvedTargets.length > 1 &&
        attachment.sizeBytes > _attachmentFanOutWarningBytes;

    return FanOutSendReport(
      shareId: resolvedShareId,
      subjectToken: resolvedToken,
      subject: resolvedSubject,
      statuses: statuses,
      attachmentWarning: attachmentWarning,
    );
  }

  String? _normalizeSubject(String? subject) {
    return sanitizeEmailHeaderValue(subject);
  }

  String? _normalizeDraftHtml({
    required String text,
    String? htmlBody,
  }) {
    final normalizedHtml = HtmlContentCodec.normalizeHtml(htmlBody);
    if (normalizedHtml != null) {
      return normalizedHtml;
    }
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return null;
    }
    return HtmlContentCodec.normalizeHtml(
      HtmlContentCodec.fromPlainText(text),
    );
  }

  EmailAttachment? _draftAttachmentForCore(
    List<EmailAttachment> attachments,
  ) {
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
    return '';
  }

  String _shareTokenForShare(String shareId) {
    try {
      return ShareTokenCodec.subjectToken(shareId);
    } on ArgumentError catch (error, stackTrace) {
      _log.warning(
        'Rejected invalid share identifier $shareId for subject token',
        error,
        stackTrace,
      );
      throw const FanOutValidationException(
        'Unable to derive share token for the provided identifier.',
      );
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
    final chats = <Chat>[];
    for (final participant in participants) {
      final chat = await db.getChat(participant.contactJid);
      if (chat != null) {
        chats.add(chat);
      }
    }
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
          attachments =
              await db.getMessageAttachmentsForGroup(transportGroupId);
        }
        final ordered = attachments
            .whereType<MessageAttachmentData>()
            .toList(growable: false)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
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
    final resolved = <EmailAttachment>[];
    for (final metadataId in orderedIds) {
      final metadata = await db.getFileMetadata(metadataId);
      final path = metadata?.path;
      if (metadata == null || path == null || path.isEmpty) {
        continue;
      }
      final file = File(path);
      if (!await file.exists()) {
        continue;
      }
      final size = metadata.sizeBytes ?? await file.length();
      resolved.add(
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
    return resolved;
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
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await ensureEventChannelActive();
    await _transport.notifyNetworkAvailable();
    unawaited(_bootstrapActiveAccountIfNeeded());
    unawaited(
      _runReconnectCatchUp().whenComplete(
        () => _refreshConnectivityState(
          source: _EmailSyncSource.networkAvailable,
        ),
      ),
    );
    unawaited(_scheduleReconnectRestartIfOffline());
  }

  Future<void> handleNetworkLost() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _transport.notifyNetworkLost();
  }

  Future<bool> performBackgroundFetch({
    Duration timeout = _imapSyncFetchTimeout,
  }) async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      return false;
    }
    return _transport.performBackgroundFetch(timeout);
  }

  Future<void> syncContactsFromCore() async {
    if (_contactsSyncInFlight) {
      _contactsSyncPending = true;
      return;
    }
    _cancelContactsSyncTimer();
    _contactsSyncInFlight = true;
    try {
      await _ensureReady();
      final contacts = await getContacts(flags: _deltaContactListFlags);
      final blocked = await getBlockedContacts();
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
      await _syncEmailBlocklist(
        db: db,
        blockedContacts: blocked,
      );
      await _syncEmailChatMetadata(
        db: db,
        contactsByAddress: contactsByAddress,
      );
    } finally {
      _contactsSyncInFlight = false;
      if (_contactsSyncPending) {
        _contactsSyncPending = false;
        _scheduleContactsSyncFromCore();
      }
    }
  }

  Future<void> refreshChatlistFromCore() async {
    if (_chatlistSyncInFlight) return;
    _chatlistSyncInFlight = true;
    try {
      await _ensureReady();
      await _transport.refreshChatlistSnapshot();
    } finally {
      _chatlistSyncInFlight = false;
    }
  }

  Future<void> syncInboxAndSent() async {
    await performBackgroundFetch(timeout: _imapSyncFetchTimeout);
    await refreshChatlistFromCore();
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
    if (normalized.isEmpty || !normalized.isEmailJid) {
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
    if (normalized.isEmpty || !normalized.isEmailJid) {
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
          'Failed to apply email blocklist sync update to DeltaChat core.');
    }
  }

  Future<void> _syncEmailChatMetadata({
    required XmppDatabase db,
    required Map<String, DeltaContact> contactsByAddress,
  }) async {
    for (final entry in contactsByAddress.entries) {
      final address = entry.key;
      final contact = entry.value;
      final chat = await db.getChat(address);
      if (chat == null) {
        continue;
      }
      final resolvedName = contact.name?.trim();
      final displayName = resolvedName?.isNotEmpty == true
          ? resolvedName
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
    final _ResolvedEmailAccount account = await _resolveAccountForChat(chat);
    await _ensureAccountConfigured(scope: scope, account: account);
    final int? chatId = await _deltaChatIdForAccount(
      chat: chat,
      deltaAccountId: account.deltaAccountId,
    );
    if (chatId == null) {
      return;
    }
    final db = await _databaseBuilder();
    final localCount = await db.countChatMessages(
      chat.jid,
      filter: filter,
      includePseudoMessages: _includePseudoMessagesInBackfill,
    );
    if (localCount >= desiredWindow) {
      return;
    }
    await performBackgroundFetch(timeout: _foregroundFetchTimeout);
    await _transport.backfillChatHistory(
      chatId: chatId,
      chatJid: chat.jid,
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
      _startImapSyncLoop();
      return;
    }
    _stopImapSyncLoop();

    final operationId = ++_foregroundKeepaliveOperationId;

    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    if (_foregroundKeepaliveEnabled) {
      return;
    }
    final bridge = _foregroundBridge;
    if (bridge == null) {
      _log.fine('Foreground bridge unavailable, skipping keepalive.');
      return;
    }

    await start();
    if (!_isForegroundKeepaliveOpCurrent(operationId)) {
      return;
    }

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
      return;
    }

    if (!_isForegroundKeepaliveOpCurrent(operationId)) {
      await _releaseForegroundKeepaliveResources();
      return;
    }

    _foregroundKeepaliveEnabled = true;
    unawaited(_foregroundKeepaliveTick());
  }

  Stream<List<Message>> messageStreamForChat(
    String jid, {
    int start = 0,
    int end = _defaultPageSize,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async* {
    await _ensureReady();
    final db = await _databaseBuilder();
    yield await db.getChatMessages(
      jid,
      start: start,
      end: end,
      filter: filter,
    );
    yield* db.watchChatMessages(
      jid,
      start: start,
      end: end,
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
    yield _sortChats(await db.getChats(start: start, end: end));
    yield* db.watchChats(start: start, end: end).map<List<Chat>>(_sortChats);
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
    await db.deletePinnedMessage(
      chatJid: chatJid,
      messageStanzaId: stanzaId,
    );
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
            accountId: event.accountId ?? deltaAccountIdLegacy,
          );
        }
        break;
      case DeltaEventType.incomingMsgBunch:
        await _flushQueuedNotifications();
        break;
      case DeltaEventType.incomingReaction:
        await _handleIncomingReaction(
          chatId: event.data1,
          msgId: event.data2,
          accountId: event.accountId ?? deltaAccountIdLegacy,
          reaction: event.data2Text,
        );
        break;
      case DeltaEventType.incomingWebxdcNotify:
        await _handleIncomingWebxdcNotify(
          chatId: event.data1,
          msgId: event.data2,
          accountId: event.accountId ?? deltaAccountIdLegacy,
          text: event.data2Text,
        );
        break;
      case DeltaEventType.msgsNoticed:
        await _handleMessagesNoticed(
          event.data1,
          accountId: event.accountId ?? deltaAccountIdLegacy,
        );
        break;
      case DeltaEventType.chatModified:
        break;
      case DeltaEventType.chatDeleted:
        await _handleChatDeleted(
          event.data1,
          accountId: event.accountId ?? deltaAccountIdLegacy,
        );
        break;
      case DeltaEventType.contactsChanged:
        _scheduleContactsSyncFromCore();
        break;
      case DeltaEventType.accountsBackgroundFetchDone:
        _handleBackgroundFetchDone();
        unawaited(_bootstrapActiveAccountIfNeeded());
        unawaited(refreshChatlistFromCore());
        break;
      case DeltaEventType.connectivityChanged:
        unawaited(_refreshConnectivityState(
          source: _EmailSyncSource.connectivityChangedEvent,
        ));
        unawaited(_bootstrapActiveAccountIfNeeded());
        unawaited(_runReconnectCatchUp());
        break;
      case DeltaEventType.channelOverflow:
        unawaited(_handleChannelOverflow());
        break;
      default:
        break;
    }
  }

  void _queueNotification({
    required int chatId,
    required int msgId,
    required int accountId,
  }) {
    _pendingNotifications.add(
      _PendingNotification(
        chatId: chatId,
        msgId: msgId,
        accountId: accountId,
      ),
    );
    _notificationFlushTimer ??= Timer(_notificationFlushDelay, () {
      _notificationFlushTimer = null;
      unawaited(_flushQueuedNotifications());
    });
  }

  void _scheduleContactsSyncFromCore() {
    if (_contactsSyncInFlight) {
      _contactsSyncPending = true;
      return;
    }
    if (_contactsSyncTimer != null) {
      return;
    }
    _contactsSyncTimer = Timer(_contactsSyncDebounce, () {
      _contactsSyncTimer = null;
      unawaited(syncContactsFromCore());
    });
  }

  void _cancelContactsSyncTimer() {
    _contactsSyncTimer?.cancel();
    _contactsSyncTimer = null;
  }

  Future<void> _flushQueuedNotifications() async {
    _notificationFlushTimer?.cancel();
    _notificationFlushTimer = null;
    if (_pendingNotifications.isEmpty) return;
    final pending = List<_PendingNotification>.from(_pendingNotifications);
    _pendingNotifications.clear();
    for (final entry in pending) {
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
    await _flushQueuedNotifications();
    final notificationService = _notificationService;
    if (notificationService == null) return;
    final db = await _databaseBuilder();
    final chat = await db.getChatByDeltaChatId(
      chatId,
      accountId: accountId,
    );
    if (chat == null) return;
    await notificationService.dismissMessageNotification(
      threadKey: _notificationThreadKey(chat.jid),
    );
  }

  Future<void> _handleChatDeleted(
    int chatId, {
    required int accountId,
  }) async {
    await _flushQueuedNotifications();
    final notificationService = _notificationService;
    if (notificationService == null) return;
    final db = await _databaseBuilder();
    final chat = await db.getChatByDeltaChatId(
      chatId,
      accountId: accountId,
    );
    if (chat == null) return;
    await notificationService.dismissMessageNotification(
      threadKey: _notificationThreadKey(chat.jid),
    );
  }

  Future<_DeltaNotificationContext?> _notificationContextForMessage({
    required XmppDatabase db,
    required int msgId,
    required int accountId,
    int? chatId,
  }) async {
    final stanzaId = _stanzaId(
      msgId,
      accountId: accountId,
    );
    final message = await db.getMessageByDeltaId(
          msgId,
          deltaAccountId: accountId,
        ) ??
        await db.getMessageByStanzaID(stanzaId);
    if (message == null) {
      return null;
    }
    if (message.warning == MessageWarning.emailSpamQuarantined) {
      return null;
    }
    String bare(String value) => value.split('/').first;
    final selfJid = _selfSenderJidForAccount(accountId) ?? selfSenderJid;
    if (selfJid != null && bare(message.senderJid) == bare(selfJid)) {
      return null;
    }
    var chat = await db.getChat(message.chatJid);
    if (chat == null && chatId != null) {
      chat = await db.getChatByDeltaChatId(
        chatId,
        accountId: accountId,
      );
    }
    if (chat?.muted ?? false) {
      return null;
    }
    return _DeltaNotificationContext(message: message, chat: chat);
  }

  String _notificationThreadKey(String chatJid) {
    final normalized = chatJid.trim();
    if (normalized.isEmpty) {
      return normalized;
    }
    return _notificationPayloadCodec.encodeChatJid(normalized) ?? normalized;
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
      final context = await _notificationContextForMessage(
        db: db,
        msgId: msgId,
        accountId: accountId,
        chatId: chatId,
      );
      if (context == null) {
        return;
      }
      final notificationBody =
          await _notificationBody(db: db, message: context.message);
      if (notificationBody == null) {
        return;
      }
      final previewSetting = context.chat?.notificationPreviewSetting ??
          NotificationPreviewSetting.inherit;
      final showPreview = previewSetting
          .resolvePreview(notificationService.notificationPreviewsEnabled);
      final notificationTarget = context.chat?.jid ?? context.message.chatJid;
      final threadKey = _notificationThreadKey(notificationTarget);
      if (threadKey.isEmpty) {
        return;
      }
      await notificationService.sendMessageNotification(
        title: context.chat?.title ?? context.message.senderJid,
        body: notificationBody,
        payload: threadKey,
        threadKey: threadKey,
        showPreviewOverride: showPreview,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to raise notification for email message ${_stanzaId(
          msgId,
          accountId: accountId,
        )}',
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
      final context = await _notificationContextForMessage(
        db: db,
        msgId: msgId,
        accountId: accountId,
        chatId: chatId,
      );
      if (context == null) {
        return;
      }
      final normalizedReaction = reaction?.trim();
      final body = normalizedReaction == null || normalizedReaction.isEmpty
          ? _reactionNotificationFallback
          : '$_reactionNotificationPrefix$normalizedReaction';
      final previewSetting = context.chat?.notificationPreviewSetting ??
          NotificationPreviewSetting.inherit;
      final showPreview = previewSetting
          .resolvePreview(notificationService.notificationPreviewsEnabled);
      final notificationTarget = context.chat?.jid ?? context.message.chatJid;
      final threadKey = _notificationThreadKey(notificationTarget);
      if (threadKey.isEmpty) {
        return;
      }
      await notificationService.sendMessageNotification(
        title: context.chat?.title ?? context.message.senderJid,
        body: body,
        payload: threadKey,
        threadKey: threadKey,
        showPreviewOverride: showPreview,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to raise reaction notification for email message ${_stanzaId(
          msgId,
          accountId: accountId,
        )}',
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
      final context = await _notificationContextForMessage(
        db: db,
        msgId: msgId,
        accountId: accountId,
        chatId: chatId,
      );
      if (context == null) {
        return;
      }
      final normalizedText = text?.trim();
      final body = normalizedText == null || normalizedText.isEmpty
          ? _webxdcNotificationFallback
          : normalizedText;
      final previewSetting = context.chat?.notificationPreviewSetting ??
          NotificationPreviewSetting.inherit;
      final showPreview = previewSetting
          .resolvePreview(notificationService.notificationPreviewsEnabled);
      final notificationTarget = context.chat?.jid ?? context.message.chatJid;
      final threadKey = _notificationThreadKey(notificationTarget);
      if (threadKey.isEmpty) {
        return;
      }
      await notificationService.sendMessageNotification(
        title: context.chat?.title ?? context.message.senderJid,
        body: body,
        payload: threadKey,
        threadKey: threadKey,
        showPreviewOverride: showPreview,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to raise webxdc notification for email message ${_stanzaId(
          msgId,
          accountId: accountId,
        )}',
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
    if (exception.code == DeltaChatErrorCode.network) {
      _updateSyncState(
        EmailSyncState.offline(
          exception.message,
          exception: exception,
        ),
        source: _EmailSyncSource.coreError,
      );
      return;
    }
    _updateSyncState(
      EmailSyncState.error(
        exception.message,
        exception: exception,
      ),
      source: _EmailSyncSource.coreError,
    );
  }

  void _handleSelfNotInGroup(String? message) {
    final details = message?.trim();
    _updateSyncState(
      EmailSyncState.error(
        details?.isNotEmpty == true
            ? details!
            : 'Email group membership changed. Try reopening the chat.',
      ),
      source: _EmailSyncSource.selfNotInGroup,
    );
  }

  Future<void> _refreshConnectivityState({
    _EmailSyncSource source = _EmailSyncSource.unknown,
  }) async {
    try {
      final connectivity = await _transport.connectivity();
      if (connectivity == null) return;
      _recordConnectivitySample(
        connectivity: connectivity,
        source: source,
      );
      if (connectivity >= _connectivityConnectedMin) {
        _cancelConnectivityDowngrade();
        _updateSyncState(
          const EmailSyncState.ready(),
          source: source,
        );
        return;
      }
      if (connectivity >= _connectivityWorkingMin) {
        _cancelConnectivityDowngrade();
        if (_syncState.status == EmailSyncStatus.ready) {
          return;
        }
        _updateSyncState(
          const EmailSyncState.recovering(_emailSyncingMessage),
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
    _pendingConnectivityLevel = connectivity;
    if (_connectivityDowngradeTimer != null) {
      return;
    }
    _connectivityDowngradeTimer = Timer(
      _connectivityDowngradeGrace,
      () {
        _connectivityDowngradeTimer = null;
        final pending = _pendingConnectivityLevel;
        _pendingConnectivityLevel = null;
        if (pending == null) {
          return;
        }
        unawaited(_confirmConnectivityDowngrade(pending));
      },
    );
  }

  Future<void> _confirmConnectivityDowngrade(int fallbackConnectivity) async {
    try {
      final connectivity = await _transport.connectivity();
      final resolved = connectivity ?? fallbackConnectivity;
      _recordConnectivitySample(
        connectivity: resolved,
        source: _EmailSyncSource.connectivityConfirm,
      );
      if (resolved >= _connectivityConnectedMin) {
        return;
      }
      _applyConnectivityState(
        resolved,
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
        const EmailSyncState.recovering(_emailConnectingMessage),
        source: source,
      );
      return;
    }
    _updateSyncState(
      const EmailSyncState.offline(_emailDisconnectedMessage),
      source: source,
    );
  }

  void _recordConnectivitySample({
    required int connectivity,
    required _EmailSyncSource source,
  }) {
    _lastConnectivityValue = connectivity;
    _logConnectivitySample(
      connectivity: connectivity,
      source: source,
    );
  }

  void _logConnectivitySample({
    required int connectivity,
    required _EmailSyncSource source,
  }) {
    final now = DateTime.timestamp();
    final lastLoggedAt = _lastConnectivityLoggedAt;
    final shouldLog = _lastLoggedConnectivityValue == null ||
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
    final connectivityLabel =
        connectivity == null ? _emailLogUnknownValue : '$connectivity';
    final hasMessage = next.message?.isNotEmpty == true;
    _log.fine(
      '$_emailSyncLogPrefix: '
      '${previous.status.name} -> ${next.status.name}, '
      '$_emailLogSourceLabel=${source.logLabel}, '
      '$_emailLogConnectivityLabel=$connectivityLabel, '
      '$_emailLogHasMessageLabel=$hasMessage',
    );
  }

  void _handleBackgroundFetchDone() {
    if (_syncState.status == EmailSyncStatus.ready) {
      return;
    }
    unawaited(_refreshConnectivityState(
      source: _EmailSyncSource.backgroundFetchDone,
    ));
  }

  Future<void> _handleChannelOverflow() async {
    if (_channelOverflowRecoveryInProgress) {
      return;
    }
    _channelOverflowRecoveryInProgress = true;
    _updateSyncState(
      const EmailSyncState.recovering(
        'Refreshing email sync after interruption…',
      ),
      source: _EmailSyncSource.channelOverflow,
    );
    try {
      final success =
          await _transport.performBackgroundFetch(_foregroundFetchTimeout);
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
        const EmailSyncState.error(
          'Email sync could not refresh. Try reopening the app.',
        ),
        source: _EmailSyncSource.channelOverflowFailure,
      );
    } finally {
      _channelOverflowRecoveryInProgress = false;
    }
    await _refreshConnectivityState(
      source: _EmailSyncSource.channelOverflowComplete,
    );
  }

  void _updateSyncState(
    EmailSyncState next, {
    _EmailSyncSource source = _EmailSyncSource.unknown,
  }) {
    if (_syncState == next) return;
    final previous = _syncState;
    _syncState = next;
    _syncStateController.add(next);
    _logSyncStateTransition(
      previous: previous,
      next: next,
      source: source,
    );
  }

  void _detachTransportListener() {
    if (!_listenerAttached) return;
    _transport.removeEventListener(_eventListener);
    _listenerAttached = false;
  }

  void _clearNotificationQueue() {
    _notificationFlushTimer?.cancel();
    _notificationFlushTimer = null;
    _pendingNotifications.clear();
  }

  bool _isForegroundKeepaliveOpCurrent(int operationId) =>
      operationId == _foregroundKeepaliveOperationId;

  Future<void> _applyPendingPushToken() async {
    final token = _pendingPushToken;
    if (token == null || token.isEmpty) return;
    await _transport.registerPushToken(token);
  }

  Future<void> _bootstrapActiveAccountIfNeeded() async {
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
    final existing = _bootstrapFuture;
    if (existing != null) {
      return;
    }
    final operationId = ++_bootstrapOperationId;
    final future = _runBootstrapFromCore(
      operationId: operationId,
      bootstrapKey: bootstrapKey,
    );
    _bootstrapFuture = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_bootstrapFuture, future)) {
          _bootstrapFuture = null;
        }
      }),
    );
  }

  Future<void> _runBootstrapFromCore({
    required int operationId,
    required RegisteredCredentialKey bootstrapKey,
  }) async {
    if (_syncState.status == EmailSyncStatus.ready) {
      _updateSyncState(
        const EmailSyncState.recovering('Syncing email history…'),
        source: _EmailSyncSource.bootstrapStart,
      );
    }
    try {
      await _transport.bootstrapFromCore();
      if (operationId != _bootstrapOperationId) {
        return;
      }
      await _credentialStore.write(
        key: bootstrapKey,
        value: true.toString(),
      );
      if (operationId != _bootstrapOperationId) {
        return;
      }
      await _refreshConnectivityState(
        source: _EmailSyncSource.bootstrapComplete,
      );
    } on Exception catch (error, stackTrace) {
      if (operationId != _bootstrapOperationId) {
        return;
      }
      _log.warning('Email history bootstrap failed', error, stackTrace);
      if (_syncState.status == EmailSyncStatus.ready ||
          _syncState.status == EmailSyncStatus.recovering) {
        _updateSyncState(
          const EmailSyncState.recovering('Email sync will retry shortly…'),
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
    _foregroundKeepaliveTickScheduled = false;
    final bridge = _foregroundBridge;
    if (bridge != null && _foregroundKeepaliveServiceAcquired) {
      try {
        await bridge.send([
          emailKeepalivePrefix,
          emailKeepaliveStopCommand,
        ]);
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

  void _handleForegroundTaskMessage(String data) {
    if (!data.startsWith('$emailKeepaliveTickPrefix$join')) {
      return;
    }
    if (!_foregroundKeepaliveEnabled || _foregroundKeepaliveTickScheduled) {
      return;
    }
    _foregroundKeepaliveTickScheduled = true;
    unawaited(_runForegroundKeepaliveTick());
  }

  Future<void> _runForegroundKeepaliveTick() async {
    try {
      await _foregroundKeepaliveTick();
    } finally {
      _foregroundKeepaliveTickScheduled = false;
    }
  }

  Future<void> _foregroundKeepaliveTick() async {
    if (!_foregroundKeepaliveEnabled) {
      return;
    }
    try {
      await handleNetworkAvailable();
      await performBackgroundFetch(timeout: _foregroundFetchTimeout);
      await refreshChatlistFromCore();
    } on Exception catch (error, stackTrace) {
      _log.finer('Foreground keepalive tick failed', error, stackTrace);
    }
  }

  void _startImapSyncLoop() {
    if (_imapSyncLoopActive) {
      return;
    }
    _imapSyncLoopActive = true;
    _scheduleNextImapSync();
  }

  void _stopImapSyncLoop() {
    _imapSyncLoopActive = false;
    _imapSyncTimer?.cancel();
    _imapSyncTimer = null;
  }

  void _scheduleNextImapSync() {
    if (!_imapSyncLoopActive || _foregroundKeepaliveEnabled) {
      return;
    }
    final interval = _imapSyncInterval();
    _imapSyncTimer?.cancel();
    _imapSyncTimer = Timer(
      interval,
      () => unawaited(_runImapSyncTick()),
    );
  }

  Future<void> _runImapSyncTick() async {
    if (!_imapSyncLoopActive || _foregroundKeepaliveEnabled) {
      return;
    }
    if (_imapSyncInFlight) {
      _scheduleNextImapSync();
      return;
    }
    _imapSyncInFlight = true;
    try {
      await _refreshImapCapabilities();
      await performBackgroundFetch(timeout: _imapSyncFetchTimeout);
      await refreshChatlistFromCore();
    } finally {
      _imapSyncInFlight = false;
      _scheduleNextImapSync();
    }
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
    final shouldReuse = !force &&
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
    await _ensureReady();
    final idleFlag = await _readImapConfigBool(_imapIdleConfigKey);
    final idleTimeout = await _readImapConfigInt(_imapIdleTimeoutConfigKey);
    final maxConnections =
        await _readImapConfigInt(_imapMaxConnectionsConfigKey);
    final accountsActive =
        _transport.accountsActive || _transport.accountsSupported;
    final defaultLimit =
        accountsActive ? _imapConnectionLimitMulti : _imapConnectionLimitSingle;
    final idleSupported = idleFlag ?? accountsActive;
    final connectionLimit =
        _normalizeConnectionLimit(maxConnections ?? defaultLimit);
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
    if (_reconnectCatchUpInFlight) {
      return;
    }
    _reconnectCatchUpInFlight = true;
    try {
      await _refreshImapCapabilities();
      await performBackgroundFetch(timeout: _imapSyncFetchTimeout);
      await refreshChatlistFromCore();
    } finally {
      _reconnectCatchUpInFlight = false;
    }
  }

  Future<void> _scheduleReconnectRestartIfOffline() async {
    if (_reconnectRestartInFlight) {
      return;
    }
    _reconnectRestartInFlight = true;
    try {
      await Future.delayed(_reconnectRestartDelay);
      final connectivity = await _transport.connectivity();
      if (connectivity == null || connectivity >= _connectivityConnectingMin) {
        return;
      }
      _log.warning(
        'Email transport still offline after network available; restarting.',
      );
      await stop();
      await start();
      await _transport.notifyNetworkAvailable();
    } on Exception catch (error, stackTrace) {
      _log.warning('Email transport restart failed', error, stackTrace);
    } finally {
      _reconnectRestartInFlight = false;
      unawaited(_refreshConnectivityState(
        source: _EmailSyncSource.reconnectRestart,
      ));
    }
  }

  Future<void> _ensureReady() async {
    if (_databasePrefix == null || _databasePassphrase == null) {
      throw StateError('Call ensureProvisioned before using EmailService.');
    }
    if (!_running) {
      await start();
    }
  }

  Future<void> _applyDownloadLimit() async {
    try {
      final current = await _transport.getCoreConfig(_emailDownloadLimitKey);
      if (current?.trim() == _emailDownloadLimitDisabledValue) {
        return;
      }
      await _transport.setCoreConfig(
        key: _emailDownloadLimitKey,
        value: _emailDownloadLimitDisabledValue,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to update email download limit', error, stackTrace);
    }
  }

  Future<String?> _notificationBody({
    required XmppDatabase db,
    required Message message,
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
          attachments =
              await db.getMessageAttachmentsForGroup(transportGroupId);
        }
        final ordered = attachments
            .whereType<MessageAttachmentData>()
            .toList(growable: false)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final metadata = await db.getFileMetadata(ordered.first.fileMetadataId);
        if (metadata == null) {
          return _notificationAttachmentLabel;
        }
        final filename = metadata.filename.trim();
        return filename.isEmpty
            ? _notificationAttachmentLabel
            : '$_notificationAttachmentPrefix$filename';
      }
    }
    final metadataId = message.fileMetadataID;
    if (metadataId == null) {
      return null;
    }
    final metadata = await db.getFileMetadata(metadataId);
    if (metadata == null) {
      return _notificationAttachmentLabel;
    }
    final filename = metadata.filename.trim();
    return filename.isEmpty
        ? _notificationAttachmentLabel
        : '$_notificationAttachmentPrefix$filename';
  }

  String? get selfSenderJid => _transport.selfJid;

  String? _selfSenderJidForAccount(int accountId) =>
      _transport.selfJidForAccount(accountId);

  Future<Map<String, Chat>> _resolveFanOutTargets(
    List<FanOutTarget> targets,
  ) async {
    final resolved = <String, Chat>{};
    for (final target in targets) {
      Chat chat;
      if (target.chat != null) {
        chat = await ensureChatForEmailChat(target.chat!);
      } else {
        final address = target.address;
        if (address == null || address.isEmpty) {
          continue;
        }
        chat = await ensureChatForAddress(
          address: address,
          displayName: target.displayName ?? address,
        );
      }
      resolved.putIfAbsent(chat.jid, () => chat);
    }
    return resolved;
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
    final resolvedSenderJid = _senderParticipantJid(senderJid: senderJid);
    if (resolvedSenderJid != null && resolvedSenderJid.isNotEmpty) {
      participants[resolvedSenderJid] = MessageParticipantData(
        shareId: shareId,
        contactJid: resolvedSenderJid,
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
    final normalized = senderJid?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    return selfSenderJid ?? deltaSelfJid;
  }

  Future<Chat> _waitForChat(
    int chatId, {
    int? accountId,
  }) async {
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
          .watchChatByDeltaChatId(
            chatId,
            accountId: accountId,
          )
          .where((chat) => chat != null)
          .cast<Chat>()
          .first
          .timeout(const Duration(seconds: 10));
      return chat;
    } on TimeoutException {
      throw StateError('Email chat $chatId was not persisted within timeout.');
    }
  }

  String? _preferredAddressFromJid(String jid) {
    final bare = _normalizeJid(jid);
    final parts = bare.split('@');
    if (parts.length != 2) {
      return null;
    }
    final local = parts[0].trim().toLowerCase();
    final domain = parts[1].trim().toLowerCase();
    if (local.isEmpty || domain.isEmpty) {
      return null;
    }
    return '$local@$domain';
  }

  static Map<String, String> _defaultConnectionConfig(
    String address,
    EndpointConfig config,
  ) {
    final configValues = <String, String>{
      _showEmailsConfigKey: _showEmailsAllValue,
      _emailDownloadLimitKey: _emailDownloadLimitDisabledValue,
      _mdnsEnabledConfigKey: _mdnsEnabledValue,
    };
    final normalizedAddress = address.trim();
    final localPart =
        _localPartFromAddress(normalizedAddress) ?? normalizedAddress;
    final smtpHost = config.smtpHost?.trim();
    final imapHost = config.imapHost?.trim();
    final fallbackHost = _connectionHostFor(normalizedAddress, config);
    final resolvedSendHost =
        (smtpHost != null && smtpHost.isNotEmpty) ? smtpHost : fallbackHost;
    final resolvedMailHost =
        (imapHost != null && imapHost.isNotEmpty) ? imapHost : fallbackHost;
    final sendPortValue = config.smtpPort > _portUnsetValue
        ? config.smtpPort
        : EndpointConfig.defaultSmtpPort;
    final sendSecurityMode = _securityModeForPort(
      port: sendPortValue,
      implicitTlsPort: EndpointConfig.defaultSmtpPort,
    );
    configValues
      ..[_sendServerConfigKey] = resolvedSendHost
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
      ..[_mailServerConfigKey] = resolvedMailHost
      ..[_mailPortConfigKey] = mailPortValue.toString()
      ..[_mailSecurityConfigKey] = mailSecurityMode
      ..[_mailUserConfigKey] = localPart;
    return configValues;
  }

  static String _securityModeForPort({
    required int port,
    required int implicitTlsPort,
  }) =>
      port == implicitTlsPort ? _securityModeSsl : _securityModeStartTls;

  static String _connectionHostFor(String address, EndpointConfig config) {
    final customHost = config.smtpHost?.trim();
    if (customHost != null && customHost.isNotEmpty) {
      return customHost;
    }
    final domain = _domainFromAddress(address) ?? config.domain;
    if (domain.isEmpty) {
      throw StateError('Unable to resolve email server host.');
    }
    return domain;
  }

  static String? _domainFromAddress(String address) {
    final parts = address.split('@');
    if (parts.length != 2) {
      return null;
    }
    final domain = parts[1].trim().toLowerCase();
    return domain.isEmpty ? null : domain;
  }

  static String? _localPartFromAddress(String address) {
    if (address.isEmpty) {
      return null;
    }
    final index = address.indexOf('@');
    final localPart =
        index == -1 ? address.trim() : address.substring(0, index).trim();
    return localPart.isEmpty ? null : localPart;
  }

  List<Chat> _sortChats(List<Chat> chats) => List<Chat>.of(chats)
    ..sort((a, b) {
      if (a.favorited == b.favorited) {
        return b.lastChangeTimestamp.compareTo(a.lastChangeTimestamp);
      }
      return (a.favorited ? 0 : 1) - (b.favorited ? 0 : 1);
    });

  int _compareLinkedAccountProfiles(
    EmailAccountProfile first,
    EmailAccountProfile second,
  ) {
    final int firstRank = first.isPrimary
        ? _linkedEmailAccountSortPrimary
        : _linkedEmailAccountSortSecondary;
    final int secondRank = second.isPrimary
        ? _linkedEmailAccountSortPrimary
        : _linkedEmailAccountSortSecondary;
    final int primarySort = firstRank.compareTo(secondRank);
    if (primarySort != _linkedEmailAccountSortEqual) {
      return primarySort;
    }
    return first.address.compareTo(second.address);
  }

  String _normalizeLinkedAccountAddress(String address) =>
      normalizeEmailAddress(address);

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

  String _displayNameForAddress(
    String address, {
    String? displayName,
  }) {
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
    return _addressKeys.putIfAbsent(
      scope,
      () => CredentialStore.registerKey('email_address_$scope'),
    );
  }

  RegisteredCredentialKey _passwordKeyForScope(String scope) {
    return _passwordKeys.putIfAbsent(
      scope,
      () => CredentialStore.registerKey('email_password_$scope'),
    );
  }

  RegisteredCredentialKey _provisionedKeyForScope(String scope) {
    return _provisionedKeys.putIfAbsent(
      scope,
      () => CredentialStore.registerKey('email_provisioned_$scope'),
    );
  }

  RegisteredCredentialKey _connectionOverrideKeyForScope(String scope) {
    final identifier = '${_connectionOverrideKeyPrefix}_$scope';
    return _connectionOverrideKeys.putIfAbsent(
      scope,
      () => CredentialStore.registerKey(identifier),
    );
  }

  RegisteredCredentialKey _linkedAccountListKeyForScope(String scope) {
    return _linkedAccountListKeys.putIfAbsent(
      scope,
      () => CredentialStore.registerKey(
        '${_linkedEmailAccountsKeyPrefix}_$scope',
      ),
    );
  }

  RegisteredCredentialKey _linkedAccountPrimaryKeyForScope(String scope) {
    return _linkedAccountPrimaryKeys.putIfAbsent(
      scope,
      () => CredentialStore.registerKey(
        '${_linkedEmailPrimaryAccountKeyPrefix}_$scope',
      ),
    );
  }

  RegisteredCredentialKey _linkedAccountAddressKeyFor({
    required String scope,
    required EmailAccountId accountId,
  }) {
    final String cacheKey = _linkedAccountCacheKey(
      scope: scope,
      accountId: accountId,
    );
    return _linkedAccountAddressKeys.putIfAbsent(
      cacheKey,
      () => CredentialStore.registerKey(
        _linkedAccountKeyValue(
          prefix: _linkedEmailAccountAddressKeyPrefix,
          scope: scope,
          accountId: accountId,
        ),
      ),
    );
  }

  RegisteredCredentialKey _linkedAccountPasswordKeyFor({
    required String scope,
    required EmailAccountId accountId,
  }) {
    final String cacheKey = _linkedAccountCacheKey(
      scope: scope,
      accountId: accountId,
    );
    return _linkedAccountPasswordKeys.putIfAbsent(
      cacheKey,
      () => CredentialStore.registerKey(
        _linkedAccountKeyValue(
          prefix: _linkedEmailAccountPasswordKeyPrefix,
          scope: scope,
          accountId: accountId,
        ),
      ),
    );
  }

  RegisteredCredentialKey _linkedAccountAuthMethodKeyFor({
    required String scope,
    required EmailAccountId accountId,
  }) {
    final String cacheKey = _linkedAccountCacheKey(
      scope: scope,
      accountId: accountId,
    );
    return _linkedAccountAuthMethodKeys.putIfAbsent(
      cacheKey,
      () => CredentialStore.registerKey(
        _linkedAccountKeyValue(
          prefix: _linkedEmailAccountAuthMethodKeyPrefix,
          scope: scope,
          accountId: accountId,
        ),
      ),
    );
  }

  RegisteredCredentialKey _linkedAccountOauthProviderKeyFor({
    required String scope,
    required EmailAccountId accountId,
  }) {
    final String cacheKey = _linkedAccountCacheKey(
      scope: scope,
      accountId: accountId,
    );
    return _linkedAccountOauthProviderKeys.putIfAbsent(
      cacheKey,
      () => CredentialStore.registerKey(
        _linkedAccountKeyValue(
          prefix: _linkedEmailAccountOauthProviderKeyPrefix,
          scope: scope,
          accountId: accountId,
        ),
      ),
    );
  }

  RegisteredCredentialKey _linkedAccountOauthAccessTokenKeyFor({
    required String scope,
    required EmailAccountId accountId,
  }) {
    final String cacheKey = _linkedAccountCacheKey(
      scope: scope,
      accountId: accountId,
    );
    return _linkedAccountOauthAccessKeys.putIfAbsent(
      cacheKey,
      () => CredentialStore.registerKey(
        _linkedAccountKeyValue(
          prefix: _linkedEmailAccountOauthAccessTokenKeyPrefix,
          scope: scope,
          accountId: accountId,
        ),
      ),
    );
  }

  RegisteredCredentialKey _linkedAccountOauthRefreshTokenKeyFor({
    required String scope,
    required EmailAccountId accountId,
  }) {
    final String cacheKey = _linkedAccountCacheKey(
      scope: scope,
      accountId: accountId,
    );
    return _linkedAccountOauthRefreshKeys.putIfAbsent(
      cacheKey,
      () => CredentialStore.registerKey(
        _linkedAccountKeyValue(
          prefix: _linkedEmailAccountOauthRefreshTokenKeyPrefix,
          scope: scope,
          accountId: accountId,
        ),
      ),
    );
  }

  RegisteredCredentialKey _linkedAccountOauthExpiryKeyFor({
    required String scope,
    required EmailAccountId accountId,
  }) {
    final String cacheKey = _linkedAccountCacheKey(
      scope: scope,
      accountId: accountId,
    );
    return _linkedAccountOauthExpiryKeys.putIfAbsent(
      cacheKey,
      () => CredentialStore.registerKey(
        _linkedAccountKeyValue(
          prefix: _linkedEmailAccountOauthExpiryKeyPrefix,
          scope: scope,
          accountId: accountId,
        ),
      ),
    );
  }

  RegisteredCredentialKey _linkedAccountDisplayNameKeyFor({
    required String scope,
    required EmailAccountId accountId,
  }) {
    final String cacheKey = _linkedAccountCacheKey(
      scope: scope,
      accountId: accountId,
    );
    return _linkedAccountDisplayNameKeys.putIfAbsent(
      cacheKey,
      () => CredentialStore.registerKey(
        _linkedAccountKeyValue(
          prefix: _linkedEmailAccountDisplayNameKeyPrefix,
          scope: scope,
          accountId: accountId,
        ),
      ),
    );
  }

  RegisteredCredentialKey _linkedAccountDeltaIdKeyFor({
    required String scope,
    required EmailAccountId accountId,
  }) {
    final String cacheKey = _linkedAccountCacheKey(
      scope: scope,
      accountId: accountId,
    );
    return _linkedAccountDeltaIdKeys.putIfAbsent(
      cacheKey,
      () => CredentialStore.registerKey(
        _linkedAccountKeyValue(
          prefix: _linkedEmailAccountDeltaIdKeyPrefix,
          scope: scope,
          accountId: accountId,
        ),
      ),
    );
  }

  RegisteredCredentialKey _linkedAccountProvisionedKeyFor({
    required String scope,
    required EmailAccountId accountId,
  }) {
    final String cacheKey = _linkedAccountCacheKey(
      scope: scope,
      accountId: accountId,
    );
    return _linkedAccountProvisionedKeys.putIfAbsent(
      cacheKey,
      () => CredentialStore.registerKey(
        _linkedAccountKeyValue(
          prefix: _linkedEmailAccountProvisionedKeyPrefix,
          scope: scope,
          accountId: accountId,
        ),
      ),
    );
  }

  String _linkedAccountCacheKey({
    required String scope,
    required EmailAccountId accountId,
  }) {
    return '$scope$_linkedEmailAccountKeySeparator${accountId.value}';
  }

  String _linkedAccountKeyValue({
    required String prefix,
    required String scope,
    required EmailAccountId accountId,
  }) {
    return '$prefix$_linkedEmailAccountKeySeparator$scope'
        '$_linkedEmailAccountKeySeparator${accountId.value}';
  }

  Future<EmailAccountProfile?> _legacyAccountProfileForScope(
    String scope,
  ) async {
    final String? address = await _credentialStore.read(
      key: _addressKeyForScope(scope),
    );
    if (address == null || address.isEmpty) {
      return null;
    }
    final EmailAccountId? accountId = EmailAccountId.fromAddress(address);
    if (accountId == null) {
      return null;
    }
    final String resolvedDisplayName = _displayNameForAddress(address);
    return EmailAccountProfile(
      id: accountId,
      address: address,
      displayName: resolvedDisplayName,
      authMethod: EmailAuthMethod.password,
      isPrimary: true,
      deltaAccountId: null,
    );
  }

  Future<EmailAccountId?> _legacyAccountIdForScope(String scope) async {
    final String? address = await _credentialStore.read(
      key: _addressKeyForScope(scope),
    );
    if (address == null || address.isEmpty) {
      return null;
    }
    return EmailAccountId.fromAddress(address);
  }

  Future<List<EmailAccountId>> _readLinkedAccountIds(
    String scope, {
    bool includeLegacy = false,
  }) async {
    final RegisteredCredentialKey listKey =
        _linkedAccountListKeyForScope(scope);
    final String? stored = await _credentialStore.read(key: listKey);
    final String payload = (stored == null || stored.trim().isEmpty)
        ? _linkedEmailAccountsEmptyJson
        : stored;
    final List<EmailAccountId> decoded = _decodeLinkedAccountIds(payload);
    final List<EmailAccountId> resolved = List<EmailAccountId>.of(decoded);
    if (includeLegacy) {
      final EmailAccountId? legacyId = await _legacyAccountIdForScope(scope);
      if (legacyId != null && !resolved.contains(legacyId)) {
        resolved.add(legacyId);
      }
    }
    return List<EmailAccountId>.unmodifiable(resolved);
  }

  Future<void> _ensureLinkedAccountExists({
    required String scope,
    required EmailAccountId accountId,
  }) async {
    final List<EmailAccountId> accountIds = await _readLinkedAccountIds(
      scope,
      includeLegacy: true,
    );
    if (accountIds.contains(accountId)) {
      return;
    }
    final activeAccount = _activeAccount;
    if (activeAccount != null && _activeCredentialScope == scope) {
      final String normalizedActive = _normalizeLinkedAccountAddress(
        activeAccount.address,
      );
      if (normalizedActive == accountId.value) {
        return;
      }
    }
    throw StateError(_linkedEmailAccountNotLinkedError);
  }

  Future<void> _writeLinkedAccountIds(
    String scope,
    List<EmailAccountId> accountIds,
  ) async {
    final RegisteredCredentialKey listKey =
        _linkedAccountListKeyForScope(scope);
    final String payload = accountIds.isEmpty
        ? _linkedEmailAccountsEmptyJson
        : _encodeLinkedAccountIds(accountIds);
    await _credentialStore.write(key: listKey, value: payload);
  }

  List<EmailAccountId> _decodeLinkedAccountIds(String payload) {
    if (payload.trim().isEmpty) {
      return const <EmailAccountId>[];
    }
    try {
      final dynamic decoded = jsonDecode(payload);
      if (decoded is! List<dynamic>) {
        return const <EmailAccountId>[];
      }
      final List<EmailAccountId> result = <EmailAccountId>[];
      for (final dynamic entry in decoded) {
        if (entry is! String) {
          continue;
        }
        final EmailAccountId? accountId = EmailAccountId.fromStored(entry);
        if (accountId != null) {
          result.add(accountId);
        }
      }
      return result;
    } on FormatException {
      return const <EmailAccountId>[];
    }
  }

  String _encodeLinkedAccountIds(List<EmailAccountId> accountIds) {
    final List<String> encoded = accountIds
        .map((EmailAccountId accountId) => accountId.value)
        .toList(growable: false);
    return jsonEncode(encoded);
  }

  Future<EmailAccountId?> _readPrimaryAccountId(
    String scope, {
    List<EmailAccountId>? fallbackIds,
  }) async {
    final RegisteredCredentialKey key = _linkedAccountPrimaryKeyForScope(scope);
    final String? stored = await _credentialStore.read(key: key);
    final EmailAccountId? primaryId =
        stored == null ? null : EmailAccountId.fromStored(stored);
    if (primaryId != null) {
      return primaryId;
    }
    final List<EmailAccountId> fallback = fallbackIds ?? <EmailAccountId>[];
    if (fallback.isEmpty) {
      return null;
    }
    return fallback.first;
  }

  Future<int?> _readLinkedAccountDeltaId({
    required String scope,
    required EmailAccountId accountId,
  }) async {
    final RegisteredCredentialKey key = _linkedAccountDeltaIdKeyFor(
      scope: scope,
      accountId: accountId,
    );
    final String? stored = await _credentialStore.read(key: key);
    if (stored == null || stored.trim().isEmpty) {
      return null;
    }
    return int.tryParse(stored);
  }

  Future<EmailAuthMethod> _readLinkedAccountAuthMethod({
    required String scope,
    required EmailAccountId accountId,
  }) async {
    final RegisteredCredentialKey key = _linkedAccountAuthMethodKeyFor(
      scope: scope,
      accountId: accountId,
    );
    final String? stored = await _credentialStore.read(key: key);
    return EmailAuthMethodStorage.fromStored(stored);
  }

  Future<EmailOauthProvider?> _readLinkedAccountOauthProvider({
    required String scope,
    required EmailAccountId accountId,
  }) async {
    final RegisteredCredentialKey key = _linkedAccountOauthProviderKeyFor(
      scope: scope,
      accountId: accountId,
    );
    final String? stored = await _credentialStore.read(key: key);
    return stored == null ? null : emailOauthProviderFromStorage(stored);
  }

  Future<String?> _readLinkedAccountOauthAccessToken({
    required String scope,
    required EmailAccountId accountId,
  }) async {
    return _credentialStore.read(
      key: _linkedAccountOauthAccessTokenKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
  }

  Future<String?> _readLinkedAccountOauthRefreshToken({
    required String scope,
    required EmailAccountId accountId,
  }) async {
    return _credentialStore.read(
      key: _linkedAccountOauthRefreshTokenKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
  }

  Future<DateTime?> _readLinkedAccountOauthExpiry({
    required String scope,
    required EmailAccountId accountId,
  }) async {
    final String? stored = await _credentialStore.read(
      key: _linkedAccountOauthExpiryKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
    final int? millis = _parseEpochMillis(stored);
    if (millis == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  Future<void> _writeLinkedAccountOauthTokens({
    required String scope,
    required EmailAccountId accountId,
    required EmailOauthProvider provider,
    required EmailOauthTokens tokens,
  }) async {
    await _credentialStore.write(
      key: _linkedAccountOauthProviderKeyFor(
        scope: scope,
        accountId: accountId,
      ),
      value: provider.storageValue,
    );
    await _credentialStore.write(
      key: _linkedAccountOauthAccessTokenKeyFor(
        scope: scope,
        accountId: accountId,
      ),
      value: tokens.accessToken,
    );
    await _credentialStore.write(
      key: _linkedAccountOauthRefreshTokenKeyFor(
        scope: scope,
        accountId: accountId,
      ),
      value: tokens.refreshToken,
    );
    await _credentialStore.write(
      key: _linkedAccountOauthExpiryKeyFor(
        scope: scope,
        accountId: accountId,
      ),
      value: tokens.expiresAt.millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> _clearLinkedAccountOauthTokens({
    required String scope,
    required EmailAccountId accountId,
  }) async {
    await _credentialStore.delete(
      key: _linkedAccountOauthProviderKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
    await _credentialStore.delete(
      key: _linkedAccountOauthAccessTokenKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
    await _credentialStore.delete(
      key: _linkedAccountOauthRefreshTokenKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
    await _credentialStore.delete(
      key: _linkedAccountOauthExpiryKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
  }

  int? _parseEpochMillis(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(value);
    if (parsed == null || parsed <= _oauthEpochMillisMissing) {
      return null;
    }
    return parsed;
  }

  Future<EmailAccountProfile?> _readLinkedAccountProfile({
    required String scope,
    required EmailAccountId accountId,
    required EmailAccountId? primaryId,
  }) async {
    final String? storedAddress = await _credentialStore.read(
      key: _linkedAccountAddressKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
    final String resolvedAddress = _normalizeLinkedAccountAddress(
      storedAddress ?? accountId.value,
    );
    if (resolvedAddress.isEmpty) {
      return null;
    }
    final String? storedDisplayName = await _credentialStore.read(
      key: _linkedAccountDisplayNameKeyFor(
        scope: scope,
        accountId: accountId,
      ),
    );
    final String resolvedDisplayName = _displayNameForAddress(
      resolvedAddress,
      displayName: storedDisplayName,
    );
    final EmailAuthMethod authMethod = await _readLinkedAccountAuthMethod(
      scope: scope,
      accountId: accountId,
    );
    final int? deltaAccountId = await _readLinkedAccountDeltaId(
      scope: scope,
      accountId: accountId,
    );
    final bool isPrimary = primaryId != null && primaryId == accountId;
    return EmailAccountProfile(
      id: accountId,
      address: resolvedAddress,
      displayName: resolvedDisplayName,
      authMethod: authMethod,
      isPrimary: isPrimary,
      deltaAccountId: deltaAccountId,
    );
  }

  Future<void> _hydrateLegacyAccountIfNeeded(String scope) async {
    final String? legacyAddress = await _credentialStore.read(
      key: _addressKeyForScope(scope),
    );
    if (legacyAddress == null || legacyAddress.isEmpty) {
      return;
    }
    final EmailAccountId? accountId = EmailAccountId.fromAddress(
      legacyAddress,
    );
    if (accountId == null) {
      return;
    }
    final RegisteredCredentialKey addressKey = _linkedAccountAddressKeyFor(
      scope: scope,
      accountId: accountId,
    );
    final String? existingAddress = await _credentialStore.read(
      key: addressKey,
    );
    if (existingAddress == null || existingAddress.isEmpty) {
      await _credentialStore.write(
        key: addressKey,
        value: legacyAddress,
      );
    }
    final String? legacyPassword = await _credentialStore.read(
      key: _passwordKeyForScope(scope),
    );
    if (legacyPassword != null && legacyPassword.isNotEmpty) {
      final RegisteredCredentialKey passwordKey = _linkedAccountPasswordKeyFor(
        scope: scope,
        accountId: accountId,
      );
      final String? existingPassword = await _credentialStore.read(
        key: passwordKey,
      );
      if (existingPassword == null || existingPassword.isEmpty) {
        await _credentialStore.write(
          key: passwordKey,
          value: legacyPassword,
        );
      }
    }
    final RegisteredCredentialKey authMethodKey =
        _linkedAccountAuthMethodKeyFor(
      scope: scope,
      accountId: accountId,
    );
    final String? existingAuthMethod = await _credentialStore.read(
      key: authMethodKey,
    );
    if (existingAuthMethod == null || existingAuthMethod.isEmpty) {
      await _credentialStore.write(
        key: authMethodKey,
        value: EmailAuthMethod.password.storageValue,
      );
    }
    final String? legacyProvisioned = await _credentialStore.read(
      key: _provisionedKeyForScope(scope),
    );
    if (legacyProvisioned != null && legacyProvisioned.isNotEmpty) {
      final RegisteredCredentialKey provisionedKey =
          _linkedAccountProvisionedKeyFor(
        scope: scope,
        accountId: accountId,
      );
      final String? existingProvisioned = await _credentialStore.read(
        key: provisionedKey,
      );
      if (existingProvisioned == null || existingProvisioned.isEmpty) {
        await _credentialStore.write(
          key: provisionedKey,
          value: legacyProvisioned,
        );
      }
    }
    final RegisteredCredentialKey primaryKey = _linkedAccountPrimaryKeyForScope(
      scope,
    );
    final String? existingPrimary = await _credentialStore.read(
      key: primaryKey,
    );
    if (existingPrimary == null || existingPrimary.isEmpty) {
      await _credentialStore.write(
        key: primaryKey,
        value: accountId.value,
      );
    }
  }

  Future<void> _clearLinkedAccountKeys(String scope) async {
    final List<EmailAccountId> accountIds = await _readLinkedAccountIds(
      scope,
      includeLegacy: true,
    );
    await _credentialStore.delete(key: _linkedAccountListKeyForScope(scope));
    await _credentialStore.delete(
      key: _linkedAccountPrimaryKeyForScope(scope),
    );
    for (final EmailAccountId accountId in accountIds) {
      await _credentialStore.delete(
        key: _linkedAccountAddressKeyFor(
          scope: scope,
          accountId: accountId,
        ),
      );
      await _credentialStore.delete(
        key: _linkedAccountPasswordKeyFor(
          scope: scope,
          accountId: accountId,
        ),
      );
      await _credentialStore.delete(
        key: _linkedAccountAuthMethodKeyFor(
          scope: scope,
          accountId: accountId,
        ),
      );
      await _credentialStore.delete(
        key: _linkedAccountDisplayNameKeyFor(
          scope: scope,
          accountId: accountId,
        ),
      );
      await _credentialStore.delete(
        key: _linkedAccountDeltaIdKeyFor(
          scope: scope,
          accountId: accountId,
        ),
      );
      await _credentialStore.delete(
        key: _linkedAccountProvisionedKeyFor(
          scope: scope,
          accountId: accountId,
        ),
      );
    }
  }

  RegisteredCredentialKey _bootstrapKeyFor({
    required String scope,
    required String databasePrefix,
  }) {
    final identifier = '${_emailBootstrapKeyPrefix}_${databasePrefix}_$scope';
    return _bootstrapKeys.putIfAbsent(
      identifier,
      () => CredentialStore.registerKey(identifier),
    );
  }

  String _scopeForJid(String jid) => _normalizeJid(jid).toLowerCase();

  String? _scopeForOptionalJid(String? jid) =>
      jid == null ? _activeCredentialScope : _scopeForJid(jid);

  String _normalizeJid(String jid) => jid.split('/').first;

  String _requireActiveScope() {
    final scope = _activeCredentialScope;
    if (scope != null) {
      return scope;
    }
    throw StateError('Call ensureProvisioned before using EmailService.');
  }

  Future<int> _ensureLinkedAccountDeltaId({
    required String scope,
    required EmailAccountId accountId,
  }) async {
    final int? stored = await _readLinkedAccountDeltaId(
      scope: scope,
      accountId: accountId,
    );
    if (stored != null) {
      return stored;
    }
    if (!_transport.accountsSupported) {
      final EmailAccountId? legacyId = await _legacyAccountIdForScope(scope);
      if (legacyId != null && legacyId != accountId) {
        throw StateError(_linkedEmailAccountsUnsupportedError);
      }
      await _credentialStore.write(
        key: _linkedAccountDeltaIdKeyFor(
          scope: scope,
          accountId: accountId,
        ),
        value: deltaAccountIdLegacy.toString(),
      );
      return deltaAccountIdLegacy;
    }
    final int deltaAccountId = await _transport.createAccount();
    await _credentialStore.write(
      key: _linkedAccountDeltaIdKeyFor(
        scope: scope,
        accountId: accountId,
      ),
      value: deltaAccountId.toString(),
    );
    return deltaAccountId;
  }

  Future<EmailAccountProfile?> _primaryLinkedAccountForScope(
    String scope,
  ) async {
    final accounts = await linkedAccounts(scope);
    if (accounts.isEmpty) {
      return null;
    }
    for (final account in accounts) {
      if (account.isPrimary) {
        return account;
      }
    }
    return accounts.first;
  }

  Future<EmailAccountProfile?> _linkedAccountProfileForScope({
    required String scope,
    required EmailAccountId accountId,
  }) async {
    final EmailAccountId? primaryId = await _readPrimaryAccountId(scope);
    return _readLinkedAccountProfile(
      scope: scope,
      accountId: accountId,
      primaryId: primaryId,
    );
  }

  Future<void> _updateChatEmailFromAddress(Chat chat, String? address) async {
    if (chat.emailFromAddress == address) {
      return;
    }
    final db = await _databaseBuilder();
    await db.updateChat(chat.copyWith(emailFromAddress: address));
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

  Future<_ResolvedEmailAccount> _resolveAccountForAddress({
    required String scope,
    String? fromAddress,
  }) async {
    var resolved = fromAddress?.trim() ?? '';
    if (resolved.isEmpty) {
      final primary = await _primaryLinkedAccountForScope(scope);
      resolved = primary?.address ?? '';
    }
    if (resolved.isEmpty) {
      resolved = _activeAccount?.address ?? '';
    }
    final normalized = _normalizeLinkedAccountAddress(resolved);
    if (normalized.isEmpty) {
      throw StateError(_linkedEmailAccountMissingAddressError);
    }
    final EmailAccountId? accountId = EmailAccountId.fromAddress(normalized);
    if (accountId == null) {
      throw StateError(_linkedEmailAccountMissingAddressError);
    }
    await _ensureLinkedAccountExists(
      scope: scope,
      accountId: accountId,
    );
    final int deltaAccountId = await _ensureLinkedAccountDeltaId(
      scope: scope,
      accountId: accountId,
    );
    await _hydrateAccountAddress(
      address: normalized,
      deltaAccountId: deltaAccountId,
    );
    return _ResolvedEmailAccount(
      id: accountId,
      address: normalized,
      deltaAccountId: deltaAccountId,
    );
  }

  Future<_ResolvedEmailAccount> _resolveAccountForChat(Chat chat) async {
    final String scope = _requireActiveScope();
    final resolved = await _resolveAccountForAddress(
      scope: scope,
      fromAddress: chat.emailFromAddress,
    );
    await _updateChatEmailFromAddress(chat, resolved.address);
    return resolved;
  }

  Future<void> _ensureAccountConfigured({
    required String scope,
    required _ResolvedEmailAccount account,
    bool forceProvisioning = false,
  }) async {
    await _transport.ensureAccountSession(account.deltaAccountId);
    final configured = await _transport.isConfigured(
      accountId: account.deltaAccountId,
    );
    if (configured && !forceProvisioning) {
      return;
    }
    final EmailAccount? credentials = await linkedAccountCredentials(
      jid: scope,
      accountId: account.id,
    );
    if (credentials == null || credentials.password.isEmpty) {
      throw StateError(_linkedEmailAccountMissingPasswordError);
    }
    final EmailAccountProfile? profile = await _linkedAccountProfileForScope(
      scope: scope,
      accountId: account.id,
    );
    final EmailAuthMethod authMethod = await _readLinkedAccountAuthMethod(
      scope: scope,
      accountId: account.id,
    );
    final String displayName = profile?.displayName ??
        _displayNameForAddress(
          account.address,
        );
    final Map<String, String> connectionOverrides =
        _buildConnectionConfigForAuth(
      address: account.address,
      authMethod: authMethod,
    );
    final Map<String, String> configureOverrides =
        Map<String, String>.of(connectionOverrides)
          ..[_sendPasswordConfigKey] = credentials.password;
    try {
      await _transport.configureAccount(
        address: account.address,
        password: credentials.password,
        displayName: displayName,
        additional: configureOverrides,
        accountId: account.deltaAccountId,
      );
      await _transport.purgeStockMessages(accountId: account.deltaAccountId);
      await _credentialStore.write(
        key: _linkedAccountProvisionedKeyFor(
          scope: scope,
          accountId: account.id,
        ),
        value: _linkedEmailAccountBoolTrue,
      );
    } on DeltaSafeException catch (error, stackTrace) {
      final mapped = DeltaChatExceptionMapper.fromDeltaSafe(
        error,
        operation: 'configure email account',
      );
      final errorType = error.runtimeType;
      _log.warning(
        'Failed to configure linked email account ($errorType)',
        null,
        stackTrace,
      );
      if (mapped.code == DeltaChatErrorCode.network ||
          mapped.code == DeltaChatErrorCode.server) {
        throw const EmailProvisioningException(
          'Unable to reach the email service. Please try again.',
          isRecoverable: true,
        );
      }
      throw EmailProvisioningException(
        'Unable to configure email. Please check your credentials.',
        shouldWipeCredentials: mapped.code == DeltaChatErrorCode.permission ||
            mapped.code == DeltaChatErrorCode.auth,
      );
    }
  }

  Future<int> _ensureDeltaChatIdForAccount({
    required Chat chat,
    required _ResolvedEmailAccount account,
  }) async {
    final db = await _databaseBuilder();
    final int? existing = await db.getDeltaChatIdForAccount(
      chatJid: chat.jid,
      deltaAccountId: account.deltaAccountId,
    );
    if (existing != null) {
      return existing;
    }
    final String address = chat.emailAddress ?? chat.contactJid ?? chat.jid;
    final String displayName = chat.contactDisplayName ?? chat.title;
    final int chatId = await _guardDeltaOperation(
      operation: 'ensure email chat',
      body: () => _transport.ensureChatForAddress(
        address: address,
        displayName: displayName,
        accountId: account.deltaAccountId,
      ),
    );
    if (chat.deltaChatId == null &&
        account.deltaAccountId == _transport.activeAccountId) {
      await db.updateChat(
        chat.copyWith(
          deltaChatId: chatId,
          emailAddress: chat.emailAddress ?? address,
        ),
      );
    }
    return chatId;
  }

  Future<int?> _deltaChatIdForAccount({
    required Chat chat,
    required int deltaAccountId,
  }) async {
    if (chat.deltaChatId != null &&
        deltaAccountId == _transport.activeAccountId) {
      return chat.deltaChatId;
    }
    final db = await _databaseBuilder();
    return db.getDeltaChatIdForAccount(
      chatJid: chat.jid,
      deltaAccountId: deltaAccountId,
    );
  }

  Future<_EmailChatContext> _ensureEmailChatContext(Chat chat) async {
    await _ensureReady();
    final String scope = _requireActiveScope();
    final _ResolvedEmailAccount account = await _resolveAccountForChat(chat);
    await _ensureAccountConfigured(scope: scope, account: account);
    final int chatId = await _ensureDeltaChatIdForAccount(
      chat: chat,
      account: account,
    );
    return _EmailChatContext(
      chat: chat,
      deltaChatId: chatId,
      account: account,
    );
  }

  Future<void> _ensureLinkedAccountsProvisioned({
    required String scope,
  }) async {
    if (!_transport.accountsSupported) {
      return;
    }
    final accounts = await linkedAccounts(scope);
    if (accounts.length <= _linkedEmailAccountsPrimaryCount) {
      return;
    }
    for (final account in accounts) {
      if (account.isPrimary) {
        continue;
      }
      try {
        final EmailAccountId accountId = account.id;
        final int deltaAccountId = await _ensureLinkedAccountDeltaId(
          scope: scope,
          accountId: accountId,
        );
        await _hydrateAccountAddress(
          address: account.address,
          deltaAccountId: deltaAccountId,
        );
        await _ensureAccountConfigured(
          scope: scope,
          account: _ResolvedEmailAccount(
            id: accountId,
            address: account.address,
            deltaAccountId: deltaAccountId,
          ),
        );
      } on Exception catch (error, stackTrace) {
        _log.warning(
          'Linked email provisioning failed',
          error,
          stackTrace,
        );
      }
    }
  }

  Future<void> _clearCredentials(String scope) async {
    await _credentialStore.delete(key: _addressKeyForScope(scope));
    await _credentialStore.delete(key: _passwordKeyForScope(scope));
    await _credentialStore.delete(key: _provisionedKeyForScope(scope));
    await _credentialStore.delete(key: _connectionOverrideKeyForScope(scope));
    await _clearLinkedAccountKeys(scope);
    if (_activeCredentialScope == scope) {
      _activeCredentialScope = null;
      _activeAccount = null;
    }
    _ephemeralProvisionedScopes.remove(scope);
    _ephemeralConnectionOverrideScopes.remove(scope);
  }

  Future<T> _guardDeltaOperation<T>({
    required String operation,
    required Future<T> Function() body,
  }) async {
    try {
      return await body();
    } on DeltaSafeException catch (error) {
      throw DeltaChatExceptionMapper.fromDeltaSafe(
        error,
        operation: operation,
      );
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
        key: addressKey, value: _activeAccount!.address);
    await _credentialStore.write(
        key: passwordKey, value: _activeAccount!.password);
    await _credentialStore.write(
      key: provisionedKey,
      value: _credentialTrueValue,
    );
    final EmailAccountId? accountId = EmailAccountId.fromAddress(
      _activeAccount!.address,
    );
    if (accountId != null) {
      final List<EmailAccountId> currentIds = await _readLinkedAccountIds(
        scope,
        includeLegacy: true,
      );
      final List<EmailAccountId> nextIds = List<EmailAccountId>.of(currentIds)
        ..removeWhere((EmailAccountId entry) => entry == accountId)
        ..add(accountId);
      await _writeLinkedAccountIds(scope, nextIds);
      await _credentialStore.write(
        key: _linkedAccountAddressKeyFor(
          scope: scope,
          accountId: accountId,
        ),
        value: _activeAccount!.address,
      );
      await _credentialStore.write(
        key: _linkedAccountPasswordKeyFor(
          scope: scope,
          accountId: accountId,
        ),
        value: _activeAccount!.password,
      );
      await _credentialStore.write(
        key: _linkedAccountAuthMethodKeyFor(
          scope: scope,
          accountId: accountId,
        ),
        value: EmailAuthMethod.password.storageValue,
      );
      await _credentialStore.write(
        key: _linkedAccountProvisionedKeyFor(
          scope: scope,
          accountId: accountId,
        ),
        value: _linkedEmailAccountBoolTrue,
      );
      final int activeDeltaAccountId = _transport.activeAccountId;
      await _credentialStore.write(
        key: _linkedAccountDeltaIdKeyFor(
          scope: scope,
          accountId: accountId,
        ),
        value: activeDeltaAccountId.toString(),
      );
      final RegisteredCredentialKey primaryKey =
          _linkedAccountPrimaryKeyForScope(scope);
      final String? primaryValue = await _credentialStore.read(
        key: primaryKey,
      );
      if (primaryValue == null || primaryValue.trim().isEmpty) {
        await _credentialStore.write(
          key: primaryKey,
          value: accountId.value,
        );
      }
    }
    _ephemeralProvisionedScopes.add(scope);
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
    await _clearLinkedAccountKeys(scope);
    if (!preserveActiveSession && _activeCredentialScope == scope) {
      _activeCredentialScope = null;
      _activeAccount = null;
    }
    if (!preserveActiveSession) {
      _ephemeralProvisionedScopes.remove(scope);
      _ephemeralConnectionOverrideScopes.remove(scope);
    }
  }

  /// Marks a chat as noticed, clearing unread badges in core.
  ///
  /// Call this when the user opens a chat.
  Future<bool> markNoticedChat(Chat chat) async {
    await _ensureReady();
    final account = await _resolveAccountForChat(chat);
    final chatId = await _deltaChatIdForAccount(
      chat: chat,
      deltaAccountId: account.deltaAccountId,
    );
    if (chatId == null) {
      return false;
    }
    return _transport.markNoticedChat(
      chatId,
      accountId: account.deltaAccountId,
    );
  }

  /// Marks messages as seen, triggering MDN if enabled.
  ///
  /// Call this when messages are displayed to the user.
  Future<bool> markSeenMessages(List<Message> messages) async {
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
    final account = await _resolveAccountForChat(chat);
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
      for (final message in deltaMessages) {
        await db.deleteMessage(message.stanzaID);
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
    final account = await _resolveAccountForChat(toChat);
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
    final _ResolvedEmailAccount account = chat == null
        ? await _resolveAccountForAddress(scope: scope)
        : await _resolveAccountForChat(chat);
    final int chatId = chat == null
        ? 0
        : (await _deltaChatIdForAccount(
              chat: chat,
              deltaAccountId: account.deltaAccountId,
            ) ??
            0);
    final deltaIds = await _transport.searchMessages(
      chatId: chatId,
      query: query,
      accountId: account.deltaAccountId,
    );
    if (deltaIds.isEmpty) return const [];

    final db = await _databaseBuilder();
    final int deltaAccountId = account.deltaAccountId;
    final messagesByDeltaId = <int, Message>{};
    final missingIds = <int>[];
    for (final deltaId in deltaIds) {
      final stanzaId = _stanzaId(
        deltaId,
        accountId: deltaAccountId,
      );
      final message = await db.getMessageByDeltaId(
            deltaId,
            deltaAccountId: deltaAccountId,
          ) ??
          await db.getMessageByStanzaID(stanzaId);
      if (message != null) {
        messagesByDeltaId[deltaId] = message;
      } else {
        missingIds.add(deltaId);
      }
    }
    if (missingIds.isNotEmpty) {
      await _transport.hydrateMessages(
        missingIds,
        accountId: deltaAccountId,
      );
      for (final deltaId in missingIds) {
        final stanzaId = _stanzaId(
          deltaId,
          accountId: deltaAccountId,
        );
        final message = await db.getMessageByDeltaId(
              deltaId,
              deltaAccountId: deltaAccountId,
            ) ??
            await db.getMessageByStanzaID(stanzaId);
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
    final account = await _resolveAccountForChat(chat);
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
    final quotedMsgId = quotedMessage.deltaMsgId;
    final context = await _ensureEmailChatContext(chat);
    final chatId = context.deltaChatId;
    if (quotedMsgId == null ||
        quotedMessage.deltaAccountId != context.account.deltaAccountId) {
      return sendMessage(
        chat: chat,
        body: body,
        subject: subject,
        htmlBody: htmlBody,
      );
    }
    await _ensureReady();
    final normalizedSubject = _normalizeSubject(subject);
    final normalizedHtml = HtmlContentCodec.normalizeHtml(htmlBody);
    final trimmedBody = body.trim();
    final resolvedBody = trimmedBody.isNotEmpty
        ? trimmedBody
        : (normalizedHtml == null
            ? ''
            : HtmlContentCodec.toPlainText(normalizedHtml));
    final msgId = await _guardDeltaOperation(
      operation: 'send reply',
      body: () => _transport.sendTextWithQuote(
        chatId: chatId,
        body: resolvedBody,
        quotedMessageId: quotedMsgId,
        subject: normalizedSubject,
        htmlBody: normalizedHtml,
        accountId: context.account.deltaAccountId,
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
  Future<String?> getMessageRawHeaders(int messageId) async {
    if (messageId <= _deltaMessageIdUnset) return null;
    await _ensureReady();
    final headers = await _transport.getMessageMimeHeaders(messageId);
    return sanitizeRawEmailHeaders(headers);
  }

  /// Saves a draft to core.
  Future<bool> saveDraftToCore({
    required Chat chat,
    required String text,
    String? subject,
    String? htmlBody,
    List<EmailAttachment> attachments = _emptyEmailAttachments,
  }) async {
    final context = await _ensureEmailChatContext(chat);
    final chatId = context.deltaChatId;
    await _ensureReady();
    final normalizedSubject = _normalizeSubject(subject);
    final normalizedHtml = _normalizeDraftHtml(
      text: text,
      htmlBody: htmlBody,
    );
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
      accountId: context.account.deltaAccountId,
    );
  }

  /// Clears a draft from core.
  Future<bool> clearDraftFromCore(Chat chat) async {
    await _ensureReady();
    final account = await _resolveAccountForChat(chat);
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
    final account = await _resolveAccountForChat(chat);
    final chatId = await _deltaChatIdForAccount(
      chat: chat,
      deltaAccountId: account.deltaAccountId,
    );
    if (chatId == null) {
      return null;
    }
    return _transport.getDraft(
      chatId,
      accountId: account.deltaAccountId,
    );
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

  /// Gets a contact by ID from core.
  Future<DeltaContact?> getContact(int contactId) async {
    await _ensureReady();
    return _transport.getContact(contactId);
  }

  /// Gets all contacts from core as a list.
  ///
  /// Use flags from [DeltaContactListFlags] to filter results.
  Future<List<DeltaContact>> getContacts({
    int flags = 0,
    String? query,
  }) async {
    await _ensureReady();
    final ids = await _transport.getContactIds(flags: flags, query: query);
    final contacts = <DeltaContact>[];
    for (final id in ids) {
      final contact = await _transport.getContact(id);
      if (contact != null) {
        contacts.add(contact);
      }
    }
    return contacts;
  }

  /// Gets all blocked contacts from core as a list.
  Future<List<DeltaContact>> getBlockedContacts() async {
    await _ensureReady();
    final ids = await _transport.getBlockedContactIds();
    final contacts = <DeltaContact>[];
    for (final id in ids) {
      final contact = await _transport.getContact(id);
      if (contact != null) {
        contacts.add(contact);
      }
    }
    return contacts;
  }
}

String _stanzaId(
  int msgId, {
  required int accountId,
}) {
  return deltaMessageStanzaId(msgId, accountId: accountId);
}

class _PendingNotification {
  const _PendingNotification({
    required this.chatId,
    required this.msgId,
    required this.accountId,
  });

  final int chatId;
  final int msgId;
  final int accountId;
}

class _DeltaNotificationContext {
  const _DeltaNotificationContext({
    required this.message,
    required this.chat,
  });

  final Message message;
  final Chat? chat;
}
