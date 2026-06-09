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

  test('checks connectivity using bare domain endpoint', () async {
    const domain = 'example.test';
    final manager = XmppConnectivityManager.forXmppConnection(
      domainProvider: () => domain,
      shouldContinue: () async => true,
      connectivityProbe: (endpoints) async {
        expect(endpoints, hasLength(1));
        expect(endpoints.single.host, domain);
        expect(endpoints.single.port, 5222);
        return true;
      },
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
    'waitForConnection returns after timeout when probes stay unavailable',
    () async {
      const timeout = Duration(milliseconds: 10);
      const domain = 'wait-timeout.test';
      var probeCalls = 0;
      final manager = XmppConnectivityManager.forXmppConnection(
        domainProvider: () => domain,
        shouldContinue: () async => true,
        pollInterval: const Duration(milliseconds: 1),
        waitTimeout: timeout,
        connectivityProbe: (_) async {
          probeCalls++;
          return false;
        },
      );

      final stopwatch = Stopwatch()..start();
      await manager.waitForConnection().timeout(const Duration(seconds: 1));
      stopwatch.stop();

      expect(probeCalls, greaterThan(1));
      expect(stopwatch.elapsed, greaterThanOrEqualTo(timeout));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    },
  );

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
        waitTimeout: const Duration(seconds: 1),
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
