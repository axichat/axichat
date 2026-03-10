import 'dart:async';

import 'package:axichat/src/xmpp/foreground_socket.dart';
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
}
