part of 'package:axichat/src/xmpp/xmpp_service.dart';

const String _draftSyncSourceKeyName = 'draft_sync_source_id';
const String _draftSyncPendingPublishesKeyName = 'draft_sync_pending_publishes';
const String _draftSyncPendingRetractionsKeyName =
    'draft_sync_pending_retractions';
const String _draftSyncSnapshotAtKeyName = 'draft_sync_last_snapshot_at';
const String _draftSyncSnapshotIdsKeyName = 'draft_sync_last_snapshot_ids';
const String _draftRecipientRoleDefault = 'to';
const String _draftAttachmentUploadStanzaId = 'draft-attachment-upload';
const int _draftsSnapshotStart = 0;
const int _draftsSnapshotEnd = 0;

final _draftSyncSourceKey = XmppStateStore.registerKey(
  _draftSyncSourceKeyName,
);
final _draftSyncPendingPublishesKey = XmppStateStore.registerKey(
  _draftSyncPendingPublishesKeyName,
);
final _draftSyncPendingRetractionsKey = XmppStateStore.registerKey(
  _draftSyncPendingRetractionsKeyName,
);
final _draftSyncSnapshotAtKey = XmppStateStore.registerKey(
  _draftSyncSnapshotAtKeyName,
);
final _draftSyncSnapshotIdsKey = XmppStateStore.registerKey(
  _draftSyncSnapshotIdsKeyName,
);

enum _DraftSyncDecision {
  applyRemote,
  publishLocal,
  skip,
}

mixin DraftSyncService on XmppBase, BaseStreamService {
  bool _draftSnapshotInFlight = false;
  String? _draftSourceId;
  bool _pendingDraftSyncLoaded = false;
  final Set<String> _pendingDraftPublishes = {};
  final Set<String> _pendingDraftRetractions = {};
  bool _draftSnapshotMetaLoaded = false;
  DateTime? _draftLastSnapshotAt;
  final Set<String> _draftLastSnapshotIds = {};

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
        if (connectionState != ConnectionState.connected) return;
        if (event.resumed) {
          unawaited(_flushPendingDraftSync());
          return;
        }
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

  Future<XmppAttachmentUpload> _uploadDraftAttachment(
    EmailAttachment attachment,
  );

  Future<void> _uploadDraftAttachmentFile({
    required XmppAttachmentUpload upload,
    required FileMetadataData metadata,
    required String stanzaId,
    required bool shouldStore,
  });

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
      await _ensurePendingDraftSyncLoaded();
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
      await _ensureDraftSnapshotMetaLoaded();
      final snapshotTimestamp = DateTime.timestamp().toUtc();
      final isSnapshotComplete = snapshot.isComplete;
      final remoteItems = snapshot.items;
      final remoteById = <String, DraftSyncPayload>{};
      for (final item in remoteItems) {
        final normalized = item.syncId.trim();
        if (normalized.isEmpty) {
          continue;
        }
        remoteById[normalized] = item;
      }
      final remoteIds = remoteById.keys.toSet();
      final localDrafts = await _dbOpReturning<XmppDatabase, List<Draft>>(
        (db) => db.getDrafts(
          start: _draftsSnapshotStart,
          end: _draftsSnapshotEnd,
        ),
      );
      final localById = <String, Draft>{};
      for (final draft in localDrafts) {
        final syncId = draft.draftSyncId.trim();
        if (syncId.isEmpty) {
          continue;
        }
        localById[syncId] = draft;
      }
      final localSourceId = await _ensureDraftSourceId();
      final previousSnapshotAt = _draftLastSnapshotAt;
      final previousSnapshotIds = Set<String>.of(_draftLastSnapshotIds);

      for (final entry in remoteById.entries) {
        final remoteSyncId = entry.key;
        final remote = entry.value;
        if (_pendingDraftRetractions.contains(remoteSyncId)) {
          await retractDraftSync(remoteSyncId);
          continue;
        }
        final local = localById[remoteSyncId];
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
            await _saveDraftFromSync(remote, existing: local);
          case _DraftSyncDecision.publishLocal:
            await publishDraftSync(local);
          case _DraftSyncDecision.skip:
            continue;
        }
      }

      for (final entry in localById.entries) {
        final syncId = entry.key;
        final draft = entry.value;
        if (remoteById.containsKey(syncId)) {
          continue;
        }
        if (_shouldApplyMissingDraftDeletion(
          syncId: syncId,
          localUpdatedAt: draft.draftUpdatedAt,
          entrySourceId: draft.draftSourceId,
          localSourceId: localSourceId,
          lastSnapshotAt: previousSnapshotAt,
          previousSnapshotIds: previousSnapshotIds,
          isSnapshotComplete: isSnapshotComplete,
        )) {
          await _applyDraftSyncRetraction(syncId);
          continue;
        }
        await publishDraftSync(draft);
      }
      for (final draft in localDrafts) {
        if (draft.draftSyncId.trim().isNotEmpty) {
          continue;
        }
        await publishDraftSync(draft);
      }
      if (isSnapshotComplete) {
        await _persistDraftSnapshotMeta(
          snapshotAt: snapshotTimestamp,
          remoteIds: remoteIds,
        );
      }

      await _flushPendingDraftSync();
    } on XmppAbortedException {
      return;
    } finally {
      _draftSnapshotInFlight = false;
    }
  }

  Future<void> publishDraftSync(Draft draft) async {
    final sourceId = await _ensureDraftSourceId();
    final resolvedDraft = await _ensureDraftSyncIdentity(
      draft: draft,
      sourceId: sourceId,
    );
    final syncId = resolvedDraft.draftSyncId.trim();
    if (syncId.isEmpty) {
      return;
    }
    if (!_connection.hasConnectionSettings) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      await _queueDraftPublish(syncId);
      return;
    }
    final support = await refreshPubSubSupport();
    if (!support.canUsePepNodes) {
      await _queueDraftPublish(syncId);
      return;
    }
    final manager = _draftsManager;
    if (manager == null) {
      await _queueDraftPublish(syncId);
      return;
    }
    final payload = await _buildDraftPayload(resolvedDraft);
    if (payload == null) {
      await _queueDraftPublish(syncId);
      return;
    }
    await manager.ensureNode();
    final published = await manager.publishDraft(payload);
    if (published) {
      await _clearPendingDraftPublish(syncId);
    } else {
      await _queueDraftPublish(syncId);
    }
  }

  Future<void> retractDraftSync(String syncId) async {
    final normalized = syncId.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (!_connection.hasConnectionSettings) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      await _queueDraftRetraction(normalized);
      return;
    }
    final support = await refreshPubSubSupport();
    if (!support.canUsePepNodes) {
      await _queueDraftRetraction(normalized);
      return;
    }
    final manager = _draftsManager;
    if (manager == null) {
      await _queueDraftRetraction(normalized);
      return;
    }
    final retracted = await manager.retractDraft(normalized);
    if (retracted) {
      await _clearPendingDraftRetraction(normalized);
    } else {
      await _queueDraftRetraction(normalized);
    }
  }

  Future<void> _applyDraftSyncUpdate(DraftSyncPayload payload) async {
    final normalizedSyncId = payload.syncId.trim();
    if (normalizedSyncId.isEmpty) {
      return;
    }
    await _ensurePendingDraftSyncLoaded();
    if (_pendingDraftRetractions.contains(normalizedSyncId)) {
      await retractDraftSync(normalizedSyncId);
      return;
    }
    final localSourceId = await _ensureDraftSourceId();
    final existing = await _dbOpReturning<XmppDatabase, Draft?>(
      (db) => db.getDraftBySyncId(normalizedSyncId),
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
        await _saveDraftFromSync(payload, existing: existing);
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
    await _ensurePendingDraftSyncLoaded();
    await _clearPendingDraftPublish(normalized);
    await _clearPendingDraftRetraction(normalized);
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

  Future<void> _saveDraftFromSync(
    DraftSyncPayload payload, {
    Draft? existing,
  }) async {
    final resolvedExisting = existing ??
        await _dbOpReturning<XmppDatabase, Draft?>(
          (db) => db.getDraftBySyncId(payload.syncId),
        );
    final existingMetadataIds =
        resolvedExisting?.attachmentMetadataIds ?? const <String>[];
    final recipientRecords = _mapDraftRecipientRecords(payload.recipients);
    await _saveDraftAttachmentMetadataFromSync(payload.attachments);
    await _dbOp<XmppDatabase>(
      (db) async => db.upsertDraftFromSync(
        draftSyncId: payload.syncId,
        jids: payload.recipientJids,
        body: payload.body,
        subject: payload.subject,
        attachmentMetadataIds: payload.attachmentMetadataIds,
        draftUpdatedAt: payload.updatedAt.toUtc(),
        draftSourceId: payload.sourceId,
        draftRecipients: recipientRecords,
      ),
    );
    await _clearPendingDraftPublish(payload.syncId);
    final staleMetadataIds = _resolveStaleAttachmentMetadata(
      existing: existingMetadataIds,
      incoming: payload.attachmentMetadataIds,
    );
    await _removeDraftAttachmentMetadata(staleMetadataIds);
  }

  Future<DraftSyncPayload?> _buildDraftPayload(Draft draft) async {
    final syncId = draft.draftSyncId.trim();
    if (syncId.isEmpty) return null;
    final recipients = await _resolveDraftRecipients(draft);
    final attachments = await _resolveDraftAttachments(draft);
    if (attachments == null) {
      return null;
    }
    return DraftSyncPayload(
      syncId: syncId,
      updatedAt: draft.draftUpdatedAt.toUtc(),
      sourceId: draft.draftSourceId,
      recipients: recipients,
      subject: draft.subject,
      body: draft.body,
      attachments: attachments,
    );
  }

  Future<List<DraftRecipient>> _resolveDraftRecipients(Draft draft) async {
    final storedRecipients = draft.draftRecipients;
    if (storedRecipients.isNotEmpty) {
      return _mapSyncRecipients(storedRecipients);
    }
    final recipients = await _resolveDraftRecipientRecords(
      jids: draft.jids,
      existingRecipients: const <DraftRecipientData>[],
    );
    return _mapSyncRecipients(recipients);
  }

  Future<List<DraftRecipientData>> _resolveDraftRecipientRecords({
    required List<String> jids,
    required List<DraftRecipientData> existingRecipients,
  }) {
    if (jids.isEmpty) {
      return Future.value(const <DraftRecipientData>[]);
    }
    final existingByJid = <String, DraftRecipientData>{};
    for (final recipient in existingRecipients) {
      final normalized = recipient.jid.trim();
      if (normalized.isEmpty) continue;
      existingByJid[normalized] = recipient;
    }
    final recipients = <DraftRecipientData>[];
    for (final jid in jids) {
      final normalized = jid.trim();
      if (normalized.isEmpty) continue;
      final existing = existingByJid[normalized];
      if (existing != null) {
        recipients.add(existing);
        continue;
      }
      recipients.add(
        DraftRecipientData(
          jid: normalized,
          role: _draftRecipientRoleDefault,
        ),
      );
    }
    return Future.value(List<DraftRecipientData>.unmodifiable(recipients));
  }

  List<DraftRecipientData> _mapDraftRecipientRecords(
    List<DraftRecipient> recipients,
  ) {
    if (recipients.isEmpty) return const <DraftRecipientData>[];
    final mapped = recipients
        .map(
          (recipient) => DraftRecipientData(
            jid: recipient.jid,
            role: recipient.role,
          ),
        )
        .toList(growable: false);
    return List<DraftRecipientData>.unmodifiable(mapped);
  }

  List<DraftRecipient> _mapSyncRecipients(
    List<DraftRecipientData> recipients,
  ) {
    if (recipients.isEmpty) return const <DraftRecipient>[];
    final mapped = recipients
        .map(
          (recipient) => DraftRecipient(
            jid: recipient.jid,
            role: recipient.role,
          ),
        )
        .toList(growable: false);
    return List<DraftRecipient>.unmodifiable(mapped);
  }

  List<String> _resolveStaleAttachmentMetadata({
    required List<String> existing,
    required List<String> incoming,
  }) {
    if (existing.isEmpty) return const <String>[];
    final incomingSet = incoming.toSet();
    return existing
        .where((metadataId) => !incomingSet.contains(metadataId))
        .toList(growable: false);
  }

  Future<List<DraftAttachmentRef>?> _resolveDraftAttachments(
      Draft draft) async {
    final metadataIds =
        draft.attachmentMetadataIds.length > draftSyncMaxAttachments
            ? draft.attachmentMetadataIds
                .take(draftSyncMaxAttachments)
                .toList(growable: false)
            : draft.attachmentMetadataIds;
    if (metadataIds.isEmpty) return const <DraftAttachmentRef>[];
    final db = await database;
    final attachments = <DraftAttachmentRef>[];
    for (final metadataId in metadataIds) {
      final normalized = metadataId.trim();
      if (normalized.isEmpty) {
        return null;
      }
      final metadata = await db.getFileMetadata(normalized);
      if (metadata == null) {
        return null;
      }
      final resolved = await _ensureDraftAttachmentUpload(metadata);
      final url = _firstAttachmentUrl(resolved);
      if (url == null) {
        return null;
      }
      attachments.add(
        DraftAttachmentRef(
          id: resolved.id,
          url: url,
          filename: resolved.filename,
          mimeType: resolved.mimeType,
          sizeBytes: resolved.sizeBytes,
          width: resolved.width,
          height: resolved.height,
        ),
      );
    }
    return List<DraftAttachmentRef>.unmodifiable(attachments);
  }

  Future<void> _saveDraftAttachmentMetadataFromSync(
    List<DraftAttachmentRef> attachments,
  ) async {
    if (attachments.isEmpty) return;
    await _dbOp<XmppDatabase>(
      (db) async {
        for (final attachment in attachments) {
          final existing = await db.getFileMetadata(attachment.id);
          final merged = _mergeDraftAttachmentMetadata(
            attachment: attachment,
            existing: existing,
          );
          await db.saveFileMetadata(merged);
        }
      },
    );
  }

  FileMetadataData _mergeDraftAttachmentMetadata({
    required DraftAttachmentRef attachment,
    FileMetadataData? existing,
  }) {
    final normalizedName = _normalizeAttachmentText(
      attachment.filename,
      maxBytes: draftSyncMaxAttachmentNameBytes,
    );
    final normalizedMime = _normalizeAttachmentText(
      attachment.mimeType,
      maxBytes: draftSyncMaxAttachmentMimeBytes,
    );
    final mergedUrls = _mergeAttachmentUrls(
      existing?.sourceUrls,
      attachment.url,
    );
    return FileMetadataData(
      id: attachment.id,
      filename: normalizedName ?? existing?.filename ?? attachment.id,
      path: existing?.path,
      sourceUrls: mergedUrls,
      mimeType: normalizedMime ?? existing?.mimeType,
      sizeBytes: attachment.sizeBytes ?? existing?.sizeBytes,
      width: attachment.width ?? existing?.width,
      height: attachment.height ?? existing?.height,
      encryptionKey: existing?.encryptionKey,
      encryptionIV: existing?.encryptionIV,
      encryptionScheme: existing?.encryptionScheme,
      cipherTextHashes: existing?.cipherTextHashes,
      plainTextHashes: existing?.plainTextHashes,
      thumbnailType: existing?.thumbnailType,
      thumbnailData: existing?.thumbnailData,
    );
  }

  Future<FileMetadataData> _ensureDraftAttachmentUpload(
    FileMetadataData metadata,
  ) async {
    if (_hasAttachmentUrl(metadata)) {
      return metadata;
    }
    if (connectionState != ConnectionState.connected) {
      return metadata;
    }
    final path = metadata.path?.trim();
    if (path == null || path.isEmpty) {
      return metadata;
    }
    final file = File(path);
    if (!await file.exists()) {
      return metadata;
    }
    final sizeBytes = metadata.sizeBytes ?? await file.length();
    final attachment = EmailAttachment(
      path: path,
      fileName: metadata.filename,
      sizeBytes: sizeBytes,
      mimeType: metadata.mimeType,
      width: metadata.width,
      height: metadata.height,
      metadataId: metadata.id,
    );
    try {
      final upload = await _uploadDraftAttachment(attachment);
      await _uploadDraftAttachmentFile(
        upload: upload,
        metadata: upload.metadata,
        stanzaId: _draftAttachmentUploadStanzaId,
        shouldStore: false,
      );
      await _dbOp<XmppDatabase>(
        (db) => db.saveFileMetadata(upload.metadata),
      );
      return upload.metadata;
    } on XmppException catch (_) {
      return metadata;
    } on Exception {
      return metadata;
    }
  }

  bool _hasAttachmentUrl(FileMetadataData metadata) =>
      _firstAttachmentUrl(metadata) != null;

  String? _firstAttachmentUrl(FileMetadataData metadata) {
    final urls = metadata.sourceUrls;
    if (urls == null || urls.isEmpty) {
      return null;
    }
    for (final url in urls) {
      final trimmed = url.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  List<String>? _mergeAttachmentUrls(
    List<String>? existing,
    String? incoming,
  ) {
    final urls = <String>{};
    if (existing != null) {
      for (final value in existing) {
        final normalized = _normalizeAttachmentUrl(value);
        if (normalized != null) {
          urls.add(normalized);
        }
      }
    }
    final normalizedIncoming = _normalizeAttachmentUrl(incoming);
    if (normalizedIncoming != null) {
      urls.add(normalizedIncoming);
    }
    if (urls.isEmpty) {
      return null;
    }
    return urls.toList(growable: false);
  }

  String? _normalizeAttachmentText(
    String? value, {
    required int maxBytes,
  }) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final clamped = clampUtf8Value(trimmed, maxBytes: maxBytes);
    if (clamped == null || clamped.trim().isEmpty) return null;
    return clamped;
  }

  String? _normalizeAttachmentUrl(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final clamped = clampUtf8Value(
      trimmed,
      maxBytes: draftSyncMaxAttachmentUrlBytes,
    );
    if (clamped == null || clamped.trim().isEmpty) return null;
    final uri = Uri.tryParse(clamped);
    if (uri == null || !uri.hasAuthority || !uri.hasScheme) return null;
    final scheme = uri.scheme.toLowerCase();
    if (!draftSyncAllowedAttachmentSchemes.contains(scheme)) return null;
    return uri.toString();
  }

  Future<void> _ensurePendingDraftSyncLoaded() async {
    if (_pendingDraftSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) async {
        final rawPublishes =
            (ss.read(key: _draftSyncPendingPublishesKey) as List?)
                ?.cast<Object?>();
        final rawRetractions =
            (ss.read(key: _draftSyncPendingRetractionsKey) as List?)
                ?.cast<Object?>();
        _pendingDraftPublishes
          ..clear()
          ..addAll(_normalizeDraftSyncIds(rawPublishes));
        _pendingDraftRetractions
          ..clear()
          ..addAll(_normalizeDraftSyncIds(rawRetractions));
      },
      awaitDatabase: true,
    );
    _pendingDraftSyncLoaded = true;
  }

  Future<void> _ensureDraftSnapshotMetaLoaded() async {
    if (_draftSnapshotMetaLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) async {
        final rawTimestamp = ss.read(key: _draftSyncSnapshotAtKey);
        final rawIds =
            (ss.read(key: _draftSyncSnapshotIdsKey) as List?)?.cast<Object?>();
        _draftLastSnapshotAt = _parseDraftSnapshotAt(rawTimestamp);
        _draftLastSnapshotIds
          ..clear()
          ..addAll(_normalizeDraftSyncIds(rawIds));
      },
      awaitDatabase: true,
    );
    _draftSnapshotMetaLoaded = true;
  }

  DateTime? _parseDraftSnapshotAt(Object? raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  Iterable<String> _normalizeDraftSyncIds(List<Object?>? raw) sync* {
    if (raw == null || raw.isEmpty) {
      return;
    }
    for (final entry in raw) {
      final normalized = entry?.toString().trim();
      if (normalized == null || normalized.isEmpty) {
        continue;
      }
      yield normalized;
    }
  }

  Future<void> _persistDraftSnapshotMeta({
    required DateTime snapshotAt,
    required Set<String> remoteIds,
  }) async {
    _draftLastSnapshotAt = snapshotAt;
    _draftLastSnapshotIds
      ..clear()
      ..addAll(remoteIds);
    await _dbOp<XmppStateStore>(
      (ss) async => ss.writeAll(
        data: {
          _draftSyncSnapshotAtKey: snapshotAt.toIso8601String(),
          _draftSyncSnapshotIdsKey: remoteIds.toList(growable: false),
        },
      ),
      awaitDatabase: true,
    );
  }

  bool _shouldApplyMissingDraftDeletion({
    required String syncId,
    required DateTime localUpdatedAt,
    required String entrySourceId,
    required String localSourceId,
    required DateTime? lastSnapshotAt,
    required Set<String> previousSnapshotIds,
    required bool isSnapshotComplete,
  }) {
    if (!isSnapshotComplete) {
      return false;
    }
    if (!previousSnapshotIds.contains(syncId)) {
      return false;
    }
    if (_pendingDraftPublishes.contains(syncId)) {
      return false;
    }
    final normalizedSource = entrySourceId.trim();
    if (normalizedSource != localSourceId) {
      return true;
    }
    if (lastSnapshotAt == null) {
      return false;
    }
    return !localUpdatedAt.toUtc().isAfter(lastSnapshotAt);
  }

  Future<void> _persistPendingDraftSync() async {
    if (!_pendingDraftSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) async => ss.writeAll(
        data: {
          _draftSyncPendingPublishesKey:
              _pendingDraftPublishes.toList(growable: false),
          _draftSyncPendingRetractionsKey:
              _pendingDraftRetractions.toList(growable: false),
        },
      ),
      awaitDatabase: true,
    );
  }

  Future<void> _queueDraftPublish(String syncId) async {
    final normalized = syncId.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingDraftSyncLoaded();
    _pendingDraftRetractions.remove(normalized);
    _pendingDraftPublishes.add(normalized);
    await _persistPendingDraftSync();
  }

  Future<void> _queueDraftRetraction(String syncId) async {
    final normalized = syncId.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingDraftSyncLoaded();
    _pendingDraftPublishes.remove(normalized);
    _pendingDraftRetractions.add(normalized);
    await _persistPendingDraftSync();
  }

  Future<void> _clearPendingDraftPublish(String syncId) async {
    final normalized = syncId.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingDraftSyncLoaded();
    final removed = _pendingDraftPublishes.remove(normalized);
    if (!removed) {
      return;
    }
    await _persistPendingDraftSync();
  }

  Future<void> _clearPendingDraftRetraction(String syncId) async {
    final normalized = syncId.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingDraftSyncLoaded();
    final removed = _pendingDraftRetractions.remove(normalized);
    if (!removed) {
      return;
    }
    await _persistPendingDraftSync();
  }

  Future<void> _flushPendingDraftSync() async {
    await _ensurePendingDraftSyncLoaded();
    if (_pendingDraftPublishes.isEmpty && _pendingDraftRetractions.isEmpty) {
      return;
    }
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
    final pendingRetractions = _pendingDraftRetractions.toList(growable: false);
    for (final syncId in pendingRetractions) {
      final retracted = await manager.retractDraft(syncId);
      if (retracted) {
        _pendingDraftRetractions.remove(syncId);
      }
    }
    final pendingPublishes = _pendingDraftPublishes.toList(growable: false);
    for (final syncId in pendingPublishes) {
      final draft = await _dbOpReturning<XmppDatabase, Draft?>(
        (db) => db.getDraftBySyncId(syncId),
      );
      if (draft == null) {
        _pendingDraftPublishes.remove(syncId);
        continue;
      }
      await publishDraftSync(draft);
    }
    await _persistPendingDraftSync();
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
