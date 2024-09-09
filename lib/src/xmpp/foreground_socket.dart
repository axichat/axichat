import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart'
    hide NotificationPermission;
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
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

@pragma("vm:entry-point")
Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
  FlutterForegroundTask.launchApp('/');
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
    _log.info('Sending to main: $data');
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
  void onStart(DateTime timestamp) {
    _log.info('onStart called.');
    _socket ??= XmppSocketWrapper();
    _dataSubscription = _socket!.getDataStream().listen(_onData);
    _eventSubscription = _socket!.getEventStream().listen(_onEvent);
  }

  @override
  void onReceiveData(covariant String data) async {
    _log.info('Received task: $data');
    _socket ??= XmppSocketWrapper();
    if (data.startsWith('$connectPrefix$join')) {
      final split = data.split(join);
      _log.info(split);
      final result = await _socket!.connect(
        split[1],
        host: split[2],
        port: int.parse(split[3]),
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
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  void onDestroy(DateTime timestamp) async {
    _socket?.close();
    _socket = null;
    await _dataSubscription.cancel();
    await _eventSubscription.cancel();
  }
}

class ForegroundSocketWrapper implements XmppSocketWrapper {
  static final _log = Logger('ForegroundSocketWrapper');

  final StreamController<String> _dataStream = StreamController.broadcast();
  final StreamController<mox.XmppSocketEvent> _eventStream =
      StreamController.broadcast();

  var _connect = Completer<bool>();
  var _secure = Completer<bool>();

  Future<void> _onReceiveTaskData(Object data) async {
    if (data is! String) return;
    _log.info('Received main: $data');
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
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Axichat Message Service',
      notificationText: 'Return to the app',
      notificationIcon: null,
      callback: startCallback,
    );

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
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
