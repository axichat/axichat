import 'dart:async';

import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does nothing when reconnect disabled', () {
    fakeAsync((async) {
      final policy = XmppReconnectionPolicy.exponential();
      var reconnectCalls = 0;
      policy.register(() async {
        reconnectCalls++;
      });

      var triggered = false;
      fireAndForget(
        () => policy.canTriggerFailure().then((value) async {
          triggered = value;
          if (value) {
            await policy.onFailure();
          }
        }),
      );
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 10));
      async.flushMicrotasks();

      expect(triggered, isFalse);
      expect(reconnectCalls, 0);
    });
  });

  test('reconnects after backoff when enabled', () {
    fakeAsync((async) {
      final policy = XmppReconnectionPolicy.exponential();
      var reconnectCalls = 0;
      policy.register(() async {
        reconnectCalls++;
      });

      fireAndForget(() => policy.setShouldReconnect(true));
      var triggered = false;
      fireAndForget(
        () => policy.canTriggerFailure().then((value) async {
          triggered = value;
          if (value) {
            await policy.onFailure();
          }
        }),
      );

      async.flushMicrotasks();
      expect(triggered, isTrue);
      expect(reconnectCalls, 0);

      async.elapse(const Duration(minutes: 10));
      async.flushMicrotasks();

      expect(reconnectCalls, 1);
    });
  });

  test('does not reconnect if disabled during backoff', () {
    fakeAsync((async) {
      final policy = XmppReconnectionPolicy.exponential();
      var reconnectCalls = 0;
      policy.register(() async {
        reconnectCalls++;
      });

      fireAndForget(() => policy.setShouldReconnect(true));
      fireAndForget(
        () => policy.canTriggerFailure().then((value) async {
          if (value) {
            await policy.onFailure();
          }
        }),
      );

      async.flushMicrotasks();
      fireAndForget(() => policy.setShouldReconnect(false));

      async.elapse(const Duration(minutes: 10));
      async.flushMicrotasks();

      expect(reconnectCalls, 0);
    });
  });

  test('requestReconnect bypasses remaining backoff', () {
    fakeAsync((async) {
      final policy = XmppReconnectionPolicy.exponential();
      var reconnectCalls = 0;
      policy.register(() async {
        reconnectCalls++;
      });

      fireAndForget(() => policy.setShouldReconnect(true));
      fireAndForget(
        () => policy.canTriggerFailure().then((value) async {
          if (value) {
            await policy.onFailure();
          }
        }),
      );
      async.flushMicrotasks();

      fireAndForget(() => policy.requestReconnect(ReconnectTrigger.userAction));
      async.flushMicrotasks();

      expect(reconnectCalls, 1);
    });
  });

  test('concurrent failure triggers only schedule one reconnect', () {
    fakeAsync((async) {
      final policy = XmppReconnectionPolicy.exponential();
      var reconnectCalls = 0;
      policy.register(() async {
        reconnectCalls++;
      });

      fireAndForget(() => policy.setShouldReconnect(true));
      final triggered = <bool>[];
      fireAndForget(() async {
        final results = await Future.wait([
          policy.canTriggerFailure(),
          policy.canTriggerFailure(),
        ]);
        triggered.addAll(results);
        for (final value in results) {
          if (value) {
            await policy.onFailure();
          }
        }
      });

      async.flushMicrotasks();
      expect(triggered.where((value) => value).length, 1);

      async.elapse(const Duration(minutes: 10));
      async.flushMicrotasks();

      expect(reconnectCalls, 1);
    });
  });

  test('concurrent requestReconnect only reconnects once', () {
    fakeAsync((async) {
      final policy = XmppReconnectionPolicy.exponential();
      final reconnectCompleter = Completer<void>();
      var reconnectCalls = 0;
      policy.register(() async {
        reconnectCalls++;
        await reconnectCompleter.future;
      });

      fireAndForget(() => policy.setShouldReconnect(true));
      fireAndForget(() async {
        await Future.wait([
          policy.requestReconnect(ReconnectTrigger.userAction),
          policy.requestReconnect(ReconnectTrigger.userAction),
        ]);
      });

      async.flushMicrotasks();
      expect(reconnectCalls, 1);

      reconnectCompleter.complete();
      async.flushMicrotasks();
    });
  });

  test('requestReconnect stays latched until onSuccess', () async {
    final policy = XmppReconnectionPolicy.exponential();
    var reconnectCalls = 0;
    policy.register(() async {
      reconnectCalls++;
    });

    await policy.setShouldReconnect(true);
    await policy.requestReconnect(ReconnectTrigger.userAction);
    await policy.requestReconnect(ReconnectTrigger.userAction);

    expect(reconnectCalls, 1);

    await policy.onSuccess();
    await policy.requestReconnect(ReconnectTrigger.userAction);

    expect(reconnectCalls, 2);
  });
}
