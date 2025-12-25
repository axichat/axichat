import 'dart:async';

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
      unawaited(
        policy.canTriggerFailure().then((value) {
          triggered = value;
          if (value) {
            unawaited(policy.onFailure());
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

      unawaited(policy.setShouldReconnect(true));
      var triggered = false;
      unawaited(
        policy.canTriggerFailure().then((value) {
          triggered = value;
          if (value) {
            unawaited(policy.onFailure());
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

      unawaited(policy.setShouldReconnect(true));
      unawaited(
        policy.canTriggerFailure().then((value) {
          if (value) {
            unawaited(policy.onFailure());
          }
        }),
      );

      async.flushMicrotasks();
      unawaited(policy.setShouldReconnect(false));

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

      unawaited(policy.setShouldReconnect(true));
      unawaited(
        policy.canTriggerFailure().then((value) {
          if (value) {
            unawaited(policy.onFailure());
          }
        }),
      );
      async.flushMicrotasks();

      unawaited(policy.requestReconnect(ReconnectTrigger.userAction));
      async.flushMicrotasks();

      expect(reconnectCalls, 1);
    });
  });
}
