// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/xmpp/pubsub_error_extensions.dart';
import 'package:axichat/src/xmpp/pubsub_events.dart';
import 'package:axichat/src/xmpp/pubsub_forms.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
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
  static const String _iqGet = 'get';
  static const String _iqResult = 'result';
  static const String _messageTag = 'message';
  static const String _eventTag = 'event';
  static const String _itemsTag = 'items';
  static const String _itemTag = 'item';
  static const String _retractTag = 'retract';
  static const String _subscriptionTag = 'subscription';
  static const String _configurationTag = 'configuration';
  static const String _affiliationsTag = 'affiliations';
  static const String _affiliationTag = 'affiliation';
  static const String _nodeAttr = 'node';
  static const String _bookmarksNode = 'urn:xmpp:bookmarks:1';
  static const String _conversationIndexNode = 'urn:axi:conversations';
  static const String _draftsNode = 'urn:axi:drafts';
  static const String _spamNode = 'urn:axi:spam';
  static const String _emailBlocklistNode = 'urn:axi:email-blocklist';
  static const String _jidAttr = 'jid';
  static const String _subIdAttr = 'subid';
  static const String _subscriptionAttr = 'subscription';
  static const String _affiliationAttr = 'affiliation';
  static const String _dataFormTag = 'x';
  static const String _dataFormXmlns = 'jabber:x:data';
  static const String _pubsubEventXmlns =
      'http://jabber.org/protocol/pubsub#event';
  static const String _pubsubOwnerXmlns =
      'http://jabber.org/protocol/pubsub#owner';
  static const String _pubsubTag = 'pubsub';
  static const String _configureTag = 'configure';
  static const String _defaultTag = 'default';
  static const String _nodeUnknownLabel = '<unknown>';
  static const String _nodeRedactedLabel = '<redacted>';
  static const String _nodeJidMarker = '@';

  final Map<_SubscriptionCacheKey, mox.SubscriptionInfo> _subscriptionCache =
      {};
  final Map<_SendLastCacheKey, String?> _sendLastValueCache = {};
  final Map<_SendLastCacheKey, Future<String?>> _sendLastValueInFlight = {};
  final Map<String, String?> _sendLastDefaultCache = {};

  XmppOperationKind _operationKindForNode(String? node) {
    final trimmed = node?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return XmppOperationKind.pubSubFetch;
    }
    return switch (trimmed) {
      _bookmarksNode => XmppOperationKind.pubSubBookmarks,
      _conversationIndexNode => XmppOperationKind.pubSubConversations,
      _draftsNode => XmppOperationKind.pubSubDrafts,
      _spamNode => XmppOperationKind.pubSubSpam,
      _emailBlocklistNode => XmppOperationKind.pubSubEmailBlocklist,
      mox.userAvatarMetadataXmlns => XmppOperationKind.pubSubAvatarMetadata,
      mox.userAvatarDataXmlns => XmppOperationKind.pubSubAvatarMetadata,
      _ => XmppOperationKind.pubSubFetch,
    };
  }

  XmppOperationEvent _operationStartEvent(XmppOperationKind kind) =>
      XmppOperationEvent(kind: kind, stage: XmppOperationStage.start);

  XmppOperationEvent _operationEndEvent(
    XmppOperationKind kind, {
    required bool isSuccess,
  }) =>
      XmppOperationEvent(
        kind: kind,
        stage: XmppOperationStage.end,
        isSuccess: isSuccess,
      );

  String _safeNodeLabel(String? node) {
    final trimmed = node?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return _nodeUnknownLabel;
    }
    if (trimmed.contains(_nodeJidMarker)) {
      return _nodeRedactedLabel;
    }
    return trimmed;
  }

  @override
  List<mox.StanzaHandler> getIncomingStanzaHandlers() {
    return [
      mox.StanzaHandler(
        stanzaTag: _messageTag,
        tagName: _eventTag,
        tagXmlns: _pubsubEventXmlns,
        callback: _onPubSubEvent,
      ),
      ...super.getIncomingStanzaHandlers(),
    ];
  }

  Future<moxlib.Result<mox.PubSubError, bool>> publishRaw(
    mox.JID jid,
    String node,
    mox.XMLNode payload, {
    String? id,
    mox.PubSubPublishOptions? options,
    bool autoCreate = false,
    mox.NodeConfig? createNodeConfig,
  }) async {
    logger.fine('PubSub publish start. node=${_safeNodeLabel(node)}.');
    final operationKind = _operationKindForNode(node);
    final attrs = getAttributes()
      ..sendEvent(_operationStartEvent(operationKind));
    var success = false;
    try {
      final result = await super.publish(
        jid,
        node,
        payload,
        id: id,
        options: options,
        autoCreate: autoCreate,
        createNodeConfig: createNodeConfig,
      );
      if (result.isType<mox.PubSubError>()) {
        final error = result.get<mox.PubSubError>();
        final acceptedMalformed = error is mox.MalformedResponseError;
        success = acceptedMalformed;
        if (acceptedMalformed) {
          logger.fine(
            'PubSub publish accepted malformed response. '
            'node=${_safeNodeLabel(node)}.',
          );
        } else {
          logger.fine(
            'PubSub publish failed. node=${_safeNodeLabel(node)} '
            'error=${error.runtimeType}.',
          );
        }
      } else {
        success = true;
        logger.fine('PubSub publish succeeded. node=${_safeNodeLabel(node)}.');
      }
      return result;
    } finally {
      attrs.sendEvent(_operationEndEvent(operationKind, isSuccess: success));
    }
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
    logger.fine('PubSub subscribe start. node=${_safeNodeLabel(node)}.');
    final operationKind = _operationKindForNode(node);
    final attrs = getAttributes()
      ..sendEvent(_operationStartEvent(operationKind));
    final subscriberJid = attrs.getFullJID().toBare().toString();
    var success = false;
    try {
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
        logger.fine('PubSub subscribe failed: null response.');
        return moxlib.Result(mox.UnknownPubSubError());
      }

      if (result.attributes['type'] != _iqResult) {
        logger.fine('PubSub subscribe failed: error response.');
        return moxlib.Result(mox.getPubSubError(result));
      }

      final pubsub = result.firstTag('pubsub', xmlns: mox.pubsubXmlns);
      if (pubsub == null) {
        logger.fine('PubSub subscribe failed: missing pubsub element.');
        return moxlib.Result(mox.UnknownPubSubError());
      }
      final subscription = pubsub.firstTag('subscription');
      if (subscription == null) {
        logger.fine('PubSub subscribe failed: missing subscription element.');
        return moxlib.Result(mox.UnknownPubSubError());
      }
      final state = mox.SubscriptionState.fromString(
            subscription.attributes['subscription'] as String?,
          ) ??
          mox.SubscriptionState.none;
      final subId = subscription.attributes['subid'] as String?;
      final configurationRequired =
          subscription.attributes['subscription'] == 'unconfigured';

      final subscriptionInfo = mox.SubscriptionInfo(
        jid: subscriberJid,
        node: node,
        state: state,
        subId: subId,
        configurationRequired: configurationRequired,
      );
      _recordSubscription(subscriptionInfo);
      logger.fine('PubSub subscribe succeeded. node=${_safeNodeLabel(node)}.');
      success = true;
      return moxlib.Result(subscriptionInfo);
    } finally {
      attrs.sendEvent(_operationEndEvent(operationKind, isSuccess: success));
    }
  }

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> unsubscribe(
    mox.JID jid,
    String node, {
    String? subId,
  }) async {
    logger.fine('PubSub unsubscribe start. node=${_safeNodeLabel(node)}.');
    final operationKind = _operationKindForNode(node);
    final attrs = getAttributes()
      ..sendEvent(_operationStartEvent(operationKind));
    final subscriberJid = attrs.getFullJID().toBare().toString();
    var success = false;
    try {
      final result = await super.unsubscribe(jid, node, subId: subId);
      if (result.isType<mox.PubSubError>()) {
        final error = result.get<mox.PubSubError>();
        if (error is mox.MalformedResponseError) {
          logger.fine(
            'PubSub unsubscribe accepted malformed response. '
            'node=${_safeNodeLabel(node)}.',
          );
          success = true;
          return const moxlib.Result(true);
        }
        logger.fine(
          'PubSub unsubscribe failed. node=${_safeNodeLabel(node)} '
          'error=${error.runtimeType}.',
        );
        return result;
      }
      _removeSubscription(jid: subscriberJid, node: node, subId: subId);
      logger
          .fine('PubSub unsubscribe succeeded. node=${_safeNodeLabel(node)}.');
      success = true;
      return result;
    } finally {
      attrs.sendEvent(_operationEndEvent(operationKind, isSuccess: success));
    }
  }

  Future<moxlib.Result<mox.PubSubError, bool>> configureNode(
    mox.JID jid,
    String node,
    AxiPubSubNodeConfig config,
  ) async {
    logger.fine('PubSub configure start. node=${_safeNodeLabel(node)}.');
    return configureNodeWithForm(jid, node, config.toForm());
  }

  Future<moxlib.Result<mox.PubSubError, bool>> configureNodeWithForm(
    mox.JID jid,
    String node,
    mox.XMLNode form,
  ) async {
    final operationKind = _operationKindForNode(node);
    final attrs = getAttributes()
      ..sendEvent(_operationStartEvent(operationKind));
    var success = false;
    try {
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
        logger.fine('PubSub configure failed: null response.');
        return moxlib.Result(mox.UnknownPubSubError());
      }

      if (result.attributes['type'] != _iqResult) {
        final error = mox.getPubSubError(result);
        logger.fine(
          'PubSub configure failed. node=${_safeNodeLabel(node)} '
          'error=${error.runtimeType} missingNode=${error.indicatesMissingNode}.',
        );
        return moxlib.Result(error);
      }

      logger.fine('PubSub configure succeeded. node=${_safeNodeLabel(node)}.');
      success = true;
      return const moxlib.Result(true);
    } finally {
      attrs.sendEvent(_operationEndEvent(operationKind, isSuccess: success));
    }
  }

  Future<String?> resolveSendLastPublishedItemForNode({
    required mox.JID host,
    required String node,
  }) async {
    final key = _SendLastCacheKey(host: host.toString(), node: node);
    if (_sendLastValueCache.containsKey(key)) {
      return _sendLastValueCache[key];
    }
    final inFlight = _sendLastValueInFlight[key];
    if (inFlight != null) {
      return inFlight;
    }
    final future = _resolveSendLastPublishedItemForNode(
      host: host,
      node: node,
    );
    _sendLastValueInFlight[key] = future;
    try {
      final value = await future;
      _sendLastValueCache[key] = value;
      return value;
    } finally {
      _sendLastValueInFlight.remove(key);
    }
  }

  Future<String?> _resolveSendLastPublishedItemForNode({
    required mox.JID host,
    required String node,
  }) async {
    final nodeForm = await _fetchNodeConfigForm(host: host, node: node);
    if (nodeForm != null) {
      final value = resolveSendLastPublishedItemValue(nodeForm);
      if (value != null) {
        logger.fine(
          'PubSub send_last resolved. node=${_safeNodeLabel(node)} '
          'value=$value.',
        );
      }
      return value;
    }
    final defaultValue = await _resolveDefaultSendLastPublishedItem(host);
    if (defaultValue != null) {
      logger.fine(
        'PubSub send_last resolved from default form. '
        'node=${_safeNodeLabel(node)} value=$defaultValue.',
      );
    }
    return defaultValue;
  }

  Future<String?> _resolveDefaultSendLastPublishedItem(mox.JID host) async {
    final cacheKey = host.toString();
    if (_sendLastDefaultCache.containsKey(cacheKey)) {
      return _sendLastDefaultCache[cacheKey];
    }
    final form = await _fetchDefaultNodeConfigForm(host: host);
    if (form == null) {
      return null;
    }
    final value = resolveSendLastPublishedItemValue(form);
    _sendLastDefaultCache[cacheKey] = value;
    return value;
  }

  Future<mox.XMLNode?> _fetchNodeConfigForm({
    required mox.JID host,
    required String node,
  }) async {
    final result = await getAttributes().sendStanza(
      mox.StanzaDetails(
        mox.Stanza.iq(
          type: _iqGet,
          to: host.toString(),
          children: [
            (mox.XmlBuilder.withNamespace(_pubsubTag, _pubsubOwnerXmlns)
                  ..child(
                    (mox.XmlBuilder(_configureTag)..attr(_nodeAttr, node))
                        .build(),
                  ))
                .build(),
          ],
        ),
        shouldEncrypt: false,
      ),
    );
    if (result == null) {
      logger.fine(
        'PubSub config form fetch failed: null response. '
        'node=${_safeNodeLabel(node)}.',
      );
      return null;
    }
    if (result.attributes['type'] != _iqResult) {
      final error = mox.getPubSubError(result);
      logger.fine(
        'PubSub config form fetch failed. node=${_safeNodeLabel(node)} '
        'error=${error.runtimeType} missingNode=${error.indicatesMissingNode}.',
      );
      return null;
    }
    final pubsub = result.firstTag(_pubsubTag, xmlns: _pubsubOwnerXmlns);
    final configure = pubsub?.firstTag(_configureTag);
    final form = configure?.firstTag(_dataFormTag, xmlns: _dataFormXmlns);
    if (form == null) {
      logger.fine(
        'PubSub config form missing. node=${_safeNodeLabel(node)}.',
      );
    }
    return form;
  }

  Future<mox.XMLNode?> _fetchDefaultNodeConfigForm({
    required mox.JID host,
  }) async {
    final result = await getAttributes().sendStanza(
      mox.StanzaDetails(
        mox.Stanza.iq(
          type: _iqGet,
          to: host.toString(),
          children: [
            (mox.XmlBuilder.withNamespace(_pubsubTag, _pubsubOwnerXmlns)
                  ..child(mox.XmlBuilder(_defaultTag).build()))
                .build(),
          ],
        ),
        shouldEncrypt: false,
      ),
    );
    if (result == null) {
      logger.fine('PubSub default config form fetch failed: null response.');
      return null;
    }
    if (result.attributes['type'] != _iqResult) {
      final error = mox.getPubSubError(result);
      logger.fine(
        'PubSub default config form fetch failed. error=${error.runtimeType}.',
      );
      return null;
    }
    final pubsub = result.firstTag(_pubsubTag, xmlns: _pubsubOwnerXmlns);
    final defaults = pubsub?.firstTag(_defaultTag);
    final form = defaults?.firstTag(_dataFormTag, xmlns: _dataFormXmlns);
    if (form == null) {
      logger.fine('PubSub default config form missing.');
    }
    return form;
  }

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> setAffiliations(
    mox.JID jid,
    String node,
    Map<String, mox.PubSubAffiliation> affiliations,
  ) async {
    if (affiliations.isEmpty) {
      return const moxlib.Result(true);
    }
    logger.fine(
      'PubSub setAffiliations start. node=${_safeNodeLabel(node)} '
      'count=${affiliations.length}.',
    );
    final affiliationNodes = <mox.XMLNode>[];
    for (final entry in affiliations.entries) {
      final targetJid = entry.key.trim();
      final affiliationValue = entry.value.value.trim();
      if (targetJid.isEmpty || affiliationValue.isEmpty) {
        continue;
      }
      affiliationNodes.add(
        mox.XMLNode(
          tag: _affiliationTag,
          attributes: {_jidAttr: targetJid, _affiliationAttr: affiliationValue},
        ),
      );
    }
    if (affiliationNodes.isEmpty) {
      return const moxlib.Result(true);
    }
    final operationKind = _operationKindForNode(node);
    final attrs = getAttributes()
      ..sendEvent(_operationStartEvent(operationKind));
    var success = false;
    final affiliationsBuilder = mox.XmlBuilder(_affiliationsTag)
      ..attr(_nodeAttr, node);
    for (final node in affiliationNodes) {
      affiliationsBuilder.child(node);
    }
    try {
      final result = await attrs.sendStanza(
        mox.StanzaDetails(
          mox.Stanza.iq(
            type: _iqSet,
            to: jid.toString(),
            children: [
              (mox.XmlBuilder.withNamespace(
                _pubsubTag,
                _pubsubOwnerXmlns,
              )..child(affiliationsBuilder.build()))
                  .build(),
            ],
          ),
          shouldEncrypt: false,
        ),
      );

      if (result == null) {
        logger.fine('PubSub setAffiliations failed: null response.');
        return moxlib.Result(mox.UnknownPubSubError());
      }

      if (result.attributes['type'] != _iqResult) {
        logger.fine('PubSub setAffiliations failed: error response.');
        return moxlib.Result(mox.getPubSubError(result));
      }

      logger.fine(
        'PubSub setAffiliations succeeded. node=${_safeNodeLabel(node)}.',
      );
      success = true;
      return const moxlib.Result(true);
    } finally {
      attrs.sendEvent(_operationEndEvent(operationKind, isSuccess: success));
    }
  }

  @override
  Future<moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>> getItems(
    mox.JID jid,
    String node, {
    int? maxItems,
  }) async {
    logger.fine('PubSub getItems start. node=${_safeNodeLabel(node)}.');
    final operationKind = _operationKindForNode(node);
    final attrs = getAttributes()
      ..sendEvent(_operationStartEvent(operationKind));
    var success = false;
    try {
      final result = await super.getItems(jid, node, maxItems: maxItems);
      success = !result.isType<mox.PubSubError>();
      if (!success) {
        logger.fine(
          'PubSub getItems failed. node=${_safeNodeLabel(node)} '
          'error=${result.get<mox.PubSubError>().runtimeType}.',
        );
        return result;
      }
      final items = result.get<List<mox.PubSubItem>>();
      logger.fine(
        'PubSub getItems succeeded. node=${_safeNodeLabel(node)} '
        'count=${items.length}.',
      );
      return result;
    } finally {
      attrs.sendEvent(_operationEndEvent(operationKind, isSuccess: success));
    }
  }

  @override
  Future<moxlib.Result<mox.PubSubError, mox.PubSubItem>> getItem(
    mox.JID jid,
    String node,
    String id,
  ) async {
    logger.fine('PubSub getItem start. node=${_safeNodeLabel(node)}.');
    final operationKind = _operationKindForNode(node);
    final attrs = getAttributes()
      ..sendEvent(_operationStartEvent(operationKind));
    var success = false;
    try {
      final result = await super.getItem(jid, node, id);
      success = !result.isType<mox.PubSubError>();
      if (!success) {
        logger.fine(
          'PubSub getItem failed. node=${_safeNodeLabel(node)} '
          'error=${result.get<mox.PubSubError>().runtimeType}.',
        );
      } else {
        logger.fine('PubSub getItem succeeded. node=${_safeNodeLabel(node)}.');
      }
      return result;
    } finally {
      attrs.sendEvent(_operationEndEvent(operationKind, isSuccess: success));
    }
  }

  @override
  Future<String?> createNode(mox.JID jid, {String? nodeId}) async {
    logger.fine(
      'PubSub createNode start. node=${_safeNodeLabel(nodeId)}.',
    );
    final operationKind = _operationKindForNode(nodeId);
    final attrs = getAttributes()
      ..sendEvent(_operationStartEvent(operationKind));
    var success = false;
    try {
      final result = await super.createNode(jid, nodeId: nodeId);
      success = result != null;
      if (result == null) {
        logger.fine(
          'PubSub createNode failed. node=${_safeNodeLabel(nodeId)}.',
        );
      } else {
        logger.fine(
          'PubSub createNode succeeded. node=${_safeNodeLabel(nodeId)}.',
        );
      }
      return result;
    } finally {
      attrs.sendEvent(_operationEndEvent(operationKind, isSuccess: success));
    }
  }

  @override
  Future<String?> createNodeWithConfig(
    mox.JID jid,
    mox.NodeConfig config, {
    String? nodeId,
  }) async {
    logger.fine(
      'PubSub createNodeWithConfig start. node=${_safeNodeLabel(nodeId)}.',
    );
    final operationKind = _operationKindForNode(nodeId);
    final attrs = getAttributes()
      ..sendEvent(_operationStartEvent(operationKind));
    var success = false;
    try {
      final result = await super.createNodeWithConfig(
        jid,
        config,
        nodeId: nodeId,
      );
      success = result != null;
      if (result == null) {
        logger.fine(
          'PubSub createNodeWithConfig failed. '
          'node=${_safeNodeLabel(nodeId)}.',
        );
      } else {
        logger.fine(
          'PubSub createNodeWithConfig succeeded. '
          'node=${_safeNodeLabel(nodeId)}.',
        );
      }
      return result;
    } finally {
      attrs.sendEvent(_operationEndEvent(operationKind, isSuccess: success));
    }
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
          logger.fine(
            'PubSub items refresh event. node=${_safeNodeLabel(node)}.',
          );
          getAttributes().sendEvent(
            PubSubItemsRefreshedEvent(from: from, node: node),
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
    logger.fine(
      'PubSub subscription event. node=${_safeNodeLabel(node)} '
      'state=${state.value}.',
    );
  }

  void _handleConfigurationEvent(mox.XMLNode configuration, mox.JID from) {
    final node = configuration.attributes[_nodeAttr]?.toString().trim();
    if (node == null || node.isEmpty) return;

    final form = configuration.firstTag(_dataFormTag, xmlns: _dataFormXmlns);

    getAttributes().sendEvent(
      PubSubSubscriptionConfigChangedEvent(
        from: from,
        node: node,
        dataForm: form,
      ),
    );
    logger.fine(
      'PubSub configuration event. node=${_safeNodeLabel(node)}.',
    );
  }

  void _recordSubscription(mox.SubscriptionInfo info) {
    if (info.state == mox.SubscriptionState.none) {
      _removeSubscription(jid: info.jid, node: info.node, subId: info.subId);
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
    final key = _SubscriptionCacheKey(jid: jid, node: node, subId: subId);
    _subscriptionCache.remove(key);
    subscriptionManager.removeSubscription(jid, node, subId: subId);
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

final class _SendLastCacheKey {
  const _SendLastCacheKey({
    required this.host,
    required this.node,
  });

  final String host;
  final String node;

  @override
  bool operator ==(Object other) =>
      other is _SendLastCacheKey && other.host == host && other.node == node;

  @override
  int get hashCode => Object.hash(host, node);
}
