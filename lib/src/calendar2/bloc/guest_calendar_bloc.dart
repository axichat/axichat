import '../storage/guest_calendar_storage.dart';
import 'calendar_bloc.dart';

class GuestCalendarBloc extends CalendarBloc {
  GuestCalendarBloc({required super.storage});

  static Future<GuestCalendarBloc> create() async {
    final storage = await buildGuestCalendarStorage();
    return GuestCalendarBloc(storage: storage);
  }
}
