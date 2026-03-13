// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

// ignore_for_file: avoid_renaming_method_parameters

import 'dart:convert';
import 'dart:io';

import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/utils/calendar_snapshot_metadata.dart';
import 'package:axichat/src/chat/util/chat_subject_codec.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/anti_abuse_sync.dart';
import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:axichat/src/common/transport.dart';
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

import 'package:axichat/src/storage/models.dart';

part 'database.g.dart';

abstract interface class Database {
  /// Must be idempotent.
  Future<void> close();
}

const String _databaseFileSuffix = '.axichat.drift';
const int _messageAttachmentMaxCount = 50;
const int _emptyTimestampMillis = 0;
const String _messageStatusSyncEnvelopeKey = 'message_status_sync';

class MessageDeltaSnapshot {
  const MessageDeltaSnapshot({
    required this.stanzaId,
    required this.deltaMsgId,
    required this.displayed,
  });

  final String stanzaId;
  final int? deltaMsgId;
  final bool displayed;
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

  Future<List<Message>> getChatMessagesBefore(
    String jid, {
    required DateTime beforeTimestamp,
    required String beforeStanzaId,
    int? beforeDeltaMsgId,
    required int limit,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  });

  Future<int> countChatMessages(
    String jid, {
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    bool includePseudoMessages = true,
  });

  Future<int> countChatMessagesThrough(
    String jid, {
    required DateTime throughTimestamp,
    required String throughStanzaId,
    int? throughDeltaMsgId,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  });

  Stream<int> watchConversationMessageCount();

  Future<int> getConversationMessageCount();

  Future<List<Message>> getAllMessagesForChat(
    String jid, {
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  });

  Future<Message?> getLastMessageForChat(
    String jid, {
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  });

  Future<List<MessageDeltaSnapshot>> getMessageDeltaSnapshot(String jid);

  Future<void> deleteMessagesByStanzaIds(Iterable<String> stanzaIds);

  Future<List<Message>> getPendingOutgoingDeltaMessages({
    required int deltaAccountId,
    required int deltaChatId,
  });

  Future<List<Message>> searchChatMessages({
    required String jid,
    String? query,
    String? subject,
    bool excludeSubject = false,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    String? collectionId,
    int limit,
    bool ascending,
  });

  Future<List<String>> subjectsForChat(String jid);

  Future<Message?> getMessageByStanzaID(String stanzaID);

  Future<Message?> getMessageByOriginID(String originID, {String? chatJid});

  Future<Message?> getMessageByReferenceId(String messageId, {String? chatJid});

  Future<Message?> getMessageByDeltaId(
    int deltaMsgId, {
    int? deltaAccountId,
    String? chatJid,
  });

  Future<List<Message>> getMessagesByDeltaIds(
    Iterable<int> deltaMsgIds, {
    int? deltaAccountId,
    String? chatJid,
  });

  Future<List<Message>> getMessagesByStanzaIds(Iterable<String> stanzaIds);

  Future<List<Message>> getMessagesByReferenceIds(
    Iterable<String> messageIds, {
    String? chatJid,
  });

  Stream<List<Reaction>> watchReactionsForChat(String jid);

  Future<List<Reaction>> getReactionsForChat(String jid);

  Stream<List<Reaction>> watchReactionsForMessages(Iterable<String> messageIds);

  Future<List<Reaction>> getReactionsForMessages(Iterable<String> messageIds);

  Future<List<Reaction>> getReactionsForMessageSender({
    required String messageId,
    required String senderJid,
  });

  Future<ReactionState?> getReactionState({
    required String messageId,
    required String senderJid,
  });

  Future<void> clearReactionsForMessageSender({
    required String messageId,
    required String senderJid,
  });

  Future<void> replaceReactions({
    required String messageId,
    required String senderJid,
    required List<String> emojis,
    required DateTime updatedAt,
    required bool identityVerified,
  });

  Future<void> saveMessage(
    Message message, {
    ChatType chatType = ChatType.chat,
    String? selfJid,
  });

  Future<void> updateMessage(Message message);

  Future<int> countUnreadMessagesForChat(String jid, {String? selfJid});

  Future<void> saveMessageMucStanzaId({
    required String stanzaID,
    required String mucStanzaId,
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

  Future<void> addMessageAttachment({
    required String messageId,
    required String fileMetadataId,
    String? transportGroupId,
    int? sortOrder,
  });

  Future<void> replaceMessageAttachments({
    required String messageId,
    required List<String> fileMetadataIds,
    String? transportGroupId,
  });

  Future<List<MessageAttachmentData>> getMessageAttachments(String messageId);

  Future<Map<String, List<MessageAttachmentData>>>
  getMessageAttachmentsForMessages(Iterable<String> messageIds);

  Future<List<MessageAttachmentData>> getMessageAttachmentsForGroup(
    String transportGroupId,
  );

  Future<List<String>> deleteMessageAttachments(String messageId);

  Future<void> seedSystemMessageCollections();

  Stream<List<MessageCollectionMembershipEntry>>
  watchMessageCollectionMemberships(String collectionId, {String? chatJid});

  Future<List<MessageCollectionMembershipEntry>>
  getMessageCollectionMemberships(
    String collectionId, {
    String? chatJid,
    bool includeInactive = false,
  });
  Future<List<MessageCollectionMembershipEntry>>
  getAllMessageCollectionMemberships({bool includeInactive = false});

  Future<MessageCollectionMembershipEntry?> getMessageCollectionMembership({
    required String collectionId,
    required String chatJid,
    required String messageReferenceId,
  });

  Future<void> applyMessageCollectionMembershipMutation({
    required String collectionId,
    required String chatJid,
    required String messageReferenceId,
    required String? messageStanzaId,
    required String? messageOriginId,
    required String? messageMucStanzaId,
    required int? deltaAccountId,
    required int? deltaMsgId,
    required DateTime addedAt,
    required bool active,
  });

  Future<void> normalizeMessageCollectionMembershipAliases({
    required String collectionId,
    required String chatJid,
    required String canonicalMessageReferenceId,
    required Iterable<String> aliases,
    required String? messageStanzaId,
    required String? messageOriginId,
    required String? messageMucStanzaId,
    required int? deltaAccountId,
    required int? deltaMsgId,
  });

  Stream<List<PinnedMessageEntry>> watchPinnedMessages(String chatJid);

  Future<List<PinnedMessageEntry>> getPinnedMessages(String chatJid);

  Future<PinnedMessageEntry?> getPinnedMessage({
    required String chatJid,
    required String messageStanzaId,
  });

  Future<void> upsertPinnedMessage(PinnedMessageEntry entry);

  Future<void> applyPinnedMessageMutation({
    required String chatJid,
    required String messageStanzaId,
    required DateTime pinnedAt,
    required bool active,
  });

  Future<void> normalizePinnedMessageAliases({
    required String chatJid,
    required String canonicalMessageStanzaId,
    required Iterable<String> aliases,
  });

  Future<void> deletePinnedMessage({
    required String chatJid,
    required String messageStanzaId,
  });

  Future<void> markMessageRetracted(String stanzaID);

  Future<void> markMessageAcked(String stanzaID, {String? chatJid});

  Future<void> markMessageReceived(String stanzaID, {String? chatJid});

  Future<void> markMessageDisplayed(String stanzaID, {String? chatJid});

  Future<void> markOutgoingMessagesDisplayedThrough({
    required String messageId,
    required String chatJid,
    required String senderJid,
  });

  Future<void> deleteMessage(String stanzaID);

  Future<void> replaceDeltaPlaceholderSelfJids({
    required int deltaAccountId,
    required String resolvedAddress,
    required List<String> placeholderJids,
  });

  Future<void> removeDeltaPlaceholderDuplicates({
    required int deltaAccountId,
    required List<String> placeholderJids,
  });

  Future<void> clearMessageHistory();

  Future<void> trimChatMessages({
    required String jid,
    required int maxMessages,
    int? deltaAccountId,
  });

  Future<void> createMessageShare({
    required MessageShareData share,
    required List<MessageParticipantData> participants,
  });

  Future<void> insertMessageCopy({
    required String shareId,
    required int dcMsgId,
    required int dcChatId,
    int dcAccountId = DeltaAccountDefaults.legacyId,
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

  Future<String?> getShareIdForDeltaMessage(
    int deltaMsgId, {
    int deltaAccountId = DeltaAccountDefaults.legacyId,
  });

  Future<void> removeChatMessages(String jid);

  Stream<List<Draft>> watchDrafts({required int start, required int end});

  Future<List<Draft>> getDrafts({required int start, required int end});

  Future<int> countDrafts();

  Future<Draft?> getDraft(int id);

  Future<Draft?> getDraftBySyncId(String syncId);

  Future<int> saveDraft({
    int? id,
    required List<String> jids,
    required String body,
    required String draftSyncId,
    required DateTime draftUpdatedAt,
    required String draftSourceId,
    required List<DraftRecipientData> draftRecipients,
    String? subject,
    String? quotingStanzaId,
    MessageReferenceKind? quotingReferenceKind,
    List<String> attachmentMetadataIds = const [],
  });

  Future<void> updateDraftSyncMetadata({
    required int id,
    required String draftSyncId,
    required DateTime draftUpdatedAt,
    required String draftSourceId,
  });

  Future<int> upsertDraftFromSync({
    required String draftSyncId,
    required List<String> jids,
    required DateTime draftUpdatedAt,
    required String draftSourceId,
    required List<DraftRecipientData> draftRecipients,
    String? body,
    String? subject,
    String? quotingStanzaId,
    MessageReferenceKind? quotingReferenceKind,
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

  Future<List<FileMetadataData>> getFileMetadataForIds(Iterable<String> ids);

  Stream<FileMetadataData?> watchFileMetadata(String id);

  Future<void> deleteFileMetadata(String id);

  Stream<List<Chat>> watchChats({required int start, required int end});

  Future<List<Chat>> getChats({required int start, required int end});

  Future<List<Chat>> getChatsByJids(Iterable<String> jids);

  Future<List<Chat>> getDeltaChats({int? accountId});

  Stream<List<String>> watchRecipientAddressSuggestions({int? limit});

  Future<List<String>> getRecipientAddressSuggestions({int? limit});

  Future<Chat?> getChat(String jid);

  Future<Chat?> getOpenChat();

  Future<Chat?> getChatByDeltaChatId(int deltaChatId, {int? accountId});

  Stream<Chat?> watchChatByDeltaChatId(int deltaChatId, {int? accountId});

  Future<void> upsertEmailChatAccount({
    required String chatJid,
    required int deltaAccountId,
    required int deltaChatId,
  });

  Future<int?> getDeltaChatIdForAccount({
    required String chatJid,
    required int deltaAccountId,
  });

  Future<void> deleteEmailChatAccount({
    required String chatJid,
    required int deltaAccountId,
  });

  Future<void> deleteEmailChatAccountsForAccount(int deltaAccountId);

  Future<int> countEmailChatAccounts(String chatJid);

  Future<void> createChat(Chat chat);

  Future<void> updateChat(Chat chat);

  Future<void> updateConversationIndexChatMeta({
    required String jid,
    required DateTime lastChangeTimestamp,
    required bool muted,
    required bool favorited,
    required bool archived,
    required String contactJid,
  });

  Future<void> updateConversationIndexArchived({
    required String jid,
    required bool archived,
  });

  Future<void> repairChatSummaryPreservingTimestamp(String jid);

  Future<void> clearChatsEmailFromAddress(String address);

  Stream<Chat?> watchChat(String jid);

  Future<Chat?> openChat(String jid);

  Future<Chat?> closeChat();

  Future<void> markChatMuted({required String jid, required bool muted});

  Future<void> setChatNotificationPreviewSetting({
    required String jid,
    required NotificationPreviewSetting? setting,
  });

  Future<void> setChatShareSignature({
    required String jid,
    required bool? enabled,
  });

  Future<void> setChatAttachmentAutoDownload({
    required String jid,
    required AttachmentAutoDownload? value,
  });

  Future<void> markChatFavorited({
    required String jid,
    required bool favorited,
  });

  Future<void> markChatArchived({required String jid, required bool archived});

  Future<void> markChatHidden({required String jid, required bool hidden});

  Future<void> markChatSpam({
    required String jid,
    required bool spam,
    DateTime? spamUpdatedAt,
  });

  Future<void> markEmailChatsSpam({
    required String address,
    required bool spam,
    DateTime? spamUpdatedAt,
  });

  Future<void> markChatMarkerResponsive({
    required String jid,
    required bool? responsive,
  });

  Future<void> updateChatAvatar({
    required String jid,
    required String? avatarPath,
    required String? avatarHash,
  });

  Future<void> clearAvatarReferencesForPath({required String path});

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

  Future<void> updateRosterAsk({required String jid, Ask? ask});

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

  Future<bool> isJidBlocked(String jid);

  Future<void> blockJid(String jid);

  Future<void> blockJids(List<String> jids);

  Future<void> unblockJid(String jid);

  Future<void> unblockJids(List<String> jids);

  Future<void> replaceBlocklist(List<String> blocks);

  Future<void> deleteBlocklist();

  Future<void> replaceContacts(Map<String, String> contactsByNativeId);

  Stream<List<EmailBlocklistEntry>> watchEmailBlocklist();

  Future<List<EmailBlocklistEntry>> getEmailBlocklist();

  Future<EmailBlocklistEntry?> getEmailBlocklistEntry(String address);

  Future<void> addEmailBlock(
    String address, {
    DateTime? blockedAt,
    String? sourceId,
  });

  Future<void> removeEmailBlock(String address);

  Future<bool> isEmailAddressBlocked(String address);

  Future<void> incrementEmailBlockCount(String address);

  Stream<List<EmailSpamEntry>> watchEmailSpamlist();

  Future<List<EmailSpamEntry>> getEmailSpamlist();

  Future<EmailSpamEntry?> getEmailSpamEntry(String address);

  Future<void> addEmailSpam(
    String address, {
    DateTime? flaggedAt,
    String? sourceId,
  });

  Future<void> removeEmailSpam(String address);

  Future<bool> isEmailAddressSpam(String address);

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
              ),
            ])
            ..limit(limit))
          .watch();

  Future<List<Message>> selectChatMessages(String jid) =>
      (select(table)
            ..where((table) => table.chatJid.equals(jid))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.timestamp,
                mode: OrderingMode.desc,
              ),
            ]))
          .get();

  @override
  Future<Message?> selectOne(String stanzaID) => (select(
    table,
  )..where((table) => table.stanzaID.equals(stanzaID))).getSingleOrNull();

  Future<Message?> selectOneByOriginID(String originID) => (select(
    table,
  )..where((table) => table.originID.equals(originID))).getSingleOrNull();

  Future<Message?> selectOneByMucStanzaId(
    String mucStanzaId, {
    String? chatJid,
  }) {
    final query = select(table)
      ..where((tbl) => tbl.mucStanzaId.equals(mucStanzaId));
    final normalizedChatJid = chatJid?.trim();
    if (normalizedChatJid != null && normalizedChatJid.isNotEmpty) {
      query.where((tbl) => tbl.chatJid.equals(normalizedChatJid));
    }
    return query.getSingleOrNull();
  }

  Future<void> updateTrust(int device, BTBVTrustState trust, bool trusted) =>
      (update(table)..where((table) => table.deviceID.equals(device))).write(
        MessagesCompanion(trust: Value(trust)),
      );

  @override
  Future<void> deleteOne(String stanzaID) =>
      (delete(table)..where((item) => item.stanzaID.equals(stanzaID))).go();

  Future<void> deleteChatMessages(String jid) =>
      (delete(table)..where((item) => item.chatJid.equals(jid))).go();
}

@DriftAccessor(tables: [MessageAttachments])
class MessageAttachmentsAccessor
    extends BaseAccessor<MessageAttachmentData, $MessageAttachmentsTable>
    with _$MessageAttachmentsAccessorMixin {
  MessageAttachmentsAccessor(super.attachedDatabase);

  @override
  $MessageAttachmentsTable get table => messageAttachments;

  @override
  Future<MessageAttachmentData?> selectOne(Object value) => (select(
    table,
  )..where((tbl) => tbl.id.equals(value as int))).getSingleOrNull();

  Future<List<MessageAttachmentData>> selectForMessage(String messageId) =>
      (select(table)
            ..where((tbl) => tbl.messageId.equals(messageId))
            ..orderBy([
              (tbl) => OrderingTerm(
                expression: tbl.sortOrder,
                mode: OrderingMode.asc,
              ),
            ]))
          .get();

  Future<List<MessageAttachmentData>> selectForMessages(
    Iterable<String> messageIds,
  ) {
    final ids = messageIds.toList(growable: false);
    if (ids.isEmpty) return Future.value(const []);
    return (select(table)
          ..where((tbl) => tbl.messageId.isIn(ids))
          ..orderBy([
            (tbl) =>
                OrderingTerm(expression: tbl.sortOrder, mode: OrderingMode.asc),
          ]))
        .get();
  }

  Future<void> deleteForMessages(Iterable<String> messageIds) {
    final ids = messageIds.toList(growable: false);
    if (ids.isEmpty) return Future.value();
    return (delete(table)..where((tbl) => tbl.messageId.isIn(ids))).go();
  }

  Future<List<MessageAttachmentData>> selectForGroup(String transportGroupId) =>
      (select(table)
            ..where((tbl) => tbl.transportGroupId.equals(transportGroupId))
            ..orderBy([
              (tbl) => OrderingTerm(
                expression: tbl.sortOrder,
                mode: OrderingMode.asc,
              ),
            ]))
          .get();

  Future<int> nextSortOrder(String messageId) async {
    final query = selectOnly(table)
      ..addColumns([table.sortOrder.max()])
      ..where(table.messageId.equals(messageId));
    final row = await query.getSingleOrNull();
    final maxOrder = row?.read(table.sortOrder.max()) ?? -1;
    return maxOrder + 1;
  }

  @override
  Future<void> deleteOne(Object value) =>
      (delete(table)..where((tbl) => tbl.id.equals(value as int))).go();

  Future<void> deleteForMessage(String messageId) =>
      (delete(table)..where((tbl) => tbl.messageId.equals(messageId))).go();
}

@DriftAccessor(tables: [MessageShares])
class MessageSharesAccessor
    extends BaseAccessor<MessageShareData, $MessageSharesTable>
    with _$MessageSharesAccessorMixin {
  MessageSharesAccessor(super.attachedDatabase);

  @override
  $MessageSharesTable get table => messageShares;

  @override
  Future<MessageShareData?> selectOne(String shareId) => (select(
    table,
  )..where((tbl) => tbl.shareId.equals(shareId))).getSingleOrNull();

  Future<MessageShareData?> selectByToken(String token) => (select(
    table,
  )..where((tbl) => tbl.subjectToken.equals(token))).getSingleOrNull();

  Future<void> updateOriginator(String shareId, int originatorDcMsgId) =>
      (update(table)..where((tbl) => tbl.shareId.equals(shareId))).write(
        MessageSharesCompanion(originatorDcMsgId: Value(originatorDcMsgId)),
      );

  Future<void> updateSubject(String shareId, String? subject) =>
      (update(table)..where((tbl) => tbl.shareId.equals(shareId))).write(
        MessageSharesCompanion(subject: Value(subject)),
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
      (select(table)..where(
            (tbl) => tbl.shareId.equals(key.$1) & tbl.contactJid.equals(key.$2),
          ))
          .getSingleOrNull();

  @override
  Future<void> deleteOne((String, String) key) =>
      (delete(table)..where(
            (tbl) => tbl.shareId.equals(key.$1) & tbl.contactJid.equals(key.$2),
          ))
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

  Future<MessageCopyData?> selectByDeltaMsgId(
    int deltaMsgId, {
    int deltaAccountId = DeltaAccountDefaults.legacyId,
  }) =>
      (select(table)..where(
            (tbl) =>
                tbl.dcMsgId.equals(deltaMsgId) &
                tbl.dcAccountId.equals(deltaAccountId),
          ))
          .getSingleOrNull();

  Future<String?> selectShareIdForDeltaMsg(
    int deltaMsgId, {
    int deltaAccountId = DeltaAccountDefaults.legacyId,
  }) async => (await selectByDeltaMsgId(
    deltaMsgId,
    deltaAccountId: deltaAccountId,
  ))?.shareId;

  Future<List<MessageCopyData>> selectByShare(String shareId) =>
      (select(table)..where((tbl) => tbl.shareId.equals(shareId))).get();
}

@DriftAccessor(tables: [Reactions, ReactionStates, Messages])
class ReactionsAccessor extends DatabaseAccessor<XmppDrift>
    with _$ReactionsAccessorMixin {
  ReactionsAccessor(super.attachedDatabase);

  Stream<List<Reaction>> watchChat(String jid) {
    final query = select(reactions).join([
      innerJoin(messages, messages.stanzaID.equalsExp(reactions.messageID)),
    ])..where(messages.chatJid.equals(jid));
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(reactions)).toList(),
    );
  }

  Future<List<Reaction>> selectByChat(String jid) {
    final query = select(reactions).join([
      innerJoin(messages, messages.stanzaID.equalsExp(reactions.messageID)),
    ])..where(messages.chatJid.equals(jid));
    return _mapReactions(query);
  }

  Future<List<Reaction>> _mapReactions(
    JoinedSelectStatement<HasResultSet, dynamic> query,
  ) async {
    final rows = await query.get();
    return rows.map((row) => row.readTable(reactions)).toList();
  }

  Future<List<Reaction>> selectByMessageAndSender({
    required String messageId,
    required String senderJid,
  }) =>
      (select(reactions)..where(
            (table) =>
                table.messageID.equals(messageId) &
                table.senderJid.equals(senderJid),
          ))
          .get();

  Future<void> deleteByMessage(String messageId) => (delete(
    reactions,
  )..where((table) => table.messageID.equals(messageId))).go();

  Future<void> deleteByMessages(Iterable<String> messageIds) => (delete(
    reactions,
  )..where((table) => table.messageID.isIn(messageIds))).go();

  Future<void> deleteByMessageAndSender({
    required String messageId,
    required String senderJid,
  }) =>
      (delete(reactions)..where(
            (table) =>
                table.messageID.equals(messageId) &
                table.senderJid.equals(senderJid),
          ))
          .go();

  Future<ReactionState?> selectStateByMessageAndSender({
    required String messageId,
    required String senderJid,
  }) =>
      (select(reactionStates)..where(
            (table) =>
                table.messageID.equals(messageId) &
                table.senderJid.equals(senderJid),
          ))
          .getSingleOrNull();

  Future<void> deleteStateByMessageAndSender({
    required String messageId,
    required String senderJid,
  }) =>
      (delete(reactionStates)..where(
            (table) =>
                table.messageID.equals(messageId) &
                table.senderJid.equals(senderJid),
          ))
          .go();

  Future<void> upsertState({
    required String messageId,
    required String senderJid,
    required DateTime updatedAt,
    required bool identityVerified,
  }) => into(reactionStates).insertOnConflictUpdate(
    ReactionStatesCompanion.insert(
      messageID: messageId,
      senderJid: senderJid,
      updatedAt: updatedAt.toUtc(),
      identityVerified: Value(identityVerified),
    ),
  );

  Future<void> deleteStatesByMessage(String messageId) => (delete(
    reactionStates,
  )..where((table) => table.messageID.equals(messageId))).go();

  Future<void> deleteStatesByMessages(Iterable<String> messageIds) => (delete(
    reactionStates,
  )..where((table) => table.messageID.isIn(messageIds))).go();
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
  Future<OmemoDevice?> selectOne(String value) => (select(
    table,
  )..where((table) => table.jid.equals(value))).getSingleOrNull();

  Future<OmemoDevice?> selectByID(int value) => (select(
    table,
  )..where((table) => table.id.equals(value))).getSingleOrNull();

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
  Future<OmemoDeviceList?> selectOne(String value) => (select(
    table,
  )..where((table) => table.jid.equals(value))).getSingleOrNull();

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
  Future<OmemoRatchet?> selectOne((String, int) key) =>
      (select(table)..where(
            (table) => table.jid.equals(key.$1) & table.device.equals(key.$2),
          ))
          .getSingleOrNull();

  Future<List<OmemoRatchet>> selectByJid(String jid) =>
      (select(table)..where((table) => table.jid.equals(jid))).get();

  @override
  Future<void> deleteOne((String, int) key) =>
      (delete(table)..where(
            (table) => table.jid.equals(key.$1) & table.device.equals(key.$2),
          ))
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
  Future<OmemoBundleCache?> selectOne((String, int) key) =>
      (select(
            table,
          )..where((tbl) => tbl.jid.equals(key.$1) & tbl.device.equals(key.$2)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne((String, int) key) => (delete(
    table,
  )..where((tbl) => tbl.jid.equals(key.$1) & tbl.device.equals(key.$2))).go();

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
  Future<FileMetadataData?> selectOne(Object value) => (select(
    table,
  )..where((table) => table.id.equals(value as String))).getSingleOrNull();

  Future<List<FileMetadataData>> selectForIds(List<String> ids) {
    final normalizedIds = _normalizedUniqueIds(ids);
    if (normalizedIds.isEmpty) return Future.value(const []);
    const maxInClauseItems = 900;
    if (normalizedIds.length <= maxInClauseItems) {
      return (select(
        table,
      )..where((table) => table.id.isIn(normalizedIds))).get();
    }
    return _selectForIdsChunked(
      ids: normalizedIds,
      chunkSize: maxInClauseItems,
    );
  }

  Stream<List<FileMetadataData>> watchForIds(List<String> ids) {
    final normalizedIds = _normalizedUniqueIds(ids);
    if (normalizedIds.isEmpty) {
      return Stream.value(const <FileMetadataData>[]);
    }
    const maxInClauseItems = 900;
    if (normalizedIds.length <= maxInClauseItems) {
      return (select(
        table,
      )..where((table) => table.id.isIn(normalizedIds))).watch();
    }
    final trackedIds = normalizedIds.toSet();
    return select(table).watch().map(
      (rows) => rows
          .where((row) => trackedIds.contains(row.id))
          .toList(growable: false),
    );
  }

  Stream<FileMetadataData?> watchOne(String id) => (select(
    table,
  )..where((table) => table.id.equals(id))).watchSingleOrNull();

  Future<FileMetadataData?> selectOneByPlaintextHashes(
    Map<HashFunction, String> hashes,
  ) =>
      (select(table)
            ..where((table) => table.plainTextHashes.equalsValue(hashes)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne(String id) =>
      (delete(table)..where((item) => item.id.equals(id))).go();

  List<String> _normalizedUniqueIds(List<String> ids) {
    if (ids.isEmpty) {
      return const <String>[];
    }
    final seen = <String>{};
    final normalized = <String>[];
    for (final rawId in ids) {
      final id = rawId.trim();
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      normalized.add(id);
    }
    return normalized;
  }

  Future<List<FileMetadataData>> _selectForIdsChunked({
    required List<String> ids,
    required int chunkSize,
  }) async {
    final byId = <String, FileMetadataData>{};
    var start = 0;
    while (start < ids.length) {
      final end = start + chunkSize < ids.length
          ? start + chunkSize
          : ids.length;
      final chunk = ids.sublist(start, end);
      final rows = await (select(
        table,
      )..where((table) => table.id.isIn(chunk))).get();
      for (final metadata in rows) {
        byId[metadata.id] = metadata;
      }
      start = end;
    }
    final ordered = <FileMetadataData>[];
    for (final id in ids) {
      final metadata = byId[id];
      if (metadata != null) {
        ordered.add(metadata);
      }
    }
    return ordered;
  }
}

@DriftAccessor(tables: [Chats])
class ChatsAccessor extends BaseAccessor<Chat, $ChatsTable>
    with _$ChatsAccessorMixin {
  ChatsAccessor(super.attachedDatabase);

  @override
  $ChatsTable get table => chats;

  @override
  Stream<List<Chat>> watchAll() =>
      (select(table)..orderBy([
            (t) =>
                OrderingTerm(expression: t.favorited, mode: OrderingMode.desc),
            (t) => OrderingTerm(
              expression: t.lastChangeTimestamp,
              mode: OrderingMode.desc,
            ),
          ]))
          .watch();

  Stream<Chat?> watchOne(String jid) => (select(
    table,
  )..where((table) => table.jid.equals(jid))).watchSingleOrNull();

  @override
  Future<Chat?> selectOne(String value) => (select(
    table,
  )..where((table) => table.jid.equals(value))).getSingleOrNull();

  Future<List<Chat>> selectForJids(List<String> jids) {
    if (jids.isEmpty) return Future.value(const []);
    return (select(table)..where((table) => table.jid.isIn(jids))).get();
  }

  Future<Chat?> selectOpen() => (select(
    table,
  )..where((table) => table.open.equals(true))).getSingleOrNull();

  Future<List<Chat>> closeOpen() =>
      (update(table)..where((table) => table.open.equals(true))).writeReturning(
        const ChatsCompanion(
          open: Value(false),
          chatState: Value(mox.ChatState.gone),
        ),
      );

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
  Future<RosterItem?> selectOne(String value) => (select(
    table,
  )..where((table) => table.jid.equals(value))).getSingleOrNull();

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
  Future<Invite?> selectOne(String value) => (select(
    table,
  )..where((table) => table.jid.equals(value))).getSingleOrNull();

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
  Future<BlocklistData?> selectOne(String value) => (select(
    table,
  )..where((table) => table.jid.equals(value))).getSingleOrNull();

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
  Future<EmailBlocklistEntry?> selectOne(String address) => (select(
    table,
  )..where((tbl) => tbl.address.equals(address))).getSingleOrNull();

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
  Future<EmailSpamEntry?> selectOne(String address) => (select(
    table,
  )..where((tbl) => tbl.address.equals(address))).getSingleOrNull();

  @override
  Future<void> deleteOne(String address) =>
      (delete(table)..where((tbl) => tbl.address.equals(address))).go();

  Stream<List<EmailSpamEntry>> watchEntries() => select(table).watch();

  Future<List<EmailSpamEntry>> selectEntries() => select(table).get();
}

@DriftDatabase(
  tables: [
    Messages,
    MessageCollections,
    MessageCollectionMemberships,
    PinnedMessages,
    MessageAttachments,
    MessageShares,
    MessageParticipants,
    MessageCopies,
    Drafts,
    DraftAttachmentRefs,
    OmemoDevices,
    OmemoTrusts,
    OmemoDeviceLists,
    OmemoRatchets,
    OmemoBundleCaches,
    Reactions,
    ReactionStates,
    Notifications,
    FileMetadata,
    Roster,
    Invites,
    Chats,
    RecipientAddresses,
    EmailChatAccounts,
    Contacts,
    Blocklist,
    Stickers,
    StickerPacks,
    EmailBlocklist,
    EmailSpamlist,
  ],
  daos: [
    MessagesAccessor,
    MessageAttachmentsAccessor,
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
  ],
)
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
  }) => _instance ??= XmppDrift._(
    file,
    executor ?? _openDatabase(file, passphrase),
  );

  final _log = Logger('XmppDrift');
  final File _file;
  final bool _inMemory;

  bool get isInMemory => _inMemory;
  String _normalizeEmail(String address) =>
      normalizedAddressValueOrEmpty(address);
  String? _normalizeBlocklistJid(String jid) {
    final normalized = normalizedAddressKey(jid);
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    final trimmed = jid.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.toLowerCase();
  }

  String _chatTitleForIdentifier(String identifier, {String? selfJid}) {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) {
      return identifier;
    }
    if (sameNormalizedAddressValue(trimmed, selfJid)) {
      return 'Saved Messages';
    }
    try {
      return addressDisplayLabel(trimmed) ?? mox.JID.fromString(trimmed).local;
    } catch (_) {
      return trimmed;
    }
  }

  @override
  int get schemaVersion => 36;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _createMessageSearchInfrastructure();
        await _createRecipientAddressTriggers();
        await seedSystemMessageCollections();
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
          await customStatement('''
CREATE TABLE drafts_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  jids TEXT NOT NULL,
  body TEXT,
  attachment_metadata_ids TEXT NOT NULL DEFAULT '[]'
)
''');
          await customStatement('''
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
''');
          await customStatement('DROP TABLE drafts');
          await customStatement('ALTER TABLE drafts_new RENAME TO drafts');
        }
        if (rebuildReactions) {
          await m.createTable(reactions);
        }
        if (from < 9) {
          await customStatement('''
UPDATE message_shares
SET subject_token = UPPER(share_id)
WHERE subject_token IS NOT NULL
''');
          await customStatement('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_message_shares_subject_token
ON message_shares(subject_token)
WHERE subject_token IS NOT NULL
''');
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
        // Version 15 originally created dayEvents table, but we've removed it.
        // Version 16 drops the table if it exists (silently for users who never had it).
        if (from < 16) {
          await customStatement('DROP TABLE IF EXISTS day_events');
        }
        if (from < 17) {
          await m.addColumn(messages, messages.htmlBody);
        }
        if (from < 18) {
          await m.createTable(messageAttachments);
          await customStatement('''
INSERT INTO message_attachments(message_id, file_metadata_id, sort_order)
SELECT id, file_metadata_i_d, 0
FROM messages
WHERE file_metadata_i_d IS NOT NULL
  AND trim(file_metadata_i_d) != ''
''');
        }
        if (from < 19) {
          const draftSyncIdSql = "lower(hex(randomblob(16)))";
          const draftSyncIdUpdateSql =
              '''
UPDATE drafts
SET draft_sync_id = $draftSyncIdSql
WHERE draft_sync_id IS NULL OR trim(draft_sync_id) = ''
''';
          const draftUpdatedAtUpdateSql = '''
UPDATE drafts
SET draft_updated_at = CURRENT_TIMESTAMP
WHERE draft_updated_at IS NULL
''';
          const draftSourceIdUpdateSql = '''
UPDATE drafts
SET draft_source_id = ?
WHERE draft_source_id IS NULL OR trim(draft_source_id) = ''
''';
          await m.addColumn(drafts, drafts.draftSyncId);
          await m.addColumn(drafts, drafts.draftUpdatedAt);
          await m.addColumn(drafts, drafts.draftSourceId);
          await customStatement(draftSyncIdUpdateSql);
          await customStatement(draftUpdatedAtUpdateSql);
          await customStatement(draftSourceIdUpdateSql, [
            DraftDefaults.sourceLegacyId,
          ]);
        }
        if (from < 20) {
          await m.addColumn(drafts, drafts.draftRecipients);
        }
        if (from < 21) {
          await m.addColumn(chats, chats.attachmentAutoDownload);
        }
        if (from < 22) {
          await m.addColumn(chats, chats.spamUpdatedAt);
          await m.addColumn(blocklist, blocklist.blockedAt);
          await m.addColumn(emailBlocklist, emailBlocklist.sourceId);
          await m.addColumn(emailSpamlist, emailSpamlist.sourceId);
          await customStatement('''
UPDATE chats
SET spam_updated_at = last_change_timestamp
WHERE spam = 1 AND spam_updated_at IS NULL
''');
          await customStatement('''
UPDATE blocklist
SET blocked_at = CURRENT_TIMESTAMP
WHERE blocked_at IS NULL
''');
          await customStatement(
            '''
UPDATE email_blocklist
SET source_id = ?
WHERE source_id IS NULL OR trim(source_id) = ''
''',
            [syncLegacySourceId],
          );
          await customStatement('''
UPDATE email_blocklist
SET blocked_at = CURRENT_TIMESTAMP
WHERE blocked_at IS NULL
''');
          await customStatement(
            '''
UPDATE email_spamlist
SET source_id = ?
WHERE source_id IS NULL OR trim(source_id) = ''
''',
            [syncLegacySourceId],
          );
        }
        if (from < 24) {
          await m.addColumn(chats, chats.notificationPreviewSetting);
        }
        if (from < 25) {
          await m.addColumn(messages, messages.deltaAccountId);
          await _rebuildMessageCopiesTable(m);
        }
        if (from < 26) {
          await m.addColumn(chats, chats.emailFromAddress);
          await m.createTable(emailChatAccounts);
          await customStatement(
            '''
INSERT INTO email_chat_accounts(chat_jid, delta_account_id, delta_chat_id)
SELECT jid, ?, delta_chat_id
FROM chats
WHERE delta_chat_id IS NOT NULL
''',
            [DeltaAccountDefaults.legacyId],
          );
        }
        if (from < 27) {
          await m.addColumn(drafts, drafts.quotingStanzaId);
        }
        if (from < 28) {
          await _rebuildChatsTable(m);
        }
        if (from < 29) {
          await m.createTable(draftAttachmentRefs);
          await m.createTable(recipientAddresses);
          await m.createIndex(
            Index('idx_messages_chat_timestamp', 'chat_jid, timestamp'),
          );
          await m.createIndex(
            Index('idx_chats_last_change', 'last_change_timestamp'),
          );
          await _createMessageSearchInfrastructure();
          await _createRecipientAddressTriggers();
          await _backfillRecipientAddresses();
          await _backfillDraftAttachmentRefs();
        }
        if (from < 30) {
          await m.addColumn(chats, chats.transport);
          await customStatement('''
UPDATE chats
SET transport = ${MessageTransport.email.index}
WHERE transport IS NULL
  AND (delta_chat_id IS NOT NULL
    OR email_address IS NOT NULL
    OR email_from_address IS NOT NULL)
''');
          await customStatement('''
UPDATE chats
SET transport = ${MessageTransport.xmpp.index}
WHERE transport IS NULL
''');
        }
        if (from < 28) {
          await m.createTable(pinnedMessages);
        }
        if (from < 31) {
          await m.addColumn(pinnedMessages, pinnedMessages.active);
        }
        if (from < 32 &&
            !await _tableHasColumn(messages.actualTableName, 'muc_stanza_id')) {
          await m.addColumn(messages, messages.mucStanzaId);
        }
        if (from < 33 &&
            !await _tableHasColumn(
              messages.actualTableName,
              'quoting_reference_kind',
            )) {
          await customStatement(
            'ALTER TABLE ${messages.actualTableName} '
            'ADD COLUMN quoting_reference_kind INTEGER NULL',
          );
        }
        if (from < 34 &&
            !await _tableHasColumn(
              drafts.actualTableName,
              'quoting_reference_kind',
            )) {
          await customStatement(
            'ALTER TABLE ${drafts.actualTableName} '
            'ADD COLUMN quoting_reference_kind INTEGER NULL',
          );
        }
        if (from < 35) {
          await m.createTable(reactionStates);
        }
        if (from < 36) {
          await m.createTable(messageCollections);
          await m.createTable(messageCollectionMemberships);
          await seedSystemMessageCollections();
        }
      },
      beforeOpen: (_) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  @override
  Future<void> seedSystemMessageCollections() async {
    final now = DateTime.timestamp().toUtc();
    final collections = <MessageCollectionEntry>[
      MessageCollectionEntry(
        id: SystemMessageCollection.important.id,
        title: null,
        isSystem: true,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
        active: true,
      ),
    ];
    for (final entry in collections) {
      await into(messageCollections).insertOnConflictUpdate(entry);
    }
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
  Future<List<Message>> getChatMessagesBefore(
    String jid, {
    required DateTime beforeTimestamp,
    required String beforeStanzaId,
    int? beforeDeltaMsgId,
    required int limit,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) {
    return _chatMessagesBeforeSelectable(
      jid: jid,
      filter: filter,
      limit: limit,
      beforeTimestamp: beforeTimestamp,
      beforeStanzaId: beforeStanzaId,
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
      LEFT JOIN message_copies mc
        ON mc.dc_msg_id = m.delta_msg_id
       AND mc.dc_account_id = m.delta_account_id
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
      readsFrom: {messages, messageCopies, messageShares, messageParticipants},
    ).getSingle();

    return query.read<int>('count');
  }

  @override
  Future<int> countChatMessagesThrough(
    String jid, {
    required DateTime throughTimestamp,
    required String throughStanzaId,
    int? throughDeltaMsgId,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    final filterValue = filter.index;
    final query = await customSelect(
      '''
      SELECT COUNT(*) AS count
      FROM messages m
      LEFT JOIN message_copies mc
        ON mc.dc_msg_id = m.delta_msg_id
       AND mc.dc_account_id = m.delta_account_id
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
        AND (
          m.timestamp > ?
          OR (
            m.timestamp = ?
            AND m.rowid >= COALESCE(
              (SELECT rowid FROM messages WHERE stanza_i_d = ?),
              9223372036854775807
            )
          )
        )
      ''',
      variables: [
        Variable<String>(jid),
        Variable<String>(jid),
        Variable<int>(filterValue),
        Variable<DateTime>(throughTimestamp),
        Variable<DateTime>(throughTimestamp),
        Variable<String>(throughStanzaId),
      ],
      readsFrom: {messages, messageCopies, messageShares, messageParticipants},
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
      LEFT JOIN message_copies mc
        ON mc.dc_msg_id = m.delta_msg_id
       AND mc.dc_account_id = m.delta_account_id
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
      ORDER BY m.timestamp DESC, m.rowid DESC
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
        messageAttachments,
      },
    );
    return query.map((row) => messages.map(row.data));
  }

  Selectable<Message> _chatMessagesBeforeSelectable({
    required String jid,
    required MessageTimelineFilter filter,
    required int limit,
    required DateTime beforeTimestamp,
    required String beforeStanzaId,
  }) {
    final filterValue = filter.index;
    final query = customSelect(
      '''
      SELECT m.*
      FROM messages m
      LEFT JOIN message_copies mc
        ON mc.dc_msg_id = m.delta_msg_id
       AND mc.dc_account_id = m.delta_account_id
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
        AND (
          m.timestamp < ?
          OR (
            m.timestamp = ?
            AND m.rowid < COALESCE(
              (SELECT rowid FROM messages WHERE stanza_i_d = ?),
              -1
            )
          )
        )
      ORDER BY m.timestamp DESC, m.rowid DESC
      LIMIT ?
      ''',
      variables: [
        Variable<String>(jid),
        Variable<String>(jid),
        Variable<int>(filterValue),
        Variable<DateTime>(beforeTimestamp),
        Variable<DateTime>(beforeTimestamp),
        Variable<String>(beforeStanzaId),
        Variable<int>(limit),
      ],
      readsFrom: {messages, messageCopies, messageShares, messageParticipants},
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
        (tbl) =>
            OrderingTerm(expression: tbl.timestamp, mode: OrderingMode.asc),
      ]);
    return query.get();
  }

  @override
  Future<List<MessageDeltaSnapshot>> getMessageDeltaSnapshot(String jid) async {
    final query = selectOnly(messages)
      ..addColumns([messages.stanzaID, messages.deltaMsgId, messages.displayed])
      ..where(messages.chatJid.equals(jid));
    final rows = await query.get();
    return rows
        .map(
          (row) => MessageDeltaSnapshot(
            stanzaId: row.read(messages.stanzaID) ?? '',
            deltaMsgId: row.read(messages.deltaMsgId),
            displayed: row.read(messages.displayed) ?? false,
          ),
        )
        .where((snapshot) => snapshot.stanzaId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> deleteMessagesByStanzaIds(Iterable<String> stanzaIds) async {
    final ids = stanzaIds.toList(growable: false);
    if (ids.isEmpty) return;
    await transaction(() async {
      await reactionsAccessor.deleteByMessages(ids);
      await reactionsAccessor.deleteStatesByMessages(ids);
      await (delete(messages)..where((tbl) => tbl.stanzaID.isIn(ids))).go();
    });
  }

  @override
  Future<List<Message>> getPendingOutgoingDeltaMessages({
    required int deltaAccountId,
    required int deltaChatId,
  }) async {
    final query = select(messages)
      ..where(
        (tbl) =>
            tbl.deltaMsgId.isNull() &
            tbl.deltaChatId.equals(deltaChatId) &
            tbl.deltaAccountId.equals(deltaAccountId),
      )
      ..orderBy([
        (tbl) =>
            OrderingTerm(expression: tbl.timestamp, mode: OrderingMode.desc),
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
    String? collectionId,
    int limit = 200,
    bool ascending = false,
  }) async {
    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    final normalizedSubject = subject?.trim().toLowerCase() ?? '';
    final normalizedCollectionId = collectionId?.trim() ?? '';
    final hasQuery = normalizedQuery.isNotEmpty;
    final hasSubject = normalizedSubject.isNotEmpty;
    final hasCollectionFilter = normalizedCollectionId.isNotEmpty;
    if (!hasQuery && !hasSubject && !hasCollectionFilter) return const [];
    final ftsQuery = hasQuery ? _escapeFtsQuery(normalizedQuery) : '';
    final filterValue = filter.index;
    final orderClause = ascending ? 'ASC' : 'DESC';
    final subjectPattern = hasSubject
        ? '%${_escapeLikePattern(normalizedSubject)}%'
        : '%';
    final ftsJoin = hasQuery
        ? 'JOIN messages_fts fts ON fts.rowid = m.rowid'
        : '';
    final ftsClause = hasQuery ? 'AND fts.body MATCH ?' : '';
    final collectionClause = hasCollectionFilter
        ? '''
        AND EXISTS (
          SELECT 1
          FROM message_collection_memberships mcm
          WHERE mcm.collection_id = ?
            AND mcm.chat_jid = m.chat_jid
            AND mcm.active = 1
            AND (
              mcm.message_reference_id = m.stanza_i_d OR
              mcm.message_reference_id = m.origin_i_d OR
              mcm.message_reference_id = m.muc_stanza_id OR
              (
                mcm.message_stanza_id IS NOT NULL AND
                mcm.message_stanza_id = m.stanza_i_d
              ) OR
              (
                mcm.message_origin_id IS NOT NULL AND
                mcm.message_origin_id = m.origin_i_d
              ) OR
              (
                mcm.message_muc_stanza_id IS NOT NULL AND
                mcm.message_muc_stanza_id = m.muc_stanza_id
              ) OR
              (
                mcm.delta_msg_id IS NOT NULL AND
                mcm.delta_account_id IS NOT NULL AND
                m.delta_msg_id = mcm.delta_msg_id AND
                m.delta_account_id = mcm.delta_account_id
              )
            )
        )
        '''
        : '';
    final selectable = customSelect(
      '''
      SELECT m.*
      FROM messages m
      $ftsJoin
      LEFT JOIN message_copies mc
        ON mc.dc_msg_id = m.delta_msg_id
       AND mc.dc_account_id = m.delta_account_id
      LEFT JOIN message_shares ms ON ms.share_id = mc.share_id
      LEFT JOIN message_participants mp
        ON mp.share_id = mc.share_id AND mp.contact_jid = ?
      WHERE m.chat_jid = ?
        $ftsClause
        $collectionClause
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
      ORDER BY m.timestamp $orderClause, m.stanza_i_d $orderClause
      LIMIT ?
      ''',
      variables: [
        Variable<String>(jid),
        Variable<String>(jid),
        if (hasQuery) Variable<String>(ftsQuery),
        if (hasCollectionFilter) Variable<String>(normalizedCollectionId),
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
        messageCollectionMemberships,
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
      JOIN messages m
        ON m.delta_msg_id = mc.dc_msg_id
       AND m.delta_account_id = mc.dc_account_id
      WHERE m.chat_jid = ?
        AND ms.subject IS NOT NULL
        AND TRIM(ms.subject) <> ''
      ORDER BY LOWER(TRIM(ms.subject)) ASC
      ''',
      variables: [Variable<String>(jid)],
      readsFrom: {messageShares, messageCopies, messages},
    );
    final rows = await selectable.get();
    return rows
        .map((row) => row.data['subject'] as String?)
        .whereType<String>()
        .toList();
  }

  @override
  Future<Message?> getLastMessageForChat(
    String jid, {
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    const int startOffset = 0;
    const int pageSize = 25;
    int offset = startOffset;
    while (true) {
      final messages = await getChatMessages(
        jid,
        start: offset,
        end: pageSize,
        filter: filter,
      );
      if (messages.isEmpty) {
        return null;
      }
      for (final message in messages) {
        final bool isInternalSync = await _isInternalSyncMessage(
          body: message.body,
          fileMetadataId: message.fileMetadataID,
        );
        if (!isInternalSync) {
          return message;
        }
      }
      if (messages.length < pageSize) {
        return null;
      }
      offset += pageSize;
    }
  }

  @override
  Future<Message?> getMessageByStanzaID(String stanzaID) =>
      messagesAccessor.selectOne(stanzaID);

  @override
  Future<Message?> getMessageByOriginID(
    String originID, {
    String? chatJid,
  }) async {
    final normalizedOriginId = originID.trim();
    if (normalizedOriginId.isEmpty) {
      return null;
    }
    final normalizedChatJid = chatJid?.trim();
    if (normalizedChatJid != null && normalizedChatJid.isNotEmpty) {
      return await (select(messages)..where(
            (tbl) =>
                tbl.chatJid.equals(normalizedChatJid) &
                tbl.originID.equals(normalizedOriginId),
          ))
          .getSingleOrNull();
    }
    return messagesAccessor.selectOneByOriginID(normalizedOriginId);
  }

  @override
  Future<Message?> getMessageByReferenceId(
    String messageId, {
    String? chatJid,
  }) async {
    final normalized = messageId.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final normalizedChatJid = chatJid?.trim();
    if (normalizedChatJid != null && normalizedChatJid.isNotEmpty) {
      return await (select(messages)..where(
            (tbl) =>
                tbl.chatJid.equals(normalizedChatJid) &
                (tbl.stanzaID.equals(normalized) |
                    tbl.originID.equals(normalized) |
                    tbl.mucStanzaId.equals(normalized)),
          ))
          .getSingleOrNull();
    }
    return await getMessageByStanzaID(normalized) ??
        await getMessageByOriginID(normalized) ??
        await messagesAccessor.selectOneByMucStanzaId(normalized);
  }

  @override
  Future<Message?> getMessageByDeltaId(
    int deltaMsgId, {
    int? deltaAccountId,
    String? chatJid,
  }) {
    final query = select(messages)
      ..where((tbl) => tbl.deltaMsgId.equals(deltaMsgId));
    if (deltaAccountId != null) {
      query.where((tbl) => tbl.deltaAccountId.equals(deltaAccountId));
    }
    if (chatJid != null) {
      query.where((tbl) => tbl.chatJid.equals(chatJid));
    }
    return query.getSingleOrNull();
  }

  @override
  Future<List<Message>> getMessagesByDeltaIds(
    Iterable<int> deltaMsgIds, {
    int? deltaAccountId,
    String? chatJid,
  }) async {
    final normalized = deltaMsgIds
        .where((id) => id > 0)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return const <Message>[];
    }
    final query = select(messages)
      ..where((tbl) => tbl.deltaMsgId.isIn(normalized));
    if (deltaAccountId != null) {
      query.where((tbl) => tbl.deltaAccountId.equals(deltaAccountId));
    }
    if (chatJid != null) {
      query.where((tbl) => tbl.chatJid.equals(chatJid));
    }
    return query.get();
  }

  @override
  Future<List<Message>> getMessagesByStanzaIds(
    Iterable<String> stanzaIds,
  ) async {
    final normalized = stanzaIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) {
      return const <Message>[];
    }
    return (select(
      messages,
    )..where((tbl) => tbl.stanzaID.isIn(normalized))).get();
  }

  @override
  Future<List<Message>> getMessagesByReferenceIds(
    Iterable<String> messageIds, {
    String? chatJid,
  }) async {
    final normalized = messageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return const <Message>[];
    }
    final query = select(messages)
      ..where(
        (tbl) =>
            tbl.stanzaID.isIn(normalized) |
            tbl.originID.isIn(normalized) |
            tbl.mucStanzaId.isIn(normalized),
      );
    final normalizedChatJid = chatJid?.trim();
    if (normalizedChatJid != null && normalizedChatJid.isNotEmpty) {
      query.where((tbl) => tbl.chatJid.equals(normalizedChatJid));
    }
    return query.get();
  }

  @override
  Stream<List<Reaction>> watchReactionsForChat(String jid) =>
      reactionsAccessor.watchChat(jid);

  @override
  Future<List<Reaction>> getReactionsForChat(String jid) =>
      reactionsAccessor.selectByChat(jid);

  @override
  Stream<List<Reaction>> watchReactionsForMessages(
    Iterable<String> messageIds,
  ) {
    final ids = messageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) {
      return Stream.value(const <Reaction>[]);
    }
    return (select(reactions)..where((tbl) => tbl.messageID.isIn(ids))).watch();
  }

  @override
  Future<List<Reaction>> getReactionsForMessages(
    Iterable<String> messageIds,
  ) async {
    final ids = messageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) {
      return const <Reaction>[];
    }
    return (select(reactions)..where((tbl) => tbl.messageID.isIn(ids))).get();
  }

  @override
  Future<List<Reaction>> getReactionsForMessageSender({
    required String messageId,
    required String senderJid,
  }) => reactionsAccessor.selectByMessageAndSender(
    messageId: messageId,
    senderJid: senderJid,
  );

  @override
  Future<ReactionState?> getReactionState({
    required String messageId,
    required String senderJid,
  }) => reactionsAccessor.selectStateByMessageAndSender(
    messageId: messageId,
    senderJid: senderJid,
  );

  @override
  Future<void> clearReactionsForMessageSender({
    required String messageId,
    required String senderJid,
  }) async {
    await transaction(() async {
      await reactionsAccessor.deleteByMessageAndSender(
        messageId: messageId,
        senderJid: senderJid,
      );
      await reactionsAccessor.deleteStateByMessageAndSender(
        messageId: messageId,
        senderJid: senderJid,
      );
    });
  }

  @override
  Future<void> replaceReactions({
    required String messageId,
    required String senderJid,
    required List<String> emojis,
    required DateTime updatedAt,
    required bool identityVerified,
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
      await reactionsAccessor.upsertState(
        messageId: messageId,
        senderJid: senderJid,
        updatedAt: updatedAt,
        identityVerified: identityVerified,
      );
    });
  }

  bool _isInternalSyncEnvelope(String? body) {
    final trimmed = body?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return false;
    }
    return CalendarSyncMessage.isCalendarSyncEnvelope(trimmed) ||
        CalendarSyncMessage.looksLikeEnvelope(trimmed) ||
        _isMessageStatusSyncEnvelope(trimmed);
  }

  Future<bool> _isInternalSyncMessage({
    required String? body,
    required String? fileMetadataId,
  }) async {
    if (_isInternalSyncEnvelope(body)) {
      return true;
    }
    final String? trimmedMetadataId = fileMetadataId?.trim();
    if (trimmedMetadataId == null || trimmedMetadataId.isEmpty) {
      return false;
    }
    final FileMetadataData? metadata = await fileMetadataAccessor.selectOne(
      trimmedMetadataId,
    );
    if (metadata == null) {
      return false;
    }
    return metadata.isCalendarSnapshot;
  }

  bool _isMessageStatusSyncEnvelope(String raw) {
    if (!raw.contains(_messageStatusSyncEnvelopeKey)) {
      return false;
    }
    const versionKey = 'v';
    const idKey = 'id';
    const messageStatusSyncEnvelopeVersion = 1;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      final payload = decoded[_messageStatusSyncEnvelopeKey];
      if (payload is! Map<String, dynamic>) {
        return false;
      }
      final version = payload[versionKey] as int?;
      if (version != messageStatusSyncEnvelopeVersion) {
        return false;
      }
      final id = payload[idKey] as String?;
      return id != null && id.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> saveMessage(
    Message message, {
    ChatType chatType = ChatType.chat,
    String? selfJid,
  }) async {
    _log.fine('Persisting message');
    final resolvedMessageId = message.id ?? uuid.v4();
    final trimmedBody = message.body?.trim();
    final trimmedMetadataId = message.fileMetadataID?.trim();
    final hasAttachment = trimmedMetadataId?.isNotEmpty == true;
    final messageTimestamp = message.timestamp ?? DateTime.timestamp();
    final bool isInternalSync = await _isInternalSyncMessage(
      body: message.body,
      fileMetadataId: trimmedMetadataId,
    );
    final bool shouldUpdateChatSummary = !isInternalSync;
    final currentChat = await getChat(message.chatJid);
    final bool isSelfMessage = sameNormalizedAddressValue(
      message.senderJid,
      selfJid,
    );
    final bool isSelfChat = sameNormalizedAddressValue(
      message.chatJid,
      selfJid,
    );
    final bool shouldNormalizeSelfChatTitle =
        isSelfChat &&
        currentChat?.contactDisplayName?.trim().isNotEmpty != true &&
        currentChat?.title.trim() != 'Saved Messages';
    final bool shouldIncrementUnread =
        shouldUpdateChatSummary &&
        _messageCountsTowardUnread(
          trimmedBody: trimmedBody,
          fileMetadataId: message.fileMetadataID,
          pseudoMessageType: message.pseudoMessageType,
        ) &&
        !message.displayed &&
        !isSelfMessage;
    final int unreadIncrement = shouldIncrementUnread ? 1 : 0;
    final bool isEmailMessage =
        currentChat?.defaultTransport.isEmail == true ||
        message.deltaMsgId != null;
    final bool shouldRepairSummaryAfterSave =
        shouldUpdateChatSummary &&
        currentChat?.lastChangeTimestamp.isAfter(messageTimestamp) == true;
    final DateTime? existingLastChangeTimestamp =
        currentChat?.lastChangeTimestamp;
    final DateTime resolvedLastChangeTimestamp = shouldUpdateChatSummary
        ? messageTimestamp
        : (existingLastChangeTimestamp ??
              DateTime.fromMillisecondsSinceEpoch(_emptyTimestampMillis));
    final String? lastMessagePreview = shouldUpdateChatSummary
        ? await _messagePreview(
            trimmedBody: trimmedBody,
            subject: message.subject,
            deltaChatId: message.deltaChatId,
            deltaMsgId: message.deltaMsgId,
            fileMetadataId: message.fileMetadataID,
            hasAttachment: hasAttachment,
            pseudoMessageType: message.pseudoMessageType,
            pseudoMessageData: message.pseudoMessageData,
          )
        : null;
    final chatTitle = _chatTitleForIdentifier(
      message.chatJid,
      selfJid: selfJid,
    );
    await transaction(() async {
      await into(chats).insert(
        ChatsCompanion.insert(
          jid: message.chatJid,
          title: chatTitle,
          type: chatType,
          unreadCount: Value(unreadIncrement),
          lastMessage: Value.absentIfNull(lastMessagePreview),
          lastChangeTimestamp: resolvedLastChangeTimestamp,
          encryptionProtocol: Value(message.encryptionProtocol),
          contactJid: Value(
            chatType == ChatType.groupChat ? null : message.chatJid,
          ),
        ),
        onConflict: DoUpdate.withExcluded(
          (old, excluded) => ChatsCompanion.custom(
            type: excluded.type,
            unreadCount: (old.unreadCount + Constant(unreadIncrement)).iif(
              Constant(isEmailMessage),
              const Constant(0).iif(
                old.open.isValue(true),
                old.unreadCount + Constant(unreadIncrement),
              ),
            ),
            lastMessage: old.lastMessage,
            lastChangeTimestamp: old.lastChangeTimestamp,
          ),
        ),
      );
      BTBVTrustState? trust;
      bool? trusted;
      if (message.deviceID case final int deviceID) {
        final trustData = await omemoTrustsAccessor.selectOne(
          OmemoTrust(jid: message.senderJid, device: deviceID),
        );
        trust = trustData?.state;
        trusted = trustData?.trusted;
      }
      final messageToSave = message.copyWith(
        id: resolvedMessageId,
        trust: trust,
        trusted: trusted,
      );
      await messagesAccessor.insertOne(messageToSave);
      if (shouldNormalizeSelfChatTitle) {
        await (update(chats)..where((tbl) => tbl.jid.equals(message.chatJid)))
            .write(ChatsCompanion(title: Value(chatTitle)));
      }
      final persisted = await messagesAccessor.selectOne(message.stanzaID);
      if (persisted == null) {
        _log.warning('Message insert ignored; retrying with upsert');
        await into(messages).insertOnConflictUpdate(messageToSave);
        if (shouldUpdateChatSummary) {
          await _updateChatSummaryIfNewer(
            jid: message.chatJid,
            timestamp: messageTimestamp,
            lastMessage: lastMessagePreview,
          );
          if (shouldRepairSummaryAfterSave) {
            await repairChatSummaryPreservingTimestamp(message.chatJid);
          }
        }
        return;
      }

      if (persisted.retracted) {
        return;
      }

      final persistedMessageId = persisted.id ?? resolvedMessageId;
      final incomingMetadataId = messageToSave.fileMetadataID?.trim();
      final hasIncomingMetadataId = incomingMetadataId?.isNotEmpty == true;
      if (hasIncomingMetadataId) {
        await addMessageAttachment(
          messageId: persistedMessageId,
          fileMetadataId: incomingMetadataId!,
        );
      }
      if (shouldUpdateChatSummary) {
        await _updateChatSummaryIfNewer(
          jid: message.chatJid,
          timestamp: messageTimestamp,
          lastMessage: lastMessagePreview,
        );
        if (shouldRepairSummaryAfterSave) {
          await repairChatSummaryPreservingTimestamp(message.chatJid);
        }
      }

      final incomingBody = messageToSave.body?.trim();
      final hasIncomingBody = incomingBody?.isNotEmpty == true;
      final persistedBody = persisted.body?.trim();
      final hasPersistedBody = persistedBody?.isNotEmpty == true;

      final incomingHtml = messageToSave.htmlBody?.trim();
      final hasIncomingHtml = incomingHtml?.isNotEmpty == true;
      final persistedHtml = persisted.htmlBody?.trim();
      final hasPersistedHtml = persistedHtml?.isNotEmpty == true;

      final persistedMetadataId = persisted.fileMetadataID?.trim();
      final hasPersistedMetadataId = persistedMetadataId?.isNotEmpty == true;
      final incomingMucStanzaId = messageToSave.mucStanzaId?.trim();
      final hasIncomingMucStanzaId = incomingMucStanzaId?.isNotEmpty == true;
      final persistedMucStanzaId = persisted.mucStanzaId?.trim();
      final hasPersistedMucStanzaId = persistedMucStanzaId?.isNotEmpty == true;

      final shouldMergeBody = hasIncomingBody && !hasPersistedBody;
      final shouldMergeHtml = hasIncomingHtml && !hasPersistedHtml;
      final shouldMergeMetadataId =
          hasIncomingMetadataId && !hasPersistedMetadataId;
      final shouldMergeMucStanzaId =
          hasIncomingMucStanzaId && !hasPersistedMucStanzaId;
      if (!shouldMergeBody &&
          !shouldMergeHtml &&
          !shouldMergeMetadataId &&
          !shouldMergeMucStanzaId) {
        return;
      }

      await (update(
        messages,
      )..where((tbl) => tbl.stanzaID.equals(message.stanzaID))).write(
        MessagesCompanion(
          body: shouldMergeBody
              ? Value(messageToSave.body)
              : const Value.absent(),
          htmlBody: shouldMergeHtml
              ? Value(messageToSave.htmlBody)
              : const Value.absent(),
          fileMetadataID: shouldMergeMetadataId
              ? Value(incomingMetadataId)
              : const Value.absent(),
          mucStanzaId: shouldMergeMucStanzaId
              ? Value(incomingMucStanzaId)
              : const Value.absent(),
        ),
      );
    });
  }

  bool _messageCountsTowardUnread({
    required String? trimmedBody,
    required String? fileMetadataId,
    required PseudoMessageType? pseudoMessageType,
  }) {
    final hasBody = trimmedBody?.isNotEmpty == true;
    final hasAttachment = fileMetadataId?.trim().isNotEmpty == true;
    if (!(hasBody || hasAttachment)) {
      return false;
    }
    if (pseudoMessageType == null) {
      return true;
    }
    return pseudoMessageType.isInvite;
  }

  Future<String?> _messagePreview({
    required String? trimmedBody,
    required String? subject,
    required int? deltaChatId,
    required int? deltaMsgId,
    required String? fileMetadataId,
    required bool hasAttachment,
    required PseudoMessageType? pseudoMessageType,
    required Map<String, dynamic>? pseudoMessageData,
  }) async {
    if (pseudoMessageType == PseudoMessageType.mucInvite ||
        pseudoMessageType == PseudoMessageType.mucInviteRevocation) {
      return pseudoMessageType == PseudoMessageType.mucInvite
          ? 'You have been invited to a group chat'
          : 'Invite revoked';
    }

    final bool isEmailMessage = deltaChatId != null || deltaMsgId != null;
    if (isEmailMessage) {
      final preview = ChatSubjectCodec.previewEmailText(
        body: trimmedBody,
        subject: subject,
      );
      if (preview != null) {
        return preview;
      }
    }
    final split = ChatSubjectCodec.splitDisplayBody(
      body: trimmedBody,
      subject: subject,
    );
    final String? trimmedSubject = split.subject?.trim();
    final previewBody = ChatSubjectCodec.previewBodyText(split.body).trim();
    if (ChatSubjectCodec.containsInviteEnvelope(previewBody)) {
      return 'You have been invited to a group chat';
    }
    if (ChatSubjectCodec.containsInviteRevocationEnvelope(previewBody)) {
      return 'Invite revoked';
    }
    if (previewBody.isNotEmpty) {
      final lines = previewBody.split('\n');
      final filtered = lines
          .where(
            (line) =>
                !ChatSubjectCodec.containsInviteEnvelope(line) &&
                !ChatSubjectCodec.containsInviteRevocationEnvelope(line),
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
      if (cleaned.isNotEmpty) {
        return trimmedSubject?.isNotEmpty == true
            ? '$trimmedSubject — $cleaned'
            : cleaned;
      }
    }
    if (trimmedSubject?.isNotEmpty == true) {
      return trimmedSubject;
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

  Future<void> _updateChatSummaryIfNewer({
    required String jid,
    required DateTime timestamp,
    required String? lastMessage,
  }) async {
    final resolvedLastMessage = lastMessage ?? '';
    final hasLastMessage = resolvedLastMessage.trim().isNotEmpty;
    const int emptyMessageLength = 0;
    await customUpdate(
      '''
UPDATE chats
SET last_change_timestamp = CASE
      WHEN last_change_timestamp IS NULL OR last_change_timestamp < ? THEN ?
      ELSE last_change_timestamp
    END,
    last_message = CASE
      WHEN ? = 0 THEN last_message
      WHEN last_message IS NULL OR LENGTH(TRIM(last_message)) <= ? THEN ?
      WHEN last_change_timestamp IS NULL OR last_change_timestamp <= ? THEN ?
      ELSE last_message
    END
WHERE jid = ?
''',
      variables: [
        Variable<DateTime>(timestamp),
        Variable<DateTime>(timestamp),
        Variable<int>(hasLastMessage ? 1 : 0),
        Variable<int>(emptyMessageLength),
        Variable<String>(resolvedLastMessage),
        Variable<DateTime>(timestamp),
        Variable<String>(resolvedLastMessage),
        Variable<String>(jid),
      ],
      updates: {chats},
    );
  }

  @override
  Future<void> saveMessageError({
    required String stanzaID,
    required MessageError error,
  }) async {
    _log.info('Updating message error');
    await messagesAccessor.updateOne(
      MessagesCompanion(stanzaID: Value(stanzaID), error: Value(error)),
    );
  }

  @override
  Future<void> saveMessageDevice({
    required String stanzaID,
    required int deviceID,
    required String to,
  }) async {
    _log.info('Updating message device');
    await messagesAccessor.updateOne(
      MessagesCompanion(
        stanzaID: Value(stanzaID),
        deviceID: Value(deviceID),
        trusted: const Value(true),
      ),
    );
  }

  @override
  Future<void> saveMessageEdit({
    required String stanzaID,
    required String? body,
  }) async {
    _log.fine('Editing message');
    await messagesAccessor.updateOne(
      MessagesCompanion(
        stanzaID: Value(stanzaID),
        edited: const Value(true),
        body: Value(body),
      ),
    );
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
      final existing = await messagesAccessor.selectOne(stanzaID);
      if (metadata != null && existing?.id != null) {
        await addMessageAttachment(
          messageId: existing!.id!,
          fileMetadataId: metadata.id,
        );
      }
      await (update(
        messages,
      )..where((tbl) => tbl.stanzaID.equals(stanzaID))).write(
        MessagesCompanion(
          fileMetadataID: metadata != null
              ? Value(metadata.id)
              : const Value.absent(),
          body: body != null ? Value(body) : const Value.absent(),
        ),
      );
    });
  }

  @override
  Future<void> markMessageRetracted(String stanzaID) async {
    _log.info('Retracting message');
    final existing = await messagesAccessor.selectOne(stanzaID);
    if (existing == null) return;
    final metadataIds = <String>{};
    final directMetadataId = existing.fileMetadataID?.trim();
    if (directMetadataId != null && directMetadataId.isNotEmpty) {
      metadataIds.add(directMetadataId);
    }
    await transaction(() async {
      await (update(
        messages,
      )..where((messages) => messages.stanzaID.equals(stanzaID))).write(
        const MessagesCompanion(
          retracted: Value(true),
          body: Value(null),
          fileMetadataID: Value(null),
          error: Value(MessageError.none),
          warning: Value(MessageWarning.none),
        ),
      );
      if (existing.id != null) {
        metadataIds.addAll(await deleteMessageAttachments(existing.id!));
      }
    });
    for (final metadataId in metadataIds) {
      await _deleteFileMetadataIfOrphaned(metadataId);
    }
  }

  @override
  Future<void> markMessageAcked(String stanzaID, {String? chatJid}) async {
    final normalizedChatJid = chatJid?.trim();
    final query = update(messages)
      ..where(
        (tbl) =>
            (normalizedChatJid == null || normalizedChatJid.isEmpty
                ? const Constant(true)
                : tbl.chatJid.equals(normalizedChatJid)) &
            (tbl.stanzaID.equals(stanzaID) | tbl.originID.equals(stanzaID)) &
            tbl.acked.equals(false),
      );
    final updatedRows = await query.write(
      const MessagesCompanion(acked: Value(true)),
    );
    if (updatedRows > 0) {
      _log.info('Marking message acked');
    }
  }

  @override
  Future<void> markMessageReceived(String stanzaID, {String? chatJid}) async {
    final normalizedChatJid = chatJid?.trim();
    final query = update(messages)
      ..where(
        (tbl) =>
            (normalizedChatJid == null || normalizedChatJid.isEmpty
                ? const Constant(true)
                : tbl.chatJid.equals(normalizedChatJid)) &
            (tbl.stanzaID.equals(stanzaID) | tbl.originID.equals(stanzaID)) &
            tbl.received.equals(false),
      );
    final updatedRows = await query.write(
      const MessagesCompanion(received: Value(true)),
    );
    if (updatedRows > 0) {
      _log.info('Marking message received');
    }
  }

  @override
  Future<void> markMessageDisplayed(String stanzaID, {String? chatJid}) async {
    final normalizedChatJid = chatJid?.trim();
    final query = update(messages)
      ..where(
        (tbl) =>
            (normalizedChatJid == null || normalizedChatJid.isEmpty
                ? const Constant(true)
                : tbl.chatJid.equals(normalizedChatJid)) &
            (tbl.stanzaID.equals(stanzaID) | tbl.originID.equals(stanzaID)) &
            tbl.displayed.equals(false),
      );
    final updatedRows = await query.write(
      const MessagesCompanion(displayed: Value(true)),
    );
    if (updatedRows > 0) {
      _log.info('Marking message displayed');
    }
  }

  @override
  Future<void> markOutgoingMessagesDisplayedThrough({
    required String messageId,
    required String chatJid,
    required String senderJid,
  }) async {
    final normalizedMessageId = messageId.trim();
    final normalizedChatJid = chatJid.trim();
    final normalizedSenderJid = senderJid.trim();
    if (normalizedMessageId.isEmpty ||
        normalizedChatJid.isEmpty ||
        normalizedSenderJid.isEmpty) {
      return;
    }

    final updatedRows = await customUpdate(
      '''
UPDATE messages
SET displayed = 1
WHERE chat_jid = ?
  AND LOWER(sender_jid) = LOWER(?)
  AND displayed = 0
  AND EXISTS (
    SELECT 1
    FROM messages target
    WHERE target.chat_jid = ?
      AND LOWER(target.sender_jid) = LOWER(?)
      AND (
        target.stanza_i_d = ?
        OR target.origin_i_d = ?
        OR target.muc_stanza_id = ?
      )
      AND (
        messages.timestamp < target.timestamp
        OR (
          messages.timestamp = target.timestamp
          AND messages.rowid <= target.rowid
        )
      )
  )
''',
      variables: [
        Variable<String>(normalizedChatJid),
        Variable<String>(normalizedSenderJid),
        Variable<String>(normalizedChatJid),
        Variable<String>(normalizedSenderJid),
        Variable<String>(normalizedMessageId),
        Variable<String>(normalizedMessageId),
        Variable<String>(normalizedMessageId),
      ],
      updates: {messages},
    );
    if (updatedRows > 0) {
      _log.info(
        'Marking outgoing messages displayed through $normalizedMessageId',
      );
    }
  }

  @override
  Future<void> deleteMessage(String stanzaID) async {
    _log.info('Deleting message');
    final existing = await messagesAccessor.selectOne(stanzaID);
    if (existing == null) return;
    final metadataIds = <String>{};
    final directMetadataId = existing.fileMetadataID?.trim();
    if (directMetadataId != null && directMetadataId.isNotEmpty) {
      metadataIds.add(directMetadataId);
    }
    await transaction(() async {
      await reactionsAccessor.deleteByMessage(stanzaID);
      await reactionsAccessor.deleteStatesByMessage(stanzaID);
      if (existing.id != null) {
        metadataIds.addAll(await deleteMessageAttachments(existing.id!));
      }
      await deletePinnedMessage(
        chatJid: existing.chatJid,
        messageStanzaId: existing.stanzaID,
      );
      await messagesAccessor.deleteOne(stanzaID);
      final chat = await getChat(existing.chatJid);
      if (chat == null) return;
      final lastMessage = await getLastMessageForChat(chat.jid);
      final lastMessagePreview = await _messagePreview(
        trimmedBody: lastMessage?.body?.trim(),
        subject: lastMessage?.subject,
        deltaChatId: lastMessage?.deltaChatId,
        deltaMsgId: lastMessage?.deltaMsgId,
        fileMetadataId: lastMessage?.fileMetadataID,
        hasAttachment: lastMessage?.fileMetadataID?.isNotEmpty == true,
        pseudoMessageType: lastMessage?.pseudoMessageType,
        pseudoMessageData: lastMessage?.pseudoMessageData,
      );
      final String? trimmedBody = existing.body?.trim();
      final bool shouldDecrementUnread =
          _messageCountsTowardUnread(
            trimmedBody: trimmedBody,
            fileMetadataId: existing.fileMetadataID,
            pseudoMessageType: existing.pseudoMessageType,
          ) &&
          !existing.displayed;
      final int nextUnreadCount = lastMessage == null
          ? 0
          : shouldDecrementUnread && chat.unreadCount > 0
          ? chat.unreadCount - 1
          : chat.unreadCount;
      await chatsAccessor.updateOne(
        chat.copyWith(
          lastMessage: lastMessagePreview,
          lastChangeTimestamp:
              lastMessage?.timestamp ?? chat.lastChangeTimestamp,
          unreadCount: nextUnreadCount,
        ),
      );
    });
    for (final metadataId in metadataIds) {
      await _deleteFileMetadataIfOrphaned(metadataId);
    }
  }

  @override
  Future<void> replaceDeltaPlaceholderSelfJids({
    required int deltaAccountId,
    required String resolvedAddress,
    required List<String> placeholderJids,
  }) async {
    const String sqlPlaceholderToken = '?';
    const String sqlPlaceholderSeparator = ', ';
    final normalizedAddress = normalizedAddressValue(resolvedAddress);
    if (normalizedAddress == null || normalizedAddress.isEmpty) {
      return;
    }
    final normalizedPlaceholders = placeholderJids
        .map(normalizedAddressValue)
        .whereType<String>()
        .where((jid) => jid.isNotEmpty)
        .toList(growable: false);
    if (normalizedPlaceholders.isEmpty) {
      return;
    }
    final placeholderClause = List<String>.filled(
      normalizedPlaceholders.length,
      sqlPlaceholderToken,
      growable: false,
    ).join(sqlPlaceholderSeparator);
    final updateMessagesSql =
        '''
UPDATE messages
SET sender_jid = ?
WHERE delta_account_id = ?
  AND sender_jid IN ($placeholderClause)
''';
    await customStatement(updateMessagesSql, [
      normalizedAddress,
      deltaAccountId,
      ...normalizedPlaceholders,
    ]);
    final updateChatsSql =
        '''
UPDATE chats
SET email_from_address = ?
WHERE email_from_address IN ($placeholderClause)
  AND jid IN (
    SELECT chat_jid
    FROM email_chat_accounts
    WHERE delta_account_id = ?
  )
''';
    await customStatement(updateChatsSql, [
      normalizedAddress,
      ...normalizedPlaceholders,
      deltaAccountId,
    ]);
  }

  @override
  Future<void> removeDeltaPlaceholderDuplicates({
    required int deltaAccountId,
    required List<String> placeholderJids,
  }) async {
    const String deltaKeySeparator = '|';
    final normalizedPlaceholders = placeholderJids
        .map(normalizedAddressValue)
        .whereType<String>()
        .where((jid) => jid.isNotEmpty)
        .toList(growable: false);
    if (normalizedPlaceholders.isEmpty) {
      return;
    }
    final placeholderMessages =
        await (select(messages)..where(
              (tbl) =>
                  tbl.deltaAccountId.equals(deltaAccountId) &
                  tbl.deltaMsgId.isNotNull() &
                  tbl.senderJid.isIn(normalizedPlaceholders),
            ))
            .get();
    if (placeholderMessages.isEmpty) {
      return;
    }
    final deltaIds = placeholderMessages
        .map((message) => message.deltaMsgId)
        .whereType<int>()
        .toSet();
    if (deltaIds.isEmpty) {
      return;
    }
    final relatedMessages =
        await (select(messages)..where(
              (tbl) =>
                  tbl.deltaAccountId.equals(deltaAccountId) &
                  tbl.deltaMsgId.isIn(deltaIds),
            ))
            .get();
    final messagesByKey = <String, List<Message>>{};
    for (final message in relatedMessages) {
      final deltaMsgId = message.deltaMsgId;
      if (deltaMsgId == null) {
        continue;
      }
      final key = '${message.chatJid}$deltaKeySeparator$deltaMsgId';
      final entries = messagesByKey[key] ?? <Message>[];
      entries.add(message);
      messagesByKey[key] = entries;
    }
    final messagesToDelete = <Message>[];
    for (final message in placeholderMessages) {
      final deltaMsgId = message.deltaMsgId;
      if (deltaMsgId == null) {
        continue;
      }
      final key = '${message.chatJid}$deltaKeySeparator$deltaMsgId';
      final candidates = messagesByKey[key] ?? const <Message>[];
      final hasNonPlaceholder = candidates.any((candidate) {
        final sender = normalizedAddressValueOrEmpty(candidate.senderJid);
        return !normalizedPlaceholders.contains(sender);
      });
      if (hasNonPlaceholder) {
        messagesToDelete.add(message);
      }
    }
    if (messagesToDelete.isEmpty) {
      return;
    }
    final stanzaIds = messagesToDelete
        .map((message) => message.stanzaID)
        .toSet()
        .toList(growable: false);
    final messageIds = messagesToDelete
        .map((message) => message.id)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final metadataIds = <String>{};
    for (final message in messagesToDelete) {
      final directMetadataId = message.fileMetadataID?.trim();
      if (directMetadataId != null && directMetadataId.isNotEmpty) {
        metadataIds.add(directMetadataId);
      }
    }
    if (messageIds.isNotEmpty) {
      final attachments = await messageAttachmentsAccessor.selectForMessages(
        messageIds,
      );
      for (final attachment in attachments) {
        final metadataId = attachment.fileMetadataId;
        if (metadataId.isNotEmpty) {
          metadataIds.add(metadataId);
        }
      }
    }
    final unreadDecrements = <String, int>{};
    for (final message in messagesToDelete) {
      final trimmedBody = message.body?.trim();
      final shouldDecrement =
          _messageCountsTowardUnread(
            trimmedBody: trimmedBody,
            fileMetadataId: message.fileMetadataID,
            pseudoMessageType: message.pseudoMessageType,
          ) &&
          !message.displayed;
      if (!shouldDecrement) {
        continue;
      }
      unreadDecrements.update(
        message.chatJid,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    await transaction(() async {
      for (final batch in _chunked(stanzaIds, batchSize: 900)) {
        await (delete(
          reactions,
        )..where((tbl) => tbl.messageID.isIn(batch))).go();
        await (delete(
          reactionStates,
        )..where((tbl) => tbl.messageID.isIn(batch))).go();
        await (delete(
          pinnedMessages,
        )..where((tbl) => tbl.messageStanzaId.isIn(batch))).go();
        await (delete(messages)..where((tbl) => tbl.stanzaID.isIn(batch))).go();
      }
      if (messageIds.isNotEmpty) {
        for (final batch in _chunked(messageIds, batchSize: 900)) {
          await messageAttachmentsAccessor.deleteForMessages(batch);
        }
      }
      for (final entry in unreadDecrements.entries) {
        final chat = await getChat(entry.key);
        if (chat == null) continue;
        final nextUnread = chat.unreadCount - entry.value;
        await chatsAccessor.updateOne(
          chat.copyWith(unreadCount: nextUnread < 0 ? 0 : nextUnread),
        );
      }
    });
    for (final metadataId in metadataIds) {
      await _deleteFileMetadataIfOrphaned(metadataId);
    }
    final affectedChats = messagesToDelete
        .map((message) => message.chatJid)
        .toSet();
    for (final chatJid in affectedChats) {
      await _refreshChatSummaryAfterTrim(jid: chatJid);
    }
  }

  @override
  Future<void> clearMessageHistory() async {
    _log.info('Clearing message history...');
    final metadataToDelete = await select(fileMetadata).get();
    bool cleared = false;
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        await delete(reactions).go();
        await delete(reactionStates).go();
        await delete(messageParticipants).go();
        await delete(messageCopies).go();
        await delete(messageShares).go();
        await delete(messageAttachments).go();
        await delete(messages).go();
        await delete(pinnedMessages).go();
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
      cleared = true;
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
    if (cleared) {
      await _deleteManagedAttachmentFiles(metadataToDelete);
    }
  }

  @override
  Future<void> trimChatMessages({
    required String jid,
    required int maxMessages,
    int? deltaAccountId,
  }) async {
    const int trimBatchSize = 900; // stays under SQLite's 999-variable limit
    const int trimRefreshSummaryLimit = 0;
    Iterable<List<T>> chunked<T>(List<T> items) sync* {
      for (var index = 0; index < items.length; index += trimBatchSize) {
        final end = index + trimBatchSize;
        yield items.sublist(index, end > items.length ? items.length : end);
      }
    }

    final offset = maxMessages <= trimRefreshSummaryLimit
        ? trimRefreshSummaryLimit
        : maxMessages;
    final bool refreshSummary = maxMessages <= trimRefreshSummaryLimit;
    final bool filterByAccount = deltaAccountId != null;
    final String accountClause = filterByAccount
        ? ' AND delta_account_id = ?'
        : '';
    final pruned = await customSelect(
      '''
      SELECT id AS message_id, stanza_i_d AS stanza_id, delta_msg_id,
             delta_account_id
      FROM messages
      WHERE chat_jid = ?$accountClause
      ORDER BY timestamp DESC
      LIMIT -1 OFFSET ?
      ''',
      variables: [
        Variable<String>(jid),
        if (filterByAccount) Variable<int>(deltaAccountId),
        Variable<int>(offset),
      ],
      readsFrom: {messages},
    ).get();

    if (pruned.isEmpty) {
      if (refreshSummary) {
        await _refreshChatSummaryAfterTrim(jid: jid);
      }
      return;
    }

    final stanzaIds = <String>[];
    final Map<int, List<int>> deltaMsgIdsByAccount = {};
    final messageIds = <String>[];
    for (final row in pruned) {
      final messageId = row.read<String>('message_id');
      messageIds.add(messageId);
      stanzaIds.add(row.read<String>('stanza_id'));
      final deltaMsgId = row.read<int?>('delta_msg_id');
      final deltaAccountId = row.read<int>('delta_account_id');
      if (deltaMsgId != null) {
        deltaMsgIdsByAccount
            .putIfAbsent(deltaAccountId, () => <int>[])
            .add(deltaMsgId);
      }
    }

    final metadataIds = <String>{};
    if (messageIds.isNotEmpty) {
      for (final batch in chunked(messageIds)) {
        final rows =
            await (selectOnly(messageAttachments)
                  ..addColumns([messageAttachments.fileMetadataId])
                  ..where(messageAttachments.messageId.isIn(batch)))
                .get();
        for (final row in rows) {
          final metadataId = row.read(messageAttachments.fileMetadataId);
          if (metadataId != null && metadataId.isNotEmpty) {
            metadataIds.add(metadataId);
          }
        }
      }
    }
    if (stanzaIds.isNotEmpty) {
      for (final batch in chunked(stanzaIds)) {
        final rows =
            await (selectOnly(messages)
                  ..addColumns([messages.fileMetadataID])
                  ..where(messages.stanzaID.isIn(batch)))
                .get();
        for (final row in rows) {
          final metadataId = row.read(messages.fileMetadataID)?.trim();
          if (metadataId != null && metadataId.isNotEmpty) {
            metadataIds.add(metadataId);
          }
        }
      }
    }

    await transaction(() async {
      final shareIds = <String>{};
      if (deltaMsgIdsByAccount.isNotEmpty) {
        for (final entry in deltaMsgIdsByAccount.entries) {
          final accountId = entry.key;
          final messageIds = entry.value;
          for (final batch in chunked(messageIds)) {
            final copies =
                await (select(messageCopies)..where(
                      (tbl) =>
                          tbl.dcAccountId.equals(accountId) &
                          tbl.dcMsgId.isIn(batch),
                    ))
                    .get();
            shareIds.addAll(copies.map((copy) => copy.shareId));

            await (delete(messageCopies)..where(
                  (tbl) =>
                      tbl.dcAccountId.equals(accountId) &
                      tbl.dcMsgId.isIn(batch),
                ))
                .go();
          }
        }
      }

      if (stanzaIds.isNotEmpty) {
        for (final batch in chunked(stanzaIds)) {
          await (delete(
            reactions,
          )..where((tbl) => tbl.messageID.isIn(batch))).go();
        }
        for (final batch in chunked(messageIds)) {
          await (delete(
            messageAttachments,
          )..where((tbl) => tbl.messageId.isIn(batch))).go();
        }
        for (final batch in chunked(stanzaIds)) {
          await (delete(pinnedMessages)
                ..where((tbl) => tbl.messageStanzaId.isIn(batch))
                ..where((tbl) => tbl.chatJid.equals(jid)))
              .go();
        }
        for (final batch in chunked(stanzaIds)) {
          await (delete(
            messages,
          )..where((tbl) => tbl.stanzaID.isIn(batch))).go();
        }
      }

      if (shareIds.isNotEmpty) {
        final remainingShareIds = <String>{};
        final shareIdList = shareIds.toList(growable: false);
        for (final batch in chunked(shareIdList)) {
          final rows =
              await (selectOnly(messageCopies)
                    ..addColumns([messageCopies.shareId])
                    ..where(messageCopies.shareId.isIn(batch)))
                  .get();
          remainingShareIds.addAll(
            rows
                .map((row) => row.read(messageCopies.shareId))
                .whereType<String>(),
          );
        }

        final expiredShares = shareIds
            .difference(remainingShareIds)
            .toList(growable: false);
        if (expiredShares.isNotEmpty) {
          for (final batch in chunked(expiredShares)) {
            await (delete(
              messageParticipants,
            )..where((tbl) => tbl.shareId.isIn(batch))).go();
          }
          for (final batch in chunked(expiredShares)) {
            await (delete(
              messageShares,
            )..where((tbl) => tbl.shareId.isIn(batch))).go();
          }
        }
      }
    });

    for (final metadataId in metadataIds) {
      await _deleteFileMetadataIfOrphaned(metadataId);
    }
    if (refreshSummary) {
      await _refreshChatSummaryAfterTrim(jid: jid);
    }
  }

  Future<void> _refreshChatSummaryAfterTrim({required String jid}) async {
    const int summaryStartOffset = 0;
    const int summaryPageSize = 1;
    const int emptyUnreadCount = 0;
    const summaryFilter = MessageTimelineFilter.allWithContact;
    final chat = await getChat(jid);
    if (chat == null) return;
    final lastMessage = await getLastMessageForChat(jid, filter: summaryFilter);
    final bool hasVisibleMessage = lastMessage != null;
    final bool hasAnyMessages =
        hasVisibleMessage ||
        (await getChatMessages(
          jid,
          start: summaryStartOffset,
          end: summaryPageSize,
          filter: summaryFilter,
        )).isNotEmpty;
    final String? trimmedBody = lastMessage?.body?.trim();
    final bool hasAttachment = lastMessage?.fileMetadataID?.isNotEmpty == true;
    final String? lastMessagePreview = lastMessage == null
        ? null
        : await _messagePreview(
            trimmedBody: trimmedBody,
            subject: lastMessage.subject,
            deltaChatId: lastMessage.deltaChatId,
            deltaMsgId: lastMessage.deltaMsgId,
            fileMetadataId: lastMessage.fileMetadataID,
            hasAttachment: hasAttachment,
            pseudoMessageType: lastMessage.pseudoMessageType,
            pseudoMessageData: lastMessage.pseudoMessageData,
          );
    final DateTime emptyTimestamp = DateTime.fromMillisecondsSinceEpoch(
      _emptyTimestampMillis,
    );
    final DateTime nextTimestamp =
        lastMessage?.timestamp ??
        (hasAnyMessages ? chat.lastChangeTimestamp : emptyTimestamp);
    final int nextUnreadCount = lastMessage == null
        ? emptyUnreadCount
        : chat.unreadCount;
    final updated = chat.copyWith(
      lastMessage: lastMessagePreview,
      lastChangeTimestamp: nextTimestamp,
      unreadCount: nextUnreadCount,
    );
    if (updated != chat) {
      await chatsAccessor.updateOne(updated);
    }
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
  Future<void> updateMessage(Message message) async {
    _log.fine('Updating message');
    await update(messages).replace(message);
  }

  @override
  Future<int> countUnreadMessagesForChat(String jid, {String? selfJid}) async {
    final normalizedJid = jid.trim();
    if (normalizedJid.isEmpty) {
      return 0;
    }
    final normalizedSelfJid = selfJid?.trim();
    final candidates =
        await (select(messages)..where(
              (tbl) =>
                  tbl.chatJid.equals(normalizedJid) &
                  tbl.displayed.equals(false),
            ))
            .get();
    var unreadCount = 0;
    for (final message in candidates) {
      if (!message.hasUnreadContent) {
        continue;
      }
      if (sameNormalizedAddressValue(message.senderJid, normalizedSelfJid)) {
        continue;
      }
      unreadCount += 1;
    }
    return unreadCount;
  }

  @override
  Future<void> saveMessageMucStanzaId({
    required String stanzaID,
    required String mucStanzaId,
  }) async {
    final normalizedStanzaId = stanzaID.trim();
    final normalizedMucStanzaId = mucStanzaId.trim();
    if (normalizedStanzaId.isEmpty || normalizedMucStanzaId.isEmpty) {
      return;
    }
    await (update(messages)
          ..where((tbl) => tbl.stanzaID.equals(normalizedStanzaId)))
        .write(MessagesCompanion(mucStanzaId: Value(normalizedMucStanzaId)));
  }

  @override
  Future<void> insertMessageCopy({
    required String shareId,
    required int dcMsgId,
    required int dcChatId,
    int dcAccountId = DeltaAccountDefaults.legacyId,
  }) async {
    await messageCopiesAccessor.insertOrUpdateOne(
      MessageCopiesCompanion.insert(
        shareId: shareId,
        dcMsgId: dcMsgId,
        dcChatId: dcChatId,
        dcAccountId: Value(dcAccountId),
      ),
    );
  }

  @override
  Future<void> assignShareOriginator({
    required String shareId,
    required int originatorDcMsgId,
  }) => messageSharesAccessor.updateOriginator(shareId, originatorDcMsgId);

  @override
  Future<void> saveMessageShareSubject({
    required String shareId,
    required String? subject,
  }) => messageSharesAccessor.updateSubject(shareId, subject);

  @override
  Future<MessageShareData?> getMessageShareByToken(String token) =>
      messageSharesAccessor.selectByToken(token);

  @override
  Future<MessageShareData?> getMessageShareById(String shareId) =>
      messageSharesAccessor.selectOne(shareId);

  @override
  Future<List<MessageParticipantData>> getParticipantsForShare(
    String shareId,
  ) => messageParticipantsAccessor.selectByShare(shareId);

  @override
  Future<List<MessageCopyData>> getMessageCopiesForShare(String shareId) =>
      messageCopiesAccessor.selectByShare(shareId);

  @override
  Future<List<Message>> getMessagesForShare(String shareId) async {
    final query = select(messages).join([
      innerJoin(
        messageCopies,
        messageCopies.dcMsgId.equalsExp(messages.deltaMsgId) &
            messageCopies.dcAccountId.equalsExp(messages.deltaAccountId),
      ),
    ])..where(messageCopies.shareId.equals(shareId));
    final rows = await query.get();
    return rows.map((row) => row.readTable(messages)).toList();
  }

  @override
  Future<String?> getShareIdForDeltaMessage(
    int deltaMsgId, {
    int deltaAccountId = DeltaAccountDefaults.legacyId,
  }) => messageCopiesAccessor.selectShareIdForDeltaMsg(
    deltaMsgId,
    deltaAccountId: deltaAccountId,
  );

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
  Future<int> countDrafts() async {
    final countExpression = drafts.id.count();
    final query = selectOnly(drafts)..addColumns([countExpression]);
    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  @override
  Stream<int> watchConversationMessageCount() {
    final countExpression = messages.stanzaID.count();
    final query = selectOnly(messages)
      ..addColumns([countExpression])
      ..where(
        messages.noStore.equals(false) & messages.pseudoMessageType.isNull(),
      );
    return query.watchSingle().map((row) => row.read(countExpression) ?? 0);
  }

  @override
  Future<int> getConversationMessageCount() async {
    final countExpression = messages.stanzaID.count();
    final query = selectOnly(messages)
      ..addColumns([countExpression])
      ..where(
        messages.noStore.equals(false) & messages.pseudoMessageType.isNull(),
      );
    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  @override
  Future<Draft?> getDraft(int id) => draftsAccessor.selectOne(id);

  @override
  Future<Draft?> getDraftBySyncId(String syncId) {
    final normalized = syncId.trim();
    if (normalized.isEmpty) return Future.value(null);
    final query = select(drafts)
      ..where((tbl) => tbl.draftSyncId.equals(normalized));
    return query.getSingleOrNull();
  }

  @override
  Future<int> saveDraft({
    int? id,
    required List<String> jids,
    required String body,
    required String draftSyncId,
    required DateTime draftUpdatedAt,
    required String draftSourceId,
    required List<DraftRecipientData> draftRecipients,
    String? subject,
    String? quotingStanzaId,
    MessageReferenceKind? quotingReferenceKind,
    List<String> attachmentMetadataIds = const [],
  }) async {
    return transaction(() async {
      final draftId = await draftsAccessor.insertOrUpdateOne(
        DraftsCompanion(
          id: Value.absentIfNull(id),
          jids: Value(jids),
          body: Value(body),
          draftSyncId: Value(draftSyncId),
          draftUpdatedAt: Value(draftUpdatedAt),
          draftSourceId: Value(draftSourceId),
          draftRecipients: Value(draftRecipients),
          subject: Value.absentIfNull(subject),
          quotingStanzaId: Value.absentIfNull(quotingStanzaId),
          quotingReferenceKind: Value.absentIfNull(quotingReferenceKind),
          attachmentMetadataIds: Value(attachmentMetadataIds),
        ),
      );
      await _replaceDraftAttachmentRefs(
        draftId: draftId,
        attachmentMetadataIds: attachmentMetadataIds,
      );
      return draftId;
    });
  }

  @override
  Future<void> updateDraftSyncMetadata({
    required int id,
    required String draftSyncId,
    required DateTime draftUpdatedAt,
    required String draftSourceId,
  }) {
    return draftsAccessor.updateOne(
      DraftsCompanion(
        id: Value(id),
        draftSyncId: Value(draftSyncId),
        draftUpdatedAt: Value(draftUpdatedAt),
        draftSourceId: Value(draftSourceId),
      ),
    );
  }

  @override
  Future<int> upsertDraftFromSync({
    required String draftSyncId,
    required List<String> jids,
    required DateTime draftUpdatedAt,
    required String draftSourceId,
    required List<DraftRecipientData> draftRecipients,
    String? body,
    String? subject,
    String? quotingStanzaId,
    MessageReferenceKind? quotingReferenceKind,
    List<String> attachmentMetadataIds = const [],
  }) async {
    final normalized = draftSyncId.trim();
    if (normalized.isEmpty) return 0;
    final existing = await getDraftBySyncId(normalized);
    if (existing == null) {
      return transaction(() async {
        final draftId = await draftsAccessor.insertOrUpdateOne(
          DraftsCompanion(
            jids: Value(jids),
            draftSyncId: Value(normalized),
            draftUpdatedAt: Value(draftUpdatedAt),
            draftSourceId: Value(draftSourceId),
            draftRecipients: Value(draftRecipients),
            body: Value(body),
            subject: Value(subject),
            quotingStanzaId: Value.absentIfNull(quotingStanzaId),
            quotingReferenceKind: Value.absentIfNull(quotingReferenceKind),
            attachmentMetadataIds: Value(attachmentMetadataIds),
          ),
        );
        await _replaceDraftAttachmentRefs(
          draftId: draftId,
          attachmentMetadataIds: attachmentMetadataIds,
        );
        return draftId;
      });
    }
    await transaction(() async {
      await draftsAccessor.updateOne(
        DraftsCompanion(
          id: Value(existing.id),
          jids: Value(jids),
          draftSyncId: Value(normalized),
          draftUpdatedAt: Value(draftUpdatedAt),
          draftSourceId: Value(draftSourceId),
          draftRecipients: Value(draftRecipients),
          body: Value(body),
          subject: Value(subject),
          quotingStanzaId: Value.absentIfNull(quotingStanzaId),
          quotingReferenceKind: Value.absentIfNull(quotingReferenceKind),
          attachmentMetadataIds: Value(attachmentMetadataIds),
        ),
      );
      await _replaceDraftAttachmentRefs(
        draftId: existing.id,
        attachmentMetadataIds: attachmentMetadataIds,
      );
    });
    return existing.id;
  }

  @override
  Future<void> removeDraft(int id) async {
    await transaction(() async {
      await (delete(
        draftAttachmentRefs,
      )..where((tbl) => tbl.draftId.equals(id))).go();
      await draftsAccessor.deleteOne(id);
    });
  }

  Future<void> _replaceDraftAttachmentRefs({
    required int draftId,
    required List<String> attachmentMetadataIds,
  }) async {
    await (delete(
      draftAttachmentRefs,
    )..where((tbl) => tbl.draftId.equals(draftId))).go();
    final normalizedIds = attachmentMetadataIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (normalizedIds.isEmpty) {
      return;
    }
    await batch((batch) {
      batch.insertAll(
        draftAttachmentRefs,
        normalizedIds
            .map(
              (id) => DraftAttachmentRefsCompanion.insert(
                draftId: draftId,
                fileMetadataId: id,
              ),
            )
            .toList(growable: false),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

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
      return omemoTrustsAccessor.insertOrUpdateOne(
        OmemoTrust(
          device: trust.device,
          jid: trust.jid,
          trust: trust.state,
          enabled: trust.enabled,
          trusted: trust.trusted,
        ),
      );
    });
  }

  @override
  Future<void> setOmemoTrustLabel({
    required String jid,
    required int device,
    required String? label,
  }) => omemoTrustsAccessor.updateOne(
    OmemoTrustsCompanion(
      device: Value(device),
      jid: Value(jid),
      label: Value(label),
    ),
  );

  @override
  Future<void> resetOmemoTrust(String jid) async {
    await transaction(() async {
      final trusts = await (delete(
        omemoTrusts,
      )..where((table) => table.jid.equals(jid))).goAndReturn();
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
        await (delete(omemoRatchets)..where(
              (omemoRatchets) =>
                  omemoRatchets.jid.equals(jid) &
                  omemoRatchets.device.equals(deviceID),
            ))
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
  Future<List<FileMetadataData>> getFileMetadataForIds(Iterable<String> ids) =>
      fileMetadataAccessor.selectForIds(ids.toList(growable: false));

  @override
  Stream<FileMetadataData?> watchFileMetadata(String id) =>
      fileMetadataAccessor.watchOne(id);

  @override
  Future<void> deleteFileMetadata(String id) async {
    await _deleteFileMetadataIfOrphaned(id);
  }

  Future<void> _deleteFileMetadataIfOrphaned(String id) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) return;
    final metadata = await fileMetadataAccessor.selectOne(trimmedId);
    if (metadata == null) return;
    final isReferenced = await _isFileMetadataReferenced(trimmedId);
    if (isReferenced) return;
    await fileMetadataAccessor.deleteOne(trimmedId);
    final path = metadata.path?.trim();
    if (path == null || path.isEmpty) {
      return;
    }
    final hasSiblingMetadata = await (select(
      fileMetadata,
    )..where((tbl) => tbl.path.equals(path))).get();
    if (hasSiblingMetadata.isNotEmpty) {
      return;
    }
    await _deleteManagedAttachmentFile(metadata);
  }

  Future<bool> _isFileMetadataReferenced(String id) async {
    final messageAttachmentRefs =
        await (selectOnly(messageAttachments)
              ..addColumns([messageAttachments.fileMetadataId])
              ..where(messageAttachments.fileMetadataId.equals(id)))
            .get();
    if (messageAttachmentRefs.isNotEmpty) return true;

    final draftAttachmentRows =
        await (selectOnly(draftAttachmentRefs)
              ..addColumns([draftAttachmentRefs.fileMetadataId])
              ..where(draftAttachmentRefs.fileMetadataId.equals(id)))
            .get();
    if (draftAttachmentRows.isNotEmpty) return true;

    final messageRefs =
        await (selectOnly(messages)
              ..addColumns([messages.fileMetadataID])
              ..where(messages.fileMetadataID.equals(id)))
            .get();
    if (messageRefs.isNotEmpty) return true;

    final stickerRefs =
        await (selectOnly(stickers)
              ..addColumns([stickers.fileMetadataID])
              ..where(stickers.fileMetadataID.equals(id)))
            .get();
    if (stickerRefs.isNotEmpty) return true;

    return false;
  }

  Future<Directory> _attachmentRootDirectory() async {
    const attachmentRootDirectoryName = 'attachments';
    final supportDir = await getApplicationSupportDirectory();
    return Directory(p.join(supportDir.path, attachmentRootDirectoryName));
  }

  String? _databasePrefixFromFilePath() {
    final path = _file.path;
    if (path.isEmpty) return null;
    final baseName = p.basename(path);
    if (!baseName.endsWith(_databaseFileSuffix)) {
      return null;
    }
    final prefix = baseName.substring(
      0,
      baseName.length - _databaseFileSuffix.length,
    );
    final trimmed = prefix.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _normalizeAttachmentPrefix(String prefix) {
    const attachmentPrefixFallback = 'shared';
    const attachmentPrefixReplacement = '_';
    final attachmentPrefixSanitizer = RegExp(r'[^a-zA-Z0-9_-]');
    final trimmed = prefix.trim();
    if (trimmed.isEmpty) {
      return attachmentPrefixFallback;
    }
    return trimmed.replaceAll(
      attachmentPrefixSanitizer,
      attachmentPrefixReplacement,
    );
  }

  Future<Directory> _attachmentDirectoryForPrefix(String prefix) async {
    final root = await _attachmentRootDirectory();
    final normalizedPrefix = _normalizeAttachmentPrefix(prefix);
    return Directory(p.join(root.path, normalizedPrefix));
  }

  Future<bool> _isManagedAttachmentPath(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return false;
    final root = await _attachmentRootDirectory();
    final normalizedPath = p.normalize(trimmed);
    final normalizedRoot = p.normalize(root.path);
    return p.isWithin(normalizedRoot, normalizedPath);
  }

  Future<void> _deleteManagedAttachmentFile(FileMetadataData metadata) async {
    final path = metadata.path?.trim();
    if (path == null || path.isEmpty) return;
    if (!await _isManagedAttachmentPath(path)) return;
    final file = File(path);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on Exception {
      // Ignore deletion failures.
    }
  }

  Future<void> _deleteManagedAttachmentFiles(
    Iterable<FileMetadataData> metadataItems,
  ) async {
    for (final metadata in metadataItems) {
      await _deleteManagedAttachmentFile(metadata);
    }
  }

  Iterable<List<T>> _chunked<T>(List<T> items, {required int batchSize}) sync* {
    for (var index = 0; index < items.length; index += batchSize) {
      final end = index + batchSize;
      yield items.sublist(index, end > items.length ? items.length : end);
    }
  }

  @override
  Future<void> addMessageAttachment({
    required String messageId,
    required String fileMetadataId,
    String? transportGroupId,
    int? sortOrder,
  }) async {
    final existing =
        await (select(messageAttachments)..where(
              (tbl) =>
                  tbl.messageId.equals(messageId) &
                  tbl.fileMetadataId.equals(fileMetadataId),
            ))
            .getSingleOrNull();
    if (existing != null) {
      final shouldUpdateGroup =
          transportGroupId != null &&
          existing.transportGroupId != transportGroupId;
      final shouldUpdateOrder =
          sortOrder != null && existing.sortOrder != sortOrder;
      if (shouldUpdateGroup || shouldUpdateOrder) {
        await (update(
          messageAttachments,
        )..where((tbl) => tbl.id.equals(existing.id))).write(
          MessageAttachmentsCompanion(
            transportGroupId: shouldUpdateGroup
                ? Value(transportGroupId)
                : const Value.absent(),
            sortOrder: shouldUpdateOrder
                ? Value(sortOrder)
                : const Value.absent(),
          ),
        );
      }
      return;
    }
    final nextOrder =
        sortOrder ?? await messageAttachmentsAccessor.nextSortOrder(messageId);
    if (nextOrder >= _messageAttachmentMaxCount) {
      _log.warning('Skipping attachment insert after reaching max count.');
      return;
    }
    await into(messageAttachments).insert(
      MessageAttachmentsCompanion.insert(
        messageId: messageId,
        fileMetadataId: fileMetadataId,
        sortOrder: Value(nextOrder),
        transportGroupId: Value.absentIfNull(transportGroupId),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  @override
  Future<void> replaceMessageAttachments({
    required String messageId,
    required List<String> fileMetadataIds,
    String? transportGroupId,
  }) async {
    final trimmedIds = fileMetadataIds.length > _messageAttachmentMaxCount
        ? fileMetadataIds
              .take(_messageAttachmentMaxCount)
              .toList(growable: false)
        : fileMetadataIds;
    if (trimmedIds.length < fileMetadataIds.length) {
      _log.warning('Dropping message attachments beyond max count.');
    }
    await transaction(() async {
      await messageAttachmentsAccessor.deleteForMessage(messageId);
      if (trimmedIds.isEmpty) return;
      const attachmentSortOrderStart = 0;
      const attachmentSortOrderStep = 1;
      var order = attachmentSortOrderStart;
      for (final metadataId in trimmedIds) {
        await into(messageAttachments).insert(
          MessageAttachmentsCompanion.insert(
            messageId: messageId,
            fileMetadataId: metadataId,
            sortOrder: Value(order),
            transportGroupId: Value.absentIfNull(transportGroupId),
          ),
          mode: InsertMode.insertOrIgnore,
        );
        order += attachmentSortOrderStep;
      }
    });
  }

  @override
  Future<List<MessageAttachmentData>> getMessageAttachments(String messageId) =>
      messageAttachmentsAccessor.selectForMessage(messageId);

  @override
  Future<Map<String, List<MessageAttachmentData>>>
  getMessageAttachmentsForMessages(Iterable<String> messageIds) async {
    final ids = messageIds.toList(growable: false);
    if (ids.isEmpty) return const {};
    final attachments = await messageAttachmentsAccessor.selectForMessages(ids);
    final grouped = <String, List<MessageAttachmentData>>{};
    for (final attachment in attachments) {
      grouped.putIfAbsent(attachment.messageId, () => []).add(attachment);
    }
    return grouped;
  }

  @override
  Future<List<MessageAttachmentData>> getMessageAttachmentsForGroup(
    String transportGroupId,
  ) => messageAttachmentsAccessor.selectForGroup(transportGroupId);

  @override
  Future<List<String>> deleteMessageAttachments(String messageId) async {
    final attachments = await messageAttachmentsAccessor.selectForMessage(
      messageId,
    );
    if (attachments.isEmpty) return const [];
    await messageAttachmentsAccessor.deleteForMessage(messageId);
    return attachments.map((attachment) => attachment.fileMetadataId).toList();
  }

  @override
  Stream<List<MessageCollectionMembershipEntry>>
  watchMessageCollectionMemberships(String collectionId, {String? chatJid}) {
    final query = select(messageCollectionMemberships)
      ..where(
        (tbl) =>
            tbl.collectionId.equals(collectionId) & tbl.active.equals(true),
      )
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.addedAt, mode: OrderingMode.desc),
        (tbl) => OrderingTerm(
          expression: tbl.messageReferenceId,
          mode: OrderingMode.desc,
        ),
      ]);
    final normalizedChatJid = chatJid?.trim();
    if (normalizedChatJid != null && normalizedChatJid.isNotEmpty) {
      query.where((tbl) => tbl.chatJid.equals(normalizedChatJid));
    }
    return query.watch();
  }

  @override
  Future<List<MessageCollectionMembershipEntry>>
  getMessageCollectionMemberships(
    String collectionId, {
    String? chatJid,
    bool includeInactive = false,
  }) {
    final query = select(messageCollectionMemberships)
      ..where((tbl) => tbl.collectionId.equals(collectionId))
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.addedAt, mode: OrderingMode.desc),
        (tbl) => OrderingTerm(
          expression: tbl.messageReferenceId,
          mode: OrderingMode.desc,
        ),
      ]);
    if (!includeInactive) {
      query.where((tbl) => tbl.active.equals(true));
    }
    final normalizedChatJid = chatJid?.trim();
    if (normalizedChatJid != null && normalizedChatJid.isNotEmpty) {
      query.where((tbl) => tbl.chatJid.equals(normalizedChatJid));
    }
    return query.get();
  }

  @override
  Future<List<MessageCollectionMembershipEntry>>
  getAllMessageCollectionMemberships({bool includeInactive = false}) {
    final query = select(messageCollectionMemberships)
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.addedAt, mode: OrderingMode.desc),
        (tbl) => OrderingTerm(
          expression: tbl.messageReferenceId,
          mode: OrderingMode.desc,
        ),
      ]);
    if (!includeInactive) {
      query.where((tbl) => tbl.active.equals(true));
    }
    return query.get();
  }

  @override
  Future<MessageCollectionMembershipEntry?> getMessageCollectionMembership({
    required String collectionId,
    required String chatJid,
    required String messageReferenceId,
  }) {
    final query = select(messageCollectionMemberships)
      ..where((tbl) => tbl.collectionId.equals(collectionId))
      ..where((tbl) => tbl.chatJid.equals(chatJid))
      ..where((tbl) => tbl.messageReferenceId.equals(messageReferenceId));
    return query.getSingleOrNull();
  }

  @override
  Future<void> applyMessageCollectionMembershipMutation({
    required String collectionId,
    required String chatJid,
    required String messageReferenceId,
    required String? messageStanzaId,
    required String? messageOriginId,
    required String? messageMucStanzaId,
    required int? deltaAccountId,
    required int? deltaMsgId,
    required DateTime addedAt,
    required bool active,
  }) async {
    final normalizedCollectionId = collectionId.trim();
    final normalizedChatJid = chatJid.trim();
    final normalizedReferenceId = messageReferenceId.trim();
    if (normalizedCollectionId.isEmpty ||
        normalizedChatJid.isEmpty ||
        normalizedReferenceId.isEmpty) {
      return;
    }
    String? normalizeValue(String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return null;
      }
      return trimmed;
    }

    final normalizedAddedAt = addedAt.toUtc();
    final normalizedDeltaAccountId = deltaMsgId == null ? null : deltaAccountId;
    await transaction(() async {
      final existing = await getMessageCollectionMembership(
        collectionId: normalizedCollectionId,
        chatJid: normalizedChatJid,
        messageReferenceId: normalizedReferenceId,
      );
      if (existing != null) {
        final existingAddedAt = existing.addedAt.toUtc();
        if (existingAddedAt.isAfter(normalizedAddedAt)) {
          return;
        }
        final sameTimestamp = existingAddedAt.isAtSameMomentAs(
          normalizedAddedAt,
        );
        final aliasChanged =
            normalizeValue(existing.messageStanzaId) !=
                normalizeValue(messageStanzaId) ||
            normalizeValue(existing.messageOriginId) !=
                normalizeValue(messageOriginId) ||
            normalizeValue(existing.messageMucStanzaId) !=
                normalizeValue(messageMucStanzaId) ||
            existing.deltaAccountId != normalizedDeltaAccountId ||
            existing.deltaMsgId != deltaMsgId;
        if (sameTimestamp &&
            (!existing.active || existing.active == active) &&
            !aliasChanged) {
          return;
        }
      }
      await into(messageCollectionMemberships).insertOnConflictUpdate(
        MessageCollectionMembershipEntry(
          collectionId: normalizedCollectionId,
          chatJid: normalizedChatJid,
          messageReferenceId: normalizedReferenceId,
          messageStanzaId: normalizeValue(messageStanzaId),
          messageOriginId: normalizeValue(messageOriginId),
          messageMucStanzaId: normalizeValue(messageMucStanzaId),
          deltaAccountId: normalizedDeltaAccountId,
          deltaMsgId: deltaMsgId,
          addedAt: normalizedAddedAt,
          active: active,
        ),
      );
    });
  }

  @override
  Future<void> normalizeMessageCollectionMembershipAliases({
    required String collectionId,
    required String chatJid,
    required String canonicalMessageReferenceId,
    required Iterable<String> aliases,
    required String? messageStanzaId,
    required String? messageOriginId,
    required String? messageMucStanzaId,
    required int? deltaAccountId,
    required int? deltaMsgId,
  }) async {
    final normalizedCollectionId = collectionId.trim();
    final normalizedChatJid = chatJid.trim();
    final canonical = canonicalMessageReferenceId.trim();
    if (normalizedCollectionId.isEmpty ||
        normalizedChatJid.isEmpty ||
        canonical.isEmpty) {
      return;
    }
    String? normalizeValue(String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return null;
      }
      return trimmed;
    }

    String? firstNonEmpty(Iterable<String?> values) {
      for (final value in values) {
        final normalized = normalizeValue(value);
        if (normalized != null) {
          return normalized;
        }
      }
      return null;
    }

    final normalizedAliases = <String>{
      canonical,
      for (final alias in aliases)
        if (alias.trim().isNotEmpty) alias.trim(),
    }.toList(growable: false);
    await transaction(() async {
      final existing =
          await (select(messageCollectionMemberships)
                ..where(
                  (tbl) => tbl.collectionId.equals(normalizedCollectionId),
                )
                ..where((tbl) => tbl.chatJid.equals(normalizedChatJid))
                ..where(
                  (tbl) => tbl.messageReferenceId.isIn(normalizedAliases),
                ))
              .get();
      if (existing.isEmpty) {
        return;
      }

      MessageCollectionMembershipEntry latest = existing.first;
      for (final entry in existing.skip(1)) {
        final latestAddedAt = latest.addedAt.toUtc();
        final entryAddedAt = entry.addedAt.toUtc();
        if (entryAddedAt.isAfter(latestAddedAt)) {
          latest = entry;
          continue;
        }
        if (!entryAddedAt.isAtSameMomentAs(latestAddedAt)) {
          continue;
        }
        if (!entry.active && latest.active) {
          latest = entry;
          continue;
        }
        if (entry.messageReferenceId == canonical &&
            latest.messageReferenceId != canonical) {
          latest = entry;
        }
      }

      final resolvedStanzaId = firstNonEmpty([
        messageStanzaId,
        latest.messageStanzaId,
        for (final entry in existing) entry.messageStanzaId,
      ]);
      final resolvedOriginId = firstNonEmpty([
        messageOriginId,
        latest.messageOriginId,
        for (final entry in existing) entry.messageOriginId,
      ]);
      final resolvedMucStanzaId = firstNonEmpty([
        messageMucStanzaId,
        latest.messageMucStanzaId,
        for (final entry in existing) entry.messageMucStanzaId,
      ]);
      final resolvedDeltaMsgId = deltaMsgId ?? latest.deltaMsgId;
      int? resolvedDeltaAccountId;
      if (resolvedDeltaMsgId != null) {
        resolvedDeltaAccountId = deltaAccountId ?? latest.deltaAccountId;
        if (resolvedDeltaAccountId == null) {
          for (final entry in existing) {
            final candidate = entry.deltaAccountId;
            if (candidate == null) {
              continue;
            }
            resolvedDeltaAccountId = candidate;
            break;
          }
        }
      }

      await (delete(messageCollectionMemberships)
            ..where((tbl) => tbl.collectionId.equals(normalizedCollectionId))
            ..where((tbl) => tbl.chatJid.equals(normalizedChatJid))
            ..where((tbl) => tbl.messageReferenceId.isIn(normalizedAliases)))
          .go();
      await into(messageCollectionMemberships).insertOnConflictUpdate(
        MessageCollectionMembershipEntry(
          collectionId: normalizedCollectionId,
          chatJid: normalizedChatJid,
          messageReferenceId: canonical,
          messageStanzaId: resolvedStanzaId,
          messageOriginId: resolvedOriginId,
          messageMucStanzaId: resolvedMucStanzaId,
          deltaAccountId: resolvedDeltaAccountId,
          deltaMsgId: resolvedDeltaMsgId,
          addedAt: latest.addedAt.toUtc(),
          active: latest.active,
        ),
      );
    });
  }

  @override
  Stream<List<PinnedMessageEntry>> watchPinnedMessages(String chatJid) {
    final query = select(pinnedMessages)
      ..where((tbl) => tbl.chatJid.equals(chatJid) & tbl.active.equals(true))
      ..orderBy([
        (tbl) =>
            OrderingTerm(expression: tbl.pinnedAt, mode: OrderingMode.desc),
        (tbl) => OrderingTerm(
          expression: tbl.messageStanzaId,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.watch();
  }

  @override
  Future<List<PinnedMessageEntry>> getPinnedMessages(String chatJid) {
    final query = select(pinnedMessages)
      ..where((tbl) => tbl.chatJid.equals(chatJid) & tbl.active.equals(true))
      ..orderBy([
        (tbl) =>
            OrderingTerm(expression: tbl.pinnedAt, mode: OrderingMode.desc),
        (tbl) => OrderingTerm(
          expression: tbl.messageStanzaId,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.get();
  }

  @override
  Future<PinnedMessageEntry?> getPinnedMessage({
    required String chatJid,
    required String messageStanzaId,
  }) {
    final query = select(pinnedMessages)
      ..where((tbl) => tbl.chatJid.equals(chatJid))
      ..where((tbl) => tbl.messageStanzaId.equals(messageStanzaId));
    return query.getSingleOrNull();
  }

  @override
  Future<void> upsertPinnedMessage(PinnedMessageEntry entry) async {
    await into(pinnedMessages).insertOnConflictUpdate(
      PinnedMessageEntry(
        messageStanzaId: entry.messageStanzaId,
        chatJid: entry.chatJid,
        pinnedAt: entry.pinnedAt.toUtc(),
        active: true,
      ),
    );
  }

  @override
  Future<void> applyPinnedMessageMutation({
    required String chatJid,
    required String messageStanzaId,
    required DateTime pinnedAt,
    required bool active,
  }) async {
    await transaction(() async {
      final normalizedPinnedAt = pinnedAt.toUtc();
      final existing = await getPinnedMessage(
        chatJid: chatJid,
        messageStanzaId: messageStanzaId,
      );
      if (existing != null) {
        final existingPinnedAt = existing.pinnedAt.toUtc();
        if (existingPinnedAt.isAfter(normalizedPinnedAt)) {
          return;
        }
        final sameTimestamp = existingPinnedAt.isAtSameMomentAs(
          normalizedPinnedAt,
        );
        if (sameTimestamp && (!existing.active || existing.active == active)) {
          return;
        }
      }
      await into(pinnedMessages).insertOnConflictUpdate(
        PinnedMessageEntry(
          messageStanzaId: messageStanzaId,
          chatJid: chatJid,
          pinnedAt: normalizedPinnedAt,
          active: active,
        ),
      );
    });
  }

  @override
  Future<void> normalizePinnedMessageAliases({
    required String chatJid,
    required String canonicalMessageStanzaId,
    required Iterable<String> aliases,
  }) async {
    final canonical = canonicalMessageStanzaId.trim();
    if (canonical.isEmpty) {
      return;
    }
    final normalizedAliases = <String>{
      canonical,
      for (final alias in aliases)
        if (alias.trim().isNotEmpty) alias.trim(),
    }.toList(growable: false);
    if (normalizedAliases.length < 2) {
      return;
    }
    await transaction(() async {
      final existing =
          await (select(pinnedMessages)
                ..where((tbl) => tbl.chatJid.equals(chatJid))
                ..where((tbl) => tbl.messageStanzaId.isIn(normalizedAliases)))
              .get();
      if (existing.isEmpty) {
        return;
      }

      PinnedMessageEntry latest = existing.first;
      for (final entry in existing.skip(1)) {
        final latestPinnedAt = latest.pinnedAt.toUtc();
        final entryPinnedAt = entry.pinnedAt.toUtc();
        if (entryPinnedAt.isAfter(latestPinnedAt)) {
          latest = entry;
          continue;
        }
        if (!entryPinnedAt.isAtSameMomentAs(latestPinnedAt)) {
          continue;
        }
        if (!entry.active && latest.active) {
          latest = entry;
          continue;
        }
        if (entry.messageStanzaId == canonical &&
            latest.messageStanzaId != canonical) {
          latest = entry;
        }
      }

      final requiresRewrite =
          latest.messageStanzaId != canonical ||
          existing.any((entry) => entry.messageStanzaId != canonical);
      if (!requiresRewrite) {
        return;
      }

      await (delete(pinnedMessages)
            ..where((tbl) => tbl.chatJid.equals(chatJid))
            ..where((tbl) => tbl.messageStanzaId.isIn(normalizedAliases)))
          .go();
      await into(pinnedMessages).insertOnConflictUpdate(
        PinnedMessageEntry(
          messageStanzaId: canonical,
          chatJid: chatJid,
          pinnedAt: latest.pinnedAt.toUtc(),
          active: latest.active,
        ),
      );
    });
  }

  @override
  Future<void> deletePinnedMessage({
    required String chatJid,
    required String messageStanzaId,
  }) async {
    await (delete(pinnedMessages)
          ..where((tbl) => tbl.chatJid.equals(chatJid))
          ..where((tbl) => tbl.messageStanzaId.equals(messageStanzaId)))
        .go();
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
  Future<List<Chat>> getChatsByJids(Iterable<String> jids) {
    return chatsAccessor.selectForJids(jids.toList(growable: false));
  }

  @override
  Future<List<Chat>> getDeltaChats({int? accountId}) {
    if (accountId == null) {
      return _mergeDeltaChats();
    }
    return _mergeDeltaChatsForAccount(accountId);
  }

  Future<List<Chat>> _mergeDeltaChats() async {
    final Map<String, Chat> resolved = <String, Chat>{};
    final legacy = await (select(
      chats,
    )..where((tbl) => tbl.deltaChatId.isNotNull())).get();
    for (final chat in legacy) {
      resolved[chat.jid] = chat;
    }
    final mapped = await (select(chats).join([
      innerJoin(
        emailChatAccounts,
        emailChatAccounts.chatJid.equalsExp(chats.jid),
      ),
    ])).get();
    for (final row in mapped) {
      final chat = row.readTable(chats);
      resolved[chat.jid] = chat;
    }
    return resolved.values.toList(growable: false);
  }

  Future<List<Chat>> _mergeDeltaChatsForAccount(int accountId) async {
    final Map<String, Chat> resolved = <String, Chat>{};
    if (accountId == DeltaAccountDefaults.legacyId) {
      final legacy = await (select(
        chats,
      )..where((tbl) => tbl.deltaChatId.isNotNull())).get();
      for (final chat in legacy) {
        resolved[chat.jid] = chat;
      }
    }
    final mapped = await (select(chats).join([
      innerJoin(
        emailChatAccounts,
        emailChatAccounts.chatJid.equalsExp(chats.jid),
      ),
    ])..where(emailChatAccounts.deltaAccountId.equals(accountId))).get();
    for (final row in mapped) {
      final chat = row.readTable(chats);
      resolved[chat.jid] = chat;
    }
    return resolved.values.toList(growable: false);
  }

  Selectable<String> _recipientAddressSuggestionsQuery({int? limit}) {
    final query = select(recipientAddresses)
      ..orderBy([
        (tbl) =>
            OrderingTerm(expression: tbl.lastSeen, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.map((row) => row.address);
  }

  @override
  Stream<List<String>> watchRecipientAddressSuggestions({int? limit}) =>
      _recipientAddressSuggestionsQuery(limit: limit).watch();

  @override
  Future<List<String>> getRecipientAddressSuggestions({int? limit}) =>
      _recipientAddressSuggestionsQuery(limit: limit).get();

  @override
  Future<Chat?> getChat(String jid) => chatsAccessor.selectOne(jid);

  @override
  Future<Chat?> getOpenChat() => chatsAccessor.selectOpen();

  @override
  Future<Chat?> getChatByDeltaChatId(int deltaChatId, {int? accountId}) async {
    final resolvedAccountId = accountId ?? DeltaAccountDefaults.legacyId;
    final query =
        select(chats).join([
          innerJoin(
            emailChatAccounts,
            emailChatAccounts.chatJid.equalsExp(chats.jid),
          ),
        ])..where(
          emailChatAccounts.deltaChatId.equals(deltaChatId) &
              emailChatAccounts.deltaAccountId.equals(resolvedAccountId),
        );
    final row = await query.getSingleOrNull();
    if (row != null) {
      return row.readTable(chats);
    }
    if (accountId != null) {
      return null;
    }
    return (select(
      chats,
    )..where((tbl) => tbl.deltaChatId.equals(deltaChatId))).getSingleOrNull();
  }

  @override
  Stream<Chat?> watchChatByDeltaChatId(int deltaChatId, {int? accountId}) {
    final resolvedAccountId = accountId ?? DeltaAccountDefaults.legacyId;
    final query =
        select(chats).join([
          innerJoin(
            emailChatAccounts,
            emailChatAccounts.chatJid.equalsExp(chats.jid),
          ),
        ])..where(
          emailChatAccounts.deltaChatId.equals(deltaChatId) &
              emailChatAccounts.deltaAccountId.equals(resolvedAccountId),
        );
    final mappedStream = query.watchSingleOrNull().map(
      (row) => row?.readTable(chats),
    );
    if (accountId != null) {
      return mappedStream;
    }
    return mappedStream.asyncMap((mapped) async {
      if (mapped != null) {
        return mapped;
      }
      return (select(
        chats,
      )..where((tbl) => tbl.deltaChatId.equals(deltaChatId))).getSingleOrNull();
    });
  }

  @override
  Future<void> upsertEmailChatAccount({
    required String chatJid,
    required int deltaAccountId,
    required int deltaChatId,
  }) async {
    await into(emailChatAccounts).insertOnConflictUpdate(
      EmailChatAccountsCompanion.insert(
        chatJid: chatJid,
        deltaAccountId: Value(deltaAccountId),
        deltaChatId: deltaChatId,
      ),
    );
  }

  @override
  Future<int?> getDeltaChatIdForAccount({
    required String chatJid,
    required int deltaAccountId,
  }) async {
    final query = select(emailChatAccounts)
      ..where(
        (tbl) =>
            tbl.chatJid.equals(chatJid) &
            tbl.deltaAccountId.equals(deltaAccountId),
      );
    final row = await query.getSingleOrNull();
    return row?.deltaChatId;
  }

  @override
  Future<void> deleteEmailChatAccount({
    required String chatJid,
    required int deltaAccountId,
  }) async {
    await (delete(emailChatAccounts)..where(
          (tbl) =>
              tbl.chatJid.equals(chatJid) &
              tbl.deltaAccountId.equals(deltaAccountId),
        ))
        .go();
  }

  @override
  Future<void> deleteEmailChatAccountsForAccount(int deltaAccountId) async {
    await (delete(
      emailChatAccounts,
    )..where((tbl) => tbl.deltaAccountId.equals(deltaAccountId))).go();
  }

  @override
  Future<int> countEmailChatAccounts(String chatJid) async {
    final countExpression = emailChatAccounts.chatJid.count();
    final query = selectOnly(emailChatAccounts)
      ..addColumns([countExpression])
      ..where(emailChatAccounts.chatJid.equals(chatJid));
    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  @override
  Future<void> createChat(Chat chat) async {
    const summaryFilter = MessageTimelineFilter.allWithContact;
    final lastMessage = await getLastMessageForChat(
      chat.jid,
      filter: summaryFilter,
    );
    final lastMessagePreview = await _messagePreview(
      trimmedBody: lastMessage?.body?.trim(),
      subject: lastMessage?.subject,
      deltaChatId: lastMessage?.deltaChatId,
      deltaMsgId: lastMessage?.deltaMsgId,
      fileMetadataId: lastMessage?.fileMetadataID,
      hasAttachment: lastMessage?.fileMetadataID?.isNotEmpty == true,
      pseudoMessageType: lastMessage?.pseudoMessageType,
      pseudoMessageData: lastMessage?.pseudoMessageData,
    );

    return await chatsAccessor.insertOne(
      chat.copyWith(
        lastMessage: lastMessagePreview,
        lastChangeTimestamp: lastMessage?.timestamp ?? chat.lastChangeTimestamp,
      ),
    );
  }

  @override
  Future<void> updateChat(Chat chat) => chatsAccessor.updateOne(chat);

  @override
  Future<void> updateConversationIndexChatMeta({
    required String jid,
    required DateTime lastChangeTimestamp,
    required bool muted,
    required bool favorited,
    required bool archived,
    required String contactJid,
  }) async {
    await customUpdate(
      '''
UPDATE chats
SET last_change_timestamp = CASE
      WHEN last_change_timestamp IS NULL OR last_change_timestamp < ? THEN ?
      ELSE last_change_timestamp
    END,
    muted = ?,
    favorited = ?,
    archived = ?,
    contact_jid = ?
WHERE jid = ?
''',
      variables: [
        Variable<DateTime>(lastChangeTimestamp),
        Variable<DateTime>(lastChangeTimestamp),
        Variable<bool>(muted),
        Variable<bool>(favorited),
        Variable<bool>(archived),
        Variable<String>(contactJid),
        Variable<String>(jid),
      ],
      updates: {chats},
    );
  }

  @override
  Future<void> updateConversationIndexArchived({
    required String jid,
    required bool archived,
  }) async {
    await (update(chats)..where((tbl) => tbl.jid.equals(jid))).write(
      ChatsCompanion(archived: Value(archived)),
    );
  }

  @override
  Future<void> repairChatSummaryPreservingTimestamp(String jid) async {
    const summaryFilter = MessageTimelineFilter.allWithContact;
    final chat = await getChat(jid);
    if (chat == null) {
      return;
    }
    final lastMessage = await getLastMessageForChat(jid, filter: summaryFilter);
    final lastMessagePreview = await _messagePreview(
      trimmedBody: lastMessage?.body?.trim(),
      subject: lastMessage?.subject,
      deltaChatId: lastMessage?.deltaChatId,
      deltaMsgId: lastMessage?.deltaMsgId,
      fileMetadataId: lastMessage?.fileMetadataID,
      hasAttachment: lastMessage?.fileMetadataID?.isNotEmpty == true,
      pseudoMessageType: lastMessage?.pseudoMessageType,
      pseudoMessageData: lastMessage?.pseudoMessageData,
    );
    final DateTime nextTimestamp = switch (lastMessage?.timestamp) {
      final DateTime timestamp
          when timestamp.isAfter(chat.lastChangeTimestamp) =>
        timestamp,
      _ => chat.lastChangeTimestamp,
    };
    final updated = chat.copyWith(
      lastMessage: lastMessagePreview,
      lastChangeTimestamp: nextTimestamp,
    );
    if (updated != chat) {
      await chatsAccessor.updateOne(updated);
    }
  }

  @override
  Future<void> clearChatsEmailFromAddress(String address) async {
    final normalizedAddress = _normalizeEmail(address);
    if (normalizedAddress.isEmpty) {
      return;
    }
    final query = update(chats)
      ..where((tbl) => tbl.emailFromAddress.equals(normalizedAddress));
    const clearedEmailFromAddress = ChatsCompanion(
      emailFromAddress: Value<String?>(null),
    );
    await query.write(clearedEmailFromAddress);
  }

  @override
  Stream<Chat?> watchChat(String jid) {
    return chatsAccessor.watchOne(jid);
  }

  @override
  Future<Chat?> openChat(String jid) async {
    const summaryFilter = MessageTimelineFilter.allWithContact;
    final normalizedJid = jid.trim();
    final lastMessage = await getLastMessageForChat(
      normalizedJid,
      filter: summaryFilter,
    );
    final lastMessagePreview = await _messagePreview(
      trimmedBody: lastMessage?.body?.trim(),
      subject: lastMessage?.subject,
      deltaChatId: lastMessage?.deltaChatId,
      deltaMsgId: lastMessage?.deltaMsgId,
      fileMetadataId: lastMessage?.fileMetadataID,
      hasAttachment: lastMessage?.fileMetadataID?.isNotEmpty == true,
      pseudoMessageType: lastMessage?.pseudoMessageType,
      pseudoMessageData: lastMessage?.pseudoMessageData,
    );

    return await transaction(() async {
      final closed = await closeChat();
      final existing = await getChat(normalizedJid);
      if (existing == null) {
        await into(chats).insert(
          ChatsCompanion.insert(
            jid: normalizedJid,
            title: _chatTitleForIdentifier(normalizedJid),
            type: ChatType.chat,
            open: const Value(true),
            unreadCount: const Value(0),
            chatState: const Value(mox.ChatState.active),
            lastMessage: Value(lastMessagePreview),
            lastChangeTimestamp: lastMessage?.timestamp ?? DateTime.timestamp(),
            contactJid: Value(normalizedJid),
          ),
        );
        return closed;
      }
      await chatsAccessor.updateOne(
        existing.copyWith(
          open: true,
          unreadCount: existing.defaultTransport.isEmail
              ? existing.unreadCount
              : 0,
          chatState: mox.ChatState.active,
        ),
      );
      return closed;
    });
  }

  @override
  Future<Chat?> closeChat() async =>
      (await chatsAccessor.closeOpen()).firstOrNull;

  @override
  Future<void> markChatMuted({required String jid, required bool muted}) async {
    _log.info('Updating chat muted state');
    await (update(chats)..where((chats) => chats.jid.equals(jid))).write(
      ChatsCompanion(muted: Value(muted)),
    );
  }

  @override
  Future<void> setChatNotificationPreviewSetting({
    required String jid,
    required NotificationPreviewSetting? setting,
  }) async {
    _log.info('Updating chat notification preview setting');
    await (update(chats)..where((chats) => chats.jid.equals(jid))).write(
      ChatsCompanion(notificationPreviewSetting: Value(setting)),
    );
  }

  @override
  Future<void> setChatShareSignature({
    required String jid,
    required bool? enabled,
  }) async {
    _log.info('Updating chat share signature');
    await (update(chats)..where((chats) => chats.jid.equals(jid))).write(
      ChatsCompanion(shareSignatureEnabled: Value(enabled)),
    );
  }

  @override
  Future<void> setChatAttachmentAutoDownload({
    required String jid,
    required AttachmentAutoDownload? value,
  }) async {
    _log.info('Updating chat attachment auto-download state');
    await (update(chats)..where((chats) => chats.jid.equals(jid))).write(
      ChatsCompanion(attachmentAutoDownload: Value(value)),
    );
  }

  @override
  Future<void> markChatFavorited({
    required String jid,
    required bool favorited,
  }) async {
    _log.info('Updating chat favorite state');
    await (update(chats)..where((chats) => chats.jid.equals(jid))).write(
      ChatsCompanion(favorited: Value(favorited)),
    );
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
        .write(MessagesCompanion(chatJid: Value(archivedJid)));
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
        DraftsCompanion(id: Value(draft.id), jids: Value(updated)),
      );
    }
  }

  @override
  Future<void> markChatHidden({
    required String jid,
    required bool hidden,
  }) async {
    _log.info('Updating chat hidden state');
    await (update(chats)..where((chats) => chats.jid.equals(jid))).write(
      ChatsCompanion(hidden: Value(hidden)),
    );
  }

  @override
  Future<void> markChatSpam({
    required String jid,
    required bool spam,
    DateTime? spamUpdatedAt,
  }) async {
    final resolvedUpdatedAt = spam
        ? (spamUpdatedAt ?? DateTime.timestamp())
        : null;
    await (update(chats)..where((tbl) => tbl.jid.equals(jid))).write(
      ChatsCompanion(
        spam: Value(spam),
        spamUpdatedAt: Value(resolvedUpdatedAt),
      ),
    );
  }

  @override
  Future<void> markEmailChatsSpam({
    required String address,
    required bool spam,
    DateTime? spamUpdatedAt,
  }) async {
    final normalized = _normalizeEmail(address);
    if (normalized.isEmpty) {
      return;
    }
    final resolvedUpdatedAt = spam
        ? (spamUpdatedAt ?? DateTime.timestamp())
        : null;
    await (update(chats)..where(
          (tbl) =>
              (tbl.transport.equals(MessageTransport.email.index) |
                  tbl.deltaChatId.isNotNull() |
                  tbl.emailAddress.isNotNull() |
                  tbl.emailFromAddress.isNotNull()) &
              (tbl.jid.equals(normalized) |
                  tbl.contactJid.equals(normalized) |
                  tbl.contactID.equals(normalized) |
                  tbl.emailAddress.equals(normalized) |
                  tbl.emailFromAddress.equals(normalized)),
        ))
        .write(
          ChatsCompanion(
            spam: Value(spam),
            spamUpdatedAt: Value(resolvedUpdatedAt),
          ),
        );
  }

  @override
  Future<void> updateChatAvatar({
    required String jid,
    required String? avatarPath,
    required String? avatarHash,
  }) async {
    await (update(
      chats,
    )..where((tbl) => tbl.jid.equals(jid) | tbl.contactJid.equals(jid))).write(
      ChatsCompanion(
        avatarPath: Value(avatarPath),
        avatarHash: Value(avatarHash),
      ),
    );
  }

  @override
  Future<void> clearAvatarReferencesForPath({required String path}) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) return;

    await transaction(() async {
      await (update(
        roster,
      )..where((tbl) => tbl.avatarPath.equals(normalizedPath))).write(
        const RosterCompanion(
          avatarPath: Value<String?>(null),
          avatarHash: Value<String?>(null),
        ),
      );
      await (update(
        roster,
      )..where((tbl) => tbl.contactAvatarPath.equals(normalizedPath))).write(
        const RosterCompanion(contactAvatarPath: Value<String?>(null)),
      );
      await (update(
        chats,
      )..where((tbl) => tbl.avatarPath.equals(normalizedPath))).write(
        const ChatsCompanion(
          avatarPath: Value<String?>(null),
          avatarHash: Value<String?>(null),
        ),
      );
      await (update(
        chats,
      )..where((tbl) => tbl.contactAvatarPath.equals(normalizedPath))).write(
        const ChatsCompanion(
          contactAvatarPath: Value<String?>(null),
          contactAvatarHash: Value<String?>(null),
        ),
      );
    });
  }

  @override
  Future<void> markChatMarkerResponsive({
    required String jid,
    required bool? responsive,
  }) async {
    _log.info('Updating chat marker responsiveness');
    await (update(chats)..where((chats) => chats.jid.equals(jid))).write(
      ChatsCompanion(markerResponsive: Value(responsive)),
    );
  }

  @override
  Future<void> markChatsMarkerResponsive({required bool responsive}) async {
    _log.info('Updating marker responsiveness for all chats');
    await (update(
      chats,
    )).write(ChatsCompanion(markerResponsive: Value(responsive)));
  }

  @override
  Future<void> updateChatState({
    required String chatJid,
    required mox.ChatState state,
  }) async {
    _log.info('Updating chat state');
    await chatsAccessor.updateOne(
      ChatsCompanion(jid: Value(chatJid), chatState: Value(state)),
    );
  }

  @override
  Future<void> updateChatAlert({
    required String chatJid,
    required String? alert,
  }) async {
    _log.info('Updating chat alert');
    await chatsAccessor.updateOne(
      ChatsCompanion(jid: Value(chatJid), alert: Value(alert)),
    );
  }

  @override
  Future<void> updateChatEncryption({
    required String chatJid,
    required EncryptionProtocol protocol,
  }) async {
    _log.info('Updating chat encryption protocol');
    await chatsAccessor.updateOne(
      ChatsCompanion(jid: Value(chatJid), encryptionProtocol: Value(protocol)),
    );
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
    final emptyTimestamp = DateTime.fromMillisecondsSinceEpoch(
      _emptyTimestampMillis,
    );
    await transaction(() async {
      await createChat(
        Chat.fromJid(item.jid).copyWith(lastChangeTimestamp: emptyTimestamp),
      );
      await rosterAccessor.insertOrUpdateOne(item);
      await invitesAccessor.deleteOne(item.jid);
    });
  }

  @override
  Future<void> saveRosterItems(List<RosterItem> items) async {
    if (items.isEmpty) return;
    final emptyTimestamp = DateTime.fromMillisecondsSinceEpoch(
      _emptyTimestampMillis,
    );
    await transaction(() async {
      await batch((batch) {
        batch.insertAll(
          chats,
          items
              .map(
                (item) => ChatsCompanion.insert(
                  jid: item.jid,
                  title: _chatTitleForIdentifier(item.jid),
                  type: ChatType.chat,
                  lastChangeTimestamp: emptyTimestamp,
                  contactJid: Value(item.jid),
                ),
              )
              .toList(growable: false),
          mode: InsertMode.insertOrIgnore,
        );
        batch.insertAll(roster, items, mode: InsertMode.insertOrReplace);
      });
      final jids = items.map((item) => item.jid).toList(growable: false);
      for (final batch in _chunked(jids, batchSize: 900)) {
        await (delete(invites)..where((tbl) => tbl.jid.isIn(batch))).go();
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
    if (items.isEmpty) return;
    await transaction(() async {
      await batch((batch) {
        batch.insertAll(roster, items, mode: InsertMode.insertOrReplace);
      });
      final jids = items.map((item) => item.jid).toList(growable: false);
      for (final batch in _chunked(jids, batchSize: 900)) {
        await (delete(invites)..where((tbl) => tbl.jid.isIn(batch))).go();
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
    await rosterAccessor.updateOne(
      RosterCompanion(
        jid: Value(jid),
        presence: Value(presence),
        status: Value(status),
      ),
    );
  }

  @override
  Future<void> updateRosterSubscription({
    required String jid,
    required Subscription subscription,
  }) async {
    _log.info('Updating roster subscription');
    await rosterAccessor.updateOne(
      RosterCompanion(jid: Value(jid), subscription: Value(subscription)),
    );
  }

  @override
  Future<void> updateRosterAsk({required String jid, Ask? ask}) async {
    _log.info('Updating roster ask state');
    await rosterAccessor.updateOne(
      RosterCompanion(jid: Value(jid), ask: Value(ask)),
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
      await rosterAccessor.updateOne(
        RosterCompanion(
          jid: Value(jid),
          subscription: const Value(Subscription.both),
        ),
      );
      await invitesAccessor.deleteOne(jid);
    });
  }

  @override
  Stream<List<Invite>> watchInvites({required int start, required int end}) {
    _log.info('Loading invites from database...');
    return invitesAccessor.watchAll();
  }

  @override
  Future<List<Invite>> getInvites({
    required int start,
    required int end,
  }) async {
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
  Future<bool> isJidBlocked(String jid) async {
    final normalized = _normalizeBlocklistJid(jid);
    if (normalized == null) {
      return false;
    }
    return await blocklistAccessor.selectOne(normalized) != null;
  }

  @override
  Future<void> blockJid(String jid) async {
    _log.info('Adding to blocklist');
    final normalized = _normalizeBlocklistJid(jid);
    if (normalized == null) {
      return;
    }
    await blocklistAccessor.insertOne(
      BlocklistCompanion.insert(
        jid: normalized,
        blockedAt: Value(DateTime.timestamp().toUtc()),
      ),
    );
  }

  @override
  Future<void> blockJids(List<String> jids) async {
    final normalizedJids = <String>{};
    for (final jid in jids) {
      final normalized = _normalizeBlocklistJid(jid);
      if (normalized != null) {
        normalizedJids.add(normalized);
      }
    }
    if (normalizedJids.isEmpty) {
      return;
    }
    await transaction(() async {
      for (final jid in normalizedJids) {
        _log.info('Adding to blocklist');
        await blocklistAccessor.insertOne(
          BlocklistCompanion.insert(
            jid: jid,
            blockedAt: Value(DateTime.timestamp().toUtc()),
          ),
        );
      }
    });
  }

  @override
  Future<void> unblockJid(String jid) async {
    _log.info('Removing from blocklist');
    final normalized = _normalizeBlocklistJid(jid);
    if (normalized == null) {
      return;
    }
    await blocklistAccessor.deleteOne(normalized);
  }

  @override
  Future<void> unblockJids(List<String> jids) async {
    final normalizedJids = <String>{};
    for (final jid in jids) {
      final normalized = _normalizeBlocklistJid(jid);
      if (normalized != null) {
        normalizedJids.add(normalized);
      }
    }
    if (normalizedJids.isEmpty) {
      return;
    }
    await transaction(() async {
      for (final jid in normalizedJids) {
        _log.info('Removing from blocklist');
        await blocklistAccessor.deleteOne(jid);
      }
    });
  }

  @override
  Future<void> replaceBlocklist(List<String> blocks) async {
    _log.info('Replacing blocklist...');
    final existing = await blocklistAccessor.selectAll();
    final blockedAtByJid = <String, DateTime>{
      for (final entry in existing)
        ?_normalizeBlocklistJid(entry.jid): entry.blockedAt,
    };
    final normalizedBlocks = <String>{};
    for (final blocked in blocks) {
      final normalized = _normalizeBlocklistJid(blocked);
      if (normalized != null) {
        normalizedBlocks.add(normalized);
      }
    }
    await transaction(() async {
      final existingKeys = blockedAtByJid.keys.toSet();
      final toDelete = existingKeys.difference(normalizedBlocks).toList();
      if (toDelete.isNotEmpty) {
        for (final batch in _chunked(toDelete, batchSize: 900)) {
          await (delete(blocklist)..where((tbl) => tbl.jid.isIn(batch))).go();
        }
      }
      final toInsert = normalizedBlocks.difference(existingKeys);
      for (final blocked in toInsert) {
        final blockedAt = (blockedAtByJid[blocked] ?? DateTime.timestamp())
            .toUtc();
        await blocklistAccessor.insertOne(
          BlocklistCompanion.insert(jid: blocked, blockedAt: Value(blockedAt)),
        );
      }
    });
  }

  @override
  Future<void> deleteBlocklist() async {
    _log.info('Deleting blocklist...');
    await blocklistAccessor.deleteAll();
  }

  @override
  Future<void> replaceContacts(Map<String, String> contactsByNativeId) async {
    await transaction(() async {
      final existing = await select(contacts).get();
      final existingById = <String, String>{
        for (final entry in existing) entry.nativeID: entry.jid,
      };
      final toDelete = existingById.keys
          .where((id) => !contactsByNativeId.containsKey(id))
          .toList();
      if (toDelete.isNotEmpty) {
        for (final batch in _chunked(toDelete, batchSize: 900)) {
          await (delete(
            contacts,
          )..where((tbl) => tbl.nativeID.isIn(batch))).go();
        }
      }
      final upserts = <ContactsCompanion>[];
      for (final entry in contactsByNativeId.entries) {
        final existingJid = existingById[entry.key];
        if (existingJid == entry.value) {
          continue;
        }
        upserts.add(
          ContactsCompanion.insert(nativeID: entry.key, jid: entry.value),
        );
      }
      if (upserts.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(contacts, upserts, mode: InsertMode.insertOrReplace);
        });
      }
    });
  }

  @override
  Stream<List<EmailBlocklistEntry>> watchEmailBlocklist() =>
      emailBlocklistAccessor.watchEntries();

  @override
  Future<List<EmailBlocklistEntry>> getEmailBlocklist() =>
      emailBlocklistAccessor.selectEntries();

  @override
  Future<EmailBlocklistEntry?> getEmailBlocklistEntry(String address) =>
      emailBlocklistAccessor.selectOne(address);

  @override
  Future<void> addEmailBlock(
    String address, {
    DateTime? blockedAt,
    String? sourceId,
  }) async {
    final normalized = _normalizeEmail(address);
    if (normalized.isEmpty) {
      return;
    }
    final resolvedBlockedAt = (blockedAt ?? DateTime.timestamp()).toUtc();
    await customStatement(
      '''
INSERT INTO email_blocklist(address, blocked_at, source_id)
VALUES(?, ?, ?)
ON CONFLICT(address) DO UPDATE SET
  blocked_at = excluded.blocked_at,
  source_id = COALESCE(excluded.source_id, email_blocklist.source_id)
''',
      [normalized, resolvedBlockedAt.toIso8601String(), sourceId],
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
INSERT INTO email_blocklist(
  address,
  blocked_at,
  blocked_message_count,
  last_blocked_message_at,
  source_id
)
VALUES(?, CURRENT_TIMESTAMP, 1, CURRENT_TIMESTAMP, ?)
ON CONFLICT(address) DO UPDATE SET
  blocked_message_count = blocked_message_count + 1,
  last_blocked_message_at = excluded.last_blocked_message_at
''',
      [normalized, null],
    );
  }

  @override
  Stream<List<EmailSpamEntry>> watchEmailSpamlist() =>
      emailSpamlistAccessor.watchEntries();

  @override
  Future<List<EmailSpamEntry>> getEmailSpamlist() =>
      emailSpamlistAccessor.selectEntries();

  @override
  Future<EmailSpamEntry?> getEmailSpamEntry(String address) =>
      emailSpamlistAccessor.selectOne(address);

  @override
  Future<void> addEmailSpam(
    String address, {
    DateTime? flaggedAt,
    String? sourceId,
  }) async {
    final normalized = _normalizeEmail(address);
    if (normalized.isEmpty) {
      return;
    }
    final resolvedFlaggedAt = (flaggedAt ?? DateTime.timestamp()).toUtc();
    await customStatement(
      '''
INSERT INTO email_spamlist(address, flagged_at, source_id)
VALUES(?, ?, ?)
ON CONFLICT(address) DO UPDATE SET
  flagged_at = excluded.flagged_at,
  source_id = COALESCE(excluded.source_id, email_spamlist.source_id)
''',
      [normalized, resolvedFlaggedAt.toIso8601String(), sourceId],
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

  Future<bool> _tableHasColumn(String tableName, String columnName) async {
    final rows = await customSelect('PRAGMA table_info("$tableName")').get();
    for (final row in rows) {
      final name = row.data['name']?.toString().trim();
      if (name == columnName) {
        return true;
      }
    }
    return false;
  }

  Future<void> _rebuildChatsTable(Migrator m) async {
    const tableName = 'chats';
    const tempTableName = '${tableName}_old';
    const columnNames = <String>[
      'jid',
      'title',
      'type',
      'my_nickname',
      'avatar_path',
      'avatar_hash',
      'last_message',
      'alert',
      'last_change_timestamp',
      'unread_count',
      'open',
      'muted',
      'notification_preview_setting',
      'favorited',
      'archived',
      'hidden',
      'spam',
      'spam_updated_at',
      'marker_responsive',
      'share_signature_enabled',
      'attachment_auto_download',
      'encryption_protocol',
      'contact_i_d',
      'contact_display_name',
      'contact_avatar_path',
      'contact_avatar_hash',
      'contact_jid',
      'chat_state',
      'delta_chat_id',
      'email_address',
      'email_from_address',
    ];
    final columns = columnNames.join(', ');
    await customStatement('ALTER TABLE $tableName RENAME TO $tempTableName');
    await m.createTable(chats);
    await customStatement('''
INSERT INTO $tableName ($columns)
SELECT
  jid,
  title,
  type,
  my_nickname,
  avatar_path,
  avatar_hash,
  last_message,
  alert,
  last_change_timestamp,
  unread_count,
  open,
  muted,
  NULL AS notification_preview_setting,
  favorited,
  archived,
  hidden,
  spam,
  spam_updated_at,
  NULL AS marker_responsive,
  NULL AS share_signature_enabled,
  NULL AS attachment_auto_download,
  encryption_protocol,
  contact_i_d,
  contact_display_name,
  contact_avatar_path,
  contact_avatar_hash,
  contact_jid,
  chat_state,
  delta_chat_id,
  email_address,
  email_from_address
FROM $tempTableName
''');
    await customStatement('DROP TABLE $tempTableName');
  }

  Future<void> _createMessageSearchInfrastructure() async {
    await customStatement('''
CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts
USING fts5(
  body,
  content='messages',
  content_rowid='rowid'
)
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS messages_ai
AFTER INSERT ON messages
BEGIN
  INSERT INTO messages_fts(rowid, body)
  VALUES (new.rowid, new.body);
END
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS messages_ad
AFTER DELETE ON messages
BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, body)
  VALUES ('delete', old.rowid, old.body);
END
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS messages_au
AFTER UPDATE ON messages
BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, body)
  VALUES ('delete', old.rowid, old.body);
  INSERT INTO messages_fts(rowid, body)
  VALUES (new.rowid, new.body);
END
''');
    await customStatement(
      "INSERT INTO messages_fts(messages_fts) VALUES('rebuild')",
    );
  }

  Future<void> _createRecipientAddressTriggers() async {
    const upsertClause =
        'ON CONFLICT(address) DO UPDATE SET last_seen = '
        'CASE WHEN excluded.last_seen > recipient_addresses.last_seen '
        'THEN excluded.last_seen ELSE recipient_addresses.last_seen END';
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS recipient_addresses_messages_ai
AFTER INSERT ON messages
BEGIN
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.sender_jid)), new.timestamp
  WHERE new.sender_jid IS NOT NULL
    AND trim(new.sender_jid) != ''
    AND instr(new.sender_jid, '@') > 0
  $upsertClause;
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.chat_jid)), new.timestamp
  WHERE new.chat_jid IS NOT NULL
    AND trim(new.chat_jid) != ''
    AND instr(new.chat_jid, '@') > 0
  $upsertClause;
END
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS recipient_addresses_chats_ai
AFTER INSERT ON chats
BEGIN
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.jid)), new.last_change_timestamp
  WHERE new.jid IS NOT NULL
    AND trim(new.jid) != ''
    AND instr(new.jid, '@') > 0
  $upsertClause;
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.contact_jid)), new.last_change_timestamp
  WHERE new.contact_jid IS NOT NULL
    AND trim(new.contact_jid) != ''
    AND instr(new.contact_jid, '@') > 0
  $upsertClause;
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.email_address)), new.last_change_timestamp
  WHERE new.email_address IS NOT NULL
    AND trim(new.email_address) != ''
    AND instr(new.email_address, '@') > 0
  $upsertClause;
END
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS recipient_addresses_chats_au
AFTER UPDATE OF last_change_timestamp, jid, contact_jid, email_address ON chats
BEGIN
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.jid)), new.last_change_timestamp
  WHERE new.jid IS NOT NULL
    AND trim(new.jid) != ''
    AND instr(new.jid, '@') > 0
  $upsertClause;
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.contact_jid)), new.last_change_timestamp
  WHERE new.contact_jid IS NOT NULL
    AND trim(new.contact_jid) != ''
    AND instr(new.contact_jid, '@') > 0
  $upsertClause;
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.email_address)), new.last_change_timestamp
  WHERE new.email_address IS NOT NULL
    AND trim(new.email_address) != ''
    AND instr(new.email_address, '@') > 0
  $upsertClause;
END
''');
  }

  Future<void> _backfillRecipientAddresses() async {
    await customStatement('''
INSERT INTO recipient_addresses(address, last_seen)
SELECT address, MAX(ts)
FROM (
  SELECT lower(trim(jid)) AS address, last_change_timestamp AS ts
  FROM chats
  WHERE jid IS NOT NULL AND jid != '' AND instr(jid, '@') > 0
  UNION ALL
  SELECT lower(trim(contact_jid)) AS address, last_change_timestamp AS ts
  FROM chats
  WHERE contact_jid IS NOT NULL AND contact_jid != '' AND instr(contact_jid, '@') > 0
  UNION ALL
  SELECT lower(trim(email_address)) AS address, last_change_timestamp AS ts
  FROM chats
  WHERE email_address IS NOT NULL AND email_address != '' AND instr(email_address, '@') > 0
  UNION ALL
  SELECT lower(trim(sender_jid)) AS address, timestamp AS ts
  FROM messages
  WHERE sender_jid IS NOT NULL AND sender_jid != '' AND instr(sender_jid, '@') > 0
  UNION ALL
  SELECT lower(trim(chat_jid)) AS address, timestamp AS ts
  FROM messages
  WHERE chat_jid IS NOT NULL AND chat_jid != '' AND instr(chat_jid, '@') > 0
)
GROUP BY address
ON CONFLICT(address) DO UPDATE SET last_seen =
  CASE WHEN excluded.last_seen > recipient_addresses.last_seen
       THEN excluded.last_seen ELSE recipient_addresses.last_seen END
''');
  }

  Future<void> _backfillDraftAttachmentRefs() async {
    await customStatement('''
INSERT INTO draft_attachment_refs(draft_id, file_metadata_id)
SELECT DISTINCT d.id, value
FROM drafts d, json_each(d.attachment_metadata_ids)
WHERE value IS NOT NULL AND trim(value) != ''
''');
  }

  Future<void> _rebuildMessageCopiesTable(Migrator m) async {
    final tableName = messageCopies.actualTableName;
    final tempTableName = '${tableName}_old';
    const columnNames = <String>['id', 'share_id', 'dc_msg_id', 'dc_chat_id'];
    final columnList = columnNames.map((c) => '"$c"').join(', ');
    final tableExists = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(tableName)],
    ).get();
    if (tableExists.isEmpty) {
      await m.createTable(messageCopies);
      return;
    }
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await customStatement('DROP TABLE IF EXISTS "$tempTableName"');
      await customStatement(
        'ALTER TABLE "$tableName" RENAME TO "$tempTableName"',
      );
      await m.createTable(messageCopies);
      await customStatement(
        'INSERT INTO "$tableName" ($columnList, "dc_account_id") '
        'SELECT $columnList, ? FROM "$tempTableName"',
        [DeltaAccountDefaults.legacyId],
      );
      await customStatement('DROP TABLE "$tempTableName"');
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _mergeEmailChats() async {
    final emailChats = await (select(
      chats,
    )..where((tbl) => tbl.emailAddress.isNotNull())).get();
    final canonical = <String, Chat>{};
    final impactedSummaryJids = <String>{};
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
            .write(MessageParticipantsCompanion(contactJid: Value(normalized)));
        await (update(notifications)
              ..where((tbl) => tbl.chatJid.equals(chat.jid)))
            .write(NotificationsCompanion(chatJid: Value(normalized)));
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
        impactedSummaryJids.add(normalized);
      } else {
        await (update(messages)..where((tbl) => tbl.chatJid.equals(chat.jid)))
            .write(MessagesCompanion(chatJid: Value(normalized)));
        await (update(messageParticipants)
              ..where((tbl) => tbl.contactJid.equals(chat.jid)))
            .write(MessageParticipantsCompanion(contactJid: Value(normalized)));
        await (update(notifications)
              ..where((tbl) => tbl.chatJid.equals(chat.jid)))
            .write(NotificationsCompanion(chatJid: Value(normalized)));
        await (update(chats)..where((tbl) => tbl.jid.equals(chat.jid))).write(
          ChatsCompanion(jid: Value(normalized), contactJid: Value(normalized)),
        );
        canonical[normalized] = chat.copyWith(
          jid: normalized,
          contactJid: normalized,
        );
        impactedSummaryJids.add(normalized);
      }
    }
    for (final jid in impactedSummaryJids) {
      if (await getChat(jid) == null) {
        continue;
      }
      await _refreshChatSummaryAfterTrim(jid: jid);
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
  Future<void> deleteFile() async {
    if (_inMemory || _file.path.isEmpty) {
      return;
    }
    const databaseWalSuffix = '-wal';
    const databaseShmSuffix = '-shm';
    const databaseJournalSuffix = '-journal';
    final prefix = _databasePrefixFromFilePath();
    if (prefix == null) {
      _log.warning(
        'Skipped database file cleanup for unexpected path ${_file.path}',
      );
      return;
    }
    final expectedDatabaseFile = await dbFileFor(prefix);
    final basePath = expectedDatabaseFile.path;
    if (!appOwnedPathsMatch(expectedPath: basePath, actualPath: _file.path)) {
      _log.warning(
        'Skipped database file cleanup for unexpected path ${_file.path}',
      );
      return;
    }
    final candidates = <File>[
      File(basePath),
      File('$basePath$databaseWalSuffix'),
      File('$basePath$databaseShmSuffix'),
      File('$basePath$databaseJournalSuffix'),
    ];
    for (final candidate in candidates) {
      try {
        final deleted = await deleteAppOwnedFile(
          file: candidate,
          expectedPath: candidate.path,
        );
        if (!deleted) {
          _log.warning(
            'Skipped database artifact cleanup for unexpected path ${candidate.path}',
          );
        }
      } on FileSystemException catch (error, stackTrace) {
        _log.warning(
          'Failed to delete database artifact ${candidate.path}',
          error,
          stackTrace,
        );
      }
    }
    await _deleteAttachmentRootDirectory();
  }

  Future<void> _deleteAttachmentRootDirectory() async {
    final String? prefix = _databasePrefixFromFilePath();
    if (prefix == null) {
      return;
    }
    final Directory directory = await _attachmentDirectoryForPrefix(prefix);
    try {
      final deleted = await deleteAppOwnedDirectoryTree(
        directory: directory,
        expectedPath: directory.path,
      );
      if (!deleted) {
        _log.warning(
          'Skipped attachment cleanup for unexpected path ${directory.path}',
        );
      }
    } on FileSystemException catch (error, stackTrace) {
      _log.warning(
        'Failed to delete attachment directory ${directory.path}',
        error,
        stackTrace,
      );
    }
  }
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
  final trimmedPrefix = prefix.trim();
  final normalizedPrefix = trimmedPrefix.isEmpty
      ? trimmedPrefix
      : normalizeAppOwnedPathSegment(trimmedPrefix);
  return File(p.join(path, '$normalizedPrefix.axichat.drift'));
}

String _escapeLikePattern(String input) {
  return input
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

String _escapeFtsQuery(String input) {
  final tokens = input.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  if (tokens.isEmpty) return '';
  return tokens.map(_escapeFtsToken).join(' ');
}

String _escapeFtsToken(String token) {
  final escaped = token.replaceAll('"', '""');
  final requiresQuotes = RegExp(r'[^\w]').hasMatch(token);
  final base = requiresQuotes ? '"$escaped"' : escaped;
  return '$base*';
}

typedef HashFunction = mox.HashFunction;
