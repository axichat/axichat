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
import 'package:axichat/src/chat/bloc/chat_transport_cubit.dart';
import 'package:axichat/src/chat/view/chat.dart' as chat_view;
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/chat_selection_bar.dart';
import 'package:axichat/src/chats/view/chats_filter_button.dart';
import 'package:axichat/src/chats/view/chats_list.dart';
import 'package:axichat/src/common/search/search_models.dart';
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
import 'package:axichat/src/roster/view/roster_add_button.dart';
import 'package:axichat/src/roster/view/roster_invites_list.dart';
import 'package:axichat/src/roster/view/roster_list.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const _contactsSearchFilters = [
  HomeSearchFilter(id: 'all', label: 'All contacts'),
  HomeSearchFilter(id: 'online', label: 'Online'),
  HomeSearchFilter(id: 'offline', label: 'Offline'),
];

const _invitesSearchFilters = [
  HomeSearchFilter(id: 'all', label: 'All invites'),
];

const _blocklistSearchFilters = [
  HomeSearchFilter(id: 'all', label: 'All blocked'),
];

const _draftsSearchFilters = [
  HomeSearchFilter(id: 'all', label: 'All drafts'),
  HomeSearchFilter(id: 'attachments', label: 'With attachments'),
];

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

    final tabs = <HomeTabEntry>[
      if (isChat)
        const HomeTabEntry(
          id: HomeTab.chats,
          label: 'Chats',
          body: ChatsList(key: PageStorageKey('Chats')),
          fab: Row(
            spacing: 8,
            mainAxisSize: MainAxisSize.min,
            children: [ChatsFilterButton(), DraftButton()],
          ),
          searchFilters: chatsSearchFilters,
        ),
      if (isRoster)
        const HomeTabEntry(
          id: HomeTab.contacts,
          label: 'Contacts',
          body: RosterList(key: PageStorageKey('Contacts')),
          fab: RosterAddButton(),
          searchFilters: _contactsSearchFilters,
        ),
      if (isRoster)
        const HomeTabEntry(
          id: HomeTab.invites,
          label: 'New',
          body: RosterInvitesList(key: PageStorageKey('New')),
          searchFilters: _invitesSearchFilters,
        ),
      if (isBlocking)
        const HomeTabEntry(
          id: HomeTab.blocked,
          label: 'Blocked',
          body: BlocklistList(key: PageStorageKey('Blocked')),
          fab: BlocklistAddButton(),
          searchFilters: _blocklistSearchFilters,
        ),
      if (isMessage)
        const HomeTabEntry(
          id: HomeTab.drafts,
          label: 'Drafts',
          body: DraftsList(key: PageStorageKey('Drafts')),
          searchFilters: _draftsSearchFilters,
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
                    return SafeArea(
                      top: state is ConnectivityConnected,
                      child: AxiAdaptiveLayout(
                        invertPriority: openJid != null || openCalendar,
                        primaryChild: Nexus(tabs: tabs),
                        secondaryChild: openCalendar
                            ? const CalendarWidget()
                            : openJid == null ||
                                    context.read<XmppService?>() == null
                                ? const chat_view.GuestChat()
                                : MultiBlocProvider(
                                    providers: [
                                      BlocProvider(
                                        key: Key(openJid),
                                        create: (context) => ChatBloc(
                                          jid: openJid,
                                          messageService:
                                              context.read<XmppService>(),
                                          chatsService:
                                              context.read<XmppService>(),
                                          notificationService: context
                                              .read<NotificationService>(),
                                          emailService:
                                              context.read<EmailService>(),
                                          omemoService: isOmemo
                                              ? context.read<XmppService>()
                                                  as OmemoService
                                              : null,
                                        ),
                                      ),
                                      BlocProvider(
                                        create: (context) => ChatTransportCubit(
                                          chatsService:
                                              context.read<XmppService>(),
                                          jid: openJid,
                                        ),
                                      ),
                                      BlocProvider(
                                        create: (context) => ChatSearchCubit(
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
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    return Scaffold(
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
            if (isPresence)
              BlocProvider(
                create: (context) => ProfileCubit(
                  presenceService: context.read<XmppService>(),
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
  }
}

class Nexus extends StatefulWidget {
  const Nexus({super.key, required this.tabs});

  final List<HomeTabEntry> tabs;

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
    return Column(
      children: [
        AxiAppBar(
          trailing: _SearchToggleButton(
            active: searchActive,
            onPressed: searchState == null
                ? null
                : () => context.read<HomeSearchCubit>().toggleSearch(),
          ),
        ),
        _HomeSearchPanel(tabs: widget.tabs),
        MultiBlocListener(
          listeners: [
            if (context.read<RosterCubit?>() != null)
              BlocListener<RosterCubit, RosterState>(
                listener: (context, state) {
                  if (showToast == null) return;
                  if (state is RosterFailure) {
                    showToast(
                      ShadToast.destructive(
                        title: const Text('Whoops!'),
                        description: Text(state.message),
                        alignment: Alignment.topRight,
                        showCloseIconOnlyWhenHovered: false,
                      ),
                    );
                  } else if (state is RosterSuccess) {
                    showToast(
                      ShadToast(
                        title: const Text('Success!'),
                        description: Text(state.message),
                        alignment: Alignment.topRight,
                        showCloseIconOnlyWhenHovered: false,
                      ),
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
                      ShadToast.destructive(
                        title: const Text('Whoops!'),
                        description: Text(state.message),
                        alignment: Alignment.topRight,
                        showCloseIconOnlyWhenHovered: false,
                      ),
                    );
                  } else if (state is BlocklistSuccess) {
                    showToast(
                      ShadToast(
                        title: const Text('Success!'),
                        description: Text(state.message),
                        alignment: Alignment.topRight,
                        showCloseIconOnlyWhenHovered: false,
                      ),
                    );
                  }
                },
              ),
          ],
          child: Expanded(
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
          ),
        ),
        if (selectionActive)
          ChatSelectionActionBar(
            chatsCubit: chatsCubit,
            selectedChats: selectedChats,
          )
        else ...[
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
      ],
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
