import 'dart:io';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart' show XmppService;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatAttachmentPreview extends StatelessWidget {
  const ChatAttachmentPreview({
    super.key,
    required this.stanzaId,
    required this.metadataStream,
    this.initialMetadata,
    required this.allowed,
    this.onAllowPressed,
  });

  final String stanzaId;
  final Stream<FileMetadataData?> metadataStream;
  final FileMetadataData? initialMetadata;
  final bool allowed;
  final VoidCallback? onAllowPressed;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: StreamBuilder<FileMetadataData?>(
        stream: metadataStream,
        initialData: initialMetadata,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AttachmentError(message: snapshot.error.toString());
          }

          final l10n = context.l10n;
          final metadata = snapshot.data;
          if (metadata == null) {
            if (snapshot.connectionState != ConnectionState.active &&
                snapshot.connectionState != ConnectionState.done) {
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
            return _ImageAttachment(
              metadata: metadata,
              stanzaId: stanzaId,
            );
          }
          return _FileAttachment(
            metadata: metadata,
            stanzaId: stanzaId,
          );
        },
      ),
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

class _ImageAttachment extends StatefulWidget {
  const _ImageAttachment({
    required this.metadata,
    required this.stanzaId,
  });

  final FileMetadataData metadata;
  final String stanzaId;

  @override
  State<_ImageAttachment> createState() => _ImageAttachmentState();
}

class _ImageAttachmentState extends State<_ImageAttachment> {
  var _downloading = false;

  bool get _encrypted =>
      widget.metadata.encryptionScheme?.trim().isNotEmpty == true;

  @override
  Widget build(BuildContext context) {
    final metadata = widget.metadata;
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
    if (!hasLocalFile) {
      if (_encrypted) {
        return _EncryptedAttachment(
          filename: metadata.filename,
          downloading: _downloading,
          onPressed: _downloading ? null : () => _downloadAttachment(),
        );
      }
      return _RemoteImageAttachment(
        filename: metadata.filename,
        downloading: _downloading,
        onPressed: _downloading ? null : () => _downloadAttachment(),
      );
    }
    final image = Image.file(
      localFile!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image_outlined)),
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
                  onTap: () =>
                      _openAttachment(context, path: widget.metadata.path),
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

  Future<void> _downloadAttachment() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
    });
    final l10n = context.l10n;
    final toaster = ShadToaster.maybeOf(context);
    try {
      final xmpp = context.read<XmppService>();
      final downloadedPath = await xmpp.downloadInboundAttachment(
        metadataId: widget.metadata.id,
        stanzaId: widget.stanzaId,
      );
      if (!mounted) return;
      if (downloadedPath == null || downloadedPath.trim().isEmpty) {
        _showToast(
          l10n,
          toaster,
          l10n.chatAttachmentUnavailable,
          destructive: true,
        );
      }
    } on Exception {
      if (!mounted) return;
      _showToast(
        l10n,
        toaster,
        l10n.chatAttachmentUnavailable,
        destructive: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  double _resolveWidth(BoxConstraints constraints, BuildContext context) {
    final availableWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : MediaQuery.sizeOf(context).width;
    const maxUnknownWidth = 420.0;
    final intrinsicWidth = widget.metadata.width?.toDouble();
    final targetWidth = intrinsicWidth != null && intrinsicWidth > 0
        ? intrinsicWidth
        : math.min(maxUnknownWidth, availableWidth);
    return math.min(targetWidth, availableWidth * 0.9);
  }

  double _aspectRatio(FileMetadataData metadata) {
    if (metadata.width != null && metadata.height != null) {
      if (metadata.height == 0) return 4 / 3;
      return metadata.width! / metadata.height!;
    }
    return 4 / 3;
  }
}

class _FileAttachment extends StatefulWidget {
  const _FileAttachment({
    required this.metadata,
    required this.stanzaId,
  });

  final FileMetadataData metadata;
  final String stanzaId;

  @override
  State<_FileAttachment> createState() => _FileAttachmentState();
}

class _FileAttachmentState extends State<_FileAttachment> {
  var _downloading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final metadata = widget.metadata;
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
          if (_downloading)
            const SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            AxiIconButton(
              iconData: LucideIcons.download,
              tooltip: l10n.chatAttachmentDownload,
              onPressed: url == null && metadata.path == null
                  ? null
                  : () => _downloadAndOpen(
                        existingPath: metadata.path,
                      ),
            ),
        ],
      ),
    );
  }

  Future<void> _downloadAndOpen({
    required String? existingPath,
  }) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
    });
    final l10n = context.l10n;
    final toaster = ShadToaster.maybeOf(context);
    try {
      final xmpp = context.read<XmppService>();
      final downloadedPath = await xmpp.downloadInboundAttachment(
        metadataId: widget.metadata.id,
        stanzaId: widget.stanzaId,
      );
      if (!mounted) return;
      final resolvedPath = downloadedPath?.trim().isNotEmpty == true
          ? downloadedPath
          : existingPath;
      if (resolvedPath == null || resolvedPath.trim().isEmpty) {
        _showToast(
          l10n,
          toaster,
          l10n.chatAttachmentUnavailable,
          destructive: true,
        );
        return;
      }
      await _openAttachment(context, path: resolvedPath);
    } on Exception {
      if (!mounted) return;
      _showToast(
        l10n,
        toaster,
        l10n.chatAttachmentUnavailable,
        destructive: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }
}

class _EncryptedAttachment extends StatelessWidget {
  const _EncryptedAttachment({
    required this.filename,
    required this.downloading,
    required this.onPressed,
  });

  final String filename;
  final bool downloading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final width = availableWidth * 0.9;
        return Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox(
            width: width,
            child: _AttachmentSurface(
              backgroundColor: colors.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.lock,
                        size: 18,
                        color: colors.mutedForeground,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ShadButton(
                      onPressed: onPressed,
                      enabled: onPressed != null,
                      leading: downloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      child: Text(
                        downloading
                            ? l10n.chatAttachmentLoading
                            : l10n.chatAttachmentDownload,
                      ),
                    ).withTapBounce(enabled: onPressed != null),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RemoteImageAttachment extends StatelessWidget {
  const _RemoteImageAttachment({
    required this.filename,
    required this.downloading,
    required this.onPressed,
  });

  final String filename;
  final bool downloading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final width = availableWidth * 0.9;
        return Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox(
            width: width,
            child: _AttachmentSurface(
              backgroundColor: colors.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.image,
                        size: 18,
                        color: colors.mutedForeground,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ShadButton(
                      onPressed: onPressed,
                      enabled: onPressed != null,
                      leading: downloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      child: Text(
                        downloading
                            ? l10n.chatAttachmentLoading
                            : l10n.chatAttachmentDownload,
                      ),
                    ).withTapBounce(enabled: onPressed != null),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
