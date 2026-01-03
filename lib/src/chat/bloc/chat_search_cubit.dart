// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

class ChatSearchState extends Equatable {
  const ChatSearchState({
    this.active = false,
    this.query = '',
    this.sort = SearchSortOrder.newestFirst,
    this.filter = MessageTimelineFilter.directOnly,
    this.status = RequestStatus.none,
    this.results = const [],
    this.error,
    this.subjectFilter,
    this.excludeSubject = false,
    this.subjects = const [],
  });

  final bool active;
  final String query;
  final SearchSortOrder sort;
  final MessageTimelineFilter filter;
  final RequestStatus status;
  final List<Message> results;
  final String? error;
  final String? subjectFilter;
  final bool excludeSubject;
  final List<String> subjects;

  bool get hasResults => results.isNotEmpty;

  ChatSearchState copyWith({
    bool? active,
    String? query,
    SearchSortOrder? sort,
    MessageTimelineFilter? filter,
    RequestStatus? status,
    List<Message>? results,
    String? error,
    String? subjectFilter,
    bool? excludeSubject,
    List<String>? subjects,
  }) {
    return ChatSearchState(
      active: active ?? this.active,
      query: query ?? this.query,
      sort: sort ?? this.sort,
      filter: filter ?? this.filter,
      status: status ?? this.status,
      results: results ?? this.results,
      error: error,
      subjectFilter: subjectFilter ?? this.subjectFilter,
      excludeSubject: excludeSubject ?? this.excludeSubject,
      subjects: subjects ?? this.subjects,
    );
  }

  @override
  List<Object?> get props => [
        active,
        query,
        sort,
        filter,
        status,
        results,
        error,
        subjectFilter,
        excludeSubject,
        subjects,
      ];
}

class ChatSearchCubit extends Cubit<ChatSearchState> {
  ChatSearchCubit({
    required this.jid,
    required MessageService messageService,
    EmailService? emailService,
    this.resultLimit = 200,
  })  : _messageService = messageService,
        _emailService = emailService,
        super(const ChatSearchState());

  final String jid;
  final MessageService _messageService;
  final EmailService? _emailService;
  final int resultLimit;

  Timer? _debounce;
  bool _subjectsLoaded = false;
  Chat? _cachedChat;

  void toggleActive() => setActive(!state.active);

  void setActive(bool active) {
    if (!active) {
      _debounce?.cancel();
      emit(
        state.copyWith(
          active: false,
          status: RequestStatus.none,
          results: const [],
          error: null,
          excludeSubject: false,
          subjectFilter: null,
        ),
      );
      return;
    }
    emit(state.copyWith(active: true));
    unawaited(_maybeLoadSubjects());
    if (state.query.trim().isNotEmpty) {
      _scheduleSearch(immediate: true);
    }
  }

  void updateQuery(String value) {
    emit(state.copyWith(query: value));
    _scheduleSearch();
  }

  void updateSort(SearchSortOrder sort) {
    if (state.sort == sort) return;
    emit(state.copyWith(sort: sort));
    _scheduleSearch(immediate: true);
  }

  void updateFilter(MessageTimelineFilter filter) {
    if (state.filter == filter) return;
    emit(state.copyWith(filter: filter));
    _scheduleSearch(immediate: true);
  }

  Future<Chat?> _chatForSearch() async {
    final cached = _cachedChat;
    if (cached != null) return cached;
    final db = await _messageService.database;
    final chat = await db.getChat(jid);
    _cachedChat = chat;
    return chat;
  }

  List<Message> _sortResults(List<Message> results) {
    if (results.isEmpty) return results;
    final earliestTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
    final ordered = List<Message>.of(results)
      ..sort(
        (a, b) => (a.timestamp ?? earliestTimestamp)
            .compareTo(b.timestamp ?? earliestTimestamp),
      );
    if (state.sort == SearchSortOrder.newestFirst) {
      return ordered.reversed.toList(growable: false);
    }
    return ordered;
  }

  Future<void> _maybeLoadSubjects() async {
    if (_subjectsLoaded) return;
    try {
      final subjects = await _messageService.subjectsForChat(jid);
      _subjectsLoaded = true;
      emit(state.copyWith(subjects: subjects));
    } catch (_) {
      // Silent failure; search can proceed without subject options.
    }
  }

  void updateSubjectFilter(String? subject) {
    emit(
      state.copyWith(
        subjectFilter: subject?.trim().isEmpty == true ? null : subject?.trim(),
      ),
    );
    _scheduleSearch(immediate: true);
  }

  void toggleExcludeSubject(bool exclude) {
    emit(state.copyWith(excludeSubject: exclude));
    _scheduleSearch(immediate: true);
  }

  void _scheduleSearch({bool immediate = false}) {
    _debounce?.cancel();
    final hasQuery = state.query.trim().isNotEmpty;
    final hasSubject = state.subjectFilter?.isNotEmpty == true;
    if (!hasQuery && !hasSubject) {
      emit(
        state.copyWith(
          status: RequestStatus.none,
          results: const [],
          error: null,
        ),
      );
      return;
    }
    if (immediate) {
      unawaited(_performSearch());
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_performSearch());
    });
  }

  Future<void> _performSearch() async {
    final query = state.query.trim();
    final subject = state.subjectFilter?.trim();
    if (query.isEmpty && (subject == null || subject.isEmpty)) return;
    emit(state.copyWith(status: RequestStatus.loading, error: null));
    try {
      final chat = await _chatForSearch();
      final emailService = _emailService;
      final shouldUseEmailSearch = emailService != null &&
          chat?.defaultTransport.isEmail == true &&
          (subject == null || subject.isEmpty) &&
          !state.excludeSubject;
      List<Message> results;
      if (shouldUseEmailSearch) {
        results = await emailService.searchMessages(
          chat: chat,
          query: query,
        );
        results = _sortResults(results);
        if (results.length > resultLimit) {
          results = results.sublist(0, resultLimit);
        }
      } else {
        results = await _messageService.searchChatMessages(
          jid: jid,
          query: query,
          subject: subject,
          excludeSubject: state.excludeSubject,
          filter: state.filter,
          sortOrder: state.sort,
          limit: resultLimit,
        );
      }
      emit(
        state.copyWith(
          status: RequestStatus.success,
          results: results,
          error: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: RequestStatus.failure,
          error: error.toString(),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
