enum MessageStorageMode {
  local,
  serverOnly;

  bool get isLocal => this == MessageStorageMode.local;

  bool get isServerOnly => this == MessageStorageMode.serverOnly;
}
