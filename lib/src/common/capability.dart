// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

class Capability {
  const Capability();

  bool get canFssBatchOperation => !Platform.isWindows;

  String get discoClient {
    if (Platform.isAndroid) {
      return 'phone';
    }
    return 'pc';
  }

  bool get canBackgroundMessaging => canForegroundService;

  bool get canForegroundService => Platform.isAndroid;

  bool get usesPlatformForegroundService => canForegroundService;

  bool get defaultsBackgroundMessagingEnabled => false;
}
