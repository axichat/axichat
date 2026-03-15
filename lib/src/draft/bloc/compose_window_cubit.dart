// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:bloc/bloc.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

part 'compose_window_state.dart';

class ComposeWindowCubit extends Cubit<ComposeWindowState> {
  ComposeWindowCubit() : super(const ComposeWindowState());

  int _nextId = 0;
  int _nextSession = 0;

  void openDraft({
    int? id,
    List<String> jids = const [''],
    String body = '',
    String subject = '',
    DraftQuoteTarget? quoteTarget,
    List<String> attachmentMetadataIds = const <String>[],
  }) {
    final entry = ComposeWindowEntry(
      id: _nextId++,
      view: ComposeWindowView.normal,
      seed: ComposeDraftSeed(
        id: id,
        jids: jids,
        body: body,
        subject: subject,
        quoteTarget: quoteTarget,
        attachmentMetadataIds: attachmentMetadataIds,
      ),
      session: _nextSession++,
    );
    emit(state.copyWith(windows: [...state.windows, entry]));
  }

  void recordDraftId(int windowId, int draftId) {
    final index = state.windows.indexWhere((entry) => entry.id == windowId);
    if (index == -1) return;
    final current = state.windows[index];
    if (current.seed.id == draftId) return;
    _updateWindow(
      windowId,
      (entry) => entry.copyWith(seed: entry.seed.copyWith(id: draftId)),
    );
  }

  void minimize(int id) => _updateWindow(
    id,
    (entry) => entry.copyWith(view: ComposeWindowView.minimized),
  );

  void restore(int id) => _updateWindow(
    id,
    (entry) => entry.copyWith(view: ComposeWindowView.normal),
  );

  void toggleExpanded(int id) => _updateWindow(
    id,
    (entry) => entry.copyWith(
      view: entry.isExpanded
          ? ComposeWindowView.normal
          : ComposeWindowView.expanded,
    ),
  );

  void closeWindow(int id) => emit(
    state.copyWith(
      windows: state.windows.where((entry) => entry.id != id).toList(),
    ),
  );

  void updateOffset(int id, Offset offset) =>
      _updateWindow(id, (entry) => entry.copyWith(offset: offset));

  void initializeOffset(int id, Offset offset) => _updateWindow(
    id,
    (entry) => entry.offset == null ? entry.copyWith(offset: offset) : entry,
  );

  void _updateWindow(
    int id,
    ComposeWindowEntry Function(ComposeWindowEntry) update,
  ) {
    var changed = false;
    final next = state.windows.map((entry) {
      if (entry.id != id) {
        return entry;
      }
      final updated = update(entry);
      if (updated != entry) {
        changed = true;
      }
      return updated;
    }).toList();
    if (!changed) {
      return;
    }
    emit(state.copyWith(windows: next));
  }

  @override
  Future<void> close() async {
    emit(const ComposeWindowState());
    await super.close();
  }
}
