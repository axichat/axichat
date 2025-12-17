// ignore_for_file: avoid_renaming_method_parameters

import 'dart:io';

import 'package:axichat/src/common/bool_tool.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:omemo_dart/omemo_dart.dart' as omemo;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import 'models.dart';

part 'database.g.dart';

abstract interface class Database {
  /// Must be idempotent.
  Future<void> close();
}

abstract interface class XmppDatabase implements Database {
  Stream<List<Message>> watchChatMessages(
    String jid, {
    required int start,
    required int end,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  });

  Future<List<Message>> getChatMessages(
    String jid, {
    required int start,
    required int end,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  });

  Future<int> countChatMessages(
    String jid, {
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    bool includePseudoMessages = true,
  });

  Future<List<Message>> getAllMessagesForChat(
    String jid, {
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  });

  Future<List<Message>> searchChatMessages({
    required String jid,
    String? query,
    String? subject,
    bool excludeSubject = false,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    int limit,
    bool ascending,
  });

  Future<List<String>> subjectsForChat(String jid);

  Future<Message?> getMessageByStanzaID(String stanzaID);

  Future<Message?> getMessageByOriginID(String originID);

  Stream<List<Reaction>> watchReactionsForChat(String jid);

  Future<List<Reaction>> getReactionsForChat(String jid);

  Future<List<Reaction>> getReactionsForMessageSender({
    required String messageId,
    required String senderJid,
  });

  Future<void> replaceReactions({
    required String messageId,
    required String senderJid,
    required List<String> emojis,
  });

  Future<void> saveMessage(
    Message message, {
    ChatType chatType = ChatType.chat,
  });

  Future<void> saveMessageError({
    required String stanzaID,
    required MessageError error,
  });

  Future<void> saveMessageDevice({
    required String stanzaID,
    required int deviceID,
    required String to,
  });

  Future<void> saveMessageEdit({
    required String stanzaID,
    required String? body,
  });

  Future<void> updateMessageAttachment({
    required String stanzaID,
    FileMetadataData? metadata,
    String? body,
  });

  Future<void> markMessageRetracted(String stanzaID);

  Future<void> markMessageAcked(String stanzaID);

  Future<void> markMessageReceived(String stanzaID);

  Future<void> markMessageDisplayed(String stanzaID);

  Future<void> deleteMessage(String stanzaID);

  Future<void> clearMessageHistory();

  Future<void> trimChatMessages({
    required String jid,
    required int maxMessages,
  });

  Future<void> createMessageShare({
    required MessageShareData share,
    required List<MessageParticipantData> participants,
  });

  Future<void> insertMessageCopy({
    required String shareId,
    required int dcMsgId,
    required int dcChatId,
  });

  Future<void> assignShareOriginator({
    required String shareId,
    required int originatorDcMsgId,
  });

  Future<void> saveMessageShareSubject({
    required String shareId,
    required String? subject,
  });

  Future<MessageShareData?> getMessageShareByToken(String token);

  Future<MessageShareData?> getMessageShareById(String shareId);

  Future<List<MessageParticipantData>> getParticipantsForShare(String shareId);

  Future<List<MessageCopyData>> getMessageCopiesForShare(String shareId);

  Future<List<Message>> getMessagesForShare(String shareId);

  Future<String?> getShareIdForDeltaMessage(int deltaMsgId);

  Future<void> removeChatMessages(String jid);

  Stream<List<Draft>> watchDrafts({required int start, required int end});

  Future<List<Draft>> getDrafts({required int start, required int end});

  Future<Draft?> getDraft(int id);

  Future<int> saveDraft({
    int? id,
    required List<String> jids,
    required String body,
    String? subject,
    List<String> attachmentMetadataIds = const [],
  });

  Future<void> removeDraft(int id);

  Future<OmemoDevice?> getOmemoDevice(String jid);

  Future<void> saveOmemoDevice(OmemoDevice device);

  Future<void> deleteOmemoDevice(String jid);

  Future<OmemoDeviceList?> getOmemoDeviceList(String jid);

  Future<void> saveOmemoDeviceList(OmemoDeviceList data);

  Future<void> deleteOmemoDeviceList(String jid);

  Future<List<OmemoTrust>> getOmemoTrusts(String jid);

  Future<List<OmemoTrust>> getAllOmemoTrusts();

  Future<OmemoTrust?> getOmemoTrust(String jid, int device);

  Future<void> setOmemoTrust(OmemoTrust trust);

  Future<void> setOmemoTrustLabel({
    required String jid,
    required int device,
    required String? label,
  });

  Future<void> resetOmemoTrust(String jid);

  Future<List<OmemoRatchet>> getOmemoRatchets(String jid);

  Future<void> saveOmemoRatchet(OmemoRatchet ratchet);

  Future<void> saveOmemoRatchets(List<OmemoRatchet> ratchets);

  Future<void> removeOmemoRatchets(List<(String, int)> ratchets);

  Future<OmemoBundleCache?> getOmemoBundleCache(String jid, int device);

  Future<void> saveOmemoBundleCache(OmemoBundleCache cache);

  Future<void> removeOmemoBundleCache(String jid, int device);

  Future<void> clearOmemoBundleCache();

  Future<DateTime?> getLastPreKeyRotationTime(String jid);

  Future<void> setLastPreKeyRotationTime(String jid, DateTime time);

  Future<void> saveFileMetadata(FileMetadataData metadata);

  Future<FileMetadataData?> getFileMetadata(String id);

  Stream<FileMetadataData?> watchFileMetadata(String id);

  Future<void> deleteFileMetadata(String id);

  Stream<List<Chat>> watchChats({required int start, required int end});

  Future<List<Chat>> getChats({required int start, required int end});

  Future<Chat?> getChat(String jid);

  Future<Chat?> getChatByDeltaChatId(int deltaChatId);

  Stream<Chat?> watchChatByDeltaChatId(int deltaChatId);

  Future<void> createChat(Chat chat);

  Future<void> updateChat(Chat chat);

  Stream<Chat?> watchChat(String jid);

  Future<Chat?> openChat(String jid);

  Future<Chat?> closeChat();

  Future<void> markChatMuted({
    required String jid,
    required bool muted,
  });

  Future<void> setChatShareSignature({
    required String jid,
    required bool enabled,
  });

  Future<void> markChatFavorited({
    required String jid,
    required bool favorited,
  });

  Future<void> markChatArchived({
    required String jid,
    required bool archived,
  });

  Future<void> markChatHidden({
    required String jid,
    required bool hidden,
  });

  Future<void> markChatSpam({
    required String jid,
    required bool spam,
  });

  Future<void> markChatMarkerResponsive({
    required String jid,
    required bool responsive,
  });

  Future<void> updateChatAvatar({
    required String jid,
    required String? avatarPath,
    required String? avatarHash,
  });

  Future<void> markChatsMarkerResponsive({required bool responsive});

  Future<void> updateChatState({
    required String chatJid,
    required mox.ChatState state,
  });

  Future<void> updateChatEncryption({
    required String chatJid,
    required EncryptionProtocol protocol,
  });

  Future<void> updateChatAlert({
    required String chatJid,
    required String? alert,
  });

  Future<void> removeChat(String jid);

  Stream<List<RosterItem>> watchRoster({required int start, required int end});

  Future<List<RosterItem>> getRoster();

  Future<RosterItem?> getRosterItem(String jid);

  Future<void> saveRosterItem(RosterItem item);

  Future<void> saveRosterItems(List<RosterItem> items);

  Future<void> updateRosterItem(RosterItem item);

  Future<void> updateRosterItems(List<RosterItem> items);

  Future<void> removeRosterItem(String jid);

  Future<void> removeRosterItems(List<String> jids);

  Future<void> updatePresence({
    required String jid,
    required Presence presence,
    String? status,
  });

  Future<void> updateRosterSubscription({
    required String jid,
    required Subscription subscription,
  });

  Future<void> updateRosterAsk({
    required String jid,
    Ask? ask,
  });

  Future<void> updateRosterAvatar({
    required String jid,
    required String? avatarPath,
    required String? avatarHash,
  });

  Future<void> markSubscriptionBoth(String jid);

  Stream<List<Invite>> watchInvites({required int start, required int end});

  Future<List<Invite>> getInvites({required int start, required int end});

  Future<void> saveInvite(Invite invite);

  Future<void> deleteInvite(String jid);

  Stream<List<BlocklistData>> watchBlocklist({
    required int start,
    required int end,
  });

  Future<List<BlocklistData>> getBlocklist({
    required int start,
    required int end,
  });

  Future<void> blockJid(String jid);

  Future<void> blockJids(List<String> jids);

  Future<void> unblockJid(String jid);

  Future<void> unblockJids(List<String> jids);

  Future<void> replaceBlocklist(List<String> blocks);

  Future<void> deleteBlocklist();

  Stream<List<EmailBlocklistEntry>> watchEmailBlocklist();

  Future<List<EmailBlocklistEntry>> getEmailBlocklist();

  Future<void> addEmailBlock(String address);

  Future<void> removeEmailBlock(String address);

  Future<bool> isEmailAddressBlocked(String address);

  Future<void> incrementEmailBlockCount(String address);

  Stream<List<EmailSpamEntry>> watchEmailSpamlist();

  Future<void> addEmailSpam(String address);

  Future<void> removeEmailSpam(String address);

  Future<bool> isEmailAddressSpam(String address);

  Stream<List<DayEventEntry>> watchDayEvents({
    required DateTime start,
    required DateTime end,
  });

  Future<List<DayEventEntry>> getDayEvents({
    required DateTime start,
    required DateTime end,
  });

  Future<DayEventEntry?> getDayEvent(String id);

  Future<void> saveDayEvent(DayEventEntry entry);

  Future<void> deleteDayEvent(String id);

  Future<void> replaceDayEvents(Iterable<DayEventEntry> entries);

  Future<void> deleteAll();

  Future<void> deleteFile();
}

abstract class BaseAccessor<D, T extends TableInfo<Table, D>>
    extends DatabaseAccessor<XmppDrift> {
  BaseAccessor(super.attachedDatabase);

  T get table;

  Stream<List<D>> watchAll() => select(table).watch();

  Future<List<D>> selectAll() => select(table).get();

  Future<D?> selectOne(covariant Object value);

  Future<void> insertOne(Insertable<D> data) =>
      into(table).insert(data, mode: InsertMode.insertOrIgnore);

  Future<int> insertOrUpdateOne(Insertable<D> data) =>
      into(table).insertOnConflictUpdate(data);

  Future<void> updateOne(Insertable<D> data) =>
      (update(table)..whereSamePrimaryKey(data)).write(data);

  Future<void> deleteOne(covariant Object value);
}

@DriftAccessor(tables: [Messages])
class MessagesAccessor extends BaseAccessor<Message, $MessagesTable>
    with _$MessagesAccessorMixin {
  MessagesAccessor(super.attachedDatabase);

  @override
  $MessagesTable get table => messages;

  Stream<List<Message>> watchChat(String jid, {int limit = 50}) =>
      (select(table)
            ..where((table) => table.chatJid.equals(jid))
            ..orderBy([
              (t) => OrderingTerm(
                    expression: t.timestamp,
                    mode: OrderingMode.desc,
                  )
            ])
            ..limit(limit))
          .watch();

  Future<List<Message>> selectChatMessages(String jid) => (select(table)
        ..where((table) => table.chatJid.equals(jid))
        ..orderBy([
          (t) => OrderingTerm(
                expression: t.timestamp,
                mode: OrderingMode.desc,
              )
        ]))
      .get();

  @override
  Future<Message?> selectOne(String stanzaID) =>
      (select(table)..where((table) => table.stanzaID.equals(stanzaID)))
          .getSingleOrNull();

  Future<Message?> selectOneByOriginID(String originID) =>
      (select(table)..where((table) => table.originID.equals(originID)))
          .getSingleOrNull();

  Future<void> updateTrust(int device, BTBVTrustState trust, bool trusted) =>
      (update(table)..where((table) => table.deviceID.equals(device)))
          .write(MessagesCompanion(trust: Value(trust)));

  @override
  Future<void> deleteOne(String stanzaID) =>
      (delete(table)..where((item) => item.stanzaID.equals(stanzaID))).go();

  Future<void> deleteChatMessages(String jid) =>
      (delete(table)..where((item) => item.chatJid.equals(jid))).go();
}

@DriftAccessor(tables: [MessageShares])
class MessageSharesAccessor
    extends BaseAccessor<MessageShareData, $MessageSharesTable>
    with _$MessageSharesAccessorMixin {
  MessageSharesAccessor(super.attachedDatabase);

  @override
  $MessageSharesTable get table => messageShares;

  @override
  Future<MessageShareData?> selectOne(String shareId) =>
      (select(table)..where((tbl) => tbl.shareId.equals(shareId)))
          .getSingleOrNull();

  Future<MessageShareData?> selectByToken(String token) =>
      (select(table)..where((tbl) => tbl.subjectToken.equals(token)))
          .getSingleOrNull();

  Future<void> updateOriginator(String shareId, int originatorDcMsgId) =>
      (update(table)..where((tbl) => tbl.shareId.equals(shareId))).write(
        MessageSharesCompanion(
          originatorDcMsgId: Value(originatorDcMsgId),
        ),
      );

  Future<void> updateSubject(String shareId, String? subject) =>
      (update(table)..where((tbl) => tbl.shareId.equals(shareId))).write(
        MessageSharesCompanion(
          subject: Value(subject),
        ),
      );

  @override
  Future<void> deleteOne(String shareId) =>
      (delete(table)..where((tbl) => tbl.shareId.equals(shareId))).go();
}

@DriftAccessor(tables: [MessageParticipants])
class MessageParticipantsAccessor
    extends BaseAccessor<MessageParticipantData, $MessageParticipantsTable>
    with _$MessageParticipantsAccessorMixin {
  MessageParticipantsAccessor(super.attachedDatabase);

  @override
  $MessageParticipantsTable get table => messageParticipants;

  @override
  Future<MessageParticipantData?> selectOne((String, String) key) =>
      (select(table)
            ..where((tbl) =>
                tbl.shareId.equals(key.$1) & tbl.contactJid.equals(key.$2)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne((String, String) key) => (delete(table)
        ..where((tbl) =>
            tbl.shareId.equals(key.$1) & tbl.contactJid.equals(key.$2)))
      .go();

  Future<List<MessageParticipantData>> selectByShare(String shareId) =>
      (select(table)..where((tbl) => tbl.shareId.equals(shareId))).get();
}

@DriftAccessor(tables: [MessageCopies])
class MessageCopiesAccessor
    extends BaseAccessor<MessageCopyData, $MessageCopiesTable>
    with _$MessageCopiesAccessorMixin {
  MessageCopiesAccessor(super.attachedDatabase);

  @override
  $MessageCopiesTable get table => messageCopies;

  @override
  Future<MessageCopyData?> selectOne(int id) =>
      (select(table)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  @override
  Future<void> deleteOne(int id) =>
      (delete(table)..where((tbl) => tbl.id.equals(id))).go();

  Future<MessageCopyData?> selectByDeltaMsgId(int deltaMsgId) =>
      (select(table)..where((tbl) => tbl.dcMsgId.equals(deltaMsgId)))
          .getSingleOrNull();

  Future<String?> selectShareIdForDeltaMsg(int deltaMsgId) async =>
      (await selectByDeltaMsgId(deltaMsgId))?.shareId;

  Future<List<MessageCopyData>> selectByShare(String shareId) =>
      (select(table)..where((tbl) => tbl.shareId.equals(shareId))).get();
}

@DriftAccessor(tables: [Reactions, Messages])
class ReactionsAccessor extends DatabaseAccessor<XmppDrift>
    with _$ReactionsAccessorMixin {
  ReactionsAccessor(super.attachedDatabase);

  Stream<List<Reaction>> watchChat(String jid) {
    final query = select(reactions).join([
      innerJoin(messages, messages.stanzaID.equalsExp(reactions.messageID)),
    ])
      ..where(messages.chatJid.equals(jid));
    return query
        .watch()
        .map((rows) => rows.map((row) => row.readTable(reactions)).toList());
  }

  Future<List<Reaction>> selectByChat(String jid) {
    final query = select(reactions).join([
      innerJoin(messages, messages.stanzaID.equalsExp(reactions.messageID)),
    ])
      ..where(messages.chatJid.equals(jid));
    return query
        .get()
        .then((rows) => rows.map((row) => row.readTable(reactions)).toList());
  }

  Future<List<Reaction>> selectByMessageAndSender({
    required String messageId,
    required String senderJid,
  }) =>
      (select(reactions)
            ..where(
              (table) =>
                  table.messageID.equals(messageId) &
                  table.senderJid.equals(senderJid),
            ))
          .get();

  Future<void> deleteByMessage(String messageId) =>
      (delete(reactions)..where((table) => table.messageID.equals(messageId)))
          .go();

  Future<void> deleteByMessageAndSender({
    required String messageId,
    required String senderJid,
  }) =>
      (delete(reactions)
            ..where(
              (table) =>
                  table.messageID.equals(messageId) &
                  table.senderJid.equals(senderJid),
            ))
          .go();
}

@DriftAccessor(tables: [Drafts])
class DraftsAccessor extends BaseAccessor<Draft, $DraftsTable>
    with _$DraftsAccessorMixin {
  DraftsAccessor(super.attachedDatabase);

  @override
  $DraftsTable get table => drafts;

  @override
  Future<Draft?> selectOne(int id) =>
      (select(table)..where((table) => table.id.equals(id))).getSingleOrNull();

  @override
  Future<void> deleteOne(int id) =>
      (delete(table)..where((item) => item.id.equals(id))).go();
}

@DriftAccessor(tables: [OmemoDevices])
class OmemoDevicesAccessor extends BaseAccessor<OmemoDevice, $OmemoDevicesTable>
    with _$OmemoDevicesAccessorMixin {
  OmemoDevicesAccessor(super.attachedDatabase);

  @override
  $OmemoDevicesTable get table => omemoDevices;

  @override
  Future<OmemoDevice?> selectOne(String value) =>
      (select(table)..where((table) => table.jid.equals(value)))
          .getSingleOrNull();

  Future<OmemoDevice?> selectByID(int value) =>
      (select(table)..where((table) => table.id.equals(value)))
          .getSingleOrNull();

  Future<List<OmemoDevice>> selectByJid(String jid) =>
      (select(table)..where((table) => table.jid.equals(jid))).get();

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((table) => table.jid.equals(value))).go();
}

@DriftAccessor(tables: [OmemoTrusts])
class OmemoTrustsAccessor extends BaseAccessor<OmemoTrust, $OmemoTrustsTable>
    with _$OmemoTrustsAccessorMixin {
  OmemoTrustsAccessor(super.attachedDatabase);

  @override
  $OmemoTrustsTable get table => omemoTrusts;

  @override
  Future<OmemoTrust?> selectOne(OmemoTrust value) =>
      (select(table)..whereSamePrimaryKey(value)).getSingleOrNull();

  Future<List<OmemoTrust>> selectByJid(String jid) =>
      (select(table)..where((table) => table.jid.equals(jid))).get();

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((table) => table.jid.equals(value))).go();
}

@DriftAccessor(tables: [OmemoDeviceLists])
class OmemoDeviceListsAccessor
    extends BaseAccessor<OmemoDeviceList, $OmemoDeviceListsTable>
    with _$OmemoDeviceListsAccessorMixin {
  OmemoDeviceListsAccessor(super.attachedDatabase);

  @override
  $OmemoDeviceListsTable get table => omemoDeviceLists;

  @override
  Future<OmemoDeviceList?> selectOne(String value) =>
      (select(table)..where((table) => table.jid.equals(value)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((table) => table.jid.equals(value))).go();
}

@DriftAccessor(tables: [OmemoRatchets])
class OmemoRatchetsAccessor
    extends BaseAccessor<OmemoRatchet, $OmemoRatchetsTable>
    with _$OmemoRatchetsAccessorMixin {
  OmemoRatchetsAccessor(super.attachedDatabase);

  @override
  $OmemoRatchetsTable get table => omemoRatchets;

  @override
  Future<OmemoRatchet?> selectOne((String, int) key) => (select(table)
        ..where(
            (table) => table.jid.equals(key.$1) & table.device.equals(key.$2)))
      .getSingleOrNull();

  Future<List<OmemoRatchet>> selectByJid(String jid) =>
      (select(table)..where((table) => table.jid.equals(jid))).get();

  @override
  Future<void> deleteOne((String, int) key) => (delete(table)
        ..where(
            (table) => table.jid.equals(key.$1) & table.device.equals(key.$2)))
      .go();
}

@DriftAccessor(tables: [OmemoBundleCaches])
class OmemoBundleCachesAccessor
    extends BaseAccessor<OmemoBundleCache, $OmemoBundleCachesTable>
    with _$OmemoBundleCachesAccessorMixin {
  OmemoBundleCachesAccessor(super.attachedDatabase);

  @override
  $OmemoBundleCachesTable get table => omemoBundleCaches;

  Future<OmemoBundleCache?> selectByKey(String jid, int device) =>
      selectOne((jid, device));

  @override
  Future<OmemoBundleCache?> selectOne((String, int) key) => (select(table)
        ..where((tbl) => tbl.jid.equals(key.$1) & tbl.device.equals(key.$2)))
      .getSingleOrNull();

  @override
  Future<void> deleteOne((String, int) key) => (delete(table)
        ..where((tbl) => tbl.jid.equals(key.$1) & tbl.device.equals(key.$2)))
      .go();

  Future<void> clear() => delete(table).go();
}

@DriftAccessor(tables: [FileMetadata])
class FileMetadataAccessor
    extends BaseAccessor<FileMetadataData, $FileMetadataTable>
    with _$FileMetadataAccessorMixin {
  FileMetadataAccessor(super.attachedDatabase);

  @override
  $FileMetadataTable get table => fileMetadata;

  @override
  Future<FileMetadataData?> selectOne(Object value) =>
      (select(table)..where((table) => table.id.equals(value as String)))
          .getSingleOrNull();

  Stream<FileMetadataData?> watchOne(String id) =>
      (select(table)..where((table) => table.id.equals(id)))
          .watchSingleOrNull();

  Future<FileMetadataData?> selectOneByPlaintextHashes(
          Map<HashFunction, String> hashes) =>
      (select(table)
            ..where((table) => table.plainTextHashes.equalsValue(hashes)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne(String id) =>
      (delete(table)..where((item) => item.id.equals(id))).go();
}

@DriftAccessor(tables: [Chats])
class ChatsAccessor extends BaseAccessor<Chat, $ChatsTable>
    with _$ChatsAccessorMixin {
  ChatsAccessor(super.attachedDatabase);

  @override
  $ChatsTable get table => chats;

  @override
  Stream<List<Chat>> watchAll() => (select(table)
        ..orderBy([
          (t) => OrderingTerm(
                expression: t.favorited,
                mode: OrderingMode.desc,
              ),
          (t) => OrderingTerm(
                expression: t.lastChangeTimestamp,
                mode: OrderingMode.desc,
              ),
        ]))
      .watch();

  Stream<Chat?> watchOne(String jid) =>
      (select(table)..where((table) => table.jid.equals(jid)))
          .watchSingleOrNull();

  @override
  Future<Chat?> selectOne(String value) =>
      (select(table)..where((table) => table.jid.equals(value)))
          .getSingleOrNull();

  Future<Chat?> selectOpen() =>
      (select(table)..where((table) => table.open.equals(true)))
          .getSingleOrNull();

  Future<List<Chat>> closeOpen() =>
      (update(table)..where((table) => table.open.equals(true))).writeReturning(
          const ChatsCompanion(
              open: Value(false), chatState: Value(mox.ChatState.gone)));

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((item) => item.jid.equals(value))).go();
}

@DriftAccessor(tables: [Roster])
class RosterAccessor extends BaseAccessor<RosterItem, $RosterTable>
    with _$RosterAccessorMixin {
  RosterAccessor(super.attachedDatabase);

  @override
  $RosterTable get table => roster;

  @override
  Future<RosterItem?> selectOne(String value) =>
      (select(table)..where((table) => table.jid.equals(value)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((table) => table.jid.equals(value))).go();
}

@DriftAccessor(tables: [Invites])
class InvitesAccessor extends BaseAccessor<Invite, $InvitesTable>
    with _$InvitesAccessorMixin {
  InvitesAccessor(super.attachedDatabase);

  @override
  $InvitesTable get table => invites;

  @override
  Future<Invite?> selectOne(String value) =>
      (select(table)..where((table) => table.jid.equals(value)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((item) => item.jid.equals(value))).go();
}

@DriftAccessor(tables: [Blocklist])
class BlocklistAccessor extends BaseAccessor<BlocklistData, $BlocklistTable>
    with _$BlocklistAccessorMixin {
  BlocklistAccessor(super.attachedDatabase);

  @override
  $BlocklistTable get table => blocklist;

  @override
  Future<BlocklistData?> selectOne(String value) =>
      (select(table)..where((table) => table.jid.equals(value)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((item) => item.jid.equals(value))).go();

  Future<void> deleteAll() => delete(blocklist).go();
}

@DriftAccessor(tables: [EmailBlocklist])
class EmailBlocklistAccessor
    extends BaseAccessor<EmailBlocklistEntry, $EmailBlocklistTable>
    with _$EmailBlocklistAccessorMixin {
  EmailBlocklistAccessor(super.attachedDatabase);

  @override
  $EmailBlocklistTable get table => emailBlocklist;

  @override
  Future<EmailBlocklistEntry?> selectOne(String address) =>
      (select(table)..where((tbl) => tbl.address.equals(address)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne(String address) =>
      (delete(table)..where((tbl) => tbl.address.equals(address))).go();

  Stream<List<EmailBlocklistEntry>> watchEntries() => select(table).watch();

  Future<List<EmailBlocklistEntry>> selectEntries() => select(table).get();
}

@DriftAccessor(tables: [EmailSpamlist])
class EmailSpamlistAccessor
    extends BaseAccessor<EmailSpamEntry, $EmailSpamlistTable>
    with _$EmailSpamlistAccessorMixin {
  EmailSpamlistAccessor(super.attachedDatabase);

  @override
  $EmailSpamlistTable get table => emailSpamlist;

  @override
  Future<EmailSpamEntry?> selectOne(String address) =>
      (select(table)..where((tbl) => tbl.address.equals(address)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne(String address) =>
      (delete(table)..where((tbl) => tbl.address.equals(address))).go();

  Stream<List<EmailSpamEntry>> watchEntries() => select(table).watch();
}

@DriftAccessor(tables: [DayEvents])
class DayEventsAccessor extends BaseAccessor<DayEventEntry, $DayEventsTable>
    with _$DayEventsAccessorMixin {
  DayEventsAccessor(super.attachedDatabase);

  @override
  $DayEventsTable get table => dayEvents;

  @override
  Future<DayEventEntry?> selectOne(String id) =>
      (select(table)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Stream<List<DayEventEntry>> watchRange(DateTime start, DateTime end) =>
      (select(table)
            ..where(
              (tbl) =>
                  tbl.startDate.isSmallerOrEqual(Variable(end)) &
                  tbl.endDate.isBiggerOrEqual(Variable(start)),
            )
            ..orderBy([
              (tbl) => OrderingTerm(
                    expression: tbl.startDate,
                    mode: OrderingMode.asc,
                  ),
            ]))
          .watch();

  Future<List<DayEventEntry>> selectRange(DateTime start, DateTime end) =>
      (select(table)
            ..where(
              (tbl) =>
                  tbl.startDate.isSmallerOrEqual(Variable(end)) &
                  tbl.endDate.isBiggerOrEqual(Variable(start)),
            )
            ..orderBy([
              (tbl) => OrderingTerm(
                    expression: tbl.startDate,
                    mode: OrderingMode.asc,
                  ),
            ]))
          .get();

  Future<void> insertAll(List<DayEventEntry> entries) async {
    if (entries.isEmpty) {
      return;
    }
    await batch(
      (batch) => batch.insertAll(
        table,
        entries.map((entry) => DayEventsCompanion.insert(
              id: entry.id,
              title: entry.title,
              startDate: entry.startDate,
              endDate: entry.endDate,
              description: Value(entry.description),
              reminders: entry.reminders,
              createdAt: entry.createdAt,
              modifiedAt: entry.modifiedAt,
            )),
        mode: InsertMode.insertOrReplace,
      ),
    );
  }

  Future<void> replaceAll(List<DayEventEntry> entries) async {
    await transaction(() async {
      await delete(table).go();
      await insertAll(entries);
    });
  }

  @override
  Future<void> deleteOne(String id) =>
      (delete(table)..where((tbl) => tbl.id.equals(id))).go();
}

@DriftDatabase(tables: [
  Messages,
  MessageShares,
  MessageParticipants,
  MessageCopies,
  Drafts,
  OmemoDevices,
  OmemoTrusts,
  OmemoDeviceLists,
  OmemoRatchets,
  OmemoBundleCaches,
  Reactions,
  Notifications,
  FileMetadata,
  Roster,
  Invites,
  Chats,
  Contacts,
  Blocklist,
  Stickers,
  StickerPacks,
  EmailBlocklist,
  EmailSpamlist,
  DayEvents,
], daos: [
  MessagesAccessor,
  MessageSharesAccessor,
  MessageParticipantsAccessor,
  MessageCopiesAccessor,
  ReactionsAccessor,
  DraftsAccessor,
  OmemoDevicesAccessor,
  OmemoTrustsAccessor,
  OmemoDeviceListsAccessor,
  OmemoRatchetsAccessor,
  OmemoBundleCachesAccessor,
  FileMetadataAccessor,
  ChatsAccessor,
  RosterAccessor,
  InvitesAccessor,
  BlocklistAccessor,
  EmailBlocklistAccessor,
  EmailSpamlistAccessor,
  DayEventsAccessor,
])
class XmppDrift extends _$XmppDrift implements XmppDatabase {
  XmppDrift._(this._file, super.e, {bool inMemory = false})
      : _inMemory = inMemory,
        super();

  factory XmppDrift.inMemory({QueryExecutor? executor}) =>
      _inMemoryInstance ??= XmppDrift._(
        File(''),
        executor ?? _openInMemoryDatabase(),
        inMemory: true,
      );

  static XmppDrift? _inMemoryInstance;
  static XmppDrift? _instance;

  factory XmppDrift({
    required File file,
    required String passphrase,
    QueryExecutor? executor,
  }) =>
      _instance ??=
          XmppDrift._(file, executor ?? _openDatabase(file, passphrase));

  final _log = Logger('XmppDrift');
  final File _file;
  final bool _inMemory;

  bool get isInMemory => _inMemory;
  String _normalizeEmail(String address) => address.trim().toLowerCase();

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _chatTitleForIdentifier(String identifier) {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) {
      return identifier;
    }
    try {
      return mox.JID.fromString(trimmed).local;
    } catch (_) {
      return trimmed;
    }
  }

  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(omemoBundleCaches);
        }
        if (from < 3) {
          await m.addColumn(messages, messages.deltaChatId);
          await m.addColumn(messages, messages.deltaMsgId);
          await m.addColumn(chats, chats.deltaChatId);
          await m.addColumn(chats, chats.emailAddress);
        }
        final rebuildReactions = from < 4;
        if (rebuildReactions) {
          await m.deleteTable(reactions.actualTableName);
        }
        if (from < 5) {
          await _rebuildMessagesTable(m);
        }
        if (from < 6) {
          await m.createTable(messageShares);
          await m.createTable(messageParticipants);
          await m.createTable(messageCopies);
        }
        if (from < 7) {
          await m.addColumn(chats, chats.archived);
          await m.addColumn(chats, chats.hidden);
        }
        if (from < 8) {
          await customStatement(
            '''
CREATE TABLE drafts_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  jids TEXT NOT NULL,
  body TEXT,
  attachment_metadata_ids TEXT NOT NULL DEFAULT '[]'
)
''',
          );
          await customStatement(
            '''
INSERT INTO drafts_new (id, jids, body, attachment_metadata_ids)
SELECT
  id,
  jids,
  body,
  CASE
    WHEN file_metadata_i_d IS NULL OR length(file_metadata_i_d) = 0 THEN '[]'
    ELSE json_array(file_metadata_i_d)
  END
FROM drafts
''',
          );
          await customStatement('DROP TABLE drafts');
          await customStatement('ALTER TABLE drafts_new RENAME TO drafts');
        }
        if (rebuildReactions) {
          await m.createTable(reactions);
        }
        if (from < 9) {
          await customStatement(
            '''
UPDATE message_shares
SET subject_token = UPPER(share_id)
WHERE subject_token IS NOT NULL
''',
          );
          await customStatement(
            '''
CREATE UNIQUE INDEX IF NOT EXISTS idx_message_shares_subject_token
ON message_shares(subject_token)
WHERE subject_token IS NOT NULL
''',
          );
        }
        if (from < 10) {
          await m.addColumn(messageShares, messageShares.subject);
          await m.addColumn(drafts, drafts.subject);
        }
        if (from < 11) {
          await m.createTable(emailBlocklist);
        }
        if (from < 12) {
          await m.addColumn(chats, chats.spam);
          await m.createTable(emailSpamlist);
        }
        if (from < 13) {
          await _mergeEmailChats();
        }
        if (from < 14) {
          await m.addColumn(chats, chats.shareSignatureEnabled);
        }
        if (from < 15) {
          await m.createTable(dayEvents);
        }
      },
      beforeOpen: (_) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  @override
  Stream<List<Message>> watchChatMessages(
    String jid, {
    required int start,
    required int end,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) {
    return _chatMessagesSelectable(
      jid: jid,
      filter: filter,
      limit: end,
      offset: start,
    ).watch();
  }

  @override
  Future<List<Message>> getChatMessages(
    String jid, {
    required int start,
    required int end,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) {
    return _chatMessagesSelectable(
      jid: jid,
      filter: filter,
      limit: end,
      offset: start,
    ).get();
  }

  @override
  Future<int> countChatMessages(
    String jid, {
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    bool includePseudoMessages = true,
  }) async {
    final filterValue = filter.index;
    final query = await customSelect(
      '''
      SELECT COUNT(*) AS count
      FROM messages m
      LEFT JOIN message_copies mc ON mc.dc_msg_id = m.delta_msg_id
      LEFT JOIN message_shares ms ON ms.share_id = mc.share_id
      LEFT JOIN message_participants mp
        ON mp.share_id = mc.share_id AND mp.contact_jid = ?
      WHERE m.chat_jid = ?
        AND (? = 1 OR m.pseudo_message_type IS NULL)
        AND (
          CASE WHEN ? = 0 THEN
            (mc.share_id IS NULL OR COALESCE(ms.participant_count, 0) <= 2)
          ELSE
            (mc.share_id IS NULL OR mp.contact_jid IS NOT NULL)
          END
        )
      ''',
      variables: [
        Variable<String>(jid),
        Variable<String>(jid),
        Variable<int>(includePseudoMessages ? 1 : 0),
        Variable<int>(filterValue),
      ],
      readsFrom: {
        messages,
        messageCopies,
        messageShares,
        messageParticipants,
      },
    ).getSingle();

    return query.read<int>('count');
  }

  Selectable<Message> _chatMessagesSelectable({
    required String jid,
    required MessageTimelineFilter filter,
    required int limit,
    required int offset,
  }) {
    final filterValue = filter.index;
    final query = customSelect(
      '''
      SELECT m.*
      FROM messages m
      LEFT JOIN message_copies mc ON mc.dc_msg_id = m.delta_msg_id
      LEFT JOIN message_shares ms ON ms.share_id = mc.share_id
      LEFT JOIN message_participants mp
        ON mp.share_id = mc.share_id AND mp.contact_jid = ?
      WHERE m.chat_jid = ?
        AND (
          CASE WHEN ? = 0 THEN
            (mc.share_id IS NULL OR COALESCE(ms.participant_count, 0) <= 2)
          ELSE
            (mc.share_id IS NULL OR mp.contact_jid IS NOT NULL)
          END
        )
      ORDER BY m.timestamp DESC
      LIMIT ?
      OFFSET ?
      ''',
      variables: [
        Variable<String>(jid),
        Variable<String>(jid),
        Variable<int>(filterValue),
        Variable<int>(limit),
        Variable<int>(offset),
      ],
      readsFrom: {
        messages,
        messageCopies,
        messageShares,
        messageParticipants,
      },
    );
    return query.map((row) => messages.map(row.data));
  }

  @override
  Future<List<Message>> getAllMessagesForChat(
    String jid, {
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    final query = select(messages)
      ..where((tbl) => tbl.chatJid.equals(jid))
      ..orderBy([
        (tbl) => OrderingTerm(
              expression: tbl.timestamp,
              mode: OrderingMode.asc,
            ),
      ]);
    return query.get();
  }

  @override
  Future<List<Message>> searchChatMessages({
    required String jid,
    String? query,
    String? subject,
    bool excludeSubject = false,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    int limit = 200,
    bool ascending = false,
  }) async {
    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    final normalizedSubject = subject?.trim().toLowerCase() ?? '';
    final hasQuery = normalizedQuery.isNotEmpty;
    final hasSubject = normalizedSubject.isNotEmpty;
    if (!hasQuery && !hasSubject) return const [];
    final filterValue = filter.index;
    final orderClause = ascending ? 'ASC' : 'DESC';
    final likePattern =
        hasQuery ? '%${_escapeLikePattern(normalizedQuery)}%' : '%';
    final subjectPattern =
        hasSubject ? '%${_escapeLikePattern(normalizedSubject)}%' : '%';
    final selectable = customSelect(
      '''
      SELECT m.*
      FROM messages m
      LEFT JOIN message_copies mc ON mc.dc_msg_id = m.delta_msg_id
      LEFT JOIN message_shares ms ON ms.share_id = mc.share_id
      LEFT JOIN message_participants mp
        ON mp.share_id = mc.share_id AND mp.contact_jid = ?
      WHERE m.chat_jid = ?
        AND (
          CASE WHEN ? = 0 THEN 1
               ELSE LOWER(COALESCE(m.body, '')) LIKE ? ESCAPE '\\'
          END
        )
        AND (
          CASE WHEN ? = 0 THEN
            (mc.share_id IS NULL OR COALESCE(ms.participant_count, 0) <= 2)
          ELSE
            (mc.share_id IS NULL OR mp.contact_jid IS NOT NULL)
          END
        )
        AND (
          CASE WHEN ? = 0 THEN 1
               WHEN ? = 1 THEN
                 COALESCE(LOWER(TRIM(ms.subject)), '') NOT LIKE ? ESCAPE '\\'
               ELSE
                 LOWER(TRIM(ms.subject)) LIKE ? ESCAPE '\\'
          END
        )
      ORDER BY m.timestamp $orderClause
      LIMIT ?
      ''',
      variables: [
        Variable<String>(jid),
        Variable<String>(jid),
        Variable<int>(hasQuery ? 1 : 0),
        Variable<String>(likePattern),
        Variable<int>(filterValue),
        Variable<int>(hasSubject ? 1 : 0),
        Variable<int>(excludeSubject ? 1 : 0),
        Variable<String>(subjectPattern),
        Variable<String>(subjectPattern),
        Variable<int>(limit),
      ],
      readsFrom: {
        messages,
        messageCopies,
        messageShares,
        messageParticipants,
      },
    );
    return selectable.map((row) => messages.map(row.data)).get();
  }

  @override
  Future<List<String>> subjectsForChat(String jid) async {
    final selectable = customSelect(
      '''
      SELECT DISTINCT TRIM(ms.subject) AS subject
      FROM message_shares ms
      JOIN message_copies mc ON mc.share_id = ms.share_id
      JOIN messages m ON m.delta_msg_id = mc.dc_msg_id
      WHERE m.chat_jid = ?
        AND ms.subject IS NOT NULL
        AND TRIM(ms.subject) <> ''
      ORDER BY LOWER(TRIM(ms.subject)) ASC
      ''',
      variables: [Variable<String>(jid)],
      readsFrom: {
        messageShares,
        messageCopies,
        messages,
      },
    );
    final rows = await selectable.get();
    return rows
        .map((row) => row.data['subject'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<Message?> getLastMessageForChat(String jid) async {
    final messages = await getChatMessages(jid, start: 0, end: 1);

    if (messages.isEmpty) {
      return null;
    }
    return messages.last;
  }

  @override
  Future<Message?> getMessageByStanzaID(String stanzaID) =>
      messagesAccessor.selectOne(stanzaID);

  @override
  Future<Message?> getMessageByOriginID(String originID) =>
      messagesAccessor.selectOneByOriginID(originID);

  @override
  Stream<List<Reaction>> watchReactionsForChat(String jid) =>
      reactionsAccessor.watchChat(jid);

  @override
  Future<List<Reaction>> getReactionsForChat(String jid) =>
      reactionsAccessor.selectByChat(jid);

  @override
  Future<List<Reaction>> getReactionsForMessageSender({
    required String messageId,
    required String senderJid,
  }) =>
      reactionsAccessor.selectByMessageAndSender(
        messageId: messageId,
        senderJid: senderJid,
      );

  @override
  Future<void> replaceReactions({
    required String messageId,
    required String senderJid,
    required List<String> emojis,
  }) async {
    await transaction(() async {
      await reactionsAccessor.deleteByMessageAndSender(
        messageId: messageId,
        senderJid: senderJid,
      );
      for (final emoji in emojis) {
        await into(reactions).insert(
          ReactionsCompanion.insert(
            messageID: messageId,
            senderJid: senderJid,
            emoji: emoji,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  @override
  Future<void> saveMessage(
    Message message, {
    ChatType chatType = ChatType.chat,
  }) async {
    _log.fine('Persisting message');
    final trimmedBody = message.body?.trim();
    final hasBody = trimmedBody?.isNotEmpty == true;
    final hasAttachment = message.fileMetadataID?.isNotEmpty == true;
    final lastMessagePreview = await _messagePreview(
      trimmedBody: trimmedBody,
      fileMetadataId: message.fileMetadataID,
      hasAttachment: hasAttachment,
      pseudoMessageType: message.pseudoMessageType,
      pseudoMessageData: message.pseudoMessageData,
    );
    final chatTitle = _chatTitleForIdentifier(message.chatJid);
    await transaction(() async {
      await into(chats).insert(
        ChatsCompanion.insert(
          jid: message.chatJid,
          title: chatTitle,
          type: chatType,
          unreadCount: Value((hasBody || hasAttachment).toBinary),
          lastMessage: Value.absentIfNull(lastMessagePreview),
          lastChangeTimestamp: DateTime.timestamp(),
          encryptionProtocol: Value(message.encryptionProtocol),
          contactJid:
              Value(chatType == ChatType.groupChat ? null : message.chatJid),
        ),
        onConflict: DoUpdate.withExcluded(
          (old, excluded) => ChatsCompanion.custom(
            type: excluded.type,
            unreadCount: const Constant(0).iif(
              old.open.isValue(true),
              old.unreadCount + Constant((hasBody || hasAttachment).toBinary),
            ),
            lastMessage: excluded.lastMessage,
            lastChangeTimestamp: excluded.lastChangeTimestamp,
          ),
        ),
      );
      BTBVTrustState? trust;
      bool? trusted;
      if (message.deviceID case final int deviceID) {
        final trustData = await omemoTrustsAccessor
            .selectOne(OmemoTrust(jid: message.senderJid, device: deviceID));
        trust = trustData?.state;
        trusted = trustData?.trusted;
      }
      final messageToSave = message.copyWith(
        trust: trust,
        trusted: trusted,
      );
      await messagesAccessor.insertOne(messageToSave);
      final persisted = await messagesAccessor.selectOne(message.stanzaID);
      if (persisted == null) {
        _log.warning(
          'Message insert ignored; retrying with upsert',
        );
        await into(messages).insertOnConflictUpdate(messageToSave);
      }
    });
  }

  Future<String?> _messagePreview({
    required String? trimmedBody,
    required String? fileMetadataId,
    required bool hasAttachment,
    required PseudoMessageType? pseudoMessageType,
    required Map<String, dynamic>? pseudoMessageData,
  }) async {
    const invitePrefix = 'axc-invite:';
    const inviteRevokePrefix = 'axc-invite-revoke:';
    if (pseudoMessageType == PseudoMessageType.mucInvite ||
        pseudoMessageType == PseudoMessageType.mucInviteRevocation) {
      return pseudoMessageType == PseudoMessageType.mucInvite
          ? 'You have been invited to a group chat'
          : 'Invite revoked';
    }

    if (trimmedBody?.isNotEmpty == true) {
      final lines = trimmedBody!.split('\n');
      final filtered = lines
          .where(
            (line) =>
                !line.trim().startsWith(invitePrefix) &&
                !line.trim().startsWith(inviteRevokePrefix),
          )
          .toList();
      final cleaned = filtered.join('\n').trim();
      if (cleaned.startsWith('Join ')) {
        final joinLine = cleaned.split('\n').first.trim();
        final withoutPrefix = joinLine.substring('Join '.length);
        final cutoffIndex = withoutPrefix.indexOf(' (');
        final extractedName = cutoffIndex == -1
            ? withoutPrefix.trim()
            : withoutPrefix.substring(0, cutoffIndex).trim();
        if (extractedName.isNotEmpty) {
          return extractedName;
        }
      }
      if (cleaned.isNotEmpty) return cleaned;
    }
    if (!hasAttachment) {
      return null;
    }
    if (fileMetadataId == null) {
      return 'Attachment';
    }
    final metadata = await fileMetadataAccessor.selectOne(fileMetadataId);
    if (metadata == null) {
      return 'Attachment';
    }
    final filename = metadata.filename.trim();
    if (filename.isEmpty) {
      return 'Attachment';
    }
    return 'Attachment: $filename';
  }

  @override
  Future<void> saveMessageError({
    required String stanzaID,
    required MessageError error,
  }) async {
    _log.info('Updating message error');
    await messagesAccessor.updateOne(MessagesCompanion(
      stanzaID: Value(stanzaID),
      error: Value(error),
    ));
  }

  @override
  Future<void> saveMessageDevice({
    required String stanzaID,
    required int deviceID,
    required String to,
  }) async {
    _log.info('Updating message device');
    await messagesAccessor.updateOne(MessagesCompanion(
      stanzaID: Value(stanzaID),
      deviceID: Value(deviceID),
      trusted: const Value(true),
    ));
  }

  @override
  Future<void> saveMessageEdit({
    required String stanzaID,
    required String? body,
  }) async {
    _log.fine('Editing message');
    await messagesAccessor.updateOne(MessagesCompanion(
      stanzaID: Value(stanzaID),
      edited: const Value(true),
      body: Value(body),
    ));
  }

  @override
  Future<void> updateMessageAttachment({
    required String stanzaID,
    FileMetadataData? metadata,
    String? body,
  }) async {
    await transaction(() async {
      if (metadata != null) {
        await saveFileMetadata(metadata);
      }
      await (update(messages)..where((tbl) => tbl.stanzaID.equals(stanzaID)))
          .write(
        MessagesCompanion(
          fileMetadataID:
              metadata != null ? Value(metadata.id) : const Value.absent(),
          body: body != null ? Value(body) : const Value.absent(),
        ),
      );
    });
  }

  @override
  Future<void> markMessageRetracted(String stanzaID) async {
    _log.info('Retracting message');
    await transaction(() async {
      final message = await (update(messages)
            ..where((messages) => messages.stanzaID.equals(stanzaID)))
          .writeReturning(const MessagesCompanion(
        retracted: Value(true),
        body: Value(null),
        fileMetadataID: Value(null),
        error: Value(MessageError.none),
        warning: Value(MessageWarning.none),
      ));
      if (message.firstOrNull?.fileMetadataID case final id?) {
        await fileMetadataAccessor.deleteOne(id);
      }
    });
  }

  @override
  Future<void> markMessageAcked(String stanzaID) async {
    _log.info('Marking message acked');
    await (update(messages)
          ..where(
            (tbl) =>
                tbl.stanzaID.equals(stanzaID) | tbl.originID.equals(stanzaID),
          ))
        .write(
      const MessagesCompanion(
        acked: Value(true),
      ),
    );
  }

  @override
  Future<void> markMessageReceived(String stanzaID) async {
    _log.info('Marking message received');
    await (update(messages)
          ..where(
            (tbl) =>
                tbl.stanzaID.equals(stanzaID) | tbl.originID.equals(stanzaID),
          ))
        .write(
      const MessagesCompanion(
        received: Value(true),
      ),
    );
  }

  @override
  Future<void> markMessageDisplayed(String stanzaID) async {
    _log.info('Marking message displayed');
    await (update(messages)
          ..where(
            (tbl) =>
                tbl.stanzaID.equals(stanzaID) | tbl.originID.equals(stanzaID),
          ))
        .write(
      const MessagesCompanion(
        displayed: Value(true),
      ),
    );
  }

  @override
  Future<void> deleteMessage(String stanzaID) async {
    _log.info('Deleting message');
    final existing = await messagesAccessor.selectOne(stanzaID);
    if (existing == null) return;
    await transaction(() async {
      await reactionsAccessor.deleteByMessage(stanzaID);
      await messagesAccessor.deleteOne(stanzaID);
      final chat = await getChat(existing.chatJid);
      if (chat == null) return;
      final lastMessage = await getLastMessageForChat(chat.jid);
      final lastMessagePreview = await _messagePreview(
        trimmedBody: lastMessage?.body?.trim(),
        fileMetadataId: lastMessage?.fileMetadataID,
        hasAttachment: lastMessage?.fileMetadataID?.isNotEmpty == true,
        pseudoMessageType: lastMessage?.pseudoMessageType,
        pseudoMessageData: lastMessage?.pseudoMessageData,
      );
      final String? trimmedBody = existing.body?.trim();
      final bool hasBody = trimmedBody?.isNotEmpty == true;
      final bool hasAttachment = existing.fileMetadataID?.isNotEmpty == true;
      final bool shouldDecrementUnread =
          (hasBody || hasAttachment) && !existing.displayed;
      final int nextUnreadCount = lastMessage == null
          ? 0
          : shouldDecrementUnread && chat.unreadCount > 0
              ? chat.unreadCount - 1
              : chat.unreadCount;
      await chatsAccessor.updateOne(chat.copyWith(
        lastMessage: lastMessagePreview,
        lastChangeTimestamp: lastMessage?.timestamp ?? chat.lastChangeTimestamp,
        unreadCount: nextUnreadCount,
      ));
    });
  }

  @override
  Future<void> clearMessageHistory() async {
    _log.info('Clearing message history...');
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        await delete(reactions).go();
        await delete(messageParticipants).go();
        await delete(messageCopies).go();
        await delete(messageShares).go();
        await delete(messages).go();
        await delete(drafts).go();
        await delete(fileMetadata).go();
        await delete(notifications).go();
        await (update(chats)).write(
          ChatsCompanion(
            lastMessage: const Value(null),
            unreadCount: const Value(0),
            lastChangeTimestamp: Value(DateTime.fromMillisecondsSinceEpoch(0)),
          ),
        );
      });
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  @override
  Future<void> trimChatMessages({
    required String jid,
    required int maxMessages,
  }) async {
    const int trimBatchSize = 900; // stays under SQLite's 999-variable limit
    Iterable<List<T>> chunked<T>(List<T> items) sync* {
      for (var index = 0; index < items.length; index += trimBatchSize) {
        final end = index + trimBatchSize;
        yield items.sublist(index, end > items.length ? items.length : end);
      }
    }

    final offset = maxMessages <= 0 ? 0 : maxMessages;
    final pruned = await customSelect(
      '''
      SELECT stanza_i_d AS stanza_id, delta_msg_id
      FROM messages
      WHERE chat_jid = ?
      ORDER BY timestamp DESC
      LIMIT -1 OFFSET ?
      ''',
      variables: [
        Variable<String>(jid),
        Variable<int>(offset),
      ],
      readsFrom: {messages},
    ).get();

    if (pruned.isEmpty) return;

    final stanzaIds = <String>[];
    final deltaMsgIds = <int>[];
    for (final row in pruned) {
      stanzaIds.add(row.read<String>('stanza_id'));
      final deltaMsgId = row.read<int?>('delta_msg_id');
      if (deltaMsgId != null) {
        deltaMsgIds.add(deltaMsgId);
      }
    }

    await transaction(() async {
      final shareIds = <String>{};
      if (deltaMsgIds.isNotEmpty) {
        for (final batch in chunked(deltaMsgIds)) {
          final copies = await (select(messageCopies)
                ..where((tbl) => tbl.dcMsgId.isIn(batch)))
              .get();
          shareIds.addAll(copies.map((copy) => copy.shareId));

          await (delete(messageCopies)..where((tbl) => tbl.dcMsgId.isIn(batch)))
              .go();
        }
      }

      if (stanzaIds.isNotEmpty) {
        for (final batch in chunked(stanzaIds)) {
          await (delete(reactions)..where((tbl) => tbl.messageID.isIn(batch)))
              .go();
        }
        for (final batch in chunked(stanzaIds)) {
          await (delete(messages)..where((tbl) => tbl.stanzaID.isIn(batch)))
              .go();
        }
      }

      if (shareIds.isNotEmpty) {
        final remainingShareIds = <String>{};
        final shareIdList = shareIds.toList(growable: false);
        for (final batch in chunked(shareIdList)) {
          final rows = await (selectOnly(messageCopies)
                ..addColumns([messageCopies.shareId])
                ..where(messageCopies.shareId.isIn(batch)))
              .get();
          remainingShareIds.addAll(
            rows
                .map((row) => row.read(messageCopies.shareId))
                .whereType<String>(),
          );
        }

        final expiredShares =
            shareIds.difference(remainingShareIds).toList(growable: false);
        if (expiredShares.isNotEmpty) {
          for (final batch in chunked(expiredShares)) {
            await (delete(messageParticipants)
                  ..where((tbl) => tbl.shareId.isIn(batch)))
                .go();
          }
          for (final batch in chunked(expiredShares)) {
            await (delete(messageShares)
                  ..where((tbl) => tbl.shareId.isIn(batch)))
                .go();
          }
        }
      }
    });
  }

  @override
  Future<void> createMessageShare({
    required MessageShareData share,
    required List<MessageParticipantData> participants,
  }) async {
    await transaction(() async {
      await messageSharesAccessor.insertOrUpdateOne(share);
      for (final participant in participants) {
        await messageParticipantsAccessor.insertOrUpdateOne(participant);
      }
    });
  }

  @override
  Future<void> insertMessageCopy({
    required String shareId,
    required int dcMsgId,
    required int dcChatId,
  }) async {
    await messageCopiesAccessor.insertOrUpdateOne(
      MessageCopiesCompanion.insert(
        shareId: shareId,
        dcMsgId: dcMsgId,
        dcChatId: dcChatId,
      ),
    );
  }

  @override
  Future<void> assignShareOriginator({
    required String shareId,
    required int originatorDcMsgId,
  }) =>
      messageSharesAccessor.updateOriginator(shareId, originatorDcMsgId);

  @override
  Future<void> saveMessageShareSubject({
    required String shareId,
    required String? subject,
  }) =>
      messageSharesAccessor.updateSubject(shareId, subject);

  @override
  Future<MessageShareData?> getMessageShareByToken(String token) =>
      messageSharesAccessor.selectByToken(token);

  @override
  Future<MessageShareData?> getMessageShareById(String shareId) =>
      messageSharesAccessor.selectOne(shareId);

  @override
  Future<List<MessageParticipantData>> getParticipantsForShare(
          String shareId) =>
      messageParticipantsAccessor.selectByShare(shareId);

  @override
  Future<List<MessageCopyData>> getMessageCopiesForShare(String shareId) =>
      messageCopiesAccessor.selectByShare(shareId);

  @override
  Future<List<Message>> getMessagesForShare(String shareId) async {
    final copies = await messageCopiesAccessor.selectByShare(shareId);
    if (copies.isEmpty) return const [];
    final messageIds = copies
        .map((copy) => copy.dcMsgId)
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    if (messageIds.isEmpty) return const [];
    final query = select(messages)
      ..where((tbl) => tbl.deltaMsgId.isIn(messageIds));
    return query.get();
  }

  @override
  Future<String?> getShareIdForDeltaMessage(int deltaMsgId) =>
      messageCopiesAccessor.selectShareIdForDeltaMsg(deltaMsgId);

  @override
  Future<void> removeChatMessages(String jid) =>
      trimChatMessages(jid: jid, maxMessages: 0);

  @override
  Stream<List<Draft>> watchDrafts({required int start, required int end}) {
    return draftsAccessor.watchAll();
  }

  @override
  Future<List<Draft>> getDrafts({required int start, required int end}) {
    return draftsAccessor.selectAll();
  }

  @override
  Future<Draft?> getDraft(int id) => draftsAccessor.selectOne(id);

  @override
  Future<int> saveDraft({
    int? id,
    required List<String> jids,
    required String body,
    String? subject,
    List<String> attachmentMetadataIds = const [],
  }) =>
      draftsAccessor.insertOrUpdateOne(DraftsCompanion(
        id: Value.absentIfNull(id),
        jids: Value(jids),
        body: Value(body),
        subject: Value.absentIfNull(subject),
        attachmentMetadataIds: Value(attachmentMetadataIds),
      ));

  @override
  Future<void> removeDraft(int id) => draftsAccessor.deleteOne(id);

  @override
  Future<OmemoDevice?> getOmemoDevice(String jid) =>
      omemoDevicesAccessor.selectOne(jid);

  @override
  Future<void> saveOmemoDevice(OmemoDevice device) async {
    _log.info('Saving OMEMO device');
    await omemoDevicesAccessor.insertOrUpdateOne(await device.toDb());
  }

  @override
  Future<void> deleteOmemoDevice(String jid) async {
    await (delete(omemoDevices)..where((t) => t.jid.equals(jid))).go();
  }

  @override
  Future<OmemoDeviceList?> getOmemoDeviceList(String jid) =>
      omemoDeviceListsAccessor.selectOne(jid);

  @override
  Future<void> saveOmemoDeviceList(OmemoDeviceList data) =>
      omemoDeviceListsAccessor.insertOrUpdateOne(data);

  @override
  Future<void> deleteOmemoDeviceList(String jid) async {
    await (delete(omemoDeviceLists)..where((t) => t.jid.equals(jid))).go();
  }

  @override
  Future<List<OmemoTrust>> getOmemoTrusts(String jid) =>
      omemoTrustsAccessor.selectByJid(jid);

  @override
  Future<List<OmemoTrust>> getAllOmemoTrusts() => select(omemoTrusts).get();

  @override
  Future<OmemoTrust?> getOmemoTrust(String jid, int device) =>
      omemoTrustsAccessor.selectOne(OmemoTrust(jid: jid, device: device));

  @override
  Future<void> setOmemoTrust(OmemoTrust trust) async {
    await transaction(() async {
      await messagesAccessor.updateTrust(
        trust.device,
        trust.state,
        trust.trusted,
      );
      return omemoTrustsAccessor.insertOrUpdateOne(OmemoTrust(
        device: trust.device,
        jid: trust.jid,
        trust: trust.state,
        enabled: trust.enabled,
        trusted: trust.trusted,
      ));
    });
  }

  @override
  Future<void> setOmemoTrustLabel({
    required String jid,
    required int device,
    required String? label,
  }) =>
      omemoTrustsAccessor.updateOne(OmemoTrustsCompanion(
        device: Value(device),
        jid: Value(jid),
        label: Value(label),
      ));

  @override
  Future<void> resetOmemoTrust(String jid) async {
    await transaction(() async {
      final trusts = await (delete(omemoTrusts)
            ..where((table) => table.jid.equals(jid)))
          .goAndReturn();
      for (final trust in trusts) {
        await messagesAccessor.updateTrust(
          trust.device,
          trust.state,
          trust.trusted,
        );
      }
    });
  }

  @override
  Future<List<OmemoRatchet>> getOmemoRatchets(String jid) =>
      omemoRatchetsAccessor.selectByJid(jid);

  @override
  Future<void> saveOmemoRatchet(OmemoRatchet ratchet) async {
    await omemoRatchetsAccessor.insertOrUpdateOne(ratchet.toDb());
  }

  @override
  Future<void> saveOmemoRatchets(List<OmemoRatchet> ratchets) async {
    await transaction(() async {
      for (final ratchet in ratchets) {
        await omemoRatchetsAccessor.insertOrUpdateOne(ratchet.toDb());
      }
    });
  }

  @override
  Future<void> removeOmemoRatchets(List<(String, int)> ratchets) async {
    await transaction(() async {
      for (final (jid, deviceID) in ratchets) {
        await (delete(omemoRatchets)
              ..where((omemoRatchets) =>
                  omemoRatchets.jid.equals(jid) &
                  omemoRatchets.device.equals(deviceID)))
            .go();
      }
    });
  }

  @override
  Future<OmemoBundleCache?> getOmemoBundleCache(String jid, int device) =>
      omemoBundleCachesAccessor.selectByKey(jid, device);

  @override
  Future<void> saveOmemoBundleCache(OmemoBundleCache cache) async {
    await omemoBundleCachesAccessor.insertOrUpdateOne(cache.toDb());
  }

  @override
  Future<void> removeOmemoBundleCache(String jid, int device) async {
    await omemoBundleCachesAccessor.deleteOne((jid, device));
  }

  @override
  Future<void> clearOmemoBundleCache() async {
    await omemoBundleCachesAccessor.clear();
  }

  @override
  Future<DateTime?> getLastPreKeyRotationTime(String jid) async {
    // For now, we'll store this in the omemo_devices table
    // You may want to add a dedicated column or table for this
    // TODO: Add lastPreKeyRotation column to omemo_devices table
    // For now, return null to indicate no rotation time stored
    return null;
  }

  @override
  Future<void> setLastPreKeyRotationTime(String jid, DateTime time) async {
    // TODO: Add lastPreKeyRotation column to omemo_devices table
    // For now, this is a no-op
    // You'll need to update the database schema to properly store this
  }

  @override
  Future<void> saveFileMetadata(FileMetadataData metadata) async {
    await fileMetadataAccessor.insertOrUpdateOne(metadata);
  }

  @override
  Future<FileMetadataData?> getFileMetadata(String id) =>
      fileMetadataAccessor.selectOne(id);

  @override
  Stream<FileMetadataData?> watchFileMetadata(String id) =>
      fileMetadataAccessor.watchOne(id);

  @override
  Future<void> deleteFileMetadata(String id) async {
    await fileMetadataAccessor.deleteOne(id);
  }

  @override
  Stream<List<Chat>> watchChats({required int start, required int end}) {
    return chatsAccessor.watchAll();
  }

  @override
  Future<List<Chat>> getChats({required int start, required int end}) {
    return chatsAccessor.selectAll();
  }

  @override
  Future<Chat?> getChat(String jid) => chatsAccessor.selectOne(jid);

  @override
  Future<Chat?> getChatByDeltaChatId(int deltaChatId) {
    return (select(chats)..where((tbl) => tbl.deltaChatId.equals(deltaChatId)))
        .getSingleOrNull();
  }

  @override
  Stream<Chat?> watchChatByDeltaChatId(int deltaChatId) {
    return (select(chats)..where((tbl) => tbl.deltaChatId.equals(deltaChatId)))
        .watchSingleOrNull();
  }

  @override
  Future<void> createChat(Chat chat) async {
    final lastMessage = await getLastMessageForChat(chat.jid);
    final lastMessagePreview = await _messagePreview(
      trimmedBody: lastMessage?.body?.trim(),
      fileMetadataId: lastMessage?.fileMetadataID,
      hasAttachment: lastMessage?.fileMetadataID?.isNotEmpty == true,
      pseudoMessageType: lastMessage?.pseudoMessageType,
      pseudoMessageData: lastMessage?.pseudoMessageData,
    );

    return await chatsAccessor.insertOne(chat.copyWith(
      lastMessage: lastMessagePreview,
      lastChangeTimestamp: lastMessage?.timestamp ?? chat.lastChangeTimestamp,
    ));
  }

  @override
  Future<void> updateChat(Chat chat) => chatsAccessor.updateOne(chat);

  @override
  Stream<Chat?> watchChat(String jid) {
    return chatsAccessor.watchOne(jid);
  }

  @override
  Future<Chat?> openChat(String jid) async {
    final lastMessage = await getLastMessageForChat(jid);
    final lastMessagePreview = await _messagePreview(
      trimmedBody: lastMessage?.body?.trim(),
      fileMetadataId: lastMessage?.fileMetadataID,
      hasAttachment: lastMessage?.fileMetadataID?.isNotEmpty == true,
      pseudoMessageType: lastMessage?.pseudoMessageType,
      pseudoMessageData: lastMessage?.pseudoMessageData,
    );

    return await transaction(() async {
      final closed = await closeChat();
      await into(chats).insert(
        ChatsCompanion.insert(
          jid: jid,
          title: _chatTitleForIdentifier(jid),
          type: ChatType.chat,
          open: const Value(true),
          unreadCount: const Value(0),
          chatState: const Value(mox.ChatState.active),
          lastMessage: Value(lastMessagePreview),
          lastChangeTimestamp: lastMessage?.timestamp ?? DateTime.timestamp(),
          contactJid: Value(jid),
        ),
        onConflict: DoUpdate(
          (old) => const ChatsCompanion(
            open: Value(true),
            unreadCount: Value(0),
            chatState: Value(mox.ChatState.active),
          ),
        ),
      );
      return closed;
    });
  }

  @override
  Future<Chat?> closeChat() async =>
      (await chatsAccessor.closeOpen()).firstOrNull;

  @override
  Future<void> markChatMuted({
    required String jid,
    required bool muted,
  }) async {
    _log.info('Updating chat muted state');
    await (update(chats)..where((chats) => chats.jid.equals(jid)))
        .write(ChatsCompanion(muted: Value(muted)));
  }

  @override
  Future<void> setChatShareSignature({
    required String jid,
    required bool enabled,
  }) async {
    _log.info('Updating chat share signature');
    await (update(chats)..where((chats) => chats.jid.equals(jid))).write(
      ChatsCompanion(shareSignatureEnabled: Value(enabled)),
    );
  }

  @override
  Future<void> markChatFavorited({
    required String jid,
    required bool favorited,
  }) async {
    _log.info('Updating chat favorite state');
    await (update(chats)..where((chats) => chats.jid.equals(jid)))
        .write(ChatsCompanion(favorited: Value(favorited)));
  }

  @override
  Future<void> markChatArchived({
    required String jid,
    required bool archived,
  }) async {
    _log.info('Updating chat archived state');
    await transaction(() async {
      final chat = await chatsAccessor.selectOne(jid);
      if (chat == null) return;
      if (!archived) {
        await (update(chats)..where((tbl) => tbl.jid.equals(jid))).write(
          const ChatsCompanion(archived: Value(false)),
        );
        return;
      }
      if (chat.archived) {
        return;
      }
      final canonicalJid = chat.contactJid ?? chat.jid;
      final archivedJid = _generateArchivedJid(canonicalJid);
      await _archiveChatThread(
        chat: chat,
        canonicalJid: canonicalJid,
        archivedJid: archivedJid,
      );
      await _retargetDraftsForChat(fromJid: jid, toJid: archivedJid);
    });
  }

  String _generateArchivedJid(String canonicalJid) {
    final timestamp = DateTime.timestamp().microsecondsSinceEpoch;
    return '$canonicalJid--arch--${timestamp.toRadixString(16)}';
  }

  Future<void> _archiveChatThread({
    required Chat chat,
    required String canonicalJid,
    required String archivedJid,
  }) async {
    final archivedChat = chat.copyWith(
      jid: archivedJid,
      contactJid: canonicalJid,
      archived: true,
      open: false,
    );
    await chatsAccessor.insertOne(archivedChat);
    await (update(messages)..where((tbl) => tbl.chatJid.equals(chat.jid)))
        .write(
      MessagesCompanion(chatJid: Value(archivedJid)),
    );
    await (update(notifications)..where((tbl) => tbl.chatJid.equals(chat.jid)))
        .write(NotificationsCompanion(chatJid: Value(archivedJid)));
    await (delete(chats)..where((tbl) => tbl.jid.equals(chat.jid))).go();
  }

  Future<void> _retargetDraftsForChat({
    required String fromJid,
    required String toJid,
  }) async {
    final impactedDrafts = await draftsAccessor.selectAll();
    for (final draft in impactedDrafts) {
      if (!draft.jids.contains(fromJid)) continue;
      final updated = [
        for (final jid in draft.jids) jid == fromJid ? toJid : jid,
      ];
      if (listEquals(updated, draft.jids)) continue;
      await draftsAccessor.updateOne(
        DraftsCompanion(
          id: Value(draft.id),
          jids: Value(updated),
        ),
      );
    }
  }

  @override
  Future<void> markChatHidden({
    required String jid,
    required bool hidden,
  }) async {
    _log.info('Updating chat hidden state');
    await (update(chats)..where((chats) => chats.jid.equals(jid)))
        .write(ChatsCompanion(hidden: Value(hidden)));
  }

  @override
  Future<void> markChatSpam({
    required String jid,
    required bool spam,
  }) async {
    await (update(chats)..where((tbl) => tbl.jid.equals(jid)))
        .write(ChatsCompanion(spam: Value(spam)));
  }

  @override
  Future<void> updateChatAvatar({
    required String jid,
    required String? avatarPath,
    required String? avatarHash,
  }) async {
    await (update(chats)
          ..where((tbl) => tbl.jid.equals(jid) | tbl.contactJid.equals(jid)))
        .write(
      ChatsCompanion(
        avatarPath: Value(avatarPath),
        avatarHash: Value(avatarHash),
      ),
    );
  }

  @override
  Future<void> markChatMarkerResponsive({
    required String jid,
    required bool responsive,
  }) async {
    _log.info('Updating chat marker responsiveness');
    await (update(chats)..where((chats) => chats.jid.equals(jid)))
        .write(ChatsCompanion(markerResponsive: Value(responsive)));
  }

  @override
  Future<void> markChatsMarkerResponsive({required bool responsive}) async {
    _log.info('Updating marker responsiveness for all chats');
    await (update(chats))
        .write(ChatsCompanion(markerResponsive: Value(responsive)));
  }

  @override
  Future<void> updateChatState({
    required String chatJid,
    required mox.ChatState state,
  }) async {
    _log.info('Updating chat state');
    await chatsAccessor.updateOne(ChatsCompanion(
      jid: Value(chatJid),
      chatState: Value(state),
    ));
  }

  @override
  Future<void> updateChatAlert({
    required String chatJid,
    required String? alert,
  }) async {
    _log.info('Updating chat alert');
    await chatsAccessor.updateOne(ChatsCompanion(
      jid: Value(chatJid),
      alert: Value(alert),
    ));
  }

  @override
  Future<void> updateChatEncryption({
    required String chatJid,
    required EncryptionProtocol protocol,
  }) async {
    _log.info('Updating chat encryption protocol');
    await chatsAccessor.updateOne(ChatsCompanion(
      jid: Value(chatJid),
      encryptionProtocol: Value(protocol),
    ));
  }

  @override
  Future<void> removeChat(String jid) {
    return chatsAccessor.deleteOne(jid);
  }

  @override
  Stream<List<RosterItem>> watchRoster({required int start, required int end}) {
    return rosterAccessor.watchAll();
  }

  @override
  Future<List<RosterItem>> getRoster() async {
    _log.info('Loading roster from database...');
    return await rosterAccessor.selectAll();
  }

  @override
  Future<RosterItem?> getRosterItem(String jid) async {
    return rosterAccessor.selectOne(jid);
  }

  @override
  Future<void> saveRosterItem(RosterItem item) async {
    _log.info('Saving roster item');
    await transaction(() async {
      await createChat(Chat.fromJid(item.jid));
      await rosterAccessor.insertOrUpdateOne(item);
      await invitesAccessor.deleteOne(item.jid);
    });
  }

  @override
  Future<void> saveRosterItems(List<RosterItem> items) async {
    await transaction(() async {
      for (final item in items) {
        _log.info('Saving roster item');
        await createChat(Chat.fromJid(item.jid));
        await rosterAccessor.insertOrUpdateOne(item);
        await invitesAccessor.deleteOne(item.jid);
      }
    });
  }

  @override
  Future<void> updateRosterItem(RosterItem item) async {
    _log.info('Updating roster item');
    await transaction(() async {
      await rosterAccessor.updateOne(item);
      await invitesAccessor.deleteOne(item.jid);
    });
  }

  @override
  Future<void> updateRosterItems(List<RosterItem> items) async {
    await transaction(() async {
      for (final item in items) {
        _log.info('Updating roster item');
        await rosterAccessor.updateOne(item);
        await invitesAccessor.deleteOne(item.jid);
      }
    });
  }

  @override
  Future<void> removeRosterItem(String jid) async {
    _log.info('Removing roster item');
    await transaction(() async {
      await rosterAccessor.deleteOne(jid);
      await chatsAccessor.deleteOne(jid);
    });
  }

  @override
  Future<void> removeRosterItems(List<String> jids) async {
    await transaction(() async {
      for (final jid in jids) {
        _log.info('Removing roster item');
        await rosterAccessor.deleteOne(jid);
        await chatsAccessor.deleteOne(jid);
      }
    });
  }

  @override
  Future<void> updatePresence({
    required String jid,
    required Presence presence,
    String? status,
  }) async {
    _log.info('Updating presence');
    await rosterAccessor.updateOne(RosterCompanion(
      jid: Value(jid),
      presence: Value(presence),
      status: Value(status),
    ));
  }

  @override
  Future<void> updateRosterSubscription({
    required String jid,
    required Subscription subscription,
  }) async {
    _log.info('Updating roster subscription');
    await rosterAccessor.updateOne(
      RosterCompanion(
        jid: Value(jid),
        subscription: Value(subscription),
      ),
    );
  }

  @override
  Future<void> updateRosterAsk({
    required String jid,
    Ask? ask,
  }) async {
    _log.info('Updating roster ask state');
    await rosterAccessor.updateOne(
      RosterCompanion(
        jid: Value(jid),
        ask: Value(ask),
      ),
    );
  }

  @override
  Future<void> updateRosterAvatar({
    required String jid,
    required String? avatarPath,
    required String? avatarHash,
  }) async {
    await rosterAccessor.updateOne(
      RosterCompanion(
        jid: Value(jid),
        avatarPath: Value(avatarPath),
        avatarHash: Value(avatarHash),
      ),
    );
  }

  @override
  Future<void> markSubscriptionBoth(String jid) async {
    _log.info('Marking roster subscription as mutual');
    await transaction(() async {
      await rosterAccessor.updateOne(RosterCompanion(
        jid: Value(jid),
        subscription: const Value(Subscription.both),
      ));
      await invitesAccessor.deleteOne(jid);
    });
  }

  @override
  Stream<List<Invite>> watchInvites({required int start, required int end}) {
    _log.info('Loading invites from database...');
    return invitesAccessor.watchAll();
  }

  @override
  Future<List<Invite>> getInvites(
      {required int start, required int end}) async {
    return await invitesAccessor.selectAll();
  }

  @override
  Future<void> saveInvite(Invite invite) async {
    _log.info('Saving invite');
    await invitesAccessor.insertOne(invite);
  }

  @override
  Future<void> deleteInvite(String jid) async {
    _log.info('Deleting invite');
    await invitesAccessor.deleteOne(jid);
  }

  @override
  Stream<List<BlocklistData>> watchBlocklist({
    required int start,
    required int end,
  }) {
    return blocklistAccessor.watchAll();
  }

  @override
  Future<List<BlocklistData>> getBlocklist({
    required int start,
    required int end,
  }) {
    return blocklistAccessor.selectAll();
  }

  @override
  Future<void> blockJid(String jid) async {
    _log.info('Adding to blocklist');
    await blocklistAccessor.insertOne(BlocklistCompanion(jid: Value(jid)));
  }

  @override
  Future<void> blockJids(List<String> jids) async {
    await transaction(() async {
      for (final jid in jids) {
        _log.info('Adding to blocklist');
        await blocklistAccessor.insertOne(BlocklistCompanion(jid: Value(jid)));
      }
    });
  }

  @override
  Future<void> unblockJid(String jid) async {
    _log.info('Removing from blocklist');
    await blocklistAccessor.deleteOne(jid);
  }

  @override
  Future<void> unblockJids(List<String> jids) async {
    await transaction(() async {
      for (final jid in jids) {
        _log.info('Removing from blocklist');
        await blocklistAccessor.deleteOne(jid);
      }
    });
  }

  @override
  Future<void> replaceBlocklist(List<String> blocks) async {
    _log.info('Replacing blocklist...');
    await transaction(() async {
      await blocklistAccessor.deleteAll();
      for (final blocked in blocks) {
        await blocklistAccessor.insertOne(BlocklistData(jid: blocked));
      }
    });
  }

  @override
  Future<void> deleteBlocklist() async {
    _log.info('Deleting blocklist...');
    await blocklistAccessor.deleteAll();
  }

  @override
  Stream<List<EmailBlocklistEntry>> watchEmailBlocklist() =>
      emailBlocklistAccessor.watchEntries();

  @override
  Future<List<EmailBlocklistEntry>> getEmailBlocklist() =>
      emailBlocklistAccessor.selectEntries();

  @override
  Future<void> addEmailBlock(String address) async {
    final normalized = _normalizeEmail(address);
    if (normalized.isEmpty) {
      return;
    }
    await emailBlocklistAccessor.insertOrUpdateOne(
      EmailBlocklistCompanion.insert(address: normalized),
    );
  }

  @override
  Future<void> removeEmailBlock(String address) async {
    final normalized = _normalizeEmail(address);
    if (normalized.isEmpty) {
      return;
    }
    await emailBlocklistAccessor.deleteOne(normalized);
  }

  @override
  Future<bool> isEmailAddressBlocked(String address) async {
    final normalized = _normalizeEmail(address);
    if (normalized.isEmpty) {
      return false;
    }
    final existing = await emailBlocklistAccessor.selectOne(normalized);
    return existing != null;
  }

  @override
  Future<void> incrementEmailBlockCount(String address) async {
    final normalized = _normalizeEmail(address);
    if (normalized.isEmpty) {
      return;
    }
    await customStatement(
      '''
INSERT INTO email_blocklist(address, blocked_message_count, last_blocked_message_at)
VALUES(?, 1, CURRENT_TIMESTAMP)
ON CONFLICT(address) DO UPDATE SET
  blocked_message_count = blocked_message_count + 1,
  last_blocked_message_at = excluded.last_blocked_message_at
''',
      [normalized],
    );
  }

  @override
  Stream<List<EmailSpamEntry>> watchEmailSpamlist() =>
      emailSpamlistAccessor.watchEntries();

  @override
  Future<void> addEmailSpam(String address) async {
    final normalized = _normalizeEmail(address);
    if (normalized.isEmpty) {
      return;
    }
    await emailSpamlistAccessor.insertOrUpdateOne(
      EmailSpamlistCompanion.insert(address: normalized),
    );
  }

  @override
  Future<void> removeEmailSpam(String address) async {
    final normalized = _normalizeEmail(address);
    if (normalized.isEmpty) {
      return;
    }
    await emailSpamlistAccessor.deleteOne(normalized);
  }

  @override
  Future<bool> isEmailAddressSpam(String address) async {
    final normalized = _normalizeEmail(address);
    if (normalized.isEmpty) {
      return false;
    }
    final existing = await emailSpamlistAccessor.selectOne(normalized);
    return existing != null;
  }

  @override
  Stream<List<DayEventEntry>> watchDayEvents({
    required DateTime start,
    required DateTime end,
  }) {
    final DateTime normalizedStart = _normalizeDate(start);
    final DateTime normalizedEnd = _normalizeDate(end);
    return dayEventsAccessor.watchRange(normalizedStart, normalizedEnd);
  }

  @override
  Future<List<DayEventEntry>> getDayEvents({
    required DateTime start,
    required DateTime end,
  }) {
    final DateTime normalizedStart = _normalizeDate(start);
    final DateTime normalizedEnd = _normalizeDate(end);
    return dayEventsAccessor.selectRange(normalizedStart, normalizedEnd);
  }

  @override
  Future<DayEventEntry?> getDayEvent(String id) =>
      dayEventsAccessor.selectOne(id);

  @override
  Future<void> saveDayEvent(DayEventEntry entry) =>
      dayEventsAccessor.insertOrUpdateOne(entry);

  @override
  Future<void> deleteDayEvent(String id) => dayEventsAccessor.deleteOne(id);

  @override
  Future<void> replaceDayEvents(Iterable<DayEventEntry> entries) =>
      dayEventsAccessor.replaceAll(entries.toList(growable: false));

  Future<void> _rebuildMessagesTable(Migrator m) async {
    final tableName = messages.actualTableName;
    final tempTableName = '${tableName}_old';
    const columnNames = <String>[
      'id',
      'stanza_i_d',
      'origin_i_d',
      'occupant_i_d',
      'sender_jid',
      'chat_jid',
      'body',
      'timestamp',
      'error',
      'warning',
      'encryption_protocol',
      'trust',
      'trusted',
      'device_i_d',
      'no_store',
      'acked',
      'received',
      'displayed',
      'edited',
      'retracted',
      'is_file_upload_notification',
      'file_downloading',
      'file_uploading',
      'file_metadata_i_d',
      'quoting',
      'sticker_pack_i_d',
      'pseudo_message_type',
      'pseudo_message_data',
      'delta_chat_id',
      'delta_msg_id',
    ];
    final columnList = columnNames.map((c) => '"$c"').join(', ');
    final tableExists = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(tableName)],
    ).get();
    if (tableExists.isEmpty) {
      await m.createTable(messages);
      return;
    }
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await customStatement('DROP TABLE IF EXISTS "$tempTableName"');
      await customStatement(
        'ALTER TABLE "$tableName" RENAME TO "$tempTableName"',
      );
      await m.createTable(messages);
      await customStatement(
        'INSERT INTO "$tableName" ($columnList) '
        'SELECT $columnList FROM "$tempTableName"',
      );
      await customStatement('DROP TABLE "$tempTableName"');
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _mergeEmailChats() async {
    final emailChats = await (select(chats)
          ..where((tbl) => tbl.emailAddress.isNotNull()))
        .get();
    final canonical = <String, Chat>{};
    for (final chat in emailChats) {
      final email = chat.emailAddress;
      if (email == null || email.trim().isEmpty) {
        continue;
      }
      final normalized = _normalizeEmail(email);
      if (normalized.isEmpty) {
        continue;
      }
      if (chat.jid == normalized && !canonical.containsKey(normalized)) {
        canonical[normalized] = chat;
      }
    }
    for (final chat in emailChats) {
      final email = chat.emailAddress;
      if (email == null || email.trim().isEmpty) {
        continue;
      }
      final normalized = _normalizeEmail(email);
      if (normalized.isEmpty || chat.jid == normalized) {
        continue;
      }
      final target = canonical[normalized];
      if (target != null) {
        await (update(messages)..where((tbl) => tbl.chatJid.equals(chat.jid)))
            .write(MessagesCompanion(chatJid: Value(normalized)));
        await (update(messageParticipants)
              ..where((tbl) => tbl.contactJid.equals(chat.jid)))
            .write(
          MessageParticipantsCompanion(contactJid: Value(normalized)),
        );
        await (update(notifications)
              ..where((tbl) => tbl.chatJid.equals(chat.jid)))
            .write(
          NotificationsCompanion(chatJid: Value(normalized)),
        );
        final merged = target.copyWith(
          deltaChatId: chat.deltaChatId ?? target.deltaChatId,
          emailAddress: chat.emailAddress ?? target.emailAddress,
          contactDisplayName:
              target.contactDisplayName ?? chat.contactDisplayName,
          contactID: target.contactID ?? chat.contactID,
        );
        await (update(chats)..where((tbl) => tbl.jid.equals(target.jid))).write(
          ChatsCompanion(
            deltaChatId: Value(merged.deltaChatId),
            emailAddress: Value(merged.emailAddress),
            contactDisplayName: Value(merged.contactDisplayName),
            contactID: Value(merged.contactID),
          ),
        );
        await (delete(chats)..where((tbl) => tbl.jid.equals(chat.jid))).go();
      } else {
        await (update(messages)..where((tbl) => tbl.chatJid.equals(chat.jid)))
            .write(MessagesCompanion(chatJid: Value(normalized)));
        await (update(messageParticipants)
              ..where((tbl) => tbl.contactJid.equals(chat.jid)))
            .write(
          MessageParticipantsCompanion(contactJid: Value(normalized)),
        );
        await (update(notifications)
              ..where((tbl) => tbl.chatJid.equals(chat.jid)))
            .write(
          NotificationsCompanion(chatJid: Value(normalized)),
        );
        await (update(chats)..where((tbl) => tbl.jid.equals(chat.jid))).write(
          ChatsCompanion(
            jid: Value(normalized),
            contactJid: Value(normalized),
          ),
        );
        canonical[normalized] = chat.copyWith(
          jid: normalized,
          contactJid: normalized,
        );
      }
    }
  }

  @override
  Future<void> deleteAll() async {
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        for (final table in allTables) {
          await delete(table).go();
        }
      });
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  @override
  Future<void> close() async {
    await super.close();
    _inMemory ? _inMemoryInstance = null : _instance = null;
  }

  @override
  Future<void> deleteFile() =>
      _inMemory || _file.path.isEmpty ? Future.value() : _file.delete();
}

QueryExecutor _openDatabase(File file, String passphrase) {
  return LazyDatabase(() async {
    final token = RootIsolateToken.instance!;
    if (kDebugMode) {
      // await file.delete();
    }
    return NativeDatabase.createInBackground(
      file,
      isolateSetup: () async {
        BackgroundIsolateBinaryMessenger.ensureInitialized(token);
        await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
        open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
        // ..overrideFor(OperatingSystem.linux,
        //     () => DynamicLibrary.open('libsqlcipher.so'))
        // ..overrideFor(OperatingSystem.windows,
        //     () => DynamicLibrary.open('sqlcipher.dll'));
      },
      setup: (rawDb) {
        final result = rawDb.select('PRAGMA cipher_version');
        if (result.isEmpty) {
          throw UnsupportedError('SQLCipher library unavailable');
        }

        // This will be used with PBKDF2 to get the actual key.
        final escapedKey = passphrase.replaceAll("'", "''");
        rawDb.execute("PRAGMA key = '$escapedKey'");
      },
    );
  });
}

QueryExecutor _openInMemoryDatabase() {
  return LazyDatabase(() async {
    return NativeDatabase.memory();
  });
}

Future<File> dbFileFor(String prefix) async {
  final path = (await getApplicationDocumentsDirectory()).path;
  return File(p.join(path, '$prefix.axichat.drift'));
}

String _escapeLikePattern(String input) {
  return input
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

typedef HashFunction = mox.HashFunction;
