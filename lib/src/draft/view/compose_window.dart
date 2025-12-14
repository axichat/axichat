import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/view/compose_draft_content.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _composeHeaderHeight = 48;
const double _composeWindowPadding = 12;
const double _composeWindowWidth = 520;
const double _composeWindowExpandedWidth = 720;
const double _composeWindowHeight = 560;
const double _composeWindowExpandedHeight = 640;
const double _composeWindowMinWidth = 360;
const double _composeWindowMinHeight = 260;

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
        return Stack(
          children: [
            for (var index = 0; index < state.windows.length; index++)
              _ComposeWindowShell(
                entry: state.windows[index],
                index: index,
                viewportSize: mediaSize,
                viewPadding: viewPadding,
              ),
          ],
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
        height: _composeHeaderHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.muted.withValues(alpha: 0.05),
          border: Border(
            bottom: BorderSide(color: colors.border),
          ),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.pencilLine,
              size: 18,
              color: colors.foreground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.composeTitle,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detailLabel,
                    overflow: TextOverflow.ellipsis,
                    style:
                        textTheme.muted.copyWith(color: colors.mutedForeground),
                  ),
                ],
              ),
            ),
            _ComposeHeaderButton(
              tooltip: minimized ? l10n.draftRestore : l10n.draftMinimize,
              icon: minimizeIcon,
              onPressed: onMinimize,
            ),
            const SizedBox(width: 6),
            _ComposeHeaderButton(
              tooltip: expanded ? l10n.draftExitFullscreen : l10n.draftExpand,
              icon: expandIcon,
              onPressed: onToggleExpanded,
            ),
            const SizedBox(width: 6),
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
    return AxiTooltip(
      builder: (_) => Text(tooltip),
      child: AxiIconButton(
        iconData: icon,
        semanticLabel: tooltip,
        onPressed: onPressed,
        color: foreground,
        backgroundColor: colors.card,
        borderColor: colors.border,
        borderWidth: 1.2,
        buttonSize: 34,
        tapTargetSize: 36,
        iconSize: 18,
        cornerRadius: 12,
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
    return SizedBox(
      height: availableHeight,
      child: ComposeDraftContent(
        seed: seed,
        onClosed: () => context.read<ComposeWindowCubit>().closeWindow(id),
        onDiscarded: () => context.read<ComposeWindowCubit>().closeWindow(id),
      ),
    );
  }
}

class _ComposeWindowShell extends StatefulWidget {
  const _ComposeWindowShell({
    required this.entry,
    required this.index,
    required this.viewportSize,
    required this.viewPadding,
  });

  final ComposeWindowEntry entry;
  final int index;
  final Size viewportSize;
  final EdgeInsets viewPadding;

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
    final cardRadius = context.radius;
    final isMinimized = entry.isMinimized;
    final isExpanded = entry.isExpanded;

    final double availableWidth =
        math.max(mediaSize.width - (_composeWindowPadding * 2), 0);
    final double targetWidth = math.max(
      math.min(
        isExpanded ? _composeWindowExpandedWidth : _composeWindowWidth,
        availableWidth,
      ),
      math.min(availableWidth, _composeWindowMinWidth),
    );

    final double availableHeight =
        math.max(mediaSize.height - (_composeWindowPadding * 2), 0);
    final double normalHeight = math.max(
      math.min(
        isExpanded ? _composeWindowExpandedHeight : _composeWindowHeight,
        availableHeight,
      ),
      math.min(availableHeight, _composeWindowMinHeight),
    );
    final double targetHeight =
        isMinimized ? _composeHeaderHeight : normalHeight;
    final double collapseOffset = isMinimized ? normalHeight - targetHeight : 0;
    final double bodyHeight = math.max(targetHeight - _composeHeaderHeight, 0);

    final resolvedOffset = _resolveOffset(
      entry: entry,
      viewportSize: mediaSize,
      viewPadding: widget.viewPadding,
      targetWidth: targetWidth,
      targetHeight: normalHeight,
      index: widget.index,
    );

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : baseAnimationDuration,
      curve: Curves.easeOutCubic,
      left: resolvedOffset.dx,
      top: resolvedOffset.dy + collapseOffset,
      width: targetWidth,
      height: targetHeight,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.card,
            shadows: calendarMediumShadow,
            shape: ContinuousRectangleBorder(
              borderRadius: cardRadius,
              side: BorderSide(color: colors.border),
            ),
          ),
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
                onClose: () => context.read<ComposeWindowCubit>().closeWindow(
                      entry.id,
                    ),
                onDragStart: (details) =>
                    _handleDragStart(details, resolvedOffset),
                onDragUpdate: (details) =>
                    _handleDragUpdate(details, targetWidth, normalHeight),
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
    required double targetWidth,
    required double targetHeight,
    required int index,
  }) {
    final defaultOffset = Offset(
      math.max(
        _composeWindowPadding + viewPadding.left,
        viewportSize.width -
            targetWidth -
            _composeWindowPadding -
            viewPadding.right -
            (index * 20),
      ),
      math.max(
        _composeWindowPadding + viewPadding.top,
        viewportSize.height -
            targetHeight -
            _composeWindowPadding -
            viewPadding.bottom -
            (index * 20),
      ),
    );
    final clamped = _clampOffset(
      offset: entry.offset ?? defaultOffset,
      viewportSize: viewportSize,
      viewPadding: viewPadding,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ComposeWindowCubit>().initializeOffset(entry.id, clamped);
    });
    return clamped;
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
      targetWidth: targetWidth,
      targetHeight: targetHeight,
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
    required double targetWidth,
    required double targetHeight,
  }) {
    final maxX = math.max(
      _composeWindowPadding + viewPadding.left,
      viewportSize.width -
          targetWidth -
          _composeWindowPadding -
          viewPadding.right,
    );
    final maxY = math.max(
      _composeWindowPadding + viewPadding.top,
      viewportSize.height -
          targetHeight -
          _composeWindowPadding -
          viewPadding.bottom,
    );
    final dx = offset.dx.clamp(_composeWindowPadding + viewPadding.left, maxX);
    final dy = offset.dy.clamp(_composeWindowPadding + viewPadding.top, maxY);
    return Offset(dx, dy);
  }
}
