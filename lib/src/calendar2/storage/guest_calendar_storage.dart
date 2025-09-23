import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:hive/hive.dart';

import 'calendar_storage.dart';

/// Builds an unencrypted Hydrated [Storage] instance for the guest calendar.
Future<Storage> buildGuestCalendarStorage({HiveInterface? hive}) async {
  return Calendar2HydratedStorage.open(
    boxName: 'calendar2_guest',
    keyPrefix: 'guest',
    hive: hive,
  );
}
