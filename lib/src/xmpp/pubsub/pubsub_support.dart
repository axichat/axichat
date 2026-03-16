// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

class PubSubSupport {
  const PubSubSupport({
    required this.pubSubSupported,
    required this.pepSupported,
    required this.bookmarks2Supported,
  });

  final bool pubSubSupported;
  final bool pepSupported;
  final bool bookmarks2Supported;

  bool get canUsePepNodes => pubSubSupported && pepSupported;

  bool get canUseBookmarks2 => canUsePepNodes && bookmarks2Supported;

  @override
  bool operator ==(Object other) {
    return other is PubSubSupport &&
        other.pubSubSupported == pubSubSupported &&
        other.pepSupported == pepSupported &&
        other.bookmarks2Supported == bookmarks2Supported;
  }

  @override
  int get hashCode =>
      Object.hash(pubSubSupported, pepSupported, bookmarks2Supported);
}
