// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:axichat/main.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

import '../../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(FakeCredentialKey());
  });

  late MockCredentialStore credentialStore;
  late MockXmppService xmppService;
  late MockHttpClient httpClient;
  late MockEmailProvisioningClient provisioningClient;

  setUp(() {
    credentialStore = MockCredentialStore();
    xmppService = MockXmppService();
    httpClient = MockHttpClient();
    provisioningClient = MockEmailProvisioningClient();

    when(() => xmppService.connectivityStream).thenAnswer(
      (_) => const Stream<mox.XmppConnectionState>.empty(),
    );

    when(() => credentialStore.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => credentialStore.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async => true);
    when(() => credentialStore.delete(key: any(named: 'key')))
        .thenAnswer((_) async => true);
    when(() => credentialStore.close()).thenAnswer((_) async {});
  });

  test('checkNotPwned does not emit AuthenticationState changes', () async {
    when(() => httpClient.get(any())).thenAnswer(
      (_) async => http.Response('', 200),
    );

    final cubit = AuthenticationCubit(
      credentialStore: credentialStore,
      xmppService: xmppService,
      httpClient: httpClient,
      emailProvisioningClient: provisioningClient,
    );
    addTearDown(cubit.close);

    final emitted = <AuthenticationState>[];
    final subscription = cubit.stream.listen(emitted.add);
    addTearDown(subscription.cancel);

    final result = await cubit.checkNotPwned(password: 'password');

    expect(result, isTrue);
    expect(emitted, isEmpty);
  });

  test('checkNotPwned returns false for pwned password', () async {
    const password = 'password';
    final hash = sha1.convert(utf8.encode(password)).toString().toUpperCase();
    final subhash = hash.substring(0, 5);
    final suffix = hash.substring(5);

    when(
      () => httpClient.get(
        Uri.parse('https://api.pwnedpasswords.com/range/$subhash'),
      ),
    ).thenAnswer(
      (_) async => http.Response('$suffix:42\r\n', 200),
    );

    final cubit = AuthenticationCubit(
      credentialStore: credentialStore,
      xmppService: xmppService,
      httpClient: httpClient,
      emailProvisioningClient: provisioningClient,
    );
    addTearDown(cubit.close);

    final emitted = <AuthenticationState>[];
    final subscription = cubit.stream.listen(emitted.add);
    addTearDown(subscription.cancel);

    final result = await cubit.checkNotPwned(password: password);

    expect(result, isFalse);
    expect(emitted, isEmpty);
  });
}
