import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:axichat/main.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/email/service/chatmail_provisioning_client.dart'
    as provisioning;
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

  static const String domain = EndpointConfig.defaultDomain;
  static const String signupCleanupInProgressMessage =
      'Cleaning up your previous signup attempt. We will retry the removal as soon as you are back online—try again once it finishes.';

  Uri get registrationUrl => _buildRegistrationUrl();
  Uri get changePasswordUrl => _buildChangePasswordUrl();
  Uri get deleteAccountUrl => _buildDeleteAccountUrl();

  final jidStorageKey = CredentialStore.registerKey('jid');
  final passwordStorageKey = CredentialStore.registerKey('password');
  final passwordPreHashedStorageKey =
      CredentialStore.registerKey('password_prehashed_v1');
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
  VoidCallback? _foregroundListener;
  Future<void>? _pendingAccountDeletionFlush;
  String? _blockedSignupCredentialKey;
  String? _activeSignupCredentialKey;
  bool get _stickyAuthActive => state is AuthenticationComplete;

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
      _buildBaseUrl().replace(path: '/register/change_password/');

  Uri _buildDeleteAccountUrl() =>
      _buildBaseUrl().replace(path: '/register/delete/');

  void _emit(AuthenticationState state) {
    // Always allow transitions away from an authenticated session (e.g. logout).
    emit(state.copyWithConfig(_endpointConfig));
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
    _lastEmailProvisioningError = null;
    if (state is AuthenticationComplete && _xmppService.connected) {
      return;
    }
    if (state is AuthenticationLogInInProgress) {
      _log.fine('Ignoring login request while another is in progress.');
      return;
    }
    final config = _endpointConfig;
    final xmppEnabled = config.enableXmpp;
    final smtpEnabled = config.enableSmtp;
    if (!xmppEnabled && !smtpEnabled) {
      _emit(const AuthenticationFailure(
        'Enable XMPP or SMTP to continue.',
      ));
      return;
    }
    final loginState = _activeSignupCredentialKey != null
        ? AuthenticationLogInInProgress(fromSignup: true, config: config)
        : AuthenticationLogInInProgress(config: config);

    if ((username == null) != (password == null)) {
      _emit(const AuthenticationFailure(
          'Username and password have different nullness.'));
      return;
    }
    if (!rememberMe) {
      _log.fine('rememberMe flag ignored; credentials are always persisted.');
    }

    final bool usingStoredCredentials = username == null;
    late final String? jid;
    var emailPassword = emailCredentials?.password ?? password;
    if (username == null || password == null) {
      jid = await _credentialStore.read(key: jidStorageKey);
      password = await _credentialStore.read(key: passwordStorageKey);
    } else {
      jid = '$username@${config.domain}';
    }

    if (jid == null || password == null) {
      _emit(const AuthenticationNone());
      return;
    }
    final String resolvedJid = jid;
    final String resolvedPassword = password;
    final String displayName = resolvedJid.split('@').first;
    final hasCompletedAuthentication =
        await _hasCompletedAuthentication(_normalizeJid(resolvedJid));
    final bool stickySession = hasCompletedAuthentication ||
        _stickyAuthActive ||
        _authenticatedJid != null;
    final bool stickyAuthActive = _stickyAuthActive;
    final bool isAutoReauth = stickySession && usingStoredCredentials;
    if (isAutoReauth) {
      _log.fine('Attempting silent session re-authentication.');
    } else {
      _emit(loginState);
    }
    _authenticatedJid ??= resolvedJid;

    final databasePrefixStorageKey =
        CredentialStore.registerKey('${jid}_database_prefix');

    String? databasePrefix =
        await _credentialStore.read(key: databasePrefixStorageKey);
    final bool hadStoredDatabasePrefix = databasePrefix != null;
    databasePrefix ??= generateRandomString(length: 8);

    final databasePassphraseStorageKey = CredentialStore.registerKey(
      '${databasePrefix}_database_passphrase',
    );

    String? databasePassphrase =
        await _credentialStore.read(key: databasePassphraseStorageKey);
    final bool hadStoredDatabasePassphrase = databasePassphrase != null;
    databasePassphrase ??= generateRandomString();
    final hasStoredDatabaseSecrets =
        hadStoredDatabasePassphrase && hadStoredDatabasePrefix;
    final String ensuredDatabasePrefix = databasePrefix;
    final String ensuredDatabasePassphrase = databasePassphrase;

    final savedPassword = await _credentialStore.read(key: passwordStorageKey);
    final savedPasswordPreHashedValue =
        await _credentialStore.read(key: passwordPreHashedStorageKey);
    final bool? savedPasswordPreHashed = savedPasswordPreHashedValue == null
        ? null
        : savedPasswordPreHashedValue == true.toString();
    final bool shouldClearEmailCredentialsOnFailure = !usingStoredCredentials;
    const bool shouldPersistCredentials = true;
    bool passwordPreHashed =
        usingStoredCredentials ? (savedPasswordPreHashed ?? false) : false;
    if (usingStoredCredentials &&
        savedPassword != null &&
        savedPasswordPreHashed == null) {
      _emit(const AuthenticationFailure(
        'Stored credentials are outdated. Please log in manually.',
      ));
      await _xmppService.disconnect();
      _authenticatedJid = null;
      return;
    }
    final String xmppPassword = usingStoredCredentials
        ? (savedPassword ?? resolvedPassword)
        : resolvedPassword;

    final emailService = smtpEnabled ? _emailService : null;
    if (emailPassword == null && emailService != null) {
      final existing = await emailService.currentAccount(resolvedJid);
      emailPassword = existing?.password;
    }

    if (emailService != null && emailPassword == null) {
      if (stickyAuthActive) {
        _log.warning(
            'Stored email password missing during silent re-authentication.');
        return;
      }
      _emit(const AuthenticationFailure(
          'Stored email password missing. Please log in manually.'));
      return;
    }

    final enforceEmailProvisioning = requireEmailProvisioned ||
        _activeSignupCredentialKey != null ||
        emailService != null;

    final reuseExistingSession =
        _xmppService.databasesInitialized && _xmppService.myJid == resolvedJid;

    EndpointOverride? xmppEndpoint;
    if (xmppEnabled) {
      try {
        xmppEndpoint = await _endpointResolver.resolveXmpp(
          config,
          fallback: _overrideFrom(serverLookup[config.domain]),
        );
      } on EndpointResolutionException catch (error) {
        _emit(AuthenticationFailure(error.message, config: config));
        return;
      }
    }

    if (xmppEnabled) {
      try {
        password = await _xmppService.connect(
          jid: resolvedJid,
          password: xmppPassword,
          databasePrefix: databasePrefix,
          databasePassphrase: databasePassphrase,
          preHashed: passwordPreHashed,
          reuseExistingSession: reuseExistingSession,
          endpoint: xmppEndpoint,
        );
        passwordPreHashed = true;
      } on XmppAuthenticationException catch (_) {
        final canResumeOffline =
            usingStoredCredentials && hasStoredDatabaseSecrets;
        if (canResumeOffline) {
          final resumed = await _resumeOfflineLogin(
            jid: resolvedJid,
            displayName: displayName,
            databasePrefix: ensuredDatabasePrefix,
            databasePassphrase: ensuredDatabasePassphrase,
            rememberMe: shouldPersistCredentials,
            password: password,
            passwordPreHashed: passwordPreHashed,
            emailPassword: emailPassword,
            emailCredentials: emailCredentials,
            enforceEmailProvisioning: enforceEmailProvisioning,
            clearEmailCredentials: shouldClearEmailCredentialsOnFailure,
            databasePrefixStorageKey: databasePrefixStorageKey,
            databasePassphraseStorageKey: databasePassphraseStorageKey,
          );
          if (resumed) {
            return;
          }
        }
        _emit(const AuthenticationFailure('Incorrect username or password'));
        await _xmppService.disconnect();
        _authenticatedJid = null;
        return;
      } on XmppNetworkException catch (error) {
        final canResumeOffline = usingStoredCredentials &&
            hasStoredDatabaseSecrets &&
            hasCompletedAuthentication;
        if (canResumeOffline) {
          final resumed = await _resumeOfflineLogin(
            jid: resolvedJid,
            displayName: displayName,
            databasePrefix: ensuredDatabasePrefix,
            databasePassphrase: ensuredDatabasePassphrase,
            rememberMe: shouldPersistCredentials,
            password: password,
            passwordPreHashed: passwordPreHashed,
            emailPassword: emailPassword,
            emailCredentials: emailCredentials,
            enforceEmailProvisioning: enforceEmailProvisioning,
            clearEmailCredentials: shouldClearEmailCredentialsOnFailure,
            databasePrefixStorageKey: databasePrefixStorageKey,
            databasePassphraseStorageKey: databasePassphraseStorageKey,
          );
          if (resumed) {
            return;
          }
        }
        _log.warning('Network/XMPP error during login', error);
        _emit(const AuthenticationFailure('Error. Please try again later.'));
        await _xmppService.disconnect();
        _authenticatedJid = null;
        return;
      } on XmppAlreadyConnectedException catch (_) {
        _log.fine('Re-auth attempted while already connected, ignoring.');
        return;
      } on Exception catch (error) {
        final canResumeOffline = usingStoredCredentials &&
            hasStoredDatabaseSecrets &&
            hasCompletedAuthentication &&
            _looksLikeConnectivityError(error);
        if (canResumeOffline) {
          final resumed = await _resumeOfflineLogin(
            jid: resolvedJid,
            displayName: displayName,
            databasePrefix: ensuredDatabasePrefix,
            databasePassphrase: ensuredDatabasePassphrase,
            rememberMe: shouldPersistCredentials,
            password: password,
            passwordPreHashed: passwordPreHashed,
            emailPassword: emailPassword,
            emailCredentials: emailCredentials,
            enforceEmailProvisioning: enforceEmailProvisioning,
            clearEmailCredentials: shouldClearEmailCredentialsOnFailure,
            databasePrefixStorageKey: databasePrefixStorageKey,
            databasePassphraseStorageKey: databasePassphraseStorageKey,
          );
          if (resumed) {
            return;
          }
        }
        _log.severe(error);
        _emit(const AuthenticationFailure('Error. Please try again later.'));
        await _xmppService.disconnect();
        _authenticatedJid = null;
        return;
      }
    } else {
      await _xmppService.resumeOfflineSession(
        jid: resolvedJid,
        databasePrefix: ensuredDatabasePrefix,
        databasePassphrase: ensuredDatabasePassphrase,
      );
      password = resolvedPassword;
    }

    final emailReady = await _ensureEmailProvisioned(
      displayName: displayName,
      databasePrefix: ensuredDatabasePrefix,
      databasePassphrase: ensuredDatabasePassphrase,
      jid: resolvedJid,
      enforceProvisioning: enforceEmailProvisioning,
      clearCredentialsOnFailure: shouldClearEmailCredentialsOnFailure,
      emailPassword: emailPassword,
      emailCredentials: emailCredentials,
    );
    if (!emailReady) {
      await _xmppService.disconnect();
      if (!stickyAuthActive) {
        _authenticatedJid = null;
      }
      return;
    }

    await _finalizeAuthentication(
      jid: resolvedJid,
      rememberMe: shouldPersistCredentials,
      password: password,
      passwordPreHashed: passwordPreHashed,
      databasePrefixStorageKey: databasePrefixStorageKey,
      databasePrefix: ensuredDatabasePrefix,
      databasePassphraseStorageKey: databasePassphraseStorageKey,
      databasePassphrase: ensuredDatabasePassphrase,
    );
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

  Future<bool> _resumeOfflineLogin({
    required String jid,
    required String displayName,
    required String databasePrefix,
    required String databasePassphrase,
    required bool rememberMe,
    required bool enforceEmailProvisioning,
    required bool clearEmailCredentials,
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
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to resume offline session', error, stackTrace);
      return false;
    }

    final emailReady = await _ensureEmailProvisioned(
      displayName: displayName,
      databasePrefix: databasePrefix,
      databasePassphrase: databasePassphrase,
      jid: jid,
      enforceProvisioning: enforceEmailProvisioning,
      clearCredentialsOnFailure: clearEmailCredentials,
      emailPassword: emailPassword,
      emailCredentials: emailCredentials,
    );
    if (!emailReady) {
      await _xmppService.disconnect();
      return false;
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
    return true;
  }

  Future<bool> _ensureEmailProvisioned({
    required String displayName,
    required String databasePrefix,
    required String databasePassphrase,
    required String jid,
    required bool enforceProvisioning,
    required bool clearCredentialsOnFailure,
    String? emailPassword,
    provisioning.EmailProvisioningCredentials? emailCredentials,
  }) async {
    if (!_endpointConfig.enableSmtp) {
      return true;
    }
    final emailService = _emailService;
    if (emailService == null) {
      return true;
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
      return false;
    }
    try {
      await emailService.ensureProvisioned(
        displayName: displayName,
        databasePrefix: databasePrefix,
        databasePassphrase: databasePassphrase,
        jid: jid,
        passwordOverride: resolvedPassword,
        addressOverride: emailCredentials?.email,
        principalIdOverride: emailCredentials?.principalId,
      );
      _lastEmailProvisioningError = null;
      return true;
    } on EmailProvisioningException catch (error) {
      final shouldAbort = enforceProvisioning || !error.isRecoverable;
      if (shouldAbort) {
        _lastEmailProvisioningError = error;
        if (!_stickyAuthActive) {
          _emit(AuthenticationFailure(error.message));
        } else {
          _log.warning('Email provisioning failed silently: ${error.message}');
        }
        await _cancelPendingEmailProvisioning(
          null,
          jid,
          clearCredentials: clearCredentialsOnFailure,
        );
        await _xmppService.disconnect();
        return false;
      }
      _log.warning('Email provisioning pending: ${error.message}');
      _lastEmailProvisioningError = null;
      return true;
    } on Exception catch (error, stackTrace) {
      _log.warning('Email provisioning failed', error, stackTrace);
      if (enforceProvisioning) {
        if (!_stickyAuthActive) {
          _emit(const AuthenticationFailure('Error. Please try again later.'));
        } else {
          _log.warning('Silent re-auth email provisioning deferred.');
        }
        await _cancelPendingEmailProvisioning(
          null,
          jid,
          clearCredentials: clearCredentialsOnFailure,
        );
        await _xmppService.disconnect();
        return false;
      }
      return true;
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
    _updateEmailForegroundKeepalive();
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
    if (!rememberMe) {
      _log.fine('Persisting credentials despite rememberMe=false request.');
    }
    await _credentialStore.write(key: jidStorageKey, value: jid);
    if (password != null) {
      await _credentialStore.write(key: passwordStorageKey, value: password);
      await _credentialStore.write(
        key: passwordPreHashedStorageKey,
        value: passwordPreHashed.toString(),
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

  Future<void> signup({
    required String username,
    required String password,
    required String confirmPassword,
    required String captchaID,
    required String captcha,
    required bool rememberMe,
  }) async {
    _emit(const AuthenticationSignUpInProgress());
    final host = _endpointConfig.domain;
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
      principalId: credentials.principalId,
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
    _emit(const AuthenticationPasswordChangeInProgress());
    final response = await http.post(
      changePasswordUrl,
      body: {
        'username': username,
        'host': host,
        'passwordold': oldPassword,
        'password': password,
        'password2': password2,
      },
    );
    if (response.statusCode == 200) {
      _emit(AuthenticationPasswordChangeSuccess(response.body));
    } else {
      _emit(AuthenticationPasswordChangeFailure(response.body));
    }
  }

  Future<void> unregister({
    required String username,
    required String host,
    required String password,
  }) async {
    _emit(const AuthenticationUnregisterInProgress());
    try {
      if (_endpointConfig.enableSmtp) {
        await _deleteProvisionedEmailAccountForUser(
          username: username,
          host: host,
          password: password,
        );
      }
      final response = await http.post(
        deleteAccountUrl,
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
        _emit(AuthenticationUnregisterFailure(response.body));
      }
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to delete account', error, stackTrace);
      _emit(const AuthenticationUnregisterFailure(
        'Unable to delete account. Please try again later.',
      ));
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

  Future<bool> _deleteProvisionedEmailAccountIfAvailable(
    _PendingAccountDeletion deletion,
  ) async {
    final email = deletion.email;
    final principalId = deletion.principalId;
    if (email == null || principalId == null) {
      return true;
    }
    try {
      await _emailProvisioningClient.deleteAccount(
        principalId: principalId,
        email: email,
        password: deletion.password,
      );
      return true;
    } on provisioning.EmailProvisioningApiException catch (error, stackTrace) {
      _log.warning(
        'Email account deletion failed during rollback',
        error,
        stackTrace,
      );
      return !error.isRecoverable;
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Email account deletion failed during rollback',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<void> _deleteProvisionedEmailAccountForUser({
    required String username,
    required String host,
    required String password,
  }) async {
    final emailService = _emailService;
    if (emailService == null) {
      return;
    }
    final jid = '$username@$host';
    final account = await emailService.currentAccount(jid);
    final principalId = account?.principalId;
    final email = account?.address;
    if (account == null || email == null || principalId == null) {
      _log.fine('Email account details missing; skipping provisioning delete.');
      return;
    }
    await _emailProvisioningClient.deleteAccount(
      principalId: principalId,
      email: email,
      password: password,
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
    final emailDeleted = await _deleteProvisionedEmailAccountIfAvailable(
      deletion,
    );
    if (!emailDeleted) {
      return false;
    }
    try {
      final response = await _httpClient.post(
        deleteAccountUrl,
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

class _PendingAccountDeletion {
  _PendingAccountDeletion({
    required String username,
    required String host,
    required this.password,
    this.email,
    this.principalId,
    String? createdAt,
  })  : username = username.trim().toLowerCase(),
        host = host.trim().toLowerCase(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  factory _PendingAccountDeletion.fromJson(Map<String, dynamic> json) {
    final rawPrincipal = json['principalId'] ?? json['chatmailPrincipalId'];
    int? principalId;
    if (rawPrincipal is num) {
      principalId = rawPrincipal.toInt();
    } else if (rawPrincipal is String) {
      principalId = int.tryParse(rawPrincipal.trim());
    }
    final rawEmail = (json['email'] ?? json['chatmailEmail']) as String? ?? '';
    return _PendingAccountDeletion(
      username: (json['username'] as String? ?? '').trim(),
      host: (json['host'] as String? ?? AuthenticationCubit.domain).trim(),
      password: json['password'] as String? ?? '',
      email: rawEmail.trim().isEmpty ? null : rawEmail.trim(),
      principalId: principalId,
      createdAt: json['createdAt'] as String?,
    );
  }

  final String username;
  final String host;
  final String password;
  final String? email;
  final int? principalId;
  final String createdAt;

  Map<String, dynamic> toJson() => {
        'username': username,
        'host': host,
        'password': password,
        'createdAt': createdAt,
        if (email != null) 'email': email,
        if (principalId != null) 'principalId': principalId,
      };

  _PendingAccountDeletion copyWith({
    String? password,
    String? email,
    int? principalId,
    String? createdAt,
  }) {
    return _PendingAccountDeletion(
      username: username,
      host: host,
      password: password ?? this.password,
      email: email ?? this.email,
      principalId: principalId ?? this.principalId,
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
