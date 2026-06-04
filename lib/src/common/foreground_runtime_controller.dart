// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/main.dart';
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
  }) : _capability = capability,
       _notificationService = notificationService,
       _xmppService = xmppService,
       _emailService = emailService,
       _foregroundBridge = foregroundBridge;

  final Capability _capability;
  final NotificationService _notificationService;
  final XmppService _xmppService;
  final EmailService _emailService;
  final ForegroundTaskBridge? _foregroundBridge;
  final Logger _log = Logger('ForegroundRuntimeController');

  ForegroundTaskBridge get _bridge => _foregroundBridge ?? foregroundTaskBridge;

  bool get isActive => foregroundServiceActive.value;

  Future<void> prepareForNextXmppConnection({
    required bool desired,
    bool emailKeepaliveEnabled = true,
  }) async {
    if (!desired ||
        !_capability.canForegroundService ||
        !await _notificationService.hasAllNotificationPermissions()) {
      _setForegroundIntent(false);
      await _setEmailKeepaliveStopped();
      await refreshActualState(fallback: foregroundServiceActive.value);
      return;
    }
    _setForegroundIntent(true);
    if (!emailKeepaliveEnabled) {
      await _setEmailKeepaliveStopped();
    }
  }

  Future<bool> restoreIfPreferred({
    required bool desired,
    bool emailKeepaliveEnabled = true,
  }) async {
    if (!desired) {
      return disableForUserToggle();
    }
    final result = await _activateForegroundRuntime(
      emailKeepaliveEnabled: emailKeepaliveEnabled,
      allowCurrentSessionMigration: false,
    );
    return result == ForegroundActivationResult.active;
  }

  Future<ForegroundActivationResult> enableForUserToggle({
    bool emailKeepaliveEnabled = true,
    bool allowCurrentSessionMigration = false,
  }) => _activateForegroundRuntime(
    emailKeepaliveEnabled: emailKeepaliveEnabled,
    allowCurrentSessionMigration: allowCurrentSessionMigration,
  );

  Future<ForegroundActivationResult> _activateForegroundRuntime({
    required bool emailKeepaliveEnabled,
    required bool allowCurrentSessionMigration,
  }) async {
    if (!_capability.canForegroundService) {
      await disableForUserToggle();
      return ForegroundActivationResult.unavailable;
    }
    if (!await _notificationService.hasAllNotificationPermissions()) {
      await disableForUserToggle();
      return ForegroundActivationResult.unavailable;
    }
    if (_xmppService.connected &&
        !_xmppService.usingForegroundSocket &&
        !allowCurrentSessionMigration) {
      _setForegroundIntent(false);
      return ForegroundActivationResult.deferredUntilRestart;
    }
    _setForegroundIntent(true);
    initForegroundService();
    if (await refreshActualState(fallback: foregroundServiceActive.value)) {
      return await _refreshActiveRuntime(
            emailKeepaliveEnabled: emailKeepaliveEnabled,
            allowCurrentSessionMigration: allowCurrentSessionMigration,
          )
          ? ForegroundActivationResult.active
          : ForegroundActivationResult.failed;
    }

    try {
      if (!_xmppService.connected) {
        await _setEmailKeepaliveForRuntime(emailKeepaliveEnabled);
        return await _isRuntimeReadyForCurrentTransport(
              allowPendingSocketStart: true,
            )
            ? ForegroundActivationResult.active
            : ForegroundActivationResult.failed;
      }
      await _xmppService.ensureForegroundSocketIfActive();
      await _setEmailKeepaliveForRuntime(emailKeepaliveEnabled);
      if (await _isRuntimeReadyForCurrentTransport()) {
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
    required bool emailKeepaliveEnabled,
    required bool allowCurrentSessionMigration,
  }) async {
    try {
      if (!_xmppService.connected ||
          _xmppService.usingForegroundSocket ||
          allowCurrentSessionMigration) {
        await _xmppService.ensureForegroundSocketIfActive();
      }
      await _setEmailKeepaliveForRuntime(emailKeepaliveEnabled);
      if (await _isRuntimeReadyForCurrentTransport(
        allowPendingSocketStart: !_xmppService.connected,
      )) {
        return true;
      }
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to refresh foreground runtime.', error, stackTrace);
    }
    await _reconcileFailedStart();
    return false;
  }

  Future<bool> _isRuntimeReadyForCurrentTransport({
    bool allowPendingSocketStart = false,
  }) async {
    final running = await refreshActualState(
      fallback: foregroundServiceActive.value,
    );
    if (!_xmppService.connected) {
      return allowPendingSocketStart || running;
    }
    return running && _xmppService.usingForegroundSocket;
  }

  Future<void> _reconcileFailedStart() async {
    try {
      await _emailService.setForegroundKeepalive(false);
    } on Exception catch (error, stackTrace) {
      _log.finer(
        'Failed to roll back email foreground keepalive.',
        error,
        stackTrace,
      );
    }
    try {
      await _xmppService.disableForegroundSocketIfActive();
    } on Exception catch (error, stackTrace) {
      _log.finer(
        'Failed to roll back XMPP foreground socket.',
        error,
        stackTrace,
      );
    }
    await refreshActualState(fallback: foregroundServiceActive.value);
    _setForegroundIntent(false);
  }

  Future<void> _setEmailKeepaliveForRuntime(bool enabled) async {
    await _emailService.setForegroundKeepalive(enabled);
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
