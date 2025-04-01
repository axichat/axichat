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

  bool get canForegroundService => Platform.isAndroid || Platform.isIOS;

  bool get isShorebirdAvailable => Platform.isAndroid || Platform.isIOS;
}
