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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'XmppConnection.getManager resolves UserAvatarManager id',
    () {
      final connection = _SpyXmppConnection();

      connection.getManager<mox.UserAvatarManager>();

      expect(connection.lastManagerId, equals(mox.userAvatarManager));
    },
  );

  test(
    'XmppConnection.getManager resolves VCardManager id',
    () {
      final connection = _SpyXmppConnection();

      connection.getManager<mox.VCardManager>();

      expect(connection.lastManagerId, equals(mox.vcardManager));
    },
  );
}
