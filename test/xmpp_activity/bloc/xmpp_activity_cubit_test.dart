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

      final cubit = XmppActivityCubit(xmppBase: xmppService);

      operationEvents.add(
        XmppOperationEvent(
          kind: XmppOperationKind.pubSubConversations,
          stage: XmppOperationStage.start,
        ),
      );

      expect(cubit.state.operations, hasLength(1));
      expect(
        cubit.state.operations.single.status,
        XmppOperationStatus.inProgress,
      );

      connectionState = ConnectionState.connecting;
      connectionStates.add(ConnectionState.connecting);

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

      final cubit = XmppActivityCubit(
        xmppBase: xmppService,
        completedRetention: const Duration(milliseconds: 1),
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

      expect(
        cubit.state.operations.single.status,
        XmppOperationStatus.inProgress,
      );

      async.elapse(const Duration(milliseconds: 350));

      expect(cubit.state.operations.single.status, XmppOperationStatus.success);

      async.elapse(const Duration(milliseconds: 1));

      expect(cubit.state.operations, isEmpty);

      unawaited(cubit.close());
      unawaited(operationEvents.close());
      unawaited(connectionStates.close());
      async.flushMicrotasks();
    });
  });
}
