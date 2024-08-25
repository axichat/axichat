import 'dart:async';
import 'dart:io';

import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
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

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ForegroundSocket());
}

class ForegroundSocket extends TaskHandler {
  final _socket = XmppSocketWrapper();
  late final StreamSubscription<String> _dataSubscription;
  late final StreamSubscription<mox.XmppSocketEvent> _eventSubscription;

  static void _sendToMain(List<Object> strings) =>
      FlutterForegroundTask.sendDataToMain(strings.join(join));

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
    _dataSubscription = _socket.getDataStream().listen(_onData);
    _eventSubscription = _socket.getEventStream().listen(_onEvent);
  }

  @override
  void onReceiveData(covariant String data) async {
    if (data.startsWith('$connectPrefix$join')) {
      final split = data.split(join);
      final result = await _socket.connect(
        split[1],
        host: split[2],
        port: int.parse(split[3]),
      );
      return _sendToMain([connectPrefix, result]);
    } else if (data.startsWith('$securePrefix$join')) {
      final domain = data.substring('$securePrefix$join'.length);
      final result = await _socket.secure(domain);
      return _sendToMain([securePrefix, result]);
    } else if (data.startsWith('$writePrefix$join')) {
      return _socket.write(data.substring('$writePrefix$join'.length));
    } else if (data.startsWith('$closePrefix$join')) {
      return _socket.close();
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
    _socket.close();
    await _dataSubscription.cancel();
    await _eventSubscription.cancel();
  }
}

class ForegroundSocketWrapper implements XmppSocketWrapper {
  ForegroundSocketWrapper() {
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }

  final StreamController<String> _dataStream = StreamController.broadcast();
  final StreamController<mox.XmppSocketEvent> _eventStream =
      StreamController.broadcast();

  var _connect = Completer<bool>();
  var _secure = Completer<bool>();

  void _onReceiveTaskData(Object data) {
    if (data is! String) return;
    if (data.startsWith('$dataPrefix$join')) {
      _dataStream.add(data.substring('$dataPrefix$join'.length));
    } else if (data == socketErrorPrefix) {
      _eventStream.add(mox.XmppSocketErrorEvent(''));
    } else if (data.startsWith('$socketClosurePrefix$join')) {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
      FlutterForegroundTask.stopService();
      _eventStream
          .add(mox.XmppSocketClosureEvent(bool.parse(data.split(join)[1])));
    } else if (data.startsWith('$connectPrefix$join')) {
      _connect.complete(bool.parse(data.split(join)[1]));
      _connect = Completer<bool>();
    } else if (data.startsWith('$securePrefix$join')) {
      _secure.complete(bool.parse(data.split(join)[1]));
    }
  }

  static void _sendToTask(List<Object> strings) =>
      FlutterForegroundTask.sendDataToTask(strings.join(join));

  @override
  bool isSecure() => _secure.isCompleted;

  @override
  bool managesKeepalives() => false;

  @override
  Stream<String> getDataStream() => _dataStream.stream;

  @override
  Stream<mox.XmppSocketEvent> getEventStream() => _eventStream.stream;

  @override
  bool onBadCertificate(certificate, String domain) {
    // This will never be called.
    throw UnimplementedError();
  }

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
  Future<bool> connect(String domain, {String? host, int? port}) {
    _secure = Completer<bool>();
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
}

Future<bool> hasAllNotificationPermissions() async {
  return (await FlutterForegroundTask.checkNotificationPermission()) ==
          NotificationPermission.granted &&
      await FlutterForegroundTask.canDrawOverlays &&
      await FlutterForegroundTask.isIgnoringBatteryOptimizations;
}

Future<void> requestNotificationPermissions() async {
  final NotificationPermission notificationPermissionStatus =
      await FlutterForegroundTask.checkNotificationPermission();
  if (notificationPermissionStatus != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }

  if (Platform.isAndroid) {
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    if (!await FlutterForegroundTask.canDrawOverlays) {
      await FlutterForegroundTask.openSystemAlertWindowSettings();
    }
  }
}

void initForegroundService() => FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Foreground Service Notification',
        channelDescription:
            'This notification appears when the foreground service is running.',
        channelImportance: NotificationChannelImportance.DEFAULT,
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

Future<ServiceRequestResult> startForegroundService() async {
  if (await FlutterForegroundTask.isRunningService) {
    return FlutterForegroundTask.restartService();
  } else {
    return FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Axichat Message Service',
      notificationText: 'Return to the app',
      notificationIcon: null,
      callback: startCallback,
    );
  }
}
