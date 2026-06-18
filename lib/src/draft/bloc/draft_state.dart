// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'draft_cubit.dart';

sealed class DraftState extends Equatable {
  const DraftState({
    required this.items,
    required this.visibleItems,
    this.sendingOwnerIds = const <String>{},
  });

  final List<Draft>? items;
  final List<Draft>? visibleItems;
  final Set<String> sendingOwnerIds;

  bool isSendingOwner(String ownerId) => sendingOwnerIds.contains(ownerId);

  @override
  List<Object?> get props => [items, visibleItems, sendingOwnerIds];
}

final class DraftsAvailable extends DraftState {
  const DraftsAvailable({
    required super.items,
    required super.visibleItems,
    super.sendingOwnerIds,
  });
}

final class DraftSaveComplete extends DraftState {
  const DraftSaveComplete({
    required super.items,
    required super.visibleItems,
    super.sendingOwnerIds,
    this.autoSaved = false,
  });

  final bool autoSaved;

  @override
  List<Object?> get props => [items, visibleItems, sendingOwnerIds, autoSaved];
}

final class DraftSending extends DraftState {
  const DraftSending({
    required super.items,
    required super.visibleItems,
    super.sendingOwnerIds,
    this.ownerId,
    this.preparing = false,
  });

  final String? ownerId;
  final bool preparing;

  @override
  List<Object?> get props => [
    items,
    visibleItems,
    sendingOwnerIds,
    ownerId,
    preparing,
  ];
}

final class DraftSendComplete extends DraftState {
  const DraftSendComplete({
    required super.items,
    required super.visibleItems,
    super.sendingOwnerIds,
    this.ownerId,
  });

  final String? ownerId;

  @override
  List<Object?> get props => [items, visibleItems, sendingOwnerIds, ownerId];
}

final class DraftFailure extends DraftState {
  const DraftFailure(
    this.type, {
    required super.items,
    required super.visibleItems,
    super.sendingOwnerIds,
    this.ownerId,
  });

  final DraftSendFailureType type;
  final String? ownerId;

  @override
  List<Object?> get props => [
    type,
    items,
    visibleItems,
    sendingOwnerIds,
    ownerId,
  ];
}
