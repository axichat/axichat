// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'chat_bloc.dart';

@Freezed(toJson: false, fromJson: false)
class ChatState with _$ChatState {
  const factory ChatState({
    required List<Message> items,
    @Default(false) bool messagesLoaded,
    @Default(<String, List<String>>{})
    Map<String, List<String>> attachmentMetadataIdsByMessageId,
    @Default(<String, String>{})
    Map<String, String> attachmentGroupLeaderByMessageId,
    @Default(<PinnedMessageItem>[]) List<PinnedMessageItem> pinnedMessages,
    @Default(false) bool pinnedMessagesLoaded,
    @Default(false) bool pinnedMessagesHydrating,
    @Default(<String, Message>{}) Map<String, Message> quotedMessagesById,
    Chat? chat,
    RoomState? roomState,
    @Default(<RoomMemberSection>[]) List<RoomMemberSection> roomMemberSections,
    Message? focused,
    Message? quoting,
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
    @Default(<int, String>{}) Map<int, String> emailRawHeadersByDeltaId,
    @Default(<int>{}) Set<int> emailRawHeadersLoading,
    @Default(<int>{}) Set<int> emailRawHeadersUnavailable,
    @Default(<PendingAttachment>[]) List<PendingAttachment> pendingAttachments,
    String? composerError,
    @Default(0) int composerHydrationId,
    String? composerHydrationText,
    @Default(0) int composerClearId,
    String? emailSubject,
    @Default(0) int emailSubjectHydrationId,
    String? emailSubjectHydrationText,
    @Default(true) bool emailSubjectAutofillEligible,
    @Default(false) bool emailSubjectAutofilled,
    @Default(EmailSyncState.ready()) EmailSyncState emailSyncState,
    @Default(mox.XmppConnectionState.notConnected)
    mox.XmppConnectionState xmppConnectionState,
    @Default(false) bool supportsHttpFileUpload,
    XmppPeerCapabilities? xmppCapabilities,
    @Default(false) bool emailServiceAvailable,
    String? emailSelfJid,
    String? openChatJid,
    @Default(0) int openChatRequestId,
    ChatToast? toast,
    @Default(0) int toastId,
  }) = _ChatState;
}
