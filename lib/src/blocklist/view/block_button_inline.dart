// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BlockButtonInline extends StatelessWidget {
  const BlockButtonInline({
    super.key,
    required this.jid,
    this.emailAddress,
    this.useEmailBlocking = false,
    this.callback,
    this.showIcon = false,
    this.mainAxisAlignment,
  });

  final String jid;
  final String? emailAddress;
  final bool useEmailBlocking;
  final void Function()? callback;
  final bool showIcon;
  final MainAxisAlignment? mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    if (useEmailBlocking) {
      return _EmailBlockButton(
        emailAddress: emailAddress,
        callback: callback,
        showIcon: showIcon,
        mainAxisAlignment: mainAxisAlignment,
      );
    }
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) =>
          state is BlocklistLoading && (state.jid == jid || state.jid == null),
      builder: (context, disabled) {
        final onPressed = disabled
            ? null
            : () {
                context.read<BlocklistCubit?>()?.block(address: jid);
                if (callback != null) {
                  callback!();
                }
              };
        return ShadButton.ghost(
          width: double.infinity,
          mainAxisAlignment: mainAxisAlignment,
          onPressed: onPressed,
          foregroundColor: context.colorScheme.destructive,
          leading: showIcon ? const Icon(LucideIcons.userX) : null,
          child: Text(context.l10n.blocklistBlock),
        ).withTapBounce(enabled: onPressed != null);
      },
    );
  }
}

class _EmailBlockButton extends StatelessWidget {
  const _EmailBlockButton({
    required this.emailAddress,
    this.callback,
    this.showIcon = false,
    this.mainAxisAlignment,
  });

  final String? emailAddress;
  final void Function()? callback;
  final bool showIcon;
  final MainAxisAlignment? mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final String? address = emailAddress?.trim();
    if (address == null || address.isEmpty) {
      return ShadButton.ghost(
        width: double.infinity,
        mainAxisAlignment: mainAxisAlignment,
        onPressed: null,
        foregroundColor: context.colorScheme.destructive,
        leading: showIcon ? const Icon(LucideIcons.userX) : null,
        child: Text(context.l10n.blocklistBlock),
      ).withTapBounce(enabled: false);
    }
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) =>
          state is BlocklistLoading &&
          (state.jid == address || state.jid == null),
      builder: (context, disabled) {
        VoidCallback? onPressed = disabled
            ? null
            : () {
                context.read<BlocklistCubit>().block(
                      address: address,
                      transport: MessageTransport.email,
                    );
                callback?.call();
              };
        return ShadButton.ghost(
          width: double.infinity,
          mainAxisAlignment: mainAxisAlignment,
          onPressed: onPressed,
          foregroundColor: context.colorScheme.destructive,
          leading: showIcon ? const Icon(LucideIcons.userX) : null,
          child: Text(context.l10n.blocklistBlock),
        ).withTapBounce(enabled: onPressed != null);
      },
    );
  }
}
