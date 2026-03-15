// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'chats_cubit.dart';

@Freezed(toJson: false, fromJson: false)
abstract class ChatsState with _$ChatsState {
  const factory ChatsState({
    @Default(ChatNavigationSession()) ChatNavigationSession navigation,
    required bool openCalendar,
    required List<Chat>? items,
    required RequestStatus creationStatus,
    ChatsCreateRoomFailure? creationFailure,
    @Default(RequestStatus.none) RequestStatus refreshStatus,
    DateTime? lastSyncedAt,
    @Default(<String>{}) Set<String> selectedJids,
    @Default('') String searchQuery,
    @Default(false) bool searchActive,
    SearchFilterId? searchFilter,
    @Default(SearchSortOrder.newestFirst) SearchSortOrder searchSortOrder,
    @Default('') String spamSearchQuery,
    @Default(false) bool spamSearchActive,
    SearchFilterId? spamSearchFilter,
    @Default(SearchSortOrder.newestFirst) SearchSortOrder spamSearchSortOrder,
    @Default(<String>{}) Set<String> rosterContacts,
    @Default(<Chat>[]) List<Chat> visibleItems,
    @Default(<Chat>[]) List<Chat> archivedItems,
    @Default(<Chat>[]) List<Chat> selectedChats,
    @Default(<Chat>[]) List<Chat> spamVisibleItems,
    @Default(<String>{}) Set<String> spamUpdatingJids,
    @Default(<String>[]) List<String> recipientAddressSuggestions,
    @Default(0) int demoResetRevision,
  }) = _ChatsState;

  const ChatsState._();

  String? get openJid => navigation.openJid;

  List<String> get openStack => navigation.stack;

  List<String> get forwardStack => navigation.forwardStack;

  bool get openChatCalendar => navigation.chatCalendarOpen;

  ChatRouteIndex get openChatRoute => navigation.route;

  String? get pendingOpenMessageChatJid => navigation.pendingOpenMessageChatJid;

  String? get pendingOpenMessageReferenceId =>
      navigation.pendingOpenMessageReferenceId;

  int get pendingOpenMessageRequestId => navigation.pendingOpenMessageRequestId;
}

@immutable
final class PendingOpenMessageSelection {
  const PendingOpenMessageSelection({
    required this.chatJid,
    required this.referenceId,
  });

  final String chatJid;
  final String referenceId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PendingOpenMessageSelection &&
            other.chatJid == chatJid &&
            other.referenceId == referenceId;
  }

  @override
  int get hashCode => Object.hash(chatJid, referenceId);
}

@immutable
final class ChatNavigationSession {
  const ChatNavigationSession({
    List<String> stack = const <String>[],
    List<String> forwardStack = const <String>[],
    this.route = ChatRouteIndex.main,
    this.chatCalendarOpen = false,
    this.pendingOpenMessage,
    this.pendingOpenMessageRequestId = 0,
    this.pendingDefaultRouteJid,
  }) : _stack = stack,
       _forwardStack = forwardStack;

  final List<String> _stack;
  final List<String> _forwardStack;
  final ChatRouteIndex route;
  final bool chatCalendarOpen;
  final PendingOpenMessageSelection? pendingOpenMessage;
  final int pendingOpenMessageRequestId;
  final String? pendingDefaultRouteJid;

  List<String> get stack => List<String>.unmodifiable(_stack);

  List<String> get forwardStack => List<String>.unmodifiable(_forwardStack);

  String? get openJid => _stack.isEmpty ? null : _stack.last;

  String? get pendingOpenMessageChatJid => pendingOpenMessage?.chatJid;

  String? get pendingOpenMessageReferenceId => pendingOpenMessage?.referenceId;

  ChatNavigationSession copyWith({
    List<String>? stack,
    List<String>? forwardStack,
    ChatRouteIndex? route,
    bool? chatCalendarOpen,
    Object? pendingOpenMessage = _chatNavigationSessionUnset,
    int? pendingOpenMessageRequestId,
    Object? pendingDefaultRouteJid = _chatNavigationSessionUnset,
  }) {
    return ChatNavigationSession(
      stack: stack ?? _stack,
      forwardStack: forwardStack ?? _forwardStack,
      route: route ?? this.route,
      chatCalendarOpen: chatCalendarOpen ?? this.chatCalendarOpen,
      pendingOpenMessage: pendingOpenMessage == _chatNavigationSessionUnset
          ? this.pendingOpenMessage
          : pendingOpenMessage as PendingOpenMessageSelection?,
      pendingOpenMessageRequestId:
          pendingOpenMessageRequestId ?? this.pendingOpenMessageRequestId,
      pendingDefaultRouteJid:
          pendingDefaultRouteJid == _chatNavigationSessionUnset
          ? this.pendingDefaultRouteJid
          : pendingDefaultRouteJid as String?,
    );
  }

  ChatNavigationSession replace({
    required List<String> stack,
    required List<String> forwardStack,
    required ChatRouteIndex route,
    required bool chatCalendarOpen,
    required String? pendingDefaultRouteJid,
  }) {
    return copyWith(
      stack: stack,
      forwardStack: forwardStack,
      route: route,
      chatCalendarOpen: chatCalendarOpen,
      pendingDefaultRouteJid: pendingDefaultRouteJid,
    );
  }

  ChatNavigationSession open({
    required String jid,
    required ChatRouteIndex route,
    required String? pendingDefaultRouteJid,
  }) {
    return copyWith(
      stack: <String>[jid],
      forwardStack: const <String>[],
      route: route,
      chatCalendarOpen: route.isCalendar,
      pendingOpenMessage: null,
      pendingDefaultRouteJid: pendingDefaultRouteJid,
    );
  }

  ChatNavigationSession queuePendingOpenMessage({
    required String jid,
    required String referenceId,
  }) {
    return copyWith(
      pendingOpenMessage: PendingOpenMessageSelection(
        chatJid: jid,
        referenceId: referenceId,
      ),
      pendingOpenMessageRequestId: pendingOpenMessageRequestId + 1,
    );
  }

  ChatNavigationSession clearPendingOpenMessage({required int requestId}) {
    if (requestId != pendingOpenMessageRequestId) {
      return this;
    }
    return copyWith(pendingOpenMessage: null);
  }

  ChatNavigationSession push({
    required String jid,
    required ChatRouteIndex route,
  }) {
    final nextStack =
        _stack.where((entry) => entry != jid).toList(growable: true)..add(jid);
    return copyWith(
      stack: nextStack,
      forwardStack: const <String>[],
      route: route,
      chatCalendarOpen: route.isCalendar,
      pendingDefaultRouteJid: null,
    );
  }

  ChatNavigationSession pop({
    required ChatRouteIndex route,
    required String? pendingDefaultRouteJid,
  }) {
    if (_stack.isEmpty) {
      return this;
    }
    final nextStack = List<String>.of(_stack)..removeLast();
    final nextForward = List<String>.of(_forwardStack)..add(_stack.last);
    return copyWith(
      stack: nextStack,
      forwardStack: nextForward,
      route: route,
      chatCalendarOpen: route.isCalendar,
      pendingDefaultRouteJid: pendingDefaultRouteJid,
    );
  }

  ChatNavigationSession restore({
    required String jid,
    required ChatRouteIndex route,
    required String? pendingDefaultRouteJid,
  }) {
    final nextForward = List<String>.of(_forwardStack)..removeLast();
    final nextStack =
        _stack.where((entry) => entry != jid).toList(growable: true)..add(jid);
    return copyWith(
      stack: nextStack,
      forwardStack: nextForward,
      route: route,
      chatCalendarOpen: route.isCalendar,
      pendingDefaultRouteJid: pendingDefaultRouteJid,
    );
  }

  ChatNavigationSession closeAll() {
    return copyWith(
      stack: const <String>[],
      forwardStack: const <String>[],
      route: ChatRouteIndex.main,
      chatCalendarOpen: false,
      pendingDefaultRouteJid: null,
    );
  }

  ChatNavigationSession clearPendingDefaultRoute() {
    return copyWith(pendingDefaultRouteJid: null);
  }

  ChatNavigationSession closeChatCalendarPanel() {
    return copyWith(chatCalendarOpen: false, pendingDefaultRouteJid: null);
  }

  ChatNavigationSession setRoute(ChatRouteIndex route) {
    return copyWith(
      route: route,
      chatCalendarOpen: route.isCalendar,
      pendingDefaultRouteJid: null,
    );
  }

  ChatNavigationSession setChatCalendarOpen(bool open) {
    return copyWith(
      chatCalendarOpen: open,
      route: open
          ? ChatRouteIndex.calendar
          : route.isCalendar
          ? ChatRouteIndex.main
          : route,
      pendingDefaultRouteJid: null,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChatNavigationSession &&
            listEquals(other._stack, _stack) &&
            listEquals(other._forwardStack, _forwardStack) &&
            other.route == route &&
            other.chatCalendarOpen == chatCalendarOpen &&
            other.pendingOpenMessage == pendingOpenMessage &&
            other.pendingOpenMessageRequestId == pendingOpenMessageRequestId &&
            other.pendingDefaultRouteJid == pendingDefaultRouteJid;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(_stack),
    Object.hashAll(_forwardStack),
    route,
    chatCalendarOpen,
    pendingOpenMessage,
    pendingOpenMessageRequestId,
    pendingDefaultRouteJid,
  );
}

const Object _chatNavigationSessionUnset = Object();
