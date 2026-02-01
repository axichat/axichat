// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/view/compose_draft_content.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ComposeScreen extends StatelessWidget {
  const ComposeScreen({super.key, required this.seed, required this.locate});

  final ComposeDraftSeed seed;
  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final endpointConfig = locate<SettingsCubit>().state.endpointConfig;
    final emailEnabled = endpointConfig.enableSmtp;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<XmppService>.value(value: locate<XmppService>()),
        RepositoryProvider<MessageService>.value(
          value: locate<MessageService>(),
        ),
        if (emailEnabled)
          RepositoryProvider<EmailService>.value(
            value: locate<EmailService>(),
          ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: locate<AuthenticationCubit>()),
          BlocProvider.value(value: locate<ChatsCubit>()),
          BlocProvider.value(value: locate<DraftCubit>()),
          BlocProvider.value(value: locate<ProfileCubit>()),
          BlocProvider.value(value: locate<RosterCubit>()),
          BlocProvider.value(value: locate<SettingsCubit>()),
        ],
        child: Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            forceMaterialTransparency: true,
            shape: Border(bottom: context.borderSide),
            leadingWidth: sizing.iconButtonTapTarget + spacing.m,
            leading: Navigator.canPop(context)
                ? Padding(
                    padding: EdgeInsets.only(left: spacing.m),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: sizing.iconButtonSize,
                        height: sizing.iconButtonSize,
                        child: AxiIconButton.ghost(
                          iconData: LucideIcons.arrowLeft,
                          tooltip: l10n.commonBack,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  )
                : null,
            title: Text(l10n.composeTitle),
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.all(spacing.m),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: sizing.composeWindowExpandedWidth,
                ),
                child: AxiModalSurface(
                  child: ComposeDraftContent(
                    seed: seed,
                    onClosed: () => Navigator.maybePop(context),
                    onDiscarded: () => Navigator.maybePop(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
