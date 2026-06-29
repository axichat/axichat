// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/flavor_prefix.dart';
import 'package:axichat/src/common/foreground_notification_snapshot.dart';
import 'package:axichat/src/common/foreground_task_messages.dart';
import 'package:axichat/src/common/notification_privacy.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/common/xml_safety.dart';
import 'package:axichat/src/notifications/notification_payload.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as local_notifications;
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:xml/xml.dart' as xml;

const join = foregroundTaskMessageSeparator;
const connectPrefix = 'Connect';
const securePrefix = 'Secure';
const String _foregroundSocketSendOperationName = 'ForegroundSocket.sendToTask';
const writePrefix = 'Write';
const closePrefix = 'Close';
const destroyPrefix = 'Destroy';
const dataPrefix = 'Data';
const mainAliveProbePrefix = 'MainAliveProbe';
const mainAliveAckPrefix = 'MainAliveAck';
const socketErrorPrefix = 'XmppSocketErrorEvent';
const socketClosurePrefix = 'XmppSocketClosureEvent';
const taskReadyPrefix = 'ForegroundTaskReady';
const foregroundClientXmpp = 'xmpp_socket';
const _foregroundServiceId = 256;

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

  Future<bool> stopIfRunning();

  Future<bool> isRunning();

  Future<void> send(List<Object> parts);

  void registerListener(String clientId, ForegroundTaskMessageHandler handler);

  void unregisterListener(String clientId);
}

ForegroundTaskBridge _foregroundTaskBridge = FlutterForegroundTaskBridge();

ForegroundTaskBridge get foregroundTaskBridge => _foregroundTaskBridge;

@visibleForTesting
set foregroundTaskBridge(ForegroundTaskBridge bridge) {
  _foregroundTaskBridge = bridge;
}

final _foregroundNotificationShownController =
    StreamController<List<String>>.broadcast(sync: true);

Stream<List<String>> get foregroundNotificationShownStream =>
    _foregroundNotificationShownController.stream;

class FlutterForegroundTaskBridge implements ForegroundTaskBridge {
  FlutterForegroundTaskBridge({
    Future<bool> Function()? isRunningService,
    Future<void> Function(ForegroundServiceConfig config)?
    startForegroundService,
    Future<void> Function()? stopForegroundService,
    Duration? stopServiceTimeout,
    Future<void> Function()? waitForResume,
    void Function()? initCommunicationPort,
    void Function(Future<void> Function(dynamic))? addTaskDataCallback,
    void Function(Future<void> Function(dynamic))? removeTaskDataCallback,
    void Function(String data)? sendDataToTask,
  }) : _isRunningService = isRunningService ?? _defaultIsRunningService,
       _startForegroundService =
           startForegroundService ?? _defaultStartForegroundService,
       _stopForegroundService =
           stopForegroundService ?? _defaultStopForegroundService,
       _stopServiceTimeout = stopServiceTimeout ?? _defaultStopServiceTimeout,
       _waitUntilResumed = waitForResume ?? _waitForResume,
       _initCommunicationPort =
           initCommunicationPort ?? _defaultInitCommunicationPort,
       _addTaskDataCallback =
           addTaskDataCallback ?? _defaultAddTaskDataCallback,
       _removeTaskDataCallback =
           removeTaskDataCallback ?? _defaultRemoveTaskDataCallback,
       _sendDataToTask = sendDataToTask ?? _defaultSendDataToTask;

  final Map<String, int> _usageCounts = {};
  final Map<String, ForegroundTaskMessageHandler> _listeners = {};
  final Future<bool> Function() _isRunningService;
  final Future<void> Function(ForegroundServiceConfig config)
  _startForegroundService;
  final Future<void> Function() _stopForegroundService;
  final Duration _stopServiceTimeout;
  final Future<void> Function() _waitUntilResumed;
  final void Function() _initCommunicationPort;
  final void Function(Future<void> Function(dynamic)) _addTaskDataCallback;
  final void Function(Future<void> Function(dynamic)) _removeTaskDataCallback;
  final void Function(String data) _sendDataToTask;
  bool _callbackRegistered = false;
  bool _taskReady = false;
  Completer<void>? _startCompleter;
  Completer<void>? _taskReadyCompleter;

  static const Duration _taskReadyTimeout = Duration(seconds: 15);
  static const Duration _defaultStopServiceTimeout = Duration(seconds: 15);
  static final Logger _log = Logger('ForegroundTaskBridge');

  int get _totalUsage =>
      _usageCounts.values.fold(0, (previous, element) => previous + element);

  @override
  void registerListener(String clientId, ForegroundTaskMessageHandler handler) {
    _listeners[clientId] = handler;
    _attachCallbackIfNeeded();
  }

  @override
  void unregisterListener(String clientId) {
    _listeners.remove(clientId);
    if (_listeners.isEmpty && _totalUsage == 0) {
      _detachCallbackIfUnused();
    }
  }

  Future<void> _handleTaskData(dynamic data) async {
    if (data is! String) {
      return;
    }
    if (data == taskReadyPrefix) {
      _completeTaskReady();
      return;
    }
    for (final handler in List.of(_listeners.values)) {
      await handler(data);
    }
  }

  @override
  Future<void> acquire({
    required String clientId,
    ForegroundServiceConfig? config,
  }) async {
    _attachCallbackIfNeeded();
    final addedClient = !_usageCounts.containsKey(clientId);
    final totalBefore = _totalUsage;
    if (addedClient) {
      _usageCounts[clientId] = 1;
    }
    if (totalBefore > 0) {
      final pendingStart = _startCompleter;
      if (pendingStart != null) {
        try {
          await pendingStart.future;
        } on Exception {
          if (addedClient) {
            _decrementUsage(clientId);
          }
          _detachCallbackIfUnused();
          rethrow;
        }
        return;
      }

      if (await _isRunningService()) {
        return;
      }

      _log.warning(
        'Foreground service lease state was stale after the service stopped unexpectedly. Restarting while preserving active client leases.',
      );
      _resetTaskReady();
    }
    try {
      await _startService(config ?? _defaultConfig());
    } on Exception {
      if (addedClient) {
        _decrementUsage(clientId);
      }
      _detachCallbackIfUnused();
      rethrow;
    }
  }

  @override
  Future<void> release(String clientId) async {
    if (!_usageCounts.containsKey(clientId)) {
      _log.fine(
        'Foreground service release ignored for inactive client: '
        'clientId=$clientId totalUsage=$_totalUsage',
      );
      _detachCallbackIfUnused();
      return;
    }
    _log.info(
      'Foreground service release requested: '
      'clientId=$clientId totalUsageBefore=$_totalUsage',
    );
    _decrementUsage(clientId);
    if (_totalUsage != 0) {
      _log.info(
        'Foreground service release retained active leases: '
        'clientId=$clientId totalUsageAfter=$_totalUsage',
      );
      return;
    }
    final pendingStart = _startCompleter;
    final startupWasInFlight = pendingStart != null;
    if (pendingStart != null) {
      _log.info(
        'Foreground service release waiting for pending start: '
        'clientId=$clientId',
      );
      try {
        await pendingStart.future;
      } on Exception {
        _detachCallbackIfUnused();
        return;
      }
      if (_totalUsage != 0) {
        _log.info(
          'Foreground service release retained lease after pending start: '
          'clientId=$clientId totalUsageAfter=$_totalUsage',
        );
        return;
      }
    }
    await _stopService(forceStop: startupWasInFlight);
    _log.info(
      'Foreground service release completed: '
      'clientId=$clientId totalUsageAfter=$_totalUsage',
    );
  }

  @override
  Future<bool> isRunning() => _isRunningService();

  @override
  Future<bool> stopIfRunning() async {
    final pendingStart = _startCompleter;
    if (pendingStart != null) {
      try {
        await pendingStart.future;
      } on Exception {
        // Continue with cleanup; explicit teardown owns the final state.
      }
    }
    final running = await _isRunningService();
    if (!running) {
      _usageCounts.clear();
      _listeners.clear();
      _resetTaskReady();
      _detachCallbackIfUnused();
      return false;
    }
    _usageCounts.clear();
    try {
      await _stopService(forceStop: true);
    } finally {
      _listeners.clear();
      _detachCallbackIfUnused();
    }
    return true;
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
    _taskReady = false;
    _taskReadyCompleter = Completer<void>();
    initForegroundService();
    try {
      if (await _isRunningService()) {
        _completeTaskReady();
        completer.complete();
        return completer.future;
      }
      await _waitUntilResumed();
      await _startForegroundService(config);
      await _awaitTaskReady();
      completer.complete();
    } on Exception catch (error, stackTrace) {
      _resetTaskReady();
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _startCompleter = null;
    }
  }

  Future<void> _stopService({bool forceStop = false}) async {
    final stopwatch = Stopwatch()..start();
    try {
      _log.info('Stopping foreground service: forceStop=$forceStop');
      final serviceRunning = forceStop ? true : await _isRunningService();
      if (!serviceRunning) {
        _log.fine(
          'Skipping foreground service stop because the service is not running.',
        );
        return;
      }
      await _stopForegroundService().timeout(_stopServiceTimeout);
    } on TimeoutException catch (error, stackTrace) {
      _log.warning(
        'Timed out while stopping the foreground service.',
        error,
        stackTrace,
      );
    } on MissingPluginException catch (error, stackTrace) {
      _log.warning(
        'Foreground task plugin unavailable while stopping the service.',
        error,
        stackTrace,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to stop the foreground service cleanly.',
        error,
        stackTrace,
      );
    } finally {
      _resetTaskReady();
      _detachCallbackIfUnused();
      stopwatch.stop();
      _log.info(
        'Foreground service stop finished: '
        'forceStop=$forceStop elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
    }
  }

  ForegroundServiceConfig _defaultConfig() => buildForegroundServiceConfig(
    notificationText:
        toBeginningOfSentenceCase(ConnectionState.connecting.name) ??
        ConnectionState.connecting.name,
  );

  @override
  Future<void> send(List<Object> parts) async {
    final pendingStart = _startCompleter;
    if (pendingStart != null) {
      await pendingStart.future;
    }
    _sendDataToTask(parts.join(join));
  }

  void _attachCallbackIfNeeded() {
    if (_callbackRegistered) {
      return;
    }
    _initCommunicationPort();
    _addTaskDataCallback(_handleTaskData);
    _callbackRegistered = true;
  }

  void _detachCallbackIfUnused() {
    if (_callbackRegistered && _listeners.isEmpty && _totalUsage == 0) {
      _removeTaskDataCallback(_handleTaskData);
      _callbackRegistered = false;
    }
  }

  Future<void> _awaitTaskReady() async {
    if (_taskReady) {
      return;
    }
    final completer = _taskReadyCompleter ??= Completer<void>();
    try {
      await completer.future.timeout(_taskReadyTimeout);
    } on TimeoutException catch (error) {
      throw ForegroundServiceUnavailableException(error);
    }
  }

  void _completeTaskReady() {
    _taskReady = true;
    final completer = _taskReadyCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _resetTaskReady() {
    _taskReady = false;
    _taskReadyCompleter = null;
  }

  static Future<bool> _defaultIsRunningService() =>
      FlutterForegroundTask.isRunningService;

  static Future<void> _defaultStartForegroundService(
    ForegroundServiceConfig config,
  ) async {
    final result = await FlutterForegroundTask.startService(
      serviceTypes: const [ForegroundServiceTypes.specialUse],
      serviceId: _foregroundServiceId,
      notificationTitle: config.notificationTitle,
      notificationText: config.notificationText,
      notificationIcon: config.notificationIcon,
      callback: startCallback,
      notificationInitialRoute: '/',
    );
    if (result is ServiceRequestSuccess) {
      return;
    }
    final error = result is ServiceRequestFailure ? result.error : null;
    throw ForegroundServiceUnavailableException(
      error is Exception ? error : null,
    );
  }

  static Future<void> _defaultStopForegroundService() =>
      FlutterForegroundTask.stopService();

  static void _defaultInitCommunicationPort() {
    FlutterForegroundTask.initCommunicationPort();
  }

  static void _defaultAddTaskDataCallback(
    Future<void> Function(dynamic) callback,
  ) {
    FlutterForegroundTask.addTaskDataCallback(callback);
  }

  static void _defaultRemoveTaskDataCallback(
    Future<void> Function(dynamic) callback,
  ) {
    FlutterForegroundTask.removeTaskDataCallback(callback);
  }

  static void _defaultSendDataToTask(String data) {
    FlutterForegroundTask.sendDataToTask(data);
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
    const Duration(seconds: 15),
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
}) => ForegroundServiceConfig(
  notificationTitle: '${getFlavorPrefix()} Axichat Message Service',
  notificationText: notificationText,
  notificationIcon: const NotificationIcon(
    metaDataName: 'im.axi.axichat.APP_ICON',
  ),
);

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ForegroundSocket());
}

class ForegroundSocket extends TaskHandler {
  ForegroundSocket({
    ForegroundSocketNotificationResolver? notificationResolver,
    Future<bool> Function(ForegroundSocketNotificationRequest)?
    showNotification,
    Future<bool> Function()? isAppOnForeground,
    void Function(List<Object> strings)? sendToMain,
    Duration? mainAliveProbeTimeout,
  }) : _notificationResolver =
           notificationResolver ?? ForegroundSocketNotificationResolver(),
       _showNotification =
           showNotification ?? ForegroundSocketNotificationPresenter().show,
       _isAppOnForeground = isAppOnForeground ?? _defaultIsAppOnForeground,
       _sendToMainOverride = sendToMain,
       _mainAliveProbeTimeout =
           mainAliveProbeTimeout ?? const Duration(seconds: 5);

  static final _log = Logger('ForegroundSocket');

  XmppSocketWrapper? _socket;
  final ForegroundSocketNotificationResolver _notificationResolver;
  final Future<bool> Function(ForegroundSocketNotificationRequest)
  _showNotification;
  final Future<bool> Function() _isAppOnForeground;
  final void Function(List<Object> strings)? _sendToMainOverride;
  final Duration _mainAliveProbeTimeout;
  final WindowRateLimiter _messageNotificationGlobalLimiter = WindowRateLimiter(
    messageNotificationGlobalRateLimit,
  );
  final KeyedWindowRateLimiter _messageNotificationPerThreadLimiter =
      KeyedWindowRateLimiter(
        limit: messageNotificationPerThreadRateLimit,
        cleanupInterval: messageNotificationRateLimitCleanupInterval,
      );
  final Map<String, Completer<bool>> _mainAliveProbeCompleters =
      <String, Completer<bool>>{};
  late final StreamSubscription<String> _dataSubscription;
  late final StreamSubscription<mox.XmppSocketEvent> _eventSubscription;
  Future<void> _incomingDataQueue = Future<void>.value();
  var _mainAliveProbeSequence = 0;
  var _foregroundCheckUnavailable = false;

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

  void _sendDataToMain(List<Object> strings) {
    final override = _sendToMainOverride;
    if (override != null) {
      override(strings);
      return;
    }
    _sendToMain(strings);
  }

  static Future<bool> _defaultIsAppOnForeground() async {
    if (!Platform.isAndroid) {
      return false;
    }
    return FlutterForegroundTask.isAppOnForeground;
  }

  Future<bool> _shouldHandleForegroundNotifications() async {
    try {
      return !await _isAppOnForeground();
    } on MissingPluginException catch (error, stackTrace) {
      if (!_foregroundCheckUnavailable) {
        _log.fine(
          'Foreground app-state check unavailable; allowing notifications.',
          error,
          stackTrace,
        );
        _foregroundCheckUnavailable = true;
      }
      return true;
    } on PlatformException catch (error, stackTrace) {
      if (!_foregroundCheckUnavailable) {
        _log.fine(
          'Foreground app-state check unavailable; allowing notifications.',
          error,
          stackTrace,
        );
        _foregroundCheckUnavailable = true;
      }
      return true;
    }
  }

  Future<void> _resolveAndForward(String data) async {
    _sendDataToMain([dataPrefix, data]);
    try {
      if (!await _shouldHandleForegroundNotifications()) {
        return;
      }
      final requests = _notificationResolver.resolve(data);
      if (requests.isNotEmpty) {
        _scheduleFallbackNotifications(requests);
      }
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Foreground notification resolution failed; forwarding socket data.',
        error,
        stackTrace,
      );
    }
  }

  void _scheduleFallbackNotifications(
    List<ForegroundSocketNotificationRequest> requests,
  ) {
    fireAndForget(
      () => _showFallbackNotificationsIfMainUnavailable(requests),
      operationName: 'ForegroundSocket.fallbackNotifications',
      loggerName: 'ForegroundSocket',
    );
  }

  Future<void> _showFallbackNotificationsIfMainUnavailable(
    List<ForegroundSocketNotificationRequest> requests,
  ) async {
    if (await _mainIsolateResponds()) {
      return;
    }
    if (!await _shouldHandleForegroundNotifications()) {
      return;
    }
    for (final request in requests) {
      if (!_allowMessageNotification(request)) {
        continue;
      }
      if (await _showNotification(request)) {
        _sendDataToMain([
          foregroundNotificationShownPrefix,
          jsonEncode(request.dedupeKeys),
        ]);
      }
    }
  }

  Future<bool> _mainIsolateResponds() async {
    final token = (++_mainAliveProbeSequence).toString();
    final ack = Completer<bool>();
    _mainAliveProbeCompleters[token] = ack;
    try {
      _sendDataToMain([mainAliveProbePrefix, token]);
      return await ack.future.timeout(
        _mainAliveProbeTimeout,
        onTimeout: () => false,
      );
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to probe main isolate.', error, stackTrace);
      return false;
    } finally {
      _mainAliveProbeCompleters.remove(token);
    }
  }

  bool _allowMessageNotification(ForegroundSocketNotificationRequest request) {
    final threadKey = request.payload.trim();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (threadKey.isNotEmpty &&
        !_messageNotificationPerThreadLimiter.allowEvent(
          threadKey,
          nowMs: nowMs,
        )) {
      return false;
    }
    return _messageNotificationGlobalLimiter.allowEvent(nowMs: nowMs);
  }

  @visibleForTesting
  Future<void> debugResolveAndForward(String data) => _resolveAndForward(data);

  void _queueSocketData(String data) {
    _incomingDataQueue = _incomingDataQueue.then(
      (_) => _resolveAndForward(data),
      onError: (Object error, StackTrace stackTrace) {
        if (error is Exception) {
          _log.warning(
            'Foreground socket data queue recovered after an exception.',
            error,
            stackTrace,
          );
        }
        return _resolveAndForward(data);
      },
    );
  }

  Future<void> _drainIncomingDataQueue() async {
    try {
      await _incomingDataQueue.timeout(const Duration(seconds: 5));
    } on TimeoutException catch (error, stackTrace) {
      _log.warning(
        'Timed out draining foreground socket data before destroy.',
        error,
        stackTrace,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Foreground socket data queue failed before destroy.',
        error,
        stackTrace,
      );
    }
  }

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
    _dataSubscription = _socket!.getDataStream().listen(_queueSocketData);
    _eventSubscription = _socket!.getEventStream().listen(_onEvent);
    _sendDataToMain([taskReadyPrefix]);
  }

  @override
  void onReceiveData(covariant String data) async {
    final separatorIndex = data.indexOf(join);
    final type = separatorIndex == -1
        ? data
        : data.substring(0, separatorIndex);
    final payloadLength = separatorIndex == -1
        ? 0
        : data.length - separatorIndex - join.length;
    _log.fine('Received task: type=$type payloadLen=$payloadLength');
    if (data.startsWith('$foregroundNotificationSnapshotPrefix$join')) {
      final payload = data.substring(
        '$foregroundNotificationSnapshotPrefix$join'.length,
      );
      final tokenSeparator = payload.indexOf(join);
      final token = tokenSeparator == -1
          ? null
          : payload.substring(0, tokenSeparator);
      final snapshotPayload = tokenSeparator == -1
          ? payload
          : payload.substring(tokenSeparator + join.length);
      final updated = _notificationResolver.updateSnapshot(snapshotPayload);
      if (updated && token != null && token.isNotEmpty) {
        _sendDataToMain([foregroundNotificationSnapshotAckPrefix, token]);
      }
      return;
    }
    if (data.startsWith('$mainAliveAckPrefix$join')) {
      final token = data.substring('$mainAliveAckPrefix$join'.length);
      _mainAliveProbeCompleters.remove(token)?.complete(true);
      return;
    }
    _socket ??= XmppSocketWrapper();
    if (data.startsWith('$connectPrefix$join')) {
      final split = data.split(join);
      final host = split.length > 2 && split[2].isNotEmpty ? split[2] : null;
      final port = split.length > 3 && split[3].isNotEmpty
          ? int.tryParse(split[3])
          : null;
      _log.info(
        'Foreground task connecting XMPP socket: '
        'domain=${split[1]} host=$host port=$port',
      );
      final result = await _socket!.connect(split[1], host: host, port: port);
      _log.info('Foreground task XMPP socket connect result: $result');
      return _sendDataToMain([connectPrefix, result]);
    } else if (data.startsWith('$securePrefix$join')) {
      final domain = data.substring('$securePrefix$join'.length);
      final result = await _socket!.secure(domain);
      return _sendDataToMain([securePrefix, result]);
    } else if (data.startsWith('$writePrefix$join')) {
      return _socket?.write(data.substring('$writePrefix$join'.length));
    } else if (data.startsWith('$closePrefix$join')) {
      return _socket?.close();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, _) async {
    _socket?.close();
    _socket = null;
    await _dataSubscription.cancel();
    await _eventSubscription.cancel();
    await _drainIncomingDataQueue();
  }
}

@visibleForTesting
final class ForegroundSocketNotificationRequest {
  const ForegroundSocketNotificationRequest({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.payload,
    required this.channelName,
    required this.showPreview,
    required this.dedupeKeys,
  });

  final int notificationId;
  final String title;
  final String? body;
  final String payload;
  final String channelName;
  final bool showPreview;
  final List<String> dedupeKeys;
}

@visibleForTesting
final class ForegroundSocketNotificationResolver {
  ForegroundSocketNotificationResolver({
    ForegroundMessageStanzaBuffer? buffer,
    ForegroundSocketMessageExtractor? extractor,
    DateTime Function()? now,
  }) : _buffer = buffer ?? ForegroundMessageStanzaBuffer(),
       _extractor = extractor ?? const ForegroundSocketMessageExtractor(),
       _now = now ?? DateTime.timestamp;

  static const Duration _dedupeTtl = Duration(seconds: 90);

  final ForegroundMessageStanzaBuffer _buffer;
  final ForegroundSocketMessageExtractor _extractor;
  final DateTime Function() _now;
  final Map<String, DateTime> _recentNotificationKeys = <String, DateTime>{};
  ForegroundNotificationSnapshot? _snapshot;

  bool updateSnapshot(String raw) {
    final snapshot = ForegroundNotificationSnapshot.tryDecode(raw);
    if (snapshot == null) {
      return false;
    }
    _snapshot = snapshot;
    return true;
  }

  List<ForegroundSocketNotificationRequest> resolve(String socketData) {
    final snapshot = _snapshot;
    if (snapshot == null ||
        (!snapshot.strings.hasMessageLabels &&
            !snapshot.strings.hasEmailLabels)) {
      return const <ForegroundSocketNotificationRequest>[];
    }
    final requests = <ForegroundSocketNotificationRequest>[];
    for (final stanza in _buffer.add(socketData)) {
      final candidate = _extractor.extract(stanza, snapshot: snapshot);
      if (candidate == null) {
        continue;
      }
      final request = _requestFor(candidate, snapshot);
      if (request != null) {
        requests.add(request);
      }
    }
    return requests;
  }

  ForegroundSocketNotificationRequest? _requestFor(
    ForegroundSocketMessageCandidate candidate,
    ForegroundNotificationSnapshot snapshot,
  ) {
    if (!snapshot.backgroundMessageNotificationsEnabled) {
      return null;
    }
    if (candidate.isMailPushHint) {
      return _mailPushRequestFor(candidate, snapshot);
    }
    if (!snapshot.strings.hasMessageLabels) {
      return null;
    }
    final policy = snapshot.policyFor(candidate.chatJid);
    if (policy?.allowsNotification(
          globalChatNotificationsMuted: snapshot.chatNotificationsMuted,
        ) ==
        false) {
      return null;
    }
    if (policy == null && snapshot.chatNotificationsMuted) {
      return null;
    }
    final threadKey = _notificationThreadKey(policy, candidate.chatJid);
    if (threadKey.isEmpty) {
      return null;
    }
    final showPreview =
        policy?.resolvePreviews(snapshot.notificationPreviewsEnabled) ??
        snapshot.notificationPreviewsEnabled;
    final sanitizedBody = showPreview
        ? sanitizeNotificationPreview(candidate.preview)
        : null;
    final conversationTitle = _notificationLabel(
      policy?.title,
      fallback: candidate.conversationTitle,
    );
    final senderName = _notificationLabel(
      candidate.senderName,
      fallback: conversationTitle,
    );
    final presentation = _resolvePresentation(
      strings: snapshot.strings,
      conversationTitle: conversationTitle,
      senderName: senderName,
      isGroupConversation:
          policy?.isGroupConversation ?? candidate.isGroupConversation,
      sanitizedBody: sanitizedBody,
    );
    final dedupeKeys = candidate.dedupeKeys;
    if (dedupeKeys.isEmpty || !_reserveDedupeKeys(dedupeKeys)) {
      return null;
    }
    return ForegroundSocketNotificationRequest(
      notificationId: foregroundNotificationStableId(threadKey),
      title: presentation.title,
      body: presentation.body,
      payload: threadKey,
      channelName: snapshot.strings.channelMessages,
      showPreview: sanitizedBody != null,
      dedupeKeys: dedupeKeys,
    );
  }

  ForegroundSocketNotificationRequest? _mailPushRequestFor(
    ForegroundSocketMessageCandidate candidate,
    ForegroundNotificationSnapshot snapshot,
  ) {
    if (snapshot.emailNotificationsMuted || !snapshot.strings.hasEmailLabels) {
      return null;
    }
    final dedupeKeys = candidate.dedupeKeys;
    if (!_reserveDedupeKeys(dedupeKeys)) {
      return null;
    }
    final payload = const NotificationPayloadCodec().emailInboxPayload;
    return ForegroundSocketNotificationRequest(
      notificationId: foregroundNotificationStableId(payload),
      title: snapshot.strings.newEmailTitle.trim(),
      body: null,
      payload: payload,
      channelName: snapshot.strings.channelMessages,
      showPreview: false,
      dedupeKeys: dedupeKeys,
    );
  }

  bool _reserveDedupeKeys(List<String> dedupeKeys) {
    final now = _now();
    _recentNotificationKeys.removeWhere(
      (key, createdAt) => now.difference(createdAt) > _dedupeTtl,
    );
    for (final key in dedupeKeys) {
      if (_recentNotificationKeys.containsKey(key)) {
        return false;
      }
    }
    for (final key in dedupeKeys) {
      _recentNotificationKeys[key] = now;
    }
    return true;
  }

  ({String title, String? body}) _resolvePresentation({
    required ForegroundNotificationStrings strings,
    required String conversationTitle,
    required String senderName,
    required bool isGroupConversation,
    required String? sanitizedBody,
  }) {
    if (sanitizedBody != null) {
      return (
        title: isGroupConversation ? conversationTitle : senderName,
        body: isGroupConversation && senderName != conversationTitle
            ? '$senderName: $sanitizedBody'
            : sanitizedBody,
      );
    }
    final categoryTitle = strings.newMessageTitle.trim();
    final label = (isGroupConversation ? conversationTitle : senderName).trim();
    return (
      title: label.isEmpty ? categoryTitle : '$categoryTitle: $label',
      body: isGroupConversation && senderName.trim() != conversationTitle.trim()
          ? senderName
          : null,
    );
  }

  String _notificationLabel(String? value, {required String fallback}) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    return fallback.trim();
  }

  String _notificationThreadKey(
    ForegroundChatNotificationPolicy? policy,
    String chatJid,
  ) {
    final policyThreadKey = policy?.threadKey.trim();
    if (policyThreadKey != null && policyThreadKey.isNotEmpty) {
      return policyThreadKey;
    }
    return const NotificationPayloadCodec().encodeChatJid(chatJid) ??
        normalizedAddressKey(chatJid) ??
        chatJid.trim();
  }
}

@visibleForTesting
final class ForegroundMessageStanzaBuffer {
  static const int _maxBufferCharacters = 128 * 1024;
  static const String _messageStartPrefix = '<message';

  String _buffer = '';

  List<String> add(String data) {
    if (data.isEmpty) {
      return const <String>[];
    }
    _buffer = '$_buffer$data';
    if (_buffer.length > _maxBufferCharacters) {
      _trimOversizedBuffer();
    }
    final stanzas = <String>[];
    while (_buffer.isNotEmpty) {
      final start = _findMessageStart(_buffer);
      if (start == -1) {
        _retainPossibleMessageStartPrefix();
        return stanzas;
      }
      if (start > 0) {
        _buffer = _buffer.substring(start);
      }
      final end = _findTopLevelMessageEnd(_buffer);
      if (end == null) {
        return stanzas;
      }
      stanzas.add(_buffer.substring(0, end));
      _buffer = _buffer.substring(end);
    }
    return stanzas;
  }

  void _trimOversizedBuffer() {
    final start = _findMessageStart(_buffer);
    if (start == -1) {
      _retainPossibleMessageStartPrefix();
      return;
    }
    _buffer = _buffer.substring(start);
    if (_buffer.length > _maxBufferCharacters) {
      _buffer = '';
    }
  }

  int _findMessageStart(String value) {
    var index = value.indexOf(_messageStartPrefix);
    while (index != -1) {
      final after = index + _messageStartPrefix.length;
      if (after >= value.length ||
          _isXmlNameBoundary(value.codeUnitAt(after))) {
        return index;
      }
      index = value.indexOf(_messageStartPrefix, index + 1);
    }
    return -1;
  }

  void _retainPossibleMessageStartPrefix() {
    final maxSuffixLength = _messageStartPrefix.length - 1;
    final suffixStart = _buffer.length > maxSuffixLength
        ? _buffer.length - maxSuffixLength
        : 0;
    final suffix = _buffer.substring(suffixStart);
    for (var length = suffix.length; length > 0; length--) {
      final candidate = suffix.substring(suffix.length - length);
      if (_messageStartPrefix.startsWith(candidate)) {
        _buffer = candidate;
        return;
      }
    }
    _buffer = '';
  }

  int? _findTopLevelMessageEnd(String value) {
    var index = 0;
    var depth = 0;
    while (index < value.length) {
      if (value.codeUnitAt(index) != 0x3c) {
        index++;
        continue;
      }
      if (value.startsWith('<!--', index)) {
        final end = value.indexOf('-->', index + 4);
        if (end == -1) return null;
        index = end + 3;
        continue;
      }
      if (value.startsWith('<![CDATA[', index)) {
        final end = value.indexOf(']]>', index + 9);
        if (end == -1) return null;
        index = end + 3;
        continue;
      }
      if (value.startsWith('<?', index)) {
        final end = value.indexOf('?>', index + 2);
        if (end == -1) return null;
        index = end + 2;
        continue;
      }
      if (value.startsWith('</', index)) {
        final tagEnd = _findTagEnd(value, index + 2);
        if (tagEnd == null) return null;
        if (_isMessageTagName(_readTagName(value, index + 2))) {
          depth--;
          if (depth <= 0) {
            return tagEnd + 1;
          }
        }
        index = tagEnd + 1;
        continue;
      }
      if (value.startsWith('<!', index)) {
        final end = value.indexOf('>', index + 2);
        if (end == -1) return null;
        index = end + 1;
        continue;
      }
      final tagEnd = _findTagEnd(value, index + 1);
      if (tagEnd == null) return null;
      if (_isMessageTagName(_readTagName(value, index + 1))) {
        if (_isSelfClosingTag(value, tagEnd)) {
          if (depth == 0) {
            return tagEnd + 1;
          }
        } else {
          depth++;
        }
      }
      index = tagEnd + 1;
    }
    return null;
  }

  int? _findTagEnd(String value, int start) {
    int? quote;
    var index = start;
    while (index < value.length) {
      final codeUnit = value.codeUnitAt(index);
      if (quote != null) {
        if (codeUnit == quote) {
          quote = null;
        }
      } else if (codeUnit == 0x22 || codeUnit == 0x27) {
        quote = codeUnit;
      } else if (codeUnit == 0x3e) {
        return index;
      }
      index++;
    }
    return null;
  }

  String _readTagName(String value, int start) {
    var index = start;
    while (index < value.length && value.codeUnitAt(index) <= 0x20) {
      index++;
    }
    final begin = index;
    while (index < value.length &&
        !_isXmlNameBoundary(value.codeUnitAt(index))) {
      index++;
    }
    return value.substring(begin, index);
  }

  bool _isMessageTagName(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) {
      return false;
    }
    final colonIndex = name.indexOf(':');
    final localName = colonIndex == -1 ? name : name.substring(colonIndex + 1);
    return localName == 'message';
  }

  bool _isSelfClosingTag(String value, int tagEnd) {
    var index = tagEnd - 1;
    while (index >= 0 && value.codeUnitAt(index) <= 0x20) {
      index--;
    }
    return index >= 0 && value.codeUnitAt(index) == 0x2f;
  }

  bool _isXmlNameBoundary(int codeUnit) {
    return codeUnit <= 0x20 || codeUnit == 0x2f || codeUnit == 0x3e;
  }
}

@visibleForTesting
final class ForegroundSocketMessageCandidate {
  const ForegroundSocketMessageCandidate.chat({
    required this.chatJid,
    required this.senderJid,
    required this.senderName,
    required this.conversationTitle,
    required this.preview,
    required this.isGroupConversation,
    required this.dedupeKeys,
  }) : isMailPushHint = false;

  const ForegroundSocketMessageCandidate.mailPushHint({
    required this.dedupeKeys,
  }) : chatJid = '',
       senderJid = '',
       senderName = '',
       conversationTitle = '',
       preview = null,
       isGroupConversation = false,
       isMailPushHint = true;

  final String chatJid;
  final String senderJid;
  final String senderName;
  final String conversationTitle;
  final String? preview;
  final bool isGroupConversation;
  final bool isMailPushHint;
  final List<String> dedupeKeys;
}

@visibleForTesting
final class ForegroundSocketMessageExtractor {
  const ForegroundSocketMessageExtractor();

  static const XmlParseLimits _parseLimits = XmlParseLimits(
    maxBytes: 64 * 1024,
    maxNodes: 512,
    maxDepth: 32,
    maxDuration: Duration(milliseconds: 50),
  );
  static const Set<String> _mamNamespaces = <String>{
    'urn:xmpp:mam:0',
    'urn:xmpp:mam:1',
    'urn:xmpp:mam:2',
    'urn:xmpp:mam:tmp',
  };
  static const String _carbonsNamespace = 'urn:xmpp:carbons:2';
  static const String _messageCorrectionNamespace =
      'urn:xmpp:message-correct:0';
  static const String _messageRetractionNamespace =
      'urn:xmpp:message-retract:1';
  static const String _receiptsNamespace = 'urn:xmpp:receipts';
  static const String _chatMarkersNamespace = 'urn:xmpp:chat-markers:0';
  static const String _mailPushNamespace = 'urn:axichat:mail-push:0';
  static const String _mailPushSenderLocalPart = 'mail-notify';

  ForegroundSocketMessageCandidate? extract(
    String raw, {
    required ForegroundNotificationSnapshot snapshot,
  }) {
    final document = tryParseXml(raw, _parseLimits);
    if (document == null) {
      return null;
    }
    final root = document.rootElement;
    if (root.name.local != 'message') {
      return null;
    }
    final mailPushHint = _mailPushHintCandidate(root, snapshot);
    if (mailPushHint != null) {
      return mailPushHint;
    }
    if (_suppressedMessageType(root)) {
      return null;
    }
    if (_hasSuppressedWrapper(root) || _hasSuppressedMutation(root)) {
      return null;
    }

    final from = fullAddress(root.getAttribute('from'))?.trim();
    if (from == null || from.isEmpty) {
      return null;
    }
    final body = _directChildText(root, 'body');
    final subject = _directChildText(root, 'subject');
    final type = root.getAttribute('type')?.trim();
    final isGroupConversation = type == 'groupchat';
    final chatJid = bareAddress(from)?.trim();
    if (chatJid == null || chatJid.isEmpty) {
      return null;
    }
    if (_isSelfDirectMessage(
      from: from,
      isGroupConversation: isGroupConversation,
      accountJid: snapshot.accountJid,
    )) {
      return null;
    }
    if (!isGroupConversation && snapshot.blocksInboundSender(from)) {
      return null;
    }

    final policy = snapshot.policyFor(chatJid);
    final senderResource = addressResourcePart(from);
    if (isGroupConversation &&
        _isOwnGroupEcho(senderResource, policy?.myNickname)) {
      return null;
    }

    final preview = ChatSubjectCodec.previewText(
      body: body,
      subject: isGroupConversation ? null : subject,
    );
    final encrypted = _hasDirectChild(
      root,
      'encrypted',
      namespace: mox.omemoXmlns,
    );
    final fileUpload = _hasDirectChild(
      root,
      'file-upload',
      namespace: mox.fileUploadNotificationXmlns,
    );
    if (preview == null && !encrypted && !fileUpload) {
      return null;
    }
    final senderName = isGroupConversation
        ? _displayName(
            senderResource,
            fallback: displaySafeAddress(from, includeResource: true) ?? from,
          )
        : _displayName(
            policy?.title,
            fallback:
                addressDisplayLabel(from) ?? displaySafeAddress(from) ?? from,
          );
    final conversationTitle = _displayName(
      policy?.title,
      fallback: isGroupConversation
          ? addressDisplayLabel(chatJid) ??
                displaySafeAddress(chatJid) ??
                chatJid
          : senderName,
    );
    final dedupeKeys = <String>{
      ?foregroundNotificationStanzaDedupeKey(root.getAttribute('id')),
    }.toList(growable: false);
    return ForegroundSocketMessageCandidate.chat(
      chatJid: chatJid,
      senderJid: from,
      senderName: senderName,
      conversationTitle: conversationTitle,
      preview: preview,
      isGroupConversation: isGroupConversation,
      dedupeKeys: dedupeKeys,
    );
  }

  ForegroundSocketMessageCandidate? _mailPushHintCandidate(
    xml.XmlElement root,
    ForegroundNotificationSnapshot snapshot,
  ) {
    if (root.getAttribute('type')?.trim() != 'headline') {
      return null;
    }
    final accountJid = snapshot.accountJid?.trim();
    if (accountJid == null || accountJid.isEmpty) {
      return null;
    }
    final from = fullAddress(root.getAttribute('from'))?.trim();
    if (from == null || from.isEmpty) {
      return null;
    }
    if (addressLocalPart(from)?.trim().toLowerCase() !=
        _mailPushSenderLocalPart) {
      return null;
    }
    final accountBare = bareAddress(accountJid) ?? accountJid;
    final fromBare = bareAddress(from) ?? from;
    final accountDomain = addressDomainPart(accountBare)?.toLowerCase();
    final fromDomain = addressDomainPart(fromBare)?.toLowerCase();
    if (accountDomain == null || fromDomain != accountDomain) {
      return null;
    }
    final to = fullAddress(root.getAttribute('to'))?.trim();
    if (to != null && to.isNotEmpty && !sameBareAddress(to, accountJid)) {
      return null;
    }
    if (!_hasDirectChild(root, 'x', namespace: _mailPushNamespace)) {
      return null;
    }
    final dedupeKeys = <String>{
      ?foregroundNotificationMailPushDedupeKey(root.getAttribute('id')),
    }.toList(growable: false);
    return ForegroundSocketMessageCandidate.mailPushHint(
      dedupeKeys: dedupeKeys,
    );
  }

  bool _suppressedMessageType(xml.XmlElement root) {
    final type = root.getAttribute('type')?.trim();
    return type == 'error' || type == 'headline';
  }

  bool _hasSuppressedWrapper(xml.XmlElement root) {
    return _hasDirectChild(root, 'result', namespaces: _mamNamespaces) ||
        _hasDirectChild(root, 'sent', namespace: _carbonsNamespace) ||
        _hasDirectChild(root, 'received', namespace: _carbonsNamespace);
  }

  bool _hasSuppressedMutation(xml.XmlElement root) {
    return _hasDirectChild(
          root,
          'replace',
          namespace: _messageCorrectionNamespace,
        ) ||
        _hasDirectChild(
          root,
          'retract',
          namespace: _messageRetractionNamespace,
        ) ||
        _hasDirectChild(
          root,
          'retracted',
          namespace: _messageRetractionNamespace,
        ) ||
        _hasDirectChild(root, 'received', namespace: _receiptsNamespace) ||
        _hasDirectChild(root, 'displayed', namespace: _chatMarkersNamespace) ||
        _hasDirectChild(root, 'acknowledged', namespace: _chatMarkersNamespace);
  }

  bool _hasDirectChild(
    xml.XmlElement root,
    String localName, {
    String? namespace,
    Set<String> namespaces = const <String>{},
  }) {
    for (final child in root.children.whereType<xml.XmlElement>()) {
      if (child.name.local != localName) {
        continue;
      }
      final childNamespace = _namespaceFor(child);
      if (namespace != null) {
        if (childNamespace == namespace) {
          return true;
        }
        continue;
      }
      if (namespaces.isNotEmpty) {
        if (childNamespace != null && namespaces.contains(childNamespace)) {
          return true;
        }
        continue;
      }
      return true;
    }
    return false;
  }

  String? _directChildText(xml.XmlElement root, String localName) {
    for (final child in root.children.whereType<xml.XmlElement>()) {
      if (child.name.local != localName) {
        continue;
      }
      final text = child.innerText.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String? _namespaceFor(xml.XmlElement element) {
    final namespace = element.name.namespaceUri?.trim();
    if (namespace != null && namespace.isNotEmpty) {
      return namespace;
    }
    final defaultNamespace = element.getAttribute('xmlns')?.trim();
    if (defaultNamespace != null && defaultNamespace.isNotEmpty) {
      return defaultNamespace;
    }
    return null;
  }

  bool _isSelfDirectMessage({
    required String from,
    required bool isGroupConversation,
    required String? accountJid,
  }) {
    if (isGroupConversation) {
      return false;
    }
    final account = accountJid?.trim();
    return account != null &&
        account.isNotEmpty &&
        sameBareAddress(from, account);
  }

  bool _isOwnGroupEcho(String? resource, String? myNickname) {
    final normalizedResource = resource?.trim().toLowerCase();
    final normalizedNickname = myNickname?.trim().toLowerCase();
    return normalizedResource != null &&
        normalizedResource.isNotEmpty &&
        normalizedNickname != null &&
        normalizedNickname.isNotEmpty &&
        normalizedResource == normalizedNickname;
  }

  String _displayName(String? value, {required String fallback}) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    return fallback.trim();
  }
}

@visibleForTesting
final class ForegroundSocketNotificationPresenter {
  ForegroundSocketNotificationPresenter({
    local_notifications.FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin =
           plugin ?? local_notifications.FlutterLocalNotificationsPlugin();

  static const String _androidIconPath = '@mipmap/ic_launcher';
  static const String _androidGroupKey = 'im.axi.axichat.MESSAGES';

  final local_notifications.FlutterLocalNotificationsPlugin _plugin;
  var _initialized = false;
  Future<void>? _initialization;

  Future<bool> show(ForegroundSocketNotificationRequest request) async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      await _ensureInitialized();
      final details = local_notifications.NotificationDetails(
        android: local_notifications.AndroidNotificationDetails(
          request.channelName,
          request.channelName,
          groupKey: _androidGroupKey,
          importance: local_notifications.Importance.max,
          priority: local_notifications.Priority.high,
          icon: _androidIconPath,
          category: local_notifications.AndroidNotificationCategory.message,
          visibility: request.showPreview
              ? local_notifications.NotificationVisibility.public
              : local_notifications.NotificationVisibility.private,
        ),
      );
      await _plugin.show(
        id: request.notificationId,
        title: request.title,
        body: request.body,
        notificationDetails: details,
        payload: request.payload,
      );
      return true;
    } on MissingPluginException catch (error, stackTrace) {
      ForegroundSocket._log.warning(
        'Foreground notification plugin unavailable.',
        error,
        stackTrace,
      );
      return false;
    } on PlatformException catch (error, stackTrace) {
      ForegroundSocket._log.warning(
        'Foreground notification failed.',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<void> _ensureInitialized() {
    if (_initialized) {
      return Future<void>.value();
    }
    final pending = _initialization;
    if (pending != null) {
      return pending;
    }
    final initialization = _initialize();
    _initialization = initialization;
    return initialization;
  }

  Future<void> _initialize() async {
    const androidSettings = local_notifications.AndroidInitializationSettings(
      _androidIconPath,
    );
    const settings = local_notifications.InitializationSettings(
      android: androidSettings,
    );
    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: handleBackgroundNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            handleBackgroundNotificationResponse,
      );
      _initialized = true;
    } finally {
      _initialization = null;
    }
  }
}

class ForegroundSocketWrapper implements XmppSocketWrapper {
  ForegroundSocketWrapper({
    ForegroundTaskBridge? bridge,
    Duration? connectTimeout,
    Duration? secureTimeout,
  }) : _bridge = bridge ?? foregroundTaskBridge,
       _connectTimeout = connectTimeout ?? _defaultTaskResponseTimeout,
       _secureTimeout = secureTimeout ?? _defaultTaskResponseTimeout;

  static final _log = Logger('ForegroundSocketWrapper');
  static const Duration _defaultTaskResponseTimeout = Duration(seconds: 20);
  final ForegroundTaskBridge _bridge;
  final Duration _connectTimeout;
  final Duration _secureTimeout;
  final StreamController<String> _dataStream = StreamController.broadcast();
  final StreamController<mox.XmppSocketEvent> _eventStream =
      StreamController.broadcast();
  void Function()? _onConnectSuccess;
  void Function(SocketException error)? _onConnectError;
  FutureOr<void> Function()? _onConnectFailure;

  var _connect = Completer<bool>();
  var _secure = Completer<bool>();
  var _secureResult = false;
  var _listenerRegistered = false;
  var _serviceAcquired = false;
  DateTime? _lastIncomingAt;
  DateTime? _lastOutgoingAt;

  Future<void> _onReceiveTaskData(String data) async {
    final separatorIndex = data.indexOf(join);
    final type = separatorIndex == -1
        ? data
        : data.substring(0, separatorIndex);
    final payloadLength = separatorIndex == -1
        ? 0
        : data.length - separatorIndex - join.length;
    _log.fine('Received main: type=$type payloadLen=$payloadLength');
    if (data.startsWith('$mainAliveProbePrefix$join')) {
      final token = data.substring('$mainAliveProbePrefix$join'.length);
      try {
        await _bridge.send([mainAliveAckPrefix, token]);
      } on Exception catch (error, stackTrace) {
        _log.fine('Failed to acknowledge main-alive probe.', error, stackTrace);
      }
    } else if (data.startsWith('$dataPrefix$join')) {
      _recordIncomingTraffic();
      _dataStream.add(data.substring('$dataPrefix$join'.length));
    } else if (data.startsWith('$foregroundNotificationShownPrefix$join')) {
      _recordForegroundNotificationShown(
        data.substring('$foregroundNotificationShownPrefix$join'.length),
      );
    } else if (data == socketErrorPrefix) {
      _eventStream.add(mox.XmppSocketErrorEvent(''));
    } else if (data.startsWith('$socketClosurePrefix$join')) {
      _eventStream.add(mox.XmppSocketClosureEvent(_boolFromPayload(data)));
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

  void _recordForegroundNotificationShown(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! List) {
        return;
      }
      _foregroundNotificationShownController.add(
        decoded.whereType<String>().toList(growable: false),
      );
    } on FormatException {
      return;
    }
  }

  void _completeConnect(bool connected) {
    if (_connect.isCompleted) return;
    _connect.complete(connected);
    if (connected) {
      _onConnectSuccess?.call();
      return;
    }
    _onConnectError?.call(
      const SocketException('Foreground socket connection failed.'),
    );
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
    fireAndForget(() async {
      await _bridge.send(strings);
    }, operationName: _foregroundSocketSendOperationName);
  }

  @override
  bool isSecure() => _secureResult;

  @override
  void registerConnectionCallbacks({
    void Function()? onConnectSuccess,
    void Function(SocketException error)? onConnectError,
    FutureOr<void> Function()? onConnectFailure,
  }) {
    _onConnectSuccess = onConnectSuccess;
    _onConnectError = onConnectError;
    _onConnectFailure = onConnectFailure;
  }

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
    _secure = Completer<bool>();
    _sendToTask([securePrefix, domain]);
    return _awaitSecureResponse(domain);
  }

  @override
  bool whitespacePingAllowed() => true;

  @override
  DateTime? get lastIncomingAt => _lastIncomingAt;

  @override
  DateTime? get lastOutgoingAt => _lastOutgoingAt;

  void _recordIncomingTraffic() {
    _lastIncomingAt = DateTime.timestamp();
  }

  void _recordOutgoingTraffic() {
    _lastOutgoingAt = DateTime.timestamp();
  }

  @override
  Future<bool> connect(String domain, {String? host, int? port}) async {
    await reset();
    _connect = Completer<bool>();
    _secure = Completer<bool>();
    _secureResult = false;

    final target = host == null || host.isEmpty
        ? _SocketTarget(domain, port ?? EndpointConfig.defaultXmppPort)
        : _SocketTarget(host, port ?? EndpointConfig.defaultXmppPort);

    if (!_listenerRegistered) {
      _bridge.registerListener(foregroundClientXmpp, _onReceiveTaskData);
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
      _log.info(
        'Foreground XMPP lease acquired. Connecting to '
        '${target.host}:${target.port}',
      );
    } on Exception {
      _detachListener();
      rethrow;
    }

    _sendToTask([connectPrefix, domain, target.host, target.port]);
    final connected = await _awaitConnectResponse();
    if (!connected) {
      await _onConnectFailure?.call();
    }
    return connected;
  }

  @override
  void write(String data) {
    _recordOutgoingTraffic();
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
  Future<void> closeStreams() async {
    if (!_dataStream.isClosed) {
      await _dataStream.close();
    }
    if (!_eventStream.isClosed) {
      await _eventStream.close();
    }
  }

  @override
  void prepareDisconnect() {}

  Future<void> reset() async {
    _log.info(
      'Resetting foreground socket wrapper. '
      'serviceAcquired=$_serviceAcquired listenerRegistered=$_listenerRegistered',
    );
    _cancelPendingTaskResponses();
    _secureResult = false;
    _detachListener();
    await _releaseService();
  }

  void _cancelPendingTaskResponses() {
    if (!_connect.isCompleted) {
      _connect.complete(false);
    }
    if (!_secure.isCompleted) {
      _secure.complete(false);
    }
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

  Future<bool> _awaitConnectResponse() async {
    try {
      return await _connect.future.timeout(_connectTimeout);
    } on TimeoutException {
      const error = SocketException('Foreground task connect timed out.');
      _log.warning('Timed out waiting for the foreground task connect result.');
      _onConnectError?.call(error);
      await reset();
      return false;
    }
  }

  Future<bool> _awaitSecureResponse(String domain) async {
    try {
      return await _secure.future.timeout(_secureTimeout);
    } on TimeoutException {
      _log.warning(
        'Timed out waiting for the foreground task secure result for $domain.',
      );
      await reset();
      return false;
    }
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

  SafeLogging.setVerboseXmppTraffic(enabled: kDebugMode);
  SafeLogging.setRawXmppTraffic(enabled: kDebugMode);

  if (kDebugMode) {
    Logger.root
      ..level = Level.ALL
      ..onRecord.listen((record) {
        if (!SafeLogging.shouldEmitDebugRecord(record)) {
          return;
        }
        // ignore: avoid_print
        print(SafeLogging.formatDebugRecord(record));
      });
    return;
  }

  Logger.root.level = Level.OFF;
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
    eventAction: ForegroundTaskEventAction.nothing(),
    autoRunOnBoot: true,
    autoRunOnMyPackageReplaced: true,
    allowWakeLock: true,
    allowWifiLock: true,
  ),
);
