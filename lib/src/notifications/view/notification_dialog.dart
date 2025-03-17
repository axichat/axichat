import 'package:chat/src/notifications/bloc/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<bool?> showNotificationDialog(BuildContext context, NotificationService notificationService) =>
    showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text('Enable message notifications'),
        content: const Text('Chats can always be muted later.'),
        actions: [
          ShadButton.destructive(
            onPressed: () => context.pop(false),
            text: const Text('Ignore'),
          ),
          ShadButton(
            onPressed: () async {
              if (await notificationService.requestAllNotificationPermissions() &&
                  context.mounted) {
                context.pop(true);
              }
            },
            text: const Text('Continue'),
          )
        ],
      ),
    );
