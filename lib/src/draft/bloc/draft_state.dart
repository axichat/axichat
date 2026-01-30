// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'draft_cubit.dart';

sealed class DraftState extends Equatable {
  const DraftState({required this.items, required this.visibleItems});

  final List<Draft>? items;
  final List<Draft>? visibleItems;

  @override
  List<Object?> get props => [items, visibleItems];
}

final class DraftsAvailable extends DraftState {
  const DraftsAvailable({required super.items, required super.visibleItems});
}

final class DraftSaveComplete extends DraftState {
  const DraftSaveComplete({
    required super.items,
    required super.visibleItems,
    this.autoSaved = false,
  });

  final bool autoSaved;

  @override
  List<Object?> get props => [items, visibleItems, autoSaved];
}

final class DraftSending extends DraftState {
  const DraftSending({required super.items, required super.visibleItems});
}

final class DraftSendComplete extends DraftState {
  const DraftSendComplete({required super.items, required super.visibleItems});
}

final class DraftFailure extends DraftState {
  const DraftFailure(this.type,
      {required super.items, required super.visibleItems});

  final DraftSendFailureType type;

  @override
  List<Object?> get props => [type, items, visibleItems];
}
