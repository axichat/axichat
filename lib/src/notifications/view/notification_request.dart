import 'package:axichat/main.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
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
    return FutureBuilder(
      initialData: withForeground,
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData || withForeground || !widget.capability.canForegroundService) {
          return const SizedBox.shrink();
        }

        if (snapshot.requireData) {
          return const ShadSwitch(
            enabled: false,
            value: true,
            label: Text('Restart app to enable notifications'),
            sublabel: Text('Required permissions already granted'),
          );
        }

        return ShadSwitch(
          label: const Text('Message notifications'),
          sublabel: const Text('Requires restart'),
          value: snapshot.requireData,
          onChanged: (enabled) async {
            await widget.notificationService
                .requestAllNotificationPermissions();
            setState(() {
              _future =
                  widget.notificationService.hasAllNotificationPermissions();
            });
          },
        );
      },
    );
  }
}
