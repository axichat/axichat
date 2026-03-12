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
import 'package:axichat/src/blocklist/view/blocklist_notice_l10n.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
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
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
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
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/attachment_optimizer.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/view/email_forwarding_guide.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/home/home_search_definitions.dart';
import 'package:axichat/src/home/home_search_models.dart';
import 'package:axichat/src/important/bloc/important_messages_cubit.dart';
import 'package:axichat/src/important/models/important_message_item.dart';
import 'package:axichat/src/important/view/important_messages_list.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/omemo_operation_overlay.dart';
import 'package:axichat/src/notifications/view/xmpp_operation_overlay.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/view/session_capability_indicators.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/share/bloc/share_intent_cubit.dart';
import 'package:axichat/src/spam/view/spam_list.dart';
import 'package:axichat/src/storage/models.dart' as m;
import 'package:axichat/src/xmpp/xmpp_service.dart';
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

part 'home/view/home_screen_widgets.dart';

List<HomeSearchFilter> _draftsSearchFilters(AppLocalizations l10n) => [
  HomeSearchFilter(id: SearchFilterId.all, label: l10n.draftsFilterAll),
  HomeSearchFilter(
    id: SearchFilterId.attachments,
    label: l10n.draftsFilterAttachments,
  ),
];

class _GlobalImportantMessagesTab extends StatefulWidget {
  const _GlobalImportantMessagesTab();

  @override
  State<_GlobalImportantMessagesTab> createState() =>
      _GlobalImportantMessagesTabState();
}

class _GlobalImportantMessagesTabState
    extends State<_GlobalImportantMessagesTab> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSearchState(context, context.read<HomeSearchCubit>().state);
  }

  void _syncSearchState(BuildContext context, HomeSearchState searchState) {
    final tabState = searchState.stateFor(HomeTab.important);
    final query = searchState.active ? tabState.query : '';
    context.read<ImportantMessagesCubit>().updateFilter(
      query: query,
      sortOrder: tabState.sort,
    );
  }

  Future<void> _openItem(ImportantMessageItem item) async {
    await context.read<ChatsCubit>().openImportantMessage(
      jid: item.chatJid,
      messageReferenceId: item.messageReferenceId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeSearchCubit, HomeSearchState>(
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

class HomeShellScope extends InheritedWidget {
  const HomeShellScope({
    super.key,
    required this.calendarBottomDragSession,
    required this.bottomNavIndex,
    required this.homeTabIndex,
    required this.tabs,
    required super.child,
  });

  final ValueNotifier<CalendarBottomDragSession?> calendarBottomDragSession;
  final ValueNotifier<int> bottomNavIndex;
  final ValueNotifier<int> homeTabIndex;
  final List<HomeTabEntry> tabs;

  static HomeShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeShellScope>();
  }

  @override
  bool updateShouldNotify(HomeShellScope oldWidget) {
    return calendarBottomDragSession != oldWidget.calendarBottomDragSession ||
        bottomNavIndex != oldWidget.bottomNavIndex ||
        homeTabIndex != oldWidget.homeTabIndex ||
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
    final shell = HomeShell(navigationShell: navigationShell);
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
  final ValueNotifier<int> _homeTabIndex = ValueNotifier<int>(0);
  bool _railCollapsed = true;

  @override
  void initState() {
    super.initState();
    _bottomNavIndex.addListener(_handleBottomNavIndexSelection);
  }

  @override
  void dispose() {
    _bottomNavIndex.removeListener(_handleBottomNavIndexSelection);
    _calendarBottomDragSession.dispose();
    _bottomNavIndex.dispose();
    _homeTabIndex.dispose();
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

  void _onBottomNavSelected(int index) {
    assert(index >= 0 && index <= 3, 'bottom nav index must be 0..3');
    if (index < 0 || index > 3) {
      return;
    }
    if (index == _profileBottomNavIndex) {
      if (widget.navigationShell.currentIndex == _profileBranchIndex) {
        return;
      }
      widget.navigationShell.goBranch(_profileBranchIndex);
      return;
    }
    final safeIndex = index.clamp(0, 2).toInt();
    if (_bottomNavIndex.value != safeIndex) {
      _bottomNavIndex.value = safeIndex;
    }
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
    final isChatOpen = chatsState.openJid != null;
    final isChatCalendarRoute = chatsState.openChatRoute.isCalendar;
    final chatItems = chatsState.items ?? const <m.Chat>[];
    final badgeCounts = <HomeTab, int>{
      HomeTab.chats: chatItems
          .where((chat) => !chat.archived && !chat.spam && !chat.hidden)
          .fold<int>(0, (sum, chat) => sum + math.max(0, chat.unreadCount)),
      HomeTab.drafts: context.watch<DraftCubit>().state.items?.length ?? 0,
      HomeTab.spam: chatItems
          .where((chat) => chat.spam && !chat.archived)
          .length,
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
        id: HomeTab.important,
        label: l10n.homeTabImportant,
        body: BlocProvider(
          create: (context) =>
              ImportantMessagesCubit(xmppService: context.read<XmppService>()),
          child: const _GlobalImportantMessagesTab(),
        ),
        fab: showDesktopPrimaryActions
            ? const _TabActionGroup(includePrimaryActions: true)
            : null,
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
    ];

    Widget buildShellChild(Widget child) {
      return BlocProvider(
        create: (context) {
          final locate = context.read;
          return AccessibilityActionBloc(
            chatsService: locate<XmppService>(),
            messageService: locate<XmppService>(),
            rosterService: locate<XmppService>() as RosterService,
          );
        },
        child: HomeShellScope(
          calendarBottomDragSession: _calendarBottomDragSession,
          bottomNavIndex: _bottomNavIndex,
          homeTabIndex: _homeTabIndex,
          tabs: tabs,
          child: child,
        ),
      );
    }

    if (navPlacement != NavPlacement.bottom) {
      return buildShellChild(
        ValueListenableBuilder<int>(
          valueListenable: _bottomNavIndex,
          builder: (context, homeBottomIndex, _) {
            final selectedBottomIndex = _selectedBottomNavIndex(
              homeBottomIndex,
            );
            return _HomeShellRailLayout(
              tabs: tabs,
              homeTabIndex: _homeTabIndex,
              bottomNavIndex: _bottomNavIndex,
              selectedBottomIndex: selectedBottomIndex,
              calendarAvailable: calendarAvailable,
              collapsed: _railCollapsed,
              badgeCounts: badgeCounts,
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
      ValueListenableBuilder<int>(
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
  ValueNotifier<int>? _bottomNavIndexNotifier;

  @override
  void dispose() {
    unawaited(_shareIntentRequestSubscription.cancel());
    unawaited(_shareIntentRequests.close());
    _shortcutFocusNode.dispose();
    _clearOpenChatHistoryEntry();
    _clearOpenCalendarHistoryEntry();
    _bottomNavIndexNotifier?.removeListener(_handleBottomNavIndexChanged);
    _bottomNavIndexNotifier = null;
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
      notifier.value = 0;
    }
  }

  void _clearOpenCalendarHistoryEntry() {
    final entry = _openCalendarHistoryEntry;
    _openCalendarHistoryEntry = null;
    entry?.remove();
  }

  void _updateOpenCalendarHistoryEntry() {
    final route = ModalRoute.of(context);
    if (route == null || !_isPrimaryCalendarActive) {
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
    final messageService = context.read<MessageService>();
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
    final List<EmailAttachment> prepared = await _prepareSharedAttachments(
      attachments: attachments,
      optimize: true,
    );
    if (prepared.isEmpty) {
      return const <String>[];
    }
    return messageService.persistDraftAttachmentMetadata(prepared);
  }

  Future<List<EmailAttachment>> _prepareSharedAttachments({
    required List<ShareAttachmentPayload> attachments,
    required bool optimize,
  }) async {
    if (attachments.isEmpty) {
      return const <EmailAttachment>[];
    }
    final List<EmailAttachment> prepared = <EmailAttachment>[];
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
      EmailAttachment emailAttachment = EmailAttachment(
        path: normalizedPath,
        fileName: fileName,
        sizeBytes: resolvedSizeBytes,
        mimeType: mimeType,
      );
      if (optimize) {
        emailAttachment = await EmailAttachmentOptimizer.optimize(
          emailAttachment,
        );
      }
      prepared.add(emailAttachment);
    }
    return List<EmailAttachment>.unmodifiable(prepared);
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
    final nextBottomNav = HomeShellScope.maybeOf(context)?.bottomNavIndex;
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
    final homeTabIndex = HomeShellScope.maybeOf(context)?.homeTabIndex;
    final bottomNavIndex = HomeShellScope.maybeOf(context)?.bottomNavIndex;
    final calendarBottomDragSession = HomeShellScope.maybeOf(
      context,
    )?.calendarBottomDragSession;
    final tabs =
        HomeShellScope.maybeOf(context)?.tabs ?? const <HomeTabEntry>[];
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

  final ValueNotifier<int>? homeTabIndex;
  final ValueNotifier<int>? bottomNavIndex;
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
        final content = BlocSelector<ChatsCubit, ChatsState, bool>(
          selector: (state) => state.openStack.isNotEmpty,
          builder: (context, hasOpenChatStack) {
            final selectedBottomIndex = bottomNotifier?.value ?? 0;
            final bool isPrimaryCalendar =
                selectedBottomIndex == 1 || selectedBottomIndex == 2;
            final canPop =
                isPrimaryCalendar || hasOpenChatStack || activeIndex == 0;
            return PopScope(
              canPop: canPop,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop || canPop) {
                  return;
                }
                if (homeNotifier.value != 0) {
                  homeNotifier.value = 0;
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
          builder: (context, _, _) => content,
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
    required this.bottomNavIndex,
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
  final ValueNotifier<int>? bottomNavIndex;
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
                        final Widget chatPaneContent = openJid == null
                            ? const GuestChat()
                            : const Chat();
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

                        Widget calendarLayout({
                          required int? calendarTabIndex,
                          required bool surfacePopEnabled,
                        }) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: CalendarWidget(
                                  mobileTabIndex: calendarTabIndex,
                                  surfacePopEnabled: surfacePopEnabled,
                                  onMobileTabIndexChanged: (tabIndex) {
                                    final safeTab = tabIndex
                                        .clamp(0, 1)
                                        .toInt();
                                    final scope = HomeShellScope.maybeOf(
                                      context,
                                    );
                                    if (scope != null) {
                                      scope.bottomNavIndex.value = safeTab == 0
                                          ? 1
                                          : 2;
                                    }
                                  },
                                  bottomDragSession: calendarBottomDragSession,
                                ),
                              ),
                            ],
                          );
                        }

                        Widget contentForBottomIndex(int selectedBottomIndex) {
                          final bool openCalendar =
                              (selectedBottomIndex == 1 ||
                              selectedBottomIndex == 2);
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
      },
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
        navPlacement != NavPlacement.bottom || openJid != null;

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
          create: (context) => ImportantMessagesCubit(
            xmppService: context.read<XmppService>(),
            chatJid: resolvedJid,
          ),
        ),
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
                  final scope = HomeShellScope.maybeOf(context);
                  final int currentIndex = (scope?.bottomNavIndex.value ?? 0)
                      .clamp(0, 3)
                      .toInt();
                  if (currentIndex == 1 || currentIndex == 2) {
                    if (scope != null) {
                      scope.bottomNavIndex.value = 0;
                    }
                    return null;
                  }
                  if (scope != null) {
                    scope.bottomNavIndex.value = 1;
                  }
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
