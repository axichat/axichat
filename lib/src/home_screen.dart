// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math' as math;

import 'package:axichat/src/accessibility/bloc/accessibility_action_bloc.dart';
import 'package:axichat/src/accessibility/view/accessibility_action_menu.dart';
import 'package:axichat/src/accessibility/view/shortcut_hint.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/view/blocklist_button.dart';
import 'package:axichat/src/blocklist/view/blocklist_list.dart';
import 'package:axichat/src/blocklist/view/blocklist_notice_l10n.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
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
import 'package:axichat/src/draft/view/compose_window.dart';
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
import 'package:axichat/src/notifications/view/omemo_operation_overlay.dart';
import 'package:axichat/src/notifications/view/xmpp_operation_overlay.dart';
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

class HomeShellCalendarScope extends StatelessWidget {
  const HomeShellCalendarScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final storageManager = context.watch<CalendarStorageManager>();
    final storage = storageManager.authStorage;
    final shell = HomeShell(child: child);
    if (storage == null) {
      return shell;
    }
    final locate = context.read;
    return BlocProvider<CalendarBloc>(
      key: ValueKey(storage),
      create: (context) {
        final reminderController = locate<CalendarReminderController>();
        final xmppService = locate<XmppService>();
        const seedDemoCalendar = kEnableDemoChats;
        final emailService =
            locate<SettingsCubit>().state.endpointConfig.smtpEnabled
                ? locate<EmailService>()
                : null;
        if (seedDemoCalendar) {
          return CalendarBloc(
            xmppService: xmppService,
            emailService: emailService,
            reminderController: reminderController,
            syncManagerBuilder: (bloc) {
              final manager = CalendarSyncManager(
                readModel: () => bloc.currentModel,
                applyModel: (model) async {
                  bloc.add(
                    CalendarEvent.remoteModelApplied(
                      model: model,
                    ),
                  );
                },
                sendCalendarMessage: (outbound) async {
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
              return manager;
            },
            storage: storage,
          )
            ..add(const CalendarEvent.started())
            ..add(
              CalendarEvent.remoteModelApplied(
                model: DemoCalendar.franklin(anchor: demoNow()),
              ),
            );
        }
        return CalendarBloc(
          xmppService: xmppService,
          emailService: emailService,
          reminderController: reminderController,
          syncManagerBuilder: (bloc) {
            final manager = CalendarSyncManager(
              readModel: () => bloc.currentModel,
              applyModel: (model) async {
                bloc.add(
                  CalendarEvent.remoteModelApplied(
                    model: model,
                  ),
                );
              },
              sendCalendarMessage: (outbound) async {
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
            return manager;
          },
          storage: storage,
        )..add(const CalendarEvent.started());
      },
      child: BlocListener<SettingsCubit, SettingsState>(
        listenWhen: (previous, current) =>
            previous.endpointConfig != current.endpointConfig,
        listener: (context, settings) {
          final config = settings.endpointConfig;
          final emailService = locate<EmailService>();
          final EmailService? activeEmailService =
              config.smtpEnabled ? emailService : null;
          locate<CalendarBloc>().updateEmailService(activeEmailService);
        },
        child: shell,
      ),
    );
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
      return BlocProvider(
        create: (context) => AccessibilityActionBloc(
          chatsService: context.read<XmppService>(),
          messageService: context.read<XmppService>(),
          rosterService: context.read<XmppService>() as RosterService,
        ),
        child: HomeShellScope(
          pendingCalendarTabIndex: _pendingCalendarTabIndex,
          calendarTabHost: _calendarTabHost,
          homeTabIndex: _homeTabIndex,
          tabs: tabs,
          child: CalendarMobileTabHostScope(
            controller: _calendarTabHost,
            child: child,
          ),
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
  bool _railCollapsed = true;
  LocalHistoryEntry? _openChatHistoryEntry;
  LocalHistoryEntry? _openCalendarHistoryEntry;

  @override
  void dispose() {
    _pendingCalendarTabIndex?.removeListener(_handlePendingCalendarTabChange);
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
    final chatsState = context.read<ChatsCubit>().state;
    if (chatsState.openStack.skip(1).isNotEmpty) {
      context.read<ChatsCubit>().popChat();
      return;
    }
    context.read<ChatsCubit>().closeAllChats();
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
    final chatsState = context.read<ChatsCubit>().state;
    if (!chatsState.openCalendar) {
      return;
    }
    context.read<ChatsCubit>().toggleCalendar();
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
    if (!context.read<ChatsCubit>().state.openCalendar) {
      context.read<ChatsCubit>().toggleCalendar();
    }
  }

  KeyEventResult _handleHomeKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isFindActionEvent(event)) return KeyEventResult.ignored;
    context.read<AccessibilityActionBloc>().add(
          const AccessibilityMenuOpened(),
        );
    return KeyEventResult.handled;
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
  StreamSubscription<ChatCalendarSyncDispatch>? _chatCalendarSyncSubscription;
  StreamSubscription<XmppStreamReady>? _streamReadySubscription;

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
      _detachChatCalendarSyncSubscription();
    }
    _ensureCoordinators();
  }

  void _ensureCoordinators() {
    final locate = context.read;
    final storage = widget.storage;
    if (storage == null) {
      _chatCalendarCoordinator = null;
      _availabilityCoordinator = null;
      _detachChatCalendarSyncSubscription();
      return;
    }
    if (_storage == storage &&
        _chatCalendarCoordinator != null &&
        _availabilityCoordinator != null) {
      locate<CalendarBloc>().attachAvailabilityCoordinator(
        _availabilityCoordinator!,
      );
      _ensureChatCalendarSyncSubscription();
      return;
    }
    _storage = storage;
    final chatStorage = ChatCalendarStorage(storage: storage);
    _chatCalendarCoordinator = ChatCalendarSyncCoordinator(
      storage: chatStorage,
      sendMessage: ({
        required String jid,
        required CalendarSyncOutbound outbound,
        required m.ChatType chatType,
      }) {
        return locate<CalendarBloc>().sendCalendarSyncMessage(
          jid: jid,
          outbound: outbound,
          chatType: chatType,
        );
      },
      sendSnapshotFile: (file) =>
          locate<CalendarBloc>().uploadCalendarSnapshot(file),
    );
    _availabilityCoordinator = CalendarAvailabilityShareCoordinator(
      store: CalendarAvailabilityShareStore(),
      sendMessage: ({
        required String jid,
        required CalendarAvailabilityMessage message,
        required m.ChatType chatType,
      }) {
        return locate<CalendarBloc>().sendAvailabilityMessage(
          jid: jid,
          message: message,
          chatType: chatType,
        );
      },
    );
    locate<CalendarBloc>().attachAvailabilityCoordinator(
      _availabilityCoordinator!,
    );
    _ensureChatCalendarSyncSubscription();
  }

  void _ensureChatCalendarSyncSubscription() {
    final coordinator = _chatCalendarCoordinator;
    if (coordinator == null) {
      _detachChatCalendarSyncSubscription();
      return;
    }
    if (_chatCalendarSyncSubscription != null) {
      return;
    }
    final locate = context.read;
    final xmppService = locate<XmppService>();
    if (xmppService.lastStreamReady == null) {
      _streamReadySubscription ??= xmppService.streamReadyStream.listen((_) {
        _ensureChatCalendarSyncSubscription();
      });
      return;
    }
    _chatCalendarSyncSubscription =
        xmppService.chatCalendarSyncDispatchStream.listen(
      (dispatch) async {
        try {
          await coordinator.handleInbound(dispatch.envelope);
          dispatch.complete();
        } catch (error, stackTrace) {
          dispatch.completeError(error, stackTrace);
        }
      },
    );
    _streamReadySubscription?.cancel();
    _streamReadySubscription = null;
  }

  void _detachChatCalendarSyncSubscription() {
    _chatCalendarSyncSubscription?.cancel();
    _chatCalendarSyncSubscription = null;
    _streamReadySubscription?.cancel();
    _streamReadySubscription = null;
  }

  @override
  void dispose() {
    _detachChatCalendarSyncSubscription();
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

class _HomeTabIndexSync extends StatefulWidget {
  const _HomeTabIndexSync({required this.child});

  final Widget child;

  @override
  State<_HomeTabIndexSync> createState() => _HomeTabIndexSyncState();
}

class _HomeTabIndexSyncState extends State<_HomeTabIndexSync> {
  ValueNotifier<int>? _homeTabIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = HomeShellScope.maybeOf(context)?.homeTabIndex;
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
    final settings = context.watch<SettingsCubit>().state;
    final endpointConfig = settings.endpointConfig;
    final bool emailEnabled = endpointConfig.smtpEnabled;

    final xmppService = context.watch<XmppService>();
    final isOmemo = xmppService is OmemoService;
    final env = EnvScope.of(context);
    final navPlacement = env.navPlacement;
    final Storage? calendarStorage = storageManager.authStorage;
    final bool hasCalendarBloc = storageManager.isAuthStorageReady;
    final String? openJid = context.select<ChatsCubit, String?>(
      (cubit) => cubit.state.openJid,
    );
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
                      final bool openCalendar =
                          hasCalendarBloc && chatsState.openCalendar;
                      final chatRoute = chatsState.openChatRoute;
                      final Widget chatPaneContent =
                          openJid == null ? const GuestChat() : const Chat();
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
        ? Builder(
            builder: (context) {
              final locate = context.read;
              final initialTasks =
                  context.select<CalendarBloc, Map<String, CalendarTask>>(
                (bloc) => bloc.state.model.tasks,
              );
              return CalendarTaskFeedbackObserver<CalendarBloc>(
                initialTasks: initialTasks,
                onEvent: (event) => locate<CalendarBloc>().add(event),
                child: mainContent,
              );
            },
          )
        : mainContent;
    final shouldResizeForKeyboard = navPlacement != NavPlacement.bottom;

    final scaffold = Scaffold(
      resizeToAvoidBottomInset: shouldResizeForKeyboard,
      body: DefaultTabController(
        length: tabs.length,
        animationDuration: context.watch<SettingsCubit>().animationDuration,
        child: _HomeTabIndexSync(
          child: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) => HomeSearchCubit(
                  tabs: tabs.map((tab) => tab.id).toList(),
                  initialFilters: initialTabFilters,
                ),
              ),
            ],
            child: _HomeCoordinatorBridge(
              storage: calendarStorage,
              child: EmailForwardingWelcomeGate(child: calendarAwareContent),
            ),
          ),
        ),
      ),
    );
    final Widget baseLayer = _HomeActionLayer(
      hasCalendarBloc: hasCalendarBloc,
      shortcutFocusNode: shortcutFocusNode,
      onHomeKeyEvent: onHomeKeyEvent,
      child: scaffold,
    );
    if (openJid == null) {
      return baseLayer;
    }
    final String resolvedJid = openJid;
    return MultiBlocProvider(
      key: ValueKey(resolvedJid),
      providers: [
        BlocProvider(
          create: (context) {
            final emailService =
                emailEnabled ? context.read<EmailService>() : null;
            return ChatBloc(
              jid: resolvedJid,
              messageService: context.read<XmppService>(),
              chatsService: context.read<XmppService>(),
              mucService: context.read<XmppService>(),
              notificationService: context.read<NotificationService>(),
              emailService: emailService,
              omemoService:
                  isOmemo ? context.read<XmppService>() as OmemoService : null,
              settings: ChatSettingsSnapshot(
                language: settings.language,
                chatReadReceipts: settings.chatReadReceipts,
                emailReadReceipts: settings.emailReadReceipts,
                shareTokenSignatureEnabled: settings.shareTokenSignatureEnabled,
                autoDownloadImages: settings.autoDownloadImages,
                autoDownloadVideos: settings.autoDownloadVideos,
                autoDownloadDocuments: settings.autoDownloadDocuments,
                autoDownloadArchives: settings.autoDownloadArchives,
              ),
            );
          },
        ),
        BlocProvider(
          create: (context) => ChatSearchCubit(
            jid: resolvedJid,
            messageService: context.read<XmppService>(),
            emailService: emailEnabled ? context.read<EmailService>() : null,
          ),
        ),
        /* Verification flow temporarily disabled
        if (isOmemo)
          BlocProvider(
            create: (context) => VerificationCubit(
              jid: openJid,
              omemoService: context.read<XmppService>() as OmemoService,
            ),
          ),
        */
      ],
      child: Builder(
        builder: (context) => _HomeActionLayer(
          hasCalendarBloc: hasCalendarBloc,
          shortcutFocusNode: shortcutFocusNode,
          onHomeKeyEvent: onHomeKeyEvent,
          chatLocate: context.read,
          child: scaffold,
        ),
      ),
    );
  }
}

class _HomeActionLayer extends StatelessWidget {
  const _HomeActionLayer({
    required this.hasCalendarBloc,
    required this.shortcutFocusNode,
    required this.onHomeKeyEvent,
    required this.child,
    this.chatLocate,
  });

  final bool hasCalendarBloc;
  final FocusNode shortcutFocusNode;
  final KeyEventResult Function(FocusNode, KeyEvent) onHomeKeyEvent;
  final Widget child;
  final T Function<T>()? chatLocate;

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
                  locate<HomeSearchCubit>().toggleSearch();
                  return null;
                },
              ),
              ToggleCalendarIntent: CallbackAction<ToggleCalendarIntent>(
                onInvoke: (_) {
                  if (!hasCalendarBloc) return null;
                  locate<ChatsCubit>().toggleCalendar();
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
                const Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: OmemoOperationOverlay(),
                  ),
                ),
                const Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: XmppOperationOverlay(),
                  ),
                ),
                AccessibilityActionMenu(chatLocate: chatLocate),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    context
        .read<AccessibilityActionBloc>()
        .add(const AccessibilityMenuOpened());
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
