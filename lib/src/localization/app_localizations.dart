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
    Locale('zh', 'HK'),
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

  /// No description provided for @homeBottomNavHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeBottomNavHome;

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

  /// No description provided for @homeSyncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get homeSyncTooltip;

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

  /// No description provided for @attachmentGalleryRosterTrustLabel.
  ///
  /// In en, this message translates to:
  /// **'Automatically download files from this user'**
  String get attachmentGalleryRosterTrustLabel;

  /// No description provided for @attachmentGalleryRosterTrustHint.
  ///
  /// In en, this message translates to:
  /// **'You can turn this off later in chat settings.'**
  String get attachmentGalleryRosterTrustHint;

  /// No description provided for @attachmentGalleryChatTrustLabel.
  ///
  /// In en, this message translates to:
  /// **'Always allow attachments in this chat'**
  String get attachmentGalleryChatTrustLabel;

  /// No description provided for @attachmentGalleryChatTrustHint.
  ///
  /// In en, this message translates to:
  /// **'You can turn this off later in chat settings.'**
  String get attachmentGalleryChatTrustHint;

  /// No description provided for @attachmentGalleryRosterErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to add contact'**
  String get attachmentGalleryRosterErrorTitle;

  /// No description provided for @attachmentGalleryRosterErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Downloaded this attachment once, but automatic downloads are still disabled.'**
  String get attachmentGalleryRosterErrorMessage;

  /// No description provided for @attachmentGalleryErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to load attachments.'**
  String get attachmentGalleryErrorMessage;

  /// No description provided for @attachmentGalleryAllLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get attachmentGalleryAllLabel;

  /// No description provided for @attachmentGalleryImagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get attachmentGalleryImagesLabel;

  /// No description provided for @attachmentGalleryVideosLabel.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get attachmentGalleryVideosLabel;

  /// No description provided for @attachmentGalleryFilesLabel.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get attachmentGalleryFilesLabel;

  /// No description provided for @attachmentGallerySentLabel.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get attachmentGallerySentLabel;

  /// No description provided for @attachmentGalleryReceivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get attachmentGalleryReceivedLabel;

  /// No description provided for @attachmentGalleryMetaSeparator.
  ///
  /// In en, this message translates to:
  /// **' - '**
  String get attachmentGalleryMetaSeparator;

  /// No description provided for @attachmentGalleryLayoutGridLabel.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get attachmentGalleryLayoutGridLabel;

  /// No description provided for @attachmentGalleryLayoutListLabel.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get attachmentGalleryLayoutListLabel;

  /// No description provided for @attachmentGallerySortNameAscLabel.
  ///
  /// In en, this message translates to:
  /// **'Name A-Z'**
  String get attachmentGallerySortNameAscLabel;

  /// No description provided for @attachmentGallerySortNameDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Name Z-A'**
  String get attachmentGallerySortNameDescLabel;

  /// No description provided for @attachmentGallerySortSizeAscLabel.
  ///
  /// In en, this message translates to:
  /// **'Size small to large'**
  String get attachmentGallerySortSizeAscLabel;

  /// No description provided for @attachmentGallerySortSizeDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Size large to small'**
  String get attachmentGallerySortSizeDescLabel;

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

  /// No description provided for @chatOpenLinkWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'You are about to open:\n{url}\n\nThis link contains unusual or invisible characters. Verify the address carefully (host: {host}).'**
  String chatOpenLinkWarningMessage(Object url, Object host);

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

  /// No description provided for @chatInvitePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to invite users to this room.'**
  String get chatInvitePermissionDenied;

  /// No description provided for @chatInviteDomainRestricted.
  ///
  /// In en, this message translates to:
  /// **'Invites are limited to the default domain.'**
  String get chatInviteDomainRestricted;

  /// No description provided for @chatInviteAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'User is already a member.'**
  String get chatInviteAlreadyMember;

  /// No description provided for @chatInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invite sent.'**
  String get chatInviteSent;

  /// No description provided for @chatInviteSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send invite.'**
  String get chatInviteSendFailed;

  /// No description provided for @chatInviteRevoked.
  ///
  /// In en, this message translates to:
  /// **'Invite revoked'**
  String get chatInviteRevoked;

  /// No description provided for @chatInviteRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to revoke invite.'**
  String get chatInviteRevokeFailed;

  /// No description provided for @chatInviteJoinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Joined room.'**
  String get chatInviteJoinSuccess;

  /// No description provided for @chatInviteJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not join room.'**
  String get chatInviteJoinFailed;

  /// No description provided for @chatNicknameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Nickname updated.'**
  String get chatNicknameUpdated;

  /// No description provided for @chatNicknameUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change nickname.'**
  String get chatNicknameUpdateFailed;

  /// No description provided for @chatRoomAvatarPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to update the room avatar.'**
  String get chatRoomAvatarPermissionDenied;

  /// No description provided for @chatRoomAvatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Room avatar updated.'**
  String get chatRoomAvatarUpdated;

  /// No description provided for @chatRoomAvatarUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update room avatar.'**
  String get chatRoomAvatarUpdateFailed;

  /// No description provided for @chatPinPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to pin messages in this room.'**
  String get chatPinPermissionDenied;

  /// No description provided for @chatMessageForwarded.
  ///
  /// In en, this message translates to:
  /// **'Message forwarded.'**
  String get chatMessageForwarded;

  /// No description provided for @chatMessageForwardFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to forward message.'**
  String get chatMessageForwardFailed;

  /// No description provided for @chatModerationRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested {action} for {nickname}.'**
  String chatModerationRequested(Object action, Object nickname);

  /// No description provided for @chatModerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not complete that action. Check permissions or connectivity.'**
  String get chatModerationFailed;

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

  /// No description provided for @chatComposerEmailWatermark.
  ///
  /// In en, this message translates to:
  /// **'Sent from Axichat'**
  String get chatComposerEmailWatermark;

  /// No description provided for @chatTransportChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how to send'**
  String get chatTransportChoiceTitle;

  /// No description provided for @chatTransportChoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'This address could be chat or email. How should Axichat send to {address}?'**
  String chatTransportChoiceMessage(Object address);

  /// No description provided for @chatComposerMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get chatComposerMessageHint;

  /// No description provided for @chatComposerFromHint.
  ///
  /// In en, this message translates to:
  /// **'Sending from {address}'**
  String chatComposerFromHint(Object address);

  /// No description provided for @chatComposerEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Message cannot be empty.'**
  String get chatComposerEmptyMessage;

  /// No description provided for @chatComposerEmailUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Email sending is unavailable for this chat.'**
  String get chatComposerEmailUnavailable;

  /// No description provided for @chatComposerFileUploadUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File upload is not available on this server.'**
  String get chatComposerFileUploadUnavailable;

  /// No description provided for @chatComposerSelectRecipient.
  ///
  /// In en, this message translates to:
  /// **'Select at least one recipient.'**
  String get chatComposerSelectRecipient;

  /// No description provided for @chatComposerEmailRecipientUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Email is unavailable for one or more recipients.'**
  String get chatComposerEmailRecipientUnavailable;

  /// No description provided for @chatComposerEmailAttachmentRecipientRequired.
  ///
  /// In en, this message translates to:
  /// **'Add an email recipient to send attachments.'**
  String get chatComposerEmailAttachmentRecipientRequired;

  /// No description provided for @chatComposerDraftRecipientsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to resolve recipients for this draft.'**
  String get chatComposerDraftRecipientsUnavailable;

  /// No description provided for @chatComposerSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to send message. Please try again.'**
  String get chatComposerSendFailed;

  /// No description provided for @chatComposerAttachmentBundleFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to bundle attachments. Please try again.'**
  String get chatComposerAttachmentBundleFailed;

  /// No description provided for @chatEmailOfflineRetryMessage.
  ///
  /// In en, this message translates to:
  /// **'Email is offline. Retry once sync recovers.'**
  String get chatEmailOfflineRetryMessage;

  /// No description provided for @chatEmailOfflineDraftsFallback.
  ///
  /// In en, this message translates to:
  /// **'Email is offline. Messages will be saved to Drafts until the connection returns.'**
  String get chatEmailOfflineDraftsFallback;

  /// No description provided for @chatEmailSyncRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Email sync is refreshing...'**
  String get chatEmailSyncRefreshing;

  /// No description provided for @chatEmailSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Email sync failed. Please try again.'**
  String get chatEmailSyncFailed;

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
  /// **'Mark as spam'**
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

  /// No description provided for @chatCalendarTaskCopyActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Copy to calendar'**
  String get chatCalendarTaskCopyActionLabel;

  /// No description provided for @chatCalendarTaskImportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to calendar?'**
  String get chatCalendarTaskImportConfirmTitle;

  /// No description provided for @chatCalendarTaskImportConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This task came from chat. Add it to your calendar to manage or edit it.'**
  String get chatCalendarTaskImportConfirmMessage;

  /// No description provided for @chatCalendarTaskImportConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Add to calendar'**
  String get chatCalendarTaskImportConfirmLabel;

  /// No description provided for @chatCalendarTaskImportCancelLabel.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get chatCalendarTaskImportCancelLabel;

  /// No description provided for @chatCalendarTaskCopyUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Calendar is unavailable.'**
  String get chatCalendarTaskCopyUnavailableMessage;

  /// No description provided for @chatCalendarTaskCopyAlreadyAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'Task already added.'**
  String get chatCalendarTaskCopyAlreadyAddedMessage;

  /// No description provided for @chatCalendarTaskCopySuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Task copied.'**
  String get chatCalendarTaskCopySuccessMessage;

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

  /// No description provided for @draftAutosaved.
  ///
  /// In en, this message translates to:
  /// **'Autosaved'**
  String get draftAutosaved;

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

  /// No description provided for @emailSendConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Review email before sending'**
  String get emailSendConfirmTitle;

  /// No description provided for @emailSendConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Confirm the recipients and body below before sending.'**
  String get emailSendConfirmMessage;

  /// No description provided for @emailSendConfirmRecipientsLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipients'**
  String get emailSendConfirmRecipientsLabel;

  /// No description provided for @emailSendConfirmBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get emailSendConfirmBodyLabel;

  /// No description provided for @emailSendConfirmEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'(No body)'**
  String get emailSendConfirmEmptyBody;

  /// No description provided for @emailSendConfirmDontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show this again'**
  String get emailSendConfirmDontShowAgain;

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

  /// No description provided for @draftLimitWarning.
  ///
  /// In en, this message translates to:
  /// **'Draft sync keeps up to {limit} drafts. You\'re at {count}.'**
  String draftLimitWarning(int limit, int count);

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

  /// No description provided for @chatCopySuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get chatCopySuccessMessage;

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

  /// No description provided for @chatForwardEmailWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Forward email?'**
  String get chatForwardEmailWarningTitle;

  /// No description provided for @chatForwardEmailWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Forwarding email can include original headers and external image links. Choose how to send.'**
  String get chatForwardEmailWarningMessage;

  /// No description provided for @chatForwardEmailOptionSafe.
  ///
  /// In en, this message translates to:
  /// **'Forward as new message'**
  String get chatForwardEmailOptionSafe;

  /// No description provided for @chatForwardEmailOptionOriginal.
  ///
  /// In en, this message translates to:
  /// **'Forward original'**
  String get chatForwardEmailOptionOriginal;

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
    Object subject,
    int count,
    Object recipientLabel,
  );

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

  /// No description provided for @chatCollapseLongEmails.
  ///
  /// In en, this message translates to:
  /// **'Collapse long emails'**
  String get chatCollapseLongEmails;

  /// No description provided for @chatExpandLongEmails.
  ///
  /// In en, this message translates to:
  /// **'Expand long emails'**
  String get chatExpandLongEmails;

  /// No description provided for @chatAttachmentTooltip.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get chatAttachmentTooltip;

  /// No description provided for @chatPinnedMessagesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pinned messages'**
  String get chatPinnedMessagesTooltip;

  /// No description provided for @chatPinnedMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Pinned messages'**
  String get chatPinnedMessagesTitle;

  /// No description provided for @chatPinMessage.
  ///
  /// In en, this message translates to:
  /// **'Pin message'**
  String get chatPinMessage;

  /// No description provided for @chatUnpinMessage.
  ///
  /// In en, this message translates to:
  /// **'Unpin message'**
  String get chatUnpinMessage;

  /// No description provided for @chatPinnedEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No pinned messages yet.'**
  String get chatPinnedEmptyState;

  /// No description provided for @chatPinnedMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'Pinned message is unavailable.'**
  String get chatPinnedMissingMessage;

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
  /// **'RE:'**
  String get chatReplyingTo;

  /// No description provided for @chatForwardPrefix.
  ///
  /// In en, this message translates to:
  /// **'FWD:'**
  String get chatForwardPrefix;

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
  /// **'Welcome to Axichat: chat, email, and calendar in one place.'**
  String get chatGuestScriptWelcome;

  /// No description provided for @chatGuestScriptExternalQuestion.
  ///
  /// In en, this message translates to:
  /// **'Looks clean. Can I message people who aren\'t on Axichat?'**
  String get chatGuestScriptExternalQuestion;

  /// No description provided for @chatGuestScriptExternalAnswer.
  ///
  /// In en, this message translates to:
  /// **'Yep: send chat-formatted email to Gmail, Outlook, Tuta, and more. If both of you use Axichat you also get groupchats, reactions, delivery receipts, and more.'**
  String get chatGuestScriptExternalAnswer;

  /// No description provided for @chatGuestScriptOfflineQuestion.
  ///
  /// In en, this message translates to:
  /// **'Does it work offline or in guest mode?'**
  String get chatGuestScriptOfflineQuestion;

  /// No description provided for @chatGuestScriptOfflineAnswer.
  ///
  /// In en, this message translates to:
  /// **'Yes: offline functionality is built in, and the calendar even works in Guest Mode without an account or internet.'**
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

  /// No description provided for @chatGuestScriptBubbleTip.
  ///
  /// In en, this message translates to:
  /// **'Press a message bubble to open options like forwarding, replying, and reacting.'**
  String get chatGuestScriptBubbleTip;

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

  /// No description provided for @draftRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore from draft'**
  String get draftRestoreAction;

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

  /// No description provided for @authRememberMeLabel.
  ///
  /// In en, this message translates to:
  /// **'Remember me on this device'**
  String get authRememberMeLabel;

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

  /// No description provided for @signupSkipPassword.
  ///
  /// In en, this message translates to:
  /// **'Skip password'**
  String get signupSkipPassword;

  /// No description provided for @signupSkipPasswordConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip password setup?'**
  String get signupSkipPasswordConfirmTitle;

  /// No description provided for @signupSkipPasswordConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Axichat will create a secure password and keep it only on this device. You will not be able to sign in or sync this account on any other device unless you later set a password you know in Settings. If you lose this device or delete the app, you will lose this account and all data permanently.'**
  String get signupSkipPasswordConfirmMessage;

  /// No description provided for @signupSkipPasswordConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Skip and continue'**
  String get signupSkipPasswordConfirmAction;

  /// No description provided for @signupDeviceOnlyRememberMeLocked.
  ///
  /// In en, this message translates to:
  /// **'Remember me is required while using a device-managed password.'**
  String get signupDeviceOnlyRememberMeLocked;

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
    Object current,
    Object currentLabel,
    Object percent,
    Object total,
  );

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

  /// No description provided for @signupAvatarRenderError.
  ///
  /// In en, this message translates to:
  /// **'Could not render that avatar.'**
  String get signupAvatarRenderError;

  /// No description provided for @signupAvatarLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load that avatar.'**
  String get signupAvatarLoadError;

  /// No description provided for @signupAvatarReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read that image.'**
  String get signupAvatarReadError;

  /// No description provided for @signupAvatarOpenError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open that file.'**
  String get signupAvatarOpenError;

  /// No description provided for @signupAvatarInvalidImage.
  ///
  /// In en, this message translates to:
  /// **'That file is not a valid image.'**
  String get signupAvatarInvalidImage;

  /// No description provided for @signupAvatarSizeError.
  ///
  /// In en, this message translates to:
  /// **'Avatar must be under {kilobytes} KB.'**
  String signupAvatarSizeError(Object kilobytes);

  /// No description provided for @signupAvatarProcessError.
  ///
  /// In en, this message translates to:
  /// **'Unable to process that image.'**
  String get signupAvatarProcessError;

  /// No description provided for @signupAvatarEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit avatar'**
  String get signupAvatarEdit;

  /// No description provided for @signupAvatarUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload image'**
  String get signupAvatarUploadImage;

  /// No description provided for @signupAvatarUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get signupAvatarUpload;

  /// No description provided for @signupAvatarShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle default'**
  String get signupAvatarShuffle;

  /// No description provided for @signupAvatarMenuDescription.
  ///
  /// In en, this message translates to:
  /// **'We publish the avatar when your XMPP account is created.'**
  String get signupAvatarMenuDescription;

  /// No description provided for @avatarSaveAvatar.
  ///
  /// In en, this message translates to:
  /// **'Save avatar'**
  String get avatarSaveAvatar;

  /// No description provided for @avatarUseThis.
  ///
  /// In en, this message translates to:
  /// **'Set avatar'**
  String get avatarUseThis;

  /// No description provided for @signupAvatarBackgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get signupAvatarBackgroundColor;

  /// No description provided for @signupAvatarDefaultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Default avatars'**
  String get signupAvatarDefaultsTitle;

  /// No description provided for @signupAvatarCategoryAbstract.
  ///
  /// In en, this message translates to:
  /// **'Abstract'**
  String get signupAvatarCategoryAbstract;

  /// No description provided for @signupAvatarCategoryScience.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get signupAvatarCategoryScience;

  /// No description provided for @signupAvatarCategorySports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get signupAvatarCategorySports;

  /// No description provided for @signupAvatarCategoryMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get signupAvatarCategoryMusic;

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

  /// No description provided for @accessibilityActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get accessibilityActionsTitle;

  /// No description provided for @accessibilityReadNewMessages.
  ///
  /// In en, this message translates to:
  /// **'Read new messages'**
  String get accessibilityReadNewMessages;

  /// No description provided for @accessibilityUnreadSummaryDescription.
  ///
  /// In en, this message translates to:
  /// **'Focus on conversations with unread messages'**
  String get accessibilityUnreadSummaryDescription;

  /// No description provided for @accessibilityStartNewChat.
  ///
  /// In en, this message translates to:
  /// **'Start a new chat'**
  String get accessibilityStartNewChat;

  /// No description provided for @accessibilityStartNewChatDescription.
  ///
  /// In en, this message translates to:
  /// **'Pick a contact or type an address'**
  String get accessibilityStartNewChatDescription;

  /// No description provided for @accessibilityInvitesTitle.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get accessibilityInvitesTitle;

  /// No description provided for @accessibilityPendingInvites.
  ///
  /// In en, this message translates to:
  /// **'Pending invites'**
  String get accessibilityPendingInvites;

  /// No description provided for @accessibilityAcceptInvite.
  ///
  /// In en, this message translates to:
  /// **'Accept invite'**
  String get accessibilityAcceptInvite;

  /// No description provided for @accessibilityInviteAccepted.
  ///
  /// In en, this message translates to:
  /// **'Invite accepted'**
  String get accessibilityInviteAccepted;

  /// No description provided for @accessibilityInviteDismissed.
  ///
  /// In en, this message translates to:
  /// **'Invite dismissed'**
  String get accessibilityInviteDismissed;

  /// No description provided for @accessibilityInviteUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to update invite'**
  String get accessibilityInviteUpdateFailed;

  /// No description provided for @accessibilityUnreadEmpty.
  ///
  /// In en, this message translates to:
  /// **'No unread conversations'**
  String get accessibilityUnreadEmpty;

  /// No description provided for @accessibilityInvitesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending invites'**
  String get accessibilityInvitesEmpty;

  /// No description provided for @accessibilityMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get accessibilityMessagesTitle;

  /// No description provided for @accessibilityNoConversationSelected.
  ///
  /// In en, this message translates to:
  /// **'No conversation selected'**
  String get accessibilityNoConversationSelected;

  /// No description provided for @accessibilityMessagesWithContact.
  ///
  /// In en, this message translates to:
  /// **'Messages with {name}'**
  String accessibilityMessagesWithContact(Object name);

  /// No description provided for @accessibilityMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'{sender} at {timestamp}: {body}'**
  String accessibilityMessageLabel(
    Object sender,
    Object timestamp,
    Object body,
  );

  /// No description provided for @accessibilityMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent.'**
  String get accessibilityMessageSent;

  /// No description provided for @accessibilityDiscardWarning.
  ///
  /// In en, this message translates to:
  /// **'Press Escape again to discard your message and close this step.'**
  String get accessibilityDiscardWarning;

  /// No description provided for @accessibilityDraftLoaded.
  ///
  /// In en, this message translates to:
  /// **'Draft loaded. Press Escape to exit or Save to keep edits.'**
  String get accessibilityDraftLoaded;

  /// No description provided for @accessibilityDraftLabel.
  ///
  /// In en, this message translates to:
  /// **'Draft {id}'**
  String accessibilityDraftLabel(Object id);

  /// No description provided for @accessibilityDraftLabelWithRecipients.
  ///
  /// In en, this message translates to:
  /// **'Draft to {recipients}'**
  String accessibilityDraftLabelWithRecipients(Object recipients);

  /// No description provided for @accessibilityDraftPreview.
  ///
  /// In en, this message translates to:
  /// **'{recipients} — {preview}'**
  String accessibilityDraftPreview(Object recipients, Object preview);

  /// No description provided for @accessibilityIncomingMessageStatus.
  ///
  /// In en, this message translates to:
  /// **'New message from {sender} at {time}'**
  String accessibilityIncomingMessageStatus(Object sender, Object time);

  /// No description provided for @accessibilityAttachmentWithName.
  ///
  /// In en, this message translates to:
  /// **'Attachment: {filename}'**
  String accessibilityAttachmentWithName(Object filename);

  /// No description provided for @accessibilityAttachmentGeneric.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get accessibilityAttachmentGeneric;

  /// No description provided for @accessibilityUploadAvailable.
  ///
  /// In en, this message translates to:
  /// **'Upload available'**
  String get accessibilityUploadAvailable;

  /// No description provided for @accessibilityUnknownContact.
  ///
  /// In en, this message translates to:
  /// **'Unknown contact'**
  String get accessibilityUnknownContact;

  /// No description provided for @accessibilityChooseContact.
  ///
  /// In en, this message translates to:
  /// **'Choose a contact'**
  String get accessibilityChooseContact;

  /// No description provided for @accessibilityUnreadConversations.
  ///
  /// In en, this message translates to:
  /// **'Unread conversations'**
  String get accessibilityUnreadConversations;

  /// No description provided for @accessibilityStartNewAddress.
  ///
  /// In en, this message translates to:
  /// **'Start a new address'**
  String get accessibilityStartNewAddress;

  /// No description provided for @accessibilityConversationWith.
  ///
  /// In en, this message translates to:
  /// **'Conversation with {name}'**
  String accessibilityConversationWith(Object name);

  /// No description provided for @accessibilityConversationLabel.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get accessibilityConversationLabel;

  /// No description provided for @accessibilityDialogLabel.
  ///
  /// In en, this message translates to:
  /// **'Accessibility actions dialog'**
  String get accessibilityDialogLabel;

  /// No description provided for @accessibilityDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Press Tab to reach shortcut instructions, use arrow keys inside lists, Shift plus arrows to move between groups, or Escape to exit.'**
  String get accessibilityDialogHint;

  /// No description provided for @accessibilityNoActionsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No actions available right now'**
  String get accessibilityNoActionsAvailable;

  /// No description provided for @accessibilityBreadcrumbLabel.
  ///
  /// In en, this message translates to:
  /// **'Step {position} of {total}: {label}. Activate to jump to this step.'**
  String accessibilityBreadcrumbLabel(
    Object position,
    Object total,
    Object label,
  );

  /// No description provided for @accessibilityShortcutOpenMenu.
  ///
  /// In en, this message translates to:
  /// **'Open menu'**
  String get accessibilityShortcutOpenMenu;

  /// No description provided for @accessibilityShortcutBack.
  ///
  /// In en, this message translates to:
  /// **'Back a step or close'**
  String get accessibilityShortcutBack;

  /// No description provided for @accessibilityShortcutNextFocus.
  ///
  /// In en, this message translates to:
  /// **'Next focus target'**
  String get accessibilityShortcutNextFocus;

  /// No description provided for @accessibilityShortcutPreviousFocus.
  ///
  /// In en, this message translates to:
  /// **'Previous focus target'**
  String get accessibilityShortcutPreviousFocus;

  /// No description provided for @accessibilityShortcutActivateItem.
  ///
  /// In en, this message translates to:
  /// **'Activate item'**
  String get accessibilityShortcutActivateItem;

  /// No description provided for @accessibilityShortcutNextItem.
  ///
  /// In en, this message translates to:
  /// **'Next item'**
  String get accessibilityShortcutNextItem;

  /// No description provided for @accessibilityShortcutPreviousItem.
  ///
  /// In en, this message translates to:
  /// **'Previous item'**
  String get accessibilityShortcutPreviousItem;

  /// No description provided for @accessibilityShortcutNextGroup.
  ///
  /// In en, this message translates to:
  /// **'Next group'**
  String get accessibilityShortcutNextGroup;

  /// No description provided for @accessibilityShortcutPreviousGroup.
  ///
  /// In en, this message translates to:
  /// **'Previous group'**
  String get accessibilityShortcutPreviousGroup;

  /// No description provided for @accessibilityShortcutFirstItem.
  ///
  /// In en, this message translates to:
  /// **'First item'**
  String get accessibilityShortcutFirstItem;

  /// No description provided for @accessibilityShortcutLastItem.
  ///
  /// In en, this message translates to:
  /// **'Last item'**
  String get accessibilityShortcutLastItem;

  /// No description provided for @accessibilityKeyboardShortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get accessibilityKeyboardShortcutsTitle;

  /// No description provided for @accessibilityKeyboardShortcutAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcut: {description}'**
  String accessibilityKeyboardShortcutAnnouncement(Object description);

  /// No description provided for @accessibilityTextFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Enter text. Use Tab to move forward or Escape to go back or close the menu.'**
  String get accessibilityTextFieldHint;

  /// No description provided for @accessibilityLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get accessibilityLoadingLabel;

  /// No description provided for @accessibilityComposerPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get accessibilityComposerPlaceholder;

  /// No description provided for @accessibilityRecipientLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient {name}'**
  String accessibilityRecipientLabel(Object name);

  /// No description provided for @accessibilityRecipientRemoveHint.
  ///
  /// In en, this message translates to:
  /// **'Press backspace or delete to remove'**
  String get accessibilityRecipientRemoveHint;

  /// No description provided for @accessibilityMessageActionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Message actions'**
  String get accessibilityMessageActionsLabel;

  /// No description provided for @accessibilityMessageActionsHint.
  ///
  /// In en, this message translates to:
  /// **'Save as draft or send this message'**
  String get accessibilityMessageActionsHint;

  /// No description provided for @accessibilityMessagePosition.
  ///
  /// In en, this message translates to:
  /// **'Message {position} of {total}'**
  String accessibilityMessagePosition(Object position, Object total);

  /// No description provided for @accessibilityNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages'**
  String get accessibilityNoMessages;

  /// No description provided for @accessibilityMessageMetadata.
  ///
  /// In en, this message translates to:
  /// **'From {sender} at {timestamp}'**
  String accessibilityMessageMetadata(Object sender, Object timestamp);

  /// No description provided for @accessibilityMessageFrom.
  ///
  /// In en, this message translates to:
  /// **'From {sender}'**
  String accessibilityMessageFrom(Object sender);

  /// No description provided for @accessibilityMessageNavigationHint.
  ///
  /// In en, this message translates to:
  /// **'Use arrow keys to move between messages. Shift plus arrows switches groups. Press Escape to exit.'**
  String get accessibilityMessageNavigationHint;

  /// No description provided for @accessibilitySectionSummary.
  ///
  /// In en, this message translates to:
  /// **'{section} section with {count} items'**
  String accessibilitySectionSummary(Object section, Object count);

  /// No description provided for @accessibilityActionListLabel.
  ///
  /// In en, this message translates to:
  /// **'Accessibility action list with {count} items'**
  String accessibilityActionListLabel(Object count);

  /// No description provided for @accessibilityActionListHint.
  ///
  /// In en, this message translates to:
  /// **'Use arrow keys to move, Shift plus arrows to switch groups, Home or End to jump, Enter to activate, Escape to exit.'**
  String get accessibilityActionListHint;

  /// No description provided for @accessibilityActionItemPosition.
  ///
  /// In en, this message translates to:
  /// **'Item {position} of {total} in {section}'**
  String accessibilityActionItemPosition(
    Object position,
    Object total,
    Object section,
  );

  /// No description provided for @accessibilityActionReadOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Use arrow keys to move through the list'**
  String get accessibilityActionReadOnlyHint;

  /// No description provided for @accessibilityActionActivateHint.
  ///
  /// In en, this message translates to:
  /// **'Press Enter to activate'**
  String get accessibilityActionActivateHint;

  /// No description provided for @accessibilityDismissHighlight.
  ///
  /// In en, this message translates to:
  /// **'Dismiss highlight'**
  String get accessibilityDismissHighlight;

  /// No description provided for @accessibilityNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get accessibilityNeedsAttention;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileJumpToTop.
  ///
  /// In en, this message translates to:
  /// **'Back to top'**
  String get profileJumpToTop;

  /// No description provided for @settingsWebsiteLabel.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get settingsWebsiteLabel;

  /// No description provided for @settingsDonateLabel.
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get settingsDonateLabel;

  /// No description provided for @profileDonationPromptMessage.
  ///
  /// In en, this message translates to:
  /// **'Hi {username}, please support Axichat. It is free and open source, so we rely on donations from users like you to maintain the app and keep servers running. Even \$5 goes a long way to help cover our monthly expenses.'**
  String profileDonationPromptMessage(Object username);

  /// No description provided for @settingsMastodonLabel.
  ///
  /// In en, this message translates to:
  /// **'Mastodon'**
  String get settingsMastodonLabel;

  /// No description provided for @settingsGithubLabel.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get settingsGithubLabel;

  /// No description provided for @settingsGitlabLabel.
  ///
  /// In en, this message translates to:
  /// **'GitLab'**
  String get settingsGitlabLabel;

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

  /// No description provided for @profileEditAvatar.
  ///
  /// In en, this message translates to:
  /// **'Edit avatar'**
  String get profileEditAvatar;

  /// No description provided for @profileLinkedEmailAccounts.
  ///
  /// In en, this message translates to:
  /// **'Email accounts'**
  String get profileLinkedEmailAccounts;

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

  /// No description provided for @profileExportActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Export {label}'**
  String profileExportActionLabel(Object label);

  /// No description provided for @profileExportXmppMessagesLabel.
  ///
  /// In en, this message translates to:
  /// **'XMPP messages'**
  String get profileExportXmppMessagesLabel;

  /// No description provided for @profileExportXmppContactsLabel.
  ///
  /// In en, this message translates to:
  /// **'XMPP contacts'**
  String get profileExportXmppContactsLabel;

  /// No description provided for @profileExportEmailMessagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Emails'**
  String get profileExportEmailMessagesLabel;

  /// No description provided for @profileExportEmailContactsLabel.
  ///
  /// In en, this message translates to:
  /// **'Email contacts'**
  String get profileExportEmailContactsLabel;

  /// No description provided for @profileExportShareText.
  ///
  /// In en, this message translates to:
  /// **'Axichat export: {label}'**
  String profileExportShareText(Object label);

  /// No description provided for @profileExportShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Axichat {label} export'**
  String profileExportShareSubject(Object label);

  /// No description provided for @profileExportReadyMessage.
  ///
  /// In en, this message translates to:
  /// **'{label} export ready.'**
  String profileExportReadyMessage(Object label);

  /// No description provided for @profileExportEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No {label} to export.'**
  String profileExportEmptyMessage(Object label);

  /// No description provided for @profileExportFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to export {label}.'**
  String profileExportFailedMessage(Object label);

  /// No description provided for @profileExportShareUnsupportedMessage.
  ///
  /// In en, this message translates to:
  /// **'Sharing isn\'t available on this platform. {label} export saved to {path}.'**
  String profileExportShareUnsupportedMessage(Object label, Object path);

  /// No description provided for @profileExportCopyPathAction.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get profileExportCopyPathAction;

  /// No description provided for @profileExportPathCopiedMessage.
  ///
  /// In en, this message translates to:
  /// **'Export path copied to clipboard.'**
  String get profileExportPathCopiedMessage;

  /// No description provided for @profileExportFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose export format'**
  String get profileExportFormatTitle;

  /// No description provided for @profileExportFormatCsvTitle.
  ///
  /// In en, this message translates to:
  /// **'CSV (.csv)'**
  String get profileExportFormatCsvTitle;

  /// No description provided for @profileExportFormatCsvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Works with most address books.'**
  String get profileExportFormatCsvSubtitle;

  /// No description provided for @profileExportFormatVcardTitle.
  ///
  /// In en, this message translates to:
  /// **'vCard (.vcf)'**
  String get profileExportFormatVcardTitle;

  /// No description provided for @profileExportFormatVcardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Standard contact cards.'**
  String get profileExportFormatVcardSubtitle;

  /// No description provided for @profileExportCsvHeaderName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileExportCsvHeaderName;

  /// No description provided for @profileExportCsvHeaderAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get profileExportCsvHeaderAddress;

  /// No description provided for @profileExportContactsFilenameFallback.
  ///
  /// In en, this message translates to:
  /// **'contacts'**
  String get profileExportContactsFilenameFallback;

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
  /// **'privacy'**
  String get termsAgreementPrivacy;

  /// No description provided for @termsAgreementError.
  ///
  /// In en, this message translates to:
  /// **'You must accept the terms and conditions'**
  String get termsAgreementError;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @commonDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// No description provided for @settingsButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsButtonLabel;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsSectionData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsSectionData;

  /// No description provided for @settingsSectionImportant.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get settingsSectionImportant;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSectionSecurity;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get settingsThemeMode;

  /// No description provided for @settingsThemeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeModeSystem;

  /// No description provided for @settingsThemeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeModeLight;

  /// No description provided for @settingsThemeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeModeDark;

  /// No description provided for @settingsColorScheme.
  ///
  /// In en, this message translates to:
  /// **'Color scheme'**
  String get settingsColorScheme;

  /// No description provided for @settingsColorfulAvatars.
  ///
  /// In en, this message translates to:
  /// **'Colorful avatars'**
  String get settingsColorfulAvatars;

  /// No description provided for @settingsColorfulAvatarsDescription.
  ///
  /// In en, this message translates to:
  /// **'Generate different background colors for each avatar.'**
  String get settingsColorfulAvatarsDescription;

  /// No description provided for @settingsLowMotion.
  ///
  /// In en, this message translates to:
  /// **'Low motion'**
  String get settingsLowMotion;

  /// No description provided for @settingsLowMotionDescription.
  ///
  /// In en, this message translates to:
  /// **'Disables most animations. Better for slow devices.'**
  String get settingsLowMotionDescription;

  /// No description provided for @settingsSectionChats.
  ///
  /// In en, this message translates to:
  /// **'Chat preferences'**
  String get settingsSectionChats;

  /// No description provided for @settingsSectionEmail.
  ///
  /// In en, this message translates to:
  /// **'Email preferences'**
  String get settingsSectionEmail;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsAboutAxichat.
  ///
  /// In en, this message translates to:
  /// **'About Axichat'**
  String get settingsAboutAxichat;

  /// No description provided for @settingsAboutLegalese.
  ///
  /// In en, this message translates to:
  /// **'Copyright (C) 2025 Axichat LLC\n\nThis program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.\n\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.\n\nYou should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.'**
  String get settingsAboutLegalese;

  /// No description provided for @settingsTermsLabel.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get settingsTermsLabel;

  /// No description provided for @settingsPrivacyLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacyLabel;

  /// No description provided for @settingsLicenseAgpl.
  ///
  /// In en, this message translates to:
  /// **'AGPLv3'**
  String get settingsLicenseAgpl;

  /// No description provided for @settingsMuteNotifications.
  ///
  /// In en, this message translates to:
  /// **'Mute notifications'**
  String get settingsMuteNotifications;

  /// No description provided for @settingsMuteNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Stop receiving message notifications.'**
  String get settingsMuteNotificationsDescription;

  /// No description provided for @settingsNotificationPreviews.
  ///
  /// In en, this message translates to:
  /// **'Notification previews'**
  String get settingsNotificationPreviews;

  /// No description provided for @settingsNotificationPreviewsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show message content in notifications and on the lock screen.'**
  String get settingsNotificationPreviewsDescription;

  /// No description provided for @settingsChatReadReceipts.
  ///
  /// In en, this message translates to:
  /// **'Send chat read receipts'**
  String get settingsChatReadReceipts;

  /// No description provided for @settingsChatReadReceiptsDescription.
  ///
  /// In en, this message translates to:
  /// **'When on, opening a chat while the app is active sends read receipts for visible messages.'**
  String get settingsChatReadReceiptsDescription;

  /// No description provided for @settingsChatSendOnEnter.
  ///
  /// In en, this message translates to:
  /// **'Send chat messages on Enter'**
  String get settingsChatSendOnEnter;

  /// No description provided for @settingsChatSendOnEnterDescription.
  ///
  /// In en, this message translates to:
  /// **'When on, pressing Enter sends chat messages. Shift+Enter inserts a new line.'**
  String get settingsChatSendOnEnterDescription;

  /// No description provided for @settingsEmailReadReceipts.
  ///
  /// In en, this message translates to:
  /// **'Send email read receipts'**
  String get settingsEmailReadReceipts;

  /// No description provided for @settingsEmailReadReceiptsDescription.
  ///
  /// In en, this message translates to:
  /// **'When on, opening an email chat while the app is active sends read receipts (MDNs) for visible messages.'**
  String get settingsEmailReadReceiptsDescription;

  /// No description provided for @settingsEmailSendOnEnter.
  ///
  /// In en, this message translates to:
  /// **'Send email messages on Enter'**
  String get settingsEmailSendOnEnter;

  /// No description provided for @settingsEmailSendOnEnterDescription.
  ///
  /// In en, this message translates to:
  /// **'When on, pressing Enter sends email messages. Shift+Enter inserts a new line.'**
  String get settingsEmailSendOnEnterDescription;

  /// No description provided for @settingsEmailSendConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirm before sending email'**
  String get settingsEmailSendConfirmation;

  /// No description provided for @settingsEmailSendConfirmationDescription.
  ///
  /// In en, this message translates to:
  /// **'Show a review prompt with recipients and body before each email send.'**
  String get settingsEmailSendConfirmationDescription;

  /// No description provided for @settingsEmailComposerWatermark.
  ///
  /// In en, this message translates to:
  /// **'Prepopulate email watermark'**
  String get settingsEmailComposerWatermark;

  /// No description provided for @settingsEmailComposerWatermarkDescription.
  ///
  /// In en, this message translates to:
  /// **'Pre-fills new email messages with \"Sent from Axichat\" text that you can edit or delete.'**
  String get settingsEmailComposerWatermarkDescription;

  /// No description provided for @settingsTypingIndicators.
  ///
  /// In en, this message translates to:
  /// **'Send typing indicators'**
  String get settingsTypingIndicators;

  /// No description provided for @settingsTypingIndicatorsDescription.
  ///
  /// In en, this message translates to:
  /// **'Let other people in a chat see when you are typing.'**
  String get settingsTypingIndicatorsDescription;

  /// No description provided for @settingsShareTokenFooter.
  ///
  /// In en, this message translates to:
  /// **'Include share token footer'**
  String get settingsShareTokenFooter;

  /// No description provided for @settingsShareTokenFooterDescription.
  ///
  /// In en, this message translates to:
  /// **'Adds Axichat share tokens for multi-recipient email fan-out to preserve linking and threading.'**
  String get settingsShareTokenFooterDescription;

  /// No description provided for @authCustomServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom server'**
  String get authCustomServerTitle;

  /// No description provided for @authCustomServerDescription.
  ///
  /// In en, this message translates to:
  /// **'Override XMPP/SMTP endpoints or enable DNS lookups. Leave fields blank to keep defaults. Custom servers must be created following the steps at https://github.com/axichat/server or they probably won\'t work.'**
  String get authCustomServerDescription;

  /// No description provided for @authCustomServerDomainOrIp.
  ///
  /// In en, this message translates to:
  /// **'Domain'**
  String get authCustomServerDomainOrIp;

  /// No description provided for @authCustomServerXmppLabel.
  ///
  /// In en, this message translates to:
  /// **'XMPP'**
  String get authCustomServerXmppLabel;

  /// No description provided for @authCustomServerSmtpLabel.
  ///
  /// In en, this message translates to:
  /// **'SMTP'**
  String get authCustomServerSmtpLabel;

  /// No description provided for @authCustomServerUseDns.
  ///
  /// In en, this message translates to:
  /// **'Use DNS'**
  String get authCustomServerUseDns;

  /// No description provided for @authCustomServerUseSrv.
  ///
  /// In en, this message translates to:
  /// **'Use SRV'**
  String get authCustomServerUseSrv;

  /// No description provided for @authCustomServerRequireDnssec.
  ///
  /// In en, this message translates to:
  /// **'Require DNSSEC'**
  String get authCustomServerRequireDnssec;

  /// No description provided for @authCustomServerXmppHostPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'XMPP host (optional)'**
  String get authCustomServerXmppHostPlaceholder;

  /// No description provided for @authCustomServerPortPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get authCustomServerPortPlaceholder;

  /// No description provided for @authCustomServerSmtpHostPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'SMTP host (optional)'**
  String get authCustomServerSmtpHostPlaceholder;

  /// No description provided for @authCustomServerImapHostPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'IMAP host (optional)'**
  String get authCustomServerImapHostPlaceholder;

  /// No description provided for @authCustomServerApiPortPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'API port'**
  String get authCustomServerApiPortPlaceholder;

  /// No description provided for @authCustomServerEmailProvisioningUrlPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Email provisioning URL (optional)'**
  String get authCustomServerEmailProvisioningUrlPlaceholder;

  /// No description provided for @authCustomServerEmailPublicTokenPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Email public token (optional)'**
  String get authCustomServerEmailPublicTokenPlaceholder;

  /// No description provided for @authCustomServerReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to axi.im'**
  String get authCustomServerReset;

  /// No description provided for @authCustomServerOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open custom server settings'**
  String get authCustomServerOpenSettings;

  /// No description provided for @authCustomServerAdvancedHint.
  ///
  /// In en, this message translates to:
  /// **'Advanced server options stay hidden until you tap the username suffix.'**
  String get authCustomServerAdvancedHint;

  /// No description provided for @authUnregisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Unregister'**
  String get authUnregisterTitle;

  /// No description provided for @authUnregisterConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get authUnregisterConfirmTitle;

  /// No description provided for @authUnregisterConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and local data. This cannot be undone.'**
  String get authUnregisterConfirmMessage;

  /// No description provided for @authUnregisterConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get authUnregisterConfirmAction;

  /// No description provided for @authUnregisterProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Waiting for account deletion'**
  String get authUnregisterProgressLabel;

  /// No description provided for @authPasswordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordPlaceholder;

  /// No description provided for @authPasswordCurrentPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Old password'**
  String get authPasswordCurrentPlaceholder;

  /// No description provided for @authPasswordNewPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authPasswordNewPlaceholder;

  /// No description provided for @authPasswordConfirmNewPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get authPasswordConfirmNewPlaceholder;

  /// No description provided for @authDeviceOnlyPasswordManagedChangeHint.
  ///
  /// In en, this message translates to:
  /// **'This account uses a device-managed password. Current password is not required on this device.'**
  String get authDeviceOnlyPasswordManagedChangeHint;

  /// No description provided for @authDeviceOnlyPasswordManagedDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'This account uses a device-managed password. Axichat will use it automatically to confirm deletion.'**
  String get authDeviceOnlyPasswordManagedDeleteHint;

  /// No description provided for @authChangePasswordProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Waiting for password change'**
  String get authChangePasswordProgressLabel;

  /// No description provided for @authLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get authLogoutTitle;

  /// No description provided for @authLogoutNormal.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get authLogoutNormal;

  /// No description provided for @authLogoutNormalDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this account.'**
  String get authLogoutNormalDescription;

  /// No description provided for @authLogoutBurn.
  ///
  /// In en, this message translates to:
  /// **'Burn account'**
  String get authLogoutBurn;

  /// No description provided for @authLogoutBurnDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign out and clear local data for this account.'**
  String get authLogoutBurnDescription;

  /// No description provided for @chatAttachmentBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Attachment blocked'**
  String get chatAttachmentBlockedTitle;

  /// No description provided for @chatEmailImageBlockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Image blocked'**
  String get chatEmailImageBlockedLabel;

  /// No description provided for @chatEmailImageFailedLabel.
  ///
  /// In en, this message translates to:
  /// **'Image failed'**
  String get chatEmailImageFailedLabel;

  /// No description provided for @chatAttachmentBlockedDescription.
  ///
  /// In en, this message translates to:
  /// **'Load attachments from unknown contacts only if you trust them. We will fetch it once you approve.'**
  String get chatAttachmentBlockedDescription;

  /// No description provided for @chatAttachmentLoad.
  ///
  /// In en, this message translates to:
  /// **'Load attachment'**
  String get chatAttachmentLoad;

  /// No description provided for @chatAttachmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Attachment unavailable'**
  String get chatAttachmentUnavailable;

  /// No description provided for @chatAttachmentSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to send attachment.'**
  String get chatAttachmentSendFailed;

  /// No description provided for @chatAttachmentRetryUpload.
  ///
  /// In en, this message translates to:
  /// **'Retry upload'**
  String get chatAttachmentRetryUpload;

  /// No description provided for @chatAttachmentRemoveAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get chatAttachmentRemoveAttachment;

  /// No description provided for @chatAttachmentStatusUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading attachment…'**
  String get chatAttachmentStatusUploading;

  /// No description provided for @chatAttachmentStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get chatAttachmentStatusQueued;

  /// No description provided for @chatAttachmentStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get chatAttachmentStatusFailed;

  /// No description provided for @chatAttachmentLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading attachment'**
  String get chatAttachmentLoading;

  /// No description provided for @chatAttachmentLoadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Loading {percent}'**
  String chatAttachmentLoadingProgress(Object percent);

  /// No description provided for @chatAttachmentDownload.
  ///
  /// In en, this message translates to:
  /// **'Download attachment'**
  String get chatAttachmentDownload;

  /// No description provided for @chatAttachmentDownloadAndOpen.
  ///
  /// In en, this message translates to:
  /// **'Download and open'**
  String get chatAttachmentDownloadAndOpen;

  /// No description provided for @chatAttachmentDownloadAndSave.
  ///
  /// In en, this message translates to:
  /// **'Download and save'**
  String get chatAttachmentDownloadAndSave;

  /// No description provided for @chatAttachmentDownloadAndShare.
  ///
  /// In en, this message translates to:
  /// **'Download and share'**
  String get chatAttachmentDownloadAndShare;

  /// No description provided for @chatAttachmentExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Save attachment?'**
  String get chatAttachmentExportTitle;

  /// No description provided for @chatAttachmentExportMessage.
  ///
  /// In en, this message translates to:
  /// **'This will copy the attachment to shared storage. Exports are unencrypted and may be readable by other apps. Continue?'**
  String get chatAttachmentExportMessage;

  /// No description provided for @chatAttachmentExportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get chatAttachmentExportConfirm;

  /// No description provided for @chatAttachmentExportCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatAttachmentExportCancel;

  /// No description provided for @chatMediaMetadataWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Media may include metadata'**
  String get chatMediaMetadataWarningTitle;

  /// No description provided for @chatMediaMetadataWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Photos and videos can include location and device details. Continue?'**
  String get chatMediaMetadataWarningMessage;

  /// No description provided for @chatNotificationPreviewOptionInherit.
  ///
  /// In en, this message translates to:
  /// **'Use app setting'**
  String get chatNotificationPreviewOptionInherit;

  /// No description provided for @chatNotificationPreviewOptionShow.
  ///
  /// In en, this message translates to:
  /// **'Always show previews'**
  String get chatNotificationPreviewOptionShow;

  /// No description provided for @chatNotificationPreviewOptionHide.
  ///
  /// In en, this message translates to:
  /// **'Always hide previews'**
  String get chatNotificationPreviewOptionHide;

  /// No description provided for @chatAttachmentUnavailableDevice.
  ///
  /// In en, this message translates to:
  /// **'Attachment is no longer available on this device'**
  String get chatAttachmentUnavailableDevice;

  /// No description provided for @chatAttachmentInvalidLink.
  ///
  /// In en, this message translates to:
  /// **'Invalid attachment link'**
  String get chatAttachmentInvalidLink;

  /// No description provided for @chatAttachmentOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open {target}'**
  String chatAttachmentOpenFailed(Object target);

  /// No description provided for @chatAttachmentTypeMismatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Attachment type mismatch'**
  String get chatAttachmentTypeMismatchTitle;

  /// No description provided for @chatAttachmentTypeMismatchMessage.
  ///
  /// In en, this message translates to:
  /// **'This attachment says it is {declared}, but the file looks like {detected}. Opening it could be unsafe. Continue?'**
  String chatAttachmentTypeMismatchMessage(Object declared, Object detected);

  /// No description provided for @chatAttachmentTypeMismatchConfirm.
  ///
  /// In en, this message translates to:
  /// **'Open anyway'**
  String get chatAttachmentTypeMismatchConfirm;

  /// No description provided for @chatAttachmentHighRiskTitle.
  ///
  /// In en, this message translates to:
  /// **'Potentially unsafe file'**
  String get chatAttachmentHighRiskTitle;

  /// No description provided for @chatAttachmentHighRiskMessage.
  ///
  /// In en, this message translates to:
  /// **'This file type can be dangerous to open. We recommend saving it and scanning it before opening. Continue?'**
  String get chatAttachmentHighRiskMessage;

  /// No description provided for @chatAttachmentUnknownSize.
  ///
  /// In en, this message translates to:
  /// **'Unknown size'**
  String get chatAttachmentUnknownSize;

  /// No description provided for @chatAttachmentNotDownloadedYet.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded yet'**
  String get chatAttachmentNotDownloadedYet;

  /// No description provided for @chatAttachmentErrorTooltip.
  ///
  /// In en, this message translates to:
  /// **'{message} ({fileName})'**
  String chatAttachmentErrorTooltip(Object message, Object fileName);

  /// No description provided for @chatAttachmentMenuHint.
  ///
  /// In en, this message translates to:
  /// **'Open menu for actions.'**
  String get chatAttachmentMenuHint;

  /// No description provided for @accessibilityActionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Accessibility actions'**
  String get accessibilityActionsLabel;

  /// No description provided for @accessibilityActionsShortcutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Accessibility actions ({shortcut})'**
  String accessibilityActionsShortcutTooltip(Object shortcut);

  /// No description provided for @shorebirdUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available: log out and restart the app'**
  String get shorebirdUpdateAvailable;

  /// No description provided for @calendarEditTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get calendarEditTaskTitle;

  /// No description provided for @calendarDateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get calendarDateTimeLabel;

  /// No description provided for @calendarSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get calendarSelectDate;

  /// No description provided for @calendarSelectTime.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get calendarSelectTime;

  /// No description provided for @calendarDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get calendarDurationLabel;

  /// No description provided for @calendarSelectDuration.
  ///
  /// In en, this message translates to:
  /// **'Select duration'**
  String get calendarSelectDuration;

  /// No description provided for @calendarAddToCriticalPath.
  ///
  /// In en, this message translates to:
  /// **'Add to critical path'**
  String get calendarAddToCriticalPath;

  /// No description provided for @calendarNoCriticalPathMembership.
  ///
  /// In en, this message translates to:
  /// **'Not in any critical paths'**
  String get calendarNoCriticalPathMembership;

  /// No description provided for @calendarGuestTitle.
  ///
  /// In en, this message translates to:
  /// **'Guest calendar'**
  String get calendarGuestTitle;

  /// No description provided for @calendarGuestBanner.
  ///
  /// In en, this message translates to:
  /// **'Guest Mode - No Sync'**
  String get calendarGuestBanner;

  /// No description provided for @calendarGuestModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Guest mode'**
  String get calendarGuestModeLabel;

  /// No description provided for @calendarGuestModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Log in to sync tasks across devices and enable reminders.'**
  String get calendarGuestModeDescription;

  /// No description provided for @calendarNoTasksForDate.
  ///
  /// In en, this message translates to:
  /// **'No tasks for this date'**
  String get calendarNoTasksForDate;

  /// No description provided for @calendarTapToCreateTask.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create a new task'**
  String get calendarTapToCreateTask;

  /// No description provided for @calendarQuickStats.
  ///
  /// In en, this message translates to:
  /// **'Quick stats'**
  String get calendarQuickStats;

  /// No description provided for @calendarDueReminders.
  ///
  /// In en, this message translates to:
  /// **'Due reminders'**
  String get calendarDueReminders;

  /// No description provided for @calendarNextTaskLabel.
  ///
  /// In en, this message translates to:
  /// **'Next task'**
  String get calendarNextTaskLabel;

  /// No description provided for @calendarNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get calendarNone;

  /// No description provided for @calendarViewLabel.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get calendarViewLabel;

  /// No description provided for @calendarViewDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get calendarViewDay;

  /// No description provided for @calendarViewWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calendarViewWeek;

  /// No description provided for @calendarViewMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calendarViewMonth;

  /// No description provided for @calendarPreviousDate.
  ///
  /// In en, this message translates to:
  /// **'Previous date'**
  String get calendarPreviousDate;

  /// No description provided for @calendarNextDate.
  ///
  /// In en, this message translates to:
  /// **'Next date'**
  String get calendarNextDate;

  /// No description provided for @calendarPreviousUnit.
  ///
  /// In en, this message translates to:
  /// **'Previous {unit}'**
  String calendarPreviousUnit(Object unit);

  /// No description provided for @calendarNextUnit.
  ///
  /// In en, this message translates to:
  /// **'Next {unit}'**
  String calendarNextUnit(Object unit);

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// No description provided for @calendarUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get calendarUndo;

  /// No description provided for @calendarRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get calendarRedo;

  /// No description provided for @calendarOpeningCreator.
  ///
  /// In en, this message translates to:
  /// **'Opening task creator...'**
  String get calendarOpeningCreator;

  /// No description provided for @calendarWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String calendarWeekOf(Object date);

  /// No description provided for @calendarStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get calendarStatusCompleted;

  /// No description provided for @calendarStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get calendarStatusOverdue;

  /// No description provided for @calendarStatusDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get calendarStatusDueSoon;

  /// No description provided for @calendarStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get calendarStatusPending;

  /// No description provided for @calendarTaskCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Task completed!'**
  String get calendarTaskCompletedMessage;

  /// No description provided for @calendarTaskUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Task updated!'**
  String get calendarTaskUpdatedMessage;

  /// No description provided for @calendarErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get calendarErrorTitle;

  /// No description provided for @calendarErrorTaskNotFound.
  ///
  /// In en, this message translates to:
  /// **'Task not found'**
  String get calendarErrorTaskNotFound;

  /// No description provided for @calendarErrorTitleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Title cannot be empty'**
  String get calendarErrorTitleEmpty;

  /// No description provided for @calendarErrorTitleTooLong.
  ///
  /// In en, this message translates to:
  /// **'Title too long'**
  String get calendarErrorTitleTooLong;

  /// No description provided for @calendarErrorDescriptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Description too long'**
  String get calendarErrorDescriptionTooLong;

  /// No description provided for @calendarErrorInputInvalid.
  ///
  /// In en, this message translates to:
  /// **'Input invalid'**
  String get calendarErrorInputInvalid;

  /// No description provided for @calendarErrorAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add task'**
  String get calendarErrorAddFailed;

  /// No description provided for @calendarErrorUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update task'**
  String get calendarErrorUpdateFailed;

  /// No description provided for @calendarErrorDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete task'**
  String get calendarErrorDeleteFailed;

  /// No description provided for @calendarErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get calendarErrorNetwork;

  /// No description provided for @calendarErrorStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage error'**
  String get calendarErrorStorage;

  /// No description provided for @calendarErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get calendarErrorUnknown;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// No description provided for @commonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get commonSelect;

  /// No description provided for @commonExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get commonExport;

  /// No description provided for @commonFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get commonFavorite;

  /// No description provided for @commonUnfavorite.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get commonUnfavorite;

  /// No description provided for @commonArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get commonArchive;

  /// No description provided for @commonUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get commonUnarchive;

  /// No description provided for @commonShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get commonShow;

  /// No description provided for @commonHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get commonHide;

  /// No description provided for @blocklistBlockUser.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get blocklistBlockUser;

  /// No description provided for @blocklistWaitingForUnblock.
  ///
  /// In en, this message translates to:
  /// **'Awaiting unblock'**
  String get blocklistWaitingForUnblock;

  /// No description provided for @blocklistUnblockAll.
  ///
  /// In en, this message translates to:
  /// **'Unblock all'**
  String get blocklistUnblockAll;

  /// No description provided for @blocklistUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get blocklistUnblock;

  /// No description provided for @blocklistBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get blocklistBlock;

  /// No description provided for @blocklistAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to blocklist'**
  String get blocklistAddTooltip;

  /// No description provided for @blocklistInvalidJid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid address.'**
  String get blocklistInvalidJid;

  /// No description provided for @blocklistBlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to block {address}. Try again later.'**
  String blocklistBlockFailed(Object address);

  /// No description provided for @blocklistUnblockFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to unblock {address}. Try again later.'**
  String blocklistUnblockFailed(Object address);

  /// No description provided for @blocklistBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked {address}.'**
  String blocklistBlocked(Object address);

  /// No description provided for @blocklistUnblocked.
  ///
  /// In en, this message translates to:
  /// **'Unblocked {address}.'**
  String blocklistUnblocked(Object address);

  /// No description provided for @blocklistBlockingUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Server does not support blocking.'**
  String get blocklistBlockingUnsupported;

  /// No description provided for @blocklistUnblockingUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Server does not support unblocking.'**
  String get blocklistUnblockingUnsupported;

  /// No description provided for @blocklistUnblockAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to unblock users. Try again later.'**
  String get blocklistUnblockAllFailed;

  /// No description provided for @blocklistUnblockAllSuccess.
  ///
  /// In en, this message translates to:
  /// **'Unblocked all.'**
  String get blocklistUnblockAllSuccess;

  /// No description provided for @mucChangeNickname.
  ///
  /// In en, this message translates to:
  /// **'Change nickname'**
  String get mucChangeNickname;

  /// No description provided for @mucChangeNicknameWithCurrent.
  ///
  /// In en, this message translates to:
  /// **'Change nickname (current: {current})'**
  String mucChangeNicknameWithCurrent(Object current);

  /// No description provided for @mucLeaveRoom.
  ///
  /// In en, this message translates to:
  /// **'Leave room'**
  String get mucLeaveRoom;

  /// No description provided for @mucNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No members yet'**
  String get mucNoMembers;

  /// No description provided for @mucInviteUsers.
  ///
  /// In en, this message translates to:
  /// **'Invite users'**
  String get mucInviteUsers;

  /// No description provided for @mucSendInvites.
  ///
  /// In en, this message translates to:
  /// **'Send invites'**
  String get mucSendInvites;

  /// No description provided for @mucChangeNicknameTitle.
  ///
  /// In en, this message translates to:
  /// **'Change nickname'**
  String get mucChangeNicknameTitle;

  /// No description provided for @mucEnterNicknamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter a nickname'**
  String get mucEnterNicknamePlaceholder;

  /// No description provided for @mucUpdateNickname.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get mucUpdateNickname;

  /// No description provided for @mucMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get mucMembersTitle;

  /// No description provided for @mucEditAvatar.
  ///
  /// In en, this message translates to:
  /// **'Edit room avatar'**
  String get mucEditAvatar;

  /// No description provided for @mucAvatarMenuDescription.
  ///
  /// In en, this message translates to:
  /// **'Room members will see this avatar.'**
  String get mucAvatarMenuDescription;

  /// No description provided for @mucInviteUser.
  ///
  /// In en, this message translates to:
  /// **'Invite user'**
  String get mucInviteUser;

  /// No description provided for @mucSectionOwners.
  ///
  /// In en, this message translates to:
  /// **'Owners'**
  String get mucSectionOwners;

  /// No description provided for @mucSectionAdmins.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get mucSectionAdmins;

  /// No description provided for @mucSectionModerators.
  ///
  /// In en, this message translates to:
  /// **'Moderators'**
  String get mucSectionModerators;

  /// No description provided for @mucSectionMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get mucSectionMembers;

  /// No description provided for @mucSectionVisitors.
  ///
  /// In en, this message translates to:
  /// **'Visitors'**
  String get mucSectionVisitors;

  /// No description provided for @mucRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get mucRoleOwner;

  /// No description provided for @mucRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get mucRoleAdmin;

  /// No description provided for @mucRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get mucRoleMember;

  /// No description provided for @mucRoleVisitor.
  ///
  /// In en, this message translates to:
  /// **'Visitor'**
  String get mucRoleVisitor;

  /// No description provided for @mucRoleModerator.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get mucRoleModerator;

  /// No description provided for @mucActionKick.
  ///
  /// In en, this message translates to:
  /// **'Kick'**
  String get mucActionKick;

  /// No description provided for @mucActionBan.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get mucActionBan;

  /// No description provided for @mucActionMakeMember.
  ///
  /// In en, this message translates to:
  /// **'Make member'**
  String get mucActionMakeMember;

  /// No description provided for @mucActionMakeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get mucActionMakeAdmin;

  /// No description provided for @mucActionMakeOwner.
  ///
  /// In en, this message translates to:
  /// **'Make owner'**
  String get mucActionMakeOwner;

  /// No description provided for @mucActionGrantModerator.
  ///
  /// In en, this message translates to:
  /// **'Grant moderator'**
  String get mucActionGrantModerator;

  /// No description provided for @mucActionRevokeModerator.
  ///
  /// In en, this message translates to:
  /// **'Revoke moderator'**
  String get mucActionRevokeModerator;

  /// No description provided for @chatsEmptyList.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get chatsEmptyList;

  /// No description provided for @chatsDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete chat: {chatTitle}'**
  String chatsDeleteConfirmMessage(Object chatTitle);

  /// No description provided for @chatsDeleteMessagesOption.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete messages'**
  String get chatsDeleteMessagesOption;

  /// No description provided for @chatsDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Chat deleted'**
  String get chatsDeleteSuccess;

  /// No description provided for @chatsExportNoContent.
  ///
  /// In en, this message translates to:
  /// **'No text content to export'**
  String get chatsExportNoContent;

  /// No description provided for @chatsExportShareText.
  ///
  /// In en, this message translates to:
  /// **'Chat export from Axichat'**
  String get chatsExportShareText;

  /// No description provided for @chatsExportShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Chat with {chatTitle}'**
  String chatsExportShareSubject(Object chatTitle);

  /// No description provided for @chatsExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Chat exported'**
  String get chatsExportSuccess;

  /// No description provided for @chatsExportFailure.
  ///
  /// In en, this message translates to:
  /// **'Unable to export chat'**
  String get chatsExportFailure;

  /// No description provided for @chatExportWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Export chat history?'**
  String get chatExportWarningTitle;

  /// No description provided for @chatExportWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Chat exports are unencrypted and may be readable by other apps or cloud services. Continue?'**
  String get chatExportWarningMessage;

  /// No description provided for @chatsArchivedRestored.
  ///
  /// In en, this message translates to:
  /// **'Chat restored'**
  String get chatsArchivedRestored;

  /// No description provided for @chatsArchivedHint.
  ///
  /// In en, this message translates to:
  /// **'Chat archived (Profile → Archived chats)'**
  String get chatsArchivedHint;

  /// No description provided for @chatsVisibleNotice.
  ///
  /// In en, this message translates to:
  /// **'Chat is visible again'**
  String get chatsVisibleNotice;

  /// No description provided for @chatsHiddenNotice.
  ///
  /// In en, this message translates to:
  /// **'Chat hidden (use filter to reveal)'**
  String get chatsHiddenNotice;

  /// No description provided for @chatsUnreadLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No unread messages} one {# unread message} other {# unread messages}}'**
  String chatsUnreadLabel(num count);

  /// No description provided for @chatsSemanticsUnselectHint.
  ///
  /// In en, this message translates to:
  /// **'Press to unselect chat'**
  String get chatsSemanticsUnselectHint;

  /// No description provided for @chatsSemanticsSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Press to select chat'**
  String get chatsSemanticsSelectHint;

  /// No description provided for @chatsSemanticsOpenHint.
  ///
  /// In en, this message translates to:
  /// **'Press to open chat'**
  String get chatsSemanticsOpenHint;

  /// No description provided for @chatsHideActions.
  ///
  /// In en, this message translates to:
  /// **'Hide chat actions'**
  String get chatsHideActions;

  /// No description provided for @chatsShowActions.
  ///
  /// In en, this message translates to:
  /// **'Show chat actions'**
  String get chatsShowActions;

  /// No description provided for @chatsSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Chat selected'**
  String get chatsSelectedLabel;

  /// No description provided for @chatsSelectLabel.
  ///
  /// In en, this message translates to:
  /// **'Select chat'**
  String get chatsSelectLabel;

  /// No description provided for @chatsExportFileLabel.
  ///
  /// In en, this message translates to:
  /// **'chats'**
  String get chatsExportFileLabel;

  /// No description provided for @chatSelectionExportEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No messages to export'**
  String get chatSelectionExportEmptyTitle;

  /// No description provided for @chatSelectionExportEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Select chats with text content'**
  String get chatSelectionExportEmptyMessage;

  /// No description provided for @chatSelectionExportShareText.
  ///
  /// In en, this message translates to:
  /// **'Chat exports from Axichat'**
  String get chatSelectionExportShareText;

  /// No description provided for @chatSelectionExportShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Axichat chats export'**
  String get chatSelectionExportShareSubject;

  /// No description provided for @chatSelectionExportReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Export ready'**
  String get chatSelectionExportReadyTitle;

  /// No description provided for @chatSelectionExportReadyMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Shared # chat} other {Shared # chats}}'**
  String chatSelectionExportReadyMessage(num count);

  /// No description provided for @chatSelectionExportFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get chatSelectionExportFailedTitle;

  /// No description provided for @chatSelectionExportFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to export selected chats'**
  String get chatSelectionExportFailedMessage;

  /// No description provided for @chatSelectionDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete chats?'**
  String get chatSelectionDeleteConfirmTitle;

  /// No description provided for @chatSelectionDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {This removes 1 chat and all of its messages. This cannot be undone.} other {This removes # chats and all of their messages. This cannot be undone.}}'**
  String chatSelectionDeleteConfirmMessage(num count);

  /// No description provided for @chatsCreateGroupChatTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create group chat'**
  String get chatsCreateGroupChatTooltip;

  /// No description provided for @chatsCreateGroupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Group chat created.'**
  String get chatsCreateGroupSuccess;

  /// No description provided for @chatsCreateGroupFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not create group chat.'**
  String get chatsCreateGroupFailure;

  /// No description provided for @chatsRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed.'**
  String get chatsRefreshFailed;

  /// No description provided for @chatsRoomLabel.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get chatsRoomLabel;

  /// No description provided for @chatsCreateChatRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Create chat room'**
  String get chatsCreateChatRoomTitle;

  /// No description provided for @chatsCreateChatRoomAction.
  ///
  /// In en, this message translates to:
  /// **'Create room'**
  String get chatsCreateChatRoomAction;

  /// No description provided for @chatsRoomNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get chatsRoomNamePlaceholder;

  /// No description provided for @chatsRoomNameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Room name cannot be empty.'**
  String get chatsRoomNameRequiredError;

  /// No description provided for @chatsRoomNameInvalidCharacterError.
  ///
  /// In en, this message translates to:
  /// **'Room names cannot contain {character}.'**
  String chatsRoomNameInvalidCharacterError(Object character);

  /// No description provided for @chatsArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get chatsArchiveTitle;

  /// No description provided for @chatsArchiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'No archived chats yet'**
  String get chatsArchiveEmpty;

  /// No description provided for @calendarTileNow.
  ///
  /// In en, this message translates to:
  /// **'Now: {title}'**
  String calendarTileNow(Object title);

  /// No description provided for @calendarTileNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {title}'**
  String calendarTileNext(Object title);

  /// No description provided for @calendarTileNone.
  ///
  /// In en, this message translates to:
  /// **'No upcoming tasks'**
  String get calendarTileNone;

  /// No description provided for @calendarViewDayShort.
  ///
  /// In en, this message translates to:
  /// **'D'**
  String get calendarViewDayShort;

  /// No description provided for @calendarViewWeekShort.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get calendarViewWeekShort;

  /// No description provided for @calendarViewMonthShort.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get calendarViewMonthShort;

  /// No description provided for @calendarShowCompleted.
  ///
  /// In en, this message translates to:
  /// **'Show completed'**
  String get calendarShowCompleted;

  /// No description provided for @calendarHideCompleted.
  ///
  /// In en, this message translates to:
  /// **'Hide completed'**
  String get calendarHideCompleted;

  /// No description provided for @rosterAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to roster'**
  String get rosterAddTooltip;

  /// No description provided for @rosterAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get rosterAddLabel;

  /// No description provided for @rosterAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get rosterAddTitle;

  /// No description provided for @rosterEmpty.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet'**
  String get rosterEmpty;

  /// No description provided for @rosterCompose.
  ///
  /// In en, this message translates to:
  /// **'Compose'**
  String get rosterCompose;

  /// No description provided for @rosterRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {jid} from contacts?'**
  String rosterRemoveConfirm(Object jid);

  /// No description provided for @rosterInvitesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No invites yet'**
  String get rosterInvitesEmpty;

  /// No description provided for @rosterRejectInviteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reject invite from {jid}?'**
  String rosterRejectInviteConfirm(Object jid);

  /// No description provided for @rosterAddContactTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get rosterAddContactTooltip;

  /// No description provided for @jidInputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'john@axi.im'**
  String get jidInputPlaceholder;

  /// No description provided for @jidInputInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid JID'**
  String get jidInputInvalid;

  /// No description provided for @sessionCapabilityChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get sessionCapabilityChat;

  /// No description provided for @sessionCapabilityEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get sessionCapabilityEmail;

  /// No description provided for @sessionCapabilityStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get sessionCapabilityStatusConnected;

  /// No description provided for @sessionCapabilityStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get sessionCapabilityStatusConnecting;

  /// No description provided for @sessionCapabilityStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get sessionCapabilityStatusError;

  /// No description provided for @sessionCapabilityStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get sessionCapabilityStatusOffline;

  /// No description provided for @sessionCapabilityStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get sessionCapabilityStatusOff;

  /// No description provided for @sessionCapabilityStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get sessionCapabilityStatusSyncing;

  /// No description provided for @emailSyncMessageSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing email...'**
  String get emailSyncMessageSyncing;

  /// No description provided for @emailSyncMessageConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to email servers...'**
  String get emailSyncMessageConnecting;

  /// No description provided for @emailSyncMessageDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected from email servers.'**
  String get emailSyncMessageDisconnected;

  /// No description provided for @emailSyncMessageGroupMembershipChanged.
  ///
  /// In en, this message translates to:
  /// **'Email group membership changed. Try reopening the chat.'**
  String get emailSyncMessageGroupMembershipChanged;

  /// No description provided for @emailSyncMessageHistorySyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing email history...'**
  String get emailSyncMessageHistorySyncing;

  /// No description provided for @emailSyncMessageRetrying.
  ///
  /// In en, this message translates to:
  /// **'Email sync will retry shortly...'**
  String get emailSyncMessageRetrying;

  /// No description provided for @emailSyncMessageRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing email sync after interruption…'**
  String get emailSyncMessageRefreshing;

  /// No description provided for @emailSyncMessageRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Email sync could not refresh. Try reopening the app.'**
  String get emailSyncMessageRefreshFailed;

  /// No description provided for @authChangePasswordPending.
  ///
  /// In en, this message translates to:
  /// **'Updating password...'**
  String get authChangePasswordPending;

  /// No description provided for @authEndpointAdvancedHint.
  ///
  /// In en, this message translates to:
  /// **'Advanced options'**
  String get authEndpointAdvancedHint;

  /// No description provided for @authEndpointApiPortPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'API port'**
  String get authEndpointApiPortPlaceholder;

  /// No description provided for @authEndpointDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure XMPP/SMTP endpoints for this account.'**
  String get authEndpointDescription;

  /// No description provided for @authEndpointDomainPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Domain'**
  String get authEndpointDomainPlaceholder;

  /// No description provided for @authEndpointPortPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get authEndpointPortPlaceholder;

  /// No description provided for @authEndpointRequireDnssecLabel.
  ///
  /// In en, this message translates to:
  /// **'Require DNSSEC'**
  String get authEndpointRequireDnssecLabel;

  /// No description provided for @authEndpointReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get authEndpointReset;

  /// No description provided for @authEndpointSmtpHostPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'SMTP host'**
  String get authEndpointSmtpHostPlaceholder;

  /// No description provided for @authEndpointSmtpLabel.
  ///
  /// In en, this message translates to:
  /// **'SMTP'**
  String get authEndpointSmtpLabel;

  /// No description provided for @authEndpointTitle.
  ///
  /// In en, this message translates to:
  /// **'Endpoint configuration'**
  String get authEndpointTitle;

  /// No description provided for @authEndpointUseDnsLabel.
  ///
  /// In en, this message translates to:
  /// **'Use DNS'**
  String get authEndpointUseDnsLabel;

  /// No description provided for @authEndpointUseSrvLabel.
  ///
  /// In en, this message translates to:
  /// **'Use SRV'**
  String get authEndpointUseSrvLabel;

  /// No description provided for @authEndpointXmppHostPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'XMPP host'**
  String get authEndpointXmppHostPlaceholder;

  /// No description provided for @authEndpointXmppLabel.
  ///
  /// In en, this message translates to:
  /// **'XMPP'**
  String get authEndpointXmppLabel;

  /// No description provided for @authUnregisterPending.
  ///
  /// In en, this message translates to:
  /// **'Unregistering...'**
  String get authUnregisterPending;

  /// No description provided for @calendarAddTaskError.
  ///
  /// In en, this message translates to:
  /// **'Could not add task: {details}'**
  String calendarAddTaskError(Object details);

  /// No description provided for @calendarBackToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Back to calendar'**
  String get calendarBackToCalendar;

  /// No description provided for @calendarLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Loading calendar...'**
  String get calendarLoadingMessage;

  /// No description provided for @calendarCriticalPathAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get calendarCriticalPathAddTask;

  /// No description provided for @calendarCriticalPathAddToTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to critical path'**
  String get calendarCriticalPathAddToTitle;

  /// No description provided for @calendarCriticalPathCreatePrompt.
  ///
  /// In en, this message translates to:
  /// **'Create a critical path to get started'**
  String get calendarCriticalPathCreatePrompt;

  /// No description provided for @calendarCriticalPathDragHint.
  ///
  /// In en, this message translates to:
  /// **'Drag tasks to reorder'**
  String get calendarCriticalPathDragHint;

  /// No description provided for @calendarCriticalPathEmptyTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks in this path yet'**
  String get calendarCriticalPathEmptyTasks;

  /// No description provided for @calendarCriticalPathNameEmptyError.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get calendarCriticalPathNameEmptyError;

  /// No description provided for @calendarCriticalPathNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Critical path name'**
  String get calendarCriticalPathNamePlaceholder;

  /// No description provided for @calendarCriticalPathNamePrompt.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get calendarCriticalPathNamePrompt;

  /// No description provided for @calendarCriticalPathTaskOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Order tasks'**
  String get calendarCriticalPathTaskOrderTitle;

  /// No description provided for @calendarCriticalPathsAll.
  ///
  /// In en, this message translates to:
  /// **'All paths'**
  String get calendarCriticalPathsAll;

  /// No description provided for @calendarCriticalPathsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No critical paths yet'**
  String get calendarCriticalPathsEmpty;

  /// No description provided for @calendarCriticalPathsNew.
  ///
  /// In en, this message translates to:
  /// **'New critical path'**
  String get calendarCriticalPathsNew;

  /// No description provided for @calendarCriticalPathRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename critical path'**
  String get calendarCriticalPathRenameTitle;

  /// No description provided for @calendarCriticalPathDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete critical path'**
  String get calendarCriticalPathDeleteTitle;

  /// No description provided for @calendarCriticalPathsTitle.
  ///
  /// In en, this message translates to:
  /// **'Critical paths'**
  String get calendarCriticalPathsTitle;

  /// No description provided for @calendarCriticalPathShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share to chat'**
  String get calendarCriticalPathShareAction;

  /// No description provided for @calendarCriticalPathShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share critical path'**
  String get calendarCriticalPathShareTitle;

  /// No description provided for @calendarCriticalPathShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send a critical path to a chat.'**
  String get calendarCriticalPathShareSubtitle;

  /// No description provided for @calendarCriticalPathShareTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Share with'**
  String get calendarCriticalPathShareTargetLabel;

  /// No description provided for @calendarCriticalPathShareButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get calendarCriticalPathShareButtonLabel;

  /// No description provided for @calendarCriticalPathShareMissingChats.
  ///
  /// In en, this message translates to:
  /// **'No eligible chats available.'**
  String get calendarCriticalPathShareMissingChats;

  /// No description provided for @calendarCriticalPathShareMissingRecipient.
  ///
  /// In en, this message translates to:
  /// **'Select a chat to share with.'**
  String get calendarCriticalPathShareMissingRecipient;

  /// No description provided for @calendarCriticalPathShareMissingService.
  ///
  /// In en, this message translates to:
  /// **'Calendar sharing is unavailable.'**
  String get calendarCriticalPathShareMissingService;

  /// No description provided for @calendarCriticalPathShareDenied.
  ///
  /// In en, this message translates to:
  /// **'Calendar cards are disabled for your role in this room.'**
  String get calendarCriticalPathShareDenied;

  /// No description provided for @calendarCriticalPathShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share critical path.'**
  String get calendarCriticalPathShareFailed;

  /// No description provided for @calendarCriticalPathShareSuccess.
  ///
  /// In en, this message translates to:
  /// **'Critical path shared.'**
  String get calendarCriticalPathShareSuccess;

  /// No description provided for @calendarCriticalPathShareChatTypeDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct chat'**
  String get calendarCriticalPathShareChatTypeDirect;

  /// No description provided for @calendarCriticalPathShareChatTypeGroup.
  ///
  /// In en, this message translates to:
  /// **'Group chat'**
  String get calendarCriticalPathShareChatTypeGroup;

  /// No description provided for @calendarCriticalPathShareChatTypeNote.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get calendarCriticalPathShareChatTypeNote;

  /// Summary of completed tasks in a critical path.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, one {{completed} of {total} task completed in order} other {{completed} of {total} tasks completed in order}}'**
  String calendarCriticalPathProgressSummary(int completed, int total);

  /// No description provided for @calendarCriticalPathProgressHint.
  ///
  /// In en, this message translates to:
  /// **'Complete tasks in the listed order to advance'**
  String get calendarCriticalPathProgressHint;

  /// No description provided for @calendarCriticalPathProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get calendarCriticalPathProgressLabel;

  /// Progress percentage label for critical path progress.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String calendarCriticalPathProgressPercent(int percent);

  /// No description provided for @calendarCriticalPathFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get calendarCriticalPathFocus;

  /// No description provided for @calendarCriticalPathUnfocus.
  ///
  /// In en, this message translates to:
  /// **'Unfocus'**
  String get calendarCriticalPathUnfocus;

  /// No description provided for @calendarCriticalPathCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get calendarCriticalPathCompletedLabel;

  /// Status message when queuing a critical path for a draft.
  ///
  /// In en, this message translates to:
  /// **'Will add to \"{name}\" on save'**
  String calendarCriticalPathQueuedAdd(Object name);

  /// Status message when creating a critical path and queuing it.
  ///
  /// In en, this message translates to:
  /// **'Created \"{name}\" and queued'**
  String calendarCriticalPathQueuedCreate(Object name);

  /// No description provided for @calendarCriticalPathUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Critical paths are unavailable in this view.'**
  String get calendarCriticalPathUnavailable;

  /// No description provided for @calendarCriticalPathAddAfterSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Task saved but could not be added to a critical path.'**
  String get calendarCriticalPathAddAfterSaveFailed;

  /// Success message after adding tasks to a critical path.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Added to \"{name}\".} other {Added {count} tasks to \"{name}\".}}'**
  String calendarCriticalPathAddSuccess(int count, Object name);

  /// Success message after creating a critical path and adding tasks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Created \"{name}\" and added task.} other {Created \"{name}\" and added tasks.}}'**
  String calendarCriticalPathCreateSuccess(int count, Object name);

  /// Error message when adding tasks to a critical path fails.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Unable to add task to a critical path.} other {Unable to add tasks to a critical path.}}'**
  String calendarCriticalPathAddFailed(int count);

  /// Error message shown when a task is already a member of the selected critical path.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Task already in this critical path.} other {Tasks already in this critical path.}}'**
  String calendarCriticalPathAlreadyContainsTasks(int count);

  /// No description provided for @calendarCriticalPathCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to create a critical path.'**
  String get calendarCriticalPathCreateFailed;

  /// No description provided for @calendarTaskSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search tasks'**
  String get calendarTaskSearchTitle;

  /// No description provided for @calendarTaskSearchAddToTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to {name}'**
  String calendarTaskSearchAddToTitle(Object name);

  /// No description provided for @calendarTaskSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search titles, descriptions, locations, categories, priorities, and deadlines.'**
  String get calendarTaskSearchSubtitle;

  /// No description provided for @calendarTaskSearchAddToSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap a task to append it to the critical path order.'**
  String get calendarTaskSearchAddToSubtitle;

  /// Search query hint. Keep filter tokens (title:, desc:, etc) in English.
  ///
  /// In en, this message translates to:
  /// **'title:, desc:, location:, category:work, priority:urgent, status:done'**
  String get calendarTaskSearchHint;

  /// No description provided for @calendarTaskSearchEmptyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search tasks'**
  String get calendarTaskSearchEmptyPrompt;

  /// No description provided for @calendarTaskSearchEmptyNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get calendarTaskSearchEmptyNoResults;

  /// Search tips. Keep filter tokens (title:, desc:, etc) in English.
  ///
  /// In en, this message translates to:
  /// **'Use filters like title:, desc:, location:, priority:critical, status:done, deadline:today.'**
  String get calendarTaskSearchEmptyHint;

  /// No description provided for @calendarTaskSearchFilterScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get calendarTaskSearchFilterScheduled;

  /// No description provided for @calendarTaskSearchFilterUnscheduled.
  ///
  /// In en, this message translates to:
  /// **'Unscheduled'**
  String get calendarTaskSearchFilterUnscheduled;

  /// No description provided for @calendarTaskSearchFilterReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get calendarTaskSearchFilterReminders;

  /// No description provided for @calendarTaskSearchFilterOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get calendarTaskSearchFilterOpen;

  /// No description provided for @calendarTaskSearchFilterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get calendarTaskSearchFilterCompleted;

  /// No description provided for @calendarTaskSearchDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String calendarTaskSearchDueDate(Object date);

  /// No description provided for @calendarTaskSearchOverdueDate.
  ///
  /// In en, this message translates to:
  /// **'Overdue · {date}'**
  String calendarTaskSearchOverdueDate(Object date);

  /// No description provided for @calendarDeleteTaskConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String calendarDeleteTaskConfirm(Object title);

  /// No description provided for @calendarErrorTitleEmptyFriendly.
  ///
  /// In en, this message translates to:
  /// **'Title cannot be empty'**
  String get calendarErrorTitleEmptyFriendly;

  /// No description provided for @calendarExportFormatIcsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compatible with other apps (recurrence & checklists excluded)'**
  String get calendarExportFormatIcsSubtitle;

  /// No description provided for @calendarExportFormatIcsTitle.
  ///
  /// In en, this message translates to:
  /// **'Export .ics'**
  String get calendarExportFormatIcsTitle;

  /// No description provided for @calendarExportFormatJsonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full backup with all task data (Recommended)'**
  String get calendarExportFormatJsonSubtitle;

  /// No description provided for @calendarExportFormatJsonTitle.
  ///
  /// In en, this message translates to:
  /// **'Export JSON'**
  String get calendarExportFormatJsonTitle;

  /// No description provided for @calendarRemovePathConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this task from \"{name}\"?'**
  String calendarRemovePathConfirm(Object name);

  /// No description provided for @calendarSandboxHint.
  ///
  /// In en, this message translates to:
  /// **'Plan tasks here before assigning them to a path.'**
  String get calendarSandboxHint;

  /// No description provided for @chatAlertHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get chatAlertHide;

  /// No description provided for @chatAlertIgnore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get chatAlertIgnore;

  /// No description provided for @chatAttachmentTapToLoad.
  ///
  /// In en, this message translates to:
  /// **'Tap to load'**
  String get chatAttachmentTapToLoad;

  /// No description provided for @chatMessageAddRecipientSuccess.
  ///
  /// In en, this message translates to:
  /// **'Added {recipient}'**
  String chatMessageAddRecipientSuccess(Object recipient);

  /// No description provided for @chatMessageAddRecipients.
  ///
  /// In en, this message translates to:
  /// **'Add recipients'**
  String get chatMessageAddRecipients;

  /// No description provided for @chatMessageCreateChat.
  ///
  /// In en, this message translates to:
  /// **'Create chat'**
  String get chatMessageCreateChat;

  /// No description provided for @chatMessageCreateChatFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not create chat: {reason}'**
  String chatMessageCreateChatFailure(Object reason);

  /// No description provided for @chatMessageInfoDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get chatMessageInfoDevice;

  /// No description provided for @chatMessageInfoError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get chatMessageInfoError;

  /// No description provided for @chatMessageInfoProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get chatMessageInfoProtocol;

  /// No description provided for @chatMessageInfoTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get chatMessageInfoTimestamp;

  /// No description provided for @chatMessageOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get chatMessageOpenChat;

  /// No description provided for @chatMessageStatusDisplayed.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get chatMessageStatusDisplayed;

  /// No description provided for @chatMessageStatusReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get chatMessageStatusReceived;

  /// No description provided for @chatMessageStatusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get chatMessageStatusSent;

  /// No description provided for @commonActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get commonActions;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get commonPrevious;

  /// No description provided for @emailDemoAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account: {account}'**
  String emailDemoAccountLabel(Object account);

  /// No description provided for @emailDemoDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello from Axichat'**
  String get emailDemoDefaultMessage;

  /// No description provided for @emailDemoDisplayNameSelf.
  ///
  /// In en, this message translates to:
  /// **'Self'**
  String get emailDemoDisplayNameSelf;

  /// No description provided for @emailDemoErrorMissingPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Missing database passphrase.'**
  String get emailDemoErrorMissingPassphrase;

  /// No description provided for @emailDemoErrorMissingPrefix.
  ///
  /// In en, this message translates to:
  /// **'Missing database prefix.'**
  String get emailDemoErrorMissingPrefix;

  /// No description provided for @emailDemoErrorMissingProfile.
  ///
  /// In en, this message translates to:
  /// **'No primary profile found. Log in first.'**
  String get emailDemoErrorMissingProfile;

  /// No description provided for @emailDemoMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Demo message'**
  String get emailDemoMessageLabel;

  /// No description provided for @emailDemoProvisionButton.
  ///
  /// In en, this message translates to:
  /// **'Provision Email'**
  String get emailDemoProvisionButton;

  /// No description provided for @emailDemoSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send Demo Message'**
  String get emailDemoSendButton;

  /// No description provided for @emailDemoStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get emailDemoStatusIdle;

  /// No description provided for @emailDemoStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String emailDemoStatusLabel(Object status);

  /// No description provided for @emailDemoStatusLoginToProvision.
  ///
  /// In en, this message translates to:
  /// **'Log in to provision email.'**
  String get emailDemoStatusLoginToProvision;

  /// No description provided for @emailDemoStatusNotProvisioned.
  ///
  /// In en, this message translates to:
  /// **'Not provisioned'**
  String get emailDemoStatusNotProvisioned;

  /// No description provided for @emailDemoStatusProvisionFailed.
  ///
  /// In en, this message translates to:
  /// **'Provisioning failed: {error}'**
  String emailDemoStatusProvisionFailed(Object error);

  /// No description provided for @emailDemoStatusProvisionFirst.
  ///
  /// In en, this message translates to:
  /// **'Provision an account first.'**
  String get emailDemoStatusProvisionFirst;

  /// No description provided for @emailDemoStatusProvisioned.
  ///
  /// In en, this message translates to:
  /// **'Provisioned {address}'**
  String emailDemoStatusProvisioned(Object address);

  /// No description provided for @emailDemoStatusProvisioning.
  ///
  /// In en, this message translates to:
  /// **'Provisioning email account…'**
  String get emailDemoStatusProvisioning;

  /// No description provided for @emailDemoStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get emailDemoStatusReady;

  /// No description provided for @emailDemoStatusSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed: {error}'**
  String emailDemoStatusSendFailed(Object error);

  /// No description provided for @emailDemoStatusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending demo message…'**
  String get emailDemoStatusSending;

  /// No description provided for @emailDemoStatusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent demo message (id={id})'**
  String emailDemoStatusSent(Object id);

  /// No description provided for @emailDemoTitle.
  ///
  /// In en, this message translates to:
  /// **'Email Transport Demo'**
  String get emailDemoTitle;

  /// No description provided for @verificationAddLabelPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add label'**
  String get verificationAddLabelPlaceholder;

  /// No description provided for @verificationCurrentDevice.
  ///
  /// In en, this message translates to:
  /// **'Current device'**
  String get verificationCurrentDevice;

  /// No description provided for @verificationDeviceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String verificationDeviceIdLabel(Object id);

  /// No description provided for @verificationNotTrusted.
  ///
  /// In en, this message translates to:
  /// **'Not trusted'**
  String get verificationNotTrusted;

  /// No description provided for @verificationRegenerateDevice.
  ///
  /// In en, this message translates to:
  /// **'Regenerate device'**
  String get verificationRegenerateDevice;

  /// No description provided for @verificationRegenerateWarning.
  ///
  /// In en, this message translates to:
  /// **'Only do this if you are an expert.'**
  String get verificationRegenerateWarning;

  /// No description provided for @verificationTrustBlind.
  ///
  /// In en, this message translates to:
  /// **'Blind trust'**
  String get verificationTrustBlind;

  /// No description provided for @verificationTrustNone.
  ///
  /// In en, this message translates to:
  /// **'No trust'**
  String get verificationTrustNone;

  /// No description provided for @verificationTrustVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verificationTrustVerified;

  /// No description provided for @verificationTrusted.
  ///
  /// In en, this message translates to:
  /// **'Trusted'**
  String get verificationTrusted;

  /// No description provided for @avatarSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Avatar saved.'**
  String get avatarSavedMessage;

  /// No description provided for @avatarOpenError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open that file.'**
  String get avatarOpenError;

  /// No description provided for @avatarReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read that file.'**
  String get avatarReadError;

  /// No description provided for @avatarInvalidImageError.
  ///
  /// In en, this message translates to:
  /// **'That file is not a valid image.'**
  String get avatarInvalidImageError;

  /// No description provided for @avatarProcessError.
  ///
  /// In en, this message translates to:
  /// **'Unable to process that image.'**
  String get avatarProcessError;

  /// No description provided for @avatarTemplateLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load that avatar option.'**
  String get avatarTemplateLoadError;

  /// No description provided for @avatarMissingDraftError.
  ///
  /// In en, this message translates to:
  /// **'Pick or build an avatar first.'**
  String get avatarMissingDraftError;

  /// No description provided for @avatarXmppDisconnectedError.
  ///
  /// In en, this message translates to:
  /// **'Connect to XMPP before saving your avatar.'**
  String get avatarXmppDisconnectedError;

  /// No description provided for @avatarPublishRejectedError.
  ///
  /// In en, this message translates to:
  /// **'Your server rejected avatar publishing.'**
  String get avatarPublishRejectedError;

  /// No description provided for @avatarPublishTimeoutError.
  ///
  /// In en, this message translates to:
  /// **'Avatar upload timed out. Please try again.'**
  String get avatarPublishTimeoutError;

  /// No description provided for @avatarPublishGenericError.
  ///
  /// In en, this message translates to:
  /// **'Could not publish avatar. Check your connection and try again.'**
  String get avatarPublishGenericError;

  /// No description provided for @avatarPublishUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error while uploading avatar.'**
  String get avatarPublishUnexpectedError;

  /// No description provided for @avatarCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Crop & focus'**
  String get avatarCropTitle;

  /// No description provided for @avatarCropDescription.
  ///
  /// In en, this message translates to:
  /// **'Drag or resize the square to set your crop. Reset to center and follow the circle to match the saved avatar.'**
  String get avatarCropDescription;

  /// No description provided for @avatarCropPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or pick a default avatar to adjust the framing.'**
  String get avatarCropPlaceholder;

  /// No description provided for @avatarCropSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'{pixels} px crop'**
  String avatarCropSizeLabel(Object pixels);

  /// No description provided for @avatarCropSavedSize.
  ///
  /// In en, this message translates to:
  /// **'Saved at 256×256 • < 64 KB'**
  String get avatarCropSavedSize;

  /// No description provided for @avatarBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get avatarBackgroundTitle;

  /// No description provided for @avatarBackgroundDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the wheel or presets to tint transparent avatars before saving.'**
  String get avatarBackgroundDescription;

  /// No description provided for @avatarBackgroundWheelTitle.
  ///
  /// In en, this message translates to:
  /// **'Wheel & hex'**
  String get avatarBackgroundWheelTitle;

  /// No description provided for @avatarBackgroundWheelDescription.
  ///
  /// In en, this message translates to:
  /// **'Drag the wheel or enter a hex value.'**
  String get avatarBackgroundWheelDescription;

  /// No description provided for @avatarBackgroundTransparent.
  ///
  /// In en, this message translates to:
  /// **'Transparent'**
  String get avatarBackgroundTransparent;

  /// No description provided for @avatarBackgroundPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview saved circle tint.'**
  String get avatarBackgroundPreview;

  /// No description provided for @avatarDefaultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Default avatars'**
  String get avatarDefaultsTitle;

  /// No description provided for @avatarCategoryAbstract.
  ///
  /// In en, this message translates to:
  /// **'Abstract'**
  String get avatarCategoryAbstract;

  /// No description provided for @avatarCategoryStem.
  ///
  /// In en, this message translates to:
  /// **'STEM'**
  String get avatarCategoryStem;

  /// No description provided for @avatarCategorySports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get avatarCategorySports;

  /// No description provided for @avatarCategoryMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get avatarCategoryMusic;

  /// No description provided for @avatarCategoryMisc.
  ///
  /// In en, this message translates to:
  /// **'Hobbies & Games'**
  String get avatarCategoryMisc;

  /// No description provided for @avatarTemplateAbstract.
  ///
  /// In en, this message translates to:
  /// **'Abstract {index}'**
  String avatarTemplateAbstract(Object index);

  /// No description provided for @avatarTemplateAtom.
  ///
  /// In en, this message translates to:
  /// **'Atom'**
  String get avatarTemplateAtom;

  /// No description provided for @avatarTemplateBeaker.
  ///
  /// In en, this message translates to:
  /// **'Beaker'**
  String get avatarTemplateBeaker;

  /// No description provided for @avatarTemplateCompass.
  ///
  /// In en, this message translates to:
  /// **'Compass'**
  String get avatarTemplateCompass;

  /// No description provided for @avatarTemplateCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get avatarTemplateCpu;

  /// No description provided for @avatarTemplateGear.
  ///
  /// In en, this message translates to:
  /// **'Gear'**
  String get avatarTemplateGear;

  /// No description provided for @avatarTemplateGlobe.
  ///
  /// In en, this message translates to:
  /// **'Globe'**
  String get avatarTemplateGlobe;

  /// No description provided for @avatarTemplateLaptop.
  ///
  /// In en, this message translates to:
  /// **'Laptop'**
  String get avatarTemplateLaptop;

  /// No description provided for @avatarTemplateMicroscope.
  ///
  /// In en, this message translates to:
  /// **'Microscope'**
  String get avatarTemplateMicroscope;

  /// No description provided for @avatarTemplateRobot.
  ///
  /// In en, this message translates to:
  /// **'Robot'**
  String get avatarTemplateRobot;

  /// No description provided for @avatarTemplateStethoscope.
  ///
  /// In en, this message translates to:
  /// **'Stethoscope'**
  String get avatarTemplateStethoscope;

  /// No description provided for @avatarTemplateTelescope.
  ///
  /// In en, this message translates to:
  /// **'Telescope'**
  String get avatarTemplateTelescope;

  /// No description provided for @avatarTemplateArchery.
  ///
  /// In en, this message translates to:
  /// **'Archery'**
  String get avatarTemplateArchery;

  /// No description provided for @avatarTemplateBaseball.
  ///
  /// In en, this message translates to:
  /// **'Baseball'**
  String get avatarTemplateBaseball;

  /// No description provided for @avatarTemplateBasketball.
  ///
  /// In en, this message translates to:
  /// **'Basketball'**
  String get avatarTemplateBasketball;

  /// No description provided for @avatarTemplateBoxing.
  ///
  /// In en, this message translates to:
  /// **'Boxing'**
  String get avatarTemplateBoxing;

  /// No description provided for @avatarTemplateCycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get avatarTemplateCycling;

  /// No description provided for @avatarTemplateDarts.
  ///
  /// In en, this message translates to:
  /// **'Darts'**
  String get avatarTemplateDarts;

  /// No description provided for @avatarTemplateFootball.
  ///
  /// In en, this message translates to:
  /// **'Football'**
  String get avatarTemplateFootball;

  /// No description provided for @avatarTemplateGolf.
  ///
  /// In en, this message translates to:
  /// **'Golf'**
  String get avatarTemplateGolf;

  /// No description provided for @avatarTemplatePingPong.
  ///
  /// In en, this message translates to:
  /// **'Ping Pong'**
  String get avatarTemplatePingPong;

  /// No description provided for @avatarTemplateSkiing.
  ///
  /// In en, this message translates to:
  /// **'Skiing'**
  String get avatarTemplateSkiing;

  /// No description provided for @avatarTemplateSoccer.
  ///
  /// In en, this message translates to:
  /// **'Soccer'**
  String get avatarTemplateSoccer;

  /// No description provided for @avatarTemplateTennis.
  ///
  /// In en, this message translates to:
  /// **'Tennis'**
  String get avatarTemplateTennis;

  /// No description provided for @avatarTemplateVolleyball.
  ///
  /// In en, this message translates to:
  /// **'Volleyball'**
  String get avatarTemplateVolleyball;

  /// No description provided for @avatarTemplateDrums.
  ///
  /// In en, this message translates to:
  /// **'Drums'**
  String get avatarTemplateDrums;

  /// No description provided for @avatarTemplateElectricGuitar.
  ///
  /// In en, this message translates to:
  /// **'Electric Guitar'**
  String get avatarTemplateElectricGuitar;

  /// No description provided for @avatarTemplateGuitar.
  ///
  /// In en, this message translates to:
  /// **'Guitar'**
  String get avatarTemplateGuitar;

  /// No description provided for @avatarTemplateMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get avatarTemplateMicrophone;

  /// No description provided for @avatarTemplatePiano.
  ///
  /// In en, this message translates to:
  /// **'Piano'**
  String get avatarTemplatePiano;

  /// No description provided for @avatarTemplateSaxophone.
  ///
  /// In en, this message translates to:
  /// **'Saxophone'**
  String get avatarTemplateSaxophone;

  /// No description provided for @avatarTemplateViolin.
  ///
  /// In en, this message translates to:
  /// **'Violin'**
  String get avatarTemplateViolin;

  /// No description provided for @avatarTemplateCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get avatarTemplateCards;

  /// No description provided for @avatarTemplateChess.
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get avatarTemplateChess;

  /// No description provided for @avatarTemplateChessAlt.
  ///
  /// In en, this message translates to:
  /// **'Chess Alt'**
  String get avatarTemplateChessAlt;

  /// No description provided for @avatarTemplateDice.
  ///
  /// In en, this message translates to:
  /// **'Dice'**
  String get avatarTemplateDice;

  /// No description provided for @avatarTemplateDiceAlt.
  ///
  /// In en, this message translates to:
  /// **'Dice Alt'**
  String get avatarTemplateDiceAlt;

  /// No description provided for @avatarTemplateEsports.
  ///
  /// In en, this message translates to:
  /// **'Esports'**
  String get avatarTemplateEsports;

  /// No description provided for @avatarTemplateSword.
  ///
  /// In en, this message translates to:
  /// **'Sword'**
  String get avatarTemplateSword;

  /// No description provided for @avatarTemplateVideoGames.
  ///
  /// In en, this message translates to:
  /// **'Video Games'**
  String get avatarTemplateVideoGames;

  /// No description provided for @avatarTemplateVideoGamesAlt.
  ///
  /// In en, this message translates to:
  /// **'Video Games Alt'**
  String get avatarTemplateVideoGamesAlt;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @calendarHour.
  ///
  /// In en, this message translates to:
  /// **'Hour'**
  String get calendarHour;

  /// No description provided for @calendarMinute.
  ///
  /// In en, this message translates to:
  /// **'Minute'**
  String get calendarMinute;

  /// No description provided for @calendarPasteTaskHere.
  ///
  /// In en, this message translates to:
  /// **'Paste Task Here'**
  String get calendarPasteTaskHere;

  /// No description provided for @calendarQuickAddTask.
  ///
  /// In en, this message translates to:
  /// **'Quick Add Task'**
  String get calendarQuickAddTask;

  /// No description provided for @calendarSplitTaskAt.
  ///
  /// In en, this message translates to:
  /// **'Split task at'**
  String get calendarSplitTaskAt;

  /// No description provided for @calendarAddDayEvent.
  ///
  /// In en, this message translates to:
  /// **'Add day event'**
  String get calendarAddDayEvent;

  /// No description provided for @calendarZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out (Ctrl/Cmd + -)'**
  String get calendarZoomOut;

  /// No description provided for @calendarZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in (Ctrl/Cmd + +)'**
  String get calendarZoomIn;

  /// No description provided for @calendarChecklistItem.
  ///
  /// In en, this message translates to:
  /// **'Checklist item'**
  String get calendarChecklistItem;

  /// No description provided for @calendarRemoveItem.
  ///
  /// In en, this message translates to:
  /// **'Remove item'**
  String get calendarRemoveItem;

  /// No description provided for @calendarAddChecklistItem.
  ///
  /// In en, this message translates to:
  /// **'Add checklist item'**
  String get calendarAddChecklistItem;

  /// No description provided for @calendarRepeatTimes.
  ///
  /// In en, this message translates to:
  /// **'Repeat times'**
  String get calendarRepeatTimes;

  /// No description provided for @calendarDayEventHint.
  ///
  /// In en, this message translates to:
  /// **'Birthday, holiday, or note'**
  String get calendarDayEventHint;

  /// No description provided for @calendarOptionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Optional details'**
  String get calendarOptionalDetails;

  /// No description provided for @calendarDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get calendarDates;

  /// No description provided for @calendarTaskTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Task title'**
  String get calendarTaskTitleHint;

  /// No description provided for @calendarDescriptionOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get calendarDescriptionOptionalHint;

  /// No description provided for @calendarLocationOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get calendarLocationOptionalHint;

  /// No description provided for @calendarCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get calendarCloseTooltip;

  /// No description provided for @calendarAddTaskInputHint.
  ///
  /// In en, this message translates to:
  /// **'Add task... (e.g., \"Meeting tomorrow at 3pm\")'**
  String get calendarAddTaskInputHint;

  /// No description provided for @calendarBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get calendarBranch;

  /// No description provided for @calendarPickDifferentTask.
  ///
  /// In en, this message translates to:
  /// **'Pick a different task for this slot'**
  String get calendarPickDifferentTask;

  /// No description provided for @calendarSyncRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get calendarSyncRequest;

  /// No description provided for @calendarSyncPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get calendarSyncPush;

  /// No description provided for @calendarImportant.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get calendarImportant;

  /// No description provided for @calendarUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get calendarUrgent;

  /// No description provided for @calendarClearSchedule.
  ///
  /// In en, this message translates to:
  /// **'Clear schedule'**
  String get calendarClearSchedule;

  /// No description provided for @calendarEditTaskTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get calendarEditTaskTooltip;

  /// No description provided for @calendarDeleteTaskTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get calendarDeleteTaskTooltip;

  /// No description provided for @calendarBackToChats.
  ///
  /// In en, this message translates to:
  /// **'Back to chats'**
  String get calendarBackToChats;

  /// No description provided for @calendarBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get calendarBackToLogin;

  /// No description provided for @calendarRemindersSection.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get calendarRemindersSection;

  /// No description provided for @settingsAutoLoadEmailImages.
  ///
  /// In en, this message translates to:
  /// **'Auto-load email images'**
  String get settingsAutoLoadEmailImages;

  /// No description provided for @settingsAutoLoadEmailImagesDescription.
  ///
  /// In en, this message translates to:
  /// **'May reveal your IP address to senders'**
  String get settingsAutoLoadEmailImagesDescription;

  /// No description provided for @settingsAutoDownloadImages.
  ///
  /// In en, this message translates to:
  /// **'Auto-download images'**
  String get settingsAutoDownloadImages;

  /// No description provided for @settingsAutoDownloadImagesDescription.
  ///
  /// In en, this message translates to:
  /// **'Applies when this chat allows automatic downloads.'**
  String get settingsAutoDownloadImagesDescription;

  /// No description provided for @settingsAutoDownloadVideos.
  ///
  /// In en, this message translates to:
  /// **'Auto-download videos'**
  String get settingsAutoDownloadVideos;

  /// No description provided for @settingsAutoDownloadVideosDescription.
  ///
  /// In en, this message translates to:
  /// **'Applies when this chat allows automatic downloads.'**
  String get settingsAutoDownloadVideosDescription;

  /// No description provided for @settingsAutoDownloadDocuments.
  ///
  /// In en, this message translates to:
  /// **'Auto-download documents'**
  String get settingsAutoDownloadDocuments;

  /// No description provided for @settingsAutoDownloadDocumentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Applies when this chat allows automatic downloads.'**
  String get settingsAutoDownloadDocumentsDescription;

  /// No description provided for @settingsAutoDownloadArchives.
  ///
  /// In en, this message translates to:
  /// **'Auto-download archives'**
  String get settingsAutoDownloadArchives;

  /// No description provided for @settingsAutoDownloadArchivesDescription.
  ///
  /// In en, this message translates to:
  /// **'Applies when this chat allows automatic downloads.'**
  String get settingsAutoDownloadArchivesDescription;

  /// No description provided for @settingsAutoDownloadScopeAlways.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get settingsAutoDownloadScopeAlways;

  /// No description provided for @settingsAutoDownloadScopeTrustedContacts.
  ///
  /// In en, this message translates to:
  /// **'Only for trusted contacts.'**
  String get settingsAutoDownloadScopeTrustedContacts;

  /// No description provided for @emailContactsImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import contacts'**
  String get emailContactsImportTitle;

  /// No description provided for @emailContactsImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Gmail, Outlook, Yahoo CSVs, or vCards.'**
  String get emailContactsImportSubtitle;

  /// No description provided for @emailContactsImportFileAccessError.
  ///
  /// In en, this message translates to:
  /// **'Unable to access the selected file.'**
  String get emailContactsImportFileAccessError;

  /// No description provided for @emailContactsImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get emailContactsImportAction;

  /// No description provided for @emailContactsImportFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get emailContactsImportFormatLabel;

  /// No description provided for @emailContactsImportFileLabel.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get emailContactsImportFileLabel;

  /// No description provided for @emailContactsImportNoFile.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get emailContactsImportNoFile;

  /// No description provided for @emailContactsImportChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get emailContactsImportChooseFile;

  /// No description provided for @emailContactsImportFormatGmail.
  ///
  /// In en, this message translates to:
  /// **'Gmail CSV'**
  String get emailContactsImportFormatGmail;

  /// No description provided for @emailContactsImportFormatOutlook.
  ///
  /// In en, this message translates to:
  /// **'Outlook CSV'**
  String get emailContactsImportFormatOutlook;

  /// No description provided for @emailContactsImportFormatYahoo.
  ///
  /// In en, this message translates to:
  /// **'Yahoo CSV'**
  String get emailContactsImportFormatYahoo;

  /// No description provided for @emailContactsImportFormatGenericCsv.
  ///
  /// In en, this message translates to:
  /// **'Generic CSV'**
  String get emailContactsImportFormatGenericCsv;

  /// No description provided for @emailContactsImportFormatVcard.
  ///
  /// In en, this message translates to:
  /// **'vCard (VCF)'**
  String get emailContactsImportFormatVcard;

  /// No description provided for @emailContactsImportNoValidContacts.
  ///
  /// In en, this message translates to:
  /// **'No valid contacts found.'**
  String get emailContactsImportNoValidContacts;

  /// No description provided for @emailContactsImportAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Set up email before importing contacts.'**
  String get emailContactsImportAccountRequired;

  /// No description provided for @emailContactsImportEmptyFile.
  ///
  /// In en, this message translates to:
  /// **'The selected file is empty.'**
  String get emailContactsImportEmptyFile;

  /// No description provided for @emailContactsImportReadFailure.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read that file.'**
  String get emailContactsImportReadFailure;

  /// No description provided for @emailContactsImportFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is too large to import.'**
  String get emailContactsImportFileTooLarge;

  /// No description provided for @emailContactsImportUnsupportedFile.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file type.'**
  String get emailContactsImportUnsupportedFile;

  /// No description provided for @emailContactsImportNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts found in that file.'**
  String get emailContactsImportNoContacts;

  /// No description provided for @emailContactsImportTooManyContacts.
  ///
  /// In en, this message translates to:
  /// **'This file contains too many contacts to import.'**
  String get emailContactsImportTooManyContacts;

  /// No description provided for @emailContactsImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed.'**
  String get emailContactsImportFailed;

  /// No description provided for @emailContactsImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported {imported} contacts. {duplicates} duplicates, {invalid} invalid, {failed} failed.'**
  String emailContactsImportSuccess(
    Object imported,
    Object duplicates,
    Object invalid,
    Object failed,
  );

  /// No description provided for @fanOutErrorNoRecipients.
  ///
  /// In en, this message translates to:
  /// **'Select at least one recipient.'**
  String get fanOutErrorNoRecipients;

  /// No description provided for @fanOutErrorResolveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t resolve recipients.'**
  String get fanOutErrorResolveFailed;

  /// No description provided for @fanOutErrorTooManyRecipients.
  ///
  /// In en, this message translates to:
  /// **'Too many recipients (max {max}).'**
  String fanOutErrorTooManyRecipients(int max);

  /// No description provided for @fanOutErrorEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a message or attachment before sending.'**
  String get fanOutErrorEmptyMessage;

  /// No description provided for @fanOutErrorInvalidShareToken.
  ///
  /// In en, this message translates to:
  /// **'Share token is invalid.'**
  String get fanOutErrorInvalidShareToken;

  /// No description provided for @emailForwardingGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect existing email'**
  String get emailForwardingGuideTitle;

  /// No description provided for @emailForwardingGuideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Forward mail from Gmail, Outlook, or any provider.'**
  String get emailForwardingGuideSubtitle;

  /// No description provided for @emailForwardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Axichat'**
  String get emailForwardingWelcomeTitle;

  /// No description provided for @emailForwardingGuideIntro.
  ///
  /// In en, this message translates to:
  /// **'Keep your existing inbox and forward mail into Axichat.'**
  String get emailForwardingGuideIntro;

  /// No description provided for @emailForwardingGuideLinkExistingEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Link existing email'**
  String get emailForwardingGuideLinkExistingEmailTitle;

  /// No description provided for @emailForwardingGuideAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Enter this address in your provider\'s forwarding settings.'**
  String get emailForwardingGuideAddressHint;

  /// No description provided for @emailForwardingGuideAddressFallback.
  ///
  /// In en, this message translates to:
  /// **'Your Axichat address will appear here.'**
  String get emailForwardingGuideAddressFallback;

  /// No description provided for @emailForwardingGuideLinksTitle.
  ///
  /// In en, this message translates to:
  /// **'This must be done in your existing email client. Your provider should have instructions. If you use Gmail or Outlook, here are their guides:'**
  String get emailForwardingGuideLinksTitle;

  /// No description provided for @emailForwardingGuideLinksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search your provider\'s help docs, or start here:'**
  String get emailForwardingGuideLinksSubtitle;

  /// No description provided for @emailForwardingWelcomeSetupFrom.
  ///
  /// In en, this message translates to:
  /// **'Setup forwarding from:'**
  String get emailForwardingWelcomeSetupFrom;

  /// No description provided for @emailForwardingWelcomeOtherProviderHint.
  ///
  /// In en, this message translates to:
  /// **'If you use another provider, their website should have instructions as well.'**
  String get emailForwardingWelcomeOtherProviderHint;

  /// No description provided for @emailForwardingGuideNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Message notifications'**
  String get emailForwardingGuideNotificationsTitle;

  /// No description provided for @emailForwardingGuideSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'You can do this later in settings.'**
  String get emailForwardingGuideSettingsHint;

  /// No description provided for @emailForwardingGuideSkipLabel.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get emailForwardingGuideSkipLabel;

  /// No description provided for @emailForwardingProviderGmail.
  ///
  /// In en, this message translates to:
  /// **'Gmail'**
  String get emailForwardingProviderGmail;

  /// No description provided for @emailForwardingProviderOutlook.
  ///
  /// In en, this message translates to:
  /// **'Outlook'**
  String get emailForwardingProviderOutlook;

  /// No description provided for @chatChooseTextToAdd.
  ///
  /// In en, this message translates to:
  /// **'Choose text to add'**
  String get chatChooseTextToAdd;

  /// No description provided for @notificationChannelMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get notificationChannelMessages;

  /// No description provided for @notificationNewMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get notificationNewMessageTitle;

  /// No description provided for @notificationOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open notification'**
  String get notificationOpenAction;

  /// No description provided for @notificationAttachmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get notificationAttachmentLabel;

  /// No description provided for @notificationAttachmentLabelWithName.
  ///
  /// In en, this message translates to:
  /// **'Attachment: {filename}'**
  String notificationAttachmentLabelWithName(String filename);

  /// No description provided for @notificationReactionFallback.
  ///
  /// In en, this message translates to:
  /// **'New reaction'**
  String get notificationReactionFallback;

  /// No description provided for @notificationReactionLabel.
  ///
  /// In en, this message translates to:
  /// **'Reaction: {reaction}'**
  String notificationReactionLabel(String reaction);

  /// No description provided for @notificationWebxdcFallback.
  ///
  /// In en, this message translates to:
  /// **'New update'**
  String get notificationWebxdcFallback;

  /// No description provided for @shareTokenFooterLabel.
  ///
  /// In en, this message translates to:
  /// **'Please do not remove:'**
  String get shareTokenFooterLabel;

  /// No description provided for @notificationBackgroundConnectionDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Background connection disabled'**
  String get notificationBackgroundConnectionDisabledTitle;

  /// No description provided for @notificationBackgroundConnectionDisabledBody.
  ///
  /// In en, this message translates to:
  /// **'Android blocked Axichat\'s message service. Re-enable overlay and battery optimization permissions to restore background messaging.'**
  String get notificationBackgroundConnectionDisabledBody;

  /// No description provided for @calendarReminderDeadlineNow.
  ///
  /// In en, this message translates to:
  /// **'Deadline now'**
  String get calendarReminderDeadlineNow;

  /// No description provided for @calendarReminderDueIn.
  ///
  /// In en, this message translates to:
  /// **'Due in {duration}'**
  String calendarReminderDueIn(Object duration);

  /// No description provided for @calendarReminderStartingNow.
  ///
  /// In en, this message translates to:
  /// **'Starting now'**
  String get calendarReminderStartingNow;

  /// No description provided for @calendarReminderStartsIn.
  ///
  /// In en, this message translates to:
  /// **'Starts in {duration}'**
  String calendarReminderStartsIn(Object duration);

  /// No description provided for @calendarReminderHappeningToday.
  ///
  /// In en, this message translates to:
  /// **'Happening today'**
  String get calendarReminderHappeningToday;

  /// No description provided for @calendarReminderIn.
  ///
  /// In en, this message translates to:
  /// **'In {duration}'**
  String calendarReminderIn(Object duration);

  /// No description provided for @calendarReminderDurationDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# day} other {# days}}'**
  String calendarReminderDurationDays(num count);

  /// No description provided for @calendarReminderDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# hour} other {# hours}}'**
  String calendarReminderDurationHours(num count);

  /// No description provided for @calendarReminderDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# minute} other {# minutes}}'**
  String calendarReminderDurationMinutes(num count);

  /// No description provided for @calendarExportCalendar.
  ///
  /// In en, this message translates to:
  /// **'Export calendar'**
  String get calendarExportCalendar;

  /// No description provided for @calendarImportCalendar.
  ///
  /// In en, this message translates to:
  /// **'Import calendar'**
  String get calendarImportCalendar;

  /// No description provided for @calendarSyncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get calendarSyncStatusSyncing;

  /// No description provided for @calendarSyncStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get calendarSyncStatusFailed;

  /// No description provided for @calendarSyncStatusSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get calendarSyncStatusSynced;

  /// No description provided for @calendarSyncStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get calendarSyncStatusIdle;

  /// No description provided for @calendarSplitTaskAtTime.
  ///
  /// In en, this message translates to:
  /// **'Split task at {time}'**
  String calendarSplitTaskAtTime(Object time);

  /// No description provided for @calendarSplitSelectTime.
  ///
  /// In en, this message translates to:
  /// **'Select split time'**
  String get calendarSplitSelectTime;

  /// No description provided for @calendarTaskMarkIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Mark incomplete'**
  String get calendarTaskMarkIncomplete;

  /// No description provided for @calendarTaskMarkComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark complete'**
  String get calendarTaskMarkComplete;

  /// No description provided for @calendarTaskRemoveImportant.
  ///
  /// In en, this message translates to:
  /// **'Remove important flag'**
  String get calendarTaskRemoveImportant;

  /// No description provided for @calendarTaskMarkImportant.
  ///
  /// In en, this message translates to:
  /// **'Mark as important'**
  String get calendarTaskMarkImportant;

  /// No description provided for @calendarTaskRemoveUrgent.
  ///
  /// In en, this message translates to:
  /// **'Remove urgent flag'**
  String get calendarTaskRemoveUrgent;

  /// No description provided for @calendarTaskMarkUrgent.
  ///
  /// In en, this message translates to:
  /// **'Mark as urgent'**
  String get calendarTaskMarkUrgent;

  /// No description provided for @calendarDeselectTask.
  ///
  /// In en, this message translates to:
  /// **'Deselect task'**
  String get calendarDeselectTask;

  /// No description provided for @calendarAddTaskToSelection.
  ///
  /// In en, this message translates to:
  /// **'Add task to selection'**
  String get calendarAddTaskToSelection;

  /// No description provided for @calendarSelectTask.
  ///
  /// In en, this message translates to:
  /// **'Select task'**
  String get calendarSelectTask;

  /// No description provided for @calendarDeselectAllRepeats.
  ///
  /// In en, this message translates to:
  /// **'Deselect all repeats'**
  String get calendarDeselectAllRepeats;

  /// No description provided for @calendarAddAllRepeats.
  ///
  /// In en, this message translates to:
  /// **'Add all repeats'**
  String get calendarAddAllRepeats;

  /// No description provided for @calendarSelectAllRepeats.
  ///
  /// In en, this message translates to:
  /// **'Select all repeats'**
  String get calendarSelectAllRepeats;

  /// No description provided for @calendarAddToSelection.
  ///
  /// In en, this message translates to:
  /// **'Add to selection'**
  String get calendarAddToSelection;

  /// No description provided for @calendarSelectAllTasks.
  ///
  /// In en, this message translates to:
  /// **'Select all tasks'**
  String get calendarSelectAllTasks;

  /// No description provided for @calendarExitSelectionMode.
  ///
  /// In en, this message translates to:
  /// **'Exit selection mode'**
  String get calendarExitSelectionMode;

  /// No description provided for @calendarSplitTask.
  ///
  /// In en, this message translates to:
  /// **'Split task'**
  String get calendarSplitTask;

  /// No description provided for @calendarCopyTemplate.
  ///
  /// In en, this message translates to:
  /// **'Copy template'**
  String get calendarCopyTemplate;

  /// No description provided for @calendarTaskAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'Task \"{title}\" added'**
  String calendarTaskAddedMessage(Object title);

  /// No description provided for @calendarTasksAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# task added} other {# tasks added}}'**
  String calendarTasksAddedMessage(num count);

  /// No description provided for @calendarTaskRemovedMessage.
  ///
  /// In en, this message translates to:
  /// **'Task \"{title}\" removed'**
  String calendarTaskRemovedMessage(Object title);

  /// No description provided for @calendarTasksRemovedMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# task removed} other {# tasks removed}}'**
  String calendarTasksRemovedMessage(num count);

  /// No description provided for @calendarTaskRemovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Task removed'**
  String get calendarTaskRemovedTitle;

  /// No description provided for @calendarDeadlinePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Set deadline (optional)'**
  String get calendarDeadlinePlaceholder;

  /// No description provided for @calendarTaskDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get calendarTaskDescriptionHint;

  /// No description provided for @calendarTaskLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get calendarTaskLocationHint;

  /// No description provided for @calendarPickDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Pick date'**
  String get calendarPickDateLabel;

  /// No description provided for @calendarPickTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Pick time'**
  String get calendarPickTimeLabel;

  /// No description provided for @calendarReminderLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get calendarReminderLabel;

  /// No description provided for @calendarEditDayEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit day event'**
  String get calendarEditDayEventTitle;

  /// No description provided for @calendarNewDayEventTitle.
  ///
  /// In en, this message translates to:
  /// **'New day event'**
  String get calendarNewDayEventTitle;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get commonTitle;

  /// No description provided for @calendarShareUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Calendar sharing is unavailable.'**
  String get calendarShareUnavailable;

  /// No description provided for @calendarShareAvailability.
  ///
  /// In en, this message translates to:
  /// **'Share availability'**
  String get calendarShareAvailability;

  /// No description provided for @calendarShortcutUndo.
  ///
  /// In en, this message translates to:
  /// **'Ctrl/Cmd+Z'**
  String get calendarShortcutUndo;

  /// No description provided for @calendarShortcutRedo.
  ///
  /// In en, this message translates to:
  /// **'Ctrl/Cmd+Shift+Z'**
  String get calendarShortcutRedo;

  /// No description provided for @commonShortcutTooltip.
  ///
  /// In en, this message translates to:
  /// **'{tooltip} ({shortcut})'**
  String commonShortcutTooltip(Object tooltip, Object shortcut);

  /// No description provided for @calendarDragCanceled.
  ///
  /// In en, this message translates to:
  /// **'Drag canceled'**
  String get calendarDragCanceled;

  /// No description provided for @calendarZoomLabelCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get calendarZoomLabelCompact;

  /// No description provided for @calendarZoomLabelComfort.
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get calendarZoomLabelComfort;

  /// No description provided for @calendarZoomLabelExpanded.
  ///
  /// In en, this message translates to:
  /// **'Expanded'**
  String get calendarZoomLabelExpanded;

  /// No description provided for @calendarZoomLabelMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String calendarZoomLabelMinutes(Object minutes);

  /// No description provided for @calendarGuestModeNotice.
  ///
  /// In en, this message translates to:
  /// **'Guest Mode - Tasks saved locally on this device only'**
  String get calendarGuestModeNotice;

  /// No description provided for @calendarGuestSignUpToSync.
  ///
  /// In en, this message translates to:
  /// **'Sign Up to Sync'**
  String get calendarGuestSignUpToSync;

  /// No description provided for @calendarGuestExportNoData.
  ///
  /// In en, this message translates to:
  /// **'No calendar data available to export.'**
  String get calendarGuestExportNoData;

  /// No description provided for @calendarGuestExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export guest calendar'**
  String get calendarGuestExportTitle;

  /// No description provided for @calendarGuestExportShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Axichat guest calendar export'**
  String get calendarGuestExportShareSubject;

  /// No description provided for @calendarGuestExportShareText.
  ///
  /// In en, this message translates to:
  /// **'Axichat guest calendar export ({format})'**
  String calendarGuestExportShareText(Object format);

  /// No description provided for @calendarGuestExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export calendar: {error}'**
  String calendarGuestExportFailed(Object error);

  /// No description provided for @calendarGuestImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import calendar'**
  String get calendarGuestImportTitle;

  /// No description provided for @calendarGuestImportWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Importing will merge data and override matching items in your current calendar. Continue?'**
  String get calendarGuestImportWarningMessage;

  /// No description provided for @calendarGuestImportConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get calendarGuestImportConfirmLabel;

  /// No description provided for @calendarGuestImportFileAccessError.
  ///
  /// In en, this message translates to:
  /// **'Unable to access the selected file.'**
  String get calendarGuestImportFileAccessError;

  /// No description provided for @calendarGuestImportNoData.
  ///
  /// In en, this message translates to:
  /// **'No calendar data detected in the selected file.'**
  String get calendarGuestImportNoData;

  /// No description provided for @calendarGuestImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed to apply changes.'**
  String get calendarGuestImportFailed;

  /// No description provided for @calendarGuestImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported calendar data.'**
  String get calendarGuestImportSuccess;

  /// No description provided for @calendarGuestImportNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks detected in the selected file.'**
  String get calendarGuestImportNoTasks;

  /// No description provided for @calendarGuestImportTasksSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported {count, plural, one {# task} other {# tasks}}.'**
  String calendarGuestImportTasksSuccess(num count);

  /// No description provided for @calendarGuestImportError.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String calendarGuestImportError(Object error);

  /// No description provided for @blocklistEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody blocked'**
  String get blocklistEmpty;

  /// No description provided for @chatMessageSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get chatMessageSubjectLabel;

  /// No description provided for @chatMessageRecipientsLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipients'**
  String get chatMessageRecipientsLabel;

  /// No description provided for @chatMessageAlsoSentToLabel.
  ///
  /// In en, this message translates to:
  /// **'Also sent to'**
  String get chatMessageAlsoSentToLabel;

  /// No description provided for @chatMessageFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From {sender}'**
  String chatMessageFromLabel(Object sender);

  /// No description provided for @chatMessageReactionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get chatMessageReactionsLabel;

  /// No description provided for @commonClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get commonClearSelection;

  /// No description provided for @commonSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# selected} other {# selected}}'**
  String commonSelectedCount(num count);

  /// No description provided for @profileDeviceFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Device Fingerprint'**
  String get profileDeviceFingerprint;

  /// No description provided for @profileFingerprintUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint unavailable'**
  String get profileFingerprintUnavailable;

  /// No description provided for @axiVersionCurrentFeatures.
  ///
  /// In en, this message translates to:
  /// **'Current features:'**
  String get axiVersionCurrentFeatures;

  /// No description provided for @axiVersionCurrentFeaturesList.
  ///
  /// In en, this message translates to:
  /// **'Messaging, presence'**
  String get axiVersionCurrentFeaturesList;

  /// No description provided for @axiVersionComingNext.
  ///
  /// In en, this message translates to:
  /// **'Coming next:'**
  String get axiVersionComingNext;

  /// No description provided for @axiVersionComingNextList.
  ///
  /// In en, this message translates to:
  /// **'Groupchat, multimedia'**
  String get axiVersionComingNextList;

  /// No description provided for @commonMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get commonMoreOptions;

  /// No description provided for @commonAreYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get commonAreYouSure;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageChineseSimplified.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChineseSimplified;

  /// No description provided for @languageChineseHongKong.
  ///
  /// In en, this message translates to:
  /// **'繁體中文 (香港)'**
  String get languageChineseHongKong;

  /// No description provided for @languageSystemShort.
  ///
  /// In en, this message translates to:
  /// **'SYS'**
  String get languageSystemShort;

  /// No description provided for @languageEnglishShort.
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get languageEnglishShort;

  /// No description provided for @languageGermanShort.
  ///
  /// In en, this message translates to:
  /// **'DE'**
  String get languageGermanShort;

  /// No description provided for @languageSpanishShort.
  ///
  /// In en, this message translates to:
  /// **'ES'**
  String get languageSpanishShort;

  /// No description provided for @languageFrenchShort.
  ///
  /// In en, this message translates to:
  /// **'FR'**
  String get languageFrenchShort;

  /// No description provided for @languageChineseSimplifiedShort.
  ///
  /// In en, this message translates to:
  /// **'ZH'**
  String get languageChineseSimplifiedShort;

  /// No description provided for @languageChineseHongKongShort.
  ///
  /// In en, this message translates to:
  /// **'ZH-HK'**
  String get languageChineseHongKongShort;

  /// No description provided for @languageSystemFlag.
  ///
  /// In en, this message translates to:
  /// **'🌐'**
  String get languageSystemFlag;

  /// No description provided for @languageEnglishFlag.
  ///
  /// In en, this message translates to:
  /// **'🇬🇧'**
  String get languageEnglishFlag;

  /// No description provided for @languageGermanFlag.
  ///
  /// In en, this message translates to:
  /// **'🇩🇪'**
  String get languageGermanFlag;

  /// No description provided for @languageSpanishFlag.
  ///
  /// In en, this message translates to:
  /// **'🇪🇸'**
  String get languageSpanishFlag;

  /// No description provided for @languageFrenchFlag.
  ///
  /// In en, this message translates to:
  /// **'🇫🇷'**
  String get languageFrenchFlag;

  /// No description provided for @languageChineseSimplifiedFlag.
  ///
  /// In en, this message translates to:
  /// **'🇨🇳'**
  String get languageChineseSimplifiedFlag;

  /// No description provided for @languageChineseHongKongFlag.
  ///
  /// In en, this message translates to:
  /// **'🇭🇰'**
  String get languageChineseHongKongFlag;

  /// No description provided for @calendarTransferNoDataExport.
  ///
  /// In en, this message translates to:
  /// **'No calendar data available to export.'**
  String get calendarTransferNoDataExport;

  /// No description provided for @calendarTransferExportSubject.
  ///
  /// In en, this message translates to:
  /// **'Axichat calendar export'**
  String get calendarTransferExportSubject;

  /// No description provided for @calendarTransferExportText.
  ///
  /// In en, this message translates to:
  /// **'Axichat calendar export ({format})'**
  String calendarTransferExportText(String format);

  /// No description provided for @calendarTransferExportReady.
  ///
  /// In en, this message translates to:
  /// **'Export ready to share.'**
  String get calendarTransferExportReady;

  /// No description provided for @calendarTransferExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export calendar: {error}'**
  String calendarTransferExportFailed(String error);

  /// No description provided for @calendarTransferImportWarning.
  ///
  /// In en, this message translates to:
  /// **'Importing will merge data and override matching items in your current calendar. Continue?'**
  String get calendarTransferImportWarning;

  /// No description provided for @calendarTransferImportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get calendarTransferImportConfirm;

  /// No description provided for @calendarTransferFileAccessFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to access the selected file.'**
  String get calendarTransferFileAccessFailed;

  /// No description provided for @calendarTransferNoDataImport.
  ///
  /// In en, this message translates to:
  /// **'No calendar data detected in the selected file.'**
  String get calendarTransferNoDataImport;

  /// No description provided for @calendarTransferImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed to apply changes.'**
  String get calendarTransferImportFailed;

  /// No description provided for @calendarTransferImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported calendar data.'**
  String get calendarTransferImportSuccess;

  /// No description provided for @calendarTransferNoTasksDetected.
  ///
  /// In en, this message translates to:
  /// **'No tasks detected in the selected file.'**
  String get calendarTransferNoTasksDetected;

  /// No description provided for @calendarTransferImportTasksSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} task{count, plural, one{} other{s}}.'**
  String calendarTransferImportTasksSuccess(int count);

  /// No description provided for @calendarTransferImportFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String calendarTransferImportFailedWithError(String error);

  /// No description provided for @calendarExportChooseFormat.
  ///
  /// In en, this message translates to:
  /// **'Choose export format'**
  String get calendarExportChooseFormat;

  /// No description provided for @calendarAvailabilityWindowsTitle.
  ///
  /// In en, this message translates to:
  /// **'Availability windows'**
  String get calendarAvailabilityWindowsTitle;

  /// No description provided for @calendarAvailabilityWindowsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Define the time ranges you want to share.'**
  String get calendarAvailabilityWindowsSubtitle;

  /// No description provided for @calendarAvailabilityWindowsLabel.
  ///
  /// In en, this message translates to:
  /// **'Windows'**
  String get calendarAvailabilityWindowsLabel;

  /// No description provided for @calendarAvailabilityNoWindows.
  ///
  /// In en, this message translates to:
  /// **'No windows yet.'**
  String get calendarAvailabilityNoWindows;

  /// No description provided for @calendarAvailabilityWindowLabel.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get calendarAvailabilityWindowLabel;

  /// No description provided for @calendarAvailabilitySummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get calendarAvailabilitySummaryLabel;

  /// No description provided for @calendarAvailabilitySummaryHint.
  ///
  /// In en, this message translates to:
  /// **'Optional label'**
  String get calendarAvailabilitySummaryHint;

  /// No description provided for @calendarAvailabilityNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get calendarAvailabilityNotesLabel;

  /// No description provided for @calendarAvailabilityNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional details'**
  String get calendarAvailabilityNotesHint;

  /// No description provided for @calendarAvailabilityAddWindow.
  ///
  /// In en, this message translates to:
  /// **'Add window'**
  String get calendarAvailabilityAddWindow;

  /// No description provided for @calendarAvailabilitySaveWindows.
  ///
  /// In en, this message translates to:
  /// **'Save windows'**
  String get calendarAvailabilitySaveWindows;

  /// No description provided for @calendarAvailabilityEmptyWindowsError.
  ///
  /// In en, this message translates to:
  /// **'Add at least one availability window.'**
  String get calendarAvailabilityEmptyWindowsError;

  /// No description provided for @calendarAvailabilityInvalidRangeError.
  ///
  /// In en, this message translates to:
  /// **'Check the window ranges before saving.'**
  String get calendarAvailabilityInvalidRangeError;

  /// No description provided for @calendarTaskShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share task'**
  String get calendarTaskShareTitle;

  /// No description provided for @calendarTaskShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send a task to a chat as .ics.'**
  String get calendarTaskShareSubtitle;

  /// No description provided for @calendarTaskShareTarget.
  ///
  /// In en, this message translates to:
  /// **'Share with'**
  String get calendarTaskShareTarget;

  /// No description provided for @calendarTaskShareEditAccess.
  ///
  /// In en, this message translates to:
  /// **'Edit access'**
  String get calendarTaskShareEditAccess;

  /// No description provided for @calendarTaskShareReadOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get calendarTaskShareReadOnlyLabel;

  /// No description provided for @calendarTaskShareEditableLabel.
  ///
  /// In en, this message translates to:
  /// **'Editable'**
  String get calendarTaskShareEditableLabel;

  /// No description provided for @calendarTaskShareReadOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Recipients can view this task, but only you can edit it.'**
  String get calendarTaskShareReadOnlyHint;

  /// No description provided for @calendarTaskShareEditableHint.
  ///
  /// In en, this message translates to:
  /// **'Recipients can edit this task, and updates sync back to your calendar.'**
  String get calendarTaskShareEditableHint;

  /// No description provided for @calendarTaskShareReadOnlyDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Editing is only available for chat calendars.'**
  String get calendarTaskShareReadOnlyDisabledHint;

  /// No description provided for @calendarTaskShareMissingChats.
  ///
  /// In en, this message translates to:
  /// **'No chats available.'**
  String get calendarTaskShareMissingChats;

  /// No description provided for @calendarTaskShareMissingRecipient.
  ///
  /// In en, this message translates to:
  /// **'Select a chat to share with.'**
  String get calendarTaskShareMissingRecipient;

  /// No description provided for @calendarTaskShareServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Calendar sharing is unavailable.'**
  String get calendarTaskShareServiceUnavailable;

  /// No description provided for @calendarTaskShareDenied.
  ///
  /// In en, this message translates to:
  /// **'Calendar cards are disabled for your role in this room.'**
  String get calendarTaskShareDenied;

  /// No description provided for @calendarTaskShareSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share task.'**
  String get calendarTaskShareSendFailed;

  /// No description provided for @calendarTaskShareSuccess.
  ///
  /// In en, this message translates to:
  /// **'Task shared.'**
  String get calendarTaskShareSuccess;

  /// No description provided for @commonTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get commonTimeJustNow;

  /// No description provided for @commonTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min{count, plural, one{} other{s}} ago'**
  String commonTimeMinutesAgo(int count);

  /// No description provided for @commonTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hour{count, plural, one{} other{s}} ago'**
  String commonTimeHoursAgo(int count);

  /// No description provided for @commonTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} day{count, plural, one{} other{s}} ago'**
  String commonTimeDaysAgo(int count);

  /// No description provided for @commonTimeWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} week{count, plural, one{} other{s}} ago'**
  String commonTimeWeeksAgo(int count);

  /// No description provided for @commonTimeMonthsAgo.
  ///
  /// In en, this message translates to:
  /// **'Months ago'**
  String get commonTimeMonthsAgo;

  /// No description provided for @connectivityStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectivityStatusConnected;

  /// No description provided for @connectivityStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connectivityStatusConnecting;

  /// No description provided for @connectivityStatusNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected.'**
  String get connectivityStatusNotConnected;

  /// No description provided for @connectivityStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect.'**
  String get connectivityStatusFailed;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonRecipients.
  ///
  /// In en, this message translates to:
  /// **'Recipients'**
  String get commonRecipients;

  /// No description provided for @commonRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'{start} - {end}'**
  String commonRangeLabel(String start, String end);

  /// No description provided for @commonOwnerFallback.
  ///
  /// In en, this message translates to:
  /// **'owner'**
  String get commonOwnerFallback;

  /// No description provided for @commonDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min{count, plural, one{} other{s}}'**
  String commonDurationMinutes(int count);

  /// No description provided for @commonDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{count} hour{count, plural, one{} other{s}}'**
  String commonDurationHours(int count);

  /// No description provided for @commonDurationMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String commonDurationMinutesShort(int count);

  /// No description provided for @commonDurationHoursShort.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String commonDurationHoursShort(int count);

  /// No description provided for @commonDateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'{date} · {time}'**
  String commonDateTimeLabel(String date, String time);

  /// No description provided for @calendarAvailabilityShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share availability'**
  String get calendarAvailabilityShareTitle;

  /// No description provided for @calendarAvailabilityShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a range, edit free/busy, then share.'**
  String get calendarAvailabilityShareSubtitle;

  /// No description provided for @calendarAvailabilityShareChatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a range, edit free/busy, then share in this chat.'**
  String get calendarAvailabilityShareChatSubtitle;

  /// No description provided for @calendarAvailabilityShareRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get calendarAvailabilityShareRangeLabel;

  /// No description provided for @calendarAvailabilityShareEditHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to split, drag to resize, or toggle free/busy.'**
  String get calendarAvailabilityShareEditHint;

  /// No description provided for @calendarAvailabilityShareSavePreset.
  ///
  /// In en, this message translates to:
  /// **'Save as preset'**
  String get calendarAvailabilityShareSavePreset;

  /// No description provided for @calendarAvailabilitySharePresetNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Save free/busy sheet'**
  String get calendarAvailabilitySharePresetNameTitle;

  /// No description provided for @calendarAvailabilitySharePresetNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get calendarAvailabilitySharePresetNameLabel;

  /// No description provided for @calendarAvailabilitySharePresetNameHint.
  ///
  /// In en, this message translates to:
  /// **'Team hours'**
  String get calendarAvailabilitySharePresetNameHint;

  /// No description provided for @calendarAvailabilitySharePresetNameMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter a name to save this sheet.'**
  String get calendarAvailabilitySharePresetNameMissing;

  /// No description provided for @calendarAvailabilityShareInvalidRange.
  ///
  /// In en, this message translates to:
  /// **'Select a valid range to share.'**
  String get calendarAvailabilityShareInvalidRange;

  /// No description provided for @calendarAvailabilityShareMissingJid.
  ///
  /// In en, this message translates to:
  /// **'Calendar sharing is unavailable.'**
  String get calendarAvailabilityShareMissingJid;

  /// No description provided for @calendarAvailabilityShareRecipientsRequired.
  ///
  /// In en, this message translates to:
  /// **'Select at least one recipient.'**
  String get calendarAvailabilityShareRecipientsRequired;

  /// No description provided for @calendarAvailabilityShareMissingChats.
  ///
  /// In en, this message translates to:
  /// **'No eligible chats available.'**
  String get calendarAvailabilityShareMissingChats;

  /// No description provided for @calendarAvailabilityShareLockedChatUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This chat cannot receive availability shares.'**
  String get calendarAvailabilityShareLockedChatUnavailable;

  /// No description provided for @calendarAvailabilityShareSuccess.
  ///
  /// In en, this message translates to:
  /// **'Availability shared.'**
  String get calendarAvailabilityShareSuccess;

  /// No description provided for @calendarAvailabilityShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share availability.'**
  String get calendarAvailabilityShareFailed;

  /// No description provided for @calendarAvailabilitySharePartialFailure.
  ///
  /// In en, this message translates to:
  /// **'Some shares failed to send.'**
  String get calendarAvailabilitySharePartialFailure;

  /// No description provided for @calendarAvailabilitySharePresetLabel.
  ///
  /// In en, this message translates to:
  /// **'Recent sheets'**
  String get calendarAvailabilitySharePresetLabel;

  /// No description provided for @calendarAvailabilitySharePresetEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recent sheets yet.'**
  String get calendarAvailabilitySharePresetEmpty;

  /// No description provided for @calendarAvailabilityShareRecentPreset.
  ///
  /// In en, this message translates to:
  /// **'Shared {range}'**
  String calendarAvailabilityShareRecentPreset(String range);

  /// No description provided for @calendarAvailabilityPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No availability intervals.'**
  String get calendarAvailabilityPreviewEmpty;

  /// No description provided for @calendarAvailabilityPreviewMore.
  ///
  /// In en, this message translates to:
  /// **'and {count} more'**
  String calendarAvailabilityPreviewMore(int count);

  /// No description provided for @calendarTaskTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a task title before continuing.'**
  String get calendarTaskTitleRequired;

  /// No description provided for @calendarTaskTitleTooLong.
  ///
  /// In en, this message translates to:
  /// **'Task title is too long. Please use fewer than {max} characters.'**
  String calendarTaskTitleTooLong(int max);

  /// No description provided for @calendarTaskTitleLimitWarning.
  ///
  /// In en, this message translates to:
  /// **'Task titles are limited to {max} characters. Shorten this text or move details into the description before saving.'**
  String calendarTaskTitleLimitWarning(int max);

  /// No description provided for @calendarTaskTitleCharacterCount.
  ///
  /// In en, this message translates to:
  /// **'{count} / {limit} characters'**
  String calendarTaskTitleCharacterCount(int count, int limit);

  /// No description provided for @axiVersionWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Axichat'**
  String get axiVersionWelcomeTitle;

  /// No description provided for @axiVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String axiVersionLabel(String version);

  /// No description provided for @axiVersionTagAlpha.
  ///
  /// In en, this message translates to:
  /// **'alpha'**
  String get axiVersionTagAlpha;

  /// No description provided for @calendarSyncWarningSnapshotTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar sync'**
  String get calendarSyncWarningSnapshotTitle;

  /// No description provided for @calendarSyncWarningSnapshotMessage.
  ///
  /// In en, this message translates to:
  /// **'Calendar snapshot unavailable. Export your calendar JSON from another device and import it here to restore.'**
  String get calendarSyncWarningSnapshotMessage;

  /// No description provided for @commonLabelValue.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String commonLabelValue(String label, String value);

  /// No description provided for @calendarAvailabilityRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Request time'**
  String get calendarAvailabilityRequestTitle;

  /// No description provided for @calendarAvailabilityRequestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a free slot and share details.'**
  String get calendarAvailabilityRequestSubtitle;

  /// No description provided for @calendarAvailabilityRequestDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get calendarAvailabilityRequestDetailsLabel;

  /// No description provided for @calendarAvailabilityRequestRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get calendarAvailabilityRequestRangeLabel;

  /// No description provided for @calendarAvailabilityRequestTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get calendarAvailabilityRequestTitleLabel;

  /// No description provided for @calendarAvailabilityRequestTitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'What is this for?'**
  String get calendarAvailabilityRequestTitlePlaceholder;

  /// No description provided for @calendarAvailabilityRequestDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get calendarAvailabilityRequestDescriptionLabel;

  /// No description provided for @calendarAvailabilityRequestDescriptionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add context (optional).'**
  String get calendarAvailabilityRequestDescriptionPlaceholder;

  /// No description provided for @calendarAvailabilityRequestSendLabel.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get calendarAvailabilityRequestSendLabel;

  /// No description provided for @calendarAvailabilityRequestInvalidRange.
  ///
  /// In en, this message translates to:
  /// **'Pick a valid time range.'**
  String get calendarAvailabilityRequestInvalidRange;

  /// No description provided for @calendarAvailabilityRequestNotFree.
  ///
  /// In en, this message translates to:
  /// **'Select a free slot before sending.'**
  String get calendarAvailabilityRequestNotFree;

  /// No description provided for @calendarAvailabilityDecisionTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept request'**
  String get calendarAvailabilityDecisionTitle;

  /// No description provided for @calendarAvailabilityDecisionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which calendars should receive it.'**
  String get calendarAvailabilityDecisionSubtitle;

  /// No description provided for @calendarAvailabilityDecisionPersonalLabel.
  ///
  /// In en, this message translates to:
  /// **'Add to personal calendar'**
  String get calendarAvailabilityDecisionPersonalLabel;

  /// No description provided for @calendarAvailabilityDecisionChatLabel.
  ///
  /// In en, this message translates to:
  /// **'Add to chat calendar'**
  String get calendarAvailabilityDecisionChatLabel;

  /// No description provided for @calendarAvailabilityDecisionMissingSelection.
  ///
  /// In en, this message translates to:
  /// **'Select at least one calendar.'**
  String get calendarAvailabilityDecisionMissingSelection;

  /// No description provided for @calendarAvailabilityDecisionSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get calendarAvailabilityDecisionSummaryLabel;

  /// No description provided for @calendarAvailabilityRequestTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Requested time'**
  String get calendarAvailabilityRequestTitleFallback;

  /// No description provided for @calendarAvailabilityShareFallback.
  ///
  /// In en, this message translates to:
  /// **'Shared availability'**
  String get calendarAvailabilityShareFallback;

  /// No description provided for @calendarAvailabilityRequestFallback.
  ///
  /// In en, this message translates to:
  /// **'Availability request'**
  String get calendarAvailabilityRequestFallback;

  /// No description provided for @calendarAvailabilityResponseAcceptedFallback.
  ///
  /// In en, this message translates to:
  /// **'Availability accepted'**
  String get calendarAvailabilityResponseAcceptedFallback;

  /// No description provided for @calendarAvailabilityResponseDeclinedFallback.
  ///
  /// In en, this message translates to:
  /// **'Availability declined'**
  String get calendarAvailabilityResponseDeclinedFallback;

  /// No description provided for @calendarFreeBusyFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get calendarFreeBusyFree;

  /// No description provided for @calendarFreeBusyBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get calendarFreeBusyBusy;

  /// No description provided for @calendarFreeBusyTentative.
  ///
  /// In en, this message translates to:
  /// **'Tentative'**
  String get calendarFreeBusyTentative;

  /// No description provided for @calendarFreeBusyEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit availability'**
  String get calendarFreeBusyEditTitle;

  /// No description provided for @calendarFreeBusyEditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust the time range and status.'**
  String get calendarFreeBusyEditSubtitle;

  /// No description provided for @calendarFreeBusyToggleLabel.
  ///
  /// In en, this message translates to:
  /// **'Free/Busy'**
  String get calendarFreeBusyToggleLabel;

  /// No description provided for @calendarFreeBusySplitLabel.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get calendarFreeBusySplitLabel;

  /// No description provided for @calendarFreeBusySplitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Split segment'**
  String get calendarFreeBusySplitTooltip;

  /// No description provided for @calendarFreeBusyMarkFree.
  ///
  /// In en, this message translates to:
  /// **'Mark free'**
  String get calendarFreeBusyMarkFree;

  /// No description provided for @calendarFreeBusyMarkBusy.
  ///
  /// In en, this message translates to:
  /// **'Mark busy'**
  String get calendarFreeBusyMarkBusy;

  /// No description provided for @calendarFreeBusyRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get calendarFreeBusyRangeLabel;

  /// No description provided for @commonWeekdayDayLabel.
  ///
  /// In en, this message translates to:
  /// **'{weekday} {day}'**
  String commonWeekdayDayLabel(String weekday, int day);

  /// No description provided for @calendarFragmentChecklistLabel.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get calendarFragmentChecklistLabel;

  /// No description provided for @calendarFragmentChecklistSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get calendarFragmentChecklistSeparator;

  /// No description provided for @calendarFragmentChecklistSummary.
  ///
  /// In en, this message translates to:
  /// **'Checklist: {summary}'**
  String calendarFragmentChecklistSummary(String summary);

  /// No description provided for @calendarFragmentChecklistSummaryMore.
  ///
  /// In en, this message translates to:
  /// **'Checklist: {summary} and {count} more'**
  String calendarFragmentChecklistSummaryMore(String summary, int count);

  /// No description provided for @calendarFragmentRemindersLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get calendarFragmentRemindersLabel;

  /// No description provided for @calendarFragmentReminderStartSummary.
  ///
  /// In en, this message translates to:
  /// **'Start: {summary}'**
  String calendarFragmentReminderStartSummary(String summary);

  /// No description provided for @calendarFragmentReminderDeadlineSummary.
  ///
  /// In en, this message translates to:
  /// **'Deadline: {summary}'**
  String calendarFragmentReminderDeadlineSummary(String summary);

  /// No description provided for @calendarFragmentRemindersSummary.
  ///
  /// In en, this message translates to:
  /// **'Reminders: {summary}'**
  String calendarFragmentRemindersSummary(String summary);

  /// No description provided for @calendarFragmentReminderSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get calendarFragmentReminderSeparator;

  /// No description provided for @calendarFragmentEventTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Untitled event'**
  String get calendarFragmentEventTitleFallback;

  /// No description provided for @calendarFragmentDayEventSummary.
  ///
  /// In en, this message translates to:
  /// **'{title} (Day event: {range})'**
  String calendarFragmentDayEventSummary(String title, String range);

  /// No description provided for @calendarFragmentFreeBusySummary.
  ///
  /// In en, this message translates to:
  /// **'{label} (Window: {range})'**
  String calendarFragmentFreeBusySummary(String label, String range);

  /// No description provided for @calendarFragmentCriticalPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Critical path'**
  String get calendarFragmentCriticalPathLabel;

  /// No description provided for @calendarFragmentCriticalPathSummary.
  ///
  /// In en, this message translates to:
  /// **'Critical path: {name}'**
  String calendarFragmentCriticalPathSummary(String name);

  /// No description provided for @calendarFragmentCriticalPathProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} done'**
  String calendarFragmentCriticalPathProgress(int completed, int total);

  /// No description provided for @calendarFragmentCriticalPathDetail.
  ///
  /// In en, this message translates to:
  /// **'{name} (Critical path: {progress})'**
  String calendarFragmentCriticalPathDetail(String name, String progress);

  /// No description provided for @calendarFragmentAvailabilitySummary.
  ///
  /// In en, this message translates to:
  /// **'{summary} (Availability: {range})'**
  String calendarFragmentAvailabilitySummary(String summary, String range);

  /// No description provided for @calendarFragmentAvailabilityFallback.
  ///
  /// In en, this message translates to:
  /// **'Availability: {range}'**
  String calendarFragmentAvailabilityFallback(String range);

  /// No description provided for @calendarMonthOverflowMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String calendarMonthOverflowMore(int count);

  /// No description provided for @commonPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String commonPercentLabel(int value);

  /// No description provided for @commonStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get commonStart;

  /// No description provided for @commonEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get commonEnd;

  /// No description provided for @commonSelectStart.
  ///
  /// In en, this message translates to:
  /// **'Select start'**
  String get commonSelectStart;

  /// No description provided for @commonSelectEnd.
  ///
  /// In en, this message translates to:
  /// **'Select end'**
  String get commonSelectEnd;

  /// No description provided for @commonTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get commonTimeLabel;

  /// No description provided for @commonListSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get commonListSeparator;

  /// No description provided for @commonClauseSeparator.
  ///
  /// In en, this message translates to:
  /// **'; '**
  String get commonClauseSeparator;

  /// No description provided for @commonSentenceSeparator.
  ///
  /// In en, this message translates to:
  /// **'. '**
  String get commonSentenceSeparator;

  /// No description provided for @commonSentenceTerminator.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get commonSentenceTerminator;

  /// No description provided for @commonListAnd.
  ///
  /// In en, this message translates to:
  /// **'{head} and {tail}'**
  String commonListAnd(String head, String tail);

  /// No description provided for @calendarAlarmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alarms'**
  String get calendarAlarmsTitle;

  /// No description provided for @calendarAlarmsHelper.
  ///
  /// In en, this message translates to:
  /// **'Reminders are exported as display alarms.'**
  String get calendarAlarmsHelper;

  /// No description provided for @calendarAlarmsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No alarms yet'**
  String get calendarAlarmsEmpty;

  /// No description provided for @calendarAlarmAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add alarm'**
  String get calendarAlarmAddTooltip;

  /// No description provided for @calendarAlarmRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove alarm'**
  String get calendarAlarmRemoveTooltip;

  /// No description provided for @calendarAlarmItemLabel.
  ///
  /// In en, this message translates to:
  /// **'Alarm {index}'**
  String calendarAlarmItemLabel(int index);

  /// No description provided for @calendarAlarmActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get calendarAlarmActionLabel;

  /// No description provided for @calendarAlarmActionDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get calendarAlarmActionDisplay;

  /// No description provided for @calendarAlarmActionAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get calendarAlarmActionAudio;

  /// No description provided for @calendarAlarmActionEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get calendarAlarmActionEmail;

  /// No description provided for @calendarAlarmActionProcedure.
  ///
  /// In en, this message translates to:
  /// **'Procedure'**
  String get calendarAlarmActionProcedure;

  /// No description provided for @calendarAlarmActionProcedureHelper.
  ///
  /// In en, this message translates to:
  /// **'Procedure alarms are imported read-only.'**
  String get calendarAlarmActionProcedureHelper;

  /// No description provided for @calendarAlarmTriggerLabel.
  ///
  /// In en, this message translates to:
  /// **'Trigger'**
  String get calendarAlarmTriggerLabel;

  /// No description provided for @calendarAlarmTriggerRelative.
  ///
  /// In en, this message translates to:
  /// **'Relative'**
  String get calendarAlarmTriggerRelative;

  /// No description provided for @calendarAlarmTriggerAbsolute.
  ///
  /// In en, this message translates to:
  /// **'Absolute'**
  String get calendarAlarmTriggerAbsolute;

  /// No description provided for @calendarAlarmAbsolutePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Pick date and time'**
  String get calendarAlarmAbsolutePlaceholder;

  /// No description provided for @calendarAlarmRelativeToLabel.
  ///
  /// In en, this message translates to:
  /// **'Relative to'**
  String get calendarAlarmRelativeToLabel;

  /// No description provided for @calendarAlarmRelativeToStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get calendarAlarmRelativeToStart;

  /// No description provided for @calendarAlarmRelativeToEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get calendarAlarmRelativeToEnd;

  /// No description provided for @calendarAlarmDirectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get calendarAlarmDirectionLabel;

  /// No description provided for @calendarAlarmDirectionBefore.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get calendarAlarmDirectionBefore;

  /// No description provided for @calendarAlarmDirectionAfter.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get calendarAlarmDirectionAfter;

  /// No description provided for @calendarAlarmOffsetLabel.
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get calendarAlarmOffsetLabel;

  /// No description provided for @calendarAlarmOffsetHint.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get calendarAlarmOffsetHint;

  /// No description provided for @calendarAlarmRepeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get calendarAlarmRepeatLabel;

  /// No description provided for @calendarAlarmRepeatCountHint.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get calendarAlarmRepeatCountHint;

  /// No description provided for @calendarAlarmRepeatEveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get calendarAlarmRepeatEveryLabel;

  /// No description provided for @calendarAlarmRecipientsLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipients'**
  String get calendarAlarmRecipientsLabel;

  /// No description provided for @calendarAlarmRecipientAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Add email'**
  String get calendarAlarmRecipientAddressHint;

  /// No description provided for @calendarAlarmRecipientNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get calendarAlarmRecipientNameHint;

  /// No description provided for @calendarAlarmRecipientRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove recipient'**
  String get calendarAlarmRecipientRemoveTooltip;

  /// No description provided for @calendarAlarmRecipientDisplay.
  ///
  /// In en, this message translates to:
  /// **'{name} <{address}>'**
  String calendarAlarmRecipientDisplay(String name, String address);

  /// No description provided for @calendarAlarmAcknowledgedLabel.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get calendarAlarmAcknowledgedLabel;

  /// No description provided for @calendarAlarmUnitMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get calendarAlarmUnitMinutes;

  /// No description provided for @calendarAlarmUnitHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get calendarAlarmUnitHours;

  /// No description provided for @calendarAlarmUnitDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get calendarAlarmUnitDays;

  /// No description provided for @calendarAlarmUnitWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get calendarAlarmUnitWeeks;

  /// No description provided for @taskShareTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Untitled task'**
  String get taskShareTitleFallback;

  /// No description provided for @taskShareTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Task \"{title}\"'**
  String taskShareTitleLabel(String title);

  /// No description provided for @taskShareTitleWithQualifiers.
  ///
  /// In en, this message translates to:
  /// **'Task \"{title}\" ({qualifiers})'**
  String taskShareTitleWithQualifiers(String title, String qualifiers);

  /// No description provided for @taskShareQualifierDone.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get taskShareQualifierDone;

  /// No description provided for @taskSharePriorityImportant.
  ///
  /// In en, this message translates to:
  /// **'important'**
  String get taskSharePriorityImportant;

  /// No description provided for @taskSharePriorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'urgent'**
  String get taskSharePriorityUrgent;

  /// No description provided for @taskSharePriorityCritical.
  ///
  /// In en, this message translates to:
  /// **'critical'**
  String get taskSharePriorityCritical;

  /// No description provided for @taskShareLocationClause.
  ///
  /// In en, this message translates to:
  /// **' at {location}'**
  String taskShareLocationClause(String location);

  /// No description provided for @taskShareScheduleNoTime.
  ///
  /// In en, this message translates to:
  /// **' with no set time'**
  String get taskShareScheduleNoTime;

  /// No description provided for @taskShareScheduleSameDay.
  ///
  /// In en, this message translates to:
  /// **' on {date} from {startTime} to {endTime}'**
  String taskShareScheduleSameDay(
    String date,
    String startTime,
    String endTime,
  );

  /// No description provided for @taskShareScheduleRange.
  ///
  /// In en, this message translates to:
  /// **' from {startDateTime} to {endDateTime}'**
  String taskShareScheduleRange(String startDateTime, String endDateTime);

  /// No description provided for @taskShareScheduleStartDuration.
  ///
  /// In en, this message translates to:
  /// **' on {date} at {time} for {duration}'**
  String taskShareScheduleStartDuration(
    String date,
    String time,
    String duration,
  );

  /// No description provided for @taskShareScheduleStart.
  ///
  /// In en, this message translates to:
  /// **' on {date} at {time}'**
  String taskShareScheduleStart(String date, String time);

  /// No description provided for @taskShareScheduleEnding.
  ///
  /// In en, this message translates to:
  /// **' ending {dateTime}'**
  String taskShareScheduleEnding(String dateTime);

  /// No description provided for @taskShareRecurrenceEveryOtherDay.
  ///
  /// In en, this message translates to:
  /// **' every other day'**
  String get taskShareRecurrenceEveryOtherDay;

  /// No description provided for @taskShareRecurrenceEveryDays.
  ///
  /// In en, this message translates to:
  /// **' every {count, plural, one{day} other{{count} days}}'**
  String taskShareRecurrenceEveryDays(int count);

  /// No description provided for @taskShareRecurrenceEveryWeekdays.
  ///
  /// In en, this message translates to:
  /// **' every {count, plural, one{weekday} other{{count} weekdays}}'**
  String taskShareRecurrenceEveryWeekdays(int count);

  /// No description provided for @taskShareRecurrenceEveryWeeks.
  ///
  /// In en, this message translates to:
  /// **' every {count, plural, one{week} other{{count} weeks}}'**
  String taskShareRecurrenceEveryWeeks(int count);

  /// No description provided for @taskShareRecurrenceEveryMonths.
  ///
  /// In en, this message translates to:
  /// **' every {count, plural, one{month} other{{count} months}}'**
  String taskShareRecurrenceEveryMonths(int count);

  /// No description provided for @taskShareRecurrenceEveryOtherYear.
  ///
  /// In en, this message translates to:
  /// **' every other year'**
  String get taskShareRecurrenceEveryOtherYear;

  /// No description provided for @taskShareRecurrenceEveryYears.
  ///
  /// In en, this message translates to:
  /// **' every {count, plural, one{year} other{{count} years}}'**
  String taskShareRecurrenceEveryYears(int count);

  /// No description provided for @taskShareRecurrenceOnDays.
  ///
  /// In en, this message translates to:
  /// **' on {days}'**
  String taskShareRecurrenceOnDays(String days);

  /// No description provided for @taskShareRecurrenceUntil.
  ///
  /// In en, this message translates to:
  /// **' until {date}'**
  String taskShareRecurrenceUntil(String date);

  /// No description provided for @taskShareRecurrenceCount.
  ///
  /// In en, this message translates to:
  /// **' for {count} occurrences'**
  String taskShareRecurrenceCount(int count);

  /// No description provided for @taskShareDeadlineClause.
  ///
  /// In en, this message translates to:
  /// **', due by {dateTime}'**
  String taskShareDeadlineClause(String dateTime);

  /// No description provided for @taskShareNotesClause.
  ///
  /// In en, this message translates to:
  /// **' Notes: {notes}.'**
  String taskShareNotesClause(String notes);

  /// No description provided for @taskShareChangesClause.
  ///
  /// In en, this message translates to:
  /// **' Changes: {changes}'**
  String taskShareChangesClause(String changes);

  /// No description provided for @taskShareOverrideMoveTo.
  ///
  /// In en, this message translates to:
  /// **'move to {dateTime}'**
  String taskShareOverrideMoveTo(String dateTime);

  /// No description provided for @taskShareOverrideDuration.
  ///
  /// In en, this message translates to:
  /// **'for {duration}'**
  String taskShareOverrideDuration(String duration);

  /// No description provided for @taskShareOverrideEndAt.
  ///
  /// In en, this message translates to:
  /// **'end at {dateTime}'**
  String taskShareOverrideEndAt(String dateTime);

  /// No description provided for @taskShareOverridePriority.
  ///
  /// In en, this message translates to:
  /// **'priority {priority}'**
  String taskShareOverridePriority(String priority);

  /// No description provided for @taskShareOverrideCancelled.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get taskShareOverrideCancelled;

  /// No description provided for @taskShareOverrideDone.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get taskShareOverrideDone;

  /// No description provided for @taskShareOverrideRenameTo.
  ///
  /// In en, this message translates to:
  /// **'rename to \"{title}\"'**
  String taskShareOverrideRenameTo(String title);

  /// No description provided for @taskShareOverrideNotes.
  ///
  /// In en, this message translates to:
  /// **'notes \"{notes}\"'**
  String taskShareOverrideNotes(String notes);

  /// No description provided for @taskShareOverrideLocation.
  ///
  /// In en, this message translates to:
  /// **'location \"{location}\"'**
  String taskShareOverrideLocation(String location);

  /// No description provided for @taskShareOverrideNoChanges.
  ///
  /// In en, this message translates to:
  /// **'no changes'**
  String get taskShareOverrideNoChanges;

  /// No description provided for @taskShareOverrideSegment.
  ///
  /// In en, this message translates to:
  /// **'On {dateTime}: {actions}'**
  String taskShareOverrideSegment(String dateTime, String actions);

  /// No description provided for @calendarTaskCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Task copied to clipboard'**
  String get calendarTaskCopiedToClipboard;

  /// No description provided for @calendarTaskSplitRequiresSchedule.
  ///
  /// In en, this message translates to:
  /// **'Task must be scheduled to use split.'**
  String get calendarTaskSplitRequiresSchedule;

  /// No description provided for @calendarTaskSplitTooShort.
  ///
  /// In en, this message translates to:
  /// **'Task is too short to split.'**
  String get calendarTaskSplitTooShort;

  /// No description provided for @calendarTaskSplitUnable.
  ///
  /// In en, this message translates to:
  /// **'Unable to split task at that time.'**
  String get calendarTaskSplitUnable;

  /// No description provided for @calendarDayEventsLabel.
  ///
  /// In en, this message translates to:
  /// **'Day events'**
  String get calendarDayEventsLabel;

  /// No description provided for @calendarShareAsIcsAction.
  ///
  /// In en, this message translates to:
  /// **'Share as .ics'**
  String get calendarShareAsIcsAction;

  /// No description provided for @calendarCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get calendarCompletedLabel;

  /// No description provided for @calendarDeadlineDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get calendarDeadlineDueToday;

  /// No description provided for @calendarDeadlineDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow'**
  String get calendarDeadlineDueTomorrow;

  /// No description provided for @calendarExportTasksFilePrefix.
  ///
  /// In en, this message translates to:
  /// **'axichat_tasks'**
  String get calendarExportTasksFilePrefix;

  /// No description provided for @chatTaskViewTitle.
  ///
  /// In en, this message translates to:
  /// **'Task details'**
  String get chatTaskViewTitle;

  /// No description provided for @chatTaskViewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read-only task.'**
  String get chatTaskViewSubtitle;

  /// No description provided for @chatTaskViewPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get chatTaskViewPreviewLabel;

  /// No description provided for @chatTaskViewActionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Task actions'**
  String get chatTaskViewActionsLabel;

  /// No description provided for @chatTaskViewCopyLabel.
  ///
  /// In en, this message translates to:
  /// **'Copy to calendar'**
  String get chatTaskViewCopyLabel;

  /// No description provided for @chatTaskCopyTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy task'**
  String get chatTaskCopyTitle;

  /// No description provided for @chatTaskCopySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which calendars should receive it.'**
  String get chatTaskCopySubtitle;

  /// No description provided for @chatTaskCopyPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get chatTaskCopyPreviewLabel;

  /// No description provided for @chatTaskCopyCalendarsLabel.
  ///
  /// In en, this message translates to:
  /// **'Calendars'**
  String get chatTaskCopyCalendarsLabel;

  /// No description provided for @chatTaskCopyPersonalLabel.
  ///
  /// In en, this message translates to:
  /// **'Add to personal calendar'**
  String get chatTaskCopyPersonalLabel;

  /// No description provided for @chatTaskCopyChatLabel.
  ///
  /// In en, this message translates to:
  /// **'Add to chat calendar'**
  String get chatTaskCopyChatLabel;

  /// No description provided for @chatTaskCopyConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatTaskCopyConfirmLabel;

  /// No description provided for @chatTaskCopyMissingSelectionMessage.
  ///
  /// In en, this message translates to:
  /// **'Select at least one calendar.'**
  String get chatTaskCopyMissingSelectionMessage;

  /// No description provided for @chatCriticalPathCopyTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy critical path'**
  String get chatCriticalPathCopyTitle;

  /// No description provided for @chatCriticalPathCopySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which calendars should receive it.'**
  String get chatCriticalPathCopySubtitle;

  /// No description provided for @chatCriticalPathCopyPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get chatCriticalPathCopyPreviewLabel;

  /// No description provided for @chatCriticalPathCopyCalendarsLabel.
  ///
  /// In en, this message translates to:
  /// **'Calendars'**
  String get chatCriticalPathCopyCalendarsLabel;

  /// No description provided for @chatCriticalPathCopyPersonalLabel.
  ///
  /// In en, this message translates to:
  /// **'Add to personal calendar'**
  String get chatCriticalPathCopyPersonalLabel;

  /// No description provided for @chatCriticalPathCopyChatLabel.
  ///
  /// In en, this message translates to:
  /// **'Add to chat calendar'**
  String get chatCriticalPathCopyChatLabel;

  /// No description provided for @chatCriticalPathCopyConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatCriticalPathCopyConfirmLabel;

  /// No description provided for @chatCriticalPathCopyMissingSelectionMessage.
  ///
  /// In en, this message translates to:
  /// **'Select at least one calendar.'**
  String get chatCriticalPathCopyMissingSelectionMessage;

  /// No description provided for @chatCriticalPathCopyUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Calendar is unavailable.'**
  String get chatCriticalPathCopyUnavailableMessage;

  /// No description provided for @chatCriticalPathCopySuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Critical path copied.'**
  String get chatCriticalPathCopySuccessMessage;

  /// No description provided for @commonBulletLabel.
  ///
  /// In en, this message translates to:
  /// **'• {text}'**
  String commonBulletLabel(String text);

  /// No description provided for @chatFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages shown'**
  String get chatFilterTitle;

  /// No description provided for @chatFilterDirectOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Direct only'**
  String get chatFilterDirectOnlyLabel;

  /// No description provided for @chatFilterAllLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get chatFilterAllLabel;

  /// No description provided for @calendarFragmentTaskLabel.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get calendarFragmentTaskLabel;

  /// No description provided for @calendarFragmentDayEventLabel.
  ///
  /// In en, this message translates to:
  /// **'Day event'**
  String get calendarFragmentDayEventLabel;

  /// No description provided for @calendarFragmentFreeBusyLabel.
  ///
  /// In en, this message translates to:
  /// **'Free/busy'**
  String get calendarFragmentFreeBusyLabel;

  /// No description provided for @calendarFragmentAvailabilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get calendarFragmentAvailabilityLabel;

  /// No description provided for @calendarFragmentScheduledLabel.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get calendarFragmentScheduledLabel;

  /// No description provided for @calendarFragmentDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get calendarFragmentDueLabel;

  /// No description provided for @calendarFragmentUntitledLabel.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get calendarFragmentUntitledLabel;

  /// No description provided for @calendarFragmentChecklistBullet.
  ///
  /// In en, this message translates to:
  /// **'- '**
  String get calendarFragmentChecklistBullet;

  /// No description provided for @commonAndMoreLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {and 1 more} other {and {count} more}}'**
  String commonAndMoreLabel(int count);

  /// No description provided for @commonBulletSymbol.
  ///
  /// In en, this message translates to:
  /// **'• '**
  String get commonBulletSymbol;

  /// No description provided for @commonLabelSeparator.
  ///
  /// In en, this message translates to:
  /// **': '**
  String get commonLabelSeparator;

  /// No description provided for @commonUnknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknownLabel;

  /// No description provided for @commonBadgeOverflowLabel.
  ///
  /// In en, this message translates to:
  /// **'99+'**
  String get commonBadgeOverflowLabel;

  /// No description provided for @commonEllipsis.
  ///
  /// In en, this message translates to:
  /// **'…'**
  String get commonEllipsis;

  /// No description provided for @chatMessageDetailsSenderLabel.
  ///
  /// In en, this message translates to:
  /// **'Sender address'**
  String get chatMessageDetailsSenderLabel;

  /// No description provided for @chatMessageDetailsMetadataLabel.
  ///
  /// In en, this message translates to:
  /// **'Message metadata'**
  String get chatMessageDetailsMetadataLabel;

  /// No description provided for @chatMessageDetailsHeadersLabel.
  ///
  /// In en, this message translates to:
  /// **'Raw headers'**
  String get chatMessageDetailsHeadersLabel;

  /// No description provided for @chatMessageDetailsHeadersActionLabel.
  ///
  /// In en, this message translates to:
  /// **'View headers'**
  String get chatMessageDetailsHeadersActionLabel;

  /// No description provided for @chatMessageDetailsHeadersNote.
  ///
  /// In en, this message translates to:
  /// **'Headers are loaded from the original RFC822 message.'**
  String get chatMessageDetailsHeadersNote;

  /// No description provided for @chatMessageDetailsHeadersLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading headers...'**
  String get chatMessageDetailsHeadersLoadingLabel;

  /// No description provided for @chatMessageDetailsHeadersUnavailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Headers unavailable.'**
  String get chatMessageDetailsHeadersUnavailableLabel;

  /// No description provided for @chatMessageDetailsDebugDumpLabel.
  ///
  /// In en, this message translates to:
  /// **'Delta debug dump'**
  String get chatMessageDetailsDebugDumpLabel;

  /// No description provided for @chatMessageDetailsDebugDumpActionLabel.
  ///
  /// In en, this message translates to:
  /// **'View debug dump'**
  String get chatMessageDetailsDebugDumpActionLabel;

  /// No description provided for @chatMessageDetailsDebugDumpNote.
  ///
  /// In en, this message translates to:
  /// **'Shows Axichat-stored fields and Delta\'s parsed message payload. This is not the full raw MIME source.'**
  String get chatMessageDetailsDebugDumpNote;

  /// No description provided for @chatMessageDetailsDebugDumpLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading debug dump...'**
  String get chatMessageDetailsDebugDumpLoadingLabel;

  /// No description provided for @chatMessageDetailsDebugDumpUnavailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Debug dump unavailable.'**
  String get chatMessageDetailsDebugDumpUnavailableLabel;

  /// No description provided for @chatMessageDetailsStanzaIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Stanza ID'**
  String get chatMessageDetailsStanzaIdLabel;

  /// No description provided for @chatMessageDetailsOriginIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Origin ID'**
  String get chatMessageDetailsOriginIdLabel;

  /// No description provided for @chatMessageDetailsOccupantIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Occupant ID'**
  String get chatMessageDetailsOccupantIdLabel;

  /// No description provided for @chatMessageDetailsDeltaIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Delta message ID'**
  String get chatMessageDetailsDeltaIdLabel;

  /// No description provided for @chatMessageDetailsLocalIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Local message ID'**
  String get chatMessageDetailsLocalIdLabel;

  /// No description provided for @chatCalendarFragmentShareDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Calendar cards are disabled for your role in this room.'**
  String get chatCalendarFragmentShareDeniedMessage;

  /// No description provided for @chatAvailabilityRequestAccountMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'Availability requests are unavailable right now.'**
  String get chatAvailabilityRequestAccountMissingMessage;

  /// No description provided for @chatAvailabilityRequestEmailUnsupportedMessage.
  ///
  /// In en, this message translates to:
  /// **'Availability is unavailable for email chats.'**
  String get chatAvailabilityRequestEmailUnsupportedMessage;

  /// No description provided for @chatAvailabilityRequestInvalidRangeMessage.
  ///
  /// In en, this message translates to:
  /// **'Availability request time is invalid.'**
  String get chatAvailabilityRequestInvalidRangeMessage;

  /// No description provided for @chatAvailabilityRequestCalendarUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Calendar is unavailable.'**
  String get chatAvailabilityRequestCalendarUnavailableMessage;

  /// No description provided for @chatAvailabilityRequestChatCalendarUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Chat calendar is unavailable.'**
  String get chatAvailabilityRequestChatCalendarUnavailableMessage;

  /// No description provided for @chatAvailabilityRequestTaskTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Requested time'**
  String get chatAvailabilityRequestTaskTitleFallback;

  /// No description provided for @chatSenderAddressPrefix.
  ///
  /// In en, this message translates to:
  /// **'JID: '**
  String get chatSenderAddressPrefix;

  /// No description provided for @chatRecipientVisibilityCcLabel.
  ///
  /// In en, this message translates to:
  /// **'CC'**
  String get chatRecipientVisibilityCcLabel;

  /// No description provided for @chatRecipientVisibilityBccLabel.
  ///
  /// In en, this message translates to:
  /// **'BCC'**
  String get chatRecipientVisibilityBccLabel;

  /// No description provided for @chatInviteRoomFallbackLabel.
  ///
  /// In en, this message translates to:
  /// **'group chat'**
  String get chatInviteRoomFallbackLabel;

  /// No description provided for @chatInviteBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'You have been invited to a group chat'**
  String get chatInviteBodyLabel;

  /// No description provided for @chatInviteRevokedLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite revoked'**
  String get chatInviteRevokedLabel;

  /// No description provided for @chatInviteActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Join \'{roomName}\''**
  String chatInviteActionLabel(String roomName);

  /// No description provided for @chatInviteActionFallbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get chatInviteActionFallbackLabel;

  /// No description provided for @chatInviteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept invite?'**
  String get chatInviteConfirmTitle;

  /// No description provided for @chatInviteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Join \'{roomName}\'?'**
  String chatInviteConfirmMessage(String roomName);

  /// No description provided for @chatInviteConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get chatInviteConfirmLabel;

  /// No description provided for @chatChooseTextToAddHint.
  ///
  /// In en, this message translates to:
  /// **'Select a portion of the message to send to the calendar or edit it first.'**
  String get chatChooseTextToAddHint;

  /// No description provided for @chatAttachmentAutoDownloadLabel.
  ///
  /// In en, this message translates to:
  /// **'Automatically download attachments in this chat'**
  String get chatAttachmentAutoDownloadLabel;

  /// No description provided for @chatAttachmentAutoDownloadHintOn.
  ///
  /// In en, this message translates to:
  /// **'Attachments in this chat will download automatically.'**
  String get chatAttachmentAutoDownloadHintOn;

  /// No description provided for @chatAttachmentAutoDownloadHintOff.
  ///
  /// In en, this message translates to:
  /// **'Attachments are blocked until you approve them.'**
  String get chatAttachmentAutoDownloadHintOff;

  /// No description provided for @chatAttachmentCaption.
  ///
  /// In en, this message translates to:
  /// **'📎 {filename} ({size})'**
  String chatAttachmentCaption(String filename, String size);

  /// No description provided for @chatAttachmentFallbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get chatAttachmentFallbackLabel;

  /// No description provided for @commonFileSizeUnitBytes.
  ///
  /// In en, this message translates to:
  /// **'B'**
  String get commonFileSizeUnitBytes;

  /// No description provided for @commonFileSizeUnitKilobytes.
  ///
  /// In en, this message translates to:
  /// **'KB'**
  String get commonFileSizeUnitKilobytes;

  /// No description provided for @commonFileSizeUnitMegabytes.
  ///
  /// In en, this message translates to:
  /// **'MB'**
  String get commonFileSizeUnitMegabytes;

  /// No description provided for @commonFileSizeUnitGigabytes.
  ///
  /// In en, this message translates to:
  /// **'GB'**
  String get commonFileSizeUnitGigabytes;

  /// No description provided for @commonFileSizeUnitTerabytes.
  ///
  /// In en, this message translates to:
  /// **'TB'**
  String get commonFileSizeUnitTerabytes;

  /// No description provided for @chatAttachmentTooLargeMessageDefault.
  ///
  /// In en, this message translates to:
  /// **'Attachment exceeds the server limit.'**
  String get chatAttachmentTooLargeMessageDefault;

  /// No description provided for @chatAttachmentTooLargeMessage.
  ///
  /// In en, this message translates to:
  /// **'Attachment exceeds the server limit ({limit}).'**
  String chatAttachmentTooLargeMessage(String limit);

  /// No description provided for @chatMessageErrorWithBody.
  ///
  /// In en, this message translates to:
  /// **'{label}: \"{body}\"'**
  String chatMessageErrorWithBody(String label, String body);

  /// Label for the unread messages divider in chat history.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get chatUnreadDividerLabel;

  /// No description provided for @messageErrorServiceUnavailableTooltip.
  ///
  /// In en, this message translates to:
  /// **'The service reported a temporary issue.'**
  String get messageErrorServiceUnavailableTooltip;

  /// No description provided for @messageErrorServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service unavailable'**
  String get messageErrorServiceUnavailable;

  /// No description provided for @messageErrorServerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Server not found'**
  String get messageErrorServerNotFound;

  /// No description provided for @messageErrorServerTimeout.
  ///
  /// In en, this message translates to:
  /// **'Server timed out'**
  String get messageErrorServerTimeout;

  /// No description provided for @messageErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get messageErrorUnknown;

  /// No description provided for @messageErrorNotEncryptedForDevice.
  ///
  /// In en, this message translates to:
  /// **'Not encrypted for this device'**
  String get messageErrorNotEncryptedForDevice;

  /// No description provided for @messageErrorMalformedKey.
  ///
  /// In en, this message translates to:
  /// **'Malformed encryption key'**
  String get messageErrorMalformedKey;

  /// No description provided for @messageErrorUnknownSignedPrekey.
  ///
  /// In en, this message translates to:
  /// **'Unknown signed prekey'**
  String get messageErrorUnknownSignedPrekey;

  /// No description provided for @messageErrorNoDeviceSession.
  ///
  /// In en, this message translates to:
  /// **'No device session'**
  String get messageErrorNoDeviceSession;

  /// No description provided for @messageErrorSkippingTooManyKeys.
  ///
  /// In en, this message translates to:
  /// **'Too many keys skipped'**
  String get messageErrorSkippingTooManyKeys;

  /// No description provided for @messageErrorInvalidHmac.
  ///
  /// In en, this message translates to:
  /// **'Invalid HMAC'**
  String get messageErrorInvalidHmac;

  /// No description provided for @messageErrorMalformedCiphertext.
  ///
  /// In en, this message translates to:
  /// **'Malformed ciphertext'**
  String get messageErrorMalformedCiphertext;

  /// No description provided for @messageErrorNoKeyMaterial.
  ///
  /// In en, this message translates to:
  /// **'Missing key material'**
  String get messageErrorNoKeyMaterial;

  /// No description provided for @messageErrorNoDecryptionKey.
  ///
  /// In en, this message translates to:
  /// **'Missing decryption key'**
  String get messageErrorNoDecryptionKey;

  /// No description provided for @messageErrorInvalidKex.
  ///
  /// In en, this message translates to:
  /// **'Invalid key exchange'**
  String get messageErrorInvalidKex;

  /// No description provided for @messageErrorUnknownOmemo.
  ///
  /// In en, this message translates to:
  /// **'Unknown OMEMO error'**
  String get messageErrorUnknownOmemo;

  /// No description provided for @messageErrorInvalidAffixElements.
  ///
  /// In en, this message translates to:
  /// **'Invalid affix elements'**
  String get messageErrorInvalidAffixElements;

  /// No description provided for @messageErrorEmptyDeviceList.
  ///
  /// In en, this message translates to:
  /// **'Empty device list'**
  String get messageErrorEmptyDeviceList;

  /// No description provided for @messageErrorOmemoUnsupported.
  ///
  /// In en, this message translates to:
  /// **'OMEMO not supported'**
  String get messageErrorOmemoUnsupported;

  /// No description provided for @messageErrorEncryptionFailure.
  ///
  /// In en, this message translates to:
  /// **'Encryption failed'**
  String get messageErrorEncryptionFailure;

  /// No description provided for @messageErrorInvalidEnvelope.
  ///
  /// In en, this message translates to:
  /// **'Invalid envelope'**
  String get messageErrorInvalidEnvelope;

  /// No description provided for @messageErrorFileDownloadFailure.
  ///
  /// In en, this message translates to:
  /// **'File download failed'**
  String get messageErrorFileDownloadFailure;

  /// No description provided for @messageErrorFileUploadFailure.
  ///
  /// In en, this message translates to:
  /// **'File upload failed'**
  String get messageErrorFileUploadFailure;

  /// No description provided for @messageErrorFileDecryptionFailure.
  ///
  /// In en, this message translates to:
  /// **'File decryption failed'**
  String get messageErrorFileDecryptionFailure;

  /// No description provided for @messageErrorFileEncryptionFailure.
  ///
  /// In en, this message translates to:
  /// **'File encryption failed'**
  String get messageErrorFileEncryptionFailure;

  /// No description provided for @messageErrorPlaintextFileInOmemo.
  ///
  /// In en, this message translates to:
  /// **'Plaintext file in OMEMO message'**
  String get messageErrorPlaintextFileInOmemo;

  /// No description provided for @messageErrorEmailSendFailure.
  ///
  /// In en, this message translates to:
  /// **'Email send failed'**
  String get messageErrorEmailSendFailure;

  /// No description provided for @messageErrorEmailAttachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Email attachment too large'**
  String get messageErrorEmailAttachmentTooLarge;

  /// No description provided for @messageErrorEmailRecipientRejected.
  ///
  /// In en, this message translates to:
  /// **'Email recipient rejected'**
  String get messageErrorEmailRecipientRejected;

  /// No description provided for @messageErrorEmailAuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Email authentication failed'**
  String get messageErrorEmailAuthenticationFailed;

  /// No description provided for @messageErrorEmailBounced.
  ///
  /// In en, this message translates to:
  /// **'Email bounced'**
  String get messageErrorEmailBounced;

  /// No description provided for @messageErrorEmailThrottled.
  ///
  /// In en, this message translates to:
  /// **'Email throttled'**
  String get messageErrorEmailThrottled;

  /// No description provided for @chatEmailResendFailedDetails.
  ///
  /// In en, this message translates to:
  /// **'Unable to resend the email.'**
  String get chatEmailResendFailedDetails;

  /// No description provided for @authEnableXmppOrSmtp.
  ///
  /// In en, this message translates to:
  /// **'Enable XMPP or SMTP to continue.'**
  String get authEnableXmppOrSmtp;

  /// No description provided for @authUsernamePasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Username and password have different nullness.'**
  String get authUsernamePasswordMismatch;

  /// No description provided for @authStoredCredentialsOutdated.
  ///
  /// In en, this message translates to:
  /// **'Stored credentials are outdated. Please log in manually.'**
  String get authStoredCredentialsOutdated;

  /// No description provided for @authMissingDatabaseSecrets.
  ///
  /// In en, this message translates to:
  /// **'Local database secrets are missing for this account. Axichat cannot open your existing chats. Restore the original install or reset local data to continue.'**
  String get authMissingDatabaseSecrets;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect username or password'**
  String get authInvalidCredentials;

  /// No description provided for @authGenericError.
  ///
  /// In en, this message translates to:
  /// **'Error. Please try again later.'**
  String get authGenericError;

  /// No description provided for @authStorageLocked.
  ///
  /// In en, this message translates to:
  /// **'Storage is locked by another Axichat instance. Close other windows or processes and try again.'**
  String get authStorageLocked;

  /// No description provided for @authEmailServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the email server. Please try again.'**
  String get authEmailServerUnreachable;

  /// No description provided for @authEmailSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Email setup failed. Please try again.'**
  String get authEmailSetupFailed;

  /// No description provided for @authEmailPasswordMissing.
  ///
  /// In en, this message translates to:
  /// **'Stored email password missing. Please log in manually.'**
  String get authEmailPasswordMissing;

  /// No description provided for @authEmailAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Email authentication failed. Please log in again.'**
  String get authEmailAuthFailed;

  /// No description provided for @signupCleanupInProgress.
  ///
  /// In en, this message translates to:
  /// **'Cleaning up your previous signup attempt. We will retry the removal as soon as you are back online; try again once it finishes.'**
  String get signupCleanupInProgress;

  /// No description provided for @signupFailedTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Failed to register, try again later.'**
  String get signupFailedTryAgain;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'New passwords do not match.'**
  String get authPasswordMismatch;

  /// No description provided for @authPasswordChangeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Password changes are disabled for this account.'**
  String get authPasswordChangeDisabled;

  /// No description provided for @authPasswordChangeRejected.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect, or the new password does not meet server requirements.'**
  String get authPasswordChangeRejected;

  /// No description provided for @authPasswordChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to change password. Please try again later.'**
  String get authPasswordChangeFailed;

  /// No description provided for @authPasswordChangeSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully.'**
  String get authPasswordChangeSuccess;

  /// No description provided for @authPasswordChangeReconnectPending.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Email is reconnecting in the background.'**
  String get authPasswordChangeReconnectPending;

  /// No description provided for @authPasswordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get authPasswordIncorrect;

  /// No description provided for @authDeviceOnlyPasswordUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Device-managed password is unavailable on this device. Account recovery is not possible.'**
  String get authDeviceOnlyPasswordUnavailable;

  /// No description provided for @authAccountNotFound.
  ///
  /// In en, this message translates to:
  /// **'Account not found.'**
  String get authAccountNotFound;

  /// No description provided for @authAccountAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Account already exists.'**
  String get authAccountAlreadyExists;

  /// No description provided for @authAccountDeletionDisabled.
  ///
  /// In en, this message translates to:
  /// **'Account deletion is disabled for this account.'**
  String get authAccountDeletionDisabled;

  /// No description provided for @authAccountDeletionFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete account. Please try again later.'**
  String get authAccountDeletionFailed;

  /// No description provided for @authDemoModeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start demo mode. Please try again.'**
  String get authDemoModeFailed;

  /// No description provided for @authLoginBackoff.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait {seconds} seconds before trying again.'**
  String authLoginBackoff(Object seconds);

  /// No description provided for @signupAvatarCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Crop & focus'**
  String get signupAvatarCropTitle;

  /// No description provided for @signupAvatarCropHint.
  ///
  /// In en, this message translates to:
  /// **'Only the area inside the circle will appear in the final avatar.'**
  String get signupAvatarCropHint;

  /// No description provided for @xmppOperationPubSubBookmarksStart.
  ///
  /// In en, this message translates to:
  /// **'Syncing bookmarks...'**
  String get xmppOperationPubSubBookmarksStart;

  /// No description provided for @xmppOperationPubSubBookmarksSuccess.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks synced'**
  String get xmppOperationPubSubBookmarksSuccess;

  /// No description provided for @xmppOperationPubSubBookmarksFailure.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks sync failed'**
  String get xmppOperationPubSubBookmarksFailure;

  /// No description provided for @xmppOperationPubSubConversationsStart.
  ///
  /// In en, this message translates to:
  /// **'Syncing chats list...'**
  String get xmppOperationPubSubConversationsStart;

  /// No description provided for @xmppOperationPubSubConversationsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Chats list synced'**
  String get xmppOperationPubSubConversationsSuccess;

  /// No description provided for @xmppOperationPubSubConversationsFailure.
  ///
  /// In en, this message translates to:
  /// **'Chats list sync failed'**
  String get xmppOperationPubSubConversationsFailure;

  /// No description provided for @xmppOperationPubSubDraftsStart.
  ///
  /// In en, this message translates to:
  /// **'Syncing drafts...'**
  String get xmppOperationPubSubDraftsStart;

  /// No description provided for @xmppOperationPubSubDraftsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Drafts synced'**
  String get xmppOperationPubSubDraftsSuccess;

  /// No description provided for @xmppOperationPubSubDraftsFailure.
  ///
  /// In en, this message translates to:
  /// **'Drafts sync failed'**
  String get xmppOperationPubSubDraftsFailure;

  /// No description provided for @xmppOperationPubSubSpamStart.
  ///
  /// In en, this message translates to:
  /// **'Syncing spam list...'**
  String get xmppOperationPubSubSpamStart;

  /// No description provided for @xmppOperationPubSubSpamSuccess.
  ///
  /// In en, this message translates to:
  /// **'Spam list synced'**
  String get xmppOperationPubSubSpamSuccess;

  /// No description provided for @xmppOperationPubSubSpamFailure.
  ///
  /// In en, this message translates to:
  /// **'Spam list sync failed'**
  String get xmppOperationPubSubSpamFailure;

  /// No description provided for @xmppOperationPubSubEmailBlocklistStart.
  ///
  /// In en, this message translates to:
  /// **'Syncing email blocklist...'**
  String get xmppOperationPubSubEmailBlocklistStart;

  /// No description provided for @xmppOperationPubSubEmailBlocklistSuccess.
  ///
  /// In en, this message translates to:
  /// **'Email blocklist synced'**
  String get xmppOperationPubSubEmailBlocklistSuccess;

  /// No description provided for @xmppOperationPubSubEmailBlocklistFailure.
  ///
  /// In en, this message translates to:
  /// **'Email blocklist sync failed'**
  String get xmppOperationPubSubEmailBlocklistFailure;

  /// No description provided for @xmppOperationPubSubAvatarMetadataStart.
  ///
  /// In en, this message translates to:
  /// **'Syncing avatar details...'**
  String get xmppOperationPubSubAvatarMetadataStart;

  /// No description provided for @xmppOperationPubSubAvatarMetadataSuccess.
  ///
  /// In en, this message translates to:
  /// **'Avatar details synced'**
  String get xmppOperationPubSubAvatarMetadataSuccess;

  /// No description provided for @xmppOperationPubSubAvatarMetadataFailure.
  ///
  /// In en, this message translates to:
  /// **'Avatar details sync failed'**
  String get xmppOperationPubSubAvatarMetadataFailure;

  /// No description provided for @xmppOperationPubSubFetchStart.
  ///
  /// In en, this message translates to:
  /// **'Syncing account updates...'**
  String get xmppOperationPubSubFetchStart;

  /// No description provided for @xmppOperationPubSubFetchSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account updates synced'**
  String get xmppOperationPubSubFetchSuccess;

  /// No description provided for @xmppOperationPubSubFetchFailure.
  ///
  /// In en, this message translates to:
  /// **'Account updates sync failed'**
  String get xmppOperationPubSubFetchFailure;

  /// No description provided for @xmppOperationMamLoginStart.
  ///
  /// In en, this message translates to:
  /// **'Syncing messages...'**
  String get xmppOperationMamLoginStart;

  /// No description provided for @xmppOperationMamLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Messages synced'**
  String get xmppOperationMamLoginSuccess;

  /// No description provided for @xmppOperationMamLoginFailure.
  ///
  /// In en, this message translates to:
  /// **'Message sync failed'**
  String get xmppOperationMamLoginFailure;

  /// No description provided for @xmppOperationMamGlobalStart.
  ///
  /// In en, this message translates to:
  /// **'Syncing full history...'**
  String get xmppOperationMamGlobalStart;

  /// No description provided for @xmppOperationMamGlobalSuccess.
  ///
  /// In en, this message translates to:
  /// **'History synced'**
  String get xmppOperationMamGlobalSuccess;

  /// No description provided for @xmppOperationMamGlobalFailure.
  ///
  /// In en, this message translates to:
  /// **'History sync failed'**
  String get xmppOperationMamGlobalFailure;

  /// No description provided for @xmppOperationMamMucStart.
  ///
  /// In en, this message translates to:
  /// **'Syncing room history...'**
  String get xmppOperationMamMucStart;

  /// No description provided for @xmppOperationMamMucSuccess.
  ///
  /// In en, this message translates to:
  /// **'Room history synced'**
  String get xmppOperationMamMucSuccess;

  /// No description provided for @xmppOperationMamMucFailure.
  ///
  /// In en, this message translates to:
  /// **'Room history sync failed'**
  String get xmppOperationMamMucFailure;

  /// No description provided for @xmppOperationMamFetchStart.
  ///
  /// In en, this message translates to:
  /// **'Fetching archived messages...'**
  String get xmppOperationMamFetchStart;

  /// No description provided for @xmppOperationMamFetchSuccess.
  ///
  /// In en, this message translates to:
  /// **'Archive fetched'**
  String get xmppOperationMamFetchSuccess;

  /// No description provided for @xmppOperationMamFetchFailure.
  ///
  /// In en, this message translates to:
  /// **'Archive fetch failed'**
  String get xmppOperationMamFetchFailure;

  /// No description provided for @xmppOperationMucJoinStart.
  ///
  /// In en, this message translates to:
  /// **'Joining room...'**
  String get xmppOperationMucJoinStart;

  /// No description provided for @xmppOperationMucJoinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Room joined'**
  String get xmppOperationMucJoinSuccess;

  /// No description provided for @xmppOperationMucJoinFailure.
  ///
  /// In en, this message translates to:
  /// **'Room join failed'**
  String get xmppOperationMucJoinFailure;

  /// No description provided for @chatSettingsCapabilitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get chatSettingsCapabilitiesTitle;

  /// No description provided for @chatSettingsCapabilitiesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last checked: {timestamp}'**
  String chatSettingsCapabilitiesUpdated(Object timestamp);

  /// No description provided for @chatSettingsCapabilitiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No features reported'**
  String get chatSettingsCapabilitiesEmpty;
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
    'that was used.',
  );
}
