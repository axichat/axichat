part of 'package:axichat/src/xmpp/xmpp_service.dart';

const String _draftSyncSourceKeyName = 'draft_sync_source_id';
const String _draftRecipientRoleDefault = 'to';
const int _draftsSnapshotStart = 0;
const int _draftsSnapshotEnd = 0;

final _draftSyncSourceKey = XmppStateStore.registerKey(
  _draftSyncSourceKeyName,
);

enum _DraftSyncDecision {
  applyRemote,
  publishLocal,
  skip,
}

mixin DraftSyncService on XmppBase, BaseStreamService {
  bool _draftSnapshotInFlight = false;
  String? _draftSourceId;

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
        if (event.resumed) return;
        if (connectionState != ConnectionState.connected) return;
        unawaited(syncDraftsOnLogin());
      })
      ..registerHandler<DraftSyncUpdatedEvent>((event) async {
        await _applyDraftSyncUpdate(event.payload);
      })
      ..registerHandler<DraftSyncRetractedEvent>((event) async {
        await _applyDraftSyncRetraction(event.syncId);
      });
  }

  DraftsPubSubManager? get _draftsManager =>
      _connection.getManager<DraftsPubSubManager>();

  Future<void> syncDraftsOnLogin() async {
    await syncDraftsSnapshot();
  }

  Future<void> syncDraftsSnapshot() async {
    if (_draftSnapshotInFlight) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      return;
    }
    _draftSnapshotInFlight = true;
    try {
      await database;
      if (connectionState != ConnectionState.connected) {
        return;
      }
      final support = await refreshPubSubSupport();
      if (!support.canUsePepNodes) {
        return;
      }
      final manager = _draftsManager;
      if (manager == null) {
        return;
      }
      await manager.ensureNode();
      await manager.subscribe();
      final snapshot = await manager.fetchAllWithStatus();
      if (!snapshot.isSuccess) {
        return;
      }
      final remoteItems = snapshot.items;
      final remoteById = <String, DraftSyncPayload>{
        for (final item in remoteItems) item.syncId: item,
      };
      final localDrafts = await _dbOpReturning<XmppDatabase, List<Draft>>(
        (db) => db.getDrafts(
          start: _draftsSnapshotStart,
          end: _draftsSnapshotEnd,
        ),
      );
      final localById = <String, Draft>{
        for (final draft in localDrafts)
          if (draft.draftSyncId.trim().isNotEmpty) draft.draftSyncId: draft,
      };
      final localSourceId = await _ensureDraftSourceId();

      for (final remote in remoteItems) {
        final local = localById[remote.syncId];
        if (local == null) {
          await _saveDraftFromSync(remote);
          continue;
        }
        final decision = _resolveDraftSyncDecision(
          local: local,
          remote: remote,
          localSourceId: localSourceId,
        );
        switch (decision) {
          case _DraftSyncDecision.applyRemote:
            await _saveDraftFromSync(remote);
          case _DraftSyncDecision.publishLocal:
            await publishDraftSync(local);
          case _DraftSyncDecision.skip:
            continue;
        }
      }

      for (final draft in localDrafts) {
        final syncId = draft.draftSyncId.trim();
        if (syncId.isEmpty || !remoteById.containsKey(syncId)) {
          await publishDraftSync(draft);
        }
      }
    } on XmppAbortedException {
      return;
    } finally {
      _draftSnapshotInFlight = false;
    }
  }

  Future<void> publishDraftSync(Draft draft) async {
    if (connectionState != ConnectionState.connected) {
      return;
    }
    final support = await refreshPubSubSupport();
    if (!support.canUsePepNodes) {
      return;
    }
    final manager = _draftsManager;
    if (manager == null) {
      return;
    }
    final sourceId = await _ensureDraftSourceId();
    final resolvedDraft = await _ensureDraftSyncIdentity(
      draft: draft,
      sourceId: sourceId,
    );
    final payload = await _buildDraftPayload(resolvedDraft);
    if (payload == null) {
      return;
    }
    await manager.ensureNode();
    await manager.publishDraft(payload);
  }

  Future<void> retractDraftSync(String syncId) async {
    if (connectionState != ConnectionState.connected) {
      return;
    }
    final support = await refreshPubSubSupport();
    if (!support.canUsePepNodes) {
      return;
    }
    final manager = _draftsManager;
    if (manager == null) {
      return;
    }
    await manager.retractDraft(syncId);
  }

  Future<void> _applyDraftSyncUpdate(DraftSyncPayload payload) async {
    if (payload.syncId.trim().isEmpty) {
      return;
    }
    final localSourceId = await _ensureDraftSourceId();
    final existing = await _dbOpReturning<XmppDatabase, Draft?>(
      (db) => db.getDraftBySyncId(payload.syncId),
    );
    if (existing == null) {
      await _saveDraftFromSync(payload);
      return;
    }
    final decision = _resolveDraftSyncDecision(
      local: existing,
      remote: payload,
      localSourceId: localSourceId,
    );
    switch (decision) {
      case _DraftSyncDecision.applyRemote:
        await _saveDraftFromSync(payload);
      case _DraftSyncDecision.publishLocal:
        await publishDraftSync(existing);
      case _DraftSyncDecision.skip:
        return;
    }
  }

  Future<void> _applyDraftSyncRetraction(String syncId) async {
    final normalized = syncId.trim();
    if (normalized.isEmpty) {
      return;
    }
    final existing = await _dbOpReturning<XmppDatabase, Draft?>(
      (db) => db.getDraftBySyncId(normalized),
    );
    if (existing == null) {
      return;
    }
    final metadataIds = existing.attachmentMetadataIds;
    await _dbOp<XmppDatabase>((db) => db.removeDraft(existing.id));
    await _removeDraftAttachmentMetadata(metadataIds);
  }

  _DraftSyncDecision _resolveDraftSyncDecision({
    required Draft local,
    required DraftSyncPayload remote,
    required String localSourceId,
  }) {
    final localUpdatedAt = local.draftUpdatedAt.toUtc();
    final remoteUpdatedAt = remote.updatedAt.toUtc();
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      return _DraftSyncDecision.applyRemote;
    }
    if (remoteUpdatedAt.isBefore(localUpdatedAt)) {
      return _DraftSyncDecision.publishLocal;
    }

    final remoteSource = remote.sourceId.trim();
    final localSource = local.draftSourceId.trim();
    if (remoteSource == localSourceId) {
      return _DraftSyncDecision.skip;
    }
    if (remoteSource.compareTo(localSource) > 0) {
      return _DraftSyncDecision.applyRemote;
    }
    if (remoteSource.compareTo(localSource) < 0) {
      return _DraftSyncDecision.publishLocal;
    }
    return _DraftSyncDecision.skip;
  }

  Future<void> _saveDraftFromSync(DraftSyncPayload payload) async {
    await _dbOp<XmppDatabase>(
      (db) async => db.upsertDraftFromSync(
        draftSyncId: payload.syncId,
        jids: payload.recipientJids,
        body: payload.body,
        subject: payload.subject,
        attachmentMetadataIds: payload.attachmentMetadataIds,
        draftUpdatedAt: payload.updatedAt.toUtc(),
        draftSourceId: payload.sourceId,
      ),
    );
  }

  Future<DraftSyncPayload?> _buildDraftPayload(Draft draft) async {
    final syncId = draft.draftSyncId.trim();
    if (syncId.isEmpty) return null;
    final recipients = await _resolveDraftRecipients(draft);
    return DraftSyncPayload(
      syncId: syncId,
      updatedAt: draft.draftUpdatedAt.toUtc(),
      sourceId: draft.draftSourceId,
      recipients: recipients,
      subject: draft.subject,
      body: draft.body,
      attachmentMetadataIds: draft.attachmentMetadataIds,
    );
  }

  Future<List<DraftRecipient>> _resolveDraftRecipients(Draft draft) async {
    if (draft.jids.isEmpty) return const <DraftRecipient>[];
    final db = await database;
    final recipients = <DraftRecipient>[];
    for (final jid in draft.jids) {
      final chat = await db.getChat(jid);
      final transport = chat?.defaultTransport ?? MessageTransport.xmpp;
      recipients.add(
        DraftRecipient(
          jid: jid,
          role: _draftRecipientRoleDefault,
          transport: transport,
        ),
      );
    }
    return List<DraftRecipient>.unmodifiable(recipients);
  }

  Future<Draft> _ensureDraftSyncIdentity({
    required Draft draft,
    required String sourceId,
  }) async {
    final resolvedSyncId =
        draft.draftSyncId.trim().isEmpty ? uuid.v4() : draft.draftSyncId;
    final resolvedSourceId =
        draft.draftSourceId.trim().isEmpty ? sourceId : draft.draftSourceId;
    if (resolvedSyncId == draft.draftSyncId &&
        resolvedSourceId == draft.draftSourceId) {
      return draft;
    }
    await _dbOp<XmppDatabase>(
      (db) async => db.updateDraftSyncMetadata(
        id: draft.id,
        draftSyncId: resolvedSyncId,
        draftUpdatedAt: draft.draftUpdatedAt.toUtc(),
        draftSourceId: resolvedSourceId,
      ),
    );
    return draft.copyWith(
      draftSyncId: resolvedSyncId,
      draftSourceId: resolvedSourceId,
    );
  }

  Future<String> _ensureDraftSourceId() async {
    final cached = _draftSourceId;
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }
    final stored = await _dbOpReturning<XmppStateStore, String?>(
      (ss) async => ss.read(key: _draftSyncSourceKey) as String?,
    );
    final trimmed = stored?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      _draftSourceId = trimmed;
      return trimmed;
    }
    final generated = uuid.v4();
    await _dbOp<XmppStateStore>(
      (ss) async => ss.write(
        key: _draftSyncSourceKey,
        value: generated,
      ),
    );
    _draftSourceId = generated;
    return generated;
  }

  Future<void> _removeDraftAttachmentMetadata(
    Iterable<String> metadataIds,
  ) async {
    if (metadataIds.isEmpty) return;
    await _dbOp<XmppDatabase>(
      (db) async {
        for (final metadataId in metadataIds) {
          await db.deleteFileMetadata(metadataId);
        }
      },
    );
  }
}
