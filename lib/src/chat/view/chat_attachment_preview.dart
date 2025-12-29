import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/attachments/attachment_auto_download_settings.dart';
import 'package:axichat/src/attachments/attachment_metadata_extensions.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/media_decode_safety.dart';
import 'package:axichat/src/common/url_safety.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart'
    show XmppFileTooBigException, XmppService;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
const double _attachmentSpinnerSize = 32.0;
const double _attachmentVideoFallbackAspectRatio = 16 / 9;
const double _attachmentRemoteIconSize = 18.0;
const double _attachmentRemoteSpacing = 8.0;
const double _attachmentRemoteBodySpacing = 12.0;
const double _attachmentUnknownMaxWidth = 420.0;
const double _attachmentMaxWidthFraction = 0.9;
const int _attachmentImagePreviewMaxBytes = 16 * 1024 * 1024;
const int _attachmentImageMaxPixels = 16 * 1024 * 1024;
const int _attachmentImageMaxFrames = 60;
const int _attachmentImageMinDimension = 1;
const int _attachmentImageMinBytes = 1;
const int _attachmentImageMinFrameCount = 1;
const int _attachmentVideoPreviewMaxBytes = 64 * 1024 * 1024;
const int _attachmentVideoMaxPixels = 32 * 1024 * 1024;
const int _attachmentVideoMinDimensionPixels = 1;
const int _attachmentVideoMinBytes = 1;
const double _attachmentVideoMinDimension = 1.0;
const String _attachmentShareDirName = 'attachment_shares';
const String _attachmentShareDirPrefix = 'share_';
const String _attachmentShareFallbackName = 'attachment';
const int _attachmentShareNameMaxLength = 120;
const int _attachmentShareNameSubstringStart = 0;
const Duration _attachmentShareCleanupAge = Duration(days: 1);
const bool _attachmentShareCleanupFollowLinks = false;
const Duration _attachmentImageDecodeTimeout = Duration(seconds: 2);
const Duration _attachmentVideoInitTimeout = Duration(seconds: 3);
const ImageDecodeLimits _attachmentImageDecodeLimits = ImageDecodeLimits(
  maxBytes: _attachmentImagePreviewMaxBytes,
  maxPixels: _attachmentImageMaxPixels,
  maxFrames: _attachmentImageMaxFrames,
  minDimension: _attachmentImageMinDimension,
  decodeTimeout: _attachmentImageDecodeTimeout,
  minBytes: _attachmentImageMinBytes,
  minFrames: _attachmentImageMinFrameCount,
);
const int _attachmentMillisecondsPerSecond = 1000;
const int _attachmentMacOsQuarantineRadix = 16;
const String _attachmentMacOsQuarantineAgent = appDisplayName;
const String _attachmentMacOsQuarantineCommand = 'xattr';
const String _attachmentMacOsQuarantineWriteArg = '-w';
const String _attachmentMacOsQuarantineAttribute = 'com.apple.quarantine';
const String _attachmentMacOsQuarantineFlags = '0083';
const String _attachmentMacOsQuarantineSeparator = ';';
const String _attachmentMacOsQuarantineOrigin = '';
const String _attachmentWindowsZoneIdentifierSuffix = ':Zone.Identifier';
const String _attachmentWindowsZoneTransferHeader = '[ZoneTransfer]';
const String _attachmentWindowsZoneEntrySeparator = '\r\n';
const String _attachmentWindowsZoneIdLabel = 'ZoneId';
const String _attachmentWindowsZoneIdInternetValue = '3';
const String _attachmentWindowsZoneIdEntry =
    '$_attachmentWindowsZoneIdLabel=$_attachmentWindowsZoneIdInternetValue';
const String _attachmentWindowsZoneIdentifierContent =
    '$_attachmentWindowsZoneTransferHeader'
    '$_attachmentWindowsZoneEntrySeparator'
    '$_attachmentWindowsZoneIdEntry'
    '$_attachmentWindowsZoneEntrySeparator';
const String _mediaDecodeGuardKeyPrefix = 'attachment:';
const String _attachmentTooLargeMessageDefault =
    'Attachment exceeds the server limit.';
const String _attachmentTooLargeMessagePrefix =
    'Attachment exceeds the server limit (';
const String _attachmentTooLargeMessageSuffix = ').';
const int _acknowledgedHighRiskAttachmentMaxEntries = 256;
final LinkedHashSet<String> _acknowledgedHighRiskAttachmentIds =
    LinkedHashSet<String>();

extension _FileMetadataRiskExtension on FileMetadataData {
  FileTypeReport get declaredTypeReport => buildDeclaredFileTypeReport(
        declaredMimeType: mimeType,
        fileName: filename,
        path: path,
      );

  String get riskAcknowledgementId => id;
}

bool _hasAcknowledgedHighRisk(String? attachmentId) {
  final String? resolvedId = attachmentId?.trim();
  if (resolvedId == null || resolvedId.isEmpty) {
    return false;
  }
  return _acknowledgedHighRiskAttachmentIds.contains(resolvedId);
}

void _registerHighRiskAcknowledgement(String? attachmentId) {
  final String? resolvedId = attachmentId?.trim();
  if (resolvedId == null || resolvedId.isEmpty) {
    return;
  }
  _acknowledgedHighRiskAttachmentIds
    ..remove(resolvedId)
    ..add(resolvedId);
  _evictAcknowledgedHighRiskAttachmentIdsIfNeeded();
}

void _evictAcknowledgedHighRiskAttachmentIdsIfNeeded() {
  while (_acknowledgedHighRiskAttachmentIds.length >
      _acknowledgedHighRiskAttachmentMaxEntries) {
    _acknowledgedHighRiskAttachmentIds
        .remove(_acknowledgedHighRiskAttachmentIds.first);
  }
}

Future<bool> _confirmHighRiskAction(
  BuildContext context, {
  required FileTypeReport report,
  required String? fileName,
  required String confirmLabel,
  required String? acknowledgementId,
  required bool requireConfirmation,
}) async {
  final FileOpenRisk risk = assessFileOpenRisk(
    report: report,
    fileName: fileName,
  );
  if (!risk.isWarning) {
    return true;
  }
  if (_hasAcknowledgedHighRisk(acknowledgementId)) {
    return true;
  }
  if (!requireConfirmation) {
    return false;
  }
  if (!context.mounted) {
    return false;
  }
  final l10n = context.l10n;
  final approved = await confirm(
    context,
    title: l10n.chatAttachmentHighRiskTitle,
    message: l10n.chatAttachmentHighRiskMessage,
    confirmLabel: confirmLabel,
    cancelLabel: l10n.commonCancel,
    destructiveConfirm: true,
  );
  if (approved == true) {
    _registerHighRiskAcknowledgement(acknowledgementId);
    return true;
  }
  return false;
}

Future<bool> _confirmDownloadAllowed(
  BuildContext context, {
  required FileMetadataData metadata,
  required FileTypeReport? report,
  required bool requireConfirmation,
}) async {
  final FileTypeReport resolvedReport = report ?? metadata.declaredTypeReport;
  return _confirmHighRiskAction(
    context,
    report: resolvedReport,
    fileName: metadata.filename,
    confirmLabel: context.l10n.chatAttachmentDownload,
    acknowledgementId: metadata.riskAcknowledgementId,
    requireConfirmation: requireConfirmation,
  );
}

Future<bool> _confirmExportAllowed(
  BuildContext context, {
  required FileMetadataData metadata,
  required FileTypeReport report,
  required String confirmLabel,
}) {
  return _confirmHighRiskAction(
    context,
    report: report,
    fileName: metadata.filename,
    confirmLabel: confirmLabel,
    acknowledgementId: metadata.riskAcknowledgementId,
    requireConfirmation: true,
  );
}

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
    required this.autoDownloadSettings,
    required this.autoDownloadAllowed,
    this.autoDownloadUserInitiated = false,
    this.downloadDelegate,
    this.onAllowPressed,
  });

  final String stanzaId;
  final Stream<FileMetadataData?> metadataStream;
  final FileMetadataData? initialMetadata;
  final bool allowed;
  final AttachmentAutoDownloadSettings autoDownloadSettings;
  final bool autoDownloadAllowed;
  final bool autoDownloadUserInitiated;
  final AttachmentDownloadDelegate? downloadDelegate;
  final VoidCallback? onAllowPressed;

  bool _shouldAutoDownload(FileMetadataData metadata) {
    if (autoDownloadUserInitiated) {
      return true;
    }
    if (!autoDownloadAllowed) {
      return false;
    }
    return autoDownloadSettings.allowsMetadata(metadata);
  }

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
                    size: _attachmentSpinnerSize,
                    color: colors.primary,
                  ),
                ),
              );
            }
            return _AttachmentError(
              message: l10n.chatAttachmentUnavailable,
            );
          }
          final FileTypeReport declaredReport = metadata.declaredTypeReport;

          final shouldAutoDownload = _shouldAutoDownload(metadata);
          final path = metadata.path?.trim();
          final localFile = path == null || path.isEmpty ? null : File(path);
          final hasLocalFile = localFile?.existsSync() ?? false;
          if (hasLocalFile) {
            return FutureBuilder<FileTypeReport>(
              future: inspectFileType(
                file: localFile!,
                declaredMimeType: metadata.mimeType,
                fileName: metadata.filename,
              ),
              builder: (context, typeSnapshot) {
                if (typeSnapshot.connectionState != ConnectionState.done) {
                  return _AttachmentSurface(
                    child: Center(
                      child: _AttachmentSpinner(
                        size: _attachmentSpinnerSize,
                        color: colors.primary,
                      ),
                    ),
                  );
                }
                final FileTypeReport? report = typeSnapshot.data;
                final FileTypeReport resolvedReport = report ?? declaredReport;
                final bool useDeclaredFallback =
                    !resolvedReport.hasReliableDetection;
                final bool isImage = resolvedReport.isDetectedImage ||
                    (useDeclaredFallback && resolvedReport.isDeclaredImage);
                final bool isVideo = resolvedReport.isDetectedVideo ||
                    (useDeclaredFallback && resolvedReport.isDeclaredVideo);
                if (isImage) {
                  return _ImageAttachment(
                    metadata: metadata,
                    stanzaId: stanzaId,
                    autoDownload: shouldAutoDownload,
                    autoDownloadUserInitiated: autoDownloadUserInitiated,
                    downloadDelegate: downloadDelegate,
                    typeReport: resolvedReport,
                  );
                }
                if (isVideo) {
                  return _VideoAttachment(
                    metadata: metadata,
                    stanzaId: stanzaId,
                    autoDownload: shouldAutoDownload,
                    autoDownloadUserInitiated: autoDownloadUserInitiated,
                    downloadDelegate: downloadDelegate,
                    typeReport: resolvedReport,
                  );
                }
                return _FileAttachment(
                  metadata: metadata,
                  stanzaId: stanzaId,
                  autoDownload: shouldAutoDownload,
                  autoDownloadUserInitiated: autoDownloadUserInitiated,
                  downloadDelegate: downloadDelegate,
                  typeReport: resolvedReport,
                );
              },
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
              autoDownload: shouldAutoDownload,
              autoDownloadUserInitiated: autoDownloadUserInitiated,
              downloadDelegate: downloadDelegate,
              typeReport: declaredReport,
            );
          }
          if (metadata.isVideo) {
            return _VideoAttachment(
              metadata: metadata,
              stanzaId: stanzaId,
              autoDownload: shouldAutoDownload,
              autoDownloadUserInitiated: autoDownloadUserInitiated,
              downloadDelegate: downloadDelegate,
              typeReport: declaredReport,
            );
          }
          return _FileAttachment(
            metadata: metadata,
            stanzaId: stanzaId,
            autoDownload: shouldAutoDownload,
            autoDownloadUserInitiated: autoDownloadUserInitiated,
            downloadDelegate: downloadDelegate,
            typeReport: declaredReport,
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
    this.typeReport,
  });

  final FileMetadataData metadata;
  final String stanzaId;
  final bool autoDownload;
  final bool autoDownloadUserInitiated;
  final AttachmentDownloadDelegate? downloadDelegate;
  final FileTypeReport? typeReport;

  @override
  State<_ImageAttachment> createState() => _ImageAttachmentState();
}

class _ImageAttachmentState extends State<_ImageAttachment> {
  var _downloading = false;
  var _autoDownloadRequested = false;
  Future<bool>? _previewAllowed;
  String? _previewPath;

  bool get _encrypted =>
      widget.metadata.encryptionScheme?.trim().isNotEmpty == true;

  @override
  void didUpdateWidget(covariant _ImageAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPath = oldWidget.metadata.path?.trim();
    final nextPath = widget.metadata.path?.trim();
    if (oldPath != nextPath) {
      _previewAllowed = null;
      _previewPath = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
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
        _downloadAttachment(
          showFeedback: widget.autoDownloadUserInitiated,
          requireConfirmation: widget.autoDownloadUserInitiated,
        );
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
              : () => _downloadAttachment(
                    showFeedback: true,
                    requireConfirmation: true,
                  ),
        );
      }
      return _RemoteImageAttachment(
        filename: metadata.filename,
        downloading: _downloading,
        onPressed: _downloading
            ? null
            : () => _downloadAttachment(
                  showFeedback: true,
                  requireConfirmation: true,
                ),
      );
    }
    final previewFile = localFile!;
    final previewAllowedFuture = _resolvePreviewAllowed(
      previewFile,
      metadataId: metadata.id,
    );
    return FutureBuilder<bool>(
      future: previewAllowedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _AttachmentSurface(
            child: Center(
              child: _AttachmentSpinner(
                size: _attachmentSpinnerSize,
                color: colors.primary,
              ),
            ),
          );
        }
        final allowed = snapshot.data ?? false;
        if (!allowed) {
          return _FileAttachment(
            metadata: metadata,
            stanzaId: widget.stanzaId,
            autoDownload: widget.autoDownload,
            autoDownloadUserInitiated: widget.autoDownloadUserInitiated,
            downloadDelegate: widget.downloadDelegate,
            typeReport: widget.typeReport,
          );
        }
        final image = Image.file(
          previewFile,
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
                      onTap: () => _openImagePreview(
                        context,
                        file: previewFile,
                        metadata: metadata,
                        typeReport: widget.typeReport,
                      ),
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
      },
    );
  }

  Future<bool> _resolvePreviewAllowed(
    File file, {
    required String metadataId,
  }) {
    final path = file.path;
    final cachedFuture = _previewAllowed;
    if (cachedFuture != null && _previewPath == path) {
      return cachedFuture;
    }
    _previewPath = path;
    final nextFuture = _isImagePreviewAllowed(
      file,
      metadataId: metadataId,
    );
    _previewAllowed = nextFuture;
    return nextFuture;
  }

  Future<void> _downloadAttachment({
    required bool showFeedback,
    required bool requireConfirmation,
  }) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
    });
    final l10n = context.l10n;
    final toaster = ShadToaster.maybeOf(context);
    try {
      final allowed = await _confirmDownloadAllowed(
        context,
        metadata: widget.metadata,
        report: widget.typeReport,
        requireConfirmation: requireConfirmation,
      );
      if (!allowed || !mounted) return;
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
    this.typeReport,
  });

  final FileMetadataData metadata;
  final String stanzaId;
  final bool autoDownload;
  final bool autoDownloadUserInitiated;
  final AttachmentDownloadDelegate? downloadDelegate;
  final FileTypeReport? typeReport;

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
        _downloadAttachment(
          showFeedback: widget.autoDownloadUserInitiated,
          requireConfirmation: widget.autoDownloadUserInitiated,
        );
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
              : () => _downloadAttachment(
                    showFeedback: true,
                    requireConfirmation: true,
                  ),
        );
      }
      return _RemoteVideoAttachment(
        filename: metadata.filename,
        downloading: _downloading,
        onPressed: _downloading
            ? null
            : () => _downloadAttachment(
                  showFeedback: true,
                  requireConfirmation: true,
                ),
      );
    }
    if (_initFailed) {
      return _FileAttachment(
        metadata: metadata,
        stanzaId: widget.stanzaId,
        autoDownload: widget.autoDownload,
        autoDownloadUserInitiated: widget.autoDownloadUserInitiated,
        downloadDelegate: widget.downloadDelegate,
        typeReport: widget.typeReport,
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
    final actionButtons = Positioned(
      top: _attachmentOverlayPadding,
      right: _attachmentOverlayPadding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: _downloading
                ? null
                : () async {
                    if (localFile == null) return;
                    await _handleSaveAttachment(localFile);
                  },
            child: const Icon(
              LucideIcons.save,
              size: _attachmentOverlayIconSize,
            ),
          ),
          const SizedBox(width: _attachmentActionSpacing),
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: _downloading
                ? null
                : () async {
                    if (localFile == null) return;
                    await _handleShareAttachment(localFile);
                  },
            child: const Icon(
              LucideIcons.share2,
              size: _attachmentOverlayIconSize,
            ),
          ),
        ],
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
                      if (initialized) actionButtons,
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

  Future<void> _downloadAttachment({
    required bool showFeedback,
    required bool requireConfirmation,
  }) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
    });
    final l10n = context.l10n;
    final toaster = ShadToaster.maybeOf(context);
    try {
      final allowed = await _confirmDownloadAllowed(
        context,
        metadata: widget.metadata,
        report: widget.typeReport,
        requireConfirmation: requireConfirmation,
      );
      if (!allowed || !mounted) return;
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

  Future<void> _handleSaveAttachment(File file) async {
    final l10n = context.l10n;
    final FileTypeReport report =
        widget.typeReport ?? widget.metadata.declaredTypeReport;
    final bool allowed = await _confirmExportAllowed(
      context,
      metadata: widget.metadata,
      report: report,
      confirmLabel: l10n.chatAttachmentExportConfirm,
    );
    if (!mounted || !allowed) return;
    await _saveAttachmentToDevice(
      context,
      file: file,
      filename: widget.metadata.filename,
    );
  }

  Future<void> _handleShareAttachment(File file) async {
    final l10n = context.l10n;
    final FileTypeReport report =
        widget.typeReport ?? widget.metadata.declaredTypeReport;
    final bool allowed = await _confirmExportAllowed(
      context,
      metadata: widget.metadata,
      report: report,
      confirmLabel: l10n.chatActionShare,
    );
    if (!mounted || !allowed) return;
    await _shareAttachmentFromFile(
      context,
      file: file,
      filename: widget.metadata.filename,
    );
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
    final guardKey = _mediaDecodeGuardKey(widget.metadata.id);
    if (!MediaDecodeGuard.instance.allowAttempt(guardKey)) {
      _markVideoInitFailed();
      return;
    }
    final path = widget.metadata.path?.trim();
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!file.existsSync()) return;
    if (!_isVideoMetadataAllowed(widget.metadata)) {
      _markVideoInitFailed();
      return;
    }
    final length = _safeFileLength(file);
    if (length == null || length < _attachmentVideoMinBytes) {
      _markVideoInitFailed();
      return;
    }
    if (length > _attachmentVideoPreviewMaxBytes) {
      _markVideoInitFailed();
      return;
    }
    final controller = VideoPlayerController.file(file);
    _controller = controller;
    controller.initialize().timeout(_attachmentVideoInitTimeout).then((_) {
      if (!mounted) return;
      final size = controller.value.size;
      if (!_isVideoFrameAllowed(size)) {
        _disposeVideoController(controller);
        MediaDecodeGuard.instance.registerFailure(guardKey);
        _markVideoInitFailed();
        return;
      }
      MediaDecodeGuard.instance.registerSuccess(guardKey);
      setState(() {});
    }).catchError((_) {
      if (!mounted) return;
      _disposeVideoController(controller);
      MediaDecodeGuard.instance.registerFailure(guardKey);
      _markVideoInitFailed();
    });
  }

  int? _safeFileLength(File file) {
    try {
      return file.lengthSync();
    } on Exception {
      return null;
    }
  }

  bool _isVideoMetadataAllowed(FileMetadataData metadata) {
    final sizeBytes = metadata.sizeBytes;
    if (sizeBytes != null && sizeBytes > _attachmentVideoPreviewMaxBytes) {
      return false;
    }
    final width = metadata.width;
    final height = metadata.height;
    if (width == null || height == null) {
      return true;
    }
    if (width < _attachmentVideoMinDimensionPixels ||
        height < _attachmentVideoMinDimensionPixels) {
      return true;
    }
    final pixelCount = width * height;
    return pixelCount <= _attachmentVideoMaxPixels;
  }

  bool _isVideoFrameAllowed(Size size) {
    final width = size.width;
    final height = size.height;
    if (width < _attachmentVideoMinDimension ||
        height < _attachmentVideoMinDimension) {
      return false;
    }
    final pixelCount = width * height;
    return pixelCount <= _attachmentVideoMaxPixels.toDouble();
  }

  void _markVideoInitFailed() {
    if (!mounted) {
      _initFailed = true;
      return;
    }
    setState(() {
      _initFailed = true;
    });
  }

  void _disposeVideoController(VideoPlayerController controller) {
    controller.dispose();
    if (identical(_controller, controller)) {
      _controller = null;
    }
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
  FileTypeReport? typeReport,
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
        typeReport: typeReport,
      );
    },
  );
}

class _ImageAttachmentPreviewDialog extends StatelessWidget {
  const _ImageAttachmentPreviewDialog({
    required this.file,
    required this.metadata,
    this.typeReport,
  });

  final File file;
  final FileMetadataData metadata;
  final FileTypeReport? typeReport;

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
    final l10n = context.l10n;
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
                    final FileTypeReport report =
                        typeReport ?? metadata.declaredTypeReport;
                    final bool allowed = await _confirmExportAllowed(
                      context,
                      metadata: metadata,
                      report: report,
                      confirmLabel: l10n.chatAttachmentExportConfirm,
                    );
                    if (!context.mounted || !allowed) return;
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
                  onPressed: () async {
                    final FileTypeReport report =
                        typeReport ?? metadata.declaredTypeReport;
                    final bool allowed = await _confirmExportAllowed(
                      context,
                      metadata: metadata,
                      report: report,
                      confirmLabel: l10n.chatActionShare,
                    );
                    if (!context.mounted || !allowed) return;
                    await _shareAttachmentFromFile(
                      context,
                      file: file,
                      filename: metadata.filename,
                    );
                  },
                  child: const Icon(
                    LucideIcons.share2,
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

String _mediaDecodeGuardKey(String metadataId) =>
    '$_mediaDecodeGuardKeyPrefix$metadataId';

Future<bool> _isImagePreviewAllowed(
  File file, {
  required String metadataId,
}) async {
  final guardKey = _mediaDecodeGuardKey(metadataId);
  if (!MediaDecodeGuard.instance.allowAttempt(guardKey)) {
    return false;
  }
  final allowed = await isSafeImageFile(file, _attachmentImageDecodeLimits);
  if (!allowed) {
    MediaDecodeGuard.instance.registerFailure(guardKey);
    return false;
  }
  MediaDecodeGuard.instance.registerSuccess(guardKey);
  return true;
}

class _FileAttachment extends StatefulWidget {
  const _FileAttachment({
    required this.metadata,
    required this.stanzaId,
    required this.autoDownload,
    required this.autoDownloadUserInitiated,
    this.downloadDelegate,
    this.typeReport,
  });

  final FileMetadataData metadata;
  final String stanzaId;
  final bool autoDownload;
  final bool autoDownloadUserInitiated;
  final AttachmentDownloadDelegate? downloadDelegate;
  final FileTypeReport? typeReport;

  @override
  State<_FileAttachment> createState() => _FileAttachmentState();
}

class _AttachmentDownloadCancelledException implements Exception {
  const _AttachmentDownloadCancelledException();
}

class _FileAttachmentState extends State<_FileAttachment> {
  var _downloading = false;
  var _autoDownloadRequested = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final metadata = widget.metadata;
    final FileTypeReport report =
        widget.typeReport ?? metadata.declaredTypeReport;
    final url = metadata.sourceUrls == null || metadata.sourceUrls!.isEmpty
        ? null
        : metadata.sourceUrls!.first;
    final path = metadata.path?.trim();
    final localFile = path == null || path.isEmpty ? null : File(path);
    final hasLocalFile = localFile?.existsSync() ?? false;
    final canDownload = url != null || widget.downloadDelegate != null;
    final bool shareEnabled = hasLocalFile || canDownload;
    final FileOpenRisk risk = assessFileOpenRisk(
      report: report,
      fileName: metadata.filename,
    );
    final showWarningOpen = hasLocalFile && risk.isWarning;
    final IconData openIconData = showWarningOpen
        ? Icons.warning_amber_outlined
        : hasLocalFile
            ? LucideIcons.externalLink
            : LucideIcons.download;
    final String openTooltip = showWarningOpen
        ? l10n.chatAttachmentTypeMismatchConfirm
        : hasLocalFile
            ? l10n.chatAttachmentView
            : l10n.chatAttachmentDownload;
    final Color? openColor = showWarningOpen ? colors.destructive : null;
    final VoidCallback? openAction = hasLocalFile
        ? () => _openAttachment(
              context,
              path: metadata.path,
              declaredMimeType: metadata.mimeType,
              fileName: metadata.filename,
              typeReport: widget.typeReport,
              riskAcknowledgementId: metadata.riskAcknowledgementId,
            )
        : canDownload
            ? () => _downloadOnly(showFeedback: true, requireConfirmation: true)
            : null;
    if (widget.autoDownload &&
        !_autoDownloadRequested &&
        !_downloading &&
        !hasLocalFile &&
        canDownload) {
      _autoDownloadRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _downloadOnly(
          showFeedback: widget.autoDownloadUserInitiated,
          requireConfirmation: widget.autoDownloadUserInitiated,
        );
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
                  iconData: LucideIcons.share2,
                  tooltip: l10n.chatActionShare,
                  onPressed: shareEnabled ? _shareAttachment : null,
                ),
                const SizedBox(width: _attachmentActionSpacing),
                AxiIconButton(
                  iconData: openIconData,
                  tooltip: openTooltip,
                  color: openColor,
                  onPressed: openAction,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _saveAttachment() async {
    if (_downloading) return;
    final l10n = context.l10n;
    final FileTypeReport report =
        widget.typeReport ?? widget.metadata.declaredTypeReport;
    final bool allowed = await _confirmExportAllowed(
      context,
      metadata: widget.metadata,
      report: report,
      confirmLabel: l10n.chatAttachmentExportConfirm,
    );
    if (!allowed || !mounted) return;
    setState(() {
      _downloading = true;
    });
    final toaster = ShadToaster.maybeOf(context);
    try {
      final path = await _resolveLocalPath(
        existingPath: widget.metadata.path,
        requireConfirmation: true,
        typeReport: widget.typeReport,
      );
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
    } on _AttachmentDownloadCancelledException {
      return;
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

  Future<void> _shareAttachment() async {
    if (_downloading) return;
    final l10n = context.l10n;
    final FileTypeReport report =
        widget.typeReport ?? widget.metadata.declaredTypeReport;
    final bool allowed = await _confirmExportAllowed(
      context,
      metadata: widget.metadata,
      report: report,
      confirmLabel: l10n.chatActionShare,
    );
    if (!allowed || !mounted) return;
    final approved = await _confirmAttachmentShare(context);
    if (!mounted) return;
    if (approved != true) return;
    setState(() {
      _downloading = true;
    });
    final toaster = ShadToaster.maybeOf(context);
    try {
      final path = await _resolveLocalPath(
        existingPath: widget.metadata.path,
        requireConfirmation: true,
        typeReport: widget.typeReport,
      );
      if (!mounted) return;
      final trimmedPath = path?.trim();
      if (trimmedPath == null || trimmedPath.isEmpty) {
        _showToast(
          l10n,
          toaster,
          l10n.chatAttachmentUnavailable,
          destructive: true,
        );
        return;
      }
      final file = File(trimmedPath);
      await _shareAttachmentFromFile(
        context,
        file: file,
        filename: widget.metadata.filename,
        skipConfirm: true,
      );
    } on _AttachmentDownloadCancelledException {
      return;
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

  Future<void> _downloadOnly({
    required bool showFeedback,
    bool requireConfirmation = false,
  }) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
    });
    final l10n = context.l10n;
    final toaster = ShadToaster.maybeOf(context);
    try {
      final resolvedPath = await _resolveLocalPath(
        existingPath: widget.metadata.path,
        requireConfirmation: requireConfirmation,
        typeReport: widget.typeReport,
      );
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
    } on _AttachmentDownloadCancelledException {
      return;
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
    bool requireConfirmation = false,
    FileTypeReport? typeReport,
  }) async {
    final resolvedExisting = existingPath?.trim();
    final existingFile = resolvedExisting == null || resolvedExisting.isEmpty
        ? null
        : File(resolvedExisting);
    if (existingFile?.existsSync() ?? false) return existingFile!.path;
    final allowed = await _confirmDownloadAllowed(
      context,
      metadata: widget.metadata,
      report: typeReport,
      requireConfirmation: requireConfirmation,
    );
    if (!allowed || !mounted) {
      throw const _AttachmentDownloadCancelledException();
    }
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
  String? declaredMimeType,
  String? fileName,
  FileTypeReport? typeReport,
  String? riskAcknowledgementId,
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
    final report = typeReport ??
        await inspectFileType(
          file: file,
          declaredMimeType: declaredMimeType,
          fileName: fileName,
        );
    if (!context.mounted) return;
    final declaredLabel = report.declaredLabel;
    final detectedLabel = report.detectedLabel;
    final hasMismatchWarning =
        report.hasMismatch && declaredLabel != null && detectedLabel != null;
    if (hasMismatchWarning) {
      final approved = await confirm(
        context,
        title: l10n.chatAttachmentTypeMismatchTitle,
        message: l10n.chatAttachmentTypeMismatchMessage(
          declaredLabel,
          detectedLabel,
        ),
        confirmLabel: l10n.chatAttachmentTypeMismatchConfirm,
        destructiveConfirm: true,
      );
      if (approved != true) return;
      if (!context.mounted) return;
      _registerHighRiskAcknowledgement(riskAcknowledgementId);
    }
    if (!hasMismatchWarning) {
      final allowed = await _confirmHighRiskAction(
        context,
        report: report,
        fileName: fileName ?? path,
        confirmLabel: l10n.chatAttachmentTypeMismatchConfirm,
        acknowledgementId: riskAcknowledgementId,
        requireConfirmation: true,
      );
      if (!allowed || !context.mounted) return;
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
  final rawUrl = url?.trim();
  if (rawUrl == null || rawUrl.isEmpty) {
    _showToast(
      l10n,
      toaster,
      l10n.chatAttachmentInvalidLink,
      destructive: true,
    );
    return;
  }
  final report = assessLinkSafety(
    raw: rawUrl,
    kind: LinkSafetyKind.attachment,
  );
  if (report == null || !report.isSafe) {
    _showToast(
      l10n,
      toaster,
      l10n.chatAttachmentInvalidLink,
      destructive: true,
    );
    return;
  }
  final hostLabel = formatLinkSchemeHostLabel(report);
  final baseMessage = report.needsWarning
      ? l10n.chatOpenLinkWarningMessage(
          report.displayUri,
          hostLabel,
        )
      : l10n.chatOpenLinkMessage(
          report.displayUri,
          hostLabel,
        );
  final warningBlock = formatLinkWarningText(report.warnings);
  final action = await showLinkActionDialog(
    context,
    title: l10n.chatOpenLinkTitle,
    message: '$baseMessage$warningBlock',
    openLabel: l10n.chatOpenLinkConfirm,
    copyLabel: l10n.chatActionCopy,
    cancelLabel: l10n.commonCancel,
  );
  if (action == null) return;
  if (action == LinkAction.copy) {
    await Clipboard.setData(
      ClipboardData(text: report.displayUri),
    );
    return;
  }
  final launched =
      await launchUrl(report.uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    final target = report.displayHost;
    _showToast(
      l10n,
      toaster,
      l10n.chatAttachmentOpenFailed(target),
      destructive: true,
    );
  }
}

Future<bool> _confirmAttachmentShare(BuildContext context) async {
  final l10n = context.l10n;
  final approved = await confirm(
    context,
    title: l10n.chatActionShare,
    message: l10n.chatAttachmentExportMessage,
    confirmLabel: l10n.chatActionShare,
    cancelLabel: l10n.commonCancel,
    destructiveConfirm: false,
  );
  return approved == true;
}

Future<void> _shareAttachmentFromFile(
  BuildContext context, {
  required File file,
  required String filename,
  bool skipConfirm = false,
}) async {
  final l10n = context.l10n;
  final toaster = ShadToaster.maybeOf(context);
  if (!skipConfirm) {
    final confirmed = await _confirmAttachmentShare(context);
    if (!context.mounted) return;
    if (!confirmed) return;
  }
  final exists = await file.exists();
  if (!context.mounted) return;
  if (!exists) {
    _showToast(
      l10n,
      toaster,
      l10n.chatAttachmentUnavailableDevice,
      destructive: true,
    );
    return;
  }
  if (defaultTargetPlatform == TargetPlatform.linux) {
    await _saveAttachmentToDevice(
      context,
      file: file,
      filename: filename,
      skipConfirm: true,
    );
    return;
  }
  try {
    final sharedFile = await _prepareShareAttachmentFile(
      file: file,
      filename: filename,
    );
    if (!context.mounted) return;
    if (sharedFile == null) {
      _showToast(
        l10n,
        toaster,
        l10n.chatAttachmentUnavailable,
        destructive: true,
      );
      return;
    }
    await Share.shareXFiles([XFile(sharedFile.path)]);
  } on PlatformException {
    _showToast(
      l10n,
      toaster,
      l10n.chatAttachmentUnavailable,
      destructive: true,
    );
  } on Exception {
    _showToast(
      l10n,
      toaster,
      l10n.chatAttachmentUnavailable,
      destructive: true,
    );
  }
}

Future<void> _saveAttachmentToDevice(
  BuildContext context, {
  required File file,
  required String filename,
  bool skipConfirm = false,
}) async {
  final l10n = context.l10n;
  final toaster = ShadToaster.maybeOf(context);
  if (!skipConfirm) {
    final approved = await confirm(
      context,
      title: l10n.chatAttachmentExportTitle,
      message: l10n.chatAttachmentExportMessage,
      confirmLabel: l10n.chatAttachmentExportConfirm,
      cancelLabel: l10n.chatAttachmentExportCancel,
      destructiveConfirm: false,
    );
    if (approved != true) {
      return;
    }
  }
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
    await _applyDownloadProtections(destination);
  } on Exception {
    _showToast(
      l10n,
      toaster,
      l10n.chatAttachmentUnavailable,
      destructive: true,
    );
  }
}

Future<File?> _prepareShareAttachmentFile({
  required File file,
  required String filename,
}) async {
  if (!await file.exists()) {
    return null;
  }
  final entityType = await FileSystemEntity.type(
    file.path,
    followLinks: false,
  );
  if (entityType != FileSystemEntityType.file) {
    return null;
  }
  final shareDir = await _createAttachmentShareDir();
  final shareFileName = _sanitizeShareFileName(
    explicitName: filename,
    fallbackPath: file.path,
  );
  final sharePath = p.join(shareDir.path, shareFileName);
  final sharedFile = await file.copy(sharePath);
  await _applyDownloadProtections(sharedFile);
  return sharedFile;
}

Future<Directory> _createAttachmentShareDir() async {
  final tempDir = await getTemporaryDirectory();
  final shareRoot = Directory(p.join(tempDir.path, _attachmentShareDirName));
  if (!await shareRoot.exists()) {
    await shareRoot.create(recursive: true);
  }
  await _cleanupAttachmentShareRoot(shareRoot);
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final shareDirName = '$_attachmentShareDirPrefix$timestamp';
  final shareDir = Directory(p.join(shareRoot.path, shareDirName));
  if (!await shareDir.exists()) {
    await shareDir.create(recursive: true);
  }
  return shareDir;
}

Future<void> _cleanupAttachmentShareRoot(Directory shareRoot) async {
  final cutoff = DateTime.now().subtract(_attachmentShareCleanupAge);
  try {
    await for (final entity in shareRoot.list(
      followLinks: _attachmentShareCleanupFollowLinks,
    )) {
      if (entity is! Directory) {
        continue;
      }
      final baseName = p.basename(entity.path);
      if (!baseName.startsWith(_attachmentShareDirPrefix)) {
        continue;
      }
      FileStat stat;
      try {
        stat = await entity.stat();
      } on Exception {
        continue;
      }
      if (stat.modified.isAfter(cutoff)) {
        continue;
      }
      try {
        await entity.delete(recursive: true);
      } on Exception {
        continue;
      }
    }
  } on Exception {
    return;
  }
}

String _sanitizeShareFileName({
  required String? explicitName,
  required String fallbackPath,
}) {
  final trimmedName = explicitName?.trim();
  final candidate =
      trimmedName?.isNotEmpty == true ? trimmedName! : p.basename(fallbackPath);
  final normalized = p.basename(candidate).trim();
  final resolved =
      normalized.isNotEmpty ? normalized : _attachmentShareFallbackName;
  return _truncateShareFileName(resolved);
}

String _truncateShareFileName(String name) {
  if (name.length <= _attachmentShareNameMaxLength) {
    return name;
  }
  final extension = p.extension(name);
  if (extension.isEmpty || extension.length >= _attachmentShareNameMaxLength) {
    return name.substring(
      _attachmentShareNameSubstringStart,
      _attachmentShareNameMaxLength,
    );
  }
  final maxBaseLength = _attachmentShareNameMaxLength - extension.length;
  final base = name.substring(
    _attachmentShareNameSubstringStart,
    maxBaseLength,
  );
  return '$base$extension';
}

Future<void> _applyDownloadProtections(File destination) async {
  if (!await destination.exists()) {
    return;
  }
  if (Platform.isMacOS) {
    await _applyMacOsQuarantine(destination);
  }
  if (Platform.isWindows) {
    await _applyWindowsZoneIdentifier(destination);
  }
}

Future<void> _applyMacOsQuarantine(File destination) async {
  try {
    final value = _buildMacOsQuarantineValue();
    await Process.run(
      _attachmentMacOsQuarantineCommand,
      [
        _attachmentMacOsQuarantineWriteArg,
        _attachmentMacOsQuarantineAttribute,
        value,
        destination.path,
      ],
    );
  } on Exception {
    return;
  }
}

Future<void> _applyWindowsZoneIdentifier(File destination) async {
  try {
    final zonePath =
        '${destination.path}$_attachmentWindowsZoneIdentifierSuffix';
    final zoneFile = File(zonePath);
    await zoneFile.writeAsString(_attachmentWindowsZoneIdentifierContent);
  } on Exception {
    return;
  }
}

String _buildMacOsQuarantineValue() {
  final timestampSeconds =
      DateTime.now().millisecondsSinceEpoch ~/ _attachmentMillisecondsPerSecond;
  final timestampHex =
      timestampSeconds.toRadixString(_attachmentMacOsQuarantineRadix);
  final parts = <String>[
    _attachmentMacOsQuarantineFlags,
    timestampHex,
    _attachmentMacOsQuarantineAgent,
    _attachmentMacOsQuarantineOrigin,
  ];
  return parts.join(_attachmentMacOsQuarantineSeparator);
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
