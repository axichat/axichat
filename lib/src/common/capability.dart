import 'dart:io';

class Capability {
  bool get canFssBatchOperation => !Platform.isWindows;
  String get discoClient {
    if (Platform.isAndroid || Platform.isIOS) {
      return 'phone';
    }
    return 'pc';
  }
}
