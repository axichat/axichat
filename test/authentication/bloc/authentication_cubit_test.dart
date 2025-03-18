import 'package:bloc_test/bloc_test.dart';
import 'package:chat/src/authentication/bloc/authentication_cubit.dart';
import 'package:chat/src/common/capability.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

const jid = 'jid@axi.im/resource';
const password = 'password';
const from = 'from@axi.im';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
  });

  setUp(() {
    when(() => mockCredentialStore.read(key: any(named: 'key')))
        .thenAnswer((_) async => '');

    when(() => mockCredentialStore.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async => true);

    when(() => mockCredentialStore.close()).thenAnswer((_) async {});
  });

  group('login', () {
    blocTest<AuthenticationCubit, AuthenticationState>(
      'Given invalid credentials, emits [AuthenticationFailure].',
      setUp: () async {
        when(() => mockXmppService.connect(
              jid: any(named: 'jid'),
              resource: any(named: 'resource'),
              password: any(named: 'password'),
              databasePrefix: any(named: 'databasePrefix'),
              databasePassphrase: any(named: 'databasePassphrase'),
              preHashed: any(named: 'preHashed'),
            )).thenThrow(XmppAuthenticationException());
      },
      build: () => AuthenticationCubit(
        credentialStore: mockCredentialStore,
        xmppService: mockXmppService,
        capability: const Capability(),
      ),
      act: (bloc) => bloc.login(username: 'invalid', password: 'invalid'),
      expect: () => [
        const AuthenticationInProgress(),
        const AuthenticationFailure('Incorrect username or password'),
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
