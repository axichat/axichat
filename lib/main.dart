// ignore_for_file: avoid_print
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/duration_adapter.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Table, Column;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart' hide BlocObserver;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';

late final bool withForeground;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(
    (record) => kDebugMode
        ? print('${record.level.name}: ${record.time}: ${record.message}'
            '${record.stackTrace != null ? 'Exception: ${record.error} ' 'Stack Trace: ${record.stackTrace}' : ''}')
        : null,
  );

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: await getApplicationDocumentsDirectory(),
  );

  await Hive.initFlutter();
  Hive.registerAdapter(DurationAdapter());
  Hive.registerAdapter(CalendarTaskAdapter());
  Hive.registerAdapter(CalendarModelAdapter());
  final guestCalendarBox = await Hive.openBox<CalendarModel>('guest_calendar');

  const capability = Capability();
  final notificationService = NotificationService();

  withForeground = capability.canForegroundService &&
      await notificationService.hasAllNotificationPermissions();
  if (withForeground) {
    await notificationService.init();
  }

  runApp(
    withForeground
        ? WithForegroundTask(
            child: Material(
              child: Axichat(
                notificationService: notificationService,
                capability: capability,
                guestCalendarBox: guestCalendarBox,
              ),
            ),
          )
        : Axichat(
            capability: capability,
            guestCalendarBox: guestCalendarBox,
          ),
  );
}

class BlocLogger extends BlocObserver {
  final logger = Logger('Bloc');

  @override
  void onChange(BlocBase bloc, Change change) {
    // logger.info('${bloc.runtimeType} $change');
    super.onChange(bloc, change);
  }
}
