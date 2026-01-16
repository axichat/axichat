// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/compose_screen.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
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
  final env = EnvScope.maybeOf(context);
  final platform = Theme.of(context).platform;
  final bool isDesktopPlatform = env?.isDesktopPlatform ??
      (platform == TargetPlatform.macOS ||
          platform == TargetPlatform.linux ||
          platform == TargetPlatform.windows);
  if (isDesktopPlatform ||
      resolveCommandSurface(context) != CommandSurface.sheet) {
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
  T locate<T>() => context.read<T>();
  final Duration animationDuration =
      context.read<SettingsCubit>().animationDuration;
  resolvedNavigator.push<void>(
    AxiFadePageRoute<void>(
      duration: animationDuration,
      builder: (_) => ComposeScreen(seed: seed, locate: locate),
    ),
  );
}
