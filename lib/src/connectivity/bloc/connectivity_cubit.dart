// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/network_availability.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';

part 'connectivity_state.dart';

class ConnectivityCubit extends Cubit<ConnectivityState> {
  ConnectivityCubit({
    required XmppBase xmppBase,
    required bool emailEnabled,
    EmailService? emailService,
    Stream<NetworkAvailability>? networkAvailabilityStream,
    NetworkAvailability? initialNetworkAvailability,
  }) : _xmppBase = xmppBase,
       _emailEnabled = emailEnabled,
       _emailService = emailService,
       _networkAvailabilityStream =
           networkAvailabilityStream ??
           NetworkAvailabilityService.instance.stream,
       _ownsNetworkAvailabilityService = networkAvailabilityStream == null,
       _networkAvailability =
           initialNetworkAvailability ??
           NetworkAvailabilityService.instance.current,
       super(
         stateMap(
           xmppBase.connectionState,
           emailState: emailService?.syncState ?? const EmailSyncState.ready(),
           emailEnabled: emailEnabled,
           demoOffline: xmppBase.demoOfflineMode,
           networkAvailability:
               initialNetworkAvailability ??
               NetworkAvailabilityService.instance.current,
         ),
       ) {
    _connectivitySubscription = _xmppBase.connectivityStream.listen(
      (e) => emit(
        stateMap(
          e,
          emailState: state.emailState,
          emailEnabled: state.emailEnabled,
          demoOffline: _xmppBase.demoOfflineMode,
          networkAvailability: _networkAvailability,
        ),
      ),
    );
    _emailSyncSubscription = _emailService?.syncStateStream.listen(
      _handleEmailSyncState,
    );
    _networkAvailabilitySubscription = _networkAvailabilityStream.listen(
      _handleNetworkAvailability,
    );
    if (_ownsNetworkAvailabilityService) {
      fireAndForget(
        () => NetworkAvailabilityService.instance.start(),
        operationName: 'ConnectivityCubit.startNetworkAvailabilityService',
      );
    }
  }

  static ConnectivityState stateMap(
    ConnectionState connectionState, {
    required EmailSyncState emailState,
    required bool emailEnabled,
    required bool demoOffline,
    NetworkAvailability networkAvailability = NetworkAvailability.unknown,
  }) {
    return switch (connectionState) {
      ConnectionState.connected => ConnectivityConnected(
        emailState: emailState,
        emailEnabled: emailEnabled,
        demoOffline: demoOffline,
        networkAvailability: networkAvailability,
      ),
      ConnectionState.connecting => ConnectivityConnecting(
        emailState: emailState,
        emailEnabled: emailEnabled,
        demoOffline: demoOffline,
        networkAvailability: networkAvailability,
      ),
      ConnectionState.notConnected => ConnectivityNotConnected(
        emailState: emailState,
        emailEnabled: emailEnabled,
        demoOffline: demoOffline,
        networkAvailability: networkAvailability,
      ),
      ConnectionState.error => ConnectivityError(
        emailState: emailState,
        emailEnabled: emailEnabled,
        demoOffline: demoOffline,
        networkAvailability: networkAvailability,
      ),
    };
  }

  final XmppBase _xmppBase;
  EmailService? _emailService;
  bool _emailEnabled;
  final Stream<NetworkAvailability> _networkAvailabilityStream;
  final bool _ownsNetworkAvailabilityService;
  NetworkAvailability _networkAvailability;

  late final StreamSubscription<ConnectionState> _connectivitySubscription;
  StreamSubscription<EmailSyncState>? _emailSyncSubscription;
  late final StreamSubscription<NetworkAvailability>
  _networkAvailabilitySubscription;

  void _handleEmailSyncState(EmailSyncState emailState) {
    emit(
      stateMap(
        _xmppBase.connectionState,
        emailState: emailState,
        emailEnabled: _emailEnabled,
        demoOffline: _xmppBase.demoOfflineMode,
        networkAvailability: _networkAvailability,
      ),
    );
  }

  void _handleNetworkAvailability(NetworkAvailability availability) {
    _networkAvailability = availability;
    emit(
      stateMap(
        _xmppBase.connectionState,
        emailState: state.emailState,
        emailEnabled: state.emailEnabled,
        demoOffline: _xmppBase.demoOfflineMode,
        networkAvailability: availability,
      ),
    );
  }

  Future<void> updateEmailContext({
    required bool emailEnabled,
    EmailService? emailService,
  }) async {
    if (_emailEnabled == emailEnabled &&
        identical(_emailService, emailService)) {
      return;
    }
    _emailEnabled = emailEnabled;
    final emailSub = _emailSyncSubscription;
    _emailSyncSubscription = null;
    await emailSub?.cancel();
    _emailService = emailService;
    if (emailService != null) {
      _emailSyncSubscription = emailService.syncStateStream.listen(
        _handleEmailSyncState,
      );
    }
    emit(
      stateMap(
        _xmppBase.connectionState,
        emailState: emailService?.syncState ?? const EmailSyncState.ready(),
        emailEnabled: _emailEnabled,
        demoOffline: _xmppBase.demoOfflineMode,
        networkAvailability: _networkAvailability,
      ),
    );
  }

  Future<void> resetDemoInteractivePhase() async {
    final xmppBase = _xmppBase;
    if (xmppBase is! XmppService) return;
    await xmppBase.resetDemoInteractivePhase();
    emit(
      stateMap(
        _xmppBase.connectionState,
        emailState: state.emailState,
        emailEnabled: state.emailEnabled,
        demoOffline: _xmppBase.demoOfflineMode,
        networkAvailability: _networkAvailability,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _connectivitySubscription.cancel();
    await _emailSyncSubscription?.cancel();
    await _networkAvailabilitySubscription.cancel();
    if (_ownsNetworkAvailabilityService) {
      await NetworkAvailabilityService.instance.stop();
    }
    return super.close();
  }
}
