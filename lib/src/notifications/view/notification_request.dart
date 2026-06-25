// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

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

class _NotificationRequestBody extends StatelessWidget {
  const _NotificationRequestBody({
    required this.capability,
    required this.displayMode,
  });

  final Capability capability;
  final NotificationRequestDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final backgroundMessagingEnabled = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.backgroundMessagingEnabled,
    );
    return BlocListener<NotificationRequestCubit, NotificationRequestState>(
      listenWhen: (previous, current) =>
          previous.restartPromptRequestId != current.restartPromptRequestId &&
          current.restartPromptRequestId > 0,
      listener: (context, state) {
        unawaited(showNotificationRestartDialog(context));
      },
      child: BlocBuilder<NotificationRequestCubit, NotificationRequestState>(
        builder: (context, state) {
          if (state.hasPermissions == null ||
              !displayMode.shouldShowFor(capability)) {
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
          return ShadSwitch(
            enabled: !state.isBusy,
            label: Text(l10n.notificationsMessageToggle),
            sublabel: statusSublabel == null ? null : Text(statusSublabel),
            value: backgroundMessagingEnabled,
            onChanged: state.isBusy
                ? null
                : (enabled) {
                    final notificationCubit = context
                        .read<NotificationRequestCubit>();
                    if (enabled) {
                      unawaited(notificationCubit.enableBackgroundMessaging());
                      return;
                    }
                    unawaited(notificationCubit.disableBackgroundMessaging());
                  },
          );
        },
      ),
    );
  }
}
