// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

const String _contactSyncPendingPublishesKeyName =
    'contact_sync_pending_publishes';
const String _contactSyncFlushPendingOperationName =
    'ContactDirectoryStorage.flushPendingContactSyncOnResume';
const String _contactSyncSnapshotBootstrapOperationName =
    'ContactDirectoryStorage.bootstrapContactSnapshotOnNegotiations';
final _contactSyncPendingPublishesKey = XmppStateStore.registerKey(
  _contactSyncPendingPublishesKeyName,
);

mixin ContactDirectoryStorage
    on XmppBase, BaseStreamService, MessageService, PubSubService {
  bool _contactSnapshotInFlight = false;
  bool _pendingContactSyncLoaded = false;
  final Set<String> _pendingContactPublishes = <String>{};

  ContactsPubSubManager? get _contactsManager =>
      _connection.getManager<ContactsPubSubManager>();

  Stream<List<ContactDirectoryEntry>> contactDirectoryStream() {
    return createSingleItemStream<List<ContactDirectoryEntry>, XmppDatabase>(
      watchFunction: (db) async => db.watchContactDirectoryEntries(),
    );
  }

  Future<List<ContactDirectoryEntry>> loadContactDirectorySnapshot() async {
    return await _dbOpReturning<XmppDatabase, List<ContactDirectoryEntry>>(
      (db) => db.getContactDirectoryEntries(),
    );
  }

  Stream<Map<String, String>> contactFolderRulesStream() {
    return createSingleItemStream<Map<String, String>, XmppDatabase>(
      watchFunction: (db) async => db.watchActiveContactFolderRules(),
    );
  }

  Future<void> addManualContact({
    required String address,
    String? displayName,
  }) async {
    final key = contactDirectoryAddressKey(address);
    if (key.isEmpty) {
      throw XmppContactDirectoryException();
    }
    final record = await _dbOpReturning<XmppDatabase, PrivateContactRecord?>(
      (db) => db.upsertManualPrivateContact(
        addressKey: key,
        displayName: displayName,
      ),
    );
    if (record != null) {
      await _publishContactSyncEntry(record);
    }
  }

  Future<void> deactivateManualContact({required String address}) async {
    await deactivatePrivateContact(address: address);
  }

  Future<void> deactivatePrivateContact({required String address}) async {
    final key = contactDirectoryAddressKey(address);
    if (key.isEmpty) {
      throw XmppContactDirectoryException();
    }
    final record = await _dbOpReturning<XmppDatabase, PrivateContactRecord?>(
      (db) => db.deactivateManualPrivateContact(addressKey: key),
    );
    if (record != null) {
      await _publishContactSyncEntry(record);
    }
  }

  Future<void> setContactFavorited({
    required String address,
    required bool favorited,
  }) async {
    final key = contactDirectoryAddressKey(address);
    if (key.isEmpty) {
      throw XmppContactDirectoryException();
    }
    await _dbOp<XmppDatabase>(
      (db) => db.setContactFavorited(addressKey: key, favorited: favorited),
      awaitDatabase: true,
    );
    final record = await _loadPrivateContactRecord(key);
    if (record != null) {
      await _publishContactSyncEntry(record);
    }
  }

  Future<void> setContactDisplayNameOverride({
    required String address,
    required String? displayName,
  }) async {
    final key = contactDirectoryAddressKey(address);
    if (key.isEmpty) {
      throw XmppContactDirectoryException();
    }
    await _dbOp<XmppDatabase>(
      (db) => db.setContactDisplayNameOverride(
        addressKey: key,
        displayName: displayName?.trim(),
      ),
      awaitDatabase: true,
    );
    final record = await _loadPrivateContactRecord(key);
    if (record != null) {
      await _publishContactSyncEntry(record);
    }
  }

  Future<void> setContactFolderRule({
    required String address,
    required String collectionId,
  }) async {
    final key = contactDirectoryAddressKey(address);
    final normalizedCollectionId = collectionId.trim();
    if (key.isEmpty || normalizedCollectionId.isEmpty) {
      throw XmppContactDirectoryException();
    }
    await _dbOp<XmppDatabase>(
      (db) => db.setContactFolderRule(
        addressKey: key,
        collectionId: normalizedCollectionId,
      ),
      awaitDatabase: true,
    );
    final record = await _loadPrivateContactRecord(key);
    if (record != null) {
      await _publishContactSyncEntry(record);
    }
  }

  Future<void> clearContactFolderRule({required String address}) async {
    final key = contactDirectoryAddressKey(address);
    if (key.isEmpty) {
      throw XmppContactDirectoryException();
    }
    await _dbOp<XmppDatabase>(
      (db) => db.clearContactFolderRule(addressKey: key),
      awaitDatabase: true,
    );
    final record = await _loadPrivateContactRecord(key);
    if (record != null) {
      await _publishContactSyncEntry(record);
    }
  }

  Future<void> syncContactsSnapshot() async {
    if (_contactSnapshotInFlight) {
      return;
    }
    _contactSnapshotInFlight = true;
    try {
      await database;
      await _ensurePendingContactSyncLoaded();
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'contact sync',
      );
      if (!decision.isAllowed) {
        return;
      }
      final manager = _contactsManager;
      if (manager == null) {
        return;
      }
      await manager.ensureNode();
      await manager.subscribe();
      await _flushPendingContactSync(
        managerOverride: manager,
        managerReady: true,
      );
      final snapshot = await manager.fetchAllWithStatus();
      if (!snapshot.isSuccess) {
        return;
      }

      final localEntries = await _localContactSyncEntries(
        includeInactive: true,
      );
      final localByItemId = <String, PrivateContactRecord>{
        for (final entry in localEntries)
          ContactSyncPayload.itemIdFor(addressKey: entry.addressKey): entry,
      };

      for (final remote in snapshot.items) {
        final local = localByItemId.remove(remote.itemId);
        if (local == null) {
          await _applyContactSyncUpdate(remote);
          continue;
        }
        final syncDecision = _resolveContactSyncDecision(local, remote);
        if (syncDecision == _MessageCollectionSyncDecision.applyRemote) {
          await _applyContactSyncUpdate(remote);
          continue;
        }
        if (syncDecision == _MessageCollectionSyncDecision.publishLocal) {
          await _publishContactSyncEntry(
            local,
            managerOverride: manager,
            managerReady: true,
          );
        }
      }

      for (final local in localByItemId.values) {
        await _publishContactSyncEntry(
          local,
          managerOverride: manager,
          managerReady: true,
        );
      }
      await _flushPendingContactSync(
        managerOverride: manager,
        managerReady: true,
      );
    } on XmppAbortedException {
      return;
    } finally {
      _contactSnapshotInFlight = false;
    }
  }

  Future<PrivateContactRecord?> _loadPrivateContactRecord(
    String addressKey,
  ) async {
    return await _dbOpReturning<XmppDatabase, PrivateContactRecord?>(
      (db) => db.getPrivateContactRecord(addressKey),
    );
  }

  Future<void> _publishContactSyncEntry(
    PrivateContactRecord entry, {
    ContactsPubSubManager? managerOverride,
    bool managerReady = false,
  }) async {
    final itemId = ContactSyncPayload.itemIdFor(addressKey: entry.addressKey);
    if (!_connection.hasConnectionSettings) {
      return;
    }
    try {
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'contact sync',
      );
      if (!decision.isAllowed) {
        return;
      }
      final manager = managerOverride ?? _contactsManager;
      if (manager == null) {
        await _queueContactPublish(itemId);
        return;
      }
      if (!managerReady) {
        await manager.ensureNode();
        await manager.subscribe();
      }
      final published = await manager.publishEntry(
        await _buildContactPayload(entry),
      );
      if (published) {
        await _clearPendingContactPublish(itemId);
        return;
      }
      await _queueContactPublish(itemId);
    } on XmppException {
      await _queueContactPublish(itemId);
    }
  }

  Future<ContactSyncPayload> _buildContactPayload(
    PrivateContactRecord entry,
  ) async {
    final fields =
        await _dbOpReturning<
          XmppDatabase,
          List<PrivateContactDetailFieldEntry>
        >(
          (db) => db.getPrivateContactDetailFields(
            entry.addressKey,
            includeInactive: true,
          ),
        );
    return ContactSyncPayload(
      addressKey: entry.addressKey,
      active: entry.active,
      manual: entry.manual,
      favorited: entry.favorited,
      displayNameOverride: entry.displayNameOverride,
      folderCollectionId: entry.folderCollectionId,
      updatedAt: entry.updatedAt.toUtc(),
      activeUpdatedAt: entry.activeUpdatedAt?.toUtc(),
      manualUpdatedAt: entry.manualUpdatedAt?.toUtc(),
      favoriteUpdatedAt: entry.favoriteUpdatedAt?.toUtc(),
      displayNameUpdatedAt: entry.displayNameUpdatedAt?.toUtc(),
      folderRuleUpdatedAt: entry.folderRuleUpdatedAt?.toUtc(),
      sourceId: entry.sourceId ?? anti_abuse.syncLegacySourceId,
      fields: fields
          .map(
            (field) => ContactSyncFieldPayload(
              fieldId: field.fieldId,
              kind: field.kind,
              label: field.label,
              value: field.value,
              sortOrder: field.sortOrder,
              active: field.active,
              updatedAt: field.updatedAt.toUtc(),
              sourceId: field.sourceId ?? anti_abuse.syncLegacySourceId,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _applyContactSyncUpdate(ContactSyncPayload payload) async {
    await _dbOp<XmppDatabase>((db) async {
      await db.applyPrivateContactMutation(
        addressKey: payload.addressKey,
        active: payload.active,
        manual: payload.manual,
        favorited: payload.favorited,
        displayNameOverride: payload.displayNameOverride,
        folderCollectionId: payload.folderCollectionId,
        updatedAt: payload.updatedAt.toUtc(),
        activeUpdatedAt: payload.activeUpdatedAt?.toUtc(),
        manualUpdatedAt: payload.manualUpdatedAt?.toUtc(),
        favoriteUpdatedAt: payload.favoriteUpdatedAt?.toUtc(),
        displayNameUpdatedAt: payload.displayNameUpdatedAt?.toUtc(),
        folderRuleUpdatedAt: payload.folderRuleUpdatedAt?.toUtc(),
        sourceId: payload.sourceId,
      );
      for (final field in payload.fields) {
        await db.applyPrivateContactDetailFieldMutation(
          addressKey: payload.addressKey,
          fieldId: field.fieldId,
          kind: field.kind,
          label: field.label,
          value: field.value,
          sortOrder: field.sortOrder,
          active: field.active,
          updatedAt: field.updatedAt.toUtc(),
          sourceId: field.sourceId,
        );
      }
    }, awaitDatabase: true);
  }

  _MessageCollectionSyncDecision _resolveContactSyncDecision(
    PrivateContactRecord local,
    ContactSyncPayload remote,
  ) {
    final localUpdatedAt = local.updatedAt.toUtc();
    final remoteUpdatedAt = remote.updatedAt.toUtc();
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      return _MessageCollectionSyncDecision.applyRemote;
    }
    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return _MessageCollectionSyncDecision.publishLocal;
    }
    return _MessageCollectionSyncDecision.skip;
  }

  Future<List<PrivateContactRecord>> _localContactSyncEntries({
    bool includeInactive = false,
  }) async {
    return await _dbOpReturning<XmppDatabase, List<PrivateContactRecord>>(
      (db) => db.getPrivateContactRecords(includeInactive: includeInactive),
    );
  }

  Future<void> _ensurePendingContactSyncLoaded() async {
    if (_pendingContactSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>((ss) async {
      final rawPublishes =
          (ss.read(key: _contactSyncPendingPublishesKey) as List?)
              ?.cast<Object?>();
      _pendingContactPublishes
        ..clear()
        ..addAll(_normalizePendingMessageCollectionIds(rawPublishes));
    }, awaitDatabase: true);
    _pendingContactSyncLoaded = true;
  }

  Future<void> _persistPendingContactSync() async {
    if (!_pendingContactSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) async => ss.write(
        key: _contactSyncPendingPublishesKey,
        value: _pendingContactPublishes.toList(growable: false),
      ),
      awaitDatabase: true,
    );
  }

  Future<void> _queueContactPublish(String itemId) async {
    final normalized = itemId.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingContactSyncLoaded();
    _pendingContactPublishes.add(normalized);
    await _persistPendingContactSync();
  }

  Future<void> _clearPendingContactPublish(String itemId) async {
    final normalized = itemId.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingContactSyncLoaded();
    final removed = _pendingContactPublishes.remove(normalized);
    if (!removed) {
      return;
    }
    await _persistPendingContactSync();
  }

  Future<void> _flushPendingContactSync({
    ContactsPubSubManager? managerOverride,
    bool managerReady = false,
  }) async {
    await _ensurePendingContactSyncLoaded();
    if (_pendingContactPublishes.isEmpty) {
      return;
    }
    final support = await refreshPubSubSupport();
    final decision = decidePubSubSupport(
      supported: support.canUsePepNodes,
      featureLabel: 'contact sync',
    );
    if (!decision.isAllowed) {
      return;
    }
    final manager = managerOverride ?? _contactsManager;
    if (manager == null) {
      return;
    }
    if (!managerReady) {
      await manager.ensureNode();
      await manager.subscribe();
    }
    final localEntries = await _localContactSyncEntries(includeInactive: true);
    final localByItemId = <String, PrivateContactRecord>{
      for (final entry in localEntries)
        ContactSyncPayload.itemIdFor(addressKey: entry.addressKey): entry,
    };
    final pendingPublishes = _pendingContactPublishes.toList(growable: false);
    for (final itemId in pendingPublishes) {
      final localEntry = localByItemId[itemId];
      if (localEntry == null) {
        _pendingContactPublishes.remove(itemId);
        continue;
      }
      final published = await manager.publishEntry(
        await _buildContactPayload(localEntry),
      );
      if (published) {
        _pendingContactPublishes.remove(itemId);
      }
    }
    await _persistPendingContactSync();
  }

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _contactSyncSnapshotBootstrapOperationName,
        priority: 0,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _contactSyncSnapshotBootstrapOperationName,
        run: () async {
          await syncContactsSnapshot();
        },
      ),
    );
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _contactSyncFlushPendingOperationName,
        priority: 2,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.resumedNegotiation,
        },
        operationName: _contactSyncFlushPendingOperationName,
        run: () async {
          await _flushPendingContactSync();
        },
      ),
    );
    manager.registerHandler<ContactSyncUpdatedEvent>((event) async {
      await _applyContactSyncUpdate(event.payload);
    });
  }

  @override
  List<mox.XmppManagerBase> get pubSubFeatureManagers => <mox.XmppManagerBase>[
    ...super.pubSubFeatureManagers,
    ContactsPubSubManager(),
  ];

  @override
  List<String> get discoFeatures => <String>[
    ...super.discoFeatures,
    contactsNotifyFeature,
  ];
}
