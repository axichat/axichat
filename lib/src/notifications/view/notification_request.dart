import 'package:chat/main.dart';
import 'package:chat/src/notifications/bloc/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class NotificationRequest extends StatefulWidget {
  const NotificationRequest({
    super.key,
    required this.notificationService,
  });

  final NotificationService notificationService;

  @override
  State<NotificationRequest> createState() => _NotificationRequestState();
}

class _NotificationRequestState extends State<NotificationRequest> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      initialData: withForeground,
      future: widget.notificationService.hasAllNotificationPermissions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.requireData) {
          return const SizedBox.shrink();
        }

        if (!withForeground && snapshot.requireData) {
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
          onChanged: (enabled) =>
              widget.notificationService.requestAllNotificationPermissions(),
        );
      },
    );
  }
}
