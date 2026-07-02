// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BlocklistTile extends StatelessWidget {
  const BlocklistTile({super.key, required this.entry, this.avatarPathsByJid});

  final BlocklistAddressEntry entry;
  final Map<String, String>? avatarPathsByJid;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) =>
          state is BlocklistLoading &&
          state.operation.matches(address: entry.address),
      builder: (context, disabled) {
        final normalizedJid = entry.address.normalizedJidKey;
        final avatarPath = normalizedJid == null
            ? null
            : avatarPathsByJid?[normalizedJid];
        final avatar = HydratedAxiAvatar(
          avatar: AvatarPresentation.avatar(
            label: entry.address,
            colorSeed: entry.address,
            avatar: Avatar.tryParseOrNull(path: avatarPath, hash: null),
            loading: false,
          ),
        );
        return AxiListTile(
          paintSurface: false,
          minTileHeight: context.sizing.iconButtonTapTarget,
          contentPadding: EdgeInsetsDirectional.only(
            start: context.spacing.s,
            end: context.spacing.s,
            top: context.spacing.xs,
            bottom: context.spacing.xs,
          ),
          horizontalTitleGap: context.spacing.s,
          leadingConstraints: BoxConstraints(
            maxWidth: context.sizing.iconButtonSize,
            maxHeight: context.sizing.iconButtonSize,
          ),
          leading: avatar,
          title: entry.address,
          actions: [
            AxiIconButton.destructive(
              iconData: LucideIcons.shieldOff,
              tooltip: context.l10n.blocklistUnblock,
              loading: disabled,
              onPressed: disabled
                  ? null
                  : () => context.read<BlocklistCubit>().unblockContact(
                      address: entry.address,
                      includeEmail: entry.hasEmail,
                      includeXmpp: entry.hasXmpp,
                    ),
            ),
          ],
        );
      },
    );
  }
}
