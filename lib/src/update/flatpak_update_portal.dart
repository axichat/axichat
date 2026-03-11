// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'flatpak_update_portal_stub.dart'
    if (dart.library.io) 'flatpak_update_portal_io.dart'
    as implementation;

abstract interface class FlatpakUpdatePortal {
  Future<FlatpakUpdateMonitor> createUpdateMonitor();
}

abstract interface class FlatpakUpdateMonitor {
  Stream<FlatpakUpdateInfo> get updateAvailable;

  Future<void> update({String parentWindow});

  Future<void> close();
}

final class FlatpakUpdateInfo {
  const FlatpakUpdateInfo({
    this.runningCommit,
    this.localCommit,
    this.remoteCommit,
  });

  final String? runningCommit;
  final String? localCommit;
  final String? remoteCommit;

  bool get hasUpdate =>
      remoteCommit != null &&
      (localCommit == null || localCommit != remoteCommit);
}

Future<bool> isFlatpakSandbox() => implementation.isFlatpakSandbox();

FlatpakUpdatePortal? createFlatpakUpdatePortal() =>
    implementation.createFlatpakUpdatePortal();
