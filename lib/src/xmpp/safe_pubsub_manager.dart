import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;

/// Compatibility wrapper for moxxmpp's [mox.PubSubManager].
///
/// Some servers return an empty `<iq type='result'/>` for publish requests. The
/// base implementation currently treats that as a malformed response even though
/// the publish succeeded at the IQ level.
class SafePubSubManager extends mox.PubSubManager {
  SafePubSubManager();

  static const String _iqSet = 'set';
  static const String _iqResult = 'result';

  Future<moxlib.Result<mox.PubSubError, bool>> publishRaw(
    mox.JID jid,
    String node,
    mox.XMLNode payload, {
    String? id,
    mox.PubSubPublishOptions? options,
    bool autoCreate = false,
    mox.NodeConfig? createNodeConfig,
  }) async {
    return super.publish(
      jid,
      node,
      payload,
      id: id,
      options: options,
      autoCreate: autoCreate,
      createNodeConfig: createNodeConfig,
    );
  }

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
    final result = await publishRaw(
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

  @override
  Future<moxlib.Result<mox.PubSubError, mox.SubscriptionInfo>> subscribe(
    mox.JID jid,
    String node,
  ) async {
    final attrs = getAttributes();
    final subscriberJid = attrs.getFullJID().toBare().toString();
    final result = await attrs.sendStanza(
      mox.StanzaDetails(
        mox.Stanza.iq(
          type: _iqSet,
          to: jid.toString(),
          children: [
            (mox.XmlBuilder.withNamespace('pubsub', mox.pubsubXmlns)
                  ..child(
                    (mox.XmlBuilder('subscribe')
                          ..attr('jid', subscriberJid)
                          ..attr('node', node))
                        .build(),
                  ))
                .build(),
          ],
        ),
        shouldEncrypt: false,
      ),
    );

    if (result == null) {
      return moxlib.Result(mox.UnknownPubSubError());
    }

    if (result.attributes['type'] != _iqResult) {
      return moxlib.Result(mox.getPubSubError(result));
    }

    final pubsub = result.firstTag('pubsub', xmlns: mox.pubsubXmlns);
    final subscription = pubsub?.firstTag('subscription');
    final state = mox.SubscriptionState.fromString(
          subscription?.attributes['subscription'] as String?,
        ) ??
        mox.SubscriptionState.subscribed;
    final subId = subscription?.attributes['subid'] as String?;

    final subscriptionInfo = mox.SubscriptionInfo(
      jid: subscriberJid,
      node: node,
      state: state,
      subId: subId,
    );
    subscriptionManager.addSubscription(subscriptionInfo);
    return moxlib.Result(subscriptionInfo);
  }

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> unsubscribe(
    mox.JID jid,
    String node, {
    String? subId,
  }) async {
    final result = await super.unsubscribe(jid, node, subId: subId);
    if (result.isType<mox.PubSubError>() &&
        result.get<mox.PubSubError>() is mox.MalformedResponseError) {
      return const moxlib.Result(true);
    }
    return result;
  }
}
