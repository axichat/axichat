// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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
  })  : _notificationService = notificationService,
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

  Future<void> refreshPermissions() async {
    emit(state.copyWith(isCheckingPermissions: true));
    final hasPermissions =
        await _notificationService.hasAllNotificationPermissions();
    emit(
      state.copyWith(
        hasPermissions: hasPermissions,
        isCheckingPermissions: false,
      ),
    );
  }

  Future<bool> requestPermissions() async {
    emit(state.copyWith(isRequestingPermissions: true));
    final hasPermissions =
        await _notificationService.requestAllNotificationPermissions();
    emit(
      state.copyWith(
        hasPermissions: hasPermissions,
        isRequestingPermissions: false,
      ),
    );
    return hasPermissions;
  }

  Future<bool> enableForegroundService() async {
    if (state.foregroundServiceActive) {
      return true;
    }
    emit(state.copyWith(isEnablingForeground: true));
    withForeground = true;
    foregroundServiceActive.value = true;
    initForegroundService();
    await _xmppService.ensureForegroundSocketIfActive();
    emit(
      state.copyWith(
        isEnablingForeground: false,
        foregroundServiceActive: foregroundServiceActive.value,
      ),
    );
    return foregroundServiceActive.value;
  }

  void _handleForegroundServiceChanged() {
    emit(
      state.copyWith(
        foregroundServiceActive: foregroundServiceActive.value,
      ),
    );
  }

  @override
  Future<void> close() {
    foregroundServiceActive.removeListener(_handleForegroundServiceChanged);
    return super.close();
  }
}
