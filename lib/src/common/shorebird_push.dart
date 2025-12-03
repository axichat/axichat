import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

/// F-Droid and other store builds pass `--dart-define=ENABLE_SHOREBIRD=false`
/// to disable OTA updates entirely.
const bool kEnableShorebird =
    bool.fromEnvironment('ENABLE_SHOREBIRD', defaultValue: true);

Future<bool> checkShorebird([ShorebirdUpdater? shorebird]) async {
  if (!kEnableShorebird) {
    return false;
  }
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
    if (!kEnableShorebird) {
      return const SizedBox.shrink();
    }
    return AnimatedSize(
      duration: context.watch<SettingsCubit>().animationDuration,
      curve: Curves.easeInOut,
      child: FutureBuilder<bool>(
        future: checkShorebird(),
        builder: (context, snapshot) {
          final hasUpdate = snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData &&
              snapshot.requireData;
          if (!hasUpdate) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(context.l10n.shorebirdUpdateAvailable),
          );
        },
      ),
    );
  }
}
