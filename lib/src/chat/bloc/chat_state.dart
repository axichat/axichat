// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'chat_bloc.dart';

enum ChatCollectionActionFailureReason { unsupported, updateFailed }

enum ChatPinnedMessagesStatus {
  idle,
  loading,
  loaded,
  hydrating,
  failure;

  bool get hasSnapshot => this == loaded || this == hydrating;

  bool get showsPanelLoading => this == loading;

  bool get isHydrating => this == hydrating;

  bool get canAutoLoadOnOpen => this == idle;

  bool get canRetry => this == failure;
}

final class ChatPinnedMessageNotice extends Equatable
    implements Comparable<ChatPinnedMessageNotice> {
  const ChatPinnedMessageNotice({
    required this.messageStanzaId,
    required this.chatJid,
    required this.pinnedAt,
  });

  final String messageStanzaId;
  final String chatJid;
  final DateTime pinnedAt;

  bool isAfter(ChatPinnedMessageNotice other) => compareTo(other) > 0;

  @override
  int compareTo(ChatPinnedMessageNotice other) {
    final timestampOrder = pinnedAt.compareTo(other.pinnedAt);
    if (timestampOrder != 0) {
      return timestampOrder;
    }
    final messageOrder = messageStanzaId.compareTo(other.messageStanzaId);
    if (messageOrder != 0) {
      return messageOrder;
    }
    return chatJid.compareTo(other.chatJid);
  }

  @override
  List<Object?> get props => [messageStanzaId, chatJid, pinnedAt];
}

final class ChatForwardDraft extends Equatable {
  const ChatForwardDraft({required this.sources});

  final List<ChatForwardDraftSource> sources;

  List<DraftForwardedBlock> get forwardedBlocks => sources
      .map(
        (source) => DraftForwardedBlock(
          blockId: uuid.v4(),
          sourceMessageId: source.sourceMessageId,
          senderJid: source.senderJid,
          senderLabel: source.resolvedSenderLabel,
          timestamp: source.timestamp,
          originalSubject: source.originalSubject,
          originalPlainText: source.originalPlainTextBody,
          originalHtml: source.originalHtmlBody,
          quotedContext: source.quotedContext,
        ),
      )
      .toList(growable: false);

  List<String> get attachmentMetadataIds {
    final ids = <String>{};
    for (final source in sources) {
      for (final id in source.attachmentMetadataIds) {
        final trimmed = id.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        ids.add(trimmed);
      }
    }
    return ids.toList(growable: false);
  }

  @override
  List<Object?> get props => [sources];
}

final class ChatForwardDraftSource extends Equatable {
  const ChatForwardDraftSource({
    required this.sourceMessageId,
    required this.senderJid,
    required this.resolvedSenderLabel,
    required this.timestamp,
    required this.originalSubject,
    required this.originalPlainTextBody,
    required this.originalHtmlBody,
    required this.attachmentMetadataIds,
    this.quotedContext,
  });

  final String sourceMessageId;
  final String senderJid;
  final String resolvedSenderLabel;
  final DateTime? timestamp;
  final String? originalSubject;
  final String originalPlainTextBody;
  final String? originalHtmlBody;
  final List<String> attachmentMetadataIds;
  final DraftForwardedQuoteContext? quotedContext;

  @override
  List<Object?> get props => [
    sourceMessageId,
    senderJid,
    resolvedSenderLabel,
    timestamp,
    originalSubject,
    originalPlainTextBody,
    originalHtmlBody,
    attachmentMetadataIds,
    quotedContext,
  ];
}

sealed class ChatCollectionActionState extends Equatable {
  const ChatCollectionActionState();
}

final class ChatCollectionActionIdle extends ChatCollectionActionState {
  const ChatCollectionActionIdle();

  @override
  List<Object?> get props => const [];
}

final class ChatCollectionActionLoading extends ChatCollectionActionState {
  const ChatCollectionActionLoading({
    required this.collectionId,
    required this.messageReferenceId,
    required this.active,
  });

  final String collectionId;
  final String messageReferenceId;
  final bool active;

  @override
  List<Object?> get props => [collectionId, messageReferenceId, active];
}

final class ChatCollectionActionSuccess extends ChatCollectionActionState {
  const ChatCollectionActionSuccess({
    required this.collectionId,
    required this.messageReferenceId,
    required this.active,
  });

  final String collectionId;
  final String messageReferenceId;
  final bool active;

  @override
  List<Object?> get props => [collectionId, messageReferenceId, active];
}

final class ChatCollectionActionFailure extends ChatCollectionActionState {
  const ChatCollectionActionFailure({
    required this.collectionId,
    required this.messageReferenceId,
    required this.active,
    required this.reason,
  });

  final String collectionId;
  final String messageReferenceId;
  final bool active;
  final ChatCollectionActionFailureReason reason;

  @override
  List<Object?> get props => [collectionId, messageReferenceId, active, reason];
}

@Freezed(toJson: false, fromJson: false)
abstract class ChatState with _$ChatState {
  const factory ChatState({
    required List<Message> items,
    @Default(false) bool messagesLoaded,
    @Default(<String, List<String>>{})
    Map<String, List<String>> attachmentMetadataIdsByMessageId,
    @Default(<String, String>{})
    Map<String, String> attachmentGroupLeaderByMessageId,
    @Default(<PinnedMessageItem>[]) List<PinnedMessageItem> pinnedMessages,
    @Default(ChatPinnedMessagesStatus.idle)
    ChatPinnedMessagesStatus pinnedMessagesStatus,
    ChatPinnedMessageNotice? latestPinnedMessageNotice,
    DateTime? lastSeenPinnedMessageAt,
    @Default(<String, Message>{}) Map<String, Message> quotedMessagesById,
    Chat? chat,
    RoomState? roomState,
    @Default(<RoomMemberSection>[]) List<RoomMemberSection> roomMemberSections,
    Message? focused,
    @Default(false) bool typing,
    @Default(<String>[]) List<String> typingParticipants,
    @Default(true) bool showAlert,
    @Default(MessageTimelineFilter.allWithContact)
    MessageTimelineFilter viewFilter,
    @Default(<String, FanOutSendReport>{})
    Map<String, FanOutSendReport> fanOutReports,
    @Default(<String, FanOutDraft>{}) Map<String, FanOutDraft> fanOutDrafts,
    @Default(<String, ShareContext>{}) Map<String, ShareContext> shareContexts,
    @Default(_emptyShareReplies) Map<String, List<Chat>> shareReplies,
    @Default(<String>{}) Set<String> resendLoadingMessageIds,
    @Default(<int, String>{}) Map<int, String> emailRawHeadersByDeltaId,
    @Default(<int>{}) Set<int> emailRawHeadersLoading,
    @Default(<int>{}) Set<int> emailRawHeadersUnavailable,
    @Default(<int, String>{}) Map<int, String> emailFullHtmlByDeltaId,
    @Default(<int>{}) Set<int> emailFullHtmlLoading,
    @Default(<int>{}) Set<int> emailFullHtmlUnavailable,
    @Default(<int, String>{}) Map<int, String> emailQuotedTextByDeltaId,
    @Default(<int>{}) Set<int> emailQuotedTextLoading,
    @Default(<int>{}) Set<int> emailQuotedTextUnavailable,
    @Default(<String, FileMetadataData?>{})
    Map<String, FileMetadataData?> fileMetadataById,
    ChatMessageKey? composerError,
    @Default(RequestStatus.none) RequestStatus composerSendStatus,
    @Default(0) int composerHydrationId,
    String? composerHydrationText,
    CalendarTaskIcsMessage? composerHydrationCalendarTaskIcsMessage,
    String? emailSubject,
    @Default(true) bool emailSubjectAutofillEligible,
    @Default(false) bool emailSubjectAutofilled,
    @Default(EmailSyncState.ready()) EmailSyncState emailSyncState,
    @Default(mox.XmppConnectionState.notConnected)
    mox.XmppConnectionState xmppConnectionState,
    String? unreadBoundaryStanzaId,
    XmppPeerCapabilities? xmppCapabilities,
    @Default(false) bool supportsHttpFileUpload,
    @Default(false) bool emailServiceAvailable,
    String? emailSelfJid,
    MessageTransport? savedTransportOverride,
    @Default(RequestStatus.none) RequestStatus savedTransportOverrideStatus,
    String? openChatJid,
    @Default(0) int openChatRequestId,
    String? scrollTargetMessageId,
    @Default(0) int scrollTargetRequestId,
    ChatForwardDraft? pendingForwardDraft,
    ChatToast? toast,
    @Default(0) int toastId,
    @Default(RequestStatus.none) RequestStatus roomAvatarUpdateStatus,
    @Default(<ChatSettingId, RequestStatus>{})
    Map<ChatSettingId, RequestStatus> chatSettingStatuses,
    @Default(ChatCollectionActionIdle())
    ChatCollectionActionState collectionActionState,
  }) = _ChatState;
}

extension ChatStatePinnedMessageNoticeVisibility on ChatState {
  bool get showPinnedMessageBanner {
    final latest = latestPinnedMessageNotice;
    if (latest == null) {
      return false;
    }
    final seenAt = lastSeenPinnedMessageAt;
    return seenAt == null || latest.pinnedAt.isAfter(seenAt);
  }
}

extension ChatStateSettingsSync on ChatState {
  MessageTransport activeTransportForSend(
    Chat chat, {
    MessageTransport? oneShotOverride,
  }) {
    return oneShotOverride ?? savedTransportOverride ?? chat.defaultTransport;
  }

  bool get canOfferEmailOutboundOverride {
    final currentChat = chat;
    final trimmedSelfJid = emailSelfJid?.trim();
    return emailServiceAvailable &&
        trimmedSelfJid != null &&
        trimmedSelfJid.isNotEmpty &&
        currentChat != null &&
        currentChat.supportsEmailOutboundOverrideForDomain(
          addressDomainPart(trimmedSelfJid),
        );
  }

  bool get usesSavedEmailTransportOverride {
    final currentChat = chat;
    return canOfferEmailOutboundOverride &&
        currentChat != null &&
        activeTransportForSend(currentChat).isEmail;
  }

  bool isChatSettingLoading(ChatSettingId settingId) {
    return chatSettingStatuses[settingId]?.isLoading ?? false;
  }

  ChatState markChatSettingLoading(ChatSettingId settingId) {
    final statuses = Map<ChatSettingId, RequestStatus>.from(chatSettingStatuses)
      ..[settingId] = RequestStatus.loading;
    return copyWith(
      chatSettingStatuses: Map<ChatSettingId, RequestStatus>.unmodifiable(
        statuses,
      ),
    );
  }

  ChatState clearChatSettingLoading(ChatSettingId settingId) {
    final statuses = Map<ChatSettingId, RequestStatus>.from(chatSettingStatuses)
      ..remove(settingId);
    return copyWith(
      chatSettingStatuses: Map<ChatSettingId, RequestStatus>.unmodifiable(
        statuses,
      ),
    );
  }
}

extension ChatStateResendLoading on ChatState {
  bool isMessageResendLoading(String stanzaId) {
    final trimmedStanzaId = stanzaId.trim();
    return trimmedStanzaId.isNotEmpty &&
        resendLoadingMessageIds.contains(trimmedStanzaId);
  }

  ChatState markMessageResendLoading(String stanzaId) {
    final trimmedStanzaId = stanzaId.trim();
    if (trimmedStanzaId.isEmpty ||
        resendLoadingMessageIds.contains(trimmedStanzaId)) {
      return this;
    }
    return copyWith(
      resendLoadingMessageIds: Set<String>.unmodifiable(<String>{
        ...resendLoadingMessageIds,
        trimmedStanzaId,
      }),
    );
  }

  ChatState clearMessageResendLoading(String stanzaId) {
    final trimmedStanzaId = stanzaId.trim();
    if (trimmedStanzaId.isEmpty ||
        !resendLoadingMessageIds.contains(trimmedStanzaId)) {
      return this;
    }
    return copyWith(
      resendLoadingMessageIds: Set<String>.unmodifiable(
        Set<String>.from(resendLoadingMessageIds)..remove(trimmedStanzaId),
      ),
    );
  }
}
