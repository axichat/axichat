import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:axichat/src/common/anti_abuse_sync.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/jid_transport.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/settings/message_storage_mode.dart';
import 'package:logging/logging.dart';
import 'package:delta_ffi/delta_safe.dart';

import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/email/service/email_blocking_service.dart';
import 'package:axichat/src/email/service/email_spam_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/email/transport/email_delta_transport.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:axichat/src/email/util/share_token_html.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';

const _defaultPageSize = 50;
const _maxFanOutRecipients = 20;
const _attachmentFanOutWarningBytes = 8 * 1024 * 1024;
const _foregroundKeepaliveInterval = Duration(seconds: 45);
const _foregroundFetchTimeout = Duration(seconds: 8);
const _notificationFlushDelay = Duration(milliseconds: 500);
const _connectivityConnectedMin = 4000;
const _connectivityWorkingMin = 3000;
const _connectivityConnectingMin = 2000;
const _coreDraftMessageId = 0;
const _defaultImapPort = '993';
const _defaultSecurityMode = 'ssl';
const _emailDownloadLimitKey = 'download_limit';
const _emailDownloadLimitDisabledValue = '0';
const _unknownEmailPassword = '';
const _emailBootstrapKeyPrefix = 'email_bootstrap_v1';
const _notificationAttachmentLabel = 'Attachment';
const _notificationAttachmentPrefix = 'Attachment: ';
const List<EmailAttachment> _emptyEmailAttachments = <EmailAttachment>[];
const _deltaContactIdPrefix = 'delta_contact_';
const _deltaContactListFlags =
    DeltaContactListFlags.addSelf | DeltaContactListFlags.addRecent;
const _imapIdleConfigKey = 'imap_idle';
const _imapIdleTimeoutConfigKey = 'imap_idle_timeout';
const _imapMaxConnectionsConfigKey = 'imap_max_connections';
const _imapIdleKeepaliveInterval = Duration(minutes: 25);
const _imapSentPollIntervalSingleConnection = Duration(seconds: 60);
const _imapPollIntervalNoIdle = Duration(seconds: 30);
const _imapSyncFetchTimeout = Duration(seconds: 25);
const _imapCapabilityRefreshInterval = Duration(minutes: 10);
const _imapConnectionLimitSingle = 1;
const _imapConnectionLimitMulti = 2;
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

typedef EmailConnectionConfigBuilder = Map<String, String> Function(
  String address,
  EndpointConfig config,
);

class EmailAccount {
  const EmailAccount({
    required this.address,
    required this.password,
  });

  final String address;
  final String password;
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

class EmailService {
  EmailService({
    required CredentialStore credentialStore,
    required Future<XmppDatabase> Function() databaseBuilder,
    EmailDeltaTransport? transport,
    EmailConnectionConfigBuilder? connectionConfigBuilder,
    NotificationService? notificationService,
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
  final ForegroundTaskBridge? _foregroundBridge;
  late final EmailBlockingService blocking;
  late final EmailSpamService spam;
  final Map<String, RegisteredCredentialKey> _provisionedKeys = {};
  late final void Function(DeltaCoreEvent) _eventListener;
  var _listenerAttached = false;

  String? _databasePrefix;
  String? _databasePassphrase;
  EmailAccount? _activeAccount;
  String? _activeCredentialScope;
  bool _running = false;
  final Map<String, RegisteredCredentialKey> _addressKeys = {};
  final Map<String, RegisteredCredentialKey> _passwordKeys = {};
  final Set<String> _ephemeralProvisionedScopes = {};
  final _authFailureController =
      StreamController<DeltaChatException>.broadcast(sync: true);
  bool _foregroundKeepaliveEnabled = false;
  bool _foregroundKeepaliveListenerAttached = false;
  bool _foregroundKeepaliveServiceAcquired = false;
  bool _foregroundKeepaliveTickScheduled = false;
  int _foregroundKeepaliveOperationId = 0;
  final List<_PendingNotification> _pendingNotifications = [];
  Timer? _notificationFlushTimer;
  String? _pendingPushToken;
  final _syncStateController =
      StreamController<EmailSyncState>.broadcast(sync: true);
  EmailSyncState _syncState = const EmailSyncState.ready();
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
  var _chatlistSyncInFlight = false;

  void updateEndpointConfig(EndpointConfig config) {
    _endpointConfig = config;
  }

  void updateMessageStorageMode(MessageStorageMode mode) {
    _transport.updateMessageStorageMode(mode);
  }

  Map<String, String> _buildConnectionConfig(String address) =>
      _connectionConfigBuilder(address, _endpointConfig);

  EmailAccount? get activeAccount => _activeAccount;

  bool get isSmtpOnly =>
      _endpointConfig.enableSmtp && !_endpointConfig.enableXmpp;

  bool get isRunning => _running;

  Stream<DeltaCoreEvent> get events => _transport.events;

  EmailSyncState get syncState => _syncState;

  Stream<EmailSyncState> get syncStateStream => _syncStateController.stream;

  Stream<DeltaChatException> get authFailureStream =>
      _authFailureController.stream;

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

    var alreadyProvisioned =
        (await _credentialStore.read(key: provisionedKey)) == 'true';
    if (!shouldPersistCredentials &&
        _ephemeralProvisionedScopes.contains(scope)) {
      alreadyProvisioned = true;
    }
    final shouldForceProvisioning =
        shouldPersistCredentials && credentialsMutated;
    if (shouldForceProvisioning) {
      alreadyProvisioned = false;
      _ephemeralProvisionedScopes.remove(scope);
      if (shouldPersistCredentials) {
        await _credentialStore.write(key: provisionedKey, value: 'false');
      }
    }
    // Always verify with transport - credential store may be stale after cold start
    if (!shouldForceProvisioning) {
      try {
        alreadyProvisioned = await _transport.isConfigured();
      } on Exception {
        alreadyProvisioned = false;
      }
    }

    final needsProvisioning = !alreadyProvisioned;
    final pausedForProvisioning = needsProvisioning && _running;
    if (pausedForProvisioning) {
      await stop();
    }

    final normalizedAddress = address;
    if (needsProvisioning && (password == null || password.isEmpty)) {
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
          additional: _buildConnectionConfig(normalizedAddress),
        );
        _resetImapCapabilities();
        await _transport.purgeStockMessages();
        if (shouldPersistCredentials) {
          await _credentialStore.write(key: provisionedKey, value: 'true');
        } else {
          _ephemeralProvisionedScopes.add(scope);
        }
      } on DeltaSafeException catch (error, stackTrace) {
        if (shouldPersistCredentials) {
          await _credentialStore.write(key: provisionedKey, value: 'false');
        } else {
          _ephemeralProvisionedScopes.remove(scope);
        }
        final isTimeout = error.message.toLowerCase().contains('timed out');
        final mapped = DeltaChatExceptionMapper.fromDeltaSafe(
          error,
          operation: 'configure email account',
        );
        _log.warning(
          'Failed to configure email account',
          error,
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

    _transport.hydrateAccountAddress(normalizedAddress);
    await start();
    unawaited(_refreshImapCapabilities(force: true));
    await _applyPendingPushToken();

    final account = EmailAccount(
      address: normalizedAddress,
      password: normalizedPassword ?? _unknownEmailPassword,
    );
    _activeAccount = account;
    _ephemeralProvisionedScopes.add(scope);
    unawaited(
      _bootstrapFromCoreIfNeeded(scope: scope, databasePrefix: databasePrefix),
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
    await _credentialStore.write(
      key: _passwordKeyForScope(scope),
      value: password,
    );
    await _transport.configureAccount(
      address: address,
      password: password,
      displayName: displayName,
      additional: _buildConnectionConfig(address),
    );
    _resetImapCapabilities();
    unawaited(_refreshImapCapabilities(force: true));
    _activeCredentialScope = scope;
    _activeAccount = EmailAccount(address: address, password: password);
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
  }) async {
    await _ensureReady();
    final chatId = await _guardDeltaOperation(
      operation: 'ensure email chat',
      body: () => _transport.ensureChatForAddress(
        address: address,
        displayName: displayName,
      ),
    );
    return _waitForChat(chatId);
  }

  Future<Chat> ensureChatForEmailChat(Chat chat) async {
    await _ensureReady();
    if (chat.deltaChatId != null) {
      return chat;
    }
    final address = chat.emailAddress;
    if (address == null) {
      throw StateError('Email chat ${chat.jid} missing emailAddress metadata.');
    }
    return ensureChatForAddress(
      address: address,
      displayName: chat.contactDisplayName ?? chat.title,
    );
  }

  Future<int> sendMessage({
    required Chat chat,
    required String body,
    String? subject,
    String? htmlBody,
  }) async {
    final deltaChat = await ensureChatForEmailChat(chat);
    final chatId = deltaChat.deltaChatId!;
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
      final participants = await _shareParticipants(
        shareId: shareId,
        chats: [deltaChat],
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
    final deltaChat = await ensureChatForEmailChat(chat);
    final chatId = deltaChat.deltaChatId!;
    await _ensureReady();
    final normalizedSubject = _normalizeSubject(subject);
    final normalizedHtml = HtmlContentCodec.normalizeHtml(htmlCaption);
    String? shareId;
    if (normalizedSubject != null) {
      shareId = ShareTokenCodec.generateShareId();
      final db = await _databaseBuilder();
      final participants = await _shareParticipants(
        shareId: shareId,
        chats: [deltaChat],
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
        final normalizedChat = entry.deltaChatId == null
            ? await ensureChatForEmailChat(entry)
            : entry;
        final chatId = normalizedChat.deltaChatId!;
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
            chat: normalizedChat,
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
    final trimmed = subject?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
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
    final shareId = await db.getShareIdForDeltaMessage(deltaMsgId);
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
    await _transport.notifyNetworkAvailable();
    unawaited(_bootstrapActiveAccountIfNeeded());
    unawaited(_runReconnectCatchUp());
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
    if (_contactsSyncInFlight) return;
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
    final chatId = chat.deltaChatId;
    if (chatId == null) {
      return;
    }
    if (beforeMessageId == null && beforeTimestamp == null) {
      return;
    }
    await _ensureReady();
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
        _queueNotification(chatId: event.data1, msgId: event.data2);
        break;
      case DeltaEventType.incomingMsgBunch:
        await _flushQueuedNotifications();
        break;
      case DeltaEventType.msgsChanged:
      case DeltaEventType.chatModified:
        break;
      case DeltaEventType.msgDelivered:
      case DeltaEventType.msgFailed:
      case DeltaEventType.msgRead:
        break;
      case DeltaEventType.accountsBackgroundFetchDone:
        _handleBackgroundFetchDone();
        unawaited(_bootstrapActiveAccountIfNeeded());
        unawaited(refreshChatlistFromCore());
        break;
      case DeltaEventType.connectivityChanged:
        unawaited(_refreshConnectivityState());
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

  void _queueNotification({required int chatId, required int msgId}) {
    _pendingNotifications
        .add(_PendingNotification(chatId: chatId, msgId: msgId));
    _notificationFlushTimer ??= Timer(_notificationFlushDelay, () {
      _notificationFlushTimer = null;
      unawaited(_flushQueuedNotifications());
    });
  }

  Future<void> _flushQueuedNotifications() async {
    _notificationFlushTimer?.cancel();
    _notificationFlushTimer = null;
    if (_pendingNotifications.isEmpty) return;
    final pending = List<_PendingNotification>.from(_pendingNotifications);
    _pendingNotifications.clear();
    for (final entry in pending) {
      await _notifyIncoming(chatId: entry.chatId, msgId: entry.msgId);
    }
  }

  Future<void> _notifyIncoming({
    required int chatId,
    required int msgId,
  }) async {
    final notificationService = _notificationService;
    if (notificationService == null) return;
    try {
      final db = await _databaseBuilder();
      final message = await db.getMessageByStanzaID(_stanzaId(msgId));
      if (message == null) {
        return;
      }
      if (message.warning == MessageWarning.emailSpamQuarantined) {
        return;
      }
      String bare(String value) => value.split('/').first;
      final selfJid = selfSenderJid;
      if (selfJid != null && bare(message.senderJid) == bare(selfJid)) {
        return;
      }
      final notificationBody =
          await _notificationBody(db: db, message: message);
      if (notificationBody == null) {
        return;
      }
      final chat = await db.getChat(message.chatJid);
      if (chat?.muted ?? false) {
        return;
      }
      await notificationService.sendMessageNotification(
        title: chat?.title ?? message.senderJid,
        body: notificationBody,
        payload: chat?.jid,
        threadKey: message.chatJid,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to raise notification for email message ${_stanzaId(msgId)}',
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
      );
      return;
    }
    _updateSyncState(
      EmailSyncState.error(
        exception.message,
        exception: exception,
      ),
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
    );
  }

  Future<void> _refreshConnectivityState() async {
    try {
      final connectivity = await _transport.connectivity();
      if (connectivity == null) return;
      if (connectivity >= _connectivityConnectedMin) {
        _updateSyncState(const EmailSyncState.ready());
      } else if (connectivity >= _connectivityWorkingMin) {
        _updateSyncState(
          const EmailSyncState.recovering('Syncing email…'),
        );
      } else if (connectivity >= _connectivityConnectingMin) {
        _updateSyncState(
          const EmailSyncState.recovering('Connecting to email servers…'),
        );
      } else {
        _updateSyncState(
          const EmailSyncState.offline(
            'Disconnected from email servers.',
          ),
        );
      }
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to refresh email connectivity', error, stackTrace);
    }
  }

  void _handleBackgroundFetchDone() {
    if (_syncState.status == EmailSyncStatus.ready) {
      return;
    }
    _updateSyncState(const EmailSyncState.ready());
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
      );
    } finally {
      _channelOverflowRecoveryInProgress = false;
    }
    await _refreshConnectivityState();
  }

  void _updateSyncState(EmailSyncState next) {
    if (_syncState == next) return;
    _syncState = next;
    _syncStateController.add(next);
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
      );
    }
    try {
      final didBootstrap = await _transport.bootstrapFromCore();
      if (operationId != _bootstrapOperationId) {
        return;
      }
      if (didBootstrap) {
        await _credentialStore.write(
          key: bootstrapKey,
          value: true.toString(),
        );
      }
      if (operationId != _bootstrapOperationId) {
        return;
      }
      await _refreshConnectivityState();
    } on Exception catch (error, stackTrace) {
      if (operationId != _bootstrapOperationId) {
        return;
      }
      _log.warning('Email history bootstrap failed', error, stackTrace);
      if (_syncState.status == EmailSyncStatus.ready ||
          _syncState.status == EmailSyncStatus.recovering) {
        _updateSyncState(
          const EmailSyncState.recovering('Email sync will retry shortly…'),
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
  }) async {
    final participants = <String, MessageParticipantData>{};
    for (final participant in existingParticipants) {
      participants[participant.contactJid] = participant;
    }
    final senderJid = _senderParticipantJid();
    if (senderJid != null && senderJid.isNotEmpty) {
      participants[senderJid] = MessageParticipantData(
        shareId: shareId,
        contactJid: senderJid,
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

  String? _senderParticipantJid() => selfSenderJid ?? _defaultDeltaSelfJid;

  Future<Chat> _waitForChat(int chatId) async {
    final db = await _databaseBuilder();

    final existing = await db.getChatByDeltaChatId(chatId);
    if (existing != null) {
      return existing;
    }

    try {
      final chat = await db
          .watchChatByDeltaChatId(chatId)
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
    final host = _connectionHostFor(address, config);
    final localPart = _localPartFromAddress(address) ?? address;
    return {
      'mail_server': host,
      'mail_port': _defaultImapPort,
      'mail_security': _defaultSecurityMode,
      'mail_user': localPart,
      'send_server': host,
      'send_port': (config.smtpPort > 0
              ? config.smtpPort
              : EndpointConfig.defaultSmtpPort)
          .toString(),
      'send_security': _defaultSecurityMode,
      'send_user': localPart,
      'show_emails': '2',
      _emailDownloadLimitKey: _emailDownloadLimitDisabledValue,
      'mdns_enabled': '1',
    };
  }

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
    if (localPart.isEmpty) {
      return null;
    }
    return localPart;
  }

  List<Chat> _sortChats(List<Chat> chats) => List<Chat>.of(chats)
    ..sort((a, b) {
      if (a.favorited == b.favorited) {
        return b.lastChangeTimestamp.compareTo(a.lastChangeTimestamp);
      }
      return (a.favorited ? 0 : 1) - (b.favorited ? 0 : 1);
    });

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

  Future<void> _clearCredentials(String scope) async {
    await _credentialStore.delete(key: _addressKeyForScope(scope));
    await _credentialStore.delete(key: _passwordKeyForScope(scope));
    await _credentialStore.delete(key: _provisionedKeyForScope(scope));
    if (_activeCredentialScope == scope) {
      _activeCredentialScope = null;
      _activeAccount = null;
    }
    _ephemeralProvisionedScopes.remove(scope);
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
    final scope = _scopeForJid(jid);
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
    await _credentialStore.write(key: provisionedKey, value: 'true');
    _ephemeralProvisionedScopes.add(scope);
  }

  Future<void> clearStoredCredentials({
    required String jid,
    bool preserveActiveSession = false,
  }) async {
    final scope = _scopeForJid(jid);
    await _credentialStore.delete(key: _addressKeyForScope(scope));
    await _credentialStore.delete(key: _passwordKeyForScope(scope));
    await _credentialStore.delete(key: _provisionedKeyForScope(scope));
    if (!preserveActiveSession && _activeCredentialScope == scope) {
      _activeCredentialScope = null;
      _activeAccount = null;
    }
    if (!preserveActiveSession) {
      _ephemeralProvisionedScopes.remove(scope);
    }
  }

  /// Marks a chat as noticed, clearing unread badges in core.
  ///
  /// Call this when the user opens a chat.
  Future<bool> markNoticedChat(Chat chat) async {
    final chatId = chat.deltaChatId;
    if (chatId == null) return false;
    await _ensureReady();
    return _transport.markNoticedChat(chatId);
  }

  /// Marks messages as seen, triggering MDN if enabled.
  ///
  /// Call this when messages are displayed to the user.
  Future<bool> markSeenMessages(List<Message> messages) async {
    final deltaIds = messages
        .map((m) => m.deltaMsgId)
        .whereType<int>()
        .toList(growable: false);
    if (deltaIds.isEmpty) return true;
    await _ensureReady();
    return _transport.markSeenMessages(deltaIds);
  }

  /// Returns the count of fresh (unread) messages in a chat.
  Future<int> getFreshMessageCount(Chat chat) async {
    final chatId = chat.deltaChatId;
    if (chatId == null) return 0;
    await _ensureReady();
    return _transport.getFreshMessageCount(chatId);
  }

  /// Deletes messages from core and server.
  Future<bool> deleteMessages(List<Message> messages) async {
    final deltaMessages = messages
        .where((message) => message.deltaMsgId != null)
        .toList(growable: false);
    final deltaIds = deltaMessages
        .map((message) => message.deltaMsgId!)
        .toList(growable: false);
    if (deltaIds.isEmpty) return false;
    await _ensureReady();
    final success = await _transport.deleteMessages(deltaIds);
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
    final toChatId = toChat.deltaChatId;
    if (toChatId == null) return false;
    final deltaIds = messages
        .map((m) => m.deltaMsgId)
        .whereType<int>()
        .toList(growable: false);
    if (deltaIds.isEmpty) return false;
    await _ensureReady();
    return _transport.forwardMessages(messageIds: deltaIds, toChatId: toChatId);
  }

  /// Searches messages using core search.
  ///
  /// Pass null for chat to search all chats.
  Future<List<Message>> searchMessages({
    Chat? chat,
    required String query,
  }) async {
    await _ensureReady();
    final chatId = chat?.deltaChatId ?? 0;
    final deltaIds = await _transport.searchMessages(
      chatId: chatId,
      query: query,
    );
    if (deltaIds.isEmpty) return const [];

    final db = await _databaseBuilder();
    final messagesByDeltaId = <int, Message>{};
    final missingIds = <int>[];
    for (final deltaId in deltaIds) {
      final stanzaId = _stanzaId(deltaId);
      final message = await db.getMessageByStanzaID(stanzaId);
      if (message != null) {
        messagesByDeltaId[deltaId] = message;
      } else {
        missingIds.add(deltaId);
      }
    }
    if (missingIds.isNotEmpty) {
      await _transport.hydrateMessages(missingIds);
      for (final deltaId in missingIds) {
        final stanzaId = _stanzaId(deltaId);
        final message = await db.getMessageByStanzaID(stanzaId);
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
    final chatId = chat.deltaChatId;
    if (chatId == null) return false;
    await _ensureReady();
    return _transport.setChatVisibility(
      chatId: chatId,
      visibility: visibility,
    );
  }

  /// Triggers download of full message content for partial messages.
  Future<bool> downloadFullMessage(Message message) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null) return false;
    await _ensureReady();
    return _transport.downloadFullMessage(deltaId);
  }

  /// Resends failed messages using core retry.
  Future<bool> resendMessages(List<Message> messages) async {
    final deltaIds = messages
        .map((m) => m.deltaMsgId)
        .whereType<int>()
        .toList(growable: false);
    if (deltaIds.isEmpty) return false;
    await _ensureReady();
    return _transport.resendMessages(deltaIds);
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
    final deltaChat = await ensureChatForEmailChat(chat);
    final chatId = deltaChat.deltaChatId!;
    final quotedMsgId = quotedMessage.deltaMsgId;
    if (quotedMsgId == null) {
      return sendMessage(
        chat: chat,
        body: body,
        subject: subject,
        htmlBody: htmlBody,
      );
    }
    await _ensureReady();
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
        subject: subject,
        htmlBody: normalizedHtml,
      ),
    );
    final deltaMessage = await _transport.getMessage(msgId);
    await _recordOutgoing(
      chatId: chatId,
      msgId: msgId,
      body: resolvedBody,
      htmlBody: normalizedHtml,
      timestamp: deltaMessage?.timestamp,
    );
    return msgId;
  }

  /// Gets the quoted message info for a message.
  Future<DeltaQuotedMessage?> getQuotedMessage(Message message) async {
    final deltaId = message.deltaMsgId;
    if (deltaId == null) return null;
    await _ensureReady();
    return _transport.getQuotedMessage(deltaId);
  }

  /// Saves a draft to core.
  Future<bool> saveDraftToCore({
    required Chat chat,
    required String text,
    String? subject,
    String? htmlBody,
    List<EmailAttachment> attachments = _emptyEmailAttachments,
  }) async {
    final deltaChat = await ensureChatForEmailChat(chat);
    final chatId = deltaChat.deltaChatId;
    if (chatId == null) return false;
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
    return _transport.setDraft(chatId: chatId, message: message);
  }

  /// Clears a draft from core.
  Future<bool> clearDraftFromCore(Chat chat) async {
    final chatId = chat.deltaChatId;
    if (chatId == null) return false;
    await _ensureReady();
    return _transport.setDraft(chatId: chatId, message: null);
  }

  /// Gets a draft from core.
  Future<DeltaMessage?> getDraftFromCore(Chat chat) async {
    final chatId = chat.deltaChatId;
    if (chatId == null) return null;
    await _ensureReady();
    return _transport.getDraft(chatId);
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

  Future<void> _recordOutgoing({
    required int chatId,
    required int msgId,
    String? body,
    String? htmlBody,
    DateTime? timestamp,
  }) async {
    final db = await _databaseBuilder();
    final chat = await db.getChatByDeltaChatId(chatId);
    if (chat == null) return;

    final resolvedTimestamp = timestamp ?? DateTime.timestamp();
    final message = Message(
      stanzaID: _stanzaId(msgId),
      senderJid: selfSenderJid ?? _defaultDeltaSelfJid,
      chatJid: chat.jid,
      timestamp: resolvedTimestamp,
      body: body?.trim(),
      htmlBody: HtmlContentCodec.normalizeHtml(htmlBody),
      encryptionProtocol: EncryptionProtocol.none,
      acked: false,
      received: false,
      deltaChatId: chatId,
      deltaMsgId: msgId,
    );
    await db.saveMessage(message);
    await db.updateChat(
      chat.copyWith(lastChangeTimestamp: resolvedTimestamp),
    );
  }
}

const _deltaDomain = 'delta.chat';
const _defaultDeltaSelfJid = 'dc-self@$_deltaDomain';

String _stanzaId(int msgId) => 'dc-msg-$msgId';

class _PendingNotification {
  const _PendingNotification({required this.chatId, required this.msgId});

  final int chatId;
  final int msgId;
}
