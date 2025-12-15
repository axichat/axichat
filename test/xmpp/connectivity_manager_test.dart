import 'dart:io';

import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fails open when no domain is available', () async {
    final manager = XmppConnectivityManager.forXmppConnection(
      domainProvider: () => null,
      shouldContinue: () async => true,
    );

    expect(await manager.hasConnection(), isTrue);
  });

  test('checks connectivity using mapped XMPP endpoint', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final subscription = server.listen((socket) {
      socket.destroy();
    });
    addTearDown(subscription.cancel);

    const domain = 'example.test';
    final previousEndpoint = serverLookup[domain];
    serverLookup[domain] = IOEndpoint(
      InternetAddress.loopbackIPv4.address,
      server.port,
    );
    addTearDown(() {
      if (previousEndpoint == null) {
        serverLookup.remove(domain);
      } else {
        serverLookup[domain] = previousEndpoint;
      }
    });

    final manager = XmppConnectivityManager.forXmppConnection(
      domainProvider: () => domain,
      shouldContinue: () async => true,
    );

    expect(await manager.hasConnection(), isTrue);
  });

  test('waitForConnection returns when reconnect disabled', () async {
    final manager = XmppConnectivityManager.forXmppConnection(
      domainProvider: () => null,
      shouldContinue: () async => false,
    );

    await manager.waitForConnection();
  });
}
