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
    mockXmppService = MockXmppService();
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockNotificationService = MockNotificationService();

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
            jid: any(named: 'jid'),
            resource: any(named: 'resource'),
            password: any(named: 'password'),
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            preHashed: any(named: 'preHashed'),
          )).thenThrow(XmppAuthenticationException());
      when(() => mockXmppService.connect(
            jid: validJid,
            resource: any(named: 'resource'),
            password: validPassword,
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            preHashed: any(named: 'preHashed'),
          )).thenAnswer((_) async => saltedPassword);
    });

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given valid credentials with "remember me", saves them and emits [AuthenticationComplete].',
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
      'Given valid credentials without "remember me", doesn\'t save them and emits [AuthenticationComplete].',
      build: () => bloc,
      act: (bloc) => bloc.login(
        username: validUsername,
        password: validPassword,
      ),
      expect: () => [
        const AuthenticationInProgress(),
        const AuthenticationComplete(),
      ],
      verify: (bloc) {
        verifyNever(() => mockCredentialStore.write(
              key: bloc.jidStorageKey,
              value: validJid,
            ));
        verifyNever(() => mockCredentialStore.write(
              key: bloc.passwordStorageKey,
              value: saltedPassword,
            ));
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given invalid username and password, emits [AuthenticationFailure].',
      build: () => bloc,
      act: (bloc) => bloc.login(
        username: invalidUsername,
        password: invalidPassword,
      ),
      expect: () => [
        const AuthenticationInProgress(),
        const AuthenticationFailure('Incorrect username or password'),
      ],
      verify: (bloc) {
        verifyNever(() => mockCredentialStore.write(
              key: bloc.jidStorageKey,
              value: validJid,
            ));
        verifyNever(() => mockCredentialStore.write(
              key: bloc.passwordStorageKey,
              value: saltedPassword,
            ));
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given invalid username and valid password, emits [AuthenticationFailure].',
      build: () => bloc,
      act: (bloc) => bloc.login(
        username: invalidUsername,
        password: validPassword,
      ),
      expect: () => [
        const AuthenticationInProgress(),
        const AuthenticationFailure('Incorrect username or password'),
      ],
      verify: (bloc) {
        verifyNever(() => mockCredentialStore.write(
              key: bloc.jidStorageKey,
              value: validJid,
            ));
        verifyNever(() => mockCredentialStore.write(
              key: bloc.passwordStorageKey,
              value: saltedPassword,
            ));
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given valid username and invalid password, emits [AuthenticationFailure].',
      build: () => bloc,
      act: (bloc) => bloc.login(
        username: validUsername,
        password: invalidPassword,
      ),
      expect: () => [
        const AuthenticationInProgress(),
        const AuthenticationFailure('Incorrect username or password'),
      ],
      verify: (bloc) {
        verifyNever(() => mockCredentialStore.write(
              key: bloc.jidStorageKey,
              value: validJid,
            ));
        verifyNever(() => mockCredentialStore.write(
              key: bloc.passwordStorageKey,
              value: saltedPassword,
            ));
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given valid username and missing password, emits [AuthenticationFailure].',
      build: () => bloc,
      act: (bloc) => bloc.login(
        username: validUsername,
      ),
      expect: () => [
        const AuthenticationInProgress(),
        const AuthenticationFailure(
            'Username and password have different nullness.'),
      ],
      verify: (bloc) {
        verifyNever(() => mockCredentialStore.write(
              key: bloc.jidStorageKey,
              value: validJid,
            ));
        verifyNever(() => mockCredentialStore.write(
              key: bloc.passwordStorageKey,
              value: saltedPassword,
            ));
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given missing username and valid password, emits [AuthenticationFailure].',
      build: () => bloc,
      act: (bloc) => bloc.login(
        password: validPassword,
      ),
      expect: () => [
        const AuthenticationInProgress(),
        const AuthenticationFailure(
            'Username and password have different nullness.'),
      ],
      verify: (bloc) {
        verifyNever(() => mockCredentialStore.write(
              key: bloc.jidStorageKey,
              value: validJid,
            ));
        verifyNever(() => mockCredentialStore.write(
              key: bloc.passwordStorageKey,
              value: saltedPassword,
            ));
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given saved valid credentials, automatic login emits [AuthenticationComplete].',
      setUp: () {
        when(() => mockCredentialStore.read(key: bloc.jidStorageKey))
            .thenAnswer((_) async => validJid);
        when(() => mockCredentialStore.read(key: bloc.passwordStorageKey))
            .thenAnswer((_) async => validPassword);
      },
      build: () => bloc,
      act: (bloc) => bloc.login(),
      expect: () => [
        const AuthenticationInProgress(),
        const AuthenticationComplete(),
      ],
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given saved invalid credentials, automatic login emits [AuthenticationFailure].',
      setUp: () {
        when(() => mockCredentialStore.read(key: bloc.jidStorageKey))
            .thenAnswer((_) async => validJid);
        when(() => mockCredentialStore.read(key: bloc.passwordStorageKey))
            .thenAnswer((_) async => invalidPassword);
      },
      build: () => bloc,
      act: (bloc) => bloc.login(),
      expect: () => [
        const AuthenticationInProgress(),
        const AuthenticationFailure('Incorrect username or password'),
      ],
      verify: (bloc) {
        verifyNever(() => mockCredentialStore.write(
              key: bloc.jidStorageKey,
              value: validJid,
            ));
        verifyNever(() => mockCredentialStore.write(
              key: bloc.passwordStorageKey,
              value: saltedPassword,
            ));
      },
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
