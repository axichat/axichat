// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:shorebird_code_push/shorebird_code_push.dart';

/// F-Droid and other non-Play Android builds pass
/// `--dart-define=ENABLE_SHOREBIRD=false` to disable OTA patching.
const bool kEnableShorebird = bool.fromEnvironment(
  'ENABLE_SHOREBIRD',
  defaultValue: true,
);

enum ShorebirdUpdateStatus { upToDate, restartRequired, unavailable, failed }

extension ShorebirdUpdateStatusX on ShorebirdUpdateStatus {
  bool get requiresRestart => this == ShorebirdUpdateStatus.restartRequired;
}

Future<ShorebirdUpdateStatus> checkShorebirdStatus({
  ShorebirdUpdater? shorebird,
  bool applyUpdate = true,
}) async {
  if (!kEnableShorebird) {
    return ShorebirdUpdateStatus.unavailable;
  }
  final updater = shorebird ?? ShorebirdUpdater();
  if (!updater.isAvailable) {
    return ShorebirdUpdateStatus.unavailable;
  }

  try {
    final status = await updater.checkForUpdate();
    if (status == UpdateStatus.restartRequired) {
      return ShorebirdUpdateStatus.restartRequired;
    }
    if (status == UpdateStatus.outdated) {
      if (!applyUpdate) {
        return ShorebirdUpdateStatus.upToDate;
      }
      await updater.update();
      return ShorebirdUpdateStatus.restartRequired;
    }
    return ShorebirdUpdateStatus.upToDate;
  } on Exception {
    return ShorebirdUpdateStatus.failed;
  }
}
