// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/accessibility/models/accessibility_action_models.dart';
import 'package:axichat/src/common/ui/jid_input.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'accessibility_action_event.dart';
part 'accessibility_action_state.dart';

class AccessibilityActionBloc
    extends Bloc<AccessibilityActionEvent, AccessibilityActionState> {
  AccessibilityActionBloc({
    required ChatsService chatsService,
    required MessageService messageService,
    required AppLocalizations initialLocalization,
    RosterService? rosterService,
  })  : _chatsService = chatsService,
        _messageService = messageService,
        _rosterService = rosterService,
        _log = Logger('AccessibilityActionBloc'),
        _l10n = initialLocalization,
        super(const AccessibilityActionState.initial()) {
    on<AccessibilityMenuOpened>(_onMenuOpened);
    on<AccessibilityMenuClosed>(_onMenuClosed);
    on<AccessibilityMenuBack>(_onMenuBack);
    on<AccessibilityMenuActionTriggered>(_onMenuActionTriggered);
    on<AccessibilityComposerChanged>(_onComposerChanged);
    on<AccessibilityRecipientRemoved>(_onRecipientRemoved);
    on<AccessibilityNewContactChanged>(_onNewContactChanged);
    on<AccessibilityConfirmNewContact>(_onConfirmNewContact);
    on<AccessibilityDiscardWarningRequested>(_onDiscardWarningRequested);
    on<AccessibilityMenuJumpedTo>(_onMenuJumpedTo);
    on<AccessibilityDataUpdated>(_onDataUpdated);
    on<AccessibilityLocaleUpdated>(_onLocaleUpdated);
    on<AccessibilityDraftIdUpdated>(_onDraftIdUpdated);

    _chatSubscription = _chatsService.chatsStream().listen(
          (items) => add(AccessibilityDataUpdated(chats: items)),
        );
    _draftSubscription = _messageService.draftsStream().listen(
          (items) => add(AccessibilityDataUpdated(drafts: items)),
        );
    if (_rosterService != null) {
      _rosterSubscription = _rosterService.rosterStream().listen(
            (items) => add(AccessibilityDataUpdated(roster: items)),
          );
      _inviteSubscription = _rosterService.invitesStream().listen(
            (items) => add(AccessibilityDataUpdated(invites: items)),
          );
    }
  }

  final ChatsService _chatsService;
  final MessageService _messageService;
  final RosterService? _rosterService;
  final Logger _log;

  late AppLocalizations _l10n;

  late final StreamSubscription<List<Chat>> _chatSubscription;
  StreamSubscription<List<RosterItem>>? _rosterSubscription;
  StreamSubscription<List<Invite>>? _inviteSubscription;
  StreamSubscription<List<Draft>>? _draftSubscription;

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

  void _onMenuClosed(
    AccessibilityMenuClosed event,
    Emitter<AccessibilityActionState> emit,
  ) {
    final nextState = state.copyWith(
      visible: false,
      stack: const [AccessibilityStepEntry(kind: AccessibilityStepKind.root)],
      composerText: '',
      newContactInput: '',
      statusMessage: null,
      errorMessage: null,
      discardWarningActive: false,
    );
    emit(nextState);
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
          discardWarningActive: false,
        ),
      );
      return;
    }
    final nextStack = List<AccessibilityStepEntry>.of(state.stack)
      ..removeLast();
    final nextState = state.copyWith(
      stack: nextStack,
      statusMessage: null,
      errorMessage: null,
      composerText: '',
      newContactInput: '',
      discardWarningActive: false,
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

  void _onMenuJumpedTo(
    AccessibilityMenuJumpedTo event,
    Emitter<AccessibilityActionState> emit,
  ) {
    if (event.index < 0 || event.index >= state.stack.length) return;
    final nextStack = state.stack.take(event.index + 1).toList();
    emit(
      state.copyWith(
        stack: nextStack,
        statusMessage: null,
        errorMessage: null,
        discardWarningActive: false,
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
      _handleNavigateAction(action, emit);
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
    nextStack[index] = entry.copyWith(recipients: filtered);
    emit(
      state.copyWith(
        stack: nextStack,
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

  void _onDraftIdUpdated(
    AccessibilityDraftIdUpdated event,
    Emitter<AccessibilityActionState> emit,
  ) {
    final nextStack = List<AccessibilityStepEntry>.of(state.stack);
    final index = nextStack.lastIndexWhere(
      (entry) => entry.kind == AccessibilityStepKind.composer,
    );
    if (index == -1) return;
    if (nextStack[index].draftId == event.draftId) return;
    nextStack[index] = nextStack[index].copyWith(draftId: event.draftId);
    emit(state.copyWith(stack: nextStack));
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
      final sortedDrafts = List<Draft>.of(event.drafts!)
        ..sort((a, b) => b.id.compareTo(a.id));
      _drafts = sortedDrafts;
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
    final refreshedStack = _refreshRecipientSnapshots(nextState.stack);
    if (!identical(refreshedStack, nextState.stack)) {
      nextState = nextState.copyWith(stack: refreshedStack);
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

  List<AccessibilityStepEntry> _refreshRecipientSnapshots(
    List<AccessibilityStepEntry> stack,
  ) {
    var changed = false;
    final refreshed = <AccessibilityStepEntry>[];
    for (final entry in stack) {
      if (entry.recipients.isEmpty) {
        refreshed.add(entry);
        continue;
      }
      final updatedRecipients = entry.recipients
          .map((recipient) => _contactForJid(recipient.jid))
          .toList();
      if (_sameRecipients(entry.recipients, updatedRecipients)) {
        refreshed.add(entry);
        continue;
      }
      refreshed.add(entry.copyWith(recipients: updatedRecipients));
      changed = true;
    }
    return changed ? refreshed : stack;
  }

  bool _sameRecipients(
    List<AccessibilityContact> current,
    List<AccessibilityContact> updated,
  ) {
    if (current.length != updated.length) return false;
    for (var index = 0; index < current.length; index++) {
      if (current[index] != updated[index]) {
        return false;
      }
    }
    return true;
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
      case AccessibilityCommand.resumeDraft:
        final draft = action.draft;
        if (draft == null) return;
        _openDraftComposer(draft, emit);
        break;
    }
  }

  void _openDraftComposer(
    Draft draft,
    Emitter<AccessibilityActionState> emit,
  ) {
    final recipients = draft.jids.map(_contactForJid).toList();
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
          composerText: state.composerText,
          newContactInput: '',
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
          newContactInput: '',
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
    final nextState = state.copyWith(
      visible: true,
      stack: nextStack,
      statusMessage: null,
      errorMessage: null,
      discardWarningActive: false,
    );
    emit(nextState);
  }

  String _displayNameForChat(Chat chat) {
    final preferred = chat.contactDisplayName?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      return preferred;
    }
    final title = chat.title.trim();
    return title.isEmpty ? chat.jid : chat.title;
  }
}
