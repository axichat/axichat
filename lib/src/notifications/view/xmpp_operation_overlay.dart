// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/ui/settings_cubit_lookup.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
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
  final Map<String, Timer> _removalTimers = <String, Timer>{};

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncOperations(context.read<XmppActivityCubit>().state.operations);
  }

  @override
  void dispose() {
    for (final timer in _exitTimers.values) {
      timer.cancel();
    }
    _exitTimers.clear();
    for (final timer in _removalTimers.values) {
      timer.cancel();
    }
    _removalTimers.clear();
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
    final animationDuration = _resolveAnimationDuration();
    final exitDelay = _resolveExitDelay(animationDuration);

    for (final entry in _entries) {
      final XmppOperation? updated = incoming.remove(entry.operation.id);
      if (updated == null) {
        if (!rawOperationIds.contains(entry.operation.id) ||
            entry.operation.kind == XmppOperationKind.pubSubFetch) {
          removalQueue.add(entry.operation.id);
        }
        continue;
      }
      final statusChanged = updated.status != entry.operation.status ||
          updated.startedAt != entry.operation.startedAt;
      if (statusChanged) {
        entry.operation = updated;
        shouldRebuild = true;
      }
      var visibilityRestored = false;
      final shouldRestoreVisibility = !entry.isVisible &&
          (updated.status == XmppOperationStatus.inProgress || statusChanged);
      if (shouldRestoreVisibility) {
        entry.isVisible = true;
        _cancelRemovalTimer(updated.id);
        visibilityRestored = true;
        shouldRebuild = true;
      }
      if (updated.status == XmppOperationStatus.inProgress) {
        _cancelExitTimer(updated.id);
        _cancelRemovalTimer(updated.id);
      } else if (!entry.isVisible) {
        _cancelExitTimer(updated.id);
      } else if (statusChanged || visibilityRestored) {
        _scheduleExit(updated.id, exitDelay, animationDuration);
      } else {
        _ensureExitScheduled(updated.id, exitDelay, animationDuration);
      }
    }

    for (final id in removalQueue) {
      if (_startExitNow(id, animationDuration)) {
        shouldRebuild = true;
      }
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

  void _scheduleExit(String id, Duration delay, Duration animationDuration) {
    _cancelExitTimer(id);
    _exitTimers[id] = Timer(delay, () {
      if (!mounted) {
        return;
      }
      final changed = _setEntryVisibility(id, false);
      if (changed) {
        setState(() {});
      }
      _scheduleRemoval(id, animationDuration);
    });
  }

  void _ensureExitScheduled(
    String id,
    Duration delay,
    Duration animationDuration,
  ) {
    if (_exitTimers.containsKey(id)) {
      return;
    }
    _scheduleExit(id, delay, animationDuration);
  }

  void _cancelExitTimer(String id) {
    final Timer? timer = _exitTimers.remove(id);
    timer?.cancel();
  }

  void _cancelRemovalTimer(String id) {
    final Timer? timer = _removalTimers.remove(id);
    timer?.cancel();
  }

  bool _startExitNow(String id, Duration animationDuration) {
    _cancelExitTimer(id);
    _cancelRemovalTimer(id);
    if (!_hasEntry(id)) {
      return false;
    }
    final changed = _setEntryVisibility(id, false);
    _scheduleRemoval(id, animationDuration);
    return changed;
  }

  void _scheduleRemoval(String id, Duration animationDuration) {
    _cancelRemovalTimer(id);
    _removalTimers[id] = Timer(animationDuration, () {
      if (!mounted) {
        return;
      }
      _removeEntry(id);
      setState(() {});
    });
  }

  bool _hasEntry(String id) {
    return _entries.any((entry) => entry.operation.id == id);
  }

  bool _setEntryVisibility(String id, bool isVisible) {
    for (final entry in _entries) {
      if (entry.operation.id == id) {
        if (entry.isVisible == isVisible) {
          return false;
        }
        entry.isVisible = isVisible;
        return true;
      }
    }
    return false;
  }

  void _removeEntry(String id) {
    _cancelExitTimer(id);
    _cancelRemovalTimer(id);
    _entries.removeWhere((entry) => entry.operation.id == id);
  }

  Duration _resolveAnimationDuration() {
    return maybeSettingsCubit(context)?.animationDuration ??
        context.motion.statusBannerSuccessDuration;
  }

  Duration _resolveExitDelay(Duration animationDuration) {
    final totalDuration = context.motion.statusBannerSuccessDuration;
    final delay = totalDuration - animationDuration;
    return delay.isNegative ? Duration.zero : delay;
  }

  @override
  Widget build(BuildContext context) {
    final animationDuration = maybeSettingsCubit(context) == null
        ? context.motion.statusBannerSuccessDuration
        : context.select<SettingsCubit, Duration>(
            (cubit) => cubit.animationDuration,
          );
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
                      child: _AnimatedToast(
                        key: ValueKey(entry.operation.id),
                        isVisible: entry.isVisible,
                        duration: animationDuration,
                        child: InBoundsFadeScale(
                          child:
                              _XmppOperationToast(operation: entry.operation),
                        ),
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
    final l10n = context.l10n;
    final statusLabel = _resolveOperationLabel(l10n, operation.labelKey);
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
                statusLabel,
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
  _ToastEntry({required this.operation}) : isVisible = true;

  XmppOperation operation;
  bool isVisible;
}

class _AnimatedToast extends StatelessWidget {
  const _AnimatedToast({
    required this.isVisible,
    required this.duration,
    required this.child,
    super.key,
  });

  final bool isVisible;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topLeft,
      child: AnimatedSlide(
        offset:
            isVisible ? Offset.zero : context.motion.statusBannerSlideOffset,
        duration: duration,
        curve: Curves.easeInOutCubic,
        child: AnimatedOpacity(
          opacity: isVisible ? 1 : 0,
          duration: duration,
          curve: Curves.easeInOutCubic,
          child: child,
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
    XmppOperationLabelKey.pubSubEmailBlocklistStart =>
      l10n.xmppOperationPubSubEmailBlocklistStart,
    XmppOperationLabelKey.pubSubEmailBlocklistSuccess =>
      l10n.xmppOperationPubSubEmailBlocklistSuccess,
    XmppOperationLabelKey.pubSubEmailBlocklistFailure =>
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
    XmppOperationLabelKey.mamLoginStart => l10n.xmppOperationMamLoginStart,
    XmppOperationLabelKey.mamLoginSuccess => l10n.xmppOperationMamLoginSuccess,
    XmppOperationLabelKey.mamLoginFailure => l10n.xmppOperationMamLoginFailure,
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
    XmppOperationLabelKey.mucJoinStart => l10n.xmppOperationMucJoinStart,
    XmppOperationLabelKey.mucJoinSuccess => l10n.xmppOperationMucJoinSuccess,
    XmppOperationLabelKey.mucJoinFailure => l10n.xmppOperationMucJoinFailure,
  };
}
