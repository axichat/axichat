// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/bloc/chat_search_cubit.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/folders/bloc/folders_cubit.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatSessionProviders extends StatelessWidget {
  const ChatSessionProviders({
    super.key,
    required this.jid,
    required this.settings,
    required this.emailService,
    required this.locate,
    required this.child,
  });

  final String jid;
  final SettingsState settings;
  final EmailService? emailService;
  final T Function<T>() locate;
  final Widget child;

  ChatSettingsSnapshot get _settingsSnapshot => ChatSettingsSnapshot(
    language: settings.language,
    chatReadReceipts: settings.chatReadReceipts,
    emailReadReceipts: settings.emailReadReceipts,
    shareTokenSignatureEnabled: settings.shareTokenSignatureEnabled,
    autoDownloadImages: settings.autoDownloadImages,
    autoDownloadVideos: settings.autoDownloadVideos,
    autoDownloadDocuments: settings.autoDownloadDocuments,
    autoDownloadArchives: settings.autoDownloadArchives,
  );

  @override
  Widget build(BuildContext context) {
    final xmppService = locate<XmppService>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ChatBloc(
            jid: jid,
            messageService: xmppService,
            chatsService: xmppService,
            mucService: xmppService,
            notificationService: locate<NotificationService>(),
            emailService: emailService,
            settings: _settingsSnapshot,
          ),
        ),
        BlocProvider(
          create: (_) => ChatSearchCubit(
            jid: jid,
            messageService: xmppService,
            emailService: emailService,
          ),
        ),
        BlocProvider(
          create: (_) => FoldersCubit(xmppService: xmppService, chatJid: jid),
        ),
      ],
      child: child,
    );
  }
}
