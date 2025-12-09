import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:axichat/main.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/email/service/chatmail_provisioning_client.dart'
    as provisioning;
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
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
import 'package:moxxmpp/moxxmpp.dart' as mox;

part 'authentication_state.dart';

const _smtpProvisioningMaxAttempts = 3;
const _smtpProvisioningMaxDuration = Duration(seconds: 20);
const _smtpProvisioningInitialDelay = Duration(seconds: 2);
const _smtpProvisioningMaxDelay = Duration(seconds: 8);

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
    provisioning.EmailProvisioningClient? emailProvisioningClient,
    AuthenticationState? initialState,
    EndpointConfig? initialEndpointConfig,
    EndpointResolver endpointResolver = const EndpointResolver(),
  })  : _credentialStore = credentialStore,
        _xmppService = xmppService,
        _emailService = emailService,
        _endpointResolver = endpointResolver,
        _endpointConfig = initialState?.config ??
            initialEndpointConfig ??
            const EndpointConfig(),
        super(initialState ?? const AuthenticationNone()) {
    _httpClient = httpClient ?? http.Client();
    _emailProvisioningClient = emailProvisioningClient ??
        provisioning.EmailProvisioningClient.fromEnvironment(
          httpClient: _httpClient,
        );
    _emailService?.updateEndpointConfig(_endpointConfig);
    _authRecoveryFuture = _recoverAuthTransaction();
    unawaited(_restoreEndpointConfig());
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
      _emailAuthFailureSubscription =
          _emailService.authFailureStream.listen(_handleEmailAuthFailure);
    }
    unawaited(_flushPendingAccountDeletions());
    unawaited(_purgeLegacySignupDraft());
    if (kEnableDemoChats) {
      unawaited(_loginToDemoMode());
    }
  }

  final _log = Logger('AuthenticationCubit');

  static const String domain = EndpointConfig.defaultDomain;
  static const String signupCleanupInProgressMessage =
      'Cleaning up your previous signup attempt. We will retry the removal as soon as you are back online—try again once it finishes.';

  Uri get registrationUrl => _buildRegistrationUrl();

  final jidStorageKey = CredentialStore.registerKey('jid');
  final passwordStorageKey = CredentialStore.registerKey('password');
  final passwordPreHashedStorageKey =
      CredentialStore.registerKey('password_prehashed_v1');
  final rememberMeChoiceKey = CredentialStore.registerKey('remember_me_choice');
  final pendingSignupRollbacksKey =
      CredentialStore.registerKey('pending_signup_rollbacks');
  final completedSignupAccountsKey =
      CredentialStore.registerKey('completed_signup_accounts_v1');
  final _legacySignupDraftStorageKey =
      CredentialStore.registerKey('signup_draft_v1');
  final _legacySignupDraftClosedAtStorageKey =
      CredentialStore.registerKey('signup_draft_last_closed_at');
  final endpointConfigStorageKey =
      CredentialStore.registerKey('endpoint_config_v1');
  final authTransactionStorageKey =
      CredentialStore.registerKey('auth_transaction_v1');

  final CredentialStore _credentialStore;
  final XmppService _xmppService;
  final EmailService? _emailService;
  final EndpointResolver _endpointResolver;
  EndpointConfig _endpointConfig;
  late final http.Client _httpClient;
  late final provisioning.EmailProvisioningClient _emailProvisioningClient;
  String? _authenticatedJid;
  EmailProvisioningException? _lastEmailProvisioningError;
  StreamSubscription<ConnectionState>? _connectivitySubscription;
  StreamSubscription<DeltaChatException>? _emailAuthFailureSubscription;
  VoidCallback? _foregroundListener;
  Future<void>? _pendingAccountDeletionFlush;
  String? _blockedSignupCredentialKey;
  String? _activeSignupCredentialKey;
  AvatarUploadPayload? _signupAvatarDraft;
  _AuthTransaction? _authTransaction;
  late final Future<void> _authRecoveryFuture;
  bool get _stickyAuthActive => state is AuthenticationComplete;
  bool _loginInFlight = false;
  bool _demoLoginInProgress = false;
  bool _demoSessionReady = false;

  late final AppLifecycleListener _lifecycleListener;

  EndpointConfig get endpointConfig => _endpointConfig;

  Future<void> updateEndpointConfig(EndpointConfig config) async {
    _endpointConfig = config;
    _emailService?.updateEndpointConfig(config);
    await _credentialStore.write(
      key: endpointConfigStorageKey,
      value: jsonEncode(config.toJson()),
    );
    _emit(state);
    _updateEmailForegroundKeepalive();
  }

  Future<void> resetEndpointConfig() => updateEndpointConfig(
        const EndpointConfig(),
      );

  Future<void> _restoreEndpointConfig() async {
    try {
      final stored =
          await _credentialStore.read(key: endpointConfigStorageKey) ?? '';
      if (stored.isEmpty) {
        return;
      }
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      final restored = EndpointConfig.fromJson(decoded);
      _endpointConfig = restored;
      _emailService?.updateEndpointConfig(restored);
      _emit(state);
      _updateEmailForegroundKeepalive();
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to restore endpoint config', error, stackTrace);
    }
  }

  Uri _buildBaseUrl() => Uri(
        scheme: _endpointConfig.apiUseTls ? 'https' : 'http',
        host: _endpointConfig.domain,
        port: _endpointConfig.apiPort,
      );

  Uri _buildRegistrationUrl() =>
      _buildBaseUrl().replace(path: '/register/new/');

  Uri _buildChangePasswordUrl() =>
      _buildBaseUrl().replace(path: '/register/password/');

  Uri _buildDeleteAccountUrl() =>
      _buildBaseUrl().replace(path: '/register/unregister/');

  void _emit(AuthenticationState state) {
    // Always allow transitions away from an authenticated session (e.g. logout).
    emit(state.copyWithConfig(_endpointConfig));
  }

  Future<void> _recoverAuthTransaction() async {
    final txn = await _readAuthTransaction();
    if (txn == null) return;
    if (txn.committed) {
      await _clearAuthTransaction();
      return;
    }
    _authTransaction = txn;
    await _rollbackAuthTransaction(
      clearCredentials: txn.clearCredentialsOnFailure,
      jid: txn.jid,
    );
  }

  Future<_AuthTransaction?> _readAuthTransaction() async {
    try {
      final raw = await _credentialStore.read(key: authTransactionStorageKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return _AuthTransaction.fromJson(decoded);
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to read auth transaction', error, stackTrace);
      return null;
    }
  }

  Future<void> _persistAuthTransaction(_AuthTransaction txn) async {
    try {
      await _credentialStore.write(
        key: authTransactionStorageKey,
        value: jsonEncode(txn.toJson()),
      );
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to persist auth transaction', error, stackTrace);
    }
  }

  Future<void> _clearAuthTransaction() async {
    _authTransaction = null;
    try {
      await _credentialStore.delete(key: authTransactionStorageKey);
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to clear auth transaction', error, stackTrace);
    }
  }

  Future<void> _clearLoginSecrets() async {
    await _credentialStore.delete(key: jidStorageKey);
    await _credentialStore.delete(key: passwordStorageKey);
    await _credentialStore.delete(key: passwordPreHashedStorageKey);
  }

  Future<void> _clearStoredSmtpCredentials(
    String jid, {
    bool preserveActiveSession = false,
  }) async {
    if (!_endpointConfig.enableSmtp) {
      return;
    }
    await _emailService?.clearStoredCredentials(
      jid: jid,
      preserveActiveSession: preserveActiveSession,
    );
  }

  Future<void> persistRememberMeChoice(bool rememberMe) async {
    await _credentialStore.write(
      key: rememberMeChoiceKey,
      value: rememberMe.toString(),
    );
  }

  Future<bool> loadRememberMeChoice() async {
    final stored = await _credentialStore.read(key: rememberMeChoiceKey);
    final parsed = _parseBoolOrNull(stored);
    return parsed ?? true;
  }

  Future<_StoredLoginCredentials> _readStoredLoginCredentials() async {
    final storedJid = await _credentialStore.read(key: jidStorageKey);
    final storedPassword = await _credentialStore.read(key: passwordStorageKey);
    final storedPasswordPreHashed = _parseBoolOrNull(
        await _credentialStore.read(key: passwordPreHashedStorageKey));
    return _StoredLoginCredentials(
      jid: storedJid,
      password: storedPassword,
      passwordPreHashed: storedPasswordPreHashed,
    );
  }

  Future<bool> hasStoredLoginCredentials() async {
    final storedLogin = await _readStoredLoginCredentials();
    return storedLogin.hasUsableCredentials;
  }

  Future<_DatabaseSecrets> _readDatabaseSecrets(String jid) async {
    var prefixKey = CredentialStore.registerKey('${jid}_database_prefix');
    var storedPrefix = await _credentialStore.read(key: prefixKey);

    if ((storedPrefix == null || storedPrefix.isEmpty) &&
        jid != _normalizeJid(jid)) {
      final normalizedJid = _normalizeJid(jid);
      final normalizedKey =
          CredentialStore.registerKey('${normalizedJid}_database_prefix');
      storedPrefix = await _credentialStore.read(key: normalizedKey);
      if (storedPrefix != null && storedPrefix.isNotEmpty) {
        prefixKey = normalizedKey;
      }
    }

    RegisteredCredentialKey? passphraseKey;
    String? storedPassphrase;
    if (storedPrefix != null && storedPrefix.isNotEmpty) {
      passphraseKey =
          CredentialStore.registerKey('${storedPrefix}_database_passphrase');
      storedPassphrase = await _credentialStore.read(key: passphraseKey);
    }
    return _DatabaseSecrets(
      prefixKey: prefixKey,
      prefix: storedPrefix,
      passphraseKey: passphraseKey,
      passphrase: storedPassphrase,
    );
  }

  Future<void> _updateAuthTransactionCredentialClearance(
      bool shouldClear) async {
    final txn = _authTransaction ?? await _readAuthTransaction();
    if (txn == null || txn.clearCredentialsOnFailure == shouldClear) {
      return;
    }
    final updated = txn.copyWith(clearCredentialsOnFailure: shouldClear);
    _authTransaction = updated;
    await _persistAuthTransaction(updated);
  }

  bool? _parseBoolOrNull(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized = raw.toLowerCase().trim();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
    return null;
  }

  Future<void> _startAuthTransaction({
    required String jid,
    required bool clearCredentialsOnFailure,
  }) async {
    final txn = _AuthTransaction(
      jid: jid,
      clearCredentialsOnFailure: clearCredentialsOnFailure,
    );
    _authTransaction = txn;
    await _persistAuthTransaction(txn);
  }

  Future<void> _markXmppConnected() async {
    final txn = _authTransaction;
    if (txn == null || txn.xmppConnected) {
      return;
    }
    final updated = txn.copyWith(xmppConnected: true);
    _authTransaction = updated;
    await _persistAuthTransaction(updated);
  }

  Future<void> _markSmtpProvisioned() async {
    final txn = _authTransaction;
    if (txn == null || txn.smtpProvisioned) {
      return;
    }
    final updated = txn.copyWith(smtpProvisioned: true);
    _authTransaction = updated;
    await _persistAuthTransaction(updated);
  }

  Future<void> _completeAuthTransaction() async {
    final txn = _authTransaction;
    if (txn == null) {
      return;
    }
    final committed = txn.copyWith(committed: true);
    _authTransaction = committed;
    await _persistAuthTransaction(committed);
    await _clearAuthTransaction();
  }

  Future<void> _rollbackAuthTransaction({
    required bool clearCredentials,
    String? jid,
  }) async {
    final txn = _authTransaction ?? await _readAuthTransaction();
    if (txn == null) {
      if (clearCredentials) {
        await _clearLoginSecrets();
        if (jid != null) {
          await _clearStoredSmtpCredentials(jid);
        }
      }
      return;
    }
    _authTransaction = txn;
    final shouldClearCredentials =
        clearCredentials || txn.clearCredentialsOnFailure;
    if (shouldClearCredentials || txn.smtpProvisioned) {
      await _cancelPendingEmailProvisioning(
        null,
        txn.jid,
        clearCredentials: shouldClearCredentials,
      );
    }
    if (txn.xmppConnected || _xmppService.connected) {
      await _xmppService.disconnect();
    }
    if (shouldClearCredentials) {
      await _clearLoginSecrets();
    }
    _authenticatedJid = null;
    await _clearAuthTransaction();
  }

  EndpointOverride? _overrideFrom(IOEndpoint? endpoint) {
    if (endpoint == null) {
      return null;
    }
    return EndpointOverride(host: endpoint.host, port: endpoint.port);
  }

  @override
  Future<void> close() async {
    _lifecycleListener.dispose();
    await _connectivitySubscription?.cancel();
    await _emailAuthFailureSubscription?.cancel();
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
    bool rememberMe = true,
    bool requireEmailProvisioned = false,
    provisioning.EmailProvisioningCredentials? emailCredentials,
  }) async {
    if (kEnableDemoChats) {
      await _loginToDemoMode();
      return;
    }
    if (_loginInFlight) {
      _log.fine('Ignoring login request while another is in flight.');
      return;
    }
    _loginInFlight = true;
    try {
      _log.info(
        'Login requested '
        '(usingStoredCredentials: ${username == null && password == null}, '
        'xmppEnabled: ${_endpointConfig.enableXmpp}, '
        'smtpEnabled: ${_endpointConfig.enableSmtp})',
      );
      _lastEmailProvisioningError = null;
      await _authRecoveryFuture;
      if (state is AuthenticationComplete && _xmppService.connected) {
        return;
      }
      if (state is AuthenticationLogInInProgress) {
        _log.fine('Ignoring login request while another is in progress.');
        return;
      }
      final AuthenticationState previousState = state;
      final config = _endpointConfig;
      final xmppEnabled = config.enableXmpp;
      final smtpEnabled = config.enableSmtp;
      if (!xmppEnabled && !smtpEnabled) {
        _emit(const AuthenticationFailure(
          'Enable XMPP or SMTP to continue.',
        ));
        return;
      }
      final bool wasAuthenticated = state is AuthenticationComplete;
      final bool usingStoredCredentials = username == null && password == null;
      final storedLogin =
          usingStoredCredentials ? await _readStoredLoginCredentials() : null;
      if ((username == null) != (password == null)) {
        _emit(const AuthenticationFailure(
            'Username and password have different nullness.'));
        return;
      }
      var credentialDisposition = _CredentialDisposition.keep;

      if (usingStoredCredentials &&
          !(storedLogin?.hasUsableCredentials ?? false)) {
        _log.info('Login aborted due to missing stored credentials.');
        _authenticatedJid = null;
        await _xmppService.disconnect();
        _emit(const AuthenticationNone());
        return;
      }

      final loginState = _activeSignupCredentialKey != null
          ? AuthenticationLogInInProgress(fromSignup: true, config: config)
          : AuthenticationLogInInProgress(config: config);

      if (!wasAuthenticated || !usingStoredCredentials) {
        _emit(loginState);
      }

      late final String resolvedJid;
      late final String resolvedPassword;
      bool passwordPreHashed = false;
      if (usingStoredCredentials) {
        final loginFromStore = storedLogin!;
        resolvedJid = loginFromStore.jid!;
        resolvedPassword = loginFromStore.password!;
        if (!loginFromStore.hasPreHashedFlag) {
          if (!wasAuthenticated) {
            _emit(const AuthenticationFailure(
              'Stored credentials are outdated. Please log in manually.',
            ));
            _authenticatedJid = null;
            await _xmppService.disconnect();
          } else {
            _log.warning(
              'Stored credentials missing pre-hash flag; preserving session.',
            );
          }
          return;
        }
        passwordPreHashed = loginFromStore.passwordPreHashed ?? false;
      } else {
        resolvedJid = '$username@${config.domain}';
        resolvedPassword = password!;
      }

      final storedSecrets = await _readDatabaseSecrets(resolvedJid);
      final bool hasStoredDatabaseSecrets = storedSecrets.hasSecrets;
      final bool hasStoredLoginForJid =
          (storedLogin?.matches(resolvedJid) ?? false) &&
              (storedLogin?.hasUsableCredentials ?? false);
      if (hasStoredLoginForJid && !hasStoredDatabaseSecrets) {
        _log.warning(
          'Stored login credentials found without database secrets; clearing.',
        );
        await _clearLoginSecrets();
        await _clearStoredSmtpCredentials(resolvedJid);
        _authenticatedJid = null;
        await _xmppService.disconnect();
        _emit(const AuthenticationNone());
        return;
      }

      String? emailPassword = emailCredentials?.password;
      final String displayName = resolvedJid.split('@').first;
      _authenticatedJid ??= resolvedJid;

      final bool canPreserveSession =
          wasAuthenticated && usingStoredCredentials;

      final String ensuredDatabasePrefix =
          storedSecrets.prefix ?? generateRandomString(length: 8);
      final RegisteredCredentialKey databasePrefixStorageKey =
          storedSecrets.prefixKey;

      final RegisteredCredentialKey databasePassphraseStorageKey =
          storedSecrets.passphraseKey ??
              CredentialStore.registerKey(
                '${ensuredDatabasePrefix}_database_passphrase',
              );

      final String ensuredDatabasePassphrase =
          storedSecrets.passphrase ?? generateRandomString();

      final String xmppPassword = resolvedPassword;
      String? effectivePassword = xmppPassword;

      await _startAuthTransaction(
        jid: resolvedJid,
        clearCredentialsOnFailure: credentialDisposition.shouldWipe,
      );

      var authenticationCommitted = false;
      try {
        final emailService = smtpEnabled ? _emailService : null;
        if (emailPassword == null && emailService != null) {
          final existing = await emailService.currentAccount(resolvedJid);
          emailPassword = existing?.password ?? resolvedPassword;
        }

        final enforceEmailProvisioning = requireEmailProvisioned ||
            _activeSignupCredentialKey != null ||
            emailService != null;

        final reuseExistingSession = _xmppService.databasesInitialized &&
            _xmppService.myJid == resolvedJid;

        EndpointOverride? xmppEndpoint;
        if (xmppEnabled) {
          try {
            xmppEndpoint = await _endpointResolver.resolveXmpp(
              config,
              fallback: _overrideFrom(serverLookup[config.domain]),
            );
          } on EndpointResolutionException catch (error) {
            if (!canPreserveSession) {
              _emit(AuthenticationFailure(error.message, config: config));
              return;
            }
            _log.warning('Endpoint resolution failed: ${error.message}');
            await _clearAuthTransaction();
            authenticationCommitted = true;
            if (previousState is! AuthenticationComplete) {
              _emit(const AuthenticationComplete());
            }
            return;
          }
        }

        if (xmppEnabled) {
          try {
            effectivePassword = await _xmppService.connect(
              jid: resolvedJid,
              password: xmppPassword,
              databasePrefix: ensuredDatabasePrefix,
              databasePassphrase: ensuredDatabasePassphrase,
              preHashed: passwordPreHashed,
              reuseExistingSession: reuseExistingSession,
              endpoint: xmppEndpoint,
            );
            passwordPreHashed = true;
            await _markXmppConnected();
          } on XmppAuthenticationException catch (_) {
            credentialDisposition = _CredentialDisposition.wipeLoginCredentials;
            await _updateAuthTransactionCredentialClearance(true);
            _emit(
              const AuthenticationFailure('Incorrect username or password'),
            );
            await _xmppService.disconnect();
            _authenticatedJid = null;
            return;
          } on XmppNetworkException catch (error) {
            final canResumeOffline =
                usingStoredCredentials && hasStoredDatabaseSecrets;
            if (canResumeOffline) {
              final resumeResult = await _resumeOfflineLogin(
                jid: resolvedJid,
                displayName: displayName,
                databasePrefix: ensuredDatabasePrefix,
                databasePassphrase: ensuredDatabasePassphrase,
                rememberMe: rememberMe,
                password: effectivePassword,
                passwordPreHashed: passwordPreHashed,
                emailPassword: emailPassword,
                emailCredentials: emailCredentials,
                enforceEmailProvisioning: enforceEmailProvisioning,
                databasePrefixStorageKey: databasePrefixStorageKey,
                databasePassphraseStorageKey: databasePassphraseStorageKey,
              );
              if (resumeResult.isResumed) {
                authenticationCommitted = true;
                return;
              }
              if (resumeResult.shouldWipeCredentials) {
                credentialDisposition =
                    _CredentialDisposition.wipeLoginCredentials;
                await _updateAuthTransactionCredentialClearance(true);
              }
            }
            _log.warning('Network/XMPP error during login', error);
            await _xmppService.disconnect();
            _authenticatedJid = null;
            _emit(
                const AuthenticationFailure('Error. Please try again later.'));
            return;
          } on XmppAlreadyConnectedException catch (_) {
            _log.fine('Re-auth attempted while already connected, ignoring.');
            await _markXmppConnected();
            await _completeAuthTransaction();
            authenticationCommitted = true;
            return;
          } on Exception catch (error) {
            final canResumeOffline = usingStoredCredentials &&
                hasStoredDatabaseSecrets &&
                _looksLikeConnectivityError(error);
            if (canResumeOffline) {
              final resumeResult = await _resumeOfflineLogin(
                jid: resolvedJid,
                displayName: displayName,
                databasePrefix: ensuredDatabasePrefix,
                databasePassphrase: ensuredDatabasePassphrase,
                rememberMe: rememberMe,
                password: effectivePassword,
                passwordPreHashed: passwordPreHashed,
                emailPassword: emailPassword,
                emailCredentials: emailCredentials,
                enforceEmailProvisioning: enforceEmailProvisioning,
                databasePrefixStorageKey: databasePrefixStorageKey,
                databasePassphraseStorageKey: databasePassphraseStorageKey,
              );
              if (resumeResult.isResumed) {
                authenticationCommitted = true;
                return;
              }
              if (resumeResult.shouldWipeCredentials) {
                credentialDisposition =
                    _CredentialDisposition.wipeLoginCredentials;
                await _updateAuthTransactionCredentialClearance(true);
              }
            }
            _log.severe(error);
            await _xmppService.disconnect();
            _authenticatedJid = null;
            _emit(
                const AuthenticationFailure('Error. Please try again later.'));
            return;
          }
        } else {
          await _xmppService.resumeOfflineSession(
            jid: resolvedJid,
            databasePrefix: ensuredDatabasePrefix,
            databasePassphrase: ensuredDatabasePassphrase,
          );
          await _markXmppConnected();
          effectivePassword = resolvedPassword;
        }

        final allowOfflineEmail =
            usingStoredCredentials && hasStoredDatabaseSecrets;
        final provisioningStatus = await _provisionEmailWithRetry(
          displayName: displayName,
          databasePrefix: ensuredDatabasePrefix,
          databasePassphrase: ensuredDatabasePassphrase,
          jid: resolvedJid,
          enforceProvisioning: enforceEmailProvisioning,
          emailPassword: emailPassword,
          emailCredentials: emailCredentials,
          persistCredentials: false,
          allowOfflineOnRecoverable: allowOfflineEmail,
          allowRetries: !hasStoredDatabaseSecrets,
        );
        if (provisioningStatus.shouldAbort) {
          if (provisioningStatus.shouldWipeCredentials) {
            credentialDisposition = _CredentialDisposition.wipeLoginCredentials;
            await _updateAuthTransactionCredentialClearance(true);
          }
          _log.warning('Email provisioning failed; aborting authentication.');
          await _xmppService.disconnect();
          _authenticatedJid = null;
          if (state is! AuthenticationFailure &&
              state is! AuthenticationSignupFailure) {
            final fallbackMessage =
                provisioningStatus == _ProvisioningStatus.blockedTransient
                    ? 'Unable to reach the email server. Please try again.'
                    : 'Email setup failed. Please try again.';
            _emit(
              AuthenticationFailure(
                _lastEmailProvisioningError?.message ?? fallbackMessage,
              ),
            );
          }
          return;
        }

        await _finalizeAuthentication(
          jid: resolvedJid,
          rememberMe: rememberMe,
          password: effectivePassword,
          passwordPreHashed: passwordPreHashed,
          databasePrefixStorageKey: databasePrefixStorageKey,
          databasePrefix: ensuredDatabasePrefix,
          databasePassphraseStorageKey: databasePassphraseStorageKey,
          databasePassphrase: ensuredDatabasePassphrase,
        );
        authenticationCommitted = true;
      } finally {
        if (!authenticationCommitted) {
          await _rollbackAuthTransaction(
            clearCredentials: credentialDisposition.shouldWipe,
            jid: resolvedJid,
          );
        }
      }
    } finally {
      _loginInFlight = false;
    }
  }

  Future<void> _loginToDemoMode() async {
    if (_demoSessionReady || _demoLoginInProgress) {
      return;
    }
    _demoLoginInProgress = true;
    _loginInFlight = true;
    try {
      await _authRecoveryFuture;
      final demoDomain = kDemoSelfJid.split('@').last;
      final demoConfig = EndpointConfig(
        domain: demoDomain,
        enableXmpp: false,
        enableSmtp: false,
      );
      if (_endpointConfig != demoConfig) {
        _endpointConfig = demoConfig;
        _emailService?.updateEndpointConfig(demoConfig);
        _emit(state);
        _updateEmailForegroundKeepalive();
      }
      await _xmppService.resumeOfflineSession(
        jid: kDemoSelfJid,
        databasePrefix: kDemoDatabasePrefix,
        databasePassphrase: kDemoDatabasePassphrase,
      );
      await _markXmppConnected();
      _authenticatedJid = kDemoSelfJid;
      _demoSessionReady = true;
      _emit(const AuthenticationComplete());
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to start demo session', error, stackTrace);
      _authenticatedJid = null;
      _emit(const AuthenticationFailure(
        'Failed to start demo mode. Please try again.',
      ));
    } finally {
      _demoLoginInProgress = false;
      _loginInFlight = false;
    }
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
        'Failed to clean up email provisioning after aborted login',
        error,
        stackTrace,
      );
    }
  }

  Future<_ResumeResult> _resumeOfflineLogin({
    required String jid,
    required String displayName,
    required String databasePrefix,
    required String databasePassphrase,
    required bool rememberMe,
    required bool enforceEmailProvisioning,
    required RegisteredCredentialKey databasePrefixStorageKey,
    required RegisteredCredentialKey databasePassphraseStorageKey,
    required bool passwordPreHashed,
    String? password,
    String? emailPassword,
    provisioning.EmailProvisioningCredentials? emailCredentials,
  }) async {
    try {
      await _xmppService.resumeOfflineSession(
        jid: jid,
        databasePrefix: databasePrefix,
        databasePassphrase: databasePassphrase,
      );
      await _markXmppConnected();
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to resume offline session', error, stackTrace);
      return _ResumeResult.blockedTransient;
    }

    final provisioningStatus = await _provisionEmailWithRetry(
      displayName: displayName,
      databasePrefix: databasePrefix,
      databasePassphrase: databasePassphrase,
      jid: jid,
      enforceProvisioning: enforceEmailProvisioning,
      emailPassword: emailPassword,
      emailCredentials: emailCredentials,
      persistCredentials: false,
      allowOfflineOnRecoverable: true,
      allowRetries: false,
    );
    if (provisioningStatus.shouldAbort) {
      await _xmppService.disconnect();
      if (provisioningStatus.shouldWipeCredentials) {
        return _ResumeResult.blockedFatal;
      }
      return _ResumeResult.blockedTransient;
    }

    await _finalizeAuthentication(
      jid: jid,
      rememberMe: rememberMe,
      password: password,
      passwordPreHashed: passwordPreHashed,
      databasePrefixStorageKey: databasePrefixStorageKey,
      databasePrefix: databasePrefix,
      databasePassphraseStorageKey: databasePassphraseStorageKey,
      databasePassphrase: databasePassphrase,
    );
    return _ResumeResult.resumed;
  }

  Future<_ProvisioningStatus> _provisionEmailWithRetry({
    required String displayName,
    required String databasePrefix,
    required String databasePassphrase,
    required String jid,
    required bool enforceProvisioning,
    required bool allowOfflineOnRecoverable,
    required bool allowRetries,
    String? emailPassword,
    provisioning.EmailProvisioningCredentials? emailCredentials,
    bool persistCredentials = true,
  }) async {
    var attempts = 0;
    var delay = _smtpProvisioningInitialDelay;
    final start = DateTime.timestamp();
    while (true) {
      final status = await _ensureEmailProvisioned(
        displayName: displayName,
        databasePrefix: databasePrefix,
        databasePassphrase: databasePassphrase,
        jid: jid,
        enforceProvisioning: enforceProvisioning,
        allowOfflineOnRecoverable: allowOfflineOnRecoverable,
        emailPassword: emailPassword,
        emailCredentials: emailCredentials,
        persistCredentials: persistCredentials,
      );
      if (status == _ProvisioningStatus.ready || status.shouldAbort) {
        return status;
      }
      if (allowOfflineOnRecoverable) {
        return _ProvisioningStatus.ready;
      }
      if (!allowRetries) {
        return status;
      }
      attempts += 1;
      final elapsed = DateTime.timestamp().difference(start);
      if (attempts >= _smtpProvisioningMaxAttempts ||
          elapsed >= _smtpProvisioningMaxDuration) {
        return _ProvisioningStatus.blockedTransient;
      }
      await Future.delayed(delay);
      final nextDelayMs = delay.inMilliseconds * 2;
      delay = Duration(
        milliseconds: nextDelayMs.clamp(
          _smtpProvisioningInitialDelay.inMilliseconds,
          _smtpProvisioningMaxDelay.inMilliseconds,
        ),
      );
    }
  }

  Future<_ProvisioningStatus> _ensureEmailProvisioned({
    required String displayName,
    required String databasePrefix,
    required String databasePassphrase,
    required String jid,
    required bool enforceProvisioning,
    required bool allowOfflineOnRecoverable,
    String? emailPassword,
    provisioning.EmailProvisioningCredentials? emailCredentials,
    bool persistCredentials = true,
  }) async {
    if (!_endpointConfig.enableSmtp) {
      return _ProvisioningStatus.ready;
    }
    final emailService = _emailService;
    if (emailService == null) {
      return _ProvisioningStatus.ready;
    }
    var resolvedPassword = emailPassword;
    if (resolvedPassword == null) {
      final existing = await emailService.currentAccount(jid);
      resolvedPassword = existing?.password;
    }
    if (resolvedPassword == null) {
      if (!_stickyAuthActive) {
        _emit(const AuthenticationFailure(
            'Stored email password missing. Please log in manually.'));
      } else {
        _log.warning('Email password missing during silent re-auth.');
      }
      return _ProvisioningStatus.blockedTransient;
    }
    try {
      await emailService.ensureProvisioned(
        displayName: displayName,
        databasePrefix: databasePrefix,
        databasePassphrase: databasePassphrase,
        jid: jid,
        passwordOverride: resolvedPassword,
        addressOverride: emailCredentials?.email,
        persistCredentials: persistCredentials,
      );
      _lastEmailProvisioningError = null;
      await _markSmtpProvisioned();
      return _ProvisioningStatus.ready;
    } on EmailProvisioningException catch (error) {
      final shouldWipeCredentials = error.shouldWipeCredentials;
      final shouldAbort = shouldWipeCredentials ||
          (enforceProvisioning && !error.isRecoverable);
      if (shouldAbort) {
        if (!shouldWipeCredentials && allowOfflineOnRecoverable) {
          _log.warning(
            'Email provisioning deferred; continuing offline: ${error.message}',
          );
          _lastEmailProvisioningError = error;
          return _ProvisioningStatus.pendingRecoverable;
        }
        _lastEmailProvisioningError = error;
        if (!_stickyAuthActive) {
          _emit(AuthenticationFailure(error.message));
        } else {
          _log.warning('Email provisioning failed silently: ${error.message}');
        }
        await _cancelPendingEmailProvisioning(
          null,
          jid,
          clearCredentials: shouldWipeCredentials,
        );
        await _xmppService.disconnect();
        return shouldWipeCredentials
            ? _ProvisioningStatus.blockedFatal
            : _ProvisioningStatus.blockedTransient;
      }
      _log.warning('Email provisioning pending: ${error.message}');
      _lastEmailProvisioningError = null;
      return _ProvisioningStatus.pendingRecoverable;
    } on Exception catch (error, stackTrace) {
      _log.warning('Email provisioning failed', error, stackTrace);
      if (enforceProvisioning) {
        if (allowOfflineOnRecoverable) {
          _log.warning(
            'Email provisioning deferred due to recoverable error; '
            'continuing offline.',
          );
          _lastEmailProvisioningError = null;
          return _ProvisioningStatus.pendingRecoverable;
        }
        if (!_stickyAuthActive) {
          _emit(const AuthenticationFailure('Error. Please try again later.'));
        } else {
          _log.warning('Silent re-auth email provisioning deferred.');
        }
        await _cancelPendingEmailProvisioning(
          null,
          jid,
          clearCredentials: false,
        );
        await _xmppService.disconnect();
        return _ProvisioningStatus.blockedTransient;
      }
      return _ProvisioningStatus.pendingRecoverable;
    }
  }

  Future<void> _finalizeAuthentication({
    required String jid,
    required bool rememberMe,
    required String? password,
    required bool passwordPreHashed,
    required RegisteredCredentialKey databasePrefixStorageKey,
    required String databasePrefix,
    required RegisteredCredentialKey databasePassphraseStorageKey,
    required String databasePassphrase,
  }) async {
    await _persistLoginSecrets(
      jid: jid,
      rememberMe: rememberMe,
      password: password,
      passwordPreHashed: passwordPreHashed,
      databasePrefixStorageKey: databasePrefixStorageKey,
      databasePrefix: databasePrefix,
      databasePassphraseStorageKey: databasePassphraseStorageKey,
      databasePassphrase: databasePassphrase,
    );
    _authenticatedJid = jid;
    _emit(const AuthenticationComplete());
    await _recordAccountAuthenticated(jid);
    await _completeAuthTransaction();
    _updateEmailForegroundKeepalive();
    await _publishPendingAvatar();
  }

  Future<void> _persistLoginSecrets({
    required String jid,
    required bool rememberMe,
    required String? password,
    required bool passwordPreHashed,
    required RegisteredCredentialKey databasePrefixStorageKey,
    required String databasePrefix,
    required RegisteredCredentialKey databasePassphraseStorageKey,
    required String databasePassphrase,
  }) async {
    await _credentialStore.write(
      key: databasePassphraseStorageKey,
      value: databasePassphrase,
    );
    await _credentialStore.write(
      key: databasePrefixStorageKey,
      value: databasePrefix,
    );
    final normalizedPrefixKey = CredentialStore.registerKey(
      '${_normalizeJid(jid)}_database_prefix',
    );
    if (normalizedPrefixKey != databasePrefixStorageKey) {
      await _credentialStore.write(
        key: normalizedPrefixKey,
        value: databasePrefix,
      );
    }
    if (rememberMe) {
      try {
        if (_endpointConfig.enableSmtp) {
          await _emailService?.persistActiveCredentials(jid: jid);
        }
        await _credentialStore.write(key: jidStorageKey, value: jid);
        if (password != null) {
          await _credentialStore.write(
            key: passwordStorageKey,
            value: password,
          );
          await _credentialStore.write(
            key: passwordPreHashedStorageKey,
            value: passwordPreHashed.toString(),
          );
        }
        return;
      } on Exception catch (error, stackTrace) {
        _log.warning(
          'Failed to persist login credentials atomically',
          error,
          stackTrace,
        );
        if (_endpointConfig.enableSmtp) {
          await _emailService?.clearStoredCredentials(
            jid: jid,
            preserveActiveSession: true,
          );
        }
        await _clearLoginSecrets();
        rethrow;
      }
    }
    await _clearLoginSecrets();
    if (_endpointConfig.enableSmtp) {
      await _emailService?.clearStoredCredentials(
        jid: jid,
        preserveActiveSession: true,
      );
    }
  }

  Future<void> _publishPendingAvatar() async {
    final payload = _signupAvatarDraft;
    if (payload == null) return;
    _signupAvatarDraft = null;
    try {
      await _xmppService.publishAvatar(payload);
    } on XmppAvatarException catch (error, stackTrace) {
      final cause = error.wrapped;
      if (cause is mox.AvatarError) {
        _log.info('Signup avatar publish unsupported; skipping.', cause);
        return;
      }
      _log.warning('Failed to publish signup avatar', error, stackTrace);
    } catch (error, stackTrace) {
      _log.warning(
        'Unexpected error publishing signup avatar',
        error,
        stackTrace,
      );
    }
  }

  bool _looksLikeConnectivityError(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException ||
        error is http.ClientException) {
      return true;
    }
    if (error is XmppException && error.wrapped != null) {
      return _looksLikeConnectivityError(error.wrapped!);
    }
    return false;
  }

  Future<void> _handleEmailAuthFailure(
    DeltaChatException exception,
  ) async {
    if (state is! AuthenticationComplete) {
      return;
    }
    _log.warning(
      'Email auth failure detected; forcing credential wipe.',
      exception,
    );
    await logout(severity: LogoutSeverity.normal);
    _emit(const AuthenticationFailure(
      'Email authentication failed. Please log in again.',
    ));
  }

  Future<void> signup({
    required String username,
    required String password,
    required String confirmPassword,
    required String captchaID,
    required String captcha,
    required bool rememberMe,
    AvatarUploadPayload? avatar,
  }) async {
    if (kEnableDemoChats) {
      await _loginToDemoMode();
      return;
    }
    _log.info(
      'Signup requested '
      '(xmppEnabled: ${_endpointConfig.enableXmpp}, '
      'smtpEnabled: ${_endpointConfig.enableSmtp})',
    );
    _emit(const AuthenticationSignUpInProgress());
    final host = _endpointConfig.domain;
    _signupAvatarDraft = avatar;
    final cleanupComplete = await _ensureAccountDeletionCleanupComplete(
      username: username,
      host: host,
    );
    if (!cleanupComplete) {
      _emit(const AuthenticationSignupFailure(
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
    var signupComplete = false;
    provisioning.EmailProvisioningCredentials? emailProvisioningCredentials;
    try {
      if (_emailService != null && _endpointConfig.enableSmtp) {
        emailProvisioningCredentials =
            await _emailProvisioningClient.createAccount(
          localpart: username,
          password: password,
        );
        await _recordEmailProvisioning(
          username: username,
          host: host,
          password: password,
          credentials: emailProvisioningCredentials,
        );
      }
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
        _emit(AuthenticationSignupFailure(response.body));
        return;
      }
      await login(
        username: username,
        password: password,
        rememberMe: rememberMe,
        requireEmailProvisioned: true,
        emailCredentials: emailProvisioningCredentials,
      );
      signupComplete = state is AuthenticationComplete;
    } on provisioning.EmailProvisioningApiException catch (error, stackTrace) {
      _log.warning(
          'Email provisioning failed before signup', error, stackTrace);
      _emit(AuthenticationSignupFailure(error.message));
      return;
    } on Exception catch (error, stackTrace) {
      _log.warning('Signup failed', error, stackTrace);
      _emit(const AuthenticationSignupFailure(
        'Failed to register, try again later.',
      ));
      return;
    } finally {
      _activeSignupCredentialKey = null;
      if (!signupComplete) {
        _signupAvatarDraft = null;
      }
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

  Future<void> _recordEmailProvisioning({
    required String username,
    required String host,
    required String password,
    required provisioning.EmailProvisioningCredentials credentials,
  }) async {
    final normalizedEmail = credentials.email.trim();
    if (normalizedEmail.isEmpty) {
      _log.warning('Skipping email rollback staging due to blank email.');
      return;
    }
    final entry = _PendingAccountDeletion(
      username: username,
      host: host,
      password: password,
      email: normalizedEmail,
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
    _emit(const AuthenticationSignUpInProgress(fromSubmission: false));
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
          _emit(const AuthenticationSignupFailure(
              'Hackers have already found this password so it is insecure. '
              'Use a different one or allow insecure passwords.'));
          return false;
        }
      }
    } on Exception catch (_) {
      _emit(const AuthenticationNone());
      return true;
    }
    _emit(const AuthenticationNone());
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
        await _credentialStore.delete(key: passwordPreHashedStorageKey);
      case LogoutSeverity.burn:
        await _credentialStore.deleteAll(burn: true);
        await _xmppService.burn();
    }

    await _xmppService.disconnect();
    if (_endpointConfig.enableSmtp) {
      if (severity == LogoutSeverity.burn) {
        await _emailService?.burn(jid: currentJid);
      } else {
        await _emailService?.shutdown(
          jid: currentJid,
          clearCredentials: severity == LogoutSeverity.normal,
        );
      }
    }

    _authenticatedJid = null;
    _demoSessionReady = false;
    _emit(const AuthenticationNone());
    _updateEmailForegroundKeepalive();
  }

  Future<void> changePassword({
    required String username,
    required String host,
    required String oldPassword,
    required String password,
    required String password2,
  }) async {
    if (password != password2) {
      _emit(const AuthenticationPasswordChangeFailure(
        'New passwords do not match.',
      ));
      return;
    }
    _emit(const AuthenticationPasswordChangeInProgress());
    final normalizedUsername = username.trim();
    final configuredHost = _endpointConfig.domain.trim();
    final resolvedHost = configuredHost.isEmpty ? host.trim() : configuredHost;
    if (normalizedUsername.isEmpty || resolvedHost.isEmpty) {
      _emit(const AuthenticationPasswordChangeFailure(
        'Unable to change password. Please try again later.',
      ));
      return;
    }
    final uri = _buildChangePasswordUrl();
    final resolvedJid = '$normalizedUsername@$resolvedHost';
    final shouldChangeEmailPassword =
        _emailService != null && _endpointConfig.enableSmtp;
    final resolvedEmail = shouldChangeEmailPassword
        ? await _resolveEmailAddress(
            username: normalizedUsername,
            host: resolvedHost,
          )
        : null;
    try {
      final response = await _httpClient.post(
        uri,
        body: {
          'username': normalizedUsername,
          'host': resolvedHost,
          'password': password,
          'password2': password2,
          'oldpassword': oldPassword,
        },
      );
      if (response.statusCode == 200) {
        if (shouldChangeEmailPassword && resolvedEmail != null) {
          final emailError = await _changeProvisionedEmailPassword(
            email: resolvedEmail,
            oldPassword: oldPassword,
            newPassword: password,
          );
          if (emailError != null) {
            final rollbackSucceeded = await _attemptXmppPasswordRollback(
              username: normalizedUsername,
              host: resolvedHost,
              oldPassword: oldPassword,
              newPassword: password,
            );
            _log.warning(
              'Email password change failed; xmpp rollback '
              '${rollbackSucceeded ? 'succeeded' : 'failed'}.',
            );
            _emit(AuthenticationPasswordChangeFailure(emailError));
            return;
          }
        }
        await _updateStoredPasswords(
          jid: resolvedJid,
          newPassword: password,
        );
        _emit(const AuthenticationPasswordChangeSuccess(
          'Password changed successfully.',
        ));
        return;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        _emit(const AuthenticationPasswordChangeFailure(
          'Current password is incorrect.',
        ));
        return;
      }
      if (response.statusCode == 404) {
        _emit(const AuthenticationPasswordChangeFailure(
          'Account not found.',
        ));
        return;
      }
      const fallback = 'Unable to change password. Please try again later.';
      final responseBody = response.body.trim();
      _emit(AuthenticationPasswordChangeFailure(
        responseBody.isEmpty ? fallback : responseBody,
      ));
      _log.warning(
        'Password change failed (${response.statusCode}) '
        '${responseBody.isEmpty ? '' : responseBody}',
      );
    } on Exception catch (error, stackTrace) {
      _log.warning('Password change failed', error, stackTrace);
      _emit(const AuthenticationPasswordChangeFailure(
        'Unable to change password. Please try again later.',
      ));
    }
  }

  Future<String?> _changeProvisionedEmailPassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _emailProvisioningClient.changePassword(
        email: email,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      return null;
    } on provisioning.EmailProvisioningApiException catch (error, stackTrace) {
      _log.warning('Email password change failed', error, stackTrace);
      if (error.code == provisioning.EmailProvisioningApiErrorCode.notFound) {
        return 'Account not found.';
      }
      if (error.code ==
          provisioning.EmailProvisioningApiErrorCode.authenticationFailed) {
        return 'Current password is incorrect.';
      }
      return error.message;
    } on Exception catch (error, stackTrace) {
      _log.warning('Email password change failed', error, stackTrace);
      return 'Unable to change password. Please try again later.';
    }
  }

  Future<bool> _attemptXmppPasswordRollback({
    required String username,
    required String host,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _httpClient.post(
        _buildChangePasswordUrl(),
        body: {
          'username': username,
          'host': host,
          'password': oldPassword,
          'password2': oldPassword,
          'oldpassword': newPassword,
        },
      );
      return response.statusCode == 200;
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to rollback xmpp password', error, stackTrace);
      return false;
    }
  }

  Future<http.Response?> _requestAccountDeletion({
    required String username,
    required String host,
    required String password,
    required String logContext,
  }) async {
    try {
      return await _httpClient.post(
        _buildDeleteAccountUrl(),
        body: {
          'username': username,
          'host': host,
          'password': password,
        },
      );
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to delete account $logContext', error, stackTrace);
      return null;
    }
  }

  Future<void> unregister({
    required String username,
    required String host,
    required String password,
  }) async {
    _emit(const AuthenticationUnregisterInProgress());
    final normalizedUsername = username.trim();
    final configuredHost = _endpointConfig.domain.trim();
    final resolvedHost = configuredHost.isEmpty ? host.trim() : configuredHost;
    if (normalizedUsername.isEmpty || resolvedHost.isEmpty) {
      _emit(const AuthenticationUnregisterFailure(
        'Unable to delete account right now. Please try again later.',
      ));
      return;
    }
    const fallback = 'Unable to delete account. Please try again later.';
    try {
      final email = await _resolveEmailAddress(
        username: normalizedUsername,
        host: resolvedHost,
      );
      final emailDeleted = await _deleteProvisionedEmailAccount(
        email: email ?? '$normalizedUsername@$resolvedHost',
        password: password,
        logContext: 'during unregister',
      );
      if (!emailDeleted) {
        _emit(const AuthenticationUnregisterFailure(fallback));
        return;
      }
      final response = await _requestAccountDeletion(
        username: normalizedUsername,
        host: resolvedHost,
        password: password,
        logContext: 'during unregister',
      );
      if (response == null) {
        _emit(const AuthenticationUnregisterFailure(fallback));
        return;
      }
      if (response.statusCode == 200 || response.statusCode == 404) {
        await logout(severity: LogoutSeverity.burn);
        await _removeCompletedAccountRecord(normalizedUsername, resolvedHost);
        return;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        _emit(const AuthenticationUnregisterFailure(
          'Incorrect password. Please try again.',
        ));
        return;
      }
      final responseBody = response.body.trim();
      _emit(AuthenticationUnregisterFailure(
        responseBody.isEmpty ? fallback : responseBody,
      ));
      _log.warning(
        'Account deletion failed (${response.statusCode}) '
        '${responseBody.isEmpty ? '' : responseBody}',
      );
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to delete account', error, stackTrace);
      _emit(const AuthenticationUnregisterFailure(
        'Unable to delete account. Please try again later.',
      ));
    }
  }

  Future<String?> _resolveEmailAddress({
    required String username,
    required String host,
  }) async {
    final emailService = _emailService;
    final jid = '$username@$host';
    if (emailService != null) {
      try {
        final account = await emailService.currentAccount(jid);
        final email = account?.address.trim();
        if (email != null && email.isNotEmpty) {
          return email;
        }
      } on Exception catch (error, stackTrace) {
        _log.finer('Failed to resolve stored email address', error, stackTrace);
      }
    }
    final normalized = jid.trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _updateStoredPasswords({
    required String jid,
    required String newPassword,
  }) async {
    try {
      await _credentialStore.write(
        key: passwordStorageKey,
        value: newPassword,
      );
      await _credentialStore.write(
        key: passwordPreHashedStorageKey,
        value: false.toString(),
      );
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to persist updated password', error, stackTrace);
    }
    final emailService = _emailService;
    if (emailService == null) {
      return;
    }
    try {
      final displayName = jid.split('@').first;
      await emailService.updatePassword(
        jid: jid,
        displayName: displayName,
        password: newPassword,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to refresh email credentials after password change',
        error,
        stackTrace,
      );
    }
  }

  void _updateEmailForegroundKeepalive() {
    final emailService = _emailService;
    if (emailService == null) return;
    final shouldRun = _endpointConfig.enableSmtp &&
        foregroundServiceActive.value &&
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

  Future<bool> _deleteProvisionedEmailAccount({
    required String email,
    required String password,
    required String logContext,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      return true;
    }
    try {
      await _emailProvisioningClient.deleteAccount(
        email: normalizedEmail,
        password: password,
      );
      return true;
    } on provisioning.EmailProvisioningApiException catch (error, stackTrace) {
      _log.warning(
        'Email account deletion failed $logContext',
        error,
        stackTrace,
      );
      if (error.code == provisioning.EmailProvisioningApiErrorCode.notFound) {
        return true;
      }
      return !error.isRecoverable;
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Email account deletion failed $logContext',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<bool> _deleteProvisionedEmailAccountIfAvailable(
    _PendingAccountDeletion deletion,
  ) async {
    final fallbackEmail =
        deletion.email ?? '${deletion.username}@${deletion.host}'.trim();
    return _deleteProvisionedEmailAccount(
      email: fallbackEmail,
      password: deletion.password,
      logContext: 'during rollback',
    );
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
        final activeKey = _activeSignupCredentialKey;
        if (activeKey != null && request.matchesKey(activeKey)) {
          remaining.add(request);
          continue;
        }
        final normalizedKey =
            _normalizeSignupKey(request.username, request.host);
        if (await _hasCompletedAuthentication(normalizedKey)) {
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
    final filtered = <_PendingAccountDeletion>[];
    for (final entry in pending) {
      final normalizedEntryKey =
          _normalizeSignupKey(entry.username, entry.host);
      if (await _hasCompletedAuthentication(normalizedEntryKey)) {
        continue;
      }
      filtered.add(entry);
    }
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
    final emailDeleted = await _deleteProvisionedEmailAccountIfAvailable(
      deletion,
    );
    if (!emailDeleted) {
      return false;
    }
    final response = await _requestAccountDeletion(
      username: deletion.username,
      host: deletion.host,
      password: deletion.password,
      logContext: 'during rollback',
    );
    if (response == null) {
      return false;
    }
    if (response.statusCode == 200 || response.statusCode == 404) {
      return true;
    }
    _log.warning(
      'Signup rollback delete failed (${response.statusCode}) '
      '${response.body.trim()}',
    );
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

  Future<void> _upsertPendingAccountDeletion(
    _PendingAccountDeletion deletion,
  ) async {
    final pending = await _readPendingAccountDeletions();
    _PendingAccountDeletion? existing;
    final filtered = <_PendingAccountDeletion>[];
    for (final entry in pending) {
      if (entry.matches(deletion) && existing == null) {
        existing = entry;
        continue;
      }
      if (!entry.matches(deletion)) {
        filtered.add(entry);
      }
    }
    final normalized = existing == null
        ? deletion
        : deletion.copyWith(createdAt: existing.createdAt);
    filtered.add(normalized);
    await _writePendingAccountDeletions(filtered);
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
    try {
      await _credentialStore.delete(key: completedSignupAccountsKey);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to clear legacy completed authentication record',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _removeCompletedAccountRecord(
    String username,
    String host,
  ) async {
    try {
      await _credentialStore.delete(key: completedSignupAccountsKey);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to clear legacy completed authentication record',
        error,
        stackTrace,
      );
    }
  }

  Future<bool> _hasCompletedAuthentication(String normalizedKey) async {
    try {
      final secrets = await _readDatabaseSecrets(normalizedKey);
      return secrets.hasSecrets;
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to check database secrets for $normalizedKey',
        error,
        stackTrace,
      );
      return false;
    }
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
      _emit(const AuthenticationNone());
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

enum _CredentialDisposition {
  keep,
  wipeLoginCredentials;

  bool get shouldWipe => this == _CredentialDisposition.wipeLoginCredentials;
}

enum _ProvisioningStatus {
  ready,
  pendingRecoverable,
  blockedTransient,
  blockedFatal;

  bool get shouldAbort =>
      this == _ProvisioningStatus.blockedTransient ||
      this == _ProvisioningStatus.blockedFatal;

  bool get shouldWipeCredentials => this == _ProvisioningStatus.blockedFatal;
}

enum _ResumeResult {
  resumed,
  blockedTransient,
  blockedFatal;

  bool get isResumed => this == _ResumeResult.resumed;

  bool get shouldWipeCredentials => this == _ResumeResult.blockedFatal;
}

class _StoredLoginCredentials {
  const _StoredLoginCredentials({
    this.jid,
    this.password,
    this.passwordPreHashed,
  });

  final String? jid;
  final String? password;
  final bool? passwordPreHashed;

  bool get hasUsableCredentials =>
      jid != null && password != null && passwordPreHashed != null;

  bool get hasPreHashedFlag => passwordPreHashed != null;

  bool matches(String candidateJid) =>
      hasUsableCredentials && jid == candidateJid;
}

class _DatabaseSecrets {
  const _DatabaseSecrets({
    required this.prefixKey,
    this.prefix,
    this.passphraseKey,
    this.passphrase,
  });

  final RegisteredCredentialKey prefixKey;
  final RegisteredCredentialKey? passphraseKey;
  final String? prefix;
  final String? passphrase;

  bool get hasSecrets => prefix != null && passphrase != null;
}

class _AuthTransaction {
  const _AuthTransaction({
    required this.jid,
    required this.clearCredentialsOnFailure,
    this.xmppConnected = false,
    this.smtpProvisioned = false,
    this.committed = false,
  });

  factory _AuthTransaction.fromJson(Map<String, dynamic> json) {
    bool asBool(Object? value) {
      if (value is bool) {
        return value;
      }
      if (value is String) {
        return value.toLowerCase().trim() == true.toString();
      }
      if (value is num) {
        return value != 0;
      }
      return false;
    }

    return _AuthTransaction(
      jid: (json['jid'] as String? ?? '').trim(),
      clearCredentialsOnFailure: asBool(
        json['clearCredentialsOnFailure'] ??
            json['clearEmailCredentialsOnFailure'],
      ),
      xmppConnected: asBool(json['xmppConnected']),
      smtpProvisioned: asBool(json['smtpProvisioned']),
      committed: asBool(json['committed']),
    );
  }

  final String jid;
  final bool xmppConnected;
  final bool smtpProvisioned;
  final bool committed;
  final bool clearCredentialsOnFailure;

  Map<String, dynamic> toJson() => {
        'jid': jid,
        'xmppConnected': xmppConnected,
        'smtpProvisioned': smtpProvisioned,
        'committed': committed,
        'clearCredentialsOnFailure': clearCredentialsOnFailure,
      };

  _AuthTransaction copyWith({
    bool? xmppConnected,
    bool? smtpProvisioned,
    bool? committed,
    bool? clearCredentialsOnFailure,
  }) {
    return _AuthTransaction(
      jid: jid,
      xmppConnected: xmppConnected ?? this.xmppConnected,
      smtpProvisioned: smtpProvisioned ?? this.smtpProvisioned,
      committed: committed ?? this.committed,
      clearCredentialsOnFailure:
          clearCredentialsOnFailure ?? this.clearCredentialsOnFailure,
    );
  }
}

class _PendingAccountDeletion {
  _PendingAccountDeletion({
    required String username,
    required String host,
    required this.password,
    this.email,
    String? createdAt,
  })  : username = username.trim().toLowerCase(),
        host = host.trim().toLowerCase(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  factory _PendingAccountDeletion.fromJson(Map<String, dynamic> json) {
    final rawEmail = (json['email'] ?? json['chatmailEmail']) as String? ?? '';
    return _PendingAccountDeletion(
      username: (json['username'] as String? ?? '').trim(),
      host: (json['host'] as String? ?? AuthenticationCubit.domain).trim(),
      password: json['password'] as String? ?? '',
      email: rawEmail.trim().isEmpty ? null : rawEmail.trim(),
      createdAt: json['createdAt'] as String?,
    );
  }

  final String username;
  final String host;
  final String password;
  final String? email;
  final String createdAt;

  Map<String, dynamic> toJson() => {
        'username': username,
        'host': host,
        'password': password,
        'createdAt': createdAt,
        if (email != null) 'email': email,
      };

  _PendingAccountDeletion copyWith({
    String? password,
    String? email,
    String? createdAt,
  }) {
    return _PendingAccountDeletion(
      username: username,
      host: host,
      password: password ?? this.password,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool matches(_PendingAccountDeletion other) =>
      matchesCredentials(other.username, other.host);

  bool matchesCredentials(String username, String host) =>
      this.username == username.trim().toLowerCase() &&
      this.host == host.trim().toLowerCase();

  bool matchesKey(String key) => '$username@$host' == key.trim().toLowerCase();
}
