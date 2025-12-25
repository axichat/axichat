// ignore_for_file: avoid_print

import 'dart:ui' as ui;

import 'package:axichat/src/calendar/storage/calendar_hive_adapters.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_registry.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/common/startup/auth_bootstrap.dart';
import 'package:axichat/src/common/startup/first_frame_gate.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
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
  final binding = WidgetsFlutterBinding.ensureInitialized();
  firstFrameGate.defer(binding);
  _installKeyboardGuard();

  const capability = Capability();
  const policy = Policy();
  final credentialStore = CredentialStore(
    capability: capability,
    policy: policy,
  );
  final storedCredentialsFuture =
      resolveHasStoredLoginCredentials(credentialStore);

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

  final notificationService = NotificationService();
  await notificationService.init();

  withForeground = capability.canForegroundService &&
      await notificationService.hasAllNotificationPermissions();
  foregroundServiceActive.value = withForeground;
  if (withForeground) {
    initForegroundService();
  }

  final hasStoredLoginCredentials = await storedCredentialsFuture;
  final authBootstrap =
      AuthBootstrap(hasStoredLoginCredentials: hasStoredLoginCredentials);
  final app = withForeground
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
          notificationService: notificationService,
          capability: capability,
          storageManager: storageManager,
        );

  runApp(
    RepositoryProvider.value(
      value: authBootstrap,
      child: app,
    ),
  );
  firstFrameGate.allow();
}

var _loggerConfigured = false;

void _configureLogging() {
  if (_loggerConfigured) return;
  _loggerConfigured = true;

  if (kDebugMode) {
    Logger.root
      ..level = Level.ALL
      ..onRecord.listen((record) {
        final sanitizedMessage = SafeLogging.sanitizeMessage(record.message);
        final sanitizedError = SafeLogging.sanitizeError(record.error);
        final sanitizedStackTrace =
            SafeLogging.sanitizeStackTrace(record.stackTrace);
        final buffer = StringBuffer()
          ..write(
            '${record.level.name}: ${record.time}: $sanitizedMessage',
          );
        if (record.stackTrace != null) {
          buffer
            ..write(' Exception: $sanitizedError')
            ..write(' Stack Trace: $sanitizedStackTrace');
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
  const interLicenseAsset = 'assets/licenses/inter_ofl.txt';
  const dmSansLicenseAsset = 'assets/licenses/dmsans_ofl.txt';
  const gabaritoLicenseAsset = 'assets/licenses/gabarito_ofl.txt';
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
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(interLicenseAsset);
    yield LicenseEntryWithLineBreaks(
      ['Inter (OFL-1.1)'],
      text,
    );
  });
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(dmSansLicenseAsset);
    yield LicenseEntryWithLineBreaks(
      ['DM Sans (OFL-1.1)'],
      text,
    );
  });
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(gabaritoLicenseAsset);
    yield LicenseEntryWithLineBreaks(
      ['Gabarito (OFL-1.1)'],
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

const String _rawKeyHandledResponseKey = 'handled';
const bool _keyEventNotHandled = false;
const Set<ui.KeyEventType> _guardedKeyDataTypes = {
  ui.KeyEventType.up,
  ui.KeyEventType.repeat,
};
const Map<String, dynamic> _rawKeyNotHandledResponse = <String, dynamic>{
  _rawKeyHandledResponseKey: _keyEventNotHandled,
};

enum _KeyboardTransitMode {
  rawKeyData,
  keyDataThenRawKeyData;

  bool get isRawKeyData => this == _KeyboardTransitMode.rawKeyData;

  bool get isKeyDataThenRawKeyData =>
      this == _KeyboardTransitMode.keyDataThenRawKeyData;
}

// ignore: deprecated_member_use
KeyEventManager? _keyboardGuardKeyEventManager;
_KeyboardTransitMode? _keyboardTransitMode;

bool _shouldIgnoreKeyData(ui.KeyData data) {
  final bool isGuardedType = _guardedKeyDataTypes.contains(data.type);
  final PhysicalKeyboardKey key = PhysicalKeyboardKey(data.physical);
  final bool isPressed =
      HardwareKeyboard.instance.physicalKeysPressed.contains(key);
  return isGuardedType && !isPressed;
}

// ignore: deprecated_member_use
bool _shouldIgnoreRawKeyEvent(RawKeyEvent rawEvent) {
  // ignore: deprecated_member_use
  final bool isUpEvent = rawEvent is RawKeyUpEvent;
  // ignore: deprecated_member_use
  final bool isRepeatDownEvent = rawEvent is RawKeyDownEvent && rawEvent.repeat;
  final bool isRepeatOrUp = isUpEvent || isRepeatDownEvent;
  final PhysicalKeyboardKey key = rawEvent.physicalKey;
  final bool isPressed =
      HardwareKeyboard.instance.physicalKeysPressed.contains(key);
  return isRepeatOrUp && !isPressed;
}

bool _handleGuardedKeyData(ui.KeyData data) {
  // ignore: deprecated_member_use
  final KeyEventManager? keyEventManager = _keyboardGuardKeyEventManager;
  if (keyEventManager == null) {
    return _keyEventNotHandled;
  }
  final bool isRawMode =
      _keyboardTransitMode?.isRawKeyData ?? _keyEventNotHandled;
  if (isRawMode || _shouldIgnoreKeyData(data)) {
    return _keyEventNotHandled;
  }
  _keyboardTransitMode ??= _KeyboardTransitMode.keyDataThenRawKeyData;
  // ignore: deprecated_member_use
  return keyEventManager.handleKeyData(data);
}

Future<Map<String, dynamic>> _handleGuardedRawKeyMessage(
  dynamic message,
) async {
  // ignore: deprecated_member_use
  final KeyEventManager? keyEventManager = _keyboardGuardKeyEventManager;
  if (keyEventManager == null) {
    return _rawKeyNotHandledResponse;
  }
  final Map<String, dynamic> rawMessage = message as Map<String, dynamic>;
  // ignore: deprecated_member_use
  final RawKeyEvent rawEvent = RawKeyEvent.fromMessage(rawMessage);
  if (_shouldIgnoreRawKeyEvent(rawEvent)) {
    return _rawKeyNotHandledResponse;
  }
  _keyboardTransitMode ??= _KeyboardTransitMode.rawKeyData;
  // ignore: deprecated_member_use
  return keyEventManager.handleRawKeyMessage(rawMessage);
}

void _installKeyboardGuard() {
  final ServicesBinding servicesBinding = ServicesBinding.instance;
  final ui.PlatformDispatcher dispatcher = servicesBinding.platformDispatcher;
  // ignore: deprecated_member_use
  final KeyEventManager keyEventManager = servicesBinding.keyEventManager;
  _keyboardGuardKeyEventManager = keyEventManager;
  dispatcher.onKeyData = _handleGuardedKeyData;
  SystemChannels.keyEvent.setMessageHandler(_handleGuardedRawKeyMessage);
}
