// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/main.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/notification_dialog.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
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

class NotificationRequest extends StatefulWidget {
  const NotificationRequest({
    super.key,
    required this.notificationService,
    required this.capability,
    this.displayMode = NotificationRequestDisplayMode.platformOnly,
  });

  final NotificationService notificationService;
  final Capability capability;
  final NotificationRequestDisplayMode displayMode;

  @override
  State<NotificationRequest> createState() => _NotificationRequestState();
}

class _NotificationRequestState extends State<NotificationRequest> {
  late var _future = widget.notificationService.hasAllNotificationPermissions();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder(
      initialData: foregroundServiceActive.value,
      future: _future,
      builder: (context, snapshot) {
        return ValueListenableBuilder<bool>(
          valueListenable: foregroundServiceActive,
          builder: (context, serviceActive, _) {
            if (!snapshot.hasData ||
                serviceActive ||
                !widget.displayMode.shouldShowFor(widget.capability)) {
              return const SizedBox.shrink();
            }

            if (snapshot.requireData) {
              return ShadSwitch(
                enabled: false,
                value: true,
                label: Text(l10n.notificationsRestartTitle),
                sublabel: Text(l10n.notificationsRestartSubtitle),
              );
            }

            return ShadSwitch(
              label: Text(l10n.notificationsMessageToggle),
              sublabel: Text(l10n.notificationsRequiresRestart),
              value: snapshot.requireData,
              onChanged: (enabled) async {
                final confirmed = await showNotificationDialog(
                  context,
                  widget.notificationService,
                );
                if (!context.mounted || confirmed != true) {
                  return;
                }
                if (!widget.displayMode.shouldShowFor(widget.capability)) {
                  return;
                }
                if (!widget.capability.canForegroundService) {
                  return;
                }
                final permissionCheck =
                    widget.notificationService.hasAllNotificationPermissions();
                setState(() {
                  _future = permissionCheck;
                });
                if (!await permissionCheck) {
                  return;
                }
                if (!context.mounted) {
                  return;
                }
                final xmppService = context.read<XmppService>();
                withForeground = true;
                foregroundServiceActive.value = true;
                initForegroundService();
                await xmppService.ensureForegroundSocketIfActive();
              },
            );
          },
        );
      },
    );
  }
}
