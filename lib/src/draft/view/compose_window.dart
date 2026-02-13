// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/view/compose_draft_content.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ComposeWindowOverlay extends StatelessWidget {
  const ComposeWindowOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ComposeWindowCubit, ComposeWindowState>(
      builder: (context, state) {
        if (state.windows.isEmpty) return const SizedBox.shrink();
        final mediaQuery = MediaQuery.of(context);
        final mediaSize = mediaQuery.size;
        final viewPadding = mediaQuery.viewPadding;
        final viewInsets = mediaQuery.viewInsets;
        return LayoutBuilder(
          builder: (context, constraints) {
            final boundedSize = constraints.biggest;
            final viewportSize = Size(
              boundedSize.width.isFinite ? boundedSize.width : mediaSize.width,
              boundedSize.height.isFinite
                  ? boundedSize.height
                  : mediaSize.height,
            );
            return Stack(
              children: [
                for (var index = 0; index < state.windows.length; index++)
                  _ComposeWindowShell(
                    key: ValueKey(state.windows[index].id),
                    entry: state.windows[index],
                    index: index,
                    viewportSize: viewportSize,
                    viewPadding: viewPadding,
                    viewInsets: viewInsets,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ComposeWindowHeader extends StatelessWidget {
  const _ComposeWindowHeader({
    required this.id,
    required this.seed,
    required this.minimized,
    required this.expanded,
    required this.onMinimize,
    required this.onToggleExpanded,
    required this.onClose,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final int id;
  final ComposeDraftSeed seed;
  final bool minimized;
  final bool expanded;
  final VoidCallback onMinimize;
  final VoidCallback onToggleExpanded;
  final VoidCallback onClose;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final headerHeight = sizing.buttonHeightLg;
    final horizontalPadding = spacing.m;
    final gapSm = spacing.s;
    final gapMd = spacing.s;
    final subject = seed.subject.trim();
    final recipients =
        seed.jids.where((jid) => jid.trim().isNotEmpty).take(3).join(', ');
    final detailLabel = subject.isNotEmpty
        ? subject
        : (recipients.isNotEmpty ? recipients : l10n.draftNewMessage);
    final minimizeIcon = minimized ? LucideIcons.chevronUp : LucideIcons.minus;
    final expandIcon = expanded ? LucideIcons.minimize2 : LucideIcons.maximize2;

    return GestureDetector(
      onPanStart: onDragStart,
      onPanUpdate: onDragUpdate,
      onPanEnd: onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Container(
        height: headerHeight,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: colors.muted.withValues(alpha: context.motion.tapHoverAlpha),
          border: Border(
            bottom: BorderSide(
              color: colors.border,
              width: context.borderSide.width,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.pencilLine,
              size: sizing.iconButtonIconSize,
              color: colors.foreground,
            ),
            SizedBox(width: gapMd),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.composeTitle,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.small.copyWith(
                      color: colors.foreground,
                    ),
                  ),
                  SizedBox(height: spacing.xxs),
                  Text(
                    detailLabel,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.muted.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            _ComposeHeaderButton(
              tooltip: minimized ? l10n.draftRestore : l10n.draftMinimize,
              icon: minimizeIcon,
              onPressed: onMinimize,
            ),
            SizedBox(width: gapSm),
            _ComposeHeaderButton(
              tooltip: expanded ? l10n.draftExitFullscreen : l10n.draftExpand,
              icon: expandIcon,
              onPressed: onToggleExpanded,
            ),
            SizedBox(width: gapSm),
            _ComposeHeaderButton(
              tooltip: l10n.draftCloseComposer,
              icon: LucideIcons.x,
              onPressed: onClose,
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeHeaderButton extends StatelessWidget {
  const _ComposeHeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final foreground = destructive ? colors.destructive : colors.foreground;
    final sizing = context.sizing;
    return AxiTooltip(
      builder: (_) => Text(tooltip),
      child: AxiIconButton(
        iconData: icon,
        semanticLabel: tooltip,
        onPressed: onPressed,
        color: foreground,
        backgroundColor: colors.card,
        borderColor: colors.border,
        borderWidth: context.borderSide.width,
        buttonSize: sizing.iconButtonSize,
        tapTargetSize: sizing.iconButtonTapTarget,
        iconSize: sizing.iconButtonIconSize,
        cornerRadius: context.radii.squircle,
      ),
    );
  }
}

class _ComposeWindowBody extends StatelessWidget {
  const _ComposeWindowBody({
    required this.id,
    super.key,
    required this.seed,
    required this.availableHeight,
  });

  final int id;
  final ComposeDraftSeed seed;
  final double availableHeight;

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    return SizedBox(
      height: availableHeight,
      child: ComposeDraftContent(
        seed: seed,
        locate: locate,
        onClosed: () => context.read<ComposeWindowCubit>().closeWindow(id),
        onDiscarded: () => context.read<ComposeWindowCubit>().closeWindow(id),
        onDraftSaved: (draftId) =>
            context.read<ComposeWindowCubit>().recordDraftId(id, draftId),
      ),
    );
  }
}

class _ComposeWindowShell extends StatefulWidget {
  const _ComposeWindowShell({
    super.key,
    required this.entry,
    required this.index,
    required this.viewportSize,
    required this.viewPadding,
    required this.viewInsets,
  });

  final ComposeWindowEntry entry;
  final int index;
  final Size viewportSize;
  final EdgeInsets viewPadding;
  final EdgeInsets viewInsets;

  @override
  State<_ComposeWindowShell> createState() => _ComposeWindowShellState();
}

class _ComposeWindowShellState extends State<_ComposeWindowShell> {
  Offset? _dragStartPosition;
  Offset? _pointerStart;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final mediaSize = widget.viewportSize;
    final colors = context.colorScheme;
    final sizing = context.sizing;
    final isMinimized = entry.isMinimized;
    final isExpanded = entry.isExpanded;

    final windowPadding = sizing.composeWindowPadding;
    final headerHeight = sizing.buttonHeightLg;
    final baseWidth = sizing.composeWindowWidth;
    final expandedWidth = sizing.composeWindowExpandedWidth;
    final minWidth = sizing.composeWindowMinWidth;
    final stackOffset = sizing.composeWindowStackOffset;
    final baseHeight = sizing.composeWindowHeight;
    final expandedHeight = sizing.composeWindowExpandedHeight;
    final minHeight = sizing.composeWindowMinHeight;
    final systemInsets = _systemInsets(
      viewPadding: widget.viewPadding,
      viewInsets: widget.viewInsets,
    );

    final double availableWidth = math.max(
      mediaSize.width -
          (windowPadding * 2) -
          systemInsets.left -
          systemInsets.right,
      0,
    );
    final double targetWidth = math.max(
      math.min(
        isExpanded ? expandedWidth : baseWidth,
        availableWidth,
      ),
      math.min(availableWidth, minWidth),
    );

    final double availableHeight = math.max(
      mediaSize.height -
          (windowPadding * 2) -
          systemInsets.top -
          systemInsets.bottom,
      0,
    );
    final double normalHeight = math.max(
      math.min(
        isExpanded ? expandedHeight : baseHeight,
        availableHeight,
      ),
      math.min(availableHeight, minHeight),
    );
    final double targetHeight = isMinimized ? headerHeight : normalHeight;
    final double collapseOffset = isMinimized ? normalHeight - targetHeight : 0;
    final double bodyHeight = math.max(targetHeight - headerHeight, 0);

    final resolvedOffset = _resolveOffset(
      entry: entry,
      viewportSize: mediaSize,
      viewPadding: widget.viewPadding,
      viewInsets: widget.viewInsets,
      targetWidth: targetWidth,
      targetHeight: normalHeight,
      index: widget.index,
      windowPadding: windowPadding,
      stackOffset: stackOffset,
    );

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : baseAnimationDuration,
      curve: Curves.easeOutCubic,
      left: resolvedOffset.dx,
      top: resolvedOffset.dy + collapseOffset,
      width: targetWidth,
      height: targetHeight,
      child: InBoundsFadeScale(
        child: AxiModalSurface(
          padding: EdgeInsets.zero,
          backgroundColor: colors.card,
          borderColor: context.borderSide.color,
          cornerRadius: context.radii.container,
          shadows: calendarMediumShadow,
          child: Column(
            children: [
              _ComposeWindowHeader(
                id: entry.id,
                seed: entry.seed,
                minimized: isMinimized,
                expanded: isExpanded,
                onMinimize: () => isMinimized
                    ? context.read<ComposeWindowCubit>().restore(entry.id)
                    : context.read<ComposeWindowCubit>().minimize(entry.id),
                onToggleExpanded: () =>
                    context.read<ComposeWindowCubit>().toggleExpanded(entry.id),
                onClose: () =>
                    context.read<ComposeWindowCubit>().closeWindow(entry.id),
                onDragStart: (details) =>
                    _handleDragStart(details, resolvedOffset),
                onDragUpdate: (details) => _handleDragUpdate(
                  details,
                  targetWidth,
                  normalHeight,
                  windowPadding,
                ),
                onDragEnd: _handleDragEnd,
              ),
              Expanded(
                child: Offstage(
                  offstage: isMinimized,
                  child: AnimatedOpacity(
                    opacity: isMinimized ? 0 : 1,
                    duration: baseAnimationDuration,
                    curve: Curves.easeInOut,
                    child: _ComposeWindowBody(
                      key: ValueKey(entry.session),
                      id: entry.id,
                      seed: entry.seed,
                      availableHeight: bodyHeight,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Offset _resolveOffset({
    required ComposeWindowEntry entry,
    required Size viewportSize,
    required EdgeInsets viewPadding,
    required EdgeInsets viewInsets,
    required double targetWidth,
    required double targetHeight,
    required int index,
    required double windowPadding,
    required double stackOffset,
  }) {
    final spacing = context.spacing;
    final systemInsets = _systemInsets(
      viewPadding: viewPadding,
      viewInsets: viewInsets,
    );
    final horizontalInset = windowPadding + spacing.l;
    final defaultOffset = Offset(
      math.max(
        windowPadding + systemInsets.left,
        viewportSize.width -
            targetWidth -
            horizontalInset -
            systemInsets.right -
            (index * stackOffset),
      ),
      math.max(
        windowPadding + systemInsets.top,
        viewportSize.height -
            targetHeight -
            windowPadding -
            systemInsets.bottom -
            (index * stackOffset),
      ),
    );
    final clampedOffset = _clampOffset(
      offset: entry.offset ?? defaultOffset,
      viewportSize: viewportSize,
      viewPadding: viewPadding,
      viewInsets: viewInsets,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      windowPadding: windowPadding,
    );
    if (entry.offset == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ComposeWindowCubit>().initializeOffset(
              entry.id,
              clampedOffset,
            );
      });
    }
    return clampedOffset;
  }

  void _handleDragStart(DragStartDetails details, Offset currentOffset) {
    setState(() {
      _isDragging = true;
      _dragStartPosition = currentOffset;
      _pointerStart = details.globalPosition;
    });
  }

  void _handleDragUpdate(
    DragUpdateDetails details,
    double targetWidth,
    double targetHeight,
    double windowPadding,
  ) {
    final dragStart = _dragStartPosition;
    final pointerStart = _pointerStart;
    if (dragStart == null || pointerStart == null) return;
    final viewportSize = widget.viewportSize;
    final delta = details.globalPosition - pointerStart;
    final candidate = dragStart + delta;
    final clamped = _clampOffset(
      offset: candidate,
      viewportSize: viewportSize,
      viewPadding: widget.viewPadding,
      viewInsets: widget.viewInsets,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      windowPadding: windowPadding,
    );
    context.read<ComposeWindowCubit>().updateOffset(widget.entry.id, clamped);
  }

  void _handleDragEnd(DragEndDetails _) {
    setState(() {
      _isDragging = false;
      _dragStartPosition = null;
      _pointerStart = null;
    });
  }

  Offset _clampOffset({
    required Offset offset,
    required Size viewportSize,
    required EdgeInsets viewPadding,
    required EdgeInsets viewInsets,
    required double targetWidth,
    required double targetHeight,
    required double windowPadding,
  }) {
    final systemInsets = _systemInsets(
      viewPadding: viewPadding,
      viewInsets: viewInsets,
    );
    final maxX = math.max(
      windowPadding + systemInsets.left,
      viewportSize.width - targetWidth - windowPadding - systemInsets.right,
    );
    final maxY = math.max(
      windowPadding + systemInsets.top,
      viewportSize.height - targetHeight - windowPadding - systemInsets.bottom,
    );
    final dx = offset.dx.clamp(windowPadding + systemInsets.left, maxX);
    final dy = offset.dy.clamp(windowPadding + systemInsets.top, maxY);
    return Offset(dx, dy);
  }

  EdgeInsets _systemInsets({
    required EdgeInsets viewPadding,
    required EdgeInsets viewInsets,
  }) {
    return EdgeInsets.fromLTRB(
      math.max(viewPadding.left, viewInsets.left),
      math.max(viewPadding.top, viewInsets.top),
      math.max(viewPadding.right, viewInsets.right),
      math.max(viewPadding.bottom, viewInsets.bottom),
    );
  }
}
