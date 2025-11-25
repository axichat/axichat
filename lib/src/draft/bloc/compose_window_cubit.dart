import 'package:bloc/bloc.dart';
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
        attachmentMetadataIds: attachmentMetadataIds,
      ),
      session: _nextSession++,
    );
    emit(state.copyWith(windows: [...state.windows, entry]));
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

  void updateOffset(int id, Offset offset) => _updateWindow(
        id,
        (entry) => entry.copyWith(offset: offset),
      );

  void initializeOffset(int id, Offset offset) => _updateWindow(
        id,
        (entry) =>
            entry.offset == null ? entry.copyWith(offset: offset) : entry,
      );

  void _updateWindow(
    int id,
    ComposeWindowEntry Function(ComposeWindowEntry) update,
  ) {
    final next = state.windows
        .map((entry) => entry.id == id ? update(entry) : entry)
        .toList();
    emit(state.copyWith(windows: next));
  }

  @override
  Future<void> close() async {
    emit(const ComposeWindowState());
    await super.close();
  }
}
