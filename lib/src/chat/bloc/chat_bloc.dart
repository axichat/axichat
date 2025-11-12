import 'dart:async';
import 'dart:collection';

import 'package:async/async.dart';
import 'package:axichat/src/common/event_transform.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/email_service.dart';
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
  });

  final String? body;
  final EmailAttachment? attachment;
  final String shareId;

  @override
  List<Object?> get props => [body, attachment, shareId];
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

  void _onChatMessageFocused(
    ChatMessageFocused event,
    Emitter<ChatState> emit,
  ) {
    emit(
      state.copyWith(
        focused:
            state.items.where((e) => e.stanzaID == event.messageID).firstOrNull,
      ),
    );
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
        if (state.composerError != null) {
          emit(state.copyWith(composerError: null));
        }
        final body = _composeEmailBody(event.text, quotedDraft);
        if (_shouldFanOut(recipients, chat)) {
          await _sendFanOut(
            recipients: recipients,
            text: body,
            emit: emit,
          );
        } else {
          final service = _emailService;
          if (service == null) {
            throw StateError('EmailService not available for email chat.');
          }
          await service.sendMessage(chat: chat, body: body);
        }
      } else {
        final sameChatQuote =
            quotedDraft != null && quotedDraft.chatJid == chat.jid
                ? quotedDraft
                : null;
        await _messageService.sendMessage(
          jid: jid!,
          text: event.text,
          encryptionProtocol: chat.encryptionProtocol,
          quotedMessage: sameChatQuote,
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
        final emailService = _emailService;
        final chat = state.chat;
        if (emailService == null || chat == null) return;
        await emailService.sendMessage(chat: chat, body: message.body!);
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
    _addPendingAttachment(event.attachment, emit);
    final quotedDraft = state.quoting;
    final rawCaption = event.attachment.caption?.trim();
    final caption = rawCaption?.isNotEmpty == true
        ? _composeEmailBody(rawCaption!, quotedDraft)
        : null;
    final recipients = _includedRecipients();
    final shouldFanOut = _shouldFanOut(recipients, chat);
    try {
      if (shouldFanOut) {
        await _sendFanOut(
          recipients: recipients,
          attachment: event.attachment.copyWith(caption: caption),
          emit: emit,
        );
      } else {
        await service.sendAttachment(
          chat: chat,
          attachment: event.attachment.copyWith(caption: caption),
        );
      }
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to send attachment for chat ${chat.jid}',
        error,
        stackTrace,
      );
    } finally {
      _removePendingAttachment(event.attachment, emit);
      if (state.quoting != null) {
        emit(state.copyWith(quoting: null));
      }
    }
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

  Future<void> _sendFanOut({
    required List<ComposerRecipient> recipients,
    String? text,
    EmailAttachment? attachment,
    String? shareId,
    required Emitter<ChatState> emit,
  }) async {
    final service = _emailService;
    if (service == null || recipients.isEmpty) return;
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
    } on FanOutValidationException catch (error) {
      emit(state.copyWith(composerError: error.message));
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to send fan-out message', error, stackTrace);
      emit(
        state.copyWith(
          composerError: 'Unable to send message. Please try again.',
        ),
      );
    }
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

  ComposerRecipient? _recipientForChat(String jid) {
    for (final recipient in state.recipients) {
      final chat = recipient.target.chat;
      if (chat != null && chat.jid == jid) {
        return recipient;
      }
    }
    return null;
  }

  void _addPendingAttachment(
    EmailAttachment attachment,
    Emitter<ChatState> emit,
  ) {
    final updated = List<EmailAttachment>.from(state.pendingAttachments)
      ..add(attachment);
    emit(state.copyWith(pendingAttachments: updated));
  }

  void _removePendingAttachment(
    EmailAttachment attachment,
    Emitter<ChatState> emit,
  ) {
    final updated = List<EmailAttachment>.from(state.pendingAttachments);
    final matchIndex =
        updated.indexWhere((candidate) => identical(candidate, attachment));
    if (matchIndex >= 0) {
      updated.removeAt(matchIndex);
    } else {
      updated.removeWhere(
        (candidate) =>
            candidate.path == attachment.path &&
            candidate.sizeBytes == attachment.sizeBytes,
      );
    }
    emit(state.copyWith(pendingAttachments: updated));
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
