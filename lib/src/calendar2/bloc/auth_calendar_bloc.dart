import '../storage/auth_calendar_storage.dart';
import 'calendar_bloc.dart';

class AuthCalendarBloc extends CalendarBloc {
  AuthCalendarBloc({required super.storage});

  static Future<AuthCalendarBloc> create(
      {required List<int> encryptionKey}) async {
    final storage =
        await buildAuthCalendarStorage(encryptionKey: encryptionKey);
    return AuthCalendarBloc(storage: storage);
  }
}
