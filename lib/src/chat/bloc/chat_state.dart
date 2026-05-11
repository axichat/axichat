// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'chat_bloc.dart';

enum ChatCollectionActionFailureReason { unsupported, updateFailed }

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
    @Default(false) bool pinnedMessagesLoaded,
    @Default(false) bool pinnedMessagesHydrating,
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
    @Default(0) int composerHydrationId,
    String? composerHydrationText,
    @Default(0) int composerClearId,
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
    String? openChatJid,
    @Default(0) int openChatRequestId,
    String? scrollTargetMessageId,
    @Default(0) int scrollTargetRequestId,
    ChatToast? toast,
    @Default(0) int toastId,
    @Default(RequestStatus.none) RequestStatus roomAvatarUpdateStatus,
    @Default(ChatCollectionActionIdle())
    ChatCollectionActionState collectionActionState,
  }) = _ChatState;
}
