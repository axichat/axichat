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
  String get chatOpenLinkTitle => 'Open external link?';

  @override
  String chatOpenLinkMessage(Object url, Object host) {
    return 'You are about to open:\n$url\n\nOnly tap OK if you trust the site (host: $host).';
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
  String get chatComposerMessageHint => 'Send message';

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
  String get chatReportSpam => 'Report spam';

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
  String get chatInviteRevoked => 'Invite revoked';

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
  String get profileTitle => 'Profile';

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
  String get profileChangePassword => 'Change password';

  @override
  String get profileDeleteAccount => 'Delete account';

  @override
  String get termsAcceptLabel => 'I accept the terms and conditions';

  @override
  String get termsAgreementPrefix => 'You agree to our ';

  @override
  String get termsAgreementTerms => 'terms';

  @override
  String get termsAgreementAnd => ' and ';

  @override
  String get termsAgreementPrivacy => 'privacy policy';

  @override
  String get termsAgreementError => 'You must accept the terms and conditions';
}
