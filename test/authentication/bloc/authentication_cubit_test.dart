import 'dart:async';
import 'dart:convert';

import 'package:axichat/main.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/generate_random.dart';
import 'package:axichat/src/common/anti_abuse_sync.dart';
import 'package:axichat/src/common/startup/auth_bootstrap.dart';
import 'package:axichat/src/email/models/email_account.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/authentication/bloc/email_provisioning_client.dart'
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
const signupWelcomeBody =
    'Welcome to the next evolution of messaging and email.';
const _welcomeChatJid = 'axichat@welcome.axichat.invalid';
const _welcomeStanzaId = 'signup-welcome.axichat';
const bool clearEmailCredentialsOnLogout = true;
const _xmppOnlyEndpointConfig = EndpointConfig(smtpEnabled: false);
const _signupEndpointConfig = EndpointConfig(domain: 'selfhosted.example');
const _signupXmppOnlyEndpointConfig = EndpointConfig(
  domain: 'selfhosted.example',
  smtpEnabled: false,
);
const _signupJid = '$validUsername@selfhosted.example';

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
    registerFallbackValue(EmailShutdownMode.graceful);
    registerFallbackValue(
      SpamSyncUpdate(
        address: 'fallback@example.com',
        isSpam: false,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        sourceId: syncLegacySourceId,
        origin: SyncOrigin.local,
      ),
    );
    registerFallbackValue(
      AddressBlockSyncUpdate(
        address: 'fallback@example.com',
        blocked: false,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        sourceId: syncLegacySourceId,
        origin: SyncOrigin.local,
      ),
    );
  });

  late Client mockHttpClient;
  late MockEmailProvisioningClient mockProvisioningClient;
  late MockEmailService mockEmailService;
  late Map<String, String?> credentialStorage;
  late AppLocalizations localizations;

  setUp(() {
    mockXmppService = MockXmppService();
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockDatabase = MockXmppDatabase();
    mockEmailService = MockEmailService();
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
    when(
      () => mockEmailService.applySpamSyncUpdate(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockEmailService.applyEmailBlocklistSyncUpdate(any()),
    ).thenAnswer((_) async {});
    when(() => mockEmailService.hasActiveSession).thenReturn(false);
    when(() => mockEmailService.hasInMemoryReconnectContext).thenReturn(true);
    when(
      () => mockEmailService.canReconnectConfiguredSession(
        jid: any(named: 'jid'),
      ),
    ).thenAnswer((_) async => true);
    when(() => mockXmppService.hasInMemoryReconnectContext).thenReturn(true);
    when(
      () => mockXmppService.connectionState,
    ).thenReturn(ConnectionState.notConnected);
    when(() => mockXmppService.hasConnectionSettings).thenReturn(true);
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
    when(
      () => mockEmailService.handleForegroundResumeNetworkAvailable(),
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
    when(
      () => mockXmppService.spamSyncUpdateStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockXmppService.addressBlockSyncUpdateStream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockXmppService.connected).thenReturn(false);
    when(() => mockXmppService.databasesInitialized).thenReturn(false);
    when(() => mockXmppService.myJid).thenReturn(null);
    when(() => mockXmppService.activeDatabasePrefix).thenReturn(null);
    when(() => mockXmppService.localizations).thenReturn(localizations);
    when(() => mockXmppService.database).thenAnswer((_) async => mockDatabase);
    when(
      () => mockXmppService.syncSignupWelcomeMessage(
        allowInsert: any(named: 'allowInsert'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockXmppService.cleanupUnregisterLocalData(
        jid: any(named: 'jid'),
        databasePrefix: any(named: 'databasePrefix'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockXmppService.setClientState(any())).thenAnswer((_) async {});
    when(() => mockXmppService.clearSessionTokens()).thenAnswer((_) async {});
    when(
      () => mockXmppService.pauseAutomaticReconnect(),
    ).thenAnswer((_) async {});
    for (final trigger in ReconnectTrigger.values) {
      when(
        () => mockXmppService.requestReconnect(trigger),
      ).thenAnswer((_) async => true);
    }
    when(
      () => mockXmppService.ensureForegroundSocketIfActive(),
    ).thenAnswer((_) async {});
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
    when(() => mockEmailService.clearSessionCredentials()).thenReturn(null);
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
      () => mockEmailService.shutdown(
        jid: any(named: 'jid'),
        clearCredentials: any(named: 'clearCredentials'),
        mode: any(named: 'mode'),
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
        initialEndpointConfig: _xmppOnlyEndpointConfig,
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
        const AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        const AuthenticationComplete(config: _xmppOnlyEndpointConfig),
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
        initialEndpointConfig: _xmppOnlyEndpointConfig,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        authRequestTimeout: const Duration(milliseconds: 1),
      ),
      act: (bloc) =>
          bloc.login(username: validUsername, password: validPassword),
      wait: const Duration(milliseconds: 20),
      expect: () => const [
        AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.genericError),
          config: _xmppOnlyEndpointConfig,
        ),
      ],
      verify: (bloc) {
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
        const AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        const AuthenticationComplete(config: _xmppOnlyEndpointConfig),
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
      'Manual login clears pending partial-unregister state for the same account.',
      setUp: () {
        credentialStorage['partial_unregister_jid_v1'] = validJid;
        credentialStorage['partial_unregister_database_prefix_v1'] =
            'pending-prefix';
      },
      build: () => bloc,
      act: (bloc) =>
          bloc.login(username: validUsername, password: validPassword),
      expect: () => [
        const AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        const AuthenticationComplete(config: _xmppOnlyEndpointConfig),
      ],
      verify: (bloc) {
        expect(credentialStorage['partial_unregister_jid_v1'], isNull);
        expect(
          credentialStorage['partial_unregister_database_prefix_v1'],
          isNull,
        );
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given invalid username and password, emits [AuthenticationFailure].',
      build: () => bloc,
      act: (bloc) =>
          bloc.login(username: invalidUsername, password: invalidPassword),
      expect: () => [
        const AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        const AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
          config: _xmppOnlyEndpointConfig,
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
        const AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        const AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
          config: _xmppOnlyEndpointConfig,
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
        const AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        const AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
          config: _xmppOnlyEndpointConfig,
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
        const AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        const AuthenticationComplete(config: _xmppOnlyEndpointConfig),
      ],
      verify: (bloc) {
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
        const AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        const AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.usernamePasswordMismatch),
          config: _xmppOnlyEndpointConfig,
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
        const AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        const AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.usernamePasswordMismatch),
          config: _xmppOnlyEndpointConfig,
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
        const AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        const AuthenticationComplete(config: _xmppOnlyEndpointConfig),
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
        ).thenThrow(const EmailProvisioningNetworkUnavailableException());
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
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
      verify: (bloc) {
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
        verify(() => mockEmailService.handleNetworkAvailable()).called(1);
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
        AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
          config: _xmppOnlyEndpointConfig,
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
        const AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        const AuthenticationNone(config: _xmppOnlyEndpointConfig),
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
        AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        AuthenticationNone(config: _xmppOnlyEndpointConfig),
        AuthenticationLogInInProgress(config: _xmppOnlyEndpointConfig),
        AuthenticationComplete(config: _xmppOnlyEndpointConfig),
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
            password: any(named: 'password'),
            preHashed: any(named: 'preHashed'),
            endpoint: any(named: 'endpoint'),
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
            password: validPassword,
            preHashed: true,
            endpoint: any(named: 'endpoint'),
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
            mode: EmailShutdownMode.logout,
          ),
        ).called(1);
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
      'Rejects default axi.im signup before provisioning or registration.',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        allowDefaultSignupEndpoint: false,
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
        AuthenticationSignupFailure(
          AuthKeyMessage(AuthMessageKey.signupCustomEndpointRequired),
        ),
      ],
      verify: (bloc) {
        verifyNever(
          () => mockProvisioningClient.createAccount(
            localpart: any(named: 'localpart'),
            password: any(named: 'password'),
          ),
        );
        verifyNever(
          () => mockHttpClient.post(
            _registrationMatcher(),
            body: any(named: 'body'),
          ),
        );
        expect(credentialStorage[bloc.pendingSignupRollbacksKey.value], isNull);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Rejects default axi.im signup case-insensitively.',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(domain: ' AXI.IM '),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        allowDefaultSignupEndpoint: false,
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
        AuthenticationSignUpInProgress(
          config: EndpointConfig(domain: ' AXI.IM '),
        ),
        AuthenticationSignupFailure(
          AuthKeyMessage(AuthMessageKey.signupCustomEndpointRequired),
          config: EndpointConfig(domain: ' AXI.IM '),
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
      'Emits AuthenticationCompleteFromSignup after successful signup.',
      setUp: () {
        when(
          () => mockXmppService.connect(
            jid: _signupJid,
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
        initialEndpointConfig: _signupEndpointConfig,
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
        rememberMe: true,
        passwordWasSkipped: false,
        welcomeTitle: signupWelcomeTitle,
        welcomeBody: signupWelcomeBody,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(config: _signupEndpointConfig),
        AuthenticationLogInInProgress(
          fromSignup: true,
          config: _signupEndpointConfig,
        ),
        AuthenticationCompleteFromSignup(config: _signupEndpointConfig),
      ],
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Provisions email only after captcha registration succeeds.',
      setUp: () {
        final order = <String>[];
        when(
          () => mockHttpClient.post(
            _registrationMatcher(),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          order.add('registration');
          return Response('', 200);
        });
        when(
          () => mockProvisioningClient.createAccount(
            localpart: any(named: 'localpart'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async {
          order.add('email');
          return const provisioning.EmailProvisioningCredentials(
            email: 'prov@axi.im',
            password: validPassword,
          );
        });
        when(
          () => mockXmppService.connect(
            jid: _signupJid,
            password: validPassword,
            databasePrefix: any(named: 'databasePrefix'),
            databasePassphrase: any(named: 'databasePassphrase'),
            preHashed: any(named: 'preHashed'),
            reuseExistingSession: any(named: 'reuseExistingSession'),
            endpoint: any(named: 'endpoint'),
          ),
        ).thenAnswer((_) async => saltedPassword);
        addTearDown(() {
          expect(order, equals(<String>['registration', 'email']));
        });
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _signupEndpointConfig,
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
        rememberMe: true,
        passwordWasSkipped: false,
        welcomeTitle: signupWelcomeTitle,
        welcomeBody: signupWelcomeBody,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(config: _signupEndpointConfig),
        AuthenticationLogInInProgress(
          fromSignup: true,
          config: _signupEndpointConfig,
        ),
        AuthenticationCompleteFromSignup(config: _signupEndpointConfig),
      ],
    );

    test('syncSignupWelcomeMessage delegates to XmppService.', () async {
      const welcomeTitle = 'Axichat';
      const welcomeBody = 'Localized welcome body';
      final bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _signupEndpointConfig,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      );

      await bloc.syncSignupWelcomeMessage(
        allowInsert: false,
        title: welcomeTitle,
        body: welcomeBody,
      );

      verify(
        () => mockXmppService.syncSignupWelcomeMessage(
          allowInsert: false,
          title: welcomeTitle,
          body: welcomeBody,
        ),
      ).called(1);
    });

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Captcha rejection never provisions email or stages rollback.',
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
        initialEndpointConfig: _signupEndpointConfig,
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
        AuthenticationSignUpInProgress(config: _signupEndpointConfig),
        AuthenticationSignupFailure(
          AuthRawMessage('Incorrect captcha'),
          config: _signupEndpointConfig,
        ),
      ],
      verify: (bloc) {
        verifyNever(
          () => mockProvisioningClient.createAccount(
            localpart: any(named: 'localpart'),
            password: any(named: 'password'),
          ),
        );
        verifyNever(
          () => mockProvisioningClient.deleteAccount(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
        verifyNever(
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
        );
        expect(credentialStorage[bloc.pendingSignupRollbacksKey.value], isNull);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Retry after captcha rejection can complete with a clean state.',
      setUp: () {
        var registrationAttempts = 0;
        when(
          () => mockHttpClient.post(
            _registrationMatcher(),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          registrationAttempts += 1;
          return registrationAttempts == 1
              ? Response(
                  'There was an error registering the account: Incorrect captcha',
                  400,
                )
              : Response('', 200);
        });
        when(
          () => mockXmppService.connect(
            jid: _signupJid,
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
        initialEndpointConfig: _signupEndpointConfig,
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      ),
      act: (bloc) async {
        await bloc.signup(
          username: validUsername,
          password: validPassword,
          confirmPassword: validPassword,
          captchaID: captchaId,
          captcha: 'wrong-captcha',
          rememberMe: true,
          passwordWasSkipped: false,
          welcomeTitle: signupWelcomeTitle,
          welcomeBody: signupWelcomeBody,
        );
        await bloc.signup(
          username: validUsername,
          password: validPassword,
          confirmPassword: validPassword,
          captchaID: captchaId,
          captcha: captchaText,
          rememberMe: true,
          passwordWasSkipped: false,
          welcomeTitle: signupWelcomeTitle,
          welcomeBody: signupWelcomeBody,
        );
      },
      expect: () => const [
        AuthenticationSignUpInProgress(config: _signupEndpointConfig),
        AuthenticationSignupFailure(
          AuthRawMessage('Incorrect captcha'),
          config: _signupEndpointConfig,
        ),
        AuthenticationSignUpInProgress(config: _signupEndpointConfig),
        AuthenticationLogInInProgress(
          fromSignup: true,
          config: _signupEndpointConfig,
        ),
        AuthenticationCompleteFromSignup(config: _signupEndpointConfig),
      ],
      verify: (bloc) {
        verify(
          () => mockProvisioningClient.createAccount(
            localpart: validUsername,
            password: validPassword,
          ),
        ).called(1);
        expect(credentialStorage[bloc.pendingSignupRollbacksKey.value], isNull);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Uses the provisioned email password when rolling back after login failure.',
      setUp: () {
        when(
          () => mockProvisioningClient.createAccount(
            localpart: any(named: 'localpart'),
            password: any(named: 'password'),
          ),
        ).thenAnswer(
          (_) async => const provisioning.EmailProvisioningCredentials(
            email: 'prov@axi.im',
            password: 'provisioned-email-password',
          ),
        );
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _signupEndpointConfig,
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
        AuthenticationSignUpInProgress(config: _signupEndpointConfig),
        AuthenticationLogInInProgress(
          fromSignup: true,
          config: _signupEndpointConfig,
        ),
        AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
          config: _signupEndpointConfig,
        ),
      ],
      verify: (_) {
        verify(
          () => mockProvisioningClient.deleteAccount(
            email: 'prov@axi.im',
            password: 'provisioned-email-password',
          ),
        ).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Rolls back the account if login fails after registration.',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _signupEndpointConfig,
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
        rememberMe: true,
        passwordWasSkipped: false,
        welcomeTitle: signupWelcomeTitle,
        welcomeBody: signupWelcomeBody,
      ),
      expect: () => const [
        AuthenticationSignUpInProgress(config: _signupEndpointConfig),
        AuthenticationLogInInProgress(
          fromSignup: true,
          config: _signupEndpointConfig,
        ),
        AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
          config: _signupEndpointConfig,
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
        expect(credentialStorage[bloc.pendingSignupRollbacksKey.value], isNull);
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
        initialEndpointConfig: _signupEndpointConfig,
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
        AuthenticationSignUpInProgress(config: _signupEndpointConfig),
        AuthenticationLogInInProgress(
          fromSignup: true,
          config: _signupEndpointConfig,
        ),
        AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
          config: _signupEndpointConfig,
        ),
      ],
      verify: (bloc) {
        final payload = credentialStorage[bloc.pendingSignupRollbacksKey.value];
        expect(payload, isNotNull);
        final decoded = jsonDecode(payload!) as List<dynamic>;
        expect(decoded, hasLength(1));
        final entry = decoded.first as Map<String, dynamic>;
        expect(entry['email'], equals('prov@axi.im'));
        expect(entry['emailPassword'], equals(validPassword));
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Queues the provisioned email password when email rollback fails.',
      setUp: () {
        when(
          () => mockProvisioningClient.createAccount(
            localpart: any(named: 'localpart'),
            password: any(named: 'password'),
          ),
        ).thenAnswer(
          (_) async => const provisioning.EmailProvisioningCredentials(
            email: 'prov@axi.im',
            password: 'provisioned-email-password',
          ),
        );
        when(
          () => mockProvisioningClient.deleteAccount(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(Exception('offline'));
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _signupEndpointConfig,
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
        AuthenticationSignUpInProgress(config: _signupEndpointConfig),
        AuthenticationLogInInProgress(
          fromSignup: true,
          config: _signupEndpointConfig,
        ),
        AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
          config: _signupEndpointConfig,
        ),
      ],
      verify: (bloc) {
        final payload = credentialStorage[bloc.pendingSignupRollbacksKey.value];
        expect(payload, isNotNull);
        final decoded = jsonDecode(payload!) as List<dynamic>;
        expect(decoded, hasLength(1));
        final entry = decoded.first as Map<String, dynamic>;
        expect(entry['email'], equals('prov@axi.im'));
        expect(entry['password'], equals(validPassword));
        expect(entry['emailPassword'], equals('provisioned-email-password'));
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Never sends rollback for accounts that completed authentication.',
      setUp: () {
        credentialStorage['${_signupJid}_database_prefix'] = 'prefix';
        credentialStorage['validusername@selfhosted.example_database_prefix'] =
            'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
        when(
          () => mockHttpClient.post(
            _registrationMatcher(),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => Response('', 200));
        when(
          () => mockXmppService.connect(
            jid: _signupJid,
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
        initialEndpointConfig: _signupEndpointConfig,
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
        AuthenticationSignUpInProgress(config: _signupEndpointConfig),
        AuthenticationLogInInProgress(
          fromSignup: true,
          config: _signupEndpointConfig,
        ),
        AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
          config: _signupEndpointConfig,
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
            'host': _signupEndpointConfig.domain,
            'password': 'stale',
            'createdAt': '2024-01-01T00:00:00.000Z',
            'expiresAt': '2099-01-01T00:00:00.000Z',
            'email': 'user@selfhosted.example',
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
        initialEndpointConfig: _signupEndpointConfig,
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
        const AuthenticationSignUpInProgress(config: _signupEndpointConfig),
        const AuthenticationSignupFailure(
          AuthKeyMessage(AuthMessageKey.signupCleanupInProgress),
          isCleanupBlocked: true,
          config: _signupEndpointConfig,
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
            'host': _signupEndpointConfig.domain,
            'password': 'stale',
            'createdAt': '2024-01-01T00:00:00.000Z',
            'expiresAt': '2099-01-01T00:00:00.000Z',
          },
        ]);
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _signupEndpointConfig,
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
        AuthenticationSignUpInProgress(config: _signupEndpointConfig),
        AuthenticationLogInInProgress(
          fromSignup: true,
          config: _signupEndpointConfig,
        ),
        AuthenticationFailure(
          AuthKeyMessage(AuthMessageKey.invalidCredentials),
          config: _signupEndpointConfig,
        ),
      ],
      verify: (bloc) {
        expect(credentialStorage[bloc.pendingSignupRollbacksKey.value], isNull);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Surfaces email signup conflicts and rolls back registered XMPP account.',
      setUp: () {
        when(
          () => mockProvisioningClient.createAccount(
            localpart: any(named: 'localpart'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const provisioning.EmailProvisioningApiAlreadyExistsException(
            statusCode: 409,
          ),
        );
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _signupEndpointConfig,
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
        AuthenticationSignUpInProgress(config: _signupEndpointConfig),
        AuthenticationSignupFailure(
          AuthKeyMessage(AuthMessageKey.accountAlreadyExists),
          config: _signupEndpointConfig,
        ),
      ],
      verify: (bloc) {
        verify(
          () => mockHttpClient.post(
            _registrationMatcher(),
            body: any(named: 'body'),
          ),
        ).called(1);
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
        expect(credentialStorage[bloc.pendingSignupRollbacksKey.value], isNull);
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
        initialEndpointConfig: _signupXmppOnlyEndpointConfig,
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
        AuthenticationSignUpInProgress(config: _signupXmppOnlyEndpointConfig),
        AuthenticationSignupFailure(
          AuthKeyMessage(AuthMessageKey.accountAlreadyExists),
          config: _signupXmppOnlyEndpointConfig,
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
          const provisioning.EmailProvisioningApiInvalidResponseException(
            statusCode: 422,
            debugMessage: 'Mailbox policy rejected this username.',
          ),
        );
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _signupEndpointConfig,
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
        AuthenticationSignUpInProgress(config: _signupEndpointConfig),
        AuthenticationSignupFailure(
          AuthRawMessage('Mailbox policy rejected this username.'),
          config: _signupEndpointConfig,
        ),
      ],
    );
  });

  group('signup captcha', () {
    test('Default endpoint does not fetch signup captcha.', () async {
      final bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        allowDefaultSignupEndpoint: false,
      );

      expect(await bloc.fetchCaptchaSrcWithRetry(), isEmpty);
      verifyNever(() => mockHttpClient.get(_registrationMatcher()));

      await bloc.close();
    });

    test('Allowed default endpoint fetches signup captcha.', () async {
      when(() => mockHttpClient.get(_registrationMatcher())).thenAnswer(
        (_) async => Response(
          '<html><body><img src="/captcha/example" /></body></html>',
          200,
        ),
      );
      final bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      );

      expect(
        await bloc.fetchCaptchaSrcWithRetry(),
        'https://axi.im:5443/captcha/example',
      );
      verify(() => mockHttpClient.get(_registrationMatcher())).called(1);

      await bloc.close();
    });

    test('Custom endpoint fetches signup captcha.', () async {
      when(() => mockHttpClient.get(_registrationMatcher())).thenAnswer(
        (_) async => Response(
          '<html><body><img src="/captcha/example" /></body></html>',
          200,
        ),
      );
      final bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _signupEndpointConfig,
        xmppService: mockXmppService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
      );

      expect(
        await bloc.fetchCaptchaSrcWithRetry(),
        'https://selfhosted.example:5443/captcha/example',
      );
      verify(() => mockHttpClient.get(_registrationMatcher())).called(1);

      await bloc.close();
    });
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
        AuthenticationPasswordChangeInProgress(config: _xmppOnlyEndpointConfig),
        AuthenticationPasswordChangeFailure(
          AuthKeyMessage(AuthMessageKey.accountNotFound),
          config: _xmppOnlyEndpointConfig,
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
      'Successful unregister wipes local secrets and XMPP storage.',
      setUp: () {
        credentialStorage['jid'] = validJid;
        credentialStorage['password'] = validPassword;
        credentialStorage['password_prehashed_v1'] = true.toString();
        credentialStorage['${validJid}_database_prefix'] = 'prefix';
        credentialStorage['validusername@axi.im_database_prefix'] = 'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
        when(() => mockXmppService.databasesInitialized).thenReturn(true);
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
            jid: validJid,
            clearCredentials: clearEmailCredentialsOnLogout,
          ),
        ).called(1);
        verify(
          () => mockEmailService.clearStoredCredentials(
            jid: validJid,
            preserveActiveSession: false,
          ),
        ).called(1);
        verify(
          () => mockXmppService.cleanupUnregisterLocalData(
            jid: validJid,
            databasePrefix: 'prefix',
          ),
        ).called(1);
        expect(credentialStorage['jid'], isNull);
        expect(credentialStorage['password'], isNull);
        expect(credentialStorage['password_prehashed_v1'], isNull);
        expect(credentialStorage['${validJid}_database_prefix'], isNull);
        expect(
          credentialStorage['validusername@axi.im_database_prefix'],
          isNull,
        );
        expect(credentialStorage['prefix_database_passphrase'], isNull);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Skipped-password unregister uses the stored password and wipes skipped secrets.',
      setUp: () {
        credentialStorage['jid'] = validJid;
        credentialStorage['password_skipped_v1'] = true.toString();
        credentialStorage['skipped_password_raw_v1'] = validPassword;
        credentialStorage['${validJid}_database_prefix'] = 'prefix';
        credentialStorage['validusername@axi.im_database_prefix'] = 'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
        when(() => mockXmppService.databasesInitialized).thenReturn(true);
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
        verify(() => mockXmppService.clearSessionTokens()).called(1);
        verify(() => mockXmppService.disconnect()).called(1);
        expect(credentialStorage['password_skipped_v1'], isNull);
        expect(credentialStorage['skipped_password_raw_v1'], isNull);
        expect(credentialStorage['jid'], isNull);
        expect(credentialStorage['${validJid}_database_prefix'], isNull);
        expect(
          credentialStorage['validusername@axi.im_database_prefix'],
          isNull,
        );
        expect(credentialStorage['prefix_database_passphrase'], isNull);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Unregister passes the stored database prefix to XMPP cleanup even before DB init.',
      setUp: () {
        credentialStorage['jid'] = validJid;
        credentialStorage['password'] = validPassword;
        credentialStorage['password_prehashed_v1'] = true.toString();
        credentialStorage['${validJid}_database_prefix'] = 'prefix';
        credentialStorage['validusername@axi.im_database_prefix'] = 'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
        when(() => mockXmppService.databasesInitialized).thenReturn(false);
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
          () => mockXmppService.cleanupUnregisterLocalData(
            jid: validJid,
            databasePrefix: 'prefix',
          ),
        ).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Unregister uses the active XMPP database prefix when no cleanup secrets were persisted.',
      setUp: () {
        when(
          () => mockXmppService.activeDatabasePrefix,
        ).thenReturn('session-prefix');
        when(
          () => mockHttpClient.post(any(), body: any(named: 'body')),
        ).thenAnswer((_) async => Response('', 200));
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _xmppOnlyEndpointConfig,
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(
          config: _xmppOnlyEndpointConfig,
        ),
      ),
      act: (bloc) => bloc.unregister(
        username: validUsername,
        host: EndpointConfig.defaultDomain,
        password: validPassword,
      ),
      expect: () => const [
        AuthenticationUnregisterInProgress(config: _xmppOnlyEndpointConfig),
        AuthenticationNone(config: _xmppOnlyEndpointConfig),
      ],
      verify: (_) {
        verify(
          () => mockXmppService.cleanupUnregisterLocalData(
            jid: validJid,
            databasePrefix: 'session-prefix',
          ),
        ).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'If email delete succeeds and XMPP delete fails, only the email side is torn down locally.',
      setUp: () {
        credentialStorage['jid'] = validJid;
        credentialStorage['password'] = validPassword;
        credentialStorage['password_prehashed_v1'] = true.toString();
        credentialStorage['${validJid}_database_prefix'] = 'prefix';
        credentialStorage['validusername@axi.im_database_prefix'] = 'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
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
        when(
          () => mockHttpClient.post(any(), body: any(named: 'body')),
        ).thenAnswer((_) async => Response('server error', 500));
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
        AuthenticationUnregisterFailure(AuthRawMessage('server error')),
      ],
      verify: (bloc) {
        verifyInOrder([
          () => mockProvisioningClient.deleteAccount(
            email: 'user@axi.im',
            password: validPassword,
          ),
          () => mockXmppService.clearSessionTokens(),
          () => mockEmailService.shutdown(
            jid: validJid,
            clearCredentials: clearEmailCredentialsOnLogout,
          ),
          () => mockXmppService.disconnect(),
        ]);
        verify(
          () => mockEmailService.clearStoredCredentials(
            jid: validJid,
            preserveActiveSession: false,
          ),
        ).called(1);
        verifyNever(
          () => mockXmppService.cleanupUnregisterLocalData(
            jid: any(named: 'jid'),
            databasePrefix: any(named: 'databasePrefix'),
          ),
        );
        expect(credentialStorage[bloc.jidStorageKey.value], equals(validJid));
        expect(
          credentialStorage[bloc.passwordStorageKey.value],
          equals(validPassword),
        );
        expect(
          credentialStorage[bloc.passwordPreHashedStorageKey.value],
          equals(true.toString()),
        );
        expect(
          credentialStorage['${validJid}_database_prefix'],
          equals('prefix'),
        );
        expect(
          credentialStorage['validusername@axi.im_database_prefix'],
          equals('prefix'),
        );
        expect(
          credentialStorage['prefix_database_passphrase'],
          equals('passphrase'),
        );
        expect(
          credentialStorage[bloc.partialUnregisterJidKey.value],
          equals(validJid.toLowerCase()),
        );
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'If email delete succeeds and XMPP already reports 404, unregister completes locally.',
      setUp: () {
        credentialStorage['jid'] = validJid;
        credentialStorage['password'] = validPassword;
        credentialStorage['password_prehashed_v1'] = true.toString();
        credentialStorage['${validJid}_database_prefix'] = 'prefix';
        credentialStorage['validusername@axi.im_database_prefix'] = 'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
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
      verify: (bloc) {
        verify(
          () => mockProvisioningClient.deleteAccount(
            email: 'user@axi.im',
            password: validPassword,
          ),
        ).called(1);
        verify(
          () => mockXmppService.cleanupUnregisterLocalData(
            jid: validJid,
            databasePrefix: 'prefix',
          ),
        ).called(1);
        expect(credentialStorage[bloc.partialUnregisterJidKey.value], isNull);
        expect(credentialStorage[bloc.jidStorageKey.value], isNull);
        expect(credentialStorage['${validJid}_database_prefix'], isNull);
        expect(credentialStorage['prefix_database_passphrase'], isNull);
      },
    );

    test(
      'Stored-credential login stays blocked while partial unregister is pending.',
      () async {
        credentialStorage['jid'] = validJid;
        credentialStorage['password'] = validPassword;
        credentialStorage['password_prehashed_v1'] = true.toString();
        credentialStorage['${validJid}_database_prefix'] = 'prefix';
        credentialStorage['validusername@axi.im_database_prefix'] = 'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
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
        when(
          () => mockHttpClient.post(any(), body: any(named: 'body')),
        ).thenAnswer(
          (_) async => Response(
            "There was an error deleting the account: The account doesn't exist",
            404,
          ),
        );

        final unregisterBloc = AuthenticationCubit(
          credentialStore: mockCredentialStore,
          initialEndpointConfig: const EndpointConfig(),
          xmppService: mockXmppService,
          emailService: mockEmailService,
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
          initialState: const AuthenticationComplete(),
        );
        await unregisterBloc.unregister(
          username: validUsername,
          host: EndpointConfig.defaultDomain,
          password: validPassword,
        );
        await unregisterBloc.close();

        clearInteractions(mockXmppService);
        clearInteractions(mockHttpClient);

        final loginBloc = AuthenticationCubit(
          credentialStore: mockCredentialStore,
          initialEndpointConfig: const EndpointConfig(),
          xmppService: mockXmppService,
          emailService: mockEmailService,
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
        );

        expect(await loginBloc.hasStoredLoginCredentials(), isFalse);

        await loginBloc.login();

        verify(() => mockXmppService.disconnect()).called(1);
        verifyNever(() => mockHttpClient.post(any(), body: any(named: 'body')));

        await loginBloc.close();
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Partial unregister retry skips the email delete step once the marker exists.',
      setUp: () {
        credentialStorage['jid'] = validJid;
        credentialStorage['password'] = validPassword;
        credentialStorage['password_prehashed_v1'] = true.toString();
        credentialStorage['${validJid}_database_prefix'] = 'prefix';
        credentialStorage['validusername@axi.im_database_prefix'] = 'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
        credentialStorage['partial_unregister_jid_v1'] = validJid;
        when(() => mockXmppService.databasesInitialized).thenReturn(true);
        when(
          () => mockHttpClient.post(any(), body: any(named: 'body')),
        ).thenAnswer((_) async => Response('', 200));
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
      verify: (bloc) {
        verifyNever(
          () => mockProvisioningClient.deleteAccount(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
        verify(
          () => mockHttpClient.post(any(), body: any(named: 'body')),
        ).called(1);
        expect(credentialStorage[bloc.partialUnregisterJidKey.value], isNull);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Partial unregister retry treats an XMPP 404 as completion and clears local state.',
      setUp: () {
        credentialStorage['jid'] = validJid;
        credentialStorage['password'] = validPassword;
        credentialStorage['password_prehashed_v1'] = true.toString();
        credentialStorage['partial_unregister_jid_v1'] = validJid;
        credentialStorage['partial_unregister_database_prefix_v1'] = 'prefix';
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
      verify: (bloc) {
        verifyNever(
          () => mockProvisioningClient.deleteAccount(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
        verify(
          () => mockXmppService.cleanupUnregisterLocalData(
            jid: validJid,
            databasePrefix: 'prefix',
          ),
        ).called(1);
        expect(credentialStorage[bloc.partialUnregisterJidKey.value], isNull);
        expect(
          credentialStorage[bloc.partialUnregisterDatabasePrefixKey.value],
          isNull,
        );
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'Successful unregister keeps another account pending partial-unregister state intact.',
      setUp: () {
        credentialStorage['partial_unregister_jid_v1'] = validJid;
        credentialStorage['partial_unregister_database_prefix_v1'] =
            'pending-prefix';
        when(
          () => mockXmppService.activeDatabasePrefix,
        ).thenReturn('other-prefix');
        when(
          () => mockHttpClient.post(any(), body: any(named: 'body')),
        ).thenAnswer((_) async => Response('', 200));
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _xmppOnlyEndpointConfig,
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(
          config: _xmppOnlyEndpointConfig,
        ),
      ),
      act: (bloc) => bloc.unregister(
        username: 'otherUser',
        host: EndpointConfig.defaultDomain,
        password: 'otherPassword',
      ),
      expect: () => const [
        AuthenticationUnregisterInProgress(config: _xmppOnlyEndpointConfig),
        AuthenticationNone(config: _xmppOnlyEndpointConfig),
      ],
      verify: (_) {
        verify(
          () => mockXmppService.cleanupUnregisterLocalData(
            jid: 'otherUser@${EndpointConfig.defaultDomain}',
            databasePrefix: 'other-prefix',
          ),
        ).called(1);
        expect(credentialStorage['partial_unregister_jid_v1'], validJid);
        expect(
          credentialStorage['partial_unregister_database_prefix_v1'],
          'pending-prefix',
        );
      },
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
          const provisioning.EmailProvisioningApiInvalidResponseException(
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

    test(
      'Successful unregister waits for teardown and leaves no resumability state.',
      () async {
        credentialStorage['jid'] = validJid;
        credentialStorage['password'] = validPassword;
        credentialStorage['password_prehashed_v1'] = true.toString();
        credentialStorage['${validJid}_database_prefix'] = 'prefix';
        credentialStorage['validusername@axi.im_database_prefix'] = 'prefix';
        credentialStorage['prefix_database_passphrase'] = 'passphrase';
        when(() => mockXmppService.databasesInitialized).thenReturn(true);
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

        final clearTokensCompleter = Completer<void>();
        final shutdownCompleter = Completer<void>();
        final disconnectCompleter = Completer<void>();
        final cleanupCompleter = Completer<void>();

        when(
          () => mockXmppService.clearSessionTokens(),
        ).thenAnswer((_) => clearTokensCompleter.future);
        when(
          () => mockEmailService.shutdown(
            jid: any(named: 'jid'),
            clearCredentials: any(named: 'clearCredentials'),
          ),
        ).thenAnswer((_) => shutdownCompleter.future);
        when(
          () => mockEmailService.shutdown(
            jid: any(named: 'jid'),
            clearCredentials: any(named: 'clearCredentials'),
            mode: any(named: 'mode'),
          ),
        ).thenAnswer((_) => shutdownCompleter.future);
        when(
          () => mockXmppService.disconnect(),
        ).thenAnswer((_) => disconnectCompleter.future);
        when(
          () => mockXmppService.cleanupUnregisterLocalData(
            jid: any(named: 'jid'),
            databasePrefix: any(named: 'databasePrefix'),
          ),
        ).thenAnswer((_) => cleanupCompleter.future);

        final bloc = AuthenticationCubit(
          credentialStore: mockCredentialStore,
          initialEndpointConfig: const EndpointConfig(),
          xmppService: mockXmppService,
          emailService: mockEmailService,
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
          initialState: const AuthenticationComplete(),
        );
        final emittedStates = <AuthenticationState>[];
        final subscription = bloc.stream.listen(emittedStates.add);

        final unregisterFuture = bloc.unregister(
          username: validUsername,
          host: EndpointConfig.defaultDomain,
          password: validPassword,
        );

        await Future<void>.delayed(Duration.zero);
        expect(emittedStates, const [AuthenticationUnregisterInProgress()]);

        clearTokensCompleter.complete();
        await Future<void>.delayed(Duration.zero);
        expect(emittedStates, const [AuthenticationUnregisterInProgress()]);

        shutdownCompleter.complete();
        await Future<void>.delayed(Duration.zero);
        expect(emittedStates, const [AuthenticationUnregisterInProgress()]);

        disconnectCompleter.complete();
        await Future<void>.delayed(Duration.zero);
        expect(emittedStates, const [AuthenticationUnregisterInProgress()]);

        cleanupCompleter.complete();
        await unregisterFuture;
        await Future<void>.delayed(Duration.zero);
        expect(emittedStates, const [
          AuthenticationUnregisterInProgress(),
          AuthenticationNone(),
        ]);
        verifyInOrder([
          () => mockXmppService.clearSessionTokens(),
          () => mockEmailService.shutdown(
            jid: validJid,
            clearCredentials: clearEmailCredentialsOnLogout,
          ),
          () => mockXmppService.disconnect(),
          () => mockXmppService.cleanupUnregisterLocalData(
            jid: validJid,
            databasePrefix: 'prefix',
          ),
        ]);
        expect(credentialStorage[bloc.jidStorageKey.value], isNull);
        expect(credentialStorage[bloc.passwordStorageKey.value], isNull);
        expect(
          credentialStorage[bloc.passwordPreHashedStorageKey.value],
          isNull,
        );
        expect(credentialStorage['${validJid}_database_prefix'], isNull);
        expect(
          credentialStorage['validusername@axi.im_database_prefix'],
          isNull,
        );
        expect(credentialStorage['prefix_database_passphrase'], isNull);

        await subscription.cancel();
        await bloc.close();
      },
    );
  });

  group('lifecycle resume', () {
    void moveLifecycleToHidden() {
      final binding = WidgetsBinding.instance;
      if (binding.lifecycleState == AppLifecycleState.detached) {
        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      if (binding.lifecycleState == null ||
          binding.lifecycleState == AppLifecycleState.resumed) {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      }
      if (binding.lifecycleState == AppLifecycleState.paused) {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      }
      if (binding.lifecycleState == AppLifecycleState.inactive) {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      }
    }

    test(
      'starts email reconnect before XMPP without waiting for catch-up',
      () async {
        final emailCompleter = Completer<void>();
        final events = <String>[];
        when(
          () => mockEmailService.handleForegroundResumeNetworkAvailable(),
        ).thenAnswer((_) {
          events.add('email');
          return emailCompleter.future;
        });
        when(
          () => mockXmppService.requestReconnect(ReconnectTrigger.resume),
        ).thenAnswer((_) async {
          events.add('xmpp');
          return true;
        });

        final bloc = AuthenticationCubit(
          credentialStore: mockCredentialStore,
          initialEndpointConfig: const EndpointConfig(),
          xmppService: mockXmppService,
          emailService: mockEmailService,
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
          initialState: const AuthenticationComplete(),
        );
        addTearDown(bloc.close);

        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await pumpEventQueue();

        expect(events, contains('email'));
        expect(events, contains('xmpp'));
        expect(events.indexOf('email'), lessThan(events.indexOf('xmpp')));
        expect(emailCompleter.isCompleted, isFalse);

        emailCompleter.complete();
        await pumpEventQueue();
      },
    );

    test('foreground resume probes ready active email sessions', () async {
      when(() => mockEmailService.hasActiveSession).thenReturn(true);
      when(
        () => mockEmailService.syncState,
      ).thenReturn(const EmailSyncState.ready());

      final bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
      );
      addTearDown(bloc.close);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await pumpEventQueue();

      verify(
        () => mockEmailService.handleForegroundResumeNetworkAvailable(),
      ).called(1);
      verifyNever(() => mockEmailService.handleNetworkAvailable());
    });

    test('show lifecycle does not run foreground email recovery', () async {
      when(() => mockEmailService.hasActiveSession).thenReturn(true);
      when(
        () => mockEmailService.syncState,
      ).thenReturn(const EmailSyncState.ready());

      final bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
      );
      addTearDown(bloc.close);

      moveLifecycleToHidden();
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await pumpEventQueue();

      verifyNever(
        () => mockEmailService.handleForegroundResumeNetworkAvailable(),
      );
      verifyNever(() => mockEmailService.handleNetworkAvailable());
    });

    test(
      'foreground resume probes email when joining active show resume',
      () async {
        final reconnectCompleter = Completer<bool>();
        when(() => mockEmailService.hasActiveSession).thenReturn(true);
        when(
          () => mockEmailService.syncState,
        ).thenReturn(const EmailSyncState.ready());
        when(
          () => mockXmppService.requestReconnect(ReconnectTrigger.resume),
        ).thenAnswer((_) => reconnectCompleter.future);

        final bloc = AuthenticationCubit(
          credentialStore: mockCredentialStore,
          initialEndpointConfig: const EndpointConfig(),
          xmppService: mockXmppService,
          emailService: mockEmailService,
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
          initialState: const AuthenticationComplete(),
        );
        addTearDown(bloc.close);

        moveLifecycleToHidden();
        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await untilCalled(
          () => mockXmppService.requestReconnect(ReconnectTrigger.resume),
        );

        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await pumpEventQueue();

        verify(
          () => mockEmailService.handleForegroundResumeNetworkAvailable(),
        ).called(1);
        verifyNever(() => mockEmailService.handleNetworkAvailable());

        reconnectCompleter.complete(true);
        await pumpEventQueue();
      },
    );

    test(
      'auth state change during email resume prevents XMPP reconnect',
      () async {
        var emailContextChecks = 0;
        when(() => mockXmppService.myJid).thenReturn(validJid);
        when(() => mockEmailService.hasActiveSession).thenReturn(false);
        when(() => mockEmailService.hasInMemoryReconnectContext).thenAnswer((
          _,
        ) {
          emailContextChecks++;
          return emailContextChecks == 1;
        });
        when(
          () => mockXmppService.requestReconnect(ReconnectTrigger.resume),
        ).thenAnswer((_) async => true);

        final bloc = AuthenticationCubit(
          credentialStore: mockCredentialStore,
          initialEndpointConfig: const EndpointConfig(),
          xmppService: mockXmppService,
          emailService: mockEmailService,
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
          initialState: const AuthenticationComplete(),
        );
        addTearDown(bloc.close);

        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await pumpEventQueue();

        expect(bloc.state, const AuthenticationNone());
        verifyNever(
          () => mockXmppService.requestReconnect(ReconnectTrigger.resume),
        );
      },
    );

    test('skips resume reconnect when XMPP is already connected', () async {
      when(() => mockXmppService.connected).thenReturn(true);

      final bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
      );
      addTearDown(bloc.close);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await pumpEventQueue();

      verifyNever(
        () => mockXmppService.requestReconnect(ReconnectTrigger.resume),
      );
    });
  });

  group('background XMPP reconnect pause', () {
    const pauseDelay = Duration(milliseconds: 10);

    void restoreForegroundLifecycle() {
      final binding = WidgetsBinding.instance;
      if (binding.lifecycleState == AppLifecycleState.paused) {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      }
      if (binding.lifecycleState == AppLifecycleState.hidden) {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      }
      if (binding.lifecycleState == AppLifecycleState.inactive ||
          binding.lifecycleState == null) {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
      withForeground = false;
      resetForegroundNotifier(value: false);
    }

    void enterHiddenLifecycle() {
      final binding = WidgetsBinding.instance;
      if (binding.lifecycleState == AppLifecycleState.resumed ||
          binding.lifecycleState == null) {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      }
      if (binding.lifecycleState == AppLifecycleState.inactive) {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      }
    }

    test('hidden lifecycle starts the pause timer', () async {
      restoreForegroundLifecycle();
      addTearDown(restoreForegroundLifecycle);
      final bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _xmppOnlyEndpointConfig,
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
        xmppReconnectPauseDelay: pauseDelay,
      );
      addTearDown(bloc.close);

      enterHiddenLifecycle();
      await Future<void>.delayed(pauseDelay * 2);
      await pumpEventQueue();

      verify(() => mockXmppService.pauseAutomaticReconnect()).called(1);
    });

    test('inactive lifecycle cancels the pause timer', () async {
      restoreForegroundLifecycle();
      addTearDown(restoreForegroundLifecycle);
      final bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _xmppOnlyEndpointConfig,
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
        xmppReconnectPauseDelay: pauseDelay,
      );
      addTearDown(bloc.close);

      enterHiddenLifecycle();
      await Future<void>.delayed(pauseDelay ~/ 2);
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await Future<void>.delayed(pauseDelay * 2);
      await pumpEventQueue();

      verifyNever(() => mockXmppService.pauseAutomaticReconnect());
    });

    test('resumed lifecycle cancels the pause timer', () async {
      restoreForegroundLifecycle();
      addTearDown(restoreForegroundLifecycle);
      final bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _xmppOnlyEndpointConfig,
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
        xmppReconnectPauseDelay: pauseDelay,
      );
      addTearDown(bloc.close);

      enterHiddenLifecycle();
      await Future<void>.delayed(pauseDelay ~/ 2);
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await Future<void>.delayed(pauseDelay * 2);
      await pumpEventQueue();

      verifyNever(() => mockXmppService.pauseAutomaticReconnect());
    });

    test('active foreground service prevents the pause', () async {
      restoreForegroundLifecycle();
      withForeground = true;
      resetForegroundNotifier(value: true);
      addTearDown(restoreForegroundLifecycle);
      final bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _xmppOnlyEndpointConfig,
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
        xmppReconnectPauseDelay: pauseDelay,
      );
      addTearDown(bloc.close);

      enterHiddenLifecycle();
      await Future<void>.delayed(pauseDelay * 2);
      await pumpEventQueue();

      verifyNever(() => mockXmppService.pauseAutomaticReconnect());
    });

    test('foreground service activation cancels the pause timer', () async {
      restoreForegroundLifecycle();
      addTearDown(restoreForegroundLifecycle);
      final bloc = AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: _xmppOnlyEndpointConfig,
        xmppService: mockXmppService,
        emailService: mockEmailService,
        httpClient: mockHttpClient,
        emailProvisioningClient: mockProvisioningClient,
        initialState: const AuthenticationComplete(),
        xmppReconnectPauseDelay: pauseDelay,
      );
      addTearDown(bloc.close);

      enterHiddenLifecycle();
      await Future<void>.delayed(pauseDelay ~/ 2);
      withForeground = true;
      resetForegroundNotifier(value: true);
      await Future<void>.delayed(pauseDelay * 2);
      await pumpEventQueue();

      verifyNever(() => mockXmppService.pauseAutomaticReconnect());
    });
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

  group('auth bootstrap', () {
    test('Pending logout barrier blocks stored login bootstrap.', () async {
      credentialStorage
        ..['remember_me_choice'] = true.toString()
        ..['jid'] = validJid
        ..['password'] = validPassword
        ..['password_prehashed_v1'] = true.toString()
        ..['logout_in_progress_v1'] = validJid;

      expect(
        await resolveHasStoredLoginCredentials(mockCredentialStore),
        isFalse,
      );
    });
  });

  group('logout', () {
    setUp(() {
      when(() => mockXmppService.disconnect()).thenAnswer((_) async {});
      when(
        () => mockCredentialStore.delete(key: any(named: 'key')),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
        credentialStorage.remove(key.value);
        return true;
      });
      when(
        () => mockEmailService.shutdown(
          jid: any(named: 'jid'),
          clearCredentials: any(named: 'clearCredentials'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockEmailService.shutdown(
          jid: any(named: 'jid'),
          clearCredentials: any(named: 'clearCredentials'),
          mode: any(named: 'mode'),
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
      setUp: () {
        credentialStorage['jid'] = validJid;
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
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
        expect(credentialStorage, isNot(contains('logout_in_progress_v1')));
        verify(() => mockXmppService.clearSessionTokens()).called(1);
        verify(() => mockXmppService.disconnect()).called(1);
      },
    );

    test(
      'User initiated logout writes a durable barrier before slow teardown.',
      () async {
        credentialStorage['jid'] = validJid;
        final shutdownCompleter = Completer<void>();
        when(
          () => mockEmailService.shutdown(
            jid: any(named: 'jid'),
            clearCredentials: any(named: 'clearCredentials'),
            mode: any(named: 'mode'),
          ),
        ).thenAnswer((_) => shutdownCompleter.future);

        final bloc = AuthenticationCubit(
          credentialStore: mockCredentialStore,
          initialEndpointConfig: const EndpointConfig(),
          xmppService: mockXmppService,
          emailService: mockEmailService,
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
          initialState: const AuthenticationComplete(),
        );

        final logoutFuture = bloc.logout(severity: LogoutSeverity.normal);
        await Future<void>.delayed(Duration.zero);

        expect(credentialStorage['logout_in_progress_v1'], validJid);
        expect(credentialStorage['jid'], validJid);

        shutdownCompleter.complete();
        await logoutFuture;

        expect(credentialStorage, isNot(contains('logout_in_progress_v1')));
        expect(credentialStorage, isNot(contains('jid')));

        await bloc.close();
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
            mode: any(named: 'mode'),
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
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
          initialState: const AuthenticationComplete(),
        );
        final emittedStates = <AuthenticationState>[];
        final subscription = bloc.stream.listen(emittedStates.add);

        final logoutFuture = bloc.logout(severity: LogoutSeverity.normal);
        await Future<void>.delayed(Duration.zero);
        expect(emittedStates, isEmpty);
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
      'Stored login recovers an interrupted logout instead of auto-login.',
      setUp: () {
        credentialStorage
          ..['jid'] = validJid
          ..['password'] = validPassword
          ..['password_prehashed_v1'] = true.toString()
          ..['logout_in_progress_v1'] = validJid;
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
      expect: () => [],
      verify: (bloc) {
        expect(credentialStorage, isNot(contains('logout_in_progress_v1')));
        expect(credentialStorage, isNot(contains('jid')));
        expect(credentialStorage, isNot(contains('password')));
        verify(() => mockXmppService.clearSessionTokens()).called(1);
        verify(() => mockXmppService.disconnect()).called(1);
        verify(
          () => mockEmailService.clearStoredCredentials(
            jid: validJid,
            preserveActiveSession: false,
          ),
        ).called(1);
      },
    );

    blocTest<AuthenticationCubit, AuthenticationState>(
      'User initiated logout clears email credentials when enabled.',
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        initialEndpointConfig: const EndpointConfig(),
        xmppService: mockXmppService,
        emailService: mockEmailService,
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
            mode: EmailShutdownMode.logout,
          ),
        ).called(1);
      },
    );

    test(
      'User initiated logout stays blocked for device-only password accounts.',
      () async {
        credentialStorage['password_skipped_v1'] = true.toString();

        final bloc = AuthenticationCubit(
          credentialStore: mockCredentialStore,
          initialEndpointConfig: const EndpointConfig(),
          xmppService: mockXmppService,
          emailService: mockEmailService,
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
          initialState: const AuthenticationComplete(),
        );
        await bloc.loadPasswordWasSkippedChoice();

        final emittedStates = <AuthenticationState>[];
        final subscription = bloc.stream.listen(emittedStates.add);

        await bloc.logout(severity: LogoutSeverity.normal);

        expect(emittedStates, isEmpty);
        verifyNever(() => mockXmppService.clearSessionTokens());
        verifyNever(() => mockXmppService.disconnect());
        verifyNever(() => mockCredentialStore.delete(key: bloc.jidStorageKey));
        verifyNever(
          () => mockCredentialStore.delete(key: bloc.passwordStorageKey),
        );

        await subscription.cancel();
        await bloc.close();
      },
    );

    test(
      'Connectivity connected uses normal email network recovery.',
      () async {
        final connectivityController =
            StreamController<ConnectionState>.broadcast();
        when(
          () => mockXmppService.connectivityStream,
        ).thenAnswer((_) => connectivityController.stream);

        final bloc = AuthenticationCubit(
          credentialStore: mockCredentialStore,
          initialEndpointConfig: const EndpointConfig(),
          xmppService: mockXmppService,
          emailService: mockEmailService,
          httpClient: mockHttpClient,
          emailProvisioningClient: mockProvisioningClient,
          initialState: const AuthenticationComplete(),
        );

        connectivityController.add(ConnectionState.connected);
        await Future<void>.delayed(Duration.zero);

        verify(() => mockEmailService.handleNetworkAvailable()).called(1);
        verifyNever(
          () => mockEmailService.handleForegroundResumeNetworkAvailable(),
        );

        await connectivityController.close();
        await bloc.close();
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
