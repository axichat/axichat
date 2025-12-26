import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models/message_models.dart';
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
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{
      'jid': Variable<String>(jid),
      'title': Variable<String>(title),
      'presence': Variable<String>(presence.name),
      'subscription': Variable<String>(subscription.name),
      'ask': Variable<String>(ask?.name),
    };
    if (status != null) {
      map['status'] = Variable<String>(status);
    }
    if (avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    if (avatarHash != null) {
      map['avatar_hash'] = Variable<String>(avatarHash);
    }
    if (contactID != null) {
      map['contact_i_d'] = Variable<String>(contactID);
    }
    if (contactAvatarPath != null) {
      map['contact_avatar_path'] = Variable<String>(contactAvatarPath);
    }
    if (contactDisplayName != null) {
      map['contact_display_name'] = Variable<String>(contactDisplayName);
    }
    return map;
  }
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
  Map<String, Expression> toColumns(bool nullToAbsent) => {
        'jid': Variable<String>(jid),
        'title': Variable<String>(title),
      };
}

@UseRowClass(Invite)
class Invites extends Table {
  TextColumn get jid => text()();

  TextColumn get title => text()();

  @override
  Set<Column<Object>>? get primaryKey => {jid};
}

const int attachmentAutoDownloadDefaultIndex = 0;

enum ChatType { chat, groupChat, note }

enum AttachmentAutoDownload {
  blocked,
  allowed;

  bool get isBlocked => this == blocked;

  bool get isAllowed => this == allowed;
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
    String? alert,
    @Default(0) int unreadCount,
    @Default(false) bool open,
    @Default(false) bool muted,
    @Default(false) bool favorited,
    @Default(false) bool archived,
    @Default(false) bool hidden,
    @Default(false) bool spam,
    @Default(true) bool markerResponsive,
    @Default(true) bool shareSignatureEnabled,
    @Default(AttachmentAutoDownload.blocked)
    AttachmentAutoDownload attachmentAutoDownload,
    @Default(EncryptionProtocol.none) EncryptionProtocol encryptionProtocol,
    String? contactID,
    String? contactDisplayName,
    String? contactAvatarPath,
    String? contactAvatarHash,
    String? contactJid,
    mox.ChatState? chatState,
    int? deltaChatId,
    String? emailAddress,
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
    required bool archived,
    required bool hidden,
    required bool spam,
    required bool markerResponsive,
    required bool shareSignatureEnabled,
    required AttachmentAutoDownload attachmentAutoDownload,
    required EncryptionProtocol encryptionProtocol,
    required String? contactID,
    required String? contactDisplayName,
    required String? contactAvatarPath,
    required String? contactAvatarHash,
    required String? contactJid,
    required mox.ChatState? chatState,
    required int? deltaChatId,
    required String? emailAddress,
  }) = _ChatFromDb;

  factory Chat.fromJid(String jid) => Chat(
        jid: jid,
        title: mox.JID.fromString(jid).local,
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        contactJid: jid,
      );

  const Chat._();

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{
      'jid': Variable<String>(jid),
      'title': Variable<String>(title),
      'type': Variable<int>(type.index),
      'alert': Variable<String>(alert),
      'last_change_timestamp': Variable<DateTime>(lastChangeTimestamp),
      'unread_count': Variable<int>(unreadCount),
      'open': Variable<bool>(open),
      'muted': Variable<bool>(muted),
      'favorited': Variable<bool>(favorited),
      'archived': Variable<bool>(archived),
      'hidden': Variable<bool>(hidden),
      'spam': Variable<bool>(spam),
      'marker_responsive': Variable<bool>(markerResponsive),
      'share_signature_enabled': Variable<bool>(shareSignatureEnabled),
      'attachment_auto_download': Variable<int>(attachmentAutoDownload.index),
      'encryption_protocol': Variable<int>(encryptionProtocol.index),
    };
    if (myNickname != null) {
      map['my_nickname'] = Variable<String>(myNickname);
    }
    if (avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    if (avatarHash != null) {
      map['avatar_hash'] = Variable<String>(avatarHash);
    }
    if (lastMessage != null) {
      map['last_message'] = Variable<String>(lastMessage);
    }
    if (contactID != null) {
      map['contact_i_d'] = Variable<String>(contactID);
    }
    if (contactDisplayName != null) {
      map['contact_display_name'] = Variable<String>(contactDisplayName);
    }
    if (contactAvatarPath != null) {
      map['contact_avatar_path'] = Variable<String>(contactAvatarPath);
    }
    if (contactAvatarHash != null) {
      map['contact_avatar_hash'] = Variable<String>(contactAvatarHash);
    }
    if (contactJid != null) {
      map['contact_jid'] = Variable<String>(contactJid);
    }
    if (chatState != null) {
      map['chat_state'] = Variable<String>(chatState!.name);
    }
    if (deltaChatId != null) {
      map['delta_chat_id'] = Variable<int>(deltaChatId);
    }
    if (emailAddress != null) {
      map['email_address'] = Variable<String>(emailAddress);
    }
    return map;
  }
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

  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  BoolColumn get spam => boolean().withDefault(const Constant(false))();

  BoolColumn get markerResponsive =>
      boolean().withDefault(const Constant(true))();

  BoolColumn get shareSignatureEnabled =>
      boolean().withDefault(const Constant(true))();

  IntColumn get attachmentAutoDownload => intEnum<AttachmentAutoDownload>()
      .withDefault(const Constant(attachmentAutoDownloadDefaultIndex))();

  IntColumn get encryptionProtocol =>
      intEnum<EncryptionProtocol>().withDefault(const Constant(1))();

  TextColumn get contactID => text().nullable()();

  TextColumn get contactDisplayName => text().nullable()();

  TextColumn get contactAvatarPath => text().nullable()();

  TextColumn get contactAvatarHash => text().nullable()();

  TextColumn get contactJid => text().nullable()();

  TextColumn get chatState => textEnum<mox.ChatState>().nullable()();

  IntColumn get deltaChatId => integer().nullable()();

  TextColumn get emailAddress => text().nullable()();

  @override
  Set<Column> get primaryKey => {jid};
}

class Contacts extends Table {
  TextColumn get nativeID => text()();

  TextColumn get jid => text()();

  @override
  Set<Column> get primaryKey => {nativeID};
}

extension ChatThreadExtension on Chat {
  String get remoteJid => contactJid ?? jid;

  bool get hasDetachedThread => contactJid != null && contactJid != jid;
}

extension ChatTransportExtension on Chat {
  static final _axiDomainPattern = RegExp(r'@axi\.im$', caseSensitive: false);

  bool get supportsEmail => isEmailOnlyContact;

  bool get isAxiContact {
    final remote = remoteJid.toLowerCase();
    if (!remote.contains('@')) {
      return false;
    }
    return _axiDomainPattern.hasMatch(remote);
  }

  bool get isEmailOnlyContact {
    if (type != ChatType.chat) {
      return false;
    }
    final remote = remoteJid.toLowerCase();
    if (!remote.contains('@')) {
      return false;
    }
    return !_axiDomainPattern.hasMatch(remote);
  }

  MessageTransport get defaultTransport {
    if (type != ChatType.chat) {
      return MessageTransport.xmpp;
    }
    return isEmailOnlyContact ? MessageTransport.email : MessageTransport.xmpp;
  }

  MessageTransport get transport => defaultTransport;
}

extension ChatAvatarExtension on Chat {
  String get avatarIdentifier {
    final displayName = contactDisplayName?.trim();
    if (displayName?.isNotEmpty == true) {
      return displayName!;
    }
    final titleText = title.trim();
    if (titleText.isNotEmpty) {
      return titleText;
    }
    final address = emailAddress?.trim();
    if (address?.isNotEmpty == true) {
      return address!;
    }
    final contact = contactJid?.trim();
    if (contact?.isNotEmpty == true) {
      return contact!;
    }
    return remoteJid;
  }
}

extension ChatLabelExtension on Chat {
  String get displayName {
    final display = contactDisplayName?.trim();
    if (display?.isNotEmpty == true) {
      return display!;
    }
    final titleText = title.trim();
    if (titleText.isNotEmpty) {
      return titleText;
    }
    final address = emailAddress?.trim();
    if (address?.isNotEmpty == true) {
      return address!;
    }
    final contact = contactJid?.trim();
    if (contact?.isNotEmpty == true) {
      return contact!;
    }
    return remoteJid;
  }
}

@Freezed(toJson: false, fromJson: false)
class BlocklistData with _$BlocklistData implements Insertable<BlocklistData> {
  const factory BlocklistData({
    required String jid,
  }) = _BlocklistData;

  const BlocklistData._();

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) =>
      {'jid': Variable<String>(jid)};
}

@UseRowClass(BlocklistData)
class Blocklist extends Table {
  TextColumn get jid => text()();

  @override
  Set<Column> get primaryKey => {jid};
}

@Freezed(toJson: false, fromJson: false)
class EmailBlocklistEntry
    with _$EmailBlocklistEntry
    implements Insertable<EmailBlocklistEntry> {
  const factory EmailBlocklistEntry({
    required String address,
    required DateTime blockedAt,
    @Default(0) int blockedMessageCount,
    DateTime? lastBlockedMessageAt,
  }) = _EmailBlocklistEntry;

  const EmailBlocklistEntry._();

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{
      'address': Variable<String>(address),
      'blocked_at': Variable<DateTime>(blockedAt),
      'blocked_message_count': Variable<int>(blockedMessageCount),
    };
    if (lastBlockedMessageAt != null) {
      map['last_blocked_message_at'] = Variable<DateTime>(lastBlockedMessageAt);
    }
    return map;
  }
}

@UseRowClass(EmailBlocklistEntry)
class EmailBlocklist extends Table {
  TextColumn get address => text()();

  DateTimeColumn get blockedAt =>
      dateTime().clientDefault(() => DateTime.timestamp())();

  IntColumn get blockedMessageCount =>
      integer().withDefault(const Constant(0))();

  DateTimeColumn get lastBlockedMessageAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {address};
}

@Freezed(toJson: false, fromJson: false)
class EmailSpamEntry
    with _$EmailSpamEntry
    implements Insertable<EmailSpamEntry> {
  const factory EmailSpamEntry({
    required String address,
    required DateTime flaggedAt,
  }) = _EmailSpamEntry;

  const EmailSpamEntry._();

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) => {
        'address': Variable<String>(address),
        'flagged_at': Variable<DateTime>(flaggedAt),
      };
}

@UseRowClass(EmailSpamEntry)
class EmailSpamlist extends Table {
  TextColumn get address => text()();

  DateTimeColumn get flaggedAt =>
      dateTime().clientDefault(() => DateTime.timestamp())();

  @override
  Set<Column> get primaryKey => {address};
}
