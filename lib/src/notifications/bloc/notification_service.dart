// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:axichat/src/common/notification_privacy.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/notifications/notification_strings.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
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

const Duration _messageNotificationRateLimitWindow = Duration(minutes: 1);
const Duration _messageNotificationRateLimitCleanupInterval = Duration(
  minutes: 5,
);
const int _messageNotificationMaxPerThread = 30;
const int _messageNotificationMaxGlobal = 120;
const WindowRateLimit _messageNotificationPerThreadRateLimit = WindowRateLimit(
  maxEvents: _messageNotificationMaxPerThread,
  window: _messageNotificationRateLimitWindow,
);
const WindowRateLimit _messageNotificationGlobalRateLimit = WindowRateLimit(
  maxEvents: _messageNotificationMaxGlobal,
  window: _messageNotificationRateLimitWindow,
);

enum MessageNotificationChannel { chat, email }

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
  final Map<int, Timer> _inAppTimers = {};
  Completer<void>? _initializationCompleter;
  bool _foregroundCheckUnavailable = false;
  final WindowRateLimiter _messageNotificationGlobalLimiter = WindowRateLimiter(
    _messageNotificationGlobalRateLimit,
  );
  final KeyedWindowRateLimiter _messageNotificationPerThreadLimiter =
      KeyedWindowRateLimiter(
        limit: _messageNotificationPerThreadRateLimit,
        cleanupInterval: _messageNotificationRateLimitCleanupInterval,
      );
  final Logger _log = Logger('NotificationService');
  PackageInfo? _packageInfo;
  Future<PackageInfo>? _packageInfoFuture;
  final Map<String, List<_MessageNotificationEntry>>
  _messageNotificationHistoryByThread =
      <String, List<_MessageNotificationEntry>>{};

  bool mute = false;
  bool chatNotificationsMuted = false;
  bool emailNotificationsMuted = false;
  bool notificationPreviewsEnabled = false;
  NotificationStrings? _strings;

  bool get needsPermissions =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  bool get _supportsPlatformScheduling =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  static const String _unsupportedSchedulingMessage =
      'Scheduled notifications are unavailable on this platform; skipping reminder scheduling.';

  NotificationStrings get _l10n =>
      _strings ?? const NotificationStrings.empty();

  void updateLocalizations(NotificationStrings strings) {
    _strings = strings;
  }

  String get channel => _l10n.channelMessages;

  String get _genericMessageNotificationTitle => _l10n.newMessageTitle;

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
        _log.warning(
          'Notification launch details unsupported on this platform.',
          error,
          stackTrace,
        );
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
      }

      return true;
    } on MissingPluginException catch (error, stackTrace) {
      _log.warning(
        'Permission plugin unavailable while requesting permissions.',
        error,
        stackTrace,
      );
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
  }) async {
    if (mute || _isChannelMuted(channel)) return;
    if (!await hasAllNotificationPermissions()) return;
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
    final showPreview = showPreviewOverride ?? notificationPreviewsEnabled;
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

    await _showNotification(
      id: notificationId,
      title: _resolveMessageNotificationTitle(
        conversationTitle: resolvedConversationTitle,
        senderName: resolvedSenderName,
        isGroupConversation: isGroupConversation,
      ),
      body: _resolveMessageNotificationBody(
        sanitizedBody: sanitizedBody,
        senderName: resolvedSenderName,
        conversationTitle: resolvedConversationTitle,
        isGroupConversation: isGroupConversation,
        useMessagingStyle: useMessagingStyle,
      ),
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
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    _cancelInAppTimer(id);
    await _ensureInitialized();
    await _plugin.cancel(id: id);
  }

  Future<void> refreshTimeZone() => _ensureTimeZones(force: true);

  void _markSchedulingUnsupported({Object? error, StackTrace? stackTrace}) {
    if (_schedulingUnsupported) {
      return;
    }
    _schedulingUnsupported = true;
    _log.warning(_unsupportedSchedulingMessage, error, stackTrace);
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
    _inAppTimers[id] = Timer(delay, () async {
      _inAppTimers.remove(id);
      await _fireImmediate(id: id, title: title, body: body, payload: payload);
    });
  }

  Future<void> _fireImmediate({
    required int id,
    required String title,
    String? body,
    String? payload,
  }) async {
    final notificationDetails = await _notificationDetails();
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

  Future<NotificationDetails> _notificationDetails() async {
    await _ensureInitialized();
    final packageInfo = await _resolvePackageInfo();

    final androidDetails = AndroidNotificationDetails(
      channel,
      channel,
      groupKey: '${packageInfo.packageName}.MESSAGES',
      importance: Importance.max,
      priority: Priority.high,
      icon: androidIconPath,
      visibility: NotificationVisibility.private,
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
      icon: androidIconPath,
      category: AndroidNotificationCategory.message,
      styleInformation: styleInformation,
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

  String _resolveMessageNotificationTitle({
    required String conversationTitle,
    required String senderName,
    required bool isGroupConversation,
  }) {
    if (isGroupConversation) {
      return conversationTitle;
    }
    return senderName;
  }

  String? _resolveMessageNotificationBody({
    required String? sanitizedBody,
    required String senderName,
    required String conversationTitle,
    required bool isGroupConversation,
    required bool useMessagingStyle,
  }) {
    if (sanitizedBody == null) {
      return null;
    }
    if (useMessagingStyle) {
      return sanitizedBody;
    }
    if (isGroupConversation && senderName != conversationTitle) {
      return '$senderName: $sanitizedBody';
    }
    return sanitizedBody;
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
