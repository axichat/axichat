import 'dart:async';
import 'dart:math';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:chat/src/notifications/bloc/notification_permissions.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

Future<void> sendNotification(
    {String? title,
    String? body,
    String? groupKey,
    List<FutureOr<bool>> extraConditions = const []}) async {
  if (!await FlutterForegroundTask.isAppOnForeground &&
      await hasNotificationPermission()) {
    for (final condition in extraConditions) {
      if (!await condition) return;
    }
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: Random(DateTime.now().millisecondsSinceEpoch).nextInt(10000),
        channelKey: 'basic_channel',
        groupKey: groupKey,
        actionType: ActionType.Default,
        title: title,
        body: body,
      ),
    );
  }
}
