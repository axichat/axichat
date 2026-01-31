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
  String get homeTabChats => 'Conversaciones';

  @override
  String get homeTabDrafts => 'Borradores';

  @override
  String get homeTabSpam => 'Correo no deseado';

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
  String get homeSyncTooltip => 'Sincronizar ahora';

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
  String get attachmentGalleryRosterTrustLabel =>
      'Descargar archivos automáticamente de este usuario';

  @override
  String get attachmentGalleryRosterTrustHint =>
      'Puedes desactivarlo más tarde en los ajustes del chat.';

  @override
  String get attachmentGalleryChatTrustLabel =>
      'Permitir siempre los archivos adjuntos en este chat';

  @override
  String get attachmentGalleryChatTrustHint =>
      'Puedes desactivarlo más tarde en los ajustes del chat.';

  @override
  String get attachmentGalleryRosterErrorTitle =>
      'No se pudo añadir el contacto';

  @override
  String get attachmentGalleryRosterErrorMessage =>
      'Se descargó este archivo adjunto una vez, pero las descargas automáticas siguen desactivadas.';

  @override
  String get attachmentGalleryErrorMessage =>
      'No se pudieron cargar los archivos adjuntos.';

  @override
  String get attachmentGalleryAllLabel => 'Todos';

  @override
  String get attachmentGalleryImagesLabel => 'Imágenes';

  @override
  String get attachmentGalleryVideosLabel => 'Videos';

  @override
  String get attachmentGalleryFilesLabel => 'Archivos';

  @override
  String get attachmentGallerySentLabel => 'Enviado';

  @override
  String get attachmentGalleryReceivedLabel => 'Recibido';

  @override
  String get attachmentGalleryMetaSeparator => ' - ';

  @override
  String get attachmentGalleryLayoutGridLabel => 'Grid view';

  @override
  String get attachmentGalleryLayoutListLabel => 'List view';

  @override
  String get attachmentGallerySortNameAscLabel => 'Nombre A-Z';

  @override
  String get attachmentGallerySortNameDescLabel => 'Nombre Z-A';

  @override
  String get attachmentGallerySortSizeAscLabel => 'Tamaño de menor a mayor';

  @override
  String get attachmentGallerySortSizeDescLabel => 'Tamaño de mayor a menor';

  @override
  String get chatOpenLinkTitle => '¿Abrir enlace externo?';

  @override
  String chatOpenLinkMessage(Object url, Object host) {
    return 'Vas a abrir:\n$url\n\nToca Aceptar solo si confías en el sitio (host: $host).';
  }

  @override
  String chatOpenLinkWarningMessage(Object url, Object host) {
    return 'Vas a abrir:\n$url\n\nEste enlace contiene caracteres inusuales o invisibles. Verifica la dirección con cuidado (host: $host).';
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
  String chatComposerFromHint(Object address) {
    return 'Enviando desde $address';
  }

  @override
  String get chatComposerEmptyMessage => 'El mensaje no puede estar vacío.';

  @override
  String get chatComposerEmailUnavailable =>
      'El envío de correo no está disponible en este chat.';

  @override
  String get chatComposerFileUploadUnavailable =>
      'La carga de archivos no está disponible en este servidor.';

  @override
  String get chatComposerSelectRecipient =>
      'Selecciona al menos un destinatario.';

  @override
  String get chatComposerEmailRecipientUnavailable =>
      'El correo no está disponible para uno o más destinatarios.';

  @override
  String get chatComposerEmailAttachmentRecipientRequired =>
      'Agrega un destinatario de correo para enviar archivos adjuntos.';

  @override
  String get chatComposerDraftRecipientsUnavailable =>
      'No se pudieron resolver los destinatarios de este borrador.';

  @override
  String get chatComposerSendFailed =>
      'No se pudo enviar el mensaje. Inténtalo de nuevo.';

  @override
  String get chatComposerAttachmentBundleFailed =>
      'No se pudieron agrupar los archivos adjuntos. Inténtalo de nuevo.';

  @override
  String get chatEmailOfflineRetryMessage =>
      'El correo está sin conexión. Reintenta cuando la sincronización se recupere.';

  @override
  String get chatEmailOfflineDraftsFallback =>
      'El correo está sin conexión. Los mensajes se guardarán en Borradores hasta que vuelva la conexión.';

  @override
  String get chatEmailSyncRefreshing =>
      'La sincronización de correo se está actualizando...';

  @override
  String get chatEmailSyncFailed =>
      'La sincronización de correo falló. Inténtalo de nuevo.';

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
  String get chatReportSpam => 'Marcar como spam';

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
  String get chatCalendarTaskCopyActionLabel => 'Copiar al calendario';

  @override
  String get chatCalendarTaskImportConfirmTitle => '¿Agregar al calendario?';

  @override
  String get chatCalendarTaskImportConfirmMessage =>
      'Esta tarea proviene del chat. Agrégala a tu calendario para administrarla o editarla.';

  @override
  String get chatCalendarTaskImportConfirmLabel => 'Agregar al calendario';

  @override
  String get chatCalendarTaskImportCancelLabel => 'Ahora no';

  @override
  String get chatCalendarTaskCopyUnavailableMessage =>
      'El calendario no está disponible.';

  @override
  String get chatCalendarTaskCopyAlreadyAddedMessage =>
      'La tarea ya fue agregada.';

  @override
  String get chatCalendarTaskCopySuccessMessage => 'Tarea copiada.';

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
  String get draftAutosaved => 'Guardado automáticamente';

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
  String draftLimitWarning(int limit, int count) {
    return 'La sincronización de borradores admite hasta $limit borradores. Ya tienes $count.';
  }

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
  String get chatCopySuccessMessage => 'Copiado al portapapeles';

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
  String get draftRestoreAction => 'Restaurar desde borrador';

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
  String get authRememberMeLabel => 'Recordarme en este dispositivo';

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
  String get signupAvatarRenderError => 'No se pudo generar ese avatar.';

  @override
  String get signupAvatarLoadError => 'No se pudo cargar ese avatar.';

  @override
  String get signupAvatarReadError => 'No se pudo leer esa imagen.';

  @override
  String get signupAvatarOpenError => 'No se pudo abrir ese archivo.';

  @override
  String get signupAvatarInvalidImage => 'Ese archivo no es una imagen válida.';

  @override
  String signupAvatarSizeError(Object kilobytes) {
    return 'El avatar debe ser menor de $kilobytes KB.';
  }

  @override
  String get signupAvatarProcessError => 'No se pudo procesar esa imagen.';

  @override
  String get signupAvatarEdit => 'Editar avatar';

  @override
  String get signupAvatarUploadImage => 'Subir imagen';

  @override
  String get signupAvatarUpload => 'Subir';

  @override
  String get signupAvatarShuffle => 'Mezclar predeterminado';

  @override
  String get signupAvatarMenuDescription =>
      'Publicaremos el avatar cuando se cree tu cuenta XMPP.';

  @override
  String get avatarSaveAvatar => 'Guardar avatar';

  @override
  String get avatarUseThis => 'Establecer avatar';

  @override
  String get signupAvatarBackgroundColor => 'Color de fondo';

  @override
  String get signupAvatarDefaultsTitle => 'Avatares predeterminados';

  @override
  String get signupAvatarCategoryAbstract => 'Abstracto';

  @override
  String get signupAvatarCategoryScience => 'Ciencia';

  @override
  String get signupAvatarCategorySports => 'Deportes';

  @override
  String get signupAvatarCategoryMusic => 'Música';

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
  String get calendarDayEventsTitle => 'Eventos del día';

  @override
  String get calendarDayEventsEmpty => 'No hay eventos de dia para esta fecha';

  @override
  String get calendarDayEventsAdd => 'Agregar evento del día';

  @override
  String get accessibilityNewContactLabel => 'Dirección de contacto';

  @override
  String get accessibilityNewContactHint => 'alguien@ejemplo.com';

  @override
  String get accessibilityStartChat => 'Iniciar chat';

  @override
  String get accessibilityStartChatHint =>
      'Envía esta dirección para iniciar una conversación.';

  @override
  String get accessibilityMessagesEmpty => 'Aún no hay mensajes';

  @override
  String get accessibilityMessageNoContent => 'Sin contenido de mensaje';

  @override
  String get accessibilityActionsTitle => 'Acciones';

  @override
  String get accessibilityReadNewMessages => 'Leer mensajes nuevos';

  @override
  String get accessibilityUnreadSummaryDescription =>
      'Céntrate en las conversaciones con mensajes sin leer';

  @override
  String get accessibilityStartNewChat => 'Iniciar un nuevo chat';

  @override
  String get accessibilityStartNewChatDescription =>
      'Elige un contacto o escribe una dirección';

  @override
  String get accessibilityInvitesTitle => 'Invitaciones';

  @override
  String get accessibilityPendingInvites => 'Invitaciones pendientes';

  @override
  String get accessibilityAcceptInvite => 'Aceptar invitación';

  @override
  String get accessibilityInviteAccepted => 'Invitación aceptada';

  @override
  String get accessibilityInviteDismissed => 'Invitación rechazada';

  @override
  String get accessibilityInviteUpdateFailed =>
      'No se pudo actualizar la invitación';

  @override
  String get accessibilityUnreadEmpty => 'No hay conversaciones sin leer';

  @override
  String get accessibilityInvitesEmpty => 'No hay invitaciones pendientes';

  @override
  String get accessibilityMessagesTitle => 'Mensajes';

  @override
  String get accessibilityNoConversationSelected =>
      'No hay conversación seleccionada';

  @override
  String accessibilityMessagesWithContact(Object name) {
    return 'Mensajes con $name';
  }

  @override
  String accessibilityMessageLabel(
      Object sender, Object timestamp, Object body) {
    return '$sender a las $timestamp: $body';
  }

  @override
  String get accessibilityMessageSent => 'Mensaje enviado.';

  @override
  String get accessibilityDiscardWarning =>
      'Presiona Escape otra vez para descartar tu mensaje y cerrar este paso.';

  @override
  String get accessibilityDraftLoaded =>
      'Borrador cargado. Presiona Escape para salir o Guardar para mantener los cambios.';

  @override
  String accessibilityDraftLabel(Object id) {
    return 'Borrador $id';
  }

  @override
  String accessibilityDraftLabelWithRecipients(Object recipients) {
    return 'Borrador para $recipients';
  }

  @override
  String accessibilityDraftPreview(Object recipients, Object preview) {
    return '$recipients — $preview';
  }

  @override
  String accessibilityIncomingMessageStatus(Object sender, Object time) {
    return 'Nuevo mensaje de $sender a las $time';
  }

  @override
  String accessibilityAttachmentWithName(Object filename) {
    return 'Archivo adjunto: $filename';
  }

  @override
  String get accessibilityAttachmentGeneric => 'Adjunto';

  @override
  String get accessibilityUploadAvailable => 'Carga disponible';

  @override
  String get accessibilityUnknownContact => 'Contacto desconocido';

  @override
  String get accessibilityChooseContact => 'Elegir un contacto';

  @override
  String get accessibilityUnreadConversations => 'Conversaciones sin leer';

  @override
  String get accessibilityStartNewAddress => 'Ingresar una nueva dirección';

  @override
  String accessibilityConversationWith(Object name) {
    return 'Conversación con $name';
  }

  @override
  String get accessibilityConversationLabel => 'Conversación';

  @override
  String get accessibilityDialogLabel => 'Diálogo de accesibilidad';

  @override
  String get accessibilityDialogHint =>
      'Presiona Tab para ver los atajos, usa las flechas dentro de las listas, Mayús más flechas para moverte entre grupos o Escape para salir.';

  @override
  String get accessibilityNoActionsAvailable =>
      'No hay acciones disponibles ahora';

  @override
  String accessibilityBreadcrumbLabel(
      Object position, Object total, Object label) {
    return 'Paso $position de $total: $label. Activa para saltar a este paso.';
  }

  @override
  String get accessibilityShortcutOpenMenu => 'Abrir menú';

  @override
  String get accessibilityShortcutBack => 'Atrás un paso o cerrar';

  @override
  String get accessibilityShortcutNextFocus => 'Siguiente objetivo de foco';

  @override
  String get accessibilityShortcutPreviousFocus => 'Objetivo de foco anterior';

  @override
  String get accessibilityShortcutActivateItem => 'Activar elemento';

  @override
  String get accessibilityShortcutNextItem => 'Elemento siguiente';

  @override
  String get accessibilityShortcutPreviousItem => 'Elemento anterior';

  @override
  String get accessibilityShortcutNextGroup => 'Siguiente grupo';

  @override
  String get accessibilityShortcutPreviousGroup => 'Grupo anterior';

  @override
  String get accessibilityShortcutFirstItem => 'Primer elemento';

  @override
  String get accessibilityShortcutLastItem => 'Último elemento';

  @override
  String get accessibilityKeyboardShortcutsTitle => 'Atajos de teclado';

  @override
  String accessibilityKeyboardShortcutAnnouncement(Object description) {
    return 'Atajo de teclado: $description';
  }

  @override
  String get accessibilityTextFieldHint =>
      'Ingresa texto. Usa Tab para avanzar o Escape para regresar o cerrar el menú.';

  @override
  String get accessibilityLoadingLabel => 'Cargando';

  @override
  String get accessibilityComposerPlaceholder => 'Escribe un mensaje';

  @override
  String accessibilityRecipientLabel(Object name) {
    return 'Destinatario $name';
  }

  @override
  String get accessibilityRecipientRemoveHint =>
      'Presiona retroceso o suprimir para quitar';

  @override
  String get accessibilityMessageActionsLabel => 'Acciones del mensaje';

  @override
  String get accessibilityMessageActionsHint =>
      'Guardar como borrador o enviar este mensaje';

  @override
  String accessibilityMessagePosition(Object position, Object total) {
    return 'Mensaje $position de $total';
  }

  @override
  String get accessibilityNoMessages => 'No hay mensajes';

  @override
  String accessibilityMessageMetadata(Object sender, Object timestamp) {
    return 'De $sender a las $timestamp';
  }

  @override
  String accessibilityMessageFrom(Object sender) {
    return 'De $sender';
  }

  @override
  String get accessibilityMessageNavigationHint =>
      'Usa las flechas para moverte entre mensajes. Mayús más flechas cambia de grupo. Presiona Escape para salir.';

  @override
  String accessibilitySectionSummary(Object section, Object count) {
    return 'Sección $section con $count elementos';
  }

  @override
  String accessibilityActionListLabel(Object count) {
    return 'Lista de acciones con $count elementos';
  }

  @override
  String get accessibilityActionListHint =>
      'Usa flechas para moverte, Mayús más flechas para cambiar de grupo, Inicio/Fin para saltar, Enter para activar, Escape para salir.';

  @override
  String accessibilityActionItemPosition(
      Object position, Object total, Object section) {
    return 'Elemento $position de $total en $section';
  }

  @override
  String get accessibilityActionReadOnlyHint =>
      'Usa las flechas para recorrer la lista';

  @override
  String get accessibilityActionActivateHint => 'Presiona Enter para activar';

  @override
  String get accessibilityDismissHighlight => 'Descartar destacado';

  @override
  String get accessibilityNeedsAttention => 'Requiere atención';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileJumpToTop => 'Back to top';

  @override
  String get settingsWebsiteLabel => 'Website';

  @override
  String get settingsDonateLabel => 'Donate';

  @override
  String get settingsMastodonLabel => 'Mastodon';

  @override
  String get settingsGithubLabel => 'GitHub';

  @override
  String get settingsGitlabLabel => 'GitLab';

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
  String get profileEditAvatar => 'Editar avatar';

  @override
  String get profileLinkedEmailAccounts => 'Email accounts';

  @override
  String get profileChangePassword => 'Cambiar contraseña';

  @override
  String get profileDeleteAccount => 'Eliminar cuenta';

  @override
  String profileExportActionLabel(Object label) {
    return 'Exportar $label';
  }

  @override
  String get profileExportXmppMessagesLabel => 'Mensajes XMPP';

  @override
  String get profileExportXmppContactsLabel => 'Contactos XMPP';

  @override
  String get profileExportEmailMessagesLabel => 'Correos';

  @override
  String get profileExportEmailContactsLabel => 'Contactos de correo';

  @override
  String profileExportShareText(Object label) {
    return 'Exportación de Axichat: $label';
  }

  @override
  String profileExportShareSubject(Object label) {
    return 'Exportación de Axichat: $label';
  }

  @override
  String profileExportReadyMessage(Object label) {
    return 'Exportación de $label lista.';
  }

  @override
  String profileExportEmptyMessage(Object label) {
    return 'No hay $label para exportar.';
  }

  @override
  String profileExportFailedMessage(Object label) {
    return 'No se pudo exportar $label.';
  }

  @override
  String profileExportShareUnsupportedMessage(Object label, Object path) {
    return 'Compartir no está disponible en esta plataforma. Exportación de $label guardada en $path.';
  }

  @override
  String get profileExportCopyPathAction => 'Copiar ruta';

  @override
  String get profileExportPathCopiedMessage =>
      'Ruta de exportación copiada al portapapeles.';

  @override
  String get profileExportFormatTitle => 'Elegir formato de exportación';

  @override
  String get profileExportFormatCsvTitle => 'CSV (.csv)';

  @override
  String get profileExportFormatCsvSubtitle =>
      'Funciona con la mayoría de libretas de direcciones.';

  @override
  String get profileExportFormatVcardTitle => 'vCard (.vcf)';

  @override
  String get profileExportFormatVcardSubtitle =>
      'Tarjetas de contacto estándar.';

  @override
  String get profileExportCsvHeaderName => 'Nombre';

  @override
  String get profileExportCsvHeaderAddress => 'Dirección';

  @override
  String get profileExportContactsFilenameFallback => 'contactos';

  @override
  String get termsAcceptLabel => 'Acepto los términos y condiciones';

  @override
  String get termsAgreementPrefix => 'Aceptas nuestras ';

  @override
  String get termsAgreementTerms => 'términos';

  @override
  String get termsAgreementAnd => ' y ';

  @override
  String get termsAgreementPrivacy => 'privacidad';

  @override
  String get termsAgreementError => 'Debes aceptar los términos y condiciones';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonRemove => 'Quitar';

  @override
  String get commonSend => 'Enviar';

  @override
  String get commonDismiss => 'Descartar';

  @override
  String get settingsButtonLabel => 'Configuración';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSectionData => 'Data';

  @override
  String get settingsSectionImportant => 'Importante';

  @override
  String get settingsSectionAppearance => 'Apariencia';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsThemeMode => 'Modo de tema';

  @override
  String get settingsThemeModeSystem => 'Sistema';

  @override
  String get settingsThemeModeLight => 'Claro';

  @override
  String get settingsThemeModeDark => 'Oscuro';

  @override
  String get settingsColorScheme => 'Esquema de color';

  @override
  String get settingsColorfulAvatars => 'Avatares coloridos';

  @override
  String get settingsColorfulAvatarsDescription =>
      'Genera colores de fondo diferentes para cada avatar.';

  @override
  String get settingsLowMotion => 'Movimiento reducido';

  @override
  String get settingsLowMotionDescription =>
      'Desactiva la mayoría de las animaciones. Mejor para dispositivos lentos.';

  @override
  String get settingsSectionChats => 'Chat preferences';

  @override
  String get settingsSectionEmail => 'Email preferences';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsAboutAxichat => 'About Axichat';

  @override
  String get settingsAboutLegalese =>
      'Copyright (C) 2025 Axichat LLC\n\nThis program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.\n\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.\n\nYou should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.';

  @override
  String get settingsTermsLabel => 'Terms';

  @override
  String get settingsPrivacyLabel => 'Privacy';

  @override
  String get settingsLicenseAgpl => 'AGPLv3';

  @override
  String get settingsMuteNotifications => 'Silenciar notificaciones';

  @override
  String get settingsMuteNotificationsDescription =>
      'Deja de recibir notificaciones de mensajes.';

  @override
  String get settingsNotificationPreviews =>
      'Previsualizaciones de notificación';

  @override
  String get settingsNotificationPreviewsDescription =>
      'Mostrar el contenido de los mensajes en notificaciones y en la pantalla de bloqueo.';

  @override
  String get settingsChatReadReceipts =>
      'Enviar confirmaciones de lectura de chats';

  @override
  String get settingsChatReadReceiptsDescription =>
      'Si está activado, abrir un chat mientras la app está activa envía confirmaciones de lectura para los mensajes visibles.';

  @override
  String get settingsEmailReadReceipts =>
      'Enviar confirmaciones de lectura de correo';

  @override
  String get settingsEmailReadReceiptsDescription =>
      'Si está activado, abrir un chat de correo mientras la app está activa envía confirmaciones de lectura (MDN) para los mensajes visibles.';

  @override
  String get settingsTypingIndicators => 'Enviar indicadores de escritura';

  @override
  String get settingsTypingIndicatorsDescription =>
      'Permite que otros en el chat vean cuando estás escribiendo.';

  @override
  String get settingsShareTokenFooter => 'Incluir pie de token de compartir';

  @override
  String get settingsShareTokenFooterDescription =>
      'Ayuda a mantener enlazados los hilos de correo con varios destinatarios y sus adjuntos. Desactivarlo puede romper el hilo.';

  @override
  String get authCustomServerTitle => 'Servidor personalizado';

  @override
  String get authCustomServerDescription =>
      'Anula los endpoints XMPP/SMTP o habilita búsquedas DNS. Deja los campos vacíos para mantener los valores predeterminados.';

  @override
  String get authCustomServerDomainOrIp => 'Dominio o IP';

  @override
  String get authCustomServerXmppLabel => 'XMPP';

  @override
  String get authCustomServerSmtpLabel => 'SMTP';

  @override
  String get authCustomServerUseDns => 'Usar DNS';

  @override
  String get authCustomServerUseSrv => 'Usar SRV';

  @override
  String get authCustomServerRequireDnssec => 'Requerir DNSSEC';

  @override
  String get authCustomServerXmppHostPlaceholder => 'Host XMPP (opcional)';

  @override
  String get authCustomServerPortPlaceholder => 'Puerto';

  @override
  String get authCustomServerSmtpHostPlaceholder => 'Host SMTP (opcional)';

  @override
  String get authCustomServerImapHostPlaceholder => 'Host IMAP (opcional)';

  @override
  String get authCustomServerApiPortPlaceholder => 'Puerto API';

  @override
  String get authCustomServerEmailProvisioningUrlPlaceholder =>
      'URL de aprovisionamiento de correo (opcional)';

  @override
  String get authCustomServerEmailPublicTokenPlaceholder =>
      'Token público de correo (opcional)';

  @override
  String get authCustomServerReset => 'Restablecer a axi.im';

  @override
  String get authCustomServerOpenSettings =>
      'Abrir ajustes de servidor personalizado';

  @override
  String get authCustomServerAdvancedHint =>
      'Las opciones avanzadas del servidor se mantienen ocultas hasta que toques el sufijo de usuario.';

  @override
  String get authUnregisterTitle => 'Dar de baja';

  @override
  String get authUnregisterConfirmTitle => 'Delete account?';

  @override
  String get authUnregisterConfirmMessage =>
      'This will permanently delete your account and local data. This cannot be undone.';

  @override
  String get authUnregisterConfirmAction => 'Delete account';

  @override
  String get authUnregisterProgressLabel =>
      'Esperando la eliminación de la cuenta';

  @override
  String get authPasswordPlaceholder => 'Contraseña';

  @override
  String get authPasswordCurrentPlaceholder => 'Contraseña anterior';

  @override
  String get authPasswordNewPlaceholder => 'Nueva contraseña';

  @override
  String get authPasswordConfirmNewPlaceholder => 'Confirmar nueva contraseña';

  @override
  String get authChangePasswordProgressLabel =>
      'Esperando el cambio de contraseña';

  @override
  String get authLogoutTitle => 'Cerrar sesión';

  @override
  String get authLogoutNormal => 'Cerrar sesión';

  @override
  String get authLogoutNormalDescription => 'Cerrar sesión de esta cuenta.';

  @override
  String get authLogoutBurn => 'Borrar cuenta';

  @override
  String get authLogoutBurnDescription =>
      'Cerrar sesión y borrar los datos locales de esta cuenta.';

  @override
  String get chatAttachmentBlockedTitle => 'Adjunto bloqueado';

  @override
  String get chatEmailImageBlockedLabel => 'Imagen bloqueada';

  @override
  String get chatEmailImageFailedLabel => 'Imagen fallida';

  @override
  String get chatAttachmentBlockedDescription =>
      'Cargar adjuntos de contactos desconocidos solo si confías en ellos. Lo descargaremos cuando lo apruebes.';

  @override
  String get chatAttachmentLoad => 'Cargar adjunto';

  @override
  String get chatAttachmentUnavailable => 'Adjunto no disponible';

  @override
  String get chatAttachmentSendFailed => 'No se pudo enviar el adjunto.';

  @override
  String get chatAttachmentRetryUpload => 'Reintentar carga';

  @override
  String get chatAttachmentRemoveAttachment => 'Quitar adjunto';

  @override
  String get chatAttachmentStatusUploading => 'Subiendo adjunto…';

  @override
  String get chatAttachmentStatusQueued => 'Esperando para enviar';

  @override
  String get chatAttachmentStatusFailed => 'Carga fallida';

  @override
  String get chatAttachmentLoading => 'Cargando adjunto';

  @override
  String chatAttachmentLoadingProgress(Object percent) {
    return 'Cargando $percent';
  }

  @override
  String get chatAttachmentDownload => 'Descargar adjunto';

  @override
  String get chatAttachmentDownloadAndOpen => 'Descargar y abrir';

  @override
  String get chatAttachmentDownloadAndSave => 'Descargar y guardar';

  @override
  String get chatAttachmentDownloadAndShare => 'Descargar y compartir';

  @override
  String get chatAttachmentExportTitle => '¿Guardar adjunto?';

  @override
  String get chatAttachmentExportMessage =>
      'Esto copiará el adjunto al almacenamiento compartido. Las exportaciones no están cifradas y otras apps pueden leerlas. ¿Continuar?';

  @override
  String get chatAttachmentExportConfirm => 'Guardar';

  @override
  String get chatAttachmentExportCancel => 'Cancelar';

  @override
  String get chatMediaMetadataWarningTitle =>
      'Los medios pueden incluir metadatos';

  @override
  String get chatMediaMetadataWarningMessage =>
      'Las fotos y los videos pueden incluir ubicación y datos del dispositivo. ¿Continuar?';

  @override
  String get chatNotificationPreviewOptionInherit =>
      'Usar la configuración de la app';

  @override
  String get chatNotificationPreviewOptionShow =>
      'Mostrar vistas previas siempre';

  @override
  String get chatNotificationPreviewOptionHide =>
      'Ocultar vistas previas siempre';

  @override
  String get chatAttachmentUnavailableDevice =>
      'El adjunto ya no está disponible en este dispositivo';

  @override
  String get chatAttachmentInvalidLink => 'Enlace de adjunto no válido';

  @override
  String chatAttachmentOpenFailed(Object target) {
    return 'No se pudo abrir $target';
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
  String get chatAttachmentUnknownSize => 'Tamaño desconocido';

  @override
  String get chatAttachmentNotDownloadedYet => 'Not downloaded yet';

  @override
  String chatAttachmentErrorTooltip(Object message, Object fileName) {
    return '$message ($fileName)';
  }

  @override
  String get chatAttachmentMenuHint => 'Abre el menú para ver acciones.';

  @override
  String get accessibilityActionsLabel => 'Acciones de accesibilidad';

  @override
  String accessibilityActionsShortcutTooltip(Object shortcut) {
    return 'Acciones de accesibilidad ($shortcut)';
  }

  @override
  String get shorebirdUpdateAvailable =>
      'Actualización disponible: cierra sesión y reinicia la app';

  @override
  String get calendarEditTaskTitle => 'Editar tarea';

  @override
  String get calendarDateTimeLabel => 'Fecha y hora';

  @override
  String get calendarSelectDate => 'Seleccionar fecha';

  @override
  String get calendarSelectTime => 'Seleccionar hora';

  @override
  String get calendarDurationLabel => 'Duración';

  @override
  String get calendarSelectDuration => 'Seleccionar duración';

  @override
  String get calendarAddToCriticalPath => 'Agregar a la ruta crítica';

  @override
  String get calendarNoCriticalPathMembership =>
      'No está en ninguna ruta crítica';

  @override
  String get calendarGuestTitle => 'Calendario de invitado';

  @override
  String get calendarGuestBanner => 'Modo invitado - Sin sincronización';

  @override
  String get calendarGuestModeLabel => 'Modo invitado';

  @override
  String get calendarGuestModeDescription =>
      'Inicia sesión para sincronizar tareas y activar recordatorios.';

  @override
  String get calendarNoTasksForDate => 'No hay tareas para esta fecha';

  @override
  String get calendarTapToCreateTask => 'Toca + para crear una nueva tarea';

  @override
  String get calendarQuickStats => 'Estadísticas rápidas';

  @override
  String get calendarDueReminders => 'Recordatorios vencidos';

  @override
  String get calendarNextTaskLabel => 'Próxima tarea';

  @override
  String get calendarNone => 'Ninguna';

  @override
  String get calendarViewLabel => 'Vista';

  @override
  String get calendarViewDay => 'Día';

  @override
  String get calendarViewWeek => 'Semana';

  @override
  String get calendarViewMonth => 'Mes';

  @override
  String get calendarPreviousDate => 'Fecha anterior';

  @override
  String get calendarNextDate => 'Fecha siguiente';

  @override
  String calendarPreviousUnit(Object unit) {
    return 'Anterior $unit';
  }

  @override
  String calendarNextUnit(Object unit) {
    return 'Siguiente $unit';
  }

  @override
  String get calendarToday => 'Hoy';

  @override
  String get calendarUndo => 'Deshacer';

  @override
  String get calendarRedo => 'Rehacer';

  @override
  String get calendarOpeningCreator => 'Abriendo creador de tareas...';

  @override
  String calendarWeekOf(Object date) {
    return 'Semana de $date';
  }

  @override
  String get calendarStatusCompleted => 'Completada';

  @override
  String get calendarStatusOverdue => 'Atrasada';

  @override
  String get calendarStatusDueSoon => 'Próxima a vencer';

  @override
  String get calendarStatusPending => 'Pendiente';

  @override
  String get calendarTaskCompletedMessage => '¡Tarea completada!';

  @override
  String get calendarTaskUpdatedMessage => 'Tarea actualizada';

  @override
  String get calendarErrorTitle => 'Error';

  @override
  String get calendarErrorTaskNotFound => 'Tarea no encontrada';

  @override
  String get calendarErrorTitleEmpty => 'El título no puede estar vacío';

  @override
  String get calendarErrorTitleTooLong => 'Título demasiado largo';

  @override
  String get calendarErrorDescriptionTooLong => 'Descripción demasiado larga';

  @override
  String get calendarErrorInputInvalid => 'Entrada no válida';

  @override
  String get calendarErrorAddFailed => 'No se pudo agregar la tarea';

  @override
  String get calendarErrorUpdateFailed => 'No se pudo actualizar la tarea';

  @override
  String get calendarErrorDeleteFailed => 'No se pudo eliminar la tarea';

  @override
  String get calendarErrorNetwork => 'Error de red';

  @override
  String get calendarErrorStorage => 'Error de almacenamiento';

  @override
  String get calendarErrorUnknown => 'Error desconocido';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonOpen => 'Abrir';

  @override
  String get commonSelect => 'Seleccionar';

  @override
  String get commonExport => 'Exportar';

  @override
  String get commonFavorite => 'Favorito';

  @override
  String get commonUnfavorite => 'Quitar favorito';

  @override
  String get commonArchive => 'Archivar';

  @override
  String get commonUnarchive => 'Desarchivar';

  @override
  String get commonShow => 'Mostrar';

  @override
  String get commonHide => 'Ocultar';

  @override
  String get blocklistBlockUser => 'Bloquear usuario';

  @override
  String get blocklistWaitingForUnblock => 'Esperando desbloqueo';

  @override
  String get blocklistUnblockAll => 'Desbloquear todo';

  @override
  String get blocklistUnblock => 'Desbloquear';

  @override
  String get blocklistBlock => 'Bloquear';

  @override
  String get blocklistAddTooltip => 'Agregar a la lista bloqueada';

  @override
  String get blocklistInvalidJid => 'Introduce una dirección válida.';

  @override
  String blocklistBlockFailed(Object address) {
    return 'Error al bloquear $address. Inténtalo de nuevo más tarde.';
  }

  @override
  String blocklistUnblockFailed(Object address) {
    return 'Error al desbloquear $address. Inténtalo de nuevo más tarde.';
  }

  @override
  String blocklistBlocked(Object address) {
    return '$address bloqueado.';
  }

  @override
  String blocklistUnblocked(Object address) {
    return '$address desbloqueado.';
  }

  @override
  String get blocklistBlockingUnsupported =>
      'El servidor no admite el bloqueo.';

  @override
  String get blocklistUnblockingUnsupported =>
      'El servidor no admite el desbloqueo.';

  @override
  String get blocklistUnblockAllFailed =>
      'No se pudieron desbloquear los usuarios. Inténtalo de nuevo más tarde.';

  @override
  String get blocklistUnblockAllSuccess => 'Todos desbloqueados.';

  @override
  String get mucChangeNickname => 'Cambiar apodo';

  @override
  String mucChangeNicknameWithCurrent(Object current) {
    return 'Cambiar apodo (actual: $current)';
  }

  @override
  String get mucLeaveRoom => 'Salir de la sala';

  @override
  String get mucNoMembers => 'Aún no hay miembros';

  @override
  String get mucInviteUsers => 'Invitar usuarios';

  @override
  String get mucSendInvites => 'Enviar invitaciones';

  @override
  String get mucChangeNicknameTitle => 'Cambiar apodo';

  @override
  String get mucEnterNicknamePlaceholder => 'Introduce un apodo';

  @override
  String get mucUpdateNickname => 'Actualizar';

  @override
  String get mucMembersTitle => 'Miembros';

  @override
  String get mucEditAvatar => 'Editar avatar de la sala';

  @override
  String get mucAvatarMenuDescription =>
      'Los miembros de la sala verán este avatar.';

  @override
  String get mucInviteUser => 'Invitar usuario';

  @override
  String get mucSectionOwners => 'Propietarios';

  @override
  String get mucSectionAdmins => 'Administradores';

  @override
  String get mucSectionModerators => 'Moderadores';

  @override
  String get mucSectionMembers => 'Miembros';

  @override
  String get mucSectionVisitors => 'Visitantes';

  @override
  String get mucRoleOwner => 'Propietario';

  @override
  String get mucRoleAdmin => 'Administrador';

  @override
  String get mucRoleMember => 'Miembro';

  @override
  String get mucRoleVisitor => 'Visitante';

  @override
  String get mucRoleModerator => 'Moderador';

  @override
  String get mucActionKick => 'Expulsar';

  @override
  String get mucActionBan => 'Bloquear';

  @override
  String get mucActionMakeMember => 'Convertir en miembro';

  @override
  String get mucActionMakeAdmin => 'Hacer administrador';

  @override
  String get mucActionMakeOwner => 'Hacer propietario';

  @override
  String get mucActionGrantModerator => 'Conceder moderador';

  @override
  String get mucActionRevokeModerator => 'Revocar moderador';

  @override
  String get chatsEmptyList => 'Aún no hay chats';

  @override
  String chatsDeleteConfirmMessage(Object chatTitle) {
    return 'Eliminar chat: $chatTitle';
  }

  @override
  String get chatsDeleteMessagesOption => 'Eliminar mensajes permanentemente';

  @override
  String get chatsDeleteSuccess => 'Chat eliminado';

  @override
  String get chatsExportNoContent => 'No hay texto para exportar';

  @override
  String get chatsExportShareText => 'Exportación de chat desde Axichat';

  @override
  String chatsExportShareSubject(Object chatTitle) {
    return 'Chat con $chatTitle';
  }

  @override
  String get chatsExportSuccess => 'Chat exportado';

  @override
  String get chatsExportFailure => 'No se pudo exportar el chat';

  @override
  String get chatExportWarningTitle => '¿Exportar historial del chat?';

  @override
  String get chatExportWarningMessage =>
      'Las exportaciones de chat no están cifradas y otras apps o servicios en la nube pueden leerlas. ¿Continuar?';

  @override
  String get chatsArchivedRestored => 'Chat restaurado';

  @override
  String get chatsArchivedHint => 'Chat archivado (Perfil → Chats archivados)';

  @override
  String get chatsVisibleNotice => 'El chat vuelve a ser visible';

  @override
  String get chatsHiddenNotice => 'Chat oculto (usa el filtro para mostrarlo)';

  @override
  String chatsUnreadLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# mensajes sin leer',
      one: '# mensaje sin leer',
      zero: 'Sin mensajes sin leer',
    );
    return '$_temp0';
  }

  @override
  String get chatsSemanticsUnselectHint => 'Pulsa para deseleccionar el chat';

  @override
  String get chatsSemanticsSelectHint => 'Pulsa para seleccionar el chat';

  @override
  String get chatsSemanticsOpenHint => 'Pulsa para abrir el chat';

  @override
  String get chatsHideActions => 'Ocultar acciones del chat';

  @override
  String get chatsShowActions => 'Mostrar acciones del chat';

  @override
  String get chatsSelectedLabel => 'Chat seleccionado';

  @override
  String get chatsSelectLabel => 'Seleccionar chat';

  @override
  String get chatsExportFileLabel => 'chats';

  @override
  String get chatSelectionExportEmptyTitle => 'No hay mensajes para exportar';

  @override
  String get chatSelectionExportEmptyMessage =>
      'Selecciona chats con contenido de texto';

  @override
  String get chatSelectionExportShareText =>
      'Exportaciones de chat desde Axichat';

  @override
  String get chatSelectionExportShareSubject =>
      'Exportación de chats de Axichat';

  @override
  String get chatSelectionExportReadyTitle => 'Exportación lista';

  @override
  String chatSelectionExportReadyMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# chats compartidos',
      one: '# chat compartido',
    );
    return '$_temp0';
  }

  @override
  String get chatSelectionExportFailedTitle => 'Error de exportación';

  @override
  String get chatSelectionExportFailedMessage =>
      'No se pudieron exportar los chats seleccionados';

  @override
  String get chatSelectionDeleteConfirmTitle => '¿Eliminar chats?';

  @override
  String chatSelectionDeleteConfirmMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Esto elimina # chats y todos sus mensajes. No se puede deshacer.',
      one: 'Esto elimina 1 chat y todos sus mensajes. No se puede deshacer.',
    );
    return '$_temp0';
  }

  @override
  String get chatsCreateGroupChatTooltip => 'Crear chat grupal';

  @override
  String get chatsCreateGroupSuccess => 'Chat grupal creado.';

  @override
  String get chatsCreateGroupFailure => 'No se pudo crear el chat grupal.';

  @override
  String get chatsRefreshFailed => 'Sincronización fallida.';

  @override
  String get chatsRoomLabel => 'Sala';

  @override
  String get chatsCreateChatRoomTitle => 'Crear sala de chat';

  @override
  String get chatsCreateChatRoomAction => 'Crear sala';

  @override
  String get chatsRoomNamePlaceholder => 'Nombre';

  @override
  String get chatsRoomNameRequiredError =>
      'El nombre de la sala no puede estar vacío.';

  @override
  String chatsRoomNameInvalidCharacterError(Object character) {
    return 'Los nombres de sala no pueden contener $character.';
  }

  @override
  String get chatsArchiveTitle => 'Archivo';

  @override
  String get chatsArchiveEmpty => 'Aún no hay chats archivados';

  @override
  String calendarTileNow(Object title) {
    return 'Ahora: $title';
  }

  @override
  String calendarTileNext(Object title) {
    return 'Siguiente: $title';
  }

  @override
  String get calendarTileNone => 'No hay tareas próximas';

  @override
  String get calendarViewDayShort => 'D';

  @override
  String get calendarViewWeekShort => 'S';

  @override
  String get calendarViewMonthShort => 'M';

  @override
  String get calendarShowCompleted => 'Mostrar completadas';

  @override
  String get calendarHideCompleted => 'Ocultar completadas';

  @override
  String get rosterAddTooltip => 'Agregar a la lista de contactos';

  @override
  String get rosterAddLabel => 'Contacto';

  @override
  String get rosterAddTitle => 'Agregar contacto';

  @override
  String get rosterEmpty => 'Aún no hay contactos';

  @override
  String get rosterCompose => 'Redactar';

  @override
  String rosterRemoveConfirm(Object jid) {
    return '¿Eliminar $jid de los contactos?';
  }

  @override
  String get rosterInvitesEmpty => 'Aún no hay invitaciones';

  @override
  String rosterRejectInviteConfirm(Object jid) {
    return '¿Rechazar invitación de $jid?';
  }

  @override
  String get rosterAddContactTooltip => 'Agregar contacto';

  @override
  String get jidInputPlaceholder => 'john@axi.im';

  @override
  String get jidInputInvalid => 'Introduce un JID válido';

  @override
  String get sessionCapabilityChat => 'Chat';

  @override
  String get sessionCapabilityEmail => 'Correo';

  @override
  String get sessionCapabilityStatusConnected => 'Conectado';

  @override
  String get sessionCapabilityStatusConnecting => 'Conectando';

  @override
  String get sessionCapabilityStatusError => 'Error';

  @override
  String get sessionCapabilityStatusOffline => 'Sin conexión';

  @override
  String get sessionCapabilityStatusOff => 'Desactivado';

  @override
  String get sessionCapabilityStatusSyncing => 'Sincronizando';

  @override
  String get emailSyncMessageSyncing => 'Sincronizando correo...';

  @override
  String get emailSyncMessageConnecting =>
      'Conectando con servidores de correo...';

  @override
  String get emailSyncMessageDisconnected =>
      'Desconectado de los servidores de correo.';

  @override
  String get emailSyncMessageGroupMembershipChanged =>
      'La membresía del grupo de correo cambió. Vuelve a abrir el chat.';

  @override
  String get emailSyncMessageHistorySyncing =>
      'Sincronizando historial de correo...';

  @override
  String get emailSyncMessageRetrying =>
      'La sincronización de correo se reintentará pronto...';

  @override
  String get emailSyncMessageRefreshing =>
      'Actualizando la sincronización de correo tras una interrupción…';

  @override
  String get emailSyncMessageRefreshFailed =>
      'No se pudo actualizar la sincronización del correo. Intenta reabrir la app.';

  @override
  String get authChangePasswordPending => 'Actualizando contraseña...';

  @override
  String get authEndpointAdvancedHint => 'Opciones avanzadas';

  @override
  String get authEndpointApiPortPlaceholder => 'Puerto de API';

  @override
  String get authEndpointDescription =>
      'Configura los endpoints XMPP/SMTP para esta cuenta.';

  @override
  String get authEndpointDomainPlaceholder => 'Dominio';

  @override
  String get authEndpointPortPlaceholder => 'Puerto';

  @override
  String get authEndpointRequireDnssecLabel => 'Requerir DNSSEC';

  @override
  String get authEndpointReset => 'Restablecer';

  @override
  String get authEndpointSmtpHostPlaceholder => 'Host SMTP';

  @override
  String get authEndpointSmtpLabel => 'SMTP';

  @override
  String get authEndpointTitle => 'Configuración de endpoint';

  @override
  String get authEndpointUseDnsLabel => 'Usar DNS';

  @override
  String get authEndpointUseSrvLabel => 'Usar SRV';

  @override
  String get authEndpointXmppHostPlaceholder => 'Host XMPP';

  @override
  String get authEndpointXmppLabel => 'XMPP';

  @override
  String get authUnregisterPending => 'Cancelando registro...';

  @override
  String calendarAddTaskError(Object details) {
    return 'No se pudo agregar la tarea: $details';
  }

  @override
  String get calendarBackToCalendar => 'Volver al calendario';

  @override
  String get calendarLoadingMessage => 'Cargando calendario...';

  @override
  String get calendarCriticalPathAddTask => 'Agregar tarea';

  @override
  String get calendarCriticalPathAddToTitle => 'Agregar a ruta crítica';

  @override
  String get calendarCriticalPathCreatePrompt =>
      'Crea una ruta crítica para comenzar';

  @override
  String get calendarCriticalPathDragHint =>
      'Arrastra las tareas para reordenar';

  @override
  String get calendarCriticalPathEmptyTasks =>
      'No hay tareas en esta ruta todavía';

  @override
  String get calendarCriticalPathNameEmptyError => 'Ingresa un nombre';

  @override
  String get calendarCriticalPathNamePlaceholder => 'Nombre de la ruta crítica';

  @override
  String get calendarCriticalPathNamePrompt => 'Nombre';

  @override
  String get calendarCriticalPathTaskOrderTitle => 'Ordenar tareas';

  @override
  String get calendarCriticalPathsAll => 'Todas las rutas';

  @override
  String get calendarCriticalPathsEmpty => 'Aún no hay rutas críticas';

  @override
  String get calendarCriticalPathsNew => 'Nueva ruta crítica';

  @override
  String get calendarCriticalPathRenameTitle => 'Renombrar ruta crítica';

  @override
  String get calendarCriticalPathDeleteTitle => 'Eliminar ruta crítica';

  @override
  String get calendarCriticalPathsTitle => 'Rutas críticas';

  @override
  String get calendarCriticalPathShareAction => 'Compartir en el chat';

  @override
  String get calendarCriticalPathShareTitle => 'Compartir ruta crítica';

  @override
  String get calendarCriticalPathShareSubtitle =>
      'Envía una ruta crítica a un chat.';

  @override
  String get calendarCriticalPathShareTargetLabel => 'Compartir con';

  @override
  String get calendarCriticalPathShareButtonLabel => 'Compartir';

  @override
  String get calendarCriticalPathShareMissingChats =>
      'No hay chats aptos disponibles.';

  @override
  String get calendarCriticalPathShareMissingRecipient =>
      'Selecciona un chat para compartir.';

  @override
  String get calendarCriticalPathShareMissingService =>
      'El uso compartido del calendario no está disponible.';

  @override
  String get calendarCriticalPathShareDenied =>
      'Las tarjetas de calendario están deshabilitadas para tu rol en esta sala.';

  @override
  String get calendarCriticalPathShareFailed =>
      'No se pudo compartir la ruta crítica.';

  @override
  String get calendarCriticalPathShareSuccess => 'Ruta crítica compartida.';

  @override
  String get calendarCriticalPathShareChatTypeDirect => 'Chat directo';

  @override
  String get calendarCriticalPathShareChatTypeGroup => 'Chat grupal';

  @override
  String get calendarCriticalPathShareChatTypeNote => 'Notas';

  @override
  String calendarCriticalPathProgressSummary(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$completed de $total tareas completadas en orden',
      one: '$completed de $total tarea completada en orden',
    );
    return '$_temp0';
  }

  @override
  String get calendarCriticalPathProgressHint =>
      'Completa las tareas en el orden indicado para avanzar.';

  @override
  String get calendarCriticalPathProgressLabel => 'Progreso';

  @override
  String calendarCriticalPathProgressPercent(int percent) {
    return '$percent%';
  }

  @override
  String get calendarCriticalPathFocus => 'Enfocar';

  @override
  String get calendarCriticalPathUnfocus => 'Quitar foco';

  @override
  String get calendarCriticalPathCompletedLabel => 'Completadas';

  @override
  String calendarCriticalPathQueuedAdd(Object name) {
    return 'Se añadirá a \"$name\" al guardar';
  }

  @override
  String calendarCriticalPathQueuedCreate(Object name) {
    return 'Se creó \"$name\" y se puso en cola';
  }

  @override
  String get calendarCriticalPathUnavailable =>
      'Las rutas críticas no están disponibles en esta vista.';

  @override
  String get calendarCriticalPathAddAfterSaveFailed =>
      'La tarea se guardó, pero no se pudo añadir a una ruta crítica.';

  @override
  String calendarCriticalPathAddSuccess(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se añadieron $count tareas a \"$name\".',
      one: 'Añadido a \"$name\".',
    );
    return '$_temp0';
  }

  @override
  String calendarCriticalPathCreateSuccess(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se creó \"$name\" y se añadieron las tareas.',
      one: 'Se creó \"$name\" y se añadió la tarea.',
    );
    return '$_temp0';
  }

  @override
  String calendarCriticalPathAddFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se pudieron añadir las tareas a una ruta crítica.',
      one: 'No se pudo añadir la tarea a una ruta crítica.',
    );
    return '$_temp0';
  }

  @override
  String calendarCriticalPathAlreadyContainsTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Las tareas ya están en esta ruta crítica.',
      one: 'La tarea ya está en esta ruta crítica.',
    );
    return '$_temp0';
  }

  @override
  String get calendarCriticalPathCreateFailed =>
      'No se pudo crear una ruta crítica.';

  @override
  String get calendarTaskSearchTitle => 'Buscar tareas';

  @override
  String calendarTaskSearchAddToTitle(Object name) {
    return 'Añadir a $name';
  }

  @override
  String get calendarTaskSearchSubtitle =>
      'Busca títulos, descripciones, ubicaciones, categorías, prioridades y fechas límite.';

  @override
  String get calendarTaskSearchAddToSubtitle =>
      'Toca una tarea para añadirla al orden de la ruta crítica.';

  @override
  String get calendarTaskSearchHint =>
      'title:, desc:, location:, category:work, priority:urgent, status:done';

  @override
  String get calendarTaskSearchEmptyPrompt =>
      'Empieza a escribir para buscar tareas';

  @override
  String get calendarTaskSearchEmptyNoResults => 'No se encontraron resultados';

  @override
  String get calendarTaskSearchEmptyHint =>
      'Usa filtros como title:, desc:, location:, priority:critical, status:done, deadline:today.';

  @override
  String get calendarTaskSearchFilterScheduled => 'Programadas';

  @override
  String get calendarTaskSearchFilterUnscheduled => 'Sin programar';

  @override
  String get calendarTaskSearchFilterReminders => 'Recordatorios';

  @override
  String get calendarTaskSearchFilterOpen => 'Abiertas';

  @override
  String get calendarTaskSearchFilterCompleted => 'Completadas';

  @override
  String calendarTaskSearchDueDate(Object date) {
    return 'Vence $date';
  }

  @override
  String calendarTaskSearchOverdueDate(Object date) {
    return 'Vencida · $date';
  }

  @override
  String calendarDeleteTaskConfirm(Object title) {
    return '¿Eliminar \"$title\"?';
  }

  @override
  String get calendarErrorTitleEmptyFriendly =>
      'El título no puede estar vacío';

  @override
  String get calendarExportFormatIcsSubtitle =>
      'Úsalo con clientes de calendario';

  @override
  String get calendarExportFormatIcsTitle => 'Exportar .ics';

  @override
  String get calendarExportFormatJsonSubtitle =>
      'Úsalo para copias de seguridad o scripts';

  @override
  String get calendarExportFormatJsonTitle => 'Exportar JSON';

  @override
  String calendarRemovePathConfirm(Object name) {
    return '¿Quitar esta tarea de \"$name\"?';
  }

  @override
  String get calendarSandboxHint =>
      'Planifica tareas aquí antes de asignarlas a una ruta.';

  @override
  String get chatAlertHide => 'Ocultar';

  @override
  String get chatAlertIgnore => 'Ignorar';

  @override
  String get chatAttachmentTapToLoad => 'Toca para cargar';

  @override
  String chatMessageAddRecipientSuccess(Object recipient) {
    return 'Se agregó $recipient';
  }

  @override
  String get chatMessageAddRecipients => 'Agregar destinatarios';

  @override
  String get chatMessageCreateChat => 'Crear chat';

  @override
  String chatMessageCreateChatFailure(Object reason) {
    return 'No se pudo crear el chat: $reason';
  }

  @override
  String get chatMessageInfoDevice => 'Dispositivo';

  @override
  String get chatMessageInfoError => 'Error';

  @override
  String get chatMessageInfoProtocol => 'Protocolo';

  @override
  String get chatMessageInfoTimestamp => 'Marca de tiempo';

  @override
  String get chatMessageOpenChat => 'Abrir chat';

  @override
  String get chatMessageStatusDisplayed => 'Leído';

  @override
  String get chatMessageStatusReceived => 'Recibido';

  @override
  String get chatMessageStatusSent => 'Enviado';

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
  String get avatarOpenError => 'No se pudo abrir ese archivo.';

  @override
  String get avatarReadError => 'No se pudo leer ese archivo.';

  @override
  String get avatarInvalidImageError => 'Ese archivo no es una imagen válida.';

  @override
  String get avatarProcessError => 'No se pudo procesar esa imagen.';

  @override
  String get avatarTemplateLoadError =>
      'No se pudo cargar esa opción de avatar.';

  @override
  String get avatarMissingDraftError => 'Primero elige o crea un avatar.';

  @override
  String get avatarXmppDisconnectedError =>
      'Conéctate a XMPP antes de guardar tu avatar.';

  @override
  String get avatarPublishRejectedError =>
      'Tu servidor rechazó la publicación del avatar.';

  @override
  String get avatarPublishTimeoutError =>
      'La carga del avatar agotó el tiempo. Inténtalo de nuevo.';

  @override
  String get avatarPublishGenericError =>
      'No se pudo publicar el avatar. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get avatarPublishUnexpectedError =>
      'Error inesperado al subir el avatar.';

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
  String get commonDone => 'Listo';

  @override
  String get commonRename => 'Renombrar';

  @override
  String get calendarHour => 'Hora';

  @override
  String get calendarMinute => 'Minuto';

  @override
  String get calendarPasteTaskHere => 'Pegar tarea aquí';

  @override
  String get calendarQuickAddTask => 'Añadir tarea rápida';

  @override
  String get calendarSplitTaskAt => 'Dividir tarea en';

  @override
  String get calendarAddDayEvent => 'Añadir evento del día';

  @override
  String get calendarZoomOut => 'Alejar (Ctrl/Cmd + -)';

  @override
  String get calendarZoomIn => 'Acercar (Ctrl/Cmd + +)';

  @override
  String get calendarChecklistItem => 'Elemento de lista';

  @override
  String get calendarRemoveItem => 'Eliminar elemento';

  @override
  String get calendarAddChecklistItem => 'Añadir elemento a la lista';

  @override
  String get calendarRepeatTimes => 'Repeticiones';

  @override
  String get calendarDayEventHint => 'Cumpleaños, festivo o nota';

  @override
  String get calendarOptionalDetails => 'Detalles opcionales';

  @override
  String get calendarDates => 'Fechas';

  @override
  String get calendarTaskTitleHint => 'Título de la tarea';

  @override
  String get calendarDescriptionOptionalHint => 'Descripción (opcional)';

  @override
  String get calendarLocationOptionalHint => 'Ubicación (opcional)';

  @override
  String get calendarCloseTooltip => 'Cerrar';

  @override
  String get calendarAddTaskInputHint =>
      'Añadir tarea... (ej. \"Reunión mañana a las 3pm\")';

  @override
  String get calendarBranch => 'Rama';

  @override
  String get calendarPickDifferentTask => 'Elegir otra tarea para este espacio';

  @override
  String get calendarSyncRequest => 'Solicitar';

  @override
  String get calendarSyncPush => 'Enviar';

  @override
  String get calendarImportant => 'Importante';

  @override
  String get calendarUrgent => 'Urgente';

  @override
  String get calendarClearSchedule => 'Limpiar horario';

  @override
  String get calendarEditTaskTooltip => 'Editar tarea';

  @override
  String get calendarDeleteTaskTooltip => 'Eliminar tarea';

  @override
  String get calendarBackToChats => 'Volver a chats';

  @override
  String get calendarBackToLogin => 'Volver al inicio de sesión';

  @override
  String get calendarRemindersSection => 'Recordatorios';

  @override
  String get settingsAutoLoadEmailImages =>
      'Cargar imágenes de correo automáticamente';

  @override
  String get settingsAutoLoadEmailImagesDescription =>
      'Puede revelar tu dirección IP a los remitentes';

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
  String get emailContactsImportFileTooLarge =>
      'This file is too large to import.';

  @override
  String get emailContactsImportUnsupportedFile => 'Unsupported file type.';

  @override
  String get emailContactsImportNoContacts => 'No contacts found in that file.';

  @override
  String get emailContactsImportTooManyContacts =>
      'This file contains too many contacts to import.';

  @override
  String get emailContactsImportFailed => 'Import failed.';

  @override
  String emailContactsImportSuccess(
      Object imported, Object duplicates, Object invalid, Object failed) {
    return 'Imported $imported contacts. $duplicates duplicates, $invalid invalid, $failed failed.';
  }

  @override
  String get fanOutErrorNoRecipients => 'Select at least one recipient.';

  @override
  String get fanOutErrorResolveFailed => 'Couldn\'t resolve recipients.';

  @override
  String fanOutErrorTooManyRecipients(int max) {
    return 'Too many recipients (max $max).';
  }

  @override
  String get fanOutErrorEmptyMessage =>
      'Add a message or attachment before sending.';

  @override
  String get fanOutErrorInvalidShareToken => 'Share token is invalid.';

  @override
  String get emailForwardingGuideTitle => 'Conectar correo existente';

  @override
  String get emailForwardingGuideSubtitle =>
      'Reenvía correo desde Gmail, Outlook o cualquier proveedor.';

  @override
  String get emailForwardingWelcomeTitle => 'Bienvenido a Axichat';

  @override
  String get emailForwardingGuideIntro =>
      'Conserva tu bandeja de entrada y reenvía el correo a Axichat.';

  @override
  String get emailForwardingGuideLinkExistingEmailTitle =>
      'Vincular correo existente';

  @override
  String get emailForwardingGuideAddressHint =>
      'Introduce esta dirección en la configuración de reenvío de tu proveedor.';

  @override
  String get emailForwardingGuideAddressFallback =>
      'Aquí aparecerá tu dirección de Axichat.';

  @override
  String get emailForwardingGuideLinksTitle =>
      'Esto debe hacerse en tu cliente de correo existente. Tu proveedor debería tener instrucciones. Si usas Gmail u Outlook, aquí están sus guías:';

  @override
  String get emailForwardingGuideLinksSubtitle =>
      'Busca en la ayuda de tu proveedor o empieza aquí:';

  @override
  String get emailForwardingGuideNotificationsTitle =>
      'Notificaciones de mensajes';

  @override
  String get emailForwardingGuideSettingsHint =>
      'Esto se puede hacer más tarde en los ajustes.';

  @override
  String get emailForwardingGuideSkipLabel => 'Omitir por ahora';

  @override
  String get emailForwardingProviderGmail => 'Gmail';

  @override
  String get emailForwardingProviderOutlook => 'Outlook';

  @override
  String get chatChooseTextToAdd => 'Elegir texto para añadir';

  @override
  String get notificationChannelMessages => 'Mensajes';

  @override
  String get notificationNewMessageTitle => 'Nuevo mensaje';

  @override
  String get notificationOpenAction => 'Abrir notificación';

  @override
  String get notificationAttachmentLabel => 'Attachment';

  @override
  String notificationAttachmentLabelWithName(String filename) {
    return 'Attachment: $filename';
  }

  @override
  String get notificationReactionFallback => 'New reaction';

  @override
  String notificationReactionLabel(String reaction) {
    return 'Reaction: $reaction';
  }

  @override
  String get notificationWebxdcFallback => 'New update';

  @override
  String get shareTokenFooterLabel => 'Please do not remove:';

  @override
  String get notificationBackgroundConnectionDisabledTitle =>
      'Conexión en segundo plano desactivada';

  @override
  String get notificationBackgroundConnectionDisabledBody =>
      'Android bloqueó el servicio de mensajes de Axichat. Vuelve a habilitar los permisos de superposición y optimización de batería para restaurar la mensajería en segundo plano.';

  @override
  String get calendarReminderDeadlineNow => 'Vence ahora';

  @override
  String calendarReminderDueIn(Object duration) {
    return 'Vence en $duration';
  }

  @override
  String get calendarReminderStartingNow => 'Empieza ahora';

  @override
  String calendarReminderStartsIn(Object duration) {
    return 'Empieza en $duration';
  }

  @override
  String get calendarReminderHappeningToday => 'Sucede hoy';

  @override
  String calendarReminderIn(Object duration) {
    return 'En $duration';
  }

  @override
  String calendarReminderDurationDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# días',
      one: '# día',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderDurationHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# horas',
      one: '# hora',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderDurationMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# minutos',
      one: '# minuto',
    );
    return '$_temp0';
  }

  @override
  String get calendarExportCalendar => 'Exportar calendario';

  @override
  String get calendarImportCalendar => 'Importar calendario';

  @override
  String get calendarSyncStatusSyncing => 'Sincronizando...';

  @override
  String get calendarSyncStatusFailed => 'Sincronización fallida';

  @override
  String get calendarSyncStatusSynced => 'Sincronizado';

  @override
  String get calendarSyncStatusIdle => 'Aún no sincronizado';

  @override
  String calendarSplitTaskAtTime(Object time) {
    return 'Dividir tarea a las $time';
  }

  @override
  String get calendarSplitSelectTime => 'Seleccionar hora de división';

  @override
  String get calendarTaskMarkIncomplete => 'Marcar como incompleta';

  @override
  String get calendarTaskMarkComplete => 'Marcar como completa';

  @override
  String get calendarTaskRemoveImportant => 'Quitar marca importante';

  @override
  String get calendarTaskMarkImportant => 'Marcar como importante';

  @override
  String get calendarTaskRemoveUrgent => 'Quitar marca urgente';

  @override
  String get calendarTaskMarkUrgent => 'Marcar como urgente';

  @override
  String get calendarDeselectTask => 'Deseleccionar tarea';

  @override
  String get calendarAddTaskToSelection => 'Añadir tarea a la selección';

  @override
  String get calendarSelectTask => 'Seleccionar tarea';

  @override
  String get calendarDeselectAllRepeats =>
      'Deseleccionar todas las repeticiones';

  @override
  String get calendarAddAllRepeats => 'Añadir todas las repeticiones';

  @override
  String get calendarSelectAllRepeats => 'Seleccionar todas las repeticiones';

  @override
  String get calendarAddToSelection => 'Añadir a la selección';

  @override
  String get calendarSelectAllTasks => 'Seleccionar todas las tareas';

  @override
  String get calendarExitSelectionMode => 'Salir del modo de selección';

  @override
  String get calendarSplitTask => 'Dividir tarea';

  @override
  String get calendarCopyTemplate => 'Copiar plantilla';

  @override
  String calendarTaskAddedMessage(Object title) {
    return 'Tarea \"$title\" añadida';
  }

  @override
  String calendarTasksAddedMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# tareas añadidas',
      one: '# tarea añadida',
    );
    return '$_temp0';
  }

  @override
  String calendarTaskRemovedMessage(Object title) {
    return 'Tarea \"$title\" eliminada';
  }

  @override
  String calendarTasksRemovedMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# tareas eliminadas',
      one: '# tarea eliminada',
    );
    return '$_temp0';
  }

  @override
  String get calendarTaskRemovedTitle => 'Tarea eliminada';

  @override
  String get calendarDeadlinePlaceholder =>
      'Establecer fecha límite (opcional)';

  @override
  String get calendarTaskDescriptionHint => 'Descripción (opcional)';

  @override
  String get calendarTaskLocationHint => 'Ubicación (opcional)';

  @override
  String get calendarPickDateLabel => 'Elegir fecha';

  @override
  String get calendarPickTimeLabel => 'Elegir hora';

  @override
  String get calendarReminderLabel => 'Recordatorio';

  @override
  String get calendarEditDayEventTitle => 'Editar evento del día';

  @override
  String get calendarNewDayEventTitle => 'Nuevo evento del día';

  @override
  String get commonAdd => 'Añadir';

  @override
  String get commonTitle => 'Título';

  @override
  String get calendarShareUnavailable =>
      'El uso compartido del calendario no está disponible.';

  @override
  String get calendarShareAvailability => 'Compartir disponibilidad';

  @override
  String get calendarShortcutUndo => 'Ctrl/Cmd+Z';

  @override
  String get calendarShortcutRedo => 'Ctrl/Cmd+Shift+Z';

  @override
  String commonShortcutTooltip(Object tooltip, Object shortcut) {
    return '$tooltip ($shortcut)';
  }

  @override
  String get calendarDragCanceled => 'Arrastre cancelado';

  @override
  String get calendarZoomLabelCompact => 'Compacto';

  @override
  String get calendarZoomLabelComfort => 'Cómodo';

  @override
  String get calendarZoomLabelExpanded => 'Expandido';

  @override
  String calendarZoomLabelMinutes(Object minutes) {
    return '${minutes}m';
  }

  @override
  String get calendarGuestModeNotice =>
      'Modo invitado: las tareas se guardan solo en este dispositivo';

  @override
  String get calendarGuestSignUpToSync => 'Regístrate para sincronizar';

  @override
  String get calendarGuestExportNoData =>
      'No hay datos del calendario para exportar.';

  @override
  String get calendarGuestExportTitle => 'Exportar calendario de invitado';

  @override
  String get calendarGuestExportShareSubject =>
      'Exportación del calendario de invitado de Axichat';

  @override
  String calendarGuestExportShareText(Object format) {
    return 'Exportación del calendario de invitado de Axichat ($format)';
  }

  @override
  String calendarGuestExportFailed(Object error) {
    return 'Error al exportar el calendario: $error';
  }

  @override
  String get calendarGuestImportTitle => 'Importar calendario';

  @override
  String get calendarGuestImportWarningMessage =>
      'La importación combinará datos y sobrescribirá los elementos coincidentes en tu calendario actual. ¿Continuar?';

  @override
  String get calendarGuestImportConfirmLabel => 'Importar';

  @override
  String get calendarGuestImportFileAccessError =>
      'No se puede acceder al archivo seleccionado.';

  @override
  String get calendarGuestImportNoData =>
      'No se detectaron datos de calendario en el archivo seleccionado.';

  @override
  String get calendarGuestImportFailed =>
      'La importación no pudo aplicar los cambios.';

  @override
  String get calendarGuestImportSuccess => 'Datos del calendario importados.';

  @override
  String get calendarGuestImportNoTasks =>
      'No se detectaron tareas en el archivo seleccionado.';

  @override
  String calendarGuestImportTasksSuccess(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# tareas',
      one: '# tarea',
    );
    return 'Se importaron $_temp0.';
  }

  @override
  String calendarGuestImportError(Object error) {
    return 'Falló la importación: $error';
  }

  @override
  String get blocklistEmpty => 'Nadie bloqueado';

  @override
  String get chatMessageSubjectLabel => 'Asunto';

  @override
  String get chatMessageRecipientsLabel => 'Destinatarios';

  @override
  String get chatMessageAlsoSentToLabel => 'También enviado a';

  @override
  String chatMessageFromLabel(Object sender) {
    return 'De $sender';
  }

  @override
  String get chatMessageReactionsLabel => 'Reacciones';

  @override
  String get commonClearSelection => 'Borrar selección';

  @override
  String commonSelectedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# seleccionados',
      one: '# seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get profileDeviceFingerprint => 'Huella del dispositivo';

  @override
  String get profileFingerprintUnavailable => 'Huella no disponible';

  @override
  String get axiVersionCurrentFeatures => 'Funciones actuales:';

  @override
  String get axiVersionCurrentFeaturesList => 'Mensajería, presencia';

  @override
  String get axiVersionComingNext => 'Próximamente:';

  @override
  String get axiVersionComingNextList => 'Chat grupal, multimedia';

  @override
  String get commonMoreOptions => 'Más opciones';

  @override
  String get commonAreYouSure => '¿Estás seguro?';

  @override
  String get commonAll => 'Todos';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageGerman => 'Alemán';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageFrench => 'Francés';

  @override
  String get languageChineseSimplified => 'Chino simplificado';

  @override
  String get languageChineseHongKong => 'Chino (Hong Kong)';

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
      'No hay datos de calendario disponibles para exportar.';

  @override
  String get calendarTransferExportSubject =>
      'Exportación de calendario de Axichat';

  @override
  String calendarTransferExportText(String format) {
    return 'Exportación de calendario de Axichat ($format)';
  }

  @override
  String get calendarTransferExportReady => 'Exportación lista para compartir.';

  @override
  String calendarTransferExportFailed(String error) {
    return 'Error al exportar el calendario: $error';
  }

  @override
  String get calendarTransferImportWarning =>
      'La importación fusionará los datos y sobrescribirá los elementos coincidentes en tu calendario actual. ¿Continuar?';

  @override
  String get calendarTransferImportConfirm => 'Importar';

  @override
  String get calendarTransferFileAccessFailed =>
      'No se puede acceder al archivo seleccionado.';

  @override
  String get calendarTransferNoDataImport =>
      'No se detectaron datos de calendario en el archivo seleccionado.';

  @override
  String get calendarTransferImportFailed =>
      'No se pudieron aplicar los cambios de la importación.';

  @override
  String get calendarTransferImportSuccess => 'Datos de calendario importados.';

  @override
  String get calendarTransferNoTasksDetected =>
      'No se detectaron tareas en el archivo seleccionado.';

  @override
  String calendarTransferImportTasksSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Se importó $count tarea$_temp0.';
  }

  @override
  String calendarTransferImportFailedWithError(String error) {
    return 'Falló la importación: $error';
  }

  @override
  String get calendarExportChooseFormat => 'Elegir formato de exportación';

  @override
  String get calendarAvailabilityWindowsTitle => 'Ventanas de disponibilidad';

  @override
  String get calendarAvailabilityWindowsSubtitle =>
      'Define los rangos de tiempo que quieres compartir.';

  @override
  String get calendarAvailabilityWindowsLabel => 'Ventanas';

  @override
  String get calendarAvailabilityNoWindows => 'Aún no hay ventanas.';

  @override
  String get calendarAvailabilityWindowLabel => 'Ventana';

  @override
  String get calendarAvailabilitySummaryLabel => 'Resumen';

  @override
  String get calendarAvailabilitySummaryHint => 'Etiqueta opcional';

  @override
  String get calendarAvailabilityNotesLabel => 'Notas';

  @override
  String get calendarAvailabilityNotesHint => 'Detalles opcionales';

  @override
  String get calendarAvailabilityAddWindow => 'Añadir ventana';

  @override
  String get calendarAvailabilitySaveWindows => 'Guardar ventanas';

  @override
  String get calendarAvailabilityEmptyWindowsError =>
      'Añade al menos una ventana de disponibilidad.';

  @override
  String get calendarAvailabilityInvalidRangeError =>
      'Revisa los rangos de las ventanas antes de guardar.';

  @override
  String get calendarTaskShareTitle => 'Compartir tarea';

  @override
  String get calendarTaskShareSubtitle =>
      'Envía una tarea a un chat como .ics.';

  @override
  String get calendarTaskShareTarget => 'Compartir con';

  @override
  String get calendarTaskShareEditAccess => 'Acceso de edición';

  @override
  String get calendarTaskShareReadOnlyLabel => 'Solo lectura';

  @override
  String get calendarTaskShareEditableLabel => 'Editable';

  @override
  String get calendarTaskShareReadOnlyHint =>
      'Los destinatarios pueden ver esta tarea, pero solo tú puedes editarla.';

  @override
  String get calendarTaskShareEditableHint =>
      'Los destinatarios pueden editar esta tarea y las actualizaciones se sincronizan con tu calendario.';

  @override
  String get calendarTaskShareReadOnlyDisabledHint =>
      'La edición solo está disponible para calendarios de chat.';

  @override
  String get calendarTaskShareMissingChats => 'No hay chats disponibles.';

  @override
  String get calendarTaskShareMissingRecipient =>
      'Selecciona un chat para compartir.';

  @override
  String get calendarTaskShareServiceUnavailable =>
      'El uso compartido del calendario no está disponible.';

  @override
  String get calendarTaskShareDenied =>
      'Las tarjetas de calendario están deshabilitadas para tu rol en esta sala.';

  @override
  String get calendarTaskShareSendFailed => 'No se pudo compartir la tarea.';

  @override
  String get calendarTaskShareSuccess => 'Tarea compartida.';

  @override
  String get commonTimeJustNow => 'Justo ahora';

  @override
  String commonTimeMinutesAgo(int count) {
    return 'Hace $count min';
  }

  @override
  String commonTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Hace $count hora$_temp0';
  }

  @override
  String commonTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Hace $count día$_temp0';
  }

  @override
  String commonTimeWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Hace $count semana$_temp0';
  }

  @override
  String get commonTimeMonthsAgo => 'Hace meses';

  @override
  String get connectivityStatusConnected => 'Conectado';

  @override
  String get connectivityStatusConnecting => 'Conectando...';

  @override
  String get connectivityStatusNotConnected => 'No conectado.';

  @override
  String get connectivityStatusFailed => 'Error al conectar.';

  @override
  String get commonShare => 'Compartir';

  @override
  String get commonRecipients => 'Destinatarios';

  @override
  String commonRangeLabel(String start, String end) {
    return '$start - $end';
  }

  @override
  String get commonOwnerFallback => 'propietario';

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
    return '$count hora$_temp0';
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
  String get calendarAvailabilityShareTitle => 'Compartir disponibilidad';

  @override
  String get calendarAvailabilityShareSubtitle =>
      'Elige un rango, edita libre/ocupado y luego comparte.';

  @override
  String get calendarAvailabilityShareChatSubtitle =>
      'Elige un rango, edita libre/ocupado y luego comparte en este chat.';

  @override
  String get calendarAvailabilityShareRangeLabel => 'Rango';

  @override
  String get calendarAvailabilityShareEditHint =>
      'Toca para dividir, arrastra para cambiar el tamaño o alterna libre/ocupado.';

  @override
  String get calendarAvailabilityShareSavePreset => 'Guardar como preset';

  @override
  String get calendarAvailabilitySharePresetNameTitle =>
      'Guardar hoja libre/ocupado';

  @override
  String get calendarAvailabilitySharePresetNameLabel => 'Nombre';

  @override
  String get calendarAvailabilitySharePresetNameHint => 'Horario del equipo';

  @override
  String get calendarAvailabilitySharePresetNameMissing =>
      'Ingresa un nombre para guardar esta hoja.';

  @override
  String get calendarAvailabilityShareInvalidRange =>
      'Selecciona un rango válido para compartir.';

  @override
  String get calendarAvailabilityShareMissingJid =>
      'El uso compartido del calendario no está disponible.';

  @override
  String get calendarAvailabilityShareRecipientsRequired =>
      'Selecciona al menos un destinatario.';

  @override
  String get calendarAvailabilityShareMissingChats =>
      'No hay chats elegibles disponibles.';

  @override
  String get calendarAvailabilityShareLockedChatUnavailable =>
      'Este chat no puede recibir disponibilidades.';

  @override
  String get calendarAvailabilityShareSuccess => 'Disponibilidad compartida.';

  @override
  String get calendarAvailabilityShareFailed =>
      'No se pudo compartir la disponibilidad.';

  @override
  String get calendarAvailabilitySharePartialFailure =>
      'Algunos envíos no se pudieron enviar.';

  @override
  String get calendarAvailabilitySharePresetLabel => 'Hojas recientes';

  @override
  String get calendarAvailabilitySharePresetEmpty =>
      'Aún no hay hojas recientes.';

  @override
  String calendarAvailabilityShareRecentPreset(String range) {
    return 'Compartido $range';
  }

  @override
  String get calendarAvailabilityPreviewEmpty =>
      'No hay intervalos de disponibilidad.';

  @override
  String calendarAvailabilityPreviewMore(int count) {
    return 'y $count más';
  }

  @override
  String get calendarTaskTitleRequired =>
      'Ingresa un título de tarea antes de continuar.';

  @override
  String calendarTaskTitleTooLong(int max) {
    return 'El título de la tarea es demasiado largo. Usa menos de $max caracteres.';
  }

  @override
  String calendarTaskTitleLimitWarning(int max) {
    return 'Los títulos de tareas están limitados a $max caracteres. Acorta este texto o mueve los detalles a la descripción antes de guardar.';
  }

  @override
  String calendarTaskTitleCharacterCount(int count, int limit) {
    return '$count / $limit caracteres';
  }

  @override
  String get axiVersionWelcomeTitle => 'Bienvenido a Axichat';

  @override
  String axiVersionLabel(String version) {
    return 'v$version';
  }

  @override
  String get axiVersionTagAlpha => 'alpha';

  @override
  String get calendarSyncWarningSnapshotTitle => 'Sincronizacion de calendario';

  @override
  String get calendarSyncWarningSnapshotMessage =>
      'Instantanea del calendario no disponible. Exporta el JSON del calendario desde otro dispositivo e importalo aqui para restaurar.';

  @override
  String commonLabelValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String get calendarAvailabilityRequestTitle => 'Solicitar hora';

  @override
  String get calendarAvailabilityRequestSubtitle =>
      'Elige un espacio libre y comparte detalles.';

  @override
  String get calendarAvailabilityRequestDetailsLabel => 'Detalles';

  @override
  String get calendarAvailabilityRequestRangeLabel => 'Rango';

  @override
  String get calendarAvailabilityRequestTitleLabel => 'Título';

  @override
  String get calendarAvailabilityRequestTitlePlaceholder =>
      '¿Para qué es esto?';

  @override
  String get calendarAvailabilityRequestDescriptionLabel => 'Descripción';

  @override
  String get calendarAvailabilityRequestDescriptionPlaceholder =>
      'Agregar contexto (opcional).';

  @override
  String get calendarAvailabilityRequestSendLabel => 'Enviar solicitud';

  @override
  String get calendarAvailabilityRequestInvalidRange =>
      'Elige un rango de tiempo válido.';

  @override
  String get calendarAvailabilityRequestNotFree =>
      'Selecciona un espacio libre antes de enviar.';

  @override
  String get calendarAvailabilityDecisionTitle => 'Aceptar solicitud';

  @override
  String get calendarAvailabilityDecisionSubtitle =>
      'Elige qué calendarios deben recibirlo.';

  @override
  String get calendarAvailabilityDecisionPersonalLabel =>
      'Agregar al calendario personal';

  @override
  String get calendarAvailabilityDecisionChatLabel =>
      'Agregar al calendario del chat';

  @override
  String get calendarAvailabilityDecisionMissingSelection =>
      'Selecciona al menos un calendario.';

  @override
  String get calendarAvailabilityDecisionSummaryLabel => 'Solicitado';

  @override
  String get calendarAvailabilityRequestTitleFallback => 'Hora solicitada';

  @override
  String get calendarAvailabilityShareFallback => 'Disponibilidad compartida';

  @override
  String get calendarAvailabilityRequestFallback =>
      'Solicitud de disponibilidad';

  @override
  String get calendarAvailabilityResponseAcceptedFallback =>
      'Disponibilidad aceptada';

  @override
  String get calendarAvailabilityResponseDeclinedFallback =>
      'Disponibilidad rechazada';

  @override
  String get calendarFreeBusyFree => 'Libre';

  @override
  String get calendarFreeBusyBusy => 'Ocupado';

  @override
  String get calendarFreeBusyTentative => 'Tentativo';

  @override
  String get calendarFreeBusyEditTitle => 'Editar disponibilidad';

  @override
  String get calendarFreeBusyEditSubtitle =>
      'Ajusta el rango de tiempo y el estado.';

  @override
  String get calendarFreeBusyToggleLabel => 'Libre/Ocupado';

  @override
  String get calendarFreeBusySplitLabel => 'Dividir';

  @override
  String get calendarFreeBusySplitTooltip => 'Dividir segmento';

  @override
  String get calendarFreeBusyMarkFree => 'Marcar como libre';

  @override
  String get calendarFreeBusyMarkBusy => 'Marcar como ocupado';

  @override
  String get calendarFreeBusyRangeLabel => 'Rango';

  @override
  String commonWeekdayDayLabel(String weekday, int day) {
    return '$weekday $day';
  }

  @override
  String get calendarFragmentChecklistLabel => 'Lista de verificacion';

  @override
  String get calendarFragmentChecklistSeparator => ', ';

  @override
  String calendarFragmentChecklistSummary(String summary) {
    return 'Lista de verificacion: $summary';
  }

  @override
  String calendarFragmentChecklistSummaryMore(String summary, int count) {
    return 'Lista de verificacion: $summary y $count mas';
  }

  @override
  String get calendarFragmentRemindersLabel => 'Recordatorios';

  @override
  String calendarFragmentReminderStartSummary(String summary) {
    return 'Inicio: $summary';
  }

  @override
  String calendarFragmentReminderDeadlineSummary(String summary) {
    return 'Fecha limite: $summary';
  }

  @override
  String calendarFragmentRemindersSummary(String summary) {
    return 'Recordatorios: $summary';
  }

  @override
  String get calendarFragmentReminderSeparator => ', ';

  @override
  String get calendarFragmentEventTitleFallback => 'Evento sin titulo';

  @override
  String calendarFragmentDayEventSummary(String title, String range) {
    return '$title (Evento de dia: $range)';
  }

  @override
  String calendarFragmentFreeBusySummary(String label, String range) {
    return '$label (Ventana: $range)';
  }

  @override
  String get calendarFragmentCriticalPathLabel => 'Ruta critica';

  @override
  String calendarFragmentCriticalPathSummary(String name) {
    return 'Ruta critica: $name';
  }

  @override
  String calendarFragmentCriticalPathProgress(int completed, int total) {
    return '$completed/$total hecho';
  }

  @override
  String calendarFragmentCriticalPathDetail(String name, String progress) {
    return '$name (Ruta critica: $progress)';
  }

  @override
  String calendarFragmentAvailabilitySummary(String summary, String range) {
    return '$summary (Disponibilidad: $range)';
  }

  @override
  String calendarFragmentAvailabilityFallback(String range) {
    return 'Disponibilidad: $range';
  }

  @override
  String calendarMonthOverflowMore(int count) {
    return '+$count mas';
  }

  @override
  String commonPercentLabel(int value) {
    return '$value%';
  }

  @override
  String get commonStart => 'Inicio';

  @override
  String get commonEnd => 'Fin';

  @override
  String get commonSelectStart => 'Seleccionar inicio';

  @override
  String get commonSelectEnd => 'Seleccionar fin';

  @override
  String get commonTimeLabel => 'Hora';

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
    return '$head y $tail';
  }

  @override
  String get calendarAlarmsTitle => 'Alarmas';

  @override
  String get calendarAlarmsHelper =>
      'Los recordatorios se exportan como alarmas de visualización.';

  @override
  String get calendarAlarmsEmpty => 'Aún no hay alarmas';

  @override
  String get calendarAlarmAddTooltip => 'Agregar alarma';

  @override
  String get calendarAlarmRemoveTooltip => 'Eliminar alarma';

  @override
  String calendarAlarmItemLabel(int index) {
    return 'Alarma $index';
  }

  @override
  String get calendarAlarmActionLabel => 'Acción';

  @override
  String get calendarAlarmActionDisplay => 'Mostrar';

  @override
  String get calendarAlarmActionAudio => 'Audio';

  @override
  String get calendarAlarmActionEmail => 'Correo';

  @override
  String get calendarAlarmActionProcedure => 'Procedimiento';

  @override
  String get calendarAlarmActionProcedureHelper =>
      'Las alarmas de procedimiento se importan en modo solo lectura.';

  @override
  String get calendarAlarmTriggerLabel => 'Disparador';

  @override
  String get calendarAlarmTriggerRelative => 'Relativo';

  @override
  String get calendarAlarmTriggerAbsolute => 'Absoluto';

  @override
  String get calendarAlarmAbsolutePlaceholder => 'Seleccionar fecha y hora';

  @override
  String get calendarAlarmRelativeToLabel => 'Relativo a';

  @override
  String get calendarAlarmRelativeToStart => 'Inicio';

  @override
  String get calendarAlarmRelativeToEnd => 'Fin';

  @override
  String get calendarAlarmDirectionLabel => 'Dirección';

  @override
  String get calendarAlarmDirectionBefore => 'Antes';

  @override
  String get calendarAlarmDirectionAfter => 'Después';

  @override
  String get calendarAlarmOffsetLabel => 'Desfase';

  @override
  String get calendarAlarmOffsetHint => 'Cantidad';

  @override
  String get calendarAlarmRepeatLabel => 'Repetir';

  @override
  String get calendarAlarmRepeatCountHint => 'Veces';

  @override
  String get calendarAlarmRepeatEveryLabel => 'Cada';

  @override
  String get calendarAlarmRecipientsLabel => 'Destinatarios';

  @override
  String get calendarAlarmRecipientAddressHint => 'Agregar correo';

  @override
  String get calendarAlarmRecipientNameHint => 'Nombre (opcional)';

  @override
  String get calendarAlarmRecipientRemoveTooltip => 'Eliminar destinatario';

  @override
  String calendarAlarmRecipientDisplay(String name, String address) {
    return '$name <$address>';
  }

  @override
  String get calendarAlarmAcknowledgedLabel => 'Confirmado';

  @override
  String get calendarAlarmUnitMinutes => 'Minutos';

  @override
  String get calendarAlarmUnitHours => 'Horas';

  @override
  String get calendarAlarmUnitDays => 'Días';

  @override
  String get calendarAlarmUnitWeeks => 'Semanas';

  @override
  String get taskShareTitleFallback => 'Tarea sin título';

  @override
  String taskShareTitleLabel(String title) {
    return 'Tarea \"$title\"';
  }

  @override
  String taskShareTitleWithQualifiers(String title, String qualifiers) {
    return 'Tarea \"$title\" ($qualifiers)';
  }

  @override
  String get taskShareQualifierDone => 'hecho';

  @override
  String get taskSharePriorityImportant => 'importante';

  @override
  String get taskSharePriorityUrgent => 'urgente';

  @override
  String get taskSharePriorityCritical => 'crítica';

  @override
  String taskShareLocationClause(String location) {
    return ' en $location';
  }

  @override
  String get taskShareScheduleNoTime => ' sin hora establecida';

  @override
  String taskShareScheduleSameDay(
      String date, String startTime, String endTime) {
    return ' el $date de $startTime a $endTime';
  }

  @override
  String taskShareScheduleRange(String startDateTime, String endDateTime) {
    return ' desde $startDateTime hasta $endDateTime';
  }

  @override
  String taskShareScheduleStartDuration(
      String date, String time, String duration) {
    return ' el $date a las $time durante $duration';
  }

  @override
  String taskShareScheduleStart(String date, String time) {
    return ' el $date a las $time';
  }

  @override
  String taskShareScheduleEnding(String dateTime) {
    return ' termina $dateTime';
  }

  @override
  String get taskShareRecurrenceEveryOtherDay => ' día por medio';

  @override
  String taskShareRecurrenceEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: 'día',
    );
    return ' cada $_temp0';
  }

  @override
  String taskShareRecurrenceEveryWeekdays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días laborables',
      one: 'día laborable',
    );
    return ' cada $_temp0';
  }

  @override
  String taskShareRecurrenceEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semanas',
      one: 'semana',
    );
    return ' cada $_temp0';
  }

  @override
  String taskShareRecurrenceEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meses',
      one: 'mes',
    );
    return ' cada $_temp0';
  }

  @override
  String get taskShareRecurrenceEveryOtherYear => ' cada dos años';

  @override
  String taskShareRecurrenceEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count años',
      one: 'año',
    );
    return ' cada $_temp0';
  }

  @override
  String taskShareRecurrenceOnDays(String days) {
    return ' en $days';
  }

  @override
  String taskShareRecurrenceUntil(String date) {
    return ' hasta $date';
  }

  @override
  String taskShareRecurrenceCount(int count) {
    return ' por $count ocurrencias';
  }

  @override
  String taskShareDeadlineClause(String dateTime) {
    return ', vence el $dateTime';
  }

  @override
  String taskShareNotesClause(String notes) {
    return ' Notas: $notes.';
  }

  @override
  String taskShareChangesClause(String changes) {
    return ' Cambios: $changes';
  }

  @override
  String taskShareOverrideMoveTo(String dateTime) {
    return 'mover a $dateTime';
  }

  @override
  String taskShareOverrideDuration(String duration) {
    return 'durante $duration';
  }

  @override
  String taskShareOverrideEndAt(String dateTime) {
    return 'termina a las $dateTime';
  }

  @override
  String taskShareOverridePriority(String priority) {
    return 'prioridad $priority';
  }

  @override
  String get taskShareOverrideCancelled => 'cancelada';

  @override
  String get taskShareOverrideDone => 'hecho';

  @override
  String taskShareOverrideRenameTo(String title) {
    return 'renombrar a \"$title\"';
  }

  @override
  String taskShareOverrideNotes(String notes) {
    return 'notas \"$notes\"';
  }

  @override
  String taskShareOverrideLocation(String location) {
    return 'ubicación \"$location\"';
  }

  @override
  String get taskShareOverrideNoChanges => 'sin cambios';

  @override
  String taskShareOverrideSegment(String dateTime, String actions) {
    return 'El $dateTime: $actions';
  }

  @override
  String get calendarTaskCopiedToClipboard => 'Tarea copiada al portapapeles';

  @override
  String get calendarTaskSplitRequiresSchedule =>
      'La tarea debe estar programada para dividirla.';

  @override
  String get calendarTaskSplitTooShort =>
      'La tarea es demasiado corta para dividirla.';

  @override
  String get calendarTaskSplitUnable =>
      'No se puede dividir la tarea en ese momento.';

  @override
  String get calendarDayEventsLabel => 'Eventos del dia';

  @override
  String get calendarShareAsIcsAction => 'Compartir como .ics';

  @override
  String get calendarCompletedLabel => 'Completado';

  @override
  String get calendarDeadlineDueToday => 'Vence hoy';

  @override
  String get calendarDeadlineDueTomorrow => 'Vence manana';

  @override
  String get calendarExportTasksFilePrefix => 'axichat_tareas';

  @override
  String get chatTaskViewTitle => 'Detalles de la tarea';

  @override
  String get chatTaskViewSubtitle => 'Tarea de solo lectura.';

  @override
  String get chatTaskViewPreviewLabel => 'Vista previa';

  @override
  String get chatTaskViewActionsLabel => 'Acciones de la tarea';

  @override
  String get chatTaskViewCopyLabel => 'Copiar al calendario';

  @override
  String get chatTaskCopyTitle => 'Copiar tarea';

  @override
  String get chatTaskCopySubtitle => 'Elige a que calendarios se debe enviar.';

  @override
  String get chatTaskCopyPreviewLabel => 'Vista previa';

  @override
  String get chatTaskCopyCalendarsLabel => 'Calendarios';

  @override
  String get chatTaskCopyPersonalLabel => 'Agregar al calendario personal';

  @override
  String get chatTaskCopyChatLabel => 'Agregar al calendario del chat';

  @override
  String get chatTaskCopyConfirmLabel => 'Copiar';

  @override
  String get chatTaskCopyMissingSelectionMessage =>
      'Selecciona al menos un calendario.';

  @override
  String get chatCriticalPathCopyTitle => 'Copiar ruta critica';

  @override
  String get chatCriticalPathCopySubtitle =>
      'Elige a que calendarios se debe enviar.';

  @override
  String get chatCriticalPathCopyPreviewLabel => 'Vista previa';

  @override
  String get chatCriticalPathCopyCalendarsLabel => 'Calendarios';

  @override
  String get chatCriticalPathCopyPersonalLabel =>
      'Agregar al calendario personal';

  @override
  String get chatCriticalPathCopyChatLabel => 'Agregar al calendario del chat';

  @override
  String get chatCriticalPathCopyConfirmLabel => 'Copiar';

  @override
  String get chatCriticalPathCopyMissingSelectionMessage =>
      'Selecciona al menos un calendario.';

  @override
  String get chatCriticalPathCopyUnavailableMessage =>
      'El calendario no esta disponible.';

  @override
  String get chatCriticalPathCopySuccessMessage => 'Ruta critica copiada.';

  @override
  String commonBulletLabel(String text) {
    return '• $text';
  }

  @override
  String get chatFilterTitle => 'Mensajes mostrados';

  @override
  String get chatFilterDirectOnlyLabel => 'Solo directos';

  @override
  String get chatFilterAllLabel => 'Todos';

  @override
  String get calendarFragmentTaskLabel => 'Tarea';

  @override
  String get calendarFragmentDayEventLabel => 'Evento de dia';

  @override
  String get calendarFragmentFreeBusyLabel => 'Libre/ocupado';

  @override
  String get calendarFragmentAvailabilityLabel => 'Disponibilidad';

  @override
  String get calendarFragmentScheduledLabel => 'Programado';

  @override
  String get calendarFragmentDueLabel => 'Vence';

  @override
  String get calendarFragmentUntitledLabel => 'Sin titulo';

  @override
  String get calendarFragmentChecklistBullet => '- ';

  @override
  String commonAndMoreLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'y $count mas',
      one: 'y 1 mas',
    );
    return '$_temp0';
  }

  @override
  String get commonBulletSymbol => '• ';

  @override
  String get commonLabelSeparator => ': ';

  @override
  String get commonUnknownLabel => 'Desconocido';

  @override
  String get commonBadgeOverflowLabel => '99+';

  @override
  String get commonEllipsis => '…';

  @override
  String get chatMessageDetailsSenderLabel => 'Direccion del remitente';

  @override
  String get chatMessageDetailsMetadataLabel => 'Metadatos del mensaje';

  @override
  String get chatMessageDetailsHeadersLabel => 'Encabezados sin formato';

  @override
  String get chatMessageDetailsHeadersActionLabel => 'Ver encabezados';

  @override
  String get chatMessageDetailsHeadersNote =>
      'Los encabezados se cargan del mensaje RFC822 original.';

  @override
  String get chatMessageDetailsHeadersLoadingLabel => 'Cargando encabezados...';

  @override
  String get chatMessageDetailsHeadersUnavailableLabel =>
      'Encabezados no disponibles.';

  @override
  String get chatMessageDetailsStanzaIdLabel => 'ID de stanza';

  @override
  String get chatMessageDetailsOriginIdLabel => 'ID de origen';

  @override
  String get chatMessageDetailsOccupantIdLabel => 'ID de ocupante';

  @override
  String get chatMessageDetailsDeltaIdLabel => 'ID de mensaje Delta';

  @override
  String get chatMessageDetailsLocalIdLabel => 'ID de mensaje local';

  @override
  String get chatCalendarFragmentShareDeniedMessage =>
      'Las tarjetas de calendario estan deshabilitadas para tu rol en esta sala.';

  @override
  String get chatAvailabilityRequestAccountMissingMessage =>
      'Las solicitudes de disponibilidad no estan disponibles ahora.';

  @override
  String get chatAvailabilityRequestEmailUnsupportedMessage =>
      'La disponibilidad no esta disponible para chats de correo.';

  @override
  String get chatAvailabilityRequestInvalidRangeMessage =>
      'La hora solicitada de disponibilidad no es valida.';

  @override
  String get chatAvailabilityRequestCalendarUnavailableMessage =>
      'El calendario no esta disponible.';

  @override
  String get chatAvailabilityRequestChatCalendarUnavailableMessage =>
      'El calendario del chat no esta disponible.';

  @override
  String get chatAvailabilityRequestTaskTitleFallback => 'Tiempo solicitado';

  @override
  String get chatSenderAddressPrefix => 'JID: ';

  @override
  String get chatRecipientVisibilityCcLabel => 'CC';

  @override
  String get chatRecipientVisibilityBccLabel => 'BCC';

  @override
  String get chatInviteRoomFallbackLabel => 'chat grupal';

  @override
  String get chatInviteBodyLabel => 'Has sido invitado a un chat grupal';

  @override
  String get chatInviteRevokedLabel => 'Invitacion revocada';

  @override
  String chatInviteActionLabel(String roomName) {
    return 'Unirse a \'$roomName\'';
  }

  @override
  String get chatInviteActionFallbackLabel => 'Unirse';

  @override
  String get chatInviteConfirmTitle => 'Aceptar invitacion?';

  @override
  String chatInviteConfirmMessage(String roomName) {
    return 'Unirse a \'$roomName\'?';
  }

  @override
  String get chatInviteConfirmLabel => 'Aceptar';

  @override
  String get chatChooseTextToAddHint =>
      'Selecciona una parte del mensaje para enviarla al calendario o editala primero.';

  @override
  String get chatAttachmentAutoDownloadLabel =>
      'Descargar automaticamente los adjuntos en este chat';

  @override
  String get chatAttachmentAutoDownloadHintOn =>
      'Los adjuntos de este chat se descargaran automaticamente.';

  @override
  String get chatAttachmentAutoDownloadHintOff =>
      'Los adjuntos se bloquean hasta que los apruebes.';

  @override
  String chatAttachmentCaption(String filename, String size) {
    return '📎 $filename ($size)';
  }

  @override
  String get chatAttachmentFallbackLabel => 'Adjunto';

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
      'El adjunto supera el limite del servidor.';

  @override
  String chatAttachmentTooLargeMessage(String limit) {
    return 'El adjunto supera el limite del servidor ($limit).';
  }

  @override
  String chatMessageErrorWithBody(String label, String body) {
    return '$label: \"$body\"';
  }

  @override
  String get messageErrorServiceUnavailableTooltip =>
      'El servicio informo de un problema temporal.';

  @override
  String get messageErrorServiceUnavailable => 'Servicio no disponible';

  @override
  String get messageErrorServerNotFound => 'Servidor no encontrado';

  @override
  String get messageErrorServerTimeout => 'Tiempo de espera del servidor';

  @override
  String get messageErrorUnknown => 'Error desconocido';

  @override
  String get messageErrorNotEncryptedForDevice =>
      'No cifrado para este dispositivo';

  @override
  String get messageErrorMalformedKey => 'Clave de cifrado mal formada';

  @override
  String get messageErrorUnknownSignedPrekey => 'Prekey firmada desconocida';

  @override
  String get messageErrorNoDeviceSession => 'Sin sesion de dispositivo';

  @override
  String get messageErrorSkippingTooManyKeys =>
      'Se omitieron demasiadas claves';

  @override
  String get messageErrorInvalidHmac => 'HMAC invalido';

  @override
  String get messageErrorMalformedCiphertext => 'Cifrado mal formado';

  @override
  String get messageErrorNoKeyMaterial => 'Falta material de clave';

  @override
  String get messageErrorNoDecryptionKey => 'Falta clave de descifrado';

  @override
  String get messageErrorInvalidKex => 'Intercambio de claves invalido';

  @override
  String get messageErrorUnknownOmemo => 'Error OMEMO desconocido';

  @override
  String get messageErrorInvalidAffixElements => 'Elementos de afijo invalidos';

  @override
  String get messageErrorEmptyDeviceList => 'Lista de dispositivos vacia';

  @override
  String get messageErrorOmemoUnsupported => 'OMEMO no compatible';

  @override
  String get messageErrorEncryptionFailure => 'Fallo de cifrado';

  @override
  String get messageErrorInvalidEnvelope => 'Sobre invalido';

  @override
  String get messageErrorFileDownloadFailure =>
      'Fallo en la descarga del archivo';

  @override
  String get messageErrorFileUploadFailure => 'Fallo en la carga del archivo';

  @override
  String get messageErrorFileDecryptionFailure =>
      'Fallo al descifrar el archivo';

  @override
  String get messageErrorFileEncryptionFailure => 'Fallo al cifrar el archivo';

  @override
  String get messageErrorPlaintextFileInOmemo =>
      'Archivo en texto plano en mensaje OMEMO';

  @override
  String get messageErrorEmailSendFailure => 'Fallo al enviar el correo';

  @override
  String get messageErrorEmailAttachmentTooLarge =>
      'Adjunto de correo demasiado grande';

  @override
  String get messageErrorEmailRecipientRejected =>
      'Destinatario de correo rechazado';

  @override
  String get messageErrorEmailAuthenticationFailed =>
      'Autenticacion de correo fallida';

  @override
  String get messageErrorEmailBounced => 'Correo rebotado';

  @override
  String get messageErrorEmailThrottled => 'Correo limitado';

  @override
  String get chatEmailResendFailedDetails => 'No se pudo reenviar el correo.';

  @override
  String get authEnableXmppOrSmtp => 'Enable XMPP or SMTP to continue.';

  @override
  String get authUsernamePasswordMismatch =>
      'Username and password have different nullness.';

  @override
  String get authStoredCredentialsOutdated =>
      'Stored credentials are outdated. Please log in manually.';

  @override
  String get authMissingDatabaseSecrets =>
      'Local database secrets are missing for this account. Axichat cannot open your existing chats. Restore the original install or reset local data to continue.';

  @override
  String get authInvalidCredentials => 'Incorrect username or password';

  @override
  String get authGenericError => 'Error. Please try again later.';

  @override
  String get authStorageLocked =>
      'Storage is locked by another Axichat instance. Close other windows or processes and try again.';

  @override
  String get authEmailServerUnreachable =>
      'Unable to reach the email server. Please try again.';

  @override
  String get authEmailSetupFailed => 'Email setup failed. Please try again.';

  @override
  String get authEmailPasswordMissing =>
      'Stored email password missing. Please log in manually.';

  @override
  String get authEmailAuthFailed =>
      'Email authentication failed. Please log in again.';

  @override
  String get signupCleanupInProgress =>
      'Cleaning up your previous signup attempt. We will retry the removal as soon as you are back online; try again once it finishes.';

  @override
  String get signupFailedTryAgain => 'Failed to register, try again later.';

  @override
  String get authPasswordMismatch => 'New passwords do not match.';

  @override
  String get authPasswordChangeDisabled =>
      'Password changes are disabled for this account.';

  @override
  String get authPasswordChangeRejected =>
      'Current password is incorrect, or the new password does not meet server requirements.';

  @override
  String get authPasswordChangeFailed =>
      'Unable to change password. Please try again later.';

  @override
  String get authPasswordChangeSuccess => 'Password changed successfully.';

  @override
  String get authPasswordIncorrect => 'Incorrect password. Please try again.';

  @override
  String get authAccountNotFound => 'Account not found.';

  @override
  String get authAccountDeletionDisabled =>
      'Account deletion is disabled for this account.';

  @override
  String get authAccountDeletionFailed =>
      'Unable to delete account. Please try again later.';

  @override
  String get authDemoModeFailed =>
      'Failed to start demo mode. Please try again.';

  @override
  String authLoginBackoff(Object seconds) {
    return 'Too many attempts. Wait $seconds seconds before trying again.';
  }

  @override
  String get signupAvatarCropTitle => 'Crop & focus';

  @override
  String get signupAvatarCropHint =>
      'Only the area inside the circle will appear in the final avatar.';

  @override
  String get xmppOperationPubSubBookmarksStart => 'Syncing bookmarks...';

  @override
  String get xmppOperationPubSubBookmarksSuccess => 'Bookmarks synced';

  @override
  String get xmppOperationPubSubBookmarksFailure => 'Bookmarks sync failed';

  @override
  String get xmppOperationPubSubConversationsStart => 'Syncing chats list...';

  @override
  String get xmppOperationPubSubConversationsSuccess => 'Chats list synced';

  @override
  String get xmppOperationPubSubConversationsFailure =>
      'Chats list sync failed';

  @override
  String get xmppOperationPubSubDraftsStart => 'Syncing drafts...';

  @override
  String get xmppOperationPubSubDraftsSuccess => 'Drafts synced';

  @override
  String get xmppOperationPubSubDraftsFailure => 'Drafts sync failed';

  @override
  String get xmppOperationPubSubSpamStart => 'Syncing spam list...';

  @override
  String get xmppOperationPubSubSpamSuccess => 'Spam list synced';

  @override
  String get xmppOperationPubSubSpamFailure => 'Spam list sync failed';

  @override
  String get xmppOperationPubSubEmailBlocklistStart =>
      'Syncing email blocklist...';

  @override
  String get xmppOperationPubSubEmailBlocklistSuccess =>
      'Email blocklist synced';

  @override
  String get xmppOperationPubSubEmailBlocklistFailure =>
      'Email blocklist sync failed';

  @override
  String get xmppOperationPubSubAvatarMetadataStart =>
      'Syncing avatar details...';

  @override
  String get xmppOperationPubSubAvatarMetadataSuccess =>
      'Avatar details synced';

  @override
  String get xmppOperationPubSubAvatarMetadataFailure =>
      'Avatar details sync failed';

  @override
  String get xmppOperationPubSubFetchStart => 'Syncing account updates...';

  @override
  String get xmppOperationPubSubFetchSuccess => 'Account updates synced';

  @override
  String get xmppOperationPubSubFetchFailure => 'Account updates sync failed';

  @override
  String get xmppOperationMamLoginStart => 'Syncing messages...';

  @override
  String get xmppOperationMamLoginSuccess => 'Messages synced';

  @override
  String get xmppOperationMamLoginFailure => 'Message sync failed';

  @override
  String get xmppOperationMamGlobalStart => 'Syncing full history...';

  @override
  String get xmppOperationMamGlobalSuccess => 'History synced';

  @override
  String get xmppOperationMamGlobalFailure => 'History sync failed';

  @override
  String get xmppOperationMamMucStart => 'Syncing room history...';

  @override
  String get xmppOperationMamMucSuccess => 'Room history synced';

  @override
  String get xmppOperationMamMucFailure => 'Room history sync failed';

  @override
  String get xmppOperationMamFetchStart => 'Fetching archived messages...';

  @override
  String get xmppOperationMamFetchSuccess => 'Archive fetched';

  @override
  String get xmppOperationMamFetchFailure => 'Archive fetch failed';

  @override
  String get xmppOperationMucJoinStart => 'Joining room...';

  @override
  String get xmppOperationMucJoinSuccess => 'Room joined';

  @override
  String get xmppOperationMucJoinFailure => 'Room join failed';
}
