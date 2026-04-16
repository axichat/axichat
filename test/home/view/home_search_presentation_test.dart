import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/home/bloc/home_bloc.dart';
import 'package:axichat/src/home/view/home_screen.dart';
import 'package:axichat/src/localization/app_localizations_en.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final tabs = <HomeTabEntry>[
    HomeTabEntry(
      id: HomeTab.chats,
      label: l10n.homeTabChats,
      body: const SizedBox.shrink(),
      searchFilters: chatsSearchFilters(l10n),
    ),
    HomeTabEntry(
      id: HomeTab.contacts,
      label: l10n.homeTabContacts,
      body: const SizedBox.shrink(),
    ),
    HomeTabEntry(
      id: HomeTab.folders,
      label: l10n.homeTabFolders,
      body: const SizedBox.shrink(),
    ),
  ];

  group('resolveHomeSearchPresentationForState', () {
    test('hides search on the folders overview', () {
      final presentation = resolveHomeSearchPresentationForState(
        l10n: l10n,
        tabs: tabs,
        activeTab: HomeTab.folders,
        foldersSection: null,
      );

      expect(presentation.available, isFalse);
      expect(presentation.filterIds, isEmpty);
      expect(presentation.label, l10n.homeTabFolders);
      expect(presentation.alphabeticalSort, isFalse);
    });

    test('uses spam filters inside the spam folder', () {
      final presentation = resolveHomeSearchPresentationForState(
        l10n: l10n,
        tabs: tabs,
        activeTab: HomeTab.folders,
        foldersSection: FolderHomeSection.spam,
      );

      expect(presentation.available, isTrue);
      expect(presentation.filterIds, const [
        SearchFilterId.all,
        SearchFilterId.email,
        SearchFilterId.xmpp,
      ]);
      expect(presentation.label, l10n.homeTabSpam);
      expect(presentation.alphabeticalSort, isFalse);
    });

    test('uses query and sort only inside the important folder', () {
      final presentation = resolveHomeSearchPresentationForState(
        l10n: l10n,
        tabs: tabs,
        activeTab: HomeTab.folders,
        foldersSection: FolderHomeSection.important,
      );

      expect(presentation.available, isTrue);
      expect(presentation.filterIds, isEmpty);
      expect(presentation.label, l10n.homeTabImportant);
      expect(presentation.alphabeticalSort, isFalse);
    });

    test('uses alphabetical sort labels for contacts', () {
      final presentation = resolveHomeSearchPresentationForState(
        l10n: l10n,
        tabs: tabs,
        activeTab: HomeTab.contacts,
        foldersSection: null,
      );

      expect(presentation.available, isTrue);
      expect(presentation.filterIds, isEmpty);
      expect(presentation.label, l10n.homeTabContacts);
      expect(presentation.alphabeticalSort, isTrue);
    });
  });
}
