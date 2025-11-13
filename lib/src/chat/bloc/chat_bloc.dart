import 'dart:async';
import 'dart:collection';

import 'package:async/async.dart';
import 'package:axichat/src/common/event_transform.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/attachment_optimizer.dart';
import 'package:axichat/src/email/service/delta_error_mapper.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/scheduler.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';

part 'chat_bloc.freezed.dart';
part 'chat_event.dart';
part 'chat_state.dart';

class ComposerRecipient extends Equatable {
  const ComposerRecipient({
    required this.target,
    this.included = true,
    this.pinned = false,
  });

  final FanOutTarget target;
  final bool included;
  final bool pinned;

  String get key => target.key;

  ComposerRecipient copyWith({
    FanOutTarget? target,
    bool? included,
    bool? pinned,
  }) =>
      ComposerRecipient(
        target: target ?? this.target,
        included: included ?? this.included,
        pinned: pinned ?? this.pinned,
      );

  @override
  List<Object?> get props => [target, included, pinned];
}

class FanOutDraft extends Equatable {
  const FanOutDraft({
    this.body,
    this.attachment,
    required this.shareId,
  });

  final String? body;
  final EmailAttachment? attachment;
  final String shareId;

  @override
  List<Object?> get props => [body, attachment, shareId];
}

enum PendingAttachmentStatus { queued, uploading, failed }

class PendingAttachment extends Equatable {
  const PendingAttachment({
    required this.id,
    required this.attachment,
    this.status = PendingAttachmentStatus.queued,
    this.errorMessage,
  });

  final String id;
  final EmailAttachment attachment;
  final PendingAttachmentStatus status;
  final String? errorMessage;

  PendingAttachment copyWith({
    EmailAttachment? attachment,
    PendingAttachmentStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return PendingAttachment(
      id: id,
      attachment: attachment ?? this.attachment,
      status: status ?? this.status,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [id, attachment, status, errorMessage];
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required this.jid,
    required MessageService messageService,
    required ChatsService chatsService,
    required NotificationService notificationService,
    EmailService? emailService,
    OmemoService? omemoService,
  })  : _messageService = messageService,
        _chatsService = chatsService,
        _notificationService = notificationService,
        _emailService = emailService,
        _omemoService = omemoService,
        super(const ChatState(items: [])) {
    on<_ChatUpdated>(_onChatUpdated);
    on<_ChatMessagesUpdated>(_onChatMessagesUpdated);
    on<ChatMessageFocused>(_onChatMessageFocused);
    on<ChatTypingStarted>(_onChatTypingStarted);
    on<_ChatTypingStopped>(_onChatTypingStopped);
    on<ChatMessageSent>(
      _onChatMessageSent,
      transformer: blocThrottle(downTime),
    );
    on<ChatMuted>(_onChatMuted);
    on<ChatResponsivityChanged>(_onChatResponsivityChanged);
    on<ChatEncryptionChanged>(_onChatEncryptionChanged);
    on<ChatEncryptionRepaired>(_onChatEncryptionRepaired);
    on<ChatTransportChanged>(_onChatTransportChanged);
    on<ChatLoadEarlier>(_onChatLoadEarlier);
    on<ChatAlertHidden>(_onChatAlertHidden);
    on<ChatQuoteRequested>(_onChatQuoteRequested);
    on<ChatQuoteCleared>(_onChatQuoteCleared);
    on<ChatMessageReactionToggled>(_onChatMessageReactionToggled);
    on<ChatMessageForwardRequested>(_onChatMessageForwardRequested);
    on<ChatMessageResendRequested>(_onChatMessageResendRequested);
    on<ChatAttachmentPicked>(_onChatAttachmentPicked);
    on<ChatAttachmentRetryRequested>(_onChatAttachmentRetryRequested);
    on<ChatPendingAttachmentRemoved>(_onChatPendingAttachmentRemoved);
    on<ChatViewFilterChanged>(_onChatViewFilterChanged);
    on<ChatComposerRecipientAdded>(_onComposerRecipientAdded);
    on<ChatComposerRecipientRemoved>(_onComposerRecipientRemoved);
    on<ChatComposerRecipientToggled>(_onComposerRecipientToggled);
    on<ChatFanOutRetryRequested>(_onFanOutRetryRequested);
    if (jid != null) {
      _notificationService.dismissNotifications();
      _chatSubscription = _chatsService
          .chatStream(jid!)
          .listen((chat) => chat == null ? null : add(_ChatUpdated(chat)));
      _subscribeToMessages(limit: messageBatchSize, filter: state.viewFilter);
      unawaited(_initializeTransport());
      unawaited(_initializeViewFilter());
    }
  }

  static const messageBatchSize = 50;

  final String? jid;
  final MessageService _messageService;
  final ChatsService _chatsService;
  final NotificationService _notificationService;
  final EmailService? _emailService;
  final OmemoService? _omemoService;
  final Logger _log = Logger('ChatBloc');
  var _pendingAttachmentSeed = 0;
  var _composerHydrationSeed = 0;

  late final StreamSubscription<Chat?> _chatSubscription;
  StreamSubscription<List<Message>>? _messageSubscription;
  var _currentMessageLimit = messageBatchSize;

  RestartableTimer? _typingTimer;
  MessageTransport _transport = MessageTransport.xmpp;

  bool get encryptionAvailable => _omemoService != null;
  bool get _isEmailChat {
    final chat = state.chat;
    if (chat == null) return false;
    if (_transport.isEmail) return true;
    return chat.transport.isEmail;
  }

  String _nextPendingAttachmentId() => 'pending-${_pendingAttachmentSeed++}';

  Future<void> _initializeTransport() async {
    if (jid == null) return;
    try {
      _transport = await _chatsService.loadChatTransportPreference(jid!);
    } on Exception catch (error, stackTrace) {
      _log.fine(
        'Failed to load transport preference for $jid',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _initializeViewFilter() async {
    if (jid == null) return;
    try {
      final filter = await _chatsService.loadChatViewFilter(jid!);
      add(ChatViewFilterChanged(filter: filter, persist: false));
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to load view filter for $jid', error, stackTrace);
    }
  }

  void _subscribeToMessages({
    required int limit,
    required MessageTimelineFilter filter,
  }) {
    if (jid == null) return;
    unawaited(_messageSubscription?.cancel());
    _currentMessageLimit = limit;
    _messageSubscription = _messageService
        .messageStreamForChat(
          jid!,
          end: limit,
          filter: filter,
        )
        .listen((items) => add(_ChatMessagesUpdated(items)));
  }

  @override
  Future<void> close() async {
    await _chatSubscription.cancel();
    await _messageSubscription?.cancel();
    _typingTimer?.cancel();
    _typingTimer = null;
    return super.close();
  }

  void _onChatUpdated(_ChatUpdated event, Emitter<ChatState> emit) {
    final resetContext = state.chat?.jid != event.chat.jid;
    emit(state.copyWith(
      chat: event.chat,
      showAlert: event.chat.alert != null && state.chat?.alert == null,
      recipients: _syncRecipientsForChat(event.chat),
      fanOutReports: resetContext ? const {} : state.fanOutReports,
      fanOutDrafts: resetContext ? const {} : state.fanOutDrafts,
      shareContexts: resetContext ? const {} : state.shareContexts,
      composerError: resetContext ? null : state.composerError,
      composerHydrationText: resetContext ? null : state.composerHydrationText,
      composerHydrationId: resetContext ? 0 : state.composerHydrationId,
    ));
    if (event.chat.deltaChatId != null && _transport.isXmpp) {
      _transport = MessageTransport.email;
      unawaited(
        _chatsService.saveChatTransportPreference(
          jid: event.chat.jid,
          transport: _transport,
        ),
      );
    }
  }

  Future<void> _onChatMessagesUpdated(
    _ChatMessagesUpdated event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(items: event.items));
    if (_isEmailChat) {
      await _hydrateShareContexts(event.items, emit);
    }

    final lifecycleState = SchedulerBinding.instance.lifecycleState;
    if (!_isEmailChat && lifecycleState == AppLifecycleState.resumed) {
      for (final item in event.items) {
        if (!item.displayed &&
            item.senderJid != _chatsService.myJid &&
            item.body?.isNotEmpty == true) {
          _messageService.sendReadMarker(jid!, item.stanzaID);
        }
      }
    }
  }

  Future<void> _onChatMessageFocused(
    ChatMessageFocused event,
    Emitter<ChatState> emit,
  ) async {
    final messageId = event.messageID;
    if (messageId == null) {
      emit(state.copyWith(focused: null));
      return;
    }
    var target = state.items.where((e) => e.stanzaID == messageId).firstOrNull;
    if (target == null) {
      final fetched = await _messageService.loadMessageByStanzaId(messageId);
      if (fetched != null) {
        final updatedItems = List<Message>.from(state.items)
          ..removeWhere((msg) => msg.stanzaID == fetched.stanzaID)
          ..add(fetched)
          ..sort(
            (a, b) => (b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
              a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0),
            ),
          );
        emit(state.copyWith(items: updatedItems, focused: fetched));
        return;
      }
    }
    emit(state.copyWith(focused: target));
  }

  Future<void> _onChatTypingStarted(
      ChatTypingStarted event, Emitter<ChatState> emit) async {
    if (_typingTimer case final timer?) {
      if (timer.isActive) {
        timer.reset();
      }
      return;
    } else {
      _typingTimer = RestartableTimer(
        const Duration(seconds: 3),
        () => add(const _ChatTypingStopped()),
      );
    }
    if (!_isEmailChat) {
      await _chatsService.sendTyping(jid: state.chat!.jid, typing: true);
    }
    emit(state.copyWith(typing: true));
  }

  void _onChatTypingStopped(_ChatTypingStopped event, Emitter<ChatState> emit) {
    _stopTyping();
    emit(state.copyWith(typing: false));
  }

  Future<void> _onChatMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    _stopTyping();
    emit(state.copyWith(typing: false));
    final chat = state.chat;
    if (chat == null) return;
    final isEmailChat = _isEmailChat;
    final trimmedText = event.text.trim();
    final attachments = List<PendingAttachment>.from(state.pendingAttachments);
    final queuedAttachments = attachments
        .where(
            (attachment) => attachment.status == PendingAttachmentStatus.queued)
        .toList();
    final hasQueuedAttachments = queuedAttachments.isNotEmpty;
    final quotedDraft = state.quoting;
    try {
      if (isEmailChat) {
        final recipients = _includedRecipients();
        if (recipients.isEmpty) {
          emit(
            state.copyWith(
              composerError: 'Select at least one recipient.',
            ),
          );
          return;
        }
        final hasBody = trimmedText.isNotEmpty;
        if (!hasBody && !hasQueuedAttachments) {
          emit(
            state.copyWith(
              composerError: 'Message cannot be empty.',
            ),
          );
          return;
        }
        if (state.composerError != null) {
          emit(state.copyWith(composerError: null));
        }
        final service = _emailService;
        if (service == null) {
          throw StateError('EmailService not available for email chat.');
        }
        final body =
            hasBody ? _composeEmailBody(trimmedText, quotedDraft) : null;
        if (_shouldFanOut(recipients, chat)) {
          if (body != null) {
            final sent = await _sendFanOut(
              recipients: recipients,
              text: body,
              emit: emit,
            );
            if (!sent) {
              return;
            }
          }
          if (hasQueuedAttachments) {
            await _sendQueuedAttachments(
              attachments: queuedAttachments,
              chat: chat,
              service: service,
              recipients: recipients,
              emit: emit,
            );
          }
        } else {
          if (body != null) {
            await service.sendMessage(chat: chat, body: body);
          }
          if (hasQueuedAttachments) {
            await _sendQueuedAttachments(
              attachments: queuedAttachments,
              chat: chat,
              service: service,
              recipients: recipients,
              emit: emit,
            );
          }
        }
      } else {
        if (trimmedText.isEmpty) return;
        final sameChatQuote =
            quotedDraft != null && quotedDraft.chatJid == chat.jid
                ? quotedDraft
                : null;
        await _messageService.sendMessage(
          jid: jid!,
          text: trimmedText,
          encryptionProtocol: chat.encryptionProtocol,
          quotedMessage: sameChatQuote,
        );
      }
    } on DeltaSafeException catch (error, stackTrace) {
      _log.warning(
        'Failed to send email message for chat ${chat.jid}',
        error,
        stackTrace,
      );
      if (isEmailChat) {
        final mappedError = DeltaErrorMapper.resolve(error.message);
        final nextHydrationId = ++_composerHydrationSeed;
        emit(
          state.copyWith(
            composerError: mappedError.asString,
            composerHydrationId: nextHydrationId,
            composerHydrationText: trimmedText,
          ),
        );
      }
    } on XmppMessageException catch (_) {
      // Don't panic. User will see a visual difference in the message bubble.
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to send message for chat ${chat.jid}',
        error,
        stackTrace,
      );
    } finally {
      if (state.quoting != null) {
        emit(state.copyWith(quoting: null));
      }
    }
  }

  Future<void> _onChatMuted(
    ChatMuted event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    await _chatsService.toggleChatMuted(jid: jid!, muted: event.muted);
  }

  Future<void> _onChatResponsivityChanged(
    ChatResponsivityChanged event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    await _chatsService.toggleChatMarkerResponsive(
        jid: jid!, responsive: event.responsive);
  }

  Future<void> _onChatEncryptionChanged(
    ChatEncryptionChanged event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    await _chatsService.setChatEncryption(jid: jid!, protocol: event.protocol);
  }

  Future<void> _onChatEncryptionRepaired(
    ChatEncryptionRepaired event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    await _omemoService?.recreateSessions(jid: jid!);
  }

  Future<void> _onChatTransportChanged(
    ChatTransportChanged event,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    if (chat == null) return;
    if (_transport == event.transport) return;
    try {
      _transport = event.transport;
      await _chatsService.saveChatTransportPreference(
        jid: chat.jid,
        transport: event.transport,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to change transport for chat ${chat.jid}',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _onChatLoadEarlier(
    ChatLoadEarlier event,
    Emitter<ChatState> emit,
  ) async {
    final nextLimit = state.items.length + messageBatchSize;
    _subscribeToMessages(limit: nextLimit, filter: state.viewFilter);
  }

  Future<void> _onChatAlertHidden(
    ChatAlertHidden event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    emit(state.copyWith(showAlert: false));
    if (event.forever) {
      await _chatsService.clearChatAlert(jid: jid!);
    }
  }

  void _onChatQuoteRequested(
    ChatQuoteRequested event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(quoting: event.message));
  }

  void _onChatQuoteCleared(
    ChatQuoteCleared event,
    Emitter<ChatState> emit,
  ) {
    if (state.quoting != null) {
      emit(state.copyWith(quoting: null));
    }
  }

  Future<void> _onChatMessageReactionToggled(
    ChatMessageReactionToggled event,
    Emitter<ChatState> emit,
  ) async {
    if (_isEmailChat) return;
    try {
      await _messageService.reactToMessage(
        stanzaID: event.message.stanzaID,
        emoji: event.emoji,
      );
    } on Exception catch (error, stackTrace) {
      _log.fine(
        'Failed to react to message ${event.message.stanzaID}',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _onChatMessageForwardRequested(
    ChatMessageForwardRequested event,
    Emitter<ChatState> emit,
  ) async {
    final body = event.message.body;
    if (body?.isNotEmpty != true) return;
    final target = event.target;
    final isEmailTarget = target.deltaChatId != null ||
        (target.emailAddress?.isNotEmpty ?? false);
    try {
      if (isEmailTarget) {
        final emailService = _emailService;
        if (emailService == null) return;
        await emailService.sendMessage(chat: target, body: body!);
      } else {
        await _messageService.sendMessage(
          jid: target.jid,
          text: body!,
          encryptionProtocol: target.encryptionProtocol,
        );
      }
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to forward message ${event.message.stanzaID} to ${target.jid}',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _onChatMessageResendRequested(
    ChatMessageResendRequested event,
    Emitter<ChatState> emit,
  ) async {
    final message = event.message;
    if (message.body?.isNotEmpty != true) return;
    final isEmailMessage = message.deltaChatId != null;
    try {
      if (isEmailMessage) {
        await _rehydrateEmailDraft(message, emit);
        return;
      } else {
        await _messageService.resendMessage(message.stanzaID);
      }
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to resend message ${message.stanzaID}',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _onChatAttachmentPicked(
    ChatAttachmentPicked event,
    Emitter<ChatState> emit,
  ) async {
    if (!_isEmailChat) return;
    final chat = state.chat;
    final service = _emailService;
    if (chat == null || service == null) return;
    final quotedDraft = state.quoting;
    final rawCaption = event.attachment.caption?.trim();
    final caption = rawCaption?.isNotEmpty == true
        ? _composeEmailBody(rawCaption!, quotedDraft)
        : null;
    var preparedAttachment = event.attachment.copyWith(caption: caption);
    try {
      preparedAttachment =
          await EmailAttachmentOptimizer.optimize(preparedAttachment);
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to optimize attachment', error, stackTrace);
    }
    _addPendingAttachment(preparedAttachment, emit);
    if (state.quoting != null) {
      emit(state.copyWith(quoting: null));
    }
  }

  Future<void> _onChatAttachmentRetryRequested(
    ChatAttachmentRetryRequested event,
    Emitter<ChatState> emit,
  ) async {
    final pending = _pendingAttachmentById(event.attachmentId);
    final chat = state.chat;
    final service = _emailService;
    if (pending == null ||
        pending.status != PendingAttachmentStatus.failed ||
        chat == null ||
        service == null) {
      return;
    }
    final updated = pending.copyWith(
      status: PendingAttachmentStatus.queued,
      clearErrorMessage: true,
    );
    _replacePendingAttachment(updated, emit);
    await _sendPendingAttachment(
      pending: updated,
      chat: chat,
      service: service,
      recipients: _includedRecipients(),
      emit: emit,
    );
  }

  Future<void> _onChatPendingAttachmentRemoved(
    ChatPendingAttachmentRemoved event,
    Emitter<ChatState> emit,
  ) async {
    _removePendingAttachment(event.attachmentId, emit);
  }

  Future<void> _onChatViewFilterChanged(
    ChatViewFilterChanged event,
    Emitter<ChatState> emit,
  ) async {
    if (jid == null) return;
    emit(state.copyWith(viewFilter: event.filter));
    _subscribeToMessages(limit: _currentMessageLimit, filter: event.filter);
    if (event.persist) {
      await _chatsService.saveChatViewFilter(jid: jid!, filter: event.filter);
    }
  }

  void _onComposerRecipientAdded(
    ChatComposerRecipientAdded event,
    Emitter<ChatState> emit,
  ) {
    if (!_isEmailChat) return;
    final recipients = List<ComposerRecipient>.from(state.recipients);
    final index =
        recipients.indexWhere((recipient) => recipient.key == event.target.key);
    if (index >= 0) {
      recipients[index] = recipients[index].copyWith(
        target: event.target,
        included: true,
      );
    } else {
      recipients.add(ComposerRecipient(target: event.target));
    }
    emit(state.copyWith(recipients: recipients, composerError: null));
  }

  void _onComposerRecipientRemoved(
    ChatComposerRecipientRemoved event,
    Emitter<ChatState> emit,
  ) {
    if (!_isEmailChat) return;
    final recipients = List<ComposerRecipient>.from(state.recipients);
    final index = recipients
        .indexWhere((recipient) => recipient.key == event.recipientKey);
    if (index == -1 || recipients[index].pinned) {
      return;
    }
    recipients.removeAt(index);
    emit(state.copyWith(recipients: recipients, composerError: null));
  }

  void _onComposerRecipientToggled(
    ChatComposerRecipientToggled event,
    Emitter<ChatState> emit,
  ) {
    if (!_isEmailChat) return;
    final recipients = List<ComposerRecipient>.from(state.recipients);
    final index = recipients
        .indexWhere((recipient) => recipient.key == event.recipientKey);
    if (index == -1) {
      return;
    }
    final recipient = recipients[index];
    recipients[index] = recipient.copyWith(
      included: event.included ?? !recipient.included,
    );
    emit(state.copyWith(recipients: recipients, composerError: null));
  }

  Future<void> _onFanOutRetryRequested(
    ChatFanOutRetryRequested event,
    Emitter<ChatState> emit,
  ) async {
    final draft = state.fanOutDrafts[event.shareId];
    final report = state.fanOutReports[event.shareId];
    if (draft == null || report == null) return;
    final failedStatuses = report.statuses
        .where((status) => status.state == FanOutRecipientState.failed)
        .toList();
    if (failedStatuses.isEmpty) return;
    final recipients = <ComposerRecipient>[];
    for (final status in failedStatuses) {
      final jid = status.chat.jid;
      final existing = _recipientForChat(jid);
      if (existing != null) {
        recipients.add(existing.copyWith(included: true));
      } else {
        recipients.add(
          ComposerRecipient(target: FanOutTarget.chat(status.chat)),
        );
      }
    }
    if (recipients.isEmpty) return;
    await _sendFanOut(
      recipients: recipients,
      text: draft.body,
      attachment: draft.attachment,
      shareId: draft.shareId,
      emit: emit,
    );
  }

  Future<void> _stopTyping() async {
    _typingTimer?.cancel();
    _typingTimer = null;
    if (!_isEmailChat) {
      await _chatsService.sendTyping(jid: state.chat!.jid, typing: false);
    }
  }

  Future<void> _sendPendingAttachment({
    required PendingAttachment pending,
    required Chat chat,
    required EmailService service,
    required List<ComposerRecipient> recipients,
    required Emitter<ChatState> emit,
  }) async {
    var current = pending;
    if (current.status != PendingAttachmentStatus.uploading) {
      current = current.copyWith(
        status: PendingAttachmentStatus.uploading,
        clearErrorMessage: true,
      );
      _replacePendingAttachment(current, emit);
    }
    if (_shouldFanOut(recipients, chat)) {
      final succeeded = await _sendFanOut(
        recipients: recipients,
        attachment: current.attachment,
        emit: emit,
      );
      if (succeeded) {
        _removePendingAttachment(current.id, emit);
      } else {
        _markPendingAttachmentFailed(
          current.id,
          emit,
          message: state.composerError ??
              'Unable to send attachment. Please try again.',
        );
      }
      return;
    }
    try {
      await service.sendAttachment(
        chat: chat,
        attachment: current.attachment,
      );
      _removePendingAttachment(current.id, emit);
    } on DeltaSafeException catch (error, stackTrace) {
      _log.warning(
        'Failed to send attachment for chat ${chat.jid}',
        error,
        stackTrace,
      );
      final mappedError = DeltaErrorMapper.resolve(error.message);
      final readableMessage = mappedError.asString;
      _markPendingAttachmentFailed(
        current.id,
        emit,
        message: readableMessage,
      );
      emit(state.copyWith(composerError: readableMessage));
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to send attachment for chat ${chat.jid}',
        error,
        stackTrace,
      );
      _markPendingAttachmentFailed(current.id, emit);
      emit(
        state.copyWith(
          composerError: 'Unable to send attachment. Please try again.',
        ),
      );
    }
  }

  Future<void> _sendQueuedAttachments({
    required Iterable<PendingAttachment> attachments,
    required Chat chat,
    required EmailService service,
    required List<ComposerRecipient> recipients,
    required Emitter<ChatState> emit,
  }) async {
    for (final attachment in attachments) {
      final latest = _pendingAttachmentById(attachment.id);
      if (latest == null) {
        continue;
      }
      await _sendPendingAttachment(
        pending: latest,
        chat: chat,
        service: service,
        recipients: recipients,
        emit: emit,
      );
    }
  }

  String _composeEmailBody(String body, Message? quoted) {
    if (quoted?.body?.isNotEmpty != true) {
      return body;
    }
    final quotedBody = quoted!.body!
        .split('\n')
        .map((line) => line.isEmpty ? '>' : '> $line')
        .join('\n');
    return '$quotedBody\n\n$body';
  }

  List<ComposerRecipient> _includedRecipients() =>
      state.recipients.where((recipient) => recipient.included).toList();

  bool _shouldFanOut(List<ComposerRecipient> recipients, Chat chat) {
    if (recipients.isEmpty) return false;
    if (recipients.length == 1) {
      final targetChat = recipients.single.target.chat;
      if (targetChat != null && targetChat.jid == chat.jid) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _sendFanOut({
    required List<ComposerRecipient> recipients,
    String? text,
    EmailAttachment? attachment,
    String? shareId,
    required Emitter<ChatState> emit,
  }) async {
    final service = _emailService;
    if (service == null || recipients.isEmpty) return false;
    final effectiveShareId = shareId ?? ShareTokenCodec.generateShareId();
    try {
      final report = await service.fanOutSend(
        targets: recipients.map((recipient) => recipient.target).toList(),
        body: text,
        attachment: attachment,
        shareId: effectiveShareId,
      );
      final mergedRecipients = _mergeRecipientsWithReport(report);
      final reports =
          LinkedHashMap<String, FanOutSendReport>.from(state.fanOutReports)
            ..remove(report.shareId)
            ..[report.shareId] = report;
      final drafts = LinkedHashMap<String, FanOutDraft>.from(state.fanOutDrafts)
        ..remove(report.shareId)
        ..[report.shareId] = FanOutDraft(
          body: text,
          attachment: attachment,
          shareId: report.shareId,
        );
      emit(state.copyWith(
        recipients: mergedRecipients,
        fanOutReports: reports,
        fanOutDrafts: drafts,
        composerError: null,
      ));
      return true;
    } on FanOutValidationException catch (error) {
      emit(state.copyWith(composerError: error.message));
      return false;
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to send fan-out message', error, stackTrace);
      emit(
        state.copyWith(
          composerError: 'Unable to send message. Please try again.',
        ),
      );
      return false;
    }
    // Should be unreachable.
    // ignore: dead_code
    return false;
  }

  List<ComposerRecipient> _mergeRecipientsWithReport(
    FanOutSendReport report,
  ) {
    if (report.statuses.isEmpty) {
      return state.recipients;
    }
    final recipients = List<ComposerRecipient>.from(state.recipients);
    var changed = false;
    for (final status in report.statuses) {
      final jid = status.chat.jid;
      final matchesIndex = recipients.indexWhere(
        (recipient) =>
            recipient.target.chat?.jid == jid ||
            (recipient.target.address != null &&
                recipient.target.address == status.chat.emailAddress),
      );
      if (matchesIndex >= 0 &&
          recipients[matchesIndex].target.chat?.jid != jid) {
        recipients[matchesIndex] = recipients[matchesIndex].copyWith(
          target: FanOutTarget.chat(status.chat),
        );
        changed = true;
      }
    }
    return changed ? recipients : state.recipients;
  }

  Future<void> _rehydrateEmailDraft(
    Message message,
    Emitter<ChatState> emit,
  ) async {
    final chat = state.chat;
    final service = _emailService;
    if (chat == null || service == null) return;
    ShareContext? shareContext = state.shareContexts[message.stanzaID];
    shareContext ??= await service.shareContextForMessage(message);
    final recipients = _recipientsForHydration(
      chat: chat,
      shareContext: shareContext,
    );
    var pendingAttachments = state.pendingAttachments;
    if (message.fileMetadataID != null) {
      final attachment = await service.attachmentForMessage(message);
      if (attachment != null &&
          !_hasPendingAttachmentForPath(
            pendingAttachments: pendingAttachments,
            path: attachment.path,
          )) {
        pendingAttachments = [
          ...pendingAttachments,
          PendingAttachment(
            id: _nextPendingAttachmentId(),
            attachment: attachment,
          ),
        ];
      }
    }
    final nextHydrationId = ++_composerHydrationSeed;
    emit(
      state.copyWith(
        recipients: recipients,
        pendingAttachments: pendingAttachments,
        composerHydrationId: nextHydrationId,
        composerHydrationText: message.body ?? '',
        composerError: message.error.isNotNone
            ? message.error.asString
            : state.composerError,
      ),
    );
  }

  List<ComposerRecipient> _recipientsForHydration({
    required Chat chat,
    ShareContext? shareContext,
  }) {
    final recipients = _syncRecipientsForChat(chat);
    if (shareContext == null) {
      return recipients;
    }
    final updated = List<ComposerRecipient>.from(recipients);
    for (final participant in shareContext.participants) {
      final jid = participant.jid;
      if (jid == chat.jid) {
        continue;
      }
      final target = FanOutTarget.chat(participant);
      final index = updated.indexWhere((recipient) => recipient.key == jid);
      if (index >= 0) {
        updated[index] = updated[index].copyWith(
          target: target,
          included: true,
        );
      } else {
        updated.add(
          ComposerRecipient(target: target, included: true),
        );
      }
    }
    return updated;
  }

  bool _hasPendingAttachmentForPath({
    required List<PendingAttachment> pendingAttachments,
    required String? path,
  }) {
    if (path == null || path.isEmpty) {
      return false;
    }
    for (final pending in pendingAttachments) {
      if (pending.attachment.path == path) {
        return true;
      }
    }
    return false;
  }

  ComposerRecipient? _recipientForChat(String jid) {
    for (final recipient in state.recipients) {
      final chat = recipient.target.chat;
      if (chat != null && chat.jid == jid) {
        return recipient;
      }
    }
    return null;
  }

  PendingAttachment _addPendingAttachment(
    EmailAttachment attachment,
    Emitter<ChatState> emit,
  ) {
    final pending = PendingAttachment(
      id: _nextPendingAttachmentId(),
      attachment: attachment,
    );
    emit(
      state.copyWith(
        pendingAttachments: [...state.pendingAttachments, pending],
      ),
    );
    return pending;
  }

  void _replacePendingAttachment(
    PendingAttachment replacement,
    Emitter<ChatState> emit,
  ) {
    final updated = state.pendingAttachments
        .map(
          (pending) => pending.id == replacement.id ? replacement : pending,
        )
        .toList();
    emit(state.copyWith(pendingAttachments: updated));
  }

  void _removePendingAttachment(
    String attachmentId,
    Emitter<ChatState> emit,
  ) {
    final updated = state.pendingAttachments
        .where((pending) => pending.id != attachmentId)
        .toList();
    if (updated.length == state.pendingAttachments.length) return;
    emit(state.copyWith(pendingAttachments: updated));
  }

  void _markPendingAttachmentFailed(
    String attachmentId,
    Emitter<ChatState> emit, {
    String? message,
  }) {
    final updated = state.pendingAttachments.map((pending) {
      if (pending.id != attachmentId) return pending;
      return pending.copyWith(
        status: PendingAttachmentStatus.failed,
        errorMessage: message ?? 'Unable to send attachment. Please try again.',
      );
    }).toList();
    emit(state.copyWith(pendingAttachments: updated));
  }

  PendingAttachment? _pendingAttachmentById(String attachmentId) {
    for (final pending in state.pendingAttachments) {
      if (pending.id == attachmentId) {
        return pending;
      }
    }
    return null;
  }

  List<ComposerRecipient> _syncRecipientsForChat(Chat chat) {
    if (!chat.transport.isEmail) {
      return const [];
    }
    final recipients = List<ComposerRecipient>.from(state.recipients);
    final key = chat.jid;
    final index = recipients.indexWhere(
      (recipient) => recipient.pinned && recipient.target.chat?.jid == key,
    );
    if (index >= 0) {
      recipients[index] = recipients[index].copyWith(
        target: FanOutTarget.chat(chat),
        included: true,
      );
      return recipients;
    }
    recipients.insert(
      0,
      ComposerRecipient(
        target: FanOutTarget.chat(chat),
        included: true,
        pinned: true,
      ),
    );
    return recipients;
  }

  Future<void> _hydrateShareContexts(
    List<Message> messages,
    Emitter<ChatState> emit,
  ) async {
    final emailService = _emailService;
    if (emailService == null) return;
    final pending = <String, ShareContext>{};
    for (final message in messages) {
      if (message.deltaMsgId == null) continue;
      if (state.shareContexts.containsKey(message.stanzaID)) {
        continue;
      }
      final context = await emailService.shareContextForMessage(message);
      if (context != null) {
        pending[message.stanzaID] = context;
      }
    }
    if (pending.isEmpty) return;
    final contexts = Map<String, ShareContext>.from(state.shareContexts)
      ..addAll(pending);
    emit(state.copyWith(shareContexts: contexts));
  }
}
