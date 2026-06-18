// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:axichat/src/calendar/storage/calendar_hive_adapters.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_registry.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/network_availability.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/common/startup/auth_bootstrap.dart';
import 'package:axichat/src/common/startup/first_frame_gate.dart';
import 'package:axichat/src/common/ui/ui.dart' show compactDeviceBreakpoint;
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/storage/app_storage.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Column, Table;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart' hide BlocObserver;
import 'package:logging/logging.dart';

import 'src/app.dart';

bool withForeground = false;
final ValueNotifier<bool> foregroundServiceActive = ValueNotifier(false);

Future<void> main(List<String> args) async {
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  _configureLogging();
  _installProfileErrorLogging();
  firstFrameGate.defer(binding);
  await _applyPhoneOrientationPolicy(binding.platformDispatcher.views);
  _installKeyboardGuard();
  await NetworkAvailabilityService.instance.start();

  const capability = Capability();
  const policy = Policy();
  final CredentialStore credentialStore = CredentialStore(
    capability: capability,
    policy: policy,
  );
  final Future<bool> storedCredentialsFuture = resolveHasStoredLoginCredentials(
    credentialStore,
  );

  _registerThirdPartyLicenses();

  final NotificationService notificationService = NotificationService();
  final Future<void> notificationInitFuture = notificationService.init();

  final Future<Directory> storageDirectoryFuture = prepareAppStorageDirectory();
  const bool isWeb = kIsWeb;

  final Directory storageDirectory = await storageDirectoryFuture;
  final HydratedStorage baseStorage = await HydratedStorage.build(
    storageDirectory: isWeb
        ? HydratedStorageDirectory.web
        : HydratedStorageDirectory(storageDirectory.path),
  );
  final Future<void> hiveInitFuture = () async {
    final String storagePath = storageDirectory.path;
    if (isWeb) {
      await Hive.initFlutter();
      return;
    }
    Hive.init(storagePath);
  }();
  final CalendarStorageRegistry storageRegistry = CalendarStorageRegistry(
    fallback: baseStorage,
  );
  final CalendarStorageManager storageManager = CalendarStorageManager(
    registry: storageRegistry,
  );
  HydratedBloc.storage = storageRegistry;

  await hiveInitFuture;
  registerCalendarHiveAdapters();
  await storageManager.ensureGuestStorage();

  await notificationInitFuture;

  final bool hasStoredLoginCredentials = await storedCredentialsFuture;
  final AuthBootstrap authBootstrap = AuthBootstrap(
    hasStoredLoginCredentials: hasStoredLoginCredentials,
  );
  _installFrameTimingLogger(binding);
  _installEventLoopDriftLogger(binding);
  final Widget app = _PhoneOrientationPolicy(
    child: capability.canForegroundService
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
          ),
  );

  runApp(RepositoryProvider.value(value: authBootstrap, child: app));
  firstFrameGate.allow();
}

class _PhoneOrientationPolicy extends StatefulWidget {
  const _PhoneOrientationPolicy({required this.child});

  final Widget child;

  @override
  State<_PhoneOrientationPolicy> createState() =>
      _PhoneOrientationPolicyState();
}

class _PhoneOrientationPolicyState extends State<_PhoneOrientationPolicy>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apply();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _apply();
  }

  void _apply() {
    unawaited(
      _applyPhoneOrientationPolicy(
        WidgetsBinding.instance.platformDispatcher.views,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

Future<void> _applyPhoneOrientationPolicy(
  Iterable<ui.FlutterView> views,
) async {
  if (kIsWeb || !_supportsPhoneOrientationLock(defaultTargetPlatform)) {
    return;
  }
  ui.Display? display;
  for (final view in views) {
    display = view.display;
    break;
  }
  if (display == null) {
    return;
  }
  await SystemChrome.setPreferredOrientations(
    _isPhoneDisplay(display)
        ? const <DeviceOrientation>[DeviceOrientation.portraitUp]
        : const <DeviceOrientation>[],
  );
}

bool _supportsPhoneOrientationLock(TargetPlatform platform) {
  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}

bool _isPhoneDisplay(ui.Display display) {
  final logicalSize = Size(
    display.size.width / display.devicePixelRatio,
    display.size.height / display.devicePixelRatio,
  );
  return logicalSize.shortestSide < compactDeviceBreakpoint;
}

var _loggerConfigured = false;
var _profileErrorLoggingInstalled = false;

void _configureLogging() {
  if (_loggerConfigured) return;
  _loggerConfigured = true;

  SafeLogging.setVerboseXmppTraffic(enabled: kDebugMode);
  SafeLogging.setRawXmppTraffic(enabled: kDebugMode);

  if (kDebugMode) {
    Logger.root
      ..level = Level.ALL
      ..onRecord.listen((record) {
        if (!SafeLogging.shouldEmitDebugRecord(record)) {
          return;
        }
        print(SafeLogging.formatRecord(record));
      });
    return;
  }

  if (kProfileMode) {
    Logger.root
      ..level = Level.ALL
      ..onRecord.listen((record) {
        if (!SafeLogging.shouldEmitProfileRecord(record)) {
          return;
        }
        print(SafeLogging.formatRecord(record));
      });
    return;
  }

  Logger.root.level = Level.OFF;
}

void _installProfileErrorLogging() {
  if (!kProfileMode || _profileErrorLoggingInstalled) {
    return;
  }
  _profileErrorLoggingInstalled = true;
  final log = Logger('ProfileErrors');
  final previousFlutterErrorOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    log.severe(
      'Flutter framework error: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
    if (previousFlutterErrorOnError != null) {
      previousFlutterErrorOnError(details);
      return;
    }
    FlutterError.presentError(details);
  };
  final previousPlatformDispatcherOnError =
      ui.PlatformDispatcher.instance.onError;
  ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
    log.severe('Uncaught platform error: $error', error, stackTrace);
    return previousPlatformDispatcherOnError?.call(error, stackTrace) ?? false;
  };
}

void _installFrameTimingLogger(WidgetsBinding binding) {
  if (!kProfileMode) {
    return;
  }
  final log = Logger(SafeLogging.profileFrameTimingLoggerName);
  var lastSlowReport = DateTime.fromMillisecondsSinceEpoch(0);
  binding.addTimingsCallback((timings) {
    final now = DateTime.now();
    final slowTimings = timings
        .where(_isSlowFrameTiming)
        .toList(growable: false);
    if (slowTimings.isEmpty) {
      return;
    }
    if (now.difference(lastSlowReport) < const Duration(seconds: 2)) {
      return;
    }
    lastSlowReport = now;
    final worst = slowTimings.reduce(
      (current, next) => current.totalSpan >= next.totalSpan ? current : next,
    );
    log.warning(
      'Slow frame batch count=${slowTimings.length} '
      'worstTotal=${_formatFrameDuration(worst.totalSpan)} '
      'build=${_formatFrameDuration(worst.buildDuration)} '
      'raster=${_formatFrameDuration(worst.rasterDuration)} '
      'vsync=${_formatFrameDuration(worst.vsyncOverhead)} '
      'estimatedDroppedFrames=${_estimatedDroppedFrames(worst.totalSpan)}',
    );
  });
}

void _installEventLoopDriftLogger(WidgetsBinding binding) {
  if (!kProfileMode) {
    return;
  }
  const interval = Duration(seconds: 1);
  const threshold = Duration(milliseconds: 250);
  const throttle = Duration(seconds: 2);
  var expected = DateTime.timestamp().add(interval);
  var lastReport = DateTime.fromMillisecondsSinceEpoch(0);
  Timer.periodic(interval, (_) {
    final now = DateTime.timestamp();
    final drift = now.difference(expected);
    expected = now.add(interval);
    if (drift < threshold || now.difference(lastReport) < throttle) {
      return;
    }
    lastReport = now;
    SafeLogging.profileTrace(
      'app.eventLoopDrift',
      'lag',
      fields: <String, Object?>{
        'driftMs': drift.inMilliseconds,
        'schedulerPhase': binding.schedulerPhase.name,
        'transientCallbackCount': binding.transientCallbackCount,
      },
    );
  });
}

bool _isSlowFrameTiming(ui.FrameTiming timing) =>
    timing.totalSpan >= const Duration(milliseconds: 100) ||
    timing.buildDuration >= const Duration(milliseconds: 50) ||
    timing.rasterDuration >= const Duration(milliseconds: 50);

int _estimatedDroppedFrames(Duration frameSpan) {
  const frameBudget = Duration(microseconds: 16667);
  final occupiedFrames =
      (frameSpan.inMicroseconds + frameBudget.inMicroseconds - 1) ~/
      frameBudget.inMicroseconds;
  if (occupiedFrames <= 1) {
    return 0;
  }
  return occupiedFrames - 1;
}

String _formatFrameDuration(Duration duration) =>
    '${(duration.inMicroseconds / Duration.microsecondsPerMillisecond).toStringAsFixed(1)}ms';

void _registerThirdPartyLicenses() {
  const deltaLicenseAsset = 'assets/licenses/delta_chat_core_mpl.txt';
  const notoColorEmojiLicenseAsset = 'assets/licenses/noto_color_emoji_ofl.txt';
  const interLicenseAsset = 'assets/licenses/inter_ofl.txt';
  const dmSansLicenseAsset = 'assets/licenses/dmsans_ofl.txt';
  const flutterLicenseAsset = 'assets/licenses/flutter_bsd.txt';
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(deltaLicenseAsset);
    yield LicenseEntryWithLineBreaks(['Delta Chat Core (MPL-2.0)'], text);
  });
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(notoColorEmojiLicenseAsset);
    yield LicenseEntryWithLineBreaks(['Noto Color Emoji (OFL-1.1)'], text);
  });
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(interLicenseAsset);
    yield LicenseEntryWithLineBreaks(['Inter (OFL-1.1)'], text);
  });
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(dmSansLicenseAsset);
    yield LicenseEntryWithLineBreaks(['DM Sans (OFL-1.1)'], text);
  });
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(flutterLicenseAsset);
    yield LicenseEntryWithLineBreaks([
      'Flutter BSD-3-Clause (local source adaptations)',
    ], text);
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
  final bool isPressed = HardwareKeyboard.instance.physicalKeysPressed.contains(
    key,
  );
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
  final bool isPressed = HardwareKeyboard.instance.physicalKeysPressed.contains(
    key,
  );
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
