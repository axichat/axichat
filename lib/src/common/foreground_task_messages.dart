// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide NotificationVisibility;

const foregroundClientEmailDelta = 'email_delta';
const foregroundTaskMessageSeparator = '::';
const foregroundNotificationSnapshotPrefix = 'NotificationSnapshot';
const foregroundNotificationSnapshotAckPrefix = 'NotificationSnapshotAck';
const foregroundNotificationShownPrefix = 'ForegroundNotificationShown';
const _notificationTapPrefix = 'NotificationTap';

bool launchedFromNotification = false;
String? _launchedNotificationPayload;
var _notificationTapHandlerRegistered = false;
final _notificationTapPayloadController = StreamController<String?>.broadcast(
  sync: true,
);

Stream<String?> get notificationTapPayloadStream =>
    _notificationTapPayloadController.stream;

void recordNotificationLaunch(String? payload) {
  launchedFromNotification = true;
  _launchedNotificationPayload = payload;
  _notificationTapPayloadController.add(payload);
}

void clearLaunchedNotification() {
  launchedFromNotification = false;
  _launchedNotificationPayload = null;
}

String? takeLaunchedNotificationPayload() {
  launchedFromNotification = false;
  final payload = _launchedNotificationPayload;
  _launchedNotificationPayload = null;
  return payload;
}

@pragma('vm:entry-point')
void handleNotificationResponse(NotificationResponse notificationResponse) {
  recordNotificationLaunch(
    (notificationResponse.payload?.isEmpty ?? true)
        ? null
        : notificationResponse.payload,
  );
}

@pragma('vm:entry-point')
void handleBackgroundNotificationResponse(
  NotificationResponse notificationResponse,
) {
  if (!Platform.isAndroid) {
    handleNotificationResponse(notificationResponse);
    return;
  }
  FlutterForegroundTask.sendDataToMain(
    [
      _notificationTapPrefix,
      notificationResponse.payload ?? '',
    ].join(foregroundTaskMessageSeparator),
  );
}

void ensureNotificationTapPortInitialized() {
  if (!Platform.isAndroid) {
    return;
  }
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
