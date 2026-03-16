part of '../chat.dart';

final _selectionSpacerTimestamp = DateTime.fromMillisecondsSinceEpoch(
  0,
  isUtc: true,
);
const _composerOverlaySpacerMessageId = '__composer_overlay_spacer__';
const _emptyStateMessageId = '__empty_state__';
const _unreadDividerMessageId = '__unread_divider__';

class _ChatTopPanelVisibility extends StatelessWidget {
  const _ChatTopPanelVisibility({required this.visible, this.child});

  final bool visible;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final duration = context.watch<SettingsCubit>().animationDuration;
    final currentChild = visible && child != null
        ? child!
        : const SizedBox.shrink(key: ValueKey<String>('chat-top-panel-hidden'));
    return AxiAnimatedSize(
      duration: duration,
      reverseDuration: duration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        reverseDuration: duration,
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previousChildren,
              if (currentChild case final Widget current) current,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          return _ChatTopPanelTransition(animation: animation, child: child);
        },
        child: currentChild,
      ),
    );
  }
}

class _ChatTopPanelTransition extends StatelessWidget {
  const _ChatTopPanelTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SlideTransition(
        position: Tween<Offset>(
          begin: context.motion.statusBannerSlideOffset,
          end: Offset.zero,
        ).animate(animation),
        child: SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1.0,
          child: child,
        ),
      ),
    );
  }
}

class _UnknownSenderBanner extends StatelessWidget {
  const _UnknownSenderBanner({
    required this.readOnly,
    required this.isSelfChat,
    required this.onAddContact,
    required this.onReportSpam,
  });

  final bool readOnly;
  final bool isSelfChat;
  final Future<void> Function()? onAddContact;
  final Future<void> Function()? onReportSpam;

  @override
  Widget build(BuildContext context) {
    if (readOnly || isSelfChat) {
      return const SizedBox.shrink();
    }
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final chat = state.chat;
        if (chat == null ||
            chat.type != ChatType.chat ||
            chat.spam ||
            chat.isAxichatWelcomeThread ||
            chat.isEmailBacked) {
          return const SizedBox.shrink();
        }
        return BlocBuilder<RosterCubit, RosterState>(
          buildWhen: (previous, current) => previous.items != current.items,
          builder: (context, rosterState) {
            final rosterItems =
                rosterState.items ??
                (context.read<RosterCubit>()[RosterCubit.itemsCacheKey]
                    as List<RosterItem>?) ??
                const <RosterItem>[];
            final normalizedChatJid = normalizedAddressKey(chat.remoteJid);
            final rosterEntry = normalizedChatJid == null
                ? null
                : rosterItems
                      .where(
                        (entry) =>
                            normalizedAddressKey(entry.jid) ==
                            normalizedChatJid,
                      )
                      .firstOrNull;
            if (rosterEntry != null) {
              return const SizedBox.shrink();
            }
            final l10n = context.l10n;
            final spacing = context.spacing;
            final iconSize = spacing.m;
            final actions = <Widget>[
              if (onAddContact != null)
                ContextActionButton(
                  icon: Icon(LucideIcons.userPlus, size: iconSize),
                  label: l10n.rosterAddTitle,
                  onPressed: () async {
                    await onAddContact!();
                  },
                ),
              if (onReportSpam != null)
                ContextActionButton(
                  icon: Icon(LucideIcons.shieldAlert, size: iconSize),
                  label: l10n.chatReportSpam,
                  onPressed: () async {
                    await onReportSpam!();
                  },
                  destructive: true,
                ),
            ];
            return ListItemPadding(
              child: ShadCard(
                padding: EdgeInsets.all(spacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.userX,
                          size: iconSize,
                          color: context.colorScheme.destructive,
                        ),
                        SizedBox(width: spacing.s),
                        Expanded(
                          child: Text(
                            l10n.accessibilityUnknownContact,
                            style: context.textTheme.small.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.s),
                    Text(
                      l10n.chatAttachmentBlockedDescription,
                      style: context.textTheme.muted,
                    ),
                    if (actions.isNotEmpty) ...[
                      SizedBox(height: spacing.s),
                      Wrap(
                        spacing: spacing.s,
                        runSpacing: spacing.s,
                        children: actions,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ChatScaffoldBody extends StatelessWidget {
  const _ChatScaffoldBody({
    required this.owner,
    required this.state,
    required this.chatEntity,
    required this.readOnly,
    required this.isSelfChat,
    required this.isWelcomeChat,
    required this.isGroupChat,
    required this.isEmailComposer,
    required this.chatCalendarAvailable,
    required this.personalCalendarAvailable,
    required this.currentUserId,
    required this.selfXmppJid,
    required this.selfIdentity,
    required this.selfAvatarPath,
    required this.myOccupantJid,
    required this.selfNick,
    required this.user,
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
    required this.canRenameContact,
    required this.isChatBlocked,
    required this.chatBlocklistEntry,
    required this.blockAddress,
    required this.isEmailBacked,
    required this.profileJid,
    required this.avatarPathForBareJid,
    required this.avatarPathForTypingParticipant,
    required this.onExpandedComposerDraftSaved,
    required this.onClearQuote,
  });

  final _ChatState owner;
  final ChatState state;
  final chat_models.Chat? chatEntity;
  final bool readOnly;
  final bool isSelfChat;
  final bool isWelcomeChat;
  final bool isGroupChat;
  final bool isEmailComposer;
  final bool chatCalendarAvailable;
  final bool personalCalendarAvailable;
  final String? currentUserId;
  final String? selfXmppJid;
  final SelfAvatar selfIdentity;
  final String? selfAvatarPath;
  final String? myOccupantJid;
  final String? selfNick;
  final ChatUser user;
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
  final bool canRenameContact;
  final bool isChatBlocked;
  final BlocklistEntry? chatBlocklistEntry;
  final String? blockAddress;
  final bool isEmailBacked;
  final String? profileJid;
  final String? Function(String bareJid) avatarPathForBareJid;
  final String? Function(String participant) avatarPathForTypingParticipant;
  final ValueChanged<int> onExpandedComposerDraftSaved;
  final VoidCallback onClearQuote;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final chatMainBody = Column(
          children: [
            _ChatTopPanelVisibility(
              visible: owner._chatRoute.isSearch,
              child: const _ChatSearchPanel(),
            ),
            const ChatAlert(),
            _UnknownSenderBanner(
              readOnly: readOnly,
              isSelfChat: isSelfChat,
              onAddContact: owner._handleAddContact,
              onReportSpam: () => owner._handleSpamToggle(sendToSpam: true),
            ),
            Expanded(
              child: IgnorePointer(
                ignoring: !owner._chatRoute.allowsChatInteraction,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final spacing = context.spacing;
                    final messageListHorizontalPadding = spacing.s;
                    final pinnedPanelMinHeight = 0.0;
                    final rawContentWidth = math.max(0.0, constraints.maxWidth);
                    final availableWidth = math.max(
                      0.0,
                      rawContentWidth - (messageListHorizontalPadding * 2),
                    );
                    final isCompact = availableWidth < smallScreen;
                    final pinnedPanelMaxHeight = math.max(
                      pinnedPanelMinHeight,
                      constraints.maxHeight - owner._bottomSectionHeight,
                    );
                    final pinnedMessageIds = state.pinnedMessages
                        .map((item) => item.messageStanzaId)
                        .toSet();
                    final attachmentsByMessageId =
                        state.attachmentMetadataIdsByMessageId;
                    final groupLeaderByMessageId =
                        state.attachmentGroupLeaderByMessageId;
                    owner._ensureMessageCaches(
                      items: state.items,
                      quotedMessagesById: state.quotedMessagesById,
                      searchResults: searchResults ?? const <Message>[],
                      searchFiltering: searchFiltering,
                      attachmentsByMessageId: attachmentsByMessageId,
                      groupLeaderByMessageId: groupLeaderByMessageId,
                    );
                    final messageById = owner._cachedMessageById;
                    const emptyAttachments = <String>[];
                    final importantMessageIds = context
                        .select<ImportantMessagesCubit, Set<String>>((cubit) {
                          final items = cubit.state.items;
                          if (items == null) {
                            return const <String>{};
                          }
                          return items
                              .map((item) => item.messageReferenceId.trim())
                              .where((value) => value.isNotEmpty)
                              .toSet();
                        });

                    String messageKey(Message message) =>
                        message.id ?? message.stanzaID;

                    List<String> attachmentsForMessage(Message message) {
                      final key = messageKey(message);
                      return attachmentsByMessageId[key] ?? emptyAttachments;
                    }

                    bool isPinnedMessage(Message message) {
                      return message.referenceIds.any(
                        pinnedMessageIds.contains,
                      );
                    }

                    bool isImportantMessage(Message message) {
                      return message.referenceIds.any(
                        importantMessageIds.contains,
                      );
                    }

                    final filteredItems = owner._cachedFilteredItems;
                    final availabilityCoordinator =
                        _readAvailabilityShareCoordinator(
                          context,
                          calendarAvailable: chatCalendarAvailable,
                        );
                    final availabilityShareOwnersById = <String, String>{};
                    for (final item in filteredItems) {
                      final availabilityMessage =
                          item.calendarAvailabilityMessage;
                      if (availabilityMessage == null) {
                        continue;
                      }
                      availabilityMessage.maybeMap(
                        share: (value) {
                          final ownerJid = value.share.overlay.owner;
                          final isValid = item.senderMatchesClaimedJid(
                            ownerJid,
                            roomState: state.roomState,
                          );
                          if (isValid) {
                            availabilityShareOwnersById[value.share.id] =
                                ownerJid;
                          }
                        },
                        orElse: () {},
                      );
                    }
                    final isEmailChat = state.chat?.isEmailBacked == true;
                    final loadingMessages = !state.messagesLoaded;
                    final selectedMessages = owner._collectSelectedMessages(
                      filteredItems,
                    );
                    if (owner._multiSelectActive && selectedMessages.isEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!owner.mounted) return;
                        owner._clearMultiSelection();
                      });
                    }
                    const compactBubbleWidthFraction = 0.8;
                    const regularBubbleWidthFraction = 0.8;
                    const selectionExtrasPreferredMaxWidth = 500.0;
                    final selectionCutoutDepth = spacing.m;
                    final selectionOuterInset =
                        selectionCutoutDepth + (SelectionIndicator.size / 2);
                    final messageRowAvatarReservation = spacing.l;
                    final baseBubbleMaxWidth =
                        availableWidth *
                        (isCompact
                            ? compactBubbleWidthFraction
                            : regularBubbleWidthFraction);
                    final inboundAvatarReservation = isGroupChat
                        ? messageRowAvatarReservation
                        : 0.0;
                    final inboundClampedBubbleWidth = baseBubbleMaxWidth.clamp(
                      0.0,
                      availableWidth - inboundAvatarReservation,
                    );
                    final outboundClampedBubbleWidth = baseBubbleMaxWidth.clamp(
                      0.0,
                      availableWidth,
                    );
                    final inboundMessageRowMaxWidth = math.min(
                      availableWidth - inboundAvatarReservation,
                      inboundClampedBubbleWidth + selectionOuterInset,
                    );
                    final outboundMessageRowMaxWidth = math.min(
                      availableWidth,
                      outboundClampedBubbleWidth + selectionOuterInset,
                    );
                    final messageRowMaxWidth = rawContentWidth;
                    final revokedInviteTokens = <String>{
                      for (final invite in filteredItems.where(
                        (m) =>
                            m.pseudoMessageType ==
                            PseudoMessageType.mucInviteRevocation,
                      ))
                        if (invite.pseudoMessageData?.containsKey('token') ==
                            true)
                          invite.pseudoMessageData?['token'] as String,
                    };
                    const pinnedPreviewMessagePrefix = 'pinned-preview:';
                    final emptyStateLabel = searchFiltering
                        ? context.l10n.chatEmptySearch
                        : context.l10n.chatEmptyMessages;
                    final xmppCapabilities = state.xmppCapabilities;
                    final supportsMarkers =
                        isEmailChat ||
                        xmppCapabilities?.supportsMarkers == true;
                    final supportsReceipts =
                        isEmailChat ||
                        xmppCapabilities?.supportsReceipts == true;
                    final timelineItems = buildMainChatTimelineItems(
                      messages: filteredItems,
                      loadingMessages: loadingMessages,
                      unreadBoundaryStanzaId: state.unreadBoundaryStanzaId,
                      emptyStateCreatedAt: _selectionSpacerTimestamp,
                      unreadDividerItemId: _unreadDividerMessageId,
                      unreadDividerLabel: context.l10n.chatUnreadDividerLabel,
                      emptyStateItemId: _emptyStateMessageId,
                      emptyStateLabel: emptyStateLabel,
                      isGroupChat: isGroupChat,
                      isEmailChat: isEmailChat,
                      profileJid: profileJid,
                      resolvedEmailSelfJid: resolvedEmailSelfJid,
                      currentUserId: currentUserId,
                      selfUserId: user.id,
                      selfDisplayName: user.firstName ?? '',
                      selfAvatarPath: selfAvatarPath,
                      myOccupantJid: myOccupantJid,
                      selfNick: selfNick,
                      roomState: state.roomState,
                      roomMemberSections: state.roomMemberSections,
                      chat: state.chat,
                      messageById: messageById,
                      shareContexts: shareContexts,
                      shareReplies: shareReplies,
                      emailFullHtmlByDeltaId: state.emailFullHtmlByDeltaId,
                      revokedInviteTokens: revokedInviteTokens,
                      inviteRoomFallbackLabel:
                          context.l10n.chatInviteRoomFallbackLabel,
                      inviteBodyLabel: context.l10n.chatInviteBodyLabel,
                      inviteRevokedBodyLabel:
                          context.l10n.chatInviteRevokedLabel,
                      unknownAuthorLabel: context.l10n.commonUnknownLabel,
                      inviteActionLabel: context.l10n.chatInviteActionLabel,
                      supportsMarkers: supportsMarkers,
                      supportsReceipts: supportsReceipts,
                      attachmentsForMessage: attachmentsForMessage,
                      reactionPreviewsForMessage:
                          owner._reactionPreviewsForMessage,
                      participantsForBanner: owner._participantsForBanner,
                      avatarPathForBareJid: avatarPathForBareJid,
                      ownerJidForShare: (shareId) =>
                          availabilityShareOwnersById[shareId] ??
                          availabilityCoordinator?.ownerJidForShare(shareId),
                      errorLabel: (error) => error.label(context.l10n),
                      errorLabelWithBody: (error, body) =>
                          context.l10n.chatMessageErrorWithBody(
                            error.label(context.l10n),
                            body,
                          ),
                    );
                    final mainTimelineItems = <ChatTimelineItem>[
                      ChatTimelineComposerOverlaySpacerItem(
                        id: _composerOverlaySpacerMessageId,
                        createdAt: _selectionSpacerTimestamp,
                      ),
                      ...timelineItems,
                    ];
                    late final MessageListOptions dashMessageListOptions;
                    dashMessageListOptions = MessageListOptions(
                      scrollController: owner._scrollController,
                      scrollPhysics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      separatorFrequency: SeparatorFrequency.days,
                      dateSeparatorBuilder: (date) {
                        if (date.isAtSameMomentAs(_selectionSpacerTimestamp)) {
                          return const SizedBox.shrink();
                        }
                        return DefaultDateSeparator(
                          date: date,
                          messageListOptions: dashMessageListOptions,
                        );
                      },
                      typingBuilder: (_) => const SizedBox.shrink(),
                      onLoadEarlier:
                          searchFiltering ||
                              state.items.length % ChatBloc.messageBatchSize !=
                                  0
                          ? null
                          : () async {
                              final completer = Completer<void>();
                              context.read<ChatBloc>().add(
                                ChatLoadEarlier(completer: completer),
                              );
                              await completer.future;
                            },
                      loadEarlierBuilder: Padding(
                        padding: EdgeInsets.all(context.spacing.m),
                        child: const Center(child: AxiProgressIndicator()),
                      ),
                    );
                    final composerHintText = isEmailComposer
                        ? context.l10n.chatComposerEmailHint
                        : context.l10n.chatComposerMessageHint;
                    final overlayAnimationDuration = context
                        .watch<SettingsCubit>()
                        .animationDuration;
                    final quotedMessage =
                        owner._quotedDraft ??
                        (_ChatState._debugShowAllComposerBanners &&
                                filteredItems.isNotEmpty
                            ? filteredItems.first
                            : null);
                    final quotedIsSelf = quotedMessage == null
                        ? false
                        : owner._isQuotedMessageFromSelf(
                            quotedMessage: quotedMessage,
                            isGroupChat: isGroupChat,
                            roomState: state.roomState,
                            fallbackSelfNick: selfNick,
                            currentUserId: currentUserId,
                          );
                    final quotedSenderLabel = quotedMessage == null
                        ? null
                        : quotedIsSelf
                        ? context.l10n.chatSenderYou
                        : owner._quotedSenderLabel(
                            quotedMessage: quotedMessage,
                            isGroupChat: isGroupChat,
                            roomState: state.roomState,
                            chatDisplayName: resolvedDirectChatDisplayName,
                            l10n: context.l10n,
                          );
                    final composerErrorKey = state.composerError;
                    final composerErrorMessage = composerErrorKey?.label(
                      context.l10n,
                    );
                    final onComposerErrorCleared =
                        state.emailSyncState.requiresAttention &&
                            composerErrorKey ==
                                ChatMessageKey.messageErrorServiceUnavailable
                        ? null
                        : () => context.read<ChatBloc>().add(
                            const ChatComposerErrorCleared(),
                          );
                    final composerNotices = _ComposerNotices(
                      composerError: composerErrorMessage,
                      onComposerErrorCleared: onComposerErrorCleared,
                      showAttachmentWarning: showAttachmentWarning,
                      retryReport: retryReport,
                      retryShareId: retryShareId,
                      onFanOutRetry: onFanOutRetry,
                    );
                    final showComposerNotices =
                        composerErrorMessage?.isNotEmpty == true ||
                        showAttachmentWarning ||
                        (retryReport != null &&
                            retryShareId != null &&
                            retryReport!.statuses.any(
                              (status) =>
                                  status.state == FanOutRecipientState.failed,
                            ));
                    Widget? overlayNotices = showComposerNotices
                        ? composerNotices
                        : (_ChatState._debugShowAllComposerBanners
                              ? const _DebugComposerNotices()
                              : null);
                    var overlayQuotedMessage = quotedMessage;
                    var overlayQuotedSenderLabel = quotedSenderLabel;
                    var overlayQuotedIsSelf = quotedIsSelf;
                    final demoTypingAvatars = owner._demoTypingParticipants(
                      state,
                    );
                    final typingAvatars = demoTypingAvatars.isNotEmpty
                        ? demoTypingAvatars
                        : state.typingParticipants.isNotEmpty
                        ? state.typingParticipants
                        : const <String>[];
                    final typingAvatarPaths = <String, String>{};
                    for (final participant in typingAvatars) {
                      final path = avatarPathForTypingParticipant(participant);
                      if (path == null || path.isEmpty) {
                        continue;
                      }
                      typingAvatarPaths[participant] = path;
                    }
                    final typingVisible =
                        state.typing == true || typingAvatars.isNotEmpty;
                    Widget? composerOverlayBanner;
                    final Widget bottomContent;
                    if (owner._multiSelectActive &&
                        selectedMessages.isNotEmpty) {
                      final targets = List<Message>.of(
                        selectedMessages,
                        growable: false,
                      );
                      final canReact =
                          !isEmailChat &&
                          (state.xmppCapabilities?.supportsFeature(
                                mox.messageReactionsXmlns,
                              ) ??
                              false);
                      composerOverlayBanner = _MessageSelectionToolbar(
                        count: targets.length,
                        onClear: owner._clearMultiSelection,
                        onCopy: () => owner._copySelectedMessages(
                          List<Message>.of(targets),
                        ),
                        onShare: () => owner._shareSelectedMessages(
                          List<Message>.of(targets),
                        ),
                        shareStatus: owner._shareRequestStatus,
                        onForward: () => owner._forwardSelectedMessages(
                          List<Message>.of(targets),
                        ),
                        onAddToCalendar: () => owner._addSelectedToCalendar(
                          List<Message>.of(targets),
                        ),
                        showReactions: canReact,
                        onReactionSelected: canReact
                            ? (emoji) => owner._toggleQuickReactionForMessages(
                                targets,
                                emoji,
                              )
                            : null,
                        onReactionPicker: canReact
                            ? () => owner._handleMultiReactionSelection(
                                List<Message>.of(targets),
                              )
                            : null,
                      );
                      bottomContent = const SizedBox.shrink();
                    } else if (readOnly) {
                      owner._ensureRecipientBarHeightCleared();
                      composerOverlayBanner = const _ReadOnlyComposerBanner();
                      bottomContent = const SizedBox.shrink();
                    } else {
                      final visibilityLabel = owner._recipientVisibilityLabel(
                        chat: state.chat,
                        recipients: recipients,
                      );
                      final expandedComposerSeed = owner._expandedComposerSeed;
                      final Widget composerChild;
                      if (expandedComposerSeed != null) {
                        final locate = context.read;
                        composerChild = _InlineExpandedDraftComposerSection(
                          key: const ValueKey<String>('expanded-composer'),
                          seed: expandedComposerSeed,
                          locate: locate,
                          onUnexpand: () =>
                              owner._collapseExpandedDraftComposer(
                                clearInlineComposer: false,
                              ),
                          onClosed: () => owner._collapseExpandedDraftComposer(
                            clearInlineComposer: true,
                          ),
                          onDiscarded: () =>
                              owner._collapseExpandedDraftComposer(
                                clearInlineComposer: true,
                              ),
                          onDraftSaved: onExpandedComposerDraftSaved,
                        );
                        bottomContent = _ComposerModeTransition(
                          duration: overlayAnimationDuration,
                          child: composerChild,
                        );
                      } else {
                        composerChild = _ChatComposerSection(
                          key: const ValueKey<String>('inline-composer'),
                          enabled:
                              !isWelcomeChat &&
                              !roomBootstrapInProgress &&
                              !roomJoinFailed,
                          hintText: composerHintText,
                          recipients: recipients,
                          availableChats: availableChats,
                          latestStatuses: latestStatuses,
                          visibilityLabel: visibilityLabel,
                          pendingAttachments: pendingAttachments,
                          composerHasText: owner._composerHasContent,
                          composerMinLines: 1,
                          composerMaxLines: 6,
                          selfJid: selfXmppJid,
                          selfIdentity: selfIdentity,
                          composerError: null,
                          onComposerErrorCleared: null,
                          showAttachmentWarning: false,
                          retryReport: null,
                          retryShareId: null,
                          onFanOutRetry: null,
                          subjectController: owner._subjectController,
                          subjectFocusNode: owner._subjectFocusNode,
                          textController: owner._textController,
                          textFocusNode: owner._focusNode,
                          tapRegionGroup: owner._composerTapRegionGroup,
                          onSubjectSubmitted: () =>
                              owner._focusNode.requestFocus(),
                          showExpandDraftAction: isEmailComposer,
                          expandDraftEnabled: !owner._expandingComposerDraft,
                          onExpandDraftPressed: () =>
                              owner._expandEmailComposerToDraft(state),
                          onRecipientAdded: owner._handleRecipientAdded,
                          onRecipientRemoved: owner._handleRecipientRemoved,
                          onRecipientToggled: owner._handleRecipientToggled,
                          onAttachmentRetry: (pending) {
                            final chat = chatEntity;
                            if (chat == null) {
                              return;
                            }
                            unawaited(
                              owner._retryPendingAttachment(
                                pending,
                                chat: chat,
                                quotedDraft: owner._quotedDraft,
                                supportsHttpFileUpload:
                                    state.supportsHttpFileUpload,
                                settingsSnapshot: settingsSnapshot,
                              ),
                            );
                          },
                          onAttachmentRemove: owner._removePendingAttachment,
                          onPendingAttachmentPressed:
                              owner._handlePendingAttachmentPressed,
                          onPendingAttachmentLongPressed:
                              owner._handlePendingAttachmentLongPressed,
                          pendingAttachmentMenuBuilder: (pending) =>
                              owner._pendingAttachmentMenuItems(
                                pending,
                                chat: chatEntity,
                                quotedDraft: owner._quotedDraft,
                                supportsHttpFileUpload:
                                    state.supportsHttpFileUpload,
                                settingsSnapshot: settingsSnapshot,
                              ),
                          buildComposerAccessories: ({required bool canSend}) =>
                              owner._composerAccessories(
                                canSend: canSend,
                                attachmentsEnabled: attachmentsEnabled,
                                chatState: state,
                                settingsSnapshot: settingsSnapshot,
                              ),
                          onTaskDropped: owner._handleTaskDrop,
                          sendOnEnter: composerSendOnEnter,
                          onSend: () => owner._handleSendMessage(
                            chatState: state,
                            settingsSnapshot: settingsSnapshot,
                          ),
                        );
                        bottomContent = _ComposerModeTransition(
                          duration: overlayAnimationDuration,
                          child: composerChild,
                        );
                        if (roomBootstrapInProgress) {
                          composerOverlayBanner =
                              const _RoomBootstrapComposerBanner();
                        } else if (roomJoinFailureState != null) {
                          composerOverlayBanner =
                              _RoomJoinFailureComposerBanner(
                                detail:
                                    roomJoinFailureState!.joinErrorText ??
                                    roomJoinFailureState!.selfPresenceReason,
                              );
                        }
                      }
                    }
                    composerOverlayBanner ??=
                        _ChatState._debugShowAllComposerBanners
                        ? const _DebugComposerOverlayBanner()
                        : null;
                    if (_ChatState._debugCycleComposerBanners) {
                      overlayQuotedMessage = null;
                      overlayQuotedSenderLabel = null;
                      overlayQuotedIsSelf = false;
                      overlayNotices = null;
                      composerOverlayBanner = _DebugComposerBannerCycle(
                        animationDuration: overlayAnimationDuration,
                        interval: context.motion.statusBannerSuccessDuration,
                      );
                    }
                    return _ChatMainConversationSection(
                      chatEntity: chatEntity,
                      state: state,
                      pinnedPanelVisible: owner._pinnedPanelVisible,
                      pinnedPanelMaxHeight: pinnedPanelMaxHeight,
                      accountJidForPins: accountJidForPins,
                      canTogglePins: canTogglePins,
                      chatCalendarAvailable: chatCalendarAvailable,
                      personalCalendarAvailable: personalCalendarAvailable,
                      attachmentsBlockedForChat: attachmentsBlockedForChat,
                      pinnedPreviewMessagePrefix: pinnedPreviewMessagePrefix,
                      isGroupChat: isGroupChat,
                      isEmailChat: isEmailChat,
                      currentUserId: currentUserId,
                      selfXmppJid: selfXmppJid,
                      selfUserId: user.id,
                      selfDisplayName: user.firstName ?? _emptyText,
                      selfAvatarPath: selfAvatarPath,
                      myOccupantJid: myOccupantJid,
                      selfNick: selfNick,
                      resolvedEmailSelfJid: resolvedEmailSelfJid,
                      resolvedDirectChatDisplayName:
                          resolvedDirectChatDisplayName,
                      supportsMarkers: supportsMarkers,
                      supportsReceipts: supportsReceipts,
                      messageById: messageById,
                      shareContexts: shareContexts,
                      shareReplies: shareReplies,
                      revokedInviteTokens: revokedInviteTokens,
                      availabilityCoordinator: availabilityCoordinator,
                      availabilityShareOwnersById: availabilityShareOwnersById,
                      availabilityActorId: availabilityActorId,
                      availableWidth: availableWidth,
                      inboundMessageRowMaxWidth: inboundMessageRowMaxWidth,
                      outboundMessageRowMaxWidth: outboundMessageRowMaxWidth,
                      inboundClampedBubbleWidth: inboundClampedBubbleWidth,
                      outboundClampedBubbleWidth: outboundClampedBubbleWidth,
                      messageRowMaxWidth: messageRowMaxWidth,
                      selectionExtrasPreferredMaxWidth:
                          selectionExtrasPreferredMaxWidth,
                      readOnly: readOnly,
                      isWelcomeChat: isWelcomeChat,
                      multiSelectActive: owner._multiSelectActive,
                      selectedMessageId: owner._selectedMessageId,
                      normalizedXmppSelfJid: normalizedXmppSelfJid,
                      normalizedEmailSelfJid: normalizedEmailSelfJid,
                      messageFontSize: settingsState.messageTextSize.fontSize,
                      loadingMessages: loadingMessages,
                      mainTimelineItems: mainTimelineItems,
                      messageListOptions: dashMessageListOptions,
                      typingVisible: typingVisible,
                      typingAvatars: typingAvatars,
                      typingAvatarPaths: typingAvatarPaths,
                      overlayQuotedMessage: overlayQuotedMessage,
                      overlayQuotedSenderLabel: overlayQuotedSenderLabel,
                      overlayQuotedIsSelf: overlayQuotedIsSelf,
                      overlayNotices: overlayNotices,
                      composerOverlayBanner: composerOverlayBanner,
                      overlayAnimationDuration: overlayAnimationDuration,
                      bottomPaneMaxHeight: constraints.maxHeight,
                      onBottomPaneSizeChange: owner._updateBottomSectionHeight,
                      bottomContent: bottomContent,
                      shareRequestStatus: owner._shareRequestStatus,
                      bubbleRegionRegistry: owner._bubbleRegionRegistry,
                      selectionTapRegionGroup: owner._selectionTapRegionGroup,
                      messageKeys: owner._messageKeys,
                      bubbleWidthByMessageId: owner._bubbleWidthByMessageId,
                      shouldAnimateMessage: owner._shouldAnimateMessage,
                      isPinnedMessage: isPinnedMessage,
                      isImportantMessage: isImportantMessage,
                      onClosePinnedMessages: owner._closePinnedMessages,
                      metadataFor: (metadataId) => owner._metadataFor(
                        state: state,
                        metadataId: metadataId,
                      ),
                      metadataPendingFor: (metadataId) =>
                          owner._metadataPending(
                            state: state,
                            metadataId: metadataId,
                          ),
                      isOneTimeAttachmentAllowed:
                          owner._isOneTimeAttachmentAllowed,
                      shouldAllowAttachment: owner._shouldAllowAttachment,
                      onApproveAttachment: owner._approveAttachment,
                      attachmentsForMessage: attachmentsForMessage,
                      reactionPreviewsForMessage:
                          owner._reactionPreviewsForMessage,
                      participantsForBanner: owner._participantsForBanner,
                      avatarPathForBareJid: avatarPathForBareJid,
                      onMessageLinkTap: owner._handleLinkTap,
                      messageListKey: owner._messageListKey,
                      onPointerMove: owner._handleOutsideTapMove,
                      onPointerUp: owner._handleOutsideTapUp,
                      onPointerCancel: owner._handleOutsideTapCancel,
                      onClearQuote: onClearQuote,
                      onTapOutsideRequested: owner._armOutsideTapDismiss,
                      resolveViewData: owner._resolveTimelineMessageViewData,
                      resolveInteractionData:
                          owner._resolveTimelineMessageInteractionData,
                      composeBubbleContent:
                          owner._composeTimelineMessageBubbleContent,
                      onReplyRequested: owner._handleReplyRequested,
                      onForwardRequested: owner._handleForward,
                      onCopyRequested: owner._copyMessage,
                      onShareRequested: owner._shareMessage,
                      onAddToCalendarRequested: owner._handleAddToCalendar,
                      onDetailsRequested: owner._showMessageDetailsById,
                      onStartMultiSelectRequested: (message) =>
                          unawaited(owner._startMultiSelect(message)),
                      onResendRequested: owner._handleMessageResendRequested,
                      onEditRequested: owner._handleEditMessage,
                      onImportantToggleRequested:
                          owner._handleImportantToggleRequested,
                      onPinToggleRequested: owner._handlePinToggleRequested,
                      onRevokeInviteRequested:
                          owner._handleInviteRevocationRequested,
                      onBubbleTapRequested: owner._handleTimelineBubbleTap,
                      onToggleMultiSelectRequested:
                          owner._toggleMultiSelectMessage,
                      onToggleQuickReactionRequested:
                          owner._toggleQuickReaction,
                      onReactionSelectionRequested:
                          owner._handleReactionSelection,
                      onRecipientTap: owner._openChatFromParticipant,
                      onBubbleSizeChanged: owner._updateMessageBubbleWidth,
                      onCopyTaskToPersonalCalendar: personalCalendarAvailable
                          ? owner._copyTaskToPersonalCalendar
                          : null,
                      onCopyCriticalPathToPersonalCalendar:
                          personalCalendarAvailable
                          ? owner._copyCriticalPathToPersonalCalendar
                          : null,
                      profileJid: profileJid,
                    );
                  },
                ),
              ),
            ),
          ],
        );
        return _ChatRouteOverlayStack(
          chatMainBody: chatMainBody,
          currentRoute: owner._chatRoute,
          previousRoute: owner._previousChatRoute,
          chatEntity: chatEntity,
          calendarAvailable: chatCalendarAvailable,
          state: state,
          canRenameContact: canRenameContact,
          isChatBlocked: isChatBlocked,
          chatBlocklistEntry: chatBlocklistEntry,
          blockAddress: blockAddress,
          loadedEmailImageMessageIds: owner._loadedEmailImageMessageIds,
          onEmailImagesApproved: owner._handleEmailImagesApproved,
          onAddRecipientFromChat: owner._handleRecipientAddedFromChat,
          onViewFilterChanged: owner._setViewFilter,
          onToggleNotifications: owner._toggleNotifications,
          onSpamToggle: ({required bool sendToSpam}) =>
              owner._handleSpamToggle(sendToSpam: sendToSpam),
          onRenameContact: canRenameContact ? owner._promptContactRename : null,
          onImportantMessageSelected: owner._handleImportantMessageSelected,
        );
      },
    );
  }
}
