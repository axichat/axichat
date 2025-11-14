part of 'chat_bloc.dart';

@Freezed(toJson: false, fromJson: false)
class ChatState with _$ChatState {
  const factory ChatState({
    required List<Message> items,
    Chat? chat,
    Message? focused,
    Message? quoting,
    @Default(false) bool typing,
    @Default(true) bool showAlert,
    @Default(MessageTimelineFilter.allWithContact)
    MessageTimelineFilter viewFilter,
    @Default(<ComposerRecipient>[]) List<ComposerRecipient> recipients,
    @Default(<String, FanOutSendReport>{})
    Map<String, FanOutSendReport> fanOutReports,
    @Default(<String, FanOutDraft>{}) Map<String, FanOutDraft> fanOutDrafts,
    @Default(<String, ShareContext>{}) Map<String, ShareContext> shareContexts,
    @Default(<PendingAttachment>[]) List<PendingAttachment> pendingAttachments,
    String? composerError,
    @Default(0) int composerHydrationId,
    String? composerHydrationText,
    @Default(EmailSyncState.ready()) EmailSyncState emailSyncState,
    ChatToast? toast,
    @Default(0) int toastId,
  }) = _ChatState;
}
