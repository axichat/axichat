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
  String get settingsSectionImportant => 'Important';

  @override
  String get settingsSectionAppearance => 'Appearance';

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
  String get settingsSectionChats => 'Chats';

  @override
  String get settingsMessageStorageTitle => 'Message storage';

  @override
  String get settingsMessageStorageSubtitle =>
      'Local keeps device copies; Server-only queries the archive.';

  @override
  String get settingsMessageStorageLocal => 'Local';

  @override
  String get settingsMessageStorageServerOnly => 'Server-only';

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
  String get settingsReadReceipts => 'Send read receipts';

  @override
  String get settingsTypingIndicators => 'Send typing indicators';

  @override
  String get settingsTypingIndicatorsDescription =>
      'Let other people in a chat see when you are typing.';

  @override
  String get settingsShareTokenFooter => 'Include share token footer';

  @override
  String get settingsShareTokenFooterDescription =>
      'Helps keep multi-recipient email threads and attachments linked. Turning this off can break threading.';

  @override
  String get authCustomServerTitle => 'Custom server';

  @override
  String get authCustomServerDescription =>
      'Override XMPP/SMTP endpoints or enable DNS lookups. Leave fields blank to keep defaults.';

  @override
  String get authCustomServerDomainOrIp => 'Domain or IP';

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
  String get authCustomServerApiPortPlaceholder => 'API port';

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
    return 'This attachment says it is $declared, but the file looks like '
        '$detected. Opening it could be unsafe. Continue?';
  }

  @override
  String get chatAttachmentTypeMismatchConfirm => 'Open anyway';

  @override
  String get chatAttachmentHighRiskTitle => 'Potentially unsafe file';

  @override
  String get chatAttachmentHighRiskMessage =>
      'This file type can be dangerous to open. We recommend saving it and '
      'scanning it before opening. Continue?';

  @override
  String get chatAttachmentUnknownSize => 'Unknown size';

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
  String get chatsRoomLabel => 'Room';

  @override
  String get chatsCreateChatRoomTitle => 'Create chat room';

  @override
  String get chatsRoomNamePlaceholder => 'Name';

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
  String get calendarCriticalPathsTitle => 'Critical paths';

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
  String get chatChooseTextToAdd => 'Choose text to add';
}
