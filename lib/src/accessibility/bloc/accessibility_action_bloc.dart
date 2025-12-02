import 'dart:async';

import 'package:axichat/src/accessibility/models/accessibility_action_models.dart';
import 'package:axichat/src/common/ui/jid_input.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

part 'accessibility_action_event.dart';
part 'accessibility_action_state.dart';

class _SectionWithInitial {
  const _SectionWithInitial({
    required this.section,
    this.initialIndex,
  });

  final AccessibilityMenuSection section;
  final int? initialIndex;
}

class _ConversationSectionsResult {
  const _ConversationSectionsResult({
    required this.sections,
    this.initialMessageIndex,
  });

  final List<AccessibilityMenuSection> sections;
  final int? initialMessageIndex;
}

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
  static const int _messagePageSize = 50;

  late AppLocalizations _l10n;

  late final StreamSubscription<List<Chat>> _chatSubscription;
  StreamSubscription<List<RosterItem>>? _rosterSubscription;
  StreamSubscription<List<Invite>>? _inviteSubscription;
  StreamSubscription<List<Message>>? _messageSubscription;
  StreamSubscription<List<Draft>>? _draftSubscription;

  List<Chat> _chats = const [];
  List<RosterItem> _roster = const [];
  List<Invite> _invites = const [];
  List<Draft> _drafts = const [];
  List<AccessibilityContact> _contacts = const [];
  final Set<String> _dismissedHighlights = <String>{};

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
    _rebuildSections(emit, nextState);
  }

  void _onMenuClosed(
    AccessibilityMenuClosed event,
    Emitter<AccessibilityActionState> emit,
  ) {
    _clearMessageStream();
    final nextState = state.copyWith(
      visible: false,
      stack: const [
        AccessibilityStepEntry(kind: AccessibilityStepKind.root),
      ],
      composerText: '',
      newContactInput: '',
      statusMessage: null,
      errorMessage: null,
      messages: const [],
      activeChatJid: null,
      discardWarningActive: false,
      recipients: const [],
      attachments: const {},
    );
    emit(nextState);
    _rebuildSections(emit, nextState);
  }

  void _onMenuBack(
    AccessibilityMenuBack event,
    Emitter<AccessibilityActionState> emit,
  ) {
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
      _clearMessageStream();
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
      attachments: keepChatMessages ? state.attachments : const {},
    );
    emit(nextState);
    _rebuildSections(emit, nextState);
  }

  void _onMenuReset(
    AccessibilityMenuReset event,
    Emitter<AccessibilityActionState> emit,
  ) {
    _clearMessageStream();
    final nextState = state.copyWith(
      stack: const [
        AccessibilityStepEntry(kind: AccessibilityStepKind.root),
      ],
      composerText: '',
      newContactInput: '',
      statusMessage: null,
      errorMessage: null,
      messages: const [],
      activeChatJid: null,
      discardWarningActive: false,
      recipients: const [],
      attachments: const {},
    );
    emit(nextState);
    _rebuildSections(emit, nextState);
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
        statusMessage:
            'Press Escape again to discard your message and close this step.',
        errorMessage: null,
      ),
    );
  }

  void _onMenuJumpedTo(
    AccessibilityMenuJumpedTo event,
    Emitter<AccessibilityActionState> emit,
  ) {
    if (event.index < 0 || event.index >= state.stack.length) return;
    final nextStack = state.stack.take(event.index + 1).toList();
    final keepChatMessages = nextStack.isNotEmpty &&
        (nextStack.last.kind == AccessibilityStepKind.chatMessages ||
            nextStack.last.kind == AccessibilityStepKind.conversation ||
            nextStack.last.kind == AccessibilityStepKind.composer);
    if (!keepChatMessages) {
      _clearMessageStream();
    }
    emit(
      state.copyWith(
        stack: nextStack,
        statusMessage: null,
        errorMessage: null,
        messages: keepChatMessages ? state.messages : const [],
        activeChatJid: keepChatMessages ? state.activeChatJid : null,
        discardWarningActive: false,
      ),
    );
    _rebuildSections(emit, state);
  }

  void _onMenuActionTriggered(
    AccessibilityMenuActionTriggered event,
    Emitter<AccessibilityActionState> emit,
  ) {
    final action = event.action;
    if (action is AccessibilityNoopAction) {
      return;
    }
    if (action is AccessibilityNavigateAction) {
      _handleNavigateAction(action, emit);
      return;
    }
    if (action is AccessibilityCommandAction) {
      _handleCommandAction(action, emit);
      return;
    }
    if (action is AccessibilitySelectContactAction) {
      _handleContactSelection(action.contact, emit);
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
    _rebuildSections(emit, nextState);
  }

  Future<void> _onSendMessageRequested(
    AccessibilitySendMessageRequested event,
    Emitter<AccessibilityActionState> emit,
  ) async {
    final currentEntry = state.stack.last;
    final trimmedMessage = state.composerText.trim();
    final isConversation =
        currentEntry.kind == AccessibilityStepKind.composer ||
            currentEntry.kind == AccessibilityStepKind.chatMessages ||
            currentEntry.kind == AccessibilityStepKind.conversation;
    if (!isConversation ||
        trimmedMessage.isEmpty ||
        currentEntry.recipients.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: _l10n.chatDraftMissingContent,
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
        statusMessage: failures.isEmpty ? 'Message sent.' : null,
        errorMessage: failureLabel,
        discardWarningActive: false,
      ),
    );
    _rebuildSections(emit, state);
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

  void _onRecipientRemoved(
    AccessibilityRecipientRemoved event,
    Emitter<AccessibilityActionState> emit,
  ) {
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
      _clearMessageStream();
    }
    nextStack[index] = entry.copyWith(recipients: filtered);
    emit(
      state.copyWith(
        stack: nextStack,
        activeChatJid: filtered.isEmpty ? null : state.activeChatJid,
        statusMessage: filtered.isEmpty ? null : state.statusMessage,
      ),
    );
    _rebuildSections(emit, state);
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
    _rebuildSections(emit, state);
  }

  void _onConfirmNewContact(
    AccessibilityConfirmNewContact event,
    Emitter<AccessibilityActionState> emit,
  ) {
    final trimmed = state.newContactInput.trim();
    if (!trimmed.isValidJid) {
      emit(
        state.copyWith(
          errorMessage: _textInvalidAddress,
        ),
      );
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
    _handleContactSelection(contact, emit);
  }

  void _onLocaleUpdated(
    AccessibilityLocaleUpdated event,
    Emitter<AccessibilityActionState> emit,
  ) {
    if (_l10n.localeName == event.localization.localeName) return;
    _l10n = event.localization;
    _rebuildSections(emit, state);
  }

  void _onDataUpdated(
    AccessibilityDataUpdated event,
    Emitter<AccessibilityActionState> emit,
  ) {
    if (event.chats != null) {
      _chats = event.chats!;
    }
    if (event.roster != null) {
      _roster = event.roster!;
    }
    if (event.invites != null) {
      _invites = event.invites!;
      _purgeDismissedHighlights();
    }
    if (event.drafts != null) {
      _drafts = event.drafts!;
    }
    _refreshContacts();
    _syncActiveChatRecipient(emit);
    _rebuildSections(emit, state);
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
      (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
    );
    _contacts = [...orderedChats, ...rosterOnly];
  }

  void _purgeDismissedHighlights() {
    final validInviteIds = _invites.map((invite) => 'invite-${invite.jid}');
    _dismissedHighlights.removeWhere(
      (id) => id.startsWith('invite-') && !validInviteIds.contains(id),
    );
    final unreadDigests = _unreadDigest();
    _dismissedHighlights.removeWhere(
      (id) =>
          id.startsWith('unread-') &&
          !id.startsWith('unread-summary-') &&
          !unreadDigests.contains(id),
    );
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

  Set<String> _unreadDigest() {
    final digests = <String>{};
    for (final chat in _chats.where((chat) => chat.unreadCount > 0)) {
      digests.add('unread-${chat.jid}-${chat.unreadCount}');
    }
    return digests;
  }

  void _handleNavigateAction(
    AccessibilityNavigateAction action,
    Emitter<AccessibilityActionState> emit,
  ) {
    final isChatContext =
        state.currentEntry.kind == AccessibilityStepKind.chatMessages ||
            state.currentEntry.kind == AccessibilityStepKind.conversation ||
            state.currentEntry.kind == AccessibilityStepKind.composer;
    final targetIsChat = action.step == AccessibilityStepKind.chatMessages ||
        action.step == AccessibilityStepKind.conversation ||
        action.step == AccessibilityStepKind.composer;
    final leavingChat = isChatContext && !targetIsChat;
    if (leavingChat) {
      _clearMessageStream();
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
        discardWarningActive: false,
      ),
    );
    _rebuildSections(emit, state);
  }

  void _handleCommandAction(
    AccessibilityCommandAction action,
    Emitter<AccessibilityActionState> emit,
  ) {
    if (state.discardWarningActive) {
      emit(state.copyWith(discardWarningActive: false));
    }
    switch (action.command) {
      case AccessibilityCommand.openChat:
        final contact = action.contact;
        if (contact == null) return;
        _openChatMessages(contact, emit);
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
        _saveDraft(emit);
        break;
      case AccessibilityCommand.resumeDraft:
        final draft = action.draft;
        if (draft == null) return;
        _openDraftComposer(draft, emit);
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
          'Failed to save draft from accessibility modal', error, stackTrace);
      emit(
        state.copyWith(
          busy: false,
          errorMessage: _l10n.chatDraftMissingContent,
          discardWarningActive: false,
        ),
      );
    }
  }

  void _openDraftComposer(
    Draft draft,
    Emitter<AccessibilityActionState> emit,
  ) {
    final recipients = draft.jids.map(_contactForJid).toList();
    final activeJid = recipients.isNotEmpty ? recipients.first.jid : null;
    if (activeJid != null) {
      _startMessageStream(activeJid);
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
      statusMessage:
          'Draft loaded. Press Escape to exit or Save to keep edits.',
      errorMessage: null,
      discardWarningActive: false,
    );
    emit(nextState);
    _rebuildSections(emit, nextState);
  }

  void _enterRecipientPicker(Emitter<AccessibilityActionState> emit) {
    final nextStack = List<AccessibilityStepEntry>.of(state.stack);
    final composerIndex = nextStack.lastIndexWhere(
        (entry) => entry.kind == AccessibilityStepKind.composer);
    if (composerIndex == -1) return;
    nextStack[composerIndex] =
        nextStack[composerIndex].copyWith(addingRecipient: true);
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
        statusMessage: null,
        errorMessage: null,
      ),
    );
    _rebuildSections(emit, state);
  }

  void _handleContactSelection(
    AccessibilityContact contact,
    Emitter<AccessibilityActionState> emit,
  ) {
    final stack = List<AccessibilityStepEntry>.of(state.stack);
    if (state.stack.last.kind == AccessibilityStepKind.contactPicker) {
      final entry = state.stack.last;
      if (entry.purpose == AccessibilityFlowPurpose.sendMessage) {
        final recipients = _mergeRecipients(entry.recipients, contact);
        final nextStack = List<AccessibilityStepEntry>.of(state.stack);
        final previousIndex = nextStack.length - 2;
        final cameFromComposer = previousIndex >= 0 &&
            nextStack[previousIndex].kind == AccessibilityStepKind.composer;
        final activeJid = recipients.first.jid;
        _startMessageStream(activeJid);
        if (cameFromComposer) {
          nextStack[previousIndex] = nextStack[previousIndex].copyWith(
            recipients: recipients,
            addingRecipient: false,
          );
          nextStack.removeLast();
        } else {
          nextStack[nextStack.length - 1] =
              entry.copyWith(recipients: recipients, addingRecipient: false);
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
          statusMessage: null,
          errorMessage: null,
          discardWarningActive: false,
        );
        emit(nextState);
        _rebuildSections(emit, nextState);
        return;
      }
      if (entry.purpose == AccessibilityFlowPurpose.openChat) {
        _openChatMessages(contact, emit);
        return;
      }
    }
    if (stack.last.kind == AccessibilityStepKind.newContact) {
      final recipients = _mergeRecipients(stack.last.recipients, contact);
      final activeJid = recipients.first.jid;
      _startMessageStream(activeJid);
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
          statusMessage: null,
          errorMessage: null,
          discardWarningActive: false,
        ),
      );
      _rebuildSections(emit, state);
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
            jid: action.invite.jid, title: action.invite.title);
      } else {
        await roster.rejectSubscriptionRequest(action.invite.jid);
      }
      emit(
        state.copyWith(
          busy: false,
          statusMessage:
              action.accept ? _textInviteAccepted : _textInviteDismissed,
        ),
      );
    } on XmppException catch (error, stackTrace) {
      _log.warning('Invite decision failed', error, stackTrace);
      emit(
        state.copyWith(
          busy: false,
          errorMessage: _textInviteUpdateFailed,
        ),
      );
    }
    _rebuildSections(emit, state);
  }

  void _handleDismissHighlight(
    String highlightId,
    Emitter<AccessibilityActionState> emit,
  ) {
    _dismissedHighlights.add(highlightId);
    _rebuildSections(emit, state);
  }

  void _openChatMessages(
    AccessibilityContact contact,
    Emitter<AccessibilityActionState> emit,
  ) {
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
      nextStack[nextStack.length - 1] =
          nextStack.last.copyWith(recipients: [contact]);
    } else {
      nextStack.add(newEntry);
    }
    _startMessageStream(contact.jid);
    final nextState = state.copyWith(
      visible: true,
      stack: nextStack,
      recipients: [contact],
      activeChatJid: contact.jid,
      messages: const [],
      attachments: const {},
      statusMessage: null,
      errorMessage: null,
      discardWarningActive: false,
    );
    emit(nextState);
    _rebuildSections(emit, nextState);
  }

  void _startMessageStream(String jid) {
    _clearMessageStream();
    _messageSubscription = _messageService
        .messageStreamForChat(
      jid,
      end: _messagePageSize,
    )
        .listen(
      (messages) => add(
        AccessibilityMessagesUpdated(jid: jid, messages: messages),
      ),
      onError: (error, stackTrace) {
        _log.warning('Message stream error for $jid', error, stackTrace);
      },
    );
  }

  void _clearMessageStream() {
    unawaited(_messageSubscription?.cancel());
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
        : 'New message from ${_senderLabelFor(latest)} at '
            '${_formatTimestamp(latest.timestamp)}';
    final nextState = state.copyWith(
      messages: ordered,
      attachments: attachments,
      statusMessage: incomingStatus ?? state.statusMessage,
    );
    emit(nextState);
    _rebuildSections(emit, nextState);
  }

  Future<Map<String, FileMetadataData>> _loadAttachments(
    List<Message> messages,
  ) async {
    final pairs = <String, String>{};
    for (final message in messages) {
      final metadataId = message.fileMetadataID;
      if (metadataId != null && metadataId.isNotEmpty) {
        pairs[_messageId(message)] = metadataId;
      }
    }
    if (pairs.isEmpty) return const {};
    try {
      final db = await _messageService.database;
      final results = <String, FileMetadataData>{};
      for (final entry in pairs.entries) {
        final metadata = await db.getFileMetadata(entry.value);
        if (metadata != null) {
          results[entry.key] = metadata;
        }
      }
      return results;
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to load attachment metadata', error, stackTrace);
      return const {};
    }
  }

  void _rebuildSections(
    Emitter<AccessibilityActionState> emit,
    AccessibilityActionState baseState,
  ) {
    final entry = baseState.stack.last;
    int? messageInitialIndex;
    final sections = switch (entry.kind) {
      AccessibilityStepKind.root => _buildRootSections(),
      AccessibilityStepKind.contactPicker => _buildContactSections(
          entry.purpose ?? AccessibilityFlowPurpose.openChat),
      AccessibilityStepKind.unread => _buildUnreadSections(),
      AccessibilityStepKind.invites => _buildInviteSections(),
      AccessibilityStepKind.composer => () {
          final result = _buildConversationSections(entry);
          messageInitialIndex = result.initialMessageIndex;
          return result.sections;
        }(),
      AccessibilityStepKind.newContact => _buildNewContactSections(),
      AccessibilityStepKind.chatMessages => () {
          final result = _buildConversationSections(entry);
          messageInitialIndex = result.initialMessageIndex;
          return result.sections;
        }(),
      AccessibilityStepKind.conversation => () {
          final result = _buildConversationSections(entry);
          messageInitialIndex = result.initialMessageIndex;
          return result.sections;
        }(),
    };
    emit(
      baseState.copyWith(
        sections: sections,
        recipients: entry.recipients,
        messageInitialIndex: messageInitialIndex,
      ),
    );
  }

  List<AccessibilityMenuSection> _buildRootSections() {
    final sections = <AccessibilityMenuSection>[];
    final totalUnread = _contacts.fold<int>(
      0,
      (count, contact) =>
          contact.unreadCount > 0 ? count + contact.unreadCount : count,
    );

    sections.add(
      AccessibilityMenuSection(
        id: 'actions',
        title: _textRootActionsTitle,
        items: [
          AccessibilityMenuItem(
            id: 'action-start-chat',
            label: _textStartNewChat,
            description: _textStartNewChatDescription,
            kind: AccessibilityMenuItemKind.navigate,
            action: const AccessibilityNavigateAction(
              step: AccessibilityStepKind.contactPicker,
              purpose: AccessibilityFlowPurpose.sendMessage,
            ),
            icon: Icons.add_comment_outlined,
          ),
          AccessibilityMenuItem(
            id: 'action-unread',
            label: _textReadNewMessages,
            description: _textUnreadSummaryDescription,
            kind: AccessibilityMenuItemKind.navigate,
            action: const AccessibilityNavigateAction(
              step: AccessibilityStepKind.unread,
              purpose: AccessibilityFlowPurpose.reviewUnread,
            ),
            icon: Icons.mark_chat_unread_outlined,
            badge: totalUnread > 0 ? totalUnread.toString() : null,
          ),
        ],
      ),
    );

    if (_invites.isNotEmpty) {
      sections.addAll(_buildInviteSections());
    }

    final orderedDrafts = List<Draft>.of(_drafts)
      ..sort((a, b) => b.id.compareTo(a.id));

    final chatItems = _contacts
        .where((contact) => contact.source == AccessibilityContactSource.chat)
        .map(
          (contact) => AccessibilityMenuItem(
            id: 'chat-${contact.jid}',
            label: contact.displayName,
            description: contact.subtitle,
            kind: AccessibilityMenuItemKind.command,
            action: AccessibilityCommandAction(
              command: AccessibilityCommand.openChat,
              contact: contact,
            ),
            icon: contact.isGroup
                ? Icons.groups_2_outlined
                : Icons.chat_bubble_outline,
            badge:
                contact.unreadCount > 0 ? contact.unreadCount.toString() : null,
          ),
        )
        .toList();

    sections.add(
      AccessibilityMenuSection(
        id: 'chats',
        title: _l10n.homeTabChats,
        items: chatItems.isEmpty
            ? const [
                AccessibilityMenuItem(
                  id: 'chats-empty',
                  label: 'No conversations yet',
                  description: '',
                  kind: AccessibilityMenuItemKind.readOnly,
                  action: AccessibilityNoopAction(),
                ),
              ]
            : chatItems,
      ),
    );

    if (orderedDrafts.isNotEmpty) {
      sections.add(
        AccessibilityMenuSection(
          id: 'drafts',
          title: 'Drafts',
          items: _draftMenuItems(orderedDrafts),
        ),
      );
    }

    return sections;
  }

  List<AccessibilityMenuItem> _draftMenuItems(List<Draft> drafts) {
    return drafts.take(10).map((draft) {
      final description = _draftDescription(draft);
      final recipientsLabel = _draftRecipientsLabel(draft.jids);
      final label = recipientsLabel.isEmpty
          ? 'Draft ${draft.id}'
          : 'Draft to $recipientsLabel';
      return AccessibilityMenuItem(
        id: 'draft-${draft.id}',
        label: label,
        description: description,
        kind: AccessibilityMenuItemKind.command,
        action: AccessibilityCommandAction(
          command: AccessibilityCommand.resumeDraft,
          draft: draft,
        ),
        icon: Icons.note_outlined,
      );
    }).toList();
  }

  String _draftDescription(Draft draft) {
    final recipientsLabel = _draftRecipientsLabel(draft.jids);
    final body = (draft.body ?? '').trim();
    final preview = body.isEmpty
        ? 'No message body'
        : (body.length > 80 ? '${body.substring(0, 80)}…' : body);
    if (recipientsLabel.isEmpty) return preview;
    return '$recipientsLabel — $preview';
  }

  String _draftRecipientsLabel(List<String> jids) {
    if (jids.isEmpty) return '';
    final names = jids.map((jid) => _contactForJid(jid).displayName).toList();
    return names.join(', ');
  }

  List<AccessibilityMenuSection> _buildContactSections(
    AccessibilityFlowPurpose purpose,
  ) {
    final description = purpose == AccessibilityFlowPurpose.sendMessage
        ? _l10n.chatComposerMessageHint
        : _l10n.chatSearchMessages;
    final items = _contacts
        .map(
          (contact) => AccessibilityMenuItem(
            id: 'contact-${contact.jid}',
            label: contact.displayName,
            description: contact.subtitle,
            kind: purpose == AccessibilityFlowPurpose.sendMessage
                ? AccessibilityMenuItemKind.selectContact
                : AccessibilityMenuItemKind.command,
            action: purpose == AccessibilityFlowPurpose.sendMessage
                ? AccessibilitySelectContactAction(contact: contact)
                : AccessibilityCommandAction(
                    command: AccessibilityCommand.openChat,
                    contact: contact,
                  ),
            icon:
                contact.isGroup ? Icons.groups_outlined : Icons.person_outline,
            badge:
                contact.unreadCount > 0 ? contact.unreadCount.toString() : null,
          ),
        )
        .toList();
    if (purpose == AccessibilityFlowPurpose.sendMessage) {
      items.add(
        AccessibilityMenuItem(
          id: 'new-contact',
          label: _textNewContactTitle,
          description: _textNewContactDescription,
          kind: AccessibilityMenuItemKind.navigate,
          action: const AccessibilityNavigateAction(
            step: AccessibilityStepKind.newContact,
            purpose: AccessibilityFlowPurpose.sendMessage,
          ),
          icon: Icons.create,
        ),
      );
    }
    return [
      AccessibilityMenuSection(
        id: 'contacts',
        title: description,
        items: items,
      ),
    ];
  }

  List<AccessibilityMenuSection> _buildUnreadSections() {
    final items = _contacts
        .where((contact) => contact.unreadCount > 0)
        .map(
          (contact) => AccessibilityMenuItem(
            id: 'unread-${contact.jid}',
            label: contact.displayName,
            description: _unreadDescription(contact),
            kind: AccessibilityMenuItemKind.command,
            action: AccessibilityCommandAction(
              command: AccessibilityCommand.openChat,
              contact: contact,
            ),
            icon: Icons.mark_chat_unread_outlined,
            badge: contact.unreadCount.toString(),
          ),
        )
        .toList();
    if (items.isEmpty) {
      items.add(
        const AccessibilityMenuItem(
          id: 'unread-none',
          label: 'No unread conversations',
          description: '',
          kind: AccessibilityMenuItemKind.command,
          action: AccessibilityCommandAction(
            command: AccessibilityCommand.closeMenu,
          ),
          icon: Icons.mark_chat_unread_outlined,
          disabled: true,
        ),
      );
    }
    return [
      AccessibilityMenuSection(
        id: 'unread',
        title: _textReadNewMessages,
        items: items,
      ),
    ];
  }

  List<AccessibilityMenuSection> _buildInviteSections() {
    final items = <AccessibilityMenuItem>[];
    for (final invite in _invites) {
      items.addAll([
        AccessibilityMenuItem(
          id: 'invite-accept-${invite.jid}',
          label: _textAcceptInvite,
          description: invite.jid,
          kind: AccessibilityMenuItemKind.inviteDecision,
          action: AccessibilityInviteDecisionAction(
            invite: invite,
            accept: true,
          ),
          icon: Icons.person_add_alt,
        ),
        AccessibilityMenuItem(
          id: 'invite-reject-${invite.jid}',
          label: _textInviteDismissed,
          description: invite.jid,
          kind: AccessibilityMenuItemKind.inviteDecision,
          action: AccessibilityInviteDecisionAction(
            invite: invite,
            accept: false,
          ),
          icon: Icons.person_off_outlined,
          destructive: true,
        ),
      ]);
    }
    if (items.isEmpty) {
      items.add(
        const AccessibilityMenuItem(
          id: 'invites-none',
          label: 'No pending invites',
          description: '',
          kind: AccessibilityMenuItemKind.command,
          action: AccessibilityCommandAction(
            command: AccessibilityCommand.closeMenu,
          ),
          icon: Icons.person_add_disabled_outlined,
          disabled: true,
        ),
      );
    }
    return [
      AccessibilityMenuSection(
        id: 'invites',
        title: _textInvitesTitle,
        items: items,
      ),
    ];
  }

  _SectionWithInitial _buildChatMessageSections(
    AccessibilityStepEntry entry,
  ) {
    final targetJid = entry.recipients.isNotEmpty
        ? entry.recipients.first.jid
        : state.activeChatJid;
    if (targetJid == null) {
      return const _SectionWithInitial(
        section: AccessibilityMenuSection(
          id: 'chat-messages',
          title: 'Messages',
          items: [
            AccessibilityMenuItem(
              id: 'msg-none',
              label: 'No conversation selected',
              description: '',
              kind: AccessibilityMenuItemKind.readOnly,
              action: AccessibilityNoopAction(),
            ),
          ],
        ),
        initialIndex: 0,
      );
    }
    final contact = _contactFor(targetJid);
    final messages = state.messages;
    final items = <AccessibilityMenuItem>[];
    var lastSender = '';
    final attachmentIndex = state.attachments;
    for (final message in messages) {
      final senderLabel = _senderLabelFor(message);
      final timestampLabel = _formatTimestamp(message.timestamp);
      final attachment = attachmentIndex[_messageId(message)];
      final body = (message.body ?? '').trim();
      final attachmentNote = _attachmentLabelFor(message, metadata: attachment);
      final fullBody =
          body.isNotEmpty ? body : (attachmentNote ?? 'Empty message');
      final showSender = senderLabel != lastSender;
      final label =
          showSender ? '$senderLabel at $timestampLabel: $fullBody' : fullBody;
      items.add(
        AccessibilityMenuItem(
          id: 'msg-${_messageId(message)}',
          label: label,
          description: showSender ? null : senderLabel,
          kind: AccessibilityMenuItemKind.readOnly,
          action: const AccessibilityNoopAction(),
          message: message,
          attachment: attachment,
          attachmentLabel: attachmentNote,
          senderLabel: senderLabel,
          timestampLabel: timestampLabel,
          showMetadata: showSender,
        ),
      );
      lastSender = senderLabel;
    }
    var initialIndex = 0;
    if (items.isNotEmpty) {
      initialIndex = _initialMessageIndex(messages);
    } else {
      items.add(
        const AccessibilityMenuItem(
          id: 'msg-empty',
          label: 'No messages yet',
          description: '',
          kind: AccessibilityMenuItemKind.readOnly,
          action: AccessibilityNoopAction(),
        ),
      );
    }
    final title = 'Messages with ${contact.displayName}';
    return _SectionWithInitial(
      section: AccessibilityMenuSection(
        id: 'chat-messages',
        title: title,
        items: items,
      ),
      initialIndex: initialIndex,
    );
  }

  _ConversationSectionsResult _buildConversationSections(
    AccessibilityStepEntry entry,
  ) {
    final messages = _buildChatMessageSections(entry);
    return _ConversationSectionsResult(
      sections: [messages.section],
      initialMessageIndex: messages.initialIndex,
    );
  }

  List<AccessibilityMenuSection> _buildNewContactSections() {
    return [
      AccessibilityMenuSection(
        id: 'new-contact',
        title: _textSubmitNewContactTitle,
        items: [
          AccessibilityMenuItem(
            id: 'new-contact-confirm',
            label: _textSubmitNewContactTitle,
            description: _textSubmitNewContactDescription,
            kind: AccessibilityMenuItemKind.command,
            action: const AccessibilityCommandAction(
              command: AccessibilityCommand.confirmNewContact,
            ),
            icon: Icons.check,
            disabled: !state.newContactInput.trim().isValidJid,
          ),
        ],
      ),
    ];
  }

  int _initialMessageIndex(List<Message> messages) {
    if (messages.isEmpty) return 0;
    final latestUnread = _latestIndexFor(messages, onlyUnread: true);
    if (latestUnread != null) {
      return latestUnread;
    }
    return _latestIndexFor(messages) ?? 0;
  }

  int? _latestIndexFor(
    List<Message> messages, {
    bool onlyUnread = false,
  }) {
    if (messages.isEmpty) return null;
    final myBareJid = _chatsService.myJid?.split('/').first;
    int? latestIndex;
    DateTime latestTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (onlyUnread) {
        final senderBare = message.senderJid.split('/').first;
        final fromMe = myBareJid != null && senderBare == myBareJid;
        final unread = !fromMe && !message.displayed;
        if (!unread) continue;
      }
      final timestamp =
          message.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (latestIndex == null || timestamp.isAfter(latestTimestamp)) {
        latestIndex = i;
        latestTimestamp = timestamp;
      }
    }
    return latestIndex;
  }

  String _unreadDescription(AccessibilityContact contact) =>
      contact.unreadCount == 1
          ? '1 unread message'
          : '${contact.unreadCount} unread messages';

  void _syncActiveChatRecipient(Emitter<AccessibilityActionState> emit) {
    final active = state.activeChatJid;
    if (active == null) return;
    final contact = _contactFor(active);
    var stackChanged = false;
    final nextStack = <AccessibilityStepEntry>[];
    for (final entry in state.stack) {
      if (entry.kind == AccessibilityStepKind.chatMessages &&
          (entry.recipients.length != 1 || entry.recipients.first != contact)) {
        nextStack.add(entry.copyWith(recipients: [contact]));
        stackChanged = true;
      } else {
        nextStack.add(entry);
      }
    }
    final recipientsChanged =
        state.recipients.length != 1 || state.recipients.first != contact;
    if (stackChanged || recipientsChanged) {
      emit(
        state.copyWith(
          stack: nextStack,
          recipients: [contact],
        ),
      );
    }
  }

  AccessibilityContact _contactFor(String? jid) {
    final fallbackJid = jid ?? 'unknown';
    return _contacts.firstWhere(
      (contact) => contact.jid == fallbackJid,
      orElse: () => AccessibilityContact(
        jid: fallbackJid,
        displayName: jid ?? 'Unknown contact',
        subtitle: jid ?? 'Unknown contact',
        source: AccessibilityContactSource.chat,
        encryptionProtocol: EncryptionProtocol.none,
        chatType: ChatType.chat,
        unreadCount: 0,
      ),
    );
  }

  String _senderLabelFor(Message message) {
    final senderBare = message.senderJid.split('/').first;
    final me = _chatsService.myJid;
    if (me != null && senderBare == me) {
      return 'You';
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
    return DateFormat.yMMMd().add_jm().format(safe);
  }

  String? _attachmentLabelFor(
    Message message, {
    FileMetadataData? metadata,
  }) {
    final filename = metadata?.filename.trim();
    if (filename != null && filename.isNotEmpty) {
      return 'Attachment: $filename';
    }
    if (message.fileMetadataID != null) {
      return 'Attachment';
    }
    if (message.isFileUploadNotification) {
      return 'Upload available';
    }
    if (message.pseudoMessageType != null) {
      return message.pseudoMessageType!.name;
    }
    return null;
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

  // ignore: unused_element
  String get _textNeedsAttention => 'Needs attention';
  String get _textReadNewMessages => 'Read new messages';
  String get _textUnreadSummaryDescription =>
      'Focus on conversations with unread messages';
  String get _textRootActionsTitle => 'Actions';
  String get _textStartNewChat => 'Start a new chat';
  String get _textStartNewChatDescription =>
      'Pick a contact or type an address';
  String get _textInvitesTitle => 'Invites';
  // ignore: unused_element
  String get _textPendingInvites => 'Pending invites';
  String get _textAcceptInvite => 'Accept invite';
  String get _textNewContactTitle => 'Start chat';
  String get _textNewContactDescription =>
      'Use the typed address to start chatting';
  String get _textSubmitNewContactTitle => 'Start chat';
  String get _textSubmitNewContactDescription =>
      'Use the typed address to start chatting';
  String get _textInvalidAddress => 'Enter a valid address';
  String get _textInviteAccepted => 'Invite accepted';
  String get _textInviteDismissed => 'Invite dismissed';
  String get _textInviteUpdateFailed => 'Unable to update invite';
}
