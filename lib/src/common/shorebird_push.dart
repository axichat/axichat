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

final class ShorebirdCheckResult {
  const ShorebirdCheckResult({required this.status, this.nextPatchNumber});

  final ShorebirdUpdateStatus status;
  final int? nextPatchNumber;
}

Future<ShorebirdCheckResult> checkShorebirdStatus({
  ShorebirdUpdater? shorebird,
  bool applyUpdate = true,
}) async {
  if (!kEnableShorebird) {
    return const ShorebirdCheckResult(
      status: ShorebirdUpdateStatus.unavailable,
    );
  }
  final updater = shorebird ?? ShorebirdUpdater();
  if (!updater.isAvailable) {
    return const ShorebirdCheckResult(
      status: ShorebirdUpdateStatus.unavailable,
    );
  }

  try {
    final status = await updater.checkForUpdate();
    if (status == UpdateStatus.restartRequired) {
      final nextPatch = await updater.readNextPatch();
      return ShorebirdCheckResult(
        status: ShorebirdUpdateStatus.restartRequired,
        nextPatchNumber: nextPatch?.number,
      );
    }
    if (status == UpdateStatus.outdated) {
      if (!applyUpdate) {
        return const ShorebirdCheckResult(
          status: ShorebirdUpdateStatus.upToDate,
        );
      }
      await updater.update();
      final nextPatch = await updater.readNextPatch();
      return ShorebirdCheckResult(
        status: ShorebirdUpdateStatus.restartRequired,
        nextPatchNumber: nextPatch?.number,
      );
    }
    return const ShorebirdCheckResult(status: ShorebirdUpdateStatus.upToDate);
  } on Exception {
    return const ShorebirdCheckResult(status: ShorebirdUpdateStatus.failed);
  }
}
