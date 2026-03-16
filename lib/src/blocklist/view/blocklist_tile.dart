// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/models/blocklist_entry.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BlocklistTile extends StatelessWidget {
  const BlocklistTile({super.key, required this.entry, this.avatarPathsByJid});

  final BlocklistEntry entry;
  final Map<String, String>? avatarPathsByJid;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) =>
          state is BlocklistLoading &&
          (state.jid == entry.address || state.jid == null),
      builder: (context, disabled) {
        final normalizedJid = entry.address.normalizedJidKey;
        final avatarPath = normalizedJid == null
            ? null
            : avatarPathsByJid?[normalizedJid];
        final avatar = HydratedAxiAvatar(
          avatar: AvatarPresentation.avatar(
            identifier: entry.address,
            colorSeed: entry.address,
            avatarPath: avatarPath,
            loading: false,
          ),
        );
        return AxiListTile(
          leading: avatar,
          title: entry.address,
          actions: [
            AxiButton.ghost(
              size: AxiButtonSize.sm,
              onPressed: disabled
                  ? null
                  : () => context.read<BlocklistCubit>().unblock(entry: entry),
              child: Text(
                context.l10n.blocklistUnblock,
                style: context.textTheme.label.copyWith(
                  color: context.colorScheme.destructive,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
