// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/grid/calendar_drag_payload.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';

CalendarTask restoreCalendarTaskFromDragPayload(CalendarDragPayload payload) {
  final CalendarTask snapshot = payload.snapshot;
  final DateTime? originalStart =
      payload.pickupScheduledTime ??
      snapshot.scheduledTime ??
      payload.originSlot;
  if (originalStart != null) {
    return snapshot.withScheduled(
      scheduledTime: originalStart,
      duration: snapshot.duration,
      endDate: snapshot.endDate,
    );
  }
  return snapshot.copyWith(scheduledTime: null, endDate: snapshot.endDate);
}

class CalendarDragCancelBucket extends StatelessWidget {
  const CalendarDragCancelBucket({
    super.key,
    required this.visible,
    required this.bottomInset,
    required this.hovering,
    required this.onWillAcceptWithDetails,
    required this.onMove,
    required this.onLeave,
    required this.onAcceptWithDetails,
    this.focusNode,
    this.shortcuts,
    this.actions,
    this.semanticEnabled = true,
    this.onSemanticTap,
  });

  final bool visible;
  final double bottomInset;
  final bool hovering;
  final DragTargetWillAcceptWithDetails<CalendarDragPayload>
  onWillAcceptWithDetails;
  final DragTargetMove<CalendarDragPayload> onMove;
  final DragTargetLeave<CalendarDragPayload> onLeave;
  final DragTargetAcceptWithDetails<CalendarDragPayload> onAcceptWithDetails;
  final FocusNode? focusNode;
  final Map<ShortcutActivator, Intent>? shortcuts;
  final Map<Type, Action<Intent>>? actions;
  final bool semanticEnabled;
  final VoidCallback? onSemanticTap;

  @override
  Widget build(BuildContext context) {
    const duration = calendarSlotHoverAnimationDuration;
    const curve = Curves.easeInOutCubic;
    final double safeBottomPadding = math.max(bottomInset, 0.0);
    final double bucketHeight = context.sizing.buttonHeightLg;
    final double totalHeight = bucketHeight + safeBottomPadding;
    final double targetHeight = visible ? totalHeight : 0;
    final Widget bucket = SizedBox(
      width: double.infinity,
      height: totalHeight,
      child: DragTarget<CalendarDragPayload>(
        hitTestBehavior: HitTestBehavior.translucent,
        onWillAcceptWithDetails: onWillAcceptWithDetails,
        onMove: onMove,
        onLeave: onLeave,
        onAcceptWithDetails: onAcceptWithDetails,
        builder: (context, candidate, _) {
          final bool active = hovering || candidate.isNotEmpty;
          final colors = context.colorScheme;
          final fillColor = colors.destructive.withValues(
            alpha: active ? 0.24 : 0.12,
          );
          final borderColor = colors.destructive.withValues(
            alpha: active ? 0.42 : 0.18,
          );
          final foregroundColor = colors.destructive.withValues(
            alpha: active ? 1 : 0.82,
          );
          return AnimatedContainer(
            duration: duration,
            curve: curve,
            width: double.infinity,
            height: totalHeight,
            padding: EdgeInsets.only(bottom: safeBottomPadding),
            decoration: BoxDecoration(
              color: fillColor,
              border: Border(
                top: BorderSide(
                  color: borderColor,
                  width: context.borderSide.width,
                ),
              ),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.close_rounded,
                    color: foregroundColor,
                    size: context.sizing.menuItemIconSize,
                  ),
                  SizedBox(width: context.spacing.s),
                  Text(
                    context.l10n.commonCancel,
                    style: context.textTheme.label.strong.copyWith(
                      color: foregroundColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    final Widget semanticBucket = Semantics(
      button: true,
      enabled: semanticEnabled,
      label: context.l10n.commonCancel,
      hint: context.l10n.commonCancel,
      onTap: semanticEnabled ? onSemanticTap : null,
      child: bucket,
    );
    final Widget focusableBucket = focusNode == null
        ? semanticBucket
        : FocusableActionDetector(
            focusNode: focusNode,
            enabled: visible,
            shortcuts: shortcuts ?? const <ShortcutActivator, Intent>{},
            actions: actions ?? const <Type, Action<Intent>>{},
            child: semanticBucket,
          );
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      height: targetHeight,
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: curve,
        switchOutCurve: curve,
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: curve));
          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: !visible
            ? const SizedBox.shrink()
            : KeyedSubtree(
                key: const ValueKey('calendar.drag.cancel-bucket'),
                child: focusableBucket,
              ),
      ),
    );
  }
}
