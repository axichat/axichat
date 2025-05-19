part of 'roster_cubit.dart';

sealed class RosterState extends Equatable {
  const RosterState();
}

final class RosterInitial extends RosterState
    implements RosterAvailable, RosterInvitesAvailable {
  const RosterInitial();

  @override
  List<Invite>? get invites => null;

  @override
  List<RosterItem>? get items => null;

  @override
  List<Object?> get props => [items, invites];
}

final class RosterAvailable extends RosterState {
  const RosterAvailable({required this.items});

  final List<RosterItem>? items;

  @override
  List<Object?> get props => [items];
}

final class RosterInvitesAvailable extends RosterState {
  const RosterInvitesAvailable({required this.invites});

  final List<Invite>? invites;

  @override
  List<Object?> get props => [invites];
}

final class RosterLoading extends RosterState {
  const RosterLoading({required this.jid});

  final String jid;

  @override
  List<Object?> get props => [jid];
}

final class RosterSuccess extends RosterState {
  const RosterSuccess(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class RosterFailure extends RosterState {
  const RosterFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
