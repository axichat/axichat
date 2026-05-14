// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/contact_rename_dialog.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/contacts/bloc/contacts_cubit.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
import 'package:axichat/src/email/bloc/email_contact_import_cubit.dart';
import 'package:axichat/src/email/view/email_contact_import_tile.dart';
import 'package:axichat/src/folders/bloc/folders_cubit.dart';
import 'package:axichat/src/folders/view/folder_picker_sheet.dart';
import 'package:axichat/src/home/bloc/home_bloc.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
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
  final action = await showAdaptiveBottomSheet<_ContactDetailsSheetAction>(
    context: context,
    isScrollControlled: true,
    useBottomSafeArea: false,
    surfacePadding: EdgeInsets.zero,
    showDragHandle: true,
    builder: (_) {
      return MultiBlocProvider(
        providers: [
          BlocProvider.value(value: locate<ContactsCubit>()),
          BlocProvider.value(value: locate<BlocklistCubit>()),
          BlocProvider.value(value: locate<FoldersCubit>()),
        ],
        child: _ContactDetailsSheet(contact: contact),
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
        attachmentMetadataIds: const <String>[],
      );
    case null:
      return;
  }
}

enum _ContactDetailsSheetAction { openChat, composeEmail }

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
    final locate = context.read;
    final l10n = context.l10n;
    final emailEnabled = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.endpointConfig.smtpEnabled,
    );
    if (!emailEnabled) {
      return AxiFab(
        tooltip: l10n.emailContactsImportAccountRequired,
        iconData: LucideIcons.userRoundPlus,
        text: l10n.emailContactsImportAction,
      );
    }
    return BlocSelector<EmailContactImportCubit, EmailContactImportState, bool>(
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
    final contactsActionState = context
        .watch<ContactsCubit>()
        .state
        .actionState;
    final isRemoving =
        contactsActionState is ContactActionLoading &&
        contactsActionState.action == ContactActionType.removeContact &&
        contactDirectoryAddressKey(contactsActionState.address) == addressKey;
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
        actions: _contactTileIndicators(contact),
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
  String _address = '';
  String _displayName = '';
  String _submittedAddress = '';

  Future<void> _submit({
    required bool supportsEmail,
    required bool supportsXmpp,
  }) async {
    final resolvedTransport = await _resolveTransport(
      supportsEmail: supportsEmail,
      supportsXmpp: supportsXmpp,
    );
    if (resolvedTransport == null || !mounted) {
      return;
    }
    final title = _displayName.trim().isEmpty ? null : _displayName.trim();
    setState(() => _submittedAddress = _address);
    await context.read<ContactsCubit>().addContact(
      address: _address,
      displayName: title,
      transport: resolvedTransport,
    );
  }

  Future<MessageTransport?> _resolveTransport({
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
    return showTransportChoiceDialog(
      context,
      address: _address.trim(),
      defaultTransport: hintTransportForAddress(_address),
    );
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
            previous.actionState != current.actionState,
        builder: (context, contactsState) {
          final contactsActionState = contactsState.actionState;
          final loading =
              contactsActionState is ContactActionLoading &&
              contactsActionState.action == ContactActionType.addContact &&
              _matchesSubmittedAddress(contactsActionState.address);
          final errorMessage = switch (contactsActionState) {
            ContactActionFailure(:final reason, :final address)
                when contactsActionState.action ==
                        ContactActionType.addContact &&
                    _matchesSubmittedAddress(address) =>
              _contactFailureMessage(context, reason),
            _ => null,
          };
          return AxiInputDialog(
            title: Text(l10n.rosterAddTitle),
            loading: loading,
            callback:
                _address.trim().isEmpty ||
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
                JidInput(
                  enabled: !loading,
                  error: errorMessage,
                  jidOptions:
                      (contactsState.items ?? const <ContactDirectoryEntry>[])
                          .map((item) => item.address)
                          .toList(growable: false),
                  onChanged: (value) {
                    setState(() {
                      _address = value;
                      _submittedAddress = '';
                    });
                  },
                ),
                SizedBox(height: spacing.s),
                AxiTextFormField(
                  enabled: !loading,
                  placeholder: Text(l10n.contactsDisplayNameLabel),
                  onChanged: (value) => setState(() => _displayName = value),
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
  const _ContactDetailsSheet({required this.contact});

  final ContactDirectoryEntry contact;

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
            previous.actionState != current.actionState,
        builder: (context, state) {
          final spacing = context.spacing;
          final currentContact = _currentContactForSheet(state.items, contact);
          final emailEnabled = context.select<SettingsCubit, bool>(
            (cubit) => cubit.state.endpointConfig.smtpEnabled,
          );
          final detailRows = _contactDetailRows(
            context.l10n,
            currentContact,
            emailEnabled: emailEnabled,
          );
          return AxiSheetScaffold.scroll(
            header: AxiSheetHeader(
              title: Text(context.l10n.contactsDetailsSectionTitle),
              onClose: () => Navigator.of(context).maybePop(),
            ),
            bodyPadding: EdgeInsets.fromLTRB(
              spacing.m,
              0,
              spacing.m,
              spacing.s,
            ),
            children: [
              _ContactSummaryCard(contact: currentContact),
              SizedBox(height: spacing.m),
              if (detailRows.isNotEmpty) ...[
                _ContactDetailsInfoCard(
                  contact: currentContact,
                  rows: detailRows,
                ),
                SizedBox(height: spacing.m),
              ],
              _ContactDetailsActions(
                contact: currentContact,
                emailEnabled: emailEnabled,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ContactSummaryCard extends StatelessWidget {
  const _ContactSummaryCard({required this.contact});

  final ContactDirectoryEntry contact;

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
  });

  final ContactDirectoryEntry contact;
  final List<({IconData icon, String label})> sourceItems;

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
        if (contact.favorited || sourceItems.isNotEmpty) ...[
          SizedBox(height: spacing.m),
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
  const _ContactDetailsInfoCard({required this.contact, required this.rows});

  final ContactDirectoryEntry contact;
  final List<({IconData icon, String label, String value})> rows;

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
              icon: rows[index].icon,
              label: rows[index].label,
              value: rows[index].value,
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactDetailRow extends StatelessWidget {
  const _ContactDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
  const _ContactStatusRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: context.sizing.menuItemIconSize,
          color: context.colorScheme.mutedForeground,
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
  });

  final ContactDirectoryEntry contact;
  final bool emailEnabled;

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
    final contactsActionState = context
        .watch<ContactsCubit>()
        .state
        .actionState;
    final isUpdatingContact =
        contactsActionState is ContactActionLoading &&
        contactDirectoryAddressKey(contactsActionState.address) == addressKey;
    final blocklistState = context.watch<BlocklistCubit>().state;
    final isBlocking =
        blocklistState is BlocklistLoading &&
        (blocklistState.jid == contact.address || blocklistState.jid == null);
    final isRemoving =
        contactsActionState is ContactActionLoading &&
        contactsActionState.action == ContactActionType.removeContact &&
        contactDirectoryAddressKey(contactsActionState.address) == addressKey;
    final disabled = isRemoving || isUpdatingContact || isBlocking;
    final isRenaming =
        contactsActionState is ContactActionLoading &&
        contactDirectoryAddressKey(contactsActionState.address) == addressKey &&
        (contactsActionState.action == ContactActionType.rename ||
            contactsActionState.action == ContactActionType.resetRename);
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          SizedBox(height: spacing.s),
          if (contact.hasXmppRoster)
            AxiButton.outline(
              widthBehavior: AxiButtonWidth.expand,
              onPressed: disabled ? null : () => _openChat(context),
              child: Text(l10n.commonOpen),
            ),
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
          if (contact.hasXmppRoster || contact.hasEmailContact) ...[
            SizedBox(height: spacing.s),
            AxiButton.destructive(
              widthBehavior: AxiButtonWidth.expand,
              loading: isBlocking,
              onPressed: disabled ? null : () => _blockContact(context),
              leading: const Icon(LucideIcons.userX),
              child: Text(l10n.blocklistBlock),
            ),
          ],
          if (contact.hasPrivateContact ||
              contact.hasXmppRoster ||
              contact.hasEmailContact) ...[
            SizedBox(height: spacing.s),
            AxiButton.destructive(
              widthBehavior: AxiButtonWidth.expand,
              loading: isRemoving,
              onPressed: disabled ? null : () => _removeContact(context),
              child: Text(l10n.contactsRemoveContactLabel),
            ),
          ],
        ],
      ),
    );
  }
}

String _contactFailureMessage(
  BuildContext context,
  ContactFailureReason reason,
) {
  final l10n = context.l10n;
  return switch (reason) {
    ContactFailureReason.invalidAddress => l10n.jidInputInvalid,
    ContactFailureReason.unavailable => l10n.contactsEmailUnavailableLabel,
    ContactFailureReason.addFailed ||
    ContactFailureReason.removeFailed ||
    ContactFailureReason.updateFailed => l10n.authGenericError,
  };
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

List<Widget>? _contactTileIndicators(ContactDirectoryEntry contact) {
  final systemCollection = contact.folderCollectionId == null
      ? null
      : SystemMessageCollection.fromId(contact.folderCollectionId!);
  final indicators = <Widget>[
    if (contact.favorited &&
        systemCollection != SystemMessageCollection.important)
      const _ContactFavoriteIndicator(),
    if (systemCollection != null)
      _ContactFolderRuleIndicator(collection: systemCollection),
  ];
  return indicators.isEmpty ? null : indicators;
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
}) => contact.hasEmailContact && emailEnabled;

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

List<({IconData icon, String label, String value})> _contactDetailRows(
  AppLocalizations l10n,
  ContactDirectoryEntry contact, {
  required bool emailEnabled,
}) {
  final folderCollectionId = _trimmedContactDetail(contact.folderCollectionId);
  final folderCollectionLabel = folderCollectionId == null
      ? null
      : SystemMessageCollection.fromId(folderCollectionId)?.label(l10n) ??
            folderCollectionId;
  return <({IconData icon, String label, String value})>[
    if (folderCollectionLabel != null)
      (
        icon: LucideIcons.folder,
        label: l10n.homeTabFolders,
        value: folderCollectionLabel,
      ),
    if (contact.hasEmailContact && !emailEnabled)
      (
        icon: LucideIcons.mailWarning,
        label: l10n.contactsEmailLabel,
        value: l10n.contactsEmailUnavailableLabel,
      ),
  ];
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
