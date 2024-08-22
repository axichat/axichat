import 'dart:async';
import 'dart:ui';

import 'package:bloc/bloc.dart';
import 'package:chat/src/storage/credential_store.dart';
import 'package:chat/src/storage/database.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  })  : _credentialStore = credentialStore,
        _xmppService = xmppService,
        super(AuthenticationNone()) {
    _lifecycleListener = AppLifecycleListener(
      onResume: login,
      onShow: login,
      onRestart: login,
      onDetach: logout,
      onExitRequested: () async {
        await logout();
        return AppExitResponse.exit;
      },
    );
  }

  static const defaultServer = 'xmpp.social';
  static Uri registrationUrl = Uri.parse('https://hookipa.net/register/new');

  final jidStorageKey = CredentialStore.registerKey('jid');
  final passwordStorageKey = CredentialStore.registerKey('password');

  final CredentialStore _credentialStore;
  final XmppService _xmppService;

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
    String domain = defaultServer,
    bool rememberMe = false,
  }) async {
    if (state is AuthenticationComplete) return;
    emit(AuthenticationInProgress());

    assert((username == null) == (password == null));

    late final String? jid;
    if (username == null || password == null) {
      jid = await _credentialStore.read(key: jidStorageKey);
      password = await _credentialStore.read(key: passwordStorageKey);
    } else {
      jid = '$username@$domain';
    }

    if (jid == null || password == null) {
      emit(AuthenticationNone());
      return;
    }

    final prefix = storagePrefixFor(jid);

    final resourceStorageKey = CredentialStore.registerKey(
      '${prefix}_resource',
    );
    var resource = await _credentialStore.read(key: resourceStorageKey) ??
        XmppService.generateResource();

    final databasePassphraseStorageKey = CredentialStore.registerKey(
      '${prefix}_database_passphrase',
    );
    var databasePassphrase = await _credentialStore.read(
      key: databasePassphraseStorageKey,
    );

    if (databasePassphrase == null) {
      databasePassphrase = generateRandomString();
      try {
        await _xmppService.connect(
          jid: jid,
          resource: resource,
          password: password,
          databasePassphrase: databasePassphrase,
        );
      } on XmppAuthenticationException catch (_) {
        emit(const AuthenticationFailure('Incorrect username or password'));
        return;
      } on Exception catch (_) {
        emit(const AuthenticationFailure('Error. Please try again later.'));
        return;
      }

      await _credentialStore.write(
        key: databasePassphraseStorageKey,
        value: databasePassphrase,
      );
    } else {
      if (await _credentialStore.read(key: passwordStorageKey)
          case final savedPassword?) {
        if (password != savedPassword) {
          emit(const AuthenticationFailure('Incorrect username or password'));
          return;
        }
      }
      try {
        await _xmppService.connect(
          jid: jid,
          resource: resource,
          password: password,
          databasePassphrase: databasePassphrase,
          awaitAuthentication: false,
        );
      } on Exception catch (_) {
        // If user has logged in before they should be able to enter the app
        // and see their stored messages even if the server is unavailable.
      }
    }

    await _credentialStore.write(
      key: resourceStorageKey,
      value: _xmppService.resource,
    );

    if (rememberMe) {
      await _credentialStore.write(key: jidStorageKey, value: jid);
      await _credentialStore.write(key: passwordStorageKey, value: password);
    }

    emit(AuthenticationComplete());
  }

  Future<void> signup({
    required String username,
    required String password,
    required String confirmPassword,
    required String captchaID,
    required String captcha,
    required bool rememberMe,
    required bool agreeToTerms,
  }) async {
    emit(AuthenticationInProgress());
    try {
      // final client = HttpClient(
      //     context: SecurityContext()..setTrustedCertificatesBytes(certBytes));
      final response = await http.post(
        Uri(
          scheme: 'https',
          host: 'hookipa.net',
          path: '/register/new/',
        ),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;'
              'q=0.9,image/avif,image/webp,image/apng,*/*;'
              'q=0.8,application/signed-exchange;v=b3;q=0.7',
          'Accept-Encoding': 'gzip, deflate, br, zstd',
          'Accept-Language': 'en-GB,en-US;q=0.9,en;q=0.8',
          'Cache-Control': 'max-age=0',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': 'pll_language=en',
          'Dnt': '1',
          'Origin': 'https://hookipa.net',
          'Priority': 'u=0, i',
          'Referer': 'https://hookipa.net/register/new/',
          'Sec-Ch-Ua': '"Chromium";v="127", "Not)A;Brand";v="99"',
          'Sec-Ch-Ua-Mobile': '?0',
          'Sec-Ch-Ua-Platform': '"Linux"',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'same-origin',
          'Sec-Fetch-User': '?1',
          'Upgrade-Insecure-Requests': '1',
          'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36',
        },
        body: {
          'username': username,
          'host': defaultServer,
          'password': password,
          'password2': confirmPassword,
          'id': captchaID,
          'key': captcha,
          'register': 'Register',
        },
      );
      print(response.request?.headers);
      print(response.request?.url);
      print(response.request?.method);
      print(response.request?.toString());
      print(
          '${response.statusCode}: ${response.body}: ${response.headers}: ${response.reasonPhrase}: ${response.isRedirect}');
      if (!(response.statusCode == 200 || response.statusCode == 201)) {
        emit(AuthenticationSignupFailure(response.body));
        return;
      }
    } on Exception catch (e) {
      print(e);
      emit(const AuthenticationSignupFailure(
          'Failed to register, try again later.'));
      return;
    }
    await login(username: username, password: password, rememberMe: rememberMe);
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

    emit(AuthenticationNone());
  }
}
