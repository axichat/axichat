// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

// ignore_for_file: avoid_renaming_method_parameters

import 'dart:async';
import 'dart:io';

import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/interop/calendar_snapshot_metadata.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/anti_abuse_sync.dart';
import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/util/delta_message_ids.dart';
import 'package:axichat/src/email/util/email_message_ids.dart';
import 'package:axichat/src/storage/app_storage.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:omemo_dart/omemo_dart.dart' as omemo;
import 'package:path/path.dart' as p;
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

List<String> _emailOriginIdCandidates(String originID) {
  final trimmed = originID.trim();
  if (trimmed.isEmpty) {
    return const <String>[];
  }
  final normalized = normalizeEmailMessageId(trimmed);
  final candidates = <String>{trimmed};
  if (normalized != null && normalized.isNotEmpty && normalized.contains('@')) {
    candidates
      ..add(normalized)
      ..add('<$normalized>');
  }
  return candidates.toList(growable: false);
}

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

final class _LegacyReplyReferenceMessage {
  const _LegacyReplyReferenceMessage({
    required this.id,
    required this.stanzaId,
    required this.chatJid,
    this.body,
    this.htmlBody,
    this.fileMetadataId,
    this.originId,
    this.mucStanzaId,
    this.deltaAccountId,
    this.deltaChatId,
  });

  final String id;
  final String stanzaId;
  final String chatJid;
  final String? body;
  final String? htmlBody;
  final String? fileMetadataId;
  final String? originId;
  final String? mucStanzaId;
  final int? deltaAccountId;
  final int? deltaChatId;

  String? get trimmedStanzaId => _trimmedReferenceValue(stanzaId);

  String? get trimmedOriginId => _trimmedReferenceValue(originId);

  String? get trimmedMucStanzaId => _trimmedReferenceValue(mucStanzaId);

  bool get hasStableContent =>
      body?.trim().isNotEmpty == true ||
      htmlBody?.trim().isNotEmpty == true ||
      fileMetadataId?.trim().isNotEmpty == true;
}

enum MessageSaveChange { inserted, upserted, merged, unchanged, ignored }

final class MessageSaveResult {
  const MessageSaveResult({
    required this.change,
    required this.unreadDelta,
    required this.chatSummaryChanged,
  });

  final MessageSaveChange change;
  final int unreadDelta;
  final bool chatSummaryChanged;

  bool get storedMessage =>
      change == MessageSaveChange.inserted ||
      change == MessageSaveChange.upserted ||
      change == MessageSaveChange.merged ||
      change == MessageSaveChange.unchanged;
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

  Future<bool> hasDisplayableMessagesForChat(String jid);

  Future<int> countEmailBackedChatMessages(
    String jid, {
    int? deltaAccountId,
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

  Future<List<MessageDeltaSnapshot>> getMessageDeltaSnapshot(
    String jid, {
    int? deltaAccountId,
  });

  Future<void> deleteMessagesByStanzaIds(Iterable<String> stanzaIds);

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

  Future<List<Message>> getMessagesByOriginID(
    String originID, {
    String? chatJid,
  });

  Future<Message?> getMessageByReferenceId(String messageId, {String? chatJid});

  Future<Message?> getNewestChatMessageByReferenceIds({
    required String chatJid,
    required Iterable<String> referenceIds,
    bool includeEmailBacked = true,
  });

  Future<Message?> getMessageByDeltaId(
    int deltaMsgId, {
    int? deltaAccountId,
    String? chatJid,
  });

  Future<bool> repairMessageDeltaAccountIdIfUnclaimed({
    required String stanzaID,
    required int deltaAccountId,
  });

  Future<List<Message>> getRecoverableOutgoingDeltaMessages({
    required int deltaAccountId,
    required String senderJid,
    required DateTime since,
    required int limit,
  });

  Future<List<Message>> getMessagesByDeltaIds(
    Iterable<int> deltaMsgIds, {
    int? deltaAccountId,
    String? chatJid,
  });

  Future<List<Message>> getMessagesByDeltaChat({
    required int deltaAccountId,
    required int deltaChatId,
  });

  Future<List<Message>> getUndisplayedMessagesByDeltaChat({
    required int deltaAccountId,
    required int deltaChatId,
    required int limit,
  });

  Future<Message?> getOldestUnreadEmailBackedMessageForChat(
    String jid, {
    String? selfJid,
    String? emailSelfJid,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  });

  Future<Message?> getOldestUnreadMessageForChat(
    String jid, {
    String? selfJid,
    String? emailSelfJid,
    bool isGroupChat = false,
    String? myOccupantJid,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  });

  Future<List<Message>> getDisplayedEmailMessagesPendingDeltaSeen({
    Iterable<String> chatJids = const <String>[],
    int limit = 100,
  });

  Future<int> markDeltaMessagesSeenSynced({
    required int deltaAccountId,
    required Iterable<int> deltaMsgIds,
  });

  Future<void> clearMessageDeltaHandles(String stanzaID);

  Future<Message?> rehomeDeltaMessage({
    required int deltaMsgId,
    required int deltaAccountId,
    required int deltaChatId,
    required String chatJid,
    required String senderJid,
    String? selfJid,
    String? emailSelfJid,
  });

  Future<Message?> recoverStaleDeltaMessageLocator({
    required int deltaMsgId,
    required int deltaAccountId,
    required int deltaChatId,
    required String chatJid,
  });

  Future<void> clearChatDeltaChatId(String jid);

  Future<void> updateMessageOriginId({
    required String stanzaID,
    required String originID,
  });

  Future<void> rebindMessageCollectionMembershipReferences({
    required String chatJid,
    required String oldReferenceId,
    required String newReferenceId,
  });

  Future<List<Message>> getMessagesByStanzaIds(Iterable<String> stanzaIds);

  Future<List<Message>> getEmailMessagesWithDeltaAccountNotIn(
    List<int> validAccountIds,
  );

  Future<int> collapseLegacyDeltaAccountDuplicates({
    required List<int> activeAccountIds,
  });

  Future<int> normalizeDeltaAccountsForSingleContext();

  Future<List<Message>> getMessagesByReferenceIds(
    Iterable<String> messageIds, {
    String? chatJid,
  });

  Future<List<Message>> getEmailMessagesByRfcGroup({
    required String chatJid,
    required String originID,
    required int deltaAccountId,
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

  Future<MessageSaveResult> saveMessageWithResult(
    Message message, {
    ChatType chatType = ChatType.chat,
    String? selfJid,
  });

  Future<void> updateMessage(Message message);

  Future<void> ensureEmailEncryptionStatusMarkerForChat(String chatJid);

  Future<int> countUnreadMessagesForChat(
    String jid, {
    String? selfJid,
    String? emailSelfJid,
  });

  Future<int> repairUnreadCountForChat(
    String jid, {
    String? selfJid,
    String? emailSelfJid,
  });

  Future<void> hydrateMessageMucIdentity({
    required String stanzaID,
    String? senderRealJid,
    String? occupantID,
    String? mucStanzaId,
  });

  Future<void> replacePendingOutboundMucIdentity({
    required String stanzaID,
    required String senderJid,
    String? senderRealJid,
    String? occupantID,
  });

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
    String? groupQuotedStanzaId,
  });

  Future<void> replaceMessageAttachments({
    required String messageId,
    required List<String> fileMetadataIds,
    String? transportGroupId,
    String? groupQuotedStanzaId,
  });

  Future<List<MessageAttachmentData>> getMessageAttachments(String messageId);

  Future<Map<String, List<MessageAttachmentData>>>
  getMessageAttachmentsForMessages(Iterable<String> messageIds);

  Future<List<MessageAttachmentData>> getMessageAttachmentsForGroup(
    String transportGroupId,
  );

  Future<List<String>> deleteMessageAttachments(String messageId);

  Future<void> seedSystemMessageCollections();

  Stream<List<MessageCollectionEntry>> watchMessageCollections({
    bool includeInactive = false,
    bool includeSystem = true,
  });

  Future<List<MessageCollectionEntry>> getMessageCollections({
    bool includeInactive = false,
    bool includeSystem = true,
  });

  Future<MessageCollectionEntry?> getMessageCollection(String collectionId);

  Future<void> applyMessageCollectionDefinitionMutation({
    required String collectionId,
    required DateTime updatedAt,
    required bool active,
  });

  Stream<List<MessageCollectionMembershipEntry>>
  watchMessageCollectionMemberships(String collectionId, {String? chatJid});

  Stream<List<FolderMessageItem>> watchFolderMessageItems(
    String collectionId, {
    String? chatJid,
  });

  Future<List<MessageCollectionMembershipEntry>>
  getMessageCollectionMemberships(
    String collectionId, {
    String? chatJid,
    bool includeInactive = false,
  });

  Future<List<FolderMessageItem>> getFolderMessageItems(
    String collectionId, {
    String? chatJid,
    bool includeInactive = false,
  });

  Future<List<MessageCollectionMembershipEntry>>
  getAllMessageCollectionMemberships({bool includeInactive = false});

  Stream<List<MessageCollectionMembershipEntry>>
  watchAllMessageCollectionMemberships({
    bool includeInactive = false,
    String? chatJid,
  });

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

  Stream<List<PinnedMessageAggregate>> watchPinnedMessageAggregates({
    required String chatJid,
    required String selfPinnerJid,
  });

  Future<List<PinnedMessageAggregate>> getPinnedMessageAggregates({
    required String chatJid,
    required String selfPinnerJid,
  });

  Future<PinEntry?> getMessagePin({
    required String chatJid,
    required String messageReferenceId,
    required String pinnerJid,
  });

  Future<DateTime?> getPinnedMessageClearAllTimestamp({
    required String chatJid,
    required String messageReferenceId,
  });

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

  Future<void> applyMessagePinMutation({
    required String chatJid,
    required String messageReferenceId,
    String? messageStanzaId,
    String? messageOriginId,
    String? messageMucStanzaId,
    required String pinnerJid,
    required DateTime pinnedAt,
    required bool active,
    required bool identityVerified,
  });

  Future<void> clearMessagePins({
    required String chatJid,
    required String messageReferenceId,
    required DateTime pinnedAt,
  });

  Future<void> copyLegacyPinnedMessagesToPinRows({required String pinnerJid});

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

  Future<void> markMessageManualSendAgain({
    required String stanzaID,
    required String sendAgainStanzaID,
  });

  Future<int> markMessagesStatusThrough({
    required String messageId,
    required String chatJid,
    required String senderJid,
    bool acked = false,
    bool received = false,
    bool displayed = false,
    bool includeEmailBacked = true,
  });

  Future<void> markOutgoingMessagesDisplayedThrough({
    required String messageId,
    required String chatJid,
    required String senderJid,
  });

  Future<void> deleteMessage(
    String stanzaID, {
    String? selfJid,
    String? emailSelfJid,
  });

  Future<void> replaceDeltaPlaceholderSelfJids({
    required int deltaAccountId,
    required String resolvedAddress,
    required List<String> placeholderJids,
    String? selfJid,
    String? emailSelfJid,
  });

  Future<void> clearMessageHistory();

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
    required int deltaAccountId,
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
    String? quotingOriginId,
    String? quotingMucStanzaId,
    List<String> attachmentMetadataIds = const [],
    List<FileMetadataData> attachmentMetadata = const [],
    CalendarTaskIcsMessage? calendarTaskIcsMessage,
    List<DraftForwardedBlock> forwardedBlocks = const [],
    bool autosaveEnabled = false,
  });

  Future<void> updateDraftSyncMetadata({
    required int id,
    required String draftSyncId,
    required DateTime draftUpdatedAt,
    required String draftSourceId,
  });

  Future<void> updateDraftAutosaveEnabled({
    required int id,
    required bool enabled,
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
    String? quotingOriginId,
    String? quotingMucStanzaId,
    List<String> attachmentMetadataIds = const [],
    List<FileMetadataData> attachmentMetadata = const [],
    CalendarTaskIcsMessage? calendarTaskIcsMessage,
    List<DraftForwardedBlock> forwardedBlocks = const [],
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

  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  });

  Future<List<FileMetadataData>> getFileMetadataForIds(Iterable<String> ids);

  Stream<FileMetadataData?> watchFileMetadata(String id);

  Future<void> deleteFileMetadata(String id);

  Future<List<Chat>> getChats({required int start, required int end});

  Stream<List<Chat>> watchHomeChats({required int recentLimit});

  Future<List<Chat>> getHomeChats({required int recentLimit});

  Stream<List<Chat>> watchAllChats();

  Future<List<Chat>> getAllChats();

  Stream<List<Chat>> watchUnreadChatsForFolderBadges();

  Future<List<Chat>> getUnreadChatsForFolderBadges();

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

  Future<List<EmailChatAccountData>> getEmailChatAccountsForAccount(
    int deltaAccountId,
  );

  Future<List<int>> getDeltaChatIdsForAccount({
    required String chatJid,
    required int deltaAccountId,
  });

  Future<List<int>> getMessageDeltaChatIdsForAccount({
    required String chatJid,
    required int deltaAccountId,
  });

  Future<int?> getDeltaChatIdForAccount({
    required String chatJid,
    required int deltaAccountId,
  });

  Future<void> deleteEmailChatAccount({
    required String chatJid,
    required int deltaAccountId,
    required int deltaChatId,
  });

  Future<void> deleteEmailChatAccountsForDeltaChat({
    required int deltaAccountId,
    required int deltaChatId,
  });

  Future<void> deleteEmailChatAccountsForAccount(int deltaAccountId);

  Future<int> countEmailChatAccounts(String chatJid);

  Future<EmailTrustedContactKeyData?> getEmailTrustedContactKey({
    required int deltaAccountId,
    required String address,
  });

  Future<void> upsertEmailTrustedContactKey(EmailTrustedContactKeyData key);

  Future<void> deleteEmailTrustedContactKey({
    required int deltaAccountId,
    required String address,
  });

  Future<void> createChat(Chat chat);

  Future<void> updateChat(Chat chat);

  Future<void> markDirectChatXmppCapable(String jid);

  Future<void> updateChatSettingsSyncState(Chat chat);

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

  Future<void> repairChatSummaryFromMessages(
    String jid, {
    bool clearStaleLastMessage = false,
  });

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

  Future<void> replaceAvatarReferencesForPath({
    required String oldPath,
    required String newPath,
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

  Future<void> saveRosterItemOnly(RosterItem item);

  Future<void> saveRosterItemsOnly(List<RosterItem> items);

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

  Stream<List<Contact>> watchSavedEmailContacts();

  Future<List<Contact>> getSavedEmailContacts();

  Future<void> replaceContacts(Iterable<Contact> contacts);

  Stream<List<ContactDirectoryEntry>> watchContactDirectoryEntries();

  Future<List<ContactDirectoryEntry>> getContactDirectoryEntries();

  Stream<List<ContactPreference>> watchContactPreferences();

  Future<List<ContactPreference>> getContactPreferences();

  Future<List<PrivateContactRecord>> getPrivateContactRecords({
    bool includeInactive = false,
  });

  Future<PrivateContactRecord?> getPrivateContactRecord(String addressKey);

  Future<List<ContactPreference>> getContactFolderRulePreferences({
    bool includeInactive = false,
  });

  Stream<Map<String, String>> watchActiveContactFolderRules();

  Future<Map<String, String>> getActiveContactFolderRules();

  Future<ContactPreference?> getContactPreference(String addressKey);

  Future<void> setContactFavorited({
    required String addressKey,
    required bool favorited,
  });

  Future<void> setContactDisplayNameOverride({
    required String addressKey,
    required String? displayName,
  });

  Future<void> setContactFolderRule({
    required String addressKey,
    required String collectionId,
  });

  Future<void> clearContactFolderRule({required String addressKey});

  Future<void> applyContactFolderRuleMutation({
    required String addressKey,
    required String? collectionId,
    required DateTime updatedAt,
    required bool active,
  });

  Future<PrivateContactRecord?> upsertManualPrivateContact({
    required String addressKey,
    String? displayName,
  });

  Future<PrivateContactRecord?> deactivateManualPrivateContact({
    required String addressKey,
  });

  Future<PrivateContactRecord?> applyPrivateContactMutation({
    required String addressKey,
    required bool active,
    required bool manual,
    required bool favorited,
    required String? displayNameOverride,
    required String? folderCollectionId,
    required DateTime updatedAt,
    required DateTime? activeUpdatedAt,
    required DateTime? manualUpdatedAt,
    required DateTime? favoriteUpdatedAt,
    required DateTime? displayNameUpdatedAt,
    required DateTime? folderRuleUpdatedAt,
    String? sourceId,
  });

  Future<List<PrivateContactDetailFieldEntry>> getPrivateContactDetailFields(
    String addressKey, {
    bool includeInactive = false,
  });

  Future<PrivateContactDetailFieldEntry?>
  applyPrivateContactDetailFieldMutation({
    required String addressKey,
    required String fieldId,
    required ContactDetailFieldKind kind,
    required String? label,
    required String value,
    required int sortOrder,
    required bool active,
    required DateTime updatedAt,
    String? sourceId,
  });

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

abstract interface class LocalPromptStateStore {
  Future<String?> getLocalPromptState({
    required String accountJid,
    required String promptId,
  });

  Future<void> saveLocalPromptState({
    required String accountJid,
    required String promptId,
    required String status,
  });
}

final class EmailHistoryImportJournal {
  const EmailHistoryImportJournal({
    required this.accountJid,
    required this.deltaAccountId,
    required this.status,
    required this.watermarkDeltaMsgId,
    required this.targetDeltaMsgId,
    required this.lastProjectedDeltaMsgId,
    required this.fetchCompleted,
    required this.updatedAt,
  });

  final String accountJid;
  final int deltaAccountId;
  final String status;
  final int watermarkDeltaMsgId;
  final int targetDeltaMsgId;
  final int lastProjectedDeltaMsgId;
  final bool fetchCompleted;
  final DateTime updatedAt;
}

abstract interface class EmailHistoryImportJournalStore {
  Future<EmailHistoryImportJournal?> getEmailHistoryImportJournal({
    required String accountJid,
    required int deltaAccountId,
  });

  Future<void> saveEmailHistoryImportJournal({
    required String accountJid,
    required int deltaAccountId,
    required String status,
    required int watermarkDeltaMsgId,
    required int targetDeltaMsgId,
    required int lastProjectedDeltaMsgId,
    required bool fetchCompleted,
  });

  Future<void> deleteEmailHistoryImportJournal({
    required String accountJid,
    required int deltaAccountId,
  });
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

extension AddressBlockXmppDatabase on XmppDatabase {
  Stream<List<AddressBlockEntry>> watchAddressBlocks() => watchEmailBlocklist();

  Future<List<AddressBlockEntry>> getAddressBlocks() => getEmailBlocklist();

  Future<AddressBlockEntry?> getAddressBlockEntry(String address) =>
      getEmailBlocklistEntry(address);

  Future<void> addAddressBlock(
    String address, {
    DateTime? blockedAt,
    String? sourceId,
  }) => addEmailBlock(address, blockedAt: blockedAt, sourceId: sourceId);

  Future<void> removeAddressBlock(String address) => removeEmailBlock(address);
}

extension SpamXmppDatabase on XmppDatabase {
  Stream<List<SpamEntry>> watchSpamlist() => watchEmailSpamlist();

  Future<List<SpamEntry>> getSpamlist() => getEmailSpamlist();

  Future<SpamEntry?> getSpamEntry(String address) => getEmailSpamEntry(address);

  Future<void> addSpam(
    String address, {
    DateTime? flaggedAt,
    String? sourceId,
  }) => addEmailSpam(address, flaggedAt: flaggedAt, sourceId: sourceId);

  Future<void> removeSpam(String address) => removeEmailSpam(address);
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

  Future<void> insertForDeltaMessage(MessageCopiesCompanion data) =>
      into(table).insert(
        data,
        onConflict: DoUpdate.withExcluded(
          (old, excluded) =>
              MessageCopiesCompanion.custom(dcChatId: excluded.dcChatId),
          target: [table.dcMsgId, table.dcAccountId],
        ),
      );

  @override
  Future<void> deleteOne(int id) =>
      (delete(table)..where((tbl) => tbl.id.equals(id))).go();

  Future<MessageCopyData?> selectByDeltaMsgId(
    int deltaMsgId, {
    required int deltaAccountId,
  }) =>
      (select(table)..where(
            (tbl) =>
                tbl.dcMsgId.equals(deltaMsgId) &
                tbl.dcAccountId.equals(deltaAccountId),
          ))
          .getSingleOrNull();

  Future<String?> selectShareIdForDeltaMsg(
    int deltaMsgId, {
    required int deltaAccountId,
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
  Stream<List<Chat>> watchAll() => _orderedQuery().watch();

  @override
  Future<List<Chat>> selectAll() => _orderedQuery().get();

  Stream<List<Chat>> watchRange({required int start, required int end}) =>
      _orderedRangeQuery(start: start, end: end).watch();

  Future<List<Chat>> selectRange({required int start, required int end}) =>
      _orderedRangeQuery(start: start, end: end).get();

  Stream<List<Chat>> watchHome({required int recentLimit}) =>
      _homeQuery(recentLimit: recentLimit).watch();

  Future<List<Chat>> selectHome({required int recentLimit}) =>
      _homeQuery(recentLimit: recentLimit).get();

  SimpleSelectStatement<$ChatsTable, Chat> _homeQuery({
    required int recentLimit,
  }) {
    final recentJids = _recentJidsQuery(
      recentLimit: recentLimit,
      predicate:
          table.archived.equals(false) &
          table.spam.equals(false) &
          table.hidden.equals(false),
    );
    final recentArchivedJids = _recentJidsQuery(
      recentLimit: recentLimit,
      predicate: table.archived.equals(true),
    );
    final recentSpamJids = _recentJidsQuery(
      recentLimit: recentLimit,
      predicate: table.spam.equals(true),
    );
    return _orderedQuery()..where(
      (tbl) =>
          tbl.unreadCount.isBiggerThanValue(0) |
          tbl.jid.isInQuery(recentJids) |
          tbl.jid.isInQuery(recentArchivedJids) |
          tbl.jid.isInQuery(recentSpamJids),
    );
  }

  JoinedSelectStatement<$ChatsTable, Chat> _recentJidsQuery({
    required int recentLimit,
    required Expression<bool> predicate,
  }) {
    return selectOnly(table)
      ..addColumns([table.jid])
      ..where(predicate)
      ..orderBy([
        OrderingTerm(
          expression: table.lastChangeTimestamp,
          mode: OrderingMode.desc,
        ),
        OrderingTerm(expression: table.jid, mode: OrderingMode.asc),
      ])
      ..limit(recentLimit);
  }

  Stream<List<Chat>> watchUnreadForFolderBadges() =>
      _unreadFolderBadgeQuery().watch();

  Future<List<Chat>> selectUnreadForFolderBadges() =>
      _unreadFolderBadgeQuery().get();

  SimpleSelectStatement<$ChatsTable, Chat> _orderedQuery() =>
      select(table)..orderBy([
        (t) => OrderingTerm(
          expression: t.lastChangeTimestamp,
          mode: OrderingMode.desc,
        ),
        (t) => OrderingTerm(expression: t.jid, mode: OrderingMode.asc),
      ]);

  SimpleSelectStatement<$ChatsTable, Chat> _orderedRangeQuery({
    required int start,
    required int end,
  }) {
    final query = _orderedQuery();
    if (end > start) {
      query.limit(end - start, offset: start);
    }
    return query;
  }

  SimpleSelectStatement<$ChatsTable, Chat> _unreadFolderBadgeQuery() =>
      _orderedQuery()..where((tbl) => tbl.unreadCount.isBiggerThanValue(0));

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

@DriftAccessor(tables: [Contacts])
class ContactsAccessor extends BaseAccessor<Contact, $ContactsTable>
    with _$ContactsAccessorMixin {
  ContactsAccessor(super.attachedDatabase);

  @override
  $ContactsTable get table => contacts;

  @override
  Future<Contact?> selectOne(String value) => (select(
    table,
  )..where((table) => table.nativeID.equals(value))).getSingleOrNull();

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((item) => item.nativeID.equals(value))).go();
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
    MessagePins,
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
    EmailTrustedContactKeys,
    Contacts,
    ContactPreferences,
    PrivateContactRecords,
    PrivateContactDetailFields,
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
    ContactsAccessor,
    BlocklistAccessor,
    EmailBlocklistAccessor,
    EmailSpamlistAccessor,
  ],
)
class XmppDrift extends _$XmppDrift
    implements
        XmppDatabase,
        LocalPromptStateStore,
        EmailHistoryImportJournalStore {
  // This marker preserves clear-all ordering even when newer individual pins keep
  // the visible aggregate active.
  static const String _pinnedMessageClearAllMarkerPinnerJid =
      'urn:axi:pinned-message:clear-all';

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
  int get schemaVersion => 74;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _createLocalPromptStatesTable();
        await _createEmailHistoryImportJournalTable();
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
        if (from < 31 &&
            !await _tableHasColumn(pinnedMessages.actualTableName, 'active')) {
          await m.addColumn(pinnedMessages, pinnedMessages.active);
        }
        if (from < 57) {
          await _dropLegacyMessagePinIndexes();
          await _migrateMessagePinsTable(m);
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
        if (from < 37) {
          await m.addColumn(chats, chats.primaryView);
        }
        if (from < 38) {
          await m.addColumn(contacts, contacts.displayName);
        }
        if (from < 39) {
          await customStatement('DROP TABLE IF EXISTS contact_cards');
        }
        if (from < 40) {
          await m.createTable(contactPreferences);
        }
        if (from < 41) {
          if (!await _tableHasColumn(
            contactPreferences.actualTableName,
            'folder_collection_id',
          )) {
            await m.addColumn(
              contactPreferences,
              contactPreferences.folderCollectionId,
            );
          }
          await seedSystemMessageCollections();
        }
        if (from < 42 &&
            !await _tableHasColumn(
              contactPreferences.actualTableName,
              'folder_rule_updated_at',
            )) {
          await m.addColumn(
            contactPreferences,
            contactPreferences.folderRuleUpdatedAt,
          );
        }
        if (from < 43) {
          await m.createTable(privateContactRecords);
          await m.createTable(privateContactDetailFields);
          await _migrateContactPreferencesToPrivateContacts();
        }
        if (from < 44 &&
            !await _tableHasColumn(
              messages.actualTableName,
              'manual_send_again_stanza_i_d',
            )) {
          await m.addColumn(messages, messages.manualSendAgainStanzaID);
        }
        if (from < 45 &&
            !await _tableHasColumn(
              messages.actualTableName,
              'sender_real_jid',
            )) {
          await m.addColumn(messages, messages.senderRealJid);
        }
        if (from < 47 &&
            !await _tableHasColumn(
              drafts.actualTableName,
              'calendar_task_ics',
            )) {
          await m.addColumn(drafts, drafts.calendarTaskIcsMessage);
        }
        if (from < 50 &&
            !await _tableHasColumn(
              drafts.actualTableName,
              'forwarded_blocks',
            )) {
          await m.addColumn(drafts, drafts.forwardedBlocks);
        }
        if (from < 51) {
          if (!await _tableHasColumn(
            chats.actualTableName,
            'email_remote_images_enabled',
          )) {
            await m.addColumn(chats, chats.emailRemoteImagesEnabled);
          }
          if (!await _tableHasColumn(
            chats.actualTableName,
            'typing_indicators_enabled',
          )) {
            await m.addColumn(chats, chats.typingIndicatorsEnabled);
          }
          if (!await _tableHasColumn(
            chats.actualTableName,
            'email_read_receipts_enabled',
          )) {
            await m.addColumn(chats, chats.emailReadReceiptsEnabled);
          }
          if (!await _tableHasColumn(
            chats.actualTableName,
            'email_send_confirmation_enabled',
          )) {
            await m.addColumn(chats, chats.emailSendConfirmationEnabled);
          }
          if (!await _tableHasColumn(
            chats.actualTableName,
            'email_composer_watermark_enabled',
          )) {
            await m.addColumn(chats, chats.emailComposerWatermarkEnabled);
          }
        }
        if (from < 51) {
          if (!await _tableHasColumn(
            chats.actualTableName,
            'chat_settings_updated_at',
          )) {
            await m.addColumn(chats, chats.chatSettingsUpdatedAt);
          }
          if (!await _tableHasColumn(
            chats.actualTableName,
            'chat_settings_source_id',
          )) {
            await m.addColumn(chats, chats.chatSettingsSourceId);
          }
          if (!await _tableHasColumn(
            chats.actualTableName,
            'chat_settings_confirmed_json',
          )) {
            await m.addColumn(chats, chats.chatSettingsConfirmedJson);
          }
          if (!await _tableHasColumn(
            chats.actualTableName,
            'chat_settings_confirmed_updated_at',
          )) {
            await m.addColumn(chats, chats.chatSettingsConfirmedUpdatedAt);
          }
          if (!await _tableHasColumn(
            chats.actualTableName,
            'chat_settings_confirmed_source_id',
          )) {
            await m.addColumn(chats, chats.chatSettingsConfirmedSourceId);
          }
        }
        if (from < 51 &&
            !await _tableHasColumn(
              chats.actualTableName,
              'notification_behavior',
            )) {
          await m.addColumn(chats, chats.notificationBehavior);
        }
        if (from < 52) {
          if (!await _tableHasColumn(
            messageAttachments.actualTableName,
            'group_quoted_reference',
          )) {
            await m.addColumn(
              messageAttachments,
              messageAttachments.groupQuotedReference,
            );
          }
        }
        if (from < 53) {
          await m.createTable(emailTrustedContactKeys);
        }
        if (from < 54) {
          await _promoteRosterBackedEmailChats();
        }
        if (from < 56 &&
            !await _tableHasColumn(
              drafts.actualTableName,
              'autosave_enabled',
            )) {
          await m.addColumn(drafts, drafts.autosaveEnabled);
        }
        if (from < 73) {
          await _ensureMessageColumnsReadByMigrationDataRepairs(m);
        }
        if (from < 58) {
          await _rebuildEmailChatAccountsForMultipleDeltaChats();
        }
        if (from < 59) {
          await repairGeneratedEmailAttachmentCaptionBodies();
        }
        if (from < 60) {
          await migrateMessageIdentityToLadder();
        }
        if (from < 62) {
          await m.drop(Index('messages_delta_locator', ''));
          final removed = await collapseDuplicateDeltaPairRows();
          if (removed > 0) {
            _log.info('Collapsed $removed cross-chat delta-locator rows.');
          }
          await m.createIndex(messagesDeltaLocator);
        }
        if (from < 63) {
          final repaired = await _repairOverpromotedEmailChatTransports();
          if (repaired > 0) {
            _log.info(
              'Repaired $repaired over-promoted email chat transports.',
            );
          }
        }
        if (from < 64) {
          final cleared = await clearXmppErrorsFromEmailMessages();
          if (cleared > 0) {
            _log.info(
              'Cleared $cleared stray XMPP errors from email messages.',
            );
          }
        }
        if (from < 65) {
          await retireDerivedEmailOriginIds();
        }
        if (from < 66) {
          await _ensureMessageRfc822BodyStatusColumn(m);
          await _migrateEmailRfc822BodyStatusFromPseudoData();
        }
        if (from < 67) {
          await _createCurrentSchemaIndexes();
        }
        if (from < 69) {
          await _ensureMessageReplyColumns(m);
          if (!await _tableHasColumn(
            drafts.actualTableName,
            'quoting_origin_id',
          )) {
            await m.addColumn(drafts, drafts.quotingOriginId);
          }
          if (!await _tableHasColumn(
            drafts.actualTableName,
            'quoting_muc_stanza_id',
          )) {
            await m.addColumn(drafts, drafts.quotingMucStanzaId);
          }
          await _migrateMessageReplyFieldsFromLegacyQuoting();
          await _migrateDraftQuoteFieldsFromLegacyQuoting();
          await _dropLegacyMessagePinIndexes();
          if (await _tableExists(messagePins.actualTableName)) {
            if (await _tableHasColumn(
              messagePins.actualTableName,
              'message_reference_kind',
            )) {
              await _migrateMessagePinsReferenceKindColumn(m);
            } else {
              await _ensureMessagePinReferenceColumns(m);
            }
          } else {
            await m.createTable(messagePins);
          }
          await _createCurrentSchemaIndexes();
        }
        if (from < 70) {
          final normalized = await normalizeDeltaAccountsForSingleContext();
          if (normalized > 0) {
            _log.info('Re-normalized $normalized single-context Delta rows.');
          }
        }
        if (from < 71) {
          final repaired = await normalizeDeltaAccountsForSingleContext();
          if (repaired > 0) {
            _log.info('Repaired $repaired legacy Delta stanza duplicate rows.');
          }
        }
        if (from < 72) {
          await _createLocalPromptStatesTable();
        }
        if (from < 74) {
          await _createEmailHistoryImportJournalTable();
        }
      },
      beforeOpen: (_) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await _repairRestoredArchiveJids();
        await repairMixedChatTransports();
      },
    );
  }

  Future<void> _migrateMessageReplyFieldsFromLegacyQuoting() async {
    if (!await _tableHasColumn(messages.actualTableName, 'quoting')) {
      return;
    }
    final hasLegacyTypeColumn = await _tableHasColumn(
      messages.actualTableName,
      'quoting_reference_kind',
    );
    final legacyTypeSelection = hasLegacyTypeColumn
        ? 'quoting_reference_kind'
        : 'NULL AS quoting_reference_kind';
    final rows = await customSelect(
      '''
SELECT stanza_i_d, chat_jid, quoting, $legacyTypeSelection
FROM messages
WHERE quoting IS NOT NULL AND trim(quoting) != ''
''',
      readsFrom: {messages},
    ).get();
    if (rows.isEmpty) {
      return;
    }
    for (final row in rows) {
      final stanzaId = row.read<String>('stanza_i_d');
      final chatJid = row.read<String>('chat_jid');
      final resolved = await _replyFieldsForLegacyQuoting(
        legacyValue: row.read<String>('quoting'),
        chatJid: chatJid,
        legacyType: row.read<int?>('quoting_reference_kind'),
      );
      if (resolved == null) {
        continue;
      }
      await _updateMessageReplyFields(stanzaId, resolved);
    }
  }

  Future<({String? stanzaId, String? originId, String? mucStanzaId})?>
  _replyFieldsForLegacyQuoting({
    required String legacyValue,
    required String chatJid,
    int? legacyType,
  }) async {
    final value = legacyValue.trim();
    if (value.isEmpty) {
      return null;
    }
    if (isLegacyWireMessageReferenceValue(value)) {
      return _stableReplyFieldsForLegacyWireReference(
        await _messageForLegacyWireReference(value, chatJid: chatJid),
      );
    }
    final referencedMessage = await getMessageByReferenceId(
      value,
      chatJid: chatJid,
    );
    if (referencedMessage?.trimmedMucStanzaId == value) {
      return (stanzaId: null, originId: null, mucStanzaId: value);
    }
    if (referencedMessage?.trimmedOriginId == value) {
      return (stanzaId: null, originId: value, mucStanzaId: null);
    }
    if (referencedMessage?.trimmedStanzaId == value) {
      return (stanzaId: value, originId: null, mucStanzaId: null);
    }
    const legacyOriginIdType = 1;
    const legacyMucStanzaIdType = 2;
    if (legacyType == legacyOriginIdType) {
      return (stanzaId: null, originId: value, mucStanzaId: null);
    }
    if (legacyType == legacyMucStanzaIdType) {
      return (stanzaId: null, originId: null, mucStanzaId: value);
    }
    return (stanzaId: value, originId: null, mucStanzaId: null);
  }

  Future<void> _updateMessageReplyFields(
    String stanzaId,
    ({String? stanzaId, String? originId, String? mucStanzaId})? fields,
  ) => (update(messages)..where((tbl) => tbl.stanzaID.equals(stanzaId))).write(
    MessagesCompanion(
      replyStanzaId: Value(fields?.stanzaId),
      replyOriginId: Value(fields?.originId),
      replyMucStanzaId: Value(fields?.mucStanzaId),
    ),
  );

  Future<_LegacyReplyReferenceMessage?> _messageForLegacyWireReference(
    String value, {
    required String chatJid,
  }) async {
    final deltaMsgId = deltaMsgIdFromDeviceLocalStanzaId(value);
    if (deltaMsgId != null) {
      final rows = await _legacyReplyReferenceMessagesByDeltaMsgId(
        chatJid: chatJid,
        deltaMsgId: deltaMsgId,
      );
      if (rows.length == 1) {
        return rows.single;
      }
      if (rows.length > 1) {
        return await _preferredLegacyReplyReferenceDeltaMessage(rows);
      }
    }
    return _legacyReplyReferenceMessageByReferenceId(value, chatJid: chatJid);
  }

  ({String? stanzaId, String? originId, String? mucStanzaId})?
  _stableReplyFieldsForLegacyWireReference(
    _LegacyReplyReferenceMessage? message,
  ) {
    if (message == null) {
      return null;
    }
    final originId = genuineEmailMessageId(message.originId);
    if (originId != null) {
      return (stanzaId: null, originId: originId, mucStanzaId: null);
    }
    final mucStanzaId = message.trimmedMucStanzaId;
    if (mucStanzaId != null &&
        !isLegacyWireMessageReferenceValue(mucStanzaId)) {
      return (stanzaId: null, originId: null, mucStanzaId: mucStanzaId);
    }
    final stanzaId = message.trimmedStanzaId;
    if (stanzaId != null && !isLegacyWireMessageReferenceValue(stanzaId)) {
      return (stanzaId: stanzaId, originId: null, mucStanzaId: null);
    }
    return null;
  }

  Future<List<_LegacyReplyReferenceMessage>>
  _legacyReplyReferenceMessagesByDeltaMsgId({
    required String chatJid,
    required int deltaMsgId,
  }) async {
    final rows = await customSelect(
      '''
SELECT id, stanza_i_d, chat_jid, timestamp, body, html_body,
       file_metadata_i_d, origin_i_d, muc_stanza_id, delta_account_id,
       delta_chat_id
FROM messages
WHERE chat_jid = ? AND delta_msg_id = ?
ORDER BY timestamp ASC, stanza_i_d ASC
''',
      variables: [Variable<String>(chatJid), Variable<int>(deltaMsgId)],
      readsFrom: {messages},
    ).get();
    return rows
        .map(_legacyReplyReferenceMessageFromRow)
        .toList(growable: false);
  }

  Future<_LegacyReplyReferenceMessage?>
  _legacyReplyReferenceMessageByReferenceId(
    String value, {
    required String chatJid,
  }) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final rows = await customSelect(
      '''
SELECT id, stanza_i_d, chat_jid, timestamp, body, html_body,
       file_metadata_i_d, origin_i_d, muc_stanza_id, delta_account_id,
       delta_chat_id
FROM messages
WHERE chat_jid = ?
  AND (stanza_i_d = ? OR origin_i_d = ? OR muc_stanza_id = ?)
ORDER BY timestamp ASC, stanza_i_d ASC
LIMIT 1
''',
      variables: [
        Variable<String>(chatJid),
        Variable<String>(normalized),
        Variable<String>(normalized),
        Variable<String>(normalized),
      ],
      readsFrom: {messages},
    ).get();
    return rows.firstOrNull == null
        ? null
        : _legacyReplyReferenceMessageFromRow(rows.first);
  }

  _LegacyReplyReferenceMessage _legacyReplyReferenceMessageFromRow(
    QueryRow row,
  ) {
    return _LegacyReplyReferenceMessage(
      id: row.read<String>('id'),
      stanzaId: row.read<String>('stanza_i_d'),
      chatJid: row.read<String>('chat_jid'),
      body: row.read<String?>('body'),
      htmlBody: row.read<String?>('html_body'),
      fileMetadataId: row.read<String?>('file_metadata_i_d'),
      originId: row.read<String?>('origin_i_d'),
      mucStanzaId: row.read<String?>('muc_stanza_id'),
      deltaAccountId: row.read<int?>('delta_account_id'),
      deltaChatId: row.read<int?>('delta_chat_id'),
    );
  }

  Future<_LegacyReplyReferenceMessage?>
  _preferredLegacyReplyReferenceDeltaMessage(
    List<_LegacyReplyReferenceMessage> rows,
  ) async {
    return await _preferredLegacyReplyReferenceDeltaMessageBy(
          rows,
          _legacyReplyReferenceMatchesStoredChatAccount,
        ) ??
        await _preferredLegacyReplyReferenceDeltaMessageBy(
          rows,
          _legacyReplyReferenceMatchesSingleContextChatAccount,
        ) ??
        await _preferredLegacyReplyReferenceDeltaMessageBy(
          rows,
          _legacyReplyReferenceChatDeltaIdMatchesMessage,
        ) ??
        _uniqueLegacyReplyReferenceMessageBy(
          rows,
          (row) => row.deltaAccountId == DeltaAccountDefaults.singleContextId,
        ) ??
        _uniqueLegacyReplyReferenceMessageBy(
          rows,
          (row) => genuineEmailMessageId(row.originId) != null,
        );
  }

  Future<_LegacyReplyReferenceMessage?>
  _preferredLegacyReplyReferenceDeltaMessageBy(
    List<_LegacyReplyReferenceMessage> rows,
    Future<bool> Function(_LegacyReplyReferenceMessage row) predicate,
  ) async {
    final matches = <_LegacyReplyReferenceMessage>[];
    for (final row in rows) {
      if (await predicate(row)) {
        matches.add(row);
      }
    }
    if (matches.isEmpty) {
      return null;
    }
    return _preferredDuplicateLegacyReplyReferenceRow(matches);
  }

  _LegacyReplyReferenceMessage? _uniqueLegacyReplyReferenceMessageBy(
    List<_LegacyReplyReferenceMessage> rows,
    bool Function(_LegacyReplyReferenceMessage row) predicate,
  ) {
    _LegacyReplyReferenceMessage? match;
    for (final row in rows) {
      if (!predicate(row)) {
        continue;
      }
      if (match != null) {
        return null;
      }
      match = row;
    }
    return match;
  }

  _LegacyReplyReferenceMessage _preferredDuplicateLegacyReplyReferenceRow(
    List<_LegacyReplyReferenceMessage> rows,
  ) {
    return _uniqueLegacyReplyReferenceMessageBy(
          rows,
          (row) => row.deltaAccountId == DeltaAccountDefaults.singleContextId,
        ) ??
        _uniqueLegacyReplyReferenceMessageBy(
          rows,
          (row) => genuineEmailMessageId(row.originId) != null,
        ) ??
        _uniqueLegacyReplyReferenceMessageBy(
          rows,
          (row) => row.hasStableContent,
        ) ??
        rows.first;
  }

  Future<bool> _legacyReplyReferenceMatchesStoredChatAccount(
    _LegacyReplyReferenceMessage row,
  ) async {
    final deltaChatId = row.deltaChatId;
    final deltaAccountId = row.deltaAccountId;
    if (deltaChatId == null || deltaAccountId == null) {
      return false;
    }
    final mapped = await _emailChatAccountJid(
      deltaAccountId: deltaAccountId,
      deltaChatId: deltaChatId,
    );
    return mapped == row.chatJid;
  }

  Future<bool> _legacyReplyReferenceMatchesSingleContextChatAccount(
    _LegacyReplyReferenceMessage row,
  ) async {
    final deltaChatId = row.deltaChatId;
    if (deltaChatId == null) {
      return false;
    }
    final mapped = await _emailChatAccountJid(
      deltaAccountId: DeltaAccountDefaults.singleContextId,
      deltaChatId: deltaChatId,
    );
    return mapped == row.chatJid;
  }

  Future<bool> _legacyReplyReferenceChatDeltaIdMatchesMessage(
    _LegacyReplyReferenceMessage row,
  ) async {
    final deltaChatId = row.deltaChatId;
    if (deltaChatId == null) {
      return false;
    }
    final chatRows = await customSelect(
      '''
SELECT delta_chat_id
FROM chats
WHERE jid = ?
LIMIT 1
''',
      variables: [Variable<String>(row.chatJid)],
      readsFrom: {chats},
    ).get();
    return chatRows.firstOrNull?.read<int?>('delta_chat_id') == deltaChatId;
  }

  Future<void> _migrateDraftQuoteFieldsFromLegacyQuoting() async {
    if (!await _tableHasColumn(drafts.actualTableName, 'quoting_stanza_id')) {
      return;
    }
    final hasLegacyTypeColumn = await _tableHasColumn(
      drafts.actualTableName,
      'quoting_reference_kind',
    );
    final legacyTypeSelection = hasLegacyTypeColumn
        ? 'quoting_reference_kind'
        : 'NULL AS quoting_reference_kind';
    final rows = await customSelect(
      '''
SELECT id, quoting_stanza_id, $legacyTypeSelection
FROM drafts
WHERE quoting_stanza_id IS NOT NULL AND trim(quoting_stanza_id) != ''
''',
      readsFrom: {drafts},
    ).get();
    if (rows.isEmpty) {
      return;
    }
    const legacyOriginIdType = 1;
    const legacyMucStanzaIdType = 2;
    for (final row in rows) {
      final id = row.read<int>('id');
      final legacyValue = row.read<String>('quoting_stanza_id').trim();
      if (legacyValue.isEmpty ||
          isLegacyWireMessageReferenceValue(legacyValue)) {
        continue;
      }
      String? quotingStanzaId = legacyValue;
      String? quotingOriginId;
      String? quotingMucStanzaId;
      final legacyType = row.read<int?>('quoting_reference_kind');
      if (legacyType == legacyOriginIdType) {
        quotingStanzaId = null;
        quotingOriginId = legacyValue;
      } else if (legacyType == legacyMucStanzaIdType) {
        quotingStanzaId = null;
        quotingMucStanzaId = legacyValue;
      }
      await (update(drafts)..where((tbl) => tbl.id.equals(id))).write(
        DraftsCompanion(
          quotingStanzaId: Value(quotingStanzaId),
          quotingOriginId: Value(quotingOriginId),
          quotingMucStanzaId: Value(quotingMucStanzaId),
        ),
      );
    }
  }

  Future<void> _migrateEmailRfc822BodyStatusFromPseudoData() async {
    final rows = await customSelect(
      '''
SELECT stanza_i_d, pseudo_message_data
FROM messages
WHERE pseudo_message_data LIKE ?
''',
      variables: [Variable<String>('%emailRfc822Body%')],
      readsFrom: {messages},
    ).get();
    if (rows.isEmpty) {
      return;
    }
    const converter = MapStringDynamicConverter();
    for (final row in rows) {
      final stanzaId = row.read<String>('stanza_i_d');
      final rawPseudoMessageData = row.read<String?>('pseudo_message_data');
      if (rawPseudoMessageData == null || rawPseudoMessageData.trim().isEmpty) {
        continue;
      }
      final pseudoMessageData = converter.fromSql(rawPseudoMessageData);
      if (!pseudoMessageData.containsKey('emailRfc822Body')) {
        continue;
      }
      final status = pseudoMessageData['emailRfc822Body'] == true
          ? EmailRfc822BodyStatus.hydrated
          : EmailRfc822BodyStatus.unknown;
      final updatedPseudoMessageData = Map<String, dynamic>.from(
        pseudoMessageData,
      )..remove('emailRfc822Body');
      await customStatement(
        '''
UPDATE messages
SET rfc822_body_status = ?,
    pseudo_message_data = ?
WHERE stanza_i_d = ?
''',
        [
          status.index,
          updatedPseudoMessageData.isEmpty
              ? null
              : converter.toSql(updatedPseudoMessageData),
          stanzaId,
        ],
      );
    }
  }

  Future<int> clearXmppErrorsFromEmailMessages() {
    const xmppErrors = [MessageError.serviceUnavailable, MessageError.unknown];
    final query = update(messages)
      ..where(
        (tbl) =>
            (tbl.deltaMsgId.isNotNull() | tbl.deltaChatId.isNotNull()) &
            tbl.error.isInValues(xmppErrors),
      );
    return query.write(
      const MessagesCompanion(error: Value(MessageError.none)),
    );
  }

  @override
  Future<void> seedSystemMessageCollections() async {
    final now = DateTime.timestamp().toUtc();
    final collections = SystemMessageCollection.values.map(
      (collection) => MessageCollectionEntry(
        id: collection.id,
        title: null,
        isSystem: true,
        sortOrder: collection.sortOrder,
        createdAt: now,
        updatedAt: now,
        active: true,
      ),
    );
    for (final entry in collections) {
      await into(messageCollections).insertOnConflictUpdate(entry);
    }
  }

  Future<void> _migrateContactPreferencesToPrivateContacts() async {
    final preferences = await select(contactPreferences).get();
    if (preferences.isEmpty) {
      return;
    }
    await batch((batch) {
      for (final preference in preferences) {
        final key = contactDirectoryAddressKey(preference.addressKey);
        if (key.isEmpty) {
          continue;
        }
        final updatedAt = preference.updatedAt.toUtc();
        batch.insert(
          privateContactRecords,
          PrivateContactRecordsCompanion.insert(
            addressKey: key,
            active: const Value(true),
            manual: const Value(false),
            favorited: Value(preference.favorited),
            displayNameOverride: Value(preference.displayNameOverride),
            folderCollectionId: Value(preference.folderCollectionId),
            favoriteUpdatedAt: Value(updatedAt),
            displayNameUpdatedAt: Value(updatedAt),
            folderRuleUpdatedAt: Value(preference.folderRuleUpdatedAt),
            createdAt: Value(updatedAt),
            updatedAt: Value(updatedAt),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  @override
  Stream<List<MessageCollectionEntry>> watchMessageCollections({
    bool includeInactive = false,
    bool includeSystem = true,
  }) {
    return _messageCollectionsQuery(
      includeInactive: includeInactive,
      includeSystem: includeSystem,
    ).watch().map(_sortMessageCollections).distinct(listEquals);
  }

  @override
  Future<List<MessageCollectionEntry>> getMessageCollections({
    bool includeInactive = false,
    bool includeSystem = true,
  }) async => _sortMessageCollections(
    await _messageCollectionsQuery(
      includeInactive: includeInactive,
      includeSystem: includeSystem,
    ).get(),
  );

  SimpleSelectStatement<$MessageCollectionsTable, MessageCollectionEntry>
  _messageCollectionsQuery({
    required bool includeInactive,
    required bool includeSystem,
  }) {
    final query = select(messageCollections);
    if (!includeInactive) {
      query.where((tbl) => tbl.active.equals(true));
    }
    if (!includeSystem) {
      query.where((tbl) => tbl.isSystem.equals(false));
    }
    return query;
  }

  List<MessageCollectionEntry> _sortMessageCollections(
    List<MessageCollectionEntry> entries,
  ) {
    final sorted = List<MessageCollectionEntry>.of(entries)
      ..sort((a, b) {
        final systemOrder = (b.isSystem ? 1 : 0).compareTo(a.isSystem ? 1 : 0);
        if (systemOrder != 0) {
          return systemOrder;
        }
        final sortOrder = a.sortOrder.compareTo(b.sortOrder);
        if (sortOrder != 0) {
          return sortOrder;
        }
        final titleOrder = a.displayTitle.toLowerCase().compareTo(
          b.displayTitle.toLowerCase(),
        );
        if (titleOrder != 0) {
          return titleOrder;
        }
        return a.id.compareTo(b.id);
      });
    return List<MessageCollectionEntry>.unmodifiable(sorted);
  }

  @override
  Future<MessageCollectionEntry?> getMessageCollection(String collectionId) {
    final normalizedCollectionId = collectionId.trim();
    if (normalizedCollectionId.isEmpty) {
      return Future<MessageCollectionEntry?>.value();
    }
    final query = select(messageCollections)
      ..where((tbl) => tbl.id.equals(normalizedCollectionId));
    return query.getSingleOrNull();
  }

  @override
  Future<void> applyMessageCollectionDefinitionMutation({
    required String collectionId,
    required DateTime updatedAt,
    required bool active,
  }) async {
    final normalizedCollectionId = normalizeCustomMessageCollectionId(
      collectionId,
    );
    if (normalizedCollectionId == null ||
        SystemMessageCollection.isSystemId(normalizedCollectionId)) {
      return;
    }
    final normalizedUpdatedAt = updatedAt.toUtc();
    await transaction(() async {
      final existing = await getMessageCollection(normalizedCollectionId);
      if (existing != null &&
          !normalizedUpdatedAt.isAfter(existing.updatedAt.toUtc())) {
        return;
      }
      await into(messageCollections).insertOnConflictUpdate(
        MessageCollectionEntry(
          id: normalizedCollectionId,
          title: null,
          isSystem: false,
          sortOrder: existing?.sortOrder ?? 0,
          createdAt: existing?.createdAt.toUtc() ?? normalizedUpdatedAt,
          updatedAt: normalizedUpdatedAt,
          active: active,
        ),
      );
    });
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
    ).watch().map(_filterMessagesForDisplay);
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
    ).get().then(_filterMessagesForDisplay);
  }

  @override
  Future<List<Message>> getChatMessagesBefore(
    String jid, {
    required DateTime beforeTimestamp,
    required String beforeStanzaId,
    int? beforeDeltaMsgId,
    required int limit,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    final beforeRowId = await _chatMessageCursorRowId(
      jid: jid,
      beforeStanzaId: beforeStanzaId,
      beforeDeltaMsgId: beforeDeltaMsgId,
    );
    return _chatMessagesBeforeSelectable(
      jid: jid,
      filter: filter,
      limit: limit,
      beforeTimestamp: beforeTimestamp,
      beforeRowId: beforeRowId,
      beforeDeltaMsgId: beforeDeltaMsgId,
    ).get().then(_filterMessagesForDisplay);
  }

  @override
  Future<int> countChatMessages(
    String jid, {
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    bool includePseudoMessages = true,
  }) async {
    final countExpression = messages.rowId.count(distinct: true);
    final query = _chatMessagesCountJoin(jid: jid, filter: filter)
      ..addColumns([countExpression]);
    if (!includePseudoMessages) {
      query.where(messages.pseudoMessageType.isNull());
    }
    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  @override
  Future<bool> hasDisplayableMessagesForChat(String jid) async {
    final countExpression = messages.rowId.count();
    final query = selectOnly(messages)
      ..addColumns([countExpression])
      ..where(
        messages.chatJid.equals(jid) &
            _timelineDisplayableMessageExpression(messages),
      );
    final row = await query.getSingle();
    return (row.read(countExpression) ?? 0) > 0;
  }

  @override
  Future<int> countEmailBackedChatMessages(
    String jid, {
    int? deltaAccountId,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    bool includePseudoMessages = true,
  }) async {
    final countExpression = messages.rowId.count(distinct: true);
    final query = _chatMessagesCountJoin(jid: jid, filter: filter)
      ..addColumns([countExpression])
      ..where(
        messages.deltaChatId.isNotNull() | messages.deltaMsgId.isNotNull(),
      );
    if (!includePseudoMessages) {
      query.where(messages.pseudoMessageType.isNull());
    }
    if (deltaAccountId != null) {
      query.where(messages.deltaAccountId.equals(deltaAccountId));
    }
    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  String _visibleMessageSqlPredicate(String alias) =>
      '''
    NOT (
      $alias.received = 0
      AND lower(trim(COALESCE($alias.sender_jid, ''))) =
          lower(trim(COALESCE($alias.chat_jid, '')))
      AND lower(trim(COALESCE($alias.subject, ''))) =
          'multi device synchronization'
      AND lower(trim(COALESCE($alias.body, ''))) LIKE
          'this message is used to synchronize data between your devices%'
    )
  ''';

  bool _shouldDisplayMessage(Message message) {
    if (message.isHiddenMultiDeviceSyncMessage) {
      return false;
    }
    return true;
  }

  String _timelineOrderSql(String alias, {required bool newestFirst}) {
    final direction = newestFirst ? 'DESC' : 'ASC';
    return '''
      $alias.timestamp $direction,
      CASE WHEN $alias.delta_msg_id IS NOT NULL THEN 1 ELSE 0 END $direction,
      $alias.delta_msg_id $direction,
      $alias.rowid $direction
    ''';
  }

  List<OrderingTerm> _timelineOrdering({required bool newestFirst}) {
    final mode = newestFirst ? OrderingMode.desc : OrderingMode.asc;
    return [
      OrderingTerm(expression: messages.timestamp, mode: mode),
      OrderingTerm(expression: messages.deltaMsgId.isNotNull(), mode: mode),
      OrderingTerm(expression: messages.deltaMsgId, mode: mode),
      OrderingTerm(expression: messages.rowId, mode: mode),
    ];
  }

  List<OrderingTerm Function($MessagesTable)> _timelineMessageOrdering({
    required bool newestFirst,
  }) {
    final mode = newestFirst ? OrderingMode.desc : OrderingMode.asc;
    return [
      (tbl) => OrderingTerm(expression: tbl.timestamp, mode: mode),
      (tbl) => OrderingTerm(expression: tbl.deltaMsgId.isNotNull(), mode: mode),
      (tbl) => OrderingTerm(expression: tbl.deltaMsgId, mode: mode),
      (tbl) => OrderingTerm(expression: tbl.rowId, mode: mode),
    ];
  }

  List<Message> _filterMessagesForDisplay(Iterable<Message> messages) {
    return messages.where(_shouldDisplayMessage).toList(growable: false);
  }

  @override
  Future<int> countChatMessagesThrough(
    String jid, {
    required DateTime throughTimestamp,
    required String throughStanzaId,
    int? throughDeltaMsgId,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    final throughRowId = await _chatMessageCursorRowId(
      jid: jid,
      beforeStanzaId: throughStanzaId,
      beforeDeltaMsgId: throughDeltaMsgId,
    );
    final Expression<bool> sameTimestampThrough;
    if (throughDeltaMsgId != null && throughDeltaMsgId > 0) {
      final rowCursor = throughRowId ?? -1;
      sameTimestampThrough =
          messages.deltaMsgId.isNotNull() &
          (messages.deltaMsgId.isBiggerThanValue(throughDeltaMsgId) |
              (messages.deltaMsgId.equals(throughDeltaMsgId) &
                  messages.rowId.isBiggerOrEqualValue(rowCursor)));
    } else if (throughRowId != null) {
      sameTimestampThrough =
          messages.deltaMsgId.isNotNull() |
          (messages.deltaMsgId.isNull() &
              messages.rowId.isBiggerOrEqualValue(throughRowId));
    } else {
      sameTimestampThrough = const Constant(false);
    }
    final countExpression = messages.rowId.count(distinct: true);
    final query = _chatMessagesCountJoin(jid: jid, filter: filter)
      ..addColumns([countExpression])
      ..where(
        messages.timestamp.isBiggerThanValue(throughTimestamp) |
            (messages.timestamp.equals(throughTimestamp) &
                sameTimestampThrough),
      );
    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  Selectable<Message> _chatMessagesSelectable({
    required String jid,
    required MessageTimelineFilter filter,
    required int limit,
    required int offset,
  }) {
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
        AND ${_visibleMessageSqlPredicate('m')}
        AND (
          CASE WHEN ? = 0 THEN
            (mc.share_id IS NULL OR COALESCE(ms.participant_count, 0) <= 2)
          ELSE
            (mc.share_id IS NULL OR mp.contact_jid IS NOT NULL)
          END
        )
      ORDER BY ${_timelineOrderSql('m', newestFirst: true)}
      LIMIT ?
      OFFSET ?
      ''',
      variables: [
        Variable<String>(jid),
        Variable<String>(jid),
        Variable<int>(filter.index),
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

  JoinedSelectStatement<HasResultSet, dynamic> _chatMessagesCountJoin({
    required String jid,
    required MessageTimelineFilter filter,
  }) {
    final query = selectOnly(messages).join(_chatMessageShareJoins(jid))
      ..where(
        messages.chatJid.equals(jid) &
            _timelineDisplayableMessageExpression(messages) &
            _timelineShareFilterExpression(filter),
      );
    return query;
  }

  Selectable<Message> _chatMessagesBeforeSelectable({
    required String jid,
    required MessageTimelineFilter filter,
    required int limit,
    required DateTime beforeTimestamp,
    required int? beforeRowId,
    required int? beforeDeltaMsgId,
  }) {
    final Expression<bool> sameTimestampBefore;
    if (beforeDeltaMsgId != null && beforeDeltaMsgId > 0) {
      final rowCursor = beforeRowId ?? -1;
      sameTimestampBefore =
          messages.deltaMsgId.isNull() |
          messages.deltaMsgId.isSmallerThanValue(beforeDeltaMsgId) |
          (messages.deltaMsgId.equals(beforeDeltaMsgId) &
              messages.rowId.isSmallerThanValue(rowCursor));
    } else if (beforeRowId != null) {
      sameTimestampBefore =
          messages.deltaMsgId.isNull() &
          messages.rowId.isSmallerThanValue(beforeRowId);
    } else {
      sameTimestampBefore = const Constant(false);
    }
    final query = _chatMessagesJoin(jid: jid, filter: filter)
      ..where(
        messages.timestamp.isSmallerThanValue(beforeTimestamp) |
            (messages.timestamp.equals(beforeTimestamp) & sameTimestampBefore),
      )
      ..orderBy(_timelineOrdering(newestFirst: true))
      ..limit(limit);
    return query.map((row) => row.readTable(messages));
  }

  JoinedSelectStatement<HasResultSet, dynamic> _chatMessagesJoin({
    required String jid,
    required MessageTimelineFilter filter,
  }) {
    final query = select(messages).join(_chatMessageShareJoins(jid))
      ..where(
        messages.chatJid.equals(jid) &
            _timelineDisplayableMessageExpression(messages) &
            _timelineShareFilterExpression(filter),
      );
    return query;
  }

  List<Join> _chatMessageShareJoins(String jid) {
    return [
      leftOuterJoin(
        messageCopies,
        messageCopies.dcMsgId.equalsExp(messages.deltaMsgId) &
            messageCopies.dcAccountId.equalsExp(messages.deltaAccountId),
      ),
      leftOuterJoin(
        messageShares,
        messageShares.shareId.equalsExp(messageCopies.shareId),
      ),
      leftOuterJoin(
        messageParticipants,
        messageParticipants.shareId.equalsExp(messageCopies.shareId) &
            messageParticipants.contactJid.equals(jid),
      ),
    ];
  }

  Expression<bool> _timelineDisplayableMessageExpression(
    $MessagesTable messageTable,
  ) {
    return _timelineVisibleSyncMessageExpression(messageTable);
  }

  Expression<bool> _timelineVisibleSyncMessageExpression(
    $MessagesTable messageTable,
  ) {
    final normalizedSender = coalesce<String>([
      messageTable.senderJid,
      const Constant(''),
    ]).trim().lower();
    final normalizedChat = coalesce<String>([
      messageTable.chatJid,
      const Constant(''),
    ]).trim().lower();
    final normalizedSubject = coalesce<String>([
      messageTable.subject,
      const Constant(''),
    ]).trim().lower();
    final normalizedBody = coalesce<String>([
      messageTable.body,
      const Constant(''),
    ]).trim().lower();
    final hiddenSyncMessage =
        messageTable.received.equals(false) &
        normalizedSender.equalsExp(normalizedChat) &
        normalizedSubject.equals('multi device synchronization') &
        normalizedBody.like(
          'this message is used to synchronize data between your devices%',
        );
    return hiddenSyncMessage.not();
  }

  Expression<bool> _timelineShareFilterExpression(
    MessageTimelineFilter filter,
  ) {
    if (filter.isDirect) {
      return messageCopies.shareId.isNull() |
          coalesce<int>([
            messageShares.participantCount,
            const Constant(0),
          ]).isSmallerOrEqualValue(2);
    }
    return messageCopies.shareId.isNull() |
        messageParticipants.contactJid.isNotNull();
  }

  Future<int?> _chatMessageCursorRowId({
    required String jid,
    required String beforeStanzaId,
    int? beforeDeltaMsgId,
  }) async {
    final normalizedStanzaId = beforeStanzaId.trim();
    if (normalizedStanzaId.isNotEmpty) {
      final row =
          await (selectOnly(messages)
                ..addColumns([messages.rowId])
                ..where(
                  messages.chatJid.equals(jid) &
                      messages.stanzaID.equals(normalizedStanzaId) &
                      _timelineDisplayableMessageExpression(messages),
                ))
              .getSingleOrNull();
      final rowId = row?.read(messages.rowId);
      if (rowId != null) {
        return rowId;
      }
    }
    if (beforeDeltaMsgId == null || beforeDeltaMsgId <= 0) {
      return null;
    }
    final row =
        await (selectOnly(messages)
              ..addColumns([messages.rowId])
              ..where(
                messages.chatJid.equals(jid) &
                    messages.deltaMsgId.equals(beforeDeltaMsgId) &
                    _timelineDisplayableMessageExpression(messages),
              )
              ..orderBy([
                OrderingTerm(
                  expression: messages.rowId,
                  mode: OrderingMode.desc,
                ),
              ]))
            .getSingleOrNull();
    return row?.read(messages.rowId);
  }

  @override
  Future<List<Message>> getAllMessagesForChat(
    String jid, {
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    final query = select(messages)
      ..where((tbl) => tbl.chatJid.equals(jid))
      ..orderBy(_timelineMessageOrdering(newestFirst: false));
    final rows = await query.get();
    return _filterMessagesForDisplay(rows);
  }

  @override
  Future<List<MessageDeltaSnapshot>> getMessageDeltaSnapshot(
    String jid, {
    int? deltaAccountId,
  }) async {
    final query = selectOnly(messages)
      ..addColumns([messages.stanzaID, messages.deltaMsgId, messages.displayed])
      ..where(messages.chatJid.equals(jid));
    if (deltaAccountId != null) {
      query.where(messages.deltaAccountId.equals(deltaAccountId));
    }
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
    return selectable
        .map((row) => messages.map(row.data))
        .get()
        .then(_filterMessagesForDisplay);
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
        if (_messageExcludedFromChatSummary(message)) {
          continue;
        }
        final bool isInternalSync = await _isInternalSyncMessage(
          subject: message.subject,
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
    final matches = await getMessagesByOriginID(originID, chatJid: chatJid);
    return matches.firstOrNull;
  }

  @override
  Future<List<Message>> getMessagesByOriginID(
    String originID, {
    String? chatJid,
  }) async {
    final originIds = _emailOriginIdCandidates(originID);
    if (originIds.isEmpty) {
      return const <Message>[];
    }
    final normalizedChatJid = chatJid?.trim();
    final query = select(messages)
      ..where((tbl) => tbl.originID.isIn(originIds))
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.timestamp),
        (tbl) => OrderingTerm.asc(tbl.deltaMsgId),
        (tbl) => OrderingTerm.asc(tbl.stanzaID),
      ]);
    if (normalizedChatJid != null && normalizedChatJid.isNotEmpty) {
      query.where((tbl) => tbl.chatJid.equals(normalizedChatJid));
    }
    return query.get();
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
      return await (select(messages)
            ..where(
              (tbl) =>
                  tbl.chatJid.equals(normalizedChatJid) &
                  (tbl.stanzaID.equals(normalized) |
                      tbl.originID.equals(normalized) |
                      tbl.mucStanzaId.equals(normalized)),
            )
            ..orderBy([
              (tbl) => OrderingTerm.asc(tbl.timestamp),
              (tbl) => OrderingTerm.asc(tbl.stanzaID),
            ])
            ..limit(1))
          .getSingleOrNull();
    }
    return await getMessageByStanzaID(normalized) ??
        await getMessageByOriginID(normalized) ??
        await messagesAccessor.selectOneByMucStanzaId(normalized);
  }

  @override
  Future<Message?> getNewestChatMessageByReferenceIds({
    required String chatJid,
    required Iterable<String> referenceIds,
    bool includeEmailBacked = true,
  }) {
    final normalizedChatJid = chatJid.trim();
    final ids = referenceIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedChatJid.isEmpty || ids.isEmpty) {
      return Future<Message?>.value();
    }
    final query = select(messages)
      ..where(
        (tbl) =>
            tbl.chatJid.equals(normalizedChatJid) &
            (tbl.stanzaID.isIn(ids) |
                tbl.originID.isIn(ids) |
                tbl.mucStanzaId.isIn(ids)),
      );
    if (!includeEmailBacked) {
      query.where((tbl) => tbl.deltaChatId.isNull() & tbl.deltaMsgId.isNull());
    }
    query
      ..orderBy(_timelineMessageOrdering(newestFirst: true))
      ..limit(1);
    return query.getSingleOrNull();
  }

  @override
  Future<Message?> getMessageByDeltaId(
    int deltaMsgId, {
    int? deltaAccountId,
    String? chatJid,
  }) {
    final query = select(messages)
      ..where((tbl) => tbl.deltaMsgId.equals(deltaMsgId))
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.timestamp),
        (tbl) => OrderingTerm.asc(tbl.stanzaID),
      ])
      ..limit(1);
    if (deltaAccountId != null) {
      query.where((tbl) => tbl.deltaAccountId.equals(deltaAccountId));
    }
    if (chatJid != null) {
      query.where((tbl) => tbl.chatJid.equals(chatJid));
    }
    return query.getSingleOrNull();
  }

  @override
  Future<List<Message>> getRecoverableOutgoingDeltaMessages({
    required int deltaAccountId,
    required String senderJid,
    required DateTime since,
    required int limit,
  }) {
    final query = select(messages)
      ..where(
        (tbl) =>
            tbl.deltaAccountId.equals(deltaAccountId) &
            tbl.deltaMsgId.isNotNull() &
            tbl.deltaChatId.isNotNull() &
            tbl.senderJid.equals(senderJid) &
            tbl.displayed.equals(false) &
            tbl.timestamp.isBiggerOrEqualValue(since),
      )
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)])
      ..limit(limit);
    return query.get();
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
  Future<List<Message>> getMessagesByDeltaChat({
    required int deltaAccountId,
    required int deltaChatId,
  }) {
    if (deltaAccountId <= 0 || deltaChatId <= 0) {
      return Future.value(const <Message>[]);
    }
    return (select(messages)
          ..where(
            (tbl) =>
                tbl.deltaAccountId.equals(deltaAccountId) &
                tbl.deltaChatId.equals(deltaChatId) &
                tbl.deltaMsgId.isNotNull(),
          )
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.timestamp),
            (tbl) => OrderingTerm.asc(tbl.deltaMsgId),
            (tbl) => OrderingTerm.asc(tbl.stanzaID),
          ]))
        .get();
  }

  @override
  Future<List<Message>> getUndisplayedMessagesByDeltaChat({
    required int deltaAccountId,
    required int deltaChatId,
    required int limit,
  }) {
    if (deltaAccountId <= 0 || deltaChatId <= 0 || limit <= 0) {
      return Future.value(const <Message>[]);
    }
    return (select(messages)
          ..where(
            (tbl) =>
                tbl.deltaAccountId.equals(deltaAccountId) &
                tbl.deltaChatId.equals(deltaChatId) &
                tbl.deltaMsgId.isNotNull() &
                tbl.displayed.equals(false),
          )
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.timestamp),
            (tbl) => OrderingTerm.asc(tbl.deltaMsgId),
            (tbl) => OrderingTerm.asc(tbl.stanzaID),
          ])
          ..limit(limit))
        .get();
  }

  @override
  Future<Message?> getOldestUnreadEmailBackedMessageForChat(
    String jid, {
    String? selfJid,
    String? emailSelfJid,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    final normalizedJid = jid.trim();
    if (normalizedJid.isEmpty) {
      return null;
    }
    const pageSize = 128;
    var offset = 0;
    while (true) {
      final rows =
          await (_chatMessagesJoin(jid: normalizedJid, filter: filter)
                ..where(
                  (messages.deltaChatId.isNotNull() |
                          messages.deltaMsgId.isNotNull()) &
                      messages.displayed.equals(false),
                )
                ..orderBy([..._timelineOrdering(newestFirst: false)])
                ..limit(pageSize, offset: offset))
              .map((row) => row.readTable(messages))
              .get();
      if (rows.isEmpty) {
        return null;
      }
      for (final message in rows) {
        if (message.countsTowardUnread(
          selfJid: message.isEmailBacked ? emailSelfJid ?? selfJid : selfJid,
          isGroupChat: false,
          myOccupantJid: null,
        )) {
          return message;
        }
      }
      if (rows.length < pageSize) {
        return null;
      }
      offset += rows.length;
    }
  }

  @override
  Future<Message?> getOldestUnreadMessageForChat(
    String jid, {
    String? selfJid,
    String? emailSelfJid,
    bool isGroupChat = false,
    String? myOccupantJid,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) async {
    final normalizedJid = jid.trim();
    if (normalizedJid.isEmpty) {
      return null;
    }
    const pageSize = 128;
    var offset = 0;
    while (true) {
      final rows =
          await (_chatMessagesJoin(jid: normalizedJid, filter: filter)
                ..where(messages.displayed.equals(false))
                ..orderBy(_timelineOrdering(newestFirst: false))
                ..limit(pageSize, offset: offset))
              .map((row) => row.readTable(messages))
              .get();
      if (rows.isEmpty) {
        return null;
      }
      for (final message in rows) {
        if (message.countsTowardUnread(
          selfJid: message.isEmailBacked ? emailSelfJid ?? selfJid : selfJid,
          isGroupChat: !message.isEmailBacked && isGroupChat,
          myOccupantJid: message.isEmailBacked ? null : myOccupantJid,
        )) {
          return message;
        }
      }
      if (rows.length < pageSize) {
        return null;
      }
      offset += rows.length;
    }
  }

  @override
  Future<List<Message>> getDisplayedEmailMessagesPendingDeltaSeen({
    Iterable<String> chatJids = const <String>[],
    int limit = 100,
  }) {
    if (limit <= 0) {
      return Future.value(const <Message>[]);
    }
    final scopedChatJids = chatJids
        .map((jid) => jid.trim())
        .where((jid) => jid.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final query = select(messages)
      ..where(
        (tbl) =>
            tbl.deltaMsgId.isNotNull() &
            tbl.displayed.equals(true) &
            tbl.deltaSeenSynced.equals(false),
      );
    if (scopedChatJids.isNotEmpty) {
      query.where((tbl) => tbl.chatJid.isIn(scopedChatJids));
    }
    query
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.timestamp),
        (tbl) => OrderingTerm.asc(tbl.deltaMsgId),
        (tbl) => OrderingTerm.asc(tbl.stanzaID),
      ])
      ..limit(limit);
    return query.get();
  }

  @override
  Future<int> markDeltaMessagesSeenSynced({
    required int deltaAccountId,
    required Iterable<int> deltaMsgIds,
  }) {
    final ids = deltaMsgIds.where((id) => id > 0).toSet().toList();
    if (deltaAccountId <= 0 || ids.isEmpty) {
      return Future.value(0);
    }
    return (update(messages)..where(
          (tbl) =>
              tbl.deltaAccountId.equals(deltaAccountId) &
              tbl.deltaMsgId.isIn(ids) &
              tbl.deltaSeenSynced.equals(false),
        ))
        .write(const MessagesCompanion(deltaSeenSynced: Value(true)));
  }

  @override
  Future<List<Message>> getEmailMessagesWithDeltaAccountNotIn(
    List<int> validAccountIds,
  ) {
    final query = select(messages)
      ..where(
        (tbl) =>
            tbl.deltaMsgId.isNotNull() &
            tbl.deltaAccountId.isNotIn(validAccountIds),
      );
    return query.get();
  }

  @override
  Future<bool> repairMessageDeltaAccountIdIfUnclaimed({
    required String stanzaID,
    required int deltaAccountId,
  }) {
    return transaction(() async {
      final stored = await getMessageByStanzaID(stanzaID);
      final deltaMsgId = stored?.deltaMsgId;
      if (stored == null || deltaMsgId == null) {
        return false;
      }
      if (stored.deltaAccountId == deltaAccountId) {
        return true;
      }
      final claimed = await getMessageByDeltaId(
        deltaMsgId,
        deltaAccountId: deltaAccountId,
      );
      if (claimed != null && claimed.stanzaID != stored.stanzaID) {
        return false;
      }
      await (update(messages)..where((tbl) => tbl.stanzaID.equals(stanzaID)))
          .write(MessagesCompanion(deltaAccountId: Value(deltaAccountId)));
      return true;
    });
  }

  @override
  Future<void> clearMessageDeltaHandles(String stanzaID) async {
    await (update(
      messages,
    )..where((tbl) => tbl.stanzaID.equals(stanzaID))).write(
      const MessagesCompanion(
        deltaChatId: Value(null),
        deltaMsgId: Value(null),
      ),
    );
  }

  @override
  Future<void> updateMessageOriginId({
    required String stanzaID,
    required String originID,
  }) async {
    await (update(messages)..where((tbl) => tbl.stanzaID.equals(stanzaID)))
        .write(MessagesCompanion(originID: Value(originID)));
  }

  @override
  Future<void> clearChatDeltaChatId(String jid) async {
    await (update(chats)..where((tbl) => tbl.jid.equals(jid))).write(
      const ChatsCompanion(deltaChatId: Value(null)),
    );
  }

  @override
  Future<void> rebindMessageCollectionMembershipReferences({
    required String chatJid,
    required String oldReferenceId,
    required String newReferenceId,
  }) async {
    final entries =
        await (select(messageCollectionMemberships)..where(
              (tbl) =>
                  tbl.chatJid.equals(chatJid) &
                  tbl.messageReferenceId.equals(oldReferenceId),
            ))
            .get();
    for (final entry in entries) {
      await _rebindMembershipEntryReference(
        entry: entry,
        chatJid: chatJid,
        oldReferenceId: oldReferenceId,
        newReferenceId: newReferenceId,
      );
    }
  }

  @override
  Future<Message?> rehomeDeltaMessage({
    required int deltaMsgId,
    required int deltaAccountId,
    required int deltaChatId,
    required String chatJid,
    required String senderJid,
    String? selfJid,
    String? emailSelfJid,
  }) async {
    return transaction(() async {
      final existing = await getMessageByDeltaId(
        deltaMsgId,
        deltaAccountId: deltaAccountId,
      );
      if (existing == null) {
        return null;
      }
      if (existing.chatJid == chatJid && existing.deltaChatId == deltaChatId) {
        return existing;
      }
      final fromChatJid = existing.chatJid;
      final updated = existing.copyWith(
        chatJid: chatJid,
        deltaChatId: deltaChatId,
        senderJid: senderJid,
      );
      await updateMessage(updated);
      if (fromChatJid == chatJid) {
        return updated;
      }
      await _migrateMembershipChatJid(
        message: existing,
        fromChatJid: fromChatJid,
        toChatJid: chatJid,
      );
      await _migratePinChatJid(
        message: existing,
        fromChatJid: fromChatJid,
        toChatJid: chatJid,
      );
      await repairUnreadCountForChat(
        fromChatJid,
        selfJid: selfJid,
        emailSelfJid: emailSelfJid,
      );
      await repairUnreadCountForChat(
        chatJid,
        selfJid: selfJid,
        emailSelfJid: emailSelfJid,
      );
      await repairChatSummaryFromMessages(fromChatJid);
      await repairChatSummaryFromMessages(chatJid);
      return updated;
    });
  }

  @override
  Future<Message?> recoverStaleDeltaMessageLocator({
    required int deltaMsgId,
    required int deltaAccountId,
    required int deltaChatId,
    required String chatJid,
  }) {
    return transaction(() async {
      final existing = await getMessageByDeltaId(
        deltaMsgId,
        deltaAccountId: deltaAccountId,
      );
      if (existing != null) {
        return existing;
      }
      final mappedChatIds = await getDeltaChatIdsForAccount(
        chatJid: chatJid,
        deltaAccountId: deltaAccountId,
      );
      if (!mappedChatIds.contains(deltaChatId)) {
        return null;
      }
      final staleRows =
          await (select(messages)
                ..where(
                  (tbl) =>
                      tbl.deltaMsgId.equals(deltaMsgId) &
                      tbl.deltaChatId.equals(deltaChatId) &
                      tbl.chatJid.equals(chatJid) &
                      tbl.deltaAccountId.isNotValue(deltaAccountId),
                )
                ..orderBy([
                  (tbl) => OrderingTerm.asc(tbl.timestamp),
                  (tbl) => OrderingTerm.asc(tbl.stanzaID),
                ]))
              .get();
      if (staleRows.length != 1) {
        return null;
      }
      final stale = staleRows.single;
      final updated = stale.copyWith(
        deltaAccountId: deltaAccountId,
        deltaChatId: deltaChatId,
      );
      await updateMessage(updated);
      return updated;
    });
  }

  Future<void> _migratePinChatJid({
    required Message message,
    required String fromChatJid,
    required String toChatJid,
  }) async {
    final pinnedRows =
        await (select(pinnedMessages)..where(
              (tbl) =>
                  tbl.chatJid.equals(fromChatJid) &
                  tbl.messageStanzaId.equals(message.stanzaID),
            ))
            .get();
    for (final row in pinnedRows) {
      await (delete(pinnedMessages)..where(
            (tbl) =>
                tbl.chatJid.equals(fromChatJid) &
                tbl.messageStanzaId.equals(row.messageStanzaId),
          ))
          .go();
      await into(pinnedMessages).insert(
        row.copyWith(chatJid: toChatJid),
        mode: InsertMode.insertOrIgnore,
      );
    }
    final references = message.referenceIds;
    if (references.isEmpty) {
      return;
    }
    final pinRows =
        await (select(messagePins)..where(
              (tbl) =>
                  tbl.chatJid.equals(fromChatJid) &
                  tbl.messageReferenceId.isIn(references),
            ))
            .get();
    for (final row in pinRows) {
      await (delete(messagePins)..where(
            (tbl) =>
                tbl.chatJid.equals(fromChatJid) &
                tbl.messageReferenceId.equals(row.messageReferenceId) &
                tbl.pinnerJid.equals(row.pinnerJid),
          ))
          .go();
      await into(messagePins).insert(
        row.copyWith(chatJid: toChatJid),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  Future<void> _migratePinsToKeeper({
    required Message extra,
    required Message keeper,
  }) async {
    final pinnedRows =
        await (select(pinnedMessages)..where(
              (tbl) =>
                  tbl.chatJid.equals(extra.chatJid) &
                  tbl.messageStanzaId.equals(extra.stanzaID),
            ))
            .get();
    for (final row in pinnedRows) {
      await (delete(pinnedMessages)..where(
            (tbl) =>
                tbl.chatJid.equals(extra.chatJid) &
                tbl.messageStanzaId.equals(row.messageStanzaId),
          ))
          .go();
      await into(pinnedMessages).insert(
        row.copyWith(chatJid: keeper.chatJid, messageStanzaId: keeper.stanzaID),
        mode: InsertMode.insertOrIgnore,
      );
    }
    final references = extra.referenceIds;
    if (references.isEmpty) {
      return;
    }
    final pinRows =
        await (select(messagePins)..where(
              (tbl) =>
                  tbl.chatJid.equals(extra.chatJid) &
                  tbl.messageReferenceId.isIn(references),
            ))
            .get();
    for (final row in pinRows) {
      await (delete(messagePins)..where(
            (tbl) =>
                tbl.chatJid.equals(extra.chatJid) &
                tbl.messageReferenceId.equals(row.messageReferenceId) &
                tbl.pinnerJid.equals(row.pinnerJid),
          ))
          .go();
      final mappedReference = row.messageReferenceId == extra.stanzaID
          ? keeper.stanzaID
          : row.messageReferenceId;
      await into(messagePins).insert(
        row.copyWith(
          chatJid: keeper.chatJid,
          messageReferenceId: mappedReference,
          messageStanzaId: Value(keeper.stanzaID),
          messageOriginId: Value(keeper.originID),
          messageMucStanzaId: Value(keeper.mucStanzaId),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  Future<void> _migrateAttachmentsToKeeper({
    required Message extra,
    required Message keeper,
  }) async {
    final keeperId = keeper.id?.trim();
    if (keeperId == null || keeperId.isEmpty) {
      return;
    }
    final attachmentOwnerIds = <String>{};
    void addAttachmentOwnerId(String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        attachmentOwnerIds.add(trimmed);
      }
    }

    addAttachmentOwnerId(extra.id);
    addAttachmentOwnerId(extra.stanzaID);
    final attachments = await messageAttachmentsAccessor.selectForMessages(
      attachmentOwnerIds,
    );
    for (final attachment in attachments) {
      await into(messageAttachments).insert(
        MessageAttachmentsCompanion.insert(
          messageId: keeperId,
          fileMetadataId: attachment.fileMetadataId,
          sortOrder: Value(attachment.sortOrder),
          transportGroupId: Value(attachment.transportGroupId),
          groupQuotedReference: Value(attachment.groupQuotedReference),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  Future<void> _migrateReactionsToKeeper({
    required Message extra,
    required Message keeper,
  }) async {
    final reactionRows = await (select(
      reactions,
    )..where((tbl) => tbl.messageID.equals(extra.stanzaID))).get();
    for (final row in reactionRows) {
      await into(reactions).insert(
        ReactionsCompanion.insert(
          messageID: keeper.stanzaID,
          senderJid: row.senderJid,
          emoji: row.emoji,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    final reactionStateRows = await (select(
      reactionStates,
    )..where((tbl) => tbl.messageID.equals(extra.stanzaID))).get();
    for (final row in reactionStateRows) {
      final existing =
          await (select(reactionStates)..where(
                (tbl) =>
                    tbl.messageID.equals(keeper.stanzaID) &
                    tbl.senderJid.equals(row.senderJid),
              ))
              .getSingleOrNull();
      if (existing != null && !row.updatedAt.isAfter(existing.updatedAt)) {
        continue;
      }
      await into(reactionStates).insertOnConflictUpdate(
        ReactionStatesCompanion.insert(
          messageID: keeper.stanzaID,
          senderJid: row.senderJid,
          updatedAt: row.updatedAt,
          identityVerified: Value(row.identityVerified),
        ),
      );
    }
  }

  Future<void> _migrateMembershipChatJid({
    required Message message,
    required String fromChatJid,
    required String toChatJid,
  }) async {
    final references = message.referenceIds;
    final deltaMsgId = message.deltaMsgId;
    Expression<bool> referencePredicate(
      $MessageCollectionMembershipsTable tbl,
    ) {
      var predicate = tbl.messageReferenceId.isIn(references);
      if (deltaMsgId != null) {
        predicate =
            predicate |
            (tbl.deltaMsgId.equals(deltaMsgId) &
                tbl.deltaAccountId.equals(message.deltaAccountId));
      }
      return tbl.chatJid.equals(fromChatJid) & predicate;
    }

    final entries = await (select(
      messageCollectionMemberships,
    )..where(referencePredicate)).get();
    final tombstonedAt = DateTime.timestamp().toUtc();
    for (final entry in entries) {
      final occupied = await getMessageCollectionMembership(
        collectionId: entry.collectionId,
        chatJid: toChatJid,
        messageReferenceId: entry.messageReferenceId,
      );
      if (occupied == null) {
        await into(messageCollectionMemberships).insert(
          entry.copyWith(chatJid: toChatJid),
          mode: InsertMode.insertOrIgnore,
        );
      }
      await (update(messageCollectionMemberships)..where(
            (tbl) =>
                tbl.collectionId.equals(entry.collectionId) &
                tbl.chatJid.equals(fromChatJid) &
                tbl.messageReferenceId.equals(entry.messageReferenceId),
          ))
          .write(
            MessageCollectionMembershipsCompanion(
              active: const Value(false),
              addedAt: Value(tombstonedAt),
            ),
          );
    }
  }

  Future<void> _migrateDeltaDuplicateMemberships({
    required Message extra,
    required Message keeper,
  }) async {
    final references = extra.referenceIds;
    final deltaMsgId = extra.deltaMsgId;
    if (references.isEmpty && deltaMsgId == null) {
      return;
    }

    Expression<bool> referencePredicate(
      $MessageCollectionMembershipsTable tbl,
    ) {
      var predicate = references.isEmpty
          ? const Constant(false)
          : tbl.messageReferenceId.isIn(references);
      if (deltaMsgId != null) {
        predicate =
            predicate |
            (tbl.deltaMsgId.equals(deltaMsgId) &
                tbl.deltaAccountId.equals(extra.deltaAccountId));
      }
      return tbl.chatJid.equals(extra.chatJid) & predicate;
    }

    final entries = await (select(
      messageCollectionMemberships,
    )..where(referencePredicate)).get();
    for (final entry in entries) {
      final mappedReference = _membershipReferenceForKeeper(
        entry: entry,
        extra: extra,
        keeper: keeper,
      );
      final samePrimaryKey =
          entry.chatJid == keeper.chatJid &&
          entry.messageReferenceId == mappedReference;
      if (samePrimaryKey) {
        await _updateMembershipMessageLocator(entry: entry, keeper: keeper);
        continue;
      }
      final occupied = await getMessageCollectionMembership(
        collectionId: entry.collectionId,
        chatJid: keeper.chatJid,
        messageReferenceId: mappedReference,
      );
      if (occupied == null) {
        await into(messageCollectionMemberships).insert(
          MessageCollectionMembershipsCompanion.insert(
            collectionId: entry.collectionId,
            chatJid: keeper.chatJid,
            messageReferenceId: mappedReference,
            messageStanzaId: Value(keeper.stanzaID),
            messageOriginId: Value(keeper.originID),
            messageMucStanzaId: Value(keeper.mucStanzaId),
            deltaAccountId: Value(keeper.deltaAccountId),
            deltaMsgId: Value(keeper.deltaMsgId),
            addedAt: entry.addedAt,
            active: Value(entry.active),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      } else {
        await _mergeMembershipIntoOccupied(
          occupied: occupied,
          incoming: entry,
          keeper: keeper,
        );
      }
      await _deleteMembershipEntry(entry);
    }
  }

  String _membershipReferenceForKeeper({
    required MessageCollectionMembershipEntry entry,
    required Message extra,
    required Message keeper,
  }) {
    if (keeper.referenceIds.contains(entry.messageReferenceId)) {
      return entry.messageReferenceId;
    }
    if (entry.messageReferenceId == extra.stanzaID) {
      return keeper.stanzaID;
    }
    if (entry.messageReferenceId == extra.originID && keeper.originID != null) {
      return keeper.originID!;
    }
    return keeper.originID ?? keeper.stanzaID;
  }

  Future<void> _updateMembershipMessageLocator({
    required MessageCollectionMembershipEntry entry,
    required Message keeper,
  }) async {
    await (update(messageCollectionMemberships)..where(
          (tbl) =>
              tbl.collectionId.equals(entry.collectionId) &
              tbl.chatJid.equals(entry.chatJid) &
              tbl.messageReferenceId.equals(entry.messageReferenceId),
        ))
        .write(
          MessageCollectionMembershipsCompanion(
            messageStanzaId: Value(keeper.stanzaID),
            messageOriginId: Value(keeper.originID),
            messageMucStanzaId: Value(keeper.mucStanzaId),
            deltaAccountId: Value(keeper.deltaAccountId),
            deltaMsgId: Value(keeper.deltaMsgId),
          ),
        );
  }

  Future<void> _mergeMembershipIntoOccupied({
    required MessageCollectionMembershipEntry occupied,
    required MessageCollectionMembershipEntry incoming,
    required Message keeper,
  }) async {
    await (update(messageCollectionMemberships)..where(
          (tbl) =>
              tbl.collectionId.equals(occupied.collectionId) &
              tbl.chatJid.equals(occupied.chatJid) &
              tbl.messageReferenceId.equals(occupied.messageReferenceId),
        ))
        .write(
          MessageCollectionMembershipsCompanion(
            messageStanzaId: Value(keeper.stanzaID),
            messageOriginId: Value(keeper.originID),
            messageMucStanzaId: Value(keeper.mucStanzaId),
            deltaAccountId: Value(keeper.deltaAccountId),
            deltaMsgId: Value(keeper.deltaMsgId),
            active: Value(occupied.active || incoming.active),
            addedAt: incoming.active && !occupied.active
                ? Value(incoming.addedAt)
                : const Value.absent(),
          ),
        );
  }

  Future<void> _deleteMembershipEntry(
    MessageCollectionMembershipEntry entry,
  ) async {
    await (delete(messageCollectionMemberships)..where(
          (tbl) =>
              tbl.collectionId.equals(entry.collectionId) &
              tbl.chatJid.equals(entry.chatJid) &
              tbl.messageReferenceId.equals(entry.messageReferenceId),
        ))
        .go();
  }

  Future<void> _rebindMembershipEntryReference({
    required MessageCollectionMembershipEntry entry,
    required String chatJid,
    required String oldReferenceId,
    required String newReferenceId,
  }) async {
    final occupied = await getMessageCollectionMembership(
      collectionId: entry.collectionId,
      chatJid: chatJid,
      messageReferenceId: newReferenceId,
    );
    if (occupied != null) {
      await (delete(messageCollectionMemberships)..where(
            (tbl) =>
                tbl.collectionId.equals(entry.collectionId) &
                tbl.chatJid.equals(chatJid) &
                tbl.messageReferenceId.equals(oldReferenceId),
          ))
          .go();
      return;
    }
    await (update(messageCollectionMemberships)..where(
          (tbl) =>
              tbl.collectionId.equals(entry.collectionId) &
              tbl.chatJid.equals(chatJid) &
              tbl.messageReferenceId.equals(oldReferenceId),
        ))
        .write(
          MessageCollectionMembershipsCompanion(
            messageReferenceId: Value(newReferenceId),
            messageOriginId: Value(newReferenceId),
          ),
        );
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
  Future<List<Message>> getEmailMessagesByRfcGroup({
    required String chatJid,
    required String originID,
    required int deltaAccountId,
  }) {
    final normalizedChatJid = chatJid.trim();
    final originIds = _emailOriginIdCandidates(originID);
    if (normalizedChatJid.isEmpty || originIds.isEmpty) {
      return Future.value(const <Message>[]);
    }
    return (select(messages)
          ..where(
            (tbl) =>
                tbl.chatJid.equals(normalizedChatJid) &
                tbl.originID.isIn(originIds) &
                tbl.deltaAccountId.equals(deltaAccountId),
          )
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.timestamp),
            (tbl) => OrderingTerm.asc(tbl.deltaMsgId),
            (tbl) => OrderingTerm.asc(tbl.stanzaID),
          ]))
        .get();
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
        CalendarSyncMessage.looksLikeEnvelope(trimmed);
  }

  Future<bool> _isInternalSyncMessage({
    required String? subject,
    required String? body,
    required String? fileMetadataId,
  }) async {
    if (isMultiDeviceSyncMessage(subject: subject, body: body)) {
      return true;
    }
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

  @override
  Future<void> saveMessage(
    Message message, {
    ChatType chatType = ChatType.chat,
    String? selfJid,
  }) async {
    await saveMessageWithResult(message, chatType: chatType, selfJid: selfJid);
  }

  @override
  Future<MessageSaveResult> saveMessageWithResult(
    Message message, {
    ChatType chatType = ChatType.chat,
    String? selfJid,
  }) async {
    if ((message.deltaChatId != null || message.deltaMsgId != null) &&
        message.deltaAccountId == DeltaAccountDefaults.legacyId) {
      throw StateError('Delta-backed messages require a real account id.');
    }
    _log.fine('Persisting message');
    final resolvedMessageId = message.id ?? uuid.v4();
    final trimmedBody = message.body?.trim();
    final normalizedMetadataId = _normalizedFileMetadataIdOrNull(
      message.fileMetadataID,
    );
    final hasAttachment = normalizedMetadataId != null;
    final messageTimestamp = message.timestamp ?? DateTime.timestamp();
    final bool isInternalSync = await _isInternalSyncMessage(
      subject: message.subject,
      body: message.body,
      fileMetadataId: normalizedMetadataId,
    );
    final bool shouldUpdateChatSummary =
        !isInternalSync && !_messageExcludedFromChatSummary(message);
    final currentChat = await getChat(message.chatJid);
    final currentUnreadCount = currentChat?.unreadCount ?? 0;
    final existingStanzaMessage = await messagesAccessor.selectOne(
      message.stanzaID,
    );
    final Message? existingDeltaMessage;
    if (existingStanzaMessage == null && message.deltaMsgId != null) {
      existingDeltaMessage = await getMessageByDeltaId(
        message.deltaMsgId!,
        deltaAccountId: message.deltaAccountId,
      );
      if (existingDeltaMessage != null) {
        _log.fine(
          'Message save ignored because the Delta locator is already stored.',
        );
        return const MessageSaveResult(
          change: MessageSaveChange.ignored,
          unreadDelta: 0,
          chatSummaryChanged: false,
        );
      }
    } else {
      existingDeltaMessage = null;
    }
    final isAxiImServerAnnouncement = message.isAxiImServerAnnouncement;
    final bool isSelfMessage = message.isFromAccount(selfJid);
    final bool isSelfChat = sameNormalizedAddressValue(
      message.chatJid,
      selfJid,
    );
    final bool shouldNormalizeSelfChatTitle =
        isSelfChat &&
        currentChat?.contactDisplayName?.trim().isNotEmpty != true &&
        currentChat?.title.trim() != 'Saved Messages';
    final int unreadIncrement = existingStanzaMessage == null
        ? await _unreadIncrementForIncomingMessage(
            message: message,
            shouldUpdateChatSummary: shouldUpdateChatSummary,
            selfJid: selfJid,
            isSelfMessage: isSelfMessage,
          )
        : 0;
    final bool usesEmailUnreadCounter =
        currentChat?.defaultTransport.isEmail == true;
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
            fileMetadataId: normalizedMetadataId,
            hasAttachment: hasAttachment,
            pseudoMessageType: message.pseudoMessageType,
            pseudoMessageData: message.pseudoMessageData,
          )
        : null;
    final chatTitle = _chatTitleForIdentifier(
      message.chatJid,
      selfJid: selfJid,
    );
    return transaction(() async {
      var chatSummaryChanged = false;

      Future<MessageSaveResult> result(MessageSaveChange change) async {
        final updatedChat = await getChat(message.chatJid);
        return MessageSaveResult(
          change: change,
          unreadDelta:
              (updatedChat?.unreadCount ?? currentUnreadCount) -
              currentUnreadCount,
          chatSummaryChanged: chatSummaryChanged,
        );
      }

      await into(chats).insert(
        ChatsCompanion.insert(
          jid: message.chatJid,
          title: chatTitle,
          type: chatType,
          unreadCount: Value(unreadIncrement),
          lastMessage: Value.absentIfNull(lastMessagePreview),
          lastChangeTimestamp: resolvedLastChangeTimestamp,
          encryptionProtocol: Value(message.encryptionProtocol),
          favorited: Value(isAxiImServerAnnouncement),
          contactJid: Value(
            chatType == ChatType.groupChat ? null : message.chatJid,
          ),
        ),
        onConflict: DoUpdate.withExcluded(
          (old, excluded) => ChatsCompanion.custom(
            type: excluded.type,
            unreadCount: (old.unreadCount + Constant(unreadIncrement)).iif(
              Constant(usesEmailUnreadCounter),
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
        fileMetadataID: normalizedMetadataId,
        trust: trust,
        trusted: trusted,
      );
      await messagesAccessor.insertOne(messageToSave);
      if (shouldNormalizeSelfChatTitle) {
        await (update(chats)..where((tbl) => tbl.jid.equals(message.chatJid)))
            .write(ChatsCompanion(title: Value(chatTitle)));
      }
      if (isAxiImServerAnnouncement && currentChat?.favorited == false) {
        await (update(chats)..where((tbl) => tbl.jid.equals(message.chatJid)))
            .write(const ChatsCompanion(favorited: Value(true)));
      }
      final persisted = await messagesAccessor.selectOne(message.stanzaID);
      if (persisted == null) {
        if (messageToSave.deltaMsgId != null) {
          final locatorOwner = await getMessageByDeltaId(
            messageToSave.deltaMsgId!,
            deltaAccountId: messageToSave.deltaAccountId,
          );
          if (locatorOwner != null) {
            _log.fine(
              'Message insert ignored because the Delta locator is claimed.',
            );
            return result(MessageSaveChange.ignored);
          }
        }
        _log.warning('Message insert ignored; retrying with upsert');
        await into(messages).insertOnConflictUpdate(messageToSave);
        if (shouldUpdateChatSummary) {
          await _updateChatSummaryIfNewer(
            jid: message.chatJid,
            timestamp: messageTimestamp,
            lastMessage: lastMessagePreview,
          );
          chatSummaryChanged = true;
        }
        return result(MessageSaveChange.upserted);
      }

      if (persisted.retracted) {
        return result(MessageSaveChange.unchanged);
      }

      final persistedMessageId = persisted.id ?? resolvedMessageId;
      final incomingMetadataId = messageToSave.fileMetadataID;
      final hasIncomingMetadataId = incomingMetadataId != null;
      if (incomingMetadataId != null) {
        await addMessageAttachment(
          messageId: persistedMessageId,
          fileMetadataId: incomingMetadataId,
        );
      }
      if (shouldUpdateChatSummary) {
        await _updateChatSummaryIfNewer(
          jid: message.chatJid,
          timestamp: messageTimestamp,
          lastMessage: lastMessagePreview,
        );
        chatSummaryChanged = true;
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
      final incomingSenderRealJid = messageToSave.effectiveSenderRealJid;
      final persistedSenderRealJid = persisted.effectiveSenderRealJid;
      final hasIncomingSenderRealJid =
          incomingSenderRealJid?.isNotEmpty == true;
      final hasPersistedSenderRealJid =
          persistedSenderRealJid?.isNotEmpty == true;
      final incomingOccupantID = messageToSave.occupantID?.trim();
      final hasIncomingOccupantID = incomingOccupantID?.isNotEmpty == true;
      final persistedOccupantID = persisted.occupantID?.trim();
      final hasPersistedOccupantID = persistedOccupantID?.isNotEmpty == true;

      final shouldMergeBody = hasIncomingBody && !hasPersistedBody;
      final shouldMergeHtml = hasIncomingHtml && !hasPersistedHtml;
      final shouldMergeMetadataId =
          hasIncomingMetadataId && !hasPersistedMetadataId;
      final shouldMergeMucStanzaId =
          hasIncomingMucStanzaId && !hasPersistedMucStanzaId;
      final shouldMergeSenderRealJid =
          hasIncomingSenderRealJid && !hasPersistedSenderRealJid;
      final shouldMergeOccupantID =
          hasIncomingOccupantID && !hasPersistedOccupantID;
      if (!shouldMergeBody &&
          !shouldMergeHtml &&
          !shouldMergeMetadataId &&
          !shouldMergeMucStanzaId &&
          !shouldMergeSenderRealJid &&
          !shouldMergeOccupantID) {
        return result(
          existingStanzaMessage == null
              ? MessageSaveChange.inserted
              : MessageSaveChange.unchanged,
        );
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
          senderRealJid: shouldMergeSenderRealJid
              ? Value(incomingSenderRealJid)
              : const Value.absent(),
          occupantID: shouldMergeOccupantID
              ? Value(incomingOccupantID)
              : const Value.absent(),
        ),
      );
      return result(
        existingStanzaMessage == null
            ? MessageSaveChange.inserted
            : MessageSaveChange.merged,
      );
    });
  }

  bool _messageCountsTowardUnread({required Message message}) {
    return message.hasUnreadContent;
  }

  Future<int> _unreadIncrementForIncomingMessage({
    required Message message,
    required bool shouldUpdateChatSummary,
    required String? selfJid,
    required bool isSelfMessage,
  }) async {
    if (!shouldUpdateChatSummary ||
        !_messageCountsTowardUnread(message: message) ||
        message.displayed ||
        isSelfMessage) {
      return 0;
    }
    final originId = message.originID?.trim();
    if (message.emailRfcGroupKey == null ||
        originId == null ||
        originId.isEmpty) {
      return 1;
    }
    final siblings = await getEmailMessagesByRfcGroup(
      chatJid: message.chatJid,
      originID: originId,
      deltaAccountId: message.deltaAccountId,
    );
    for (final sibling in siblings) {
      if (sibling.stanzaID == message.stanzaID) {
        continue;
      }
      if (!message.hasSameEmailRfcGroup(sibling)) {
        continue;
      }
      if (sibling.displayed ||
          !_messageCountsTowardUnread(message: sibling) ||
          sibling.isFromAccount(selfJid)) {
        continue;
      }
      return 0;
    }
    return 1;
  }

  bool _messageExcludedFromChatSummary(Message message) {
    return message.pseudoMessageType?.isSystemStatus == true ||
        message.pseudoMessageType?.isHiddenInviteLifecycle == true;
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
    if (pseudoMessageType?.isSystemStatus == true ||
        pseudoMessageType?.isHiddenInviteLifecycle == true) {
      return null;
    }
    if (pseudoMessageType == PseudoMessageType.mucInvite ||
        pseudoMessageType == PseudoMessageType.mucInviteRevocation ||
        pseudoMessageType == PseudoMessageType.mucInviteAccepted) {
      return switch (pseudoMessageType) {
        PseudoMessageType.mucInvite => 'You have been invited to a group chat',
        PseudoMessageType.mucInviteRevocation => 'Invite revoked',
        PseudoMessageType.mucInviteAccepted => 'Invite accepted',
        _ => null,
      };
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
    if (pseudoMessageType == PseudoMessageType.calendarTaskIcs) {
      final calendarTaskPreview = _calendarTaskPreview(pseudoMessageData);
      if (calendarTaskPreview != null) {
        return calendarTaskPreview;
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

  String? _calendarTaskPreview(Map<String, dynamic>? pseudoMessageData) {
    final message = CalendarTaskIcsMessage.tryParse(
      pseudoMessageData == null
          ? null
          : Map<String, dynamic>.from(pseudoMessageData),
    );
    final title = message?.task.title.trim();
    if (title == null || title.isEmpty) {
      return null;
    }
    return title;
  }

  Future<void> _updateChatSummaryIfNewer({
    required String jid,
    required DateTime timestamp,
    required String? lastMessage,
  }) async {
    final resolvedLastMessage = lastMessage?.trim().isEmpty == true
        ? null
        : lastMessage;
    await customUpdate(
      '''
UPDATE chats
SET last_change_timestamp = ?,
    last_message = ?
WHERE jid = ?
  AND (last_change_timestamp IS NULL OR last_change_timestamp <= ?)
''',
      variables: [
        Variable<DateTime>(timestamp),
        Variable<String>(resolvedLastMessage),
        Variable<String>(jid),
        Variable<DateTime>(timestamp),
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
      final normalizedMetadata = metadata == null
          ? null
          : _normalizedFileMetadataData(metadata);
      if (normalizedMetadata != null) {
        await saveFileMetadata(normalizedMetadata);
      }
      final existing = await messagesAccessor.selectOne(stanzaID);
      if (normalizedMetadata != null && existing?.id != null) {
        await addMessageAttachment(
          messageId: existing!.id!,
          fileMetadataId: normalizedMetadata.id,
        );
      }
      await (update(
        messages,
      )..where((tbl) => tbl.stanzaID.equals(stanzaID))).write(
        MessagesCompanion(
          fileMetadataID: normalizedMetadata != null
              ? Value(normalizedMetadata.id)
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
  Future<void> markMessageManualSendAgain({
    required String stanzaID,
    required String sendAgainStanzaID,
  }) async {
    final normalizedStanzaId = stanzaID.trim();
    final normalizedSendAgainStanzaId = sendAgainStanzaID.trim();
    if (normalizedStanzaId.isEmpty || normalizedSendAgainStanzaId.isEmpty) {
      return;
    }
    await (update(messages)..where(
          (tbl) =>
              tbl.stanzaID.equals(normalizedStanzaId) &
              tbl.manualSendAgainStanzaID.isNull(),
        ))
        .write(
          MessagesCompanion(
            manualSendAgainStanzaID: Value(normalizedSendAgainStanzaId),
          ),
        );
  }

  @override
  Future<int> markMessagesStatusThrough({
    required String messageId,
    required String chatJid,
    required String senderJid,
    bool acked = false,
    bool received = false,
    bool displayed = false,
    bool includeEmailBacked = true,
  }) async {
    final normalizedMessageId = messageId.trim();
    final normalizedChatJid = chatJid.trim();
    final normalizedSenderJid = senderJid.trim();
    final ackedFlag = acked ? 1 : 0;
    final receivedFlag = received ? 1 : 0;
    final displayedFlag = displayed ? 1 : 0;
    if (normalizedMessageId.isEmpty ||
        normalizedChatJid.isEmpty ||
        normalizedSenderJid.isEmpty ||
        !acked && !received && !displayed) {
      return 0;
    }

    final updatedRows = await customUpdate(
      '''
UPDATE messages
SET acked = CASE WHEN ? = 1 THEN 1 ELSE acked END,
    received = CASE WHEN ? = 1 THEN 1 ELSE received END,
    displayed = CASE WHEN ? = 1 THEN 1 ELSE displayed END
WHERE chat_jid = ?
  AND LOWER(sender_jid) = LOWER(?)
  AND (
    ? = 1
    OR (delta_chat_id IS NULL AND delta_msg_id IS NULL)
  )
  AND (
    (? = 1 AND acked = 0)
    OR (? = 1 AND received = 0)
    OR (? = 1 AND displayed = 0)
  )
  AND EXISTS (
    SELECT 1
    FROM messages target
    WHERE target.chat_jid = ?
      AND (
        target.stanza_i_d = ?
        OR target.origin_i_d = ?
        OR target.muc_stanza_id = ?
      )
      AND (
        ? = 1
        OR (target.delta_chat_id IS NULL AND target.delta_msg_id IS NULL)
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
        Variable<int>(ackedFlag),
        Variable<int>(receivedFlag),
        Variable<int>(displayedFlag),
        Variable<String>(normalizedChatJid),
        Variable<String>(normalizedSenderJid),
        Variable<int>(includeEmailBacked ? 1 : 0),
        Variable<int>(ackedFlag),
        Variable<int>(receivedFlag),
        Variable<int>(displayedFlag),
        Variable<String>(normalizedChatJid),
        Variable<String>(normalizedMessageId),
        Variable<String>(normalizedMessageId),
        Variable<String>(normalizedMessageId),
        Variable<int>(includeEmailBacked ? 1 : 0),
      ],
      updates: {messages},
    );
    if (updatedRows > 0) {
      _log.info(
        'Marking messages through $normalizedMessageId '
        '(acked=$acked received=$received displayed=$displayed)',
      );
    }
    return updatedRows;
  }

  @override
  Future<void> markOutgoingMessagesDisplayedThrough({
    required String messageId,
    required String chatJid,
    required String senderJid,
  }) async {
    await markMessagesStatusThrough(
      messageId: messageId,
      chatJid: chatJid,
      senderJid: senderJid,
      displayed: true,
    );
  }

  @override
  Future<void> deleteMessage(
    String stanzaID, {
    String? selfJid,
    String? emailSelfJid,
  }) async {
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
      final referenceIds = existing.referenceIds;
      if (referenceIds.isNotEmpty) {
        await (delete(messagePins)
              ..where((tbl) => tbl.chatJid.equals(existing.chatJid))
              ..where((tbl) => tbl.messageReferenceId.isIn(referenceIds)))
            .go();
        await (delete(pinnedMessages)
              ..where((tbl) => tbl.chatJid.equals(existing.chatJid))
              ..where((tbl) => tbl.messageStanzaId.isIn(referenceIds)))
            .go();
      }
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
      await chatsAccessor.updateOne(
        chat.copyWith(
          lastMessage: lastMessagePreview,
          lastChangeTimestamp:
              lastMessage?.timestamp ?? chat.lastChangeTimestamp,
          unreadCount: lastMessage == null
              ? 0
              : await countUnreadMessagesForChat(
                  chat.jid,
                  selfJid: selfJid,
                  emailSelfJid: emailSelfJid,
                ),
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
    String? selfJid,
    String? emailSelfJid,
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
    final affectedChatRows = await customSelect(
      '''
SELECT DISTINCT chat_jid
FROM messages
WHERE delta_account_id = ?
  AND sender_jid IN ($placeholderClause)
''',
      variables: [
        Variable<int>(deltaAccountId),
        ...normalizedPlaceholders.map(Variable<String>.new),
      ],
      readsFrom: {messages},
    ).get();
    final affectedChats = affectedChatRows
        .map((row) => row.read<String>('chat_jid'))
        .where((jid) => jid.trim().isNotEmpty)
        .toSet();
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
    final repairEmailSelfJid = emailSelfJid ?? normalizedAddress;
    for (final chatJid in affectedChats) {
      await repairUnreadCountForChat(
        chatJid,
        selfJid: selfJid,
        emailSelfJid: repairEmailSelfJid,
      );
    }
  }

  @override
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
        await delete(messagePins).go();
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
  Future<void> removeChatMessages(String jid) async {
    const int deleteBatchSize = 900; // stays under SQLite's 999-variable limit
    Iterable<List<T>> chunked<T>(List<T> items) sync* {
      for (var index = 0; index < items.length; index += deleteBatchSize) {
        final end = index + deleteBatchSize;
        yield items.sublist(index, end > items.length ? items.length : end);
      }
    }

    final pruned = await customSelect(
      '''
      SELECT id AS message_id, stanza_i_d AS stanza_id, origin_i_d,
             muc_stanza_id, delta_msg_id, delta_account_id
      FROM messages
      WHERE chat_jid = ?
      ''',
      variables: [Variable<String>(jid)],
      readsFrom: {messages},
    ).get();

    if (pruned.isEmpty) {
      await _refreshChatSummaryAfterMessageRemoval(jid: jid);
      return;
    }

    final stanzaIds = <String>[];
    final referenceIds = <String>{};
    final Map<int, List<int>> deltaMsgIdsByAccount = {};
    final messageIds = <String>[];
    for (final row in pruned) {
      final messageId = row.read<String>('message_id');
      messageIds.add(messageId);
      final stanzaId = row.read<String>('stanza_id');
      stanzaIds.add(stanzaId);
      referenceIds.add(stanzaId);
      final originId = row.read<String?>('origin_i_d')?.trim();
      if (originId != null && originId.isNotEmpty) {
        referenceIds.add(originId);
      }
      final mucStanzaId = row.read<String?>('muc_stanza_id')?.trim();
      if (mucStanzaId != null && mucStanzaId.isNotEmpty) {
        referenceIds.add(mucStanzaId);
      }
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
        for (final batch in chunked(referenceIds.toList(growable: false))) {
          await (delete(messagePins)
                ..where((tbl) => tbl.messageReferenceId.isIn(batch))
                ..where((tbl) => tbl.chatJid.equals(jid)))
              .go();
        }
        for (final batch in chunked(referenceIds.toList(growable: false))) {
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
    await _refreshChatSummaryAfterMessageRemoval(jid: jid);
  }

  Future<void> _refreshChatSummaryAfterMessageRemoval({
    required String jid,
    String? selfJid,
    String? emailSelfJid,
  }) async {
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
        : await countUnreadMessagesForChat(
            jid,
            selfJid: selfJid,
            emailSelfJid: emailSelfJid,
          );
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
    await update(messages).replace(
      message.copyWith(
        fileMetadataID: _normalizedFileMetadataIdOrNull(message.fileMetadataID),
      ),
    );
  }

  @override
  @override
  Future<void> ensureEmailEncryptionStatusMarkerForChat(String chatJid) async {
    final normalizedChatJid = chatJid.trim();
    if (normalizedChatJid.isEmpty) {
      return;
    }
    await transaction(() async {
      final firstOpenPgpEmail = await _firstOpenPgpEmailMessageForChat(
        normalizedChatJid,
      );
      if (firstOpenPgpEmail == null) {
        return;
      }
      final markerStanzaId = emailEncryptionStatusMarkerStanzaId(
        normalizedChatJid,
      );
      final anchorTimestamp =
          firstOpenPgpEmail.timestamp ?? DateTime.timestamp();
      final markerTimestamp = anchorTimestamp.microsecondsSinceEpoch <= 0
          ? anchorTimestamp
          : anchorTimestamp.subtract(const Duration(microseconds: 1));
      final markerData = emailEncryptionStatusMarkerData(
        anchorStanzaId: firstOpenPgpEmail.stanzaID,
        anchorTimestamp: anchorTimestamp,
      );
      final existing = await messagesAccessor.selectOne(markerStanzaId);
      if (existing == null) {
        await into(messages).insert(
          Message(
            stanzaID: markerStanzaId,
            senderJid: normalizedChatJid,
            chatJid: normalizedChatJid,
            timestamp: markerTimestamp,
            acked: true,
            received: true,
            displayed: true,
            pseudoMessageType: PseudoMessageType.emailEncryptionStatus,
            pseudoMessageData: markerData,
          ),
        );
        return;
      }

      final existingAnchorTimestampMicros =
          existing.emailEncryptionStatusAnchorTimestampMicros;
      final anchorTimestampMicros = anchorTimestamp.microsecondsSinceEpoch;
      if (existingAnchorTimestampMicros != null &&
          existingAnchorTimestampMicros <= anchorTimestampMicros) {
        return;
      }
      await (update(
        messages,
      )..where((tbl) => tbl.stanzaID.equals(markerStanzaId))).write(
        MessagesCompanion(
          senderJid: Value(normalizedChatJid),
          chatJid: Value(normalizedChatJid),
          timestamp: Value(markerTimestamp),
          acked: const Value(true),
          received: const Value(true),
          displayed: const Value(true),
          pseudoMessageType: const Value(
            PseudoMessageType.emailEncryptionStatus,
          ),
          pseudoMessageData: Value(markerData),
        ),
      );
    });
  }

  Future<Message?> _firstOpenPgpEmailMessageForChat(String chatJid) async {
    final row = await customSelect(
      '''
      SELECT m.*
      FROM messages m
      WHERE m.chat_jid = ?
        AND m.pseudo_message_type IS NULL
        AND m.retracted = 0
        AND m.encryption_protocol = ?
        AND (m.delta_chat_id IS NOT NULL OR m.delta_msg_id IS NOT NULL)
        AND ${_visibleMessageSqlPredicate('m')}
      ORDER BY m.timestamp ASC, m.rowid ASC
      LIMIT 1
      ''',
      variables: [
        Variable<String>(chatJid),
        Variable<int>(EncryptionProtocol.openPgp.index),
      ],
      readsFrom: {messages},
    ).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return messages.map(row.data);
  }

  @override
  Future<int> countUnreadMessagesForChat(
    String jid, {
    String? selfJid,
    String? emailSelfJid,
  }) async {
    final normalizedJid = jid.trim();
    if (normalizedJid.isEmpty) {
      return 0;
    }
    final normalizedSelfJid = selfJid?.trim();
    final normalizedEmailSelfJid = emailSelfJid?.trim();
    final candidates =
        await (select(messages)..where(
              (tbl) =>
                  tbl.chatJid.equals(normalizedJid) &
                  tbl.displayed.equals(false),
            ))
            .get();
    var unreadCount = 0;
    final unreadEmailGroups = <String>{};
    for (final message in candidates) {
      if (!message.hasUnreadContent) {
        continue;
      }
      final messageSelfJid = message.isEmailBacked
          ? normalizedEmailSelfJid ?? normalizedSelfJid
          : normalizedSelfJid;
      if (message.isFromAccount(messageSelfJid)) {
        continue;
      }
      final emailGroupKey = message.emailRfcGroupKey;
      if (emailGroupKey != null) {
        unreadEmailGroups.add(emailGroupKey);
        continue;
      }
      unreadCount += 1;
    }
    return unreadCount + unreadEmailGroups.length;
  }

  @override
  Future<int> repairUnreadCountForChat(
    String jid, {
    String? selfJid,
    String? emailSelfJid,
  }) async {
    final normalizedJid = jid.trim();
    if (normalizedJid.isEmpty) {
      return 0;
    }
    final stopwatch = Stopwatch()..start();
    final unreadCount = await countUnreadMessagesForChat(
      normalizedJid,
      selfJid: selfJid,
      emailSelfJid: emailSelfJid,
    );
    final chat = await getChat(normalizedJid);
    final previousUnreadCount = chat?.unreadCount;
    final changed = chat != null && previousUnreadCount != unreadCount;
    if (changed) {
      await chatsAccessor.updateOne(chat.copyWith(unreadCount: unreadCount));
    }
    SafeLogging.profileTrace(
      'chat.unreadRepair',
      'end',
      fields: <String, Object?>{
        'chatHash': SafeLogging.profileFingerprint(normalizedJid),
        'previousUnread': previousUnreadCount,
        'nextUnread': unreadCount,
        'changed': changed,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      },
    );
    return unreadCount;
  }

  @override
  Future<void> hydrateMessageMucIdentity({
    required String stanzaID,
    String? senderRealJid,
    String? occupantID,
    String? mucStanzaId,
  }) async {
    final normalizedStanzaId = stanzaID.trim();
    if (normalizedStanzaId.isEmpty) {
      return;
    }
    final normalizedRealJid = bareAddress(senderRealJid)?.trim();
    if (normalizedRealJid != null && normalizedRealJid.isNotEmpty) {
      await customUpdate(
        '''
UPDATE messages
SET sender_real_jid = ?
WHERE stanza_i_d = ?
  AND (sender_real_jid IS NULL OR trim(sender_real_jid) = '')
''',
        variables: [
          Variable<String>(normalizedRealJid),
          Variable<String>(normalizedStanzaId),
        ],
        updates: {messages},
      );
    }
    final normalizedOccupantID = occupantID?.trim();
    if (normalizedOccupantID != null && normalizedOccupantID.isNotEmpty) {
      await customUpdate(
        '''
UPDATE messages
SET occupant_i_d = ?
WHERE stanza_i_d = ?
  AND (occupant_i_d IS NULL OR trim(occupant_i_d) = '')
''',
        variables: [
          Variable<String>(normalizedOccupantID),
          Variable<String>(normalizedStanzaId),
        ],
        updates: {messages},
      );
    }
    final normalizedMucStanzaId = mucStanzaId?.trim();
    if (normalizedMucStanzaId != null && normalizedMucStanzaId.isNotEmpty) {
      await customUpdate(
        '''
UPDATE messages
SET muc_stanza_id = ?
WHERE stanza_i_d = ?
  AND (muc_stanza_id IS NULL OR trim(muc_stanza_id) = '')
''',
        variables: [
          Variable<String>(normalizedMucStanzaId),
          Variable<String>(normalizedStanzaId),
        ],
        updates: {messages},
      );
    }
  }

  @override
  Future<void> replacePendingOutboundMucIdentity({
    required String stanzaID,
    required String senderJid,
    String? senderRealJid,
    String? occupantID,
  }) async {
    final normalizedStanzaId = stanzaID.trim();
    final normalizedSenderJid = senderJid.trim();
    if (normalizedStanzaId.isEmpty || normalizedSenderJid.isEmpty) {
      return;
    }
    final normalizedRealJid = bareAddress(senderRealJid)?.trim();
    final normalizedOccupantID = occupantID?.trim();
    await (update(messages)..where(
          (tbl) =>
              tbl.stanzaID.equals(normalizedStanzaId) &
              tbl.acked.equals(false) &
              tbl.received.equals(false) &
              tbl.displayed.equals(false),
        ))
        .write(
          MessagesCompanion(
            senderJid: Value(normalizedSenderJid),
            senderRealJid: Value(
              normalizedRealJid == null || normalizedRealJid.isEmpty
                  ? null
                  : normalizedRealJid,
            ),
            occupantID: Value(
              normalizedOccupantID == null || normalizedOccupantID.isEmpty
                  ? null
                  : normalizedOccupantID,
            ),
          ),
        );
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
    await messageCopiesAccessor.insertForDeltaMessage(
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
    required int deltaAccountId,
  }) => messageCopiesAccessor.selectShareIdForDeltaMsg(
    deltaMsgId,
    deltaAccountId: deltaAccountId,
  );

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
    String? quotingOriginId,
    String? quotingMucStanzaId,
    List<String> attachmentMetadataIds = const [],
    List<FileMetadataData> attachmentMetadata = const [],
    CalendarTaskIcsMessage? calendarTaskIcsMessage,
    List<DraftForwardedBlock> forwardedBlocks = const [],
    bool autosaveEnabled = false,
  }) async {
    return transaction(() async {
      for (final metadata in attachmentMetadata) {
        await saveFileMetadata(metadata);
      }
      final normalizedAttachmentMetadataIds = _normalizedFileMetadataIds(
        attachmentMetadataIds.isEmpty && attachmentMetadata.isNotEmpty
            ? attachmentMetadata.map((metadata) => metadata.id)
            : attachmentMetadataIds,
      );
      final draftId = await draftsAccessor.insertOrUpdateOne(
        DraftsCompanion(
          id: Value.absentIfNull(id),
          jids: Value(jids),
          body: Value(body),
          draftSyncId: Value(draftSyncId),
          draftUpdatedAt: Value(draftUpdatedAt),
          draftSourceId: Value(draftSourceId),
          draftRecipients: Value(draftRecipients),
          subject: Value(subject),
          quotingStanzaId: Value(quotingStanzaId),
          quotingOriginId: Value(quotingOriginId),
          quotingMucStanzaId: Value(quotingMucStanzaId),
          attachmentMetadataIds: Value(normalizedAttachmentMetadataIds),
          calendarTaskIcsMessage: Value(calendarTaskIcsMessage),
          forwardedBlocks: Value(forwardedBlocks),
          autosaveEnabled: id == null
              ? Value(autosaveEnabled)
              : const Value.absent(),
        ),
      );
      await _replaceDraftAttachmentRefs(
        draftId: draftId,
        attachmentMetadataIds: normalizedAttachmentMetadataIds,
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
  Future<void> updateDraftAutosaveEnabled({
    required int id,
    required bool enabled,
  }) {
    return draftsAccessor.updateOne(
      DraftsCompanion(id: Value(id), autosaveEnabled: Value(enabled)),
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
    String? quotingOriginId,
    String? quotingMucStanzaId,
    List<String> attachmentMetadataIds = const [],
    List<FileMetadataData> attachmentMetadata = const [],
    CalendarTaskIcsMessage? calendarTaskIcsMessage,
    List<DraftForwardedBlock> forwardedBlocks = const [],
  }) async {
    final normalized = draftSyncId.trim();
    if (normalized.isEmpty) return 0;
    final existing = await getDraftBySyncId(normalized);
    if (existing == null) {
      return transaction(() async {
        for (final metadata in attachmentMetadata) {
          await saveFileMetadata(metadata);
        }
        final normalizedAttachmentMetadataIds = _normalizedFileMetadataIds(
          attachmentMetadataIds.isEmpty && attachmentMetadata.isNotEmpty
              ? attachmentMetadata.map((metadata) => metadata.id)
              : attachmentMetadataIds,
        );
        final draftId = await draftsAccessor.insertOrUpdateOne(
          DraftsCompanion(
            jids: Value(jids),
            draftSyncId: Value(normalized),
            draftUpdatedAt: Value(draftUpdatedAt),
            draftSourceId: Value(draftSourceId),
            draftRecipients: Value(draftRecipients),
            body: Value(body),
            subject: Value(subject),
            quotingStanzaId: Value(quotingStanzaId),
            quotingOriginId: Value(quotingOriginId),
            quotingMucStanzaId: Value(quotingMucStanzaId),
            attachmentMetadataIds: Value(normalizedAttachmentMetadataIds),
            calendarTaskIcsMessage: Value(calendarTaskIcsMessage),
            forwardedBlocks: Value(forwardedBlocks),
            autosaveEnabled: const Value(false),
          ),
        );
        await _replaceDraftAttachmentRefs(
          draftId: draftId,
          attachmentMetadataIds: normalizedAttachmentMetadataIds,
        );
        return draftId;
      });
    }
    await transaction(() async {
      for (final metadata in attachmentMetadata) {
        await saveFileMetadata(metadata);
      }
      final normalizedAttachmentMetadataIds = _normalizedFileMetadataIds(
        attachmentMetadataIds.isEmpty && attachmentMetadata.isNotEmpty
            ? attachmentMetadata.map((metadata) => metadata.id)
            : attachmentMetadataIds,
      );
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
          quotingStanzaId: Value(quotingStanzaId),
          quotingOriginId: Value(quotingOriginId),
          quotingMucStanzaId: Value(quotingMucStanzaId),
          attachmentMetadataIds: Value(normalizedAttachmentMetadataIds),
          calendarTaskIcsMessage: Value(calendarTaskIcsMessage),
          forwardedBlocks: Value(forwardedBlocks),
        ),
      );
      await _replaceDraftAttachmentRefs(
        draftId: existing.id,
        attachmentMetadataIds: normalizedAttachmentMetadataIds,
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
    final normalizedIds = _normalizedFileMetadataIds(attachmentMetadataIds);
    await _ensureFileMetadataRowsExist(normalizedIds);
    await (delete(
      draftAttachmentRefs,
    )..where((tbl) => tbl.draftId.equals(draftId))).go();
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
    await fileMetadataAccessor.insertOrUpdateOne(
      _normalizedFileMetadataData(metadata),
    );
  }

  @override
  Future<FileMetadataData?> getFileMetadata(String id) {
    final normalizedId = _normalizedFileMetadataIdOrNull(id);
    if (normalizedId == null) return Future.value(null);
    return fileMetadataAccessor.selectOne(normalizedId);
  }

  @override
  Future<List<FileMetadataData>> getFileMetadataForIds(Iterable<String> ids) {
    final normalizedIds = _normalizedFileMetadataIds(ids);
    if (normalizedIds.isEmpty) return Future.value(const <FileMetadataData>[]);
    return fileMetadataAccessor.selectForIds(normalizedIds);
  }

  @override
  Stream<FileMetadataData?> watchFileMetadata(String id) {
    final normalizedId = _normalizedFileMetadataIdOrNull(id);
    if (normalizedId == null) return Stream.value(null);
    return fileMetadataAccessor.watchOne(normalizedId);
  }

  @override
  Future<void> deleteFileMetadata(String id) async {
    final normalizedId = _normalizedFileMetadataIdOrNull(id);
    if (normalizedId == null) return;
    await _deleteFileMetadataIfOrphaned(normalizedId);
  }

  @override
  Future<String?> getLocalPromptState({
    required String accountJid,
    required String promptId,
  }) async {
    final normalizedAccountJid = accountJid.trim();
    final normalizedPromptId = promptId.trim();
    if (normalizedAccountJid.isEmpty || normalizedPromptId.isEmpty) {
      return null;
    }
    final row = await customSelect(
      '''
SELECT status
FROM local_prompt_states
WHERE account_jid = ?
  AND prompt_id = ?
LIMIT 1
''',
      variables: [
        Variable<String>(normalizedAccountJid),
        Variable<String>(normalizedPromptId),
      ],
    ).getSingleOrNull();
    return row?.read<String>('status').trim();
  }

  @override
  Future<void> saveLocalPromptState({
    required String accountJid,
    required String promptId,
    required String status,
  }) async {
    final normalizedAccountJid = accountJid.trim();
    final normalizedPromptId = promptId.trim();
    final normalizedStatus = status.trim();
    if (normalizedAccountJid.isEmpty ||
        normalizedPromptId.isEmpty ||
        normalizedStatus.isEmpty) {
      return;
    }
    await customStatement(
      '''
INSERT INTO local_prompt_states(account_jid, prompt_id, status, updated_at)
VALUES (?, ?, ?, ?)
ON CONFLICT(account_jid, prompt_id) DO UPDATE SET
  status = excluded.status,
  updated_at = excluded.updated_at
''',
      [
        normalizedAccountJid,
        normalizedPromptId,
        normalizedStatus,
        DateTime.timestamp().millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<EmailHistoryImportJournal?> getEmailHistoryImportJournal({
    required String accountJid,
    required int deltaAccountId,
  }) async {
    final normalizedAccountJid = accountJid.trim();
    if (normalizedAccountJid.isEmpty) {
      return null;
    }
    final row = await customSelect(
      '''
SELECT account_jid, delta_account_id, status, watermark_delta_msg_id,
       target_delta_msg_id, last_projected_delta_msg_id, fetch_completed,
       updated_at
FROM email_history_import_journal
WHERE account_jid = ?
  AND delta_account_id = ?
LIMIT 1
''',
      variables: [
        Variable<String>(normalizedAccountJid),
        Variable<int>(deltaAccountId),
      ],
    ).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return EmailHistoryImportJournal(
      accountJid: row.read<String>('account_jid'),
      deltaAccountId: row.read<int>('delta_account_id'),
      status: row.read<String>('status').trim(),
      watermarkDeltaMsgId: row.read<int>('watermark_delta_msg_id'),
      targetDeltaMsgId: row.read<int>('target_delta_msg_id'),
      lastProjectedDeltaMsgId: row.read<int>('last_projected_delta_msg_id'),
      fetchCompleted: row.read<int>('fetch_completed') != 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('updated_at'),
      ),
    );
  }

  @override
  Future<void> saveEmailHistoryImportJournal({
    required String accountJid,
    required int deltaAccountId,
    required String status,
    required int watermarkDeltaMsgId,
    required int targetDeltaMsgId,
    required int lastProjectedDeltaMsgId,
    required bool fetchCompleted,
  }) async {
    final normalizedAccountJid = accountJid.trim();
    final normalizedStatus = status.trim();
    if (normalizedAccountJid.isEmpty || normalizedStatus.isEmpty) {
      return;
    }
    await customStatement(
      '''
INSERT INTO email_history_import_journal(
  account_jid,
  delta_account_id,
  status,
  watermark_delta_msg_id,
  target_delta_msg_id,
  last_projected_delta_msg_id,
  fetch_completed,
  updated_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(account_jid, delta_account_id) DO UPDATE SET
  status = excluded.status,
  watermark_delta_msg_id = excluded.watermark_delta_msg_id,
  target_delta_msg_id = excluded.target_delta_msg_id,
  last_projected_delta_msg_id = excluded.last_projected_delta_msg_id,
  fetch_completed = excluded.fetch_completed,
  updated_at = excluded.updated_at
''',
      [
        normalizedAccountJid,
        deltaAccountId,
        normalizedStatus,
        watermarkDeltaMsgId,
        targetDeltaMsgId,
        lastProjectedDeltaMsgId,
        fetchCompleted ? 1 : 0,
        DateTime.timestamp().millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<void> deleteEmailHistoryImportJournal({
    required String accountJid,
    required int deltaAccountId,
  }) async {
    final normalizedAccountJid = accountJid.trim();
    if (normalizedAccountJid.isEmpty) {
      return;
    }
    await customStatement(
      '''
DELETE FROM email_history_import_journal
WHERE account_jid = ?
  AND delta_account_id = ?
''',
      [normalizedAccountJid, deltaAccountId],
    );
  }

  String? _normalizedFileMetadataIdOrNull(String? id) {
    final normalized = id?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String _requiredFileMetadataId(String id) {
    final normalized = _normalizedFileMetadataIdOrNull(id);
    if (normalized == null) {
      throw const FormatException('File metadata id cannot be empty.');
    }
    return normalized;
  }

  FileMetadataData _normalizedFileMetadataData(FileMetadataData metadata) {
    final normalizedId = _requiredFileMetadataId(metadata.id);
    if (normalizedId == metadata.id) {
      return metadata;
    }
    return metadata.copyWith(id: normalizedId);
  }

  List<String> _normalizedFileMetadataIds(Iterable<String> ids) {
    final normalizedIds = <String>[];
    final seen = <String>{};
    for (final id in ids) {
      final normalized = _normalizedFileMetadataIdOrNull(id);
      if (normalized == null || !seen.add(normalized)) {
        continue;
      }
      normalizedIds.add(normalized);
    }
    return normalizedIds;
  }

  Future<void> _ensureFileMetadataRowsExist(List<String> ids) async {
    if (ids.isEmpty) return;
    final rows = await fileMetadataAccessor.selectForIds(ids);
    if (rows.length == ids.length) return;
    throw const FormatException('Missing file metadata for attachment ref.');
  }

  Future<void> _deleteFileMetadataIfOrphaned(String id) async {
    final trimmedId = _normalizedFileMetadataIdOrNull(id);
    if (trimmedId == null) return;
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
    return appOwnedAttachmentRootDirectory();
  }

  Future<Directory> _attachmentDirectoryForPrefix(String prefix) async {
    final root = await _attachmentRootDirectory();
    final normalizedPrefix = normalizeAttachmentStoragePrefix(prefix);
    return Directory(p.join(root.path, normalizedPrefix));
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
    String? groupQuotedStanzaId,
  }) async {
    final normalizedMetadataId = _requiredFileMetadataId(fileMetadataId);
    await _ensureFileMetadataRowsExist(<String>[normalizedMetadataId]);
    final existing =
        await (select(messageAttachments)..where(
              (tbl) =>
                  tbl.messageId.equals(messageId) &
                  tbl.fileMetadataId.equals(normalizedMetadataId),
            ))
            .getSingleOrNull();
    if (existing != null) {
      final shouldUpdateGroup =
          transportGroupId != null &&
          existing.transportGroupId != transportGroupId;
      final shouldUpdateOrder =
          sortOrder != null && existing.sortOrder != sortOrder;
      final shouldUpdateGroupQuote =
          groupQuotedStanzaId != null &&
          existing.groupQuotedReference != groupQuotedStanzaId;
      if (shouldUpdateGroup || shouldUpdateOrder || shouldUpdateGroupQuote) {
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
            groupQuotedReference: shouldUpdateGroupQuote
                ? Value(groupQuotedStanzaId)
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
        fileMetadataId: normalizedMetadataId,
        sortOrder: Value(nextOrder),
        transportGroupId: Value.absentIfNull(transportGroupId),
        groupQuotedReference: Value.absentIfNull(groupQuotedStanzaId),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  @override
  Future<void> replaceMessageAttachments({
    required String messageId,
    required List<String> fileMetadataIds,
    String? transportGroupId,
    String? groupQuotedStanzaId,
  }) async {
    final normalizedIds = _normalizedFileMetadataIds(fileMetadataIds);
    final limitedIds = normalizedIds.length > _messageAttachmentMaxCount
        ? normalizedIds.take(_messageAttachmentMaxCount).toList(growable: false)
        : normalizedIds;
    if (limitedIds.length < normalizedIds.length) {
      _log.warning('Dropping message attachments beyond max count.');
    }
    await _ensureFileMetadataRowsExist(limitedIds);
    await transaction(() async {
      await messageAttachmentsAccessor.deleteForMessage(messageId);
      if (limitedIds.isEmpty) return;
      const attachmentSortOrderStart = 0;
      const attachmentSortOrderStep = 1;
      var order = attachmentSortOrderStart;
      for (final metadataId in limitedIds) {
        await into(messageAttachments).insert(
          MessageAttachmentsCompanion.insert(
            messageId: messageId,
            fileMetadataId: metadataId,
            sortOrder: Value(order),
            transportGroupId: Value.absentIfNull(transportGroupId),
            groupQuotedReference: Value.absentIfNull(groupQuotedStanzaId),
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
  Stream<List<FolderMessageItem>> watchFolderMessageItems(
    String collectionId, {
    String? chatJid,
  }) {
    late final StreamController<List<FolderMessageItem>> controller;
    final subscriptions = <StreamSubscription<Object?>>[];
    List<FolderMessageItem>? lastItems;
    var emitting = false;
    var pending = false;

    Future<void> emitItems() async {
      if (emitting) {
        pending = true;
        return;
      }
      emitting = true;
      try {
        do {
          pending = false;
          final items = await getFolderMessageItems(
            collectionId,
            chatJid: chatJid,
          );
          if (!listEquals(lastItems, items)) {
            lastItems = items;
            if (!controller.isClosed) {
              controller.add(items);
            }
          }
        } while (pending);
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        emitting = false;
      }
    }

    controller = StreamController<List<FolderMessageItem>>(
      onListen: () {
        subscriptions
          ..add(
            select(
              messageCollectionMemberships,
            ).watch().listen((_) => emitItems()),
          )
          ..add(select(messages).watch().listen((_) => emitItems()))
          ..add(select(chats).watch().listen((_) => emitItems()))
          ..add(
            select(privateContactRecords).watch().listen((_) => emitItems()),
          )
          ..add(select(messageCollections).watch().listen((_) => emitItems()));
        unawaited(emitItems());
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions.clear();
      },
    );
    return controller.stream;
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
  Future<List<FolderMessageItem>> getFolderMessageItems(
    String collectionId, {
    String? chatJid,
    bool includeInactive = false,
  }) async {
    final explicitItems = _folderMessageItemsFromRows(
      await _folderMessageItemsQuery(
        collectionId,
        chatJid: chatJid,
        includeInactive: includeInactive,
      ).get(),
    );
    if (includeInactive) {
      return explicitItems;
    }
    return _mergeFolderMessageItems(
      explicitItems,
      await _contactRuleDerivedFolderMessageItems(
        collectionId,
        chatJid: chatJid,
      ),
    );
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
  Stream<List<MessageCollectionMembershipEntry>>
  watchAllMessageCollectionMemberships({
    bool includeInactive = false,
    String? chatJid,
  }) {
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
    final normalizedChatJid = chatJid?.trim();
    if (normalizedChatJid != null && normalizedChatJid.isNotEmpty) {
      query.where((tbl) => tbl.chatJid.equals(normalizedChatJid));
    }
    return query.watch();
  }

  JoinedSelectStatement<HasResultSet, dynamic> _folderMessageItemsQuery(
    String collectionId, {
    String? chatJid,
    bool includeInactive = false,
  }) {
    final memberships = messageCollectionMemberships;
    final query = select(memberships).join([
      leftOuterJoin(
        messages,
        _folderMessageJoinPredicate(memberships, messages),
      ),
      leftOuterJoin(chats, chats.jid.equalsExp(memberships.chatJid)),
    ]);
    query.where(memberships.collectionId.equals(collectionId));
    if (!includeInactive) {
      query.where(memberships.active.equals(true));
    }
    final normalizedChatJid = chatJid?.trim();
    if (normalizedChatJid != null && normalizedChatJid.isNotEmpty) {
      query.where(memberships.chatJid.equals(normalizedChatJid));
    }
    query.orderBy([
      OrderingTerm.desc(memberships.addedAt),
      OrderingTerm.desc(memberships.messageReferenceId),
    ]);
    return query;
  }

  Expression<bool> _folderMessageJoinPredicate(
    $MessageCollectionMembershipsTable memberships,
    $MessagesTable messages,
  ) {
    final normalizedDeltaAccountId = coalesce<int>([
      memberships.deltaAccountId,
      const Constant(DeltaAccountDefaults.legacyId),
    ]);
    return messages.chatJid.equalsExp(memberships.chatJid) &
        ((messages.stanzaID.equalsExp(memberships.messageReferenceId) |
                messages.originID.equalsExp(memberships.messageReferenceId) |
                messages.mucStanzaId.equalsExp(
                  memberships.messageReferenceId,
                )) |
            (memberships.deltaMsgId.isNotNull() &
                messages.deltaMsgId.equalsExp(memberships.deltaMsgId) &
                messages.deltaAccountId.equalsExp(normalizedDeltaAccountId)));
  }

  List<FolderMessageItem> _folderMessageItemsFromRows(List<TypedResult> rows) {
    final itemsByKey = <String, FolderMessageItem>{};
    for (final row in rows) {
      final entry = row.readTable(messageCollectionMemberships);
      final message = row.readTableOrNull(messages);
      final item = FolderMessageItem(
        collectionId: entry.collectionId,
        chatJid: entry.chatJid,
        messageReferenceId: entry.messageReferenceId,
        messageStanzaId: entry.messageStanzaId,
        messageOriginId: entry.messageOriginId,
        messageMucStanzaId: entry.messageMucStanzaId,
        deltaAccountId: entry.deltaAccountId,
        deltaMsgId: entry.deltaMsgId,
        addedAt: entry.addedAt,
        active: entry.active,
        message: message,
        chat: row.readTableOrNull(chats),
      );
      final key = _folderMessageItemKey(item);
      itemsByKey.putIfAbsent(key, () => item);
    }
    return itemsByKey.values.toList(growable: false);
  }

  Future<List<FolderMessageItem>> _contactRuleDerivedFolderMessageItems(
    String collectionId, {
    String? chatJid,
  }) async {
    final normalizedCollectionId = collectionId.trim();
    if (normalizedCollectionId.isEmpty) {
      return const <FolderMessageItem>[];
    }
    final collection = await getMessageCollection(normalizedCollectionId);
    if (collection?.active != true) {
      return const <FolderMessageItem>[];
    }
    final ruleRecords = await _activeContactFolderRuleRecords(
      collectionId: normalizedCollectionId,
    );
    if (ruleRecords.isEmpty) {
      return const <FolderMessageItem>[];
    }
    final recordsByAddressKey = <String, PrivateContactRecord>{
      for (final record in ruleRecords)
        contactDirectoryAddressKey(record.addressKey): record,
    };
    final normalizedChatJid = chatJid?.trim();
    final candidateChats = <String, Chat>{};
    for (final chat in await getChats(start: 0, end: 0)) {
      if (chat.type == ChatType.groupChat) {
        continue;
      }
      if (normalizedChatJid != null &&
          normalizedChatJid.isNotEmpty &&
          chat.jid != normalizedChatJid) {
        continue;
      }
      final matchesRule = _contactAddressKeysForChat(
        chat,
      ).any(recordsByAddressKey.containsKey);
      if (matchesRule) {
        candidateChats[chat.jid] = chat;
      }
    }
    if (candidateChats.isEmpty) {
      return const <FolderMessageItem>[];
    }
    final messageRows =
        await (select(messages)
              ..where(
                (tbl) =>
                    tbl.chatJid.isIn(candidateChats.keys) &
                    tbl.retracted.equals(false),
              )
              ..orderBy([
                (tbl) => OrderingTerm(
                  expression: tbl.timestamp,
                  mode: OrderingMode.desc,
                ),
                (tbl) => OrderingTerm(
                  expression: tbl.stanzaID,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    final items = <FolderMessageItem>[];
    for (final message in messageRows) {
      final reference = message.collectionReference(isGroupChat: false);
      if (reference == null) {
        continue;
      }
      final timestamp = message.timestamp;
      if (timestamp == null) {
        continue;
      }
      final chat = candidateChats[message.chatJid];
      items.add(
        FolderMessageItem(
          collectionId: normalizedCollectionId,
          chatJid: message.chatJid,
          messageReferenceId: reference.value,
          messageStanzaId: message.isEmailBacked
              ? null
              : message.trimmedStanzaId,
          messageOriginId: message.isEmailBacked
              ? reference.value
              : message.trimmedOriginId,
          messageMucStanzaId: message.trimmedMucStanzaId,
          deltaAccountId: message.deltaMsgId == null
              ? null
              : message.deltaAccountId,
          deltaMsgId: message.deltaMsgId,
          addedAt: timestamp.toUtc(),
          active: true,
          message: message,
          chat: chat,
          isContactRuleDerived: true,
        ),
      );
    }
    return items;
  }

  List<FolderMessageItem> _mergeFolderMessageItems(
    List<FolderMessageItem> explicitItems,
    List<FolderMessageItem> derivedItems,
  ) {
    final itemsByKey = <String, FolderMessageItem>{};
    for (final item in explicitItems) {
      itemsByKey[_folderMessageItemKey(item)] = item;
    }
    for (final item in derivedItems) {
      itemsByKey.putIfAbsent(_folderMessageItemKey(item), () => item);
    }
    final items = itemsByKey.values.toList(growable: false)
      ..sort((a, b) {
        final addedAtOrder = b.markedAt.compareTo(a.markedAt);
        if (addedAtOrder != 0) {
          return addedAtOrder;
        }
        return b.messageReferenceId.compareTo(a.messageReferenceId);
      });
    return items;
  }

  String _folderMessageItemKey(FolderMessageItem item) {
    final message = item.message;
    final String reference;
    if (message == null) {
      reference = item.messageReferenceId.trim();
    } else {
      final stanzaId = message.trimmedStanzaId;
      // ignore: prefer_if_null_operators
      reference = stanzaId == null ? item.messageReferenceId.trim() : stanzaId;
    }
    return '${item.collectionId.trim()}\n${item.chatJid.trim()}\n$reference';
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
    await transaction(() async {
      final existing = await getMessageCollectionMembership(
        collectionId: normalizedCollectionId,
        chatJid: normalizedChatJid,
        messageReferenceId: normalizedReferenceId,
      );
      final resolvedDeltaMsgId = deltaMsgId ?? existing?.deltaMsgId;
      final resolvedDeltaAccountId = resolvedDeltaMsgId == null
          ? null
          : (deltaMsgId == null ? existing?.deltaAccountId : deltaAccountId);
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
            existing.deltaAccountId != resolvedDeltaAccountId ||
            existing.deltaMsgId != resolvedDeltaMsgId;
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
          deltaAccountId: resolvedDeltaAccountId,
          deltaMsgId: resolvedDeltaMsgId,
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

  Selectable<QueryRow> _pinnedMessageAggregateRows({
    required String chatJid,
    required String selfPinnerJid,
  }) {
    return customSelect(
      '''
SELECT
  chat_jid,
  message_reference_id,
  max(message_stanza_id) AS message_stanza_id,
  max(message_origin_id) AS message_origin_id,
  max(message_muc_stanza_id) AS message_muc_stanza_id,
  max(pinned_at) AS pinned_at,
  count(*) AS pin_count,
  max(CASE WHEN pinner_jid = ? THEN 1 ELSE 0 END) AS pinned_by_self
FROM message_pins
WHERE chat_jid = ? AND active = 1
GROUP BY chat_jid, message_reference_id
ORDER BY pinned_at DESC, message_reference_id DESC
''',
      variables: [Variable<String>(selfPinnerJid), Variable<String>(chatJid)],
      readsFrom: {messagePins},
    );
  }

  PinnedMessageAggregate? _pinnedMessageAggregateFromRow(QueryRow row) {
    return PinnedMessageAggregate(
      chatJid: row.read<String>('chat_jid'),
      messageReferenceId: row.read<String>('message_reference_id'),
      messageStanzaId: row.read<String?>('message_stanza_id'),
      messageOriginId: row.read<String?>('message_origin_id'),
      messageMucStanzaId: row.read<String?>('message_muc_stanza_id'),
      pinnedAt: row.read<DateTime>('pinned_at').toUtc(),
      pinCount: row.read<int>('pin_count'),
      pinnedBySelf: row.read<int>('pinned_by_self') > 0,
    );
  }

  @override
  Stream<List<PinnedMessageAggregate>> watchPinnedMessageAggregates({
    required String chatJid,
    required String selfPinnerJid,
  }) {
    return _pinnedMessageAggregateRows(
      chatJid: chatJid,
      selfPinnerJid: selfPinnerJid,
    ).watch().map(
      (rows) => rows
          .map(_pinnedMessageAggregateFromRow)
          .nonNulls
          .toList(growable: false),
    );
  }

  @override
  Future<List<PinnedMessageAggregate>> getPinnedMessageAggregates({
    required String chatJid,
    required String selfPinnerJid,
  }) async {
    final rows = await _pinnedMessageAggregateRows(
      chatJid: chatJid,
      selfPinnerJid: selfPinnerJid,
    ).get();
    return rows
        .map(_pinnedMessageAggregateFromRow)
        .nonNulls
        .toList(growable: false);
  }

  @override
  Future<PinEntry?> getMessagePin({
    required String chatJid,
    required String messageReferenceId,
    required String pinnerJid,
  }) {
    final normalizedReference = messageReferenceId.trim();
    final query = select(messagePins)
      ..where((tbl) => tbl.chatJid.equals(chatJid))
      ..where((tbl) => tbl.messageReferenceId.equals(normalizedReference))
      ..where((tbl) => tbl.pinnerJid.equals(pinnerJid));
    return query.getSingleOrNull();
  }

  Future<PinEntry?> _getPinnedMessageClearAllMarker({
    required String chatJid,
    required String messageReferenceId,
  }) {
    return getMessagePin(
      chatJid: chatJid,
      messageReferenceId: messageReferenceId,
      pinnerJid: _pinnedMessageClearAllMarkerPinnerJid,
    );
  }

  @override
  Future<DateTime?> getPinnedMessageClearAllTimestamp({
    required String chatJid,
    required String messageReferenceId,
  }) async {
    final marker = await _getPinnedMessageClearAllMarker(
      chatJid: chatJid,
      messageReferenceId: messageReferenceId,
    );
    return marker?.pinnedAt.toUtc();
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

  Future<void> _refreshPinnedMessageAggregate({
    required String chatJid,
    required String messageReferenceId,
    required DateTime fallbackTimestamp,
    required bool writeTombstone,
  }) async {
    final normalizedReference = messageReferenceId.trim();
    final normalizedFallbackTimestamp = fallbackTimestamp.toUtc();
    final activePins =
        await (select(messagePins)
              ..where((tbl) => tbl.chatJid.equals(chatJid))
              ..where(
                (tbl) => tbl.messageReferenceId.equals(normalizedReference),
              )
              ..where((tbl) => tbl.active.equals(true))
              ..orderBy([
                (tbl) => OrderingTerm(
                  expression: tbl.pinnedAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    if (activePins.isEmpty) {
      final existingAggregate = await getPinnedMessage(
        chatJid: chatJid,
        messageStanzaId: normalizedReference,
      );
      if (!writeTombstone) {
        await deletePinnedMessage(
          chatJid: chatJid,
          messageStanzaId: normalizedReference,
        );
        return;
      }
      if (existingAggregate != null &&
          !existingAggregate.active &&
          existingAggregate.pinnedAt.toUtc().isAfter(
            normalizedFallbackTimestamp,
          )) {
        return;
      }
      await into(pinnedMessages).insertOnConflictUpdate(
        PinnedMessageEntry(
          messageStanzaId: normalizedReference,
          chatJid: chatJid,
          pinnedAt: normalizedFallbackTimestamp,
          active: false,
        ),
      );
      return;
    }
    final activePinnedAt = activePins.first.pinnedAt.toUtc();
    final clearAllMarker = await _getPinnedMessageClearAllMarker(
      chatJid: chatJid,
      messageReferenceId: normalizedReference,
    );
    if (clearAllMarker != null &&
        !clearAllMarker.pinnedAt.toUtc().isBefore(activePinnedAt)) {
      return;
    }
    await into(pinnedMessages).insertOnConflictUpdate(
      PinnedMessageEntry(
        messageStanzaId: normalizedReference,
        chatJid: chatJid,
        pinnedAt: activePinnedAt,
        active: true,
      ),
    );
  }

  @override
  Future<void> applyMessagePinMutation({
    required String chatJid,
    required String messageReferenceId,
    String? messageStanzaId,
    String? messageOriginId,
    String? messageMucStanzaId,
    required String pinnerJid,
    required DateTime pinnedAt,
    required bool active,
    required bool identityVerified,
  }) async {
    final normalizedReference = messageReferenceId.trim();
    await transaction(() async {
      final normalizedPinnedAt = pinnedAt.toUtc();
      final clearAllMarker = await _getPinnedMessageClearAllMarker(
        chatJid: chatJid,
        messageReferenceId: normalizedReference,
      );
      if (clearAllMarker != null &&
          !clearAllMarker.pinnedAt.toUtc().isBefore(normalizedPinnedAt)) {
        return;
      }
      final existing = await getMessagePin(
        chatJid: chatJid,
        messageReferenceId: normalizedReference,
        pinnerJid: pinnerJid,
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
      await into(messagePins).insertOnConflictUpdate(
        PinEntry(
          chatJid: chatJid,
          messageReferenceId: normalizedReference,
          messageStanzaId: messageStanzaId,
          messageOriginId: messageOriginId,
          messageMucStanzaId: messageMucStanzaId,
          pinnerJid: pinnerJid,
          pinnedAt: normalizedPinnedAt,
          active: active,
          identityVerified: identityVerified,
        ),
      );
      await _refreshPinnedMessageAggregate(
        chatJid: chatJid,
        messageReferenceId: normalizedReference,
        fallbackTimestamp: normalizedPinnedAt,
        writeTombstone: false,
      );
    });
  }

  @override
  Future<void> clearMessagePins({
    required String chatJid,
    required String messageReferenceId,
    required DateTime pinnedAt,
  }) async {
    final normalizedReference = messageReferenceId.trim();
    await transaction(() async {
      final normalizedPinnedAt = pinnedAt.toUtc();
      final existingMarker = await _getPinnedMessageClearAllMarker(
        chatJid: chatJid,
        messageReferenceId: normalizedReference,
      );
      if (existingMarker == null ||
          existingMarker.pinnedAt.toUtc().isBefore(normalizedPinnedAt)) {
        await into(messagePins).insertOnConflictUpdate(
          PinEntry(
            chatJid: chatJid,
            messageReferenceId: normalizedReference,
            messageStanzaId: null,
            messageOriginId: null,
            messageMucStanzaId: null,
            pinnerJid: _pinnedMessageClearAllMarkerPinnerJid,
            pinnedAt: normalizedPinnedAt,
            active: false,
            identityVerified: true,
          ),
        );
      }
      final activePins =
          await (select(messagePins)
                ..where((tbl) => tbl.chatJid.equals(chatJid))
                ..where(
                  (tbl) => tbl.messageReferenceId.equals(normalizedReference),
                )
                ..where((tbl) => tbl.active.equals(true)))
              .get();
      for (final pin in activePins) {
        if (pin.pinnedAt.toUtc().isAfter(normalizedPinnedAt)) {
          continue;
        }
        await into(messagePins).insertOnConflictUpdate(
          pin.copyWith(pinnedAt: normalizedPinnedAt, active: false),
        );
      }
      await _refreshPinnedMessageAggregate(
        chatJid: chatJid,
        messageReferenceId: normalizedReference,
        fallbackTimestamp: normalizedPinnedAt,
        writeTombstone: true,
      );
    });
  }

  @override
  Future<void> copyLegacyPinnedMessagesToPinRows({
    required String pinnerJid,
  }) async {
    final normalizedPinner = pinnerJid.trim();
    if (normalizedPinner.isEmpty) {
      return;
    }
    await transaction(() async {
      final legacyRows = await (select(
        pinnedMessages,
      )..where((tbl) => tbl.active.equals(true))).get();
      for (final legacy in legacyRows) {
        final messageId = legacy.messageStanzaId.trim();
        if (messageId.isEmpty) {
          continue;
        }
        final chat = await getChat(legacy.chatJid);
        if (chat?.defaultTransport.isEmail == true) {
          continue;
        }
        final message = await getMessageByReferenceId(
          messageId,
          chatJid: legacy.chatJid,
        );
        if (message?.isEmailBacked == true) {
          continue;
        }
        String referenceId = messageId;
        String? messageStanzaId;
        String? messageOriginId;
        String? messageMucStanzaId;
        if (message != null) {
          final isGroupPin = message.trimmedMucStanzaId != null;
          final pinId = message.pinId(isGroupChat: isGroupPin);
          if (pinId != null) {
            referenceId = pinId;
          }
          messageStanzaId = message.trimmedStanzaId;
          messageOriginId = message.trimmedOriginId;
          messageMucStanzaId = message.trimmedMucStanzaId;
        }
        final existingPinRows =
            await (select(messagePins)
                  ..where((tbl) => tbl.chatJid.equals(legacy.chatJid))
                  ..where((tbl) => tbl.messageReferenceId.equals(referenceId)))
                .get();
        if (existingPinRows.isNotEmpty) {
          continue;
        }
        await into(messagePins).insert(
          PinEntry(
            chatJid: legacy.chatJid,
            messageReferenceId: referenceId,
            messageStanzaId: messageStanzaId,
            messageOriginId: messageOriginId,
            messageMucStanzaId: messageMucStanzaId,
            pinnerJid: normalizedPinner,
            pinnedAt: legacy.pinnedAt.toUtc(),
            active: true,
            identityVerified: true,
          ),
        );
      }
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
      if (existing.isNotEmpty) {
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
        if (requiresRewrite) {
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
        }
      }

      final message = await getMessageByReferenceId(
        canonical,
        chatJid: chatJid,
      );
      final canonicalReference = message == null
          ? canonical
          : message.pinId(isGroupChat: message.trimmedMucStanzaId != null);
      if (canonicalReference == null || canonicalReference.trim().isEmpty) {
        return;
      }
      final existingPins =
          await (select(messagePins)
                ..where((tbl) => tbl.chatJid.equals(chatJid))
                ..where(
                  (tbl) => tbl.messageReferenceId.isIn(normalizedAliases),
                ))
              .get();
      if (existingPins.isEmpty) {
        return;
      }
      final latestPinsByPinner = <String, PinEntry>{};
      for (final pin in existingPins) {
        final current = latestPinsByPinner[pin.pinnerJid];
        if (current == null) {
          latestPinsByPinner[pin.pinnerJid] = pin;
          continue;
        }
        final pinTimestamp = pin.pinnedAt.toUtc();
        final currentTimestamp = current.pinnedAt.toUtc();
        if (pinTimestamp.isAfter(currentTimestamp)) {
          latestPinsByPinner[pin.pinnerJid] = pin;
          continue;
        }
        if (!pinTimestamp.isAtSameMomentAs(currentTimestamp)) {
          continue;
        }
        if (current.active && !pin.active) {
          latestPinsByPinner[pin.pinnerJid] = pin;
          continue;
        }
        if (pin.active == current.active &&
            pin.messageReferenceId == canonical &&
            current.messageReferenceId != canonical) {
          latestPinsByPinner[pin.pinnerJid] = pin;
        }
      }
      await (delete(messagePins)
            ..where((tbl) => tbl.chatJid.equals(chatJid))
            ..where((tbl) => tbl.messageReferenceId.isIn(normalizedAliases)))
          .go();
      for (final pin in latestPinsByPinner.values) {
        await into(messagePins).insertOnConflictUpdate(
          PinEntry(
            chatJid: pin.chatJid,
            messageReferenceId: canonicalReference,
            messageStanzaId: message?.trimmedStanzaId,
            messageOriginId: message?.trimmedOriginId,
            messageMucStanzaId: message?.trimmedMucStanzaId,
            pinnerJid: pin.pinnerJid,
            pinnedAt: pin.pinnedAt.toUtc(),
            active: pin.active,
            identityVerified: pin.identityVerified,
          ),
        );
      }
      await _refreshPinnedMessageAggregate(
        chatJid: chatJid,
        messageReferenceId: canonicalReference,
        fallbackTimestamp: latestPinsByPinner.values
            .map((pin) => pin.pinnedAt.toUtc())
            .reduce((a, b) => a.isAfter(b) ? a : b),
        writeTombstone: latestPinsByPinner.values.every((pin) => !pin.active),
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
  Future<List<Chat>> getChats({required int start, required int end}) {
    return chatsAccessor.selectRange(start: start, end: end);
  }

  @override
  Stream<List<Chat>> watchHomeChats({required int recentLimit}) {
    return chatsAccessor.watchHome(recentLimit: recentLimit);
  }

  @override
  Future<List<Chat>> getHomeChats({required int recentLimit}) {
    return chatsAccessor.selectHome(recentLimit: recentLimit);
  }

  @override
  Stream<List<Chat>> watchAllChats() {
    return chatsAccessor.watchAll();
  }

  @override
  Future<List<Chat>> getAllChats() {
    return chatsAccessor.selectAll();
  }

  @override
  Stream<List<Chat>> watchUnreadChatsForFolderBadges() {
    return chatsAccessor.watchUnreadForFolderBadges();
  }

  @override
  Future<List<Chat>> getUnreadChatsForFolderBadges() {
    return chatsAccessor.selectUnreadForFolderBadges();
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
    await transaction(() async {
      await (delete(emailChatAccounts)..where(
            (tbl) =>
                tbl.deltaAccountId.equals(deltaAccountId) &
                tbl.deltaChatId.equals(deltaChatId) &
                tbl.chatJid.isNotValue(chatJid),
          ))
          .go();
      await into(emailChatAccounts).insertOnConflictUpdate(
        EmailChatAccountsCompanion.insert(
          chatJid: chatJid,
          deltaAccountId: Value(deltaAccountId),
          deltaChatId: deltaChatId,
        ),
      );
    });
  }

  @override
  Future<List<EmailChatAccountData>> getEmailChatAccountsForAccount(
    int deltaAccountId,
  ) {
    return (select(emailChatAccounts)
          ..where((tbl) => tbl.deltaAccountId.equals(deltaAccountId))
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.chatJid),
            (tbl) => OrderingTerm.desc(tbl.deltaChatId),
          ]))
        .get();
  }

  @override
  Future<List<int>> getDeltaChatIdsForAccount({
    required String chatJid,
    required int deltaAccountId,
  }) async {
    final rows =
        await (select(emailChatAccounts)
              ..where(
                (tbl) =>
                    tbl.chatJid.equals(chatJid) &
                    tbl.deltaAccountId.equals(deltaAccountId),
              )
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.deltaChatId)]))
            .get();
    return rows.map((row) => row.deltaChatId).toList(growable: false);
  }

  @override
  Future<List<int>> getMessageDeltaChatIdsForAccount({
    required String chatJid,
    required int deltaAccountId,
  }) async {
    final normalizedJid = chatJid.trim();
    if (normalizedJid.isEmpty || deltaAccountId <= 0) {
      return const <int>[];
    }
    final rows =
        await (selectOnly(messages)
              ..addColumns([messages.deltaChatId])
              ..where(
                messages.chatJid.equals(normalizedJid) &
                    messages.deltaAccountId.equals(deltaAccountId) &
                    messages.deltaChatId.isNotNull(),
              )
              ..orderBy([OrderingTerm.desc(messages.deltaChatId)]))
            .get();
    return {
      for (final row in rows)
        if (row.read(messages.deltaChatId) case final int chatId) chatId,
    }.toList(growable: false);
  }

  @override
  Future<int?> getDeltaChatIdForAccount({
    required String chatJid,
    required int deltaAccountId,
  }) async {
    final deltaChatIds = await getDeltaChatIdsForAccount(
      chatJid: chatJid,
      deltaAccountId: deltaAccountId,
    );
    return deltaChatIds.firstOrNull;
  }

  @override
  Future<void> deleteEmailChatAccount({
    required String chatJid,
    required int deltaAccountId,
    required int deltaChatId,
  }) async {
    await (delete(emailChatAccounts)..where(
          (tbl) =>
              tbl.chatJid.equals(chatJid) &
              tbl.deltaAccountId.equals(deltaAccountId) &
              tbl.deltaChatId.equals(deltaChatId),
        ))
        .go();
  }

  @override
  Future<void> deleteEmailChatAccountsForDeltaChat({
    required int deltaAccountId,
    required int deltaChatId,
  }) async {
    await (delete(emailChatAccounts)..where(
          (tbl) =>
              tbl.deltaAccountId.equals(deltaAccountId) &
              tbl.deltaChatId.equals(deltaChatId),
        ))
        .go();
  }

  @override
  Future<void> deleteEmailChatAccountsForAccount(int deltaAccountId) async {
    await (delete(
      emailChatAccounts,
    )..where((tbl) => tbl.deltaAccountId.equals(deltaAccountId))).go();
    await (delete(
      emailTrustedContactKeys,
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
  Future<EmailTrustedContactKeyData?> getEmailTrustedContactKey({
    required int deltaAccountId,
    required String address,
  }) async {
    final normalizedAddress = _normalizeEmail(address);
    if (normalizedAddress.isEmpty) {
      return null;
    }
    return (select(emailTrustedContactKeys)..where(
          (tbl) =>
              tbl.deltaAccountId.equals(deltaAccountId) &
              tbl.address.equals(normalizedAddress),
        ))
        .getSingleOrNull();
  }

  @override
  Future<void> upsertEmailTrustedContactKey(
    EmailTrustedContactKeyData key,
  ) async {
    await into(emailTrustedContactKeys).insertOnConflictUpdate(key);
  }

  @override
  Future<void> deleteEmailTrustedContactKey({
    required int deltaAccountId,
    required String address,
  }) async {
    final normalizedAddress = _normalizeEmail(address);
    if (normalizedAddress.isEmpty) {
      return;
    }
    await (delete(emailTrustedContactKeys)..where(
          (tbl) =>
              tbl.deltaAccountId.equals(deltaAccountId) &
              tbl.address.equals(normalizedAddress),
        ))
        .go();
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
    final resolvedTransport = await _resolveCreatedChatTransport(chat);

    return await chatsAccessor.insertOne(
      chat.copyWith(
        transport: resolvedTransport,
        lastMessage: lastMessagePreview,
        lastChangeTimestamp: lastMessage?.timestamp ?? chat.lastChangeTimestamp,
      ),
    );
  }

  Future<MessageTransport> _resolveCreatedChatTransport(Chat chat) async {
    if (chat.transport != MessageTransport.email ||
        chat.type != ChatType.chat) {
      return chat.transport;
    }
    final bareJid = bareAddress(chat.jid) ?? chat.jid.trim();
    if (bareJid.isEmpty) {
      return chat.transport;
    }
    final rosterItem = await rosterAccessor.selectOne(bareJid);
    if (rosterItem == null) {
      return chat.transport;
    }
    return MessageTransport.xmpp;
  }

  @override
  Future<void> updateChat(Chat chat) => chatsAccessor.updateOne(chat);

  @override
  Future<void> markDirectChatXmppCapable(String jid) async {
    await _markDirectChatsXmppCapable([jid]);
  }

  Future<void> repairMixedChatTransports() async {
    final rosterItems = await rosterAccessor.selectAll();
    if (rosterItems.isEmpty) {
      return;
    }
    final jids = rosterItems
        .map((item) => bareAddress(item.jid) ?? item.jid.trim())
        .where((jid) => jid.isNotEmpty)
        .toList(growable: false);
    await _markDirectChatsXmppCapable(jids);
  }

  Future<int> _promoteRosterBackedEmailChats() {
    return customUpdate(
      '''
UPDATE chats
SET transport = ?
WHERE transport = ?
  AND type = ?
  AND EXISTS (
    SELECT 1
    FROM roster
    WHERE lower(trim(roster.jid)) = lower(trim(chats.jid))
  )
''',
      variables: [
        Variable<int>(MessageTransport.xmpp.index),
        Variable<int>(MessageTransport.email.index),
        Variable<int>(ChatType.chat.index),
      ],
      updates: {chats},
    );
  }

  Future<int> _repairOverpromotedEmailChatTransports() {
    return customUpdate(
      '''
UPDATE chats
SET transport = ?
WHERE transport = ?
  AND type = ?
  AND (
    delta_chat_id IS NOT NULL
    OR EXISTS (
      SELECT 1
      FROM email_chat_accounts
      WHERE email_chat_accounts.chat_jid = chats.jid
    )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM roster
    WHERE lower(trim(roster.jid)) = lower(trim(chats.jid))
  )
  AND NOT EXISTS (
    SELECT 1
    FROM messages
    WHERE messages.chat_jid = chats.jid
      AND (
        (
          messages.muc_stanza_id IS NOT NULL
          AND trim(messages.muc_stanza_id) != ''
        )
        OR (
          messages.sender_real_jid IS NOT NULL
          AND trim(messages.sender_real_jid) != ''
        )
        OR (
          messages.occupant_i_d IS NOT NULL
          AND trim(messages.occupant_i_d) != ''
        )
        OR messages.device_i_d IS NOT NULL
        OR messages.trust IS NOT NULL
        OR messages.trusted IS NOT NULL
        OR messages.encryption_protocol IN (?, ?)
        OR messages.is_file_upload_notification = 1
      )
  )
''',
      variables: [
        Variable<int>(MessageTransport.email.index),
        Variable<int>(MessageTransport.xmpp.index),
        Variable<int>(ChatType.chat.index),
        Variable<int>(EncryptionProtocol.omemo.index),
        Variable<int>(EncryptionProtocol.mls.index),
      ],
      updates: {chats},
    );
  }

  Future<void> _markDirectChatsXmppCapable(Iterable<String> jids) async {
    final normalizedJids = jids
        .map((jid) => bareAddress(jid) ?? jid.trim())
        .where((jid) => jid.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedJids.isEmpty) return;

    for (final batch in _chunked(normalizedJids, batchSize: 900)) {
      await (update(chats)..where(
            (tbl) =>
                tbl.jid.isIn(batch) &
                tbl.type.equals(ChatType.chat.index) &
                tbl.transport.equals(MessageTransport.email.index),
          ))
          .write(const ChatsCompanion(transport: Value(MessageTransport.xmpp)));
    }
  }

  @override
  Future<void> updateChatSettingsSyncState(Chat chat) {
    return (update(chats)..where((row) => row.jid.equals(chat.jid))).write(
      ChatsCompanion(
        muted: Value(chat.muted),
        notificationPreviewSetting: Value(chat.notificationPreviewSetting),
        notificationBehavior: Value(chat.notificationBehavior),
        markerResponsive: Value(chat.markerResponsive),
        shareSignatureEnabled: Value(chat.shareSignatureEnabled),
        attachmentAutoDownload: Value(chat.attachmentAutoDownload),
        emailRemoteImagesEnabled: Value(chat.emailRemoteImagesEnabled),
        typingIndicatorsEnabled: Value(chat.typingIndicatorsEnabled),
        emailReadReceiptsEnabled: Value(chat.emailReadReceiptsEnabled),
        emailSendConfirmationEnabled: Value(chat.emailSendConfirmationEnabled),
        emailComposerWatermarkEnabled: Value(
          chat.emailComposerWatermarkEnabled,
        ),
        chatSettingsUpdatedAt: Value(chat.chatSettingsUpdatedAt),
        chatSettingsSourceId: Value(chat.chatSettingsSourceId),
        chatSettingsConfirmedJson: Value(chat.chatSettingsConfirmedJson),
        chatSettingsConfirmedUpdatedAt: Value(
          chat.chatSettingsConfirmedUpdatedAt,
        ),
        chatSettingsConfirmedSourceId: Value(
          chat.chatSettingsConfirmedSourceId,
        ),
      ),
    );
  }

  @override
  Future<void> updateConversationIndexChatMeta({
    required String jid,
    required DateTime lastChangeTimestamp,
    required bool muted,
    required bool favorited,
    required bool archived,
    required String contactJid,
  }) async {
    await transaction(() async {
      await _markDirectChatsXmppCapable([jid]);
      await customUpdate(
        '''
UPDATE chats
SET last_message = CASE
      WHEN last_change_timestamp IS NULL OR last_change_timestamp < ? THEN NULL
      ELSE last_message
    END,
    last_change_timestamp = CASE
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
          Variable<DateTime>(lastChangeTimestamp),
          Variable<bool>(muted),
          Variable<bool>(favorited),
          Variable<bool>(archived),
          Variable<String>(contactJid),
          Variable<String>(jid),
        ],
        updates: {chats},
      );
    });
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

  Future<int> collapseDuplicateDeltaPairRows() async {
    final count = countAll();
    final duplicateGroups = selectOnly(messages)
      ..addColumns([messages.deltaAccountId, messages.deltaMsgId, count])
      ..where(messages.deltaMsgId.isNotNull())
      ..groupBy([
        messages.deltaAccountId,
        messages.deltaMsgId,
      ], having: count.isBiggerThanValue(1));
    final groups = await duplicateGroups.get();
    var removed = 0;
    final affectedChatJids = <String>{};
    for (final group in groups) {
      removed += await _deleteExtraDeltaPairRows(
        deltaAccountId: group.read(messages.deltaAccountId),
        deltaMsgId: group.read(messages.deltaMsgId),
        affectedChatJids: affectedChatJids,
      );
    }
    for (final chatJid in affectedChatJids) {
      await repairUnreadCountForChat(chatJid);
      await repairChatSummaryFromMessages(chatJid);
    }
    return removed;
  }

  @override
  Future<int> collapseLegacyDeltaAccountDuplicates({
    required List<int> activeAccountIds,
  }) async {
    final canonicalAccountIds = activeAccountIds
        .where((id) => id != DeltaAccountDefaults.legacyId)
        .toSet()
        .toList(growable: false);
    if (canonicalAccountIds.isEmpty) {
      return 0;
    }
    return transaction(() async {
      final legacyRows =
          await (select(messages)
                ..where(
                  (tbl) =>
                      tbl.deltaAccountId.equals(DeltaAccountDefaults.legacyId) &
                      tbl.deltaMsgId.isNotNull(),
                )
                ..orderBy([
                  (tbl) => OrderingTerm.asc(tbl.timestamp),
                  (tbl) => OrderingTerm.asc(tbl.stanzaID),
                ]))
              .get();
      var removed = 0;
      final affectedChatJids = <String>{};
      for (final legacyRow in legacyRows) {
        final deltaMsgId = legacyRow.deltaMsgId;
        if (deltaMsgId == null) {
          continue;
        }
        final canonicalRows =
            await (select(messages)
                  ..where(
                    (tbl) =>
                        tbl.deltaMsgId.equals(deltaMsgId) &
                        tbl.deltaAccountId.isIn(canonicalAccountIds),
                  )
                  ..orderBy([
                    (tbl) => OrderingTerm.asc(tbl.timestamp),
                    (tbl) => OrderingTerm.asc(tbl.stanzaID),
                  ]))
                .get();
        final keeper = _legacyDeltaDuplicateKeeper(
          legacyRow: legacyRow,
          canonicalRows: canonicalRows,
        );
        if (keeper == null) {
          continue;
        }
        affectedChatJids
          ..add(legacyRow.chatJid)
          ..add(keeper.chatJid);
        await _migrateDeltaDuplicateMemberships(
          extra: legacyRow,
          keeper: keeper,
        );
        await _migratePinsToKeeper(extra: legacyRow, keeper: keeper);
        await _migrateAttachmentsToKeeper(extra: legacyRow, keeper: keeper);
        await _migrateReactionsToKeeper(extra: legacyRow, keeper: keeper);
        await _deleteMessageRowWithDependents(legacyRow);
        removed++;
      }
      for (final chatJid in affectedChatJids) {
        await repairUnreadCountForChat(chatJid);
        await repairChatSummaryFromMessages(chatJid);
      }
      return removed;
    });
  }

  @override
  Future<int> normalizeDeltaAccountsForSingleContext() async {
    return transaction(() async {
      final affectedChatJids = <String>{};
      var changed = 0;
      changed += await _collapseLegacyDeltaStanzaDuplicates(affectedChatJids);
      changed += await _collapseDuplicateDeltaMessagesAcrossAccounts(
        affectedChatJids,
      );
      changed += await _normalizeMessageRowsForSingleContext(affectedChatJids);
      changed += await _normalizeMessageCollectionMembershipsForSingleContext();
      changed += await _normalizeMessageCopiesForSingleContext();
      changed += await _normalizeEmailChatAccountsForSingleContext();
      changed += await _normalizeEmailTrustedContactKeysForSingleContext();
      changed += await collapseDuplicateDeltaPairRows();
      for (final chatJid in affectedChatJids) {
        await repairUnreadCountForChat(chatJid);
        await repairChatSummaryFromMessages(chatJid);
      }
      return changed;
    });
  }

  Future<int> _collapseLegacyDeltaStanzaDuplicates(
    Set<String> affectedChatJids,
  ) async {
    final legacyRows =
        await (select(messages)
              ..where(
                (tbl) =>
                    tbl.deltaMsgId.isNull() &
                    (tbl.stanzaID.like('dc-msg-%') |
                        tbl.stanzaID.like('dc-local-msg-%')),
              )
              ..orderBy([
                (tbl) => OrderingTerm.asc(tbl.timestamp),
                (tbl) => OrderingTerm.asc(tbl.stanzaID),
              ]))
            .get();
    var changed = 0;
    for (final legacyRow in legacyRows) {
      final parsedDeltaMsgId = deltaMsgIdFromDeviceLocalStanzaId(
        legacyRow.stanzaID,
      );
      if (parsedDeltaMsgId == null) {
        continue;
      }
      final keeper = await _legacyDeltaStanzaDuplicateKeeper(
        legacyRow: legacyRow,
        deltaMsgId: parsedDeltaMsgId,
      );
      if (keeper == null) {
        continue;
      }
      affectedChatJids
        ..add(legacyRow.chatJid)
        ..add(keeper.chatJid);
      final mergedKeeper = await _mergeDeltaMessageStateIntoKeeper(
        extra: legacyRow,
        keeper: keeper,
      );
      await _migrateDeltaDuplicateMemberships(
        extra: legacyRow.copyWith(deltaMsgId: parsedDeltaMsgId),
        keeper: mergedKeeper,
      );
      await _migratePinsToKeeper(extra: legacyRow, keeper: mergedKeeper);
      await _migrateAttachmentsToKeeper(extra: legacyRow, keeper: mergedKeeper);
      await _migrateReactionsToKeeper(extra: legacyRow, keeper: mergedKeeper);
      await _deleteMessageRowWithDependents(legacyRow);
      changed++;
    }
    return changed;
  }

  Future<Message?> _legacyDeltaStanzaDuplicateKeeper({
    required Message legacyRow,
    required int deltaMsgId,
  }) async {
    final rows =
        await (select(messages)
              ..where((tbl) => tbl.deltaMsgId.equals(deltaMsgId))
              ..orderBy([
                (tbl) => OrderingTerm.asc(tbl.timestamp),
                (tbl) => OrderingTerm.asc(tbl.stanzaID),
              ]))
            .get();
    if (rows.isEmpty) {
      return null;
    }
    final keeper = rows.length == 1
        ? rows.single
        : await _preferredSingleContextDeltaMessage(rows);
    if (keeper == null ||
        !await _legacyDeltaStanzaRowMatchesKeeper(
          legacyRow: legacyRow,
          keeper: keeper,
          deltaMsgId: deltaMsgId,
        )) {
      return null;
    }
    return keeper;
  }

  Future<bool> _legacyDeltaStanzaRowMatchesKeeper({
    required Message legacyRow,
    required Message keeper,
    required int deltaMsgId,
  }) async {
    if (keeper.deltaMsgId != deltaMsgId) {
      return false;
    }
    if (legacyRow.chatJid == keeper.chatJid) {
      return true;
    }
    final legacyOrigin = genuineEmailMessageId(legacyRow.originID);
    return legacyOrigin != null &&
        legacyOrigin == genuineEmailMessageId(keeper.originID);
  }

  Future<int> _collapseDuplicateDeltaMessagesAcrossAccounts(
    Set<String> affectedChatJids,
  ) async {
    final count = countAll();
    final duplicateGroups = selectOnly(messages)
      ..addColumns([messages.deltaMsgId, count])
      ..where(messages.deltaMsgId.isNotNull())
      ..groupBy([messages.deltaMsgId], having: count.isBiggerThanValue(1));
    final groups = await duplicateGroups.get();
    var changed = 0;
    for (final group in groups) {
      final deltaMsgId = group.read(messages.deltaMsgId);
      if (deltaMsgId == null) {
        continue;
      }
      final rows =
          await (select(messages)
                ..where((tbl) => tbl.deltaMsgId.equals(deltaMsgId))
                ..orderBy([
                  (tbl) => OrderingTerm.asc(tbl.timestamp),
                  (tbl) => OrderingTerm.asc(tbl.stanzaID),
                ]))
              .get();
      if (rows.length < 2) {
        continue;
      }
      for (final row in rows) {
        affectedChatJids.add(row.chatJid);
      }
      final initialKeeper = await _preferredSingleContextDeltaMessage(rows);
      if (initialKeeper == null) {
        for (final row in rows) {
          await _clearAmbiguousDuplicateDeltaLocator(row);
          changed++;
        }
        continue;
      }
      var keeper = initialKeeper;
      for (final extra in rows) {
        if (extra.stanzaID == keeper.stanzaID) {
          continue;
        }
        if (!await _singleContextDeltaRowsAreProvenDuplicates(
          first: extra,
          second: keeper,
        )) {
          await _clearAmbiguousDuplicateDeltaLocator(extra);
          changed++;
          continue;
        }
        keeper = await _mergeDeltaMessageStateIntoKeeper(
          extra: extra,
          keeper: keeper,
        );
        await _migrateDeltaDuplicateMemberships(extra: extra, keeper: keeper);
        await _migratePinsToKeeper(extra: extra, keeper: keeper);
        await _migrateAttachmentsToKeeper(extra: extra, keeper: keeper);
        await _migrateReactionsToKeeper(extra: extra, keeper: keeper);
        await _deleteMessageRowWithDependents(extra);
        changed++;
      }
    }
    return changed;
  }

  Future<Message?> _preferredSingleContextDeltaMessage(
    List<Message> rows,
  ) async {
    return await _preferredSingleContextDeltaMessageBy(
          rows,
          _deltaMessageMatchesStoredChatAccount,
        ) ??
        await _preferredSingleContextDeltaMessageBy(
          rows,
          _deltaMessageMatchesSingleContextChatAccount,
        ) ??
        await _preferredSingleContextDeltaMessageBy(
          rows,
          _chatDeltaIdMatchesMessage,
        ) ??
        _uniqueDeltaMessageBy(
          rows,
          (row) => row.deltaAccountId == DeltaAccountDefaults.singleContextId,
        ) ??
        _uniqueDeltaMessageBy(
          rows,
          (row) => genuineEmailMessageId(row.originID) != null,
        );
  }

  Future<Message?> _preferredSingleContextDeltaMessageBy(
    List<Message> rows,
    Future<bool> Function(Message row) predicate,
  ) async {
    final matches = <Message>[];
    for (final row in rows) {
      if (await predicate(row)) {
        matches.add(row);
      }
    }
    if (matches.isEmpty) {
      return null;
    }
    return _preferredDuplicateDeltaMessageRow(matches);
  }

  Message? _uniqueDeltaMessageBy(
    List<Message> rows,
    bool Function(Message row) predicate,
  ) {
    Message? match;
    for (final row in rows) {
      if (!predicate(row)) {
        continue;
      }
      if (match != null) {
        return null;
      }
      match = row;
    }
    return match;
  }

  Future<Message> _preferredDuplicateDeltaMessageRow(List<Message> rows) async {
    return _uniqueDeltaMessageBy(
          rows,
          (row) => row.deltaAccountId == DeltaAccountDefaults.singleContextId,
        ) ??
        _uniqueDeltaMessageBy(
          rows,
          (row) => genuineEmailMessageId(row.originID) != null,
        ) ??
        await _uniqueDeltaMessageByAsync(
          rows,
          _deltaMessageHasUserReferences,
        ) ??
        _uniqueDeltaMessageBy(
          rows,
          (row) => row.rfc822BodyStatus == EmailRfc822BodyStatus.hydrated,
        ) ??
        _uniqueDeltaMessageBy(
          rows,
          (row) =>
              row.body?.trim().isNotEmpty == true ||
              row.htmlBody?.trim().isNotEmpty == true ||
              row.fileMetadataID?.trim().isNotEmpty == true,
        ) ??
        rows.first;
  }

  Future<Message?> _uniqueDeltaMessageByAsync(
    List<Message> rows,
    Future<bool> Function(Message row) predicate,
  ) async {
    Message? match;
    for (final row in rows) {
      if (!await predicate(row)) {
        continue;
      }
      if (match != null) {
        return null;
      }
      match = row;
    }
    return match;
  }

  Future<bool> _deltaMessageHasUserReferences(Message row) async {
    final attachmentOwnerIds = <String>{row.stanzaID.trim()};
    final rowId = row.id?.trim();
    if (rowId != null && rowId.isNotEmpty) {
      attachmentOwnerIds.add(rowId);
    }
    final attachment =
        await (select(messageAttachments)
              ..where((tbl) => tbl.messageId.isIn(attachmentOwnerIds))
              ..limit(1))
            .getSingleOrNull();
    if (attachment != null) {
      return true;
    }
    final legacyPin =
        await (select(pinnedMessages)
              ..where(
                (tbl) =>
                    tbl.chatJid.equals(row.chatJid) &
                    tbl.messageStanzaId.equals(row.stanzaID),
              )
              ..limit(1))
            .getSingleOrNull();
    if (legacyPin != null) {
      return true;
    }
    final references = row.referenceIds;
    if (references.isNotEmpty) {
      final pin =
          await (select(messagePins)
                ..where(
                  (tbl) =>
                      tbl.chatJid.equals(row.chatJid) &
                      tbl.messageReferenceId.isIn(references),
                )
                ..limit(1))
              .getSingleOrNull();
      if (pin != null) {
        return true;
      }
    }
    final deltaMsgId = row.deltaMsgId;
    Expression<bool> membershipPredicate(
      $MessageCollectionMembershipsTable tbl,
    ) {
      var predicate = references.isEmpty
          ? const Constant(false)
          : tbl.messageReferenceId.isIn(references);
      if (deltaMsgId != null) {
        predicate =
            predicate |
            (tbl.deltaMsgId.equals(deltaMsgId) &
                tbl.deltaAccountId.equals(row.deltaAccountId));
      }
      return tbl.chatJid.equals(row.chatJid) & predicate;
    }

    final membership =
        await (select(messageCollectionMemberships)
              ..where(membershipPredicate)
              ..limit(1))
            .getSingleOrNull();
    if (membership != null) {
      return true;
    }
    final reaction =
        await (select(reactions)
              ..where((tbl) => tbl.messageID.equals(row.stanzaID))
              ..limit(1))
            .getSingleOrNull();
    if (reaction != null) {
      return true;
    }
    final reactionState =
        await (select(reactionStates)
              ..where((tbl) => tbl.messageID.equals(row.stanzaID))
              ..limit(1))
            .getSingleOrNull();
    return reactionState != null;
  }

  Future<bool> _deltaMessageHasStoredChatEvidence(Message row) async {
    return await _deltaMessageMatchesStoredChatAccount(row) ||
        await _deltaMessageMatchesSingleContextChatAccount(row) ||
        await _chatDeltaIdMatchesMessage(row);
  }

  Future<bool> _singleContextDeltaRowsAreProvenDuplicates({
    required Message first,
    required Message second,
  }) async {
    final firstOrigin = genuineEmailMessageId(first.originID);
    final secondOrigin = genuineEmailMessageId(second.originID);
    if (firstOrigin != null && firstOrigin == secondOrigin) {
      return true;
    }
    if (first.chatJid != second.chatJid) {
      return false;
    }
    final firstDeltaChatId = first.deltaChatId;
    if (firstDeltaChatId == null || firstDeltaChatId != second.deltaChatId) {
      return false;
    }
    return await _deltaMessageHasStoredChatEvidence(first) &&
        await _deltaMessageHasStoredChatEvidence(second);
  }

  Future<bool> _deltaMessageMatchesStoredChatAccount(Message row) async {
    final deltaChatId = row.deltaChatId;
    if (deltaChatId == null) {
      return false;
    }
    final mapped = await _emailChatAccountJid(
      deltaAccountId: row.deltaAccountId,
      deltaChatId: deltaChatId,
    );
    return mapped == row.chatJid;
  }

  Future<bool> _deltaMessageMatchesSingleContextChatAccount(Message row) async {
    final deltaChatId = row.deltaChatId;
    if (deltaChatId == null) {
      return false;
    }
    final mapped = await _emailChatAccountJid(
      deltaAccountId: DeltaAccountDefaults.singleContextId,
      deltaChatId: deltaChatId,
    );
    return mapped == row.chatJid;
  }

  Future<bool> _chatDeltaIdMatchesMessage(Message row) async {
    final deltaChatId = row.deltaChatId;
    if (deltaChatId == null) {
      return false;
    }
    final chat = await getChat(row.chatJid);
    return chat?.deltaChatId == deltaChatId;
  }

  Future<void> _clearAmbiguousDuplicateDeltaLocator(Message row) async {
    await (update(messages)..where((tbl) => tbl.stanzaID.equals(row.stanzaID)))
        .write(const MessagesCompanion(deltaMsgId: Value(null)));
    final deltaMsgId = row.deltaMsgId;
    if (deltaMsgId == null) {
      return;
    }
    final references = row.referenceIds;
    Expression<bool> referencePredicate(
      $MessageCollectionMembershipsTable tbl,
    ) {
      var predicate = references.isEmpty
          ? const Constant(false)
          : tbl.messageReferenceId.isIn(references);
      predicate =
          predicate |
          (tbl.deltaMsgId.equals(deltaMsgId) &
              tbl.deltaAccountId.equals(row.deltaAccountId));
      return tbl.chatJid.equals(row.chatJid) & predicate;
    }

    final entries = await (select(
      messageCollectionMemberships,
    )..where(referencePredicate)).get();
    for (final entry in entries) {
      await _clearCollectionMembershipHandles(entry);
    }
  }

  Future<Message> _mergeDeltaMessageStateIntoKeeper({
    required Message extra,
    required Message keeper,
  }) async {
    final merged = keeper.copyWith(
      originID: _preferPresentString(keeper.originID, extra.originID),
      mucStanzaId: _preferPresentString(keeper.mucStanzaId, extra.mucStanzaId),
      occupantID: _preferPresentString(keeper.occupantID, extra.occupantID),
      senderRealJid: _preferPresentString(
        keeper.senderRealJid,
        extra.senderRealJid,
      ),
      body: _preferPresentString(keeper.body, extra.body),
      htmlBody: _preferPresentString(keeper.htmlBody, extra.htmlBody),
      subject: _preferPresentString(keeper.subject, extra.subject),
      trust: keeper.trust ?? extra.trust,
      trusted: keeper.trusted ?? extra.trusted,
      deviceID: keeper.deviceID ?? extra.deviceID,
      noStore: keeper.noStore || extra.noStore,
      acked: keeper.acked || extra.acked,
      received: keeper.received || extra.received,
      displayed: keeper.displayed || extra.displayed,
      deltaSeenSynced: keeper.deltaSeenSynced || extra.deltaSeenSynced,
      edited: keeper.edited || extra.edited,
      retracted: keeper.retracted || extra.retracted,
      isFileUploadNotification:
          keeper.isFileUploadNotification || extra.isFileUploadNotification,
      fileDownloading: keeper.fileDownloading || extra.fileDownloading,
      fileUploading: keeper.fileUploading || extra.fileUploading,
      fileMetadataID: _preferPresentString(
        keeper.fileMetadataID,
        extra.fileMetadataID,
      ),
      replyStanzaId: _preferPresentString(
        keeper.replyStanzaId,
        extra.replyStanzaId,
      ),
      replyOriginId: _preferPresentString(
        keeper.replyOriginId,
        extra.replyOriginId,
      ),
      replyMucStanzaId: _preferPresentString(
        keeper.replyMucStanzaId,
        extra.replyMucStanzaId,
      ),
      stickerPackID: _preferPresentString(
        keeper.stickerPackID,
        extra.stickerPackID,
      ),
      pseudoMessageType: keeper.pseudoMessageType ?? extra.pseudoMessageType,
      pseudoMessageData: keeper.pseudoMessageData ?? extra.pseudoMessageData,
      rfc822BodyStatus: _bestRfc822BodyStatus(
        keeper.rfc822BodyStatus,
        extra.rfc822BodyStatus,
      ),
      manualSendAgainStanzaID: _preferPresentString(
        keeper.manualSendAgainStanzaID,
        extra.manualSendAgainStanzaID,
      ),
      deltaChatId: keeper.deltaChatId ?? extra.deltaChatId,
    );
    if (merged == keeper) {
      return keeper;
    }
    await updateMessage(merged);
    return merged;
  }

  String? _preferPresentString(String? preferred, String? fallback) {
    final preferredTrimmed = preferred?.trim();
    if (preferredTrimmed != null && preferredTrimmed.isNotEmpty) {
      return preferred;
    }
    final fallbackTrimmed = fallback?.trim();
    if (fallbackTrimmed != null && fallbackTrimmed.isNotEmpty) {
      return fallback;
    }
    return preferred ?? fallback;
  }

  EmailRfc822BodyStatus _bestRfc822BodyStatus(
    EmailRfc822BodyStatus preferred,
    EmailRfc822BodyStatus fallback,
  ) {
    if (_rfc822BodyStatusRank(fallback) > _rfc822BodyStatusRank(preferred)) {
      return fallback;
    }
    return preferred;
  }

  int _rfc822BodyStatusRank(EmailRfc822BodyStatus status) {
    return switch (status) {
      EmailRfc822BodyStatus.hydrated => 3,
      EmailRfc822BodyStatus.pendingDownload => 2,
      EmailRfc822BodyStatus.unavailable => 1,
      EmailRfc822BodyStatus.unknown => 0,
    };
  }

  Future<int> _normalizeMessageRowsForSingleContext(
    Set<String> affectedChatJids,
  ) async {
    final rows = await customSelect(
      '''
SELECT stanza_i_d, chat_jid
FROM messages
WHERE (delta_msg_id IS NOT NULL OR delta_chat_id IS NOT NULL)
  AND delta_account_id != ?
''',
      variables: [Variable<int>(DeltaAccountDefaults.singleContextId)],
      readsFrom: {messages},
    ).get();
    for (final row in rows) {
      final stanzaId = row.read<String>('stanza_i_d');
      affectedChatJids.add(row.read<String>('chat_jid'));
      await (update(
        messages,
      )..where((tbl) => tbl.stanzaID.equals(stanzaId))).write(
        const MessagesCompanion(
          deltaAccountId: Value(DeltaAccountDefaults.singleContextId),
        ),
      );
    }
    return rows.length;
  }

  Future<int> _normalizeMessageCollectionMembershipsForSingleContext() async {
    final rows =
        await (select(messageCollectionMemberships)..where(
              (tbl) =>
                  tbl.deltaMsgId.isNotNull() &
                  (tbl.deltaAccountId.isNull() |
                      tbl.deltaAccountId.isNotValue(
                        DeltaAccountDefaults.singleContextId,
                      )),
            ))
            .get();
    for (final row in rows) {
      await (update(messageCollectionMemberships)..where(
            (tbl) =>
                tbl.collectionId.equals(row.collectionId) &
                tbl.chatJid.equals(row.chatJid) &
                tbl.messageReferenceId.equals(row.messageReferenceId),
          ))
          .write(
            const MessageCollectionMembershipsCompanion(
              deltaAccountId: Value(DeltaAccountDefaults.singleContextId),
            ),
          );
    }
    return rows.length;
  }

  Future<int> _normalizeMessageCopiesForSingleContext() async {
    final count = countAll();
    final duplicateGroups = selectOnly(messageCopies)
      ..addColumns([messageCopies.dcMsgId, count])
      ..groupBy([messageCopies.dcMsgId], having: count.isBiggerThanValue(1));
    final groups = await duplicateGroups.get();
    var changed = 0;
    for (final group in groups) {
      final dcMsgId = group.read(messageCopies.dcMsgId);
      if (dcMsgId == null) {
        continue;
      }
      final rows =
          await (select(messageCopies)
                ..where((tbl) => tbl.dcMsgId.equals(dcMsgId))
                ..orderBy([
                  (tbl) => OrderingTerm.desc(
                    tbl.dcAccountId.equals(
                      DeltaAccountDefaults.singleContextId,
                    ),
                  ),
                  (tbl) => OrderingTerm.asc(tbl.id),
                ]))
              .get();
      final keeper = await _preferredSingleContextMessageCopy(rows);
      if (keeper == null) {
        continue;
      }
      for (final row in rows) {
        if (row.id == keeper.id) {
          continue;
        }
        await (delete(
          messageCopies,
        )..where((tbl) => tbl.id.equals(row.id))).go();
        changed++;
      }
    }
    final rows =
        await (select(messageCopies)..where(
              (tbl) => tbl.dcAccountId.isNotValue(
                DeltaAccountDefaults.singleContextId,
              ),
            ))
            .get();
    for (final row in rows) {
      await (update(
        messageCopies,
      )..where((tbl) => tbl.id.equals(row.id))).write(
        const MessageCopiesCompanion(
          dcAccountId: Value(DeltaAccountDefaults.singleContextId),
        ),
      );
    }
    return changed + rows.length;
  }

  Future<MessageCopyData?> _preferredSingleContextMessageCopy(
    List<MessageCopyData> rows,
  ) async {
    if (rows.isEmpty) {
      return null;
    }
    final messageBacked = <MessageCopyData>[];
    for (final row in rows) {
      if (await _messageCopyHasStoredMessage(row)) {
        messageBacked.add(row);
      }
    }
    return _uniqueMessageCopyBy(messageBacked, (_) => true) ??
        _uniqueMessageCopyBy(
          rows,
          (row) => row.dcAccountId == DeltaAccountDefaults.singleContextId,
        ) ??
        rows.first;
  }

  Future<bool> _messageCopyHasStoredMessage(MessageCopyData row) async {
    final messageCount = countAll();
    final query = selectOnly(messages)
      ..addColumns([messageCount])
      ..where(
        messages.deltaMsgId.equals(row.dcMsgId) &
            messages.deltaChatId.equals(row.dcChatId),
      );
    return ((await query.getSingle()).read(messageCount) ?? 0) > 0;
  }

  MessageCopyData? _uniqueMessageCopyBy(
    List<MessageCopyData> rows,
    bool Function(MessageCopyData row) predicate,
  ) {
    MessageCopyData? match;
    for (final row in rows) {
      if (!predicate(row)) {
        continue;
      }
      if (match != null) {
        return null;
      }
      match = row;
    }
    return match;
  }

  Future<int> _normalizeEmailChatAccountsForSingleContext() async {
    final count = countAll();
    final duplicateGroups = selectOnly(emailChatAccounts)
      ..addColumns([emailChatAccounts.deltaChatId, count])
      ..groupBy([
        emailChatAccounts.deltaChatId,
      ], having: count.isBiggerThanValue(1));
    final groups = await duplicateGroups.get();
    var changed = 0;
    for (final group in groups) {
      final deltaChatId = group.read(emailChatAccounts.deltaChatId);
      if (deltaChatId == null) {
        continue;
      }
      final rows =
          await (select(emailChatAccounts)
                ..where((tbl) => tbl.deltaChatId.equals(deltaChatId))
                ..orderBy([
                  (tbl) => OrderingTerm.desc(
                    tbl.deltaAccountId.equals(
                      DeltaAccountDefaults.singleContextId,
                    ),
                  ),
                  (tbl) => OrderingTerm.asc(tbl.chatJid),
                ]))
              .get();
      final keeper = await _preferredSingleContextEmailChatAccount(rows);
      if (keeper == null) {
        continue;
      }
      for (final row in rows) {
        if (row == keeper) {
          continue;
        }
        await (delete(emailChatAccounts)..where(
              (tbl) =>
                  tbl.chatJid.equals(row.chatJid) &
                  tbl.deltaAccountId.equals(row.deltaAccountId) &
                  tbl.deltaChatId.equals(row.deltaChatId),
            ))
            .go();
        changed++;
      }
    }
    final rows =
        await (select(emailChatAccounts)..where(
              (tbl) => tbl.deltaAccountId.isNotValue(
                DeltaAccountDefaults.singleContextId,
              ),
            ))
            .get();
    for (final row in rows) {
      await (delete(emailChatAccounts)..where(
            (tbl) =>
                tbl.chatJid.equals(row.chatJid) &
                tbl.deltaAccountId.equals(row.deltaAccountId) &
                tbl.deltaChatId.equals(row.deltaChatId),
          ))
          .go();
      await into(emailChatAccounts).insert(
        row.copyWith(deltaAccountId: DeltaAccountDefaults.singleContextId),
        mode: InsertMode.insertOrIgnore,
      );
    }
    return changed + rows.length;
  }

  Future<EmailChatAccountData?> _preferredSingleContextEmailChatAccount(
    List<EmailChatAccountData> rows,
  ) async {
    if (rows.isEmpty) {
      return null;
    }
    final chatBacked = <EmailChatAccountData>[];
    for (final row in rows) {
      if (await _emailChatAccountMatchesChatRow(row)) {
        chatBacked.add(row);
      }
    }
    final messageBacked = <EmailChatAccountData>[];
    for (final row in rows) {
      if (await _emailChatAccountHasStoredMessages(row)) {
        messageBacked.add(row);
      }
    }
    return _uniqueEmailChatAccountBy(chatBacked, (_) => true) ??
        _uniqueEmailChatAccountBy(messageBacked, (_) => true) ??
        _uniqueEmailChatAccountBy(
          rows,
          (row) => row.deltaAccountId == DeltaAccountDefaults.singleContextId,
        ) ??
        rows.first;
  }

  Future<bool> _emailChatAccountMatchesChatRow(EmailChatAccountData row) async {
    final chat = await getChat(row.chatJid);
    return chat?.deltaChatId == row.deltaChatId;
  }

  Future<bool> _emailChatAccountHasStoredMessages(
    EmailChatAccountData row,
  ) async {
    final messageCount = countAll();
    final query = selectOnly(messages)
      ..addColumns([messageCount])
      ..where(
        messages.chatJid.equals(row.chatJid) &
            messages.deltaChatId.equals(row.deltaChatId),
      );
    return ((await query.getSingle()).read(messageCount) ?? 0) > 0;
  }

  EmailChatAccountData? _uniqueEmailChatAccountBy(
    List<EmailChatAccountData> rows,
    bool Function(EmailChatAccountData row) predicate,
  ) {
    EmailChatAccountData? match;
    for (final row in rows) {
      if (!predicate(row)) {
        continue;
      }
      if (match != null) {
        return null;
      }
      match = row;
    }
    return match;
  }

  Future<int> _normalizeEmailTrustedContactKeysForSingleContext() async {
    final count = countAll();
    final duplicateGroups = selectOnly(emailTrustedContactKeys)
      ..addColumns([emailTrustedContactKeys.address, count])
      ..groupBy([
        emailTrustedContactKeys.address,
      ], having: count.isBiggerThanValue(1));
    final groups = await duplicateGroups.get();
    var changed = 0;
    for (final group in groups) {
      final address = group.read(emailTrustedContactKeys.address);
      if (address == null) {
        continue;
      }
      final rows =
          await (select(emailTrustedContactKeys)
                ..where((tbl) => tbl.address.equals(address))
                ..orderBy([
                  (tbl) => OrderingTerm.desc(
                    tbl.deltaAccountId.equals(
                      DeltaAccountDefaults.singleContextId,
                    ),
                  ),
                  (tbl) => OrderingTerm.desc(tbl.importedAt),
                ]))
              .get();
      final keeper = rows.firstOrNull;
      if (keeper == null) {
        continue;
      }
      for (final row in rows.skip(1)) {
        await (delete(emailTrustedContactKeys)..where(
              (tbl) =>
                  tbl.deltaAccountId.equals(row.deltaAccountId) &
                  tbl.address.equals(row.address),
            ))
            .go();
        changed++;
      }
    }
    final rows =
        await (select(emailTrustedContactKeys)..where(
              (tbl) => tbl.deltaAccountId.isNotValue(
                DeltaAccountDefaults.singleContextId,
              ),
            ))
            .get();
    for (final row in rows) {
      await (delete(emailTrustedContactKeys)..where(
            (tbl) =>
                tbl.deltaAccountId.equals(row.deltaAccountId) &
                tbl.address.equals(row.address),
          ))
          .go();
      await into(emailTrustedContactKeys).insert(
        row.copyWith(deltaAccountId: DeltaAccountDefaults.singleContextId),
        mode: InsertMode.insertOrIgnore,
      );
    }
    return changed + rows.length;
  }

  Message? _legacyDeltaDuplicateKeeper({
    required Message legacyRow,
    required List<Message> canonicalRows,
  }) {
    if (canonicalRows.isEmpty) {
      return null;
    }
    final exactMatches = canonicalRows
        .where(
          (row) =>
              row.chatJid == legacyRow.chatJid &&
              row.deltaChatId == legacyRow.deltaChatId,
        )
        .toList(growable: false);
    const singleMatchCount = 1;
    if (exactMatches.length == singleMatchCount) {
      return exactMatches.single;
    }
    if (canonicalRows.length == singleMatchCount) {
      final keeper = canonicalRows.single;
      if (_legacyDeltaDuplicateRowsMatch(
        legacyRow: legacyRow,
        keeper: keeper,
      )) {
        return keeper;
      }
    }
    return null;
  }

  bool _legacyDeltaDuplicateRowsMatch({
    required Message legacyRow,
    required Message keeper,
  }) {
    if (legacyRow.chatJid == keeper.chatJid) {
      return true;
    }
    final legacyDeltaChatId = legacyRow.deltaChatId;
    if (legacyDeltaChatId != null && legacyDeltaChatId == keeper.deltaChatId) {
      return true;
    }
    final legacyOrigin = normalizeEmailMessageId(legacyRow.originID);
    return legacyOrigin != null &&
        legacyOrigin == normalizeEmailMessageId(keeper.originID);
  }

  Future<int> _deleteExtraDeltaPairRows({
    required int? deltaAccountId,
    required int? deltaMsgId,
    required Set<String> affectedChatJids,
  }) async {
    if (deltaAccountId == null || deltaMsgId == null) {
      return 0;
    }
    final rows =
        await (select(messages)
              ..where(
                (tbl) =>
                    tbl.deltaAccountId.equals(deltaAccountId) &
                    tbl.deltaMsgId.equals(deltaMsgId),
              )
              ..orderBy([
                (tbl) => OrderingTerm.asc(tbl.timestamp),
                (tbl) => OrderingTerm.asc(tbl.stanzaID),
              ]))
            .get();
    if (rows.length < 2) {
      return 0;
    }
    for (final row in rows) {
      affectedChatJids.add(row.chatJid);
    }
    final keeper = await _preferredSingleContextDeltaMessage(rows);
    var removed = 0;
    if (keeper == null) {
      for (final row in rows) {
        await _clearAmbiguousDuplicateDeltaLocator(row);
      }
      return rows.length;
    }
    for (final extra in rows) {
      if (extra.stanzaID == keeper.stanzaID) {
        continue;
      }
      if (!await _singleContextDeltaRowsAreProvenDuplicates(
        first: extra,
        second: keeper,
      )) {
        await _clearAmbiguousDuplicateDeltaLocator(extra);
        removed++;
        continue;
      }
      if (extra.chatJid != keeper.chatJid) {
        await _migrateMembershipChatJid(
          message: extra,
          fromChatJid: extra.chatJid,
          toChatJid: keeper.chatJid,
        );
      } else {
        final keeperReference = keeper.originID ?? keeper.stanzaID;
        await rebindMessageCollectionMembershipReferences(
          chatJid: keeper.chatJid,
          oldReferenceId: extra.stanzaID,
          newReferenceId: keeperReference,
        );
      }
      await _migratePinsToKeeper(extra: extra, keeper: keeper);
      await _migrateAttachmentsToKeeper(extra: extra, keeper: keeper);
      await _migrateReactionsToKeeper(extra: extra, keeper: keeper);
      await _deleteMessageRowWithDependents(extra);
      removed++;
    }
    return removed;
  }

  Future<String?> _emailChatAccountJid({
    required int deltaAccountId,
    required int deltaChatId,
  }) async {
    final query = select(emailChatAccounts)
      ..where(
        (tbl) =>
            tbl.deltaAccountId.equals(deltaAccountId) &
            tbl.deltaChatId.equals(deltaChatId),
      )
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row?.chatJid;
  }

  Future<void> _deleteMessageRowWithDependents(Message extra) async {
    await reactionsAccessor.deleteByMessage(extra.stanzaID);
    await reactionsAccessor.deleteStatesByMessage(extra.stanzaID);
    final attachmentOwnerIds = <String>{extra.stanzaID};
    final rowId = extra.id?.trim();
    if (rowId != null && rowId.isNotEmpty) {
      attachmentOwnerIds.add(rowId);
    }
    final metadataIds = <String>{};
    for (final ownerId in attachmentOwnerIds) {
      metadataIds.addAll(await deleteMessageAttachments(ownerId));
    }
    for (final metadataId in metadataIds) {
      await _deleteFileMetadataIfOrphaned(metadataId);
    }
    await (delete(
      messages,
    )..where((tbl) => tbl.stanzaID.equals(extra.stanzaID))).go();
  }

  Future<void> migrateMessageIdentityToLadder() async {
    final (scopedByMapping, ambiguousKeys) =
        await _backfillDeltaChatScopeFromAccountMappings();
    final scopedByChat = await _backfillDeltaChatScopeFromChatRows(
      ambiguousKeys,
    );
    final unresolvable = await _countUnscopedEmailMessageRows();
    final nonWireMembershipsRepaired =
        await _repairNonWireEmailMembershipRows();
    final rewritten = await _rewriteEmailOriginIdsToGenuine();
    final membershipsRepaired =
        nonWireMembershipsRepaired +
        await _repairForeignCollectionMembershipHandles();
    _log.info(
      'Message identity migration: scopedByMapping=$scopedByMapping '
      'scopedByChat=$scopedByChat unresolvable=$unresolvable '
      'originIdsRewritten=$rewritten '
      'membershipsRepaired=$membershipsRepaired',
    );
  }

  Future<int> _repairForeignCollectionMembershipHandles() async {
    final entries = await (select(
      messageCollectionMemberships,
    )..where((tbl) => tbl.deltaMsgId.isNotNull())).get();
    var repaired = 0;
    for (final entry in entries) {
      final matching = await getMessageByDeltaId(
        entry.deltaMsgId!,
        deltaAccountId: entry.deltaAccountId,
        chatJid: entry.chatJid,
      );
      if (matching != null &&
          (_membershipReferencesMessage(entry, matching) ||
              _membershipIsNonWireEmailReference(entry, matching))) {
        await _normalizeEmailMembershipIdentity(
          entry: entry,
          message: matching,
        );
        continue;
      }
      await _clearCollectionMembershipHandles(entry);
      repaired++;
    }
    return repaired;
  }

  bool _membershipIsNonWireEmailReference(
    MessageCollectionMembershipEntry entry,
    Message message,
  ) {
    final reference = entry.messageReferenceId.trim();
    return message.isEmailBacked &&
        (isDerivedEmailMessageKey(reference) ||
            isDeltaGeneratedMessageId(reference));
  }

  bool _membershipReferencesMessage(
    MessageCollectionMembershipEntry entry,
    Message message,
  ) {
    final candidates = <String>{
      ?message.originID?.trim(),
      message.stanzaID.trim(),
      ?message.mucStanzaId?.trim(),
    }..removeWhere((value) => value.isEmpty);
    if (candidates.contains(entry.messageReferenceId.trim())) {
      return true;
    }
    final entryOrigin = entry.messageOriginId?.trim();
    return entryOrigin != null &&
        entryOrigin.isNotEmpty &&
        candidates.contains(entryOrigin);
  }

  Future<bool> _normalizeEmailMembershipIdentity({
    required MessageCollectionMembershipEntry entry,
    required Message message,
  }) async {
    var normalized = false;
    if (entry.messageStanzaId != null) {
      await (update(messageCollectionMemberships)..where(
            (tbl) =>
                tbl.collectionId.equals(entry.collectionId) &
                tbl.chatJid.equals(entry.chatJid) &
                tbl.messageReferenceId.equals(entry.messageReferenceId),
          ))
          .write(
            const MessageCollectionMembershipsCompanion(
              messageStanzaId: Value(null),
            ),
          );
      normalized = true;
    }
    final origin = genuineEmailMessageId(message.originID);
    final reference = entry.messageReferenceId.trim();
    final referenceIsNonPortable =
        isDeviceLocalDeltaStanzaId(reference) ||
        isDeltaGeneratedMessageId(reference) ||
        isDerivedEmailMessageKey(reference);
    if (origin == null ||
        origin.isEmpty ||
        reference == origin ||
        !referenceIsNonPortable) {
      return normalized;
    }
    await _rebindMembershipEntryReference(
      entry: entry,
      chatJid: entry.chatJid,
      oldReferenceId: entry.messageReferenceId,
      newReferenceId: origin,
    );
    return true;
  }

  Future<void> _clearCollectionMembershipHandles(
    MessageCollectionMembershipEntry entry,
  ) async {
    final query = update(messageCollectionMemberships)
      ..where(
        (tbl) =>
            tbl.collectionId.equals(entry.collectionId) &
            tbl.chatJid.equals(entry.chatJid) &
            tbl.messageReferenceId.equals(entry.messageReferenceId),
      );
    await query.write(
      const MessageCollectionMembershipsCompanion(
        deltaAccountId: Value(null),
        deltaMsgId: Value(null),
        messageStanzaId: Value(null),
      ),
    );
  }

  Future<(int, Set<(String, int)>)>
  _backfillDeltaChatScopeFromAccountMappings() async {
    final mappings = await select(emailChatAccounts).get();
    final byKey = <(String, int), Set<int>>{};
    for (final mapping in mappings) {
      byKey
          .putIfAbsent((mapping.chatJid, mapping.deltaAccountId), () => <int>{})
          .add(mapping.deltaChatId);
    }
    var updated = 0;
    final ambiguous = <(String, int)>{};
    for (final entry in byKey.entries) {
      if (entry.value.length != 1) {
        ambiguous.add(entry.key);
        continue;
      }
      updated += await _scopeUnscopedEmailRows(
        chatJid: entry.key.$1,
        deltaAccountId: entry.key.$2,
        deltaChatId: entry.value.single,
      );
    }
    return (updated, ambiguous);
  }

  Future<int> _scopeUnscopedEmailRows({
    required String chatJid,
    required int deltaAccountId,
    required int deltaChatId,
  }) {
    final query = update(messages)
      ..where(
        (tbl) =>
            tbl.chatJid.equals(chatJid) &
            tbl.deltaAccountId.equals(deltaAccountId) &
            tbl.deltaMsgId.isNotNull() &
            tbl.deltaChatId.isNull(),
      );
    return query.write(MessagesCompanion(deltaChatId: Value(deltaChatId)));
  }

  Future<int> _backfillDeltaChatScopeFromChatRows(
    Set<(String, int)> ambiguousKeys,
  ) async {
    final chatRows = await (select(
      chats,
    )..where((tbl) => tbl.deltaChatId.isNotNull())).get();
    var updated = 0;
    for (final chat in chatRows) {
      final mapped = chat.deltaChatId;
      if (mapped == null) {
        continue;
      }
      final accountIds = await _emailAccountIdsForChatJid(chat.jid);
      if (accountIds.length != 1) {
        continue;
      }
      final accountId = accountIds.single;
      if (ambiguousKeys.contains((chat.jid, accountId))) {
        continue;
      }
      final query = update(messages)
        ..where(
          (tbl) =>
              tbl.chatJid.equals(chat.jid) &
              tbl.deltaAccountId.equals(accountId) &
              tbl.deltaMsgId.isNotNull() &
              tbl.deltaChatId.isNull(),
        );
      updated += await query.write(
        MessagesCompanion(deltaChatId: Value(mapped)),
      );
    }
    return updated;
  }

  Future<List<int>> _emailAccountIdsForChatJid(String chatJid) async {
    final query = selectOnly(messages, distinct: true)
      ..addColumns([messages.deltaAccountId])
      ..where(
        messages.chatJid.equals(chatJid) & messages.deltaMsgId.isNotNull(),
      );
    final rows = await query.get();
    return rows
        .map((row) => row.read(messages.deltaAccountId))
        .whereType<int>()
        .toList(growable: false);
  }

  Future<int> _countUnscopedEmailMessageRows() async {
    final count = countAll();
    final query = selectOnly(messages)
      ..addColumns([count])
      ..where(messages.deltaMsgId.isNotNull() & messages.deltaChatId.isNull());
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> _rewriteEmailOriginIdsToGenuine() async {
    const int pageSize = 500;
    var rewritten = 0;
    String? lastStanzaId;
    while (true) {
      final rows = await _emailIdentityRewritePage(
        afterStanzaId: lastStanzaId,
        pageSize: pageSize,
      );
      if (rows.isEmpty) {
        break;
      }
      for (final row in rows) {
        if (await _rewriteEmailOriginIdRow(row)) {
          rewritten++;
        }
        lastStanzaId = row.read(messages.stanzaID);
      }
      if (rows.length < pageSize) {
        break;
      }
    }
    return rewritten;
  }

  Future<List<TypedResult>> _emailIdentityRewritePage({
    required String? afterStanzaId,
    required int pageSize,
  }) {
    Expression<bool> predicate = messages.deltaMsgId.isNotNull();
    if (afterStanzaId != null) {
      predicate =
          predicate & messages.stanzaID.isBiggerThanValue(afterStanzaId);
    }
    final query = selectOnly(messages)
      ..addColumns([messages.stanzaID, messages.originID])
      ..where(predicate)
      ..orderBy([OrderingTerm.asc(messages.stanzaID)])
      ..limit(pageSize);
    return query.get();
  }

  Future<bool> _rewriteEmailOriginIdRow(TypedResult row) async {
    final stanzaId = row.read(messages.stanzaID);
    if (stanzaId == null) {
      return false;
    }
    final storedOrigin = row.read(messages.originID);
    final genuine = genuineEmailMessageId(storedOrigin);
    if (genuine == storedOrigin) {
      return false;
    }
    await (update(messages)..where((tbl) => tbl.stanzaID.equals(stanzaId)))
        .write(MessagesCompanion(originID: Value(genuine)));
    return true;
  }

  Future<void> retireDerivedEmailOriginIds() async {
    final repairedMemberships = await _repairNonWireEmailMembershipRows();
    final rewritten = await _rewriteEmailOriginIdsToGenuine();
    _log.info(
      'Retired derived email origins: originIdsRewritten=$rewritten '
      'membershipsRepaired=$repairedMemberships',
    );
  }

  Future<int> _repairNonWireEmailMembershipRows() async {
    final entries = await select(messageCollectionMemberships).get();
    var repaired = 0;
    for (final entry in entries) {
      final reference = entry.messageReferenceId.trim();
      if (!isDerivedEmailMessageKey(reference) &&
          !isDeltaGeneratedMessageId(reference)) {
        continue;
      }
      final message = await _emailMessageForNonWireMembership(entry);
      if (message == null) {
        continue;
      }
      if (await _repairNonWireEmailMembershipRow(
        entry: entry,
        message: message,
      )) {
        repaired++;
      }
    }
    return repaired;
  }

  Future<Message?> _emailMessageForNonWireMembership(
    MessageCollectionMembershipEntry entry,
  ) async {
    final deltaMsgId = entry.deltaMsgId;
    if (deltaMsgId != null) {
      final matching = await getMessageByDeltaId(
        deltaMsgId,
        deltaAccountId: entry.deltaAccountId ?? DeltaAccountDefaults.legacyId,
        chatJid: entry.chatJid,
      );
      if (matching?.isEmailBacked == true) {
        return matching;
      }
    }
    final rawReferences = <String>{
      entry.messageReferenceId.trim(),
      ?entry.messageStanzaId?.trim(),
      ?entry.messageOriginId?.trim(),
      ?entry.messageMucStanzaId?.trim(),
    }..removeWhere((value) => value.isEmpty);
    final references = <String>{};
    for (final reference in rawReferences) {
      references.add(reference);
      final normalized = normalizeEmailMessageId(reference);
      if (normalized != null) {
        references.add(normalized);
      }
    }
    if (references.isEmpty) {
      return null;
    }
    final query = select(messages)
      ..where(
        (tbl) =>
            tbl.chatJid.equals(entry.chatJid) &
            tbl.deltaMsgId.isNotNull() &
            (tbl.stanzaID.isIn(references) |
                tbl.originID.isIn(references) |
                tbl.mucStanzaId.isIn(references)),
      )
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.timestamp),
        (tbl) => OrderingTerm.asc(tbl.stanzaID),
      ])
      ..limit(2);
    final matches = await query.get();
    if (matches.length != 1) {
      return null;
    }
    final matching = matches.single;
    return matching.isEmailBacked ? matching : null;
  }

  Future<bool> _repairNonWireEmailMembershipRow({
    required MessageCollectionMembershipEntry entry,
    required Message message,
  }) async {
    var repaired = false;
    final deltaMsgId = message.deltaMsgId;
    if (deltaMsgId != null &&
        (entry.deltaMsgId != deltaMsgId ||
            entry.deltaAccountId != message.deltaAccountId)) {
      await (update(messageCollectionMemberships)..where(
            (tbl) =>
                tbl.collectionId.equals(entry.collectionId) &
                tbl.chatJid.equals(entry.chatJid) &
                tbl.messageReferenceId.equals(entry.messageReferenceId),
          ))
          .write(
            MessageCollectionMembershipsCompanion(
              deltaAccountId: Value(message.deltaAccountId),
              deltaMsgId: Value(deltaMsgId),
            ),
          );
      repaired = true;
    }
    return await _normalizeEmailMembershipIdentity(
          entry: entry,
          message: message,
        ) ||
        repaired;
  }

  Future<void> repairGeneratedEmailAttachmentCaptionBodies() async {
    final candidates =
        await (select(messages)..where(
              (tbl) =>
                  tbl.fileMetadataID.isNotNull() &
                  tbl.pseudoMessageData.isNotNull(),
            ))
            .get();
    final chatJids = <String>{};
    for (final message in candidates) {
      if (!message.isEmailBacked) {
        continue;
      }
      if (!message.hasGeneratedEmailAttachmentCaption) {
        continue;
      }
      await (update(
        messages,
      )..where((tbl) => tbl.stanzaID.equals(message.stanzaID))).write(
        MessagesCompanion(
          pseudoMessageData: Value(
            _pseudoMessageDataWithoutGeneratedEmailAttachmentCaption(
              message.pseudoMessageData,
            ),
          ),
        ),
      );
      chatJids.add(message.chatJid);
    }
    for (final chatJid in chatJids) {
      await repairChatSummaryFromMessages(chatJid);
    }
  }

  Map<String, dynamic>?
  _pseudoMessageDataWithoutGeneratedEmailAttachmentCaption(
    Map<String, dynamic>? pseudoMessageData,
  ) {
    if (pseudoMessageData?['emailAttachmentCaption'] != true) {
      return pseudoMessageData;
    }
    final updated = Map<String, dynamic>.from(pseudoMessageData!)
      ..remove('emailAttachmentCaption');
    return updated.isEmpty ? null : updated;
  }

  @override
  Future<void> repairChatSummaryFromMessages(
    String jid, {
    bool clearStaleLastMessage = false,
  }) async {
    const summaryFilter = MessageTimelineFilter.allWithContact;
    final chat = await getChat(jid);
    if (chat == null) {
      return;
    }
    final lastMessage = await getLastMessageForChat(jid, filter: summaryFilter);
    if (lastMessage == null) {
      if (clearStaleLastMessage && chat.lastMessage != null) {
        await (update(chats)..where((tbl) => tbl.jid.equals(jid))).write(
          const ChatsCompanion(lastMessage: Value(null)),
        );
      }
      return;
    }
    final timestamp = lastMessage.timestamp;
    if (timestamp == null || timestamp.isBefore(chat.lastChangeTimestamp)) {
      return;
    }
    final lastMessagePreview = await _messagePreview(
      trimmedBody: lastMessage.body?.trim(),
      subject: lastMessage.subject,
      deltaChatId: lastMessage.deltaChatId,
      deltaMsgId: lastMessage.deltaMsgId,
      fileMetadataId: lastMessage.fileMetadataID,
      hasAttachment: lastMessage.fileMetadataID?.isNotEmpty == true,
      pseudoMessageType: lastMessage.pseudoMessageType,
      pseudoMessageData: lastMessage.pseudoMessageData,
    );
    final updated = chat.copyWith(
      lastMessage: lastMessagePreview,
      lastChangeTimestamp: timestamp,
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
    final normalizedJid = jid.trim();
    final closed = await transaction(() async {
      final closed = await closeChat();
      final existing = await getChat(normalizedJid);
      if (existing == null) {
        final emptyTimestamp = DateTime.fromMillisecondsSinceEpoch(
          _emptyTimestampMillis,
        );
        await into(chats).insert(
          ChatsCompanion.insert(
            jid: normalizedJid,
            title: _chatTitleForIdentifier(normalizedJid),
            type: ChatType.chat,
            open: const Value(true),
            unreadCount: const Value(0),
            chatState: const Value(mox.ChatState.active),
            lastChangeTimestamp: emptyTimestamp,
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
    try {
      await repairChatSummaryFromMessages(
        normalizedJid,
        clearStaleLastMessage: true,
      );
    } on Exception catch (error, stackTrace) {
      _log.fine(
        'Chat summary repair failed while opening chat.',
        error,
        stackTrace,
      );
    }
    return closed;
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
        await _unarchiveChatThread(chat);
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
    });
  }

  String _generateArchivedJid(String canonicalJid) {
    final timestamp = DateTime.timestamp().microsecondsSinceEpoch;
    return '$canonicalJid--arch--${timestamp.toRadixString(16)}';
  }

  String? _archivedJidBase(String jid) {
    final normalizedJid = normalizeAddress(jid);
    if (normalizedJid == null) {
      return null;
    }
    final archiveMatch = RegExp(
      r'^(.*)--arch--[0-9a-f]+$',
      caseSensitive: false,
    ).firstMatch(normalizedJid);
    final canonicalJid = archiveMatch?.group(1);
    if (canonicalJid == null || canonicalJid.isEmpty) {
      return null;
    }
    return canonicalJid;
  }

  String _canonicalJidForArchivedChat(Chat chat) {
    final contactJid = normalizeAddress(chat.contactJid);
    if (contactJid != null) {
      return contactJid;
    }
    return _archivedJidBase(chat.jid) ?? normalizeAddress(chat.jid) ?? chat.jid;
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
    await _retargetChatThreadReferences(fromJid: chat.jid, toJid: archivedJid);
    await (delete(chats)..where((tbl) => tbl.jid.equals(chat.jid))).go();
  }

  Future<void> _unarchiveChatThread(Chat chat) async {
    final canonicalJid = _canonicalJidForArchivedChat(chat);
    if (canonicalJid == chat.jid) {
      await (update(chats)..where((tbl) => tbl.jid.equals(chat.jid))).write(
        ChatsCompanion(
          archived: const Value(false),
          contactJid: Value(canonicalJid),
        ),
      );
      return;
    }
    final existing = await chatsAccessor.selectOne(canonicalJid);
    if (existing == null) {
      await chatsAccessor.insertOne(
        chat.copyWith(
          jid: canonicalJid,
          contactJid: canonicalJid,
          archived: false,
        ),
      );
    } else {
      await (update(chats)..where((tbl) => tbl.jid.equals(canonicalJid))).write(
        ChatsCompanion(
          contactJid: Value(canonicalJid),
          archived: const Value(false),
        ),
      );
    }
    await _retargetChatThreadReferences(fromJid: chat.jid, toJid: canonicalJid);
    await (delete(chats)..where((tbl) => tbl.jid.equals(chat.jid))).go();
    await _refreshChatSummaryAfterMessageRemoval(jid: canonicalJid);
  }

  Future<void> _retargetChatThreadReferences({
    required String fromJid,
    required String toJid,
  }) async {
    await _retargetEmailChatAccounts(fromJid: fromJid, toJid: toJid);
    await (update(messages)..where((tbl) => tbl.chatJid.equals(fromJid))).write(
      MessagesCompanion(chatJid: Value(toJid)),
    );
    await (update(notifications)..where((tbl) => tbl.chatJid.equals(fromJid)))
        .write(NotificationsCompanion(chatJid: Value(toJid)));
    await _retargetDraftsForChat(fromJid: fromJid, toJid: toJid);
  }

  Future<void> _retargetEmailChatAccounts({
    required String fromJid,
    required String toJid,
  }) async {
    final accounts = await (select(
      emailChatAccounts,
    )..where((tbl) => tbl.chatJid.equals(fromJid))).get();
    for (final account in accounts) {
      final target =
          await (select(emailChatAccounts)..where(
                (tbl) =>
                    tbl.chatJid.equals(toJid) &
                    tbl.deltaAccountId.equals(account.deltaAccountId) &
                    tbl.deltaChatId.equals(account.deltaChatId),
              ))
              .getSingleOrNull();
      final source = delete(emailChatAccounts)
        ..where(
          (tbl) =>
              tbl.chatJid.equals(fromJid) &
              tbl.deltaAccountId.equals(account.deltaAccountId) &
              tbl.deltaChatId.equals(account.deltaChatId),
        );
      if (target != null) {
        await source.go();
        continue;
      }
      await (update(emailChatAccounts)..where(
            (tbl) =>
                tbl.chatJid.equals(fromJid) &
                tbl.deltaAccountId.equals(account.deltaAccountId) &
                tbl.deltaChatId.equals(account.deltaChatId),
          ))
          .write(EmailChatAccountsCompanion(chatJid: Value(toJid)));
    }
  }

  Future<void> _repairRestoredArchiveJids() async {
    final restoredChats =
        await (select(chats)..where(
              (tbl) =>
                  tbl.archived.equals(false) &
                  tbl.contactJid.isNotNull() &
                  tbl.jid.like('%--arch--%'),
            ))
            .get();
    for (final chat in restoredChats) {
      final canonicalJid = _archivedJidBase(chat.jid);
      final contactJid = normalizeAddress(chat.contactJid);
      if (canonicalJid == null ||
          contactJid == null ||
          canonicalJid != contactJid) {
        continue;
      }
      await transaction(() => _unarchiveChatThread(chat));
    }
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
  Future<void> replaceAvatarReferencesForPath({
    required String oldPath,
    required String newPath,
  }) async {
    final normalizedOldPath = oldPath.trim();
    final normalizedNewPath = newPath.trim();
    if (normalizedOldPath.isEmpty || normalizedNewPath.isEmpty) return;
    if (normalizedOldPath == normalizedNewPath) return;

    await transaction(() async {
      await (update(roster)
            ..where((tbl) => tbl.avatarPath.equals(normalizedOldPath)))
          .write(RosterCompanion(avatarPath: Value(normalizedNewPath)));
      await (update(roster)
            ..where((tbl) => tbl.contactAvatarPath.equals(normalizedOldPath)))
          .write(RosterCompanion(contactAvatarPath: Value(normalizedNewPath)));
      await (update(chats)
            ..where((tbl) => tbl.avatarPath.equals(normalizedOldPath)))
          .write(ChatsCompanion(avatarPath: Value(normalizedNewPath)));
      await (update(chats)
            ..where((tbl) => tbl.contactAvatarPath.equals(normalizedOldPath)))
          .write(ChatsCompanion(contactAvatarPath: Value(normalizedNewPath)));
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
      await _markDirectChatsXmppCapable([item.jid]);
      await rosterAccessor.insertOrUpdateOne(item);
      await invitesAccessor.deleteOne(item.jid);
    });
  }

  @override
  Future<void> saveRosterItemOnly(RosterItem item) async {
    _log.info('Saving roster item without creating chat');
    await transaction(() async {
      await _markDirectChatsXmppCapable([item.jid]);
      await rosterAccessor.insertOrUpdateOne(item);
      await invitesAccessor.deleteOne(item.jid);
    });
  }

  @override
  Future<void> saveRosterItemsOnly(List<RosterItem> items) async {
    if (items.isEmpty) return;
    await transaction(() async {
      await batch((batch) {
        batch.insertAll(roster, items, mode: InsertMode.insertOrReplace);
      });
      final jids = items.map((item) => item.jid).toList(growable: false);
      await _markDirectChatsXmppCapable(jids);
      for (final batch in _chunked(jids, batchSize: 900)) {
        await (delete(invites)..where((tbl) => tbl.jid.isIn(batch))).go();
      }
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
      await _markDirectChatsXmppCapable(jids);
      for (final batch in _chunked(jids, batchSize: 900)) {
        await (delete(invites)..where((tbl) => tbl.jid.isIn(batch))).go();
      }
    });
  }

  @override
  Future<void> updateRosterItem(RosterItem item) async {
    _log.info('Updating roster item');
    await transaction(() async {
      await _markDirectChatsXmppCapable([item.jid]);
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
      await _markDirectChatsXmppCapable(jids);
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
  Stream<List<Contact>> watchSavedEmailContacts() =>
      contactsAccessor.watchAll();

  @override
  Future<List<Contact>> getSavedEmailContacts() => contactsAccessor.selectAll();

  @override
  Future<void> replaceContacts(Iterable<Contact> contacts) async {
    await transaction(() async {
      final existing = await select(this.contacts).get();
      final existingById = <String, String>{
        for (final entry in existing)
          if (entry.nativeID != null && entry.nativeID!.isNotEmpty)
            entry.nativeID!: entry.jid,
      };
      final existingDisplayNamesById = <String, String?>{
        for (final entry in existing)
          if (entry.nativeID != null && entry.nativeID!.isNotEmpty)
            entry.nativeID!: entry.providedDisplayName?.trim(),
      };
      final contactsByNativeId = <String, Contact>{
        for (final entry in contacts)
          if (entry.nativeID?.trim().isNotEmpty == true)
            entry.nativeID!.trim(): entry,
      };
      final toDelete = existingById.keys
          .where((id) => !contactsByNativeId.containsKey(id))
          .toList();
      if (toDelete.isNotEmpty) {
        for (final batch in _chunked(toDelete, batchSize: 900)) {
          await (delete(
            this.contacts,
          )..where((tbl) => tbl.nativeID.isIn(batch))).go();
        }
      }
      final upserts = <ContactsCompanion>[];
      for (final entry in contactsByNativeId.entries) {
        final value = entry.value;
        final existingJid = existingById[entry.key];
        final nextAddress = value.resolvedAddress;
        if (nextAddress == null || nextAddress.isEmpty) {
          continue;
        }
        final nextDisplayName = value.providedDisplayName?.trim();
        if (existingJid == nextAddress &&
            existingDisplayNamesById[entry.key] == nextDisplayName) {
          continue;
        }
        upserts.add(
          ContactsCompanion.insert(
            nativeID: entry.key,
            jid: nextAddress,
            displayName: Value(nextDisplayName),
          ),
        );
      }
      if (upserts.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            this.contacts,
            upserts,
            mode: InsertMode.insertOrReplace,
          );
        });
      }
    });
  }

  @override
  Stream<List<ContactDirectoryEntry>> watchContactDirectoryEntries() {
    late final StreamController<List<ContactDirectoryEntry>> controller;
    final subscriptions = <StreamSubscription<Object?>>[];
    List<ContactDirectoryEntry>? lastItems;
    var emitting = false;
    var pending = false;

    Future<void> emitDirectory() async {
      if (emitting) {
        pending = true;
        return;
      }
      emitting = true;
      try {
        do {
          pending = false;
          final items = await getContactDirectoryEntries();
          if (!listEquals(lastItems, items)) {
            lastItems = items;
            if (!controller.isClosed) {
              controller.add(items);
            }
          }
        } while (pending);
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        emitting = false;
      }
    }

    controller = StreamController<List<ContactDirectoryEntry>>(
      onListen: () {
        subscriptions
          ..add(select(roster).watch().listen((_) => emitDirectory()))
          ..add(select(contacts).watch().listen((_) => emitDirectory()))
          ..add(
            select(
              privateContactRecords,
            ).watch().listen((_) => emitDirectory()),
          )
          ..add(
            select(
              privateContactDetailFields,
            ).watch().listen((_) => emitDirectory()),
          )
          ..add(select(chats).watch().listen((_) => emitDirectory()));
        unawaited(emitDirectory());
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions.clear();
      },
    );
    return controller.stream;
  }

  @override
  Future<List<ContactDirectoryEntry>> getContactDirectoryEntries() async {
    return _mergeContactDirectoryEntries(
      await rosterAccessor.selectAll(),
      await contactsAccessor.selectAll(),
      await getPrivateContactRecords(),
      await _getPrivateContactDetailFieldsByAddress(),
      await getChats(start: 0, end: 0),
    );
  }

  @override
  Stream<List<ContactPreference>> watchContactPreferences() {
    final query = select(privateContactRecords)
      ..where((tbl) => tbl.active.equals(true));
    return query
        .watch()
        .map(_privateContactsAsPreferences)
        .distinct(listEquals);
  }

  @override
  Future<List<ContactPreference>> getContactPreferences() async =>
      _privateContactsAsPreferences(await getPrivateContactRecords());

  @override
  Future<List<PrivateContactRecord>> getPrivateContactRecords({
    bool includeInactive = false,
  }) {
    final query = select(privateContactRecords);
    if (!includeInactive) {
      query.where((tbl) => tbl.active.equals(true));
    }
    return query.get();
  }

  @override
  Future<PrivateContactRecord?> getPrivateContactRecord(String addressKey) {
    final key = contactDirectoryAddressKey(addressKey);
    if (key.isEmpty) {
      return Future<PrivateContactRecord?>.value();
    }
    return (select(
      privateContactRecords,
    )..where((tbl) => tbl.addressKey.equals(key))).getSingleOrNull();
  }

  @override
  Future<List<ContactPreference>> getContactFolderRulePreferences({
    bool includeInactive = false,
  }) async {
    final entries =
        _privateContactsAsPreferences(
              await getPrivateContactRecords(includeInactive: true),
            )
            .where((entry) {
              return entry.folderCollectionId != null ||
                  entry.folderRuleUpdatedAt != null;
            })
            .toList(growable: false);
    if (includeInactive) {
      return entries;
    }
    return entries
        .where((entry) => entry.folderCollectionId?.trim().isNotEmpty == true)
        .toList(growable: false);
  }

  @override
  Stream<Map<String, String>> watchActiveContactFolderRules() {
    late final StreamController<Map<String, String>> controller;
    final subscriptions = <StreamSubscription<Object?>>[];
    Map<String, String>? lastRules;
    var emitting = false;
    var pending = false;

    Future<void> emitRules() async {
      if (emitting) {
        pending = true;
        return;
      }
      emitting = true;
      try {
        do {
          pending = false;
          final rules = await getActiveContactFolderRules();
          if (!mapEquals(lastRules, rules)) {
            lastRules = rules;
            if (!controller.isClosed) {
              controller.add(rules);
            }
          }
        } while (pending);
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        emitting = false;
      }
    }

    controller = StreamController<Map<String, String>>(
      onListen: () {
        subscriptions
          ..add(
            select(privateContactRecords).watch().listen((_) => emitRules()),
          )
          ..add(select(messageCollections).watch().listen((_) => emitRules()));
        unawaited(emitRules());
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions.clear();
      },
    );
    return controller.stream;
  }

  @override
  Future<Map<String, String>> getActiveContactFolderRules() async {
    final rules = <String, String>{};
    for (final record in await _activeContactFolderRuleRecords()) {
      final key = contactDirectoryAddressKey(record.addressKey);
      final collectionId = record.folderCollectionId?.trim();
      if (key.isEmpty || collectionId == null || collectionId.isEmpty) {
        continue;
      }
      rules[key] = collectionId;
    }
    return Map<String, String>.unmodifiable(rules);
  }

  Future<List<PrivateContactRecord>> _activeContactFolderRuleRecords({
    String? collectionId,
  }) async {
    final normalizedCollectionId = collectionId?.trim();
    final activeCollections = (await getMessageCollections(
      includeInactive: false,
    )).map((entry) => entry.id);
    final activeCollectionIds = activeCollections.toSet();
    if (activeCollectionIds.isEmpty) {
      return const <PrivateContactRecord>[];
    }
    final query = select(privateContactRecords)
      ..where(
        (tbl) => tbl.active.equals(true) & tbl.folderCollectionId.isNotNull(),
      );
    if (normalizedCollectionId != null && normalizedCollectionId.isNotEmpty) {
      query.where(
        (tbl) => tbl.folderCollectionId.equals(normalizedCollectionId),
      );
    }
    final records = await query.get();
    return records
        .where((record) {
          final ruleCollectionId = record.folderCollectionId?.trim();
          return ruleCollectionId != null &&
              ruleCollectionId.isNotEmpty &&
              activeCollectionIds.contains(ruleCollectionId);
        })
        .toList(growable: false);
  }

  @override
  Future<ContactPreference?> getContactPreference(String addressKey) {
    final key = contactDirectoryAddressKey(addressKey);
    if (key.isEmpty) {
      return Future<ContactPreference?>.value();
    }
    return getPrivateContactRecord(key).then(
      (record) => record == null ? null : _privateContactAsPreference(record),
    );
  }

  List<ContactPreference> _privateContactsAsPreferences(
    List<PrivateContactRecord> records,
  ) {
    return records.map(_privateContactAsPreference).toList(growable: false);
  }

  ContactPreference _privateContactAsPreference(PrivateContactRecord record) {
    return ContactPreference(
      addressKey: record.addressKey,
      favorited: record.active && record.favorited,
      displayNameOverride: record.active ? record.displayNameOverride : null,
      folderCollectionId: record.active ? record.folderCollectionId : null,
      folderRuleUpdatedAt: record.folderRuleUpdatedAt,
      updatedAt: record.updatedAt,
    );
  }

  bool _privateContactShouldRemainActive({
    required bool manual,
    required bool favorited,
    required String? displayNameOverride,
    required String? folderCollectionId,
  }) {
    return manual ||
        favorited ||
        _trimmedContactValue(displayNameOverride) != null ||
        _trimmedContactValue(folderCollectionId) != null;
  }

  Future<PrivateContactRecord> _writePrivateContactRecord({
    required String addressKey,
    required bool active,
    required bool manual,
    required bool favorited,
    required String? displayNameOverride,
    required String? folderCollectionId,
    required DateTime updatedAt,
    required DateTime? activeUpdatedAt,
    required DateTime? manualUpdatedAt,
    required DateTime? favoriteUpdatedAt,
    required DateTime? displayNameUpdatedAt,
    required DateTime? folderRuleUpdatedAt,
    String? sourceId,
  }) async {
    final key = contactDirectoryAddressKey(addressKey);
    final existing = await getPrivateContactRecord(key);
    final normalizedUpdatedAt = updatedAt.toUtc();
    final record = PrivateContactRecord(
      addressKey: key,
      active: active,
      manual: manual,
      favorited: favorited,
      displayNameOverride: _trimmedContactValue(displayNameOverride),
      folderCollectionId: _trimmedContactValue(folderCollectionId),
      activeUpdatedAt: activeUpdatedAt?.toUtc() ?? existing?.activeUpdatedAt,
      manualUpdatedAt: manualUpdatedAt?.toUtc() ?? existing?.manualUpdatedAt,
      favoriteUpdatedAt:
          favoriteUpdatedAt?.toUtc() ?? existing?.favoriteUpdatedAt,
      displayNameUpdatedAt:
          displayNameUpdatedAt?.toUtc() ?? existing?.displayNameUpdatedAt,
      folderRuleUpdatedAt:
          folderRuleUpdatedAt?.toUtc() ?? existing?.folderRuleUpdatedAt,
      createdAt: existing?.createdAt.toUtc() ?? normalizedUpdatedAt,
      updatedAt: normalizedUpdatedAt,
      sourceId: _trimmedContactValue(sourceId ?? existing?.sourceId),
    );
    await into(
      privateContactRecords,
    ).insertOnConflictUpdate(record.toCompanion(false));
    return record;
  }

  @override
  Future<void> setContactFavorited({
    required String addressKey,
    required bool favorited,
  }) async {
    final key = contactDirectoryAddressKey(addressKey);
    if (key.isEmpty) {
      return;
    }
    final now = DateTime.timestamp().toUtc();
    final existing = await getPrivateContactRecord(key);
    if (existing == null && !favorited) {
      return;
    }
    await _writePrivateContactRecord(
      addressKey: key,
      active: _privateContactShouldRemainActive(
        manual: existing?.manual ?? false,
        favorited: favorited,
        displayNameOverride: existing?.displayNameOverride,
        folderCollectionId: existing?.folderCollectionId,
      ),
      manual: existing?.manual ?? false,
      favorited: favorited,
      displayNameOverride: existing?.displayNameOverride,
      folderCollectionId: existing?.folderCollectionId,
      updatedAt: now,
      activeUpdatedAt: now,
      manualUpdatedAt: null,
      favoriteUpdatedAt: now,
      displayNameUpdatedAt: null,
      folderRuleUpdatedAt: null,
    );
  }

  @override
  Future<void> setContactDisplayNameOverride({
    required String addressKey,
    required String? displayName,
  }) async {
    final key = contactDirectoryAddressKey(addressKey);
    if (key.isEmpty) {
      return;
    }
    final trimmed = displayName?.trim();
    final now = DateTime.timestamp().toUtc();
    final existing = await getPrivateContactRecord(key);
    if ((trimmed == null || trimmed.isEmpty) && existing == null) {
      return;
    }
    await _writePrivateContactRecord(
      addressKey: key,
      active: _privateContactShouldRemainActive(
        manual: existing?.manual ?? false,
        favorited: existing?.favorited ?? false,
        displayNameOverride: trimmed,
        folderCollectionId: existing?.folderCollectionId,
      ),
      manual: existing?.manual ?? false,
      favorited: existing?.favorited ?? false,
      displayNameOverride: trimmed,
      folderCollectionId: existing?.folderCollectionId,
      updatedAt: now,
      activeUpdatedAt: now,
      manualUpdatedAt: null,
      favoriteUpdatedAt: null,
      displayNameUpdatedAt: now,
      folderRuleUpdatedAt: null,
    );
  }

  @override
  Future<void> setContactFolderRule({
    required String addressKey,
    required String collectionId,
  }) async {
    final key = contactDirectoryAddressKey(addressKey);
    final normalizedCollectionId = collectionId.trim();
    if (key.isEmpty || normalizedCollectionId.isEmpty) {
      return;
    }
    final now = DateTime.timestamp().toUtc();
    final existing = await getPrivateContactRecord(key);
    await _writePrivateContactRecord(
      addressKey: key,
      active: true,
      manual: existing?.manual ?? false,
      favorited: existing?.favorited ?? false,
      displayNameOverride: existing?.displayNameOverride,
      folderCollectionId: normalizedCollectionId,
      updatedAt: now,
      activeUpdatedAt: now,
      manualUpdatedAt: null,
      favoriteUpdatedAt: null,
      displayNameUpdatedAt: null,
      folderRuleUpdatedAt: now,
    );
  }

  @override
  Future<void> clearContactFolderRule({required String addressKey}) async {
    final key = contactDirectoryAddressKey(addressKey);
    if (key.isEmpty) {
      return;
    }
    final existing = await getPrivateContactRecord(key);
    if (existing == null) {
      return;
    }
    final now = DateTime.timestamp().toUtc();
    await _writePrivateContactRecord(
      addressKey: key,
      active: _privateContactShouldRemainActive(
        manual: existing.manual,
        favorited: existing.favorited,
        displayNameOverride: existing.displayNameOverride,
        folderCollectionId: null,
      ),
      manual: existing.manual,
      favorited: existing.favorited,
      displayNameOverride: existing.displayNameOverride,
      folderCollectionId: null,
      updatedAt: now,
      activeUpdatedAt: now,
      manualUpdatedAt: null,
      favoriteUpdatedAt: null,
      displayNameUpdatedAt: null,
      folderRuleUpdatedAt: now,
    );
  }

  @override
  Future<void> applyContactFolderRuleMutation({
    required String addressKey,
    required String? collectionId,
    required DateTime updatedAt,
    required bool active,
  }) async {
    final key = contactDirectoryAddressKey(addressKey);
    if (key.isEmpty) {
      return;
    }
    final normalizedUpdatedAt = updatedAt.toUtc();
    final normalizedCollectionId = collectionId?.trim();
    if (active) {
      if (normalizedCollectionId == null || normalizedCollectionId.isEmpty) {
        return;
      }
    }
    final existing = await getPrivateContactRecord(key);
    final existingRuleUpdatedAt =
        existing?.folderRuleUpdatedAt?.toUtc() ?? existing?.updatedAt.toUtc();
    if (existing != null &&
        existingRuleUpdatedAt != null &&
        !normalizedUpdatedAt.isAfter(existingRuleUpdatedAt)) {
      return;
    }
    final nextFolderCollectionId = active ? normalizedCollectionId : null;
    await _writePrivateContactRecord(
      addressKey: key,
      active:
          active ||
          _privateContactShouldRemainActive(
            manual: existing?.manual ?? false,
            favorited: existing?.favorited ?? false,
            displayNameOverride: existing?.displayNameOverride,
            folderCollectionId: nextFolderCollectionId,
          ),
      manual: existing?.manual ?? false,
      favorited: existing?.favorited ?? false,
      displayNameOverride: existing?.displayNameOverride,
      folderCollectionId: nextFolderCollectionId,
      updatedAt: normalizedUpdatedAt,
      activeUpdatedAt: normalizedUpdatedAt,
      manualUpdatedAt: null,
      favoriteUpdatedAt: null,
      displayNameUpdatedAt: null,
      folderRuleUpdatedAt: normalizedUpdatedAt,
    );
  }

  @override
  Future<PrivateContactRecord?> upsertManualPrivateContact({
    required String addressKey,
    String? displayName,
  }) async {
    final key = contactDirectoryAddressKey(addressKey);
    if (key.isEmpty) {
      return null;
    }
    final now = DateTime.timestamp().toUtc();
    final existing = await getPrivateContactRecord(key);
    return _writePrivateContactRecord(
      addressKey: key,
      active: true,
      manual: true,
      favorited: existing?.favorited ?? false,
      displayNameOverride:
          _trimmedContactValue(displayName) ?? existing?.displayNameOverride,
      folderCollectionId: existing?.folderCollectionId,
      updatedAt: now,
      activeUpdatedAt: now,
      manualUpdatedAt: now,
      favoriteUpdatedAt: null,
      displayNameUpdatedAt: _trimmedContactValue(displayName) == null
          ? null
          : now,
      folderRuleUpdatedAt: null,
    );
  }

  @override
  Future<PrivateContactRecord?> deactivateManualPrivateContact({
    required String addressKey,
  }) async {
    final key = contactDirectoryAddressKey(addressKey);
    if (key.isEmpty) {
      return null;
    }
    final existing = await getPrivateContactRecord(key);
    if (existing == null) {
      return null;
    }
    final now = DateTime.timestamp().toUtc();
    return _writePrivateContactRecord(
      addressKey: key,
      active: false,
      manual: false,
      favorited: existing.favorited,
      displayNameOverride: existing.displayNameOverride,
      folderCollectionId: existing.folderCollectionId,
      updatedAt: now,
      activeUpdatedAt: now,
      manualUpdatedAt: now,
      favoriteUpdatedAt: null,
      displayNameUpdatedAt: null,
      folderRuleUpdatedAt: null,
    );
  }

  @override
  Future<PrivateContactRecord?> applyPrivateContactMutation({
    required String addressKey,
    required bool active,
    required bool manual,
    required bool favorited,
    required String? displayNameOverride,
    required String? folderCollectionId,
    required DateTime updatedAt,
    required DateTime? activeUpdatedAt,
    required DateTime? manualUpdatedAt,
    required DateTime? favoriteUpdatedAt,
    required DateTime? displayNameUpdatedAt,
    required DateTime? folderRuleUpdatedAt,
    String? sourceId,
  }) async {
    final key = contactDirectoryAddressKey(addressKey);
    if (key.isEmpty) {
      return null;
    }
    final normalizedUpdatedAt = updatedAt.toUtc();
    final existing = await getPrivateContactRecord(key);
    if (existing != null &&
        !normalizedUpdatedAt.isAfter(existing.updatedAt.toUtc())) {
      return existing;
    }
    return _writePrivateContactRecord(
      addressKey: key,
      active: active,
      manual: manual,
      favorited: favorited,
      displayNameOverride: displayNameOverride,
      folderCollectionId: folderCollectionId,
      updatedAt: normalizedUpdatedAt,
      activeUpdatedAt: activeUpdatedAt ?? normalizedUpdatedAt,
      manualUpdatedAt: manualUpdatedAt,
      favoriteUpdatedAt: favoriteUpdatedAt,
      displayNameUpdatedAt: displayNameUpdatedAt,
      folderRuleUpdatedAt: folderRuleUpdatedAt,
      sourceId: sourceId,
    );
  }

  @override
  Future<List<PrivateContactDetailFieldEntry>> getPrivateContactDetailFields(
    String addressKey, {
    bool includeInactive = false,
  }) {
    final key = contactDirectoryAddressKey(addressKey);
    if (key.isEmpty) {
      return Future<List<PrivateContactDetailFieldEntry>>.value(
        const <PrivateContactDetailFieldEntry>[],
      );
    }
    final query = select(privateContactDetailFields)
      ..where((tbl) => tbl.addressKey.equals(key))
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.sortOrder),
        (tbl) => OrderingTerm(expression: tbl.fieldId),
      ]);
    if (!includeInactive) {
      query.where((tbl) => tbl.active.equals(true));
    }
    return query.get();
  }

  @override
  Future<PrivateContactDetailFieldEntry?>
  applyPrivateContactDetailFieldMutation({
    required String addressKey,
    required String fieldId,
    required ContactDetailFieldKind kind,
    required String? label,
    required String value,
    required int sortOrder,
    required bool active,
    required DateTime updatedAt,
    String? sourceId,
  }) async {
    final key = contactDirectoryAddressKey(addressKey);
    final normalizedFieldId = fieldId.trim();
    final normalizedValue = value.trim();
    if (key.isEmpty || normalizedFieldId.isEmpty || normalizedValue.isEmpty) {
      return null;
    }
    final normalizedUpdatedAt = updatedAt.toUtc();
    final existing =
        await (select(privateContactDetailFields)..where(
              (tbl) =>
                  tbl.addressKey.equals(key) &
                  tbl.fieldId.equals(normalizedFieldId),
            ))
            .getSingleOrNull();
    if (existing != null &&
        !normalizedUpdatedAt.isAfter(existing.updatedAt.toUtc())) {
      return existing;
    }
    final entry = PrivateContactDetailFieldEntry(
      addressKey: key,
      fieldId: normalizedFieldId,
      kind: kind,
      label: _trimmedContactValue(label),
      value: normalizedValue,
      sortOrder: sortOrder,
      active: active,
      updatedAt: normalizedUpdatedAt,
      sourceId: _trimmedContactValue(sourceId),
    );
    await into(privateContactDetailFields).insertOnConflictUpdate(entry);
    final record = await getPrivateContactRecord(key);
    if (record == null) {
      await _writePrivateContactRecord(
        addressKey: key,
        active: true,
        manual: false,
        favorited: false,
        displayNameOverride: null,
        folderCollectionId: null,
        updatedAt: normalizedUpdatedAt,
        activeUpdatedAt: normalizedUpdatedAt,
        manualUpdatedAt: null,
        favoriteUpdatedAt: null,
        displayNameUpdatedAt: null,
        folderRuleUpdatedAt: null,
        sourceId: sourceId,
      );
    } else if (normalizedUpdatedAt.isAfter(record.updatedAt.toUtc())) {
      await _writePrivateContactRecord(
        addressKey: key,
        active: record.active || active,
        manual: record.manual,
        favorited: record.favorited,
        displayNameOverride: record.displayNameOverride,
        folderCollectionId: record.folderCollectionId,
        updatedAt: normalizedUpdatedAt,
        activeUpdatedAt: null,
        manualUpdatedAt: null,
        favoriteUpdatedAt: null,
        displayNameUpdatedAt: null,
        folderRuleUpdatedAt: null,
        sourceId: record.sourceId,
      );
    }
    return entry;
  }

  Future<Map<String, List<PrivateContactDetailFieldEntry>>>
  _getPrivateContactDetailFieldsByAddress({
    bool includeInactive = false,
  }) async {
    final query = select(privateContactDetailFields)
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.addressKey),
        (tbl) => OrderingTerm(expression: tbl.sortOrder),
        (tbl) => OrderingTerm(expression: tbl.fieldId),
      ]);
    if (!includeInactive) {
      query.where((tbl) => tbl.active.equals(true));
    }
    final fields = await query.get();
    final byAddress = <String, List<PrivateContactDetailFieldEntry>>{};
    for (final field in fields) {
      final key = contactDirectoryAddressKey(field.addressKey);
      if (key.isEmpty) {
        continue;
      }
      byAddress
          .putIfAbsent(key, () => <PrivateContactDetailFieldEntry>[])
          .add(field);
    }
    return {
      for (final entry in byAddress.entries)
        entry.key: List<PrivateContactDetailFieldEntry>.unmodifiable(
          entry.value,
        ),
    };
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
    const copiedColumnNames = <String>[
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
      'sticker_pack_i_d',
      'pseudo_message_type',
      'pseudo_message_data',
      'delta_chat_id',
      'delta_msg_id',
    ];
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
      final targetColumns = copiedColumnNames.map((c) => '"$c"').toList();
      final sourceColumns = copiedColumnNames.map((c) => '"$c"').toList();
      final hasDeltaSeenSynced = await _tableHasColumn(
        tempTableName,
        'delta_seen_synced',
      );
      if (hasDeltaSeenSynced) {
        targetColumns.add('"delta_seen_synced"');
        sourceColumns.add('"delta_seen_synced"');
      }
      final hasLegacyQuoting = await _tableHasColumn(tempTableName, 'quoting');
      if (hasLegacyQuoting) {
        targetColumns.add('"reply_stanza_id"');
        sourceColumns.add('NULLIF(trim("quoting"), \'\')');
      }
      final targetColumnList = targetColumns.join(', ');
      final sourceColumnList = sourceColumns.join(', ');
      await customStatement(
        'INSERT INTO "$tableName" ($targetColumnList) '
        'SELECT $sourceColumnList FROM "$tempTableName"',
      );
      if (hasLegacyQuoting) {
        await _resolveRebuiltMessageReplyFieldsFromLegacyQuoting();
      }
      await customStatement('DROP TABLE "$tempTableName"');
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _resolveRebuiltMessageReplyFieldsFromLegacyQuoting() async {
    final rows = await customSelect(
      '''
SELECT stanza_i_d, chat_jid, reply_stanza_id
FROM messages
WHERE reply_stanza_id IS NOT NULL AND trim(reply_stanza_id) != ''
''',
      readsFrom: {messages},
    ).get();
    for (final row in rows) {
      final stanzaId = row.read<String>('stanza_i_d');
      final chatJid = row.read<String>('chat_jid');
      final resolved = await _replyFieldsForLegacyQuoting(
        legacyValue: row.read<String>('reply_stanza_id'),
        chatJid: chatJid,
      );
      await _updateMessageReplyFields(stanzaId, resolved);
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

  Future<void> _ensureMessageDeltaSeenSyncedColumn(Migrator m) async {
    if (await _tableHasColumn(messages.actualTableName, 'delta_seen_synced')) {
      return;
    }
    await m.addColumn(messages, messages.deltaSeenSynced);
  }

  Future<void> _ensureMessageColumnsReadByMigrationDataRepairs(
    Migrator m,
  ) async {
    await _ensureMessageRfc822BodyStatusColumn(m);
    await _ensureMessageReplyColumns(m);
    await _ensureMessageDeltaSeenSyncedColumn(m);
  }

  Future<void> _ensureMessageRfc822BodyStatusColumn(Migrator m) async {
    if (await _tableHasColumn(messages.actualTableName, 'rfc822_body_status')) {
      return;
    }
    await m.addColumn(messages, messages.rfc822BodyStatus);
  }

  Future<void> _ensureMessageReplyColumns(Migrator m) async {
    if (!await _tableHasColumn(messages.actualTableName, 'reply_stanza_id')) {
      await m.addColumn(messages, messages.replyStanzaId);
    }
    if (!await _tableHasColumn(messages.actualTableName, 'reply_origin_id')) {
      await m.addColumn(messages, messages.replyOriginId);
    }
    if (!await _tableHasColumn(
      messages.actualTableName,
      'reply_muc_stanza_id',
    )) {
      await m.addColumn(messages, messages.replyMucStanzaId);
    }
  }

  Future<void> _createLocalPromptStatesTable() async {
    await customStatement('''
CREATE TABLE IF NOT EXISTS local_prompt_states (
  account_jid TEXT NOT NULL,
  prompt_id TEXT NOT NULL,
  status TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY(account_jid, prompt_id)
)
''');
  }

  Future<void> _createEmailHistoryImportJournalTable() async {
    await customStatement('''
CREATE TABLE IF NOT EXISTS email_history_import_journal (
  account_jid TEXT NOT NULL,
  delta_account_id INTEGER NOT NULL,
  status TEXT NOT NULL,
  watermark_delta_msg_id INTEGER NOT NULL,
  target_delta_msg_id INTEGER NOT NULL,
  last_projected_delta_msg_id INTEGER NOT NULL,
  fetch_completed INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY(account_jid, delta_account_id)
)
''');
  }

  Future<void> _rebuildEmailChatAccountsForMultipleDeltaChats() async {
    const tempTableName = 'email_chat_accounts_multi';
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await customStatement('DROP TABLE IF EXISTS $tempTableName');
      await customStatement('''
CREATE TABLE $tempTableName (
  chat_jid TEXT NOT NULL REFERENCES chats(jid),
  delta_account_id INTEGER NOT NULL DEFAULT ${DeltaAccountDefaults.legacyId},
  delta_chat_id INTEGER NOT NULL,
  PRIMARY KEY(chat_jid, delta_account_id, delta_chat_id),
  UNIQUE(delta_account_id, delta_chat_id)
)
''');
      await customStatement('''
INSERT OR IGNORE INTO $tempTableName(
  chat_jid,
  delta_account_id,
  delta_chat_id
)
SELECT chat_jid, delta_account_id, delta_chat_id
FROM email_chat_accounts
''');
      await customStatement('DROP TABLE email_chat_accounts');
      await customStatement(
        'ALTER TABLE $tempTableName RENAME TO email_chat_accounts',
      );
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  Future<bool> _tableExists(String tableName) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(tableName)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<void> _dropLegacyMessagePinIndexes() async {
    await customStatement(
      'DROP INDEX IF EXISTS idx_message_pins_chat_reference',
    );
    await customStatement(
      'DROP INDEX IF EXISTS idx_message_pins_chat_active_pinned',
    );
  }

  Future<void> _ensureMessagePinReferenceColumns(Migrator m) async {
    if (!await _tableHasColumn(
      messagePins.actualTableName,
      'message_stanza_id',
    )) {
      await m.addColumn(messagePins, messagePins.messageStanzaId);
    }
    if (!await _tableHasColumn(
      messagePins.actualTableName,
      'message_origin_id',
    )) {
      await m.addColumn(messagePins, messagePins.messageOriginId);
    }
    if (!await _tableHasColumn(
      messagePins.actualTableName,
      'message_muc_stanza_id',
    )) {
      await m.addColumn(messagePins, messagePins.messageMucStanzaId);
    }
  }

  Future<void> _migrateMessagePinsReferenceKindColumn(Migrator m) async {
    await _ensureMessagePinReferenceColumns(m);
    await customStatement('''
UPDATE message_pins
SET
  message_stanza_id = COALESCE(
    message_stanza_id,
    CASE WHEN message_reference_kind = 0 THEN message_reference_id ELSE NULL END
  ),
  message_origin_id = COALESCE(
    message_origin_id,
    CASE WHEN message_reference_kind = 1 THEN message_reference_id ELSE NULL END
  ),
  message_muc_stanza_id = COALESCE(
    message_muc_stanza_id,
    CASE WHEN message_reference_kind = 2 THEN message_reference_id ELSE NULL END
  )
''');
    await m.alterTable(
      // ignore: experimental_member_use
      TableMigration(messagePins),
    );
  }

  Future<void> _migrateMessagePinsTable(Migrator m) async {
    final tableName = messagePins.actualTableName;
    if (!await _tableExists(tableName)) {
      await m.createTable(messagePins);
    }

    Future<void> copyOldRows({
      required String oldTableName,
      required String oldPinnerColumn,
    }) async {
      if (!await _tableExists(oldTableName)) {
        return;
      }
      final hasReferenceKind = await _tableHasColumn(
        oldTableName,
        'message_reference_kind',
      );
      final messageStanzaIdSelect = hasReferenceKind
          ? 'CASE WHEN message_reference_kind = 0 THEN message_reference_id ELSE NULL END'
          : 'message_reference_id';
      final messageOriginIdSelect = hasReferenceKind
          ? 'CASE WHEN message_reference_kind = 1 THEN message_reference_id ELSE NULL END'
          : 'NULL';
      final messageMucStanzaIdSelect = hasReferenceKind
          ? 'CASE WHEN message_reference_kind = 2 THEN message_reference_id ELSE NULL END'
          : 'NULL';
      await customStatement('''
INSERT OR REPLACE INTO message_pins (
  chat_jid,
  message_reference_id,
  message_stanza_id,
  message_origin_id,
  message_muc_stanza_id,
  pinner_jid,
  pinned_at,
  active,
  identity_verified
)
SELECT
  chat_jid,
  message_reference_id,
  $messageStanzaIdSelect,
  $messageOriginIdSelect,
  $messageMucStanzaIdSelect,
  $oldPinnerColumn,
  pinned_at,
  active,
  identity_verified
FROM $oldTableName
''');
      await customStatement('DROP TABLE $oldTableName');
    }

    await copyOldRows(
      oldTableName: 'pinned_message_actors',
      oldPinnerColumn: 'actor_jid',
    );
    await copyOldRows(
      oldTableName: 'pinned_message_pinners',
      oldPinnerColumn: 'pinner_jid',
    );
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

  Future<void> _createCurrentSchemaIndexes() async {
    await _dropLegacyMessagePinIndexes();
    final statements = <String>[
      '''
CREATE INDEX IF NOT EXISTS idx_messages_chat_timestamp
ON messages(chat_jid, timestamp)
''',
      '''
CREATE INDEX IF NOT EXISTS idx_chats_last_change
ON chats(last_change_timestamp)
''',
      '''
CREATE INDEX IF NOT EXISTS idx_recipient_addresses_last_seen
ON recipient_addresses(last_seen)
''',
      '''
CREATE INDEX IF NOT EXISTS idx_message_collection_memberships_collection_added
ON message_collection_memberships(
  collection_id,
  active,
  added_at,
  message_reference_id
)
''',
      '''
CREATE INDEX IF NOT EXISTS idx_message_collection_memberships_chat_added
ON message_collection_memberships(
  chat_jid,
  active,
  added_at,
  message_reference_id
)
''',
      '''
CREATE INDEX IF NOT EXISTS idx_message_collection_memberships_delta
ON message_collection_memberships(delta_account_id, delta_msg_id)
''',
      '''
CREATE INDEX IF NOT EXISTS idx_pinned_messages_chat_pinned
ON pinned_messages(chat_jid, active, pinned_at, message_stanza_id)
''',
      '''
CREATE INDEX IF NOT EXISTS idx_message_pins_chat_reference
ON message_pins(chat_jid, message_reference_id)
''',
      '''
CREATE INDEX IF NOT EXISTS idx_message_pins_chat_active_pinned
ON message_pins(chat_jid, active, pinned_at, message_reference_id)
''',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
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
      await _refreshChatSummaryAfterMessageRemoval(jid: jid);
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

List<ContactDirectoryEntry> _mergeContactDirectoryEntries(
  List<RosterItem> rosterItems,
  List<Contact> emailContacts,
  List<PrivateContactRecord> privateContacts,
  Map<String, List<PrivateContactDetailFieldEntry>> detailFieldsByAddress,
  List<Chat> chats,
) {
  final rosterByAddress = <String, RosterItem>{};
  for (final item in rosterItems) {
    final key = contactDirectoryAddressKey(item.jid);
    if (key.isEmpty) {
      continue;
    }
    rosterByAddress[key] = item;
  }

  final emailByAddress = <String, _EmailContactAggregate>{};
  for (final contact in emailContacts) {
    final resolvedAddress = contact.resolvedAddress;
    final key = contactDirectoryAddressKey(resolvedAddress);
    if (key.isEmpty || resolvedAddress == null || resolvedAddress.isEmpty) {
      continue;
    }
    final aggregate = emailByAddress.putIfAbsent(
      key,
      () => _EmailContactAggregate(),
    );
    final nativeId = contact.nativeID?.trim();
    if (nativeId != null &&
        nativeId.isNotEmpty &&
        !aggregate.nativeIds.contains(nativeId)) {
      aggregate.nativeIds.add(nativeId);
    }
    final displayName = contact.providedDisplayName?.trim();
    if (displayName != null &&
        displayName.isNotEmpty &&
        aggregate.displayName == null) {
      aggregate.displayName = displayName;
    }
  }

  final avatarPathsByAddress = <String, String>{};
  for (final chat in chats) {
    if (chat.type != ChatType.chat) {
      continue;
    }
    final avatarPath = _preferredContactAvatarPath(chat);
    if (avatarPath == null) {
      continue;
    }
    for (final candidate in <String?>[
      chat.jid,
      chat.emailAddress,
      chat.remoteJid,
    ]) {
      final key = contactDirectoryAddressKey(candidate);
      if (key.isEmpty || avatarPathsByAddress.containsKey(key)) {
        continue;
      }
      avatarPathsByAddress[key] = avatarPath;
    }
  }

  final privateContactsByAddress = <String, PrivateContactRecord>{};
  for (final contact in privateContacts) {
    final key = contactDirectoryAddressKey(contact.addressKey);
    if (key.isEmpty) {
      continue;
    }
    privateContactsByAddress[key] = contact;
  }

  final addresses = <String>{
    ...privateContactsByAddress.keys,
    ...rosterByAddress.keys,
    ...emailByAddress.keys,
  }.toList(growable: false)..sort();

  final items = <ContactDirectoryEntry>[];
  for (final address in addresses) {
    final roster = rosterByAddress[address];
    final email = emailByAddress[address];
    final privateContact = privateContactsByAddress[address];
    items.add(
      ContactDirectoryEntry(
        address: address,
        hasPrivateContact: privateContact != null,
        hasXmppRoster: roster != null,
        hasEmailContact: email != null,
        emailNativeIds: List<String>.unmodifiable(
          email?.nativeIds ?? const <String>[],
        ),
        isManualContact: privateContact?.manual ?? false,
        xmppTitle: roster == null ? null : _contactDisplayName(roster),
        emailDisplayName: email?.displayName,
        displayNameOverride: privateContact?.displayNameOverride,
        folderCollectionId: _trimmedContactValue(
          privateContact?.folderCollectionId,
        ),
        favorited: privateContact?.favorited ?? false,
        detailFields:
            detailFieldsByAddress[address]
                ?.map(_contactDetailFieldEntry)
                .toList(growable: false) ??
            const <ContactDetailFieldEntry>[],
        avatarPath:
            _trimmedContactValue(roster?.avatarPath) ??
            avatarPathsByAddress[address],
        subscription: roster?.subscription,
      ),
    );
  }
  items.sort(_compareContactDirectoryEntries);
  return List<ContactDirectoryEntry>.unmodifiable(items);
}

ContactDetailFieldEntry _contactDetailFieldEntry(
  PrivateContactDetailFieldEntry entry,
) {
  return ContactDetailFieldEntry(
    fieldId: entry.fieldId,
    kind: entry.kind,
    label: entry.label,
    value: entry.value,
    sortOrder: entry.sortOrder,
    active: entry.active,
    updatedAt: entry.updatedAt,
    sourceId: entry.sourceId,
  );
}

int _compareContactDirectoryEntries(
  ContactDirectoryEntry a,
  ContactDirectoryEntry b,
) {
  final aKey = a.displayName.toLowerCase();
  final bKey = b.displayName.toLowerCase();
  final byName = aKey.compareTo(bKey);
  if (byName != 0) {
    return byName;
  }
  return a.address.compareTo(b.address);
}

String? _contactDisplayName(RosterItem item) {
  final title = item.contactDisplayName?.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }
  final fallback = item.title.trim();
  if (fallback.isEmpty) {
    return null;
  }
  return fallback;
}

class _EmailContactAggregate {
  final List<String> nativeIds = <String>[];
  String? displayName;
}

String? _preferredContactAvatarPath(Chat chat) {
  return _trimmedContactValue(chat.avatarPath) ??
      _trimmedContactValue(chat.contactAvatarPath);
}

Set<String> _contactAddressKeysForChat(Chat chat) {
  final keys = <String>{};
  for (final candidate in <String?>[
    chat.jid,
    chat.remoteJid,
    chat.emailAddress,
    chat.emailFromAddress,
  ]) {
    final key = contactDirectoryAddressKey(candidate);
    if (key.isNotEmpty) {
      keys.add(key);
    }
  }
  return keys;
}

String? _trimmedContactValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String? _trimmedReferenceValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
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
  final path = (await prepareAppStorageDirectory()).path;
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
