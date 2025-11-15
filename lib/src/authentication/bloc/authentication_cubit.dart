import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:axichat/main.dart';
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
  }

  final _log = Logger('AuthenticationCubit');

  static const String domain = 'axi.im';
  static Uri baseUrl = Uri.parse('https://$domain:5443');
  static Uri registrationUrl = Uri.parse('$baseUrl/register/new/');
  static Uri changePasswordUrl =
      Uri.parse('$baseUrl/register/change_password/');
  static Uri deleteAccountUrl = Uri.parse('$baseUrl/register/delete/');

  final jidStorageKey = CredentialStore.registerKey('jid');
  final passwordStorageKey = CredentialStore.registerKey('password');

  final CredentialStore _credentialStore;
  final XmppService _xmppService;
  final EmailService? _emailService;
  final http.Client _httpClient;
  String? _authenticatedJid;
  EmailProvisioningException? _lastEmailProvisioningError;
  StreamSubscription<ConnectionState>? _connectivitySubscription;
  VoidCallback? _foregroundListener;

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
    final bool usingStoredCredentials = username == null || password == null;
    final preHashed = usingStoredCredentials && savedPassword != null;
    final xmppPassword = preHashed ? savedPassword : password;

    if (xmppPassword == null) {
      emit(const AuthenticationFailure('Missing credentials.'));
      return;
    }

    final emailService = _emailService;
    if (emailPassword == null && jid != null && emailService != null) {
      final existing = await emailService.currentAccount(jid);
      emailPassword = existing?.password;
    }

    if (emailService != null && emailPassword == null) {
      emit(const AuthenticationFailure(
          'Stored email password missing. Please log in manually.'));
      return;
    }

    try {
      password = await _xmppService.connect(
        jid: jid,
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
      _lastEmailProvisioningError = error;
      emit(AuthenticationFailure(error.message));
      await _xmppService.disconnect();
      return;
    } on Exception catch (error, stackTrace) {
      _log.warning('Chatmail provisioning failed', error, stackTrace);
    }

    emit(const AuthenticationComplete());
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
    try {
      final response = await _httpClient.post(
        registrationUrl,
        body: {
          'username': username,
          'host': state.server,
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
          'Failed to register, try again later.'));
      return;
    }
    await login(username: username, password: password, rememberMe: rememberMe);
    if (_lastEmailProvisioningError != null) {
      await _rollbackSignup(
        username: username,
        host: state.server,
        password: password,
      );
    }
  }

  Future<void> _rollbackSignup({
    required String username,
    required String host,
    required String password,
  }) async {
    try {
      await _httpClient.post(
        AuthenticationCubit.deleteAccountUrl,
        body: {
          'username': username,
          'host': host,
          'password': password,
        },
      );
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to roll back signup after email provisioning error',
          error, stackTrace);
    } finally {
      _lastEmailProvisioningError = null;
    }
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
}
