part of '../chat.dart';

const String _chatCalendarPanelKeyPrefix = 'chat-calendar-';
const String _chatPanelKeyFallback = '';
const Curve _chatOverlayFadeCurve = Curves.easeOutCubic;
const Offset _chatCalendarSlideOffset = Offset(0.0, 0.04);
const double _chatCalendarTransitionVisibleValue = 1.0;
const double _chatCalendarTransitionHiddenValue = 0.0;

class _RoomMembersDrawerContent extends StatelessWidget {
  const _RoomMembersDrawerContent({
    required this.onInvite,
    required this.onAction,
    required this.onOpenDirectChat,
    required this.onChangeNickname,
    required this.onLeaveRoom,
    required this.onDestroyRoom,
    required this.onClose,
  });

  final ValueChanged<String> onInvite;
  final Future<void> Function(
    String occupantId,
    MucModerationAction action,
    String actionLabel,
  )
  onAction;
  final Future<void> Function(String jid) onOpenDirectChat;
  final ValueChanged<String> onChangeNickname;
  final Future<void> Function() onLeaveRoom;
  final Future<void> Function() onDestroyRoom;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final l10n = context.l10n;
        final roomState = state.roomState;
        if (roomState == null ||
            (!roomState.isReadyForMessaging &&
                !roomState.hasJoinError &&
                !roomState.hasTerminalExit)) {
          final colors = context.colorScheme;
          final textTheme = context.textTheme;
          final spacing = context.spacing;
          return SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AxiProgressIndicator(
                    color: colors.foreground,
                    semanticsLabel: l10n.chatMembersLoading,
                  ),
                  SizedBox(height: spacing.s),
                  Text(
                    l10n.chatMembersLoadingEllipsis,
                    style: textTheme.muted.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return RoomMembersSheet(
          roomState: roomState,
          memberSections: state.roomMemberSections,
          avatarUpdateInFlight: state.roomAvatarUpdateStatus.isLoading,
          canInvite:
              roomState.myAffiliation.isOwner ||
              roomState.myAffiliation.isAdmin ||
              roomState.myRole.isModerator,
          onInvite: onInvite,
          onAction: onAction,
          onOpenDirectChat: onOpenDirectChat,
          roomAvatarPath: state.chat?.avatarPath,
          onChangeNickname: onChangeNickname,
          onLeaveRoom: onLeaveRoom,
          onDestroyRoom: onDestroyRoom,
          currentNickname: roomState.selfNick,
          onClose: onClose,
          useSurface: true,
        );
      },
    );
  }
}

class _ChatDetailsOverlay extends StatelessWidget {
  const _ChatDetailsOverlay({
    required this.onAddRecipient,
    required this.loadedEmailImageMessageIds,
    required this.onEmailImagesApproved,
  });

  final ValueChanged<chat_models.Chat> onAddRecipient;
  final Set<String> loadedEmailImageMessageIds;
  final ValueChanged<String> onEmailImagesApproved;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colorScheme.background,
      child: SafeArea(
        top: false,
        child: _ChatSubrouteShell(
          title: context.l10n.chatActionDetails,
          child: ChatMessageDetails(
            onAddRecipient: onAddRecipient,
            loadedEmailImageMessageIds: loadedEmailImageMessageIds,
            onEmailImagesApproved: onEmailImagesApproved,
          ),
        ),
      ),
    );
  }
}

class _ChatSubrouteShell extends StatelessWidget {
  const _ChatSubrouteShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChatIndexedHeader(
          title: title,
          onClose: () {
            context.read<ChatsCubit>().setOpenChatRoute(
              route: ChatRouteIndex.main,
            );
          },
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _ChatIndexedHeader extends StatelessWidget {
  const _ChatIndexedHeader({
    required this.title,
    required this.onClose,
    this.padding,
  });

  final String title;
  final VoidCallback onClose;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Padding(
      padding: padding ?? EdgeInsets.all(spacing.m),
      child: Row(
        children: [
          AxiIconButton.ghost(
            iconData: LucideIcons.x,
            tooltip: context.l10n.commonClose,
            onPressed: onClose,
          ),
          SizedBox(width: spacing.s),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.large,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatSettingsOverlay extends StatelessWidget {
  const _ChatSettingsOverlay({
    required this.state,
    required this.onViewFilterChanged,
    required this.onToggleNotifications,
    required this.onSpamToggle,
    required this.onRenameContact,
    required this.isChatBlocked,
    required this.blocklistEntry,
    required this.blockAddress,
  });

  final ChatState state;
  final ValueChanged<MessageTimelineFilter> onViewFilterChanged;
  final ValueChanged<bool> onToggleNotifications;
  final ValueChanged<bool> onSpamToggle;
  final VoidCallback? onRenameContact;
  final bool isChatBlocked;
  final BlocklistEntry? blocklistEntry;
  final String? blockAddress;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colorScheme.background,
      child: SafeArea(
        top: false,
        child: _ChatSubrouteShell(
          title: context.l10n.chatSettings,
          child: _ChatSettingsButtons(
            state: state,
            onViewFilterChanged: onViewFilterChanged,
            onToggleNotifications: onToggleNotifications,
            onSpamToggle: onSpamToggle,
            onRenameContact: onRenameContact,
            isChatBlocked: isChatBlocked,
            blocklistEntry: blocklistEntry,
            blockAddress: blockAddress,
          ),
        ),
      ),
    );
  }
}

class _ChatGalleryOverlay extends StatelessWidget {
  const _ChatGalleryOverlay({required this.chat});

  final chat_models.Chat? chat;

  @override
  Widget build(BuildContext context) {
    final currentChat = chat;
    if (currentChat == null) {
      return const SizedBox.shrink();
    }
    return BlocProvider(
      create: (context) {
        final endpointConfig = context
            .read<SettingsCubit>()
            .state
            .endpointConfig;
        final emailService = endpointConfig.smtpEnabled
            ? context.read<EmailService>()
            : null;
        return AttachmentGalleryBloc(
          xmppService: context.read<XmppService>(),
          emailService: emailService,
          chatJid: currentChat.jid,
          chatOverride: currentChat,
          showChatLabel: false,
        );
      },
      child: ColoredBox(
        color: context.colorScheme.background,
        child: SafeArea(
          top: false,
          child: _ChatSubrouteShell(
            title: context.l10n.chatAttachmentTooltip,
            child: AttachmentGalleryView(
              chatOverride: currentChat,
              showChatLabel: false,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatImportantOverlay extends StatelessWidget {
  const _ChatImportantOverlay({required this.onMessageSelected});

  final ValueChanged<String> onMessageSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colorScheme.background,
      child: SafeArea(
        top: false,
        child: _ChatSubrouteShell(
          title: context.l10n.chatImportantMessagesTooltip,
          child: ImportantMessagesList(
            onPressed: (item) => onMessageSelected(item.messageReferenceId),
          ),
        ),
      ),
    );
  }
}

class _ChatCalendarOverlay extends StatelessWidget {
  const _ChatCalendarOverlay({
    super.key,
    required this.chat,
    required this.calendarAvailable,
  });

  final chat_models.Chat? chat;
  final bool calendarAvailable;

  @override
  Widget build(BuildContext context) {
    final currentChat = chat;
    if (!calendarAvailable || currentChat == null) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: context.colorScheme.background,
      child: SafeArea(
        top: false,
        child: _ChatCalendarPanel(
          chat: currentChat,
          calendarAvailable: calendarAvailable,
        ),
      ),
    );
  }
}

class _ChatCalendarOverlayVisibility extends StatefulWidget {
  const _ChatCalendarOverlayVisibility({
    required this.visible,
    required this.duration,
    required this.curve,
    required this.useDesktopFade,
    required this.child,
  });

  final bool visible;
  final Duration duration;
  final Curve curve;
  final bool useDesktopFade;
  final Widget child;

  @override
  State<_ChatCalendarOverlayVisibility> createState() =>
      _ChatCalendarOverlayVisibilityState();
}

class _ChatCalendarOverlayVisibilityState
    extends State<_ChatCalendarOverlayVisibility>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller0 = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.visible
        ? _chatCalendarTransitionVisibleValue
        : _chatCalendarTransitionHiddenValue,
  );

  late CurvedAnimation curve0 = CurvedAnimation(
    parent: controller0,
    curve: widget.curve,
    reverseCurve: widget.curve,
  );

  late Animation<double> opacity = curve0;
  late Animation<Offset> slide = Tween<Offset>(
    begin: _chatCalendarSlideOffset,
    end: Offset.zero,
  ).animate(curve0);

  @override
  void didUpdateWidget(_ChatCalendarOverlayVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      controller0.duration = widget.duration;
      syncVisibility();
    }
    if (oldWidget.curve != widget.curve) {
      curve0 = CurvedAnimation(
        parent: controller0,
        curve: widget.curve,
        reverseCurve: widget.curve,
      );
      opacity = curve0;
      slide = Tween<Offset>(
        begin: _chatCalendarSlideOffset,
        end: Offset.zero,
      ).animate(curve0);
    }
    if (oldWidget.visible != widget.visible) {
      syncVisibility();
    }
  }

  void syncVisibility() {
    final double target = widget.visible
        ? _chatCalendarTransitionVisibleValue
        : _chatCalendarTransitionHiddenValue;
    if (widget.duration == Duration.zero) {
      controller0
        ..stop()
        ..value = target;
      return;
    }
    controller0.animateTo(
      target,
      duration: widget.duration,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    controller0.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool visible = widget.visible;
    final Widget transitionChild = widget.useDesktopFade
        ? FadeTransition(opacity: opacity, child: widget.child)
        : SlideTransition(
            position: slide,
            child: FadeScaleTransition(animation: opacity, child: widget.child),
          );
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(excluding: !visible, child: transitionChild),
    );
  }
}

class _ChatRouteOverlayStack extends StatelessWidget {
  const _ChatRouteOverlayStack({
    required this.chatMainBody,
    required this.currentRoute,
    required this.previousRoute,
    required this.chatEntity,
    required this.calendarAvailable,
    required this.state,
    required this.canRenameContact,
    required this.isChatBlocked,
    required this.chatBlocklistEntry,
    required this.blockAddress,
    required this.loadedEmailImageMessageIds,
    required this.onEmailImagesApproved,
    required this.onAddRecipientFromChat,
    required this.onViewFilterChanged,
    required this.onToggleNotifications,
    required this.onSpamToggle,
    required this.onRenameContact,
    required this.onImportantMessageSelected,
  });

  final Widget chatMainBody;
  final ChatRouteIndex currentRoute;
  final ChatRouteIndex previousRoute;
  final chat_models.Chat? chatEntity;
  final bool calendarAvailable;
  final ChatState state;
  final bool canRenameContact;
  final bool isChatBlocked;
  final BlocklistEntry? chatBlocklistEntry;
  final String? blockAddress;
  final Set<String> loadedEmailImageMessageIds;
  final ValueChanged<String> onEmailImagesApproved;
  final void Function(chat_models.Chat chat) onAddRecipientFromChat;
  final ValueChanged<MessageTimelineFilter> onViewFilterChanged;
  final ValueChanged<bool> onToggleNotifications;
  final Future<void> Function({required bool sendToSpam}) onSpamToggle;
  final Future<void> Function()? onRenameContact;
  final ValueChanged<String> onImportantMessageSelected;

  @override
  Widget build(BuildContext context) {
    final isDesktopPlatform =
        EnvScope.maybeOf(context)?.isDesktopPlatform ?? false;
    final isLeavingToMain = currentRoute.isMain && !previousRoute.isMain;
    final isOverlaySwap = !currentRoute.isMain && !previousRoute.isMain;
    final isCalendarEnter = currentRoute.isCalendar;
    final chatRouteKey = ValueKey(currentRoute);
    final overlayDuration =
        isDesktopPlatform &&
            (currentRoute.isCalendar || previousRoute.isCalendar)
        ? Duration.zero
        : context.watch<SettingsCubit>().animationDuration;
    return Stack(
      fit: StackFit.expand,
      children: [
        chatMainBody,
        _ChatRouteOverlaySwitcher(
          currentRoute: currentRoute,
          chatEntity: chatEntity,
          state: state,
          canRenameContact: canRenameContact,
          isChatBlocked: isChatBlocked,
          chatBlocklistEntry: chatBlocklistEntry,
          blockAddress: blockAddress,
          loadedEmailImageMessageIds: loadedEmailImageMessageIds,
          onEmailImagesApproved: onEmailImagesApproved,
          onAddRecipientFromChat: onAddRecipientFromChat,
          onViewFilterChanged: onViewFilterChanged,
          onToggleNotifications: onToggleNotifications,
          onSpamToggle: onSpamToggle,
          onRenameContact: onRenameContact,
          onImportantMessageSelected: onImportantMessageSelected,
          chatRouteKey: chatRouteKey,
          isLeavingToMain: isLeavingToMain,
          isOverlaySwap: isOverlaySwap,
          isCalendarEnter: isCalendarEnter,
          isDesktopPlatform: isDesktopPlatform,
          overlayDuration: overlayDuration,
        ),
        _ChatCalendarOverlayVisibility(
          visible: currentRoute.isCalendar,
          duration: overlayDuration,
          curve: _chatOverlayFadeCurve,
          useDesktopFade: isDesktopPlatform,
          child: _ChatCalendarOverlay(
            key: ValueKey(
              '$_chatCalendarPanelKeyPrefix${chatEntity?.jid ?? _chatPanelKeyFallback}',
            ),
            chat: chatEntity,
            calendarAvailable: calendarAvailable,
          ),
        ),
      ],
    );
  }
}

class _ChatRouteOverlayChild extends StatelessWidget {
  const _ChatRouteOverlayChild({
    required this.currentRoute,
    required this.chatEntity,
    required this.state,
    required this.canRenameContact,
    required this.isChatBlocked,
    required this.chatBlocklistEntry,
    required this.blockAddress,
    required this.loadedEmailImageMessageIds,
    required this.onEmailImagesApproved,
    required this.onAddRecipientFromChat,
    required this.onViewFilterChanged,
    required this.onToggleNotifications,
    required this.onSpamToggle,
    required this.onRenameContact,
    required this.onImportantMessageSelected,
  });

  final ChatRouteIndex currentRoute;
  final chat_models.Chat? chatEntity;
  final ChatState state;
  final bool canRenameContact;
  final bool isChatBlocked;
  final BlocklistEntry? chatBlocklistEntry;
  final String? blockAddress;
  final Set<String> loadedEmailImageMessageIds;
  final ValueChanged<String> onEmailImagesApproved;
  final void Function(chat_models.Chat chat) onAddRecipientFromChat;
  final ValueChanged<MessageTimelineFilter> onViewFilterChanged;
  final ValueChanged<bool> onToggleNotifications;
  final Future<void> Function({required bool sendToSpam}) onSpamToggle;
  final Future<void> Function()? onRenameContact;
  final ValueChanged<String> onImportantMessageSelected;

  @override
  Widget build(BuildContext context) {
    return switch (currentRoute) {
      ChatRouteIndex.main => const SizedBox.expand(),
      ChatRouteIndex.search => const SizedBox.expand(),
      ChatRouteIndex.details => _ChatDetailsOverlay(
        onAddRecipient: onAddRecipientFromChat,
        loadedEmailImageMessageIds: loadedEmailImageMessageIds,
        onEmailImagesApproved: onEmailImagesApproved,
      ),
      ChatRouteIndex.settings => _ChatSettingsOverlay(
        state: state,
        onViewFilterChanged: onViewFilterChanged,
        onToggleNotifications: onToggleNotifications,
        onSpamToggle: (sendToSpam) => onSpamToggle(sendToSpam: sendToSpam),
        onRenameContact: canRenameContact ? onRenameContact : null,
        isChatBlocked: isChatBlocked,
        blocklistEntry: chatBlocklistEntry,
        blockAddress: blockAddress,
      ),
      ChatRouteIndex.important => _ChatImportantOverlay(
        onMessageSelected: onImportantMessageSelected,
      ),
      ChatRouteIndex.gallery => _ChatGalleryOverlay(chat: chatEntity),
      ChatRouteIndex.calendar => const SizedBox.expand(),
    };
  }
}

class _ChatRouteOverlaySwitcher extends StatelessWidget {
  const _ChatRouteOverlaySwitcher({
    required this.currentRoute,
    required this.chatEntity,
    required this.state,
    required this.canRenameContact,
    required this.isChatBlocked,
    required this.chatBlocklistEntry,
    required this.blockAddress,
    required this.loadedEmailImageMessageIds,
    required this.onEmailImagesApproved,
    required this.onAddRecipientFromChat,
    required this.onViewFilterChanged,
    required this.onToggleNotifications,
    required this.onSpamToggle,
    required this.onRenameContact,
    required this.onImportantMessageSelected,
    required this.chatRouteKey,
    required this.isLeavingToMain,
    required this.isOverlaySwap,
    required this.isCalendarEnter,
    required this.isDesktopPlatform,
    required this.overlayDuration,
  });

  final ChatRouteIndex currentRoute;
  final chat_models.Chat? chatEntity;
  final ChatState state;
  final bool canRenameContact;
  final bool isChatBlocked;
  final BlocklistEntry? chatBlocklistEntry;
  final String? blockAddress;
  final Set<String> loadedEmailImageMessageIds;
  final ValueChanged<String> onEmailImagesApproved;
  final void Function(chat_models.Chat chat) onAddRecipientFromChat;
  final ValueChanged<MessageTimelineFilter> onViewFilterChanged;
  final ValueChanged<bool> onToggleNotifications;
  final Future<void> Function({required bool sendToSpam}) onSpamToggle;
  final Future<void> Function()? onRenameContact;
  final ValueChanged<String> onImportantMessageSelected;
  final Key chatRouteKey;
  final bool isLeavingToMain;
  final bool isOverlaySwap;
  final bool isCalendarEnter;
  final bool isDesktopPlatform;
  final Duration overlayDuration;

  @override
  Widget build(BuildContext context) {
    return PageTransitionSwitcher(
      reverse: isLeavingToMain,
      duration: overlayDuration,
      layoutBuilder: (entries) =>
          Stack(fit: StackFit.expand, children: entries),
      transitionBuilder: (child, primaryAnimation, secondaryAnimation) =>
          _ChatRouteOverlayTransition(
            chatRouteKey: chatRouteKey,
            primaryAnimation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            isLeavingToMain: isLeavingToMain,
            isOverlaySwap: isOverlaySwap,
            isCalendarEnter: isCalendarEnter,
            isDesktopPlatform: isDesktopPlatform,
            child: child,
          ),
      child: KeyedSubtree(
        key: chatRouteKey,
        child: _ChatRouteOverlayChild(
          currentRoute: currentRoute,
          chatEntity: chatEntity,
          state: state,
          canRenameContact: canRenameContact,
          isChatBlocked: isChatBlocked,
          chatBlocklistEntry: chatBlocklistEntry,
          blockAddress: blockAddress,
          loadedEmailImageMessageIds: loadedEmailImageMessageIds,
          onEmailImagesApproved: onEmailImagesApproved,
          onAddRecipientFromChat: onAddRecipientFromChat,
          onViewFilterChanged: onViewFilterChanged,
          onToggleNotifications: onToggleNotifications,
          onSpamToggle: onSpamToggle,
          onRenameContact: onRenameContact,
          onImportantMessageSelected: onImportantMessageSelected,
        ),
      ),
    );
  }
}

class _ChatRouteOverlayTransition extends StatelessWidget {
  const _ChatRouteOverlayTransition({
    required this.child,
    required this.chatRouteKey,
    required this.primaryAnimation,
    required this.secondaryAnimation,
    required this.isLeavingToMain,
    required this.isOverlaySwap,
    required this.isCalendarEnter,
    required this.isDesktopPlatform,
  });

  final Widget child;
  final Key chatRouteKey;
  final Animation<double> primaryAnimation;
  final Animation<double> secondaryAnimation;
  final bool isLeavingToMain;
  final bool isOverlaySwap;
  final bool isCalendarEnter;
  final bool isDesktopPlatform;

  @override
  Widget build(BuildContext context) {
    final isExiting = child.key != chatRouteKey;
    final enterAnimation = CurvedAnimation(
      parent: primaryAnimation,
      curve: _chatOverlayFadeCurve,
      reverseCurve: Curves.easeInCubic,
    );
    final exitAnimation = CurvedAnimation(
      parent: isLeavingToMain ? primaryAnimation : secondaryAnimation,
      curve: _chatOverlayFadeCurve,
      reverseCurve: Curves.easeInCubic,
    );
    if (isExiting) {
      final exiting = isOverlaySwap
          ? child
          : FadeTransition(opacity: exitAnimation, child: child);
      return IgnorePointer(
        ignoring: true,
        child: ExcludeSemantics(excluding: true, child: exiting),
      );
    }
    final entering = isCalendarEnter
        ? (isDesktopPlatform
              ? FadeTransition(opacity: enterAnimation, child: child)
              : SlideTransition(
                  position: Tween<Offset>(
                    begin: _chatCalendarSlideOffset,
                    end: Offset.zero,
                  ).animate(enterAnimation),
                  child: FadeScaleTransition(
                    animation: enterAnimation,
                    child: child,
                  ),
                ))
        : FadeTransition(opacity: enterAnimation, child: child);
    return IgnorePointer(
      ignoring: false,
      child: ExcludeSemantics(excluding: false, child: entering),
    );
  }
}
