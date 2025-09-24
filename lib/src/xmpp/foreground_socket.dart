import 'dart:async';

import 'package:axichat/src/common/flavor_prefix.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide NotificationVisibility;
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:moxxmpp_socket_tcp/moxxmpp_socket_tcp.dart' as mox_tcp;

const join = '::';
const connectPrefix = 'Connect';
const securePrefix = 'Secure';
const writePrefix = 'Write';
const closePrefix = 'Close';
const destroyPrefix = 'Destroy';
const dataPrefix = 'Data';
const socketErrorPrefix = 'XmppSocketErrorEvent';
const socketClosurePrefix = 'XmppSocketClosureEvent';

bool launchedFromNotification = false;

@pragma("vm:entry-point")
void notificationTapBackground(NotificationResponse notificationResponse) {
  launchedFromNotification = true;
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

  static void _sendToMain(List<Object> strings) {
    final data = strings.join(join);
    _log.fine('Sending to main: $data');
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
    _log.fine('Received task: $data');
    _socket ??= XmppSocketWrapper();
    if (data.startsWith('$connectPrefix$join')) {
      final split = data.split(join);
      final result = await _socket!.connect(
        split[1],
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
  }
}

class ForegroundSocketWrapper implements XmppSocketWrapper {
  ForegroundSocketWrapper();

  static final _log = Logger('ForegroundSocketWrapper');

  final StreamController<String> _dataStream = StreamController.broadcast();
  final StreamController<mox.XmppSocketEvent> _eventStream =
      StreamController.broadcast();

  var _connect = Completer<bool>();
  var _secure = Completer<bool>();

  Future<void> _onReceiveTaskData(Object data) async {
    if (data is! String) return;
    _log.fine('Received main: $data');
    if (data.startsWith('$dataPrefix$join')) {
      _dataStream.add(data.substring('$dataPrefix$join'.length));
    } else if (data == socketErrorPrefix) {
      _eventStream.add(mox.XmppSocketErrorEvent(''));
    } else if (data.startsWith('$socketClosurePrefix$join')) {
      _eventStream.add(
        mox.XmppSocketClosureEvent(bool.parse(data.split(join)[1])),
      );
    } else if (data.startsWith('$connectPrefix$join')) {
      final connected = bool.parse(data.split(join)[1]);
      _connect.complete(connected);
    } else if (data.startsWith('$securePrefix$join')) {
      _secure.complete(bool.parse(data.split(join)[1]));
    }
  }

  static void _sendToTask(List<Object> strings) {
    final data = strings.join(join);
    _log.info('Sending to task: $data');
    FlutterForegroundTask.sendDataToTask(data);
  }

  @override
  bool isSecure() => _secure.isCompleted;

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
  Future<List<mox_tcp.MoxSrvRecord>> srvQuery(
    String domain,
    bool dnssec,
  ) async =>
      [];

  @override
  bool whitespacePingAllowed() => true;

  @override
  Future<bool> connect(String domain, {String? host, int? port}) async {
    await reset();

    _log.info('Starting foreground service...');
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    initForegroundService();
    final ServiceRequestResult startResult;
    try {
      startResult = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: '${getFlavorPrefix()} Axichat Message Service',
        notificationText:
            toBeginningOfSentenceCase(ConnectionState.connecting.name),
        notificationIcon:
            const NotificationIcon(metaDataName: 'im.axi.axichat.APP_ICON'),
        callback: startCallback,
        notificationInitialRoute: '/',
      );
    } on Exception catch (error) {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
      throw ForegroundServiceUnavailableException(error);
    }

    if (startResult is! ServiceRequestSuccess) {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
      final error =
          startResult is ServiceRequestFailure ? startResult.error : null;
      throw ForegroundServiceUnavailableException(
        error is Exception ? error : null,
      );
    }

    _sendToTask([
      connectPrefix,
      domain,
      serverLookup[domain]!.host.address,
      serverLookup[domain]!.port,
    ]);
    return _connect.future;
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
    if (!await FlutterForegroundTask.isRunningService) return;
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    await FlutterForegroundTask.stopService();
  }
}

var _foregroundLoggerConfigured = false;

void _configureLogging() {
  if (_foregroundLoggerConfigured) return;
  _foregroundLoggerConfigured = true;

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
