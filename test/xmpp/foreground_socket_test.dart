import 'dart:async';
import 'package:axichat/src/common/foreground_task_messages.dart';
import 'package:axichat/src/xmpp/connection/foreground_socket.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterForegroundTaskBridge', () {
    test('acquire waits for the foreground task ready signal', () async {
      late Future<void> Function(dynamic) taskDataCallback;
      final ready = Completer<void>();

      final bridge = FlutterForegroundTaskBridge(
        isRunningService: () async => false,
        startForegroundService: (_) async {
          unawaited(() async {
            await ready.future;
            await taskDataCallback(taskReadyPrefix);
          }());
        },
        stopForegroundService: () async {},
        waitForResume: () async {},
        initCommunicationPort: () {},
        addTaskDataCallback: (callback) {
          taskDataCallback = callback;
        },
        removeTaskDataCallback: (_) {},
        sendDataToTask: (_) {},
      );

      var completed = false;
      final acquire = bridge.acquire(clientId: 'warmup');
      acquire.then((_) => completed = true);

      await pumpEventQueue();
      expect(completed, isFalse);

      ready.complete();
      await acquire;

      expect(completed, isTrue);
    });

    test('second acquire waits for an in-flight startup to finish', () async {
      late Future<void> Function(dynamic) taskDataCallback;
      final ready = Completer<void>();

      final bridge = FlutterForegroundTaskBridge(
        isRunningService: () async => false,
        startForegroundService: (_) async {
          unawaited(() async {
            await ready.future;
            await taskDataCallback(taskReadyPrefix);
          }());
        },
        stopForegroundService: () async {},
        waitForResume: () async {},
        initCommunicationPort: () {},
        addTaskDataCallback: (callback) {
          taskDataCallback = callback;
        },
        removeTaskDataCallback: (_) {},
        sendDataToTask: (_) {},
      );

      final firstAcquire = bridge.acquire(clientId: 'warmup');
      await pumpEventQueue();

      var secondCompleted = false;
      final secondAcquire = bridge.acquire(clientId: 'xmpp');
      secondAcquire.then((_) => secondCompleted = true);

      await pumpEventQueue();
      expect(secondCompleted, isFalse);

      ready.complete();
      await Future.wait([firstAcquire, secondAcquire]);

      expect(secondCompleted, isTrue);
    });

    test(
      'duplicate acquire for the same client does not leak a lease',
      () async {
        var stopCalls = 0;

        final bridge = FlutterForegroundTaskBridge(
          isRunningService: () async => true,
          startForegroundService: (_) async {},
          stopForegroundService: () async {
            stopCalls++;
          },
          waitForResume: () async {},
          initCommunicationPort: () {},
          addTaskDataCallback: (_) {},
          removeTaskDataCallback: (_) {},
          sendDataToTask: (_) {},
        );

        await bridge.acquire(clientId: foregroundClientEmailKeepalive);
        await bridge.acquire(clientId: foregroundClientEmailKeepalive);
        await bridge.release(foregroundClientEmailKeepalive);

        expect(stopCalls, equals(1));
      },
    );

    test(
      'acquire restarts the foreground service when lease state is stale',
      () async {
        late Future<void> Function(dynamic) taskDataCallback;
        var running = false;
        var startCalls = 0;

        final bridge = FlutterForegroundTaskBridge(
          isRunningService: () async => running,
          startForegroundService: (_) async {
            startCalls++;
            running = true;
            await taskDataCallback(taskReadyPrefix);
          },
          stopForegroundService: () async {},
          waitForResume: () async {},
          initCommunicationPort: () {},
          addTaskDataCallback: (callback) {
            taskDataCallback = callback;
          },
          removeTaskDataCallback: (_) {},
          sendDataToTask: (_) {},
        );

        await bridge.acquire(clientId: foregroundClientXmpp);
        expect(startCalls, equals(1));

        running = false;
        await bridge.acquire(clientId: foregroundClientXmpp);

        expect(startCalls, equals(2));
      },
    );

    test(
      'stale service recovery preserves other active client leases',
      () async {
        late Future<void> Function(dynamic) taskDataCallback;
        var running = false;
        var startCalls = 0;
        var stopCalls = 0;

        final bridge = FlutterForegroundTaskBridge(
          isRunningService: () async => running,
          startForegroundService: (_) async {
            startCalls++;
            running = true;
            await taskDataCallback(taskReadyPrefix);
          },
          stopForegroundService: () async {
            stopCalls++;
            running = false;
          },
          waitForResume: () async {},
          initCommunicationPort: () {},
          addTaskDataCallback: (callback) {
            taskDataCallback = callback;
          },
          removeTaskDataCallback: (_) {},
          sendDataToTask: (_) {},
        );

        await bridge.acquire(clientId: foregroundClientEmailKeepalive);
        await bridge.acquire(clientId: foregroundClientXmpp);
        expect(startCalls, equals(1));

        running = false;
        await bridge.acquire(clientId: foregroundClientXmpp);
        expect(startCalls, equals(2));

        await bridge.release(foregroundClientXmpp);
        expect(stopCalls, isZero);

        await bridge.release(foregroundClientEmailKeepalive);
        expect(stopCalls, equals(1));
      },
    );

    test('release waits for an in-flight startup before stopping', () async {
      late Future<void> Function(dynamic) taskDataCallback;
      final startEntered = Completer<void>();
      final allowReady = Completer<void>();
      var stopCalls = 0;

      final bridge = FlutterForegroundTaskBridge(
        isRunningService: () async => false,
        startForegroundService: (_) async {
          startEntered.complete();
          await allowReady.future;
          await taskDataCallback(taskReadyPrefix);
        },
        stopForegroundService: () async {
          stopCalls++;
        },
        waitForResume: () async {},
        initCommunicationPort: () {},
        addTaskDataCallback: (callback) {
          taskDataCallback = callback;
        },
        removeTaskDataCallback: (_) {},
        sendDataToTask: (_) {},
      );

      final acquire = bridge.acquire(clientId: foregroundClientXmpp);
      await startEntered.future;

      final release = bridge.release(foregroundClientXmpp);
      await pumpEventQueue();
      expect(stopCalls, isZero);

      allowReady.complete();
      await Future.wait([acquire, release]);

      expect(stopCalls, equals(1));
    });

    test(
      'release skips stop when the foreground service is already not running',
      () async {
        var stopCalls = 0;
        var runningChecks = 0;
        final bridge = FlutterForegroundTaskBridge(
          isRunningService: () async {
            runningChecks++;
            return runningChecks == 1;
          },
          startForegroundService: (_) async {},
          stopForegroundService: () async {
            stopCalls++;
          },
          waitForResume: () async {},
          initCommunicationPort: () {},
          addTaskDataCallback: (_) {},
          removeTaskDataCallback: (_) {},
          sendDataToTask: (_) {},
        );

        await bridge.acquire(clientId: foregroundClientXmpp);
        await bridge.release(foregroundClientXmpp);

        expect(stopCalls, isZero);
      },
    );

    test('release does not hang when foreground service stop stalls', () async {
      var stopCalls = 0;
      final bridge = FlutterForegroundTaskBridge(
        isRunningService: () async => true,
        startForegroundService: (_) async {},
        stopForegroundService: () async {
          stopCalls++;
          await Completer<void>().future;
        },
        stopServiceTimeout: const Duration(milliseconds: 1),
        waitForResume: () async {},
        initCommunicationPort: () {},
        addTaskDataCallback: (_) {},
        removeTaskDataCallback: (_) {},
        sendDataToTask: (_) {},
      );

      await bridge.acquire(clientId: foregroundClientXmpp);
      await bridge.release(foregroundClientXmpp);

      expect(stopCalls, equals(1));
    });
  });

  group('resetForegroundServiceIfRunning', () {
    test('stops a running foreground service', () async {
      var stopped = false;

      final result = await resetForegroundServiceIfRunning(
        isAndroid: true,
        isRunningService: () async => true,
        stopForegroundService: () async {
          stopped = true;
          return const ServiceRequestSuccess();
        },
      );

      expect(result, isTrue);
      expect(stopped, isTrue);
    });

    test('does nothing when no foreground service is running', () async {
      var stopCalls = 0;

      final result = await resetForegroundServiceIfRunning(
        isAndroid: true,
        isRunningService: () async => false,
        stopForegroundService: () async {
          stopCalls++;
          return const ServiceRequestSuccess();
        },
      );

      expect(result, isFalse);
      expect(stopCalls, isZero);
    });
  });

  group('ForegroundSocketWrapper', () {
    test('connect times out instead of hanging forever', () async {
      final bridge = _NoReplyForegroundTaskBridge();
      final socket = ForegroundSocketWrapper(
        bridge: bridge,
        connectTimeout: const Duration(milliseconds: 1),
      );

      final connected = await socket.connect(
        'axi.im',
        host: '127.0.0.1',
        port: 5222,
      );

      expect(connected, isFalse);
      expect(bridge.releaseCalls, equals(1));
    });
  });
}

class _NoReplyForegroundTaskBridge implements ForegroundTaskBridge {
  var releaseCalls = 0;

  @override
  Future<void> acquire({
    required String clientId,
    ForegroundServiceConfig? config,
  }) async {}

  @override
  void registerListener(
    String clientId,
    ForegroundTaskMessageHandler handler,
  ) {}

  @override
  Future<void> release(String clientId) async {
    releaseCalls++;
  }

  @override
  Future<void> send(List<Object> parts) async {}

  @override
  void unregisterListener(String clientId) {}
}
