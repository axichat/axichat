// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';

part 'connectivity_state.dart';

class ConnectivityCubit extends Cubit<ConnectivityState> {
  ConnectivityCubit({
    required XmppBase xmppBase,
  })  : _xmppBase = xmppBase,
        super(stateMap(xmppBase.connectionState)) {
    _connectivitySubscription = _xmppBase.connectivityStream.listen(
      (e) => emit(stateMap(e)),
    );
  }

  static ConnectivityState stateMap(ConnectionState connectionState) =>
      switch (connectionState) {
        ConnectionState.connected => const ConnectivityConnected(),
        ConnectionState.connecting => const ConnectivityConnecting(),
        ConnectionState.notConnected => const ConnectivityNotConnected(),
        ConnectionState.error => const ConnectivityError(),
      };

  final XmppBase _xmppBase;

  late final StreamSubscription<ConnectionState> _connectivitySubscription;

  @override
  Future<void> close() {
    _connectivitySubscription.cancel();
    return super.close();
  }
}
