// ignore_for_file: avoid_print
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/duration_adapter.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_registry.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Table, Column;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart' hide BlocObserver;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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

  final baseStorage = await HydratedStorage.build(
    storageDirectory: await getApplicationDocumentsDirectory(),
  );
  final storageRegistry = CalendarStorageRegistry(fallback: baseStorage);
  final storageManager = CalendarStorageManager(registry: storageRegistry);
  HydratedBloc.storage = storageRegistry;

  await Hive.initFlutter();

  // Register adapters in consistent order to prevent typeId conflicts
  Hive.registerAdapter(DurationAdapter()); // typeId: 32
  Hive.registerAdapter(TaskPriorityAdapter()); // typeId: 31
  Hive.registerAdapter(CalendarTaskAdapter()); // typeId: 30
  Hive.registerAdapter(RecurrenceRuleAdapter()); // typeId: 34
  Hive.registerAdapter(RecurrenceFrequencyAdapter()); // typeId: 35
  Hive.registerAdapter(CalendarModelAdapter()); // typeId: 33

  print('Hive adapters registered successfully');

  // Handle corrupted calendar data from typeId issues
  Box<CalendarModel>? guestCalendarBox;
  try {
    guestCalendarBox = await Hive.openBox<CalendarModel>('guest_calendar');
  } catch (e) {
    // Handle any Hive error (typeId conflicts, unknown typeIds, corruption)
    print('Calendar data corruption detected: $e');
    print('Clearing corrupted calendar data...');

    try {
      await Hive.deleteBoxFromDisk('guest_calendar');
    } catch (deleteError) {
      print('Error deleting corrupted box: $deleteError');

      // Force clear by manually deleting Hive files
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final hiveDir = Directory(appDir.path);
        final guestCalendarFiles = hiveDir
            .listSync()
            .where((file) => file.path.contains('guest_calendar'))
            .toList();

        for (final file in guestCalendarFiles) {
          await file.delete();
          print('Deleted corrupted file: ${file.path}');
        }
      } catch (forceDeleteError) {
        print('Force delete failed: $forceDeleteError');
      }
    }

    guestCalendarBox = await Hive.openBox<CalendarModel>('guest_calendar');
    print('Calendar data reset complete');
  }

  // Initialize hydrated storage for the guest calendar, migrating legacy data
  final legacyModel = guestCalendarBox.get('calendar');
  await storageManager.ensureGuestStorage(legacyModel: legacyModel);

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
                storageManager: storageManager,
              ),
            ),
          )
        : Axichat(
            capability: capability,
            guestCalendarBox: guestCalendarBox,
            storageManager: storageManager,
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
