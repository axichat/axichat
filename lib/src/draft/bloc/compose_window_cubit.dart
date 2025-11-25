import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

part 'compose_window_state.dart';

class ComposeWindowCubit extends Cubit<ComposeWindowState> {
  ComposeWindowCubit() : super(const ComposeWindowState.hidden());

  void openDraft({
    int? id,
    List<String> jids = const [''],
    String body = '',
    String subject = '',
    List<String> attachmentMetadataIds = const <String>[],
  }) {
    emit(
      ComposeWindowState(
        visible: true,
        view: ComposeWindowView.normal,
        seed: ComposeDraftSeed(
          id: id,
          jids: jids,
          body: body,
          subject: subject,
          attachmentMetadataIds: attachmentMetadataIds,
        ),
        session: state.session + 1,
      ),
    );
  }

  void minimize() => emit(
        state.copyWith(
          visible: true,
          view: ComposeWindowView.minimized,
        ),
      );

  void restore() => emit(
        state.copyWith(
          visible: true,
          view: ComposeWindowView.normal,
        ),
      );

  void toggleExpanded() => emit(
        state.copyWith(
          visible: true,
          view: state.isExpanded
              ? ComposeWindowView.normal
              : ComposeWindowView.expanded,
        ),
      );

  void hide() => emit(
        state.copyWith(
          visible: false,
          view: ComposeWindowView.normal,
        ),
      );

  @override
  Future<void> close() async {
    hide();
    await super.close();
  }
}
