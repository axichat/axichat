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

      final outcomes = <ReconnectRequestOutcome>[];
      fireAndForget(() async {
        outcomes.add(
          await policy.requestReconnect(ReconnectTrigger.immediateRetry),
        );
      });
      async.flushMicrotasks();

      expect(reconnectCalls, 1);
      expect(outcomes, [ReconnectRequestOutcome.dispatched]);
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
      final outcomes = <ReconnectRequestOutcome>[];
      fireAndForget(() async {
        outcomes.addAll(
          await Future.wait([
            policy.requestReconnect(ReconnectTrigger.immediateRetry),
            policy.requestReconnect(ReconnectTrigger.immediateRetry),
          ]),
        );
      });

      async.flushMicrotasks();
      expect(reconnectCalls, 1);

      reconnectCompleter.complete();
      async.flushMicrotasks();
      expect(
        outcomes,
        containsAll([
          ReconnectRequestOutcome.dispatched,
          ReconnectRequestOutcome.joinedActiveCycle,
        ]),
      );
    });
  });

  test('resume and networkAvailable share one reconnect action', () {
    fakeAsync((async) {
      final policy = XmppReconnectionPolicy.exponential();
      final reconnectCompleter = Completer<void>();
      var reconnectCalls = 0;
      policy.register(() async {
        reconnectCalls++;
        await reconnectCompleter.future;
      });

      fireAndForget(() => policy.setShouldReconnect(true));
      final outcomes = <ReconnectRequestOutcome>[];
      fireAndForget(() async {
        outcomes.addAll(
          await Future.wait([
            policy.requestReconnect(ReconnectTrigger.resume),
            policy.requestReconnect(ReconnectTrigger.networkAvailable),
          ]),
        );
      });

      async.flushMicrotasks();
      expect(reconnectCalls, 1);

      reconnectCompleter.complete();
      async.flushMicrotasks();
      expect(
        outcomes,
        containsAll([
          ReconnectRequestOutcome.dispatched,
          ReconnectRequestOutcome.joinedActiveCycle,
        ]),
      );
    });
  });

  test('requestReconnect reports ignored triggers', () async {
    final policy = XmppReconnectionPolicy.exponential();

    expect(
      await policy.requestReconnect(ReconnectTrigger.immediateRetry),
      ReconnectRequestOutcome.ignored,
    );

    await policy.setShouldReconnect(true);

    expect(
      await policy.requestReconnect(ReconnectTrigger.autoFailure),
      ReconnectRequestOutcome.ignored,
    );
  });

  test(
    'requestReconnect stays latched through reset and onSuccess until completeReconnect',
    () async {
      final policy = XmppReconnectionPolicy.exponential();
      var reconnectCalls = 0;
      policy.register(() async {
        reconnectCalls++;
      });

      await policy.setShouldReconnect(true);
      expect(
        await policy.requestReconnect(ReconnectTrigger.immediateRetry),
        ReconnectRequestOutcome.dispatched,
      );
      await policy.reset();
      expect(
        await policy.requestReconnect(ReconnectTrigger.immediateRetry),
        ReconnectRequestOutcome.joinedActiveCycle,
      );

      expect(reconnectCalls, 1);
      expect(policy.reconnectActivity, XmppReconnectActivity.awaitingSocket);

      await policy.onSuccess();
      expect(
        await policy.requestReconnect(ReconnectTrigger.immediateRetry),
        ReconnectRequestOutcome.joinedActiveCycle,
      );

      expect(reconnectCalls, 1);
      expect(
        policy.reconnectActivity,
        XmppReconnectActivity.awaitingNegotiation,
      );

      await policy.completeReconnect();
      expect(policy.reconnectActivity, XmppReconnectActivity.inactive);
      expect(
        await policy.requestReconnect(ReconnectTrigger.immediateRetry),
        ReconnectRequestOutcome.dispatched,
      );

      expect(reconnectCalls, 2);
    },
  );

  test('pre-socket reconnect does not move into negotiation backoff', () async {
    final policy = XmppReconnectionPolicy.exponential();
    var reconnectCalls = 0;
    policy.register(() async {
      reconnectCalls++;
    });

    await policy.setShouldReconnect(true);
    expect(
      await policy.requestReconnect(ReconnectTrigger.immediateRetry),
      ReconnectRequestOutcome.dispatched,
    );

    expect(await policy.moveAwaitingNegotiationToBackoff(), isFalse);
    expect(reconnectCalls, 1);
    expect(policy.reconnectActivity, XmppReconnectActivity.awaitingSocket);
  });

  test('socket failure moves pre-socket reconnect to backoff', () {
    fakeAsync((async) {
      final policy = XmppReconnectionPolicy.exponential();
      var reconnectCalls = 0;
      policy.register(() async {
        reconnectCalls++;
      });

      var movedToBackoff = false;
      fireAndForget(() async {
        await policy.setShouldReconnect(true);
        await policy.requestReconnect(ReconnectTrigger.immediateRetry);
        movedToBackoff = await policy.moveAwaitingSocketToBackoff();
      });
      async.flushMicrotasks();

      expect(reconnectCalls, 1);
      expect(movedToBackoff, isTrue);
      expect(policy.reconnectActivity, XmppReconnectActivity.scheduledBackoff);

      final outcomes = <ReconnectRequestOutcome>[];
      fireAndForget(() async {
        outcomes.add(await policy.requestReconnect(ReconnectTrigger.resume));
      });
      async.flushMicrotasks();

      expect(outcomes, [ReconnectRequestOutcome.dispatched]);
      expect(reconnectCalls, 2);
      expect(policy.reconnectActivity, XmppReconnectActivity.awaitingSocket);
    });
  });

  test('awaiting negotiation cycle can move into backoff and retry', () {
    fakeAsync((async) {
      final policy = XmppReconnectionPolicy.exponential();
      var reconnectCalls = 0;
      policy.register(() async {
        reconnectCalls++;
      });

      var movedToBackoff = false;
      fireAndForget(() async {
        await policy.setShouldReconnect(true);
        await policy.requestReconnect(ReconnectTrigger.immediateRetry);
        await policy.onSuccess();
        movedToBackoff = await policy.moveAwaitingNegotiationToBackoff();
      });
      async.flushMicrotasks();

      expect(reconnectCalls, 1);
      expect(movedToBackoff, isTrue);
      expect(policy.reconnectActivity, XmppReconnectActivity.scheduledBackoff);

      async.elapse(const Duration(minutes: 10));
      async.flushMicrotasks();

      expect(reconnectCalls, 2);
      expect(policy.reconnectActivity, XmppReconnectActivity.awaitingSocket);
    });
  });
}
