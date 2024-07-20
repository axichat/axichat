import 'dart:convert';

import 'package:drift/drift.dart' hide JsonKey;
import 'package:flutter/material.dart' hide Table, Column;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:uuid/uuid.dart';

import 'database.dart';

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
  noDecryptionKey,
  invalidHMAC,
  encryptionFailure,
  fileDecryptionFailure,
  fileEncryptionFailure,
  plaintextFileInOmemo;

  bool get isNotNone => this != none;
}

enum MessageWarning {
  none,
  fileIntegrityFailure,
  plaintextFileInOmemo;

  bool get isNotNone => this != none;
}

enum PseudoMessageType {
  newDevice,
  changedDevice,
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
    @Default(false) bool encrypted,
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
    required bool encrypted,
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
        encrypted: Value(encrypted),
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
  BoolColumn get encrypted => boolean().withDefault(const Constant(false))();
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
  TextColumn get sourceUrls => text().map(ListConverter()).nullable()();
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
  chat;

  bool get isUnavailable => this == unavailable;
  bool get isXa => this == xa;
  bool get isAway => this == away;
  bool get isDnd => this == dnd;
  bool get isChat => this == chat;

  static Presence fromString(String? value) => switch (value) {
        'unavailable' => unavailable,
        'xa' => xa,
        'away' => away,
        'dnd' => dnd,
        'chat' => chat,
        _ => chat,
      };

  Color get toColor => switch (this) {
        unavailable => Colors.grey,
        xa => Colors.red,
        away => Colors.orange,
        dnd => Colors.red,
        chat => const Color(0xff80ee80),
      };

  String get tooltip => switch (this) {
        unavailable => 'Offline',
        xa => 'Away',
        away => 'Idle',
        dnd => 'Busy',
        chat => 'Online',
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

  factory RosterItem.fromJid(mox.JID jid) => RosterItem(
        jid: jid.toString(),
        title: jid.local,
        presence: Presence.chat,
        subscription: Subscription.both,
      );

  static RosterItem fromMox({
    required mox.XmppRosterItem item,
    bool isGhost = false,
  }) {
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
  TextColumn get jid =>
      text().references(Chats, #jid, onDelete: KeyAction.cascade)();
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
  const factory Invite({
    required String jid,
    required String title,
  }) = _Invite;

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

enum ChatType {
  chat,
  groupChat,
  note,
}

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
    @Default(0) int unreadCount,
    @Default(false) bool open,
    @Default(false) bool muted,
    @Default(false) bool encrypted,
    @Default(false) bool favourited,
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
    required DateTime lastChangeTimestamp,
    required int unreadCount,
    required bool open,
    required bool muted,
    required bool encrypted,
    required bool favourited,
    required String? contactID,
    required String? contactDisplayName,
    required String? contactAvatarPath,
    required String? contactAvatarHash,
    required mox.ChatState? chatState,
  }) = _ChatFromDb;

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
        lastChangeTimestamp: Value(lastChangeTimestamp),
        unreadCount: Value(unreadCount),
        open: Value(open),
        muted: Value(muted),
        encrypted: Value(encrypted),
        favourited: Value(favourited),
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
  DateTimeColumn get lastChangeTimestamp => dateTime()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  BoolColumn get open => boolean().withDefault(const Constant(false))();
  BoolColumn get muted => boolean().withDefault(const Constant(false))();
  BoolColumn get encrypted => boolean().withDefault(const Constant(false))();
  BoolColumn get favourited => boolean().withDefault(const Constant(false))();
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
      (jsonDecode(fromDb) as Map<String, dynamic>)
          .map((k, v) => MapEntry(HashFunction.fromName(k), v as String));

  @override
  String toSql(Map<HashFunction, String> value) =>
      jsonEncode(value.map((k, v) => MapEntry(k.toName(), value)));
}

class ListConverter extends TypeConverter<List<String>, String> {
  @override
  List<String> fromSql(String fromDb) => jsonDecode(fromDb);

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
