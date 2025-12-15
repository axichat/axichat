import 'package:axichat/src/xmpp/safe_pubsub_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;

class _TestSafePubSubManager extends SafePubSubManager {
  _TestSafePubSubManager(this.rawResult);

  final moxlib.Result<mox.PubSubError, bool> rawResult;

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> publishRaw(
    mox.JID jid,
    String node,
    mox.XMLNode payload, {
    String? id,
    mox.PubSubPublishOptions? options,
    bool autoCreate = false,
    mox.NodeConfig? createNodeConfig,
  }) async {
    return rawResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SafePubSubManager treats MalformedResponseError as success',
    () async {
      final manager = _TestSafePubSubManager(
        moxlib.Result(mox.MalformedResponseError()),
      );
      final jid = mox.JID.fromString('pubsub.example.com');
      final payload = (mox.XmlBuilder('payload')..text('value')).build();

      final result = await manager.publish(jid, 'node', payload);

      expect(result.isType<mox.PubSubError>(), isFalse);
      expect(result.get<bool>(), isTrue);
    },
  );

  test(
    'SafePubSubManager passes through non-malformed errors',
    () async {
      final manager = _TestSafePubSubManager(
        moxlib.Result(mox.UnknownPubSubError()),
      );
      final jid = mox.JID.fromString('pubsub.example.com');
      final payload = (mox.XmlBuilder('payload')..text('value')).build();

      final result = await manager.publish(jid, 'node', payload);

      expect(result.isType<mox.PubSubError>(), isTrue);
      expect(result.get<mox.PubSubError>(), isA<mox.UnknownPubSubError>());
    },
  );
}
