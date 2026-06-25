// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:async/async.dart';
import 'package:axichat/main.dart';
import 'package:axichat/src/common/foreground_runtime_controller.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'notification_request_state.dart';

enum NotificationBackgroundMessagingPhase {
  idle,
  requestingPermissions,
  awaitingNotificationSettingsResume,
  awaitingBatteryOptimizationSettingsResume,
  awaitingPermissionGrantResume,
  activatingForeground,
  disablingForeground,
  persistingPreference;

  bool get isBusy => this != NotificationBackgroundMessagingPhase.idle;

  NotificationPermissionRequestResult? get awaitedPermissionResult {
    switch (this) {
      case NotificationBackgroundMessagingPhase
          .awaitingNotificationSettingsResume:
        return NotificationPermissionRequestResult.awaitingNotificationSettings;
      case NotificationBackgroundMessagingPhase
          .awaitingBatteryOptimizationSettingsResume:
        return NotificationPermissionRequestResult
            .awaitingBatteryOptimizationSettings;
      case NotificationBackgroundMessagingPhase.idle:
      case NotificationBackgroundMessagingPhase.requestingPermissions:
      case NotificationBackgroundMessagingPhase.awaitingPermissionGrantResume:
      case NotificationBackgroundMessagingPhase.activatingForeground:
      case NotificationBackgroundMessagingPhase.disablingForeground:
      case NotificationBackgroundMessagingPhase.persistingPreference:
        return null;
    }
  }
}

class NotificationRequestCubit extends Cubit<NotificationRequestState> {
  NotificationRequestCubit({
    required NotificationService notificationService,
    required ForegroundRuntimeController foregroundRuntimeController,
    required Future<void> Function(bool enabled, {String? accountJid})
    persistBackgroundMessagingPreference,
    required String? Function() accountJidProvider,
    AppLifecycleState? Function()? lifecycleStateProvider,
  }) : _notificationService = notificationService,
       _foregroundRuntimeController = foregroundRuntimeController,
       _persistBackgroundMessagingPreference =
           persistBackgroundMessagingPreference,
       _accountJidProvider = accountJidProvider,
       _lifecycleStateProvider =
           lifecycleStateProvider ??
           (() => SchedulerBinding.instance.lifecycleState),
       super(
         NotificationRequestState(
           foregroundServiceActive: foregroundRuntimeController.isActive,
         ),
       ) {
    foregroundServiceActive.addListener(_handleForegroundServiceChanged);
  }

  final NotificationService _notificationService;
  final ForegroundRuntimeController _foregroundRuntimeController;
  final Future<void> Function(bool enabled, {String? accountJid})
  _persistBackgroundMessagingPreference;
  final String? Function() _accountJidProvider;
  final AppLifecycleState? Function() _lifecycleStateProvider;
  CancelableOperation<bool>? _refreshPermissionsOperation;
  Future<NotificationPermissionRequestResult>? _requestPermissionsFuture;
  CancelableOperation<ForegroundActivationResult>? _enableForegroundOperation;
  CancelableOperation<bool>? _disableForegroundOperation;
  CancelableOperation<void>? _backgroundMessagingOperation;
  DateTime? _permissionDetachAllowanceExpiresAt;
  var _permissionDetachAllowanceCount = 0;
  String? _pendingBackgroundMessagingAccountJid;

  Future<void> enableBackgroundMessaging() {
    return _runBackgroundMessagingOperation(_enableBackgroundMessaging);
  }

  Future<void> disableBackgroundMessaging() {
    return _runBackgroundMessagingOperation(_disableBackgroundMessaging);
  }

  Future<void> resumePendingBackgroundMessagingEnable() {
    return _resumePendingBackgroundMessagingEnableAfterActiveOperation();
  }

  Future<void> handleLifecycleResume() {
    return _handleLifecycleResumeAfterActiveOperation();
  }

  Future<void>
  _resumePendingBackgroundMessagingEnableAfterActiveOperation() async {
    final existing = _backgroundMessagingOperation;
    if (existing != null) {
      await existing.valueOrCancellation();
    }
    await _runBackgroundMessagingOperation(
      _resumePendingBackgroundMessagingEnable,
    );
  }

  Future<void> _handleLifecycleResumeAfterActiveOperation() async {
    final existing = _backgroundMessagingOperation;
    if (existing != null) {
      await existing.valueOrCancellation();
    }
    await _runBackgroundMessagingOperation(_handleLifecycleResume);
  }

  bool consumePermissionDetachAllowance() {
    if (!_permissionDetachAllowanceActive) {
      _endPermissionDetachAllowance();
      return false;
    }
    if (_permissionDetachAllowanceCount == 0) {
      return false;
    }
    _permissionDetachAllowanceCount -= 1;
    return true;
  }

  Future<void> _runBackgroundMessagingOperation(
    Future<void> Function() action,
  ) async {
    final existing = _backgroundMessagingOperation;
    if (existing != null) {
      await existing.valueOrCancellation();
      return;
    }
    final operation = CancelableOperation<void>.fromFuture(action());
    _backgroundMessagingOperation = operation;
    try {
      await operation.valueOrCancellation();
    } finally {
      if (_backgroundMessagingOperation == operation) {
        _backgroundMessagingOperation = null;
      }
    }
  }

  Future<void> _enableBackgroundMessaging() async {
    _pendingBackgroundMessagingAccountJid = _accountJidProvider();
    if (state.hasPermissions == true) {
      await _activateForegroundAndPersist();
      return;
    }
    await _requestPermissionsAndEnable();
  }

  Future<void> _disableBackgroundMessaging() async {
    _pendingBackgroundMessagingAccountJid = _accountJidProvider();
    _endPermissionDetachAllowance();
    emit(
      state.copyWith(
        backgroundMessagingPhase:
            NotificationBackgroundMessagingPhase.disablingForeground,
      ),
    );
    try {
      final foregroundDisabled = await disableForegroundService();
      if (!foregroundDisabled) {
        return;
      }
      emit(
        state.copyWith(
          backgroundMessagingPhase:
              NotificationBackgroundMessagingPhase.persistingPreference,
          foregroundActivationDeferredUntilRestart: false,
        ),
      );
      await _persistBackgroundMessagingPreference(
        false,
        accountJid: _pendingBackgroundMessagingAccountJid,
      );
    } finally {
      _pendingBackgroundMessagingAccountJid = null;
      emit(
        state.copyWith(
          backgroundMessagingPhase: NotificationBackgroundMessagingPhase.idle,
        ),
      );
    }
  }

  Future<void> _requestPermissionsAndEnable() async {
    _beginPermissionDetachAllowance();
    emit(
      state.copyWith(
        backgroundMessagingPhase:
            NotificationBackgroundMessagingPhase.requestingPermissions,
      ),
    );
    var keepPermissionDetachAllowance = false;
    try {
      final permissionResult = await requestPermissions();
      keepPermissionDetachAllowance = await _handlePermissionResult(
        permissionResult,
      );
    } finally {
      if (!keepPermissionDetachAllowance) {
        _endPermissionDetachAllowance();
      }
    }
  }

  Future<void> _resumePendingBackgroundMessagingEnable() async {
    final awaitedPermissionResult =
        state.backgroundMessagingPhase.awaitedPermissionResult;
    if (awaitedPermissionResult != null) {
      await _resumeSettingsPermissionRequest(awaitedPermissionResult);
      return;
    }
    if (state.backgroundMessagingPhase !=
        NotificationBackgroundMessagingPhase.awaitingPermissionGrantResume) {
      return;
    }
    await _activateForegroundAndPersist();
  }

  Future<void> _handleLifecycleResume() async {
    await refreshPermissions();
    final awaitedPermissionResult =
        state.backgroundMessagingPhase.awaitedPermissionResult;
    if (awaitedPermissionResult != null) {
      await _resumeSettingsPermissionRequest(awaitedPermissionResult);
      return;
    }
    if (state.backgroundMessagingPhase !=
        NotificationBackgroundMessagingPhase.awaitingPermissionGrantResume) {
      return;
    }
    if (state.hasPermissions != true) {
      _clearPendingBackgroundMessagingEnable();
      return;
    }
    await _activateForegroundAndPersist();
  }

  Future<void> _resumeSettingsPermissionRequest(
    NotificationPermissionRequestResult awaitedPermissionResult,
  ) async {
    emit(
      state.copyWith(
        backgroundMessagingPhase:
            NotificationBackgroundMessagingPhase.requestingPermissions,
      ),
    );
    final resolved = await hasPermissionResolvedFor(awaitedPermissionResult);
    if (!resolved) {
      _pendingBackgroundMessagingAccountJid = null;
      _endPermissionDetachAllowance();
      emit(
        state.copyWith(
          backgroundMessagingPhase: NotificationBackgroundMessagingPhase.idle,
        ),
      );
      return;
    }
    await _requestPermissionsAndEnable();
  }

  Future<bool> _handlePermissionResult(
    NotificationPermissionRequestResult permissionResult,
  ) async {
    switch (permissionResult) {
      case NotificationPermissionRequestResult.granted:
        if (!_lifecycleReadyForForegroundActivation) {
          emit(
            state.copyWith(
              backgroundMessagingPhase: NotificationBackgroundMessagingPhase
                  .awaitingPermissionGrantResume,
            ),
          );
          return true;
        }
        await _activateForegroundAndPersist();
        return false;
      case NotificationPermissionRequestResult.awaitingNotificationSettings:
        emit(
          state.copyWith(
            backgroundMessagingPhase: NotificationBackgroundMessagingPhase
                .awaitingNotificationSettingsResume,
          ),
        );
        return true;
      case NotificationPermissionRequestResult
          .awaitingBatteryOptimizationSettings:
        emit(
          state.copyWith(
            backgroundMessagingPhase: NotificationBackgroundMessagingPhase
                .awaitingBatteryOptimizationSettingsResume,
          ),
        );
        return true;
      case NotificationPermissionRequestResult.denied:
        _pendingBackgroundMessagingAccountJid = null;
        emit(
          state.copyWith(
            backgroundMessagingPhase: NotificationBackgroundMessagingPhase.idle,
          ),
        );
        return false;
    }
  }

  Future<void> _activateForegroundAndPersist() async {
    try {
      emit(
        state.copyWith(
          backgroundMessagingPhase:
              NotificationBackgroundMessagingPhase.activatingForeground,
          foregroundActivationDeferredUntilRestart: false,
        ),
      );
      final foregroundResult = await enableForegroundService(
        allowCurrentSessionMigration: true,
      );
      if (!foregroundResult.shouldPersistPreference) {
        return;
      }
      final deferredUntilRestart =
          foregroundResult == ForegroundActivationResult.deferredUntilRestart;
      emit(
        state.copyWith(
          backgroundMessagingPhase:
              NotificationBackgroundMessagingPhase.persistingPreference,
          foregroundActivationDeferredUntilRestart: deferredUntilRestart,
        ),
      );
      await _persistBackgroundMessagingPreference(
        true,
        accountJid: _pendingBackgroundMessagingAccountJid,
      );
      if (deferredUntilRestart) {
        emit(
          state.copyWith(
            restartPromptRequestId: state.restartPromptRequestId + 1,
          ),
        );
      }
    } finally {
      _pendingBackgroundMessagingAccountJid = null;
      _endPermissionDetachAllowance();
      emit(
        state.copyWith(
          backgroundMessagingPhase: NotificationBackgroundMessagingPhase.idle,
        ),
      );
    }
  }

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

  bool get _permissionDetachAllowanceActive {
    final expiresAt = _permissionDetachAllowanceExpiresAt;
    return expiresAt != null && DateTime.now().isBefore(expiresAt);
  }

  bool get _lifecycleReadyForForegroundActivation {
    final lifecycleState = _lifecycleStateProvider();
    return lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed;
  }

  void _beginPermissionDetachAllowance() {
    _permissionDetachAllowanceExpiresAt = DateTime.now().add(
      const Duration(minutes: 5),
    );
    _permissionDetachAllowanceCount = 1;
  }

  void _endPermissionDetachAllowance() {
    _permissionDetachAllowanceExpiresAt = null;
    _permissionDetachAllowanceCount = 0;
  }

  void _clearPendingBackgroundMessagingEnable() {
    if (state.backgroundMessagingPhase !=
            NotificationBackgroundMessagingPhase
                .awaitingPermissionGrantResume &&
        state.backgroundMessagingPhase.awaitedPermissionResult == null) {
      return;
    }
    _pendingBackgroundMessagingAccountJid = null;
    _endPermissionDetachAllowance();
    emit(
      state.copyWith(
        backgroundMessagingPhase: NotificationBackgroundMessagingPhase.idle,
      ),
    );
  }

  @override
  Future<void> close() async {
    foregroundServiceActive.removeListener(_handleForegroundServiceChanged);
    final requestPermissionsFuture = _requestPermissionsFuture;
    final operations = <CancelableOperation<Object?>?>[
      _refreshPermissionsOperation,
      _enableForegroundOperation,
      _disableForegroundOperation,
      _backgroundMessagingOperation,
    ];
    try {
      await Future.wait([
        ...operations.whereType<CancelableOperation<Object?>>().map(
          (operation) => operation.valueOrCancellation(),
        ),
        ?requestPermissionsFuture,
      ]);
    } finally {
      _refreshPermissionsOperation = null;
      _requestPermissionsFuture = null;
      _enableForegroundOperation = null;
      _disableForegroundOperation = null;
      _backgroundMessagingOperation = null;
      _endPermissionDetachAllowance();
      await super.close();
    }
  }
}
