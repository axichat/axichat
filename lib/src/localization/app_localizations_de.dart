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
  String get homeTabChats => 'Chats';

  @override
  String get homeTabDrafts => 'Entwürfe';

  @override
  String get homeTabSpam => 'Spam';

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
  String get chatActionDetails => 'Details';

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
}
