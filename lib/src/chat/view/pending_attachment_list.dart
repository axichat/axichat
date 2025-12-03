import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
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

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  void _showMenu() {
    if (!mounted) return;
    _menuController.show();
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.pending;
    Widget preview;
    if (pending.attachment.isImage) {
      preview = _PendingImageAttachment(
        pending: pending,
        onRetry: widget.onRetry,
        onRemove: widget.onRemove,
      );
    } else {
      preview = _PendingFileAttachment(
        pending: pending,
        onRetry: widget.onRetry,
        onRemove: widget.onRemove,
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
  });

  final PendingAttachment pending;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

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
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: colors.card,
                  child: Icon(
                    attachmentIcon(pending.attachment),
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
  });

  final PendingAttachment pending;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

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
                  attachmentIcon(pending.attachment),
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

IconData attachmentIcon(EmailAttachment attachment) {
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
