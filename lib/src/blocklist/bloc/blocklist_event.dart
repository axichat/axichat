part of 'blocklist_bloc.dart';

sealed class BlocklistEvent extends Equatable {
  const BlocklistEvent();
}

final class _BlocklistUpdated extends BlocklistEvent {
  const _BlocklistUpdated({required this.items});

  final List<BlocklistData> items;

  @override
  List<Object?> get props => [items];
}

final class BlocklistBlocked extends BlocklistEvent {
  const BlocklistBlocked({required this.jid});

  final String jid;

  @override
  List<Object?> get props => [jid];
}

final class BlocklistUnblocked extends BlocklistEvent {
  const BlocklistUnblocked({required this.jid});

  final String jid;

  @override
  List<Object?> get props => [jid];
}

final class BlocklistAllUnblocked extends BlocklistEvent {
  const BlocklistAllUnblocked();

  @override
  List<Object?> get props => [];
}
