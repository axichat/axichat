// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_coordinator.dart';
import 'package:axichat/src/calendar/storage/chat_calendar_storage.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';

class ChatCalendarBloc extends CalendarBloc {
  ChatCalendarBloc({
    required String chatJid,
    required ChatType chatType,
    required ChatCalendarSyncCoordinator coordinator,
    required super.storage,
    required XmppService xmppService,
    super.emailService,
    super.reminderController,
    super.availabilityCoordinator,
  }) : _chatJid = chatJid,
       super(
         storageId: chatCalendarStorageId(chatJid),
         syncManagerBuilder: (bloc) {
           coordinator.registerBloc(
             chatJid: chatJid,
             chatType: chatType,
             readModel: () => bloc.currentModel,
             applyModel: (CalendarModel model) async {
               if (bloc.currentModel.checksum == model.checksum) {
                 return;
               }
               bloc.add(CalendarEvent.remoteModelApplied(model: model));
               await bloc.stream
                   .firstWhere(
                     (state) => state.model.checksum == model.checksum,
                   )
                   .timeout(const Duration(seconds: 5));
             },
           );
           return coordinator.managerFor(chatJid: chatJid, chatType: chatType);
         },
         onDispose: () => coordinator.unregisterBloc(chatJid: chatJid),
         xmppService: xmppService,
       ) {
    unawaited(
      xmppService
          .rehydrateChatCalendarFromMam(chatJid: chatJid, chatType: chatType)
          .then((outcome) {
            if (outcome.isSuccessful) {
              return;
            }
            SafeLogging.debugLog(
              'Chat calendar MAM rehydration incomplete: $outcome',
              name: 'ChatCalendarBloc',
            );
          })
          .catchError((Object error, StackTrace stackTrace) {
            SafeLogging.debugLog(
              'Chat calendar MAM rehydration failed: $error',
              name: 'ChatCalendarBloc',
              stackTrace: stackTrace,
            );
          }),
    );
  }

  final String _chatJid;

  @override
  CalendarAvailabilityShareSource get availabilityShareSource =>
      CalendarAvailabilityShareSource.chat(chatJid: _chatJid);
}
