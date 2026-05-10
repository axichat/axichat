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

  test(
    'waitForConnection stops polling once reconnect should no longer continue',
    () async {
      const domain = 'wait-stop.test';
      var probeCalls = 0;
      var keepWaiting = true;
      final manager = XmppConnectivityManager.forXmppConnection(
        domainProvider: () => domain,
        shouldContinue: () async => keepWaiting,
        pollInterval: const Duration(milliseconds: 1),
        waitTimeout: const Duration(milliseconds: 2),
        connectivityProbe: (_) async {
          probeCalls++;
          return false;
        },
      );

      final waitFuture = manager.waitForConnection();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      keepWaiting = false;

      await waitFuture.timeout(const Duration(seconds: 1));
      expect(probeCalls, greaterThan(0));
    },
  );

  test(
    'waitForConnection default polling reacts promptly when connectivity returns',
    () async {
      const domain = 'wait-default-poll.test';
      var probeCalls = 0;
      var connectivityAvailable = false;
      final manager = XmppConnectivityManager.forXmppConnection(
        domainProvider: () => domain,
        shouldContinue: () async => true,
        connectivityProbe: (_) async {
          probeCalls++;
          return connectivityAvailable;
        },
      );

      final waitFuture = manager.waitForConnection();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      connectivityAvailable = true;

      await waitFuture.timeout(const Duration(seconds: 2));
      expect(probeCalls, greaterThan(1));
    },
  );
}
