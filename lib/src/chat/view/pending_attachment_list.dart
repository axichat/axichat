// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/models/chat_message.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PendingAttachmentList extends StatelessWidget {
  const PendingAttachmentList({
    super.key,
    required this.attachments,
    required this.onRetry,
    required this.onRemove,
    this.onPressed,
    this.onLongPress,
    this.contextMenuBuilder,
  });

  final List<PendingAttachment> attachments;
  final ValueChanged<PendingAttachment> onRetry;
  final ValueChanged<String> onRemove;
  final ValueChanged<PendingAttachment>? onPressed;
  final ValueChanged<PendingAttachment>? onLongPress;
  final List<Widget> Function(PendingAttachment pending)? contextMenuBuilder;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: spacing.m,
        runSpacing: spacing.m,
        children: attachments
            .map(
              (pending) => _PendingAttachmentPreview(
                pending: pending,
                onRetry: () => onRetry(pending),
                onRemove: () => onRemove(pending.id),
                onPressed: onPressed == null ? null : () => onPressed!(pending),
                onLongPress: onLongPress == null
                    ? null
                    : () => onLongPress!(pending),
                contextMenuBuilder: contextMenuBuilder,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PendingAttachmentPreview extends StatefulWidget {
  const _PendingAttachmentPreview({
    required this.pending,
    required this.onRetry,
    required this.onRemove,
    this.onPressed,
    this.onLongPress,
    this.contextMenuBuilder,
  });

  final PendingAttachment pending;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final List<Widget> Function(PendingAttachment pending)? contextMenuBuilder;

  @override
  State<_PendingAttachmentPreview> createState() =>
      _PendingAttachmentPreviewState();
}

class _PendingAttachmentPreviewState extends State<_PendingAttachmentPreview> {
  late final ShadContextMenuController _menuController =
      ShadContextMenuController();
  final AxiTapBounceController _bounceController = AxiTapBounceController();
  Future<FileTypeReport>? _typeReportFuture;
  String? _typeReportPath;

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PendingAttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String oldPath = oldWidget.pending.attachment.path.trim();
    final String newPath = widget.pending.attachment.path.trim();
    if (oldPath != newPath) {
      _typeReportPath = null;
      _typeReportFuture = null;
    }
  }

  void _showMenu() {
    if (!mounted) return;
    _menuController.show();
  }

  Future<FileTypeReport> _resolveTypeReport(Attachment attachment) {
    final String path = attachment.path.trim();
    final String? resolvedPath = path.isEmpty ? null : path;
    final Future<FileTypeReport>? cached = _typeReportFuture;
    if (cached != null && resolvedPath == _typeReportPath) {
      return cached;
    }
    _typeReportPath = resolvedPath;
    if (resolvedPath == null) {
      final FileTypeReport report = buildDeclaredFileTypeReport(
        declaredMimeType: attachment.mimeType,
        fileName: attachment.fileName,
        path: attachment.path,
      );
      return Future<FileTypeReport>.value(report);
    }
    final Future<FileTypeReport> nextFuture = inspectFileType(
      file: File(resolvedPath),
      declaredMimeType: attachment.mimeType,
      fileName: attachment.fileName,
    );
    _typeReportFuture = nextFuture;
    return nextFuture;
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.pending;
    Widget preview;
    if (pending.isPreparing) {
      preview = _PendingAttachmentSkeleton(pending: pending);
    } else {
      preview = FutureBuilder<FileTypeReport>(
        future: _resolveTypeReport(pending.attachment),
        builder: (context, snapshot) {
          final FileTypeReport? report = snapshot.data;
          final FileTypeReport fallbackReport = buildDeclaredFileTypeReport(
            declaredMimeType: pending.attachment.mimeType,
            fileName: pending.attachment.fileName,
            path: pending.attachment.path,
          );
          final FileTypeReport resolvedReport = report ?? fallbackReport;
          final bool useDeclaredFallback = !resolvedReport.hasReliableDetection;
          final bool isImage =
              resolvedReport.isDetectedImage ||
              (useDeclaredFallback && resolvedReport.isDeclaredImage);
          if (isImage) {
            return _PendingImageAttachment(
              pending: pending,
              onRetry: widget.onRetry,
              onRemove: widget.onRemove,
              typeReport: resolvedReport,
            );
          }
          return _PendingFileAttachment(
            pending: pending,
            typeReport: resolvedReport,
          );
        },
      );
    }
    final hasGesture = widget.onPressed != null || widget.onLongPress != null;
    final builder = widget.contextMenuBuilder;
    if (!hasGesture && builder == null) {
      return preview;
    }
    Widget interactive = preview;
    if (hasGesture) {
      interactive = ShadFocusable(
        canRequestFocus: true,
        builder: (context, focused, child) => child ?? const SizedBox.shrink(),
        child: ShadGestureDetector(
          cursor: SystemMouseCursors.click,
          hoverStrategies: mobileHoverStrategies,
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress ?? widget.onPressed,
          onTapDown: _bounceController.handleTapDown,
          onTapUp: _bounceController.handleTapUp,
          onTapCancel: _bounceController.handleTapCancel,
          child: AxiTapBounce(controller: _bounceController, child: preview),
        ),
      );
    }
    var items = <Widget>[];
    if (builder != null) {
      items = builder(pending);
    }
    final hasMenu = items.isNotEmpty;
    if (!hasGesture && !hasMenu) {
      return preview;
    }
    if (hasMenu) {
      final allowLongPress =
          widget.onLongPress != null || widget.contextMenuBuilder != null;
      interactive = Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.contextMenu):
              _ShowAttachmentMenuIntent(),
          SingleActivator(LogicalKeyboardKey.f10, shift: true):
              _ShowAttachmentMenuIntent(),
        },
        child: Actions(
          actions: {
            _ShowAttachmentMenuIntent:
                CallbackAction<_ShowAttachmentMenuIntent>(
                  onInvoke: (_) {
                    _showMenu();
                    return null;
                  },
                ),
          },
          child: AxiContextMenuRegion(
            controller: _menuController,
            longPressEnabled: allowLongPress,
            items: items,
            child: interactive,
          ),
        ),
      );
    }

    final attachment = pending.attachment;
    final l10n = context.l10n;
    final sizeLabel = formatBytes(attachment.sizeBytes, l10n);
    final statusMessage = _statusLabel(pending.status, l10n);
    final hasTapHandler = widget.onPressed != null;
    final semanticsOnTap = widget.onPressed ?? (hasMenu ? _showMenu : null);
    final semanticsOnLongPress =
        widget.onLongPress ?? (hasMenu ? _showMenu : null);
    final hint = hasMenu
        ? '$statusMessage. ${l10n.chatAttachmentMenuHint}'
        : statusMessage;

    return Semantics(
      label: '${attachment.fileName}, $sizeLabel',
      hint: hint,
      button: hasTapHandler || hasMenu,
      onTap: semanticsOnTap,
      onLongPress: semanticsOnLongPress,
      child: interactive,
    );
  }
}

class _ShowAttachmentMenuIntent extends Intent {
  const _ShowAttachmentMenuIntent();
}

class _PendingImageAttachment extends StatelessWidget {
  const _PendingImageAttachment({
    required this.pending,
    required this.onRetry,
    required this.onRemove,
    this.typeReport,
  });

  final PendingAttachment pending;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final FileTypeReport? typeReport;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(context.radii.squircle),
      side: context.borderSide,
    );
    final clipShape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(context.radii.squircle),
    );
    final borderWidth = context.borderSide.width;
    final previewExtent = sizing.attachmentPreviewExtent;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheExtent = (previewExtent * pixelRatio).round();
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    final isFailed = pending.status == PendingAttachmentStatus.failed;
    return SizedBox(
      width: previewExtent,
      height: previewExtent,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: ShapeDecoration(color: colors.card, shape: shape),
              child: Padding(
                padding: EdgeInsets.all(borderWidth),
                child: ClipPath(
                  clipper: ShapeBorderClipper(shape: clipShape),
                  child: Image.file(
                    File(pending.attachment.path),
                    fit: BoxFit.cover,
                    cacheWidth: cacheExtent,
                    cacheHeight: cacheExtent,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded || frame != null) {
                            return child;
                          }
                          return _PendingImageSkeleton(
                            shape: clipShape,
                            animationDuration: animationDuration,
                          );
                        },
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: colors.card,
                      child: Icon(
                        attachmentIcon(
                          pending.attachment,
                          typeReport: typeReport,
                        ),
                        color: colors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isFailed)
            _PendingAttachmentErrorOverlay(
              shape: clipShape,
              fileName: pending.attachment.fileName,
              message: pending.errorMessage?.label(context.l10n),
              onRetry: onRetry,
              onRemove: onRemove,
            )
          else
            Positioned(
              top: spacing.xs,
              right: spacing.xs,
              child: PendingAttachmentStatusBadge(status: pending.status),
            ),
        ],
      ),
    );
  }
}

class _PendingFileAttachment extends StatelessWidget {
  const _PendingFileAttachment({required this.pending, this.typeReport});

  final PendingAttachment pending;
  final FileTypeReport? typeReport;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final borderRadius = BorderRadius.circular(context.radii.squircle);
    final isFailed = pending.status == PendingAttachmentStatus.failed;
    final background = isFailed ? colors.destructive : colors.card;
    final foreground = isFailed
        ? colors.destructiveForeground
        : colors.foreground;
    final borderColor = isFailed ? colors.destructive : colors.border;
    final sizeLabel = formatBytes(pending.attachment.sizeBytes, context.l10n);
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: sizing.menuMaxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: borderRadius,
            border: Border.all(
              color: borderColor,
              width: context.borderSide.width,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacing.m,
            vertical: spacing.s,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: sizing.iconButtonSize,
                height: sizing.iconButtonSize,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: context.radius,
                ),
                child: Icon(
                  attachmentIcon(pending.attachment, typeReport: typeReport),
                  color: foreground,
                ),
              ),
              SizedBox(width: spacing.m),
              Flexible(
                fit: FlexFit.loose,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pending.attachment.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sizeLabel,
                          style: context.textTheme.small.copyWith(
                            color: colors.mutedForeground,
                          ),
                        ),
                        SizedBox(width: spacing.xs),
                        PendingAttachmentStatusInlineBadge(
                          status: pending.status,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingAttachmentSkeleton extends StatelessWidget {
  const _PendingAttachmentSkeleton({required this.pending});

  final PendingAttachment pending;

  @override
  Widget build(BuildContext context) {
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    if (pending.attachment.isImage) {
      return _PendingImageSkeleton(animationDuration: animationDuration);
    }
    return _PendingFileSkeleton(animationDuration: animationDuration);
  }
}

class _PendingImageSkeleton extends StatelessWidget {
  const _PendingImageSkeleton({required this.animationDuration, this.shape});

  final Duration animationDuration;
  final OutlinedBorder? shape;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final extent = sizing.attachmentPreviewExtent;
    final resolvedShape =
        shape ??
        RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(context.radii.squircle),
        );
    return SizedBox(
      width: extent,
      height: extent,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: resolvedShape),
        child: _ShimmerSurface(animationDuration: animationDuration),
      ),
    );
  }
}

class _PendingFileSkeleton extends StatelessWidget {
  const _PendingFileSkeleton({required this.animationDuration});

  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final borderRadius = BorderRadius.circular(context.radii.squircle);
    final iconExtent = sizing.iconButtonSize;
    final iconRadius = context.radii.container;
    final lineHeight = sizing.progressIndicatorBarHeight;
    final primaryLineWidth = sizing.menuMaxWidth - spacing.xl;
    final secondaryLineWidth = sizing.menuMaxWidth - spacing.xxl;
    final actionWidth = sizing.iconButtonSize;
    return Container(
      constraints: BoxConstraints(
        minWidth: sizing.menuMaxWidth - spacing.xl,
        maxWidth: sizing.menuMaxWidth,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: borderRadius,
        border: Border.all(
          color: context.borderSide.color,
          width: context.borderSide.width,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: spacing.m, vertical: spacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: iconExtent,
                height: iconExtent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(iconRadius),
                  child: _ShimmerSurface(animationDuration: animationDuration),
                ),
              ),
              SizedBox(width: spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: sizing.buttonHeightSm,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          context.radii.container,
                        ),
                        child: _ShimmerSurface(
                          animationDuration: animationDuration,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.s),
                    Row(
                      children: [
                        SizedBox(
                          width: primaryLineWidth,
                          height: lineHeight,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              context.radii.container,
                            ),
                            child: _ShimmerSurface(
                              animationDuration: animationDuration,
                            ),
                          ),
                        ),
                        SizedBox(width: spacing.s),
                        SizedBox(
                          width: secondaryLineWidth,
                          height: lineHeight,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              context.radii.container,
                            ),
                            child: _ShimmerSurface(
                              animationDuration: animationDuration,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.m),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: actionWidth,
              height: actionWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(context.radii.squircle),
                child: _ShimmerSurface(animationDuration: animationDuration),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerSurface extends StatefulWidget {
  const _ShimmerSurface({required this.animationDuration});

  final Duration animationDuration;

  @override
  State<_ShimmerSurface> createState() => _ShimmerSurfaceState();
}

class _ShimmerSurfaceState extends State<_ShimmerSurface>
    with SingleTickerProviderStateMixin {
  static const Duration _minShimmerDuration = Duration(milliseconds: 1200);

  Duration get _effectiveDuration {
    if (widget.animationDuration == Duration.zero) {
      return Duration.zero;
    }
    if (widget.animationDuration < _minShimmerDuration) {
      return _minShimmerDuration;
    }
    return widget.animationDuration;
  }

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _effectiveDuration,
  );

  @override
  void initState() {
    super.initState();
    if (_effectiveDuration != Duration.zero) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ShimmerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationDuration == widget.animationDuration) {
      return;
    }
    _controller.duration = _effectiveDuration;
    if (_effectiveDuration == Duration.zero) {
      _controller.stop();
      _controller.value = 0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final baseAlpha =
        (motion.tapHoverAlpha +
                motion.tapSplashAlpha +
                (motion.tapHoverAlpha / 2))
            .clamp(0.0, 1.0);
    final highlightAlpha =
        (motion.tapFocusAlpha + motion.tapSplashAlpha + motion.tapHoverAlpha)
            .clamp(0.0, 1.0);
    final base = context.colorScheme.border.withValues(alpha: baseAlpha);
    final highlight = context.colorScheme.card.withValues(
      alpha: highlightAlpha,
    );
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final shimmer = _controller.value;
          final start = (shimmer - 0.25).clamp(0.0, 1.0);
          final mid = shimmer.clamp(0.0, 1.0);
          final end = (shimmer + 0.25).clamp(0.0, 1.0);
          return SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [base, highlight, base],
                  stops: [start, mid, end],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PendingAttachmentErrorOverlay extends StatelessWidget {
  const _PendingAttachmentErrorOverlay({
    required this.shape,
    required this.fileName,
    required this.onRetry,
    required this.onRemove,
    this.message,
  });

  final OutlinedBorder shape;
  final String fileName;
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final errorLabel = message?.isNotEmpty == true
        ? message!
        : l10n.chatAttachmentSendFailed;
    return Positioned.fill(
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.destructive),
          child: Padding(
            padding: EdgeInsets.all(spacing.s),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.triangleAlert,
                      size: sizing.menuItemIconSize,
                      color: colors.destructiveForeground,
                    ),
                    SizedBox(width: spacing.xs),
                    Expanded(
                      child: AxiTooltip(
                        builder: (_) => Text(
                          l10n.chatAttachmentErrorTooltip(errorLabel, fileName),
                        ),
                        child: Text(
                          errorLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.destructiveForeground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PendingAttachmentOverlayAction(
                      icon: LucideIcons.refreshCcw,
                      tooltip: l10n.chatAttachmentRetryUpload,
                      onPressed: onRetry,
                    ),
                    _PendingAttachmentOverlayAction(
                      icon: LucideIcons.x,
                      tooltip: l10n.chatAttachmentRemoveAttachment,
                      onPressed: onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingAttachmentOverlayAction extends StatelessWidget {
  const _PendingAttachmentOverlayAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiIconButton.destructive(
      iconData: icon,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class PendingAttachmentStatusBadge extends StatelessWidget {
  const PendingAttachmentStatusBadge({super.key, required this.status});

  final PendingAttachmentStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final l10n = context.l10n;
    final background = colors.card;
    final extent = sizing.iconButtonIconSize + spacing.xs;
    return AxiTooltip(
      builder: (_) => Text(_statusLabel(status, l10n)),
      child: Container(
        width: extent,
        height: extent,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(
            color: context.borderSide.color,
            width: context.borderSide.width,
          ),
        ),
        padding: EdgeInsets.all(spacing.xs),
        child: _StatusIndicator(status: status),
      ),
    );
  }
}

class PendingAttachmentStatusInlineBadge extends StatelessWidget {
  const PendingAttachmentStatusInlineBadge({super.key, required this.status});

  final PendingAttachmentStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sizing = context.sizing;
    return AxiTooltip(
      builder: (_) => Text(_statusLabel(status, l10n)),
      child: SizedBox(
        width: sizing.iconButtonIconSize,
        height: sizing.iconButtonIconSize,
        child: _StatusIndicator(status: status),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  final PendingAttachmentStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final sizing = context.sizing;
    switch (status) {
      case PendingAttachmentStatus.uploading:
        return AxiProgressIndicator(color: colors.primary);
      case PendingAttachmentStatus.queued:
        return Icon(
          LucideIcons.clock,
          size: sizing.menuItemIconSize,
          color: colors.mutedForeground,
        );
      case PendingAttachmentStatus.failed:
        return Icon(
          LucideIcons.triangleAlert,
          size: sizing.menuItemIconSize,
          color: colors.destructive,
        );
    }
  }
}

String _statusLabel(PendingAttachmentStatus status, AppLocalizations l10n) {
  return switch (status) {
    PendingAttachmentStatus.uploading => l10n.chatAttachmentStatusUploading,
    PendingAttachmentStatus.queued => l10n.chatAttachmentStatusQueued,
    PendingAttachmentStatus.failed => l10n.chatAttachmentStatusFailed,
  };
}

IconData attachmentIcon(Attachment attachment, {FileTypeReport? typeReport}) {
  if (typeReport?.isDetectedImage ?? false) return Icons.image_outlined;
  if (typeReport?.isDetectedVideo ?? false) return Icons.videocam_outlined;
  if (attachment.isImage) return Icons.image_outlined;
  if (attachment.isVideo) return Icons.videocam_outlined;
  if (attachment.isAudio) return Icons.audiotrack;
  return Icons.insert_drive_file_outlined;
}

String formatBytes(int bytes, AppLocalizations l10n) {
  final units = [
    l10n.commonFileSizeUnitBytes,
    l10n.commonFileSizeUnitKilobytes,
    l10n.commonFileSizeUnitMegabytes,
    l10n.commonFileSizeUnitGigabytes,
    l10n.commonFileSizeUnitTerabytes,
  ];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final formatted = unit == 0
      ? size.toStringAsFixed(0)
      : size.toStringAsFixed(size >= 10 ? 0 : 1);
  return '$formatted ${units[unit]}';
}
