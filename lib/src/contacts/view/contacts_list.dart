// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/contacts/bloc/contacts_cubit.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
import 'package:axichat/src/home/bloc/home_bloc.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
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
    final locate = context.read;
    final tabState = searchState.stateFor(HomeTab.contacts);
    final query = searchState.active ? tabState.query : '';
    locate<ContactsCubit>().updateCriteria(query: query, sort: tabState.sort);
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

class ContactsAddButton extends StatelessWidget {
  const ContactsAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    final l10n = context.l10n;
    return AxiDialogFab(
      tooltip: l10n.rosterAddTooltip,
      iconData: LucideIcons.userPlus,
      label: l10n.rosterAddLabel,
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
              onPressed: () => locate<ChatsCubit>().openChat(jid: address),
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
                      await locate<RosterCubit>().removeContact(jid: address);
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
                      await locate<ContactsCubit>().removeEmailContact(
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
          contact.address,
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
    final spacing = context.spacing;
    final address = contact.address;
    final emailEnabled = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.endpointConfig.smtpEnabled,
    );
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
    return AxiSheetScaffold.scroll(
      header: AxiSheetHeader(
        title: Text(contact.displayName),
        subtitle: contact.displayName == address ? null : Text(address),
        onClose: () => Navigator.of(context).maybePop(),
      ),
      bodyPadding: EdgeInsets.fromLTRB(spacing.m, 0, spacing.m, spacing.s),
      children: [
        _ContactSummaryCard(contact: contact, emailEnabled: emailEnabled),
        SizedBox(height: spacing.m),
        _ContactDetailsCard(contact: contact, emailEnabled: emailEnabled),
        SizedBox(height: spacing.m),
        _ContactDetailsActions(
          contact: contact,
          emailEnabled: emailEnabled,
          isRemovingEmail: isRemovingEmail,
          isRemovingXmpp: isRemovingXmpp,
        ),
      ],
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
    final secondaryTextColor = context.colorScheme.mutedForeground;
    final displayName = contact.displayName;
    final address = contact.address;
    final storageValue = _contactStorageValue(context.l10n, contact);
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
                if (displayName != address)
                  Text(displayName, style: context.textTheme.h3),
                Text(
                  address,
                  style: displayName == address
                      ? context.textTheme.h3
                      : context.textTheme.muted.copyWith(
                          color: secondaryTextColor,
                        ),
                ),
                if (storageValue != null) ...[
                  SizedBox(height: spacing.s),
                  Text(
                    storageValue,
                    style: context.textTheme.muted.copyWith(
                      color: secondaryTextColor,
                    ),
                  ),
                ],
                if (contact.hasEmailContact && !emailEnabled) ...[
                  SizedBox(height: spacing.s),
                  Text(
                    context.l10n.contactsEmailUnavailableLabel,
                    style: context.textTheme.muted.copyWith(
                      color: secondaryTextColor,
                    ),
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

class _ContactDetailsCard extends StatelessWidget {
  const _ContactDetailsCard({
    required this.contact,
    required this.emailEnabled,
  });

  final ContactDirectoryEntry contact;
  final bool emailEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final storageValue = _contactStorageValue(l10n, contact);
    final facts = <Widget>[
      _ContactFactRow(
        label: l10n.profileExportCsvHeaderAddress,
        value: contact.address,
      ),
      if (storageValue != null)
        _ContactFactRow(label: l10n.contactsStoredLabel, value: storageValue),
      if (contact.hasEmailContact && !emailEnabled)
        _ContactFactRow(
          label: l10n.contactsEmailLabel,
          value: l10n.contactsEmailUnavailableLabel,
        ),
    ];
    return AxiModalSurface(
      backgroundColor: context.colorScheme.background,
      borderColor: context.borderSide.color,
      padding: EdgeInsets.all(spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatActionDetails,
            style: context.textTheme.label.strong.copyWith(
              color: context.colorScheme.mutedForeground,
            ),
          ),
          SizedBox(height: spacing.s),
          for (var index = 0; index < facts.length; index += 1) ...[
            if (index > 0) SizedBox(height: spacing.m),
            facts[index],
          ],
        ],
      ),
    );
  }
}

class _ContactFactRow extends StatelessWidget {
  const _ContactFactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textTheme.label.strong.copyWith(
            color: context.colorScheme.mutedForeground,
          ),
        ),
        SizedBox(height: context.spacing.xxs),
        Text(value, style: context.textTheme.small.strong),
      ],
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
    final locate = context.read;
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
      await locate<ContactsCubit>().removeEmailContact(
        address: contact.address,
        nativeIds: contact.emailNativeIds,
      );
      final emailActionState = locate<ContactsCubit>().state.actionState;
      removed =
          removed &&
          emailActionState is ContactActionSuccess &&
          emailActionState.action == ContactActionType.removeEmail &&
          emailActionState.address == contact.address;
    }
    if (contact.hasXmppRoster) {
      await locate<RosterCubit>().removeContact(jid: contact.address);
      final rosterActionState = locate<RosterCubit>().state.actionState;
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

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final isRemoving = isRemovingXmpp || isRemovingEmail;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (contact.hasXmppRoster)
            AxiButton.outline(
              widthBehavior: AxiButtonWidth.expand,
              onPressed: isRemoving
                  ? null
                  : () => locate<ChatsCubit>().openChat(jid: contact.address),
              child: Text(l10n.commonOpen),
            ),
          if (_emailComposeEnabled(
            contact: contact,
            emailEnabled: emailEnabled,
          )) ...[
            SizedBox(height: spacing.s),
            AxiButton.outline(
              widthBehavior: AxiButtonWidth.expand,
              onPressed: isRemoving
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
              loading: isRemoving,
              onPressed: isRemoving ? null : () => _removeContact(context),
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
    ContactFailureReason.removeFailed => l10n.authGenericError,
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
    if (contact.displayName != contact.address) contact.displayName,
    if (contact.isEmailOnly) l10n.contactsLocalOnlyLabel,
  ];
}

bool _emailComposeEnabled({
  required ContactDirectoryEntry contact,
  required bool emailEnabled,
}) => contact.hasEmailContact && emailEnabled;

String? _contactStorageValue(
  AppLocalizations l10n,
  ContactDirectoryEntry contact,
) {
  final sources = <String>[
    if (contact.hasXmppRoster) l10n.authSignupWelcomeTitle,
    if (contact.hasEmailContact) l10n.profileExportEmailContactsLabel,
  ];
  if (sources.isEmpty) {
    return null;
  }
  if (contact.isEmailOnly) {
    return '${sources.join(' • ')} • ${l10n.contactsLocalOnlyLabel}';
  }
  return sources.join(' • ');
}
