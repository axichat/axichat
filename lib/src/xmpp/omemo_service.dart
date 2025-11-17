part of 'package:axichat/src/xmpp/xmpp_service.dart';

final _omemoLogger = Logger('OmemoService');

mixin OmemoService on XmppBase {
  var _omemoManager = ImpatientCompleter(Completer<mox.OmemoManager>());
  mox.OmemoPersistence? _omemoPersistence;
  Future<void>? _pendingOmemoInitialization;

  @override
  bool get needsReset => super.needsReset || _omemoManager.isCompleted;

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
        if (event.resumed) return;
        _omemoLogger.info(
            'Stream negotiation done, ensuring OMEMO device is published...');
        if (_omemoManager.isCompleted) {
          await _ensureOmemoDevicePublished();
        } else {
          _omemoLogger.warning(
              'OMEMO manager not ready during stream negotiation done');
        }
      })
      ..registerHandler<mox.OmemoDeviceListUpdatedEvent>((event) async {
        final isSelfUpdate =
            myJid != null && event.jid.toBare().toString() == myJid;
        _omemoLogger.fine(
          'Received OMEMO device list update for '
          '${isSelfUpdate ? 'self' : 'contact'}; '
          'devices=${event.deviceList.length}.',
        );
        await _dbOp<XmppDatabase>(
          (db) => db.updateChatAlert(
            chatJid: event.jid.toBare().toString(),
            alert: 'Contact added new devices to this chat',
          ),
        );
      })
      ..registerHandler<mox.StanzaSendingCancelledEvent>((event) async {
        if (event.data.encryptionError == null ||
            event.data.stanza.id == null) {
          return;
        }
        late final Object? error;
        if (event.data.cancelReason
            case final mox.OmemoNotSupportedForContactException
                notSupportedForContactException) {
          error = notSupportedForContactException;
        } else if (event.data.cancelReason is mox.UnknownOmemoError) {
          final encryptionError =
              event.data.encryptionError as mox.OmemoEncryptionError;
          Object? extractedError;
          for (final deviceErrors
              in encryptionError.deviceEncryptionErrors.values) {
            if (deviceErrors.isEmpty) continue;
            extractedError = deviceErrors.first.error;
            break;
          }
          error = extractedError ?? omemo.NoKeyMaterialAvailableError();
        }
        var messageError = MessageError.fromOmemo(error);
        if (messageError.isNone &&
            event.data.cancelReason is mox.UnknownOmemoError) {
          messageError = MessageError.noKeyMaterial;
        }
        await _dbOp<XmppDatabase>(
          (db) => db.saveMessageError(
            error: messageError,
            stanzaID: event.data.stanza.id!,
          ),
        );
      });
  }

  @override
  List<mox.XmppManagerBase> get featureManagers {
    final managers = super.featureManagers;
    // OMEMO manager should now be completed during _initConnection()
    // before featureManagers is called
    if (_omemoManager.isCompleted) {
      try {
        final manager = _omemoManager.value;
        if (manager != null) {
          managers.add(manager);
          _omemoLogger.info('OMEMO manager added to featureManagers');
        }
      } catch (e) {
        _omemoLogger.severe('OMEMO manager completed but not available: $e');
      }
    } else {
      _omemoLogger
          .warning('OMEMO manager not completed when featureManagers called');
    }
    return managers;
  }

  /// Device callback for lazy loading - called when OMEMO manager needs the device
  Future<omemo.OmemoDevice> _getDeviceCallback() async {
    final jid = myJid;
    if (jid == null) {
      _omemoLogger.warning(
        'Attempted to resolve OMEMO device before JID was available.',
      );
      throw mox.OmemoManagerNotInitializedError();
    }
    return await _dbOpReturning<XmppDatabase, omemo.OmemoDevice>(
      (db) async {
        try {
          // Try to get existing device from database
          final existingDevice = await db.getOmemoDevice(jid);
          if (existingDevice != null) {
            return existingDevice;
          }

          // Generate new device if none exists
          _omemoLogger.info('Generating new OMEMO device...');
          final payload = await compute(
            _generateOmemoDevicePayload,
            _OmemoDeviceGenerationArgs(jid: jid, excludedIds: const []),
          );
          final newDevice = _rebuildOmemoDevice(payload);
          await db.saveOmemoDevice(newDevice);
          _omemoLogger.info(
              'New OMEMO device generated and saved with ID: ${newDevice.id}');
          return newDevice;
        } catch (e) {
          _omemoLogger.severe('Device callback failed: $e');
          rethrow;
        }
      },
    );
  }

  /// Get or create the OMEMO device from database
  Future<omemo.OmemoDevice> _getOrCreateDevice() async {
    final jid = myJid;
    if (jid == null) {
      _omemoLogger.warning(
        'Attempted to access OMEMO device before JID was available.',
      );
      throw mox.OmemoManagerNotInitializedError();
    }
    // Try to get existing device from database
    final existingDevice = await _dbOpReturning<XmppDatabase, OmemoDevice?>(
      (db) async {
        try {
          return await db.getOmemoDevice(jid);
        } catch (e) {
          return null;
        }
      },
    );

    if (existingDevice != null) {
      return existingDevice;
    }

    final reservedIds = await _dbOpReturning<XmppDatabase, List<int>>(
      (db) async =>
          (await db.getOmemoDeviceList(jid))?.devices.toList() ?? <int>[],
    );

    final payload = await compute(
      _generateOmemoDevicePayload,
      _OmemoDeviceGenerationArgs(jid: jid, excludedIds: reservedIds),
    );

    final newDevice = _rebuildOmemoDevice(payload);

    await _dbOp<XmppDatabase>(
      (db) async {
        await db.saveOmemoDevice(newDevice);
      },
    );

    await _persistOwnDeviceId(newDevice.id);

    return newDevice;
  }

  Future<void> _persistOwnDeviceId(int deviceId) async {
    final jid = myJid;
    if (jid == null) {
      return;
    }

    await _dbOp<XmppDatabase>((db) async {
      final existing = await db.getOmemoDeviceList(jid);
      final devicesSet = <int>{
        deviceId,
        if (existing != null) ...existing.devices,
      };
      final devices = devicesSet.toList()..sort();

      await db.saveOmemoDeviceList(
        OmemoDeviceList(jid: jid, devices: devices),
      );
    });
  }

  Future<void> _refreshOwnDeviceListCache() async {
    if (!_omemoManager.isCompleted) return;

    final jid = myJid;
    if (jid == null) {
      return;
    }

    try {
      final manager = await _getOmemoManager();
      if (!manager.isInitialized) {
        return;
      }

      await manager.fetchDeviceList(jid);
    } catch (error, stackTrace) {
      _omemoLogger.fine(
        'Unable to refresh OMEMO device list cache after publishing device.',
        error,
        stackTrace,
      );
    }
  }

  /// Create the persistence implementation for OMEMO
  Future<mox.OmemoPersistence?> _createPersistence() async {
    return _OmemoPersistenceImpl(this);
  }

  Future<void> _completeOmemoManager() async {
    if (_omemoManager.isCompleted) return;

    if (myJid == null) {
      _omemoLogger.fine('Deferring OmemoManager creation until JID is known.');
      return;
    }

    try {
      _omemoLogger.info('Creating OMEMO manager (manual initialization)...');

      final manager = mox.OmemoManager(
        _shouldEncryptStanza,
        _getDeviceCallback,
        const mox.TrustManagerConfig.btbv(),
        enableMessageQueueing: true,
        initializeManually: true,
      );

      _omemoManager.complete(manager);
      _omemoLogger.info('OMEMO manager created; initialization deferred.');
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
        final chatJid = to.toBare().toString();
        final chat = await db.getChat(chatJid);
        final shouldEncrypt =
            chat?.encryptionProtocol == EncryptionProtocol.omemo;

        if (shouldEncrypt) {
          _omemoLogger.fine('Encrypting message to $chatJid with OMEMO');
        }

        return shouldEncrypt;
      },
    );
  }

  Future<mox.OmemoError?> _ensureOmemoDevicePublished() async {
    final jid = myJid;
    if (jid == null) return null;

    final manager = await _getOmemoManager();
    if (!manager.isInitialized) {
      _omemoLogger.fine('Skipping OMEMO publish; manager not initialized.');
      return null;
    }

    if (!manager.initialized) {
      _omemoLogger.fine('Skipping OMEMO publish; manager not registered yet.');
      return null;
    }

    // One-time reset of the bundles node to ensure maxItems='max'
    // if (!_bundlesNodeReset) {
    //   _bundlesNodeReset = true;
    //   _omemoLogger.info('Performing one-time OMEMO bundles node reset...');
    //   final resetSuccess = await _resetOmemoBundlesNode();
    //   if (!resetSuccess) {
    //     _omemoLogger
    //         .warning('Failed to reset OMEMO bundles node, continuing anyway');
    //   }
    // }

    try {
      final device = await _getOrCreateDevice();
      final deviceListResult =
          await manager.getDeviceList(mox.JID.fromString(jid));

      if (deviceListResult.isType<List<int>>()) {
        final devices = deviceListResult.get<List<int>>();
        if (devices.contains(device.id)) {
          _omemoLogger.fine('Device already published');
          return null;
        }
      }

      return await _publishOwnDeviceBundle(manager, device);
    } on Error catch (error, stackTrace) {
      final errorType = error.runtimeType.toString();
      if (errorType.contains('LateInitializationError')) {
        _omemoLogger.fine(
          'Skipping OMEMO publish; manager attributes unavailable yet.',
          error,
          stackTrace,
        );
        return null;
      }
      rethrow;
    }
  }

  Future<mox.OmemoError?> _publishOwnDeviceBundle(
    mox.OmemoManager manager,
    omemo.OmemoDevice device,
  ) async {
    final bundle = await device.toBundle();
    final publishResult = await manager.publishBundle(bundle);

    if (publishResult.isType<mox.OmemoError>()) {
      final error = publishResult.get<mox.OmemoError>();
      _omemoLogger.warning('OMEMO bundle publish failed', error);
      return error;
    }

    _omemoLogger.info(
      'OMEMO device bundle published for ${device.jid}:${device.id}.',
    );

    await _persistOwnDeviceId(device.id);
    await _refreshOwnDeviceListCache();

    return null;
  }

  Future<void> _initializeOmemoManagerIfNeeded() async {
    if (_pendingOmemoInitialization != null) {
      await _pendingOmemoInitialization;
      return;
    }

    if (!_omemoManager.isCompleted) {
      await _completeOmemoManager();
      if (!_omemoManager.isCompleted) {
        return;
      }
    }

    final manager = await _getOmemoManager();
    if (manager.isInitialized) {
      return;
    }

    _pendingOmemoInitialization = () async {
      _omemoLogger.info('Initializing OMEMO manager after storage unlock...');
      _omemoPersistence ??= await _createPersistence();

      try {
        await manager.initialize(persistence: _omemoPersistence);
        _omemoLogger.info('OMEMO manager initialization finished.');

        final publishError = await _ensureOmemoDevicePublished();
        if (publishError != null) {
          _omemoLogger.warning(
            'Initial OMEMO publish reported error: $publishError',
          );
        }
      } on mox.OmemoManagerNotInitializedError catch (error, stackTrace) {
        _omemoLogger.warning(
          'OMEMO manager deferred initialization; prerequisites missing.',
          error,
          stackTrace,
        );
        return;
      } catch (error, stackTrace) {
        _omemoLogger.severe(
          'Failed to initialize OMEMO manager after storage unlock.',
          error,
          stackTrace,
        );
        rethrow;
      }
    }();

    try {
      await _pendingOmemoInitialization;
    } finally {
      _pendingOmemoInitialization = null;
    }
  }

  Future<OmemoFingerprint?> getCurrentFingerprint() async {
    try {
      final device = await _getOrCreateDevice();

      // Generate fingerprint from device's identity key
      final identityKeyBytes = await device.ik.pk.getBytes();
      final fingerprint = _hexEncode(identityKeyBytes);

      final jid = myJid;
      if (jid == null) return null;

      return OmemoFingerprint(
        jid: jid,
        fingerprint: fingerprint,
        deviceID: device.id,
        trust: BTBVTrustState.blindTrust,
        trusted: true,
      );
    } on mox.OmemoManagerNotInitializedError {
      _omemoLogger.fine('Fingerprint requested before OMEMO initialization.');
      return null;
    }
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

    final reservedIds = await _dbOpReturning<XmppDatabase, List<int>>(
      (db) async {
        final deviceList = await db.getOmemoDeviceList(myJid!);
        return [
          if (deviceList != null) ...deviceList.devices,
          old.id,
        ];
      },
    );

    final payload = await compute(
      _generateOmemoDevicePayload,
      _OmemoDeviceGenerationArgs(jid: myJid!, excludedIds: reservedIds),
    );

    final newDevice = _rebuildOmemoDevice(payload);

    await _dbOp<XmppDatabase>(
      (db) async {
        await db.saveOmemoDevice(newDevice);
      },
    );

    // Delete the old device from server
    await _connection.getManager<mox.OmemoManager>()?.deleteDevice(old.id);

    // Reinitialize the manager with the new device
    _omemoManager = ImpatientCompleter(Completer<mox.OmemoManager>());
    _omemoPersistence = null;
    await _completeOmemoManager();
    await _initializeOmemoManagerIfNeeded();
  }

  Future<void> recreateSessions({required String jid}) async {
    try {
      await _initializeOmemoManagerIfNeeded();
    } catch (error, stackTrace) {
      _omemoLogger.severe(
        'Failed to initialize OMEMO before recreating sessions for $jid.',
        error,
        stackTrace,
      );
      return;
    }

    final manager = await _getOmemoManager();
    if (!manager.isInitialized) {
      _omemoLogger.warning(
        'Skipping session recreation for $jid; OMEMO manager is not initialized.',
      );
      return;
    }

    await manager.resetAllSessions(mox.JID.fromString(jid));
  }

  @override
  Future<void> _reset() async {
    await super._reset();
    _omemoManager = ImpatientCompleter(Completer<mox.OmemoManager>());
    _omemoPersistence = null;
    _pendingOmemoInitialization = null;
  }
}

String _hexEncode(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

// OmemoDeviceData extension removed - moxxmpp v0.5.0 OmemoManager handles
// device attachment internally. The OmemoDeviceData class in message_models.dart
// is still used for extracting device info from received messages.

class _OmemoDeviceGenerationArgs {
  const _OmemoDeviceGenerationArgs({
    required this.jid,
    required this.excludedIds,
  });

  final String jid;
  final List<int> excludedIds;
}

Future<Map<String, Object?>> _generateOmemoDevicePayload(
  _OmemoDeviceGenerationArgs args,
) async {
  final exclusions = args.excludedIds.toSet();
  late OmemoDevice device;
  do {
    final generatedDevice = await omemo.OmemoDevice.generateNewDevice(args.jid);
    device = OmemoDevice.fromMox(generatedDevice);
  } while (exclusions.contains(device.id));

  return _serializeOmemoDevice(device);
}

Future<Map<String, Object?>> _serializeOmemoDevice(OmemoDevice device) async =>
    {
      'jid': device.jid,
      'id': device.id,
      'identityKey': await device.identityKey.toJson(),
      'signedPreKey': await device.signedPreKey.toJson(),
      'oldSignedPreKey': device.oldSignedPreKey != null
          ? await device.oldSignedPreKey!.toJson()
          : null,
      'onetimePreKeys': await device.onetimePreKeysToJson(),
      'label': device.label,
    };

OmemoDevice _rebuildOmemoDevice(Map<String, Object?> payload) =>
    OmemoDevice.fromDb(
      jid: payload['jid'] as String,
      id: payload['id'] as int,
      identityKey: payload['identityKey'] as String,
      signedPreKey: payload['signedPreKey'] as String,
      oldSignedPreKey: payload['oldSignedPreKey'] as String?,
      onetimePreKeys: payload['onetimePreKeys'] as String,
      label: payload['label'] as String?,
    );

/// Database-backed implementation of [mox.OmemoPersistence] for axichat.
///
/// This class provides persistent storage for OMEMO data using the app's
/// SQLCipher database. It handles device storage, ratchet sessions,
/// device lists, trust decisions, and bundle caching.
class _OmemoPersistenceImpl implements mox.OmemoPersistence {
  _OmemoPersistenceImpl(this._service);

  final OmemoService _service;

  // Registered key for storing prekey rotation timestamp
  static final _prekeyRotationKey =
      XmppStateStore.registerKey('omemo_prekey_rotation');

  static const _bundleCacheTtl = Duration(minutes: 30);

  bool get _hasDatabase => _service.isDatabaseReady;

  bool get _hasStateStore => _service.isStateStoreReady;

  @override
  Future<void> storeDevice(omemo.OmemoDevice device) async {
    if (!_hasDatabase) {
      _omemoLogger.fine('Skipping storeDevice; database not ready yet.');
      return;
    }
    await _service._dbOp<XmppDatabase>(
      (db) => db.saveOmemoDevice(OmemoDevice.fromMox(device)),
    );
  }

  @override
  Future<omemo.OmemoDevice?> loadDevice() async {
    if (!_hasDatabase) return null;
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
    if (!_hasDatabase) return;
    await _service._dbOp<XmppDatabase>(
      (db) => db.deleteOmemoDevice(_service.myJid!),
    );
  }

  @override
  Future<void> storeRatchets(List<omemo.OmemoRatchetData> ratchets) async {
    if (!_hasDatabase) return;
    if (ratchets.isEmpty) {
      _omemoLogger.fine('No ratchets provided to storeRatchets; skipping.');
      return;
    }

    _omemoLogger.info('Storing ${ratchets.length} ratchets');

    await _service._dbOp<XmppDatabase>((db) async {
      for (final ratchetData in ratchets) {
        _service.emitOmemoActivity(
          mox.OmemoActivityEvent(
            operation: mox.OmemoActivityOperation.persistRatchets,
            stage: mox.OmemoActivityStage.start,
            jid: ratchetData.jid,
            deviceId: ratchetData.id,
          ),
        );
        try {
          final ratchet = await OmemoRatchet.fromDoubleRatchet(
            jid: ratchetData.jid,
            device: ratchetData.id,
            ratchet: ratchetData.ratchet,
          );
          await db.saveOmemoRatchet(ratchet);
          _service.emitOmemoActivity(
            mox.OmemoActivityEvent(
              operation: mox.OmemoActivityOperation.persistRatchets,
              stage: mox.OmemoActivityStage.end,
              jid: ratchetData.jid,
              deviceId: ratchetData.id,
            ),
          );
        } catch (error, stackTrace) {
          _omemoLogger.severe(
            'Failed to persist ratchet for ${ratchetData.jid}:${ratchetData.id}.',
            error,
            stackTrace,
          );
          _service.emitOmemoActivity(
            mox.OmemoActivityEvent(
              operation: mox.OmemoActivityOperation.persistRatchets,
              stage: mox.OmemoActivityStage.end,
              jid: ratchetData.jid,
              deviceId: ratchetData.id,
              error: error,
            ),
          );
          rethrow;
        }
      }
    });
  }

  @override
  Future<void> removeRatchets(List<RatchetMapKey> keys) async {
    if (!_hasDatabase) return;
    final keyPairs = keys.map((key) => (key.jid, key.deviceId)).toList();
    await _service._dbOp<XmppDatabase>(
      (db) => db.removeOmemoRatchets(keyPairs),
    );
  }

  @override
  Future<OmemoDataPackage?> loadRatchets(String jid) async {
    if (!_hasDatabase) return null;
    return await _service._dbOpReturning<XmppDatabase, OmemoDataPackage?>(
      (db) async {
        // Load device list
        final deviceListData = await db.getOmemoDeviceList(jid);
        final deviceList = deviceListData?.devices ?? <int>[];

        // Load ratchets for this JID
        final ratchetList = await db.getOmemoRatchets(jid);
        final ratchets = <RatchetMapKey, omemo.OmemoDoubleRatchet>{};

        for (final entry in ratchetList) {
          try {
            final ratchet = await entry.toDoubleRatchet();
            if (ratchet != null) {
              ratchets[RatchetMapKey(entry.jid, entry.device)] = ratchet;
            }
          } catch (error, stackTrace) {
            _omemoLogger.warning(
              'Failed to restore ratchet for ${entry.jid}:${entry.device}',
              error,
              stackTrace,
            );
          }
        }

        if (deviceList.isEmpty && ratchets.isEmpty) return null;

        return OmemoDataPackage(deviceList, ratchets);
      },
    );
  }

  @override
  Future<void> storeDeviceList(String jid, List<int> devices) async {
    if (!_hasDatabase) return;
    final deviceList = OmemoDeviceList(jid: jid, devices: devices);
    await _service._dbOp<XmppDatabase>(
      (db) => db.saveOmemoDeviceList(deviceList),
    );
  }

  @override
  Future<List<int>?> loadDeviceList(String jid) async {
    if (!_hasDatabase) return null;
    final deviceList =
        await _service._dbOpReturning<XmppDatabase, OmemoDeviceList?>(
      (db) => db.getOmemoDeviceList(jid),
    );
    return deviceList?.devices;
  }

  @override
  Future<void> clearDeviceList(String jid) async {
    if (!_hasDatabase) return;
    await _service._dbOp<XmppDatabase>(
      (db) => db.deleteOmemoDeviceList(jid),
    );
  }

  @override
  Future<void> storeTrust(String jid, int deviceId, int trustState) async {
    if (!_hasDatabase) return;
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
    if (!_hasDatabase) return null;
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
    if (!_hasDatabase) return <String, Map<int, int>>{};
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
    if (!_hasDatabase) return;
    final cacheEntry = OmemoBundleCache.fromBundle(
      jid: jid,
      bundle: bundle,
    );
    await _service._dbOp<XmppDatabase>(
      (db) => db.saveOmemoBundleCache(cacheEntry),
    );
  }

  @override
  Future<omemo.OmemoBundle?> getCachedBundle(String jid, int deviceId) async {
    if (!_hasDatabase) return null;
    return await _service._dbOpReturning<XmppDatabase, omemo.OmemoBundle?>(
      (db) async {
        final cache = await db.getOmemoBundleCache(jid, deviceId);
        if (cache == null) return null;
        final now = DateTime.timestamp();
        if (now.difference(cache.updatedAt) > _bundleCacheTtl) {
          await db.removeOmemoBundleCache(jid, deviceId);
          return null;
        }
        return cache.toBundle();
      },
    );
  }

  @override
  Future<void> removeCachedBundle(String jid, int deviceId) async {
    if (!_hasDatabase) return;
    await _service._dbOp<XmppDatabase>(
      (db) => db.removeOmemoBundleCache(jid, deviceId),
    );
  }

  @override
  Future<void> clearBundleCache() async {
    if (!_hasDatabase) return;
    await _service._dbOp<XmppDatabase>(
      (db) => db.clearOmemoBundleCache(),
    );
  }

  @override
  Future<void> storeLastPreKeyRotation(DateTime timestamp) async {
    if (!_hasStateStore) return;
    await _service._dbOp<XmppStateStore>(
      (stateStore) => stateStore.write(
        key: _prekeyRotationKey,
        value: timestamp.millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Future<DateTime?> loadLastPreKeyRotation() async {
    if (!_hasStateStore) return null;
    final timestampMs = await _service._dbOpReturning<XmppStateStore, int?>(
      (stateStore) => stateStore.read(key: _prekeyRotationKey) as int?,
    );

    if (timestampMs == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestampMs);
  }
}

// Old OMEMO manager implementation removed - moxxmpp v0.5.0 OmemoManager
// handles stanza processing internally via its own handlers
