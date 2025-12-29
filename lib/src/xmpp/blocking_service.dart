part of 'package:axichat/src/xmpp/xmpp_service.dart';

const String _blockingXmlns = 'urn:xmpp:blocking';
const String _reportingXmlns = 'urn:xmpp:reporting:1';
const String _reportingFeature = _reportingXmlns;
const String _reportingSpamReason = 'urn:xmpp:reporting:spam';
const String _reportingAbuseReason = 'urn:xmpp:reporting:abuse';
const String _stanzaIdXmlns = 'urn:xmpp:sid:0';
const String _blockTag = 'block';
const String _blockItemTag = 'item';
const String _blockingJidAttr = 'jid';
const String _reportTag = 'report';
const String _reportReasonAttr = 'reason';
const String _reportTextTag = 'text';
const String _stanzaIdTag = 'stanza-id';
const String _stanzaIdByAttr = 'by';
const String _stanzaIdIdAttr = 'id';
const String _blockingIqTypeSet = 'set';
const String _blockingIqTypeResult = 'result';

enum SpamReportReason {
  spam,
  abuse;
}

extension SpamReportReasonExtension on SpamReportReason {
  String get urn => switch (this) {
        SpamReportReason.spam => _reportingSpamReason,
        SpamReportReason.abuse => _reportingAbuseReason,
      };
}

final class SpamReportStanzaId {
  const SpamReportStanzaId({
    required this.by,
    required this.id,
  });

  final String by;
  final String id;

  mox.XMLNode toXml() => mox.XMLNode.xmlns(
        tag: _stanzaIdTag,
        xmlns: _stanzaIdXmlns,
        attributes: {
          _stanzaIdByAttr: by,
          _stanzaIdIdAttr: id,
        },
      );
}

mixin BlockingService on XmppBase, BaseStreamService {
  Stream<List<BlocklistData>> blocklistStream({
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      createPaginatedStream<BlocklistData, XmppDatabase>(
        watchFunction: (db) async => db.watchBlocklist(start: start, end: end),
        getFunction: (db) => db.getBlocklist(start: start, end: end),
      );

  final Logger _blockingLogger = Logger('BlockingService');
  final Set<String> _blockedJids = <String>{};
  StreamSubscription<List<BlocklistData>>? _blocklistSubscription;
  bool _blocklistCacheReady = false;
  bool _spamReportingSupportResolved = false;
  bool _spamReportingSupported = false;

  void _startBlocklistCache() {
    if (_blocklistSubscription != null) {
      return;
    }
    _blocklistSubscription = blocklistStream().listen(_updateBlocklistCache);
  }

  void _updateBlocklistCache(List<BlocklistData> items) {
    final previous = Set<String>.from(_blockedJids);
    final next = <String>{
      for (final entry in items)
        if (_normalizeBareJidValue(entry.jid) case final jid?) jid,
    };
    _blockedJids
      ..clear()
      ..addAll(next);
    _blocklistCacheReady = true;
    final newlyBlocked = next.difference(previous);
    if (newlyBlocked.isEmpty) {
      return;
    }
    unawaited(
      _dbOp<XmppDatabase>(
        (db) async {
          for (final jid in newlyBlocked) {
            await db.updatePresence(
              jid: jid,
              presence: Presence.unavailable,
              status: null,
            );
          }
        },
      ),
    );
  }

  Future<bool> isJidBlocked(String jid) async {
    final normalized = _normalizeBareJidValue(jid);
    if (normalized == null) {
      return false;
    }
    if (_blockedJids.contains(normalized)) {
      return true;
    }
    if (_blocklistCacheReady) {
      return false;
    }
    final db = await database;
    final blocked = await db.isJidBlocked(normalized);
    if (blocked) {
      _blockedJids.add(normalized);
    }
    return blocked;
  }

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    _startBlocklistCache();
    manager
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((_) async {
        _spamReportingSupportResolved = false;
        _blockingLogger.info('Fetching blocklist...');
        requestBlocklist();
      })
      ..registerHandler<mox.BlocklistBlockPushEvent>((event) async {
        await _dbOp<XmppDatabase>(
          (db) => db.blockJids(event.items),
        );
      })
      ..registerHandler<mox.BlocklistUnblockPushEvent>((event) async {
        await _dbOp<XmppDatabase>(
          (db) => db.unblockJids(event.items),
        );
      })
      ..registerHandler<mox.BlocklistUnblockAllPushEvent>((_) async {
        await _dbOp<XmppDatabase>(
          (db) => db.deleteBlocklist(),
        );
      });
  }

  @override
  Future<void> _reset() async {
    await _blocklistSubscription?.cancel();
    _blocklistSubscription = null;
    _blockedJids.clear();
    _blocklistCacheReady = false;
    await super._reset();
  }

  @override
  List<mox.XmppManagerBase> get featureManagers => super.featureManagers
    ..addAll([
      mox.BlockingManager(),
    ]);

  Future<void> requestBlocklist() async {
    if (await _connection.requestBlocklist() case final blocked?) {
      await _dbOp<XmppDatabase>(
        (db) => db.replaceBlocklist(blocked),
      );
    }
  }

  Future<void> block({required String jid}) async {
    _blockingLogger.info('Requesting to block $jid...');
    await _connection.block(jid);
  }

  Future<void> blockAndReport({
    required String jid,
    required SpamReportReason reason,
    String? reportText,
    List<SpamReportStanzaId> stanzaIds = const <SpamReportStanzaId>[],
  }) async {
    final normalized = jid.trim();
    if (normalized.isEmpty) return;
    final manager = _connection.getManager<mox.BlockingManager>();
    if (manager == null) {
      throw XmppBlockUnsupportedException();
    }
    if (!await manager.isSupported()) {
      throw XmppBlockUnsupportedException();
    }
    if (!await _ensureSpamReportingSupport()) {
      throw XmppSpamReportUnsupportedException();
    }
    final reportChildren = <mox.XMLNode>[
      for (final stanzaId in stanzaIds)
        if (stanzaId.by.trim().isNotEmpty && stanzaId.id.trim().isNotEmpty)
          stanzaId.toXml(),
      if (reportText != null && reportText.trim().isNotEmpty)
        mox.XMLNode(tag: _reportTextTag, text: reportText.trim()),
    ];
    final reportNode = mox.XMLNode.xmlns(
      tag: _reportTag,
      xmlns: _reportingXmlns,
      attributes: {_reportReasonAttr: reason.urn},
      children: reportChildren,
    );
    final blockNode = mox.XMLNode.xmlns(
      tag: _blockTag,
      xmlns: _blockingXmlns,
      children: [
        mox.XMLNode(
          tag: _blockItemTag,
          attributes: {_blockingJidAttr: normalized},
          children: [reportNode],
        ),
      ],
    );
    final result = await _connection.sendStanza(
      mox.StanzaDetails(
        mox.Stanza.iq(
          type: _blockingIqTypeSet,
          children: [blockNode],
        ),
        shouldEncrypt: false,
      ),
    );
    if (result == null ||
        result.attributes[_iqTypeAttr]?.toString() != _blockingIqTypeResult) {
      throw XmppSpamReportException();
    }
  }

  Future<void> unblock({required String jid}) async {
    _blockingLogger.info('Requesting to unblock $jid...');
    await _connection.unblock(jid);
  }

  Future<void> unblockAll() async {
    _blockingLogger.info('Requesting to unblock all...');
    await _connection.unblockAll();
  }

  Future<bool> _ensureSpamReportingSupport() async {
    if (_spamReportingSupportResolved) {
      return _spamReportingSupported;
    }
    _spamReportingSupportResolved = true;
    final discoManager = _connection.getManager<mox.DiscoManager>();
    final target = _reportingDiscoTarget();
    if (discoManager == null || target == null) {
      _spamReportingSupported = false;
      return false;
    }
    try {
      final result = await discoManager.discoInfoQuery(target);
      if (result.isType<mox.StanzaError>()) {
        _spamReportingSupported = false;
        return false;
      }
      final info = result.get<mox.DiscoInfo>();
      _spamReportingSupported = info.features.contains(_reportingFeature);
      return _spamReportingSupported;
    } on Exception {
      _spamReportingSupported = false;
      return false;
    }
  }

  mox.JID? _reportingDiscoTarget() {
    final host = _myJid?.domain;
    final trimmed = host?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    try {
      return mox.JID.fromString(trimmed);
    } on Exception {
      return null;
    }
  }
}
