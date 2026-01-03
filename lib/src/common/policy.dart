// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Policy {
  const Policy();

  AndroidOptions getFssAndroidOptions() =>
      const AndroidOptions(encryptedSharedPreferences: true);

  MacOsOptions getFssMacOsOptions() => const MacOsOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  double getMaxEmojiSize() =>
      28 * (defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0);
}
