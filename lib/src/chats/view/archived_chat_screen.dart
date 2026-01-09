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
    final OmemoService? omemoService =
        xmppService is OmemoService ? xmppService as OmemoService : null;
    ProfileCubit? profileCubit;
    RosterCubit? rosterCubit;
    try {
      profileCubit = locate<ProfileCubit>();
    } catch (_) {
      profileCubit = null;
    }
    try {
      rosterCubit = locate<RosterCubit>();
    } catch (_) {
      rosterCubit = null;
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: chatsCubit),
        if (profileCubit != null) BlocProvider.value(value: profileCubit),
        if (rosterCubit != null)
          BlocProvider.value(value: rosterCubit)
        else
          BlocProvider(
            create: (_) => RosterCubit(rosterService: xmppService),
          ),
        BlocProvider(
          create: (_) => ChatBloc(
            jid: jid,
            messageService: xmppService,
            chatsService: xmppService,
            mucService: xmppService,
            notificationService: notificationService,
            emailService: emailService,
            omemoService: omemoService,
            settingsCubit: settingsCubit,
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
    final colors = context.colorScheme;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatsArchiveTitle),
        leadingWidth: AxiIconButton.kDefaultSize + 24,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: AxiIconButton.kDefaultSize,
              height: AxiIconButton.kDefaultSize,
              child: AxiIconButton.ghost(
                iconData: LucideIcons.arrowLeft,
                tooltip: l10n.commonBack,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: colors.border,
          ),
        ),
      ),
      body: const SafeArea(
        child: Chat(readOnly: true),
      ),
    );
  }
}
