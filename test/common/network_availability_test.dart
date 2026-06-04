import 'dart:async';

import 'package:axichat/src/common/network_availability.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent starts share one connectivity subscription', () async {
    final checkCompleter = Completer<List<ConnectivityResult>>();
    final connectivity = _FakeConnectivity(check: () => checkCompleter.future);
    final service = NetworkAvailabilityService.forTesting(
      connectivity: connectivity,
    );

    final firstStart = service.start();
    final secondStart = service.start();
    await pumpEventQueue();

    expect(connectivity.checkCallCount, 1);
    checkCompleter.complete(const [ConnectivityResult.wifi]);
    await Future.wait([firstStart, secondStart]);

    expect(connectivity.listenCount, 1);

    await service.stop();
    expect(connectivity.cancelCount, 0);

    await service.stop();
    expect(connectivity.cancelCount, 1);
  });

  test('stop during in-flight start leaves no subscription', () async {
    final checkCompleter = Completer<List<ConnectivityResult>>();
    final connectivity = _FakeConnectivity(check: () => checkCompleter.future);
    final service = NetworkAvailabilityService.forTesting(
      connectivity: connectivity,
    );

    final startFuture = service.start();
    await pumpEventQueue();
    final stopFuture = service.stop();
    await pumpEventQueue();

    checkCompleter.complete(const [ConnectivityResult.wifi]);
    await Future.wait([startFuture, stopFuture]);

    expect(connectivity.listenCount, 0);
    expect(connectivity.cancelCount, 0);
  });

  test('failed start rolls back ownership and can recover', () async {
    var fail = true;
    final connectivity = _FakeConnectivity(
      check: () {
        if (fail) {
          return Future<List<ConnectivityResult>>.error(
            const _ConnectivityCheckException(),
          );
        }
        return Future<List<ConnectivityResult>>.value(const [
          ConnectivityResult.wifi,
        ]);
      },
    );
    final service = NetworkAvailabilityService.forTesting(
      connectivity: connectivity,
    );

    await expectLater(
      service.start(),
      throwsA(isA<_ConnectivityCheckException>()),
    );
    fail = false;

    await service.start();
    expect(connectivity.listenCount, 1);

    await service.stop();
    expect(connectivity.cancelCount, 1);
  });
}

class _FakeConnectivity implements Connectivity {
  _FakeConnectivity({required this.check}) {
    _controller = StreamController<List<ConnectivityResult>>.broadcast(
      onListen: () {
        listenCount += 1;
      },
      onCancel: () {
        cancelCount += 1;
      },
    );
  }

  final Future<List<ConnectivityResult>> Function() check;
  late final StreamController<List<ConnectivityResult>> _controller;

  int checkCallCount = 0;
  int listenCount = 0;
  int cancelCount = 0;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    checkCallCount += 1;
    return check();
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;
}

class _ConnectivityCheckException implements Exception {
  const _ConnectivityCheckException();
}
