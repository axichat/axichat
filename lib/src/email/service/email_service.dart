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
import 'package:axichat/src/common/foreground_task_messages.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:axichat/src/common/synthetic_reply.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/demo/demo_chats.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:crypto/crypto.dart' as crypto;
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
  mailPushHint,
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

enum _EmailCatchUpReason {
  mailPushHint,
  homeUnreadRefresh,
  homeHistoryRefresh,
  syncInboxAndSent,
  periodicIdleTick,
  backgroundFetchDone,
  incomingMsgBunch,
  foregroundResume,
  channelOverflow,
  reconnectCatchUp,
}

enum _EmailCatchUpQueue { none, imapSync, channelOverflow, reconnectCatchUp }

enum _EmailCatchUpFetchDecision { none, skippedIoRunning, attempted }

enum _EmailCatchUpProjectDecision {
  none,
  skippedFetchFailed,
  requested,
  incremental,
  incrementalWithSnapshotFallback,
}

final class _EmailCatchUpResult {
  const _EmailCatchUpResult({
    required this.fetchDecision,
    required this.projectDecision,
    this.fetched = false,
    this.projected = false,
    this.projectedMessageCount = 0,
    this.projectedFreshIdCount = 0,
    this.projectedAffectedChatCount = 0,
    this.networkNotified = false,
  });

  final _EmailCatchUpFetchDecision fetchDecision;
  final _EmailCatchUpProjectDecision projectDecision;
  final bool fetched;
  final bool projected;
  final int projectedMessageCount;
  final int projectedFreshIdCount;
  final int projectedAffectedChatCount;
  final bool networkNotified;

  static const skipped = _EmailCatchUpResult(
    fetchDecision: _EmailCatchUpFetchDecision.none,
    projectDecision: _EmailCatchUpProjectDecision.none,
  );
}

final class _EmailFreshProjectionResult {
  const _EmailFreshProjectionResult({
    this.freshIdCount = 0,
    this.syncedMessageCount = 0,
    this.affectedChatCount = 0,
  });

  final int freshIdCount;
  final int syncedMessageCount;
  final int affectedChatCount;

  bool get hadFreshIds => freshIdCount > 0;

  bool get projectedLocalState =>
      syncedMessageCount > 0 || affectedChatCount > 0;
}

enum EmailChatNoticeSyncStatus { freshCleared, partial, unresolved, failed }

final class EmailChatNoticeSyncResult {
  const EmailChatNoticeSyncResult({
    required this.status,
    this.deltaAccountId,
    this.chatIds = const <int>[],
    this.noticeRequestCount = 0,
    this.noticeAcceptedCount = 0,
    this.coreNoticeRequested = false,
    this.coreNoticeAccepted = false,
  });

  final EmailChatNoticeSyncStatus status;
  final int? deltaAccountId;
  final List<int> chatIds;
  final int noticeRequestCount;
  final int noticeAcceptedCount;
  final bool coreNoticeRequested;
  final bool coreNoticeAccepted;

  bool get terminalSuccess => status == EmailChatNoticeSyncStatus.freshCleared;
}

enum EmailMessageSeenSyncStatus { sent, pending, unresolved, failed }

final class EmailMessageSeenSyncResult {
  const EmailMessageSeenSyncResult({
    required this.status,
    this.submittedCount = 0,
    this.verifiedSeenCount = 0,
    this.unresolvedCount = 0,
    this.transportAcceptedCount = 0,
  });

  final EmailMessageSeenSyncStatus status;
  final int submittedCount;
  final int verifiedSeenCount;
  final int unresolvedCount;
  final int transportAcceptedCount;

  bool get terminalSuccess => status == EmailMessageSeenSyncStatus.sent;
}

final class EmailContentJobKey {
  const EmailContentJobKey({
    required this.deltaAccountId,
    required this.deltaChatId,
    required this.deltaMsgId,
  });

  final int deltaAccountId;
  final int deltaChatId;
  final int deltaMsgId;

  @override
  bool operator ==(Object other) {
    return other is EmailContentJobKey &&
        other.deltaAccountId == deltaAccountId &&
        other.deltaChatId == deltaChatId &&
        other.deltaMsgId == deltaMsgId;
  }

  @override
  int get hashCode => Object.hash(deltaAccountId, deltaChatId, deltaMsgId);

  @override
  String toString() => '$deltaAccountId:$deltaChatId:$deltaMsgId';
}

enum EmailContentPreparationPriority { visible, manual }

final class EmailContentPreparationSnapshot {
  const EmailContentPreparationSnapshot({
    required this.activeBodyHydrationKeys,
    required this.activeHtmlDerivationKeys,
    Set<EmailContentJobKey>? activeLoadingIndicatorKeys,
    required this.revision,
  }) : activeLoadingIndicatorKeys =
           activeLoadingIndicatorKeys ?? activeBodyHydrationKeys;

  static const empty = EmailContentPreparationSnapshot(
    activeBodyHydrationKeys: <EmailContentJobKey>{},
    activeHtmlDerivationKeys: <EmailContentJobKey>{},
    activeLoadingIndicatorKeys: <EmailContentJobKey>{},
    revision: 0,
  );

  final Set<EmailContentJobKey> activeBodyHydrationKeys;
  final Set<EmailContentJobKey> activeHtmlDerivationKeys;
  final Set<EmailContentJobKey> activeLoadingIndicatorKeys;
  final int revision;
}

final class EmailOriginalContentSnapshot {
  const EmailOriginalContentSnapshot({
    required this.htmlByKey,
    required this.loadingKeys,
    required this.unavailableKeys,
    required this.revision,
  });

  static const empty = EmailOriginalContentSnapshot(
    htmlByKey: <EmailContentJobKey, String>{},
    loadingKeys: <EmailContentJobKey>{},
    unavailableKeys: <EmailContentJobKey>{},
    revision: 0,
  );

  final Map<EmailContentJobKey, String> htmlByKey;
  final Set<EmailContentJobKey> loadingKeys;
  final Set<EmailContentJobKey> unavailableKeys;
  final int revision;
}

final class _EmailContentBodyTask {
  _EmailContentBodyTask({
    required this.key,
    required this.message,
    required this.queuedAt,
    required this.generation,
  });

  final EmailContentJobKey key;
  Message message;
  final DateTime queuedAt;
  final int generation;
  bool started = false;
  bool loadingIndicatorVisible = false;
}

final class _EmailContentHtmlDerivationTask {
  _EmailContentHtmlDerivationTask({
    required this.digest,
    required this.normalizedHtml,
    required this.queuedAt,
    required this.generation,
  });

  final String digest;
  final String normalizedHtml;
  final DateTime queuedAt;
  final int generation;
  final Map<EmailContentJobKey, Message> messagesByKey =
      <EmailContentJobKey, Message>{};
  bool started = false;
}

final class _EmailContentRetryDeferral {
  const _EmailContentRetryDeferral({
    required this.fingerprint,
    required this.failureCount,
    required this.nextRetryAt,
  });

  final String fingerprint;
  final int failureCount;
  final DateTime nextRetryAt;
}

final class EmailFullMessageHydrationResult {
  const EmailFullMessageHydrationResult({
    required this.accepted,
    required this.html,
    required this.settled,
    required this.timedOut,
    required this.bodyAvailable,
  });

  final bool accepted;
  final String? html;
  final bool settled;
  final bool timedOut;
  final bool bodyAvailable;
}

enum _ExistingHistoryImportProjectionState {
  idle,
  importing,
  finalizingProjection,
}

final class _EmailChatNoticeSyncKey {
  const _EmailChatNoticeSyncKey({
    required this.credentialScope,
    required this.chatJid,
    required this.deltaChatId,
    required this.emailFromAddress,
    required this.emailAddress,
    required this.contactJid,
  });

  factory _EmailChatNoticeSyncKey.from({
    required String? credentialScope,
    required Chat chat,
  }) {
    return _EmailChatNoticeSyncKey(
      credentialScope: credentialScope ?? '',
      chatJid: chat.jid.trim(),
      deltaChatId: chat.deltaChatId,
      emailFromAddress: chat.emailFromAddress?.trim() ?? '',
      emailAddress: chat.emailAddress?.trim() ?? '',
      contactJid: chat.contactJid?.trim() ?? '',
    );
  }

  final String credentialScope;
  final String chatJid;
  final int? deltaChatId;
  final String emailFromAddress;
  final String emailAddress;
  final String contactJid;

  @override
  bool operator ==(Object other) {
    return other is _EmailChatNoticeSyncKey &&
        other.credentialScope == credentialScope &&
        other.chatJid == chatJid &&
        other.deltaChatId == deltaChatId &&
        other.emailFromAddress == emailFromAddress &&
        other.emailAddress == emailAddress &&
        other.contactJid == contactJid;
  }

  @override
  int get hashCode {
    return Object.hash(
      credentialScope,
      chatJid,
      deltaChatId,
      emailFromAddress,
      emailAddress,
      contactJid,
    );
  }
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
  Future<DeltaMessageStatus?> getMessageStatus(int messageId) =>
      _transport.getMessageStatus(messageId, accountId: _accountId);

  @override
  Future<List<DeltaMessage>> getMessages(List<int> messageIds) =>
      _transport.getMessages(messageIds, accountId: _accountId);

  @override
  Future<List<DeltaMessageStatus>> getMessageStatuses(List<int> messageIds) =>
      _transport.getMessageStatuses(messageIds, accountId: _accountId);

  @override
  Future<List<int>> getFreshMessageIds() =>
      _transport.getFreshMessageIds(accountId: _accountId);

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
  Future<DeltaQuotedMessage?> getQuotedMessage(int messageId) =>
      _transport.getQuotedMessage(messageId, accountId: _accountId);

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

final class EmailServiceExistingHistoryImportUnsupportedException
    extends EmailServiceException {
  const EmailServiceExistingHistoryImportUnsupportedException();
}

final class EmailServiceExistingHistoryImportFetchFailedException
    extends EmailServiceException {
  const EmailServiceExistingHistoryImportFetchFailedException();
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

final class _ResolvedFanOutTarget {
  const _ResolvedFanOutTarget({required this.intent, required this.chat});

  final EmailRecipientIntent intent;
  final Chat? chat;

  FanOutRecipientTargetSnapshot get requestedTarget =>
      FanOutRecipientTargetSnapshot.fromIntent(intent);
}

class EmailService {
  static final Logger _profileTraceLog = Logger(
    SafeLogging.profileTraceLoggerName,
  );

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
  static const Duration _connectivityHealthyReadReuseWindow = Duration(
    seconds: 1,
  );
  static const Duration _chatlistRefreshRecentSuppressionWindow = Duration(
    milliseconds: 500,
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
  static const String _downloadLimitConfigKey = 'download_limit';
  static const int _downloadLimitBytes = 163840;
  static const String _fetchExistingMsgsConfigKey = 'fetch_existing_msgs';
  static const String _fetchedExistingMsgsConfigKey = 'fetched_existing_msgs';
  static const String _fetchExistingMsgsEnabledValue = '1';
  static const String _fetchExistingMsgsDisabledValue = '0';
  static const Duration _existingHistoryImportTimeout = Duration(hours: 2);
  static const int _existingHistoryImportDeltaIdPageSize = 500;
  static const int _existingHistoryImportProjectionBatchSize = 15;
  static const Duration _existingHistoryImportProjectionYieldDelay = Duration(
    milliseconds: 16,
  );
  static const int _existingHistoryImportProjectionStartDeltaMsgId = 0;
  static const String _existingHistoryImportJournalStatusImporting =
      'importing';
  static const String _existingHistoryImportFailureWarningMarker =
      'Failed to fetch existing messages';
  static const String _existingHistoryImportFailureWarningContext =
      'could not fetch existing messages';
  static const String _emailHistoryImportPromptStatusAttemptFinished =
      'attempt_finished';
  static const String _emailHistoryImportPromptStatusCompleted = 'completed';
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
  static const Duration _pendingEmailBodyDownloadPollInterval = Duration(
    milliseconds: 250,
  );
  static const Duration _pendingEmailBodyDownloadTimeout = Duration(
    seconds: 30,
  );
  static const int _pendingEmailBodyDownloadConcurrentOps = 6;
  static const int _emailHtmlDerivationConcurrentOps = 1;
  static const Duration _emailHtmlDerivationTimeout = Duration(seconds: 30);
  static const Duration _emailContentRetrySecondDelay = Duration(minutes: 2);
  static const Duration _emailContentRetryMaxDelay = Duration(minutes: 5);
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
  static const NotificationPayloadCodec _notificationPayloadCodec =
      NotificationPayloadCodec();

  static const String _deltaQueueOperationNameProcessDeltaEvent =
      'EmailService.processDeltaEvent';
  static const String _deltaQueueOperationNameFlushQueuedNotifications =
      'EmailService.flushQueuedNotifications';
  static const String _deltaQueueOperationNameSyncContactsFromCore =
      'EmailService.syncContactsFromCore';
  static const String _deltaQueueOperationNameRuntimeRestartRecovery =
      'EmailService.runtimeRestartRecovery';

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
    Stream<Object?>? mailPushHints,
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
        () => EmailDeltaTransport(
          databaseBuilder: _databaseBuilder,
          databaseOperationTracker: _trackAppDatabaseOperation,
          logger: _log,
          localizationsProvider: () => _l10n,
          xmppSelfJidProvider: _xmppSelfJidProvider,
          shouldDeferProjectionForEvent:
              _shouldDeferExistingHistoryImportDeltaProjection,
          onProjectionDeferred: _markExistingHistoryImportProjectionDeferred,
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
    _mailPushHintSubscription = mailPushHints?.listen((_) {
      fireAndForget(
        _handleMailPushHint,
        operationName: 'EmailService.mailPushHint',
      );
    });
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
  StreamSubscription<Object?>? _mailPushHintSubscription;
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
  DateTime? _lastHealthyConnectivityReadAt;
  int _consecutiveConnectingSamples = 0;
  DateTime? _lastConnectivityDetailLoggedAt;
  Future<int?>? _connectivityRefreshTask;
  int _suppressedConnectivityChangedEvents = 0;
  final EmailAsyncQueue _channelOverflowRecoveryQueue = EmailAsyncQueue();
  EmailImapCapabilities _imapCapabilities = const EmailImapCapabilities(
    idleSupported: false,
    connectionLimit: _imapConnectionLimitSingle,
    idleCutoff: _imapIdleKeepaliveInterval,
  );
  DateTime? _imapCapabilitiesCheckedAt;
  bool _imapCapabilitiesResolved = false;

  bool _deltaAccountRepairCompleted = false;
  String? _provisioningBlockedScope;

  Future<bool>? _backgroundFetchInFlight;
  Future<void>? _existingHistoryImportTask;
  _ExistingHistoryImportProjectionState _existingHistoryImportProjectionState =
      _ExistingHistoryImportProjectionState.idle;
  bool _existingHistoryImportDeferredProjection = false;
  bool _existingHistoryImportDeferredContactsSync = false;
  final List<String> _existingHistoryImportWarnings = <String>[];
  final Set<String> _emailHistoryImportPromptSnoozedScopes = <String>{};
  final Set<String> _deltaProjectionCursorRepairCompletedKeys = <String>{};

  String get _emailHistoryImportPromptId => 'email_history_import_v1';

  String _deltaProjectionCursorPromptId(int accountId) =>
      'email_delta_projection_cursor_v1_$accountId';

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
  DateTime? _lastChatlistRefreshCompletedAt;
  int? _lastChatlistRefreshCompletedAccountId;
  final _contentPreparationController =
      StreamController<EmailContentPreparationSnapshot>.broadcast(sync: true);
  EmailContentPreparationSnapshot _contentPreparationSnapshot =
      EmailContentPreparationSnapshot.empty;
  int _contentPreparationRevision = 0;
  int _contentPreparationGeneration = 0;
  final _originalContentController =
      StreamController<EmailOriginalContentSnapshot>.broadcast(sync: true);
  EmailOriginalContentSnapshot _originalContentSnapshot =
      EmailOriginalContentSnapshot.empty;
  int _originalContentRevision = 0;
  int _originalContentGeneration = 0;
  final Map<EmailContentJobKey, String> _emailOriginalHtmlByKey =
      <EmailContentJobKey, String>{};
  final Set<EmailContentJobKey> _emailOriginalLoadingKeys =
      <EmailContentJobKey>{};
  final Set<EmailContentJobKey> _emailOriginalUnavailableKeys =
      <EmailContentJobKey>{};
  final Map<String, Map<EmailContentJobKey, Message>>
  _visibleEmailContentMessagesByChatJid =
      <String, Map<EmailContentJobKey, Message>>{};
  final Queue<_EmailContentBodyTask> _emailContentBodyPendingTasks =
      Queue<_EmailContentBodyTask>();
  final Map<EmailContentJobKey, _EmailContentBodyTask>
  _emailContentBodyTasksByKey = <EmailContentJobKey, _EmailContentBodyTask>{};
  int _emailContentBodyActiveCount = 0;
  final Queue<_EmailContentHtmlDerivationTask>
  _emailContentHtmlDerivationPendingTasks =
      Queue<_EmailContentHtmlDerivationTask>();
  final Map<String, _EmailContentHtmlDerivationTask>
  _emailContentHtmlDerivationTasksByDigest =
      <String, _EmailContentHtmlDerivationTask>{};
  int _emailContentHtmlDerivationActiveCount = 0;
  final Map<EmailContentJobKey, List<Completer<bool>>>
  _emailContentPreparationWaiters =
      <EmailContentJobKey, List<Completer<bool>>>{};
  final Map<EmailContentJobKey, _EmailContentRetryDeferral>
  _emailContentRetryDeferrals =
      <EmailContentJobKey, _EmailContentRetryDeferral>{};
  Timer? _emailContentRetryTimer;
  final EmailAsyncQueue _readStateQueue = EmailAsyncQueue();
  final Map<_EmailChatNoticeSyncKey, Future<EmailChatNoticeSyncResult>>
  _noticeSyncInFlight =
      <_EmailChatNoticeSyncKey, Future<EmailChatNoticeSyncResult>>{};
  final EmailAsyncQueue _mdnConfigQueue = EmailAsyncQueue();
  _EmailNetworkTransition? _pendingNetworkTransition;
  _EmailNetworkTransition? _activeNetworkTransition;
  final Set<Future<void>> _activeAppDatabaseOperations = <Future<void>>{};
  int _profileTraceSequence = 0;

  void updateEndpointConfig(EndpointConfig config) {
    _endpointConfig = config;
    if (!config.smtpEnabled) {
      _setEmailHistoryImportPromptStatus(
        EmailHistoryImportPromptStatus.hidden,
        source: _EmailSyncSource.unknown,
      );
    }
  }

  String _nextTraceId(String operation) {
    _profileTraceSequence += 1;
    return '$operation#$_profileTraceSequence';
  }

  void _traceEmailOperation(
    String operation,
    String phase, {
    String? id,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {}

  void _traceExistingHistoryImport(
    String phase, {
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    if (!kProfileMode) {
      return;
    }
    final buffer = StringBuffer('email.historyImport $phase');
    for (final entry in fields.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      buffer
        ..write(' ')
        ..write(entry.key)
        ..write('=')
        ..write(value);
    }
    _profileTraceLog.info(buffer.toString());
  }

  String _traceCaller(StackTrace stackTrace) {
    for (final line in stackTrace.toString().split('\n').skip(1)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.contains('email_service.dart')) {
        continue;
      }
      return trimmed;
    }
    return 'unknown';
  }

  Future<void> _handleMailPushHint() async {
    final id = _nextTraceId('email.mailPush');
    final stopwatch = Stopwatch()..start();
    _traceEmailOperation(
      'email.mailPush',
      'start',
      id: id,
      fields: <String, Object?>{
        'smtpEnabled': _endpointConfig.smtpEnabled,
        'runtime': _runtimePhase.name,
        'hasSession': hasActiveSession,
        'ioRunning': _transport.isIoRunning,
        'caller': _traceCaller(StackTrace.current),
      },
    );
    if (!_endpointConfig.smtpEnabled) {
      _traceEmailOperation(
        'email.mailPush',
        'skip',
        id: id,
        fields: <String, Object?>{
          'reason': 'smtpDisabled',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return;
    }
    try {
      await _refreshForMailPushHint(id);
      _traceEmailOperation(
        'email.mailPush',
        'end',
        id: id,
        fields: <String, Object?>{
          'result': 'completed',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
    } on Exception catch (error, stackTrace) {
      _traceEmailOperation(
        'email.mailPush',
        'error',
        id: id,
        fields: <String, Object?>{
          'result': error.runtimeType,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      _log.warning('Email mail-push refresh failed.', error, stackTrace);
    }
  }

  Future<void> _refreshForMailPushHint(String traceId) async {
    await _requestEmailCatchUp(
      _EmailCatchUpReason.mailPushHint,
      parentTraceId: traceId,
    );
  }

  Future<_EmailCatchUpResult> _requestEmailCatchUp(
    _EmailCatchUpReason reason, {
    String? parentTraceId,
    bool Function()? isStillRelevant,
  }) async {
    final queue = _catchUpQueueFor(reason);
    switch (queue) {
      case _EmailCatchUpQueue.none:
        return _runEmailCatchUp(
          reason,
          parentTraceId: parentTraceId,
          isStillRelevant: isStillRelevant,
        );
      case _EmailCatchUpQueue.imapSync:
        var result = _EmailCatchUpResult.skipped;
        await _imapSyncQueue.run(() async {
          result = await _runEmailCatchUp(
            reason,
            parentTraceId: parentTraceId,
            isStillRelevant: isStillRelevant,
          );
        });
        return result;
      case _EmailCatchUpQueue.channelOverflow:
        var result = _EmailCatchUpResult.skipped;
        await _channelOverflowRecoveryQueue.run(() async {
          result = await _runEmailCatchUp(
            reason,
            parentTraceId: parentTraceId,
            isStillRelevant: isStillRelevant,
          );
        });
        return result;
      case _EmailCatchUpQueue.reconnectCatchUp:
        var result = _EmailCatchUpResult.skipped;
        await _reconnectCatchUpQueue.run(() async {
          result = await _runEmailCatchUp(
            reason,
            parentTraceId: parentTraceId,
            isStillRelevant: isStillRelevant,
          );
        });
        return result;
    }
  }

  Future<_EmailCatchUpResult> _runEmailCatchUp(
    _EmailCatchUpReason reason, {
    String? parentTraceId,
    bool Function()? isStillRelevant,
  }) async {
    final traceId = _nextTraceId('email.catchUp');
    final stopwatch = Stopwatch()..start();
    final fetchTimeout = _catchUpFetchTimeout(reason);
    final shouldFetch = fetchTimeout != null;
    final ioRunningAtStart = _transport.isIoRunning;
    final queue = _catchUpQueueFor(reason);
    _traceEmailOperation(
      'email.catchUp',
      'start',
      id: traceId,
      fields: <String, Object?>{
        'reason': reason.name,
        'parent': parentTraceId,
        'queue': queue.name,
        'runtime': _runtimePhase.name,
        'syncStatus': _syncState.status.name,
        'ioRunning': ioRunningAtStart,
        'fetchPolicy': shouldFetch ? 'ifIdle' : 'none',
        'projectPolicy': _catchUpProjectPolicyLabel(reason),
        'fetchInFlight': _backgroundFetchInFlight != null,
        'projectionInFlight': _chatlistRefreshTask != null,
        'connectivityInFlight': _connectivityRefreshTask != null,
      },
    );
    if (!await _ensureBackgroundSyncReady()) {
      if (reason == _EmailCatchUpReason.incomingMsgBunch) {
        await _flushQueuedNotifications();
      }
      _traceEmailOperation(
        'email.catchUp',
        'skip',
        id: traceId,
        fields: <String, Object?>{
          'reason': reason.name,
          'result': 'backgroundSyncNotReady',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return _EmailCatchUpResult.skipped;
    }
    if (isStillRelevant?.call() == false) {
      _traceEmailOperation(
        'email.catchUp',
        'skip',
        id: traceId,
        fields: <String, Object?>{
          'reason': reason.name,
          'result': 'notRelevant',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return _EmailCatchUpResult.skipped;
    }

    var ioRunningForFetch = _transport.isIoRunning;
    if (reason == _EmailCatchUpReason.channelOverflow) {
      _updateSyncState(
        EmailSyncState.recovering(_l10n.emailSyncMessageRefreshing),
        source: _EmailSyncSource.channelOverflow,
      );
    }
    if (_shouldRefreshImapCapabilitiesForCatchUp(reason)) {
      await _refreshImapCapabilities();
      if (isStillRelevant?.call() == false) {
        _traceEmailOperation(
          'email.catchUp',
          'skip',
          id: traceId,
          fields: <String, Object?>{
            'reason': reason.name,
            'result': 'notRelevantAfterCapabilities',
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
        return _EmailCatchUpResult.skipped;
      }
      ioRunningForFetch = _transport.isIoRunning;
    }

    var fetchDecision = _EmailCatchUpFetchDecision.none;
    var fetched = false;
    if (_shouldPrepareDeltaProjectionCursorBeforeFetch(reason)) {
      await _ensureDeltaProjectionCursorsForCatchUp();
    }
    if (shouldFetch) {
      if (ioRunningForFetch) {
        fetchDecision = _EmailCatchUpFetchDecision.skippedIoRunning;
      } else {
        fetchDecision = _EmailCatchUpFetchDecision.attempted;
        fetched = await performBackgroundFetch(timeout: fetchTimeout);
      }
    }
    final ioRunningAfterFetch = _transport.isIoRunning;
    if (isStillRelevant?.call() == false) {
      _traceEmailOperation(
        'email.catchUp',
        'skip',
        id: traceId,
        fields: <String, Object?>{
          'reason': reason.name,
          'result': 'notRelevantAfterFetch',
          'fetchDecision': fetchDecision.name,
          'fetched': fetched,
          'ioRunningAfterFetch': ioRunningAfterFetch,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return _EmailCatchUpResult(
        fetchDecision: fetchDecision,
        projectDecision: _EmailCatchUpProjectDecision.none,
        fetched: fetched,
      );
    }

    var networkNotified = false;
    if (_shouldNotifyNetworkForCatchUp(
      reason: reason,
      fetched: fetched,
      ioRunning: ioRunningAfterFetch,
    )) {
      await _notifyTransportNetworkAvailable();
      networkNotified = true;
    }

    if (!await _ensureBackgroundSyncReady()) {
      _traceEmailOperation(
        'email.catchUp',
        'skip',
        id: traceId,
        fields: <String, Object?>{
          'reason': reason.name,
          'result': 'backgroundSyncStoppedAfterFetch',
          'fetchDecision': fetchDecision.name,
          'fetched': fetched,
          'ioRunningAfterFetch': ioRunningAfterFetch,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return _EmailCatchUpResult(
        fetchDecision: fetchDecision,
        projectDecision: _EmailCatchUpProjectDecision.none,
        fetched: fetched,
        networkNotified: networkNotified,
      );
    }
    final ioRunningForProjection = _transport.isIoRunning;

    if (_shouldDeferExistingHistoryImportCatchUpProjection(reason)) {
      _existingHistoryImportDeferredProjection = true;
      return _EmailCatchUpResult(
        fetchDecision: fetchDecision,
        projectDecision: _EmailCatchUpProjectDecision.none,
        fetched: fetched,
        networkNotified: networkNotified,
      );
    }

    final projectDecision = _projectDecisionForCatchUp(
      reason: reason,
      fetched: fetched,
      ioRunning: ioRunningForProjection,
    );
    var projected = false;
    var projectedMessageCount = 0;
    var projectedFreshIdCount = 0;
    var projectedAffectedChatCount = 0;
    String? fullSnapshotFallbackReason;
    if (projectDecision == _EmailCatchUpProjectDecision.requested) {
      await refreshChatlistFromCore(
        source: reason.name,
        force: _catchUpBypassesRecentProjectionSuppression(
          reason: reason,
          fetched: fetched,
          ioRunning: ioRunningForProjection,
        ),
      );
      projected = true;
    } else if (projectDecision == _EmailCatchUpProjectDecision.incremental ||
        projectDecision ==
            _EmailCatchUpProjectDecision.incrementalWithSnapshotFallback) {
      final incrementalProjection =
          _shouldProjectDeltaMessageCursorForCatchUp(reason)
          ? await _syncIncrementalFromCore(isStillRelevant: isStillRelevant)
          : await _syncFreshFromCore(isStillRelevant: isStillRelevant);
      projectedMessageCount = incrementalProjection.syncedMessageCount;
      projectedFreshIdCount = incrementalProjection.freshIdCount;
      projectedAffectedChatCount = incrementalProjection.affectedChatCount;
      projected = true;
      fullSnapshotFallbackReason = _incrementalCatchUpSnapshotFallbackReason(
        reason: reason,
        freshProjection: incrementalProjection,
        ioRunning: ioRunningForProjection,
      );
      if (fullSnapshotFallbackReason != null) {
        await refreshChatlistFromCore(source: reason.name);
      }
    }
    if (_shouldFlushNotificationsForCatchUp(reason)) {
      await _flushQueuedNotifications();
    }
    final connectivitySource = _connectivitySourceForCatchUp(reason);
    if (connectivitySource != null) {
      await _refreshConnectivityState(
        source: connectivitySource,
        recoveryCompleted: _catchUpRecoveryCompleted(
          reason: reason,
          fetched: fetched,
          ioRunning: ioRunningForProjection,
        ),
      );
    }

    final result = _EmailCatchUpResult(
      fetchDecision: fetchDecision,
      projectDecision: projectDecision,
      fetched: fetched,
      projected: projected,
      projectedMessageCount: projectedMessageCount,
      projectedFreshIdCount: projectedFreshIdCount,
      projectedAffectedChatCount: projectedAffectedChatCount,
      networkNotified: networkNotified,
    );
    _traceEmailOperation(
      'email.catchUp',
      'end',
      id: traceId,
      fields: <String, Object?>{
        'reason': reason.name,
        'fetchDecision': fetchDecision.name,
        'fetched': fetched,
        'ioRunningAtStart': ioRunningAtStart,
        'ioRunningForFetch': ioRunningForFetch,
        'ioRunningForProjection': ioRunningForProjection,
        'projectDecision': projectDecision.name,
        'projected': projected,
        'projectedMessageCount': projectedMessageCount,
        'projectedFreshIdCount': projectedFreshIdCount,
        'projectedAffectedChatCount': projectedAffectedChatCount,
        'fullSnapshotFallback': fullSnapshotFallbackReason,
        'networkNotified': networkNotified,
        'syncStatus': _syncState.status.name,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
    if (projected) {
      await _refreshEmailHistoryImportPromptStatus();
    }
    return result;
  }

  _EmailCatchUpQueue _catchUpQueueFor(_EmailCatchUpReason reason) {
    switch (reason) {
      case _EmailCatchUpReason.mailPushHint:
      case _EmailCatchUpReason.periodicIdleTick:
        return _EmailCatchUpQueue.imapSync;
      case _EmailCatchUpReason.channelOverflow:
        return _EmailCatchUpQueue.channelOverflow;
      case _EmailCatchUpReason.foregroundResume:
      case _EmailCatchUpReason.reconnectCatchUp:
        return _EmailCatchUpQueue.reconnectCatchUp;
      case _EmailCatchUpReason.homeUnreadRefresh:
      case _EmailCatchUpReason.homeHistoryRefresh:
      case _EmailCatchUpReason.syncInboxAndSent:
      case _EmailCatchUpReason.backgroundFetchDone:
      case _EmailCatchUpReason.incomingMsgBunch:
        return _EmailCatchUpQueue.none;
    }
  }

  Duration? _catchUpFetchTimeout(_EmailCatchUpReason reason) {
    switch (reason) {
      case _EmailCatchUpReason.mailPushHint:
      case _EmailCatchUpReason.homeUnreadRefresh:
      case _EmailCatchUpReason.homeHistoryRefresh:
      case _EmailCatchUpReason.channelOverflow:
      case _EmailCatchUpReason.foregroundResume:
      case _EmailCatchUpReason.reconnectCatchUp:
        return _foregroundFetchTimeout;
      case _EmailCatchUpReason.syncInboxAndSent:
      case _EmailCatchUpReason.periodicIdleTick:
        return _imapSyncFetchTimeout;
      case _EmailCatchUpReason.backgroundFetchDone:
      case _EmailCatchUpReason.incomingMsgBunch:
        return null;
    }
  }

  String _catchUpProjectPolicyLabel(_EmailCatchUpReason reason) {
    switch (reason) {
      case _EmailCatchUpReason.mailPushHint:
        return 'incrementalAfterFetchOrIoRunning';
      case _EmailCatchUpReason.periodicIdleTick:
        return 'fetchSuccessIncremental';
      case _EmailCatchUpReason.incomingMsgBunch:
        return 'incrementalWithFallback';
      case _EmailCatchUpReason.homeUnreadRefresh:
      case _EmailCatchUpReason.homeHistoryRefresh:
        return 'incrementalThenImport';
      case _EmailCatchUpReason.foregroundResume:
        return 'freshOnlyAfterFetchOrResume';
      case _EmailCatchUpReason.syncInboxAndSent:
      case _EmailCatchUpReason.backgroundFetchDone:
      case _EmailCatchUpReason.channelOverflow:
      case _EmailCatchUpReason.reconnectCatchUp:
        return 'always';
    }
  }

  _EmailCatchUpProjectDecision _projectDecisionForCatchUp({
    required _EmailCatchUpReason reason,
    required bool fetched,
    required bool ioRunning,
  }) {
    switch (reason) {
      case _EmailCatchUpReason.mailPushHint:
        return fetched || ioRunning
            ? _EmailCatchUpProjectDecision.incrementalWithSnapshotFallback
            : _EmailCatchUpProjectDecision.skippedFetchFailed;
      case _EmailCatchUpReason.periodicIdleTick:
        return fetched
            ? _EmailCatchUpProjectDecision.incremental
            : _EmailCatchUpProjectDecision.skippedFetchFailed;
      case _EmailCatchUpReason.incomingMsgBunch:
        return _EmailCatchUpProjectDecision.incrementalWithSnapshotFallback;
      case _EmailCatchUpReason.foregroundResume:
      case _EmailCatchUpReason.homeUnreadRefresh:
      case _EmailCatchUpReason.homeHistoryRefresh:
        return _EmailCatchUpProjectDecision.incremental;
      case _EmailCatchUpReason.syncInboxAndSent:
      case _EmailCatchUpReason.backgroundFetchDone:
      case _EmailCatchUpReason.channelOverflow:
      case _EmailCatchUpReason.reconnectCatchUp:
        return _EmailCatchUpProjectDecision.requested;
    }
  }

  String? _incrementalCatchUpSnapshotFallbackReason({
    required _EmailCatchUpReason reason,
    required _EmailFreshProjectionResult freshProjection,
    required bool ioRunning,
  }) {
    if (freshProjection.hadFreshIds || freshProjection.projectedLocalState) {
      return null;
    }
    if (_hasRecentChatlistRefreshCovering(accountId: null)) {
      return null;
    }
    switch (reason) {
      case _EmailCatchUpReason.incomingMsgBunch:
        return 'emptyIncremental';
      case _EmailCatchUpReason.mailPushHint:
        return ioRunning ? null : 'emptyIncrementalAfterFetch';
      case _EmailCatchUpReason.homeUnreadRefresh:
      case _EmailCatchUpReason.homeHistoryRefresh:
      case _EmailCatchUpReason.syncInboxAndSent:
      case _EmailCatchUpReason.periodicIdleTick:
      case _EmailCatchUpReason.backgroundFetchDone:
      case _EmailCatchUpReason.channelOverflow:
      case _EmailCatchUpReason.foregroundResume:
      case _EmailCatchUpReason.reconnectCatchUp:
        return null;
    }
  }

  bool _catchUpBypassesRecentProjectionSuppression({
    required _EmailCatchUpReason reason,
    required bool fetched,
    required bool ioRunning,
  }) {
    if (fetched) {
      return true;
    }
    switch (reason) {
      case _EmailCatchUpReason.syncInboxAndSent:
      case _EmailCatchUpReason.backgroundFetchDone:
      case _EmailCatchUpReason.channelOverflow:
      case _EmailCatchUpReason.reconnectCatchUp:
        return true;
      case _EmailCatchUpReason.incomingMsgBunch:
      case _EmailCatchUpReason.foregroundResume:
        return false;
      case _EmailCatchUpReason.mailPushHint:
        return ioRunning;
      case _EmailCatchUpReason.homeUnreadRefresh:
      case _EmailCatchUpReason.homeHistoryRefresh:
      case _EmailCatchUpReason.periodicIdleTick:
        return false;
    }
  }

  bool _shouldNotifyNetworkForCatchUp({
    required _EmailCatchUpReason reason,
    required bool fetched,
    required bool ioRunning,
  }) {
    if (fetched) {
      return false;
    }
    switch (reason) {
      case _EmailCatchUpReason.channelOverflow:
        return true;
      case _EmailCatchUpReason.mailPushHint:
        return !ioRunning;
      case _EmailCatchUpReason.homeUnreadRefresh:
      case _EmailCatchUpReason.homeHistoryRefresh:
      case _EmailCatchUpReason.syncInboxAndSent:
      case _EmailCatchUpReason.periodicIdleTick:
      case _EmailCatchUpReason.backgroundFetchDone:
      case _EmailCatchUpReason.incomingMsgBunch:
      case _EmailCatchUpReason.foregroundResume:
      case _EmailCatchUpReason.reconnectCatchUp:
        return false;
    }
  }

  bool _shouldRefreshImapCapabilitiesForCatchUp(_EmailCatchUpReason reason) {
    switch (reason) {
      case _EmailCatchUpReason.periodicIdleTick:
      case _EmailCatchUpReason.reconnectCatchUp:
        return true;
      case _EmailCatchUpReason.mailPushHint:
      case _EmailCatchUpReason.homeUnreadRefresh:
      case _EmailCatchUpReason.homeHistoryRefresh:
      case _EmailCatchUpReason.syncInboxAndSent:
      case _EmailCatchUpReason.backgroundFetchDone:
      case _EmailCatchUpReason.incomingMsgBunch:
      case _EmailCatchUpReason.channelOverflow:
      case _EmailCatchUpReason.foregroundResume:
        return false;
    }
  }

  bool _shouldFlushNotificationsForCatchUp(_EmailCatchUpReason reason) {
    switch (reason) {
      case _EmailCatchUpReason.mailPushHint:
      case _EmailCatchUpReason.incomingMsgBunch:
        return true;
      case _EmailCatchUpReason.homeUnreadRefresh:
      case _EmailCatchUpReason.homeHistoryRefresh:
      case _EmailCatchUpReason.syncInboxAndSent:
      case _EmailCatchUpReason.periodicIdleTick:
      case _EmailCatchUpReason.backgroundFetchDone:
      case _EmailCatchUpReason.channelOverflow:
      case _EmailCatchUpReason.foregroundResume:
      case _EmailCatchUpReason.reconnectCatchUp:
        return false;
    }
  }

  _EmailSyncSource? _connectivitySourceForCatchUp(_EmailCatchUpReason reason) {
    switch (reason) {
      case _EmailCatchUpReason.mailPushHint:
        return _EmailSyncSource.mailPushHint;
      case _EmailCatchUpReason.homeUnreadRefresh:
      case _EmailCatchUpReason.homeHistoryRefresh:
      case _EmailCatchUpReason.backgroundFetchDone:
        return _EmailSyncSource.backgroundFetchDone;
      case _EmailCatchUpReason.channelOverflow:
        return _EmailSyncSource.channelOverflowComplete;
      case _EmailCatchUpReason.foregroundResume:
      case _EmailCatchUpReason.reconnectCatchUp:
        return _EmailSyncSource.reconnectCatchUp;
      case _EmailCatchUpReason.syncInboxAndSent:
      case _EmailCatchUpReason.periodicIdleTick:
      case _EmailCatchUpReason.incomingMsgBunch:
        return null;
    }
  }

  bool _catchUpRecoveryCompleted({
    required _EmailCatchUpReason reason,
    required bool fetched,
    required bool ioRunning,
  }) {
    switch (reason) {
      case _EmailCatchUpReason.mailPushHint:
        return fetched || ioRunning;
      case _EmailCatchUpReason.homeUnreadRefresh:
      case _EmailCatchUpReason.homeHistoryRefresh:
      case _EmailCatchUpReason.backgroundFetchDone:
        return fetched || reason == _EmailCatchUpReason.backgroundFetchDone;
      case _EmailCatchUpReason.channelOverflow:
        return false;
      case _EmailCatchUpReason.foregroundResume:
        return fetched || ioRunning;
      case _EmailCatchUpReason.reconnectCatchUp:
        return true;
      case _EmailCatchUpReason.syncInboxAndSent:
      case _EmailCatchUpReason.periodicIdleTick:
      case _EmailCatchUpReason.incomingMsgBunch:
        return false;
    }
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
    transport.onRuntimeRestarted = _scheduleRuntimeRestartRecovery;
  }

  void _scheduleRuntimeRestartRecovery() {
    _enqueueDeltaOperation(
      _recoverAfterRuntimeRestart,
      operationName: _deltaQueueOperationNameRuntimeRestartRecovery,
    );
  }

  Future<void> _recoverAfterRuntimeRestart() async {
    if (_provisioningBlockedScope != null || !hasActiveSession) {
      return;
    }
    _deltaAccountRepairCompleted = false;
    await _refreshChatlistSnapshotOnMain();
    final accountIds = await _deltaAccountIdsForScope(null);
    for (final accountId in accountIds) {
      await _deltaConsumerForAccount(
        accountId,
      ).recoverOutgoingMessageStatuses();
    }
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
  }) {
    final overrides = Map<String, String>.of(_buildConnectionConfig(address));
    overrides[_sendPasswordConfigKey] = password;
    overrides[_downloadLimitConfigKey] = _downloadLimitBytes.toString();
    overrides[_mdnsEnabledConfigKey] = _mdnsConfigValue(
      _emailReadReceiptsEnabled,
    );
    overrides[_syncMsgsConfigKey] = '0';
    return overrides;
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

  bool get hasActiveSession =>
      _credentialSession.hasActiveSession && _provisioningBlockedScope == null;

  bool get hasInMemoryReconnectContext =>
      _credentialSession.hasInMemoryReconnectContext &&
      _provisioningBlockedScope == null;

  Stream<DeltaCoreEvent> get events => _transport.events;

  EmailSyncState get syncState => _syncState;

  Stream<EmailSyncState> get syncStateStream => _syncStateController.stream;

  Stream<void> get readyTransitionStream => _readyTransitionController.stream;

  EmailContentPreparationSnapshot get contentPreparationSnapshot =>
      _contentPreparationSnapshot;

  Stream<EmailContentPreparationSnapshot> get contentPreparationStream =>
      _contentPreparationController.stream;

  EmailOriginalContentSnapshot get originalContentSnapshot =>
      _originalContentSnapshot;

  Stream<EmailOriginalContentSnapshot> get originalContentStream =>
      _originalContentController.stream;

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
    final traceId = _nextTraceId('email.ensureProvisioned');
    final stopwatch = Stopwatch()..start();
    _traceEmailOperation(
      'email.ensureProvisioned',
      'start',
      id: traceId,
      fields: <String, Object?>{
        'jid': jid,
        'runtime': _runtimePhase.name,
        'hasSession': hasActiveSession,
        'activeScope': _activeCredentialScope,
        'persistCredentials': persistCredentials,
        'hasPasswordOverride': passwordOverride?.isNotEmpty == true,
        'hasAddressOverride': addressOverride?.isNotEmpty == true,
        'pendingCleanup': _pendingNativeCleanup != null,
        'caller': _traceCaller(StackTrace.current),
      },
    );
    try {
      final account = await _ensureProvisioned(
        displayName: displayName,
        databasePrefix: databasePrefix,
        databasePassphrase: databasePassphrase,
        jid: jid,
        passwordOverride: passwordOverride,
        addressOverride: addressOverride,
        persistCredentials: persistCredentials,
        traceId: traceId,
        traceStopwatch: stopwatch,
      );
      _traceEmailOperation(
        'email.ensureProvisioned',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'result': 'completed',
          'elapsedMs': stopwatch.elapsedMilliseconds,
          'activeScope': _activeCredentialScope,
          'runtime': _runtimePhase.name,
        },
      );
      return account;
    } on Exception catch (error, stackTrace) {
      final scope = _scopeForJid(jid);
      if (_isProvisioningRuntimeFailure(error)) {
        _recordProvisioningRuntimeFailure(scope);
      }
      _traceEmailOperation(
        'email.ensureProvisioned',
        'error',
        id: traceId,
        fields: <String, Object?>{
          'result': error.runtimeType,
          'elapsedMs': stopwatch.elapsedMilliseconds,
          'runtime': _runtimePhase.name,
        },
      );
      _log.warning('Email provisioning failed.', error, stackTrace);
      rethrow;
    }
  }

  Future<EmailAccount> _ensureProvisioned({
    required String displayName,
    required String databasePrefix,
    required String databasePassphrase,
    required String jid,
    String? passwordOverride,
    String? addressOverride,
    bool persistCredentials = true,
    required String traceId,
    required Stopwatch traceStopwatch,
  }) async {
    final pendingCleanup = _pendingNativeCleanup;
    if (pendingCleanup != null) {
      final cleanupWatch = Stopwatch()..start();
      await pendingCleanup;
      _traceEmailOperation(
        'email.ensureProvisioned.pendingCleanup',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'elapsedMs': cleanupWatch.elapsedMilliseconds,
        },
      );
    }
    final scope = _scopeForJid(jid);
    _provisioningBlockedScope = null;
    final needsInit =
        _databasePrefix != databasePrefix ||
        _databasePassphrase != databasePassphrase;
    _traceEmailOperation(
      'email.ensureProvisioned.init',
      'decision',
      id: traceId,
      fields: <String, Object?>{
        'needsInit': needsInit,
        'scope': scope,
        'activeScope': _activeCredentialScope,
        'runtime': _runtimePhase.name,
      },
    );
    if (needsInit) {
      final initWatch = Stopwatch()..start();
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
      _traceEmailOperation(
        'email.ensureProvisioned.ensureInitialized',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'elapsedMs': initWatch.elapsedMilliseconds,
          'listenerAttached': _listenerAttached,
        },
      );
    }

    if (!_listenerAttached) {
      _attachTransportListener();
    }

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
    _transport.hydrateAccountAddress(
      address: selectedAddress,
      accountId: DeltaAccountDefaults.singleContextId,
    );

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
    _log.fine(
      'Email provisioning decision: '
      'accountId=$deltaAccountId '
      'transportConfigured=$transportConfigured '
      'requiresReconfigure=$requiresReconfigure '
      'needsProvisioning=$needsProvisioning '
      'advertisedConfigKeys=${supportedConfigKeys ?? '<unavailable>'}',
    );
    _traceEmailOperation(
      'email.ensureProvisioned',
      'decision',
      id: traceId,
      fields: <String, Object?>{
        'accountId': deltaAccountId,
        'storedProvisioned': storedProvisioned,
        'ephemeralProvisioned': ephemerallyProvisioned,
        'transportConfigured': transportConfigured,
        'credentialsMutated': credentialsMutated,
        'requiresReconfigure': requiresReconfigure,
        'needsProvisioning': needsProvisioning,
        'hasPassword': hasPassword,
        'shouldForceProvisioning': shouldForceProvisioning,
        'elapsedMs': traceStopwatch.elapsedMilliseconds,
      },
    );
    final pausedForProvisioning = needsProvisioning && _acceptsRuntimeWork;
    if (pausedForProvisioning) {
      final stopWatch = Stopwatch()..start();
      await stop();
      _traceEmailOperation(
        'email.ensureProvisioned.stopForProvisioning',
        'end',
        id: traceId,
        fields: <String, Object?>{'elapsedMs': stopWatch.elapsedMilliseconds},
      );
    }

    if (needsProvisioning && !hasPassword) {
      throw const EmailProvisioningMissingPasswordException();
    }

    if (needsProvisioning) {
      final provisioningPassword = password!;
      _log.info('Configuring email account credentials');
      try {
        final configureWatch = Stopwatch()..start();
        final configureOverrides = _buildConfigureAccountOverrides(
          address: address,
          password: provisioningPassword,
        );
        await _applyDeltaDownloadLimit(accountIds: [deltaAccountId]);
        await _applyNormalExistingHistoryImportPolicy(
          accountIds: [deltaAccountId],
        );
        await _transport.configureAccount(
          address: address,
          password: provisioningPassword,
          displayName: displayName,
          additional: configureOverrides,
          accountId: deltaAccountId,
        );
        _traceEmailOperation(
          'email.ensureProvisioned.configureAccount',
          'end',
          id: traceId,
          fields: <String, Object?>{
            'elapsedMs': configureWatch.elapsedMilliseconds,
          },
        );
        final openPgpWatch = Stopwatch()..start();
        await _applyOpenPgpBaseConfigForAccount(
          _EmailAccountBinding(
            address: address,
            deltaAccountId: deltaAccountId,
          ),
        );
        _traceEmailOperation(
          'email.ensureProvisioned.applyOpenPgpConfig',
          'end',
          id: traceId,
          fields: <String, Object?>{
            'elapsedMs': openPgpWatch.elapsedMilliseconds,
          },
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

    final hydrateWatch = Stopwatch()..start();
    await _hydrateAccountAddress(
      address: address,
      deltaAccountId: deltaAccountId,
    );
    _traceEmailOperation(
      'email.ensureProvisioned.hydrateAccount',
      'end',
      id: traceId,
      fields: <String, Object?>{'elapsedMs': hydrateWatch.elapsedMilliseconds},
    );
    final account = EmailAccount(
      address: address,
      password: password ?? _unknownEmailPassword,
    );
    _activateCredentialAccount(scope: scope, account: account);
    final startWatch = Stopwatch()..start();
    await start();
    _traceEmailOperation(
      'email.ensureProvisioned.startTransport',
      'end',
      id: traceId,
      fields: <String, Object?>{
        'elapsedMs': startWatch.elapsedMilliseconds,
        'runtime': _runtimePhase.name,
        'ioRunning': _transport.isIoRunning,
      },
    );
    final capabilitiesWatch = Stopwatch()..start();
    await _refreshImapCapabilities(force: true);
    _traceEmailOperation(
      'email.ensureProvisioned.refreshImapCapabilities',
      'end',
      id: traceId,
      fields: <String, Object?>{
        'elapsedMs': capabilitiesWatch.elapsedMilliseconds,
      },
    );
    _credentialSession.markEphemerallyProvisioned(scope);
    _clearProvisioningRuntimeFailure(scope);
    final startupSnapshotWatch = Stopwatch()..start();
    await _refreshStartupChatlistSnapshot(accountId: deltaAccountId);
    await _refreshEmailHistoryImportPromptStatus();
    _traceEmailOperation(
      'email.ensureProvisioned.startupChatlistSnapshot',
      'end',
      id: traceId,
      fields: <String, Object?>{
        'elapsedMs': startupSnapshotWatch.elapsedMilliseconds,
      },
    );
    return account;
  }

  Future<int> _ensureEmailAccountSession({
    required bool createIfMissing,
  }) async {
    final existingAccountIds = _usableDeltaAccountIds(
      await _transport.accountIds(),
    );
    if (existingAccountIds.isNotEmpty) {
      final preferredAccountId = _transport.activeAccountId;
      final deltaAccountId =
          preferredAccountId != DeltaAccountDefaults.legacyId &&
              existingAccountIds.contains(preferredAccountId)
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
      if (deltaAccountId == DeltaAccountDefaults.legacyId) {
        throw const EmailProvisioningAccountUnavailableException();
      }
      await _transport.ensureAccountSession(deltaAccountId);
      _transport.setPrimaryAccountId(deltaAccountId);
      return deltaAccountId;
    }

    throw const EmailProvisioningAccountUnavailableException();
  }

  List<int> _usableDeltaAccountIds(Iterable<int> accountIds) {
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
    final activeAccountId = _transport.activeAccountId;
    if (ids.contains(activeAccountId)) {
      return List<int>.unmodifiable(<int>[
        activeAccountId,
        ...ids.where((id) => id != activeAccountId),
      ]);
    }
    return List<int>.unmodifiable(ids);
  }

  bool _isProvisioningRuntimeFailure(Object error) =>
      error is DeltaAllocationException ||
      error is EmailProvisioningAccountUnavailableException;

  void _recordProvisioningRuntimeFailure(String scope) {
    _provisioningBlockedScope = scope;
    if (_activeCredentialScope == scope) {
      _activeAccount = null;
      _activeCredentialScope = null;
    }
    _credentialSession.clearEphemeralProvisioning(scope);
    if (_runtimePhase != _EmailRuntimePhase.disposing &&
        _runtimePhase != _EmailRuntimePhase.stopping) {
      _runtimePhase = _EmailRuntimePhase.stopped;
    }
  }

  void _clearProvisioningRuntimeFailure(String scope) {
    if (_provisioningBlockedScope == scope) {
      _provisioningBlockedScope = null;
    }
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
        await _applyDeltaDownloadLimit(accountIds: [deltaAccountId]);
        await _applyNormalExistingHistoryImportPolicy(
          accountIds: [deltaAccountId],
        );
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
    _activateCredentialAccount(
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
    if (_provisioningBlockedScope != null) {
      throw const EmailProvisioningAccountUnavailableException();
    }
    if (!hasActiveSession) {
      throw const EmailProvisioningAccountUnavailableException();
    }
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
    await _applyDeltaDownloadLimit();
    await _applyNormalExistingHistoryImportPolicy();
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
    _suppressedConnectivityChangedEvents = 0;
    _clearNotificationQueue();
    _resetEmailContentPreparation();
    _resetEmailOriginalContent();
    _contactsSyncQueue.reset();
    _chatlistSyncQueue.reset();
    _chatlistRefreshTask = null;
    _lastChatlistRefreshCompletedAt = null;
    _lastChatlistRefreshCompletedAccountId = null;
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
    if (_provisioningBlockedScope != null || !hasActiveSession) {
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
      await _boundedNativeCleanupStep(
        'transport dispose',
        () => _disposeTransportForCleanup(_transport),
      );
    } finally {
      _credentialSession.clearRuntime();
      _runtimePhase = _EmailRuntimePhase.stopped;
      _setEmailHistoryImportPromptStatus(
        EmailHistoryImportPromptStatus.hidden,
        source: _EmailSyncSource.unknown,
      );
    }
  }

  Future<void> close() async {
    await _mailPushHintSubscription?.cancel();
    _mailPushHintSubscription = null;
    await shutdown();
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
    _suppressedConnectivityChangedEvents = 0;
    _clearNotificationQueue();
    _resetRuntimeQueues();
    _credentialSession.invalidateBootstrapOperations();
    _resetDeltaOperationQueue();
    _resetImapCapabilities();

    await _awaitLogoutRuntimeWork(pendingDatabaseRuntimeWork);

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
    _setEmailHistoryImportPromptStatus(
      EmailHistoryImportPromptStatus.hidden,
      source: _EmailSyncSource.unknown,
    );
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
    _resetEmailContentPreparation();
    _resetEmailOriginalContent();
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
    _lastChatlistRefreshCompletedAt = null;
    _lastChatlistRefreshCompletedAccountId = null;
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

  Future<void> _awaitLogoutRuntimeWork(Future<void> pendingRuntimeWork) async {
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
      await _boundedNativeCleanupStep(
        'transport stop',
        () => _stopTransportForNativeLogoutCleanup(
          transport: transport,
          activeStop: activeStop,
          matchingStopFuture: matchingStopFuture,
        ),
      );
      await _boundedNativeCleanupStep(
        'runtime drain',
        () => _awaitLogoutRuntimeWork(pendingRuntimeWork),
      );
      if (clearTransportCredentials) {
        await _boundedNativeCleanupStep(
          'account deconfigure',
          () => _deconfigureTransportForCredentialClear(
            transport,
            requireActiveRuntime: false,
          ),
        );
      }
      await _boundedNativeCleanupStep(
        'transport dispose',
        () => _disposeTransportForCleanup(transport),
      );
    } finally {
      await _releaseForegroundKeepaliveResources();
    }
  }

  Future<void> _disposeTransportForCleanup(EmailDeltaRuntime transport) async {
    try {
      await transport.dispose();
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to dispose email transport', error, stackTrace);
    }
  }

  Future<void> _boundedNativeCleanupStep(
    String step,
    Future<void> Function() run,
  ) {
    return run().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _log.warning('Email native cleanup step timed out: $step');
      },
    );
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
  }) async {
    final record = !_transport.persistsAppStateInternally;
    final int msgId;
    try {
      msgId = await _guardDeltaOperation(operation: operation, body: send);
    } on Exception {
      if (record) {
        await _recordFailedOutgoingEmail(
          chatId: chatId,
          accountId: accountId,
          chat: chat,
          body: body,
          subject: subject,
          quotingStanzaId: quotingStanzaId,
          localBodyOverride: localBodyOverride,
          htmlBody: htmlBody,
        );
      }
      rethrow;
    }
    if (record) {
      await _deltaConsumerForAccount(accountId).hydrateMessage(msgId);
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
        await _patchOutgoingEmailQuote(
          db: db,
          msgId: msgId,
          accountId: accountId,
          chatId: chatId,
          quotingStanzaId: quotingStanzaId,
        );
      }
    }
    return msgId;
  }

  Future<void> _patchOutgoingEmailQuote({
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

  Future<void> _recordFailedOutgoingEmail({
    required int chatId,
    required int accountId,
    required Chat chat,
    String? body,
    String? subject,
    String? quotingStanzaId,
    String? localBodyOverride,
    String? htmlBody,
  }) async {
    final db = await _databaseBuilder();
    final displayBody = localBodyOverride ?? body;
    final trimmedBody = displayBody?.trim();
    final senderJid = _resolveOutgoingSenderJid(
      chat: chat,
      accountId: accountId,
    );
    await db.saveMessage(
      Message(
        stanzaID: _outgoingEmailRowKey(),
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

  String _outgoingEmailRowKey() => const Uuid().v4();

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
              forwardedOriginalSenderLabel: forwardedOriginalSenderLabel,
            ),
          ),
        );
      }
    }
    return msgId;
  }

  Future<FanOutSendReport> fanOutSend({
    required List<EmailRecipientIntent> targets,
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
    if (targets.isEmpty) {
      throw const FanOutNoRecipientsException();
    }
    if (targets.length > composeRecipientLimit) {
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
    await _ensureReady();
    final resolution = await _resolveFanOutTargets(targets);
    final targetChatsByJid = resolution.chatByJid;
    if (targetChatsByJid.isEmpty) {
      return FanOutSendReport(
        shareId: shareId ?? ShareTokenCodec.generateShareId(),
        subject: normalizedSubject,
        statuses: [
          for (final resolved in resolution.unresolved)
            FanOutRecipientStatus(
              recipientKey: resolved.intent.recipientKey,
              requestedTarget: resolved.requestedTarget,
              state: FanOutRecipientState.failed,
              error: const FanOutResolveFailedException(),
            ),
        ],
      );
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

    final statuses = <FanOutRecipientStatus>[
      for (final resolved in resolution.unresolved)
        FanOutRecipientStatus(
          recipientKey: resolved.intent.recipientKey,
          requestedTarget: resolved.requestedTarget,
          state: FanOutRecipientState.failed,
          error: const FanOutResolveFailedException(),
        ),
    ];
    final bool originatorAlreadyCaptured =
        existingShare?.originatorDcMsgId != null;
    int? originatorMsgId;

    Future<
      ({
        String chatJid,
        Chat chat,
        FanOutRecipientState state,
        int? msgId,
        Object? error,
      })
    >
    sendTo(Chat entry) async {
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
          chatJid: entry.jid,
          chat: binding.chat,
          state: FanOutRecipientState.sent,
          msgId: msgId,
          error: null,
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
          chatJid: entry.jid,
          chat: entry,
          state: FanOutRecipientState.failed,
          msgId: null,
          error: error,
        );
      }
    }

    final results =
        <
          ({
            String chatJid,
            Chat chat,
            FanOutRecipientState state,
            int? msgId,
            Object? error,
          })
        >[];
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
      final resolvedTargets = resolution.targetsByChatJid[result.chatJid];
      if (resolvedTargets == null) {
        continue;
      }
      for (final resolved in resolvedTargets) {
        statuses.add(
          FanOutRecipientStatus(
            recipientKey: resolved.intent.recipientKey,
            requestedTarget: resolved.requestedTarget,
            resolvedChat: result.chat,
            state: result.state,
            deltaMsgId: result.msgId,
            error: result.error,
          ),
        );
      }
      if (!originatorAlreadyCaptured &&
          originatorMsgId == null &&
          result.msgId != null) {
        originatorMsgId = result.msgId;
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
    required List<EmailRecipientIntent> targets,
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
    if (targets.length > composeRecipientLimit) {
      throw const FanOutTooManyRecipientsException(composeRecipientLimit);
    }
    final normalizedSubject = _normalizeSubject(subject);
    final bodyPayload = _outgoingTextPayload(
      body: body,
      htmlBody: htmlBody,
      subject: normalizedSubject,
    );
    if (bodyPayload.displayText.isEmpty &&
        attachment == null &&
        normalizedSubject == null) {
      throw const FanOutEmptyMessageException();
    }
    final effectiveShareId = shareId ?? ShareTokenCodec.generateShareId();
    final chatsByJid = <String, Chat>{};
    final targetsByChatJid = <String, List<EmailRecipientIntent>>{};
    for (final target in targets) {
      final chat = _demoChatForTarget(target);
      chatsByJid.putIfAbsent(chat.jid, () => chat);
      targetsByChatJid.putIfAbsent(chat.jid, () => []).add(target);
    }
    final statuses = <FanOutRecipientStatus>[];
    for (final entry in chatsByJid.entries) {
      final chat = entry.value;
      final resolvedTargets = targetsByChatJid[entry.key]!;
      try {
        if (attachment != null) {
          final captionedAttachment = attachment.copyWith(
            caption: htmlCaption ?? body,
          );
          await _sendDemoEmailAttachment(
            chat: chat,
            attachment: captionedAttachment,
            subject: normalizedSubject,
            htmlCaption: htmlCaption,
            quotedStanzaId: quotedStanzaId,
          );
          _scheduleDemoCopiedReply(chat);
        } else {
          await _sendDemoEmailMessage(
            chat: chat,
            body: bodyPayload.displayText,
            subject: normalizedSubject,
            htmlBody: bodyPayload.htmlBody,
            quotedStanzaId: quotedStanzaId,
          );
        }
        final deltaMsgId = demoNow().millisecondsSinceEpoch;
        for (final target in resolvedTargets) {
          statuses.add(
            FanOutRecipientStatus(
              recipientKey: target.recipientKey,
              requestedTarget: FanOutRecipientTargetSnapshot.fromIntent(target),
              resolvedChat: chat,
              state: FanOutRecipientState.sent,
              deltaMsgId: deltaMsgId,
            ),
          );
        }
      } catch (error) {
        for (final target in resolvedTargets) {
          statuses.add(
            FanOutRecipientStatus(
              recipientKey: target.recipientKey,
              requestedTarget: FanOutRecipientTargetSnapshot.fromIntent(target),
              resolvedChat: chat,
              state: FanOutRecipientState.failed,
              error: error,
            ),
          );
        }
      }
    }
    return FanOutSendReport(
      shareId: effectiveShareId,
      statuses: statuses,
      subject: normalizedSubject,
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

  Chat _demoChatForTarget(EmailRecipientIntent target) {
    final address = target.address.trim();
    final String selectedAddress =
        target.sourceChatJid ?? (address.isNotEmpty ? address : kDemoSelfJid);
    final displayName = target.displayName.trim();
    final String resolvedTitle = displayName.isNotEmpty
        ? displayName
        : selectedAddress;
    return Chat.fromJid(selectedAddress).copyWith(
      title: resolvedTitle,
      contactDisplayName: resolvedTitle,
      emailAddress: address.isNotEmpty ? address : selectedAddress,
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
    try {
      await _ensureReady();
    } on EmailProvisioningException catch (error, stackTrace) {
      _log.fine('Email share context unavailable.', error, stackTrace);
      return null;
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      _log.fine('Email share context unavailable.', error, stackTrace);
      return null;
    } on DeltaSafeException catch (error, stackTrace) {
      _log.fine('Email share context unavailable.', error, stackTrace);
      return null;
    }
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
    final traceId = _nextTraceId('email.networkAvailable');
    final stopwatch = Stopwatch()..start();
    _traceEmailOperation(
      'email.networkAvailable',
      'start',
      id: traceId,
      fields: <String, Object?>{
        'policy': restartPolicy.name,
        'runtime': _runtimePhase.name,
        'hasReconnectContext': hasInMemoryReconnectContext,
        'ioRunning': _transport.isIoRunning,
      },
    );
    if (!_canProcessNetworkTransition) {
      _traceEmailOperation(
        'email.networkAvailable',
        'skip',
        id: traceId,
        fields: <String, Object?>{
          'reason': 'cannotProcessNetworkTransition',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return;
    }
    if (_databasePrefix == null || _databasePassphrase == null) {
      _traceEmailOperation(
        'email.networkAvailable',
        'skip',
        id: traceId,
        fields: <String, Object?>{
          'reason': 'missingDatabaseRuntime',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return;
    }
    final startWatch = Stopwatch()..start();
    await ensureEventChannelActive();
    _traceEmailOperation(
      'email.networkAvailable.ensureEventChannelActive',
      'end',
      id: traceId,
      fields: <String, Object?>{'elapsedMs': startWatch.elapsedMilliseconds},
    );
    final notifyWatch = Stopwatch()..start();
    await _notifyTransportNetworkAvailable();
    _traceEmailOperation(
      'email.networkAvailable.notifyTransport',
      'end',
      id: traceId,
      fields: <String, Object?>{'elapsedMs': notifyWatch.elapsedMilliseconds},
    );
    final bootstrapWatch = Stopwatch()..start();
    await _bootstrapActiveAccountIfNeeded();
    _traceEmailOperation(
      'email.networkAvailable.bootstrap',
      'end',
      id: traceId,
      fields: <String, Object?>{
        'elapsedMs': bootstrapWatch.elapsedMilliseconds,
      },
    );
    final catchUpWatch = Stopwatch()..start();
    if (restartPolicy == _EmailReconnectRestartPolicy.foregroundResume) {
      await _runForegroundResumeCatchUp(parentTraceId: traceId);
    } else {
      await _runReconnectCatchUp(parentTraceId: traceId);
    }
    _traceEmailOperation(
      'email.networkAvailable.catchUp',
      'end',
      id: traceId,
      fields: <String, Object?>{
        'policy': restartPolicy.name,
        'elapsedMs': catchUpWatch.elapsedMilliseconds,
      },
    );
    _startImapSyncLoop();
    final connectivityWatch = Stopwatch()..start();
    final connectivity = await _refreshConnectivityState(
      source: _EmailSyncSource.networkAvailable,
    );
    _traceEmailOperation(
      'email.networkAvailable.connectivity',
      'end',
      id: traceId,
      fields: <String, Object?>{
        'elapsedMs': connectivityWatch.elapsedMilliseconds,
      },
    );
    if (_shouldScheduleReconnectRestart(
      connectivity: connectivity,
      restartPolicy: restartPolicy,
    )) {
      fireAndForget(
        () => _scheduleReconnectRestart(restartPolicy),
        operationName: 'EmailService.reconnectRestart',
      );
    }
    _traceEmailOperation(
      'email.networkAvailable',
      'end',
      id: traceId,
      fields: <String, Object?>{'elapsedMs': stopwatch.elapsedMilliseconds},
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
      _traceEmailOperation(
        'email.backgroundFetch',
        'coalesced',
        fields: <String, Object?>{'timeout': timeout},
      );
      return active;
    }
    final traceId = _nextTraceId('email.backgroundFetch');
    final task = _performBackgroundFetchExclusive(
      timeout: timeout,
      traceId: traceId,
    );
    _backgroundFetchInFlight = task;
    return task.whenComplete(() {
      if (identical(_backgroundFetchInFlight, task)) {
        _backgroundFetchInFlight = null;
      }
    });
  }

  Future<bool> _performBackgroundFetchExclusive({
    required Duration timeout,
    required String traceId,
  }) async {
    final stopwatch = Stopwatch()..start();
    _traceEmailOperation(
      'email.backgroundFetch',
      'start',
      id: traceId,
      fields: <String, Object?>{
        'timeout': timeout,
        'runtime': _runtimePhase.name,
        'ioRunning': _transport.isIoRunning,
      },
    );
    if (_nativeCleanupPending || _blocksRuntimeReentry || !hasActiveSession) {
      _traceEmailOperation(
        'email.backgroundFetch',
        'skip',
        id: traceId,
        fields: <String, Object?>{
          'reason': 'runtimeBlocked',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return false;
    }
    if (_databasePrefix == null || _databasePassphrase == null) {
      _traceEmailOperation(
        'email.backgroundFetch',
        'skip',
        id: traceId,
        fields: <String, Object?>{
          'reason': 'missingDatabaseRuntime',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return false;
    }
    await _applyDeltaDownloadLimit();
    await _applyNormalExistingHistoryImportPolicy();
    try {
      final result = await _transport
          .performBackgroundFetch(timeout)
          .timeout(
            timeout + const Duration(seconds: 30),
            onTimeout: () {
              _log.warning(
                'Email background fetch overran its native timeout.',
              );
              return false;
            },
          );
      _traceEmailOperation(
        'email.backgroundFetch',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'result': result,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return result;
    } on Exception catch (error) {
      _traceEmailOperation(
        'email.backgroundFetch',
        'error',
        id: traceId,
        fields: <String, Object?>{
          'result': error.runtimeType,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      rethrow;
    }
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

  Future<void> refreshChatlistFromCore({
    String source = 'explicit',
    bool force = false,
    int? accountId,
    bool allowExistingHistoryImportProjection = false,
  }) async {
    if (_blocksExistingHistoryImportProjectionCall(
      allowExistingHistoryImportProjection:
          allowExistingHistoryImportProjection,
    )) {
      _existingHistoryImportDeferredProjection = true;
      return;
    }
    final caller = _traceCaller(StackTrace.current);
    final activeRefresh = _chatlistRefreshTask;
    if (activeRefresh != null) {
      _traceEmailOperation(
        'email.chatlistRefresh',
        'coalesced',
        fields: <String, Object?>{
          'source': source,
          'accountId': accountId,
          'caller': caller,
        },
      );
      await activeRefresh;
      return;
    }
    final forceProjection = force || source == 'explicit';
    if (!forceProjection &&
        _hasRecentChatlistRefreshCovering(accountId: accountId)) {
      _traceEmailOperation(
        'email.chatlistRefresh',
        'skip',
        fields: <String, Object?>{
          'source': source,
          'accountId': accountId,
          'reason': 'recentSnapshot',
          'caller': caller,
        },
      );
      return;
    }
    final traceId = _nextTraceId('email.chatlistRefresh');
    final task = _chatlistSyncQueue.run(() async {
      final stopwatch = Stopwatch()..start();
      try {
        _traceEmailOperation(
          'email.chatlistRefresh',
          'start',
          id: traceId,
          fields: <String, Object?>{
            'source': source,
            'runtime': _runtimePhase.name,
            'hasSession': hasActiveSession,
            'force': forceProjection,
            'accountId': accountId,
            'caller': caller,
          },
        );
        if (!await _ensureBackgroundSyncReady()) {
          _traceEmailOperation(
            'email.chatlistRefresh',
            'skip',
            id: traceId,
            fields: <String, Object?>{
              'source': source,
              'accountId': accountId,
              'reason': 'backgroundSyncNotReady',
              'elapsedMs': stopwatch.elapsedMilliseconds,
            },
          );
          return;
        }
        await _refreshChatlistSnapshotOnMain(accountId: accountId);
        _traceEmailOperation(
          'email.chatlistRefresh',
          'end',
          id: traceId,
          fields: <String, Object?>{
            'source': source,
            'accountId': accountId,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
      } on Exception catch (error) {
        _traceEmailOperation(
          'email.chatlistRefresh',
          'error',
          id: traceId,
          fields: <String, Object?>{
            'source': source,
            'result': error.runtimeType,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
        rethrow;
      }
    });
    _chatlistRefreshTask = task;
    try {
      await task;
    } finally {
      if (identical(_chatlistRefreshTask, task)) {
        _chatlistRefreshTask = null;
      }
    }
    await _refreshEmailHistoryImportPromptStatus();
  }

  bool _hasRecentChatlistRefreshCovering({required int? accountId}) {
    final completedAt = _lastChatlistRefreshCompletedAt;
    if (completedAt == null) {
      return false;
    }
    final completedAccountId = _lastChatlistRefreshCompletedAccountId;
    if (accountId != null &&
        completedAccountId != null &&
        completedAccountId != accountId) {
      return false;
    }
    return DateTime.timestamp().difference(completedAt) <
        _chatlistRefreshRecentSuppressionWindow;
  }

  void _recordChatlistRefreshCompleted({required int? accountId}) {
    _lastChatlistRefreshCompletedAt = DateTime.timestamp();
    _lastChatlistRefreshCompletedAccountId = accountId;
  }

  Future<void> syncInboxAndSent() async {
    await _requestEmailCatchUp(_EmailCatchUpReason.syncInboxAndSent);
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
      return await _refreshHomeEmailSnapshot(source: 'homeUnreadRefresh');
    } on Exception catch (error, stackTrace) {
      _log.fine('Email unread sync failed.', error, stackTrace);
      return false;
    }
  }

  Future<bool> refreshHistoryForHomeRefresh() async {
    if (!hasActiveSession) {
      return true;
    }
    try {
      return await _refreshHomeEmailSnapshot(source: 'homeHistoryRefresh');
    } on Exception {
      _log.fine('Email background sync failed.');
      return false;
    }
  }

  Future<bool> _refreshHomeEmailSnapshot({required String source}) async {
    final reason = source == 'homeHistoryRefresh'
        ? _EmailCatchUpReason.homeHistoryRefresh
        : _EmailCatchUpReason.homeUnreadRefresh;
    final result = await _requestEmailCatchUp(reason);
    await _repairLocalEmailChatSummariesBestEffort();
    return result.projected;
  }

  Future<void> _repairLocalEmailChatSummariesBestEffort({
    int? accountId,
  }) async {
    try {
      await _repairLocalEmailChatSummaries(accountId: accountId);
    } on Exception catch (error, stackTrace) {
      _log.fine('Email chat summary repair failed.', error, stackTrace);
    }
  }

  Future<void> _repairLocalEmailChatSummaries({int? accountId}) async {
    await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      final chats = await db.getDeltaChats(accountId: accountId);
      for (final chat in chats) {
        try {
          await db.repairChatSummaryFromMessages(
            chat.jid,
            clearStaleLastMessage: true,
          );
        } on Exception catch (error, stackTrace) {
          _log.fine(
            'Email chat summary repair failed for ${chat.jid}.',
            error,
            stackTrace,
          );
        }
      }
    });
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

  Future<void> importExistingEmailHistory({bool force = false}) {
    final active = _existingHistoryImportTask;
    _traceExistingHistoryImport(
      'request',
      fields: <String, Object?>{
        'force': force,
        'alreadyRunning': active != null,
      },
    );
    if (active != null) {
      return active;
    }
    final task = _importExistingEmailHistory(force: force);
    _existingHistoryImportTask = task;
    return task.whenComplete(() {
      if (identical(_existingHistoryImportTask, task)) {
        _existingHistoryImportTask = null;
      }
    });
  }

  Future<void> dismissExistingEmailHistoryImportPrompt() async {
    final scope = _activeCredentialScope;
    if (scope != null) {
      _emailHistoryImportPromptSnoozedScopes.add(scope);
    }
    _setEmailHistoryImportPromptStatus(
      EmailHistoryImportPromptStatus.hidden,
      source: _EmailSyncSource.unknown,
    );
  }

  Future<void> _importExistingEmailHistory({required bool force}) async {
    await _ensureReady();
    final scope = _activeCredentialScope;
    if (scope == null) {
      _traceExistingHistoryImport(
        'skip',
        fields: <String, Object?>{'reason': 'missingScope', 'force': force},
      );
      return;
    }
    if (!force && await _emailHistoryImportPromptAttemptFinished()) {
      _traceExistingHistoryImport(
        'skip',
        fields: <String, Object?>{'reason': 'completed', 'force': force},
      );
      return;
    }
    final accountIds = await _deltaAccountIdsForScope(null);
    if (accountIds.isEmpty) {
      _traceExistingHistoryImport(
        'skip',
        fields: <String, Object?>{'reason': 'noAccounts', 'force': force},
      );
      return;
    }
    final enabledAccountIds = <int>{};
    final importStopwatch = Stopwatch()..start();
    _traceExistingHistoryImport(
      'start',
      fields: <String, Object?>{
        'accountCount': accountIds.length,
        'force': force,
      },
    );
    try {
      for (final accountId in accountIds) {
        await _transport.ensureAccountSession(accountId);
        await _requireDeltaDownloadLimit(accountIds: [accountId]);
      }
      _existingHistoryImportDeferredProjection = false;
      _existingHistoryImportDeferredContactsSync = false;
      _existingHistoryImportWarnings.clear();
      _existingHistoryImportProjectionState =
          _ExistingHistoryImportProjectionState.importing;
      _updateSyncState(
        EmailSyncState.recovering(
          _l10n.emailSyncMessageHistorySyncing,
        ).withHistoryImportPromptStatus(
          EmailHistoryImportPromptStatus.importing,
        ),
        source: _EmailSyncSource.bootstrapStart,
        preserveHistoryImportPromptStatus: false,
      );
      await start();
      await _notifyTransportNetworkAvailable();
      var fetchedExistingHistory = true;
      for (final accountId in accountIds) {
        var journal = await _ensureExistingHistoryImportJournal(
          scope: scope,
          accountId: accountId,
          resetProjection: force,
        );
        if (!journal.fetchCompleted) {
          final fetchStopwatch = Stopwatch()..start();
          var fetchSucceeded = false;
          _traceExistingHistoryImport(
            'account_fetch_start',
            fields: <String, Object?>{'accountId': accountId},
          );
          try {
            await _enableExistingHistoryImport(accountId);
            enabledAccountIds.add(accountId);
            fetchSucceeded = await _runExistingHistoryImportFetch(accountId);
          } finally {
            try {
              if (enabledAccountIds.contains(accountId)) {
                await _disableExistingHistoryImport(accountId);
                enabledAccountIds.remove(accountId);
              }
            } finally {
              _traceExistingHistoryImport(
                'account_fetch_end',
                fields: <String, Object?>{
                  'accountId': accountId,
                  'success': fetchSucceeded,
                  'elapsedMs': fetchStopwatch.elapsedMilliseconds,
                },
              );
            }
          }
          if (!fetchSucceeded) {
            fetchedExistingHistory = false;
          }
          final targetDeltaMsgId = await _transport.maxMessageId(
            accountId: accountId,
          );
          journal = await _saveExistingHistoryImportJournal(
            scope: scope,
            accountId: accountId,
            status: _existingHistoryImportJournalStatusImporting,
            watermarkDeltaMsgId: journal.watermarkDeltaMsgId,
            targetDeltaMsgId: targetDeltaMsgId,
            lastProjectedDeltaMsgId: journal.lastProjectedDeltaMsgId,
            fetchCompleted: fetchSucceeded,
          );
        }
        final projectionStopwatch = Stopwatch()..start();
        var projectedDeltaMsgId = journal.lastProjectedDeltaMsgId;
        _traceExistingHistoryImport(
          'projection_start',
          fields: <String, Object?>{
            'accountId': accountId,
            'targetDeltaMsgId': journal.targetDeltaMsgId,
            'lastProjectedDeltaMsgId': journal.lastProjectedDeltaMsgId,
          },
        );
        try {
          projectedDeltaMsgId = await _projectExistingHistoryImportJournal(
            journal,
          );
        } finally {
          _traceExistingHistoryImport(
            'projection_end',
            fields: <String, Object?>{
              'accountId': accountId,
              'targetDeltaMsgId': journal.targetDeltaMsgId,
              'projectedDeltaMsgId': projectedDeltaMsgId,
              'elapsedMs': projectionStopwatch.elapsedMilliseconds,
            },
          );
        }
        await _saveDeltaProjectionCursor(
          scope: scope,
          accountId: accountId,
          deltaMsgId: projectedDeltaMsgId,
        );
      }
      final deferredStopwatch = Stopwatch()..start();
      _traceExistingHistoryImport(
        'deferred_work_start',
        fields: <String, Object?>{
          'projectionDeferred': _existingHistoryImportDeferredProjection,
          'contactsDeferred': _existingHistoryImportDeferredContactsSync,
        },
      );
      try {
        await _finishExistingHistoryImportDeferredWork();
        // Warning events are captured through the service Delta queue; wait for
        // currently delivered events before deciding whether the import completed.
        await _deltaOperationQueue;
        await _repairLocalEmailChatSummariesBestEffort();
      } finally {
        _traceExistingHistoryImport(
          'deferred_work_end',
          fields: <String, Object?>{
            'elapsedMs': deferredStopwatch.elapsedMilliseconds,
          },
        );
      }
      if (!fetchedExistingHistory ||
          _hasExistingHistoryImportFailureWarning()) {
        await _markExistingHistoryImportFetchIncomplete(
          scope: scope,
          accountIds: accountIds,
        );
        throw const EmailServiceExistingHistoryImportFetchFailedException();
      }
      await _completeExistingHistoryImport(
        scope: scope,
        accountIds: accountIds,
        source: _EmailSyncSource.bootstrapComplete,
      );
      _traceExistingHistoryImport(
        'complete',
        fields: <String, Object?>{
          'elapsedMs': importStopwatch.elapsedMilliseconds,
        },
      );
    } on Exception {
      _traceExistingHistoryImport(
        'failed',
        fields: <String, Object?>{
          'elapsedMs': importStopwatch.elapsedMilliseconds,
        },
      );
      await _restoreExistingHistoryImportPromptAfterFailure();
      rethrow;
    } finally {
      try {
        for (final accountId in enabledAccountIds.toList(growable: false)) {
          await _disableExistingHistoryImport(accountId);
        }
      } finally {
        _existingHistoryImportProjectionState =
            _ExistingHistoryImportProjectionState.idle;
      }
    }
  }

  Future<void> _completeExistingHistoryImport({
    required String scope,
    required Iterable<int> accountIds,
    required _EmailSyncSource source,
  }) async {
    for (final accountId in accountIds) {
      await _deleteExistingHistoryImportJournal(
        scope: scope,
        accountId: accountId,
      );
    }
    await _recordEmailHistoryImportPromptState(
      _emailHistoryImportPromptStatusAttemptFinished,
    );
    _setEmailHistoryImportPromptStatus(
      EmailHistoryImportPromptStatus.completed,
      source: source,
    );
    await _refreshConnectivityState(source: source);
  }

  Future<void> _restoreExistingHistoryImportPromptAfterFailure() async {
    _setEmailHistoryImportPromptStatus(
      EmailHistoryImportPromptStatus.failed,
      source: _EmailSyncSource.unknown,
    );
    try {
      await _refreshConnectivityState(source: _EmailSyncSource.unknown);
    } on Exception catch (error, stackTrace) {
      _log.fine(
        'Failed to refresh email connectivity after history import failure.',
        error,
        stackTrace,
      );
    }
    if (_syncState.status == EmailSyncStatus.recovering &&
        _syncState.historyImportPromptStatus.isVisible) {
      _updateSyncState(
        const EmailSyncState.ready().withHistoryImportPromptStatus(
          EmailHistoryImportPromptStatus.failed,
        ),
        source: _EmailSyncSource.unknown,
        preserveHistoryImportPromptStatus: false,
      );
    }
  }

  Future<void> _finishExistingHistoryImportDeferredWork() async {
    _existingHistoryImportProjectionState =
        _ExistingHistoryImportProjectionState.finalizingProjection;
    while (true) {
      final hadDeferredProjection = _existingHistoryImportDeferredProjection;
      final hadDeferredContactsSync =
          _existingHistoryImportDeferredContactsSync;
      if (!hadDeferredProjection && !hadDeferredContactsSync) {
        _existingHistoryImportProjectionState =
            _ExistingHistoryImportProjectionState.idle;
        return;
      }
      _existingHistoryImportDeferredProjection = false;
      _existingHistoryImportDeferredContactsSync = false;
      if (hadDeferredProjection) {
        await _syncIncrementalFromCore(
          allowExistingHistoryImportProjection: true,
        );
      }
      if (hadDeferredContactsSync) {
        await syncContactsFromCore();
      }
    }
  }

  bool _hasExistingHistoryImportFailureWarning() {
    for (final warning in _existingHistoryImportWarnings) {
      if (_isExistingHistoryImportFailureWarning(warning)) {
        return true;
      }
    }
    return false;
  }

  bool _isExistingHistoryImportFailureWarning(String warning) {
    return warning.contains(_existingHistoryImportFailureWarningMarker) ||
        warning.contains(_existingHistoryImportFailureWarningContext);
  }

  Future<void> _markExistingHistoryImportFetchIncomplete({
    required String scope,
    required Iterable<int> accountIds,
  }) async {
    for (final accountId in accountIds) {
      final journal = await _readExistingHistoryImportJournal(
        scope: scope,
        accountId: accountId,
      );
      if (journal == null || !journal.fetchCompleted) {
        continue;
      }
      await _saveExistingHistoryImportJournal(
        scope: scope,
        accountId: accountId,
        status: journal.status,
        watermarkDeltaMsgId: journal.watermarkDeltaMsgId,
        targetDeltaMsgId: journal.targetDeltaMsgId,
        lastProjectedDeltaMsgId: journal.lastProjectedDeltaMsgId,
        fetchCompleted: false,
      );
    }
  }

  Future<bool> _runExistingHistoryImportFetch(int accountId) async {
    await _requireDeltaDownloadLimit(accountIds: [accountId]);
    return _transport.performExistingHistoryImportFetch(
      _existingHistoryImportTimeout,
      accountId: accountId,
    );
  }

  Future<void> _enableExistingHistoryImport(int accountId) async {
    await _setRequiredDeltaCoreConfig(
      key: _fetchedExistingMsgsConfigKey,
      value: _fetchExistingMsgsDisabledValue,
      accountId: accountId,
    );
    await _setRequiredDeltaCoreConfig(
      key: _fetchExistingMsgsConfigKey,
      value: _fetchExistingMsgsEnabledValue,
      accountId: accountId,
    );
  }

  Future<void> _disableExistingHistoryImport(int accountId) =>
      _setRequiredDeltaCoreConfig(
        key: _fetchExistingMsgsConfigKey,
        value: _fetchExistingMsgsDisabledValue,
        accountId: accountId,
      );

  Future<EmailHistoryImportJournal> _ensureExistingHistoryImportJournal({
    required String scope,
    required int accountId,
    required bool resetProjection,
  }) async {
    final existing = await _readExistingHistoryImportJournal(
      scope: scope,
      accountId: accountId,
    );
    if (existing != null) {
      if (resetProjection ||
          _shouldResetExistingHistoryImportJournalProjection(existing)) {
        return _saveExistingHistoryImportJournal(
          scope: scope,
          accountId: accountId,
          status: _existingHistoryImportJournalStatusImporting,
          watermarkDeltaMsgId: existing.watermarkDeltaMsgId,
          targetDeltaMsgId: existing.targetDeltaMsgId,
          lastProjectedDeltaMsgId:
              _existingHistoryImportProjectionStartDeltaMsgId,
          fetchCompleted: resetProjection ? false : existing.fetchCompleted,
        );
      }
      return existing;
    }
    final watermarkDeltaMsgId = await _transport.maxMessageId(
      accountId: accountId,
    );
    return _saveExistingHistoryImportJournal(
      scope: scope,
      accountId: accountId,
      status: _existingHistoryImportJournalStatusImporting,
      watermarkDeltaMsgId: watermarkDeltaMsgId,
      targetDeltaMsgId: watermarkDeltaMsgId,
      lastProjectedDeltaMsgId: _existingHistoryImportProjectionStartDeltaMsgId,
      fetchCompleted: false,
    );
  }

  bool _shouldResetExistingHistoryImportJournalProjection(
    EmailHistoryImportJournal journal,
  ) {
    return journal.watermarkDeltaMsgId >
            _existingHistoryImportProjectionStartDeltaMsgId &&
        journal.lastProjectedDeltaMsgId >= journal.watermarkDeltaMsgId;
  }

  Future<EmailHistoryImportJournal?> _readExistingHistoryImportJournal({
    required String scope,
    required int accountId,
  }) {
    return _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      final EmailHistoryImportJournalStore? journalStore =
          db is EmailHistoryImportJournalStore
          ? db as EmailHistoryImportJournalStore
          : null;
      if (journalStore == null) {
        return null;
      }
      return journalStore.getEmailHistoryImportJournal(
        accountJid: scope,
        deltaAccountId: accountId,
      );
    });
  }

  Future<EmailHistoryImportJournal> _saveExistingHistoryImportJournal({
    required String scope,
    required int accountId,
    required String status,
    required int watermarkDeltaMsgId,
    required int targetDeltaMsgId,
    required int lastProjectedDeltaMsgId,
    required bool fetchCompleted,
  }) async {
    await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      final EmailHistoryImportJournalStore? journalStore =
          db is EmailHistoryImportJournalStore
          ? db as EmailHistoryImportJournalStore
          : null;
      if (journalStore == null) {
        return;
      }
      await journalStore.saveEmailHistoryImportJournal(
        accountJid: scope,
        deltaAccountId: accountId,
        status: status,
        watermarkDeltaMsgId: watermarkDeltaMsgId,
        targetDeltaMsgId: targetDeltaMsgId,
        lastProjectedDeltaMsgId: lastProjectedDeltaMsgId,
        fetchCompleted: fetchCompleted,
      );
    });
    return EmailHistoryImportJournal(
      accountJid: scope,
      deltaAccountId: accountId,
      status: status,
      watermarkDeltaMsgId: watermarkDeltaMsgId,
      targetDeltaMsgId: targetDeltaMsgId,
      lastProjectedDeltaMsgId: lastProjectedDeltaMsgId,
      fetchCompleted: fetchCompleted,
      updatedAt: DateTime.timestamp(),
    );
  }

  Future<void> _deleteExistingHistoryImportJournal({
    required String scope,
    required int accountId,
  }) {
    return _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      final EmailHistoryImportJournalStore? journalStore =
          db is EmailHistoryImportJournalStore
          ? db as EmailHistoryImportJournalStore
          : null;
      if (journalStore == null) {
        return;
      }
      await journalStore.deleteEmailHistoryImportJournal(
        accountJid: scope,
        deltaAccountId: accountId,
      );
    });
  }

  Future<int> _projectExistingHistoryImportJournal(
    EmailHistoryImportJournal journal,
  ) async {
    if (journal.targetDeltaMsgId <= journal.lastProjectedDeltaMsgId) {
      return journal.lastProjectedDeltaMsgId;
    }
    _existingHistoryImportProjectionState =
        _ExistingHistoryImportProjectionState.finalizingProjection;
    var cursor = journal.lastProjectedDeltaMsgId;
    Future<int> finishProjection() async {
      await _saveExistingHistoryImportJournal(
        scope: journal.accountJid,
        accountId: journal.deltaAccountId,
        status: _existingHistoryImportJournalStatusImporting,
        watermarkDeltaMsgId: journal.watermarkDeltaMsgId,
        targetDeltaMsgId: journal.targetDeltaMsgId,
        lastProjectedDeltaMsgId: journal.targetDeltaMsgId,
        fetchCompleted: journal.fetchCompleted,
      );
      return journal.targetDeltaMsgId;
    }

    while (cursor < journal.targetDeltaMsgId) {
      final pageStopwatch = Stopwatch()..start();
      _traceExistingHistoryImport(
        'projection_page_start',
        fields: <String, Object?>{
          'accountId': journal.deltaAccountId,
          'afterDeltaMsgId': cursor,
          'targetDeltaMsgId': journal.targetDeltaMsgId,
          'limit': _existingHistoryImportDeltaIdPageSize,
        },
      );
      final page = await _transport.messageIdsAfter(
        afterId: cursor,
        limit: _existingHistoryImportDeltaIdPageSize,
        accountId: journal.deltaAccountId,
      );
      _traceExistingHistoryImport(
        'projection_page_end',
        fields: <String, Object?>{
          'accountId': journal.deltaAccountId,
          'afterDeltaMsgId': cursor,
          'pageCount': page.length,
          'elapsedMs': pageStopwatch.elapsedMilliseconds,
        },
      );
      if (page.isEmpty) {
        return finishProjection();
      }
      final boundedPage = page
          .where((id) => id <= journal.targetDeltaMsgId)
          .toList(growable: false);
      if (boundedPage.isEmpty) {
        return finishProjection();
      }
      for (
        var index = 0;
        index < boundedPage.length;
        index += _existingHistoryImportProjectionBatchSize
      ) {
        final end =
            index + _existingHistoryImportProjectionBatchSize >
                boundedPage.length
            ? boundedPage.length
            : index + _existingHistoryImportProjectionBatchSize;
        final batch = boundedPage.sublist(index, end);
        final batchStopwatch = Stopwatch()..start();
        _traceExistingHistoryImport(
          'projection_batch_start',
          fields: <String, Object?>{
            'accountId': journal.deltaAccountId,
            'batchCount': batch.length,
            'firstDeltaMsgId': batch.first,
            'lastDeltaMsgId': batch.last,
          },
        );
        try {
          await _hydrateMessagesOnMain(
            batch,
            accountId: journal.deltaAccountId,
            allowExistingHistoryImportProjection: true,
          );
        } finally {
          _traceExistingHistoryImport(
            'projection_batch_end',
            fields: <String, Object?>{
              'accountId': journal.deltaAccountId,
              'batchCount': batch.length,
              'firstDeltaMsgId': batch.first,
              'lastDeltaMsgId': batch.last,
              'elapsedMs': batchStopwatch.elapsedMilliseconds,
            },
          );
        }
        cursor = batch.last;
        await _saveExistingHistoryImportJournal(
          scope: journal.accountJid,
          accountId: journal.deltaAccountId,
          status: _existingHistoryImportJournalStatusImporting,
          watermarkDeltaMsgId: journal.watermarkDeltaMsgId,
          targetDeltaMsgId: journal.targetDeltaMsgId,
          lastProjectedDeltaMsgId: cursor,
          fetchCompleted: journal.fetchCompleted,
        );
        await _yieldAfterExistingHistoryImportProjectionBatch();
      }
      if (page.length < _existingHistoryImportDeltaIdPageSize ||
          boundedPage.length < page.length) {
        return finishProjection();
      }
    }
    return cursor;
  }

  Future<void> _yieldAfterExistingHistoryImportProjectionBatch() {
    return Future<void>.delayed(_existingHistoryImportProjectionYieldDelay);
  }

  Future<void> _recordEmailHistoryImportPromptState(String status) async {
    final scope = _activeCredentialScope;
    if (scope == null) {
      return;
    }
    await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      final LocalPromptStateStore? promptStore = db is LocalPromptStateStore
          ? db as LocalPromptStateStore
          : null;
      if (promptStore == null) {
        return;
      }
      await promptStore.saveLocalPromptState(
        accountJid: scope,
        promptId: _emailHistoryImportPromptId,
        status: status,
      );
    });
  }

  Future<bool> _emailHistoryImportPromptAttemptFinished() async {
    final scope = _activeCredentialScope;
    if (scope == null) {
      return true;
    }
    return _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      final LocalPromptStateStore? promptStore = db is LocalPromptStateStore
          ? db as LocalPromptStateStore
          : null;
      if (promptStore == null) {
        return true;
      }
      final status = await promptStore.getLocalPromptState(
        accountJid: scope,
        promptId: _emailHistoryImportPromptId,
      );
      return status == _emailHistoryImportPromptStatusAttemptFinished ||
          status == _emailHistoryImportPromptStatusCompleted;
    });
  }

  bool _emailHistoryImportPromptSnoozed() {
    final scope = _activeCredentialScope;
    return scope != null &&
        _emailHistoryImportPromptSnoozedScopes.contains(scope);
  }

  Future<void> _refreshEmailHistoryImportPromptStatus() async {
    if (!_endpointConfig.smtpEnabled ||
        _activeCredentialScope == null ||
        !hasActiveSession) {
      _setEmailHistoryImportPromptStatus(
        EmailHistoryImportPromptStatus.hidden,
        source: _EmailSyncSource.unknown,
      );
      return;
    }
    if (_syncState.historyImportPromptStatus.isImporting ||
        _syncState.historyImportPromptStatus.isCompleted ||
        _syncState.historyImportPromptStatus.isFailed) {
      return;
    }
    if (_emailHistoryImportPromptSnoozed() ||
        await _emailHistoryImportPromptAttemptFinished()) {
      _setEmailHistoryImportPromptStatus(
        EmailHistoryImportPromptStatus.hidden,
        source: _EmailSyncSource.unknown,
      );
      return;
    }
    _setEmailHistoryImportPromptStatus(
      EmailHistoryImportPromptStatus.visible,
      source: _EmailSyncSource.unknown,
    );
  }

  void _activateCredentialAccount({
    required String scope,
    required EmailAccount account,
  }) {
    _emailHistoryImportPromptSnoozedScopes.remove(scope);
    _credentialSession.activateAccount(scope: scope, account: account);
  }

  Future<void> setForegroundKeepalive(bool enabled) async {
    if (!enabled) {
      await _stopForegroundKeepalive();
      if (hasActiveSession) {
        _startImapSyncLoop();
      }
      return;
    }
    if (!hasActiveSession) {
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
  EmailDeltaRuntime get debugTransportForTest => _transport;

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
    final db = await _databaseBuilder();
    final initial = await db.getChatMessages(
      jid,
      start: start,
      end: end,
      filter: filter,
    );
    yield initial;
    var previousMessages = List<Message>.unmodifiable(initial);
    await for (final messages in db.watchChatMessages(
      jid,
      start: start,
      end: end,
      filter: filter,
    )) {
      if (listEquals(previousMessages, messages)) {
        continue;
      }
      previousMessages = List<Message>.unmodifiable(messages);
      yield messages;
    }
  }

  Future<List<Message>> loadChatMessagesBefore({
    required String jid,
    required DateTime beforeTimestamp,
    required String beforeStanzaId,
    int? beforeDeltaMsgId,
    required int limit,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
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

  Future<Message?> loadOldestUnreadEmailBackedMessageForChat(
    Chat chat, {
    String? selfJid,
    String? emailSelfJid,
    int? unreadCount,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    if ((unreadCount ?? chat.unreadCount) <= _emptyUnreadCount) {
      return null;
    }
    final db = await _databaseBuilder();
    return db.getOldestUnreadEmailBackedMessageForChat(
      chat.jid,
      selfJid: selfJid,
      emailSelfJid: emailSelfJid,
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
    final eventType = DeltaEventType.fromCode(event.type);
    if (eventType == DeltaEventType.warning &&
        _existingHistoryImportTask != null) {
      final warning = event.data2Text ?? event.data1Text;
      if (warning != null && warning.trim().isNotEmpty) {
        _existingHistoryImportWarnings.add(warning);
      }
    }
    if (eventType != null &&
        _shouldDeferExistingHistoryImportDeltaProjection(eventType)) {
      _markExistingHistoryImportProjectionDeferred(eventType);
      return;
    }
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

  bool _shouldDeferExistingHistoryImportCatchUpProjection(
    _EmailCatchUpReason reason,
  ) {
    if (!_blocksExistingHistoryImportProjection) {
      return false;
    }
    switch (reason) {
      case _EmailCatchUpReason.mailPushHint:
      case _EmailCatchUpReason.homeUnreadRefresh:
      case _EmailCatchUpReason.homeHistoryRefresh:
      case _EmailCatchUpReason.syncInboxAndSent:
      case _EmailCatchUpReason.periodicIdleTick:
      case _EmailCatchUpReason.backgroundFetchDone:
      case _EmailCatchUpReason.incomingMsgBunch:
      case _EmailCatchUpReason.channelOverflow:
      case _EmailCatchUpReason.foregroundResume:
      case _EmailCatchUpReason.reconnectCatchUp:
        return true;
    }
  }

  bool _shouldDeferExistingHistoryImportDeltaProjection(
    DeltaEventType eventType,
  ) {
    if (!_blocksExistingHistoryImportProjection) {
      return false;
    }
    switch (eventType) {
      case DeltaEventType.msgsChanged:
      case DeltaEventType.reactionsChanged:
      case DeltaEventType.incomingReaction:
      case DeltaEventType.incomingWebxdcNotify:
      case DeltaEventType.msgsNoticed:
      case DeltaEventType.incomingMsg:
      case DeltaEventType.incomingMsgBunch:
      case DeltaEventType.msgDelivered:
      case DeltaEventType.msgFailed:
      case DeltaEventType.msgRead:
      case DeltaEventType.chatModified:
      case DeltaEventType.accountsBackgroundFetchDone:
      case DeltaEventType.channelOverflow:
      case DeltaEventType.contactsChanged:
        return true;
      case DeltaEventType.warning:
      case DeltaEventType.error:
      case DeltaEventType.errorSelfNotInGroup:
      case DeltaEventType.chatDeleted:
      case DeltaEventType.configureProgress:
      case DeltaEventType.imexProgress:
      case DeltaEventType.imexFileWritten:
      case DeltaEventType.connectivityChanged:
        return false;
    }
  }

  void _markExistingHistoryImportProjectionDeferred(DeltaEventType eventType) {
    if (!_blocksExistingHistoryImportProjection) {
      return;
    }
    if (eventType == DeltaEventType.contactsChanged) {
      _existingHistoryImportDeferredContactsSync = true;
    } else {
      _existingHistoryImportDeferredProjection = true;
    }
  }

  bool get _blocksExistingHistoryImportProjection =>
      _existingHistoryImportProjectionState !=
      _ExistingHistoryImportProjectionState.idle;

  bool _blocksExistingHistoryImportProjectionCall({
    required bool allowExistingHistoryImportProjection,
  }) {
    if (!_blocksExistingHistoryImportProjection) {
      return false;
    }
    return !allowExistingHistoryImportProjection ||
        _existingHistoryImportProjectionState !=
            _ExistingHistoryImportProjectionState.finalizingProjection;
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
    if (accountId == null || accountId == DeltaAccountDefaults.legacyId) {
      _log.fine('Skipping Delta event persistence without account id.');
      return;
    }
    final consumer = _deltaConsumerForAccount(accountId);
    await consumer.handle(event);
  }

  int? _deltaAccountIdForEvent(DeltaCoreEvent event) {
    final accountId = event.accountId;
    if (accountId == null) {
      return null;
    }
    if (!_transport.accountsActive) {
      final activeAccountId = _transport.activeAccountId;
      if (activeAccountId != DeltaAccountDefaults.legacyId) {
        return activeAccountId;
      }
      return DeltaAccountDefaults.singleContextId;
    }
    return accountId;
  }

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
        shouldDeferProjectionForEvent:
            _shouldDeferExistingHistoryImportDeltaProjection,
        onProjectionDeferred: _markExistingHistoryImportProjectionDeferred,
        logger: _log,
        databaseOperationTracker: _trackAppDatabaseOperation,
      ),
    );
  }

  Future<bool> _bootstrapFromCoreOnMain({
    bool includeMessages = false,
    bool allowExistingHistoryImportProjection = false,
  }) async {
    if (_blocksExistingHistoryImportProjectionCall(
      allowExistingHistoryImportProjection:
          allowExistingHistoryImportProjection,
    )) {
      _existingHistoryImportDeferredProjection = true;
      return false;
    }
    final traceId = _nextTraceId('email.bootstrapFromCoreOnMain');
    final stopwatch = Stopwatch()..start();
    _traceEmailOperation(
      'email.bootstrapFromCoreOnMain',
      'start',
      id: traceId,
      fields: <String, Object?>{'includeMessages': includeMessages},
    );
    final accountIds = _usableDeltaAccountIds(await _transport.accountIds());
    _traceEmailOperation(
      'email.bootstrapFromCoreOnMain.accounts',
      'end',
      id: traceId,
      fields: <String, Object?>{
        'accountCount': accountIds.length,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
    var didBootstrap = false;
    for (final accountId in accountIds) {
      final accountWatch = Stopwatch()..start();
      await _transport.ensureAccountSession(accountId);
      final consumer = _deltaConsumerForAccount(accountId);
      if (await consumer.bootstrapFromCore(includeMessages: includeMessages)) {
        didBootstrap = true;
      }
      _traceEmailOperation(
        'email.bootstrapFromCoreOnMain.account',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'accountId': accountId,
          'elapsedMs': accountWatch.elapsedMilliseconds,
        },
      );
    }
    _traceEmailOperation(
      'email.bootstrapFromCoreOnMain',
      'end',
      id: traceId,
      fields: <String, Object?>{
        'didBootstrap': didBootstrap,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
    return didBootstrap;
  }

  Future<void> _refreshChatlistSnapshotOnMain({int? accountId}) async {
    final traceId = _nextTraceId('email.chatlistSnapshot');
    final stopwatch = Stopwatch()..start();
    _traceEmailOperation(
      'email.chatlistSnapshot',
      'start',
      id: traceId,
      fields: <String, Object?>{'accountId': accountId},
    );
    final accountIds = await _deltaAccountIdsForScope(accountId);
    _traceEmailOperation(
      'email.chatlistSnapshot.accounts',
      'end',
      id: traceId,
      fields: <String, Object?>{
        'accountCount': accountIds.length,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
    for (final resolvedAccountId in accountIds) {
      final accountWatch = Stopwatch()..start();
      await _transport.ensureAccountSession(resolvedAccountId);
      await _repairStoredDeltaProjectionForCursor(
        scope: _activeCredentialScope,
        accountId: resolvedAccountId,
      );
      await _deltaConsumerForAccount(
        resolvedAccountId,
      ).refreshChatlistSnapshot();
      _traceEmailOperation(
        'email.chatlistSnapshot.account',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'accountId': resolvedAccountId,
          'elapsedMs': accountWatch.elapsedMilliseconds,
        },
      );
    }
    _traceEmailOperation(
      'email.chatlistSnapshot',
      'end',
      id: traceId,
      fields: <String, Object?>{'elapsedMs': stopwatch.elapsedMilliseconds},
    );
    _recordChatlistRefreshCompleted(accountId: accountId);
  }

  bool _shouldPrepareDeltaProjectionCursorBeforeFetch(
    _EmailCatchUpReason reason,
  ) {
    switch (reason) {
      case _EmailCatchUpReason.homeUnreadRefresh:
      case _EmailCatchUpReason.homeHistoryRefresh:
        return true;
      case _EmailCatchUpReason.mailPushHint:
      case _EmailCatchUpReason.syncInboxAndSent:
      case _EmailCatchUpReason.periodicIdleTick:
      case _EmailCatchUpReason.backgroundFetchDone:
      case _EmailCatchUpReason.incomingMsgBunch:
      case _EmailCatchUpReason.foregroundResume:
      case _EmailCatchUpReason.channelOverflow:
      case _EmailCatchUpReason.reconnectCatchUp:
        return false;
    }
  }

  bool _shouldProjectDeltaMessageCursorForCatchUp(_EmailCatchUpReason reason) {
    switch (reason) {
      case _EmailCatchUpReason.homeUnreadRefresh:
      case _EmailCatchUpReason.homeHistoryRefresh:
        return true;
      case _EmailCatchUpReason.mailPushHint:
      case _EmailCatchUpReason.syncInboxAndSent:
      case _EmailCatchUpReason.periodicIdleTick:
      case _EmailCatchUpReason.backgroundFetchDone:
      case _EmailCatchUpReason.incomingMsgBunch:
      case _EmailCatchUpReason.foregroundResume:
      case _EmailCatchUpReason.channelOverflow:
      case _EmailCatchUpReason.reconnectCatchUp:
        return false;
    }
  }

  Future<void> _ensureDeltaProjectionCursorsForCatchUp() async {
    final scope = _activeCredentialScope;
    if (scope == null) {
      return;
    }
    final accountIds = await _deltaAccountIdsForScope(null);
    for (final accountId in accountIds) {
      await _transport.ensureAccountSession(accountId);
      final cursor = await _readDeltaProjectionCursor(
        scope: scope,
        accountId: accountId,
      );
      if (cursor == null) {
        await _ensureDeltaProjectionCursor(scope: scope, accountId: accountId);
        continue;
      }
      await _repairStoredDeltaProjectionForCursor(
        scope: scope,
        accountId: accountId,
        cursor: cursor,
      );
    }
  }

  Future<int> _ensureDeltaProjectionCursor({
    required String scope,
    required int accountId,
  }) async {
    final cursor = await _readDeltaProjectionCursor(
      scope: scope,
      accountId: accountId,
    );
    if (cursor != null) {
      return cursor;
    }
    final maxMessageId = await _transport.maxMessageId(accountId: accountId);
    await _saveDeltaProjectionCursor(
      scope: scope,
      accountId: accountId,
      deltaMsgId: maxMessageId,
    );
    return maxMessageId;
  }

  Future<int?> _readDeltaProjectionCursor({
    required String scope,
    required int accountId,
  }) {
    return _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      final LocalPromptStateStore? promptStore = db is LocalPromptStateStore
          ? db as LocalPromptStateStore
          : null;
      if (promptStore == null) {
        return null;
      }
      final stored = await promptStore.getLocalPromptState(
        accountJid: scope,
        promptId: _deltaProjectionCursorPromptId(accountId),
      );
      final parsed = int.tryParse(stored ?? '');
      return parsed == null || parsed < 0 ? null : parsed;
    });
  }

  Future<void> _saveDeltaProjectionCursor({
    required String scope,
    required int accountId,
    required int deltaMsgId,
  }) {
    return _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      final LocalPromptStateStore? promptStore = db is LocalPromptStateStore
          ? db as LocalPromptStateStore
          : null;
      if (promptStore == null) {
        return;
      }
      await promptStore.saveLocalPromptState(
        accountJid: scope,
        promptId: _deltaProjectionCursorPromptId(accountId),
        status: deltaMsgId.toString(),
      );
    });
  }

  Future<void> _repairStoredDeltaProjectionForCursor({
    required String? scope,
    required int accountId,
    int? cursor,
  }) async {
    final resolvedScope = scope?.trim();
    if (resolvedScope == null || resolvedScope.isEmpty) {
      return;
    }
    if (_existingHistoryImportProjectionState !=
        _ExistingHistoryImportProjectionState.idle) {
      return;
    }
    final targetDeltaMsgId =
        cursor ??
        await _readDeltaProjectionCursor(
          scope: resolvedScope,
          accountId: accountId,
        );
    if (targetDeltaMsgId == null ||
        targetDeltaMsgId <= _existingHistoryImportProjectionStartDeltaMsgId) {
      return;
    }
    final repairKey = '$resolvedScope:$accountId:$targetDeltaMsgId';
    if (!_deltaProjectionCursorRepairCompletedKeys.add(repairKey)) {
      return;
    }
    final stopwatch = Stopwatch()..start();
    var repairedCount = 0;
    _traceEmailOperation(
      'email.deltaProjectionRepair',
      'start',
      fields: <String, Object?>{
        'accountId': accountId,
        'targetDeltaMsgId': targetDeltaMsgId,
      },
    );
    var completed = false;
    try {
      repairedCount = await _repairMissingStoredDeltaProjectionRange(
        accountId: accountId,
        targetDeltaMsgId: targetDeltaMsgId,
      );
      completed = true;
    } finally {
      if (!completed) {
        _deltaProjectionCursorRepairCompletedKeys.remove(repairKey);
      }
      _traceEmailOperation(
        'email.deltaProjectionRepair',
        'end',
        fields: <String, Object?>{
          'accountId': accountId,
          'targetDeltaMsgId': targetDeltaMsgId,
          'repairedCount': repairedCount,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
    }
  }

  Future<int> _repairMissingStoredDeltaProjectionRange({
    required int accountId,
    required int targetDeltaMsgId,
  }) async {
    var cursor = _existingHistoryImportProjectionStartDeltaMsgId;
    var repairedCount = 0;
    while (cursor < targetDeltaMsgId) {
      final page = await _transport.messageIdsAfter(
        afterId: cursor,
        limit: _existingHistoryImportDeltaIdPageSize,
        accountId: accountId,
      );
      if (page.isEmpty) {
        return repairedCount;
      }
      final boundedPage = page
          .where((id) => id <= targetDeltaMsgId)
          .toList(growable: false);
      if (boundedPage.isEmpty) {
        return repairedCount;
      }
      final missingIds = await _missingStoredDeltaMessageIds(
        boundedPage,
        accountId: accountId,
      );
      if (missingIds.isNotEmpty) {
        await _hydrateMessagesOnMain(
          missingIds,
          accountId: accountId,
          allowExistingHistoryImportProjection: true,
        );
        repairedCount += missingIds.length;
        await _yieldAfterExistingHistoryImportProjectionBatch();
      }
      cursor = boundedPage.last;
      if (page.length < _existingHistoryImportDeltaIdPageSize ||
          boundedPage.length < page.length) {
        return repairedCount;
      }
    }
    return repairedCount;
  }

  Future<List<int>> _missingStoredDeltaMessageIds(
    List<int> deltaMsgIds, {
    required int accountId,
  }) async {
    if (deltaMsgIds.isEmpty) {
      return const <int>[];
    }
    final db = await _databaseBuilder();
    final stored = await db.getMessagesByDeltaIds(
      deltaMsgIds,
      deltaAccountId: accountId,
    );
    final storedIds = <int>{};
    for (final message in stored) {
      final deltaMsgId = message.deltaMsgId;
      if (deltaMsgId != null) {
        storedIds.add(deltaMsgId);
      }
    }
    return deltaMsgIds
        .where((deltaMsgId) => !storedIds.contains(deltaMsgId))
        .toList(growable: false);
  }

  Future<_EmailFreshProjectionResult> _syncIncrementalFromCore({
    bool Function()? isStillRelevant,
    bool allowExistingHistoryImportProjection = false,
  }) async {
    final projectedMessageCount = await _projectNewDeltaMessagesFromCore(
      isStillRelevant: isStillRelevant,
      allowExistingHistoryImportProjection:
          allowExistingHistoryImportProjection,
    );
    final freshProjection = await _syncFreshFromCore(
      isStillRelevant: isStillRelevant,
      allowExistingHistoryImportProjection:
          allowExistingHistoryImportProjection,
    );
    return _EmailFreshProjectionResult(
      freshIdCount: freshProjection.freshIdCount,
      syncedMessageCount:
          freshProjection.syncedMessageCount + projectedMessageCount,
      affectedChatCount: freshProjection.affectedChatCount,
    );
  }

  Future<int> _projectNewDeltaMessagesFromCore({
    bool Function()? isStillRelevant,
    bool allowExistingHistoryImportProjection = false,
  }) async {
    if (_blocksExistingHistoryImportProjectionCall(
      allowExistingHistoryImportProjection:
          allowExistingHistoryImportProjection,
    )) {
      _existingHistoryImportDeferredProjection = true;
      return 0;
    }
    bool cancelled() => isStillRelevant?.call() == false;
    if (!await _ensureBackgroundSyncReady()) {
      return 0;
    }
    final scope = _activeCredentialScope;
    if (scope == null) {
      return 0;
    }
    var projectedCount = 0;
    final accountIds = await _deltaAccountIdsForScope(null);
    for (final accountId in accountIds) {
      if (cancelled()) {
        break;
      }
      await _transport.ensureAccountSession(accountId);
      final existingCursor = await _readDeltaProjectionCursor(
        scope: scope,
        accountId: accountId,
      );
      if (existingCursor == null) {
        await _ensureDeltaProjectionCursor(scope: scope, accountId: accountId);
        continue;
      }
      var cursor = existingCursor;
      final targetDeltaMsgId = await _transport.maxMessageId(
        accountId: accountId,
      );
      while (cursor < targetDeltaMsgId && !cancelled()) {
        final page = await _transport.messageIdsAfter(
          afterId: cursor,
          limit: _existingHistoryImportDeltaIdPageSize,
          accountId: accountId,
        );
        if (page.isEmpty) {
          await _saveDeltaProjectionCursor(
            scope: scope,
            accountId: accountId,
            deltaMsgId: targetDeltaMsgId,
          );
          break;
        }
        final boundedPage = page
            .where((id) => id <= targetDeltaMsgId)
            .toList(growable: false);
        if (boundedPage.isEmpty) {
          await _saveDeltaProjectionCursor(
            scope: scope,
            accountId: accountId,
            deltaMsgId: targetDeltaMsgId,
          );
          break;
        }
        for (
          var index = 0;
          index < boundedPage.length && !cancelled();
          index += _existingHistoryImportProjectionBatchSize
        ) {
          final end =
              index + _existingHistoryImportProjectionBatchSize >
                  boundedPage.length
              ? boundedPage.length
              : index + _existingHistoryImportProjectionBatchSize;
          final batch = boundedPage.sublist(index, end);
          await _hydrateMessagesOnMain(
            batch,
            accountId: accountId,
            allowExistingHistoryImportProjection:
                allowExistingHistoryImportProjection,
          );
          cursor = batch.last;
          projectedCount += batch.length;
          await _saveDeltaProjectionCursor(
            scope: scope,
            accountId: accountId,
            deltaMsgId: cursor,
          );
          await _yieldAfterExistingHistoryImportProjectionBatch();
        }
        if (page.length < _existingHistoryImportDeltaIdPageSize ||
            boundedPage.length < page.length) {
          break;
        }
      }
    }
    return projectedCount;
  }

  Future<_EmailFreshProjectionResult> _syncFreshFromCore({
    bool Function()? isStillRelevant,
    bool allowExistingHistoryImportProjection = false,
  }) async {
    if (_blocksExistingHistoryImportProjectionCall(
      allowExistingHistoryImportProjection:
          allowExistingHistoryImportProjection,
    )) {
      _existingHistoryImportDeferredProjection = true;
      return const _EmailFreshProjectionResult();
    }
    bool cancelled() => isStillRelevant?.call() == false;
    final traceId = _nextTraceId('email.freshProjection');
    final stopwatch = Stopwatch()..start();
    _traceEmailOperation(
      'email.freshProjection',
      'start',
      id: traceId,
      fields: <String, Object?>{
        'runtime': _runtimePhase.name,
        'hasSession': hasActiveSession,
      },
    );
    if (!await _ensureBackgroundSyncReady()) {
      _traceEmailOperation(
        'email.freshProjection',
        'skip',
        id: traceId,
        fields: <String, Object?>{
          'reason': 'backgroundSyncNotReady',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return const _EmailFreshProjectionResult();
    }

    var syncedCount = 0;
    var freshIdCount = 0;
    var affectedChatCount = 0;
    final accountIds = await _deltaAccountIdsForScope(null);
    for (final accountId in accountIds) {
      if (cancelled()) {
        break;
      }
      final accountWatch = Stopwatch()..start();
      await _transport.ensureAccountSession(accountId);
      final freshIds = await _transport.getFreshMessageIds(
        accountId: accountId,
      );
      freshIdCount += freshIds.length;
      var accountSyncedCount = 0;
      var accountAffectedChatCount = 0;
      if (freshIds.isNotEmpty && !cancelled()) {
        final syncResult = await _deltaConsumerForAccount(
          accountId,
        ).syncFreshMessages(freshIds, isCurrent: isStillRelevant);
        accountSyncedCount = syncResult.hydratedCount;
        accountAffectedChatCount = syncResult.affectedChatCount;
        syncedCount += accountSyncedCount;
        affectedChatCount += accountAffectedChatCount;
      }
      _traceEmailOperation(
        'email.freshProjection.account',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'accountId': accountId,
          'freshIdCount': freshIds.length,
          'syncedMessageCount': accountSyncedCount,
          'affectedChatCount': accountAffectedChatCount,
          'elapsedMs': accountWatch.elapsedMilliseconds,
        },
      );
    }
    _traceEmailOperation(
      'email.freshProjection',
      'end',
      id: traceId,
      fields: <String, Object?>{
        'accountCount': accountIds.length,
        'freshIdCount': freshIdCount,
        'syncedMessageCount': syncedCount,
        'affectedChatCount': affectedChatCount,
        'cancelled': cancelled(),
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
    return _EmailFreshProjectionResult(
      freshIdCount: freshIdCount,
      syncedMessageCount: syncedCount,
      affectedChatCount: affectedChatCount,
    );
  }

  Future<void> _refreshStartupChatlistSnapshot({required int accountId}) async {
    try {
      await refreshChatlistFromCore(
        source: 'startup',
        force: true,
        accountId: accountId,
      );
    } on Exception catch (error, stackTrace) {
      _log.fine('Email startup chatlist refresh failed.', error, stackTrace);
    }
  }

  Future<void> _hydrateMessagesOnMain(
    List<int> messageIds, {
    int? accountId,
    bool allowExistingHistoryImportProjection = false,
  }) async {
    if (_blocksExistingHistoryImportProjectionCall(
      allowExistingHistoryImportProjection:
          allowExistingHistoryImportProjection,
    )) {
      _existingHistoryImportDeferredProjection = true;
      return;
    }
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
    final affectedChatJids = <String>{};
    for (var index = 0; index < messageIds.length; index += batchSize) {
      final chunk = messageIds.skip(index).take(batchSize).toList();
      final results = await Future.wait(
        chunk.map(
          (messageId) => consumer.hydrateMessage(
            messageId,
            deferRfc822BodyContent: allowExistingHistoryImportProjection,
          ),
        ),
      );
      for (final result in results) {
        if (result == null || !result.affectsUserChat) {
          continue;
        }
        final chatJid = result.chatJid?.trim();
        if (chatJid != null && chatJid.isNotEmpty) {
          affectedChatJids.add(chatJid);
        }
      }
    }
    if (affectedChatJids.isEmpty) {
      return;
    }
    final db = await _databaseBuilder();
    for (final chatJid in affectedChatJids) {
      await db.repairChatSummaryFromMessages(chatJid);
    }
  }

  Future<List<int>> _deltaAccountIdsForScope(int? accountId) async {
    final accountIds = _usableDeltaAccountIds(await _transport.accountIds());
    if (accountId != null) {
      if (accountId == DeltaAccountDefaults.legacyId) {
        return accountIds;
      }
      return accountIds.contains(accountId) ? <int>[accountId] : const <int>[];
    }
    return accountIds;
  }

  Future<void> _processDeltaEvent(DeltaCoreEvent event) async {
    final eventType = DeltaEventType.fromCode(event.type);
    if (eventType == null) {
      return;
    }
    final traceDeltaEvent = _shouldTraceDeltaEvent(eventType);
    final traceId = traceDeltaEvent ? _nextTraceId('email.deltaEvent') : null;
    final stopwatch = traceDeltaEvent ? (Stopwatch()..start()) : null;
    if (traceId != null) {
      _traceEmailOperation(
        'email.deltaEvent',
        'start',
        id: traceId,
        fields: <String, Object?>{
          'type': eventType.name,
          'accountId': event.accountId,
          'data1': event.data1,
          'data2': event.data2,
        },
      );
    }
    int? eventAccountId() {
      final accountId = _deltaAccountIdForEvent(event);
      if (accountId == null) {
        _log.fine('Skipping ${eventType.name} Delta event without account id.');
      }
      return accountId;
    }

    try {
      switch (eventType) {
        case DeltaEventType.warning:
          _log.fine(event.data2Text ?? event.data1Text ?? 'Delta warning.');
          break;
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
          await _requestEmailCatchUp(_EmailCatchUpReason.incomingMsgBunch);
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
          break;
        case DeltaEventType.connectivityChanged:
          await _refreshConnectivityState(
            source: _EmailSyncSource.connectivityChangedEvent,
          );
          break;
        case DeltaEventType.channelOverflow:
          await _handleChannelOverflow();
          break;
        default:
          break;
      }
    } finally {
      if (traceId != null && stopwatch != null) {
        _traceEmailOperation(
          'email.deltaEvent',
          'end',
          id: traceId,
          fields: <String, Object?>{
            'type': eventType.name,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
      }
    }
  }

  bool _shouldTraceDeltaEvent(DeltaEventType eventType) {
    switch (eventType) {
      case DeltaEventType.incomingMsg:
      case DeltaEventType.incomingMsgBunch:
      case DeltaEventType.msgsChanged:
      case DeltaEventType.chatModified:
      case DeltaEventType.accountsBackgroundFetchDone:
      case DeltaEventType.channelOverflow:
      case DeltaEventType.error:
      case DeltaEventType.errorSelfNotInGroup:
        return true;
      default:
        return false;
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
    final stored = await db.getMessageByDeltaId(
      id.msgId,
      deltaAccountId: id.accountId,
    );
    if (stored != null && _storedDeltaLocatorMatches(stored, id)) {
      return stored;
    }
    return null;
  }

  bool _storedDeltaLocatorMatches(Message message, _DeltaChatMessageId id) {
    return message.deltaMsgId == id.msgId &&
        message.deltaAccountId == id.accountId;
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
      if (!_canProcessDeltaWork) {
        return;
      }
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
        'dc-msg-$msgId accountId=$accountId',
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
        'dc-msg-$msgId accountId=$accountId',
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
        'dc-msg-$msgId accountId=$accountId',
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
    final active = _connectivityRefreshTask;
    if (active != null &&
        source == _EmailSyncSource.connectivityChangedEvent &&
        !recoveryCompleted) {
      return active;
    }
    if (_canReuseHealthyConnectivitySample(
      source: source,
      recoveryCompleted: recoveryCompleted,
    )) {
      return _lastConnectivityValue;
    }
    final task = _refreshConnectivityStateExclusive(
      source: source,
      recoveryCompleted: recoveryCompleted,
    );
    _connectivityRefreshTask = task;
    try {
      return await task;
    } finally {
      if (identical(_connectivityRefreshTask, task)) {
        _connectivityRefreshTask = null;
      }
    }
  }

  bool _canReuseHealthyConnectivitySample({
    required _EmailSyncSource source,
    required bool recoveryCompleted,
  }) {
    if (source != _EmailSyncSource.connectivityChangedEvent ||
        recoveryCompleted ||
        _syncState.status != EmailSyncStatus.ready) {
      return false;
    }
    final connectivity = _lastConnectivityValue;
    final readAt = _lastHealthyConnectivityReadAt;
    if (connectivity == null ||
        connectivity < _connectivityWorkingMin ||
        readAt == null) {
      return false;
    }
    return DateTime.timestamp().difference(readAt) <
        _connectivityHealthyReadReuseWindow;
  }

  Future<int?> _refreshConnectivityStateExclusive({
    _EmailSyncSource source = _EmailSyncSource.unknown,
    bool recoveryCompleted = false,
  }) async {
    final traceId = _nextTraceId('email.connectivity');
    final stopwatch = Stopwatch()..start();
    final suppressedEvents = _suppressedConnectivityChangedEvents;
    _suppressedConnectivityChangedEvents = 0;
    _traceEmailOperation(
      'email.connectivity',
      'start',
      id: traceId,
      fields: <String, Object?>{
        'source': source.logLabel,
        'recoveryCompleted': recoveryCompleted,
        'runtime': _runtimePhase.name,
        'suppressedConnectivityEvents': suppressedEvents,
      },
    );
    if (!_acceptsRuntimeWork) {
      _traceEmailOperation(
        'email.connectivity',
        'skip',
        id: traceId,
        fields: <String, Object?>{
          'reason': 'runtimeNotRunning',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return null;
    }
    try {
      final connectivity = await _readTransportConnectivity(source: source);
      _traceEmailOperation(
        'email.connectivity',
        'read',
        id: traceId,
        fields: <String, Object?>{
          'source': source.logLabel,
          'connectivity': connectivity,
          'syncStatus': _syncState.status.name,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      if (!_acceptsRuntimeWork) {
        _traceEmailOperation(
          'email.connectivity',
          'skip',
          id: traceId,
          fields: <String, Object?>{
            'reason': 'runtimeStoppedAfterRead',
            'connectivity': connectivity,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
        return null;
      }
      if (connectivity == null) {
        _traceEmailOperation(
          'email.connectivity',
          'end',
          id: traceId,
          fields: <String, Object?>{
            'result': 'null',
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
        return null;
      }
      _recordConnectivitySample(connectivity: connectivity, source: source);
      await _maybeLogConnectingConnectivityDetail(
        connectivity: connectivity,
        source: source,
      );
      if (recoveryCompleted && connectivity >= _connectivityWorkingMin) {
        _cancelConnectivityDowngrade();
        _updateSyncState(const EmailSyncState.ready(), source: source);
        _traceEmailOperation(
          'email.connectivity',
          'end',
          id: traceId,
          fields: <String, Object?>{
            'result': 'recoveryCompleted',
            'connectivity': connectivity,
            'syncStatus': _syncState.status.name,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
        return connectivity;
      }
      if (connectivity >= _connectivityConnectedMin) {
        _cancelConnectivityDowngrade();
        _updateSyncState(const EmailSyncState.ready(), source: source);
        _traceEmailOperation(
          'email.connectivity',
          'end',
          id: traceId,
          fields: <String, Object?>{
            'result': 'connected',
            'connectivity': connectivity,
            'syncStatus': _syncState.status.name,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
        return connectivity;
      }
      if (connectivity >= _connectivityWorkingMin) {
        _cancelConnectivityDowngrade();
        if (_syncState.status == EmailSyncStatus.ready) {
          _traceEmailOperation(
            'email.connectivity',
            'end',
            id: traceId,
            fields: <String, Object?>{
              'result': 'workingAlreadyReady',
              'connectivity': connectivity,
              'syncStatus': _syncState.status.name,
              'elapsedMs': stopwatch.elapsedMilliseconds,
            },
          );
          return connectivity;
        }
        _updateSyncState(
          EmailSyncState.recovering(_l10n.emailSyncMessageSyncing),
          source: source,
        );
        _traceEmailOperation(
          'email.connectivity',
          'end',
          id: traceId,
          fields: <String, Object?>{
            'result': 'workingRecovering',
            'connectivity': connectivity,
            'syncStatus': _syncState.status.name,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
        return connectivity;
      }
      if (_syncState.status == EmailSyncStatus.ready) {
        _scheduleConnectivityDowngrade(connectivity);
        _traceEmailOperation(
          'email.connectivity',
          'end',
          id: traceId,
          fields: <String, Object?>{
            'result': 'downgradeScheduled',
            'connectivity': connectivity,
            'syncStatus': _syncState.status.name,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
        return connectivity;
      }
      _applyConnectivityState(
        connectivity,
        source: _EmailSyncSource.connectivityApply,
      );
      _traceEmailOperation(
        'email.connectivity',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'connectivity': connectivity,
          'syncStatus': _syncState.status.name,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return connectivity;
    } on TimeoutException {
      _traceEmailOperation(
        'email.connectivity',
        'timeout',
        id: traceId,
        fields: <String, Object?>{
          'source': source.logLabel,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return null;
    } on Exception catch (error, stackTrace) {
      _traceEmailOperation(
        'email.connectivity',
        'error',
        id: traceId,
        fields: <String, Object?>{
          'result': error.runtimeType,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
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
    _lastHealthyConnectivityReadAt = connectivity >= _connectivityWorkingMin
        ? DateTime.timestamp()
        : null;
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
      _log.fine(
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
    await _requestEmailCatchUp(_EmailCatchUpReason.backgroundFetchDone);
  }

  Future<void> _handleChannelOverflow() async {
    try {
      await _requestEmailCatchUp(_EmailCatchUpReason.channelOverflow);
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
      await _refreshConnectivityState(
        source: _EmailSyncSource.channelOverflowComplete,
      );
    }
  }

  void _updateSyncState(
    EmailSyncState next, {
    _EmailSyncSource source = _EmailSyncSource.unknown,
    bool preserveHistoryImportPromptStatus = true,
  }) {
    final resolvedNext = preserveHistoryImportPromptStatus
        ? next.withHistoryImportPromptStatus(
            _syncState.historyImportPromptStatus,
          )
        : next;
    if (_syncState == resolvedNext) return;
    final previous = _syncState;
    _syncState = resolvedNext;
    _syncStateController.add(resolvedNext);
    if (previous.status != EmailSyncStatus.ready &&
        resolvedNext.status == EmailSyncStatus.ready) {
      _readyTransitionController.add(null);
      _emailContentRetryDeferrals.clear();
      _scheduleEmailContentRetryTimer();
      _scheduleVisibleEmailContentPreparation();
    }
    _logSyncStateTransition(
      previous: previous,
      next: resolvedNext,
      source: source,
    );
  }

  void _setEmailHistoryImportPromptStatus(
    EmailHistoryImportPromptStatus status, {
    required _EmailSyncSource source,
  }) {
    _updateSyncState(
      _syncState.withHistoryImportPromptStatus(status),
      source: source,
      preserveHistoryImportPromptStatus: false,
    );
  }

  void _attachTransportListener([EmailDeltaRuntime? transport]) {
    final target = transport ?? _transport;
    if (identical(_listenerTransport, target)) return;
    _detachTransportListener();
    void listener(DeltaCoreEvent event) {
      if (!_canProcessDeltaWork) {
        return;
      }
      if (_shouldDropConnectivityChangedEvent(event)) {
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

  bool _shouldDropConnectivityChangedEvent(DeltaCoreEvent event) {
    if (DeltaEventType.fromCode(event.type) !=
        DeltaEventType.connectivityChanged) {
      return false;
    }
    if (_connectivityRefreshTask != null ||
        _canReuseHealthyConnectivitySample(
          source: _EmailSyncSource.connectivityChangedEvent,
          recoveryCompleted: false,
        )) {
      _suppressedConnectivityChangedEvents += 1;
      return true;
    }
    return false;
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

  Future<void> _bootstrapActiveAccountIfNeeded() async {
    final traceId = _nextTraceId('email.bootstrapActiveAccount');
    final stopwatch = Stopwatch()..start();
    if (!_acceptsRuntimeWork) {
      _traceEmailOperation(
        'email.bootstrapActiveAccount',
        'skip',
        id: traceId,
        fields: <String, Object?>{
          'reason': 'runtimeNotRunning',
          'runtime': _runtimePhase.name,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return;
    }
    final scope = _activeCredentialScope;
    final prefix = _databasePrefix;
    if (scope == null || prefix == null) {
      _traceEmailOperation(
        'email.bootstrapActiveAccount',
        'skip',
        id: traceId,
        fields: <String, Object?>{
          'reason': 'missingScopeOrPrefix',
          'hasScope': scope != null,
          'hasPrefix': prefix != null,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return;
    }
    await _bootstrapFromCoreIfNeeded(
      scope: scope,
      databasePrefix: prefix,
      includeMessages: false,
    );
    _traceEmailOperation(
      'email.bootstrapActiveAccount',
      'end',
      id: traceId,
      fields: <String, Object?>{
        'scope': scope,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
  }

  Future<void> _bootstrapFromCoreIfNeeded({
    required String scope,
    required String databasePrefix,
    bool includeMessages = false,
  }) async {
    final traceId = _nextTraceId('email.bootstrapFromCore');
    final stopwatch = Stopwatch()..start();
    final bootstrapKey = _bootstrapKeyFor(
      scope: scope,
      databasePrefix: databasePrefix,
    );
    final bootstrapped =
        (await _credentialStore.read(key: bootstrapKey)) == true.toString();
    if (bootstrapped) {
      _traceEmailOperation(
        'email.bootstrapFromCore',
        'skip',
        id: traceId,
        fields: <String, Object?>{
          'reason': 'alreadyBootstrapped',
          'scope': scope,
          'includeMessages': includeMessages,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return;
    }
    final existing = _bootstrapFutureForScope(scope);
    if (existing != null) {
      _traceEmailOperation(
        'email.bootstrapFromCore',
        'coalesced',
        id: traceId,
        fields: <String, Object?>{
          'scope': scope,
          'includeMessages': includeMessages,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      await existing;
      return;
    }
    final operationId = _nextBootstrapOperationIdForScope(scope);
    final future = _runBootstrapFromCore(
      scope: scope,
      operationId: operationId,
      bootstrapKey: bootstrapKey,
      includeMessages: includeMessages,
    );
    _setBootstrapFutureForScope(scope, future);
    try {
      await future;
      _traceEmailOperation(
        'email.bootstrapFromCore',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'scope': scope,
          'includeMessages': includeMessages,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
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
    required bool includeMessages,
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
      final didBootstrap = await _bootstrapFromCoreOnMain(
        includeMessages: includeMessages,
      );
      if (operationId != _bootstrapOperationIdForScope(scope) ||
          !_acceptsRuntimeWork) {
        return;
      }
      if (didBootstrap && includeMessages) {
        await _credentialStore.write(key: bootstrapKey, value: true.toString());
      }
      if (operationId != _bootstrapOperationIdForScope(scope) ||
          !_acceptsRuntimeWork) {
        return;
      }
      await _refreshConnectivityState(
        source: _EmailSyncSource.bootstrapComplete,
      );
      await _refreshEmailHistoryImportPromptStatus();
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
      await _requestEmailCatchUp(
        _EmailCatchUpReason.periodicIdleTick,
        isStillRelevant: () => _canContinueImapSyncLoop(token),
      );
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
    final traceId = _nextTraceId('email.imapCapabilities');
    final stopwatch = Stopwatch()..start();
    final now = DateTime.timestamp();
    final lastChecked = _imapCapabilitiesCheckedAt;
    final shouldReuse =
        !force &&
        _imapCapabilitiesResolved &&
        lastChecked != null &&
        now.difference(lastChecked) < _imapCapabilityRefreshInterval;
    if (shouldReuse) {
      _traceEmailOperation(
        'email.imapCapabilities',
        'reuse',
        id: traceId,
        fields: <String, Object?>{
          'force': force,
          'idleSupported': _imapCapabilities.idleSupported,
          'connectionLimit': _imapCapabilities.connectionLimit,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return;
    }
    _traceEmailOperation(
      'email.imapCapabilities',
      'start',
      id: traceId,
      fields: <String, Object?>{
        'force': force,
        'resolved': _imapCapabilitiesResolved,
      },
    );
    _imapCapabilities = await _resolveImapCapabilities();
    _imapCapabilitiesCheckedAt = now;
    _imapCapabilitiesResolved = true;
    _traceEmailOperation(
      'email.imapCapabilities',
      'end',
      id: traceId,
      fields: <String, Object?>{
        'force': force,
        'idleSupported': _imapCapabilities.idleSupported,
        'connectionLimit': _imapCapabilities.connectionLimit,
        'idleCutoff': _imapCapabilities.idleCutoff,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
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

  Future<void> _runReconnectCatchUp({String? parentTraceId}) async {
    await _requestEmailCatchUp(
      _EmailCatchUpReason.reconnectCatchUp,
      parentTraceId: parentTraceId,
    );
  }

  Future<void> _runForegroundResumeCatchUp({String? parentTraceId}) async {
    await _requestEmailCatchUp(
      _EmailCatchUpReason.foregroundResume,
      parentTraceId: parentTraceId,
    );
  }

  bool _shouldScheduleReconnectRestart({
    required int? connectivity,
    required _EmailReconnectRestartPolicy restartPolicy,
  }) {
    if (connectivity == null || connectivity >= _connectivityWorkingMin) {
      return false;
    }
    if (restartPolicy == _EmailReconnectRestartPolicy.offlineOnly) {
      return connectivity < _connectivityConnectingMin;
    }
    return true;
  }

  Future<void> _scheduleReconnectRestart(
    _EmailReconnectRestartPolicy restartPolicy,
  ) async {
    final traceId = _nextTraceId('email.reconnectRestart');
    final stopwatch = Stopwatch()..start();
    _traceEmailOperation(
      'email.reconnectRestart',
      'start',
      id: traceId,
      fields: <String, Object?>{
        'policy': restartPolicy.name,
        'runtime': _runtimePhase.name,
        'ioRunning': _transport.isIoRunning,
      },
    );
    await _reconnectRestartQueue.run(() async {
      if (!_acceptsRuntimeWork) {
        _traceEmailOperation(
          'email.reconnectRestart',
          'skip',
          id: traceId,
          fields: <String, Object?>{
            'reason': 'runtimeNotRunning',
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
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
          _traceEmailOperation(
            'email.reconnectRestart',
            'skip',
            id: traceId,
            fields: <String, Object?>{
              'reason': 'connectivityRecoveredOrNoRestart',
              'connectivity': connectivity,
              'elapsedMs': stopwatch.elapsedMilliseconds,
            },
          );
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
        await _runReconnectCatchUp(parentTraceId: traceId);
        _traceEmailOperation(
          'email.reconnectRestart',
          'end',
          id: traceId,
          fields: <String, Object?>{
            'result': 'restarted',
            'connectivity': restartConnectivity,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
      } on Exception catch (error, stackTrace) {
        _traceEmailOperation(
          'email.reconnectRestart',
          'error',
          id: traceId,
          fields: <String, Object?>{
            'result': error.runtimeType,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
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
    if (_provisioningBlockedScope != null) {
      throw const EmailProvisioningAccountUnavailableException();
    }
    if (_nativeCleanupPending) {
      throw const EmailServiceStoppingException();
    }
    if (_databasePrefix == null || _databasePassphrase == null) {
      throw const EmailProvisioningAccountUnavailableException();
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
    return true;
  }

  Future<void> repairStoredDeltaAccountIdsForMaintenance() async {
    await _repairStoredDeltaAccountIdsOnce();
  }

  Future<void> _repairStoredDeltaAccountIdsOnce() async {
    if (_deltaAccountRepairCompleted) {
      return;
    }
    final accountIds = _usableDeltaAccountIds(await _transport.accountIds());
    if (accountIds.isEmpty) {
      return;
    }
    final db = await _databaseBuilder();
    final duplicateRows = await db.collapseLegacyDeltaAccountDuplicates(
      activeAccountIds: accountIds,
    );
    if (duplicateRows > 0) {
      _log.info('Collapsed $duplicateRows legacy delta account duplicates.');
    }
    final invalid = await db.getEmailMessagesWithDeltaAccountNotIn(accountIds);
    var repaired = 0;
    for (final message in invalid) {
      if (await _repairStoredDeltaAccountId(
        message: message,
        activeAccountIds: accountIds,
      )) {
        repaired += 1;
      }
    }
    if (repaired > 0) {
      _log.info('Repaired $repaired stored delta account ids.');
    }
    _deltaAccountRepairCompleted = true;
  }

  Future<bool> _repairStoredDeltaAccountId({
    required Message message,
    required List<int> activeAccountIds,
  }) async {
    final resolved = await _resolveDeltaAccountIdForStoredMessage(
      message,
      activeAccountIds: activeAccountIds,
    );
    if (resolved != null) {
      return true;
    }
    _log.fine(
      'Leaving stored Delta locator unchanged for ${message.stanzaID}; '
      'account id could not be proven.',
    );
    return false;
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
      replyStanzaId: quotedStanzaId,
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
      replyStanzaId: quotedStanzaId,
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
    final text = ChatSubjectCodec.previewEmailText(
      body: message.body,
      subject: message.subject,
    );
    if (text != null) {
      return text;
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

  Future<
    ({
      Map<String, Chat> chatByJid,
      Map<String, List<_ResolvedFanOutTarget>> targetsByChatJid,
      List<_ResolvedFanOutTarget> unresolved,
    })
  >
  _resolveFanOutTargets(List<EmailRecipientIntent> targets) async {
    final chatByJid = <String, Chat>{};
    final targetsByChatJid = <String, List<_ResolvedFanOutTarget>>{};
    final unresolved = <_ResolvedFanOutTarget>[];
    final pending = <ComposerRecipientKey, Future<Chat?>>{};
    for (final target in targets) {
      pending.putIfAbsent(
        target.recipientKey,
        () => _resolveFanOutIntent(target),
      );
    }
    final entries = pending.entries.toList(growable: false);
    final chatsByKey = <ComposerRecipientKey, Chat?>{};
    for (var index = 0; index < entries.length; index += _fanOutConcurrentOps) {
      final chunk = entries.skip(index).take(_fanOutConcurrentOps).toList();
      final results = await Future.wait(
        chunk.map((entry) async => MapEntry(entry.key, await entry.value)),
      );
      for (final result in results) {
        chatsByKey[result.key] = result.value;
      }
    }
    for (final target in targets) {
      final resolved = _ResolvedFanOutTarget(
        intent: target,
        chat: chatsByKey[target.recipientKey],
      );
      final chat = resolved.chat;
      if (chat == null) {
        unresolved.add(resolved);
        continue;
      }
      chatByJid.putIfAbsent(chat.jid, () => chat);
      targetsByChatJid.putIfAbsent(chat.jid, () => []).add(resolved);
    }
    return (
      chatByJid: chatByJid,
      targetsByChatJid: targetsByChatJid,
      unresolved: unresolved,
    );
  }

  Future<Chat?> _resolveFanOutIntent(EmailRecipientIntent target) async {
    final sourceChatJid = target.sourceChatJid;
    final normalizedTarget = normalizedAddressValue(target.address);
    if (sourceChatJid != null && sourceChatJid.isNotEmpty) {
      final db = await _databaseBuilder();
      final stored = await db.getChat(sourceChatJid);
      if (stored != null &&
          (normalizedTarget == null ||
              stored.normalizedIdentityKeys.contains(normalizedTarget))) {
        return ensureChatForEmailChat(stored);
      }
    }
    final chat = await ensureChatForAddress(
      address: target.address,
      displayName: target.displayName,
      fromAddress: target.fromAddress,
    );
    if (normalizedTarget != null &&
        !chat.normalizedIdentityKeys.contains(normalizedTarget)) {
      return null;
    }
    return chat;
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
    final List<int> resolvedAccountIds;
    try {
      resolvedAccountIds = _usableDeltaAccountIds(
        accountIds ?? await _transport.accountIds(),
      );
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      _log.fine('Email read-receipt config deferred.', error, stackTrace);
      return;
    } on DeltaSafeException catch (error, stackTrace) {
      _log.fine('Email read-receipt config deferred.', error, stackTrace);
      return;
    }
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

  Future<List<int>> _deltaConfigAccountIds({
    Iterable<int>? accountIds,
    required String deferredLogMessage,
  }) async {
    if (!hasActiveSession && accountIds == null) {
      return const <int>[];
    }
    try {
      return _usableDeltaAccountIds(
        accountIds ?? await _transport.accountIds(),
      );
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      _log.fine(deferredLogMessage, error, stackTrace);
      return const <int>[];
    } on DeltaSafeException catch (error, stackTrace) {
      _log.fine(deferredLogMessage, error, stackTrace);
      return const <int>[];
    }
  }

  Future<bool> _applyDeltaDownloadLimit({Iterable<int>? accountIds}) async {
    final resolvedAccountIds = await _deltaConfigAccountIds(
      accountIds: accountIds,
      deferredLogMessage: 'Email download limit config deferred.',
    );
    if (resolvedAccountIds.isEmpty) {
      return false;
    }
    final appliedAccountIds = <int>{};
    for (final accountId in resolvedAccountIds) {
      if (!appliedAccountIds.add(accountId)) {
        continue;
      }
      await _setRequiredDeltaCoreConfig(
        key: _downloadLimitConfigKey,
        value: _downloadLimitBytes.toString(),
        accountId: accountId,
      );
    }
    return true;
  }

  Future<void> _requireDeltaDownloadLimit({
    required Iterable<int> accountIds,
  }) async {
    if (await _applyDeltaDownloadLimit(accountIds: accountIds)) {
      return;
    }
    throw const EmailServiceExistingHistoryImportUnsupportedException();
  }

  Future<bool> _applyExistingHistoryImportDisabled({
    Iterable<int>? accountIds,
  }) async {
    final resolvedAccountIds = await _deltaConfigAccountIds(
      accountIds: accountIds,
      deferredLogMessage: 'Email existing-history import config deferred.',
    );
    if (resolvedAccountIds.isEmpty) {
      return false;
    }
    final appliedAccountIds = <int>{};
    for (final accountId in resolvedAccountIds) {
      if (!appliedAccountIds.add(accountId)) {
        continue;
      }
      await _disableExistingHistoryImport(accountId);
    }
    return true;
  }

  Future<void> _applyNormalExistingHistoryImportPolicy({
    Iterable<int>? accountIds,
  }) async {
    if (_existingHistoryImportTask != null) {
      return;
    }
    await _applyExistingHistoryImportDisabled(accountIds: accountIds);
  }

  Future<void> _setRequiredDeltaCoreConfig({
    required String key,
    required String value,
    required int accountId,
  }) async {
    try {
      await _transport.setCoreConfig(
        key: key,
        value: value,
        accountId: accountId,
      );
      final configured = await _transport.getCoreConfig(
        key,
        accountId: accountId,
      );
      if (configured?.trim() == value) {
        return;
      }
      throw StateError(
        'Delta config $key readback mismatch for accountId=$accountId.',
      );
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StateError(
          'Failed to set required Delta config $key for accountId=$accountId: '
          '$error',
        ),
        stackTrace,
      );
    } on DeltaSafeException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StateError(
          'Failed to set required Delta config $key for accountId=$accountId: '
          '$error',
        ),
        stackTrace,
      );
    }
  }

  Future<void> _applyDeltaSelfSyncSuppression() async {
    if (!hasActiveSession) {
      return;
    }
    final List<int> resolvedAccountIds;
    try {
      resolvedAccountIds = _usableDeltaAccountIds(
        await _transport.accountIds(),
      );
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      _log.fine('Email self-sync suppression deferred.', error, stackTrace);
      return;
    } on DeltaSafeException catch (error, stackTrace) {
      _log.fine('Email self-sync suppression deferred.', error, stackTrace);
      return;
    }
    final appliedAccountIds = <int>{};
    for (final accountId in resolvedAccountIds) {
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
    throw const EmailProvisioningAccountUnavailableException();
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
    final List<int> accountIds;
    try {
      accountIds = _usableDeltaAccountIds(await _transport.accountIds());
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      _log.fine('Email OpenPGP base config deferred.', error, stackTrace);
      return;
    } on DeltaSafeException catch (error, stackTrace) {
      _log.fine('Email OpenPGP base config deferred.', error, stackTrace);
      return;
    }
    for (final accountId in accountIds) {
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
      await _applyDeltaDownloadLimit(accountIds: [account.deltaAccountId]);
      await _applyNormalExistingHistoryImportPolicy(
        accountIds: [account.deltaAccountId],
      );
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
      await _applyDeltaDownloadLimit(accountIds: [account.deltaAccountId]);
      await _applyNormalExistingHistoryImportPolicy(
        accountIds: [account.deltaAccountId],
      );
      await _transport.configureAccount(
        address: account.address,
        password: credentials.password,
        displayName: displayName,
        additional: configureOverrides,
        accountId: account.deltaAccountId,
      );
      await _applyOpenPgpBaseConfigForAccount(account);
      await _applyDeltaDownloadLimit(accountIds: [account.deltaAccountId]);
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

  Future<List<int>> _storedDeltaChatIdsForReadState({
    required Chat chat,
    required int deltaAccountId,
  }) async {
    final Chat resolvedChat = await _trackAppDatabaseOperation(
      () => _storedEmailChatForAccount(
        chat: chat,
        deltaAccountId: deltaAccountId,
      ),
    );
    final mappedDeltaChatIds = await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      return db.getDeltaChatIdsForAccount(
        chatJid: resolvedChat.jid,
        deltaAccountId: deltaAccountId,
      );
    });
    final messageDeltaChatIds = await _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      return db.getMessageDeltaChatIdsForAccount(
        chatJid: resolvedChat.jid,
        deltaAccountId: deltaAccountId,
      );
    });
    final ordered = <int>{
      ..._deltaChatIdCandidates(
        mappedDeltaChatIds: mappedDeltaChatIds,
        activeDeltaChatId: resolvedChat.deltaChatId,
      ),
      ...messageDeltaChatIds,
    };
    return ordered.toList(growable: false);
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
    if (!preserveActiveSession ||
        (_activeCredentialScope == scope && _activeAccount != null)) {
      _clearProvisioningRuntimeFailure(scope);
    }
    _credentialSession.clearScope(
      scope,
      preserveActiveSession: preserveActiveSession,
      clearEphemeralState: !preserveActiveSession,
    );
  }

  /// Marks a chat as noticed, clearing unread badges in core.
  ///
  /// Call this when the user opens a chat.
  Future<bool> markNoticedChat(Chat chat) async =>
      (await syncChatNoticeState(chat)).terminalSuccess;

  Future<EmailChatNoticeSyncResult> syncChatNoticeState(Chat chat) {
    final dedupeKey = _chatNoticeSyncKey(chat);
    final inFlight = _noticeSyncInFlight[dedupeKey];
    if (inFlight != null) {
      return inFlight;
    }
    final task = _syncChatNoticeState(chat);
    _noticeSyncInFlight[dedupeKey] = task;
    return task.whenComplete(() {
      if (identical(_noticeSyncInFlight[dedupeKey], task)) {
        _noticeSyncInFlight.remove(dedupeKey);
      }
    });
  }

  _EmailChatNoticeSyncKey _chatNoticeSyncKey(Chat chat) {
    return _EmailChatNoticeSyncKey.from(
      credentialScope: _activeCredentialScope,
      chat: chat,
    );
  }

  Future<EmailChatNoticeSyncResult> _syncChatNoticeState(Chat chat) async {
    try {
      var syncResult = const EmailChatNoticeSyncResult(
        status: EmailChatNoticeSyncStatus.unresolved,
      );
      await _readStateQueue.run(() async {
        await _ensureReady();
        if (_blocksRuntimeReentry) {
          syncResult = const EmailChatNoticeSyncResult(
            status: EmailChatNoticeSyncStatus.failed,
          );
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
          syncResult = const EmailChatNoticeSyncResult(
            status: EmailChatNoticeSyncStatus.failed,
          );
          return;
        }
        final chatIds = await _storedDeltaChatIdsForReadState(
          chat: resolvedChat,
          deltaAccountId: account.deltaAccountId,
        );
        if (chatIds.isEmpty) {
          syncResult = EmailChatNoticeSyncResult(
            status: EmailChatNoticeSyncStatus.unresolved,
            deltaAccountId: account.deltaAccountId,
          );
          return;
        }
        var acceptedNoticeCount = 0;
        for (final chatId in chatIds) {
          final result = await _transport.markNoticedChat(
            chatId,
            accountId: account.deltaAccountId,
          );
          if (result) {
            acceptedNoticeCount += 1;
          }
        }
        final status = acceptedNoticeCount == chatIds.length
            ? EmailChatNoticeSyncStatus.freshCleared
            : acceptedNoticeCount > 0
            ? EmailChatNoticeSyncStatus.partial
            : EmailChatNoticeSyncStatus.failed;
        syncResult = EmailChatNoticeSyncResult(
          status: status,
          deltaAccountId: account.deltaAccountId,
          chatIds: chatIds,
          noticeRequestCount: chatIds.length,
          noticeAcceptedCount: acceptedNoticeCount,
          coreNoticeRequested: true,
          coreNoticeAccepted: acceptedNoticeCount > 0,
        );
      });
      return syncResult;
    } on EmailProvisioningException catch (error, stackTrace) {
      _log.fine('Email noticed sync failed.', error, stackTrace);
      return const EmailChatNoticeSyncResult(
        status: EmailChatNoticeSyncStatus.failed,
      );
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      _log.fine('Email noticed sync failed.', error, stackTrace);
      return const EmailChatNoticeSyncResult(
        status: EmailChatNoticeSyncStatus.failed,
      );
    } on DeltaSafeException catch (error, stackTrace) {
      _log.fine('Email noticed sync failed.', error, stackTrace);
      return const EmailChatNoticeSyncResult(
        status: EmailChatNoticeSyncStatus.failed,
      );
    }
  }

  /// Marks messages as seen, triggering MDN if enabled.
  ///
  /// Call this when messages are displayed to the user.
  Future<bool> markSeenMessages(
    List<Message> messages, {
    required bool sendReadReceipts,
    String? chatJidScope,
  }) async => (await syncSeenMessages(
    messages,
    sendReadReceipts: sendReadReceipts,
    chatJidScope: chatJidScope,
  )).terminalSuccess;

  Future<EmailMessageSeenSyncResult> syncSeenMessages(
    List<Message> messages, {
    required bool sendReadReceipts,
    String? chatJidScope,
  }) async {
    try {
      var syncResult = const EmailMessageSeenSyncResult(
        status: EmailMessageSeenSyncStatus.unresolved,
      );
      await _readStateQueue.run(() async {
        await _mdnConfigQueue.run(() async {
          await _ensureReady();
          if (_blocksRuntimeReentry) {
            syncResult = const EmailMessageSeenSyncResult(
              status: EmailMessageSeenSyncStatus.failed,
            );
            return;
          }
          final idsByAccount = await _trackAppDatabaseOperation(() async {
            final db = await _databaseBuilder();
            return _deltaSeenDebtTargetsForMessages(
              db: db,
              messages: messages,
              chatJidScope: chatJidScope,
            );
          });
          final submittedCount = idsByAccount.values.fold<int>(
            0,
            (sum, ids) => sum + ids.length,
          );
          if (submittedCount == 0) {
            syncResult = const EmailMessageSeenSyncResult(
              status: EmailMessageSeenSyncStatus.sent,
            );
            return;
          }
          var transportAcceptedCount = 0;
          try {
            await _applyEmailReadReceiptPreference(
              accountIds: idsByAccount.keys.toList(growable: false),
              enabled: sendReadReceipts,
            );
            for (final entry in idsByAccount.entries) {
              final result = await _transport.markSeenMessages(
                entry.value,
                accountId: entry.key,
              );
              if (!result) {
                continue;
              }
              transportAcceptedCount += entry.value.length;
              await _trackAppDatabaseOperation(() async {
                final db = await _databaseBuilder();
                await db.markDeltaMessagesSeenSynced(
                  deltaAccountId: entry.key,
                  deltaMsgIds: entry.value,
                );
              });
            }
          } finally {
            await _applyEmailReadReceiptPreference(
              accountIds: idsByAccount.keys.toList(growable: false),
              enabled: _emailReadReceiptsEnabled,
            );
          }
          syncResult = EmailMessageSeenSyncResult(
            status: transportAcceptedCount == submittedCount
                ? EmailMessageSeenSyncStatus.sent
                : EmailMessageSeenSyncStatus.pending,
            submittedCount: submittedCount,
            verifiedSeenCount: transportAcceptedCount,
            unresolvedCount: submittedCount - transportAcceptedCount,
            transportAcceptedCount: transportAcceptedCount,
          );
        });
      });
      return syncResult;
    } on DeltaChatException catch (error, stackTrace) {
      _log.fine('Email unread sync failed.', error, stackTrace);
      return const EmailMessageSeenSyncResult(
        status: EmailMessageSeenSyncStatus.failed,
      );
    } on EmailProvisioningException catch (error, stackTrace) {
      _log.fine('Email unread sync failed.', error, stackTrace);
      return const EmailMessageSeenSyncResult(
        status: EmailMessageSeenSyncStatus.failed,
      );
    } on EmailServiceStoppingException catch (error, stackTrace) {
      _log.fine('Email unread sync failed.', error, stackTrace);
      return const EmailMessageSeenSyncResult(
        status: EmailMessageSeenSyncStatus.failed,
      );
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      _log.fine('Email unread sync failed.', error, stackTrace);
      return const EmailMessageSeenSyncResult(
        status: EmailMessageSeenSyncStatus.failed,
      );
    } on DeltaSafeException catch (error, stackTrace) {
      _log.fine('Email unread sync failed.', error, stackTrace);
      return const EmailMessageSeenSyncResult(
        status: EmailMessageSeenSyncStatus.failed,
      );
    } on StateError catch (error, stackTrace) {
      _log.fine('Email unread sync failed.', error, stackTrace);
      return const EmailMessageSeenSyncResult(
        status: EmailMessageSeenSyncStatus.failed,
      );
    }
  }

  String? _emailSelfJidForReadRepair({
    required int accountId,
    required Chat? chat,
  }) {
    final chatFromAddress = chat?.emailFromAddress?.trim();
    if (chatFromAddress != null && chatFromAddress.isNotEmpty) {
      return chatFromAddress;
    }
    final transportSelf = _transport.selfJidForAccount(accountId)?.trim();
    if (transportSelf != null && transportSelf.isNotEmpty) {
      return transportSelf;
    }
    final activeAddress = _activeAccount?.address.trim();
    if (activeAddress != null && activeAddress.isNotEmpty) {
      return activeAddress;
    }
    return null;
  }

  Future<List<Message>> _seenMessageCandidatesForMessages({
    required XmppDatabase db,
    required List<Message> messages,
  }) async {
    final candidates = <int, Message>{};
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
        candidates[deltaId] = candidate;
      }
    }
    return candidates.values.toList(growable: false);
  }

  Future<Map<int, List<int>>> _deltaSeenDebtTargetsForMessages({
    required XmppDatabase db,
    required List<Message> messages,
    String? chatJidScope,
  }) async {
    final activeAccountIds = _usableDeltaAccountIds(
      await _transport.accountIds(),
    );
    if (activeAccountIds.isEmpty) {
      return const <int, List<int>>{};
    }
    final visibleCandidates = await _seenMessageCandidatesForMessages(
      db: db,
      messages: messages,
    );
    final scopedChatJids = <String>{
      for (final message in messages) message.chatJid.trim(),
      ?chatJidScope?.trim(),
    }..removeWhere((jid) => jid.isEmpty);
    const pendingDebtLimit = 500;
    final storedDebtCandidates = scopedChatJids.isEmpty
        ? const <Message>[]
        : await db.getDisplayedEmailMessagesPendingDeltaSeen(
            chatJids: scopedChatJids,
            limit: pendingDebtLimit,
          );
    final candidatesByLocator = <String, Message>{};
    for (final message in visibleCandidates) {
      _putDeltaSeenDebtCandidate(candidatesByLocator, message);
    }
    for (final message in storedDebtCandidates) {
      _putDeltaSeenDebtCandidate(candidatesByLocator, message);
    }
    if (candidatesByLocator.isEmpty) {
      return const <int, List<int>>{};
    }
    final validAccounts = activeAccountIds.toSet();
    final idsByAccount = <int, LinkedHashSet<int>>{};
    for (final message in candidatesByLocator.values) {
      if (message.deltaSeenSynced) {
        continue;
      }
      final deltaId = message.deltaMsgId;
      if (deltaId == null || deltaId <= _deltaEventMessageUnset) {
        continue;
      }
      final storedAccountId = message.deltaAccountId;
      final accountId = validAccounts.contains(storedAccountId)
          ? storedAccountId
          : await _resolveDeltaAccountIdForStoredMessage(
              message,
              activeAccountIds: activeAccountIds,
            );
      if (accountId == null) {
        continue;
      }
      final emailSelfJid = _emailSelfJidForReadRepair(
        accountId: accountId,
        chat: null,
      );
      if (message.isFromAccount(emailSelfJid) ||
          message.isFromAccount(_xmppSelfJidProvider?.call())) {
        continue;
      }
      idsByAccount.putIfAbsent(accountId, LinkedHashSet<int>.new).add(deltaId);
    }
    return {
      for (final entry in idsByAccount.entries)
        if (entry.value.isNotEmpty)
          entry.key: List<int>.unmodifiable(entry.value),
    };
  }

  void _putDeltaSeenDebtCandidate(
    Map<String, Message> candidatesByLocator,
    Message message,
  ) {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaEventMessageUnset) {
      return;
    }
    if (!message.displayed) {
      return;
    }
    if (message.deltaSeenSynced) {
      return;
    }
    candidatesByLocator['${message.deltaAccountId}:$deltaId'] = message;
  }

  Future<Map<int, List<int>>> _deltaIdsByResolvedAccountForMessages(
    List<Message> messages,
  ) async {
    if (messages.isEmpty) {
      return const <int, List<int>>{};
    }
    final validAccounts = _usableDeltaAccountIds(
      await _transport.accountIds(),
    ).toSet();
    final idsByAccount = <int, LinkedHashSet<int>>{};
    for (final message in messages) {
      final deltaId = message.deltaMsgId;
      if (deltaId == null) {
        continue;
      }
      final storedAccountId = message.deltaAccountId;
      final accountId = validAccounts.contains(storedAccountId)
          ? storedAccountId
          : await _resolveDeltaAccountIdForStoredMessage(message);
      if (accountId == null) {
        continue;
      }
      idsByAccount.putIfAbsent(accountId, LinkedHashSet<int>.new).add(deltaId);
    }
    return {
      for (final entry in idsByAccount.entries)
        if (entry.value.isNotEmpty)
          entry.key: List<int>.unmodifiable(entry.value),
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

  /// Deletes messages from core and server.
  Future<bool> deleteMessages(List<Message> messages) async {
    final deltaMessages = messages
        .where((message) => message.deltaMsgId != null)
        .toList(growable: false);
    if (deltaMessages.isEmpty) {
      return false;
    }
    await _ensureReady();
    final validAccounts = _usableDeltaAccountIds(
      await _transport.accountIds(),
    ).toSet();
    final idsByAccount = <int, LinkedHashSet<int>>{};
    final stanzaIdsByAccount = <int, Map<int, String>>{};
    var unresolved = false;
    for (final message in deltaMessages) {
      final deltaId = message.deltaMsgId;
      if (deltaId == null || deltaId <= _deltaMessageIdUnset) {
        unresolved = true;
        continue;
      }
      final storedAccountId = message.deltaAccountId;
      final accountId = validAccounts.contains(storedAccountId)
          ? storedAccountId
          : await _resolveDeltaAccountIdForStoredMessage(
              message,
              activeAccountIds: validAccounts.toList(growable: false),
            );
      if (accountId == null) {
        unresolved = true;
        continue;
      }
      idsByAccount.putIfAbsent(accountId, LinkedHashSet<int>.new).add(deltaId);
      final stanzaId = message.stanzaID.trim();
      if (stanzaId.isNotEmpty) {
        stanzaIdsByAccount
            .putIfAbsent(accountId, () => <int, String>{})
            .putIfAbsent(deltaId, () => stanzaId);
      }
    }
    if (idsByAccount.isEmpty) {
      return false;
    }
    var success = !unresolved;
    final deletedStanzaIds = <String>{};
    for (final entry in idsByAccount.entries) {
      final messageIds = entry.value.toList(growable: false);
      final result = await _transport.deleteMessages(
        messageIds,
        accountId: entry.key,
      );
      if (!result) {
        success = false;
        continue;
      }
      final stanzaIds = stanzaIdsByAccount[entry.key];
      if (stanzaIds == null) {
        continue;
      }
      for (final messageId in messageIds) {
        final stanzaId = stanzaIds[messageId];
        if (stanzaId != null) {
          deletedStanzaIds.add(stanzaId);
        }
      }
    }
    if (deletedStanzaIds.isNotEmpty) {
      final db = await _databaseBuilder();
      await db.deleteMessagesByStanzaIds(deletedStanzaIds);
    }
    return success;
  }

  /// Forwards messages to another chat using core.
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

    final remainingIds = deltaIdSet
        .where((deltaId) => !messagesByDeltaId.containsKey(deltaId))
        .toList(growable: false);
    if (remainingIds.isNotEmpty) {
      await _hydrateMessagesOnMain(remainingIds, accountId: deltaAccountId);
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
    try {
      return await _downloadFullMessage(message);
    } on TimeoutException catch (error, stackTrace) {
      _log.fine('Email full message download timed out.', error, stackTrace);
      return false;
    } on DeltaChatException catch (error, stackTrace) {
      _log.fine('Email full message download failed.', error, stackTrace);
      return false;
    } on EmailProvisioningException catch (error, stackTrace) {
      _log.fine('Email full message download failed.', error, stackTrace);
      return false;
    } on EmailServiceStoppingException catch (error, stackTrace) {
      _log.fine('Email full message download failed.', error, stackTrace);
      return false;
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      _log.fine('Email full message download failed.', error, stackTrace);
      return false;
    } on DeltaSafeException catch (error, stackTrace) {
      _log.fine('Email full message download failed.', error, stackTrace);
      return false;
    } on StateError catch (error, stackTrace) {
      _log.fine('Email full message download failed.', error, stackTrace);
      return false;
    }
  }

  Future<bool> _downloadFullMessage(Message message) async {
    final deadline = DateTime.timestamp().add(_pendingEmailBodyDownloadTimeout);
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) {
      return false;
    }
    final readyResult = await _withPendingEmailBodyDownloadBudgetResult(
      () async {
        await _ensureReady();
        return true;
      },
      deadline: deadline,
    );
    if (!readyResult.completed) {
      return false;
    }
    final accountResult = await _withPendingEmailBodyDownloadBudgetResult(
      () => _storedDeltaAccountIdForBodyHydration(message, deadline: deadline),
      deadline: deadline,
    );
    if (!accountResult.completed) {
      return false;
    }
    final accountId = accountResult.value;
    if (accountId == null) {
      return false;
    }
    final acceptedResult = await _downloadFullMessageWithPendingBudget(
      deltaMsgId: deltaId,
      accountId: accountId,
      deadline: deadline,
    );
    if (acceptedResult != true) {
      return false;
    }
    return _waitForFullMessageMaterial(
      message,
      accountId: accountId,
      deadline: deadline,
    );
  }

  void reportVisibleEmailContentMessages({
    required String chatJid,
    required Iterable<Message> messages,
  }) {
    final normalizedChatJid = normalizeAddress(chatJid) ?? chatJid.trim();
    if (normalizedChatJid.isEmpty) {
      return;
    }
    final visibleMessages = <EmailContentJobKey, Message>{};
    for (final message in messages) {
      final key = _emailContentJobKey(message);
      if (key == null) {
        continue;
      }
      visibleMessages[key] = message;
    }
    if (visibleMessages.isEmpty) {
      _visibleEmailContentMessagesByChatJid.remove(normalizedChatJid);
    } else {
      _visibleEmailContentMessagesByChatJid[normalizedChatJid] =
          visibleMessages;
    }
    _scheduleVisibleEmailContentPreparation();
  }

  void clearVisibleEmailContentMessages(String chatJid) {
    final normalizedChatJid = normalizeAddress(chatJid) ?? chatJid.trim();
    if (normalizedChatJid.isEmpty) {
      return;
    }
    _visibleEmailContentMessagesByChatJid.remove(normalizedChatJid);
    _cancelUnwantedVisibleEmailContentTasks();
    _emitEmailContentPreparationSnapshot();
  }

  Future<bool> requestEmailContentPreparation(
    Message message, {
    EmailContentPreparationPriority priority =
        EmailContentPreparationPriority.manual,
  }) async {
    final key = _emailContentJobKey(message);
    if (key == null) {
      return false;
    }
    final effectiveMessage =
        await _currentStoredEmailContentMessage(message, expectedKey: key) ??
        message;
    if (effectiveMessage.rfc822BodyContentUnavailable) {
      return false;
    }
    if (_emailContentPreparationComplete(effectiveMessage)) {
      return true;
    }
    final completer = Completer<bool>();
    _emailContentPreparationWaiters
        .putIfAbsent(key, () => <Completer<bool>>[])
        .add(completer);
    final queued = _enqueueEmailContentPreparation(
      effectiveMessage,
      priority: priority,
    );
    if (!queued) {
      _completeEmailContentPreparationWaiters(key, false);
    } else {
      _drainEmailContentPreparationQueues();
    }
    return await completer.future;
  }

  Future<bool> requestEmailOriginalContentPreparation(
    Message message, {
    EmailContentPreparationPriority priority =
        EmailContentPreparationPriority.manual,
  }) async {
    final key = _emailContentJobKey(message);
    if (key == null) {
      return false;
    }
    final cachedHtml = _emailOriginalHtmlByKey[key]?.trim();
    if (cachedHtml != null && cachedHtml.isNotEmpty) {
      return true;
    }
    if (_emailOriginalLoadingKeys.contains(key)) {
      return false;
    }
    final effectiveMessage =
        await _currentStoredEmailContentMessage(message, expectedKey: key) ??
        message;
    _emailOriginalLoadingKeys.add(key);
    _emailOriginalUnavailableKeys.remove(key);
    _emitEmailOriginalContentSnapshot();
    final generation = _originalContentGeneration;
    return await _runEmailOriginalContentPreparation(
      key: key,
      message: effectiveMessage,
      priority: priority,
      generation: generation,
    );
  }

  Future<Message?> _currentStoredEmailContentMessage(
    Message message, {
    required EmailContentJobKey expectedKey,
  }) {
    return _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      final current = await db.getMessageByStanzaID(message.stanzaID);
      if (current == null) {
        return null;
      }
      if (_emailContentJobKey(current) != expectedKey) {
        return null;
      }
      return current;
    });
  }

  Future<bool> _runEmailOriginalContentPreparation({
    required EmailContentJobKey key,
    required Message message,
    required EmailContentPreparationPriority priority,
    required int generation,
  }) async {
    final stopwatch = Stopwatch()..start();
    final traceId = _nextTraceId('email.originalContentPreparation');
    var result = 'failed';
    String? html;
    var unavailable = false;
    final deadline = DateTime.timestamp().add(_pendingEmailBodyDownloadTimeout);
    bool isCanceled() {
      return generation != _originalContentGeneration ||
          !_emailOriginalLoadingKeys.contains(key);
    }

    try {
      _traceEmailOperation(
        'email.originalContentPreparation',
        'start',
        id: traceId,
        fields: <String, Object?>{
          'accountId': key.deltaAccountId,
          'chatId': key.deltaChatId,
          'deltaMsgId': key.deltaMsgId,
          'priority': priority.name,
        },
      );
      final content = await _loadEmailOriginalHtml(
        message,
        deadline: deadline,
        isCanceled: isCanceled,
      );
      result = content.result;
      html = content.html;
      unavailable = content.unavailable;
    } on TimeoutException catch (error, stackTrace) {
      _log.fine(
        'Email original content preparation timed out.',
        error,
        stackTrace,
      );
      result = 'timeout';
    } on DeltaChatException catch (error, stackTrace) {
      _log.fine(
        'Email original content preparation failed.',
        error,
        stackTrace,
      );
    } on EmailProvisioningException catch (error, stackTrace) {
      _log.fine(
        'Email original content preparation failed.',
        error,
        stackTrace,
      );
    } on EmailServiceStoppingException catch (error, stackTrace) {
      _log.fine(
        'Email original content preparation failed.',
        error,
        stackTrace,
      );
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      _log.fine(
        'Email original content preparation failed.',
        error,
        stackTrace,
      );
    } on DeltaSafeException catch (error, stackTrace) {
      _log.fine(
        'Email original content preparation failed.',
        error,
        stackTrace,
      );
    } on StateError catch (error, stackTrace) {
      _log.fine(
        'Email original content preparation failed.',
        error,
        stackTrace,
      );
    } finally {
      _traceEmailOperation(
        'email.originalContentPreparation',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'accountId': key.deltaAccountId,
          'chatId': key.deltaChatId,
          'deltaMsgId': key.deltaMsgId,
          'priority': priority.name,
          'result': result,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
    }
    if (generation != _originalContentGeneration ||
        !_emailOriginalLoadingKeys.contains(key)) {
      return false;
    }
    _emailOriginalLoadingKeys.remove(key);
    if (html?.trim().isNotEmpty == true) {
      _emailOriginalHtmlByKey[key] = html!;
      _emailOriginalUnavailableKeys.remove(key);
      _emitEmailOriginalContentSnapshot();
      return true;
    }
    if (unavailable) {
      _emailOriginalUnavailableKeys.add(key);
    }
    _emitEmailOriginalContentSnapshot();
    return false;
  }

  Future<({String? html, bool unavailable, String result})>
  _loadEmailOriginalHtml(
    Message message, {
    required DateTime deadline,
    required bool Function() isCanceled,
  }) async {
    String? fullHtml;
    var transientFailure = false;
    if (!message.hasRfc822BodyContent) {
      ({String? html, bool settled, bool timedOut}) rfc822Hydration = (
        html: null,
        settled: false,
        timedOut: false,
      );
      try {
        rfc822Hydration = await hydrateStoredRfc822BodyContent(
          message,
          deadline: deadline,
          isCanceled: isCanceled,
        );
      } on TimeoutException catch (error, stackTrace) {
        _log.fine(
          'Email original RFC822 hydration timed out.',
          error,
          stackTrace,
        );
        transientFailure = true;
      } on DeltaChatException catch (error, stackTrace) {
        _log.fine('Email original RFC822 hydration failed.', error, stackTrace);
        transientFailure = true;
      } on EmailProvisioningException catch (error, stackTrace) {
        _log.fine('Email original RFC822 hydration failed.', error, stackTrace);
        transientFailure = true;
      } on EmailServiceStoppingException catch (error, stackTrace) {
        _log.fine('Email original RFC822 hydration failed.', error, stackTrace);
        transientFailure = true;
      } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
        _log.fine('Email original RFC822 hydration failed.', error, stackTrace);
        transientFailure = true;
      } on DeltaSafeException catch (error, stackTrace) {
        _log.fine('Email original RFC822 hydration failed.', error, stackTrace);
        transientFailure = true;
      } on StateError catch (error, stackTrace) {
        _log.fine('Email original RFC822 hydration failed.', error, stackTrace);
        transientFailure = true;
      }
      final hydratedHtml = rfc822Hydration.html?.trim();
      if (hydratedHtml != null && hydratedHtml.isNotEmpty) {
        fullHtml = hydratedHtml;
      }
      if (rfc822Hydration.timedOut || isCanceled()) {
        return (html: null, unavailable: false, result: 'timeout');
      }
      if (message.rfc822BodyStatus.isPendingDownload &&
          !rfc822Hydration.settled &&
          (fullHtml == null || fullHtml.trim().isEmpty)) {
        return (html: null, unavailable: false, result: 'pendingDownload');
      }
    } else {
      fullHtml = message.normalizedHtmlBody;
    }
    if (fullHtml == null || fullHtml.trim().isEmpty) {
      try {
        final fullHtmlResult = await _getMessageFullHtmlWithBudget(
          message,
          deadline: deadline,
          isCanceled: isCanceled,
        );
        if (fullHtmlResult.timedOut) {
          return (html: null, unavailable: false, result: 'timeout');
        }
        if (!fullHtmlResult.definitive) {
          return (html: null, unavailable: false, result: 'missingAccount');
        }
        fullHtml = fullHtmlResult.html;
      } on TimeoutException catch (error, stackTrace) {
        _log.fine('Email original full HTML timed out.', error, stackTrace);
        return (html: null, unavailable: false, result: 'timeout');
      } on DeltaChatException catch (error, stackTrace) {
        _log.fine('Email original full HTML failed.', error, stackTrace);
        return (html: null, unavailable: false, result: 'failed');
      } on EmailProvisioningException catch (error, stackTrace) {
        _log.fine('Email original full HTML failed.', error, stackTrace);
        return (html: null, unavailable: false, result: 'failed');
      } on EmailServiceStoppingException catch (error, stackTrace) {
        _log.fine('Email original full HTML failed.', error, stackTrace);
        return (html: null, unavailable: false, result: 'failed');
      } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
        _log.fine('Email original full HTML failed.', error, stackTrace);
        return (html: null, unavailable: false, result: 'failed');
      } on DeltaSafeException catch (error, stackTrace) {
        _log.fine('Email original full HTML failed.', error, stackTrace);
        return (html: null, unavailable: false, result: 'failed');
      } on StateError catch (error, stackTrace) {
        _log.fine('Email original full HTML failed.', error, stackTrace);
        return (html: null, unavailable: false, result: 'failed');
      }
    }
    if (fullHtml == null || fullHtml.trim().isEmpty) {
      if (transientFailure) {
        return (html: null, unavailable: false, result: 'failed');
      }
      return (html: null, unavailable: true, result: 'unavailable');
    }
    return (html: fullHtml, unavailable: false, result: 'stored');
  }

  EmailContentJobKey? _emailContentJobKey(Message message) {
    final deltaId = message.deltaMsgId;
    if (!message.isEmailBacked ||
        deltaId == null ||
        deltaId <= _deltaMessageIdUnset) {
      return null;
    }
    return EmailContentJobKey(
      deltaAccountId: message.deltaAccountId,
      deltaChatId: message.deltaChatId ?? 0,
      deltaMsgId: deltaId,
    );
  }

  void _scheduleVisibleEmailContentPreparation() {
    for (final messagesByKey in _visibleEmailContentMessagesByChatJid.values) {
      for (final message in messagesByKey.values) {
        _enqueueEmailContentPreparation(
          message,
          priority: EmailContentPreparationPriority.visible,
        );
      }
    }
    _drainEmailContentPreparationQueues();
  }

  bool _enqueueEmailContentPreparation(
    Message message, {
    required EmailContentPreparationPriority priority,
  }) {
    final key = _emailContentJobKey(message);
    if (key == null) {
      return false;
    }
    if (message.rfc822BodyContentUnavailable) {
      return false;
    }
    if (_emailContentPreparationComplete(message)) {
      _recordEmailContentPreparationSuccess(key);
      _completeEmailContentPreparationWaiters(key, true);
      return true;
    }
    if (_emailContentRetryDeferred(
      key: key,
      message: message,
      priority: priority,
    )) {
      return false;
    }
    if (_emailContentNeedsBodyHydration(message)) {
      _enqueueEmailContentBodyHydration(key: key, message: message);
      return true;
    }
    final normalizedHtml = message.normalizedHtmlBody;
    if (normalizedHtml != null) {
      final cachedDerivation = HtmlContentCodec.cachedEmailDerivations(
        normalizedHtml,
      );
      if (cachedDerivation == null) {
        _enqueueEmailHtmlDerivation(
          key: key,
          message: message,
          normalizedHtml: normalizedHtml,
        );
        if (_emailContentBodyUsable(message)) {
          _recordEmailContentPreparationSuccess(key);
          _completeEmailContentPreparationWaiters(key, true);
        }
        return true;
      }
    }
    if (_emailContentBodyUsable(message)) {
      _recordEmailContentPreparationSuccess(key);
      _completeEmailContentPreparationWaiters(key, true);
      return true;
    }
    return false;
  }

  void _enqueueEmailContentBodyHydration({
    required EmailContentJobKey key,
    required Message message,
  }) {
    final existing = _emailContentBodyTasksByKey[key];
    if (existing != null) {
      return;
    }
    final task = _EmailContentBodyTask(
      key: key,
      message: message,
      queuedAt: DateTime.timestamp(),
      generation: _contentPreparationGeneration,
    );
    _emailContentBodyTasksByKey[key] = task;
    _emailContentBodyPendingTasks.add(task);
    _emitEmailContentPreparationSnapshot();
  }

  void _enqueueEmailHtmlDerivation({
    required EmailContentJobKey key,
    required Message message,
    required String normalizedHtml,
  }) {
    final digest = _emailHtmlDigest(normalizedHtml);
    final existing = _emailContentHtmlDerivationTasksByDigest[digest];
    if (existing != null) {
      existing.messagesByKey[key] = message;
      _emitEmailContentPreparationSnapshot();
      return;
    }
    final task = _EmailContentHtmlDerivationTask(
      digest: digest,
      normalizedHtml: normalizedHtml,
      queuedAt: DateTime.timestamp(),
      generation: _contentPreparationGeneration,
    )..messagesByKey[key] = message;
    _emailContentHtmlDerivationTasksByDigest[digest] = task;
    _emailContentHtmlDerivationPendingTasks.add(task);
    _emitEmailContentPreparationSnapshot();
  }

  void _drainEmailContentPreparationQueues() {
    _drainEmailContentBodyQueue();
    _drainEmailContentHtmlDerivationQueue();
  }

  void _drainEmailContentBodyQueue() {
    while (_emailContentBodyActiveCount <
            _pendingEmailBodyDownloadConcurrentOps &&
        _emailContentBodyPendingTasks.isNotEmpty) {
      final task = _emailContentBodyPendingTasks.removeFirst();
      if (task.generation != _contentPreparationGeneration ||
          !identical(_emailContentBodyTasksByKey[task.key], task)) {
        continue;
      }
      task.started = true;
      _emailContentBodyActiveCount += 1;
      unawaited(_runEmailContentBodyTask(task));
    }
    _emitEmailContentPreparationSnapshot();
  }

  void _drainEmailContentHtmlDerivationQueue() {
    while (_emailContentHtmlDerivationActiveCount <
            _emailHtmlDerivationConcurrentOps &&
        _emailContentHtmlDerivationPendingTasks.isNotEmpty) {
      final task = _emailContentHtmlDerivationPendingTasks.removeFirst();
      if (task.generation != _contentPreparationGeneration ||
          !identical(
            _emailContentHtmlDerivationTasksByDigest[task.digest],
            task,
          )) {
        continue;
      }
      task.started = true;
      _emailContentHtmlDerivationActiveCount += 1;
      unawaited(_runEmailContentHtmlDerivationTask(task));
    }
    _emitEmailContentPreparationSnapshot();
  }

  Future<void> _runEmailContentBodyTask(_EmailContentBodyTask task) async {
    final startedAt = DateTime.timestamp();
    final deadline = startedAt.add(_pendingEmailBodyDownloadTimeout);
    final stopwatch = Stopwatch()..start();
    final traceId = _nextTraceId('email.contentBodyPreparation');
    var result = 'failed';
    var usable = false;
    var retryFailure = true;
    try {
      _traceEmailOperation(
        'email.contentBodyPreparation',
        'start',
        id: traceId,
        fields: <String, Object?>{
          'accountId': task.key.deltaAccountId,
          'chatId': task.key.deltaChatId,
          'deltaMsgId': task.key.deltaMsgId,
          'queueWaitMs': startedAt.difference(task.queuedAt).inMilliseconds,
        },
      );
      final currentBeforeHydration = await _messageForEmailContentKey(
        task,
        deadline: deadline,
      );
      if (currentBeforeHydration == null) {
        result = 'missingStoredMessage';
        return;
      }
      task.message = currentBeforeHydration;
      if (_emailContentPreparationComplete(currentBeforeHydration)) {
        usable = true;
        result = 'alreadyStored';
        return;
      }
      if (currentBeforeHydration.rfc822BodyContentUnavailable) {
        retryFailure = false;
        result = 'alreadyUnavailable';
        return;
      }
      final normalizedHtml = currentBeforeHydration.normalizedHtmlBody;
      if (!_emailContentNeedsBodyHydration(currentBeforeHydration)) {
        retryFailure = false;
        usable = _emailContentBodyUsable(currentBeforeHydration);
        if (normalizedHtml != null &&
            HtmlContentCodec.cachedEmailDerivations(normalizedHtml) == null) {
          _enqueueEmailHtmlDerivation(
            key: task.key,
            message: currentBeforeHydration,
            normalizedHtml: normalizedHtml,
          );
          result = 'htmlDerivationQueued';
        } else {
          result = 'notHydratable';
        }
        return;
      }
      task.loadingIndicatorVisible = true;
      _emitEmailContentPreparationSnapshot();
      final hydration = await downloadAndHydrateFullMessage(
        currentBeforeHydration,
        deadline: deadline,
        pendingHydrationGeneration: task.generation,
        isCanceled: () => _emailContentBodyTaskCanceled(task),
      );
      if (hydration.timedOut) {
        result = 'timeout';
      } else if (!hydration.accepted) {
        result = 'rejected';
      } else {
        final current = await _messageForEmailContentKey(
          task,
          deadline: deadline,
        );
        if (current != null) {
          task.message = current;
          final currentHtml = current.normalizedHtmlBody;
          if (currentHtml != null &&
              HtmlContentCodec.cachedEmailDerivations(currentHtml) == null) {
            _enqueueEmailHtmlDerivation(
              key: task.key,
              message: current,
              normalizedHtml: currentHtml,
            );
          }
          usable = _emailContentBodyUsable(current);
          result = hydration.settled || usable ? 'stored' : 'unsettled';
        } else {
          result = 'missingStoredMessage';
        }
      }
    } on TimeoutException catch (error, stackTrace) {
      _log.fine('Email content body preparation timed out.', error, stackTrace);
      result = 'timeout';
    } on DeltaChatException catch (error, stackTrace) {
      _log.fine('Email content body preparation failed.', error, stackTrace);
    } on EmailProvisioningException catch (error, stackTrace) {
      _log.fine('Email content body preparation failed.', error, stackTrace);
    } on EmailServiceStoppingException catch (error, stackTrace) {
      _log.fine('Email content body preparation failed.', error, stackTrace);
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      _log.fine('Email content body preparation failed.', error, stackTrace);
    } on DeltaSafeException catch (error, stackTrace) {
      _log.fine('Email content body preparation failed.', error, stackTrace);
    } on StateError catch (error, stackTrace) {
      _log.fine('Email content body preparation failed.', error, stackTrace);
    } finally {
      final sameGeneration = task.generation == _contentPreparationGeneration;
      if (sameGeneration) {
        final ownsBookkeeping = identical(
          _emailContentBodyTasksByKey[task.key],
          task,
        );
        if (ownsBookkeeping) {
          _emailContentBodyTasksByKey.remove(task.key);
        }
        if (task.started && _emailContentBodyActiveCount > 0) {
          _emailContentBodyActiveCount -= 1;
        }
        if (ownsBookkeeping) {
          final htmlDerivationPending = _emailHtmlDerivationTaskContains(
            task.key,
          );
          if (usable) {
            _recordEmailContentPreparationSuccess(task.key);
          } else if (!htmlDerivationPending && retryFailure) {
            _recordEmailContentPreparationFailure(task.key, task.message);
          }
          if (usable || !htmlDerivationPending) {
            _completeEmailContentPreparationWaiters(task.key, usable);
          }
        }
        _traceEmailOperation(
          'email.contentBodyPreparation',
          'end',
          id: traceId,
          fields: <String, Object?>{
            'accountId': task.key.deltaAccountId,
            'chatId': task.key.deltaChatId,
            'deltaMsgId': task.key.deltaMsgId,
            'result': result,
            'usable': usable,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
        _emitEmailContentPreparationSnapshot();
        _drainEmailContentPreparationQueues();
      }
    }
  }

  bool _emailContentBodyTaskCanceled(_EmailContentBodyTask task) {
    return task.generation != _contentPreparationGeneration ||
        !identical(_emailContentBodyTasksByKey[task.key], task);
  }

  Future<Message?> _messageForEmailContentKey(
    _EmailContentBodyTask task, {
    required DateTime deadline,
  }) async {
    final result = await _withPendingEmailBodyDownloadBudgetResult(
      () async {
        final db = await _databaseBuilder();
        final current = await db.getMessageByStanzaID(task.message.stanzaID);
        if (current == null || _emailContentJobKey(current) != task.key) {
          return null;
        }
        return current;
      },
      deadline: deadline,
      pendingHydrationGeneration: task.generation,
      isCanceled: () => _emailContentBodyTaskCanceled(task),
    );
    return result.completed ? result.value : null;
  }

  Future<void> _runEmailContentHtmlDerivationTask(
    _EmailContentHtmlDerivationTask task,
  ) async {
    final startedAt = DateTime.timestamp();
    final deadline = startedAt.add(_emailHtmlDerivationTimeout);
    final stopwatch = Stopwatch()..start();
    final traceId = _nextTraceId('email.contentHtmlDerivation');
    var result = 'failed';
    EmailHtmlDerivation? derivation;
    try {
      _traceEmailOperation(
        'email.contentHtmlDerivation',
        'start',
        id: traceId,
        fields: <String, Object?>{
          'digest': task.digest,
          'messageCount': task.messagesByKey.length,
          'queueWaitMs': startedAt.difference(task.queuedAt).inMilliseconds,
        },
      );
      final derived = await _withPendingEmailBodyDownloadBudgetResult(
        () async {
          await HtmlContentCodec.precacheEmailDerivations([
            task.normalizedHtml,
          ]);
          return HtmlContentCodec.cachedEmailDerivations(task.normalizedHtml);
        },
        deadline: deadline,
        pendingHydrationGeneration: task.generation,
      );
      if (!derived.completed) {
        result = 'timeout';
      } else {
        derivation = derived.value;
        result = derivation == null ? 'missingDerivation' : 'derived';
      }
    } on StateError catch (error, stackTrace) {
      _log.fine('Email HTML derivation failed.', error, stackTrace);
    } finally {
      final sameGeneration = task.generation == _contentPreparationGeneration;
      if (sameGeneration) {
        var ownsBookkeeping = identical(
          _emailContentHtmlDerivationTasksByDigest[task.digest],
          task,
        );
        var usableByKey = <EmailContentJobKey, bool>{};
        if (ownsBookkeeping) {
          usableByKey = await _settleEmailHtmlDerivationTask(
            task,
            derivation: derivation,
            deadline: deadline,
            isCanceled: () => _emailContentHtmlDerivationTaskCanceled(task),
          );
          ownsBookkeeping =
              task.generation == _contentPreparationGeneration &&
              identical(
                _emailContentHtmlDerivationTasksByDigest[task.digest],
                task,
              );
        }
        if (ownsBookkeeping) {
          _emailContentHtmlDerivationTasksByDigest.remove(task.digest);
          for (final entry in task.messagesByKey.entries) {
            final usable = usableByKey[entry.key] ?? false;
            if (usable) {
              _recordEmailContentPreparationSuccess(entry.key);
            } else {
              _recordEmailContentPreparationFailure(entry.key, entry.value);
            }
            _completeEmailContentPreparationWaiters(entry.key, usable);
          }
        }
        if (task.started && _emailContentHtmlDerivationActiveCount > 0) {
          _emailContentHtmlDerivationActiveCount -= 1;
        }
        _traceEmailOperation(
          'email.contentHtmlDerivation',
          'end',
          id: traceId,
          fields: <String, Object?>{
            'digest': task.digest,
            'messageCount': task.messagesByKey.length,
            'result': result,
            'elapsedMs': stopwatch.elapsedMilliseconds,
          },
        );
        _emitEmailContentPreparationSnapshot();
        _drainEmailContentPreparationQueues();
      }
    }
  }

  bool _emailContentHtmlDerivationTaskCanceled(
    _EmailContentHtmlDerivationTask task,
  ) {
    return task.generation != _contentPreparationGeneration ||
        !identical(_emailContentHtmlDerivationTasksByDigest[task.digest], task);
  }

  Future<Map<EmailContentJobKey, bool>> _settleEmailHtmlDerivationTask(
    _EmailContentHtmlDerivationTask task, {
    required EmailHtmlDerivation? derivation,
    required DateTime deadline,
    required bool Function() isCanceled,
  }) async {
    final usableByKey = <EmailContentJobKey, bool>{};
    if (derivation == null) {
      for (final key in task.messagesByKey.keys) {
        usableByKey[key] = false;
      }
      return usableByKey;
    }
    final settledResult = await _withPendingEmailBodyDownloadBudgetResult(
      () => _trackAppDatabaseOperation(() async {
        if (!_pendingEmailBodyHydrationCanContinue(
          deadline: deadline,
          pendingHydrationGeneration: task.generation,
          isCanceled: isCanceled,
        )) {
          return false;
        }
        final db = await _databaseBuilder();
        if (!_pendingEmailBodyHydrationCanContinue(
          deadline: deadline,
          pendingHydrationGeneration: task.generation,
          isCanceled: isCanceled,
        )) {
          return false;
        }
        for (final entry in task.messagesByKey.entries) {
          final message = await db.getMessageByStanzaID(entry.value.stanzaID);
          final normalizedHtml = message?.normalizedHtmlBody;
          if (message == null ||
              normalizedHtml == null ||
              _emailHtmlDigest(normalizedHtml) != task.digest) {
            usableByKey[entry.key] = false;
            continue;
          }
          final settled = _messageSettledAfterHtmlDerivation(
            message: message,
            derivation: derivation,
          );
          usableByKey[entry.key] = _emailContentPreparationComplete(settled);
          if (settled == message) {
            continue;
          }
          if (!_pendingEmailBodyHydrationCanContinue(
            deadline: deadline,
            pendingHydrationGeneration: task.generation,
            isCanceled: isCanceled,
          )) {
            return false;
          }
          await db.updateMessage(settled);
          if (!_pendingEmailBodyHydrationCanContinue(
            deadline: deadline,
            pendingHydrationGeneration: task.generation,
            isCanceled: isCanceled,
          )) {
            return false;
          }
          await db.repairChatSummaryFromMessages(settled.chatJid);
        }
        return true;
      }),
      deadline: deadline,
      pendingHydrationGeneration: task.generation,
      isCanceled: isCanceled,
    );
    if (!settledResult.completed || settledResult.value != true) {
      for (final key in task.messagesByKey.keys) {
        usableByKey[key] = false;
      }
      return usableByKey;
    }
    for (final key in task.messagesByKey.keys) {
      usableByKey.putIfAbsent(key, () => false);
    }
    return usableByKey;
  }

  Message _messageSettledAfterHtmlDerivation({
    required Message message,
    required EmailHtmlDerivation derivation,
  }) {
    final existingBody = message.body?.trim();
    final safePlainBody =
        existingBody?.isNotEmpty == true &&
            !HtmlContentCodec.looksLikeCssBodyText(existingBody!)
        ? existingBody
        : null;
    final visibleHtmlText = derivation.visibleBodyText.trim();
    if (message.rfc822BodyStatus.isPendingDownload) {
      return message;
    }
    if (!_emailHtmlDerivationHasRenderableContent(derivation)) {
      if (safePlainBody != null) {
        return message.copyWith(
          htmlBody: null,
          rfc822BodyStatus: EmailRfc822BodyStatus.hydrated,
          pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
        );
      }
      return message.copyWith(
        body: null,
        htmlBody: null,
        rfc822BodyStatus: EmailRfc822BodyStatus.unavailable,
        pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
      );
    }
    return message.copyWith(
      body: safePlainBody ?? (visibleHtmlText.isEmpty ? null : visibleHtmlText),
      htmlBody: message.normalizedHtmlBody,
      rfc822BodyStatus: EmailRfc822BodyStatus.hydrated,
      pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
    );
  }

  bool _emailContentNeedsBodyHydration(Message message) {
    if (!message.rfc822BodyStatus.isPendingDownload ||
        message.rfc822BodyContentUnavailable) {
      return false;
    }
    return true;
  }

  bool _emailContentPreparationComplete(Message message) {
    if (message.rfc822BodyContentUnavailable) {
      return false;
    }
    if (message.rfc822BodyStatus.isPendingDownload) {
      return false;
    }
    final normalizedHtml = message.normalizedHtmlBody;
    if (normalizedHtml != null &&
        HtmlContentCodec.cachedEmailDerivations(normalizedHtml) == null) {
      return false;
    }
    return _emailContentBodyUsable(message);
  }

  bool _emailContentBodyUsable(Message message) {
    if (_emailContentHasSafePlainBody(message)) {
      return true;
    }
    final normalizedHtml = message.normalizedHtmlBody;
    if (normalizedHtml == null) {
      return false;
    }
    final derivation = HtmlContentCodec.cachedEmailDerivations(normalizedHtml);
    return derivation != null &&
        _emailHtmlDerivationHasRenderableContent(derivation);
  }

  bool _emailContentHasSafePlainBody(Message message) {
    final body = message.body?.trim();
    return body?.isNotEmpty == true &&
        !HtmlContentCodec.looksLikeCssBodyText(body!);
  }

  String _emailHtmlDigest(String normalizedHtml) =>
      crypto.sha256.convert(utf8.encode(normalizedHtml)).toString();

  bool _emailContentRetryDeferred({
    required EmailContentJobKey key,
    required Message message,
    required EmailContentPreparationPriority priority,
  }) {
    final deferral = _emailContentRetryDeferrals[key];
    if (deferral == null) {
      return false;
    }
    if (priority == EmailContentPreparationPriority.manual) {
      _emailContentRetryDeferrals.remove(key);
      _scheduleEmailContentRetryTimer();
      return false;
    }
    final fingerprint = _emailContentRetryFingerprint(message);
    if (deferral.fingerprint != fingerprint) {
      _emailContentRetryDeferrals.remove(key);
      _scheduleEmailContentRetryTimer();
      return false;
    }
    if (!DateTime.timestamp().isBefore(deferral.nextRetryAt)) {
      return false;
    }
    _scheduleEmailContentRetryTimer();
    return true;
  }

  bool _emailContentTaskShowsLoadingIndicator({
    required EmailContentJobKey key,
    required Message message,
  }) {
    final deferral = _emailContentRetryDeferrals[key];
    return deferral == null ||
        deferral.fingerprint != _emailContentRetryFingerprint(message);
  }

  void _recordEmailContentPreparationSuccess(EmailContentJobKey key) {
    if (_emailContentRetryDeferrals.remove(key) != null) {
      _scheduleEmailContentRetryTimer();
    }
  }

  void _recordEmailContentPreparationFailure(
    EmailContentJobKey key,
    Message message,
  ) {
    final fingerprint = _emailContentRetryFingerprint(message);
    final previous = _emailContentRetryDeferrals[key];
    final failureCount = previous?.fingerprint == fingerprint
        ? previous!.failureCount + 1
        : 1;
    final delay = failureCount == 1
        ? _pendingEmailBodyDownloadTimeout
        : failureCount == 2
        ? _emailContentRetrySecondDelay
        : _emailContentRetryMaxDelay;
    _emailContentRetryDeferrals[key] = _EmailContentRetryDeferral(
      fingerprint: fingerprint,
      failureCount: failureCount,
      nextRetryAt: DateTime.timestamp().add(delay),
    );
    _scheduleEmailContentRetryTimer();
  }

  void _scheduleEmailContentRetryTimer() {
    _emailContentRetryTimer?.cancel();
    _emailContentRetryTimer = null;
    if (_emailContentRetryDeferrals.isEmpty) {
      return;
    }
    DateTime? nextRetryAt;
    for (final deferral in _emailContentRetryDeferrals.values) {
      if (nextRetryAt == null || deferral.nextRetryAt.isBefore(nextRetryAt)) {
        nextRetryAt = deferral.nextRetryAt;
      }
    }
    final delay = nextRetryAt!.difference(DateTime.timestamp());
    _emailContentRetryTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      _scheduleVisibleEmailContentPreparation,
    );
  }

  String _emailContentRetryFingerprint(Message message) {
    return jsonEncode(<String, Object?>{
      'stanzaID': message.stanzaID,
      'deltaAccountId': message.deltaAccountId,
      'deltaChatId': message.deltaChatId,
      'deltaMsgId': message.deltaMsgId,
      'body': message.body,
      'htmlBody': message.normalizedHtmlBody,
      'rfc822BodyStatus': message.rfc822BodyStatus.index,
      'pseudoMessageData': _stableJsonValue(message.pseudoMessageData),
    });
  }

  Object? _stableJsonValue(Object? value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in value.entries) {
        sorted['${entry.key}'] = _stableJsonValue(entry.value);
      }
      return sorted;
    }
    if (value is Iterable && value is! String) {
      return value.map(_stableJsonValue).toList(growable: false);
    }
    return value;
  }

  bool _emailHtmlDerivationTaskContains(EmailContentJobKey key) {
    for (final task in _emailContentHtmlDerivationTasksByDigest.values) {
      if (task.messagesByKey.containsKey(key)) {
        return true;
      }
    }
    return false;
  }

  void _completeEmailContentPreparationWaiters(
    EmailContentJobKey key,
    bool result,
  ) {
    final waiters = _emailContentPreparationWaiters.remove(key);
    if (waiters == null) {
      return;
    }
    for (final waiter in waiters) {
      if (!waiter.isCompleted) {
        waiter.complete(result);
      }
    }
  }

  void _cancelUnwantedVisibleEmailContentTasks() {
    final desiredKeys = <EmailContentJobKey>{};
    for (final messagesByKey in _visibleEmailContentMessagesByChatJid.values) {
      desiredKeys.addAll(messagesByKey.keys);
    }
    for (final entry in _emailContentBodyTasksByKey.entries.toList(
      growable: false,
    )) {
      final key = entry.key;
      final task = entry.value;
      if (desiredKeys.contains(key) ||
          _emailContentPreparationWaiters.containsKey(key)) {
        continue;
      }
      _emailContentBodyPendingTasks.remove(task);
      _emailContentBodyTasksByKey.remove(key);
    }
    for (final task in _emailContentHtmlDerivationTasksByDigest.values.toList(
      growable: false,
    )) {
      task.messagesByKey.removeWhere(
        (key, _) =>
            !desiredKeys.contains(key) &&
            !_emailContentPreparationWaiters.containsKey(key),
      );
      if (task.messagesByKey.isEmpty &&
          identical(
            _emailContentHtmlDerivationTasksByDigest[task.digest],
            task,
          )) {
        _emailContentHtmlDerivationPendingTasks.remove(task);
        _emailContentHtmlDerivationTasksByDigest.remove(task.digest);
      }
    }
    _drainEmailContentPreparationQueues();
  }

  void _emitEmailContentPreparationSnapshot({bool force = false}) {
    final bodyKeys = Set<EmailContentJobKey>.unmodifiable(
      _emailContentBodyTasksByKey.keys,
    );
    final loadingIndicatorKeys = <EmailContentJobKey>{};
    for (final entry in _emailContentBodyTasksByKey.entries) {
      final task = entry.value;
      if (task.loadingIndicatorVisible &&
          _emailContentTaskShowsLoadingIndicator(
            key: entry.key,
            message: task.message,
          )) {
        loadingIndicatorKeys.add(entry.key);
      }
    }
    final htmlKeys = <EmailContentJobKey>{};
    for (final task in _emailContentHtmlDerivationTasksByDigest.values) {
      htmlKeys.addAll(task.messagesByKey.keys);
    }
    if (!force &&
        setEquals(
          bodyKeys,
          _contentPreparationSnapshot.activeBodyHydrationKeys,
        ) &&
        setEquals(
          htmlKeys,
          _contentPreparationSnapshot.activeHtmlDerivationKeys,
        ) &&
        setEquals(
          loadingIndicatorKeys,
          _contentPreparationSnapshot.activeLoadingIndicatorKeys,
        )) {
      return;
    }
    _contentPreparationRevision += 1;
    _contentPreparationSnapshot = EmailContentPreparationSnapshot(
      activeBodyHydrationKeys: bodyKeys,
      activeHtmlDerivationKeys: Set<EmailContentJobKey>.unmodifiable(htmlKeys),
      activeLoadingIndicatorKeys: Set<EmailContentJobKey>.unmodifiable(
        loadingIndicatorKeys,
      ),
      revision: _contentPreparationRevision,
    );
    _contentPreparationController.add(_contentPreparationSnapshot);
  }

  void _emitEmailOriginalContentSnapshot({bool force = false}) {
    final htmlByKey = Map<EmailContentJobKey, String>.unmodifiable(
      _emailOriginalHtmlByKey,
    );
    final loadingKeys = Set<EmailContentJobKey>.unmodifiable(
      _emailOriginalLoadingKeys,
    );
    final unavailableKeys = Set<EmailContentJobKey>.unmodifiable(
      _emailOriginalUnavailableKeys,
    );
    if (!force &&
        mapEquals(htmlByKey, _originalContentSnapshot.htmlByKey) &&
        setEquals(loadingKeys, _originalContentSnapshot.loadingKeys) &&
        setEquals(unavailableKeys, _originalContentSnapshot.unavailableKeys)) {
      return;
    }
    _originalContentRevision += 1;
    _originalContentSnapshot = EmailOriginalContentSnapshot(
      htmlByKey: htmlByKey,
      loadingKeys: loadingKeys,
      unavailableKeys: unavailableKeys,
      revision: _originalContentRevision,
    );
    _originalContentController.add(_originalContentSnapshot);
  }

  void _resetEmailOriginalContent() {
    _originalContentGeneration += 1;
    _emailOriginalHtmlByKey.clear();
    _emailOriginalLoadingKeys.clear();
    _emailOriginalUnavailableKeys.clear();
    _emitEmailOriginalContentSnapshot(force: true);
  }

  void _resetEmailContentPreparation() {
    _contentPreparationGeneration += 1;
    _visibleEmailContentMessagesByChatJid.clear();
    _emailContentBodyPendingTasks.clear();
    _emailContentBodyTasksByKey.clear();
    _emailContentBodyActiveCount = 0;
    _emailContentHtmlDerivationPendingTasks.clear();
    _emailContentHtmlDerivationTasksByDigest.clear();
    _emailContentHtmlDerivationActiveCount = 0;
    _emailContentRetryDeferrals.clear();
    _emailContentRetryTimer?.cancel();
    _emailContentRetryTimer = null;
    final waiters = _emailContentPreparationWaiters.values
        .expand((items) => items)
        .toList(growable: false);
    _emailContentPreparationWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) {
        waiter.complete(false);
      }
    }
    _emitEmailContentPreparationSnapshot(force: true);
  }

  Future<({bool completed, T? value})>
  _withPendingEmailBodyDownloadBudgetResult<T>(
    Future<T> Function() operation, {
    required DateTime? deadline,
    int? pendingHydrationGeneration,
    bool Function()? isCanceled,
  }) async {
    if (!_pendingEmailBodyHydrationCanContinue(
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    )) {
      return (completed: false, value: null);
    }
    if (deadline == null) {
      try {
        final value = await operation();
        if (!_pendingEmailBodyHydrationCanContinue(
          deadline: deadline,
          pendingHydrationGeneration: pendingHydrationGeneration,
          isCanceled: isCanceled,
        )) {
          return (completed: false, value: null);
        }
        return (completed: true, value: value);
      } on Exception {
        if (!_pendingEmailBodyHydrationCanContinue(
          deadline: deadline,
          pendingHydrationGeneration: pendingHydrationGeneration,
          isCanceled: isCanceled,
        )) {
          return (completed: false, value: null);
        }
        rethrow;
      }
    }
    final remaining = deadline.difference(DateTime.timestamp());
    if (remaining <= Duration.zero) {
      return (completed: false, value: null);
    }
    final timeoutSentinel = Object();
    late final Object? value;
    try {
      value = await operation()
          .then<Object?>((value) => value)
          .timeout(remaining, onTimeout: () => timeoutSentinel);
    } on Exception {
      if (!_pendingEmailBodyHydrationCanContinue(
        deadline: deadline,
        pendingHydrationGeneration: pendingHydrationGeneration,
        isCanceled: isCanceled,
      )) {
        return (completed: false, value: null);
      }
      rethrow;
    }
    if (identical(value, timeoutSentinel)) {
      return (completed: false, value: null);
    }
    if (!_pendingEmailBodyHydrationCanContinue(
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    )) {
      return (completed: false, value: null);
    }
    return (completed: true, value: value as T?);
  }

  bool _pendingEmailBodyHydrationCanContinue({
    required DateTime? deadline,
    required int? pendingHydrationGeneration,
    bool Function()? isCanceled,
  }) {
    if (pendingHydrationGeneration != null &&
        pendingHydrationGeneration != _contentPreparationGeneration) {
      return false;
    }
    if (isCanceled?.call() == true) {
      return false;
    }
    return deadline == null || DateTime.timestamp().isBefore(deadline);
  }

  Future<bool?> _downloadFullMessageWithPendingBudget({
    required int deltaMsgId,
    required int accountId,
    required DateTime? deadline,
    int? pendingHydrationGeneration,
    bool Function()? isCanceled,
  }) async {
    final result = await _withPendingEmailBodyDownloadBudgetResult(
      () => _transport.downloadFullMessage(deltaMsgId, accountId: accountId),
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    );
    return result.completed ? result.value : null;
  }

  Future<bool> _waitForFullMessageMaterial(
    Message message, {
    required int accountId,
    required DateTime deadline,
  }) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) {
      return false;
    }
    while (DateTime.timestamp().isBefore(deadline)) {
      final currentResult = await _withPendingEmailBodyDownloadBudgetResult(
        () => _trackAppDatabaseOperation(() async {
          final db = await _databaseBuilder();
          final current = await db.getMessageByStanzaID(message.stanzaID);
          if (current == null) {
            return false;
          }
          return _storedFullMessageMaterialAvailable(db, current);
        }),
        deadline: deadline,
      );
      if (currentResult.completed && currentResult.value == true) {
        return true;
      }
      final rfc822Body = await _withPendingEmailBodyDownloadBudgetResult(
        () => _transport.getMessageRfc822Body(deltaId, accountId: accountId),
        deadline: deadline,
      );
      if (!rfc822Body.completed) {
        return _storedFullMessageMaterialAvailableForMessage(message);
      }
      final body = rfc822Body.value;
      if (body != null && body.hasBody) {
        final current = await _trackAppDatabaseOperation(() async {
          final db = await _databaseBuilder();
          return db.getMessageByStanzaID(message.stanzaID);
        });
        final hydration = await hydrateStoredRfc822BodyContent(
          current ?? message,
          rfc822Body: body,
          deadline: deadline,
        );
        if (hydration.timedOut) {
          return _storedFullMessageMaterialAvailableForMessage(message);
        }
      }
      final currentAfterHydration =
          await _withPendingEmailBodyDownloadBudgetResult(
            () => _trackAppDatabaseOperation(() async {
              final db = await _databaseBuilder();
              final current = await db.getMessageByStanzaID(message.stanzaID);
              if (current == null) {
                return false;
              }
              return _storedFullMessageMaterialAvailable(db, current);
            }),
            deadline: deadline,
          );
      if (currentAfterHydration.completed &&
          currentAfterHydration.value == true) {
        return true;
      }
      await Future<void>.delayed(_pendingEmailBodyDownloadPollInterval);
    }
    return _storedFullMessageMaterialAvailableForMessage(message);
  }

  Future<bool> _storedFullMessageMaterialAvailableForMessage(
    Message message,
  ) async {
    return _trackAppDatabaseOperation(() async {
      final db = await _databaseBuilder();
      final current = await db.getMessageByStanzaID(message.stanzaID);
      if (current == null) {
        return false;
      }
      return _storedFullMessageMaterialAvailable(db, current);
    });
  }

  Future<bool> _storedFullMessageMaterialAvailable(
    XmppDatabase db,
    Message message,
  ) async {
    if (!message.rfc822BodyStatus.isPendingDownload &&
        _emailContentBodyUsable(message)) {
      return true;
    }
    final metadataIds = <String>{};
    void addMetadataId(String? metadataId) {
      final trimmed = metadataId?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        metadataIds.add(trimmed);
      }
    }

    addMetadataId(message.fileMetadataID);
    final messageId = message.id;
    if (messageId != null && messageId.isNotEmpty) {
      final attachments = await db.getMessageAttachments(messageId);
      for (final attachment in attachments) {
        addMetadataId(attachment.fileMetadataId);
      }
    }
    if (metadataIds.isEmpty) {
      return false;
    }
    final metadataItems = await db.getFileMetadataForIds(metadataIds);
    for (final metadata in metadataItems) {
      if (await _fileMetadataHasLocalFile(metadata)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _fileMetadataHasLocalFile(FileMetadataData metadata) async {
    final path = metadata.path?.trim();
    if (path == null || path.isEmpty) {
      return false;
    }
    return File(path).exists();
  }

  Future<EmailFullMessageHydrationResult> downloadAndHydrateFullMessage(
    Message message, {
    DateTime? deadline,
    int? pendingHydrationGeneration,
    bool Function()? isCanceled,
  }) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) {
      return const EmailFullMessageHydrationResult(
        accepted: false,
        html: null,
        settled: false,
        timedOut: false,
        bodyAvailable: false,
      );
    }
    final readyResult = await _withPendingEmailBodyDownloadBudgetResult(
      () async {
        await _ensureReady();
        return true;
      },
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    );
    if (!readyResult.completed) {
      return const EmailFullMessageHydrationResult(
        accepted: true,
        html: null,
        settled: false,
        timedOut: true,
        bodyAvailable: false,
      );
    }
    final accountResult = await _withPendingEmailBodyDownloadBudgetResult(
      () => _storedDeltaAccountIdForBodyHydration(
        message,
        deadline: deadline,
        pendingHydrationGeneration: pendingHydrationGeneration,
        isCanceled: isCanceled,
      ),
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    );
    if (!accountResult.completed) {
      return const EmailFullMessageHydrationResult(
        accepted: true,
        html: null,
        settled: false,
        timedOut: true,
        bodyAvailable: false,
      );
    }
    final accountId = accountResult.value;
    if (accountId == null) {
      return const EmailFullMessageHydrationResult(
        accepted: false,
        html: null,
        settled: false,
        timedOut: false,
        bodyAvailable: false,
      );
    }
    final acceptedResult = await _downloadFullMessageWithPendingBudget(
      deltaMsgId: deltaId,
      accountId: accountId,
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    );
    if (acceptedResult == false) {
      return const EmailFullMessageHydrationResult(
        accepted: false,
        html: null,
        settled: false,
        timedOut: false,
        bodyAvailable: false,
      );
    }
    if (acceptedResult == null) {
      return const EmailFullMessageHydrationResult(
        accepted: true,
        html: null,
        settled: false,
        timedOut: true,
        bodyAvailable: false,
      );
    }
    final rfc822Body = await _waitForMessageRfc822Body(
      deltaMsgId: deltaId,
      accountId: accountId,
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    );
    final body = rfc822Body.body;
    if (body == null) {
      return EmailFullMessageHydrationResult(
        accepted: true,
        html: null,
        settled: false,
        timedOut: rfc822Body.timedOut,
        bodyAvailable: false,
      );
    }
    final hydration = await hydrateStoredRfc822BodyContent(
      message,
      rfc822Body: body,
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    );
    return EmailFullMessageHydrationResult(
      accepted: true,
      html: hydration.html,
      settled: hydration.settled,
      timedOut: hydration.timedOut,
      bodyAvailable: true,
    );
  }

  Future<({DeltaMessageRfc822Body? body, bool timedOut})>
  _waitForMessageRfc822Body({
    required int deltaMsgId,
    required int accountId,
    DateTime? deadline,
    int? pendingHydrationGeneration,
    bool Function()? isCanceled,
  }) async {
    final effectiveDeadline =
        deadline ?? DateTime.timestamp().add(_pendingEmailBodyDownloadTimeout);
    while (true) {
      final rfc822Body = await _withPendingEmailBodyDownloadBudgetResult(
        () => _transport.getMessageRfc822Body(deltaMsgId, accountId: accountId),
        deadline: effectiveDeadline,
        pendingHydrationGeneration: pendingHydrationGeneration,
        isCanceled: isCanceled,
      );
      if (!rfc822Body.completed) {
        return (body: null, timedOut: true);
      }
      final body = rfc822Body.value;
      if (body != null && body.hasBody) {
        return (body: body, timedOut: false);
      }
      if (!DateTime.timestamp().isBefore(effectiveDeadline)) {
        return (body: null, timedOut: true);
      }
      await Future<void>.delayed(_pendingEmailBodyDownloadPollInterval);
      if (!_pendingEmailBodyHydrationCanContinue(
        deadline: effectiveDeadline,
        pendingHydrationGeneration: pendingHydrationGeneration,
        isCanceled: isCanceled,
      )) {
        return (body: null, timedOut: true);
      }
    }
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
    final accountId = await _storedDeltaAccountIdForBodyHydration(message);
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
    final accountId = await _storedDeltaAccountIdForBodyHydration(message);
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
    final result = await _getMessageFullHtmlWithBudget(message);
    return result.html;
  }

  Future<({String? html, bool definitive, bool timedOut})>
  _getMessageFullHtmlWithBudget(
    Message message, {
    DateTime? deadline,
    bool Function()? isCanceled,
  }) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) {
      return (html: null, definitive: false, timedOut: false);
    }
    final readyResult = await _withPendingEmailBodyDownloadBudgetResult(
      () async {
        await _ensureReady();
        return true;
      },
      deadline: deadline,
      isCanceled: isCanceled,
    );
    if (!readyResult.completed) {
      return (html: null, definitive: false, timedOut: true);
    }
    final accountResult = await _withPendingEmailBodyDownloadBudgetResult(
      () => _storedDeltaAccountIdForBodyHydration(
        message,
        deadline: deadline,
        isCanceled: isCanceled,
      ),
      deadline: deadline,
      isCanceled: isCanceled,
    );
    if (!accountResult.completed) {
      return (html: null, definitive: false, timedOut: true);
    }
    final accountId = accountResult.value;
    if (accountId == null) {
      return (html: null, definitive: false, timedOut: false);
    }
    final htmlResult = await _withPendingEmailBodyDownloadBudgetResult(
      () => _transport.getMessageFullHtml(deltaId, accountId: accountId),
      deadline: deadline,
      isCanceled: isCanceled,
    );
    if (!htmlResult.completed) {
      return (html: null, definitive: false, timedOut: true);
    }
    return (html: htmlResult.value, definitive: true, timedOut: false);
  }

  Future<int?> _resolveDeltaAccountIdForStoredMessage(
    Message message, {
    List<int>? activeAccountIds,
  }) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) {
      return null;
    }
    final accountIds =
        activeAccountIds ??
        _usableDeltaAccountIds(await _transport.accountIds());
    final storedAccountId = message.deltaAccountId;
    final storedOrigin = normalizeEmailMessageId(message.originID);
    if (accountIds.contains(storedAccountId)) {
      final candidate = await _loadDeltaMessageForStoredLocator(
        message: message,
        deltaAccountId: storedAccountId,
      );
      if (candidate == null) {
        return null;
      }
      if (storedOrigin == null &&
          !_deltaMessageMatchesStoredChat(
            message: message,
            deltaMessage: candidate,
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
    final matches = <int>[];
    for (final accountId in accountIds) {
      final candidate = await _loadDeltaMessageForStoredLocator(
        message: message,
        deltaAccountId: accountId,
      );
      if (candidate == null) {
        continue;
      }
      if (storedOrigin == null) {
        if (_deltaMessageMatchesStoredChat(
          message: message,
          deltaMessage: candidate,
        )) {
          matches.add(accountId);
        }
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

  Future<int?> _storedDeltaAccountIdForBodyHydration(
    Message message, {
    DateTime? deadline,
    int? pendingHydrationGeneration,
    bool Function()? isCanceled,
  }) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) {
      return null;
    }
    final accountIds = _usableDeltaAccountIds(await _transport.accountIds());
    if (!_pendingEmailBodyHydrationCanContinue(
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    )) {
      return null;
    }
    if (accountIds.contains(message.deltaAccountId)) {
      return message.deltaAccountId;
    }
    if (accountIds.length != 1) {
      return null;
    }
    final accountId = accountIds.single;
    if (!_pendingEmailBodyHydrationCanContinue(
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    )) {
      return null;
    }
    await _repairStoredMessageDeltaAccountId(
      message: message,
      deltaAccountId: accountId,
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    );
    if (!_pendingEmailBodyHydrationCanContinue(
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    )) {
      return null;
    }
    return accountId;
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

  Future<DeltaMessage?> _loadDeltaMessageForStoredLocator({
    required Message message,
    required int deltaAccountId,
  }) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) {
      return null;
    }
    try {
      return await _transport.getMessage(deltaId, accountId: deltaAccountId);
    } on EmailDeltaWorkerRuntimeException catch (error, stackTrace) {
      _log.fine('Failed to validate Delta message locator.', error, stackTrace);
      return null;
    } on DeltaSafeException catch (error, stackTrace) {
      _log.fine('Failed to validate Delta message locator.', error, stackTrace);
      return null;
    } on TimeoutException catch (error, stackTrace) {
      _log.fine(
        'Timed out validating Delta message locator.',
        error,
        stackTrace,
      );
      return null;
    }
  }

  bool _deltaMessageMatchesStoredChat({
    required Message message,
    required DeltaMessage deltaMessage,
  }) {
    final deltaChatId = message.deltaChatId;
    return deltaChatId != null &&
        deltaChatId > DeltaChatId.lastSpecial &&
        deltaMessage.chatId == deltaChatId;
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
    DateTime? deadline,
    int? pendingHydrationGeneration,
    bool Function()? isCanceled,
  }) async {
    if (message.deltaAccountId == deltaAccountId) {
      return;
    }
    await _withPendingEmailBodyDownloadBudgetResult(
      () => _trackAppDatabaseOperation(() async {
        final db = await _databaseBuilder();
        if (!_pendingEmailBodyHydrationCanContinue(
          deadline: deadline,
          pendingHydrationGeneration: pendingHydrationGeneration,
          isCanceled: isCanceled,
        )) {
          return;
        }
        await db.repairMessageDeltaAccountIdIfUnclaimed(
          stanzaID: message.stanzaID,
          deltaAccountId: deltaAccountId,
        );
      }),
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    );
  }

  /// Gets body-only content parsed from the stored RFC822 MIME, if available.
  Future<DeltaMessageRfc822Body?> getMessageRfc822Body(Message message) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) return null;
    await _ensureReady();
    final accountId = await _storedDeltaAccountIdForBodyHydration(message);
    if (accountId == null) {
      return null;
    }
    return _transport.getMessageRfc822Body(deltaId, accountId: accountId);
  }

  Future<({String? html, bool settled, bool timedOut})>
  hydrateStoredRfc822BodyContent(
    Message message, {
    DeltaMessageRfc822Body? rfc822Body,
    DateTime? deadline,
    int? pendingHydrationGeneration,
    bool Function()? isCanceled,
  }) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null || deltaId <= _deltaMessageIdUnset) {
      return (html: null, settled: false, timedOut: false);
    }
    if (message.hasRfc822BodyContent) {
      return (html: message.normalizedHtmlBody, settled: true, timedOut: false);
    }
    if (message.rfc822BodyContentUnavailable) {
      return (html: null, settled: true, timedOut: false);
    }
    final traceId = _nextTraceId('email.rfc822BodyHydration');
    final watch = Stopwatch()..start();
    _traceEmailOperation(
      'email.rfc822BodyHydration',
      'start',
      id: traceId,
      fields: <String, Object?>{
        'deltaMsgId': deltaId,
        'storedAccountId': message.deltaAccountId,
      },
    );
    final readyResult = await _withPendingEmailBodyDownloadBudgetResult(
      () async {
        await _ensureReady();
        return true;
      },
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    );
    if (!readyResult.completed) {
      _traceEmailOperation(
        'email.rfc822BodyHydration',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'result': 'timeoutBeforeReady',
          'elapsedMs': watch.elapsedMilliseconds,
        },
      );
      return (html: null, settled: false, timedOut: true);
    }
    final accountResult = await _withPendingEmailBodyDownloadBudgetResult(
      () => _storedDeltaAccountIdForBodyHydration(
        message,
        deadline: deadline,
        pendingHydrationGeneration: pendingHydrationGeneration,
        isCanceled: isCanceled,
      ),
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    );
    if (!accountResult.completed) {
      _traceEmailOperation(
        'email.rfc822BodyHydration',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'result': 'timeoutBeforeAccount',
          'elapsedMs': watch.elapsedMilliseconds,
        },
      );
      return (html: null, settled: false, timedOut: true);
    }
    final accountId = accountResult.value;
    if (accountId == null) {
      _traceEmailOperation(
        'email.rfc822BodyHydration',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'result': 'missingAccount',
          'elapsedMs': watch.elapsedMilliseconds,
        },
      );
      return (html: null, settled: false, timedOut: false);
    }
    final resolvedRfc822BodyResult = rfc822Body == null
        ? await _withPendingEmailBodyDownloadBudgetResult(
            () =>
                _transport.getMessageRfc822Body(deltaId, accountId: accountId),
            deadline: deadline,
            pendingHydrationGeneration: pendingHydrationGeneration,
            isCanceled: isCanceled,
          )
        : (completed: true, value: rfc822Body);
    if (!resolvedRfc822BodyResult.completed) {
      _traceEmailOperation(
        'email.rfc822BodyHydration',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'result': 'timeoutBeforeBody',
          'accountId': accountId,
          'elapsedMs': watch.elapsedMilliseconds,
        },
      );
      return (html: null, settled: false, timedOut: true);
    }
    final resolvedRfc822Body = resolvedRfc822BodyResult.value;
    if (resolvedRfc822Body == null || !resolvedRfc822Body.hasBody) {
      if (message.rfc822BodyStatus.isPendingDownload) {
        _traceEmailOperation(
          'email.rfc822BodyHydration',
          'end',
          id: traceId,
          fields: <String, Object?>{
            'result': 'pendingBodyUnavailable',
            'accountId': accountId,
            'elapsedMs': watch.elapsedMilliseconds,
          },
        );
        return (html: null, settled: false, timedOut: false);
      }
    }
    var result = 'missingStoredMessage';
    var settled = false;
    String? hydratedHtml;
    final currentResult = await _withPendingEmailBodyDownloadBudgetResult(
      () async {
        final db = await _databaseBuilder();
        return db.getMessageByStanzaID(message.stanzaID);
      },
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    );
    if (!currentResult.completed) {
      _traceEmailOperation(
        'email.rfc822BodyHydration',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'result': 'timeoutBeforeRead',
          'accountId': accountId,
          'elapsedMs': watch.elapsedMilliseconds,
        },
      );
      return (html: null, settled: false, timedOut: true);
    }
    final current = currentResult.value;
    if (current == null) {
      _traceEmailOperation(
        'email.rfc822BodyHydration',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'result': result,
          'accountId': accountId,
          'elapsedMs': watch.elapsedMilliseconds,
        },
      );
      return (html: null, settled: false, timedOut: false);
    }
    if (current.hasRfc822BodyContent) {
      _traceEmailOperation(
        'email.rfc822BodyHydration',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'result': 'alreadyStored',
          'accountId': accountId,
          'elapsedMs': watch.elapsedMilliseconds,
        },
      );
      return (html: current.normalizedHtmlBody, settled: true, timedOut: false);
    }
    if (current.rfc822BodyContentUnavailable) {
      _traceEmailOperation(
        'email.rfc822BodyHydration',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'result': 'alreadyUnavailable',
          'accountId': accountId,
          'elapsedMs': watch.elapsedMilliseconds,
        },
      );
      return (html: null, settled: true, timedOut: false);
    }
    final prepared = await _messageWithRfc822BodyContent(
      message: current,
      rfc822Body: resolvedRfc822Body,
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
    );
    if (prepared.timedOut) {
      _traceEmailOperation(
        'email.rfc822BodyHydration',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'result': 'timeoutBeforeDerivation',
          'accountId': accountId,
          'elapsedMs': watch.elapsedMilliseconds,
        },
      );
      return (html: null, settled: false, timedOut: true);
    }
    if (!_pendingEmailBodyHydrationCanContinue(
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    )) {
      _traceEmailOperation(
        'email.rfc822BodyHydration',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'result': 'timeoutBeforeWrite',
          'accountId': accountId,
          'elapsedMs': watch.elapsedMilliseconds,
        },
      );
      return (html: null, settled: false, timedOut: true);
    }
    final writeResult = await _withPendingEmailBodyDownloadBudgetResult(
      () => _trackAppDatabaseOperation(() async {
        final db = await _databaseBuilder();
        if (!_pendingEmailBodyHydrationCanContinue(
          deadline: deadline,
          pendingHydrationGeneration: pendingHydrationGeneration,
          isCanceled: isCanceled,
        )) {
          return false;
        }
        final updated = prepared.message;
        await db.updateMessage(updated);
        if (!_pendingEmailBodyHydrationCanContinue(
          deadline: deadline,
          pendingHydrationGeneration: pendingHydrationGeneration,
          isCanceled: isCanceled,
        )) {
          return false;
        }
        await db.repairChatSummaryFromMessages(updated.chatJid);
        settled =
            updated.hasRfc822BodyContent ||
            updated.rfc822BodyContentUnavailable;
        hydratedHtml = updated.hasRfc822BodyContent
            ? updated.normalizedHtmlBody
            : null;
        result = updated.hasRfc822BodyContent
            ? 'stored'
            : updated.rfc822BodyContentUnavailable
            ? 'unavailable'
            : 'missingBody';
        return true;
      }),
      deadline: deadline,
      pendingHydrationGeneration: pendingHydrationGeneration,
      isCanceled: isCanceled,
    );
    if (!writeResult.completed || writeResult.value != true) {
      _traceEmailOperation(
        'email.rfc822BodyHydration',
        'end',
        id: traceId,
        fields: <String, Object?>{
          'result': 'timeoutDuringWrite',
          'accountId': accountId,
          'elapsedMs': watch.elapsedMilliseconds,
        },
      );
      return (html: null, settled: false, timedOut: true);
    }
    _traceEmailOperation(
      'email.rfc822BodyHydration',
      'end',
      id: traceId,
      fields: <String, Object?>{
        'result': result,
        'accountId': accountId,
        'hasPlainText':
            resolvedRfc822Body?.plainText?.trim().isNotEmpty == true,
        'hasHtml': resolvedRfc822Body?.htmlBody?.trim().isNotEmpty == true,
        'elapsedMs': watch.elapsedMilliseconds,
      },
    );
    return (html: hydratedHtml, settled: settled, timedOut: false);
  }

  Future<({Message message, bool timedOut})> _messageWithRfc822BodyContent({
    required Message message,
    required DeltaMessageRfc822Body? rfc822Body,
    DateTime? deadline,
    int? pendingHydrationGeneration,
  }) async {
    if (rfc822Body == null || !rfc822Body.hasBody) {
      return (
        message: message.copyWith(
          body: null,
          htmlBody: null,
          rfc822BodyStatus: EmailRfc822BodyStatus.unavailable,
          pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
        ),
        timedOut: false,
      );
    }
    final normalizedHtml = HtmlContentCodec.normalizeHtml(rfc822Body.htmlBody);
    final plainBody = clampMessageText(rfc822Body.plainText)?.trim();
    final safePlainBody =
        plainBody?.isNotEmpty == true &&
            !HtmlContentCodec.looksLikeCssBodyText(plainBody!)
        ? plainBody
        : null;
    final cachedDerivation = normalizedHtml == null
        ? null
        : HtmlContentCodec.cachedEmailDerivations(normalizedHtml);
    if (safePlainBody != null) {
      final hasRenderableHtml =
          cachedDerivation != null &&
          _emailHtmlDerivationHasRenderableContent(cachedDerivation);
      return (
        message: message.copyWith(
          body: safePlainBody,
          htmlBody: hasRenderableHtml || cachedDerivation == null
              ? normalizedHtml
              : null,
          rfc822BodyStatus: EmailRfc822BodyStatus.hydrated,
          pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
        ),
        timedOut: false,
      );
    }
    if (normalizedHtml == null &&
        HtmlContentCodec.normalizeHtml(message.htmlBody) != null) {
      return (
        message: message.copyWith(
          body: null,
          htmlBody: null,
          rfc822BodyStatus: EmailRfc822BodyStatus.unavailable,
          pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
        ),
        timedOut: false,
      );
    }
    if (normalizedHtml == null) {
      return (
        message: message.copyWith(
          body: null,
          htmlBody: null,
          rfc822BodyStatus: EmailRfc822BodyStatus.unavailable,
          pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
        ),
        timedOut: false,
      );
    }
    if (cachedDerivation == null) {
      return (
        message: message.copyWith(
          htmlBody: normalizedHtml,
          rfc822BodyStatus: EmailRfc822BodyStatus.hydrated,
          pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
        ),
        timedOut: false,
      );
    }
    final visibleHtmlText = cachedDerivation.visibleBodyText.trim();
    final resolvedBody = visibleHtmlText;
    final hasRenderableHtml = _emailHtmlDerivationHasRenderableContent(
      cachedDerivation,
    );
    if (resolvedBody.isEmpty && !hasRenderableHtml) {
      return (
        message: message.copyWith(
          body: null,
          htmlBody: null,
          rfc822BodyStatus: EmailRfc822BodyStatus.unavailable,
          pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
        ),
        timedOut: false,
      );
    }
    return (
      message: message.copyWith(
        body: resolvedBody.isEmpty ? null : resolvedBody,
        htmlBody: hasRenderableHtml ? normalizedHtml : null,
        rfc822BodyStatus: EmailRfc822BodyStatus.hydrated,
        pseudoMessageData: message.pseudoMessageDataWithoutRfc822BodyStatus,
      ),
      timedOut: false,
    );
  }

  bool _emailHtmlDerivationHasRenderableContent(
    EmailHtmlDerivation derivation,
  ) {
    return derivation.visibleBodyText.trim().isNotEmpty ||
        derivation.containsRemoteImages;
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

  bool get hasRuntimeCredentials =>
      databasePrefix != null && databasePassphrase != null;

  bool get hasActiveSession =>
      hasRuntimeCredentials &&
      activeCredentialScope != null &&
      activeAccount != null;

  bool get hasInMemoryReconnectContext => hasActiveSession;

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
