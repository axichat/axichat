// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
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
  static const _completionExitDelay = Duration(seconds: 1);
  static const _reconciliationInterval = Duration(seconds: 1);
  static const _toastSlideOffset = Offset(0.22, 0.0);

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<_ToastEntry> _entries = <_ToastEntry>[];
  final List<XmppOperation> _pendingInsertions = <XmppOperation>[];
  final Map<String, Timer> _exitTimers = <String, Timer>{};
  Timer? _insertCooldownTimer;
  bool _isInsertAnimating = false;
  final List<String> _pendingRemovals = <String>[];
  Timer? _removalCooldownTimer;
  Timer? _reconciliationTimer;
  bool _isRemoving = false;

  @override
  void initState() {
    super.initState();
    _reconciliationTimer = Timer.periodic(_reconciliationInterval, (_) {
      if (!mounted) {
        return;
      }
      _runPeriodicReconciliation();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncOperations(context.read<XmppActivityCubit>().state.operations);
    });
  }

  @override
  void dispose() {
    for (final timer in _exitTimers.values.toList(growable: false)) {
      timer.cancel();
    }
    _exitTimers.clear();
    _insertCooldownTimer?.cancel();
    _removalCooldownTimer?.cancel();
    _reconciliationTimer?.cancel();
    super.dispose();
  }

  void _runPeriodicReconciliation() {
    _syncOperations(context.read<XmppActivityCubit>().state.operations);
    _pendingRemovals.removeWhere((id) {
      return _entries.indexWhere((entry) => entry.operation.id == id) == -1;
    });
    _pendingInsertions.removeWhere((pending) {
      return _entries.any((entry) => entry.operation.id == pending.id);
    });
    _processInsertQueue();
    _processRemovalQueue();
  }

  void _syncOperations(List<XmppOperation> operations) {
    final List<XmppOperation> visibleOperations = operations
        .where(_shouldDisplayOperation)
        .toList(growable: false);
    final List<XmppOperation> coalesced = _coalesceOperations(
      visibleOperations,
    );
    final Map<String, XmppOperation> incoming = <String, XmppOperation>{
      for (final operation in coalesced) operation.id: operation,
    };
    final Set<String> rawOperationIds = {
      for (final operation in visibleOperations) operation.id,
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
      final statusChanged =
          updated.status != entry.operation.status ||
          updated.startedAt != entry.operation.startedAt;
      if (statusChanged) {
        entry.operation = updated;
        shouldRebuild = true;
      }
      if (updated.status == XmppOperationStatus.inProgress) {
        _cancelExitTimer(updated.id);
        _cancelPendingRemoval(updated.id);
      } else {
        _ensureExitScheduled(updated.id);
      }
    }

    for (final id in removalQueue) {
      _queueRemoval(id);
    }

    _syncPendingInsertions(coalesced);
    for (final operation in coalesced) {
      if (incoming.containsKey(operation.id)) {
        _queueInsertion(operation);
      }
    }

    if (shouldRebuild) {
      setState(() {});
    }
  }

  bool _insertEntry(XmppOperation operation) {
    if (operation.status != XmppOperationStatus.inProgress) {
      return true;
    }
    if (_entries.any((entry) => entry.operation.id == operation.id)) {
      return true;
    }
    final listState = _listKey.currentState;
    if (listState == null) {
      return false;
    }
    final index = _entries.length;
    _entries.add(_ToastEntry(operation: operation));
    listState.insertItem(index, duration: _resolveAnimationDuration());
    return true;
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
    final int pendingIndex = _pendingInsertions.indexWhere(
      (entry) => entry.id == operation.id,
    );
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
    final XmppOperation operation = _pendingInsertions.removeAt(0);
    _isInsertAnimating = true;
    final inserted = _insertEntry(operation);
    if (!inserted) {
      _isInsertAnimating = false;
      _pendingInsertions.insert(0, operation);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _processInsertQueue();
      });
      return;
    }
    _startInsertCooldown();
  }

  void _startInsertCooldown() {
    _insertCooldownTimer?.cancel();
    final duration = _resolveAnimationDuration();
    if (duration == Duration.zero) {
      _isInsertAnimating = false;
      _processInsertQueue();
      return;
    }
    _insertCooldownTimer = Timer(duration, () {
      if (!mounted) {
        return;
      }
      _isInsertAnimating = false;
      _processInsertQueue();
    });
  }

  void _scheduleExit(String id) {
    _cancelExitTimer(id);
    _exitTimers[id] = Timer(_completionExitDelay, () {
      if (!mounted) {
        return;
      }
      _queueRemoval(id);
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

  void _cancelPendingRemoval(String id) {
    _pendingRemovals.removeWhere((pendingId) => pendingId == id);
  }

  void _queueRemoval(String id) {
    if (_pendingRemovals.contains(id)) {
      return;
    }
    if (_entries.indexWhere((entry) => entry.operation.id == id) == -1) {
      return;
    }
    _pendingRemovals.add(id);
    _processRemovalQueue();
  }

  void _processRemovalQueue() {
    if (!mounted || _isRemoving || _pendingRemovals.isEmpty) {
      return;
    }
    final id = _pendingRemovals.removeAt(0);
    if (_entries.indexWhere((entry) => entry.operation.id == id) == -1) {
      _processRemovalQueue();
      return;
    }
    _isRemoving = true;
    _removeEntry(id, animated: true);
    _startRemovalCooldown();
  }

  void _startRemovalCooldown() {
    _removalCooldownTimer?.cancel();
    final duration = _resolveAnimationDuration();
    if (duration == Duration.zero) {
      _isRemoving = false;
      _processRemovalQueue();
      return;
    }
    _removalCooldownTimer = Timer(duration, () {
      if (!mounted) {
        return;
      }
      _isRemoving = false;
      _processRemovalQueue();
    });
  }

  void _removeEntry(String id, {required bool animated}) {
    _cancelExitTimer(id);
    final index = _entries.indexWhere((entry) => entry.operation.id == id);
    if (index == -1) {
      return;
    }
    final removedEntry = _entries.removeAt(index);
    final listState = _listKey.currentState;
    if (!animated || listState == null) {
      setState(() {});
      return;
    }
    listState.removeItem(
      index,
      (context, animation) => _AnimatedToastListItem(
        operation: removedEntry.operation,
        animation: animation,
        removing: true,
      ),
      duration: _resolveAnimationDuration(),
    );
  }

  Duration _resolveAnimationDuration() {
    return context.read<SettingsCubit>().animationDuration;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isCompactDevice =
        mediaQuery.size.shortestSide < compactDeviceBreakpoint;
    final isCompactLayout =
        isCompactDevice || mediaQuery.size.width < smallScreen;
    final openJid = context.select<ChatsCubit, String?>(
      (cubit) => cubit.state.openJid,
    );
    final chatOpenOverlayFloorInset = openJid == null || !isCompactLayout
        ? 0.0
        : context.spacing.xl;
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
              bottom:
                  context.spacing.l +
                  _resolveBottomInset(context) +
                  chatOpenOverlayFloorInset,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.sizing.menuMaxWidth,
                maxHeight: context.sizing.menuMaxHeight,
              ),
              child: AnimatedList(
                key: _listKey,
                initialItemCount: _entries.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
                clipBehavior: Clip.none,
                itemBuilder: (context, index, animation) {
                  final _ToastEntry entry = _entries[index];
                  return _AnimatedToastListItem(
                    key: ValueKey<String>(entry.operation.id),
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

  bool _shouldDisplayOperation(XmppOperation operation) {
    if (operation.status == XmppOperationStatus.failure) {
      return true;
    }
    return switch (operation.kind) {
      XmppOperationKind.pubSubFetch => false,
      XmppOperationKind.pubSubAvatarMetadata => false,
      XmppOperationKind.mamFetch => false,
      _ => true,
    };
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
    final l10n = context.l10n;
    final statusLabel = _resolveOperationLabel(l10n, operation.labelKey);
    final isFailure = operation.status == XmppOperationStatus.failure;
    final surfaceColor = isFailure ? colorScheme.destructive : colorScheme.card;
    final textColor = isFailure
        ? colorScheme.destructiveForeground
        : colorScheme.foreground;

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
                statusLabel,
                style: context.textTheme.p.copyWith(color: textColor),
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

class _AnimatedToastListItem extends StatelessWidget {
  const _AnimatedToastListItem({
    required this.operation,
    required this.animation,
    this.removing = false,
    super.key,
  });

  static const _entryCurve = Curves.easeOutCubic;
  static const _exitCurve = Curves.easeInCubic;
  static const _entryOpacity = 0.0;
  static const _entrySize = 0.0;
  static const _exitMotionPhaseEnd = 0.72;

  final XmppOperation operation;
  final Animation<double> animation;
  final bool removing;

  @override
  Widget build(BuildContext context) {
    if (removing) {
      return _RemovingToastListItem(operation: operation, animation: animation);
    }
    return _EnteringToastListItem(operation: operation, animation: animation);
  }
}

class _EnteringToastListItem extends StatelessWidget {
  const _EnteringToastListItem({
    required this.operation,
    required this.animation,
  });

  final XmppOperation operation;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation curve = CurvedAnimation(
      parent: animation,
      curve: _AnimatedToastListItem._entryCurve,
    );
    final Animation<double> fadeAnimation = Tween<double>(
      begin: _AnimatedToastListItem._entryOpacity,
      end: 1.0,
    ).animate(curve);
    final Animation<Offset> slideAnimation = Tween<Offset>(
      begin: _XmppOperationOverlayState._toastSlideOffset,
      end: Offset.zero,
    ).animate(curve);

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.s),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: curve,
          child: _XmppOperationToast(operation: operation),
          builder: (context, child) {
            return Align(
              alignment: Alignment.bottomLeft,
              heightFactor:
                  _AnimatedToastListItem._entrySize +
                  (1.0 - _AnimatedToastListItem._entrySize) * curve.value,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: SlideTransition(position: slideAnimation, child: child),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RemovingToastListItem extends StatelessWidget {
  const _RemovingToastListItem({
    required this.operation,
    required this.animation,
  });

  final XmppOperation operation;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final Animation<double> removalProgress = CurvedAnimation(
      parent: ReverseAnimation(animation),
      curve: Curves.linear,
    );
    final Animation<double> motionCurve = CurvedAnimation(
      parent: removalProgress,
      curve: const Interval(
        0.0,
        _AnimatedToastListItem._exitMotionPhaseEnd,
        curve: _AnimatedToastListItem._exitCurve,
      ),
    );
    final Animation<double> collapseCurve = CurvedAnimation(
      parent: removalProgress,
      curve: const Interval(
        _AnimatedToastListItem._exitMotionPhaseEnd,
        1.0,
        curve: _AnimatedToastListItem._exitCurve,
      ),
    );
    final Animation<double> fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(motionCurve);
    final Animation<Offset> slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: _XmppOperationOverlayState._toastSlideOffset,
    ).animate(motionCurve);

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.s),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: removalProgress,
          child: _XmppOperationToast(operation: operation),
          builder: (context, child) {
            return Align(
              alignment: Alignment.bottomLeft,
              heightFactor: 1.0 - collapseCurve.value,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: SlideTransition(position: slideAnimation, child: child),
              ),
            );
          },
        ),
      ),
    );
  }
}

String _resolveOperationLabel(
  AppLocalizations l10n,
  XmppOperationLabelKey labelKey,
) {
  return switch (labelKey) {
    XmppOperationLabelKey.pubSubBookmarksStart =>
      l10n.xmppOperationPubSubBookmarksStart,
    XmppOperationLabelKey.pubSubBookmarksSuccess =>
      l10n.xmppOperationPubSubBookmarksSuccess,
    XmppOperationLabelKey.pubSubBookmarksFailure =>
      l10n.xmppOperationPubSubBookmarksFailure,
    XmppOperationLabelKey.pubSubConversationsStart =>
      l10n.xmppOperationPubSubConversationsStart,
    XmppOperationLabelKey.pubSubConversationsSuccess =>
      l10n.xmppOperationPubSubConversationsSuccess,
    XmppOperationLabelKey.pubSubConversationsFailure =>
      l10n.xmppOperationPubSubConversationsFailure,
    XmppOperationLabelKey.pubSubDraftsStart =>
      l10n.xmppOperationPubSubDraftsStart,
    XmppOperationLabelKey.pubSubDraftsSuccess =>
      l10n.xmppOperationPubSubDraftsSuccess,
    XmppOperationLabelKey.pubSubDraftsFailure =>
      l10n.xmppOperationPubSubDraftsFailure,
    XmppOperationLabelKey.pubSubSpamStart => l10n.xmppOperationPubSubSpamStart,
    XmppOperationLabelKey.pubSubSpamSuccess =>
      l10n.xmppOperationPubSubSpamSuccess,
    XmppOperationLabelKey.pubSubSpamFailure =>
      l10n.xmppOperationPubSubSpamFailure,
    XmppOperationLabelKey.pubSubAddressBlockStart =>
      l10n.xmppOperationPubSubEmailBlocklistStart,
    XmppOperationLabelKey.pubSubAddressBlockSuccess =>
      l10n.xmppOperationPubSubEmailBlocklistSuccess,
    XmppOperationLabelKey.pubSubAddressBlockFailure =>
      l10n.xmppOperationPubSubEmailBlocklistFailure,
    XmppOperationLabelKey.pubSubAvatarMetadataStart =>
      l10n.xmppOperationPubSubAvatarMetadataStart,
    XmppOperationLabelKey.pubSubAvatarMetadataSuccess =>
      l10n.xmppOperationPubSubAvatarMetadataSuccess,
    XmppOperationLabelKey.pubSubAvatarMetadataFailure =>
      l10n.xmppOperationPubSubAvatarMetadataFailure,
    XmppOperationLabelKey.pubSubFetchStart =>
      l10n.xmppOperationPubSubFetchStart,
    XmppOperationLabelKey.pubSubFetchSuccess =>
      l10n.xmppOperationPubSubFetchSuccess,
    XmppOperationLabelKey.pubSubFetchFailure =>
      l10n.xmppOperationPubSubFetchFailure,
    XmppOperationLabelKey.mamGlobalStart => l10n.xmppOperationMamGlobalStart,
    XmppOperationLabelKey.mamGlobalSuccess =>
      l10n.xmppOperationMamGlobalSuccess,
    XmppOperationLabelKey.mamGlobalFailure =>
      l10n.xmppOperationMamGlobalFailure,
    XmppOperationLabelKey.mamMucStart => l10n.xmppOperationMamMucStart,
    XmppOperationLabelKey.mamMucSuccess => l10n.xmppOperationMamMucSuccess,
    XmppOperationLabelKey.mamMucFailure => l10n.xmppOperationMamMucFailure,
    XmppOperationLabelKey.mamFetchStart => l10n.xmppOperationMamFetchStart,
    XmppOperationLabelKey.mamFetchSuccess => l10n.xmppOperationMamFetchSuccess,
    XmppOperationLabelKey.mamFetchFailure => l10n.xmppOperationMamFetchFailure,
    XmppOperationLabelKey.mucCreateStart => l10n.xmppOperationMucCreateStart,
    XmppOperationLabelKey.mucCreateSuccess =>
      l10n.xmppOperationMucCreateSuccess,
    XmppOperationLabelKey.mucCreateFailure =>
      l10n.xmppOperationMucCreateFailure,
    XmppOperationLabelKey.mucJoinStart => l10n.xmppOperationMucJoinStart,
    XmppOperationLabelKey.mucJoinSuccess => l10n.xmppOperationMucJoinSuccess,
    XmppOperationLabelKey.mucJoinFailure => l10n.xmppOperationMucJoinFailure,
    XmppOperationLabelKey.selfAvatarPublishStart =>
      l10n.xmppOperationSelfAvatarPublishStart,
    XmppOperationLabelKey.selfAvatarPublishSuccess =>
      l10n.xmppOperationSelfAvatarPublishSuccess,
    XmppOperationLabelKey.selfAvatarPublishFailure =>
      l10n.xmppOperationSelfAvatarPublishFailure,
  };
}
