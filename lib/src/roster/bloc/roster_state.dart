part of 'roster_bloc.dart';

sealed class RosterState extends Equatable {
  const RosterState({required this.items, required this.invites});

  final List<RosterItem> items;
  final List<Invite> invites;

  @override
  List<Object?> get props => [items, invites];
}

final class RosterInitial extends RosterState {
  const RosterInitial({required super.items, required super.invites});
}

final class RosterAvailable extends RosterState {
  const RosterAvailable({required super.items, required super.invites});
}

final class RosterInvitesAvailable extends RosterState {
  const RosterInvitesAvailable({required super.invites, required super.items});
}

final class RosterLoading extends RosterState {
  const RosterLoading({
    required this.jid,
    required super.items,
    required super.invites,
  });

  final String jid;

  @override
  List<Object?> get props => [...super.props, jid];
}

final class RosterSuccess extends RosterState {
  const RosterSuccess(
    this.message, {
    required super.items,
    required super.invites,
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}

final class RosterFailure extends RosterState {
  const RosterFailure(
    this.message, {
    required super.items,
    required super.invites,
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}
