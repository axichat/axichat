// ignore_for_file: avoid_print

import 'package:axichat/src/calendar/storage/calendar_hive_adapters.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_registry.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Column, Table;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart' hide BlocObserver;
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';

bool withForeground = false;
final ValueNotifier<bool> foregroundServiceActive = ValueNotifier(false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _configureLogging();
  _registerThirdPartyLicenses();

  final storageDirectory = await getApplicationDocumentsDirectory();
  final baseStorage = await HydratedStorage.build(
    storageDirectory: storageDirectory,
  );
  final storageRegistry = CalendarStorageRegistry(fallback: baseStorage);
  final storageManager = CalendarStorageManager(registry: storageRegistry);
  HydratedBloc.storage = storageRegistry;

  await Hive.initFlutter();
  registerCalendarHiveAdapters();
  await storageManager.ensureGuestStorage();

  const capability = Capability();
  final notificationService = NotificationService();

  withForeground = capability.canForegroundService &&
      await notificationService.hasAllNotificationPermissions();
  foregroundServiceActive.value = withForeground;
  if (withForeground) {
    initForegroundService();
    await notificationService.init();
  }

  runApp(
    withForeground
        ? WithForegroundTask(
            child: Material(
              child: Axichat(
                notificationService: notificationService,
                capability: capability,
                storageManager: storageManager,
              ),
            ),
          )
        : Axichat(
            capability: capability,
            storageManager: storageManager,
          ),
  );
}

var _loggerConfigured = false;

void _configureLogging() {
  if (_loggerConfigured) return;
  _loggerConfigured = true;

  if (kDebugMode) {
    Logger.root
      ..level = Level.ALL
      ..onRecord.listen((record) {
        final buffer = StringBuffer()
          ..write('${record.level.name}: ${record.time}: ${record.message}');
        if (record.stackTrace != null) {
          buffer
            ..write(' Exception: ${record.error}')
            ..write(' Stack Trace: ${record.stackTrace}');
        }
        print(buffer.toString());
      });
    return;
  }

  Logger.root.level = Level.WARNING;
}

void _registerThirdPartyLicenses() {
  const deltaLicenseAsset = 'assets/licenses/delta_chat_core_mpl.txt';
  const notoColorEmojiLicenseAsset = 'assets/licenses/noto_color_emoji_ofl.txt';
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(deltaLicenseAsset);
    yield LicenseEntryWithLineBreaks(
      ['Delta Chat Core (MPL-2.0)'],
      text,
    );
  });
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(notoColorEmojiLicenseAsset);
    yield LicenseEntryWithLineBreaks(
      ['Noto Color Emoji (OFL-1.1)'],
      text,
    );
  });
}

class BlocLogger extends BlocObserver {
  final logger = Logger('Bloc');

  @override
  void onChange(BlocBase bloc, Change change) {
    // logger.info('${bloc.runtimeType} $change');
    super.onChange(bloc, change);
  }
}
