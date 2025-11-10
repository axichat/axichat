import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

///Call [init].
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _tzInitialized = false;

  bool mute = false;

  bool get needsPermissions =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  String get channel => 'Messages';

  Future<void> init() async {
    FlutterForegroundTask.initCommunicationPort();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(androidIconPath);
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

    await _ensureTimeZones();
  }

  Future<NotificationAppLaunchDetails?> getAppNotificationAppLaunchDetails() =>
      _plugin.getNotificationAppLaunchDetails();

  Future<bool> hasAllNotificationPermissions() async {
    if (!needsPermissions) return true;

    try {
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
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint(
        'Permission plugin unavailable; disabling notifications: $error',
      );
      mute = true;
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> requestAllNotificationPermissions() async {
    if (!needsPermissions) return true;

    try {
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
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint(
        'Permission plugin unavailable while requesting permissions: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      mute = true;
      return false;
    }
  }

  Future<void> sendNotification({
    required String title,
    String? body,
    List<FutureOr<bool>> extraConditions = const [],
    bool allowForeground = false,
  }) async {
    if (mute) return;
    if (!await hasAllNotificationPermissions()) return;
    if (!allowForeground && await FlutterForegroundTask.isAppOnForeground) {
      return;
    }
    for (final condition in extraConditions) {
      if (!await condition) return;
    }

    final notificationDetails = await _notificationDetails();

    await _plugin.show(
      Random(DateTime.now().millisecondsSinceEpoch).nextInt(10000),
      title,
      body,
      notificationDetails,
      payload: title,
    );
  }

  Future<void> dismissNotifications() => _plugin.cancelAll();

  Future<void> scheduleNotification({
    required int id,
    required DateTime scheduledAt,
    required String title,
    String? body,
    String? payload,
  }) async {
    if (mute) return;
    if (!await hasAllNotificationPermissions()) return;
    await _ensureTimeZones();

    final notificationDetails = await _notificationDetails();
    final scheduled = tz.TZDateTime.from(scheduledAt, tz.local);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
      matchDateTimeComponents: null,
    );
  }

  Future<void> cancelNotification(int id) => _plugin.cancel(id);

  Future<void> _ensureTimeZones() async {
    if (_tzInitialized) {
      return;
    }

    tz.initializeTimeZones();
    try {
      final name = await FlutterNativeTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    _tzInitialized = true;
  }

  Future<NotificationDetails> _notificationDetails() async {
    final packageInfo = await PackageInfo.fromPlatform();

    final androidDetails = AndroidNotificationDetails(
      channel,
      channel,
      groupKey: '${packageInfo.packageName}.MESSAGES',
      importance: Importance.max,
      priority: Priority.high,
      icon: androidIconPath,
    );
    const windowsDetails = WindowsNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();

    return NotificationDetails(
      android: androidDetails,
      windows: windowsDetails,
      linux: linuxDetails,
    );
  }
}
