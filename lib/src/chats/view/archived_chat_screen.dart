// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/bloc/chat_search_cubit.dart';
import 'package:axichat/src/chat/view/chat.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ArchivedChatScreen extends StatelessWidget {
  const ArchivedChatScreen({
    super.key,
    required this.locate,
    required this.jid,
  });

  final T Function<T>() locate;
  final String jid;

  @override
  Widget build(BuildContext context) {
    final xmppService = locate<XmppService>();
    final notificationService = locate<NotificationService>();
    final emailService = locate<EmailService>();
    final chatsCubit = locate<ChatsCubit>();
    final settingsCubit = locate<SettingsCubit>();
    final profileCubit = locate<ProfileCubit>();
    final rosterCubit = locate<RosterCubit>();
    final OmemoService? omemoService =
        xmppService is OmemoService ? xmppService as OmemoService : null;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: chatsCubit),
        BlocProvider.value(value: profileCubit),
        BlocProvider.value(value: rosterCubit),
        BlocProvider(
          create: (_) => ChatBloc(
            jid: jid,
            messageService: xmppService,
            chatsService: xmppService,
            mucService: xmppService,
            notificationService: notificationService,
            emailService: emailService,
            omemoService: omemoService,
            settings: ChatSettingsSnapshot(
              language: settingsCubit.state.language,
              chatReadReceipts: settingsCubit.state.chatReadReceipts,
              emailReadReceipts: settingsCubit.state.emailReadReceipts,
              shareTokenSignatureEnabled:
                  settingsCubit.state.shareTokenSignatureEnabled,
            ),
          ),
        ),
        BlocProvider(
          create: (_) => ChatSearchCubit(
            jid: jid,
            messageService: xmppService,
            emailService: emailService,
          ),
        ),
      ],
      child: const _ArchivedChatBody(),
    );
  }
}

class _ArchivedChatBody extends StatelessWidget {
  const _ArchivedChatBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatsArchiveTitle),
        leadingWidth: sizing.iconButtonTapTarget + spacing.m,
        leading: Padding(
          padding: EdgeInsets.only(left: spacing.s),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox.square(
              dimension: sizing.iconButtonTapTarget,
              child: AxiIconButton.ghost(
                iconData: LucideIcons.arrowLeft,
                tooltip: l10n.commonBack,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(context.borderSide.width),
          child: Divider(
            height: context.borderSide.width,
            thickness: context.borderSide.width,
            color: context.borderSide.color,
          ),
        ),
      ),
      body: const SafeArea(child: Chat(readOnly: true)),
    );
  }
}
