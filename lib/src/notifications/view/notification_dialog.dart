import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<bool?> showNotificationDialog(
        BuildContext context, NotificationService notificationService) =>
    showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog(
        title: Text(context.l10n.notificationsDialogTitle),
        actions: [
          ShadButton.destructive(
            onPressed: () => context.pop(false),
            child: Text(context.l10n.notificationsDialogIgnore),
          ).withTapBounce(),
          ShadButton(
            onPressed: () async {
              if (await notificationService
                      .requestAllNotificationPermissions() &&
                  context.mounted) {
                context.pop(true);
              }
            },
            child: Text(context.l10n.notificationsDialogContinue),
          ).withTapBounce(),
        ],
        child: Text(context.l10n.notificationsDialogDescription),
      ),
    );
