//
// when(() => credentialStore.read(key: any(named: 'key')))
//     .thenAnswer((_) async => null);
//
// when(() => credentialStore.write(
//       key: any(named: 'key'),
//       value: any(named: 'value'),
//     )).thenAnswer((_) async => true);

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
