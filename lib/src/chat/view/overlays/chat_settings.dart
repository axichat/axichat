part of '../chat.dart';

class _ChatSettingsButtons extends StatelessWidget {
  const _ChatSettingsButtons({
    required this.state,
    required this.onViewFilterChanged,
    required this.onNotificationBehaviorChanged,
    required this.onSpamToggle,
    required this.onRenameContact,
    required this.isChatBlocked,
    required this.blocklistEntry,
    required this.blockAddress,
  });

  final ChatState state;
  final ValueChanged<MessageTimelineFilter> onViewFilterChanged;
  final ValueChanged<ChatNotificationBehavior?> onNotificationBehaviorChanged;
  final ValueChanged<bool> onSpamToggle;
  final VoidCallback? onRenameContact;
  final bool isChatBlocked;
  final BlocklistEntry? blocklistEntry;
  final String? blockAddress;

  @override
  Widget build(BuildContext context) {
    final chat = state.chat;
    if (chat == null) {
      return const SizedBox.expand();
    }
    final AppLocalizations l10n = context.l10n;
    final colors = context.colorScheme;
    final destructiveColor = colors.destructive;
    final BlocklistState blocklistState = context.watch<BlocklistCubit>().state;
    final settingsState = context.watch<SettingsCubit>().state;
    final bool signatureActive =
        chat.shareSignatureEnabled ?? settingsState.shareTokenSignatureEnabled;
    final String signatureHint = signatureActive
        ? l10n.chatSignatureHintEnabled
        : l10n.chatSignatureHintDisabled;
    final String signatureWarning = l10n.chatSignatureHintWarning;
    final bool showAttachmentToggle =
        chat.defaultTransport.isXmpp && chat.type != ChatType.note;
    final bool canRenameContact =
        chat.type == ChatType.chat && !chat.isAxichatWelcomeThread;
    final bool isSpamChat = chat.spam;
    final String spamLabel = l10n.chatReportSpam;
    final String? resolvedBlockAddress = blockAddress?.trim();
    final String? resolvedBlockEntryAddress = blocklistEntry?.address.trim();
    final bool hasBlockAddress =
        resolvedBlockAddress != null && resolvedBlockAddress.isNotEmpty;
    final bool hasBlockEntry = blocklistEntry != null;
    final bool showXmppCapabilities =
        chat.defaultTransport.isXmpp && !chat.isAxichatWelcomeThread;
    final blockTransport = chat.defaultTransport;
    final itemPadding = EdgeInsets.all(context.spacing.m);
    final bool blockActionInFlight = switch (blocklistState) {
      BlocklistLoading state =>
        state.jid == null ||
            state.jid == resolvedBlockAddress ||
            state.jid == resolvedBlockEntryAddress,
      _ => false,
    };
    final bool blockSwitchEnabled =
        !blockActionInFlight &&
        (isChatBlocked ? hasBlockEntry : hasBlockAddress);
    final List<Widget> tiles = [
      if (canRenameContact && onRenameContact != null)
        Padding(
          padding: itemPadding,
          child: AxiListButton(
            leading: Icon(
              LucideIcons.pencilLine,
              size: context.sizing.menuItemIconSize,
            ),
            onPressed: onRenameContact,
            child: Text(l10n.chatContactRenameTooltip),
          ),
        ),
      if (showXmppCapabilities)
        Padding(
          padding: itemPadding,
          child: _ChatCapabilitiesSection(
            capabilities: state.xmppCapabilities,
            isGroupChat: chat.type == ChatType.groupChat,
          ),
        ),
      if (state.canOfferEmailOutboundOverride)
        Padding(
          padding: itemPadding,
          child: _ChatSettingsSwitchRow(
            title: l10n.chatEmailOutboundOverrideTitle,
            subtitle: l10n.chatEmailOutboundOverrideSubtitle,
            value: state.usesSavedEmailTransportOverride,
            loading: state.savedTransportOverrideStatus.isLoading,
            onChanged: state.savedTransportOverrideStatus.isLoading
                ? null
                : (enabled) => context.read<ChatBloc>().add(
                    ChatSavedTransportOverrideChanged(
                      chatJid: chat.jid,
                      transport: enabled ? MessageTransport.email : null,
                    ),
                  ),
          ),
        ),
      if (showAttachmentToggle)
        Padding(
          padding: itemPadding,
          child: _ChatAttachmentTrustToggle(state: state, chat: chat),
        ),
      if (chat.defaultTransport.isXmpp)
        Padding(
          padding: itemPadding,
          child: _ChatInheritedBoolControl(
            state: state,
            settingId: ChatSettingId.readReceipts,
            title: l10n.settingsChatReadReceipts,
            subtitle: l10n.settingsChatReadReceiptsDescription,
            inheritedValue: settingsState.chatReadReceipts,
            value: chat.markerResponsive,
            onChanged: (value) => context.read<ChatBloc>().add(
              ChatResponsivityChanged(chatJid: chat.jid, responsive: value),
            ),
          ),
        ),
      if (chat.defaultTransport.isXmpp)
        Padding(
          padding: itemPadding,
          child: _ChatInheritedBoolControl(
            state: state,
            settingId: ChatSettingId.typingIndicators,
            title: l10n.settingsTypingIndicators,
            subtitle: l10n.settingsTypingIndicatorsDescription,
            inheritedValue: settingsState.indicateTyping,
            value: chat.typingIndicatorsEnabled,
            onChanged: (value) => context.read<ChatBloc>().add(
              ChatTypingIndicatorsChanged(chatJid: chat.jid, enabled: value),
            ),
          ),
        ),
      if (chat.defaultTransport.isEmail)
        Padding(
          padding: itemPadding,
          child: _ChatInheritedBoolControl(
            state: state,
            settingId: ChatSettingId.emailImageAutoload,
            title: l10n.settingsAutoLoadEmailImages,
            subtitle: l10n.settingsAutoLoadEmailImagesDescription,
            inheritedValue: settingsState.autoLoadEmailImages,
            value: chat.emailRemoteImagesEnabled,
            onChanged: (value) => context.read<ChatBloc>().add(
              ChatEmailRemoteImagesChanged(chatJid: chat.jid, enabled: value),
            ),
          ),
        ),
      if (chat.defaultTransport.isEmail)
        Padding(
          padding: itemPadding,
          child: _ChatInheritedBoolControl(
            state: state,
            settingId: ChatSettingId.emailSendConfirmation,
            title: l10n.settingsEmailSendConfirmation,
            subtitle: l10n.settingsEmailSendConfirmationDescription,
            inheritedValue: settingsState.emailSendConfirmationEnabled,
            value: chat.emailSendConfirmationEnabled,
            onChanged: (value) => context.read<ChatBloc>().add(
              ChatEmailSendConfirmationChanged(
                chatJid: chat.jid,
                enabled: value,
              ),
            ),
          ),
        ),
      if (chat.defaultTransport.isEmail)
        Padding(
          padding: itemPadding,
          child: _ChatInheritedBoolControl(
            state: state,
            settingId: ChatSettingId.emailComposerWatermark,
            title: l10n.settingsEmailComposerWatermark,
            subtitle: l10n.settingsEmailComposerWatermarkDescription,
            inheritedValue: settingsState.emailComposerWatermarkEnabled,
            value: chat.emailComposerWatermarkEnabled,
            onChanged: (value) => context.read<ChatBloc>().add(
              ChatEmailComposerWatermarkChanged(
                chatJid: chat.jid,
                enabled: value,
              ),
            ),
          ),
        ),
      if (chat.defaultTransport.isEmail)
        Padding(
          padding: itemPadding,
          child: _ChatInheritedBoolControl(
            state: state,
            settingId: ChatSettingId.emailReadReceipts,
            title: l10n.settingsEmailReadReceipts,
            subtitle: l10n.settingsEmailReadReceiptsDescription,
            inheritedValue: settingsState.emailReadReceipts,
            value: chat.emailReadReceiptsEnabled,
            onChanged: (value) => context.read<ChatBloc>().add(
              ChatEmailReadReceiptsChanged(chatJid: chat.jid, enabled: value),
            ),
          ),
        ),
      Padding(
        padding: itemPadding,
        child: _ChatViewFilterControl(
          filter: state.viewFilter,
          onChanged: onViewFilterChanged,
        ),
      ),
      Padding(
        padding: itemPadding,
        child: _ChatNotificationBehaviorControl(
          state: state,
          behavior: chat.effectiveNotificationBehavior,
          inheritedMuted: blockTransport.isEmail
              ? settingsState.emailNotificationsMuted
              : settingsState.chatNotificationsMuted,
          onChanged: onNotificationBehaviorChanged,
        ),
      ),
      if (defaultTargetPlatform.supportsNotificationPreviewControls)
        Padding(
          padding: itemPadding,
          child: _ChatNotificationPreviewControl(
            state: state,
            setting: chat.notificationPreviewSetting,
            inheritedPreviewsEnabled: settingsState.notificationPreviewsEnabled,
            onChanged: (setting) => context.read<ChatBloc>().add(
              ChatNotificationPreviewSettingChanged(
                chat: chat,
                setting: setting,
              ),
            ),
          ),
        ),
      if (chat.defaultTransport.isEmail)
        Padding(
          padding: itemPadding,
          child: _ChatInheritedBoolControl(
            state: state,
            settingId: ChatSettingId.shareSignature,
            title: l10n.chatSignatureToggleLabel,
            subtitle: '$signatureHint $signatureWarning',
            inheritedValue: settingsState.shareTokenSignatureEnabled,
            value: chat.shareSignatureEnabled,
            onChanged: (enabled) => context.read<ChatBloc>().add(
              ChatShareSignatureToggled(chat: chat, enabled: enabled),
            ),
          ),
        ),
      Padding(
        padding: itemPadding,
        child: _ChatSettingsSwitchRow(
          title: spamLabel,
          titleColor: destructiveColor,
          checkedTrackColor: destructiveColor,
          value: isSpamChat,
          onChanged: onSpamToggle,
        ),
      ),
      Padding(
        padding: itemPadding,
        child: _ChatSettingsSwitchRow(
          title: l10n.blocklistBlock,
          titleColor: destructiveColor,
          checkedTrackColor: destructiveColor,
          value: isChatBlocked,
          onChanged: blockSwitchEnabled
              ? (blocked) {
                  if (blocked == isChatBlocked) {
                    return;
                  }
                  if (blocked) {
                    final address = resolvedBlockAddress;
                    if (address == null || address.isEmpty) {
                      return;
                    }
                    context.read<BlocklistCubit>().block(
                      address: address,
                      transport: blockTransport,
                    );
                    return;
                  }
                  final entry = blocklistEntry;
                  if (entry == null) {
                    return;
                  }
                  context.read<BlocklistCubit>().unblock(entry: entry);
                }
              : null,
        ),
      ),
    ];
    return ListView(padding: EdgeInsets.zero, children: tiles);
  }
}

class _ChatCapabilitiesSection extends StatelessWidget {
  const _ChatCapabilitiesSection({
    required this.capabilities,
    required this.isGroupChat,
  });

  final XmppPeerCapabilities? capabilities;
  final bool isGroupChat;

  String _formatFeatureLabel(String feature) {
    final trimmed = feature.trim();
    if (trimmed.isEmpty) return trimmed;
    final normalized = trimmed
        .replaceAll('urn:xmpp:', '')
        .replaceAll('http://jabber.org/protocol/', '')
        .replaceAll('jabber:iq:', '')
        .replaceAll('urn:ietf:params:xml:ns:', '')
        .replaceAll('/', ' ')
        .replaceAll('#', ' ')
        .replaceAll(':', ' ')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    final parts = normalized
        .split(RegExp(r'\\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    return parts
        .map((part) {
          final lower = part.toLowerCase();
          if (lower.length <= 3) {
            return lower.toUpperCase();
          }
          if (lower.length == 4 && lower == 'xep') {
            return lower.toUpperCase();
          }
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final capabilitiesResolvedAt = capabilities?.capabilitiesResolvedAt;
    final String subtitle = capabilitiesResolvedAt == null
        ? l10n.commonUnknownLabel
        : l10n.chatSettingsCapabilitiesUpdated(
            TimeFormatter.formatFriendlyDateTime(l10n, capabilitiesResolvedAt),
          );
    final supportsMarkers = capabilities?.supportsMarkers ?? false;
    final supportsReceipts = capabilities?.supportsReceipts ?? false;
    final supportsTypingIndicators =
        capabilities?.supportsFeature(mox.chatStateXmlns) ?? false;
    final supportsReactions =
        capabilities?.supportsFeature(mox.messageReactionsXmlns) ?? false;
    final supportsMam = capabilities?.supportsFeature(mox.mamXmlns) ?? false;
    final supportsMuc =
        isGroupChat && (capabilities?.supportsFeature(mox.mucXmlns) ?? false);
    final List<_CapabilityEntry> entries = [
      if (supportsMarkers || supportsReceipts)
        _CapabilityEntry(
          label: l10n.settingsChatReadReceipts,
          detail: l10n.settingsChatReadReceiptsDescription,
        ),
      if (supportsTypingIndicators)
        _CapabilityEntry(
          label: l10n.settingsTypingIndicators,
          detail: l10n.settingsTypingIndicatorsDescription,
        ),
      if (supportsReactions)
        _CapabilityEntry(
          label: _formatFeatureLabel(mox.messageReactionsXmlns),
          detail: l10n.chatReactionsPrompt,
        ),
      if (supportsMam)
        _CapabilityEntry(label: _formatFeatureLabel(mox.mamXmlns)),
      if (supportsMuc)
        _CapabilityEntry(label: _formatFeatureLabel(mox.mucXmlns)),
      if (supportsMuc) _CapabilityEntry(label: l10n.mucSectionModerators),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.chatSettingsCapabilitiesTitle),
        SizedBox(height: spacing.xs),
        Text(subtitle, style: context.textTheme.muted),
        SizedBox(height: spacing.s),
        if (entries.isEmpty)
          Text(
            l10n.chatSettingsCapabilitiesEmpty,
            style: context.textTheme.muted,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final minTileWidth = math.max(
                sizing.menuMinWidth,
                sizing.menuItemHeight * 6,
              );
              final double spacingWidth = spacing.s;
              final int columns = math.max(
                1,
                (availableWidth / (minTileWidth + spacingWidth)).floor(),
              );
              final double totalSpacing = spacingWidth * (columns - 1);
              final double tileWidth =
                  (availableWidth - totalSpacing) / columns;
              return Wrap(
                spacing: spacingWidth,
                runSpacing: spacingWidth,
                children: entries
                    .map(
                      (entry) => SizedBox(
                        width: tileWidth,
                        child: _CapabilityTile(
                          label: entry.label,
                          detail: entry.detail,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }
}

class _CapabilityEntry {
  const _CapabilityEntry({required this.label, this.detail});

  final String label;
  final String? detail;
}

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({required this.label, required this.detail});

  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final textTheme = context.textTheme;
    return AxiModalSurface(
      padding: EdgeInsets.all(spacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          if (detail != null) ...[
            SizedBox(height: spacing.xs),
            Text(detail!, style: textTheme.muted),
          ],
        ],
      ),
    );
  }
}

class _ChatSettingsRow extends StatelessWidget {
  const _ChatSettingsRow({
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.trailing,
    this.statusKind,
    this.retrySettingId,
    this.loading = false,
  });

  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget trailing;
  final _ChatSettingStatusKind? statusKind;
  final ChatSettingId? retrySettingId;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final String? resolvedSubtitle = subtitle;
    final Color? resolvedTitleColor = titleColor;
    final TextStyle mutedStyle = context.textTheme.muted;
    final TextStyle subtitleStyle = mutedStyle;
    final List<Widget> textChildren = [
      Text(
        title,
        style: context.textTheme.small.strong.copyWith(
          color: resolvedTitleColor ?? context.colorScheme.foreground,
        ),
      ),
      if (resolvedSubtitle != null)
        Padding(
          padding: EdgeInsets.only(top: spacing.xs),
          child: Text(resolvedSubtitle, style: subtitleStyle),
        ),
      if (statusKind != null)
        Padding(
          padding: EdgeInsets.only(top: spacing.s),
          child: _ChatSettingStatusControl(
            kind: statusKind!,
            retrySettingId: retrySettingId,
          ),
        ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: textChildren,
          ),
        ),
        SizedBox(width: spacing.s),
        _ChatSettingTrailingControl(loading: loading, child: trailing),
      ],
    );
  }
}

enum _ChatSettingStatusKind { notSynced }

class _ChatSettingStatusChip extends StatelessWidget {
  const _ChatSettingStatusChip({required this.kind});

  final _ChatSettingStatusKind kind;

  @override
  Widget build(BuildContext context) {
    return AxiStatusChip(
      label: switch (kind) {
        _ChatSettingStatusKind.notSynced =>
          context.l10n.settingsSyncStatusNotSynced,
      },
      tone: switch (kind) {
        _ChatSettingStatusKind.notSynced => AxiStatusChipTone.warning,
      },
    );
  }
}

class _ChatSettingStatusControl extends StatelessWidget {
  const _ChatSettingStatusControl({
    required this.kind,
    required this.retrySettingId,
  });

  final _ChatSettingStatusKind kind;
  final ChatSettingId? retrySettingId;

  @override
  Widget build(BuildContext context) {
    final settingId = retrySettingId;
    return Wrap(
      spacing: context.spacing.s,
      runSpacing: context.spacing.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ChatSettingStatusChip(kind: kind),
        if (settingId != null)
          AxiButton.outline(
            size: AxiButtonSize.sm,
            onPressed: () =>
                context.read<ChatBloc>().add(ChatSettingSyncRetried(settingId)),
            child: Text(context.l10n.commonRetry),
          ),
      ],
    );
  }
}

class _ChatSettingTrailingControl extends StatelessWidget {
  const _ChatSettingTrailingControl({
    required this.loading,
    required this.child,
  });

  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!loading) return child;
    return SizedBox.square(
      dimension: context.sizing.iconButtonSize,
      child: Center(
        child: AxiProgressIndicator(
          semanticsLabel: context.l10n.settingsSyncStatusSyncing,
        ),
      ),
    );
  }
}

class _ChatSettingsSwitchRow extends StatelessWidget {
  const _ChatSettingsSwitchRow({
    required this.title,
    this.subtitle,
    this.titleColor,
    this.checkedTrackColor,
    required this.value,
    required this.onChanged,
    this.loading = false,
  });

  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? checkedTrackColor;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return _ChatSettingsRow(
      title: title,
      subtitle: subtitle,
      titleColor: titleColor,
      loading: loading,
      trailing: ShadSwitch(
        value: value,
        onChanged: onChanged,
        checkedTrackColor: checkedTrackColor,
      ),
    );
  }
}

class _ChatViewFilterControl extends StatelessWidget {
  const _ChatViewFilterControl({required this.filter, required this.onChanged});

  final MessageTimelineFilter filter;
  final ValueChanged<MessageTimelineFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final sizing = context.sizing;
    final messageFilterOptions = _messageFilterOptions(l10n);
    return _ChatSettingsRow(
      title: l10n.chatFilterTitle,
      subtitle: filter.statusLabel(l10n),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: sizing.menuMaxWidth),
        child: AxiSelect<MessageTimelineFilter>(
          maxWidth: sizing.menuMaxWidth,
          initialValue: filter,
          onChanged: (value) {
            if (value == null) return;
            onChanged(value);
          },
          options: messageFilterOptions
              .map(
                (option) => ShadOption<MessageTimelineFilter>(
                  value: option.filter,
                  child: Text(
                    option.filter.menuLabel(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          selectedOptionBuilder: (_, value) => Text(
            value.menuLabel(l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _ChatNotificationPreviewControl extends StatelessWidget {
  const _ChatNotificationPreviewControl({
    required this.state,
    required this.setting,
    required this.inheritedPreviewsEnabled,
    required this.onChanged,
  });

  final ChatState state;
  final NotificationPreviewSetting? setting;
  final bool inheritedPreviewsEnabled;
  final ValueChanged<NotificationPreviewSetting?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final sizing = context.sizing;
    final settingId = ChatSettingId.notificationPreview;
    return _ChatSettingsRow(
      title: l10n.settingsNotificationPreviews,
      subtitle: l10n.settingsNotificationPreviewsDescription,
      statusKind: _chatSettingStatusKind(state, settingId),
      retrySettingId: settingId,
      loading: state.isChatSettingLoading(settingId),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: sizing.menuMaxWidth),
        child: AxiSelect<NotificationPreviewSetting?>(
          maxWidth: sizing.menuMaxWidth,
          initialValue: setting,
          enabled: !state.isChatSettingLoading(settingId),
          onChanged: (value) {
            onChanged(value);
          },
          options:
              <NotificationPreviewSetting?>[
                    null,
                    ...NotificationPreviewSetting.values,
                  ]
                  .map(
                    (option) => ShadOption<NotificationPreviewSetting?>(
                      value: option,
                      child: Text(
                        option == null
                            ? _inheritedPreviewLabel(l10n)
                            : option.label(
                                showLabel:
                                    l10n.chatNotificationPreviewOptionShow,
                                hideLabel:
                                    l10n.chatNotificationPreviewOptionHide,
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          selectedOptionBuilder: (_, value) => Text(
            value == null
                ? _inheritedPreviewLabel(l10n)
                : value.label(
                    showLabel: l10n.chatNotificationPreviewOptionShow,
                    hideLabel: l10n.chatNotificationPreviewOptionHide,
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  String _inheritedPreviewLabel(AppLocalizations l10n) {
    return l10n.chatSettingInheritOption(
      inheritedPreviewsEnabled
          ? l10n.chatSettingStateOn
          : l10n.chatSettingStateOff,
    );
  }
}

class _ChatInheritedBoolControl extends StatelessWidget {
  const _ChatInheritedBoolControl({
    required this.state,
    required this.settingId,
    required this.title,
    required this.subtitle,
    required this.inheritedValue,
    required this.value,
    required this.onChanged,
  });

  final ChatState state;
  final ChatSettingId settingId;
  final String title;
  final String subtitle;
  final bool inheritedValue;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sizing = context.sizing;
    return _ChatSettingsRow(
      title: title,
      subtitle: subtitle,
      statusKind: _chatSettingStatusKind(state, settingId),
      retrySettingId: settingId,
      loading: state.isChatSettingLoading(settingId),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: sizing.menuMaxWidth),
        child: AxiSelect<bool?>(
          maxWidth: sizing.menuMaxWidth,
          initialValue: value,
          enabled: !state.isChatSettingLoading(settingId),
          onChanged: onChanged,
          options: <bool?>[null, true, false]
              .map(
                (option) => ShadOption<bool?>(
                  value: option,
                  child: Text(
                    _boolOptionLabel(l10n, option),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          selectedOptionBuilder: (_, option) => Text(
            _boolOptionLabel(l10n, option),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  String _boolOptionLabel(AppLocalizations l10n, bool? option) {
    return switch (option) {
      null => l10n.chatSettingInheritOption(
        inheritedValue ? l10n.chatSettingStateOn : l10n.chatSettingStateOff,
      ),
      true => l10n.chatSettingStateOn,
      false => l10n.chatSettingStateOff,
    };
  }
}

class _ChatNotificationBehaviorControl extends StatelessWidget {
  const _ChatNotificationBehaviorControl({
    required this.state,
    required this.behavior,
    required this.inheritedMuted,
    required this.onChanged,
  });

  final ChatState state;
  final ChatNotificationBehavior? behavior;
  final bool inheritedMuted;
  final ValueChanged<ChatNotificationBehavior?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sizing = context.sizing;
    const settingId = ChatSettingId.notificationBehavior;
    return _ChatSettingsRow(
      title: l10n.chatMuteNotifications,
      subtitle: l10n.settingsMuteNotificationsDescription,
      statusKind: _chatSettingStatusKind(state, settingId),
      retrySettingId: settingId,
      loading: state.isChatSettingLoading(settingId),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: sizing.menuMaxWidth),
        child: AxiSelect<ChatNotificationBehavior?>(
          maxWidth: sizing.menuMaxWidth,
          initialValue: behavior,
          enabled: !state.isChatSettingLoading(settingId),
          onChanged: onChanged,
          options:
              <ChatNotificationBehavior?>[
                    null,
                    ChatNotificationBehavior.muted,
                    ChatNotificationBehavior.alwaysNotify,
                  ]
                  .map(
                    (option) => ShadOption<ChatNotificationBehavior?>(
                      value: option,
                      child: Text(
                        _notificationBehaviorLabel(l10n, option),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          selectedOptionBuilder: (_, option) => Text(
            _notificationBehaviorLabel(l10n, option),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  String _notificationBehaviorLabel(
    AppLocalizations l10n,
    ChatNotificationBehavior? option,
  ) {
    return switch (option) {
      null => l10n.chatSettingInheritOption(
        inheritedMuted ? l10n.chatSettingStateOn : l10n.chatSettingStateOff,
      ),
      ChatNotificationBehavior.muted => l10n.chatNotificationBehaviorOptionMute,
      ChatNotificationBehavior.alwaysNotify =>
        l10n.chatNotificationBehaviorOptionAlwaysNotify,
    };
  }
}

class _ChatAttachmentTrustToggle extends StatelessWidget {
  const _ChatAttachmentTrustToggle({required this.state, required this.chat});

  final ChatState state;
  final chat_models.Chat chat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = context.watch<SettingsCubit>().state;
    final effectiveEnabled = switch (chat.attachmentAutoDownload) {
      AttachmentAutoDownload.allowed => true,
      AttachmentAutoDownload.blocked => false,
      null => settings.anyAttachmentAutoDownloadEnabled,
    };
    final hint = effectiveEnabled
        ? l10n.chatAttachmentAutoDownloadHintOn
        : l10n.chatAttachmentAutoDownloadHintOff;
    return _ChatInheritedAttachmentAutoDownloadControl(
      state: state,
      title: l10n.chatAttachmentAutoDownloadLabel,
      subtitle: hint,
      inheritedEnabled: settings.anyAttachmentAutoDownloadEnabled,
      value: chat.attachmentAutoDownload,
      onChanged: (value) => context.read<ChatBloc>().add(
        ChatAttachmentAutoDownloadToggled(chat: chat, value: value),
      ),
    );
  }
}

class _ChatInheritedAttachmentAutoDownloadControl extends StatelessWidget {
  const _ChatInheritedAttachmentAutoDownloadControl({
    required this.state,
    required this.title,
    required this.subtitle,
    required this.inheritedEnabled,
    required this.value,
    required this.onChanged,
  });

  final ChatState state;
  final String title;
  final String subtitle;
  final bool inheritedEnabled;
  final AttachmentAutoDownload? value;
  final ValueChanged<AttachmentAutoDownload?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sizing = context.sizing;
    const settingId = ChatSettingId.attachmentAutoDownload;
    return _ChatSettingsRow(
      title: title,
      subtitle: subtitle,
      statusKind: _chatSettingStatusKind(state, settingId),
      retrySettingId: settingId,
      loading: state.isChatSettingLoading(settingId),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: sizing.menuMaxWidth),
        child: AxiSelect<AttachmentAutoDownload?>(
          maxWidth: sizing.menuMaxWidth,
          initialValue: value,
          enabled: !state.isChatSettingLoading(settingId),
          onChanged: onChanged,
          options:
              <AttachmentAutoDownload?>[
                    null,
                    AttachmentAutoDownload.allowed,
                    AttachmentAutoDownload.blocked,
                  ]
                  .map(
                    (option) => ShadOption<AttachmentAutoDownload?>(
                      value: option,
                      child: Text(
                        _attachmentAutoDownloadOptionLabel(l10n, option),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          selectedOptionBuilder: (_, option) => Text(
            _attachmentAutoDownloadOptionLabel(l10n, option),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  String _attachmentAutoDownloadOptionLabel(
    AppLocalizations l10n,
    AttachmentAutoDownload? option,
  ) {
    return switch (option) {
      null => l10n.chatSettingInheritOption(
        inheritedEnabled ? l10n.chatSettingStateOn : l10n.chatSettingStateOff,
      ),
      AttachmentAutoDownload.allowed => l10n.settingsAutoDownloadScopeAlways,
      AttachmentAutoDownload.blocked => l10n.sessionCapabilityStatusOff,
    };
  }
}

_ChatSettingStatusKind? _chatSettingStatusKind(
  ChatState state,
  ChatSettingId settingId,
) {
  if (state.isChatSettingLoading(settingId)) {
    return null;
  }
  if (state.chat?.isChatSettingNotSynced(settingId) ?? false) {
    return _ChatSettingStatusKind.notSynced;
  }
  return null;
}
