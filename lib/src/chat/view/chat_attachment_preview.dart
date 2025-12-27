import 'dart:io';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/attachment_metadata_extensions.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart'
    show XmppFileTooBigException, XmppService;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class _AttachmentSpinner extends StatelessWidget {
  const _AttachmentSpinner({
    required this.size,
    required this.color,
  });

  static const double _strokeWidth = 2;

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: _strokeWidth,
        color: color,
      ),
    );
  }
}

const double _attachmentPreviewCornerRadius = 18.0;
const double _attachmentActionSpacing = 8.0;
const double _attachmentOverlayIconSize = 16.0;
const double _attachmentVideoIconSize = 20.0;
const double _attachmentOverlayPadding = 8.0;
const double _attachmentVideoSpinnerSize = 32.0;
const double _attachmentVideoFallbackAspectRatio = 16 / 9;
const double _attachmentRemoteIconSize = 18.0;
const double _attachmentRemoteSpacing = 8.0;
const double _attachmentRemoteBodySpacing = 12.0;
const double _attachmentUnknownMaxWidth = 420.0;
const double _attachmentMaxWidthFraction = 0.9;
const String _attachmentTooLargeMessageDefault =
    'Attachment exceeds the server limit.';
const String _attachmentTooLargeMessagePrefix =
    'Attachment exceeds the server limit (';
const String _attachmentTooLargeMessageSuffix = ').';

class AttachmentDownloadDelegate {
  const AttachmentDownloadDelegate(this._download);

  final Future<bool> Function() _download;

  Future<bool> download() => _download();
}

class ChatAttachmentPreview extends StatelessWidget {
  const ChatAttachmentPreview({
    super.key,
    required this.stanzaId,
    required this.metadataStream,
    this.initialMetadata,
    required this.allowed,
    this.autoDownload = false,
    this.autoDownloadUserInitiated = false,
    this.downloadDelegate,
    this.onAllowPressed,
  });

  final String stanzaId;
  final Stream<FileMetadataData?> metadataStream;
  final FileMetadataData? initialMetadata;
  final bool allowed;
  final bool autoDownload;
  final bool autoDownloadUserInitiated;
  final AttachmentDownloadDelegate? downloadDelegate;
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
          final colors = context.colorScheme;
          final metadata = snapshot.data;
          if (metadata == null) {
            if (snapshot.connectionState != ConnectionState.active &&
                snapshot.connectionState != ConnectionState.done) {
              return _AttachmentSurface(
                child: Center(
                  child: _AttachmentSpinner(
                    size: 32,
                    color: colors.primary,
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
          if (metadata.isImage) {
            return _ImageAttachment(
              metadata: metadata,
              stanzaId: stanzaId,
              autoDownload: autoDownload,
              autoDownloadUserInitiated: autoDownloadUserInitiated,
              downloadDelegate: downloadDelegate,
            );
          }
          if (metadata.isVideo) {
            return _VideoAttachment(
              metadata: metadata,
              stanzaId: stanzaId,
              autoDownload: autoDownload,
              autoDownloadUserInitiated: autoDownloadUserInitiated,
              downloadDelegate: downloadDelegate,
            );
          }
          return _FileAttachment(
            metadata: metadata,
            stanzaId: stanzaId,
            autoDownload: autoDownload,
            autoDownloadUserInitiated: autoDownloadUserInitiated,
            downloadDelegate: downloadDelegate,
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
    required this.autoDownload,
    required this.autoDownloadUserInitiated,
    this.downloadDelegate,
  });

  final FileMetadataData metadata;
  final String stanzaId;
  final bool autoDownload;
  final bool autoDownloadUserInitiated;
  final AttachmentDownloadDelegate? downloadDelegate;

  @override
  State<_ImageAttachment> createState() => _ImageAttachmentState();
}

class _ImageAttachmentState extends State<_ImageAttachment> {
  var _downloading = false;
  var _autoDownloadRequested = false;

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
    final canDownload = url != null || widget.downloadDelegate != null;
    if (!hasLocalFile && !canDownload) {
      return _AttachmentError(message: context.l10n.chatAttachmentUnavailable);
    }
    if (widget.autoDownload &&
        !_autoDownloadRequested &&
        !_downloading &&
        !hasLocalFile &&
        canDownload) {
      _autoDownloadRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _downloadAttachment(showFeedback: widget.autoDownloadUserInitiated);
      });
    }
    final radius = BorderRadius.circular(_attachmentPreviewCornerRadius);
    if (!hasLocalFile) {
      if (_encrypted) {
        return _EncryptedAttachment(
          filename: metadata.filename,
          downloading: _downloading,
          onPressed: _downloading
              ? null
              : () => _downloadAttachment(showFeedback: true),
        );
      }
      return _RemoteImageAttachment(
        filename: metadata.filename,
        downloading: _downloading,
        onPressed:
            _downloading ? null : () => _downloadAttachment(showFeedback: true),
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
        final targetWidth = _resolveAttachmentWidth(
          constraints,
          context,
          intrinsicWidth: widget.metadata.width?.toDouble(),
        );
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
                  onTap: () => _openImagePreview(context,
                      file: localFile, metadata: metadata),
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

  Future<void> _downloadAttachment({required bool showFeedback}) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
    });
    final l10n = context.l10n;
    final toaster = ShadToaster.maybeOf(context);
    try {
      final downloadDelegate = widget.downloadDelegate;
      final downloaded = downloadDelegate == null
          ? await _downloadViaXmpp()
          : await downloadDelegate.download();
      if (!mounted) return;
      if (!downloaded && showFeedback) {
        _showToast(
          l10n,
          toaster,
          l10n.chatAttachmentUnavailable,
          destructive: true,
        );
      }
    } on XmppFileTooBigException catch (error) {
      if (!mounted) return;
      if (showFeedback) {
        _showToast(
          l10n,
          toaster,
          _attachmentTooLargeMessage(l10n, error.maxBytes),
          destructive: true,
        );
      }
    } on Exception {
      if (!mounted) return;
      if (showFeedback) {
        _showToast(
          l10n,
          toaster,
          l10n.chatAttachmentUnavailable,
          destructive: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  Future<bool> _downloadViaXmpp() async {
    final xmpp = context.read<XmppService>();
    final downloadedPath = await xmpp.downloadInboundAttachment(
      metadataId: widget.metadata.id,
      stanzaId: widget.stanzaId,
    );
    return downloadedPath?.trim().isNotEmpty == true;
  }

  double _aspectRatio(FileMetadataData metadata) {
    if (metadata.width != null && metadata.height != null) {
      if (metadata.height == 0) return 4 / 3;
      return metadata.width! / metadata.height!;
    }
    return 4 / 3;
  }
}

class _VideoAttachment extends StatefulWidget {
  const _VideoAttachment({
    required this.metadata,
    required this.stanzaId,
    required this.autoDownload,
    required this.autoDownloadUserInitiated,
    this.downloadDelegate,
  });

  final FileMetadataData metadata;
  final String stanzaId;
  final bool autoDownload;
  final bool autoDownloadUserInitiated;
  final AttachmentDownloadDelegate? downloadDelegate;

  @override
  State<_VideoAttachment> createState() => _VideoAttachmentState();
}

class _VideoAttachmentState extends State<_VideoAttachment> {
  var _downloading = false;
  var _autoDownloadRequested = false;
  var _initFailed = false;
  VideoPlayerController? _controller;

  bool get _encrypted =>
      widget.metadata.encryptionScheme?.trim().isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    _initializeVideoIfAvailable();
  }

  @override
  void didUpdateWidget(covariant _VideoAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPath = oldWidget.metadata.path?.trim();
    final nextPath = widget.metadata.path?.trim();
    if (oldPath != nextPath) {
      _resetController();
      _initializeVideoIfAvailable();
    }
  }

  @override
  void dispose() {
    _resetController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.metadata;
    final url = metadata.sourceUrls == null || metadata.sourceUrls!.isEmpty
        ? null
        : metadata.sourceUrls!.first;
    final path = metadata.path?.trim();
    final localFile = path == null || path.isEmpty ? null : File(path);
    final hasLocalFile = localFile?.existsSync() ?? false;
    final canDownload = url != null || widget.downloadDelegate != null;
    if (!hasLocalFile && !canDownload) {
      return _AttachmentError(message: context.l10n.chatAttachmentUnavailable);
    }
    if (widget.autoDownload &&
        !_autoDownloadRequested &&
        !_downloading &&
        !hasLocalFile &&
        canDownload) {
      _autoDownloadRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _downloadAttachment(showFeedback: widget.autoDownloadUserInitiated);
      });
    }
    final radius = BorderRadius.circular(_attachmentPreviewCornerRadius);
    if (!hasLocalFile) {
      if (_encrypted) {
        return _EncryptedAttachment(
          filename: metadata.filename,
          downloading: _downloading,
          onPressed: _downloading
              ? null
              : () => _downloadAttachment(showFeedback: true),
        );
      }
      return _RemoteVideoAttachment(
        filename: metadata.filename,
        downloading: _downloading,
        onPressed:
            _downloading ? null : () => _downloadAttachment(showFeedback: true),
      );
    }
    if (_initFailed) {
      return _FileAttachment(
        metadata: metadata,
        stanzaId: widget.stanzaId,
        autoDownload: widget.autoDownload,
        autoDownloadUserInitiated: widget.autoDownloadUserInitiated,
        downloadDelegate: widget.downloadDelegate,
      );
    }

    final colors = context.colorScheme;
    final controller = _controller;
    final initialized = controller?.value.isInitialized == true;
    final playing = controller?.value.isPlaying == true;
    final aspectRatio = _videoAspectRatio(
      metadata: metadata,
      controller: controller,
    );
    final saveButton = Positioned(
      top: _attachmentOverlayPadding,
      right: _attachmentOverlayPadding,
      child: ShadButton.ghost(
        size: ShadButtonSize.sm,
        onPressed: _downloading
            ? null
            : () async {
                if (localFile == null) return;
                await _saveAttachmentToDevice(
                  context,
                  file: localFile,
                  filename: metadata.filename,
                );
              },
        child: const Icon(
          LucideIcons.save,
          size: _attachmentOverlayIconSize,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = _resolveAttachmentWidth(
          constraints,
          context,
          intrinsicWidth: metadata.width?.toDouble(),
        );
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
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: ShapeDecoration(
                          color: colors.card,
                          shape: const RoundedRectangleBorder(),
                        ),
                      ),
                      if (initialized && controller != null)
                        VideoPlayer(controller)
                      else
                        Center(
                          child: _AttachmentSpinner(
                            size: _attachmentVideoSpinnerSize,
                            color: colors.primary,
                          ),
                        ),
                      if (initialized && controller != null)
                        Center(
                          child: ShadButton.ghost(
                            size: ShadButtonSize.sm,
                            onPressed: _togglePlayback,
                            child: Icon(
                              playing ? LucideIcons.pause : LucideIcons.play,
                              size: _attachmentVideoIconSize,
                            ),
                          ),
                        ),
                      if (initialized) saveButton,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadAttachment({required bool showFeedback}) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
    });
    final l10n = context.l10n;
    final toaster = ShadToaster.maybeOf(context);
    try {
      final downloadDelegate = widget.downloadDelegate;
      final downloaded = downloadDelegate == null
          ? await _downloadViaXmpp()
          : await downloadDelegate.download();
      if (!mounted) return;
      if (!downloaded && showFeedback) {
        _showToast(
          l10n,
          toaster,
          l10n.chatAttachmentUnavailable,
          destructive: true,
        );
      }
    } on XmppFileTooBigException catch (error) {
      if (!mounted) return;
      if (showFeedback) {
        _showToast(
          l10n,
          toaster,
          _attachmentTooLargeMessage(l10n, error.maxBytes),
          destructive: true,
        );
      }
    } on Exception {
      if (!mounted) return;
      if (showFeedback) {
        _showToast(
          l10n,
          toaster,
          l10n.chatAttachmentUnavailable,
          destructive: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  Future<bool> _downloadViaXmpp() async {
    final xmpp = context.read<XmppService>();
    final downloadedPath = await xmpp.downloadInboundAttachment(
      metadataId: widget.metadata.id,
      stanzaId: widget.stanzaId,
    );
    return downloadedPath?.trim().isNotEmpty == true;
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null) return;
    final playing = controller.value.isPlaying;
    if (playing) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  void _initializeVideoIfAvailable() {
    _initFailed = false;
    final path = widget.metadata.path?.trim();
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!file.existsSync()) return;
    final controller = VideoPlayerController.file(file);
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    }).catchError((_) {
      if (!mounted) return;
      controller.dispose();
      if (identical(_controller, controller)) {
        _controller = null;
      }
      setState(() {
        _initFailed = true;
      });
    });
  }

  void _resetController() {
    final controller = _controller;
    if (controller == null) return;
    controller.dispose();
    _controller = null;
    _initFailed = false;
  }

  double _videoAspectRatio({
    required FileMetadataData metadata,
    required VideoPlayerController? controller,
  }) {
    final controllerValue = controller?.value;
    final controllerRatio = controllerValue?.aspectRatio;
    if (controllerRatio != null && controllerRatio > 0) {
      return controllerRatio;
    }
    final width = metadata.width;
    final height = metadata.height;
    if (width != null && height != null && width > 0 && height > 0) {
      return width / height;
    }
    return _attachmentVideoFallbackAspectRatio;
  }
}

double _resolveAttachmentWidth(
  BoxConstraints constraints,
  BuildContext context, {
  required double? intrinsicWidth,
}) {
  final availableWidth = constraints.maxWidth.isFinite
      ? constraints.maxWidth
      : MediaQuery.sizeOf(context).width;
  final targetWidth = intrinsicWidth != null && intrinsicWidth > 0
      ? intrinsicWidth
      : math.min(_attachmentUnknownMaxWidth, availableWidth);
  return math.min(targetWidth, availableWidth * _attachmentMaxWidthFraction);
}

Future<void> _openImagePreview(
  BuildContext context, {
  required File file,
  required FileMetadataData metadata,
}) async {
  if (!await file.exists()) return;
  if (!context.mounted) return;
  await showShadDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return _ImageAttachmentPreviewDialog(
        file: file,
        metadata: metadata,
      );
    },
  );
}

class _ImageAttachmentPreviewDialog extends StatelessWidget {
  const _ImageAttachmentPreviewDialog({
    required this.file,
    required this.metadata,
  });

  final File file;
  final FileMetadataData metadata;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final maxWidth = (mediaSize.width - 96).clamp(240.0, mediaSize.width);
    final maxHeight = (mediaSize.height - 160).clamp(240.0, mediaSize.height);
    final intrinsic = _intrinsicSizeFrom(metadata);
    final targetSize = _fitWithinBounds(
      intrinsicSize: intrinsic,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    final colors = context.colorScheme;
    final radius = BorderRadius.circular(_attachmentPreviewCornerRadius);
    final borderSide = BorderSide(color: colors.border);
    return ShadDialog(
      padding: const EdgeInsets.all(12),
      gap: 12,
      closeIcon: const SizedBox.shrink(),
      constraints: BoxConstraints(
        maxWidth: targetSize.width + 24,
        maxHeight: targetSize.height + 24,
      ),
      child: Stack(
        children: [
          Center(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.card,
                shape: ContinuousRectangleBorder(
                  borderRadius: radius,
                  side: borderSide,
                ),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: SizedBox(
                  width: targetSize.width,
                  height: targetSize.height,
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () async {
                    await _saveAttachmentToDevice(
                      context,
                      file: file,
                      filename: metadata.filename,
                    );
                  },
                  child: const Icon(
                    LucideIcons.save,
                    size: _attachmentOverlayIconSize,
                  ),
                ),
                const SizedBox(width: _attachmentActionSpacing),
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(
                    LucideIcons.x,
                    size: _attachmentOverlayIconSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Size? _intrinsicSizeFrom(FileMetadataData metadata) {
  final width = metadata.width;
  final height = metadata.height;
  if (width == null || height == null) return null;
  if (width <= 0 || height <= 0) return null;
  return Size(width.toDouble(), height.toDouble());
}

Size _fitWithinBounds({
  required Size? intrinsicSize,
  required double maxWidth,
  required double maxHeight,
}) {
  final cappedWidth = math.max(0.0, maxWidth);
  final cappedHeight = math.max(0.0, maxHeight);
  if (intrinsicSize == null ||
      intrinsicSize.width <= 0 ||
      intrinsicSize.height <= 0) {
    final width = math.min(cappedWidth, 360.0);
    final height = math.min(cappedHeight, width * 0.75);
    return Size(width, height);
  }
  final aspectRatio = intrinsicSize.width / intrinsicSize.height;
  var width = math.min(intrinsicSize.width, cappedWidth);
  var height = width / aspectRatio;
  if (height > cappedHeight && cappedHeight > 0) {
    height = cappedHeight;
    width = height * aspectRatio;
  }
  return Size(width, height);
}

class _FileAttachment extends StatefulWidget {
  const _FileAttachment({
    required this.metadata,
    required this.stanzaId,
    required this.autoDownload,
    required this.autoDownloadUserInitiated,
    this.downloadDelegate,
  });

  final FileMetadataData metadata;
  final String stanzaId;
  final bool autoDownload;
  final bool autoDownloadUserInitiated;
  final AttachmentDownloadDelegate? downloadDelegate;

  @override
  State<_FileAttachment> createState() => _FileAttachmentState();
}

class _FileAttachmentState extends State<_FileAttachment> {
  var _downloading = false;
  var _autoDownloadRequested = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final metadata = widget.metadata;
    final url = metadata.sourceUrls == null || metadata.sourceUrls!.isEmpty
        ? null
        : metadata.sourceUrls!.first;
    final path = metadata.path?.trim();
    final localFile = path == null || path.isEmpty ? null : File(path);
    final hasLocalFile = localFile?.existsSync() ?? false;
    final canDownload = url != null || widget.downloadDelegate != null;
    if (widget.autoDownload &&
        !_autoDownloadRequested &&
        !_downloading &&
        !hasLocalFile &&
        canDownload) {
      _autoDownloadRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _downloadOnly(showFeedback: widget.autoDownloadUserInitiated);
      });
    }
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
            SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: _AttachmentSpinner(
                  size: 18,
                  color: colors.primary,
                ),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AxiIconButton(
                  iconData: LucideIcons.save,
                  tooltip: l10n.commonSave,
                  onPressed:
                      hasLocalFile || canDownload ? _saveAttachment : null,
                ),
                const SizedBox(width: _attachmentActionSpacing),
                AxiIconButton(
                  iconData: LucideIcons.download,
                  tooltip: l10n.chatAttachmentDownload,
                  onPressed: hasLocalFile || canDownload
                      ? () => _downloadAndOpen(existingPath: metadata.path)
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _saveAttachment() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
    });
    final l10n = context.l10n;
    final toaster = ShadToaster.maybeOf(context);
    try {
      final path = await _resolveLocalPath(existingPath: widget.metadata.path);
      if (!mounted) return;
      if (path == null || path.trim().isEmpty) {
        _showToast(
          l10n,
          toaster,
          l10n.chatAttachmentUnavailable,
          destructive: true,
        );
        return;
      }
      final file = File(path);
      await _saveAttachmentToDevice(
        context,
        file: file,
        filename: widget.metadata.filename,
      );
    } on XmppFileTooBigException catch (error) {
      if (!mounted) return;
      _showToast(
        l10n,
        toaster,
        _attachmentTooLargeMessage(l10n, error.maxBytes),
        destructive: true,
      );
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
      final resolvedPath = await _resolveLocalPath(existingPath: existingPath);
      if (!mounted) return;
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
    } on XmppFileTooBigException catch (error) {
      if (!mounted) return;
      _showToast(
        l10n,
        toaster,
        _attachmentTooLargeMessage(l10n, error.maxBytes),
        destructive: true,
      );
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

  Future<void> _downloadOnly({required bool showFeedback}) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
    });
    final l10n = context.l10n;
    final toaster = ShadToaster.maybeOf(context);
    try {
      final resolvedPath =
          await _resolveLocalPath(existingPath: widget.metadata.path);
      final downloaded = resolvedPath?.trim().isNotEmpty == true;
      if (!mounted) return;
      if (!downloaded && showFeedback) {
        _showToast(
          l10n,
          toaster,
          l10n.chatAttachmentUnavailable,
          destructive: true,
        );
      }
    } on XmppFileTooBigException catch (error) {
      if (!mounted) return;
      if (showFeedback) {
        _showToast(
          l10n,
          toaster,
          _attachmentTooLargeMessage(l10n, error.maxBytes),
          destructive: true,
        );
      }
    } on Exception {
      if (!mounted) return;
      if (showFeedback) {
        _showToast(
          l10n,
          toaster,
          l10n.chatAttachmentUnavailable,
          destructive: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  Future<String?> _downloadViaXmpp() async {
    final xmpp = context.read<XmppService>();
    return xmpp.downloadInboundAttachment(
      metadataId: widget.metadata.id,
      stanzaId: widget.stanzaId,
    );
  }

  Future<String?> _resolveLocalPath({
    required String? existingPath,
  }) async {
    final resolvedExisting = existingPath?.trim();
    final existingFile = resolvedExisting == null || resolvedExisting.isEmpty
        ? null
        : File(resolvedExisting);
    if (existingFile?.existsSync() ?? false) return existingFile!.path;
    final downloadDelegate = widget.downloadDelegate;
    if (downloadDelegate != null) {
      final downloaded = await downloadDelegate.download();
      if (!downloaded) return null;
      final refreshed = await _reloadMetadata();
      final refreshedPath = refreshed?.path?.trim();
      if (refreshedPath == null || refreshedPath.isEmpty) return null;
      final refreshedFile = File(refreshedPath);
      return refreshedFile.existsSync() ? refreshedFile.path : null;
    }
    return _downloadViaXmpp();
  }

  Future<FileMetadataData?> _reloadMetadata() async {
    final xmpp = context.read<XmppService>();
    final db = await xmpp.database;
    return db.getFileMetadata(widget.metadata.id);
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
                spacing: _attachmentRemoteBodySpacing,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.lock,
                        size: _attachmentRemoteIconSize,
                        color: colors.mutedForeground,
                      ),
                      const SizedBox(width: _attachmentRemoteSpacing),
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
                          ? _AttachmentSpinner(
                              size: 16,
                              color: colors.primaryForeground,
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
                spacing: _attachmentRemoteBodySpacing,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.image,
                        size: _attachmentRemoteIconSize,
                        color: colors.mutedForeground,
                      ),
                      const SizedBox(width: _attachmentRemoteSpacing),
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
                          ? _AttachmentSpinner(
                              size: 16,
                              color: colors.primaryForeground,
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

class _RemoteVideoAttachment extends StatelessWidget {
  const _RemoteVideoAttachment({
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
                spacing: _attachmentRemoteBodySpacing,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.video,
                        size: _attachmentRemoteIconSize,
                        color: colors.mutedForeground,
                      ),
                      const SizedBox(width: _attachmentRemoteSpacing),
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
                          ? _AttachmentSpinner(
                              size: 16,
                              color: colors.primaryForeground,
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

Future<void> _saveAttachmentToDevice(
  BuildContext context, {
  required File file,
  required String filename,
}) async {
  final l10n = context.l10n;
  final toaster = ShadToaster.maybeOf(context);
  if (!await file.exists()) {
    _showToast(
      l10n,
      toaster,
      l10n.chatAttachmentUnavailableDevice,
      destructive: true,
    );
    return;
  }
  final trimmedName = filename.trim();
  final resolvedName =
      trimmedName.isNotEmpty ? trimmedName : p.basename(file.path);
  final savePath = await FilePicker.platform.saveFile(
    fileName: resolvedName,
  );
  if (savePath == null || savePath.trim().isEmpty) return;
  try {
    final destination = File(savePath);
    if (p.equals(destination.path, file.path)) return;
    if (await destination.exists()) {
      await destination.delete();
    }
    await file.copy(destination.path);
  } on Exception {
    _showToast(
      l10n,
      toaster,
      l10n.chatAttachmentUnavailable,
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

String _attachmentTooLargeMessage(
  AppLocalizations l10n,
  int? maxBytes,
) {
  final resolvedLimit =
      maxBytes == null || maxBytes <= 0 ? null : _formatSize(maxBytes, l10n);
  if (resolvedLimit == null) {
    return _attachmentTooLargeMessageDefault;
  }
  return '$_attachmentTooLargeMessagePrefix$resolvedLimit$_attachmentTooLargeMessageSuffix';
}
