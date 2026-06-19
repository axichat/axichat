// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/foreground_runtime_controller.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/notifications/bloc/notification_request_cubit.dart';
import 'package:axichat/src/notifications/view/notification_dialog.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum NotificationRequestDisplayMode {
  platformOnly,
  always;

  bool shouldShowFor(Capability capability) {
    switch (this) {
      case NotificationRequestDisplayMode.platformOnly:
        return capability.canForegroundService;
      case NotificationRequestDisplayMode.always:
        return true;
    }
  }
}

enum _BackgroundMessagingTogglePhase {
  idle,
  requestingPermissions,
  awaitingNotificationSettingsResume,
  awaitingBatteryOptimizationSettingsResume,
  activatingForeground,
  disablingForeground,
  persistingPreference;

  bool get isBusy => this != _BackgroundMessagingTogglePhase.idle;

  NotificationPermissionRequestResult? get awaitedPermissionResult {
    switch (this) {
      case _BackgroundMessagingTogglePhase.awaitingNotificationSettingsResume:
        return NotificationPermissionRequestResult.awaitingNotificationSettings;
      case _BackgroundMessagingTogglePhase
          .awaitingBatteryOptimizationSettingsResume:
        return NotificationPermissionRequestResult
            .awaitingBatteryOptimizationSettings;
      case _BackgroundMessagingTogglePhase.idle:
      case _BackgroundMessagingTogglePhase.requestingPermissions:
      case _BackgroundMessagingTogglePhase.activatingForeground:
      case _BackgroundMessagingTogglePhase.disablingForeground:
      case _BackgroundMessagingTogglePhase.persistingPreference:
        return null;
    }
  }
}

class NotificationRequest extends StatelessWidget {
  const NotificationRequest({
    super.key,
    this.displayMode = NotificationRequestDisplayMode.platformOnly,
  });

  final NotificationRequestDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationRequestCubit(
        foregroundRuntimeController: context
            .read<ForegroundRuntimeController>(),
        notificationService: context.read<NotificationService>(),
      )..refreshPermissions(),
      child: _NotificationRequestBody(
        capability: context.watch<Capability>(),
        displayMode: displayMode,
      ),
    );
  }
}

class _NotificationRequestBody extends StatefulWidget {
  const _NotificationRequestBody({
    required this.capability,
    required this.displayMode,
  });

  final Capability capability;
  final NotificationRequestDisplayMode displayMode;

  @override
  State<_NotificationRequestBody> createState() =>
      _NotificationRequestBodyState();
}

class _NotificationRequestBodyState extends State<_NotificationRequestBody>
    with WidgetsBindingObserver {
  _BackgroundMessagingTogglePhase _togglePhase =
      _BackgroundMessagingTogglePhase.idle;
  bool _foregroundActivationDeferredUntilRestart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final awaitedPermissionResult = _togglePhase.awaitedPermissionResult;
    if (state != AppLifecycleState.resumed || awaitedPermissionResult == null) {
      return;
    }
    unawaited(_resumeBackgroundMessagingEnable(awaitedPermissionResult));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final backgroundMessagingEnabled = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.backgroundMessagingEnabled,
    );
    return BlocBuilder<NotificationRequestCubit, NotificationRequestState>(
      builder: (context, state) {
        if (state.hasPermissions == null ||
            !widget.displayMode.shouldShowFor(widget.capability)) {
          return const SizedBox.shrink();
        }
        final switchBusy = state.isBusy || _togglePhase.isBusy;
        final String? statusSublabel;
        if (_togglePhase ==
                _BackgroundMessagingTogglePhase.activatingForeground ||
            _togglePhase ==
                _BackgroundMessagingTogglePhase.disablingForeground) {
          statusSublabel = null;
        } else if (!backgroundMessagingEnabled) {
          statusSublabel = l10n.notificationsRequiresRestart;
        } else if (state.hasPermissions != true) {
          statusSublabel = null;
        } else if (_foregroundActivationDeferredUntilRestart &&
            !state.foregroundServiceActive) {
          statusSublabel = l10n.notificationsRestartTitle;
        } else {
          statusSublabel = null;
        }
        return ShadSwitch(
          enabled: !switchBusy,
          label: Text(l10n.notificationsMessageToggle),
          sublabel: statusSublabel == null ? null : Text(statusSublabel),
          value: backgroundMessagingEnabled,
          onChanged: switchBusy
              ? null
              : (enabled) =>
                    _handleBackgroundMessagingChanged(context, enabled),
        );
      },
    );
  }

  Future<void> _handleBackgroundMessagingChanged(
    BuildContext context,
    bool enabled,
  ) async {
    if (_togglePhase.isBusy) {
      return;
    }
    if (enabled) {
      await _enableBackgroundMessaging(context);
      return;
    }
    await _disableBackgroundMessaging(context);
  }

  Future<void> _disableBackgroundMessaging(BuildContext context) async {
    final locate = context.read;
    final notificationCubit = locate<NotificationRequestCubit>();
    final settingsCubit = locate<SettingsCubit>();
    final xmppService = locate<XmppService>();
    setState(() {
      _togglePhase = _BackgroundMessagingTogglePhase.disablingForeground;
    });
    try {
      final foregroundDisabled = await notificationCubit
          .disableForegroundService();
      if (!context.mounted || !foregroundDisabled) {
        return;
      }
      setState(() {
        _togglePhase = _BackgroundMessagingTogglePhase.persistingPreference;
        _foregroundActivationDeferredUntilRestart = false;
      });
      await settingsCubit.toggleBackgroundMessaging(
        false,
        accountJid: xmppService.myJid,
      );
    } finally {
      if (mounted) {
        setState(() {
          _togglePhase = _BackgroundMessagingTogglePhase.idle;
        });
      }
    }
  }

  Future<void> _enableBackgroundMessaging(BuildContext context) async {
    final notificationCubit = context.read<NotificationRequestCubit>();
    if (notificationCubit.state.hasPermissions == true) {
      await _activateForegroundAndPersist(context);
      return;
    }
    await _requestPermissionsAndEnable(context);
  }

  Future<void> _requestPermissionsAndEnable(BuildContext context) async {
    final notificationCubit = context.read<NotificationRequestCubit>();
    setState(() {
      _togglePhase = _BackgroundMessagingTogglePhase.requestingPermissions;
    });
    final permissionResult = await notificationCubit.requestPermissions();
    if (!context.mounted) {
      return;
    }
    await _handlePermissionResult(context, permissionResult);
  }

  Future<void> _resumeBackgroundMessagingEnable(
    NotificationPermissionRequestResult awaitedPermissionResult,
  ) async {
    final notificationCubit = context.read<NotificationRequestCubit>();
    setState(() {
      _togglePhase = _BackgroundMessagingTogglePhase.requestingPermissions;
    });
    final resolved = await notificationCubit.hasPermissionResolvedFor(
      awaitedPermissionResult,
    );
    if (!mounted) {
      return;
    }
    if (!resolved) {
      setState(() {
        _togglePhase = _BackgroundMessagingTogglePhase.idle;
      });
      return;
    }
    await _requestPermissionsAndEnable(context);
  }

  Future<void> _handlePermissionResult(
    BuildContext context,
    NotificationPermissionRequestResult permissionResult,
  ) async {
    switch (permissionResult) {
      case NotificationPermissionRequestResult.granted:
        await _activateForegroundAndPersist(context);
        return;
      case NotificationPermissionRequestResult.awaitingNotificationSettings:
        setState(() {
          _togglePhase = _BackgroundMessagingTogglePhase
              .awaitingNotificationSettingsResume;
        });
        return;
      case NotificationPermissionRequestResult
          .awaitingBatteryOptimizationSettings:
        setState(() {
          _togglePhase = _BackgroundMessagingTogglePhase
              .awaitingBatteryOptimizationSettingsResume;
        });
        return;
      case NotificationPermissionRequestResult.denied:
        setState(() {
          _togglePhase = _BackgroundMessagingTogglePhase.idle;
        });
        return;
    }
  }

  Future<void> _activateForegroundAndPersist(BuildContext context) async {
    final locate = context.read;
    final notificationCubit = locate<NotificationRequestCubit>();
    final settingsCubit = locate<SettingsCubit>();
    final xmppService = locate<XmppService>();
    try {
      setState(() {
        _togglePhase = _BackgroundMessagingTogglePhase.activatingForeground;
        _foregroundActivationDeferredUntilRestart = false;
      });
      final foregroundResult = await notificationCubit.enableForegroundService(
        allowCurrentSessionMigration: true,
      );
      if (!context.mounted || !foregroundResult.shouldPersistPreference) {
        return;
      }
      setState(() {
        _togglePhase = _BackgroundMessagingTogglePhase.persistingPreference;
        _foregroundActivationDeferredUntilRestart =
            foregroundResult == ForegroundActivationResult.deferredUntilRestart;
      });
      await settingsCubit.toggleBackgroundMessaging(
        true,
        accountJid: xmppService.myJid,
      );
      if (!context.mounted) {
        return;
      }
      switch (foregroundResult) {
        case ForegroundActivationResult.active:
        case ForegroundActivationResult.unavailable:
        case ForegroundActivationResult.failed:
          return;
        case ForegroundActivationResult.deferredUntilRestart:
          await showNotificationRestartDialog(context);
          return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _togglePhase = _BackgroundMessagingTogglePhase.idle;
        });
      }
    }
  }
}
