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
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ContactsList extends StatefulWidget {
  const ContactsList({super.key});

  @override
  State<ContactsList> createState() => _ContactsListState();
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
        BlocListener<RosterCubit, RosterState>(
          listenWhen: (previous, current) =>
              previous.actionState != current.actionState,
          listener: (context, state) {
            final actionState = state.actionState;
            if (actionState is! RosterActionFailure ||
                actionState.action != RosterActionType.remove) {
              return;
            }
            ShadToaster.maybeOf(context)?.show(
              FeedbackToast.error(
                message: _rosterFailureMessage(context, actionState.reason),
              ),
            );
          },
        ),
        BlocListener<ContactsCubit, ContactsState>(
          listenWhen: (previous, current) =>
              previous.actionState != current.actionState,
          listener: (context, state) {
            final actionState = state.actionState;
            if (actionState is! ContactActionFailure ||
                actionState.action != ContactActionType.removeEmail) {
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
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: locate<ContactsCubit>()),
            BlocProvider.value(value: locate<RosterCubit>()),
          ],
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
        padding: EdgeInsets.only(top: spacing.l, bottom: spacing.m),
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
    final locate = context.read;
    final spacing = context.spacing;
    final emailEnabled = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.endpointConfig.smtpEnabled,
    );
    final address = contact.address;
    final rosterActionState = context.watch<RosterCubit>().state.actionState;
    final contactsActionState = context
        .watch<ContactsCubit>()
        .state
        .actionState;
    final isRemovingXmpp =
        rosterActionState is RosterActionLoading &&
        rosterActionState.action == RosterActionType.remove &&
        rosterActionState.jid == address;
    final isRemovingEmail =
        contactsActionState is ContactActionLoading &&
        contactsActionState.action == ContactActionType.removeEmail &&
        contactsActionState.address == address;
    return ListItemPadding(
      padding: EdgeInsets.fromLTRB(
        spacing.m,
        spacing.xxs,
        spacing.m,
        spacing.xxs,
      ),
      child: AxiListTile(
        key: ValueKey(address),
        onTap: () => showAdaptiveBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useBottomSafeArea: false,
          surfacePadding: EdgeInsets.zero,
          showDragHandle: true,
          builder: (sheetContext) {
            return MultiBlocProvider(
              providers: [
                BlocProvider.value(value: locate<ContactsCubit>()),
                BlocProvider.value(value: locate<RosterCubit>()),
                BlocProvider.value(value: locate<ChatsCubit>()),
                BlocProvider.value(value: locate<BlocklistCubit>()),
                BlocProvider.value(value: locate<FoldersCubit>()),
              ],
              child: _ContactDetailsSheet(contact: contact),
            );
          },
        ),
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
          if (contact.hasXmppRoster)
            AxiDeleteMenuItem(
              onPressed: isRemovingXmpp
                  ? null
                  : () async {
                      final confirmed = await confirm(
                        context,
                        text: context.l10n.rosterRemoveConfirm(address),
                      );
                      if (confirmed != true || !context.mounted) {
                        return;
                      }
                      await context.read<RosterCubit>().removeContact(
                        jid: address,
                      );
                    },
            ),
          if (contact.hasEmailContact)
            AxiDeleteMenuItem(
              onPressed: isRemovingEmail
                  ? null
                  : () async {
                      final confirmed = await confirm(
                        context,
                        text: context.l10n.contactsRemoveEmailConfirm(address),
                      );
                      if (confirmed != true || !context.mounted) {
                        return;
                      }
                      await context.read<ContactsCubit>().removeEmailContact(
                        address: address,
                        nativeIds: contact.emailNativeIds,
                      );
                    },
            ),
        ],
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.s,
          vertical: spacing.xxs,
        ),
        minTileHeight: context.sizing.listButtonHeight + spacing.xs,
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
        actions: contact.favorited
            ? [
                Semantics(
                  label: context.l10n.commonFavorite,
                  child: Icon(
                    LucideIcons.star,
                    size: context.sizing.menuItemIconSize,
                    color: context.colorScheme.primary,
                  ),
                ),
              ]
            : null,
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
          style: context.textTheme.small.copyWith(
            color: context.colorScheme.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (secondaryValues.isNotEmpty)
          Text(
            secondaryValues.join(' • '),
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
  MessageTransport? _selectedTransport;

  Future<void> _submit() async {
    final resolvedTransport = await _resolveTransport();
    if (resolvedTransport == null || !mounted) {
      return;
    }
    setState(() => _selectedTransport = resolvedTransport);
    final title = _displayName.trim().isEmpty ? null : _displayName.trim();
    if (resolvedTransport.isXmpp) {
      await context.read<RosterCubit>().addContact(
        jid: _address.trim(),
        title: title,
      );
      return;
    }
    await context.read<ContactsCubit>().addEmailContact(
      address: _address,
      displayName: title,
    );
  }

  Future<MessageTransport?> _resolveTransport() async {
    final settings = context.read<SettingsCubit>().state.endpointConfig;
    final supportsEmail = settings.smtpEnabled;
    final supportsXmpp = settings.xmppEnabled;
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    return MultiBlocListener(
      listeners: [
        BlocListener<RosterCubit, RosterState>(
          listenWhen: (previous, current) =>
              previous.actionState != current.actionState,
          listener: (context, state) {
            final actionState = state.actionState;
            if (_selectedTransport != MessageTransport.xmpp) {
              return;
            }
            if (actionState is RosterActionSuccess &&
                actionState.action == RosterActionType.add &&
                context.canPop()) {
              context.pop();
            }
          },
        ),
        BlocListener<ContactsCubit, ContactsState>(
          listenWhen: (previous, current) =>
              previous.actionState != current.actionState,
          listener: (context, state) {
            final actionState = state.actionState;
            if (_selectedTransport != MessageTransport.email) {
              return;
            }
            if (actionState is ContactActionSuccess &&
                actionState.action == ContactActionType.addEmail &&
                context.canPop()) {
              context.pop();
            }
          },
        ),
      ],
      child: BlocBuilder<RosterCubit, RosterState>(
        buildWhen: (previous, current) =>
            previous.actionState != current.actionState,
        builder: (context, rosterState) {
          return BlocBuilder<ContactsCubit, ContactsState>(
            buildWhen: (previous, current) =>
                previous.items != current.items ||
                previous.actionState != current.actionState,
            builder: (context, contactsState) {
              final rosterActionState = rosterState.actionState;
              final contactsActionState = contactsState.actionState;
              final loading = _selectedTransport == MessageTransport.xmpp
                  ? rosterActionState is RosterActionLoading &&
                        rosterActionState.action == RosterActionType.add
                  : _selectedTransport == MessageTransport.email
                  ? contactsActionState is ContactActionLoading &&
                        contactsActionState.action == ContactActionType.addEmail
                  : false;
              final errorMessage = _selectedTransport == MessageTransport.xmpp
                  ? switch (rosterActionState) {
                      RosterActionFailure(:final reason)
                          when rosterActionState.action ==
                              RosterActionType.add =>
                        _rosterFailureMessage(context, reason),
                      _ => null,
                    }
                  : _selectedTransport == MessageTransport.email
                  ? switch (contactsActionState) {
                      ContactActionFailure(:final reason)
                          when contactsActionState.action ==
                              ContactActionType.addEmail =>
                        _contactFailureMessage(context, reason),
                      _ => null,
                    }
                  : null;
              return AxiInputDialog(
                title: Text(l10n.rosterAddTitle),
                loading: loading,
                callback: _address.trim().isEmpty || loading ? null : _submit,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    JidInput(
                      enabled: !loading,
                      error: errorMessage,
                      jidOptions:
                          (contactsState.items ??
                                  const <ContactDirectoryEntry>[])
                              .map((item) => item.address)
                              .toList(growable: false),
                      onChanged: (value) {
                        setState(() {
                          _address = value;
                          _selectedTransport = null;
                        });
                      },
                    ),
                    SizedBox(height: spacing.s),
                    AxiTextFormField(
                      enabled: !loading,
                      placeholder: Text(l10n.contactsDisplayNameLabel),
                      onChanged: (value) =>
                          setState(() => _displayName = value),
                    ),
                  ],
                ),
              );
            },
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
    return BlocBuilder<ContactsCubit, ContactsState>(
      buildWhen: (previous, current) =>
          previous.items != current.items ||
          previous.actionState != current.actionState,
      builder: (context, state) {
        final spacing = context.spacing;
        final currentContact = _currentContactForSheet(state.items, contact);
        final address = currentContact.address;
        final emailEnabled = context.select<SettingsCubit, bool>(
          (cubit) => cubit.state.endpointConfig.smtpEnabled,
        );
        final rosterActionState = context
            .watch<RosterCubit>()
            .state
            .actionState;
        final contactsActionState = state.actionState;
        final isRemovingXmpp =
            rosterActionState is RosterActionLoading &&
            rosterActionState.action == RosterActionType.remove &&
            rosterActionState.jid == address;
        final isRemovingEmail =
            contactsActionState is ContactActionLoading &&
            contactsActionState.action == ContactActionType.removeEmail &&
            contactsActionState.address == address;
        return AxiSheetScaffold.scroll(
          header: AxiSheetHeader(
            title: Text(currentContact.displayName),
            subtitle: currentContact.displayName == address
                ? null
                : Text(address),
            onClose: () => Navigator.of(context).maybePop(),
          ),
          bodyPadding: EdgeInsets.fromLTRB(spacing.m, 0, spacing.m, spacing.s),
          children: [
            _ContactSummaryCard(
              contact: currentContact,
              emailEnabled: emailEnabled,
            ),
            SizedBox(height: spacing.m),
            _ContactDetailsActions(
              contact: currentContact,
              emailEnabled: emailEnabled,
              isRemovingEmail: isRemovingEmail,
              isRemovingXmpp: isRemovingXmpp,
            ),
          ],
        );
      },
    );
  }
}

class _ContactSummaryCard extends StatelessWidget {
  const _ContactSummaryCard({
    required this.contact,
    required this.emailEnabled,
  });

  final ContactDirectoryEntry contact;
  final bool emailEnabled;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final address = contact.address;
    final l10n = context.l10n;
    final sourceItems = _contactSourceItems(l10n, contact);
    return AxiModalSurface(
      backgroundColor: context.colorScheme.background,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (contact.hasEmailContact && !emailEnabled) ...[
                  SizedBox(height: spacing.s),
                  _ContactStatusRow(
                    icon: LucideIcons.mailWarning,
                    label: l10n.contactsEmailUnavailableLabel,
                  ),
                ],
              ],
            ),
          ),
        ],
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
            style: context.textTheme.muted.copyWith(
              color: context.colorScheme.mutedForeground,
            ),
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
    required this.isRemovingEmail,
    required this.isRemovingXmpp,
  });

  final ContactDirectoryEntry contact;
  final bool emailEnabled;
  final bool isRemovingEmail;
  final bool isRemovingXmpp;

  Future<void> _removeContact(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await confirm(
      context,
      text: l10n.contactsRemoveContactConfirm(contact.address),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    var removed = true;
    if (contact.hasEmailContact) {
      await context.read<ContactsCubit>().removeEmailContact(
        address: contact.address,
        nativeIds: contact.emailNativeIds,
      );
      if (!context.mounted) {
        return;
      }
      final emailActionState = context.read<ContactsCubit>().state.actionState;
      removed =
          removed &&
          emailActionState is ContactActionSuccess &&
          emailActionState.action == ContactActionType.removeEmail &&
          emailActionState.address == contact.address;
    }
    if (!context.mounted) {
      return;
    }
    if (contact.hasXmppRoster) {
      await context.read<RosterCubit>().removeContact(jid: contact.address);
      if (!context.mounted) {
        return;
      }
      final rosterActionState = context.read<RosterCubit>().state.actionState;
      removed =
          removed &&
          rosterActionState is RosterActionSuccess &&
          rosterActionState.action == RosterActionType.remove &&
          rosterActionState.jid == contact.address;
    }
    if (removed && context.mounted && context.canPop()) {
      context.pop();
    }
  }

  Future<void> _renameContact(BuildContext context) async {
    final l10n = context.l10n;
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
    if (!context.mounted) {
      return;
    }
    final actionState = context.read<ContactsCubit>().state.actionState;
    final showToast = ShadToaster.maybeOf(context)?.show;
    if (actionState is ContactActionSuccess &&
        actionState.address == contact.address &&
        (actionState.action == ContactActionType.rename ||
            actionState.action == ContactActionType.resetRename)) {
      showToast?.call(
        FeedbackToast.success(message: l10n.chatContactRenameSuccess),
      );
      return;
    }
    if (actionState is ContactActionFailure &&
        actionState.address == contact.address &&
        (actionState.action == ContactActionType.rename ||
            actionState.action == ContactActionType.resetRename)) {
      showToast?.call(
        FeedbackToast.error(message: l10n.chatContactRenameFailure),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final contactsActionState = context
        .watch<ContactsCubit>()
        .state
        .actionState;
    final isUpdatingContact =
        contactsActionState is ContactActionLoading &&
        contactsActionState.address == contact.address;
    final blocklistState = context.watch<BlocklistCubit>().state;
    final isBlocking =
        blocklistState is BlocklistLoading &&
        (blocklistState.jid == contact.address || blocklistState.jid == null);
    final isRemoving = isRemovingXmpp || isRemovingEmail;
    final disabled = isRemoving || isUpdatingContact || isBlocking;
    final isRenaming =
        contactsActionState is ContactActionLoading &&
        contactsActionState.address == contact.address &&
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
              onPressed: disabled
                  ? null
                  : () => context.read<ChatsCubit>().openChat(
                      jid: contact.address,
                    ),
              child: Text(l10n.commonOpen),
            ),
          if (_emailComposeEnabled(
            contact: contact,
            emailEnabled: emailEnabled,
          )) ...[
            SizedBox(height: spacing.s),
            AxiButton.outline(
              widthBehavior: AxiButtonWidth.expand,
              onPressed: disabled
                  ? null
                  : () => openComposeDraft(
                      context,
                      jids: [contact.address],
                      attachmentMetadataIds: const <String>[],
                    ),
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

String _rosterFailureMessage(BuildContext context, RosterFailureReason reason) {
  final l10n = context.l10n;
  return switch (reason) {
    RosterFailureReason.invalidJid => l10n.jidInputInvalid,
    RosterFailureReason.addFailed ||
    RosterFailureReason.removeFailed ||
    RosterFailureReason.rejectFailed => l10n.authGenericError,
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
