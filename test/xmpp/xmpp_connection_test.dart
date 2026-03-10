import 'dart:async';

import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

class _SpyXmppConnection extends XmppConnection {
  _SpyXmppConnection();

  String? lastManagerId;

  @override
  T? getManagerById<T extends mox.XmppManagerBase>(String id) {
    lastManagerId = id;
    return null;
  }
}

class _BlockingForegroundSocketWrapper extends ForegroundSocketWrapper {
  _BlockingForegroundSocketWrapper();

  final Completer<void> resetStarted = Completer<void>();
  final Completer<void> allowReset = Completer<void>();

  @override
  Future<void> reset() async {
    if (!resetStarted.isCompleted) {
      resetStarted.complete();
    }
    await allowReset.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('XmppConnection.getManager resolves UserAvatarManager id', () {
    final connection = _SpyXmppConnection();

    connection.getManager<mox.UserAvatarManager>();

    expect(connection.lastManagerId, equals(mox.userAvatarManager));
  });

  test('XmppConnection.getManager resolves VCardManager id', () {
    final connection = _SpyXmppConnection();

    connection.getManager<mox.VCardManager>();

    expect(connection.lastManagerId, equals(mox.vcardManager));
  });

  test('XmppConnection.reset awaits foreground socket cleanup', () async {
    final socket = _BlockingForegroundSocketWrapper();
    final connection = XmppConnection(socketWrapper: socket);

    var completed = false;
    final resetFuture = connection.reset();
    resetFuture.then((_) => completed = true);

    await socket.resetStarted.future;
    await pumpEventQueue();
    expect(completed, isFalse);

    socket.allowReset.complete();
    await resetFuture;

    expect(completed, isTrue);
  });
}
