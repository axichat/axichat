part of 'blocklist_bloc.dart';

sealed class BlocklistState extends Equatable {
  const BlocklistState({required this.items});

  final List<BlocklistData> items;

  @override
  List<Object?> get props => [items];
}

final class BlocklistInitial extends BlocklistState {
  const BlocklistInitial({required super.items});
}

final class BlocklistAvailable extends BlocklistState {
  const BlocklistAvailable({required super.items});
}

final class BlocklistLoading extends BlocklistState {
  const BlocklistLoading({required this.jid, required super.items});

  final String? jid;

  @override
  List<Object?> get props => [...super.props, jid];
}

final class BlocklistSuccess extends BlocklistState {
  const BlocklistSuccess(this.message, {required super.items});

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}

final class BlocklistFailure extends BlocklistState {
  const BlocklistFailure(this.message, {required super.items});

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}
