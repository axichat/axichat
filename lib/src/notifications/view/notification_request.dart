// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
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
        notificationService: context.read<NotificationService>(),
        xmppService: context.read<XmppService>(),
      )..refreshPermissions(),
      child: _NotificationRequestBody(
        capability: context.watch<Capability>(),
        displayMode: displayMode,
      ),
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
    return BlocBuilder<NotificationRequestCubit, NotificationRequestState>(
      builder: (context, state) {
        final locate = context.read;
        if (state.hasPermissions == null ||
            state.foregroundServiceActive ||
            !displayMode.shouldShowFor(capability)) {
          return const SizedBox.shrink();
        }

        return ShadSwitch(
          label: Text(l10n.notificationsMessageToggle),
          sublabel: Text(
            state.hasPermissions == true
                ? l10n.notificationsRestartSubtitle
                : l10n.notificationsRequiresRestart,
          ),
          value: state.foregroundServiceActive,
          onChanged: state.isBusy
              ? null
              : (enabled) async {
                  if (!enabled) {
                    return;
                  }
                  if (state.hasPermissions == true) {
                    final foregroundEnabled =
                        await locate<NotificationRequestCubit>()
                            .enableForegroundService();
                    if (!context.mounted || !foregroundEnabled) {
                      return;
                    }
                    context.read<SettingsCubit>().toggleBackgroundMessaging(
                      true,
                    );
                    return;
                  }
                  final confirmed = await showNotificationDialog(
                    context,
                    locate,
                  );
                  if (!context.mounted || confirmed != true) {
                    return;
                  }
                  if (!displayMode.shouldShowFor(capability)) {
                    return;
                  }
                  if (!capability.canForegroundService) {
                    return;
                  }
                  if (!context.mounted) {
                    return;
                  }
                  final foregroundEnabled =
                      await locate<NotificationRequestCubit>()
                          .enableForegroundService();
                  if (!context.mounted || !foregroundEnabled) {
                    return;
                  }
                  context.read<SettingsCubit>().toggleBackgroundMessaging(true);
                },
        );
      },
    );
  }
}
