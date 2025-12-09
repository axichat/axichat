import 'dart:io';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatAttachmentPreview extends StatelessWidget {
  const ChatAttachmentPreview({
    super.key,
    required this.metadataFuture,
    required this.allowed,
    this.onAllowPressed,
  });

  final Future<FileMetadataData?> metadataFuture;
  final bool allowed;
  final VoidCallback? onAllowPressed;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FileMetadataData?>(
      future: metadataFuture,
      builder: (context, snapshot) {
        final l10n = context.l10n;
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AttachmentSurface(
            child: Center(
              child: SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return _AttachmentError(message: snapshot.error.toString());
        }
        final metadata = snapshot.data;
        if (metadata == null) {
          return _AttachmentError(
            message: l10n.chatAttachmentUnavailable,
          );
        }
        if (!allowed) {
          return _BlockedAttachment(
            metadata: metadata,
            onAllowPressed: onAllowPressed,
          );
        }
        if (_isImage(metadata)) {
          return _ImageAttachment(metadata: metadata);
        }
        return _FileAttachment(metadata: metadata);
      },
    );
  }
}

class _BlockedAttachment extends StatelessWidget {
  const _BlockedAttachment({
    required this.metadata,
    this.onAllowPressed,
  });

  final FileMetadataData metadata;
  final VoidCallback? onAllowPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    return _AttachmentSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            l10n.chatAttachmentBlockedTitle,
            style: context.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            metadata.filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
          Text(
            l10n.chatAttachmentBlockedDescription,
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ShadButton(
              onPressed: onAllowPressed,
              enabled: onAllowPressed != null,
              child: Text(l10n.chatAttachmentLoad),
            ).withTapBounce(enabled: onAllowPressed != null),
          ),
        ],
      ),
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({required this.metadata});

  final FileMetadataData metadata;

  @override
  Widget build(BuildContext context) {
    final url = metadata.sourceUrls == null || metadata.sourceUrls!.isEmpty
        ? null
        : metadata.sourceUrls!.first;
    final path = metadata.path;
    final localFile = path == null ? null : File(path);
    final hasLocalFile = localFile?.existsSync() ?? false;
    if (!hasLocalFile && url == null) {
      return _AttachmentError(message: context.l10n.chatAttachmentUnavailable);
    }
    final radius = BorderRadius.circular(18);
    final image = hasLocalFile
        ? Image.file(
            localFile!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Center(child: Icon(Icons.broken_image_outlined)),
          )
        : Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Center(child: Icon(Icons.broken_image_outlined)),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              final value = progress.expectedTotalBytes == null
                  ? null
                  : progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!;
              return _AttachmentLoadingPlaceholder(progress: value);
            },
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = _resolveWidth(constraints, context);
        return Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox(
            width: targetWidth,
            child: _AttachmentSurface(
              padding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              borderSide: BorderSide.none,
              child: ClipRRect(
                borderRadius: radius,
                child: GestureDetector(
                  onTap: () => _openAttachment(context, url: url, path: path),
                  child: AspectRatio(
                    aspectRatio: _aspectRatio(metadata),
                    child: image,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _resolveWidth(BoxConstraints constraints, BuildContext context) {
    final availableWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : MediaQuery.sizeOf(context).width;
    final intrinsicWidth = metadata.width?.toDouble();
    if (intrinsicWidth == null || intrinsicWidth <= 0) {
      return availableWidth;
    }
    return math.min(intrinsicWidth, availableWidth);
  }

  double _aspectRatio(FileMetadataData metadata) {
    if (metadata.width != null && metadata.height != null) {
      if (metadata.height == 0) return 4 / 3;
      return metadata.width! / metadata.height!;
    }
    return 4 / 3;
  }
}

class _AttachmentLoadingPlaceholder extends StatelessWidget {
  const _AttachmentLoadingPlaceholder({this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final label = progress == null
        ? l10n.chatAttachmentLoading
        : l10n.chatAttachmentLoadingProgress(
            '${(progress!.clamp(0, 1) * 100).toStringAsFixed(0)}%',
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        Shimmer.fromColors(
          baseColor: colors.muted.withValues(alpha: 0.2),
          highlightColor: colors.muted.withValues(alpha: 0.35),
          child: Container(color: colors.card),
        ),
        Center(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: colors.background.withValues(alpha: 0.85),
              shape: SquircleBorder(cornerRadius: 12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.image,
                    size: 16,
                    color: colors.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: context.textTheme.small.copyWith(
                      color: colors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FileAttachment extends StatelessWidget {
  const _FileAttachment({required this.metadata});

  final FileMetadataData metadata;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final url = metadata.sourceUrls == null || metadata.sourceUrls!.isEmpty
        ? null
        : metadata.sourceUrls!.first;
    return _AttachmentSurface(
      child: Row(
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              color: colors.muted.withValues(alpha: 0.15),
              shape: SquircleBorder(
                cornerRadius: 12,
                side: BorderSide(color: colors.border),
              ),
            ),
            child: const SizedBox(
              width: 42,
              height: 46,
              child: Icon(
                LucideIcons.paperclip,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  metadata.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatSize(metadata.sizeBytes, l10n),
                  style: context.textTheme.small.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AxiIconButton(
            iconData: LucideIcons.download,
            tooltip: l10n.chatAttachmentDownload,
            onPressed: url == null && metadata.path == null
                ? null
                : () => _openAttachment(
                      context,
                      url: url,
                      path: metadata.path,
                    ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentSurface extends StatelessWidget {
  const _AttachmentSurface({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.backgroundColor,
    this.borderSide,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final BorderSide? borderSide;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final resolvedBackground = backgroundColor ?? colors.card;
    final resolvedBorder = borderSide ?? BorderSide(color: colors.border);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: resolvedBackground,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: resolvedBorder,
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _AttachmentError extends StatelessWidget {
  const _AttachmentError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return _AttachmentSurface(
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.small.copyWith(
                color: colors.destructive,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openAttachment(
  BuildContext context, {
  String? url,
  String? path,
}) async {
  final l10n = context.l10n;
  final toaster = ShadToaster.maybeOf(context);
  if (path != null) {
    final file = File(path);
    if (!await file.exists()) {
      _showToast(
        l10n,
        toaster,
        l10n.chatAttachmentUnavailableDevice,
        destructive: true,
      );
      return;
    }
    final launched = await launchUrl(
      Uri.file(file.path),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      final target = file.path.split('/').last;
      _showToast(
        l10n,
        toaster,
        l10n.chatAttachmentOpenFailed(target),
        destructive: true,
      );
    }
    return;
  }
  final trimmed = url?.trim();
  final uri = trimmed == null ? null : Uri.tryParse(trimmed);
  if (uri == null) {
    _showToast(
      l10n,
      toaster,
      l10n.chatAttachmentInvalidLink,
      destructive: true,
    );
    return;
  }
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    final target = uri.host.isEmpty ? uri.toString() : uri.host;
    _showToast(
      l10n,
      toaster,
      l10n.chatAttachmentOpenFailed(target),
      destructive: true,
    );
  }
}

void _showToast(
  AppLocalizations l10n,
  ShadToasterState? toaster,
  String message, {
  bool destructive = false,
}) {
  final toast = destructive
      ? FeedbackToast.error(
          title: l10n.toastWhoopsTitle,
          message: message,
        )
      : FeedbackToast.info(
          title: l10n.toastHeadsUpTitle,
          message: message,
        );
  toaster?.show(toast);
}

bool _isImage(FileMetadataData metadata) {
  final mime = metadata.mimeType?.toLowerCase();
  if (mime?.startsWith('image/') ?? false) return true;
  final name = metadata.filename.toLowerCase();
  const extensions = [
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
  ];
  return extensions.any(name.endsWith);
}

String _formatSize(int? bytes, AppLocalizations l10n) {
  if (bytes == null || bytes <= 0) return l10n.chatAttachmentUnknownSize;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}
