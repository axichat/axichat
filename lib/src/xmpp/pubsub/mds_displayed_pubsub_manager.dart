// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/xmpp/pubsub/pep_item_pubsub_node_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_forms.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const String mdsDisplayedPubSubNode = 'urn:xmpp:mds:displayed:0';
const String mdsDisplayedNotifyFeature = 'urn:xmpp:mds:displayed:0+notify';

const String _displayedTag = 'displayed';
const String _stanzaIdTag = 'stanza-id';
const String _idAttr = 'id';
const String _byAttr = 'by';
const String _defaultMaxItems = 'max';
const int _fetchLimitFallback = 1000;
const Duration _ensureNodeBackoff = Duration(minutes: 5);
const String _bootstrapOperationName =
    'MdsDisplayedPubSubManager.bootstrapOnNegotiations';
const String _refreshOperationName =
    'MdsDisplayedPubSubManager.refreshFromServer';

final class MdsDisplayedPayload {
  const MdsDisplayedPayload({
    required this.chatJid,
    required this.serverStanzaId,
    required this.serverStanzaBy,
  });

  final String chatJid;
  final String serverStanzaId;
  final String serverStanzaBy;

  String get itemId => chatJid;

  static MdsDisplayedPayload? fromXml(mox.XMLNode node, {String? itemId}) {
    if (node.tag != _displayedTag ||
        node.attributes['xmlns']?.toString() != mdsDisplayedPubSubNode) {
      return null;
    }
    final chatJid = itemId?.trim();
    if (chatJid == null || chatJid.isEmpty) {
      return null;
    }
    final stanzaId = node.firstTag(_stanzaIdTag, xmlns: mox.stableIdXmlns);
    final id = stanzaId?.attributes[_idAttr]?.toString().trim();
    final by = stanzaId?.attributes[_byAttr]?.toString().trim();
    if (id == null || id.isEmpty || by == null || by.isEmpty) {
      return null;
    }
    return MdsDisplayedPayload(
      chatJid: chatJid,
      serverStanzaId: id,
      serverStanzaBy: by,
    );
  }

  mox.XMLNode toXml() {
    return mox.XMLNode.xmlns(
      tag: _displayedTag,
      xmlns: mdsDisplayedPubSubNode,
      children: [
        mox.XMLNode.xmlns(
          tag: _stanzaIdTag,
          xmlns: mox.stableIdXmlns,
          attributes: {
            _byAttr: (serverStanzaBy.trim()),
            _idAttr: (serverStanzaId.trim()),
          },
        ),
      ],
    );
  }
}

sealed class MdsDisplayedUpdate {
  const MdsDisplayedUpdate();
}

final class MdsDisplayedUpdated extends MdsDisplayedUpdate {
  const MdsDisplayedUpdated(this.payload);

  final MdsDisplayedPayload payload;
}

final class MdsDisplayedRetracted extends MdsDisplayedUpdate {
  const MdsDisplayedRetracted(this.chatJid);

  final String chatJid;
}

final class MdsDisplayedUpdatedEvent extends mox.XmppEvent {
  MdsDisplayedUpdatedEvent(this.payload);

  final MdsDisplayedPayload payload;
}

final class MdsDisplayedRetractedEvent extends mox.XmppEvent {
  MdsDisplayedRetractedEvent(this.chatJid);

  final String chatJid;
}

final class MdsDisplayedPubSubManager
    extends PepItemPubSubNodeManager<MdsDisplayedPayload>
    implements PubSubHubDelegate {
  MdsDisplayedPubSubManager({String? maxItems})
    : _maxItems = maxItems ?? _defaultMaxItems,
      super(managerId);

  static const String managerId = 'axi.mds.displayed';

  final String _maxItems;

  @override
  final SyncRateLimiter rateLimiter = SyncRateLimiter(settingsSyncRateLimit);

  final StreamController<MdsDisplayedUpdate> _updatesController =
      StreamController<MdsDisplayedUpdate>.broadcast();

  Stream<MdsDisplayedUpdate> get updates => _updatesController.stream;

  @override
  String get nodeId => mdsDisplayedPubSubNode;

  @override
  String get maxItemsValue => _maxItems;

  @override
  String get defaultMaxItemsValue => '$_fetchLimitFallback';

  @override
  String get sendLastPublishedItemValue =>
      SendLastPublishedItemSetting.never.value;

  @override
  Duration get ensureNodeBackoff => _ensureNodeBackoff;

  @override
  String get bootstrapOperationName => _bootstrapOperationName;

  @override
  String get refreshOperationName => _refreshOperationName;

  @override
  XmppOperationKind? get operationKind => null;

  @override
  List<mox.AccessModel> get candidateAccessModels => const <mox.AccessModel>[
    mox.AccessModel.whitelist,
  ];

  @override
  bool get publishAutoCreate => true;

  @override
  bool get treatMissingNodeAsEmptySnapshot => true;

  @override
  Future<void> close() async {
    if (_updatesController.isClosed) {
      return;
    }
    await _updatesController.close();
  }

  Future<bool> publishDisplayed(MdsDisplayedPayload payload) =>
      publishItem(payload);

  @override
  Future<({List<MdsDisplayedPayload> items, bool isSuccess, bool isComplete})>
  fetchAllWithStatus() async {
    final pubsub = getAttributes().getManagerById<mox.PubSubManager>(
      mox.pubsubManager,
    );
    final host = _selfPepHost();
    if (pubsub == null || host == null) {
      return (
        items: <MdsDisplayedPayload>[],
        isSuccess: false,
        isComplete: false,
      );
    }
    final result = await pubsub.getItems(host, nodeId);
    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      final missing =
          error is mox.ItemNotFoundError || error is mox.NoItemReturnedError;
      if (missing) {
        cache.clear();
        return (
          items: <MdsDisplayedPayload>[],
          isSuccess: true,
          isComplete: true,
        );
      }
      return (
        items: <MdsDisplayedPayload>[],
        isSuccess: false,
        isComplete: false,
      );
    }
    final parsed = <MdsDisplayedPayload>[];
    var hadParseFailure = false;
    for (final item in result.get<List<mox.PubSubItem>>()) {
      final payload = item.payload;
      if (payload == null) {
        hadParseFailure = true;
        continue;
      }
      final parsedPayload = parsePayload(payload, itemId: item.id);
      if (parsedPayload == null) {
        hadParseFailure = true;
        continue;
      }
      parsed.add(parsedPayload);
    }
    return (
      items: List<MdsDisplayedPayload>.unmodifiable(parsed),
      isSuccess: true,
      isComplete: !hadParseFailure,
    );
  }

  mox.JID? _selfPepHost() {
    try {
      return getAttributes().getConnectionSettings().jid.toBare();
    } on Exception {
      try {
        return getAttributes().getFullJID().toBare();
      } on Exception {
        return null;
      }
    }
  }

  @override
  MdsDisplayedPayload? parsePayload(mox.XMLNode payload, {String? itemId}) =>
      MdsDisplayedPayload.fromXml(payload, itemId: itemId);

  @override
  String itemIdOf(MdsDisplayedPayload payload) => payload.itemId;

  @override
  mox.XMLNode payloadToXml(MdsDisplayedPayload payload) => payload.toXml();

  @override
  void emitUpdatePayload(MdsDisplayedPayload payload) {
    if (!_updatesController.isClosed) {
      _updatesController.add(MdsDisplayedUpdated(payload));
    }
    getAttributes().sendEvent(MdsDisplayedUpdatedEvent(payload));
  }

  @override
  void emitRetractionId(String itemId) {
    if (!_updatesController.isClosed) {
      _updatesController.add(MdsDisplayedRetracted(itemId));
    }
    getAttributes().sendEvent(MdsDisplayedRetractedEvent(itemId));
  }
}
