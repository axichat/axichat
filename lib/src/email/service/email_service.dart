// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive_io.dart';
import 'package:axichat/src/common/anti_abuse_sync.dart';
import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:axichat/src/common/email_validation.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/foreground_task_messages.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:axichat/src/common/synthetic_reply.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/demo/demo_chats.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
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
import 'package:axichat/src/email/transport/email_delta_worker_runtime.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/email/util/async_queue.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/email/util/delta_message_ids.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/email/util/email_header_safety.dart';
import 'package:axichat/src/email/util/email_message_ids.dart';
import 'package:axichat/src/email/util/share_token_html.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/notifications/notification_payload.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/connection/foreground_socket.dart';

enum _EmailSyncSource {
  unknown,
  coreError,
  selfNotInGroup,
  connectivityConfirm,
  connectivityApply,
  connectivityChangedEvent,
  backgroundFetchDone,
  networkAvailable,
  networkLost,
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

enum _EmailReconnectRestartPolicy { offlineOnly, foregroundResume }

enum _EmailNetworkTransition { lost, available, foregroundResumeAvailable }

enum EmailShutdownMode { graceful, logout }

enum EmailPasswordRefreshResult {
  confirmed,
  reconnectPending;

  bool get isConfirmed => this == confirmed;
}

enum EmailOutgoingEncryptionMode {
  plaintextNoAutocrypt,
  autocryptBeta;

  bool get forcePlaintext => this == plaintextNoAutocrypt;

  bool get skipAutocrypt => this == plaintextNoAutocrypt;
}

final class EmailEncryptionAccountInfo {
  const EmailEncryptionAccountInfo({
    required this.normalizedAddress,
    required this.deltaAccountId,
    this.hasSelfKey = false,
  });

  final String normalizedAddress;
  final int deltaAccountId;
  final bool hasSelfKey;
}

final class EmailEncryptionKeyExport {
  const EmailEncryptionKeyExport({
    required this.normalizedAddress,
    required this.archiveBytes,
  });

  final String normalizedAddress;
  final Uint8List archiveBytes;
}

enum EmailOpenPgpKeyKind { public, private }

enum EmailOpenPgpIdentityBinding { addressMatch, userConfirmed }

final class EmailOpenPgpKeyMetadata {
  const EmailOpenPgpKeyMetadata({
    required this.kind,
    required this.fingerprint,
    required this.userIds,
    required this.hasExpectedAddress,
    required this.hasEncryptionCapability,
  });

  final EmailOpenPgpKeyKind kind;
  final String fingerprint;
  final List<String> userIds;
  final bool hasExpectedAddress;
  final bool hasEncryptionCapability;

  bool get requiresIdentityConfirmation => !hasExpectedAddress;

  EmailOpenPgpIdentityBinding get defaultIdentityBinding => hasExpectedAddress
      ? EmailOpenPgpIdentityBinding.addressMatch
      : EmailOpenPgpIdentityBinding.userConfirmed;
}

final class EmailTrustedContactKey {
  const EmailTrustedContactKey({
    required this.deltaAccountId,
    required this.normalizedAddress,
    required this.fingerprint,
    required this.deltaContactId,
    required this.deltaChatId,
    required this.identityBinding,
    required this.userIds,
    required this.importedAt,
  });

  factory EmailTrustedContactKey.fromData(EmailTrustedContactKeyData data) {
    final decodedUserIds = switch (data.userIdsJson) {
      final String value when value.trim().isNotEmpty => jsonDecode(value),
      _ => const <Object?>[],
    };
    return EmailTrustedContactKey(
      deltaAccountId: data.deltaAccountId,
      normalizedAddress: data.address,
      fingerprint: data.fingerprint,
      deltaContactId: data.deltaContactId,
      deltaChatId: data.deltaChatId,
      identityBinding: _emailOpenPgpIdentityBindingFromStorage(
        data.identityBinding,
      ),
      userIds: switch (decodedUserIds) {
        final List<Object?> values =>
          values
              .map((value) => value?.toString() ?? '')
              .where((value) => value.trim().isNotEmpty)
              .toList(growable: false),
        _ => const <String>[],
      },
      importedAt: data.importedAt,
    );
  }

  final int deltaAccountId;
  final String normalizedAddress;
  final String fingerprint;
  final int deltaContactId;
  final int deltaChatId;
  final EmailOpenPgpIdentityBinding identityBinding;
  final List<String> userIds;
  final DateTime importedAt;

  EmailTrustedContactKeyData toData() => EmailTrustedContactKeyData(
    deltaAccountId: deltaAccountId,
    address: normalizedAddress,
    fingerprint: fingerprint,
    deltaContactId: deltaContactId,
    deltaChatId: deltaChatId,
    identityBinding: identityBinding.name,
    userIdsJson: jsonEncode(userIds),
    importedAt: importedAt,
  );
}

EmailOpenPgpIdentityBinding _emailOpenPgpIdentityBindingFromStorage(
  String value,
) {
  for (final binding in EmailOpenPgpIdentityBinding.values) {
    if (binding.name == value) {
      return binding;
    }
  }
  return EmailOpenPgpIdentityBinding.userConfirmed;
}

sealed class EmailEncryptionKeyException implements Exception {
  const EmailEncryptionKeyException();
}

final class EmailEncryptionNoActiveAccountException
    extends EmailEncryptionKeyException {
  const EmailEncryptionNoActiveAccountException();
}

final class EmailEncryptionUnsupportedKeyFormatException
    extends EmailEncryptionKeyException {
  const EmailEncryptionUnsupportedKeyFormatException();
}

final class EmailEncryptionNoPrivateKeyFoundException
    extends EmailEncryptionKeyException {
  const EmailEncryptionNoPrivateKeyFoundException();
}

final class EmailEncryptionAmbiguousKeyArchiveException
    extends EmailEncryptionKeyException {
  const EmailEncryptionAmbiguousKeyArchiveException();
}

final class EmailEncryptionImportFailedException
    extends EmailEncryptionKeyException {
  const EmailEncryptionImportFailedException();
}

final class EmailEncryptionExportFailedException
    extends EmailEncryptionKeyException {
  const EmailEncryptionExportFailedException();
}

final class EmailEncryptionSaveFailedException
    extends EmailEncryptionKeyException {
  const EmailEncryptionSaveFailedException();
}

sealed class EmailContactKeyException implements Exception {
  const EmailContactKeyException();
}

final class EmailContactKeyNoActiveAccountException
    extends EmailContactKeyException {
  const EmailContactKeyNoActiveAccountException();
}

final class EmailContactKeyUnsupportedFormatException
    extends EmailContactKeyException {
  const EmailContactKeyUnsupportedFormatException();
}

final class EmailContactKeyImportFailedException
    extends EmailContactKeyException {
  const EmailContactKeyImportFailedException();
}

final class EmailContactKeyRemoveFailedException
    extends EmailContactKeyException {
  const EmailContactKeyRemoveFailedException();
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

  String senderIdentity(EmailDeltaRuntime transport) =>
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

  String senderIdentity(EmailDeltaRuntime transport) =>
      account.senderIdentity(transport);
}

final class _DeltaChatMessageId {
  const _DeltaChatMessageId({
    required this.accountId,
    required this.chatId,
    required this.msgId,
  });

  final int accountId;
  final int? chatId;
  final int msgId;
}

final class _EmailRuntimeEventCore implements DeltaEventCore {
  const _EmailRuntimeEventCore({
    required EmailDeltaRuntime transport,
    required int accountId,
  }) : _transport = transport,
       _accountId = accountId;

  final EmailDeltaRuntime _transport;
  final int _accountId;

  @override
  int get accountId => _accountId;

  @override
  bool get supportsMessageRfc724Mid => true;

  @override
  bool get supportsMessageInfo => true;

  @override
  bool get supportsMessageDebugInfo => true;

  @override
  Future<List<DeltaChatlistEntry>> getChatlist({int flags = 0}) =>
      _transport.getChatlist(flags: flags, accountId: _accountId);

  @override
  Future<List<int>> getChatMessageIds({
    required int chatId,
    int? beforeMessageId,
  }) => _transport.getChatMessageIds(
    chatId: chatId,
    beforeMessageId: beforeMessageId,
    accountId: _accountId,
  );

  @override
  Future<DeltaMessage?> getMessage(int messageId) =>
      _transport.getMessage(messageId, accountId: _accountId);

  @override
  Future<List<DeltaMessage>> getMessages(List<int> messageIds) =>
      _transport.getMessages(messageIds, accountId: _accountId);

  @override
  Future<DeltaFreshMessageCount> getFreshMessageCountSafe(int chatId) =>
      _transport.getFreshMessageCountSafe(chatId, accountId: _accountId);

  @override
  Future<bool> downloadFullMessage(int messageId) =>
      _transport.downloadFullMessage(messageId, accountId: _accountId);

  @override
  Future<String?> getMessageRfc724Mid(int messageId) =>
      _transport.getMessageRfc724Mid(messageId, accountId: _accountId);

  @override
  Future<String?> getMessageInfo(int messageId) =>
      _transport.getMessageInfo(messageId, accountId: _accountId);

  @override
  Future<String?> getMessageMimeHeaders(int messageId) =>
      _transport.getMessageMimeHeaders(messageId, accountId: _accountId);

  @override
  Future<String?> getMessageDebugInfo(int messageId) =>
      _transport.getMessageDebugInfo(messageId, accountId: _accountId);

  @override
  Future<DeltaMessageRfc822Body?> getMessageRfc822Body(int messageId) =>
      _transport.getMessageRfc822Body(messageId, accountId: _accountId);

  @override
  Future<DeltaContactPublicKeyImport> importContactPublicKey({
    required String address,
    required String displayName,
    required String armoredPublicKey,
  }) => _transport.importContactPublicKey(
    address: address,
    displayName: displayName,
    armoredPublicKey: armoredPublicKey,
    accountId: _accountId,
  );

  @override
  Future<DeltaChatSendCapabilities> chatSendCapabilities(int chatId) =>
      _transport.chatSendCapabilities(chatId: chatId, accountId: _accountId);

  @override
  Future<DeltaChat?> getChat(int chatId) =>
      _transport.getChat(chatId, accountId: _accountId);
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

final class EmailServiceTrustedContactKeyUnavailableException
    extends EmailServiceException {
  const EmailServiceTrustedContactKeyUnavailableException();
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
  static const int _fanOutConcurrentOps = 4;
  static const int _contactHydrationConcurrentOps = 6;
  static const int _attachmentFanOutWarningBytes = 8 * 1024 * 1024;
  static const int _deltaMessageIdUnset = DeltaMessageId.none;
  static const int _emptyUnreadCount = 0;
  static const Duration _foregroundFetchTimeout = Duration(seconds: 15);
  static const Duration _connectivityProbeTimeout = Duration(seconds: 1);
  static const Duration _notificationFlushDelay = Duration(milliseconds: 500);
  static const Duration _contactsSyncDebounce = Duration(seconds: 2);
  static const int _connectivityConnectedMin = 4000;
  static const int _connectivityWorkingMin = 3000;
  static const int _connectivityConnectingMin = 2000;
  static const int _connectivityLogIntervalSeconds = 5;
  static const Duration _connectivityLogInterval = Duration(
    seconds: _connectivityLogIntervalSeconds,
  );
  static const int _connectivityDetailLogIntervalSeconds = 60;
  static const Duration _connectivityDetailLogInterval = Duration(
    seconds: _connectivityDetailLogIntervalSeconds,
  );
  static const int _connectivityDetailConnectingSampleThreshold = 4;
  static const int _connectivityDetailMaxLength = 500;
  static const String _emailConnectivityLogPrefix = 'Email connectivity';
  static const String _emailConnectivityDetailLogPrefix =
      'Email connectivity detail';
  static const String _emailSyncLogPrefix = 'Email sync state';
  static const String _emailLogSourceLabel = 'source';
  static const String _emailLogValueLabel = 'value';
  static const String _emailLogStateLabel = 'state';
  static const String _emailLogConnectivityLabel = 'connectivity';
  static const String _emailLogHasMessageLabel = 'hasMessage';
  static const String _emailLogIoRunningLabel = 'ioRunning';
  static const String _emailLogDetailLabel = 'detail';
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
  static const String _signUnencryptedConfigKey = 'sign_unencrypted';
  static const String _signUnencryptedDisabledValue = '0';
  static const String _openPgpKeyIdConfigKey = 'key_id';
  static const String _privateKeyArmorBegin =
      '-----BEGIN PGP PRIVATE KEY BLOCK-----';
  static const String _publicKeyArmorBegin =
      '-----BEGIN PGP PUBLIC KEY BLOCK-----';
  static const String _emailEncryptionImportFileName = 'private-key.asc';
  static const String _emailEncryptionExportArchiveName =
      'axichat-email-openpgp-key.zip';
  static const Set<String> _emailEncryptionDirectImportExtensions = {
    '.asc',
    '.pgp',
    '.gpg',
  };
  static const String _syncMsgsConfigKey = 'sync_msgs';
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
    EmailDeltaRuntime? transport,
    EmailDeltaRuntime Function()? transportFactory,
    EmailConnectionConfigBuilder? connectionConfigBuilder,
    NotificationService? notificationService,
    Logger? logger,
    ForegroundTaskBridge? foregroundBridge,
    EndpointConfig endpointConfig = const EndpointConfig(),
    bool emailReadReceiptsEnabled = false,
    Map<String, bool> emailEncryptionBetaEnabledByAddress =
        const <String, bool>{},
    String? Function()? xmppSelfJidProvider,
  }) : _credentialStore = credentialStore,
       _databaseBuilder = databaseBuilder,
       _endpointConfig = endpointConfig,
       _emailReadReceiptsEnabled = emailReadReceiptsEnabled,
       _emailEncryptionBetaEnabledByAddress = _normalizedEncryptionBetaMap(
         emailEncryptionBetaEnabledByAddress,
       ),
       _xmppSelfJidProvider = xmppSelfJidProvider,
       _connectionConfigBuilder =
           connectionConfigBuilder ??
           const EmailConnectionConfigBuilder(_defaultConnectionConfig),
       _log = logger ?? Logger('EmailService'),
       _notificationService = notificationService,
       _foregroundBridge = foregroundBridge ?? foregroundTaskBridge {
    _transportFactory =
        transportFactory ??
        () => EmailDeltaWorkerRuntime(
          logger: _log,
          xmppSelfJidProvider: _xmppSelfJidProvider,
        );
    _transport = transport ?? _transportFactory();
    _configureTransport(_transport);
    blocking = EmailBlockingService(
      databaseBuilder: databaseBuilder,
      onBlock: DeltaChatBlockCallback(
        (address) => _transport.blockContact(address),
      ),
      onUnblock: DeltaChatBlockCallback(
        (address) => _transport.unblockContact(address),
      ),
    );
    spam = EmailSpamService(
      databaseBuilder: databaseBuilder,
      onMarkSpam: DeltaChatSpamCallback(
        (address) => _transport.blockContact(address),
      ),
      onUnmarkSpam: DeltaChatSpamCallback(
        (address) => _transport.unblockContact(address),
      ),
    );
    _attachTransportListener();
  }

  final CredentialStore _credentialStore;
  final Future<XmppDatabase> Function() _databaseBuilder;
  late final EmailDeltaRuntime Function() _transportFactory;
  late EmailDeltaRuntime _transport;
  final EmailConnectionConfigBuilder _connectionConfigBuilder;
  final Logger _log;
  EndpointConfig _endpointConfig;
  bool _emailReadReceiptsEnabled;
  Map<String, bool> _emailEncryptionBetaEnabledByAddress;
  final String? Function()? _xmppSelfJidProvider;
  final NotificationService? _notificationService;
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
  EmailDeltaRuntime? _listenerTransport;
  void Function(DeltaCoreEvent)? _listenerCallback;
  final Map<int, DeltaEventConsumer> _deltaEventConsumers = {};

  Future<void> _deltaOperationQueue = Future<void>.value();
  int _deltaOperationQueueEpoch = 0;

  _EmailRuntimePhase _runtimePhase = _EmailRuntimePhase.stopped;
  Future<void>? _stopFuture;
  EmailDeltaRuntime? _stopFutureTransport;
  Future<void>? _pendingNativeCleanup;
  final _authFailureController = StreamController<DeltaChatException>.broadcast(
    sync: true,
  );
  bool _foregroundKeepaliveEnabled = false;
  bool _foregroundKeepaliveLeaseAcquired = false;
  int _foregroundKeepaliveOperationId = 0;
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
  int _consecutiveConnectingSamples = 0;
  DateTime? _lastConnectivityDetailLoggedAt;
  final EmailAsyncQueue _channelOverflowRecoveryQueue = EmailAsyncQueue();
  EmailImapCapabilities _imapCapabilities = const EmailImapCapabilities(
    idleSupported: false,
    connectionLimit: _imapConnectionLimitSingle,
    idleCutoff: _imapIdleKeepaliveInterval,
  );
  DateTime? _imapCapabilitiesCheckedAt;
  bool _imapCapabilitiesResolved = false;

  bool _deltaAccountRepairCompleted = false;

  Future<bool>? _backgroundFetchInFlight;

  Timer? _imapSyncTimer;
  Object? _imapSyncLoopToken;
  final EmailAsyncQueue _imapSyncQueue = EmailAsyncQueue();
  final EmailAsyncQueue _networkSignalQueue = EmailAsyncQueue();
  final EmailAsyncQueue _networkTransitionQueue = EmailAsyncQueue();
  final EmailAsyncQueue _reconnectCatchUpQueue = EmailAsyncQueue();
  final EmailAsyncQueue _reconnectRestartQueue = EmailAsyncQueue();
  final EmailAsyncQueue _contactsSyncQueue = EmailAsyncQueue();
  final EmailAsyncQueue _chatlistSyncQueue = EmailAsyncQueue();
  Future<void>? _chatlistRefreshTask;
  final EmailAsyncQueue _readStateQueue = EmailAsyncQueue();
  final EmailAsyncQueue _mdnConfigQueue = EmailAsyncQueue();
  _EmailNetworkTransition? _pendingNetworkTransition;
  _EmailNetworkTransition? _activeNetworkTransition;
  final Set<Future<void>> _activeAppDatabaseOperations = <Future<void>>{};

  void updateEndpointConfig(EndpointConfig config) {
    _endpointConfig = config;
  }

  Future<void> updateEmailReadReceiptsEnabled(bool enabled) async {
    if (_emailReadReceiptsEnabled == enabled) {
      return;
    }
    _emailReadReceiptsEnabled = enabled;
    if (_nativeCleanupPending || !_acceptsRuntimeWork) {
      return;
    }
    await _mdnConfigQueue.run(
      () => _applyEmailReadReceiptPreference(enabled: enabled),
    );
  }

  void updateEmailEncryptionBetaSettings(Map<String, bool> enabledByAddress) {
    _emailEncryptionBetaEnabledByAddress = _normalizedEncryptionBetaMap(
      enabledByAddress,
    );
    _transport.updateEmailEncryptionBetaSettings(
      _emailEncryptionBetaEnabledByAddress,
    );
  }

  void _configureTransport(EmailDeltaRuntime transport) {
    _deltaEventConsumers.clear();
    transport.updateDatabaseOperationTracker(_trackAppDatabaseOperation);
    transport.updateEmailEncryptionBetaSettings(
      _emailEncryptionBetaEnabledByAddress,
    );
  }

  Future<EmailEncryptionAccountInfo?> activeEncryptionAccountInfo() async {
    final scope = _activeCredentialScope;
    if (_activeAccount == null || scope == null) {
      return null;
    }
    final binding = await _accountBindingForScope(scope: scope);
    final keyId = await _transport.getCoreConfig(
      _openPgpKeyIdConfigKey,
      accountId: binding.deltaAccountId,
    );
    return EmailEncryptionAccountInfo(
      normalizedAddress: binding.address,
      deltaAccountId: binding.deltaAccountId,
      hasSelfKey: keyId != null && keyId.trim().isNotEmpty,
    );
  }

  Future<EmailOpenPgpKeyMetadata> inspectEmailEncryptionPrivateKey(
    File source,
  ) async {
    await _ensureReady();
    final account = await _requireActiveEncryptionAccount();
    final operationDirectory = await _createEmailEncryptionOperationDirectory();
    try {
      final importFile = await _prepareEmailEncryptionImportFile(
        source: source,
        operationDirectory: operationDirectory,
      );
      final metadata = await _inspectOpenPgpKeyFile(
        file: importFile,
        expectedAddress: account.address,
        expectedKind: DeltaOpenPgpKeyKind.private,
      );
      if (!metadata.hasEncryptionCapability) {
        throw const EmailEncryptionUnsupportedKeyFormatException();
      }
      return metadata;
    } on EmailEncryptionKeyException {
      rethrow;
    } on DeltaSafeException {
      throw const EmailEncryptionUnsupportedKeyFormatException();
    } on FileSystemException {
      throw const EmailEncryptionUnsupportedKeyFormatException();
    } on FormatException {
      throw const EmailEncryptionUnsupportedKeyFormatException();
    } finally {
      await _cleanupEmailEncryptionOperationDirectory(operationDirectory);
    }
  }

  Future<EmailEncryptionAccountInfo> importEmailEncryptionPrivateKey(
    File source, {
    required String expectedFingerprint,
    required bool allowIdentityMismatch,
  }) async {
    await _ensureReady();
    final account = await _requireActiveEncryptionAccount();
    final operationDirectory = await _createEmailEncryptionOperationDirectory();
    try {
      final importFile = await _prepareEmailEncryptionImportFile(
        source: source,
        operationDirectory: operationDirectory,
      );
      final metadata = await _inspectOpenPgpKeyFile(
        file: importFile,
        expectedAddress: account.address,
        expectedKind: DeltaOpenPgpKeyKind.private,
      );
      if (!metadata.hasEncryptionCapability ||
          metadata.fingerprint != expectedFingerprint ||
          (!metadata.hasExpectedAddress && !allowIdentityMismatch)) {
        throw const EmailEncryptionImportFailedException();
      }
      await _transport.runImex(
        mode: DeltaImexMode.importSelfKeys,
        path: importFile.path,
        accountId: account.deltaAccountId,
      );
      await _verifyEmailEncryptionKey(
        account,
        failure: const EmailEncryptionImportFailedException(),
      );
      return EmailEncryptionAccountInfo(
        normalizedAddress: account.address,
        deltaAccountId: account.deltaAccountId,
        hasSelfKey: true,
      );
    } on EmailEncryptionKeyException {
      rethrow;
    } on DeltaSafeException {
      throw const EmailEncryptionImportFailedException();
    } on EmailDeltaImexException {
      throw const EmailEncryptionImportFailedException();
    } on FileSystemException {
      throw const EmailEncryptionImportFailedException();
    } on FormatException {
      throw const EmailEncryptionImportFailedException();
    } finally {
      await _cleanupEmailEncryptionOperationDirectory(operationDirectory);
    }
  }

  Future<EmailTrustedContactKey?> trustedContactKeyForAddress(
    String address,
  ) async {
    await _ensureReady();
    final account = await _requireActiveEncryptionAccount();
    final normalized = normalizedAddressValue(address);
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final db = await _databaseBuilder();
    final data = await db.getEmailTrustedContactKey(
      deltaAccountId: account.deltaAccountId,
      address: normalized,
    );
    return data == null ? null : EmailTrustedContactKey.fromData(data);
  }

  Future<EmailOpenPgpKeyMetadata> inspectContactPublicKey({
    required String address,
    required File source,
  }) async {
    await _ensureReady();
    await _requireActiveEncryptionAccountForContactKey();
    final normalized = normalizedAddressValue(address);
    if (normalized == null || normalized.isEmpty) {
      throw const EmailContactKeyUnsupportedFormatException();
    }
    try {
      final armored = await _readSingleArmoredPublicKey(source);
      final metadata = await _inspectOpenPgpArmoredKey(
        armored: armored,
        expectedAddress: normalized,
        expectedKind: DeltaOpenPgpKeyKind.public,
      );
      if (!metadata.hasEncryptionCapability) {
        throw const EmailContactKeyUnsupportedFormatException();
      }
      return metadata;
    } on EmailContactKeyException {
      rethrow;
    } on DeltaSafeException {
      throw const EmailContactKeyUnsupportedFormatException();
    } on FileSystemException {
      throw const EmailContactKeyUnsupportedFormatException();
    } on FormatException {
      throw const EmailContactKeyUnsupportedFormatException();
    }
  }

  Future<EmailTrustedContactKey> importTrustedContactPublicKey({
    required String address,
    required String displayName,
    required File source,
    required EmailOpenPgpIdentityBinding identityBinding,
    required String expectedFingerprint,
  }) async {
    await _ensureReady();
    final account = await _requireActiveEncryptionAccountForContactKey();
    final normalized = normalizedAddressValue(address);
    if (normalized == null || normalized.isEmpty) {
      throw const EmailContactKeyUnsupportedFormatException();
    }
    try {
      final armored = await _readSingleArmoredPublicKey(source);
      final metadata = await _inspectOpenPgpArmoredKey(
        armored: armored,
        expectedAddress: normalized,
        expectedKind: DeltaOpenPgpKeyKind.public,
      );
      if (!metadata.hasEncryptionCapability ||
          metadata.fingerprint != expectedFingerprint ||
          (!metadata.hasExpectedAddress &&
              identityBinding != EmailOpenPgpIdentityBinding.userConfirmed)) {
        throw const EmailContactKeyImportFailedException();
      }
      final imported = await _transport.importContactPublicKey(
        address: normalized,
        displayName: displayName,
        armoredPublicKey: armored,
        accountId: account.deltaAccountId,
      );
      if (imported.contactId <= DeltaContactId.lastSpecial ||
          imported.chatId <= DeltaChatId.lastSpecial ||
          imported.metadata.fingerprint.trim().isEmpty ||
          imported.metadata.fingerprint != expectedFingerprint ||
          !imported.metadata.hasEncryptionCapability) {
        throw const EmailContactKeyImportFailedException();
      }
      final key = EmailTrustedContactKey(
        deltaAccountId: account.deltaAccountId,
        normalizedAddress: normalized,
        fingerprint: imported.metadata.fingerprint,
        deltaContactId: imported.contactId,
        deltaChatId: imported.chatId,
        identityBinding: identityBinding,
        userIds: imported.metadata.userIds,
        importedAt: DateTime.timestamp(),
      );
      final db = await _databaseBuilder();
      await db.upsertEmailTrustedContactKey(key.toData());
      return key;
    } on EmailContactKeyException {
      rethrow;
    } on DeltaSafeException {
      throw const EmailContactKeyImportFailedException();
    } on FileSystemException {
      throw const EmailContactKeyImportFailedException();
    } on FormatException {
      throw const EmailContactKeyImportFailedException();
    }
  }

  Future<void> removeTrustedContactPublicKey(String address) async {
    await _ensureReady();
    final account = await _requireActiveEncryptionAccountForContactKey();
    final normalized = normalizedAddressValue(address);
    if (normalized == null || normalized.isEmpty) {
      throw const EmailContactKeyRemoveFailedException();
    }
    final db = await _databaseBuilder();
    final key = await db.getEmailTrustedContactKey(
      deltaAccountId: account.deltaAccountId,
      address: normalized,
    );
    if (key == null) {
      return;
    }
    if (key.deltaContactId <= DeltaContactId.lastSpecial ||
        key.deltaChatId <= DeltaChatId.lastSpecial) {
      _log.warning(
        'Clearing invalid trusted OpenPGP key mapping with special Delta ids '
        'contact ${key.deltaContactId} chat ${key.deltaChatId} fingerprint '
        '${key.fingerprint} for $normalized on account '
        '${account.deltaAccountId}.',
      );
      await _deleteTrustedContactPublicKeyMapping(
        db: db,
        deltaAccountId: account.deltaAccountId,
        address: normalized,
        deltaChatId: key.deltaChatId,
      );
      return;
    }
    try {
      await _transport.removeContactPublicKey(
        address: normalized,
        fingerprint: key.fingerprint,
        contactId: key.deltaContactId,
        chatId: key.deltaChatId,
        accountId: account.deltaAccountId,
      );
    } on EmailContactKeyException {
      rethrow;
    } on DeltaSafeException catch (error, stackTrace) {
      _log.warning(
        'Delta failed to remove trusted OpenPGP key contact '
        '${key.deltaContactId} chat ${key.deltaChatId} fingerprint '
        '${key.fingerprint} for $normalized on account '
        '${account.deltaAccountId}; keeping local pinned key mapping.',
        error,
        stackTrace,
      );
      throw const EmailContactKeyRemoveFailedException();
    }
    await _deleteTrustedContactPublicKeyMapping(
      db: db,
      deltaAccountId: account.deltaAccountId,
      address: normalized,
      deltaChatId: key.deltaChatId,
    );
  }

  Future<void> _deleteTrustedContactPublicKeyMapping({
    required XmppDatabase db,
    required int deltaAccountId,
    required String address,
    required int deltaChatId,
  }) async {
    await db.deleteEmailTrustedContactKey(
      deltaAccountId: deltaAccountId,
      address: address,
    );
    await db.deleteEmailChatAccountsForDeltaChat(
      deltaAccountId: deltaAccountId,
      deltaChatId: deltaChatId,
    );
  }

  Future<EmailEncryptionKeyExport> createEmailEncryptionKeyExport() async {
    await _ensureReady();
    final account = await _requireActiveEncryptionAccount();
    final operationDirectory = await _createEmailEncryptionOperationDirectory();
    try {
      await _transport.runImex(
        mode: DeltaImexMode.exportSelfKeys,
        path: operationDirectory.path,
        accountId: account.deltaAccountId,
      );
      await _verifyEmailEncryptionKey(
        account,
        failure: const EmailEncryptionExportFailedException(),
      );
      final archive = await _zipEmailEncryptionExport(
        operationDirectory: operationDirectory,
        account: account,
      );
      final archiveBytes = await archive.readAsBytes();
      _validateEmailEncryptionExportArchiveBytes(
        archiveBytes,
        normalizedAddress: account.address,
        failure: const EmailEncryptionExportFailedException(),
      );
      return EmailEncryptionKeyExport(
        normalizedAddress: account.address,
        archiveBytes: archiveBytes,
      );
    } on EmailEncryptionKeyException {
      rethrow;
    } on EmailDeltaImexException {
      throw const EmailEncryptionExportFailedException();
    } on DeltaSafeException {
      throw const EmailEncryptionExportFailedException();
    } on FileSystemException {
      throw const EmailEncryptionExportFailedException();
    } on FormatException {
      throw const EmailEncryptionExportFailedException();
    } finally {
      await _cleanupEmailEncryptionOperationDirectory(operationDirectory);
    }
  }

  Future<void> saveEmailEncryptionKeyExport({
    required Uint8List archiveBytes,
    required String destinationPath,
    required String normalizedAddress,
  }) async {
    try {
      final normalized = normalizedAddressValue(normalizedAddress);
      if (normalized == null || normalized.isEmpty) {
        throw const EmailEncryptionSaveFailedException();
      }
      _validateEmailEncryptionExportArchiveBytes(
        archiveBytes,
        normalizedAddress: normalized,
        failure: const EmailEncryptionSaveFailedException(),
      );
      final destination = File(destinationPath);
      await destination.writeAsBytes(archiveBytes, flush: true);
      if (!await destination.exists()) {
        throw const EmailEncryptionSaveFailedException();
      }
      _validateEmailEncryptionExportArchiveBytes(
        await destination.readAsBytes(),
        normalizedAddress: normalized,
        failure: const EmailEncryptionSaveFailedException(),
      );
    } on EmailEncryptionKeyException {
      rethrow;
    } on FileSystemException {
      throw const EmailEncryptionSaveFailedException();
    }
  }

  Future<void> completeEmailEncryptionKeyExportAfterPlatformSave({
    required Uint8List archiveBytes,
    required String platformResultPath,
    required String normalizedAddress,
  }) async {
    try {
      if (platformResultPath.trim().isEmpty) {
        throw const EmailEncryptionSaveFailedException();
      }
      final normalized = normalizedAddressValue(normalizedAddress);
      if (normalized == null || normalized.isEmpty) {
        throw const EmailEncryptionSaveFailedException();
      }
      _validateEmailEncryptionExportArchiveBytes(
        archiveBytes,
        normalizedAddress: normalized,
        failure: const EmailEncryptionSaveFailedException(),
      );
    } on EmailEncryptionKeyException {
      rethrow;
    } on FormatException {
      throw const EmailEncryptionSaveFailedException();
    }
  }

  Future<void> cancelEmailEncryptionKeyExport() {
    return _transport.cancelImex();
  }

  Future<void> cleanupEmailEncryptionTempPath(String path) async {
    final normalizedPath = p.normalize(path.trim());
    if (normalizedPath.isEmpty || !p.isAbsolute(normalizedPath)) {
      return;
    }
    final root = await appOwnedTemporaryDirectory(
      emailEncryptionKeyTempDirectoryName,
    );
    if (!appOwnedPathIsChildOf(
      rootPath: root.path,
      candidatePath: normalizedPath,
    )) {
      return;
    }
    final entityType = await FileSystemEntity.type(
      normalizedPath,
      followLinks: false,
    );
    switch (entityType) {
      case FileSystemEntityType.notFound:
        return;
      case FileSystemEntityType.directory:
        await deleteAppOwnedDirectoryTree(
          directory: Directory(normalizedPath),
          expectedPath: normalizedPath,
        );
      case FileSystemEntityType.file:
      case FileSystemEntityType.link:
        await deleteAppOwnedFile(
          file: File(normalizedPath),
          expectedPath: normalizedPath,
        );
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
        return;
    }
  }

  EmailOutgoingEncryptionMode outgoingEncryptionModeForAddress(String address) {
    final normalized = normalizedAddressValue(address);
    if (normalized == null || normalized.isEmpty) {
      return EmailOutgoingEncryptionMode.plaintextNoAutocrypt;
    }
    return _emailEncryptionBetaEnabledByAddress[normalized] == true
        ? EmailOutgoingEncryptionMode.autocryptBeta
        : EmailOutgoingEncryptionMode.plaintextNoAutocrypt;
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
    overrides[_syncMsgsConfigKey] = '0';
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

  bool get _listenerAttached => _listenerTransport != null;

  bool get _nativeCleanupPending => _pendingNativeCleanup != null;

  bool get _canProcessDeltaWork => _listenerAttached && !_blocksRuntimeReentry;

  bool get _canProcessNetworkTransition =>
      !_nativeCleanupPending &&
      !_blocksRuntimeReentry &&
      hasInMemoryReconnectContext;

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
    if (_nativeCleanupPending || _blocksRuntimeReentry) {
      return false;
    }
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
    return _accountForScope(_scopeForJid(jid));
  }

  Future<EmailAccount?> _accountForScope(String scope) async {
    final activeAccount = _accountForActiveScope(scope);
    if (activeAccount != null) {
      return activeAccount;
    }
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

  EmailAccount? _accountForActiveScope(String scope) {
    if (_activeCredentialScope != scope) {
      return null;
    }
    final activeAccount = _activeAccount;
    if (activeAccount != null && activeAccount.password.isNotEmpty) {
      return activeAccount;
    }
    final sessionAccount = sessionCredentials;
    if (sessionAccount == null || sessionAccount.password.isEmpty) {
      return null;
    }
    if (_scopeForJid(sessionAccount.address) != scope) {
      return null;
    }
    return sessionAccount;
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
    final pendingCleanup = _pendingNativeCleanup;
    if (pendingCleanup != null) {
      await pendingCleanup;
    }
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
      _attachTransportListener();
    }

    if (!_listenerAttached) {
      _attachTransportListener();
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
    final storedProvisioned =
        (await _credentialStore.read(key: provisionedKey)) ==
        _credentialTrueValue;
    final ephemerallyProvisioned =
        !shouldPersistCredentials &&
        _credentialSession.isEphemerallyProvisioned(scope);
    var alreadyProvisioned = storedProvisioned;
    if (ephemerallyProvisioned) {
      alreadyProvisioned = true;
    }
    var transportConfigured = false;
    final hasFreshPasswordOverride =
        passwordOverride != null && passwordOverride.isNotEmpty;
    final shouldForceProvisioning =
        credentialsMutated &&
        !ephemerallyProvisioned &&
        (shouldPersistCredentials ||
            hasFreshPasswordOverride ||
            !storedProvisioned);
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
        await _applyOpenPgpBaseConfigForAccount(
          _EmailAccountBinding(
            address: address,
            deltaAccountId: deltaAccountId,
          ),
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
        await _applyOpenPgpBaseConfigForAccount(
          _EmailAccountBinding(
            address: address,
            deltaAccountId: deltaAccountId,
          ),
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
    final pendingCleanup = _pendingNativeCleanup;
    if (pendingCleanup != null) {
      await pendingCleanup;
    }
    if (_acceptsRuntimeWork) {
      return;
    }
    if (_blocksRuntimeReentry) {
      throw const EmailServiceStoppingException();
    }
    if (!_listenerAttached) {
      _attachTransportListener();
    }
    await _applyOpenPgpBaseConfigForActiveAccounts();
    await _transport.start();
    await _mdnConfigQueue.run(() => _applyEmailReadReceiptPreference());
    await _applyDeltaSelfSyncSuppression();
    _runtimePhase = _EmailRuntimePhase.running;
    _startImapSyncLoop();
  }

  Future<void> stop() async {
    final pendingCleanup = _pendingNativeCleanup;
    if (pendingCleanup != null) {
      await pendingCleanup;
    }
    final transport = _transport;
    final existing = _stopFuture;
    if (existing != null && identical(_stopFutureTransport, transport)) {
      await existing;
      return;
    }
    if (!_acceptsRuntimeWork && !_listenerAttached) {
      return;
    }
    final future = _runStop(transport);
    _stopFuture = future;
    _stopFutureTransport = transport;
    try {
      await future;
    } finally {
      if (identical(_stopFuture, future)) {
        _stopFuture = null;
        _stopFutureTransport = null;
      }
    }
  }

  Future<void> _runStop(EmailDeltaRuntime transport) async {
    if (_runtimePhase != _EmailRuntimePhase.disposing) {
      _runtimePhase = _EmailRuntimePhase.stopping;
    }
    _detachTransportListener(transport: transport);
    await _stopForegroundKeepalive();
    _stopImapSyncLoop();
    _cancelContactsSyncTimer();
    _cancelConnectivityDowngrade();
    _clearNotificationQueue();
    _contactsSyncQueue.reset();
    _chatlistSyncQueue.reset();
    _chatlistRefreshTask = null;
    _readStateQueue.reset();
    _imapSyncQueue.reset();
    _networkSignalQueue.reset();
    _networkTransitionQueue.reset();
    _pendingNetworkTransition = null;
    _activeNetworkTransition = null;
    _reconnectCatchUpQueue.reset();
    _reconnectRestartQueue.reset();
    _channelOverflowRecoveryQueue.reset();
    _credentialSession.invalidateBootstrapOperations();
    await _drainDeltaOperationQueueForShutdown();
    _resetDeltaOperationQueue();
    final stopTransport = _transport;
    if (!identical(stopTransport, transport)) {
      _detachTransportListener(transport: stopTransport);
    }
    try {
      await stopTransport.stop();
    } finally {
      if (_runtimePhase == _EmailRuntimePhase.disposing) {
        await _releaseForegroundKeepaliveResources();
      }
    }
    if (_runtimePhase == _EmailRuntimePhase.stopping) {
      _runtimePhase = _EmailRuntimePhase.stopped;
    }
  }

  Future<void> _drainDeltaOperationQueueForShutdown() async {
    await _deltaOperationQueue;
  }

  Future<void> ensureEventChannelActive() async {
    if (_blocksRuntimeReentry) {
      return;
    }
    if (!_listenerAttached) {
      _attachTransportListener();
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

  Future<void> shutdown({
    String? jid,
    bool clearCredentials = false,
    EmailShutdownMode mode = EmailShutdownMode.graceful,
  }) async {
    if (mode == EmailShutdownMode.logout) {
      await _shutdownForLogout(jid: jid, clearCredentials: clearCredentials);
      return;
    }
    final pendingCleanup = _pendingNativeCleanup;
    if (pendingCleanup != null) {
      await pendingCleanup;
    }
    _runtimePhase = _EmailRuntimePhase.disposing;
    try {
      await stop();
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Email transport stop failed during shutdown',
        error,
        stackTrace,
      );
    }
    _resetImapCapabilities();
    if (clearCredentials) {
      await _deconfigureTransportForCredentialClear(
        _transport,
        requireActiveRuntime: true,
      );
      final scope = _scopeForOptionalJid(jid);
      if (scope != null) {
        await _clearCredentials(scope);
      }
    }
    try {
      await _transport.dispose();
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to dispose email transport', error, stackTrace);
    } finally {
      _credentialSession.clearRuntime();
      _pendingPushToken = null;
      _runtimePhase = _EmailRuntimePhase.stopped;
    }
  }

  Future<void> _shutdownForLogout({
    required String? jid,
    required bool clearCredentials,
  }) async {
    _runtimePhase = _EmailRuntimePhase.disposing;
    final transport = _transport;
    final matchingStopFuture = identical(_stopFutureTransport, transport)
        ? _stopFuture
        : null;
    final pendingRuntimeWork = _pendingRuntimeWorkForNativeCleanup();
    final pendingDatabaseRuntimeWork = _pendingDatabaseRuntimeWorkForLogout();

    _detachTransportListener(transport: transport);
    final activeOperationBarrier = _stopTransportEventDeliveryForLogout(
      transport,
    );
    await _stopForegroundKeepalive();
    _stopImapSyncLoop();
    _cancelContactsSyncTimer();
    _cancelConnectivityDowngrade();
    _clearNotificationQueue();
    _resetRuntimeQueues();
    _credentialSession.invalidateBootstrapOperations();
    _resetDeltaOperationQueue();
    _resetImapCapabilities();
    _pendingPushToken = null;

    await _drainLogoutRuntimeWork(
      activeStop: activeOperationBarrier,
      pendingRuntimeWork: pendingDatabaseRuntimeWork,
    );

    Object? credentialError;
    StackTrace? credentialStackTrace;
    if (clearCredentials) {
      final scope = _scopeForOptionalJid(jid);
      if (scope != null) {
        try {
          await _clearCredentials(scope);
        } on Exception catch (error, stackTrace) {
          credentialError = error;
          credentialStackTrace = stackTrace;
        }
      }
    }
    _credentialSession.clearRuntime(clearEphemeralState: true);
    _startNativeLogoutCleanup(
      transport: transport,
      pendingRuntimeWork: pendingRuntimeWork,
      activeStop: activeOperationBarrier,
      matchingStopFuture: matchingStopFuture,
      clearTransportCredentials: clearCredentials,
    );
    if (credentialError != null) {
      Error.throwWithStackTrace(credentialError, credentialStackTrace!);
    }
  }

  Future<void> _stopTransportEventDeliveryForLogout(
    EmailDeltaRuntime transport,
  ) async {
    try {
      await transport.stopEventDeliveryForLogout();
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Email transport event delivery stop failed during logout cleanup',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _pendingRuntimeWorkForNativeCleanup() async {
    await Future.wait<void>([
      _deltaOperationQueue,
      _channelOverflowRecoveryQueue.pending,
      _imapSyncQueue.pending,
      _networkSignalQueue.pending,
      _networkTransitionQueue.pending,
      _reconnectCatchUpQueue.pending,
      _reconnectRestartQueue.pending,
      _contactsSyncQueue.pending,
      _chatlistSyncQueue.pending,
      _readStateQueue.pending,
      _mdnConfigQueue.pending,
    ]);
  }

  Future<void> _pendingDatabaseRuntimeWorkForLogout() async {
    await _pendingAppDatabaseOperations();
  }

  Future<T> _trackAppDatabaseOperation<T>(Future<T> Function() operation) {
    final future = Future<T>.sync(operation);
    late final Future<void> tracked;
    tracked = future.then<void>((_) {}, onError: (_, _) {});
    _activeAppDatabaseOperations.add(tracked);
    tracked.whenComplete(() {
      _activeAppDatabaseOperations.remove(tracked);
    });
    return future;
  }

  Future<void> _pendingAppDatabaseOperations() async {
    while (_activeAppDatabaseOperations.isNotEmpty) {
      await Future.wait(_activeAppDatabaseOperations.toList(growable: false));
    }
  }

  void _resetRuntimeQueues() {
    _channelOverflowRecoveryQueue.reset();
    _imapSyncQueue.reset();
    _networkSignalQueue.reset();
    _networkTransitionQueue.reset();
    _pendingNetworkTransition = null;
    _activeNetworkTransition = null;
    _reconnectCatchUpQueue.reset();
    _reconnectRestartQueue.reset();
    _contactsSyncQueue.reset();
    _chatlistSyncQueue.reset();
    _chatlistRefreshTask = null;
    _readStateQueue.reset();
    _mdnConfigQueue.reset();
  }

  void _startNativeLogoutCleanup({
    required EmailDeltaRuntime transport,
    required Future<void> pendingRuntimeWork,
    required Future<void>? activeStop,
    required Future<void>? matchingStopFuture,
    required bool clearTransportCredentials,
  }) {
    if (_pendingNativeCleanup != null) {
      return;
    }
    late final Future<void> cleanup;
    cleanup =
        _runNativeLogoutCleanup(
          transport: transport,
          pendingRuntimeWork: pendingRuntimeWork,
          activeStop: activeStop,
          matchingStopFuture: matchingStopFuture,
          clearTransportCredentials: clearTransportCredentials,
        ).whenComplete(() {
          if (!identical(_pendingNativeCleanup, cleanup)) {
            return;
          }
          _pendingNativeCleanup = null;
          if (identical(_transport, transport)) {
            _replaceTransportAfterNativeCleanup(transport);
          }
          if (_runtimePhase == _EmailRuntimePhase.disposing) {
            _runtimePhase = _EmailRuntimePhase.stopped;
          }
        });
    _pendingNativeCleanup = cleanup;
  }

  Future<void> _drainLogoutRuntimeWork({
    required Future<void>? activeStop,
    required Future<void> pendingRuntimeWork,
  }) async {
    try {
      await activeStop;
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Email stop failed during logout cleanup',
        error,
        stackTrace,
      );
    }
    try {
      await pendingRuntimeWork;
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Pending email runtime work failed during logout cleanup',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _runNativeLogoutCleanup({
    required EmailDeltaRuntime transport,
    required Future<void> pendingRuntimeWork,
    required Future<void>? activeStop,
    required Future<void>? matchingStopFuture,
    required bool clearTransportCredentials,
  }) async {
    try {
      await _stopTransportForNativeLogoutCleanup(
        transport: transport,
        activeStop: activeStop,
        matchingStopFuture: matchingStopFuture,
      );
      await _drainLogoutRuntimeWork(
        activeStop: null,
        pendingRuntimeWork: pendingRuntimeWork,
      );
      if (clearTransportCredentials) {
        await _deconfigureTransportForCredentialClear(
          transport,
          requireActiveRuntime: false,
        );
      }
      try {
        if (transport is EmailDeltaWorkerRuntime) {
          await transport.dispose(requestWorkerDispose: false);
        } else {
          await transport.dispose();
        }
      } on Exception catch (error, stackTrace) {
        _log.warning('Failed to dispose email transport', error, stackTrace);
      }
    } finally {
      await _releaseForegroundKeepaliveResources();
    }
  }

  Future<void> _deconfigureTransportForCredentialClear(
    EmailDeltaRuntime transport, {
    required bool requireActiveRuntime,
  }) async {
    if (requireActiveRuntime &&
        (_databasePrefix == null || _databasePassphrase == null)) {
      _log.fine('Skipping email account deconfigure; runtime is not active.');
      return;
    }
    try {
      await transport.deconfigureAccount();
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      if (error.message == 'Delta worker is not initialized.') {
        _log.fine(
          'Skipping email account deconfigure; worker is not initialized.',
          error,
          stackTrace,
        );
        return;
      }
      _log.warning('Failed to deconfigure email account', error, stackTrace);
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to deconfigure email account', error, stackTrace);
    }
  }

  Future<void> _stopTransportForNativeLogoutCleanup({
    required EmailDeltaRuntime transport,
    required Future<void>? activeStop,
    required Future<void>? matchingStopFuture,
  }) async {
    var stopped = false;
    try {
      await activeStop;
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Email transport event stop failed before native logout cleanup',
        error,
        stackTrace,
      );
    }
    if (matchingStopFuture != null) {
      try {
        await matchingStopFuture;
        stopped = true;
      } on Exception catch (error, stackTrace) {
        _log.warning(
          'In-flight email transport stop failed during logout cleanup',
          error,
          stackTrace,
        );
      }
    }
    if (stopped) {
      return;
    }
    try {
      await transport.stop();
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Email transport native stop failed during logout cleanup',
        error,
        stackTrace,
      );
    }
  }

  void _replaceTransportAfterNativeCleanup(EmailDeltaRuntime oldTransport) {
    if (!identical(_transport, oldTransport)) {
      return;
    }
    final nextTransport = _transportFactory();
    _configureTransport(nextTransport);
    _transport = nextTransport;
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

  Future<void> createContactAddress({
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
    await _guardDeltaOperation(
      operation: 'add email contact',
      body: () => _transport.createContact(
        address: address,
        displayName: displayName,
        accountId: account.deltaAccountId,
      ),
    );
  }

  Future<void> addContactAddress({
    required String address,
    String? displayName,
    String? fromAddress,
  }) async {
    await createContactAddress(
      address: address,
      displayName: displayName,
      fromAddress: fromAddress,
    );
    await syncContactsFromCore();
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
    final accountSender = _transport.selfJidForAccount(accountId);
    if (accountSender != null &&
        accountSender.isNotEmpty &&
        !accountSender.isDeltaPlaceholderJid) {
      return accountSender;
    }
    return deltaAnonUserJid;
  }

  FileMetadataData _metadataForAttachment(
    EmailAttachment attachment,
    int msgId,
  ) {
    return FileMetadataData(
      id: deltaFileMetadataId(msgId),
      filename: sanitizeEmailAttachmentFilename(
        attachment.fileName,
        fallbackPath: attachment.path,
      ),
      path: attachment.path,
      mimeType: sanitizeEmailMimeType(attachment.mimeType),
      sizeBytes: attachment.sizeBytes,
      width: attachment.width,
      height: attachment.height,
    );
  }

  Future<int> _sendAndRecordEmail({
    required int chatId,
    required Chat chat,
    required int accountId,
    required String operation,
    required Future<int> Function() send,
    String? body,
    String? subject,
    String? quotingStanzaId,
    String? shareId,
    String? localBodyOverride,
    String? htmlBody,
    FileMetadataData Function(int msgId, DeltaMessage? deltaMessage)?
    metadataForMsg,
  }) async {
    final record = !_transport.persistsAppStateInternally;
    final int msgId;
    try {
      msgId = await _guardDeltaOperation(operation: operation, body: send);
    } on Exception {
      if (record) {
        await _recordOutgoingEmail(
          chatId: chatId,
          accountId: accountId,
          chat: chat,
          stanzaId: _outgoingEmailRowKey(),
          body: body,
          subject: subject,
          quotingStanzaId: quotingStanzaId,
          shareId: shareId,
          localBodyOverride: localBodyOverride,
          htmlBody: htmlBody,
          error: MessageError.emailSendFailure,
        );
      }
      rethrow;
    }
    if (record) {
      final deltaMessage = await _transport.getMessage(
        msgId,
        accountId: accountId,
      );
      await _recordOutgoingEmail(
        chatId: chatId,
        accountId: accountId,
        chat: chat,
        msgId: msgId,
        stanzaId: _outgoingEmailRowKey(),
        originId: await _resolveSentEmailOriginId(msgId, accountId: accountId),
        body: body,
        subject: subject,
        quotingStanzaId: quotingStanzaId,
        metadata: metadataForMsg?.call(msgId, deltaMessage),
        shareId: shareId,
        localBodyOverride: localBodyOverride,
        htmlBody: htmlBody,
        timestamp: deltaMessage?.timestamp,
        encryptionProtocol: _encryptionProtocolForDelta(deltaMessage),
      );
    }
    return msgId;
  }

  String _outgoingEmailRowKey() => const Uuid().v4();

  Future<String?> _resolveSentEmailOriginId(
    int msgId, {
    required int accountId,
  }) async {
    try {
      final mid = normalizeEmailMessageId(
        await _transport.getMessageRfc724Mid(msgId, accountId: accountId),
      );
      if (mid == null || isDeltaGeneratedMessageId(mid)) {
        return null;
      }
      return mid;
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to resolve sent email origin.', error, stackTrace);
      return null;
    }
  }

  Future<void> _recordOutgoingEmail({
    required int chatId,
    required int accountId,
    required Chat chat,
    required String stanzaId,
    int? msgId,
    String? originId,
    String? body,
    String? subject,
    String? quotingStanzaId,
    FileMetadataData? metadata,
    String? shareId,
    String? localBodyOverride,
    String? htmlBody,
    DateTime? timestamp,
    EncryptionProtocol encryptionProtocol = EncryptionProtocol.none,
    MessageError error = MessageError.none,
  }) async {
    final db = await _databaseBuilder();
    if (metadata != null) {
      await db.saveFileMetadata(metadata);
    }
    final displayBody = localBodyOverride ?? body;
    final trimmedBody = displayBody?.trim();
    final senderJid = _resolveOutgoingSenderJid(
      chat: chat,
      accountId: accountId,
    );
    final message = Message(
      stanzaID: stanzaId,
      senderJid: senderJid,
      chatJid: chat.jid,
      timestamp: timestamp ?? DateTime.timestamp(),
      originID: originId,
      body: trimmedBody?.isNotEmpty == true ? trimmedBody : null,
      htmlBody: HtmlContentCodec.normalizeHtml(htmlBody),
      subject: subject,
      quoting: quotingStanzaId,
      encryptionProtocol: encryptionProtocol,
      error: error,
      acked: false,
      received: false,
      deltaChatId: chatId,
      deltaMsgId: msgId,
      deltaAccountId: accountId,
      fileMetadataID: metadata?.id,
    );
    await _claimOutgoingEmailRow(db: db, message: message, selfJid: senderJid);
    if (shareId != null && msgId != null) {
      await db.insertMessageCopy(
        shareId: shareId,
        dcMsgId: msgId,
        dcChatId: chatId,
        dcAccountId: accountId,
      );
    }
  }

  Future<void> _claimOutgoingEmailRow({
    required XmppDatabase db,
    required Message message,
    required String selfJid,
  }) async {
    final msgId = message.deltaMsgId;
    if (msgId == null) {
      await db.saveMessage(message, selfJid: selfJid);
      return;
    }
    final echo = await db.getMessageByDeltaId(
      msgId,
      deltaAccountId: message.deltaAccountId,
      deltaChatId: message.deltaChatId,
    );
    if (echo != null) {
      await db.updateMessage(_withOutgoingPresentation(echo, message));
      return;
    }
    await db.saveMessage(message, selfJid: selfJid);
    final persisted = await db.getMessageByStanzaID(message.stanzaID);
    if (persisted != null) {
      return;
    }
    final racedEcho = await db.getMessageByDeltaId(
      msgId,
      deltaAccountId: message.deltaAccountId,
      deltaChatId: message.deltaChatId,
    );
    if (racedEcho != null) {
      await db.updateMessage(_withOutgoingPresentation(racedEcho, message));
    }
  }

  Message _withOutgoingPresentation(Message row, Message outgoing) {
    return row.copyWith(
      body: outgoing.body ?? row.body,
      htmlBody: outgoing.htmlBody ?? row.htmlBody,
      subject: outgoing.subject ?? row.subject,
      quoting: outgoing.quoting ?? row.quoting,
      fileMetadataID: outgoing.fileMetadataID ?? row.fileMetadataID,
    );
  }

  EncryptionProtocol _encryptionProtocolForDelta(DeltaMessage? message) {
    return message?.showPadlock == true
        ? EncryptionProtocol.openPgp
        : EncryptionProtocol.none;
  }

  Future<int> sendMessage({
    required Chat chat,
    required String body,
    String? subject,
    String? htmlBody,
    bool forwarded = false,
    String? forwardedFromJid,
    String? forwardedOriginalSenderLabel,
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
        forwardedOriginalSenderLabel: forwardedOriginalSenderLabel,
        quotedStanzaId: quotedStanzaId,
      );
    }
    final binding = await _bindEmailChat(chat);
    final chatId = binding.deltaChatId;
    final mode = _outgoingEncryptionModeForAccount(binding.account);
    await _ensureReady();
    final normalizedSubject = _normalizeSubject(subject);
    final payload = _outgoingTextPayload(
      body: body,
      htmlBody: htmlBody,
      subject: normalizedSubject,
    );
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
    final int msgId = await _sendAndRecordEmail(
      chatId: chatId,
      chat: binding.chat,
      accountId: binding.deltaAccountId,
      operation: 'send email message',
      send: () => _transport.sendText(
        chatId: chatId,
        body: payload.transmitText,
        subject: normalizedSubject,
        shareId: shareId,
        localBodyOverride: payload.displayText,
        htmlBody: payload.htmlBody,
        quotingStanzaId: quotedStanzaId,
        accountId: binding.deltaAccountId,
        forcePlaintext: mode.forcePlaintext,
        skipAutocrypt: mode.skipAutocrypt,
      ),
      body: payload.transmitText,
      subject: normalizedSubject,
      quotingStanzaId: quotedStanzaId,
      shareId: shareId,
      localBodyOverride: payload.displayText,
      htmlBody: payload.htmlBody,
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
        deltaChatId: chatId,
      );
      if (message != null && !message.isForwarded) {
        await db.updateMessage(
          message.copyWith(
            pseudoMessageData: message.pseudoMessageDataWithForwarded(
              forwardedFromJid: forwardedFromJid,
              forwardedOriginalSenderLabel: forwardedOriginalSenderLabel,
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
    String? forwardedOriginalSenderLabel,
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
        forwardedOriginalSenderLabel: forwardedOriginalSenderLabel,
        quotedStanzaId: effectiveQuotedStanzaId,
      );
    }
    final binding = await _bindEmailChat(chat);
    final chatId = binding.deltaChatId;
    final mode = _outgoingEncryptionModeForAccount(binding.account);
    await _ensureReady();
    final normalizedSubject = _normalizeSubject(effectiveSubject);
    final payload = _outgoingTextPayload(
      body: effectiveAttachment.caption,
      htmlBody: effectiveHtmlCaption,
      subject: normalizedSubject,
    );
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
    final pendingAttachment = effectiveAttachment.copyWith(
      caption: payload.transmitText,
    );
    final int msgId = await _sendAndRecordEmail(
      chatId: chatId,
      chat: binding.chat,
      accountId: binding.deltaAccountId,
      operation: 'send email attachment',
      send: () => _transport.sendAttachment(
        chatId: chatId,
        attachment: pendingAttachment,
        subject: normalizedSubject,
        shareId: shareId,
        captionOverride: payload.displayText,
        htmlCaption: payload.htmlBody,
        quotingStanzaId: effectiveQuotedStanzaId,
        accountId: binding.deltaAccountId,
        forcePlaintext: mode.forcePlaintext,
        skipAutocrypt: mode.skipAutocrypt,
      ),
      body: pendingAttachment.caption,
      subject: normalizedSubject,
      quotingStanzaId: effectiveQuotedStanzaId,
      shareId: shareId,
      localBodyOverride: payload.displayText,
      htmlBody: payload.htmlBody,
      metadataForMsg: (msgId, deltaMessage) {
        final metadata = _metadataForAttachment(pendingAttachment, msgId);
        if (deltaMessage == null) {
          return metadata;
        }
        return metadata.copyWith(
          path: deltaMessage.filePath ?? metadata.path,
          mimeType: deltaMessage.fileMime ?? metadata.mimeType,
          sizeBytes: deltaMessage.fileSize ?? metadata.sizeBytes,
          width: deltaMessage.width ?? metadata.width,
          height: deltaMessage.height ?? metadata.height,
        );
      },
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
        deltaChatId: chatId,
      );
      if (message != null && !message.isForwarded) {
        await db.updateMessage(
          message.copyWith(
            pseudoMessageData: message.pseudoMessageDataWithForwarded(
              forwardedFromJid: forwardedFromJid,
              forwardedOriginalSenderLabel: forwardedOriginalSenderLabel,
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
    if (targetChatsByJid.length > composeRecipientLimit) {
      throw const FanOutTooManyRecipientsException(composeRecipientLimit);
    }
    final normalizedSubject = _normalizeSubject(subject);
    final hasSubject = normalizedSubject != null;
    final hasAttachment = attachment != null;
    final bodyPayload = _outgoingTextPayload(
      body: body,
      htmlBody: htmlBody,
      subject: normalizedSubject,
    );
    final hasBody = bodyPayload.displayText.isNotEmpty;
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
    final effectiveBodyPayload = _outgoingTextPayload(
      body: bodyPayload.displayText,
      htmlBody: bodyPayload.htmlBody,
      subject: effectiveSubject,
      shareToken: subjectShareToken,
      tokenAsSignature: tokenAsSignature,
    );
    final captionPayload = _outgoingTextPayload(
      body: attachment?.caption,
      htmlBody: htmlCaption,
      subject: effectiveSubject,
      shareToken: subjectShareToken,
      tokenAsSignature: tokenAsSignature,
    );
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
        final mode = _outgoingEncryptionModeForAccount(binding.account);
        int msgId;
        if (hasAttachment) {
          final updatedAttachment = attachment.copyWith(
            caption: captionPayload.transmitText,
          );
          msgId = await _guardDeltaOperation(
            operation: 'fan-out attachment',
            body: () => _transport.sendAttachment(
              chatId: chatId,
              attachment: updatedAttachment,
              subject: effectiveSubject,
              shareId: effectiveShareId,
              captionOverride: captionPayload.displayText,
              htmlCaption: captionPayload.htmlBody,
              quotingStanzaId: quotedStanzaId,
              accountId: binding.deltaAccountId,
              forcePlaintext: mode.forcePlaintext,
              skipAutocrypt: mode.skipAutocrypt,
            ),
          );
        } else {
          msgId = await _guardDeltaOperation(
            operation: 'fan-out message',
            body: () => _transport.sendText(
              chatId: chatId,
              body: effectiveBodyPayload.transmitText,
              subject: effectiveSubject,
              shareId: effectiveShareId,
              localBodyOverride: effectiveBodyPayload.displayText,
              htmlBody: effectiveBodyPayload.htmlBody,
              quotingStanzaId: quotedStanzaId,
              accountId: binding.deltaAccountId,
              forcePlaintext: mode.forcePlaintext,
              skipAutocrypt: mode.skipAutocrypt,
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
    if (targets.map((target) => target.key).toSet().length >
        composeRecipientLimit) {
      throw const FanOutTooManyRecipientsException(composeRecipientLimit);
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
          final payload = _outgoingTextPayload(
            body: body,
            htmlBody: htmlBody,
            subject: subject,
          );
          await _sendDemoEmailMessage(
            chat: chat,
            body: payload.displayText,
            subject: subject,
            htmlBody: payload.htmlBody,
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

  ({String displayText, String transmitText, String? htmlBody})
  _outgoingTextPayload({
    required String? body,
    required String? subject,
    String? htmlBody,
    String? shareToken,
    bool tokenAsSignature = true,
  }) {
    final normalizedHtml = HtmlContentCodec.normalizeHtml(htmlBody);
    final trimmedBody = body?.trim() ?? '';
    final htmlText = normalizedHtml == null
        ? ''
        : HtmlContentCodec.toPlainText(normalizedHtml).trim();
    final displayText = trimmedBody.isNotEmpty ? trimmedBody : htmlText;
    final resolvedHtml =
        normalizedHtml ??
        (displayText.isEmpty
            ? null
            : HtmlContentCodec.normalizeHtml(
                HtmlContentCodec.fromPlainText(displayText),
              ));
    final envelope = _composeSubjectEnvelope(
      subject: subject,
      body: displayText,
    );
    final transmitText = shareToken == null
        ? envelope
        : ShareTokenCodec.injectToken(
            token: shareToken,
            body: envelope,
            asSignature: tokenAsSignature,
            footerLabel: _l10n.shareTokenFooterLabel,
          );
    final transmitHtml = shareToken == null
        ? resolvedHtml
        : ShareTokenHtmlCodec.injectToken(
            html: resolvedHtml,
            token: shareToken,
            asSignature: tokenAsSignature,
            footerLabel: _l10n.shareTokenFooterLabel,
          );
    return (
      displayText: displayText,
      transmitText: transmitText,
      htmlBody: transmitHtml,
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
    final payload = _outgoingTextPayload(body: normalizedBody, subject: null);
    return (
      subject: envelope.subject,
      body: normalizedBody,
      htmlBody: payload.htmlBody,
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
    final payload = _outgoingTextPayload(body: normalizedBody, subject: null);
    return (
      subject: envelope.subject,
      body: normalizedBody,
      htmlBody: payload.htmlBody,
      quotedStanzaId: quotedDraft.stanzaID,
    );
  }

  String? _normalizeDraftHtml({required String text, String? htmlBody}) {
    return _outgoingTextPayload(
      body: text,
      htmlBody: htmlBody,
      subject: null,
    ).htmlBody;
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
    if (_nativeCleanupPending ||
        _databasePrefix == null ||
        _databasePassphrase == null) {
      return;
    }
    await _transport.registerPushToken(normalized);
  }

  Future<void> handleNetworkAvailable() =>
      _enqueueNetworkTransition(_EmailNetworkTransition.available);

  Future<void> handleForegroundResumeNetworkAvailable() =>
      _enqueueNetworkTransition(
        _EmailNetworkTransition.foregroundResumeAvailable,
      );

  Future<void> handleNetworkLost() =>
      _enqueueNetworkTransition(_EmailNetworkTransition.lost);

  Future<void> _enqueueNetworkTransition(
    _EmailNetworkTransition transition,
  ) async {
    if (!_canProcessNetworkTransition) {
      _pendingNetworkTransition = null;
      return;
    }
    _setPendingNetworkTransition(transition);
    await _networkTransitionQueue.run(() async {
      if (!_canProcessNetworkTransition) {
        _pendingNetworkTransition = null;
        return;
      }
      final pending = _pendingNetworkTransition;
      _pendingNetworkTransition = null;
      if (pending == null) return;
      await _runNetworkTransition(pending);
    });
  }

  void _setPendingNetworkTransition(_EmailNetworkTransition transition) {
    if (transition == _EmailNetworkTransition.foregroundResumeAvailable) {
      if (_pendingNetworkTransition == _EmailNetworkTransition.lost) {
        return;
      }
      if (_activeNetworkTransition == _EmailNetworkTransition.lost &&
          _pendingNetworkTransition != _EmailNetworkTransition.available) {
        return;
      }
    }
    if (_pendingNetworkTransition ==
            _EmailNetworkTransition.foregroundResumeAvailable &&
        transition == _EmailNetworkTransition.available) {
      return;
    }
    _pendingNetworkTransition = transition;
  }

  Future<void> _runNetworkTransition(_EmailNetworkTransition transition) async {
    if (!_canProcessNetworkTransition) {
      return;
    }
    _activeNetworkTransition = transition;
    try {
      switch (transition) {
        case _EmailNetworkTransition.lost:
          await _handleNetworkLost();
        case _EmailNetworkTransition.available:
          await _handleNetworkAvailable(
            _EmailReconnectRestartPolicy.offlineOnly,
          );
        case _EmailNetworkTransition.foregroundResumeAvailable:
          await _handleNetworkAvailable(
            _EmailReconnectRestartPolicy.foregroundResume,
          );
      }
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      _log.fine(
        'Email network transition cancelled because the Delta worker stopped.',
        error,
        stackTrace,
      );
    } on DeltaSafeException catch (error, stackTrace) {
      _log.fine(
        'Email network transition failed in Delta core.',
        error,
        stackTrace,
      );
    } finally {
      if (_activeNetworkTransition == transition) {
        _activeNetworkTransition = null;
      }
    }
  }

  Future<void> _notifyTransportNetworkAvailable() =>
      _networkSignalQueue.run(_transport.notifyNetworkAvailable);

  Future<void> _notifyTransportNetworkLost() =>
      _networkSignalQueue.run(_transport.notifyNetworkLost);

  Future<void> _handleNetworkAvailable(
    _EmailReconnectRestartPolicy restartPolicy,
  ) async {
    if (!_canProcessNetworkTransition) {
      return;
    }
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await ensureEventChannelActive();
    await _notifyTransportNetworkAvailable();
    await _bootstrapActiveAccountIfNeeded();
    await _runReconnectCatchUp();
    _startImapSyncLoop();
    await _refreshConnectivityState(source: _EmailSyncSource.networkAvailable);
    fireAndForget(
      () => _scheduleReconnectRestart(restartPolicy),
      operationName: 'EmailService.reconnectRestart',
    );
  }

  Future<void> _handleNetworkLost() async {
    if (!_canProcessNetworkTransition) {
      return;
    }
    _stopImapSyncLoop();
    _applyDeviceNetworkLostState(source: _EmailSyncSource.networkLost);
    if (_databasePrefix == null || _databasePassphrase == null) {
      return;
    }
    await _notifyTransportNetworkLost();
  }

  Future<bool> performBackgroundFetch({
    Duration timeout = _imapSyncFetchTimeout,
  }) {
    final active = _backgroundFetchInFlight;
    if (active != null) {
      return active;
    }
    final task = _performBackgroundFetchExclusive(timeout: timeout);
    _backgroundFetchInFlight = task;
    return task.whenComplete(() {
      if (identical(_backgroundFetchInFlight, task)) {
        _backgroundFetchInFlight = null;
      }
    });
  }

  Future<bool> _performBackgroundFetchExclusive({
    required Duration timeout,
  }) async {
    if (_nativeCleanupPending || _blocksRuntimeReentry) {
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
    await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      final savedContacts = <Contact>[];
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
        savedContacts.add(
          Contact.address(
            nativeID: nativeId,
            address: normalized,
            displayName: contact.name?.trim(),
            transport: MessageTransport.email,
          ),
        );
        contactsByAddress.putIfAbsent(normalized, () => contact);
      }

      await db.replaceContacts(savedContacts);
      await _syncEmailBlocklist(db: db, blockedContacts: blocked);
      await _syncEmailChatMetadata(
        db: db,
        contactsByAddress: contactsByAddress,
      );
    });
  }

  Future<void> refreshChatlistFromCore() {
    final activeRefresh = _chatlistRefreshTask;
    if (activeRefresh != null) {
      return activeRefresh;
    }
    final task = _chatlistSyncQueue.run(() async {
      if (!await _ensureBackgroundSyncReady()) {
        return;
      }
      await _refreshChatlistSnapshotOnMain();
    });
    _chatlistRefreshTask = task;
    return task.whenComplete(() {
      if (identical(_chatlistRefreshTask, task)) {
        _chatlistRefreshTask = null;
      }
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
      await _notifyTransportNetworkAvailable();
      await _bootstrapActiveAccountIfNeeded();
      fireAndForget(
        () =>
            _scheduleReconnectRestart(_EmailReconnectRestartPolicy.offlineOnly),
        operationName: 'EmailService.reconnectRestart',
      );
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
      return await _refreshHomeEmailSnapshot();
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
      return await _refreshHomeEmailSnapshot();
    } on Exception {
      _log.fine('Email background sync failed.');
      return false;
    }
  }

  Future<bool> _refreshHomeEmailSnapshot() async {
    if (_transport.isIoRunning) {
      await refreshChatlistFromCore();
      return true;
    }
    final fetched = await performBackgroundFetch(
      timeout: _foregroundFetchTimeout,
    );
    if (!fetched) {
      return false;
    }
    await refreshChatlistFromCore();
    await _refreshConnectivityState(
      source: _EmailSyncSource.backgroundFetchDone,
      recoveryCompleted: true,
    );
    return true;
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

  Future<bool> syncSessionState() async {
    if (!await recoverForHomeRefresh()) {
      return false;
    }
    await Future.wait<void>([
      _runBestEffortSessionSync(syncContactsForHomeRefresh),
      _runBestEffortSessionSync(refreshHistoryForHomeRefresh),
    ]);
    return true;
  }

  Future<void> _runBestEffortSessionSync(
    Future<bool> Function() operation,
  ) async {
    try {
      await operation();
    } on Exception {
      // Home refresh is best-effort once session recovery succeeded.
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
    if (!chat.isEmailBacked) {
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
    if (_blocksRuntimeReentry) {
      return;
    }
    final Chat resolvedChat = await _trackAppDatabaseOperation(
      () => _storedEmailChatForAccount(
        chat: chat,
        deltaAccountId: account.deltaAccountId,
      ),
    );
    if (_blocksRuntimeReentry) {
      return;
    }
    await _ensureAccountConfigured(scope: scope, account: account);
    final int? chatId = await _deltaChatIdForAccount(
      chat: resolvedChat,
      deltaAccountId: account.deltaAccountId,
    );
    if (chatId == null) {
      return;
    }
    final Chat effectiveChat = await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      return await db.getChatByDeltaChatId(
            chatId,
            accountId: account.deltaAccountId,
          ) ??
          resolvedChat;
    });
    if (_blocksRuntimeReentry) {
      return;
    }
    final localCount = await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      return db.countEmailBackedChatMessages(
        effectiveChat.jid,
        deltaAccountId: account.deltaAccountId,
        filter: filter,
        includePseudoMessages: _includePseudoMessagesInBackfill,
      );
    });
    if (_blocksRuntimeReentry) {
      return;
    }
    if (localCount >= desiredWindow) {
      return;
    }
    await _performBackgroundFetchIfIdle(timeout: _foregroundFetchTimeout);
    await _backfillChatHistoryOnMain(
      chatId: chatId,
      chatJid: effectiveChat.jid,
      desiredWindow: desiredWindow,
      targetChat: effectiveChat,
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
    final bridge = _foregroundBridge;
    if (bridge == null) {
      _log.fine('Foreground bridge unavailable, skipping email foreground IO.');
      if (hasActiveSession) {
        _startImapSyncLoop();
      }
      return;
    }
    if (_foregroundKeepaliveEnabled) {
      if (await _foregroundKeepaliveRuntimeHealthy(bridge)) {
        await bridge.acquire(
          clientId: foregroundClientEmailDelta,
          config: buildForegroundServiceConfig(
            notificationText: 'Email sync active',
          ),
        );
        _foregroundKeepaliveLeaseAcquired = true;
        _log.fine('Email foreground IO already active.');
        return;
      }
      _log.warning(
        'Repairing stale email foreground IO. '
        'transport=${_transport.runtimeType}',
      );
      _foregroundKeepaliveEnabled = false;
    }

    final operationId = ++_foregroundKeepaliveOperationId;

    _log.info('Starting email foreground IO.');
    try {
      await bridge.acquire(
        clientId: foregroundClientEmailDelta,
        config: buildForegroundServiceConfig(
          notificationText: 'Email sync active',
        ),
      );
      _foregroundKeepaliveLeaseAcquired = true;
    } on Exception catch (error, stackTrace) {
      _foregroundKeepaliveEnabled = false;
      _foregroundKeepaliveLeaseAcquired = false;
      _log.warning(
        'Email foreground keepalive failed to acquire foreground service.',
        error,
        stackTrace,
      );
      if (hasActiveSession) {
        _startImapSyncLoop();
      }
      return;
    }
    if (!_isForegroundKeepaliveOpCurrent(operationId)) {
      await _releaseForegroundKeepaliveResources();
      return;
    }

    try {
      if (!_acceptsRuntimeWork) {
        await start();
      }
      if (!_isForegroundKeepaliveOpCurrent(operationId)) {
        await _releaseForegroundKeepaliveResources();
        if (hasActiveSession) {
          _startImapSyncLoop();
        }
        return;
      }
      _stopImapSyncLoop();
    } on Exception catch (error, stackTrace) {
      _foregroundKeepaliveEnabled = false;
      await _releaseForegroundKeepaliveResources();
      _log.warning(
        'Email foreground keepalive failed to keep worker runtime active.',
        error,
        stackTrace,
      );
      if (hasActiveSession) {
        _startImapSyncLoop();
      }
      return;
    }

    if (!_isForegroundKeepaliveOpCurrent(operationId)) {
      await _releaseForegroundKeepaliveResources();
      return;
    }

    _foregroundKeepaliveEnabled = true;
    _log.info('Email foreground IO started.');
  }

  @visibleForTesting
  bool get debugImapSyncLoopActive => _imapSyncLoopToken != null;

  @visibleForTesting
  Future<void> debugRunImapSyncTick() async {
    final token = _imapSyncLoopToken;
    if (token == null) {
      return;
    }
    await _runImapSyncTick(token);
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

  Future<void> _handleDeltaEvent(
    DeltaCoreEvent event, {
    required bool sourcePersistsAppStateInternally,
  }) async {
    final notifyBeforeHandle = event.type == DeltaEventCode.chatDeleted;
    if (!notifyBeforeHandle) {
      await _persistDeltaEvent(
        event,
        sourcePersistsAppStateInternally: sourcePersistsAppStateInternally,
      );
    }
    await _processDeltaEvent(event);
    if (notifyBeforeHandle) {
      await _persistDeltaEvent(
        event,
        sourcePersistsAppStateInternally: sourcePersistsAppStateInternally,
      );
    }
  }

  Future<void> _persistDeltaEvent(
    DeltaCoreEvent event, {
    required bool sourcePersistsAppStateInternally,
  }) async {
    if (sourcePersistsAppStateInternally) {
      return;
    }
    final eventType = DeltaEventType.fromCode(event.type);
    if (eventType == null) {
      return;
    }
    final accountId = _deltaAccountIdForEvent(event);
    if (accountId == null) {
      _log.fine('Skipping Delta event persistence without account id.');
      return;
    }
    final consumer = _deltaConsumerForAccount(accountId);
    await consumer.handle(event);
  }

  int? _deltaAccountIdForEvent(DeltaCoreEvent event) => event.accountId;

  DeltaEventConsumer _deltaConsumerForAccount(int accountId) {
    return _deltaEventConsumers.putIfAbsent(
      accountId,
      () => DeltaEventConsumer(
        databaseBuilder: _databaseBuilder,
        core: _EmailRuntimeEventCore(
          transport: _transport,
          accountId: accountId,
        ),
        localizationsProvider: () => _l10n,
        selfJidProvider: () => _selfSenderJidForAccount(accountId),
        xmppSelfJidProvider: _xmppSelfJidProvider,
        emailEncryptionBetaEnabledForAddress: (_, address) {
          final normalized = normalizedAddressValue(address);
          return normalized != null &&
              _emailEncryptionBetaEnabledByAddress[normalized] == true;
        },
        logger: _log,
        databaseOperationTracker: _trackAppDatabaseOperation,
      ),
    );
  }

  Future<bool> _bootstrapFromCoreOnMain() async {
    final accountIds = await _transport.accountIds();
    var didBootstrap = false;
    for (final accountId in accountIds) {
      await _transport.ensureAccountSession(accountId);
      final consumer = _deltaConsumerForAccount(accountId);
      if (await consumer.bootstrapFromCore()) {
        didBootstrap = true;
      }
    }
    return didBootstrap;
  }

  Future<void> _refreshChatlistSnapshotOnMain({int? accountId}) async {
    final accountIds = await _deltaAccountIdsForScope(accountId);
    for (final resolvedAccountId in accountIds) {
      await _transport.ensureAccountSession(resolvedAccountId);
      await _deltaConsumerForAccount(
        resolvedAccountId,
      ).refreshChatlistSnapshot();
    }
  }

  Future<void> _backfillChatHistoryOnMain({
    required int chatId,
    required String chatJid,
    required int desiredWindow,
    Chat? targetChat,
    int? beforeMessageId,
    DateTime? beforeTimestamp,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    int? accountId,
  }) async {
    final resolvedAccountId = accountId;
    if (resolvedAccountId == null) {
      _log.fine('Skipping Delta chat history backfill without account id.');
      return;
    }
    await _transport.ensureAccountSession(resolvedAccountId);
    await _deltaConsumerForAccount(resolvedAccountId).backfillChatHistory(
      chatId: chatId,
      chatJid: chatJid,
      desiredWindow: desiredWindow,
      targetChat: targetChat,
      beforeMessageId: beforeMessageId,
      beforeTimestamp: beforeTimestamp,
      filter: filter,
    );
  }

  Future<void> _hydrateMessagesOnMain(
    List<int> messageIds, {
    int? accountId,
  }) async {
    if (messageIds.isEmpty) {
      return;
    }
    final resolvedAccountId = accountId;
    if (resolvedAccountId == null) {
      _log.fine('Skipping Delta message hydration without account id.');
      return;
    }
    await _transport.ensureAccountSession(resolvedAccountId);
    final consumer = _deltaConsumerForAccount(resolvedAccountId);
    const int batchSize = 8;
    for (var index = 0; index < messageIds.length; index += batchSize) {
      final chunk = messageIds.skip(index).take(batchSize).toList();
      await Future.wait(chunk.map(consumer.hydrateMessage));
    }
  }

  Future<List<int>> _deltaAccountIdsForScope(int? accountId) async {
    if (accountId != null) {
      return <int>[accountId];
    }
    return _transport.accountIds();
  }

  Future<void> _processDeltaEvent(DeltaCoreEvent event) async {
    final eventType = DeltaEventType.fromCode(event.type);
    if (eventType == null) {
      return;
    }
    int? eventAccountId() {
      final accountId = _deltaAccountIdForEvent(event);
      if (accountId == null) {
        _log.fine('Skipping ${eventType.name} Delta event without account id.');
      }
      return accountId;
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
          final accountId = eventAccountId();
          if (accountId == null) {
            break;
          }
          _queueNotification(
            chatId: event.data1,
            msgId: event.data2,
            accountId: accountId,
          );
        }
        break;
      case DeltaEventType.incomingMsgBunch:
        await _flushQueuedNotifications();
        break;
      case DeltaEventType.incomingReaction:
        final accountId = eventAccountId();
        if (accountId == null) {
          break;
        }
        await _handleIncomingReaction(
          chatId: event.data1,
          msgId: event.data2,
          accountId: accountId,
          reaction: event.data2Text,
        );
        break;
      case DeltaEventType.incomingWebxdcNotify:
        final accountId = eventAccountId();
        if (accountId == null) {
          break;
        }
        await _handleIncomingWebxdcNotify(
          chatId: event.data1,
          msgId: event.data2,
          accountId: accountId,
          text: event.data2Text,
        );
        break;
      case DeltaEventType.msgRead:
        final accountId = eventAccountId();
        if (accountId == null) {
          break;
        }
        await _handleMessageRead(event.data1, accountId: accountId);
        break;
      case DeltaEventType.msgsNoticed:
        final accountId = eventAccountId();
        if (accountId == null) {
          break;
        }
        await _handleMessagesNoticed(event.data1, accountId: accountId);
        break;
      case DeltaEventType.chatModified:
        break;
      case DeltaEventType.chatDeleted:
        final accountId = eventAccountId();
        if (accountId == null) {
          break;
        }
        await _handleChatDeleted(event.data1, accountId: accountId);
        break;
      case DeltaEventType.contactsChanged:
        _scheduleContactsSyncFromCore();
        break;
      case DeltaEventType.accountsBackgroundFetchDone:
        await _handleBackgroundFetchDone();
        await _bootstrapActiveAccountIfNeeded();
        await refreshChatlistFromCore();
        await _refreshConnectivityState(
          source: _EmailSyncSource.backgroundFetchDone,
          recoveryCompleted: true,
        );
        break;
      case DeltaEventType.connectivityChanged:
        final connectivity = await _refreshConnectivityState(
          source: _EmailSyncSource.connectivityChangedEvent,
        );
        if (connectivity == null || connectivity < _connectivityWorkingMin) {
          break;
        }
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
    final notifiedEmailRfcGroups = <String>{};
    for (final entry in pending) {
      await _notifyIncoming(
        chatId: entry.chatId,
        msgId: entry.msgId,
        accountId: entry.accountId,
        notifiedEmailRfcGroups: notifiedEmailRfcGroups,
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
    if (!_canProcessDeltaWork) return;
    final threadKey = await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      final chat = await db.getChatByDeltaChatId(chatId, accountId: accountId);
      if (chat == null) return null;
      if (chat.unreadCount != _emptyUnreadCount) {
        return null;
      }
      return _notificationThreadKey(chat.jid);
    });
    if (threadKey == null || !_canProcessDeltaWork) {
      return;
    }
    await notificationService.dismissMessageNotification(threadKey: threadKey);
  }

  Future<void> _handleChatDeleted(int chatId, {required int accountId}) async {
    await _flushQueuedNotifications();
    final notificationService = _notificationService;
    if (notificationService == null) return;
    if (!_canProcessDeltaWork) return;
    final threadKey = await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      final chat = await db.getChatByDeltaChatId(chatId, accountId: accountId);
      if (chat == null) return null;
      return _notificationThreadKey(chat.jid);
    });
    if (threadKey == null || !_canProcessDeltaWork) {
      return;
    }
    await notificationService.dismissMessageNotification(threadKey: threadKey);
  }

  Future<_EmailNotificationTarget?> _notificationTargetForMessage({
    required XmppDatabase db,
    required _DeltaChatMessageId id,
  }) async {
    final message = await _lookupStoredDeltaMessage(db, id);
    if (message == null) {
      return null;
    }
    if (message.warning == MessageWarning.emailSpamQuarantined) {
      return null;
    }
    final selfJid = _selfSenderJidForAccount(id.accountId) ?? selfSenderJid;
    final senderBare = bareAddressValue(message.senderJid);
    final selfBare = bareAddressValue(selfJid);
    if (senderBare != null && selfBare != null && senderBare == selfBare) {
      return null;
    }
    var chat = await db.getChat(message.chatJid);
    final deltaChatId = id.chatId;
    if (chat == null && deltaChatId != null) {
      chat = await db.getChatByDeltaChatId(
        deltaChatId,
        accountId: id.accountId,
      );
    }
    final notificationBehavior = chat?.effectiveNotificationBehavior;
    if (notificationBehavior?.isMuted ?? false) {
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

  Future<Message?> _lookupStoredDeltaMessage(
    XmppDatabase db,
    _DeltaChatMessageId id,
  ) async {
    final scoped = await db.getMessageByDeltaId(
      id.msgId,
      deltaAccountId: id.accountId,
      deltaChatId: id.chatId,
    );
    if (scoped != null && _storedDeltaLocatorMatches(scoped, id)) {
      return scoped;
    }
    final legacy = await db.getMessageByStanzaID(
      deltaMessageStanzaId(id.msgId),
    );
    if (legacy == null || !_storedDeltaLocatorMatches(legacy, id)) {
      return null;
    }
    return legacy;
  }

  bool _storedDeltaLocatorMatches(Message message, _DeltaChatMessageId id) {
    if (message.deltaMsgId != id.msgId ||
        message.deltaAccountId != id.accountId) {
      return false;
    }
    final deltaChatId = message.deltaChatId;
    return id.chatId == null || deltaChatId == null || deltaChatId == id.chatId;
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

  Future<_EmailNotificationTarget?> _notificationTargetForRfcGroup({
    required XmppDatabase db,
    required _EmailNotificationTarget target,
  }) async {
    final originId = target.message.originID?.trim();
    if (originId == null ||
        originId.isEmpty ||
        target.message.emailRfcGroupKey == null) {
      return target;
    }
    final siblings = await db.getEmailMessagesByRfcGroup(
      chatJid: target.message.chatJid,
      originID: originId,
      deltaAccountId: target.message.deltaAccountId,
    );
    final groupedSiblings = siblings
        .where(target.message.hasSameEmailRfcGroup)
        .toList(growable: false);
    if (groupedSiblings.length < 2) {
      return target;
    }
    final leader = groupedSiblings
        .where((message) => !message.displayed && message.hasUnreadContent)
        .firstOrNull;
    if (leader == null) {
      return null;
    }
    if (leader == target.message) {
      return target;
    }
    return _EmailNotificationTarget(
      message: leader,
      chat: target.chat,
      threadKey: target.threadKey,
      conversationTitle: target.conversationTitle,
      senderName: target.senderName,
    );
  }

  Future<void> _notifyIncoming({
    required int chatId,
    required int msgId,
    required int accountId,
    required Set<String> notifiedEmailRfcGroups,
  }) async {
    final notificationService = _notificationService;
    if (notificationService == null) return;
    if (!_canProcessDeltaWork) return;
    try {
      final delivery = await _trackAppDatabaseOperation(() async {
        final db = await _databaseBuilder();
        var target = await _notificationTargetForMessage(
          db: db,
          id: _DeltaChatMessageId(
            accountId: accountId,
            chatId: chatId,
            msgId: msgId,
          ),
        );
        if (target == null) {
          return null;
        }
        target = await _notificationTargetForRfcGroup(db: db, target: target);
        if (target == null) {
          return null;
        }
        if (target.message.displayed || !target.message.hasUnreadContent) {
          return null;
        }
        if (_emailRfcGroupWasNotified(
          message: target.message,
          notifiedEmailRfcGroups: notifiedEmailRfcGroups,
        )) {
          return null;
        }
        final notificationBody = await _notificationBody(
          db: db,
          message: target.message,
          l10n: _l10n,
        );
        if (notificationBody == null) {
          return null;
        }
        final threadKey = target.threadKey;
        if (threadKey.isEmpty) {
          return null;
        }
        return _EmailNotificationDelivery(
          target: target,
          body: notificationBody,
          threadKey: threadKey,
          showPreview: NotificationPreviewSetting.resolveOverride(
            target.previewSetting,
            notificationService.notificationPreviewsEnabled,
          ),
        );
      });
      if (delivery == null || !_canProcessDeltaWork) {
        return;
      }
      final target = delivery.target;
      await notificationService.sendMessageNotification(
        title: target.title,
        body: delivery.body,
        senderName: target.senderName,
        senderKey: target.senderKey,
        conversationTitle: target.conversationTitle,
        sentAt: target.sentAt,
        isGroupConversation: target.isGroupConversation,
        ignoreChannelMute: target.ignoreChannelMute,
        payload: delivery.threadKey,
        threadKey: delivery.threadKey,
        showPreviewOverride: delivery.showPreview,
        channel: MessageNotificationChannel.email,
      );
      _markEmailRfcGroupNotified(
        message: target.message,
        notifiedEmailRfcGroups: notifiedEmailRfcGroups,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to raise notification for email message '
        '${deltaMessageStanzaId(msgId)} accountId=$accountId',
        error,
        stackTrace,
      );
    }
  }

  bool _emailRfcGroupWasNotified({
    required Message message,
    required Set<String> notifiedEmailRfcGroups,
  }) {
    final rfcGroupKey = message.emailRfcGroupKey;
    return rfcGroupKey != null && notifiedEmailRfcGroups.contains(rfcGroupKey);
  }

  void _markEmailRfcGroupNotified({
    required Message message,
    required Set<String> notifiedEmailRfcGroups,
  }) {
    final rfcGroupKey = message.emailRfcGroupKey;
    if (rfcGroupKey != null) {
      notifiedEmailRfcGroups.add(rfcGroupKey);
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
    if (!_canProcessDeltaWork) return;
    try {
      final delivery = await _trackAppDatabaseOperation(() async {
        final db = await _databaseBuilder();
        final target = await _notificationTargetForMessage(
          db: db,
          id: _DeltaChatMessageId(
            accountId: accountId,
            chatId: chatId,
            msgId: msgId,
          ),
        );
        if (target == null) {
          return null;
        }
        final normalizedReaction = reaction?.trim();
        final body = normalizedReaction == null || normalizedReaction.isEmpty
            ? _l10n.notificationReactionFallback
            : _l10n.notificationReactionLabel(normalizedReaction);
        final threadKey = target.threadKey;
        if (threadKey.isEmpty) {
          return null;
        }
        return _EmailNotificationDelivery(
          target: target,
          body: body,
          threadKey: threadKey,
          showPreview: NotificationPreviewSetting.resolveOverride(
            target.previewSetting,
            notificationService.notificationPreviewsEnabled,
          ),
        );
      });
      if (delivery == null || !_canProcessDeltaWork) {
        return;
      }
      final target = delivery.target;
      await notificationService.sendMessageNotification(
        title: target.title,
        body: delivery.body,
        senderName: target.senderName,
        senderKey: target.senderKey,
        conversationTitle: target.conversationTitle,
        sentAt: target.sentAt,
        isGroupConversation: target.isGroupConversation,
        ignoreChannelMute: target.ignoreChannelMute,
        payload: delivery.threadKey,
        threadKey: delivery.threadKey,
        showPreviewOverride: delivery.showPreview,
        channel: MessageNotificationChannel.email,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to raise reaction notification for email message '
        '${deltaMessageStanzaId(msgId)} accountId=$accountId',
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
    if (!_canProcessDeltaWork) return;
    try {
      final delivery = await _trackAppDatabaseOperation(() async {
        final db = await _databaseBuilder();
        final target = await _notificationTargetForMessage(
          db: db,
          id: _DeltaChatMessageId(
            accountId: accountId,
            chatId: chatId,
            msgId: msgId,
          ),
        );
        if (target == null) {
          return null;
        }
        final normalizedText = text?.trim();
        final body = normalizedText == null || normalizedText.isEmpty
            ? _l10n.notificationWebxdcFallback
            : normalizedText;
        final threadKey = target.threadKey;
        if (threadKey.isEmpty) {
          return null;
        }
        return _EmailNotificationDelivery(
          target: target,
          body: body,
          threadKey: threadKey,
          showPreview: NotificationPreviewSetting.resolveOverride(
            target.previewSetting,
            notificationService.notificationPreviewsEnabled,
          ),
        );
      });
      if (delivery == null || !_canProcessDeltaWork) {
        return;
      }
      final target = delivery.target;
      await notificationService.sendMessageNotification(
        title: target.title,
        body: delivery.body,
        senderName: target.senderName,
        senderKey: target.senderKey,
        conversationTitle: target.conversationTitle,
        sentAt: target.sentAt,
        isGroupConversation: target.isGroupConversation,
        ignoreChannelMute: target.ignoreChannelMute,
        payload: delivery.threadKey,
        threadKey: delivery.threadKey,
        showPreviewOverride: delivery.showPreview,
        channel: MessageNotificationChannel.email,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to raise webxdc notification for email message '
        '${deltaMessageStanzaId(msgId)} accountId=$accountId',
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

  Future<int?> _refreshConnectivityState({
    _EmailSyncSource source = _EmailSyncSource.unknown,
    bool recoveryCompleted = false,
  }) async {
    if (!_acceptsRuntimeWork) {
      return null;
    }
    try {
      final connectivity = await _readTransportConnectivity(source: source);
      if (!_acceptsRuntimeWork) {
        return null;
      }
      if (connectivity == null) return null;
      _recordConnectivitySample(connectivity: connectivity, source: source);
      await _maybeLogConnectingConnectivityDetail(
        connectivity: connectivity,
        source: source,
      );
      if (recoveryCompleted && connectivity >= _connectivityWorkingMin) {
        _cancelConnectivityDowngrade();
        _updateSyncState(const EmailSyncState.ready(), source: source);
        return connectivity;
      }
      if (connectivity >= _connectivityConnectedMin) {
        _cancelConnectivityDowngrade();
        _updateSyncState(const EmailSyncState.ready(), source: source);
        return connectivity;
      }
      if (connectivity >= _connectivityWorkingMin) {
        _cancelConnectivityDowngrade();
        if (_syncState.status == EmailSyncStatus.ready) {
          return connectivity;
        }
        _updateSyncState(
          EmailSyncState.recovering(_l10n.emailSyncMessageSyncing),
          source: source,
        );
        return connectivity;
      }
      if (_syncState.status == EmailSyncStatus.ready) {
        _scheduleConnectivityDowngrade(connectivity);
        return connectivity;
      }
      _applyConnectivityState(
        connectivity,
        source: _EmailSyncSource.connectivityApply,
      );
      return connectivity;
    } on TimeoutException {
      return null;
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to refresh email connectivity', error, stackTrace);
      return null;
    }
  }

  void _applyDeviceNetworkLostState({required _EmailSyncSource source}) {
    _cancelConnectivityDowngrade();
    _consecutiveConnectingSamples = 0;
    _updateSyncState(
      EmailSyncState.offline(_l10n.emailSyncMessageDisconnected),
      source: source,
    );
  }

  Future<int?> _readTransportConnectivity({
    required _EmailSyncSource source,
  }) async {
    try {
      return await _transport.connectivity().timeout(_connectivityProbeTimeout);
    } on TimeoutException catch (error, stackTrace) {
      _log.warning(
        'Timed out refreshing email connectivity. source=${source.name}',
        error,
        stackTrace,
      );
      rethrow;
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
      final connectivity = await _readTransportConnectivity(
        source: _EmailSyncSource.connectivityConfirm,
      );
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
    } on TimeoutException {
      return;
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

  Future<void> _maybeLogConnectingConnectivityDetail({
    required int connectivity,
    required _EmailSyncSource source,
  }) async {
    if (connectivity != _connectivityConnectingMin) {
      _consecutiveConnectingSamples = 0;
      return;
    }
    _consecutiveConnectingSamples += 1;
    if (_consecutiveConnectingSamples <
        _connectivityDetailConnectingSampleThreshold) {
      return;
    }
    final now = DateTime.timestamp();
    final lastLoggedAt = _lastConnectivityDetailLoggedAt;
    if (lastLoggedAt != null &&
        now.difference(lastLoggedAt) < _connectivityDetailLogInterval) {
      return;
    }
    _lastConnectivityDetailLoggedAt = now;
    try {
      final detail = _sanitizeConnectivityDetail(
        await _transport.connectivityDetails(),
      );
      _log.warning(
        '$_emailConnectivityDetailLogPrefix: '
        '$_emailLogSourceLabel=${source.logLabel}, '
        '$_emailLogValueLabel=$connectivity, '
        '$_emailLogStateLabel=${_syncState.status.name}, '
        '$_emailLogIoRunningLabel=${_transport.isIoRunning}, '
        '$_emailLogDetailLabel=${detail ?? _emailLogUnknownValue}',
      );
    } on Exception catch (error, stackTrace) {
      _log.finer('Failed to read email connectivity detail', error, stackTrace);
    }
  }

  String? _sanitizeConnectivityDetail(String? detail) {
    if (detail == null) {
      return null;
    }
    final withoutStyle = detail.replaceAll(
      RegExp(r'<style\b[^>]*>.*?</style>', caseSensitive: false, dotAll: true),
      ' ',
    );
    final withoutScript = withoutStyle.replaceAll(
      RegExp(
        r'<script\b[^>]*>.*?</script>',
        caseSensitive: false,
        dotAll: true,
      ),
      ' ',
    );
    final withoutTags = withoutScript.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final collapsed = withoutTags.trim().split(RegExp(r'\s+')).join(' ');
    if (collapsed.isEmpty) {
      return null;
    }
    final redacted = collapsed.replaceAll(
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
      '<email>',
    );
    if (redacted.length <= _connectivityDetailMaxLength) {
      return redacted;
    }
    return redacted.substring(0, _connectivityDetailMaxLength);
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
        final success = await _performBackgroundFetchIfIdle(
          timeout: _foregroundFetchTimeout,
        );
        if (!success) {
          await _notifyTransportNetworkAvailable();
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

  void _attachTransportListener([EmailDeltaRuntime? transport]) {
    final target = transport ?? _transport;
    if (identical(_listenerTransport, target)) return;
    _detachTransportListener();
    void listener(DeltaCoreEvent event) {
      if (!_canProcessDeltaWork) {
        return;
      }
      final sourcePersistsAppStateInternally =
          target.persistsAppStateInternally;
      _enqueueDeltaOperation(
        () => _handleDeltaEvent(
          event,
          sourcePersistsAppStateInternally: sourcePersistsAppStateInternally,
        ),
        operationName: _deltaQueueOperationNameProcessDeltaEvent,
      );
    }

    target.addEventListener(listener);
    _listenerTransport = target;
    _listenerCallback = listener;
  }

  void _detachTransportListener({EmailDeltaRuntime? transport}) {
    final attached = _listenerTransport;
    if (attached == null) return;
    if (transport != null && !identical(attached, transport)) return;
    final callback = _listenerCallback;
    if (callback != null) {
      attached.removeEventListener(callback);
    }
    if (identical(_listenerTransport, attached)) {
      _listenerTransport = null;
      _listenerCallback = null;
    }
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
      final didBootstrap = await _bootstrapFromCoreOnMain();
      if (operationId != _bootstrapOperationIdForScope(scope) ||
          !_acceptsRuntimeWork) {
        return;
      }
      if (didBootstrap) {
        await _credentialStore.write(key: bootstrapKey, value: true.toString());
      }
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
    if (!_foregroundKeepaliveEnabled && !_foregroundKeepaliveLeaseAcquired) {
      return;
    }
    final stopwatch = Stopwatch()..start();
    _log.info(
      'Stopping email foreground IO. '
      'enabled=$_foregroundKeepaliveEnabled '
      'transport=${_transport.runtimeType}',
    );
    try {
      _foregroundKeepaliveEnabled = false;
      await _releaseForegroundKeepaliveResources();
    } finally {
      stopwatch.stop();
      _log.info(
        'Stopped email foreground IO. '
        'elapsedMs=${stopwatch.elapsedMilliseconds} '
        'transport=${_transport.runtimeType}',
      );
    }
  }

  Future<bool> _foregroundKeepaliveRuntimeHealthy(
    ForegroundTaskBridge bridge,
  ) async {
    if (!_foregroundKeepaliveEnabled || !_foregroundKeepaliveLeaseAcquired) {
      return false;
    }
    try {
      return await bridge.isRunning();
    } on Exception catch (error, stackTrace) {
      _log.fine(
        'Failed to inspect email foreground keepalive runtime.',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<void> _releaseForegroundKeepaliveResources() async {
    if (!_foregroundKeepaliveLeaseAcquired) {
      return;
    }
    _foregroundKeepaliveLeaseAcquired = false;
    await _foregroundBridge?.release(foregroundClientEmailDelta);
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
    if (!_canContinueImapSyncLoop(token)) {
      return;
    }
    final interval = _imapSyncInterval();
    _imapSyncTimer?.cancel();
    _imapSyncTimer = Timer(interval, () async {
      await _runImapSyncTick(token);
    });
  }

  Future<void> _runImapSyncTick(Object token) async {
    if (!_canContinueImapSyncLoop(token)) {
      return;
    }
    if (_transport.isIoRunning) {
      _scheduleNextImapSync(token);
      return;
    }
    try {
      await _enqueueImapSync(token);
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      if (!_canContinueImapSyncLoop(token)) {
        _log.fine('Email IMAP sync tick cancelled.', error, stackTrace);
        return;
      }
      _log.warning('Email IMAP sync tick failed.', error, stackTrace);
    } on DeltaSafeException catch (error, stackTrace) {
      if (!_canContinueImapSyncLoop(token)) {
        _log.fine('Email IMAP sync tick cancelled.', error, stackTrace);
        return;
      }
      _log.warning('Email IMAP sync tick failed.', error, stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      if (!_canContinueImapSyncLoop(token)) {
        _log.fine('Email IMAP sync tick cancelled.', error, stackTrace);
        return;
      }
      _log.warning('Email IMAP sync tick timed out.', error, stackTrace);
    }
    _scheduleNextImapSync(token);
  }

  Future<void> _enqueueImapSync(Object token) async {
    await _imapSyncQueue.run(() async {
      if (!_canContinueImapSyncLoop(token)) {
        return;
      }
      await _refreshImapCapabilities();
      if (!_canContinueImapSyncLoop(token)) {
        return;
      }
      await _performBackgroundFetchIfIdle(timeout: _imapSyncFetchTimeout);
      if (!_canContinueImapSyncLoop(token)) {
        return;
      }
      await refreshChatlistFromCore();
    });
  }

  bool _canContinueImapSyncLoop(Object token) =>
      _imapSyncLoopToken == token &&
      !_foregroundKeepaliveEnabled &&
      hasActiveSession &&
      !_nativeCleanupPending &&
      !_blocksRuntimeReentry;

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
        recoveryCompleted: true,
      );
    });
  }

  Future<void> _scheduleReconnectRestart(
    _EmailReconnectRestartPolicy restartPolicy,
  ) async {
    await _reconnectRestartQueue.run(() async {
      if (!_acceptsRuntimeWork) {
        return;
      }
      try {
        await Future.delayed(_reconnectRestartDelay);
        if (!_acceptsRuntimeWork) {
          return;
        }
        final connectivity = await _refreshConnectivityState(
          source: _EmailSyncSource.reconnectRestart,
        );
        final restartConnectivity = await _connectivityForRestart(
          connectivity: connectivity,
          restartPolicy: restartPolicy,
        );
        if (restartConnectivity == null) {
          return;
        }
        _log.warning(
          'Email transport did not recover after network available; '
          'restarting. connectivity=$restartConnectivity '
          'policy=${restartPolicy.name}',
        );
        await stop();
        await start();
        await _notifyTransportNetworkAvailable();
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

  Future<int?> _connectivityForRestart({
    required int? connectivity,
    required _EmailReconnectRestartPolicy restartPolicy,
  }) async {
    if (connectivity == null) {
      return null;
    }
    if (connectivity < _connectivityConnectingMin) {
      return connectivity;
    }
    if (connectivity >= _connectivityWorkingMin) {
      return null;
    }
    if (restartPolicy != _EmailReconnectRestartPolicy.foregroundResume) {
      return null;
    }
    if (!_transport.isIoRunning) {
      return null;
    }
    await _notifyTransportNetworkAvailable();
    await Future.delayed(_reconnectRestartDelay);
    if (!_acceptsRuntimeWork) {
      return null;
    }
    final retryConnectivity = await _refreshConnectivityState(
      source: _EmailSyncSource.reconnectRestart,
    );
    if (retryConnectivity == null) {
      return null;
    }
    if (retryConnectivity >= _connectivityWorkingMin) {
      await _runReconnectCatchUp();
      return null;
    }
    if (retryConnectivity >= _connectivityConnectingMin &&
        !_transport.isIoRunning) {
      return null;
    }
    return retryConnectivity;
  }

  Future<void> _ensureReady() async {
    if (kEnableDemoChats) {
      return;
    }
    if (_nativeCleanupPending) {
      throw const EmailServiceStoppingException();
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
    if (_nativeCleanupPending || _blocksRuntimeReentry || !hasActiveSession) {
      return false;
    }
    await ensureEventChannelActive();
    if (!_acceptsRuntimeWork || _blocksRuntimeReentry) {
      return false;
    }
    await _repairStoredDeltaAccountIdsOnce();
    return true;
  }

  Future<void> _repairStoredDeltaAccountIdsOnce() async {
    if (_deltaAccountRepairCompleted) {
      return;
    }
    _deltaAccountRepairCompleted = true;
    final accountIds = await _transport.accountIds();
    if (accountIds.isEmpty) {
      return;
    }
    final db = await _databaseBuilder();
    final invalid = await db.getEmailMessagesWithDeltaAccountNotIn(accountIds);
    for (final message in invalid) {
      await _repairStoredDeltaAccountId(db: db, message: message);
    }
    if (invalid.isNotEmpty) {
      _log.info('Repaired ${invalid.length} stored delta account ids.');
    }
  }

  Future<void> _repairStoredDeltaAccountId({
    required XmppDatabase db,
    required Message message,
  }) async {
    final resolved = await _resolveDeltaAccountIdForStoredMessage(message);
    if (resolved != null) {
      await db.updateMessage(message.copyWith(deltaAccountId: resolved));
      return;
    }
    await db.clearMessageDeltaHandles(message.stanzaID);
  }

  Future<int> _sendDemoEmailMessage({
    required Chat chat,
    required String body,
    String? subject,
    String? htmlBody,
    bool forwarded = false,
    String? forwardedFromJid,
    String? forwardedOriginalSenderLabel,
    String? quotedStanzaId,
  }) async {
    final normalizedSubject = _normalizeSubject(subject);
    final payload = _outgoingTextPayload(
      body: body,
      htmlBody: htmlBody,
      subject: normalizedSubject,
    );
    const generator = Uuid();
    final stanzaId = 'demo-email-${generator.v4()}';
    final forwardedFromNormalized = forwardedFromJid?.trim();
    final originalSenderNormalized = forwardedOriginalSenderLabel?.trim();
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
      body: payload.displayText,
      htmlBody: payload.htmlBody,
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
              if (originalSenderNormalized != null &&
                  originalSenderNormalized.isNotEmpty)
                'forwardedOriginalSenderLabel': originalSenderNormalized,
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
    String? forwardedOriginalSenderLabel,
    String? quotedStanzaId,
  }) async {
    final normalizedSubject = _normalizeSubject(subject);
    final payload = _outgoingTextPayload(
      body: attachment.caption,
      htmlBody: htmlCaption,
      subject: normalizedSubject,
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
    final originalSenderNormalized = forwardedOriginalSenderLabel?.trim();
    final message = Message(
      stanzaID: stanzaId,
      originID: stanzaId,
      senderJid: kDemoSelfJid,
      chatJid: chat.jid,
      body: payload.transmitText,
      htmlBody: payload.htmlBody,
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
              if (originalSenderNormalized != null &&
                  originalSenderNormalized.isNotEmpty)
                'forwardedOriginalSenderLabel': originalSenderNormalized,
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

  Future<void> _applyDeltaSelfSyncSuppression() async {
    if (!hasActiveSession) {
      return;
    }
    final resolvedAccountIds = await _transport.accountIds();
    final targetAccountIds = resolvedAccountIds.isEmpty
        ? <int>[_transport.activeAccountId]
        : resolvedAccountIds;
    final appliedAccountIds = <int>{};
    for (final accountId in targetAccountIds) {
      if (!appliedAccountIds.add(accountId)) {
        continue;
      }
      await _transport.setCoreConfig(
        key: _syncMsgsConfigKey,
        value: '0',
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

  bool _usesOwnEmailBackedThread(Chat chat) {
    final String normalizedJid = normalizeEmailAddress(chat.jid);
    if (chat.defaultTransport.isEmail ||
        _isSyntheticEmailChatAddress(normalizedJid)) {
      return false;
    }
    return chat.deltaChatId != null || _storedRealEmailAddress(chat) != null;
  }

  Future<Chat> _storedEmailChatForAccount({
    required Chat chat,
    required int deltaAccountId,
  }) async {
    final db = await _databaseBuilder();
    if (_usesOwnEmailBackedThread(chat)) {
      return await db.getChat(chat.jid) ?? chat;
    }
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
      if (storedByDelta != null &&
          _canUseDeltaMappedChatForInput(
            requested: chat,
            mapped: storedByDelta,
          )) {
        return storedByDelta;
      }
    }
    final Chat? stored = await db.getChat(chat.jid);
    return stored ?? chat;
  }

  bool _canUseDeltaMappedChatForInput({
    required Chat requested,
    required Chat mapped,
  }) {
    if (sameBareAddress(mapped.jid, requested.jid)) {
      return true;
    }
    return _isSyntheticEmailChatAddress(normalizeEmailAddress(requested.jid));
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
    await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      await db.updateChat(chat.copyWith(emailFromAddress: address));
    });
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
    await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      await db.updateChat(
        chat.copyWith(
          deltaChatId: deltaChatId,
          emailAddress: resolvedEmailAddress,
        ),
      );
    });
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
    await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      final xmppSelfJid = _xmppSelfJidProvider?.call();
      await db.removeDeltaPlaceholderDuplicates(
        deltaAccountId: deltaAccountId,
        placeholderJids: deltaPlaceholderJids,
        selfJid: xmppSelfJid,
        emailSelfJid: normalizedAddress,
      );
      await db.replaceDeltaPlaceholderSelfJids(
        deltaAccountId: deltaAccountId,
        resolvedAddress: normalizedAddress,
        placeholderJids: deltaPlaceholderJids,
        selfJid: xmppSelfJid,
        emailSelfJid: normalizedAddress,
      );
    });
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
    if (_blocksRuntimeReentry) {
      throw const EmailServiceStoppingException();
    }
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

  EmailOutgoingEncryptionMode _outgoingEncryptionModeForAccount(
    _EmailAccountBinding account,
  ) {
    return outgoingEncryptionModeForAddress(account.address);
  }

  Future<_EmailAccountBinding> _requireActiveEncryptionAccount() async {
    final scope = _activeCredentialScope;
    if (_activeAccount == null || scope == null) {
      throw const EmailEncryptionNoActiveAccountException();
    }
    return _accountBindingForScope(scope: scope);
  }

  Future<_EmailAccountBinding>
  _requireActiveEncryptionAccountForContactKey() async {
    try {
      return await _requireActiveEncryptionAccount();
    } on EmailEncryptionNoActiveAccountException {
      throw const EmailContactKeyNoActiveAccountException();
    }
  }

  Future<Directory> _createEmailEncryptionOperationDirectory() async {
    final root = await appOwnedTemporaryDirectory(
      emailEncryptionKeyTempDirectoryName,
    );
    await root.create(recursive: true);
    final operationName = normalizeAppOwnedPathSegment(
      'op-${DateTime.timestamp().microsecondsSinceEpoch}-${const Uuid().v4()}',
    );
    final directory = Directory(p.join(root.path, operationName));
    await directory.create();
    return directory;
  }

  Future<EmailOpenPgpKeyMetadata> _inspectOpenPgpKeyFile({
    required File file,
    required String expectedAddress,
    required DeltaOpenPgpKeyKind expectedKind,
  }) async {
    return _inspectOpenPgpArmoredKey(
      armored: await file.readAsString(),
      expectedAddress: expectedAddress,
      expectedKind: expectedKind,
    );
  }

  Future<EmailOpenPgpKeyMetadata> _inspectOpenPgpArmoredKey({
    required String armored,
    required String expectedAddress,
    required DeltaOpenPgpKeyKind expectedKind,
  }) async {
    final metadata = await _transport.inspectOpenPgpKey(
      armored: armored,
      expectedAddress: expectedAddress,
      expectedKind: expectedKind,
    );
    return EmailOpenPgpKeyMetadata(
      kind: switch (metadata.kind) {
        DeltaOpenPgpKeyKind.public => EmailOpenPgpKeyKind.public,
        DeltaOpenPgpKeyKind.private => EmailOpenPgpKeyKind.private,
      },
      fingerprint: metadata.fingerprint,
      userIds: metadata.userIds,
      hasExpectedAddress: metadata.hasExpectedAddress,
      hasEncryptionCapability: metadata.hasEncryptionCapability,
    );
  }

  Future<String> _readSingleArmoredPublicKey(File source) async {
    final sourceType = await FileSystemEntity.type(
      source.path,
      followLinks: false,
    );
    if (sourceType != FileSystemEntityType.file) {
      throw const EmailContactKeyUnsupportedFormatException();
    }
    final extension = p.extension(source.path).toLowerCase();
    if (!_emailEncryptionDirectImportExtensions.contains(extension)) {
      throw const EmailContactKeyUnsupportedFormatException();
    }
    final text = await source.readAsString();
    if (text.contains(_privateKeyArmorBegin)) {
      throw const EmailContactKeyUnsupportedFormatException();
    }
    final publicBlockCount = _armorMarkerCount(text, _publicKeyArmorBegin);
    if (publicBlockCount != 1) {
      throw const EmailContactKeyUnsupportedFormatException();
    }
    return text;
  }

  int _armorMarkerCount(String value, String marker) =>
      marker.isEmpty ? 0 : marker.allMatches(value).length;

  Future<File> _prepareEmailEncryptionImportFile({
    required File source,
    required Directory operationDirectory,
  }) async {
    final sourceType = await FileSystemEntity.type(
      source.path,
      followLinks: false,
    );
    if (sourceType != FileSystemEntityType.file) {
      throw const EmailEncryptionUnsupportedKeyFormatException();
    }
    final extension = p.extension(source.path).toLowerCase();
    if (extension == '.zip') {
      return _prepareEmailEncryptionImportFileFromZip(
        source: source,
        operationDirectory: operationDirectory,
      );
    }
    if (!_emailEncryptionDirectImportExtensions.contains(extension)) {
      throw const EmailEncryptionUnsupportedKeyFormatException();
    }
    final bytes = await source.readAsBytes();
    if (!_containsAsciiArmoredPrivateKey(bytes)) {
      throw const EmailEncryptionUnsupportedKeyFormatException();
    }
    final importFile = File(
      p.join(operationDirectory.path, _emailEncryptionImportFileName),
    );
    await importFile.writeAsBytes(bytes, flush: true);
    return importFile;
  }

  Future<File> _prepareEmailEncryptionImportFileFromZip({
    required File source,
    required Directory operationDirectory,
  }) async {
    final archive = ZipDecoder().decodeBytes(await source.readAsBytes());
    final candidates = <ArchiveFile>[];
    for (final entry in archive.files) {
      final name = entry.name.trim();
      if (name.isEmpty ||
          p.isAbsolute(name) ||
          p.basename(name) != name ||
          p.normalize(name) != name ||
          entry.isSymbolicLink ||
          !entry.isFile) {
        throw const EmailEncryptionUnsupportedKeyFormatException();
      }
      final bytes = entry.readBytes();
      if (bytes != null && _containsAsciiArmoredPrivateKey(bytes)) {
        candidates.add(entry);
      }
    }
    if (candidates.isEmpty) {
      throw const EmailEncryptionNoPrivateKeyFoundException();
    }
    final selected = _selectEmailEncryptionImportCandidate(candidates);
    final bytes = selected.readBytes();
    if (bytes == null || !_containsAsciiArmoredPrivateKey(bytes)) {
      throw const EmailEncryptionNoPrivateKeyFoundException();
    }
    final importFile = File(
      p.join(operationDirectory.path, _emailEncryptionImportFileName),
    );
    await importFile.writeAsBytes(bytes, flush: true);
    return importFile;
  }

  ArchiveFile _selectEmailEncryptionImportCandidate(
    List<ArchiveFile> candidates,
  ) {
    if (candidates.length == 1) {
      return candidates.single;
    }
    final defaultNamePattern = RegExp(
      r'^private-key-.+-default-[0-9A-Fa-f]+\.asc$',
    );
    final defaultCandidates = candidates
        .where((entry) => defaultNamePattern.hasMatch(p.basename(entry.name)))
        .toList(growable: false);
    if (defaultCandidates.length == 1) {
      return defaultCandidates.single;
    }
    throw const EmailEncryptionAmbiguousKeyArchiveException();
  }

  bool _containsAsciiArmoredPrivateKey(List<int> bytes) {
    final text = String.fromCharCodes(bytes);
    return text.contains(_privateKeyArmorBegin);
  }

  bool _containsAsciiArmoredPublicKey(List<int> bytes) {
    final text = String.fromCharCodes(bytes);
    return text.contains(_publicKeyArmorBegin);
  }

  Future<void> _verifyEmailEncryptionKey(
    _EmailAccountBinding account, {
    required EmailEncryptionKeyException failure,
  }) async {
    final keyId = await _transport.getCoreConfig(
      _openPgpKeyIdConfigKey,
      accountId: account.deltaAccountId,
    );
    if (keyId == null || keyId.trim().isEmpty) {
      throw failure;
    }
  }

  Future<File> _zipEmailEncryptionExport({
    required Directory operationDirectory,
    required _EmailAccountBinding account,
  }) async {
    final ascFiles = <({String name, File file, Uint8List bytes})>[];
    await for (final entity in operationDirectory.list(followLinks: false)) {
      final entityPath = entity.path;
      final entityType = await FileSystemEntity.type(
        entityPath,
        followLinks: false,
      );
      if (entityType != FileSystemEntityType.file ||
          p.extension(entityPath).toLowerCase() != '.asc') {
        continue;
      }
      final file = File(entityPath);
      ascFiles.add((
        name: p.basename(file.path),
        file: file,
        bytes: await file.readAsBytes(),
      ));
    }
    ({String fingerprint, String name, Uint8List bytes})? privateKey;
    for (final candidate in ascFiles) {
      final privateFingerprint = _defaultEmailEncryptionExportKeyFingerprint(
        candidate.name,
        normalizedAddress: account.address,
        kind: EmailOpenPgpKeyKind.private,
      );
      if (privateFingerprint == null) {
        continue;
      }
      if (privateKey != null) {
        throw const EmailEncryptionExportFailedException();
      }
      if (!_containsAsciiArmoredPrivateKey(candidate.bytes)) {
        throw const EmailEncryptionExportFailedException();
      }
      final metadata = await _inspectOpenPgpKeyFile(
        file: candidate.file,
        expectedAddress: account.address,
        expectedKind: DeltaOpenPgpKeyKind.private,
      );
      if (!metadata.hasEncryptionCapability ||
          metadata.fingerprint.toLowerCase() !=
              privateFingerprint.toLowerCase()) {
        throw const EmailEncryptionExportFailedException();
      }
      privateKey = (
        fingerprint: privateFingerprint,
        name: candidate.name,
        bytes: candidate.bytes,
      );
    }
    final privateKeyValue = privateKey;
    if (privateKeyValue == null) {
      throw const EmailEncryptionExportFailedException();
    }
    ({String name, Uint8List bytes})? publicKey;
    for (final candidate in ascFiles) {
      final publicFingerprint = _defaultEmailEncryptionExportKeyFingerprint(
        candidate.name,
        normalizedAddress: account.address,
        kind: EmailOpenPgpKeyKind.public,
      );
      if (publicFingerprint == null ||
          publicFingerprint.toLowerCase() !=
              privateKeyValue.fingerprint.toLowerCase()) {
        continue;
      }
      if (publicKey != null) {
        throw const EmailEncryptionExportFailedException();
      }
      if (!_containsAsciiArmoredPublicKey(candidate.bytes)) {
        throw const EmailEncryptionExportFailedException();
      }
      final metadata = await _inspectOpenPgpKeyFile(
        file: candidate.file,
        expectedAddress: account.address,
        expectedKind: DeltaOpenPgpKeyKind.public,
      );
      if (!metadata.hasEncryptionCapability ||
          metadata.fingerprint.toLowerCase() !=
              privateKeyValue.fingerprint.toLowerCase()) {
        throw const EmailEncryptionExportFailedException();
      }
      publicKey = (name: candidate.name, bytes: candidate.bytes);
    }
    final archive = Archive()
      ..addFile(ArchiveFile.bytes(privateKeyValue.name, privateKeyValue.bytes));
    final publicKeyValue = publicKey;
    if (publicKeyValue != null) {
      archive.addFile(
        ArchiveFile.bytes(publicKeyValue.name, publicKeyValue.bytes),
      );
    }
    final archiveBytes = ZipEncoder().encode(archive);
    _validateEmailEncryptionExportArchiveBytes(
      archiveBytes,
      normalizedAddress: account.address,
      failure: const EmailEncryptionExportFailedException(),
    );
    final archivePath = p.join(
      operationDirectory.path,
      _emailEncryptionExportArchiveName,
    );
    final archiveFile = File(archivePath);
    await archiveFile.writeAsBytes(archiveBytes, flush: true);
    if (!await archiveFile.exists()) {
      throw const EmailEncryptionExportFailedException();
    }
    _validateEmailEncryptionExportArchiveBytes(
      await archiveFile.readAsBytes(),
      normalizedAddress: account.address,
      failure: const EmailEncryptionExportFailedException(),
    );
    return archiveFile;
  }

  String? _defaultEmailEncryptionExportKeyFingerprint(
    String basename, {
    required String normalizedAddress,
    required EmailOpenPgpKeyKind kind,
  }) {
    final prefix = switch (kind) {
      EmailOpenPgpKeyKind.public => 'public',
      EmailOpenPgpKeyKind.private => 'private',
    };
    final match = RegExp(
      '^$prefix-key-${RegExp.escape(normalizedAddress)}-default-'
      r'([0-9A-Fa-f]+)\.asc$',
    ).firstMatch(basename);
    return match?.group(1);
  }

  void _validateEmailEncryptionExportArchiveBytes(
    List<int> bytes, {
    required String normalizedAddress,
    required EmailEncryptionKeyException failure,
  }) {
    if (bytes.isEmpty) {
      throw failure;
    }
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      String? privateFingerprint;
      final publicFingerprints = <String>[];
      for (final entry in archive.files) {
        final name = entry.name.trim();
        if (name.isEmpty ||
            p.isAbsolute(name) ||
            p.basename(name) != name ||
            p.normalize(name) != name ||
            entry.isSymbolicLink ||
            !entry.isFile) {
          throw failure;
        }
        final privateEntryFingerprint =
            _defaultEmailEncryptionExportKeyFingerprint(
              name,
              normalizedAddress: normalizedAddress,
              kind: EmailOpenPgpKeyKind.private,
            );
        if (privateEntryFingerprint != null) {
          final entryBytes = entry.readBytes();
          if (entryBytes == null ||
              !_containsAsciiArmoredPrivateKey(entryBytes)) {
            throw failure;
          }
          if (privateFingerprint != null) {
            throw failure;
          }
          privateFingerprint = privateEntryFingerprint;
          continue;
        }
        final publicEntryFingerprint =
            _defaultEmailEncryptionExportKeyFingerprint(
              name,
              normalizedAddress: normalizedAddress,
              kind: EmailOpenPgpKeyKind.public,
            );
        if (publicEntryFingerprint == null) {
          throw failure;
        }
        final entryBytes = entry.readBytes();
        if (entryBytes == null || !_containsAsciiArmoredPublicKey(entryBytes)) {
          throw failure;
        }
        publicFingerprints.add(publicEntryFingerprint);
      }
      final privateFingerprintValue = privateFingerprint;
      if (privateFingerprintValue == null) {
        throw failure;
      }
      for (final fingerprint in publicFingerprints) {
        if (fingerprint.toLowerCase() !=
            privateFingerprintValue.toLowerCase()) {
          throw failure;
        }
      }
      if (publicFingerprints.length > 1) {
        throw failure;
      }
    } on FormatException {
      throw failure;
    }
  }

  Future<void> _cleanupEmailEncryptionOperationDirectory(
    Directory directory,
  ) async {
    try {
      await cleanupEmailEncryptionTempPath(directory.path);
    } on FileSystemException catch (error, stackTrace) {
      _log.warning(
        'Failed to clean email encryption key temp directory.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _applyOpenPgpBaseConfigForAccount(
    _EmailAccountBinding account,
  ) async {
    final supported = await _transport.setCoreConfigIfSupported(
      key: _signUnencryptedConfigKey,
      value: _signUnencryptedDisabledValue,
      accountId: account.deltaAccountId,
    );
    if (!supported) {
      _log.fine(
        'Delta config $_signUnencryptedConfigKey unsupported for '
        'accountId=${account.deltaAccountId} address=${account.address}.',
      );
    }
  }

  Future<void> _applyOpenPgpBaseConfigForActiveAccounts() async {
    final accountIds = await _transport.accountIds();
    final targetAccountIds = accountIds.isEmpty
        ? <int>[_transport.activeAccountId]
        : accountIds;
    for (final accountId in targetAccountIds) {
      final address = _transport.selfJidForAccount(accountId);
      final normalizedAddress = normalizedAddressValue(address);
      if (normalizedAddress == null || normalizedAddress.isEmpty) {
        continue;
      }
      await _applyOpenPgpBaseConfigForAccount(
        _EmailAccountBinding(
          address: normalizedAddress,
          deltaAccountId: accountId,
        ),
      );
    }
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
      await _applyOpenPgpBaseConfigForAccount(account);
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
      await _applyOpenPgpBaseConfigForAccount(account);
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
    int? stopResult() {
      if (requireRecipientMetadata) {
        throw const EmailServiceStoppingException();
      }
      return null;
    }

    if (_blocksRuntimeReentry) {
      return stopResult();
    }
    final Chat resolvedChat = await _trackAppDatabaseOperation(
      () => _storedEmailChatForAccount(
        chat: chat,
        deltaAccountId: deltaAccountId,
      ),
    );
    if (_blocksRuntimeReentry) {
      return stopResult();
    }
    final existingDeltaChatIds = await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      return db.getDeltaChatIdsForAccount(
        chatJid: resolvedChat.jid,
        deltaAccountId: deltaAccountId,
      );
    });
    if (_blocksRuntimeReentry) {
      return stopResult();
    }
    final int? activeDeltaChatId = resolvedChat.deltaChatId;
    final deltaChatIdCandidates = _deltaChatIdCandidates(
      mappedDeltaChatIds: existingDeltaChatIds,
      activeDeltaChatId: activeDeltaChatId,
    );
    final String? recipientAddress = resolvedChat.type == ChatType.chat
        ? _recipientAddressForChat(resolvedChat)
        : null;
    if (recipientAddress != null) {
      final trustedKey = await _trustedContactKeyForNewSend(
        recipientAddress: recipientAddress,
        deltaAccountId: deltaAccountId,
      );
      if (_blocksRuntimeReentry) {
        return stopResult();
      }
      if (trustedKey != null) {
        if (await _isEncryptedSendableDeltaChat(
          chatId: trustedKey.deltaChatId,
          deltaAccountId: deltaAccountId,
        )) {
          if (_blocksRuntimeReentry) {
            return stopResult();
          }
          await _trackAppDatabaseOperation(() async {
            final db = await _databaseBuilder();
            await db.upsertEmailChatAccount(
              chatJid: resolvedChat.jid,
              deltaAccountId: deltaAccountId,
              deltaChatId: trustedKey.deltaChatId,
            );
          });
          return trustedKey.deltaChatId;
        }
        _log.warning(
          'Trusted OpenPGP chat ${trustedKey.deltaChatId} for '
          '$recipientAddress on account $deltaAccountId because it is not '
          'ready for encrypted sends; refusing plaintext fallback.',
        );
        throw const EmailServiceTrustedContactKeyUnavailableException();
      }
      if (deltaChatIdCandidates.isNotEmpty &&
          outgoingEncryptionModeForAddress(
                _transport.selfJidForAccount(deltaAccountId) ?? '',
              ) ==
              EmailOutgoingEncryptionMode.autocryptBeta) {
        for (final candidate in deltaChatIdCandidates) {
          if (await _isEncryptedSendableDeltaChat(
            chatId: candidate,
            deltaAccountId: deltaAccountId,
          )) {
            if (_blocksRuntimeReentry) {
              return stopResult();
            }
            return candidate;
          }
        }
        _log.fine(
          'Ignoring stored Delta chats for $recipientAddress on account '
          '$deltaAccountId because none are ready for encrypted sends.',
        );
      }
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
        if (_blocksRuntimeReentry) {
          return stopResult();
        }
        await _trackAppDatabaseOperation(() async {
          final db = await _databaseBuilder();
          await db.upsertEmailChatAccount(
            chatJid: resolvedChat.jid,
            deltaAccountId: deltaAccountId,
            deltaChatId: chatId,
          );
          await _updateActiveChatDeltaReference(
            chat: resolvedChat,
            deltaAccountId: deltaAccountId,
            deltaChatId: chatId,
            emailAddress: recipientAddress,
          );
        });
        return chatId;
      } on DeltaChatException {
        if (_blocksRuntimeReentry) {
          return stopResult();
        }
        if (requireRecipientMetadata) {
          rethrow;
        }
        if (deltaChatIdCandidates.isNotEmpty) {
          return deltaChatIdCandidates.first;
        }
        if (activeDeltaChatId != null &&
            deltaAccountId == _transport.activeAccountId) {
          if (_blocksRuntimeReentry) {
            return stopResult();
          }
          await _trackAppDatabaseOperation(() async {
            final db = await _databaseBuilder();
            await db.upsertEmailChatAccount(
              chatJid: resolvedChat.jid,
              deltaAccountId: deltaAccountId,
              deltaChatId: activeDeltaChatId,
            );
          });
          return activeDeltaChatId;
        }
        return null;
      }
    }
    if (deltaChatIdCandidates.isNotEmpty) {
      return deltaChatIdCandidates.first;
    }
    if (activeDeltaChatId != null &&
        deltaAccountId == _transport.activeAccountId) {
      if (_blocksRuntimeReentry) {
        return stopResult();
      }
      await _trackAppDatabaseOperation(() async {
        final db = await _databaseBuilder();
        await db.upsertEmailChatAccount(
          chatJid: resolvedChat.jid,
          deltaAccountId: deltaAccountId,
          deltaChatId: activeDeltaChatId,
        );
      });
      return activeDeltaChatId;
    }
    if (requireRecipientMetadata) {
      throw const EmailServiceMissingRecipientMetadataException();
    }
    return null;
  }

  Future<List<int>> _deltaChatIdsForReadState({
    required Chat chat,
    required int deltaAccountId,
  }) async {
    if (_blocksRuntimeReentry) {
      return const <int>[];
    }
    final primaryChatId = await _deltaChatIdForAccount(
      chat: chat,
      deltaAccountId: deltaAccountId,
    );
    if (_blocksRuntimeReentry) {
      return const <int>[];
    }
    final Chat resolvedChat = await _trackAppDatabaseOperation(
      () => _storedEmailChatForAccount(
        chat: chat,
        deltaAccountId: deltaAccountId,
      ),
    );
    if (_blocksRuntimeReentry) {
      return const <int>[];
    }
    final mappedDeltaChatIds = await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      return db.getDeltaChatIdsForAccount(
        chatJid: resolvedChat.jid,
        deltaAccountId: deltaAccountId,
      );
    });
    final activeDeltaChatId = resolvedChat.deltaChatId;
    final activeDeltaChatIdForAccount =
        activeDeltaChatId != null &&
            (mappedDeltaChatIds.contains(activeDeltaChatId) ||
                deltaAccountId == _transport.activeAccountId)
        ? activeDeltaChatId
        : null;
    final ordered = <int>{};
    if (primaryChatId != null) {
      ordered.add(primaryChatId);
    }
    ordered.addAll(
      _deltaChatIdCandidates(
        mappedDeltaChatIds: mappedDeltaChatIds,
        activeDeltaChatId: activeDeltaChatIdForAccount,
      ),
    );
    return ordered.toList(growable: false);
  }

  Future<bool> _isEncryptedSendableDeltaChat({
    required int chatId,
    required int deltaAccountId,
  }) async {
    final capabilities = await _transport.chatSendCapabilities(
      chatId: chatId,
      accountId: deltaAccountId,
    );
    return capabilities.isEncryptedAndSendable;
  }

  List<int> _deltaChatIdCandidates({
    required Iterable<int> mappedDeltaChatIds,
    required int? activeDeltaChatId,
  }) {
    final mapped = mappedDeltaChatIds.toList(growable: false);
    final candidates = <int>[];
    if (activeDeltaChatId != null &&
        (mapped.isEmpty || mapped.contains(activeDeltaChatId))) {
      candidates.add(activeDeltaChatId);
    }
    for (final mappedDeltaChatId in mapped) {
      if (mappedDeltaChatId == activeDeltaChatId) {
        continue;
      }
      candidates.add(mappedDeltaChatId);
    }
    return candidates;
  }

  Future<EmailTrustedContactKey?> _trustedContactKeyForNewSend({
    required String recipientAddress,
    required int deltaAccountId,
  }) async {
    final accountAddress = normalizedAddressValue(
      _transport.selfJidForAccount(deltaAccountId),
    );
    if (accountAddress == null ||
        outgoingEncryptionModeForAddress(accountAddress) !=
            EmailOutgoingEncryptionMode.autocryptBeta) {
      return null;
    }
    final normalizedRecipient = normalizedAddressValue(recipientAddress);
    if (normalizedRecipient == null || normalizedRecipient.isEmpty) {
      return null;
    }
    final data = await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      return db.getEmailTrustedContactKey(
        deltaAccountId: deltaAccountId,
        address: normalizedRecipient,
      );
    });
    return data == null ? null : EmailTrustedContactKey.fromData(data);
  }

  Future<_EmailChatBinding> _bindEmailChat(Chat chat) async {
    await _ensureReady();
    final String scope = _requireActiveScope();
    final _EmailAccountBinding account = await _accountBindingForChat(chat);
    if (_blocksRuntimeReentry) {
      throw const EmailServiceStoppingException();
    }
    final Chat resolvedChat = await _trackAppDatabaseOperation(
      () => _storedEmailChatForAccount(
        chat: chat,
        deltaAccountId: account.deltaAccountId,
      ),
    );
    if (_blocksRuntimeReentry) {
      throw const EmailServiceStoppingException();
    }
    await _updateChatEmailFromAddress(resolvedChat, account.address);
    if (_blocksRuntimeReentry) {
      throw const EmailServiceStoppingException();
    }
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
    if (_nativeCleanupPending) {
      throw const EmailServiceStoppingException();
    }
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
    var noticed = false;
    await _readStateQueue.run(() async {
      await _ensureReady();
      if (_blocksRuntimeReentry) {
        return;
      }
      final account = await _accountBindingForChat(chat);
      final Chat resolvedChat = await _trackAppDatabaseOperation(
        () => _storedEmailChatForAccount(
          chat: chat,
          deltaAccountId: account.deltaAccountId,
        ),
      );
      if (_blocksRuntimeReentry) {
        return;
      }
      final chatIds = await _deltaChatIdsForReadState(
        chat: resolvedChat,
        deltaAccountId: account.deltaAccountId,
      );
      if (chatIds.isEmpty) {
        return;
      }
      for (final chatId in chatIds) {
        final result = await _transport.markNoticedChat(
          chatId,
          accountId: account.deltaAccountId,
        );
        noticed = noticed || result;
      }
    });
    return noticed;
  }

  /// Marks messages as seen, triggering MDN if enabled.
  ///
  /// Call this when messages are displayed to the user.
  Future<bool> markSeenMessages(
    List<Message> messages, {
    required bool sendReadReceipts,
  }) async {
    try {
      var success = true;
      await _readStateQueue.run(() async {
        await _mdnConfigQueue.run(() async {
          await _ensureReady();
          if (_blocksRuntimeReentry) {
            return;
          }
          final candidates = await _trackAppDatabaseOperation(() async {
            final db = await _databaseBuilder();
            return _seenMessageCandidatesForMessages(
              db: db,
              messages: messages,
            );
          });
          final idsByAccount = await _deltaIdsByResolvedAccountForMessages(
            candidates,
          );
          if (idsByAccount.isEmpty) {
            return;
          }
          try {
            await _applyEmailReadReceiptPreference(
              accountIds: idsByAccount.keys,
              enabled: sendReadReceipts,
            );
            for (final entry in idsByAccount.entries) {
              final result = await _transport.markSeenMessages(
                entry.value,
                accountId: entry.key,
              );
              if (!result) {
                success = false;
              }
            }
          } finally {
            await _applyEmailReadReceiptPreference(
              accountIds: idsByAccount.keys,
              enabled: _emailReadReceiptsEnabled,
            );
          }
        });
      });
      return success;
    } on DeltaChatException catch (error, stackTrace) {
      _log.fine('Email unread sync failed.', error, stackTrace);
      return false;
    } on EmailServiceStoppingException catch (error, stackTrace) {
      _log.fine('Email unread sync failed.', error, stackTrace);
      return false;
    } on StateError catch (error, stackTrace) {
      _log.fine('Email unread sync failed.', error, stackTrace);
      return false;
    }
  }

  Future<List<Message>> _seenMessageCandidatesForMessages({
    required XmppDatabase db,
    required List<Message> messages,
  }) async {
    final candidates = <String, Message>{};
    for (final message in messages) {
      final messageCandidates = await _seenMessageCandidatesForRfcGroup(
        db: db,
        message: message,
      );
      for (final candidate in messageCandidates) {
        final deltaId = candidate.deltaMsgId;
        if (deltaId == null) {
          continue;
        }
        candidates['${candidate.deltaAccountId}:$deltaId'] = candidate;
      }
    }
    return candidates.values.toList(growable: false);
  }

  Future<Map<int, List<int>>> _deltaIdsByResolvedAccountForMessages(
    List<Message> messages,
  ) async {
    final idsByAccount = <int, LinkedHashSet<int>>{};
    for (final message in messages) {
      final deltaId = message.deltaMsgId;
      if (deltaId == null) {
        continue;
      }
      final accountId = await _resolveDeltaAccountIdForStoredMessage(message);
      if (accountId == null) {
        continue;
      }
      idsByAccount.putIfAbsent(accountId, LinkedHashSet<int>.new).add(deltaId);
    }
    return {
      for (final entry in idsByAccount.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.toList(),
    };
  }

  Future<List<Message>> _seenMessageCandidatesForRfcGroup({
    required XmppDatabase db,
    required Message message,
  }) async {
    final originId = message.originID?.trim();
    if (originId == null ||
        originId.isEmpty ||
        message.emailRfcGroupKey == null) {
      return [message];
    }
    final siblings = await db.getEmailMessagesByRfcGroup(
      chatJid: message.chatJid,
      originID: originId,
      deltaAccountId: message.deltaAccountId,
    );
    final groupedSiblings = siblings
        .where(message.hasSameEmailRfcGroup)
        .toList(growable: false);
    if (groupedSiblings.isEmpty) {
      return [message];
    }
    return groupedSiblings;
  }

  /// Returns the count of fresh (unread) messages in a chat.
  Future<int> getFreshMessageCount(Chat chat) async {
    await _ensureReady();
    final account = await _accountBindingForChat(chat);
    final chatIds = await _deltaChatIdsForReadState(
      chat: chat,
      deltaAccountId: account.deltaAccountId,
    );
    if (chatIds.isEmpty) {
      return 0;
    }
    var count = 0;
    for (final chatId in chatIds) {
      count += await _transport.getFreshMessageCount(
        chatId,
        accountId: account.deltaAccountId,
      );
    }
    return count;
  }

  /// Returns the oldest fresh (unread) message ID for a chat.
  ///
  /// This consults core fresh IDs so the boundary comes from server state.
  Future<int?> getOldestFreshMessageId(Chat chat) async {
    await _ensureReady();
    final account = await _accountBindingForChat(chat);
    final chatIds = await _deltaChatIdsForReadState(
      chat: chat,
      deltaAccountId: account.deltaAccountId,
    );
    if (chatIds.isEmpty) {
      return null;
    }
    final chatIdSet = chatIds.toSet();
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
      if (message == null || !chatIdSet.contains(message.chatId)) {
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
    await _ensureReady();
    final idsByAccount = await _deltaIdsByResolvedAccountForMessages(
      deltaMessages,
    );
    if (idsByAccount.isEmpty) {
      return false;
    }
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
    final forwardedMessages = messages
        .where(
          (message) =>
              message.deltaMsgId != null &&
              message.deltaAccountId == account.deltaAccountId,
        )
        .toList(growable: false);
    final deltaIds = forwardedMessages
        .map((message) => message.deltaMsgId!)
        .toList(growable: false);
    if (deltaIds.isEmpty) {
      return false;
    }
    final existingMessageIds = await _transport.getChatMessageIds(
      chatId: toChatId,
      accountId: account.deltaAccountId,
    );
    final forwarded = await _transport.forwardMessages(
      messageIds: deltaIds,
      toChatId: toChatId,
      accountId: account.deltaAccountId,
    );
    if (!forwarded) {
      return false;
    }
    await _applyNativeForwardMetadata(
      sourceMessages: forwardedMessages,
      deltaAccountId: account.deltaAccountId,
      deltaChatId: toChatId,
      existingMessageIds: existingMessageIds.toSet(),
    );
    return true;
  }

  Future<void> _applyNativeForwardMetadata({
    required List<Message> sourceMessages,
    required int deltaAccountId,
    required int deltaChatId,
    required Set<int> existingMessageIds,
  }) async {
    if (sourceMessages.isEmpty) {
      return;
    }
    final db = await _databaseBuilder();
    final unresolvedSourceIndexes = <int>{
      for (var index = 0; index < sourceMessages.length; index += 1) index,
    };
    final appliedCandidateIds = <int>{};
    const maxAttempts = 5;
    const retryDelay = Duration(milliseconds: 50);
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      final candidateIds =
          (await _transport.getChatMessageIds(
                chatId: deltaChatId,
                accountId: deltaAccountId,
              ))
              .where(
                (messageId) =>
                    messageId > _deltaMessageIdUnset &&
                    !existingMessageIds.contains(messageId) &&
                    !appliedCandidateIds.contains(messageId),
              )
              .toList()
            ..sort();
      if (candidateIds.isEmpty) {
        if (attempt + 1 < maxAttempts) {
          await Future<void>.delayed(retryDelay);
        }
        continue;
      }
      await _hydrateMessagesOnMain(candidateIds, accountId: deltaAccountId);
      final candidateMessages = <Message>[];
      for (final candidateId in candidateIds) {
        final deltaMessage = await _transport.getMessage(
          candidateId,
          accountId: deltaAccountId,
        );
        if (deltaMessage?.isOutgoing != true) {
          continue;
        }
        final stored = await db.getMessageByDeltaId(
          candidateId,
          deltaAccountId: deltaAccountId,
          deltaChatId: deltaChatId,
        );
        if (stored == null) {
          continue;
        }
        candidateMessages.add(stored);
      }
      if (candidateMessages.isEmpty) {
        if (attempt + 1 < maxAttempts) {
          await Future<void>.delayed(retryDelay);
        }
        continue;
      }
      final matches = _matchNativeForwardSources(
        sourceMessages: sourceMessages,
        unresolvedSourceIndexes: unresolvedSourceIndexes,
        candidateMessages: candidateMessages,
      );
      if (matches.isEmpty) {
        if (attempt + 1 < maxAttempts) {
          await Future<void>.delayed(retryDelay);
        }
        continue;
      }
      for (final entry in matches.entries) {
        final sourceMessage = sourceMessages[entry.key];
        final stored = entry.value;
        final updated = stored.copyWith(
          pseudoMessageData: stored.pseudoMessageDataWithForwarded(
            forwardedFromJid: sourceMessage.senderJid,
            forwardedOriginalSenderLabel: sourceMessage
                .resolveForwardedOriginalSenderLabel(),
          ),
        );
        if (updated != stored) {
          await db.updateMessage(updated);
        }
        final candidateId = stored.deltaMsgId;
        if (candidateId != null) {
          appliedCandidateIds.add(candidateId);
        }
        unresolvedSourceIndexes.remove(entry.key);
      }
      if (unresolvedSourceIndexes.isEmpty) {
        return;
      }
      if (attempt + 1 < maxAttempts) {
        await Future<void>.delayed(retryDelay);
      }
    }
    _log.fine(
      'Native forwarded email metadata was only applied to '
      '${sourceMessages.length - unresolvedSourceIndexes.length}/'
      '${sourceMessages.length} messages for '
      'chatId=$deltaChatId accountId=$deltaAccountId.',
    );
  }

  Map<int, Message> _matchNativeForwardSources({
    required List<Message> sourceMessages,
    required Set<int> unresolvedSourceIndexes,
    required List<Message> candidateMessages,
  }) {
    final candidatesByKey =
        <({String body, bool hasAttachment}), List<Message>>{};
    for (final candidate in candidateMessages) {
      final key = _nativeForwardMatchKey(candidate);
      candidatesByKey.putIfAbsent(key, () => <Message>[]).add(candidate);
    }
    final matches = <int, Message>{};
    final sortedSourceIndexes = unresolvedSourceIndexes.toList()..sort();
    for (final sourceIndex in sortedSourceIndexes) {
      final sourceMessage = sourceMessages[sourceIndex];
      final key = _nativeForwardMatchKey(sourceMessage);
      final candidates = candidatesByKey[key];
      if (candidates == null || candidates.isEmpty) {
        continue;
      }
      matches[sourceIndex] = candidates.removeAt(
        _preferredNativeForwardCandidateIndex(
          sourceMessage: sourceMessage,
          candidateMessages: candidates,
        ),
      );
    }
    return matches;
  }

  int _preferredNativeForwardCandidateIndex({
    required Message sourceMessage,
    required List<Message> candidateMessages,
  }) {
    final sourceSubject = sourceMessage.subject?.trim() ?? '';
    if (sourceSubject.isEmpty) {
      final emptySubjectIndex = candidateMessages.indexWhere(
        (candidate) => (candidate.subject?.trim() ?? '').isEmpty,
      );
      return emptySubjectIndex == -1 ? 0 : emptySubjectIndex;
    }
    final exactSubjectIndex = candidateMessages.indexWhere(
      (candidate) => (candidate.subject?.trim() ?? '') == sourceSubject,
    );
    if (exactSubjectIndex != -1) {
      return exactSubjectIndex;
    }
    final emptySubjectIndex = candidateMessages.indexWhere(
      (candidate) => (candidate.subject?.trim() ?? '').isEmpty,
    );
    return emptySubjectIndex == -1 ? 0 : emptySubjectIndex;
  }

  ({String body, bool hasAttachment}) _nativeForwardMatchKey(Message message) {
    final normalizedBody = message.body?.trim() ?? '';
    final fileMetadataId = message.fileMetadataID?.trim();
    return (
      body: normalizedBody,
      hasAttachment: fileMetadataId != null && fileMetadataId.isNotEmpty,
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
      deltaChatId: chat == null ? null : chatId,
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
          .map(deltaMessageStanzaId)
          .toList(growable: false);
      final stanzaMatches = await db.getMessagesByStanzaIds(stanzaIds);
      final messagesByStanzaId = <String, Message>{
        for (final message in stanzaMatches) message.stanzaID: message,
      };
      for (final deltaId in missingIds) {
        final stanzaId = deltaMessageStanzaId(deltaId);
        final message = messagesByStanzaId[stanzaId];
        if (message != null &&
            _storedDeltaLocatorMatches(
              message,
              _DeltaChatMessageId(
                chatId: chat == null ? null : chatId,
                msgId: deltaId,
                accountId: deltaAccountId,
              ),
            )) {
          messagesByDeltaId[deltaId] = message;
        }
      }
    }

    final remainingIds = deltaIdSet
        .where((deltaId) => !messagesByDeltaId.containsKey(deltaId))
        .toList(growable: false);
    if (remainingIds.isNotEmpty) {
      await _hydrateMessagesOnMain(remainingIds, accountId: deltaAccountId);
      final hydrated = await db.getMessagesByDeltaIds(
        remainingIds,
        deltaAccountId: deltaAccountId,
        deltaChatId: chat == null ? null : chatId,
      );
      for (final message in hydrated) {
        final deltaId = message.deltaMsgId;
        if (deltaId != null) {
          messagesByDeltaId[deltaId] = message;
        }
      }
      final stanzaIds = remainingIds
          .map(deltaMessageStanzaId)
          .toList(growable: false);
      final stanzaMatches = await db.getMessagesByStanzaIds(stanzaIds);
      final messagesByStanzaId = <String, Message>{
        for (final message in stanzaMatches) message.stanzaID: message,
      };
      for (final deltaId in remainingIds) {
        if (messagesByDeltaId.containsKey(deltaId)) {
          continue;
        }
        final stanzaId = deltaMessageStanzaId(deltaId);
        final message = messagesByStanzaId[stanzaId];
        if (message != null &&
            _storedDeltaLocatorMatches(
              message,
              _DeltaChatMessageId(
                chatId: chat == null ? null : chatId,
                msgId: deltaId,
                accountId: deltaAccountId,
              ),
            )) {
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
    final accountId = await _resolveDeltaAccountIdForStoredMessage(message);
    if (accountId == null) {
      return false;
    }
    return _transport.downloadFullMessage(deltaId, accountId: accountId);
  }

  /// Resends failed messages using core retry.
  Future<bool> resendMessages(List<Message> messages) async {
    await _ensureReady();
    final idsByAccount = await _deltaIdsByResolvedAccountForMessages(messages);
    if (idsByAccount.isEmpty) {
      return false;
    }
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
    final mode = _outgoingEncryptionModeForAccount(binding.account);
    final normalizedSubject = _normalizeReplySubject(
      subject: subject,
      quotedSubject: quotedMessage.subject,
      quotedSenderLabel:
          displaySafeAddress(quotedMessage.senderJid) ??
          quotedMessage.senderJid.trim(),
    );
    final payload = _outgoingTextPayload(
      body: body,
      htmlBody: htmlBody,
      subject: null,
    );
    return _sendAndRecordEmail(
      chatId: chatId,
      chat: binding.chat,
      accountId: binding.deltaAccountId,
      operation: 'send reply',
      send: () => _transport.sendTextWithQuote(
        chatId: chatId,
        body: payload.displayText,
        quotedMessageId: quotedMsgId,
        quotedStanzaId: quotedMessage.stanzaID,
        subject: normalizedSubject,
        htmlBody: payload.htmlBody,
        accountId: binding.deltaAccountId,
        forcePlaintext: mode.forcePlaintext,
        skipAutocrypt: mode.skipAutocrypt,
      ),
      body: payload.displayText,
      subject: normalizedSubject,
      quotingStanzaId: quotedMessage.stanzaID,
      htmlBody: payload.htmlBody,
    );
  }

  /// Gets the quoted message info for a message.
  Future<DeltaQuotedMessage?> getQuotedMessage(Message message) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null) return null;
    await _ensureReady();
    final accountId = await _resolveDeltaAccountIdForStoredMessage(message);
    if (accountId == null) {
      return null;
    }
    return _transport.getQuotedMessage(deltaId, accountId: accountId);
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

  Future<String?> getMessageRawHeadersForMessage(Message message) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) return null;
    await _ensureReady();
    final accountId = await _resolveDeltaAccountIdForStoredMessage(message);
    if (accountId == null) {
      return null;
    }
    final headers = await _transport.getMessageMimeHeaders(
      deltaId,
      accountId: accountId,
    );
    return sanitizeRawEmailHeaders(headers);
  }

  /// Gets HTML synthesized from the stored MIME for a message, if available.
  Future<String?> getMessageFullHtml(Message message) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) return null;
    await _ensureReady();
    final accountId = await _resolveDeltaAccountIdForStoredMessage(message);
    if (accountId == null) {
      return null;
    }
    return _transport.getMessageFullHtml(deltaId, accountId: accountId);
  }

  Future<int?> _resolveDeltaAccountIdForStoredMessage(Message message) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) {
      return null;
    }
    final accountIds = await _transport.accountIds();
    final storedAccountId = message.deltaAccountId;
    if (accountIds.contains(storedAccountId)) {
      if (!await _deltaMessageMatchesStoredLocator(
        message: message,
        deltaAccountId: storedAccountId,
      )) {
        return null;
      }
      if (await _deltaMessageHasConflictingStoredOrigin(
        message: message,
        deltaAccountId: storedAccountId,
      )) {
        _log.fine(
          'Stored message ${message.stanzaID} origin does not match '
          'Delta account $storedAccountId.',
        );
        return null;
      }
      return message.deltaAccountId;
    }
    if (accountIds.isEmpty) {
      _log.fine(
        'No Delta accounts available for stored message ${message.stanzaID}.',
      );
      return null;
    }
    final storedOrigin = normalizeEmailMessageId(message.originID);
    if (storedOrigin == null) {
      _log.fine(
        'Stored message ${message.stanzaID} account id $storedAccountId '
        'is unavailable without origin proof.',
      );
      return null;
    }
    final matches = <int>[];
    for (final accountId in accountIds) {
      if (!await _deltaMessageMatchesStoredLocator(
        message: message,
        deltaAccountId: accountId,
      )) {
        continue;
      }
      final candidateOrigin = await _resolveDeltaMessageOriginId(
        deltaMsgId: deltaId,
        deltaAccountId: accountId,
      );
      if (candidateOrigin != storedOrigin) {
        continue;
      }
      matches.add(accountId);
    }
    if (matches.length != 1) {
      _log.fine(
        'Stored message ${message.stanzaID} account id '
        '${message.deltaAccountId} is unavailable and resolved to '
        '${matches.length} candidate accounts.',
      );
      return null;
    }
    final resolvedAccountId = matches.single;
    await _repairStoredMessageDeltaAccountId(
      message: message,
      deltaAccountId: resolvedAccountId,
    );
    return resolvedAccountId;
  }

  Future<bool> _deltaMessageHasConflictingStoredOrigin({
    required Message message,
    required int deltaAccountId,
  }) async {
    final storedOrigin = normalizeEmailMessageId(message.originID);
    if (storedOrigin == null) {
      return false;
    }
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) {
      return false;
    }
    final candidateOrigin = await _resolveDeltaMessageOriginId(
      deltaMsgId: deltaId,
      deltaAccountId: deltaAccountId,
    );
    return candidateOrigin != null && candidateOrigin != storedOrigin;
  }

  Future<bool> _deltaMessageMatchesStoredLocator({
    required Message message,
    required int deltaAccountId,
  }) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) {
      return false;
    }
    DeltaMessage? deltaMessage;
    try {
      deltaMessage = await _transport.getMessage(
        deltaId,
        accountId: deltaAccountId,
      );
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      _log.fine('Failed to validate Delta message locator.', error, stackTrace);
      return false;
    } on DeltaSafeException catch (error, stackTrace) {
      _log.fine('Failed to validate Delta message locator.', error, stackTrace);
      return false;
    } on TimeoutException catch (error, stackTrace) {
      _log.fine(
        'Timed out validating Delta message locator.',
        error,
        stackTrace,
      );
      return false;
    }
    if (deltaMessage == null) {
      return false;
    }
    final deltaChatId = message.deltaChatId;
    if (deltaChatId != null && deltaMessage.chatId != deltaChatId) {
      return false;
    }
    return true;
  }

  Future<String?> _resolveDeltaMessageOriginId({
    required int deltaMsgId,
    required int deltaAccountId,
  }) async {
    final rfc724Mid = normalizeEmailMessageId(
      await _readDeltaMessageOriginData(
        deltaMsgId: deltaMsgId,
        deltaAccountId: deltaAccountId,
        source: 'RFC724 Message-ID',
        read: () => _transport.getMessageRfc724Mid(
          deltaMsgId,
          accountId: deltaAccountId,
        ),
      ),
    );
    if (rfc724Mid != null) {
      return rfc724Mid;
    }
    final infoMessageId = parseDeltaMessageInfoMessageId(
      await _readDeltaMessageOriginData(
        deltaMsgId: deltaMsgId,
        deltaAccountId: deltaAccountId,
        source: 'message info',
        read: () =>
            _transport.getMessageInfo(deltaMsgId, accountId: deltaAccountId),
      ),
    );
    if (infoMessageId != null) {
      return infoMessageId;
    }
    return parseEmailMessageId(
      await _readDeltaMessageOriginData(
        deltaMsgId: deltaMsgId,
        deltaAccountId: deltaAccountId,
        source: 'MIME headers',
        read: () => _transport.getMessageMimeHeaders(
          deltaMsgId,
          accountId: deltaAccountId,
        ),
      ),
    );
  }

  Future<String?> _readDeltaMessageOriginData({
    required int deltaMsgId,
    required int deltaAccountId,
    required String source,
    required Future<String?> Function() read,
  }) async {
    try {
      return await read();
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      _log.fine(
        'Failed to load Delta $source for message $deltaMsgId '
        'on account $deltaAccountId.',
        error,
        stackTrace,
      );
      return null;
    } on DeltaSafeException catch (error, stackTrace) {
      _log.fine(
        'Failed to load Delta $source for message $deltaMsgId '
        'on account $deltaAccountId.',
        error,
        stackTrace,
      );
      return null;
    } on TimeoutException catch (error, stackTrace) {
      _log.fine(
        'Timed out loading Delta $source for message $deltaMsgId '
        'on account $deltaAccountId.',
        error,
        stackTrace,
      );
      return null;
    }
  }

  Future<void> _repairStoredMessageDeltaAccountId({
    required Message message,
    required int deltaAccountId,
  }) async {
    if (message.id == null || message.deltaAccountId == deltaAccountId) {
      return;
    }
    await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      await db.updateMessage(message.copyWith(deltaAccountId: deltaAccountId));
    });
  }

  /// Gets body-only content parsed from the stored RFC822 MIME, if available.
  Future<DeltaMessageRfc822Body?> getMessageRfc822Body(Message message) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) return null;
    await _ensureReady();
    final accountId = await _resolveDeltaAccountIdForStoredMessage(message);
    if (accountId == null) {
      return null;
    }
    return _transport.getMessageRfc822Body(deltaId, accountId: accountId);
  }

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

  Future<void> deleteContactsByNativeIds(Iterable<String> nativeIds) async {
    await _ensureReady();
    for (final nativeId in nativeIds) {
      final contactId = _parseDeltaContactId(nativeId);
      if (contactId == null) {
        continue;
      }
      await _guardDeltaOperation(
        operation: 'delete email contact',
        body: () => _transport.deleteContact(contactId),
      );
    }
    await syncContactsFromCore();
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

int? _parseDeltaContactId(String nativeId) {
  const prefix = 'delta_contact_';
  if (!nativeId.startsWith(prefix)) {
    return null;
  }
  return int.tryParse(nativeId.substring(prefix.length));
}

Map<String, bool> _normalizedEncryptionBetaMap(Map<String, bool> values) {
  final normalized = <String, bool>{};
  for (final entry in values.entries) {
    if (!entry.value) {
      continue;
    }
    final address = normalizedAddressValue(entry.key);
    if (address == null || address.isEmpty || !address.isValidEmailAddress) {
      continue;
    }
    normalized[address] = true;
  }
  return Map<String, bool>.unmodifiable(normalized);
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

  void clearRuntime({bool clearEphemeralState = false}) {
    databasePrefix = null;
    databasePassphrase = null;
    final activeScope = activeScopeState;
    if (activeScope != null) {
      activeScope.activeAccount = null;
      activeScope.bootstrapFuture = null;
      activeScope.bootstrapOperationId = 0;
    }
    if (clearEphemeralState) {
      for (final scopeState in _scopes.values) {
        scopeState.isEphemerallyProvisioned = false;
        scopeState.hasEphemeralConnectionOverride = false;
      }
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
  Timer? _notificationFlushTimer;

  void enqueue({
    required int chatId,
    required int msgId,
    required int accountId,
    required Duration flushDelay,
    required void Function() onFlush,
  }) {
    _pendingNotifications.add(
      _PendingNotification(chatId: chatId, msgId: msgId, accountId: accountId),
    );
    _notificationFlushTimer ??= Timer(flushDelay, () {
      _notificationFlushTimer = null;
      onFlush();
    });
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

  void clear() {
    _notificationFlushTimer?.cancel();
    _notificationFlushTimer = null;
    _pendingNotifications.clear();
  }
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

  bool get ignoreChannelMute =>
      chat?.effectiveNotificationBehavior?.isAlwaysNotify ?? false;
}

final class _EmailNotificationDelivery {
  const _EmailNotificationDelivery({
    required this.target,
    required this.body,
    required this.threadKey,
    required this.showPreview,
  });

  final _EmailNotificationTarget target;
  final String body;
  final String threadKey;
  final bool showPreview;
}
