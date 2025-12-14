import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    hide NotificationVisibility;
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
  bool _initialized = false;
  bool _tzInitialized = false;
  bool _tzDataLoaded = false;
  String? _lastTimeZoneName;
  bool _schedulingUnsupported = false;
  final Map<int, Timer> _inAppTimers = {};
  Completer<void>? _initializationCompleter;
  bool _foregroundCheckUnavailable = false;

  bool mute = false;
  bool notificationPreviewsEnabled = false;

  bool get needsPermissions =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  bool get _supportsPlatformScheduling =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  static const String _unsupportedSchedulingMessage =
      'Scheduled notifications are unavailable on this platform; skipping reminder scheduling.';
  static const String _genericMessageNotificationTitle = 'New message';

  String get channel => 'Messages';

  Future<void> init() => _ensureInitialized();

  Future<NotificationAppLaunchDetails?>
      getAppNotificationAppLaunchDetails() async {
    await _ensureInitialized();
    return _plugin.getNotificationAppLaunchDetails();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }

    final completer = Completer<void>();
    _initializationCompleter = completer;

    try {
      FlutterForegroundTask.initCommunicationPort();
      ensureNotificationTapPortInitialized();
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

      await _ensureTimeZones(force: true);

      try {
        final launchDetails = await _plugin.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp == true) {
          final payload = launchDetails?.notificationResponse?.payload;
          recordNotificationLaunch(payload);
        }
      } on UnimplementedError catch (error, stackTrace) {
        debugPrint(
          'Notification launch details unsupported on this platform: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }

      _initialized = true;
      completer.complete();
    } catch (error, stackTrace) {
      _initializationCompleter = null;
      completer.completeError(error, stackTrace);
      rethrow;
    }
  }

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
    String? payload,
  }) async {
    if (mute) return;
    if (!await hasAllNotificationPermissions()) return;
    final bool appInForeground = await _isAppOnForeground();
    if (!allowForeground && appInForeground) {
      return;
    }
    for (final condition in extraConditions) {
      if (!await condition) return;
    }

    await _ensureInitialized();
    final notificationDetails = await _notificationDetails();

    await _plugin.show(
      Random(DateTime.now().millisecondsSinceEpoch).nextInt(10000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> sendMessageNotification({
    required String title,
    String? body,
    List<FutureOr<bool>> extraConditions = const [],
    bool allowForeground = false,
    String? payload,
    String? threadKey,
  }) async {
    if (mute) return;
    if (!await hasAllNotificationPermissions()) return;
    final bool appInForeground = await _isAppOnForeground();
    if (!allowForeground && appInForeground) {
      return;
    }
    for (final condition in extraConditions) {
      if (!await condition) return;
    }

    await _ensureInitialized();
    final notificationDetails = await _messageNotificationDetails(
      showPreview: notificationPreviewsEnabled,
    );
    final stableKey = (threadKey ?? payload)?.trim();
    final notificationId = stableKey == null || stableKey.isEmpty
        ? Random(DateTime.now().millisecondsSinceEpoch).nextInt(10000)
        : _stableNotificationId(stableKey);

    await _plugin.show(
      notificationId,
      _sanitizeMessageNotificationTitle(title),
      notificationPreviewsEnabled ? body : null,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> dismissNotifications() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  Future<bool> _isAppOnForeground() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      return await FlutterForegroundTask.isAppOnForeground;
    } on MissingPluginException catch (error, stackTrace) {
      if (!_foregroundCheckUnavailable) {
        debugPrint(
          'Foreground task plugin unavailable; assuming app is backgrounded: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        _foregroundCheckUnavailable = true;
      }
      return false;
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required DateTime scheduledAt,
    required String title,
    String? body,
    String? payload,
  }) async {
    if (mute) return;
    final hasPermissions = await hasAllNotificationPermissions();
    if (!hasPermissions) return;
    await _ensureInitialized();
    final scheduledLocal = scheduledAt.toLocal();
    if (_schedulingUnsupported || !_supportsPlatformScheduling) {
      _markSchedulingUnsupported();
      await _scheduleInAppTimer(
        id: id,
        scheduledAt: scheduledLocal,
        title: title,
        body: body,
        payload: payload,
      );
      return;
    }
    await _ensureTimeZones(force: true);

    final notificationDetails = await _notificationDetails();
    final scheduled = tz.TZDateTime.from(scheduledLocal, tz.local);

    try {
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
    } on UnimplementedError catch (error, stackTrace) {
      _markSchedulingUnsupported(error: error, stackTrace: stackTrace);
      await _scheduleInAppTimer(
        id: id,
        scheduledAt: scheduledLocal,
        title: title,
        body: body,
        payload: payload,
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    _cancelInAppTimer(id);
    await _ensureInitialized();
    await _plugin.cancel(id);
  }

  Future<void> refreshTimeZone() => _ensureTimeZones(force: true);

  void _markSchedulingUnsupported({Object? error, StackTrace? stackTrace}) {
    if (_schedulingUnsupported) {
      return;
    }
    _schedulingUnsupported = true;
    debugPrint(_unsupportedSchedulingMessage);
    if (error != null) {
      debugPrint('$error');
    }
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _scheduleInAppTimer({
    required int id,
    required DateTime scheduledAt,
    required String title,
    String? body,
    String? payload,
  }) async {
    final delay = scheduledAt.difference(DateTime.now());
    _cancelInAppTimer(id);
    if (delay.isNegative || delay.inMicroseconds == 0) {
      await _fireImmediate(id: id, title: title, body: body, payload: payload);
      return;
    }
    _inAppTimers[id] = Timer(delay, () {
      _inAppTimers.remove(id);
      unawaited(
        _fireImmediate(id: id, title: title, body: body, payload: payload),
      );
    });
  }

  Future<void> _fireImmediate({
    required int id,
    required String title,
    String? body,
    String? payload,
  }) async {
    final notificationDetails = await _notificationDetails();
    await _plugin.show(id, title, body, notificationDetails, payload: payload);
  }

  void _cancelInAppTimer(int id) {
    _inAppTimers.remove(id)?.cancel();
  }

  Future<void> _ensureTimeZones({bool force = false}) async {
    if (!_tzDataLoaded) {
      tz.initializeTimeZones();
      _tzDataLoaded = true;
    }

    String? timeZoneName;
    try {
      timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
    } catch (_) {
      timeZoneName = null;
    }

    final String resolved = timeZoneName ?? 'UTC';
    if (_tzInitialized && !force && _lastTimeZoneName == resolved) {
      return;
    }

    try {
      tz.setLocalLocation(tz.getLocation(resolved));
      _lastTimeZoneName = resolved;
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
      _lastTimeZoneName = 'UTC';
    }

    _tzInitialized = true;
  }

  Future<NotificationDetails> _notificationDetails() async {
    await _ensureInitialized();
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

  Future<NotificationDetails> _messageNotificationDetails({
    required bool showPreview,
  }) async {
    await _ensureInitialized();
    final packageInfo = await PackageInfo.fromPlatform();

    final androidDetails = AndroidNotificationDetails(
      channel,
      channel,
      groupKey: '${packageInfo.packageName}.MESSAGES',
      importance: Importance.max,
      priority: Priority.high,
      icon: androidIconPath,
      category: AndroidNotificationCategory.message,
      visibility: showPreview
          ? NotificationVisibility.public
          : NotificationVisibility.private,
    );
    const windowsDetails = WindowsNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();

    return NotificationDetails(
      android: androidDetails,
      windows: windowsDetails,
      linux: linuxDetails,
    );
  }

  String _sanitizeMessageNotificationTitle(String title) {
    final normalized = title.trim();
    if (normalized.isEmpty) return _genericMessageNotificationTitle;
    if (normalized.contains('@')) return _genericMessageNotificationTitle;
    return normalized;
  }

  int _stableNotificationId(String key) {
    var hash = 0x811c9dc5;
    for (final codeUnit in key.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return (hash & 0x7fffffff) + 1;
  }
}
