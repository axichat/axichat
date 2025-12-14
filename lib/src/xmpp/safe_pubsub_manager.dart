import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;

/// Compatibility wrapper for moxxmpp's [mox.PubSubManager].
///
/// Some servers return an empty `<iq type='result'/>` for publish requests. The
/// base implementation currently treats that as a malformed response even though
/// the publish succeeded at the IQ level.
class SafePubSubManager extends mox.PubSubManager {
  SafePubSubManager();

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> publish(
    mox.JID jid,
    String node,
    mox.XMLNode payload, {
    String? id,
    mox.PubSubPublishOptions? options,
    bool autoCreate = false,
    mox.NodeConfig? createNodeConfig,
  }) async {
    final result = await super.publish(
      jid,
      node,
      payload,
      id: id,
      options: options,
      autoCreate: autoCreate,
      createNodeConfig: createNodeConfig,
    );
    if (result.isType<mox.PubSubError>() &&
        result.get<mox.PubSubError>() is mox.MalformedResponseError) {
      return const moxlib.Result(true);
    }
    return result;
  }
}

