// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/notifications/bloc/notification_request_cubit.dart';
import 'package:axichat/src/notifications/view/notification_dialog.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
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

class NotificationRequest extends StatelessWidget {
  const NotificationRequest({
    super.key,
    this.displayMode = NotificationRequestDisplayMode.platformOnly,
  });

  final NotificationRequestDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    return _NotificationRequestBody(
      capability: context.watch<Capability>(),
      displayMode: displayMode,
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

class _NotificationRequestBodyState extends State<_NotificationRequestBody> {
  bool _backgroundMessagingActionInProgress = false;

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
        final String? statusSublabel;
        if (state.backgroundMessagingPhase ==
                NotificationBackgroundMessagingPhase.activatingForeground ||
            state.backgroundMessagingPhase ==
                NotificationBackgroundMessagingPhase.disablingForeground) {
          statusSublabel = null;
        } else if (!backgroundMessagingEnabled) {
          statusSublabel = l10n.notificationsRequiresRestart;
        } else if (state.hasPermissions != true) {
          statusSublabel = null;
        } else if (state.foregroundActivationDeferredUntilRestart &&
            !state.foregroundServiceActive) {
          statusSublabel = l10n.notificationsRestartTitle;
        } else {
          statusSublabel = null;
        }
        final canToggle =
            !state.isBusy && !_backgroundMessagingActionInProgress;
        return ShadSwitch(
          enabled: canToggle,
          label: Text(l10n.notificationsMessageToggle),
          sublabel: statusSublabel == null ? null : Text(statusSublabel),
          value: backgroundMessagingEnabled,
          onChanged: canToggle
              ? (enabled) {
                  unawaited(
                    _handleBackgroundMessagingChanged(
                      enabled,
                      state.hasPermissions == true,
                    ),
                  );
                }
              : null,
        );
      },
    );
  }

  Future<void> _handleBackgroundMessagingChanged(
    bool enabled,
    bool alreadyHasPermissions,
  ) async {
    if (_backgroundMessagingActionInProgress) {
      return;
    }
    setState(() {
      _backgroundMessagingActionInProgress = true;
    });
    final notificationCubit = context.read<NotificationRequestCubit>();
    final settingsCubit = context.read<SettingsCubit>();
    final authenticationCubit = context.read<AuthenticationCubit>();
    var result = NotificationBackgroundMessagingResult.unchanged;
    var preferencePersisted = false;
    try {
      if (enabled) {
        if (!alreadyHasPermissions) {
          authenticationCubit.beginNotificationPermissionDetachAllowance();
        }
        try {
          result = await notificationCubit.enableBackgroundMessaging();
        } finally {
          if (!alreadyHasPermissions) {
            authenticationCubit.endNotificationPermissionDetachAllowance();
          }
        }
      } else {
        authenticationCubit.endNotificationPermissionDetachAllowance();
        result = await notificationCubit.disableBackgroundMessaging();
      }
      final preferenceEnabled = result.preferenceEnabled;
      if (preferenceEnabled != null) {
        await settingsCubit.toggleBackgroundMessaging(preferenceEnabled);
        preferencePersisted = true;
        notificationCubit.clearBackgroundMessagingPreferencePersistence();
        if (result.requiresRestartPrompt && mounted) {
          unawaited(showNotificationRestartDialog(context));
        }
      }
    } finally {
      if (result.shouldPersistPreference && !preferencePersisted) {
        notificationCubit.clearBackgroundMessagingPreferencePersistence();
      }
      if (mounted) {
        setState(() {
          _backgroundMessagingActionInProgress = false;
        });
      }
    }
  }
}
