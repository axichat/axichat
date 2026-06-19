// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum CalendarTaskDragTipSource { grid, sidebar }

enum CalendarTaskDragTipLocation {
  grid,
  criticalPath,
  unscheduled,
  reminders;

  List<int> orderPath(int order) {
    return switch (this) {
      CalendarTaskDragTipLocation.grid => <int>[0, order],
      CalendarTaskDragTipLocation.criticalPath => <int>[1, 0, order],
      CalendarTaskDragTipLocation.unscheduled => <int>[1, 1, order],
      CalendarTaskDragTipLocation.reminders => <int>[1, 2, order],
    };
  }
}

class CalendarTaskDragTipHost extends StatefulWidget {
  const CalendarTaskDragTipHost({
    super.key,
    required this.accountJid,
    required this.enabled,
    required this.visibleSources,
    required this.rescanIdentity,
    required this.dragActive,
    required this.child,
    this.alwaysShow = false,
  });

  final String? accountJid;
  final bool enabled;
  final Set<CalendarTaskDragTipSource> visibleSources;
  final Object? rescanIdentity;
  final bool dragActive;
  final Widget child;
  final bool alwaysShow;

  @override
  State<CalendarTaskDragTipHost> createState() =>
      _CalendarTaskDragTipHostState();
}

class CalendarTaskDragTipCandidate extends StatelessWidget {
  const CalendarTaskDragTipCandidate({
    super.key,
    required this.source,
    required this.location,
    required this.taskId,
    required this.order,
    required this.child,
    this.enabled = true,
  });

  final CalendarTaskDragTipSource source;
  final CalendarTaskDragTipLocation location;
  final String taskId;
  final int order;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final sourceScope = _CalendarTaskDragTipSourceScope.maybeOf(context);
    final sourceVisible =
        sourceScope == null || sourceScope.visibleSources.contains(source);
    return OnboardingTipTarget(
      kind: OnboardingTipKind.calendarTaskDrag,
      candidateId: (location: location, order: order, taskId: taskId),
      order: OnboardingTipOrder(
        path: location.orderPath(order),
        tieBreaker: taskId,
      ),
      enabled: enabled && sourceVisible,
      title: context.l10n.calendarTaskDragHoldShowcaseTitle,
      description: context.l10n.calendarTaskDragShowcaseDescription,
      disableDefaultTargetGestures: true,
      child: child,
    );
  }
}

void notifyCalendarTaskDragTipTaskPickedUp(BuildContext context) {
  const OnboardingTipCompletedNotification(
    kind: OnboardingTipKind.calendarTaskDrag,
  ).dispatch(context);
}

@visibleForTesting
String? calendarTaskDragTipFirstCandidateForTesting({
  required Map<String, OnboardingTipOrder> candidates,
}) {
  MapEntry<String, OnboardingTipOrder>? winner;
  for (final entry in candidates.entries) {
    if (winner == null || entry.value.compareTo(winner.value) < 0) {
      winner = entry;
    }
  }
  return winner?.key;
}

@visibleForTesting
String? calendarTaskDragTipFirstVisibleCandidateForTesting({
  required Set<CalendarTaskDragTipSource> visibleSources,
  required Map<
    String,
    ({CalendarTaskDragTipSource source, OnboardingTipOrder order})
  >
  candidates,
}) {
  return calendarTaskDragTipFirstCandidateForTesting(
    candidates: <String, OnboardingTipOrder>{
      for (final entry in candidates.entries)
        if (visibleSources.contains(entry.value.source))
          entry.key: entry.value.order,
    },
  );
}

@visibleForTesting
bool calendarTaskDragTipShownFromStoredForTesting({
  required bool storedShown,
  required bool alwaysShow,
  bool completedThisSession = false,
}) {
  return _calendarTaskDragTipShownFromStored(
    storedShown: storedShown,
    alwaysShow: alwaysShow,
    completedThisSession: completedThisSession,
  );
}

bool _calendarTaskDragTipShownFromStored({
  required bool storedShown,
  required bool alwaysShow,
  required bool completedThisSession,
}) {
  if (alwaysShow) {
    return false;
  }
  return completedThisSession || storedShown;
}

@visibleForTesting
Set<CalendarTaskDragTipSource> calendarTaskDragTipVisibleSourcesForTesting({
  required bool usesDesktopLayout,
  required int mobileTabIndex,
}) => calendarTaskDragTipVisibleSources(
  usesDesktopLayout: usesDesktopLayout,
  mobileTabIndex: mobileTabIndex,
);

Set<CalendarTaskDragTipSource> calendarTaskDragTipVisibleSources({
  required bool usesDesktopLayout,
  required int mobileTabIndex,
}) {
  if (usesDesktopLayout) {
    return const <CalendarTaskDragTipSource>{
      CalendarTaskDragTipSource.grid,
      CalendarTaskDragTipSource.sidebar,
    };
  }
  return mobileTabIndex == 0
      ? const <CalendarTaskDragTipSource>{CalendarTaskDragTipSource.grid}
      : const <CalendarTaskDragTipSource>{CalendarTaskDragTipSource.sidebar};
}

class _CalendarTaskDragTipHostState extends State<CalendarTaskDragTipHost> {
  bool _tipShown = true;
  bool _tipStateLoaded = false;
  bool _tipCompletedThisSession = false;
  String? _loadedAccountJid;

  bool get _accountAvailable => widget.accountJid?.trim().isNotEmpty == true;

  bool get _tipReady =>
      widget.enabled && _accountAvailable && _tipStateLoaded && !_tipShown;

  bool get _tipPending => _tipReady && !widget.dragActive;

  @override
  void initState() {
    super.initState();
    _loadTipState();
  }

  @override
  void didUpdateWidget(covariant CalendarTaskDragTipHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountJid != widget.accountJid) {
      _tipCompletedThisSession = false;
    }
    if (oldWidget.accountJid != widget.accountJid ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.alwaysShow != widget.alwaysShow) {
      _tipShown = true;
      _tipStateLoaded = false;
      _loadedAccountJid = null;
      _loadTipState();
    }
    if (!oldWidget.dragActive && widget.dragActive && _tipReady) {
      _markTipShown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CalendarTaskDragTipSourceScope(
      visibleSources: widget.visibleSources,
      child: OnboardingTipArena(
        kind: OnboardingTipKind.calendarTaskDrag,
        enabled: _tipPending,
        identity: (accountJid: widget.accountJid),
        candidateIdentity: (
          rescanIdentity: widget.rescanIdentity,
          visibleSources: _calendarTaskDragTipVisibleSourceKey(
            widget.visibleSources,
          ),
        ),
        lowMotion: context.watch<SettingsCubit>().state.lowMotion,
        onCompleted: _markTipShown,
        child: widget.child,
      ),
    );
  }

  String _calendarTaskDragTipVisibleSourceKey(
    Set<CalendarTaskDragTipSource> visibleSources,
  ) {
    final sourceNames = visibleSources.map((source) => source.name).toList()
      ..sort();
    return sourceNames.join('|');
  }

  void _loadTipState() {
    final accountJid = widget.accountJid;
    if (!widget.enabled || accountJid == null || accountJid.trim().isEmpty) {
      _loadedAccountJid = null;
      _tipShown = true;
      _tipStateLoaded = true;
      return;
    }
    _loadedAccountJid = accountJid;
    if (widget.alwaysShow) {
      _tipShown = false;
      _tipStateLoaded = true;
      return;
    }
    final settingsCubit = context.read<SettingsCubit>();
    unawaited(
      settingsCubit.calendarTaskDragTipShownFor(accountJid).then((shown) {
        if (!mounted || _loadedAccountJid != accountJid) {
          return;
        }
        setState(() {
          _tipShown = _calendarTaskDragTipShownFromStored(
            storedShown: shown,
            alwaysShow: false,
            completedThisSession: _tipCompletedThisSession,
          );
          _tipStateLoaded = true;
        });
      }),
    );
  }

  void _markTipShown() {
    if (!mounted || _tipShown) {
      return;
    }
    _tipCompletedThisSession = true;
    setState(() {
      _tipShown = true;
      _tipStateLoaded = true;
    });
    if (widget.alwaysShow) {
      return;
    }
    unawaited(
      context.read<SettingsCubit>().markCalendarTaskDragTipShownFor(
        widget.accountJid,
      ),
    );
  }
}

class _CalendarTaskDragTipSourceScope extends InheritedWidget {
  const _CalendarTaskDragTipSourceScope({
    required this.visibleSources,
    required super.child,
  });

  final Set<CalendarTaskDragTipSource> visibleSources;

  static _CalendarTaskDragTipSourceScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_CalendarTaskDragTipSourceScope>();
  }

  @override
  bool updateShouldNotify(covariant _CalendarTaskDragTipSourceScope oldWidget) {
    return !setEquals(oldWidget.visibleSources, visibleSources);
  }
}
