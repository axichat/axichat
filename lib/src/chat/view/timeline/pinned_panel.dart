part of '../chat.dart';

const String _chatPinnedPanelKeyPrefix = 'chat-pins-';

class _ChatPinnedMessagesPanel extends StatefulWidget {
  const _ChatPinnedMessagesPanel({
    super.key,
    required this.chat,
    required this.visible,
    required this.maxHeight,
    required this.accountJid,
    required this.pinnedMessages,
    required this.pinnedMessagesLoaded,
    required this.pinnedMessagesHydrating,
    required this.onClose,
    required this.canTogglePins,
    required this.canShowCalendarTasks,
    required this.canAddToPersonalCalendar,
    required this.canAddToChatCalendar,
    required this.onCopyTaskToPersonalCalendar,
    required this.onCopyCriticalPathToPersonalCalendar,
    required this.locate,
    required this.roomState,
    required this.metadataFor,
    required this.metadataPendingFor,
    required this.attachmentsBlocked,
    required this.isOneTimeAttachmentAllowed,
    required this.shouldAllowAttachment,
    required this.onApproveAttachment,
    required this.previewTimelineItemForItem,
    required this.resolvedHtmlBodyFor,
    required this.resolvedQuotedTextFor,
    required this.onMessageLinkTap,
  });

  final chat_models.Chat? chat;
  final bool visible;
  final double maxHeight;
  final String? accountJid;
  final List<PinnedMessageItem> pinnedMessages;
  final bool pinnedMessagesLoaded;
  final bool pinnedMessagesHydrating;
  final VoidCallback onClose;
  final bool canTogglePins;
  final bool canShowCalendarTasks;
  final bool canAddToPersonalCalendar;
  final bool canAddToChatCalendar;
  final Future<String?> Function(CalendarTask task)?
  onCopyTaskToPersonalCalendar;
  final Future<bool> Function(
    CalendarModel model,
    String pathId,
    Set<String> taskIds,
  )?
  onCopyCriticalPathToPersonalCalendar;
  final T Function<T>() locate;
  final RoomState? roomState;
  final FileMetadataData? Function(String) metadataFor;
  final bool Function(String) metadataPendingFor;
  final bool attachmentsBlocked;
  final bool Function(String stanzaId) isOneTimeAttachmentAllowed;
  final bool Function({required bool isSelf, required chat_models.Chat? chat})
  shouldAllowAttachment;
  final Future<void> Function({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required bool isSelf,
    required bool isEmailChat,
    String? senderEmail,
  })
  onApproveAttachment;
  final ChatTimelineMessageItem? Function(PinnedMessageItem item)
  previewTimelineItemForItem;
  final String? Function(Message message) resolvedHtmlBodyFor;
  final String? Function(Message message) resolvedQuotedTextFor;
  final ValueChanged<String> onMessageLinkTap;

  @override
  State<_ChatPinnedMessagesPanel> createState() =>
      _ChatPinnedMessagesPanelState();
}

class _ChatPinnedMessagesPanelState extends State<_ChatPinnedMessagesPanel> {
  @override
  void initState() {
    super.initState();
    _requestPinnedHydration();
  }

  @override
  void didUpdateWidget(covariant _ChatPinnedMessagesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool becameVisible = !oldWidget.visible && widget.visible;
    final bool pinnedChanged =
        oldWidget.pinnedMessages != widget.pinnedMessages;
    if (becameVisible || (widget.visible && pinnedChanged)) {
      _requestPinnedHydration();
    }
  }

  void _requestPinnedHydration() {
    if (!widget.visible) {
      return;
    }
    final hasMissingMessage = widget.pinnedMessages.any(
      (item) => item.message == null && item.messageStanzaId.trim().isNotEmpty,
    );
    if (!hasMissingMessage) {
      return;
    }
    context.read<ChatBloc>().add(const ChatPinnedMessagesOpened());
  }

  @override
  Widget build(BuildContext context) {
    final currentChat = widget.chat;
    if (currentChat == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final showPanel = widget.visible && widget.maxHeight > 0.0;
    final showLoading = showPanel && !widget.pinnedMessagesLoaded;
    final panelBody = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }
        if (showLoading) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.m),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [AxiProgressIndicator(color: colors.mutedForeground)],
            ),
          );
        }
        if (widget.pinnedMessages.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.m),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    l10n.chatPinnedEmptyState,
                    textAlign: TextAlign.center,
                    style: context.textTheme.muted.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          primary: false,
          physics: const ClampingScrollPhysics(),
          itemCount: widget.pinnedMessages.length,
          itemBuilder: (context, index) {
            final item = widget.pinnedMessages[index];
            return _PinnedMessageTile(
              item: item,
              chat: currentChat,
              roomState: widget.roomState,
              canTogglePins: widget.canTogglePins,
              canShowCalendarTasks: widget.canShowCalendarTasks,
              canAddToPersonalCalendar: widget.canAddToPersonalCalendar,
              canAddToChatCalendar: widget.canAddToChatCalendar,
              onCopyTaskToPersonalCalendar: widget.onCopyTaskToPersonalCalendar,
              onCopyCriticalPathToPersonalCalendar:
                  widget.onCopyCriticalPathToPersonalCalendar,
              locate: widget.locate,
              isHydrating: widget.pinnedMessagesHydrating,
              accountJid: widget.accountJid,
              metadataFor: widget.metadataFor,
              metadataPendingFor: widget.metadataPendingFor,
              attachmentsBlocked: widget.attachmentsBlocked,
              isOneTimeAttachmentAllowed: widget.isOneTimeAttachmentAllowed,
              shouldAllowAttachment: widget.shouldAllowAttachment,
              onApproveAttachment: widget.onApproveAttachment,
              previewTimelineItemForItem: widget.previewTimelineItemForItem,
              resolvedHtmlBodyFor: widget.resolvedHtmlBodyFor,
              resolvedQuotedTextFor: widget.resolvedQuotedTextFor,
              onMessageLinkTap: widget.onMessageLinkTap,
            );
          },
        );
      },
    );
    final panel = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: spacing.m,
          vertical: spacing.m,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChatIndexedHeader(
              title: l10n.chatPinnedMessagesTitle,
              onClose: widget.onClose,
              padding: EdgeInsets.zero,
            ),
            SizedBox(height: spacing.m),
            Flexible(fit: FlexFit.loose, child: panelBody),
          ],
        ),
      ),
    );
    return _ChatTopPanelVisibility(visible: showPanel, child: panel);
  }
}

class _PinnedMessageTile extends StatelessWidget {
  const _PinnedMessageTile({
    required this.item,
    required this.chat,
    required this.roomState,
    required this.canTogglePins,
    required this.canShowCalendarTasks,
    required this.canAddToPersonalCalendar,
    required this.canAddToChatCalendar,
    required this.onCopyTaskToPersonalCalendar,
    required this.onCopyCriticalPathToPersonalCalendar,
    required this.locate,
    required this.isHydrating,
    required this.accountJid,
    required this.metadataFor,
    required this.metadataPendingFor,
    required this.attachmentsBlocked,
    required this.isOneTimeAttachmentAllowed,
    required this.shouldAllowAttachment,
    required this.onApproveAttachment,
    required this.previewTimelineItemForItem,
    required this.resolvedHtmlBodyFor,
    required this.resolvedQuotedTextFor,
    required this.onMessageLinkTap,
  });

  final PinnedMessageItem item;
  final chat_models.Chat chat;
  final RoomState? roomState;
  final bool canTogglePins;
  final bool canShowCalendarTasks;
  final bool canAddToPersonalCalendar;
  final bool canAddToChatCalendar;
  final Future<String?> Function(CalendarTask task)?
  onCopyTaskToPersonalCalendar;
  final Future<bool> Function(
    CalendarModel model,
    String pathId,
    Set<String> taskIds,
  )?
  onCopyCriticalPathToPersonalCalendar;
  final T Function<T>() locate;
  final bool isHydrating;
  final String? accountJid;
  final FileMetadataData? Function(String) metadataFor;
  final bool Function(String) metadataPendingFor;
  final bool attachmentsBlocked;
  final bool Function(String stanzaId) isOneTimeAttachmentAllowed;
  final bool Function({required bool isSelf, required chat_models.Chat? chat})
  shouldAllowAttachment;
  final Future<void> Function({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required bool isSelf,
    required bool isEmailChat,
    String? senderEmail,
  })
  onApproveAttachment;
  final ChatTimelineMessageItem? Function(PinnedMessageItem item)
  previewTimelineItemForItem;
  final String? Function(Message message) resolvedHtmlBodyFor;
  final String? Function(Message message) resolvedQuotedTextFor;
  final ValueChanged<String> onMessageLinkTap;

  Message? resolveMessageForPin() {
    final message = item.message;
    if (message != null) {
      return message;
    }
    final chatJid = item.chatJid.trim();
    final stanzaId = item.messageStanzaId.trim();
    if (chatJid.isEmpty || stanzaId.isEmpty) {
      return null;
    }
    return Message(
      stanzaID: stanzaId,
      senderJid: chatJid,
      chatJid: chatJid,
      timestamp: item.pinnedAt,
    );
  }

  bool isSelfMessage({required Message message, required String? accountJid}) {
    if (chat.type == ChatType.groupChat) {
      return roomState?.isSelfSenderJid(
            message.senderJid,
            selfJid: accountJid,
            fallbackSelfNick: chat.myNickname,
          ) ??
          false;
    }
    return message.isFromAuthorizedJid(accountJid);
  }

  String? nickFromSender(String senderJid) =>
      roomState?.senderNick(senderJid) ?? addressResourcePart(senderJid);

  String resolveSenderLabel({
    required BuildContext context,
    required Message? message,
    required bool isSelf,
  }) {
    final l10n = context.l10n;
    final trimmedSelfLabel = l10n.chatSenderYou.trim();
    if (isSelf) {
      return trimmedSelfLabel.isNotEmpty ? trimmedSelfLabel : chat.displayName;
    }
    if (message == null) {
      return chat.displayName;
    }
    final isGroupChat = chat.type == ChatType.groupChat;
    String? label;
    if (isGroupChat) {
      label = nickFromSender(message.senderJid);
    } else {
      final displayName = chat.displayName.trim();
      label = displayName.isNotEmpty ? displayName : null;
    }
    final senderFallback = message.senderJid.trim();
    final fallback = senderFallback.isNotEmpty
        ? senderFallback
        : chat.displayName;
    final hasLabel = label != null && label.isNotEmpty;
    final candidate = hasLabel ? label : fallback;
    final sanitized = sanitizeUnicodeControls(candidate);
    final safeLabel = sanitized.value.trim();
    return safeLabel.isNotEmpty ? safeLabel : fallback;
  }

  String resolveQuotedSenderLabel(BuildContext context, Message quotedMessage) {
    final quotedIsSelf = isSelfMessage(
      message: quotedMessage,
      accountJid: accountJid,
    );
    if (quotedIsSelf) {
      return context.l10n.chatSenderYou;
    }
    return resolveSenderLabel(
      context: context,
      message: quotedMessage,
      isSelf: false,
    );
  }

  String resolveForwardedSenderLabel({
    required BuildContext context,
    required Message? message,
    required bool isSelf,
    required String? forwardedFromJid,
    required String? forwardedSubjectSenderLabel,
  }) {
    final source = forwardedFromJid?.trim();
    if (source != null && source.isNotEmpty) {
      return source;
    }
    final subjectSender = forwardedSubjectSenderLabel?.trim();
    if (subjectSender != null && subjectSender.isNotEmpty) {
      return subjectSender;
    }
    if (isSelf) {
      return context.l10n.chatSenderYou;
    }
    return resolveSenderLabel(
      context: context,
      message: message,
      isSelf: false,
    );
  }

  List<InlineSpan> calendarTaskShareMetadata(
    CalendarTask task,
    AppLocalizations l10n,
    TextStyle detailStyle,
  ) {
    final metadata = <InlineSpan>[];
    final description = task.description?.trim() ?? _emptyText;
    if (description.isNotEmpty) {
      metadata.add(TextSpan(text: description, style: detailStyle));
    }
    final location = task.location?.trim() ?? _emptyText;
    if (location.isNotEmpty) {
      metadata.add(
        TextSpan(text: l10n.calendarCopyLocation(location), style: detailStyle),
      );
    }
    final scheduleText = calendarTaskScheduleText(task, l10n);
    if (scheduleText != null && scheduleText.isNotEmpty) {
      metadata.add(TextSpan(text: scheduleText, style: detailStyle));
    }
    return metadata;
  }

  String? calendarTaskScheduleText(CalendarTask task, AppLocalizations l10n) {
    final scheduled = task.scheduledTime;
    if (scheduled == null) {
      return null;
    }
    final end =
        task.endDate ??
        (task.duration == null ? null : scheduled.add(task.duration!));
    final startText = TimeFormatter.formatFriendlyDateTime(l10n, scheduled);
    if (end == null) {
      return startText;
    }
    final endText = TimeFormatter.formatFriendlyDateTime(l10n, end);
    if (endText == startText) {
      return startText;
    }
    return l10n.commonRangeLabel(startText, endText);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locate = context.read;
    final colors = context.colorScheme;
    final chatTokens = context.chatTheme;
    final spacing = context.spacing;
    final settings = context.watch<SettingsCubit>().state;
    final sourceMessage = item.message;
    final previewTimelineItem = previewTimelineItemForItem(item);
    final importantMessageIds = context
        .select<ImportantMessagesCubit, Set<String>>((cubit) {
          final items = cubit.state.items;
          if (items == null) {
            return const <String>{};
          }
          return items
              .map((entry) => entry.messageReferenceId.trim())
              .where((value) => value.isNotEmpty)
              .toSet();
        });
    final effectiveMessage = previewTimelineItem?.messageModel ?? sourceMessage;
    final previewItemId =
        previewTimelineItem?.id ??
        effectiveMessage?.stanzaID ??
        item.messageStanzaId.trim();
    final isEmailMessage =
        chat.isEmailBacked ||
        chat.defaultTransport.isEmail ||
        previewTimelineItem?.isEmailMessage == true ||
        effectiveMessage?.isEmailBacked == true;
    final rawRenderedText =
        (previewTimelineItem?.renderedText ?? sourceMessage?.plainText)
            ?.trim() ??
        _emptyText;
    final renderedText = isEmailMessage
        ? ChatSubjectCodec.previewBodyText(rawRenderedText).trim()
        : rawRenderedText;
    final attachmentIds =
        previewTimelineItem?.attachmentIds ?? item.attachmentMetadataIds;
    final shareParticipants =
        previewTimelineItem?.shareParticipants ?? const <chat_models.Chat>[];
    final replyParticipants =
        previewTimelineItem?.replyParticipants ?? const <chat_models.Chat>[];
    final quotedMessage = previewTimelineItem?.quotedMessage;
    final reactions =
        previewTimelineItem?.reactions ?? const <ReactionPreview>[];
    final isForwarded = previewTimelineItem?.isForwarded ?? false;
    final forwardedSubjectSenderLabel =
        previewTimelineItem?.forwardedSubjectSenderLabel;
    final forwardedFromJid = previewTimelineItem?.forwardedFromJid;
    final messageError =
        previewTimelineItem?.error ??
        effectiveMessage?.error ??
        MessageError.none;
    final trusted = previewTimelineItem?.trusted ?? effectiveMessage?.trusted;
    final calendarFragment =
        previewTimelineItem?.calendarFragment ??
        effectiveMessage?.calendarFragment;
    final calendarTask =
        previewTimelineItem?.calendarTaskIcs ??
        effectiveMessage?.calendarTaskIcs;
    final bool calendarTaskReadOnly =
        previewTimelineItem?.calendarTaskIcsReadOnly ??
        effectiveMessage?.calendarTaskIcsReadOnly ??
        _calendarTaskIcsReadOnlyFallback;
    final availabilityMessage = previewTimelineItem?.availabilityMessage;
    final CalendarCriticalPathFragment? criticalPathFragment = calendarFragment
        ?.maybeMap(criticalPath: (value) => value, orElse: () => null);
    final String? taskShareText = calendarTask
        ?.toShareText(context.l10n)
        .trim();
    final String? fragmentShareText = calendarFragment == null
        ? null
        : CalendarFragmentFormatter(
            context.l10n,
          ).describe(calendarFragment).trim();
    final bool hideTaskText =
        taskShareText != null &&
        taskShareText.isNotEmpty &&
        taskShareText == renderedText;
    final bool hideFragmentText =
        fragmentShareText != null &&
        fragmentShareText.isNotEmpty &&
        fragmentShareText == renderedText;
    final bool hideAvailabilityText =
        availabilityMessage != null && messageError.isNone;
    final showLoading = sourceMessage == null && isHydrating;
    final messageForPin = resolveMessageForPin();
    final stanzaId = item.messageStanzaId.trim();
    final VoidCallback? onPressed = stanzaId.isEmpty
        ? null
        : () => locate<ChatBloc>().add(ChatPinnedMessageSelected(stanzaId));
    final isSelf = effectiveMessage == null
        ? (previewTimelineItem?.isSelf ?? false)
        : (previewTimelineItem?.isSelf ??
              isSelfMessage(message: effectiveMessage, accountJid: accountJid));
    final senderLabel = resolveSenderLabel(
      context: context,
      message: effectiveMessage,
      isSelf: isSelf,
    );
    final bubbleColor = isSelf ? colors.primary : colors.card;
    final borderColor = isSelf ? Colors.transparent : chatTokens.recvEdge;
    final textColor = isSelf ? colors.primaryForeground : colors.foreground;
    final detailColor = isSelf
        ? colors.primaryForeground
        : colors.mutedForeground;
    final baseTextStyle = context.textTheme.small.copyWith(
      color: textColor,
      fontSize: settings.messageTextSize.fontSize,
      height: 1.3,
    );
    final linkStyle = baseTextStyle.copyWith(
      color: isSelf ? colors.primaryForeground : colors.primary,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );
    final detailStyle = context.textTheme.muted.copyWith(
      color: detailColor,
      height: 1.0,
      textBaseline: TextBaseline.alphabetic,
    );
    final extraStyle = context.textTheme.muted.copyWith(
      color: detailColor,
      fontStyle: FontStyle.italic,
    );
    final transportIconData = isEmailMessage
        ? LucideIcons.mail
        : LucideIcons.messageCircle;
    final isImportant =
        effectiveMessage?.referenceIds.any(importantMessageIds.contains) ??
        false;
    TextSpan iconDetailSpan(IconData icon, Color color) => TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: detailStyle.copyWith(
        color: color,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
      ),
    );

    final timestamp = (effectiveMessage?.timestamp ?? item.pinnedAt).toLocal();
    final timeLabel =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final statusIcon = switch (previewTimelineItem?.delivery) {
      ChatTimelineMessageDelivery.none => MessageStatus.none.icon,
      ChatTimelineMessageDelivery.pending => MessageStatus.pending.icon,
      ChatTimelineMessageDelivery.sent => MessageStatus.sent.icon,
      ChatTimelineMessageDelivery.received => MessageStatus.received.icon,
      ChatTimelineMessageDelivery.read => MessageStatus.read.icon,
      ChatTimelineMessageDelivery.failed => MessageStatus.failed.icon,
      null => null,
    };
    final detailSpans = <InlineSpan>[
      TextSpan(text: timeLabel, style: detailStyle),
      iconDetailSpan(transportIconData, detailColor),
      iconDetailSpan(LucideIcons.pin, detailColor),
      if (isImportant) iconDetailSpan(Icons.star_rounded, detailColor),
      if (trusted != null)
        iconDetailSpan(
          trusted.toShieldIcon,
          trusted ? axiGreen : colors.destructive,
        ),
      if (isSelf && statusIcon != null) iconDetailSpan(statusIcon, detailColor),
    ];
    final detailOpticalOffsetFactors = isEmailMessage
        ? const <int, double>{1: 0.08}
        : const <int, double>{};
    final shareMetadataDetails = hideTaskText && calendarTask != null
        ? calendarTaskShareMetadata(calendarTask, context.l10n, detailStyle)
        : _emptyInlineSpans;
    final taskFooterDetails = hideTaskText
        ? <InlineSpan>[...detailSpans, ...shareMetadataDetails]
        : _emptyInlineSpans;
    final fragmentFooterDetails = hideFragmentText
        ? detailSpans
        : _emptyInlineSpans;
    final availabilityFooterDetails = hideAvailabilityText
        ? detailSpans
        : _emptyInlineSpans;
    final showSubjectBanner =
        previewTimelineItem?.showSubject == true &&
        (previewTimelineItem?.subjectLabel?.trim().isNotEmpty == true);
    final subjectLabel =
        previewTimelineItem?.subjectLabel?.trim() ?? _emptyText;
    final isInviteMessage =
        previewTimelineItem?.isInvite ??
        (effectiveMessage?.pseudoMessageType == PseudoMessageType.mucInvite);
    final isInviteRevocationMessage =
        previewTimelineItem?.isInviteRevocation ??
        (effectiveMessage?.pseudoMessageType ==
            PseudoMessageType.mucInviteRevocation);
    final resolvedHtmlBody = effectiveMessage == null
        ? null
        : resolvedHtmlBodyFor(effectiveMessage);
    final normalizedHtmlBody = HtmlContentCodec.normalizeHtml(resolvedHtmlBody);
    final normalizedHtmlText = normalizedHtmlBody == null
        ? null
        : HtmlContentCodec.toPlainText(normalizedHtmlBody).trim();
    final bool shouldRenderTextContent =
        !hideTaskText && !hideFragmentText && !hideAvailabilityText;
    final messageText = renderedText;
    final metadataIdForCaption = attachmentIds.isNotEmpty
        ? attachmentIds.first
        : effectiveMessage?.fileMetadataID;
    final bool hasAttachmentCaption =
        shouldRenderTextContent &&
        messageText.isEmpty &&
        metadataIdForCaption != null &&
        metadataIdForCaption.isNotEmpty;
    final bool hasVisibleEmailText =
        messageText.isNotEmpty || subjectLabel.isNotEmpty;
    final bool shouldPreferRichEmailHtml =
        isEmailMessage &&
        HtmlContentCodec.shouldRenderRichEmailHtml(
          normalizedHtmlBody: normalizedHtmlBody,
          normalizedHtmlText: normalizedHtmlText,
          renderedText: messageText,
        );
    final bool shouldRenderInlineEmailHtmlBody =
        isEmailMessage &&
        shouldRenderTextContent &&
        !hasAttachmentCaption &&
        normalizedHtmlBody != null &&
        (!hasVisibleEmailText || shouldPreferRichEmailHtml);
    final contentChildren = <Widget>[];
    final extraChildren = <Widget>[];
    void addExtra(Widget child) {
      if (extraChildren.isNotEmpty) {
        extraChildren.add(SizedBox(height: spacing.s));
      }
      extraChildren.add(child);
    }

    if (showLoading) {
      contentChildren.add(
        Align(
          alignment: Alignment.centerLeft,
          child: AxiProgressIndicator(color: detailColor),
        ),
      );
    } else if (effectiveMessage == null) {
      contentChildren.add(
        Text(
          l10n.chatPinnedMissingMessage,
          style: context.textTheme.muted.copyWith(color: detailColor),
        ),
      );
    } else {
      if (showSubjectBanner) {
        final textScaler =
            MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
        final subjectPainter = TextPainter(
          text: TextSpan(text: subjectLabel, style: baseTextStyle),
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout();
        contentChildren.add(Text(subjectLabel, style: baseTextStyle));
        contentChildren.add(
          DecoratedBox(
            decoration: BoxDecoration(color: context.colorScheme.border),
            child: SizedBox(
              height: context.borderSide.width,
              width: subjectPainter.width,
            ),
          ),
        );
        contentChildren.add(SizedBox(height: spacing.xs));
      }
      if (messageError.isNotNone) {
        contentChildren.add(
          Text(
            l10n.chatErrorLabel,
            style: baseTextStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        );
        if (messageText.isNotEmpty) {
          contentChildren.add(
            _ParsedMessageBody(
              contentKey: '${previewItemId}_error',
              text: messageText,
              baseStyle: baseTextStyle,
              linkStyle: linkStyle,
              details: detailSpans,
              detailOpticalOffsetFactors: detailOpticalOffsetFactors,
              onLinkTap: onMessageLinkTap,
              onLinkLongPress: onMessageLinkTap,
            ),
          );
        }
      } else if (isInviteMessage || isInviteRevocationMessage) {
        final inviteActionFallbackLabel =
            context.l10n.chatInviteActionFallbackLabel;
        final inviteLabel =
            previewTimelineItem?.inviteLabel.trim() ??
            effectiveMessage.body?.trim() ??
            _emptyText;
        final inviteActionLabel =
            previewTimelineItem?.inviteActionLabel.trim() ??
            inviteActionFallbackLabel;
        final inviteRoomName =
            previewTimelineItem?.inviteRoomName?.trim() ?? _emptyText;
        final inviteRoom =
            previewTimelineItem?.inviteRoom?.trim() ?? _emptyText;
        final OutlinedBorder inviteCardShape = _attachmentSurfaceShape(
          context: context,
          isSelf: isSelf,
          chainedPrevious: contentChildren.isNotEmpty,
          chainedNext: false,
        );
        contentChildren.add(
          _ParsedMessageBody(
            contentKey: '${previewItemId}_invite',
            text: inviteLabel,
            baseStyle: baseTextStyle,
            linkStyle: linkStyle,
            details: detailSpans,
            detailOpticalOffsetFactors: detailOpticalOffsetFactors,
            onLinkTap: onMessageLinkTap,
            onLinkLongPress: onMessageLinkTap,
          ),
        );
        addExtra(
          _InviteAttachmentCard(
            shape: inviteCardShape,
            enabled: false,
            label: inviteRoomName.isNotEmpty ? inviteRoomName : inviteLabel,
            detailLabel: inviteRoom.isNotEmpty ? inviteRoom : inviteLabel,
            actionLabel: inviteActionLabel,
            onPressed: () {},
          ),
        );
      } else if (hasAttachmentCaption) {
        final metadata = metadataFor(metadataIdForCaption);
        final filename = metadata?.filename.trim() ?? _emptyText;
        final displayFilename = filename.isNotEmpty
            ? filename
            : l10n.chatAttachmentFallbackLabel;
        final sizeBytes = metadata?.sizeBytes;
        final sizeLabel = sizeBytes != null && sizeBytes > 0
            ? formatBytes(sizeBytes, l10n)
            : l10n.chatAttachmentUnknownSize;
        final caption = l10n.chatAttachmentCaption(displayFilename, sizeLabel);
        contentChildren.add(
          DynamicInlineText(
            key: ValueKey(previewItemId),
            text: TextSpan(text: caption, style: baseTextStyle),
            details: detailSpans,
            detailOpticalOffsetFactors: detailOpticalOffsetFactors,
            onLinkTap: onMessageLinkTap,
            onLinkLongPress: onMessageLinkTap,
          ),
        );
      } else if (shouldRenderInlineEmailHtmlBody) {
        final preparedHtmlBody =
            HtmlContentCodec.prepareEmailHtmlForFlutterHtml(
              normalizedHtmlBody,
              allowRemoteImages: settings.autoLoadEmailImages,
            );
        if (preparedHtmlBody.trim().isNotEmpty) {
          contentChildren.add(
            _MessageHtmlBody(
              key: ValueKey(previewItemId),
              html: preparedHtmlBody,
              textStyle: baseTextStyle,
              textColor: textColor,
              linkColor: isSelf ? colors.primaryForeground : colors.primary,
              shouldLoadImages: settings.autoLoadEmailImages,
              onLinkTap: onMessageLinkTap,
            ),
          );
        }
        contentChildren.add(
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: ChatInlineDetails(
              details: detailSpans,
              detailOpticalOffsetFactors: detailOpticalOffsetFactors,
            ),
          ),
        );
      } else if (shouldRenderTextContent && messageText.isNotEmpty) {
        contentChildren.add(
          _ParsedMessageBody(
            contentKey: previewItemId,
            text: messageText,
            baseStyle: baseTextStyle,
            linkStyle: linkStyle,
            details: detailSpans,
            detailOpticalOffsetFactors: detailOpticalOffsetFactors,
            onLinkTap: onMessageLinkTap,
            onLinkLongPress: onMessageLinkTap,
          ),
        );
      } else if (attachmentIds.isEmpty &&
          calendarTask == null &&
          calendarFragment == null &&
          availabilityMessage == null) {
        contentChildren.add(
          Text(
            l10n.chatPinnedMissingMessage,
            style: context.textTheme.muted.copyWith(color: detailColor),
          ),
        );
      }
      if (effectiveMessage.retracted) {
        if (contentChildren.isNotEmpty) {
          contentChildren.add(SizedBox(height: spacing.xs));
        }
        contentChildren.add(Text(l10n.chatMessageRetracted, style: extraStyle));
      } else if (effectiveMessage.edited) {
        if (contentChildren.isNotEmpty) {
          contentChildren.add(SizedBox(height: spacing.xs));
        }
        contentChildren.add(Text(l10n.chatMessageEdited, style: extraStyle));
      }
    }

    if (availabilityMessage != null) {
      addExtra(
        CalendarAvailabilityMessageCard(
          message: availabilityMessage,
          footerDetails: availabilityFooterDetails,
        ),
      );
    } else if (calendarTask != null) {
      addExtra(
        canShowCalendarTasks
            ? ChatCalendarTaskCard(
                task: calendarTask,
                readOnly: calendarTaskReadOnly,
                requireImportConfirmation: !isSelf,
                canAddToPersonalCalendar: canAddToPersonalCalendar,
                onCopyToPersonalCalendar: onCopyTaskToPersonalCalendar,
                demoQuickAdd:
                    kEnableDemoChats &&
                    chat.defaultTransport.isEmail &&
                    !isSelf,
                footerDetails: taskFooterDetails,
                isShareFragment: true,
              )
            : CalendarFragmentCard(
                fragment: CalendarFragment.task(task: calendarTask),
                footerDetails: taskFooterDetails,
              ),
      );
    }
    if (criticalPathFragment != null) {
      addExtra(
        ChatCalendarCriticalPathCard(
          path: criticalPathFragment.path,
          tasks: criticalPathFragment.tasks,
          footerDetails: fragmentFooterDetails,
          canAddToPersonal: canAddToPersonalCalendar,
          canAddToChat: canAddToChatCalendar,
          onCopyToPersonalCalendar: onCopyCriticalPathToPersonalCalendar,
        ),
      );
    } else if (calendarFragment != null && calendarTask == null) {
      addExtra(
        CalendarFragmentCard(
          fragment: calendarFragment,
          footerDetails: fragmentFooterDetails,
        ),
      );
    }

    if (effectiveMessage != null && attachmentIds.isNotEmpty) {
      final isEmailBacked = chat.isEmailBacked;
      final bool attachmentsBlockedForPin = attachmentsBlocked;
      final allowAttachmentByTrust = shouldAllowAttachment(
        isSelf: isSelf,
        chat: chat,
      );
      final allowAttachmentOnce = attachmentsBlockedForPin
          ? false
          : isOneTimeAttachmentAllowed(effectiveMessage.stanzaID);
      final allowAttachment =
          !attachmentsBlockedForPin &&
          (allowAttachmentByTrust || allowAttachmentOnce);
      final emailDownloadDelegate = isEmailBacked
          ? AttachmentDownloadDelegate(() async {
              await context.read<ChatBloc>().downloadFullEmailMessage(
                effectiveMessage,
              );
              return true;
            })
          : null;
      for (var index = 0; index < attachmentIds.length; index += 1) {
        final attachmentId = attachmentIds[index];
        final downloadDelegate = isEmailBacked
            ? emailDownloadDelegate
            : AttachmentDownloadDelegate(
                () => context.read<ChatBloc>().downloadInboundAttachment(
                  metadataId: attachmentId,
                  stanzaId: effectiveMessage.stanzaID,
                ),
              );
        final metadataReloadDelegate = AttachmentMetadataReloadDelegate(
          () => context.read<ChatBloc>().reloadFileMetadata(attachmentId),
        );
        final hasAttachmentAbove = index > 0 || contentChildren.isNotEmpty;
        final hasAttachmentBelow = index < attachmentIds.length - 1;
        addExtra(
          ChatAttachmentPreview(
            stanzaId: effectiveMessage.stanzaID,
            metadata: metadataFor(attachmentId),
            metadataPending: metadataPendingFor(attachmentId),
            allowed: allowAttachment,
            downloadDelegate: downloadDelegate,
            metadataReloadDelegate: metadataReloadDelegate,
            surfaceShape: _attachmentSurfaceShape(
              context: context,
              isSelf: isSelf,
              chainedPrevious: hasAttachmentAbove,
              chainedNext: hasAttachmentBelow,
            ),
            onAllowPressed: allowAttachment
                ? null
                : attachmentsBlockedForPin
                ? null
                : () => onApproveAttachment(
                    message: effectiveMessage,
                    senderJid: effectiveMessage.senderJid,
                    stanzaId: effectiveMessage.stanzaID,
                    isSelf: isSelf,
                    isEmailChat: isEmailBacked,
                    senderEmail: chat.emailAddress,
                  ),
          ),
        );
      }
    }

    final pinActionBlocked =
        messageForPin != null &&
        messageForPin.awaitsMucReference(
          isGroupChat: chat.type == ChatType.groupChat,
          isEmailBacked: chat.isEmailBacked,
        );
    final pinActionPending =
        messageForPin != null &&
        messageForPin.waitsForOwnMucReference(
          isGroupChat: chat.type == ChatType.groupChat,
          isEmailBacked: chat.isEmailBacked,
          selfJid: accountJid,
          myOccupantJid: roomState?.myOccupantJid,
        );
    final Widget? unpinAction = canTogglePins && messageForPin != null
        ? AxiIconButton.destructive(
            onPressed: pinActionBlocked
                ? null
                : () => locate<ChatBloc>().add(
                    ChatMessagePinRequested(
                      message: messageForPin,
                      pin: false,
                      chat: chat,
                      roomState: roomState,
                    ),
                  ),
            iconData: LucideIcons.pinOff,
            tooltip: l10n.chatUnpinMessage,
            backgroundColor: colors.secondary,
            borderColor: colors.secondary,
            iconSize: context.sizing.menuItemIconSize,
            buttonSize: context.sizing.menuItemHeight,
            tapTargetSize: context.sizing.menuItemHeight,
            loading: pinActionPending,
          )
        : null;
    final showReplyStrip = isEmailMessage && replyParticipants.isNotEmpty;
    final showCompactReactions = !showReplyStrip && reactions.isNotEmpty;
    final showRecipientCutout =
        !showCompactReactions && isEmailMessage && shareParticipants.length > 1;
    final reactionCutoutDepth = spacing.m;
    final reactionCutoutRadius = spacing.m;
    final reactionCutoutMinThickness = spacing.l;
    final reactionStripOffset = Offset(0, -spacing.xxs);
    final reactionCutoutPadding = EdgeInsets.symmetric(
      horizontal: spacing.xs,
      vertical: spacing.xxs,
    );
    final reactionCornerClearance = spacing.s;
    final bubbleBaseRadius = _bubbleBaseRadius(context);
    final combinedReactionCornerClearance =
        _bubbleCornerClearance(bubbleBaseRadius) + reactionCornerClearance;
    final recipientCutoutDepth = spacing.m;
    final recipientCutoutRadius = spacing.m;
    final recipientCutoutPadding = EdgeInsets.fromLTRB(
      spacing.s,
      spacing.xs,
      spacing.s,
      spacing.s,
    );
    final recipientCutoutMinThickness = spacing.xl;
    Widget? reactionOverlay;
    CutoutStyle? reactionStyle;
    if (showReplyStrip) {
      reactionOverlay = _ReplyStrip(participants: replyParticipants);
      reactionStyle = CutoutStyle(
        depth: recipientCutoutDepth,
        cornerRadius: recipientCutoutRadius,
        padding: recipientCutoutPadding,
        offset: Offset.zero,
        minThickness: recipientCutoutMinThickness,
      );
    } else if (showCompactReactions) {
      reactionOverlay = _ReactionStrip(reactions: reactions);
      reactionStyle = CutoutStyle(
        depth: reactionCutoutDepth,
        cornerRadius: reactionCutoutRadius,
        shapeCornerRadius: context.radii.squircle,
        padding: reactionCutoutPadding,
        offset: reactionStripOffset,
        minThickness: reactionCutoutMinThickness,
      );
    }
    Widget? recipientOverlay;
    CutoutStyle? recipientStyle;
    if (showRecipientCutout) {
      recipientOverlay = _RecipientCutoutStrip(recipients: shareParticipants);
      recipientStyle = CutoutStyle(
        depth: recipientCutoutDepth,
        cornerRadius: recipientCutoutRadius,
        padding: recipientCutoutPadding,
        offset: Offset.zero,
        minThickness: recipientCutoutMinThickness,
      );
    }
    final replyPreview = quotedMessage == null
        ? null
        : _QuotedMessagePreview(
            message: quotedMessage,
            senderLabel: resolveQuotedSenderLabel(context, quotedMessage),
            isSelf: isSelf,
          );
    final forwardedPreview = !isForwarded
        ? null
        : _ForwardedPreviewText(
            senderLabel: resolveForwardedSenderLabel(
              context: context,
              message: effectiveMessage,
              isSelf: isSelf,
              forwardedFromJid: forwardedFromJid,
              forwardedSubjectSenderLabel: forwardedSubjectSenderLabel,
            ),
            isSelf: isSelf,
          );
    if (unpinAction != null) {
      if (contentChildren.isNotEmpty) {
        contentChildren.add(SizedBox(height: spacing.s));
      }
      contentChildren.add(
        Align(alignment: Alignment.centerRight, child: unpinAction),
      );
    }
    final bubble = ChatBubbleSurface(
      isSelf: isSelf,
      backgroundColor: bubbleColor,
      borderColor: borderColor,
      borderRadius: _bubbleBorderRadius(
        baseRadius: bubbleBaseRadius,
        isSelf: isSelf,
        chainedPrevious: false,
        chainedNext: false,
        flattenBottom: extraChildren.isNotEmpty,
      ),
      shadowOpacity: 0,
      shadows: const <BoxShadow>[],
      bubbleWidthFraction: 1.0,
      cornerClearance: combinedReactionCornerClearance,
      body: Padding(
        padding: _bubblePadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contentChildren,
        ),
      ),
      reactionOverlay: reactionOverlay,
      reactionStyle: reactionStyle,
      recipientOverlay: recipientOverlay,
      recipientStyle: recipientStyle,
    );
    final bubblePreview = MouseRegion(
      cursor: onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: bubble,
      ),
    );
    final previewMaxWidth = context.sizing.dialogMaxWidth;
    final compactReactionMinimumBubbleWidth = showCompactReactions
        ? math.min(
            previewMaxWidth,
            minimumReactionCutoutBubbleWidth(
              context: context,
              reactions: reactions,
              padding: reactionCutoutPadding,
              minThickness: reactionCutoutMinThickness,
              cornerClearance: combinedReactionCornerClearance,
            ),
          )
        : 0.0;
    final bubbleWithPreview = _ReplyPreviewBubbleColumn(
      forwardedPreview: forwardedPreview,
      quotedPreview: replyPreview,
      senderLabel: _SenderLabelBlock(
        primaryLabel: senderLabel,
        secondaryLabel: null,
        isSelf: isSelf,
        leftInset: 0.0,
      ),
      bubble: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: compactReactionMinimumBubbleWidth,
          maxWidth: previewMaxWidth,
        ),
        child: bubblePreview,
      ),
      previewMaxWidth: previewMaxWidth,
      spacing: spacing.s,
      previewSpacing: spacing.xxs,
      alignEnd: isSelf,
    );
    final bubbleColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isSelf
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        bubbleWithPreview,
        if (extraChildren.isNotEmpty) ...[
          SizedBox(height: spacing.s),
          ...extraChildren,
        ],
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.m,
        vertical: spacing.xs,
      ),
      child: Align(
        alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sizing.dialogMaxWidth),
          child: bubbleColumn,
        ),
      ),
    );
  }
}
