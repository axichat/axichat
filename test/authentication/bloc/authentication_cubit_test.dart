import 'dart:convert';

import 'package:axichat/main.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/chatmail_provisioning_client.dart'
    as provisioning;
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart' hide ConnectionState;
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

Uri _registrationMatcher() => any<Uri>(
      that: predicate((Uri uri) => uri.path.contains('/register/new/')),
    );

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(FakeCredentialKey());
  });

  late Client mockHttpClient;
  late MockChatmailProvisioningClient mockProvisioningClient;
  late MockEmailService mockEmailService;
  String? pendingSignupRollbacksPayload;
  String? completedSignupAccountsPayload;

  setUp(() {
    mockXmppService = MockXmppService();
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockNotificationService = MockNotificationService();
    mockEmailService = MockEmailService();
    mockHttpClient = MockHttpClient();
    mockProvisioningClient = MockChatmailProvisioningClient();

    when(() => mockXmppService.omemoActivityStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockXmppService.connectivityStream)
        .thenAnswer((_) => const Stream<ConnectionState>.empty());
    when(() => mockXmppService.connected).thenReturn(false);
    when(() => mockXmppService.databasesInitialized).thenReturn(false);
    when(() => mockXmppService.myJid).thenReturn(null);
    when(() => mockXmppService.setClientState(any())).thenAnswer((_) async {});

    pendingSignupRollbacksPayload = null;
    completedSignupAccountsPayload = null;

    when(() => mockCredentialStore.read(key: any(named: 'key')))
        .thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
      if (key.value == 'pending_signup_rollbacks') {
        return pendingSignupRollbacksPayload;
      }
      if (key.value == 'completed_signup_accounts_v1') {
        return completedSignupAccountsPayload;
      }
      if (key.value == 'password_prehashed_v1') {
        return true.toString();
      }
      return null;
    });

    when(() => mockCredentialStore.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
      final value = invocation.namedArguments[#value] as String?;
      if (key.value == 'pending_signup_rollbacks') {
        pendingSignupRollbacksPayload = value;
      }
      if (key.value == 'completed_signup_accounts_v1') {
        completedSignupAccountsPayload = value;
      }
      return true;
    });

    when(() => mockCredentialStore.delete(key: any(named: 'key')))
        .thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
      if (key.value == 'pending_signup_rollbacks') {
        pendingSignupRollbacksPayload = null;
      }
      if (key.value == 'completed_signup_accounts_v1') {
        completedSignupAccountsPayload = null;
      }
      return true;
    });

    when(() => mockCredentialStore.close()).thenAnswer((_) async {});

    when(() => mockXmppService.disconnect()).thenAnswer((_) async {});
    when(() => mockEmailService.setForegroundKeepalive(any()))
        .thenAnswer((_) async {});
    when(() => mockEmailService.setClientState(any())).thenAnswer((_) async {});
    when(
      () => mockEmailService.shutdown(
        jid: any(named: 'jid'),
        clearCredentials: any(named: 'clearCredentials'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockEmailService.burn(jid: any(named: 'jid')))
        .thenAnswer((_) async {});

    when(
      () => mockProvisioningClient.createAccount(
        localpart: any(named: 'localpart'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const provisioning.EmailProvisioningCredentials(
        email: 'prov@axi.im',
        password: validPassword,
      ),
    );
    when(
      () => mockProvisioningClient.deleteAccount(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
  });

  group('login', () {
    late AuthenticationCubit bloc;

    setUp(() {
      bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      );

      when(() => mockXmppService.connect(
            jid: any(named: 'jid'),
            password: any(named: 'password'),
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            preHashed: any(named: 'preHashed'),
            reuseExistingSession: any(named: 'reuseExistingSession'),
            endpoint: any(named: 'endpoint'),
          )).thenThrow(XmppAuthenticationException());
      when(() => mockXmppService.connect(
            jid: validJid,
            password: validPassword,
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            preHashed: any(named: 'preHashed'),
            reuseExistingSession: any(named: 'reuseExistingSession'),
            endpoint: any(named: 'endpoint'),
          )).thenAnswer((_) async => saltedPassword);
    });

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given valid credentials, saves them and emits [AuthenticationComplete].',
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
        verify(() => mockCredentialStore.write(
              key: bloc.jidStorageKey,
              value: validJid,
            )).called(1);
        verify(() => mockCredentialStore.write(
              key: bloc.passwordStorageKey,
              value: saltedPassword,
            )).called(1);
        verify(() => mockCredentialStore.write(
              key: bloc.passwordPreHashedStorageKey,
              value: true.toString(),
            )).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given valid credentials with rememberMe false, still saves them and emits [AuthenticationComplete].',
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
        verify(() => mockCredentialStore.write(
              key: bloc.jidStorageKey,
              value: validJid,
            )).called(1);
        verify(() => mockCredentialStore.write(
              key: bloc.passwordStorageKey,
              value: saltedPassword,
            )).called(1);
        verify(() => mockCredentialStore.write(
              key: bloc.passwordPreHashedStorageKey,
              value: true.toString(),
            )).called(1);
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
      'Records accounts that reach AuthenticationComplete.',
      build: () => bloc,
      act: (bloc) => bloc.login(
        username: validUsername,
        password: validPassword,
      ),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationComplete(),
      ],
      verify: (_) {
        final payload = completedSignupAccountsPayload;
        expect(payload, isNotNull);
        final decoded = jsonDecode(payload!) as List<dynamic>;
        expect(decoded, contains(validJid.toLowerCase()));
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

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Preserves authenticated session on network failures.',
      setUp: () {
        when(() => mockCredentialStore.read(key: any(named: 'key')))
            .thenAnswer((invocation) async {
          final key =
              invocation.namedArguments[#key] as RegisteredCredentialKey;
          return switch (key.value) {
            'jid' => validJid,
            'password' => validPassword,
            'password_prehashed_v1' => true.toString(),
            _ => null,
          };
        });
        when(() => mockXmppService.connect(
              jid: any(named: 'jid'),
              password: any(named: 'password'),
              databasePrefix: any(named: 'databasePrefix'),
              databasePassphrase: any(named: 'databasePassphrase'),
              preHashed: any(named: 'preHashed'),
              reuseExistingSession: any(named: 'reuseExistingSession'),
              endpoint: any(named: 'endpoint'),
            )).thenThrow(XmppNetworkException());
        when(() => mockXmppService.resumeOfflineSession(
              jid: any(named: 'jid'),
              databasePrefix: any(named: 'databasePrefix'),
              databasePassphrase: any(named: 'databasePassphrase'),
            )).thenAnswer((_) async {});
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
      ),
      act: (bloc) => bloc.login(),
      expect: () => [],
      verify: (bloc) {
        verify(() => mockXmppService.disconnect()).called(1);
        expect(bloc.state, isA<AuthenticationComplete>());
      },
    );
  });

  group('signup', () {
    const captchaId = 'captcha-id';
    const captchaText = 'captcha';

    setUp(() {
      when(() => mockHttpClient.post(
            any(that: isA<Uri>()),
            body: any(named: 'body'),
          )).thenAnswer((_) async => Response('', 200));
      when(() => mockXmppService.connect(
            jid: any(named: 'jid'),
            password: any(named: 'password'),
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            preHashed: any(named: 'preHashed'),
            reuseExistingSession: any(named: 'reuseExistingSession'),
            endpoint: any(named: 'endpoint'),
          )).thenThrow(XmppAuthenticationException());
    });

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Rolls back the account if login fails after registration.',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      ),
      act: (bloc) => bloc.signup(
        username: validUsername,
        password: validPassword,
        confirmPassword: validPassword,
        captchaID: captchaId,
        captcha: captchaText,
        rememberMe: true,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(),
        AuthenticationLogInInProgress(fromSignup: true),
        AuthenticationFailure('Incorrect username or password'),
      ],
      verify: (bloc) {
        verify(
          () => mockProvisioningClient.deleteAccount(
            email: '$validUsername@${AuthenticationCubit.domain}',
            password: validPassword,
          ),
        ).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Queues the rollback when delete request fails.',
      setUp: () {
        when(
          () => mockProvisioningClient.deleteAccount(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(Exception('offline'));
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      ),
      act: (bloc) => bloc.signup(
        username: validUsername,
        password: validPassword,
        confirmPassword: validPassword,
        captchaID: captchaId,
        captcha: captchaText,
        rememberMe: false,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(),
        AuthenticationLogInInProgress(fromSignup: true),
        AuthenticationFailure('Incorrect username or password'),
      ],
      verify: (bloc) {
        verify(() => mockCredentialStore.write(
              key: bloc.pendingSignupRollbacksKey,
              value: any(named: 'value'),
            )).called(2);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Never sends rollback for accounts that completed authentication.',
      setUp: () {
        completedSignupAccountsPayload = jsonEncode([validJid.toLowerCase()]);
        when(() => mockHttpClient.post(
              _registrationMatcher(),
              body: any(named: 'body'),
            )).thenAnswer((_) async => Response('', 200));
        when(() => mockXmppService.connect(
              jid: validJid,
              password: validPassword,
              databasePrefix: any(named: 'databasePrefix'),
              databasePassphrase: any(named: 'databasePassphrase'),
              preHashed: any(named: 'preHashed'),
              reuseExistingSession: any(named: 'reuseExistingSession'),
              endpoint: any(named: 'endpoint'),
            )).thenThrow(XmppAuthenticationException());
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      ),
      act: (bloc) => bloc.signup(
        username: validUsername,
        password: validPassword,
        confirmPassword: validPassword,
        captchaID: captchaId,
        captcha: captchaText,
        rememberMe: false,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(),
        AuthenticationLogInInProgress(fromSignup: true),
        AuthenticationFailure('Incorrect username or password'),
      ],
      verify: (_) {
        verifyNever(
          () => mockProvisioningClient.deleteAccount(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
        expect(pendingSignupRollbacksPayload, isNull);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Prevents signup until pending cleanup for username completes.',
      setUp: () {
        pendingSignupRollbacksPayload = jsonEncode([
          {
            'username': validUsername,
            'host': AuthenticationCubit.domain,
            'password': 'stale',
            'createdAt': '2024-01-01T00:00:00.000Z',
          },
        ]);
        when(
          () => mockProvisioningClient.deleteAccount(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(Exception('fail'));
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      ),
      act: (bloc) => bloc.signup(
        username: validUsername,
        password: validPassword,
        confirmPassword: validPassword,
        captchaID: captchaId,
        captcha: captchaText,
        rememberMe: false,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(),
        AuthenticationSignupFailure(
          AuthenticationCubit.signupCleanupInProgressMessage,
          isCleanupBlocked: true,
        ),
      ],
      verify: (bloc) {
        verifyNever(() => mockHttpClient.post(
              _registrationMatcher(),
              body: any(named: 'body'),
            ));
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Flushes pending cleanup before retrying signup with the same username.',
      setUp: () {
        pendingSignupRollbacksPayload = jsonEncode([
          {
            'username': validUsername,
            'host': AuthenticationCubit.domain,
            'password': 'stale',
            'createdAt': '2024-01-01T00:00:00.000Z',
          },
        ]);
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      ),
      act: (bloc) => bloc.signup(
        username: validUsername,
        password: validPassword,
        confirmPassword: validPassword,
        captchaID: captchaId,
        captcha: captchaText,
        rememberMe: false,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(),
        AuthenticationLogInInProgress(fromSignup: true),
        AuthenticationFailure('Incorrect username or password'),
      ],
      verify: (bloc) {
        final payload = pendingSignupRollbacksPayload;
        expect(payload, isNotNull);
        final decoded = jsonDecode(payload!) as List<dynamic>;
        expect(decoded, hasLength(1));
        final entry = decoded.first as Map<String, dynamic>;
        expect(entry['username'], equals(validUsername.toLowerCase()));
        expect(entry['password'], equals(validPassword));
      },
    );
  });

  group('unregister', () {
    setUp(() {
      when(() => mockCredentialStore.deleteAll(burn: any(named: 'burn')))
          .thenAnswer((_) async => true);
      when(() => mockXmppService.burn()).thenAnswer((_) async {});
    });

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Burns credentials after successful unregister.',
      setUp: () {
        when(() => mockEmailService.currentAccount(validJid)).thenAnswer(
          (_) async => const EmailAccount(
            address: 'user@axi.im',
            password: validPassword,
          ),
        );
        when(() => mockEmailService.burn(jid: any(named: 'jid')))
            .thenAnswer((_) async {});
        when(
          () => mockProvisioningClient.deleteAccount(
            email: 'user@axi.im',
            password: validPassword,
          ),
        ).thenAnswer((_) async {});
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
      ),
      act: (bloc) => bloc.unregister(
        username: validUsername,
        host: AuthenticationCubit.domain,
        password: validPassword,
      ),
      expect: () => const [
        AuthenticationUnregisterInProgress(),
        AuthenticationNone(),
      ],
      verify: (_) {
        verify(
          () => mockProvisioningClient.deleteAccount(
            email: 'user@axi.im',
            password: validPassword,
          ),
        ).called(1);
        verify(() => mockXmppService.burn()).called(1);
        verify(() => mockEmailService.burn(jid: any(named: 'jid'))).called(1);
      },
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
      when(() => mockHttpClient.get(any(that: isA<Uri>())))
          .thenAnswer((invocation) async {
        final uri = invocation.positionalArguments.first as Uri;
        if (uri.toString().contains('5BAA6')) {
          return Response(
            '1E4C9B93F3F0682250B6CF8331B7EE68FD8:10\r\n',
            200,
          );
        }
        return Response('', 200);
      });
      bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
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
        emailProvisioningClient: mockProvisioningClient,
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
        emailProvisioningClient: mockProvisioningClient,
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
        emailProvisioningClient: mockProvisioningClient,
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
        emailProvisioningClient: mockProvisioningClient,
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
