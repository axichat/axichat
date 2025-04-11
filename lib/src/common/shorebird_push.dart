import 'package:chat/src/common/capability.dart';
import 'package:chat/src/common/ui/axi_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

class ShorebirdChecker extends StatelessWidget {
  const ShorebirdChecker({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: checkShorebird(context.read<Capability>()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AxiProgressIndicator(),
                SizedBox.square(
                  dimension: 8.0,
                ),
                Text('Checking for updates'),
              ],
            ),
          );
        }
        if (!snapshot.requireData) {
          return const SizedBox.shrink();
        }
        return const Padding(
          padding: EdgeInsets.all(4.0),
          child: Text('Update available: log out and restart the app'),
        );
      },
    );
  }
}
