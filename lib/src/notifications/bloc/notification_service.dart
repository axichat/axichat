import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:awesome_notifications/awesome_notifications.dart'
    hide NotificationPermission;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

extension on NotificationPermission {
  bool get isGranted => this == NotificationPermission.granted;
}

class NotificationService {
  const NotificationService();

  void init() {
    FlutterForegroundTask.initCommunicationPort();
    AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelGroupKey: 'basic_channel_group',
          channelKey: 'basic_channel',
          channelName: 'Basic notifications',
          channelDescription: 'Message notifications',
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
        )
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: 'basic_channel_group',
          channelGroupName: 'Basic group',
        )
      ],
    );
  }

  Future<bool> hasNotificationPermission() =>
      AwesomeNotifications().isNotificationAllowed();

  Future<bool> hasAllNotificationPermissions() async {
    if (!await hasNotificationPermission()) return false;

    if (!(await FlutterForegroundTask.checkNotificationPermission())
        .isGranted) {
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
    if (!await hasNotificationPermission()) {
      if (!await AwesomeNotifications()
          .requestPermissionToSendNotifications()) {
        return false;
      }
    }

    if (!(await FlutterForegroundTask.checkNotificationPermission())
        .isGranted) {
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

  Future<void> dismissNotifications({required String groupKey}) =>
      AwesomeNotifications().dismissNotificationsByGroupKey(groupKey);
}
