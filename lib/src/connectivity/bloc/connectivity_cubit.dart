import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';

part 'connectivity_state.dart';

class ConnectivityCubit extends Cubit<ConnectivityState> {
  ConnectivityCubit({
    required XmppService xmppService,
  })  : _xmppService = xmppService,
        super(stateMap(xmppService.connectionState)) {
    _connectivitySubscription = _xmppService.connectivityStream.listen(
      (e) => emit(stateMap(e)),
    );
  }

  static stateMap(ConnectionState connectionState) => switch (connectionState) {
        ConnectionState.connected => const ConnectivityConnected(),
        ConnectionState.connecting => const ConnectivityConnecting(),
        ConnectionState.notConnected => const ConnectivityNotConnected(),
        ConnectionState.error => const ConnectivityError(),
      };

  final XmppService _xmppService;

  late final StreamSubscription<ConnectionState> _connectivitySubscription;

  @override
  Future<void> close() {
    _connectivitySubscription.cancel();
    return super.close();
  }
}
