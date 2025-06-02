import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:axichat/main.dart';
import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
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
    NotificationService? notificationService,
    http.Client? httpClient,
    AuthenticationState? initialState,
  })  : _credentialStore = credentialStore,
        _xmppService = xmppService,
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
          final appLaunchDetails =
              await notificationService?.getAppNotificationAppLaunchDetails();
          if (appLaunchDetails?.notificationResponse?.payload
              case final chatJid?) {
            xmppService.openChat(chatJid);
          }
        }

        await _xmppService.setClientState(
            lifeCycleState == AppLifecycleState.resumed ||
                lifeCycleState == AppLifecycleState.inactive);
      },
    );
  }

  final _log = Logger('AuthenticationCubit');

  static const String domain = 'axi.im';
  static Uri baseUrl = Uri.parse('https://$domain:5443');
  static Uri registrationUrl = Uri.parse('$baseUrl/register/new/');

  final jidStorageKey = CredentialStore.registerKey('jid');
  final passwordStorageKey = CredentialStore.registerKey('password');

  final CredentialStore _credentialStore;
  final XmppService _xmppService;
  final http.Client _httpClient;

  late final AppLifecycleListener _lifecycleListener;

  @override
  Future<void> close() async {
    _lifecycleListener.dispose();
    await _credentialStore.close();
    return super.close();
  }

  Future<void> login({
    String? username,
    String? password,
    bool rememberMe = false,
  }) async {
    if (state is AuthenticationComplete) {
      return;
    }
    emit(const AuthenticationInProgress());

    if ((username == null) != (password == null)) {
      emit(const AuthenticationFailure(
          'Username and password have different nullness.'));
      return;
    }

    late final String? jid;
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
    final databasePrefix =
        await _credentialStore.read(key: databasePrefixStorageKey) ??
            generateRandomString(length: 8);

    final databasePassphraseStorageKey = CredentialStore.registerKey(
      '${databasePrefix}_database_passphrase',
    );
    final databasePassphrase =
        await _credentialStore.read(key: databasePassphraseStorageKey) ??
            generateRandomString();

    final savedPassword = await _credentialStore.read(key: passwordStorageKey);
    final preHashed = savedPassword != null;

    try {
      password = await _xmppService.connect(
        jid: jid,
        password: preHashed ? savedPassword : password,
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

    emit(const AuthenticationComplete());
  }

  Future<void> signup({
    required String username,
    required String password,
    required String confirmPassword,
    required String captchaID,
    required String captcha,
    required bool rememberMe,
  }) async {
    emit(const AuthenticationInProgress());
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
  }

  Future<bool> checkNotPwned({required String password}) async {
    emit(const AuthenticationInProgress());
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
              'Hackers have already found this password, so it is insecure. '
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

    emit(const AuthenticationNone());
  }
}
