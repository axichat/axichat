import 'package:chat/src/common/capability.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

Future<bool> checkShorebird(
  Capability capability, [
  ShorebirdCodePush? shorebird,
]) async {
  if (!capability.isShorebirdAvailable) return false;
  final shorebirdCodePush = shorebird ?? ShorebirdCodePush();
  if (await shorebirdCodePush.isNewPatchReadyToInstall()) return true;
  if (await shorebirdCodePush.isNewPatchAvailableForDownload()) {
    await shorebirdCodePush.downloadUpdateIfAvailable();
    return true;
  }
  return false;
}
