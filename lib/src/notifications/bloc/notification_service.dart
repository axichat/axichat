import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

extension on NotificationPermission {
  bool get isGranted => this == NotificationPermission.granted;
}

///Call [init].
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool mute = false;

  bool get needsPermissions =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  String get channel => 'Messages';

  Future<void> init() async {
    FlutterForegroundTask.initCommunicationPort();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');
    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
      appName: 'Axichat',
      appUserModelId: 'Im.Axi.Axichat',
      guid: '24d51912-a1fd-4f78-a72a-fd3333feb675',
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
      windows: initializationSettingsWindows,
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: notificationTapBackground,
    );
  }

  Future<bool> hasAllNotificationPermissions() async {
    if (!needsPermissions) return true;

    if (!await Permission.notification.isGranted) {
      return false;
    }

    if (Platform.isAndroid) {
      if (!await Permission.ignoreBatteryOptimizations.isGranted) {
        return false;
      }

      if (!await Permission.systemAlertWindow.isGranted) {
        return false;
      }
    }

    return true;
  }

  Future<bool> requestAllNotificationPermissions() async {
    if (!needsPermissions) return true;

    if (!await Permission.notification.request().isGranted) {
      await AppSettings.openAppSettings(
        type: AppSettingsType.notification,
        asAnotherTask: true,
      );
      if (!await Permission.notification.isGranted) return false;
    }

    if (Platform.isAndroid) {
      if (!await Permission.ignoreBatteryOptimizations.request().isGranted) {
        await AppSettings.openAppSettings(
          type: AppSettingsType.batteryOptimization,
          asAnotherTask: true,
        );
        if (!await Permission.ignoreBatteryOptimizations.isGranted) {
          return false;
        }
      }

      if (!await Permission.systemAlertWindow.request().isGranted) {
        await FlutterForegroundTask.openSystemAlertWindowSettings();
        if (!await Permission.systemAlertWindow.isGranted) {
          return false;
        }
      }
    }

    return true;
  }

  Future<void> sendNotification({
    required String title,
    String? body,
    List<FutureOr<bool>> extraConditions = const [],
  }) async {
    if (mute) return;
    if (!await hasAllNotificationPermissions()) return;
    if (await FlutterForegroundTask.isAppOnForeground) return;
    for (final condition in extraConditions) {
      if (!await condition) return;
    }

    final packageInfo = await PackageInfo.fromPlatform();

    var androidDetails = AndroidNotificationDetails(
      channel,
      channel,
      groupKey: '${packageInfo.packageName}.MESSAGES',
      importance: Importance.max,
      priority: Priority.high,
    );
    const windowsDetails = WindowsNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();

    var notificationDetails = NotificationDetails(
      android: androidDetails,
      windows: windowsDetails,
      linux: linuxDetails,
    );

    await _plugin.show(
      Random(DateTime.now().millisecondsSinceEpoch).nextInt(10000),
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> dismissNotifications() => _plugin.cancelAll();
}
