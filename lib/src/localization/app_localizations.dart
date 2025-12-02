import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'localization/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('zh'),
    Locale('zh', 'HK')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'axichat'**
  String get appTitle;

  /// No description provided for @homeTabChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get homeTabChats;

  /// No description provided for @homeTabDrafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get homeTabDrafts;

  /// No description provided for @homeTabSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get homeTabSpam;

  /// No description provided for @homeTabBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get homeTabBlocked;

  /// No description provided for @homeNoModules.
  ///
  /// In en, this message translates to:
  /// **'No modules available'**
  String get homeNoModules;

  /// No description provided for @homeRailShowMenu.
  ///
  /// In en, this message translates to:
  /// **'Show menu'**
  String get homeRailShowMenu;

  /// No description provided for @homeRailHideMenu.
  ///
  /// In en, this message translates to:
  /// **'Hide menu'**
  String get homeRailHideMenu;

  /// No description provided for @homeRailCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get homeRailCalendar;

  /// No description provided for @homeSearchPlaceholderTabs.
  ///
  /// In en, this message translates to:
  /// **'Search tabs'**
  String get homeSearchPlaceholderTabs;

  /// No description provided for @homeSearchPlaceholderForTab.
  ///
  /// In en, this message translates to:
  /// **'Search {tab}'**
  String homeSearchPlaceholderForTab(Object tab);

  /// No description provided for @homeSearchFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter: {filter}'**
  String homeSearchFilterLabel(Object filter);

  /// No description provided for @blocklistFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All blocked'**
  String get blocklistFilterAll;

  /// No description provided for @draftsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All drafts'**
  String get draftsFilterAll;

  /// No description provided for @draftsFilterAttachments.
  ///
  /// In en, this message translates to:
  /// **'With attachments'**
  String get draftsFilterAttachments;

  /// No description provided for @chatsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All chats'**
  String get chatsFilterAll;

  /// No description provided for @chatsFilterContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get chatsFilterContacts;

  /// No description provided for @chatsFilterNonContacts.
  ///
  /// In en, this message translates to:
  /// **'Non-contacts'**
  String get chatsFilterNonContacts;

  /// No description provided for @chatsFilterXmppOnly.
  ///
  /// In en, this message translates to:
  /// **'XMPP only'**
  String get chatsFilterXmppOnly;

  /// No description provided for @chatsFilterEmailOnly.
  ///
  /// In en, this message translates to:
  /// **'Email only'**
  String get chatsFilterEmailOnly;

  /// No description provided for @chatsFilterHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get chatsFilterHidden;

  /// No description provided for @spamFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All spam'**
  String get spamFilterAll;

  /// No description provided for @spamFilterEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get spamFilterEmail;

  /// No description provided for @spamFilterXmpp.
  ///
  /// In en, this message translates to:
  /// **'XMPP'**
  String get spamFilterXmpp;

  /// No description provided for @chatFilterDirectOnly.
  ///
  /// In en, this message translates to:
  /// **'Direct only'**
  String get chatFilterDirectOnly;

  /// No description provided for @chatFilterAllWithContact.
  ///
  /// In en, this message translates to:
  /// **'All with contact'**
  String get chatFilterAllWithContact;

  /// No description provided for @chatSearchMessages.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get chatSearchMessages;

  /// No description provided for @chatSearchSortNewestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get chatSearchSortNewestFirst;

  /// No description provided for @chatSearchSortOldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get chatSearchSortOldestFirst;

  /// No description provided for @chatSearchAnySubject.
  ///
  /// In en, this message translates to:
  /// **'Any subject'**
  String get chatSearchAnySubject;

  /// No description provided for @chatSearchExcludeSubject.
  ///
  /// In en, this message translates to:
  /// **'Exclude subject'**
  String get chatSearchExcludeSubject;

  /// No description provided for @chatSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get chatSearchFailed;

  /// No description provided for @chatSearchInProgress.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get chatSearchInProgress;

  /// No description provided for @chatSearchEmptyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Matches will appear in the conversation below.'**
  String get chatSearchEmptyPrompt;

  /// No description provided for @chatSearchNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches. Adjust filters or try another query.'**
  String get chatSearchNoMatches;

  /// No description provided for @chatSearchMatchCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# match shown below.} other {# matches shown below.}}'**
  String chatSearchMatchCount(num count);

  /// No description provided for @filterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter • {label}'**
  String filterTooltip(Object label);

  /// No description provided for @chatSearchClose.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get chatSearchClose;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @spamEmpty.
  ///
  /// In en, this message translates to:
  /// **'No spam yet'**
  String get spamEmpty;

  /// No description provided for @spamMoveToInbox.
  ///
  /// In en, this message translates to:
  /// **'Move to inbox'**
  String get spamMoveToInbox;

  /// No description provided for @spamMoveToastTitle.
  ///
  /// In en, this message translates to:
  /// **'Moved'**
  String get spamMoveToastTitle;

  /// No description provided for @spamMoveToastMessage.
  ///
  /// In en, this message translates to:
  /// **'Returned {chatTitle} to inbox.'**
  String spamMoveToastMessage(Object chatTitle);

  /// No description provided for @chatSpamUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update spam status.'**
  String get chatSpamUpdateFailed;

  /// No description provided for @chatSpamSent.
  ///
  /// In en, this message translates to:
  /// **'Sent {chatTitle} to spam.'**
  String chatSpamSent(Object chatTitle);

  /// No description provided for @chatSpamRestored.
  ///
  /// In en, this message translates to:
  /// **'Returned {chatTitle} to inbox.'**
  String chatSpamRestored(Object chatTitle);

  /// No description provided for @chatSpamReportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get chatSpamReportedTitle;

  /// No description provided for @chatSpamRestoredTitle.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get chatSpamRestoredTitle;

  /// No description provided for @chatMembersLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading members'**
  String get chatMembersLoading;

  /// No description provided for @chatMembersLoadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading members…'**
  String get chatMembersLoadingEllipsis;

  /// No description provided for @chatAttachmentConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Load attachment?'**
  String get chatAttachmentConfirmTitle;

  /// No description provided for @chatAttachmentConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Only load attachments from contacts you trust.\n\n{sender} is not in your contacts yet. Continue?'**
  String chatAttachmentConfirmMessage(Object sender);

  /// No description provided for @chatAttachmentConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get chatAttachmentConfirmButton;

  /// No description provided for @chatOpenLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Open external link?'**
  String get chatOpenLinkTitle;

  /// No description provided for @chatOpenLinkMessage.
  ///
  /// In en, this message translates to:
  /// **'You are about to open:\n{url}\n\nOnly tap OK if you trust the site (host: {host}).'**
  String chatOpenLinkMessage(Object url, Object host);

  /// No description provided for @chatOpenLinkConfirm.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get chatOpenLinkConfirm;

  /// No description provided for @chatInvalidLink.
  ///
  /// In en, this message translates to:
  /// **'Invalid link: {url}'**
  String chatInvalidLink(Object url);

  /// No description provided for @chatUnableToOpenHost.
  ///
  /// In en, this message translates to:
  /// **'Unable to open {host}'**
  String chatUnableToOpenHost(Object host);

  /// No description provided for @chatSaveAsDraft.
  ///
  /// In en, this message translates to:
  /// **'Save as draft'**
  String get chatSaveAsDraft;

  /// No description provided for @chatDraftUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Drafts are unavailable right now.'**
  String get chatDraftUnavailable;

  /// No description provided for @chatDraftMissingContent.
  ///
  /// In en, this message translates to:
  /// **'Add a message, subject, or attachment before saving.'**
  String get chatDraftMissingContent;

  /// No description provided for @chatDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to Drafts.'**
  String get chatDraftSaved;

  /// No description provided for @chatDraftSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save draft. Try again.'**
  String get chatDraftSaveFailed;

  /// No description provided for @chatAttachmentInaccessible.
  ///
  /// In en, this message translates to:
  /// **'Selected file is not accessible.'**
  String get chatAttachmentInaccessible;

  /// No description provided for @chatAttachmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to attach file.'**
  String get chatAttachmentFailed;

  /// No description provided for @chatAttachmentView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get chatAttachmentView;

  /// No description provided for @chatAttachmentRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry upload'**
  String get chatAttachmentRetry;

  /// No description provided for @chatAttachmentRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get chatAttachmentRemove;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @toastWhoopsTitle.
  ///
  /// In en, this message translates to:
  /// **'Whoops'**
  String get toastWhoopsTitle;

  /// No description provided for @toastHeadsUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Heads up'**
  String get toastHeadsUpTitle;

  /// No description provided for @toastAllSetTitle.
  ///
  /// In en, this message translates to:
  /// **'All set'**
  String get toastAllSetTitle;

  /// No description provided for @chatRoomMembers.
  ///
  /// In en, this message translates to:
  /// **'Room members'**
  String get chatRoomMembers;

  /// No description provided for @chatCloseSettings.
  ///
  /// In en, this message translates to:
  /// **'Close settings'**
  String get chatCloseSettings;

  /// No description provided for @chatSettings.
  ///
  /// In en, this message translates to:
  /// **'Chat settings'**
  String get chatSettings;

  /// No description provided for @chatEmptySearch.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get chatEmptySearch;

  /// No description provided for @chatEmptyMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages'**
  String get chatEmptyMessages;

  /// No description provided for @chatComposerEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Send email message'**
  String get chatComposerEmailHint;

  /// No description provided for @chatComposerMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get chatComposerMessageHint;

  /// No description provided for @chatReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get chatReadOnly;

  /// No description provided for @chatUnarchivePrompt.
  ///
  /// In en, this message translates to:
  /// **'Unarchive to send new messages.'**
  String get chatUnarchivePrompt;

  /// No description provided for @chatEmojiPicker.
  ///
  /// In en, this message translates to:
  /// **'Emoji picker'**
  String get chatEmojiPicker;

  /// No description provided for @chatShowingDirectOnly.
  ///
  /// In en, this message translates to:
  /// **'Showing direct only'**
  String get chatShowingDirectOnly;

  /// No description provided for @chatShowingAll.
  ///
  /// In en, this message translates to:
  /// **'Showing all'**
  String get chatShowingAll;

  /// No description provided for @chatMuteNotifications.
  ///
  /// In en, this message translates to:
  /// **'Mute notifications'**
  String get chatMuteNotifications;

  /// No description provided for @chatEnableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get chatEnableNotifications;

  /// No description provided for @chatMoveToInbox.
  ///
  /// In en, this message translates to:
  /// **'Move to inbox'**
  String get chatMoveToInbox;

  /// No description provided for @chatReportSpam.
  ///
  /// In en, this message translates to:
  /// **'Report spam'**
  String get chatReportSpam;

  /// No description provided for @chatSignatureToggleLabel.
  ///
  /// In en, this message translates to:
  /// **'Include share token footer for email'**
  String get chatSignatureToggleLabel;

  /// No description provided for @chatSignatureHintEnabled.
  ///
  /// In en, this message translates to:
  /// **'Helps keep multi-recipient email threads intact.'**
  String get chatSignatureHintEnabled;

  /// No description provided for @chatSignatureHintDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled globally; replies may not thread.'**
  String get chatSignatureHintDisabled;

  /// No description provided for @chatSignatureHintWarning.
  ///
  /// In en, this message translates to:
  /// **'Disabling can break threading and attachment grouping.'**
  String get chatSignatureHintWarning;

  /// No description provided for @chatInviteRevoked.
  ///
  /// In en, this message translates to:
  /// **'Invite revoked'**
  String get chatInviteRevoked;

  /// No description provided for @chatInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get chatInvite;

  /// No description provided for @chatReactionsNone.
  ///
  /// In en, this message translates to:
  /// **'No reactions yet'**
  String get chatReactionsNone;

  /// No description provided for @chatReactionsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Tap a reaction to add or remove yours'**
  String get chatReactionsPrompt;

  /// No description provided for @chatReactionsPick.
  ///
  /// In en, this message translates to:
  /// **'Pick an emoji to react'**
  String get chatReactionsPick;

  /// No description provided for @chatActionReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatActionReply;

  /// No description provided for @chatActionForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get chatActionForward;

  /// No description provided for @chatActionResend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get chatActionResend;

  /// No description provided for @chatActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chatActionEdit;

  /// No description provided for @chatActionRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get chatActionRevoke;

  /// No description provided for @chatActionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatActionCopy;

  /// No description provided for @chatActionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get chatActionShare;

  /// No description provided for @chatActionAddToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add to calendar'**
  String get chatActionAddToCalendar;

  /// No description provided for @chatActionDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get chatActionDetails;

  /// No description provided for @chatActionSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get chatActionSelect;

  /// No description provided for @chatActionReact.
  ///
  /// In en, this message translates to:
  /// **'React'**
  String get chatActionReact;

  /// No description provided for @chatContactRenameAction.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get chatContactRenameAction;

  /// No description provided for @chatContactRenameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rename contact'**
  String get chatContactRenameTooltip;

  /// No description provided for @chatContactRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename contact'**
  String get chatContactRenameTitle;

  /// No description provided for @chatContactRenameDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose how this contact appears across Axichat.'**
  String get chatContactRenameDescription;

  /// No description provided for @chatContactRenamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get chatContactRenamePlaceholder;

  /// No description provided for @chatContactRenameReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get chatContactRenameReset;

  /// No description provided for @chatContactRenameSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get chatContactRenameSave;

  /// No description provided for @chatContactRenameSuccess.
  ///
  /// In en, this message translates to:
  /// **'Display name updated'**
  String get chatContactRenameSuccess;

  /// No description provided for @chatContactRenameFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not rename contact'**
  String get chatContactRenameFailure;

  /// No description provided for @chatComposerSemantics.
  ///
  /// In en, this message translates to:
  /// **'Message input'**
  String get chatComposerSemantics;

  /// No description provided for @draftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get draftSaved;

  /// No description provided for @draftErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Whoops'**
  String get draftErrorTitle;

  /// No description provided for @draftNoRecipients.
  ///
  /// In en, this message translates to:
  /// **'No recipients'**
  String get draftNoRecipients;

  /// No description provided for @draftSubjectSemantics.
  ///
  /// In en, this message translates to:
  /// **'Email subject'**
  String get draftSubjectSemantics;

  /// No description provided for @draftSubjectHintOptional.
  ///
  /// In en, this message translates to:
  /// **'Subject (optional)'**
  String get draftSubjectHintOptional;

  /// No description provided for @draftMessageSemantics.
  ///
  /// In en, this message translates to:
  /// **'Message body'**
  String get draftMessageSemantics;

  /// No description provided for @draftMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get draftMessageHint;

  /// No description provided for @draftSendingStatus.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get draftSendingStatus;

  /// No description provided for @draftSendingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get draftSendingEllipsis;

  /// No description provided for @draftSend.
  ///
  /// In en, this message translates to:
  /// **'Send draft'**
  String get draftSend;

  /// No description provided for @draftDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get draftDiscard;

  /// No description provided for @draftSave.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get draftSave;

  /// No description provided for @draftAttachmentInaccessible.
  ///
  /// In en, this message translates to:
  /// **'Selected file is not accessible.'**
  String get draftAttachmentInaccessible;

  /// No description provided for @draftAttachmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to attach file.'**
  String get draftAttachmentFailed;

  /// No description provided for @draftDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Draft discarded.'**
  String get draftDiscarded;

  /// No description provided for @draftSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send draft.'**
  String get draftSendFailed;

  /// No description provided for @draftSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get draftSent;

  /// No description provided for @draftValidationNoContent.
  ///
  /// In en, this message translates to:
  /// **'Add a subject, message, or attachment'**
  String get draftValidationNoContent;

  /// No description provided for @draftFileMissing.
  ///
  /// In en, this message translates to:
  /// **'File no longer exists at {path}.'**
  String draftFileMissing(Object path);

  /// No description provided for @draftAttachmentPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get draftAttachmentPreview;

  /// No description provided for @draftRemoveAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get draftRemoveAttachment;

  /// No description provided for @draftNoAttachments.
  ///
  /// In en, this message translates to:
  /// **'No attachments yet'**
  String get draftNoAttachments;

  /// No description provided for @draftAttachmentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get draftAttachmentsLabel;

  /// No description provided for @draftAddAttachment.
  ///
  /// In en, this message translates to:
  /// **'Add attachment'**
  String get draftAddAttachment;

  /// No description provided for @draftTaskDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String draftTaskDue(Object date);

  /// No description provided for @draftTaskNoSchedule.
  ///
  /// In en, this message translates to:
  /// **'No schedule'**
  String get draftTaskNoSchedule;

  /// No description provided for @draftTaskUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled task'**
  String get draftTaskUntitled;

  /// No description provided for @chatBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get chatBack;

  /// No description provided for @chatErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error!'**
  String get chatErrorLabel;

  /// No description provided for @chatSenderYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chatSenderYou;

  /// No description provided for @chatInviteAlreadyInRoom.
  ///
  /// In en, this message translates to:
  /// **'Already in this room.'**
  String get chatInviteAlreadyInRoom;

  /// No description provided for @chatInviteWrongAccount.
  ///
  /// In en, this message translates to:
  /// **'Invite is not for this account.'**
  String get chatInviteWrongAccount;

  /// No description provided for @chatShareNoText.
  ///
  /// In en, this message translates to:
  /// **'Message has no text to share'**
  String get chatShareNoText;

  /// No description provided for @chatShareFallbackSubject.
  ///
  /// In en, this message translates to:
  /// **'Axichat message'**
  String get chatShareFallbackSubject;

  /// No description provided for @chatShareSubjectPrefix.
  ///
  /// In en, this message translates to:
  /// **'Shared from {chatTitle}'**
  String chatShareSubjectPrefix(Object chatTitle);

  /// No description provided for @chatCalendarNoText.
  ///
  /// In en, this message translates to:
  /// **'Message has no text to add to calendar'**
  String get chatCalendarNoText;

  /// No description provided for @chatCalendarUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Calendar is unavailable right now'**
  String get chatCalendarUnavailable;

  /// No description provided for @chatCopyNoText.
  ///
  /// In en, this message translates to:
  /// **'Selected messages have no text to copy'**
  String get chatCopyNoText;

  /// No description provided for @chatShareSelectedNoText.
  ///
  /// In en, this message translates to:
  /// **'Selected messages have no text to share'**
  String get chatShareSelectedNoText;

  /// No description provided for @chatForwardInviteForbidden.
  ///
  /// In en, this message translates to:
  /// **'Invites cannot be forwarded.'**
  String get chatForwardInviteForbidden;

  /// No description provided for @chatAddToCalendarNoText.
  ///
  /// In en, this message translates to:
  /// **'Selected messages have no text to add to calendar'**
  String get chatAddToCalendarNoText;

  /// No description provided for @chatForwardDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Forward to...'**
  String get chatForwardDialogTitle;

  /// No description provided for @chatComposerAttachmentWarning.
  ///
  /// In en, this message translates to:
  /// **'Large attachments are sent separately to each recipient and may take longer to deliver.'**
  String get chatComposerAttachmentWarning;

  /// No description provided for @chatFanOutRecipientLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {recipient} other {recipients}}'**
  String chatFanOutRecipientLabel(int count);

  /// No description provided for @chatFanOutFailureWithSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject \"{subject}\" failed to send to {count} {recipientLabel}.'**
  String chatFanOutFailureWithSubject(
      Object subject, int count, Object recipientLabel);

  /// No description provided for @chatFanOutFailure.
  ///
  /// In en, this message translates to:
  /// **'Failed to send to {count} {recipientLabel}.'**
  String chatFanOutFailure(int count, Object recipientLabel);

  /// No description provided for @chatFanOutRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get chatFanOutRetry;

  /// No description provided for @chatSubjectSemantics.
  ///
  /// In en, this message translates to:
  /// **'Email subject'**
  String get chatSubjectSemantics;

  /// No description provided for @chatSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get chatSubjectHint;

  /// No description provided for @chatAttachmentTooltip.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get chatAttachmentTooltip;

  /// No description provided for @chatSendMessageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get chatSendMessageTooltip;

  /// No description provided for @chatBlockAction.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get chatBlockAction;

  /// No description provided for @chatReactionMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chatReactionMore;

  /// No description provided for @chatQuotedNoContent.
  ///
  /// In en, this message translates to:
  /// **'(no content)'**
  String get chatQuotedNoContent;

  /// No description provided for @chatReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to...'**
  String get chatReplyingTo;

  /// No description provided for @chatCancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get chatCancelReply;

  /// No description provided for @chatMessageRetracted.
  ///
  /// In en, this message translates to:
  /// **'(retracted)'**
  String get chatMessageRetracted;

  /// No description provided for @chatMessageEdited.
  ///
  /// In en, this message translates to:
  /// **'(edited)'**
  String get chatMessageEdited;

  /// No description provided for @chatGuestAttachmentsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Attachments are disabled in preview.'**
  String get chatGuestAttachmentsDisabled;

  /// No description provided for @chatGuestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Guest preview • Stored locally'**
  String get chatGuestSubtitle;

  /// No description provided for @recipientsOverflowMore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {+1 more} other {+{count} more}}'**
  String recipientsOverflowMore(int count);

  /// No description provided for @recipientsCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get recipientsCollapse;

  /// No description provided for @recipientsSemantics.
  ///
  /// In en, this message translates to:
  /// **'Recipients {count}, {state}'**
  String recipientsSemantics(int count, Object state);

  /// No description provided for @recipientsStateCollapsed.
  ///
  /// In en, this message translates to:
  /// **'collapsed'**
  String get recipientsStateCollapsed;

  /// No description provided for @recipientsStateExpanded.
  ///
  /// In en, this message translates to:
  /// **'expanded'**
  String get recipientsStateExpanded;

  /// No description provided for @recipientsHintExpand.
  ///
  /// In en, this message translates to:
  /// **'Press to expand'**
  String get recipientsHintExpand;

  /// No description provided for @recipientsHintCollapse.
  ///
  /// In en, this message translates to:
  /// **'Press to collapse'**
  String get recipientsHintCollapse;

  /// No description provided for @recipientsHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to...'**
  String get recipientsHeaderTitle;

  /// No description provided for @recipientsFallbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get recipientsFallbackLabel;

  /// No description provided for @recipientsAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add...'**
  String get recipientsAddHint;

  /// No description provided for @chatGuestScriptWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Axichat—chat, email, and calendar in one place.'**
  String get chatGuestScriptWelcome;

  /// No description provided for @chatGuestScriptExternalQuestion.
  ///
  /// In en, this message translates to:
  /// **'Looks clean. Can I message people who aren\'t on Axichat?'**
  String get chatGuestScriptExternalQuestion;

  /// No description provided for @chatGuestScriptExternalAnswer.
  ///
  /// In en, this message translates to:
  /// **'Yep—send chat-formatted email to Gmail, Outlook, Tuta, and more. If both of you use Axichat you also get groupchats, reactions, delivery receipts, and more.'**
  String get chatGuestScriptExternalAnswer;

  /// No description provided for @chatGuestScriptOfflineQuestion.
  ///
  /// In en, this message translates to:
  /// **'Does it work offline or in guest mode?'**
  String get chatGuestScriptOfflineQuestion;

  /// No description provided for @chatGuestScriptOfflineAnswer.
  ///
  /// In en, this message translates to:
  /// **'Yes—offline functionality is built in, and the calendar even works in Guest Mode without an account or internet.'**
  String get chatGuestScriptOfflineAnswer;

  /// No description provided for @chatGuestScriptKeepUpQuestion.
  ///
  /// In en, this message translates to:
  /// **'How does it help me keep up with everything?'**
  String get chatGuestScriptKeepUpQuestion;

  /// No description provided for @chatGuestScriptKeepUpAnswer.
  ///
  /// In en, this message translates to:
  /// **'Our calendar does natural language scheduling, Eisenhower Matrix triage, drag-and-drop, and reminders so you can focus on what matters.'**
  String get chatGuestScriptKeepUpAnswer;

  /// No description provided for @calendarParserUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Parser unavailable ({errorType})'**
  String calendarParserUnavailable(Object errorType);

  /// No description provided for @calendarAddTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get calendarAddTaskTitle;

  /// No description provided for @calendarTaskNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Task name *'**
  String get calendarTaskNameRequired;

  /// No description provided for @calendarTaskNameHint.
  ///
  /// In en, this message translates to:
  /// **'Task name'**
  String get calendarTaskNameHint;

  /// No description provided for @calendarDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get calendarDescriptionHint;

  /// No description provided for @calendarLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get calendarLocationHint;

  /// No description provided for @calendarScheduleLabel.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get calendarScheduleLabel;

  /// No description provided for @calendarDeadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get calendarDeadlineLabel;

  /// No description provided for @calendarRepeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get calendarRepeatLabel;

  /// No description provided for @calendarCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get calendarCancel;

  /// No description provided for @calendarAddTaskAction.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get calendarAddTaskAction;

  /// No description provided for @calendarSelectionMode.
  ///
  /// In en, this message translates to:
  /// **'Selection mode'**
  String get calendarSelectionMode;

  /// No description provided for @calendarExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get calendarExit;

  /// No description provided for @calendarTasksSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# task selected} other {# tasks selected}}'**
  String calendarTasksSelected(int count);

  /// No description provided for @calendarActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get calendarActions;

  /// No description provided for @calendarSetPriority.
  ///
  /// In en, this message translates to:
  /// **'Set priority'**
  String get calendarSetPriority;

  /// No description provided for @calendarClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear Selection'**
  String get calendarClearSelection;

  /// No description provided for @calendarExportSelected.
  ///
  /// In en, this message translates to:
  /// **'Export selected'**
  String get calendarExportSelected;

  /// No description provided for @calendarDeleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get calendarDeleteSelected;

  /// No description provided for @calendarBatchEdit.
  ///
  /// In en, this message translates to:
  /// **'Batch edit'**
  String get calendarBatchEdit;

  /// No description provided for @calendarBatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get calendarBatchTitle;

  /// No description provided for @calendarBatchTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Set title for selected tasks'**
  String get calendarBatchTitleHint;

  /// No description provided for @calendarBatchDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get calendarBatchDescription;

  /// No description provided for @calendarBatchDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Set description (leave blank to clear)'**
  String get calendarBatchDescriptionHint;

  /// No description provided for @calendarBatchLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get calendarBatchLocation;

  /// No description provided for @calendarBatchLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Set location (leave blank to clear)'**
  String get calendarBatchLocationHint;

  /// No description provided for @calendarApplyChanges.
  ///
  /// In en, this message translates to:
  /// **'Apply changes'**
  String get calendarApplyChanges;

  /// No description provided for @calendarAdjustTime.
  ///
  /// In en, this message translates to:
  /// **'Adjust time'**
  String get calendarAdjustTime;

  /// No description provided for @calendarSelectionRequired.
  ///
  /// In en, this message translates to:
  /// **'Select tasks before applying changes.'**
  String get calendarSelectionRequired;

  /// No description provided for @calendarSelectionNone.
  ///
  /// In en, this message translates to:
  /// **'Select tasks to export first.'**
  String get calendarSelectionNone;

  /// No description provided for @calendarSelectionChangesApplied.
  ///
  /// In en, this message translates to:
  /// **'Changes applied to selected tasks.'**
  String get calendarSelectionChangesApplied;

  /// No description provided for @calendarSelectionNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending changes to apply.'**
  String get calendarSelectionNoPending;

  /// No description provided for @calendarSelectionTitleBlank.
  ///
  /// In en, this message translates to:
  /// **'Title cannot be blank.'**
  String get calendarSelectionTitleBlank;

  /// No description provided for @calendarExportReady.
  ///
  /// In en, this message translates to:
  /// **'Export ready to share.'**
  String get calendarExportReady;

  /// No description provided for @calendarExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export selected tasks: {error}'**
  String calendarExportFailed(Object error);

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @composeTitle.
  ///
  /// In en, this message translates to:
  /// **'Compose'**
  String get composeTitle;

  /// No description provided for @draftComposeMessage.
  ///
  /// In en, this message translates to:
  /// **'Compose a message'**
  String get draftComposeMessage;

  /// No description provided for @draftCompose.
  ///
  /// In en, this message translates to:
  /// **'Compose'**
  String get draftCompose;

  /// No description provided for @draftNewMessage.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get draftNewMessage;

  /// No description provided for @draftRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get draftRestore;

  /// No description provided for @draftMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get draftMinimize;

  /// No description provided for @draftExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get draftExpand;

  /// No description provided for @draftExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get draftExitFullscreen;

  /// No description provided for @draftCloseComposer.
  ///
  /// In en, this message translates to:
  /// **'Close composer'**
  String get draftCloseComposer;

  /// No description provided for @draftsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No drafts yet'**
  String get draftsEmpty;

  /// No description provided for @draftsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete draft?'**
  String get draftsDeleteConfirm;

  /// No description provided for @draftNoSubject.
  ///
  /// In en, this message translates to:
  /// **'(no subject)'**
  String get draftNoSubject;

  /// No description provided for @draftRecipientCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 recipient} other {{count} recipients}}'**
  String draftRecipientCount(num count);

  /// No description provided for @authCreatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating your account…'**
  String get authCreatingAccount;

  /// No description provided for @authSecuringLogin.
  ///
  /// In en, this message translates to:
  /// **'Securing your login…'**
  String get authSecuringLogin;

  /// No description provided for @authLoggingIn.
  ///
  /// In en, this message translates to:
  /// **'Logging you in…'**
  String get authLoggingIn;

  /// No description provided for @authToggleSignup.
  ///
  /// In en, this message translates to:
  /// **'New? Sign up'**
  String get authToggleSignup;

  /// No description provided for @authToggleLogin.
  ///
  /// In en, this message translates to:
  /// **'Already registered? Log in'**
  String get authToggleLogin;

  /// No description provided for @authGuestCalendarCta.
  ///
  /// In en, this message translates to:
  /// **'Try Calendar (Guest Mode)'**
  String get authGuestCalendarCta;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLogin;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authSignUp;

  /// No description provided for @authToggleSelected.
  ///
  /// In en, this message translates to:
  /// **'Current selection'**
  String get authToggleSelected;

  /// No description provided for @authToggleSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Activate to select {label}'**
  String authToggleSelectHint(Object label);

  /// No description provided for @authUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get authUsername;

  /// No description provided for @authUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a username'**
  String get authUsernameRequired;

  /// No description provided for @authUsernameRules.
  ///
  /// In en, this message translates to:
  /// **'4-20 alphanumeric, allowing \".\", \"_\" and \"-\".'**
  String get authUsernameRules;

  /// No description provided for @authUsernameCaseInsensitive.
  ///
  /// In en, this message translates to:
  /// **'Case insensitive'**
  String get authUsernameCaseInsensitive;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authPasswordConfirm;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Must be {max} characters or fewer'**
  String authPasswordMaxLength(Object max);

  /// No description provided for @authPasswordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get authPasswordsMismatch;

  /// No description provided for @authPasswordPending.
  ///
  /// In en, this message translates to:
  /// **'Checking password safety'**
  String get authPasswordPending;

  /// No description provided for @authSignupPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for signup'**
  String get authSignupPending;

  /// No description provided for @authLoginPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for login'**
  String get authLoginPending;

  /// No description provided for @signupTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signupTitle;

  /// No description provided for @signupStepUsername.
  ///
  /// In en, this message translates to:
  /// **'Choose username'**
  String get signupStepUsername;

  /// No description provided for @signupStepPassword.
  ///
  /// In en, this message translates to:
  /// **'Create password'**
  String get signupStepPassword;

  /// No description provided for @signupStepCaptcha.
  ///
  /// In en, this message translates to:
  /// **'Verify captcha'**
  String get signupStepCaptcha;

  /// No description provided for @signupStepSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get signupStepSetup;

  /// No description provided for @signupErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String signupErrorPrefix(Object message);

  /// No description provided for @signupCaptchaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Captcha unavailable'**
  String get signupCaptchaUnavailable;

  /// No description provided for @signupCaptchaChallenge.
  ///
  /// In en, this message translates to:
  /// **'Captcha challenge'**
  String get signupCaptchaChallenge;

  /// No description provided for @signupCaptchaFailed.
  ///
  /// In en, this message translates to:
  /// **'Captcha failed to load. Use reload to try again.'**
  String get signupCaptchaFailed;

  /// No description provided for @signupCaptchaLoading.
  ///
  /// In en, this message translates to:
  /// **'Captcha loading'**
  String get signupCaptchaLoading;

  /// No description provided for @signupCaptchaInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the characters shown in this captcha image.'**
  String get signupCaptchaInstructions;

  /// No description provided for @signupCaptchaReload.
  ///
  /// In en, this message translates to:
  /// **'Reload captcha'**
  String get signupCaptchaReload;

  /// No description provided for @signupCaptchaReloadHint.
  ///
  /// In en, this message translates to:
  /// **'Get a new captcha image if you cannot read this one.'**
  String get signupCaptchaReloadHint;

  /// No description provided for @signupCaptchaPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter the above text'**
  String get signupCaptchaPlaceholder;

  /// No description provided for @signupCaptchaValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter the text from the image'**
  String get signupCaptchaValidation;

  /// No description provided for @signupContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get signupContinue;

  /// No description provided for @signupProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Signup progress'**
  String get signupProgressLabel;

  /// No description provided for @signupProgressValue.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}: {currentLabel}. {percent}% complete.'**
  String signupProgressValue(
      Object current, Object currentLabel, Object percent, Object total);

  /// No description provided for @signupProgressSection.
  ///
  /// In en, this message translates to:
  /// **'Account setup'**
  String get signupProgressSection;

  /// No description provided for @signupPasswordStrength.
  ///
  /// In en, this message translates to:
  /// **'Password strength'**
  String get signupPasswordStrength;

  /// No description provided for @signupPasswordBreached.
  ///
  /// In en, this message translates to:
  /// **'This password has been found in a hacked database.'**
  String get signupPasswordBreached;

  /// No description provided for @signupStrengthNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get signupStrengthNone;

  /// No description provided for @signupStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get signupStrengthWeak;

  /// No description provided for @signupStrengthMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get signupStrengthMedium;

  /// No description provided for @signupStrengthStronger.
  ///
  /// In en, this message translates to:
  /// **'Stronger'**
  String get signupStrengthStronger;

  /// No description provided for @signupRiskAcknowledgement.
  ///
  /// In en, this message translates to:
  /// **'I understand the risk'**
  String get signupRiskAcknowledgement;

  /// No description provided for @signupRiskError.
  ///
  /// In en, this message translates to:
  /// **'Check the box above to continue.'**
  String get signupRiskError;

  /// No description provided for @signupRiskAllowBreach.
  ///
  /// In en, this message translates to:
  /// **'Allow this password even though it appeared in a breach.'**
  String get signupRiskAllowBreach;

  /// No description provided for @signupRiskAllowWeak.
  ///
  /// In en, this message translates to:
  /// **'Allow this password even though it is considered weak.'**
  String get signupRiskAllowWeak;

  /// No description provided for @signupCaptchaErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to load captcha.\nTap refresh to try again.'**
  String get signupCaptchaErrorMessage;

  /// No description provided for @notificationsRestartTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart app to enable notifications'**
  String get notificationsRestartTitle;

  /// No description provided for @notificationsRestartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Required permissions already granted'**
  String get notificationsRestartSubtitle;

  /// No description provided for @notificationsMessageToggle.
  ///
  /// In en, this message translates to:
  /// **'Message notifications'**
  String get notificationsMessageToggle;

  /// No description provided for @notificationsRequiresRestart.
  ///
  /// In en, this message translates to:
  /// **'Requires restart'**
  String get notificationsRequiresRestart;

  /// No description provided for @notificationsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable message notifications'**
  String get notificationsDialogTitle;

  /// No description provided for @notificationsDialogIgnore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get notificationsDialogIgnore;

  /// No description provided for @notificationsDialogContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get notificationsDialogContinue;

  /// No description provided for @notificationsDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Chats can always be muted later.'**
  String get notificationsDialogDescription;

  /// No description provided for @calendarAdjustStartMinus.
  ///
  /// In en, this message translates to:
  /// **'Start -15m'**
  String get calendarAdjustStartMinus;

  /// No description provided for @calendarAdjustStartPlus.
  ///
  /// In en, this message translates to:
  /// **'Start +15m'**
  String get calendarAdjustStartPlus;

  /// No description provided for @calendarAdjustEndMinus.
  ///
  /// In en, this message translates to:
  /// **'End -15m'**
  String get calendarAdjustEndMinus;

  /// No description provided for @calendarAdjustEndPlus.
  ///
  /// In en, this message translates to:
  /// **'End +15m'**
  String get calendarAdjustEndPlus;

  /// No description provided for @calendarCopyToClipboardAction.
  ///
  /// In en, this message translates to:
  /// **'Copy to Clipboard'**
  String get calendarCopyToClipboardAction;

  /// No description provided for @calendarCopyLocation.
  ///
  /// In en, this message translates to:
  /// **'Location: {location}'**
  String calendarCopyLocation(Object location);

  /// No description provided for @calendarTaskCopied.
  ///
  /// In en, this message translates to:
  /// **'Task copied'**
  String get calendarTaskCopied;

  /// No description provided for @calendarTaskCopiedClipboard.
  ///
  /// In en, this message translates to:
  /// **'Task copied to clipboard'**
  String get calendarTaskCopiedClipboard;

  /// No description provided for @calendarCopyTask.
  ///
  /// In en, this message translates to:
  /// **'Copy Task'**
  String get calendarCopyTask;

  /// No description provided for @calendarDeleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get calendarDeleteTask;

  /// No description provided for @calendarSelectionNoneShort.
  ///
  /// In en, this message translates to:
  /// **'No tasks selected.'**
  String get calendarSelectionNoneShort;

  /// No description provided for @calendarSelectionMixedRecurrence.
  ///
  /// In en, this message translates to:
  /// **'Tasks have different recurrence settings. Updates will apply to all selected tasks.'**
  String get calendarSelectionMixedRecurrence;

  /// No description provided for @calendarSelectionNoTasksHint.
  ///
  /// In en, this message translates to:
  /// **'No tasks selected. Use the Select option in the calendar to pick tasks to edit.'**
  String get calendarSelectionNoTasksHint;

  /// No description provided for @calendarSelectionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from selection'**
  String get calendarSelectionRemove;

  /// No description provided for @calendarQuickTaskHint.
  ///
  /// In en, this message translates to:
  /// **'Quick task (e.g., \"Meeting at 2pm in Room 101\")'**
  String get calendarQuickTaskHint;

  /// No description provided for @calendarAdvancedHide.
  ///
  /// In en, this message translates to:
  /// **'Hide advanced options'**
  String get calendarAdvancedHide;

  /// No description provided for @calendarAdvancedShow.
  ///
  /// In en, this message translates to:
  /// **'Show advanced options'**
  String get calendarAdvancedShow;

  /// No description provided for @calendarUnscheduledTitle.
  ///
  /// In en, this message translates to:
  /// **'Unscheduled tasks'**
  String get calendarUnscheduledTitle;

  /// No description provided for @calendarUnscheduledEmptyLabel.
  ///
  /// In en, this message translates to:
  /// **'No unscheduled tasks'**
  String get calendarUnscheduledEmptyLabel;

  /// No description provided for @calendarUnscheduledEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tasks you add will appear here'**
  String get calendarUnscheduledEmptyHint;

  /// No description provided for @calendarRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get calendarRemindersTitle;

  /// No description provided for @calendarRemindersEmptyLabel.
  ///
  /// In en, this message translates to:
  /// **'No reminders yet'**
  String get calendarRemindersEmptyLabel;

  /// No description provided for @calendarRemindersEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add a deadline to create a reminder'**
  String get calendarRemindersEmptyHint;

  /// No description provided for @calendarNothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get calendarNothingHere;

  /// No description provided for @calendarTaskNotFound.
  ///
  /// In en, this message translates to:
  /// **'Task not found'**
  String get calendarTaskNotFound;

  /// No description provided for @calendarDayEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Day events'**
  String get calendarDayEventsTitle;

  /// No description provided for @calendarDayEventsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No day-level events for this date'**
  String get calendarDayEventsEmpty;

  /// No description provided for @calendarDayEventsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add day event'**
  String get calendarDayEventsAdd;

  /// No description provided for @accessibilityNewContactLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact address'**
  String get accessibilityNewContactLabel;

  /// No description provided for @accessibilityNewContactHint.
  ///
  /// In en, this message translates to:
  /// **'someone@example.com'**
  String get accessibilityNewContactHint;

  /// No description provided for @accessibilityStartChat.
  ///
  /// In en, this message translates to:
  /// **'Start chat'**
  String get accessibilityStartChat;

  /// No description provided for @accessibilityStartChatHint.
  ///
  /// In en, this message translates to:
  /// **'Submit this address to start a conversation.'**
  String get accessibilityStartChatHint;

  /// No description provided for @accessibilityMessagesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get accessibilityMessagesEmpty;

  /// No description provided for @accessibilityMessageNoContent.
  ///
  /// In en, this message translates to:
  /// **'No message content'**
  String get accessibilityMessageNoContent;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileJidDescription.
  ///
  /// In en, this message translates to:
  /// **'This is your Jabber ID. Comprised of your username and domain, it\'s a unique address that represents you on the XMPP network.'**
  String get profileJidDescription;

  /// No description provided for @profileResourceDescription.
  ///
  /// In en, this message translates to:
  /// **'This is your XMPP resource. Every device you use has a different one, which is why your phone can have a different presence to your desktop.'**
  String get profileResourceDescription;

  /// No description provided for @profileStatusPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Status message'**
  String get profileStatusPlaceholder;

  /// No description provided for @profileArchives.
  ///
  /// In en, this message translates to:
  /// **'View archives'**
  String get profileArchives;

  /// No description provided for @profileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get profileChangePassword;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get profileDeleteAccount;

  /// No description provided for @termsAcceptLabel.
  ///
  /// In en, this message translates to:
  /// **'I accept the terms and conditions'**
  String get termsAcceptLabel;

  /// No description provided for @termsAgreementPrefix.
  ///
  /// In en, this message translates to:
  /// **'You agree to our '**
  String get termsAgreementPrefix;

  /// No description provided for @termsAgreementTerms.
  ///
  /// In en, this message translates to:
  /// **'terms'**
  String get termsAgreementTerms;

  /// No description provided for @termsAgreementAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get termsAgreementAnd;

  /// No description provided for @termsAgreementPrivacy.
  ///
  /// In en, this message translates to:
  /// **'privacy policy'**
  String get termsAgreementPrivacy;

  /// No description provided for @termsAgreementError.
  ///
  /// In en, this message translates to:
  /// **'You must accept the terms and conditions'**
  String get termsAgreementError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'HK':
            return AppLocalizationsZhHk();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
