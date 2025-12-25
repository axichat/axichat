import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_identifiers.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_coordinator.dart';
import 'package:axichat/src/storage/models/chat_models.dart';

class ChatCalendarBloc extends CalendarBloc {
  ChatCalendarBloc({
    required String chatJid,
    required ChatType chatType,
    required ChatCalendarSyncCoordinator coordinator,
    required super.storage,
    super.reminderController,
  }) : super(
          storageId: chatCalendarStorageId(chatJid),
          syncManagerBuilder: (bloc) {
            coordinator.registerBloc(
              chatJid: chatJid,
              chatType: chatType,
              readModel: () => bloc.currentModel,
              applyModel: (CalendarModel model) async {
                if (bloc.isClosed) {
                  return;
                }
                bloc.add(
                  CalendarEvent.remoteModelApplied(model: model),
                );
              },
            );
            return coordinator.managerFor(
              chatJid: chatJid,
              chatType: chatType,
            );
          },
          onDispose: () => coordinator.unregisterBloc(chatJid: chatJid),
        );
}
