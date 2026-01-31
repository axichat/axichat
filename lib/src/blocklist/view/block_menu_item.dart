// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BlockMenuItem extends StatelessWidget {
  const BlockMenuItem({
    super.key,
    required this.jid,
    required this.transport,
  });

  final String jid;
  final MessageTransport transport;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) =>
          state is BlocklistLoading && (state.jid == jid || state.jid == null),
      builder: (context, disabled) {
        return ShadContextMenuItem(
          onPressed: disabled
              ? null
              : () => context
                  .read<BlocklistCubit>()
                  .block(address: jid, transport: transport),
          leading: Icon(
            LucideIcons.userX,
            color: context.colorScheme.destructive,
          ),
          child: Text(context.l10n.blocklistBlock),
        );
      },
    );
  }
}

class ReportSpamMenuItem extends StatelessWidget {
  const ReportSpamMenuItem({
    super.key,
    required this.jid,
    required this.transport,
  });

  final String jid;
  final MessageTransport transport;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) =>
          state is BlocklistLoading && (state.jid == jid || state.jid == null),
      builder: (context, disabled) {
        return ShadContextMenuItem(
          onPressed: disabled
              ? null
              : () => context.read<BlocklistCubit>().block(
                    address: jid,
                    transport: transport,
                    reportReason: SpamReportReason.spam,
                  ),
          leading: Icon(
            LucideIcons.flag,
            color: context.colorScheme.destructive,
          ),
          child: Text(context.l10n.chatReportSpam),
        );
      },
    );
  }
}
