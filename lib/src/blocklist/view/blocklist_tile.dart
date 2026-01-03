// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/models/blocklist_entry.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BlocklistTile extends StatelessWidget {
  const BlocklistTile({super.key, required this.entry});

  final BlocklistEntry entry;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) =>
          state is BlocklistLoading &&
          (state.jid == entry.address || state.jid == null),
      builder: (context, disabled) {
        RosterCubit? rosterCubit() => context.read<RosterCubit?>();
        final Widget avatar = rosterCubit() == null
            ? AxiAvatar(jid: entry.address)
            : BlocBuilder<RosterCubit, RosterState>(
                buildWhen: (_, current) => current is RosterAvailable,
                builder: (context, rosterState) {
                  final cachedItems = rosterState is RosterAvailable
                      ? rosterState.items
                      : context.read<RosterCubit>()['items']
                          as List<RosterItem>?;
                  final normalizedJid = entry.address.trim().toLowerCase();
                  String? avatarPath;
                  if (cachedItems != null) {
                    for (final item in cachedItems) {
                      if (item.jid.toLowerCase() == normalizedJid) {
                        avatarPath = item.avatarPath;
                        break;
                      }
                    }
                  }
                  return AxiAvatar(
                    jid: entry.address,
                    avatarPath: avatarPath,
                  );
                },
              );
        return AxiListTile(
          leading: avatar,
          title: entry.address,
          actions: [
            ShadButton.ghost(
              onPressed: disabled
                  ? null
                  : () =>
                      context.read<BlocklistCubit?>()?.unblock(entry: entry),
              foregroundColor: context.colorScheme.destructive,
              child: Text(context.l10n.blocklistUnblock),
            ).withTapBounce(enabled: !disabled),
          ],
        );
      },
    );
  }
}
