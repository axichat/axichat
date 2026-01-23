// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/accessibility/models/accessibility_action_models.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/common/ui/jid_input.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

part 'accessibility_action_event.dart';
part 'accessibility_action_state.dart';

class AccessibilityActionBloc
    extends Bloc<AccessibilityActionEvent, AccessibilityActionState> {
  AccessibilityActionBloc({
    required ChatsService chatsService,
    required MessageService messageService,
    required AppLocalizations initialLocalization,
    EmailService? emailService,
    RosterService? rosterService,
  })  : _chatsService = chatsService,
        _messageService = messageService,
        _emailService = emailService,
        _rosterService = rosterService,
        _log = Logger('AccessibilityActionBloc'),
        _l10n = initialLocalization,
        super(const AccessibilityActionState.initial()) {
    on<AccessibilityMenuOpened>(_onMenuOpened);
    on<AccessibilityMenuClosed>(_onMenuClosed);
    on<AccessibilityMenuBack>(_onMenuBack);
    on<AccessibilityMenuReset>(_onMenuReset);
    on<AccessibilityMenuActionTriggered>(_onMenuActionTriggered);
    on<AccessibilityComposerChanged>(_onComposerChanged);
    on<AccessibilitySendMessageRequested>(_onSendMessageRequested);
    on<AccessibilityRecipientRemoved>(_onRecipientRemoved);
    on<AccessibilityNewContactChanged>(_onNewContactChanged);
    on<AccessibilityConfirmNewContact>(_onConfirmNewContact);
    on<AccessibilityDiscardWarningRequested>(_onDiscardWarningRequested);
    on<AccessibilityMenuJumpedTo>(_onMenuJumpedTo);
    on<AccessibilityDataUpdated>(_onDataUpdated);
    on<AccessibilityLocaleUpdated>(_onLocaleUpdated);
    on<AccessibilityMessagesUpdated>(_onMessagesUpdated);

    _chatSubscription = _chatsService.chatsStream().listen(
          (items) => add(AccessibilityDataUpdated(chats: items)),
        );
    _draftSubscription = _messageService.draftsStream().listen(
          (items) => add(AccessibilityDataUpdated(drafts: items)),
        );
    final rosterService = _rosterService;
    if (rosterService != null) {
      _rosterSubscription = rosterService.rosterStream().listen(
            (items) => add(AccessibilityDataUpdated(roster: items)),
          );
      _inviteSubscription = rosterService.invitesStream().listen(
            (items) => add(AccessibilityDataUpdated(invites: items)),
          );
    }
  }

  final ChatsService _chatsService;
  final MessageService _messageService;
  final EmailService? _emailService;
  final RosterService? _rosterService;
  final Logger _log;

  late AppLocalizations _l10n;

  late final StreamSubscription<List<Chat>> _chatSubscription;
  StreamSubscription<List<RosterItem>>? _rosterSubscription;
  StreamSubscription<List<Invite>>? _inviteSubscription;
  StreamSubscription<List<Message>>? _messageSubscription;
  StreamSubscription<List<Draft>>? _draftSubscription;
  int _messageStreamLimit = 0;

  List<Chat> _chats = const [];
  List<RosterItem> _roster = const [];
  List<Invite> _invites = const [];
  List<Draft> _drafts = const [];
  List<AccessibilityContact> _contacts = const [];

  @override
  Future<void> close() async {
    await _chatSubscription.cancel();
    await _rosterSubscription?.cancel();
    await _inviteSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _draftSubscription?.cancel();
    return super.close();
  }

  void _onMenuOpened(
    AccessibilityMenuOpened event,
    Emitter<AccessibilityActionState> emit,
  ) {
    final nextState = state.copyWith(
      visible: true,
      statusMessage: null,
      errorMessage: null,
      discardWarningActive: false,
    );
    emit(nextState);
  }

  Future<void> _onMenuClosed(
    AccessibilityMenuClosed event,
    Emitter<AccessibilityActionState> emit,
  ) async {
    await _clearMessageStream();
    final nextState = state.copyWith(
      visible: false,
      stack: const [AccessibilityStepEntry(kind: AccessibilityStepKind.root)],
      composerText: '',
      newContactInput: '',
      statusMessage: null,
      errorMessage: null,
      messages: const [],
      activeChatJid: null,
      discardWarningActive: false,
      recipients: const [],
      attachments: const <String, List<FileMetadataData>>{},
    );
    emit(nextState);
  }

  Future<void> _onMenuBack(
    AccessibilityMenuBack event,
    Emitter<AccessibilityActionState> emit,
  ) async {
    if (state.stack.length <= 1) {
      emit(
        state.copyWith(
          visible: false,
          composerText: '',
          newContactInput: '',
          statusMessage: null,
          errorMessage: null,
          recipients: const [],
          messages: const [],
          activeChatJid: null,
          discardWarningActive: false,
        ),
      );
      return;
    }
    final nextStack = List<AccessibilityStepEntry>.of(state.stack)
      ..removeLast();
    final keepChatMessages = nextStack.isNotEmpty &&
        (nextStack.last.kind == AccessibilityStepKind.chatMessages ||
            nextStack.last.kind == AccessibilityStepKind.composer ||
            nextStack.last.kind == AccessibilityStepKind.conversation);
    if (!keepChatMessages) {
      await _clearMessageStream();
    }
    final nextState = state.copyWith(
      stack: nextStack,
      statusMessage: null,
      errorMessage: null,
      messages: keepChatMessages ? state.messages : const [],
      activeChatJid: keepChatMessages ? state.activeChatJid : null,
      composerText: '',
      newContactInput: '',
      recipients: nextStack.last.recipients,
      discardWarningActive: false,
      attachments: keepChatMessages
          ? state.attachments
          : const <String, List<FileMetadataData>>{},
    );
    emit(nextState);
  }

  Future<void> _onMenuReset(
    AccessibilityMenuReset event,
    Emitter<AccessibilityActionState> emit,
  ) async {
    await _clearMessageStream();
    final nextState = state.copyWith(
      stack: const [AccessibilityStepEntry(kind: AccessibilityStepKind.root)],
      composerText: '',
      newContactInput: '',
      statusMessage: null,
      errorMessage: null,
      messages: const [],
      activeChatJid: null,
      discardWarningActive: false,
      recipients: const [],
      attachments: const <String, List<FileMetadataData>>{},
    );
    emit(nextState);
  }

  void _onDiscardWarningRequested(
    AccessibilityDiscardWarningRequested event,
    Emitter<AccessibilityActionState> emit,
  ) {
    if (!_hasUnsavedInput(state) || state.discardWarningActive) {
      return;
    }
    emit(
      state.copyWith(
        discardWarningActive: true,
        statusMessage: _l10n.accessibilityDiscardWarning,
        errorMessage: null,
      ),
    );
  }

  Future<void> _onMenuJumpedTo(
    AccessibilityMenuJumpedTo event,
    Emitter<AccessibilityActionState> emit,
  ) async {
    if (event.index < 0 || event.index >= state.stack.length) return;
    final nextStack = state.stack.take(event.index + 1).toList();
    final keepChatMessages = nextStack.isNotEmpty &&
        (nextStack.last.kind == AccessibilityStepKind.chatMessages ||
            nextStack.last.kind == AccessibilityStepKind.conversation ||
            nextStack.last.kind == AccessibilityStepKind.composer);
    if (!keepChatMessages) {
      await _clearMessageStream();
    }
    emit(
      state.copyWith(
        stack: nextStack,
        statusMessage: null,
        errorMessage: null,
        messages: keepChatMessages ? state.messages : const [],
        activeChatJid: keepChatMessages ? state.activeChatJid : null,
        recipients: nextStack.last.recipients,
        discardWarningActive: false,
        attachments: keepChatMessages
            ? state.attachments
            : const <String, List<FileMetadataData>>{},
      ),
    );
  }

  Future<void> _onMenuActionTriggered(
    AccessibilityMenuActionTriggered event,
    Emitter<AccessibilityActionState> emit,
  ) async {
    final action = event.action;
    if (action is AccessibilityNoopAction) {
      return;
    }
    if (action is AccessibilityNavigateAction) {
      await _handleNavigateAction(action, emit);
      return;
    }
    if (action is AccessibilityCommandAction) {
      await _handleCommandAction(action, emit);
      return;
    }
    if (action is AccessibilitySelectContactAction) {
      await _handleContactSelection(action.contact, emit);
      return;
    }
    if (action is AccessibilityInviteDecisionAction) {
      _handleInviteDecision(action, emit);
      return;
    }
    if (action is AccessibilityDismissHighlightAction) {
      _handleDismissHighlight(action.highlightId, emit);
    }
  }

  void _onComposerChanged(
    AccessibilityComposerChanged event,
    Emitter<AccessibilityActionState> emit,
  ) {
    final nextState = state.copyWith(composerText: event.value);
    emit(nextState.copyWith(discardWarningActive: false));
  }

  Future<void> _onSendMessageRequested(
    AccessibilitySendMessageRequested event,
    Emitter<AccessibilityActionState> emit,
  ) async {
    final currentEntry = state.stack.last;
    final trimmedMessage = state.composerText.trim();
    if ((currentEntry.kind != AccessibilityStepKind.composer &&
            currentEntry.kind != AccessibilityStepKind.chatMessages &&
            currentEntry.kind != AccessibilityStepKind.conversation) ||
        trimmedMessage.isEmpty ||
        currentEntry.recipients.isEmpty) {
      emit(state.copyWith(errorMessage: _l10n.chatDraftMissingContent));
      return;
    }
    emit(
      state.copyWith(
        busy: true,
        statusMessage: null,
        errorMessage: null,
        discardWarningActive: false,
      ),
    );
    final failures = <String>[];
    for (final contact in currentEntry.recipients) {
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
            displayName:
                contact.displayName == contact.jid ? null : contact.displayName,
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
    final recipientLabel = _l10n.chatFanOutRecipientLabel(failureCount);
    final failureLabel = failureCount == 0
        ? null
        : '${_l10n.chatFanOutFailure(failureCount, recipientLabel)}: '
            '${failures.join(', ')}';
    emit(
      state.copyWith(
        busy: false,
        composerText: failures.isEmpty ? '' : state.composerText,
        statusMessage: failures.isEmpty ? _l10n.accessibilityMessageSent : null,
        errorMessage: failureLabel,
        discardWarningActive: false,
      ),
    );
  }

  bool _shouldSendEmail(AccessibilityContact contact) {
    if (contact.chatType != ChatType.chat) {
      return false;
    }
    final messageService = _messageService;
    if (messageService is! XmppService) return true;
    final myJid = messageService.myJid;
    // If we don't know our JID, default to XMPP to avoid bogus email routing.
    if (myJid == null) return false;
    try {
      final mine = mox.JID.fromString(myJid);
      final target = mox.JID.fromString(contact.jid);
      final myDomain = mine.domain.toLowerCase();
      final targetDomain = target.domain.toLowerCase();
      // Never email local/first-party domains.
      if (targetDomain == myDomain ||
          targetDomain.endsWith('.$myDomain') ||
          targetDomain == 'axi.im' ||
          targetDomain.endsWith('.axi.im')) {
        return false;
      }
      return true;
    } on Exception {
      // If parsing fails, stick with XMPP to avoid bad fallback addresses.
      return false;
    }
  }

  Future<void> _onRecipientRemoved(
    AccessibilityRecipientRemoved event,
    Emitter<AccessibilityActionState> emit,
  ) async {
    if (state.stack.length <= 1) return;
    final nextStack = List<AccessibilityStepEntry>.of(state.stack);
    final index = nextStack.lastIndexWhere(
      (entry) =>
          entry.kind == AccessibilityStepKind.composer ||
          entry.kind == AccessibilityStepKind.chatMessages ||
          entry.kind == AccessibilityStepKind.conversation,
    );
    if (index == -1) return;
    final entry = nextStack[index];
    final filtered = entry.recipients
        .where((recipient) => recipient.jid != event.jid)
        .toList();
    if (filtered.isEmpty) {
      await _clearMessageStream();
    }
    nextStack[index] = entry.copyWith(recipients: filtered);
    emit(
      state.copyWith(
        stack: nextStack,
        activeChatJid: filtered.isEmpty ? null : state.activeChatJid,
        recipients: filtered,
        statusMessage: filtered.isEmpty ? null : state.statusMessage,
      ),
    );
  }

  void _onNewContactChanged(
    AccessibilityNewContactChanged event,
    Emitter<AccessibilityActionState> emit,
  ) {
    emit(
      state.copyWith(
        newContactInput: event.value,
        errorMessage: null,
        discardWarningActive: false,
      ),
    );
  }

  Future<void> _onConfirmNewContact(
    AccessibilityConfirmNewContact event,
    Emitter<AccessibilityActionState> emit,
  ) async {
    final trimmed = state.newContactInput.trim();
    if (!trimmed.isValidJid) {
      emit(state.copyWith(errorMessage: _l10n.jidInputInvalid));
      return;
    }
    final contact = AccessibilityContact(
      jid: trimmed,
      displayName: trimmed,
      subtitle: _l10n.chatsFilterNonContacts,
      source: AccessibilityContactSource.manual,
      encryptionProtocol: EncryptionProtocol.omemo,
      chatType: ChatType.chat,
      unreadCount: 0,
    );
    await _handleContactSelection(contact, emit);
  }

  void _onLocaleUpdated(
    AccessibilityLocaleUpdated event,
    Emitter<AccessibilityActionState> emit,
  ) {
    if (_l10n.localeName == event.localization.localeName) return;
    _l10n = event.localization;
  }

  Future<void> _onDataUpdated(
    AccessibilityDataUpdated event,
    Emitter<AccessibilityActionState> emit,
  ) async {
    if (event.chats != null) {
      _chats = event.chats!;
    }
    if (event.roster != null) {
      _roster = event.roster!;
    }
    if (event.invites != null) {
      _invites = event.invites!;
    }
    if (event.drafts != null) {
      _drafts = event.drafts!;
    }
    _refreshContacts();
    final dismissedHighlights =
        _purgeDismissedHighlights(state.dismissedHighlights);
    var nextState = state.copyWith(
      contacts: _contacts,
      invites: _invites,
      drafts: _drafts,
      myJid: _chatsService.myJid,
      dismissedHighlights: dismissedHighlights,
    );
    nextState = _syncActiveChatRecipient(nextState);
    final activeJid = nextState.activeChatJid;
    if (activeJid != null) {
      final unreadCount = _unreadCountFor(activeJid);
      final desiredLimit = _messageWindowForUnread(unreadCount);
      if (desiredLimit > _messageStreamLimit) {
        await _startMessageStream(activeJid);
      }
    }
    if (nextState != state) {
      emit(nextState);
    }
  }

  void _refreshContacts() {
    final map = <String, AccessibilityContact>{};
    final orderedChats = <AccessibilityContact>[];
    for (final chat in _chats) {
      final contact = AccessibilityContact(
        jid: chat.jid,
        displayName: _displayNameForChat(chat),
        subtitle: chat.contactJid ?? chat.jid,
        source: AccessibilityContactSource.chat,
        encryptionProtocol: chat.encryptionProtocol,
        chatType: chat.type,
        unreadCount: chat.unreadCount,
        isGroup: chat.type == ChatType.groupChat,
      );
      orderedChats.add(contact);
      map[chat.jid] = contact;
    }
    final rosterOnly = <AccessibilityContact>[];
    for (final item in _roster) {
      if (map.containsKey(item.jid)) continue;
      rosterOnly.add(
        AccessibilityContact(
          jid: item.jid,
          displayName: item.contactDisplayName ?? item.title,
          subtitle: item.jid,
          source: AccessibilityContactSource.roster,
          encryptionProtocol: EncryptionProtocol.omemo,
          chatType: ChatType.chat,
          unreadCount: 0,
        ),
      );
    }
    rosterOnly.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    _contacts = [...orderedChats, ...rosterOnly];
  }

  Set<String> _purgeDismissedHighlights(Set<String> dismissedHighlights) {
    final pruned = Set<String>.of(dismissedHighlights);
    final validInviteIds = _invites.map((invite) => 'invite-${invite.jid}');
    pruned.removeWhere(
      (id) => id.startsWith('invite-') && !validInviteIds.contains(id),
    );
    final unreadDigests = _unreadDigest();
    pruned.removeWhere(
      (id) =>
          id.startsWith('unread-') &&
          !id.startsWith('unread-summary-') &&
          !unreadDigests.contains(id),
    );
    return pruned;
  }

  bool _hasUnsavedInput(AccessibilityActionState state) {
    final entry = state.currentEntry;
    if (entry.kind == AccessibilityStepKind.composer ||
        entry.kind == AccessibilityStepKind.chatMessages ||
        entry.kind == AccessibilityStepKind.conversation) {
      return state.composerText.trim().isNotEmpty;
    }
    if (entry.kind == AccessibilityStepKind.newContact) {
      return state.newContactInput.trim().isNotEmpty;
    }
    return false;
  }

  int _unreadCountFor(String jid) {
    for (final contact in _contacts) {
      if (contact.jid == jid) {
        return contact.unreadCount;
      }
    }
    return 0;
  }

  int _messageWindowForUnread(int unreadCount) {
    const basePageSize = 50;
    return unreadCount > basePageSize ? unreadCount : basePageSize;
  }

  Set<String> _unreadDigest() {
    final digests = <String>{};
    for (final chat in _chats.where((chat) => chat.unreadCount > 0)) {
      digests.add('unread-${chat.jid}-${chat.unreadCount}');
    }
    return digests;
  }

  Future<void> _handleNavigateAction(
    AccessibilityNavigateAction action,
    Emitter<AccessibilityActionState> emit,
  ) async {
    final leavingChat =
        (state.currentEntry.kind == AccessibilityStepKind.chatMessages ||
                state.currentEntry.kind == AccessibilityStepKind.conversation ||
                state.currentEntry.kind == AccessibilityStepKind.composer) &&
            action.step != AccessibilityStepKind.chatMessages &&
            action.step != AccessibilityStepKind.conversation &&
            action.step != AccessibilityStepKind.composer;
    if (leavingChat) {
      await _clearMessageStream();
    }
    final nextEntry = AccessibilityStepEntry(
      kind: action.step,
      purpose: action.purpose,
      recipients: state.stack.last.recipients,
    );
    final nextStack = List<AccessibilityStepEntry>.of(state.stack)
      ..add(nextEntry);
    emit(
      state.copyWith(
        stack: nextStack,
        statusMessage: null,
        errorMessage: null,
        messages: leavingChat ? const [] : state.messages,
        activeChatJid: leavingChat ? null : state.activeChatJid,
        recipients: nextEntry.recipients,
        discardWarningActive: false,
      ),
    );
  }

  Future<void> _handleCommandAction(
    AccessibilityCommandAction action,
    Emitter<AccessibilityActionState> emit,
  ) async {
    if (state.discardWarningActive) {
      emit(state.copyWith(discardWarningActive: false));
    }
    switch (action.command) {
      case AccessibilityCommand.openChat:
        final contact = action.contact;
        if (contact == null) return;
        await _openChatMessages(contact, emit);
        break;
      case AccessibilityCommand.sendMessage:
        add(const AccessibilitySendMessageRequested());
        break;
      case AccessibilityCommand.addRecipient:
        _enterRecipientPicker(emit);
        break;
      case AccessibilityCommand.backToContacts:
        add(const AccessibilityMenuBack());
        break;
      case AccessibilityCommand.closeMenu:
        add(const AccessibilityMenuClosed());
        break;
      case AccessibilityCommand.confirmNewContact:
        add(const AccessibilityConfirmNewContact());
        break;
      case AccessibilityCommand.saveDraft:
        await _saveDraft(emit);
        break;
      case AccessibilityCommand.resumeDraft:
        final draft = action.draft;
        if (draft == null) return;
        await _openDraftComposer(draft, emit);
        break;
    }
  }

  Future<void> _saveDraft(Emitter<AccessibilityActionState> emit) async {
    final entry = state.currentEntry;
    if (entry.kind != AccessibilityStepKind.composer) return;
    final recipients = entry.recipients;
    final body = state.composerText.trim();
    if (recipients.isEmpty || body.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: _l10n.chatDraftMissingContent,
          discardWarningActive: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        busy: true,
        statusMessage: null,
        errorMessage: null,
        discardWarningActive: false,
      ),
    );
    try {
      final result = await _messageService.saveDraft(
        id: entry.draftId,
        jids: recipients.map((recipient) => recipient.jid).toList(),
        body: body,
      );
      final nextStack = List<AccessibilityStepEntry>.of(state.stack);
      final lastIndex = nextStack.length - 1;
      nextStack[lastIndex] = nextStack[lastIndex].copyWith(
        draftId: result.draftId,
      );
      emit(
        state.copyWith(
          busy: false,
          stack: nextStack,
          statusMessage: _l10n.chatDraftSaved,
          errorMessage: null,
          discardWarningActive: false,
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
          errorMessage: _l10n.chatDraftMissingContent,
          discardWarningActive: false,
        ),
      );
    }
  }

  Future<void> _openDraftComposer(
    Draft draft,
    Emitter<AccessibilityActionState> emit,
  ) async {
    final recipients = draft.jids.map(_contactForJid).toList();
    final activeJid = recipients.isNotEmpty ? recipients.first.jid : null;
    if (activeJid != null) {
      await _startMessageStream(activeJid);
    }
    final nextStack = List<AccessibilityStepEntry>.of(state.stack)
      ..add(
        AccessibilityStepEntry(
          kind: AccessibilityStepKind.composer,
          purpose: AccessibilityFlowPurpose.sendMessage,
          recipients: recipients,
          draftId: draft.id,
        ),
      );
    final nextState = state.copyWith(
      stack: nextStack,
      composerText: draft.body ?? '',
      newContactInput: '',
      activeChatJid: activeJid ?? state.activeChatJid,
      recipients: recipients,
      statusMessage: _l10n.accessibilityDraftLoaded,
      errorMessage: null,
      discardWarningActive: false,
    );
    emit(nextState);
  }

  void _enterRecipientPicker(Emitter<AccessibilityActionState> emit) {
    final nextStack = List<AccessibilityStepEntry>.of(state.stack);
    final composerIndex = nextStack.lastIndexWhere(
      (entry) => entry.kind == AccessibilityStepKind.composer,
    );
    if (composerIndex == -1) return;
    nextStack[composerIndex] = nextStack[composerIndex].copyWith(
      addingRecipient: true,
    );
    nextStack.add(
      AccessibilityStepEntry(
        kind: AccessibilityStepKind.contactPicker,
        purpose: AccessibilityFlowPurpose.sendMessage,
        recipients: nextStack[composerIndex].recipients,
        addingRecipient: true,
      ),
    );
    emit(
      state.copyWith(
        stack: nextStack,
        recipients: nextStack.last.recipients,
        statusMessage: null,
        errorMessage: null,
      ),
    );
  }

  Future<void> _handleContactSelection(
    AccessibilityContact contact,
    Emitter<AccessibilityActionState> emit,
  ) async {
    final stack = List<AccessibilityStepEntry>.of(state.stack);
    if (state.stack.last.kind == AccessibilityStepKind.contactPicker) {
      final entry = state.stack.last;
      if (entry.purpose == AccessibilityFlowPurpose.sendMessage) {
        final recipients = _mergeRecipients(entry.recipients, contact);
        final nextStack = List<AccessibilityStepEntry>.of(state.stack);
        final previousIndex = nextStack.length - 2;
        final activeJid = recipients.first.jid;
        await _startMessageStream(activeJid);
        if (previousIndex >= 0 &&
            nextStack[previousIndex].kind == AccessibilityStepKind.composer) {
          nextStack[previousIndex] = nextStack[previousIndex].copyWith(
            recipients: recipients,
            addingRecipient: false,
          );
          nextStack.removeLast();
        } else {
          nextStack[nextStack.length - 1] = entry.copyWith(
            recipients: recipients,
            addingRecipient: false,
          );
          nextStack.add(
            AccessibilityStepEntry(
              kind: AccessibilityStepKind.composer,
              purpose: AccessibilityFlowPurpose.sendMessage,
              recipients: recipients,
            ),
          );
        }
        final nextState = state.copyWith(
          stack: nextStack,
          activeChatJid: activeJid,
          composerText: state.composerText,
          newContactInput: '',
          recipients: recipients,
          statusMessage: null,
          errorMessage: null,
          discardWarningActive: false,
        );
        emit(nextState);
        return;
      }
      if (entry.purpose == AccessibilityFlowPurpose.openChat) {
        await _openChatMessages(contact, emit);
        return;
      }
    }
    if (stack.last.kind == AccessibilityStepKind.newContact) {
      final recipients = _mergeRecipients(stack.last.recipients, contact);
      final activeJid = recipients.first.jid;
      await _startMessageStream(activeJid);
      final nextStack = stack
        ..removeLast()
        ..add(
          AccessibilityStepEntry(
            kind: AccessibilityStepKind.composer,
            purpose: AccessibilityFlowPurpose.sendMessage,
            recipients: recipients,
          ),
        );
      emit(
        state.copyWith(
          stack: nextStack,
          activeChatJid: activeJid,
          newContactInput: '',
          recipients: recipients,
          statusMessage: null,
          errorMessage: null,
          discardWarningActive: false,
        ),
      );
    }
  }

  List<AccessibilityContact> _mergeRecipients(
    List<AccessibilityContact> recipients,
    AccessibilityContact next,
  ) {
    final existing = Map<String, AccessibilityContact>.fromEntries(
      recipients.map((entry) => MapEntry(entry.jid, entry)),
    );
    existing[next.jid] = next;
    return existing.values.toList();
  }

  AccessibilityContact _contactForJid(String jid) {
    return _contacts.firstWhere(
      (contact) => contact.jid == jid,
      orElse: () => AccessibilityContact(
        jid: jid,
        displayName: jid,
        subtitle: jid,
        source: AccessibilityContactSource.manual,
        encryptionProtocol: EncryptionProtocol.omemo,
        chatType: ChatType.chat,
        unreadCount: 0,
      ),
    );
  }

  void _handleInviteDecision(
    AccessibilityInviteDecisionAction action,
    Emitter<AccessibilityActionState> emit,
  ) async {
    final roster = _rosterService;
    if (roster == null) return;
    emit(state.copyWith(busy: true, statusMessage: null, errorMessage: null));
    try {
      if (action.accept) {
        await roster.addToRoster(
          jid: action.invite.jid,
          title: action.invite.title,
        );
      } else {
        await roster.rejectSubscriptionRequest(action.invite.jid);
      }
      emit(
        state.copyWith(
          busy: false,
          statusMessage: action.accept
              ? _l10n.accessibilityInviteAccepted
              : _l10n.accessibilityInviteDismissed,
        ),
      );
    } on XmppException catch (error, stackTrace) {
      _log.warning('Invite decision failed', error, stackTrace);
      emit(
        state.copyWith(
          busy: false,
          errorMessage: _l10n.accessibilityInviteUpdateFailed,
        ),
      );
    }
  }

  void _handleDismissHighlight(
    String highlightId,
    Emitter<AccessibilityActionState> emit,
  ) {
    final dismissed = Set<String>.of(state.dismissedHighlights)
      ..add(highlightId);
    emit(state.copyWith(dismissedHighlights: dismissed));
  }

  Future<void> _openChatMessages(
    AccessibilityContact contact,
    Emitter<AccessibilityActionState> emit,
  ) async {
    Chat? chat;
    for (final entry in _chats) {
      if (entry.jid == contact.jid) {
        chat = entry;
        break;
      }
    }
    if (chat?.open != true) {
      await _chatsService.openChat(contact.jid);
    }
    final nextStack = List<AccessibilityStepEntry>.of(state.stack);
    final newEntry = AccessibilityStepEntry(
      kind: AccessibilityStepKind.conversation,
      purpose: AccessibilityFlowPurpose.openChat,
      recipients: [contact],
    );
    if (nextStack.isNotEmpty &&
        (nextStack.last.kind == AccessibilityStepKind.chatMessages ||
            nextStack.last.kind == AccessibilityStepKind.conversation ||
            nextStack.last.kind == AccessibilityStepKind.composer)) {
      nextStack[nextStack.length - 1] = nextStack.last.copyWith(
        recipients: [contact],
      );
    } else {
      nextStack.add(newEntry);
    }
    await _startMessageStream(contact.jid);
    final nextState = state.copyWith(
      visible: true,
      stack: nextStack,
      recipients: [contact],
      activeChatJid: contact.jid,
      messages: const [],
      attachments: const <String, List<FileMetadataData>>{},
      statusMessage: null,
      errorMessage: null,
      discardWarningActive: false,
    );
    emit(nextState);
  }

  Future<void> _startMessageStream(String jid) async {
    await _clearMessageStream();
    final messagePageSize = _messageWindowForUnread(_unreadCountFor(jid));
    _messageStreamLimit = messagePageSize;
    _messageSubscription =
        _messageService.messageStreamForChat(jid, end: messagePageSize).listen(
      (messages) =>
          add(AccessibilityMessagesUpdated(jid: jid, messages: messages)),
      onError: (error, stackTrace) {
        _log.safeWarning(
          'Message stream error for $jid',
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
    AccessibilityMessagesUpdated event,
    Emitter<AccessibilityActionState> emit,
  ) async {
    if (state.activeChatJid != event.jid) return;
    final previousIds =
        state.messages.map((message) => _messageId(message)).toSet();
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
        : _l10n.accessibilityIncomingMessageStatus(
            _senderLabelFor(latest),
            _formatTimestamp(latest.timestamp),
          );
    final nextState = state.copyWith(
      messages: ordered,
      attachments: attachments,
      statusMessage: incomingStatus ?? state.statusMessage,
    );
    emit(nextState);
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

  AccessibilityActionState _syncActiveChatRecipient(
    AccessibilityActionState baseState,
  ) {
    final active = baseState.activeChatJid;
    if (active == null) return baseState;
    final contact = _contactFor(active);
    var stackChanged = false;
    final nextStack = <AccessibilityStepEntry>[];
    for (final entry in baseState.stack) {
      final isChatView = entry.kind == AccessibilityStepKind.chatMessages ||
          entry.kind == AccessibilityStepKind.conversation;
      if (isChatView &&
          (entry.recipients.length != 1 || entry.recipients.first != contact)) {
        nextStack.add(entry.copyWith(recipients: [contact]));
        stackChanged = true;
      } else {
        nextStack.add(entry);
      }
    }
    final currentEntry = baseState.currentEntry;
    final shouldSyncRecipients =
        currentEntry.kind == AccessibilityStepKind.chatMessages ||
            currentEntry.kind == AccessibilityStepKind.conversation;
    if (stackChanged ||
        (shouldSyncRecipients &&
            (baseState.recipients.length != 1 ||
                baseState.recipients.first != contact))) {
      return baseState.copyWith(
        stack: nextStack,
        recipients: shouldSyncRecipients ? [contact] : baseState.recipients,
      );
    }
    return baseState;
  }

  AccessibilityContact _contactFor(String? jid) {
    final fallbackJid = jid ?? 'unknown';
    final fallbackName = jid ?? _l10n.accessibilityUnknownContact;
    return _contacts.firstWhere(
      (contact) => contact.jid == fallbackJid,
      orElse: () => AccessibilityContact(
        jid: fallbackJid,
        displayName: fallbackName,
        subtitle: fallbackName,
        source: AccessibilityContactSource.chat,
        encryptionProtocol: EncryptionProtocol.none,
        chatType: ChatType.chat,
        unreadCount: 0,
      ),
    );
  }

  String _senderLabelFor(Message message) {
    final senderBare = message.senderJid.split('/').first;
    final myJid = _chatsService.myJid;
    if (myJid != null && senderBare == myJid) {
      return _l10n.chatSenderYou;
    }
    final matching = _contacts.firstWhere(
      (contact) => contact.jid == senderBare,
      orElse: () => AccessibilityContact(
        jid: senderBare,
        displayName: senderBare,
        subtitle: senderBare,
        source: AccessibilityContactSource.chat,
        encryptionProtocol: message.encryptionProtocol,
        chatType: ChatType.chat,
        unreadCount: 0,
      ),
    );
    return matching.displayName;
  }

  String _formatTimestamp(DateTime? timestamp) {
    final safe = timestamp ?? DateTime.now();
    return DateFormat.yMMMd(_l10n.localeName).add_jm().format(safe);
  }

  String _messageId(Message message) => message.id ?? message.stanzaID;

  String _displayNameForChat(Chat chat) {
    final preferred = chat.contactDisplayName?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      return preferred;
    }
    final title = chat.title.trim();
    return title.isEmpty ? chat.jid : chat.title;
  }
}
