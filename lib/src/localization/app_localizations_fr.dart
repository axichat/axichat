// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'axichat';

  @override
  String get homeTabChats => 'Conversations';

  @override
  String get homeBottomNavHome => 'Accueil';

  @override
  String get homeTabDrafts => 'Brouillons';

  @override
  String get homeTabImportant => 'Important';

  @override
  String get homeTabSpam => 'Indésirables';

  @override
  String get homeTabBlocked => 'Bloqués';

  @override
  String get homeNoModules => 'Aucun module disponible';

  @override
  String get homeRailShowMenu => 'Afficher le menu';

  @override
  String get homeRailHideMenu => 'Masquer le menu';

  @override
  String get homeRailCalendar => 'Calendrier';

  @override
  String get homeSyncTooltip => 'Synchroniser maintenant';

  @override
  String get homeSearchPlaceholderTabs => 'Rechercher dans les onglets';

  @override
  String homeSearchPlaceholderForTab(Object tab) {
    return 'Rechercher $tab';
  }

  @override
  String homeSearchFilterLabel(Object filter) {
    return 'Filtre : $filter';
  }

  @override
  String get blocklistFilterAll => 'Tous bloqués';

  @override
  String get draftsFilterAll => 'Tous les brouillons';

  @override
  String get draftsFilterAttachments => 'Avec pièces jointes';

  @override
  String get chatsFilterAll => 'Toutes les conversations';

  @override
  String get chatsFilterContacts => 'Carnet';

  @override
  String get chatsFilterNonContacts => 'Hors contacts';

  @override
  String get chatsFilterXmppOnly => 'XMPP uniquement';

  @override
  String get chatsFilterEmailOnly => 'E-mail uniquement';

  @override
  String get chatsFilterHidden => 'Masqués';

  @override
  String get spamFilterAll => 'Tous les indésirables';

  @override
  String get spamFilterEmail => 'E-mail';

  @override
  String get spamFilterXmpp => 'XMPP';

  @override
  String get chatFilterDirectOnly => 'Direct uniquement';

  @override
  String get chatFilterAllWithContact => 'Tout avec contact';

  @override
  String get chatSearchMessages => 'Rechercher des messages';

  @override
  String get chatSearchSortNewestFirst => 'Plus récents en premier';

  @override
  String get chatSearchSortOldestFirst => 'Plus anciens en premier';

  @override
  String get chatSearchAnySubject => 'N\'importe quel objet';

  @override
  String get chatSearchExcludeSubject => 'Exclure l\'objet';

  @override
  String get chatSearchImportantOnly => 'Important only';

  @override
  String get chatSearchFailed => 'Recherche échouée';

  @override
  String get chatSearchInProgress => 'Recherche…';

  @override
  String get chatSearchEmptyPrompt =>
      'Les résultats apparaîtront dans la conversation.';

  @override
  String get chatSearchNoMatches =>
      'Aucun résultat. Ajustez les filtres ou essayez une autre requête.';

  @override
  String chatSearchMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# résultats affichés ci-dessous.',
      one: '# résultat affiché ci-dessous.',
    );
    return '$_temp0';
  }

  @override
  String filterTooltip(Object label) {
    return 'Filtrer • $label';
  }

  @override
  String get chatSearchClose => 'Fermer la recherche';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonClear => 'Effacer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get spamEmpty => 'Pas encore de spam';

  @override
  String get spamMoveToInbox => 'Déplacer vers la boîte de réception';

  @override
  String get spamMoveToastTitle => 'Déplacé';

  @override
  String spamMoveToastMessage(Object chatTitle) {
    return '$chatTitle renvoyé dans la boîte de réception.';
  }

  @override
  String get chatSpamUpdateFailed => 'Échec de la mise à jour du statut spam.';

  @override
  String chatSpamSent(Object chatTitle) {
    return '$chatTitle envoyé en indésirable.';
  }

  @override
  String chatSpamRestored(Object chatTitle) {
    return '$chatTitle renvoyé dans la boîte de réception.';
  }

  @override
  String get chatSpamReportedTitle => 'Signalé';

  @override
  String get chatSpamRestoredTitle => 'Rétabli';

  @override
  String get chatMembersLoading => 'Chargement des membres';

  @override
  String get chatMembersLoadingEllipsis => 'Chargement des membres…';

  @override
  String get chatAttachmentConfirmTitle => 'Charger la pièce jointe ?';

  @override
  String chatAttachmentConfirmMessage(Object sender) {
    return 'Charge uniquement les pièces jointes de contacts fiables.\n\n$sender n\'est pas encore dans tes contacts. Continuer ?';
  }

  @override
  String get chatAttachmentConfirmButton => 'Charger';

  @override
  String get attachmentGalleryRosterTrustLabel =>
      'Télécharger automatiquement les fichiers de cet utilisateur';

  @override
  String get attachmentGalleryRosterTrustHint =>
      'Vous pouvez désactiver cela plus tard dans les paramètres du chat.';

  @override
  String get attachmentGalleryChatTrustLabel =>
      'Toujours autoriser les pièces jointes dans ce chat';

  @override
  String get attachmentGalleryChatTrustHint =>
      'Vous pouvez désactiver cela plus tard dans les paramètres du chat.';

  @override
  String get attachmentGalleryRosterErrorTitle =>
      'Impossible d’ajouter le contact';

  @override
  String get attachmentGalleryRosterErrorMessage =>
      'Cette pièce jointe a été téléchargée une fois, mais les téléchargements automatiques sont toujours désactivés.';

  @override
  String get attachmentGalleryErrorMessage =>
      'Impossible de charger les pièces jointes.';

  @override
  String get attachmentGalleryAllLabel => 'Tous';

  @override
  String get attachmentGalleryImagesLabel => 'Photos';

  @override
  String get attachmentGalleryVideosLabel => 'Vidéos';

  @override
  String get attachmentGalleryFilesLabel => 'Fichiers';

  @override
  String get attachmentGallerySentLabel => 'Envoyé';

  @override
  String get attachmentGalleryReceivedLabel => 'Reçu';

  @override
  String get attachmentGalleryMetaSeparator => ' - ';

  @override
  String get attachmentGalleryLayoutGridLabel => 'Vue grille';

  @override
  String get attachmentGalleryLayoutListLabel => 'Vue liste';

  @override
  String get attachmentGallerySortNameAscLabel => 'Nom A-Z';

  @override
  String get attachmentGallerySortNameDescLabel => 'Nom Z-A';

  @override
  String get attachmentGallerySortSizeAscLabel =>
      'Taille du plus petit au plus grand';

  @override
  String get attachmentGallerySortSizeDescLabel =>
      'Taille du plus grand au plus petit';

  @override
  String get chatOpenLinkTitle => 'Ouvrir un lien externe ?';

  @override
  String chatOpenLinkMessage(Object url, Object host) {
    return 'Tu es sur le point d\'ouvrir :\n$url\n\nN\'appuie sur OK que si tu fais confiance au site (hôte : $host).';
  }

  @override
  String chatOpenLinkWarningMessage(Object url, Object host) {
    return 'Tu es sur le point d\'ouvrir :\n$url\n\nCe lien contient des caractères inhabituels ou invisibles. Vérifie attentivement l\'adresse (hôte : $host).';
  }

  @override
  String get chatOpenLinkConfirm => 'Ouvrir le lien';

  @override
  String chatInvalidLink(Object url) {
    return 'Lien invalide : $url';
  }

  @override
  String chatUnableToOpenHost(Object host) {
    return 'Impossible d\'ouvrir $host';
  }

  @override
  String get chatSaveAsDraft => 'Enregistrer comme brouillon';

  @override
  String get chatDraftUnavailable =>
      'Les brouillons ne sont pas disponibles pour le moment.';

  @override
  String get chatDraftMissingContent =>
      'Ajoute un message, un objet ou une pièce jointe avant d\'enregistrer.';

  @override
  String get chatDraftSaved => 'Enregistré dans Brouillons.';

  @override
  String get chatDraftSaveFailed =>
      'Échec de l\'enregistrement du brouillon. Réessaie.';

  @override
  String get chatInvitePermissionDenied =>
      'Vous n’avez pas la permission d’inviter des utilisateurs dans ce salon.';

  @override
  String get chatInviteDomainRestricted =>
      'Les invitations sont limitées au domaine par défaut.';

  @override
  String get chatInviteAlreadyMember => 'L’utilisateur est déjà membre.';

  @override
  String get chatInviteSent => 'Invitation envoyée.';

  @override
  String get chatInviteSendFailed => 'Échec de l’envoi de l’invitation.';

  @override
  String get chatInviteRevoked => 'Invitation révoquée';

  @override
  String get chatInviteRevokeFailed =>
      'Échec de la révocation de l’invitation.';

  @override
  String get chatInviteJoinSuccess => 'Salon rejoint.';

  @override
  String get chatInviteJoinFailed => 'Impossible de rejoindre le salon.';

  @override
  String get chatNicknameUpdated => 'Pseudo mis à jour.';

  @override
  String get chatNicknameUpdateFailed => 'Impossible de modifier le pseudo.';

  @override
  String get chatLeaveRoomFailed => 'Could not leave room.';

  @override
  String get chatDestroyRoomFailed => 'Could not destroy room.';

  @override
  String get chatRoomAvatarPermissionDenied =>
      'Vous n’avez pas la permission de mettre à jour l’avatar du salon.';

  @override
  String get chatRoomAvatarUpdated => 'Avatar du salon mis à jour.';

  @override
  String get chatRoomAvatarUpdateFailed =>
      'Impossible de mettre à jour l’avatar du salon.';

  @override
  String get chatPinPermissionDenied =>
      'Vous n’avez pas la permission d’épingler des messages dans ce salon.';

  @override
  String get chatMessageForwarded => 'Message transféré.';

  @override
  String get chatMessageForwardFailed => 'Impossible de transférer le message.';

  @override
  String chatModerationRequested(Object action, Object nickname) {
    return '$action demandé pour $nickname.';
  }

  @override
  String get chatModerationFailed =>
      'Impossible d’effectuer cette action. Vérifiez les permissions ou la connexion.';

  @override
  String get chatAttachmentInaccessible =>
      'Le fichier sélectionné est inaccessible.';

  @override
  String get chatAttachmentFailed => 'Impossible de joindre le fichier.';

  @override
  String get chatAttachmentView => 'Voir';

  @override
  String get chatAttachmentRetry => 'Relancer l\'envoi';

  @override
  String get chatAttachmentRemove => 'Supprimer la pièce jointe';

  @override
  String get commonClose => 'Fermer';

  @override
  String get toastWhoopsTitle => 'Oups';

  @override
  String get toastHeadsUpTitle => 'Attention';

  @override
  String get toastAllSetTitle => 'C\'est fait';

  @override
  String get chatRoomMembers => 'Membres de la salle';

  @override
  String get chatCloseSettings => 'Fermer les réglages';

  @override
  String get chatSettings => 'Réglages du chat';

  @override
  String get chatEmptySearch => 'Aucun résultat';

  @override
  String get chatEmptyMessages => 'Aucun message';

  @override
  String get chatComposerEmailHint => 'Envoyer un message e-mail';

  @override
  String get chatComposerEmailWatermark => 'Envoyé depuis Axichat';

  @override
  String get chatTransportChoiceTitle => 'Choisir le mode d’envoi';

  @override
  String chatTransportChoiceMessage(Object address) {
    return 'Cette adresse peut être un chat ou un e-mail. Comment Axichat doit-il envoyer vers $address ?';
  }

  @override
  String get chatComposerMessageHint => 'Envoyer un message';

  @override
  String chatComposerFromHint(Object address) {
    return 'Envoi depuis $address';
  }

  @override
  String get chatComposerEmptyMessage => 'Le message ne peut pas être vide.';

  @override
  String get chatComposerEmailUnavailable =>
      'L\'envoi d\'e-mails n\'est pas disponible dans ce chat.';

  @override
  String get chatComposerFileUploadUnavailable =>
      'Le téléversement de fichiers n\'est pas disponible sur ce serveur.';

  @override
  String get chatComposerSelectRecipient =>
      'Sélectionnez au moins un destinataire.';

  @override
  String get chatComposerEmailRecipientUnavailable =>
      'L\'e-mail n\'est pas disponible pour un ou plusieurs destinataires.';

  @override
  String get chatComposerEmailAttachmentRecipientRequired =>
      'Ajoutez un destinataire e-mail pour envoyer des pièces jointes.';

  @override
  String get chatComposerDraftRecipientsUnavailable =>
      'Impossible de déterminer les destinataires de ce brouillon.';

  @override
  String get chatComposerSendFailed =>
      'Impossible d\'envoyer le message. Veuillez réessayer.';

  @override
  String get chatComposerAttachmentBundleFailed =>
      'Impossible de regrouper les pièces jointes. Veuillez réessayer.';

  @override
  String get chatEmailOfflineRetryMessage =>
      'L\'e-mail est hors ligne. Réessayez une fois la synchronisation rétablie.';

  @override
  String get chatEmailOfflineDraftsFallback =>
      'L\'e-mail est hors ligne. Les messages seront enregistrés dans les brouillons jusqu\'au retour de la connexion.';

  @override
  String get chatEmailSyncRefreshing =>
      'La synchronisation des e-mails s\'actualise...';

  @override
  String get chatEmailSyncFailed =>
      'La synchronisation des e-mails a échoué. Veuillez réessayer.';

  @override
  String get chatReadOnly => 'Lecture seule';

  @override
  String get chatUnarchivePrompt =>
      'Désarchive pour envoyer de nouveaux messages.';

  @override
  String get chatEmojiPicker => 'Sélecteur d\'emojis';

  @override
  String get chatShowingDirectOnly => 'Affichage direct uniquement';

  @override
  String get chatShowingAll => 'Tout afficher';

  @override
  String get chatMuteNotifications => 'Couper les notifications';

  @override
  String get chatEnableNotifications => 'Activer les notifications';

  @override
  String get chatMoveToInbox => 'Déplacer vers la boîte de réception';

  @override
  String get chatReportSpam => 'Marquer comme spam';

  @override
  String get chatSignatureToggleLabel =>
      'Inclure le pied de page de signature pour l\'e-mail';

  @override
  String get chatSignatureHintEnabled =>
      'Aide à garder les fils e-mail multi-destinataires intacts.';

  @override
  String get chatSignatureHintDisabled =>
      'Désactivé globalement ; les réponses peuvent perdre le fil.';

  @override
  String get chatSignatureHintWarning =>
      'La désactivation peut casser les fils et les regroupements de pièces jointes.';

  @override
  String get chatInvite => 'Invitation';

  @override
  String get chatReactionsNone => 'Pas encore de réaction';

  @override
  String get chatReactionsPrompt =>
      'Appuie sur une réaction pour ajouter ou retirer la tienne';

  @override
  String get chatReactionsPick => 'Choisis un emoji pour réagir';

  @override
  String get chatMucReferencePending =>
      'En attente de la confirmation du salon avant que les réponses, les épinglages et les réactions soient disponibles.';

  @override
  String get chatMucReferenceUnavailable =>
      'Les réponses, les épinglages et les réactions seront disponibles une fois que le salon aura confirmé ce message.';

  @override
  String get chatActionReply => 'Répondre';

  @override
  String get chatActionForward => 'Transférer';

  @override
  String get chatActionResend => 'Renvoyer';

  @override
  String get chatActionEdit => 'Modifier';

  @override
  String get chatActionRevoke => 'Révoquer';

  @override
  String get chatActionCopy => 'Copier';

  @override
  String get chatActionShare => 'Partager';

  @override
  String get chatActionAddToCalendar => 'Ajouter au calendrier';

  @override
  String get chatCalendarTaskCopyActionLabel => 'Copier dans le calendrier';

  @override
  String get chatCalendarTaskImportConfirmTitle => 'Ajouter au calendrier ?';

  @override
  String get chatCalendarTaskImportConfirmMessage =>
      'Cette tâche vient du chat. Ajoutez-la à votre calendrier pour la gérer ou la modifier.';

  @override
  String get chatCalendarTaskImportConfirmLabel => 'Ajouter au calendrier';

  @override
  String get chatCalendarTaskImportCancelLabel => 'Pas maintenant';

  @override
  String get chatCalendarTaskCopyUnavailableMessage =>
      'Le calendrier n\'est pas disponible.';

  @override
  String get chatCalendarTaskCopyAlreadyAddedMessage => 'Tâche déjà ajoutée.';

  @override
  String get chatCalendarTaskCopySuccessMessage => 'Tâche copiée.';

  @override
  String get chatActionDetails => 'Détails';

  @override
  String get chatActionSelect => 'Sélectionner';

  @override
  String get chatActionReact => 'Réagir';

  @override
  String get chatContactRenameAction => 'Renommer';

  @override
  String get chatContactRenameTooltip => 'Renommer le contact';

  @override
  String get chatContactRenameTitle => 'Renommer le contact';

  @override
  String get chatContactRenameDescription =>
      'Choisissez comment ce contact s’affiche dans Axichat.';

  @override
  String get chatContactRenamePlaceholder => 'Nom affiché';

  @override
  String get chatContactRenameReset => 'Réinitialiser par défaut';

  @override
  String get chatContactRenameSave => 'Enregistrer';

  @override
  String get chatContactRenameSuccess => 'Nom affiché mis à jour';

  @override
  String get chatContactRenameFailure => 'Impossible de renommer le contact';

  @override
  String get chatComposerSemantics => 'Saisie du message';

  @override
  String get draftSaved => 'Brouillon enregistré';

  @override
  String get draftAutosaved => 'Enregistré automatiquement';

  @override
  String get draftErrorTitle => 'Oups';

  @override
  String get draftNoRecipients => 'Aucun destinataire';

  @override
  String get draftSubjectSemantics => 'Objet de l’e-mail';

  @override
  String get draftSubjectHintOptional => 'Objet (facultatif)';

  @override
  String get draftMessageSemantics => 'Corps du message';

  @override
  String get draftMessageHint => 'Saisissez un message';

  @override
  String get draftSendingStatus => 'Envoi...';

  @override
  String get draftSendingEllipsis => 'Envoi…';

  @override
  String get draftSend => 'Envoyer le brouillon';

  @override
  String get emailSendConfirmTitle => 'Review email before sending';

  @override
  String get emailSendConfirmMessage =>
      'Confirm the recipients and body below before sending.';

  @override
  String get emailSendConfirmRecipientsLabel => 'Recipients';

  @override
  String get emailSendConfirmBodyLabel => 'Body';

  @override
  String get emailSendConfirmEmptyBody => '(No body)';

  @override
  String get emailSendConfirmDontShowAgain => 'Don\'t show this again';

  @override
  String get draftDiscard => 'Supprimer';

  @override
  String get draftSave => 'Enregistrer le brouillon';

  @override
  String get draftUnsavedChangesTitle => 'Modifications non enregistrées';

  @override
  String get draftAttachmentInaccessible =>
      'Le fichier sélectionné n’est pas accessible.';

  @override
  String get draftAttachmentFailed => 'Impossible de joindre le fichier.';

  @override
  String get draftDiscarded => 'Brouillon supprimé.';

  @override
  String get draftSendFailed => 'Échec de l’envoi du brouillon.';

  @override
  String get draftSent => 'Envoyé';

  @override
  String draftLimitWarning(int limit, int count) {
    return 'La synchronisation des brouillons conserve jusqu’à $limit brouillons. Vous en avez $count.';
  }

  @override
  String get draftValidationNoContent =>
      'Ajoutez un objet, un message ou une pièce jointe';

  @override
  String draftFileMissing(Object path) {
    return 'Le fichier n’existe plus à $path.';
  }

  @override
  String get draftAttachmentPreview => 'Aperçu';

  @override
  String get draftRemoveAttachment => 'Supprimer la pièce jointe';

  @override
  String get draftNoAttachments => 'Aucune pièce jointe pour le moment';

  @override
  String get draftAttachmentsLabel => 'Pièces jointes';

  @override
  String get draftAddAttachment => 'Ajouter une pièce jointe';

  @override
  String draftTaskDue(Object date) {
    return 'Échéance $date';
  }

  @override
  String get draftTaskNoSchedule => 'Aucune planification';

  @override
  String get draftTaskUntitled => 'Tâche sans titre';

  @override
  String get chatBack => 'Retour';

  @override
  String get chatErrorLabel => 'Erreur !';

  @override
  String get chatSenderYou => 'Vous';

  @override
  String get chatInviteAlreadyInRoom => 'Déjà dans cette discussion.';

  @override
  String get chatInviteWrongAccount =>
      'L’invitation ne concerne pas ce compte.';

  @override
  String get chatShareNoText => 'Le message n’a pas de texte à partager.';

  @override
  String get chatShareFallbackSubject => 'Message Axichat';

  @override
  String chatShareSubjectPrefix(Object chatTitle) {
    return 'Partagé depuis $chatTitle';
  }

  @override
  String get chatCalendarNoText =>
      'Le message n’a pas de texte à ajouter au calendrier.';

  @override
  String get chatCalendarUnavailable =>
      'Le calendrier n’est pas disponible pour le moment.';

  @override
  String get chatCopyNoText =>
      'Les messages sélectionnés n’ont pas de texte à copier.';

  @override
  String get chatCopySuccessMessage => 'Copié dans le presse-papiers';

  @override
  String get chatShareSelectedNoText =>
      'Les messages sélectionnés n’ont pas de texte à partager.';

  @override
  String get chatForwardInviteForbidden =>
      'Les invitations ne peuvent pas être transférées.';

  @override
  String get chatAddToCalendarNoText =>
      'Les messages sélectionnés n\'ont pas de texte à ajouter au calendrier.';

  @override
  String get chatForwardDialogTitle => 'Transférer à...';

  @override
  String get chatForwardEmailWarningTitle => 'Transférer l’e-mail ?';

  @override
  String get chatForwardEmailWarningMessage =>
      'Le transfert d’e-mails peut inclure les en-têtes d’origine et des liens d’images externes. Choisissez le mode d’envoi.';

  @override
  String get chatForwardEmailOptionSafe => 'Transférer comme nouveau message';

  @override
  String get chatForwardEmailOptionOriginal => 'Transférer l’original';

  @override
  String get chatComposerAttachmentWarning =>
      'Les pièces jointes volumineuses sont envoyées séparément à chaque destinataire et peuvent prendre plus de temps.';

  @override
  String chatFanOutRecipientLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'destinataires',
      one: 'destinataire',
    );
    return '$_temp0';
  }

  @override
  String chatFanOutFailureWithSubject(
    Object subject,
    int count,
    Object recipientLabel,
  ) {
    return 'L’objet « $subject » n’a pas pu être envoyé à $count $recipientLabel.';
  }

  @override
  String chatFanOutFailure(int count, Object recipientLabel) {
    return 'Échec de l’envoi à $count $recipientLabel.';
  }

  @override
  String get chatFanOutRetry => 'Réessayer';

  @override
  String get chatSubjectSemantics => 'Objet de l\'e-mail';

  @override
  String get chatSubjectHint => 'Objet';

  @override
  String get chatCollapseLongEmails => 'Collapse long emails';

  @override
  String get chatExpandLongEmails => 'Expand long emails';

  @override
  String get chatAttachmentTooltip => 'Pièces jointes';

  @override
  String get chatImportantMessagesTooltip => 'Important messages';

  @override
  String get chatPinnedMessagesTooltip => 'Messages épinglés';

  @override
  String get chatPinnedMessagesTitle => 'Messages épinglés';

  @override
  String get chatMarkMessageImportant => 'Mark important';

  @override
  String get chatRemoveMessageImportant => 'Remove important';

  @override
  String get chatPinMessage => 'Épingler le message';

  @override
  String get chatUnpinMessage => 'Désépingler le message';

  @override
  String get chatPinnedEmptyState => 'Aucun message épinglé pour le moment.';

  @override
  String get chatPinnedMissingMessage => 'Le message épinglé est indisponible.';

  @override
  String get importantMessagesEmpty => 'No important messages yet';

  @override
  String get chatSendMessageTooltip => 'Envoyer le message';

  @override
  String get chatBlockAction => 'Bloquer';

  @override
  String get chatReactionMore => 'Plus';

  @override
  String get chatQuotedNoContent => '(aucun contenu)';

  @override
  String get chatReplyingTo => 'RÉP. :';

  @override
  String get chatReplyingToComposer => 'Réponse à...';

  @override
  String get chatForwardPrefix => 'TR:';

  @override
  String get chatCancelReply => 'Annuler la réponse';

  @override
  String get chatMessageRetracted => '(retiré)';

  @override
  String get chatMessageEdited => '(modifié)';

  @override
  String get chatGuestAttachmentsDisabled =>
      'Les pièces jointes sont désactivées dans l’aperçu.';

  @override
  String get chatGuestSubtitle => 'Aperçu invité • Stocké localement';

  @override
  String recipientsOverflowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count de plus',
      one: '+1 de plus',
    );
    return '$_temp0';
  }

  @override
  String get recipientsCollapse => 'Réduire';

  @override
  String recipientsSemantics(int count, Object state) {
    return 'Destinataires $count, $state';
  }

  @override
  String get recipientsStateCollapsed => 'replié';

  @override
  String get recipientsStateExpanded => 'déplié';

  @override
  String get recipientsHintExpand => 'Appuyer pour déplier';

  @override
  String get recipientsHintCollapse => 'Appuyer pour replier';

  @override
  String get recipientsHeaderTitle => 'Envoyer à...';

  @override
  String get recipientsFallbackLabel => 'Destinataire';

  @override
  String get recipientsAddHint => 'Ajouter...';

  @override
  String get chatGuestScriptWelcome =>
      'Bienvenue sur Axichat : chat, e-mail et calendrier au même endroit.';

  @override
  String get chatGuestScriptExternalQuestion =>
      'C’est propre. Puis-je envoyer des messages à des personnes qui n’utilisent pas Axichat ?';

  @override
  String get chatGuestScriptExternalAnswer =>
      'Oui : envoie des e-mails au format chat vers Gmail, Outlook, Tuta et d’autres. Si vous utilisez tous Axichat, vous bénéficiez aussi des salons de groupe, réactions, accusés de réception, etc.';

  @override
  String get chatGuestScriptOfflineQuestion =>
      'Est-ce que ça marche hors ligne ou en mode invité ?';

  @override
  String get chatGuestScriptOfflineAnswer =>
      'Oui : le mode hors ligne est intégré et le calendrier fonctionne même en mode invité sans compte ni connexion.';

  @override
  String get chatGuestScriptKeepUpQuestion =>
      'Comment ça m’aide à tout suivre ?';

  @override
  String get chatGuestScriptKeepUpAnswer =>
      'Notre calendrier gère la planification en langage naturel, la matrice d’Eisenhower, le glisser-déposer et les rappels pour vous laisser vous concentrer sur l’essentiel.';

  @override
  String get chatGuestScriptBubbleTip =>
      'Appuie sur une bulle de message pour ouvrir des options comme transférer, répondre et réagir.';

  @override
  String calendarParserUnavailable(Object errorType) {
    return 'Analyseur indisponible ($errorType)';
  }

  @override
  String get calendarAddTaskTitle => 'Ajouter une tâche';

  @override
  String get calendarTaskNameRequired => 'Nom de la tâche *';

  @override
  String get calendarTaskNameHint => 'Nom de la tâche';

  @override
  String get calendarDescriptionHint => 'Description (optionnel)';

  @override
  String get calendarLocationHint => 'Lieu (optionnel)';

  @override
  String get calendarScheduleLabel => 'Planifier';

  @override
  String get calendarDeadlineLabel => 'Échéance';

  @override
  String get calendarRepeatLabel => 'Répéter';

  @override
  String get calendarCancel => 'Annuler';

  @override
  String get calendarAddTaskAction => 'Ajouter une tâche';

  @override
  String get calendarSelectionMode => 'Mode sélection';

  @override
  String get calendarExit => 'Quitter';

  @override
  String calendarTasksSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# tâches sélectionnées',
      one: '# tâche sélectionnée',
    );
    return '$_temp0';
  }

  @override
  String get calendarActions => 'Opérations';

  @override
  String get calendarSetPriority => 'Définir la priorité';

  @override
  String get calendarClearSelection => 'Effacer la sélection';

  @override
  String get calendarExportSelected => 'Exporter la sélection';

  @override
  String get calendarDeleteSelected => 'Supprimer la sélection';

  @override
  String get calendarBatchEdit => 'Édition en lot';

  @override
  String get calendarBatchTitle => 'Titre';

  @override
  String get calendarBatchTitleHint =>
      'Définir le titre des tâches sélectionnées';

  @override
  String get calendarBatchDescription => 'Détails';

  @override
  String get calendarBatchDescriptionHint =>
      'Définir la description (laisser vide pour effacer)';

  @override
  String get calendarBatchLocation => 'Lieu';

  @override
  String get calendarBatchLocationHint =>
      'Définir le lieu (laisser vide pour effacer)';

  @override
  String get calendarApplyChanges => 'Appliquer les modifications';

  @override
  String get calendarAdjustTime => 'Ajuster l’heure';

  @override
  String get calendarSelectionRequired =>
      'Sélectionnez des tâches avant d’appliquer des modifications.';

  @override
  String get calendarSelectionNone =>
      'Sélectionnez d’abord des tâches à exporter.';

  @override
  String get calendarSelectionChangesApplied =>
      'Modifications appliquées aux tâches sélectionnées.';

  @override
  String get calendarSelectionNoPending => 'Aucune modification en attente.';

  @override
  String get calendarSelectionTitleBlank => 'Le titre ne peut pas être vide.';

  @override
  String get calendarExportReady => 'Export prêt à être partagé.';

  @override
  String calendarExportFailed(Object error) {
    return 'Échec de l’export des tâches sélectionnées : $error';
  }

  @override
  String get commonBack => 'Retour';

  @override
  String get composeTitle => 'Composer';

  @override
  String get draftComposeMessage => 'Composer un message';

  @override
  String get draftCompose => 'Composer';

  @override
  String get draftNewMessage => 'Nouveau message';

  @override
  String get draftRestore => 'Restaurer';

  @override
  String get draftRestoreAction => 'Restaurer depuis le brouillon';

  @override
  String get draftMinimize => 'Réduire';

  @override
  String get draftExpand => 'Agrandir';

  @override
  String get draftExitFullscreen => 'Quitter le plein écran';

  @override
  String get draftCloseComposer => 'Fermer l\'éditeur';

  @override
  String get draftsEmpty => 'Aucun brouillon pour le moment';

  @override
  String get draftsDeleteConfirm => 'Supprimer le brouillon ?';

  @override
  String get draftNoSubject => '(pas d’objet)';

  @override
  String draftRecipientCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count destinataires',
      one: '1 destinataire',
    );
    return '$_temp0';
  }

  @override
  String get authCreatingAccount => 'Création de votre compte…';

  @override
  String get authSecuringLogin => 'Sécurisation de votre connexion…';

  @override
  String get authLoggingIn => 'Connexion…';

  @override
  String get authToggleSignup => 'Nouveau ? Inscription';

  @override
  String get authToggleLogin => 'Déjà inscrit ? Connectez-vous';

  @override
  String get authGuestCalendarCta => 'Essayer le calendrier (mode invité)';

  @override
  String get authLogin => 'Se connecter';

  @override
  String get authRememberMeLabel => 'Se souvenir de moi sur cet appareil';

  @override
  String get authSignUp => 'S’inscrire';

  @override
  String get authToggleSelected => 'Sélection actuelle';

  @override
  String authToggleSelectHint(Object label) {
    return 'Activer pour sélectionner $label';
  }

  @override
  String get authUsername => 'Nom d’utilisateur';

  @override
  String get authUsernameRequired => 'Saisissez un nom d’utilisateur';

  @override
  String get authUsernameRules =>
      '4 à 20 caractères alphanumériques, « . », « _ » et « - » autorisés.';

  @override
  String get authUsernameCaseInsensitive => 'Sans distinction de casse';

  @override
  String get authPassword => 'Mot de passe';

  @override
  String get authPasswordConfirm => 'Confirmer le mot de passe';

  @override
  String get authPasswordRequired => 'Saisissez un mot de passe';

  @override
  String authPasswordMaxLength(Object max) {
    return 'Doit contenir $max caractères ou moins';
  }

  @override
  String get authPasswordsMismatch => 'Les mots de passe ne correspondent pas';

  @override
  String get authPasswordPending =>
      'Vérification de la sécurité du mot de passe';

  @override
  String get authSignupPending => 'En attente de l’inscription';

  @override
  String get authLoginPending => 'En attente de connexion';

  @override
  String get authSignupWelcomeTitle => 'Axichat';

  @override
  String get authSignupWelcomeMessage =>
      'Bienvenue sur Axichat !\n\nLe développement est toujours très actif et les limites de stockage par utilisateur sont très faibles, donc évite pour l’instant de t’en servir pour des usages importants.\n\nDe nombreuses fonctions sont disponibles en touchant les bulles de message ; touche celle-ci !\n\nSi tu trouves des bugs, signale-les sur https://github.com/axichat/axichat/issues pour que je puisse les corriger.';

  @override
  String get signupTitle => 'S’inscrire';

  @override
  String get signupStepUsername => 'Choisir un nom d’utilisateur';

  @override
  String get signupStepPassword => 'Créer un mot de passe';

  @override
  String get signupStepCaptcha => 'Vérifier le captcha';

  @override
  String get signupStepSetup => 'Configuration';

  @override
  String signupErrorPrefix(Object message) {
    return 'Erreur : $message';
  }

  @override
  String get signupCaptchaUnavailable => 'Captcha indisponible';

  @override
  String get signupCaptchaChallenge => 'Défi captcha';

  @override
  String get signupCaptchaFailed =>
      'Échec du chargement du captcha. Réessayez après avoir rechargé.';

  @override
  String get signupCaptchaLoading => 'Chargement du captcha';

  @override
  String get signupCaptchaInstructions =>
      'Saisissez les caractères affichés dans cette image captcha.';

  @override
  String get signupCaptchaReload => 'Recharger le captcha';

  @override
  String get signupCaptchaReloadHint =>
      'Obtenez une nouvelle image captcha si celle-ci est illisible.';

  @override
  String get signupCaptchaPlaceholder => 'Saisissez le texte ci-dessus';

  @override
  String get signupCaptchaValidation => 'Saisissez le texte de l’image';

  @override
  String get signupContinue => 'Continuer';

  @override
  String get signupSkipPassword => 'Skip password';

  @override
  String get signupSkipPasswordConfirmTitle => 'Skip password setup?';

  @override
  String get signupSkipPasswordConfirmMessage =>
      'Axichat will create a secure password and keep it only on this device. You will not be able to sign in or sync this account on any other device unless you later set a password you know in Settings. If you lose this device or delete the app, you will lose this account and all data permanently.';

  @override
  String get signupSkipPasswordConfirmAction => 'Skip and continue';

  @override
  String get signupDeviceOnlyRememberMeLocked =>
      'Remember me is required while using a device-managed password.';

  @override
  String get signupProgressLabel => 'Progression de l’inscription';

  @override
  String signupProgressValue(
    Object current,
    Object currentLabel,
    Object percent,
    Object total,
  ) {
    return 'Étape $current sur $total : $currentLabel. $percent % terminé.';
  }

  @override
  String get signupProgressSection => 'Configuration du compte';

  @override
  String get signupPasswordStrength => 'Robustesse du mot de passe';

  @override
  String get signupPasswordBreached =>
      'Ce mot de passe figure dans une base de données piratée.';

  @override
  String get signupStrengthNone => 'Aucune';

  @override
  String get signupStrengthWeak => 'Faible';

  @override
  String get signupStrengthMedium => 'Moyenne';

  @override
  String get signupStrengthStronger => 'Plus fort';

  @override
  String get signupRiskAcknowledgement => 'Je comprends le risque';

  @override
  String get signupRiskError => 'Cochez la case ci-dessus pour continuer.';

  @override
  String get signupRiskAllowBreach =>
      'Autoriser ce mot de passe même s’il est apparu dans une fuite.';

  @override
  String get signupRiskAllowWeak =>
      'Autoriser ce mot de passe bien qu’il soit jugé faible.';

  @override
  String get signupCaptchaErrorMessage =>
      'Impossible de charger le captcha.\nAppuyez sur actualiser pour réessayer.';

  @override
  String get signupAvatarRenderError => 'Impossible de générer cet avatar.';

  @override
  String get signupAvatarLoadError => 'Impossible de charger cet avatar.';

  @override
  String get signupAvatarReadError => 'Impossible de lire cette image.';

  @override
  String get signupAvatarOpenError => 'Impossible d’ouvrir ce fichier.';

  @override
  String get signupAvatarInvalidImage =>
      'Ce fichier n’est pas une image valide.';

  @override
  String signupAvatarSizeError(Object kilobytes) {
    return 'L’avatar doit faire moins de $kilobytes Ko.';
  }

  @override
  String get signupAvatarProcessError => 'Impossible de traiter cette image.';

  @override
  String get signupAvatarEdit => 'Modifier l’avatar';

  @override
  String get signupAvatarUploadImage => 'Importer une image';

  @override
  String get signupAvatarUpload => 'Importer';

  @override
  String get signupAvatarShuffle => 'Mélanger un avatar par défaut';

  @override
  String get signupAvatarMenuDescription =>
      'Nous publierons l’avatar quand votre compte XMPP sera créé.';

  @override
  String get avatarSaveAvatar => 'Enregistrer l’avatar';

  @override
  String get avatarUseThis => 'Définir l’avatar';

  @override
  String get signupAvatarBackgroundColor => 'Couleur d’arrière-plan';

  @override
  String get signupAvatarDefaultsTitle => 'Avatars par défaut';

  @override
  String get signupAvatarCategoryAbstract => 'Abstrait';

  @override
  String get signupAvatarCategoryScience => 'Sciences';

  @override
  String get signupAvatarCategorySports => 'Sport';

  @override
  String get signupAvatarCategoryMusic => 'Musique';

  @override
  String get notificationsRestartTitle =>
      'Redémarrez l’app pour activer les notifications';

  @override
  String get notificationsRestartSubtitle =>
      'Autorisations requises déjà accordées';

  @override
  String get notificationsMessageToggle => 'Notifications en arrière-plan';

  @override
  String get notificationsRequiresRestart => 'Fortement recommandé';

  @override
  String get notificationsDialogTitle =>
      'Activer les notifications de messages';

  @override
  String get notificationsDialogIgnore => 'Ignorer';

  @override
  String get notificationsDialogContinue => 'Continuer';

  @override
  String get notificationsDialogDescription =>
      'Vous pourrez toujours couper le son des discussions plus tard.';

  @override
  String get calendarAdjustStartMinus => 'Début -15 min';

  @override
  String get calendarAdjustStartPlus => 'Début +15 min';

  @override
  String get calendarAdjustEndMinus => 'Fin -15 min';

  @override
  String get calendarAdjustEndPlus => 'Fin +15 min';

  @override
  String get calendarCopyToClipboardAction => 'Copier dans le presse-papiers';

  @override
  String calendarCopyLocation(Object location) {
    return 'Lieu : $location';
  }

  @override
  String get calendarTaskCopied => 'Tâche copiée';

  @override
  String get calendarTaskCopiedClipboard =>
      'Tâche copiée dans le presse-papiers';

  @override
  String get calendarCopyTask => 'Copier la tâche';

  @override
  String get calendarDeleteTask => 'Supprimer la tâche';

  @override
  String get calendarSelectionNoneShort => 'Aucune tâche sélectionnée.';

  @override
  String get calendarSelectionMixedRecurrence =>
      'Les tâches ont des réglages de récurrence différents. Les mises à jour s\'appliqueront à toutes les tâches sélectionnées.';

  @override
  String get calendarSelectionNoTasksHint =>
      'Aucune tâche sélectionnée. Utilisez l\'option Sélectionner dans le calendrier pour choisir des tâches à modifier.';

  @override
  String get calendarSelectionRemove => 'Retirer de la sélection';

  @override
  String get calendarQuickTaskHint =>
      'Tâche rapide (ex. « Réunion à 14 h en salle 101 »)';

  @override
  String get calendarAdvancedHide => 'Masquer les options avancées';

  @override
  String get calendarAdvancedShow => 'Afficher les options avancées';

  @override
  String get calendarUnscheduledTitle => 'Tâches non planifiées';

  @override
  String get calendarUnscheduledEmptyLabel => 'Aucune tâche non planifiée';

  @override
  String get calendarUnscheduledEmptyHint =>
      'Les tâches que vous ajoutez apparaîtront ici';

  @override
  String get calendarRemindersTitle => 'Rappels';

  @override
  String get calendarRemindersEmptyLabel => 'Pas encore de rappels';

  @override
  String get calendarRemindersEmptyHint =>
      'Ajoutez une échéance pour créer un rappel';

  @override
  String get calendarNothingHere => 'Rien ici pour l\'instant';

  @override
  String get calendarTaskNotFound => 'Tache introuvable';

  @override
  String get calendarDayEventsTitle => 'Événements du jour';

  @override
  String get calendarDayEventsEmpty =>
      'Aucun evenement de jour pour cette date';

  @override
  String get calendarDayEventsAdd => 'Ajouter un événement du jour';

  @override
  String get accessibilityNewContactLabel => 'Adresse du contact';

  @override
  String get accessibilityNewContactHint => 'quelquun@exemple.com';

  @override
  String get accessibilityStartChat => 'Démarrer le chat';

  @override
  String get accessibilityStartChatHint =>
      'Envoyez cette adresse pour démarrer une conversation.';

  @override
  String get accessibilityMessagesEmpty => 'Aucun message pour le moment';

  @override
  String get accessibilityMessageNoContent => 'Aucun contenu de message';

  @override
  String get accessibilityActionsTitle => 'Commandes';

  @override
  String get accessibilityReadNewMessages => 'Lire les nouveaux messages';

  @override
  String get accessibilityUnreadSummaryDescription =>
      'Se concentrer sur les conversations non lues';

  @override
  String get accessibilityStartNewChat => 'Démarrer une nouvelle discussion';

  @override
  String get accessibilityStartNewChatDescription =>
      'Choisissez un contact ou saisissez une adresse';

  @override
  String get accessibilityInvitesTitle => 'Invitations';

  @override
  String get accessibilityPendingInvites => 'Invitations en attente';

  @override
  String get accessibilityAcceptInvite => 'Accepter l\'invitation';

  @override
  String get accessibilityInviteAccepted => 'Invitation acceptée';

  @override
  String get accessibilityInviteDismissed => 'Invitation refusée';

  @override
  String get accessibilityInviteUpdateFailed =>
      'Impossible de mettre à jour l\'invitation';

  @override
  String get accessibilityUnreadEmpty => 'Aucune conversation non lue';

  @override
  String get accessibilityInvitesEmpty => 'Aucune invitation en attente';

  @override
  String get accessibilityMessagesTitle => 'Liste des messages';

  @override
  String get accessibilityNoConversationSelected =>
      'Aucune conversation sélectionnée';

  @override
  String accessibilityMessagesWithContact(Object name) {
    return 'Messages avec $name';
  }

  @override
  String accessibilityMessageLabel(
    Object sender,
    Object timestamp,
    Object body,
  ) {
    return '$sender à $timestamp : $body';
  }

  @override
  String get accessibilityMessageSent => 'Message envoyé.';

  @override
  String get accessibilityDiscardWarning =>
      'Appuyez de nouveau sur Échap pour supprimer votre message et fermer cette étape.';

  @override
  String get accessibilityDraftLoaded =>
      'Brouillon chargé. Appuyez sur Échap pour quitter ou sur Enregistrer pour conserver vos modifications.';

  @override
  String accessibilityDraftLabel(Object id) {
    return 'Brouillon $id';
  }

  @override
  String accessibilityDraftLabelWithRecipients(Object recipients) {
    return 'Brouillon pour $recipients';
  }

  @override
  String accessibilityDraftPreview(Object recipients, Object preview) {
    return '$recipients — $preview';
  }

  @override
  String accessibilityIncomingMessageStatus(Object sender, Object time) {
    return 'Nouveau message de $sender à $time';
  }

  @override
  String accessibilityAttachmentWithName(Object filename) {
    return 'Pièce jointe : $filename';
  }

  @override
  String get accessibilityAttachmentGeneric => 'Pièce jointe';

  @override
  String get accessibilityUploadAvailable => 'Téléversement disponible';

  @override
  String get accessibilityUnknownContact => 'Contact inconnu';

  @override
  String get accessibilityChooseContact => 'Choisir un contact';

  @override
  String get accessibilityUnreadConversations => 'Conversations non lues';

  @override
  String get accessibilityStartNewAddress => 'Saisir une nouvelle adresse';

  @override
  String accessibilityConversationWith(Object name) {
    return 'Conversation avec $name';
  }

  @override
  String get accessibilityConversationLabel => 'Discussion';

  @override
  String get accessibilityDialogLabel => 'Dialogue d’accessibilité';

  @override
  String get accessibilityDialogHint =>
      'Appuyez sur Tab pour voir les raccourcis, utilisez les flèches dans les listes, Maj + flèches pour changer de groupe, ou Échap pour quitter.';

  @override
  String get accessibilityNoActionsAvailable =>
      'Aucune action disponible pour le moment';

  @override
  String accessibilityBreadcrumbLabel(
    Object position,
    Object total,
    Object label,
  ) {
    return 'Étape $position sur $total : $label. Activez pour passer à cette étape.';
  }

  @override
  String get accessibilityShortcutOpenMenu => 'Ouvrir le menu';

  @override
  String get accessibilityShortcutBack => 'Reculer d\'une étape ou fermer';

  @override
  String get accessibilityShortcutNextFocus => 'Cible suivante';

  @override
  String get accessibilityShortcutPreviousFocus => 'Cible précédente';

  @override
  String get accessibilityShortcutActivateItem => 'Activer l’élément';

  @override
  String get accessibilityShortcutNextItem => 'Élément suivant';

  @override
  String get accessibilityShortcutPreviousItem => 'Élément précédent';

  @override
  String get accessibilityShortcutNextGroup => 'Groupe suivant';

  @override
  String get accessibilityShortcutPreviousGroup => 'Groupe précédent';

  @override
  String get accessibilityShortcutFirstItem => 'Premier élément';

  @override
  String get accessibilityShortcutLastItem => 'Dernier élément';

  @override
  String get accessibilityKeyboardShortcutsTitle => 'Raccourcis clavier';

  @override
  String accessibilityKeyboardShortcutAnnouncement(Object description) {
    return 'Raccourci clavier : $description';
  }

  @override
  String get accessibilityTextFieldHint =>
      'Saisissez du texte. Utilisez Tab pour avancer ou Échap pour revenir ou fermer le menu.';

  @override
  String get accessibilityLoadingLabel => 'Chargement';

  @override
  String get accessibilityComposerPlaceholder => 'Saisir un message';

  @override
  String accessibilityRecipientLabel(Object name) {
    return 'Destinataire $name';
  }

  @override
  String get accessibilityRecipientRemoveHint =>
      'Appuyez sur Retour arrière ou Suppr pour retirer';

  @override
  String get accessibilityMessageActionsLabel => 'Actions du message';

  @override
  String get accessibilityMessageActionsHint =>
      'Enregistrer comme brouillon ou envoyer ce message';

  @override
  String accessibilityMessagePosition(Object position, Object total) {
    return 'Message $position sur $total';
  }

  @override
  String get accessibilityNoMessages => 'Aucun message';

  @override
  String accessibilityMessageMetadata(Object sender, Object timestamp) {
    return 'De $sender à $timestamp';
  }

  @override
  String accessibilityMessageFrom(Object sender) {
    return 'De $sender';
  }

  @override
  String get accessibilityMessageNavigationHint =>
      'Utilisez les flèches pour naviguer entre les messages. Maj + flèches change de groupe. Appuyez sur Échap pour quitter.';

  @override
  String accessibilitySectionSummary(Object section, Object count) {
    return 'Section $section avec $count éléments';
  }

  @override
  String accessibilityActionListLabel(Object count) {
    return 'Liste d’actions avec $count éléments';
  }

  @override
  String get accessibilityActionListHint =>
      'Utilisez les flèches pour vous déplacer, Maj + flèches pour changer de groupe, Début/Fin pour sauter, Entrée pour activer, Échap pour quitter.';

  @override
  String accessibilityActionItemPosition(
    Object position,
    Object total,
    Object section,
  ) {
    return 'Élément $position sur $total dans $section';
  }

  @override
  String get accessibilityActionReadOnlyHint =>
      'Utilisez les flèches pour parcourir la liste';

  @override
  String get accessibilityActionActivateHint =>
      'Appuyez sur Entrée pour activer';

  @override
  String get accessibilityDismissHighlight => 'Ignorer la mise en avant';

  @override
  String get accessibilityNeedsAttention => 'Nécessite une attention';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileJumpToTop => 'Retour en haut';

  @override
  String get settingsWebsiteLabel => 'Site web';

  @override
  String get settingsDonateLabel => 'Faire un don';

  @override
  String profileDonationPromptMessage(Object username) {
    return 'Bonjour $username, merci de soutenir Axichat. L’application est gratuite et open source, nous dépendons donc des dons d’utilisateurs comme vous pour maintenir l’app et faire tourner les serveurs. Même 5 \$ nous aident beaucoup à couvrir nos dépenses mensuelles.';
  }

  @override
  String get settingsMastodonLabel => 'Mastodon';

  @override
  String get settingsGithubLabel => 'GitHub';

  @override
  String get settingsGitlabLabel => 'GitLab';

  @override
  String get profileJidDescription =>
      'Ceci est votre identifiant Jabber. Composé de votre nom d’utilisateur et de votre domaine, il constitue une adresse unique sur le réseau XMPP.';

  @override
  String get profileResourceDescription =>
      'Ceci est votre ressource XMPP. Chaque appareil a la sienne, c’est pourquoi votre téléphone peut avoir une présence différente de celle de votre ordinateur.';

  @override
  String get profileStatusPlaceholder => 'Message d’état';

  @override
  String get profileArchives => 'Voir les archives';

  @override
  String get profileEditAvatar => 'Modifier l’avatar';

  @override
  String get profileLinkedEmailAccounts => 'Comptes e-mail';

  @override
  String get profileBlocklistTitle => 'Blocklist';

  @override
  String get profileChangePassword => 'Changer le mot de passe';

  @override
  String get profileDeleteAccount => 'Supprimer le compte';

  @override
  String profileExportActionLabel(Object label) {
    return 'Exporter $label';
  }

  @override
  String get profileExportXmppMessagesLabel => 'Messages XMPP';

  @override
  String get profileExportXmppContactsLabel => 'Contacts XMPP';

  @override
  String get profileExportEmailMessagesLabel => 'E-mails';

  @override
  String get profileExportEmailContactsLabel => 'Contacts e-mail';

  @override
  String profileExportShareText(Object label) {
    return 'Export Axichat : $label';
  }

  @override
  String profileExportShareSubject(Object label) {
    return 'Export Axichat $label';
  }

  @override
  String profileExportReadyMessage(Object label) {
    return 'Export $label prêt.';
  }

  @override
  String profileExportEmptyMessage(Object label) {
    return 'Aucun $label à exporter.';
  }

  @override
  String profileExportFailedMessage(Object label) {
    return 'Impossible d’exporter $label.';
  }

  @override
  String profileExportShareUnsupportedMessage(Object label, Object path) {
    return 'Le partage n’est pas disponible sur cette plateforme. Export $label enregistré dans $path.';
  }

  @override
  String get profileExportCopyPathAction => 'Copier le chemin';

  @override
  String get profileExportPathCopiedMessage =>
      'Chemin d’export copié dans le presse-papiers.';

  @override
  String get profileExportFormatTitle => 'Choisir le format d’export';

  @override
  String get profileExportFormatCsvTitle => 'CSV (.csv)';

  @override
  String get profileExportFormatCsvSubtitle =>
      'Compatible avec la plupart des carnets d’adresses.';

  @override
  String get profileExportFormatVcardTitle => 'vCard (.vcf)';

  @override
  String get profileExportFormatVcardSubtitle => 'Fiches de contact standard.';

  @override
  String get profileExportCsvHeaderName => 'Nom';

  @override
  String get profileExportCsvHeaderAddress => 'Adresse';

  @override
  String get profileExportContactsFilenameFallback => 'carnet_adresses';

  @override
  String get termsAcceptLabel => 'J’accepte les conditions générales';

  @override
  String get termsAgreementPrefix => 'Vous acceptez nos ';

  @override
  String get termsAgreementTerms => 'conditions';

  @override
  String get termsAgreementAnd => ' et ';

  @override
  String get termsAgreementPrivacy => 'confidentialité';

  @override
  String get termsAgreementError =>
      'Vous devez accepter les conditions générales';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonRemove => 'Retirer';

  @override
  String get commonSend => 'Envoyer';

  @override
  String get commonDismiss => 'Ignorer';

  @override
  String get settingsButtonLabel => 'Paramètres';

  @override
  String get settingsSectionAccount => 'Compte';

  @override
  String get settingsSectionData => 'Données';

  @override
  String get settingsSectionImportant => 'Essentiel';

  @override
  String get settingsSectionAppearance => 'Apparence';

  @override
  String get settingsSectionSecurity => 'Sécurité';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsThemeMode => 'Mode du thème';

  @override
  String get settingsThemeModeSystem => 'Système';

  @override
  String get settingsThemeModeLight => 'Clair';

  @override
  String get settingsThemeModeDark => 'Sombre';

  @override
  String get settingsColorScheme => 'Palette de couleurs';

  @override
  String get settingsMessageTextSize => 'Taille du texte des messages';

  @override
  String settingsMessageTextSizeOption(int size) {
    return '${size}px';
  }

  @override
  String get settingsColorfulAvatars => 'Avatars colorés';

  @override
  String get settingsColorfulAvatarsDescription =>
      'Génère des couleurs de fond différentes pour chaque avatar.';

  @override
  String get settingsLowMotion => 'Mouvements réduits';

  @override
  String get settingsLowMotionDescription =>
      'Désactive la plupart des animations. Mieux pour les appareils lents.';

  @override
  String get settingsSectionChats => 'Préférences de chat';

  @override
  String get settingsSectionEmail => 'Préférences e-mail';

  @override
  String get settingsSectionAbout => 'À propos';

  @override
  String get settingsAboutAxichat => 'À propos d’Axichat';

  @override
  String get settingsAboutLegalese =>
      'Copyright (C) 2025 Axichat LLC\n\nThis program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.\n\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.\n\nYou should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.';

  @override
  String get settingsTermsLabel => 'Conditions';

  @override
  String get settingsPrivacyLabel => 'Confidentialité';

  @override
  String get settingsLicenseAgpl => 'AGPLv3';

  @override
  String get settingsMuteNotifications => 'Couper les notifications';

  @override
  String get settingsMuteNotificationsDescription =>
      'Arrête de recevoir les notifications de messages.';

  @override
  String get settingsNotificationPreviews => 'Aperçu des notifications';

  @override
  String get settingsNotificationPreviewsDescription =>
      'Afficher le contenu des messages dans les notifications et sur l’écran de verrouillage.';

  @override
  String get settingsChatReadReceipts =>
      'Envoyer les accusés de lecture des chats';

  @override
  String get settingsChatReadReceiptsDescription =>
      'Activé, l’ouverture d’un chat lorsque l’app est active envoie des accusés de lecture pour les messages visibles.';

  @override
  String get settingsChatSendOnEnter => 'Envoyer les chats avec Entrée';

  @override
  String get settingsChatSendOnEnterDescription =>
      'Activé, la touche Entrée envoie les messages de chat. Maj+Entrée insère une nouvelle ligne.';

  @override
  String get settingsEmailReadReceipts =>
      'Envoyer les accusés de lecture des e-mails';

  @override
  String get settingsEmailReadReceiptsDescription =>
      'Activé, l’ouverture d’un chat e-mail lorsque l’app est active envoie des accusés de lecture (MDN) pour les messages visibles.';

  @override
  String get settingsEmailSendOnEnter => 'Envoyer les e-mails avec Entrée';

  @override
  String get settingsEmailSendOnEnterDescription =>
      'Activé, la touche Entrée envoie les messages e-mail. Maj+Entrée insère une nouvelle ligne.';

  @override
  String get settingsEmailSendConfirmation => 'Confirm before sending email';

  @override
  String get settingsEmailSendConfirmationDescription =>
      'Show a review prompt with recipients and body before each email send.';

  @override
  String get settingsEmailComposerWatermark => 'Préremplir le filigrane e-mail';

  @override
  String get settingsEmailComposerWatermarkDescription =>
      'Préremplit les nouveaux e-mails avec le texte \"Sent from Axichat\" que vous pouvez modifier ou supprimer.';

  @override
  String get settingsTypingIndicators => 'Envoyer les indicateurs de saisie';

  @override
  String get settingsTypingIndicatorsDescription =>
      'Permet aux autres dans le chat de voir quand vous tapez.';

  @override
  String get settingsShareTokenFooter =>
      'Inclure le pied de page du jeton de partage';

  @override
  String get settingsShareTokenFooterDescription =>
      'Aide à garder liés les fils d’e-mails multi-destinataires et leurs pièces jointes. Le désactiver peut casser le fil.';

  @override
  String get authCustomServerTitle => 'Serveur personnalisé';

  @override
  String get authCustomServerDescription =>
      'Remplace les points de terminaison XMPP/SMTP ou active les recherches DNS. Laissez les champs vides pour conserver les valeurs par défaut. Les serveurs personnalisés doivent être créés en suivant les étapes sur https://github.com/axichat/server, sinon ils ne fonctionneront probablement pas.';

  @override
  String get authCustomServerDomainOrIp => 'Domaine';

  @override
  String get authCustomServerXmppLabel => 'XMPP';

  @override
  String get authCustomServerSmtpLabel => 'SMTP';

  @override
  String get authCustomServerUseDns => 'Utiliser le DNS';

  @override
  String get authCustomServerUseSrv => 'Utiliser SRV';

  @override
  String get authCustomServerRequireDnssec => 'Exiger DNSSEC';

  @override
  String get authCustomServerXmppHostPlaceholder => 'Hôte XMPP (optionnel)';

  @override
  String get authCustomServerPortPlaceholder => 'Port';

  @override
  String get authCustomServerSmtpHostPlaceholder => 'Hôte SMTP (optionnel)';

  @override
  String get authCustomServerImapHostPlaceholder => 'Hôte IMAP (optionnel)';

  @override
  String get authCustomServerApiPortPlaceholder => 'Port API';

  @override
  String get authCustomServerEmailProvisioningUrlPlaceholder =>
      'URL de provisionnement e-mail (optionnel)';

  @override
  String get authCustomServerEmailPublicTokenPlaceholder =>
      'Jeton public e-mail (optionnel)';

  @override
  String get authCustomServerReset => 'Réinitialiser vers axi.im';

  @override
  String get authCustomServerOpenSettings =>
      'Ouvrir les réglages du serveur personnalisé';

  @override
  String get authCustomServerAdvancedHint =>
      'Les options serveur avancées restent masquées jusqu’à ce que vous appuyiez sur le suffixe de nom d’utilisateur.';

  @override
  String get authUnregisterTitle => 'Désinscription';

  @override
  String get authUnregisterConfirmTitle => 'Supprimer le compte ?';

  @override
  String get authUnregisterConfirmMessage =>
      'Cela supprimera définitivement votre compte et les données locales. Cette action est irréversible.';

  @override
  String get authUnregisterConfirmAction => 'Supprimer le compte';

  @override
  String get authUnregisterProgressLabel =>
      'En attente de la suppression du compte';

  @override
  String get authPasswordPlaceholder => 'Mot de passe';

  @override
  String get authPasswordCurrentPlaceholder => 'Ancien mot de passe';

  @override
  String get authPasswordNewPlaceholder => 'Nouveau mot de passe';

  @override
  String get authPasswordConfirmNewPlaceholder =>
      'Confirmer le nouveau mot de passe';

  @override
  String get authDeviceOnlyPasswordManagedChangeHint =>
      'This account uses a device-managed password. Current password is not required on this device.';

  @override
  String get authDeviceOnlyPasswordManagedDeleteHint =>
      'This account uses a device-managed password. Axichat will use it automatically to confirm deletion.';

  @override
  String get authChangePasswordProgressLabel =>
      'En attente du changement de mot de passe';

  @override
  String get authLogoutTitle => 'Se déconnecter';

  @override
  String get authLogoutNormal => 'Se déconnecter';

  @override
  String get authLogoutNormalDescription => 'Se déconnecter de ce compte.';

  @override
  String get authLogoutBurn => 'Supprimer le compte';

  @override
  String get authLogoutBurnDescription =>
      'Se déconnecter et effacer les données locales de ce compte.';

  @override
  String get chatAttachmentBlockedTitle => 'Pièce jointe bloquée';

  @override
  String get chatEmailImageBlockedLabel => 'Image bloquée';

  @override
  String get chatEmailImageFailedLabel => 'Image échouée';

  @override
  String get chatEmailInteractiveContentBlockedLabel =>
      'Interactive content blocked for safety';

  @override
  String get chatAttachmentBlockedDescription =>
      'Chargez les pièces jointes d’inconnus uniquement si vous leur faites confiance. Nous les récupérerons une fois que vous aurez confirmé.';

  @override
  String get chatAttachmentLoad => 'Charger la pièce jointe';

  @override
  String get chatAttachmentUnavailable => 'Pièce jointe indisponible';

  @override
  String get chatAttachmentSendFailed =>
      'Impossible d’envoyer la pièce jointe.';

  @override
  String get chatAttachmentRetryUpload => 'Relancer l’envoi';

  @override
  String get chatAttachmentRemoveAttachment => 'Retirer la pièce jointe';

  @override
  String get chatAttachmentStatusUploading => 'Envoi de la pièce jointe…';

  @override
  String get chatAttachmentStatusQueued => 'En attente d’envoi';

  @override
  String get chatAttachmentStatusFailed => 'Échec de l’envoi';

  @override
  String get chatAttachmentLoading => 'Chargement de la pièce jointe';

  @override
  String chatAttachmentLoadingProgress(Object percent) {
    return 'Chargement $percent';
  }

  @override
  String get chatAttachmentDownload => 'Télécharger la pièce jointe';

  @override
  String get chatAttachmentDownloadAndOpen => 'Télécharger et ouvrir';

  @override
  String get chatAttachmentDownloadAndSave => 'Télécharger et enregistrer';

  @override
  String get chatAttachmentDownloadAndShare => 'Télécharger et partager';

  @override
  String get chatAttachmentExportTitle => 'Enregistrer la pièce jointe ?';

  @override
  String get chatAttachmentExportMessage =>
      'Cela copiera la pièce jointe vers le stockage partagé. Les exportations ne sont pas chiffrées et peuvent être lues par d\'autres apps. Continuer ?';

  @override
  String get chatAttachmentExportConfirm => 'Enregistrer';

  @override
  String get chatAttachmentExportCancel => 'Annuler';

  @override
  String get chatMediaMetadataWarningTitle =>
      'Les médias peuvent contenir des métadonnées';

  @override
  String get chatMediaMetadataWarningMessage =>
      'Les photos et vidéos peuvent contenir la localisation et des données de l\'appareil. Continuer ?';

  @override
  String get chatNotificationPreviewOptionInherit =>
      'Utiliser le réglage de l\'app';

  @override
  String get chatNotificationPreviewOptionShow =>
      'Toujours afficher les aperçus';

  @override
  String get chatNotificationPreviewOptionHide =>
      'Toujours masquer les aperçus';

  @override
  String get chatAttachmentUnavailableDevice =>
      'La pièce jointe n\'est plus disponible sur cet appareil';

  @override
  String get chatAttachmentInvalidLink => 'Lien de pièce jointe invalide';

  @override
  String chatAttachmentOpenFailed(Object target) {
    return 'Impossible d’ouvrir $target';
  }

  @override
  String get chatAttachmentTypeMismatchTitle =>
      'Type de pièce jointe incohérent';

  @override
  String chatAttachmentTypeMismatchMessage(Object declared, Object detected) {
    return 'Cette pièce jointe indique $declared, mais le fichier semble être $detected. Son ouverture peut être risquée. Continuer ?';
  }

  @override
  String get chatAttachmentTypeMismatchConfirm => 'Ouvrir quand même';

  @override
  String get chatAttachmentHighRiskTitle => 'Fichier potentiellement dangereux';

  @override
  String get chatAttachmentHighRiskMessage =>
      'Ce type de fichier peut être dangereux à ouvrir. Nous recommandons de l’enregistrer et de le scanner avant de l’ouvrir. Continuer ?';

  @override
  String get chatAttachmentUnknownSize => 'Taille inconnue';

  @override
  String get chatAttachmentNotDownloadedYet => 'Pas encore téléchargé';

  @override
  String chatAttachmentErrorTooltip(Object message, Object fileName) {
    return '$message (fichier : $fileName)';
  }

  @override
  String get chatAttachmentMenuHint => 'Ouvrir le menu pour les actions.';

  @override
  String get accessibilityActionsLabel => 'Actions d’accessibilité';

  @override
  String accessibilityActionsShortcutTooltip(Object shortcut) {
    return 'Actions d’accessibilité ($shortcut)';
  }

  @override
  String get shorebirdUpdateAvailable =>
      'Mise à jour disponible : déconnectez-vous et redémarrez l’app';

  @override
  String get updatePromptTitle => 'Update available';

  @override
  String get updatePromptStoreMessage =>
      'A newer version of Axichat is available. Update now to install the latest version.';

  @override
  String updatePromptStoreMessageVersion(String version) {
    return 'Version $version of Axichat is available. Update now to install the latest version.';
  }

  @override
  String get updatePromptPatchReadyTitle => 'Patch ready';

  @override
  String get updatePromptPatchReadyMessage =>
      'The latest Axichat patch is ready. Restart the app to apply it.';

  @override
  String get updateStatusStoreAvailable => 'Update available';

  @override
  String updateStatusStoreAvailableVersion(String version) {
    return 'Update available: v$version';
  }

  @override
  String get updateStatusPatchReady => 'Patch ready: restart app to apply it';

  @override
  String get updateActionUpdate => 'Update';

  @override
  String get updateActionLater => 'Later';

  @override
  String get updateActionOk => 'OK';

  @override
  String get updateActionFailed => 'Could not start the update.';

  @override
  String get updateActionOpenFailed => 'Could not open the update page.';

  @override
  String get updateActionDeclined => 'Update was declined.';

  @override
  String get calendarEditTaskTitle => 'Modifier la tâche';

  @override
  String get calendarDateTimeLabel => 'Date et heure';

  @override
  String get calendarSelectDate => 'Sélectionner la date';

  @override
  String get calendarSelectTime => 'Sélectionner l’heure';

  @override
  String get calendarDurationLabel => 'Durée';

  @override
  String get calendarSelectDuration => 'Sélectionner la durée';

  @override
  String get calendarAddToCriticalPath => 'Ajouter au chemin critique';

  @override
  String get calendarNoCriticalPathMembership => 'Aucun chemin critique';

  @override
  String get calendarGuestTitle => 'Calendrier invité';

  @override
  String get calendarGuestBanner => 'Mode invité - pas de synchronisation';

  @override
  String get calendarGuestModeLabel => 'Mode invité';

  @override
  String get calendarGuestModeDescription =>
      'Connectez-vous pour synchroniser les tâches et activer les rappels.';

  @override
  String get calendarNoTasksForDate => 'Aucune tâche pour cette date';

  @override
  String get calendarTapToCreateTask =>
      'Touchez + pour créer une nouvelle tâche';

  @override
  String get calendarQuickStats => 'Statistiques rapides';

  @override
  String get calendarDueReminders => 'Rappels dus';

  @override
  String get calendarNextTaskLabel => 'Prochaine tâche';

  @override
  String get calendarNone => 'Aucune';

  @override
  String get calendarViewLabel => 'Vue';

  @override
  String get calendarViewDay => 'Jour';

  @override
  String get calendarViewWeek => 'Semaine';

  @override
  String get calendarViewMonth => 'Mois';

  @override
  String get calendarPreviousDate => 'Date précédente';

  @override
  String get calendarNextDate => 'Date suivante';

  @override
  String calendarPreviousUnit(Object unit) {
    return 'Précédent $unit';
  }

  @override
  String calendarNextUnit(Object unit) {
    return 'Suivant $unit';
  }

  @override
  String get calendarToday => 'Aujourd’hui';

  @override
  String get calendarUndo => 'Annuler';

  @override
  String get calendarRedo => 'Rétablir';

  @override
  String get calendarOpeningCreator => 'Ouverture du créateur de tâches...';

  @override
  String calendarWeekOf(Object date) {
    return 'Semaine du $date';
  }

  @override
  String get calendarStatusCompleted => 'Terminée';

  @override
  String get calendarStatusOverdue => 'En retard';

  @override
  String get calendarStatusDueSoon => 'Bientôt due';

  @override
  String get calendarStatusPending => 'En attente';

  @override
  String get calendarTaskCompletedMessage => 'Tâche terminée !';

  @override
  String get calendarTaskUpdatedMessage => 'Tâche mise à jour !';

  @override
  String get calendarErrorTitle => 'Erreur';

  @override
  String get calendarErrorTaskNotFound => 'Tâche introuvable';

  @override
  String get calendarErrorTitleEmpty => 'Le titre ne peut pas être vide';

  @override
  String get calendarErrorTitleTooLong => 'Titre trop long';

  @override
  String get calendarErrorDescriptionTooLong => 'Description trop longue';

  @override
  String get calendarErrorInputInvalid => 'Entrée non valide';

  @override
  String get calendarErrorAddFailed => 'Échec de l’ajout de la tâche';

  @override
  String get calendarErrorUpdateFailed => 'Échec de la mise à jour de la tâche';

  @override
  String get calendarErrorDeleteFailed => 'Échec de la suppression de la tâche';

  @override
  String get calendarErrorNetwork => 'Erreur réseau';

  @override
  String get calendarErrorStorage => 'Erreur de stockage';

  @override
  String get calendarErrorUnknown => 'Erreur inconnue';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonOpen => 'Ouvrir';

  @override
  String get commonSelect => 'Sélectionner';

  @override
  String get commonExport => 'Exporter';

  @override
  String get commonFavorite => 'Favori';

  @override
  String get commonUnfavorite => 'Retirer des favoris';

  @override
  String get commonArchive => 'Archiver';

  @override
  String get commonUnarchive => 'Désarchiver';

  @override
  String get commonShow => 'Afficher';

  @override
  String get chatMessageViewHtmlAction => 'Afficher le HTML';

  @override
  String get chatMessageViewFullAction => 'Voir tout';

  @override
  String get chatMessageShowTextAction => 'Afficher le texte';

  @override
  String get commonHide => 'Masquer';

  @override
  String get blocklistBlockUser => 'Bloquer l’utilisateur';

  @override
  String get blocklistWaitingForUnblock => 'En attente de déblocage';

  @override
  String get blocklistUnblockAll => 'Débloquer tout';

  @override
  String get blocklistUnblock => 'Débloquer';

  @override
  String get blocklistBlock => 'Bloquer';

  @override
  String get blocklistAddTooltip => 'Ajouter à la liste bloquée';

  @override
  String get blocklistInvalidJid => 'Saisissez une adresse valide.';

  @override
  String blocklistBlockFailed(Object address) {
    return 'Échec du blocage de $address. Réessayez plus tard.';
  }

  @override
  String blocklistUnblockFailed(Object address) {
    return 'Échec du déblocage de $address. Réessayez plus tard.';
  }

  @override
  String blocklistBlocked(Object address) {
    return '$address bloqué.';
  }

  @override
  String blocklistUnblocked(Object address) {
    return '$address débloqué.';
  }

  @override
  String get blocklistBlockingUnsupported =>
      'Le serveur ne prend pas en charge le blocage.';

  @override
  String get blocklistUnblockingUnsupported =>
      'Le serveur ne prend pas en charge le déblocage.';

  @override
  String get blocklistUnblockAllFailed =>
      'Impossible de débloquer les utilisateurs. Réessayez plus tard.';

  @override
  String get blocklistUnblockAllSuccess => 'Tout a été débloqué.';

  @override
  String get mucChangeNickname => 'Changer de pseudo';

  @override
  String mucChangeNicknameWithCurrent(Object current) {
    return 'Changer de pseudo (actuel : $current)';
  }

  @override
  String get mucLeaveRoom => 'Quitter la salle';

  @override
  String get mucLeaveRoomConfirmTitle => 'Leave room?';

  @override
  String get mucLeaveRoomConfirmBody =>
      'You will leave this room and it will close locally until you join again.';

  @override
  String get mucDestroyRoom => 'Destroy room';

  @override
  String get mucDestroyRoomConfirmTitle => 'Destroy room?';

  @override
  String get mucDestroyRoomConfirmBody =>
      'This removes the room for everyone currently inside it.';

  @override
  String get mucNoMembers => 'Aucun membre pour l’instant';

  @override
  String get mucInviteUsers => 'Inviter des utilisateurs';

  @override
  String get mucSendInvites => 'Envoyer les invitations';

  @override
  String get mucInviteEligibleRecipientsOnly =>
      'Seuls les contacts XMPP 1:1 de votre domaine ou de axi.im peuvent être invités dans des salons.';

  @override
  String get mucChangeNicknameTitle => 'Changer de pseudo';

  @override
  String get mucEnterNicknamePlaceholder => 'Saisir un pseudo';

  @override
  String get mucUpdateNickname => 'Mettre à jour';

  @override
  String get mucMembersTitle => 'Membres';

  @override
  String get mucEditAvatar => 'Modifier l’avatar de la salle';

  @override
  String get mucAvatarMenuDescription =>
      'Les membres de la salle verront cet avatar.';

  @override
  String get mucInviteUser => 'Inviter un utilisateur';

  @override
  String get mucSectionOwners => 'Propriétaires';

  @override
  String get mucSectionAdmins => 'Administrateurs';

  @override
  String get mucSectionModerators => 'Modérateurs';

  @override
  String get mucSectionMembers => 'Membres';

  @override
  String get mucSectionParticipants => 'Participants';

  @override
  String get mucSectionVisitors => 'Visiteurs';

  @override
  String get mucRoleOwner => 'Propriétaire';

  @override
  String get mucRoleAdmin => 'Administrateur';

  @override
  String get mucRoleMember => 'Membre';

  @override
  String get mucRoleParticipant => 'Participant';

  @override
  String get mucRoleVisitor => 'Visiteur';

  @override
  String get mucRoleModerator => 'Modérateur';

  @override
  String get mucActionOpenChat => 'Ouvrir le chat';

  @override
  String get mucActionKick => 'Exclure';

  @override
  String get mucActionBan => 'Bannir';

  @override
  String get mucActionMakeMember => 'Nommer membre';

  @override
  String get mucActionMakeAdmin => 'Nommer admin';

  @override
  String get mucActionMakeOwner => 'Nommer propriétaire';

  @override
  String get mucActionGrantModerator => 'Donner le statut modérateur';

  @override
  String get mucActionRevokeModerator => 'Retirer le statut modérateur';

  @override
  String get chatsEmptyList => 'Pas encore de chats';

  @override
  String chatsDeleteConfirmMessage(Object chatTitle) {
    return 'Supprimer le chat : $chatTitle';
  }

  @override
  String get chatsDeleteMessagesOption =>
      'Supprimer définitivement les messages';

  @override
  String get chatsDeleteSuccess => 'Chat supprimé';

  @override
  String get chatsExportNoContent => 'Aucun texte à exporter';

  @override
  String get chatsExportShareText => 'Export de chat depuis Axichat';

  @override
  String chatsExportShareSubject(Object chatTitle) {
    return 'Chat avec $chatTitle';
  }

  @override
  String get chatsExportSuccess => 'Chat exporté';

  @override
  String get chatsExportFailure => 'Impossible d’exporter le chat';

  @override
  String get chatExportWarningTitle => 'Exporter l’historique du chat ?';

  @override
  String get chatExportWarningMessage =>
      'Les exports de chat ne sont pas chiffrés et peuvent être lus par d\'autres apps ou services cloud. Continuer ?';

  @override
  String get chatsArchivedRestored => 'Chat restauré';

  @override
  String get chatsArchivedHint => 'Chat archivé (Profil → Chats archivés)';

  @override
  String get chatsVisibleNotice => 'Le chat est à nouveau visible';

  @override
  String get chatsHiddenNotice =>
      'Chat masqué (utilisez le filtre pour l’afficher)';

  @override
  String chatsUnreadLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# messages non lus',
      one: '# message non lu',
      zero: 'Aucun message non lu',
    );
    return '$_temp0';
  }

  @override
  String get chatsSemanticsUnselectHint =>
      'Appuyez pour désélectionner le chat';

  @override
  String get chatsSemanticsSelectHint => 'Appuyez pour sélectionner le chat';

  @override
  String get chatsSemanticsOpenHint => 'Appuyez pour ouvrir le chat';

  @override
  String get chatsHideActions => 'Masquer les actions du chat';

  @override
  String get chatsShowActions => 'Afficher les actions du chat';

  @override
  String get chatsSelectedLabel => 'Chat sélectionné';

  @override
  String get chatsSelectLabel => 'Sélectionner le chat';

  @override
  String get chatsExportFileLabel => 'chats';

  @override
  String get chatSelectionExportEmptyTitle => 'Aucun message à exporter';

  @override
  String get chatSelectionExportEmptyMessage =>
      'Sélectionnez des chats avec du contenu texte';

  @override
  String get chatSelectionExportShareText => 'Exports de chat depuis Axichat';

  @override
  String get chatSelectionExportShareSubject => 'Export de chats Axichat';

  @override
  String get chatSelectionExportReadyTitle => 'Export prêt';

  @override
  String chatSelectionExportReadyMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# chats partagés',
      one: '# chat partagé',
    );
    return '$_temp0';
  }

  @override
  String get chatSelectionExportFailedTitle => 'Échec de l’export';

  @override
  String get chatSelectionExportFailedMessage =>
      'Impossible d’exporter les chats sélectionnés';

  @override
  String get chatSelectionDeleteConfirmTitle => 'Supprimer les chats ?';

  @override
  String chatSelectionDeleteConfirmMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ceci supprime # chats et tous leurs messages. Action irréversible.',
      one: 'Ceci supprime 1 chat et tous ses messages. Action irréversible.',
    );
    return '$_temp0';
  }

  @override
  String get chatsCreateGroupChatTooltip => 'Créer un chat de groupe';

  @override
  String get chatsCreateGroupSuccess => 'Discussion de groupe créée.';

  @override
  String get chatsCreateGroupFailure =>
      'Impossible de créer la discussion de groupe.';

  @override
  String get chatsCreateGroupAlreadyExists =>
      'Une discussion de groupe avec ce nom existe déjà.';

  @override
  String get chatsRefreshFailed => 'Synchronisation échouée.';

  @override
  String get chatsRoomLabel => 'Salle';

  @override
  String get chatsCreateChatRoomTitle => 'Créer une salle de chat';

  @override
  String get chatsCreateChatRoomAction => 'Créer la salle';

  @override
  String get chatsRoomNamePlaceholder => 'Nom';

  @override
  String get chatsRoomNameRequiredError =>
      'Le nom de la salle ne peut pas être vide.';

  @override
  String chatsRoomNameInvalidCharacterError(Object character) {
    return 'Les noms de salle ne peuvent pas contenir $character.';
  }

  @override
  String get chatsCreateRoomTypeChatTitle => 'Salle de chat';

  @override
  String get chatsCreateRoomTypeChatDescription =>
      'La conversation s’ouvre en premier. Le calendrier partagé reste disponible dans la salle.';

  @override
  String get chatsCreateRoomTypeCalendarTitle => 'Salle calendrier';

  @override
  String get chatsCreateRoomTypeCalendarDescription =>
      'Le calendrier partagé s’ouvre en premier. Le chat de la salle reste accessible depuis la barre d’application.';

  @override
  String get chatsCreateRoomTypeHint =>
      'Les salles calendrier sont des salles partagées centrées sur le calendrier, et les salles de chat ouvrent d’abord la conversation. Les deux types de salle conservent à la fois le chat et le calendrier.';

  @override
  String get chatsArchiveTitle => 'Archives';

  @override
  String get chatsArchiveEmpty => 'Aucun chat archivé pour l’instant';

  @override
  String calendarTileNow(Object title) {
    return 'Maintenant : $title';
  }

  @override
  String calendarTileNext(Object title) {
    return 'Suivant : $title';
  }

  @override
  String get calendarTileNone => 'Aucune tâche à venir';

  @override
  String get calendarViewDayShort => 'J';

  @override
  String get calendarViewWeekShort => 'S';

  @override
  String get calendarViewMonthShort => 'M';

  @override
  String get calendarShowCompleted => 'Afficher terminées';

  @override
  String get calendarHideCompleted => 'Masquer terminées';

  @override
  String get rosterAddTooltip => 'Ajouter au carnet d’adresses';

  @override
  String get rosterAddLabel => 'Ajouter un contact';

  @override
  String get rosterAddTitle => 'Ajouter un contact';

  @override
  String rosterAddedToContacts(Object user) {
    return '$user ajouté aux contacts.';
  }

  @override
  String get rosterEmpty => 'Aucun contact pour l’instant';

  @override
  String get rosterCompose => 'Composer';

  @override
  String rosterRemoveConfirm(Object jid) {
    return 'Retirer $jid des contacts ?';
  }

  @override
  String get rosterInvitesEmpty => 'Aucune invitation pour l’instant';

  @override
  String rosterRejectInviteConfirm(Object jid) {
    return 'Refuser l’invitation de $jid ?';
  }

  @override
  String get rosterAddContactTooltip => 'Ajouter un contact';

  @override
  String get jidInputPlaceholder => 'john@axi.im';

  @override
  String get jidInputInvalid => 'Saisissez un JID valide';

  @override
  String get sessionCapabilityChat => 'Chat';

  @override
  String get sessionCapabilityEmail => 'E-mail';

  @override
  String get sessionCapabilityStatusConnected => 'Connecté';

  @override
  String get sessionCapabilityStatusConnecting => 'Connexion';

  @override
  String get sessionCapabilityStatusError => 'Erreur';

  @override
  String get sessionCapabilityStatusOffline => 'Hors ligne';

  @override
  String get sessionCapabilityStatusOff => 'Désactivé';

  @override
  String get sessionCapabilityStatusSyncing => 'Synchronisation';

  @override
  String get emailSyncMessageSyncing => 'Synchronisation des e-mails...';

  @override
  String get emailSyncMessageConnecting =>
      'Connexion aux serveurs de messagerie...';

  @override
  String get emailSyncMessageDisconnected =>
      'Déconnecté des serveurs de messagerie.';

  @override
  String get emailSyncMessageGroupMembershipChanged =>
      'L\'adhésion au groupe e-mail a changé. Rouvrez la discussion.';

  @override
  String get emailSyncMessageHistorySyncing =>
      'Synchronisation de l\'historique des e-mails...';

  @override
  String get emailSyncMessageRetrying =>
      'La synchronisation des e-mails réessaiera bientôt...';

  @override
  String get emailSyncMessageRefreshing =>
      'Actualisation de la synchro e-mail après une interruption…';

  @override
  String get emailSyncMessageRefreshFailed =>
      'Impossible d’actualiser la synchro e-mail. Essayez de rouvrir l’app.';

  @override
  String get authChangePasswordPending => 'Mise à jour du mot de passe...';

  @override
  String get authEndpointAdvancedHint => 'Options avancées';

  @override
  String get authEndpointApiPortPlaceholder => 'Port API';

  @override
  String get authEndpointDescription =>
      'Configurer les points de terminaison XMPP/SMTP pour ce compte.';

  @override
  String get authEndpointDomainPlaceholder => 'Domaine';

  @override
  String get authEndpointPortPlaceholder => 'Port';

  @override
  String get authEndpointRequireDnssecLabel => 'Exiger DNSSEC';

  @override
  String get authEndpointReset => 'Réinitialiser';

  @override
  String get authEndpointSmtpHostPlaceholder => 'Hôte SMTP';

  @override
  String get authEndpointSmtpLabel => 'SMTP';

  @override
  String get authEndpointTitle => 'Configuration des points de terminaison';

  @override
  String get authEndpointUseDnsLabel => 'Utiliser DNS';

  @override
  String get authEndpointUseSrvLabel => 'Utiliser SRV';

  @override
  String get authEndpointXmppHostPlaceholder => 'Hôte XMPP';

  @override
  String get authEndpointXmppLabel => 'XMPP';

  @override
  String get authUnregisterPending => 'Désinscription...';

  @override
  String calendarAddTaskError(Object details) {
    return 'Impossible d\'ajouter la tâche : $details';
  }

  @override
  String get calendarBackToCalendar => 'Retour au calendrier';

  @override
  String get calendarLoadingMessage => 'Chargement du calendrier...';

  @override
  String get calendarCriticalPathAddTask => 'Ajouter une tâche';

  @override
  String get calendarCriticalPathAddToTitle => 'Ajouter au chemin critique';

  @override
  String get calendarCriticalPathCreatePrompt =>
      'Créez un chemin critique pour commencer';

  @override
  String get calendarCriticalPathDragHint =>
      'Faites glisser les tâches pour réorganiser';

  @override
  String get calendarCriticalPathEmptyTasks =>
      'Aucune tâche dans ce chemin pour le moment';

  @override
  String get calendarCriticalPathNameEmptyError => 'Saisissez un nom';

  @override
  String get calendarCriticalPathNamePlaceholder => 'Nom du chemin critique';

  @override
  String get calendarCriticalPathNamePrompt => 'Nom';

  @override
  String get calendarCriticalPathTaskOrderTitle => 'Ordonner les tâches';

  @override
  String get calendarCriticalPathsAll => 'Tous les chemins';

  @override
  String get calendarCriticalPathsEmpty =>
      'Aucun chemin critique pour l\'instant';

  @override
  String get calendarCriticalPathsNew => 'Nouveau chemin critique';

  @override
  String get calendarCriticalPathRenameTitle => 'Renommer le chemin critique';

  @override
  String get calendarCriticalPathDeleteTitle => 'Supprimer le chemin critique';

  @override
  String get calendarCriticalPathsTitle => 'Chemins critiques';

  @override
  String get calendarCriticalPathShareAction => 'Partager dans le chat';

  @override
  String get calendarCriticalPathShareTitle => 'Partager le chemin critique';

  @override
  String get calendarCriticalPathShareSubtitle =>
      'Envoyez un chemin critique dans un chat.';

  @override
  String get calendarCriticalPathShareTargetLabel => 'Partager avec';

  @override
  String get calendarCriticalPathShareButtonLabel => 'Partager';

  @override
  String get calendarCriticalPathShareMissingChats =>
      'Aucun chat éligible disponible.';

  @override
  String get calendarCriticalPathShareMissingRecipient =>
      'Sélectionnez un chat pour partager.';

  @override
  String get calendarCriticalPathShareMissingService =>
      'Le partage du calendrier n\'est pas disponible.';

  @override
  String get calendarCriticalPathShareDenied =>
      'Les cartes de calendrier sont désactivées pour votre rôle dans cette salle.';

  @override
  String get calendarCriticalPathShareFailed =>
      'Échec du partage du chemin critique.';

  @override
  String get calendarCriticalPathShareSuccess => 'Chemin critique partagé.';

  @override
  String get calendarCriticalPathShareChatTypeDirect => 'Discussion directe';

  @override
  String get calendarCriticalPathShareChatTypeGroup => 'Discussion de groupe';

  @override
  String get calendarCriticalPathShareChatTypeNote => 'Remarques';

  @override
  String calendarCriticalPathProgressSummary(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$completed sur $total tâches terminées dans l\'ordre',
      one: '$completed sur $total tâche terminée dans l\'ordre',
    );
    return '$_temp0';
  }

  @override
  String get calendarCriticalPathProgressHint =>
      'Terminez les tâches dans l\'ordre indiqué pour avancer.';

  @override
  String get calendarCriticalPathProgressLabel => 'Progression';

  @override
  String calendarCriticalPathProgressPercent(int percent) {
    return '$percent%';
  }

  @override
  String get calendarCriticalPathFocus => 'Cibler';

  @override
  String get calendarCriticalPathUnfocus => 'Retirer le focus';

  @override
  String get calendarCriticalPathCompletedLabel => 'Terminées';

  @override
  String calendarCriticalPathQueuedAdd(Object name) {
    return 'Sera ajouté à \"$name\" lors de l\'enregistrement';
  }

  @override
  String calendarCriticalPathQueuedCreate(Object name) {
    return '\"$name\" créé et mis en file d\'attente';
  }

  @override
  String get calendarCriticalPathUnavailable =>
      'Les chemins critiques ne sont pas disponibles dans cette vue.';

  @override
  String get calendarCriticalPathAddAfterSaveFailed =>
      'La tâche a été enregistrée, mais n\'a pas pu être ajoutée à un chemin critique.';

  @override
  String calendarCriticalPathAddSuccess(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouté $count tâches à \"$name\".',
      one: 'Ajouté à \"$name\".',
    );
    return '$_temp0';
  }

  @override
  String calendarCriticalPathCreateSuccess(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '\"$name\" créé et tâches ajoutées.',
      one: '\"$name\" créé et tâche ajoutée.',
    );
    return '$_temp0';
  }

  @override
  String calendarCriticalPathAddFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Impossible d\'ajouter les tâches à un chemin critique.',
      one: 'Impossible d\'ajouter la tâche à un chemin critique.',
    );
    return '$_temp0';
  }

  @override
  String calendarCriticalPathAlreadyContainsTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Les tâches sont déjà dans ce chemin critique.',
      one: 'La tâche est déjà dans ce chemin critique.',
    );
    return '$_temp0';
  }

  @override
  String get calendarCriticalPathCreateFailed =>
      'Impossible de créer un chemin critique.';

  @override
  String get calendarTaskSearchTitle => 'Rechercher des tâches';

  @override
  String calendarTaskSearchAddToTitle(Object name) {
    return 'Ajouter à $name';
  }

  @override
  String get calendarTaskSearchSubtitle =>
      'Recherchez des titres, descriptions, lieux, catégories, priorités et échéances.';

  @override
  String get calendarTaskSearchAddToSubtitle =>
      'Touchez une tâche pour l\'ajouter à l\'ordre du chemin critique.';

  @override
  String get calendarTaskSearchHint =>
      'title:, desc:, location:, category:work, priority:urgent, status:done';

  @override
  String get calendarTaskSearchEmptyPrompt =>
      'Commencez à taper pour rechercher des tâches';

  @override
  String get calendarTaskSearchEmptyNoResults => 'Aucun résultat';

  @override
  String get calendarTaskSearchEmptyHint =>
      'Utilisez des filtres comme title:, desc:, location:, priority:critical, status:done, deadline:today.';

  @override
  String get calendarTaskSearchFilterScheduled => 'Planifiées';

  @override
  String get calendarTaskSearchFilterUnscheduled => 'Non planifiées';

  @override
  String get calendarTaskSearchFilterReminders => 'Rappels';

  @override
  String get calendarTaskSearchFilterOpen => 'Ouvertes';

  @override
  String get calendarTaskSearchFilterCompleted => 'Terminées';

  @override
  String calendarTaskSearchDueDate(Object date) {
    return 'Échéance $date';
  }

  @override
  String calendarTaskSearchOverdueDate(Object date) {
    return 'En retard · $date';
  }

  @override
  String calendarDeleteTaskConfirm(Object title) {
    return 'Supprimer \"$title\" ?';
  }

  @override
  String get calendarErrorTitleEmptyFriendly =>
      'Le titre ne peut pas être vide';

  @override
  String get calendarExportFormatIcsSubtitle =>
      'À utiliser avec les clients calendrier';

  @override
  String get calendarExportFormatIcsTitle => 'Exporter .ics';

  @override
  String get calendarExportFormatJsonSubtitle =>
      'À utiliser pour les sauvegardes ou scripts';

  @override
  String get calendarExportFormatJsonTitle => 'Exporter JSON';

  @override
  String calendarRemovePathConfirm(Object name) {
    return 'Retirer cette tâche de \"$name\" ?';
  }

  @override
  String get calendarSandboxHint =>
      'Planifiez les tâches ici avant de les affecter à un chemin.';

  @override
  String get chatAlertHide => 'Masquer';

  @override
  String get chatAlertIgnore => 'Ignorer';

  @override
  String get chatAttachmentTapToLoad => 'Touchez pour charger';

  @override
  String chatMessageAddRecipientSuccess(Object recipient) {
    return '$recipient ajouté';
  }

  @override
  String get chatMessageAddRecipients => 'Ajouter des destinataires';

  @override
  String get chatMessageCreateChat => 'Créer un chat';

  @override
  String chatMessageCreateChatFailure(Object reason) {
    return 'Impossible de créer le chat : $reason';
  }

  @override
  String get chatMessageInfoDevice => 'Appareil';

  @override
  String get chatMessageInfoError => 'Erreur';

  @override
  String get chatMessageInfoProtocol => 'Protocole';

  @override
  String get chatMessageInfoTimestamp => 'Horodatage';

  @override
  String get chatMessageOpenChat => 'Ouvrir le chat';

  @override
  String get chatMessageStatusDisplayed => 'Lu';

  @override
  String get chatMessageStatusReceived => 'Reçu';

  @override
  String get chatMessageStatusSent => 'Envoyé';

  @override
  String get commonActions => 'Opérations';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonPrevious => 'Précédent';

  @override
  String emailDemoAccountLabel(Object account) {
    return 'Compte : $account';
  }

  @override
  String get emailDemoDefaultMessage => 'Bonjour de la part d’Axichat';

  @override
  String get emailDemoDisplayNameSelf => 'Moi';

  @override
  String get emailDemoErrorMissingPassphrase =>
      'Phrase secrète de base de données manquante.';

  @override
  String get emailDemoErrorMissingPrefix =>
      'Préfixe de base de données manquant.';

  @override
  String get emailDemoErrorMissingProfile =>
      'Aucun profil principal trouvé. Connectez-vous d’abord.';

  @override
  String get emailDemoMessageLabel => 'Message de démo';

  @override
  String get emailDemoProvisionButton => 'Provisionner l’e-mail';

  @override
  String get emailDemoSendButton => 'Envoyer le message de démo';

  @override
  String get emailDemoStatusIdle => 'Inactif';

  @override
  String emailDemoStatusLabel(Object status) {
    return 'Statut : $status';
  }

  @override
  String get emailDemoStatusLoginToProvision =>
      'Connectez-vous pour provisionner l’e-mail.';

  @override
  String get emailDemoStatusNotProvisioned => 'Non provisionné';

  @override
  String emailDemoStatusProvisionFailed(Object error) {
    return 'Échec du provisionnement : $error';
  }

  @override
  String get emailDemoStatusProvisionFirst => 'Provisionnez d’abord un compte.';

  @override
  String emailDemoStatusProvisioned(Object address) {
    return 'Provisionné $address';
  }

  @override
  String get emailDemoStatusProvisioning => 'Provisionnement du compte e-mail…';

  @override
  String get emailDemoStatusReady => 'Prêt';

  @override
  String emailDemoStatusSendFailed(Object error) {
    return 'Échec de l’envoi : $error';
  }

  @override
  String get emailDemoStatusSending => 'Envoi du message de démo…';

  @override
  String emailDemoStatusSent(Object id) {
    return 'Message de démo envoyé (id=$id)';
  }

  @override
  String get emailDemoTitle => 'Démo du transport e-mail';

  @override
  String get verificationAddLabelPlaceholder => 'Ajouter un libellé';

  @override
  String get verificationCurrentDevice => 'Appareil actuel';

  @override
  String verificationDeviceIdLabel(Object id) {
    return 'ID : $id';
  }

  @override
  String get verificationNotTrusted => 'Non fiable';

  @override
  String get verificationRegenerateDevice => 'Régénérer l’appareil';

  @override
  String get verificationRegenerateWarning =>
      'Faites ceci uniquement si vous êtes expert.';

  @override
  String get verificationTrustBlind => 'Confiance aveugle';

  @override
  String get verificationTrustNone => 'Aucune confiance';

  @override
  String get verificationTrustVerified => 'Vérifié';

  @override
  String get verificationTrusted => 'Fiable';

  @override
  String get avatarSavedMessage => 'Avatar enregistré.';

  @override
  String get avatarOpenError => 'Impossible d\'ouvrir ce fichier.';

  @override
  String get avatarReadError => 'Impossible de lire ce fichier.';

  @override
  String get avatarInvalidImageError =>
      'Ce fichier n\'est pas une image valide.';

  @override
  String get avatarProcessError => 'Impossible de traiter cette image.';

  @override
  String get avatarTemplateLoadError =>
      'Échec du chargement de cette option d\'avatar.';

  @override
  String get avatarMissingDraftError => 'Choisis ou crée un avatar d\'abord.';

  @override
  String get avatarXmppDisconnectedError =>
      'Connecte-toi à XMPP avant d\'enregistrer ton avatar.';

  @override
  String get avatarPublishRejectedError =>
      'Ton serveur a rejeté la publication de l\'avatar.';

  @override
  String get avatarPublishTimeoutError =>
      'Le téléversement de l\'avatar a expiré. Réessaie.';

  @override
  String get avatarPublishGenericError =>
      'Impossible de publier l\'avatar. Vérifie ta connexion et réessaie.';

  @override
  String get avatarPublishUnexpectedError =>
      'Erreur inattendue lors du téléversement de l\'avatar.';

  @override
  String get avatarCropTitle => 'Rogner et cadrer';

  @override
  String get avatarCropDescription =>
      'Faites glisser ou redimensionnez le carré pour définir le recadrage. Recentrez-le et suivez le cercle pour correspondre à l’avatar enregistré.';

  @override
  String get avatarCropPlaceholder =>
      'Ajoutez une photo ou choisissez un avatar par défaut pour ajuster le cadrage.';

  @override
  String avatarCropSizeLabel(Object pixels) {
    return 'Recadrage de $pixels px';
  }

  @override
  String get avatarCropSavedSize => 'Enregistré en 256×256 • < 64 Ko';

  @override
  String get avatarBackgroundTitle => 'Couleur d’arrière-plan';

  @override
  String get avatarBackgroundDescription =>
      'Utilisez la roue ou les préréglages pour teinter les avatars transparents avant l’enregistrement.';

  @override
  String get avatarBackgroundWheelTitle => 'Roue et hex';

  @override
  String get avatarBackgroundWheelDescription =>
      'Faites glisser la roue ou saisissez une valeur hexadécimale.';

  @override
  String get avatarBackgroundTransparent => 'Transparence';

  @override
  String get avatarBackgroundPreview =>
      'Aperçu de la teinte circulaire enregistrée.';

  @override
  String get avatarDefaultsTitle => 'Avatars par défaut';

  @override
  String get avatarCategoryAbstract => 'Abstrait';

  @override
  String get avatarCategoryStem => 'STEM';

  @override
  String get avatarCategorySports => 'Sport';

  @override
  String get avatarCategoryMusic => 'Musique';

  @override
  String get avatarCategoryMisc => 'Loisirs et jeux';

  @override
  String avatarTemplateAbstract(Object index) {
    return 'Abstrait $index';
  }

  @override
  String get avatarTemplateAtom => 'Atome';

  @override
  String get avatarTemplateBeaker => 'Bécher';

  @override
  String get avatarTemplateCompass => 'Boussole';

  @override
  String get avatarTemplateCpu => 'CPU';

  @override
  String get avatarTemplateGear => 'Engrenage';

  @override
  String get avatarTemplateGlobe => 'Globe';

  @override
  String get avatarTemplateLaptop => 'Ordinateur portable';

  @override
  String get avatarTemplateMicroscope => 'Microscope';

  @override
  String get avatarTemplateRobot => 'Robot';

  @override
  String get avatarTemplateStethoscope => 'Stéthoscope';

  @override
  String get avatarTemplateTelescope => 'Télescope';

  @override
  String get avatarTemplateArchery => 'Tir à l’arc';

  @override
  String get avatarTemplateBaseball => 'Baseball';

  @override
  String get avatarTemplateBasketball => 'Basket-ball';

  @override
  String get avatarTemplateBoxing => 'Boxe';

  @override
  String get avatarTemplateCycling => 'Cyclisme';

  @override
  String get avatarTemplateDarts => 'Fléchettes';

  @override
  String get avatarTemplateFootball => 'Football américain';

  @override
  String get avatarTemplateGolf => 'Golf';

  @override
  String get avatarTemplatePingPong => 'Ping-pong';

  @override
  String get avatarTemplateSkiing => 'Ski';

  @override
  String get avatarTemplateSoccer => 'Football';

  @override
  String get avatarTemplateTennis => 'Tennis';

  @override
  String get avatarTemplateVolleyball => 'Volley-ball';

  @override
  String get avatarTemplateDrums => 'Batterie';

  @override
  String get avatarTemplateElectricGuitar => 'Guitare électrique';

  @override
  String get avatarTemplateGuitar => 'Guitare';

  @override
  String get avatarTemplateMicrophone => 'Micro';

  @override
  String get avatarTemplatePiano => 'Piano';

  @override
  String get avatarTemplateSaxophone => 'Saxophone';

  @override
  String get avatarTemplateViolin => 'Violon';

  @override
  String get avatarTemplateCards => 'Cartes';

  @override
  String get avatarTemplateChess => 'Échecs';

  @override
  String get avatarTemplateChessAlt => 'Échecs alt';

  @override
  String get avatarTemplateDice => 'Dés';

  @override
  String get avatarTemplateDiceAlt => 'Dés alt';

  @override
  String get avatarTemplateEsports => 'Esport';

  @override
  String get avatarTemplateSword => 'Épée';

  @override
  String get avatarTemplateVideoGames => 'Jeux vidéo';

  @override
  String get avatarTemplateVideoGamesAlt => 'Jeux vidéo alt';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonRename => 'Renommer';

  @override
  String get calendarHour => 'Heure';

  @override
  String get calendarMinute => 'Minute';

  @override
  String get calendarPasteTaskHere => 'Coller la tâche ici';

  @override
  String get calendarQuickAddTask => 'Ajouter une tâche rapide';

  @override
  String get calendarSplitTaskAt => 'Diviser la tâche à';

  @override
  String get calendarAddDayEvent => 'Ajouter un événement du jour';

  @override
  String get calendarZoomOut => 'Dézoomer (Ctrl/Cmd + -)';

  @override
  String get calendarZoomIn => 'Zoomer (Ctrl/Cmd + +)';

  @override
  String get calendarChecklistItem => 'Élément de liste';

  @override
  String get calendarRemoveItem => 'Supprimer l\'élément';

  @override
  String get calendarAddChecklistItem => 'Ajouter un élément à la liste';

  @override
  String get calendarRepeatTimes => 'Répétitions';

  @override
  String get calendarDayEventHint => 'Anniversaire, jour férié ou note';

  @override
  String get calendarOptionalDetails => 'Détails facultatifs';

  @override
  String get calendarDates => 'Plage de dates';

  @override
  String get calendarTaskTitleHint => 'Titre de la tâche';

  @override
  String get calendarDescriptionOptionalHint => 'Description (facultatif)';

  @override
  String get calendarLocationOptionalHint => 'Lieu (facultatif)';

  @override
  String get calendarCloseTooltip => 'Fermer';

  @override
  String get calendarAddTaskInputHint =>
      'Ajouter une tâche... (ex. \"Réunion demain à 15h\")';

  @override
  String get calendarBranch => 'Branche';

  @override
  String get calendarPickDifferentTask =>
      'Choisir une autre tâche pour ce créneau';

  @override
  String get calendarSyncRequest => 'Demander';

  @override
  String get calendarSyncPush => 'Envoyer';

  @override
  String get calendarImportant => 'Essentiel';

  @override
  String get calendarUrgent => 'Prioritaire';

  @override
  String get calendarClearSchedule => 'Effacer le planning';

  @override
  String get calendarEditTaskTooltip => 'Modifier la tâche';

  @override
  String get calendarDeleteTaskTooltip => 'Supprimer la tâche';

  @override
  String get calendarBackToChats => 'Retour aux discussions';

  @override
  String get calendarBackToLogin => 'Retour à la connexion';

  @override
  String get calendarRemindersSection => 'Rappels';

  @override
  String get settingsAutoLoadEmailImages =>
      'Charger automatiquement les images des e-mails';

  @override
  String get settingsAutoLoadEmailImagesDescription =>
      'Peut révéler votre adresse IP aux expéditeurs';

  @override
  String get settingsAutoDownloadImages =>
      'Télécharger automatiquement les images';

  @override
  String get settingsAutoDownloadImagesDescription =>
      'S’applique lorsque ce chat autorise les téléchargements automatiques.';

  @override
  String get settingsAutoDownloadVideos =>
      'Télécharger automatiquement les vidéos';

  @override
  String get settingsAutoDownloadVideosDescription =>
      'S’applique lorsque ce chat autorise les téléchargements automatiques.';

  @override
  String get settingsAutoDownloadDocuments =>
      'Télécharger automatiquement les documents';

  @override
  String get settingsAutoDownloadDocumentsDescription =>
      'S’applique lorsque ce chat autorise les téléchargements automatiques.';

  @override
  String get settingsAutoDownloadArchives =>
      'Télécharger automatiquement les archives';

  @override
  String get settingsAutoDownloadArchivesDescription =>
      'S’applique lorsque ce chat autorise les téléchargements automatiques.';

  @override
  String get settingsAutoDownloadScopeAlways => 'Toujours';

  @override
  String get settingsAutoDownloadScopeTrustedContacts =>
      'Uniquement pour les contacts de confiance.';

  @override
  String get emailContactsImportTitle => 'Importer des contacts';

  @override
  String get emailContactsImportSubtitle =>
      'CSVs Gmail, Outlook, Yahoo ou vCards.';

  @override
  String get emailContactsImportFileAccessError =>
      'Impossible d’accéder au fichier sélectionné.';

  @override
  String get emailContactsImportAction => 'Importer';

  @override
  String get emailContactsImportFormatLabel => 'Type';

  @override
  String get emailContactsImportFileLabel => 'Fichier';

  @override
  String get emailContactsImportNoFile => 'Aucun fichier sélectionné';

  @override
  String get emailContactsImportChooseFile => 'Choisir un fichier';

  @override
  String get emailContactsImportFormatGmail => 'Gmail CSV';

  @override
  String get emailContactsImportFormatOutlook => 'Outlook CSV';

  @override
  String get emailContactsImportFormatYahoo => 'Yahoo CSV';

  @override
  String get emailContactsImportFormatGenericCsv => 'CSV générique';

  @override
  String get emailContactsImportFormatVcard => 'vCard (VCF)';

  @override
  String get emailContactsImportNoValidContacts =>
      'Aucun contact valide trouvé.';

  @override
  String get emailContactsImportAccountRequired =>
      'Configurez l’e-mail avant d’importer des contacts.';

  @override
  String get emailContactsImportEmptyFile => 'Le fichier sélectionné est vide.';

  @override
  String get emailContactsImportReadFailure => 'Impossible de lire ce fichier.';

  @override
  String get emailContactsImportFileTooLarge =>
      'Ce fichier est trop volumineux pour être importé.';

  @override
  String get emailContactsImportUnsupportedFile =>
      'Type de fichier non pris en charge.';

  @override
  String get emailContactsImportNoContacts =>
      'Aucun contact trouvé dans ce fichier.';

  @override
  String get emailContactsImportTooManyContacts =>
      'Ce fichier contient trop de contacts à importer.';

  @override
  String get emailContactsImportFailed => 'Échec de l’importation.';

  @override
  String emailContactsImportSuccess(
    Object imported,
    Object duplicates,
    Object invalid,
    Object failed,
  ) {
    return 'Contacts importés : $imported. $duplicates doublons, $invalid invalides, $failed échecs.';
  }

  @override
  String get fanOutErrorNoRecipients =>
      'Sélectionnez au moins un destinataire.';

  @override
  String get fanOutErrorResolveFailed =>
      'Impossible de résoudre les destinataires.';

  @override
  String fanOutErrorTooManyRecipients(int max) {
    return 'Trop de destinataires (max $max).';
  }

  @override
  String get fanOutErrorEmptyMessage =>
      'Ajoutez un message ou une pièce jointe avant l’envoi.';

  @override
  String get fanOutErrorInvalidShareToken =>
      'Le jeton de partage est invalide.';

  @override
  String get emailForwardingGuideTitle => 'Connecter un e-mail existant';

  @override
  String get emailForwardingGuideSubtitle =>
      'Transférez des e-mails depuis Gmail, Outlook ou tout autre fournisseur.';

  @override
  String get emailForwardingWelcomeTitle => 'Bienvenue sur Axichat';

  @override
  String get emailForwardingGuideIntro =>
      'Conservez votre boîte de réception actuelle et transférez les e-mails vers Axichat.';

  @override
  String get emailForwardingGuideLinkExistingEmailTitle =>
      'Lier un e-mail existant';

  @override
  String get emailForwardingGuideAddressHint =>
      'Saisissez cette adresse dans les paramètres de transfert de votre fournisseur.';

  @override
  String get emailForwardingGuideAddressFallback =>
      'Votre adresse Axichat apparaîtra ici.';

  @override
  String get emailForwardingGuideLinksTitle =>
      'Cela doit être fait dans votre client de messagerie existant. Votre fournisseur devrait avoir des instructions. Si vous utilisez Gmail ou Outlook, voici leurs guides :';

  @override
  String get emailForwardingGuideLinksSubtitle =>
      'Consultez l’aide de votre fournisseur, ou commencez ici :';

  @override
  String get emailForwardingWelcomeSetupFrom => 'Setup forwarding from:';

  @override
  String get emailForwardingWelcomeOtherProviderHint =>
      'If you use another provider, their website should have instructions as well.';

  @override
  String get emailForwardingGuideNotificationsTitle =>
      'Notifications de messages';

  @override
  String get emailForwardingGuideSettingsHint =>
      'Cela peut être fait plus tard dans les paramètres.';

  @override
  String get emailForwardingGuideSkipLabel => 'Ignorer pour l’instant';

  @override
  String get emailForwardingProviderGmail => 'Gmail';

  @override
  String get emailForwardingProviderOutlook => 'Outlook';

  @override
  String get chatChooseTextToAdd => 'Choisir le texte à ajouter';

  @override
  String get notificationChannelMessages => 'Canal des messages';

  @override
  String get notificationNewMessageTitle => 'Nouveau message';

  @override
  String get notificationOpenAction => 'Ouvrir la notification';

  @override
  String get notificationAttachmentLabel => 'Pièce jointe';

  @override
  String notificationAttachmentLabelWithName(String filename) {
    return 'Pièce jointe : $filename';
  }

  @override
  String get notificationReactionFallback => 'Nouvelle réaction';

  @override
  String notificationReactionLabel(String reaction) {
    return 'Réaction : $reaction';
  }

  @override
  String get notificationWebxdcFallback => 'Nouvelle mise à jour';

  @override
  String get shareTokenFooterLabel => 'Merci de ne pas supprimer :';

  @override
  String get notificationBackgroundConnectionDisabledTitle =>
      'Connexion en arrière-plan désactivée';

  @override
  String get notificationBackgroundConnectionDisabledBody =>
      'Android a bloqué le service de messagerie d\'Axichat. Réactivez les autorisations d\'overlay et d\'optimisation de la batterie pour rétablir la messagerie en arrière-plan.';

  @override
  String get calendarReminderDeadlineNow => 'Échéance maintenant';

  @override
  String calendarReminderDueIn(Object duration) {
    return 'Échéance dans $duration';
  }

  @override
  String get calendarReminderStartingNow => 'Commence maintenant';

  @override
  String calendarReminderStartsIn(Object duration) {
    return 'Commence dans $duration';
  }

  @override
  String get calendarReminderHappeningToday => 'Aujourd\'hui';

  @override
  String calendarReminderIn(Object duration) {
    return 'Dans $duration';
  }

  @override
  String calendarReminderDurationDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# jours',
      one: '# jour',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderDurationHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# heures',
      one: '# heure',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderDurationMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# min',
      one: '# min',
    );
    return '$_temp0';
  }

  @override
  String get calendarExportCalendar => 'Exporter le calendrier';

  @override
  String get calendarImportCalendar => 'Importer le calendrier';

  @override
  String get calendarSyncStatusSyncing => 'Synchronisation...';

  @override
  String get calendarSyncStatusFailed => 'Échec de la synchronisation';

  @override
  String get calendarSyncStatusSynced => 'Synchronisé';

  @override
  String get calendarSyncStatusIdle => 'Pas encore synchronisé';

  @override
  String calendarSplitTaskAtTime(Object time) {
    return 'Diviser la tâche à $time';
  }

  @override
  String get calendarSplitSelectTime => 'Sélectionner l\'heure de division';

  @override
  String get calendarTaskMarkIncomplete => 'Marquer comme incomplète';

  @override
  String get calendarTaskMarkComplete => 'Marquer comme terminée';

  @override
  String get calendarTaskRemoveImportant => 'Retirer le marqueur important';

  @override
  String get calendarTaskMarkImportant => 'Marquer comme important';

  @override
  String get calendarTaskRemoveUrgent => 'Retirer le marqueur urgent';

  @override
  String get calendarTaskMarkUrgent => 'Marquer comme urgent';

  @override
  String get calendarDeselectTask => 'Désélectionner la tâche';

  @override
  String get calendarAddTaskToSelection => 'Ajouter la tâche à la sélection';

  @override
  String get calendarSelectTask => 'Sélectionner la tâche';

  @override
  String get calendarDeselectAllRepeats =>
      'Désélectionner toutes les répétitions';

  @override
  String get calendarAddAllRepeats => 'Ajouter toutes les répétitions';

  @override
  String get calendarSelectAllRepeats => 'Sélectionner toutes les répétitions';

  @override
  String get calendarAddToSelection => 'Ajouter à la sélection';

  @override
  String get calendarSelectAllTasks => 'Sélectionner toutes les tâches';

  @override
  String get calendarExitSelectionMode => 'Quitter le mode de sélection';

  @override
  String get calendarSplitTask => 'Diviser la tâche';

  @override
  String get calendarCopyTemplate => 'Copier le modèle';

  @override
  String calendarTaskAddedMessage(Object title) {
    return 'Tâche \"$title\" ajoutée';
  }

  @override
  String calendarTasksAddedMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# tâches ajoutées',
      one: '# tâche ajoutée',
    );
    return '$_temp0';
  }

  @override
  String calendarTaskRemovedMessage(Object title) {
    return 'Tâche \"$title\" supprimée';
  }

  @override
  String calendarTasksRemovedMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# tâches supprimées',
      one: '# tâche supprimée',
    );
    return '$_temp0';
  }

  @override
  String get calendarTaskRemovedTitle => 'Tâche supprimée';

  @override
  String get calendarDeadlinePlaceholder => 'Définir une échéance (optionnel)';

  @override
  String get calendarTaskDescriptionHint => 'Description (optionnelle)';

  @override
  String get calendarTaskLocationHint => 'Lieu (optionnel)';

  @override
  String get calendarPickDateLabel => 'Choisir la date';

  @override
  String get calendarPickTimeLabel => 'Choisir l\'heure';

  @override
  String get calendarReminderLabel => 'Rappel';

  @override
  String get calendarEditDayEventTitle => 'Modifier l\'événement du jour';

  @override
  String get calendarNewDayEventTitle => 'Nouvel événement du jour';

  @override
  String get commonAdd => 'Ajouter';

  @override
  String get commonTitle => 'Titre';

  @override
  String get calendarShareUnavailable =>
      'Le partage du calendrier n\'est pas disponible.';

  @override
  String get calendarShareAvailability => 'Partager la disponibilité';

  @override
  String get calendarShortcutUndo => 'Ctrl/Cmd+Z';

  @override
  String get calendarShortcutRedo => 'Ctrl/Cmd+Shift+Z';

  @override
  String commonShortcutTooltip(Object tooltip, Object shortcut) {
    return '$tooltip ($shortcut)';
  }

  @override
  String get calendarDragCanceled => 'Glisser annulé';

  @override
  String get calendarZoomLabelCompact => 'Condensé';

  @override
  String get calendarZoomLabelComfort => 'Confort';

  @override
  String get calendarZoomLabelExpanded => 'Étendu';

  @override
  String calendarZoomLabelMinutes(Object minutes) {
    return '${minutes}m';
  }

  @override
  String get calendarGuestModeNotice =>
      'Mode invité - les tâches sont enregistrées uniquement sur cet appareil';

  @override
  String get calendarGuestSignUpToSync => 'S\'inscrire pour synchroniser';

  @override
  String get calendarGuestExportNoData =>
      'Aucune donnée de calendrier à exporter.';

  @override
  String get calendarGuestExportTitle => 'Exporter le calendrier invité';

  @override
  String get calendarGuestExportShareSubject =>
      'Export du calendrier invité Axichat';

  @override
  String calendarGuestExportShareText(Object format) {
    return 'Export du calendrier invité Axichat ($format)';
  }

  @override
  String calendarGuestExportFailed(Object error) {
    return 'Échec de l\'export du calendrier : $error';
  }

  @override
  String get calendarGuestImportTitle => 'Importer le calendrier';

  @override
  String get calendarGuestImportWarningMessage =>
      'L\'importation fusionnera les données et remplacera les éléments correspondants dans votre calendrier actuel. Continuer ?';

  @override
  String get calendarGuestImportConfirmLabel => 'Importer';

  @override
  String get calendarGuestImportFileAccessError =>
      'Impossible d\'accéder au fichier sélectionné.';

  @override
  String get calendarGuestImportNoData =>
      'Aucune donnée de calendrier détectée dans le fichier sélectionné.';

  @override
  String get calendarGuestImportFailed =>
      'L\'importation n\'a pas pu appliquer les modifications.';

  @override
  String get calendarGuestImportSuccess => 'Données de calendrier importées.';

  @override
  String get calendarGuestImportNoTasks =>
      'Aucune tâche détectée dans le fichier sélectionné.';

  @override
  String calendarGuestImportTasksSuccess(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# tâches',
      one: '# tâche',
    );
    return 'Importé $_temp0.';
  }

  @override
  String calendarGuestImportError(Object error) {
    return 'Échec de l\'importation : $error';
  }

  @override
  String get blocklistEmpty => 'Personne bloqué';

  @override
  String get chatMessageSubjectLabel => 'Objet';

  @override
  String get chatMessageRecipientsLabel => 'Destinataires';

  @override
  String get chatMessageAlsoSentToLabel => 'Également envoyé à';

  @override
  String chatMessageFromLabel(Object sender) {
    return 'De $sender';
  }

  @override
  String get chatMessageReactionsLabel => 'Réactions';

  @override
  String get commonClearSelection => 'Effacer la sélection';

  @override
  String commonSelectedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# sélectionnés',
      one: '# sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get profileDeviceFingerprint => 'Empreinte de l\'appareil';

  @override
  String get profileFingerprintUnavailable => 'Empreinte indisponible';

  @override
  String get axiVersionCurrentFeatures => 'Fonctionnalités actuelles :';

  @override
  String get axiVersionCurrentFeaturesList => 'Messagerie, présence';

  @override
  String get axiVersionComingNext => 'À venir :';

  @override
  String get axiVersionComingNextList => 'Chat de groupe, multimédia';

  @override
  String get commonMoreOptions => 'Plus d\'options';

  @override
  String get commonAreYouSure => 'Êtes-vous sûr ?';

  @override
  String get commonAll => 'Tous';

  @override
  String get languageSystem => 'Système';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageGerman => 'Allemand';

  @override
  String get languageSpanish => 'Espagnol';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageChineseSimplified => 'Chinois simplifié';

  @override
  String get languageChineseHongKong => 'Chinois (Hong Kong)';

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
      'Aucune donnée de calendrier disponible pour l’exportation.';

  @override
  String get calendarTransferExportSubject =>
      'Exportation du calendrier Axichat';

  @override
  String calendarTransferExportText(String format) {
    return 'Exportation du calendrier Axichat ($format)';
  }

  @override
  String get calendarTransferExportReady => 'Export prêt à être partagé.';

  @override
  String calendarTransferExportFailed(String error) {
    return 'Échec de l’exportation du calendrier : $error';
  }

  @override
  String get calendarTransferImportWarning =>
      'L’importation fusionnera les données et remplacera les éléments correspondants de votre calendrier actuel. Continuer ?';

  @override
  String get calendarTransferImportConfirm => 'Importer';

  @override
  String get calendarTransferFileAccessFailed =>
      'Impossible d’accéder au fichier sélectionné.';

  @override
  String get calendarTransferNoDataImport =>
      'Aucune donnée de calendrier détectée dans le fichier sélectionné.';

  @override
  String get calendarTransferImportFailed =>
      'Impossible d’appliquer les changements de l’importation.';

  @override
  String get calendarTransferImportSuccess =>
      'Données de calendrier importées.';

  @override
  String get calendarTransferNoTasksDetected =>
      'Aucune tâche détectée dans le fichier sélectionné.';

  @override
  String calendarTransferImportTasksSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Importé $count tâche$_temp0.';
  }

  @override
  String calendarTransferImportFailedWithError(String error) {
    return 'Échec de l’importation : $error';
  }

  @override
  String get calendarExportChooseFormat => 'Choisir le format d’exportation';

  @override
  String get calendarAvailabilityWindowsTitle => 'Fenêtres de disponibilité';

  @override
  String get calendarAvailabilityWindowsSubtitle =>
      'Définissez les plages horaires que vous souhaitez partager.';

  @override
  String get calendarAvailabilityWindowsLabel => 'Fenêtres';

  @override
  String get calendarAvailabilityNoWindows => 'Aucune fenêtre pour le moment.';

  @override
  String get calendarAvailabilityWindowLabel => 'Fenêtre';

  @override
  String get calendarAvailabilitySummaryLabel => 'Résumé';

  @override
  String get calendarAvailabilitySummaryHint => 'Libellé facultatif';

  @override
  String get calendarAvailabilityNotesLabel => 'Remarques';

  @override
  String get calendarAvailabilityNotesHint => 'Détails facultatifs';

  @override
  String get calendarAvailabilityAddWindow => 'Ajouter une fenêtre';

  @override
  String get calendarAvailabilitySaveWindows => 'Enregistrer les fenêtres';

  @override
  String get calendarAvailabilityEmptyWindowsError =>
      'Ajoutez au moins une fenêtre de disponibilité.';

  @override
  String get calendarAvailabilityInvalidRangeError =>
      'Vérifiez les plages avant d’enregistrer.';

  @override
  String get calendarTaskShareTitle => 'Partager la tâche';

  @override
  String get calendarTaskShareSubtitle =>
      'Envoyez une tâche à un chat au format .ics.';

  @override
  String get calendarTaskShareTarget => 'Partager avec';

  @override
  String get calendarTaskShareEditAccess => 'Accès en modification';

  @override
  String get calendarTaskShareReadOnlyLabel => 'Lecture seule';

  @override
  String get calendarTaskShareEditableLabel => 'Modifiable';

  @override
  String get calendarTaskShareReadOnlyHint =>
      'Les destinataires peuvent voir cette tâche, mais vous seul pouvez la modifier.';

  @override
  String get calendarTaskShareEditableHint =>
      'Les destinataires peuvent modifier cette tâche, et les mises à jour se synchronisent avec votre calendrier.';

  @override
  String get calendarTaskShareReadOnlyDisabledHint =>
      'La modification est disponible uniquement pour les calendriers de chat.';

  @override
  String get calendarTaskShareMissingChats => 'Aucun chat disponible.';

  @override
  String get calendarTaskShareMissingRecipient =>
      'Sélectionnez un chat avec lequel partager.';

  @override
  String get calendarTaskShareServiceUnavailable =>
      'Le partage de calendrier n’est pas disponible.';

  @override
  String get calendarTaskShareDenied =>
      'Les cartes de calendrier sont désactivées pour votre rôle dans ce salon.';

  @override
  String get calendarTaskShareSendFailed => 'Échec du partage de la tâche.';

  @override
  String get calendarTaskShareSuccess => 'Tâche partagée.';

  @override
  String get commonTimeJustNow => 'À l’instant';

  @override
  String commonTimeMinutesAgo(int count) {
    return 'Il y a $count min';
  }

  @override
  String commonTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Il y a $count heure$_temp0';
  }

  @override
  String commonTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Il y a $count jour$_temp0';
  }

  @override
  String commonTimeWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Il y a $count semaine$_temp0';
  }

  @override
  String get commonTimeMonthsAgo => 'Il y a des mois';

  @override
  String get connectivityStatusConnected => 'Connecté';

  @override
  String get connectivityStatusConnecting => 'Connexion…';

  @override
  String get connectivityStatusNotConnected => 'Non connecté.';

  @override
  String get connectivityStatusFailed => 'Échec de la connexion.';

  @override
  String get commonShare => 'Partager';

  @override
  String get commonRecipients => 'Destinataires';

  @override
  String commonRangeLabel(String start, String end) {
    return '$start - $end';
  }

  @override
  String get commonOwnerFallback => 'propriétaire';

  @override
  String commonDurationMinutes(int count) {
    return '$count min';
  }

  @override
  String commonDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count heure$_temp0';
  }

  @override
  String commonDurationMinutesShort(int count) {
    return '$count min';
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
  String get calendarAvailabilityShareTitle => 'Partager la disponibilité';

  @override
  String get calendarAvailabilityShareSubtitle =>
      'Choisissez une plage, modifiez libre/occupé, puis partagez.';

  @override
  String get calendarAvailabilityShareChatSubtitle =>
      'Choisissez une plage, modifiez libre/occupé, puis partagez dans ce chat.';

  @override
  String get calendarAvailabilityShareRangeLabel => 'Plage';

  @override
  String get calendarAvailabilityShareEditHint =>
      'Touchez pour scinder, faites glisser pour redimensionner ou basculez libre/occupé.';

  @override
  String get calendarAvailabilityShareSavePreset =>
      'Enregistrer comme préréglage';

  @override
  String get calendarAvailabilitySharePresetNameTitle =>
      'Enregistrer la feuille libre/occupé';

  @override
  String get calendarAvailabilitySharePresetNameLabel => 'Nom';

  @override
  String get calendarAvailabilitySharePresetNameHint => 'Horaires de l’équipe';

  @override
  String get calendarAvailabilitySharePresetNameMissing =>
      'Saisissez un nom pour enregistrer cette feuille.';

  @override
  String get calendarAvailabilityShareInvalidRange =>
      'Sélectionnez une plage valide à partager.';

  @override
  String get calendarAvailabilityShareMissingJid =>
      'Le partage de calendrier n’est pas disponible.';

  @override
  String get calendarAvailabilityShareRecipientsRequired =>
      'Sélectionnez au moins un destinataire.';

  @override
  String get calendarAvailabilityShareMissingChats =>
      'Aucun chat éligible disponible.';

  @override
  String get calendarAvailabilityShareLockedChatUnavailable =>
      'Ce chat ne peut pas recevoir de disponibilités.';

  @override
  String get calendarAvailabilityShareSuccess => 'Disponibilité partagée.';

  @override
  String get calendarAvailabilityShareFailed =>
      'Échec du partage de la disponibilité.';

  @override
  String get calendarAvailabilitySharePartialFailure =>
      'Certaines partages n’ont pas pu être envoyés.';

  @override
  String get calendarAvailabilitySharePresetLabel => 'Feuilles récentes';

  @override
  String get calendarAvailabilitySharePresetEmpty =>
      'Pas encore de feuilles récentes.';

  @override
  String calendarAvailabilityShareRecentPreset(String range) {
    return 'Partagé $range';
  }

  @override
  String get calendarAvailabilityPreviewEmpty =>
      'Aucun intervalle de disponibilité.';

  @override
  String calendarAvailabilityPreviewMore(int count) {
    return 'et $count de plus';
  }

  @override
  String get calendarTaskTitleRequired =>
      'Saisissez un titre de tâche avant de continuer.';

  @override
  String calendarTaskTitleTooLong(int max) {
    return 'Le titre de la tâche est trop long. Utilisez moins de $max caractères.';
  }

  @override
  String calendarTaskTitleLimitWarning(int max) {
    return 'Les titres de tâches sont limités à $max caractères. Raccourcissez ce texte ou déplacez les détails dans la description avant d’enregistrer.';
  }

  @override
  String calendarTaskTitleCharacterCount(int count, int limit) {
    return '$count / $limit caractères';
  }

  @override
  String get axiVersionWelcomeTitle => 'Bienvenue sur Axichat';

  @override
  String axiVersionLabel(String version) {
    return 'v$version';
  }

  @override
  String get axiVersionTagAlpha => 'alpha';

  @override
  String get calendarSyncWarningSnapshotTitle =>
      'Synchronisation du calendrier';

  @override
  String get calendarSyncWarningSnapshotMessage =>
      'Instantane du calendrier indisponible. Exportez le JSON du calendrier depuis un autre appareil et importez-le ici pour le restaurer.';

  @override
  String commonLabelValue(String label, String value) {
    return '$label : $value';
  }

  @override
  String get calendarAvailabilityRequestTitle => 'Demander un horaire';

  @override
  String get calendarAvailabilityRequestSubtitle =>
      'Choisissez un créneau libre et partagez les détails.';

  @override
  String get calendarAvailabilityRequestDetailsLabel => 'Détails';

  @override
  String get calendarAvailabilityRequestRangeLabel => 'Plage';

  @override
  String get calendarAvailabilityRequestTitleLabel => 'Titre';

  @override
  String get calendarAvailabilityRequestTitlePlaceholder =>
      'À quoi cela sert-il ?';

  @override
  String get calendarAvailabilityRequestDescriptionLabel => 'Détails';

  @override
  String get calendarAvailabilityRequestDescriptionPlaceholder =>
      'Ajouter du contexte (facultatif).';

  @override
  String get calendarAvailabilityRequestSendLabel => 'Envoyer la demande';

  @override
  String get calendarAvailabilityRequestInvalidRange =>
      'Choisissez une plage horaire valide.';

  @override
  String get calendarAvailabilityRequestNotFree =>
      'Sélectionnez un créneau libre avant d’envoyer.';

  @override
  String get calendarAvailabilityDecisionTitle => 'Accepter la demande';

  @override
  String get calendarAvailabilityDecisionSubtitle =>
      'Choisissez quels calendriers doivent le recevoir.';

  @override
  String get calendarAvailabilityDecisionPersonalLabel =>
      'Ajouter au calendrier personnel';

  @override
  String get calendarAvailabilityDecisionChatLabel =>
      'Ajouter au calendrier du chat';

  @override
  String get calendarAvailabilityDecisionMissingSelection =>
      'Sélectionnez au moins un calendrier.';

  @override
  String get calendarAvailabilityDecisionSummaryLabel => 'Demandé';

  @override
  String get calendarAvailabilityRequestTitleFallback => 'Heure demandée';

  @override
  String get calendarAvailabilityShareFallback => 'Disponibilité partagée';

  @override
  String get calendarAvailabilityRequestFallback => 'Demande de disponibilité';

  @override
  String get calendarAvailabilityResponseAcceptedFallback =>
      'Disponibilité acceptée';

  @override
  String get calendarAvailabilityResponseDeclinedFallback =>
      'Disponibilité refusée';

  @override
  String get calendarFreeBusyFree => 'Libre';

  @override
  String get calendarFreeBusyBusy => 'Occupé';

  @override
  String get calendarFreeBusyTentative => 'Provisoire';

  @override
  String get calendarFreeBusyEditTitle => 'Modifier la disponibilite';

  @override
  String get calendarFreeBusyEditSubtitle =>
      'Ajustez la plage horaire et le statut.';

  @override
  String get calendarFreeBusyToggleLabel => 'Libre/Occupe';

  @override
  String get calendarFreeBusySplitLabel => 'Scinder';

  @override
  String get calendarFreeBusySplitTooltip => 'Scinder le segment';

  @override
  String get calendarFreeBusyMarkFree => 'Marquer comme libre';

  @override
  String get calendarFreeBusyMarkBusy => 'Marquer comme occupe';

  @override
  String get calendarFreeBusyRangeLabel => 'Plage';

  @override
  String commonWeekdayDayLabel(String weekday, int day) {
    return '$weekday, $day';
  }

  @override
  String get calendarFragmentChecklistLabel => 'Liste de controle';

  @override
  String get calendarFragmentChecklistSeparator => ', ';

  @override
  String calendarFragmentChecklistSummary(String summary) {
    return 'Liste de controle : $summary';
  }

  @override
  String calendarFragmentChecklistSummaryMore(String summary, int count) {
    return 'Liste de controle : $summary et $count de plus';
  }

  @override
  String get calendarFragmentRemindersLabel => 'Rappels';

  @override
  String calendarFragmentReminderStartSummary(String summary) {
    return 'Debut : $summary';
  }

  @override
  String calendarFragmentReminderDeadlineSummary(String summary) {
    return 'Echeance : $summary';
  }

  @override
  String calendarFragmentRemindersSummary(String summary) {
    return 'Rappels : $summary';
  }

  @override
  String get calendarFragmentReminderSeparator => ', ';

  @override
  String get calendarFragmentEventTitleFallback => 'Evenement sans titre';

  @override
  String calendarFragmentDayEventSummary(String title, String range) {
    return '$title (Evenement de jour : $range)';
  }

  @override
  String calendarFragmentFreeBusySummary(String label, String range) {
    return '$label (Fenetre : $range)';
  }

  @override
  String get calendarFragmentCriticalPathLabel => 'Chemin critique';

  @override
  String calendarFragmentCriticalPathSummary(String name) {
    return 'Chemin critique : $name';
  }

  @override
  String calendarFragmentCriticalPathProgress(int completed, int total) {
    return '$completed/$total termine';
  }

  @override
  String calendarFragmentCriticalPathDetail(String name, String progress) {
    return '$name (Chemin critique : $progress)';
  }

  @override
  String calendarFragmentAvailabilitySummary(String summary, String range) {
    return '$summary (Disponibilite : $range)';
  }

  @override
  String calendarFragmentAvailabilityFallback(String range) {
    return 'Disponibilite : $range';
  }

  @override
  String calendarMonthOverflowMore(int count) {
    return '+$count de plus';
  }

  @override
  String commonPercentLabel(int value) {
    return '$value %';
  }

  @override
  String get commonStart => 'Debut';

  @override
  String get commonEnd => 'Fin';

  @override
  String get commonSelectStart => 'Selectionner le debut';

  @override
  String get commonSelectEnd => 'Selectionner la fin';

  @override
  String get commonTimeLabel => 'Heure';

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
    return '$head et $tail';
  }

  @override
  String get calendarAlarmsTitle => 'Alarmes';

  @override
  String get calendarAlarmsHelper =>
      'Les rappels sont exportes comme alarmes d’affichage.';

  @override
  String get calendarAlarmsEmpty => 'Aucune alarme pour le moment';

  @override
  String get calendarAlarmAddTooltip => 'Ajouter une alarme';

  @override
  String get calendarAlarmRemoveTooltip => 'Supprimer l’alarme';

  @override
  String calendarAlarmItemLabel(int index) {
    return 'Alarme $index';
  }

  @override
  String get calendarAlarmActionLabel => 'Type d’action';

  @override
  String get calendarAlarmActionDisplay => 'Affichage';

  @override
  String get calendarAlarmActionAudio => 'Son';

  @override
  String get calendarAlarmActionEmail => 'E-mail';

  @override
  String get calendarAlarmActionProcedure => 'Procédure d’alarme';

  @override
  String get calendarAlarmActionProcedureHelper =>
      'Les alarmes de procedure sont importees en lecture seule.';

  @override
  String get calendarAlarmTriggerLabel => 'Declencheur';

  @override
  String get calendarAlarmTriggerRelative => 'Relatif';

  @override
  String get calendarAlarmTriggerAbsolute => 'Absolu';

  @override
  String get calendarAlarmAbsolutePlaceholder => 'Choisir la date et l’heure';

  @override
  String get calendarAlarmRelativeToLabel => 'Par rapport a';

  @override
  String get calendarAlarmRelativeToStart => 'Debut';

  @override
  String get calendarAlarmRelativeToEnd => 'Fin';

  @override
  String get calendarAlarmDirectionLabel => 'Sens';

  @override
  String get calendarAlarmDirectionBefore => 'Avant';

  @override
  String get calendarAlarmDirectionAfter => 'Apres';

  @override
  String get calendarAlarmOffsetLabel => 'Decalage';

  @override
  String get calendarAlarmOffsetHint => 'Quantite';

  @override
  String get calendarAlarmRepeatLabel => 'Repeter';

  @override
  String get calendarAlarmRepeatCountHint => 'Fois';

  @override
  String get calendarAlarmRepeatEveryLabel => 'Chaque';

  @override
  String get calendarAlarmRecipientsLabel => 'Destinataires';

  @override
  String get calendarAlarmRecipientAddressHint => 'Ajouter un e-mail';

  @override
  String get calendarAlarmRecipientNameHint => 'Nom (facultatif)';

  @override
  String get calendarAlarmRecipientRemoveTooltip => 'Supprimer le destinataire';

  @override
  String calendarAlarmRecipientDisplay(String name, String address) {
    return '$name <$address>';
  }

  @override
  String get calendarAlarmAcknowledgedLabel => 'Confirme';

  @override
  String get calendarAlarmUnitMinutes => 'min';

  @override
  String get calendarAlarmUnitHours => 'Heures';

  @override
  String get calendarAlarmUnitDays => 'Jours';

  @override
  String get calendarAlarmUnitWeeks => 'Semaines';

  @override
  String get taskShareTitleFallback => 'Tache sans titre';

  @override
  String taskShareTitleLabel(String title) {
    return 'Tache \"$title\"';
  }

  @override
  String taskShareTitleWithQualifiers(String title, String qualifiers) {
    return 'Tache \"$title\" ($qualifiers)';
  }

  @override
  String get taskShareQualifierDone => 'terminee';

  @override
  String get taskSharePriorityImportant => 'importante';

  @override
  String get taskSharePriorityUrgent => 'urgente';

  @override
  String get taskSharePriorityCritical => 'critique';

  @override
  String taskShareLocationClause(String location) {
    return ' a $location';
  }

  @override
  String get taskShareScheduleNoTime => ' sans horaire defini';

  @override
  String taskShareScheduleSameDay(
    String date,
    String startTime,
    String endTime,
  ) {
    return ' le $date de $startTime a $endTime';
  }

  @override
  String taskShareScheduleRange(String startDateTime, String endDateTime) {
    return ' de $startDateTime a $endDateTime';
  }

  @override
  String taskShareScheduleStartDuration(
    String date,
    String time,
    String duration,
  ) {
    return ' le $date a $time pour $duration';
  }

  @override
  String taskShareScheduleStart(String date, String time) {
    return ' le $date a $time';
  }

  @override
  String taskShareScheduleEnding(String dateTime) {
    return ' se termine $dateTime';
  }

  @override
  String get taskShareRecurrenceEveryOtherDay => ' un jour sur deux';

  @override
  String taskShareRecurrenceEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: 'jour',
    );
    return ' chaque $_temp0';
  }

  @override
  String taskShareRecurrenceEveryWeekdays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours ouvres',
      one: 'jour ouvre',
    );
    return ' chaque $_temp0';
  }

  @override
  String taskShareRecurrenceEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines',
      one: 'semaine',
    );
    return ' chaque $_temp0';
  }

  @override
  String taskShareRecurrenceEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois',
      one: 'mois',
    );
    return ' chaque $_temp0';
  }

  @override
  String get taskShareRecurrenceEveryOtherYear => ' un an sur deux';

  @override
  String taskShareRecurrenceEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ans',
      one: 'an',
    );
    return ' chaque $_temp0';
  }

  @override
  String taskShareRecurrenceOnDays(String days) {
    return ' le $days';
  }

  @override
  String taskShareRecurrenceUntil(String date) {
    return ' jusqu’au $date';
  }

  @override
  String taskShareRecurrenceCount(int count) {
    return ' pour $count occurrences';
  }

  @override
  String taskShareDeadlineClause(String dateTime) {
    return ', a rendre avant $dateTime';
  }

  @override
  String taskShareNotesClause(String notes) {
    return ' Notes : $notes.';
  }

  @override
  String taskShareChangesClause(String changes) {
    return ' Modifications : $changes';
  }

  @override
  String taskShareOverrideMoveTo(String dateTime) {
    return 'deplacer a $dateTime';
  }

  @override
  String taskShareOverrideDuration(String duration) {
    return 'pendant $duration';
  }

  @override
  String taskShareOverrideEndAt(String dateTime) {
    return 'se termine a $dateTime';
  }

  @override
  String taskShareOverridePriority(String priority) {
    return 'priorite $priority';
  }

  @override
  String get taskShareOverrideCancelled => 'annulee';

  @override
  String get taskShareOverrideDone => 'terminee';

  @override
  String taskShareOverrideRenameTo(String title) {
    return 'renommer en \"$title\"';
  }

  @override
  String taskShareOverrideNotes(String notes) {
    return 'notes « $notes »';
  }

  @override
  String taskShareOverrideLocation(String location) {
    return 'lieu \"$location\"';
  }

  @override
  String get taskShareOverrideNoChanges => 'aucun changement';

  @override
  String taskShareOverrideSegment(String dateTime, String actions) {
    return 'Le $dateTime : $actions';
  }

  @override
  String get calendarTaskCopiedToClipboard =>
      'Tache copiee dans le presse-papiers';

  @override
  String get calendarTaskSplitRequiresSchedule =>
      'La tache doit etre planifiee pour etre divisee.';

  @override
  String get calendarTaskSplitTooShort =>
      'La tache est trop courte pour etre divisee.';

  @override
  String get calendarTaskSplitUnable =>
      'Impossible de diviser la tache a ce moment-la.';

  @override
  String get calendarDayEventsLabel => 'Evenements du jour';

  @override
  String get calendarShareAsIcsAction => 'Partager en .ics';

  @override
  String get calendarCompletedLabel => 'Termine';

  @override
  String get calendarDeadlineDueToday => 'A rendre aujourd\'hui';

  @override
  String get calendarDeadlineDueTomorrow => 'A rendre demain';

  @override
  String get calendarExportTasksFilePrefix => 'axichat_taches';

  @override
  String get chatTaskViewTitle => 'Details de la tache';

  @override
  String get chatTaskViewSubtitle => 'Tache en lecture seule.';

  @override
  String get chatTaskViewPreviewLabel => 'Apercu';

  @override
  String get chatTaskViewActionsLabel => 'Actions de la tache';

  @override
  String get chatTaskViewCopyLabel => 'Copier dans le calendrier';

  @override
  String get chatTaskCopyTitle => 'Copier la tache';

  @override
  String get chatTaskCopySubtitle =>
      'Choisissez les calendriers qui doivent la recevoir.';

  @override
  String get chatTaskCopyPreviewLabel => 'Apercu';

  @override
  String get chatTaskCopyCalendarsLabel => 'Calendriers';

  @override
  String get chatTaskCopyPersonalLabel => 'Ajouter au calendrier personnel';

  @override
  String get chatTaskCopyChatLabel => 'Ajouter au calendrier du chat';

  @override
  String get chatTaskCopyConfirmLabel => 'Copier';

  @override
  String get chatTaskCopyMissingSelectionMessage =>
      'Selectionnez au moins un calendrier.';

  @override
  String get chatCriticalPathCopyTitle => 'Copier le chemin critique';

  @override
  String get chatCriticalPathCopySubtitle =>
      'Choisissez les calendriers qui doivent la recevoir.';

  @override
  String get chatCriticalPathCopyPreviewLabel => 'Apercu';

  @override
  String get chatCriticalPathCopyCalendarsLabel => 'Calendriers';

  @override
  String get chatCriticalPathCopyPersonalLabel =>
      'Ajouter au calendrier personnel';

  @override
  String get chatCriticalPathCopyChatLabel => 'Ajouter au calendrier du chat';

  @override
  String get chatCriticalPathCopyConfirmLabel => 'Copier';

  @override
  String get chatCriticalPathCopyMissingSelectionMessage =>
      'Selectionnez au moins un calendrier.';

  @override
  String get chatCriticalPathCopyUnavailableMessage =>
      'Le calendrier est indisponible.';

  @override
  String get chatCriticalPathCopySuccessMessage => 'Chemin critique copie.';

  @override
  String commonBulletLabel(String text) {
    return '• $text';
  }

  @override
  String get chatFilterTitle => 'Messages affiches';

  @override
  String get chatFilterDirectOnlyLabel => 'Direct seulement';

  @override
  String get chatFilterAllLabel => 'Tous';

  @override
  String get calendarFragmentTaskLabel => 'Tache';

  @override
  String get calendarFragmentDayEventLabel => 'Evenement de jour';

  @override
  String get calendarFragmentFreeBusyLabel => 'Libre/occupe';

  @override
  String get calendarFragmentAvailabilityLabel => 'Disponibilite';

  @override
  String get calendarFragmentScheduledLabel => 'Planifie';

  @override
  String get calendarFragmentDueLabel => 'A rendre';

  @override
  String get calendarFragmentUntitledLabel => 'Sans titre';

  @override
  String get calendarFragmentChecklistBullet => '- ';

  @override
  String commonAndMoreLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'et $count de plus',
      one: 'et 1 de plus',
    );
    return '$_temp0';
  }

  @override
  String get commonBulletSymbol => '• ';

  @override
  String get commonLabelSeparator => ': ';

  @override
  String get commonUnknownLabel => 'Inconnu';

  @override
  String get commonBadgeOverflowLabel => '99+';

  @override
  String get commonEllipsis => '…';

  @override
  String get chatMessageDetailsSenderLabel => 'Adresse de l expediteur';

  @override
  String get chatMessageDetailsMetadataLabel => 'Metadonnees du message';

  @override
  String get chatMessageDetailsHeadersLabel => 'En-tetes bruts';

  @override
  String get chatMessageDetailsHeadersActionLabel => 'Voir les en-tetes';

  @override
  String get chatMessageDetailsHeadersNote =>
      'Les en-tetes sont charges depuis le message RFC822 original.';

  @override
  String get chatMessageDetailsHeadersLoadingLabel =>
      'Chargement des en-tetes...';

  @override
  String get chatMessageDetailsHeadersUnavailableLabel =>
      'En-tetes indisponibles.';

  @override
  String get chatMessageDetailsDebugDumpLabel => 'Vidage de debogage Delta';

  @override
  String get chatMessageDetailsDebugDumpActionLabel =>
      'Voir le vidage de debogage';

  @override
  String get chatMessageDetailsDebugDumpNote =>
      'Affiche les champs stockes par Axichat et la charge du message analysee par Delta. Ce n est pas la source MIME brute complete.';

  @override
  String get chatMessageDetailsDebugDumpLoadingLabel =>
      'Chargement du vidage de debogage...';

  @override
  String get chatMessageDetailsDebugDumpUnavailableLabel =>
      'Vidage de debogage indisponible.';

  @override
  String get chatMessageDetailsStanzaIdLabel => 'ID de stanza';

  @override
  String get chatMessageDetailsOriginIdLabel => 'ID d origine';

  @override
  String get chatMessageDetailsOccupantIdLabel => 'ID d occupant';

  @override
  String get chatMessageDetailsDeltaIdLabel => 'ID de message Delta';

  @override
  String get chatMessageDetailsLocalIdLabel => 'ID de message local';

  @override
  String get chatCalendarFragmentShareDeniedMessage =>
      'Les cartes de calendrier sont desactivees pour votre role dans ce salon.';

  @override
  String get chatAvailabilityRequestAccountMissingMessage =>
      'Les demandes de disponibilite ne sont pas disponibles pour le moment.';

  @override
  String get chatAvailabilityRequestEmailUnsupportedMessage =>
      'La disponibilite n est pas disponible pour les chats email.';

  @override
  String get chatAvailabilityRequestInvalidRangeMessage =>
      'L heure demandee pour la disponibilite est invalide.';

  @override
  String get chatAvailabilityRequestCalendarUnavailableMessage =>
      'Calendrier indisponible.';

  @override
  String get chatAvailabilityRequestChatCalendarUnavailableMessage =>
      'Le calendrier du chat est indisponible.';

  @override
  String get chatAvailabilityRequestTaskTitleFallback => 'Heure demandee';

  @override
  String get chatSenderAddressPrefix => 'JID: ';

  @override
  String get chatRecipientVisibilityCcLabel => 'CC';

  @override
  String get chatRecipientVisibilityBccLabel => 'BCC';

  @override
  String get chatInviteRoomFallbackLabel => 'chat de groupe';

  @override
  String get chatInviteBodyLabel => 'Vous avez ete invite a un chat de groupe';

  @override
  String get chatInviteRevokedLabel => 'Invitation revoquee';

  @override
  String chatInviteActionLabel(String roomName) {
    return 'Rejoindre \'$roomName\'';
  }

  @override
  String get chatInviteActionFallbackLabel => 'Rejoindre';

  @override
  String get chatInviteConfirmTitle => 'Accepter l invitation ?';

  @override
  String chatInviteConfirmMessage(String roomName) {
    return 'Rejoindre \'$roomName\' ?';
  }

  @override
  String get chatInviteConfirmLabel => 'Accepter';

  @override
  String get chatChooseTextToAddHint =>
      'Selectionnez une partie du message a envoyer au calendrier ou modifiez-la d abord.';

  @override
  String get chatAttachmentAutoDownloadLabel =>
      'Telecharger automatiquement les pieces jointes dans ce chat';

  @override
  String get chatAttachmentAutoDownloadHintOn =>
      'Les pieces jointes de ce chat se telechargeront automatiquement.';

  @override
  String get chatAttachmentAutoDownloadHintOff =>
      'Les pieces jointes sont bloquees jusqu a votre approbation.';

  @override
  String chatAttachmentCaption(String filename, String size) {
    return '📎 Fichier : $filename ($size)';
  }

  @override
  String get chatAttachmentFallbackLabel => 'Piece jointe';

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
      'La piece jointe depasse la limite du serveur.';

  @override
  String chatAttachmentTooLargeMessage(String limit) {
    return 'La piece jointe depasse la limite du serveur ($limit).';
  }

  @override
  String chatMessageErrorWithBody(String label, String body) {
    return '$label : \"$body\"';
  }

  @override
  String get chatUnreadDividerLabel => 'Non lus';

  @override
  String get messageErrorServiceUnavailableTooltip =>
      'Le service a signale un probleme temporaire.';

  @override
  String get messageErrorServiceUnavailable => 'Service indisponible';

  @override
  String get messageErrorServerNotFound => 'Serveur introuvable';

  @override
  String get messageErrorServerTimeout => 'Delai d attente du serveur';

  @override
  String get messageErrorUnknown => 'Erreur inconnue';

  @override
  String get messageErrorNotEncryptedForDevice =>
      'Non chiffre pour cet appareil';

  @override
  String get messageErrorMalformedKey => 'Cle de chiffrement mal formee';

  @override
  String get messageErrorUnknownSignedPrekey => 'Prekey signee inconnue';

  @override
  String get messageErrorNoDeviceSession => 'Aucune session d appareil';

  @override
  String get messageErrorSkippingTooManyKeys => 'Trop de cles ignorees';

  @override
  String get messageErrorInvalidHmac => 'HMAC invalide';

  @override
  String get messageErrorMalformedCiphertext => 'Chiffre mal forme';

  @override
  String get messageErrorNoKeyMaterial => 'Materiel de cle manquant';

  @override
  String get messageErrorNoDecryptionKey => 'Cle de dechiffrement manquante';

  @override
  String get messageErrorInvalidKex => 'Echange de cles invalide';

  @override
  String get messageErrorUnknownOmemo => 'Erreur OMEMO inconnue';

  @override
  String get messageErrorInvalidAffixElements => 'Elements d affixe invalides';

  @override
  String get messageErrorEmptyDeviceList => 'Liste d appareils vide';

  @override
  String get messageErrorOmemoUnsupported => 'OMEMO non pris en charge';

  @override
  String get messageErrorEncryptionFailure => 'Echec du chiffrement';

  @override
  String get messageErrorInvalidEnvelope => 'Enveloppe invalide';

  @override
  String get messageErrorFileDownloadFailure =>
      'Echec du telechargement du fichier';

  @override
  String get messageErrorFileUploadFailure =>
      'Echec du televersement du fichier';

  @override
  String get messageErrorFileDecryptionFailure =>
      'Echec du dechiffrement du fichier';

  @override
  String get messageErrorFileEncryptionFailure =>
      'Echec du chiffrement du fichier';

  @override
  String get messageErrorPlaintextFileInOmemo =>
      'Fichier en clair dans un message OMEMO';

  @override
  String get messageErrorEmailSendFailure => 'Echec de l envoi de l email';

  @override
  String get messageErrorEmailAttachmentTooLarge =>
      'Piece jointe email trop volumineuse';

  @override
  String get messageErrorEmailRecipientRejected => 'Destinataire email refuse';

  @override
  String get messageErrorEmailAuthenticationFailed =>
      'Echec de l authentification email';

  @override
  String get messageErrorEmailBounced => 'Email rebondi';

  @override
  String get messageErrorEmailThrottled => 'Email limite';

  @override
  String get chatEmailResendFailedDetails => 'Impossible de renvoyer l email.';

  @override
  String get authEnableXmppOrSmtp => 'Activez XMPP ou SMTP pour continuer.';

  @override
  String get authUsernamePasswordMismatch =>
      'Le nom d’utilisateur et le mot de passe n’ont pas la même nullabilité.';

  @override
  String get authStoredCredentialsOutdated =>
      'Les identifiants enregistrés sont obsolètes. Veuillez vous connecter manuellement.';

  @override
  String get authMissingDatabaseSecrets =>
      'Les secrets de la base locale manquent pour ce compte. Axichat ne peut pas ouvrir vos chats existants. Restaurez l’installation d’origine ou réinitialisez les données locales pour continuer.';

  @override
  String get authInvalidCredentials =>
      'Nom d’utilisateur ou mot de passe incorrect';

  @override
  String get authGenericError => 'Erreur. Veuillez réessayer plus tard.';

  @override
  String get authStorageLocked =>
      'Le stockage est verrouillé par une autre instance d’Axichat. Fermez les autres fenêtres ou processus et réessayez.';

  @override
  String get authEmailServerUnreachable =>
      'Impossible d’atteindre le serveur e-mail. Veuillez réessayer.';

  @override
  String get authEmailSetupFailed =>
      'Échec de la configuration e-mail. Veuillez réessayer.';

  @override
  String get authEmailPasswordMissing =>
      'Mot de passe e-mail enregistré manquant. Veuillez vous connecter manuellement.';

  @override
  String get authEmailAuthFailed =>
      'Échec de l’authentification e-mail. Veuillez vous reconnecter.';

  @override
  String get signupCleanupInProgress =>
      'Nettoyage de votre précédente tentative d’inscription en cours. Nous relancerons la suppression dès que vous serez de nouveau en ligne ; réessayez une fois terminé.';

  @override
  String get signupFailedTryAgain =>
      'Échec de l’inscription, réessayez plus tard.';

  @override
  String get authPasswordMismatch =>
      'Les nouveaux mots de passe ne correspondent pas.';

  @override
  String get authPasswordChangeDisabled =>
      'Les changements de mot de passe sont désactivés pour ce compte.';

  @override
  String get authPasswordChangeRejected =>
      'Le mot de passe actuel est incorrect, ou le nouveau mot de passe ne respecte pas les exigences du serveur.';

  @override
  String get authPasswordChangeFailed =>
      'Impossible de changer le mot de passe. Veuillez réessayer plus tard.';

  @override
  String get authPasswordChangeSuccess => 'Mot de passe modifié avec succès.';

  @override
  String get authPasswordChangeReconnectPending =>
      'Mot de passe modifié. L’e-mail se reconnecte en arrière-plan.';

  @override
  String get authPasswordIncorrect =>
      'Mot de passe incorrect. Veuillez réessayer.';

  @override
  String get authDeviceOnlyPasswordUnavailable =>
      'Device-managed password is unavailable on this device. Account recovery is not possible.';

  @override
  String get authAccountNotFound => 'Compte introuvable.';

  @override
  String get authAccountAlreadyExists => 'Le compte existe déjà.';

  @override
  String get authAccountDeletionDisabled =>
      'La suppression du compte est désactivée pour ce compte.';

  @override
  String get authAccountDeletionFailed =>
      'Impossible de supprimer le compte. Veuillez réessayer plus tard.';

  @override
  String get authDemoModeFailed =>
      'Impossible de démarrer le mode démo. Veuillez réessayer.';

  @override
  String authLoginBackoff(Object seconds) {
    return 'Trop de tentatives. Attendez $seconds secondes avant de réessayer.';
  }

  @override
  String get signupAvatarCropTitle => 'Rogner et cadrer';

  @override
  String get signupAvatarCropHint =>
      'Seule la zone à l’intérieur du cercle apparaîtra dans l’avatar final.';

  @override
  String get xmppOperationPubSubBookmarksStart =>
      'Synchronisation des marque-pages...';

  @override
  String get xmppOperationPubSubBookmarksSuccess => 'Marque-pages synchronisés';

  @override
  String get xmppOperationPubSubBookmarksFailure =>
      'Échec de la synchronisation des marque-pages';

  @override
  String get xmppOperationPubSubConversationsStart =>
      'Synchronisation de la liste des chats...';

  @override
  String get xmppOperationPubSubConversationsSuccess =>
      'Liste des chats synchronisée';

  @override
  String get xmppOperationPubSubConversationsFailure =>
      'Échec de la synchronisation de la liste des chats';

  @override
  String get xmppOperationPubSubDraftsStart =>
      'Synchronisation des brouillons...';

  @override
  String get xmppOperationPubSubDraftsSuccess => 'Brouillons synchronisés';

  @override
  String get xmppOperationPubSubDraftsFailure =>
      'Échec de la synchronisation des brouillons';

  @override
  String get xmppOperationPubSubSpamStart =>
      'Synchronisation de la liste de spam...';

  @override
  String get xmppOperationPubSubSpamSuccess => 'Liste de spam synchronisée';

  @override
  String get xmppOperationPubSubSpamFailure =>
      'Échec de la synchronisation de la liste de spam';

  @override
  String get xmppOperationPubSubEmailBlocklistStart =>
      'Synchronisation de la liste de blocage des e-mails...';

  @override
  String get xmppOperationPubSubEmailBlocklistSuccess =>
      'Liste de blocage des e-mails synchronisée';

  @override
  String get xmppOperationPubSubEmailBlocklistFailure =>
      'Échec de la synchronisation de la liste de blocage des e-mails';

  @override
  String get xmppOperationPubSubAvatarMetadataStart =>
      'Synchronisation des détails de l’avatar...';

  @override
  String get xmppOperationPubSubAvatarMetadataSuccess =>
      'Détails de l’avatar synchronisés';

  @override
  String get xmppOperationPubSubAvatarMetadataFailure =>
      'Échec de la synchronisation des détails de l’avatar';

  @override
  String get xmppOperationPubSubFetchStart =>
      'Synchronisation des mises à jour du compte...';

  @override
  String get xmppOperationPubSubFetchSuccess =>
      'Mises à jour du compte synchronisées';

  @override
  String get xmppOperationPubSubFetchFailure =>
      'Échec de la synchronisation des mises à jour du compte';

  @override
  String get xmppOperationMamLoginStart => 'Synchronisation des messages...';

  @override
  String get xmppOperationMamLoginSuccess => 'Messages synchronisés';

  @override
  String get xmppOperationMamLoginFailure =>
      'Échec de la synchronisation des messages';

  @override
  String get xmppOperationMamGlobalStart =>
      'Synchronisation de l’historique complet...';

  @override
  String get xmppOperationMamGlobalSuccess => 'Historique synchronisé';

  @override
  String get xmppOperationMamGlobalFailure =>
      'Échec de la synchronisation de l’historique';

  @override
  String get xmppOperationMamMucStart =>
      'Synchronisation de l’historique du salon...';

  @override
  String get xmppOperationMamMucSuccess => 'Historique du salon synchronisé';

  @override
  String get xmppOperationMamMucFailure =>
      'Échec de la synchronisation de l’historique du salon';

  @override
  String get xmppOperationMamFetchStart =>
      'Récupération des messages archivés...';

  @override
  String get xmppOperationMamFetchSuccess => 'Archive récupérée';

  @override
  String get xmppOperationMamFetchFailure =>
      'Échec de la récupération de l’archive';

  @override
  String get xmppOperationMucCreateStart => 'Création du salon...';

  @override
  String get xmppOperationMucCreateSuccess => 'Salon créé';

  @override
  String get xmppOperationMucCreateFailure => 'Échec de la création du salon';

  @override
  String get xmppOperationMucJoinStart => 'Connexion au salon...';

  @override
  String get xmppOperationMucJoinSuccess => 'Salon rejoint';

  @override
  String get xmppOperationMucJoinFailure => 'Échec de la connexion au salon';

  @override
  String get xmppOperationMucAvatarUpdateStart =>
      'Mise à jour de l’avatar du salon...';

  @override
  String get xmppOperationMucAvatarUpdateSuccess =>
      'Avatar du salon mis à jour';

  @override
  String get xmppOperationMucAvatarUpdateFailure =>
      'Échec de la mise à jour de l’avatar du salon';

  @override
  String get xmppOperationSelfAvatarPublishStart =>
      'Publication de l’avatar...';

  @override
  String get xmppOperationSelfAvatarPublishSuccess => 'Avatar publié';

  @override
  String get xmppOperationSelfAvatarPublishFailure =>
      'Échec de la publication de l’avatar';

  @override
  String get chatSettingsCapabilitiesTitle => 'Capacités';

  @override
  String chatSettingsCapabilitiesUpdated(Object timestamp) {
    return 'Dernière vérification : $timestamp';
  }

  @override
  String get chatSettingsCapabilitiesEmpty => 'Aucune fonctionnalité signalée';
}
