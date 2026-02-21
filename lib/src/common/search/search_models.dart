// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/localization/app_localizations.dart';

/// Shared filter ids used by search surfaces so we keep naming aligned.
enum SearchFilterId {
  all,
  contacts,
  nonContacts,
  xmpp,
  email,
  hidden,
  attachments,
}

/// Shared sort order used by search surfaces so we keep naming aligned.
enum SearchSortOrder {
  newestFirst,
  oldestFirst;

  bool get isNewestFirst => this == SearchSortOrder.newestFirst;

  SearchSortOrder get toggled => switch (this) {
    SearchSortOrder.newestFirst => SearchSortOrder.oldestFirst,
    SearchSortOrder.oldestFirst => SearchSortOrder.newestFirst,
  };

  String label(AppLocalizations l10n) => switch (this) {
    SearchSortOrder.newestFirst => l10n.chatSearchSortNewestFirst,
    SearchSortOrder.oldestFirst => l10n.chatSearchSortOldestFirst,
  };
}
