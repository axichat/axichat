// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BackgroundMessagingPlatform {
  BackgroundMessagingPlatform({MethodChannel? methodChannel, bool? enabled})
    : _methodChannel = methodChannel ?? const MethodChannel(_methodChannelName),
      _enabled = enabled ?? (!kIsWeb && Platform.isMacOS);

  static const String _methodChannelName =
      'im.axi.axichat/background_messaging';

  final MethodChannel _methodChannel;
  final bool _enabled;

  Future<void> setBackgroundMessagingEnabled(bool enabled) async {
    if (!_enabled) {
      return;
    }
    try {
      await _methodChannel.invokeMethod<void>(
        'setBackgroundMessagingEnabled',
        enabled,
      );
    } on MissingPluginException {
      return;
    }
  }
}
