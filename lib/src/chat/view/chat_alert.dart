// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatAlert extends StatelessWidget {
  const ChatAlert({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final l10n = context.l10n;
        final colors = context.colorScheme;
        final spacing = context.spacing;
        final sizing = context.sizing;
        final chat = state.chat;
        return AnimatedContainer(
          duration: context.watch<SettingsCubit>().animationDuration,
          color: colors.warning,
          alignment: Alignment.center,
          child: !state.showAlert || chat?.alert == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: EdgeInsets.all(spacing.s),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.info,
                        color: colors.foreground,
                        size: sizing.iconButtonIconSize,
                      ),
                      SizedBox.square(dimension: spacing.s),
                      Expanded(
                        child: Text(
                          chat!.alert!,
                          style: context.textTheme.p.copyWith(
                            color: colors.foreground,
                          ),
                        ),
                      ),
                      SizedBox.square(dimension: spacing.xs),
                      AxiButton(
                        variant: AxiButtonVariant.secondary,
                        onPressed: () {
                          context.read<ChatBloc>().add(
                            ChatAlertHidden(chatJid: chat.jid),
                          );
                        },
                        child: Text(l10n.chatAlertHide),
                      ),
                      SizedBox.square(dimension: spacing.xs),
                      AxiButton(
                        variant: AxiButtonVariant.ghost,
                        onPressed: () {
                          context.read<ChatBloc>().add(
                            ChatAlertHidden(chatJid: chat.jid, forever: true),
                          );
                        },
                        child: Text(l10n.chatAlertIgnore),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
