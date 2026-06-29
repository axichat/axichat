// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Policy {
  const Policy();

  AndroidOptions getFssAndroidOptions() => const AndroidOptions();

  MacOsOptions getFssMacOsOptions() => const _AxichatMacOsOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    usesDataProtectionKeychain: true,
  );

  double getMaxEmojiSize() =>
      28 * (defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0);
}

class _AxichatMacOsOptions extends MacOsOptions {
  const _AxichatMacOsOptions({
    super.accessibility,
    super.usesDataProtectionKeychain,
  });

  @override
  Map<String, String> toMap() => <String, String>{
    ...super.toMap(),
    'useDataProtectionKeyChain': '$usesDataProtectionKeychain',
  };
}
