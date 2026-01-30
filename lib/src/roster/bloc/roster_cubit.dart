// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/bloc_cache.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'roster_state.dart';

class RosterCubit extends Cubit<RosterState> with BlocCache<RosterState> {
  RosterCubit({required RosterService rosterService})
      : _rosterService = rosterService,
        super(const RosterState()) {
    _rosterSubscription = _rosterService.rosterStream().listen(_handleRoster);
    _invitesSubscription = _rosterService.invitesStream().listen(
          _handleInvites,
        );
  }

  final RosterService _rosterService;

  late final StreamSubscription<List<RosterItem>> _rosterSubscription;
  late final StreamSubscription<List<Invite>> _invitesSubscription;

  List<RosterItem>? _items;
  List<Invite>? _invites;
  var _contactsCriteria = const RosterViewCriteria();
  var _invitesCriteria = const RosterViewCriteria();

  int get inviteCount => _invites?.length ?? 0;
  var contacts = <String>{};

  @override
  Future<void> close() async {
    await _rosterSubscription.cancel();
    await _invitesSubscription.cancel();
    return super.close();
  }

  void updateContactsCriteria({
    required String query,
    required SearchSortOrder sort,
    required RosterFilter filter,
  }) {
    final next = RosterViewCriteria(
      query: query.trim().toLowerCase(),
      sort: sort,
      filter: filter,
    );
    if (next == _contactsCriteria) return;
    _contactsCriteria = next;
    _emitViewState();
  }

  void updateInvitesCriteria({
    required String query,
    required SearchSortOrder sort,
  }) {
    final next = RosterViewCriteria(
      query: query.trim().toLowerCase(),
      sort: sort,
    );
    if (next == _invitesCriteria) return;
    _invitesCriteria = next;
    _emitViewState();
  }

  Future<void> addContact({required String jid, String? title}) async {
    if (!jid.isValidJid) {
      emit(
        state.copyWith(
          actionState: RosterActionFailure(
            action: RosterActionType.add,
            jid: jid,
            reason: RosterFailureReason.invalidJid,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        actionState: RosterActionLoading(
          action: RosterActionType.add,
          jid: jid,
        ),
      ),
    );
    try {
      await _rosterService.addToRoster(jid: jid, title: title);
    } on XmppRosterException catch (_) {
      emit(
        state.copyWith(
          actionState: RosterActionFailure(
            action: RosterActionType.add,
            jid: jid,
            reason: RosterFailureReason.addFailed,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        actionState: RosterActionSuccess(
          action: RosterActionType.add,
          jid: jid,
        ),
      ),
    );
  }

  Future<void> removeContact({required String jid}) async {
    emit(
      state.copyWith(
        actionState: RosterActionLoading(
          action: RosterActionType.remove,
          jid: jid,
        ),
      ),
    );
    try {
      await _rosterService.removeFromRoster(jid: jid);
    } on XmppRosterException catch (_) {
      emit(
        state.copyWith(
          actionState: RosterActionFailure(
            action: RosterActionType.remove,
            jid: jid,
            reason: RosterFailureReason.removeFailed,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        actionState: RosterActionSuccess(
          action: RosterActionType.remove,
          jid: jid,
        ),
      ),
    );
  }

  Future<void> rejectContact({required String jid}) async {
    emit(
      state.copyWith(
        actionState: RosterActionLoading(
          action: RosterActionType.reject,
          jid: jid,
        ),
      ),
    );
    try {
      await _rosterService.rejectSubscriptionRequest(jid);
    } on XmppRosterException catch (_) {
      emit(
        state.copyWith(
          actionState: RosterActionFailure(
            action: RosterActionType.reject,
            jid: jid,
            reason: RosterFailureReason.rejectFailed,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        actionState: RosterActionSuccess(
          action: RosterActionType.reject,
          jid: jid,
        ),
      ),
    );
  }

  void _handleRoster(List<RosterItem> items) {
    _items = List<RosterItem>.unmodifiable(items);
    contacts = items.map((e) => e.jid).toSet();
    cache['items'] = _items;
    _emitViewState();
  }

  void _handleInvites(List<Invite> invites) {
    _invites = List<Invite>.unmodifiable(invites);
    cache['invites'] = _invites;
    _emitViewState();
  }

  void _emitViewState() {
    final visibleItems = _items == null
        ? null
        : List<RosterItem>.unmodifiable(
            _applyRosterCriteria(_items!, _contactsCriteria),
          );
    final visibleInvites = _invites == null
        ? null
        : List<Invite>.unmodifiable(
            _applyInviteCriteria(_invites!, _invitesCriteria),
          );
    emit(
      state.copyWith(
        items: _items,
        invites: _invites,
        visibleItems: visibleItems,
        visibleInvites: visibleInvites,
        contactsCriteria: _contactsCriteria,
        invitesCriteria: _invitesCriteria,
      ),
    );
  }

  List<RosterItem> _applyRosterCriteria(
    List<RosterItem> items,
    RosterViewCriteria criteria,
  ) {
    Iterable<RosterItem> filtered = items;
    switch (criteria.filter) {
      case RosterFilter.online:
        filtered = filtered.where((item) => !item.presence.isUnavailable);
      case RosterFilter.offline:
        filtered = filtered.where((item) => item.presence.isUnavailable);
      case RosterFilter.all:
        break;
    }

    if (criteria.query.isNotEmpty) {
      filtered = filtered.where((item) => _matchesRosterQuery(item, criteria));
    }

    final sorted = filtered.toList();
    sorted.sort(
      (a, b) => criteria.sort.isNewestFirst
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : b.title.toLowerCase().compareTo(a.title.toLowerCase()),
    );
    return sorted;
  }

  List<Invite> _applyInviteCriteria(
    List<Invite> invites,
    RosterViewCriteria criteria,
  ) {
    Iterable<Invite> filtered = invites;
    if (criteria.query.isNotEmpty) {
      filtered =
          filtered.where((invite) => _matchesInviteQuery(invite, criteria));
    }
    final sorted = filtered.toList();
    sorted.sort(
      (a, b) => criteria.sort.isNewestFirst
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : b.title.toLowerCase().compareTo(a.title.toLowerCase()),
    );
    return sorted;
  }

  bool _matchesRosterQuery(RosterItem item, RosterViewCriteria criteria) {
    final query = criteria.query;
    return item.title.toLowerCase().contains(query) ||
        item.jid.toLowerCase().contains(query) ||
        (item.status?.toLowerCase().contains(query) ?? false);
  }

  bool _matchesInviteQuery(Invite invite, RosterViewCriteria criteria) {
    final query = criteria.query;
    return invite.title.toLowerCase().contains(query) ||
        invite.jid.toLowerCase().contains(query);
  }
}
