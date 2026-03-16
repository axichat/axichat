// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/storage/models/message_models.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';
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
}

@Freezed(toJson: false, fromJson: false)
abstract class RosterItem with _$RosterItem implements Insertable<RosterItem> {
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

  factory RosterItem.fromJid(String jid) => RosterItem(
    jid: jid.toString(),
    title: addressDisplayLabel(jid) ?? mox.JID.fromString(jid).local,
    presence: Presence.chat,
    subscription: Subscription.both,
  );

  factory RosterItem.fromMox(mox.XmppRosterItem item, {bool isGhost = false}) {
    final subscription = Subscription.fromString(item.subscription);
    return RosterItem(
      jid: item.jid,
      title:
          item.name ??
          addressDisplayLabel(item.jid) ??
          mox.JID.fromString(item.jid).local,
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
abstract class Invite with _$Invite implements Insertable<Invite> {
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

enum ChatType { chat, groupChat, note }

enum ChatPrimaryView {
  chat,
  calendar;

  bool get isChat => this == chat;

  bool get isCalendar => this == calendar;

  String get wireValue => name;

  static ChatPrimaryView? tryParse(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    for (final candidate in values) {
      if (candidate.wireValue == normalized) {
        return candidate;
      }
    }
    return null;
  }
}

enum AttachmentAutoDownload {
  blocked,
  allowed;

  bool get isBlocked => this == blocked;

  bool get isAllowed => this == allowed;
}

enum NotificationPreviewSetting {
  show,
  hide;

  bool get isShown => this == show;

  bool get isHidden => this == hide;

  String label({required String showLabel, required String hideLabel}) =>
      isShown ? showLabel : hideLabel;

  bool resolvePreview(bool globalSetting) => isShown ? true : false;

  static bool resolveOverride(
    NotificationPreviewSetting? setting,
    bool globalSetting,
  ) {
    if (setting == null) return globalSetting;
    return setting.resolvePreview(globalSetting);
  }
}

@Freezed(toJson: false, fromJson: false)
abstract class Chat with _$Chat implements Insertable<Chat> {
  const factory Chat({
    required String jid,
    required String title,
    required ChatType type,
    @Default(ChatPrimaryView.chat) ChatPrimaryView primaryView,
    required DateTime lastChangeTimestamp,
    @Default(MessageTransport.xmpp) MessageTransport transport,
    String? myNickname,
    String? avatarPath,
    String? avatarHash,
    String? lastMessage,
    String? alert,
    @Default(0) int unreadCount,
    @Default(false) bool open,
    @Default(false) bool muted,
    NotificationPreviewSetting? notificationPreviewSetting,
    @Default(false) bool favorited,
    @Default(false) bool archived,
    @Default(false) bool hidden,
    @Default(false) bool spam,
    DateTime? spamUpdatedAt,
    bool? markerResponsive,
    bool? shareSignatureEnabled,
    AttachmentAutoDownload? attachmentAutoDownload,
    @Default(EncryptionProtocol.none) EncryptionProtocol encryptionProtocol,
    String? contactID,
    String? contactDisplayName,
    String? contactAvatarPath,
    String? contactAvatarHash,
    String? contactJid,
    mox.ChatState? chatState,
    int? deltaChatId,
    String? emailAddress,
    String? emailFromAddress,
  }) = _Chat;

  const factory Chat.fromDb({
    required String jid,
    required String title,
    required ChatType type,
    required ChatPrimaryView primaryView,
    required String? myNickname,
    required String? avatarPath,
    required String? avatarHash,
    required String? lastMessage,
    required String? alert,
    required DateTime lastChangeTimestamp,
    required MessageTransport transport,
    required int unreadCount,
    required bool open,
    required bool muted,
    required NotificationPreviewSetting? notificationPreviewSetting,
    required bool favorited,
    required bool archived,
    required bool hidden,
    required bool spam,
    required DateTime? spamUpdatedAt,
    required bool? markerResponsive,
    required bool? shareSignatureEnabled,
    required AttachmentAutoDownload? attachmentAutoDownload,
    required EncryptionProtocol encryptionProtocol,
    required String? contactID,
    required String? contactDisplayName,
    required String? contactAvatarPath,
    required String? contactAvatarHash,
    required String? contactJid,
    required mox.ChatState? chatState,
    required int? deltaChatId,
    required String? emailAddress,
    required String? emailFromAddress,
  }) = _ChatFromDb;

  factory Chat.fromJid(String jid) => Chat(
    jid: jid,
    title: addressDisplayLabel(jid) ?? mox.JID.fromString(jid).local,
    type: ChatType.chat,
    lastChangeTimestamp: DateTime.now(),
    transport: MessageTransport.xmpp,
    contactJid: jid,
  );

  const Chat._();

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{
      'jid': Variable<String>(jid),
      'title': Variable<String>(title),
      'type': Variable<int>(type.index),
      'primary_view': Variable<int>(primaryView.index),
      'alert': Variable<String>(alert),
      'last_change_timestamp': Variable<DateTime>(lastChangeTimestamp),
      'transport': Variable<int>(transport.index),
      'unread_count': Variable<int>(unreadCount),
      'open': Variable<bool>(open),
      'muted': Variable<bool>(muted),
      'favorited': Variable<bool>(favorited),
      'archived': Variable<bool>(archived),
      'hidden': Variable<bool>(hidden),
      'spam': Variable<bool>(spam),
      if (notificationPreviewSetting != null)
        'notification_preview_setting': Variable<int>(
          notificationPreviewSetting!.index,
        ),
      if (markerResponsive != null)
        'marker_responsive': Variable<bool>(markerResponsive!),
      if (shareSignatureEnabled != null)
        'share_signature_enabled': Variable<bool>(shareSignatureEnabled!),
      if (attachmentAutoDownload != null)
        'attachment_auto_download': Variable<int>(
          attachmentAutoDownload!.index,
        ),
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
    if (emailFromAddress != null) {
      map['email_from_address'] = Variable<String>(emailFromAddress);
    }
    if (spamUpdatedAt != null) {
      map['spam_updated_at'] = Variable<DateTime>(spamUpdatedAt!);
    }
    return map;
  }
}

@UseRowClass(Chat, constructor: 'fromDb')
class Chats extends Table {
  TextColumn get jid => text()();

  TextColumn get title => text()();

  IntColumn get type => intEnum<ChatType>()();

  IntColumn get primaryView => intEnum<ChatPrimaryView>().withDefault(
    Constant(ChatPrimaryView.chat.index),
  )();

  IntColumn get transport => intEnum<MessageTransport>().withDefault(
    Constant(MessageTransport.xmpp.index),
  )();

  TextColumn get myNickname => text().nullable()();

  TextColumn get avatarPath => text().nullable()();

  TextColumn get avatarHash => text().nullable()();

  TextColumn get lastMessage => text().nullable()();

  TextColumn get alert => text().nullable()();

  DateTimeColumn get lastChangeTimestamp => dateTime()();

  IntColumn get unreadCount => integer().withDefault(const Constant(0))();

  BoolColumn get open => boolean().withDefault(const Constant(false))();

  BoolColumn get muted => boolean().withDefault(const Constant(false))();

  IntColumn get notificationPreviewSetting =>
      intEnum<NotificationPreviewSetting>().nullable()();

  BoolColumn get favorited => boolean().withDefault(const Constant(false))();

  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  BoolColumn get spam => boolean().withDefault(const Constant(false))();

  DateTimeColumn get spamUpdatedAt => dateTime().nullable()();

  BoolColumn get markerResponsive => boolean().nullable()();

  BoolColumn get shareSignatureEnabled => boolean().nullable()();

  IntColumn get attachmentAutoDownload =>
      intEnum<AttachmentAutoDownload>().nullable()();

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

  TextColumn get emailFromAddress => text().nullable()();

  @override
  Set<Column> get primaryKey => {jid};

  List<Index> get indexes => [
    Index('idx_chats_last_change', 'last_change_timestamp'),
  ];
}

@DataClassName('RecipientAddress')
class RecipientAddresses extends Table {
  TextColumn get address => text()();

  DateTimeColumn get lastSeen => dateTime()();

  @override
  Set<Column> get primaryKey => {address};

  List<Index> get indexes => [
    Index('idx_recipient_addresses_last_seen', 'last_seen'),
  ];
}

@DataClassName('EmailChatAccountData')
class EmailChatAccounts extends Table {
  TextColumn get chatJid => text().references(Chats, #jid)();

  IntColumn get deltaAccountId =>
      integer().withDefault(const Constant(DeltaAccountDefaults.legacyId))();

  IntColumn get deltaChatId => integer()();

  @override
  Set<Column> get primaryKey => {chatJid, deltaAccountId};

  @override
  List<String> get customConstraints => const [
    'UNIQUE(delta_account_id, delta_chat_id)',
  ];
}

class Contact extends Equatable implements Insertable<Contact> {
  const Contact._({
    this.nativeID,
    required this.chat,
    required this.address,
    required this.providedDisplayName,
    required this.shareSignatureEnabled,
    required this.transport,
  });

  factory Contact.fromDb({required String nativeID, required String jid}) =>
      Contact._(
        nativeID: nativeID,
        chat: null,
        address: jid,
        providedDisplayName: null,
        shareSignatureEnabled: false,
        transport: null,
      );

  factory Contact.chat({
    required Chat chat,
    required bool shareSignatureEnabled,
  }) => Contact._(
    chat: chat,
    address: chat.emailAddress,
    providedDisplayName: chat.contactDisplayName,
    shareSignatureEnabled: shareSignatureEnabled,
    transport: chat.defaultTransport,
  );

  factory Contact.address({
    String? nativeID,
    required String address,
    String? displayName,
    bool shareSignatureEnabled = false,
    MessageTransport? transport,
  }) {
    final trimmed = address.trim();
    final resolvedDisplayName = displayName?.trim();
    return Contact._(
      nativeID: nativeID,
      chat: null,
      address: trimmed,
      providedDisplayName: resolvedDisplayName?.isNotEmpty == true
          ? resolvedDisplayName
          : null,
      shareSignatureEnabled: shareSignatureEnabled,
      transport: transport,
    );
  }

  final String? nativeID;
  final Chat? chat;
  final String? address;
  final String? providedDisplayName;
  final bool shareSignatureEnabled;
  final MessageTransport? transport;

  bool get hasBackingChat => chat != null;

  String? get chatJid {
    final value = chat?.jid.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String get key => chat?.jid ?? normalizedAddress ?? address!;

  MessageTransport? get configuredTransport =>
      transport ?? chat?.defaultTransport;

  MessageTransport? get hintedTransport => hintTransportForAddress(address);

  bool get isEmailBacked => chat?.isEmailBacked ?? false;

  bool get supportsEmail {
    final targetChat = chat;
    if (targetChat != null) {
      return targetChat.supportsEmail;
    }
    return resolvedAddress?.isNotEmpty == true;
  }

  bool get isAxichatWelcomeThread =>
      chat?.isAxichatWelcomeThread ??
      isAxichatWelcomeThreadJid(chatJid ?? resolvedAddress);

  bool get hasEmailThread => chat?.defaultTransport.isEmail ?? false;

  bool get hasXmppThread => chat != null && !(chat!.defaultTransport.isEmail);

  EncryptionProtocol get encryptionProtocol =>
      chat?.encryptionProtocol ?? EncryptionProtocol.none;

  ChatType get chatType => chat?.type ?? ChatType.chat;

  String? get resolvedAddress {
    final trimmed = address?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String? get normalizedOrResolvedAddress =>
      normalizedAddress ?? resolvedAddress;

  String? get remoteAddress {
    final threadedAddress = chat?.remoteJid.trim();
    if (threadedAddress != null && threadedAddress.isNotEmpty) {
      return threadedAddress;
    }
    return resolvedAddress;
  }

  String? get bareRemoteAddress {
    final bareThreadedAddress = bareAddressOrNull(chat?.remoteJid);
    if (bareThreadedAddress != null && bareThreadedAddress.isNotEmpty) {
      return bareThreadedAddress;
    }
    final bareChatJid = bareAddressOrNull(chatJid);
    if (bareChatJid != null && bareChatJid.isNotEmpty) {
      return bareChatJid;
    }
    return bareAddressOrNull(resolvedAddress);
  }

  String? get effectiveAvatarPath {
    final currentChat = chat;
    if (currentChat == null) {
      return null;
    }
    final primary = currentChat.avatarPath?.trim();
    if (primary != null && primary.isNotEmpty) {
      return primary;
    }
    final contact = currentChat.contactAvatarPath?.trim();
    if (contact != null && contact.isNotEmpty) {
      return contact;
    }
    return null;
  }

  String get jid {
    final value = resolvedAddress;
    if (value != null && value.isNotEmpty) {
      return value;
    }
    final chatJid = chat?.jid.trim();
    if (chatJid != null && chatJid.isNotEmpty) {
      return chatJid;
    }
    throw StateError('Contact has no jid.');
  }

  String? get recipientId {
    final existingChatJid = chatJid;
    if (existingChatJid != null && existingChatJid.isNotEmpty) {
      return existingChatJid;
    }
    return resolvedAddress;
  }

  String? get preferredEmailAddress {
    final chatEmail = chat?.emailAddress?.trim();
    if (chatEmail != null && chatEmail.isNotEmpty) {
      return chatEmail;
    }
    final chatJid = chat?.jid.trim();
    if (chatJid != null && chatJid.isNotEmpty) {
      return chatJid;
    }
    return resolvedAddress;
  }

  List<String> get identityAddresses {
    final values = <String>[];
    void add(String? candidate) {
      final trimmed = candidate?.trim();
      if (trimmed == null || trimmed.isEmpty || values.contains(trimmed)) {
        return;
      }
      values.add(trimmed);
    }

    add(address);
    add(chat?.jid);
    add(chat?.emailAddress);
    add(chat?.remoteJid);
    return values;
  }

  List<String> get normalizedIdentityKeys {
    final values = <String>[];
    for (final value in identityAddresses) {
      final normalized = normalizedAddressValue(value);
      if (normalized == null ||
          normalized.isEmpty ||
          values.contains(normalized)) {
        continue;
      }
      values.add(normalized);
    }
    return values;
  }

  List<String> get statusLookupKeys {
    final values = <String>[];
    final existingChatJid = chatJid;
    if (existingChatJid != null && existingChatJid.isNotEmpty) {
      values.add(existingChatJid);
    }
    for (final normalized in normalizedIdentityKeys) {
      if (values.contains(normalized)) {
        continue;
      }
      values.add(normalized);
    }
    return values;
  }

  String get displayName {
    final chatDisplayName = chat?.displayName.trim();
    if (chatDisplayName != null && chatDisplayName.isNotEmpty) {
      return chatDisplayName;
    }
    final resolvedDisplayName = providedDisplayName?.trim();
    if (resolvedDisplayName != null && resolvedDisplayName.isNotEmpty) {
      return resolvedDisplayName;
    }
    final resolved = resolvedAddress;
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    return jid;
  }

  String get colorSeed => chat?.jid ?? resolvedAddress ?? key;

  bool matchesChatJid(String jid) {
    final trimmed = jid.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final existingChatJid = chatJid;
    return existingChatJid != null &&
        existingChatJid.isNotEmpty &&
        existingChatJid == trimmed;
  }

  bool get needsTransportSelection {
    return chat == null && transport == null && resolvedAddress != null;
  }

  bool usesEmailTransport({bool allowHint = false}) {
    if (chat?.isEmailBacked ?? false) {
      return true;
    }
    final resolvedTransport =
        configuredTransport ?? (allowHint ? hintedTransport : null);
    return resolvedTransport?.isEmail ?? false;
  }

  String? xmppJid({bool allowHint = false}) {
    final resolvedTransport =
        configuredTransport ?? (allowHint ? hintedTransport : null);
    if (resolvedTransport?.isEmail ?? false) {
      return null;
    }
    final targetChat = chat;
    if (targetChat != null) {
      return resolvedTransport?.isXmpp ?? false ? targetChat.jid : null;
    }
    final candidate = normalizedOrResolvedAddress;
    if (candidate == null || candidate.isEmpty) {
      return null;
    }
    return resolvedTransport?.isXmpp ?? false ? candidate : null;
  }

  Contact withTransport(MessageTransport nextTransport) {
    if (transport == nextTransport || chat != null) {
      return this;
    }
    final candidate = resolvedAddress;
    if (candidate == null || candidate.isEmpty) {
      return this;
    }
    return Contact.address(
      nativeID: nativeID,
      address: candidate,
      displayName: providedDisplayName,
      shareSignatureEnabled: shareSignatureEnabled,
      transport: nextTransport,
    );
  }

  String? get normalizedAddress {
    final value = address?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value.toLowerCase();
  }

  @override
  Map<String, Expression<Object>> toColumns(bool nullToAbsent) {
    final storedNativeID = nativeID?.trim();
    final storedJid = resolvedAddress;
    if (storedNativeID == null ||
        storedNativeID.isEmpty ||
        storedJid == null ||
        storedJid.isEmpty) {
      throw StateError(
        'Cannot persist transient Contact without nativeID and jid.',
      );
    }
    return <String, Expression<Object>>{
      'native_i_d': Variable<String>(storedNativeID),
      'jid': Variable<String>(storedJid),
    };
  }

  @override
  List<Object?> get props => [
    nativeID,
    chat?.jid,
    address,
    providedDisplayName,
    shareSignatureEnabled,
    transport,
  ];
}

@UseRowClass(Contact, constructor: 'fromDb')
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

bool isAxichatWelcomeThreadJid(String? jid) {
  return jid?.trim() == 'axichat@welcome.axichat.invalid';
}

extension ChatSystemThreadExtension on Chat {
  bool get isAxichatWelcomeThread => isAxichatWelcomeThreadJid(jid);
}

extension ChatPrimaryViewExtension on Chat {
  bool get opensToCalendar => primaryView.isCalendar;

  bool get isCalendarFirstRoom => type == ChatType.groupChat && opensToCalendar;
}

extension ChatTransportExtension on Chat {
  bool get supportsEmail => isEmailBacked;

  bool get isAxiContact {
    return remoteJid.isAxiJid;
  }

  bool get isEmailOnlyContact {
    if (type != ChatType.chat) {
      return false;
    }
    return isEmailBacked;
  }

  bool get isEmailBacked {
    if (deltaChatId != null) {
      return true;
    }
    final address = emailAddress?.trim();
    if (address != null && address.isNotEmpty) {
      return true;
    }
    final fromAddress = emailFromAddress?.trim();
    if (fromAddress != null && fromAddress.isNotEmpty) {
      return true;
    }
    return false;
  }

  String get antiAbuseTargetAddress {
    if (!isEmailBacked) {
      return jid.trim();
    }
    final candidates = <String?>[
      emailAddress,
      contactJid,
      contactID,
      emailFromAddress,
      jid,
    ];
    for (final candidate in candidates) {
      final bareAddress = bareAddressOrNull(candidate);
      if (bareAddress == null) {
        continue;
      }
      final normalized = normalizedAddressValue(bareAddress);
      if (normalized == null ||
          normalized.isEmpty ||
          normalized.isDeltaPlaceholderJid) {
        continue;
      }
      return normalized;
    }
    return jid.trim();
  }

  String get spamSyncTargetJid => antiAbuseTargetAddress;

  MessageTransport get defaultTransport {
    return transport;
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

extension ChatIdentityExtension on Chat {
  List<String> get identityAddresses {
    final values = <String>[];
    void add(String? candidate) {
      final trimmed = candidate?.trim();
      if (trimmed == null || trimmed.isEmpty || values.contains(trimmed)) {
        return;
      }
      values.add(trimmed);
    }

    add(jid);
    add(emailAddress);
    add(remoteJid);
    return values;
  }

  List<String> get normalizedIdentityKeys {
    final values = <String>[];
    for (final address in identityAddresses) {
      final normalized = normalizedAddressValue(address);
      if (normalized == null ||
          normalized.isEmpty ||
          values.contains(normalized)) {
        continue;
      }
      values.add(normalized);
    }
    return values;
  }
}

@Freezed(toJson: false, fromJson: false)
sealed class BlocklistData
    with _$BlocklistData
    implements Insertable<BlocklistData> {
  const factory BlocklistData({
    required String jid,
    required DateTime blockedAt,
  }) = _BlocklistData;

  const BlocklistData._();

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) => {
    'jid': Variable<String>(jid),
    'blocked_at': Variable<DateTime>(blockedAt),
  };
}

@UseRowClass(BlocklistData)
class Blocklist extends Table {
  TextColumn get jid => text()();

  DateTimeColumn get blockedAt =>
      dateTime().clientDefault(() => DateTime.timestamp())();

  @override
  Set<Column> get primaryKey => {jid};
}

@Freezed(toJson: false, fromJson: false)
sealed class EmailBlocklistEntry
    with _$EmailBlocklistEntry
    implements Insertable<EmailBlocklistEntry> {
  const factory EmailBlocklistEntry({
    required String address,
    required DateTime blockedAt,
    @Default(0) int blockedMessageCount,
    DateTime? lastBlockedMessageAt,
    String? sourceId,
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
    if (sourceId != null) {
      map['source_id'] = Variable<String>(sourceId!);
    }
    return map;
  }
}

typedef AddressBlockEntry = EmailBlocklistEntry;

@UseRowClass(EmailBlocklistEntry)
class EmailBlocklist extends Table {
  TextColumn get address => text()();

  DateTimeColumn get blockedAt =>
      dateTime().clientDefault(() => DateTime.timestamp())();

  IntColumn get blockedMessageCount =>
      integer().withDefault(const Constant(0))();

  DateTimeColumn get lastBlockedMessageAt => dateTime().nullable()();

  TextColumn get sourceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {address};
}

@Freezed(toJson: false, fromJson: false)
sealed class EmailSpamEntry
    with _$EmailSpamEntry
    implements Insertable<EmailSpamEntry> {
  const factory EmailSpamEntry({
    required String address,
    required DateTime flaggedAt,
    String? sourceId,
  }) = _EmailSpamEntry;

  const EmailSpamEntry._();

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) => {
    'address': Variable<String>(address),
    'flagged_at': Variable<DateTime>(flaggedAt),
    if (sourceId != null) 'source_id': Variable<String>(sourceId!),
  };
}

typedef SpamEntry = EmailSpamEntry;

@UseRowClass(EmailSpamEntry)
class EmailSpamlist extends Table {
  TextColumn get address => text()();

  DateTimeColumn get flaggedAt =>
      dateTime().clientDefault(() => DateTime.timestamp())();

  TextColumn get sourceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {address};
}
