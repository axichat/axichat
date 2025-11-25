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
  const ComposeWindowState({
    required this.visible,
    required this.view,
    required this.seed,
    required this.session,
  });

  const ComposeWindowState.hidden()
      : visible = false,
        view = ComposeWindowView.normal,
        seed = const ComposeDraftSeed(),
        session = 0;

  final bool visible;
  final ComposeWindowView view;
  final ComposeDraftSeed seed;
  final int session;

  bool get isMinimized => view == ComposeWindowView.minimized;

  bool get isExpanded => view == ComposeWindowView.expanded;

  ComposeWindowState copyWith({
    bool? visible,
    ComposeWindowView? view,
    ComposeDraftSeed? seed,
    int? session,
  }) {
    return ComposeWindowState(
      visible: visible ?? this.visible,
      view: view ?? this.view,
      seed: seed ?? this.seed,
      session: session ?? this.session,
    );
  }

  @override
  List<Object?> get props => [
        visible,
        view,
        seed,
        session,
      ];
}
