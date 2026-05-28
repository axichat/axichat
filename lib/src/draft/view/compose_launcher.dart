// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/calendar/view/shell/calendar_task_off_grid_drag_controller.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/compose_screen.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

final ValueNotifier<int> composeScreenRouteDepth = ValueNotifier<int>(0);

void openComposeDraft(
  BuildContext context, {
  int? id,
  List<String> jids = const [''],
  String body = '',
  String subject = '',
  DraftQuoteTarget? quoteTarget,
  List<String> attachmentMetadataIds = const <String>[],
  CalendarTaskIcsMessage? calendarTaskIcsMessage,
  List<DraftForwardedBlock> forwardedBlocks = const <DraftForwardedBlock>[],
  List<String> forwardedSourceAttachmentMetadataIds = const <String>[],
  Map<String, MessageTransport> recipientTransportOverrides = const {},
  bool autosaveEnabled = false,
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
      calendarTaskIcsMessage: calendarTaskIcsMessage,
      forwardedBlocks: forwardedBlocks,
      forwardedSourceAttachmentMetadataIds:
          forwardedSourceAttachmentMetadataIds,
      recipientTransportOverrides: recipientTransportOverrides,
      autosaveEnabled: autosaveEnabled,
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
      calendarTaskIcsMessage: calendarTaskIcsMessage,
      forwardedBlocks: forwardedBlocks,
      forwardedSourceAttachmentMetadataIds:
          forwardedSourceAttachmentMetadataIds,
      recipientTransportOverrides: recipientTransportOverrides,
      autosaveEnabled: autosaveEnabled,
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
    calendarTaskIcsMessage: calendarTaskIcsMessage,
    forwardedBlocks: forwardedBlocks,
    forwardedSourceAttachmentMetadataIds: forwardedSourceAttachmentMetadataIds,
    recipientTransportOverrides: recipientTransportOverrides,
    autosaveEnabled: autosaveEnabled,
  );
  final settingsCubit = context.read<SettingsCubit>();
  final animationDuration = settingsCubit.animationDuration;
  final profileCubit = context.read<ProfileCubit>();
  final rosterCubit = context.read<RosterCubit>();
  final chatsCubit = context.read<ChatsCubit>();
  final draftCubit = context.read<DraftCubit>();
  final offGridDragController = context
      .read<CalendarTaskOffGridDragController>();

  Widget providedComposeScreen() {
    return _ComposeRouteProviders(
      settingsCubit: settingsCubit,
      profileCubit: profileCubit,
      rosterCubit: rosterCubit,
      chatsCubit: chatsCubit,
      draftCubit: draftCubit,
      offGridDragController: offGridDragController,
      child: ComposeScreen(seed: seed),
    );
  }

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
              providedComposeScreen(),
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
        builder: (_) => providedComposeScreen(),
      ),
    ),
  );
}

class _ComposeRouteProviders extends StatelessWidget {
  const _ComposeRouteProviders({
    required this.settingsCubit,
    required this.profileCubit,
    required this.rosterCubit,
    required this.chatsCubit,
    required this.draftCubit,
    required this.offGridDragController,
    required this.child,
  });

  final SettingsCubit settingsCubit;
  final ProfileCubit profileCubit;
  final RosterCubit rosterCubit;
  final ChatsCubit chatsCubit;
  final DraftCubit draftCubit;
  final CalendarTaskOffGridDragController offGridDragController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CalendarTaskOffGridDragController>.value(
      value: offGridDragController,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider<ProfileCubit>.value(value: profileCubit),
          BlocProvider<RosterCubit>.value(value: rosterCubit),
          BlocProvider<ChatsCubit>.value(value: chatsCubit),
          BlocProvider<DraftCubit>.value(value: draftCubit),
        ],
        child: child,
      ),
    );
  }
}
