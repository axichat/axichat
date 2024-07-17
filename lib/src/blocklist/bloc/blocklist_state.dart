part of 'blocklist_cubit.dart';

sealed class BlocklistState extends Equatable {
  const BlocklistState();
}

final class BlocklistAvailable extends BlocklistState {
  const BlocklistAvailable({required this.items});

  final List<BlocklistData> items;

  @override
  List<Object?> get props => [items];
}

final class BlocklistLoading extends BlocklistState {
  const BlocklistLoading({required this.jid});

  final String? jid;

  @override
  List<Object?> get props => [jid];
}

final class BlocklistSuccess extends BlocklistState {
  const BlocklistSuccess(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class BlocklistFailure extends BlocklistState {
  const BlocklistFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
