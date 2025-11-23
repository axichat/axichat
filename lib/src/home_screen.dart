// ignore_for_file: unnecessary_type_check
import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/view/blocklist_button.dart';
import 'package:axichat/src/blocklist/view/blocklist_list.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
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
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/draft_button.dart';
import 'package:axichat/src/draft/view/drafts_list.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/home/home_search_definitions.dart';
import 'package:axichat/src/home/home_search_models.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/view/profile_tile.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/spam/view/spam_list.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const _blocklistSearchFilters = [
  HomeSearchFilter(id: 'all', label: 'All blocked'),
];

const _draftsSearchFilters = [
  HomeSearchFilter(id: 'all', label: 'All drafts'),
  HomeSearchFilter(id: 'attachments', label: 'With attachments'),
];

const double _secondaryPaneGutter = 0.0;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final getService = context.read<XmppService>;

    final isChat = getService() is ChatsService;
    final isMessage = getService() is MessageService;
    final isRoster = getService() is RosterService;
    final isPresence = getService() is PresenceService;
    final isOmemo = getService() is OmemoService;
    final isBlocking = getService() is BlockingService;
    final navPlacement = EnvScope.of(context).navPlacement;

    final tabs = <HomeTabEntry>[
      if (isChat)
        HomeTabEntry(
          id: HomeTab.chats,
          label: 'Chats',
          body: ChatsList(
            key: const PageStorageKey('Chats'),
            showCalendarShortcut: navPlacement != NavPlacement.rail,
          ),
          fab: const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChatsFilterButton(),
              DraftButton(),
              ChatsAddButton(),
            ],
          ),
          searchFilters: chatsSearchFilters,
        ),
      if (isMessage)
        const HomeTabEntry(
          id: HomeTab.drafts,
          label: 'Drafts',
          body: DraftsList(key: PageStorageKey('Drafts')),
          searchFilters: _draftsSearchFilters,
        ),
      if (isChat)
        const HomeTabEntry(
          id: HomeTab.spam,
          label: 'Spam',
          body: SpamList(key: PageStorageKey('Spam')),
          searchFilters: spamSearchFilters,
        ),
      if (isBlocking)
        const HomeTabEntry(
          id: HomeTab.blocked,
          label: 'Blocked',
          body: BlocklistList(key: PageStorageKey('Blocked')),
          fab: BlocklistAddButton(),
          searchFilters: _blocklistSearchFilters,
        ),
    ];
    if (tabs.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No modules available'),
        ),
      );
    }
    final initialTabFilters = <HomeTab, String?>{
      for (final entry in tabs)
        if (entry.searchFilters.isNotEmpty)
          entry.id: entry.searchFilters.first.id,
    };
    final hasCalendarBloc = context.read<Storage?>() != null;
    final Widget mainContent = Builder(
      builder: (context) {
        final openJid = context.watch<ChatsCubit?>()?.state.openJid;
        final openCalendar =
            context.watch<ChatsCubit?>()?.state.openCalendar ?? false;
        Widget constrainSecondary(Widget child) => Align(
              alignment: Alignment.topLeft,
              child: child,
            );
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (_, __) {
            final chatsCubit = context.read<ChatsCubit?>();
            if (chatsCubit?.state.openCalendar ?? false) {
              chatsCubit?.toggleCalendar();
            } else if (openJid case final jid?) {
              chatsCubit?.toggleChat(jid: jid);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ConnectivityIndicator(),
              Expanded(
                child: BlocBuilder<ConnectivityCubit, ConnectivityState>(
                  builder: (context, state) {
                    final navRail = navPlacement == NavPlacement.rail
                        ? _HomeNavigationRail(
                            tabs: tabs,
                            selectedIndex:
                                DefaultTabController.maybeOf(context)?.index ??
                                    0,
                            onDestinationSelected: (index) {
                              final controller =
                                  DefaultTabController.maybeOf(context);
                              if (controller == null) return;
                              controller.animateTo(index);
                            },
                            calendarAvailable: hasCalendarBloc,
                            calendarActive: openCalendar,
                            onCalendarSelected: () {
                              final chatsCubit = context.read<ChatsCubit?>();
                              chatsCubit?.toggleCalendar();
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
                                ),
                                secondaryChild: openJid == null
                                    ? constrainSecondary(
                                        const chat_view.GuestChat(),
                                      )
                                    : constrainSecondary(
                                        MultiBlocProvider(
                                          providers: [
                                            BlocProvider(
                                              key: Key(openJid),
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
            if (isChat)
              BlocProvider(
                create: (context) => ChatsCubit(
                  chatsService: context.read<XmppService>(),
                ),
              ),
            if (isMessage)
              BlocProvider(
                create: (context) => DraftCubit(
                  messageService: context.read<XmppService>(),
                  emailService: context.read<EmailService>(),
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
            if (context.read<Storage?>() != null)
              BlocProvider(
                create: (context) {
                  final reminderController =
                      context.read<CalendarReminderController>();
                  final xmppService = context.read<XmppService>();
                  final storage = context.read<Storage?>()!;

                  return CalendarBloc(
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
          ],
          child: hasCalendarBloc
              ? CalendarTaskFeedbackObserver<CalendarBloc>(
                  child: mainContent,
                )
              : mainContent,
        ),
      ),
    );

    return Actions(
      actions: {
        ComposeIntent: CallbackAction<ComposeIntent>(
          onInvoke: (_) {
            context.push(
              const ComposeRoute().location,
              extra: {
                'locate': context.read,
                'attachments': const <String>[],
              },
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
            context.read<ChatsCubit?>()?.toggleCalendar();
            return null;
          },
        ),
      },
      child: scaffold,
    );
  }
}

class Nexus extends StatefulWidget {
  const Nexus({
    super.key,
    required this.tabs,
    required this.navPlacement,
    this.showNavigationRail = true,
  });

  final List<HomeTabEntry> tabs;
  final NavPlacement navPlacement;
  final bool showNavigationRail;

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
    final searchState = context.watch<HomeSearchCubit?>();
    final searchActive = searchState?.state.active ?? false;
    final chatsCubit = context.watch<ChatsCubit?>();
    List<Chat> selectedChats = const <Chat>[];
    if (chatsCubit != null &&
        chatsCubit.state.selectedJids.isNotEmpty &&
        chatsCubit.state.items != null) {
      selectedChats = chatsCubit.state.items!
          .where(
            (chat) => chatsCubit.state.selectedJids.contains(chat.jid),
          )
          .toList();
    }
    final selectionActive = selectedChats.isNotEmpty && chatsCubit != null;
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AxiAppBar(
          showTitle: widget.navPlacement != NavPlacement.rail,
          trailing: _SearchToggleButton(
            active: searchActive,
            onPressed: searchState == null
                ? null
                : () => context.read<HomeSearchCubit>().toggleSearch(),
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
        chatsCubit: chatsCubit,
        selectedChats: selectedChats,
      );
    } else if (widget.navPlacement == NavPlacement.bottom) {
      bottomArea = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AxiTabBar(
            backgroundColor: context.colorScheme.background,
            tabs: widget.tabs.map((tab) {
              if (tab.id == HomeTab.invites) {
                final length = context.watch<RosterCubit?>()?.inviteCount;
                return Tab(
                  child: AxiBadge(
                    count: length ?? 0,
                    child: Text(tab.label),
                  ),
                );
              }
              return Tab(text: tab.label);
            }).toList(),
          ),
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
            onDestinationSelected: _handleRailSelection,
            calendarAvailable: false,
            calendarActive: false,
            onCalendarSelected: () {},
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

class _SearchToggleButton extends StatelessWidget {
  const _SearchToggleButton({
    required this.active,
    this.onPressed,
  });

  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiIconButton(
      iconData: active ? LucideIcons.x : LucideIcons.search,
      tooltip: active ? 'Close search' : 'Search',
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

class _HomeNavigationRail extends StatelessWidget {
  const _HomeNavigationRail({
    required this.tabs,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.calendarAvailable,
    required this.calendarActive,
    required this.onCalendarSelected,
  });

  final List<HomeTabEntry> tabs;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool calendarAvailable;
  final bool calendarActive;
  final VoidCallback onCalendarSelected;

  @override
  Widget build(BuildContext context) {
    final inviteCount = context.watch<RosterCubit?>()?.inviteCount ?? 0;
    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }
    final baseDestinations = tabs
        .map(
          (tab) => AxiRailDestination(
            icon: _tabIcon(tab.id),
            label: tab.label,
            badgeCount: tab.id == HomeTab.invites ? inviteCount : 0,
          ),
        )
        .toList();
    if (calendarAvailable) {
      baseDestinations.add(
        const AxiRailDestination(
          icon: LucideIcons.calendarClock,
          label: 'Calendar',
        ),
      );
    }
    final safeIndex = selectedIndex.clamp(0, tabs.length - 1).toInt();
    final selectedRailIndex =
        calendarActive ? baseDestinations.length - 1 : safeIndex;
    return SafeArea(
      left: false,
      right: false,
      child: AxiNavigationRail(
        destinations: baseDestinations,
        selectedIndex: selectedRailIndex,
        onDestinationSelected: (index) {
          final calendarIndex =
              calendarAvailable ? baseDestinations.length - 1 : null;
          if (calendarIndex != null && index == calendarIndex) {
            onCalendarSelected();
            return;
          }
          onDestinationSelected(index);
        },
      ),
    );
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
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
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
            ? 'Search tabs'
            : 'Search ${entry.label.toLowerCase()}';
        final filterLabel =
            filters.isEmpty ? null : _filterLabel(filters, effectiveFilterId);
        return AnimatedCrossFade(
          crossFadeState:
              active ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: animationDuration,
          reverseDuration: animationDuration,
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
                      tooltip: 'Clear',
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
                      child: const Text('Cancel'),
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
                        'Filter: $filterLabel',
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
