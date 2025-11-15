import 'dart:async';
import 'dart:collection';

import 'package:async/async.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/chat/util/chat_subject_codec.dart';
import 'package:axichat/src/common/event_transform.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/attachment_optimizer.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/email/service/delta_error_mapper.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/service/share_token_codec.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
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
    this.subject,
  });

  final String? body;
  final EmailAttachment? attachment;
  final String shareId;
  final String? subject;

  @override
  List<Object?> get props => [body, attachment, shareId, subject];
}

enum ChatToastVariant { info, warning, destructive }

class ChatToast extends Equatable {
  const ChatToast({
    required this.message,
    this.variant = ChatToastVariant.info,
  });

  final String message;
  final ChatToastVariant variant;

  bool get isDestructive => variant == ChatToastVariant.destructive;

  @override
  List<Object?> get props => [message, variant];
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
    on<_EmailSyncStateChanged>(_onEmailSyncStateChanged);
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
    on<ChatSubjectChanged>(
      _onChatSubjectChanged,
      transformer: blocDebounce(const Duration(milliseconds: 200)),
    );
    if (jid != null) {
      _notificationService.dismissNotifications();
      _chatSubscription = _chatsService
          .chatStream(jid!)
          .listen((chat) => chat == null ? null : add(_ChatUpdated(chat)));
      _subscribeToMessages(limit: messageBatchSize, filter: state.viewFilter);
      unawaited(_initializeViewFilter());
    }
    _emailSyncSubscription = _emailService?.syncStateStream.listen(
      (syncState) => add(_EmailSyncStateChanged(syncState)),
    );
    final initialSyncState = _emailService?.syncState;
    if (initialSyncState != null) {
      add(_EmailSyncStateChanged(initialSyncState));
    }
  }

  static const messageBatchSize = 50;
  static final RegExp _axiDomainPattern =
      RegExp(r'@axi\.im$', caseSensitive: false);

  final String? jid;
  final MessageService _messageService;
  final ChatsService _chatsService;
  final NotificationService _notificationService;
  final EmailService? _emailService;
  final OmemoService? _omemoService;
  final Logger _log = Logger('ChatBloc');
  var _pendingAttachmentSeed = 0;
  var _composerHydrationSeed = 0;
  String? _lastOfflineDraftSignature;

  late final StreamSubscription<Chat?> _chatSubscription;
  StreamSubscription<List<Message>>? _messageSubscription;
  StreamSubscription<EmailSyncState>? _emailSyncSubscription;
  var _currentMessageLimit = messageBatchSize;
  String? _emailSyncComposerMessage;

  RestartableTimer? _typingTimer;

  bool get encryptionAvailable => _omemoService != null;
  bool get _isEmailChat => state.chat?.defaultTransport.isEmail ?? false;

  String _nextPendingAttachmentId() => 'pending-${_pendingAttachmentSeed++}';

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
    await _emailSyncSubscription?.cancel();
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
      emailSubject: resetContext ? null : state.emailSubject,
      emailSubjectHydrationText:
          resetContext ? null : state.emailSubjectHydrationText,
      emailSubjectHydrationId: resetContext ? 0 : state.emailSubjectHydrationId,
    ));
  }

  Future<void> _onChatMessagesUpdated(
    _ChatMessagesUpdated event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(items: event.items));
    if (state.chat?.supportsEmail == true) {
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

  void _onEmailSyncStateChanged(
    _EmailSyncStateChanged event,
    Emitter<ChatState> emit,
  ) {
    final nextState = event.state;
    if (!_isEmailChat) {
      if (state.emailSyncState != nextState) {
        emit(state.copyWith(emailSyncState: nextState));
      }
      return;
    }
    var composerError = state.composerError;
    if (nextState.status == EmailSyncStatus.ready) {
      if (composerError != null && composerError == _emailSyncComposerMessage) {
        composerError = null;
      }
      _emailSyncComposerMessage = null;
      _lastOfflineDraftSignature = null;
    } else {
      final fallback = nextState.status == EmailSyncStatus.offline
          ? 'Email is offline. Messages will be saved to Drafts until the connection returns.'
          : nextState.status == EmailSyncStatus.recovering
              ? 'Email sync is refreshing…'
              : 'Email sync failed. Please try again.';
      final message = nextState.message ?? fallback;
      _emailSyncComposerMessage = message;
      composerError = message;
    }
    emit(
      state.copyWith(
        emailSyncState: nextState,
        composerError: composerError,
      ),
    );
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
    final trimmedText = event.text.trim();
    final attachments = List<PendingAttachment>.from(state.pendingAttachments);
    final queuedAttachments = attachments
        .where(
            (attachment) => attachment.status == PendingAttachmentStatus.queued)
        .toList();
    final hasQueuedAttachments = queuedAttachments.isNotEmpty;
    final hasSubject = state.emailSubject?.trim().isNotEmpty == true;
    final quotedDraft = state.quoting;
    if (trimmedText.isEmpty && !hasQueuedAttachments && !hasSubject) {
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
    final recipients = _resolveComposerRecipients(chat);
    final split = _splitRecipientsForSend(
      recipients: recipients,
      forceEmail: hasQueuedAttachments,
    );
    final emailRecipients = split.emailRecipients;
    final xmppRecipients = split.xmppRecipients;
    final requiresEmail = emailRecipients.isNotEmpty || hasQueuedAttachments;
    final service = _emailService;
    if (requiresEmail && service == null) {
      emit(
        state.copyWith(
          composerError: 'Email sending is unavailable for this chat.',
        ),
      );
      return;
    }
    var emailSendSucceeded = false;
    var xmppSendSucceeded = false;
    try {
      if (requiresEmail) {
        if (emailRecipients.isEmpty) {
          emit(
            state.copyWith(
              composerError: 'Select at least one recipient.',
            ),
          );
          return;
        }
        final invalidEmailRecipients = emailRecipients.where(
          (recipient) {
            final targetChat = recipient.target.chat;
            if (targetChat != null) {
              return !targetChat.supportsEmail;
            }
            return recipient.target.address?.isNotEmpty != true;
          },
        );
        if (invalidEmailRecipients.isNotEmpty) {
          emit(
            state.copyWith(
              composerError: 'Email is unavailable for one or more recipients.',
            ),
          );
          return;
        }
        final hasBody = trimmedText.isNotEmpty;
        final body = hasBody
            ? _composeEmailBody(trimmedText, quotedDraft)
            : (hasSubject ? '' : null);
        if (state.emailSyncState.requiresAttention) {
          await _handleBrokenEmailSend(
            chat: chat,
            recipients: emailRecipients,
            rawText: trimmedText,
            quotedDraft: quotedDraft,
            emit: emit,
          );
          return;
        }
        if (body != null) {
          final shouldFanOut = _shouldFanOut(emailRecipients, chat);
          if (shouldFanOut) {
            final sent = await _sendFanOut(
              recipients: emailRecipients,
              text: body,
              subject: state.emailSubject,
              emit: emit,
            );
            if (!sent) {
              return;
            }
          } else {
            await service!.sendMessage(
              chat: chat,
              body: body,
              subject: state.emailSubject,
            );
          }
          emailSendSucceeded = true;
        }
        if (hasQueuedAttachments) {
          await _sendQueuedAttachments(
            attachments: queuedAttachments,
            chat: chat,
            service: service!,
            recipients: emailRecipients,
            emit: emit,
          );
          emailSendSucceeded = true;
        }
      }
      if (xmppRecipients.isNotEmpty) {
        final xmppBody = _composeXmppBody(
          body: trimmedText,
          subject: state.emailSubject,
        );
        if (xmppBody.isNotEmpty) {
          await _sendXmppFanOut(
            recipients: xmppRecipients,
            body: xmppBody,
            quotedDraft: quotedDraft,
          );
          xmppSendSucceeded = true;
        }
      } else if (!requiresEmail && trimmedText.isNotEmpty) {
        final sameChatQuote =
            quotedDraft != null && quotedDraft.chatJid == chat.jid
                ? quotedDraft
                : null;
        await _messageService.sendMessage(
          jid: chat.jid,
          text: trimmedText,
          encryptionProtocol: chat.encryptionProtocol,
          quotedMessage: sameChatQuote,
        );
        xmppSendSucceeded = true;
      }
    } on DeltaChatException catch (error, stackTrace) {
      _log.warning(
        'Failed to send email message for chat ${chat.jid}',
        error,
        stackTrace,
      );
      if (requiresEmail) {
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
      if ((emailSendSucceeded || xmppSendSucceeded) &&
          (state.emailSubject?.isNotEmpty ?? false)) {
        _clearEmailSubject(emit);
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
    final chat = state.chat;
    final service = _emailService;
    if (chat == null || service == null || !chat.supportsEmail) {
      return;
    }
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
    if (state.emailSyncState.requiresAttention) {
      emit(
        _attachToast(
          state,
          const ChatToast(
            message: 'Email is offline. Retry once sync recovers.',
            variant: ChatToastVariant.warning,
          ),
        ),
      );
      return;
    }
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
    if (state.emailSyncState.requiresAttention) {
      emit(
        _attachToast(
          state,
          const ChatToast(
            message: 'Email is offline. Retry once sync recovers.',
            variant: ChatToastVariant.warning,
          ),
        ),
      );
      return;
    }
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
      subject: draft.subject,
      emit: emit,
    );
  }

  void _onChatSubjectChanged(
    ChatSubjectChanged event,
    Emitter<ChatState> emit,
  ) {
    if (state.emailSubject == event.subject) {
      return;
    }
    emit(state.copyWith(emailSubject: event.subject));
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
        subject: state.emailSubject,
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
    } on DeltaChatException catch (error, stackTrace) {
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

  Future<void> _handleBrokenEmailSend({
    required Chat chat,
    required List<ComposerRecipient> recipients,
    required String rawText,
    required Message? quotedDraft,
    required Emitter<ChatState> emit,
  }) async {
    final resolvedRecipients =
        _draftRecipientJids(chat: chat, recipients: recipients);
    if (resolvedRecipients.isEmpty) {
      emit(
        _attachToast(
          state.copyWith(
            composerError: 'Unable to resolve recipients for this draft.',
          ),
          const ChatToast(
            message: 'Unable to save draft while email is offline.',
            variant: ChatToastVariant.destructive,
          ),
        ),
      );
      return;
    }
    final trimmed = rawText.trim();
    final body = trimmed.isEmpty ? '' : _composeEmailBody(trimmed, quotedDraft);
    final signature = _draftSignature(
      recipients: resolvedRecipients,
      body: body,
      subject: state.emailSubject,
      pendingAttachments: state.pendingAttachments,
    );
    final attachments =
        state.pendingAttachments.map((pending) => pending.attachment).toList();
    if (_lastOfflineDraftSignature == signature) {
      emit(
        _attachToast(
          state,
          const ChatToast(
            message: 'Draft already saved while email is offline.',
            variant: ChatToastVariant.warning,
          ),
        ),
      );
      return;
    }
    try {
      await _messageService.saveDraft(
        id: null,
        jids: resolvedRecipients,
        body: body,
        subject: state.emailSubject,
        attachments: attachments,
      );
      _lastOfflineDraftSignature = signature;
      emit(
        _attachToast(
          state,
          const ChatToast(
            message:
                'Saved to Drafts because email is offline. Reopen it once sync recovers.',
          ),
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to save offline email draft for chat ${chat.jid}',
        error,
        stackTrace,
      );
      emit(
        _attachToast(
          state.copyWith(
            composerError:
                'Unable to save draft while email is offline. Try again shortly.',
          ),
          const ChatToast(
            message:
                'Unable to save draft while email is offline. Try again shortly.',
            variant: ChatToastVariant.destructive,
          ),
        ),
      );
    }
  }

  List<String> _draftRecipientJids({
    required Chat chat,
    required List<ComposerRecipient> recipients,
  }) {
    if (recipients.isEmpty) {
      return [chat.jid];
    }
    final resolved = <String>{};
    for (final recipient in recipients) {
      final chatJid = recipient.target.chat?.jid;
      final address = recipient.target.address;
      final value = chatJid ?? address;
      if (value != null && value.isNotEmpty) {
        resolved.add(value);
      }
    }
    return resolved.toList();
  }

  String _draftSignature({
    required List<String> recipients,
    required String body,
    required String? subject,
    required List<PendingAttachment> pendingAttachments,
  }) {
    final sortedRecipients = List<String>.from(recipients)..sort();
    final buffer = StringBuffer(sortedRecipients.join(','))
      ..write('::')
      ..write(body)
      ..write('::subject:')
      ..write(subject ?? '');
    if (pendingAttachments.isNotEmpty) {
      final attachmentKeys = pendingAttachments
          .map((pending) => pending.attachment.path)
          .where((path) => path.isNotEmpty)
          .toList()
        ..sort();
      buffer
        ..write('::attachments:')
        ..write(attachmentKeys.join(','));
    }
    return buffer.toString();
  }

  ChatState _attachToast(ChatState base, ChatToast toast) => base.copyWith(
        toast: toast,
        toastId: base.toastId + 1,
      );

  void _clearEmailSubject(Emitter<ChatState> emit) {
    if (state.emailSubject?.isEmpty ?? true) {
      return;
    }
    emit(
      state.copyWith(
        emailSubject: '',
        emailSubjectHydrationId: state.emailSubjectHydrationId + 1,
        emailSubjectHydrationText: '',
      ),
    );
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

  List<ComposerRecipient> _resolveComposerRecipients(Chat chat) {
    final recipients = _includedRecipients();
    if (recipients.isNotEmpty) {
      return recipients;
    }
    return [
      ComposerRecipient(
        target: FanOutTarget.chat(chat),
        included: true,
        pinned: true,
      ),
    ];
  }

  ({
    List<ComposerRecipient> emailRecipients,
    List<ComposerRecipient> xmppRecipients
  }) _splitRecipientsForSend({
    required List<ComposerRecipient> recipients,
    required bool forceEmail,
  }) {
    final emailRecipients = <ComposerRecipient>[];
    final xmppRecipients = <ComposerRecipient>[];
    for (final recipient in recipients) {
      final targetChat = recipient.target.chat;
      if (forceEmail) {
        emailRecipients.add(recipient);
        continue;
      }
      if (targetChat == null) {
        emailRecipients.add(recipient);
        continue;
      }
      final identifier = targetChat.jid.toLowerCase();
      final isAxiRecipient =
          identifier.isNotEmpty && _axiDomainPattern.hasMatch(identifier);
      final prefersXmpp = isAxiRecipient && !targetChat.transport.isEmail;
      if (prefersXmpp) {
        xmppRecipients.add(recipient);
      } else {
        emailRecipients.add(recipient);
      }
    }
    return (
      emailRecipients: emailRecipients,
      xmppRecipients: xmppRecipients,
    );
  }

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

  String _composeXmppBody({
    required String body,
    required String? subject,
  }) =>
      ChatSubjectCodec.composeXmppBody(
        body: body,
        subject: subject,
      );

  Future<void> _sendXmppFanOut({
    required List<ComposerRecipient> recipients,
    required String body,
    required Message? quotedDraft,
  }) async {
    final processed = <String>{};
    for (final recipient in recipients) {
      final targetChat = recipient.target.chat;
      final targetJid = targetChat?.jid;
      if (targetChat == null || targetJid == null) {
        continue;
      }
      if (!processed.add(targetJid)) continue;
      final quote = quotedDraft != null && quotedDraft.chatJid == targetJid
          ? quotedDraft
          : null;
      await _messageService.sendMessage(
        jid: targetJid,
        text: body,
        encryptionProtocol: targetChat.encryptionProtocol,
        quotedMessage: quote,
      );
    }
  }

  Future<bool> _sendFanOut({
    required List<ComposerRecipient> recipients,
    String? text,
    EmailAttachment? attachment,
    String? shareId,
    String? subject,
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
        subject: subject,
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
          subject: subject,
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
    final nextSubject = shareContext?.subject;
    final shouldHydrateSubject =
        nextSubject != null && nextSubject != state.emailSubject;
    emit(
      state.copyWith(
        recipients: recipients,
        pendingAttachments: pendingAttachments,
        composerHydrationId: nextHydrationId,
        composerHydrationText: message.body ?? '',
        composerError: message.error.isNotNone
            ? message.error.asString
            : state.composerError,
        emailSubject: shouldHydrateSubject ? nextSubject : state.emailSubject,
        emailSubjectHydrationId: shouldHydrateSubject
            ? state.emailSubjectHydrationId + 1
            : state.emailSubjectHydrationId,
        emailSubjectHydrationText:
            shouldHydrateSubject ? nextSubject : state.emailSubject,
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
