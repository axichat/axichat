// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/view/compose_screen.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final ValueNotifier<int> composeScreenRouteDepth = ValueNotifier<int>(0);

void openComposeDraft(
  BuildContext context, {
  int? id,
  List<String> jids = const [''],
  String body = '',
  String subject = '',
  DraftQuoteTarget? quoteTarget,
  List<String> attachmentMetadataIds = const <String>[],
  bool scaleFromBottom = false,
}) {
  final env = EnvScope.maybeOf(context);
  final platform = env?.platform ?? defaultTargetPlatform;
  final bool isDesktopPlatform =
      env?.isDesktopPlatform ??
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
      quoteTarget: quoteTarget,
      attachmentMetadataIds: attachmentMetadataIds,
    );
    return;
  }

  final navigatorState = Navigator.maybeOf(context);
  if (navigatorState == null) {
    context.read<ComposeWindowCubit>().openDraft(
      id: id,
      jids: jids,
      body: body,
      subject: subject,
      quoteTarget: quoteTarget,
      attachmentMetadataIds: attachmentMetadataIds,
    );
    return;
  }

  final seed = ComposeDraftSeed(
    id: id,
    jids: jids,
    body: body,
    subject: subject,
    quoteTarget: quoteTarget,
    attachmentMetadataIds: attachmentMetadataIds,
  );
  T locate<T>() => context.read<T>();
  final Duration animationDuration = context
      .read<SettingsCubit>()
      .animationDuration;

  void trackComposeRoute(Future<void> routeFuture) {
    composeScreenRouteDepth.value = composeScreenRouteDepth.value + 1;
    routeFuture.whenComplete(() {
      final currentDepth = composeScreenRouteDepth.value;
      if (currentDepth <= 0) {
        composeScreenRouteDepth.value = 0;
        return;
      }
      composeScreenRouteDepth.value = currentDepth - 1;
    });
  }

  if (scaleFromBottom) {
    trackComposeRoute(
      navigatorState.push<void>(
        PageRouteBuilder<void>(
          transitionDuration: animationDuration,
          reverseTransitionDuration: animationDuration,
          pageBuilder: (context, animation, secondaryAnimation) =>
              ComposeScreen(seed: seed, locate: locate),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved);
            final scale = Tween<double>(begin: 0.96, end: 1.0).animate(curved);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: slide,
                child: ScaleTransition(
                  alignment: Alignment.bottomCenter,
                  scale: scale,
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
    return;
  }

  trackComposeRoute(
    navigatorState.push<void>(
      AxiFadePageRoute<void>(
        duration: animationDuration,
        builder: (_) => ComposeScreen(seed: seed, locate: locate),
      ),
    ),
  );
}
