import 'package:chat/src/app.dart';
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
      future: widget.notificationService.hasAllNotificationPermissions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.requireData) {
          return const SizedBox.shrink();
        }
        return ListTile(
          title: const Text('Missing some permissions'),
          titleAlignment: ListTileTitleAlignment.top,
          titleTextStyle: context.textTheme.small,
          subtitle: const Text('App may misbehave'),
          subtitleTextStyle: context.textTheme.muted,
          trailing: ShadButton.ghost(
            text: const Text('Enable'),
            onPressed: () async {
              await widget.notificationService
                  .requestAllNotificationPermissions();
              setState(() {});
            },
          ),
        );
      },
    );
  }
}
