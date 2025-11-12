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
    @Default(<EmailAttachment>[]) List<EmailAttachment> pendingAttachments,
    String? composerError,
  }) = _ChatState;
}
