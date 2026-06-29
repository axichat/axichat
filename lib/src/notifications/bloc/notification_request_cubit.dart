// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:async/async.dart';
import 'package:axichat/main.dart';
import 'package:axichat/src/common/foreground_runtime_controller.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/push/push_registration_coordinator.dart';
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

enum NotificationBackgroundMessagingResult {
  unchanged,
  enabled,
  enabledAfterRestart,
  disabled;

  bool get shouldPersistPreference => preferenceEnabled != null;

  bool? get preferenceEnabled {
    switch (this) {
      case NotificationBackgroundMessagingResult.enabled:
      case NotificationBackgroundMessagingResult.enabledAfterRestart:
        return true;
      case NotificationBackgroundMessagingResult.disabled:
        return false;
      case NotificationBackgroundMessagingResult.unchanged:
        return null;
    }
  }

  bool get requiresRestartPrompt =>
      this == NotificationBackgroundMessagingResult.enabledAfterRestart;
}

class NotificationRequestCubit extends Cubit<NotificationRequestState> {
  NotificationRequestCubit({
    required NotificationService notificationService,
    required ForegroundRuntimeController foregroundRuntimeController,
    PushRegistrationCoordinator? pushRegistrationCoordinator,
    AppLifecycleState? Function()? lifecycleStateProvider,
  }) : _notificationService = notificationService,
       _foregroundRuntimeController = foregroundRuntimeController,
       _pushRegistrationCoordinator = pushRegistrationCoordinator,
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
  final PushRegistrationCoordinator? _pushRegistrationCoordinator;
  final AppLifecycleState? Function() _lifecycleStateProvider;
  CancelableOperation<bool>? _refreshPermissionsOperation;
  Future<NotificationPermissionRequestResult>? _requestPermissionsFuture;
  CancelableOperation<ForegroundActivationResult>? _enableForegroundOperation;
  CancelableOperation<bool>? _disableForegroundOperation;
  CancelableOperation<NotificationBackgroundMessagingResult>?
  _backgroundMessagingOperation;
  Completer<NotificationBackgroundMessagingResult>?
  _pendingBackgroundMessagingEnableCompleter;
  Completer<void> _backgroundMessagingResumeSignal = Completer<void>();

  Future<NotificationBackgroundMessagingResult> enableBackgroundMessaging() {
    return _runBackgroundMessagingOperation(_enableBackgroundMessaging);
  }

  Future<NotificationBackgroundMessagingResult> disableBackgroundMessaging() {
    return _runBackgroundMessagingOperation(_disableBackgroundMessaging);
  }

  Future<void> handleLifecycleResume() {
    return _handleLifecycleResumeAfterActiveOperation();
  }

  void clearBackgroundMessagingPreferencePersistence() {
    if (state.backgroundMessagingPhase !=
        NotificationBackgroundMessagingPhase.persistingPreference) {
      return;
    }
    emit(
      state.copyWith(
        backgroundMessagingPhase: NotificationBackgroundMessagingPhase.idle,
      ),
    );
  }

  Future<void> _handleLifecycleResumeAfterActiveOperation() async {
    _markBackgroundMessagingResumeSignaled();
    if (_pendingBackgroundMessagingEnableCompleter != null) {
      await _completePendingBackgroundMessagingEnableFromResume();
      return;
    }
    final existing = _backgroundMessagingOperation;
    if (existing != null) {
      await existing.valueOrCancellation();
      return;
    }
    await _runBackgroundMessagingOperation(_handleLifecycleResume);
  }

  Future<NotificationBackgroundMessagingResult>
  _runBackgroundMessagingOperation(
    Future<NotificationBackgroundMessagingResult> Function() action,
  ) async {
    final existing = _backgroundMessagingOperation;
    if (existing != null) {
      return await existing.valueOrCancellation() ??
          NotificationBackgroundMessagingResult.unchanged;
    }
    final operation =
        CancelableOperation<NotificationBackgroundMessagingResult>.fromFuture(
          action(),
        );
    _backgroundMessagingOperation = operation;
    try {
      return await operation.valueOrCancellation() ??
          NotificationBackgroundMessagingResult.unchanged;
    } finally {
      if (_backgroundMessagingOperation == operation) {
        _backgroundMessagingOperation = null;
      }
    }
  }

  Future<NotificationBackgroundMessagingResult>
  _enableBackgroundMessaging() async {
    if (state.hasPermissions == true) {
      return _activateForegroundForPreference();
    }
    return _requestPermissionsAndEnable();
  }

  Future<NotificationBackgroundMessagingResult>
  _disableBackgroundMessaging() async {
    var result = NotificationBackgroundMessagingResult.unchanged;
    try {
      emit(
        state.copyWith(
          backgroundMessagingPhase:
              NotificationBackgroundMessagingPhase.disablingForeground,
        ),
      );
      final pushRegistrationDisabled =
          await _pushRegistrationCoordinator
              ?.handleBackgroundMessagingPreferenceChanged(enabled: false) ??
          true;
      if (!pushRegistrationDisabled) {
        return result;
      }
      final foregroundDisabled = await disableForegroundService();
      if (!foregroundDisabled) {
        return result;
      }
      result = NotificationBackgroundMessagingResult.disabled;
      emit(
        state.copyWith(
          backgroundMessagingPhase:
              NotificationBackgroundMessagingPhase.persistingPreference,
          foregroundActivationDeferredUntilRestart: false,
        ),
      );
      return result;
    } finally {
      if (!result.shouldPersistPreference) {
        emit(
          state.copyWith(
            backgroundMessagingPhase: NotificationBackgroundMessagingPhase.idle,
          ),
        );
      }
    }
  }

  Future<NotificationBackgroundMessagingResult>
  _requestPermissionsAndEnable() async {
    _backgroundMessagingResumeSignal = Completer<void>();
    emit(
      state.copyWith(
        backgroundMessagingPhase:
            NotificationBackgroundMessagingPhase.requestingPermissions,
      ),
    );
    final permissionResult = await requestPermissions();
    return _handlePermissionResult(permissionResult);
  }

  Future<NotificationBackgroundMessagingResult> _handleLifecycleResume() async {
    await refreshPermissions();
    final awaitedPermissionResult =
        state.backgroundMessagingPhase.awaitedPermissionResult;
    if (awaitedPermissionResult != null) {
      return _resumeSettingsPermissionRequest(awaitedPermissionResult);
    }
    if (state.backgroundMessagingPhase !=
        NotificationBackgroundMessagingPhase.awaitingPermissionGrantResume) {
      return NotificationBackgroundMessagingResult.unchanged;
    }
    if (state.hasPermissions != true) {
      _clearPendingBackgroundMessagingEnable();
      return NotificationBackgroundMessagingResult.unchanged;
    }
    return _activateForegroundForPreference();
  }

  Future<NotificationBackgroundMessagingResult>
  _resumeSettingsPermissionRequest(
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
      emit(
        state.copyWith(
          backgroundMessagingPhase: NotificationBackgroundMessagingPhase.idle,
        ),
      );
      return NotificationBackgroundMessagingResult.unchanged;
    }
    return _requestPermissionsAndEnable();
  }

  Future<NotificationBackgroundMessagingResult> _handlePermissionResult(
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
          return _waitForPendingBackgroundMessagingEnableResume();
        }
        return _activateForegroundForPreference();
      case NotificationPermissionRequestResult.awaitingNotificationSettings:
        emit(
          state.copyWith(
            backgroundMessagingPhase: NotificationBackgroundMessagingPhase
                .awaitingNotificationSettingsResume,
          ),
        );
        return _waitForPendingBackgroundMessagingEnableResume();
      case NotificationPermissionRequestResult
          .awaitingBatteryOptimizationSettings:
        emit(
          state.copyWith(
            backgroundMessagingPhase: NotificationBackgroundMessagingPhase
                .awaitingBatteryOptimizationSettingsResume,
          ),
        );
        return _waitForPendingBackgroundMessagingEnableResume();
      case NotificationPermissionRequestResult.denied:
        emit(
          state.copyWith(
            backgroundMessagingPhase: NotificationBackgroundMessagingPhase.idle,
          ),
        );
        return NotificationBackgroundMessagingResult.unchanged;
    }
  }

  Future<NotificationBackgroundMessagingResult>
  _activateForegroundForPreference() async {
    var result = NotificationBackgroundMessagingResult.unchanged;
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
        return result;
      }
      result =
          foregroundResult == ForegroundActivationResult.deferredUntilRestart
          ? NotificationBackgroundMessagingResult.enabledAfterRestart
          : NotificationBackgroundMessagingResult.enabled;
      emit(
        state.copyWith(
          backgroundMessagingPhase:
              NotificationBackgroundMessagingPhase.persistingPreference,
          foregroundActivationDeferredUntilRestart:
              result.requiresRestartPrompt,
        ),
      );
      return result;
    } finally {
      if (!result.shouldPersistPreference) {
        emit(
          state.copyWith(
            backgroundMessagingPhase: NotificationBackgroundMessagingPhase.idle,
          ),
        );
      }
    }
  }

  Future<NotificationBackgroundMessagingResult>
  _waitForPendingBackgroundMessagingEnableResume() async {
    final existing = _pendingBackgroundMessagingEnableCompleter;
    if (existing != null) {
      return existing.future;
    }
    final completer = Completer<NotificationBackgroundMessagingResult>();
    _pendingBackgroundMessagingEnableCompleter = completer;
    if (_backgroundMessagingResumeSignal.isCompleted) {
      unawaited(_completePendingBackgroundMessagingEnableFromResume());
    }
    try {
      return await completer.future;
    } finally {
      if (_pendingBackgroundMessagingEnableCompleter == completer) {
        _pendingBackgroundMessagingEnableCompleter = null;
      }
    }
  }

  Future<void> _completePendingBackgroundMessagingEnableFromResume() async {
    final completer = _pendingBackgroundMessagingEnableCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }
    _pendingBackgroundMessagingEnableCompleter = null;
    final resumeFuture = _handleLifecycleResume();
    unawaited(
      resumeFuture.then(
        (result) {
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      ),
    );
    await resumeFuture;
  }

  void _completePendingBackgroundMessagingEnable(
    NotificationBackgroundMessagingResult result,
  ) {
    final completer = _pendingBackgroundMessagingEnableCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }
    _pendingBackgroundMessagingEnableCompleter = null;
    completer.complete(result);
  }

  void _markBackgroundMessagingResumeSignaled() {
    if (_backgroundMessagingResumeSignal.isCompleted) {
      return;
    }
    _backgroundMessagingResumeSignal.complete();
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

  bool get _lifecycleReadyForForegroundActivation {
    final lifecycleState = _lifecycleStateProvider();
    return lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed;
  }

  void _clearPendingBackgroundMessagingEnable() {
    if (state.backgroundMessagingPhase !=
            NotificationBackgroundMessagingPhase
                .awaitingPermissionGrantResume &&
        state.backgroundMessagingPhase.awaitedPermissionResult == null) {
      return;
    }
    emit(
      state.copyWith(
        backgroundMessagingPhase: NotificationBackgroundMessagingPhase.idle,
      ),
    );
  }

  @override
  Future<void> close() async {
    foregroundServiceActive.removeListener(_handleForegroundServiceChanged);
    _completePendingBackgroundMessagingEnable(
      NotificationBackgroundMessagingResult.unchanged,
    );
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
      await super.close();
    }
  }
}
