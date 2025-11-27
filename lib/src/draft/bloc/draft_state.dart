part of 'draft_cubit.dart';

sealed class DraftState extends Equatable {
  const DraftState({required this.items});

  final List<Draft>? items;

  @override
  List<Object?> get props => [items];
}

final class DraftsAvailable extends DraftState {
  const DraftsAvailable({required super.items});
}

final class DraftSaveComplete extends DraftState {
  const DraftSaveComplete({required super.items});
}

final class DraftSending extends DraftState {
  const DraftSending({required super.items});
}

final class DraftSendComplete extends DraftState {
  const DraftSendComplete({required super.items});
}

final class DraftFailure extends DraftState {
  const DraftFailure(this.message, {required super.items});

  final String message;

  @override
  List<Object?> get props => [message, items];
}
