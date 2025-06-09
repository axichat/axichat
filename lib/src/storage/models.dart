import 'dart:convert';
import 'dart:math';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:flutter/material.dart' hide Column, Table;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:omemo_dart/omemo_dart.dart' as omemo;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';

part 'models.freezed.dart';
part 'models.g.dart';

const uuid = Uuid();

// ENUMS WARNING: New values must only be added to the end of the list.
// If not, the database will break

enum MessageError {
  none,
  unknown,
  serviceUnavailable,
  serverNotFound,
  serverTimeout,
  invalidAffixElements,
  fileDownloadFailure,
  fileUploadFailure,
  omemoUnsupported,
  notEncryptedForDevice,
  malformedKey,
  malformedCiphertext,
  noDeviceSession,
  noKeyMaterial,
  noDecryptionKey,
  emptyDeviceList,
  invalidHMAC,
  invalidKEX,
  invalidEnvelope,
  encryptionFailure,
  skippingTooManyKeys,
  unknownSPK,
  unknownOmemoError,
  fileDecryptionFailure,
  fileEncryptionFailure,
  plaintextFileInOmemo;

  bool get isNotNone => this != none;

  String? get tooltip {
    if (this == serviceUnavailable) {
      return 'Recipient\'s client or server does not support this action.';
    }
    return null;
  }

  String get asString => switch (this) {
        serviceUnavailable =>
          'Recipient\'s client or server does not support this action',
        serverNotFound => 'Could not reach server',
        serverTimeout => 'Server timeout',
        notEncryptedForDevice => 'Message not encrypted for this device',
        malformedKey => 'Message has malformed encrypted key',
        unknownSPK => 'Message has unknown Signed Prekey',
        noDeviceSession => 'No session with this device',
        skippingTooManyKeys => 'Message would skip too many keys',
        invalidHMAC => 'Invalid HMAC',
        malformedCiphertext => 'Malformed ciphertext',
        noKeyMaterial => 'Can\'t find contact\'s devices',
        invalidKEX => 'Invalid Key Exchange Signature',
        unknownOmemoError => 'Unknown encryption error',
        invalidAffixElements => 'Invalid affix elements',
        emptyDeviceList => 'Contact has no devices to encrypt for',
        omemoUnsupported => 'Contact doesn\'t support encryption',
        encryptionFailure => 'Encryption failed',
        invalidEnvelope => 'Invalid contents',
        _ => toString(),
      };

  static MessageError fromOmemo(Object? error) => switch (error) {
        omemo.NotEncryptedForDeviceError _ => notEncryptedForDevice,
        omemo.MalformedEncryptedKeyError _ => malformedKey,
        omemo.UnknownSignedPrekeyError _ => unknownSPK,
        omemo.NoSessionWithDeviceError _ => noDeviceSession,
        omemo.SkippingTooManyKeysError _ => skippingTooManyKeys,
        omemo.InvalidMessageHMACError _ => invalidHMAC,
        omemo.MalformedCiphertextError _ => malformedCiphertext,
        omemo.NoKeyMaterialAvailableError _ => noKeyMaterial,
        omemo.InvalidKeyExchangeSignatureError _ => invalidKEX,
        mox.UnknownOmemoError _ => unknownOmemoError,
        mox.InvalidAffixElementsException _ => invalidAffixElements,
        mox.EmptyDeviceListException _ => emptyDeviceList,
        mox.OmemoNotSupportedForContactException _ => omemoUnsupported,
        mox.EncryptionFailedException _ => encryptionFailure,
        mox.InvalidEnvelopePayloadException _ => invalidEnvelope,
        _ => none,
      };
}

enum MessageWarning {
  none,
  fileIntegrityFailure,
  plaintextFileInOmemo;

  bool get isNotNone => this != none;
}

enum EncryptionProtocol {
  none,
  omemo,
  mls;

  bool get isNone => this == none;

  bool get isNotNone => this != none;

  bool get isOmemo => this == omemo;

  bool get isMls => this == mls;
}

enum PseudoMessageType { newDevice, changedDevice }

@Freezed(toJson: false, fromJson: false)
class Message with _$Message implements Insertable<Message> {
  const factory Message({
    required String stanzaID,
    required String senderJid,
    required String chatJid,
    DateTime? timestamp,
    String? id,
    String? originID,
    String? occupantID,
    String? body,
    @Default(MessageError.none) MessageError error,
    @Default(MessageWarning.none) MessageWarning warning,
    @Default(EncryptionProtocol.none) EncryptionProtocol encryptionProtocol,
    BTBVTrustState? trust,
    bool? trusted,
    int? deviceID,
    @Default(false) bool noStore,
    @Default(false) bool acked,
    @Default(false) bool received,
    @Default(false) bool displayed,
    @Default(false) bool edited,
    @Default(false) bool retracted,
    @Default(false) bool isFileUploadNotification,
    @Default(false) bool fileDownloading,
    @Default(false) bool fileUploading,
    String? fileMetadataID,
    String? quoting,
    String? stickerPackID,
    PseudoMessageType? pseudoMessageType,
    Map<String, dynamic>? pseudoMessageData,
    @Default(<String>[]) List<String> reactionsPreview,
  }) = _Message;

  const factory Message.fromDb({
    required String id,
    required String stanzaID,
    required String? originID,
    required String? occupantID,
    required String senderJid,
    required String chatJid,
    required String? body,
    required DateTime timestamp,
    required MessageError error,
    required MessageWarning warning,
    required EncryptionProtocol encryptionProtocol,
    required BTBVTrustState? trust,
    required bool? trusted,
    required int? deviceID,
    required bool noStore,
    required bool acked,
    required bool received,
    required bool displayed,
    required bool edited,
    required bool retracted,
    required bool isFileUploadNotification,
    required bool fileDownloading,
    required bool fileUploading,
    required String? fileMetadataID,
    required String? quoting,
    required String? stickerPackID,
    required PseudoMessageType? pseudoMessageType,
    required Map<String, dynamic>? pseudoMessageData,
    @Default(<String>[]) List<String> reactionsPreview,
  }) = _MessageFromDb;

  factory Message.fromMox(mox.MessageEvent event) {
    final get = event.extensions.get;
    final to = event.to.toBare().toString();
    final from = event.from.toBare().toString();
    final chatJid = event.isCarbon ? to : from;

    return Message(
      stanzaID: event.id ?? uuid.v4(),
      senderJid: from,
      chatJid: chatJid,
      body: event.text,
      timestamp: get<mox.DelayedDeliveryData>()?.timestamp,
      noStore: get<mox.MessageProcessingHintData>()?.hints.contains(
                mox.MessageProcessingHint.noStore,
              ) ??
          false,
      quoting: get<mox.ReplyData>()?.id,
      originID: get<mox.StableIdData>()?.originId,
      occupantID: get<mox.OccupantIdData>()?.id,
      encryptionProtocol:
          event.encrypted ? EncryptionProtocol.omemo : EncryptionProtocol.none,
      deviceID: get<OmemoDeviceData>()?.id,
      error: MessageError.fromOmemo(event.encryptionError),
    );
  }

  const Message._();

  bool authorized(mox.JID jid) =>
      mox.JID.fromString(senderJid).toBare() == jid.toBare();

  bool get editable =>
      error.isNotNone &&
      fileMetadataID == null &&
      !isFileUploadNotification &&
      !fileUploading &&
      !fileDownloading;

  bool get isPseudoMessage =>
      pseudoMessageType != null && pseudoMessageData != null;

  mox.MessageEvent toMox() {
    return mox.MessageEvent(
      mox.JID.fromString(senderJid),
      mox.JID.fromString(chatJid),
      false,
      mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
        mox.MessageBodyData(body),
        const mox.MarkableData(true),
        mox.MessageIdData(stanzaID),
        mox.ChatState.active,
      ]),
      id: stanzaID,
    );
  }

  @override
  Map<String, Expression<Object>> toColumns(bool nullToAbsent) =>
      MessagesCompanion(
        id: Value.absentIfNull(id),
        stanzaID: Value(stanzaID),
        originID: Value.absentIfNull(originID),
        occupantID: Value.absentIfNull(occupantID),
        senderJid: Value(senderJid),
        chatJid: Value(chatJid),
        body: Value.absentIfNull(body),
        timestamp: Value.absentIfNull(timestamp),
        error: Value(error),
        warning: Value(warning),
        encryptionProtocol: Value(encryptionProtocol),
        trust: Value.absentIfNull(trust),
        trusted: Value.absentIfNull(trusted),
        deviceID: Value.absentIfNull(deviceID),
        noStore: Value(noStore),
        acked: Value(acked),
        received: Value(received),
        displayed: Value(displayed),
        edited: Value(edited),
        retracted: Value(retracted),
        isFileUploadNotification: Value(isFileUploadNotification),
        fileDownloading: Value(fileDownloading),
        fileUploading: Value(fileUploading),
        fileMetadataID: Value(fileMetadataID),
        quoting: Value.absentIfNull(quoting),
        stickerPackID: Value.absentIfNull(stickerPackID),
        pseudoMessageType: Value.absentIfNull(pseudoMessageType),
        pseudoMessageData: Value.absentIfNull(pseudoMessageData),
      ).toColumns(nullToAbsent);
}

@UseRowClass(Message)
class Messages extends Table {
  TextColumn get id => text().clientDefault(() => uuid.v4())();

  TextColumn get stanzaID => text()();

  TextColumn get originID => text().nullable()();

  TextColumn get occupantID => text().nullable()();

  TextColumn get senderJid => text()();

  TextColumn get chatJid => text()();

  TextColumn get body => text().nullable()();

  DateTimeColumn get timestamp =>
      dateTime().clientDefault(() => DateTime.timestamp())();

  IntColumn get error =>
      intEnum<MessageError>().withDefault(const Constant(0))();

  IntColumn get warning =>
      intEnum<MessageWarning>().withDefault(const Constant(0))();

  IntColumn get encryptionProtocol =>
      intEnum<EncryptionProtocol>().withDefault(const Constant(0))();

  IntColumn get trust => intEnum<BTBVTrustState>().nullable()();

  BoolColumn get trusted => boolean().nullable()();

  IntColumn get deviceID => integer().nullable()();

  BoolColumn get noStore => boolean().withDefault(const Constant(false))();

  BoolColumn get acked => boolean().withDefault(const Constant(false))();

  BoolColumn get received => boolean().withDefault(const Constant(false))();

  BoolColumn get displayed => boolean().withDefault(const Constant(false))();

  BoolColumn get edited => boolean().withDefault(const Constant(false))();

  BoolColumn get retracted => boolean().withDefault(const Constant(false))();

  BoolColumn get isFileUploadNotification =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get fileDownloading =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get fileUploading =>
      boolean().withDefault(const Constant(false))();

  TextColumn get fileMetadataID =>
      text().nullable().references(FileMetadata, #id)();

  TextColumn get quoting => text().nullable()();

  TextColumn get stickerPackID =>
      text().nullable().references(StickerPacks, #id)();

  IntColumn get pseudoMessageType => intEnum<PseudoMessageType>().nullable()();

  TextColumn get pseudoMessageData => text().map(JsonConverter()).nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {stanzaID};
}

class Drafts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get jids => text().map(ListConverter<String>())();

  TextColumn get body => text().nullable()();

  TextColumn get fileMetadataID =>
      text().nullable().references(FileMetadata, #id)();
}

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

  Future<Map<String, String>> toMap() async => <String, String>{
        'publicKey': await asBase64(),
        'type': type.name,
      };

  Future<String> toJson() async => jsonEncode(await toMap());
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

  Future<Map<String, dynamic>> toMap() async => <String, String>{
        'publicKey': base64Encode(await pk.getBytes()),
        'secretKey': base64Encode(await sk.getBytes()),
        'type': type.name,
      };

  Future<String> toJson() async => jsonEncode(await toMap());
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
  Future<Map<String, dynamic>> toMap() async => <String, dynamic>{
        'publicKey': base64Encode(await pk.getBytes()),
        'secretKey': base64Encode(await sk.getBytes()),
        'type': type.name,
        'id': id,
        'signature': signature,
      };

  @override
  Future<String> toJson() async => jsonEncode(await toMap());
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

  Future<Map<String, dynamic>> toMap() async => <String, dynamic>{
        'key': await key.toJson(),
        'skipped': skipped,
      };

  Future<String> toJson() async => jsonEncode(await toMap());
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

  Future<Map<String, dynamic>> toMap() async => <String, dynamic>{
        'pkId': pkId,
        'spkId': spkId,
        'identityKey': await identityKey.toJson(),
        'ephemeralKey': await ephemeralKey.toJson(),
      };

  Future<String> toJson() async => jsonEncode(await toMap());
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

typedef BTBVTrustState = omemo.BTBVTrustState;

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
        omemo.BTBVTrustState.blindTrust => LucideIcons.shieldQuestion,
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
  Future<String> onetimePreKeysToJson() async => jsonEncode(<String, String>{
        for (final entry in onetimePreKeys.entries)
          entry.key.toString(): await entry.value.toJson(),
      });

  static Map<int, omemo.OmemoKeyPair> onetimePreKeysFromJson(String json) {
    final data = Map<String, String>.from(jsonDecode(json));
    return <int, omemo.OmemoKeyPair>{
      for (final entry in data.entries)
        int.parse(entry.key): OmemoKeyPair.fromJson(entry.value),
    };
  }

  Future<Insertable<OmemoDevice>> toDb() async => OmemoDevicesCompanion.insert(
        jid: jid,
        id: id,
        identityKey: await identityKey.toJson(),
        signedPreKey: await signedPreKey.toJson(),
        oldSignedPreKey: Value.absentIfNull(await oldSignedPreKey?.toJson()),
        onetimePreKeys: await onetimePreKeysToJson(),
        label: Value(label),
      );

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

// @Freezed(toJson: false, fromJson: false)
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
      dhr: ratchet.dhr != null
          ? omemo.OmemoPublicKey(ratchet.dhr!.asPublicKey())
          : null,
      rk: ratchet.rk,
      cks: ratchet.cks,
      ckr: ratchet.ckr,
      ns: ratchet.ns,
      nr: ratchet.nr,
      pn: ratchet.pn,
      identityKey: omemo.OmemoPublicKey(ratchet.ik.asPublicKey()),
      associatedData: ratchet.sessionAd,
      mkSkipped: <omemo.SkippedKey, List<int>>{
        for (final skipped in ratchet.mkSkipped.entries)
          omemo.SkippedKey(
            omemo.OmemoPublicKey(skipped.key.dh.asPublicKey()),
            skipped.key.n,
          ): skipped.value,
      },
      keyExchangeData: omemo.KeyExchangeData(
        ratchet.kex.pkId,
        ratchet.kex.spkId,
        omemo.OmemoPublicKey(ratchet.kex.ik.asPublicKey()),
        omemo.OmemoPublicKey(ratchet.kex.ek.asPublicKey()),
      ),
      acked: ratchet.acknowledged,
    );
  }

  Future<String> mkSkippedToJson() async => jsonEncode(<String, List<int>>{
        for (final entry in mkSkipped.entries)
          await entry.key.toJson(): entry.value,
      });

  static Map<omemo.SkippedKey, List<int>> mkSkippedFromJson(String json) {
    final data = Map<String, List<int>>.from(jsonDecode(json));
    return <omemo.SkippedKey, List<int>>{
      for (final entry in data.entries)
        SkippedKey.fromJson(entry.key): entry.value,
    };
  }

  Future<Insertable<OmemoRatchet>> toDb() async =>
      OmemoRatchetsCompanion.insert(
        jid: jid,
        device: device,
        dhs: await dhs.toJson(),
        dhr: Value.absentIfNull(await dhr?.toJson()),
        rk: rk,
        cks: Value.absentIfNull(cks),
        ckr: Value.absentIfNull(ckr),
        ns: ns,
        nr: nr,
        pn: pn,
        identityKey: await identityKey.toJson(),
        associatedData: associatedData,
        mkSkipped: await mkSkippedToJson(),
        keyExchangeData: await keyExchangeData.toJson(),
        acked: Value(acked),
      );
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

@Freezed(toJson: false, fromJson: false)
class Reaction with _$Reaction {
  const factory Reaction({
    required String messageID,
    required String senderJid,
    required String emoji,
  }) = _Reaction;
}

@UseRowClass(Reaction)
class Reactions extends Table {
  TextColumn get messageID => text().references(Messages, #id)();

  TextColumn get senderJid => text()();

  TextColumn get emoji => text()();

  @override
  Set<Column> get primaryKey => {messageID, senderJid, emoji};
}

@Freezed(toJson: false, fromJson: false)
class Notification with _$Notification {
  const factory Notification({
    required int id,
    required String? senderJid,
    required String chatJid,
    required String? senderName,
    required String body,
    required DateTime timestamp,
    required String? avatarPath,
    required String? mediaMimeType,
    required String? mediaPath,
  }) = _Notification;
}

@UseRowClass(Notification)
class Notifications extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get senderJid => text().nullable()();

  TextColumn get chatJid => text()();

  TextColumn get senderName => text().nullable()();

  TextColumn get body => text()();

  DateTimeColumn get timestamp => dateTime()();

  TextColumn get avatarPath => text().nullable()();

  TextColumn get mediaMimeType => text().nullable()();

  TextColumn get mediaPath => text().nullable()();
}

class FileMetadata extends Table {
  TextColumn get id => text().clientDefault(() => uuid.v4())();

  TextColumn get filename => text()();

  TextColumn get path => text().nullable()();

  TextColumn get sourceUrls => text().map(ListConverter<String>()).nullable()();

  TextColumn get mimeType => text().nullable()();

  IntColumn get sizeBytes => integer().nullable()();

  IntColumn get width => integer().nullable()();

  IntColumn get height => integer().nullable()();

  TextColumn get encryptionKey => text().nullable()();

  TextColumn get encryptionIV => text().nullable()();

  TextColumn get encryptionScheme => text().nullable()();

  TextColumn get cipherTextHashes => text().map(HashesConverter()).nullable()();

  TextColumn get plainTextHashes => text().map(HashesConverter()).nullable()();

  TextColumn get thumbnailType => text().nullable()();

  TextColumn get thumbnailData => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

enum Subscription {
  none,
  to,
  from,
  both;

  static Subscription fromString(String value) => switch (value) {
        'to' => to,
        'from' => from,
        'both' => both,
        _ => none,
      };

  bool get isNone => this == none;

  bool get isTo => this == to;

  bool get isFrom => this == from;

  bool get isBoth => this == both;
}

enum Ask {
  subscribe,
  subscribed;

  static Ask? fromString(String? value) => switch (value) {
        'subscribe' => subscribe,
        'subscribed' => subscribed,
        _ => null,
      };

  bool get isSubscribe => this == subscribe;

  bool get isSubscribed => this == subscribed;
}

@HiveType(typeId: 1)
enum Presence {
  @HiveField(0)
  unavailable,
  @HiveField(1)
  xa,
  @HiveField(2)
  away,
  @HiveField(3)
  dnd,
  @HiveField(4)
  chat,
  @HiveField(5)
  unknown;

  bool get isUnavailable => this == unavailable;

  bool get isXa => this == xa;

  bool get isAway => this == away;

  bool get isDnd => this == dnd;

  bool get isChat => this == chat;

  bool get isUnknown => this == unknown;

  static Presence fromString(String? value) => switch (value) {
        'unavailable' => unavailable,
        'xa' => xa,
        'away' => away,
        'dnd' => dnd,
        'chat' => chat,
        _ => unknown,
      };

  Color get toColor => switch (this) {
        unavailable => Colors.grey,
        xa => Colors.red,
        away => Colors.orange,
        dnd => Colors.red,
        chat => axiGreen,
        unknown => Colors.grey,
      };

  String get tooltip => switch (this) {
        unavailable => 'Offline',
        xa => 'Away',
        away => 'Idle',
        dnd => 'Busy',
        chat => 'Online',
        unknown => 'Unknown',
      };
}

@freezed
class RosterItem with _$RosterItem implements Insertable<RosterItem> {
  const factory RosterItem({
    required String jid,
    required String title,
    required Presence presence,
    required Subscription subscription,
    String? status,
    Ask? ask,
    String? avatarPath,
    String? avatarHash,
    String? contactID,
    String? contactAvatarPath,
    String? contactDisplayName,
    @Default(<String>[]) List<String> groups,
  }) = _RosterItem;

  const factory RosterItem.fromDb({
    required String jid,
    required String title,
    required Presence presence,
    required String? status,
    required String? avatarPath,
    required String? avatarHash,
    required Subscription subscription,
    required Ask? ask,
    required String? contactID,
    required String? contactAvatarPath,
    required String? contactDisplayName,
    @Default(<String>[]) List<String> groups,
  }) = _RosterItemFromDb;

  factory RosterItem.fromJson(Map<String, Object?> json) =>
      _$RosterItemFromJson(json);

  factory RosterItem.fromJid(String jid) => RosterItem(
        jid: jid.toString(),
        title: mox.JID.fromString(jid).local,
        presence: Presence.chat,
        subscription: Subscription.both,
      );

  factory RosterItem.fromMox(mox.XmppRosterItem item, {bool isGhost = false}) {
    final subscription = Subscription.fromString(item.subscription);
    return RosterItem(
      jid: item.jid,
      title: item.name ?? mox.JID.fromString(item.jid).local,
      presence: subscription.isNone || subscription.isFrom
          ? Presence.unavailable
          : Presence.chat,
      status: null,
      avatarPath: null,
      avatarHash: null,
      subscription: subscription,
      ask: Ask.fromString(item.ask),
      contactID: null,
      contactAvatarPath: null,
      contactDisplayName: null,
      groups: item.groups,
    );
  }

  const RosterItem._();

  mox.XmppRosterItem toMox() => mox.XmppRosterItem(
        jid: jid,
        subscription: subscription.name,
        ask: ask?.name,
        name: title,
      );

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) => RosterCompanion(
        jid: Value(jid),
        title: Value(title),
        presence: Value(presence),
        status: Value.absentIfNull(status),
        avatarPath: Value.absentIfNull(avatarPath),
        avatarHash: Value.absentIfNull(avatarHash),
        subscription: Value(subscription),
        ask: Value(ask),
        contactID: Value.absentIfNull(contactID),
        contactAvatarPath: Value.absentIfNull(contactAvatarPath),
        contactDisplayName: Value.absentIfNull(contactDisplayName),
      ).toColumns(nullToAbsent);
}

@UseRowClass(RosterItem, constructor: 'fromDb')
class Roster extends Table {
  TextColumn get jid => text()();

  TextColumn get title => text()();

  TextColumn get presence => textEnum<Presence>()();

  TextColumn get status => text().nullable()();

  TextColumn get avatarPath => text().nullable()();

  TextColumn get avatarHash => text().nullable()();

  TextColumn get subscription => textEnum<Subscription>()();

  TextColumn get ask => textEnum<Ask>().nullable()();

  TextColumn get contactID =>
      text().nullable().references(Contacts, #nativeID)();

  TextColumn get contactAvatarPath => text().nullable()();

  TextColumn get contactDisplayName => text().nullable()();

  @override
  Set<Column> get primaryKey => {jid};
}

@Freezed(toJson: false, fromJson: false)
class Invite with _$Invite implements Insertable<Invite> {
  const factory Invite({required String jid, required String title}) = _Invite;

  const Invite._();

  @override
  Map<String, Expression<Object>> toColumns(bool nullToAbsent) =>
      InvitesCompanion(
        jid: Value(jid),
        title: Value(title),
      ).toColumns(nullToAbsent);
}

@UseRowClass(Invite)
class Invites extends Table {
  TextColumn get jid => text()();

  TextColumn get title => text()();

  @override
  Set<Column<Object>>? get primaryKey => {jid};
}

enum ChatType { chat, groupChat, note }

@Freezed(toJson: false, fromJson: false)
class Chat with _$Chat implements Insertable<Chat> {
  const factory Chat({
    required String jid,
    required String title,
    required ChatType type,
    required DateTime lastChangeTimestamp,
    String? myNickname,
    String? avatarPath,
    String? avatarHash,
    String? lastMessage,
    String? alert,
    @Default(0) int unreadCount,
    @Default(false) bool open,
    @Default(false) bool muted,
    @Default(false) bool favorited,
    @Default(true) bool markerResponsive,
    @Default(EncryptionProtocol.omemo) EncryptionProtocol encryptionProtocol,
    String? contactID,
    String? contactDisplayName,
    String? contactAvatarPath,
    String? contactAvatarHash,
    mox.ChatState? chatState,
  }) = _Chat;

  const factory Chat.fromDb({
    required String jid,
    required String title,
    required ChatType type,
    required String? myNickname,
    required String? avatarPath,
    required String? avatarHash,
    required String? lastMessage,
    required String? alert,
    required DateTime lastChangeTimestamp,
    required int unreadCount,
    required bool open,
    required bool muted,
    required bool favorited,
    required bool markerResponsive,
    required EncryptionProtocol encryptionProtocol,
    required String? contactID,
    required String? contactDisplayName,
    required String? contactAvatarPath,
    required String? contactAvatarHash,
    required mox.ChatState? chatState,
  }) = _ChatFromDb;

  factory Chat.fromJid(String jid) => Chat(
        jid: jid,
        title: mox.JID.fromString(jid).local,
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
      );

  const Chat._();

  @override
  Map<String, Expression<Object>> toColumns(bool nullToAbsent) =>
      ChatsCompanion(
        jid: Value(jid),
        title: Value(title),
        type: Value(type),
        myNickname: Value.absentIfNull(myNickname),
        avatarPath: Value.absentIfNull(avatarPath),
        avatarHash: Value.absentIfNull(avatarHash),
        lastMessage: Value.absentIfNull(lastMessage),
        alert: Value(alert),
        lastChangeTimestamp: Value(lastChangeTimestamp),
        unreadCount: Value(unreadCount),
        open: Value(open),
        muted: Value(muted),
        favorited: Value(favorited),
        markerResponsive: Value(markerResponsive),
        encryptionProtocol: Value(encryptionProtocol),
        contactID: Value.absentIfNull(contactID),
        contactDisplayName: Value.absentIfNull(contactDisplayName),
        contactAvatarPath: Value.absentIfNull(contactAvatarPath),
        contactAvatarHash: Value.absentIfNull(contactAvatarHash),
        chatState: Value.absentIfNull(chatState),
      ).toColumns(nullToAbsent);
}

@UseRowClass(Chat, constructor: 'fromDb')
class Chats extends Table {
  TextColumn get jid => text()();

  TextColumn get title => text()();

  IntColumn get type => intEnum<ChatType>()();

  TextColumn get myNickname => text().nullable()();

  TextColumn get avatarPath => text().nullable()();

  TextColumn get avatarHash => text().nullable()();

  TextColumn get lastMessage => text().nullable()();

  TextColumn get alert => text().nullable()();

  DateTimeColumn get lastChangeTimestamp => dateTime()();

  IntColumn get unreadCount => integer().withDefault(const Constant(0))();

  BoolColumn get open => boolean().withDefault(const Constant(false))();

  BoolColumn get muted => boolean().withDefault(const Constant(false))();

  BoolColumn get favorited => boolean().withDefault(const Constant(false))();

  BoolColumn get markerResponsive =>
      boolean().withDefault(const Constant(true))();

  IntColumn get encryptionProtocol =>
      intEnum<EncryptionProtocol>().withDefault(const Constant(1))();

  TextColumn get contactID =>
      text().nullable().references(Contacts, #nativeID)();

  TextColumn get contactDisplayName => text().nullable()();

  TextColumn get contactAvatarPath => text().nullable()();

  TextColumn get contactAvatarHash => text().nullable()();

  TextColumn get chatState => textEnum<mox.ChatState>().nullable()();

  @override
  Set<Column> get primaryKey => {jid};
}

class Contacts extends Table {
  TextColumn get nativeID => text()();

  TextColumn get jid => text()();

  @override
  Set<Column> get primaryKey => {nativeID};
}

class Blocklist extends Table {
  TextColumn get jid => text()();

  @override
  Set<Column> get primaryKey => {jid};
}

@Freezed(toJson: false, fromJson: false)
class Sticker with _$Sticker {
  const factory Sticker({
    required String id,
    required String stickerPackID,
    required String fileMetadataID,
    required String description,
    required Map<String, String> suggestions,
  }) = _Sticker;
}

@UseRowClass(Sticker)
class Stickers extends Table {
  TextColumn get id => text()();

  TextColumn get stickerPackID => text().references(StickerPacks, #id)();

  TextColumn get fileMetadataID => text().references(FileMetadata, #id)();

  TextColumn get description => text()();

  TextColumn get suggestions => text().map(JsonConverter<String>())();

  @override
  Set<Column> get primaryKey => {id};
}

@Freezed(toJson: false, fromJson: false)
class StickerPack with _$StickerPack {
  const factory StickerPack({
    required String id,
    required String name,
    required String description,
    required String hashAlgorithm,
    required String hashValue,
    required bool restricted,
    required DateTime addedTimestamp,
    @Default(<Sticker>[]) List<Sticker> stickers,
    @Default(0) int sizeBytes,
    @Default(true) bool local,
  }) = _StickerPack;
}

@UseRowClass(StickerPack)
class StickerPacks extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get description => text()();

  TextColumn get hashAlgorithm => text()();

  TextColumn get hashValue => text()();

  BoolColumn get restricted => boolean()();

  DateTimeColumn get addedTimestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class JsonConverter<V> extends TypeConverter<Map<String, V>, String> {
  @override
  Map<String, V> fromSql(String fromDb) => jsonDecode(fromDb);

  @override
  String toSql(Map<String, V> value) => jsonEncode(value);
}

class HashesConverter extends TypeConverter<Map<HashFunction, String>, String> {
  @override
  Map<HashFunction, String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as Map<String, dynamic>).map(
        (k, v) => MapEntry(HashFunction.fromName(k), v as String),
      );

  @override
  String toSql(Map<HashFunction, String> value) =>
      jsonEncode(value.map((k, v) => MapEntry(k.toName(), value)));
}

class ListConverter<T> extends TypeConverter<List<T>, String> {
  @override
  List<T> fromSql(String fromDb) => List<T>.from(jsonDecode(fromDb));

  @override
  String toSql(List<T> value) => jsonEncode(value);
}
