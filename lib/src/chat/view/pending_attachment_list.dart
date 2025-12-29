import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final ValueChanged<String> onRetry;
  final ValueChanged<String> onRemove;
  final ValueChanged<PendingAttachment>? onPressed;
  final ValueChanged<PendingAttachment>? onLongPress;
  final List<Widget> Function(PendingAttachment pending)? contextMenuBuilder;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: attachments
            .map(
              (pending) => _PendingAttachmentPreview(
                pending: pending,
                onRetry: () => onRetry(pending.id),
                onRemove: () => onRemove(pending.id),
                onPressed: onPressed == null ? null : () => onPressed!(pending),
                onLongPress:
                    onLongPress == null ? null : () => onLongPress!(pending),
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

  Future<FileTypeReport> _resolveTypeReport(EmailAttachment attachment) {
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
          final bool useDeclaredFallback =
              report != null && !resolvedReport.hasReliableDetection;
          final bool isImage = resolvedReport.isDetectedImage ||
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
            onRetry: widget.onRetry,
            onRemove: widget.onRemove,
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
      final borderRadius = BorderRadius.circular(16);
      interactive = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress ?? widget.onPressed,
          child: preview,
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
    final sizeLabel = formatBytes(attachment.sizeBytes);
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
    final borderRadius = BorderRadius.circular(16);
    final isFailed = pending.status == PendingAttachmentStatus.failed;
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Image.file(
                File(pending.attachment.path),
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    return child;
                  }
                  return _PendingImageSkeleton(borderRadius: borderRadius);
                },
                errorBuilder: (_, __, ___) => ColoredBox(
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
          if (isFailed)
            _PendingAttachmentErrorOverlay(
              borderRadius: borderRadius,
              fileName: pending.attachment.fileName,
              message: pending.errorMessage,
              onRetry: onRetry,
              onRemove: onRemove,
            )
          else
            Positioned(
              top: 6,
              right: 6,
              child: PendingAttachmentStatusBadge(status: pending.status),
            ),
        ],
      ),
    );
  }
}

class _PendingFileAttachment extends StatelessWidget {
  const _PendingFileAttachment({
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
    final borderRadius = BorderRadius.circular(16);
    final isFailed = pending.status == PendingAttachmentStatus.failed;
    final background = isFailed ? colors.destructive : colors.card;
    final foreground =
        isFailed ? colors.destructiveForeground : colors.foreground;
    final sizeLabel = formatBytes(pending.attachment.sizeBytes);
    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      decoration: BoxDecoration(
        color: background,
        borderRadius: borderRadius,
        border: Border.all(
          color: colors.border.withValues(alpha: isFailed ? 0.5 : 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: background.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  attachmentIcon(
                    pending.attachment,
                    typeReport: typeReport,
                  ),
                  color: foreground,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          sizeLabel,
                          style: context.textTheme.small.copyWith(
                            color: foreground.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(width: 6),
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
          const SizedBox(height: 12),
          _PendingAttachmentActionBar(
            pending: pending,
            onRetry: onRetry,
            onRemove: onRemove,
          ),
        ],
      ),
    );
  }
}

class _PendingAttachmentSkeleton extends StatelessWidget {
  const _PendingAttachmentSkeleton({required this.pending});

  final PendingAttachment pending;

  @override
  Widget build(BuildContext context) {
    if (pending.attachment.isImage) {
      return const _PendingImageSkeleton();
    }
    return const _PendingFileSkeleton();
  }
}

class _PendingImageSkeleton extends StatelessWidget {
  const _PendingImageSkeleton({this.borderRadius});

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    const extent = 72.0;
    final radius = borderRadius ?? BorderRadius.circular(16);
    return SizedBox(
      width: extent,
      height: extent,
      child: ClipRRect(
        borderRadius: radius,
        child: const _ShimmerSurface(),
      ),
    );
  }
}

class _PendingFileSkeleton extends StatelessWidget {
  const _PendingFileSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    const borderRadiusValue = 16.0;
    const iconExtent = 40.0;
    const iconRadius = 12.0;
    const lineHeight = 12.0;
    const primaryLineWidth = 150.0;
    const secondaryLineWidth = 110.0;
    const actionWidth = 28.0;

    final borderRadius = BorderRadius.circular(borderRadiusValue);
    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: borderRadius,
        border: Border.all(
          color: colors.border,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                  child: const _ShimmerSurface(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: const _ShimmerSurface(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: primaryLineWidth,
                          height: lineHeight,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: const _ShimmerSurface(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: secondaryLineWidth,
                          height: lineHeight,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: const _ShimmerSurface(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: actionWidth,
              height: actionWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: const _ShimmerSurface(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerSurface extends StatefulWidget {
  const _ShimmerSurface();

  @override
  State<_ShimmerSurface> createState() => _ShimmerSurfaceState();
}

class _ShimmerSurfaceState extends State<_ShimmerSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final base = colors.border.withValues(alpha: 0.30);
    final highlight = colors.card.withValues(alpha: 0.85);
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

class _PendingAttachmentActionBar extends StatelessWidget {
  const _PendingAttachmentActionBar({
    required this.pending,
    required this.onRetry,
    required this.onRemove,
  });

  final PendingAttachment pending;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isFailed = pending.status == PendingAttachmentStatus.failed;
    if (!isFailed) {
      return Align(
        alignment: Alignment.centerRight,
        child: AxiIconButton(
          iconData: LucideIcons.x,
          tooltip: l10n.chatAttachmentRemoveAttachment,
          onPressed: onRemove,
          backgroundColor: context.colorScheme.card,
          borderColor: context.colorScheme.border,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          pending.errorMessage ?? l10n.chatAttachmentSendFailed,
          style: context.textTheme.small.copyWith(
            color: context.colorScheme.destructiveForeground,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 6,
          children: [
            _PendingAttachmentActionButton(
              icon: LucideIcons.refreshCcw,
              label: l10n.commonRetry,
              onPressed: onRetry,
            ),
            _PendingAttachmentActionButton(
              icon: LucideIcons.x,
              label: l10n.commonRemove,
              onPressed: onRemove,
            ),
          ],
        ),
      ],
    );
  }
}

class _PendingAttachmentErrorOverlay extends StatelessWidget {
  const _PendingAttachmentErrorOverlay({
    required this.borderRadius,
    required this.fileName,
    required this.onRetry,
    required this.onRemove,
    this.message,
  });

  final BorderRadius borderRadius;
  final String fileName;
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final errorLabel =
        message?.isNotEmpty == true ? message! : l10n.chatAttachmentSendFailed;
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.destructive.withValues(alpha: 0.92),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.triangleAlert,
                      size: 14,
                      color: colors.destructiveForeground,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: AxiTooltip(
                        builder: (_) => Text(
                          l10n.chatAttachmentErrorTooltip(
                            errorLabel,
                            fileName,
                          ),
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

  static const double _buttonSize = 20;
  static const double _tapTargetSize = 26;
  static const double _iconSize = 14;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return AxiIconButton(
      iconData: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      buttonSize: _buttonSize,
      tapTargetSize: _tapTargetSize,
      iconSize: _iconSize,
      backgroundColor: colors.destructiveForeground.withValues(alpha: 0.12),
      borderColor: colors.destructiveForeground.withValues(alpha: 0.4),
      color: colors.destructiveForeground,
      cornerRadius: 10,
      borderWidth: 1,
    );
  }
}

class _PendingAttachmentActionButton extends StatelessWidget {
  const _PendingAttachmentActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadButton.secondary(
      size: ShadButtonSize.sm,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    ).withTapBounce();
  }
}

class _PendingAttachmentSpinner extends StatelessWidget {
  const _PendingAttachmentSpinner({
    required this.color,
    this.strokeWidth = 2.5,
  });

  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      strokeWidth: strokeWidth,
      color: color,
    );
  }
}

class PendingAttachmentStatusBadge extends StatelessWidget {
  const PendingAttachmentStatusBadge({super.key, required this.status});

  final PendingAttachmentStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final background = colors.background.withValues(alpha: 0.85);
    return AxiTooltip(
      builder: (_) => Text(_statusLabel(status, l10n)),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: colors.border),
        ),
        padding: const EdgeInsets.all(4),
        child: _StatusIndicator(status: status),
      ),
    );
  }
}

class PendingAttachmentStatusInlineBadge extends StatelessWidget {
  const PendingAttachmentStatusInlineBadge({
    super.key,
    required this.status,
  });

  final PendingAttachmentStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AxiTooltip(
      builder: (_) => Text(_statusLabel(status, l10n)),
      child: SizedBox(
        width: 20,
        height: 20,
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
    switch (status) {
      case PendingAttachmentStatus.uploading:
        return _PendingAttachmentSpinner(
          color: colors.primary,
          strokeWidth: 2,
        );
      case PendingAttachmentStatus.queued:
        return Icon(
          LucideIcons.clock,
          size: 14,
          color: colors.mutedForeground,
        );
      case PendingAttachmentStatus.failed:
        return Icon(
          LucideIcons.triangleAlert,
          size: 14,
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

IconData attachmentIcon(
  EmailAttachment attachment, {
  FileTypeReport? typeReport,
}) {
  if (typeReport?.isDetectedImage ?? false) return Icons.image_outlined;
  if (typeReport?.isDetectedVideo ?? false) return Icons.videocam_outlined;
  if (attachment.isImage) return Icons.image_outlined;
  if (attachment.isVideo) return Icons.videocam_outlined;
  if (attachment.isAudio) return Icons.audiotrack;
  return Icons.insert_drive_file_outlined;
}

String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
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
