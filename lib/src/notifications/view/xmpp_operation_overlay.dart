// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/ui/settings_cubit_lookup.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp_activity/bloc/xmpp_activity_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double _overlayHorizontalPadding = 16.0;
const double _overlayBottomPadding = 32.0;
const double _overlayMaxWidth = 320.0;
const double _overlayMaxHeight = 320.0;
const double _overlayVerticalPadding = 4.0;
const double _overlayItemSpacing = 8.0;
const double _toastShadowPadding = 6.0;
const double _toastBorderRadius = 12.0;
const double _toastShadowBlur = 12.0;
const double _toastShadowOffsetY = 8.0;
const double _toastOpacity = 0.92;
const double _toastShadowAlpha = 0.14;
const double _toastHorizontalPadding = 16.0;
const double _toastVerticalPadding = 12.0;
const double _iconTextSpacing = 12.0;
const double _progressIndicatorSize = 18.0;
const double _progressIndicatorStrokeWidth = 2.2;
const double _statusIconSize = 20.0;
const double _surfaceBackgroundAlpha = 0.12;
const Duration _entryFallbackDuration = Duration(milliseconds: 300);
const Duration _completionExitDelay = Duration(seconds: 1);
const double _entryOpacityStart = 0.0;
const double _entryOpacityEnd = 1.0;
const double _entrySizeStart = 0.0;
const double _entrySizeEnd = 1.0;
const double _entrySlideXOffset = 0.22;
const double _entrySlideYOffset = 0.0;
const Curve _entryAnimationCurve = Curves.easeOutCubic;
const Curve _exitAnimationCurve = Curves.easeInCubic;

const EdgeInsets _toastPadding = EdgeInsets.symmetric(
  horizontal: _toastHorizontalPadding,
  vertical: _toastVerticalPadding,
);
const EdgeInsets _overlayListPadding = EdgeInsets.symmetric(
  vertical: _overlayVerticalPadding,
);

class XmppOperationOverlay extends StatefulWidget {
  const XmppOperationOverlay({super.key});

  @override
  State<XmppOperationOverlay> createState() => _XmppOperationOverlayState();
}

class _XmppOperationOverlayState extends State<XmppOperationOverlay> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<_ToastEntry> _entries = <_ToastEntry>[];
  final List<XmppOperation> _pendingInsertions = <XmppOperation>[];
  final Map<String, Timer> _exitTimers = <String, Timer>{};
  Timer? _insertTimer;
  bool _isInsertAnimating = false;

  @override
  void initState() {
    super.initState();
    final operations = _coalesceOperations(
      context.read<XmppActivityCubit>().state.operations,
    );
    _syncOperations(operations);
  }

  @override
  void dispose() {
    _insertTimer?.cancel();
    for (final timer in _exitTimers.values) {
      timer.cancel();
    }
    _exitTimers.clear();
    super.dispose();
  }

  Duration _entryDuration() {
    final SettingsCubit? settingsCubit = maybeSettingsCubit(context);
    if (settingsCubit == null) {
      return _entryFallbackDuration;
    }
    return settingsCubit.animationDuration;
  }

  void _syncOperations(List<XmppOperation> operations) {
    final Map<String, XmppOperation> incoming = <String, XmppOperation>{
      for (final operation in operations) operation.id: operation,
    };
    var shouldRebuild = false;

    for (final entry in _entries) {
      final XmppOperation? updated = incoming.remove(entry.operation.id);
      if (updated == null) {
        // Ignore transient gaps so existing toasts only change on explicit
        // completion updates.
        continue;
      }
      if (updated.status != entry.operation.status ||
          updated.startedAt != entry.operation.startedAt) {
        entry.operation = updated;
        shouldRebuild = true;
        if (updated.status == XmppOperationStatus.inProgress) {
          _cancelExitTimer(updated.id);
        } else {
          _ensureExitScheduled(updated.id);
        }
      }
    }

    _syncPendingInsertions(operations);
    for (final operation in operations) {
      if (incoming.containsKey(operation.id)) {
        _queueInsertion(operation);
      }
    }

    if (shouldRebuild) {
      setState(() {});
    }
  }

  void _syncPendingInsertions(List<XmppOperation> operations) {
    final Map<String, XmppOperation> incoming = <String, XmppOperation>{
      for (final operation in operations) operation.id: operation,
    };
    _pendingInsertions.removeWhere((pending) {
      final XmppOperation? updated = incoming[pending.id];
      return updated == null ||
          updated.status != XmppOperationStatus.inProgress;
    });
    for (var index = 0; index < _pendingInsertions.length; index += 1) {
      final pending = _pendingInsertions[index];
      final XmppOperation? updated = incoming[pending.id];
      if (updated != null && updated != pending) {
        _pendingInsertions[index] = updated;
      }
    }
  }

  void _queueInsertion(XmppOperation operation) {
    if (operation.status != XmppOperationStatus.inProgress) {
      return;
    }
    if (_entries.any((entry) => entry.operation.id == operation.id)) {
      return;
    }
    final int pendingIndex =
        _pendingInsertions.indexWhere((entry) => entry.id == operation.id);
    if (pendingIndex != -1) {
      _pendingInsertions[pendingIndex] = operation;
      return;
    }
    _pendingInsertions.add(operation);
    _processInsertQueue();
  }

  void _processInsertQueue() {
    if (!mounted || _isInsertAnimating || _pendingInsertions.isEmpty) {
      return;
    }
    if (_listKey.currentState == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _processInsertQueue());
      return;
    }
    final XmppOperation operation = _pendingInsertions.removeAt(0);
    XmppOperation? latest;
    for (final candidate
        in context.read<XmppActivityCubit>().state.operations) {
      if (candidate.id == operation.id) {
        latest = candidate;
        break;
      }
    }
    if (latest == null || latest.status != XmppOperationStatus.inProgress) {
      _isInsertAnimating = false;
      _processInsertQueue();
      return;
    }
    final _ToastEntry entry = _ToastEntry(operation: latest);
    _isInsertAnimating = true;
    _entries.insert(0, entry);
    _listKey.currentState?.insertItem(0, duration: _entryDuration());
    setState(() {});
    _startInsertCooldown();
  }

  void _startInsertCooldown() {
    _insertTimer?.cancel();
    final duration = _entryDuration();
    if (duration == Duration.zero) {
      _isInsertAnimating = false;
      _processInsertQueue();
      return;
    }
    _insertTimer = Timer(duration, () {
      if (!mounted) return;
      _isInsertAnimating = false;
      _processInsertQueue();
    });
  }

  void _scheduleExit(String id) {
    _cancelExitTimer(id);
    _exitTimers[id] = Timer(_completionExitDelay, () {
      if (!mounted) return;
      _removeEntry(id);
    });
  }

  void _ensureExitScheduled(String id) {
    if (_exitTimers.containsKey(id)) {
      return;
    }
    _scheduleExit(id);
  }

  void _cancelExitTimer(String id) {
    final Timer? timer = _exitTimers.remove(id);
    timer?.cancel();
  }

  void _removeEntry(String id) {
    _cancelExitTimer(id);
    final int index = _entries.indexWhere((entry) => entry.operation.id == id);
    if (index == -1) {
      return;
    }
    final _ToastEntry entry = _entries.removeAt(index)..isRemoving = true;
    _listKey.currentState?.removeItem(
      index,
      (context, animation) {
        return XmppOperationAnimatedItem(
          operation: entry.operation,
          animation: animation,
        );
      },
      duration: _entryDuration(),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<XmppActivityCubit, XmppActivityState>(
      listener: (context, state) =>
          _syncOperations(_coalesceOperations(state.operations)),
      child: IgnorePointer(
        ignoring: true,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.only(
              left: _overlayHorizontalPadding +
                  MediaQuery.of(context).viewPadding.left,
              right: _overlayHorizontalPadding +
                  MediaQuery.of(context).viewPadding.right,
              bottom: _overlayBottomPadding +
                  (MediaQuery.of(context).viewInsets.bottom >
                          MediaQuery.of(context).viewPadding.bottom
                      ? MediaQuery.of(context).viewInsets.bottom
                      : MediaQuery.of(context).viewPadding.bottom),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _overlayMaxWidth,
                maxHeight: _overlayMaxHeight,
              ),
              child: AnimatedList(
                key: _listKey,
                reverse: true,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: _overlayListPadding,
                clipBehavior: Clip.none,
                initialItemCount: _entries.length,
                itemBuilder: (context, index, animation) {
                  final _ToastEntry entry = _entries[index];
                  return XmppOperationAnimatedItem(
                    operation: entry.operation,
                    animation: animation,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<XmppOperation> _coalesceOperations(List<XmppOperation> operations) {
    XmppOperation? pubSubFetchOperation;
    final List<XmppOperation> resolved = <XmppOperation>[];
    for (final operation in operations) {
      if (operation.kind != XmppOperationKind.pubSubFetch) {
        resolved.add(operation);
        continue;
      }
      if (pubSubFetchOperation == null) {
        pubSubFetchOperation = operation;
        continue;
      }
      if (pubSubFetchOperation.status != XmppOperationStatus.inProgress &&
          operation.status == XmppOperationStatus.inProgress) {
        pubSubFetchOperation = operation;
        continue;
      }
      if (pubSubFetchOperation.status == XmppOperationStatus.inProgress &&
          operation.status != XmppOperationStatus.inProgress) {
        continue;
      }
      if (operation.startedAt.isAfter(pubSubFetchOperation.startedAt)) {
        pubSubFetchOperation = operation;
      }
    }
    if (pubSubFetchOperation != null) {
      resolved.add(pubSubFetchOperation);
    }
    return resolved;
  }
}

class XmppOperationAnimatedItem extends StatelessWidget {
  const XmppOperationAnimatedItem({
    super.key,
    required this.operation,
    required this.animation,
  });

  final XmppOperation operation;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation curve = CurvedAnimation(
      parent: animation,
      curve: _entryAnimationCurve,
      reverseCurve: _exitAnimationCurve,
    );
    final Animation<double> fadeAnimation = Tween<double>(
      begin: _entryOpacityStart,
      end: _entryOpacityEnd,
    ).animate(curve);
    final Animation<double> sizeAnimation = Tween<double>(
      begin: _entrySizeStart,
      end: _entrySizeEnd,
    ).animate(curve);
    final Animation<Offset> slideAnimation = Tween<Offset>(
      begin: const Offset(_entrySlideXOffset, _entrySlideYOffset),
      end: Offset.zero,
    ).animate(curve);
    return Padding(
      padding: const EdgeInsets.only(
        bottom: _overlayItemSpacing + _toastShadowPadding,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: curve,
          child: _XmppOperationToast(operation: operation),
          builder: (context, child) {
            return Align(
              alignment: Alignment.bottomLeft,
              heightFactor: sizeAnimation.value,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: SlideTransition(
                  position: slideAnimation,
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _XmppOperationToast extends StatelessWidget {
  const _XmppOperationToast({required this.operation});

  final XmppOperation operation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shadowColor = colorScheme.shadow.withValues(alpha: _toastShadowAlpha);
    final surfaceColor = switch (operation.status) {
      XmppOperationStatus.inProgress => colorScheme.surfaceContainerHigh,
      XmppOperationStatus.success => colorScheme.surfaceBright,
      XmppOperationStatus.failure => colorScheme.errorContainer,
    };
    final textColor = switch (operation.status) {
      XmppOperationStatus.failure => colorScheme.onErrorContainer,
      _ => colorScheme.onSurface,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: _toastOpacity),
        borderRadius: BorderRadius.circular(_toastBorderRadius),
        boxShadow: [
          BoxShadow(
            blurRadius: _toastShadowBlur,
            offset: const Offset(0, _toastShadowOffsetY),
            color: shadowColor,
          ),
        ],
      ),
      child: Padding(
        padding: _toastPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OperationStatusIcon(status: operation.status),
            const SizedBox(width: _iconTextSpacing),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    operation.statusLabel(),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: textColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationStatusIcon extends StatelessWidget {
  const _OperationStatusIcon({required this.status});

  final XmppOperationStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (status) {
      XmppOperationStatus.inProgress => SizedBox(
          height: _progressIndicatorSize,
          width: _progressIndicatorSize,
          child: CircularProgressIndicator(
            strokeWidth: _progressIndicatorStrokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            backgroundColor: colorScheme.onSurface
                .withValues(alpha: _surfaceBackgroundAlpha),
          ),
        ),
      XmppOperationStatus.success => Icon(
          Icons.check_circle_rounded,
          size: _statusIconSize,
          color: colorScheme.primary,
        ),
      XmppOperationStatus.failure => Icon(
          Icons.error_rounded,
          size: _statusIconSize,
          color: colorScheme.onErrorContainer,
        ),
    };
  }
}

class _ToastEntry {
  _ToastEntry({required this.operation}) : isRemoving = false;

  XmppOperation operation;
  bool isRemoving;
}
