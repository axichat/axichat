import 'dart:async';
import 'dart:convert';

import 'package:axichat/main.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/email_provisioning_client.dart'
    as provisioning;
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

const validUsername = 'validUsername';
const validJid = '$validUsername@${EndpointConfig.defaultDomain}';
const validPassword = 'validPassword';
const saltedPassword = 'saltedPassword';
const invalidUsername = 'invalidUsername';
const invalidPassword = 'invalidPassword';
const signupWelcomeTitle = 'Axichat';
const signupWelcomeBody = 'Welcome to Axichat!';
const _welcomeChatJid = 'axichat@welcome.axichat.invalid';
const _welcomeStanzaId = 'signup-welcome.axichat';
const bool clearEmailCredentialsOnLogout = true;

Uri _registrationMatcher() =>
    any<Uri>(that: predicate((Uri uri) => uri.path.contains('/register/new/')));

Uri _changePasswordMatcher() => any<Uri>(
  that: predicate(
    (Uri uri) =>
        uri.path.contains('/register/change_password/') ||
        uri.path.contains('/register/password/'),
  ),
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(fallbackChat);
    registerFallbackValue(fallbackMessage);
    registerFallbackValue(ChatType.chat);
  });

  late Client mockHttpClient;
  late MockEmailProvisioningClient mockProvisioningClient;
  late MockEmailService mockEmailService;
  late MockHomeRefreshSyncService mockHomeRefreshSyncService;
  late Map<String, String?> credentialStorage;
  late AppLocalizations localizations;

  setUp(() {
    mockXmppService = MockXmppService();
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockDatabase = MockXmppDatabase();
    mockEmailService = MockEmailService();
    mockHomeRefreshSyncService = MockHomeRefreshSyncService();
    mockHttpClient = MockHttpClient();
    mockProvisioningClient = MockEmailProvisioningClient();
    localizations = lookupAppLocalizations(const Locale('en'));

    when(
      () => mockEmailService.clearStoredCredentials(
        jid: any(named: 'jid'),
        preserveActiveSession: any(named: 'preserveActiveSession'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockEmailService.persistActiveCredentials(jid: any(named: 'jid')),
    ).thenAnswer((_) async {});
    when(
      () => mockEmailService.authFailureStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockEmailService.syncState,
    ).thenReturn(const EmailSyncState.ready());
    when(
      () => mockEmailService.syncStateStream,
    ).thenAnswer((_) => const Stream<EmailSyncState>.empty());
    when(() => mockEmailService.hasActiveSession).thenReturn(false);
    when(() => mockEmailService.hasInMemoryReconnectContext).thenReturn(true);
    when(
      () => mockEmailService.canReconnectConfiguredSession(
        jid: any(named: 'jid'),
      ),
    ).thenAnswer((_) async => true);
    when(() => mockXmppService.hasInMemoryReconnectContext).thenReturn(true);
    when(
      () => mockXmppService.streamReadyStream,
    ).thenAnswer((_) => const Stream<XmppStreamReady>.empty());
    when(
      () => mockXmppService.connectionState,
    ).thenReturn(ConnectionState.notConnected);
    when(() => mockEmailService.currentAccount(any())).thenAnswer(
      (_) async =>
          const EmailAccount(address: validJid, password: validPassword),
    );
    when(
      () => mockEmailService.updatePassword(
        jid: any(named: 'jid'),
        displayName: any(named: 'displayName'),
        password: any(named: 'password'),
        persistCredentials: any(named: 'persistCredentials'),
      ),
    ).thenAnswer((_) async => EmailPasswordRefreshResult.confirmed);
    when(() => mockEmailService.start()).thenAnswer((_) async {});
    when(
      () => mockEmailService.handleNetworkAvailable(),
    ).thenAnswer((_) async {});
    when(() => mockEmailService.handleNetworkLost()).thenAnswer((_) async {});
    when(
      () => mockEmailService.ensureProvisioned(
        displayName: any(named: 'displayName'),
        databasePrefix: any(named: 'databasePrefix'),
        databasePassphrase: any(named: 'databasePassphrase'),
        jid: any(named: 'jid'),
        passwordOverride: any(named: 'passwordOverride'),
        addressOverride: any(named: 'addressOverride'),
        persistCredentials: any(named: 'persistCredentials'),
      ),
    ).thenAnswer(
      (_) async =>
          const EmailAccount(address: validJid, password: validPassword),
    );

    when(
      () => mockXmppService.omemoActivityStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockXmppService.connectivityStream,
    ).thenAnswer((_) => const Stream<ConnectionState>.empty());
    when(() => mockXmppService.connected).thenReturn(false);
    when(() => mockXmppService.databasesInitialized).thenReturn(false);
    when(() => mockXmppService.myJid).thenReturn(null);
    when(() => mockXmppService.localizations).thenReturn(localizations);
    when(() => mockXmppService.database).thenAnswer((_) async => mockDatabase);
    when(() => mockXmppService.setClientState(any())).thenAnswer((_) async {});
    when(() => mockXmppService.clearSessionTokens()).thenAnswer((_) async {});
    when(() => mockDatabase.getMessageByStanzaID(_welcomeStanzaId)).thenAnswer(
      (_) async => Message(
        stanzaID: _welcomeStanzaId,
        senderJid: _welcomeChatJid,
        chatJid: _welcomeChatJid,
        body: localizations.authSignupWelcomeMessage,
        timestamp: DateTime.utc(2026, 3, 6),
        acked: true,
        received: true,
      ),
    );
    when(
      () => mockDatabase.saveMessage(any(), chatType: any(named: 'chatType')),
    ).thenAnswer((_) async {});
    when(() => mockDatabase.updateMessage(any())).thenAnswer((_) async {});
    when(() => mockDatabase.getChat(_welcomeChatJid)).thenAnswer(
      (_) async => Chat(
        jid: _welcomeChatJid,
        title: localizations.authSignupWelcomeTitle,
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2026, 3, 6),
        contactDisplayName: localizations.authSignupWelcomeTitle,
        contactJid: _welcomeChatJid,
      ),
    );
    when(() => mockDatabase.updateChat(any())).thenAnswer((_) async {});
    when(() => mockDatabase.createChat(any())).thenAnswer((_) async {});

    when(() => mockHomeRefreshSyncService.start()).thenAnswer((_) {});
    when(() => mockHomeRefreshSyncService.close()).thenAnswer((_) async {});
    when(
      () => mockHomeRefreshSyncService.syncOnLogin(),
    ).thenAnswer((_) async {});
    credentialStorage = <String, String?>{
      'password_prehashed_v1': true.toString(),
    };

    when(() => mockCredentialStore.read(key: any(named: 'key'))).thenAnswer((
      invocation,
    ) async {
      final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
      return credentialStorage[key.value];
    });

    when(
      () => mockCredentialStore.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
      final value = invocation.namedArguments[#value] as String?;
      credentialStorage[key.value] = value;
      return true;
    });

    when(() => mockCredentialStore.delete(key: any(named: 'key'))).thenAnswer((
      invocation,
    ) async {
      final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
      credentialStorage.remove(key.value);
      return true;
    });

    when(() => mockCredentialStore.close()).thenAnswer((_) async {});

    when(() => mockXmppService.disconnect()).thenAnswer((_) async {});
    when(
      () => mockEmailService.setForegroundKeepalive(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockEmailService.shutdown(
        jid: any(named: 'jid'),
        clearCredentials: any(named: 'clearCredentials'),
      ),
    ).thenAnswer((_) async {});
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
    when(
      () => mockProvisioningClient.changePassword(
        email: any(named: 'email'),
        oldPassword: any(named: 'oldPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});
  });

  test('Remember me choice defaults to true and persists updates', () async {
    final localBloc = AuthenticationCubit(
      credentialStore: mockCredentialStore,
      initialEndpointConfig: const EndpointConfig(),
      xmppService: mockXmppService,
      httpClient: mockHttpClient,
      emailProvisioningClient: mockProvisioningClient,
    );
    final initial = await localBloc.loadRememberMeChoice();
    expect(initial, isTrue);
    await localBloc.persistRememberMeChoice(false);
    expect(await localBloc.loadRememberMeChoice(), isFalse);
  });

  group('login', () {
    late AuthenticationCubit bloc;

    setUp(() {
      bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      );

      when(
        () => mockXmppService.connect(
          jid: any(named: 'jid'),
          password: any(named: 'password'),
          databasePrefix: any(named: 'databasePrefix'),
          databasePassphrase: any(named: 'databasePassphrase'),
          preHashed: any(named: 'preHashed'),
          reuseExistingSession: any(named: 'reuseExistingSession'),
          endpoint: any(named: 'endpoint'),
        ),
      ).thenThrow(XmppAuthenticationException());
      when(
        () => mockXmppService.connect(
          jid: validJid,
          password: validPassword,
          databasePrefix: any(named: 'databasePrefix'),
          databasePassphrase: any(named: 'databasePassphrase'),
          preHashed: any(named: 'preHashed'),
          reuseExistingSession: any(named: 'reuseExistingSession'),
          endpoint: any(named: 'endpoint'),
        ),
      ).thenAnswer((_) async => saltedPassword);
    });

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given valid credentials, saves them and emits [AuthenticationComplete].',
      build: () => bloc,
      act: (bloc) =>
          bloc.login(username: validUsername, password: validPassword),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationComplete(),
      ],
      verify: (bloc) {
        verify(
          () => mockCredentialStore.write(
            key: bloc.jidStorageKey,
            value: validJid,
          ),
        ).called(1);
        verify(
          () => mockCredentialStore.write(
            key: bloc.passwordStorageKey,
            value: saltedPassword,
          ),
        ).called(1);
        verify(
          () => mockCredentialStore.write(
            key: bloc.passwordPreHashedStorageKey,
            value: true.toString(),
          ),
        ).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Xmpp login timeout emits [AuthenticationFailure] instead of hanging.',
      setUp: () {
        when(
          () => mockXmppService.connect(
            jid: validJid,
            password: validPassword,
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            preHashed: any(named: 'preHashed'),
            reuseExistingSession: any(named: 'reuseExistingSession'),
            endpoint: any(named: 'endpoint'),
          ),
        ).thenAnswer((_) => Completer<String?>().future);
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        authRequestTimeout: const Duration(milliseconds: 1),
      ),
      act: (bloc) =>
          bloc.login(username: validUsername, password: validPassword),
      wait: const Duration(milliseconds: 20),
      expect: () => const [
        AuthenticationLogInInProgress(),
        AuthenticationFailure(AuthKeyMessage(AuthMessageKey.genericError)),
      ],
      verify: (_) {
        verify(() => mockXmppService.disconnect()).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given valid credentials with rememberMe false, does not persist credentials and emits [AuthenticationComplete].',
      build: () => bloc,
      act: (bloc) => bloc.login(
        username: validUsername,
        password: validPassword,
        rememberMe: false,
      ),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationComplete(),
      ],
      verify: (bloc) {
        verifyNever(
          () => mockCredentialStore.write(
            key: bloc.jidStorageKey,
            value: validJid,
          ),
        );
        verifyNever(
          () => mockCredentialStore.write(
            key: bloc.passwordStorageKey,
            value: saltedPassword,
          ),
        );
        expect(credentialStorage['${validJid}_database_prefix'], isNull);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given invalid username and password, emits [AuthenticationFailure].',
      build: () => bloc,
      act: (bloc) =>
          bloc.login(username: invalidUsername, password: invalidPassword),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
        ),
      ],
      verify: (bloc) {
        verifyNever(
          () => mockCredentialStore.write(
            key: bloc.jidStorageKey,
            value: validJid,
          ),
        );
        verifyNever(
          () => mockCredentialStore.write(
            key: bloc.passwordStorageKey,
            value: saltedPassword,
          ),
        );
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given invalid username and valid password, emits [AuthenticationFailure].',
      build: () => bloc,
      act: (bloc) =>
          bloc.login(username: invalidUsername, password: validPassword),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
        ),
      ],
      verify: (bloc) {
        verifyNever(
          () => mockCredentialStore.write(
            key: bloc.jidStorageKey,
            value: validJid,
          ),
        );
        verifyNever(
          () => mockCredentialStore.write(
            key: bloc.passwordStorageKey,
            value: saltedPassword,
          ),
        );
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given valid username and invalid password, emits [AuthenticationFailure].',
      build: () => bloc,
      act: (bloc) =>
          bloc.login(username: validUsername, password: invalidPassword),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
        ),
      ],
      verify: (bloc) {
        verifyNever(
          () => mockCredentialStore.write(
            key: bloc.jidStorageKey,
            value: validJid,
          ),
        );
        verifyNever(
          () => mockCredentialStore.write(
            key: bloc.passwordStorageKey,
            value: saltedPassword,
          ),
        );
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Records accounts that reach AuthenticationComplete.',
      build: () => bloc,
      act: (bloc) =>
          bloc.login(username: validUsername, password: validPassword),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationComplete(),
      ],
      verify: (_) {
        final prefix = credentialStorage['${validJid}_database_prefix'];
        expect(prefix, isNotNull);
        final passphraseKey = '${prefix}_database_passphrase';
        expect(credentialStorage[passphraseKey], isNotNull);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given valid username and missing password, emits [AuthenticationFailure].',
      build: () => bloc,
      act: (bloc) => bloc.login(username: validUsername),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.usernamePasswordMismatch),
        ),
      ],
      verify: (bloc) {
        verifyNever(
          () => mockCredentialStore.write(
            key: bloc.jidStorageKey,
            value: validJid,
          ),
        );
        verifyNever(
          () => mockCredentialStore.write(
            key: bloc.passwordStorageKey,
            value: saltedPassword,
          ),
        );
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given missing username and valid password, emits [AuthenticationFailure].',
      build: () => bloc,
      act: (bloc) => bloc.login(password: validPassword),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.usernamePasswordMismatch),
        ),
      ],
      verify: (bloc) {
        verifyNever(
          () => mockCredentialStore.write(
            key: bloc.jidStorageKey,
            value: validJid,
          ),
        );
        verifyNever(
          () => mockCredentialStore.write(
            key: bloc.passwordStorageKey,
            value: saltedPassword,
          ),
        );
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given saved valid credentials, automatic login emits [AuthenticationComplete].',
      setUp: () {
        when(
          () => mockCredentialStore.read(key: bloc.jidStorageKey),
        ).thenAnswer((_) async => validJid);
        when(
          () => mockCredentialStore.read(key: bloc.passwordStorageKey),
        ).thenAnswer((_) async => validPassword);
        credentialStorage['${validJid}_database_prefix'] = 'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
      },
      build: () => bloc,
      act: (bloc) => bloc.login(),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationComplete(),
      ],
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Fresh deferred login lets deferred email provisioning own startup.',
      setUp: () {
        when(() => mockXmppService.myJid).thenReturn(validJid);
        when(
          () => mockXmppService.connectionState,
        ).thenReturn(ConnectionState.connected);
        when(() => mockEmailService.hasActiveSession).thenReturn(false);
        when(
          () => mockEmailService.hasInMemoryReconnectContext,
        ).thenReturn(false);
        when(
          () => mockEmailService.canReconnectConfiguredSession(
            jid: any(named: 'jid'),
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockEmailService.ensureProvisioned(
            displayName: any(named: 'displayName'),
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            jid: any(named: 'jid'),
            passwordOverride: any(named: 'passwordOverride'),
            addressOverride: any(named: 'addressOverride'),
            persistCredentials: any(named: 'persistCredentials'),
          ),
        ).thenThrow(
          const EmailProvisioningException(
            EmailProvisioningFailure.networkUnavailable,
            isRecoverable: true,
          ),
        );
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        homeRefreshSyncService: mockHomeRefreshSyncService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      ),
      act: (bloc) =>
          bloc.login(username: validUsername, password: validPassword),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationComplete(),
      ],
      verify: (_) {
        verify(
          () => mockEmailService.ensureProvisioned(
            displayName: any(named: 'displayName'),
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            jid: any(named: 'jid'),
            passwordOverride: any(named: 'passwordOverride'),
            addressOverride: any(named: 'addressOverride'),
            persistCredentials: any(named: 'persistCredentials'),
          ),
        ).called(2);
        verifyNever(() => mockEmailService.handleNetworkAvailable());
        verify(() => mockHomeRefreshSyncService.syncOnLogin()).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Fresh deferred login resumes email reconnect after provisioning completes.',
      setUp: () {
        when(() => mockXmppService.myJid).thenReturn(validJid);
        when(
          () => mockXmppService.connectionState,
        ).thenReturn(ConnectionState.connected);
        when(
          () => mockEmailService.syncState,
        ).thenReturn(const EmailSyncState.recovering('Syncing'));
        when(() => mockEmailService.hasActiveSession).thenReturn(true);
        when(
          () => mockEmailService.hasInMemoryReconnectContext,
        ).thenReturn(false);
        when(
          () => mockEmailService.canReconnectConfiguredSession(
            jid: any(named: 'jid'),
          ),
        ).thenAnswer((_) async => true);
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        homeRefreshSyncService: mockHomeRefreshSyncService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      ),
      act: (bloc) =>
          bloc.login(username: validUsername, password: validPassword),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationComplete(),
      ],
      verify: (_) {
        verify(() => mockEmailService.handleNetworkAvailable()).called(2);
        verify(() => mockHomeRefreshSyncService.syncOnLogin()).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Stored ready email session still triggers reconnect catch-up on login.',
      setUp: () {
        when(() => mockXmppService.myJid).thenReturn(validJid);
        when(
          () => mockXmppService.connectionState,
        ).thenReturn(ConnectionState.connected);
        when(
          () => mockEmailService.syncState,
        ).thenReturn(const EmailSyncState.ready());
        when(() => mockEmailService.hasActiveSession).thenReturn(true);
        when(
          () => mockEmailService.hasInMemoryReconnectContext,
        ).thenReturn(true);
        when(
          () => mockEmailService.canReconnectConfiguredSession(
            jid: any(named: 'jid'),
          ),
        ).thenAnswer((_) async => true);
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        homeRefreshSyncService: mockHomeRefreshSyncService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      ),
      act: (bloc) =>
          bloc.login(username: validUsername, password: validPassword),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationComplete(),
      ],
      verify: (_) {
        verify(() => mockEmailService.handleNetworkAvailable()).called(2);
        verify(() => mockHomeRefreshSyncService.syncOnLogin()).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Stored login without database secrets blocks login and emits [AuthenticationFailure].',
      setUp: () {
        credentialStorage['jid'] = validJid;
        credentialStorage['password'] = validPassword;
        credentialStorage['password_prehashed_v1'] = true.toString();
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      ),
      act: (bloc) => bloc.login(),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.missingDatabaseSecrets),
        ),
      ],
      verify: (bloc) {
        expect(
          credentialStorage[bloc.passwordPreHashedStorageKey.value],
          equals(true.toString()),
        );
        expect(credentialStorage[bloc.jidStorageKey.value], equals(validJid));
        expect(
          credentialStorage[bloc.passwordStorageKey.value],
          equals(validPassword),
        );
        expect(
          credentialStorage['remember_me_choice'],
          equals(false.toString()),
        );
        verifyNever(
          () => mockEmailService.clearStoredCredentials(
            jid: validJid,
            preserveActiveSession: false,
          ),
        );
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Database secrets without stored login skip auto-login but keep secrets intact.',
      setUp: () {
        credentialStorage['${validJid}_database_prefix'] = 'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
      },
      build: () => bloc,
      act: (bloc) => bloc.login(),
      expect: () => const [],
      verify: (_) {
        expect(
          credentialStorage['${validJid}_database_prefix'],
          equals('prefix'),
        );
        expect(
          credentialStorage['prefix_database_passphrase'],
          equals('passphrase'),
        );
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Auth failure does not persist database secrets.',
      build: () => bloc,
      act: (bloc) =>
          bloc.login(username: invalidUsername, password: invalidPassword),
      expect: () => const [
        AuthenticationLogInInProgress(),
        AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
        ),
      ],
      verify: (_) {
        expect(
          credentialStorage.keys.where(
            (key) => key.contains('database_prefix'),
          ),
          isEmpty,
        );
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Persisting with rememberMe true writes SMTP credentials atomically after success.',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      ),
      act: (bloc) => bloc.login(
        username: validUsername,
        password: validPassword,
        rememberMe: true,
      ),
      expect: () => const [
        AuthenticationLogInInProgress(),
        AuthenticationComplete(),
      ],
      verify: (bloc) {
        verify(
          () => mockEmailService.persistActiveCredentials(jid: validJid),
        ).called(1);
        verifyNever(
          () => mockEmailService.clearStoredCredentials(
            jid: any(named: 'jid'),
            preserveActiveSession: any(named: 'preserveActiveSession'),
          ),
        );
        expect(credentialStorage[bloc.jidStorageKey.value], equals(validJid));
        expect(
          credentialStorage[bloc.passwordStorageKey.value],
          equals(saltedPassword),
        );
        final prefix = credentialStorage['${validJid}_database_prefix'];
        expect(prefix, isNotNull);
        final passphraseKey = '${prefix}_database_passphrase';
        expect(credentialStorage[passphraseKey], isNotNull);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Persisting with rememberMe false keeps SMTP session only in memory and does not store credentials.',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      ),
      act: (bloc) => bloc.login(
        username: validUsername,
        password: validPassword,
        rememberMe: false,
      ),
      expect: () => const [
        AuthenticationLogInInProgress(),
        AuthenticationComplete(),
      ],
      verify: (bloc) {
        verifyNever(
          () =>
              mockEmailService.persistActiveCredentials(jid: any(named: 'jid')),
        );
        verify(
          () => mockEmailService.clearStoredCredentials(
            jid: validJid,
            preserveActiveSession: true,
          ),
        ).called(1);
        expect(credentialStorage[bloc.jidStorageKey.value], isNull);
        expect(credentialStorage[bloc.passwordStorageKey.value], isNull);
        expect(credentialStorage['${validJid}_database_prefix'], isNull);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given saved invalid credentials, automatic login emits [AuthenticationNone].',
      setUp: () {
        when(
          () => mockCredentialStore.read(key: bloc.jidStorageKey),
        ).thenAnswer((_) async => validJid);
        when(
          () => mockCredentialStore.read(key: bloc.passwordStorageKey),
        ).thenAnswer((_) async => invalidPassword);
        credentialStorage['${validJid}_database_prefix'] = 'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
      },
      build: () => bloc,
      act: (bloc) => bloc.login(),
      expect: () => [
        const AuthenticationLogInInProgress(),
        const AuthenticationNone(),
      ],
      verify: (bloc) {
        verifyNever(
          () => mockCredentialStore.write(
            key: bloc.jidStorageKey,
            value: validJid,
          ),
        );
        verifyNever(
          () => mockCredentialStore.write(
            key: bloc.passwordStorageKey,
            value: saltedPassword,
          ),
        );
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'After auto-login invalid credentials, manual login starts immediately.',
      setUp: () {
        when(
          () => mockCredentialStore.read(key: bloc.jidStorageKey),
        ).thenAnswer((_) async => validJid);
        when(
          () => mockCredentialStore.read(key: bloc.passwordStorageKey),
        ).thenAnswer((_) async => invalidPassword);
        credentialStorage['${validJid}_database_prefix'] = 'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
      },
      build: () => bloc,
      act: (bloc) async {
        await bloc.login();
        await bloc.login(username: validUsername, password: validPassword);
      },
      expect: () => const [
        AuthenticationLogInInProgress(),
        AuthenticationNone(),
        AuthenticationLogInInProgress(),
        AuthenticationComplete(),
      ],
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Without saved credentials, automatic login emits [AuthenticationNone].',
      build: () => bloc,
      act: (bloc) => bloc.login(),
      expect: () => const [],
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Preserves authenticated session on network failures.',
      setUp: () {
        credentialStorage['jid'] = validJid;
        credentialStorage['password'] = validPassword;
        credentialStorage['password_prehashed_v1'] = true.toString();
        credentialStorage['${validJid}_database_prefix'] = 'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
        when(
          () => mockXmppService.connect(
            jid: any(named: 'jid'),
            password: any(named: 'password'),
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            preHashed: any(named: 'preHashed'),
            reuseExistingSession: any(named: 'reuseExistingSession'),
            endpoint: any(named: 'endpoint'),
          ),
        ).thenThrow(XmppNetworkException());
        when(
          () => mockXmppService.resumeOfflineSession(
            jid: any(named: 'jid'),
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
          ),
        ).thenAnswer((_) async {});
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
      ),
      act: (bloc) => bloc.login(),
      expect: () => const [],
      verify: (bloc) {
        verify(
          () => mockXmppService.resumeOfflineSession(
            jid: validJid,
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
          ),
        ).called(1);
        expect(bloc.state, isA<AuthenticationComplete>());
      },
    );

    late StreamController<DeltaChatException> authFailureController;

    blocTest<AuthenticationCubit, AuthenticationState>(
      'SMTP runtime auth failure triggers credential wipe and failure state.',
      setUp: () {
        credentialStorage['jid'] = validJid;
        credentialStorage['password'] = validPassword;
        credentialStorage['password_prehashed_v1'] = true.toString();
        authFailureController = StreamController<DeltaChatException>.broadcast(
          sync: true,
        );
        when(
          () => mockEmailService.authFailureStream,
        ).thenAnswer((_) => authFailureController.stream);
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
      ),
      act: (bloc) async {
        authFailureController.add(
          const DeltaAuthException(
            operation: 'email transport',
            message: 'bad password',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
      expect: () => [
        const AuthenticationNone(),
        const AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.emailAuthFailed),
        ),
      ],
      verify: (bloc) {
        expect(credentialStorage[bloc.jidStorageKey.value], equals(validJid));
        expect(
          credentialStorage[bloc.passwordStorageKey.value],
          equals(validPassword),
        );
        verify(
          () => mockEmailService.shutdown(
            jid: any(named: 'jid'),
            clearCredentials: false,
          ),
        ).called(2);
      },
      tearDown: () async {
        await authFailureController.close();
      },
    );
  });

  group('signup', () {
    const captchaId = 'captcha-id';
    const captchaText = 'captcha';

    setUp(() {
      when(
        () => mockHttpClient.post(
          _registrationMatcher(),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => Response('', 200));
      when(
        () => mockHttpClient.post(
          any(
            that: predicate(
              (Uri uri) =>
                  uri.path.contains('/register/delete/') ||
                  uri.path.contains('/register/unregister/'),
            ),
          ),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => Response('', 200));
      when(
        () => mockXmppService.connect(
          jid: any(named: 'jid'),
          password: any(named: 'password'),
          databasePrefix: any(named: 'databasePrefix'),
          databasePassphrase: any(named: 'databasePassphrase'),
          preHashed: any(named: 'preHashed'),
          reuseExistingSession: any(named: 'reuseExistingSession'),
          endpoint: any(named: 'endpoint'),
        ),
      ).thenThrow(XmppAuthenticationException());
    });

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Emits AuthenticationCompleteFromSignup after successful signup.',
      setUp: () {
        when(
          () => mockXmppService.connect(
            jid: validJid,
            password: validPassword,
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            preHashed: any(named: 'preHashed'),
            reuseExistingSession: any(named: 'reuseExistingSession'),
            endpoint: any(named: 'endpoint'),
          ),
        ).thenAnswer((_) async => saltedPassword);
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
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
        passwordWasSkipped: false,
        welcomeTitle: signupWelcomeTitle,
        welcomeBody: signupWelcomeBody,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(),
        AuthenticationLogInInProgress(fromSignup: true),
        AuthenticationCompleteFromSignup(),
      ],
    );

    test('syncSignupWelcomeMessage seeds the welcome chat message.', () async {
      const welcomeChatJid = 'axichat@welcome.axichat.invalid';
      const welcomeTitle = 'Axichat';
      const welcomeBody =
          'Welcome to Axichat!\n\n'
          'It is still under active development and per-user storage limits '
          'are very low, so avoid relying on it for important business at '
          'the moment.\n\n'
          'Many features are available by tapping on message bubbles; '
          'try tapping this one!\n\n'
          'If you find any bugs, please report them at '
          'https://github.com/axichat/axichat/issues so I can fix them!';
      final bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      );
      when(
        () => mockXmppService.database,
      ).thenAnswer((_) async => mockDatabase);
      when(
        () => mockDatabase.getMessageByStanzaID(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockDatabase.saveMessage(any(), chatType: any(named: 'chatType')),
      ).thenAnswer((_) async {});
      when(() => mockDatabase.updateMessage(any())).thenAnswer((_) async {});
      when(
        () => mockDatabase.getChat(welcomeChatJid),
      ).thenAnswer((_) async => Chat.fromJid(welcomeChatJid));
      when(() => mockDatabase.updateChat(any())).thenAnswer((_) async {});

      await bloc.syncSignupWelcomeMessage(
        allowInsert: true,
        title: welcomeTitle,
        body: welcomeBody,
      );

      final savedMessage =
          verify(() => mockDatabase.saveMessage(captureAny())).captured.single
              as Message;
      expect(savedMessage.senderJid, equals(welcomeChatJid));
      expect(savedMessage.chatJid, equals(welcomeChatJid));
      expect(savedMessage.body, equals(welcomeBody));
      expect(savedMessage.htmlBody, isNull);
      final updatedChat =
          verify(() => mockDatabase.updateChat(captureAny())).captured.single
              as Chat;
      expect(updatedChat.title, equals(welcomeTitle));
      expect(updatedChat.contactDisplayName, equals(welcomeTitle));
    });

    test(
      'syncSignupWelcomeMessage recreates the welcome chat when the message exists but the chat is missing.',
      () async {
        const welcomeChatJid = 'axichat@welcome.axichat.invalid';
        const welcomeStanzaId = 'signup-welcome.axichat';
        const welcomeTitle = 'Axichat';
        const welcomeBody = 'Welcome to Axichat!';
        final existingMessage = Message(
          stanzaID: welcomeStanzaId,
          senderJid: welcomeChatJid,
          chatJid: welcomeChatJid,
          body: welcomeBody,
          timestamp: DateTime.utc(2026, 3, 6),
          acked: true,
          received: true,
        );
        final bloc = AuthenticationCubit(
          credentialStore: mockCredentialStore,
          initialEndpointConfig: const EndpointConfig(),
          xmppService: mockXmppService,
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
        );
        when(
          () => mockDatabase.getMessageByStanzaID(welcomeStanzaId),
        ).thenAnswer((_) async => existingMessage);
        when(
          () => mockDatabase.getChat(welcomeChatJid),
        ).thenAnswer((_) async => null);

        await bloc.syncSignupWelcomeMessage(
          allowInsert: true,
          title: welcomeTitle,
          body: welcomeBody,
        );

        verifyNever(() => mockDatabase.saveMessage(any()));
        final createdChat =
            verify(() => mockDatabase.createChat(captureAny())).captured.single
                as Chat;
        expect(createdChat.jid, equals(welcomeChatJid));
        expect(createdChat.title, equals(welcomeTitle));
        expect(createdChat.contactDisplayName, equals(welcomeTitle));
        expect(createdChat.contactJid, equals(welcomeChatJid));
      },
    );

    test(
      'syncSignupWelcomeMessage updates the existing welcome message body and clears html.',
      () async {
        const welcomeChatJid = 'axichat@welcome.axichat.invalid';
        const welcomeStanzaId = 'signup-welcome.axichat';
        const welcomeTitle = 'Axichat';
        const welcomeBody =
            'Welcome to Axichat!\n\n'
            'It is still under active development and per-user storage limits '
            'are very low, so avoid relying on it for important business at '
            'the moment.\n\n'
            'Many features are available by tapping on message bubbles; '
            'try tapping this one!\n\n'
            'If you find any bugs, please report them at '
            'https://github.com/axichat/axichat/issues so I can fix them!';
        final existingMessage = Message(
          stanzaID: welcomeStanzaId,
          senderJid: welcomeChatJid,
          chatJid: welcomeChatJid,
          body: 'Old welcome copy',
          htmlBody: '<p>Old welcome copy</p>',
          timestamp: DateTime.utc(2026, 3, 6),
        );
        final bloc = AuthenticationCubit(
          credentialStore: mockCredentialStore,
          initialEndpointConfig: const EndpointConfig(),
          xmppService: mockXmppService,
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
        );
        when(
          () => mockXmppService.database,
        ).thenAnswer((_) async => mockDatabase);
        when(
          () => mockDatabase.getMessageByStanzaID(welcomeStanzaId),
        ).thenAnswer((_) async => existingMessage);
        when(() => mockDatabase.updateMessage(any())).thenAnswer((_) async {});
        when(
          () => mockDatabase.getChat(welcomeChatJid),
        ).thenAnswer((_) async => Chat.fromJid(welcomeChatJid));
        when(() => mockDatabase.updateChat(any())).thenAnswer((_) async {});

        await bloc.syncSignupWelcomeMessage(
          allowInsert: true,
          title: welcomeTitle,
          body: welcomeBody,
        );

        verifyNever(() => mockDatabase.saveMessage(any()));
        final updatedMessage =
            verify(
                  () => mockDatabase.updateMessage(captureAny()),
                ).captured.single
                as Message;
        expect(updatedMessage.stanzaID, equals(welcomeStanzaId));
        expect(updatedMessage.htmlBody, isNull);
        expect(updatedMessage.body, equals(welcomeBody));
      },
    );

    test(
      'syncSignupWelcomeMessage skips insert when allowInsert is false and the message is missing.',
      () async {
        const welcomeTitle = 'Axichat';
        const welcomeBody = 'Localized welcome body';
        final bloc = AuthenticationCubit(
          credentialStore: mockCredentialStore,
          initialEndpointConfig: const EndpointConfig(),
          xmppService: mockXmppService,
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
        );
        when(
          () => mockXmppService.database,
        ).thenAnswer((_) async => mockDatabase);
        when(
          () => mockDatabase.getMessageByStanzaID(any()),
        ).thenAnswer((_) async => null);

        await bloc.syncSignupWelcomeMessage(
          allowInsert: false,
          title: welcomeTitle,
          body: welcomeBody,
        );

        verifyNever(() => mockDatabase.saveMessage(any()));
        verifyNever(() => mockDatabase.updateMessage(any()));
        verifyNever(() => mockDatabase.getChat(any()));
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Rolls back the provisioned email account after captcha rejection.',
      setUp: () {
        when(
          () => mockHttpClient.post(
            _registrationMatcher(),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => Response(
            'There was an error registering the account: Incorrect captcha',
            400,
          ),
        );
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
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
        passwordWasSkipped: false,
        welcomeTitle: signupWelcomeTitle,
        welcomeBody: signupWelcomeBody,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(),
        AuthenticationSignupFailure(AuthRawMessage('Incorrect captcha')),
      ],
      verify: (_) {
        verify(
          () => mockProvisioningClient.deleteAccount(
            email: 'prov@axi.im',
            password: validPassword,
          ),
        ).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Rolls back the account if login fails after registration.',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
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
        passwordWasSkipped: false,
        welcomeTitle: signupWelcomeTitle,
        welcomeBody: signupWelcomeBody,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(),
        AuthenticationLogInInProgress(fromSignup: true),
        AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
        ),
      ],
      verify: (bloc) {
        verify(
          () => mockHttpClient.post(
            any(
              that: predicate(
                (Uri uri) =>
                    uri.path.contains('/register/delete/') ||
                    uri.path.contains('/register/unregister/'),
              ),
            ),
            body: any(named: 'body'),
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
        when(
          () => mockHttpClient.post(
            any(
              that: predicate(
                (Uri uri) =>
                    uri.path.contains('/register/delete/') ||
                    uri.path.contains('/register/unregister/'),
              ),
            ),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => Response('', 500));
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
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
        passwordWasSkipped: false,
        welcomeTitle: signupWelcomeTitle,
        welcomeBody: signupWelcomeBody,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(),
        AuthenticationLogInInProgress(fromSignup: true),
        AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
        ),
      ],
      verify: (bloc) {
        verify(
          () => mockCredentialStore.write(
            key: bloc.pendingSignupRollbacksKey,
            value: any(named: 'value'),
          ),
        ).called(2);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Never sends rollback for accounts that completed authentication.',
      setUp: () {
        credentialStorage['${validJid}_database_prefix'] = 'prefix';
        credentialStorage['validusername@axi.im_database_prefix'] = 'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
        when(
          () => mockHttpClient.post(
            _registrationMatcher(),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => Response('', 200));
        when(
          () => mockXmppService.connect(
            jid: validJid,
            password: validPassword,
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            preHashed: any(named: 'preHashed'),
            reuseExistingSession: any(named: 'reuseExistingSession'),
            endpoint: any(named: 'endpoint'),
          ),
        ).thenThrow(XmppAuthenticationException());
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
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
        passwordWasSkipped: false,
        welcomeTitle: signupWelcomeTitle,
        welcomeBody: signupWelcomeBody,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(),
        AuthenticationLogInInProgress(fromSignup: true),
        AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
        ),
      ],
      verify: (_) {
        verifyNever(
          () => mockProvisioningClient.deleteAccount(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
        expect(credentialStorage['pending_signup_rollbacks'], isNull);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Prevents signup until pending cleanup for username completes.',
      setUp: () {
        credentialStorage['pending_signup_rollbacks'] = jsonEncode([
          {
            'username': validUsername,
            'host': EndpointConfig.defaultDomain,
            'password': 'stale',
            'createdAt': '2024-01-01T00:00:00.000Z',
            'expiresAt': '2099-01-01T00:00:00.000Z',
            'email': 'user@axi.im',
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
        initialEndpointConfig: const EndpointConfig(),
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
        passwordWasSkipped: false,
        welcomeTitle: signupWelcomeTitle,
        welcomeBody: signupWelcomeBody,
      ),
      expect: () => [
        const AuthenticationSignUpInProgress(),
        const AuthenticationSignupFailure(
          AuthKeyMessage(AuthMessageKey.signupCleanupInProgress),
          isCleanupBlocked: true,
        ),
      ],
      verify: (bloc) {
        verifyNever(
          () => mockHttpClient.post(
            _registrationMatcher(),
            body: any(named: 'body'),
          ),
        );
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Flushes pending cleanup before retrying signup with the same username.',
      setUp: () {
        credentialStorage['pending_signup_rollbacks'] = jsonEncode([
          {
            'username': validUsername,
            'host': EndpointConfig.defaultDomain,
            'password': 'stale',
            'createdAt': '2024-01-01T00:00:00.000Z',
            'expiresAt': '2099-01-01T00:00:00.000Z',
          },
        ]);
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
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
        passwordWasSkipped: false,
        welcomeTitle: signupWelcomeTitle,
        welcomeBody: signupWelcomeBody,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(),
        AuthenticationLogInInProgress(fromSignup: true),
        AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
        ),
      ],
      verify: (bloc) {
        final payload = credentialStorage['pending_signup_rollbacks'];
        expect(payload, isNotNull);
        final decoded = jsonDecode(payload!) as List<dynamic>;
        expect(decoded, hasLength(1));
        final entry = decoded.first as Map<String, dynamic>;
        expect(entry['username'], equals(validUsername.toLowerCase()));
        expect(entry['password'], equals(validPassword));
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Surfaces email signup conflicts as account already exists.',
      setUp: () {
        when(
          () => mockProvisioningClient.createAccount(
            localpart: any(named: 'localpart'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const provisioning.EmailProvisioningApiException(
            code: provisioning.EmailProvisioningApiErrorCode.alreadyExists,
            statusCode: 409,
          ),
        );
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
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
        passwordWasSkipped: false,
        welcomeTitle: signupWelcomeTitle,
        welcomeBody: signupWelcomeBody,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(),
        AuthenticationSignupFailure(
          AuthKeyMessage(AuthMessageKey.accountAlreadyExists),
        ),
      ],
      verify: (_) {
        verifyNever(
          () => mockHttpClient.post(
            _registrationMatcher(),
            body: any(named: 'body'),
          ),
        );
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Surfaces ejabberd signup conflicts as account already exists.',
      setUp: () {
        when(
          () => mockHttpClient.post(
            _registrationMatcher(),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => Response(
            'There was an error registering the account: The account already exists',
            409,
          ),
        );
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(smtpEnabled: false),
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
        passwordWasSkipped: false,
        welcomeTitle: signupWelcomeTitle,
        welcomeBody: signupWelcomeBody,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(),
        AuthenticationSignupFailure(
          AuthKeyMessage(AuthMessageKey.accountAlreadyExists),
        ),
      ],
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Surfaces email signup validation details instead of flattening them.',
      setUp: () {
        when(
          () => mockProvisioningClient.createAccount(
            localpart: any(named: 'localpart'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const provisioning.EmailProvisioningApiException(
            code: provisioning.EmailProvisioningApiErrorCode.invalidResponse,
            statusCode: 422,
            debugMessage: 'Mailbox policy rejected this username.',
          ),
        );
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
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
        passwordWasSkipped: false,
        welcomeTitle: signupWelcomeTitle,
        welcomeBody: signupWelcomeBody,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(),
        AuthenticationSignupFailure(
          AuthRawMessage('Mailbox policy rejected this username.'),
        ),
      ],
    );
  });

  group('changePassword', () {
    blocTest<AuthenticationCubit, AuthenticationState>(
      'Surfaces XMPP account-not-found details from 404 responses.',
      setUp: () {
        when(
          () => mockHttpClient.post(
            _changePasswordMatcher(),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => Response(
            "There was an error changing the password: The account doesn't exist",
            404,
          ),
        );
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(smtpEnabled: false),
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      ),
      act: (bloc) => bloc.changePassword(
        username: validUsername,
        host: EndpointConfig.defaultDomain,
        oldPassword: validPassword,
        password: 'newPassword',
        password2: 'newPassword',
      ),
      expect: () => const [
        AuthenticationPasswordChangeInProgress(),
        AuthenticationPasswordChangeFailure(
          AuthKeyMessage(AuthMessageKey.accountNotFound),
        ),
      ],
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Emits partial success when email reconnect remains pending.',
      setUp: () {
        when(
          () => mockHttpClient.post(
            _changePasswordMatcher(),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => Response('', 200));
        when(
          () => mockEmailService.updatePassword(
            jid: any(named: 'jid'),
            displayName: any(named: 'displayName'),
            password: any(named: 'password'),
            persistCredentials: any(named: 'persistCredentials'),
          ),
        ).thenAnswer((_) async => EmailPasswordRefreshResult.reconnectPending);
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
      ),
      act: (bloc) => bloc.changePassword(
        username: validUsername,
        host: EndpointConfig.defaultDomain,
        oldPassword: validPassword,
        password: 'newPassword',
        password2: 'newPassword',
      ),
      expect: () => const [
        AuthenticationPasswordChangeInProgress(),
        AuthenticationPasswordChangeSuccess(
          AuthKeyMessage(AuthMessageKey.passwordChangeReconnectPending),
        ),
      ],
    );
  });

  group('unregister', () {
    setUp(() {
      when(
        () => mockHttpClient.post(any(), body: any(named: 'body')),
      ).thenAnswer((_) async => Response('', 200));
    });

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Logs out after successful unregister.',
      setUp: () {
        when(() => mockEmailService.currentAccount(validJid)).thenAnswer(
          (_) async => const EmailAccount(
            address: 'user@axi.im',
            password: validPassword,
          ),
        );
        when(
          () => mockProvisioningClient.deleteAccount(
            email: 'user@axi.im',
            password: validPassword,
          ),
        ).thenAnswer((_) async {});
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
      ),
      act: (bloc) => bloc.unregister(
        username: validUsername,
        host: EndpointConfig.defaultDomain,
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
        verify(() => mockXmppService.clearSessionTokens()).called(1);
        verify(() => mockXmppService.disconnect()).called(1);
        verify(
          () => mockEmailService.shutdown(
            jid: any(named: 'jid'),
            clearCredentials: clearEmailCredentialsOnLogout,
          ),
        ).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Uses the stored device-only password when unregistering a skipped-password account.',
      setUp: () {
        credentialStorage['password_skipped_v1'] = true.toString();
        credentialStorage['skipped_password_raw_v1'] = validPassword;
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(smtpEnabled: false),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
      ),
      act: (bloc) async {
        await Future<void>.delayed(Duration.zero);
        await bloc.unregister(
          username: validUsername,
          host: EndpointConfig.defaultDomain,
          password: '',
        );
      },
      expect: () => const [
        AuthenticationUnregisterInProgress(),
        AuthenticationNone(),
      ],
      verify: (_) {
        verify(
          () => mockHttpClient.post(
            any(
              that: predicate(
                (Uri uri) =>
                    uri.path.contains('/register/delete/') ||
                    uri.path.contains('/register/unregister/'),
              ),
            ),
            body: {
              'username': validUsername,
              'host': EndpointConfig.defaultDomain,
              'password': validPassword,
            },
          ),
        ).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Surfaces XMPP delete details from 404 responses.',
      setUp: () {
        when(
          () => mockHttpClient.post(any(), body: any(named: 'body')),
        ).thenAnswer(
          (_) async => Response(
            "There was an error deleting the account: The account doesn't exist",
            404,
          ),
        );
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(smtpEnabled: false),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
      ),
      act: (bloc) => bloc.unregister(
        username: validUsername,
        host: EndpointConfig.defaultDomain,
        password: validPassword,
      ),
      expect: () => const [
        AuthenticationUnregisterInProgress(),
        AuthenticationUnregisterFailure(
          AuthRawMessage("The account doesn't exist"),
        ),
      ],
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Surfaces email delete details instead of treating them as success.',
      setUp: () {
        when(() => mockEmailService.currentAccount(validJid)).thenAnswer(
          (_) async => const EmailAccount(
            address: 'user@axi.im',
            password: validPassword,
          ),
        );
        when(
          () => mockProvisioningClient.deleteAccount(
            email: 'user@axi.im',
            password: validPassword,
          ),
        ).thenThrow(
          const provisioning.EmailProvisioningApiException(
            code: provisioning.EmailProvisioningApiErrorCode.invalidResponse,
            statusCode: 422,
            debugMessage:
                'Email account cannot be deleted while aliases exist.',
          ),
        );
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
      ),
      act: (bloc) => bloc.unregister(
        username: validUsername,
        host: EndpointConfig.defaultDomain,
        password: validPassword,
      ),
      expect: () => const [
        AuthenticationUnregisterInProgress(),
        AuthenticationUnregisterFailure(
          AuthRawMessage(
            'Email account cannot be deleted while aliases exist.',
          ),
        ),
      ],
      verify: (_) {
        verifyNever(() => mockXmppService.disconnect());
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
      when(() => mockHttpClient.get(any(that: isA<Uri>()))).thenAnswer((
        invocation,
      ) async {
        final uri = invocation.positionalArguments.first as Uri;
        if (uri.toString().contains('5BAA6')) {
          return Response('1E4C9B93F3F0682250B6CF8331B7EE68FD8:10\r\n', 200);
        }
        return Response('', 200);
      });
      bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
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
      when(
        () => mockCredentialStore.delete(key: any(named: 'key')),
      ).thenAnswer((_) async => true);
      when(
        () => mockCredentialStore.delete(key: any(named: 'key')),
      ).thenAnswer((_) async => true);
      when(
        () => mockEmailService.shutdown(
          jid: any(named: 'jid'),
          clearCredentials: any(named: 'clearCredentials'),
        ),
      ).thenAnswer((_) async {});
    });

    blocTest<AuthenticationCubit, AuthenticationState>(
      'If authentication is not complete, does nothing.',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      ),
      act: (bloc) => bloc.logout(),
      expect: () => [],
      verify: (bloc) {
        verifyNever(() => mockCredentialStore.delete(key: bloc.jidStorageKey));
        verifyNever(
          () => mockCredentialStore.delete(key: bloc.passwordStorageKey),
        );
        verifyNever(() => mockXmppService.disconnect());
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Automatic logout disconnects the xmpp service without forgetting credentials and emits [AuthenticationNone].',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
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
          () => mockCredentialStore.delete(key: bloc.passwordStorageKey),
        );
        verify(() => mockXmppService.disconnect()).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'User initiated logout disconnects the xmpp service, forgets credentials and emits [AuthenticationNone].',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        homeRefreshSyncService: mockHomeRefreshSyncService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
      ),
      act: (bloc) => bloc.logout(severity: LogoutSeverity.normal),
      expect: () => [const AuthenticationNone()],
      verify: (bloc) {
        verify(
          () => mockCredentialStore.delete(key: bloc.jidStorageKey),
        ).called(1);
        verify(
          () => mockCredentialStore.delete(key: bloc.passwordStorageKey),
        ).called(1);
        verify(
          () =>
              mockCredentialStore.delete(key: bloc.passwordPreHashedStorageKey),
        ).called(1);
        verify(() => mockXmppService.clearSessionTokens()).called(1);
        verify(() => mockHomeRefreshSyncService.start()).called(1);
        verify(() => mockHomeRefreshSyncService.close()).called(2);
        verify(() => mockXmppService.disconnect()).called(1);
      },
    );

    test(
      'User initiated logout waits for teardown before emitting AuthenticationNone.',
      () async {
        final shutdownCompleter = Completer<void>();
        final disconnectCompleter = Completer<void>();
        when(
          () => mockEmailService.shutdown(
            jid: any(named: 'jid'),
            clearCredentials: any(named: 'clearCredentials'),
          ),
        ).thenAnswer((_) => shutdownCompleter.future);
        when(
          () => mockXmppService.disconnect(),
        ).thenAnswer((_) => disconnectCompleter.future);

        final bloc = AuthenticationCubit(
          credentialStore: mockCredentialStore,
          initialEndpointConfig: const EndpointConfig(),
          xmppService: mockXmppService,
          emailService: mockEmailService,
          homeRefreshSyncService: mockHomeRefreshSyncService,
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
          initialState: const AuthenticationComplete(),
        );
        final emittedStates = <AuthenticationState>[];
        final subscription = bloc.stream.listen(emittedStates.add);

        final logoutFuture = bloc.logout(severity: LogoutSeverity.normal);
        await Future<void>.delayed(Duration.zero);
        expect(emittedStates, isEmpty);
        verify(() => mockHomeRefreshSyncService.close()).called(1);

        shutdownCompleter.complete();
        await Future<void>.delayed(Duration.zero);
        expect(emittedStates, isEmpty);

        disconnectCompleter.complete();
        await logoutFuture;
        await Future<void>.delayed(Duration.zero);
        expect(emittedStates, [const AuthenticationNone()]);

        await subscription.cancel();
        await bloc.close();
      },
    );

    test(
      'Connectivity error does not force automatic logout for authenticated sessions.',
      () async {
        final connectivityController =
            StreamController<ConnectionState>.broadcast();
        when(
          () => mockXmppService.connectivityStream,
        ).thenAnswer((_) => connectivityController.stream);
        when(
          () => mockXmppService.hasInMemoryReconnectContext,
        ).thenReturn(false);

        final bloc = AuthenticationCubit(
          credentialStore: mockCredentialStore,
          initialEndpointConfig: const EndpointConfig(),
          xmppService: mockXmppService,
          emailService: mockEmailService,
          homeRefreshSyncService: mockHomeRefreshSyncService,
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
          initialState: const AuthenticationComplete(),
        );
        final emittedStates = <AuthenticationState>[];
        final subscription = bloc.stream.listen(emittedStates.add);

        connectivityController.add(ConnectionState.error);
        await Future<void>.delayed(Duration.zero);

        expect(emittedStates, isEmpty);
        verify(() => mockEmailService.handleNetworkLost()).called(1);

        await subscription.cancel();
        await connectivityController.close();
        await bloc.close();
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'User initiated logout clears email credentials when enabled.',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        homeRefreshSyncService: mockHomeRefreshSyncService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
      ),
      act: (bloc) => bloc.logout(severity: LogoutSeverity.normal),
      expect: () => [const AuthenticationNone()],
      verify: (_) {
        verify(
          () => mockEmailService.shutdown(
            jid: any(named: 'jid'),
            clearCredentials: clearEmailCredentialsOnLogout,
          ),
        ).called(1);
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
