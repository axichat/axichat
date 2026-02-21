// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'roster_cubit.dart';

final class RosterViewCriteria extends Equatable {
  const RosterViewCriteria({
    this.query = '',
    this.sort = SearchSortOrder.newestFirst,
  });

  final String query;
  final SearchSortOrder sort;

  @override
  List<Object?> get props => [query, sort];
}

enum RosterActionType { add, remove, reject }

enum RosterFailureReason { invalidJid, addFailed, removeFailed, rejectFailed }

sealed class RosterActionState extends Equatable {
  const RosterActionState();
}

final class RosterActionIdle extends RosterActionState {
  const RosterActionIdle();

  @override
  List<Object?> get props => const [];
}

final class RosterActionLoading extends RosterActionState {
  const RosterActionLoading({required this.action, required this.jid});

  final RosterActionType action;
  final String jid;

  @override
  List<Object?> get props => [action, jid];
}

final class RosterActionSuccess extends RosterActionState {
  const RosterActionSuccess({required this.action, required this.jid});

  final RosterActionType action;
  final String jid;

  @override
  List<Object?> get props => [action, jid];
}

final class RosterActionFailure extends RosterActionState {
  const RosterActionFailure({
    required this.action,
    required this.jid,
    required this.reason,
  });

  final RosterActionType action;
  final String jid;
  final RosterFailureReason reason;

  @override
  List<Object?> get props => [action, jid, reason];
}

final class RosterState extends Equatable {
  const RosterState({
    this.items,
    this.invites,
    this.visibleItems,
    this.visibleInvites,
    this.contactsCriteria = const RosterViewCriteria(),
    this.invitesCriteria = const RosterViewCriteria(),
    this.actionState = const RosterActionIdle(),
  });

  final List<RosterItem>? items;
  final List<Invite>? invites;
  final List<RosterItem>? visibleItems;
  final List<Invite>? visibleInvites;
  final RosterViewCriteria contactsCriteria;
  final RosterViewCriteria invitesCriteria;
  final RosterActionState actionState;

  RosterState copyWith({
    List<RosterItem>? items,
    List<Invite>? invites,
    List<RosterItem>? visibleItems,
    List<Invite>? visibleInvites,
    RosterViewCriteria? contactsCriteria,
    RosterViewCriteria? invitesCriteria,
    RosterActionState? actionState,
  }) {
    return RosterState(
      items: items ?? this.items,
      invites: invites ?? this.invites,
      visibleItems: visibleItems ?? this.visibleItems,
      visibleInvites: visibleInvites ?? this.visibleInvites,
      contactsCriteria: contactsCriteria ?? this.contactsCriteria,
      invitesCriteria: invitesCriteria ?? this.invitesCriteria,
      actionState: actionState ?? this.actionState,
    );
  }

  @override
  List<Object?> get props => [
    items,
    invites,
    visibleItems,
    visibleInvites,
    contactsCriteria,
    invitesCriteria,
    actionState,
  ];
}
