const String syncLegacySourceId = 'legacy';
const int syncAddressMaxBytes = 512;
const int syncSourceIdMaxBytes = 64;

enum SyncOrigin {
  local,
  remote;

  bool get isLocal => this == SyncOrigin.local;

  bool get isRemote => this == SyncOrigin.remote;
}

class SpamSyncUpdate {
  const SpamSyncUpdate({
    required this.address,
    required this.isSpam,
    required this.updatedAt,
    required this.sourceId,
    required this.origin,
  });

  final String address;
  final bool isSpam;
  final DateTime updatedAt;
  final String sourceId;
  final SyncOrigin origin;
}

class EmailBlocklistSyncUpdate {
  const EmailBlocklistSyncUpdate({
    required this.address,
    required this.blocked,
    required this.updatedAt,
    required this.sourceId,
    required this.origin,
  });

  final String address;
  final bool blocked;
  final DateTime updatedAt;
  final String sourceId;
  final SyncOrigin origin;
}
