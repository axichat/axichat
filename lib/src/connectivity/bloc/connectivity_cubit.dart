// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';

part 'connectivity_state.dart';

class ConnectivityCubit extends Cubit<ConnectivityState> {
  ConnectivityCubit({
    required XmppBase xmppBase,
    required bool emailEnabled,
    EmailService? emailService,
  }) : _xmppBase = xmppBase,
       _emailEnabled = emailEnabled,
       _emailService = emailService,
       super(
         stateMap(
           xmppBase.connectionState,
           emailState: emailService?.syncState ?? const EmailSyncState.ready(),
            emailEnabled: emailEnabled,
            demoOffline: xmppBase.demoOfflineMode,
          ),
        ) {
    _connectivitySubscription = _xmppBase.connectivityStream.listen(
      (e) => emit(
        stateMap(
          e,
          emailState: state.emailState,
          emailEnabled: state.emailEnabled,
          demoOffline: _xmppBase.demoOfflineMode,
        ),
      ),
    );
    _emailSyncSubscription = _emailService?.syncStateStream.listen(
      _handleEmailSyncState,
    );
  }

  static ConnectivityState stateMap(
    ConnectionState connectionState, {
    required EmailSyncState emailState,
    required bool emailEnabled,
    required bool demoOffline,
  }) => switch (connectionState) {
    ConnectionState.connected => ConnectivityConnected(
      emailState: emailState,
      emailEnabled: emailEnabled,
      demoOffline: demoOffline,
    ),
    ConnectionState.connecting => ConnectivityConnecting(
      emailState: emailState,
      emailEnabled: emailEnabled,
      demoOffline: demoOffline,
    ),
    ConnectionState.notConnected => ConnectivityNotConnected(
      emailState: emailState,
      emailEnabled: emailEnabled,
      demoOffline: demoOffline,
    ),
    ConnectionState.error => ConnectivityError(
      emailState: emailState,
      emailEnabled: emailEnabled,
      demoOffline: demoOffline,
    ),
  };

  final XmppBase _xmppBase;
  EmailService? _emailService;
  bool _emailEnabled;

  late final StreamSubscription<ConnectionState> _connectivitySubscription;
  StreamSubscription<EmailSyncState>? _emailSyncSubscription;

  void _handleEmailSyncState(EmailSyncState emailState) {
    emit(
      stateMap(
        _xmppBase.connectionState,
        emailState: emailState,
        emailEnabled: _emailEnabled,
        demoOffline: _xmppBase.demoOfflineMode,
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
      ),
    );
  }

  @override
  Future<void> close() async {
    await _connectivitySubscription.cancel();
    await _emailSyncSubscription?.cancel();
    return super.close();
  }
}
