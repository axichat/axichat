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
  String get attachmentGalleryRosterTrustLabel =>
      'Dateien von diesem Benutzer automatisch herunterladen';

  @override
  String get attachmentGalleryRosterTrustHint =>
      'Du kannst das später in den Chat-Einstellungen deaktivieren.';

  @override
  String get attachmentGalleryChatTrustLabel =>
      'Anhänge in diesem Chat immer erlauben';

  @override
  String get attachmentGalleryChatTrustHint =>
      'Du kannst das später in den Chat-Einstellungen deaktivieren.';

  @override
  String get attachmentGalleryRosterErrorTitle =>
      'Kontakt konnte nicht hinzugefügt werden';

  @override
  String get attachmentGalleryRosterErrorMessage =>
      'Diesen Anhang einmal heruntergeladen, aber automatische Downloads sind weiterhin deaktiviert.';

  @override
  String get attachmentGalleryErrorMessage =>
      'Anhänge konnten nicht geladen werden.';

  @override
  String get attachmentGalleryAllLabel => 'Alle';

  @override
  String get attachmentGalleryImagesLabel => 'Bilder';

  @override
  String get attachmentGalleryVideosLabel => 'Videos';

  @override
  String get attachmentGalleryFilesLabel => 'Dateien';

  @override
  String get attachmentGallerySentLabel => 'Gesendet';

  @override
  String get attachmentGalleryReceivedLabel => 'Empfangen';

  @override
  String get attachmentGalleryLayoutGridLabel => 'Grid view';

  @override
  String get attachmentGalleryLayoutListLabel => 'List view';

  @override
  String get attachmentGallerySortNameAscLabel => 'Name A-Z';

  @override
  String get attachmentGallerySortNameDescLabel => 'Name Z-A';

  @override
  String get attachmentGallerySortSizeAscLabel => 'Größe klein bis groß';

  @override
  String get attachmentGallerySortSizeDescLabel => 'Größe groß bis klein';

  @override
  String get chatOpenLinkTitle => 'Externer Link öffnen?';

  @override
  String chatOpenLinkMessage(Object url, Object host) {
    return 'Du bist dabei, zu öffnen:\n$url\n\nTippe nur OK, wenn du der Seite vertraust (Host: $host).';
  }

  @override
  String chatOpenLinkWarningMessage(Object url, Object host) {
    return 'Du bist dabei, zu öffnen:\n$url\n\nDieser Link enthält ungewöhnliche oder unsichtbare Zeichen. Prüfe die Adresse sorgfältig (Host: $host).';
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
  String chatComposerFromHint(Object address) {
    return 'Senden von $address';
  }

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
  String get chatReportSpam => 'Als Spam markieren';

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
  String get chatCalendarTaskCopyActionLabel => 'In den Kalender kopieren';

  @override
  String get chatCalendarTaskImportConfirmTitle => 'Zum Kalender hinzufügen?';

  @override
  String get chatCalendarTaskImportConfirmMessage =>
      'Diese Aufgabe stammt aus dem Chat. Füge sie deinem Kalender hinzu, um sie zu verwalten oder zu bearbeiten.';

  @override
  String get chatCalendarTaskImportConfirmLabel => 'Zum Kalender hinzufügen';

  @override
  String get chatCalendarTaskImportCancelLabel => 'Nicht jetzt';

  @override
  String get chatCalendarTaskCopyUnavailableMessage =>
      'Kalender ist nicht verfügbar.';

  @override
  String get chatCalendarTaskCopyAlreadyAddedMessage =>
      'Aufgabe bereits hinzugefügt.';

  @override
  String get chatCalendarTaskCopySuccessMessage => 'Aufgabe kopiert.';

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
  String get draftAutosaved => 'Automatisch gespeichert';

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
  String draftLimitWarning(int limit, int count) {
    return 'Die Entwurfssynchronisierung behält bis zu $limit Entwürfe. Du hast $count.';
  }

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
  String get draftRestoreAction => 'Aus Entwurf wiederherstellen';

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
  String get avatarSaveAvatar => 'Avatar speichern';

  @override
  String get avatarUseThis => 'Avatar festlegen';

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
  String get calendarDayEventsEmpty => 'Keine Tagesereignisse fur dieses Datum';

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
  String get profileLinkedEmailAccounts => 'Email accounts';

  @override
  String get profileChangePassword => 'Passwort ändern';

  @override
  String get profileDeleteAccount => 'Konto löschen';

  @override
  String profileExportActionLabel(Object label) {
    return 'Export $label';
  }

  @override
  String get profileExportXmppMessagesLabel => 'XMPP-Nachrichten';

  @override
  String get profileExportXmppContactsLabel => 'XMPP-Kontakte';

  @override
  String get profileExportEmailMessagesLabel => 'E-Mails';

  @override
  String get profileExportEmailContactsLabel => 'E-Mail-Kontakte';

  @override
  String profileExportShareText(Object label) {
    return 'Axichat-Export: $label';
  }

  @override
  String profileExportShareSubject(Object label) {
    return 'Axichat-$label-Export';
  }

  @override
  String profileExportReadyMessage(Object label) {
    return '$label-Export bereit.';
  }

  @override
  String profileExportEmptyMessage(Object label) {
    return 'Keine $label zum Exportieren.';
  }

  @override
  String profileExportFailedMessage(Object label) {
    return '$label konnte nicht exportiert werden.';
  }

  @override
  String profileExportShareUnsupportedMessage(Object label, Object path) {
    return 'Teilen ist auf dieser Plattform nicht verfügbar. $label-Export gespeichert unter $path.';
  }

  @override
  String get profileExportCopyPathAction => 'Pfad kopieren';

  @override
  String get profileExportPathCopiedMessage =>
      'Exportpfad in die Zwischenablage kopiert.';

  @override
  String get profileExportFormatTitle => 'Exportformat auswählen';

  @override
  String get profileExportFormatCsvTitle => 'CSV (.csv)';

  @override
  String get profileExportFormatCsvSubtitle =>
      'Funktioniert mit den meisten Adressbüchern.';

  @override
  String get profileExportFormatVcardTitle => 'vCard (.vcf)';

  @override
  String get profileExportFormatVcardSubtitle => 'Standard-Visitenkarten.';

  @override
  String get termsAcceptLabel => 'Ich akzeptiere die Geschäftsbedingungen';

  @override
  String get termsAgreementPrefix => 'Du stimmst unseren ';

  @override
  String get termsAgreementTerms => 'Bedingungen';

  @override
  String get termsAgreementAnd => ' und ';

  @override
  String get termsAgreementPrivacy => 'Datenschutz';

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
  String get settingsButtonLabel => 'Einstellungen';

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
  String get settingsSectionEmail => 'E-Mail';

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
  String get settingsChatReadReceipts => 'Lesebestätigungen für Chats senden';

  @override
  String get settingsChatReadReceiptsDescription =>
      'Wenn aktiviert, sendet das Öffnen eines Chats bei aktiver App Lesebestätigungen für sichtbare Nachrichten.';

  @override
  String get settingsEmailReadReceipts =>
      'Lesebestätigungen für E-Mails senden';

  @override
  String get settingsEmailReadReceiptsDescription =>
      'Wenn aktiviert, sendet das Öffnen eines E-Mail-Chats bei aktiver App Lesebestätigungen (MDNs) für sichtbare Nachrichten.';

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
  String get authCustomServerImapHostPlaceholder => 'IMAP-Host (optional)';

  @override
  String get authCustomServerApiPortPlaceholder => 'API-Port';

  @override
  String get authCustomServerEmailProvisioningUrlPlaceholder =>
      'E-Mail-Provisioning-URL (optional)';

  @override
  String get authCustomServerEmailPublicTokenPlaceholder =>
      'Öffentlicher E-Mail-Token (optional)';

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
  String get authUnregisterConfirmTitle => 'Delete account?';

  @override
  String get authUnregisterConfirmMessage =>
      'This will permanently delete your account and local data. This cannot be undone.';

  @override
  String get authUnregisterConfirmAction => 'Delete account';

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
  String get chatAttachmentDownloadAndOpen => 'Anhang herunterladen und öffnen';

  @override
  String get chatAttachmentDownloadAndSave =>
      'Anhang herunterladen und speichern';

  @override
  String get chatAttachmentDownloadAndShare =>
      'Anhang herunterladen und teilen';

  @override
  String get chatAttachmentExportTitle => 'Anhang speichern?';

  @override
  String get chatAttachmentExportMessage =>
      'Dies kopiert den Anhang in den gemeinsamen Speicher. Exporte sind unverschlüsselt und können von anderen Apps gelesen werden. Fortfahren?';

  @override
  String get chatAttachmentExportConfirm => 'Speichern';

  @override
  String get chatAttachmentExportCancel => 'Abbrechen';

  @override
  String get chatMediaMetadataWarningTitle =>
      'Medien können Metadaten enthalten';

  @override
  String get chatMediaMetadataWarningMessage =>
      'Fotos und Videos können Standort- und Gerätedaten enthalten. Trotzdem fortfahren?';

  @override
  String get chatNotificationPreviewOptionInherit =>
      'App-Einstellung verwenden';

  @override
  String get chatNotificationPreviewOptionShow => 'Vorschau immer anzeigen';

  @override
  String get chatNotificationPreviewOptionHide => 'Vorschau immer verbergen';

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
  String get chatAttachmentUnknownSize => 'Unbekannte Größe';

  @override
  String get chatAttachmentNotDownloadedYet => 'Not downloaded yet';

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
  String get mucEditAvatar => 'Raum-Avatar bearbeiten';

  @override
  String get mucAvatarMenuDescription => 'Raummitglieder sehen diesen Avatar.';

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
  String get chatExportWarningTitle => 'Chatverlauf exportieren?';

  @override
  String get chatExportWarningMessage =>
      'Chat-Exporte sind unverschlüsselt und können von anderen Apps oder Cloud-Diensten gelesen werden. Fortfahren?';

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
  String get chatsCreateChatRoomAction => 'Raum erstellen';

  @override
  String get chatsRoomNamePlaceholder => 'Name';

  @override
  String get chatsRoomNameRequiredError => 'Der Raumname darf nicht leer sein.';

  @override
  String chatsRoomNameInvalidCharacterError(Object character) {
    return 'Raumnamen dürfen das Zeichen $character nicht enthalten.';
  }

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

  @override
  String get authChangePasswordPending => 'Passwort wird aktualisiert...';

  @override
  String get authEndpointAdvancedHint => 'Erweiterte Optionen';

  @override
  String get authEndpointApiPortPlaceholder => 'API-Port';

  @override
  String get authEndpointDescription =>
      'XMPP-/SMTP-Endpunkte für dieses Konto konfigurieren.';

  @override
  String get authEndpointDomainPlaceholder => 'Domain';

  @override
  String get authEndpointPortPlaceholder => 'Port';

  @override
  String get authEndpointRequireDnssecLabel => 'DNSSEC erforderlich';

  @override
  String get authEndpointReset => 'Zurücksetzen';

  @override
  String get authEndpointSmtpHostPlaceholder => 'SMTP-Host';

  @override
  String get authEndpointSmtpLabel => 'SMTP';

  @override
  String get authEndpointTitle => 'Endpoint-Konfiguration';

  @override
  String get authEndpointUseDnsLabel => 'DNS verwenden';

  @override
  String get authEndpointUseSrvLabel => 'SRV verwenden';

  @override
  String get authEndpointXmppHostPlaceholder => 'XMPP-Host';

  @override
  String get authEndpointXmppLabel => 'XMPP';

  @override
  String get authUnregisterPending => 'Abmeldung läuft...';

  @override
  String calendarAddTaskError(Object details) {
    return 'Aufgabe konnte nicht hinzugefügt werden: $details';
  }

  @override
  String get calendarBackToCalendar => 'Zurück zum Kalender';

  @override
  String get calendarLoadingMessage => 'Kalender wird geladen...';

  @override
  String get calendarCriticalPathAddTask => 'Aufgabe hinzufügen';

  @override
  String get calendarCriticalPathAddToTitle => 'Zum kritischen Pfad hinzufügen';

  @override
  String get calendarCriticalPathCreatePrompt =>
      'Erstelle einen kritischen Pfad, um zu beginnen';

  @override
  String get calendarCriticalPathDragHint =>
      'Aufgaben ziehen, um sie neu anzuordnen';

  @override
  String get calendarCriticalPathEmptyTasks => 'Keine Aufgaben in diesem Pfad';

  @override
  String get calendarCriticalPathNameEmptyError => 'Name eingeben';

  @override
  String get calendarCriticalPathNamePlaceholder => 'Name des kritischen Pfads';

  @override
  String get calendarCriticalPathNamePrompt => 'Name';

  @override
  String get calendarCriticalPathTaskOrderTitle => 'Aufgaben anordnen';

  @override
  String get calendarCriticalPathsAll => 'Alle Pfade';

  @override
  String get calendarCriticalPathsEmpty => 'Noch keine kritischen Pfade';

  @override
  String get calendarCriticalPathsNew => 'Neuer kritischer Pfad';

  @override
  String get calendarCriticalPathRenameTitle => 'Kritischen Pfad umbenennen';

  @override
  String get calendarCriticalPathDeleteTitle => 'Kritischen Pfad löschen';

  @override
  String get calendarCriticalPathsTitle => 'Kritische Pfade';

  @override
  String get calendarCriticalPathShareAction => 'Im Chat teilen';

  @override
  String get calendarCriticalPathShareTitle => 'Kritischen Pfad teilen';

  @override
  String get calendarCriticalPathShareSubtitle =>
      'Einen kritischen Pfad an einen Chat senden.';

  @override
  String get calendarCriticalPathShareTargetLabel => 'Teilen mit';

  @override
  String get calendarCriticalPathShareButtonLabel => 'Teilen';

  @override
  String get calendarCriticalPathShareMissingChats =>
      'Keine geeigneten Chats verfügbar.';

  @override
  String get calendarCriticalPathShareMissingRecipient =>
      'Wähle einen Chat zum Teilen aus.';

  @override
  String get calendarCriticalPathShareMissingService =>
      'Kalenderfreigabe ist nicht verfügbar.';

  @override
  String get calendarCriticalPathShareDenied =>
      'Kalenderkarten sind für deine Rolle in diesem Raum deaktiviert.';

  @override
  String get calendarCriticalPathShareFailed =>
      'Kritischer Pfad konnte nicht geteilt werden.';

  @override
  String get calendarCriticalPathShareSuccess => 'Kritischer Pfad geteilt.';

  @override
  String get calendarCriticalPathShareChatTypeDirect => 'Direkter Chat';

  @override
  String get calendarCriticalPathShareChatTypeGroup => 'Gruppenchat';

  @override
  String get calendarCriticalPathShareChatTypeNote => 'Notizen';

  @override
  String calendarCriticalPathProgressSummary(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$completed von $total Aufgaben in Reihenfolge abgeschlossen',
      one: '$completed von $total Aufgabe in Reihenfolge abgeschlossen',
    );
    return '$_temp0';
  }

  @override
  String get calendarCriticalPathProgressHint =>
      'Schließe Aufgaben in der angegebenen Reihenfolge ab, um voranzukommen.';

  @override
  String get calendarCriticalPathProgressLabel => 'Fortschritt';

  @override
  String calendarCriticalPathProgressPercent(int percent) {
    return '$percent%';
  }

  @override
  String get calendarCriticalPathFocus => 'Fokussieren';

  @override
  String get calendarCriticalPathUnfocus => 'Fokus entfernen';

  @override
  String get calendarCriticalPathCompletedLabel => 'Abgeschlossen';

  @override
  String calendarCriticalPathQueuedAdd(Object name) {
    return 'Wird beim Speichern zu \"$name\" hinzugefügt';
  }

  @override
  String calendarCriticalPathQueuedCreate(Object name) {
    return '\"$name\" erstellt und vorgemerkt';
  }

  @override
  String get calendarCriticalPathUnavailable =>
      'Kritische Pfade sind in dieser Ansicht nicht verfügbar.';

  @override
  String get calendarCriticalPathAddAfterSaveFailed =>
      'Aufgabe gespeichert, konnte aber keinem kritischen Pfad hinzugefügt werden.';

  @override
  String calendarCriticalPathAddSuccess(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben zu \"$name\" hinzugefügt.',
      one: 'Zu \"$name\" hinzugefügt.',
    );
    return '$_temp0';
  }

  @override
  String calendarCriticalPathCreateSuccess(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '\"$name\" erstellt und Aufgaben hinzugefügt.',
      one: '\"$name\" erstellt und Aufgabe hinzugefügt.',
    );
    return '$_temp0';
  }

  @override
  String calendarCriticalPathAddFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aufgaben konnten einem kritischen Pfad nicht hinzugefügt werden.',
      one: 'Aufgabe konnte einem kritischen Pfad nicht hinzugefügt werden.',
    );
    return '$_temp0';
  }

  @override
  String calendarCriticalPathAlreadyContainsTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aufgaben sind bereits in diesem kritischen Pfad.',
      one: 'Aufgabe ist bereits in diesem kritischen Pfad.',
    );
    return '$_temp0';
  }

  @override
  String get calendarCriticalPathCreateFailed =>
      'Kritischer Pfad konnte nicht erstellt werden.';

  @override
  String get calendarTaskSearchTitle => 'Aufgaben suchen';

  @override
  String calendarTaskSearchAddToTitle(Object name) {
    return 'Zu $name hinzufügen';
  }

  @override
  String get calendarTaskSearchSubtitle =>
      'Titel, Beschreibungen, Orte, Kategorien, Prioritäten und Fristen durchsuchen.';

  @override
  String get calendarTaskSearchAddToSubtitle =>
      'Tippe auf eine Aufgabe, um sie an die Reihenfolge des kritischen Pfads anzuhängen.';

  @override
  String get calendarTaskSearchHint =>
      'title:, desc:, location:, category:work, priority:urgent, status:done';

  @override
  String get calendarTaskSearchEmptyPrompt => 'Tippe, um Aufgaben zu suchen';

  @override
  String get calendarTaskSearchEmptyNoResults => 'Keine Ergebnisse gefunden';

  @override
  String get calendarTaskSearchEmptyHint =>
      'Verwende Filter wie title:, desc:, location:, priority:critical, status:done, deadline:today.';

  @override
  String get calendarTaskSearchFilterScheduled => 'Geplant';

  @override
  String get calendarTaskSearchFilterUnscheduled => 'Ohne Termin';

  @override
  String get calendarTaskSearchFilterReminders => 'Erinnerungen';

  @override
  String get calendarTaskSearchFilterOpen => 'Offen';

  @override
  String get calendarTaskSearchFilterCompleted => 'Erledigt';

  @override
  String calendarTaskSearchDueDate(Object date) {
    return 'Fällig $date';
  }

  @override
  String calendarTaskSearchOverdueDate(Object date) {
    return 'Überfällig · $date';
  }

  @override
  String calendarDeleteTaskConfirm(Object title) {
    return '\"$title\" löschen?';
  }

  @override
  String get calendarErrorTitleEmptyFriendly => 'Titel darf nicht leer sein';

  @override
  String get calendarExportFormatIcsSubtitle =>
      'Für Kalender-Clients verwenden';

  @override
  String get calendarExportFormatIcsTitle => 'ICS exportieren';

  @override
  String get calendarExportFormatJsonSubtitle =>
      'Für Backups oder Skripte verwenden';

  @override
  String get calendarExportFormatJsonTitle => 'JSON exportieren';

  @override
  String calendarRemovePathConfirm(Object name) {
    return 'Diese Aufgabe aus \"$name\" entfernen?';
  }

  @override
  String get calendarSandboxHint =>
      'Plane Aufgaben hier, bevor du sie einem Pfad zuweist.';

  @override
  String get chatAlertHide => 'Ausblenden';

  @override
  String get chatAlertIgnore => 'Ignorieren';

  @override
  String get chatAttachmentTapToLoad => 'Zum Laden tippen';

  @override
  String chatMessageAddRecipientSuccess(Object recipient) {
    return '$recipient hinzugefügt';
  }

  @override
  String get chatMessageAddRecipients => 'Empfänger hinzufügen';

  @override
  String get chatMessageCreateChat => 'Chat erstellen';

  @override
  String chatMessageCreateChatFailure(Object reason) {
    return 'Chat konnte nicht erstellt werden: $reason';
  }

  @override
  String get chatMessageInfoDevice => 'Gerät';

  @override
  String get chatMessageInfoError => 'Fehler';

  @override
  String get chatMessageInfoProtocol => 'Protokoll';

  @override
  String get chatMessageInfoTimestamp => 'Zeitstempel';

  @override
  String get chatMessageOpenChat => 'Chat öffnen';

  @override
  String get chatMessageStatusDisplayed => 'Gelesen';

  @override
  String get chatMessageStatusReceived => 'Empfangen';

  @override
  String get chatMessageStatusSent => 'Gesendet';

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
  String get avatarOpenError => 'Datei konnte nicht geöffnet werden.';

  @override
  String get avatarReadError => 'Datei konnte nicht gelesen werden.';

  @override
  String get avatarInvalidImageError => 'Diese Datei ist kein gültiges Bild.';

  @override
  String get avatarProcessError => 'Bild konnte nicht verarbeitet werden.';

  @override
  String get avatarTemplateLoadError =>
      'Avatar-Option konnte nicht geladen werden.';

  @override
  String get avatarMissingDraftError =>
      'Wähle zuerst einen Avatar aus oder erstelle ihn.';

  @override
  String get avatarXmppDisconnectedError =>
      'Verbinde dich mit XMPP, bevor du deinen Avatar speicherst.';

  @override
  String get avatarPublishRejectedError =>
      'Dein Server hat die Avatar-Veröffentlichung abgelehnt.';

  @override
  String get avatarPublishTimeoutError =>
      'Avatar-Upload hat zu lange gedauert. Bitte versuche es erneut.';

  @override
  String get avatarPublishGenericError =>
      'Avatar konnte nicht veröffentlicht werden. Prüfe die Verbindung und versuche es erneut.';

  @override
  String get avatarPublishUnexpectedError =>
      'Unerwarteter Fehler beim Hochladen des Avatars.';

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
  String get commonDone => 'Fertig';

  @override
  String get commonRename => 'Umbenennen';

  @override
  String get calendarHour => 'Stunde';

  @override
  String get calendarMinute => 'Minute';

  @override
  String get calendarPasteTaskHere => 'Aufgabe hier einfügen';

  @override
  String get calendarQuickAddTask => 'Schnell Aufgabe hinzufügen';

  @override
  String get calendarSplitTaskAt => 'Aufgabe teilen bei';

  @override
  String get calendarAddDayEvent => 'Tagesereignis hinzufügen';

  @override
  String get calendarZoomOut => 'Verkleinern (Strg/Cmd + -)';

  @override
  String get calendarZoomIn => 'Vergrößern (Strg/Cmd + +)';

  @override
  String get calendarChecklistItem => 'Checklistenpunkt';

  @override
  String get calendarRemoveItem => 'Eintrag entfernen';

  @override
  String get calendarAddChecklistItem => 'Checklistenpunkt hinzufügen';

  @override
  String get calendarRepeatTimes => 'Wiederholungen';

  @override
  String get calendarDayEventHint => 'Geburtstag, Feiertag oder Notiz';

  @override
  String get calendarOptionalDetails => 'Optionale Details';

  @override
  String get calendarDates => 'Termine';

  @override
  String get calendarTaskTitleHint => 'Aufgabentitel';

  @override
  String get calendarDescriptionOptionalHint => 'Beschreibung (optional)';

  @override
  String get calendarLocationOptionalHint => 'Ort (optional)';

  @override
  String get calendarCloseTooltip => 'Schließen';

  @override
  String get calendarAddTaskInputHint =>
      'Aufgabe hinzufügen... (z.B. \"Meeting morgen um 15 Uhr\")';

  @override
  String get calendarBranch => 'Zweig';

  @override
  String get calendarPickDifferentTask =>
      'Andere Aufgabe für diesen Slot wählen';

  @override
  String get calendarSyncRequest => 'Abrufen';

  @override
  String get calendarSyncPush => 'Senden';

  @override
  String get calendarImportant => 'Wichtig';

  @override
  String get calendarUrgent => 'Dringend';

  @override
  String get calendarClearSchedule => 'Zeitplan löschen';

  @override
  String get calendarEditTaskTooltip => 'Aufgabe bearbeiten';

  @override
  String get calendarDeleteTaskTooltip => 'Aufgabe löschen';

  @override
  String get calendarBackToChats => 'Zurück zu Chats';

  @override
  String get calendarBackToLogin => 'Zurück zur Anmeldung';

  @override
  String get calendarRemindersSection => 'Erinnerungen';

  @override
  String get settingsAutoLoadEmailImages => 'E-Mail-Bilder automatisch laden';

  @override
  String get settingsAutoLoadEmailImagesDescription =>
      'Kann Ihre IP-Adresse an Absender preisgeben';

  @override
  String get settingsAutoDownloadImages => 'Auto-download images';

  @override
  String get settingsAutoDownloadImagesDescription => 'Only for trusted chats.';

  @override
  String get settingsAutoDownloadVideos => 'Auto-download videos';

  @override
  String get settingsAutoDownloadVideosDescription => 'Only for trusted chats.';

  @override
  String get settingsAutoDownloadDocuments => 'Auto-download documents';

  @override
  String get settingsAutoDownloadDocumentsDescription =>
      'Only for trusted chats.';

  @override
  String get settingsAutoDownloadArchives => 'Auto-download archives';

  @override
  String get settingsAutoDownloadArchivesDescription =>
      'Only for trusted chats.';

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
  String get emailContactsImportUnsupportedFile => 'Unsupported file type.';

  @override
  String get emailContactsImportNoContacts => 'No contacts found in that file.';

  @override
  String get emailContactsImportFailed => 'Import failed.';

  @override
  String emailContactsImportSuccess(
      Object imported, Object duplicates, Object invalid, Object failed) {
    return 'Imported $imported contacts. $duplicates duplicates, $invalid invalid, $failed failed.';
  }

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
  String get chatChooseTextToAdd => 'Text zum Hinzufügen auswählen';

  @override
  String get notificationChannelMessages => 'Nachrichten';

  @override
  String get notificationNewMessageTitle => 'Neue Nachricht';

  @override
  String get notificationOpenAction => 'Benachrichtigung öffnen';

  @override
  String get notificationBackgroundConnectionDisabledTitle =>
      'Hintergrundverbindung deaktiviert';

  @override
  String get notificationBackgroundConnectionDisabledBody =>
      'Android hat den Nachrichtendienst von Axichat blockiert. Aktiviere Overlay- und Akku-Optimierungsberechtigungen erneut, um Hintergrundnachrichten wiederherzustellen.';

  @override
  String get calendarReminderDeadlineNow => 'Frist jetzt';

  @override
  String calendarReminderDueIn(Object duration) {
    return 'Fällig in $duration';
  }

  @override
  String get calendarReminderStartingNow => 'Startet jetzt';

  @override
  String calendarReminderStartsIn(Object duration) {
    return 'Startet in $duration';
  }

  @override
  String get calendarReminderHappeningToday => 'Findet heute statt';

  @override
  String calendarReminderIn(Object duration) {
    return 'In $duration';
  }

  @override
  String calendarReminderDurationDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# Tage',
      one: '# Tag',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderDurationHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# Stunden',
      one: '# Stunde',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderDurationMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# Minuten',
      one: '# Minute',
    );
    return '$_temp0';
  }

  @override
  String get calendarExportCalendar => 'Kalender exportieren';

  @override
  String get calendarImportCalendar => 'Kalender importieren';

  @override
  String get calendarSyncStatusSyncing => 'Synchronisiere...';

  @override
  String get calendarSyncStatusFailed => 'Synchronisierung fehlgeschlagen';

  @override
  String get calendarSyncStatusSynced => 'Synchronisiert';

  @override
  String get calendarSyncStatusIdle => 'Noch nicht synchronisiert';

  @override
  String calendarSplitTaskAtTime(Object time) {
    return 'Aufgabe teilen um $time';
  }

  @override
  String get calendarSplitSelectTime => 'Teilzeit auswählen';

  @override
  String get calendarTaskMarkIncomplete => 'Als unvollständig markieren';

  @override
  String get calendarTaskMarkComplete => 'Als abgeschlossen markieren';

  @override
  String get calendarTaskRemoveImportant => 'Wichtig-Markierung entfernen';

  @override
  String get calendarTaskMarkImportant => 'Als wichtig markieren';

  @override
  String get calendarTaskRemoveUrgent => 'Dringend-Markierung entfernen';

  @override
  String get calendarTaskMarkUrgent => 'Als dringend markieren';

  @override
  String get calendarDeselectTask => 'Aufgabe abwählen';

  @override
  String get calendarAddTaskToSelection => 'Aufgabe zur Auswahl hinzufügen';

  @override
  String get calendarSelectTask => 'Aufgabe auswählen';

  @override
  String get calendarDeselectAllRepeats => 'Alle Wiederholungen abwählen';

  @override
  String get calendarAddAllRepeats => 'Alle Wiederholungen hinzufügen';

  @override
  String get calendarSelectAllRepeats => 'Alle Wiederholungen auswählen';

  @override
  String get calendarAddToSelection => 'Zur Auswahl hinzufügen';

  @override
  String get calendarSelectAllTasks => 'Alle Aufgaben auswählen';

  @override
  String get calendarExitSelectionMode => 'Auswahlmodus beenden';

  @override
  String get calendarSplitTask => 'Aufgabe teilen';

  @override
  String get calendarCopyTemplate => 'Vorlage kopieren';

  @override
  String calendarTaskAddedMessage(Object title) {
    return 'Aufgabe \"$title\" hinzugefügt';
  }

  @override
  String calendarTasksAddedMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# Aufgaben hinzugefügt',
      one: '# Aufgabe hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String calendarTaskRemovedMessage(Object title) {
    return 'Aufgabe \"$title\" entfernt';
  }

  @override
  String calendarTasksRemovedMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# Aufgaben entfernt',
      one: '# Aufgabe entfernt',
    );
    return '$_temp0';
  }

  @override
  String get calendarTaskRemovedTitle => 'Aufgabe entfernt';

  @override
  String get calendarDeadlinePlaceholder => 'Frist festlegen (optional)';

  @override
  String get calendarTaskDescriptionHint => 'Beschreibung (optional)';

  @override
  String get calendarTaskLocationHint => 'Ort (optional)';

  @override
  String get calendarPickDateLabel => 'Datum auswählen';

  @override
  String get calendarPickTimeLabel => 'Uhrzeit auswählen';

  @override
  String get calendarReminderLabel => 'Erinnerung';

  @override
  String get calendarEditDayEventTitle => 'Tagesereignis bearbeiten';

  @override
  String get calendarNewDayEventTitle => 'Neues Tagesereignis';

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String get commonTitle => 'Titel';

  @override
  String get calendarShareUnavailable =>
      'Kalenderfreigabe ist nicht verfügbar.';

  @override
  String get calendarShareAvailability => 'Verfügbarkeit teilen';

  @override
  String get calendarShortcutUndo => 'Strg/Cmd+Z';

  @override
  String get calendarShortcutRedo => 'Strg/Cmd+Shift+Z';

  @override
  String commonShortcutTooltip(Object tooltip, Object shortcut) {
    return '$tooltip ($shortcut)';
  }

  @override
  String get calendarDragCanceled => 'Ziehen abgebrochen';

  @override
  String get calendarZoomLabelCompact => 'Kompakt';

  @override
  String get calendarZoomLabelComfort => 'Komfort';

  @override
  String get calendarZoomLabelExpanded => 'Erweitert';

  @override
  String calendarZoomLabelMinutes(Object minutes) {
    return '${minutes}m';
  }

  @override
  String get calendarGuestModeNotice =>
      'Gastmodus – Aufgaben werden nur lokal auf diesem Gerät gespeichert';

  @override
  String get calendarGuestSignUpToSync => 'Zum Synchronisieren registrieren';

  @override
  String get calendarGuestExportNoData =>
      'Keine Kalenderdaten zum Export verfügbar.';

  @override
  String get calendarGuestExportTitle => 'Gastkalender exportieren';

  @override
  String get calendarGuestExportShareSubject => 'Axichat-Gastkalender-Export';

  @override
  String calendarGuestExportShareText(Object format) {
    return 'Axichat-Gastkalender-Export ($format)';
  }

  @override
  String calendarGuestExportFailed(Object error) {
    return 'Kalenderexport fehlgeschlagen: $error';
  }

  @override
  String get calendarGuestImportTitle => 'Kalender importieren';

  @override
  String get calendarGuestImportWarningMessage =>
      'Der Import führt Daten zusammen und überschreibt passende Einträge in deinem aktuellen Kalender. Fortfahren?';

  @override
  String get calendarGuestImportConfirmLabel => 'Importieren';

  @override
  String get calendarGuestImportFileAccessError =>
      'Ausgewählte Datei kann nicht geöffnet werden.';

  @override
  String get calendarGuestImportNoData =>
      'Keine Kalenderdaten in der ausgewählten Datei gefunden.';

  @override
  String get calendarGuestImportFailed =>
      'Import konnte Änderungen nicht anwenden.';

  @override
  String get calendarGuestImportSuccess => 'Kalenderdaten importiert.';

  @override
  String get calendarGuestImportNoTasks =>
      'Keine Aufgaben in der ausgewählten Datei gefunden.';

  @override
  String calendarGuestImportTasksSuccess(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# Aufgaben',
      one: '# Aufgabe',
    );
    return 'Importiert: $_temp0.';
  }

  @override
  String calendarGuestImportError(Object error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String get blocklistEmpty => 'Niemand blockiert';

  @override
  String get chatMessageSubjectLabel => 'Betreff';

  @override
  String get chatMessageRecipientsLabel => 'Empfänger';

  @override
  String get chatMessageAlsoSentToLabel => 'Außerdem gesendet an';

  @override
  String chatMessageFromLabel(Object sender) {
    return 'Von $sender';
  }

  @override
  String get chatMessageReactionsLabel => 'Reaktionen';

  @override
  String get commonClearSelection => 'Auswahl löschen';

  @override
  String commonSelectedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# ausgewählt',
      one: '# ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get profileDeviceFingerprint => 'Geräte-Fingerabdruck';

  @override
  String get profileFingerprintUnavailable => 'Fingerabdruck nicht verfügbar';

  @override
  String get axiVersionCurrentFeatures => 'Aktuelle Funktionen:';

  @override
  String get axiVersionCurrentFeaturesList => 'Nachrichten, Präsenz';

  @override
  String get axiVersionComingNext => 'Als Nächstes:';

  @override
  String get axiVersionComingNextList => 'Gruppenchat, Multimedia';

  @override
  String get commonMoreOptions => 'Weitere Optionen';

  @override
  String get commonAreYouSure => 'Bist du sicher?';

  @override
  String get commonAll => 'Alle';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageSpanish => 'Spanisch';

  @override
  String get languageFrench => 'Französisch';

  @override
  String get languageChineseSimplified => 'Chinesisch (vereinfacht)';

  @override
  String get languageChineseHongKong => 'Chinesisch (Hongkong)';

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
      'Keine Kalenderdaten zum Exportieren verfügbar.';

  @override
  String get calendarTransferExportSubject => 'Axichat-Kalenderexport';

  @override
  String calendarTransferExportText(String format) {
    return 'Axichat-Kalenderexport ($format)';
  }

  @override
  String get calendarTransferExportReady => 'Export bereit zum Teilen.';

  @override
  String calendarTransferExportFailed(String error) {
    return 'Kalenderexport fehlgeschlagen: $error';
  }

  @override
  String get calendarTransferImportWarning =>
      'Beim Import werden Daten zusammengeführt und übereinstimmende Einträge in deinem aktuellen Kalender überschrieben. Fortfahren?';

  @override
  String get calendarTransferImportConfirm => 'Importieren';

  @override
  String get calendarTransferFileAccessFailed =>
      'Zugriff auf die ausgewählte Datei nicht möglich.';

  @override
  String get calendarTransferNoDataImport =>
      'Keine Kalenderdaten in der ausgewählten Datei gefunden.';

  @override
  String get calendarTransferImportFailed =>
      'Import konnte nicht angewendet werden.';

  @override
  String get calendarTransferImportSuccess => 'Kalenderdaten importiert.';

  @override
  String get calendarTransferNoTasksDetected =>
      'Keine Aufgaben in der ausgewählten Datei gefunden.';

  @override
  String calendarTransferImportTasksSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'n',
      one: '',
    );
    return 'Importiert $count Aufgabe$_temp0.';
  }

  @override
  String calendarTransferImportFailedWithError(String error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String get calendarExportChooseFormat => 'Exportformat wählen';

  @override
  String get calendarAvailabilityWindowsTitle => 'Verfügbarkeitsfenster';

  @override
  String get calendarAvailabilityWindowsSubtitle =>
      'Definiere die Zeitbereiche, die du teilen möchtest.';

  @override
  String get calendarAvailabilityWindowsLabel => 'Fenster';

  @override
  String get calendarAvailabilityNoWindows => 'Noch keine Fenster.';

  @override
  String get calendarAvailabilityWindowLabel => 'Fenster';

  @override
  String get calendarAvailabilitySummaryLabel => 'Zusammenfassung';

  @override
  String get calendarAvailabilitySummaryHint => 'Optionale Bezeichnung';

  @override
  String get calendarAvailabilityNotesLabel => 'Notizen';

  @override
  String get calendarAvailabilityNotesHint => 'Optionale Details';

  @override
  String get calendarAvailabilityAddWindow => 'Fenster hinzufügen';

  @override
  String get calendarAvailabilitySaveWindows => 'Fenster speichern';

  @override
  String get calendarAvailabilityEmptyWindowsError =>
      'Füge mindestens ein Verfügbarkeitsfenster hinzu.';

  @override
  String get calendarAvailabilityInvalidRangeError =>
      'Prüfe die Fensterbereiche vor dem Speichern.';

  @override
  String get calendarTaskShareTitle => 'Aufgabe teilen';

  @override
  String get calendarTaskShareSubtitle =>
      'Sende eine Aufgabe als .ics an einen Chat.';

  @override
  String get calendarTaskShareTarget => 'Teilen mit';

  @override
  String get calendarTaskShareEditAccess => 'Bearbeitungszugriff';

  @override
  String get calendarTaskShareReadOnlyLabel => 'Nur lesen';

  @override
  String get calendarTaskShareReadOnlyHint =>
      'Empfänger können diese Aufgabe ansehen, aber nur du kannst sie bearbeiten.';

  @override
  String get calendarTaskShareEditableHint =>
      'Empfänger können diese Aufgabe bearbeiten, und Aktualisierungen werden mit deinem Kalender synchronisiert.';

  @override
  String get calendarTaskShareReadOnlyDisabledHint =>
      'Bearbeiten ist nur für Chat-Kalender verfügbar.';

  @override
  String get calendarTaskShareMissingChats => 'Keine Chats verfügbar.';

  @override
  String get calendarTaskShareMissingRecipient =>
      'Wähle einen Chat zum Teilen aus.';

  @override
  String get calendarTaskShareServiceUnavailable =>
      'Kalenderfreigabe ist nicht verfügbar.';

  @override
  String get calendarTaskShareDenied =>
      'Kalenderkarten sind für deine Rolle in diesem Raum deaktiviert.';

  @override
  String get calendarTaskShareSendFailed =>
      'Aufgabe konnte nicht geteilt werden.';

  @override
  String get calendarTaskShareSuccess => 'Aufgabe geteilt.';

  @override
  String get commonTimeJustNow => 'Gerade eben';

  @override
  String commonTimeMinutesAgo(int count) {
    return 'vor $count Min.';
  }

  @override
  String commonTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'n',
      one: '',
    );
    return 'vor $count Stunde$_temp0';
  }

  @override
  String commonTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'en',
      one: '',
    );
    return 'vor $count Tag$_temp0';
  }

  @override
  String commonTimeWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'n',
      one: '',
    );
    return 'vor $count Woche$_temp0';
  }

  @override
  String get commonTimeMonthsAgo => 'Vor Monaten';

  @override
  String get connectivityStatusConnected => 'Verbunden';

  @override
  String get connectivityStatusConnecting => 'Verbinden...';

  @override
  String get connectivityStatusNotConnected => 'Nicht verbunden.';

  @override
  String get connectivityStatusFailed => 'Verbindung fehlgeschlagen.';

  @override
  String get commonShare => 'Teilen';

  @override
  String get commonRecipients => 'Empfänger';

  @override
  String commonRangeLabel(String start, String end) {
    return '$start - $end';
  }

  @override
  String get commonOwnerFallback => 'Besitzer';

  @override
  String commonDurationMinutes(int count) {
    return '$count Min.';
  }

  @override
  String commonDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'n',
      one: '',
    );
    return '$count Stunde$_temp0';
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
  String get calendarAvailabilityShareTitle => 'Verfügbarkeit teilen';

  @override
  String get calendarAvailabilityShareSubtitle =>
      'Wähle einen Zeitraum, bearbeite frei/beschäftigt und teile ihn dann.';

  @override
  String get calendarAvailabilityShareChatSubtitle =>
      'Wähle einen Zeitraum, bearbeite frei/beschäftigt und teile ihn in diesem Chat.';

  @override
  String get calendarAvailabilityShareRangeLabel => 'Zeitraum';

  @override
  String get calendarAvailabilityShareEditHint =>
      'Tippen zum Teilen, ziehen zum Anpassen oder frei/beschäftigt umschalten.';

  @override
  String get calendarAvailabilityShareSavePreset => 'Als Vorgabe speichern';

  @override
  String get calendarAvailabilitySharePresetNameTitle =>
      'Frei/Belegt-Blatt speichern';

  @override
  String get calendarAvailabilitySharePresetNameLabel => 'Name';

  @override
  String get calendarAvailabilitySharePresetNameHint => 'Teamzeiten';

  @override
  String get calendarAvailabilitySharePresetNameMissing =>
      'Gib einen Namen ein, um dieses Blatt zu speichern.';

  @override
  String get calendarAvailabilityShareInvalidRange =>
      'Wähle einen gültigen Zeitraum zum Teilen.';

  @override
  String get calendarAvailabilityShareMissingJid =>
      'Kalenderfreigabe ist nicht verfügbar.';

  @override
  String get calendarAvailabilityShareRecipientsRequired =>
      'Wähle mindestens einen Empfänger aus.';

  @override
  String get calendarAvailabilityShareMissingChats =>
      'Keine geeigneten Chats verfügbar.';

  @override
  String get calendarAvailabilityShareLockedChatUnavailable =>
      'Dieser Chat kann keine Verfügbarkeiten empfangen.';

  @override
  String get calendarAvailabilityShareSuccess => 'Verfügbarkeit geteilt.';

  @override
  String get calendarAvailabilityShareFailed =>
      'Verfügbarkeit konnte nicht geteilt werden.';

  @override
  String get calendarAvailabilitySharePartialFailure =>
      'Einige Freigaben konnten nicht gesendet werden.';

  @override
  String get calendarAvailabilitySharePresetLabel => 'Neueste Blätter';

  @override
  String get calendarAvailabilitySharePresetEmpty =>
      'Noch keine aktuellen Blätter.';

  @override
  String calendarAvailabilityShareRecentPreset(String range) {
    return 'Geteilt $range';
  }

  @override
  String get calendarAvailabilityPreviewEmpty =>
      'Keine Verfügbarkeitsintervalle.';

  @override
  String calendarAvailabilityPreviewMore(int count) {
    return 'und $count weitere';
  }

  @override
  String get calendarTaskTitleRequired =>
      'Gib einen Aufgabentitel ein, bevor du fortfährst.';

  @override
  String calendarTaskTitleTooLong(int max) {
    return 'Der Aufgabentitel ist zu lang. Bitte verwende weniger als $max Zeichen.';
  }

  @override
  String calendarTaskTitleLimitWarning(int max) {
    return 'Aufgabentitel sind auf $max Zeichen begrenzt. Kürze diesen Text oder verschiebe Details vor dem Speichern in die Beschreibung.';
  }

  @override
  String calendarTaskTitleCharacterCount(int count, int limit) {
    return '$count / $limit Zeichen';
  }

  @override
  String get axiVersionWelcomeTitle => 'Willkommen bei Axichat';

  @override
  String axiVersionLabel(String version) {
    return 'v$version';
  }

  @override
  String get axiVersionTagAlpha => 'alpha';

  @override
  String get calendarSyncWarningSnapshotTitle => 'Kalendersynchronisierung';

  @override
  String get calendarSyncWarningSnapshotMessage =>
      'Kalender-Schnappschuss nicht verfugbar. Exportiere dein Kalender-JSON von einem anderen Gerat und importiere es hier zur Wiederherstellung.';

  @override
  String commonLabelValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String get calendarAvailabilityRequestTitle => 'Zeit anfragen';

  @override
  String get calendarAvailabilityRequestSubtitle =>
      'Wähle einen freien Slot und teile Details.';

  @override
  String get calendarAvailabilityRequestDetailsLabel => 'Details';

  @override
  String get calendarAvailabilityRequestRangeLabel => 'Zeitraum';

  @override
  String get calendarAvailabilityRequestTitleLabel => 'Titel';

  @override
  String get calendarAvailabilityRequestTitlePlaceholder => 'Worum geht es?';

  @override
  String get calendarAvailabilityRequestDescriptionLabel => 'Beschreibung';

  @override
  String get calendarAvailabilityRequestDescriptionPlaceholder =>
      'Kontext hinzufügen (optional).';

  @override
  String get calendarAvailabilityRequestSendLabel => 'Anfrage senden';

  @override
  String get calendarAvailabilityRequestInvalidRange =>
      'Wähle einen gültigen Zeitraum.';

  @override
  String get calendarAvailabilityRequestNotFree =>
      'Wähle vor dem Senden einen freien Slot aus.';

  @override
  String get calendarAvailabilityDecisionTitle => 'Anfrage annehmen';

  @override
  String get calendarAvailabilityDecisionSubtitle =>
      'Wähle aus, welche Kalender es erhalten sollen.';

  @override
  String get calendarAvailabilityDecisionPersonalLabel =>
      'Zum persönlichen Kalender hinzufügen';

  @override
  String get calendarAvailabilityDecisionChatLabel =>
      'Zum Chat-Kalender hinzufügen';

  @override
  String get calendarAvailabilityDecisionMissingSelection =>
      'Wähle mindestens einen Kalender aus.';

  @override
  String get calendarAvailabilityDecisionSummaryLabel => 'Angefragt';

  @override
  String get calendarAvailabilityRequestTitleFallback => 'Angefragte Zeit';

  @override
  String get calendarFreeBusyFree => 'Frei';

  @override
  String get calendarFreeBusyBusy => 'Belegt';

  @override
  String get calendarFreeBusyTentative => 'Vorläufig';

  @override
  String get calendarFreeBusyEditTitle => 'Verfugbarkeit bearbeiten';

  @override
  String get calendarFreeBusyEditSubtitle => 'Passe Zeitraum und Status an.';

  @override
  String get calendarFreeBusyToggleLabel => 'Frei/Belegt';

  @override
  String get calendarFreeBusySplitLabel => 'Teilen';

  @override
  String get calendarFreeBusySplitTooltip => 'Segment teilen';

  @override
  String get calendarFreeBusyMarkFree => 'Als frei markieren';

  @override
  String get calendarFreeBusyMarkBusy => 'Als belegt markieren';

  @override
  String get calendarFreeBusyRangeLabel => 'Zeitraum';

  @override
  String commonWeekdayDayLabel(String weekday, int day) {
    return '$weekday $day';
  }

  @override
  String get calendarFragmentChecklistLabel => 'Checkliste';

  @override
  String get calendarFragmentChecklistSeparator => ', ';

  @override
  String calendarFragmentChecklistSummary(String summary) {
    return 'Checkliste: $summary';
  }

  @override
  String calendarFragmentChecklistSummaryMore(String summary, int count) {
    return 'Checkliste: $summary und $count weitere';
  }

  @override
  String get calendarFragmentRemindersLabel => 'Erinnerungen';

  @override
  String calendarFragmentReminderStartSummary(String summary) {
    return 'Start: $summary';
  }

  @override
  String calendarFragmentReminderDeadlineSummary(String summary) {
    return 'Frist: $summary';
  }

  @override
  String calendarFragmentRemindersSummary(String summary) {
    return 'Erinnerungen: $summary';
  }

  @override
  String get calendarFragmentReminderSeparator => ', ';

  @override
  String get calendarFragmentEventTitleFallback => 'Ereignis ohne Titel';

  @override
  String calendarFragmentDayEventSummary(String title, String range) {
    return '$title (Tagesereignis: $range)';
  }

  @override
  String calendarFragmentFreeBusySummary(String label, String range) {
    return '$label (Fenster: $range)';
  }

  @override
  String get calendarFragmentCriticalPathLabel => 'Kritischer Pfad';

  @override
  String calendarFragmentCriticalPathSummary(String name) {
    return 'Kritischer Pfad: $name';
  }

  @override
  String calendarFragmentCriticalPathProgress(int completed, int total) {
    return '$completed/$total erledigt';
  }

  @override
  String calendarFragmentCriticalPathDetail(String name, String progress) {
    return '$name (Kritischer Pfad: $progress)';
  }

  @override
  String calendarFragmentAvailabilitySummary(String summary, String range) {
    return '$summary (Verfugbarkeit: $range)';
  }

  @override
  String calendarFragmentAvailabilityFallback(String range) {
    return 'Verfugbarkeit: $range';
  }

  @override
  String calendarMonthOverflowMore(int count) {
    return '+$count mehr';
  }

  @override
  String commonPercentLabel(int value) {
    return '$value%';
  }

  @override
  String get commonStart => 'Start';

  @override
  String get commonEnd => 'Ende';

  @override
  String get commonSelectStart => 'Start auswahlen';

  @override
  String get commonSelectEnd => 'Ende auswahlen';

  @override
  String get commonTimeLabel => 'Zeit';

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
    return '$head und $tail';
  }

  @override
  String get calendarAlarmsTitle => 'Alarme';

  @override
  String get calendarAlarmsHelper =>
      'Erinnerungen werden als Anzeigealarme exportiert.';

  @override
  String get calendarAlarmsEmpty => 'Noch keine Alarme';

  @override
  String get calendarAlarmAddTooltip => 'Alarm hinzufügen';

  @override
  String get calendarAlarmRemoveTooltip => 'Alarm entfernen';

  @override
  String calendarAlarmItemLabel(int index) {
    return 'Alarm $index';
  }

  @override
  String get calendarAlarmActionLabel => 'Aktion';

  @override
  String get calendarAlarmActionDisplay => 'Anzeige';

  @override
  String get calendarAlarmActionAudio => 'Audio';

  @override
  String get calendarAlarmActionEmail => 'E-Mail';

  @override
  String get calendarAlarmActionProcedure => 'Prozedur';

  @override
  String get calendarAlarmActionProcedureHelper =>
      'Prozeduralarme werden schreibgeschützt importiert.';

  @override
  String get calendarAlarmTriggerLabel => 'Auslöser';

  @override
  String get calendarAlarmTriggerRelative => 'Relativ';

  @override
  String get calendarAlarmTriggerAbsolute => 'Absolut';

  @override
  String get calendarAlarmAbsolutePlaceholder => 'Datum und Uhrzeit auswählen';

  @override
  String get calendarAlarmRelativeToLabel => 'Bezogen auf';

  @override
  String get calendarAlarmRelativeToStart => 'Start';

  @override
  String get calendarAlarmRelativeToEnd => 'Ende';

  @override
  String get calendarAlarmDirectionLabel => 'Richtung';

  @override
  String get calendarAlarmDirectionBefore => 'Vor';

  @override
  String get calendarAlarmDirectionAfter => 'Nach';

  @override
  String get calendarAlarmOffsetLabel => 'Versatz';

  @override
  String get calendarAlarmOffsetHint => 'Menge';

  @override
  String get calendarAlarmRepeatLabel => 'Wiederholen';

  @override
  String get calendarAlarmRepeatCountHint => 'Mal';

  @override
  String get calendarAlarmRepeatEveryLabel => 'Alle';

  @override
  String get calendarAlarmRecipientsLabel => 'Empfänger';

  @override
  String get calendarAlarmRecipientAddressHint => 'E-Mail hinzufügen';

  @override
  String get calendarAlarmRecipientNameHint => 'Name (optional)';

  @override
  String get calendarAlarmRecipientRemoveTooltip => 'Empfänger entfernen';

  @override
  String calendarAlarmRecipientDisplay(String name, String address) {
    return '$name <$address>';
  }

  @override
  String get calendarAlarmAcknowledgedLabel => 'Bestätigt';

  @override
  String get calendarAlarmUnitMinutes => 'Minuten';

  @override
  String get calendarAlarmUnitHours => 'Stunden';

  @override
  String get calendarAlarmUnitDays => 'Tage';

  @override
  String get calendarAlarmUnitWeeks => 'Wochen';

  @override
  String get taskShareTitleFallback => 'Unbenannte Aufgabe';

  @override
  String taskShareTitleLabel(String title) {
    return 'Aufgabe \"$title\"';
  }

  @override
  String taskShareTitleWithQualifiers(String title, String qualifiers) {
    return 'Aufgabe \"$title\" ($qualifiers)';
  }

  @override
  String get taskShareQualifierDone => 'erledigt';

  @override
  String get taskSharePriorityImportant => 'wichtig';

  @override
  String get taskSharePriorityUrgent => 'dringend';

  @override
  String get taskSharePriorityCritical => 'kritisch';

  @override
  String taskShareLocationClause(String location) {
    return ' in $location';
  }

  @override
  String get taskShareScheduleNoTime => ' ohne feste Zeit';

  @override
  String taskShareScheduleSameDay(
      String date, String startTime, String endTime) {
    return ' am $date von $startTime bis $endTime';
  }

  @override
  String taskShareScheduleRange(String startDateTime, String endDateTime) {
    return ' von $startDateTime bis $endDateTime';
  }

  @override
  String taskShareScheduleStartDuration(
      String date, String time, String duration) {
    return ' am $date um $time für $duration';
  }

  @override
  String taskShareScheduleStart(String date, String time) {
    return ' am $date um $time';
  }

  @override
  String taskShareScheduleEnding(String dateTime) {
    return ' endet $dateTime';
  }

  @override
  String get taskShareRecurrenceEveryOtherDay => ' jeden zweiten Tag';

  @override
  String taskShareRecurrenceEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: 'Tag',
    );
    return ' jeden $_temp0';
  }

  @override
  String taskShareRecurrenceEveryWeekdays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wochentage',
      one: 'Wochentag',
    );
    return ' jeden $_temp0';
  }

  @override
  String taskShareRecurrenceEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wochen',
      one: 'Woche',
    );
    return ' jede $_temp0';
  }

  @override
  String taskShareRecurrenceEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Monate',
      one: 'Monat',
    );
    return ' jeden $_temp0';
  }

  @override
  String get taskShareRecurrenceEveryOtherYear => ' jedes zweite Jahr';

  @override
  String taskShareRecurrenceEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Jahre',
      one: 'Jahr',
    );
    return ' jedes $_temp0';
  }

  @override
  String taskShareRecurrenceOnDays(String days) {
    return ' am $days';
  }

  @override
  String taskShareRecurrenceUntil(String date) {
    return ' bis $date';
  }

  @override
  String taskShareRecurrenceCount(int count) {
    return ' für $count Vorkommnisse';
  }

  @override
  String taskShareDeadlineClause(String dateTime) {
    return ', fällig bis $dateTime';
  }

  @override
  String taskShareNotesClause(String notes) {
    return ' Notizen: $notes.';
  }

  @override
  String taskShareChangesClause(String changes) {
    return ' Änderungen: $changes';
  }

  @override
  String taskShareOverrideMoveTo(String dateTime) {
    return 'verschieben nach $dateTime';
  }

  @override
  String taskShareOverrideDuration(String duration) {
    return 'für $duration';
  }

  @override
  String taskShareOverrideEndAt(String dateTime) {
    return 'endet um $dateTime';
  }

  @override
  String taskShareOverridePriority(String priority) {
    return 'Priorität $priority';
  }

  @override
  String get taskShareOverrideCancelled => 'abgesagt';

  @override
  String get taskShareOverrideDone => 'erledigt';

  @override
  String taskShareOverrideRenameTo(String title) {
    return 'umbenennen in \"$title\"';
  }

  @override
  String taskShareOverrideNotes(String notes) {
    return 'Notizen \"$notes\"';
  }

  @override
  String taskShareOverrideLocation(String location) {
    return 'Ort \"$location\"';
  }

  @override
  String get taskShareOverrideNoChanges => 'keine Änderungen';

  @override
  String taskShareOverrideSegment(String dateTime, String actions) {
    return 'Am $dateTime: $actions';
  }

  @override
  String get calendarTaskCopiedToClipboard =>
      'Aufgabe in die Zwischenablage kopiert';

  @override
  String get calendarTaskSplitRequiresSchedule =>
      'Aufgabe muss geplant sein, um geteilt zu werden.';

  @override
  String get calendarTaskSplitTooShort => 'Aufgabe ist zu kurz zum Teilen.';

  @override
  String get calendarTaskSplitUnable =>
      'Aufgabe kann zu diesem Zeitpunkt nicht geteilt werden.';

  @override
  String get calendarDayEventsLabel => 'Tagesereignisse';

  @override
  String get calendarShareAsIcsAction => 'Als .ics teilen';

  @override
  String get calendarCompletedLabel => 'Abgeschlossen';

  @override
  String get calendarDeadlineDueToday => 'Fallig heute';

  @override
  String get calendarDeadlineDueTomorrow => 'Fallig morgen';

  @override
  String get calendarExportTasksFilePrefix => 'axichat_aufgaben';

  @override
  String get chatTaskViewTitle => 'Aufgabendetails';

  @override
  String get chatTaskViewSubtitle => 'Schreibgeschutzte Aufgabe.';

  @override
  String get chatTaskViewPreviewLabel => 'Vorschau';

  @override
  String get chatTaskViewActionsLabel => 'Aufgabenaktionen';

  @override
  String get chatTaskViewCopyLabel => 'In den Kalender kopieren';

  @override
  String get chatTaskCopyTitle => 'Aufgabe kopieren';

  @override
  String get chatTaskCopySubtitle =>
      'Wahle aus, welche Kalender sie erhalten sollen.';

  @override
  String get chatTaskCopyPreviewLabel => 'Vorschau';

  @override
  String get chatTaskCopyCalendarsLabel => 'Kalender';

  @override
  String get chatTaskCopyPersonalLabel =>
      'Zum personlichen Kalender hinzufugen';

  @override
  String get chatTaskCopyChatLabel => 'Zum Chat-Kalender hinzufugen';

  @override
  String get chatTaskCopyConfirmLabel => 'Kopieren';

  @override
  String get chatTaskCopyMissingSelectionMessage =>
      'Wahle mindestens einen Kalender aus.';

  @override
  String get chatCriticalPathCopyTitle => 'Kritischen Pfad kopieren';

  @override
  String get chatCriticalPathCopySubtitle =>
      'Wahle aus, welche Kalender ihn erhalten sollen.';

  @override
  String get chatCriticalPathCopyPreviewLabel => 'Vorschau';

  @override
  String get chatCriticalPathCopyCalendarsLabel => 'Kalender';

  @override
  String get chatCriticalPathCopyPersonalLabel =>
      'Zum personlichen Kalender hinzufugen';

  @override
  String get chatCriticalPathCopyChatLabel => 'Zum Chat-Kalender hinzufugen';

  @override
  String get chatCriticalPathCopyConfirmLabel => 'Kopieren';

  @override
  String get chatCriticalPathCopyMissingSelectionMessage =>
      'Wahle mindestens einen Kalender aus.';

  @override
  String get chatCriticalPathCopyUnavailableMessage =>
      'Kalender ist nicht verfugbar.';

  @override
  String get chatCriticalPathCopySuccessMessage => 'Kritischer Pfad kopiert.';

  @override
  String commonBulletLabel(String text) {
    return '• $text';
  }

  @override
  String get chatFilterTitle => 'Angezeigte Nachrichten';

  @override
  String get chatFilterDirectOnlyLabel => 'Nur direkt';

  @override
  String get chatFilterAllLabel => 'Alle';

  @override
  String get calendarFragmentTaskLabel => 'Aufgabe';

  @override
  String get calendarFragmentDayEventLabel => 'Ganztagstermin';

  @override
  String get calendarFragmentFreeBusyLabel => 'Frei/belegt';

  @override
  String get calendarFragmentAvailabilityLabel => 'Verfügbarkeit';

  @override
  String get calendarFragmentScheduledLabel => 'Geplant';

  @override
  String get calendarFragmentDueLabel => 'Fällig';

  @override
  String get calendarFragmentUntitledLabel => 'Unbenannt';

  @override
  String get calendarFragmentChecklistBullet => '- ';

  @override
  String commonAndMoreLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'und $count weitere',
      one: 'und 1 weitere',
    );
    return '$_temp0';
  }

  @override
  String get commonBulletSymbol => '• ';

  @override
  String get commonLabelSeparator => ': ';

  @override
  String get commonUnknownLabel => 'Unbekannt';

  @override
  String get commonBadgeOverflowLabel => '99+';

  @override
  String get commonEllipsis => '…';

  @override
  String get chatMessageDetailsSenderLabel => 'Absenderadresse';

  @override
  String get chatMessageDetailsMetadataLabel => 'Nachrichtenmetadaten';

  @override
  String get chatMessageDetailsHeadersLabel => 'Roh-Header';

  @override
  String get chatMessageDetailsHeadersActionLabel => 'Header anzeigen';

  @override
  String get chatMessageDetailsHeadersNote =>
      'Header werden aus der ursprunglichen RFC822-Nachricht geladen.';

  @override
  String get chatMessageDetailsHeadersLoadingLabel =>
      'Header werden geladen...';

  @override
  String get chatMessageDetailsHeadersUnavailableLabel =>
      'Header nicht verfugbar.';

  @override
  String get chatMessageDetailsStanzaIdLabel => 'Stanza-ID';

  @override
  String get chatMessageDetailsOriginIdLabel => 'Origin-ID';

  @override
  String get chatMessageDetailsOccupantIdLabel => 'Occupant-ID';

  @override
  String get chatMessageDetailsDeltaIdLabel => 'Delta-Nachrichten-ID';

  @override
  String get chatMessageDetailsLocalIdLabel => 'Lokale Nachrichten-ID';

  @override
  String get chatCalendarFragmentShareDeniedMessage =>
      'Kalenderkarten sind fur deine Rolle in diesem Raum deaktiviert.';

  @override
  String get chatAvailabilityRequestAccountMissingMessage =>
      'Verfugbarkeitsanfragen sind derzeit nicht verfugbar.';

  @override
  String get chatAvailabilityRequestEmailUnsupportedMessage =>
      'Verfugbarkeit ist fur E-Mail-Chats nicht verfugbar.';

  @override
  String get chatAvailabilityRequestInvalidRangeMessage =>
      'Der Zeitraum der Verfugbarkeitsanfrage ist ungultig.';

  @override
  String get chatAvailabilityRequestCalendarUnavailableMessage =>
      'Kalender ist nicht verfugbar.';

  @override
  String get chatAvailabilityRequestChatCalendarUnavailableMessage =>
      'Chat-Kalender ist nicht verfugbar.';

  @override
  String get chatAvailabilityRequestTaskTitleFallback => 'Angeforderte Zeit';

  @override
  String get chatSenderAddressPrefix => 'JID: ';

  @override
  String get chatRecipientVisibilityCcLabel => 'CC';

  @override
  String get chatRecipientVisibilityBccLabel => 'BCC';

  @override
  String get chatInviteRoomFallbackLabel => 'Gruppenchat';

  @override
  String get chatInviteBodyLabel =>
      'Du wurdest zu einem Gruppenchat eingeladen';

  @override
  String get chatInviteRevokedLabel => 'Einladung widerrufen';

  @override
  String chatInviteActionLabel(String roomName) {
    return 'Beitreten \'$roomName\'';
  }

  @override
  String get chatInviteActionFallbackLabel => 'Beitreten';

  @override
  String get chatInviteConfirmTitle => 'Einladung annehmen?';

  @override
  String chatInviteConfirmMessage(String roomName) {
    return 'Beitreten \'$roomName\'?';
  }

  @override
  String get chatInviteConfirmLabel => 'Annehmen';

  @override
  String get chatChooseTextToAddHint =>
      'Wahle einen Teil der Nachricht aus, um ihn an den Kalender zu senden, oder bearbeite ihn zuerst.';

  @override
  String get chatAttachmentAutoDownloadLabel =>
      'Anhange in diesem Chat automatisch herunterladen';

  @override
  String get chatAttachmentAutoDownloadHintOn =>
      'Anhange in diesem Chat werden automatisch heruntergeladen.';

  @override
  String get chatAttachmentAutoDownloadHintOff =>
      'Anhange werden blockiert, bis du sie bestatigst.';

  @override
  String chatAttachmentCaption(String filename, String size) {
    return '📎 $filename ($size)';
  }

  @override
  String get chatAttachmentFallbackLabel => 'Anhang';

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
      'Anhang uberschreitet das Serverlimit.';

  @override
  String chatAttachmentTooLargeMessage(String limit) {
    return 'Anhang uberschreitet das Serverlimit ($limit).';
  }

  @override
  String chatMessageErrorWithBody(String label, String body) {
    return '$label: \"$body\"';
  }

  @override
  String get messageErrorServiceUnavailableTooltip =>
      'Der Dienst meldete ein vorubergehendes Problem.';

  @override
  String get messageErrorServiceUnavailable => 'Dienst nicht verfugbar';

  @override
  String get messageErrorServerNotFound => 'Server nicht gefunden';

  @override
  String get messageErrorServerTimeout => 'Serverzeituberschreitung';

  @override
  String get messageErrorUnknown => 'Unbekannter Fehler';

  @override
  String get messageErrorNotEncryptedForDevice =>
      'Nicht fur dieses Gerat verschlusselt';

  @override
  String get messageErrorMalformedKey =>
      'Fehlerhafter Verschlusselungsschlussel';

  @override
  String get messageErrorUnknownSignedPrekey => 'Unbekannter signierter Prekey';

  @override
  String get messageErrorNoDeviceSession => 'Keine Geratesitzung';

  @override
  String get messageErrorSkippingTooManyKeys =>
      'Zu viele Schlussel ubersprungen';

  @override
  String get messageErrorInvalidHmac => 'Ungultiges HMAC';

  @override
  String get messageErrorMalformedCiphertext => 'Fehlerhafter Geheimtext';

  @override
  String get messageErrorNoKeyMaterial => 'Fehlendes Schlusselmaterial';

  @override
  String get messageErrorNoDecryptionKey =>
      'Fehlender Entschlusselungsschlussel';

  @override
  String get messageErrorInvalidKex => 'Ungultiger Schlusselaustausch';

  @override
  String get messageErrorUnknownOmemo => 'Unbekannter OMEMO-Fehler';

  @override
  String get messageErrorInvalidAffixElements => 'Ungultige Affix-Elemente';

  @override
  String get messageErrorEmptyDeviceList => 'Leere Gerateliste';

  @override
  String get messageErrorOmemoUnsupported => 'OMEMO nicht unterstutzt';

  @override
  String get messageErrorEncryptionFailure => 'Verschlusselung fehlgeschlagen';

  @override
  String get messageErrorInvalidEnvelope => 'Ungultiger Umschlag';

  @override
  String get messageErrorFileDownloadFailure => 'Dateidownload fehlgeschlagen';

  @override
  String get messageErrorFileUploadFailure => 'Dateiupload fehlgeschlagen';

  @override
  String get messageErrorFileDecryptionFailure =>
      'Dateientschlusselung fehlgeschlagen';

  @override
  String get messageErrorFileEncryptionFailure =>
      'Dateiverschlusselung fehlgeschlagen';

  @override
  String get messageErrorPlaintextFileInOmemo =>
      'Klartextdatei in OMEMO-Nachricht';

  @override
  String get messageErrorEmailSendFailure => 'E-Mail-Versand fehlgeschlagen';

  @override
  String get messageErrorEmailAttachmentTooLarge => 'E-Mail-Anhang zu gross';

  @override
  String get messageErrorEmailRecipientRejected => 'E-Mail-Empfanger abgelehnt';

  @override
  String get messageErrorEmailAuthenticationFailed =>
      'E-Mail-Authentifizierung fehlgeschlagen';

  @override
  String get messageErrorEmailBounced => 'E-Mail unzustellbar';

  @override
  String get messageErrorEmailThrottled => 'E-Mail gedrosselt';

  @override
  String get chatEmailResendFailedDetails =>
      'E-Mail konnte nicht erneut gesendet werden.';
}
