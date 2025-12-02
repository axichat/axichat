import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

extension LocalizationX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension AppLocalizationsFallbacks on AppLocalizations {
  String calendarDeleteTaskConfirm(String title) => 'Delete "$title"?';
  String calendarRemovePathConfirm(String name) =>
      'Remove this task from "$name"?';
  String get calendarCriticalPathsTitle => 'Critical paths';
  String get calendarCriticalPathsAll => 'All paths';
  String get calendarCriticalPathsNew => 'New critical path';
  String get calendarCriticalPathsEmpty => 'No critical paths yet';
  String get calendarCriticalPathTaskOrderTitle => 'Order tasks';
  String get calendarCriticalPathAddTask => 'Add task';
  String get calendarCriticalPathDragHint => 'Drag tasks to reorder';
  String get calendarCriticalPathEmptyTasks => 'No tasks in this path yet';
  String get calendarCriticalPathAddToTitle => 'Add to critical path';
  String get calendarCriticalPathCreatePrompt =>
      'Create a critical path to get started';
  String get calendarCriticalPathNamePrompt => 'Name';
  String get calendarCriticalPathNamePlaceholder => 'Critical path name';
  String get calendarCriticalPathNameEmptyError => 'Enter a name';
  String get calendarSandboxHint =>
      'Plan tasks here before assigning them to a path.';
  String get calendarBackToCalendar => 'Back to calendar';
  String get calendarErrorTitleEmptyFriendly => 'Title cannot be empty';
  String get calendarExportFormatIcsTitle => 'Export .ics';
  String get calendarExportFormatIcsSubtitle => 'Use for calendar clients';
  String get calendarExportFormatJsonTitle => 'Export JSON';
  String get calendarExportFormatJsonSubtitle => 'Use for backups or scripts';
  String calendarAddTaskError(String details) => 'Could not add task: $details';

  String get blocklistBlockUser => 'Block user';
  String get blocklistWaitingForUnblock => 'Awaiting unblock';
  String get blocklistUnblockAll => 'Unblock all';
  String get blocklistUnblock => 'Unblock';
  String get blocklistBlock => 'Block';

  String get chatAttachmentTapToLoad => 'Tap to load';
  String get chatAttachmentUnavailable => 'Attachment unavailable';
  String get chatAttachmentLoading => 'Loading attachment...';
  String chatAttachmentLoadingProgress(String percent) => 'Loading ($percent)';

  String get authEndpointTitle => 'Endpoint configuration';
  String get authEndpointDescription =>
      'Configure XMPP/SMTP endpoints for this account.';
  String get authEndpointDomainPlaceholder => 'Domain';
  String get authEndpointXmppLabel => 'XMPP';
  String get authEndpointSmtpLabel => 'SMTP';
  String get authEndpointUseDnsLabel => 'Use DNS';
  String get authEndpointUseSrvLabel => 'Use SRV';
  String get authEndpointRequireDnssecLabel => 'Require DNSSEC';
  String get authEndpointXmppHostPlaceholder => 'XMPP host';
  String get authEndpointPortPlaceholder => 'Port';
  String get authEndpointSmtpHostPlaceholder => 'SMTP host';
  String get authEndpointApiPortPlaceholder => 'API port';
  String get authEndpointReset => 'Reset';
  String get authEndpointAdvancedHint => 'Advanced options';
  String get authUnregisterPending => 'Unregistering...';
  String get authChangePasswordPending => 'Updating password...';
  String get authLogoutTitle => 'Log out';
  String get authLogoutNormal => 'Log out';
  String get authLogoutNormalDescription => 'Sign out of this account.';
  String get authLogoutBurn => 'Burn account';
  String get authLogoutBurnDescription =>
      'Sign out and clear local data for this account.';

  String get mucChangeNickname => 'Change nickname';
  String mucChangeNicknameWithCurrent(String current) =>
      'Change nickname (current: $current)';
  String get mucLeaveRoom => 'Leave room';
  String get mucNoMembers => 'No members';
  String get mucInviteUsers => 'Invite users';
  String get mucSendInvites => 'Send invites';
  String get mucChangeNicknameTitle => 'Change nickname';
  String get mucEnterNicknamePlaceholder => 'Enter nickname';
  String get mucUpdateNickname => 'Update nickname';
  String get mucMembersTitle => 'Members';
  String get mucInviteUser => 'Invite user';

  String get chatsCreateGroupChatTooltip => 'New group chat';
  String get chatsRoomLabel => 'Room';
  String get chatsCreateChatRoomTitle => 'Create chat room';
  String get chatsRoomNamePlaceholder => 'Room name';

  String get chatMessageStatusSent => 'Sent';
  String get chatMessageStatusReceived => 'Received';
  String get chatMessageStatusDisplayed => 'Read';
  String get chatMessageInfoTimestamp => 'Timestamp';
  String get chatMessageInfoProtocol => 'Protocol';
  String get chatMessageInfoDevice => 'Device';
  String get chatMessageInfoError => 'Error';
  String get chatMessageAddRecipients => 'Add recipients';
  String chatMessageAddRecipientSuccess(String recipient) => 'Added $recipient';
  String get chatMessageOpenChat => 'Open chat';
  String get chatMessageCreateChat => 'Create chat';
  String chatMessageCreateChatFailure(String reason) =>
      'Could not create chat: $reason';

  String get chatAlertHide => 'Hide';
  String get chatAlertIgnore => 'Ignore';
}
