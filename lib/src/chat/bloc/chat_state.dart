part of 'chat_bloc.dart';

@Freezed(toJson: false, fromJson: false)
class ChatState with _$ChatState {
  const factory ChatState({
    required List<Message> items,
    @Default(false) bool messagesLoaded,
    Chat? chat,
    RoomState? roomState,
    Message? focused,
    Message? quoting,
    @Default(false) bool typing,
    @Default(<String>[]) List<String> typingParticipants,
    @Default(true) bool showAlert,
    @Default(MessageTimelineFilter.allWithContact)
    MessageTimelineFilter viewFilter,
    @Default(<ComposerRecipient>[]) List<ComposerRecipient> recipients,
    @Default(<String, FanOutSendReport>{})
    Map<String, FanOutSendReport> fanOutReports,
    @Default(<String, FanOutDraft>{}) Map<String, FanOutDraft> fanOutDrafts,
    @Default(<String, ShareContext>{}) Map<String, ShareContext> shareContexts,
    @Default(<String, List<Chat>>{}) Map<String, List<Chat>> shareReplies,
    @Default(<PendingAttachment>[]) List<PendingAttachment> pendingAttachments,
    String? composerError,
    @Default(0) int composerHydrationId,
    String? composerHydrationText,
    String? emailSubject,
    @Default(0) int emailSubjectHydrationId,
    String? emailSubjectHydrationText,
    @Default(EmailSyncState.ready()) EmailSyncState emailSyncState,
    @Default(ConnectionState.notConnected) ConnectionState xmppConnectionState,
    @Default(false) bool supportsHttpFileUpload,
    ChatToast? toast,
    @Default(0) int toastId,
    @Default(<String>{}) Set<String> loadedImageMessageIds,
  }) = _ChatState;
}
