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
  String get chatsFilterNonContacts => 'Non-contacts';

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
}
