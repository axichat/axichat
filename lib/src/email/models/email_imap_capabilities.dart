// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

class EmailImapCapabilities {
  const EmailImapCapabilities({
    required this.idleSupported,
    required this.connectionLimit,
    required this.idleCutoff,
  });

  final bool idleSupported;
  final int connectionLimit;
  final Duration idleCutoff;

  @override
  bool operator ==(Object other) {
    return other is EmailImapCapabilities &&
        other.idleSupported == idleSupported &&
        other.connectionLimit == connectionLimit &&
        other.idleCutoff == idleCutoff;
  }

  @override
  int get hashCode => Object.hash(idleSupported, connectionLimit, idleCutoff);
}
