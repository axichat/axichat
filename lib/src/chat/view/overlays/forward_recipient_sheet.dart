part of '../chat.dart';

class _ForwardRecipientSheet extends StatefulWidget {
  const _ForwardRecipientSheet({required this.availableChats});

  final List<chat_models.Chat> availableChats;

  @override
  State<_ForwardRecipientSheet> createState() => _ForwardRecipientSheetState();
}

class _ForwardRecipientSheetState extends State<_ForwardRecipientSheet> {
  List<ComposerRecipient> _recipients = const [];

  Contact? get _selectedTarget {
    for (final recipient in _recipients) {
      final target = recipient.target;
      if (recipient.included) {
        return target;
      }
    }
    return null;
  }

  bool get _canSend => _selectedTarget != null;

  Future<bool> _handleRecipientAdded(Contact target) async {
    final address = target.resolvedAddress;
    if (target.needsTransportSelection &&
        address != null &&
        address.isNotEmpty) {
      final transport = await _resolveAddressTransport(address);
      if (!mounted || transport == null) {
        return false;
      }
      _applyRecipient(target.withTransport(transport));
      return true;
    }
    _applyRecipient(target);
    return true;
  }

  void _applyRecipient(Contact target) {
    setState(() {
      _recipients = <ComposerRecipient>[ComposerRecipient(target: target)];
    });
  }

  void _handleRecipientRemoved(String key) {
    if (!mounted) return;
    setState(() {
      _recipients = _recipients
          .where((recipient) => recipient.key != key)
          .toList(growable: false);
    });
  }

  void _handleSend() {
    final Contact? selected = _selectedTarget;
    if (selected == null) return;
    Navigator.of(context).pop(selected);
  }

  Future<MessageTransport?> _resolveAddressTransport(String address) async {
    final endpointConfig = context.read<SettingsCubit>().state.endpointConfig;
    final supportsEmail = endpointConfig.smtpEnabled;
    final supportsXmpp = endpointConfig.xmppEnabled;
    if (supportsEmail && !supportsXmpp) {
      return MessageTransport.email;
    }
    if (!supportsEmail && supportsXmpp) {
      return MessageTransport.xmpp;
    }
    if (!supportsEmail && !supportsXmpp) {
      return null;
    }
    final hinted = hintTransportForAddress(address);
    if (hinted != null) {
      return hinted;
    }
    return showTransportChoiceDialog(
      context,
      address: address,
      defaultTransport: hinted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final locate = context.read;
    final iconSize = context.sizing.iconButtonIconSize;
    final sectionSpacing = spacing.m;
    final contentPadding = EdgeInsets.symmetric(horizontal: spacing.m);
    final profileJid = context.watch<ProfileCubit>().state.jid;
    final trimmedProfileJid = profileJid.trim();
    final String? selfJid = trimmedProfileJid.isNotEmpty
        ? trimmedProfileJid
        : null;
    final selfIdentity = SelfAvatar(
      jid: selfJid,
      avatar: Avatar.tryParseOrNull(
        path: context.watch<ProfileCubit>().state.avatarPath,
        hash: null,
      ),
      hydrating: context.watch<ProfileCubit>().state.avatarHydrating,
    );
    final header = AxiSheetHeader(
      title: Text(l10n.chatForwardDialogTitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    return AxiSheetScaffold.scroll(
      header: header,
      bodyPadding: EdgeInsets.zero,
      children: [
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
              recipients: _recipients,
              availableChats: widget.availableChats,
              rosterItems: rosterItems,
              databaseSuggestionAddresses: recipientAddressSuggestions,
              selfJid: locate<ChatsCubit>().selfJid,
              selfIdentity: selfIdentity,
              latestStatuses: const {},
              collapsedByDefault: false,
              allowAddressTargets: true,
              showSuggestionsWhenEmpty: true,
              horizontalPadding: 0,
              onRecipientAdded: _handleRecipientAdded,
              onRecipientRemoved: _handleRecipientRemoved,
            );
          },
        ),
        SizedBox(height: sectionSpacing),
        Padding(
          padding: contentPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AxiButton.outline(
                onPressed: () => closeSheetWithKeyboardDismiss(
                  context,
                  () => Navigator.of(context).maybePop(),
                ),
                child: Text(l10n.commonCancel),
              ),
              SizedBox(width: spacing.s),
              AxiButton.primary(
                onPressed: _canSend ? _handleSend : null,
                leading: Icon(LucideIcons.send, size: iconSize),
                child: Text(l10n.commonSend),
              ),
            ],
          ),
        ),
        SizedBox(height: sectionSpacing),
      ],
    );
  }
}
