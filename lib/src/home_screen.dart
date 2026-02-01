// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math' as math;

import 'package:axichat/src/accessibility/bloc/accessibility_action_bloc.dart';
import 'package:axichat/src/accessibility/view/accessibility_action_menu.dart';
import 'package:axichat/src/accessibility/view/shortcut_hint.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/view/blocklist_button.dart';
import 'package:axichat/src/blocklist/view/blocklist_list.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/storage/chat_calendar_storage.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_store.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_manager.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_coordinator.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_envelope.dart';
import 'package:axichat/src/calendar/view/calendar_widget.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_mobile_tab_host.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_mobile_tab_shell.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_task_feedback_observer.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/bloc/chat_search_cubit.dart';
import 'package:axichat/src/chat/view/chat.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/chat_selection_bar.dart';
import 'package:axichat/src/chats/view/chats_add_button.dart';
import 'package:axichat/src/chats/view/chats_filter_button.dart';
import 'package:axichat/src/chats/view/chats_list.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/keyboard_pop_scope.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/connectivity/view/connectivity_indicator.dart';
import 'package:axichat/src/demo/demo_calendar.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
import 'package:axichat/src/draft/view/draft_button.dart';
import 'package:axichat/src/draft/view/drafts_list.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/view/email_forwarding_guide.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/home/home_search_definitions.dart';
import 'package:axichat/src/home/home_search_models.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/view/session_capability_indicators.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/spam/view/spam_list.dart';
import 'package:axichat/src/storage/models.dart' as m;
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

part 'home/view/home_screen_widgets.dart';

List<HomeSearchFilter> _blocklistSearchFilters(AppLocalizations l10n) => [
      HomeSearchFilter(id: SearchFilterId.all, label: l10n.blocklistFilterAll),
    ];

List<HomeSearchFilter> _draftsSearchFilters(AppLocalizations l10n) => [
      HomeSearchFilter(id: SearchFilterId.all, label: l10n.draftsFilterAll),
      HomeSearchFilter(
        id: SearchFilterId.attachments,
        label: l10n.draftsFilterAttachments,
      ),
    ];

class HomeShellScope extends InheritedWidget {
  const HomeShellScope({
    super.key,
    required this.pendingCalendarTabIndex,
    required this.calendarTabHost,
    required this.homeTabIndex,
    required this.tabs,
    required super.child,
  });

  final ValueNotifier<int?> pendingCalendarTabIndex;
  final CalendarMobileTabHostController calendarTabHost;
  final ValueNotifier<int> homeTabIndex;
  final List<HomeTabEntry> tabs;

  static HomeShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeShellScope>();
  }

  @override
  bool updateShouldNotify(HomeShellScope oldWidget) {
    return pendingCalendarTabIndex != oldWidget.pendingCalendarTabIndex ||
        calendarTabHost != oldWidget.calendarTabHost ||
        homeTabIndex != oldWidget.homeTabIndex ||
        tabs != oldWidget.tabs;
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final ValueNotifier<int?> _pendingCalendarTabIndex =
      ValueNotifier<int?>(null);
  final CalendarMobileTabHostController _calendarTabHost =
      CalendarMobileTabHostController();
  final ValueNotifier<int> _homeTabIndex = ValueNotifier<int>(0);
  bool _railCollapsed = true;

  @override
  void dispose() {
    _pendingCalendarTabIndex.dispose();
    _calendarTabHost.dispose();
    _homeTabIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final navPlacement = EnvScope.of(context).navPlacement;
    final storageManager = context.watch<CalendarStorageManager>();
    final calendarAvailable = storageManager.isAuthStorageReady;
    final chatsState = context.watch<ChatsCubit>().state;
    final chatItems = chatsState.items ?? const <m.Chat>[];
    final badgeCounts = <HomeTab, int>{
      HomeTab.invites: context.watch<RosterCubit>().inviteCount,
      HomeTab.chats: chatItems
          .where((chat) => !chat.archived && !chat.spam)
          .fold<int>(0, (sum, chat) => sum + math.max(0, chat.unreadCount)),
      HomeTab.drafts: context.watch<DraftCubit>().state.items?.length ?? 0,
      HomeTab.spam:
          chatItems.where((chat) => chat.spam && !chat.archived).length,
    };
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
        id: HomeTab.drafts,
        label: l10n.homeTabDrafts,
        body: const DraftsList(key: PageStorageKey('Drafts')),
        fab: showDesktopPrimaryActions
            ? const _TabActionGroup(includePrimaryActions: true)
            : null,
        searchFilters: _draftsSearchFilters(l10n),
      ),
      HomeTabEntry(
        id: HomeTab.spam,
        label: l10n.homeTabSpam,
        body: const SpamList(key: PageStorageKey('Spam')),
        fab: showDesktopPrimaryActions
            ? const _TabActionGroup(includePrimaryActions: true)
            : null,
        searchFilters: spamSearchFilters(l10n),
      ),
      HomeTabEntry(
        id: HomeTab.blocked,
        label: l10n.homeTabBlocked,
        body: const BlocklistList(key: PageStorageKey('Blocked')),
        fab: const _TabActionGroup(extraActions: [BlocklistAddButton()]),
        searchFilters: _blocklistSearchFilters(l10n),
      ),
    ];

    Widget buildShellChild(Widget child) {
      return HomeShellScope(
        pendingCalendarTabIndex: _pendingCalendarTabIndex,
        calendarTabHost: _calendarTabHost,
        homeTabIndex: _homeTabIndex,
        tabs: tabs,
        child: CalendarMobileTabHostScope(
          controller: _calendarTabHost,
          child: child,
        ),
      );
    }

    if (navPlacement != NavPlacement.bottom) {
      return buildShellChild(
        _HomeShellRailLayout(
          tabs: tabs,
          homeTabIndex: _homeTabIndex,
          calendarAvailable: calendarAvailable,
          collapsed: _railCollapsed,
          badgeCounts: badgeCounts,
          onCollapsedChanged: (value) {
            setState(() {
              _railCollapsed = value;
            });
          },
          child: widget.child,
        ),
      );
    }

    return buildShellChild(
      Column(
        children: [
          Expanded(child: widget.child),
          _HomeShellBottomBar(
            pendingCalendarTabIndex: _pendingCalendarTabIndex,
            calendarTabHost: _calendarTabHost,
            calendarAvailable: calendarAvailable,
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FocusNode _shortcutFocusNode = FocusNode(debugLabel: 'home_shortcuts');
  ValueNotifier<int?>? _pendingCalendarTabIndex;
  ValueNotifier<int>? _homeTabIndex;
  bool _railCollapsed = true;
  LocalHistoryEntry? _openChatHistoryEntry;
  LocalHistoryEntry? _openCalendarHistoryEntry;
  bool Function(KeyEvent event)? _globalShortcutHandler;

  @override
  void initState() {
    super.initState();
    _globalShortcutHandler = _handleGlobalShortcut;
    HardwareKeyboard.instance.addHandler(_globalShortcutHandler!);
  }

  @override
  void dispose() {
    final handler = _globalShortcutHandler;
    if (handler != null) {
      HardwareKeyboard.instance.removeHandler(handler);
    }
    _pendingCalendarTabIndex?.removeListener(_handlePendingCalendarTabChange);
    _homeTabIndex?.removeListener(_handleHomeTabIndexChange);
    _shortcutFocusNode.dispose();
    _clearOpenChatHistoryEntry();
    _clearOpenCalendarHistoryEntry();
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
    final chatsCubit = context.read<ChatsCubit>();
    final chatsState = chatsCubit.state;
    if (chatsState.openStack.skip(1).isNotEmpty) {
      chatsCubit.popChat();
      return;
    }
    chatsCubit.closeAllChats();
  }

  void _clearOpenChatHistoryEntry() {
    final entry = _openChatHistoryEntry;
    _openChatHistoryEntry = null;
    entry?.remove();
  }

  void _updateOpenChatHistoryEntry(ChatsState state) {
    final route = ModalRoute.of(context);
    if (route == null || state.openStack.isEmpty || state.openCalendar) {
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
    final chatsCubit = context.read<ChatsCubit>();
    final chatsState = chatsCubit.state;
    if (!chatsState.openCalendar) {
      return;
    }
    chatsCubit.toggleCalendar();
  }

  void _clearOpenCalendarHistoryEntry() {
    final entry = _openCalendarHistoryEntry;
    _openCalendarHistoryEntry = null;
    entry?.remove();
  }

  void _updateOpenCalendarHistoryEntry(ChatsState state) {
    final route = ModalRoute.of(context);
    if (route == null || !state.openCalendar) {
      _clearOpenCalendarHistoryEntry();
      return;
    }
    if (_openCalendarHistoryEntry != null) {
      return;
    }
    final entry =
        LocalHistoryEntry(onRemove: _handleOpenCalendarHistoryRemoved);
    _openCalendarHistoryEntry = entry;
    route.addLocalHistoryEntry(entry);
  }

  void _syncHomeHistoryEntries(ChatsState state) {
    _updateOpenChatHistoryEntry(state);
    _updateOpenCalendarHistoryEntry(state);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chatsState = context.read<ChatsCubit>().state;
    _syncHomeHistoryEntries(chatsState);
    _updatePendingCalendarTabIndexListener();
    _updateHomeTabIndexListener();
  }

  void _updatePendingCalendarTabIndexListener() {
    final scope = HomeShellScope.maybeOf(context);
    final notifier = scope?.pendingCalendarTabIndex;
    if (notifier == _pendingCalendarTabIndex) {
      return;
    }
    _pendingCalendarTabIndex?.removeListener(_handlePendingCalendarTabChange);
    _pendingCalendarTabIndex = notifier;
    _pendingCalendarTabIndex?.addListener(_handlePendingCalendarTabChange);
    _handlePendingCalendarTabChange();
  }

  void _handlePendingCalendarTabChange() {
    final notifier = _pendingCalendarTabIndex;
    if (notifier == null || notifier.value == null) {
      return;
    }
    final chatsCubit = context.read<ChatsCubit>();
    if (!chatsCubit.state.openCalendar) {
      chatsCubit.toggleCalendar();
    }
  }

  void _updateHomeTabIndexListener() {
    final scope = HomeShellScope.maybeOf(context);
    final notifier = scope?.homeTabIndex;
    if (notifier == _homeTabIndex) {
      return;
    }
    _homeTabIndex?.removeListener(_handleHomeTabIndexChange);
    _homeTabIndex = notifier;
    _homeTabIndex?.addListener(_handleHomeTabIndexChange);
    _handleHomeTabIndexChange();
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

  KeyEventResult _handleHomeKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isFindActionEvent(event)) return KeyEventResult.ignored;
    context.read<AccessibilityActionBloc>().add(
          const AccessibilityMenuOpened(),
        );
    return KeyEventResult.handled;
  }

  bool _isFindActionEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
    final hasMeta = pressedKeys.contains(LogicalKeyboardKey.metaLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.metaRight) ||
        pressedKeys.contains(LogicalKeyboardKey.meta);
    final hasControl = pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.controlRight) ||
        pressedKeys.contains(LogicalKeyboardKey.control);
    final shouldOpen =
        event.logicalKey == LogicalKeyboardKey.keyK && (hasMeta || hasControl);
    final locate = context.read;
    return shouldOpen && !locate<AccessibilityActionBloc>().isClosed;
  }

  bool _handleGlobalShortcut(KeyEvent event) {
    if (!mounted || !_isFindActionEvent(event)) return false;
    context.read<AccessibilityActionBloc>().add(
          const AccessibilityMenuOpened(),
        );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final storageManager = context.watch<CalendarStorageManager>();
    final pendingCalendarTabIndex =
        HomeShellScope.maybeOf(context)?.pendingCalendarTabIndex;
    final tabs =
        HomeShellScope.maybeOf(context)?.tabs ?? const <HomeTabEntry>[];
    return _HomeContent(
      storageManager: storageManager,
      shortcutFocusNode: _shortcutFocusNode,
      pendingCalendarTabIndex: pendingCalendarTabIndex,
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
    );
  }
}

class _HomeCoordinatorBridge extends StatefulWidget {
  const _HomeCoordinatorBridge({
    required this.storage,
    required this.child,
  });

  final Storage? storage;
  final Widget child;

  @override
  State<_HomeCoordinatorBridge> createState() => _HomeCoordinatorBridgeState();
}

class _HomeCoordinatorBridgeState extends State<_HomeCoordinatorBridge> {
  ChatCalendarSyncCoordinator? _chatCalendarCoordinator;
  CalendarAvailabilityShareCoordinator? _availabilityCoordinator;
  Storage? _storage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureCoordinators();
  }

  @override
  void didUpdateWidget(covariant _HomeCoordinatorBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storage != widget.storage) {
      _storage = null;
      _chatCalendarCoordinator = null;
      _availabilityCoordinator = null;
    }
    _ensureCoordinators();
  }

  void _ensureCoordinators() {
    final storage = widget.storage;
    if (storage == null) {
      final storageManager = context.read<CalendarStorageManager>();
      if (storageManager.isAuthStorageReady) {
        context.read<CalendarBloc>().clearChatCalendarSyncHandler();
      }
      _chatCalendarCoordinator = null;
      _availabilityCoordinator = null;
      return;
    }
    if (_storage == storage &&
        _chatCalendarCoordinator != null &&
        _availabilityCoordinator != null) {
      final calendarBloc = context.read<CalendarBloc>();
      calendarBloc
        ..registerChatCalendarSyncHandler(_handleChatCalendarSync)
        ..attachAvailabilityCoordinator(_availabilityCoordinator!);
      return;
    }
    _storage = storage;
    final calendarBloc = context.read<CalendarBloc>();
    final chatStorage = ChatCalendarStorage(storage: storage);
    _chatCalendarCoordinator = ChatCalendarSyncCoordinator(
      storage: chatStorage,
      sendMessage: ({
        required String jid,
        required CalendarSyncOutbound outbound,
        required m.ChatType chatType,
      }) {
        return calendarBloc.sendCalendarSyncMessage(
          jid: jid,
          outbound: outbound,
          chatType: chatType,
        );
      },
      sendSnapshotFile: calendarBloc.uploadCalendarSnapshot,
    );
    _availabilityCoordinator = CalendarAvailabilityShareCoordinator(
      store: CalendarAvailabilityShareStore(),
      sendMessage: ({
        required String jid,
        required CalendarAvailabilityMessage message,
        required m.ChatType chatType,
      }) {
        return calendarBloc.sendAvailabilityMessage(
          jid: jid,
          message: message,
          chatType: chatType,
        );
      },
    );
    calendarBloc
      ..registerChatCalendarSyncHandler(_handleChatCalendarSync)
      ..attachAvailabilityCoordinator(_availabilityCoordinator!);
  }

  Future<void> _handleChatCalendarSync(
    ChatCalendarSyncEnvelope envelope,
  ) async {
    final coordinator = _chatCalendarCoordinator;
    if (coordinator == null) {
      return;
    }
    await coordinator.handleInbound(envelope);
  }

  @override
  void dispose() {
    final storageManager = context.read<CalendarStorageManager>();
    if (storageManager.isAuthStorageReady) {
      context.read<CalendarBloc>().clearChatCalendarSyncHandler();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatCoordinator = _chatCalendarCoordinator;
    final availabilityCoordinator = _availabilityCoordinator;
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
      child: widget.child,
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.storageManager,
    required this.shortcutFocusNode,
    required this.pendingCalendarTabIndex,
    required this.tabs,
    required this.railCollapsed,
    required this.onToggleNavRail,
    required this.onRailCollapsedChanged,
    required this.onSyncHomeHistoryEntries,
    required this.onHomeKeyEvent,
  });

  final CalendarStorageManager storageManager;
  final FocusNode shortcutFocusNode;
  final ValueNotifier<int?>? pendingCalendarTabIndex;
  final List<HomeTabEntry> tabs;
  final bool railCollapsed;
  final VoidCallback onToggleNavRail;
  final ValueChanged<bool> onRailCollapsedChanged;
  final ValueChanged<ChatsState> onSyncHomeHistoryEntries;
  final KeyEventResult Function(FocusNode, KeyEvent) onHomeKeyEvent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final xmppService = context.watch<XmppService>();
    final isOmemo = xmppService is OmemoService;
    final env = EnvScope.of(context);
    final navPlacement = env.navPlacement;
    final Storage? calendarStorage = storageManager.authStorage;
    final bool hasCalendarBloc = storageManager.isAuthStorageReady;
    if (tabs.isEmpty) {
      return Scaffold(body: Center(child: Text(l10n.homeNoModules)));
    }
    final initialTabFilters = <HomeTab, SearchFilterId?>{
      for (final entry in tabs)
        if (entry.searchFilters.isNotEmpty)
          entry.id: entry.searchFilters.first.id,
    };
    final Widget mainContent = Builder(
      builder: (context) {
        return BlocListener<ChatsCubit, ChatsState>(
          listenWhen: (previous, current) =>
              previous.openStack != current.openStack ||
              previous.openCalendar != current.openCalendar,
          listener: (context, state) => onSyncHomeHistoryEntries(state),
          child: KeyboardPopScope(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ConnectivityIndicator(),
                Expanded(
                  child: BlocBuilder<ConnectivityCubit, ConnectivityState>(
                    builder: (context, state) {
                      final chatsState = context.watch<ChatsCubit>().state;
                      final String? openJid = chatsState.openJid;
                      final bool openCalendar =
                          hasCalendarBloc && chatsState.openCalendar;
                      final chatRoute = chatsState.openChatRoute;
                      final Widget chatPaneContent = openJid == null
                          ? const GuestChat()
                          : MultiBlocProvider(
                              providers: [
                                BlocProvider(
                                  key: Key(openJid),
                                  create: (context) {
                                    final settings =
                                        context.read<SettingsCubit>().state;
                                    final endpointConfig = context
                                        .read<AuthenticationCubit>()
                                        .endpointConfig;
                                    final emailService =
                                        endpointConfig.enableSmtp
                                            ? context.read<EmailService>()
                                            : null;
                                    return ChatBloc(
                                      jid: openJid,
                                      messageService:
                                          context.read<XmppService>(),
                                      chatsService: context.read<XmppService>(),
                                      mucService: context.read<XmppService>(),
                                      notificationService:
                                          context.read<NotificationService>(),
                                      emailService: emailService,
                                      omemoService: isOmemo
                                          ? context.read<XmppService>()
                                              as OmemoService
                                          : null,
                                      settings: ChatSettingsSnapshot(
                                        language: settings.language,
                                        chatReadReceipts:
                                            settings.chatReadReceipts,
                                        emailReadReceipts:
                                            settings.emailReadReceipts,
                                        shareTokenSignatureEnabled:
                                            settings.shareTokenSignatureEnabled,
                                        autoDownloadImages:
                                            settings.autoDownloadImages,
                                        autoDownloadVideos:
                                            settings.autoDownloadVideos,
                                        autoDownloadDocuments:
                                            settings.autoDownloadDocuments,
                                        autoDownloadArchives:
                                            settings.autoDownloadArchives,
                                      ),
                                    );
                                  },
                                ),
                                BlocProvider(
                                  create: (context) => ChatSearchCubit(
                                    jid: openJid,
                                    messageService: context.read<XmppService>(),
                                    emailService: context
                                            .read<AuthenticationCubit>()
                                            .endpointConfig
                                            .enableSmtp
                                        ? context.read<EmailService>()
                                        : null,
                                  ),
                                ),
                                /* Verification flow temporarily disabled
                                if (isOmemo)
                                  BlocProvider(
                                    create: (context) => VerificationCubit(
                                      jid: openJid,
                                      omemoService:
                                          context.read<XmppService>()
                                              as OmemoService,
                                    ),
                                  ),
                                */
                              ],
                              child: const Chat(),
                            );
                      final Widget chatPane = Align(
                        alignment: Alignment.topLeft,
                        child: chatPaneContent,
                      );

                      Widget chatLayout({required bool showChatCalendar}) {
                        final Widget content = Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: AxiAdaptiveLayout(
                                invertPriority: openJid != null,
                                showPrimary: !showChatCalendar,
                                centerSecondary: false,
                                centerPrimary: false,
                                animatePaneChanges: true,
                                primaryAlignment: Alignment.topLeft,
                                secondaryAlignment: Alignment.topLeft,
                                primaryChild: Nexus(
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

                      Widget calendarLayout() {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: CalendarWidget(
                                pendingMobileTabIndex: pendingCalendarTabIndex,
                              ),
                            ),
                          ],
                        );
                      }

                      final bool demoOffline =
                          context.watch<XmppService>().demoOfflineMode;

                      final bool showChatCalendar =
                          openJid != null && chatRoute.isCalendar;
                      return SafeArea(
                        top: state is ConnectivityConnected || demoOffline,
                        child: openCalendar
                            ? calendarLayout()
                            : chatLayout(
                                showChatCalendar: showChatCalendar,
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    final Widget calendarAwareContent = hasCalendarBloc
        ? CalendarTaskFeedbackObserver<CalendarBloc>(child: mainContent)
        : mainContent;
    final shouldResizeForKeyboard = navPlacement != NavPlacement.bottom;

    final scaffold = Scaffold(
      resizeToAvoidBottomInset: shouldResizeForKeyboard,
      body: DefaultTabController(
        length: tabs.length,
        animationDuration: context.watch<SettingsCubit>().animationDuration,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => HomeSearchCubit(
                tabs: tabs.map((tab) => tab.id).toList(),
                initialFilters: initialTabFilters,
              ),
            ),
            BlocProvider(
              create: (context) => ProfileCubit(
                xmppService: context.read<XmppService>(),
                presenceService: context.read<XmppService>() as PresenceService,
                omemoService: isOmemo
                    ? context.read<XmppService>() as OmemoService
                    : null,
              ),
            ),
            BlocProvider(
              create: (context) =>
                  BlocklistCubit(xmppService: context.read<XmppService>()),
            ),
            // Always provide CalendarBloc for logged-in users
            if (calendarStorage != null)
              BlocProvider<CalendarBloc>(
                create: (context) {
                  final reminderController =
                      context.read<CalendarReminderController>();
                  final xmppService = context.read<XmppService>();
                  final endpointConfig =
                      context.read<AuthenticationCubit>().endpointConfig;
                  final emailService = endpointConfig.enableSmtp
                      ? context.read<EmailService>()
                      : null;
                  const bool seedDemoCalendar = kEnableDemoChats;
                  final storage = calendarStorage;

                  final CalendarBloc bloc = CalendarBloc(
                    xmppService: xmppService,
                    emailService: emailService,
                    reminderController: reminderController,
                    syncManagerBuilder: (bloc) {
                      final manager = CalendarSyncManager(
                        readModel: () => bloc.currentModel,
                        applyModel: (model) async {
                          if (bloc.isClosed) return;
                          bloc.add(
                            CalendarEvent.remoteModelApplied(model: model),
                          );
                        },
                        sendCalendarMessage: (outbound) async {
                          if (bloc.isClosed) {
                            return;
                          }
                          final jid = xmppService.myJid;
                          if (jid != null) {
                            await xmppService.sendCalendarSyncMessage(
                              jid: jid,
                              outbound: outbound,
                            );
                          }
                        },
                        sendSnapshotFile: xmppService.uploadCalendarSnapshot,
                      );

                      xmppService
                        ..setCalendarSyncCallback((inbound) async {
                          if (bloc.isClosed) return false;
                          return await manager.onCalendarMessage(inbound);
                        })
                        ..setCalendarSyncWarningCallback((warning) async {
                          if (bloc.isClosed) return;
                          bloc.add(
                            CalendarEvent.syncWarningRaised(warning: warning),
                          );
                        });
                      return manager;
                    },
                    storage: storage,
                    onDispose: () {
                      xmppService
                        ..clearCalendarSyncCallback()
                        ..clearCalendarSyncWarningCallback();
                    },
                  )..add(const CalendarEvent.started());
                  if (seedDemoCalendar) {
                    bloc.add(
                      CalendarEvent.remoteModelApplied(
                        model: DemoCalendar.franklin(anchor: demoNow()),
                      ),
                    );
                  }
                  return bloc;
                },
              ),
            BlocProvider(
              create: (context) {
                final endpointConfig =
                    context.read<AuthenticationCubit>().endpointConfig;
                return ConnectivityCubit(
                  xmppBase: context.read<XmppService>(),
                  emailEnabled: endpointConfig.enableSmtp,
                  emailService: endpointConfig.enableSmtp
                      ? context.read<EmailService>()
                      : null,
                );
              },
            ),
          ],
          child: _HomeCoordinatorBridge(
            storage: calendarStorage,
            child: EmailForwardingWelcomeGate(child: calendarAwareContent),
          ),
        ),
      ),
    );
    final actionLayer = BlocProvider(
      create: (context) {
        final bloc = AccessibilityActionBloc(
          chatsService: context.read<XmppService>(),
          messageService: context.read<XmppService>(),
          rosterService: context.read<XmppService>() as RosterService,
          initialLocalization: l10n,
        );
        return bloc;
      },
      child: Builder(
        builder: (context) {
          final platform = EnvScope.of(context).platform;
          final isApple = platform == TargetPlatform.macOS ||
              platform == TargetPlatform.iOS;
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
          return Focus(
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
                      context.read<HomeSearchCubit>().toggleSearch();
                      return null;
                    },
                  ),
                  ToggleCalendarIntent: CallbackAction<ToggleCalendarIntent>(
                    onInvoke: (_) {
                      if (!hasCalendarBloc) return null;
                      context.read<ChatsCubit>().toggleCalendar();
                      return null;
                    },
                  ),
                  OpenFindActionIntent: CallbackAction<OpenFindActionIntent>(
                    onInvoke: (_) {
                      context.read<AccessibilityActionBloc>().add(
                            const AccessibilityMenuOpened(),
                          );
                      return null;
                    },
                  ),
                },
                child: Stack(
                  children: [scaffold, const AccessibilityActionMenu()],
                ),
              ),
            ),
          );
        },
      ),
    );
    return actionLayer;
  }
}
