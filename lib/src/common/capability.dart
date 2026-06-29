// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

class Capability {
  const Capability();

  bool get canFssBatchOperation => !Platform.isWindows;

  String get discoClient {
    if (Platform.isAndroid || Platform.isIOS) {
      return 'phone';
    }
    return 'pc';
  }

  bool get canBackgroundMessaging =>
      canForegroundService || Platform.isIOS || Platform.isMacOS;

  bool get canForegroundService => Platform.isAndroid;

  bool get usesPlatformForegroundService => canForegroundService;

  bool get usesHiddenWindowBackgroundMessaging =>
      !canForegroundService && Platform.isMacOS;

  bool get defaultsBackgroundMessagingEnabled => false;
}
