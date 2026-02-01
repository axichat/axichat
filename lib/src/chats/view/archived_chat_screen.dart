// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/storage/chat_calendar_storage.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_store.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_coordinator.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/bloc/chat_search_cubit.dart';
import 'package:axichat/src/chat/view/chat.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;
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
    final endpointConfig = locate<AuthenticationCubit>().endpointConfig;
    final EmailService? emailService =
        endpointConfig.enableSmtp ? locate<EmailService>() : null;
    final OmemoService? omemoService =
        xmppService is OmemoService ? xmppService as OmemoService : null;
    final settings = locate<SettingsCubit>().state;
    final storageManager = locate<CalendarStorageManager>();
    final storage = storageManager.authStorage;
    final ChatCalendarSyncCoordinator? chatCalendarCoordinator = storage == null
        ? null
        : ChatCalendarSyncCoordinator(
            storage: ChatCalendarStorage(storage: storage),
            sendMessage: ({
              required String jid,
              required CalendarSyncOutbound outbound,
              required chat_models.ChatType chatType,
            }) async {
              await xmppService.sendCalendarSyncMessage(
                jid: jid,
                outbound: outbound,
                chatType: chatType,
              );
            },
            sendSnapshotFile: xmppService.uploadCalendarSnapshot,
          );
    final CalendarAvailabilityShareCoordinator? availabilityCoordinator =
        storage == null
            ? null
            : CalendarAvailabilityShareCoordinator(
                store: CalendarAvailabilityShareStore(),
                sendMessage: ({
                  required String jid,
                  required CalendarAvailabilityMessage message,
                  required chat_models.ChatType chatType,
                }) async {
                  await xmppService.sendAvailabilityMessage(
                    jid: jid,
                    message: message,
                    chatType: chatType,
                  );
                },
              );

    return MultiRepositoryProvider(
      providers: [
        if (chatCalendarCoordinator != null)
          RepositoryProvider<ChatCalendarSyncCoordinator>.value(
            value: chatCalendarCoordinator,
          ),
        if (availabilityCoordinator != null)
          RepositoryProvider<CalendarAvailabilityShareCoordinator>.value(
            value: availabilityCoordinator,
          ),
      ],
      child: MultiBlocProvider(
        providers: [
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
                language: settings.language,
                chatReadReceipts: settings.chatReadReceipts,
                emailReadReceipts: settings.emailReadReceipts,
                shareTokenSignatureEnabled: settings.shareTokenSignatureEnabled,
                autoDownloadImages: settings.autoDownloadImages,
                autoDownloadVideos: settings.autoDownloadVideos,
                autoDownloadDocuments: settings.autoDownloadDocuments,
                autoDownloadArchives: settings.autoDownloadArchives,
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
      ),
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
