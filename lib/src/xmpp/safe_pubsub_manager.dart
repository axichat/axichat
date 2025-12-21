import 'package:axichat/src/xmpp/pubsub_events.dart';
import 'package:axichat/src/xmpp/pubsub_forms.dart';
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
  static const String _messageTag = 'message';
  static const String _eventTag = 'event';
  static const String _itemsTag = 'items';
  static const String _itemTag = 'item';
  static const String _retractTag = 'retract';
  static const String _subscriptionTag = 'subscription';
  static const String _configurationTag = 'configuration';
  static const String _nodeAttr = 'node';
  static const String _jidAttr = 'jid';
  static const String _subIdAttr = 'subid';
  static const String _subscriptionAttr = 'subscription';
  static const String _dataFormTag = 'x';
  static const String _dataFormXmlns = 'jabber:x:data';
  static const String _pubsubEventXmlns =
      'http://jabber.org/protocol/pubsub#event';
  static const String _pubsubOwnerXmlns =
      'http://jabber.org/protocol/pubsub#owner';
  static const String _pubsubTag = 'pubsub';
  static const String _configureTag = 'configure';

  final Map<_SubscriptionCacheKey, mox.SubscriptionInfo> _subscriptionCache =
      {};

  @override
  List<mox.StanzaHandler> getIncomingStanzaHandlers() =>
      super.getIncomingStanzaHandlers()
        ..add(
          mox.StanzaHandler(
            stanzaTag: _messageTag,
            tagName: _eventTag,
            tagXmlns: _pubsubEventXmlns,
            callback: _onPubSubEvent,
          ),
        );

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
    _recordSubscription(subscriptionInfo);
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
    if (!result.isType<mox.PubSubError>()) {
      _removeSubscription(
        jid: jid.toString(),
        node: node,
        subId: subId,
      );
    }
    return result;
  }

  Future<moxlib.Result<mox.PubSubError, bool>> configureNode(
    mox.JID jid,
    String node,
    AxiPubSubNodeConfig config,
  ) async {
    return configureNodeWithForm(jid, node, config.toForm());
  }

  Future<moxlib.Result<mox.PubSubError, bool>> configureNodeWithForm(
    mox.JID jid,
    String node,
    mox.XMLNode form,
  ) async {
    final attrs = getAttributes();
    final result = await attrs.sendStanza(
      mox.StanzaDetails(
        mox.Stanza.iq(
          type: _iqSet,
          to: jid.toString(),
          children: [
            (mox.XmlBuilder.withNamespace(_pubsubTag, _pubsubOwnerXmlns)
                  ..child(
                    (mox.XmlBuilder(_configureTag)
                          ..attr(_nodeAttr, node)
                          ..child(form))
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

    return const moxlib.Result(true);
  }

  Future<mox.StanzaHandlerData> _onPubSubEvent(
    mox.Stanza message,
    mox.StanzaHandlerData state,
  ) async {
    final event = message.firstTag(_eventTag, xmlns: _pubsubEventXmlns);
    if (event == null) return state;

    final fromRaw = message.from;
    if (fromRaw == null || fromRaw.trim().isEmpty) return state;

    late final mox.JID from;
    try {
      from = mox.JID.fromString(fromRaw);
    } on Exception {
      return state;
    }

    final subscription = event.firstTag(_subscriptionTag);
    if (subscription != null) {
      _handleSubscriptionEvent(subscription, from);
    }

    final configuration = event.firstTag(_configurationTag);
    if (configuration != null) {
      _handleConfigurationEvent(configuration, from);
    }

    final items = event.firstTag(_itemsTag);
    if (items != null) {
      final hasItem = items.findTags(_itemTag).isNotEmpty;
      final hasRetract = items.findTags(_retractTag).isNotEmpty;
      if (!hasItem && !hasRetract) {
        final node = items.attributes[_nodeAttr]?.toString().trim();
        if (node != null && node.isNotEmpty) {
          getAttributes().sendEvent(
            PubSubItemsRefreshedEvent(
              from: from,
              node: node,
            ),
          );
        }
      }
    }

    return state;
  }

  void _handleSubscriptionEvent(mox.XMLNode subscription, mox.JID from) {
    final node = subscription.attributes[_nodeAttr]?.toString().trim();
    if (node == null || node.isEmpty) return;

    final subscriberJid = subscription.attributes[_jidAttr]?.toString();
    final state = mox.SubscriptionState.fromString(
          subscription.attributes[_subscriptionAttr]?.toString(),
        ) ??
        mox.SubscriptionState.subscribed;
    final subId = subscription.attributes[_subIdAttr]?.toString();

    final info = mox.SubscriptionInfo(
      jid: subscriberJid ?? '',
      node: node,
      state: state,
      subId: subId,
    );

    if (subscriberJid != null && subscriberJid.isNotEmpty) {
      _recordSubscription(info);
    }

    getAttributes().sendEvent(
      PubSubSubscriptionChangedEvent(
        from: from,
        node: node,
        subscriberJid: subscriberJid,
        state: state,
        subId: subId,
      ),
    );
  }

  void _handleConfigurationEvent(mox.XMLNode configuration, mox.JID from) {
    final node = configuration.attributes[_nodeAttr]?.toString().trim();
    if (node == null || node.isEmpty) return;

    final form = configuration.firstTag(
      _dataFormTag,
      xmlns: _dataFormXmlns,
    );

    getAttributes().sendEvent(
      PubSubSubscriptionConfigChangedEvent(
        from: from,
        node: node,
        dataForm: form,
      ),
    );
  }

  void _recordSubscription(mox.SubscriptionInfo info) {
    if (info.state == mox.SubscriptionState.none) {
      _removeSubscription(
        jid: info.jid,
        node: info.node,
        subId: info.subId,
      );
      return;
    }
    final key = _SubscriptionCacheKey(
      jid: info.jid,
      node: info.node,
      subId: info.subId,
    );
    _subscriptionCache[key] = info;
    subscriptionManager.addSubscription(info);
  }

  void _removeSubscription({
    required String jid,
    required String node,
    String? subId,
  }) {
    final key = _SubscriptionCacheKey(
      jid: jid,
      node: node,
      subId: subId,
    );
    _subscriptionCache.remove(key);
  }
}

final class _SubscriptionCacheKey {
  const _SubscriptionCacheKey({
    required this.jid,
    required this.node,
    required this.subId,
  });

  final String jid;
  final String node;
  final String? subId;

  @override
  bool operator ==(Object other) =>
      other is _SubscriptionCacheKey &&
      other.jid == jid &&
      other.node == node &&
      other.subId == subId;

  @override
  int get hashCode => Object.hash(jid, node, subId);
}
