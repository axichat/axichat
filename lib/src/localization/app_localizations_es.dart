// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'axichat';

  @override
  String get homeTabChats => 'Chats';

  @override
  String get homeTabDrafts => 'Borradores';

  @override
  String get homeTabSpam => 'Spam';

  @override
  String get homeTabBlocked => 'Bloqueados';

  @override
  String get homeNoModules => 'No hay módulos disponibles';

  @override
  String get homeRailShowMenu => 'Mostrar menú';

  @override
  String get homeRailHideMenu => 'Ocultar menú';

  @override
  String get homeRailCalendar => 'Calendario';

  @override
  String get homeSearchPlaceholderTabs => 'Buscar pestañas';

  @override
  String homeSearchPlaceholderForTab(Object tab) {
    return 'Buscar $tab';
  }

  @override
  String homeSearchFilterLabel(Object filter) {
    return 'Filtro: $filter';
  }

  @override
  String get blocklistFilterAll => 'Todos bloqueados';

  @override
  String get draftsFilterAll => 'Todos los borradores';

  @override
  String get draftsFilterAttachments => 'Con archivos adjuntos';

  @override
  String get chatsFilterAll => 'Todos los chats';

  @override
  String get chatsFilterContacts => 'Contactos';

  @override
  String get chatsFilterNonContacts => 'No contactos';

  @override
  String get chatsFilterXmppOnly => 'Solo XMPP';

  @override
  String get chatsFilterEmailOnly => 'Solo correo';

  @override
  String get chatsFilterHidden => 'Ocultos';

  @override
  String get spamFilterAll => 'Todo el spam';

  @override
  String get spamFilterEmail => 'Correo';

  @override
  String get spamFilterXmpp => 'XMPP';

  @override
  String get chatFilterDirectOnly => 'Solo directos';

  @override
  String get chatFilterAllWithContact => 'Todo con el contacto';

  @override
  String get chatSearchMessages => 'Buscar mensajes';

  @override
  String get chatSearchSortNewestFirst => 'Más recientes primero';

  @override
  String get chatSearchSortOldestFirst => 'Más antiguos primero';

  @override
  String get chatSearchAnySubject => 'Cualquier asunto';

  @override
  String get chatSearchExcludeSubject => 'Excluir asunto';

  @override
  String get chatSearchFailed => 'Búsqueda fallida';

  @override
  String get chatSearchInProgress => 'Buscando…';

  @override
  String get chatSearchEmptyPrompt =>
      'Las coincidencias aparecerán en la conversación.';

  @override
  String get chatSearchNoMatches =>
      'Sin coincidencias. Ajusta filtros o intenta otra consulta.';

  @override
  String chatSearchMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# coincidencias mostradas.',
      one: '# coincidencia mostrada.',
    );
    return '$_temp0';
  }

  @override
  String filterTooltip(Object label) {
    return 'Filtrar • $label';
  }

  @override
  String get chatSearchClose => 'Cerrar búsqueda';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonClear => 'Limpiar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get spamEmpty => 'Aún no hay spam';

  @override
  String get spamMoveToInbox => 'Mover a bandeja de entrada';

  @override
  String get spamMoveToastTitle => 'Movido';

  @override
  String spamMoveToastMessage(Object chatTitle) {
    return 'Se devolvió $chatTitle a la bandeja de entrada.';
  }

  @override
  String get chatSpamUpdateFailed => 'Error al actualizar el estado de spam.';

  @override
  String chatSpamSent(Object chatTitle) {
    return 'Se envió $chatTitle a spam.';
  }

  @override
  String chatSpamRestored(Object chatTitle) {
    return 'Se devolvió $chatTitle a la bandeja de entrada.';
  }

  @override
  String get chatSpamReportedTitle => 'Reportado';

  @override
  String get chatSpamRestoredTitle => 'Restaurado';

  @override
  String get chatMembersLoading => 'Cargando miembros';

  @override
  String get chatMembersLoadingEllipsis => 'Cargando miembros…';

  @override
  String get chatAttachmentConfirmTitle => '¿Cargar adjunto?';

  @override
  String chatAttachmentConfirmMessage(Object sender) {
    return 'Solo carga adjuntos de contactos de confianza.\n\n$sender no está en tus contactos. ¿Continuar?';
  }

  @override
  String get chatAttachmentConfirmButton => 'Cargar';

  @override
  String get chatOpenLinkTitle => '¿Abrir enlace externo?';

  @override
  String chatOpenLinkMessage(Object url, Object host) {
    return 'Vas a abrir:\n$url\n\nToca Aceptar solo si confías en el sitio (host: $host).';
  }

  @override
  String get chatOpenLinkConfirm => 'Abrir enlace';

  @override
  String chatInvalidLink(Object url) {
    return 'Enlace no válido: $url';
  }

  @override
  String chatUnableToOpenHost(Object host) {
    return 'No se puede abrir $host';
  }

  @override
  String get chatSaveAsDraft => 'Guardar como borrador';

  @override
  String get chatDraftUnavailable =>
      'Los borradores no están disponibles en este momento.';

  @override
  String get chatDraftMissingContent =>
      'Añade un mensaje, asunto o adjunto antes de guardar.';

  @override
  String get chatDraftSaved => 'Guardado en Borradores.';

  @override
  String get chatDraftSaveFailed =>
      'No se pudo guardar el borrador. Intenta de nuevo.';

  @override
  String get chatAttachmentInaccessible =>
      'El archivo seleccionado no es accesible.';

  @override
  String get chatAttachmentFailed => 'No se pudo adjuntar el archivo.';

  @override
  String get chatAttachmentView => 'Ver';

  @override
  String get chatAttachmentRetry => 'Reintentar subida';

  @override
  String get chatAttachmentRemove => 'Eliminar adjunto';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get toastWhoopsTitle => 'Uy';

  @override
  String get toastHeadsUpTitle => 'Atención';

  @override
  String get toastAllSetTitle => 'Listo';

  @override
  String get chatRoomMembers => 'Miembros de la sala';

  @override
  String get chatCloseSettings => 'Cerrar ajustes';

  @override
  String get chatSettings => 'Ajustes del chat';

  @override
  String get chatEmptySearch => 'Sin coincidencias';

  @override
  String get chatEmptyMessages => 'Sin mensajes';

  @override
  String get chatComposerEmailHint => 'Enviar mensaje de correo';

  @override
  String get chatComposerMessageHint => 'Enviar mensaje';

  @override
  String get chatReadOnly => 'Solo lectura';

  @override
  String get chatUnarchivePrompt => 'Desarchiva para enviar nuevos mensajes.';

  @override
  String get chatEmojiPicker => 'Selector de emojis';

  @override
  String get chatShowingDirectOnly => 'Mostrando solo directos';

  @override
  String get chatShowingAll => 'Mostrando todo';

  @override
  String get chatMuteNotifications => 'Silenciar notificaciones';

  @override
  String get chatEnableNotifications => 'Activar notificaciones';

  @override
  String get chatMoveToInbox => 'Mover a bandeja de entrada';

  @override
  String get chatReportSpam => 'Reportar spam';

  @override
  String get chatSignatureToggleLabel =>
      'Incluir pie de firma de token para correo';

  @override
  String get chatSignatureHintEnabled =>
      'Ayuda a mantener los hilos de correo con varios destinatarios.';

  @override
  String get chatSignatureHintDisabled =>
      'Desactivado globalmente; las respuestas pueden perder el hilo.';

  @override
  String get chatSignatureHintWarning =>
      'Desactivarlo puede romper el hilo y los grupos de adjuntos.';

  @override
  String get chatInviteRevoked => 'Invitación revocada';

  @override
  String get chatInvite => 'Invitación';

  @override
  String get chatReactionsNone => 'Aún no hay reacciones';

  @override
  String get chatReactionsPrompt =>
      'Toca una reacción para añadir o quitar la tuya';

  @override
  String get chatReactionsPick => 'Elige un emoji para reaccionar';

  @override
  String get chatActionReply => 'Responder';

  @override
  String get chatActionForward => 'Reenviar';

  @override
  String get chatActionResend => 'Reenviar';

  @override
  String get chatActionEdit => 'Editar';

  @override
  String get chatActionRevoke => 'Revocar';

  @override
  String get chatActionCopy => 'Copiar';

  @override
  String get chatActionShare => 'Compartir';

  @override
  String get chatActionAddToCalendar => 'Agregar al calendario';

  @override
  String get chatActionDetails => 'Detalles';

  @override
  String get chatActionSelect => 'Seleccionar';

  @override
  String get chatActionReact => 'Reaccionar';

  @override
  String get chatContactRenameAction => 'Renombrar';

  @override
  String get chatContactRenameTooltip => 'Renombrar contacto';

  @override
  String get chatContactRenameTitle => 'Renombrar contacto';

  @override
  String get chatContactRenameDescription =>
      'Elige cómo aparece este contacto en Axichat.';

  @override
  String get chatContactRenamePlaceholder => 'Nombre para mostrar';

  @override
  String get chatContactRenameReset => 'Restablecer al valor predeterminado';

  @override
  String get chatContactRenameSave => 'Guardar';

  @override
  String get chatContactRenameSuccess => 'Nombre para mostrar actualizado';

  @override
  String get chatContactRenameFailure => 'No se pudo renombrar el contacto';

  @override
  String get chatComposerSemantics => 'Entrada de mensaje';

  @override
  String get draftSaved => 'Borrador guardado';

  @override
  String get draftErrorTitle => 'Ups';

  @override
  String get draftNoRecipients => 'Sin destinatarios';

  @override
  String get draftSubjectSemantics => 'Asunto del correo';

  @override
  String get draftSubjectHintOptional => 'Asunto (opcional)';

  @override
  String get draftMessageSemantics => 'Cuerpo del mensaje';

  @override
  String get draftMessageHint => 'Mensaje';

  @override
  String get draftSendingStatus => 'Enviando...';

  @override
  String get draftSendingEllipsis => 'Enviando…';

  @override
  String get draftSend => 'Enviar borrador';

  @override
  String get draftDiscard => 'Descartar';

  @override
  String get draftSave => 'Guardar borrador';

  @override
  String get draftAttachmentInaccessible =>
      'El archivo seleccionado no es accesible.';

  @override
  String get draftAttachmentFailed => 'No se pudo adjuntar el archivo.';

  @override
  String get draftDiscarded => 'Borrador descartado.';

  @override
  String get draftSendFailed => 'No se pudo enviar el borrador.';

  @override
  String get draftSent => 'Enviado';

  @override
  String get draftValidationNoContent => 'Agrega un asunto, mensaje o adjunto';

  @override
  String draftFileMissing(Object path) {
    return 'El archivo ya no existe en $path.';
  }

  @override
  String get draftAttachmentPreview => 'Vista previa';

  @override
  String get draftRemoveAttachment => 'Eliminar adjunto';

  @override
  String get draftNoAttachments => 'Aún no hay adjuntos';

  @override
  String get draftAttachmentsLabel => 'Adjuntos';

  @override
  String get draftAddAttachment => 'Agregar adjunto';

  @override
  String draftTaskDue(Object date) {
    return 'Vence $date';
  }

  @override
  String get draftTaskNoSchedule => 'Sin horario';

  @override
  String get draftTaskUntitled => 'Tarea sin título';

  @override
  String get chatBack => 'Atrás';

  @override
  String get chatErrorLabel => 'Error';

  @override
  String get chatSenderYou => 'Tú';

  @override
  String get chatInviteAlreadyInRoom => 'Ya estás en esta sala.';

  @override
  String get chatInviteWrongAccount => 'La invitación no es para esta cuenta.';

  @override
  String get chatShareNoText => 'El mensaje no tiene texto para compartir.';

  @override
  String get chatShareFallbackSubject => 'Mensaje de Axichat';

  @override
  String chatShareSubjectPrefix(Object chatTitle) {
    return 'Compartido desde $chatTitle';
  }

  @override
  String get chatCalendarNoText =>
      'El mensaje no tiene texto para añadir al calendario.';

  @override
  String get chatCalendarUnavailable =>
      'El calendario no está disponible en este momento.';

  @override
  String get chatCopyNoText =>
      'Los mensajes seleccionados no tienen texto para copiar.';

  @override
  String get chatShareSelectedNoText =>
      'Los mensajes seleccionados no tienen texto para compartir.';

  @override
  String get chatForwardInviteForbidden =>
      'Las invitaciones no se pueden reenviar.';

  @override
  String get chatAddToCalendarNoText =>
      'Los mensajes seleccionados no tienen texto para añadir al calendario.';

  @override
  String get chatForwardDialogTitle => 'Reenviar a...';

  @override
  String get chatComposerAttachmentWarning =>
      'Los archivos adjuntos grandes se envían por separado a cada destinatario y pueden tardar más en entregarse.';

  @override
  String chatFanOutRecipientLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'destinatarios',
      one: 'destinatario',
    );
    return '$_temp0';
  }

  @override
  String chatFanOutFailureWithSubject(
      Object subject, int count, Object recipientLabel) {
    return 'El asunto \"$subject\" no se pudo enviar a $count $recipientLabel.';
  }

  @override
  String chatFanOutFailure(int count, Object recipientLabel) {
    return 'No se pudo enviar a $count $recipientLabel.';
  }

  @override
  String get chatFanOutRetry => 'Reintentar';

  @override
  String get chatSubjectSemantics => 'Asunto del correo';

  @override
  String get chatSubjectHint => 'Asunto';

  @override
  String get chatAttachmentTooltip => 'Adjuntos';

  @override
  String get chatSendMessageTooltip => 'Enviar mensaje';

  @override
  String get chatBlockAction => 'Bloquear';

  @override
  String get chatReactionMore => 'Más';

  @override
  String get chatQuotedNoContent => '(sin contenido)';

  @override
  String get chatReplyingTo => 'Respondiendo a...';

  @override
  String get chatCancelReply => 'Cancelar respuesta';

  @override
  String get chatMessageRetracted => '(retirado)';

  @override
  String get chatMessageEdited => '(editado)';

  @override
  String get chatGuestAttachmentsDisabled =>
      'Los archivos adjuntos están desactivados en la vista previa.';

  @override
  String get chatGuestSubtitle =>
      'Vista previa de invitado • Guardado localmente';

  @override
  String recipientsOverflowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count más',
      one: '+1 más',
    );
    return '$_temp0';
  }

  @override
  String get recipientsCollapse => 'Contraer';

  @override
  String recipientsSemantics(int count, Object state) {
    return 'Destinatarios $count, $state';
  }

  @override
  String get recipientsStateCollapsed => 'contraído';

  @override
  String get recipientsStateExpanded => 'expandido';

  @override
  String get recipientsHintExpand => 'Pulsar para expandir';

  @override
  String get recipientsHintCollapse => 'Pulsar para contraer';

  @override
  String get recipientsHeaderTitle => 'Enviar a...';

  @override
  String get recipientsFallbackLabel => 'Destinatario';

  @override
  String get recipientsAddHint => 'Agregar...';

  @override
  String get chatGuestScriptWelcome =>
      'Bienvenido a Axichat: chat, correo y calendario en un solo lugar.';

  @override
  String get chatGuestScriptExternalQuestion =>
      'Se ve limpio. ¿Puedo enviar mensajes a personas que no usan Axichat?';

  @override
  String get chatGuestScriptExternalAnswer =>
      'Sí: envía correos con formato de chat a Gmail, Outlook, Tuta y más. Si ambos usan Axichat también obtienen chats grupales, reacciones, acuses de entrega y más.';

  @override
  String get chatGuestScriptOfflineQuestion =>
      '¿Funciona sin conexión o en modo invitado?';

  @override
  String get chatGuestScriptOfflineAnswer =>
      'Sí: la funcionalidad sin conexión está integrada y el calendario funciona incluso en modo invitado sin cuenta ni internet.';

  @override
  String get chatGuestScriptKeepUpQuestion =>
      '¿Cómo me ayuda a mantenerme al día?';

  @override
  String get chatGuestScriptKeepUpAnswer =>
      'Nuestro calendario admite programación en lenguaje natural, matriz de Eisenhower, arrastrar y soltar y recordatorios para que te concentres en lo importante.';

  @override
  String calendarParserUnavailable(Object errorType) {
    return 'Analizador no disponible ($errorType)';
  }

  @override
  String get calendarAddTaskTitle => 'Agregar tarea';

  @override
  String get calendarTaskNameRequired => 'Nombre de la tarea *';

  @override
  String get calendarTaskNameHint => 'Nombre de la tarea';

  @override
  String get calendarDescriptionHint => 'Descripción (opcional)';

  @override
  String get calendarLocationHint => 'Ubicación (opcional)';

  @override
  String get calendarScheduleLabel => 'Programar';

  @override
  String get calendarDeadlineLabel => 'Fecha límite';

  @override
  String get calendarRepeatLabel => 'Repetir';

  @override
  String get calendarCancel => 'Cancelar';

  @override
  String get calendarAddTaskAction => 'Agregar tarea';

  @override
  String get calendarSelectionMode => 'Modo de selección';

  @override
  String get calendarExit => 'Salir';

  @override
  String calendarTasksSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# tareas seleccionadas',
      one: '# tarea seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get calendarActions => 'Acciones';

  @override
  String get calendarSetPriority => 'Establecer prioridad';

  @override
  String get calendarClearSelection => 'Limpiar selección';

  @override
  String get calendarExportSelected => 'Exportar seleccionadas';

  @override
  String get calendarDeleteSelected => 'Eliminar seleccionadas';

  @override
  String get calendarBatchEdit => 'Edición en lote';

  @override
  String get calendarBatchTitle => 'Título';

  @override
  String get calendarBatchTitleHint =>
      'Establece el título para las tareas seleccionadas';

  @override
  String get calendarBatchDescription => 'Descripción';

  @override
  String get calendarBatchDescriptionHint =>
      'Define la descripción (deja en blanco para limpiar)';

  @override
  String get calendarBatchLocation => 'Ubicación';

  @override
  String get calendarBatchLocationHint =>
      'Define la ubicación (deja en blanco para limpiar)';

  @override
  String get calendarApplyChanges => 'Aplicar cambios';

  @override
  String get calendarAdjustTime => 'Ajustar hora';

  @override
  String get calendarSelectionRequired =>
      'Selecciona tareas antes de aplicar cambios.';

  @override
  String get calendarSelectionNone =>
      'Selecciona tareas para exportar primero.';

  @override
  String get calendarSelectionChangesApplied =>
      'Cambios aplicados a las tareas seleccionadas.';

  @override
  String get calendarSelectionNoPending =>
      'No hay cambios pendientes por aplicar.';

  @override
  String get calendarSelectionTitleBlank => 'El título no puede estar vacío.';

  @override
  String get calendarExportReady => 'Exportación lista para compartir.';

  @override
  String calendarExportFailed(Object error) {
    return 'No se pudo exportar las tareas seleccionadas: $error';
  }

  @override
  String get commonBack => 'Atrás';

  @override
  String get composeTitle => 'Redactar';

  @override
  String get draftComposeMessage => 'Redactar un mensaje';

  @override
  String get draftCompose => 'Redactar';

  @override
  String get draftNewMessage => 'Mensaje nuevo';

  @override
  String get draftRestore => 'Restaurar';

  @override
  String get draftMinimize => 'Minimizar';

  @override
  String get draftExpand => 'Expandir';

  @override
  String get draftExitFullscreen => 'Salir de pantalla completa';

  @override
  String get draftCloseComposer => 'Cerrar el editor';

  @override
  String get draftsEmpty => 'Aún no hay borradores';

  @override
  String get draftsDeleteConfirm => '¿Eliminar borrador?';

  @override
  String get draftNoSubject => '(sin asunto)';

  @override
  String draftRecipientCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count destinatarios',
      one: '1 destinatario',
    );
    return '$_temp0';
  }

  @override
  String get authCreatingAccount => 'Creando tu cuenta…';

  @override
  String get authSecuringLogin => 'Asegurando tu inicio de sesión…';

  @override
  String get authLoggingIn => 'Iniciando sesión…';

  @override
  String get authToggleSignup => '¿Nuevo? Regístrate';

  @override
  String get authToggleLogin => '¿Ya registrado? Inicia sesión';

  @override
  String get authGuestCalendarCta => 'Probar Calendario (Modo invitado)';

  @override
  String get authLogin => 'Iniciar sesión';

  @override
  String get authSignUp => 'Registrarse';

  @override
  String get authToggleSelected => 'Selección actual';

  @override
  String authToggleSelectHint(Object label) {
    return 'Activa para seleccionar $label';
  }

  @override
  String get authUsername => 'Nombre de usuario';

  @override
  String get authUsernameRequired => 'Introduce un nombre de usuario';

  @override
  String get authUsernameRules =>
      '4-20 caracteres alfanuméricos; se permiten \".\", \"_\" y \"-\".';

  @override
  String get authUsernameCaseInsensitive =>
      'No distingue mayúsculas/minúsculas';

  @override
  String get authPassword => 'Contraseña';

  @override
  String get authPasswordConfirm => 'Confirmar contraseña';

  @override
  String get authPasswordRequired => 'Introduce una contraseña';

  @override
  String authPasswordMaxLength(Object max) {
    return 'Debe tener $max caracteres o menos';
  }

  @override
  String get authPasswordsMismatch => 'Las contraseñas no coinciden';

  @override
  String get authPasswordPending => 'Comprobando seguridad de la contraseña';

  @override
  String get authSignupPending => 'Esperando registro';

  @override
  String get authLoginPending => 'Esperando inicio de sesión';

  @override
  String get signupTitle => 'Registrarse';

  @override
  String get signupStepUsername => 'Elige un nombre de usuario';

  @override
  String get signupStepPassword => 'Crea una contraseña';

  @override
  String get signupStepCaptcha => 'Verifica el captcha';

  @override
  String get signupStepSetup => 'Configuración';

  @override
  String signupErrorPrefix(Object message) {
    return 'Error: $message';
  }

  @override
  String get signupCaptchaUnavailable => 'Captcha no disponible';

  @override
  String get signupCaptchaChallenge => 'Desafío captcha';

  @override
  String get signupCaptchaFailed =>
      'No se pudo cargar el captcha. Reintenta con recargar.';

  @override
  String get signupCaptchaLoading => 'Cargando captcha';

  @override
  String get signupCaptchaInstructions =>
      'Introduce los caracteres que aparecen en esta imagen de captcha.';

  @override
  String get signupCaptchaReload => 'Recargar captcha';

  @override
  String get signupCaptchaReloadHint =>
      'Obtén otra imagen captcha si no puedes leer esta.';

  @override
  String get signupCaptchaPlaceholder => 'Introduce el texto de arriba';

  @override
  String get signupCaptchaValidation => 'Introduce el texto de la imagen';

  @override
  String get signupContinue => 'Continuar';

  @override
  String get signupProgressLabel => 'Progreso de registro';

  @override
  String signupProgressValue(
      Object current, Object currentLabel, Object percent, Object total) {
    return 'Paso $current de $total: $currentLabel. $percent% completado.';
  }

  @override
  String get signupProgressSection => 'Configuración de la cuenta';

  @override
  String get signupPasswordStrength => 'Fortaleza de la contraseña';

  @override
  String get signupPasswordBreached =>
      'Esta contraseña aparece en una base de datos filtrada.';

  @override
  String get signupStrengthNone => 'Ninguna';

  @override
  String get signupStrengthWeak => 'Débil';

  @override
  String get signupStrengthMedium => 'Media';

  @override
  String get signupStrengthStronger => 'Más fuerte';

  @override
  String get signupRiskAcknowledgement => 'Entiendo el riesgo';

  @override
  String get signupRiskError => 'Marca la casilla de arriba para continuar.';

  @override
  String get signupRiskAllowBreach =>
      'Permitir esta contraseña aunque apareció en una filtración.';

  @override
  String get signupRiskAllowWeak =>
      'Permitir esta contraseña aunque se considere débil.';

  @override
  String get signupCaptchaErrorMessage =>
      'No se puede cargar el captcha.\nToca refrescar para intentarlo de nuevo.';

  @override
  String get notificationsRestartTitle =>
      'Reinicia la app para activar las notificaciones';

  @override
  String get notificationsRestartSubtitle =>
      'Permisos necesarios ya concedidos';

  @override
  String get notificationsMessageToggle => 'Notificaciones de mensajes';

  @override
  String get notificationsRequiresRestart => 'Requiere reinicio';

  @override
  String get notificationsDialogTitle => 'Activar notificaciones de mensajes';

  @override
  String get notificationsDialogIgnore => 'Ignorar';

  @override
  String get notificationsDialogContinue => 'Continuar';

  @override
  String get notificationsDialogDescription =>
      'Siempre puedes silenciar los chats después.';

  @override
  String get calendarAdjustStartMinus => 'Inicio -15 min';

  @override
  String get calendarAdjustStartPlus => 'Inicio +15 min';

  @override
  String get calendarAdjustEndMinus => 'Fin -15 min';

  @override
  String get calendarAdjustEndPlus => 'Fin +15 min';

  @override
  String get calendarCopyToClipboardAction => 'Copiar al portapapeles';

  @override
  String calendarCopyLocation(Object location) {
    return 'Ubicación: $location';
  }

  @override
  String get calendarTaskCopied => 'Tarea copiada';

  @override
  String get calendarTaskCopiedClipboard => 'Tarea copiada al portapapeles';

  @override
  String get calendarCopyTask => 'Copiar tarea';

  @override
  String get calendarDeleteTask => 'Eliminar tarea';

  @override
  String get calendarSelectionNoneShort => 'No hay tareas seleccionadas.';

  @override
  String get calendarSelectionMixedRecurrence =>
      'Las tareas tienen configuraciones de recurrencia distintas. Las actualizaciones se aplicarán a todas las seleccionadas.';

  @override
  String get calendarSelectionNoTasksHint =>
      'No hay tareas seleccionadas. Usa la opción Seleccionar en el calendario para elegir tareas que editar.';

  @override
  String get calendarSelectionRemove => 'Quitar de la selección';

  @override
  String get calendarQuickTaskHint =>
      'Tarea rápida (p. ej., \"Reunión a las 2pm en la Sala 101\")';

  @override
  String get calendarAdvancedHide => 'Ocultar opciones avanzadas';

  @override
  String get calendarAdvancedShow => 'Mostrar opciones avanzadas';

  @override
  String get calendarUnscheduledTitle => 'Tareas sin programar';

  @override
  String get calendarUnscheduledEmptyLabel => 'No hay tareas sin programar';

  @override
  String get calendarUnscheduledEmptyHint =>
      'Las tareas que agregues aparecerán aquí';

  @override
  String get calendarRemindersTitle => 'Recordatorios';

  @override
  String get calendarRemindersEmptyLabel => 'Aún no hay recordatorios';

  @override
  String get calendarRemindersEmptyHint =>
      'Añade una fecha límite para crear un recordatorio';

  @override
  String get calendarNothingHere => 'Nada aquí todavía';

  @override
  String get calendarTaskNotFound => 'Tarea no encontrada';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileJidDescription =>
      'Este es tu Jabber ID. Consta de tu nombre de usuario y dominio; es una dirección única que te representa en la red XMPP.';

  @override
  String get profileResourceDescription =>
      'Este es tu recurso XMPP. Cada dispositivo que usas tiene uno diferente, por eso tu teléfono puede tener un estado distinto al de tu computadora.';

  @override
  String get profileStatusPlaceholder => 'Mensaje de estado';

  @override
  String get profileArchives => 'Ver archivos';

  @override
  String get profileChangePassword => 'Cambiar contraseña';

  @override
  String get profileDeleteAccount => 'Eliminar cuenta';

  @override
  String get termsAcceptLabel => 'Acepto los términos y condiciones';

  @override
  String get termsAgreementPrefix => 'Aceptas nuestras ';

  @override
  String get termsAgreementTerms => 'términos';

  @override
  String get termsAgreementAnd => ' y ';

  @override
  String get termsAgreementPrivacy => 'política de privacidad';

  @override
  String get termsAgreementError => 'Debes aceptar los términos y condiciones';
}
