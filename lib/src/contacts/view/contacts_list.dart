// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/contact_rename_dialog.dart';
import 'package:axichat/src/common/email_validation.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/contacts/bloc/contacts_cubit.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
import 'package:axichat/src/email/bloc/email_contact_key_cubit.dart';
import 'package:axichat/src/email/bloc/email_contact_import_cubit.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/view/email_contact_import_tile.dart';
import 'package:axichat/src/folders/bloc/folders_cubit.dart';
import 'package:axichat/src/folders/view/folder_picker_sheet.dart';
import 'package:axichat/src/home/bloc/home_bloc.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ContactsList extends StatefulWidget {
  const ContactsList({super.key});

  @override
  State<ContactsList> createState() => _ContactsListState();
}

Future<void> showContactDetailsSheet({
  required BuildContext context,
  required ContactDirectoryEntry contact,
}) async {
  final locate = context.read;
  final emailService = locate<SettingsCubit>().state.endpointConfig.smtpEnabled
      ? _maybeLocateEmailService(locate)
      : null;
  final action = await showAdaptiveBottomSheet<_ContactDetailsSheetAction>(
    context: context,
    isScrollControlled: true,
    surfacePadding: EdgeInsets.zero,
    showDragHandle: true,
    builder: (_) {
      return MultiBlocProvider(
        providers: [
          BlocProvider.value(value: locate<ContactsCubit>()),
          BlocProvider.value(value: locate<BlocklistCubit>()),
          BlocProvider.value(value: locate<FoldersCubit>()),
          if (emailService != null)
            BlocProvider(
              create: (_) => EmailContactKeyCubit(emailService: emailService)
                ..load(
                  address: contact.address,
                  displayName: contact.displayName,
                ),
            ),
        ],
        child: _ContactDetailsSheet(
          contact: contact,
          emailContactKeysAvailable: emailService != null,
        ),
      );
    },
  );
  if (!context.mounted) {
    return;
  }
  switch (action) {
    case _ContactDetailsSheetAction.openChat:
      await context.read<ChatsCubit>().openChat(jid: contact.address);
    case _ContactDetailsSheetAction.composeEmail:
      openComposeDraft(
        context,
        jids: [contact.address],
        recipientTransportOverrides: {
          contactDirectoryAddressKey(contact.address): MessageTransport.email,
        },
        attachmentMetadataIds: const <String>[],
      );
    case null:
      return;
  }
}

enum _ContactDetailsSheetAction { openChat, composeEmail }

EmailService? _maybeLocateEmailService(T Function<T>() locate) {
  try {
    return locate<EmailService>();
  } on ProviderNotFoundException {
    return null;
  }
}

class _ContactsListState extends State<ContactsList> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCriteria(context.read<HomeBloc>().state);
  }

  void _syncCriteria(HomeState searchState) {
    final tabState = searchState.stateFor(HomeTab.contacts);
    final query = searchState.active ? tabState.query : '';
    context.read<ContactsCubit>().updateCriteria(
      query: query,
      sort: tabState.sort,
      filterId: tabState.filterId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<HomeBloc, HomeState>(
          listener: (context, searchState) => _syncCriteria(searchState),
        ),
        BlocListener<ContactsCubit, ContactsState>(
          listenWhen: (previous, current) =>
              previous.actionState != current.actionState,
          listener: (context, state) {
            final actionState = state.actionState;
            if (actionState is! ContactActionFailure ||
                actionState.action != ContactActionType.removeContact) {
              return;
            }
            ShadToaster.maybeOf(context)?.show(
              FeedbackToast.error(
                message: _contactFailureMessage(context, actionState.reason),
              ),
            );
          },
        ),
      ],
      child: BlocBuilder<ContactsCubit, ContactsState>(
        buildWhen: (previous, current) =>
            previous.visibleItems != current.visibleItems,
        builder: (context, state) {
          final items = state.visibleItems ?? state.items;
          if (items == null) {
            return Center(
              child: AxiProgressIndicator(
                color: context.colorScheme.foreground,
              ),
            );
          }
          if (items.isEmpty) {
            return Center(
              child: Text(
                context.l10n.rosterEmpty,
                style: context.textTheme.muted,
              ),
            );
          }
          return _ContactsListBody(items: items);
        },
      ),
    );
  }
}

class ContactsActionGroup extends StatelessWidget {
  const ContactsActionGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final locate = context.read;
    return Wrap(
      spacing: spacing.s,
      runSpacing: spacing.s,
      children: [
        ContactsFilterButton(locate: locate),
        const ContactsImportButton(),
        const ContactsAddButton(),
      ],
    );
  }
}

class ContactsFilterButton extends StatefulWidget {
  const ContactsFilterButton({
    super.key,
    required this.locate,
    this.compact = false,
  });

  final T Function<T>() locate;
  final bool compact;

  @override
  State<ContactsFilterButton> createState() => _ContactsFilterButtonState();
}

class _ContactsFilterButtonState extends State<ContactsFilterButton> {
  late final ShadPopoverController popoverController;

  @override
  void initState() {
    super.initState();
    popoverController = ShadPopoverController();
  }

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      bloc: widget.locate<HomeBloc>(),
      builder: (context, searchState) {
        final l10n = context.l10n;
        final sizing = context.sizing;
        final filters = contactsSearchFilters(l10n);
        final selectedFilterId =
            searchState.stateFor(HomeTab.contacts).filterId ?? filters.first.id;
        final selectedFilter = filters.firstWhere(
          (filter) => filter.id == selectedFilterId,
          orElse: () => filters.first,
        );
        final tooltip = l10n.filterTooltip(selectedFilter.label);
        final iconSize = sizing.menuItemIconSize;
        Widget trigger;
        if (widget.compact) {
          trigger = AxiIconButton.outline(
            iconData: LucideIcons.listFilter,
            iconSize: iconSize,
            tooltip: tooltip,
            onPressed: popoverController.toggle,
          );
        } else {
          trigger = AxiButton.secondary(
            onPressed: popoverController.toggle,
            tooltip: tooltip,
            leading: Icon(LucideIcons.listFilter, size: iconSize),
            child: Text(selectedFilter.label),
          );
        }
        return AxiPopover(
          controller: popoverController,
          closeOnTapOutside: true,
          padding: EdgeInsets.zero,
          decoration: ShadDecoration.none,
          shadows: const <BoxShadow>[],
          popover: (context) {
            return AxiMenu(
              actions: [
                for (final option in filters)
                  AxiMenuAction(
                    icon: option.id == selectedFilter.id
                        ? LucideIcons.check
                        : null,
                    label: option.label,
                    onPressed: () {
                      widget.locate<HomeBloc>().add(
                        HomeSearchFilterChanged(
                          option.id,
                          tab: HomeTab.contacts,
                        ),
                      );
                      popoverController.hide();
                    },
                  ),
              ],
            );
          },
          child: trigger,
        );
      },
    );
  }
}

class ContactsImportButton extends StatelessWidget {
  const ContactsImportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          EmailContactImportCubit(emailService: context.read<EmailService>()),
      child: const _ContactsImportButtonContent(),
    );
  }
}

class _ContactsImportButtonContent extends StatelessWidget {
  const _ContactsImportButtonContent();

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    final l10n = context.l10n;
    return BlocSelector<SettingsCubit, SettingsState, bool>(
      selector: (state) => state.endpointConfig.smtpEnabled,
      builder: (context, emailEnabled) {
        if (!emailEnabled) {
          return AxiFab(
            tooltip: l10n.emailContactsImportAccountRequired,
            iconData: LucideIcons.userRoundPlus,
            text: l10n.emailContactsImportAction,
          );
        }
        return BlocSelector<
          EmailContactImportCubit,
          EmailContactImportState,
          bool
        >(
          selector: (state) => state is EmailContactImportInProgress,
          builder: (context, loading) {
            return AxiFab(
              tooltip: l10n.emailContactsImportTitle,
              iconData: LucideIcons.userRoundPlus,
              text: l10n.emailContactsImportAction,
              onPressed: loading
                  ? null
                  : () {
                      locate<EmailContactImportCubit>().reset();
                      showFadeScaleDialog(
                        context: context,
                        builder: (dialogContext) => BlocProvider.value(
                          value: locate<EmailContactImportCubit>(),
                          child: const EmailContactImportDialog(),
                        ),
                      );
                    },
            );
          },
        );
      },
    );
  }
}

class ContactsAddButton extends StatelessWidget {
  const ContactsAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    final l10n = context.l10n;
    return AxiDialogFab(
      tooltip: l10n.rosterAddTooltip,
      iconData: LucideIcons.userPlus,
      label: l10n.contactsNewLabel,
      dialogBuilder: (dialogContext) {
        return BlocProvider.value(
          value: locate<ContactsCubit>(),
          child: const _ContactsAddDialog(),
        );
      },
    );
  }
}

class _ContactsListBody extends StatelessWidget {
  const _ContactsListBody({required this.items});

  final List<ContactDirectoryEntry> items;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return ColoredBox(
      color: context.colorScheme.background,
      child: ListView.builder(
        padding: EdgeInsets.only(top: spacing.m, bottom: spacing.m),
        itemCount: items.length,
        itemBuilder: (context, index) =>
            _ContactListTile(contact: items[index]),
      ),
    );
  }
}

class _ContactListTile extends StatelessWidget {
  const _ContactListTile({required this.contact});

  final ContactDirectoryEntry contact;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final emailEnabled = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.endpointConfig.smtpEnabled,
    );
    final address = contact.address;
    final addressKey = contactDirectoryAddressKey(address);
    final contactsState = context.watch<ContactsCubit>().state;
    final isRemoving = contactsState.isContactActionLoading(
      action: ContactActionType.removeContact,
      address: addressKey,
    );
    final cachedBlocklistItems = context
        .select<BlocklistCubit, List<BlocklistEntry>?>(
          (cubit) =>
              cubit[BlocklistCubit.blocklistItemsCacheKey]
                  as List<BlocklistEntry>?,
        );
    final blocklistState = context.watch<BlocklistCubit>().state;
    final blocklistItems =
        blocklistState.items ??
        cachedBlocklistItems ??
        const <BlocklistEntry>[];
    final contactBlocked = _contactBlockEntries(
      contact: contact,
      entries: blocklistItems,
    ).isNotEmpty;
    return ListItemPadding(
      padding: EdgeInsets.fromLTRB(
        spacing.m,
        spacing.xs,
        spacing.m,
        spacing.xs,
      ),
      child: AxiListTile(
        key: ValueKey(address),
        onTap: () =>
            showContactDetailsSheet(context: context, contact: contact),
        menuItems: [
          if (contact.hasXmppRoster)
            ShadContextMenuItem(
              leading: const Icon(LucideIcons.messagesSquare),
              child: Text(context.l10n.commonOpen),
              onPressed: () =>
                  context.read<ChatsCubit>().openChat(jid: address),
            ),
          if (_emailComposeEnabled(
            contact: contact,
            emailEnabled: emailEnabled,
          ))
            ShadContextMenuItem(
              leading: const Icon(LucideIcons.mail),
              child: Text(context.l10n.contactsComposeEmail),
              onPressed: () => openComposeDraft(
                context,
                jids: [address],
                recipientTransportOverrides: {
                  addressKey: MessageTransport.email,
                },
                attachmentMetadataIds: const <String>[],
              ),
            ),
          if (contact.hasPrivateContact ||
              contact.hasXmppRoster ||
              contact.hasEmailContact)
            AxiDeleteMenuItem(
              onPressed: isRemoving
                  ? null
                  : () async {
                      final confirmed = await confirm(
                        context,
                        text: context.l10n.contactsRemoveContactConfirm(
                          address,
                        ),
                      );
                      if (confirmed != true || !context.mounted) {
                        return;
                      }
                      await context.read<ContactsCubit>().removeContact(
                        contact,
                      );
                    },
            ),
        ],
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.s,
          vertical: spacing.xxs,
        ),
        minTileHeight: context.sizing.listButtonHeight + spacing.xs,
        horizontalTitleGap: spacing.s,
        leading: HydratedAxiAvatar(
          avatar: AvatarPresentation.avatar(
            label: address,
            colorSeed: address,
            avatar: Avatar.tryParseOrNull(path: contact.avatarPath, hash: null),
            loading: false,
          ),
          subscription: contact.subscription ?? Subscription.none,
          presence: null,
          status: null,
        ),
        titleWidget: _ContactListTileContent(contact: contact),
        actions: _contactTileIndicators(contact, blocked: contactBlocked),
      ),
    );
  }
}

class _ContactListTileContent extends StatelessWidget {
  const _ContactListTileContent({required this.contact});

  final ContactDirectoryEntry contact;

  @override
  Widget build(BuildContext context) {
    final secondaryValues = _contactSecondaryValues(contact, context.l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          contact.displayName,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.small.strong.copyWith(
            color: context.colorScheme.foreground,
          ),
        ),
        if (secondaryValues.isNotEmpty)
          Text(
            secondaryValues.join(context.l10n.commonListSeparator),
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.muted.copyWith(
              color: context.colorScheme.mutedForeground,
            ),
          ),
      ],
    );
  }
}

class _ContactsAddDialog extends StatefulWidget {
  const _ContactsAddDialog();

  @override
  State<_ContactsAddDialog> createState() => _ContactsAddDialogState();
}

class _ContactsAddDialogState extends State<_ContactsAddDialog> {
  late final TextEditingController _addressController = TextEditingController();
  late final FocusNode _addressFocusNode = FocusNode();
  late final FocusNode _displayNameFocusNode = FocusNode();
  String _displayName = '';
  String _submittedAddress = '';
  bool _showAddressValidationError = false;

  @override
  void dispose() {
    _addressController.dispose();
    _addressFocusNode.dispose();
    _displayNameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit({
    required bool supportsEmail,
    required bool supportsXmpp,
  }) async {
    final normalizedAddress = _normalizedContactAddress();
    if (normalizedAddress == null) {
      setState(() => _showAddressValidationError = true);
      _addressFocusNode.requestFocus();
      return;
    }
    final resolvedTransport = await _resolveTransport(
      address: normalizedAddress,
      supportsEmail: supportsEmail,
      supportsXmpp: supportsXmpp,
    );
    if (resolvedTransport == null || !mounted) {
      return;
    }
    final title = _displayName.trim().isEmpty ? null : _displayName.trim();
    setState(() => _submittedAddress = normalizedAddress);
    await context.read<ContactsCubit>().addContact(
      address: normalizedAddress,
      displayName: title,
      transport: resolvedTransport,
    );
  }

  Future<MessageTransport?> _resolveTransport({
    required String address,
    required bool supportsEmail,
    required bool supportsXmpp,
  }) async {
    if (supportsEmail && !supportsXmpp) {
      return MessageTransport.email;
    }
    if (supportsXmpp && !supportsEmail) {
      return MessageTransport.xmpp;
    }
    if (!supportsEmail && !supportsXmpp) {
      return null;
    }
    final endpointConfig = context.read<SettingsCubit>().state.endpointConfig;
    final hinted = hintTransportForAddress(
      address,
      xmppDomainHints: {endpointConfig.domain},
    );
    if (hinted != null) {
      return hinted;
    }
    return showTransportChoiceDialog(
      context,
      address: address,
      defaultTransport: hinted,
    );
  }

  String? _normalizedContactAddress() {
    final bare = bareAddressOrNull(_addressController.text);
    if (bare == null || bare.trim().isEmpty) {
      return null;
    }
    final local = addressLocalPart(bare);
    final domain = addressDomainPart(bare);
    if (local == null || local.isEmpty || domain == null || domain.isEmpty) {
      return null;
    }
    if (!bare.isValidEmailAddress) {
      return null;
    }
    return normalizedAddressValue(bare);
  }

  void _handleAddressSubmitted(String _) {
    if (_normalizedContactAddress() == null) {
      setState(() => _showAddressValidationError = true);
      _addressFocusNode.requestFocus();
      return;
    }
    setState(() => _showAddressValidationError = false);
    _displayNameFocusNode.requestFocus();
  }

  bool _matchesSubmittedAddress(String address) {
    final submittedKey = contactDirectoryAddressKey(_submittedAddress);
    return submittedKey.isNotEmpty &&
        contactDirectoryAddressKey(address) == submittedKey;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final supportsEmail = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.endpointConfig.smtpEnabled,
    );
    final supportsXmpp = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.endpointConfig.xmppEnabled,
    );
    final endpointDomain = context.select<SettingsCubit, String>(
      (cubit) => cubit.state.endpointConfig.domain,
    );
    return BlocListener<ContactsCubit, ContactsState>(
      listenWhen: (previous, current) =>
          previous.actionState != current.actionState,
      listener: (context, state) {
        final actionState = state.actionState;
        if (actionState is ContactActionSuccess &&
            actionState.action == ContactActionType.addContact &&
            _matchesSubmittedAddress(actionState.address) &&
            Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: BlocBuilder<ContactsCubit, ContactsState>(
        buildWhen: (previous, current) =>
            previous.items != current.items ||
            previous.actionState != current.actionState ||
            previous.loadingActions != current.loadingActions,
        builder: (context, contactsState) {
          final contactsActionState = contactsState.actionState;
          final loading = contactsState.loadingActions.any(
            (action) =>
                action.action == ContactActionType.addContact &&
                _matchesSubmittedAddress(action.address),
          );
          final errorMessage = switch (contactsActionState) {
            ContactActionFailure(:final reason, :final address)
                when contactsActionState.action ==
                        ContactActionType.addContact &&
                    _matchesSubmittedAddress(address) =>
              _contactFailureMessage(context, reason),
            _ => null,
          };
          final addressErrorMessage = _showAddressValidationError
              ? l10n.blocklistInvalidJid
              : errorMessage;
          final normalizedAddress = _normalizedContactAddress();
          return AxiInputDialog(
            title: Text(l10n.rosterAddTitle),
            loading: loading,
            callback:
                normalizedAddress == null ||
                    loading ||
                    (!supportsEmail && !supportsXmpp)
                ? null
                : () => _submit(
                    supportsEmail: supportsEmail,
                    supportsXmpp: supportsXmpp,
                  ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AddressAutocompleteField(
                  controller: _addressController,
                  focusNode: _addressFocusNode,
                  enabled: !loading,
                  error: addressErrorMessage,
                  placeholder: Text(l10n.accessibilityNewContactLabel),
                  textInputAction: TextInputAction.next,
                  onSubmitted: _handleAddressSubmitted,
                  knownAddresses:
                      (contactsState.items ?? const <ContactDirectoryEntry>[])
                          .map((item) => item.address)
                          .toList(growable: false),
                  primaryDomain: endpointDomain,
                  suggestionDomains: knownMessageTransportDomainHints(
                    xmppDomainHints: {endpointDomain},
                  ),
                  onChanged: (value) {
                    setState(() {
                      _submittedAddress = '';
                      _showAddressValidationError = false;
                    });
                  },
                ),
                SizedBox(height: spacing.s),
                AxiTextFormField(
                  focusNode: _displayNameFocusNode,
                  enabled: !loading,
                  placeholder: Text(l10n.contactsDisplayNameLabel),
                  textInputAction: TextInputAction.done,
                  onChanged: (value) => setState(() => _displayName = value),
                  onSubmitted: (_) => _submit(
                    supportsEmail: supportsEmail,
                    supportsXmpp: supportsXmpp,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ContactDetailsSheet extends StatelessWidget {
  const _ContactDetailsSheet({
    required this.contact,
    required this.emailContactKeysAvailable,
  });

  final ContactDirectoryEntry contact;
  final bool emailContactKeysAvailable;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ContactsCubit, ContactsState>(
      listenWhen: (previous, current) =>
          previous.actionState != current.actionState,
      listener: (context, state) {
        final actionState = state.actionState;
        if (actionState is ContactActionSuccess &&
            actionState.action == ContactActionType.removeContact &&
            contactDirectoryAddressKey(actionState.address) ==
                contactDirectoryAddressKey(contact.address) &&
            Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }
        final actionAddress = switch (actionState) {
          ContactActionSuccess(:final address) => address,
          ContactActionFailure(:final address) => address,
          _ => null,
        };
        if (contactDirectoryAddressKey(actionAddress) !=
            contactDirectoryAddressKey(contact.address)) {
          return;
        }
        if (actionState is ContactActionSuccess &&
            (actionState.action == ContactActionType.rename ||
                actionState.action == ContactActionType.resetRename)) {
          ShadToaster.maybeOf(context)?.show(
            FeedbackToast.success(
              message: context.l10n.chatContactRenameSuccess,
            ),
          );
          return;
        }
        if (actionState is ContactActionFailure &&
            (actionState.action == ContactActionType.rename ||
                actionState.action == ContactActionType.resetRename)) {
          ShadToaster.maybeOf(context)?.show(
            FeedbackToast.error(message: context.l10n.chatContactRenameFailure),
          );
        }
      },
      child: BlocBuilder<ContactsCubit, ContactsState>(
        buildWhen: (previous, current) =>
            previous.items != current.items ||
            previous.actionState != current.actionState ||
            previous.loadingActions != current.loadingActions,
        builder: (context, state) {
          final spacing = context.spacing;
          final currentContact = _currentContactForSheet(state.items, contact);
          final cachedBlocklistItems =
              context.watch<BlocklistCubit>()[BlocklistCubit
                      .blocklistItemsCacheKey]
                  as List<BlocklistEntry>?;
          final blocklistState = context.watch<BlocklistCubit>().state;
          final blocklistItems =
              blocklistState.items ??
              cachedBlocklistItems ??
              const <BlocklistEntry>[];
          final contactBlocked = _contactBlockEntries(
            contact: currentContact,
            entries: blocklistItems,
          ).isNotEmpty;
          final emailEnabled = context.select<SettingsCubit, bool>(
            (cubit) => cubit.state.endpointConfig.smtpEnabled,
          );
          final detailRows = _contactDetailRows(
            context.l10n,
            currentContact,
            emailEnabled: emailEnabled,
          );
          final emailContactKeyManagementEnabled =
              _emailContactKeyManagementEnabled(
                contact: currentContact,
                emailEnabled: emailEnabled,
                emailContactKeysAvailable: emailContactKeysAvailable,
              );
          final emailContactKeyState = emailContactKeyManagementEnabled
              ? context.watch<EmailContactKeyCubit>().state
              : null;
          return AxiSheetScaffold.sections(
            header: AxiSheetHeader(
              title: Text(context.l10n.contactsDetailsSectionTitle),
              onClose: () => Navigator.of(context).maybePop(),
            ),
            sections: [
              AxiSheetSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ContactSummaryCard(
                      contact: currentContact,
                      blocked: contactBlocked,
                    ),
                    if (detailRows.isNotEmpty) ...[
                      SizedBox(height: spacing.m),
                      _ContactDetailsInfoCard(
                        contact: currentContact,
                        rows: detailRows,
                        disabled: state.isContactAddressLoading(
                          contactDirectoryAddressKey(currentContact.address),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AxiSheetSection(
                child: _ContactDetailsActions(
                  contact: currentContact,
                  emailEnabled: emailEnabled,
                  group: _ContactDetailsActionGroup.primary,
                ),
              ),
              if (_contactDestructiveActionsEnabled(currentContact)) ...[
                AxiSheetSection(
                  child: _ContactDetailsActions(
                    contact: currentContact,
                    emailEnabled: emailEnabled,
                    group: _ContactDetailsActionGroup.destructive,
                  ),
                ),
              ],
              if (emailContactKeyState != null &&
                  (emailContactKeyState is! EmailContactKeyIdle ||
                      emailContactKeyState.account != null)) ...[
                AxiSheetSection(
                  child: _ContactEmailEncryptionSection(
                    contact: currentContact,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ContactSummaryCard extends StatelessWidget {
  const _ContactSummaryCard({required this.contact, required this.blocked});

  final ContactDirectoryEntry contact;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final address = contact.address;
    final l10n = context.l10n;
    final sourceItems = _contactSourceItems(l10n, contact);
    return AxiModalSurface(
      key: ValueKey('contact-summary-$address'),
      borderColor: context.borderSide.color,
      padding: EdgeInsets.all(spacing.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HydratedAxiAvatar(
            avatar: AvatarPresentation.avatar(
              label: address,
              colorSeed: address,
              avatar: Avatar.tryParseOrNull(
                path: contact.avatarPath,
                hash: null,
              ),
              loading: false,
            ),
            subscription: contact.subscription ?? Subscription.none,
            presence: null,
            status: null,
            size: context.sizing.attachmentPreviewExtent,
          ),
          SizedBox(width: spacing.m),
          Expanded(
            child: _ContactIdentityContent(
              contact: contact,
              sourceItems: sourceItems,
              blocked: blocked,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactIdentityContent extends StatelessWidget {
  const _ContactIdentityContent({
    required this.contact,
    required this.sourceItems,
    required this.blocked,
  });

  final ContactDirectoryEntry contact;
  final List<({IconData icon, String label})> sourceItems;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          contact.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.modalHeaderTextStyle,
        ),
        if (contact.displayName != contact.address) ...[
          SizedBox(height: spacing.xs),
          Text(
            contact.address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.muted,
          ),
        ],
        if (blocked || contact.favorited || sourceItems.isNotEmpty) ...[
          SizedBox(height: spacing.m),
          if (blocked) ...[
            _ContactStatusRow(
              icon: LucideIcons.userX,
              label: l10n.blocklistBlockedStatus,
              destructive: true,
            ),
            if (contact.favorited || sourceItems.isNotEmpty)
              SizedBox(height: spacing.s),
          ],
          if (contact.favorited) ...[
            _ContactStatusRow(
              icon: LucideIcons.star,
              label: l10n.commonFavorite,
            ),
            if (sourceItems.isNotEmpty) SizedBox(height: spacing.s),
          ],
          for (var index = 0; index < sourceItems.length; index += 1) ...[
            if (index > 0) SizedBox(height: spacing.s),
            _ContactStatusRow(
              icon: sourceItems[index].icon,
              label: sourceItems[index].label,
            ),
          ],
        ],
      ],
    );
  }
}

class _ContactDetailsInfoCard extends StatelessWidget {
  const _ContactDetailsInfoCard({
    required this.contact,
    required this.rows,
    required this.disabled,
  });

  final ContactDirectoryEntry contact;
  final bool disabled;
  final List<
    ({
      IconData icon,
      String label,
      String value,
      ContactDetailFieldKind? kind,
      ContactDetailFieldEntry? field,
    })
  >
  rows;

  @override
  Widget build(BuildContext context) {
    return AxiModalSurface(
      key: ValueKey('contact-details-${contact.address}'),
      borderColor: context.borderSide.color,
      padding: EdgeInsets.all(context.spacing.m),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index += 1) ...[
            if (index > 0) SizedBox(height: context.spacing.m),
            _ContactDetailRow(
              contact: contact,
              icon: rows[index].icon,
              label: rows[index].label,
              value: rows[index].value,
              kind: rows[index].kind,
              field: rows[index].field,
              disabled: disabled,
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactEmailEncryptionSection extends StatelessWidget {
  const _ContactEmailEncryptionSection({required this.contact});

  final ContactDirectoryEntry contact;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EmailContactKeyCubit, EmailContactKeyState>(
      listener: _handleState,
      builder: (context, state) {
        return AxiModalSurface(
          key: ValueKey('contact-email-encryption-${contact.address}'),
          borderColor: context.borderSide.color,
          padding: EdgeInsets.all(context.spacing.m),
          child: _ContactEmailEncryptionContent(contact: contact, state: state),
        );
      },
    );
  }

  Future<void> _handleState(
    BuildContext context,
    EmailContactKeyState state,
  ) async {
    switch (state) {
      case EmailContactKeyConfirmationRequired():
        await _confirmKeyIdentity(context, state);
      case EmailContactKeySuccess(:final kind):
        ShadToaster.maybeOf(context)?.show(
          FeedbackToast.success(
            message: switch (kind) {
              EmailContactKeySuccessKind.imported =>
                context.l10n.contactEmailEncryptionImportSuccess,
              EmailContactKeySuccessKind.removed =>
                context.l10n.contactEmailEncryptionRemoveSuccess,
            },
          ),
        );
      case EmailContactKeyFailure(:final reason):
        ShadToaster.maybeOf(
          context,
        )?.show(FeedbackToast.error(message: _failureMessage(context, reason)));
      default:
        return;
    }
  }

  Future<void> _confirmKeyIdentity(
    BuildContext context,
    EmailContactKeyConfirmationRequired state,
  ) async {
    final identities = state.metadata.userIds.isEmpty
        ? context.l10n.emailEncryptionKeyIdentityNoIdentities
        : state.metadata.userIds.join(', ');
    final confirmed = await confirm(
      context,
      title: context.l10n.contactEmailEncryptionIdentityWarningTitle,
      message: context.l10n.contactEmailEncryptionIdentityWarningBody(
        contact.address,
        state.metadata.fingerprint,
        identities,
      ),
      confirmLabel: context.l10n.commonContinue,
      cancelLabel: context.l10n.commonCancel,
      destructiveConfirm: false,
    );
    if (!context.mounted) {
      return;
    }
    if (confirmed == true) {
      await context.read<EmailContactKeyCubit>().confirmImport();
      return;
    }
    await context.read<EmailContactKeyCubit>().cancelImport();
  }

  String _failureMessage(
    BuildContext context,
    EmailContactKeyFailureReason reason,
  ) => switch (reason) {
    EmailContactKeyFailureReason.noActiveAccount =>
      context.l10n.contactEmailEncryptionNoActiveAccount,
    EmailContactKeyFailureReason.unsupportedFormat =>
      context.l10n.contactEmailEncryptionUnsupportedFormat,
    EmailContactKeyFailureReason.importFailed =>
      context.l10n.contactEmailEncryptionImportFailed,
    EmailContactKeyFailureReason.removeFailed =>
      context.l10n.contactEmailEncryptionRemoveFailed,
  };
}

class _ContactEmailEncryptionContent extends StatelessWidget {
  const _ContactEmailEncryptionContent({
    required this.contact,
    required this.state,
  });

  final ContactDirectoryEntry contact;
  final EmailContactKeyState state;

  Future<void> _pickPublicKey(BuildContext context) async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: const ['asc', 'pgp', 'gpg'],
      );
    } on PlatformException {
      if (!context.mounted) {
        return;
      }
      ShadToaster.maybeOf(context)?.show(
        FeedbackToast.error(
          message: context.l10n.contactEmailEncryptionImportFailed,
        ),
      );
      return;
    }
    if (!context.mounted || result == null || result.files.isEmpty) {
      return;
    }
    final path = result.files.single.path;
    if (path == null || path.trim().isEmpty) {
      ShadToaster.maybeOf(context)?.show(
        FeedbackToast.error(
          message: context.l10n.contactEmailEncryptionImportFailed,
        ),
      );
      return;
    }
    await context.read<EmailContactKeyCubit>().inspectPublicKey(File(path));
  }

  Future<void> _removePublicKey(BuildContext context) async {
    final confirmed = await confirm(
      context,
      text: context.l10n.contactEmailEncryptionRemoveConfirm(contact.address),
    );
    if (!context.mounted || confirmed != true) {
      return;
    }
    await context.read<EmailContactKeyCubit>().remove();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final idle = state is EmailContactKeyIdle
        ? state as EmailContactKeyIdle
        : const EmailContactKeyIdle();
    final accountAddress = idle.account?.normalizedAddress;
    final betaEnabled =
        accountAddress != null &&
        context
                .watch<SettingsCubit>()
                .state
                .emailEncryptionBetaEnabledByAddress[accountAddress] ==
            true;
    final trustedKey = idle.trustedKey;
    final busy = state.isBusy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.keyRound,
              size: context.sizing.menuItemIconSize,
              color: context.colorScheme.mutedForeground,
            ),
            SizedBox(width: spacing.s),
            Expanded(
              child: Text(
                context.l10n.contactEmailEncryptionTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.small.strong,
              ),
            ),
            if (trustedKey != null)
              AxiStatusChip(
                label: betaEnabled
                    ? context.l10n.contactEmailEncryptionActive
                    : context.l10n.contactEmailEncryptionInactiveBetaOff,
                tone: betaEnabled
                    ? AxiStatusChipTone.info
                    : AxiStatusChipTone.neutral,
              ),
          ],
        ),
        SizedBox(height: spacing.s),
        if (trustedKey == null)
          Text(
            idle.account == null
                ? context.l10n.contactEmailEncryptionNoActiveAccount
                : context.l10n.contactEmailEncryptionNoKey,
            style: context.textTheme.muted,
          )
        else
          _ContactEmailEncryptionKeyDetails(keyData: trustedKey),
        SizedBox(height: spacing.m),
        Wrap(
          spacing: spacing.s,
          runSpacing: spacing.s,
          children: [
            AxiButton.outline(
              onPressed: idle.account == null || busy
                  ? null
                  : () => _pickPublicKey(context),
              child: Text(
                trustedKey == null
                    ? context.l10n.contactEmailEncryptionAddPublicKey
                    : context.l10n.contactEmailEncryptionReplacePublicKey,
              ),
            ),
            if (trustedKey != null)
              AxiButton.destructive(
                onPressed: busy ? null : () => _removePublicKey(context),
                child: Text(context.l10n.contactEmailEncryptionRemovePublicKey),
              ),
          ],
        ),
      ],
    );
  }
}

class _ContactEmailEncryptionKeyDetails extends StatelessWidget {
  const _ContactEmailEncryptionKeyDetails({required this.keyData});

  final EmailTrustedContactKey keyData;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.contactEmailEncryptionFingerprint(keyData.fingerprint),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.muted,
        ),
      ],
    );
  }
}

class _ContactDetailRow extends StatelessWidget {
  const _ContactDetailRow({
    required this.contact,
    required this.icon,
    required this.label,
    required this.value,
    required this.disabled,
    this.kind,
    this.field,
  });

  final ContactDirectoryEntry contact;
  final IconData icon;
  final String label;
  final String value;
  final bool disabled;
  final ContactDetailFieldKind? kind;
  final ContactDetailFieldEntry? field;

  Future<void> _editField(BuildContext context) async {
    final currentKind = field?.kind ?? kind;
    if (currentKind == null) {
      return;
    }
    final value = await _showContactDetailFieldDialog(
      context: context,
      kind: currentKind,
      initialValue: field?.value,
    );
    if (!context.mounted || value == null) {
      return;
    }
    await context.read<ContactsCubit>().saveContactDetailField(
      contact: contact,
      field: field,
      kind: currentKind,
      value: value,
    );
  }

  Future<void> _removeField(BuildContext context) async {
    final currentField = field;
    if (currentField == null) {
      return;
    }
    await context.read<ContactsCubit>().removeContactDetailField(
      contact: contact,
      field: currentField,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentField = field;
    final editable = currentField != null || kind != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: context.spacing.xxs),
          child: Icon(
            icon,
            size: context.sizing.menuItemIconSize,
            color: context.colorScheme.mutedForeground,
          ),
        ),
        SizedBox(width: context.spacing.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.muted,
              ),
              SizedBox(height: context.spacing.xxs),
              Text(
                value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.small,
              ),
            ],
          ),
        ),
        if (editable) ...[
          SizedBox(width: context.spacing.xs),
          AxiIconButton.ghost(
            iconData: currentField == null
                ? LucideIcons.plus
                : LucideIcons.pencil,
            tooltip: currentField == null
                ? context.l10n.commonAdd
                : context.l10n.chatActionEdit,
            onPressed: disabled ? null : () => _editField(context),
          ),
          if (currentField != null)
            AxiIconButton.ghost(
              iconData: LucideIcons.trash,
              tooltip: context.l10n.commonRemove,
              onPressed: disabled ? null : () => _removeField(context),
            ),
        ],
      ],
    );
  }
}

class _ContactFavoriteIndicator extends StatelessWidget {
  const _ContactFavoriteIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(end: context.spacing.xs),
      child: Semantics(
        label: context.l10n.commonFavorite,
        child: Icon(
          LucideIcons.star,
          size: context.sizing.menuItemIconSize,
          color: context.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ContactBlockedIndicator extends StatelessWidget {
  const _ContactBlockedIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(end: context.spacing.xs),
      child: AxiTooltip(
        builder: (context) => Text(context.l10n.blocklistBlockedStatus),
        child: Icon(
          LucideIcons.userX,
          size: context.sizing.menuItemIconSize,
          color: context.colorScheme.destructive,
        ),
      ),
    );
  }
}

class _ContactFolderRuleIndicator extends StatelessWidget {
  const _ContactFolderRuleIndicator({required this.collection});

  final SystemMessageCollection collection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(end: context.spacing.xs),
      child: Semantics(
        label: collection.label(context.l10n),
        child: Icon(
          _contactFolderRuleIcon(collection),
          size: context.sizing.menuItemIconSize,
          color: context.colorScheme.mutedForeground,
        ),
      ),
    );
  }
}

class _ContactStatusRow extends StatelessWidget {
  const _ContactStatusRow({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: context.sizing.menuItemIconSize,
          color: destructive
              ? context.colorScheme.destructive
              : context.colorScheme.mutedForeground,
        ),
        SizedBox(width: context.spacing.s),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.muted,
          ),
        ),
      ],
    );
  }
}

class _ContactRuleButtonLabel extends StatelessWidget {
  const _ContactRuleButtonLabel({required this.contact});

  final ContactDirectoryEntry contact;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Text(
        _contactFolderRuleActionLabel(context.l10n, contact),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ContactDetailsActions extends StatelessWidget {
  const _ContactDetailsActions({
    required this.contact,
    required this.emailEnabled,
    required this.group,
  });

  final ContactDirectoryEntry contact;
  final bool emailEnabled;
  final _ContactDetailsActionGroup group;

  Future<void> _removeContact(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await confirm(
      context,
      text: l10n.contactsRemoveContactConfirm(contact.address),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await context.read<ContactsCubit>().removeContact(contact);
  }

  Future<void> _renameContact(BuildContext context) async {
    final result = await showContactRenameDialog(
      context: context,
      initialValue: contact.displayName,
    );
    if (!context.mounted || result == null) {
      return;
    }
    if (result.isEmpty) {
      await context.read<ContactsCubit>().resetContactDisplayName(
        contact: contact,
      );
    } else {
      await context.read<ContactsCubit>().renameContact(
        contact: contact,
        displayName: result,
      );
    }
  }

  Future<void> _blockContact(BuildContext context) async {
    await context.read<BlocklistCubit>().blockContact(
      address: contact.address,
      includeEmail: contact.hasEmailContact,
      includeXmpp: contact.hasXmppRoster,
    );
  }

  Future<void> _unblockContact(
    BuildContext context,
    List<BlocklistEntry> entries,
  ) async {
    await context.read<BlocklistCubit>().unblockContact(
      address: contact.address,
      includeEmail: entries.any((entry) => entry.isEmail),
      includeXmpp: entries.any((entry) => entry.isXmpp),
    );
  }

  Future<void> _showFolderRule(BuildContext context) async {
    await showContactFolderRuleSheet(context, contact: contact);
  }

  Future<void> _openChat(BuildContext context) async {
    await Navigator.of(context).maybePop(_ContactDetailsSheetAction.openChat);
  }

  Future<void> _composeEmail(BuildContext context) async {
    await Navigator.of(
      context,
    ).maybePop(_ContactDetailsSheetAction.composeEmail);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final addressKey = contactDirectoryAddressKey(contact.address);
    final contactsState = context.watch<ContactsCubit>().state;
    final isUpdatingContact = contactsState.isContactAddressLoading(addressKey);
    final blocklistState = context.watch<BlocklistCubit>().state;
    final cachedBlocklistItems =
        context.watch<BlocklistCubit>()[BlocklistCubit.blocklistItemsCacheKey]
            as List<BlocklistEntry>?;
    final blocklistItems =
        blocklistState.items ??
        cachedBlocklistItems ??
        const <BlocklistEntry>[];
    final contactBlockEntries = _contactBlockEntries(
      contact: contact,
      entries: blocklistItems,
    );
    final contactBlocked = contactBlockEntries.isNotEmpty;
    final blockOperationInFlight =
        blocklistState is BlocklistLoading &&
        blocklistState.operation.matches(address: contact.address);
    final isRemoving = contactsState.isContactActionLoading(
      action: ContactActionType.removeContact,
      address: addressKey,
    );
    final disabled = isRemoving || isUpdatingContact || blockOperationInFlight;
    final isRenaming =
        contactsState.isContactActionLoading(
          action: ContactActionType.rename,
          address: addressKey,
        ) ||
        contactsState.isContactActionLoading(
          action: ContactActionType.resetRename,
          address: addressKey,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (group) {
        _ContactDetailsActionGroup.primary => [
          AxiButton.outline(
            widthBehavior: AxiButtonWidth.expand,
            onPressed: disabled
                ? null
                : () => context.read<ContactsCubit>().setFavorited(
                    contact: contact,
                    favorited: !contact.favorited,
                  ),
            leading: Icon(
              contact.favorited ? LucideIcons.starOff : LucideIcons.star,
            ),
            child: Text(
              contact.favorited ? l10n.commonUnfavorite : l10n.commonFavorite,
            ),
          ),
          SizedBox(height: spacing.s),
          AxiButton.outline(
            widthBehavior: AxiButtonWidth.expand,
            loading: isRenaming,
            onPressed: disabled ? null : () => _renameContact(context),
            leading: const Icon(LucideIcons.pencil),
            child: Text(l10n.commonRename),
          ),
          SizedBox(height: spacing.s),
          AxiButton.outline(
            widthBehavior: AxiButtonWidth.expand,
            onPressed: disabled ? null : () => _showFolderRule(context),
            leading: const Icon(LucideIcons.folder),
            child: _ContactRuleButtonLabel(contact: contact),
          ),
          if (contact.hasXmppRoster) ...[
            SizedBox(height: spacing.s),
            AxiButton.outline(
              widthBehavior: AxiButtonWidth.expand,
              onPressed: disabled ? null : () => _openChat(context),
              child: Text(l10n.commonOpen),
            ),
          ],
          if (_emailComposeEnabled(
            contact: contact,
            emailEnabled: emailEnabled,
          )) ...[
            SizedBox(height: spacing.s),
            AxiButton.outline(
              widthBehavior: AxiButtonWidth.expand,
              onPressed: disabled ? null : () => _composeEmail(context),
              child: Text(l10n.contactsComposeEmail),
            ),
          ],
        ],
        _ContactDetailsActionGroup.destructive => [
          if (contact.hasXmppRoster || contact.hasEmailContact)
            AxiButton.destructive(
              widthBehavior: AxiButtonWidth.expand,
              loading: blockOperationInFlight,
              onPressed: disabled
                  ? null
                  : contactBlocked
                  ? () => _unblockContact(context, contactBlockEntries)
                  : () => _blockContact(context),
              leading: Icon(
                contactBlocked ? LucideIcons.userCheck : LucideIcons.userX,
              ),
              child: Text(
                contactBlocked ? l10n.blocklistUnblock : l10n.blocklistBlock,
              ),
            ),
          if ((contact.hasXmppRoster || contact.hasEmailContact) &&
              (contact.hasPrivateContact ||
                  contact.hasXmppRoster ||
                  contact.hasEmailContact))
            SizedBox(height: spacing.s),
          if (contact.hasPrivateContact ||
              contact.hasXmppRoster ||
              contact.hasEmailContact)
            AxiButton.destructive(
              widthBehavior: AxiButtonWidth.expand,
              loading: isRemoving,
              onPressed: disabled ? null : () => _removeContact(context),
              child: Text(l10n.contactsRemoveContactLabel),
            ),
        ],
      },
    );
  }
}

enum _ContactDetailsActionGroup { primary, destructive }

bool _contactDestructiveActionsEnabled(ContactDirectoryEntry contact) {
  return contact.hasPrivateContact ||
      contact.hasXmppRoster ||
      contact.hasEmailContact;
}

String _contactFailureMessage(
  BuildContext context,
  ContactFailureReason reason,
) {
  final l10n = context.l10n;
  return switch (reason) {
    ContactFailureReason.invalidAddress => l10n.blocklistInvalidJid,
    ContactFailureReason.unavailable => l10n.contactsEmailUnavailableLabel,
    ContactFailureReason.addFailed ||
    ContactFailureReason.removeFailed ||
    ContactFailureReason.updateFailed => l10n.authGenericError,
  };
}

class _ContactDetailFieldDialog extends StatefulWidget {
  const _ContactDetailFieldDialog({required this.kind, this.initialValue});

  final ContactDetailFieldKind kind;
  final String? initialValue;

  @override
  State<_ContactDetailFieldDialog> createState() =>
      _ContactDetailFieldDialogState();
}

class _ContactDetailFieldDialogState extends State<_ContactDetailFieldDialog> {
  late final TextEditingController _controller;
  var _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(_handleChanged);
    _canSubmit = widget.initialValue?.trim().isNotEmpty == true;
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  void _handleChanged() {
    final canSubmit = _controller.text.trim().isNotEmpty;
    if (canSubmit == _canSubmit) {
      return;
    }
    setState(() {
      _canSubmit = canSubmit;
    });
  }

  void _submit() {
    if (!_canSubmit) {
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AxiDialog(
      title: Text(_contactDetailFieldLabel(l10n, widget.kind)),
      actions: [
        AxiButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        AxiButton.primary(
          onPressed: _canSubmit ? _submit : null,
          child: Text(l10n.commonSave),
        ),
      ],
      child: AxiTextFormField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.kind == ContactDetailFieldKind.phone
            ? TextInputType.phone
            : TextInputType.multiline,
        minLines: widget.kind == ContactDetailFieldKind.address ? 2 : null,
        maxLines: widget.kind == ContactDetailFieldKind.address ? 4 : 1,
        textInputAction: widget.kind == ContactDetailFieldKind.address
            ? TextInputAction.newline
            : TextInputAction.done,
        placeholder: Text(_contactDetailFieldLabel(l10n, widget.kind)),
        onSubmitted: (_) {
          if (widget.kind != ContactDetailFieldKind.address) {
            _submit();
          }
        },
      ),
    );
  }
}

Future<String?> _showContactDetailFieldDialog({
  required BuildContext context,
  required ContactDetailFieldKind kind,
  String? initialValue,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _ContactDetailFieldDialog(kind: kind, initialValue: initialValue),
  );
}

List<String> _contactSecondaryValues(
  ContactDirectoryEntry contact,
  AppLocalizations l10n,
) {
  return <String>[
    if (contact.displayName != contact.address) contact.address,
    if (contact.isEmailOnly) l10n.contactsLocalOnlyLabel,
  ];
}

List<Widget>? _contactTileIndicators(
  ContactDirectoryEntry contact, {
  required bool blocked,
}) {
  final systemCollection = contact.folderCollectionId == null
      ? null
      : SystemMessageCollection.fromId(contact.folderCollectionId!);
  final indicators = <Widget>[
    if (blocked) const _ContactBlockedIndicator(),
    if (contact.favorited &&
        systemCollection != SystemMessageCollection.important)
      const _ContactFavoriteIndicator(),
    if (systemCollection != null)
      _ContactFolderRuleIndicator(collection: systemCollection),
  ];
  return indicators.isEmpty ? null : indicators;
}

List<BlocklistEntry> _contactBlockEntries({
  required ContactDirectoryEntry contact,
  required Iterable<BlocklistEntry> entries,
}) {
  return blocklistEntriesForAddress(address: contact.address, entries: entries);
}

IconData _contactFolderRuleIcon(SystemMessageCollection collection) {
  return switch (collection) {
    SystemMessageCollection.important => LucideIcons.star,
    SystemMessageCollection.receipts => LucideIcons.receiptText,
    SystemMessageCollection.marketing => LucideIcons.megaphone,
    SystemMessageCollection.newsletters => LucideIcons.newspaper,
  };
}

bool _emailComposeEnabled({
  required ContactDirectoryEntry contact,
  required bool emailEnabled,
}) => emailEnabled && normalizedAddressValue(contact.address) != null;

bool _emailContactKeyManagementEnabled({
  required ContactDirectoryEntry contact,
  required bool emailEnabled,
  required bool emailContactKeysAvailable,
}) =>
    emailContactKeysAvailable &&
    _emailComposeEnabled(contact: contact, emailEnabled: emailEnabled);

ContactDirectoryEntry _currentContactForSheet(
  List<ContactDirectoryEntry>? items,
  ContactDirectoryEntry fallback,
) {
  final addressKey = contactDirectoryAddressKey(fallback.address);
  for (final item in items ?? const <ContactDirectoryEntry>[]) {
    if (contactDirectoryAddressKey(item.address) == addressKey) {
      return item;
    }
  }
  return fallback;
}

List<({IconData icon, String label})> _contactSourceItems(
  AppLocalizations l10n,
  ContactDirectoryEntry contact,
) {
  return <({IconData icon, String label})>[
    if (contact.hasXmppRoster)
      (icon: LucideIcons.messagesSquare, label: l10n.contactsChatContactLabel),
    if (contact.hasEmailContact)
      (icon: LucideIcons.mail, label: l10n.contactsEmailContactLabel),
    if (contact.isEmailOnly)
      (icon: LucideIcons.smartphone, label: l10n.contactsLocalOnlyLabel),
  ];
}

List<
  ({
    IconData icon,
    String label,
    String value,
    ContactDetailFieldKind? kind,
    ContactDetailFieldEntry? field,
  })
>
_contactDetailRows(
  AppLocalizations l10n,
  ContactDirectoryEntry contact, {
  required bool emailEnabled,
}) {
  final folderCollectionId = _trimmedContactDetail(contact.folderCollectionId);
  final folderCollectionLabel = folderCollectionId == null
      ? null
      : SystemMessageCollection.fromId(folderCollectionId)?.label(l10n) ??
            folderCollectionId;
  return <
    ({
      IconData icon,
      String label,
      String value,
      ContactDetailFieldKind? kind,
      ContactDetailFieldEntry? field,
    })
  >[
    if (folderCollectionLabel != null)
      (
        icon: LucideIcons.folder,
        label: l10n.contactsFolderRoutingDetailLabel,
        value: folderCollectionLabel,
        kind: null,
        field: null,
      ),
    if (contact.hasEmailContact && !emailEnabled)
      (
        icon: LucideIcons.mailWarning,
        label: l10n.contactsEmailLabel,
        value: l10n.contactsEmailUnavailableLabel,
        kind: null,
        field: null,
      ),
    for (final field in contact.detailFields)
      if (_contactDetailFieldSupported(field.kind))
        (
          icon: _contactDetailFieldIcon(field.kind),
          label: field.label?.trim().isNotEmpty == true
              ? field.label!
              : _contactDetailFieldLabel(l10n, field.kind),
          value: field.value,
          kind: field.kind,
          field: field,
        ),
    if (!_hasContactDetailField(contact, ContactDetailFieldKind.phone))
      (
        icon: _contactDetailFieldIcon(ContactDetailFieldKind.phone),
        label: _contactDetailFieldLabel(l10n, ContactDetailFieldKind.phone),
        value: l10n.commonAdd,
        kind: ContactDetailFieldKind.phone,
        field: null,
      ),
    if (!_hasContactDetailField(contact, ContactDetailFieldKind.address))
      (
        icon: _contactDetailFieldIcon(ContactDetailFieldKind.address),
        label: _contactDetailFieldLabel(l10n, ContactDetailFieldKind.address),
        value: l10n.commonAdd,
        kind: ContactDetailFieldKind.address,
        field: null,
      ),
  ];
}

bool _hasContactDetailField(
  ContactDirectoryEntry contact,
  ContactDetailFieldKind kind,
) {
  return contact.detailFields.any(
    (field) => field.kind == kind && field.value.trim().isNotEmpty,
  );
}

bool _contactDetailFieldSupported(ContactDetailFieldKind kind) {
  return kind == ContactDetailFieldKind.phone ||
      kind == ContactDetailFieldKind.address;
}

IconData _contactDetailFieldIcon(ContactDetailFieldKind kind) {
  return switch (kind) {
    ContactDetailFieldKind.phone => LucideIcons.phone,
    ContactDetailFieldKind.address => LucideIcons.mapPin,
    _ => LucideIcons.info,
  };
}

String _contactDetailFieldLabel(
  AppLocalizations l10n,
  ContactDetailFieldKind kind,
) {
  return switch (kind) {
    ContactDetailFieldKind.phone => l10n.contactsPhonesLabel,
    ContactDetailFieldKind.address => l10n.contactsPostalAddressesLabel,
    _ => l10n.contactsDetailsSectionTitle,
  };
}

String? _trimmedContactDetail(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _contactFolderRuleActionLabel(
  AppLocalizations l10n,
  ContactDirectoryEntry contact,
) {
  if (contact.hasXmppRoster && contact.hasEmailContact) {
    return l10n.contactFolderRuleMessagesAndEmailsAction;
  }
  if (contact.hasEmailContact) {
    return l10n.contactFolderRuleEmailsAction;
  }
  return l10n.contactFolderRuleMessagesAction;
}
