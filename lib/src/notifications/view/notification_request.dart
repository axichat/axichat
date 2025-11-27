import 'package:axichat/main.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class NotificationRequest extends StatefulWidget {
  const NotificationRequest({
    super.key,
    required this.notificationService,
    required this.capability,
  });

  final NotificationService notificationService;
  final Capability capability;

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
                !widget.capability.canForegroundService) {
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
                await widget.notificationService
                    .requestAllNotificationPermissions();
                setState(() {
                  _future = widget.notificationService
                      .hasAllNotificationPermissions();
                });
              },
            );
          },
        );
      },
    );
  }
}
