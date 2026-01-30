// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/xmpp_activity/bloc/xmpp_activity_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class XmppOperationOverlay extends StatefulWidget {
  const XmppOperationOverlay({super.key});

  @override
  State<XmppOperationOverlay> createState() => _XmppOperationOverlayState();
}

class _XmppOperationOverlayState extends State<XmppOperationOverlay> {
  final List<_ToastEntry> _entries = <_ToastEntry>[];
  final Map<String, Timer> _exitTimers = <String, Timer>{};

  @override
  void initState() {
    super.initState();
    _syncOperations(context.read<XmppActivityCubit>().state.operations);
  }

  @override
  void dispose() {
    for (final timer in _exitTimers.values) {
      timer.cancel();
    }
    _exitTimers.clear();
    super.dispose();
  }

  void _syncOperations(List<XmppOperation> operations) {
    final List<XmppOperation> coalesced = _coalesceOperations(operations);
    final Map<String, XmppOperation> incoming = <String, XmppOperation>{
      for (final operation in coalesced) operation.id: operation,
    };
    final Set<String> rawOperationIds = {
      for (final operation in operations) operation.id,
    };
    var shouldRebuild = false;
    final List<String> removalQueue = <String>[];

    for (final entry in _entries) {
      final XmppOperation? updated = incoming.remove(entry.operation.id);
      if (updated == null) {
        if (!rawOperationIds.contains(entry.operation.id) ||
            entry.operation.kind == XmppOperationKind.pubSubFetch) {
          removalQueue.add(entry.operation.id);
        }
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

    for (final id in removalQueue) {
      _removeEntry(id);
      shouldRebuild = true;
    }

    for (final operation in coalesced) {
      if (incoming.containsKey(operation.id)) {
        _insertEntry(operation);
        shouldRebuild = true;
      }
    }

    if (shouldRebuild) {
      setState(() {});
    }
  }

  void _insertEntry(XmppOperation operation) {
    if (operation.status != XmppOperationStatus.inProgress) {
      return;
    }
    if (_entries.any((entry) => entry.operation.id == operation.id)) {
      return;
    }
    _entries.insert(0, _ToastEntry(operation: operation));
  }

  void _scheduleExit(String id, Duration delay) {
    _cancelExitTimer(id);
    _exitTimers[id] = Timer(delay, () {
      if (!mounted) return;
      _removeEntry(id);
    });
  }

  void _ensureExitScheduled(String id) {
    if (_exitTimers.containsKey(id)) {
      return;
    }
    _scheduleExit(id, context.motion.statusBannerSuccessDuration);
  }

  void _cancelExitTimer(String id) {
    final Timer? timer = _exitTimers.remove(id);
    timer?.cancel();
  }

  void _removeEntry(String id) {
    _cancelExitTimer(id);
    _entries.removeWhere((entry) => entry.operation.id == id);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<XmppActivityCubit, XmppActivityState>(
      listener: (context, state) => _syncOperations(state.operations),
      child: IgnorePointer(
        ignoring: true,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.only(
              left: context.spacing.m + MediaQuery.of(context).viewPadding.left,
              right:
                  context.spacing.m + MediaQuery.of(context).viewPadding.right,
              bottom: context.spacing.l + _resolveBottomInset(context),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.sizing.menuMaxWidth,
                maxHeight: context.sizing.menuMaxHeight,
              ),
              child: ListView.builder(
                reverse: true,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
                clipBehavior: Clip.none,
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final _ToastEntry entry = _entries[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: context.spacing.s),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InBoundsFadeScale(
                        key: ValueKey(entry.operation.id),
                        child: _XmppOperationToast(operation: entry.operation),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _resolveBottomInset(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final viewPadding = MediaQuery.of(context).viewPadding.bottom;
    if (viewInsets > viewPadding) {
      return viewInsets;
    }
    return viewPadding;
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

class _XmppOperationToast extends StatelessWidget {
  const _XmppOperationToast({required this.operation});

  final XmppOperation operation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isFailure = operation.status == XmppOperationStatus.failure;
    final surfaceColor = isFailure ? colorScheme.destructive : colorScheme.card;
    final textColor =
        isFailure ? colorScheme.destructiveForeground : colorScheme.foreground;

    return AxiModalSurface(
      backgroundColor: surfaceColor,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.m,
          vertical: context.spacing.s,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OperationStatusIcon(status: operation.status),
            SizedBox(width: context.spacing.s),
            Flexible(
              child: Text(
                operation.statusLabel(),
                style: context.textTheme.p.copyWith(
                  color: textColor,
                ),
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
    final colorScheme = context.colorScheme;
    return switch (status) {
      XmppOperationStatus.inProgress => AxiProgressIndicator(
          color: colorScheme.primary,
        ),
      XmppOperationStatus.success => Icon(
          Icons.check_circle_rounded,
          size: context.sizing.iconButtonIconSize,
          color: colorScheme.primary,
        ),
      XmppOperationStatus.failure => Icon(
          Icons.error_rounded,
          size: context.sizing.iconButtonIconSize,
          color: colorScheme.destructiveForeground,
        ),
    };
  }
}

class _ToastEntry {
  _ToastEntry({required this.operation});

  XmppOperation operation;
}
