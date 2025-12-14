// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'axichat';

  @override
  String get homeTabChats => 'Unterhaltungen';

  @override
  String get homeTabDrafts => 'Entwürfe';

  @override
  String get homeTabSpam => 'Spamordner';

  @override
  String get homeTabBlocked => 'Blockiert';

  @override
  String get homeNoModules => 'Keine Module verfügbar';

  @override
  String get homeRailShowMenu => 'Menü anzeigen';

  @override
  String get homeRailHideMenu => 'Menü ausblenden';

  @override
  String get homeRailCalendar => 'Kalender';

  @override
  String get homeSearchPlaceholderTabs => 'Tabs durchsuchen';

  @override
  String homeSearchPlaceholderForTab(Object tab) {
    return '$tab durchsuchen';
  }

  @override
  String homeSearchFilterLabel(Object filter) {
    return 'Filter: $filter';
  }

  @override
  String get blocklistFilterAll => 'Alle blockiert';

  @override
  String get draftsFilterAll => 'Alle Entwürfe';

  @override
  String get draftsFilterAttachments => 'Mit Anhängen';

  @override
  String get chatsFilterAll => 'Alle Chats';

  @override
  String get chatsFilterContacts => 'Kontakte';

  @override
  String get chatsFilterNonContacts => 'Nicht-Kontakte';

  @override
  String get chatsFilterXmppOnly => 'Nur XMPP';

  @override
  String get chatsFilterEmailOnly => 'Nur E-Mail';

  @override
  String get chatsFilterHidden => 'Ausgeblendet';

  @override
  String get spamFilterAll => 'Alles Spam';

  @override
  String get spamFilterEmail => 'E-Mail';

  @override
  String get spamFilterXmpp => 'XMPP';

  @override
  String get chatFilterDirectOnly => 'Nur Direkt';

  @override
  String get chatFilterAllWithContact => 'Alles mit Kontakt';

  @override
  String get chatSearchMessages => 'Nachrichten durchsuchen';

  @override
  String get chatSearchSortNewestFirst => 'Neueste zuerst';

  @override
  String get chatSearchSortOldestFirst => 'Älteste zuerst';

  @override
  String get chatSearchAnySubject => 'Beliebiger Betreff';

  @override
  String get chatSearchExcludeSubject => 'Betreff ausschließen';

  @override
  String get chatSearchFailed => 'Suche fehlgeschlagen';

  @override
  String get chatSearchInProgress => 'Suche…';

  @override
  String get chatSearchEmptyPrompt => 'Treffer erscheinen unten im Gespräch.';

  @override
  String get chatSearchNoMatches =>
      'Keine Treffer. Filter anpassen oder neu suchen.';

  @override
  String chatSearchMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# Treffer unten angezeigt.',
      one: '# Treffer unten angezeigt.',
    );
    return '$_temp0';
  }

  @override
  String filterTooltip(Object label) {
    return 'Filter • $label';
  }

  @override
  String get chatSearchClose => 'Suche schließen';

  @override
  String get commonSearch => 'Suchen';

  @override
  String get commonClear => 'Leeren';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get spamEmpty => 'Noch kein Spam';

  @override
  String get spamMoveToInbox => 'In den Posteingang verschieben';

  @override
  String get spamMoveToastTitle => 'Verschoben';

  @override
  String spamMoveToastMessage(Object chatTitle) {
    return '$chatTitle zurück in den Posteingang verschoben.';
  }

  @override
  String get chatSpamUpdateFailed =>
      'Spam-Status konnte nicht aktualisiert werden.';

  @override
  String chatSpamSent(Object chatTitle) {
    return '$chatTitle wurde als Spam markiert.';
  }

  @override
  String chatSpamRestored(Object chatTitle) {
    return '$chatTitle wurde in den Posteingang zurückgelegt.';
  }

  @override
  String get chatSpamReportedTitle => 'Gemeldet';

  @override
  String get chatSpamRestoredTitle => 'Wiederhergestellt';

  @override
  String get chatMembersLoading => 'Mitglieder werden geladen';

  @override
  String get chatMembersLoadingEllipsis => 'Mitglieder werden geladen…';

  @override
  String get chatAttachmentConfirmTitle => 'Anhang laden?';

  @override
  String chatAttachmentConfirmMessage(Object sender) {
    return 'Lade nur Anhänge von Kontakten, denen du vertraust.\n\n$sender ist noch nicht in deinen Kontakten. Fortfahren?';
  }

  @override
  String get chatAttachmentConfirmButton => 'Laden';

  @override
  String get chatOpenLinkTitle => 'Externer Link öffnen?';

  @override
  String chatOpenLinkMessage(Object url, Object host) {
    return 'Du bist dabei, zu öffnen:\n$url\n\nTippe nur OK, wenn du der Seite vertraust (Host: $host).';
  }

  @override
  String get chatOpenLinkConfirm => 'Link öffnen';

  @override
  String chatInvalidLink(Object url) {
    return 'Ungültiger Link: $url';
  }

  @override
  String chatUnableToOpenHost(Object host) {
    return '$host kann nicht geöffnet werden';
  }

  @override
  String get chatSaveAsDraft => 'Als Entwurf speichern';

  @override
  String get chatDraftUnavailable => 'Entwürfe sind derzeit nicht verfügbar.';

  @override
  String get chatDraftMissingContent =>
      'Füge vor dem Speichern eine Nachricht, einen Betreff oder einen Anhang hinzu.';

  @override
  String get chatDraftSaved => 'In Entwürfe gespeichert.';

  @override
  String get chatDraftSaveFailed =>
      'Entwurf konnte nicht gespeichert werden. Versuche es erneut.';

  @override
  String get chatAttachmentInaccessible =>
      'Die ausgewählte Datei ist nicht zugänglich.';

  @override
  String get chatAttachmentFailed => 'Datei konnte nicht angehängt werden.';

  @override
  String get chatAttachmentView => 'Ansehen';

  @override
  String get chatAttachmentRetry => 'Upload wiederholen';

  @override
  String get chatAttachmentRemove => 'Anhang entfernen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get toastWhoopsTitle => 'Hoppla';

  @override
  String get toastHeadsUpTitle => 'Achtung';

  @override
  String get toastAllSetTitle => 'Alles erledigt';

  @override
  String get chatRoomMembers => 'Raumteilnehmer';

  @override
  String get chatCloseSettings => 'Einstellungen schließen';

  @override
  String get chatSettings => 'Chat-Einstellungen';

  @override
  String get chatEmptySearch => 'Keine Treffer';

  @override
  String get chatEmptyMessages => 'Keine Nachrichten';

  @override
  String get chatComposerEmailHint => 'E-Mail-Nachricht senden';

  @override
  String get chatComposerMessageHint => 'Nachricht senden';

  @override
  String get chatReadOnly => 'Nur Lesen';

  @override
  String get chatUnarchivePrompt =>
      'Entarchiviere, um neue Nachrichten zu senden.';

  @override
  String get chatEmojiPicker => 'Emoji-Auswahl';

  @override
  String get chatShowingDirectOnly => 'Nur direkte Nachrichten anzeigen';

  @override
  String get chatShowingAll => 'Alles anzeigen';

  @override
  String get chatMuteNotifications => 'Benachrichtigungen stummschalten';

  @override
  String get chatEnableNotifications => 'Benachrichtigungen aktivieren';

  @override
  String get chatMoveToInbox => 'In den Posteingang verschieben';

  @override
  String get chatReportSpam => 'Spam melden';

  @override
  String get chatSignatureToggleLabel =>
      'E-Mail-Fußzeile mit Freigabe-Token einfügen';

  @override
  String get chatSignatureHintEnabled =>
      'Hilft, E-Mail-Threads mit mehreren Empfängern beizubehalten.';

  @override
  String get chatSignatureHintDisabled =>
      'Global deaktiviert; Antworten könnten den Thread verlieren.';

  @override
  String get chatSignatureHintWarning =>
      'Deaktivieren kann Threading und Anhang-Gruppierung stören.';

  @override
  String get chatInviteRevoked => 'Einladung widerrufen';

  @override
  String get chatInvite => 'Einladen';

  @override
  String get chatReactionsNone => 'Noch keine Reaktionen';

  @override
  String get chatReactionsPrompt =>
      'Tippe auf eine Reaktion, um deine hinzuzufügen oder zu entfernen';

  @override
  String get chatReactionsPick => 'Wähle ein Emoji zum Reagieren';

  @override
  String get chatActionReply => 'Antworten';

  @override
  String get chatActionForward => 'Weiterleiten';

  @override
  String get chatActionResend => 'Erneut senden';

  @override
  String get chatActionEdit => 'Bearbeiten';

  @override
  String get chatActionRevoke => 'Widerrufen';

  @override
  String get chatActionCopy => 'Kopieren';

  @override
  String get chatActionShare => 'Teilen';

  @override
  String get chatActionAddToCalendar => 'Zum Kalender hinzufügen';

  @override
  String get chatActionDetails => 'Einzelheiten';

  @override
  String get chatActionSelect => 'Auswählen';

  @override
  String get chatActionReact => 'Reagieren';

  @override
  String get chatContactRenameAction => 'Umbenennen';

  @override
  String get chatContactRenameTooltip => 'Kontakt umbenennen';

  @override
  String get chatContactRenameTitle => 'Kontakt umbenennen';

  @override
  String get chatContactRenameDescription =>
      'Wähle, wie dieser Kontakt in Axichat angezeigt wird.';

  @override
  String get chatContactRenamePlaceholder => 'Anzeigename';

  @override
  String get chatContactRenameReset => 'Auf Standard zurücksetzen';

  @override
  String get chatContactRenameSave => 'Speichern';

  @override
  String get chatContactRenameSuccess => 'Anzeigename aktualisiert';

  @override
  String get chatContactRenameFailure =>
      'Kontakt konnte nicht umbenannt werden';

  @override
  String get chatComposerSemantics => 'Nachrichteneingabe';

  @override
  String get draftSaved => 'Entwurf gespeichert';

  @override
  String get draftErrorTitle => 'Hoppla';

  @override
  String get draftNoRecipients => 'Keine Empfänger';

  @override
  String get draftSubjectSemantics => 'E-Mail-Betreff';

  @override
  String get draftSubjectHintOptional => 'Betreff (optional)';

  @override
  String get draftMessageSemantics => 'Nachrichtentext';

  @override
  String get draftMessageHint => 'Nachricht';

  @override
  String get draftSendingStatus => 'Wird gesendet...';

  @override
  String get draftSendingEllipsis => 'Wird gesendet…';

  @override
  String get draftSend => 'Entwurf senden';

  @override
  String get draftDiscard => 'Verwerfen';

  @override
  String get draftSave => 'Entwurf speichern';

  @override
  String get draftAttachmentInaccessible =>
      'Die ausgewählte Datei ist nicht zugänglich.';

  @override
  String get draftAttachmentFailed => 'Datei konnte nicht angehängt werden.';

  @override
  String get draftDiscarded => 'Entwurf verworfen.';

  @override
  String get draftSendFailed => 'Entwurf konnte nicht gesendet werden.';

  @override
  String get draftSent => 'Gesendet';

  @override
  String get draftValidationNoContent =>
      'Betreff, Nachricht oder Anhang hinzufügen';

  @override
  String draftFileMissing(Object path) {
    return 'Datei existiert unter $path nicht mehr.';
  }

  @override
  String get draftAttachmentPreview => 'Vorschau';

  @override
  String get draftRemoveAttachment => 'Anhang entfernen';

  @override
  String get draftNoAttachments => 'Noch keine Anhänge';

  @override
  String get draftAttachmentsLabel => 'Anhänge';

  @override
  String get draftAddAttachment => 'Anhang hinzufügen';

  @override
  String draftTaskDue(Object date) {
    return 'Fällig $date';
  }

  @override
  String get draftTaskNoSchedule => 'Kein Termin';

  @override
  String get draftTaskUntitled => 'Unbenannte Aufgabe';

  @override
  String get chatBack => 'Zurück';

  @override
  String get chatErrorLabel => 'Fehler!';

  @override
  String get chatSenderYou => 'Du';

  @override
  String get chatInviteAlreadyInRoom => 'Bereits in diesem Raum.';

  @override
  String get chatInviteWrongAccount =>
      'Die Einladung gilt nicht für dieses Konto.';

  @override
  String get chatShareNoText => 'Nachricht enthält keinen Text zum Teilen.';

  @override
  String get chatShareFallbackSubject => 'Axichat-Nachricht';

  @override
  String chatShareSubjectPrefix(Object chatTitle) {
    return 'Geteilt aus $chatTitle';
  }

  @override
  String get chatCalendarNoText =>
      'Nachricht enthält keinen Text für den Kalender.';

  @override
  String get chatCalendarUnavailable => 'Kalender ist gerade nicht verfügbar.';

  @override
  String get chatCopyNoText =>
      'Ausgewählte Nachrichten enthalten keinen Text zum Kopieren.';

  @override
  String get chatShareSelectedNoText =>
      'Ausgewählte Nachrichten enthalten keinen Text zum Teilen.';

  @override
  String get chatForwardInviteForbidden =>
      'Einladungen können nicht weitergeleitet werden.';

  @override
  String get chatAddToCalendarNoText =>
      'Ausgewählte Nachrichten enthalten keinen Text für den Kalender.';

  @override
  String get chatForwardDialogTitle => 'Weiterleiten an...';

  @override
  String get chatComposerAttachmentWarning =>
      'Große Anhänge werden separat an jeden Empfänger gesendet und können länger dauern.';

  @override
  String chatFanOutRecipientLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Empfänger',
      one: 'Empfänger',
    );
    return '$_temp0';
  }

  @override
  String chatFanOutFailureWithSubject(
      Object subject, int count, Object recipientLabel) {
    return 'Betreff \"$subject\" konnte nicht an $count $recipientLabel gesendet werden.';
  }

  @override
  String chatFanOutFailure(int count, Object recipientLabel) {
    return 'Senden an $count $recipientLabel fehlgeschlagen.';
  }

  @override
  String get chatFanOutRetry => 'Erneut versuchen';

  @override
  String get chatSubjectSemantics => 'E-Mail-Betreff';

  @override
  String get chatSubjectHint => 'Betreff';

  @override
  String get chatAttachmentTooltip => 'Anhänge';

  @override
  String get chatSendMessageTooltip => 'Nachricht senden';

  @override
  String get chatBlockAction => 'Blockieren';

  @override
  String get chatReactionMore => 'Mehr';

  @override
  String get chatQuotedNoContent => '(kein Inhalt)';

  @override
  String get chatReplyingTo => 'Antwort auf...';

  @override
  String get chatCancelReply => 'Antwort abbrechen';

  @override
  String get chatMessageRetracted => '(zurückgezogen)';

  @override
  String get chatMessageEdited => '(bearbeitet)';

  @override
  String get chatGuestAttachmentsDisabled =>
      'Anhänge sind in der Vorschau deaktiviert.';

  @override
  String get chatGuestSubtitle => 'Gastvorschau • Lokal gespeichert';

  @override
  String recipientsOverflowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count mehr',
      one: '+1 mehr',
    );
    return '$_temp0';
  }

  @override
  String get recipientsCollapse => 'Einklappen';

  @override
  String recipientsSemantics(int count, Object state) {
    return 'Empfänger $count, $state';
  }

  @override
  String get recipientsStateCollapsed => 'eingeklappt';

  @override
  String get recipientsStateExpanded => 'ausgeklappt';

  @override
  String get recipientsHintExpand => 'Zum Aufklappen drücken';

  @override
  String get recipientsHintCollapse => 'Zum Einklappen drücken';

  @override
  String get recipientsHeaderTitle => 'Senden an...';

  @override
  String get recipientsFallbackLabel => 'Empfänger';

  @override
  String get recipientsAddHint => 'Hinzufügen...';

  @override
  String get chatGuestScriptWelcome =>
      'Willkommen bei Axichat – Chat, E-Mail und Kalender an einem Ort.';

  @override
  String get chatGuestScriptExternalQuestion =>
      'Sieht gut aus. Kann ich Personen erreichen, die nicht auf Axichat sind?';

  @override
  String get chatGuestScriptExternalAnswer =>
      'Ja – sende chat-formattierte E-Mails an Gmail, Outlook, Tuta und mehr. Wenn beide Axichat nutzen, gibt es zusätzlich Gruppenchats, Reaktionen, Zustellbestätigungen und mehr.';

  @override
  String get chatGuestScriptOfflineQuestion =>
      'Funktioniert es offline oder im Gastmodus?';

  @override
  String get chatGuestScriptOfflineAnswer =>
      'Ja – Offline-Funktionalität ist eingebaut und der Kalender funktioniert auch im Gastmodus ohne Konto oder Internet.';

  @override
  String get chatGuestScriptKeepUpQuestion =>
      'Wie hilft es mir, alles im Blick zu behalten?';

  @override
  String get chatGuestScriptKeepUpAnswer =>
      'Unser Kalender bietet natürliche Spracheingabe, Eisenhower-Matrix, Drag-and-drop und Erinnerungen, damit du dich auf das Wesentliche konzentrieren kannst.';

  @override
  String calendarParserUnavailable(Object errorType) {
    return 'Parser nicht verfügbar ($errorType)';
  }

  @override
  String get calendarAddTaskTitle => 'Aufgabe hinzufügen';

  @override
  String get calendarTaskNameRequired => 'Aufgabenname *';

  @override
  String get calendarTaskNameHint => 'Aufgabenname';

  @override
  String get calendarDescriptionHint => 'Beschreibung (optional)';

  @override
  String get calendarLocationHint => 'Ort (optional)';

  @override
  String get calendarScheduleLabel => 'Planen';

  @override
  String get calendarDeadlineLabel => 'Fällig';

  @override
  String get calendarRepeatLabel => 'Wiederholen';

  @override
  String get calendarCancel => 'Abbrechen';

  @override
  String get calendarAddTaskAction => 'Aufgabe hinzufügen';

  @override
  String get calendarSelectionMode => 'Auswahlmodus';

  @override
  String get calendarExit => 'Beenden';

  @override
  String calendarTasksSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# Aufgaben ausgewählt',
      one: '# Aufgabe ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get calendarActions => 'Aktionen';

  @override
  String get calendarSetPriority => 'Priorität festlegen';

  @override
  String get calendarClearSelection => 'Auswahl löschen';

  @override
  String get calendarExportSelected => 'Auswahl exportieren';

  @override
  String get calendarDeleteSelected => 'Auswahl löschen';

  @override
  String get calendarBatchEdit => 'Sammelbearbeitung';

  @override
  String get calendarBatchTitle => 'Titel';

  @override
  String get calendarBatchTitleHint =>
      'Titel für ausgewählte Aufgaben festlegen';

  @override
  String get calendarBatchDescription => 'Beschreibung';

  @override
  String get calendarBatchDescriptionHint =>
      'Beschreibung festlegen (leer lassen zum Löschen)';

  @override
  String get calendarBatchLocation => 'Ort';

  @override
  String get calendarBatchLocationHint =>
      'Ort festlegen (leer lassen zum Löschen)';

  @override
  String get calendarApplyChanges => 'Änderungen anwenden';

  @override
  String get calendarAdjustTime => 'Zeit anpassen';

  @override
  String get calendarSelectionRequired =>
      'Wähle Aufgaben aus, bevor du Änderungen anwendest.';

  @override
  String get calendarSelectionNone => 'Wähle zuerst Aufgaben zum Exportieren.';

  @override
  String get calendarSelectionChangesApplied =>
      'Änderungen auf ausgewählte Aufgaben angewendet.';

  @override
  String get calendarSelectionNoPending => 'Keine ausstehenden Änderungen.';

  @override
  String get calendarSelectionTitleBlank => 'Titel darf nicht leer sein.';

  @override
  String get calendarExportReady => 'Export bereit zum Teilen.';

  @override
  String calendarExportFailed(Object error) {
    return 'Ausgewählte Aufgaben konnten nicht exportiert werden: $error';
  }

  @override
  String get commonBack => 'Zurück';

  @override
  String get composeTitle => 'Verfassen';

  @override
  String get draftComposeMessage => 'Nachricht verfassen';

  @override
  String get draftCompose => 'Verfassen';

  @override
  String get draftNewMessage => 'Neue Nachricht';

  @override
  String get draftRestore => 'Wiederherstellen';

  @override
  String get draftMinimize => 'Minimieren';

  @override
  String get draftExpand => 'Erweitern';

  @override
  String get draftExitFullscreen => 'Vollbild verlassen';

  @override
  String get draftCloseComposer => 'Composer schließen';

  @override
  String get draftsEmpty => 'Noch keine Entwürfe';

  @override
  String get draftsDeleteConfirm => 'Entwurf löschen?';

  @override
  String get draftNoSubject => '(kein Betreff)';

  @override
  String draftRecipientCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Empfänger',
      one: '1 Empfänger',
    );
    return '$_temp0';
  }

  @override
  String get authCreatingAccount => 'Konto wird erstellt…';

  @override
  String get authSecuringLogin => 'Anmeldung wird gesichert…';

  @override
  String get authLoggingIn => 'Anmeldung läuft…';

  @override
  String get authToggleSignup => 'Neu? Registrieren';

  @override
  String get authToggleLogin => 'Schon registriert? Anmelden';

  @override
  String get authGuestCalendarCta => 'Kalender testen (Gastmodus)';

  @override
  String get authLogin => 'Anmelden';

  @override
  String get authRememberMeLabel => 'Auf diesem Gerät angemeldet bleiben';

  @override
  String get authSignUp => 'Registrieren';

  @override
  String get authToggleSelected => 'Aktuelle Auswahl';

  @override
  String authToggleSelectHint(Object label) {
    return 'Aktivieren, um $label auszuwählen';
  }

  @override
  String get authUsername => 'Benutzername';

  @override
  String get authUsernameRequired => 'Benutzernamen eingeben';

  @override
  String get authUsernameRules =>
      '4–20 alphanumerische Zeichen, „.“, „_“ und „-“ erlaubt.';

  @override
  String get authUsernameCaseInsensitive => 'Groß-/Kleinschreibung egal';

  @override
  String get authPassword => 'Passwort';

  @override
  String get authPasswordConfirm => 'Passwort bestätigen';

  @override
  String get authPasswordRequired => 'Passwort eingeben';

  @override
  String authPasswordMaxLength(Object max) {
    return 'Maximal $max Zeichen';
  }

  @override
  String get authPasswordsMismatch => 'Passwörter stimmen nicht überein';

  @override
  String get authPasswordPending => 'Passwort wird geprüft';

  @override
  String get authSignupPending => 'Registrierung läuft';

  @override
  String get authLoginPending => 'Anmeldung läuft';

  @override
  String get signupTitle => 'Registrieren';

  @override
  String get signupStepUsername => 'Benutzername wählen';

  @override
  String get signupStepPassword => 'Passwort erstellen';

  @override
  String get signupStepCaptcha => 'Captcha prüfen';

  @override
  String get signupStepSetup => 'Einrichtung';

  @override
  String signupErrorPrefix(Object message) {
    return 'Fehler: $message';
  }

  @override
  String get signupCaptchaUnavailable => 'Captcha nicht verfügbar';

  @override
  String get signupCaptchaChallenge => 'Captcha-Abfrage';

  @override
  String get signupCaptchaFailed =>
      'Captcha konnte nicht geladen werden. Versuche es erneut über „Neu laden“.';

  @override
  String get signupCaptchaLoading => 'Captcha wird geladen';

  @override
  String get signupCaptchaInstructions =>
      'Gib die Zeichen aus diesem Captcha ein.';

  @override
  String get signupCaptchaReload => 'Captcha neu laden';

  @override
  String get signupCaptchaReloadHint =>
      'Neues Captcha holen, falls unleserlich.';

  @override
  String get signupCaptchaPlaceholder => 'Obigen Text eingeben';

  @override
  String get signupCaptchaValidation => 'Text aus dem Bild eingeben';

  @override
  String get signupContinue => 'Weiter';

  @override
  String get signupProgressLabel => 'Registrierungsfortschritt';

  @override
  String signupProgressValue(
      Object current, Object currentLabel, Object percent, Object total) {
    return 'Schritt $current von $total: $currentLabel. $percent% abgeschlossen.';
  }

  @override
  String get signupProgressSection => 'Kontoeinrichtung';

  @override
  String get signupPasswordStrength => 'Passwortstärke';

  @override
  String get signupPasswordBreached =>
      'Dieses Passwort wurde in einer geleakten Datenbank gefunden.';

  @override
  String get signupStrengthNone => 'Keine';

  @override
  String get signupStrengthWeak => 'Schwach';

  @override
  String get signupStrengthMedium => 'Mittel';

  @override
  String get signupStrengthStronger => 'Stärker';

  @override
  String get signupRiskAcknowledgement => 'Ich verstehe das Risiko';

  @override
  String get signupRiskError => 'Zum Fortfahren das Kästchen oben ankreuzen.';

  @override
  String get signupRiskAllowBreach =>
      'Dieses Passwort trotz eines Leaks erlauben.';

  @override
  String get signupRiskAllowWeak =>
      'Dieses Passwort zulassen, obwohl es als schwach gilt.';

  @override
  String get signupCaptchaErrorMessage =>
      'Captcha kann nicht geladen werden.\nZum Wiederholen auf Aktualisieren tippen.';

  @override
  String get signupAvatarRenderError =>
      'Dieses Avatar konnte nicht gerendert werden.';

  @override
  String get signupAvatarLoadError =>
      'Dieses Avatar konnte nicht geladen werden.';

  @override
  String get signupAvatarReadError =>
      'Dieses Bild konnte nicht gelesen werden.';

  @override
  String get signupAvatarOpenError =>
      'Diese Datei konnte nicht geöffnet werden.';

  @override
  String get signupAvatarInvalidImage => 'Diese Datei ist kein gültiges Bild.';

  @override
  String signupAvatarSizeError(Object kilobytes) {
    return 'Avatar muss unter $kilobytes KB bleiben.';
  }

  @override
  String get signupAvatarProcessError =>
      'Dieses Bild kann nicht verarbeitet werden.';

  @override
  String get signupAvatarEdit => 'Avatar bearbeiten';

  @override
  String get signupAvatarUploadImage => 'Bild hochladen';

  @override
  String get signupAvatarUpload => 'Hochladen';

  @override
  String get signupAvatarShuffle => 'Standard zufällig wählen';

  @override
  String get signupAvatarMenuDescription =>
      'Wir veröffentlichen den Avatar, sobald dein XMPP-Konto erstellt ist.';

  @override
  String get signupAvatarBackgroundColor => 'Hintergrundfarbe';

  @override
  String get signupAvatarDefaultsTitle => 'Standard-Avatare';

  @override
  String get signupAvatarCategoryAbstract => 'Abstrakt';

  @override
  String get signupAvatarCategoryScience => 'Wissenschaft';

  @override
  String get signupAvatarCategorySports => 'Sport';

  @override
  String get signupAvatarCategoryMusic => 'Musik';

  @override
  String get notificationsRestartTitle =>
      'App neu starten, um Benachrichtigungen zu aktivieren';

  @override
  String get notificationsRestartSubtitle =>
      'Erforderliche Berechtigungen bereits erteilt';

  @override
  String get notificationsMessageToggle => 'Nachrichtenbenachrichtigungen';

  @override
  String get notificationsRequiresRestart => 'Neustart erforderlich';

  @override
  String get notificationsDialogTitle =>
      'Nachrichtenbenachrichtigungen aktivieren';

  @override
  String get notificationsDialogIgnore => 'Ignorieren';

  @override
  String get notificationsDialogContinue => 'Fortfahren';

  @override
  String get notificationsDialogDescription =>
      'Chats können später jederzeit stummgeschaltet werden.';

  @override
  String get calendarAdjustStartMinus => 'Start -15 Min';

  @override
  String get calendarAdjustStartPlus => 'Start +15 Min';

  @override
  String get calendarAdjustEndMinus => 'Ende -15 Min';

  @override
  String get calendarAdjustEndPlus => 'Ende +15 Min';

  @override
  String get calendarCopyToClipboardAction => 'In Zwischenablage kopieren';

  @override
  String calendarCopyLocation(Object location) {
    return 'Ort: $location';
  }

  @override
  String get calendarTaskCopied => 'Aufgabe kopiert';

  @override
  String get calendarTaskCopiedClipboard =>
      'Aufgabe in die Zwischenablage kopiert';

  @override
  String get calendarCopyTask => 'Aufgabe kopieren';

  @override
  String get calendarDeleteTask => 'Aufgabe löschen';

  @override
  String get calendarSelectionNoneShort => 'Keine Aufgaben ausgewählt.';

  @override
  String get calendarSelectionMixedRecurrence =>
      'Aufgaben haben unterschiedliche Wiederholungen. Änderungen gelten für alle ausgewählten Aufgaben.';

  @override
  String get calendarSelectionNoTasksHint =>
      'Keine Aufgaben ausgewählt. Nutze „Auswählen“ im Kalender, um Aufgaben zum Bearbeiten zu wählen.';

  @override
  String get calendarSelectionRemove => 'Aus Auswahl entfernen';

  @override
  String get calendarQuickTaskHint =>
      'Schnellaufgabe (z. B. „Meeting um 14 Uhr in Raum 101“)';

  @override
  String get calendarAdvancedHide => 'Erweiterte Optionen ausblenden';

  @override
  String get calendarAdvancedShow => 'Erweiterte Optionen anzeigen';

  @override
  String get calendarUnscheduledTitle => 'Nicht terminierte Aufgaben';

  @override
  String get calendarUnscheduledEmptyLabel =>
      'Keine nicht terminierten Aufgaben';

  @override
  String get calendarUnscheduledEmptyHint =>
      'Hinzugefügte Aufgaben erscheinen hier';

  @override
  String get calendarRemindersTitle => 'Erinnerungen';

  @override
  String get calendarRemindersEmptyLabel => 'Noch keine Erinnerungen';

  @override
  String get calendarRemindersEmptyHint =>
      'Füge eine Frist hinzu, um eine Erinnerung zu erstellen';

  @override
  String get calendarNothingHere => 'Hier gibt es noch nichts';

  @override
  String get calendarTaskNotFound => 'Aufgabe nicht gefunden';

  @override
  String get calendarDayEventsTitle => 'Tagestermine';

  @override
  String get calendarDayEventsEmpty => 'Keine Tagesereignisse für dieses Datum';

  @override
  String get calendarDayEventsAdd => 'Tagestermin hinzufügen';

  @override
  String get accessibilityNewContactLabel => 'Kontaktadresse';

  @override
  String get accessibilityNewContactHint => 'jemand@beispiel.de';

  @override
  String get accessibilityStartChat => 'Chat starten';

  @override
  String get accessibilityStartChatHint =>
      'Diese Adresse senden, um eine Unterhaltung zu beginnen.';

  @override
  String get accessibilityMessagesEmpty => 'Noch keine Nachrichten';

  @override
  String get accessibilityMessageNoContent => 'Kein Nachrichteninhalt';

  @override
  String get accessibilityActionsTitle => 'Aktionen';

  @override
  String get accessibilityReadNewMessages => 'Neue Nachrichten lesen';

  @override
  String get accessibilityUnreadSummaryDescription =>
      'Konzentriere dich auf Unterhaltungen mit ungelesenen Nachrichten';

  @override
  String get accessibilityStartNewChat => 'Neuen Chat starten';

  @override
  String get accessibilityStartNewChatDescription =>
      'Kontakt auswählen oder Adresse eingeben';

  @override
  String get accessibilityInvitesTitle => 'Einladungen';

  @override
  String get accessibilityPendingInvites => 'Ausstehende Einladungen';

  @override
  String get accessibilityAcceptInvite => 'Einladung annehmen';

  @override
  String get accessibilityInviteAccepted => 'Einladung angenommen';

  @override
  String get accessibilityInviteDismissed => 'Einladung abgelehnt';

  @override
  String get accessibilityInviteUpdateFailed =>
      'Einladung konnte nicht aktualisiert werden';

  @override
  String get accessibilityUnreadEmpty => 'Keine ungelesenen Unterhaltungen';

  @override
  String get accessibilityInvitesEmpty => 'Keine ausstehenden Einladungen';

  @override
  String get accessibilityMessagesTitle => 'Nachrichten';

  @override
  String get accessibilityNoConversationSelected =>
      'Keine Unterhaltung ausgewählt';

  @override
  String accessibilityMessagesWithContact(Object name) {
    return 'Nachrichten mit $name';
  }

  @override
  String accessibilityMessageLabel(
      Object sender, Object timestamp, Object body) {
    return '$sender um $timestamp: $body';
  }

  @override
  String get accessibilityMessageSent => 'Nachricht gesendet.';

  @override
  String get accessibilityDiscardWarning =>
      'Drücke erneut Escape, um deine Nachricht zu verwerfen und diesen Schritt zu schließen.';

  @override
  String get accessibilityDraftLoaded =>
      'Entwurf geladen. Drücke Escape zum Beenden oder Speichern, um Änderungen zu behalten.';

  @override
  String accessibilityDraftLabel(Object id) {
    return 'Entwurf $id';
  }

  @override
  String accessibilityDraftLabelWithRecipients(Object recipients) {
    return 'Entwurf an $recipients';
  }

  @override
  String accessibilityDraftPreview(Object recipients, Object preview) {
    return '$recipients — $preview';
  }

  @override
  String accessibilityIncomingMessageStatus(Object sender, Object time) {
    return 'Neue Nachricht von $sender um $time';
  }

  @override
  String accessibilityAttachmentWithName(Object filename) {
    return 'Anhang: $filename';
  }

  @override
  String get accessibilityAttachmentGeneric => 'Anhang';

  @override
  String get accessibilityUploadAvailable => 'Upload verfügbar';

  @override
  String get accessibilityUnknownContact => 'Unbekannter Kontakt';

  @override
  String get accessibilityChooseContact => 'Kontakt auswählen';

  @override
  String get accessibilityUnreadConversations => 'Ungelesene Unterhaltungen';

  @override
  String get accessibilityStartNewAddress => 'Neue Adresse eingeben';

  @override
  String accessibilityConversationWith(Object name) {
    return 'Unterhaltung mit $name';
  }

  @override
  String get accessibilityConversationLabel => 'Unterhaltung';

  @override
  String get accessibilityDialogLabel => 'Dialog für Bedienungshilfen';

  @override
  String get accessibilityDialogHint =>
      'Drücke Tab für Tastenkürzel, nutze Pfeiltasten in Listen, Shift plus Pfeile für Gruppenwechsel oder Escape zum Beenden.';

  @override
  String get accessibilityNoActionsAvailable =>
      'Derzeit keine Aktionen verfügbar';

  @override
  String accessibilityBreadcrumbLabel(
      Object position, Object total, Object label) {
    return 'Schritt $position von $total: $label. Aktivieren, um zu diesem Schritt zu springen.';
  }

  @override
  String get accessibilityShortcutOpenMenu => 'Menü öffnen';

  @override
  String get accessibilityShortcutBack => 'Einen Schritt zurück oder schließen';

  @override
  String get accessibilityShortcutNextFocus => 'Nächstes Fokusziel';

  @override
  String get accessibilityShortcutPreviousFocus => 'Vorheriges Fokusziel';

  @override
  String get accessibilityShortcutActivateItem => 'Element aktivieren';

  @override
  String get accessibilityShortcutNextItem => 'Nächstes Element';

  @override
  String get accessibilityShortcutPreviousItem => 'Vorheriges Element';

  @override
  String get accessibilityShortcutNextGroup => 'Nächste Gruppe';

  @override
  String get accessibilityShortcutPreviousGroup => 'Vorherige Gruppe';

  @override
  String get accessibilityShortcutFirstItem => 'Erstes Element';

  @override
  String get accessibilityShortcutLastItem => 'Letztes Element';

  @override
  String get accessibilityKeyboardShortcutsTitle => 'Tastaturkürzel';

  @override
  String accessibilityKeyboardShortcutAnnouncement(Object description) {
    return 'Tastaturkürzel: $description';
  }

  @override
  String get accessibilityTextFieldHint =>
      'Text eingeben. Tab zum Weitergehen oder Escape zum Zurückgehen bzw. Schließen.';

  @override
  String get accessibilityComposerPlaceholder => 'Nachricht eingeben';

  @override
  String accessibilityRecipientLabel(Object name) {
    return 'Empfänger $name';
  }

  @override
  String get accessibilityRecipientRemoveHint =>
      'Mit Rückschritt oder Entf-Taste entfernen';

  @override
  String get accessibilityMessageActionsLabel => 'Nachrichtenaktionen';

  @override
  String get accessibilityMessageActionsHint =>
      'Als Entwurf speichern oder diese Nachricht senden';

  @override
  String accessibilityMessagePosition(Object position, Object total) {
    return 'Nachricht $position von $total';
  }

  @override
  String get accessibilityNoMessages => 'Keine Nachrichten';

  @override
  String accessibilityMessageMetadata(Object sender, Object timestamp) {
    return 'Von $sender um $timestamp';
  }

  @override
  String accessibilityMessageFrom(Object sender) {
    return 'Von $sender';
  }

  @override
  String get accessibilityMessageNavigationHint =>
      'Mit den Pfeiltasten zwischen Nachrichten wechseln. Shift plus Pfeile wechselt die Gruppe. Escape beendet.';

  @override
  String accessibilitySectionSummary(Object section, Object count) {
    return '$section-Bereich mit $count Einträgen';
  }

  @override
  String accessibilityActionListLabel(Object count) {
    return 'Aktionsliste mit $count Einträgen';
  }

  @override
  String get accessibilityActionListHint =>
      'Mit Pfeiltasten bewegen, Shift plus Pfeile für Gruppen, Home/Ende zum Springen, Enter zum Ausführen, Escape zum Beenden.';

  @override
  String accessibilityActionItemPosition(
      Object position, Object total, Object section) {
    return 'Element $position von $total in $section';
  }

  @override
  String get accessibilityActionReadOnlyHint =>
      'Mit den Pfeiltasten durch die Liste bewegen';

  @override
  String get accessibilityActionActivateHint => 'Drücke Enter zum Aktivieren';

  @override
  String get accessibilityDismissHighlight => 'Hinweis ausblenden';

  @override
  String get accessibilityNeedsAttention => 'Benötigt Aufmerksamkeit';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileJidDescription =>
      'Dies ist deine Jabber-ID. Sie besteht aus Benutzername und Domain und ist deine eindeutige Adresse im XMPP-Netzwerk.';

  @override
  String get profileResourceDescription =>
      'Dies ist deine XMPP-Ressource. Jedes Gerät hat eine eigene, daher kann dein Telefon einen anderen Status als dein Desktop haben.';

  @override
  String get profileStatusPlaceholder => 'Statusnachricht';

  @override
  String get profileArchives => 'Archive anzeigen';

  @override
  String get profileEditAvatar => 'Avatar bearbeiten';

  @override
  String get profileChangePassword => 'Passwort ändern';

  @override
  String get profileDeleteAccount => 'Konto löschen';

  @override
  String get termsAcceptLabel => 'Ich akzeptiere die Geschäftsbedingungen';

  @override
  String get termsAgreementPrefix => 'Du stimmst unseren ';

  @override
  String get termsAgreementTerms => 'Bedingungen';

  @override
  String get termsAgreementAnd => ' und ';

  @override
  String get termsAgreementPrivacy => 'Datenschutzerklärung';

  @override
  String get termsAgreementError =>
      'Du musst die Geschäftsbedingungen akzeptieren';

  @override
  String get commonContinue => 'Weiter';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonRemove => 'Entfernen';

  @override
  String get commonSend => 'Senden';

  @override
  String get commonDismiss => 'Schließen';

  @override
  String get settingsSectionImportant => 'Wichtig';

  @override
  String get settingsSectionAppearance => 'Erscheinungsbild';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsThemeMode => 'Designmodus';

  @override
  String get settingsThemeModeSystem => 'System';

  @override
  String get settingsThemeModeLight => 'Hell';

  @override
  String get settingsThemeModeDark => 'Dunkel';

  @override
  String get settingsColorScheme => 'Farbschema';

  @override
  String get settingsColorfulAvatars => 'Bunte Avatare';

  @override
  String get settingsColorfulAvatarsDescription =>
      'Erzeuge unterschiedliche Hintergrundfarben für jeden Avatar.';

  @override
  String get settingsLowMotion => 'Weniger Bewegung';

  @override
  String get settingsLowMotionDescription =>
      'Deaktiviert die meisten Animationen. Besser für langsame Geräte.';

  @override
  String get settingsSectionChats => 'Chats';

  @override
  String get settingsMessageStorageTitle => 'Nachrichtenspeicherung';

  @override
  String get settingsMessageStorageSubtitle =>
      'Lokal behält Gerätekopien; Nur Server fragt das Archiv ab.';

  @override
  String get settingsMessageStorageLocal => 'Lokal';

  @override
  String get settingsMessageStorageServerOnly => 'Nur Server';

  @override
  String get settingsMuteNotifications => 'Benachrichtigungen stummschalten';

  @override
  String get settingsMuteNotificationsDescription =>
      'Keine Nachrichtenbenachrichtigungen mehr erhalten.';

  @override
  String get settingsNotificationPreviews => 'Benachrichtigungsvorschau';

  @override
  String get settingsNotificationPreviewsDescription =>
      'Nachrichteninhalt in Benachrichtigungen und auf dem Sperrbildschirm anzeigen.';

  @override
  String get settingsReadReceipts => 'Lesebestätigungen senden';

  @override
  String get settingsTypingIndicators => 'Tippanzeigen senden';

  @override
  String get settingsTypingIndicatorsDescription =>
      'Lässt andere im Chat sehen, wenn du tippst.';

  @override
  String get settingsShareTokenFooter => 'Freigabe-Token-Fußzeile anhängen';

  @override
  String get settingsShareTokenFooterDescription =>
      'Hilft, E-Mail-Threads mit mehreren Empfängern und Anhängen zusammenzuhalten. Deaktivieren kann Threads aufbrechen.';

  @override
  String get authCustomServerTitle => 'Eigener Server';

  @override
  String get authCustomServerDescription =>
      'XMPP/SMTP-Endpunkte überschreiben oder DNS-Abfragen aktivieren. Felder leer lassen, um Standardwerte zu behalten.';

  @override
  String get authCustomServerDomainOrIp => 'Domain oder IP';

  @override
  String get authCustomServerXmppLabel => 'XMPP';

  @override
  String get authCustomServerSmtpLabel => 'SMTP';

  @override
  String get authCustomServerUseDns => 'DNS verwenden';

  @override
  String get authCustomServerUseSrv => 'SRV verwenden';

  @override
  String get authCustomServerRequireDnssec => 'DNSSEC erzwingen';

  @override
  String get authCustomServerXmppHostPlaceholder => 'XMPP-Host (optional)';

  @override
  String get authCustomServerPortPlaceholder => 'Port';

  @override
  String get authCustomServerSmtpHostPlaceholder => 'SMTP-Host (optional)';

  @override
  String get authCustomServerApiPortPlaceholder => 'API-Port';

  @override
  String get authCustomServerReset => 'Auf axi.im zurücksetzen';

  @override
  String get authCustomServerOpenSettings =>
      'Eigene Servereinstellungen öffnen';

  @override
  String get authCustomServerAdvancedHint =>
      'Erweiterte Serveroptionen bleiben verborgen, bis du auf das Benutzernamen-Suffix tippst.';

  @override
  String get authUnregisterTitle => 'Abmelden';

  @override
  String get authUnregisterProgressLabel => 'Warten auf Kontolöschung';

  @override
  String get authPasswordPlaceholder => 'Passwort';

  @override
  String get authPasswordCurrentPlaceholder => 'Altes Passwort';

  @override
  String get authPasswordNewPlaceholder => 'Neues Passwort';

  @override
  String get authPasswordConfirmNewPlaceholder => 'Neues Passwort bestätigen';

  @override
  String get authChangePasswordProgressLabel => 'Warten auf Passwortänderung';

  @override
  String get authLogoutTitle => 'Abmelden';

  @override
  String get authLogoutNormal => 'Abmelden';

  @override
  String get authLogoutNormalDescription => 'Von diesem Konto abmelden.';

  @override
  String get authLogoutBurn => 'Konto löschen';

  @override
  String get authLogoutBurnDescription =>
      'Abmelden und lokale Daten für dieses Konto löschen.';

  @override
  String get chatAttachmentBlockedTitle => 'Anhang blockiert';

  @override
  String get chatAttachmentBlockedDescription =>
      'Lade Anhänge von unbekannten Kontakten nur, wenn du ihnen vertraust. Wir rufen ihn ab, sobald du zustimmst.';

  @override
  String get chatAttachmentLoad => 'Anhang laden';

  @override
  String get chatAttachmentUnavailable => 'Anhang nicht verfügbar';

  @override
  String get chatAttachmentSendFailed => 'Anhang konnte nicht gesendet werden.';

  @override
  String get chatAttachmentRetryUpload => 'Upload wiederholen';

  @override
  String get chatAttachmentRemoveAttachment => 'Anhang entfernen';

  @override
  String get chatAttachmentStatusUploading => 'Anhang wird hochgeladen…';

  @override
  String get chatAttachmentStatusQueued => 'Warten auf Versand';

  @override
  String get chatAttachmentStatusFailed => 'Upload fehlgeschlagen';

  @override
  String get chatAttachmentLoading => 'Anhang wird geladen';

  @override
  String chatAttachmentLoadingProgress(Object percent) {
    return 'Lade $percent';
  }

  @override
  String get chatAttachmentDownload => 'Anhang herunterladen';

  @override
  String get chatAttachmentUnavailableDevice =>
      'Anhang ist auf diesem Gerät nicht mehr verfügbar';

  @override
  String get chatAttachmentInvalidLink => 'Ungültiger Anhang-Link';

  @override
  String chatAttachmentOpenFailed(Object target) {
    return 'Konnte $target nicht öffnen';
  }

  @override
  String get chatAttachmentUnknownSize => 'Unbekannte Größe';

  @override
  String chatAttachmentErrorTooltip(Object message, Object fileName) {
    return '$message ($fileName)';
  }

  @override
  String get chatAttachmentMenuHint => 'Menü für Aktionen öffnen.';

  @override
  String get accessibilityActionsLabel => 'Bedienungshilfen-Aktionen';

  @override
  String accessibilityActionsShortcutTooltip(Object shortcut) {
    return 'Bedienungshilfen-Aktionen ($shortcut)';
  }

  @override
  String get shorebirdUpdateAvailable =>
      'Update verfügbar: abmelden und die App neu starten';

  @override
  String get calendarEditTaskTitle => 'Aufgabe bearbeiten';

  @override
  String get calendarDateTimeLabel => 'Datum & Uhrzeit';

  @override
  String get calendarSelectDate => 'Datum auswählen';

  @override
  String get calendarSelectTime => 'Uhrzeit auswählen';

  @override
  String get calendarDurationLabel => 'Dauer';

  @override
  String get calendarSelectDuration => 'Dauer auswählen';

  @override
  String get calendarAddToCriticalPath => 'Zur kritischen Abfolge hinzufügen';

  @override
  String get calendarNoCriticalPathMembership => 'In keiner kritischen Abfolge';

  @override
  String get calendarGuestTitle => 'Gastkalender';

  @override
  String get calendarGuestBanner => 'Gastmodus - keine Synchronisierung';

  @override
  String get calendarGuestModeLabel => 'Gastmodus';

  @override
  String get calendarGuestModeDescription =>
      'Melden Sie sich an, um Aufgaben zu synchronisieren und Erinnerungen zu aktivieren.';

  @override
  String get calendarNoTasksForDate => 'Keine Aufgaben für dieses Datum';

  @override
  String get calendarTapToCreateTask =>
      'Tippen Sie auf +, um eine Aufgabe zu erstellen';

  @override
  String get calendarQuickStats => 'Schnellübersicht';

  @override
  String get calendarDueReminders => 'Fällige Erinnerungen';

  @override
  String get calendarNextTaskLabel => 'Nächste Aufgabe';

  @override
  String get calendarNone => 'Keine';

  @override
  String get calendarViewLabel => 'Ansicht';

  @override
  String get calendarViewDay => 'Tag';

  @override
  String get calendarViewWeek => 'Woche';

  @override
  String get calendarViewMonth => 'Monat';

  @override
  String get calendarPreviousDate => 'Vorheriges Datum';

  @override
  String get calendarNextDate => 'Nächstes Datum';

  @override
  String calendarPreviousUnit(Object unit) {
    return 'Vorheriger $unit';
  }

  @override
  String calendarNextUnit(Object unit) {
    return 'Nächster $unit';
  }

  @override
  String get calendarToday => 'Heute';

  @override
  String get calendarUndo => 'Rückgängig';

  @override
  String get calendarRedo => 'Wiederholen';

  @override
  String get calendarOpeningCreator => 'Aufgabenerstellung wird geöffnet ...';

  @override
  String calendarWeekOf(Object date) {
    return 'Woche vom $date';
  }

  @override
  String get calendarStatusCompleted => 'Abgeschlossen';

  @override
  String get calendarStatusOverdue => 'Überfällig';

  @override
  String get calendarStatusDueSoon => 'Bald fällig';

  @override
  String get calendarStatusPending => 'Ausstehend';

  @override
  String get calendarTaskCompletedMessage => 'Aufgabe abgeschlossen!';

  @override
  String get calendarTaskUpdatedMessage => 'Aufgabe aktualisiert!';

  @override
  String get calendarErrorTitle => 'Fehler';

  @override
  String get calendarErrorTaskNotFound => 'Aufgabe nicht gefunden';

  @override
  String get calendarErrorTitleEmpty => 'Titel darf nicht leer sein';

  @override
  String get calendarErrorTitleTooLong => 'Titel zu lang';

  @override
  String get calendarErrorDescriptionTooLong => 'Beschreibung zu lang';

  @override
  String get calendarErrorInputInvalid => 'Eingabe ungültig';

  @override
  String get calendarErrorAddFailed =>
      'Aufgabe konnte nicht hinzugefügt werden';

  @override
  String get calendarErrorUpdateFailed =>
      'Aufgabe konnte nicht aktualisiert werden';

  @override
  String get calendarErrorDeleteFailed =>
      'Aufgabe konnte nicht gelöscht werden';

  @override
  String get calendarErrorNetwork => 'Netzwerkfehler';

  @override
  String get calendarErrorStorage => 'Speicherfehler';

  @override
  String get calendarErrorUnknown => 'Unbekannter Fehler';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get commonOpen => 'Öffnen';

  @override
  String get commonSelect => 'Auswählen';

  @override
  String get commonExport => 'Exportieren';

  @override
  String get commonFavorite => 'Favorisieren';

  @override
  String get commonUnfavorite => 'Favorit entfernen';

  @override
  String get commonArchive => 'Archivieren';

  @override
  String get commonUnarchive => 'Aus Archiv holen';

  @override
  String get commonShow => 'Einblenden';

  @override
  String get commonHide => 'Ausblenden';

  @override
  String get blocklistBlockUser => 'Benutzer blockieren';

  @override
  String get blocklistWaitingForUnblock => 'Warte auf Entsperrung';

  @override
  String get blocklistUnblockAll => 'Alle entsperren';

  @override
  String get blocklistUnblock => 'Entsperren';

  @override
  String get blocklistBlock => 'Blockieren';

  @override
  String get blocklistAddTooltip => 'Zur Blockliste hinzufügen';

  @override
  String get mucChangeNickname => 'Spitznamen ändern';

  @override
  String mucChangeNicknameWithCurrent(Object current) {
    return 'Spitznamen ändern (aktuell: $current)';
  }

  @override
  String get mucLeaveRoom => 'Raum verlassen';

  @override
  String get mucNoMembers => 'Noch keine Mitglieder';

  @override
  String get mucInviteUsers => 'Benutzer einladen';

  @override
  String get mucSendInvites => 'Einladungen senden';

  @override
  String get mucChangeNicknameTitle => 'Spitznamen ändern';

  @override
  String get mucEnterNicknamePlaceholder => 'Spitznamen eingeben';

  @override
  String get mucUpdateNickname => 'Aktualisieren';

  @override
  String get mucMembersTitle => 'Mitglieder';

  @override
  String get mucInviteUser => 'Benutzer einladen';

  @override
  String get mucSectionOwners => 'Eigentümer';

  @override
  String get mucSectionAdmins => 'Admins';

  @override
  String get mucSectionModerators => 'Moderatoren';

  @override
  String get mucSectionMembers => 'Mitglieder';

  @override
  String get mucSectionVisitors => 'Besucher';

  @override
  String get mucRoleOwner => 'Eigentümer';

  @override
  String get mucRoleAdmin => 'Admin';

  @override
  String get mucRoleMember => 'Mitglied';

  @override
  String get mucRoleVisitor => 'Besucher';

  @override
  String get mucRoleModerator => 'Moderator';

  @override
  String get mucActionKick => 'Rauswerfen';

  @override
  String get mucActionBan => 'Sperren';

  @override
  String get mucActionMakeMember => 'Als Mitglied festlegen';

  @override
  String get mucActionMakeAdmin => 'Zum Admin machen';

  @override
  String get mucActionMakeOwner => 'Zum Besitzer machen';

  @override
  String get mucActionGrantModerator => 'Moderatorrechte vergeben';

  @override
  String get mucActionRevokeModerator => 'Moderatorrechte entziehen';

  @override
  String get chatsEmptyList => 'Noch keine Chats';

  @override
  String chatsDeleteConfirmMessage(Object chatTitle) {
    return 'Chat löschen: $chatTitle';
  }

  @override
  String get chatsDeleteMessagesOption => 'Nachrichten dauerhaft löschen';

  @override
  String get chatsDeleteSuccess => 'Chat gelöscht';

  @override
  String get chatsExportNoContent => 'Kein Textinhalt zum Exportieren';

  @override
  String get chatsExportShareText => 'Chat-Export von Axichat';

  @override
  String chatsExportShareSubject(Object chatTitle) {
    return 'Chat mit $chatTitle';
  }

  @override
  String get chatsExportSuccess => 'Chat exportiert';

  @override
  String get chatsExportFailure => 'Chat kann nicht exportiert werden';

  @override
  String get chatsArchivedRestored => 'Chat wiederhergestellt';

  @override
  String get chatsArchivedHint =>
      'Chat archiviert (Profil → Archivierte Chats)';

  @override
  String get chatsVisibleNotice => 'Chat ist wieder sichtbar';

  @override
  String get chatsHiddenNotice => 'Chat verborgen (über Filter einblenden)';

  @override
  String chatsUnreadLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# ungelesene Nachrichten',
      one: '# ungelesene Nachricht',
      zero: 'Keine ungelesenen Nachrichten',
    );
    return '$_temp0';
  }

  @override
  String get chatsSemanticsUnselectHint => 'Drücken, um den Chat abzuwählen';

  @override
  String get chatsSemanticsSelectHint => 'Drücken, um den Chat auszuwählen';

  @override
  String get chatsSemanticsOpenHint => 'Drücken, um den Chat zu öffnen';

  @override
  String get chatsHideActions => 'Chat-Aktionen ausblenden';

  @override
  String get chatsShowActions => 'Chat-Aktionen anzeigen';

  @override
  String get chatsSelectedLabel => 'Chat ausgewählt';

  @override
  String get chatsSelectLabel => 'Chat auswählen';

  @override
  String get chatsExportFileLabel => 'chats';

  @override
  String get chatSelectionExportEmptyTitle =>
      'Keine Nachrichten zum Exportieren';

  @override
  String get chatSelectionExportEmptyMessage =>
      'Chats mit Textinhalt auswählen';

  @override
  String get chatSelectionExportShareText => 'Chat-Exporte von Axichat';

  @override
  String get chatSelectionExportShareSubject => 'Axichat-Chat-Export';

  @override
  String get chatSelectionExportReadyTitle => 'Export bereit';

  @override
  String chatSelectionExportReadyMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# Chats geteilt',
      one: '# Chat geteilt',
    );
    return '$_temp0';
  }

  @override
  String get chatSelectionExportFailedTitle => 'Export fehlgeschlagen';

  @override
  String get chatSelectionExportFailedMessage =>
      'Ausgewählte Chats können nicht exportiert werden';

  @override
  String get chatSelectionDeleteConfirmTitle => 'Chats löschen?';

  @override
  String chatSelectionDeleteConfirmMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Dadurch werden # Chats mit allen Nachrichten gelöscht. Dies kann nicht rückgängig gemacht werden.',
      one:
          'Dadurch wird 1 Chat mit allen Nachrichten gelöscht. Dies kann nicht rückgängig gemacht werden.',
    );
    return '$_temp0';
  }

  @override
  String get chatsCreateGroupChatTooltip => 'Gruppenchat erstellen';

  @override
  String get chatsRoomLabel => 'Raum';

  @override
  String get chatsCreateChatRoomTitle => 'Chatraum erstellen';

  @override
  String get chatsRoomNamePlaceholder => 'Name';

  @override
  String get chatsArchiveTitle => 'Archiv';

  @override
  String get chatsArchiveEmpty => 'Noch keine archivierten Chats';

  @override
  String calendarTileNow(Object title) {
    return 'Jetzt: $title';
  }

  @override
  String calendarTileNext(Object title) {
    return 'Als Nächstes: $title';
  }

  @override
  String get calendarTileNone => 'Keine anstehenden Aufgaben';

  @override
  String get calendarViewDayShort => 'T';

  @override
  String get calendarViewWeekShort => 'W';

  @override
  String get calendarViewMonthShort => 'M';

  @override
  String get calendarShowCompleted => 'Abgeschlossene anzeigen';

  @override
  String get calendarHideCompleted => 'Abgeschlossene ausblenden';

  @override
  String get rosterAddTooltip => 'Zum Adressbuch hinzufügen';

  @override
  String get rosterAddLabel => 'Kontakt';

  @override
  String get rosterAddTitle => 'Kontakt hinzufügen';

  @override
  String get rosterEmpty => 'Noch keine Kontakte';

  @override
  String get rosterCompose => 'Verfassen';

  @override
  String rosterRemoveConfirm(Object jid) {
    return '$jid aus Kontakten entfernen?';
  }

  @override
  String get rosterInvitesEmpty => 'Noch keine Einladungen';

  @override
  String rosterRejectInviteConfirm(Object jid) {
    return 'Einladung von $jid ablehnen?';
  }

  @override
  String get rosterAddContactTooltip => 'Kontakt hinzufügen';

  @override
  String get jidInputPlaceholder => 'john@axi.im';

  @override
  String get jidInputInvalid => 'Gültige JID eingeben';

  @override
  String get sessionCapabilityChat => 'Chat';

  @override
  String get sessionCapabilityEmail => 'E-Mail';

  @override
  String get sessionCapabilityStatusConnected => 'Verbunden';

  @override
  String get sessionCapabilityStatusConnecting => 'Verbindungsaufbau';

  @override
  String get sessionCapabilityStatusError => 'Fehler';

  @override
  String get sessionCapabilityStatusOffline => 'Offline';

  @override
  String get sessionCapabilityStatusOff => 'Aus';

  @override
  String get sessionCapabilityStatusSyncing => 'Synchronisieren';
}
