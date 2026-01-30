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
import 'package:axichat/src/calendar/view/calendar_widget.dart';
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
import 'package:axichat/src/email/bloc/email_sync_cubit.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/view/email_forwarding_guide.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/home/home_search_definitions.dart';
import 'package:axichat/src/home/home_search_models.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/view/profile_tile.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/spam/view/spam_list.dart';
import 'package:axichat/src/storage/models.dart' as m;
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

part 'home/view/home_screen_widgets.dart';

List<HomeSearchFilter> _blocklistSearchFilters(AppLocalizations l10n) => [
      HomeSearchFilter(id: 'all', label: l10n.blocklistFilterAll),
    ];

List<HomeSearchFilter> _draftsSearchFilters(AppLocalizations l10n) => [
      HomeSearchFilter(id: 'all', label: l10n.draftsFilterAll),
      HomeSearchFilter(id: 'attachments', label: l10n.draftsFilterAttachments),
    ];

const double _secondaryPaneGutter = 0.0;
const double _homeHeaderActionSpacing = 4.0;
const double _railFooterSpacing = 12.0;
const double _railFooterItemSpacing = 12.0;
const double _railFooterIconSize = 20.0;
const EdgeInsets _railFooterItemPadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 12,
);
const String _homeSyncTooltip = 'Sync';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FocusNode _shortcutFocusNode = FocusNode(debugLabel: 'home_shortcuts');
  bool _railCollapsed = true;
  LocalHistoryEntry? _openChatHistoryEntry;
  LocalHistoryEntry? _openCalendarHistoryEntry;
  bool Function(KeyEvent event)? _globalShortcutHandler;
  ChatCalendarSyncCoordinator? _chatCalendarCoordinator;
  CalendarAvailabilityShareCoordinator? _availabilityShareCoordinator;

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
    _shortcutFocusNode.dispose();
    _clearOpenChatHistoryEntry();
    _clearOpenCalendarHistoryEntry();
    super.dispose();
  }

  @override
  void deactivate() {
    context.read<XmppService?>()?.clearChatCalendarSyncCallback();
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
    final chatsCubit = context.read<ChatsCubit?>();
    final chatsState = chatsCubit?.state;
    if (chatsCubit == null || chatsState == null) {
      return;
    }
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
    final chatsCubit = context.read<ChatsCubit?>();
    final chatsState = chatsCubit?.state;
    if (chatsCubit == null || chatsState == null) {
      return;
    }
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
    final chatsState = context.read<ChatsCubit?>()?.state;
    if (chatsState == null) {
      _clearOpenChatHistoryEntry();
      _clearOpenCalendarHistoryEntry();
      return;
    }
    _syncHomeHistoryEntries(chatsState);
  }

  KeyEventResult _handleHomeKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isFindActionEvent(event)) return KeyEventResult.ignored;
    context.read<AccessibilityActionBloc?>()?.add(
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
    return shouldOpen && locate<AccessibilityActionBloc?>()?.isClosed == false;
  }

  bool _handleGlobalShortcut(KeyEvent event) {
    if (!mounted || !_isFindActionEvent(event)) return false;
    context.read<AccessibilityActionBloc?>()?.add(
          const AccessibilityMenuOpened(),
        );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final storageManager = context.read<CalendarStorageManager>();
    return ListenableBuilder(
      listenable: storageManager,
      builder: (context, _) => _buildContent(context, storageManager),
    );
  }

  Widget _buildContent(
    BuildContext context,
    CalendarStorageManager storageManager,
  ) {
    final l10n = context.l10n;

    final xmppService = context.read<XmppService>();
    // ignore: unnecessary_type_check
    final isRoster = xmppService is RosterService;
    // ignore: unnecessary_type_check
    final isPresence = xmppService is PresenceService;
    // ignore: unnecessary_type_check
    final isBlocking = xmppService is BlockingService;
    final isOmemo = xmppService is OmemoService;
    final env = EnvScope.of(context);
    final navPlacement = env.navPlacement;
    final showDesktopPrimaryActions = navPlacement == NavPlacement.rail;
    final Storage? calendarStorage = storageManager.authStorage;
    final bool hasCalendarBloc = storageManager.isAuthStorageReady;
    final chatCalendarCoordinator = _chatCalendarCoordinator ??
        (calendarStorage == null
            ? null
            : ChatCalendarSyncCoordinator(
                storage: ChatCalendarStorage(storage: calendarStorage),
                sendMessage: ({
                  required String jid,
                  required CalendarSyncOutbound outbound,
                  required m.ChatType chatType,
                }) async {
                  await xmppService.sendCalendarSyncMessage(
                    jid: jid,
                    outbound: outbound,
                    chatType: chatType,
                  );
                },
                sendSnapshotFile: xmppService.uploadCalendarSnapshot,
              ));
    if (_chatCalendarCoordinator == null && chatCalendarCoordinator != null) {
      _chatCalendarCoordinator = chatCalendarCoordinator;
    }
    if (chatCalendarCoordinator != null) {
      xmppService.setChatCalendarSyncCallback(
        chatCalendarCoordinator.handleInbound,
      );
    }
    final availabilityShareCoordinator = _availabilityShareCoordinator ??
        (calendarStorage == null
            ? null
            : CalendarAvailabilityShareCoordinator(
                store: CalendarAvailabilityShareStore(),
                sendMessage: ({
                  required String jid,
                  required CalendarAvailabilityMessage message,
                  required m.ChatType chatType,
                }) async {
                  await xmppService.sendAvailabilityMessage(
                    jid: jid,
                    message: message,
                    chatType: chatType,
                  );
                },
              ));
    if (_availabilityShareCoordinator == null &&
        availabilityShareCoordinator != null) {
      _availabilityShareCoordinator = availabilityShareCoordinator;
    }
    final chatsFilters = chatsSearchFilters(l10n);
    final spamFilters = spamSearchFilters(l10n);
    final draftsFilters = _draftsSearchFilters(l10n);
    final blocklistFilters = _blocklistSearchFilters(l10n);

    final tabs = <HomeTabEntry>[
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
      HomeTabEntry(
        id: HomeTab.drafts,
        label: l10n.homeTabDrafts,
        body: const DraftsList(key: PageStorageKey('Drafts')),
        fab: showDesktopPrimaryActions
            ? const _TabActionGroup(includePrimaryActions: true)
            : null,
        searchFilters: draftsFilters,
      ),
      HomeTabEntry(
        id: HomeTab.spam,
        label: l10n.homeTabSpam,
        body: const SpamList(key: PageStorageKey('Spam')),
        fab: showDesktopPrimaryActions
            ? const _TabActionGroup(includePrimaryActions: true)
            : null,
        searchFilters: spamFilters,
      ),
      HomeTabEntry(
        id: HomeTab.blocked,
        label: l10n.homeTabBlocked,
        body: const BlocklistList(key: PageStorageKey('Blocked')),
        fab: const _TabActionGroup(extraActions: [BlocklistAddButton()]),
        searchFilters: blocklistFilters,
      ),
    ];
    if (tabs.isEmpty) {
      return Scaffold(body: Center(child: Text(l10n.homeNoModules)));
    }
    final initialTabFilters = <HomeTab, String?>{
      for (final entry in tabs)
        if (entry.searchFilters.isNotEmpty)
          entry.id: entry.searchFilters.first.id,
    };
    final Widget mainContent = Builder(
      builder: (context) {
        Widget constrainSecondary(Widget child) =>
            Align(alignment: Alignment.topLeft, child: child);
        return BlocListener<ChatsCubit, ChatsState>(
          listenWhen: (previous, current) =>
              previous.openStack != current.openStack ||
              previous.openCalendar != current.openCalendar,
          listener: (context, state) => _syncHomeHistoryEntries(state),
          child: KeyboardPopScope(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ConnectivityIndicator(),
                Expanded(
                  child: BlocBuilder<ConnectivityCubit, ConnectivityState>(
                    builder: (context, state) {
                      final String? openJid =
                          context.watch<ChatsCubit?>()?.state.openJid;
                      final bool openCalendar = hasCalendarBloc &&
                          (context.watch<ChatsCubit?>()?.state.openCalendar ??
                              false);
                      final chatRoute =
                          context.watch<ChatsCubit?>()?.state.openChatRoute;
                      final navRail = navPlacement == NavPlacement.rail
                          ? _HomeNavigationRail(
                              tabs: tabs,
                              selectedIndex:
                                  DefaultTabController.maybeOf(context)
                                          ?.index ??
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
                              onCollapsedChanged: (collapsed) {
                                setState(() {
                                  _railCollapsed = collapsed;
                                });
                              },
                            )
                          : null;

                      final Widget chatPaneContent = openJid == null
                          ? const GuestChat()
                          : MultiBlocProvider(
                              providers: [
                                BlocProvider(
                                  key: Key(openJid),
                                  create: (context) {
                                    final settings =
                                        context.read<SettingsCubit>().state;
                                    return ChatBloc(
                                      jid: openJid,
                                      messageService:
                                          context.read<XmppService>(),
                                      chatsService: context.read<XmppService>(),
                                      mucService: context.read<XmppService>(),
                                      notificationService:
                                          context.read<NotificationService>(),
                                      emailService:
                                          context.read<EmailService>(),
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
                                      ),
                                    );
                                  },
                                ),
                                BlocProvider(
                                  create: (context) => ChatSearchCubit(
                                    jid: openJid,
                                    messageService: context.read<XmppService>(),
                                    emailService: context.read<EmailService>(),
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
                      final Widget chatPane =
                          constrainSecondary(chatPaneContent);

                      Widget chatLayout({required bool showChatCalendar}) {
                        final EdgeInsets secondaryPanePadding = showChatCalendar
                            ? EdgeInsets.zero
                            : const EdgeInsets.only(
                                left: _secondaryPaneGutter,
                              );
                        final Widget content = Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (navRail != null) navRail,
                            Expanded(
                              child: AxiAdaptiveLayout(
                                invertPriority: openJid != null,
                                showPrimary: !showChatCalendar,
                                centerSecondary: false,
                                centerPrimary: false,
                                animatePaneChanges: true,
                                primaryAlignment: Alignment.topLeft,
                                secondaryAlignment: Alignment.topLeft,
                                secondaryPadding: secondaryPanePadding,
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
                            if (navRail != null) navRail,
                            const Expanded(child: CalendarWidget()),
                          ],
                        );
                      }

                      final bool demoOffline =
                          context.read<XmppService?>()?.demoOfflineMode ??
                              false;

                      final bool showChatCalendar =
                          openJid != null && (chatRoute?.isCalendar ?? false);
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
            if (isRoster)
              BlocProvider(
                create: (context) =>
                    RosterCubit(rosterService: context.read<XmppService>()),
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
                  final emailService = context.read<EmailService?>();
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
                    availabilityCoordinator: availabilityShareCoordinator,
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
              create: (context) =>
                  ConnectivityCubit(xmppBase: context.read<XmppService>()),
            ),
            BlocProvider(
              create: (context) =>
                  EmailSyncCubit(emailService: context.read<EmailService>()),
            ),
          ],
          child: EmailForwardingWelcomeGate(child: calendarAwareContent),
        ),
      ),
    );
    Widget wrappedScaffold = scaffold;
    if (chatCalendarCoordinator != null) {
      wrappedScaffold = RepositoryProvider<ChatCalendarSyncCoordinator>.value(
        value: chatCalendarCoordinator,
        child: wrappedScaffold,
      );
    }
    if (availabilityShareCoordinator != null) {
      wrappedScaffold =
          RepositoryProvider<CalendarAvailabilityShareCoordinator>.value(
        value: availabilityShareCoordinator,
        child: wrappedScaffold,
      );
    }

    final actionLayer = BlocProvider(
      create: (context) {
        final bloc = AccessibilityActionBloc(
          chatsService: context.read<XmppService>(),
          messageService: context.read<XmppService>(),
          rosterService:
              isRoster ? context.read<XmppService>() as RosterService : null,
          initialLocalization: l10n,
        );
        return bloc;
      },
      child: Builder(
        builder: (context) {
          final platform = Theme.of(context).platform;
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
            focusNode: _shortcutFocusNode,
            autofocus: true,
            onKeyEvent: _handleHomeKeyEvent,
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
                  children: [wrappedScaffold, const AccessibilityActionMenu()],
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
