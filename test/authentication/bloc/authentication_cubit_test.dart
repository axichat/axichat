import 'package:bloc_test/bloc_test.dart';
import 'package:chat/src/authentication/bloc/authentication_cubit.dart';
import 'package:chat/src/common/capability.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

const validUsername = 'validUsername';
const validJid = '$validUsername@${AuthenticationCubit.domain}';
const validPassword = 'validPassword';
const saltedPassword = 'saltedPassword';
const invalidUsername = 'invalidUsername';
const invalidPassword = 'invalidPassword';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
  });

  setUp(() {
    when(() => mockCredentialStore.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);

    when(() => mockCredentialStore.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async => true);

    when(() => mockCredentialStore.close()).thenAnswer((_) async {});
  });

  group('login', () {
    late AuthenticationCubit bloc;

    setUp(() {
      bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        capability: const Capability(),
      );
      when(() => mockXmppService.connect(
            jid: validJid,
            resource: any(named: 'resource'),
            password: validPassword,
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            preHashed: any(named: 'preHashed'),
          )).thenAnswer((_) async => saltedPassword);
      when(() => mockXmppService.connect(
            jid: any(named: 'jid', that: isNot(validJid)),
            resource: any(named: 'resource'),
            password: any(named: 'password', that: isNot(validPassword)),
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            preHashed: any(named: 'preHashed'),
          )).thenThrow(XmppAuthenticationException());
    });

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given valid credentials, saves them and emits [AuthenticationComplete].',
      build: () => bloc,
      act: (bloc) => bloc.login(
        username: validUsername,
        password: validPassword,
        rememberMe: true,
      ),
      expect: () => [
        const AuthenticationInProgress(),
        const AuthenticationComplete(),
      ],
      verify: (bloc) {
        verify(() => mockCredentialStore.write(
              key: bloc.jidStorageKey,
              value: validJid,
            )).called(1);
        verify(() => mockCredentialStore.write(
              key: bloc.passwordStorageKey,
              value: saltedPassword,
            )).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given invalid credentials, emits [AuthenticationFailure].',
      build: () => bloc,
      act: (bloc) => bloc.login(
        username: invalidUsername,
        password: invalidPassword,
      ),
      expect: () => [
        const AuthenticationInProgress(),
        const AuthenticationFailure('Incorrect username or password'),
      ],
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given saved credentials, automatic login emits [AuthenticationComplete].',
      setUp: () {
        when(() => mockCredentialStore.read(key: bloc.jidStorageKey)).thenAnswer((_) async => validJid);
        when(() => mockCredentialStore.read(key: bloc.passwordStorageKey)).thenAnswer((_) async => validPassword);
      },
      build: () => bloc,
      act: (bloc) => bloc.login(),
      expect: () => [
        const AuthenticationInProgress(),
        const AuthenticationComplete(),
      ],
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Without saved credentials, automatic login emits [AuthenticationNone].',
      build: () => bloc,
      act: (bloc) => bloc.login(),
      expect: () => [
        const AuthenticationInProgress(),
        const AuthenticationNone(),
      ],
    );
  });
}
//

// verify(() => connection.connect(
//       shouldReconnect: false,
//       waitForConnection: true,
//       waitUntilLogin: true,
//     )).called(1);
//
// verify(() => credentialStore.write(
//       key: xmppService.jidStorageKey,
//       value: username,
//     )).called(1);
//
// verify(() => credentialStore.write(
//       key: xmppService.passwordStorageKey,
//       value: password,
//     )).called(1);
