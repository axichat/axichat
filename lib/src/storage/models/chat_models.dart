import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models/message_models.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:flutter/material.dart' hide Column, Table;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

part 'chat_models.freezed.dart';
part 'chat_models.g.dart';

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

  TextColumn get contactID => text().nullable()();

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

  TextColumn get contactID => text().nullable()();

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

@Freezed(toJson: false, fromJson: false)
class BlocklistData with _$BlocklistData implements Insertable<BlocklistData> {
  const factory BlocklistData({
    required String jid,
  }) = _BlocklistData;

  const BlocklistData._();

  @override
  Map<String, Expression<Object>> toColumns(bool nullToAbsent) =>
      BlocklistCompanion(
        jid: Value(jid),
      ).toColumns(nullToAbsent);
}

@UseRowClass(BlocklistData)
class Blocklist extends Table {
  TextColumn get jid => text()();

  @override
  Set<Column> get primaryKey => {jid};
}
