// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/main.dart';
import 'package:axichat/src/common/background_messaging_platform.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/xmpp/connection/foreground_socket.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:logging/logging.dart';

enum ForegroundActivationResult {
  active,
  deferredUntilRestart,
  unavailable,
  failed;

  bool get shouldPersistPreference {
    switch (this) {
      case ForegroundActivationResult.active:
      case ForegroundActivationResult.deferredUntilRestart:
        return true;
      case ForegroundActivationResult.unavailable:
      case ForegroundActivationResult.failed:
        return false;
    }
  }
}

class ForegroundRuntimeController {
  ForegroundRuntimeController({
    required Capability capability,
    required NotificationService notificationService,
    required XmppService xmppService,
    required EmailService emailService,
    ForegroundTaskBridge? foregroundBridge,
    BackgroundMessagingPlatform? backgroundMessagingPlatform,
  }) : _capability = capability,
       _notificationService = notificationService,
       _xmppService = xmppService,
       _emailService = emailService,
       _foregroundBridge = foregroundBridge,
       _backgroundMessagingPlatform =
           backgroundMessagingPlatform ?? BackgroundMessagingPlatform();

  final Capability _capability;
  final NotificationService _notificationService;
  final XmppService _xmppService;
  final EmailService _emailService;
  final ForegroundTaskBridge? _foregroundBridge;
  final BackgroundMessagingPlatform _backgroundMessagingPlatform;
  final Logger _log = Logger('ForegroundRuntimeController');

  ForegroundTaskBridge get _bridge => _foregroundBridge ?? foregroundTaskBridge;

  bool get _usesPlatformForegroundService =>
      _capability.usesPlatformForegroundService;

  bool get _usesHiddenWindowBackgroundMessaging =>
      _capability.usesHiddenWindowBackgroundMessaging;

  bool get _usesPermissionOnlyBackgroundMessaging =>
      _capability.canBackgroundMessaging &&
      !_usesPlatformForegroundService &&
      !_usesHiddenWindowBackgroundMessaging;

  bool get isActive => foregroundServiceActive.value;

  Future<void> prepareForNextXmppConnection({required bool desired}) async {
    if (!desired ||
        !_capability.canBackgroundMessaging ||
        !await _notificationService.hasAllNotificationPermissions()) {
      _setForegroundIntent(false);
      if (_usesPlatformForegroundService) {
        await _setEmailKeepaliveStopped();
        await refreshActualState(fallback: foregroundServiceActive.value);
      } else if (_usesHiddenWindowBackgroundMessaging) {
        await _disableNonPlatformRuntime(clearIntent: false);
      } else {
        _setRuntimeActive(false);
      }
      return;
    }
    if (_usesHiddenWindowBackgroundMessaging) {
      await _setBackgroundMessagingRuntime(true);
      _setForegroundIntent(true);
      return;
    }
    if (_usesPermissionOnlyBackgroundMessaging) {
      _setForegroundIntent(false);
      _setRuntimeActive(false);
      return;
    }
    _setForegroundIntent(true);
    await _setEmailKeepaliveStopped();
  }

  Future<bool> restoreIfPreferred({required bool desired}) async {
    if (!desired) {
      return disableForUserToggle();
    }
    final result = await _activateForegroundRuntime(
      allowCurrentSessionMigration: true,
    );
    return result == ForegroundActivationResult.active;
  }

  Future<bool> syncHiddenWindowClosePolicy({required bool desired}) async {
    if (!_usesHiddenWindowBackgroundMessaging) {
      return false;
    }
    await restoreIfPreferred(desired: desired);
    return true;
  }

  Future<ForegroundActivationResult> enableForUserToggle({
    bool allowCurrentSessionMigration = false,
  }) => _activateForegroundRuntime(
    allowCurrentSessionMigration: allowCurrentSessionMigration,
  );

  Future<ForegroundActivationResult> _activateForegroundRuntime({
    required bool allowCurrentSessionMigration,
  }) async {
    if (!_capability.canBackgroundMessaging) {
      await disableForUserToggle();
      return ForegroundActivationResult.unavailable;
    }
    if (!await _notificationService.hasAllNotificationPermissions()) {
      await disableForUserToggle();
      return ForegroundActivationResult.unavailable;
    }
    if (_usesHiddenWindowBackgroundMessaging) {
      return await _activateNonPlatformRuntime()
          ? ForegroundActivationResult.active
          : ForegroundActivationResult.failed;
    }
    if (_usesPermissionOnlyBackgroundMessaging) {
      _setForegroundIntent(false);
      _setRuntimeActive(false);
      return await _notificationService.requestRemoteNotificationsIfAuthorized()
          ? ForegroundActivationResult.active
          : ForegroundActivationResult.failed;
    }
    if (_xmppService.connected &&
        !_xmppService.usingForegroundSocket &&
        !allowCurrentSessionMigration) {
      _setForegroundIntent(false);
      return ForegroundActivationResult.deferredUntilRestart;
    }
    _setForegroundIntent(true);
    initForegroundService();
    if (await refreshActualState(fallback: false)) {
      return await _refreshActiveRuntime(
            allowCurrentSessionMigration: allowCurrentSessionMigration,
          )
          ? ForegroundActivationResult.active
          : ForegroundActivationResult.failed;
    }

    try {
      if (!_xmppService.connected) {
        await _setEmailKeepaliveStopped();
        return await _isRuntimeReadyForCurrentTransport(
              allowPendingSocketStart: true,
            )
            ? ForegroundActivationResult.active
            : ForegroundActivationResult.failed;
      }
      final foregroundSocketActive = await _xmppService
          .ensureForegroundSocketIfActive();
      await _setEmailKeepaliveStopped();
      if (foregroundSocketActive &&
          await _isRuntimeReadyForCurrentTransport(
            requireNotificationSnapshot: true,
          )) {
        return ForegroundActivationResult.active;
      }
      _log.warning(
        'Foreground preference is enabled but runtime did not start.',
      );
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to restore foreground runtime.', error, stackTrace);
    }
    await _reconcileFailedStart();
    return ForegroundActivationResult.failed;
  }

  Future<bool> disableForUserToggle() async {
    if (_usesHiddenWindowBackgroundMessaging) {
      return _disableNonPlatformRuntime();
    }
    if (!_usesPlatformForegroundService) {
      _setForegroundIntent(false);
      _setRuntimeActive(false);
      return true;
    }

    var migrationSucceeded = false;
    var emailKeepaliveStopped = false;
    try {
      migrationSucceeded = await _xmppService.disableForegroundSocketIfActive();
      if (migrationSucceeded) {
        emailKeepaliveStopped = await _setEmailKeepaliveStopped();
      }
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to stop foreground runtime.', error, stackTrace);
    }

    var stillRunning = await refreshActualState(
      fallback: foregroundServiceActive.value,
    );
    if (migrationSucceeded && emailKeepaliveStopped && stillRunning) {
      await _forceStopForegroundService(
        reason: 'foreground runtime disabled by user',
      );
      stillRunning = await refreshActualState(fallback: false);
    }
    final disabled =
        migrationSucceeded && emailKeepaliveStopped && !stillRunning;
    if (disabled) {
      _setForegroundIntent(false);
    }
    return disabled;
  }

  Future<bool> forceStopAfterExplicitSessionEnd() async {
    if (_usesHiddenWindowBackgroundMessaging) {
      return _disableNonPlatformRuntime();
    }
    if (!_usesPlatformForegroundService) {
      _setForegroundIntent(false);
      _setRuntimeActive(false);
      return true;
    }

    var emailKeepaliveStopped = false;
    try {
      emailKeepaliveStopped = await _setEmailKeepaliveStopped();
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to stop email keepalive after explicit session end.',
        error,
        stackTrace,
      );
    }
    var foregroundSocketReleased = false;
    try {
      foregroundSocketReleased = await _xmppService
          .disableForegroundSocketIfActive();
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to release foreground socket after explicit session end.',
        error,
        stackTrace,
      );
    }
    final wasRunning = await _forceStopForegroundService(
      reason: 'explicit session end',
    );
    final stillRunning = await refreshActualState(fallback: false);
    if (!stillRunning) {
      _setForegroundIntent(false);
    }
    return (emailKeepaliveStopped &&
            foregroundSocketReleased &&
            !stillRunning) ||
        (wasRunning && !stillRunning);
  }

  Future<bool> refreshAfterSessionEnd() async {
    final running = await refreshActualState(
      fallback: foregroundServiceActive.value,
    );
    if (!running) {
      _setForegroundIntent(false);
    }
    return running;
  }

  Future<bool> refreshActualState({bool fallback = false}) async {
    if (_usesHiddenWindowBackgroundMessaging) {
      final running =
          _capability.usesHiddenWindowBackgroundMessaging && withForeground;
      final synced = await _setBackgroundMessagingRuntime(running);
      if (!synced) {
        _setRuntimeActive(fallback);
        return fallback;
      }
      return running;
    }
    if (!_usesPlatformForegroundService) {
      _setRuntimeActive(false);
      return false;
    }

    var running = fallback;
    try {
      running = await _bridge.isRunning();
    } on Exception catch (error, stackTrace) {
      _log.finer(
        'Failed to inspect foreground runtime state.',
        error,
        stackTrace,
      );
    }
    _setRuntimeActive(running);
    return running;
  }

  Future<bool> _forceStopForegroundService({required String reason}) async {
    if (_usesHiddenWindowBackgroundMessaging) {
      final stopped = await _setBackgroundMessagingRuntime(false);
      if (stopped) {
        _log.info('Stopped background messaging runtime: reason=$reason');
      }
      return stopped;
    }
    if (!_usesPlatformForegroundService) {
      _setRuntimeActive(false);
      return true;
    }

    try {
      final stopped = await _bridge.stopIfRunning();
      if (stopped) {
        _log.info('Force-stopped foreground service: reason=$reason');
      }
      return stopped;
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to force-stop foreground service: reason=$reason',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<bool> _refreshActiveRuntime({
    required bool allowCurrentSessionMigration,
  }) async {
    if (_usesHiddenWindowBackgroundMessaging) {
      return _activateNonPlatformRuntime();
    }
    if (!_usesPlatformForegroundService) {
      return true;
    }

    try {
      if (_xmppService.connected) {
        if (_xmppService.usingForegroundSocket ||
            allowCurrentSessionMigration) {
          if (await _xmppService.ensureForegroundSocketIfActive()) {
            await _setEmailKeepaliveStopped();
            if (await _isRuntimeReadyForCurrentTransport(
              requireNotificationSnapshot: true,
            )) {
              return true;
            }
          }
        }
      } else {
        await _setEmailKeepaliveStopped();
        if (await _isRuntimeReadyForCurrentTransport(
          allowPendingSocketStart: true,
        )) {
          return true;
        }
      }
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to refresh foreground runtime.', error, stackTrace);
    }
    await _reconcileFailedStart();
    return false;
  }

  Future<bool> _isRuntimeReadyForCurrentTransport({
    bool allowPendingSocketStart = false,
    bool requireNotificationSnapshot = false,
  }) async {
    final running = await refreshActualState(
      fallback: foregroundServiceActive.value,
    );
    if (_usesHiddenWindowBackgroundMessaging) {
      return running;
    }
    if (!_usesPlatformForegroundService) {
      return true;
    }
    if (!_xmppService.connected) {
      return allowPendingSocketStart || running;
    }
    if (!running || !_xmppService.usingForegroundSocket) {
      return false;
    }
    if (!requireNotificationSnapshot) {
      return true;
    }
    return _xmppService.ensureForegroundNotificationSnapshotReady();
  }

  Future<void> _reconcileFailedStart() async {
    if (_usesPlatformForegroundService) {
      try {
        await _emailService.setForegroundKeepalive(false);
      } on Exception catch (error, stackTrace) {
        _log.finer(
          'Failed to roll back email foreground keepalive.',
          error,
          stackTrace,
        );
      }
    }
    try {
      if (_usesPlatformForegroundService) {
        await _xmppService.disableForegroundSocketIfActive();
        await _forceStopForegroundService(
          reason: 'failed foreground runtime start',
        );
      } else if (_usesHiddenWindowBackgroundMessaging) {
        await _setBackgroundMessagingRuntime(false);
      } else {
        _setRuntimeActive(false);
      }
    } on Exception catch (error, stackTrace) {
      _log.finer('Failed to roll back foreground runtime.', error, stackTrace);
    }
    _setForegroundIntent(false);
    await refreshActualState(fallback: false);
  }

  Future<bool> _activateNonPlatformRuntime() async {
    _setForegroundIntent(true);
    final runtimeEnabled = await _setBackgroundMessagingRuntime(true);
    if (runtimeEnabled) {
      return true;
    }
    await _reconcileFailedStart();
    return false;
  }

  Future<bool> _disableNonPlatformRuntime({bool clearIntent = true}) async {
    final runtimeStopped = await _setBackgroundMessagingRuntime(false);
    if (runtimeStopped && clearIntent) {
      _setForegroundIntent(false);
    }
    return runtimeStopped;
  }

  Future<bool> _setBackgroundMessagingRuntime(bool enabled) async {
    try {
      await _backgroundMessagingPlatform.setBackgroundMessagingEnabled(enabled);
      _setRuntimeActive(enabled);
      return true;
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to update background messaging runtime: enabled=$enabled',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<bool> _setEmailKeepaliveStopped() async {
    try {
      await _emailService.setForegroundKeepalive(false);
      return true;
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to stop email foreground keepalive.',
        error,
        stackTrace,
      );
      return false;
    }
  }

  void _setRuntimeActive(bool active) {
    if (foregroundServiceActive.value != active) {
      foregroundServiceActive.value = active;
    }
  }

  void _setForegroundIntent(bool enabled) {
    withForeground = enabled;
  }
}
