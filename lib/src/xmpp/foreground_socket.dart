// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/flavor_prefix.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide NotificationVisibility;
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const join = '::';
const connectPrefix = 'Connect';
const securePrefix = 'Secure';
const writePrefix = 'Write';
const closePrefix = 'Close';
const destroyPrefix = 'Destroy';
const dataPrefix = 'Data';
const socketErrorPrefix = 'XmppSocketErrorEvent';
const socketClosurePrefix = 'XmppSocketClosureEvent';
const emailKeepalivePrefix = 'EmailKeepalive';
const emailKeepaliveTickPrefix = 'EmailKeepaliveTick';
const emailKeepaliveStartCommand = 'Start';
const emailKeepaliveStopCommand = 'Stop';
const foregroundClientXmpp = 'xmpp_socket';
const foregroundClientEmailKeepalive = 'email_keepalive';
const _foregroundServiceId = 256;
const notificationTapPrefix = 'NotificationTap';

typedef ForegroundTaskMessageHandler = FutureOr<void> Function(String data);

class ForegroundServiceConfig {
  const ForegroundServiceConfig({
    required this.notificationTitle,
    required this.notificationText,
    required this.notificationIcon,
  });

  final String notificationTitle;
  final String notificationText;
  final NotificationIcon notificationIcon;
}

abstract class ForegroundTaskBridge {
  Future<void> acquire({
    required String clientId,
    ForegroundServiceConfig? config,
  });

  Future<void> release(String clientId);

  Future<void> send(List<Object> parts);

  void registerListener(
    String clientId,
    ForegroundTaskMessageHandler handler,
  );

  void unregisterListener(String clientId);
}

ForegroundTaskBridge _foregroundTaskBridge = FlutterForegroundTaskBridge();

ForegroundTaskBridge get foregroundTaskBridge => _foregroundTaskBridge;

@visibleForTesting
set foregroundTaskBridge(ForegroundTaskBridge bridge) {
  _foregroundTaskBridge = bridge;
}

class FlutterForegroundTaskBridge implements ForegroundTaskBridge {
  FlutterForegroundTaskBridge();

  final Map<String, int> _usageCounts = {};
  final Map<String, ForegroundTaskMessageHandler> _listeners = {};
  bool _callbackRegistered = false;
  Completer<void>? _startCompleter;

  int get _totalUsage =>
      _usageCounts.values.fold(0, (previous, element) => previous + element);

  @override
  void registerListener(
    String clientId,
    ForegroundTaskMessageHandler handler,
  ) {
    _listeners[clientId] = handler;
    if (_callbackRegistered) {
      return;
    }
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(_handleTaskData);
    _callbackRegistered = true;
  }

  @override
  void unregisterListener(String clientId) {
    _listeners.remove(clientId);
    if (_listeners.isEmpty && _totalUsage == 0) {
      _detachCallbackIfUnused();
    }
  }

  void _handleTaskData(dynamic data) {
    if (data is! String) {
      return;
    }
    for (final handler in List.of(_listeners.values)) {
      final result = handler(data);
      if (result is Future<void>) {
        unawaited(result);
      }
    }
  }

  @override
  Future<void> acquire({
    required String clientId,
    ForegroundServiceConfig? config,
  }) async {
    final totalBefore = _totalUsage;
    _usageCounts[clientId] = (_usageCounts[clientId] ?? 0) + 1;
    if (totalBefore > 0) {
      return;
    }
    try {
      await _startService(config ?? _defaultConfig());
    } on Exception {
      _decrementUsage(clientId);
      rethrow;
    }
  }

  @override
  Future<void> release(String clientId) async {
    _decrementUsage(clientId);
    if (_totalUsage == 0) {
      await _stopService();
    }
  }

  void _decrementUsage(String clientId) {
    final current = _usageCounts[clientId];
    if (current == null) {
      return;
    }
    if (current <= 1) {
      _usageCounts.remove(clientId);
    } else {
      _usageCounts[clientId] = current - 1;
    }
  }

  Future<void> _startService(ForegroundServiceConfig config) async {
    if (_startCompleter != null) {
      return _startCompleter!.future;
    }
    final completer = Completer<void>();
    _startCompleter = completer;
    initForegroundService();
    try {
      if (await FlutterForegroundTask.isRunningService) {
        completer.complete();
        return completer.future;
      }
      await _waitForResume();
      final result = await FlutterForegroundTask.startService(
        serviceId: _foregroundServiceId,
        notificationTitle: config.notificationTitle,
        notificationText: config.notificationText,
        notificationIcon: config.notificationIcon,
        callback: startCallback,
        notificationInitialRoute: '/',
      );
      if (result is! ServiceRequestSuccess) {
        if (_listeners.isEmpty) {
          _detachCallbackIfUnused();
        }
        final error = result is ServiceRequestFailure ? result.error : null;
        throw ForegroundServiceUnavailableException(
          error is Exception ? error : null,
        );
      }
      completer.complete();
    } on Exception catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _startCompleter = null;
    }
  }

  Future<void> _stopService() async {
    await FlutterForegroundTask.stopService();
    _detachCallbackIfUnused();
  }

  ForegroundServiceConfig _defaultConfig() => buildForegroundServiceConfig(
        notificationText: toBeginningOfSentenceCase(
              ConnectionState.connecting.name,
            ) ??
            ConnectionState.connecting.name,
      );

  @override
  Future<void> send(List<Object> parts) async {
    FlutterForegroundTask.sendDataToTask(parts.join(join));
  }

  void _detachCallbackIfUnused() {
    if (_callbackRegistered && _listeners.isEmpty) {
      FlutterForegroundTask.removeTaskDataCallback(_handleTaskData);
      _callbackRegistered = false;
    }
  }
}

Future<void> _waitForResume() async {
  final binding = WidgetsBinding.instance;
  final state = binding.lifecycleState;
  if (state == AppLifecycleState.resumed) {
    return;
  }
  final completer = Completer<void>();
  late final WidgetsBindingObserver observer;
  observer = _LifecycleResumeObserver(() {
    binding.removeObserver(observer);
    if (!completer.isCompleted) {
      completer.complete();
    }
  });
  binding.addObserver(observer);
  await completer.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      binding.removeObserver(observer);
    },
  );
}

class _LifecycleResumeObserver with WidgetsBindingObserver {
  _LifecycleResumeObserver(this.onResume);

  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}

ForegroundServiceConfig buildForegroundServiceConfig({
  required String notificationText,
}) =>
    ForegroundServiceConfig(
      notificationTitle: '${getFlavorPrefix()} Axichat Message Service',
      notificationText: notificationText,
      notificationIcon:
          const NotificationIcon(metaDataName: 'im.axi.axichat.APP_ICON'),
    );

bool launchedFromNotification = false;
String? _launchedNotificationChatJid;
var _notificationTapHandlerRegistered = false;

void recordNotificationLaunch(String? chatJid) {
  launchedFromNotification = true;
  _launchedNotificationChatJid = chatJid;
}

void ensureNotificationTapPortInitialized() {
  if (_notificationTapHandlerRegistered) {
    return;
  }
  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.addTaskDataCallback(_handleNotificationTapMessage);
  _notificationTapHandlerRegistered = true;
}

void _handleNotificationTapMessage(dynamic data) {
  if (data is! String || !data.startsWith('$notificationTapPrefix$join')) {
    return;
  }
  final payload = data.substring('$notificationTapPrefix$join'.length);
  recordNotificationLaunch(payload.isEmpty ? null : payload);
}

@pragma("vm:entry-point")
void notificationTapBackground(NotificationResponse notificationResponse) {
  recordNotificationLaunch(
    (notificationResponse.payload?.isEmpty ?? true)
        ? null
        : notificationResponse.payload,
  );
  FlutterForegroundTask.sendDataToMain([
    notificationTapPrefix,
    notificationResponse.payload ?? '',
  ].join(join));
}

String? takeLaunchedNotificationChatJid() {
  final payload = _launchedNotificationChatJid;
  _launchedNotificationChatJid = null;
  return payload;
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ForegroundSocket());
}

class ForegroundSocket extends TaskHandler {
  static final _log = Logger('ForegroundSocket');

  XmppSocketWrapper? _socket;
  late final StreamSubscription<String> _dataSubscription;
  late final StreamSubscription<mox.XmppSocketEvent> _eventSubscription;
  bool _emailKeepaliveEnabled = false;
  Duration _emailKeepaliveInterval = const Duration(seconds: 45);
  DateTime? _nextEmailKeepalive;

  static void _sendToMain(List<Object> strings) {
    final data = strings.join(join);
    final type = strings.isEmpty ? 'Unknown' : strings.first.toString();
    final payloadLength = strings
        .skip(1)
        .fold<int>(0, (sum, part) => sum + part.toString().length);
    _log.fine(
      'Sending to main: type=$type parts=${strings.length} '
      'payloadLen=$payloadLength',
    );
    FlutterForegroundTask.sendDataToMain(data);
  }

  static void _onData(String data) => _sendToMain([dataPrefix, data]);

  static void _onEvent(mox.XmppSocketEvent event) {
    if (event is mox.XmppSocketErrorEvent) {
      return _sendToMain([socketErrorPrefix]);
    }
    if (event is mox.XmppSocketClosureEvent) {
      return _sendToMain([socketClosurePrefix, event.expected]);
    }
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();

    _configureLogging();

    _log.fine('onStart called.');
    _socket ??= XmppSocketWrapper();
    _dataSubscription = _socket!.getDataStream().listen(_onData);
    _eventSubscription = _socket!.getEventStream().listen(_onEvent);
  }

  @override
  void onReceiveData(covariant String data) async {
    final separatorIndex = data.indexOf(join);
    final type =
        separatorIndex == -1 ? data : data.substring(0, separatorIndex);
    final payloadLength =
        separatorIndex == -1 ? 0 : data.length - separatorIndex - join.length;
    _log.fine('Received task: type=$type payloadLen=$payloadLength');
    _socket ??= XmppSocketWrapper();
    if (data.startsWith('$connectPrefix$join')) {
      final split = data.split(join);
      final host = split.length > 2 && split[2].isNotEmpty ? split[2] : null;
      final port = split.length > 3 && split[3].isNotEmpty
          ? int.tryParse(split[3])
          : null;
      final result = await _socket!.connect(
        split[1],
        host: host,
        port: port,
      );
      return _sendToMain([connectPrefix, result]);
    } else if (data.startsWith('$securePrefix$join')) {
      final domain = data.substring('$securePrefix$join'.length);
      final result = await _socket!.secure(domain);
      return _sendToMain([securePrefix, result]);
    } else if (data.startsWith('$writePrefix$join')) {
      return _socket?.write(data.substring('$writePrefix$join'.length));
    } else if (data.startsWith('$closePrefix$join')) {
      return _socket?.close();
    } else if (data.startsWith('$emailKeepalivePrefix$join')) {
      _handleEmailKeepaliveCommand(
        data.substring('$emailKeepalivePrefix$join'.length),
      );
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _maybeEmitEmailKeepalive(timestamp);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, _) async {
    _socket?.close();
    _socket = null;
    await _dataSubscription.cancel();
    await _eventSubscription.cancel();
    _emailKeepaliveEnabled = false;
    _nextEmailKeepalive = null;
  }

  void _handleEmailKeepaliveCommand(String payload) {
    final parts = payload.split(join);
    if (parts.isEmpty) {
      return;
    }
    switch (parts.first) {
      case emailKeepaliveStartCommand:
        final intervalMs = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
        _emailKeepaliveInterval = intervalMs > 0
            ? Duration(milliseconds: intervalMs)
            : const Duration(seconds: 45);
        _emailKeepaliveEnabled = true;
        final now = DateTime.now();
        _nextEmailKeepalive = now.add(_emailKeepaliveInterval);
        _emitEmailKeepaliveTick();
        break;
      case emailKeepaliveStopCommand:
        _emailKeepaliveEnabled = false;
        _nextEmailKeepalive = null;
        break;
    }
  }

  void _maybeEmitEmailKeepalive(DateTime timestamp) {
    if (!_emailKeepaliveEnabled) {
      return;
    }
    final nextTick = _nextEmailKeepalive;
    if (nextTick == null || !timestamp.isBefore(nextTick)) {
      _emitEmailKeepaliveTick();
      _nextEmailKeepalive = timestamp.add(_emailKeepaliveInterval);
    }
  }

  void _emitEmailKeepaliveTick() {
    _sendToMain([
      emailKeepaliveTickPrefix,
      DateTime.now().millisecondsSinceEpoch,
    ]);
  }
}

class ForegroundSocketWrapper implements XmppSocketWrapper {
  ForegroundSocketWrapper({ForegroundTaskBridge? bridge})
      : _bridge = bridge ?? foregroundTaskBridge;

  static final _log = Logger('ForegroundSocketWrapper');
  final ForegroundTaskBridge _bridge;
  final StreamController<String> _dataStream = StreamController.broadcast();
  final StreamController<mox.XmppSocketEvent> _eventStream =
      StreamController.broadcast();

  var _connect = Completer<bool>();
  var _secure = Completer<bool>();
  var _secureResult = false;
  var _listenerRegistered = false;
  var _serviceAcquired = false;

  Future<void> _onReceiveTaskData(String data) async {
    final separatorIndex = data.indexOf(join);
    final type =
        separatorIndex == -1 ? data : data.substring(0, separatorIndex);
    final payloadLength =
        separatorIndex == -1 ? 0 : data.length - separatorIndex - join.length;
    _log.fine('Received main: type=$type payloadLen=$payloadLength');
    if (data.startsWith('$dataPrefix$join')) {
      _dataStream.add(data.substring('$dataPrefix$join'.length));
    } else if (data == socketErrorPrefix) {
      _eventStream.add(mox.XmppSocketErrorEvent(''));
    } else if (data.startsWith('$socketClosurePrefix$join')) {
      _eventStream.add(
        mox.XmppSocketClosureEvent(_boolFromPayload(data)),
      );
    } else if (data.startsWith('$connectPrefix$join')) {
      _completeConnect(_boolFromPayload(data));
    } else if (data.startsWith('$securePrefix$join')) {
      _completeSecure(_boolFromPayload(data));
    }
  }

  bool _boolFromPayload(String data) {
    final parts = data.split(join);
    if (parts.length < 2) return false;
    return parts[1].toLowerCase() == 'true';
  }

  void _completeConnect(bool connected) {
    if (_connect.isCompleted) return;
    _connect.complete(connected);
  }

  void _completeSecure(bool secure) {
    _secureResult = secure;
    if (_secure.isCompleted) return;
    _secure.complete(secure);
  }

  void _sendToTask(List<Object> strings) {
    final type = strings.isEmpty ? 'Unknown' : strings.first.toString();
    final payloadLength = strings
        .skip(1)
        .fold<int>(0, (sum, part) => sum + part.toString().length);
    _log.info(
      'Sending to task: type=$type parts=${strings.length} '
      'payloadLen=$payloadLength',
    );
    unawaited(_bridge.send(strings));
  }

  @override
  bool isSecure() => _secureResult;

  @override
  bool managesKeepalives() => false;

  @override
  Stream<String> getDataStream() => _dataStream.stream;

  @override
  Stream<mox.XmppSocketEvent> getEventStream() => _eventStream.stream;

  @override
  bool onBadCertificate(certificate, String domain) => false;

  @override
  Future<bool> secure(String domain) {
    _sendToTask([securePrefix, domain]);
    return _secure.future;
  }

  @override
  bool whitespacePingAllowed() => true;

  @override
  Future<bool> connect(String domain, {String? host, int? port}) async {
    await reset();

    final target = _resolveTarget(
      domain,
      host: host,
      port: port,
    );
    if (target == null) {
      return false;
    }

    if (!_listenerRegistered) {
      _bridge.registerListener(
        foregroundClientXmpp,
        _onReceiveTaskData,
      );
      _listenerRegistered = true;
    }

    final notificationText = toBeginningOfSentenceCase(
      ConnectionState.connecting.name,
    );

    try {
      await _bridge.acquire(
        clientId: foregroundClientXmpp,
        config: buildForegroundServiceConfig(
          notificationText: notificationText,
        ),
      );
      _serviceAcquired = true;
    } on Exception {
      _detachListener();
      rethrow;
    }

    _sendToTask([
      connectPrefix,
      domain,
      target.host,
      target.port,
    ]);
    return _connect.future;
  }

  _SocketTarget? _resolveTarget(
    String domain, {
    String? host,
    int? port,
  }) {
    final overrideHost = host;
    final hasOverride = overrideHost != null && overrideHost.isNotEmpty;
    if (hasOverride) {
      return _SocketTarget(overrideHost, port ?? 5222);
    }

    final mapping = serverLookup[domain];
    if (mapping == null) {
      _log.severe(
        'No static server mapping and no host override provided. DNS lookups are disabled.',
      );
      return null;
    }

    return _SocketTarget(mapping.host, port ?? mapping.port);
  }

  @override
  void write(String data) {
    _sendToTask([writePrefix, data]);
  }

  Future<void> updateConnectionState(ConnectionState state) async {
    await FlutterForegroundTask.updateService(
      notificationText: toBeginningOfSentenceCase(state.name),
    );
  }

  @override
  void close() {
    _sendToTask([closePrefix]);
  }

  @override
  void destroy() {
    _sendToTask([destroyPrefix]);
  }

  @override
  void prepareDisconnect() {}

  Future<void> reset() async {
    _connect = Completer<bool>();
    _secure = Completer<bool>();
    _secureResult = false;
    await _releaseService();
    _detachListener();
  }

  Future<void> _releaseService() async {
    if (!_serviceAcquired) {
      return;
    }
    await _bridge.release(foregroundClientXmpp);
    _serviceAcquired = false;
  }

  void _detachListener() {
    if (!_listenerRegistered) {
      return;
    }
    _bridge.unregisterListener(foregroundClientXmpp);
    _listenerRegistered = false;
  }
}

class _SocketTarget {
  const _SocketTarget(this.host, this.port);

  final String host;
  final int port;
}

var _foregroundLoggerConfigured = false;

void _configureLogging() {
  if (_foregroundLoggerConfigured) return;
  _foregroundLoggerConfigured = true;

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
        // ignore: avoid_print
        print(buffer.toString());
      });
    return;
  }

  Logger.root.level = Level.WARNING;
}

void initForegroundService() => FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Foreground Service Notification',
        channelDescription:
            'This notification appears when the foreground service is running.',
        visibility: NotificationVisibility.VISIBILITY_PRIVATE,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
