import 'package:axichat/src/common/ui/axi_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

Future<bool> checkShorebird([ShorebirdUpdater? shorebird]) async {
  final updater = shorebird ?? ShorebirdUpdater();

  if (!updater.isAvailable) return false;

  final status = await updater.checkForUpdate();

  if (status == UpdateStatus.restartRequired) return true;

  if (status == UpdateStatus.outdated) {
    await updater.update();
    return true;
  }

  return false;
}

class ShorebirdChecker extends StatelessWidget {
  const ShorebirdChecker({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: checkShorebird(),
      builder: (context, snapshot) {
        if (snapshot.error is UpdateException) {
          return const Padding(
            padding: EdgeInsets.all(4.0),
            child: Text('Error occurred while fetching update.'),
          );
        }
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
