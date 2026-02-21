// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/home/home_search_models.dart';
import 'package:axichat/src/localization/app_localizations.dart';

List<HomeSearchFilter> chatsSearchFilters(AppLocalizations l10n) => [
  HomeSearchFilter(id: SearchFilterId.all, label: l10n.chatsFilterAll),
  HomeSearchFilter(
    id: SearchFilterId.contacts,
    label: l10n.chatsFilterContacts,
  ),
  HomeSearchFilter(
    id: SearchFilterId.nonContacts,
    label: l10n.chatsFilterNonContacts,
  ),
  HomeSearchFilter(id: SearchFilterId.xmpp, label: l10n.chatsFilterXmppOnly),
  HomeSearchFilter(id: SearchFilterId.email, label: l10n.chatsFilterEmailOnly),
  HomeSearchFilter(id: SearchFilterId.hidden, label: l10n.chatsFilterHidden),
];

List<HomeSearchFilter> spamSearchFilters(AppLocalizations l10n) => [
  HomeSearchFilter(id: SearchFilterId.all, label: l10n.spamFilterAll),
  HomeSearchFilter(id: SearchFilterId.email, label: l10n.spamFilterEmail),
  HomeSearchFilter(id: SearchFilterId.xmpp, label: l10n.spamFilterXmpp),
];
