import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:moxxmpp_socket_tcp/moxxmpp_socket_tcp.dart' as mox_tcp;

class ForegroundSocket extends TaskHandler {
  final _socket = XmppSocketWrapper();

  @override
  void onStart(DateTime timestamp) {
    // TODO: implement onStart
  }

  @override
  void onReceiveData(Object data) {
    // TODO: implement onReceiveData
    super.onReceiveData(data);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // TODO: implement onRepeatEvent
  }

  @override
  void onDestroy(DateTime timestamp) {
    // TODO: implement onDestroy
  }
}

class ForegroundSocketWrapper implements XmppSocketWrapper {
  var _secure = false;

  @override
  bool isSecure() => _secure;

  @override
  bool managesKeepalives() => false;

  @override
  Stream<String> getDataStream() {
    // TODO: implement getDataStream
    throw UnimplementedError();
  }

  @override
  Stream<mox.XmppSocketEvent> getEventStream() {
    // TODO: implement getEventStream
    throw UnimplementedError();
  }

  @override
  bool onBadCertificate(certificate, String domain) {
    // TODO: implement onBadCertificate
    throw UnimplementedError();
  }

  @override
  Future<bool> secure(String domain) {
    // FlutterForegroundTask.sendDataToTask('Secure::$domain');
    throw UnimplementedError();
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
    FlutterForegroundTask.sendDataToTask('Connect::'
        '$domain::'
        '${serverLookup[domain]!.host.address}::'
        '${serverLookup[domain]!.port}');
    return true;
  }

  @override
  void write(String data) {
    FlutterForegroundTask.sendDataToTask('Write::$data');
  }

  @override
  void close() {
    FlutterForegroundTask.sendDataToTask('Close');
  }

  @override
  void destroy() {
    FlutterForegroundTask.sendDataToTask('Destroy');
  }

  @override
  void prepareDisconnect() {}
}
