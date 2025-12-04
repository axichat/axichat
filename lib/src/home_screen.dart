// ignore_for_file: unnecessary_type_check
import 'dart:async';
import 'dart:math' as math;
import 'package:axichat/src/accessibility/bloc/accessibility_action_bloc.dart';
import 'package:axichat/src/accessibility/view/accessibility_action_menu.dart';
import 'package:axichat/src/accessibility/view/shortcut_hint.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/view/blocklist_button.dart';
import 'package:axichat/src/blocklist/view/blocklist_list.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/day_event_repository.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_manager.dart';
import 'package:axichat/src/calendar/view/calendar_widget.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_task_feedback_observer.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/bloc/chat_search_cubit.dart';
import 'package:axichat/src/chat/view/chat.dart' as chat_view;
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/chat_selection_bar.dart';
import 'package:axichat/src/chats/view/chats_filter_button.dart';
import 'package:axichat/src/chats/view/chats_add_button.dart';
import 'package:axichat/src/chats/view/chats_list.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/connectivity/view/connectivity_indicator.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/draft_button.dart';
import 'package:axichat/src/draft/view/drafts_list.dart';
import 'package:axichat/src/email/bloc/email_sync_cubit.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/home/home_search_definitions.dart';
import 'package:axichat/src/home/home_search_models.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/view/profile_tile.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/spam/view/spam_list.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

List<HomeSearchFilter> _blocklistSearchFilters(AppLocalizations l10n) => [
      HomeSearchFilter(id: 'all', label: l10n.blocklistFilterAll),
    ];

List<HomeSearchFilter> _draftsSearchFilters(AppLocalizations l10n) => [
      HomeSearchFilter(id: 'all', label: l10n.draftsFilterAll),
      HomeSearchFilter(
        id: 'attachments',
        label: l10n.draftsFilterAttachments,
      ),
    ];

const double _secondaryPaneGutter = 0.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FocusNode _shortcutFocusNode = FocusNode(debugLabel: 'home_shortcuts');
  bool _railCollapsed = true;
  late final VoidCallback _focusFallbackListener;
  bool Function(KeyEvent event)? _globalShortcutHandler;

  @override
  void initState() {
    super.initState();
    _focusFallbackListener = _restoreShortcutFocusIfEmpty;
    FocusManager.instance.addListener(_focusFallbackListener);
    _globalShortcutHandler = _handleGlobalShortcut;
    HardwareKeyboard.instance.addHandler(_globalShortcutHandler!);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _shortcutFocusNode.requestFocus();
        _restoreShortcutFocusIfEmpty();
      },
    );
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusFallbackListener);
    final handler = _globalShortcutHandler;
    if (handler != null) {
      HardwareKeyboard.instance.removeHandler(handler);
    }
    WidgetsBinding.instance.removeObserver(this);
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _shortcutFocusNode.canRequestFocus) {
      _shortcutFocusNode.requestFocus();
    }
  }

  KeyEventResult _handleHomeKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isFindActionEvent(event)) return KeyEventResult.ignored;
    context
        .read<AccessibilityActionBloc?>()
        ?.add(const AccessibilityMenuOpened());
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
    return shouldOpen && locate<AccessibilityActionBloc?>()?.isClosed == false;
  }

  void _restoreShortcutFocusIfEmpty() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null ||
        primary.context == null ||
        identical(primary, FocusManager.instance.rootScope)) {
      if (_shortcutFocusNode.canRequestFocus) {
        _shortcutFocusNode.requestFocus();
      }
    }
  }

  bool _handleGlobalShortcut(KeyEvent event) {
    if (!mounted || !_isFindActionEvent(event)) return false;
    context
        .read<AccessibilityActionBloc?>()
        ?.add(const AccessibilityMenuOpened());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final isChat = context.read<XmppService>() is ChatsService;
    final isMessage = context.read<XmppService>() is MessageService;
    final isRoster = context.read<XmppService>() is RosterService;
    final isPresence = context.read<XmppService>() is PresenceService;
    final isOmemo = context.read<XmppService>() is OmemoService;
    final isBlocking = context.read<XmppService>() is BlockingService;
    final navPlacement = EnvScope.of(context).navPlacement;
    final showDesktopPrimaryActions = navPlacement == NavPlacement.rail;
    final Storage? calendarStorage = context.read<Storage?>();
    final bool hasCalendarBloc = calendarStorage != null;
    final chatsFilters = chatsSearchFilters(l10n);
    final spamFilters = spamSearchFilters(l10n);
    final draftsFilters = _draftsSearchFilters(l10n);
    final blocklistFilters = _blocklistSearchFilters(l10n);

    final tabs = <HomeTabEntry>[
      if (isChat)
        HomeTabEntry(
          id: HomeTab.chats,
          label: l10n.homeTabChats,
          body: ChatsList(
            key: const PageStorageKey('Chats'),
            showCalendarShortcut: navPlacement != NavPlacement.rail,
            calendarAvailable: hasCalendarBloc,
          ),
          fab: const _TabActionGroup(includePrimaryActions: true),
          searchFilters: chatsFilters,
        ),
      if (isMessage)
        HomeTabEntry(
          id: HomeTab.drafts,
          label: l10n.homeTabDrafts,
          body: const DraftsList(key: PageStorageKey('Drafts')),
          fab: showDesktopPrimaryActions
              ? const _TabActionGroup(includePrimaryActions: true)
              : null,
          searchFilters: draftsFilters,
        ),
      if (isChat)
        HomeTabEntry(
          id: HomeTab.spam,
          label: l10n.homeTabSpam,
          body: const SpamList(key: PageStorageKey('Spam')),
          fab: showDesktopPrimaryActions
              ? const _TabActionGroup(includePrimaryActions: true)
              : null,
          searchFilters: spamFilters,
        ),
      if (isBlocking)
        HomeTabEntry(
          id: HomeTab.blocked,
          label: l10n.homeTabBlocked,
          body: const BlocklistList(key: PageStorageKey('Blocked')),
          fab: const _TabActionGroup(
            extraActions: [BlocklistAddButton()],
          ),
          searchFilters: blocklistFilters,
        ),
    ];
    if (tabs.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(l10n.homeNoModules),
        ),
      );
    }
    final initialTabFilters = <HomeTab, String?>{
      for (final entry in tabs)
        if (entry.searchFilters.isNotEmpty)
          entry.id: entry.searchFilters.first.id,
    };
    final Widget mainContent = Builder(
      builder: (context) {
        Widget constrainSecondary(Widget child) => Align(
              alignment: Alignment.topLeft,
              child: child,
            );
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (_, __) {
            final chatsCubit = context.read<ChatsCubit?>();
            final chatsState = chatsCubit?.state;
            if (chatsState == null) return;
            if (chatsState.openCalendar) {
              chatsCubit?.toggleCalendar();
            } else if (chatsState.openStack.isNotEmpty) {
              if (chatsState.openStack.length > 1) {
                unawaited(chatsCubit?.popChat());
              } else {
                unawaited(chatsCubit?.closeAllChats());
              }
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ConnectivityIndicator(),
              Expanded(
                child: BlocBuilder<ConnectivityCubit, ConnectivityState>(
                  builder: (context, state) {
                    final ChatsState? chatsState =
                        context.watch<ChatsCubit?>()?.state;
                    final String? openJid = chatsState?.openJid;
                    final bool openCalendar =
                        hasCalendarBloc && (chatsState?.openCalendar ?? false);
                    final navRail = navPlacement == NavPlacement.rail
                        ? _HomeNavigationRail(
                            tabs: tabs,
                            selectedIndex:
                                DefaultTabController.maybeOf(context)?.index ??
                                    0,
                            collapsed: _railCollapsed,
                            onDestinationSelected: (index) {
                              final controller =
                                  DefaultTabController.maybeOf(context);
                              if (controller == null) return;
                              controller.animateTo(index);
                            },
                            calendarAvailable: hasCalendarBloc,
                            calendarActive: openCalendar,
                            onCalendarSelected: () {
                              context.read<ChatsCubit?>()?.toggleCalendar();
                            },
                          )
                        : null;

                    Widget chatLayout() => Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (navRail != null) navRail,
                            Expanded(
                              child: AxiAdaptiveLayout(
                                invertPriority: openJid != null,
                                centerSecondary: false,
                                centerPrimary: false,
                                primaryAlignment: Alignment.topLeft,
                                secondaryAlignment: Alignment.topLeft,
                                secondaryPadding: const EdgeInsets.only(
                                  left: _secondaryPaneGutter,
                                ),
                                primaryChild: Nexus(
                                  tabs: tabs,
                                  navPlacement: navPlacement,
                                  showNavigationRail:
                                      navPlacement != NavPlacement.rail,
                                  navRailCollapsed: _railCollapsed,
                                  onToggleNavRail: () {
                                    setState(() {
                                      _railCollapsed = !_railCollapsed;
                                    });
                                  },
                                ),
                                secondaryChild: openJid == null
                                    ? constrainSecondary(
                                        const chat_view.GuestChat(),
                                      )
                                    : constrainSecondary(
                                        MultiBlocProvider(
                                          providers: [
                                            BlocProvider(
                                              key: Key(
                                                openJid,
                                              ),
                                              create: (context) => ChatBloc(
                                                jid: openJid,
                                                messageService:
                                                    context.read<XmppService>(),
                                                chatsService:
                                                    context.read<XmppService>(),
                                                mucService:
                                                    context.read<XmppService>(),
                                                notificationService:
                                                    context.read<
                                                        NotificationService>(),
                                                emailService: context
                                                    .read<EmailService>(),
                                                omemoService: isOmemo
                                                    ? context
                                                            .read<XmppService>()
                                                        as OmemoService
                                                    : null,
                                                settingsCubit: context
                                                    .read<SettingsCubit>(),
                                              ),
                                            ),
                                            BlocProvider(
                                              create: (context) =>
                                                  ChatSearchCubit(
                                                jid: openJid,
                                                messageService:
                                                    context.read<XmppService>(),
                                              ),
                                            ),
                                            /* Verification flow temporarily disabled
                                            if (isOmemo)
                                              BlocProvider(
                                                create: (context) =>
                                                    VerificationCubit(
                                                  jid: openJid,
                                                  omemoService:
                                                      context.read<XmppService>()
                                                          as OmemoService,
                                                ),
                                              ),
                                            */
                                          ],
                                          child: const chat_view.Chat(),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        );

                    Widget calendarLayout() => Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (navRail != null) navRail,
                            const Expanded(
                              child: CalendarWidget(),
                            ),
                          ],
                        );

                    return SafeArea(
                      top: state is ConnectivityConnected,
                      child: openCalendar ? calendarLayout() : chatLayout(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

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
            if (isRoster)
              BlocProvider(
                create: (context) => RosterCubit(
                  rosterService: context.read<XmppService>(),
                ),
              ),
            BlocProvider(
              create: (context) => ProfileCubit(
                xmppService: context.read<XmppService>(),
                presenceService: isPresence
                    ? context.read<XmppService>() as PresenceService
                    : null,
                omemoService: isOmemo
                    ? context.read<XmppService>() as OmemoService
                    : null,
              ),
            ),
            if (isBlocking)
              BlocProvider(
                create: (context) => BlocklistCubit(
                  blockingService: context.read<XmppService>(),
                ),
              ),
            // Always provide CalendarBloc for logged-in users
            if (calendarStorage != null)
              BlocProvider<CalendarBloc>(
                create: (context) {
                  final reminderController =
                      context.read<CalendarReminderController>();
                  final xmppService = context.read<XmppService>();
                  final storage = calendarStorage;
                  final DayEventRepository dayEventRepository =
                      DayEventRepository(
                    database: xmppService.database,
                  );

                  return CalendarBloc(
                    reminderController: reminderController,
                    dayEventRepository: dayEventRepository,
                    syncManagerBuilder: (bloc) {
                      final manager = CalendarSyncManager(
                        readModel: () => bloc.currentModel,
                        applyModel: (model) async {
                          if (bloc.isClosed) return;
                          bloc.add(
                            CalendarEvent.remoteModelApplied(model: model),
                          );
                        },
                        sendCalendarMessage: (message) async {
                          if (bloc.isClosed) {
                            return;
                          }
                          final jid = xmppService.myJid;
                          if (jid != null) {
                            await xmppService.sendMessage(
                              jid: jid,
                              text: message,
                              storeLocally: false,
                            );
                          }
                        },
                      );

                      xmppService.setCalendarSyncCallback(
                        (syncMessage) async {
                          if (bloc.isClosed) return;
                          await manager.onCalendarMessage(syncMessage);
                        },
                      );
                      return manager;
                    },
                    storage: storage,
                    onDispose: xmppService.clearCalendarSyncCallback,
                  )..add(const CalendarEvent.started());
                },
              ),
            BlocProvider(
              create: (context) => ConnectivityCubit(
                xmppBase: context.read<XmppService>(),
              ),
            ),
            BlocProvider(
              create: (context) => EmailSyncCubit(
                emailService: context.read<EmailService>(),
              ),
            ),
          ],
          child: hasCalendarBloc
              ? CalendarTaskFeedbackObserver<CalendarBloc>(
                  child: mainContent,
                )
              : mainContent,
        ),
      ),
    );

    return BlocProvider(
      create: (context) {
        final bloc = AccessibilityActionBloc(
          chatsService: context.read<XmppService>(),
          messageService: context.read<XmppService>(),
          emailService: context.read<EmailService>(),
          rosterService:
              isRoster ? context.read<XmppService>() as RosterService : null,
          initialLocalization: l10n,
        );
        return bloc;
      },
      child: Builder(
        builder: (context) {
          final platform = Theme.of(context).platform;
          final findActivators = findActionActivators(platform);
          return Focus(
            focusNode: _shortcutFocusNode,
            autofocus: true,
            onKeyEvent: _handleHomeKeyEvent,
            child: Shortcuts(
              shortcuts: {
                for (final activator in findActivators)
                  activator: const OpenFindActionIntent(),
              },
              child: Actions(
                actions: {
                  ComposeIntent: CallbackAction<ComposeIntent>(
                    onInvoke: (_) {
                      context.read<ComposeWindowCubit>().openDraft(
                        attachmentMetadataIds: const <String>[],
                      );
                      return null;
                    },
                  ),
                  ToggleSearchIntent: CallbackAction<ToggleSearchIntent>(
                    onInvoke: (_) {
                      context.read<HomeSearchCubit?>()?.toggleSearch();
                      return null;
                    },
                  ),
                  ToggleCalendarIntent: CallbackAction<ToggleCalendarIntent>(
                    onInvoke: (_) {
                      if (!hasCalendarBloc) return null;
                      context.read<ChatsCubit?>()?.toggleCalendar();
                      return null;
                    },
                  ),
                  OpenFindActionIntent: CallbackAction<OpenFindActionIntent>(
                    onInvoke: (_) {
                      context.read<AccessibilityActionBloc?>()?.add(
                            const AccessibilityMenuOpened(),
                          );
                      return null;
                    },
                  ),
                },
                child: Stack(
                  children: [
                    scaffold,
                    const AccessibilityActionMenu(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class Nexus extends StatefulWidget {
  const Nexus({
    super.key,
    required this.tabs,
    required this.navPlacement,
    this.showNavigationRail = true,
    this.navRailCollapsed = false,
    this.onToggleNavRail,
  });

  final List<HomeTabEntry> tabs;
  final NavPlacement navPlacement;
  final bool showNavigationRail;
  final bool navRailCollapsed;
  final VoidCallback? onToggleNavRail;

  @override
  State<Nexus> createState() => _NexusState();
}

class _NexusState extends State<Nexus> {
  TabController? _tabController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    if (controller == _tabController) return;
    _tabController?.removeListener(_handleTabChanged);
    _tabController = controller;
    _tabController?.addListener(_handleTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifyTabIndex(controller.index);
    });
  }

  void _handleTabChanged() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging) return;
    _notifyTabIndex(controller.index);
  }

  void _notifyTabIndex(int index) {
    if (index < 0 || index >= widget.tabs.length) return;
    context.read<HomeSearchCubit?>()?.setActiveTab(widget.tabs[index].id);
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showToast = ShadToaster.maybeOf(context)?.show;
    final l10n = context.l10n;
    final HomeSearchState? searchState =
        context.watch<HomeSearchCubit?>()?.state;
    final ChatsState? chatsState = context.watch<ChatsCubit?>()?.state;
    final searchActive = searchState?.active ?? false;
    List<Chat> selectedChats = const <Chat>[];
    if (chatsState?.selectedJids.isNotEmpty ?? false) {
      selectedChats = (chatsState?.items ?? const <Chat>[])
          .where(
            (chat) => chatsState?.selectedJids.contains(chat.jid) ?? false,
          )
          .toList();
    }
    final selectionActive = selectedChats.isNotEmpty;
    final badgeCounts = <HomeTab, int>{
      HomeTab.invites: context.watch<RosterCubit?>()?.inviteCount ?? 0,
      HomeTab.chats: (chatsState?.items ?? const <Chat>[])
          .where((chat) => !chat.archived && !chat.spam)
          .fold<int>(0, (sum, chat) => sum + math.max(0, chat.unreadCount)),
      HomeTab.drafts: context.watch<DraftCubit?>()?.state.items?.length ?? 0,
      HomeTab.spam: (chatsState?.items ?? const <Chat>[])
          .where((chat) => chat.spam && !chat.archived)
          .length,
    };
    final showFindActionInHeader = widget.navPlacement != NavPlacement.rail;
    final showShortcutHints = widget.navPlacement != NavPlacement.bottom;
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AxiAppBar(
          showTitle: widget.navPlacement != NavPlacement.rail,
          leading: widget.navPlacement == NavPlacement.rail &&
                  widget.onToggleNavRail != null
              ? AxiIconButton(
                  iconData: LucideIcons.menu,
                  tooltip: widget.navRailCollapsed
                      ? l10n.homeRailShowMenu
                      : l10n.homeRailHideMenu,
                  onPressed: widget.onToggleNavRail,
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showFindActionInHeader) ...[
                _FindActionIconButton(
                  showShortcutHint: showShortcutHints,
                ),
                const SizedBox(width: 4),
              ],
              _SearchToggleButton(
                active: searchActive,
                onPressed: searchState == null
                    ? null
                    : () => context.read<HomeSearchCubit>().toggleSearch(),
              ),
            ],
          ),
        ),
        _HomeSearchPanel(tabs: widget.tabs),
      ],
    );

    final tabViews = MultiBlocListener(
      listeners: [
        if (context.read<RosterCubit?>() != null)
          BlocListener<RosterCubit, RosterState>(
            listener: (context, state) {
              if (showToast == null) return;
              if (state is RosterFailure) {
                showToast(
                  FeedbackToast.error(message: state.message),
                );
              } else if (state is RosterSuccess) {
                showToast(
                  FeedbackToast.success(message: state.message),
                );
              }
            },
          ),
        if (context.read<BlocklistCubit?>() != null)
          BlocListener<BlocklistCubit, BlocklistState>(
            listener: (context, state) {
              if (showToast == null) return;
              if (state is BlocklistFailure) {
                showToast(
                  FeedbackToast.error(message: state.message),
                );
              } else if (state is BlocklistSuccess) {
                showToast(
                  FeedbackToast.success(message: state.message),
                );
              }
            },
          ),
      ],
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.colorScheme.border),
          ),
        ),
        child: TabBarView(
          children: widget.tabs.map((tab) {
            return Scaffold(
              extendBodyBehindAppBar: true,
              body: tab.body,
              floatingActionButtonAnimator: const _ScaleOnlyFabAnimator(),
              floatingActionButton: selectionActive ? null : tab.fab,
            );
          }).toList(),
        ),
      ),
    );

    late final Widget bottomArea;
    if (selectionActive) {
      bottomArea = ChatSelectionActionBar(
        selectedChats: selectedChats,
      );
    } else if (widget.navPlacement == NavPlacement.bottom) {
      final Widget tabBar = Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.colorScheme.border),
          ),
        ),
        child: AxiTabBar(
          backgroundColor: context.colorScheme.background,
          badges: widget.tabs.map((tab) => badgeCounts[tab.id] ?? 0).toList(),
          badgeOffset: const Offset(0, -12),
          tabs: widget.tabs.map((tab) {
            return Tab(child: Text(tab.label));
          }).toList(),
        ),
      );
      bottomArea = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tabBar,
          const ProfileTile(),
        ],
      );
    } else {
      bottomArea = const ProfileTile();
    }

    final column = Column(
      children: [
        header,
        Expanded(child: tabViews),
        bottomArea,
      ],
    );

    if (widget.navPlacement == NavPlacement.rail && widget.showNavigationRail) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HomeNavigationRail(
            tabs: widget.tabs,
            selectedIndex: _tabController?.index ?? 0,
            collapsed: widget.navRailCollapsed,
            onDestinationSelected: _handleRailSelection,
            calendarAvailable: false,
            calendarActive: false,
            onCalendarSelected: () {},
            onCollapsedChanged: widget.onToggleNavRail == null
                ? null
                : (_) => widget.onToggleNavRail!(),
          ),
          Expanded(child: column),
        ],
      );
    }

    return column;
  }

  void _handleRailSelection(int index) {
    final controller = _tabController;
    if (controller == null || index == controller.index) return;
    if (index < 0 || index >= widget.tabs.length) return;
    controller.animateTo(index);
  }
}

class _TabActionGroup extends StatelessWidget {
  const _TabActionGroup({
    this.includePrimaryActions = false,
    this.extraActions = const <Widget>[],
  });

  final bool includePrimaryActions;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    if (includePrimaryActions) {
      actions.addAll(const [
        ChatsFilterButton(),
        DraftButton(),
        ChatsAddButton(),
      ]);
    }
    actions.addAll(extraActions);
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions,
    );
  }
}

class _AccessibilityFindActionRailItem extends StatelessWidget {
  const _AccessibilityFindActionRailItem({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    if (context.read<AccessibilityActionBloc?>() == null) {
      return const SizedBox.shrink();
    }
    final shortcut = findActionShortcut(Theme.of(context).platform);
    final shortcutText = shortcutLabel(context, shortcut);
    final l10n = context.l10n;
    if (collapsed) {
      return AxiIconButton(
        iconData: LucideIcons.lifeBuoy,
        tooltip: l10n.accessibilityActionsShortcutTooltip(shortcutText),
        onPressed: () => context
            .read<AccessibilityActionBloc?>()
            ?.add(const AccessibilityMenuOpened()),
      );
    }
    final colors = context.colorScheme;
    final radius = context.radius;
    return Semantics(
      label: l10n.accessibilityActionsLabel,
      button: true,
      child: Material(
        color: colors.background,
        shape: SquircleBorder(
          cornerRadius: radius.topLeft.x,
          side: BorderSide(color: colors.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: () => context
              .read<AccessibilityActionBloc?>()
              ?.add(const AccessibilityMenuOpened()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                const Icon(LucideIcons.lifeBuoy, size: 20),
                const SizedBox(width: 12),
                ShortcutHint(shortcut: shortcut, dense: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FindActionIconButton extends StatelessWidget {
  const _FindActionIconButton({required this.showShortcutHint});

  final bool showShortcutHint;

  @override
  Widget build(BuildContext context) {
    if (context.read<AccessibilityActionBloc?>() == null) {
      return const SizedBox.shrink();
    }
    final shortcut = findActionShortcut(Theme.of(context).platform);
    final shortcutText = shortcutLabel(context, shortcut);
    final l10n = context.l10n;
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.lifeBuoy, size: 18),
        if (showShortcutHint) ...[
          const SizedBox(width: 10),
          ShortcutHint(
            shortcut: shortcut,
            dense: true,
          ),
        ],
      ],
    );
    return AxiTooltip(
      builder: (_) => Text(
        l10n.accessibilityActionsShortcutTooltip(shortcutText),
      ),
      child: ShadButton.ghost(
        onPressed: () => context
            .read<AccessibilityActionBloc?>()
            ?.add(const AccessibilityMenuOpened()),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: content,
      ),
    );
  }
}

class _SearchToggleButton extends StatelessWidget {
  const _SearchToggleButton({
    required this.active,
    this.onPressed,
  });

  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AxiIconButton(
      iconData: active ? LucideIcons.x : LucideIcons.search,
      tooltip: active ? l10n.chatSearchClose : l10n.commonSearch,
      onPressed: onPressed,
    );
  }
}

class _ScaleOnlyFabAnimator extends FloatingActionButtonAnimator {
  const _ScaleOnlyFabAnimator();

  static const Curve _moveCurve = Curves.easeInOutCubic;

  @override
  Offset getOffset({
    required Offset begin,
    required Offset end,
    required double progress,
  }) {
    final t = _moveCurve.transform(progress);
    return Offset.lerp(begin, end, t)!;
  }

  @override
  Animation<double> getScaleAnimation({required Animation<double> parent}) {
    const curveOut = Interval(0.0, 0.5, curve: Curves.easeIn);
    const curveIn = Interval(0.5, 1.0, curve: Curves.easeOut);
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: curveOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: curveIn)),
        weight: 50,
      ),
    ]).animate(parent);
  }

  @override
  Animation<double> getRotationAnimation({
    required Animation<double> parent,
  }) =>
      const AlwaysStoppedAnimation<double>(0.0);

  @override
  double getAnimationRestart(double previousValue) =>
      FloatingActionButtonAnimator.scaling.getAnimationRestart(previousValue);
}

class _HomeNavigationRail extends StatefulWidget {
  const _HomeNavigationRail({
    required this.tabs,
    required this.selectedIndex,
    required this.collapsed,
    required this.onDestinationSelected,
    required this.calendarAvailable,
    required this.calendarActive,
    required this.onCalendarSelected,
    this.onCollapsedChanged,
  });

  final List<HomeTabEntry> tabs;
  final int selectedIndex;
  final bool collapsed;
  final ValueChanged<int> onDestinationSelected;
  final bool calendarAvailable;
  final bool calendarActive;
  final VoidCallback onCalendarSelected;
  final ValueChanged<bool>? onCollapsedChanged;

  @override
  State<_HomeNavigationRail> createState() => _HomeNavigationRailState();
}

class _HomeNavigationRailState extends State<_HomeNavigationRail> {
  TabController? _tabController;
  int _controllerIndex = 0;
  late final AppLocalizations l10n = context.l10n;

  @override
  void initState() {
    super.initState();
    _controllerIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(covariant _HomeNavigationRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tabController == null && widget.selectedIndex != _controllerIndex) {
      _controllerIndex = widget.selectedIndex;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    if (_tabController == controller) return;
    _tabController?.removeListener(_handleTabChange);
    _tabController = controller;
    _controllerIndex = controller.index;
    _tabController?.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging) return;
    setState(() {
      _controllerIndex = controller.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _tabController?.index ?? _controllerIndex;
    if (widget.tabs.isEmpty) {
      return const SizedBox.shrink();
    }
    final badgeCounts =
        _computeBadgeCounts(context.watch<RosterCubit?>()?.inviteCount ?? 0);
    final calendarDestinationIndex = _calendarDestinationIndex();
    final destinations = <AxiRailDestination>[];
    for (final tab in widget.tabs) {
      destinations.add(
        AxiRailDestination(
          icon: _tabIcon(tab.id),
          label: tab.label,
          badgeCount: badgeCounts[tab.id] ?? 0,
        ),
      );
      if (calendarDestinationIndex != null &&
          destinations.length == calendarDestinationIndex) {
        destinations.add(
          AxiRailDestination(
            icon: LucideIcons.calendarClock,
            label: l10n.homeRailCalendar,
          ),
        );
      }
    }
    final safeTabIndex = selectedIndex.clamp(0, widget.tabs.length - 1).toInt();
    final selectedRailIndex =
        widget.calendarActive && calendarDestinationIndex != null
            ? calendarDestinationIndex
            : _destinationIndexForTab(safeTabIndex, calendarDestinationIndex);
    final effectiveSelectedIndex =
        selectedRailIndex.clamp(0, destinations.length - 1).toInt();
    return SafeArea(
      left: false,
      right: false,
      child: AxiNavigationRail(
        destinations: destinations,
        selectedIndex: effectiveSelectedIndex,
        collapsed: widget.collapsed,
        onToggleCollapse: widget.onCollapsedChanged == null
            ? null
            : () => widget.onCollapsedChanged!(!widget.collapsed),
        backgroundColor: context.colorScheme.background,
        footer: _AccessibilityFindActionRailItem(
          collapsed: widget.collapsed,
        ),
        onDestinationSelected: (index) {
          final calendarIndex = _calendarDestinationIndex();
          if (calendarIndex != null && index == calendarIndex) {
            widget.onCalendarSelected();
            return;
          }
          final tabIndex = _tabIndexForDestination(index, calendarIndex);
          if (tabIndex == null) return;
          if (widget.calendarActive) {
            widget.onCalendarSelected();
          }
          setState(() {
            _controllerIndex = tabIndex;
          });
          widget.onDestinationSelected(tabIndex);
        },
      ),
    );
  }

  int? _calendarDestinationIndex() {
    if (!widget.calendarAvailable) return null;
    final chatIndex =
        widget.tabs.indexWhere((entry) => entry.id == HomeTab.chats);
    if (chatIndex == -1) {
      return widget.tabs.length;
    }
    return chatIndex + 1;
  }

  int _destinationIndexForTab(int tabIndex, int? calendarDestinationIndex) {
    if (calendarDestinationIndex == null) return tabIndex;
    return tabIndex >= calendarDestinationIndex ? tabIndex + 1 : tabIndex;
  }

  int? _tabIndexForDestination(
      int destinationIndex, int? calendarDestinationIndex) {
    if (calendarDestinationIndex == null) return destinationIndex;
    if (destinationIndex == calendarDestinationIndex) {
      return null;
    }
    if (destinationIndex > calendarDestinationIndex) {
      return destinationIndex - 1;
    }
    return destinationIndex;
  }

  Map<HomeTab, int> _computeBadgeCounts(int inviteCount) {
    return <HomeTab, int>{
      HomeTab.invites: inviteCount,
      HomeTab.chats:
          (context.watch<ChatsCubit?>()?.state.items ?? const <Chat>[])
              .where((chat) => !chat.archived && !chat.spam)
              .fold<int>(0, (sum, chat) => sum + math.max(0, chat.unreadCount)),
      HomeTab.drafts: context.watch<DraftCubit?>()?.state.items?.length ?? 0,
      HomeTab.spam:
          (context.watch<ChatsCubit?>()?.state.items ?? const <Chat>[])
              .where((chat) => chat.spam && !chat.archived)
              .length,
    };
  }
}

IconData _tabIcon(HomeTab tab) {
  switch (tab) {
    case HomeTab.chats:
      return LucideIcons.messagesSquare;
    case HomeTab.contacts:
      return LucideIcons.users;
    case HomeTab.invites:
      return LucideIcons.userPlus;
    case HomeTab.blocked:
      return LucideIcons.userX;
    case HomeTab.spam:
      return LucideIcons.shieldAlert;
    case HomeTab.drafts:
      return LucideIcons.fileText;
  }
}

class _HomeSearchPanel extends StatefulWidget {
  const _HomeSearchPanel({required this.tabs});

  final List<HomeTabEntry> tabs;

  @override
  State<_HomeSearchPanel> createState() => _HomeSearchPanelState();
}

class _HomeSearchPanelState extends State<_HomeSearchPanel> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _programmaticChange = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (_programmaticChange) return;
    context.read<HomeSearchCubit?>()?.updateQuery(_controller.text);
    setState(() {});
  }

  void _syncController(String text) {
    if (_controller.text == text) return;
    _programmaticChange = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _programmaticChange = false;
    setState(() {});
  }

  String _filterLabel(List<HomeSearchFilter> filters, String? id) {
    for (final filter in filters) {
      if (filter.id == id) return filter.label;
    }
    return filters.isNotEmpty ? filters.first.label : '';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeSearchCubit, HomeSearchState>(
      listener: (context, state) {
        final query = state.currentTabState?.query ?? '';
        _syncController(query);
        if (state.active) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _focusNode.hasFocus) return;
            _focusNode.requestFocus();
          });
        } else if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      },
      builder: (context, state) {
        final l10n = context.l10n;
        final active = state.active;
        final tab = state.activeTab;
        final entry = tab == null
            ? (widget.tabs.isEmpty ? null : widget.tabs.first)
            : widget.tabs.firstWhere(
                (candidate) => candidate.id == tab,
                orElse: () => widget.tabs.first,
              );
        final filters = entry?.searchFilters ?? const <HomeSearchFilter>[];
        final currentTabState = tab == null ? null : state.stateFor(tab);
        final sortValue = currentTabState?.sort ?? SearchSortOrder.newestFirst;
        final selectedFilterId = currentTabState?.filterId;
        final effectiveFilterId =
            filters.isEmpty ? null : (selectedFilterId ?? filters.first.id);
        final placeholder = entry == null
            ? l10n.homeSearchPlaceholderTabs
            : l10n.homeSearchPlaceholderForTab(entry.label);
        final filterLabel =
            filters.isEmpty ? null : _filterLabel(filters, effectiveFilterId);
        return AnimatedCrossFade(
          crossFadeState:
              active ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: context.watch<SettingsCubit>().animationDuration,
          reverseDuration: context.watch<SettingsCubit>().animationDuration,
          sizeCurve: Curves.easeInOutCubic,
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.colorScheme.card,
              border: Border(
                bottom: BorderSide(color: context.colorScheme.border),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ShadInput(
                        controller: _controller,
                        focusNode: _focusNode,
                        placeholder: Text(placeholder),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AxiIconButton(
                      iconData: LucideIcons.x,
                      tooltip: l10n.commonClear,
                      onPressed: _controller.text.isEmpty
                          ? null
                          : () => context
                              .read<HomeSearchCubit?>()
                              ?.clearQuery(tab: tab),
                    ),
                    const SizedBox(width: 8),
                    ShadButton.ghost(
                      size: ShadButtonSize.sm,
                      onPressed: () => context
                          .read<HomeSearchCubit?>()
                          ?.setSearchActive(false),
                      child: Text(l10n.commonCancel),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ShadSelect<SearchSortOrder>(
                        initialValue: sortValue,
                        onChanged: (value) {
                          if (value == null) return;
                          context
                              .read<HomeSearchCubit?>()
                              ?.updateSort(value, tab: tab);
                        },
                        options: SearchSortOrder.values
                            .map(
                              (order) => ShadOption<SearchSortOrder>(
                                value: order,
                                child: Text(order.label),
                              ),
                            )
                            .toList(),
                        selectedOptionBuilder: (_, value) => Text(value.label),
                      ),
                    ),
                    if (filters.length > 1 && effectiveFilterId != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ShadSelect<String>(
                          initialValue: effectiveFilterId,
                          onChanged: (value) {
                            context
                                .read<HomeSearchCubit?>()
                                ?.updateFilter(value, tab: tab);
                          },
                          options: filters
                              .map(
                                (filter) => ShadOption<String>(
                                  value: filter.id,
                                  child: Text(filter.label),
                                ),
                              )
                              .toList(),
                          selectedOptionBuilder: (_, value) => Text(
                            _filterLabel(filters, value),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (filterLabel != null && filters.length > 1)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.homeSearchFilterLabel(filterLabel),
                        style: context.textTheme.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
