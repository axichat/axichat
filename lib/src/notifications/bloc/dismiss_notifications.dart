import 'package:awesome_notifications/awesome_notifications.dart';

Future<void> dismissNotifications({required String groupKey}) =>
    AwesomeNotifications().dismissNotificationsByGroupKey(groupKey);
