// ignore_for_file: avoid_print
import 'package:bloc/bloc.dart';
import 'package:chat/src/common/capability.dart';
import 'package:chat/src/notifications/bloc/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Table, Column;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart' hide BlocObserver;
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';

late final bool withForeground;

void main() async {
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

  const capability = Capability();
  const notificationService = NotificationService();

  withForeground = capability.canForegroundService &&
      await notificationService.hasAllNotificationPermissions();
  if (withForeground) {
    notificationService.init();
  }

  runApp(
    withForeground
        ? const WithForegroundTask(
            child: Material(
              child: Axichat(
                notificationService: notificationService,
                capability: capability,
              ),
            ),
          )
        : const Axichat(capability: capability),
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
