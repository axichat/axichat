import 'dart:async';

import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/compose_screen.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void openComposeDraft(
  BuildContext context, {
  NavigatorState? navigator,
  int? id,
  List<String> jids = const [''],
  String body = '',
  String subject = '',
  List<String> attachmentMetadataIds = const <String>[],
}) {
  if (resolveCommandSurface(context) != CommandSurface.sheet) {
    context.read<ComposeWindowCubit>().openDraft(
          id: id,
          jids: jids,
          body: body,
          subject: subject,
          attachmentMetadataIds: attachmentMetadataIds,
        );
    return;
  }

  final resolvedNavigator = navigator ?? Navigator.maybeOf(context);
  if (resolvedNavigator == null) {
    context.read<ComposeWindowCubit>().openDraft(
          id: id,
          jids: jids,
          body: body,
          subject: subject,
          attachmentMetadataIds: attachmentMetadataIds,
        );
    return;
  }

  final seed = ComposeDraftSeed(
    id: id,
    jids: jids,
    body: body,
    subject: subject,
    attachmentMetadataIds: attachmentMetadataIds,
  );
  unawaited(
    resolvedNavigator.push<void>(
      MaterialPageRoute(
        builder: (context) => ComposeScreen(seed: seed),
      ),
    ),
  );
}
