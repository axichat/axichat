part of '../chat.dart';

class _ComposerModeTransition extends StatelessWidget {
  const _ComposerModeTransition({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            ...previousChildren,
            if (currentChild case final Widget current) current,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        if (duration == Duration.zero) {
          return child;
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scale = Tween<double>(begin: 0.97, end: 1).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: SizeTransition(
            sizeFactor: curved,
            axisAlignment: 1,
            child: ScaleTransition(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _InlineExpandedDraftComposerSection extends StatelessWidget {
  const _InlineExpandedDraftComposerSection({
    super.key,
    required this.seed,
    required this.locate,
    required this.draftFormKey,
    required this.onUnexpand,
    required this.onClosed,
    required this.onDiscarded,
    required this.onDraftSaved,
  });

  final ComposeDraftSeed seed;
  final T Function<T>() locate;
  final GlobalKey<DraftFormState> draftFormKey;
  final VoidCallback onUnexpand;
  final VoidCallback onClosed;
  final VoidCallback onDiscarded;
  final ValueChanged<int> onDraftSaved;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: !keyboardVisible,
      child: ColoredBox(
        color: colors.background,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border, width: 1)),
          ),
          child: EmbeddedComposeDraftContent(
            seed: seed,
            locate: locate,
            draftFormKey: draftFormKey,
            recipientCountAdjustment: 1,
            subjectTrailing: AxiIconButton.secondary(
              iconData: LucideIcons.minimize2,
              tooltip: context.l10n.draftMinimize,
              semanticLabel: context.l10n.draftMinimize,
              iconSize: context.sizing.inputSuffixIconSize,
              buttonSize: context.sizing.inputSuffixButtonSize,
              tapTargetSize: context.sizing.inputSuffixButtonSize,
              cornerRadius: context.radii.squircleSm,
              onPressed: onUnexpand,
            ),
            onClosed: onClosed,
            onDiscarded: onDiscarded,
            onDraftSaved: onDraftSaved,
          ),
        ),
      ),
    );
  }
}

class _ChatComposerSection extends StatelessWidget {
  const _ChatComposerSection({
    super.key,
    this.enabled = true,
    required this.hintText,
    required this.recipients,
    required this.availableChats,
    required this.latestStatuses,
    required this.visibilityLabel,
    required this.pendingAttachments,
    required this.composerHasText,
    required this.composerMinLines,
    required this.composerMaxLines,
    required this.selfJid,
    required this.selfIdentity,
    required this.subjectController,
    required this.subjectFocusNode,
    required this.textController,
    required this.textFocusNode,
    required this.tapRegionGroup,
    required this.onSubjectSubmitted,
    required this.showExpandDraftAction,
    required this.expandDraftEnabled,
    required this.onExpandDraftPressed,
    required this.onRecipientAdded,
    required this.onRecipientRemoved,
    required this.onRecipientToggled,
    required this.onAttachmentRetry,
    required this.onAttachmentRemove,
    required this.onPendingAttachmentPressed,
    required this.onPendingAttachmentLongPressed,
    required this.pendingAttachmentMenuBuilder,
    required this.buildComposerAccessories,
    required this.sendOnEnter,
    required this.onSend,
    this.composerError,
    this.onComposerErrorCleared,
    this.showAttachmentWarning = false,
    this.retryReport,
    this.retryShareId,
    this.onFanOutRetry,
    this.onTaskDropped,
  });

  final bool enabled;
  final String hintText;
  final List<ComposerRecipient> recipients;
  final List<chat_models.Chat> availableChats;
  final Map<String, FanOutRecipientState> latestStatuses;
  final String? visibilityLabel;
  final List<PendingAttachment> pendingAttachments;
  final bool composerHasText;
  final int composerMinLines;
  final int composerMaxLines;
  final String? selfJid;
  final SelfAvatar selfIdentity;
  final TextEditingController subjectController;
  final FocusNode subjectFocusNode;
  final TextEditingController textController;
  final FocusNode textFocusNode;
  final Object tapRegionGroup;
  final VoidCallback onSubjectSubmitted;
  final bool showExpandDraftAction;
  final bool expandDraftEnabled;
  final VoidCallback onExpandDraftPressed;
  final ValueChanged<Contact> onRecipientAdded;
  final ValueChanged<String> onRecipientRemoved;
  final ValueChanged<String> onRecipientToggled;
  final ValueChanged<PendingAttachment> onAttachmentRetry;
  final ValueChanged<String> onAttachmentRemove;
  final ValueChanged<PendingAttachment> onPendingAttachmentPressed;
  final ValueChanged<PendingAttachment>? onPendingAttachmentLongPressed;
  final List<Widget> Function(PendingAttachment pending)?
  pendingAttachmentMenuBuilder;
  final List<ChatComposerAccessory> Function({required bool canSend})
  buildComposerAccessories;
  final bool sendOnEnter;
  final VoidCallback onSend;
  final String? composerError;
  final VoidCallback? onComposerErrorCleared;
  final bool showAttachmentWarning;
  final FanOutSendReport? retryReport;
  final String? retryShareId;
  final VoidCallback? onFanOutRetry;
  final ValueChanged<CalendarDragPayload>? onTaskDropped;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final myJid = selfJid;
    final suggestionAddresses = <String>{
      if (myJid != null && myJid.isNotEmpty) myJid,
    };
    final suggestionDomains = <String>{
      EndpointConfig.defaultDomain,
      if (myJid != null && myJid.isNotEmpty) mox.JID.fromString(myJid).domain,
    };
    final width = MediaQuery.sizeOf(context).width;
    final composerHorizontalInset = spacing.l;
    final desktopComposerHorizontalInset = spacing.l;
    final horizontalPadding = width >= smallScreen
        ? desktopComposerHorizontalInset
        : composerHorizontalInset;
    final cutoutBalanceInset = context.sizing.iconButtonTapTarget / 2;
    final rightPadding = math.max(0.0, horizontalPadding - cutoutBalanceInset);
    final hasQueuedAttachments = pendingAttachments.any(
      (attachment) =>
          attachment.status == PendingAttachmentStatus.queued &&
          !attachment.isPreparing,
    );
    final hasPreparingAttachments = pendingAttachments.any(
      (attachment) => attachment.isPreparing,
    );
    final hasSubjectText = subjectController.text.trim().isNotEmpty;
    final hasRecipients = recipients.isNotEmpty;
    final sendEnabled =
        enabled &&
        !hasPreparingAttachments &&
        hasRecipients &&
        (composerHasText || hasQueuedAttachments || hasSubjectText);
    final subjectHeader = _SubjectTextField(
      enabled: enabled,
      controller: subjectController,
      focusNode: subjectFocusNode,
      onSubmitted: onSubjectSubmitted,
      showExpandDraftAction: showExpandDraftAction,
      expandDraftEnabled: expandDraftEnabled,
      onExpandDraftPressed: onExpandDraftPressed,
    );
    final showAttachmentTray = pendingAttachments.isNotEmpty;
    final commandSurface = resolveCommandSurface(context);
    final useDesktopMenu = commandSurface == CommandSurface.menu;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    Widget? attachmentTray;
    if (showAttachmentTray) {
      attachmentTray = PendingAttachmentList(
        attachments: pendingAttachments,
        onRetry: onAttachmentRetry,
        onRemove: onAttachmentRemove,
        onPressed: onPendingAttachmentPressed,
        onLongPress: useDesktopMenu ? null : onPendingAttachmentLongPressed,
        contextMenuBuilder: useDesktopMenu
            ? pendingAttachmentMenuBuilder
            : null,
      );
    }
    final composer = SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: !keyboardVisible,
      child: SizedBox(
        width: double.infinity,
        child: ColoredBox(
          color: colors.background,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.border, width: 1)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                spacing.m,
                rightPadding,
                spacing.s,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (attachmentTray != null) ...[
                    attachmentTray,
                    SizedBox(height: spacing.m),
                  ],
                  _ComposerTaskDropRegion(
                    onTaskDropped: onTaskDropped,
                    child: ChatCutoutComposer(
                      controller: textController,
                      focusNode: textFocusNode,
                      hintText: hintText,
                      minLines: composerMinLines,
                      maxLines: composerMaxLines,
                      semanticsLabel: context.l10n.chatComposerSemantics,
                      onSend: onSend,
                      header: subjectHeader,
                      actions: buildComposerAccessories(canSend: sendEnabled),
                      sendEnabled: sendEnabled,
                      sendOnEnter: sendOnEnter,
                      enabled: enabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final locate = context.read;
    final children = <Widget>[];
    children.add(
      BlocSelector<ChatsCubit, ChatsState, List<String>>(
        bloc: locate<ChatsCubit>(),
        selector: (state) => state.recipientAddressSuggestions,
        builder: (context, recipientAddressSuggestions) {
          final rosterItems =
              context.watch<RosterCubit>().state.items ??
              (context.watch<RosterCubit>()[RosterCubit.itemsCacheKey]
                  as List<RosterItem>?) ??
              const <RosterItem>[];
          return RecipientChipsBar(
            recipients: recipients,
            availableChats: availableChats,
            rosterItems: rosterItems,
            databaseSuggestionAddresses: recipientAddressSuggestions,
            selfJid: locate<ChatsCubit>().selfJid,
            selfIdentity: selfIdentity,
            latestStatuses: latestStatuses,
            collapsedByDefault: true,
            suggestionAddresses: suggestionAddresses,
            suggestionDomains: suggestionDomains,
            onRecipientAdded: onRecipientAdded,
            onRecipientRemoved: onRecipientRemoved,
            onRecipientToggled: onRecipientToggled,
            visibilityLabel: visibilityLabel,
            tapRegionGroup: tapRegionGroup,
          );
        },
      ),
    );
    children.add(Opacity(opacity: enabled ? 1.0 : 0.56, child: composer));
    final content = TapRegion(
      groupId: tapRegionGroup,
      onTapUpOutside: (_) {
        if (!textFocusNode.hasFocus && !subjectFocusNode.hasFocus) {
          return;
        }
        textFocusNode.unfocus();
        subjectFocusNode.unfocus();
      },
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
    if (enabled) {
      return content;
    }
    return IgnorePointer(child: content);
  }
}

class _ComposerTaskDropRegion extends StatelessWidget {
  const _ComposerTaskDropRegion({required this.child, this.onTaskDropped});

  final Widget child;
  final ValueChanged<CalendarDragPayload>? onTaskDropped;

  @override
  Widget build(BuildContext context) {
    final onTaskDropped = this.onTaskDropped;
    if (onTaskDropped == null) {
      return child;
    }
    final colors = context.colorScheme;
    return DragTarget<CalendarDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onTaskDropped(details.data),
      builder: (context, candidate, rejected) {
        final bool hovering = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            border: Border.all(
              color: hovering ? colors.primary : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: child,
        );
      },
    );
  }
}

class _SubjectTextField extends StatelessWidget {
  const _SubjectTextField({
    required this.enabled,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.showExpandDraftAction,
    required this.expandDraftEnabled,
    required this.onExpandDraftPressed,
  });

  final bool enabled;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final bool showExpandDraftAction;
  final bool expandDraftEnabled;
  final VoidCallback onExpandDraftPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final subjectStyle = context.textTheme.small.copyWith(
      color: colors.foreground,
    );
    final subjectStrutStyle = StrutStyle.fromTextStyle(
      subjectStyle,
      forceStrutHeight: true,
      height: subjectStyle.height,
      leading: 0,
    );
    const inputDecoration = ShadDecoration(
      color: Colors.transparent,
      border: ShadBorder.none,
      secondaryBorder: ShadBorder.none,
      secondaryFocusedBorder: ShadBorder.none,
      focusedBorder: ShadBorder.none,
      errorBorder: ShadBorder.none,
      secondaryErrorBorder: ShadBorder.none,
      disableSecondaryBorder: true,
    );
    return SizedBox(
      height: sizing.menuItemHeight,
      child: Semantics(
        label: l10n.chatSubjectSemantics,
        textField: true,
        child: Row(
          children: [
            Text(
              '${l10n.chatSubjectHint}:',
              style: context.textTheme.small.copyWith(
                color: colors.mutedForeground,
              ),
            ),
            SizedBox(width: spacing.xs),
            Expanded(
              child: AxiInput(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                readOnly: !enabled,
                showCursor: enabled,
                enableInteractiveSelection: enabled,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: enabled ? (_) => onSubmitted() : null,
                onEditingComplete: enabled ? onSubmitted : null,
                keyboardType: TextInputType.text,
                style: subjectStyle,
                strutStyle: subjectStrutStyle,
                cursorHeight: subjectStyle.fontSize,
                decoration: inputDecoration,
                padding: EdgeInsets.zero,
                inputPadding: EdgeInsets.zero,
                constraints: const BoxConstraints(minHeight: 0),
              ),
            ),
            if (showExpandDraftAction) ...[
              SizedBox(width: spacing.xs),
              AxiIconButton.secondary(
                iconData: LucideIcons.maximize2,
                tooltip: l10n.draftExpand,
                semanticLabel: l10n.draftExpand,
                iconSize: sizing.inputSuffixIconSize,
                buttonSize: sizing.inputSuffixButtonSize,
                tapTargetSize: sizing.inputSuffixButtonSize,
                cornerRadius: context.radii.squircleSm,
                onPressed: enabled && expandDraftEnabled
                    ? onExpandDraftPressed
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyComposerBanner extends StatelessWidget {
  const _ReadOnlyComposerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final titleIndent = context.sizing.menuItemIconSize + spacing.s;
    final textTheme = context.textTheme;
    return _ComposerAttachedBannerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ComposerBannerLeading(
                child: Icon(
                  LucideIcons.archive,
                  size: context.sizing.menuItemIconSize,
                  color: colors.mutedForeground,
                ),
              ),
              SizedBox(width: spacing.s),
              Expanded(
                child: Text(
                  l10n.chatReadOnly,
                  style: textTheme.p.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.xxs),
          Padding(
            padding: EdgeInsets.only(left: titleIndent),
            child: Text(
              l10n.chatUnarchivePrompt,
              style: textTheme.p.copyWith(color: colors.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomBootstrapComposerBanner extends StatelessWidget {
  const _RoomBootstrapComposerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final titleIndent = context.sizing.menuItemIconSize + spacing.s;
    final textTheme = context.textTheme;
    return _ComposerAttachedBannerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ComposerBannerLeading(
                child: AxiProgressIndicator(
                  color: colors.foreground,
                  semanticsLabel: l10n.xmppOperationMucJoinStart,
                ),
              ),
              SizedBox(width: spacing.s),
              Expanded(
                child: Text(
                  l10n.xmppOperationMucJoinStart,
                  style: textTheme.p.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.xxs),
          Padding(
            padding: EdgeInsets.only(left: titleIndent),
            child: Text(
              l10n.chatMembersLoadingEllipsis,
              style: textTheme.p.copyWith(color: colors.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomJoinFailureComposerBanner extends StatelessWidget {
  const _RoomJoinFailureComposerBanner({super.key, this.detail});

  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final normalizedDetail = detail?.trim();
    final titleIndent = context.sizing.menuItemIconSize + spacing.s;
    final textTheme = context.textTheme;
    return _ComposerAttachedBannerSurface(
      backgroundColor: Color.alphaBlend(
        colors.destructive.withValues(alpha: 0.08),
        colors.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ComposerBannerLeading(
                child: Icon(
                  LucideIcons.triangleAlert,
                  size: context.sizing.menuItemIconSize,
                  color: colors.destructive,
                ),
              ),
              SizedBox(width: spacing.s),
              Expanded(
                child: Text(
                  l10n.chatInviteJoinFailed,
                  style: textTheme.p.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.destructive,
                  ),
                ),
              ),
            ],
          ),
          if (normalizedDetail?.isNotEmpty == true) ...[
            SizedBox(height: spacing.xxs),
            Padding(
              padding: EdgeInsets.only(left: titleIndent),
              child: Text(
                normalizedDetail!,
                style: textTheme.p.copyWith(color: colors.mutedForeground),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposerAttachedBannerSurface extends StatelessWidget {
  const _ComposerAttachedBannerSurface({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    return SizedBox(
      width: double.infinity,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor ?? colors.card,
            border: Border(
              top: BorderSide(color: borderColor ?? colors.border, width: 1),
            ),
          ),
          child: Padding(padding: EdgeInsets.all(spacing.m), child: child),
        ),
      ),
    );
  }
}

class _ComposerBannerLeading extends StatelessWidget {
  const _ComposerBannerLeading({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: context.sizing.menuItemIconSize,
      child: Center(child: child),
    );
  }
}

class _ComposerBannerTrailing extends StatelessWidget {
  const _ComposerBannerTrailing({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class _EmojiPickerAccessory extends StatelessWidget {
  const _EmojiPickerAccessory({
    required this.controller,
    required this.textController,
  });

  final ShadPopoverController controller;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    return AxiPopover(
      controller: controller,
      child: _ChatComposerIconButton(
        icon: LucideIcons.smile,
        tooltip: context.l10n.chatEmojiPicker,
        onPressed: controller.toggle,
      ),
      popover: (context) => EmojiPicker(
        textEditingController: textController,
        config: Config(
          emojiViewConfig: EmojiViewConfig(
            emojiSizeMax: context.read<Policy>().getMaxEmojiSize(),
          ),
        ),
      ),
    );
  }
}

class _AttachmentAccessoryButton extends StatelessWidget {
  const _AttachmentAccessoryButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ChatComposerIconButton(
      icon: LucideIcons.paperclip,
      tooltip: enabled
          ? l10n.chatAttachmentTooltip
          : l10n.chatComposerFileUploadUnavailable,
      onPressed: enabled ? onPressed : null,
    );
  }
}

class _SendMessageAccessory extends StatelessWidget {
  const _SendMessageAccessory({
    required this.enabled,
    required this.onPressed,
    this.onLongPress,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return _ChatComposerIconButton(
      icon: LucideIcons.send,
      tooltip: context.l10n.chatSendMessageTooltip,
      activeColor: context.colorScheme.primary,
      onPressed: enabled ? onPressed : null,
      onLongPress: onLongPress,
    );
  }
}

class _ChatComposerIconButton extends StatelessWidget {
  const _ChatComposerIconButton({
    required this.icon,
    required this.tooltip,
    this.activeColor,
    this.onPressed,
    this.onLongPress,
  });

  final IconData icon;
  final String tooltip;
  final Color? activeColor;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final iconColor = onPressed != null
        ? (activeColor ?? colors.mutedForeground)
        : colors.mutedForeground;
    final sizing = context.sizing;
    return AxiIconButton(
      iconData: icon,
      tooltip: tooltip,
      semanticLabel: tooltip,
      onPressed: onPressed,
      onLongPress: onLongPress,
      color: iconColor,
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: context.borderSide.width,
      cornerRadius: context.radii.squircle,
      iconSize: sizing.iconButtonIconSize,
      buttonSize: sizing.iconButtonSize,
      tapTargetSize: sizing.iconButtonTapTarget,
    );
  }
}

enum _ComposerNoticeType { error, warning, info }

class _ComposerNotice extends StatelessWidget {
  const _ComposerNotice({
    super.key,
    required this.type,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final _ComposerNoticeType type;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    final (Color background, Color foreground, IconData icon) = switch (type) {
      _ComposerNoticeType.error => (
        colors.destructive,
        colors.destructiveForeground,
        Icons.error_outline,
      ),
      _ComposerNoticeType.warning => (
        colors.warning,
        colors.foreground,
        Icons.warning_amber_rounded,
      ),
      _ComposerNoticeType.info => (
        colors.card,
        colors.foreground,
        Icons.refresh,
      ),
    };

    return _ComposerAttachedBannerSurface(
      backgroundColor: background,
      borderColor: colors.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ComposerBannerLeading(
            child: Icon(
              icon,
              size: context.sizing.menuItemIconSize,
              color: foreground,
            ),
          ),
          SizedBox(width: context.spacing.s),
          Expanded(
            child: Text(
              message,
              style: textTheme.p.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            _ComposerBannerTrailing(
              child: AxiButton(
                variant: AxiButtonVariant.ghost,
                size: AxiButtonSize.sm,
                onPressed: onAction,
                child: Text(
                  actionLabel,
                  style: textTheme.p.copyWith(color: foreground),
                ),
              ),
            ),
          if (onDismiss != null)
            _ComposerBannerTrailing(
              child: AxiIconButton.ghost(
                iconData: LucideIcons.x,
                tooltip: context.l10n.commonClose,
                onPressed: onDismiss,
                color: foreground,
                backgroundColor: Colors.transparent,
                iconSize: context.sizing.menuItemIconSize,
                buttonSize: context.sizing.menuItemHeight,
                tapTargetSize: context.sizing.menuItemHeight,
              ),
            ),
        ],
      ),
    );
  }
}

class _ComposerNotices extends StatelessWidget {
  const _ComposerNotices({
    required this.composerError,
    required this.onComposerErrorCleared,
    required this.showAttachmentWarning,
    required this.retryReport,
    required this.retryShareId,
    required this.onFanOutRetry,
  });

  final String? composerError;
  final VoidCallback? onComposerErrorCleared;
  final bool showAttachmentWarning;
  final FanOutSendReport? retryReport;
  final String? retryShareId;
  final VoidCallback? onFanOutRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notices = <Widget>[];
    final composerError = this.composerError;
    if (composerError != null && composerError.isNotEmpty) {
      notices.add(
        _ComposerNotice(
          type: _ComposerNoticeType.error,
          message: composerError,
          onDismiss: onComposerErrorCleared,
        ),
      );
    }
    if (showAttachmentWarning) {
      notices.add(
        _ComposerNotice(
          type: _ComposerNoticeType.warning,
          message: l10n.chatComposerAttachmentWarning,
        ),
      );
    }
    final report = retryReport;
    final shareId = retryShareId;
    if (report != null && shareId != null) {
      final failedCount = report.statuses
          .where((status) => status.state == FanOutRecipientState.failed)
          .length;
      if (failedCount > 0) {
        final label = l10n.chatFanOutRecipientLabel(failedCount);
        final subjectLabel = report.subject?.trim();
        final failureMessage = subjectLabel?.isNotEmpty == true
            ? l10n.chatFanOutFailureWithSubject(
                subjectLabel!,
                failedCount,
                label,
              )
            : l10n.chatFanOutFailure(failedCount, label);
        notices.add(
          _ComposerNotice(
            type: _ComposerNoticeType.info,
            message: failureMessage,
            actionLabel: onFanOutRetry == null ? null : l10n.chatFanOutRetry,
            onAction: onFanOutRetry,
          ),
        );
      }
    }
    if (notices.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: notices,
    );
  }
}

class _DebugComposerNotices extends StatelessWidget {
  const _DebugComposerNotices();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ComposerNotice(
          type: _ComposerNoticeType.error,
          message: 'Debug failed-send banner',
          onDismiss: () {},
        ),
        _ComposerNotice(
          type: _ComposerNoticeType.warning,
          message: 'Debug attachment warning banner',
        ),
        _ComposerNotice(
          type: _ComposerNoticeType.info,
          message: 'Debug retry/sync banner',
          actionLabel: 'Retry',
          onAction: () {},
        ),
      ],
    );
  }
}

class _DebugComposerOverlayBanner extends StatelessWidget {
  const _DebugComposerOverlayBanner();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ReadOnlyComposerBanner(),
        SizedBox(height: spacing.s),
        _MessageSelectionToolbar(
          count: 2,
          onClear: () {},
          onCopy: () {},
          onShare: () {},
          shareStatus: RequestStatus.none,
          onForward: () {},
          onAddToCalendar: () {},
        ),
      ],
    );
  }
}

class _ComposerBannerVisibility extends StatefulWidget {
  const _ComposerBannerVisibility({
    required this.child,
    required this.visible,
    required this.animationDuration,
    required this.minimumVisibleDuration,
    required this.slideOffset,
  });

  final Widget? child;
  final bool visible;
  final Duration animationDuration;
  final Duration minimumVisibleDuration;
  final Offset slideOffset;

  @override
  State<_ComposerBannerVisibility> createState() =>
      _ComposerBannerVisibilityState();
}

class _ComposerBannerVisibilityState extends State<_ComposerBannerVisibility> {
  Widget? displayedChild;
  DateTime? shownAt;
  Timer? hideTimer;
  Object switchKey = Object();

  @override
  void initState() {
    super.initState();
    displayedChild = widget.visible ? widget.child : null;
    shownAt = displayedChild == null ? null : DateTime.timestamp();
  }

  @override
  void didUpdateWidget(covariant _ComposerBannerVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVisibility();
  }

  void _syncVisibility() {
    final nextChild = widget.child;
    if (widget.visible && nextChild != null) {
      hideTimer?.cancel();
      final previousChild = displayedChild;
      final needsNewKey =
          previousChild == null ||
          previousChild.runtimeType != nextChild.runtimeType ||
          previousChild.key != nextChild.key;
      setState(() {
        displayedChild = nextChild;
        if (previousChild == null || needsNewKey) {
          shownAt = DateTime.timestamp();
        }
        if (needsNewKey) {
          switchKey = Object();
        }
      });
      return;
    }
    if (displayedChild == null) {
      return;
    }
    final elapsed = shownAt == null
        ? widget.minimumVisibleDuration
        : DateTime.timestamp().difference(shownAt!);
    final remaining = widget.minimumVisibleDuration - elapsed;
    if (remaining > Duration.zero) {
      hideTimer?.cancel();
      hideTimer = Timer(remaining, _beginHide);
      return;
    }
    _beginHide();
  }

  void _beginHide() {
    hideTimer?.cancel();
    hideTimer = null;
    if (widget.visible || displayedChild == null) {
      return;
    }
    setState(() {
      displayedChild = null;
      shownAt = null;
      switchKey = Object();
    });
  }

  @override
  void dispose() {
    hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentChild = displayedChild == null
        ? const SizedBox.shrink(key: ValueKey<String>('composer-banner-empty'))
        : KeyedSubtree(
            key: ValueKey<Object>(switchKey),
            child: displayedChild!,
          );
    return AnimatedSize(
      duration: widget.animationDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: widget.animationDuration,
        reverseDuration: widget.animationDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ...previousChildren,
              if (currentChild case final Widget current) current,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return ClipRect(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: widget.slideOffset,
                end: Offset.zero,
              ).animate(curved),
              child: SizeTransition(
                sizeFactor: curved,
                axisAlignment: 1.0,
                child: child,
              ),
            ),
          );
        },
        child: currentChild,
      ),
    );
  }
}

class _DebugComposerBannerCycle extends StatefulWidget {
  const _DebugComposerBannerCycle({
    required this.animationDuration,
    required this.interval,
  });

  final Duration animationDuration;
  final Duration interval;

  @override
  State<_DebugComposerBannerCycle> createState() =>
      _DebugComposerBannerCycleState();
}

class _DebugComposerBannerCycleState extends State<_DebugComposerBannerCycle> {
  Timer? cycleTimer;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _DebugComposerBannerCycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interval != widget.interval) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    cycleTimer?.cancel();
    if (widget.interval <= Duration.zero) {
      return;
    }
    cycleTimer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() {
        currentIndex++;
      });
    });
  }

  @override
  void dispose() {
    cycleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final debugMessage = Message(
      stanzaID: 'debug-composer-banner-quote',
      senderJid: 'debug@axi.im',
      chatJid: 'debug@axi.im',
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      body: 'Debug quote preview content.',
    );
    final banners = <Widget>[
      ComposerQuoteBanner(
        key: const ValueKey<String>('debug-quote-banner'),
        senderLabel: 'Debug Sender',
        previewText:
            previewTextForMessage(debugMessage) ??
            context.l10n.chatQuotedNoContent,
        isSelf: false,
        onClear: () {},
      ),
      _ComposerNotice(
        key: const ValueKey<String>('debug-error-banner'),
        type: _ComposerNoticeType.error,
        message: 'Debug failed-send banner',
        onDismiss: () {},
      ),
      _ComposerNotice(
        key: const ValueKey<String>('debug-warning-banner'),
        type: _ComposerNoticeType.warning,
        message: 'Debug attachment warning banner',
      ),
      _ComposerNotice(
        key: const ValueKey<String>('debug-info-banner'),
        type: _ComposerNoticeType.info,
        message: 'Debug retry/sync banner',
        actionLabel: 'Retry',
        onAction: () {},
      ),
      const _ReadOnlyComposerBanner(key: ValueKey<String>('debug-read-only')),
      const _RoomBootstrapComposerBanner(
        key: ValueKey<String>('debug-room-bootstrap'),
      ),
      _RoomJoinFailureComposerBanner(
        key: const ValueKey<String>('debug-room-failure'),
        detail: 'Membership is required to enter this room',
      ),
      _ComposerAttachedBannerSurface(
        key: const ValueKey<String>('debug-email-sync-banner'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ComposerBannerLeading(
              child: Icon(
                LucideIcons.mailWarning,
                size: context.sizing.menuItemIconSize,
                color: colors.destructive,
              ),
            ),
            SizedBox(width: context.spacing.s),
            Expanded(
              child: Text(
                l10n.messageErrorServiceUnavailable,
                style: textTheme.p.copyWith(
                  color: colors.destructive,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
    final banner = banners[currentIndex % banners.length];
    return AnimatedSwitcher(
      duration: widget.animationDuration,
      reverseDuration: widget.animationDuration,
      switchInCurve: Curves.easeOutCubic,
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
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      child: banner,
    );
  }
}

class _ComposerBottomOverlay extends StatelessWidget {
  const _ComposerBottomOverlay({
    required this.quotedMessage,
    required this.quotedSenderLabel,
    required this.quotedIsSelf,
    required this.onClearQuote,
    required this.animationDuration,
    this.notices,
    this.banner,
  });

  final Message? quotedMessage;
  final String? quotedSenderLabel;
  final bool quotedIsSelf;
  final VoidCallback onClearQuote;
  final Duration animationDuration;
  final Widget? notices;
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    Widget? quoteSection;
    final quotedMessage = this.quotedMessage;
    final quotedSenderLabel = this.quotedSenderLabel;
    if (quotedMessage == null || quotedSenderLabel == null) {
      quoteSection = null;
    } else {
      quoteSection = ComposerQuoteBanner(
        key: ValueKey<String?>(quotedMessage.stanzaID),
        senderLabel: quotedSenderLabel,
        previewText:
            previewTextForMessage(quotedMessage) ??
            context.l10n.chatQuotedNoContent,
        isSelf: quotedIsSelf,
        onClear: onClearQuote,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ComposerBannerVisibility(
          visible: quoteSection != null,
          animationDuration: animationDuration,
          minimumVisibleDuration: motion.composerBannerMinVisibilityDuration,
          slideOffset: motion.composerBannerSlideOffset,
          child: quoteSection,
        ),
        _ComposerBannerVisibility(
          visible: notices != null,
          animationDuration: animationDuration,
          minimumVisibleDuration: motion.composerBannerMinVisibilityDuration,
          slideOffset: motion.composerBannerSlideOffset,
          child: notices,
        ),
        _ComposerBannerVisibility(
          visible: banner != null,
          animationDuration: animationDuration,
          minimumVisibleDuration: motion.composerBannerMinVisibilityDuration,
          slideOffset: motion.composerBannerSlideOffset,
          child: banner,
        ),
      ],
    );
  }
}
