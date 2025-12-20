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
  String get homeTabDrafts => 'Brouillons';

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
  String get chatsFilterContacts => 'Contacts';

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
  String get chatOpenLinkTitle => 'Ouvrir un lien externe ?';

  @override
  String chatOpenLinkMessage(Object url, Object host) {
    return 'Tu es sur le point d\'ouvrir :\n$url\n\nN\'appuie sur OK que si tu fais confiance au site (hôte : $host).';
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
  String get chatComposerMessageHint => 'Envoyer un message';

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
  String get chatReportSpam => 'Signaler comme spam';

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
  String get chatInviteRevoked => 'Invitation révoquée';

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
  String get draftMessageHint => 'Message';

  @override
  String get draftSendingStatus => 'Envoi...';

  @override
  String get draftSendingEllipsis => 'Envoi…';

  @override
  String get draftSend => 'Envoyer le brouillon';

  @override
  String get draftDiscard => 'Supprimer';

  @override
  String get draftSave => 'Enregistrer le brouillon';

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
  String get chatShareSelectedNoText =>
      'Les messages sélectionnés n’ont pas de texte à partager.';

  @override
  String get chatForwardInviteForbidden =>
      'Les invitations ne peuvent pas être transférées.';

  @override
  String get chatAddToCalendarNoText =>
      'Les messages sélectionnés n’ont pas de texte à ajouter au calendrier.';

  @override
  String get chatForwardDialogTitle => 'Transférer à...';

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
      Object subject, int count, Object recipientLabel) {
    return 'L’objet « $subject » n’a pas pu être envoyé à $count $recipientLabel.';
  }

  @override
  String chatFanOutFailure(int count, Object recipientLabel) {
    return 'Échec de l’envoi à $count $recipientLabel.';
  }

  @override
  String get chatFanOutRetry => 'Réessayer';

  @override
  String get chatSubjectSemantics => 'Objet de l’e-mail';

  @override
  String get chatSubjectHint => 'Objet';

  @override
  String get chatAttachmentTooltip => 'Pièces jointes';

  @override
  String get chatSendMessageTooltip => 'Envoyer le message';

  @override
  String get chatBlockAction => 'Bloquer';

  @override
  String get chatReactionMore => 'Plus';

  @override
  String get chatQuotedNoContent => '(aucun contenu)';

  @override
  String get chatReplyingTo => 'En réponse à...';

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
      'Bienvenue sur Axichat — chat, e-mail et calendrier au même endroit.';

  @override
  String get chatGuestScriptExternalQuestion =>
      'C’est propre. Puis-je envoyer des messages à des personnes qui n’utilisent pas Axichat ?';

  @override
  String get chatGuestScriptExternalAnswer =>
      'Oui — envoie des e-mails au format chat vers Gmail, Outlook, Tuta et d’autres. Si vous utilisez tous Axichat, vous bénéficiez aussi des salons de groupe, réactions, accusés de réception, etc.';

  @override
  String get chatGuestScriptOfflineQuestion =>
      'Est-ce que ça marche hors ligne ou en mode invité ?';

  @override
  String get chatGuestScriptOfflineAnswer =>
      'Oui — le mode hors ligne est intégré et le calendrier fonctionne même en mode invité sans compte ni connexion.';

  @override
  String get chatGuestScriptKeepUpQuestion =>
      'Comment ça m’aide à tout suivre ?';

  @override
  String get chatGuestScriptKeepUpAnswer =>
      'Notre calendrier gère la planification en langage naturel, la matrice d’Eisenhower, le glisser-déposer et les rappels pour vous laisser vous concentrer sur l’essentiel.';

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
  String get calendarActions => 'Actions';

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
  String get calendarBatchDescription => 'Description';

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
  String get signupProgressLabel => 'Progression de l’inscription';

  @override
  String signupProgressValue(
      Object current, Object currentLabel, Object percent, Object total) {
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
  String get signupAvatarBackgroundColor => 'Couleur d’arrière-plan';

  @override
  String get signupAvatarDefaultsTitle => 'Avatars par défaut';

  @override
  String get signupAvatarCategoryAbstract => 'Abstrait';

  @override
  String get signupAvatarCategoryScience => 'Science';

  @override
  String get signupAvatarCategorySports => 'Sports';

  @override
  String get signupAvatarCategoryMusic => 'Musique';

  @override
  String get notificationsRestartTitle =>
      'Redémarrez l’app pour activer les notifications';

  @override
  String get notificationsRestartSubtitle =>
      'Autorisations requises déjà accordées';

  @override
  String get notificationsMessageToggle => 'Notifications de messages';

  @override
  String get notificationsRequiresRestart => 'Redémarrage requis';

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
  String get calendarTaskNotFound => 'Tâche introuvable';

  @override
  String get calendarDayEventsTitle => 'Événements du jour';

  @override
  String get calendarDayEventsEmpty => 'Aucun événement à cette date';

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
  String get accessibilityActionsTitle => 'Actions';

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
  String get accessibilityMessagesTitle => 'Messages';

  @override
  String get accessibilityNoConversationSelected =>
      'Aucune conversation sélectionnée';

  @override
  String accessibilityMessagesWithContact(Object name) {
    return 'Messages avec $name';
  }

  @override
  String accessibilityMessageLabel(
      Object sender, Object timestamp, Object body) {
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
  String get accessibilityConversationLabel => 'Conversation';

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
      Object position, Object total, Object label) {
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
      Object position, Object total, Object section) {
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
  String get profileChangePassword => 'Changer le mot de passe';

  @override
  String get profileDeleteAccount => 'Supprimer le compte';

  @override
  String get termsAcceptLabel => 'J’accepte les conditions générales';

  @override
  String get termsAgreementPrefix => 'Vous acceptez nos ';

  @override
  String get termsAgreementTerms => 'conditions';

  @override
  String get termsAgreementAnd => ' et ';

  @override
  String get termsAgreementPrivacy => 'politique de confidentialité';

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
  String get settingsSectionImportant => 'Important';

  @override
  String get settingsSectionAppearance => 'Apparence';

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
  String get settingsSectionChats => 'Discussions';

  @override
  String get settingsMessageStorageTitle => 'Stockage des messages';

  @override
  String get settingsMessageStorageSubtitle =>
      'Local conserve des copies sur l’appareil ; Serveur uniquement interroge l’archive.';

  @override
  String get settingsMessageStorageLocal => 'Local';

  @override
  String get settingsMessageStorageServerOnly => 'Serveur uniquement';

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
  String get settingsReadReceipts => 'Envoyer les accusés de lecture';

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
      'Remplace les points de terminaison XMPP/SMTP ou active les recherches DNS. Laissez les champs vides pour conserver les valeurs par défaut.';

  @override
  String get authCustomServerDomainOrIp => 'Domaine ou IP';

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
  String get authCustomServerApiPortPlaceholder => 'Port API';

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
  String get chatAttachmentUnavailableDevice =>
      'La pièce jointe n’est plus disponible sur cet appareil';

  @override
  String get chatAttachmentInvalidLink => 'Lien de pièce jointe invalide';

  @override
  String chatAttachmentOpenFailed(Object target) {
    return 'Impossible d’ouvrir $target';
  }

  @override
  String get chatAttachmentUnknownSize => 'Taille inconnue';

  @override
  String chatAttachmentErrorTooltip(Object message, Object fileName) {
    return '$message ($fileName)';
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
  String get mucChangeNickname => 'Changer de pseudo';

  @override
  String mucChangeNicknameWithCurrent(Object current) {
    return 'Changer de pseudo (actuel : $current)';
  }

  @override
  String get mucLeaveRoom => 'Quitter la salle';

  @override
  String get mucNoMembers => 'Aucun membre pour l’instant';

  @override
  String get mucInviteUsers => 'Inviter des utilisateurs';

  @override
  String get mucSendInvites => 'Envoyer les invitations';

  @override
  String get mucChangeNicknameTitle => 'Changer de pseudo';

  @override
  String get mucEnterNicknamePlaceholder => 'Saisir un pseudo';

  @override
  String get mucUpdateNickname => 'Mettre à jour';

  @override
  String get mucMembersTitle => 'Membres';

  @override
  String get mucInviteUser => 'Inviter un utilisateur';

  @override
  String get mucSectionOwners => 'Propriétaires';

  @override
  String get mucSectionAdmins => 'Admins';

  @override
  String get mucSectionModerators => 'Modérateurs';

  @override
  String get mucSectionMembers => 'Membres';

  @override
  String get mucSectionVisitors => 'Visiteurs';

  @override
  String get mucRoleOwner => 'Propriétaire';

  @override
  String get mucRoleAdmin => 'Admin';

  @override
  String get mucRoleMember => 'Membre';

  @override
  String get mucRoleVisitor => 'Visiteur';

  @override
  String get mucRoleModerator => 'Modérateur';

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
  String get chatsRoomLabel => 'Salle';

  @override
  String get chatsCreateChatRoomTitle => 'Créer une salle de chat';

  @override
  String get chatsRoomNamePlaceholder => 'Nom';

  @override
  String get chatsArchiveTitle => 'Archive';

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
  String get rosterAddLabel => 'Contact';

  @override
  String get rosterAddTitle => 'Ajouter un contact';

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
  String get calendarCriticalPathsTitle => 'Chemins critiques';

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
  String get calendarDates => 'Dates';

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
  String get calendarImportant => 'Important';

  @override
  String get calendarUrgent => 'Urgent';

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
  String get chatChooseTextToAdd => 'Choisir le texte à ajouter';
}
