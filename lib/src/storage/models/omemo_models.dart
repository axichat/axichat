import 'dart:convert';
import 'dart:math';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models/database_converters.dart';
import 'package:axichat/src/storage/models/message_models.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:flutter/material.dart' hide Column, Table;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:omemo_dart/omemo_dart.dart' as omemo;
import 'package:shadcn_ui/shadcn_ui.dart';

part 'omemo_models.freezed.dart';

final keyPairTypes = <String, KeyPairType>{
  KeyPairType.ed25519.name: KeyPairType.ed25519,
  KeyPairType.x25519.name: KeyPairType.x25519,
};

/// Necessary to deal with the contagious asynchrony from mox.
mixin AsyncJsonSerializable {
  Future<Map<String, dynamic>> toMap();

  Future<String> toJson() async => jsonEncode(await toMap());
}

// const djbType = 5;

extension OmemoPublicKey on omemo.OmemoPublicKey {
  static omemo.OmemoPublicKey fromJson(String json) {
    final data = jsonDecode(json);
    return omemo.OmemoPublicKey.fromBytes(
      base64Decode(data['publicKey']),
      keyPairTypes[data['type']]!,
    );
  }

  // Future<List<int>> serialize() async => injectDjbType(await getBytes());

  Future<Map<String, String>> toMap() async {
    final publicKeyBase64 = await asBase64();
    return <String, String>{
      'publicKey': publicKeyBase64,
      'type': type.name,
    };
  }

  Future<String> toJson() async {
    final map = await toMap();
    return jsonEncode(map);
  }
}

// List<int> injectDjbType(List<int> bytes) => [djbType, ...bytes];

extension OmemoKeyPair on omemo.OmemoKeyPair {
  static omemo.OmemoKeyPair fromJson(String json) {
    final data = jsonDecode(json);
    return omemo.OmemoKeyPair.fromBytes(
      base64Decode(data['publicKey']),
      base64Decode(data['secretKey']),
      keyPairTypes[data['type']]!,
    );
  }

  static omemo.OmemoKeyPair fromMox(omemo.OmemoKeyPair keyPair) =>
      omemo.OmemoKeyPair(keyPair.pk, keyPair.sk, keyPair.type);

  Future<Map<String, dynamic>> toMap() async {
    // Parallel execution of cryptographic operations
    final results = await Future.wait([
      pk.getBytes(),
      sk.getBytes(),
    ]);

    return <String, String>{
      'publicKey': base64Encode(results[0]),
      'secretKey': base64Encode(results[1]),
      'type': type.name,
    };
  }

  Future<String> toJson() async {
    final map = await toMap();
    return jsonEncode(map);
  }
}

class SignedPreKey extends omemo.OmemoKeyPair implements AsyncJsonSerializable {
  SignedPreKey(super.pk, super.sk, super.type, {this.id, this.signature});

  final int? id;
  final List<int>? signature;

  factory SignedPreKey.fromJson(String json) {
    final data = jsonDecode(json);
    final keyPair = OmemoKeyPair.fromJson(json);
    return SignedPreKey(
      keyPair.pk,
      keyPair.sk,
      keyPair.type,
      id: data['id'],
      signature: List<int>.from(data['signature']),
    );
  }

  @override
  Future<Map<String, dynamic>> toMap() async {
    // Parallel execution of cryptographic operations
    final results = await Future.wait([
      pk.getBytes(),
      sk.getBytes(),
    ]);

    return <String, dynamic>{
      'publicKey': base64Encode(results[0]),
      'secretKey': base64Encode(results[1]),
      'type': type.name,
      'id': id,
      'signature': signature,
    };
  }

  @override
  Future<String> toJson() async {
    final map = await toMap();
    return jsonEncode(map);
  }
}

extension SkippedKey on omemo.SkippedKey {
  omemo.OmemoPublicKey get key => dh;

  int get skipped => n;

  static omemo.SkippedKey fromJson(String json) {
    final data = jsonDecode(json);
    return omemo.SkippedKey(
      OmemoPublicKey.fromJson(data['key']),
      data['skipped'],
    );
  }

  Future<Map<String, dynamic>> toMap() async {
    final keyJson = await key.toJson();
    return <String, dynamic>{
      'key': keyJson,
      'skipped': skipped,
    };
  }

  Future<String> toJson() async {
    final map = await toMap();
    return jsonEncode(map);
  }
}

// class BundleIdentityKey extends OmemoPublicKey {
//   BundleIdentityKey(SimplePublicKey publicKey)
//       : super(SimplePublicKey(
//           injectDjbType(publicKey.bytes),
//           type: publicKey.type,
//         ));
// }

extension KeyExchangeData on omemo.KeyExchangeData {
  omemo.OmemoPublicKey get identityKey => ik;

  omemo.OmemoPublicKey get ephemeralKey => ek;

  static omemo.KeyExchangeData fromJson(String json) {
    final data = jsonDecode(json);
    return omemo.KeyExchangeData(
      data['pkId'],
      data['spkId'],
      OmemoPublicKey.fromJson(data['identityKey']),
      OmemoPublicKey.fromJson(data['ephemeralKey']),
    );
  }

  Future<Map<String, dynamic>> toMap() async {
    // Parallel execution of key serialization
    final results = await Future.wait([
      identityKey.toJson(),
      ephemeralKey.toJson(),
    ]);

    return <String, dynamic>{
      'pkId': pkId,
      'spkId': spkId,
      'identityKey': results[0],
      'ephemeralKey': results[1],
    };
  }

  Future<String> toJson() async {
    final map = await toMap();
    return jsonEncode(map);
  }
}

// class OmemoBundle extends omemo.OmemoBundle {
//   OmemoBundle(
//     super.jid,
//     super.id,
//     super.spkEncoded,
//     super.spkId,
//     super.spkSignatureEncoded,
//     super.ikEncoded,
//     super.opksEncoded,
//   );
//
//   @override
//   BundleIdentityKey get ik {
//     final key = BundleIdentityKey(super.ik.asPublicKey());
//     print(
//         'KEY: ${key.asPublicKey().bytes} - ${key.asPublicKey().bytes.length}');
//     return key;
//   }
// }

// @Freezed(toJson: false, fromJson: false)

extension TrustDisplay on BTBVTrustState {
  bool get isNone => this == BTBVTrustState.notTrusted;

  bool get isBlind => this == BTBVTrustState.blindTrust;

  bool get isVerified => this == BTBVTrustState.verified;

  String get asString => switch (this) {
        omemo.BTBVTrustState.notTrusted => 'No trust',
        omemo.BTBVTrustState.blindTrust => 'Blind trust',
        omemo.BTBVTrustState.verified => 'Verified',
      };

  IconData get toIcon => switch (this) {
        omemo.BTBVTrustState.notTrusted => LucideIcons.shieldX,
        omemo.BTBVTrustState.blindTrust => LucideIcons.shieldQuestionMark,
        omemo.BTBVTrustState.verified => LucideIcons.shieldCheck,
      };

  Color get toColor => switch (this) {
        omemo.BTBVTrustState.notTrusted => Colors.red,
        omemo.BTBVTrustState.blindTrust => Colors.orange,
        omemo.BTBVTrustState.verified => axiGreen,
      };
}

class OmemoDevice extends omemo.OmemoDevice {
  OmemoDevice({
    required String jid,
    required int id,
    required this.identityKey,
    required this.signedPreKey,
    this.oldSignedPreKey,
    this.onetimePreKeys = const {},
    this.label,
  }) : super(
          jid,
          id,
          identityKey,
          signedPreKey,
          signedPreKey.id!,
          signedPreKey.signature!,
          oldSignedPreKey,
          oldSignedPreKey?.id,
          onetimePreKeys,
        );

  final omemo.OmemoKeyPair identityKey;
  final SignedPreKey signedPreKey;
  final SignedPreKey? oldSignedPreKey;
  final Map<int, omemo.OmemoKeyPair> onetimePreKeys;
  final String? label;

  factory OmemoDevice.fromDb({
    required String jid,
    required int id,
    required String identityKey,
    required String signedPreKey,
    required String? oldSignedPreKey,
    required String onetimePreKeys,
    required String? label,
  }) =>
      OmemoDevice(
        jid: jid,
        id: id,
        identityKey: OmemoKeyPair.fromJson(identityKey),
        signedPreKey: SignedPreKey.fromJson(signedPreKey),
        oldSignedPreKey: oldSignedPreKey != null
            ? SignedPreKey.fromJson(oldSignedPreKey)
            : null,
        onetimePreKeys: onetimePreKeysFromJson(onetimePreKeys),
        label: label,
      );

  factory OmemoDevice.fromMox(omemo.OmemoDevice device) => OmemoDevice(
        id: device.id,
        jid: device.jid,
        identityKey:
            omemo.OmemoKeyPair(device.ik.pk, device.ik.sk, device.ik.type),
        signedPreKey: SignedPreKey(
          device.spk.pk,
          device.spk.sk,
          device.spk.type,
          id: device.spkId,
          signature: device.spkSignature,
        ),
        oldSignedPreKey: device.oldSpk != null
            ? SignedPreKey(
                device.oldSpk!.pk,
                device.oldSpk!.sk,
                device.oldSpk!.type,
                id: device.oldSpkId,
              )
            : null,
        onetimePreKeys: <int, omemo.OmemoKeyPair>{
          for (final opk in device.opks.entries)
            opk.key: OmemoKeyPair.fromMox(opk.value),
        },
      );

  static int generateID() => Random.secure().nextInt(2147483647);

  // static Future<OmemoDevice> generateNewDevice(
  //   String jid, {
  //   int opkAmount = 100,
  // }) async {
  //   final id = generateID();
  //   final ik = await omemo.OmemoKeyPair.generateNewPair(KeyPairType.ed25519);
  //   final spk = await omemo.OmemoKeyPair.generateNewPair(KeyPairType.x25519);
  //   final spkId = generateID();
  //   final signature =
  //       await omemo.sig(ik, injectDjbType(await spk.pk.getBytes()));
  //
  //   final opks = <int, omemo.OmemoKeyPair>{};
  //   for (var i = 0; i < opkAmount; i++) {
  //     // Generate unique ids for each key
  //     while (true) {
  //       final opkId = generateID();
  //       if (opks.containsKey(opkId)) {
  //         continue;
  //       }
  //
  //       opks[opkId] =
  //           await omemo.OmemoKeyPair.generateNewPair(KeyPairType.x25519);
  //       break;
  //     }
  //   }
  //
  //   return OmemoDevice.fromMox(omemo.OmemoDevice(
  //       jid, id, ik, spk, spkId, signature, null, null, opks));
  // }
  //
  // @override
  // Future<OmemoDevice> replaceOnetimePrekey(int id) async {
  //   opks.remove(id);
  //
  //   // Generate a new unique id for the OPK.
  //   while (true) {
  //     final newId = generateID();
  //     if (opks.containsKey(newId)) {
  //       continue;
  //     }
  //
  //     opks[newId] =
  //         await omemo.OmemoKeyPair.generateNewPair(KeyPairType.x25519);
  //     break;
  //   }
  //
  //   return OmemoDevice.fromMox(omemo.OmemoDevice(
  //       jid, this.id, ik, spk, spkId, spkSignature, oldSpk, oldSpkId, opks));
  // }
  //
  // /// This replaces the Signed-Prekey with a completely new one. Returns a new Device object
  // /// that copies over everything but replaces the Signed-Prekey and its signature.
  // @override
  // Future<OmemoDevice> replaceSignedPrekey() async {
  //   final newSpk = await omemo.OmemoKeyPair.generateNewPair(KeyPairType.x25519);
  //   final newSpkId = generateID();
  //   final newSignature =
  //       await omemo.sig(ik, injectDjbType(await newSpk.pk.getBytes()));
  //
  //   return OmemoDevice.fromMox(omemo.OmemoDevice(
  //       jid, id, ik, newSpk, newSpkId, newSignature, spk, spkId, opks));
  // }
  //
  // /// Returns a new device that is equal to this one with the exception that the new
  // /// device's id is a new number between 0 and 2**32 - 1.
  // @override
  // OmemoDevice withNewId() {
  //   return OmemoDevice.fromMox(omemo.OmemoDevice(jid, generateID(), ik, spk,
  //       spkId, spkSignature, oldSpk, oldSpkId, opks));
  // }
  //

  Future<String> onetimePreKeysToJson() async {
    // Parallel execution of all one-time pre-key serializations
    final entries = onetimePreKeys.entries.toList();
    final serializedKeys = await Future.wait(
      entries.map((entry) => entry.value.toJson()),
    );

    final result = <String, String>{};
    for (int i = 0; i < entries.length; i++) {
      result[entries[i].key.toString()] = serializedKeys[i];
    }

    return jsonEncode(result);
  }

  static Map<int, omemo.OmemoKeyPair> onetimePreKeysFromJson(String json) {
    final data = Map<String, String>.from(jsonDecode(json));
    return <int, omemo.OmemoKeyPair>{
      for (final entry in data.entries)
        int.parse(entry.key): OmemoKeyPair.fromJson(entry.value),
    };
  }

  Future<Insertable<OmemoDevice>> toDb() async {
    // Parallel execution of all serialization operations
    final futures = <Future<String>>[];
    futures.add(identityKey.toJson());
    futures.add(signedPreKey.toJson());
    futures.add(onetimePreKeysToJson());

    // Handle optional oldSignedPreKey separately
    final oldSignedPreKeyFuture = oldSignedPreKey?.toJson();

    final results = await Future.wait(futures);
    final oldSignedPreKeyResult =
        oldSignedPreKeyFuture != null ? await oldSignedPreKeyFuture : null;

    return OmemoDevicesCompanion.insert(
      jid: jid,
      id: id,
      identityKey: results[0],
      // identityKey.toJson()
      signedPreKey: results[1],
      // signedPreKey.toJson()
      oldSignedPreKey: Value.absentIfNull(oldSignedPreKeyResult),
      onetimePreKeys: results[2],
      // onetimePreKeysToJson()
      label: Value(label),
    );
  }

// @override
// Future<OmemoBundle> toBundle() async {
//   final encodedOpks = <int, String>{};
//
//   for (final opkKey in opks.keys) {
//     encodedOpks[opkKey] =
//         base64.encode(injectDjbType(await opks[opkKey]!.pk.getBytes()));
//   }
//
//   return OmemoBundle(
//     jid,
//     id,
//     base64.encode(injectDjbType(await spk.pk.getBytes())),
//     spkId,
//     base64.encode(spkSignature),
//     base64.encode(injectDjbType(await ik.pk.getBytes())),
//     encodedOpks,
//   );
// }
}

@UseRowClass(OmemoDevice, constructor: 'fromDb')
class OmemoDevices extends Table {
  TextColumn get jid => text()();

  IntColumn get id => integer()();

  TextColumn get identityKey => text()();

  TextColumn get signedPreKey => text()();

  TextColumn get oldSignedPreKey => text().nullable()();

  TextColumn get onetimePreKeys => text()();

  TextColumn get label => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {jid, id};
}

class OmemoTrust extends omemo.BTBVTrustData implements Insertable<OmemoTrust> {
  const OmemoTrust({
    required String jid,
    required int device,
    BTBVTrustState trust = BTBVTrustState.blindTrust,
    bool enabled = true,
    bool trusted = true,
    this.label,
  }) : super(jid, device, trust, enabled, trusted);

  final String? label;

  factory OmemoTrust.fromDb({
    required String jid,
    required int device,
    required BTBVTrustState trust,
    required bool enabled,
    required bool trusted,
    required String? label,
  }) =>
      OmemoTrust(
        jid: jid,
        device: device,
        trust: trust,
        enabled: enabled,
        trusted: trusted,
        label: label,
      );

  factory OmemoTrust.fromMox(omemo.BTBVTrustData data) => OmemoTrust(
        device: data.device,
        jid: data.jid,
        trust: data.state,
        enabled: data.enabled,
        trusted: data.trusted,
      );

  @override
  Map<String, Expression<Object>> toColumns(bool nullToAbsent) =>
      OmemoTrustsCompanion(
        jid: Value(jid),
        device: Value(device),
        trust: Value(state),
        enabled: Value(enabled),
        trusted: Value(trusted),
        label: Value.absentIfNull(label),
      ).toColumns(nullToAbsent);
}

@UseRowClass(OmemoTrust, constructor: 'fromDb')
class OmemoTrusts extends Table {
  TextColumn get jid => text()();

  IntColumn get device => integer()();

  IntColumn get trust =>
      intEnum<BTBVTrustState>().withDefault(const Constant(1))();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  BoolColumn get trusted => boolean().withDefault(const Constant(false))();

  TextColumn get label => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {jid, device};
}

@Freezed(toJson: false, fromJson: false)
class OmemoDeviceList
    with _$OmemoDeviceList
    implements Insertable<OmemoDeviceList> {
  const factory OmemoDeviceList({
    required String jid,
    required List<int> devices,
  }) = _OmemoDeviceList;

  const OmemoDeviceList._();

  @override
  Map<String, Expression<Object>> toColumns(bool nullToAbsent) =>
      OmemoDeviceListsCompanion(
        jid: Value(jid),
        devices: Value(devices),
      ).toColumns(nullToAbsent);
}

@UseRowClass(OmemoDeviceList)
class OmemoDeviceLists extends Table {
  TextColumn get jid => text()();

  TextColumn get devices => text().map(ListConverter<int>())();

  @override
  Set<Column<Object>>? get primaryKey => {jid};
}

@Freezed(toJson: false, fromJson: false)
class OmemoFingerprint with _$OmemoFingerprint {
  const factory OmemoFingerprint({
    required String jid,
    required String fingerprint,
    required int deviceID,
    required BTBVTrustState trust,
    @Default(false) bool trusted,
    @Default(false) bool enabled,
    String? label,
  }) = _OmemoFingerprint;
}

/// OMEMO Double Ratchet implementation for forward-secure messaging.
///
/// This class implements the Signal Protocol's Double Ratchet algorithm,
/// providing forward secrecy and future secrecy for encrypted messages.
/// Each ratchet session is tied to a specific JID and device ID.
///
/// Key cryptographic components:
/// - [dhs]: Diffie-Hellman sending key pair
/// - [dhr]: Diffie-Hellman receiving public key (optional)
/// - [rk]: Root key for deriving chain keys
/// - [cks]: Sending chain key (optional)
/// - [ckr]: Receiving chain key (optional)
/// - [mkSkipped]: Map of skipped message keys for out-of-order messages
class OmemoRatchet extends omemo.OmemoDoubleRatchet
    implements omemo.OmemoRatchetData {
  OmemoRatchet({
    required this.jid,
    required this.device,
    required omemo.OmemoKeyPair dhs,
    omemo.OmemoPublicKey? dhr,
    required List<int> rk,
    List<int>? cks,
    List<int>? ckr,
    int ns = 0,
    int nr = 0,
    int pn = 0,
    required this.identityKey,
    this.associatedData = const [],
    Map<omemo.SkippedKey, List<int>> mkSkipped = const {},
    this.acked = false,
    required this.keyExchangeData,
  })  : _dhr = dhr,
        _mkSkipped = mkSkipped,
        super(
          dhs,
          dhr,
          rk,
          cks,
          ckr,
          ns,
          nr,
          pn,
          identityKey,
          associatedData,
          mkSkipped,
          acked,
          keyExchangeData,
        );

  @override
  final String jid;
  final int device;

  @override
  omemo.OmemoPublicKey? get dhr => _dhr;
  final omemo.OmemoPublicKey? _dhr;

  final omemo.OmemoPublicKey identityKey;
  final List<int> associatedData;

  @override
  Map<omemo.SkippedKey, List<int>> get mkSkipped => _mkSkipped;
  final Map<omemo.SkippedKey, List<int>> _mkSkipped;

  final bool acked;
  final omemo.KeyExchangeData keyExchangeData;

  @override
  int get id => device;

  @override
  omemo.OmemoDoubleRatchet get ratchet => this;

  factory OmemoRatchet.fromDb({
    required String jid,
    required int device,
    required String dhs,
    required String? dhr,
    required List<int> rk,
    required List<int>? cks,
    required List<int>? ckr,
    required int ns,
    required int nr,
    required int pn,
    required String identityKey,
    required List<int> associatedData,
    required String mkSkipped,
    required String keyExchangeData,
    required bool acked,
  }) =>
      OmemoRatchet(
        jid: jid,
        device: device,
        dhs: OmemoKeyPair.fromJson(dhs),
        dhr: dhr != null ? OmemoPublicKey.fromJson(dhr) : null,
        rk: rk,
        cks: cks,
        ckr: ckr,
        ns: ns,
        nr: nr,
        pn: pn,
        identityKey: OmemoPublicKey.fromJson(identityKey),
        associatedData: associatedData,
        mkSkipped: mkSkippedFromJson(mkSkipped),
        keyExchangeData: KeyExchangeData.fromJson(keyExchangeData),
        acked: acked,
      );

  factory OmemoRatchet.fromMox(omemo.OmemoRatchetData data) {
    final ratchet = data.ratchet;
    return OmemoRatchet(
      jid: data.jid,
      device: data.id,
      dhs: OmemoKeyPair.fromMox(ratchet.dhs),
      dhr: _convertPublicKey(ratchet.dhr),
      rk: ratchet.rk,
      cks: ratchet.cks,
      ckr: ratchet.ckr,
      ns: ratchet.ns,
      nr: ratchet.nr,
      pn: ratchet.pn,
      identityKey: omemo.OmemoPublicKey(ratchet.ik.asPublicKey()),
      associatedData: ratchet.sessionAd,
      mkSkipped: _convertSkippedKeys(ratchet.mkSkipped),
      keyExchangeData: _convertKeyExchangeData(ratchet.kex),
      acked: ratchet.acknowledged,
    );
  }

  /// Helper method to convert optional public key from Mox format
  static omemo.OmemoPublicKey? _convertPublicKey(dynamic publicKey) {
    return publicKey != null
        ? omemo.OmemoPublicKey(publicKey.asPublicKey())
        : null;
  }

  /// Helper method to convert skipped keys map from Mox format
  static Map<omemo.SkippedKey, List<int>> _convertSkippedKeys(
    Map<dynamic, List<int>> mkSkipped,
  ) {
    return <omemo.SkippedKey, List<int>>{
      for (final skipped in mkSkipped.entries)
        omemo.SkippedKey(
          omemo.OmemoPublicKey(skipped.key.dh.asPublicKey()),
          skipped.key.n,
        ): skipped.value,
    };
  }

  /// Helper method to convert key exchange data from Mox format
  static omemo.KeyExchangeData _convertKeyExchangeData(dynamic kex) {
    return omemo.KeyExchangeData(
      kex.pkId,
      kex.spkId,
      omemo.OmemoPublicKey(kex.ik.asPublicKey()),
      omemo.OmemoPublicKey(kex.ek.asPublicKey()),
    );
  }

  /// Serializes the map of skipped message keys to JSON.
  ///
  /// Skipped keys are used to decrypt out-of-order messages in the
  /// Double Ratchet protocol. This method efficiently serializes
  /// all skipped keys in parallel for better performance.
  Future<String> mkSkippedToJson() async {
    if (mkSkipped.isEmpty) {
      return jsonEncode(<String, List<int>>{});
    }

    // Parallel execution of all skipped key serializations
    final entries = mkSkipped.entries.toList();
    final serializedKeys = await Future.wait(
      entries.map((entry) => entry.key.toJson()),
    );

    final result = <String, List<int>>{};
    for (int i = 0; i < entries.length; i++) {
      result[serializedKeys[i]] = entries[i].value;
    }

    return jsonEncode(result);
  }

  static Map<omemo.SkippedKey, List<int>> mkSkippedFromJson(String json) {
    final data = Map<String, List<int>>.from(jsonDecode(json));
    return <omemo.SkippedKey, List<int>>{
      for (final entry in data.entries)
        SkippedKey.fromJson(entry.key): entry.value,
    };
  }

  /// Converts the ratchet to a database insertable format.
  ///
  /// This method efficiently serializes all cryptographic components
  /// in parallel to minimize the time spent on async operations.
  /// The ratchet state is persisted to enable session resumption.
  Future<Insertable<OmemoRatchet>> toDb() async {
    // Parallel execution of all serialization operations
    final futures = <Future<String>>[];
    futures.add(dhs.toJson());
    futures.add(identityKey.toJson());
    futures.add(mkSkippedToJson());
    futures.add(keyExchangeData.toJson());

    // Handle optional dhr separately
    final dhrFuture = dhr?.toJson();

    final results = await Future.wait(futures);
    final dhrResult = dhrFuture != null ? await dhrFuture : null;

    return OmemoRatchetsCompanion.insert(
      jid: jid,
      device: device,
      dhs: results[0],
      // dhs.toJson()
      dhr: Value.absentIfNull(dhrResult),
      rk: rk,
      cks: Value.absentIfNull(cks),
      ckr: Value.absentIfNull(ckr),
      ns: ns,
      nr: nr,
      pn: pn,
      identityKey: results[1],
      // identityKey.toJson()
      associatedData: associatedData,
      mkSkipped: results[2],
      // mkSkippedToJson()
      keyExchangeData: results[3],
      // keyExchangeData.toJson()
      acked: Value(acked),
    );
  }
}

@UseRowClass(OmemoRatchet, constructor: 'fromDb')
class OmemoRatchets extends Table {
  TextColumn get jid => text()();

  IntColumn get device => integer()();

  TextColumn get dhs => text()();

  TextColumn get dhr => text().nullable()();

  TextColumn get rk => text().map(ListConverter<int>())();

  TextColumn get cks => text().map(ListConverter<int>()).nullable()();

  TextColumn get ckr => text().map(ListConverter<int>()).nullable()();

  IntColumn get ns => integer()();

  IntColumn get nr => integer()();

  IntColumn get pn => integer()();

  TextColumn get identityKey => text()();

  TextColumn get associatedData => text().map(ListConverter<int>())();

  TextColumn get mkSkipped => text()();

  TextColumn get keyExchangeData => text()();

  BoolColumn get acked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>>? get primaryKey => {jid, device};
}
