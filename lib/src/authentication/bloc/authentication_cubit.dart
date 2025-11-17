import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:axichat/main.dart';
import 'package:axichat/src/authentication/models/signup_draft.dart';
import 'package:axichat/src/common/generate_random.dart';
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
    AuthenticationState? initialState,
  })  : _credentialStore = credentialStore,
        _xmppService = xmppService,
        _emailService = emailService,
        _httpClient = httpClient ?? http.Client(),
        super(initialState ?? const AuthenticationNone()) {
    _lifecycleListener = AppLifecycleListener(
      onResume: login,
      onShow: login,
      onRestart: login,
      onDetach: () async {
        await _recordSignupDraftClosedTimestamp();
        await logout();
      },
      onExitRequested: () async {
        await logout();
        await _recordSignupDraftClosedTimestamp();
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
        if (lifeCycleState == AppLifecycleState.detached) {
          await _recordSignupDraftClosedTimestamp();
        } else if (lifeCycleState == AppLifecycleState.resumed) {
          await _clearSignupDraftClosureMarker();
        }
      },
    );
    _connectivitySubscription =
        xmppService.connectivityStream.listen((connectionState) {
      if (connectionState == ConnectionState.connected) {
        unawaited(_emailService?.handleNetworkAvailable());
        unawaited(_flushPendingAccountDeletions());
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
    unawaited(_ensureSignupDraftHydrated());
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
  final signupDraftStorageKey = CredentialStore.registerKey('signup_draft_v1');
  final signupDraftClosedAtStorageKey =
      CredentialStore.registerKey('signup_draft_last_closed_at');
  static const Duration _signupDraftClosureExpiry = Duration(minutes: 10);

  final CredentialStore _credentialStore;
  final XmppService _xmppService;
  final EmailService? _emailService;
  final http.Client _httpClient;
  String? _authenticatedJid;
  EmailProvisioningException? _lastEmailProvisioningError;
  SignupDraft? _signupDraft;
  StreamSubscription<ConnectionState>? _connectivitySubscription;
  VoidCallback? _foregroundListener;
  Future<void>? _pendingAccountDeletionFlush;
  Completer<void>? _signupDraftLoadCompleter;
  bool _signupDraftHydrated = false;
  String? _blockedSignupCredentialKey;

  late final AppLifecycleListener _lifecycleListener;

  @override
  void onChange(Change<AuthenticationState> change) {
    super.onChange(change);
    if (change.nextState is AuthenticationComplete) {
      clearSignupDraft();
    }
  }

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

  SignupDraft? get signupDraft => _signupDraft;

  bool get hasPersistedSignupDraft =>
      _signupDraft != null && !_signupDraft!.isEmpty;

  void saveSignupDraft(SignupDraft draft) {
    final normalized = draft.isEmpty ? null : draft;
    if (_signupDraft == normalized) {
      return;
    }
    _signupDraft = normalized;
    unawaited(_persistSignupDraft());
  }

  void clearSignupDraft() {
    if (_signupDraft != null) {
      _signupDraft = null;
    }
    unawaited(_credentialStore.delete(key: signupDraftStorageKey));
    unawaited(_clearSignupDraftClosureMarker());
  }

  Future<SignupDraft?> loadSignupDraft() async {
    await _ensureSignupDraftHydrated();
    return _signupDraft;
  }

  Future<void> login({
    String? username,
    String? password,
    bool rememberMe = false,
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
    var emailPassword = password;
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

    final savedPassword = await _credentialStore.read(key: passwordStorageKey);
    final bool usingStoredCredentials = username == null;
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

    try {
      password = await _xmppService.connect(
        jid: resolvedJid,
        password: xmppPassword,
        databasePrefix: databasePrefix,
        databasePassphrase: databasePassphrase,
        preHashed: preHashed,
      );
    } on XmppAuthenticationException catch (_) {
      emit(const AuthenticationFailure('Incorrect username or password'));
      await _xmppService.disconnect();
      return;
    } on XmppAlreadyConnectedException catch (_) {
      await _xmppService.disconnect();
      emit(const AuthenticationNone());
      return;
    } on Exception catch (e) {
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

    try {
      final displayName = jid.split('@').first;
      await _emailService?.ensureProvisioned(
        displayName: displayName,
        databasePrefix: databasePrefix,
        databasePassphrase: databasePassphrase,
        jid: jid,
        passwordOverride: emailPassword,
        addressOverride: jid,
      );
      _lastEmailProvisioningError = null;
    } on EmailProvisioningException catch (error) {
      if (error.isRecoverable) {
        _log.warning('Chatmail provisioning pending: ${error.message}');
        _lastEmailProvisioningError = null;
      } else {
        _lastEmailProvisioningError = error;
        emit(AuthenticationFailure(error.message));
        await _xmppService.disconnect();
        return;
      }
    } on Exception catch (error, stackTrace) {
      _log.warning('Chatmail provisioning failed', error, stackTrace);
    }

    emit(const AuthenticationComplete());
    clearSignupDraft();
    _updateEmailForegroundKeepalive();
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
        return;
      }
    } on Exception catch (_) {
      emit(const AuthenticationSignupFailure(
        'Failed to register, try again later.',
      ));
      return;
    }
    await login(username: username, password: password, rememberMe: rememberMe);
    final signupComplete = state is AuthenticationComplete;
    if (!signupComplete || _lastEmailProvisioningError != null) {
      await _rollbackSignup(
        username: username,
        host: host,
        password: password,
      );
    }
  }

  Future<void> _ensureSignupDraftHydrated() async {
    if (_signupDraftHydrated) {
      return;
    }
    if (_signupDraftLoadCompleter != null) {
      return _signupDraftLoadCompleter!.future;
    }
    final completer = Completer<void>();
    _signupDraftLoadCompleter = completer;
    try {
      await _expireSignupDraftIfClosedTooLong();
      final serialized =
          await _credentialStore.read(key: signupDraftStorageKey);
      if (serialized != null && serialized.isNotEmpty) {
        try {
          final json = jsonDecode(serialized);
          if (json is Map<String, dynamic>) {
            _signupDraft = SignupDraft.fromJson(json);
          }
        } on FormatException catch (error, stackTrace) {
          _log.warning(
            'Failed to parse signup draft payload',
            error,
            stackTrace,
          );
          await _credentialStore.delete(key: signupDraftStorageKey);
        } on Exception catch (error, stackTrace) {
          _log.warning(
            'Unexpected signup draft parsing failure',
            error,
            stackTrace,
          );
          await _credentialStore.delete(key: signupDraftStorageKey);
        }
      }
    } finally {
      _signupDraftHydrated = true;
      completer.complete();
    }
  }

  Future<void> _persistSignupDraft() async {
    final draft = _signupDraft;
    if (draft == null || draft.isEmpty) {
      await _credentialStore.delete(key: signupDraftStorageKey);
      return;
    }
    try {
      await _credentialStore.write(
        key: signupDraftStorageKey,
        value: jsonEncode(draft.toJson()),
      );
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to persist signup draft', error, stackTrace);
    }
  }

  Future<void> _rollbackSignup({
    required String username,
    required String host,
    required String password,
  }) async {
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
    final pending = await _readPendingAccountDeletions();
    if (pending.any((entry) => entry.matches(deletion))) {
      return;
    }
    pending.add(deletion);
    await _writePendingAccountDeletions(pending);
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
      final remaining = <_PendingAccountDeletion>[];
      for (final request in pending) {
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
    final cleanupPending = pending.any(
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

  Future<void> _recordSignupDraftClosedTimestamp() async {
    try {
      await _credentialStore.write(
        key: signupDraftClosedAtStorageKey,
        value: DateTime.now().toUtc().toIso8601String(),
      );
    } on Exception catch (error, stackTrace) {
      _log.finer(
        'Failed to store signup draft closure timestamp',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _clearSignupDraftClosureMarker() async {
    try {
      await _credentialStore.delete(key: signupDraftClosedAtStorageKey);
    } on Exception catch (error, stackTrace) {
      _log.finer(
        'Failed to clear signup draft closure timestamp',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _expireSignupDraftIfClosedTooLong() async {
    final rawTimestamp =
        await _credentialStore.read(key: signupDraftClosedAtStorageKey);
    if (rawTimestamp == null || rawTimestamp.isEmpty) {
      return;
    }
    await _clearSignupDraftClosureMarker();
    DateTime? closedAt;
    try {
      closedAt = DateTime.parse(rawTimestamp).toUtc();
    } on Exception catch (error, stackTrace) {
      _log.finer(
        'Failed to parse signup draft closure timestamp',
        error,
        stackTrace,
      );
    }
    if (closedAt == null) {
      return;
    }
    final now = DateTime.now().toUtc();
    if (now.difference(closedAt) >= _signupDraftClosureExpiry) {
      _log.info(
        'Deleting signup draft after ${_signupDraftClosureExpiry.inMinutes} '
        'minutes in a closed state.',
      );
      _signupDraft = null;
      await _credentialStore.delete(key: signupDraftStorageKey);
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
}
