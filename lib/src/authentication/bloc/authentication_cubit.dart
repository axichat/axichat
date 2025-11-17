import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:axichat/main.dart';
import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/email/service/chatmail_provisioning_client.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

part 'authentication_state.dart';

enum LogoutSeverity {
  auto,
  normal,
  burn;

  bool get isAuto => this == auto;

  bool get isNormal => this == normal;

  bool get isBurn => this == burn;

  String get displayText => switch (this) {
        auto => 'Auto',
        normal => 'Normal',
        burn => 'Burn',
      };
}

class AuthenticationCubit extends Cubit<AuthenticationState> {
  AuthenticationCubit({
    required CredentialStore credentialStore,
    required XmppService xmppService,
    EmailService? emailService,
    NotificationService? notificationService,
    http.Client? httpClient,
    ChatmailProvisioningClient? chatmailProvisioningClient,
    AuthenticationState? initialState,
  })  : _credentialStore = credentialStore,
        _xmppService = xmppService,
        _emailService = emailService,
        super(initialState ?? const AuthenticationNone()) {
    _httpClient = httpClient ?? http.Client();
    _chatmailProvisioningClient = chatmailProvisioningClient ??
        ChatmailProvisioningClient.fromEnvironment(
          httpClient: _httpClient,
        );
    _lifecycleListener = AppLifecycleListener(
      onResume: login,
      onShow: login,
      onRestart: login,
      onDetach: logout,
      onExitRequested: () async {
        await logout();
        return AppExitResponse.exit;
      },
      onStateChange: (lifeCycleState) async {
        if (!withForeground) return;

        if (launchedFromNotification) {
          launchedFromNotification = false;
          final payload = takeLaunchedNotificationChatJid();
          if (payload != null) {
            xmppService.openChat(payload);
          } else {
            final appLaunchDetails =
                await notificationService?.getAppNotificationAppLaunchDetails();
            if (appLaunchDetails?.notificationResponse?.payload
                case final chatJid?) {
              xmppService.openChat(chatJid);
            }
          }
        }

        await _xmppService.setClientState(
            lifeCycleState == AppLifecycleState.resumed ||
                lifeCycleState == AppLifecycleState.inactive);
        await _emailService?.setClientState(
          lifeCycleState != AppLifecycleState.detached,
        );
      },
    );
    _connectivitySubscription =
        xmppService.connectivityStream.listen((connectionState) {
      if (connectionState == ConnectionState.connected) {
        unawaited(_emailService?.handleNetworkAvailable());
      } else if (connectionState == ConnectionState.notConnected ||
          connectionState == ConnectionState.error) {
        unawaited(_emailService?.handleNetworkLost());
      }
    });
    if (_emailService != null) {
      _foregroundListener = _updateEmailForegroundKeepalive;
      foregroundServiceActive.addListener(_foregroundListener!);
    }
    unawaited(_flushPendingAccountDeletions());
    unawaited(_purgeLegacySignupDraft());
  }

  final _log = Logger('AuthenticationCubit');

  static const String domain = 'axi.im';
  static Uri baseUrl = Uri.parse('https://$domain:5443');
  static Uri registrationUrl = Uri.parse('$baseUrl/register/new/');
  static Uri changePasswordUrl =
      Uri.parse('$baseUrl/register/change_password/');
  static Uri deleteAccountUrl = Uri.parse('$baseUrl/register/delete/');
  static const String signupCleanupInProgressMessage =
      'Cleaning up your previous signup attempt. We will retry the removal as soon as you are back online—try again once it finishes.';

  final jidStorageKey = CredentialStore.registerKey('jid');
  final passwordStorageKey = CredentialStore.registerKey('password');
  final pendingSignupRollbacksKey =
      CredentialStore.registerKey('pending_signup_rollbacks');
  final completedSignupAccountsKey =
      CredentialStore.registerKey('completed_signup_accounts_v1');
  final _legacySignupDraftStorageKey =
      CredentialStore.registerKey('signup_draft_v1');
  final _legacySignupDraftClosedAtStorageKey =
      CredentialStore.registerKey('signup_draft_last_closed_at');

  final CredentialStore _credentialStore;
  final XmppService _xmppService;
  final EmailService? _emailService;
  late final http.Client _httpClient;
  late final ChatmailProvisioningClient _chatmailProvisioningClient;
  String? _authenticatedJid;
  EmailProvisioningException? _lastEmailProvisioningError;
  StreamSubscription<ConnectionState>? _connectivitySubscription;
  VoidCallback? _foregroundListener;
  Future<void>? _pendingAccountDeletionFlush;
  String? _blockedSignupCredentialKey;
  String? _activeSignupCredentialKey;

  late final AppLifecycleListener _lifecycleListener;

  @override
  Future<void> close() async {
    _lifecycleListener.dispose();
    await _connectivitySubscription?.cancel();
    if (_foregroundListener != null) {
      foregroundServiceActive.removeListener(_foregroundListener!);
      _foregroundListener = null;
    }
    await _emailService?.setForegroundKeepalive(false);
    await _credentialStore.close();
    await _emailService?.shutdown(jid: _authenticatedJid);
    return super.close();
  }

  Future<void> login({
    String? username,
    String? password,
    bool rememberMe = false,
    bool requireEmailProvisioned = false,
    ChatmailCredentials? chatmailCredentials,
  }) async {
    _lastEmailProvisioningError = null;
    if (state is AuthenticationComplete) {
      return;
    }
    if (state is AuthenticationLogInInProgress) {
      _log.fine('Ignoring login request while another is in progress.');
      return;
    }
    emit(const AuthenticationLogInInProgress());

    if ((username == null) != (password == null)) {
      emit(const AuthenticationFailure(
          'Username and password have different nullness.'));
      return;
    }

    late final String? jid;
    var emailPassword = chatmailCredentials?.password ?? password;
    if (username == null || password == null) {
      jid = await _credentialStore.read(key: jidStorageKey);
      password = await _credentialStore.read(key: passwordStorageKey);
    } else {
      jid = '$username@${state.server}';
    }

    if (jid == null || password == null) {
      emit(const AuthenticationNone());
      return;
    }
    final String resolvedJid = jid;
    final String resolvedPassword = password;
    final String displayName = resolvedJid.split('@').first;

    final databasePrefixStorageKey =
        CredentialStore.registerKey('${jid}_database_prefix');

    String? databasePrefix =
        await _credentialStore.read(key: databasePrefixStorageKey);
    databasePrefix ??= generateRandomString(length: 8);

    final databasePassphraseStorageKey = CredentialStore.registerKey(
      '${databasePrefix}_database_passphrase',
    );

    String? databasePassphrase =
        await _credentialStore.read(key: databasePassphraseStorageKey);
    databasePassphrase ??= generateRandomString();
    final String ensuredDatabasePrefix = databasePrefix;
    final String ensuredDatabasePassphrase = databasePassphrase;

    final savedPassword = await _credentialStore.read(key: passwordStorageKey);
    final bool usingStoredCredentials = username == null;
    final bool shouldClearEmailCredentialsOnFailure = !usingStoredCredentials;
    final preHashed = usingStoredCredentials && savedPassword != null;
    final String xmppPassword = usingStoredCredentials
        ? (savedPassword ?? resolvedPassword)
        : resolvedPassword;

    final emailService = _emailService;
    if (emailPassword == null && emailService != null) {
      final existing = await emailService.currentAccount(resolvedJid);
      emailPassword = existing?.password;
    }

    if (emailService != null && emailPassword == null) {
      emit(const AuthenticationFailure(
          'Stored email password missing. Please log in manually.'));
      return;
    }

    final enforceEmailProvisioning = requireEmailProvisioned ||
        _activeSignupCredentialKey != null ||
        emailService != null;

    Future<void>? emailProvisioningFuture;
    if (emailService != null) {
      final resolvedEmailPassword = emailPassword!;
      emailProvisioningFuture = Future<EmailAccount>.sync(
        () => emailService.ensureProvisioned(
          displayName: displayName,
          databasePrefix: ensuredDatabasePrefix,
          databasePassphrase: ensuredDatabasePassphrase,
          jid: resolvedJid,
          passwordOverride: resolvedEmailPassword,
          addressOverride: chatmailCredentials?.email,
        ),
      ).then<void>((_) {});
    }

    try {
      password = await _xmppService.connect(
        jid: resolvedJid,
        password: xmppPassword,
        databasePrefix: databasePrefix,
        databasePassphrase: databasePassphrase,
        preHashed: preHashed,
      );
    } on XmppAuthenticationException catch (_) {
      await _cancelPendingEmailProvisioning(
        emailProvisioningFuture,
        resolvedJid,
        clearCredentials: shouldClearEmailCredentialsOnFailure,
      );
      emit(const AuthenticationFailure('Incorrect username or password'));
      await _xmppService.disconnect();
      return;
    } on XmppAlreadyConnectedException catch (_) {
      await _cancelPendingEmailProvisioning(
        emailProvisioningFuture,
        resolvedJid,
        clearCredentials: shouldClearEmailCredentialsOnFailure,
      );
      await _xmppService.disconnect();
      emit(const AuthenticationNone());
      return;
    } on Exception catch (e) {
      await _cancelPendingEmailProvisioning(
        emailProvisioningFuture,
        resolvedJid,
        clearCredentials: shouldClearEmailCredentialsOnFailure,
      );
      _log.severe(e);
      emit(const AuthenticationFailure('Error. Please try again later.'));
      await _xmppService.disconnect();
      return;
    }

    await _credentialStore.write(
      key: databasePassphraseStorageKey,
      value: databasePassphrase,
    );

    await _credentialStore.write(
      key: databasePrefixStorageKey,
      value: databasePrefix,
    );

    if (rememberMe) {
      await _credentialStore.write(key: jidStorageKey, value: jid);
      if (password != null) {
        await _credentialStore.write(key: passwordStorageKey, value: password);
      }
    }

    _authenticatedJid = jid;

    if (emailProvisioningFuture != null) {
      try {
        await emailProvisioningFuture;
        _lastEmailProvisioningError = null;
      } on EmailProvisioningException catch (error) {
        final shouldAbort = enforceEmailProvisioning || !error.isRecoverable;
        if (shouldAbort) {
          _lastEmailProvisioningError = error;
          emit(AuthenticationFailure(error.message));
          await _cancelPendingEmailProvisioning(
            emailProvisioningFuture,
            resolvedJid,
            clearCredentials: shouldClearEmailCredentialsOnFailure,
          );
          await _xmppService.disconnect();
          return;
        }
        _log.warning('Chatmail provisioning pending: ${error.message}');
        _lastEmailProvisioningError = null;
      } on Exception catch (error, stackTrace) {
        _log.warning('Chatmail provisioning failed', error, stackTrace);
      }
    }

    emit(const AuthenticationComplete());
    await _recordAccountAuthenticated(resolvedJid);
    _updateEmailForegroundKeepalive();
  }

  Future<void> _cancelPendingEmailProvisioning(
    Future<void>? provisioningFuture,
    String jid, {
    required bool clearCredentials,
  }) async {
    if (provisioningFuture != null) {
      unawaited(
        provisioningFuture.catchError(
          (Object error, StackTrace stackTrace) {
            _log.fine(
              'Cancelled email provisioning after login failed',
              error,
              stackTrace,
            );
          },
        ),
      );
    }
    final emailService = _emailService;
    if (emailService == null) {
      return;
    }
    try {
      await emailService.shutdown(
        jid: jid,
        clearCredentials: clearCredentials,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to clean up Chatmail provisioning after aborted login',
        error,
        stackTrace,
      );
    }
  }

  Future<void> signup({
    required String username,
    required String password,
    required String confirmPassword,
    required String captchaID,
    required String captcha,
    required bool rememberMe,
  }) async {
    emit(const AuthenticationSignUpInProgress());
    final host = state.server;
    final cleanupComplete = await _ensureAccountDeletionCleanupComplete(
      username: username,
      host: host,
    );
    if (!cleanupComplete) {
      emit(const AuthenticationSignupFailure(
        signupCleanupInProgressMessage,
        isCleanupBlocked: true,
      ));
      return;
    }
    _activeSignupCredentialKey = _normalizeSignupKey(username, host);
    await _stageSignupRollback(
      username: username,
      host: host,
      password: password,
    );
    try {
      final response = await _httpClient.post(
        registrationUrl,
        body: {
          'username': username,
          'host': host,
          'password': password,
          'password2': confirmPassword,
          'id': captchaID,
          'key': captcha,
          'register': 'Register',
        },
      );
      if (!(response.statusCode == 200 || response.statusCode == 201)) {
        emit(AuthenticationSignupFailure(response.body));
        _activeSignupCredentialKey = null;
        await _removePendingAccountDeletion(
          username: username,
          host: host,
        );
        return;
      }
    } on Exception catch (_) {
      emit(const AuthenticationSignupFailure(
        'Failed to register, try again later.',
      ));
      _activeSignupCredentialKey = null;
      await _removePendingAccountDeletion(
        username: username,
        host: host,
      );
      return;
    }
    var signupComplete = false;
    try {
      ChatmailCredentials? chatmailCredentials;
      if (_emailService != null) {
        chatmailCredentials = await _chatmailProvisioningClient.createAccount(
          localpart: username,
          password: password,
        );
      }
      await login(
        username: username,
        password: password,
        rememberMe: rememberMe,
        requireEmailProvisioned: true,
        chatmailCredentials: chatmailCredentials,
      );
      signupComplete = state is AuthenticationComplete;
    } on ChatmailProvisioningException catch (error, stackTrace) {
      _log.warning(
        'Failed to auto-provision Chatmail account',
        error,
        stackTrace,
      );
      emit(AuthenticationSignupFailure(error.message));
    } finally {
      _activeSignupCredentialKey = null;
      if (signupComplete) {
        await _removePendingAccountDeletion(
          username: username,
          host: host,
        );
      }
      if (!signupComplete || _lastEmailProvisioningError != null) {
        await _rollbackSignup(
          username: username,
          host: host,
          password: password,
        );
      }
    }
  }

  Future<void> _stageSignupRollback({
    required String username,
    required String host,
    required String password,
  }) async {
    final normalizedKey = _normalizeSignupKey(username, host);
    if (await _hasCompletedAuthentication(normalizedKey)) {
      _log.info(
        'Skipping rollback staging for previously authenticated account '
        '$normalizedKey.',
      );
      return;
    }
    final entry = _PendingAccountDeletion(
      username: username,
      host: host,
      password: password,
    );
    await _upsertPendingAccountDeletion(entry);
  }

  Future<void> _rollbackSignup({
    required String username,
    required String host,
    required String password,
  }) async {
    final normalizedKey = _normalizeSignupKey(username, host);
    if (await _hasCompletedAuthentication(normalizedKey)) {
      _log.info(
        'Skipping rollback for previously authenticated account '
        '$normalizedKey.',
      );
      return;
    }
    final deletion = _PendingAccountDeletion(
      username: username,
      host: host,
      password: password,
    );
    final succeeded = await _performAccountDeletion(deletion);
    if (!succeeded) {
      await _enqueuePendingAccountDeletion(deletion);
    }
    _lastEmailProvisioningError = null;
  }

  Future<bool> checkNotPwned({required String password}) async {
    emit(const AuthenticationSignUpInProgress());
    final hash = sha1.convert(utf8.encode(password)).toString().toUpperCase();
    final subhash = hash.substring(0, 5);
    try {
      final response = await _httpClient
          .get(Uri.parse('https://api.pwnedpasswords.com/range/$subhash'));
      if (response.statusCode == 200) {
        if (response.body.split('\r\n').any((e) {
          final pwned = '$subhash${e.split(':')[0]}';
          return pwned == hash;
        })) {
          emit(const AuthenticationSignupFailure(
              'Hackers have already found this password so it is insecure. '
              'Use a different one or allow insecure passwords.'));
          return false;
        }
      }
    } on Exception catch (_) {
      emit(const AuthenticationNone());
      return true;
    }
    emit(const AuthenticationNone());
    return true;
  }

  Future<void> logout({LogoutSeverity severity = LogoutSeverity.auto}) async {
    if (state is! AuthenticationComplete) return;
    final currentJid = _authenticatedJid;

    switch (severity) {
      case LogoutSeverity.auto:
        break;
      case LogoutSeverity.normal:
        await _credentialStore.delete(key: jidStorageKey);
        await _credentialStore.delete(key: passwordStorageKey);
      case LogoutSeverity.burn:
        await _credentialStore.deleteAll(burn: true);
        await _xmppService.burn();
    }

    await _xmppService.disconnect();
    if (severity == LogoutSeverity.burn) {
      await _emailService?.burn(jid: currentJid);
    } else {
      await _emailService?.shutdown(
        jid: currentJid,
        clearCredentials: severity == LogoutSeverity.normal,
      );
    }

    _authenticatedJid = null;
    emit(const AuthenticationNone());
    _updateEmailForegroundKeepalive();
  }

  Future<void> changePassword({
    required String username,
    required String host,
    required String oldPassword,
    required String password,
    required String password2,
  }) async {
    emit(const AuthenticationPasswordChangeInProgress());
    final response = await http.post(
      AuthenticationCubit.changePasswordUrl,
      body: {
        'username': username,
        'host': host,
        'passwordold': oldPassword,
        'password': password,
        'password2': password2,
      },
    );
    if (response.statusCode == 200) {
      emit(AuthenticationPasswordChangeSuccess(response.body));
    } else {
      emit(AuthenticationPasswordChangeFailure(response.body));
    }
  }

  Future<void> unregister({
    required String username,
    required String host,
    required String password,
  }) async {
    emit(const AuthenticationUnregisterInProgress());
    final response = await http.post(
      AuthenticationCubit.deleteAccountUrl,
      body: {
        'username': username,
        'host': host,
        'password': password,
      },
    );
    if (response.statusCode == 200) {
      await logout(severity: LogoutSeverity.burn);
      await _removeCompletedAccountRecord(username, host);
    } else {
      emit(AuthenticationUnregisterFailure(response.body));
    }
  }

  void _updateEmailForegroundKeepalive() {
    final emailService = _emailService;
    if (emailService == null) return;
    final shouldRun = foregroundServiceActive.value &&
        _authenticatedJid != null &&
        state is AuthenticationComplete;
    unawaited(_setEmailForegroundKeepalive(emailService, shouldRun));
  }

  Future<void> _setEmailForegroundKeepalive(
    EmailService service,
    bool enabled,
  ) async {
    try {
      await service.setForegroundKeepalive(enabled);
    } catch (error, stackTrace) {
      _log.finer(
        'Failed to update email foreground keepalive',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _enqueuePendingAccountDeletion(
    _PendingAccountDeletion deletion,
  ) async {
    await _upsertPendingAccountDeletion(deletion);
  }

  Future<void> _flushPendingAccountDeletions() {
    final pendingFlush = _pendingAccountDeletionFlush;
    if (pendingFlush != null) {
      return pendingFlush;
    }
    final future = _processPendingAccountDeletions();
    _pendingAccountDeletionFlush = future;
    return future.whenComplete(() {
      if (identical(_pendingAccountDeletionFlush, future)) {
        _pendingAccountDeletionFlush = null;
      }
    });
  }

  Future<void> _processPendingAccountDeletions() async {
    try {
      final pending = await _readPendingAccountDeletions();
      if (pending.isEmpty) {
        return;
      }
      final completedAccounts = await _readCompletedSignupAccounts();
      final remaining = <_PendingAccountDeletion>[];
      for (final request in pending) {
        final activeKey = _activeSignupCredentialKey;
        if (activeKey != null && request.matchesKey(activeKey)) {
          remaining.add(request);
          continue;
        }
        final normalizedKey =
            _normalizeSignupKey(request.username, request.host);
        if (completedAccounts.contains(normalizedKey)) {
          _log.fine(
            'Skipping rollback for previously authenticated account '
            '$normalizedKey.',
          );
          continue;
        }
        final succeeded = await _performAccountDeletion(request);
        if (!succeeded) {
          remaining.add(request);
        }
      }
      await _writePendingAccountDeletions(remaining);
      _handleSignupCleanupResolution(remaining);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to flush pending signup rollbacks',
        error,
        stackTrace,
      );
    }
  }

  Future<bool> _ensureAccountDeletionCleanupComplete({
    required String username,
    required String host,
  }) async {
    await _flushPendingAccountDeletions();
    final pending = await _readPendingAccountDeletions();
    final completedAccounts = await _readCompletedSignupAccounts();
    final filtered = pending
        .where((entry) => !completedAccounts.contains(
              _normalizeSignupKey(entry.username, entry.host),
            ))
        .toList(growable: false);
    if (filtered.length != pending.length) {
      await _writePendingAccountDeletions(filtered);
    }
    final cleanupPending = filtered.any(
      (entry) => entry.matchesCredentials(username, host),
    );
    final normalizedKey = _normalizeSignupKey(username, host);
    if (cleanupPending) {
      _blockedSignupCredentialKey = normalizedKey;
      _log.warning(
        'Signup blocked for $username@$host because cleanup is still pending.',
      );
    } else if (_blockedSignupCredentialKey == normalizedKey) {
      _blockedSignupCredentialKey = null;
    }
    return !cleanupPending;
  }

  Future<bool> _performAccountDeletion(
    _PendingAccountDeletion deletion,
  ) async {
    final normalizedKey = _normalizeSignupKey(deletion.username, deletion.host);
    if (await _hasCompletedAuthentication(normalizedKey)) {
      _log.fine(
        'Skipping rollback request for previously authenticated account '
        '$normalizedKey.',
      );
      return true;
    }
    try {
      final response = await _httpClient.post(
        AuthenticationCubit.deleteAccountUrl,
        body: {
          'username': deletion.username,
          'host': deletion.host,
          'password': deletion.password,
        },
      );
      if (response.statusCode == 200) {
        return true;
      }
      if (_isAccountDeletionNoop(response.statusCode, response.body)) {
        _log.info(
          'Signup rollback treated as success because account is already gone '
          '(status ${response.statusCode}).',
        );
        return true;
      }
      _log.warning(
        'Signup rollback failed with status ${response.statusCode}',
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to send signup rollback request',
        error,
        stackTrace,
      );
    }
    return false;
  }

  bool _isAccountDeletionNoop(int statusCode, String? body) {
    if (statusCode == 404 || statusCode == 410) {
      return true;
    }
    final normalizedBody = body?.toLowerCase().trim();
    if (normalizedBody == null || normalizedBody.isEmpty) {
      return false;
    }
    return normalizedBody.contains('not found') ||
        normalizedBody.contains('does not exist');
  }

  Future<List<_PendingAccountDeletion>> _readPendingAccountDeletions() async {
    final serialized =
        await _credentialStore.read(key: pendingSignupRollbacksKey);
    if (serialized == null || serialized.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(serialized) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_PendingAccountDeletion.fromJson)
          .toList();
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to decode pending signup rollbacks',
        error,
        stackTrace,
      );
      await _credentialStore.delete(key: pendingSignupRollbacksKey);
      return [];
    }
  }

  Future<void> _writePendingAccountDeletions(
    List<_PendingAccountDeletion> entries,
  ) async {
    if (entries.isEmpty) {
      await _credentialStore.delete(key: pendingSignupRollbacksKey);
      return;
    }
    final serialized =
        jsonEncode(entries.map((entry) => entry.toJson()).toList());
    await _credentialStore.write(
      key: pendingSignupRollbacksKey,
      value: serialized,
    );
  }

  Future<void> _upsertPendingAccountDeletion(
    _PendingAccountDeletion deletion,
  ) async {
    final pending = await _readPendingAccountDeletions();
    final updated = pending
        .where((entry) => !entry.matches(deletion))
        .toList(growable: true)
      ..add(deletion);
    await _writePendingAccountDeletions(updated);
  }

  Future<void> _removePendingAccountDeletion({
    required String username,
    required String host,
  }) async {
    final pending = await _readPendingAccountDeletions();
    if (pending.isEmpty) {
      return;
    }
    final normalizedKey = _normalizeSignupKey(username, host);
    final filtered = pending
        .where((entry) => !entry.matchesKey(normalizedKey))
        .toList(growable: false);
    if (filtered.length == pending.length) {
      return;
    }
    await _writePendingAccountDeletions(filtered);
  }

  Future<void> _recordAccountAuthenticated(String jid) async {
    final normalized = _normalizeJid(jid);
    try {
      final accounts = await _readCompletedSignupAccounts();
      if (accounts.add(normalized)) {
        await _writeCompletedSignupAccounts(accounts);
      }
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to record completed authentication for $normalized',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _removeCompletedAccountRecord(
    String username,
    String host,
  ) async {
    final normalized = _normalizeSignupKey(username, host);
    try {
      final accounts = await _readCompletedSignupAccounts();
      if (accounts.remove(normalized)) {
        await _writeCompletedSignupAccounts(accounts);
      }
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to clear completed authentication record for $normalized',
        error,
        stackTrace,
      );
    }
  }

  Future<bool> _hasCompletedAuthentication(String normalizedKey) async {
    final accounts = await _readCompletedSignupAccounts();
    return accounts.contains(normalizedKey);
  }

  Future<Set<String>> _readCompletedSignupAccounts() async {
    final serialized =
        await _credentialStore.read(key: completedSignupAccountsKey);
    if (serialized == null || serialized.isEmpty) {
      return <String>{};
    }
    try {
      final decoded = jsonDecode(serialized) as List<dynamic>;
      return decoded
          .whereType<String>()
          .map((value) => value.trim().toLowerCase())
          .toSet();
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to decode completed signup accounts',
        error,
        stackTrace,
      );
      await _credentialStore.delete(key: completedSignupAccountsKey);
      return <String>{};
    }
  }

  Future<void> _writeCompletedSignupAccounts(Set<String> accounts) async {
    if (accounts.isEmpty) {
      await _credentialStore.delete(key: completedSignupAccountsKey);
      return;
    }
    final serialized = jsonEncode(accounts.toList());
    await _credentialStore.write(
      key: completedSignupAccountsKey,
      value: serialized,
    );
  }

  Future<void> _purgeLegacySignupDraft() async {
    try {
      await _credentialStore.delete(key: _legacySignupDraftStorageKey);
      await _credentialStore.delete(key: _legacySignupDraftClosedAtStorageKey);
    } on Exception catch (error, stackTrace) {
      _log.finer(
        'Failed to clear legacy signup draft artifacts',
        error,
        stackTrace,
      );
    }
  }

  void _handleSignupCleanupResolution(
    List<_PendingAccountDeletion> remaining,
  ) {
    final blockedKey = _blockedSignupCredentialKey;
    if (blockedKey == null) {
      return;
    }
    final stillPending = remaining.any(
      (entry) => _normalizeSignupKey(entry.username, entry.host) == blockedKey,
    );
    if (stillPending) {
      return;
    }
    _blockedSignupCredentialKey = null;
    final stateSnapshot = state;
    if (stateSnapshot is AuthenticationSignupFailure &&
        stateSnapshot.isCleanupBlocked) {
      emit(const AuthenticationNone());
    }
  }

  String _normalizeJid(String jid) {
    final parts = jid.split('@');
    if (parts.length == 2) {
      return _normalizeSignupKey(parts.first, parts.last);
    }
    return jid.trim().toLowerCase();
  }

  String _normalizeSignupKey(String username, String host) =>
      '${username.trim().toLowerCase()}@${host.trim().toLowerCase()}';
}

class _PendingAccountDeletion {
  _PendingAccountDeletion({
    required String username,
    required String host,
    required this.password,
    String? createdAt,
  })  : username = username.trim().toLowerCase(),
        host = host.trim().toLowerCase(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  factory _PendingAccountDeletion.fromJson(Map<String, dynamic> json) {
    return _PendingAccountDeletion(
      username: (json['username'] as String? ?? '').trim(),
      host: (json['host'] as String? ?? AuthenticationCubit.domain).trim(),
      password: json['password'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
    );
  }

  final String username;
  final String host;
  final String password;
  final String createdAt;

  Map<String, String> toJson() => {
        'username': username,
        'host': host,
        'password': password,
        'createdAt': createdAt,
      };

  bool matches(_PendingAccountDeletion other) =>
      matchesCredentials(other.username, other.host);

  bool matchesCredentials(String username, String host) =>
      this.username == username.trim().toLowerCase() &&
      this.host == host.trim().toLowerCase();

  bool matchesKey(String key) => '$username@$host' == key.trim().toLowerCase();
}
