import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/storage/calendar_state_storage_codec.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_identifiers.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

class ChatCalendarStorage {
  ChatCalendarStorage({
    Storage? storage,
    String? storagePrefix,
  })  : _storage = storage ?? HydratedBloc.storage,
        _storagePrefix = storagePrefix ?? authStoragePrefix;

  final Storage _storage;
  final String _storagePrefix;

  CalendarModel readModel(String chatJid) {
    final CalendarState? state = readState(chatJid);
    return state?.model ?? CalendarModel.empty();
  }

  CalendarState? readState(String chatJid) {
    final raw = _storage.read(_storageToken(chatJid));
    if (raw is! Map) {
      return null;
    }
    return CalendarStateStorageCodec.decode(
      Map<String, dynamic>.from(raw),
    );
  }

  Future<void> writeModel(String chatJid, CalendarModel model) async {
    final CalendarState base = readState(chatJid) ?? CalendarState.initial();
    final CalendarState updated = base.copyWith(model: model);
    await writeState(chatJid, updated);
  }

  Future<void> writeState(String chatJid, CalendarState state) async {
    final encoded = CalendarStateStorageCodec.encode(state);
    if (encoded == null) {
      return;
    }
    await _storage.write(_storageToken(chatJid), encoded);
  }

  String _storageToken(String chatJid) {
    return '$_storagePrefix${chatCalendarStorageId(chatJid)}';
  }
}
