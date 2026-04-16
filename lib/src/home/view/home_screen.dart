// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:axichat/src/accessibility/bloc/accessibility_action_bloc.dart';
import 'package:axichat/src/accessibility/view/accessibility_action_menu.dart';
import 'package:axichat/src/accessibility/view/shortcut_hint.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_coordinator.dart';
import 'package:axichat/src/calendar/view/shell/calendar_drag_cancel_bucket.dart';
import 'package:axichat/src/calendar/view/shell/calendar_task_off_grid_drag_controller.dart';
import 'package:axichat/src/calendar/view/shell/calendar_widget.dart';
import 'package:axichat/src/calendar/view/shell/calendar_task_feedback_observer.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/bloc/chat_search_cubit.dart';
import 'package:axichat/src/chat/view/chat.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/chat_selection_bar.dart';
import 'package:axichat/src/chats/view/chats_add_button.dart';
import 'package:axichat/src/chats/view/chats_filter_button.dart';
import 'package:axichat/src/chats/view/chats_list.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/ui/axi_attention_shake.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/keyboard_pop_scope.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/connectivity/view/connectivity_indicator.dart';
import 'package:axichat/src/contacts/bloc/contacts_cubit.dart';
import 'package:axichat/src/contacts/view/contacts_list.dart';
import 'package:axichat/src/demo/demo_calendar.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
import 'package:axichat/src/draft/view/draft_button.dart';
import 'package:axichat/src/draft/view/compose_window.dart';
import 'package:axichat/src/draft/view/drafts_list.dart';
import 'package:axichat/src/email/service/attachment_optimizer.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/view/email_forwarding_guide.dart';
import 'package:axichat/src/folders/bloc/folders_cubit.dart';
import 'package:axichat/src/home/bloc/home_bloc.dart';
import 'package:axichat/src/important/view/important_messages_list.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/notifications/view/omemo_operation_overlay.dart';
import 'package:axichat/src/notifications/view/xmpp_operation_overlay.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/common/ui/connection_status_indicators.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/share/bloc/share_intent_cubit.dart';
import 'package:axichat/src/spam/view/spam_list.dart';
import 'package:axichat/src/storage/models.dart' as m;
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:animations/animations.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_ui/shadcn_ui.dart';

part 'nexus.dart';
part 'bottom_bar.dart';
part 'navigation_rail.dart';
part 'search_panel.dart';

List<HomeSearchFilter> _draftsSearchFilters(AppLocalizations l10n) => [
  HomeSearchFilter(id: SearchFilterId.all, label: l10n.draftsFilterAll),
  HomeSearchFilter(
    id: SearchFilterId.attachments,
    label: l10n.draftsFilterAttachments,
  ),
];

HomeSearchSlot? _resolveHomeSearchSlot({
  required HomeTab? activeTab,
  required FolderHomeSection? foldersSection,
}) {
  final topLevelSlot = HomeSearchSlot.forTab(activeTab);
  if (topLevelSlot != null) {
    return topLevelSlot;
  }
  if (activeTab != HomeTab.folders) {
    return null;
  }
  return switch (foldersSection) {
    FolderHomeSection.important => HomeSearchSlot.foldersImportant,
    FolderHomeSection.spam => HomeSearchSlot.foldersSpam,
    null => null,
  };
}

@immutable
class HomeResolvedBadgeCounts {
  const HomeResolvedBadgeCounts({
    this.chats = 0,
    this.contacts = 0,
    this.drafts = 0,
    this.important = 0,
    this.spam = 0,
  });

  final int chats;
  final int contacts;
  final int drafts;
  final int important;
  final int spam;

  int get folders => important + spam;

  int get home => chats + contacts + drafts + important + spam;

  Map<HomeTab, int> get tabs => Map<HomeTab, int>.unmodifiable(<HomeTab, int>{
    HomeTab.chats: chats,
    HomeTab.contacts: contacts,
    HomeTab.drafts: drafts,
    HomeTab.folders: folders,
  });

  @override
  bool operator ==(Object other) {
    return other is HomeResolvedBadgeCounts &&
        chats == other.chats &&
        contacts == other.contacts &&
        drafts == other.drafts &&
        important == other.important &&
        spam == other.spam;
  }

  @override
  int get hashCode => Object.hash(chats, contacts, drafts, important, spam);
}

HomeResolvedBadgeCounts _homeResolvedBadgeCounts({
  required int chatsUnreadCount,
}) {
  return HomeResolvedBadgeCounts(chats: chatsUnreadCount);
}

({int home, int contacts, int important, int spam, Map<HomeTab, int> tabs})
_resolveHomeBadgeCounts({required int chatsUnreadCount}) {
  final counts = _homeResolvedBadgeCounts(chatsUnreadCount: chatsUnreadCount);
  return (
    home: counts.home,
    contacts: counts.contacts,
    important: counts.important,
    spam: counts.spam,
    tabs: counts.tabs,
  );
}

@visibleForTesting
({
  int contacts,
  int important,
  int spam,
  int folders,
  int home,
  Map<HomeTab, int> tabs,
})
resolveHomeBadgeCountsForTesting({required int chatsUnreadCount}) {
  final counts = _resolveHomeBadgeCounts(chatsUnreadCount: chatsUnreadCount);
  return (
    contacts: counts.contacts,
    important: counts.important,
    spam: counts.spam,
    folders: counts.tabs[HomeTab.folders] ?? 0,
    home: counts.home,
    tabs: counts.tabs,
  );
}

typedef _HomeSearchPresentation = ({
  bool available,
  List<HomeSearchFilter> filters,
  String? label,
  _HomeSearchSortLabels sortLabels,
});

enum _HomeSearchSortLabels {
  chronological,
  alphabetical;

  String label(SearchSortOrder order, AppLocalizations l10n) => switch (this) {
    _HomeSearchSortLabels.chronological => order.label(l10n),
    _HomeSearchSortLabels.alphabetical =>
      order.isNewestFirst
          ? l10n.attachmentGallerySortNameAscLabel
          : l10n.attachmentGallerySortNameDescLabel,
  };
}

HomeTabEntry? _homeTabEntryFor(List<HomeTabEntry> tabs, HomeTab? tab) {
  if (tabs.isEmpty) {
    return null;
  }
  if (tab == null) {
    return tabs.first;
  }
  for (final entry in tabs) {
    if (entry.id == tab) {
      return entry;
    }
  }
  return tabs.first;
}

_HomeSearchPresentation _resolveHomeSearchPresentation(
  BuildContext context, {
  required List<HomeTabEntry> tabs,
  required HomeTab? activeTab,
}) {
  return _resolveHomeSearchPresentationForState(
    l10n: context.l10n,
    tabs: tabs,
    activeTab: activeTab,
    foldersSection: _HomeShellScope.maybeOf(context)?.foldersSection.value,
  );
}

_HomeSearchPresentation _resolveHomeSearchPresentationForState({
  required AppLocalizations l10n,
  required List<HomeTabEntry> tabs,
  required HomeTab? activeTab,
  required FolderHomeSection? foldersSection,
}) {
  final entry = _homeTabEntryFor(tabs, activeTab);
  if (activeTab != HomeTab.folders) {
    final sortLabels = activeTab == HomeTab.contacts
        ? _HomeSearchSortLabels.alphabetical
        : _HomeSearchSortLabels.chronological;
    return (
      available: entry != null,
      filters: entry?.searchFilters ?? const <HomeSearchFilter>[],
      label: entry?.label,
      sortLabels: sortLabels,
    );
  }
  return switch (foldersSection) {
    FolderHomeSection.important => (
      available: true,
      filters: const <HomeSearchFilter>[],
      label: l10n.homeTabImportant,
      sortLabels: _HomeSearchSortLabels.chronological,
    ),
    FolderHomeSection.spam => (
      available: true,
      filters: spamSearchFilters(l10n),
      label: l10n.homeTabSpam,
      sortLabels: _HomeSearchSortLabels.chronological,
    ),
    null => (
      available: false,
      filters: const <HomeSearchFilter>[],
      label: entry?.label ?? l10n.homeTabFolders,
      sortLabels: _HomeSearchSortLabels.chronological,
    ),
  };
}

@visibleForTesting
({
  bool available,
  List<SearchFilterId> filterIds,
  String? label,
  bool alphabeticalSort,
})
resolveHomeSearchPresentationForState({
  required AppLocalizations l10n,
  required List<HomeTabEntry> tabs,
  required HomeTab? activeTab,
  required FolderHomeSection? foldersSection,
}) {
  final presentation = _resolveHomeSearchPresentationForState(
    l10n: l10n,
    tabs: tabs,
    activeTab: activeTab,
    foldersSection: foldersSection,
  );
  return (
    available: presentation.available,
    filterIds: presentation.filters
        .map((filter) => filter.id)
        .toList(growable: false),
    label: presentation.label,
    alphabeticalSort:
        presentation.sortLabels == _HomeSearchSortLabels.alphabetical,
  );
}

class HomeTabEntry {
  const HomeTabEntry({
    required this.id,
    required this.label,
    required this.body,
    this.fab,
    this.searchFilters = const <HomeSearchFilter>[],
  });

  final HomeTab id;
  final String label;
  final Widget body;
  final Widget? fab;
  final List<HomeSearchFilter> searchFilters;
}

class _HomeImportantMessagesTab extends StatefulWidget {
  const _HomeImportantMessagesTab({required this.searchSlot});

  final HomeSearchSlot searchSlot;

  @override
  State<_HomeImportantMessagesTab> createState() =>
      _HomeImportantMessagesTabState();
}

class _HomeImportantMessagesTabState extends State<_HomeImportantMessagesTab> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSearchState(context, context.read<HomeBloc>().state);
  }

  void _syncSearchState(BuildContext context, HomeState searchState) {
    final tabState = searchState.stateForSlot(widget.searchSlot);
    final query = searchState.active ? tabState.query : '';
    context.read<FoldersCubit>().updateCriteria(
      query: query,
      sortOrder: tabState.sort,
    );
  }

  Future<void> _openItem(m.FolderMessageItem item) async {
    await context.read<ChatsCubit>().openImportantMessage(
      jid: item.chatJid,
      messageReferenceId: item.messageReferenceId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeBloc, HomeState>(
      listener: _syncSearchState,
      child: ImportantMessagesList(
        showChatLabel: true,
        onPressed: (item) {
          unawaited(_openItem(item));
        },
      ),
    );
  }
}

enum FolderHomeSection {
  important,
  spam;

  String label(AppLocalizations l10n) => switch (this) {
    FolderHomeSection.important => l10n.homeTabImportant,
    FolderHomeSection.spam => l10n.homeTabSpam,
  };

  IconData get iconData => switch (this) {
    FolderHomeSection.important => Icons.star_outline_rounded,
    FolderHomeSection.spam => LucideIcons.shieldAlert,
  };
}

void _setFoldersSection(BuildContext context, FolderHomeSection? section) {
  final scope = _HomeShellScope.maybeOf(context);
  final currentSection = scope?.foldersSection.value;
  if (scope == null || currentSection == section) {
    return;
  }
  if (currentSection == FolderHomeSection.spam &&
      section != FolderHomeSection.spam) {
    context.read<HomeBloc>().add(
      const HomeSearchFilterChanged(
        SearchFilterId.all,
        slot: HomeSearchSlot.foldersSpam,
      ),
    );
  }
  scope.setFoldersSection(section);
}

class _FoldersTab extends StatefulWidget {
  const _FoldersTab();

  @override
  State<_FoldersTab> createState() => _FoldersTabState();
}

class _FoldersTabState extends State<_FoldersTab> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  ValueListenable<int>? _selectedBottomIndexNotifier;

  void _popToRoot() {
    _setFoldersSection(context, null);
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) {
      return;
    }
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextSelectedBottomIndex = _HomeShellScope.maybeOf(
      context,
    )?.selectedBottomIndex;
    if (_selectedBottomIndexNotifier != nextSelectedBottomIndex) {
      _selectedBottomIndexNotifier?.removeListener(
        _handleShellSelectionChanged,
      );
      _selectedBottomIndexNotifier = nextSelectedBottomIndex;
      _selectedBottomIndexNotifier?.addListener(_handleShellSelectionChanged);
    }
  }

  @override
  void dispose() {
    _selectedBottomIndexNotifier?.removeListener(_handleShellSelectionChanged);
    super.dispose();
  }

  void _handleShellSelectionChanged() {
    if (!mounted) {
      return;
    }
    if ((_selectedBottomIndexNotifier?.value ?? 0) != 0) {
      _popToRoot();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeBloc, HomeState>(
      listenWhen: (previous, current) =>
          previous.activeTab != current.activeTab,
      listener: (_, state) {
        if (state.activeTab != HomeTab.folders) {
          _popToRoot();
        }
      },
      child: NavigatorPopHandler<void>(
        enabled: true,
        onPopWithResult: (_) {
          final navigator = _navigatorKey.currentState;
          if (navigator == null || !navigator.canPop()) {
            return;
          }
          navigator.maybePop();
        },
        child: Navigator(
          key: _navigatorKey,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const _FoldersOverviewPage(),
          ),
        ),
      ),
    );
  }
}

class _FoldersOverviewPage extends StatelessWidget {
  const _FoldersOverviewPage();

  @override
  Widget build(BuildContext context) {
    final counts = _HomeShellScope.maybeOf(context)?.badgeCounts;
    if (counts == null) {
      return const SizedBox.shrink();
    }
    final spacing = context.spacing;
    return ColoredBox(
      color: context.colorScheme.background,
      child: ListView(
        padding: EdgeInsets.only(top: spacing.s, bottom: spacing.xxl),
        children: [
          _FoldersListItem(
            folder: FolderHomeSection.important,
            badgeCount: counts.important,
          ),
          SizedBox(height: spacing.xs),
          _FoldersListItem(
            folder: FolderHomeSection.spam,
            badgeCount: counts.spam,
          ),
          SizedBox(height: spacing.s),
          const _FoldersComingSoonHint(),
        ],
      ),
    );
  }
}

class _FoldersComingSoonHint extends StatelessWidget {
  const _FoldersComingSoonHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        context.spacing.m,
        context.spacing.s,
        context.spacing.m,
        context.spacing.s,
      ),
      child: Text(
        context.l10n.homeFoldersCustomComingSoon,
        style: context.textTheme.muted,
      ),
    );
  }
}

class _FoldersListItem extends StatelessWidget {
  const _FoldersListItem({required this.folder, required this.badgeCount});

  final FolderHomeSection folder;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    final bool lowMotion = context.watch<SettingsCubit>().state.lowMotion;
    final Duration animationDuration = lowMotion
        ? Duration.zero
        : context.watch<SettingsCubit>().animationDuration;
    final shadTheme = ShadTheme.of(context);
    return OpenContainer<void>(
      closedColor: Colors.transparent,
      openColor: context.colorScheme.background,
      middleColor: context.colorScheme.background,
      closedElevation: 0,
      openElevation: 0,
      tappable: false,
      transitionDuration: animationDuration,
      useRootNavigator: false,
      closedShape: RoundedSuperellipseBorder(borderRadius: context.radius),
      openShape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      closedBuilder: (context, openContainer) {
        return _FolderListRow(
          folder: folder,
          badgeCount: badgeCount,
          expanded: false,
          onPressed: () {
            _setFoldersSection(context, folder);
            openContainer();
          },
        );
      },
      openBuilder: (context, closeContainer) => ShadTheme(
        data: shadTheme,
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: locate<HomeBloc>()),
            BlocProvider.value(value: locate<ChatsCubit>()),
            BlocProvider.value(value: locate<FoldersCubit>()),
          ],
          child: _FoldersDetailPage(folder: folder, onClose: closeContainer),
        ),
      ),
    );
  }
}

class _FoldersDetailPage extends StatelessWidget {
  const _FoldersDetailPage({required this.folder, required this.onClose});

  final FolderHomeSection folder;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final counts = _HomeShellScope.maybeOf(context)?.badgeCounts;
    if (counts == null) {
      return const SizedBox.shrink();
    }
    final content = switch (folder) {
      FolderHomeSection.important => const _HomeImportantMessagesTab(
        searchSlot: HomeSearchSlot.foldersImportant,
      ),
      FolderHomeSection.spam => const SpamList(
        searchSlot: HomeSearchSlot.foldersSpam,
      ),
    };
    final badgeCount = folder == FolderHomeSection.important
        ? counts.important
        : counts.spam;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          return;
        }
        _setFoldersSection(context, null);
      },
      child: ColoredBox(
        color: context.colorScheme.background,
        child: Column(
          children: [
            _FolderListRow(
              folder: folder,
              badgeCount: badgeCount,
              expanded: true,
              onPressed: () {
                _setFoldersSection(context, null);
                onClose();
              },
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _FolderListRow extends StatelessWidget {
  const _FolderListRow({
    required this.folder,
    required this.badgeCount,
    required this.expanded,
    required this.onPressed,
  });

  final FolderHomeSection folder;
  final int badgeCount;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    final sizing = context.sizing;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: sizing.listButtonHeight + spacing.s,
      ),
      child: AxiListButton(
        key: ValueKey<String>('home-folders-row-${folder.name}'),
        onPressed: onPressed,
        leading: Icon(folder.iconData),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeCount > 0)
              AxiCountBadge(
                key: ValueKey<String>('home-folders-badge-${folder.name}'),
                count: badgeCount,
                diameter: sizing.iconButtonIconSize,
              ),
            SizedBox(width: spacing.xs),
            AnimatedRotation(
              turns: expanded ? 0.25 : 0,
              duration: animationDuration,
              curve: Curves.easeInOutCubic,
              child: Icon(
                LucideIcons.chevronRight,
                size: sizing.menuItemIconSize,
              ),
            ),
          ],
        ),
        child: Text(folder.label(l10n), overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _HomeShellScope extends InheritedWidget {
  const _HomeShellScope({
    required this.badgeCounts,
    required this.calendarBottomDragSession,
    required this.bottomNavIndex,
    required this.foldersSection,
    required this.homeTabIndex,
    required this.selectedBottomIndex,
    required this.setBottomNavIndex,
    required this.setFoldersSection,
    required this.setHomeTabIndex,
    required this.tabs,
    required super.child,
  });

  final HomeResolvedBadgeCounts badgeCounts;
  final ValueNotifier<CalendarBottomDragSession?> calendarBottomDragSession;
  final ValueListenable<int> bottomNavIndex;
  final ValueListenable<FolderHomeSection?> foldersSection;
  final ValueListenable<int> homeTabIndex;
  final ValueListenable<int> selectedBottomIndex;
  final ValueChanged<int> setBottomNavIndex;
  final ValueChanged<FolderHomeSection?> setFoldersSection;
  final ValueChanged<int> setHomeTabIndex;
  final List<HomeTabEntry> tabs;

  static _HomeShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_HomeShellScope>();
  }

  @override
  bool updateShouldNotify(_HomeShellScope oldWidget) {
    return badgeCounts != oldWidget.badgeCounts ||
        calendarBottomDragSession != oldWidget.calendarBottomDragSession ||
        bottomNavIndex != oldWidget.bottomNavIndex ||
        foldersSection != oldWidget.foldersSection ||
        homeTabIndex != oldWidget.homeTabIndex ||
        selectedBottomIndex != oldWidget.selectedBottomIndex ||
        setBottomNavIndex != oldWidget.setBottomNavIndex ||
        setFoldersSection != oldWidget.setFoldersSection ||
        setHomeTabIndex != oldWidget.setHomeTabIndex ||
        tabs != oldWidget.tabs;
  }
}

class HomeShellCalendarScope extends StatelessWidget {
  const HomeShellCalendarScope({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final storageManager = context.watch<CalendarStorageManager>();
    final storage = storageManager.authStorage;
    final shell = MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              FoldersCubit(xmppService: context.read<XmppService>()),
        ),
        BlocProvider(
          create: (context) {
            final locate = context.read;
            return ContactsCubit(
              xmppService: locate<XmppService>(),
              emailService: locate<EmailService>(),
            );
          },
        ),
      ],
      child: HomeShell(navigationShell: navigationShell),
    );
    if (storage == null) {
      return shell;
    }
    final locate = context.read;
    return BlocProvider<CalendarBloc>(
      key: ValueKey(storage),
      create: (context) {
        final reminderController = locate<CalendarReminderController>();
        const seedDemoCalendar = kEnableDemoChats;
        final emailService =
            locate<SettingsCubit>().state.endpointConfig.smtpEnabled
            ? locate<EmailService>()
            : null;
        final calendarBloc = CalendarBloc(
          xmppService: locate<XmppService>(),
          emailService: emailService,
          reminderController: reminderController,
          syncManagerBuilder: buildPersonalCalendarSyncManager,
          storage: storage,
        );
        if (seedDemoCalendar) {
          return calendarBloc
            ..add(const CalendarEvent.started())
            ..add(
              CalendarEvent.remoteModelApplied(
                model: DemoCalendar.franklin(anchor: demoNow()),
              ),
            );
        }
        return calendarBloc..add(const CalendarEvent.started());
      },
      child: BlocListener<SettingsCubit, SettingsState>(
        listenWhen: (previous, current) =>
            previous.endpointConfig != current.endpointConfig,
        listener: (context, settings) {
          final config = settings.endpointConfig;
          locate<CalendarBloc>().updateEmailService(
            config.smtpEnabled ? locate<EmailService>() : null,
          );
        },
        child: shell,
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const int _homeBranchIndex = 0;
  static const int _profileBranchIndex = 1;
  static const int _profileBottomNavIndex = 3;
  final ValueNotifier<CalendarBottomDragSession?> _calendarBottomDragSession =
      ValueNotifier<CalendarBottomDragSession?>(null);
  final ValueNotifier<int> _bottomNavIndex = ValueNotifier<int>(0);
  final ValueNotifier<FolderHomeSection?> _foldersSection =
      ValueNotifier<FolderHomeSection?>(null);
  final ValueNotifier<int> _homeTabIndex = ValueNotifier<int>(0);
  final ValueNotifier<int> _selectedBottomIndex = ValueNotifier<int>(0);
  bool _railCollapsed = true;

  @override
  void initState() {
    super.initState();
    _bottomNavIndex.addListener(_handleBottomNavIndexSelection);
    _syncSelectedBottomIndex();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSelectedBottomIndex();
  }

  @override
  void dispose() {
    _bottomNavIndex.removeListener(_handleBottomNavIndexSelection);
    _calendarBottomDragSession.dispose();
    _bottomNavIndex.dispose();
    _foldersSection.dispose();
    _homeTabIndex.dispose();
    _selectedBottomIndex.dispose();
    super.dispose();
  }

  void _closeChatsForPrimaryHomeSelection() {
    if (EnvScope.of(context).navPlacement != NavPlacement.bottom) {
      return;
    }
    context.read<ChatsCubit>().closeAllChats();
  }

  void _handleBottomNavIndexSelection() {
    if (!mounted) {
      return;
    }
    _syncSelectedBottomIndex();
    final index = _bottomNavIndex.value;
    assert(index >= 0 && index <= 2, 'bottom nav index must be 0..2');
    if (index < 0 || index > 2) {
      _bottomNavIndex.value = index.clamp(0, 2).toInt();
      return;
    }
    if (widget.navigationShell.currentIndex != _homeBranchIndex) {
      return;
    }
    if (index == 0) {
      _closeChatsForPrimaryHomeSelection();
    }
  }

  int _selectedBottomNavIndex(int homeIndex) {
    if (widget.navigationShell.currentIndex == _profileBranchIndex) {
      return _profileBottomNavIndex;
    }
    return homeIndex.clamp(0, 2).toInt();
  }

  void _syncSelectedBottomIndex([int? nextIndex]) {
    final selectedIndex =
        nextIndex ?? _selectedBottomNavIndex(_bottomNavIndex.value);
    if (_selectedBottomIndex.value == selectedIndex) {
      return;
    }
    _selectedBottomIndex.value = selectedIndex;
  }

  void _setBottomNavIndexValue(int index) {
    final safeIndex = index.clamp(0, 2).toInt();
    if (_bottomNavIndex.value == safeIndex) {
      return;
    }
    _bottomNavIndex.value = safeIndex;
  }

  void _setFoldersSectionValue(FolderHomeSection? section) {
    if (_foldersSection.value == section) {
      return;
    }
    _foldersSection.value = section;
  }

  void _setHomeTabIndexValue(int index) {
    final safeIndex = math.max(0, index);
    if (_homeTabIndex.value == safeIndex) {
      return;
    }
    _homeTabIndex.value = safeIndex;
  }

  void _onBottomNavSelected(int index) {
    assert(index >= 0 && index <= 3, 'bottom nav index must be 0..3');
    if (index < 0 || index > 3) {
      return;
    }
    if (index == _profileBottomNavIndex) {
      if (widget.navigationShell.currentIndex == _profileBranchIndex) {
        return;
      }
      _syncSelectedBottomIndex(_profileBottomNavIndex);
      widget.navigationShell.goBranch(_profileBranchIndex);
      return;
    }
    final safeIndex = index.clamp(0, 2).toInt();
    if (_bottomNavIndex.value != safeIndex) {
      _bottomNavIndex.value = safeIndex;
    }
    _syncSelectedBottomIndex(safeIndex);
    if (widget.navigationShell.currentIndex != _homeBranchIndex) {
      widget.navigationShell.goBranch(_homeBranchIndex);
      if (safeIndex == 0) {
        _closeChatsForPrimaryHomeSelection();
      }
      return;
    }
    if (safeIndex == 0) {
      _closeChatsForPrimaryHomeSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final navPlacement = EnvScope.of(context).navPlacement;
    final storageManager = context.watch<CalendarStorageManager>();
    final calendarAvailable = storageManager.isAuthStorageReady;
    final chatsState = context.watch<ChatsCubit>().state;
    final chatItems = chatsState.items ?? const <m.Chat>[];
    final isChatOpen = chatsState.openJid != null;
    final isChatCalendarRoute = chatsState.openChatRoute.isCalendar;
    final showDesktopPrimaryActions = navPlacement == NavPlacement.rail;
    final tabs = <HomeTabEntry>[
      HomeTabEntry(
        id: HomeTab.chats,
        label: l10n.homeTabChats,
        body: ChatsList(
          key: const PageStorageKey('Chats'),
          showCalendarShortcut: navPlacement != NavPlacement.rail,
          calendarAvailable: calendarAvailable,
        ),
        fab: const _TabActionGroup(includePrimaryActions: true),
        searchFilters: chatsSearchFilters(l10n),
      ),
      HomeTabEntry(
        id: HomeTab.contacts,
        label: l10n.homeTabContacts,
        body: const ContactsList(key: PageStorageKey('Contacts')),
        fab: const ContactsAddButton(),
      ),
      HomeTabEntry(
        id: HomeTab.drafts,
        label: l10n.homeTabDrafts,
        body: const DraftsList(key: PageStorageKey('Drafts')),
        fab: showDesktopPrimaryActions
            ? const _TabActionGroup(includePrimaryActions: true)
            : null,
        searchFilters: _draftsSearchFilters(l10n),
      ),
      HomeTabEntry(
        id: HomeTab.folders,
        label: l10n.homeTabFolders,
        body: const _FoldersTab(),
        fab: showDesktopPrimaryActions
            ? const _TabActionGroup(includePrimaryActions: true)
            : null,
      ),
    ];
    final initialTabFilters = <HomeTab, SearchFilterId?>{
      for (final entry in tabs)
        if (entry.searchFilters.isNotEmpty)
          entry.id: entry.searchFilters.first.id,
    };
    Widget buildShellChild(
      Widget Function(BuildContext, HomeResolvedBadgeCounts) builder,
    ) {
      return _HomeBlocScope(
        tabs: tabs,
        initialFilters: initialTabFilters,
        child: Builder(
          builder: (context) {
            final locate = context.read;
            return BlocProvider(
              create: (context) {
                return AccessibilityActionBloc(
                  chatsService: locate<XmppService>(),
                  messageService: locate<XmppService>(),
                  rosterService: locate<XmppService>() as RosterService,
                );
              },
              child: HomeBadgeCoordinator(
                chatItems: chatItems,
                builder: (context, badgeCounts) => _HomeShellScope(
                  badgeCounts: badgeCounts,
                  calendarBottomDragSession: _calendarBottomDragSession,
                  bottomNavIndex: _bottomNavIndex,
                  foldersSection: _foldersSection,
                  homeTabIndex: _homeTabIndex,
                  selectedBottomIndex: _selectedBottomIndex,
                  setBottomNavIndex: _setBottomNavIndexValue,
                  setFoldersSection: _setFoldersSectionValue,
                  setHomeTabIndex: _setHomeTabIndexValue,
                  tabs: tabs,
                  child: builder(context, badgeCounts),
                ),
              ),
            );
          },
        ),
      );
    }

    if (navPlacement != NavPlacement.bottom) {
      return buildShellChild(
        (context, badgeCounts) => ValueListenableBuilder<int>(
          valueListenable: _bottomNavIndex,
          builder: (context, homeBottomIndex, _) {
            final selectedBottomIndex = _selectedBottomNavIndex(
              homeBottomIndex,
            );
            return _HomeShellRailLayout(
              tabs: tabs,
              homeTabIndex: _homeTabIndex,
              bottomNavIndex: _bottomNavIndex,
              onHomeTabSelected: _setHomeTabIndexValue,
              selectedBottomIndex: selectedBottomIndex,
              calendarAvailable: calendarAvailable,
              collapsed: _railCollapsed,
              badgeCounts: badgeCounts.tabs,
              onBottomNavSelected: _onBottomNavSelected,
              onCollapsedChanged: (value) {
                setState(() {
                  _railCollapsed = value;
                });
              },
              child: widget.navigationShell,
            );
          },
        ),
      );
    }

    return buildShellChild(
      (context, badgeCounts) => ValueListenableBuilder<int>(
        valueListenable: _bottomNavIndex,
        builder: (context, homeBottomIndex, _) {
          return ValueListenableBuilder<int>(
            valueListenable: composeScreenRouteDepth,
            builder: (context, composeRouteDepth, _) {
              final safeSelectedBottomIndex = _selectedBottomNavIndex(
                homeBottomIndex,
              );
              final hideBottomBarForChat =
                  isChatOpen &&
                  safeSelectedBottomIndex == 0 &&
                  !isChatCalendarRoute;
              final keyboardVisible =
                  MediaQuery.viewInsetsOf(context).bottom > 0;
              final composeRouteVisible = composeRouteDepth > 0;
              final hideBottomBar =
                  hideBottomBarForChat ||
                  keyboardVisible ||
                  composeRouteVisible;
              final removeBranchBottomPadding =
                  !hideBottomBar || keyboardVisible;
              return Column(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final mediaQuery = MediaQuery.of(context);
                        return MediaQuery(
                          data: mediaQuery.removePadding(
                            removeBottom: removeBranchBottomPadding,
                          ),
                          child: widget.navigationShell,
                        );
                      },
                    ),
                  ),
                  if (!hideBottomBar)
                    _HomeShellBottomBar(
                      calendarBottomDragSession: _calendarBottomDragSession,
                      homeBadgeCount: badgeCounts.home,
                      selectedBottomIndex: safeSelectedBottomIndex,
                      onBottomNavSelected: _onBottomNavSelected,
                      calendarAvailable: calendarAvailable,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

String? _resolveWelcomeChatJid(List<m.Chat> items) {
  for (final chat in items) {
    if (chat.isAxichatWelcomeThread) {
      return chat.jid;
    }
  }
  return null;
}

enum HomeSecondaryPaneKind { none, openChat, welcomeFallback }

@immutable
final class HomeSecondaryPane {
  const HomeSecondaryPane.none()
    : kind = HomeSecondaryPaneKind.none,
      jid = null;

  const HomeSecondaryPane.openChat(this.jid)
    : kind = HomeSecondaryPaneKind.openChat;

  const HomeSecondaryPane.welcomeFallback(this.jid)
    : kind = HomeSecondaryPaneKind.welcomeFallback;

  final HomeSecondaryPaneKind kind;
  final String? jid;

  bool get hasChatPane => jid != null;

  bool get syncWithOpenChatRoute => kind == HomeSecondaryPaneKind.openChat;

  String get scopeKey => switch (kind) {
    HomeSecondaryPaneKind.none => 'none',
    HomeSecondaryPaneKind.openChat => 'open:$jid',
    HomeSecondaryPaneKind.welcomeFallback => 'welcome:$jid',
  };
}

@visibleForTesting
HomeSecondaryPane resolveHomeSecondaryPane({
  required String? openJid,
  required NavPlacement navPlacement,
  required List<m.Chat> items,
}) {
  final trimmedOpenJid = openJid?.trim();
  if (trimmedOpenJid != null && trimmedOpenJid.isNotEmpty) {
    return HomeSecondaryPane.openChat(trimmedOpenJid);
  }
  if (navPlacement == NavPlacement.bottom) {
    return const HomeSecondaryPane.none();
  }
  final welcomeJid = _resolveWelcomeChatJid(items)?.trim();
  if (welcomeJid == null || welcomeJid.isEmpty) {
    return const HomeSecondaryPane.none();
  }
  return HomeSecondaryPane.welcomeFallback(welcomeJid);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _shareFileSchemePrefix = 'file://';
  static const String _emptyShareBody = '';
  static const List<String> _emptyShareJids = [''];
  static const int _shareAttachmentUnknownSizeBytes = 0;
  static const int _shareAttachmentMinSizeBytes = 1;

  final FocusNode _shortcutFocusNode = FocusNode(debugLabel: 'home_shortcuts');
  bool _railCollapsed = true;
  final StreamController<void> _shareIntentRequests = StreamController<void>(
    sync: true,
  );
  late final StreamSubscription<void> _shareIntentRequestSubscription =
      _shareIntentRequests.stream
          .asyncMap((_) {
            return fireAndForget(
              _handleShareIntent,
              operationName: 'HomeScreen.handleShareIntent',
              loggerName: 'HomeScreen',
            );
          })
          .listen((_) {});
  LocalHistoryEntry? _openChatHistoryEntry;
  LocalHistoryEntry? _openCalendarHistoryEntry;
  ValueListenable<int>? _bottomNavIndexNotifier;
  final ValueNotifier<bool> _calendarCanHandleBack = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _calendarCanHandleBack.addListener(_handleCalendarCanHandleBackChanged);
  }

  @override
  void dispose() {
    unawaited(_shareIntentRequestSubscription.cancel());
    unawaited(_shareIntentRequests.close());
    _shortcutFocusNode.dispose();
    _clearOpenChatHistoryEntry();
    _clearOpenCalendarHistoryEntry();
    _bottomNavIndexNotifier?.removeListener(_handleBottomNavIndexChanged);
    _bottomNavIndexNotifier = null;
    _calendarCanHandleBack.removeListener(_handleCalendarCanHandleBackChanged);
    _calendarCanHandleBack.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  void _handleOpenChatHistoryRemoved() {
    if (_openChatHistoryEntry == null) {
      return;
    }
    _openChatHistoryEntry = null;
    if (!mounted) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final locate = context.read;
    final chatsState = locate<ChatsCubit>().state;
    if (chatsState.openStack.skip(1).isNotEmpty) {
      locate<ChatsCubit>().popChat();
      return;
    }
    locate<ChatsCubit>().closeAllChats();
  }

  void _clearOpenChatHistoryEntry() {
    final entry = _openChatHistoryEntry;
    _openChatHistoryEntry = null;
    entry?.remove();
  }

  void _updateOpenChatHistoryEntry(ChatsState state) {
    final route = ModalRoute.of(context);
    if (route == null || state.openStack.isEmpty || _isPrimaryCalendarActive) {
      _clearOpenChatHistoryEntry();
      return;
    }
    if (_openChatHistoryEntry != null) {
      return;
    }
    final entry = LocalHistoryEntry(onRemove: _handleOpenChatHistoryRemoved);
    _openChatHistoryEntry = entry;
    route.addLocalHistoryEntry(entry);
  }

  void _handleOpenCalendarHistoryRemoved() {
    if (_openCalendarHistoryEntry == null) {
      return;
    }
    _openCalendarHistoryEntry = null;
    if (!mounted) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final notifier = _bottomNavIndexNotifier;
    if (notifier == null) {
      return;
    }
    final index = notifier.value.clamp(0, 3).toInt();
    if (index == 1 || index == 2) {
      _HomeShellScope.maybeOf(context)?.setBottomNavIndex(0);
    }
  }

  void _clearOpenCalendarHistoryEntry() {
    final entry = _openCalendarHistoryEntry;
    _openCalendarHistoryEntry = null;
    entry?.remove();
  }

  void _updateOpenCalendarHistoryEntry() {
    final route = ModalRoute.of(context);
    if (route == null ||
        !_isPrimaryCalendarActive ||
        _calendarCanHandleBack.value) {
      _clearOpenCalendarHistoryEntry();
      return;
    }
    if (_openCalendarHistoryEntry != null) {
      return;
    }
    final entry = LocalHistoryEntry(
      onRemove: _handleOpenCalendarHistoryRemoved,
    );
    _openCalendarHistoryEntry = entry;
    route.addLocalHistoryEntry(entry);
  }

  bool get _isPrimaryCalendarActive {
    final notifier = _bottomNavIndexNotifier;
    if (notifier == null) {
      return false;
    }
    final int index = notifier.value.clamp(0, 3).toInt();
    return index == 1 || index == 2;
  }

  void _handleBottomNavIndexChanged() {
    if (!mounted) {
      return;
    }
    if (!_isPrimaryCalendarActive && _calendarCanHandleBack.value) {
      _calendarCanHandleBack.value = false;
    }
    final locate = context.read;
    _syncHomeHistoryEntries(locate<ChatsCubit>().state);
  }

  void _handleCalendarCanHandleBackChanged() {
    if (!mounted) {
      return;
    }
    final locate = context.read;
    _syncHomeHistoryEntries(locate<ChatsCubit>().state);
  }

  void _syncHomeHistoryEntries(ChatsState state) {
    _updateOpenChatHistoryEntry(state);
    _updateOpenCalendarHistoryEntry();
  }

  void _queueShareIntentHandling() {
    if (_shareIntentRequests.isClosed) {
      return;
    }
    _shareIntentRequests.add(null);
  }

  Future<void> _handleShareIntent() async {
    if (!mounted) {
      return;
    }
    final shareState = context.read<ShareIntentCubit>().state;
    if (shareState.hasPayload != true) {
      return;
    }
    final payload = shareState.payload;
    if (payload == null) {
      return;
    }
    final String resolvedBody = payload.text?.trim() ?? _emptyShareBody;
    final bool hasBody = resolvedBody.isNotEmpty;
    final messageService = context.read<XmppService>();
    final List<String> attachmentMetadataIds = await _persistSharedAttachments(
      messageService: messageService,
      attachments: payload.attachments,
    );
    if (!mounted) {
      return;
    }
    if (!hasBody && attachmentMetadataIds.isEmpty) {
      await _consumeSharePayload(payload);
      return;
    }
    openComposeDraft(
      context,
      body: resolvedBody,
      jids: _emptyShareJids,
      attachmentMetadataIds: attachmentMetadataIds,
    );
    await _consumeSharePayload(payload);
  }

  Future<void> _consumeSharePayload(SharePayload payload) async {
    final shareCubit = context.read<ShareIntentCubit>();
    if (!identical(shareCubit.state.payload, payload)) {
      return;
    }
    await shareCubit.consume();
  }

  Future<List<String>> _persistSharedAttachments({
    required MessageService messageService,
    required List<ShareAttachmentPayload> attachments,
  }) async {
    final List<Attachment> prepared = await _prepareSharedAttachments(
      attachments: attachments,
      optimize: true,
    );
    if (prepared.isEmpty) {
      return const <String>[];
    }
    return messageService.persistDraftAttachmentMetadata(prepared);
  }

  Future<List<Attachment>> _prepareSharedAttachments({
    required List<ShareAttachmentPayload> attachments,
    required bool optimize,
  }) async {
    if (attachments.isEmpty) {
      return const <Attachment>[];
    }
    final List<Attachment> prepared = <Attachment>[];
    for (final ShareAttachmentPayload attachment in attachments) {
      final String normalizedPath = _normalizeSharedAttachmentPath(
        attachment.path,
      );
      if (normalizedPath.isEmpty) {
        continue;
      }
      final File file = File(normalizedPath);
      final entityType = await FileSystemEntity.type(
        normalizedPath,
        followLinks: false,
      );
      if (entityType != FileSystemEntityType.file || !await file.exists()) {
        continue;
      }
      final String fileName = _resolveSharedAttachmentFileName(normalizedPath);
      final int sizeBytes = await _resolveSharedAttachmentSizeBytes(file);
      final int resolvedSizeBytes = sizeBytes >= _shareAttachmentMinSizeBytes
          ? sizeBytes
          : _shareAttachmentUnknownSizeBytes;
      final String mimeType = await _resolveSharedAttachmentMimeType(
        fileName: fileName,
        path: normalizedPath,
        attachment: attachment,
      );
      Attachment attachmentValue = Attachment(
        path: normalizedPath,
        fileName: fileName,
        sizeBytes: resolvedSizeBytes,
        mimeType: mimeType,
      );
      if (optimize) {
        attachmentValue = await EmailAttachmentOptimizer.optimize(
          attachmentValue,
        );
      }
      prepared.add(attachmentValue);
    }
    return List<Attachment>.unmodifiable(prepared);
  }

  String _normalizeSharedAttachmentPath(String path) {
    final String trimmed = path.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    if (!trimmed.startsWith(_shareFileSchemePrefix)) {
      return trimmed;
    }
    final String? resolved = Uri.tryParse(trimmed)?.toFilePath();
    if (resolved == null || resolved.isEmpty) {
      return trimmed;
    }
    return resolved;
  }

  String _resolveSharedAttachmentFileName(String path) {
    final String baseName = p.basename(path);
    if (baseName.isNotEmpty) {
      return baseName;
    }
    return path;
  }

  Future<String> _resolveSharedAttachmentMimeType({
    required String fileName,
    required String path,
    required ShareAttachmentPayload attachment,
  }) async {
    final String? resolvedMimeType = await resolveMimeTypeFromPath(
      path: path,
      fileName: fileName,
      declaredMimeType: attachment.type.mimeTypeFallback,
    );
    return resolvedMimeType ?? attachment.type.mimeTypeFallback;
  }

  Future<int> _resolveSharedAttachmentSizeBytes(File file) async {
    try {
      return await file.length();
    } on Exception {
      return _shareAttachmentUnknownSizeBytes;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextBottomNav = _HomeShellScope.maybeOf(context)?.bottomNavIndex;
    if (_bottomNavIndexNotifier != nextBottomNav) {
      _bottomNavIndexNotifier?.removeListener(_handleBottomNavIndexChanged);
      _bottomNavIndexNotifier = nextBottomNav;
      _bottomNavIndexNotifier?.addListener(_handleBottomNavIndexChanged);
    }
    final locate = context.read;
    final chatsState = locate<ChatsCubit>().state;
    _syncHomeHistoryEntries(chatsState);
    _queueShareIntentHandling();
  }

  KeyEventResult _handleHomeKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isFindActionEvent(event)) return KeyEventResult.ignored;
    final locate = context.read;
    locate<AccessibilityActionBloc>().add(const AccessibilityMenuOpened());
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final storageManager = context.watch<CalendarStorageManager>();
    final homeTabIndex = _HomeShellScope.maybeOf(context)?.homeTabIndex;
    final bottomNavIndex = _HomeShellScope.maybeOf(context)?.bottomNavIndex;
    final calendarBottomDragSession = _HomeShellScope.maybeOf(
      context,
    )?.calendarBottomDragSession;
    final tabs =
        _HomeShellScope.maybeOf(context)?.tabs ?? const <HomeTabEntry>[];
    return BlocListener<ShareIntentCubit, ShareIntentState>(
      listener: (context, _) {
        _queueShareIntentHandling();
      },
      child: _HomeExitPopGuard(
        homeTabIndex: homeTabIndex,
        bottomNavIndex: bottomNavIndex,
        child: _HomeContent(
          storageManager: storageManager,
          shortcutFocusNode: _shortcutFocusNode,
          bottomNavIndex: bottomNavIndex,
          calendarCanHandleBack: _calendarCanHandleBack,
          calendarBottomDragSession: calendarBottomDragSession,
          tabs: tabs,
          railCollapsed: _railCollapsed,
          onToggleNavRail: () {
            setState(() {
              _railCollapsed = !_railCollapsed;
            });
          },
          onRailCollapsedChanged: (value) {
            setState(() {
              _railCollapsed = value;
            });
          },
          onSyncHomeHistoryEntries: _syncHomeHistoryEntries,
          onHomeKeyEvent: _handleHomeKeyEvent,
        ),
      ),
    );
  }
}

class _HomeExitPopGuard extends StatelessWidget {
  const _HomeExitPopGuard({
    required this.homeTabIndex,
    required this.bottomNavIndex,
    required this.child,
  });

  final ValueListenable<int>? homeTabIndex;
  final ValueListenable<int>? bottomNavIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final homeNotifier = homeTabIndex;
    if (homeNotifier == null) {
      return child;
    }
    return ValueListenableBuilder<int>(
      valueListenable: homeNotifier,
      builder: (context, activeIndex, _) {
        final bottomNotifier = bottomNavIndex;
        final content =
            BlocSelector<
              ChatsCubit,
              ChatsState,
              ({bool hasOpenChatStack, bool openChatOnPrimaryRoute})
            >(
              selector: (state) => (
                hasOpenChatStack: state.openStack.isNotEmpty,
                openChatOnPrimaryRoute:
                    state.openStack.isNotEmpty && state.openChatRoute.isMain,
              ),
              builder: (context, chatNavigationState) {
                final hasOpenChatStack = chatNavigationState.hasOpenChatStack;
                final openChatOnPrimaryRoute =
                    chatNavigationState.openChatOnPrimaryRoute;
                final selectedBottomIndex = bottomNotifier?.value ?? 0;
                final bool isPrimaryCalendar =
                    selectedBottomIndex == 1 || selectedBottomIndex == 2;
                final canPop =
                    isPrimaryCalendar ||
                    (!openChatOnPrimaryRoute && activeIndex == 0);
                return PopScope(
                  canPop: canPop,
                  onPopInvokedWithResult: (didPop, _) {
                    if (didPop || canPop) {
                      return;
                    }
                    final locate = context.read;
                    if (openChatOnPrimaryRoute && hasOpenChatStack) {
                      final chatsState = locate<ChatsCubit>().state;
                      if (chatsState.openStack.skip(1).isNotEmpty) {
                        locate<ChatsCubit>().popChat();
                        return;
                      }
                      locate<ChatsCubit>().closeAllChats();
                      return;
                    }
                    if (homeNotifier.value != 0) {
                      _HomeShellScope.maybeOf(context)?.setHomeTabIndex(0);
                    }
                  },
                  child: child,
                );
              },
            );
        if (bottomNotifier == null) {
          return content;
        }
        return ValueListenableBuilder<int>(
          valueListenable: bottomNotifier,
          builder: (context, _, child) => content,
        );
      },
    );
  }
}

class _HomeCoordinatorBridge extends StatelessWidget {
  const _HomeCoordinatorBridge({required this.storage, required this.child});

  final Storage? storage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (storage == null) {
      return child;
    }
    final chatCoordinator = context
        .select<CalendarBloc, ChatCalendarSyncCoordinator?>(
          (stateOwner) => stateOwner.chatCalendarCoordinator,
        );
    final availabilityCoordinator = context
        .select<CalendarBloc, CalendarAvailabilityShareCoordinator?>(
          (stateOwner) => stateOwner.availabilityCoordinator,
        );
    return MultiRepositoryProvider(
      providers: [
        if (chatCoordinator != null)
          RepositoryProvider<ChatCalendarSyncCoordinator>.value(
            value: chatCoordinator,
          ),
        if (availabilityCoordinator != null)
          RepositoryProvider<CalendarAvailabilityShareCoordinator>.value(
            value: availabilityCoordinator,
          ),
      ],
      child: child,
    );
  }
}

class _HomeTabIndexSync extends StatefulWidget {
  const _HomeTabIndexSync({required this.child});

  final Widget child;

  @override
  State<_HomeTabIndexSync> createState() => _HomeTabIndexSyncState();
}

class _HomeTabIndexSyncState extends State<_HomeTabIndexSync> {
  ValueListenable<int>? _homeTabIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = _HomeShellScope.maybeOf(context)?.homeTabIndex;
    if (notifier != _homeTabIndex) {
      _homeTabIndex?.removeListener(_handleHomeTabIndexChange);
      _homeTabIndex = notifier;
      _homeTabIndex?.addListener(_handleHomeTabIndexChange);
    }
    _handleHomeTabIndexChange();
  }

  @override
  void dispose() {
    _homeTabIndex?.removeListener(_handleHomeTabIndexChange);
    super.dispose();
  }

  void _handleHomeTabIndexChange() {
    final notifier = _homeTabIndex;
    if (notifier == null) {
      return;
    }
    final controller = DefaultTabController.maybeOf(context);
    if (controller == null || controller.length == 0) {
      return;
    }
    final index = notifier.value.clamp(0, controller.length - 1);
    if (controller.index == index) {
      return;
    }
    controller.animateTo(index);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class HomeBadgeCoordinator extends StatelessWidget {
  const HomeBadgeCoordinator({
    super.key,
    required this.chatItems,
    required this.builder,
  });

  final List<m.Chat> chatItems;
  final Widget Function(BuildContext, HomeResolvedBadgeCounts) builder;

  int _chatsUnreadCount() {
    return chatItems
        .where((chat) => !chat.archived && !chat.spam && !chat.hidden)
        .fold<int>(0, (sum, chat) => sum + math.max(0, chat.unreadCount));
  }

  HomeResolvedBadgeCounts _resolveBadgeCounts() {
    return _homeResolvedBadgeCounts(chatsUnreadCount: _chatsUnreadCount());
  }

  @override
  Widget build(BuildContext context) => builder(context, _resolveBadgeCounts());
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.storageManager,
    required this.shortcutFocusNode,
    required this.bottomNavIndex,
    required this.calendarCanHandleBack,
    required this.calendarBottomDragSession,
    required this.tabs,
    required this.railCollapsed,
    required this.onToggleNavRail,
    required this.onRailCollapsedChanged,
    required this.onSyncHomeHistoryEntries,
    required this.onHomeKeyEvent,
  });

  final CalendarStorageManager storageManager;
  final FocusNode shortcutFocusNode;
  final ValueListenable<int>? bottomNavIndex;
  final ValueNotifier<bool> calendarCanHandleBack;
  final ValueNotifier<CalendarBottomDragSession?>? calendarBottomDragSession;
  final List<HomeTabEntry> tabs;
  final bool railCollapsed;
  final VoidCallback onToggleNavRail;
  final ValueChanged<bool> onRailCollapsedChanged;
  final ValueChanged<ChatsState> onSyncHomeHistoryEntries;
  final KeyEventResult Function(FocusNode, KeyEvent) onHomeKeyEvent;

  int _normalizeBottomNavIndex(int index) => index.clamp(0, 3).toInt();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = context.watch<SettingsCubit>().state;
    final endpointConfig = settings.endpointConfig;
    final bool emailEnabled = endpointConfig.smtpEnabled;
    final env = EnvScope.of(context);
    final navPlacement = env.navPlacement;
    final Storage? calendarStorage = storageManager.authStorage;
    final bool hasCalendarBloc = storageManager.isAuthStorageReady;
    final String? openJid = context.select<ChatsCubit, String?>(
      (cubit) => cubit.state.openJid,
    );
    final chatItems = context.select<ChatsCubit, List<m.Chat>>(
      (cubit) => cubit.state.items ?? const <m.Chat>[],
    );
    final pane = resolveHomeSecondaryPane(
      openJid: openJid,
      navPlacement: navPlacement,
      items: chatItems,
    );
    if (tabs.isEmpty) {
      return Scaffold(body: Center(child: Text(l10n.homeNoModules)));
    }
    return Builder(
      builder: (context) {
        final badgeCounts =
            _HomeShellScope.maybeOf(context)?.badgeCounts ??
            const HomeResolvedBadgeCounts();

        final Widget mainContent = BlocListener<ChatsCubit, ChatsState>(
          listenWhen: (previous, current) =>
              previous.openStack != current.openStack,
          listener: (context, state) => onSyncHomeHistoryEntries(state),
          child: KeyboardPopScope(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ConnectivityIndicator(reserveTopInsetWhenHidden: true),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: BlocBuilder<ConnectivityCubit, ConnectivityState>(
                      builder: (context, state) {
                        final chatsState = context.watch<ChatsCubit>().state;
                        final chatRoute = chatsState.openChatRoute;
                        final Widget chatPane = Align(
                          alignment: Alignment.topLeft,
                          child: _HomeSecondaryChatPane(
                            pane: pane,
                            settings: settings,
                            emailEnabled: emailEnabled,
                          ),
                        );

                        Widget chatLayout({required bool showChatCalendar}) {
                          final Widget content = Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: AxiAdaptiveLayout(
                                  invertPriority: pane.hasChatPane,
                                  showPrimary: !showChatCalendar,
                                  centerSecondary: false,
                                  centerPrimary: false,
                                  animatePaneChanges: true,
                                  primaryAlignment: Alignment.topLeft,
                                  secondaryAlignment: Alignment.topLeft,
                                  primaryChild: Nexus(
                                    badgeCounts: badgeCounts.tabs,
                                    tabs: tabs,
                                    navPlacement: navPlacement,
                                    showNavigationRail:
                                        navPlacement != NavPlacement.rail,
                                    navRailCollapsed: railCollapsed,
                                    onToggleNavRail: onToggleNavRail,
                                  ),
                                  secondaryChild: chatPane,
                                ),
                              ),
                            ],
                          );
                          return content;
                        }

                        Widget calendarLayout({
                          required int? calendarTabIndex,
                          required bool surfacePopEnabled,
                        }) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child:
                                    NotificationListener<
                                      NavigationNotification
                                    >(
                                      onNotification: (notification) {
                                        if (calendarCanHandleBack.value !=
                                            notification.canHandlePop) {
                                          calendarCanHandleBack.value =
                                              notification.canHandlePop;
                                        }
                                        return false;
                                      },
                                      child: CalendarWidget(
                                        mobileTabIndex: calendarTabIndex,
                                        surfacePopEnabled: surfacePopEnabled,
                                        onMobileTabIndexChanged: (tabIndex) {
                                          final safeTab = tabIndex
                                              .clamp(0, 1)
                                              .toInt();
                                          _HomeShellScope.maybeOf(
                                            context,
                                          )?.setBottomNavIndex(
                                            safeTab == 0 ? 1 : 2,
                                          );
                                        },
                                        bottomDragSession:
                                            calendarBottomDragSession,
                                      ),
                                    ),
                              ),
                            ],
                          );
                        }

                        Widget contentForBottomIndex(int selectedBottomIndex) {
                          final bool openCalendar =
                              selectedBottomIndex == 1 ||
                              selectedBottomIndex == 2;
                          final int? calendarTabIndex = openCalendar
                              ? (selectedBottomIndex == 2 ? 1 : 0)
                              : null;
                          final bool showChatCalendar =
                              openJid != null && chatRoute.isCalendar;
                          final Widget body;
                          if (!hasCalendarBloc) {
                            body = chatLayout(
                              showChatCalendar: showChatCalendar,
                            );
                          } else {
                            body = AxiFadeIndexedStack(
                              index: openCalendar ? 1 : 0,
                              duration: Duration.zero,
                              overlapChildren: false,
                              children: [
                                chatLayout(showChatCalendar: showChatCalendar),
                                calendarLayout(
                                  calendarTabIndex: calendarTabIndex,
                                  surfacePopEnabled: openCalendar,
                                ),
                              ],
                            );
                          }
                          return SafeArea(
                            top: false,
                            bottom: navPlacement != NavPlacement.bottom,
                            child: body,
                          );
                        }

                        final bottomIndexNotifier = bottomNavIndex;
                        if (bottomIndexNotifier == null) {
                          return contentForBottomIndex(0);
                        }

                        return ValueListenableBuilder<int>(
                          valueListenable: bottomIndexNotifier,
                          builder: (context, selectedBottomIndex, _) {
                            final int safeSelectedBottomIndex =
                                _normalizeBottomNavIndex(selectedBottomIndex);
                            return contentForBottomIndex(
                              safeSelectedBottomIndex,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final Widget calendarAwareContent = hasCalendarBloc
            ? Builder(
                builder: (context) {
                  final locate = context.read;
                  final initialTasks = context
                      .select<CalendarBloc, Map<String, CalendarTask>>(
                        (stateOwner) => stateOwner.state.model.tasks,
                      );
                  return CalendarTaskFeedbackObserver<CalendarBloc>(
                    initialTasks: initialTasks,
                    onEvent: (event) => locate<CalendarBloc>().add(event),
                    child: mainContent,
                  );
                },
              )
            : mainContent;
        final shouldResizeForKeyboard =
            navPlacement != NavPlacement.bottom || pane.hasChatPane;

        final scaffold = Scaffold(
          resizeToAvoidBottomInset: shouldResizeForKeyboard,
          body: DefaultTabController(
            length: tabs.length,
            animationDuration: context.watch<SettingsCubit>().animationDuration,
            child: _HomeTabIndexSync(
              child: _HomeCoordinatorBridge(
                storage: calendarStorage,
                child: EmailForwardingWelcomeGate(child: calendarAwareContent),
              ),
            ),
          ),
        );
        return _HomeActionLayer(
          hasCalendarBloc: hasCalendarBloc,
          bottomNavIndex: bottomNavIndex,
          shortcutFocusNode: shortcutFocusNode,
          onHomeKeyEvent: onHomeKeyEvent,
          child: scaffold,
        );
      },
    );
  }
}

class _HomeBlocScope extends StatelessWidget {
  const _HomeBlocScope({
    required this.tabs,
    required this.initialFilters,
    required this.child,
  });

  final List<HomeTabEntry> tabs;
  final Map<HomeTab, SearchFilterId?> initialFilters;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final locate = context.read;
        final settings = locate<SettingsCubit>().state;
        return HomeBloc(
          xmppService: locate<XmppService>(),
          emailService: settings.endpointConfig.smtpEnabled
              ? locate<EmailService>()
              : null,
          tabs: tabs.map((tab) => tab.id).toList(growable: false),
          initialFilters: initialFilters,
        );
      },
      child: MultiBlocListener(
        listeners: [
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (previous, current) =>
                previous.endpointConfig != current.endpointConfig,
            listener: (context, settings) {
              final locate = context.read;
              final emailService = settings.endpointConfig.smtpEnabled
                  ? locate<EmailService>()
                  : null;
              locate<HomeBloc>().add(HomeEmailServiceChanged(emailService));
              locate<ContactsCubit>().updateEmailService(
                locate<EmailService>(),
              );
            },
          ),
          BlocListener<HomeBloc, HomeState>(
            listenWhen: (previous, current) =>
                previous.refreshStatus != current.refreshStatus,
            listener: (context, state) {
              final locate = context.read;
              if (state.refreshStatus.isSuccess) {
                locate<HomeBloc>().add(const HomeRefreshStatusCleared());
                return;
              }
              if (!state.refreshStatus.isFailure) {
                return;
              }
              ShadToaster.maybeOf(context)?.show(
                FeedbackToast.error(message: context.l10n.chatsRefreshFailed),
              );
              locate<HomeBloc>().add(const HomeRefreshStatusCleared());
            },
          ),
        ],
        child: child,
      ),
    );
  }
}

class _HomeSecondaryChatPane extends StatelessWidget {
  const _HomeSecondaryChatPane({
    required this.pane,
    required this.settings,
    required this.emailEnabled,
  });

  final HomeSecondaryPane pane;
  final SettingsState settings;
  final bool emailEnabled;

  @override
  Widget build(BuildContext context) {
    final resolvedJid = pane.jid;
    if (resolvedJid == null || resolvedJid.isEmpty) {
      return const SizedBox.shrink();
    }
    return MultiBlocProvider(
      key: ValueKey(pane.scopeKey),
      providers: [
        BlocProvider(
          create: (context) {
            final locate = context.read;
            final settingsSnapshot = ChatSettingsSnapshot(
              language: settings.language,
              chatReadReceipts: settings.chatReadReceipts,
              emailReadReceipts: settings.emailReadReceipts,
              shareTokenSignatureEnabled: settings.shareTokenSignatureEnabled,
              autoDownloadImages: settings.autoDownloadImages,
              autoDownloadVideos: settings.autoDownloadVideos,
              autoDownloadDocuments: settings.autoDownloadDocuments,
              autoDownloadArchives: settings.autoDownloadArchives,
            );
            return ChatBloc(
              jid: resolvedJid,
              messageService: locate<XmppService>(),
              chatsService: locate<XmppService>(),
              mucService: locate<XmppService>(),
              notificationService: locate<NotificationService>(),
              emailService: emailEnabled ? locate<EmailService>() : null,
              settings: settingsSnapshot,
            );
          },
        ),
        BlocProvider(
          create: (context) {
            final locate = context.read;
            return ChatSearchCubit(
              jid: resolvedJid,
              messageService: locate<XmppService>(),
              emailService: emailEnabled ? locate<EmailService>() : null,
            );
          },
        ),
        BlocProvider(
          create: (context) => FoldersCubit(
            xmppService: context.read<XmppService>(),
            chatJid: resolvedJid,
          ),
        ),
      ],
      child: Chat(syncWithOpenChatRoute: pane.syncWithOpenChatRoute),
    );
  }
}

class _HomeActionLayer extends StatelessWidget {
  const _HomeActionLayer({
    required this.hasCalendarBloc,
    required this.bottomNavIndex,
    required this.shortcutFocusNode,
    required this.onHomeKeyEvent,
    required this.child,
  });

  final bool hasCalendarBloc;
  final ValueListenable<int>? bottomNavIndex;
  final FocusNode shortcutFocusNode;
  final KeyEventResult Function(FocusNode, KeyEvent) onHomeKeyEvent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    final platform = EnvScope.of(context).platform;
    final isApple =
        platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
    final findActivators = findActionActivators(platform);
    final composeActivator = SingleActivator(
      LogicalKeyboardKey.keyN,
      meta: isApple,
      control: !isApple,
    );
    final searchActivator = SingleActivator(
      LogicalKeyboardKey.keyF,
      meta: isApple,
      control: !isApple,
    );
    final calendarActivator = SingleActivator(
      LogicalKeyboardKey.keyC,
      meta: isApple,
      control: !isApple,
      shift: true,
    );

    return _HomeGlobalShortcutHandler(
      child: Focus(
        focusNode: shortcutFocusNode,
        autofocus: true,
        onKeyEvent: onHomeKeyEvent,
        child: Shortcuts(
          shortcuts: {
            composeActivator: const ComposeIntent(),
            searchActivator: const ToggleSearchIntent(),
            if (EnvScope.of(context).supportsDesktopShortcuts)
              calendarActivator: const ToggleCalendarIntent(),
            for (final activator in findActivators)
              activator: const OpenFindActionIntent(),
          },
          child: Actions(
            actions: {
              ComposeIntent: CallbackAction<ComposeIntent>(
                onInvoke: (_) {
                  openComposeDraft(
                    context,
                    attachmentMetadataIds: const <String>[],
                  );
                  return null;
                },
              ),
              ToggleSearchIntent: CallbackAction<ToggleSearchIntent>(
                onInvoke: (_) {
                  final searchState = locate<HomeBloc>().state;
                  final searchPresentation = _resolveHomeSearchPresentation(
                    context,
                    tabs:
                        _HomeShellScope.maybeOf(context)?.tabs ??
                        const <HomeTabEntry>[],
                    activeTab: searchState.activeTab,
                  );
                  if (!searchPresentation.available && !searchState.active) {
                    return null;
                  }
                  locate<HomeBloc>().add(const HomeSearchToggled());
                  return null;
                },
              ),
              ToggleCalendarIntent: CallbackAction<ToggleCalendarIntent>(
                onInvoke: (_) {
                  if (!hasCalendarBloc) return null;
                  final scope = _HomeShellScope.maybeOf(context);
                  final int currentIndex = (scope?.bottomNavIndex.value ?? 0)
                      .clamp(0, 3)
                      .toInt();
                  if (currentIndex == 1 || currentIndex == 2) {
                    scope?.setBottomNavIndex(0);
                    return null;
                  }
                  scope?.setBottomNavIndex(1);
                  return null;
                },
              ),
              OpenFindActionIntent: CallbackAction<OpenFindActionIntent>(
                onInvoke: (_) {
                  locate<AccessibilityActionBloc>().add(
                    const AccessibilityMenuOpened(),
                  );
                  return null;
                },
              ),
            },
            child: Stack(
              children: [
                child,
                const Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: ComposeWindowOverlay(),
                  ),
                ),
                Positioned.fill(
                  child: _HomeOperationOverlays(bottomNavIndex: bottomNavIndex),
                ),
                const AccessibilityActionMenu(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeOperationOverlays extends StatelessWidget {
  const _HomeOperationOverlays({required this.bottomNavIndex});

  final ValueListenable<int>? bottomNavIndex;

  @override
  Widget build(BuildContext context) {
    final bottomNotifier = bottomNavIndex;
    if (bottomNotifier == null) {
      return const _VisibleHomeOperationOverlays(visible: true);
    }
    return ValueListenableBuilder<int>(
      valueListenable: bottomNotifier,
      builder: (context, selectedBottomIndex, _) {
        final int safeSelectedBottomIndex = selectedBottomIndex
            .clamp(0, 3)
            .toInt();
        return _VisibleHomeOperationOverlays(
          visible: safeSelectedBottomIndex == 0,
        );
      },
    );
  }
}

class _VisibleHomeOperationOverlays extends StatelessWidget {
  const _VisibleHomeOperationOverlays({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatsCubit, ChatsState, bool>(
      selector: (state) => state.openChatRoute.isCalendar,
      builder: (context, isChatCalendarRoute) {
        return Offstage(
          offstage: !visible || isChatCalendarRoute,
          child: const Stack(
            fit: StackFit.expand,
            children: [
              Material(
                type: MaterialType.transparency,
                child: OmemoOperationOverlay(),
              ),
              Material(
                type: MaterialType.transparency,
                child: XmppOperationOverlay(),
              ),
            ],
          ),
        );
      },
    );
  }
}

bool _isFindActionEvent(KeyEvent event) {
  if (event is! KeyDownEvent) return false;
  final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
  final hasMeta =
      pressedKeys.contains(LogicalKeyboardKey.metaLeft) ||
      pressedKeys.contains(LogicalKeyboardKey.metaRight) ||
      pressedKeys.contains(LogicalKeyboardKey.meta);
  final hasControl =
      pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
      pressedKeys.contains(LogicalKeyboardKey.controlRight) ||
      pressedKeys.contains(LogicalKeyboardKey.control);
  return event.logicalKey == LogicalKeyboardKey.keyK && (hasMeta || hasControl);
}

class _HomeGlobalShortcutHandler extends StatefulWidget {
  const _HomeGlobalShortcutHandler({required this.child});

  final Widget child;

  @override
  State<_HomeGlobalShortcutHandler> createState() =>
      _HomeGlobalShortcutHandlerState();
}

class _HomeGlobalShortcutHandlerState
    extends State<_HomeGlobalShortcutHandler> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalShortcut);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalShortcut);
    super.dispose();
  }

  bool _handleGlobalShortcut(KeyEvent event) {
    if (!_isFindActionEvent(event)) return false;
    final locate = context.read;
    locate<AccessibilityActionBloc>().add(const AccessibilityMenuOpened());
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
