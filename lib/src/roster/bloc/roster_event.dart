part of 'roster_bloc.dart';

sealed class RosterEvent extends Equatable {
  const RosterEvent();
}

final class _RosterUpdated extends RosterEvent {
  const _RosterUpdated(this.items);

  final List<RosterItem> items;

  @override
  List<Object?> get props => [items];
}

final class _RosterInvitesUpdated extends RosterEvent {
  const _RosterInvitesUpdated(this.invites);

  final List<Invite> invites;

  @override
  List<Object?> get props => [invites];
}

final class RosterSubscriptionAdded extends RosterEvent {
  const RosterSubscriptionAdded({required this.jid, required this.title});

  final String jid;
  final String? title;

  @override
  List<Object?> get props => [jid];
}

final class RosterSubscriptionRemoved extends RosterEvent {
  const RosterSubscriptionRemoved({required this.jid});

  final String jid;

  @override
  List<Object?> get props => [jid];
}

final class RosterSubscriptionRejected extends RosterEvent {
  const RosterSubscriptionRejected({required this.item});

  final Invite item;

  @override
  List<Object?> get props => [item];
}
