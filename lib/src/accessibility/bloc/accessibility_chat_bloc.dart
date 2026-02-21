// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/accessibility/models/accessibility_action_models.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'accessibility_chat_event.dart';
part 'accessibility_chat_state.dart';

class AccessibilityChatBloc
    extends Bloc<AccessibilityChatEvent, AccessibilityChatState> {
  AccessibilityChatBloc({
    required String jid,
    required MessageService messageService,
    required List<AccessibilityContact> contacts,
    required String? myJid,
    required int initialUnreadCount,
    required int? draftId,
    EmailService? emailService,
  }) : _jid = jid,
       _messageService = messageService,
       _emailService = emailService,
       _contacts = contacts,
       _myJid = myJid,
       _log = Logger('AccessibilityChatBloc'),
       super(AccessibilityChatState.initial(jid: jid, draftId: draftId)) {
    on<AccessibilityChatContactsUpdated>(_onContactsUpdated);
    on<AccessibilityChatUnreadUpdated>(_onUnreadUpdated);
    on<AccessibilityChatDraftIdUpdated>(_onDraftIdUpdated);
    on<AccessibilityChatMessagesUpdated>(_onMessagesUpdated);
    on<AccessibilityChatSendRequested>(_onSendRequested);
    on<AccessibilityChatSaveDraftRequested>(_onSaveDraftRequested);

    _startMessageStreamInternal(initialUnreadCount);
  }

  final String _jid;
  final MessageService _messageService;
  EmailService? _emailService;
  final Logger _log;

  List<AccessibilityContact> _contacts;
  String? _myJid;

  StreamSubscription<List<Message>>? _messageSubscription;
  int _messageStreamLimit = 0;

  void updateEmailService(EmailService? emailService) {
    if (identical(_emailService, emailService)) {
      return;
    }
    _emailService = emailService;
  }

  @override
  Future<void> close() async {
    await _messageSubscription?.cancel();
    return super.close();
  }

  void _onContactsUpdated(
    AccessibilityChatContactsUpdated event,
    Emitter<AccessibilityChatState> emit,
  ) {
    _contacts = event.contacts;
    _myJid = event.myJid;
  }

  Future<void> _onUnreadUpdated(
    AccessibilityChatUnreadUpdated event,
    Emitter<AccessibilityChatState> emit,
  ) async {
    final desiredLimit = _messageWindowForUnread(event.unreadCount);
    if (desiredLimit > _messageStreamLimit) {
      await _startMessageStream(event.unreadCount);
    }
  }

  void _onDraftIdUpdated(
    AccessibilityChatDraftIdUpdated event,
    Emitter<AccessibilityChatState> emit,
  ) {
    if (state.draftId == event.draftId) return;
    emit(state.copyWith(draftId: event.draftId));
  }

  Future<void> _onSendRequested(
    AccessibilityChatSendRequested event,
    Emitter<AccessibilityChatState> emit,
  ) async {
    final trimmedMessage = event.body.trim();
    final recipients = event.recipients;
    if (trimmedMessage.isEmpty || recipients.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: const AccessibilityChatErrorMissingContent(),
        ),
      );
      return;
    }
    emit(state.copyWith(busy: true, statusMessage: null, errorMessage: null));
    final failures = <String>[];
    for (final contact in recipients) {
      if (_shouldSendEmail(contact)) {
        final emailService = _emailService;
        if (emailService == null) {
          _log.warning(
            'Email service unavailable; cannot send to foreign domain '
            '${contact.jid}',
          );
          failures.add(contact.displayName);
          continue;
        }
        try {
          await emailService.sendToAddress(
            address: contact.jid,
            displayName: contact.displayName == contact.jid
                ? null
                : contact.displayName,
            body: trimmedMessage,
          );
          continue;
        } on DeltaChatException catch (error, stackTrace) {
          _log.warning(
            'Failed to send accessibility email to ${contact.jid}',
            error,
            stackTrace,
          );
        } on Exception catch (error, stackTrace) {
          _log.warning(
            'Unexpected error sending accessibility email to ${contact.jid}',
            error,
            stackTrace,
          );
        }
        failures.add(contact.displayName);
        continue;
      }
      try {
        await _messageService.sendMessage(
          jid: contact.jid,
          text: trimmedMessage,
          encryptionProtocol: contact.encryptionProtocol,
          chatType: contact.chatType,
        );
      } on XmppException catch (error, stackTrace) {
        _log.warning(
          'Failed to send accessibility message to ${contact.jid}',
          error,
          stackTrace,
        );
        failures.add(contact.displayName);
      } on Exception catch (error, stackTrace) {
        _log.warning(
          'Unexpected error sending accessibility message to ${contact.jid}',
          error,
          stackTrace,
        );
        failures.add(contact.displayName);
      }
    }
    final failureCount = failures.length;
    final failureLabel = failureCount == 0
        ? null
        : AccessibilityChatErrorSendFailures(
            failureCount: failureCount,
            failures: failures,
          );
    emit(
      state.copyWith(
        busy: false,
        statusMessage: failures.isEmpty
            ? const AccessibilityChatStatusMessageSent()
            : null,
        errorMessage: failureLabel,
        sendCount: failures.isEmpty ? state.sendCount + 1 : state.sendCount,
      ),
    );
  }

  Future<void> _onSaveDraftRequested(
    AccessibilityChatSaveDraftRequested event,
    Emitter<AccessibilityChatState> emit,
  ) async {
    if (event.recipients.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: const AccessibilityChatErrorMissingContent(),
        ),
      );
      return;
    }
    emit(state.copyWith(busy: true, statusMessage: null, errorMessage: null));
    try {
      final result = await _messageService.saveDraft(
        id: event.draftId,
        jids: event.recipients.map((recipient) => recipient.jid).toList(),
        body: event.body,
      );
      emit(
        state.copyWith(
          busy: false,
          draftId: result.draftId,
          statusMessage: const AccessibilityChatStatusDraftSaved(),
          errorMessage: null,
          draftSaveCount: state.draftSaveCount + 1,
        ),
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Failed to save draft from accessibility modal',
        error,
        stackTrace,
      );
      emit(
        state.copyWith(
          busy: false,
          errorMessage: const AccessibilityChatErrorMissingContent(),
        ),
      );
    }
  }

  Future<void> _startMessageStream(int unreadCount) async {
    await _clearMessageStream();
    _startMessageStreamInternal(unreadCount);
  }

  void _startMessageStreamInternal(int unreadCount) {
    final messagePageSize = _messageWindowForUnread(unreadCount);
    _messageStreamLimit = messagePageSize;
    _messageSubscription = _messageService
        .messageStreamForChat(_jid, end: messagePageSize)
        .listen(
          (messages) => add(
            AccessibilityChatMessagesUpdated(jid: _jid, messages: messages),
          ),
          onError: (error, stackTrace) {
            _log.safeWarning(
              'Message stream error for $_jid',
              error,
              stackTrace,
            );
          },
        );
  }

  Future<void> _clearMessageStream() async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
  }

  Future<void> _onMessagesUpdated(
    AccessibilityChatMessagesUpdated event,
    Emitter<AccessibilityChatState> emit,
  ) async {
    if (_jid != event.jid) return;
    final previousIds = state.messages
        .map((message) => _messageId(message))
        .toSet();
    final ordered = List<Message>.of(event.messages)
      ..sort(
        (a, b) => (a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
    final attachments = await _loadAttachments(ordered);
    final newMessages = ordered
        .where((message) => !previousIds.contains(_messageId(message)))
        .toList();
    final latest = newMessages.isNotEmpty ? newMessages.last : null;
    final incomingStatus = latest == null
        ? null
        : AccessibilityChatStatusIncomingMessage(
            senderJid: _senderJidFor(latest),
            senderDisplayName: _senderDisplayNameFor(latest),
            isSelf: _isFromSelf(latest),
            timestamp: latest.timestamp,
          );
    emit(
      state.copyWith(
        messages: ordered,
        attachments: attachments,
        statusMessage: incomingStatus ?? state.statusMessage,
      ),
    );
  }

  Future<Map<String, List<FileMetadataData>>> _loadAttachments(
    List<Message> messages,
  ) async {
    if (messages.isEmpty) {
      return const <String, List<FileMetadataData>>{};
    }
    try {
      final db = await _messageService.database;
      final messageIds = <String>[];
      final messageKeys = <String, String>{};
      for (final message in messages) {
        final messageId = message.id;
        if (messageId == null || messageId.isEmpty) {
          continue;
        }
        messageIds.add(messageId);
        messageKeys[messageId] = _messageId(message);
      }
      final metadataCache = <String, FileMetadataData?>{};
      Future<FileMetadataData?> resolveMetadata(String metadataId) async {
        if (metadataCache.containsKey(metadataId)) {
          return metadataCache[metadataId];
        }
        final resolved = await db.getFileMetadata(metadataId);
        metadataCache[metadataId] = resolved;
        return resolved;
      }

      final attachmentsByMessage = <String, List<FileMetadataData>>{};
      if (messageIds.isNotEmpty) {
        final attachments = await db.getMessageAttachmentsForMessages(
          messageIds,
        );
        for (final entry in attachments.entries) {
          final ordered = entry.value.whereType<MessageAttachmentData>().toList(
            growable: false,
          )..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final resolved = <FileMetadataData>[];
          for (final attachment in ordered) {
            final metadata = await resolveMetadata(attachment.fileMetadataId);
            if (metadata != null) {
              resolved.add(metadata);
            }
          }
          if (resolved.isEmpty) {
            continue;
          }
          final key = messageKeys[entry.key] ?? entry.key;
          attachmentsByMessage[key] = resolved;
        }
      }

      for (final message in messages) {
        final key = _messageId(message);
        if (attachmentsByMessage.containsKey(key)) {
          continue;
        }
        final fallbackId = message.fileMetadataID?.trim();
        if (fallbackId == null || fallbackId.isEmpty) {
          continue;
        }
        final metadata = await resolveMetadata(fallbackId);
        if (metadata != null) {
          attachmentsByMessage[key] = [metadata];
        }
      }
      return attachmentsByMessage;
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to load attachment metadata', error, stackTrace);
      return const <String, List<FileMetadataData>>{};
    }
  }

  bool _shouldSendEmail(AccessibilityContact contact) {
    if (contact.chatType != ChatType.chat) {
      return false;
    }
    final messageService = _messageService;
    if (messageService is! XmppService) return true;
    return contact.transport.isEmail;
  }

  int _messageWindowForUnread(int unreadCount) {
    const basePageSize = 50;
    return unreadCount > basePageSize ? unreadCount : basePageSize;
  }

  bool _isFromSelf(Message message) {
    final senderBare = bareAddress(message.senderJid) ?? message.senderJid;
    final myJid = _myJid;
    if (myJid == null) return false;
    return sameBareAddress(senderBare, myJid);
  }

  String _senderJidFor(Message message) {
    return bareAddress(message.senderJid) ?? message.senderJid;
  }

  String _senderDisplayNameFor(Message message) {
    final senderBare = bareAddress(message.senderJid) ?? message.senderJid;
    final matching = _contacts.firstWhere(
      (contact) => sameBareAddress(contact.jid, senderBare),
      orElse: () => AccessibilityContact(
        jid: senderBare,
        displayName: senderBare,
        subtitle: senderBare,
        source: AccessibilityContactSource.chat,
        encryptionProtocol: message.encryptionProtocol,
        chatType: ChatType.chat,
        unreadCount: 0,
        transport: MessageTransport.xmpp,
      ),
    );
    return matching.displayName;
  }

  String _messageId(Message message) => message.id ?? message.stanzaID;
}
