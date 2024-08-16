part of 'draft_cubit.dart';

sealed class DraftState extends Equatable {
  const DraftState();
}

final class DraftsAvailable extends DraftState {
  const DraftsAvailable({required this.items});

  final List<Draft> items;

  @override
  List<Object?> get props => [items];
}

final class DraftSending extends DraftState {
  @override
  List<Object?> get props => [];
}

final class DraftSent extends DraftState {
  @override
  List<Object?> get props => [];
}

final class DraftFailure extends DraftState {
  const DraftFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
