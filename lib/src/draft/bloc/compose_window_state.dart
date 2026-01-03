// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'compose_window_cubit.dart';

enum ComposeWindowView { minimized, normal, expanded }

@immutable
class ComposeDraftSeed extends Equatable {
  const ComposeDraftSeed({
    this.id,
    this.jids = const [''],
    this.body = '',
    this.subject = '',
    this.attachmentMetadataIds = const <String>[],
  });

  final int? id;
  final List<String> jids;
  final String body;
  final String subject;
  final List<String> attachmentMetadataIds;

  @override
  List<Object?> get props => [
        id,
        jids,
        body,
        subject,
        attachmentMetadataIds,
      ];
}

@immutable
class ComposeWindowState extends Equatable {
  const ComposeWindowState({this.windows = const []});

  final List<ComposeWindowEntry> windows;

  ComposeWindowState copyWith({
    List<ComposeWindowEntry>? windows,
  }) {
    return ComposeWindowState(
      windows: windows ?? this.windows,
    );
  }

  @override
  List<Object?> get props => [windows];
}

@immutable
class ComposeWindowEntry extends Equatable {
  const ComposeWindowEntry({
    required this.id,
    required this.view,
    required this.seed,
    required this.session,
    this.offset,
  });

  final int id;
  final ComposeWindowView view;
  final ComposeDraftSeed seed;
  final int session;
  final Offset? offset;

  bool get isMinimized => view == ComposeWindowView.minimized;

  bool get isExpanded => view == ComposeWindowView.expanded;

  ComposeWindowEntry copyWith({
    ComposeWindowView? view,
    ComposeDraftSeed? seed,
    int? session,
    Offset? offset,
  }) {
    return ComposeWindowEntry(
      id: id,
      view: view ?? this.view,
      seed: seed ?? this.seed,
      session: session ?? this.session,
      offset: offset ?? this.offset,
    );
  }

  @override
  List<Object?> get props => [
        id,
        view,
        seed,
        session,
        offset,
      ];
}
