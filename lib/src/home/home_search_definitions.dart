import 'package:axichat/src/home/home_search_models.dart';
import 'package:axichat/src/localization/app_localizations.dart';

List<HomeSearchFilter> chatsSearchFilters(AppLocalizations l10n) => [
      HomeSearchFilter(id: 'all', label: l10n.chatsFilterAll),
      HomeSearchFilter(id: 'contacts', label: l10n.chatsFilterContacts),
      HomeSearchFilter(id: 'nonContacts', label: l10n.chatsFilterNonContacts),
      HomeSearchFilter(id: 'xmpp', label: l10n.chatsFilterXmppOnly),
      HomeSearchFilter(id: 'email', label: l10n.chatsFilterEmailOnly),
      HomeSearchFilter(id: 'hidden', label: l10n.chatsFilterHidden),
    ];

List<HomeSearchFilter> spamSearchFilters(AppLocalizations l10n) => [
      HomeSearchFilter(id: 'all', label: l10n.spamFilterAll),
      HomeSearchFilter(id: 'email', label: l10n.spamFilterEmail),
      HomeSearchFilter(id: 'xmpp', label: l10n.spamFilterXmpp),
    ];
