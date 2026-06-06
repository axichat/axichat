// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:axichat/src/xmpp_activity/bloc/xmpp_activity_cubit.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

extension on FakeAsync {
  void elapseActivityEmit() {
    elapse(const Duration(milliseconds: 16));
  }
}

void main() {
  test('clears in-progress operations when XMPP disconnects', () {
    fakeAsync((async) {
      final operationEvents = StreamController<XmppOperationEvent>.broadcast(
        sync: true,
      );
      final connectionStates = StreamController<ConnectionState>.broadcast(
        sync: true,
      );
      var connectionState = ConnectionState.connected;
      final xmppService = MockXmppService();
      when(
        () => xmppService.xmppOperationStream,
      ).thenAnswer((_) => operationEvents.stream);
      when(
        () => xmppService.connectivityStream,
      ).thenAnswer((_) => connectionStates.stream);
      when(
        () => xmppService.connectionState,
      ).thenAnswer((_) => connectionState);
      when(() => xmppService.demoOfflineMode).thenReturn(false);

      final cubit = XmppActivityCubit(xmppBase: xmppService);

      operationEvents.add(
        XmppOperationEvent(
          kind: XmppOperationKind.pubSubConversations,
          stage: XmppOperationStage.start,
        ),
      );
      async.elapseActivityEmit();

      expect(cubit.state.operations, hasLength(1));
      expect(
        cubit.state.operations.single.status,
        XmppOperationStatus.inProgress,
      );

      connectionState = ConnectionState.connecting;
      connectionStates.add(ConnectionState.connecting);
      async.elapseActivityEmit();

      expect(cubit.state.operations, isEmpty);

      unawaited(cubit.close());
      unawaited(operationEvents.close());
      unawaited(connectionStates.close());
      async.flushMicrotasks();
    });
  });

  test('allows demo offline operations without XMPP connection', () {
    fakeAsync((async) {
      final operationEvents = StreamController<XmppOperationEvent>.broadcast(
        sync: true,
      );
      final connectionStates = StreamController<ConnectionState>.broadcast(
        sync: true,
      );
      final xmppService = MockXmppService();
      when(
        () => xmppService.xmppOperationStream,
      ).thenAnswer((_) => operationEvents.stream);
      when(
        () => xmppService.connectivityStream,
      ).thenAnswer((_) => connectionStates.stream);
      when(
        () => xmppService.connectionState,
      ).thenReturn(ConnectionState.notConnected);
      when(() => xmppService.demoOfflineMode).thenReturn(true);

      final cubit = XmppActivityCubit(
        xmppBase: xmppService,
        completedRetention: const Duration(milliseconds: 32),
      );

      operationEvents.add(
        XmppOperationEvent(
          kind: XmppOperationKind.pubSubConversations,
          stage: XmppOperationStage.start,
        ),
      );
      connectionStates.add(ConnectionState.notConnected);
      async.elapseActivityEmit();

      expect(
        cubit.state.operations.single.status,
        XmppOperationStatus.inProgress,
      );

      operationEvents.add(
        XmppOperationEvent(
          kind: XmppOperationKind.pubSubConversations,
          stage: XmppOperationStage.end,
        ),
      );

      expect(
        cubit.state.operations.single.status,
        XmppOperationStatus.inProgress,
      );

      async.elapse(const Duration(milliseconds: 350));
      async.elapseActivityEmit();

      expect(cubit.state.operations.single.status, XmppOperationStatus.success);

      async.elapse(const Duration(milliseconds: 32));
      async.elapseActivityEmit();

      expect(cubit.state.operations, isEmpty);

      unawaited(cubit.close());
      unawaited(operationEvents.close());
      unawaited(connectionStates.close());
      async.flushMicrotasks();
    });
  });

  test('completed operations retain success before teardown', () {
    fakeAsync((async) {
      final operationEvents = StreamController<XmppOperationEvent>.broadcast(
        sync: true,
      );
      final connectionStates = StreamController<ConnectionState>.broadcast(
        sync: true,
      );
      final xmppService = MockXmppService();
      when(
        () => xmppService.xmppOperationStream,
      ).thenAnswer((_) => operationEvents.stream);
      when(
        () => xmppService.connectivityStream,
      ).thenAnswer((_) => connectionStates.stream);
      when(
        () => xmppService.connectionState,
      ).thenReturn(ConnectionState.connected);
      when(() => xmppService.demoOfflineMode).thenReturn(false);

      final cubit = XmppActivityCubit(
        xmppBase: xmppService,
        completedRetention: const Duration(milliseconds: 32),
      );

      operationEvents
        ..add(
          XmppOperationEvent(
            kind: XmppOperationKind.pubSubConversations,
            stage: XmppOperationStage.start,
          ),
        )
        ..add(
          XmppOperationEvent(
            kind: XmppOperationKind.pubSubConversations,
            stage: XmppOperationStage.end,
          ),
        );
      async.elapseActivityEmit();

      expect(
        cubit.state.operations.single.status,
        XmppOperationStatus.inProgress,
      );

      async.elapse(const Duration(milliseconds: 350));
      async.elapseActivityEmit();

      expect(cubit.state.operations.single.status, XmppOperationStatus.success);

      async.elapse(const Duration(milliseconds: 32));
      async.elapseActivityEmit();

      expect(cubit.state.operations, isEmpty);

      unawaited(cubit.close());
      unawaited(operationEvents.close());
      unawaited(connectionStates.close());
      async.flushMicrotasks();
    });
  });

  test('coalesces a mocked post-login activity storm by UI phase', () {
    fakeAsync((async) {
      final operationEvents = StreamController<XmppOperationEvent>.broadcast(
        sync: true,
      );
      final connectionStates = StreamController<ConnectionState>.broadcast(
        sync: true,
      );
      final xmppService = MockXmppService();
      when(
        () => xmppService.xmppOperationStream,
      ).thenAnswer((_) => operationEvents.stream);
      when(
        () => xmppService.connectivityStream,
      ).thenAnswer((_) => connectionStates.stream);
      when(
        () => xmppService.connectionState,
      ).thenReturn(ConnectionState.connected);
      when(() => xmppService.demoOfflineMode).thenReturn(false);

      final cubit = XmppActivityCubit(
        xmppBase: xmppService,
        completedRetention: const Duration(milliseconds: 32),
      );
      final emissions = <XmppActivityState>[];
      final subscription = cubit.stream.listen(emissions.add);
      final postLoginKinds = <XmppOperationKind>[
        XmppOperationKind.pubSubConversations,
        XmppOperationKind.pubSubBookmarks,
        XmppOperationKind.pubSubDrafts,
        XmppOperationKind.pubSubSpam,
        XmppOperationKind.pubSubAddressBlock,
        XmppOperationKind.pubSubAvatarMetadata,
        XmppOperationKind.mamGlobalSync,
        XmppOperationKind.mamMucSync,
        XmppOperationKind.mamFetch,
      ];

      for (var index = 0; index < 20; index++) {
        for (final kind in postLoginKinds) {
          operationEvents.add(
            XmppOperationEvent(kind: kind, stage: XmppOperationStage.start),
          );
        }
      }

      expect(emissions, isEmpty);

      async.elapseActivityEmit();

      expect(emissions, hasLength(1));
      expect(
        cubit.state.operations.map((operation) => operation.kind),
        unorderedEquals(postLoginKinds),
      );
      expect(
        cubit.state.operations.map((operation) => operation.status),
        everyElement(XmppOperationStatus.inProgress),
      );

      for (var index = 0; index < 20; index++) {
        for (final kind in postLoginKinds) {
          operationEvents.add(
            XmppOperationEvent(kind: kind, stage: XmppOperationStage.end),
          );
        }
      }

      expect(emissions, hasLength(1));

      async.elapse(const Duration(milliseconds: 350));
      async.elapseActivityEmit();

      expect(emissions, hasLength(2));
      expect(
        cubit.state.operations.map((operation) => operation.status),
        everyElement(XmppOperationStatus.success),
      );

      async.elapse(const Duration(milliseconds: 32));
      async.elapseActivityEmit();

      expect(emissions, hasLength(3));
      expect(cubit.state.operations, isEmpty);

      unawaited(subscription.cancel());
      unawaited(cubit.close());
      unawaited(operationEvents.close());
      unawaited(connectionStates.close());
      async.flushMicrotasks();
    });
  });
}
