// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:async/async.dart';
import 'package:axichat/main.dart';
import 'package:axichat/src/common/foreground_runtime_controller.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'notification_request_state.dart';

class NotificationRequestCubit extends Cubit<NotificationRequestState> {
  NotificationRequestCubit({
    required NotificationService notificationService,
    required ForegroundRuntimeController foregroundRuntimeController,
  }) : _notificationService = notificationService,
       _foregroundRuntimeController = foregroundRuntimeController,
       super(
         NotificationRequestState(
           foregroundServiceActive: foregroundRuntimeController.isActive,
         ),
       ) {
    foregroundServiceActive.addListener(_handleForegroundServiceChanged);
  }

  final NotificationService _notificationService;
  final ForegroundRuntimeController _foregroundRuntimeController;
  CancelableOperation<bool>? _refreshPermissionsOperation;
  Future<NotificationPermissionRequestResult>? _requestPermissionsFuture;
  CancelableOperation<ForegroundActivationResult>? _enableForegroundOperation;
  CancelableOperation<bool>? _disableForegroundOperation;

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

  Future<NotificationPermissionRequestResult> requestPermissions() async {
    final existing = _requestPermissionsFuture;
    if (existing != null) {
      return existing;
    }
    _refreshPermissionsOperation?.cancel();
    _refreshPermissionsOperation = null;
    emit(
      state.copyWith(
        isCheckingPermissions: false,
        isRequestingPermissions: true,
      ),
    );
    NotificationPermissionRequestResult? requestResult;
    final requestFuture = _notificationService
        .requestAllNotificationPermissions();
    _requestPermissionsFuture = requestFuture;
    try {
      requestResult = await requestFuture;
    } finally {
      if (_requestPermissionsFuture == requestFuture) {
        _requestPermissionsFuture = null;
        emit(
          state.copyWith(
            hasPermissions: switch (requestResult) {
              NotificationPermissionRequestResult.granted => true,
              NotificationPermissionRequestResult.denied => false,
              NotificationPermissionRequestResult
                  .awaitingNotificationSettings ||
              NotificationPermissionRequestResult
                  .awaitingBatteryOptimizationSettings => state.hasPermissions,
              null => state.hasPermissions,
            },
            isRequestingPermissions: false,
          ),
        );
      }
    }
    return requestResult;
  }

  Future<bool> hasPermissionResolvedFor(
    NotificationPermissionRequestResult result,
  ) async {
    return _waitForPermissionCheck(
      () => _notificationService.hasPermissionResolvedFor(result),
    );
  }

  Future<bool> _waitForPermissionCheck(Future<bool> Function() check) async {
    if (await check()) {
      return true;
    }
    const settleDelay = Duration(milliseconds: 250);
    const settleAttempts = 16;
    for (var attempt = 0; attempt < settleAttempts; attempt += 1) {
      await Future<void>.delayed(settleDelay);
      if (await check()) {
        return true;
      }
    }
    return false;
  }

  Future<ForegroundActivationResult> enableForegroundService({
    bool allowCurrentSessionMigration = true,
  }) async {
    final existing = _enableForegroundOperation;
    if (existing != null) {
      final result = await existing.valueOrCancellation();
      return result ?? ForegroundActivationResult.failed;
    }
    emit(state.copyWith(isEnablingForeground: true));
    final operation =
        CancelableOperation<ForegroundActivationResult>.fromFuture(
          _enableForegroundService(
            allowCurrentSessionMigration: allowCurrentSessionMigration,
          ),
        );
    _enableForegroundOperation = operation;
    ForegroundActivationResult? result;
    try {
      result = await operation.valueOrCancellation();
    } finally {
      if (_enableForegroundOperation == operation) {
        _enableForegroundOperation = null;
        emit(
          state.copyWith(
            isEnablingForeground: false,
            foregroundServiceActive: foregroundServiceActive.value,
          ),
        );
      }
    }
    return result ?? ForegroundActivationResult.failed;
  }

  Future<ForegroundActivationResult> _enableForegroundService({
    required bool allowCurrentSessionMigration,
  }) async {
    return _foregroundRuntimeController.enableForUserToggle(
      allowCurrentSessionMigration: allowCurrentSessionMigration,
    );
  }

  Future<bool> disableForegroundService() async {
    final existing = _disableForegroundOperation;
    if (existing != null) {
      final disabled = await existing.valueOrCancellation();
      return disabled ?? !foregroundServiceActive.value;
    }
    emit(state.copyWith(isDisablingForeground: true));
    final operation = CancelableOperation<bool>.fromFuture(
      _disableForegroundService(),
    );
    _disableForegroundOperation = operation;
    bool? disabled;
    try {
      disabled = await operation.valueOrCancellation();
    } finally {
      if (_disableForegroundOperation == operation) {
        _disableForegroundOperation = null;
        emit(
          state.copyWith(
            isDisablingForeground: false,
            foregroundServiceActive: foregroundServiceActive.value,
          ),
        );
      }
    }
    return disabled ?? !foregroundServiceActive.value;
  }

  Future<bool> _disableForegroundService() async {
    return _foregroundRuntimeController.disableForUserToggle();
  }

  void _handleForegroundServiceChanged() {
    emit(
      state.copyWith(foregroundServiceActive: foregroundServiceActive.value),
    );
  }

  @override
  Future<void> close() async {
    foregroundServiceActive.removeListener(_handleForegroundServiceChanged);
    final operations = <CancelableOperation<Object?>?>[
      _refreshPermissionsOperation,
      _enableForegroundOperation,
      _disableForegroundOperation,
    ];
    _refreshPermissionsOperation = null;
    _requestPermissionsFuture = null;
    _enableForegroundOperation = null;
    _disableForegroundOperation = null;
    await Future.wait(
      operations.whereType<CancelableOperation<Object?>>().map(
        (operation) => operation.cancel(),
      ),
    );
    return super.close();
  }
}
