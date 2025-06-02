part of 'package:axichat/src/xmpp/xmpp_service.dart';

mixin OmemoService on XmppBase {
  var _omemoManager = ImpatientCompleter(Completer<omemo.OmemoManager>());

  @override
  bool get needsReset => super.needsReset || _omemoManager.isCompleted;

  @override
  EventManager<mox.XmppEvent> get _eventManager => super._eventManager
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
      await _dbOp<XmppDatabase>((db) async {
        await db.saveMessageError(
          error: MessageError.fromOmemo(error),
          stanzaID: event.data.stanza.id!,
        );
      });
    });

  Future<void> _completeOmemoManager() async {
    OmemoDevice? device = await _dbOpReturning<XmppDatabase, OmemoDevice?>(
      (db) async {
        return await db.getOmemoDevice(myJid!);
      },
    );

    final om = _connection.getManager<mox.OmemoManager>()!;

    _omemoManager.complete(
      omemo.OmemoManager(
        device ??
            OmemoDevice.fromMox(
                await compute(omemo.OmemoDevice.generateNewDevice, myJid!)),
        omemo.BlindTrustBeforeVerificationTrustManager(
          commit: (trust) => _dbOp<XmppDatabase>(
            (db) => db.setOmemoTrust(trust),
          ),
          loadData: (jid) async =>
              await _dbOpReturning<XmppDatabase, List<omemo.BTBVTrustData>>(
            (db) => db.getOmemoTrust(jid),
          ),
          removeTrust: (jid) => _dbOp<XmppDatabase>(
            (db) => db.resetOmemoTrust(jid),
          ),
        ),
        om.sendEmptyMessageImpl,
        om.fetchDeviceList,
        om.fetchDeviceBundle,
        om.subscribeToDeviceListImpl,
        om.publishDeviceImpl,
        commitDevice: (device) => _dbOp<XmppDatabase>(
          (db) => db.saveOmemoDevice(OmemoDevice.fromMox(device)),
        ),
        commitDeviceList: (jid, devices) => _dbOp<XmppDatabase>(
          (db) => db.saveOmemoDeviceList(OmemoDeviceList(
            jid: jid,
            devices: devices,
          )),
        ),
        commitRatchets: (ratchets) => _dbOp<XmppDatabase>(
          (db) => db.saveOmemoRatchets(
            ratchets.map((e) => OmemoRatchet.fromMox(e)).toList(),
          ),
        ),
        loadRatchets: (jid) async =>
            await _dbOpReturning<XmppDatabase, omemo.OmemoDataPackage?>(
          (db) async {
            final devices = await db.getOmemoDeviceList(jid);
            if (devices == null || devices.devices.isEmpty) return null;
            final ratchets = await db.getOmemoRatchets(jid);
            if (ratchets.isEmpty) return null;
            return omemo.OmemoDataPackage(
              devices.devices,
              <omemo.RatchetMapKey, OmemoRatchet>{
                for (final ratchet in ratchets)
                  omemo.RatchetMapKey(ratchet.jid, ratchet.device): ratchet,
              },
            );
          },
        ),
        removeRatchets: (keys) => _dbOp<XmppDatabase>(
          (db) => db.removeOmemoRatchets(
            keys.map((e) => (e.jid, e.deviceId)).toList(),
          ),
        ),
      ),
    );

    await _dbOp<XmppDatabase>((db) async {
      await db.saveOmemoDevice(await _device);
    });
  }

  Future<omemo.OmemoManager> _getOmemoManager() async {
    if (!_omemoManager.isCompleted) await _completeOmemoManager();
    return _omemoManager.value!;
  }

  Future<bool> _shouldEncrypt(mox.JID to, mox.Stanza stanza) async =>
      await _dbOpReturning<XmppDatabase, bool>(
        (db) async {
          final chat = await db.getChat(to.toBare().toString());
          return chat?.encryptionProtocol == EncryptionProtocol.omemo;
        },
      );

  Future<OmemoDevice> get _device async =>
      OmemoDevice.fromMox(await (await _omemoManager.future).getDevice());

  Future<mox.OmemoError?> _publishBundle(
      {required omemo.OmemoBundle bundle}) async {
    final result =
        await _connection.getManager<mox.OmemoManager>()!.publishBundle(bundle);
    if (result.isType<mox.OmemoError>()) {
      return result.get<mox.OmemoError>();
    }

    return null;
  }

  Future<mox.OmemoError?> _ensureOmemoDevicePublished() async {
    final device = await _device;
    final jid = _myJid!.toBare();

    final bundles = await _connection
        .getManager<mox.DiscoManager>()!
        .discoItemsQuery(jid, node: mox.omemoBundlesXmlns);
    if (bundles.isType<mox.DiscoError>()) {
      return _publishBundle(bundle: await device.toBundle());
    }

    final bundleIDs = bundles
        .get<List<mox.DiscoItem>>()
        .where((e) => e.name != null)
        .map((e) => int.parse(e.name!));
    if (!bundleIDs.contains(device.id)) {
      return _publishBundle(bundle: await device.toBundle());
    }

    final result = await _connection
        .getManager<mox.OmemoManager>()!
        .fetchDeviceList(myJid!);
    final devices = result ?? [];
    if (!devices.contains(device.id)) {
      return _publishBundle(bundle: await device.toBundle());
    }

    return null;
  }

  Future<String> getCurrentFingerprint() async =>
      (await _device).getFingerprint();

  Future<List<OmemoFingerprint>> getFingerprints({required String jid}) async {
    var trustMap = <int, omemo.BTBVTrustData>{};
    await _omemoManager.value?.withTrustManager(
      jid,
      (e) async {
        trustMap = await (e as omemo.BlindTrustBeforeVerificationTrustManager)
            .getDevicesTrust(jid);
      },
    );

    final fingerprints =
        await _omemoManager.value?.getFingerprintsForJid(jid) ?? [];
    return fingerprints.map((e) {
      final trust = trustMap[e.deviceId] ??
          omemo.BTBVTrustData(
            jid,
            e.deviceId,
            BTBVTrustState.blindTrust,
            false,
            false,
          );
      return OmemoFingerprint(
        fingerprint: e.fingerprint,
        deviceID: e.deviceId,
        trust: trust.state,
        trusted: trust.trusted,
        enabled: trust.enabled,
      );
    }).toList();
  }

  Future<void> setDeviceTrust({
    required String jid,
    required int device,
    required BTBVTrustState trust,
  }) async {
    await _omemoManager.value?.withTrustManager(
      jid,
      (e) async {
        await (e as omemo.BlindTrustBeforeVerificationTrustManager)
            .setDeviceTrust(jid, device, trust);
      },
    );
  }

  Future<void> regenerateDevice() async {
    final old = await _device;
    await _omemoManager.value?.regenerateDevice();
    await _connection.getManager<mox.OmemoManager>()?.deleteDevice(old.id);
  }

  Future<void> recreateSessions({required String jid}) async {
    await _omemoManager.value?.removeAllRatchets(jid);
    await _connection.getManager<mox.OmemoManager>()!.sendOmemoHeartbeat(jid);
  }

  @override
  Future<void> _reset() async {
    await super._reset();
    _omemoManager = ImpatientCompleter(Completer<omemo.OmemoManager>());
  }
}

// const omemoXmlns = 'eu.siacs.conversations.axolotl';
// const omemoDevicesXmlns = '$omemoXmlns.devicelist';
// const omemoBundlesXmlns = '$omemoXmlns.bundles';
//
// const _doNotEncryptList = [
//   // XEP-0033
//   mox.DoNotEncrypt('addresses', mox.extendedAddressingXmlns),
//   // XEP-0060
//   mox.DoNotEncrypt('pubsub', mox.pubsubXmlns),
//   mox.DoNotEncrypt('pubsub', mox.pubsubOwnerXmlns),
//   // XEP-0334
//   mox.DoNotEncrypt('no-permanent-store', mox.messageProcessingHintsXmlns),
//   mox.DoNotEncrypt('no-store', mox.messageProcessingHintsXmlns),
//   mox.DoNotEncrypt('no-copy', mox.messageProcessingHintsXmlns),
//   mox.DoNotEncrypt('store', mox.messageProcessingHintsXmlns),
//   // XEP-0359
//   mox.DoNotEncrypt('origin-id', mox.stableIdXmlns),
//   mox.DoNotEncrypt('stanza-id', mox.stableIdXmlns),
// ];

/*class OmemoManager extends mox.XmppManagerBase {
  OmemoManager(
    this._getOmemoManager,
    this._shouldEncryptStanza, {
    required this.owner,
  }) : super(mox.omemoManager);

  final XmppService owner;

  /// Callback for getting the [omemo.OmemoManager].
  final mox.GetOmemoManagerCallback _getOmemoManager;

  /// Callback for checking whether a stanza should be encrypted or not.
  final mox.ShouldEncryptStanzaCallback _shouldEncryptStanza;

  // TODO(Unknown): Technically, this is not always true
  @override
  Future<bool> isSupported() async => true;

  @override
  List<mox.StanzaHandler> getIncomingPreStanzaHandlers() => [
        mox.StanzaHandler(
          stanzaTag: 'iq',
          tagXmlns: omemoXmlns,
          tagName: 'encrypted',
          callback: _onIncomingStanza,
        ),
        mox.StanzaHandler(
          stanzaTag: 'presence',
          tagXmlns: omemoXmlns,
          tagName: 'encrypted',
          callback: _onIncomingStanza,
        ),
        mox.StanzaHandler(
          stanzaTag: 'message',
          tagXmlns: omemoXmlns,
          tagName: 'encrypted',
          callback: _onIncomingStanza,
        ),
      ];

  @override
  List<mox.StanzaHandler> getOutgoingPreStanzaHandlers() => [
        mox.StanzaHandler(
          stanzaTag: 'iq',
          callback: _onOutgoingStanza,
        ),
        mox.StanzaHandler(
          stanzaTag: 'presence',
          callback: _onOutgoingStanza,
        ),
        mox.StanzaHandler(
          stanzaTag: 'message',
          callback: _onOutgoingStanza,
          priority: 100,
        ),
      ];

  @override
  Future<void> onXmppEvent(mox.XmppEvent event) async {
    if (event is mox.PubSubNotificationEvent) {
      if (event.item.node != omemoDevicesXmlns) return;

      logger.finest('Received PubSub device notification for ${event.from}');
      final ownJid = getAttributes().getFullJID().toBare().toString();
      final jid = mox.JID.fromString(event.from).toBare();
      final ids = event.item.payload.children
          .map((child) => int.parse(child.attributes['id']! as String))
          .toList();

      if (event.from == ownJid) {
        // Another client published to our device list node
        if (!ids.contains(await _getDeviceId())) {
          // Attempt to publish again
          unawaited(publishBundle(await _getDeviceBundle()));
        }
      } else {
        // Someone published to their device list node
        logger.finest('Got devices $ids');
      }

      // Tell the OmemoManager
      await (await _getOmemoManager()).onDeviceListUpdate(jid.toString(), ids);

      // Generate an event
      getAttributes().sendEvent(mox.OmemoDeviceListUpdatedEvent(jid, ids));
    }
  }

  /// Wrapper around using getSessionManager and then calling getDeviceId on it.
  Future<int> _getDeviceId() async => (await _getOmemoManager()).getDeviceId();

  /// Wrapper around using getSessionManager and then calling getDeviceId on it.
  Future<omemo.OmemoBundle> _getDeviceBundle() async {
    final device = await owner._device;
    return device.toBundle();
  }

  /// Determines what child elements of a stanza should be encrypted. If shouldEncrypt
  /// returns true for [element], then [element] will be encrypted. If shouldEncrypt
  /// returns false, then [element] won't be encrypted.
  ///
  /// The default implementation ignores all elements that are mentioned in XEP-0420, i.e.:
  /// - XEP-0033 elements (<addresses />)
  /// - XEP-0334 elements (<store/>, <no-copy/>, <no-store/>, <no-permanent-store/>)
  /// - XEP-0359 elements (<origin-id />, <stanza-id />)
  @visibleForOverriding
  bool shouldEncryptElement(mox.XMLNode element) {
    for (final ignore in _doNotEncryptList) {
      final xmlns = element.attributes['xmlns'] ?? '';
      if (element.tag == ignore.tag && xmlns == ignore.xmlns) {
        return false;
      }
    }

    return true;
  }

  /// Encrypt [children] using OMEMO. This either produces an <encrypted /> element with
  /// an attached payload, if [children] is not null, or an empty OMEMO message if
  /// [children] is null. This function takes care of creating the affix elements as
  /// specified by both XEP-0420 and XEP-0384.
  /// [toJid] is the list of JIDs the payload should be encrypted for.
  String _buildEnvelope(List<mox.XMLNode> children, String toJid) {
    final payload = mox.XMLNode.xmlns(
      tag: 'envelope',
      xmlns: mox.sceXmlns,
      children: [
        mox.XMLNode(
          tag: 'content',
          children: children,
        ),
        mox.XMLNode(
          tag: 'rpad',
          text: mox.generateRpad(),
        ),
        mox.XMLNode(
          tag: 'to',
          attributes: <String, String>{
            'jid': toJid,
          },
        ),
        mox.XMLNode(
          tag: 'from',
          attributes: <String, String>{
            'jid': getAttributes().getFullJID().toString(),
          },
        ),
        /*
        XMLNode(
          tag: 'time',
          // TODO(Unknown): Implement
          attributes: <String, String>{
            'stamp': '',
          },
        ),
        */
      ],
    );

    return payload.toXml();
  }

  mox.XMLNode _buildEncryptedElement(
    omemo.EncryptionResult result,
    String recipientJid,
    int deviceId,
  ) {
    final keyElements = <String, List<mox.XMLNode>>{};
    for (final keys in result.encryptedKeys.entries) {
      keyElements[keys.key] = keys.value
          .map(
            (ek) => mox.XMLNode(
              tag: 'key',
              attributes: {
                'rid': ek.rid.toString(),
                if (ek.kex) 'kex': 'true',
              },
              text: ek.value,
            ),
          )
          .toList();
    }

    final keysElements = keyElements.entries.map((entry) {
      return mox.XMLNode(
        tag: 'keys',
        attributes: {
          'jid': entry.key,
        },
        children: entry.value,
      );
    }).toList();

    return mox.XMLNode.xmlns(
      tag: 'encrypted',
      xmlns: omemoXmlns,
      children: [
        if (result.ciphertext != null)
          mox.XMLNode(
            tag: 'payload',
            text: base64Encode(result.ciphertext!),
          ),
        mox.XMLNode(
          tag: 'header',
          attributes: <String, String>{
            'sid': deviceId.toString(),
          },
          children: keysElements,
        ),
      ],
    );
  }

  /// For usage with omemo_dart's OmemoManager.
  Future<void> sendEmptyMessageImpl(
    omemo.EncryptionResult result,
    String toJid,
  ) async {
    await getAttributes().sendStanza(
      mox.StanzaDetails(
        mox.Stanza.message(
          to: toJid,
          type: 'chat',
          children: [
            _buildEncryptedElement(
              result,
              toJid,
              await _getDeviceId(),
            ),

            // Add a storage hint in case this is a message
            // Taken from the example at
            // https://xmpp.org/extensions/xep-0384.html#message-structure-description.
            mox.MessageProcessingHint.store.toXML(),
          ],
        ),
        awaitable: false,
        encrypted: true,
      ),
    );
  }

  /// Send a heartbeat message to [jid].
  Future<void> sendOmemoHeartbeat(String jid) async {
    final om = await _getOmemoManager();
    await om.sendOmemoHeartbeat(jid);
  }

  /// For usage with omemo_dart's OmemoManager
  Future<List<int>?> fetchDeviceList(String jid) async {
    final result = await getDeviceList(mox.JID.fromString(jid));
    if (result.isType<mox.OmemoError>()) return null;

    return result.get<List<int>>();
  }

  /// For usage with omemo_dart's OmemoManager
  Future<omemo.OmemoBundle?> fetchDeviceBundle(String jid, int id) async {
    final result = await retrieveDeviceBundle(mox.JID.fromString(jid), id);
    if (result.isType<mox.OmemoError>()) return null;

    return result.get<omemo.OmemoBundle>();
  }

  Future<mox.StanzaHandlerData> _onOutgoingStanza(
    mox.Stanza stanza,
    mox.StanzaHandlerData state,
  ) async {
    if (!state.shouldEncrypt) {
      logger.finest('Not encrypting since state.shouldEncrypt is false');
      return state;
    }

    if (state.encrypted) {
      logger.finest('Not encrypting since state.encrypted is true');
      return state;
    }

    if (stanza.to == null) {
      // We cannot encrypt in this case.
      logger.finest('Not encrypting since stanza.to is null');
      return state;
    }

    final toJid = mox.JID.fromString(stanza.to!).toBare();
    final shouldEncryptResult = await _shouldEncryptStanza(toJid, stanza);
    if (!shouldEncryptResult && !state.forceEncryption) {
      logger.finest(
        'Not encrypting stanza for $toJid: Both shouldEncryptStanza and forceEncryption are false.',
      );
      return state;
    } else {
      logger.finest(
        'Encrypting stanza for $toJid: shouldEncryptResult=$shouldEncryptResult, forceEncryption=${state.forceEncryption}',
      );
    }

    final toEncrypt = List<mox.XMLNode>.empty(growable: true);
    final children = List<mox.XMLNode>.empty(growable: true);
    for (final child in stanza.children) {
      if (!shouldEncryptElement(child)) {
        children.add(child);
      } else {
        toEncrypt.add(child);
      }
    }

    logger.finest('Beginning encryption');
    final carbonsEnabled = getAttributes()
            .getManagerById<mox.CarbonsManager>(mox.carbonsManager)
            ?.isEnabled ??
        false;
    final om = await _getOmemoManager();
    final encryptToJids = [
      toJid.toString(),
      if (carbonsEnabled) getAttributes().getFullJID().toBare().toString(),
    ];
    final result = await om.onOutgoingStanza(
      omemo.OmemoOutgoingStanza(
        encryptToJids,
        _buildEnvelope(toEncrypt, toJid.toString()),
      ),
    );
    logger.finest('Encryption done');

    if (!result.canSend) {
      return state
        ..cancel = true
        // If we have no device list for toJid, then the contact most likely does not
        // support OMEMO:2
        ..cancelReason = result.deviceEncryptionErrors[toJid.toString()]?.first
                .error is omemo.NoKeyMaterialAvailableError
            ? mox.OmemoNotSupportedForContactException()
            : mox.UnknownOmemoError()
        ..encryptionError = mox.OmemoEncryptionError(
          result.deviceEncryptionErrors,
        );
    }

    final encrypted = _buildEncryptedElement(
      result,
      toJid.toString(),
      await _getDeviceId(),
    );
    children.add(encrypted);

    // Only add message specific metadata when actually sending a message
    if (stanza.tag == 'message') {
      children
        // Add EME data
        ..add(mox.ExplicitEncryptionType.omemo2.toXML())
        // Add a storage hint in case this is a message
        // Taken from the example at
        // https://xmpp.org/extensions/xep-0384.html#message-structure-description.
        ..add(mox.MessageProcessingHint.store.toXML());
    }

    return state
      ..stanza = state.stanza.copyWith(children: children)
      ..encrypted = true;
  }

  Future<mox.StanzaHandlerData> _onIncomingStanza(
    mox.Stanza stanza,
    mox.StanzaHandlerData state,
  ) async {
    if (stanza.from == null) return state;

    final encrypted = stanza.firstTag('encrypted', xmlns: omemoXmlns)!;
    final fromJid = mox.JID.fromString(stanza.from!).toBare();
    final header = encrypted.firstTag('header')!;
    final ourJid = getAttributes().getFullJID();
    final ourJidString = ourJid.toBare().toString();
    final keys = List<omemo.EncryptedKey>.empty(growable: true);
    for (final keysElement in header.findTags('keys')) {
      // We only care about our own JID
      final jid = keysElement.attributes['jid']! as String;
      if (jid != ourJidString) {
        continue;
      }

      keys.addAll(
        keysElement.findTags('key').map(
              (key) => omemo.EncryptedKey(
                int.parse(key.attributes['rid']! as String),
                key.innerText(),
                key.attributes['kex'] == 'true',
              ),
            ),
      );
    }

    final sid = int.parse(header.attributes['sid']! as String);
    final om = await _getOmemoManager();
    final result = await om.onIncomingStanza(
      omemo.OmemoIncomingStanza(
        fromJid.toString(),
        sid,
        keys,
        encrypted.firstTag('payload')?.innerText(),
        false,
      ),
    );

    var children = stanza.children;
    if (result.error != null) {
      state.encryptionError = result.error;
    } else {
      children = stanza.children
          .where(
            (child) =>
                child.tag != 'encrypted' ||
                child.attributes['xmlns'] != omemoXmlns,
          )
          .toList();
    }

    logger.finest('Got payload: ${result.payload != null}');
    if (result.payload != null) {
      mox.XMLNode envelope;
      try {
        envelope = mox.XMLNode.fromString(result.payload!);
      } on Exception catch (_) {
        logger.warning('Failed to parse envelope payload: ${result.payload!}');
        return state
          ..encrypted = true
          ..encryptionError = mox.InvalidEnvelopePayloadException();
      }

      final envelopeChildren = envelope.firstTag('content')?.children;
      if (envelopeChildren != null) {
        children.addAll(
          // Do not add forbidden elements from the envelope
          envelopeChildren.where(shouldEncryptElement),
        );

        logger.finest('Adding children: ${envelopeChildren.map((c) => c.tag)}');
      } else {
        logger.warning('Invalid envelope element: No <content /> element');
      }

      if (!mox.checkAffixElements(envelope, stanza.from!, ourJid)) {
        state.encryptionError = mox.InvalidAffixElementsException();
      }
    }

    // Ignore heartbeat messages
    if (stanza.tag == 'message' && encrypted.firstTag('payload') == null) {
      logger.finest('Received empty OMEMO message. Ending processing early.');
      return state
        ..encrypted = true
        ..skip = true
        ..done = true;
    }

    return state
      ..encrypted = true
      ..stanza = mox.Stanza(
        to: stanza.to,
        from: stanza.from,
        id: stanza.id,
        type: stanza.type,
        children: children,
        tag: stanza.tag,
        attributes: Map<String, String>.from(stanza.attributes),
      )
      ..extensions.set<mox.OmemoData>(
        mox.OmemoData(
          result.newRatchets,
          result.replacedRatchets,
        ),
      );
  }

  /// Convenience function that attempts to retrieve the raw XML payload from the
  /// device list PubSub node.
  ///
  /// On success, returns the XML data. On failure, returns an OmemoError.
  Future<moxlib.Result<mox.OmemoError, mox.XMLNode>> _retrieveDeviceListPayload(
    mox.JID jid,
  ) async {
    final pm = owner._connection.getManager<PubSubManager>()!;
    final result = await pm.getItems(jid.toBare(), omemoDevicesXmlns);
    if (result.isType<mox.PubSubError>()) {
      return moxlib.Result(mox.UnknownOmemoError());
    }
    return moxlib.Result(result.get<List<mox.PubSubItem>>().first.payload);
  }

  /// Retrieves the OMEMO device list from [jid].
  Future<moxlib.Result<mox.OmemoError, List<int>>> getDeviceList(
      mox.JID jid) async {
    final itemsRaw = await _retrieveDeviceListPayload(jid);
    if (itemsRaw.isType<mox.OmemoError>()) {
      return moxlib.Result(mox.UnknownOmemoError());
    }

    final ids = itemsRaw
        .get<mox.XMLNode>()
        .children
        .map((child) => int.parse(child.attributes['id']! as String))
        .toList();
    return moxlib.Result(ids);
  }

  /// Retrieve all device bundles for the JID [jid].
  ///
  /// On success, returns a list of devices. On failure, returns am OmemoError.
  Future<moxlib.Result<mox.OmemoError, List<omemo.OmemoBundle>>>
      retrieveDeviceBundles(
    mox.JID jid,
  ) async {
    // TODO(Unknown): Should we query the device list first?
    // final pm =
    //     owner._connection.getManager<PubSubManager>()!;
    final devices = await getDeviceList(jid);
    if (devices.isType<mox.OmemoError>()) {
      return moxlib.Result(mox.UnknownOmemoError());
    }

    final bundles = await Future.wait(devices
        .get<List<int>>()
        .map((device) => retrieveDeviceBundle(jid, device)));

    if (bundles.any((e) => e.isType<mox.OmemoError>())) {
      return moxlib.Result(mox.UnknownOmemoError());
    }

    return moxlib.Result(
        bundles.map((e) => e.get<omemo.OmemoBundle>()).toList());
  }

  /// Retrieves a bundle from entity [jid] with the device id [deviceId].
  ///
  /// On success, returns the device bundle. On failure, returns an OmemoError.
  Future<moxlib.Result<mox.OmemoError, omemo.OmemoBundle>> retrieveDeviceBundle(
    mox.JID jid,
    int deviceId,
  ) async {
    final pm = owner._connection.getManager<PubSubManager>()!;
    final bareJid = jid.toBare();
    final item =
        await pm.getItem(bareJid, '$omemoBundlesXmlns:$deviceId', null);
    if (item.isType<mox.PubSubError>()) {
      return moxlib.Result(mox.UnknownOmemoError());
    }

    return moxlib.Result(
        bundleFromXML(jid, deviceId, item.get<mox.PubSubItem>().payload));
  }

  /// Attempts to publish a device bundle to the device list and device bundle PubSub
  /// nodes.
  ///
  /// On success, returns true. On failure, returns an OmemoError.
  Future<moxlib.Result<mox.OmemoError, bool>> publishBundle(
    omemo.OmemoBundle bundle,
  ) async {
    final attrs = getAttributes();
    final pm = attrs.getManagerById<mox.PubSubManager>(mox.pubsubManager)!;
    final bareJid = attrs.getFullJID().toBare();

    mox.XMLNode? deviceList;
    final deviceListRaw = await _retrieveDeviceListPayload(bareJid);
    if (!deviceListRaw.isType<mox.OmemoError>()) {
      deviceList = deviceListRaw.get<mox.XMLNode>();
    }

    deviceList ??= mox.XMLNode.xmlns(
      tag: 'list',
      xmlns: omemoXmlns,
    );

    final ids = deviceList.children
        .map((child) => int.parse(child.attributes['id']! as String));

    if (!ids.contains(bundle.id)) {
      // Only update the device list if the device Id is not there
      final newDeviceList = mox.XMLNode.xmlns(
        tag: 'list',
        xmlns: omemoXmlns,
        children: [
          ...deviceList.children,
          mox.XMLNode(
            tag: 'device',
            attributes: <String, String>{
              'id': '${bundle.id}',
            },
          ),
        ],
      );

      final deviceListPublish = await pm.publish(
        bareJid,
        omemoDevicesXmlns,
        newDeviceList,
        id: 'current',
        options: const mox.PubSubPublishOptions(
          accessModel: 'open',
        ),
      );
      if (deviceListPublish.isType<mox.PubSubError>()) {
        return const moxlib.Result(false);
      }
    }

    final deviceBundlePublish = await pm.publish(
      bareJid,
      '$omemoBundlesXmlns:${bundle.id}',
      bundleToXML(bundle),
      id: '${bundle.id}',
      options: const mox.PubSubPublishOptions(
        accessModel: 'open',
        maxItems: 'max',
      ),
    );

    return moxlib.Result(deviceBundlePublish.isType<mox.PubSubError>());
  }

  /// Subscribes to the device list PubSub node of [jid].
  Future<void> subscribeToDeviceListImpl(String jid) async {
    final pm = owner._connection.getManager<PubSubManager>()!;
    await pm.subscribe(mox.JID.fromString(jid), omemoDevicesXmlns);
  }

  /// Implementation for publishing our device [device].
  Future<void> publishDeviceImpl(omemo.OmemoDevice device) async {
    await publishBundle(await OmemoDevice.fromMox(device).toBundle());
  }

  /// Attempts to find out if [jid] supports omemo:2.
  ///
  /// On success, returns whether [jid] has published a device list and device bundles.
  /// On failure, returns an OmemoError.
  Future<moxlib.Result<mox.OmemoError, bool>> supportsOmemo(mox.JID jid) async {
    final dm =
        getAttributes().getManagerById<mox.DiscoManager>(mox.discoManager)!;
    final items = await dm.discoItemsQuery(jid.toBare());

    if (items.isType<mox.DiscoError>()) {
      return moxlib.Result(mox.UnknownOmemoError());
    }

    final nodes = items.get<List<mox.DiscoItem>>();
    final result = nodes.any((item) => item.node == omemoDevicesXmlns) &&
        nodes.any((item) => item.node == omemoBundlesXmlns);
    return moxlib.Result(result);
  }

  /// Attempts to delete a device with device id [deviceId] from the device bundles node
  /// and then the device list node. This allows a device that was accidentally removed
  /// to republish without any race conditions.
  /// Note that this does not delete a possibly existent ratchet session.
  ///
  /// On success, returns true. On failure, returns an OmemoError.
  Future<moxlib.Result<mox.OmemoError, bool>> deleteDevice(int deviceId) async {
    final pm = owner._connection.getManager<PubSubManager>()!;
    final jid = getAttributes().getFullJID().toBare();

    final bundleResult = await pm.retract(jid, omemoBundlesXmlns, '$deviceId');
    if (bundleResult.isType<mox.PubSubError>()) {
      // TODO(Unknown): Be more specific
      return moxlib.Result(mox.UnknownOmemoError());
    }

    final deviceListResult = await _retrieveDeviceListPayload(jid);
    if (deviceListResult.isType<mox.OmemoError>()) {
      return moxlib.Result(bundleResult.get<mox.OmemoError>());
    }

    final payload = deviceListResult.get<mox.XMLNode>();
    final newPayload = mox.XMLNode.xmlns(
      tag: 'devices',
      xmlns: omemoDevicesXmlns,
      children: payload.children
          .where((child) => child.attributes['id'] != '$deviceId')
          .toList(),
    );
    final publishResult = await pm.publish(
      jid,
      omemoDevicesXmlns,
      newPayload,
      id: 'current',
      options: const mox.PubSubPublishOptions(
        accessModel: 'open',
      ),
    );

    if (publishResult.isType<mox.PubSubError>()) {
      return moxlib.Result(mox.UnknownOmemoError());
    }

    return const moxlib.Result(true);
  }
}

const nsPreKeys = 'prekeys';
const nsSignedPreKeyPublic = 'signedPreKeyPublic';
const nsSignedPreKeyId = 'signedPreKeyId';
const nsSignedPreKeySignature = 'signedPreKeySignature';
const nsPreKeyPublic = 'preKeyPublic';
const nsPreKeyId = 'preKeyId';
const nsIdentityKey = 'identityKey';

omemo.OmemoBundle bundleFromXML(mox.JID jid, int id, mox.XMLNode bundle) {
  assert(bundle.attributes['xmlns'] == omemoXmlns, 'Invalid xmlns');

  final spk = bundle.firstTag(nsSignedPreKeyPublic)!;
  final prekeys = <int, String>{};
  for (final pk in bundle.firstTag(nsPreKeys)!.findTags(nsPreKeyPublic)) {
    prekeys[int.parse(pk.attributes[nsPreKeyId]! as String)] =
        pk.innerText().substring(4);
  }

  return omemo.OmemoBundle(
    jid.toBare().toString(),
    id,
    spk.innerText().substring(4),
    int.parse(spk.attributes[nsSignedPreKeyId]! as String),
    bundle.firstTag(nsSignedPreKeySignature)!.innerText(),
    bundle.firstTag(nsIdentityKey)!.innerText().substring(4),
    prekeys,
  );
}

/// Converts an OmemoBundle [bundle] into its XML representation.
///
/// Returns the XML element.
mox.XMLNode bundleToXML(omemo.OmemoBundle bundle) {
  final prekeys = List<mox.XMLNode>.empty(growable: true);
  for (final pk in bundle.opksEncoded.entries) {
    prekeys.add(
      mox.XMLNode(
        tag: nsPreKeyPublic,
        attributes: <String, String>{
          nsPreKeyId: '${pk.key}',
        },
        text: pk.value,
      ),
    );
  }

  return mox.XMLNode.xmlns(
    tag: 'bundle',
    xmlns: omemoXmlns,
    children: [
      mox.XMLNode(
        tag: nsSignedPreKeyPublic,
        attributes: <String, String>{
          nsSignedPreKeyId: '${bundle.spkId}',
        },
        text: bundle.spkEncoded,
      ),
      mox.XMLNode(
        tag: nsSignedPreKeySignature,
        text: bundle.spkSignatureEncoded,
      ),
      mox.XMLNode(
        tag: nsIdentityKey,
        text: bundle.ikEncoded,
      ),
      mox.XMLNode(
        tag: nsPreKeys,
        children: prekeys,
      ),
    ],
  );
}*/
