part of 'package:axichat/src/xmpp/xmpp_service.dart';

final _omemoLogger = Logger('OmemoService');

mixin OmemoService on XmppBase {
  var _omemoManager = ImpatientCompleter(Completer<mox.OmemoManager>());

  @override
  bool get needsReset => super.needsReset || _omemoManager.isCompleted;

  @override
  EventManager<mox.XmppEvent> get _eventManager => super._eventManager
    ..registerHandler<mox.OmemoDeviceListUpdatedEvent>((event) async {
      await _dbOp<XmppDatabase>(
        (db) => db.updateChatAlert(
          chatJid: event.jid.toBare().toString(),
          alert: 'Contact added new devices to this chat',
        ),
      );
    })
    ..registerHandler<mox.StanzaSendingCancelledEvent>((event) async {
      if (event.data.encryptionError == null || event.data.stanza.id == null) {
        return;
      }
      late final Object? error;
      if (event.data.cancelReason
          case final mox.OmemoNotSupportedForContactException
              notSupportedForContactException) {
        error = notSupportedForContactException;
      } else if (event.data.cancelReason is mox.UnknownOmemoError) {
        error = (event.data.encryptionError as mox.OmemoEncryptionError)
            .deviceEncryptionErrors
            .values
            .first
            .singleOrNull
            ?.error;
      }
      await _dbOp<XmppDatabase>(
        (db) => db.saveMessageError(
          error: MessageError.fromOmemo(error),
          stanzaID: event.data.stanza.id!,
        ),
      );
    });

  @override
  List<mox.XmppManagerBase> get featureManagers {
    final managers = super.featureManagers;
    // Add the OMEMO manager if it's been initialized
    if (_omemoManager.isCompleted) {
      try {
        managers.add(_omemoManager.value!);
      } catch (_) {
        // Manager not yet available
      }
    }
    return managers;
  }

  /// Get or create the OMEMO device from database
  Future<omemo.OmemoDevice> _getOrCreateDevice() async {
    // Try to get existing device from database
    final existingDevice = await _dbOpReturning<XmppDatabase, OmemoDevice?>(
      (db) async {
        try {
          return await db.getOmemoDevice(myJid!);
        } catch (e) {
          return null;
        }
      },
    );

    if (existingDevice != null) {
      return existingDevice;
    }

    // Generate a new device if none exists
    final newDevice = await mox.OmemoManager.generateUniqueDevice(
      jid: myJid!,
      connection: _connection,
    );

    // Save the new device to database
    await _dbOp<XmppDatabase>(
      (db) async {
        await db.saveOmemoDevice(OmemoDevice.fromMox(newDevice));
      },
    );

    return newDevice;
  }

  /// Create the persistence implementation for OMEMO
  Future<mox.OmemoPersistence?> _createPersistence() async {
    return _OmemoPersistenceImpl(this);
  }

  Future<void> _completeOmemoManager() async {
    if (_omemoManager.isCompleted) return;

    try {
      // Get the OMEMO device from database or generate a new one
      final device = await _getOrCreateDevice();

      // Create the OmemoManager with the new v0.5.0 API
      final manager = mox.OmemoManager(
        _shouldEncryptStanza, // ShouldEncryptStanzaCallback
        device, // OmemoDevice
        const mox.TrustManagerConfig.btbv(), // Use BTBV trust manager config
        persistence: await _createPersistence(), // Optional persistence
        enableMessageQueueing: true, // Prevent race conditions
        heartbeatInterval: const Duration(hours: 48), // Auto heartbeat
      );

      // Complete the future with the manager
      _omemoManager.complete(manager);

      // Note: The manager will be registered via featureManagers list

      // Ensure our device is published
      await _ensureOmemoDevicePublished();
    } catch (e) {
      _omemoLogger.severe('Failed to initialize OmemoManager: $e');
      // Don't complete the completer on error to allow retry
    }
  }

  Future<mox.OmemoManager> _getOmemoManager() async {
    if (!_omemoManager.isCompleted) await _completeOmemoManager();
    return _omemoManager.value!;
  }

  Future<bool> _shouldEncryptStanza(mox.JID to, mox.Stanza stanza) async {
    return await _dbOpReturning<XmppDatabase, bool>(
      (db) async {
        final chat = await db.getChat(to.toBare().toString());
        return chat?.encryptionProtocol == EncryptionProtocol.omemo;
      },
    );
  }

  Future<mox.OmemoError?> _ensureOmemoDevicePublished() async {
    // Device publishing is now handled internally by OmemoManager
    // when it's initialized with the device
    return null;
  }

  Future<OmemoFingerprint?> getCurrentFingerprint() async {
    final device = await _getOrCreateDevice();

    // Generate fingerprint from device's identity key
    final identityKeyBytes = await device.ik.pk.getBytes();
    final fingerprint = base64.encode(identityKeyBytes);

    return OmemoFingerprint(
      jid: myJid!,
      fingerprint: fingerprint,
      deviceID: device.id,
      trust: BTBVTrustState.blindTrust,
      trusted: true,
    );
  }

  Future<List<OmemoFingerprint>> getFingerprints({required String jid}) async {
    final trusts = await _dbOpReturning<XmppDatabase, List<OmemoTrust>>(
      (db) async {
        try {
          return await db.getOmemoTrusts(jid);
        } catch (e) {
          return <OmemoTrust>[];
        }
      },
    );

    // Get device list for the JID
    final deviceList = await _dbOpReturning<XmppDatabase, OmemoDeviceList?>(
      (db) => db.getOmemoDeviceList(jid),
    );

    if (deviceList == null) return [];

    return deviceList.devices.map((deviceId) {
      final trust = trusts.singleWhere(
        (t) => t.device == deviceId,
        orElse: () => OmemoTrust(jid: jid, device: deviceId),
      );

      return OmemoFingerprint(
        jid: jid,
        fingerprint: 'pending', // Will be populated when we have ratchets
        deviceID: deviceId,
        trust: trust.state,
        trusted: trust.trusted,
        enabled: trust.enabled,
        label: trust.label,
      );
    }).toList();
  }

  Future<void> populateTrustCache({required String jid}) async {
    // Trust cache population is now handled internally by moxxmpp
    // through the persistence layer
  }

  Future<void> setDeviceTrust({
    required String jid,
    required int device,
    required BTBVTrustState trust,
  }) async {
    // Store trust decision in database
    await _dbOp<XmppDatabase>(
      (db) => db.setOmemoTrust(
        OmemoTrust(
          jid: jid,
          device: device,
          trust: trust,
        ),
      ),
    );
  }

  Future<void> labelFingerprint({
    required String jid,
    required int device,
    String? label,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.setOmemoTrustLabel(
        jid: jid,
        device: device,
        label: label,
      ),
    );
  }

  Future<void> regenerateDevice() async {
    final old = await _getOrCreateDevice();

    // Generate a new device
    final newDevice = await mox.OmemoManager.generateUniqueDevice(
      jid: myJid!,
      connection: _connection,
    );

    // Save the new device to database
    await _dbOp<XmppDatabase>(
      (db) async {
        await db.saveOmemoDevice(OmemoDevice.fromMox(newDevice));
      },
    );

    // Delete the old device from server
    await _connection.getManager<mox.OmemoManager>()?.deleteDevice(old.id);

    // Reinitialize the manager with the new device
    _omemoManager = ImpatientCompleter(Completer<mox.OmemoManager>());
    await _completeOmemoManager();
  }

  Future<void> recreateSessions({required String jid}) async {
    // Get all devices for the JID to remove their ratchets
    final deviceList = await _dbOpReturning<XmppDatabase, OmemoDeviceList?>(
      (db) => db.getOmemoDeviceList(jid),
    );

    if (deviceList != null && deviceList.devices.isNotEmpty) {
      // Remove all ratchets for the JID from database
      await _dbOp<XmppDatabase>(
        (db) => db.removeOmemoRatchets(
          deviceList.devices.map((deviceId) => (jid, deviceId)).toList(),
        ),
      );
    }

    // Send heartbeat to re-establish sessions
    final manager = await _getOmemoManager();
    await manager.sendOmemoHeartbeat(jid);
  }

  @override
  Future<void> _reset() async {
    await super._reset();
    _omemoManager = ImpatientCompleter(Completer<mox.OmemoManager>());
  }
}

// OmemoDeviceData extension removed - moxxmpp v0.5.0 OmemoManager handles
// device attachment internally. The OmemoDeviceData class in message_models.dart
// is still used for extracting device info from received messages.

/// Database-backed implementation of [mox.OmemoPersistence] for axichat.
///
/// This class provides persistent storage for OMEMO data using the app's
/// SQLCipher database. It handles device storage, ratchet sessions,
/// device lists, trust decisions, and bundle caching.
class _OmemoPersistenceImpl implements mox.OmemoPersistence {
  _OmemoPersistenceImpl(this._service);

  final OmemoService _service;

  @override
  Future<void> storeDevice(omemo.OmemoDevice device) async {
    await _service._dbOp<XmppDatabase>(
      (db) => db.saveOmemoDevice(OmemoDevice.fromMox(device)),
    );
  }

  @override
  Future<omemo.OmemoDevice?> loadDevice() async {
    return await _service._dbOpReturning<XmppDatabase, OmemoDevice?>(
      (db) async {
        try {
          return await db.getOmemoDevice(_service.myJid!);
        } catch (e) {
          return null;
        }
      },
    );
  }

  @override
  Future<void> deleteDevice() async {
    await _service._dbOp<XmppDatabase>(
      (db) => db.deleteOmemoDevice(_service.myJid!),
    );
  }

  @override
  Future<void> storeRatchets(List<omemo.OmemoRatchetData> ratchets) async {
    _omemoLogger.info('Storing ${ratchets.length} ratchets');

    await _service._dbOp<XmppDatabase>((db) async {
      for (final ratchetData in ratchets) {
        // Store the OmemoDoubleRatchet directly as serialized data
        final ratchet = await OmemoRatchet.fromDoubleRatchet(
          jid: ratchetData.jid,
          device: ratchetData.id,
          ratchet: ratchetData.ratchet,
        );
        await db.saveOmemoRatchet(ratchet);
      }
    });
  }

  @override
  Future<void> removeRatchets(List<RatchetMapKey> keys) async {
    final keyPairs = keys.map((key) => (key.jid, key.deviceId)).toList();
    await _service._dbOp<XmppDatabase>(
      (db) => db.removeOmemoRatchets(keyPairs),
    );
  }

  @override
  Future<OmemoDataPackage?> loadRatchets(String jid) async {
    return await _service._dbOpReturning<XmppDatabase, OmemoDataPackage?>(
      (db) async {
        // Load device list
        final deviceListData = await db.getOmemoDeviceList(jid);
        final deviceList = deviceListData?.devices ?? <int>[];

        // Load ratchets for this JID
        final ratchetList = await db.getOmemoRatchets(jid);
        final ratchets = <RatchetMapKey, omemo.OmemoDoubleRatchet>{};

        // During migration, we don't load ratchets from storage
        // This allows the OMEMO manager to establish new sessions as needed
        // The stored ratchets are placeholder entries from the migration

        _omemoLogger.info(
          'Migration mode: Found ${ratchetList.length} placeholder ratchets for $jid, will establish new sessions as needed',
        );

        if (deviceList.isEmpty && ratchets.isEmpty) return null;

        return OmemoDataPackage(deviceList, ratchets);
      },
    );
  }

  @override
  Future<void> storeDeviceList(String jid, List<int> devices) async {
    final deviceList = OmemoDeviceList(jid: jid, devices: devices);
    await _service._dbOp<XmppDatabase>(
      (db) => db.saveOmemoDeviceList(deviceList),
    );
  }

  @override
  Future<List<int>?> loadDeviceList(String jid) async {
    final deviceList =
        await _service._dbOpReturning<XmppDatabase, OmemoDeviceList?>(
      (db) => db.getOmemoDeviceList(jid),
    );
    return deviceList?.devices;
  }

  @override
  Future<void> clearDeviceList(String jid) async {
    await _service._dbOp<XmppDatabase>(
      (db) => db.deleteOmemoDeviceList(jid),
    );
  }

  @override
  Future<void> storeTrust(String jid, int deviceId, int trustState) async {
    // Convert int trust state to BTBVTrustState enum
    final trust = switch (trustState) {
      0 => BTBVTrustState.notTrusted,
      1 => BTBVTrustState.blindTrust,
      2 => BTBVTrustState.verified,
      _ => BTBVTrustState.blindTrust, // Default fallback
    };

    final trustData = OmemoTrust(
      jid: jid,
      device: deviceId,
      trust: trust,
      enabled: trustState > 0, // Enabled if trusted or verified
      trusted: trustState == 2, // Only verified is fully trusted
    );

    await _service._dbOp<XmppDatabase>(
      (db) => db.setOmemoTrust(trustData),
    );
  }

  @override
  Future<int?> loadTrust(String jid, int deviceId) async {
    final trust = await _service._dbOpReturning<XmppDatabase, OmemoTrust?>(
      (db) async {
        try {
          final trusts = await db.getOmemoTrusts(jid);
          return trusts.singleWhere((t) => t.device == deviceId);
        } catch (e) {
          return null;
        }
      },
    );

    if (trust == null) return null;

    // Convert BTBVTrustState back to int
    return switch (trust.state) {
      BTBVTrustState.notTrusted => 0,
      BTBVTrustState.blindTrust => 1,
      BTBVTrustState.verified => 2,
    };
  }

  @override
  Future<Map<String, Map<int, int>>> loadAllTrust() async {
    final allTrusts =
        await _service._dbOpReturning<XmppDatabase, List<OmemoTrust>>(
      (db) async {
        try {
          // Get all trust entries from database
          return await db.getAllOmemoTrusts();
        } catch (e) {
          return <OmemoTrust>[];
        }
      },
    );

    final result = <String, Map<int, int>>{};

    for (final trust in allTrusts) {
      final jidMap = result.putIfAbsent(trust.jid, () => <int, int>{});

      // Convert BTBVTrustState to int
      final trustValue = switch (trust.state) {
        BTBVTrustState.notTrusted => 0,
        BTBVTrustState.blindTrust => 1,
        BTBVTrustState.verified => 2,
      };

      jidMap[trust.device] = trustValue;
    }

    return result;
  }

  @override
  Future<void> cacheBundle(
      String jid, int deviceId, omemo.OmemoBundle bundle) async {
    // Bundle caching is not implemented in our current database schema
    // This would require adding a bundles table with TTL
    // For now, we'll no-op this
  }

  @override
  Future<omemo.OmemoBundle?> getCachedBundle(String jid, int deviceId) async {
    // Bundle caching is not implemented
    return null;
  }

  @override
  Future<void> clearBundleCache() async {
    // Bundle caching is not implemented
  }

  @override
  Future<void> storeLastPreKeyRotation(DateTime timestamp) async {
    // PreKey rotation tracking is not implemented in our current database schema
    // This would require adding a metadata table
    // For now, we'll no-op this
  }

  @override
  Future<DateTime?> loadLastPreKeyRotation() async {
    // PreKey rotation tracking is not implemented
    return null;
  }
}

// Old OMEMO manager implementation removed - moxxmpp v0.5.0 OmemoManager
// handles stanza processing internally via its own handlers
