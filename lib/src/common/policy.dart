import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Policy {
  AndroidOptions getFssAndroidOptions() =>
      const AndroidOptions(encryptedSharedPreferences: true);
}
