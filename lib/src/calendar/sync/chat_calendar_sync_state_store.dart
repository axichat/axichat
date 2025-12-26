import 'package:axichat/src/calendar/sync/calendar_sync_state.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_identifiers.dart';
import 'package:axichat/src/storage/state_store.dart';

class ChatCalendarSyncStateStore {
  const ChatCalendarSyncStateStore();

  CalendarSyncState read(String chatJid) {
    final raw = XmppStateStore().read(key: _stateKey(chatJid));
    if (raw == null || raw is! String) {
      return const CalendarSyncState();
    }
    try {
      return CalendarSyncState.fromJson(raw);
    } on FormatException {
      return const CalendarSyncState();
    }
  }

  Future<void> write(String chatJid, CalendarSyncState state) async {
    await XmppStateStore().write(
      key: _stateKey(chatJid),
      value: state.toJson(),
    );
  }

  RegisteredStateKey _stateKey(String chatJid) {
    return XmppStateStore.registerKey(chatCalendarSyncStateKey(chatJid));
  }
}
