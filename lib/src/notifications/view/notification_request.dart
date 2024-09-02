import 'package:chat/src/app.dart';
import 'package:chat/src/notifications/bloc/notification_permissions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class NotificationRequest extends StatelessWidget {
  const NotificationRequest({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: hasAllNotificationPermissions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.requireData) {
          return const SizedBox.shrink();
        }
        return ListTile(
          title: const Text('Message notifications'),
          titleAlignment: ListTileTitleAlignment.top,
          titleTextStyle: context.textTheme.small,
          subtitle: const Text('Missing some permissions'),
          subtitleTextStyle: context.textTheme.muted,
          trailing: const ShadButton.ghost(
            text: Text('Enable'),
            onPressed: requestAllNotificationPermissions,
          ),
        );
      },
    );
  }
}
