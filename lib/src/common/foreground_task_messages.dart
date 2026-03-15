// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide NotificationVisibility;

const emailKeepalivePrefix = 'EmailKeepalive';
const emailKeepaliveTickPrefix = 'EmailKeepaliveTick';
const emailKeepaliveStartCommand = 'Start';
const emailKeepaliveStopCommand = 'Stop';
const foregroundClientEmailKeepalive = 'email_keepalive';
const foregroundTaskMessageSeparator = '::';
const _notificationTapPrefix = 'NotificationTap';

bool launchedFromNotification = false;
String? _launchedNotificationChatJid;
var _notificationTapHandlerRegistered = false;

void recordNotificationLaunch(String? chatJid) {
  launchedFromNotification = true;
  _launchedNotificationChatJid = chatJid;
}

void ensureNotificationTapPortInitialized() {
  if (_notificationTapHandlerRegistered) {
    return;
  }
  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.addTaskDataCallback(_handleNotificationTapMessage);
  _notificationTapHandlerRegistered = true;
}

void _handleNotificationTapMessage(dynamic data) {
  if (data is! String ||
      !data.startsWith(
        '$_notificationTapPrefix$foregroundTaskMessageSeparator',
      )) {
    return;
  }
  final payload = data.substring(
    '$_notificationTapPrefix$foregroundTaskMessageSeparator'.length,
  );
  recordNotificationLaunch(payload.isEmpty ? null : payload);
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  recordNotificationLaunch(
    (notificationResponse.payload?.isEmpty ?? true)
        ? null
        : notificationResponse.payload,
  );
  FlutterForegroundTask.sendDataToMain(
    [
      _notificationTapPrefix,
      notificationResponse.payload ?? '',
    ].join(foregroundTaskMessageSeparator),
  );
}

String? takeLaunchedNotificationChatJid() {
  final payload = _launchedNotificationChatJid;
  _launchedNotificationChatJid = null;
  return payload;
}
