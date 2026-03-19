part of '../chat.dart';

const int _pinnedBadgeHiddenCount = 0;

ChatCalendarSyncCoordinator? _readChatCalendarCoordinator(
  BuildContext context, {
  required bool calendarAvailable,
}) => calendarAvailable ? context.read<ChatCalendarSyncCoordinator>() : null;

CalendarAvailabilityShareCoordinator? _readAvailabilityShareCoordinator(
  BuildContext context, {
  required bool calendarAvailable,
}) => calendarAvailable
    ? context.read<CalendarAvailabilityShareCoordinator>()
    : null;

class _ActionCountBadgeIcon extends StatelessWidget {
  const _ActionCountBadgeIcon({
    required this.iconData,
    required this.count,
    required this.iconColor,
  });

  final IconData iconData;
  final int count;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    final double iconSize = context.iconTheme.size ?? sizing.iconButtonIconSize;
    final icon = Icon(iconData, size: iconSize, color: iconColor);
    if (count <= _pinnedBadgeHiddenCount) {
      return icon;
    }
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          PositionedDirectional(
            top: -spacing.xs,
            end: -spacing.xs,
            child: AxiCountBadge(
              count: count,
              diameter: sizing.menuItemIconSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedBadgeIcon extends StatelessWidget {
  const _PinnedBadgeIcon({
    required this.iconData,
    required this.count,
    required this.iconColor,
  });

  final IconData iconData;
  final int count;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return _ActionCountBadgeIcon(
      iconData: iconData,
      count: count,
      iconColor: iconColor,
    );
  }
}

class _ChatCalendarScope extends StatelessWidget {
  const _ChatCalendarScope({
    required this.chat,
    required this.calendarAvailable,
    required this.coordinator,
    required this.storage,
    required this.xmppService,
    required this.emailService,
    required this.reminderController,
    required this.availabilityCoordinator,
    required this.child,
  });

  final chat_models.Chat? chat;
  final bool calendarAvailable;
  final ChatCalendarSyncCoordinator? coordinator;
  final Storage? storage;
  final XmppService xmppService;
  final EmailService? emailService;
  final CalendarReminderController reminderController;
  final CalendarAvailabilityShareCoordinator? availabilityCoordinator;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentChat = chat;
    final currentCoordinator = coordinator;
    final currentStorage = storage;
    if (!calendarAvailable ||
        currentChat == null ||
        currentCoordinator == null ||
        currentStorage == null) {
      return child;
    }
    return BlocProvider<ChatCalendarBloc>(
      key: ValueKey('chat-calendar-${currentChat.jid}'),
      create: (context) => ChatCalendarBloc(
        chatJid: currentChat.jid,
        chatType: currentChat.type,
        coordinator: currentCoordinator,
        storage: currentStorage,
        xmppService: xmppService,
        emailService: emailService,
        reminderController: reminderController,
        availabilityCoordinator: availabilityCoordinator,
      )..add(const CalendarEvent.started()),
      child: BlocListener<SettingsCubit, SettingsState>(
        listenWhen: (previous, current) =>
            previous.endpointConfig != current.endpointConfig,
        listener: (context, settings) {
          final locate = context.read;
          locate<ChatCalendarBloc>().updateEmailService(
            settings.endpointConfig.smtpEnabled ? locate<EmailService>() : null,
          );
        },
        child: child,
      ),
    );
  }
}

class _ChatCalendarPanel extends StatelessWidget {
  const _ChatCalendarPanel({
    required this.chat,
    required this.calendarAvailable,
    required this.surfacePopEnabled,
    required this.onCanHandleBackChanged,
  });

  final chat_models.Chat? chat;
  final bool calendarAvailable;
  final bool surfacePopEnabled;
  final ValueChanged<bool> onCanHandleBackChanged;

  @override
  Widget build(BuildContext context) {
    final currentChat = chat;
    if (!calendarAvailable || currentChat == null) {
      return const SizedBox.shrink();
    }
    return BlocProvider<CalendarBloc>.value(
      value: context.watch<ChatCalendarBloc>(),
      child: ChatCalendarWidget(
        chat: currentChat,
        surfacePopEnabled: surfacePopEnabled,
        showHeader: true,
        onCanHandleBackChanged: onCanHandleBackChanged,
      ),
    );
  }
}

class _ChatContentSurface extends StatelessWidget {
  const _ChatContentSurface({
    required this.chatEntity,
    required this.calendarAvailable,
    required this.resolvedChatCalendarCoordinator,
    required this.storage,
    required this.storageManager,
    required this.child,
  });

  final chat_models.Chat? chatEntity;
  final bool calendarAvailable;
  final ChatCalendarSyncCoordinator? resolvedChatCalendarCoordinator;
  final Storage? storage;
  final CalendarStorageManager storageManager;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    final emailService =
        context.watch<SettingsCubit>().state.endpointConfig.smtpEnabled
        ? locate<EmailService>()
        : null;
    final content = _ChatCalendarScope(
      chat: chatEntity,
      calendarAvailable: calendarAvailable,
      coordinator: resolvedChatCalendarCoordinator,
      storage: storage,
      xmppService: locate<XmppService>(),
      emailService: emailService,
      reminderController: locate<CalendarReminderController>(),
      availabilityCoordinator: _readAvailabilityShareCoordinator(
        context,
        calendarAvailable: storageManager.isAuthStorageReady,
      ),
      child: child,
    );
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.background,
        border: Border(left: context.borderSide),
      ),
      child: content,
    );
  }
}

class _ChatScaffoldLayout extends StatelessWidget {
  const _ChatScaffoldLayout({
    required this.owner,
    required this.state,
    required this.chatEntity,
    required this.jid,
    required this.readOnly,
    required this.isWelcomeChat,
    required this.isSelfChat,
    required this.isGroupChat,
    required this.isEmailBacked,
    required this.isEmailComposer,
    required this.chatCalendarAvailable,
    required this.personalCalendarAvailable,
    required this.showCloseButton,
    required this.canShowSettings,
    required this.isSettingsRoute,
    required this.calendarFirstRoom,
    required this.showingChatCalendar,
    required this.pinnedCount,
    required this.navigationActions,
    required this.navigationActionCount,
    required this.chatActionCount,
    required this.selfIdentity,
    required this.user,
    required this.selfAvatarPath,
    required this.selfXmppJid,
    required this.currentUserId,
    required this.myOccupantJid,
    required this.selfNick,
    required this.normalizedXmppSelfJid,
    required this.normalizedEmailSelfJid,
    required this.resolvedEmailSelfJid,
    required this.resolvedDirectChatDisplayName,
    required this.availabilityActorId,
    required this.accountJidForPins,
    required this.attachmentsBlockedForChat,
    required this.searchFiltering,
    required this.searchResults,
    required this.shareContexts,
    required this.shareReplies,
    required this.showAttachmentWarning,
    required this.retryReport,
    required this.retryShareId,
    required this.onFanOutRetry,
    required this.availableChats,
    required this.recipients,
    required this.pendingAttachments,
    required this.settingsState,
    required this.settingsSnapshot,
    required this.composerSendOnEnter,
    required this.attachmentsEnabled,
    required this.canTogglePins,
    required this.roomBootstrapInProgress,
    required this.roomJoinFailed,
    required this.roomJoinFailureState,
    required this.latestStatuses,
    required this.isChatBlocked,
    required this.chatBlocklistEntry,
    required this.blockAddress,
    required this.profileJid,
    required this.avatarPathForBareJid,
    required this.avatarPathForTypingParticipant,
    required this.onToggleCollapseLongEmails,
    required this.onExpandedComposerDraftSaved,
    required this.onClearQuote,
    required this.storageManager,
  });

  final _ChatState owner;
  final ChatState state;
  final chat_models.Chat? chatEntity;
  final String? jid;
  final bool readOnly;
  final bool isWelcomeChat;
  final bool isSelfChat;
  final bool isGroupChat;
  final bool isEmailBacked;
  final bool isEmailComposer;
  final bool chatCalendarAvailable;
  final bool personalCalendarAvailable;
  final bool showCloseButton;
  final bool canShowSettings;
  final bool isSettingsRoute;
  final bool calendarFirstRoom;
  final bool showingChatCalendar;
  final int pinnedCount;
  final List<AppBarActionItem> navigationActions;
  final int navigationActionCount;
  final int chatActionCount;
  final SelfAvatar selfIdentity;
  final ChatUser user;
  final String? selfAvatarPath;
  final String? selfXmppJid;
  final String? currentUserId;
  final String? myOccupantJid;
  final String? selfNick;
  final String? normalizedXmppSelfJid;
  final String? normalizedEmailSelfJid;
  final String? resolvedEmailSelfJid;
  final String? resolvedDirectChatDisplayName;
  final String? availabilityActorId;
  final String? accountJidForPins;
  final bool attachmentsBlockedForChat;
  final bool searchFiltering;
  final List<Message>? searchResults;
  final Map<String, ShareContext> shareContexts;
  final Map<String, List<chat_models.Chat>> shareReplies;
  final bool showAttachmentWarning;
  final FanOutSendReport? retryReport;
  final String? retryShareId;
  final VoidCallback? onFanOutRetry;
  final List<chat_models.Chat> availableChats;
  final List<ComposerRecipient> recipients;
  final List<PendingAttachment> pendingAttachments;
  final SettingsState settingsState;
  final ChatSettingsSnapshot settingsSnapshot;
  final bool composerSendOnEnter;
  final bool attachmentsEnabled;
  final bool canTogglePins;
  final bool roomBootstrapInProgress;
  final bool roomJoinFailed;
  final RoomState? roomJoinFailureState;
  final Map<String, FanOutRecipientState> latestStatuses;
  final bool isChatBlocked;
  final BlocklistEntry? chatBlocklistEntry;
  final String? blockAddress;
  final String? profileJid;
  final String? Function(String bareJid) avatarPathForBareJid;
  final String? Function(String participant) avatarPathForTypingParticipant;
  final VoidCallback onToggleCollapseLongEmails;
  final ValueChanged<int> onExpandedComposerDraftSaved;
  final VoidCallback onClearQuote;
  final CalendarStorageManager storageManager;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.spacing;
        final leadingInset = spacing.m;
        final leadingSpacing = spacing.xs;
        final actionSpacing = spacing.xxs;
        final appBarActionsPadding = spacing.s;
        final appBarTitleSpacing = spacing.m;
        final collapsedLeadingWidth = 0.0;
        final avatarTitleSpacing = spacing.m;
        final titleMinWidth = context.sizing.iconButtonTapTarget * 3;
        final showTitleAvatar = !isEmailBacked && chatEntity != null;
        final rosterItems = jid == null
            ? const <RosterItem>[]
            : context.select<RosterCubit, List<RosterItem>>(
                (cubit) => cubit.state.items ?? const <RosterItem>[],
              );
        final item = jid == null
            ? null
            : rosterItems.where((entry) => entry.jid == jid).singleOrNull;
        final canRenameContact =
            !readOnly &&
            chatEntity != null &&
            chatEntity!.type == ChatType.chat &&
            !chatEntity!.isAxichatWelcomeThread;
        final statusLabel = item?.status?.trim() ?? '';
        final addressLabel = isWelcomeChat || jid == null
            ? _emptyText
            : jid!.trim();
        const addressStatusSeparator = ' · ';
        final secondaryLabel = switch ((
          addressLabel.isNotEmpty,
          statusLabel.isNotEmpty,
        )) {
          (true, true) => '$addressLabel$addressStatusSeparator$statusLabel',
          (true, false) => addressLabel,
          (false, true) => statusLabel,
          (false, false) => _emptyText,
        };
        final avatarTooltip = isGroupChat ? context.l10n.chatRoomMembers : null;
        final baseTitleStyle = context.textTheme.h4;
        final titleStyle = baseTitleStyle.copyWith(
          fontSize: context.textTheme.large.fontSize,
        );
        final subtitleStyle = context.textTheme.muted;
        final textScaler =
            MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;

        double measureTextWidth(String text, TextStyle style) {
          final normalized = text.trim();
          if (normalized.isEmpty) {
            return 0.0;
          }
          final painter = TextPainter(
            text: TextSpan(text: normalized, style: style),
            textDirection: Directionality.of(context),
            textScaler: textScaler,
            maxLines: 1,
          )..layout();
          return painter.width;
        }

        final appBarWidth = constraints.maxWidth;
        final leadingButtonCountExpanded =
            navigationActionCount + (showCloseButton ? 1 : 0);
        final leadingWidthExpanded = leadingButtonCountExpanded == 0
            ? collapsedLeadingWidth
            : leadingInset +
                  (AxiIconButton.kTapTargetSize * leadingButtonCountExpanded) +
                  (leadingSpacing *
                      math.max(0, leadingButtonCountExpanded - 1));
        final chatActionsWidth = chatActionCount == 0
            ? 0
            : (AxiIconButton.kTapTargetSize * chatActionCount) +
                  (actionSpacing * math.max(0, chatActionCount - 1));
        final titleReserveWidth = math.max(
          titleMinWidth,
          (showTitleAvatar
                  ? context.sizing.iconButtonSize + avatarTitleSpacing
                  : 0.0) +
              math.max(
                measureTextWidth(
                  state.chat?.displayName ?? _emptyText,
                  titleStyle,
                ),
                measureTextWidth(secondaryLabel, subtitleStyle),
              ),
        );
        final actionsPaddingWidth = appBarActionsPadding * 2;
        final toolbarMiddleSpacingWidth = appBarTitleSpacing * 2;
        final trailingActionsAvailableWidth = math.max(
          0.0,
          appBarWidth -
              leadingWidthExpanded -
              titleReserveWidth -
              actionsPaddingWidth -
              toolbarMiddleSpacingWidth,
        );
        final collapseAppBarActions =
            trailingActionsAvailableWidth < chatActionsWidth;
        final visibleLeadingButtonCount =
            (showCloseButton ? 1 : 0) +
            (collapseAppBarActions ? 0 : navigationActionCount);
        final navigationActionsWidth = navigationActionCount == 0
            ? 0.0
            : (AxiIconButton.kTapTargetSize * navigationActionCount) +
                  (leadingSpacing * math.max(0, navigationActionCount - 1));
        final leadingWidth = visibleLeadingButtonCount == 0
            ? collapsedLeadingWidth
            : leadingInset +
                  (AxiIconButton.kTapTargetSize * visibleLeadingButtonCount) +
                  (leadingSpacing * math.max(0, visibleLeadingButtonCount - 1));

        return Scaffold(
          backgroundColor: context.colorScheme.background,
          appBar: _ChatScaffoldAppBar(
            owner: owner,
            state: state,
            chatEntity: chatEntity,
            jid: jid,
            selfIdentity: selfIdentity,
            isGroupChat: isGroupChat,
            isEmailBacked: isEmailBacked,
            chatCalendarAvailable: chatCalendarAvailable,
            calendarFirstRoom: calendarFirstRoom,
            showingChatCalendar: showingChatCalendar,
            canShowSettings: canShowSettings,
            isSettingsRoute: isSettingsRoute,
            showCloseButton: showCloseButton,
            collapseAppBarActions: collapseAppBarActions,
            showTitleAvatar: showTitleAvatar,
            canRenameContact: canRenameContact,
            pinnedCount: pinnedCount,
            navigationActionCount: navigationActionCount,
            visibleLeadingButtonCount: visibleLeadingButtonCount,
            navigationActions: navigationActions,
            secondaryLabel: secondaryLabel,
            avatarTooltip: avatarTooltip,
            titleStyle: titleStyle,
            subtitleStyle: subtitleStyle,
            appBarTitleSpacing: appBarTitleSpacing,
            appBarActionsPadding: appBarActionsPadding,
            leadingWidth: leadingWidth,
            leadingInset: leadingInset,
            leadingSpacing: leadingSpacing,
            navigationActionsWidth: navigationActionsWidth,
            actionSpacing: actionSpacing,
            trailingActionsAvailableWidth: trailingActionsAvailableWidth,
            avatarTitleSpacing: avatarTitleSpacing,
            onToggleCollapseLongEmails: onToggleCollapseLongEmails,
          ),
          body: _ChatScaffoldBody(
            owner: owner,
            state: state,
            chatEntity: chatEntity,
            readOnly: readOnly,
            isSelfChat: isSelfChat,
            isWelcomeChat: isWelcomeChat,
            isGroupChat: isGroupChat,
            isEmailComposer: isEmailComposer,
            chatCalendarAvailable: chatCalendarAvailable,
            personalCalendarAvailable: personalCalendarAvailable,
            currentUserId: currentUserId,
            selfXmppJid: selfXmppJid,
            selfIdentity: selfIdentity,
            selfAvatarPath: selfAvatarPath,
            myOccupantJid: myOccupantJid,
            selfNick: selfNick,
            user: user,
            normalizedXmppSelfJid: normalizedXmppSelfJid,
            normalizedEmailSelfJid: normalizedEmailSelfJid,
            resolvedEmailSelfJid: resolvedEmailSelfJid,
            resolvedDirectChatDisplayName: resolvedDirectChatDisplayName,
            availabilityActorId: availabilityActorId,
            accountJidForPins: accountJidForPins,
            attachmentsBlockedForChat: attachmentsBlockedForChat,
            searchFiltering: searchFiltering,
            searchResults: searchResults,
            shareContexts: shareContexts,
            shareReplies: shareReplies,
            showAttachmentWarning: showAttachmentWarning,
            retryReport: retryReport,
            retryShareId: retryShareId,
            onFanOutRetry: onFanOutRetry,
            availableChats: availableChats,
            recipients: recipients,
            pendingAttachments: pendingAttachments,
            settingsState: settingsState,
            settingsSnapshot: settingsSnapshot,
            composerSendOnEnter: composerSendOnEnter,
            attachmentsEnabled: attachmentsEnabled,
            canTogglePins: canTogglePins,
            roomBootstrapInProgress: roomBootstrapInProgress,
            roomJoinFailed: roomJoinFailed,
            roomJoinFailureState: roomJoinFailureState,
            latestStatuses: latestStatuses,
            canRenameContact: canRenameContact,
            isChatBlocked: isChatBlocked,
            chatBlocklistEntry: chatBlocklistEntry,
            blockAddress: blockAddress,
            isEmailBacked: isEmailBacked,
            profileJid: profileJid,
            avatarPathForBareJid: avatarPathForBareJid,
            avatarPathForTypingParticipant: avatarPathForTypingParticipant,
            onExpandedComposerDraftSaved: onExpandedComposerDraftSaved,
            onClearQuote: onClearQuote,
          ),
        );
      },
    );
  }
}

class _ChatScaffoldAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _ChatScaffoldAppBar({
    required this.owner,
    required this.state,
    required this.chatEntity,
    required this.jid,
    required this.selfIdentity,
    required this.isGroupChat,
    required this.isEmailBacked,
    required this.chatCalendarAvailable,
    required this.calendarFirstRoom,
    required this.showingChatCalendar,
    required this.canShowSettings,
    required this.isSettingsRoute,
    required this.showCloseButton,
    required this.collapseAppBarActions,
    required this.showTitleAvatar,
    required this.canRenameContact,
    required this.pinnedCount,
    required this.navigationActionCount,
    required this.visibleLeadingButtonCount,
    required this.navigationActions,
    required this.secondaryLabel,
    required this.avatarTooltip,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.appBarTitleSpacing,
    required this.appBarActionsPadding,
    required this.leadingWidth,
    required this.leadingInset,
    required this.leadingSpacing,
    required this.navigationActionsWidth,
    required this.actionSpacing,
    required this.trailingActionsAvailableWidth,
    required this.avatarTitleSpacing,
    required this.onToggleCollapseLongEmails,
  });

  final _ChatState owner;
  final ChatState state;
  final chat_models.Chat? chatEntity;
  final String? jid;
  final SelfAvatar selfIdentity;
  final bool isGroupChat;
  final bool isEmailBacked;
  final bool chatCalendarAvailable;
  final bool calendarFirstRoom;
  final bool showingChatCalendar;
  final bool canShowSettings;
  final bool isSettingsRoute;
  final bool showCloseButton;
  final bool collapseAppBarActions;
  final bool showTitleAvatar;
  final bool canRenameContact;
  final int pinnedCount;
  final int navigationActionCount;
  final int visibleLeadingButtonCount;
  final List<AppBarActionItem> navigationActions;
  final String secondaryLabel;
  final String? avatarTooltip;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final double appBarTitleSpacing;
  final double appBarActionsPadding;
  final double leadingWidth;
  final double leadingInset;
  final double leadingSpacing;
  final double navigationActionsWidth;
  final double actionSpacing;
  final double trailingActionsAvailableWidth;
  final double avatarTitleSpacing;
  final VoidCallback onToggleCollapseLongEmails;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    const IconData pinnedIcon = LucideIcons.pin;
    return AppBar(
      scrolledUnderElevation: 0,
      forceMaterialTransparency: true,
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: appBarTitleSpacing,
      shape: Border(bottom: BorderSide(color: context.colorScheme.border)),
      actionsPadding: EdgeInsets.symmetric(horizontal: appBarActionsPadding),
      leadingWidth: leadingWidth,
      leading: visibleLeadingButtonCount == 0
          ? null
          : Padding(
              padding: EdgeInsets.only(left: leadingInset),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showCloseButton)
                      AxiIconButton.ghost(
                        iconData: LucideIcons.arrowLeft,
                        tooltip: context.l10n.commonBack,
                        onPressed: () {
                          owner._dismissTextInputFocus();
                          context.read<ChatsCubit>().closeAllChats();
                        },
                      ),
                    if (showCloseButton &&
                        !collapseAppBarActions &&
                        navigationActionCount > 0)
                      SizedBox(width: leadingSpacing),
                    if (!collapseAppBarActions && navigationActionCount > 0)
                      AppBarActions(
                        actions: navigationActions,
                        spacing: leadingSpacing,
                        overflowBreakpoint: 0,
                        availableWidth: navigationActionsWidth,
                      ),
                  ],
                ),
              ),
            ),
      title: jid == null
          ? const SizedBox.shrink()
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showTitleAvatar)
                  Builder(
                    builder: (context) {
                      final avatarData = chatEntity!.avatarPresentation(
                        selfAvatar: selfIdentity,
                      );
                      Widget avatar = avatarData.isAppIcon
                          ? AxichatAppIconAvatar(
                              size: context.sizing.iconButtonSize,
                            )
                          : AvatarTransportBadgeOverlay(
                              size: context.sizing.iconButtonSize,
                              transport: chatEntity!.defaultTransport,
                              child: HydratedAxiAvatar(
                                avatar: avatarData,
                                size: context.sizing.iconButtonSize,
                              ),
                            );
                      if (avatarTooltip != null) {
                        avatar = AxiTooltip(
                          builder: (context) => Text(avatarTooltip!),
                          child: avatar,
                        );
                      }
                      if (isGroupChat) {
                        avatar = MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: owner._showMembers,
                            child: avatar,
                          ),
                        );
                      }
                      return avatar;
                    },
                  ),
                if (showTitleAvatar) SizedBox(width: avatarTitleSpacing),
                Flexible(
                  fit: FlexFit.loose,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (canRenameContact)
                                  AxiPlainHeaderButton(
                                    onPressed: owner._promptContactRename,
                                    semanticLabel:
                                        context.l10n.chatContactRenameTooltip,
                                    child: Text(
                                      state.chat?.displayName ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: titleStyle,
                                    ),
                                  )
                                else
                                  Text(
                                    state.chat?.displayName ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: titleStyle,
                                  ),
                                if (secondaryLabel.isNotEmpty)
                                  SelectableText(
                                    secondaryLabel,
                                    maxLines: 1,
                                    style: subtitleStyle,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
      actions: [
        if (jid != null)
          BlocSelector<ChatSearchCubit, ChatSearchState, bool>(
            selector: (state) => state.active,
            builder: (context, searchActive) {
              final l10n = context.l10n;
              final colors = context.colorScheme;
              final importantCount = context
                  .select<ImportantMessagesCubit, int>(
                    (cubit) => cubit.state.items?.length ?? 0,
                  );
              final importantIconColor = owner._chatRoute.isImportant
                  ? colors.primary
                  : colors.foreground;
              final pinnedIconColor = owner._pinnedPanelVisible
                  ? colors.primary
                  : colors.foreground;
              final chatActions = <AppBarActionItem>[
                if (isEmailBacked)
                  AppBarActionItem(
                    label: l10n.chatCollapseLongEmails,
                    iconData: LucideIcons.minimize2,
                    selected: owner._collapseLongEmailMessages,
                    onPressed: onToggleCollapseLongEmails,
                  ),
                if (isGroupChat)
                  AppBarActionItem(
                    label: l10n.chatRoomMembers,
                    iconData: LucideIcons.users,
                    onPressed: owner._showMembers,
                  ),
                AppBarActionItem(
                  label: searchActive
                      ? l10n.chatSearchClose
                      : l10n.chatSearchMessages,
                  iconData: LucideIcons.search,
                  selected: owner._chatRoute.isSearch,
                  onPressed: () =>
                      context.read<ChatSearchCubit>().toggleActive(),
                ),
                AppBarActionItem(
                  label: l10n.chatAttachmentTooltip,
                  iconData: LucideIcons.image,
                  selected: owner._chatRoute.isGallery,
                  onPressed: owner._openChatAttachments,
                ),
                AppBarActionItem(
                  label: owner._chatRoute.isImportant
                      ? l10n.commonClose
                      : l10n.chatImportantMessagesTooltip,
                  iconData: Icons.star_outline_rounded,
                  icon: _ActionCountBadgeIcon(
                    iconData: Icons.star_outline_rounded,
                    count: importantCount,
                    iconColor: importantIconColor,
                  ),
                  selected: owner._chatRoute.isImportant,
                  onPressed: owner._toggleImportantMessagesRoute,
                ),
                AppBarActionItem(
                  label: owner._pinnedPanelVisible
                      ? l10n.commonClose
                      : l10n.chatPinnedMessagesTooltip,
                  iconData: pinnedIcon,
                  icon: _PinnedBadgeIcon(
                    iconData: pinnedIcon,
                    count: pinnedCount,
                    iconColor: pinnedIconColor,
                  ),
                  selected: owner._pinnedPanelVisible,
                  onPressed: owner._togglePinnedMessages,
                ),
                if (chatCalendarAvailable)
                  calendarFirstRoom
                      ? AppBarActionItem(
                          label: showingChatCalendar
                              ? l10n.sessionCapabilityChat
                              : l10n.homeRailCalendar,
                          iconData: showingChatCalendar
                              ? LucideIcons.messagesSquare
                              : LucideIcons.calendarClock,
                          onPressed: () {
                            if (showingChatCalendar) {
                              owner._returnToMainRoute();
                              return;
                            }
                            owner._openChatCalendar();
                          },
                        )
                      : AppBarActionItem(
                          label: showingChatCalendar
                              ? l10n.commonClose
                              : l10n.homeRailCalendar,
                          iconData: LucideIcons.calendarClock,
                          selected: showingChatCalendar,
                          onPressed: () {
                            if (showingChatCalendar) {
                              owner._closeChatCalendar();
                              return;
                            }
                            owner._openChatCalendar();
                          },
                        ),
                if (canShowSettings)
                  AppBarActionItem(
                    label: isSettingsRoute
                        ? l10n.chatCloseSettings
                        : l10n.chatSettings,
                    iconData: LucideIcons.settings,
                    selected: isSettingsRoute,
                    onPressed: owner._toggleSettingsPanel,
                  ),
              ];
              final combinedActions = collapseAppBarActions
                  ? <AppBarActionItem>[...navigationActions, ...chatActions]
                  : chatActions;
              return AppBarActions(
                actions: combinedActions,
                spacing: actionSpacing,
                overflowBreakpoint: 0,
                availableWidth: trailingActionsAvailableWidth,
                forceCollapsed: collapseAppBarActions ? true : null,
              );
            },
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
