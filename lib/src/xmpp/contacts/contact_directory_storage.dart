// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

const String _contactFolderRuleSyncPendingPublishesKeyName =
    'contact_folder_rule_sync_pending_publishes';
const String _contactFolderRuleSyncFlushPendingOperationName =
    'ContactDirectoryStorage.flushPendingContactFolderRuleSyncOnResume';
const String _contactFolderRuleSyncSnapshotBootstrapOperationName =
    'ContactDirectoryStorage.bootstrapContactFolderRuleSnapshotOnNegotiations';
final _contactFolderRuleSyncPendingPublishesKey = XmppStateStore.registerKey(
  _contactFolderRuleSyncPendingPublishesKeyName,
);

mixin ContactDirectoryStorage
    on XmppBase, BaseStreamService, MessageService, PubSubService {
  bool _contactFolderRuleSnapshotInFlight = false;
  bool _pendingContactFolderRuleSyncLoaded = false;
  final Set<String> _pendingContactFolderRulePublishes = <String>{};

  ContactFolderRulesPubSubManager? get _contactFolderRulesManager =>
      _connection.getManager<ContactFolderRulesPubSubManager>();

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
  }

  Future<void> setContactDisplayNameOverride({
    required String address,
    required String? displayName,
  }) async {
    final key = contactDirectoryAddressKey(address);
    if (key.isEmpty) {
      throw XmppContactDirectoryException();
    }
    final trimmed = displayName?.trim();
    await _dbOp<XmppDatabase>(
      (db) => db.setContactDisplayNameOverride(
        addressKey: key,
        displayName: trimmed,
      ),
      awaitDatabase: true,
    );
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
    final collection =
        await _dbOpReturning<XmppDatabase, MessageCollectionEntry?>(
          (db) => db.getMessageCollection(normalizedCollectionId),
        );
    if (collection?.active != true) {
      throw XmppContactDirectoryException();
    }
    final entries =
        await _dbOpReturning<
          XmppDatabase,
          List<MessageCollectionMembershipEntry>
        >(
          (db) => db.setContactFolderRule(
            addressKey: key,
            collectionId: normalizedCollectionId,
          ),
        );
    final preference = await _dbOpReturning<XmppDatabase, ContactPreference?>(
      (db) => db.getContactPreference(key),
    );
    if (preference != null) {
      await _publishContactFolderRuleSyncEntry(preference);
    }
    for (final entry in entries) {
      await publishMessageCollectionSyncEntry(entry);
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
    final preference = await _dbOpReturning<XmppDatabase, ContactPreference?>(
      (db) => db.getContactPreference(key),
    );
    if (preference != null) {
      await _publishContactFolderRuleSyncEntry(preference);
    }
  }

  Future<void> syncContactFolderRulesSnapshot() async {
    if (_contactFolderRuleSnapshotInFlight) {
      return;
    }
    _contactFolderRuleSnapshotInFlight = true;
    try {
      await database;
      await _ensurePendingContactFolderRuleSyncLoaded();
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'contact folder rule sync',
      );
      if (!decision.isAllowed) {
        return;
      }
      final manager = _contactFolderRulesManager;
      if (manager == null) {
        return;
      }
      await manager.ensureNode();
      await manager.subscribe();
      await _flushPendingContactFolderRuleSync(
        managerOverride: manager,
        managerReady: true,
      );
      final snapshot = await manager.fetchAllWithStatus();
      if (!snapshot.isSuccess) {
        return;
      }

      final localEntries = await _localContactFolderRuleEntries(
        includeInactive: true,
      );
      final localByItemId = <String, ContactPreference>{
        for (final entry in localEntries)
          ContactFolderRuleSyncPayload.itemIdFor(addressKey: entry.addressKey):
              entry,
      };

      for (final remote in snapshot.items) {
        final local = localByItemId.remove(remote.itemId);
        if (local == null) {
          await _applyContactFolderRuleSyncUpdate(remote);
          continue;
        }
        final syncDecision = _resolveContactFolderRuleSyncDecision(
          local,
          remote,
        );
        if (syncDecision == _MessageCollectionSyncDecision.applyRemote) {
          await _applyContactFolderRuleSyncUpdate(remote);
          continue;
        }
        if (syncDecision == _MessageCollectionSyncDecision.publishLocal) {
          await _publishContactFolderRuleSyncEntry(
            local,
            managerOverride: manager,
            managerReady: true,
          );
        }
      }

      for (final local in localByItemId.values) {
        await _publishContactFolderRuleSyncEntry(
          local,
          managerOverride: manager,
          managerReady: true,
        );
      }
      await _flushPendingContactFolderRuleSync(
        managerOverride: manager,
        managerReady: true,
      );
    } on XmppAbortedException {
      return;
    } finally {
      _contactFolderRuleSnapshotInFlight = false;
    }
  }

  Future<void> _publishContactFolderRuleSyncEntry(
    ContactPreference entry, {
    ContactFolderRulesPubSubManager? managerOverride,
    bool managerReady = false,
  }) async {
    final itemId = ContactFolderRuleSyncPayload.itemIdFor(
      addressKey: entry.addressKey,
    );
    if (!_connection.hasConnectionSettings) {
      return;
    }
    try {
      final support = await refreshPubSubSupport();
      final decision = decidePubSubSupport(
        supported: support.canUsePepNodes,
        featureLabel: 'contact folder rule sync',
      );
      if (!decision.isAllowed) {
        return;
      }
      final manager = managerOverride ?? _contactFolderRulesManager;
      if (manager == null) {
        await _queueContactFolderRulePublish(itemId);
        return;
      }
      if (!managerReady) {
        await manager.ensureNode();
        await manager.subscribe();
      }
      final published = await manager.publishEntry(
        _buildContactFolderRulePayload(entry),
      );
      if (published) {
        await _clearPendingContactFolderRulePublish(itemId);
        return;
      }
    } on XmppException {
      await _queueContactFolderRulePublish(itemId);
    }
    await _queueContactFolderRulePublish(itemId);
  }

  ContactFolderRuleSyncPayload _buildContactFolderRulePayload(
    ContactPreference entry,
  ) {
    final collectionId = entry.folderCollectionId?.trim();
    return ContactFolderRuleSyncPayload(
      addressKey: entry.addressKey,
      collectionId: collectionId == null || collectionId.isEmpty
          ? null
          : collectionId,
      updatedAt: (entry.folderRuleUpdatedAt ?? entry.updatedAt).toUtc(),
      active: collectionId != null && collectionId.isNotEmpty,
    );
  }

  Future<void> _applyContactFolderRuleSyncUpdate(
    ContactFolderRuleSyncPayload payload,
  ) async {
    await _dbOp<XmppDatabase>(
      (db) => db.applyContactFolderRuleMutation(
        addressKey: payload.addressKey,
        collectionId: payload.collectionId,
        updatedAt: payload.updatedAt.toUtc(),
        active: payload.active,
      ),
      awaitDatabase: true,
    );
  }

  _MessageCollectionSyncDecision _resolveContactFolderRuleSyncDecision(
    ContactPreference local,
    ContactFolderRuleSyncPayload remote,
  ) {
    final localUpdatedAt = (local.folderRuleUpdatedAt ?? local.updatedAt)
        .toUtc();
    final remoteUpdatedAt = remote.updatedAt.toUtc();
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      return _MessageCollectionSyncDecision.applyRemote;
    }
    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return _MessageCollectionSyncDecision.publishLocal;
    }
    return _MessageCollectionSyncDecision.skip;
  }

  Future<List<ContactPreference>> _localContactFolderRuleEntries({
    bool includeInactive = false,
  }) async {
    return await _dbOpReturning<XmppDatabase, List<ContactPreference>>(
      (db) =>
          db.getContactFolderRulePreferences(includeInactive: includeInactive),
    );
  }

  Future<void> _ensurePendingContactFolderRuleSyncLoaded() async {
    if (_pendingContactFolderRuleSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>((ss) async {
      final rawPublishes =
          (ss.read(key: _contactFolderRuleSyncPendingPublishesKey) as List?)
              ?.cast<Object?>();
      _pendingContactFolderRulePublishes
        ..clear()
        ..addAll(_normalizePendingMessageCollectionIds(rawPublishes));
    }, awaitDatabase: true);
    _pendingContactFolderRuleSyncLoaded = true;
  }

  Future<void> _persistPendingContactFolderRuleSync() async {
    if (!_pendingContactFolderRuleSyncLoaded) {
      return;
    }
    await _dbOp<XmppStateStore>(
      (ss) async => ss.write(
        key: _contactFolderRuleSyncPendingPublishesKey,
        value: _pendingContactFolderRulePublishes.toList(growable: false),
      ),
      awaitDatabase: true,
    );
  }

  Future<void> _queueContactFolderRulePublish(String itemId) async {
    final normalized = itemId.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingContactFolderRuleSyncLoaded();
    _pendingContactFolderRulePublishes.add(normalized);
    await _persistPendingContactFolderRuleSync();
  }

  Future<void> _clearPendingContactFolderRulePublish(String itemId) async {
    final normalized = itemId.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _ensurePendingContactFolderRuleSyncLoaded();
    final removed = _pendingContactFolderRulePublishes.remove(normalized);
    if (!removed) {
      return;
    }
    await _persistPendingContactFolderRuleSync();
  }

  Future<void> _flushPendingContactFolderRuleSync({
    ContactFolderRulesPubSubManager? managerOverride,
    bool managerReady = false,
  }) async {
    await _ensurePendingContactFolderRuleSyncLoaded();
    if (_pendingContactFolderRulePublishes.isEmpty) {
      return;
    }
    final support = await refreshPubSubSupport();
    final decision = decidePubSubSupport(
      supported: support.canUsePepNodes,
      featureLabel: 'contact folder rule sync',
    );
    if (!decision.isAllowed) {
      return;
    }
    final manager = managerOverride ?? _contactFolderRulesManager;
    if (manager == null) {
      return;
    }
    if (!managerReady) {
      await manager.ensureNode();
      await manager.subscribe();
    }
    final localEntries = await _localContactFolderRuleEntries(
      includeInactive: true,
    );
    final localByItemId = <String, ContactPreference>{
      for (final entry in localEntries)
        ContactFolderRuleSyncPayload.itemIdFor(addressKey: entry.addressKey):
            entry,
    };
    final pendingPublishes = _pendingContactFolderRulePublishes.toList(
      growable: false,
    );
    for (final itemId in pendingPublishes) {
      final localEntry = localByItemId[itemId];
      if (localEntry == null) {
        _pendingContactFolderRulePublishes.remove(itemId);
        continue;
      }
      final published = await manager.publishEntry(
        _buildContactFolderRulePayload(localEntry),
      );
      if (published) {
        _pendingContactFolderRulePublishes.remove(itemId);
      }
    }
    await _persistPendingContactFolderRuleSync();
  }

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _contactFolderRuleSyncSnapshotBootstrapOperationName,
        priority: 0,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.fullNegotiation,
          XmppBootstrapTrigger.manualRefresh,
        },
        operationName: _contactFolderRuleSyncSnapshotBootstrapOperationName,
        run: () async {
          await syncContactFolderRulesSnapshot();
        },
      ),
    );
    registerBootstrapOperation(
      XmppBootstrapOperation(
        key: _contactFolderRuleSyncFlushPendingOperationName,
        priority: 2,
        triggers: const <XmppBootstrapTrigger>{
          XmppBootstrapTrigger.resumedNegotiation,
        },
        operationName: _contactFolderRuleSyncFlushPendingOperationName,
        run: () async {
          await _flushPendingContactFolderRuleSync();
        },
      ),
    );
    manager.registerHandler<ContactFolderRuleSyncUpdatedEvent>((event) async {
      await _applyContactFolderRuleSyncUpdate(event.payload);
    });
  }

  @override
  List<mox.XmppManagerBase> get pubSubFeatureManagers => <mox.XmppManagerBase>[
    ...super.pubSubFeatureManagers,
    ContactFolderRulesPubSubManager(),
  ];

  @override
  List<String> get discoFeatures => <String>[
    ...super.discoFeatures,
    contactFolderRulesNotifyFeature,
  ];
}
