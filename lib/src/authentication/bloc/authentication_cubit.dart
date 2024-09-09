import 'dart:async';
import 'dart:ui';

import 'package:bloc/bloc.dart';
import 'package:chat/src/common/capability.dart';
import 'package:chat/src/common/generate_random.dart';
import 'package:chat/src/storage/credential_store.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
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
    required Capability capability,
  })  : _credentialStore = credentialStore,
        _xmppService = xmppService,
        _capability = capability,
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

  static Uri registrationUrl = Uri.parse('http://nz.axichat.com/api/register');

  final jidStorageKey = CredentialStore.registerKey('jid');
  final passwordStorageKey = CredentialStore.registerKey('password');

  final CredentialStore _credentialStore;
  final XmppService _xmppService;
  final Capability _capability;

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
    if (_capability.canForegroundService &&
        !await FlutterForegroundTask.isRunningService &&
        state is AuthenticationComplete) {
      await logout();
    }
    if (state is AuthenticationComplete || state is AuthenticationInProgress) {
      return;
    }
    emit(AuthenticationInProgress());

    assert((username == null) == (password == null));

    late final String? jid;
    if (username == null || password == null) {
      jid = await _credentialStore.read(key: jidStorageKey);
      password = await _credentialStore.read(key: passwordStorageKey);
    } else {
      jid = '$username@${state.server}';
    }

    if (jid == null || password == null) {
      emit(AuthenticationNone());
      return;
    }

    final resourceStorageKey = CredentialStore.registerKey(
      '${jid}_resource',
    );
    final resource = await _credentialStore.read(key: resourceStorageKey) ??
        XmppService.generateResource();

    final databasePrefixStorageKey =
        CredentialStore.registerKey('${jid}_database_prefix');
    final databasePrefix =
        await _credentialStore.read(key: databasePrefixStorageKey) ??
            generateRandomString(length: 8);

    final databasePassphraseStorageKey = CredentialStore.registerKey(
      '${databasePrefix}_database_passphrase',
    );
    var databasePassphrase = await _credentialStore.read(
      key: databasePassphraseStorageKey,
    );

    final savedPassword = await _credentialStore.read(key: passwordStorageKey);
    final preHashed = savedPassword != null;
    databasePassphrase ??= generateRandomString();
    try {
      password = await _xmppService.connect(
        jid: jid,
        resource: resource,
        password: password,
        databasePrefix: databasePrefix,
        databasePassphrase: databasePassphrase,
        preHashed: preHashed,
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

    await _credentialStore.write(
      key: resourceStorageKey,
      value: _xmppService.resource,
    );

    await _credentialStore.write(
      key: databasePrefixStorageKey,
      value: databasePrefix,
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
  }) async {
    emit(AuthenticationInProgress());
    try {
      final response = await http.post(
        registrationUrl,
        // headers: {
        //   'Accept': 'text/html,application/xhtml+xml,application/xml;'
        //       'q=0.9,image/avif,image/webp,image/apng,*/*;'
        //       'q=0.8,application/signed-exchange;v=b3;q=0.7',
        //   'Accept-Encoding': 'gzip, deflate, br, zstd',
        //   'Accept-Language': 'en-GB,en-US;q=0.9,en;q=0.8',
        //   'Cache-Control': 'max-age=0',
        //   'Content-Type': 'application/x-www-form-urlencoded',
        //   'Cookie': 'pll_language=en',
        //   'Dnt': '1',
        //   'Origin': 'https://hookipa.net',
        //   'Priority': 'u=0, i',
        //   'Referer': 'https://hookipa.net/register/new/',
        //   'Sec-Ch-Ua': '"Chromium";v="127", "Not)A;Brand";v="99"',
        //   'Sec-Ch-Ua-Mobile': '?0',
        //   'Sec-Ch-Ua-Platform': '"Linux"',
        //   'Sec-Fetch-Dest': 'document',
        //   'Sec-Fetch-Mode': 'navigate',
        //   'Sec-Fetch-Site': 'same-origin',
        //   'Sec-Fetch-User': '?1',
        //   'Upgrade-Insecure-Requests': '1',
        //   'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
        //       '(KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36',
        // },
        body: {
          'user': username,
          'host': state.server,
          'password': password,
          // 'password2': confirmPassword,
          // 'id': captchaID,
          // 'key': captcha,
          // 'register': 'Register',
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
