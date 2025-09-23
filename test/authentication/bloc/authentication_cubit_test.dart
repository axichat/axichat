import 'package:axichat/main.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

const validUsername = 'validUsername';
const validJid = '$validUsername@${AuthenticationCubit.domain}';
const validPassword = 'validPassword';
const saltedPassword = 'saltedPassword';
const invalidUsername = 'invalidUsername';
const invalidPassword = 'invalidPassword';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(FakeCredentialKey());
  });

  late Client mockHttpClient;

  setUp(() {
    mockXmppService = MockXmppService();
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockNotificationService = MockNotificationService();
    mockHttpClient = MockHttpClient();

    when(() => mockXmppService.omemoActivityStream)
        .thenAnswer((_) => const Stream.empty());

    when(() => mockCredentialStore.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);

    when(() => mockCredentialStore.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async => true);

    when(() => mockCredentialStore.close()).thenAnswer((_) async {});

    when(() => mockXmppService.disconnect()).thenAnswer((_) async {});
  });

  group('login', () {
    late AuthenticationCubit bloc;

    setUp(() {
      bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
      );

      when(() => mockXmppService.connect(
            jid: any(named: 'jid'),
            password: any(named: 'password'),
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            preHashed: any(named: 'preHashed'),
          )).thenThrow(XmppAuthenticationException());
      when(() => mockXmppService.connect(
            jid: validJid,
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
        const AuthenticationLogInInProgress(),
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
        const AuthenticationLogInInProgress(),
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
        const AuthenticationLogInInProgress(),
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
        const AuthenticationLogInInProgress(),
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
        const AuthenticationLogInInProgress(),
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
        const AuthenticationLogInInProgress(),
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
        const AuthenticationLogInInProgress(),
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
        const AuthenticationLogInInProgress(),
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
        const AuthenticationLogInInProgress(),
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
        const AuthenticationLogInInProgress(),
        const AuthenticationNone(),
      ],
    );
  });

  //Make real network calls and just accept the flakiness to know if we
  // still gel with the 3rd party api.
  group('checkNotPwned', () {
    late AuthenticationCubit bloc;

    const breachedPassword = 'password';
    //Theoretically flaky but not at all likely.
    final securePassword = generateRandomString();

    setUp(() {
      bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
      );
    });

    test('Given breached password, returns false', () async {
      expect(await bloc.checkNotPwned(password: breachedPassword), isFalse);
    });

    test('Given secure password, returns true', () async {
      expect(await bloc.checkNotPwned(password: securePassword), isTrue);
    });
  });

  group('logout', () {
    setUp(() {
      when(() => mockXmppService.disconnect()).thenAnswer((_) async {});
      when(() => mockCredentialStore.delete(key: any(named: 'key')))
          .thenAnswer((_) async => true);
      when(() => mockCredentialStore.delete(key: any(named: 'key')))
          .thenAnswer((_) async => true);
      when(() => mockCredentialStore.deleteAll(burn: any(named: 'burn')))
          .thenAnswer((_) async => true);
      when(() => mockXmppService.burn()).thenAnswer((_) async {});
    });

    blocTest<AuthenticationCubit, AuthenticationState>(
      'If authentication is not complete, does nothing.',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
      ),
      act: (bloc) => bloc.logout(),
      expect: () => [],
      verify: (bloc) {
        verifyNever(() => mockCredentialStore.delete(key: bloc.jidStorageKey));
        verifyNever(
            () => mockCredentialStore.delete(key: bloc.passwordStorageKey));
        verifyNever(() => mockXmppService.disconnect());
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Automatic logout disconnects the xmpp service without forgetting credentials and emits [AuthenticationNone].',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        initialState: const AuthenticationComplete(),
      ),
      act: (bloc) => bloc.logout(),
      expect: () => [const AuthenticationNone()],
      verify: (bloc) {
        verifyNever(() => mockCredentialStore.delete(key: bloc.jidStorageKey));
        verifyNever(
            () => mockCredentialStore.delete(key: bloc.passwordStorageKey));
        verify(() => mockXmppService.disconnect()).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'User initiated logout disconnects the xmpp service, forgets credentials and emits [AuthenticationNone].',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        initialState: const AuthenticationComplete(),
      ),
      act: (bloc) => bloc.logout(severity: LogoutSeverity.normal),
      expect: () => [const AuthenticationNone()],
      verify: (bloc) {
        verify(() => mockCredentialStore.delete(key: bloc.jidStorageKey))
            .called(1);
        verify(() => mockCredentialStore.delete(key: bloc.passwordStorageKey))
            .called(1);
        verify(() => mockXmppService.disconnect()).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Burn logout disconnects the xmpp service, wipes disk and emits [AuthenticationNone].',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        initialState: const AuthenticationComplete(),
      ),
      act: (bloc) => bloc.logout(severity: LogoutSeverity.burn),
      expect: () => [const AuthenticationNone()],
      verify: (bloc) {
        verify(() => mockCredentialStore.deleteAll(burn: true)).called(1);
        verify(() => mockXmppService.burn()).called(1);
        verify(() => mockXmppService.disconnect()).called(1);
      },
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
