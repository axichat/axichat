// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:async/async.dart';
import 'package:axichat/main.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'notification_request_state.dart';

class NotificationRequestCubit extends Cubit<NotificationRequestState> {
  NotificationRequestCubit({
    required NotificationService notificationService,
    required XmppService xmppService,
  }) : _notificationService = notificationService,
       _xmppService = xmppService,
       super(
         NotificationRequestState(
           foregroundServiceActive: foregroundServiceActive.value,
         ),
       ) {
    foregroundServiceActive.addListener(_handleForegroundServiceChanged);
  }

  final NotificationService _notificationService;
  final XmppService _xmppService;
  CancelableOperation<bool>? _refreshPermissionsOperation;
  CancelableOperation<bool>? _requestPermissionsOperation;
  CancelableOperation<bool>? _enableForegroundOperation;

  Future<void> refreshPermissions() async {
    _refreshPermissionsOperation?.cancel();
    emit(state.copyWith(isCheckingPermissions: true));
    final operation = CancelableOperation<bool>.fromFuture(
      _notificationService.hasAllNotificationPermissions(),
    );
    _refreshPermissionsOperation = operation;
    bool? hasPermissions;
    try {
      hasPermissions = await operation.valueOrCancellation();
    } finally {
      if (_refreshPermissionsOperation == operation) {
        _refreshPermissionsOperation = null;
        emit(
          state.copyWith(
            hasPermissions: hasPermissions ?? state.hasPermissions,
            isCheckingPermissions: false,
          ),
        );
      }
    }
  }

  Future<bool> requestPermissions() async {
    _requestPermissionsOperation?.cancel();
    emit(state.copyWith(isRequestingPermissions: true));
    final operation = CancelableOperation<bool>.fromFuture(
      _notificationService.requestAllNotificationPermissions(),
    );
    _requestPermissionsOperation = operation;
    bool? hasPermissions;
    try {
      hasPermissions = await operation.valueOrCancellation();
    } finally {
      if (_requestPermissionsOperation == operation) {
        _requestPermissionsOperation = null;
        emit(
          state.copyWith(
            hasPermissions: hasPermissions ?? state.hasPermissions,
            isRequestingPermissions: false,
          ),
        );
      }
    }
    return hasPermissions ?? state.hasPermissions ?? false;
  }

  Future<bool> enableForegroundService() async {
    if (state.foregroundServiceActive) {
      return true;
    }
    final existing = _enableForegroundOperation;
    if (existing != null) {
      final enabled = await existing.valueOrCancellation();
      return enabled ?? foregroundServiceActive.value;
    }
    emit(state.copyWith(isEnablingForeground: true));
    final operation = CancelableOperation<bool>.fromFuture(
      _enableForegroundService(),
    );
    _enableForegroundOperation = operation;
    bool? enabled;
    try {
      enabled = await operation.valueOrCancellation();
    } finally {
      if (_enableForegroundOperation == operation) {
        _enableForegroundOperation = null;
        emit(
          state.copyWith(
            isEnablingForeground: false,
            foregroundServiceActive: enabled ?? foregroundServiceActive.value,
          ),
        );
      }
    }
    return enabled ?? foregroundServiceActive.value;
  }

  Future<bool> _enableForegroundService() async {
    withForeground = true;
    foregroundServiceActive.value = true;
    initForegroundService();
    await _xmppService.ensureForegroundSocketIfActive();
    return foregroundServiceActive.value;
  }

  void disableForegroundService() {
    if (!foregroundServiceActive.value) {
      return;
    }
    foregroundServiceActive.value = false;
  }

  void _handleForegroundServiceChanged() {
    emit(
      state.copyWith(foregroundServiceActive: foregroundServiceActive.value),
    );
  }

  @override
  Future<void> close() async {
    foregroundServiceActive.removeListener(_handleForegroundServiceChanged);
    final operations = <CancelableOperation<bool>?>[
      _refreshPermissionsOperation,
      _requestPermissionsOperation,
      _enableForegroundOperation,
    ];
    _refreshPermissionsOperation = null;
    _requestPermissionsOperation = null;
    _enableForegroundOperation = null;
    await Future.wait(
      operations.whereType<CancelableOperation<bool>>().map(
        (operation) => operation.cancel(),
      ),
    );
    return super.close();
  }
}
