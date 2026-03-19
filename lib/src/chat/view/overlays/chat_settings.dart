part of '../chat.dart';

class _ChatSettingsButtons extends StatelessWidget {
  const _ChatSettingsButtons({
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
    final chat = state.chat;
    if (chat == null) {
      return const SizedBox.expand();
    }
    final AppLocalizations l10n = context.l10n;
    final colors = context.colorScheme;
    final destructiveColor = colors.destructive;
    final BlocklistState blocklistState = context.watch<BlocklistCubit>().state;
    final bool globalSignatureEnabled = context
        .watch<SettingsCubit>()
        .state
        .shareTokenSignatureEnabled;
    final bool chatSignatureEnabled =
        chat.shareSignatureEnabled ?? globalSignatureEnabled;
    final bool signatureActive = globalSignatureEnabled && chatSignatureEnabled;
    final String signatureHint = globalSignatureEnabled
        ? l10n.chatSignatureHintEnabled
        : l10n.chatSignatureHintDisabled;
    final String signatureWarning = l10n.chatSignatureHintWarning;
    final bool showAttachmentToggle = chat.type != ChatType.note;
    final bool canRenameContact =
        chat.type == ChatType.chat && !chat.isAxichatWelcomeThread;
    final bool notificationsMuted = chat.muted;
    final bool isSpamChat = chat.spam;
    final String spamLabel = l10n.chatReportSpam;
    final String? resolvedBlockAddress = blockAddress?.trim();
    final String? resolvedBlockEntryAddress = blocklistEntry?.address.trim();
    final bool hasBlockAddress =
        resolvedBlockAddress != null && resolvedBlockAddress.isNotEmpty;
    final bool hasBlockEntry = blocklistEntry != null;
    final bool showXmppCapabilities =
        chat.defaultTransport.isXmpp && !chat.isAxichatWelcomeThread;
    final blockTransport = chat.isEmailBacked
        ? MessageTransport.email
        : chat.defaultTransport;
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
      if (showAttachmentToggle)
        Padding(
          padding: itemPadding,
          child: _ChatAttachmentTrustToggle(chat: chat),
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
        child: _ChatSettingsSwitchRow(
          title: l10n.chatMuteNotifications,
          value: notificationsMuted,
          onChanged: (muted) => onToggleNotifications(!muted),
        ),
      ),
      Padding(
        padding: itemPadding,
        child: _ChatNotificationPreviewControl(
          setting: chat.notificationPreviewSetting,
          onChanged: (setting) => context.read<ChatBloc>().add(
            ChatNotificationPreviewSettingChanged(chat: chat, setting: setting),
          ),
        ),
      ),
      if (chat.supportsEmail)
        Padding(
          padding: itemPadding,
          child: _ChatSettingsSwitchRow(
            title: l10n.chatSignatureToggleLabel,
            subtitle: '$signatureHint $signatureWarning',
            value: signatureActive,
            onChanged: globalSignatureEnabled
                ? (enabled) => context.read<ChatBloc>().add(
                    ChatShareSignatureToggled(chat: chat, enabled: enabled),
                  )
                : null,
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
  });

  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget trailing;

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
        style: resolvedTitleColor == null
            ? null
            : TextStyle(color: resolvedTitleColor),
      ),
      if (resolvedSubtitle != null)
        Padding(
          padding: EdgeInsets.only(top: spacing.xs),
          child: Text(resolvedSubtitle, style: subtitleStyle),
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
        trailing,
      ],
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
  });

  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? checkedTrackColor;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _ChatSettingsRow(
      title: title,
      subtitle: subtitle,
      titleColor: titleColor,
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
      title: filter.statusLabel(l10n),
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
    required this.setting,
    required this.onChanged,
  });

  final NotificationPreviewSetting? setting;
  final ValueChanged<NotificationPreviewSetting?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final sizing = context.sizing;
    return _ChatSettingsRow(
      title: l10n.settingsNotificationPreviews,
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: sizing.menuMaxWidth),
        child: AxiSelect<NotificationPreviewSetting?>(
          maxWidth: sizing.menuMaxWidth,
          initialValue: setting,
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
                            ? l10n.chatNotificationPreviewOptionInherit
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
                ? l10n.chatNotificationPreviewOptionInherit
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
}

class _ChatAttachmentTrustToggle extends StatelessWidget {
  const _ChatAttachmentTrustToggle({required this.chat});

  final chat_models.Chat chat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled =
        (chat.attachmentAutoDownload ??
                context
                    .watch<SettingsCubit>()
                    .state
                    .defaultChatAttachmentAutoDownload)
            .isAllowed;
    final hint = enabled
        ? l10n.chatAttachmentAutoDownloadHintOn
        : l10n.chatAttachmentAutoDownloadHintOff;
    return _ChatSettingsSwitchRow(
      title: l10n.chatAttachmentAutoDownloadLabel,
      subtitle: hint,
      value: enabled,
      onChanged: (value) => context.read<ChatBloc>().add(
        ChatAttachmentAutoDownloadToggled(chat: chat, enabled: value),
      ),
    );
  }
}
