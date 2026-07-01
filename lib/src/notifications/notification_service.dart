// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/foreground_notification_snapshot.dart';
import 'package:axichat/src/common/foreground_task_messages.dart';
import 'package:axichat/src/common/notification_privacy.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    hide NotificationVisibility;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const String _androidIconPath = '@mipmap/ic_launcher';

enum MessageNotificationChannel {
  chat,
  email;

  String notificationTitle(NotificationStrings strings) {
    return switch (this) {
      MessageNotificationChannel.chat => strings.newMessageTitle,
      MessageNotificationChannel.email => strings.newEmailTitle,
    };
  }
}

enum ReminderSchedulingPermissionRequestResult {
  granted,
  denied,
  unavailable,
  failed,
}

enum NotificationUrgency { normal, timeSensitive }

enum NotificationPermissionRequestResult {
  granted,
  denied,
  awaitingNotificationSettings,
  awaitingBatteryOptimizationSettings;

  bool get isGranted => this == NotificationPermissionRequestResult.granted;
}

class PendingNotificationReference {
  const PendingNotificationReference({
    required this.id,
    this.title,
    this.body,
    this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

class NotificationStrings {
  const NotificationStrings({
    required this.channelMessages,
    required this.newMessageTitle,
    required this.newEmailTitle,
    required this.openAction,
    required this.appTitle,
    required this.backgroundConnectionDisabledTitle,
    required this.backgroundConnectionDisabledBody,
  });

  const NotificationStrings.empty()
    : channelMessages = '',
      newMessageTitle = '',
      newEmailTitle = '',
      openAction = '',
      appTitle = '',
      backgroundConnectionDisabledTitle = '',
      backgroundConnectionDisabledBody = '';

  final String channelMessages;
  final String newMessageTitle;
  final String newEmailTitle;
  final String openAction;
  final String appTitle;
  final String backgroundConnectionDisabledTitle;
  final String backgroundConnectionDisabledBody;
}

extension ForegroundNotificationStringsFromNotificationStrings
    on NotificationStrings {
  ForegroundNotificationStrings toForegroundNotificationStrings() {
    return ForegroundNotificationStrings(
      channelMessages: channelMessages,
      newMessageTitle: newMessageTitle,
      newEmailTitle: newEmailTitle,
      openAction: openAction,
      appTitle: appTitle,
    );
  }
}

extension NotificationStringsFromL10n on AppLocalizations {
  NotificationStrings toNotificationStrings() {
    return NotificationStrings(
      channelMessages: notificationChannelMessages,
      newMessageTitle: notificationNewMessageTitle,
      newEmailTitle: notificationNewEmailTitle,
      openAction: notificationOpenAction,
      appTitle: appTitle,
      backgroundConnectionDisabledTitle:
          notificationBackgroundConnectionDisabledTitle,
      backgroundConnectionDisabledBody:
          notificationBackgroundConnectionDisabledBody,
    );
  }
}

final class _MessageNotificationEntry {
  const _MessageNotificationEntry({
    required this.senderName,
    required this.senderKey,
    required this.text,
    required this.timestamp,
  });

  final String senderName;
  final String senderKey;
  final String text;
  final DateTime timestamp;
}

@visibleForTesting
({String title, String? body}) resolveMessageNotificationPresentation({
  required NotificationStrings strings,
  required MessageNotificationChannel channel,
  required String conversationTitle,
  required String senderName,
  required bool isGroupConversation,
  required String? sanitizedBody,
  required bool useMessagingStyle,
}) {
  if (sanitizedBody != null) {
    return (
      title: isGroupConversation ? conversationTitle : senderName,
      body: useMessagingStyle
          ? sanitizedBody
          : _resolveMessageNotificationBody(
              sanitizedBody: sanitizedBody,
              senderName: senderName,
              conversationTitle: conversationTitle,
              isGroupConversation: isGroupConversation,
            ),
    );
  }

  return (
    title: _messageNotificationHeadline(
      categoryTitle: channel.notificationTitle(strings),
      label: isGroupConversation ? conversationTitle : senderName,
    ),
    body: isGroupConversation && senderName.trim() != conversationTitle.trim()
        ? senderName
        : null,
  );
}

String _messageNotificationHeadline({
  required String categoryTitle,
  required String label,
}) {
  final normalizedCategory = categoryTitle.trim();
  final normalizedLabel = label.trim();
  if (normalizedCategory.isEmpty) {
    return normalizedLabel;
  }
  if (normalizedLabel.isEmpty) {
    return normalizedCategory;
  }
  return '$normalizedCategory: $normalizedLabel';
}

String _resolveMessageNotificationBody({
  required String sanitizedBody,
  required String senderName,
  required String conversationTitle,
  required bool isGroupConversation,
}) {
  if (isGroupConversation && senderName != conversationTitle) {
    return '$senderName: $sanitizedBody';
  }
  return sanitizedBody;
}

///Call [init].
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int _messageNotificationHistoryLimit = 8;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _tzInitialized = false;
  bool _tzDataLoaded = false;
  String? _lastTimeZoneName;
  bool _schedulingUnsupported = false;
  bool _launchDetailsUnsupported = false;
  final Map<int, Timer> _inAppTimers = {};
  Completer<void>? _initializationCompleter;
  bool _foregroundCheckUnavailable = false;
  final WindowRateLimiter _messageNotificationGlobalLimiter = WindowRateLimiter(
    messageNotificationGlobalRateLimit,
  );
  final KeyedWindowRateLimiter _messageNotificationPerThreadLimiter =
      KeyedWindowRateLimiter(
        limit: messageNotificationPerThreadRateLimit,
        cleanupInterval: messageNotificationRateLimitCleanupInterval,
      );
  final Logger _log = Logger('NotificationService');
  PackageInfo? _packageInfo;
  Future<PackageInfo>? _packageInfoFuture;
  final Map<String, List<_MessageNotificationEntry>>
  _messageNotificationHistoryByThread =
      <String, List<_MessageNotificationEntry>>{};

  bool mute = false;
  bool backgroundMessageNotificationsEnabled = false;
  bool chatNotificationsMuted = false;
  bool emailNotificationsMuted = false;
  bool notificationPreviewsEnabled = false;
  NotificationStrings? _strings;

  bool get needsPermissions => Platform.isAndroid;
  bool get _supportsPlatformScheduling =>
      Platform.isAndroid || Platform.isWindows;
  AndroidFlutterLocalNotificationsPlugin? get _androidNotificationsPlugin =>
      _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  static const String _unsupportedSchedulingMessage =
      'Scheduled notifications are unavailable on this platform; skipping reminder scheduling.';
  static const String _unsupportedLaunchDetailsMessage =
      'Notification launch details are unavailable on this platform; skipping notification launch handling.';

  NotificationStrings get _l10n =>
      _strings ?? const NotificationStrings.empty();

  void updateLocalizations(NotificationStrings strings) {
    _strings = strings;
  }

  void updateRuntimeSettings({
    required bool backgroundMessageNotificationsEnabled,
    required bool chatNotificationsMuted,
    required bool emailNotificationsMuted,
    required bool notificationPreviewsEnabled,
  }) {
    this.backgroundMessageNotificationsEnabled =
        backgroundMessageNotificationsEnabled;
    this.chatNotificationsMuted = chatNotificationsMuted;
    this.emailNotificationsMuted = emailNotificationsMuted;
    this.notificationPreviewsEnabled = notificationPreviewsEnabled;
  }

  Stream<String?> get notificationTapPayloads => notificationTapPayloadStream;

  String get channel => _l10n.channelMessages;

  String get _genericMessageNotificationTitle => _l10n.newMessageTitle;

  Future<void> init() => _ensureInitialized();

  Future<NotificationAppLaunchDetails?>
  getAppNotificationAppLaunchDetails() async {
    await _ensureInitialized();
    return _getNotificationAppLaunchDetails();
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
      if (Platform.isAndroid) {
        FlutterForegroundTask.initCommunicationPort();
      }
      ensureNotificationTapPortInitialized();
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings(_androidIconPath);
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();
      final LinuxInitializationSettings initializationSettingsLinux =
          LinuxInitializationSettings(defaultActionName: _l10n.openAction);
      final WindowsInitializationSettings initializationSettingsWindows =
          WindowsInitializationSettings(
            appName: _l10n.appTitle,
            appUserModelId: 'Im.Axi.Axichat',
            guid: '24d51912-a1fd-4f78-a72a-fd3333feb675',
          );

      final InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
            macOS: initializationSettingsDarwin,
            linux: initializationSettingsLinux,
            windows: initializationSettingsWindows,
          );

      await _plugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            handleBackgroundNotificationResponse,
      );

      await _ensureTimeZones(force: true);

      final launchDetails = await _getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        final payload = launchDetails?.notificationResponse?.payload;
        recordNotificationLaunch(payload);
      }

      _initialized = true;
      completer.complete();
    } catch (error, stackTrace) {
      _initializationCompleter = null;
      completer.completeError(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> hasNotificationDisplayPermission() async {
    if (!needsPermissions) return true;

    try {
      if (!await Permission.notification.isGranted) {
        return false;
      }
      return true;
    } on MissingPluginException catch (error, stackTrace) {
      _log.warning(
        'Permission plugin unavailable; disabling notifications.',
        error,
        stackTrace,
      );
      mute = true;
      return false;
    }
  }

  Future<bool> hasAllNotificationPermissions() async {
    if (!await hasNotificationDisplayPermission()) {
      return false;
    }
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      return await Permission.ignoreBatteryOptimizations.isGranted;
    } on MissingPluginException catch (error, stackTrace) {
      _log.warning(
        'Battery optimization permission plugin unavailable; disabling background messaging notifications.',
        error,
        stackTrace,
      );
      mute = true;
      return false;
    }
  }

  Future<NotificationPermissionRequestResult>
  requestNotificationDisplayPermission({
    bool openSettingsIfRequired = false,
  }) async {
    if (!needsPermissions) {
      return NotificationPermissionRequestResult.granted;
    }

    try {
      final PermissionStatus status = await Permission.notification.status;
      if (status.isGranted) {
        return NotificationPermissionRequestResult.granted;
      }
      if (status.isPermanentlyDenied) {
        if (openSettingsIfRequired) {
          await _openNotificationSettings();
        }
        return NotificationPermissionRequestResult.awaitingNotificationSettings;
      }
      if (status.isRestricted) {
        return NotificationPermissionRequestResult.denied;
      }

      final PermissionStatus requested = await Permission.notification
          .request();
      if (requested.isGranted) {
        return NotificationPermissionRequestResult.granted;
      }
      if (requested.isPermanentlyDenied) {
        if (openSettingsIfRequired) {
          await _openNotificationSettings();
        }
        return NotificationPermissionRequestResult.awaitingNotificationSettings;
      }
      return NotificationPermissionRequestResult.denied;
    } on MissingPluginException catch (error, stackTrace) {
      _log.warning(
        'Permission plugin unavailable while requesting permissions.',
        error,
        stackTrace,
      );
      mute = true;
      return NotificationPermissionRequestResult.denied;
    }
  }

  Future<NotificationPermissionRequestResult>
  requestAllNotificationPermissions() async {
    final displayPermissionResult = await requestNotificationDisplayPermission(
      openSettingsIfRequired: true,
    );
    if (!displayPermissionResult.isGranted) {
      return displayPermissionResult;
    }

    try {
      if (Platform.isAndroid) {
        await Permission.ignoreBatteryOptimizations.request();
        if (!await _permissionStatusSettled(
          () => Permission.ignoreBatteryOptimizations.isGranted,
        )) {
          await AppSettings.openAppSettings(
            type: AppSettingsType.batteryOptimization,
          );
          if (!await Permission.ignoreBatteryOptimizations.isGranted) {
            return NotificationPermissionRequestResult
                .awaitingBatteryOptimizationSettings;
          }
        }
      }

      return NotificationPermissionRequestResult.granted;
    } on MissingPluginException catch (error, stackTrace) {
      _log.warning(
        'Permission plugin unavailable while requesting background notification permissions.',
        error,
        stackTrace,
      );
      mute = true;
      return NotificationPermissionRequestResult.denied;
    }
  }

  Future<bool> _permissionStatusSettled(Future<bool> Function() check) async {
    if (await check()) {
      return true;
    }
    const settleDelay = Duration(milliseconds: 250);
    const settleAttempts = 16;
    for (var attempt = 0; attempt < settleAttempts; attempt += 1) {
      await Future<void>.delayed(settleDelay);
      if (await check()) {
        return true;
      }
    }
    return false;
  }

  Future<bool> hasPermissionResolvedFor(
    NotificationPermissionRequestResult result,
  ) async {
    if (!needsPermissions) return true;

    try {
      switch (result) {
        case NotificationPermissionRequestResult.granted:
          return true;
        case NotificationPermissionRequestResult.denied:
          return false;
        case NotificationPermissionRequestResult.awaitingNotificationSettings:
          return await Permission.notification.isGranted;
        case NotificationPermissionRequestResult
            .awaitingBatteryOptimizationSettings:
          if (!Platform.isAndroid) return true;
          return await Permission.ignoreBatteryOptimizations.isGranted;
      }
    } on MissingPluginException catch (error, stackTrace) {
      _log.warning(
        'Permission plugin unavailable while checking requested permission.',
        error,
        stackTrace,
      );
      mute = true;
      return false;
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    } on MissingPluginException catch (error, stackTrace) {
      _log.fine(
        'App settings plugin unavailable while opening notification settings.',
        error,
        stackTrace,
      );
    } on PlatformException catch (error, stackTrace) {
      _log.fine('Failed to open notification settings.', error, stackTrace);
    }
  }

  Future<void> openNotificationSettings() {
    return _openNotificationSettings();
  }

  Future<bool> hasReminderSchedulingPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      return await Permission.scheduleExactAlarm.isGranted;
    } on MissingPluginException catch (error, stackTrace) {
      _log.warning(
        'Exact alarm permission plugin unavailable; reminder scheduling may be degraded.',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<ReminderSchedulingPermissionRequestResult>
  requestReminderSchedulingPermission({
    bool openSettingsFallback = false,
  }) async {
    if (!Platform.isAndroid) {
      return ReminderSchedulingPermissionRequestResult.granted;
    }
    try {
      if (await Permission.scheduleExactAlarm.isGranted) {
        return ReminderSchedulingPermissionRequestResult.granted;
      }

      final granted = await _androidNotificationsPlugin
          ?.requestExactAlarmsPermission();
      if (granted == true || await Permission.scheduleExactAlarm.isGranted) {
        return ReminderSchedulingPermissionRequestResult.granted;
      }

      if (!openSettingsFallback) {
        return ReminderSchedulingPermissionRequestResult.denied;
      }

      await AppSettings.openAppSettings(
        type: AppSettingsType.alarm,
        asAnotherTask: true,
      );
      return await Permission.scheduleExactAlarm.isGranted
          ? ReminderSchedulingPermissionRequestResult.granted
          : ReminderSchedulingPermissionRequestResult.denied;
    } on PlatformException catch (error, stackTrace) {
      _log.warning(
        'Exact alarm permission request failed; reminder scheduling may be degraded.',
        error,
        stackTrace,
      );
      return await Permission.scheduleExactAlarm.isGranted
          ? ReminderSchedulingPermissionRequestResult.granted
          : ReminderSchedulingPermissionRequestResult.failed;
    } on MissingPluginException catch (error, stackTrace) {
      _log.warning(
        'Exact alarm permission plugin unavailable while requesting reminder scheduling permission.',
        error,
        stackTrace,
      );
      return ReminderSchedulingPermissionRequestResult.unavailable;
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
    if (!await hasNotificationDisplayPermission()) return;
    final bool appInForeground = await _isAppOnForeground();
    if (!allowForeground && appInForeground) {
      return;
    }
    for (final condition in extraConditions) {
      if (!await condition) return;
    }

    await _ensureInitialized();
    final notificationDetails = await _notificationDetails();
    final String? sanitizedBody = sanitizeNotificationPreview(body);

    await _showNotification(
      id: Random(DateTime.now().millisecondsSinceEpoch).nextInt(10000),
      title: title,
      body: sanitizedBody,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  Future<void> sendMessageNotification({
    required String title,
    String? body,
    String? senderName,
    String? senderKey,
    String? conversationTitle,
    DateTime? sentAt,
    bool isGroupConversation = false,
    List<FutureOr<bool>> extraConditions = const [],
    bool allowForeground = false,
    String? payload,
    String? threadKey,
    bool? showPreviewOverride,
    MessageNotificationChannel channel = MessageNotificationChannel.chat,
    bool ignoreChannelMute = false,
  }) async {
    if (mute || (!ignoreChannelMute && _isChannelMuted(channel))) return;
    if (!backgroundMessageNotificationsEnabled) return;
    if (!await hasNotificationDisplayPermission()) return;
    final bool appInForeground = await _isAppOnForeground();
    if (!allowForeground && appInForeground) {
      return;
    }
    for (final condition in extraConditions) {
      if (!await condition) return;
    }

    final stableKey = (threadKey ?? payload)?.trim();
    if (!_allowMessageNotification(stableKey)) {
      return;
    }

    await _ensureInitialized();
    final showPreview = resolveNotificationPreviewEnabled(
      platform: defaultTargetPlatform,
      globalPreviewsEnabled: notificationPreviewsEnabled,
      previewOverride: showPreviewOverride,
    );
    final resolvedConversationTitle = _resolveMessageNotificationLabel(
      conversationTitle,
      fallback: title,
    );
    final resolvedSenderName = _resolveMessageNotificationLabel(
      senderName,
      fallback: title,
    );
    final resolvedSenderKey = _resolveMessageNotificationSenderKey(
      senderKey,
      fallback: resolvedSenderName,
    );
    final notificationDetails = await _messageNotificationDetails(
      showPreview: showPreview,
      conversationTitle: resolvedConversationTitle,
      isGroupConversation: isGroupConversation,
      messages: _buildMessageNotificationHistory(
        threadKey: stableKey,
        showPreview: showPreview,
        senderName: resolvedSenderName,
        senderKey: resolvedSenderKey,
        body: body,
        sentAt: sentAt,
      ),
    );
    final notificationId = stableKey == null || stableKey.isEmpty
        ? Random(DateTime.now().millisecondsSinceEpoch).nextInt(10000)
        : _stableNotificationId(stableKey);
    final String? sanitizedBody = showPreview
        ? sanitizeNotificationPreview(body)
        : null;
    final bool useMessagingStyle =
        Platform.isAndroid && showPreview && sanitizedBody != null;
    final presentation = resolveMessageNotificationPresentation(
      strings: _l10n,
      channel: channel,
      conversationTitle: resolvedConversationTitle,
      senderName: resolvedSenderName,
      isGroupConversation: isGroupConversation,
      sanitizedBody: sanitizedBody,
      useMessagingStyle: useMessagingStyle,
    );

    await _showNotification(
      id: notificationId,
      title: presentation.title,
      body: presentation.body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  bool _isChannelMuted(MessageNotificationChannel channel) {
    return switch (channel) {
      MessageNotificationChannel.chat => chatNotificationsMuted,
      MessageNotificationChannel.email => emailNotificationsMuted,
    };
  }

  Future<void> dismissMessageNotification({required String threadKey}) async {
    final normalized = threadKey.trim();
    if (normalized.isEmpty) return;
    _messageNotificationHistoryByThread.remove(normalized);
    await cancelNotification(_stableNotificationId(normalized));
  }

  Future<void> dismissNotifications() async {
    _messageNotificationHistoryByThread.clear();
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
        _log.warning(
          'Foreground task plugin unavailable; assuming app is backgrounded.',
          error,
          stackTrace,
        );
        _foregroundCheckUnavailable = true;
      }
      return false;
    }
  }

  Future<void> sendBackgroundConnectionDisabledNotification() async {
    await sendNotification(
      title: _l10n.backgroundConnectionDisabledTitle,
      body: _l10n.backgroundConnectionDisabledBody,
      allowForeground: true,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required DateTime scheduledAt,
    required String title,
    String? body,
    String? payload,
    NotificationUrgency urgency = NotificationUrgency.normal,
  }) async {
    if (mute) return;
    final hasPermissions = await hasNotificationDisplayPermission();
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
        urgency: urgency,
      );
      return;
    }
    if (Platform.isAndroid && !await hasReminderSchedulingPermission()) {
      _log.warning(
        'Exact alarm permission denied; using in-app reminder fallback until alarms & reminders access is granted.',
      );
      await _scheduleInAppTimer(
        id: id,
        scheduledAt: scheduledLocal,
        title: title,
        body: body,
        payload: payload,
        urgency: urgency,
      );
      return;
    }
    await _ensureTimeZones(force: true);

    final notificationDetails = await _notificationDetails(urgency: urgency);
    final scheduled = tz.TZDateTime.from(scheduledLocal, tz.local);

    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: scheduled,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: title,
        body: body,
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
        urgency: urgency,
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    _cancelInAppTimer(id);
    await _ensureInitialized();
    await _plugin.cancel(id: id);
  }

  Future<List<PendingNotificationReference>>
  pendingNotificationRequests() async {
    await _ensureInitialized();
    try {
      final List<PendingNotificationRequest> requests = await _plugin
          .pendingNotificationRequests();
      return <PendingNotificationReference>[
        for (final PendingNotificationRequest request in requests)
          PendingNotificationReference(
            id: request.id,
            title: request.title,
            body: request.body,
            payload: request.payload,
          ),
      ];
    } on UnimplementedError catch (error, stackTrace) {
      _log.warning(
        'Pending notification requests are unavailable on this platform.',
        error,
        stackTrace,
      );
      return const <PendingNotificationReference>[];
    } on MissingPluginException catch (error, stackTrace) {
      _log.warning(
        'Pending notification requests plugin unavailable.',
        error,
        stackTrace,
      );
      return const <PendingNotificationReference>[];
    }
  }

  Future<void> refreshTimeZone() => _ensureTimeZones(force: true);

  void _markSchedulingUnsupported({Object? error, StackTrace? stackTrace}) {
    if (_schedulingUnsupported) {
      return;
    }
    _schedulingUnsupported = true;
    _log.warning(_unsupportedSchedulingMessage, error, stackTrace);
  }

  Future<NotificationAppLaunchDetails?>
  _getNotificationAppLaunchDetails() async {
    if (_launchDetailsUnsupported) {
      return null;
    }
    try {
      return await _plugin.getNotificationAppLaunchDetails();
    } on UnimplementedError catch (error, stackTrace) {
      _markLaunchDetailsUnsupported(error: error, stackTrace: stackTrace);
      return null;
    }
  }

  void _markLaunchDetailsUnsupported({Object? error, StackTrace? stackTrace}) {
    if (_launchDetailsUnsupported) {
      return;
    }
    _launchDetailsUnsupported = true;
    _log.warning(_unsupportedLaunchDetailsMessage, error, stackTrace);
  }

  Future<void> _scheduleInAppTimer({
    required int id,
    required DateTime scheduledAt,
    required String title,
    String? body,
    String? payload,
    NotificationUrgency urgency = NotificationUrgency.normal,
  }) async {
    final delay = scheduledAt.difference(DateTime.now());
    _cancelInAppTimer(id);
    if (delay.isNegative || delay.inMicroseconds == 0) {
      await _fireImmediate(
        id: id,
        title: title,
        body: body,
        payload: payload,
        urgency: urgency,
      );
      return;
    }
    _inAppTimers[id] = Timer(delay, () async {
      _inAppTimers.remove(id);
      await _fireImmediate(
        id: id,
        title: title,
        body: body,
        payload: payload,
        urgency: urgency,
      );
    });
  }

  Future<void> _fireImmediate({
    required int id,
    required String title,
    String? body,
    String? payload,
    NotificationUrgency urgency = NotificationUrgency.normal,
  }) async {
    final notificationDetails = await _notificationDetails(urgency: urgency);
    await _showNotification(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
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
      timeZoneName = await FlutterTimezone.getLocalTimezone();
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

  Future<NotificationDetails> _notificationDetails({
    NotificationUrgency urgency = NotificationUrgency.normal,
  }) async {
    await _ensureInitialized();
    final packageInfo = await _resolvePackageInfo();

    final androidDetails = AndroidNotificationDetails(
      channel,
      channel,
      groupKey: '${packageInfo.packageName}.MESSAGES',
      importance: Importance.max,
      priority: urgency == NotificationUrgency.timeSensitive
          ? Priority.max
          : Priority.high,
      icon: _androidIconPath,
      visibility: NotificationVisibility.private,
    );
    const windowsDetails = WindowsNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();
    const darwinDetails = DarwinNotificationDetails();

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      windows: windowsDetails,
      linux: linuxDetails,
    );
  }

  Future<NotificationDetails> _messageNotificationDetails({
    required bool showPreview,
    required String conversationTitle,
    required bool isGroupConversation,
    required List<Message>? messages,
  }) async {
    await _ensureInitialized();
    final packageInfo = await _resolvePackageInfo();
    final styleInformation =
        Platform.isAndroid &&
            showPreview &&
            messages != null &&
            messages.isNotEmpty
        ? MessagingStyleInformation(
            Person(
              name: _l10n.appTitle,
              key: '${packageInfo.packageName}.self',
            ),
            conversationTitle: conversationTitle,
            groupConversation: isGroupConversation,
            messages: messages,
          )
        : null;

    final androidDetails = AndroidNotificationDetails(
      channel,
      channel,
      groupKey: '${packageInfo.packageName}.MESSAGES',
      importance: Importance.max,
      priority: Priority.high,
      icon: _androidIconPath,
      category: AndroidNotificationCategory.message,
      styleInformation: styleInformation,
      visibility: showPreview
          ? NotificationVisibility.public
          : NotificationVisibility.private,
    );
    const windowsDetails = WindowsNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();
    const darwinDetails = DarwinNotificationDetails();

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      windows: windowsDetails,
      linux: linuxDetails,
    );
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    String? body,
    required NotificationDetails notificationDetails,
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } on Exception catch (error, stackTrace) {
      if (Platform.isLinux) {
        _log.warning('Failed to show Linux notification.', error, stackTrace);
        return;
      }
      rethrow;
    }
  }

  bool _allowMessageNotification(String? threadKey) {
    final normalized = threadKey?.trim();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (normalized != null && normalized.isNotEmpty) {
      final threadAllowed = _messageNotificationPerThreadLimiter.allowEvent(
        normalized,
        nowMs: nowMs,
      );
      if (!threadAllowed) {
        return false;
      }
    }
    return _messageNotificationGlobalLimiter.allowEvent(nowMs: nowMs);
  }

  String _sanitizeMessageNotificationTitle(String title) {
    final normalized = title.trim();
    if (normalized.isEmpty) return _genericMessageNotificationTitle;
    final label = addressDisplayLabel(normalized)?.trim();
    if (label?.isNotEmpty == true) {
      return label!;
    }
    final safeAddress = displaySafeAddress(normalized)?.trim();
    if (safeAddress?.isNotEmpty == true) {
      return safeAddress!;
    }
    return normalized;
  }

  String _resolveMessageNotificationLabel(
    String? value, {
    required String fallback,
  }) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return _sanitizeMessageNotificationTitle(normalized);
    }
    return _sanitizeMessageNotificationTitle(fallback);
  }

  String _resolveMessageNotificationSenderKey(
    String? value, {
    required String fallback,
  }) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    return fallback.toLowerCase();
  }

  List<Message>? _buildMessageNotificationHistory({
    required String? threadKey,
    required bool showPreview,
    required String senderName,
    required String senderKey,
    required String? body,
    required DateTime? sentAt,
  }) {
    if (!showPreview) {
      return null;
    }
    final sanitizedBody = sanitizeNotificationPreview(body);
    if (sanitizedBody == null) {
      return null;
    }
    final entry = _MessageNotificationEntry(
      senderName: senderName,
      senderKey: senderKey,
      text: sanitizedBody,
      timestamp: sentAt ?? DateTime.now(),
    );
    final normalizedThreadKey = threadKey?.trim();
    if (normalizedThreadKey == null || normalizedThreadKey.isEmpty) {
      return <Message>[entry._toAndroidMessage()];
    }
    final history = _messageNotificationHistoryByThread.putIfAbsent(
      normalizedThreadKey,
      () => <_MessageNotificationEntry>[],
    )..add(entry);
    final overflow = history.length - _messageNotificationHistoryLimit;
    if (overflow > 0) {
      history.removeRange(0, overflow);
    }
    return history
        .map((item) => item._toAndroidMessage())
        .toList(growable: false);
  }

  int _stableNotificationId(String key) {
    var hash = 0x811c9dc5;
    for (final codeUnit in key.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return (hash & 0x7fffffff) + 1;
  }

  Future<PackageInfo> _resolvePackageInfo() async {
    final cached = _packageInfo;
    if (cached != null) {
      return cached;
    }
    final inflight = _packageInfoFuture;
    if (inflight != null) {
      return inflight;
    }
    final future = PackageInfo.fromPlatform();
    _packageInfoFuture = future;
    try {
      final resolved = await future;
      _packageInfo = resolved;
      _packageInfoFuture = null;
      return resolved;
    } on Exception catch (error, stackTrace) {
      _packageInfoFuture = null;
      _log.warning('Failed to resolve package info.', error, stackTrace);
      rethrow;
    }
  }
}

extension on _MessageNotificationEntry {
  Message _toAndroidMessage() =>
      Message(text, timestamp, Person(name: senderName, key: senderKey));
}
