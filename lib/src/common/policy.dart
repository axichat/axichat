import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Policy {
  AndroidOptions getFssAndroidOptions() =>
      const AndroidOptions(encryptedSharedPreferences: true);

  double getMaxEmojiSize() =>
      28 * (defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0);
}
