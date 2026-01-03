// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

/// Shared sort order used by search surfaces so we keep naming aligned.
enum SearchSortOrder {
  newestFirst,
  oldestFirst;

  bool get isNewestFirst => this == SearchSortOrder.newestFirst;

  SearchSortOrder get toggled => switch (this) {
        SearchSortOrder.newestFirst => SearchSortOrder.oldestFirst,
        SearchSortOrder.oldestFirst => SearchSortOrder.newestFirst,
      };

  String get label => switch (this) {
        SearchSortOrder.newestFirst => 'Newest first',
        SearchSortOrder.oldestFirst => 'Oldest first',
      };
}
