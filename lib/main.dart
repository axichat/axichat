// ignore_for_file: avoid_print
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:bloc/bloc.dart';
import 'package:chat/src/common/capability.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Table, Column;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart' hide BlocObserver;
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';

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

  if (capability.canForegroundService) {
    FlutterForegroundTask.initCommunicationPort();
  }

  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelGroupKey: 'basic_channel_group',
        channelKey: 'basic_channel',
        channelName: 'Basic notifications',
        channelDescription: 'Message notifications',
        defaultColor: const Color(0xFF9D50DD),
        ledColor: Colors.white,
      )
    ],
    channelGroups: [
      NotificationChannelGroup(
        channelGroupKey: 'basic_channel_group',
        channelGroupName: 'Basic group',
      )
    ],
  );

  runApp(capability.canForegroundService
      ? const WithForegroundTask(
          child: Material(child: Axichat(capability: capability)))
      : const Axichat(capability: capability));
}

class BlocLogger extends BlocObserver {
  final logger = Logger('Bloc');

  @override
  void onChange(BlocBase bloc, Change change) {
    // logger.info('${bloc.runtimeType} $change');
    super.onChange(bloc, change);
  }
}
