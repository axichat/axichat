import 'package:axichat/src/home/home_search_models.dart';

const chatsSearchFilters = [
  HomeSearchFilter(id: 'all', label: 'All chats'),
  HomeSearchFilter(id: 'contacts', label: 'Contacts'),
  HomeSearchFilter(id: 'nonContacts', label: 'Non-contacts'),
  HomeSearchFilter(id: 'xmpp', label: 'XMPP only'),
  HomeSearchFilter(id: 'email', label: 'Email only'),
  HomeSearchFilter(id: 'hidden', label: 'Hidden'),
];

const spamSearchFilters = [
  HomeSearchFilter(id: 'all', label: 'All spam'),
  HomeSearchFilter(id: 'email', label: 'Email'),
  HomeSearchFilter(id: 'xmpp', label: 'XMPP'),
];
