// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'axichat';

  @override
  String get homeTabChats => 'Chats';

  @override
  String get homeBottomNavHome => 'Home';

  @override
  String get homeTabDrafts => 'Drafts';

  @override
  String get homeTabSpam => 'Spam';

  @override
  String get homeTabBlocked => 'Blocked';

  @override
  String get homeNoModules => 'No modules available';

  @override
  String get homeRailShowMenu => 'Show menu';

  @override
  String get homeRailHideMenu => 'Hide menu';

  @override
  String get homeRailCalendar => 'Calendar';

  @override
  String get homeSyncTooltip => 'Sync now';

  @override
  String get homeSearchPlaceholderTabs => 'Search tabs';

  @override
  String homeSearchPlaceholderForTab(Object tab) {
    return 'Search $tab';
  }

  @override
  String homeSearchFilterLabel(Object filter) {
    return 'Filter: $filter';
  }

  @override
  String get blocklistFilterAll => 'All blocked';

  @override
  String get draftsFilterAll => 'All drafts';

  @override
  String get draftsFilterAttachments => 'With attachments';

  @override
  String get chatsFilterAll => 'All chats';

  @override
  String get chatsFilterContacts => 'Contacts';

  @override
  String get chatsFilterNonContacts => 'Non-contacts';

  @override
  String get chatsFilterXmppOnly => 'XMPP only';

  @override
  String get chatsFilterEmailOnly => 'Email only';

  @override
  String get chatsFilterHidden => 'Hidden';

  @override
  String get spamFilterAll => 'All spam';

  @override
  String get spamFilterEmail => 'Email';

  @override
  String get spamFilterXmpp => 'XMPP';

  @override
  String get chatFilterDirectOnly => 'Direct only';

  @override
  String get chatFilterAllWithContact => 'All with contact';

  @override
  String get chatSearchMessages => 'Search messages';

  @override
  String get chatSearchSortNewestFirst => 'Newest first';

  @override
  String get chatSearchSortOldestFirst => 'Oldest first';

  @override
  String get chatSearchAnySubject => 'Any subject';

  @override
  String get chatSearchExcludeSubject => 'Exclude subject';

  @override
  String get chatSearchFailed => 'Search failed';

  @override
  String get chatSearchInProgress => 'Searching…';

  @override
  String get chatSearchEmptyPrompt =>
      'Matches will appear in the conversation below.';

  @override
  String get chatSearchNoMatches =>
      'No matches. Adjust filters or try another query.';

  @override
  String chatSearchMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# matches shown below.',
      one: '# match shown below.',
    );
    return '$_temp0';
  }

  @override
  String filterTooltip(Object label) {
    return 'Filter • $label';
  }

  @override
  String get chatSearchClose => 'Close search';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get spamEmpty => 'No spam yet';

  @override
  String get spamMoveToInbox => 'Move to inbox';

  @override
  String get spamMoveToastTitle => 'Moved';

  @override
  String spamMoveToastMessage(Object chatTitle) {
    return 'Returned $chatTitle to inbox.';
  }

  @override
  String get chatSpamUpdateFailed => 'Failed to update spam status.';

  @override
  String chatSpamSent(Object chatTitle) {
    return 'Sent $chatTitle to spam.';
  }

  @override
  String chatSpamRestored(Object chatTitle) {
    return 'Returned $chatTitle to inbox.';
  }

  @override
  String get chatSpamReportedTitle => 'Reported';

  @override
  String get chatSpamRestoredTitle => 'Restored';

  @override
  String get chatMembersLoading => 'Loading members';

  @override
  String get chatMembersLoadingEllipsis => 'Loading members…';

  @override
  String get chatAttachmentConfirmTitle => 'Load attachment?';

  @override
  String chatAttachmentConfirmMessage(Object sender) {
    return 'Only load attachments from contacts you trust.\n\n$sender is not in your contacts yet. Continue?';
  }

  @override
  String get chatAttachmentConfirmButton => 'Load';

  @override
  String get attachmentGalleryRosterTrustLabel =>
      'Automatically download files from this user';

  @override
  String get attachmentGalleryRosterTrustHint =>
      'You can turn this off later in chat settings.';

  @override
  String get attachmentGalleryChatTrustLabel =>
      'Always allow attachments in this chat';

  @override
  String get attachmentGalleryChatTrustHint =>
      'You can turn this off later in chat settings.';

  @override
  String get attachmentGalleryRosterErrorTitle => 'Unable to add contact';

  @override
  String get attachmentGalleryRosterErrorMessage =>
      'Downloaded this attachment once, but automatic downloads are still disabled.';

  @override
  String get attachmentGalleryErrorMessage => 'Unable to load attachments.';

  @override
  String get attachmentGalleryAllLabel => 'All';

  @override
  String get attachmentGalleryImagesLabel => 'Images';

  @override
  String get attachmentGalleryVideosLabel => 'Videos';

  @override
  String get attachmentGalleryFilesLabel => 'Files';

  @override
  String get attachmentGallerySentLabel => 'Sent';

  @override
  String get attachmentGalleryReceivedLabel => 'Received';

  @override
  String get attachmentGalleryMetaSeparator => ' - ';

  @override
  String get attachmentGalleryLayoutGridLabel => 'Grid view';

  @override
  String get attachmentGalleryLayoutListLabel => 'List view';

  @override
  String get attachmentGallerySortNameAscLabel => 'Name A-Z';

  @override
  String get attachmentGallerySortNameDescLabel => 'Name Z-A';

  @override
  String get attachmentGallerySortSizeAscLabel => 'Size small to large';

  @override
  String get attachmentGallerySortSizeDescLabel => 'Size large to small';

  @override
  String get chatOpenLinkTitle => 'Open external link?';

  @override
  String chatOpenLinkMessage(Object url, Object host) {
    return 'You are about to open:\n$url\n\nOnly tap OK if you trust the site (host: $host).';
  }

  @override
  String chatOpenLinkWarningMessage(Object url, Object host) {
    return 'You are about to open:\n$url\n\nThis link contains unusual or invisible characters. Verify the address carefully (host: $host).';
  }

  @override
  String get chatOpenLinkConfirm => 'Open link';

  @override
  String chatInvalidLink(Object url) {
    return 'Invalid link: $url';
  }

  @override
  String chatUnableToOpenHost(Object host) {
    return 'Unable to open $host';
  }

  @override
  String get chatSaveAsDraft => 'Save as draft';

  @override
  String get chatDraftUnavailable => 'Drafts are unavailable right now.';

  @override
  String get chatDraftMissingContent =>
      'Add a message, subject, or attachment before saving.';

  @override
  String get chatDraftSaved => 'Saved to Drafts.';

  @override
  String get chatDraftSaveFailed => 'Failed to save draft. Try again.';

  @override
  String get chatInvitePermissionDenied =>
      'You do not have permission to invite users to this room.';

  @override
  String get chatInviteDomainRestricted =>
      'Invites are limited to the default domain.';

  @override
  String get chatInviteAlreadyMember => 'User is already a member.';

  @override
  String get chatInviteSent => 'Invite sent.';

  @override
  String get chatInviteSendFailed => 'Failed to send invite.';

  @override
  String get chatInviteRevoked => 'Invite revoked';

  @override
  String get chatInviteRevokeFailed => 'Failed to revoke invite.';

  @override
  String get chatInviteJoinSuccess => 'Joined room.';

  @override
  String get chatInviteJoinFailed => 'Could not join room.';

  @override
  String get chatNicknameUpdated => 'Nickname updated.';

  @override
  String get chatNicknameUpdateFailed => 'Could not change nickname.';

  @override
  String get chatRoomAvatarPermissionDenied =>
      'You do not have permission to update the room avatar.';

  @override
  String get chatRoomAvatarUpdated => 'Room avatar updated.';

  @override
  String get chatRoomAvatarUpdateFailed => 'Could not update room avatar.';

  @override
  String get chatPinPermissionDenied =>
      'You do not have permission to pin messages in this room.';

  @override
  String get chatMessageForwarded => 'Message forwarded.';

  @override
  String get chatMessageForwardFailed => 'Unable to forward message.';

  @override
  String chatModerationRequested(Object action, Object nickname) {
    return 'Requested $action for $nickname.';
  }

  @override
  String get chatModerationFailed =>
      'Could not complete that action. Check permissions or connectivity.';

  @override
  String get chatAttachmentInaccessible => 'Selected file is not accessible.';

  @override
  String get chatAttachmentFailed => 'Unable to attach file.';

  @override
  String get chatAttachmentView => 'View';

  @override
  String get chatAttachmentRetry => 'Retry upload';

  @override
  String get chatAttachmentRemove => 'Remove attachment';

  @override
  String get commonClose => 'Close';

  @override
  String get toastWhoopsTitle => 'Whoops';

  @override
  String get toastHeadsUpTitle => 'Heads up';

  @override
  String get toastAllSetTitle => 'All set';

  @override
  String get chatRoomMembers => 'Room members';

  @override
  String get chatCloseSettings => 'Close settings';

  @override
  String get chatSettings => 'Chat settings';

  @override
  String get chatEmptySearch => 'No matches';

  @override
  String get chatEmptyMessages => 'No messages';

  @override
  String get chatComposerEmailHint => 'Send email message';

  @override
  String get chatComposerEmailWatermark => 'Sent from Axichat';

  @override
  String get chatTransportChoiceTitle => 'Choose how to send';

  @override
  String chatTransportChoiceMessage(Object address) {
    return 'This address could be chat or email. How should Axichat send to $address?';
  }

  @override
  String get chatComposerMessageHint => 'Send message';

  @override
  String chatComposerFromHint(Object address) {
    return 'Sending from $address';
  }

  @override
  String get chatComposerEmptyMessage => 'Message cannot be empty.';

  @override
  String get chatComposerEmailUnavailable =>
      'Email sending is unavailable for this chat.';

  @override
  String get chatComposerFileUploadUnavailable =>
      'File upload is not available on this server.';

  @override
  String get chatComposerSelectRecipient => 'Select at least one recipient.';

  @override
  String get chatComposerEmailRecipientUnavailable =>
      'Email is unavailable for one or more recipients.';

  @override
  String get chatComposerEmailAttachmentRecipientRequired =>
      'Add an email recipient to send attachments.';

  @override
  String get chatComposerDraftRecipientsUnavailable =>
      'Unable to resolve recipients for this draft.';

  @override
  String get chatComposerSendFailed =>
      'Unable to send message. Please try again.';

  @override
  String get chatComposerAttachmentBundleFailed =>
      'Unable to bundle attachments. Please try again.';

  @override
  String get chatEmailOfflineRetryMessage =>
      'Email is offline. Retry once sync recovers.';

  @override
  String get chatEmailOfflineDraftsFallback =>
      'Email is offline. Messages will be saved to Drafts until the connection returns.';

  @override
  String get chatEmailSyncRefreshing => 'Email sync is refreshing...';

  @override
  String get chatEmailSyncFailed => 'Email sync failed. Please try again.';

  @override
  String get chatReadOnly => 'Read only';

  @override
  String get chatUnarchivePrompt => 'Unarchive to send new messages.';

  @override
  String get chatEmojiPicker => 'Emoji picker';

  @override
  String get chatShowingDirectOnly => 'Showing direct only';

  @override
  String get chatShowingAll => 'Showing all';

  @override
  String get chatMuteNotifications => 'Mute notifications';

  @override
  String get chatEnableNotifications => 'Enable notifications';

  @override
  String get chatMoveToInbox => 'Move to inbox';

  @override
  String get chatReportSpam => 'Mark as spam';

  @override
  String get chatSignatureToggleLabel => 'Include share token footer for email';

  @override
  String get chatSignatureHintEnabled =>
      'Helps keep multi-recipient email threads intact.';

  @override
  String get chatSignatureHintDisabled =>
      'Disabled globally; replies may not thread.';

  @override
  String get chatSignatureHintWarning =>
      'Disabling can break threading and attachment grouping.';

  @override
  String get chatInvite => 'Invite';

  @override
  String get chatReactionsNone => 'No reactions yet';

  @override
  String get chatReactionsPrompt => 'Tap a reaction to add or remove yours';

  @override
  String get chatReactionsPick => 'Pick an emoji to react';

  @override
  String get chatActionReply => 'Reply';

  @override
  String get chatActionForward => 'Forward';

  @override
  String get chatActionResend => 'Resend';

  @override
  String get chatActionEdit => 'Edit';

  @override
  String get chatActionRevoke => 'Revoke';

  @override
  String get chatActionCopy => 'Copy';

  @override
  String get chatActionShare => 'Share';

  @override
  String get chatActionAddToCalendar => 'Add to calendar';

  @override
  String get chatCalendarTaskCopyActionLabel => 'Copy to calendar';

  @override
  String get chatCalendarTaskImportConfirmTitle => 'Add to calendar?';

  @override
  String get chatCalendarTaskImportConfirmMessage =>
      'This task came from chat. Add it to your calendar to manage or edit it.';

  @override
  String get chatCalendarTaskImportConfirmLabel => 'Add to calendar';

  @override
  String get chatCalendarTaskImportCancelLabel => 'Not now';

  @override
  String get chatCalendarTaskCopyUnavailableMessage =>
      'Calendar is unavailable.';

  @override
  String get chatCalendarTaskCopyAlreadyAddedMessage => 'Task already added.';

  @override
  String get chatCalendarTaskCopySuccessMessage => 'Task copied.';

  @override
  String get chatActionDetails => 'Details';

  @override
  String get chatActionSelect => 'Select';

  @override
  String get chatActionReact => 'React';

  @override
  String get chatContactRenameAction => 'Rename';

  @override
  String get chatContactRenameTooltip => 'Rename contact';

  @override
  String get chatContactRenameTitle => 'Rename contact';

  @override
  String get chatContactRenameDescription =>
      'Choose how this contact appears across Axichat.';

  @override
  String get chatContactRenamePlaceholder => 'Display name';

  @override
  String get chatContactRenameReset => 'Reset to default';

  @override
  String get chatContactRenameSave => 'Save';

  @override
  String get chatContactRenameSuccess => 'Display name updated';

  @override
  String get chatContactRenameFailure => 'Could not rename contact';

  @override
  String get chatComposerSemantics => 'Message input';

  @override
  String get draftSaved => 'Draft saved';

  @override
  String get draftAutosaved => 'Autosaved';

  @override
  String get draftErrorTitle => 'Whoops';

  @override
  String get draftNoRecipients => 'No recipients';

  @override
  String get draftSubjectSemantics => 'Email subject';

  @override
  String get draftSubjectHintOptional => 'Subject (optional)';

  @override
  String get draftMessageSemantics => 'Message body';

  @override
  String get draftMessageHint => 'Message';

  @override
  String get draftSendingStatus => 'Sending...';

  @override
  String get draftSendingEllipsis => 'Sending…';

  @override
  String get draftSend => 'Send draft';

  @override
  String get draftDiscard => 'Discard';

  @override
  String get draftSave => 'Save draft';

  @override
  String get draftAttachmentInaccessible => 'Selected file is not accessible.';

  @override
  String get draftAttachmentFailed => 'Unable to attach file.';

  @override
  String get draftDiscarded => 'Draft discarded.';

  @override
  String get draftSendFailed => 'Failed to send draft.';

  @override
  String get draftSent => 'Sent';

  @override
  String draftLimitWarning(int limit, int count) {
    return 'Draft sync keeps up to $limit drafts. You\'re at $count.';
  }

  @override
  String get draftValidationNoContent =>
      'Add a subject, message, or attachment';

  @override
  String draftFileMissing(Object path) {
    return 'File no longer exists at $path.';
  }

  @override
  String get draftAttachmentPreview => 'Preview';

  @override
  String get draftRemoveAttachment => 'Remove attachment';

  @override
  String get draftNoAttachments => 'No attachments yet';

  @override
  String get draftAttachmentsLabel => 'Attachments';

  @override
  String get draftAddAttachment => 'Add attachment';

  @override
  String draftTaskDue(Object date) {
    return 'Due $date';
  }

  @override
  String get draftTaskNoSchedule => 'No schedule';

  @override
  String get draftTaskUntitled => 'Untitled task';

  @override
  String get chatBack => 'Back';

  @override
  String get chatErrorLabel => 'Error!';

  @override
  String get chatSenderYou => 'You';

  @override
  String get chatInviteAlreadyInRoom => 'Already in this room.';

  @override
  String get chatInviteWrongAccount => 'Invite is not for this account.';

  @override
  String get chatShareNoText => 'Message has no text to share';

  @override
  String get chatShareFallbackSubject => 'Axichat message';

  @override
  String chatShareSubjectPrefix(Object chatTitle) {
    return 'Shared from $chatTitle';
  }

  @override
  String get chatCalendarNoText => 'Message has no text to add to calendar';

  @override
  String get chatCalendarUnavailable => 'Calendar is unavailable right now';

  @override
  String get chatCopyNoText => 'Selected messages have no text to copy';

  @override
  String get chatCopySuccessMessage => 'Copied to clipboard';

  @override
  String get chatShareSelectedNoText =>
      'Selected messages have no text to share';

  @override
  String get chatForwardInviteForbidden => 'Invites cannot be forwarded.';

  @override
  String get chatAddToCalendarNoText =>
      'Selected messages have no text to add to calendar';

  @override
  String get chatForwardDialogTitle => 'Forward to...';

  @override
  String get chatForwardEmailWarningTitle => 'Forward email?';

  @override
  String get chatForwardEmailWarningMessage =>
      'Forwarding email can include original headers and external image links. Choose how to send.';

  @override
  String get chatForwardEmailOptionSafe => 'Forward as new message';

  @override
  String get chatForwardEmailOptionOriginal => 'Forward original';

  @override
  String get chatComposerAttachmentWarning =>
      'Large attachments are sent separately to each recipient and may take longer to deliver.';

  @override
  String chatFanOutRecipientLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'recipients',
      one: 'recipient',
    );
    return '$_temp0';
  }

  @override
  String chatFanOutFailureWithSubject(
      Object subject, int count, Object recipientLabel) {
    return 'Subject \"$subject\" failed to send to $count $recipientLabel.';
  }

  @override
  String chatFanOutFailure(int count, Object recipientLabel) {
    return 'Failed to send to $count $recipientLabel.';
  }

  @override
  String get chatFanOutRetry => 'Retry';

  @override
  String get chatSubjectSemantics => 'Email subject';

  @override
  String get chatSubjectHint => 'Subject';

  @override
  String get chatAttachmentTooltip => 'Attachments';

  @override
  String get chatPinnedMessagesTooltip => 'Pinned messages';

  @override
  String get chatPinnedMessagesTitle => 'Pinned messages';

  @override
  String get chatPinMessage => 'Pin message';

  @override
  String get chatUnpinMessage => 'Unpin message';

  @override
  String get chatPinnedEmptyState => 'No pinned messages yet.';

  @override
  String get chatPinnedMissingMessage => 'Pinned message is unavailable.';

  @override
  String get chatSendMessageTooltip => 'Send message';

  @override
  String get chatBlockAction => 'Block';

  @override
  String get chatReactionMore => 'More';

  @override
  String get chatQuotedNoContent => '(no content)';

  @override
  String get chatReplyingTo => 'Replying to...';

  @override
  String get chatCancelReply => 'Cancel reply';

  @override
  String get chatMessageRetracted => '(retracted)';

  @override
  String get chatMessageEdited => '(edited)';

  @override
  String get chatGuestAttachmentsDisabled =>
      'Attachments are disabled in preview.';

  @override
  String get chatGuestSubtitle => 'Guest preview • Stored locally';

  @override
  String recipientsOverflowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more',
      one: '+1 more',
    );
    return '$_temp0';
  }

  @override
  String get recipientsCollapse => 'Collapse';

  @override
  String recipientsSemantics(int count, Object state) {
    return 'Recipients $count, $state';
  }

  @override
  String get recipientsStateCollapsed => 'collapsed';

  @override
  String get recipientsStateExpanded => 'expanded';

  @override
  String get recipientsHintExpand => 'Press to expand';

  @override
  String get recipientsHintCollapse => 'Press to collapse';

  @override
  String get recipientsHeaderTitle => 'Send to...';

  @override
  String get recipientsFallbackLabel => 'Recipient';

  @override
  String get recipientsAddHint => 'Add...';

  @override
  String get chatGuestScriptWelcome =>
      'Welcome to Axichat—chat, email, and calendar in one place.';

  @override
  String get chatGuestScriptExternalQuestion =>
      'Looks clean. Can I message people who aren\'t on Axichat?';

  @override
  String get chatGuestScriptExternalAnswer =>
      'Yep—send chat-formatted email to Gmail, Outlook, Tuta, and more. If both of you use Axichat you also get groupchats, reactions, delivery receipts, and more.';

  @override
  String get chatGuestScriptOfflineQuestion =>
      'Does it work offline or in guest mode?';

  @override
  String get chatGuestScriptOfflineAnswer =>
      'Yes—offline functionality is built in, and the calendar even works in Guest Mode without an account or internet.';

  @override
  String get chatGuestScriptKeepUpQuestion =>
      'How does it help me keep up with everything?';

  @override
  String get chatGuestScriptKeepUpAnswer =>
      'Our calendar does natural language scheduling, Eisenhower Matrix triage, drag-and-drop, and reminders so you can focus on what matters.';

  @override
  String calendarParserUnavailable(Object errorType) {
    return 'Parser unavailable ($errorType)';
  }

  @override
  String get calendarAddTaskTitle => 'Add Task';

  @override
  String get calendarTaskNameRequired => 'Task name *';

  @override
  String get calendarTaskNameHint => 'Task name';

  @override
  String get calendarDescriptionHint => 'Description (optional)';

  @override
  String get calendarLocationHint => 'Location (optional)';

  @override
  String get calendarScheduleLabel => 'Schedule';

  @override
  String get calendarDeadlineLabel => 'Deadline';

  @override
  String get calendarRepeatLabel => 'Repeat';

  @override
  String get calendarCancel => 'Cancel';

  @override
  String get calendarAddTaskAction => 'Add Task';

  @override
  String get calendarSelectionMode => 'Selection mode';

  @override
  String get calendarExit => 'Exit';

  @override
  String calendarTasksSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# tasks selected',
      one: '# task selected',
    );
    return '$_temp0';
  }

  @override
  String get calendarActions => 'Actions';

  @override
  String get calendarSetPriority => 'Set priority';

  @override
  String get calendarClearSelection => 'Clear Selection';

  @override
  String get calendarExportSelected => 'Export selected';

  @override
  String get calendarDeleteSelected => 'Delete selected';

  @override
  String get calendarBatchEdit => 'Batch edit';

  @override
  String get calendarBatchTitle => 'Title';

  @override
  String get calendarBatchTitleHint => 'Set title for selected tasks';

  @override
  String get calendarBatchDescription => 'Description';

  @override
  String get calendarBatchDescriptionHint =>
      'Set description (leave blank to clear)';

  @override
  String get calendarBatchLocation => 'Location';

  @override
  String get calendarBatchLocationHint => 'Set location (leave blank to clear)';

  @override
  String get calendarApplyChanges => 'Apply changes';

  @override
  String get calendarAdjustTime => 'Adjust time';

  @override
  String get calendarSelectionRequired =>
      'Select tasks before applying changes.';

  @override
  String get calendarSelectionNone => 'Select tasks to export first.';

  @override
  String get calendarSelectionChangesApplied =>
      'Changes applied to selected tasks.';

  @override
  String get calendarSelectionNoPending => 'No pending changes to apply.';

  @override
  String get calendarSelectionTitleBlank => 'Title cannot be blank.';

  @override
  String get calendarExportReady => 'Export ready to share.';

  @override
  String calendarExportFailed(Object error) {
    return 'Failed to export selected tasks: $error';
  }

  @override
  String get commonBack => 'Back';

  @override
  String get composeTitle => 'Compose';

  @override
  String get draftComposeMessage => 'Compose a message';

  @override
  String get draftCompose => 'Compose';

  @override
  String get draftNewMessage => 'New message';

  @override
  String get draftRestore => 'Restore';

  @override
  String get draftRestoreAction => 'Restore from draft';

  @override
  String get draftMinimize => 'Minimize';

  @override
  String get draftExpand => 'Expand';

  @override
  String get draftExitFullscreen => 'Exit fullscreen';

  @override
  String get draftCloseComposer => 'Close composer';

  @override
  String get draftsEmpty => 'No drafts yet';

  @override
  String get draftsDeleteConfirm => 'Delete draft?';

  @override
  String get draftNoSubject => '(no subject)';

  @override
  String draftRecipientCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipients',
      one: '1 recipient',
    );
    return '$_temp0';
  }

  @override
  String get authCreatingAccount => 'Creating your account…';

  @override
  String get authSecuringLogin => 'Securing your login…';

  @override
  String get authLoggingIn => 'Logging you in…';

  @override
  String get authToggleSignup => 'New? Sign up';

  @override
  String get authToggleLogin => 'Already registered? Log in';

  @override
  String get authGuestCalendarCta => 'Try Calendar (Guest Mode)';

  @override
  String get authLogin => 'Log in';

  @override
  String get authRememberMeLabel => 'Remember me on this device';

  @override
  String get authSignUp => 'Sign up';

  @override
  String get authToggleSelected => 'Current selection';

  @override
  String authToggleSelectHint(Object label) {
    return 'Activate to select $label';
  }

  @override
  String get authUsername => 'Username';

  @override
  String get authUsernameRequired => 'Enter a username';

  @override
  String get authUsernameRules =>
      '4-20 alphanumeric, allowing \".\", \"_\" and \"-\".';

  @override
  String get authUsernameCaseInsensitive => 'Case insensitive';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordConfirm => 'Confirm password';

  @override
  String get authPasswordRequired => 'Enter a password';

  @override
  String authPasswordMaxLength(Object max) {
    return 'Must be $max characters or fewer';
  }

  @override
  String get authPasswordsMismatch => 'Passwords don\'t match';

  @override
  String get authPasswordPending => 'Checking password safety';

  @override
  String get authSignupPending => 'Waiting for signup';

  @override
  String get authLoginPending => 'Waiting for login';

  @override
  String get signupTitle => 'Sign up';

  @override
  String get signupStepUsername => 'Choose username';

  @override
  String get signupStepPassword => 'Create password';

  @override
  String get signupStepCaptcha => 'Verify captcha';

  @override
  String get signupStepSetup => 'Setup';

  @override
  String signupErrorPrefix(Object message) {
    return 'Error: $message';
  }

  @override
  String get signupCaptchaUnavailable => 'Captcha unavailable';

  @override
  String get signupCaptchaChallenge => 'Captcha challenge';

  @override
  String get signupCaptchaFailed =>
      'Captcha failed to load. Use reload to try again.';

  @override
  String get signupCaptchaLoading => 'Captcha loading';

  @override
  String get signupCaptchaInstructions =>
      'Enter the characters shown in this captcha image.';

  @override
  String get signupCaptchaReload => 'Reload captcha';

  @override
  String get signupCaptchaReloadHint =>
      'Get a new captcha image if you cannot read this one.';

  @override
  String get signupCaptchaPlaceholder => 'Enter the above text';

  @override
  String get signupCaptchaValidation => 'Enter the text from the image';

  @override
  String get signupContinue => 'Continue';

  @override
  String get signupProgressLabel => 'Signup progress';

  @override
  String signupProgressValue(
      Object current, Object currentLabel, Object percent, Object total) {
    return 'Step $current of $total: $currentLabel. $percent% complete.';
  }

  @override
  String get signupProgressSection => 'Account setup';

  @override
  String get signupPasswordStrength => 'Password strength';

  @override
  String get signupPasswordBreached =>
      'This password has been found in a hacked database.';

  @override
  String get signupStrengthNone => 'None';

  @override
  String get signupStrengthWeak => 'Weak';

  @override
  String get signupStrengthMedium => 'Medium';

  @override
  String get signupStrengthStronger => 'Stronger';

  @override
  String get signupRiskAcknowledgement => 'I understand the risk';

  @override
  String get signupRiskError => 'Check the box above to continue.';

  @override
  String get signupRiskAllowBreach =>
      'Allow this password even though it appeared in a breach.';

  @override
  String get signupRiskAllowWeak =>
      'Allow this password even though it is considered weak.';

  @override
  String get signupCaptchaErrorMessage =>
      'Unable to load captcha.\nTap refresh to try again.';

  @override
  String get signupAvatarRenderError => 'Could not render that avatar.';

  @override
  String get signupAvatarLoadError => 'Unable to load that avatar.';

  @override
  String get signupAvatarReadError => 'Could not read that image.';

  @override
  String get signupAvatarOpenError => 'Unable to open that file.';

  @override
  String get signupAvatarInvalidImage => 'That file is not a valid image.';

  @override
  String signupAvatarSizeError(Object kilobytes) {
    return 'Avatar must be under $kilobytes KB.';
  }

  @override
  String get signupAvatarProcessError => 'Unable to process that image.';

  @override
  String get signupAvatarEdit => 'Edit avatar';

  @override
  String get signupAvatarUploadImage => 'Upload image';

  @override
  String get signupAvatarUpload => 'Upload';

  @override
  String get signupAvatarShuffle => 'Shuffle default';

  @override
  String get signupAvatarMenuDescription =>
      'We publish the avatar when your XMPP account is created.';

  @override
  String get avatarSaveAvatar => 'Save avatar';

  @override
  String get avatarUseThis => 'Set avatar';

  @override
  String get signupAvatarBackgroundColor => 'Background color';

  @override
  String get signupAvatarDefaultsTitle => 'Default avatars';

  @override
  String get signupAvatarCategoryAbstract => 'Abstract';

  @override
  String get signupAvatarCategoryScience => 'Science';

  @override
  String get signupAvatarCategorySports => 'Sports';

  @override
  String get signupAvatarCategoryMusic => 'Music';

  @override
  String get notificationsRestartTitle => 'Restart app to enable notifications';

  @override
  String get notificationsRestartSubtitle =>
      'Required permissions already granted';

  @override
  String get notificationsMessageToggle => 'Message notifications';

  @override
  String get notificationsRequiresRestart => 'Requires restart';

  @override
  String get notificationsDialogTitle => 'Enable message notifications';

  @override
  String get notificationsDialogIgnore => 'Ignore';

  @override
  String get notificationsDialogContinue => 'Continue';

  @override
  String get notificationsDialogDescription =>
      'Chats can always be muted later.';

  @override
  String get calendarAdjustStartMinus => 'Start -15m';

  @override
  String get calendarAdjustStartPlus => 'Start +15m';

  @override
  String get calendarAdjustEndMinus => 'End -15m';

  @override
  String get calendarAdjustEndPlus => 'End +15m';

  @override
  String get calendarCopyToClipboardAction => 'Copy to Clipboard';

  @override
  String calendarCopyLocation(Object location) {
    return 'Location: $location';
  }

  @override
  String get calendarTaskCopied => 'Task copied';

  @override
  String get calendarTaskCopiedClipboard => 'Task copied to clipboard';

  @override
  String get calendarCopyTask => 'Copy Task';

  @override
  String get calendarDeleteTask => 'Delete Task';

  @override
  String get calendarSelectionNoneShort => 'No tasks selected.';

  @override
  String get calendarSelectionMixedRecurrence =>
      'Tasks have different recurrence settings. Updates will apply to all selected tasks.';

  @override
  String get calendarSelectionNoTasksHint =>
      'No tasks selected. Use the Select option in the calendar to pick tasks to edit.';

  @override
  String get calendarSelectionRemove => 'Remove from selection';

  @override
  String get calendarQuickTaskHint =>
      'Quick task (e.g., \"Meeting at 2pm in Room 101\")';

  @override
  String get calendarAdvancedHide => 'Hide advanced options';

  @override
  String get calendarAdvancedShow => 'Show advanced options';

  @override
  String get calendarUnscheduledTitle => 'Unscheduled tasks';

  @override
  String get calendarUnscheduledEmptyLabel => 'No unscheduled tasks';

  @override
  String get calendarUnscheduledEmptyHint => 'Tasks you add will appear here';

  @override
  String get calendarRemindersTitle => 'Reminders';

  @override
  String get calendarRemindersEmptyLabel => 'No reminders yet';

  @override
  String get calendarRemindersEmptyHint =>
      'Add a deadline to create a reminder';

  @override
  String get calendarNothingHere => 'Nothing here yet';

  @override
  String get calendarTaskNotFound => 'Task not found';

  @override
  String get calendarDayEventsTitle => 'Day events';

  @override
  String get calendarDayEventsEmpty => 'No day-level events for this date';

  @override
  String get calendarDayEventsAdd => 'Add day event';

  @override
  String get accessibilityNewContactLabel => 'Contact address';

  @override
  String get accessibilityNewContactHint => 'someone@example.com';

  @override
  String get accessibilityStartChat => 'Start chat';

  @override
  String get accessibilityStartChatHint =>
      'Submit this address to start a conversation.';

  @override
  String get accessibilityMessagesEmpty => 'No messages yet';

  @override
  String get accessibilityMessageNoContent => 'No message content';

  @override
  String get accessibilityActionsTitle => 'Actions';

  @override
  String get accessibilityReadNewMessages => 'Read new messages';

  @override
  String get accessibilityUnreadSummaryDescription =>
      'Focus on conversations with unread messages';

  @override
  String get accessibilityStartNewChat => 'Start a new chat';

  @override
  String get accessibilityStartNewChatDescription =>
      'Pick a contact or type an address';

  @override
  String get accessibilityInvitesTitle => 'Invites';

  @override
  String get accessibilityPendingInvites => 'Pending invites';

  @override
  String get accessibilityAcceptInvite => 'Accept invite';

  @override
  String get accessibilityInviteAccepted => 'Invite accepted';

  @override
  String get accessibilityInviteDismissed => 'Invite dismissed';

  @override
  String get accessibilityInviteUpdateFailed => 'Unable to update invite';

  @override
  String get accessibilityUnreadEmpty => 'No unread conversations';

  @override
  String get accessibilityInvitesEmpty => 'No pending invites';

  @override
  String get accessibilityMessagesTitle => 'Messages';

  @override
  String get accessibilityNoConversationSelected => 'No conversation selected';

  @override
  String accessibilityMessagesWithContact(Object name) {
    return 'Messages with $name';
  }

  @override
  String accessibilityMessageLabel(
      Object sender, Object timestamp, Object body) {
    return '$sender at $timestamp: $body';
  }

  @override
  String get accessibilityMessageSent => 'Message sent.';

  @override
  String get accessibilityDiscardWarning =>
      'Press Escape again to discard your message and close this step.';

  @override
  String get accessibilityDraftLoaded =>
      'Draft loaded. Press Escape to exit or Save to keep edits.';

  @override
  String accessibilityDraftLabel(Object id) {
    return 'Draft $id';
  }

  @override
  String accessibilityDraftLabelWithRecipients(Object recipients) {
    return 'Draft to $recipients';
  }

  @override
  String accessibilityDraftPreview(Object recipients, Object preview) {
    return '$recipients — $preview';
  }

  @override
  String accessibilityIncomingMessageStatus(Object sender, Object time) {
    return 'New message from $sender at $time';
  }

  @override
  String accessibilityAttachmentWithName(Object filename) {
    return 'Attachment: $filename';
  }

  @override
  String get accessibilityAttachmentGeneric => 'Attachment';

  @override
  String get accessibilityUploadAvailable => 'Upload available';

  @override
  String get accessibilityUnknownContact => 'Unknown contact';

  @override
  String get accessibilityChooseContact => 'Choose a contact';

  @override
  String get accessibilityUnreadConversations => 'Unread conversations';

  @override
  String get accessibilityStartNewAddress => 'Start a new address';

  @override
  String accessibilityConversationWith(Object name) {
    return 'Conversation with $name';
  }

  @override
  String get accessibilityConversationLabel => 'Conversation';

  @override
  String get accessibilityDialogLabel => 'Accessibility actions dialog';

  @override
  String get accessibilityDialogHint =>
      'Press Tab to reach shortcut instructions, use arrow keys inside lists, Shift plus arrows to move between groups, or Escape to exit.';

  @override
  String get accessibilityNoActionsAvailable =>
      'No actions available right now';

  @override
  String accessibilityBreadcrumbLabel(
      Object position, Object total, Object label) {
    return 'Step $position of $total: $label. Activate to jump to this step.';
  }

  @override
  String get accessibilityShortcutOpenMenu => 'Open menu';

  @override
  String get accessibilityShortcutBack => 'Back a step or close';

  @override
  String get accessibilityShortcutNextFocus => 'Next focus target';

  @override
  String get accessibilityShortcutPreviousFocus => 'Previous focus target';

  @override
  String get accessibilityShortcutActivateItem => 'Activate item';

  @override
  String get accessibilityShortcutNextItem => 'Next item';

  @override
  String get accessibilityShortcutPreviousItem => 'Previous item';

  @override
  String get accessibilityShortcutNextGroup => 'Next group';

  @override
  String get accessibilityShortcutPreviousGroup => 'Previous group';

  @override
  String get accessibilityShortcutFirstItem => 'First item';

  @override
  String get accessibilityShortcutLastItem => 'Last item';

  @override
  String get accessibilityKeyboardShortcutsTitle => 'Keyboard shortcuts';

  @override
  String accessibilityKeyboardShortcutAnnouncement(Object description) {
    return 'Keyboard shortcut: $description';
  }

  @override
  String get accessibilityTextFieldHint =>
      'Enter text. Use Tab to move forward or Escape to go back or close the menu.';

  @override
  String get accessibilityLoadingLabel => 'Loading';

  @override
  String get accessibilityComposerPlaceholder => 'Type a message';

  @override
  String accessibilityRecipientLabel(Object name) {
    return 'Recipient $name';
  }

  @override
  String get accessibilityRecipientRemoveHint =>
      'Press backspace or delete to remove';

  @override
  String get accessibilityMessageActionsLabel => 'Message actions';

  @override
  String get accessibilityMessageActionsHint =>
      'Save as draft or send this message';

  @override
  String accessibilityMessagePosition(Object position, Object total) {
    return 'Message $position of $total';
  }

  @override
  String get accessibilityNoMessages => 'No messages';

  @override
  String accessibilityMessageMetadata(Object sender, Object timestamp) {
    return 'From $sender at $timestamp';
  }

  @override
  String accessibilityMessageFrom(Object sender) {
    return 'From $sender';
  }

  @override
  String get accessibilityMessageNavigationHint =>
      'Use arrow keys to move between messages. Shift plus arrows switches groups. Press Escape to exit.';

  @override
  String accessibilitySectionSummary(Object section, Object count) {
    return '$section section with $count items';
  }

  @override
  String accessibilityActionListLabel(Object count) {
    return 'Accessibility action list with $count items';
  }

  @override
  String get accessibilityActionListHint =>
      'Use arrow keys to move, Shift plus arrows to switch groups, Home or End to jump, Enter to activate, Escape to exit.';

  @override
  String accessibilityActionItemPosition(
      Object position, Object total, Object section) {
    return 'Item $position of $total in $section';
  }

  @override
  String get accessibilityActionReadOnlyHint =>
      'Use arrow keys to move through the list';

  @override
  String get accessibilityActionActivateHint => 'Press Enter to activate';

  @override
  String get accessibilityDismissHighlight => 'Dismiss highlight';

  @override
  String get accessibilityNeedsAttention => 'Needs attention';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileJumpToTop => 'Back to top';

  @override
  String get settingsWebsiteLabel => 'Website';

  @override
  String get settingsDonateLabel => 'Donate';

  @override
  String get settingsMastodonLabel => 'Mastodon';

  @override
  String get settingsGithubLabel => 'GitHub';

  @override
  String get settingsGitlabLabel => 'GitLab';

  @override
  String get profileJidDescription =>
      'This is your Jabber ID. Comprised of your username and domain, it\'s a unique address that represents you on the XMPP network.';

  @override
  String get profileResourceDescription =>
      'This is your XMPP resource. Every device you use has a different one, which is why your phone can have a different presence to your desktop.';

  @override
  String get profileStatusPlaceholder => 'Status message';

  @override
  String get profileArchives => 'View archives';

  @override
  String get profileEditAvatar => 'Edit avatar';

  @override
  String get profileLinkedEmailAccounts => 'Email accounts';

  @override
  String get profileChangePassword => 'Change password';

  @override
  String get profileDeleteAccount => 'Delete account';

  @override
  String profileExportActionLabel(Object label) {
    return 'Export $label';
  }

  @override
  String get profileExportXmppMessagesLabel => 'XMPP messages';

  @override
  String get profileExportXmppContactsLabel => 'XMPP contacts';

  @override
  String get profileExportEmailMessagesLabel => 'Emails';

  @override
  String get profileExportEmailContactsLabel => 'Email contacts';

  @override
  String profileExportShareText(Object label) {
    return 'Axichat export: $label';
  }

  @override
  String profileExportShareSubject(Object label) {
    return 'Axichat $label export';
  }

  @override
  String profileExportReadyMessage(Object label) {
    return '$label export ready.';
  }

  @override
  String profileExportEmptyMessage(Object label) {
    return 'No $label to export.';
  }

  @override
  String profileExportFailedMessage(Object label) {
    return 'Unable to export $label.';
  }

  @override
  String profileExportShareUnsupportedMessage(Object label, Object path) {
    return 'Sharing isn\'t available on this platform. $label export saved to $path.';
  }

  @override
  String get profileExportCopyPathAction => 'Copy path';

  @override
  String get profileExportPathCopiedMessage =>
      'Export path copied to clipboard.';

  @override
  String get profileExportFormatTitle => 'Choose export format';

  @override
  String get profileExportFormatCsvTitle => 'CSV (.csv)';

  @override
  String get profileExportFormatCsvSubtitle => 'Works with most address books.';

  @override
  String get profileExportFormatVcardTitle => 'vCard (.vcf)';

  @override
  String get profileExportFormatVcardSubtitle => 'Standard contact cards.';

  @override
  String get profileExportCsvHeaderName => 'Name';

  @override
  String get profileExportCsvHeaderAddress => 'Address';

  @override
  String get profileExportContactsFilenameFallback => 'contacts';

  @override
  String get termsAcceptLabel => 'I accept the terms and conditions';

  @override
  String get termsAgreementPrefix => 'You agree to our ';

  @override
  String get termsAgreementTerms => 'terms';

  @override
  String get termsAgreementAnd => ' and ';

  @override
  String get termsAgreementPrivacy => 'privacy';

  @override
  String get termsAgreementError => 'You must accept the terms and conditions';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSave => 'Save';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonSend => 'Send';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get settingsButtonLabel => 'Settings';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSectionData => 'Data';

  @override
  String get settingsSectionImportant => 'Important';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionSecurity => 'Security';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsThemeMode => 'Theme mode';

  @override
  String get settingsThemeModeSystem => 'System';

  @override
  String get settingsThemeModeLight => 'Light';

  @override
  String get settingsThemeModeDark => 'Dark';

  @override
  String get settingsColorScheme => 'Color scheme';

  @override
  String get settingsColorfulAvatars => 'Colorful avatars';

  @override
  String get settingsColorfulAvatarsDescription =>
      'Generate different background colors for each avatar.';

  @override
  String get settingsLowMotion => 'Low motion';

  @override
  String get settingsLowMotionDescription =>
      'Disables most animations. Better for slow devices.';

  @override
  String get settingsSectionChats => 'Chat preferences';

  @override
  String get settingsSectionEmail => 'Email preferences';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsAboutAxichat => 'About Axichat';

  @override
  String get settingsAboutLegalese =>
      'Copyright (C) 2025 Axichat LLC\n\nThis program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.\n\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.\n\nYou should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.';

  @override
  String get settingsTermsLabel => 'Terms';

  @override
  String get settingsPrivacyLabel => 'Privacy';

  @override
  String get settingsLicenseAgpl => 'AGPLv3';

  @override
  String get settingsMuteNotifications => 'Mute notifications';

  @override
  String get settingsMuteNotificationsDescription =>
      'Stop receiving message notifications.';

  @override
  String get settingsNotificationPreviews => 'Notification previews';

  @override
  String get settingsNotificationPreviewsDescription =>
      'Show message content in notifications and on the lock screen.';

  @override
  String get settingsChatReadReceipts => 'Send chat read receipts';

  @override
  String get settingsChatReadReceiptsDescription =>
      'When on, opening a chat while the app is active sends read receipts for visible messages.';

  @override
  String get settingsChatSendOnEnter => 'Send chat messages on Enter';

  @override
  String get settingsChatSendOnEnterDescription =>
      'When on, pressing Enter sends chat messages. Shift+Enter inserts a new line.';

  @override
  String get settingsEmailReadReceipts => 'Send email read receipts';

  @override
  String get settingsEmailReadReceiptsDescription =>
      'When on, opening an email chat while the app is active sends read receipts (MDNs) for visible messages.';

  @override
  String get settingsEmailSendOnEnter => 'Send email messages on Enter';

  @override
  String get settingsEmailSendOnEnterDescription =>
      'When on, pressing Enter sends email messages. Shift+Enter inserts a new line.';

  @override
  String get settingsEmailComposerWatermark => 'Prepopulate email watermark';

  @override
  String get settingsEmailComposerWatermarkDescription =>
      'Pre-fills new email messages with \"Sent from Axichat\" text that you can edit or delete.';

  @override
  String get settingsTypingIndicators => 'Send typing indicators';

  @override
  String get settingsTypingIndicatorsDescription =>
      'Let other people in a chat see when you are typing.';

  @override
  String get settingsShareTokenFooter => 'Include share token footer';

  @override
  String get settingsShareTokenFooterDescription =>
      'Adds Axichat share tokens for multi-recipient email fan-out to preserve linking and threading.';

  @override
  String get authCustomServerTitle => 'Custom server';

  @override
  String get authCustomServerDescription =>
      'Override XMPP/SMTP endpoints or enable DNS lookups. Leave fields blank to keep defaults. Custom servers must be created following the steps at https://github.com/axichat/server or they probably won\'t work.';

  @override
  String get authCustomServerDomainOrIp => 'Domain';

  @override
  String get authCustomServerXmppLabel => 'XMPP';

  @override
  String get authCustomServerSmtpLabel => 'SMTP';

  @override
  String get authCustomServerUseDns => 'Use DNS';

  @override
  String get authCustomServerUseSrv => 'Use SRV';

  @override
  String get authCustomServerRequireDnssec => 'Require DNSSEC';

  @override
  String get authCustomServerXmppHostPlaceholder => 'XMPP host (optional)';

  @override
  String get authCustomServerPortPlaceholder => 'Port';

  @override
  String get authCustomServerSmtpHostPlaceholder => 'SMTP host (optional)';

  @override
  String get authCustomServerImapHostPlaceholder => 'IMAP host (optional)';

  @override
  String get authCustomServerApiPortPlaceholder => 'API port';

  @override
  String get authCustomServerEmailProvisioningUrlPlaceholder =>
      'Email provisioning URL (optional)';

  @override
  String get authCustomServerEmailPublicTokenPlaceholder =>
      'Email public token (optional)';

  @override
  String get authCustomServerReset => 'Reset to axi.im';

  @override
  String get authCustomServerOpenSettings => 'Open custom server settings';

  @override
  String get authCustomServerAdvancedHint =>
      'Advanced server options stay hidden until you tap the username suffix.';

  @override
  String get authUnregisterTitle => 'Unregister';

  @override
  String get authUnregisterConfirmTitle => 'Delete account?';

  @override
  String get authUnregisterConfirmMessage =>
      'This will permanently delete your account and local data. This cannot be undone.';

  @override
  String get authUnregisterConfirmAction => 'Delete account';

  @override
  String get authUnregisterProgressLabel => 'Waiting for account deletion';

  @override
  String get authPasswordPlaceholder => 'Password';

  @override
  String get authPasswordCurrentPlaceholder => 'Old password';

  @override
  String get authPasswordNewPlaceholder => 'New password';

  @override
  String get authPasswordConfirmNewPlaceholder => 'Confirm new password';

  @override
  String get authChangePasswordProgressLabel => 'Waiting for password change';

  @override
  String get authLogoutTitle => 'Log out';

  @override
  String get authLogoutNormal => 'Log out';

  @override
  String get authLogoutNormalDescription => 'Sign out of this account.';

  @override
  String get authLogoutBurn => 'Burn account';

  @override
  String get authLogoutBurnDescription =>
      'Sign out and clear local data for this account.';

  @override
  String get chatAttachmentBlockedTitle => 'Attachment blocked';

  @override
  String get chatEmailImageBlockedLabel => 'Image blocked';

  @override
  String get chatEmailImageFailedLabel => 'Image failed';

  @override
  String get chatAttachmentBlockedDescription =>
      'Load attachments from unknown contacts only if you trust them. We will fetch it once you approve.';

  @override
  String get chatAttachmentLoad => 'Load attachment';

  @override
  String get chatAttachmentUnavailable => 'Attachment unavailable';

  @override
  String get chatAttachmentSendFailed => 'Unable to send attachment.';

  @override
  String get chatAttachmentRetryUpload => 'Retry upload';

  @override
  String get chatAttachmentRemoveAttachment => 'Remove attachment';

  @override
  String get chatAttachmentStatusUploading => 'Uploading attachment…';

  @override
  String get chatAttachmentStatusQueued => 'Waiting to send';

  @override
  String get chatAttachmentStatusFailed => 'Upload failed';

  @override
  String get chatAttachmentLoading => 'Loading attachment';

  @override
  String chatAttachmentLoadingProgress(Object percent) {
    return 'Loading $percent';
  }

  @override
  String get chatAttachmentDownload => 'Download attachment';

  @override
  String get chatAttachmentDownloadAndOpen => 'Download and open';

  @override
  String get chatAttachmentDownloadAndSave => 'Download and save';

  @override
  String get chatAttachmentDownloadAndShare => 'Download and share';

  @override
  String get chatAttachmentExportTitle => 'Save attachment?';

  @override
  String get chatAttachmentExportMessage =>
      'This will copy the attachment to shared storage. Exports are unencrypted and may be readable by other apps. Continue?';

  @override
  String get chatAttachmentExportConfirm => 'Save';

  @override
  String get chatAttachmentExportCancel => 'Cancel';

  @override
  String get chatMediaMetadataWarningTitle => 'Media may include metadata';

  @override
  String get chatMediaMetadataWarningMessage =>
      'Photos and videos can include location and device details. Continue?';

  @override
  String get chatNotificationPreviewOptionInherit => 'Use app setting';

  @override
  String get chatNotificationPreviewOptionShow => 'Always show previews';

  @override
  String get chatNotificationPreviewOptionHide => 'Always hide previews';

  @override
  String get chatAttachmentUnavailableDevice =>
      'Attachment is no longer available on this device';

  @override
  String get chatAttachmentInvalidLink => 'Invalid attachment link';

  @override
  String chatAttachmentOpenFailed(Object target) {
    return 'Could not open $target';
  }

  @override
  String get chatAttachmentTypeMismatchTitle => 'Attachment type mismatch';

  @override
  String chatAttachmentTypeMismatchMessage(Object declared, Object detected) {
    return 'This attachment says it is $declared, but the file looks like $detected. Opening it could be unsafe. Continue?';
  }

  @override
  String get chatAttachmentTypeMismatchConfirm => 'Open anyway';

  @override
  String get chatAttachmentHighRiskTitle => 'Potentially unsafe file';

  @override
  String get chatAttachmentHighRiskMessage =>
      'This file type can be dangerous to open. We recommend saving it and scanning it before opening. Continue?';

  @override
  String get chatAttachmentUnknownSize => 'Unknown size';

  @override
  String get chatAttachmentNotDownloadedYet => 'Not downloaded yet';

  @override
  String chatAttachmentErrorTooltip(Object message, Object fileName) {
    return '$message ($fileName)';
  }

  @override
  String get chatAttachmentMenuHint => 'Open menu for actions.';

  @override
  String get accessibilityActionsLabel => 'Accessibility actions';

  @override
  String accessibilityActionsShortcutTooltip(Object shortcut) {
    return 'Accessibility actions ($shortcut)';
  }

  @override
  String get shorebirdUpdateAvailable =>
      'Update available: log out and restart the app';

  @override
  String get calendarEditTaskTitle => 'Edit task';

  @override
  String get calendarDateTimeLabel => 'Date & time';

  @override
  String get calendarSelectDate => 'Select date';

  @override
  String get calendarSelectTime => 'Select time';

  @override
  String get calendarDurationLabel => 'Duration';

  @override
  String get calendarSelectDuration => 'Select duration';

  @override
  String get calendarAddToCriticalPath => 'Add to critical path';

  @override
  String get calendarNoCriticalPathMembership => 'Not in any critical paths';

  @override
  String get calendarGuestTitle => 'Guest calendar';

  @override
  String get calendarGuestBanner => 'Guest Mode - No Sync';

  @override
  String get calendarGuestModeLabel => 'Guest mode';

  @override
  String get calendarGuestModeDescription =>
      'Log in to sync tasks across devices and enable reminders.';

  @override
  String get calendarNoTasksForDate => 'No tasks for this date';

  @override
  String get calendarTapToCreateTask => 'Tap + to create a new task';

  @override
  String get calendarQuickStats => 'Quick stats';

  @override
  String get calendarDueReminders => 'Due reminders';

  @override
  String get calendarNextTaskLabel => 'Next task';

  @override
  String get calendarNone => 'None';

  @override
  String get calendarViewLabel => 'View';

  @override
  String get calendarViewDay => 'Day';

  @override
  String get calendarViewWeek => 'Week';

  @override
  String get calendarViewMonth => 'Month';

  @override
  String get calendarPreviousDate => 'Previous date';

  @override
  String get calendarNextDate => 'Next date';

  @override
  String calendarPreviousUnit(Object unit) {
    return 'Previous $unit';
  }

  @override
  String calendarNextUnit(Object unit) {
    return 'Next $unit';
  }

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarUndo => 'Undo';

  @override
  String get calendarRedo => 'Redo';

  @override
  String get calendarOpeningCreator => 'Opening task creator...';

  @override
  String calendarWeekOf(Object date) {
    return 'Week of $date';
  }

  @override
  String get calendarStatusCompleted => 'Completed';

  @override
  String get calendarStatusOverdue => 'Overdue';

  @override
  String get calendarStatusDueSoon => 'Due soon';

  @override
  String get calendarStatusPending => 'Pending';

  @override
  String get calendarTaskCompletedMessage => 'Task completed!';

  @override
  String get calendarTaskUpdatedMessage => 'Task updated!';

  @override
  String get calendarErrorTitle => 'Error';

  @override
  String get calendarErrorTaskNotFound => 'Task not found';

  @override
  String get calendarErrorTitleEmpty => 'Title cannot be empty';

  @override
  String get calendarErrorTitleTooLong => 'Title too long';

  @override
  String get calendarErrorDescriptionTooLong => 'Description too long';

  @override
  String get calendarErrorInputInvalid => 'Input invalid';

  @override
  String get calendarErrorAddFailed => 'Failed to add task';

  @override
  String get calendarErrorUpdateFailed => 'Failed to update task';

  @override
  String get calendarErrorDeleteFailed => 'Failed to delete task';

  @override
  String get calendarErrorNetwork => 'Network error';

  @override
  String get calendarErrorStorage => 'Storage error';

  @override
  String get calendarErrorUnknown => 'Unknown error';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonSelect => 'Select';

  @override
  String get commonExport => 'Export';

  @override
  String get commonFavorite => 'Favorite';

  @override
  String get commonUnfavorite => 'Unfavorite';

  @override
  String get commonArchive => 'Archive';

  @override
  String get commonUnarchive => 'Unarchive';

  @override
  String get commonShow => 'Show';

  @override
  String get commonHide => 'Hide';

  @override
  String get blocklistBlockUser => 'Block user';

  @override
  String get blocklistWaitingForUnblock => 'Awaiting unblock';

  @override
  String get blocklistUnblockAll => 'Unblock all';

  @override
  String get blocklistUnblock => 'Unblock';

  @override
  String get blocklistBlock => 'Block';

  @override
  String get blocklistAddTooltip => 'Add to blocklist';

  @override
  String get blocklistInvalidJid => 'Enter a valid address.';

  @override
  String blocklistBlockFailed(Object address) {
    return 'Failed to block $address. Try again later.';
  }

  @override
  String blocklistUnblockFailed(Object address) {
    return 'Failed to unblock $address. Try again later.';
  }

  @override
  String blocklistBlocked(Object address) {
    return 'Blocked $address.';
  }

  @override
  String blocklistUnblocked(Object address) {
    return 'Unblocked $address.';
  }

  @override
  String get blocklistBlockingUnsupported =>
      'Server does not support blocking.';

  @override
  String get blocklistUnblockingUnsupported =>
      'Server does not support unblocking.';

  @override
  String get blocklistUnblockAllFailed =>
      'Failed to unblock users. Try again later.';

  @override
  String get blocklistUnblockAllSuccess => 'Unblocked all.';

  @override
  String get mucChangeNickname => 'Change nickname';

  @override
  String mucChangeNicknameWithCurrent(Object current) {
    return 'Change nickname (current: $current)';
  }

  @override
  String get mucLeaveRoom => 'Leave room';

  @override
  String get mucNoMembers => 'No members yet';

  @override
  String get mucInviteUsers => 'Invite users';

  @override
  String get mucSendInvites => 'Send invites';

  @override
  String get mucChangeNicknameTitle => 'Change nickname';

  @override
  String get mucEnterNicknamePlaceholder => 'Enter a nickname';

  @override
  String get mucUpdateNickname => 'Update';

  @override
  String get mucMembersTitle => 'Members';

  @override
  String get mucEditAvatar => 'Edit room avatar';

  @override
  String get mucAvatarMenuDescription => 'Room members will see this avatar.';

  @override
  String get mucInviteUser => 'Invite user';

  @override
  String get mucSectionOwners => 'Owners';

  @override
  String get mucSectionAdmins => 'Admins';

  @override
  String get mucSectionModerators => 'Moderators';

  @override
  String get mucSectionMembers => 'Members';

  @override
  String get mucSectionVisitors => 'Visitors';

  @override
  String get mucRoleOwner => 'Owner';

  @override
  String get mucRoleAdmin => 'Admin';

  @override
  String get mucRoleMember => 'Member';

  @override
  String get mucRoleVisitor => 'Visitor';

  @override
  String get mucRoleModerator => 'Moderator';

  @override
  String get mucActionKick => 'Kick';

  @override
  String get mucActionBan => 'Ban';

  @override
  String get mucActionMakeMember => 'Make member';

  @override
  String get mucActionMakeAdmin => 'Make admin';

  @override
  String get mucActionMakeOwner => 'Make owner';

  @override
  String get mucActionGrantModerator => 'Grant moderator';

  @override
  String get mucActionRevokeModerator => 'Revoke moderator';

  @override
  String get chatsEmptyList => 'No chats yet';

  @override
  String chatsDeleteConfirmMessage(Object chatTitle) {
    return 'Delete chat: $chatTitle';
  }

  @override
  String get chatsDeleteMessagesOption => 'Permanently delete messages';

  @override
  String get chatsDeleteSuccess => 'Chat deleted';

  @override
  String get chatsExportNoContent => 'No text content to export';

  @override
  String get chatsExportShareText => 'Chat export from Axichat';

  @override
  String chatsExportShareSubject(Object chatTitle) {
    return 'Chat with $chatTitle';
  }

  @override
  String get chatsExportSuccess => 'Chat exported';

  @override
  String get chatsExportFailure => 'Unable to export chat';

  @override
  String get chatExportWarningTitle => 'Export chat history?';

  @override
  String get chatExportWarningMessage =>
      'Chat exports are unencrypted and may be readable by other apps or cloud services. Continue?';

  @override
  String get chatsArchivedRestored => 'Chat restored';

  @override
  String get chatsArchivedHint => 'Chat archived (Profile → Archived chats)';

  @override
  String get chatsVisibleNotice => 'Chat is visible again';

  @override
  String get chatsHiddenNotice => 'Chat hidden (use filter to reveal)';

  @override
  String chatsUnreadLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# unread messages',
      one: '# unread message',
      zero: 'No unread messages',
    );
    return '$_temp0';
  }

  @override
  String get chatsSemanticsUnselectHint => 'Press to unselect chat';

  @override
  String get chatsSemanticsSelectHint => 'Press to select chat';

  @override
  String get chatsSemanticsOpenHint => 'Press to open chat';

  @override
  String get chatsHideActions => 'Hide chat actions';

  @override
  String get chatsShowActions => 'Show chat actions';

  @override
  String get chatsSelectedLabel => 'Chat selected';

  @override
  String get chatsSelectLabel => 'Select chat';

  @override
  String get chatsExportFileLabel => 'chats';

  @override
  String get chatSelectionExportEmptyTitle => 'No messages to export';

  @override
  String get chatSelectionExportEmptyMessage =>
      'Select chats with text content';

  @override
  String get chatSelectionExportShareText => 'Chat exports from Axichat';

  @override
  String get chatSelectionExportShareSubject => 'Axichat chats export';

  @override
  String get chatSelectionExportReadyTitle => 'Export ready';

  @override
  String chatSelectionExportReadyMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Shared # chats',
      one: 'Shared # chat',
    );
    return '$_temp0';
  }

  @override
  String get chatSelectionExportFailedTitle => 'Export failed';

  @override
  String get chatSelectionExportFailedMessage =>
      'Unable to export selected chats';

  @override
  String get chatSelectionDeleteConfirmTitle => 'Delete chats?';

  @override
  String chatSelectionDeleteConfirmMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This removes # chats and all of their messages. This cannot be undone.',
      one:
          'This removes 1 chat and all of its messages. This cannot be undone.',
    );
    return '$_temp0';
  }

  @override
  String get chatsCreateGroupChatTooltip => 'Create group chat';

  @override
  String get chatsCreateGroupSuccess => 'Group chat created.';

  @override
  String get chatsCreateGroupFailure => 'Could not create group chat.';

  @override
  String get chatsRefreshFailed => 'Sync failed.';

  @override
  String get chatsRoomLabel => 'Room';

  @override
  String get chatsCreateChatRoomTitle => 'Create chat room';

  @override
  String get chatsCreateChatRoomAction => 'Create room';

  @override
  String get chatsRoomNamePlaceholder => 'Name';

  @override
  String get chatsRoomNameRequiredError => 'Room name cannot be empty.';

  @override
  String chatsRoomNameInvalidCharacterError(Object character) {
    return 'Room names cannot contain $character.';
  }

  @override
  String get chatsArchiveTitle => 'Archive';

  @override
  String get chatsArchiveEmpty => 'No archived chats yet';

  @override
  String calendarTileNow(Object title) {
    return 'Now: $title';
  }

  @override
  String calendarTileNext(Object title) {
    return 'Next: $title';
  }

  @override
  String get calendarTileNone => 'No upcoming tasks';

  @override
  String get calendarViewDayShort => 'D';

  @override
  String get calendarViewWeekShort => 'W';

  @override
  String get calendarViewMonthShort => 'M';

  @override
  String get calendarShowCompleted => 'Show completed';

  @override
  String get calendarHideCompleted => 'Hide completed';

  @override
  String get rosterAddTooltip => 'Add to roster';

  @override
  String get rosterAddLabel => 'Contact';

  @override
  String get rosterAddTitle => 'Add contact';

  @override
  String get rosterEmpty => 'No contacts yet';

  @override
  String get rosterCompose => 'Compose';

  @override
  String rosterRemoveConfirm(Object jid) {
    return 'Remove $jid from contacts?';
  }

  @override
  String get rosterInvitesEmpty => 'No invites yet';

  @override
  String rosterRejectInviteConfirm(Object jid) {
    return 'Reject invite from $jid?';
  }

  @override
  String get rosterAddContactTooltip => 'Add contact';

  @override
  String get jidInputPlaceholder => 'john@axi.im';

  @override
  String get jidInputInvalid => 'Enter a valid JID';

  @override
  String get sessionCapabilityChat => 'Chat';

  @override
  String get sessionCapabilityEmail => 'Email';

  @override
  String get sessionCapabilityStatusConnected => 'Connected';

  @override
  String get sessionCapabilityStatusConnecting => 'Connecting';

  @override
  String get sessionCapabilityStatusError => 'Error';

  @override
  String get sessionCapabilityStatusOffline => 'Offline';

  @override
  String get sessionCapabilityStatusOff => 'Off';

  @override
  String get sessionCapabilityStatusSyncing => 'Syncing';

  @override
  String get emailSyncMessageSyncing => 'Syncing email...';

  @override
  String get emailSyncMessageConnecting => 'Connecting to email servers...';

  @override
  String get emailSyncMessageDisconnected => 'Disconnected from email servers.';

  @override
  String get emailSyncMessageGroupMembershipChanged =>
      'Email group membership changed. Try reopening the chat.';

  @override
  String get emailSyncMessageHistorySyncing => 'Syncing email history...';

  @override
  String get emailSyncMessageRetrying => 'Email sync will retry shortly...';

  @override
  String get emailSyncMessageRefreshing =>
      'Refreshing email sync after interruption…';

  @override
  String get emailSyncMessageRefreshFailed =>
      'Email sync could not refresh. Try reopening the app.';

  @override
  String get authChangePasswordPending => 'Updating password...';

  @override
  String get authEndpointAdvancedHint => 'Advanced options';

  @override
  String get authEndpointApiPortPlaceholder => 'API port';

  @override
  String get authEndpointDescription =>
      'Configure XMPP/SMTP endpoints for this account.';

  @override
  String get authEndpointDomainPlaceholder => 'Domain';

  @override
  String get authEndpointPortPlaceholder => 'Port';

  @override
  String get authEndpointRequireDnssecLabel => 'Require DNSSEC';

  @override
  String get authEndpointReset => 'Reset';

  @override
  String get authEndpointSmtpHostPlaceholder => 'SMTP host';

  @override
  String get authEndpointSmtpLabel => 'SMTP';

  @override
  String get authEndpointTitle => 'Endpoint configuration';

  @override
  String get authEndpointUseDnsLabel => 'Use DNS';

  @override
  String get authEndpointUseSrvLabel => 'Use SRV';

  @override
  String get authEndpointXmppHostPlaceholder => 'XMPP host';

  @override
  String get authEndpointXmppLabel => 'XMPP';

  @override
  String get authUnregisterPending => 'Unregistering...';

  @override
  String calendarAddTaskError(Object details) {
    return 'Could not add task: $details';
  }

  @override
  String get calendarBackToCalendar => 'Back to calendar';

  @override
  String get calendarLoadingMessage => 'Loading calendar...';

  @override
  String get calendarCriticalPathAddTask => 'Add task';

  @override
  String get calendarCriticalPathAddToTitle => 'Add to critical path';

  @override
  String get calendarCriticalPathCreatePrompt =>
      'Create a critical path to get started';

  @override
  String get calendarCriticalPathDragHint => 'Drag tasks to reorder';

  @override
  String get calendarCriticalPathEmptyTasks => 'No tasks in this path yet';

  @override
  String get calendarCriticalPathNameEmptyError => 'Enter a name';

  @override
  String get calendarCriticalPathNamePlaceholder => 'Critical path name';

  @override
  String get calendarCriticalPathNamePrompt => 'Name';

  @override
  String get calendarCriticalPathTaskOrderTitle => 'Order tasks';

  @override
  String get calendarCriticalPathsAll => 'All paths';

  @override
  String get calendarCriticalPathsEmpty => 'No critical paths yet';

  @override
  String get calendarCriticalPathsNew => 'New critical path';

  @override
  String get calendarCriticalPathRenameTitle => 'Rename critical path';

  @override
  String get calendarCriticalPathDeleteTitle => 'Delete critical path';

  @override
  String get calendarCriticalPathsTitle => 'Critical paths';

  @override
  String get calendarCriticalPathShareAction => 'Share to chat';

  @override
  String get calendarCriticalPathShareTitle => 'Share critical path';

  @override
  String get calendarCriticalPathShareSubtitle =>
      'Send a critical path to a chat.';

  @override
  String get calendarCriticalPathShareTargetLabel => 'Share with';

  @override
  String get calendarCriticalPathShareButtonLabel => 'Share';

  @override
  String get calendarCriticalPathShareMissingChats =>
      'No eligible chats available.';

  @override
  String get calendarCriticalPathShareMissingRecipient =>
      'Select a chat to share with.';

  @override
  String get calendarCriticalPathShareMissingService =>
      'Calendar sharing is unavailable.';

  @override
  String get calendarCriticalPathShareDenied =>
      'Calendar cards are disabled for your role in this room.';

  @override
  String get calendarCriticalPathShareFailed =>
      'Failed to share critical path.';

  @override
  String get calendarCriticalPathShareSuccess => 'Critical path shared.';

  @override
  String get calendarCriticalPathShareChatTypeDirect => 'Direct chat';

  @override
  String get calendarCriticalPathShareChatTypeGroup => 'Group chat';

  @override
  String get calendarCriticalPathShareChatTypeNote => 'Notes';

  @override
  String calendarCriticalPathProgressSummary(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$completed of $total tasks completed in order',
      one: '$completed of $total task completed in order',
    );
    return '$_temp0';
  }

  @override
  String get calendarCriticalPathProgressHint =>
      'Complete tasks in the listed order to advance';

  @override
  String get calendarCriticalPathProgressLabel => 'Progress';

  @override
  String calendarCriticalPathProgressPercent(int percent) {
    return '$percent%';
  }

  @override
  String get calendarCriticalPathFocus => 'Focus';

  @override
  String get calendarCriticalPathUnfocus => 'Unfocus';

  @override
  String get calendarCriticalPathCompletedLabel => 'Completed';

  @override
  String calendarCriticalPathQueuedAdd(Object name) {
    return 'Will add to \"$name\" on save';
  }

  @override
  String calendarCriticalPathQueuedCreate(Object name) {
    return 'Created \"$name\" and queued';
  }

  @override
  String get calendarCriticalPathUnavailable =>
      'Critical paths are unavailable in this view.';

  @override
  String get calendarCriticalPathAddAfterSaveFailed =>
      'Task saved but could not be added to a critical path.';

  @override
  String calendarCriticalPathAddSuccess(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count tasks to \"$name\".',
      one: 'Added to \"$name\".',
    );
    return '$_temp0';
  }

  @override
  String calendarCriticalPathCreateSuccess(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Created \"$name\" and added tasks.',
      one: 'Created \"$name\" and added task.',
    );
    return '$_temp0';
  }

  @override
  String calendarCriticalPathAddFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Unable to add tasks to a critical path.',
      one: 'Unable to add task to a critical path.',
    );
    return '$_temp0';
  }

  @override
  String calendarCriticalPathAlreadyContainsTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tasks already in this critical path.',
      one: 'Task already in this critical path.',
    );
    return '$_temp0';
  }

  @override
  String get calendarCriticalPathCreateFailed =>
      'Unable to create a critical path.';

  @override
  String get calendarTaskSearchTitle => 'Search tasks';

  @override
  String calendarTaskSearchAddToTitle(Object name) {
    return 'Add to $name';
  }

  @override
  String get calendarTaskSearchSubtitle =>
      'Search titles, descriptions, locations, categories, priorities, and deadlines.';

  @override
  String get calendarTaskSearchAddToSubtitle =>
      'Tap a task to append it to the critical path order.';

  @override
  String get calendarTaskSearchHint =>
      'title:, desc:, location:, category:work, priority:urgent, status:done';

  @override
  String get calendarTaskSearchEmptyPrompt => 'Start typing to search tasks';

  @override
  String get calendarTaskSearchEmptyNoResults => 'No results found';

  @override
  String get calendarTaskSearchEmptyHint =>
      'Use filters like title:, desc:, location:, priority:critical, status:done, deadline:today.';

  @override
  String get calendarTaskSearchFilterScheduled => 'Scheduled';

  @override
  String get calendarTaskSearchFilterUnscheduled => 'Unscheduled';

  @override
  String get calendarTaskSearchFilterReminders => 'Reminders';

  @override
  String get calendarTaskSearchFilterOpen => 'Open';

  @override
  String get calendarTaskSearchFilterCompleted => 'Completed';

  @override
  String calendarTaskSearchDueDate(Object date) {
    return 'Due $date';
  }

  @override
  String calendarTaskSearchOverdueDate(Object date) {
    return 'Overdue · $date';
  }

  @override
  String calendarDeleteTaskConfirm(Object title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get calendarErrorTitleEmptyFriendly => 'Title cannot be empty';

  @override
  String get calendarExportFormatIcsSubtitle =>
      'Compatible with other apps (recurrence & checklists excluded)';

  @override
  String get calendarExportFormatIcsTitle => 'Export .ics';

  @override
  String get calendarExportFormatJsonSubtitle =>
      'Full backup with all task data (Recommended)';

  @override
  String get calendarExportFormatJsonTitle => 'Export JSON';

  @override
  String calendarRemovePathConfirm(Object name) {
    return 'Remove this task from \"$name\"?';
  }

  @override
  String get calendarSandboxHint =>
      'Plan tasks here before assigning them to a path.';

  @override
  String get chatAlertHide => 'Hide';

  @override
  String get chatAlertIgnore => 'Ignore';

  @override
  String get chatAttachmentTapToLoad => 'Tap to load';

  @override
  String chatMessageAddRecipientSuccess(Object recipient) {
    return 'Added $recipient';
  }

  @override
  String get chatMessageAddRecipients => 'Add recipients';

  @override
  String get chatMessageCreateChat => 'Create chat';

  @override
  String chatMessageCreateChatFailure(Object reason) {
    return 'Could not create chat: $reason';
  }

  @override
  String get chatMessageInfoDevice => 'Device';

  @override
  String get chatMessageInfoError => 'Error';

  @override
  String get chatMessageInfoProtocol => 'Protocol';

  @override
  String get chatMessageInfoTimestamp => 'Timestamp';

  @override
  String get chatMessageOpenChat => 'Open chat';

  @override
  String get chatMessageStatusDisplayed => 'Read';

  @override
  String get chatMessageStatusReceived => 'Received';

  @override
  String get chatMessageStatusSent => 'Sent';

  @override
  String get commonActions => 'Actions';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String emailDemoAccountLabel(Object account) {
    return 'Account: $account';
  }

  @override
  String get emailDemoDefaultMessage => 'Hello from Axichat';

  @override
  String get emailDemoDisplayNameSelf => 'Self';

  @override
  String get emailDemoErrorMissingPassphrase => 'Missing database passphrase.';

  @override
  String get emailDemoErrorMissingPrefix => 'Missing database prefix.';

  @override
  String get emailDemoErrorMissingProfile =>
      'No primary profile found. Log in first.';

  @override
  String get emailDemoMessageLabel => 'Demo message';

  @override
  String get emailDemoProvisionButton => 'Provision Email';

  @override
  String get emailDemoSendButton => 'Send Demo Message';

  @override
  String get emailDemoStatusIdle => 'Idle';

  @override
  String emailDemoStatusLabel(Object status) {
    return 'Status: $status';
  }

  @override
  String get emailDemoStatusLoginToProvision => 'Log in to provision email.';

  @override
  String get emailDemoStatusNotProvisioned => 'Not provisioned';

  @override
  String emailDemoStatusProvisionFailed(Object error) {
    return 'Provisioning failed: $error';
  }

  @override
  String get emailDemoStatusProvisionFirst => 'Provision an account first.';

  @override
  String emailDemoStatusProvisioned(Object address) {
    return 'Provisioned $address';
  }

  @override
  String get emailDemoStatusProvisioning => 'Provisioning email account…';

  @override
  String get emailDemoStatusReady => 'Ready';

  @override
  String emailDemoStatusSendFailed(Object error) {
    return 'Send failed: $error';
  }

  @override
  String get emailDemoStatusSending => 'Sending demo message…';

  @override
  String emailDemoStatusSent(Object id) {
    return 'Sent demo message (id=$id)';
  }

  @override
  String get emailDemoTitle => 'Email Transport Demo';

  @override
  String get verificationAddLabelPlaceholder => 'Add label';

  @override
  String get verificationCurrentDevice => 'Current device';

  @override
  String verificationDeviceIdLabel(Object id) {
    return 'ID: $id';
  }

  @override
  String get verificationNotTrusted => 'Not trusted';

  @override
  String get verificationRegenerateDevice => 'Regenerate device';

  @override
  String get verificationRegenerateWarning =>
      'Only do this if you are an expert.';

  @override
  String get verificationTrustBlind => 'Blind trust';

  @override
  String get verificationTrustNone => 'No trust';

  @override
  String get verificationTrustVerified => 'Verified';

  @override
  String get verificationTrusted => 'Trusted';

  @override
  String get avatarSavedMessage => 'Avatar saved.';

  @override
  String get avatarOpenError => 'Unable to open that file.';

  @override
  String get avatarReadError => 'Could not read that file.';

  @override
  String get avatarInvalidImageError => 'That file is not a valid image.';

  @override
  String get avatarProcessError => 'Unable to process that image.';

  @override
  String get avatarTemplateLoadError => 'Failed to load that avatar option.';

  @override
  String get avatarMissingDraftError => 'Pick or build an avatar first.';

  @override
  String get avatarXmppDisconnectedError =>
      'Connect to XMPP before saving your avatar.';

  @override
  String get avatarPublishRejectedError =>
      'Your server rejected avatar publishing.';

  @override
  String get avatarPublishTimeoutError =>
      'Avatar upload timed out. Please try again.';

  @override
  String get avatarPublishGenericError =>
      'Could not publish avatar. Check your connection and try again.';

  @override
  String get avatarPublishUnexpectedError =>
      'Unexpected error while uploading avatar.';

  @override
  String get avatarCropTitle => 'Crop & focus';

  @override
  String get avatarCropDescription =>
      'Drag or resize the square to set your crop. Reset to center and follow the circle to match the saved avatar.';

  @override
  String get avatarCropPlaceholder =>
      'Add a photo or pick a default avatar to adjust the framing.';

  @override
  String avatarCropSizeLabel(Object pixels) {
    return '$pixels px crop';
  }

  @override
  String get avatarCropSavedSize => 'Saved at 256×256 • < 64 KB';

  @override
  String get avatarBackgroundTitle => 'Background color';

  @override
  String get avatarBackgroundDescription =>
      'Use the wheel or presets to tint transparent avatars before saving.';

  @override
  String get avatarBackgroundWheelTitle => 'Wheel & hex';

  @override
  String get avatarBackgroundWheelDescription =>
      'Drag the wheel or enter a hex value.';

  @override
  String get avatarBackgroundTransparent => 'Transparent';

  @override
  String get avatarBackgroundPreview => 'Preview saved circle tint.';

  @override
  String get avatarDefaultsTitle => 'Default avatars';

  @override
  String get avatarCategoryAbstract => 'Abstract';

  @override
  String get avatarCategoryStem => 'STEM';

  @override
  String get avatarCategorySports => 'Sports';

  @override
  String get avatarCategoryMusic => 'Music';

  @override
  String get avatarCategoryMisc => 'Hobbies & Games';

  @override
  String avatarTemplateAbstract(Object index) {
    return 'Abstract $index';
  }

  @override
  String get avatarTemplateAtom => 'Atom';

  @override
  String get avatarTemplateBeaker => 'Beaker';

  @override
  String get avatarTemplateCompass => 'Compass';

  @override
  String get avatarTemplateCpu => 'CPU';

  @override
  String get avatarTemplateGear => 'Gear';

  @override
  String get avatarTemplateGlobe => 'Globe';

  @override
  String get avatarTemplateLaptop => 'Laptop';

  @override
  String get avatarTemplateMicroscope => 'Microscope';

  @override
  String get avatarTemplateRobot => 'Robot';

  @override
  String get avatarTemplateStethoscope => 'Stethoscope';

  @override
  String get avatarTemplateTelescope => 'Telescope';

  @override
  String get avatarTemplateArchery => 'Archery';

  @override
  String get avatarTemplateBaseball => 'Baseball';

  @override
  String get avatarTemplateBasketball => 'Basketball';

  @override
  String get avatarTemplateBoxing => 'Boxing';

  @override
  String get avatarTemplateCycling => 'Cycling';

  @override
  String get avatarTemplateDarts => 'Darts';

  @override
  String get avatarTemplateFootball => 'Football';

  @override
  String get avatarTemplateGolf => 'Golf';

  @override
  String get avatarTemplatePingPong => 'Ping Pong';

  @override
  String get avatarTemplateSkiing => 'Skiing';

  @override
  String get avatarTemplateSoccer => 'Soccer';

  @override
  String get avatarTemplateTennis => 'Tennis';

  @override
  String get avatarTemplateVolleyball => 'Volleyball';

  @override
  String get avatarTemplateDrums => 'Drums';

  @override
  String get avatarTemplateElectricGuitar => 'Electric Guitar';

  @override
  String get avatarTemplateGuitar => 'Guitar';

  @override
  String get avatarTemplateMicrophone => 'Microphone';

  @override
  String get avatarTemplatePiano => 'Piano';

  @override
  String get avatarTemplateSaxophone => 'Saxophone';

  @override
  String get avatarTemplateViolin => 'Violin';

  @override
  String get avatarTemplateCards => 'Cards';

  @override
  String get avatarTemplateChess => 'Chess';

  @override
  String get avatarTemplateChessAlt => 'Chess Alt';

  @override
  String get avatarTemplateDice => 'Dice';

  @override
  String get avatarTemplateDiceAlt => 'Dice Alt';

  @override
  String get avatarTemplateEsports => 'Esports';

  @override
  String get avatarTemplateSword => 'Sword';

  @override
  String get avatarTemplateVideoGames => 'Video Games';

  @override
  String get avatarTemplateVideoGamesAlt => 'Video Games Alt';

  @override
  String get commonDone => 'Done';

  @override
  String get commonRename => 'Rename';

  @override
  String get calendarHour => 'Hour';

  @override
  String get calendarMinute => 'Minute';

  @override
  String get calendarPasteTaskHere => 'Paste Task Here';

  @override
  String get calendarQuickAddTask => 'Quick Add Task';

  @override
  String get calendarSplitTaskAt => 'Split task at';

  @override
  String get calendarAddDayEvent => 'Add day event';

  @override
  String get calendarZoomOut => 'Zoom out (Ctrl/Cmd + -)';

  @override
  String get calendarZoomIn => 'Zoom in (Ctrl/Cmd + +)';

  @override
  String get calendarChecklistItem => 'Checklist item';

  @override
  String get calendarRemoveItem => 'Remove item';

  @override
  String get calendarAddChecklistItem => 'Add checklist item';

  @override
  String get calendarRepeatTimes => 'Repeat times';

  @override
  String get calendarDayEventHint => 'Birthday, holiday, or note';

  @override
  String get calendarOptionalDetails => 'Optional details';

  @override
  String get calendarDates => 'Dates';

  @override
  String get calendarTaskTitleHint => 'Task title';

  @override
  String get calendarDescriptionOptionalHint => 'Description (optional)';

  @override
  String get calendarLocationOptionalHint => 'Location (optional)';

  @override
  String get calendarCloseTooltip => 'Close';

  @override
  String get calendarAddTaskInputHint =>
      'Add task... (e.g., \"Meeting tomorrow at 3pm\")';

  @override
  String get calendarBranch => 'Branch';

  @override
  String get calendarPickDifferentTask => 'Pick a different task for this slot';

  @override
  String get calendarSyncRequest => 'Request';

  @override
  String get calendarSyncPush => 'Push';

  @override
  String get calendarImportant => 'Important';

  @override
  String get calendarUrgent => 'Urgent';

  @override
  String get calendarClearSchedule => 'Clear schedule';

  @override
  String get calendarEditTaskTooltip => 'Edit task';

  @override
  String get calendarDeleteTaskTooltip => 'Delete task';

  @override
  String get calendarBackToChats => 'Back to chats';

  @override
  String get calendarBackToLogin => 'Back to login';

  @override
  String get calendarRemindersSection => 'Reminders';

  @override
  String get settingsAutoLoadEmailImages => 'Auto-load email images';

  @override
  String get settingsAutoLoadEmailImagesDescription =>
      'May reveal your IP address to senders';

  @override
  String get settingsAutoDownloadImages => 'Auto-download images';

  @override
  String get settingsAutoDownloadImagesDescription =>
      'Applies when this chat allows automatic downloads.';

  @override
  String get settingsAutoDownloadVideos => 'Auto-download videos';

  @override
  String get settingsAutoDownloadVideosDescription =>
      'Applies when this chat allows automatic downloads.';

  @override
  String get settingsAutoDownloadDocuments => 'Auto-download documents';

  @override
  String get settingsAutoDownloadDocumentsDescription =>
      'Applies when this chat allows automatic downloads.';

  @override
  String get settingsAutoDownloadArchives => 'Auto-download archives';

  @override
  String get settingsAutoDownloadArchivesDescription =>
      'Applies when this chat allows automatic downloads.';

  @override
  String get settingsAutoDownloadScopeAlways => 'Always';

  @override
  String get settingsAutoDownloadScopeTrustedContacts =>
      'Only for trusted contacts.';

  @override
  String get emailContactsImportTitle => 'Import contacts';

  @override
  String get emailContactsImportSubtitle =>
      'Gmail, Outlook, Yahoo CSVs, or vCards.';

  @override
  String get emailContactsImportFileAccessError =>
      'Unable to access the selected file.';

  @override
  String get emailContactsImportAction => 'Import';

  @override
  String get emailContactsImportFormatLabel => 'Format';

  @override
  String get emailContactsImportFileLabel => 'File';

  @override
  String get emailContactsImportNoFile => 'No file selected';

  @override
  String get emailContactsImportChooseFile => 'Choose file';

  @override
  String get emailContactsImportFormatGmail => 'Gmail CSV';

  @override
  String get emailContactsImportFormatOutlook => 'Outlook CSV';

  @override
  String get emailContactsImportFormatYahoo => 'Yahoo CSV';

  @override
  String get emailContactsImportFormatGenericCsv => 'Generic CSV';

  @override
  String get emailContactsImportFormatVcard => 'vCard (VCF)';

  @override
  String get emailContactsImportNoValidContacts => 'No valid contacts found.';

  @override
  String get emailContactsImportAccountRequired =>
      'Set up email before importing contacts.';

  @override
  String get emailContactsImportEmptyFile => 'The selected file is empty.';

  @override
  String get emailContactsImportReadFailure => 'Couldn\'t read that file.';

  @override
  String get emailContactsImportFileTooLarge =>
      'This file is too large to import.';

  @override
  String get emailContactsImportUnsupportedFile => 'Unsupported file type.';

  @override
  String get emailContactsImportNoContacts => 'No contacts found in that file.';

  @override
  String get emailContactsImportTooManyContacts =>
      'This file contains too many contacts to import.';

  @override
  String get emailContactsImportFailed => 'Import failed.';

  @override
  String emailContactsImportSuccess(
      Object imported, Object duplicates, Object invalid, Object failed) {
    return 'Imported $imported contacts. $duplicates duplicates, $invalid invalid, $failed failed.';
  }

  @override
  String get fanOutErrorNoRecipients => 'Select at least one recipient.';

  @override
  String get fanOutErrorResolveFailed => 'Couldn\'t resolve recipients.';

  @override
  String fanOutErrorTooManyRecipients(int max) {
    return 'Too many recipients (max $max).';
  }

  @override
  String get fanOutErrorEmptyMessage =>
      'Add a message or attachment before sending.';

  @override
  String get fanOutErrorInvalidShareToken => 'Share token is invalid.';

  @override
  String get emailForwardingGuideTitle => 'Connect existing email';

  @override
  String get emailForwardingGuideSubtitle =>
      'Forward mail from Gmail, Outlook, or any provider.';

  @override
  String get emailForwardingWelcomeTitle => 'Welcome to Axichat';

  @override
  String get emailForwardingGuideIntro =>
      'Keep your existing inbox and forward mail into Axichat.';

  @override
  String get emailForwardingGuideLinkExistingEmailTitle =>
      'Link existing email';

  @override
  String get emailForwardingGuideAddressHint =>
      'Enter this address in your provider\'s forwarding settings.';

  @override
  String get emailForwardingGuideAddressFallback =>
      'Your Axichat address will appear here.';

  @override
  String get emailForwardingGuideLinksTitle =>
      'This must be done in your existing email client. Your provider should have instructions. If you use Gmail or Outlook, here are their guides:';

  @override
  String get emailForwardingGuideLinksSubtitle =>
      'Search your provider\'s help docs, or start here:';

  @override
  String get emailForwardingGuideNotificationsTitle => 'Message notifications';

  @override
  String get emailForwardingGuideSettingsHint =>
      'This can be done later in settings.';

  @override
  String get emailForwardingGuideSkipLabel => 'Skip for now';

  @override
  String get emailForwardingProviderGmail => 'Gmail';

  @override
  String get emailForwardingProviderOutlook => 'Outlook';

  @override
  String get chatChooseTextToAdd => 'Choose text to add';

  @override
  String get notificationChannelMessages => 'Messages';

  @override
  String get notificationNewMessageTitle => 'New message';

  @override
  String get notificationOpenAction => 'Open notification';

  @override
  String get notificationAttachmentLabel => 'Attachment';

  @override
  String notificationAttachmentLabelWithName(String filename) {
    return 'Attachment: $filename';
  }

  @override
  String get notificationReactionFallback => 'New reaction';

  @override
  String notificationReactionLabel(String reaction) {
    return 'Reaction: $reaction';
  }

  @override
  String get notificationWebxdcFallback => 'New update';

  @override
  String get shareTokenFooterLabel => 'Please do not remove:';

  @override
  String get notificationBackgroundConnectionDisabledTitle =>
      'Background connection disabled';

  @override
  String get notificationBackgroundConnectionDisabledBody =>
      'Android blocked Axichat\'s message service. Re-enable overlay and battery optimization permissions to restore background messaging.';

  @override
  String get calendarReminderDeadlineNow => 'Deadline now';

  @override
  String calendarReminderDueIn(Object duration) {
    return 'Due in $duration';
  }

  @override
  String get calendarReminderStartingNow => 'Starting now';

  @override
  String calendarReminderStartsIn(Object duration) {
    return 'Starts in $duration';
  }

  @override
  String get calendarReminderHappeningToday => 'Happening today';

  @override
  String calendarReminderIn(Object duration) {
    return 'In $duration';
  }

  @override
  String calendarReminderDurationDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# days',
      one: '# day',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderDurationHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# hours',
      one: '# hour',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderDurationMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# minutes',
      one: '# minute',
    );
    return '$_temp0';
  }

  @override
  String get calendarExportCalendar => 'Export calendar';

  @override
  String get calendarImportCalendar => 'Import calendar';

  @override
  String get calendarSyncStatusSyncing => 'Syncing...';

  @override
  String get calendarSyncStatusFailed => 'Sync failed';

  @override
  String get calendarSyncStatusSynced => 'Synced';

  @override
  String get calendarSyncStatusIdle => 'Not synced yet';

  @override
  String calendarSplitTaskAtTime(Object time) {
    return 'Split task at $time';
  }

  @override
  String get calendarSplitSelectTime => 'Select split time';

  @override
  String get calendarTaskMarkIncomplete => 'Mark incomplete';

  @override
  String get calendarTaskMarkComplete => 'Mark complete';

  @override
  String get calendarTaskRemoveImportant => 'Remove important flag';

  @override
  String get calendarTaskMarkImportant => 'Mark as important';

  @override
  String get calendarTaskRemoveUrgent => 'Remove urgent flag';

  @override
  String get calendarTaskMarkUrgent => 'Mark as urgent';

  @override
  String get calendarDeselectTask => 'Deselect task';

  @override
  String get calendarAddTaskToSelection => 'Add task to selection';

  @override
  String get calendarSelectTask => 'Select task';

  @override
  String get calendarDeselectAllRepeats => 'Deselect all repeats';

  @override
  String get calendarAddAllRepeats => 'Add all repeats';

  @override
  String get calendarSelectAllRepeats => 'Select all repeats';

  @override
  String get calendarAddToSelection => 'Add to selection';

  @override
  String get calendarSelectAllTasks => 'Select all tasks';

  @override
  String get calendarExitSelectionMode => 'Exit selection mode';

  @override
  String get calendarSplitTask => 'Split task';

  @override
  String get calendarCopyTemplate => 'Copy template';

  @override
  String calendarTaskAddedMessage(Object title) {
    return 'Task \"$title\" added';
  }

  @override
  String calendarTasksAddedMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# tasks added',
      one: '# task added',
    );
    return '$_temp0';
  }

  @override
  String calendarTaskRemovedMessage(Object title) {
    return 'Task \"$title\" removed';
  }

  @override
  String calendarTasksRemovedMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# tasks removed',
      one: '# task removed',
    );
    return '$_temp0';
  }

  @override
  String get calendarTaskRemovedTitle => 'Task removed';

  @override
  String get calendarDeadlinePlaceholder => 'Set deadline (optional)';

  @override
  String get calendarTaskDescriptionHint => 'Description (optional)';

  @override
  String get calendarTaskLocationHint => 'Location (optional)';

  @override
  String get calendarPickDateLabel => 'Pick date';

  @override
  String get calendarPickTimeLabel => 'Pick time';

  @override
  String get calendarReminderLabel => 'Reminder';

  @override
  String get calendarEditDayEventTitle => 'Edit day event';

  @override
  String get calendarNewDayEventTitle => 'New day event';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonTitle => 'Title';

  @override
  String get calendarShareUnavailable => 'Calendar sharing is unavailable.';

  @override
  String get calendarShareAvailability => 'Share availability';

  @override
  String get calendarShortcutUndo => 'Ctrl/Cmd+Z';

  @override
  String get calendarShortcutRedo => 'Ctrl/Cmd+Shift+Z';

  @override
  String commonShortcutTooltip(Object tooltip, Object shortcut) {
    return '$tooltip ($shortcut)';
  }

  @override
  String get calendarDragCanceled => 'Drag canceled';

  @override
  String get calendarZoomLabelCompact => 'Compact';

  @override
  String get calendarZoomLabelComfort => 'Comfort';

  @override
  String get calendarZoomLabelExpanded => 'Expanded';

  @override
  String calendarZoomLabelMinutes(Object minutes) {
    return '${minutes}m';
  }

  @override
  String get calendarGuestModeNotice =>
      'Guest Mode - Tasks saved locally on this device only';

  @override
  String get calendarGuestSignUpToSync => 'Sign Up to Sync';

  @override
  String get calendarGuestExportNoData =>
      'No calendar data available to export.';

  @override
  String get calendarGuestExportTitle => 'Export guest calendar';

  @override
  String get calendarGuestExportShareSubject => 'Axichat guest calendar export';

  @override
  String calendarGuestExportShareText(Object format) {
    return 'Axichat guest calendar export ($format)';
  }

  @override
  String calendarGuestExportFailed(Object error) {
    return 'Failed to export calendar: $error';
  }

  @override
  String get calendarGuestImportTitle => 'Import calendar';

  @override
  String get calendarGuestImportWarningMessage =>
      'Importing will merge data and override matching items in your current calendar. Continue?';

  @override
  String get calendarGuestImportConfirmLabel => 'Import';

  @override
  String get calendarGuestImportFileAccessError =>
      'Unable to access the selected file.';

  @override
  String get calendarGuestImportNoData =>
      'No calendar data detected in the selected file.';

  @override
  String get calendarGuestImportFailed => 'Import failed to apply changes.';

  @override
  String get calendarGuestImportSuccess => 'Imported calendar data.';

  @override
  String get calendarGuestImportNoTasks =>
      'No tasks detected in the selected file.';

  @override
  String calendarGuestImportTasksSuccess(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# tasks',
      one: '# task',
    );
    return 'Imported $_temp0.';
  }

  @override
  String calendarGuestImportError(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get blocklistEmpty => 'Nobody blocked';

  @override
  String get chatMessageSubjectLabel => 'Subject';

  @override
  String get chatMessageRecipientsLabel => 'Recipients';

  @override
  String get chatMessageAlsoSentToLabel => 'Also sent to';

  @override
  String chatMessageFromLabel(Object sender) {
    return 'From $sender';
  }

  @override
  String get chatMessageReactionsLabel => 'Reactions';

  @override
  String get commonClearSelection => 'Clear selection';

  @override
  String commonSelectedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# selected',
      one: '# selected',
    );
    return '$_temp0';
  }

  @override
  String get profileDeviceFingerprint => 'Device Fingerprint';

  @override
  String get profileFingerprintUnavailable => 'Fingerprint unavailable';

  @override
  String get axiVersionCurrentFeatures => 'Current features:';

  @override
  String get axiVersionCurrentFeaturesList => 'Messaging, presence';

  @override
  String get axiVersionComingNext => 'Coming next:';

  @override
  String get axiVersionComingNextList => 'Groupchat, multimedia';

  @override
  String get commonMoreOptions => 'More options';

  @override
  String get commonAreYouSure => 'Are you sure?';

  @override
  String get commonAll => 'All';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseHongKong => '繁體中文 (香港)';

  @override
  String get languageSystemShort => 'SYS';

  @override
  String get languageEnglishShort => 'EN';

  @override
  String get languageGermanShort => 'DE';

  @override
  String get languageSpanishShort => 'ES';

  @override
  String get languageFrenchShort => 'FR';

  @override
  String get languageChineseSimplifiedShort => 'ZH';

  @override
  String get languageChineseHongKongShort => 'ZH-HK';

  @override
  String get languageSystemFlag => '🌐';

  @override
  String get languageEnglishFlag => '🇬🇧';

  @override
  String get languageGermanFlag => '🇩🇪';

  @override
  String get languageSpanishFlag => '🇪🇸';

  @override
  String get languageFrenchFlag => '🇫🇷';

  @override
  String get languageChineseSimplifiedFlag => '🇨🇳';

  @override
  String get languageChineseHongKongFlag => '🇭🇰';

  @override
  String get calendarTransferNoDataExport =>
      'No calendar data available to export.';

  @override
  String get calendarTransferExportSubject => 'Axichat calendar export';

  @override
  String calendarTransferExportText(String format) {
    return 'Axichat calendar export ($format)';
  }

  @override
  String get calendarTransferExportReady => 'Export ready to share.';

  @override
  String calendarTransferExportFailed(String error) {
    return 'Failed to export calendar: $error';
  }

  @override
  String get calendarTransferImportWarning =>
      'Importing will merge data and override matching items in your current calendar. Continue?';

  @override
  String get calendarTransferImportConfirm => 'Import';

  @override
  String get calendarTransferFileAccessFailed =>
      'Unable to access the selected file.';

  @override
  String get calendarTransferNoDataImport =>
      'No calendar data detected in the selected file.';

  @override
  String get calendarTransferImportFailed => 'Import failed to apply changes.';

  @override
  String get calendarTransferImportSuccess => 'Imported calendar data.';

  @override
  String get calendarTransferNoTasksDetected =>
      'No tasks detected in the selected file.';

  @override
  String calendarTransferImportTasksSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Imported $count task$_temp0.';
  }

  @override
  String calendarTransferImportFailedWithError(String error) {
    return 'Import failed: $error';
  }

  @override
  String get calendarExportChooseFormat => 'Choose export format';

  @override
  String get calendarAvailabilityWindowsTitle => 'Availability windows';

  @override
  String get calendarAvailabilityWindowsSubtitle =>
      'Define the time ranges you want to share.';

  @override
  String get calendarAvailabilityWindowsLabel => 'Windows';

  @override
  String get calendarAvailabilityNoWindows => 'No windows yet.';

  @override
  String get calendarAvailabilityWindowLabel => 'Window';

  @override
  String get calendarAvailabilitySummaryLabel => 'Summary';

  @override
  String get calendarAvailabilitySummaryHint => 'Optional label';

  @override
  String get calendarAvailabilityNotesLabel => 'Notes';

  @override
  String get calendarAvailabilityNotesHint => 'Optional details';

  @override
  String get calendarAvailabilityAddWindow => 'Add window';

  @override
  String get calendarAvailabilitySaveWindows => 'Save windows';

  @override
  String get calendarAvailabilityEmptyWindowsError =>
      'Add at least one availability window.';

  @override
  String get calendarAvailabilityInvalidRangeError =>
      'Check the window ranges before saving.';

  @override
  String get calendarTaskShareTitle => 'Share task';

  @override
  String get calendarTaskShareSubtitle => 'Send a task to a chat as .ics.';

  @override
  String get calendarTaskShareTarget => 'Share with';

  @override
  String get calendarTaskShareEditAccess => 'Edit access';

  @override
  String get calendarTaskShareReadOnlyLabel => 'Read only';

  @override
  String get calendarTaskShareEditableLabel => 'Editable';

  @override
  String get calendarTaskShareReadOnlyHint =>
      'Recipients can view this task, but only you can edit it.';

  @override
  String get calendarTaskShareEditableHint =>
      'Recipients can edit this task, and updates sync back to your calendar.';

  @override
  String get calendarTaskShareReadOnlyDisabledHint =>
      'Editing is only available for chat calendars.';

  @override
  String get calendarTaskShareMissingChats => 'No chats available.';

  @override
  String get calendarTaskShareMissingRecipient =>
      'Select a chat to share with.';

  @override
  String get calendarTaskShareServiceUnavailable =>
      'Calendar sharing is unavailable.';

  @override
  String get calendarTaskShareDenied =>
      'Calendar cards are disabled for your role in this room.';

  @override
  String get calendarTaskShareSendFailed => 'Failed to share task.';

  @override
  String get calendarTaskShareSuccess => 'Task shared.';

  @override
  String get commonTimeJustNow => 'Just now';

  @override
  String commonTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count min$_temp0 ago';
  }

  @override
  String commonTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count hour$_temp0 ago';
  }

  @override
  String commonTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count day$_temp0 ago';
  }

  @override
  String commonTimeWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count week$_temp0 ago';
  }

  @override
  String get commonTimeMonthsAgo => 'Months ago';

  @override
  String get connectivityStatusConnected => 'Connected';

  @override
  String get connectivityStatusConnecting => 'Connecting...';

  @override
  String get connectivityStatusNotConnected => 'Not connected.';

  @override
  String get connectivityStatusFailed => 'Failed to connect.';

  @override
  String get commonShare => 'Share';

  @override
  String get commonRecipients => 'Recipients';

  @override
  String commonRangeLabel(String start, String end) {
    return '$start - $end';
  }

  @override
  String get commonOwnerFallback => 'owner';

  @override
  String commonDurationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count min$_temp0';
  }

  @override
  String commonDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count hour$_temp0';
  }

  @override
  String commonDurationMinutesShort(int count) {
    return '${count}m';
  }

  @override
  String commonDurationHoursShort(int count) {
    return '${count}h';
  }

  @override
  String commonDateTimeLabel(String date, String time) {
    return '$date · $time';
  }

  @override
  String get calendarAvailabilityShareTitle => 'Share availability';

  @override
  String get calendarAvailabilityShareSubtitle =>
      'Pick a range, edit free/busy, then share.';

  @override
  String get calendarAvailabilityShareChatSubtitle =>
      'Pick a range, edit free/busy, then share in this chat.';

  @override
  String get calendarAvailabilityShareRangeLabel => 'Range';

  @override
  String get calendarAvailabilityShareEditHint =>
      'Tap to split, drag to resize, or toggle free/busy.';

  @override
  String get calendarAvailabilityShareSavePreset => 'Save as preset';

  @override
  String get calendarAvailabilitySharePresetNameTitle => 'Save free/busy sheet';

  @override
  String get calendarAvailabilitySharePresetNameLabel => 'Name';

  @override
  String get calendarAvailabilitySharePresetNameHint => 'Team hours';

  @override
  String get calendarAvailabilitySharePresetNameMissing =>
      'Enter a name to save this sheet.';

  @override
  String get calendarAvailabilityShareInvalidRange =>
      'Select a valid range to share.';

  @override
  String get calendarAvailabilityShareMissingJid =>
      'Calendar sharing is unavailable.';

  @override
  String get calendarAvailabilityShareRecipientsRequired =>
      'Select at least one recipient.';

  @override
  String get calendarAvailabilityShareMissingChats =>
      'No eligible chats available.';

  @override
  String get calendarAvailabilityShareLockedChatUnavailable =>
      'This chat cannot receive availability shares.';

  @override
  String get calendarAvailabilityShareSuccess => 'Availability shared.';

  @override
  String get calendarAvailabilityShareFailed => 'Failed to share availability.';

  @override
  String get calendarAvailabilitySharePartialFailure =>
      'Some shares failed to send.';

  @override
  String get calendarAvailabilitySharePresetLabel => 'Recent sheets';

  @override
  String get calendarAvailabilitySharePresetEmpty => 'No recent sheets yet.';

  @override
  String calendarAvailabilityShareRecentPreset(String range) {
    return 'Shared $range';
  }

  @override
  String get calendarAvailabilityPreviewEmpty => 'No availability intervals.';

  @override
  String calendarAvailabilityPreviewMore(int count) {
    return 'and $count more';
  }

  @override
  String get calendarTaskTitleRequired =>
      'Enter a task title before continuing.';

  @override
  String calendarTaskTitleTooLong(int max) {
    return 'Task title is too long. Please use fewer than $max characters.';
  }

  @override
  String calendarTaskTitleLimitWarning(int max) {
    return 'Task titles are limited to $max characters. Shorten this text or move details into the description before saving.';
  }

  @override
  String calendarTaskTitleCharacterCount(int count, int limit) {
    return '$count / $limit characters';
  }

  @override
  String get axiVersionWelcomeTitle => 'Welcome to Axichat';

  @override
  String axiVersionLabel(String version) {
    return 'v$version';
  }

  @override
  String get axiVersionTagAlpha => 'alpha';

  @override
  String get calendarSyncWarningSnapshotTitle => 'Calendar sync';

  @override
  String get calendarSyncWarningSnapshotMessage =>
      'Calendar snapshot unavailable. Export your calendar JSON from another device and import it here to restore.';

  @override
  String commonLabelValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String get calendarAvailabilityRequestTitle => 'Request time';

  @override
  String get calendarAvailabilityRequestSubtitle =>
      'Choose a free slot and share details.';

  @override
  String get calendarAvailabilityRequestDetailsLabel => 'Details';

  @override
  String get calendarAvailabilityRequestRangeLabel => 'Range';

  @override
  String get calendarAvailabilityRequestTitleLabel => 'Title';

  @override
  String get calendarAvailabilityRequestTitlePlaceholder => 'What is this for?';

  @override
  String get calendarAvailabilityRequestDescriptionLabel => 'Description';

  @override
  String get calendarAvailabilityRequestDescriptionPlaceholder =>
      'Add context (optional).';

  @override
  String get calendarAvailabilityRequestSendLabel => 'Send request';

  @override
  String get calendarAvailabilityRequestInvalidRange =>
      'Pick a valid time range.';

  @override
  String get calendarAvailabilityRequestNotFree =>
      'Select a free slot before sending.';

  @override
  String get calendarAvailabilityDecisionTitle => 'Accept request';

  @override
  String get calendarAvailabilityDecisionSubtitle =>
      'Choose which calendars should receive it.';

  @override
  String get calendarAvailabilityDecisionPersonalLabel =>
      'Add to personal calendar';

  @override
  String get calendarAvailabilityDecisionChatLabel => 'Add to chat calendar';

  @override
  String get calendarAvailabilityDecisionMissingSelection =>
      'Select at least one calendar.';

  @override
  String get calendarAvailabilityDecisionSummaryLabel => 'Requested';

  @override
  String get calendarAvailabilityRequestTitleFallback => 'Requested time';

  @override
  String get calendarAvailabilityShareFallback => 'Shared availability';

  @override
  String get calendarAvailabilityRequestFallback => 'Availability request';

  @override
  String get calendarAvailabilityResponseAcceptedFallback =>
      'Availability accepted';

  @override
  String get calendarAvailabilityResponseDeclinedFallback =>
      'Availability declined';

  @override
  String get calendarFreeBusyFree => 'Free';

  @override
  String get calendarFreeBusyBusy => 'Busy';

  @override
  String get calendarFreeBusyTentative => 'Tentative';

  @override
  String get calendarFreeBusyEditTitle => 'Edit availability';

  @override
  String get calendarFreeBusyEditSubtitle =>
      'Adjust the time range and status.';

  @override
  String get calendarFreeBusyToggleLabel => 'Free/Busy';

  @override
  String get calendarFreeBusySplitLabel => 'Split';

  @override
  String get calendarFreeBusySplitTooltip => 'Split segment';

  @override
  String get calendarFreeBusyMarkFree => 'Mark free';

  @override
  String get calendarFreeBusyMarkBusy => 'Mark busy';

  @override
  String get calendarFreeBusyRangeLabel => 'Range';

  @override
  String commonWeekdayDayLabel(String weekday, int day) {
    return '$weekday $day';
  }

  @override
  String get calendarFragmentChecklistLabel => 'Checklist';

  @override
  String get calendarFragmentChecklistSeparator => ', ';

  @override
  String calendarFragmentChecklistSummary(String summary) {
    return 'Checklist: $summary';
  }

  @override
  String calendarFragmentChecklistSummaryMore(String summary, int count) {
    return 'Checklist: $summary and $count more';
  }

  @override
  String get calendarFragmentRemindersLabel => 'Reminders';

  @override
  String calendarFragmentReminderStartSummary(String summary) {
    return 'Start: $summary';
  }

  @override
  String calendarFragmentReminderDeadlineSummary(String summary) {
    return 'Deadline: $summary';
  }

  @override
  String calendarFragmentRemindersSummary(String summary) {
    return 'Reminders: $summary';
  }

  @override
  String get calendarFragmentReminderSeparator => ', ';

  @override
  String get calendarFragmentEventTitleFallback => 'Untitled event';

  @override
  String calendarFragmentDayEventSummary(String title, String range) {
    return '$title (Day event: $range)';
  }

  @override
  String calendarFragmentFreeBusySummary(String label, String range) {
    return '$label (Window: $range)';
  }

  @override
  String get calendarFragmentCriticalPathLabel => 'Critical path';

  @override
  String calendarFragmentCriticalPathSummary(String name) {
    return 'Critical path: $name';
  }

  @override
  String calendarFragmentCriticalPathProgress(int completed, int total) {
    return '$completed/$total done';
  }

  @override
  String calendarFragmentCriticalPathDetail(String name, String progress) {
    return '$name (Critical path: $progress)';
  }

  @override
  String calendarFragmentAvailabilitySummary(String summary, String range) {
    return '$summary (Availability: $range)';
  }

  @override
  String calendarFragmentAvailabilityFallback(String range) {
    return 'Availability: $range';
  }

  @override
  String calendarMonthOverflowMore(int count) {
    return '+$count more';
  }

  @override
  String commonPercentLabel(int value) {
    return '$value%';
  }

  @override
  String get commonStart => 'Start';

  @override
  String get commonEnd => 'End';

  @override
  String get commonSelectStart => 'Select start';

  @override
  String get commonSelectEnd => 'Select end';

  @override
  String get commonTimeLabel => 'Time';

  @override
  String get commonListSeparator => ', ';

  @override
  String get commonClauseSeparator => '; ';

  @override
  String get commonSentenceSeparator => '. ';

  @override
  String get commonSentenceTerminator => '.';

  @override
  String commonListAnd(String head, String tail) {
    return '$head and $tail';
  }

  @override
  String get calendarAlarmsTitle => 'Alarms';

  @override
  String get calendarAlarmsHelper =>
      'Reminders are exported as display alarms.';

  @override
  String get calendarAlarmsEmpty => 'No alarms yet';

  @override
  String get calendarAlarmAddTooltip => 'Add alarm';

  @override
  String get calendarAlarmRemoveTooltip => 'Remove alarm';

  @override
  String calendarAlarmItemLabel(int index) {
    return 'Alarm $index';
  }

  @override
  String get calendarAlarmActionLabel => 'Action';

  @override
  String get calendarAlarmActionDisplay => 'Display';

  @override
  String get calendarAlarmActionAudio => 'Audio';

  @override
  String get calendarAlarmActionEmail => 'Email';

  @override
  String get calendarAlarmActionProcedure => 'Procedure';

  @override
  String get calendarAlarmActionProcedureHelper =>
      'Procedure alarms are imported read-only.';

  @override
  String get calendarAlarmTriggerLabel => 'Trigger';

  @override
  String get calendarAlarmTriggerRelative => 'Relative';

  @override
  String get calendarAlarmTriggerAbsolute => 'Absolute';

  @override
  String get calendarAlarmAbsolutePlaceholder => 'Pick date and time';

  @override
  String get calendarAlarmRelativeToLabel => 'Relative to';

  @override
  String get calendarAlarmRelativeToStart => 'Start';

  @override
  String get calendarAlarmRelativeToEnd => 'End';

  @override
  String get calendarAlarmDirectionLabel => 'Direction';

  @override
  String get calendarAlarmDirectionBefore => 'Before';

  @override
  String get calendarAlarmDirectionAfter => 'After';

  @override
  String get calendarAlarmOffsetLabel => 'Offset';

  @override
  String get calendarAlarmOffsetHint => 'Amount';

  @override
  String get calendarAlarmRepeatLabel => 'Repeat';

  @override
  String get calendarAlarmRepeatCountHint => 'Times';

  @override
  String get calendarAlarmRepeatEveryLabel => 'Every';

  @override
  String get calendarAlarmRecipientsLabel => 'Recipients';

  @override
  String get calendarAlarmRecipientAddressHint => 'Add email';

  @override
  String get calendarAlarmRecipientNameHint => 'Name (optional)';

  @override
  String get calendarAlarmRecipientRemoveTooltip => 'Remove recipient';

  @override
  String calendarAlarmRecipientDisplay(String name, String address) {
    return '$name <$address>';
  }

  @override
  String get calendarAlarmAcknowledgedLabel => 'Acknowledged';

  @override
  String get calendarAlarmUnitMinutes => 'Minutes';

  @override
  String get calendarAlarmUnitHours => 'Hours';

  @override
  String get calendarAlarmUnitDays => 'Days';

  @override
  String get calendarAlarmUnitWeeks => 'Weeks';

  @override
  String get taskShareTitleFallback => 'Untitled task';

  @override
  String taskShareTitleLabel(String title) {
    return 'Task \"$title\"';
  }

  @override
  String taskShareTitleWithQualifiers(String title, String qualifiers) {
    return 'Task \"$title\" ($qualifiers)';
  }

  @override
  String get taskShareQualifierDone => 'done';

  @override
  String get taskSharePriorityImportant => 'important';

  @override
  String get taskSharePriorityUrgent => 'urgent';

  @override
  String get taskSharePriorityCritical => 'critical';

  @override
  String taskShareLocationClause(String location) {
    return ' at $location';
  }

  @override
  String get taskShareScheduleNoTime => ' with no set time';

  @override
  String taskShareScheduleSameDay(
      String date, String startTime, String endTime) {
    return ' on $date from $startTime to $endTime';
  }

  @override
  String taskShareScheduleRange(String startDateTime, String endDateTime) {
    return ' from $startDateTime to $endDateTime';
  }

  @override
  String taskShareScheduleStartDuration(
      String date, String time, String duration) {
    return ' on $date at $time for $duration';
  }

  @override
  String taskShareScheduleStart(String date, String time) {
    return ' on $date at $time';
  }

  @override
  String taskShareScheduleEnding(String dateTime) {
    return ' ending $dateTime';
  }

  @override
  String get taskShareRecurrenceEveryOtherDay => ' every other day';

  @override
  String taskShareRecurrenceEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: 'day',
    );
    return ' every $_temp0';
  }

  @override
  String taskShareRecurrenceEveryWeekdays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weekdays',
      one: 'weekday',
    );
    return ' every $_temp0';
  }

  @override
  String taskShareRecurrenceEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: 'week',
    );
    return ' every $_temp0';
  }

  @override
  String taskShareRecurrenceEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: 'month',
    );
    return ' every $_temp0';
  }

  @override
  String get taskShareRecurrenceEveryOtherYear => ' every other year';

  @override
  String taskShareRecurrenceEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: 'year',
    );
    return ' every $_temp0';
  }

  @override
  String taskShareRecurrenceOnDays(String days) {
    return ' on $days';
  }

  @override
  String taskShareRecurrenceUntil(String date) {
    return ' until $date';
  }

  @override
  String taskShareRecurrenceCount(int count) {
    return ' for $count occurrences';
  }

  @override
  String taskShareDeadlineClause(String dateTime) {
    return ', due by $dateTime';
  }

  @override
  String taskShareNotesClause(String notes) {
    return ' Notes: $notes.';
  }

  @override
  String taskShareChangesClause(String changes) {
    return ' Changes: $changes';
  }

  @override
  String taskShareOverrideMoveTo(String dateTime) {
    return 'move to $dateTime';
  }

  @override
  String taskShareOverrideDuration(String duration) {
    return 'for $duration';
  }

  @override
  String taskShareOverrideEndAt(String dateTime) {
    return 'end at $dateTime';
  }

  @override
  String taskShareOverridePriority(String priority) {
    return 'priority $priority';
  }

  @override
  String get taskShareOverrideCancelled => 'cancelled';

  @override
  String get taskShareOverrideDone => 'done';

  @override
  String taskShareOverrideRenameTo(String title) {
    return 'rename to \"$title\"';
  }

  @override
  String taskShareOverrideNotes(String notes) {
    return 'notes \"$notes\"';
  }

  @override
  String taskShareOverrideLocation(String location) {
    return 'location \"$location\"';
  }

  @override
  String get taskShareOverrideNoChanges => 'no changes';

  @override
  String taskShareOverrideSegment(String dateTime, String actions) {
    return 'On $dateTime: $actions';
  }

  @override
  String get calendarTaskCopiedToClipboard => 'Task copied to clipboard';

  @override
  String get calendarTaskSplitRequiresSchedule =>
      'Task must be scheduled to use split.';

  @override
  String get calendarTaskSplitTooShort => 'Task is too short to split.';

  @override
  String get calendarTaskSplitUnable => 'Unable to split task at that time.';

  @override
  String get calendarDayEventsLabel => 'Day events';

  @override
  String get calendarShareAsIcsAction => 'Share as .ics';

  @override
  String get calendarCompletedLabel => 'Completed';

  @override
  String get calendarDeadlineDueToday => 'Due today';

  @override
  String get calendarDeadlineDueTomorrow => 'Due tomorrow';

  @override
  String get calendarExportTasksFilePrefix => 'axichat_tasks';

  @override
  String get chatTaskViewTitle => 'Task details';

  @override
  String get chatTaskViewSubtitle => 'Read-only task.';

  @override
  String get chatTaskViewPreviewLabel => 'Preview';

  @override
  String get chatTaskViewActionsLabel => 'Task actions';

  @override
  String get chatTaskViewCopyLabel => 'Copy to calendar';

  @override
  String get chatTaskCopyTitle => 'Copy task';

  @override
  String get chatTaskCopySubtitle =>
      'Choose which calendars should receive it.';

  @override
  String get chatTaskCopyPreviewLabel => 'Preview';

  @override
  String get chatTaskCopyCalendarsLabel => 'Calendars';

  @override
  String get chatTaskCopyPersonalLabel => 'Add to personal calendar';

  @override
  String get chatTaskCopyChatLabel => 'Add to chat calendar';

  @override
  String get chatTaskCopyConfirmLabel => 'Copy';

  @override
  String get chatTaskCopyMissingSelectionMessage =>
      'Select at least one calendar.';

  @override
  String get chatCriticalPathCopyTitle => 'Copy critical path';

  @override
  String get chatCriticalPathCopySubtitle =>
      'Choose which calendars should receive it.';

  @override
  String get chatCriticalPathCopyPreviewLabel => 'Preview';

  @override
  String get chatCriticalPathCopyCalendarsLabel => 'Calendars';

  @override
  String get chatCriticalPathCopyPersonalLabel => 'Add to personal calendar';

  @override
  String get chatCriticalPathCopyChatLabel => 'Add to chat calendar';

  @override
  String get chatCriticalPathCopyConfirmLabel => 'Copy';

  @override
  String get chatCriticalPathCopyMissingSelectionMessage =>
      'Select at least one calendar.';

  @override
  String get chatCriticalPathCopyUnavailableMessage =>
      'Calendar is unavailable.';

  @override
  String get chatCriticalPathCopySuccessMessage => 'Critical path copied.';

  @override
  String commonBulletLabel(String text) {
    return '• $text';
  }

  @override
  String get chatFilterTitle => 'Messages shown';

  @override
  String get chatFilterDirectOnlyLabel => 'Direct only';

  @override
  String get chatFilterAllLabel => 'All';

  @override
  String get calendarFragmentTaskLabel => 'Task';

  @override
  String get calendarFragmentDayEventLabel => 'Day event';

  @override
  String get calendarFragmentFreeBusyLabel => 'Free/busy';

  @override
  String get calendarFragmentAvailabilityLabel => 'Availability';

  @override
  String get calendarFragmentScheduledLabel => 'Scheduled';

  @override
  String get calendarFragmentDueLabel => 'Due';

  @override
  String get calendarFragmentUntitledLabel => 'Untitled';

  @override
  String get calendarFragmentChecklistBullet => '- ';

  @override
  String commonAndMoreLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more',
      one: 'and 1 more',
    );
    return '$_temp0';
  }

  @override
  String get commonBulletSymbol => '• ';

  @override
  String get commonLabelSeparator => ': ';

  @override
  String get commonUnknownLabel => 'Unknown';

  @override
  String get commonBadgeOverflowLabel => '99+';

  @override
  String get commonEllipsis => '…';

  @override
  String get chatMessageDetailsSenderLabel => 'Sender address';

  @override
  String get chatMessageDetailsMetadataLabel => 'Message metadata';

  @override
  String get chatMessageDetailsHeadersLabel => 'Raw headers';

  @override
  String get chatMessageDetailsHeadersActionLabel => 'View headers';

  @override
  String get chatMessageDetailsHeadersNote =>
      'Headers are loaded from the original RFC822 message.';

  @override
  String get chatMessageDetailsHeadersLoadingLabel => 'Loading headers...';

  @override
  String get chatMessageDetailsHeadersUnavailableLabel =>
      'Headers unavailable.';

  @override
  String get chatMessageDetailsStanzaIdLabel => 'Stanza ID';

  @override
  String get chatMessageDetailsOriginIdLabel => 'Origin ID';

  @override
  String get chatMessageDetailsOccupantIdLabel => 'Occupant ID';

  @override
  String get chatMessageDetailsDeltaIdLabel => 'Delta message ID';

  @override
  String get chatMessageDetailsLocalIdLabel => 'Local message ID';

  @override
  String get chatCalendarFragmentShareDeniedMessage =>
      'Calendar cards are disabled for your role in this room.';

  @override
  String get chatAvailabilityRequestAccountMissingMessage =>
      'Availability requests are unavailable right now.';

  @override
  String get chatAvailabilityRequestEmailUnsupportedMessage =>
      'Availability is unavailable for email chats.';

  @override
  String get chatAvailabilityRequestInvalidRangeMessage =>
      'Availability request time is invalid.';

  @override
  String get chatAvailabilityRequestCalendarUnavailableMessage =>
      'Calendar is unavailable.';

  @override
  String get chatAvailabilityRequestChatCalendarUnavailableMessage =>
      'Chat calendar is unavailable.';

  @override
  String get chatAvailabilityRequestTaskTitleFallback => 'Requested time';

  @override
  String get chatSenderAddressPrefix => 'JID: ';

  @override
  String get chatRecipientVisibilityCcLabel => 'CC';

  @override
  String get chatRecipientVisibilityBccLabel => 'BCC';

  @override
  String get chatInviteRoomFallbackLabel => 'group chat';

  @override
  String get chatInviteBodyLabel => 'You have been invited to a group chat';

  @override
  String get chatInviteRevokedLabel => 'Invite revoked';

  @override
  String chatInviteActionLabel(String roomName) {
    return 'Join \'$roomName\'';
  }

  @override
  String get chatInviteActionFallbackLabel => 'Join';

  @override
  String get chatInviteConfirmTitle => 'Accept invite?';

  @override
  String chatInviteConfirmMessage(String roomName) {
    return 'Join \'$roomName\'?';
  }

  @override
  String get chatInviteConfirmLabel => 'Accept';

  @override
  String get chatChooseTextToAddHint =>
      'Select a portion of the message to send to the calendar or edit it first.';

  @override
  String get chatAttachmentAutoDownloadLabel =>
      'Automatically download attachments in this chat';

  @override
  String get chatAttachmentAutoDownloadHintOn =>
      'Attachments in this chat will download automatically.';

  @override
  String get chatAttachmentAutoDownloadHintOff =>
      'Attachments are blocked until you approve them.';

  @override
  String chatAttachmentCaption(String filename, String size) {
    return '📎 $filename ($size)';
  }

  @override
  String get chatAttachmentFallbackLabel => 'Attachment';

  @override
  String get commonFileSizeUnitBytes => 'B';

  @override
  String get commonFileSizeUnitKilobytes => 'KB';

  @override
  String get commonFileSizeUnitMegabytes => 'MB';

  @override
  String get commonFileSizeUnitGigabytes => 'GB';

  @override
  String get commonFileSizeUnitTerabytes => 'TB';

  @override
  String get chatAttachmentTooLargeMessageDefault =>
      'Attachment exceeds the server limit.';

  @override
  String chatAttachmentTooLargeMessage(String limit) {
    return 'Attachment exceeds the server limit ($limit).';
  }

  @override
  String chatMessageErrorWithBody(String label, String body) {
    return '$label: \"$body\"';
  }

  @override
  String get chatUnreadDividerLabel => 'Unread';

  @override
  String get messageErrorServiceUnavailableTooltip =>
      'The service reported a temporary issue.';

  @override
  String get messageErrorServiceUnavailable => 'Service unavailable';

  @override
  String get messageErrorServerNotFound => 'Server not found';

  @override
  String get messageErrorServerTimeout => 'Server timed out';

  @override
  String get messageErrorUnknown => 'Unknown error';

  @override
  String get messageErrorNotEncryptedForDevice =>
      'Not encrypted for this device';

  @override
  String get messageErrorMalformedKey => 'Malformed encryption key';

  @override
  String get messageErrorUnknownSignedPrekey => 'Unknown signed prekey';

  @override
  String get messageErrorNoDeviceSession => 'No device session';

  @override
  String get messageErrorSkippingTooManyKeys => 'Too many keys skipped';

  @override
  String get messageErrorInvalidHmac => 'Invalid HMAC';

  @override
  String get messageErrorMalformedCiphertext => 'Malformed ciphertext';

  @override
  String get messageErrorNoKeyMaterial => 'Missing key material';

  @override
  String get messageErrorNoDecryptionKey => 'Missing decryption key';

  @override
  String get messageErrorInvalidKex => 'Invalid key exchange';

  @override
  String get messageErrorUnknownOmemo => 'Unknown OMEMO error';

  @override
  String get messageErrorInvalidAffixElements => 'Invalid affix elements';

  @override
  String get messageErrorEmptyDeviceList => 'Empty device list';

  @override
  String get messageErrorOmemoUnsupported => 'OMEMO not supported';

  @override
  String get messageErrorEncryptionFailure => 'Encryption failed';

  @override
  String get messageErrorInvalidEnvelope => 'Invalid envelope';

  @override
  String get messageErrorFileDownloadFailure => 'File download failed';

  @override
  String get messageErrorFileUploadFailure => 'File upload failed';

  @override
  String get messageErrorFileDecryptionFailure => 'File decryption failed';

  @override
  String get messageErrorFileEncryptionFailure => 'File encryption failed';

  @override
  String get messageErrorPlaintextFileInOmemo =>
      'Plaintext file in OMEMO message';

  @override
  String get messageErrorEmailSendFailure => 'Email send failed';

  @override
  String get messageErrorEmailAttachmentTooLarge =>
      'Email attachment too large';

  @override
  String get messageErrorEmailRecipientRejected => 'Email recipient rejected';

  @override
  String get messageErrorEmailAuthenticationFailed =>
      'Email authentication failed';

  @override
  String get messageErrorEmailBounced => 'Email bounced';

  @override
  String get messageErrorEmailThrottled => 'Email throttled';

  @override
  String get chatEmailResendFailedDetails => 'Unable to resend the email.';

  @override
  String get authEnableXmppOrSmtp => 'Enable XMPP or SMTP to continue.';

  @override
  String get authUsernamePasswordMismatch =>
      'Username and password have different nullness.';

  @override
  String get authStoredCredentialsOutdated =>
      'Stored credentials are outdated. Please log in manually.';

  @override
  String get authMissingDatabaseSecrets =>
      'Local database secrets are missing for this account. Axichat cannot open your existing chats. Restore the original install or reset local data to continue.';

  @override
  String get authInvalidCredentials => 'Incorrect username or password';

  @override
  String get authGenericError => 'Error. Please try again later.';

  @override
  String get authStorageLocked =>
      'Storage is locked by another Axichat instance. Close other windows or processes and try again.';

  @override
  String get authEmailServerUnreachable =>
      'Unable to reach the email server. Please try again.';

  @override
  String get authEmailSetupFailed => 'Email setup failed. Please try again.';

  @override
  String get authEmailPasswordMissing =>
      'Stored email password missing. Please log in manually.';

  @override
  String get authEmailAuthFailed =>
      'Email authentication failed. Please log in again.';

  @override
  String get signupCleanupInProgress =>
      'Cleaning up your previous signup attempt. We will retry the removal as soon as you are back online; try again once it finishes.';

  @override
  String get signupFailedTryAgain => 'Failed to register, try again later.';

  @override
  String get authPasswordMismatch => 'New passwords do not match.';

  @override
  String get authPasswordChangeDisabled =>
      'Password changes are disabled for this account.';

  @override
  String get authPasswordChangeRejected =>
      'Current password is incorrect, or the new password does not meet server requirements.';

  @override
  String get authPasswordChangeFailed =>
      'Unable to change password. Please try again later.';

  @override
  String get authPasswordChangeSuccess => 'Password changed successfully.';

  @override
  String get authPasswordIncorrect => 'Incorrect password. Please try again.';

  @override
  String get authAccountNotFound => 'Account not found.';

  @override
  String get authAccountDeletionDisabled =>
      'Account deletion is disabled for this account.';

  @override
  String get authAccountDeletionFailed =>
      'Unable to delete account. Please try again later.';

  @override
  String get authDemoModeFailed =>
      'Failed to start demo mode. Please try again.';

  @override
  String authLoginBackoff(Object seconds) {
    return 'Too many attempts. Wait $seconds seconds before trying again.';
  }

  @override
  String get signupAvatarCropTitle => 'Crop & focus';

  @override
  String get signupAvatarCropHint =>
      'Only the area inside the circle will appear in the final avatar.';

  @override
  String get xmppOperationPubSubBookmarksStart => 'Syncing bookmarks...';

  @override
  String get xmppOperationPubSubBookmarksSuccess => 'Bookmarks synced';

  @override
  String get xmppOperationPubSubBookmarksFailure => 'Bookmarks sync failed';

  @override
  String get xmppOperationPubSubConversationsStart => 'Syncing chats list...';

  @override
  String get xmppOperationPubSubConversationsSuccess => 'Chats list synced';

  @override
  String get xmppOperationPubSubConversationsFailure =>
      'Chats list sync failed';

  @override
  String get xmppOperationPubSubDraftsStart => 'Syncing drafts...';

  @override
  String get xmppOperationPubSubDraftsSuccess => 'Drafts synced';

  @override
  String get xmppOperationPubSubDraftsFailure => 'Drafts sync failed';

  @override
  String get xmppOperationPubSubSpamStart => 'Syncing spam list...';

  @override
  String get xmppOperationPubSubSpamSuccess => 'Spam list synced';

  @override
  String get xmppOperationPubSubSpamFailure => 'Spam list sync failed';

  @override
  String get xmppOperationPubSubEmailBlocklistStart =>
      'Syncing email blocklist...';

  @override
  String get xmppOperationPubSubEmailBlocklistSuccess =>
      'Email blocklist synced';

  @override
  String get xmppOperationPubSubEmailBlocklistFailure =>
      'Email blocklist sync failed';

  @override
  String get xmppOperationPubSubAvatarMetadataStart =>
      'Syncing avatar details...';

  @override
  String get xmppOperationPubSubAvatarMetadataSuccess =>
      'Avatar details synced';

  @override
  String get xmppOperationPubSubAvatarMetadataFailure =>
      'Avatar details sync failed';

  @override
  String get xmppOperationPubSubFetchStart => 'Syncing account updates...';

  @override
  String get xmppOperationPubSubFetchSuccess => 'Account updates synced';

  @override
  String get xmppOperationPubSubFetchFailure => 'Account updates sync failed';

  @override
  String get xmppOperationMamLoginStart => 'Syncing messages...';

  @override
  String get xmppOperationMamLoginSuccess => 'Messages synced';

  @override
  String get xmppOperationMamLoginFailure => 'Message sync failed';

  @override
  String get xmppOperationMamGlobalStart => 'Syncing full history...';

  @override
  String get xmppOperationMamGlobalSuccess => 'History synced';

  @override
  String get xmppOperationMamGlobalFailure => 'History sync failed';

  @override
  String get xmppOperationMamMucStart => 'Syncing room history...';

  @override
  String get xmppOperationMamMucSuccess => 'Room history synced';

  @override
  String get xmppOperationMamMucFailure => 'Room history sync failed';

  @override
  String get xmppOperationMamFetchStart => 'Fetching archived messages...';

  @override
  String get xmppOperationMamFetchSuccess => 'Archive fetched';

  @override
  String get xmppOperationMamFetchFailure => 'Archive fetch failed';

  @override
  String get xmppOperationMucJoinStart => 'Joining room...';

  @override
  String get xmppOperationMucJoinSuccess => 'Room joined';

  @override
  String get xmppOperationMucJoinFailure => 'Room join failed';

  @override
  String get chatSettingsCapabilitiesTitle => 'Capabilities';

  @override
  String chatSettingsCapabilitiesUpdated(Object timestamp) {
    return 'Last checked: $timestamp';
  }

  @override
  String get chatSettingsCapabilitiesEmpty => 'No features reported';
}
