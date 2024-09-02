import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart'
    hide NotificationPermission;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

extension on NotificationPermission {
  bool get isGranted => this == NotificationPermission.granted;
}

Future<bool> hasNotificationPermission() =>
    AwesomeNotifications().isNotificationAllowed();

Future<bool> hasAllNotificationPermissions() async {
  if (!(await FlutterForegroundTask.checkNotificationPermission()).isGranted) {
    return false;
  }

  if (Platform.isAndroid) {
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      return false;
    }

    if (!await FlutterForegroundTask.canDrawOverlays) {
      return false;
    }
  }

  return true;
}

Future<bool> requestAllNotificationPermissions() async {
  if (!(await FlutterForegroundTask.checkNotificationPermission()).isGranted) {
    if (!(await FlutterForegroundTask.requestNotificationPermission())
        .isGranted) {
      return false;
    }
  }

  if (Platform.isAndroid) {
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      if (!await FlutterForegroundTask.requestIgnoreBatteryOptimization()) {
        return false;
      }
    }

    if (!await FlutterForegroundTask.canDrawOverlays) {
      if (!await FlutterForegroundTask.openSystemAlertWindowSettings()) {
        return false;
      }
    }
  }

  return true;
}
