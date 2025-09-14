import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models/database_converters.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:omemo_dart/omemo_dart.dart' as omemo;
import 'package:uuid/uuid.dart';

part 'message_models.freezed.dart';

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

  bool get isNone => this == none;

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

typedef BTBVTrustState = omemo.BTBVTrustState;

class OmemoDeviceData {
  const OmemoDeviceData({required this.id});

  final int id;
}

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
      error.isNone &&
      fileMetadataID == null &&
      !isFileUploadNotification &&
      !fileUploading &&
      !fileDownloading;

  bool get isPseudoMessage =>
      pseudoMessageType != null && pseudoMessageData != null;

  mox.MessageEvent toMox() {
    final extensions = <mox.StanzaHandlerExtension>[
      mox.MessageBodyData(body),
      const mox.MarkableData(true),
      mox.MessageIdData(stanzaID),
      mox.ChatState.active,
    ];

    // Add OMEMO flag if encryption is requested
    if (encryptionProtocol == EncryptionProtocol.omemo) {
      // The OmemoManager will intercept based on _shouldEncryptStanza callback
      // But we should ensure the message is properly flagged
      extensions.add(mox.StableIdData(originID ?? stanzaID, null));
    }

    return mox.MessageEvent(
      mox.JID.fromString(senderJid),
      mox.JID.fromString(chatJid),
      false,
      mox.TypedMap<mox.StanzaHandlerExtension>.fromList(extensions),
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

  TextColumn get fileMetadataID => text().nullable()();

  TextColumn get quoting => text().nullable()();

  TextColumn get stickerPackID => text().nullable()();

  IntColumn get pseudoMessageType => intEnum<PseudoMessageType>().nullable()();

  TextColumn get pseudoMessageData =>
      text().nullable().map(const MapStringDynamicConverter())();

  @override
  Set<Column<Object>>? get primaryKey => {stanzaID};
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
