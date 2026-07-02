// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BlocklistAddButton extends StatelessWidget {
  const BlocklistAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    return AxiFab(
      tooltip: context.l10n.blocklistAddTooltip,
      iconData: LucideIcons.userX,
      text: context.l10n.blocklistBlock,
      onPressed: () {
        showAdaptiveBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          preferDialogOnMobile: true,
          useRootNavigator: false,
          surfacePadding: EdgeInsets.zero,
          builder: (sheetContext) {
            return MultiBlocProvider(
              providers: [
                BlocProvider.value(value: locate<BlocklistCubit>()),
                BlocProvider.value(value: locate<RosterCubit>()),
                BlocProvider.value(value: locate<ChatsCubit>()),
                BlocProvider.value(value: locate<ProfileCubit>()),
                BlocProvider.value(value: locate<SettingsCubit>()),
              ],
              child: _BlocklistAddSheet(
                onClose: () => Navigator.of(sheetContext).maybePop(),
              ),
            );
          },
        );
      },
    );
  }
}

class _BlocklistAddSheet extends StatelessWidget {
  const _BlocklistAddSheet({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<BlocklistCubit, BlocklistState>(
      listener: (context, state) {
        if (state is BlocklistSuccess && state.operation?.isBlock == true) {
          onClose();
        }
      },
      builder: (context, state) {
        return RecipientPickerSheet(
          title: Text(l10n.blocklistBlockUser),
          primaryLabel: l10n.blocklistBlock,
          primaryIconData: LucideIcons.userX,
          loading: state is BlocklistLoading && state.operation.isBlock,
          errorText:
              state is BlocklistFailure && state.operation?.isBlock == true
              ? state.notice.resolve(l10n)
              : null,
          onClose: onClose,
          resolveRecipient: _resolveBlocklistTargetTransport,
          recipientKeyBuilder: _blocklistRecipientKey,
          canSubmit: (recipients) {
            final targets = _selectedBlocklistTargets(recipients);
            return targets.isNotEmpty && targets.length == recipients.length;
          },
          onSubmit: (context, recipients) {
            final targets = _selectedBlocklistTargets(recipients);
            if (targets.isEmpty || targets.length != recipients.length) {
              return;
            }
            context.read<BlocklistCubit>().blockTargets(targets: targets);
          },
        );
      },
    );
  }
}

List<BlocklistTarget> _selectedBlocklistTargets(
  List<ComposerRecipient> recipients,
) {
  final targets = <BlocklistTarget>[];
  for (final recipient in recipients) {
    switch (recipient.intent) {
      case EmailRecipientIntent(:final address):
        targets.add(
          BlocklistTarget(address: address, transport: MessageTransport.email),
        );
      case XmppRecipientIntent(:final jid):
        targets.add(
          BlocklistTarget(address: jid, transport: MessageTransport.xmpp),
        );
      case PendingTransportRecipient() || UnresolvedRecipient():
        break;
    }
  }
  return targets;
}

ComposerRecipientKey _blocklistRecipientKey(Contact target) {
  final transport = target.configuredTransport;
  final address = switch (transport) {
    MessageTransport.email => normalizedAddressValue(target.resolvedAddress),
    MessageTransport.xmpp => normalizedAddressKey(target.resolvedAddress),
    null =>
      normalizedAddressKey(target.resolvedAddress) ??
          normalizedAddressValue(target.resolvedAddress),
  };
  return ComposerRecipientKey(
    '${transport?.wireValue ?? 'pending'}:${address ?? target.key}',
  );
}

Future<Contact?> _resolveBlocklistTargetTransport(
  BuildContext context,
  Contact target,
  String? _,
) async {
  final address = target.resolvedAddress;
  if (!target.needsTransportSelection || address == null || address.isEmpty) {
    return target;
  }
  final transport = await _resolveBlocklistAddressTransport(context, address);
  if (!context.mounted || transport == null) {
    return null;
  }
  return target.withTransport(transport);
}

Future<MessageTransport?> _resolveBlocklistAddressTransport(
  BuildContext context,
  String address,
) async {
  final endpointConfig = context.read<SettingsCubit>().state.endpointConfig;
  return resolveAddressTransportChoice(
    context,
    address: address,
    endpointConfig: endpointConfig,
    hintBehavior: AddressTransportHintBehavior.promptWithHint,
  );
}

class BlocklistUnblockAllFab extends StatelessWidget {
  const BlocklistUnblockAllFab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) =>
          state is BlocklistLoading && state.operation.isUnblockAll,
      builder: (context, loading) {
        return AxiFab(
          text: context.l10n.blocklistUnblockAll,
          iconData: LucideIcons.shieldOff,
          variant: AxiButtonVariant.destructive,
          loading: loading,
          tooltip: context.l10n.blocklistUnblockAll,
          onPressed: loading
              ? null
              : () async {
                  if (await confirm(context) != true) return;
                  if (context.mounted) {
                    context.read<BlocklistCubit>().unblockAll();
                  }
                },
        );
      },
    );
  }
}
