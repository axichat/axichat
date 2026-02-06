// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/file_name_safety.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/media_decode_safety.dart';
import 'package:axichat/src/common/unicode_safety.dart';
import 'package:axichat/src/common/url_safety.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart'
    show XmppFileTooBigException;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class _AttachmentFileNameText extends StatelessWidget {
  const _AttachmentFileNameText({
    required this.filename,
    required this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String filename;
  final TextStyle style;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final UnicodeSanitizedText sanitized = sanitizeUnicodeControls(filename);
    return Text(
      sanitized.value,
      maxLines: maxLines,
      overflow: overflow,
      style: style,
    );
  }
}

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
const int _attachmentShareNameMaxLength = 120;
const int _attachmentSaveNameMaxLength = _attachmentShareNameMaxLength;
const Duration _attachmentShareCleanupAge = Duration(days: 1);
const Duration _attachmentShareCleanupDelay = Duration(minutes: 10);
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
    _acknowledgedHighRiskAttachmentIds.remove(
      _acknowledgedHighRiskAttachmentIds.first,
    );
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

Future<bool> confirmExportAllowed(
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

class AttachmentMetadataReloadDelegate {
  const AttachmentMetadataReloadDelegate(this._reload);

  final Future<FileMetadataData?> Function() _reload;

  Future<FileMetadataData?> reload() => _reload();
}

class ChatAttachmentPreview extends StatefulWidget {
  const ChatAttachmentPreview({
    super.key,
    required this.stanzaId,
    required this.metadataStream,
    this.initialMetadata,
    required this.allowed,
    this.downloadDelegate,
    this.metadataReloadDelegate,
    this.onAllowPressed,
    this.surfaceShape,
    this.maxWidthFraction,
  });

  final String stanzaId;
  final Stream<FileMetadataData?> metadataStream;
  final FileMetadataData? initialMetadata;
  final bool allowed;
  final AttachmentDownloadDelegate? downloadDelegate;
  final AttachmentMetadataReloadDelegate? metadataReloadDelegate;
  final VoidCallback? onAllowPressed;
  final OutlinedBorder? surfaceShape;
  final double? maxWidthFraction;

  @override
  State<ChatAttachmentPreview> createState() => _ChatAttachmentPreviewState();
}

class _ChatAttachmentPreviewState extends State<ChatAttachmentPreview> {
  Future<FileTypeReport>? _typeReportFuture;
  int? _typeReportKey;
  Future<bool>? _fileExistsFuture;
  int? _fileExistsKey;

  Future<FileTypeReport> _resolveTypeReportFuture({
    required FileMetadataData metadata,
    required File file,
  }) {
    final nextKey = Object.hash(
      metadata.id,
      file.path,
      metadata.mimeType,
      metadata.filename,
      metadata.sizeBytes,
    );
    final cachedFuture = _typeReportFuture;
    if (cachedFuture != null && _typeReportKey == nextKey) {
      return cachedFuture;
    }
    _typeReportKey = nextKey;
    final nextFuture = inspectFileType(
      file: file,
      declaredMimeType: metadata.mimeType,
      fileName: metadata.filename,
    );
    _typeReportFuture = nextFuture;
    return nextFuture;
  }

  void _clearTypeReportCache() {
    _typeReportFuture = null;
    _typeReportKey = null;
  }

  Future<bool> _resolveFileExistsFuture(File file) {
    final nextKey = file.path.hashCode;
    final cachedFuture = _fileExistsFuture;
    if (cachedFuture != null && _fileExistsKey == nextKey) {
      return cachedFuture;
    }
    _fileExistsKey = nextKey;
    final nextFuture = file.exists();
    _fileExistsFuture = nextFuture;
    return nextFuture;
  }

  void _clearFileExistsCache() {
    _fileExistsFuture = null;
    _fileExistsKey = null;
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final OutlinedBorder resolvedShape = widget.surfaceShape ??
        ContinuousRectangleBorder(
          borderRadius: context.radius,
        );
    final maxWidthFraction =
        widget.maxWidthFraction ?? sizing.dialogMaxHeightFraction;
    return RepaintBoundary(
      child: _AttachmentSurfaceScope(
        shape: resolvedShape,
        maxWidthFraction: maxWidthFraction,
        child: StreamBuilder<FileMetadataData?>(
          stream: widget.metadataStream,
          initialData: widget.initialMetadata,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _AttachmentError(message: snapshot.error.toString());
            }

            final l10n = context.l10n;
            final colors = context.colorScheme;
            final stanzaId = widget.stanzaId;
            final onAllowPressed = widget.onAllowPressed;
            final downloadDelegate = widget.downloadDelegate;
            final allowed = widget.allowed;
            final metadata = snapshot.data;
            if (metadata == null) {
              if (snapshot.connectionState != ConnectionState.active &&
                  snapshot.connectionState != ConnectionState.done) {
                return _AttachmentSurface(
                  child: Center(
                    child: AxiProgressIndicator(color: colors.primary),
                  ),
                );
              }
              return _AttachmentError(message: l10n.chatAttachmentUnavailable);
            }
            final FileTypeReport declaredReport = metadata.declaredTypeReport;

            final path = metadata.path?.trim();
            final localFile = path == null || path.isEmpty ? null : File(path);
            if (localFile != null) {
              final existsFuture = _resolveFileExistsFuture(localFile);
              return FutureBuilder<bool>(
                future: existsFuture,
                builder: (context, existsSnapshot) {
                  if (existsSnapshot.connectionState != ConnectionState.done) {
                    return _AttachmentSurface(
                      child: Center(
                        child: AxiProgressIndicator(color: colors.primary),
                      ),
                    );
                  }
                  final hasLocalFile = existsSnapshot.data ?? false;
                  if (!hasLocalFile) {
                    _clearTypeReportCache();
                    _clearFileExistsCache();
                  }
                  if (hasLocalFile) {
                    final typeReportFuture = _resolveTypeReportFuture(
                      metadata: metadata,
                      file: localFile,
                    );
                    return FutureBuilder<FileTypeReport>(
                      future: typeReportFuture,
                      builder: (context, typeSnapshot) {
                        if (typeSnapshot.connectionState !=
                            ConnectionState.done) {
                          return _AttachmentSurface(
                            child: Center(
                              child: AxiProgressIndicator(
                                color: colors.primary,
                              ),
                            ),
                          );
                        }
                        final FileTypeReport? report = typeSnapshot.data;
                        final FileTypeReport resolvedReport =
                            report ?? declaredReport;
                        final bool useDeclaredFallback =
                            !resolvedReport.hasReliableDetection;
                        final bool isImage = resolvedReport.isDetectedImage ||
                            (useDeclaredFallback &&
                                resolvedReport.isDeclaredImage);
                        final bool isVideo = resolvedReport.isDetectedVideo ||
                            (useDeclaredFallback &&
                                resolvedReport.isDeclaredVideo);
                        if (isImage) {
                          return _ImageAttachment(
                            metadata: metadata,
                            stanzaId: stanzaId,
                            hasLocalFile: true,
                            downloadDelegate: downloadDelegate,
                            metadataReloadDelegate:
                                widget.metadataReloadDelegate,
                            typeReport: resolvedReport,
                          );
                        }
                        if (isVideo) {
                          return _VideoAttachment(
                            metadata: metadata,
                            stanzaId: stanzaId,
                            hasLocalFile: true,
                            downloadDelegate: downloadDelegate,
                            metadataReloadDelegate:
                                widget.metadataReloadDelegate,
                            typeReport: resolvedReport,
                          );
                        }
                        return _FileAttachment(
                          metadata: metadata,
                          stanzaId: stanzaId,
                          hasLocalFile: true,
                          downloadDelegate: downloadDelegate,
                          metadataReloadDelegate: widget.metadataReloadDelegate,
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
                      hasLocalFile: false,
                      downloadDelegate: downloadDelegate,
                      metadataReloadDelegate: widget.metadataReloadDelegate,
                      typeReport: declaredReport,
                    );
                  }
                  if (metadata.isVideo) {
                    return _VideoAttachment(
                      metadata: metadata,
                      stanzaId: stanzaId,
                      hasLocalFile: false,
                      downloadDelegate: downloadDelegate,
                      metadataReloadDelegate: widget.metadataReloadDelegate,
                      typeReport: declaredReport,
                    );
                  }
                  return _FileAttachment(
                    metadata: metadata,
                    stanzaId: stanzaId,
                    hasLocalFile: false,
                    downloadDelegate: downloadDelegate,
                    metadataReloadDelegate: widget.metadataReloadDelegate,
                    typeReport: declaredReport,
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
                hasLocalFile: false,
                downloadDelegate: downloadDelegate,
                metadataReloadDelegate: widget.metadataReloadDelegate,
                typeReport: declaredReport,
              );
            }
            if (metadata.isVideo) {
              return _VideoAttachment(
                metadata: metadata,
                stanzaId: stanzaId,
                hasLocalFile: false,
                downloadDelegate: downloadDelegate,
                metadataReloadDelegate: widget.metadataReloadDelegate,
                typeReport: declaredReport,
              );
            }
            return _FileAttachment(
              metadata: metadata,
              stanzaId: stanzaId,
              hasLocalFile: false,
              downloadDelegate: downloadDelegate,
              metadataReloadDelegate: widget.metadataReloadDelegate,
              typeReport: declaredReport,
            );
          },
        ),
      ),
    );
  }
}

class _BlockedAttachment extends StatelessWidget {
  const _BlockedAttachment({required this.metadata, this.onAllowPressed});

  final FileMetadataData metadata;
  final VoidCallback? onAllowPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    return _AttachmentSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.s,
        children: [
          Text(
            l10n.chatAttachmentBlockedTitle,
            style: context.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          _AttachmentFileNameText(
            filename: metadata.filename,
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
            child: AxiButton(
              variant: AxiButtonVariant.secondary,
              onPressed: onAllowPressed,
              child: Text(l10n.chatAttachmentLoad),
            ),
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
    required this.hasLocalFile,
    this.downloadDelegate,
    this.metadataReloadDelegate,
    this.typeReport,
  });

  final FileMetadataData metadata;
  final String stanzaId;
  final bool hasLocalFile;
  final AttachmentDownloadDelegate? downloadDelegate;
  final AttachmentMetadataReloadDelegate? metadataReloadDelegate;
  final FileTypeReport? typeReport;

  @override
  State<_ImageAttachment> createState() => _ImageAttachmentState();
}

class _ImageAttachmentState extends State<_ImageAttachment> {
  var _downloading = false;
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
    final path = metadata.path?.trim();
    final localFile =
        widget.hasLocalFile && path?.isNotEmpty == true ? File(path!) : null;
    final hasLocalFile = localFile != null;
    final canDownload = url != null || widget.downloadDelegate != null;
    if (!hasLocalFile && !canDownload) {
      return _AttachmentError(message: context.l10n.chatAttachmentUnavailable);
    }
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
    final previewFile = localFile;
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
              child: AxiProgressIndicator(color: colors.primary),
            ),
          );
        }
        final allowed = snapshot.data ?? false;
        if (!allowed) {
          return _FileAttachment(
            metadata: metadata,
            stanzaId: widget.stanzaId,
            hasLocalFile: hasLocalFile,
            downloadDelegate: widget.downloadDelegate,
            metadataReloadDelegate: widget.metadataReloadDelegate,
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
                  child: _AttachmentImageTapTarget(
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
            );
          },
        );
      },
    );
  }

  Future<bool> _resolvePreviewAllowed(File file, {required String metadataId}) {
    final path = file.path;
    final cachedFuture = _previewAllowed;
    if (cachedFuture != null && _previewPath == path) {
      return cachedFuture;
    }
    _previewPath = path;
    final nextFuture = _isImagePreviewAllowed(file, metadataId: metadataId);
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
      if (downloadDelegate == null) {
        if (showFeedback) {
          _showToast(
            l10n,
            toaster,
            l10n.chatAttachmentUnavailable,
            destructive: true,
          );
        }
        return;
      }
      final downloaded = await downloadDelegate.download();
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
    required this.hasLocalFile,
    this.downloadDelegate,
    this.metadataReloadDelegate,
    this.typeReport,
  });

  final FileMetadataData metadata;
  final String stanzaId;
  final bool hasLocalFile;
  final AttachmentDownloadDelegate? downloadDelegate;
  final AttachmentMetadataReloadDelegate? metadataReloadDelegate;
  final FileTypeReport? typeReport;

  @override
  State<_VideoAttachment> createState() => _VideoAttachmentState();
}

class _VideoAttachmentState extends State<_VideoAttachment> {
  var _downloading = false;
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
    final spacing = context.spacing;
    final url = metadata.sourceUrls == null || metadata.sourceUrls!.isEmpty
        ? null
        : metadata.sourceUrls!.first;
    final path = metadata.path?.trim();
    final localFile =
        widget.hasLocalFile && path?.isNotEmpty == true ? File(path!) : null;
    final hasLocalFile = localFile != null;
    final canDownload = url != null || widget.downloadDelegate != null;
    if (!hasLocalFile && !canDownload) {
      return _AttachmentError(message: context.l10n.chatAttachmentUnavailable);
    }
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
        hasLocalFile: hasLocalFile,
        downloadDelegate: widget.downloadDelegate,
        metadataReloadDelegate: widget.metadataReloadDelegate,
        typeReport: widget.typeReport,
      );
    }

    final resolvedLocalFile = localFile;
    final colors = context.colorScheme;
    final controller = _controller;
    final initialized = controller?.value.isInitialized == true;
    final playing = controller?.value.isPlaying == true;
    final aspectRatio = _videoAspectRatio(
      metadata: metadata,
      controller: controller,
    );
    final actionButtons = Positioned(
      top: spacing.s,
      right: spacing.s,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AxiIconButton.ghost(
            iconData: LucideIcons.save,
            onPressed: _downloading
                ? null
                : () async {
                    await _handleSaveAttachment(resolvedLocalFile);
                  },
          ),
          SizedBox(width: spacing.s),
          AxiIconButton.ghost(
            iconData: LucideIcons.share2,
            onPressed: _downloading
                ? null
                : () async {
                    await _handleShareAttachment(resolvedLocalFile);
                  },
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
                        child: AxiProgressIndicator(color: colors.primary),
                      ),
                    if (initialized && controller != null)
                      Center(
                        child: AxiIconButton.ghost(
                          iconData:
                              playing ? LucideIcons.pause : LucideIcons.play,
                          onPressed: _togglePlayback,
                        ),
                      ),
                    if (initialized) actionButtons,
                  ],
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
      if (downloadDelegate == null) {
        if (showFeedback) {
          _showToast(
            l10n,
            toaster,
            l10n.chatAttachmentUnavailable,
            destructive: true,
          );
        }
        return;
      }
      final downloaded = await downloadDelegate.download();
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

  Future<void> _handleSaveAttachment(File file) async {
    final l10n = context.l10n;
    final FileTypeReport report =
        widget.typeReport ?? widget.metadata.declaredTypeReport;
    final bool allowed = await confirmExportAllowed(
      context,
      metadata: widget.metadata,
      report: report,
      confirmLabel: l10n.chatAttachmentExportConfirm,
    );
    if (!mounted || !allowed) return;
    await saveAttachmentToDevice(
      context,
      file: file,
      filename: widget.metadata.filename,
    );
  }

  Future<void> _handleShareAttachment(File file) async {
    final l10n = context.l10n;
    final FileTypeReport report =
        widget.typeReport ?? widget.metadata.declaredTypeReport;
    final bool allowed = await confirmExportAllowed(
      context,
      metadata: widget.metadata,
      report: report,
      confirmLabel: l10n.chatActionShare,
    );
    if (!mounted || !allowed) return;
    await shareAttachmentFromFile(
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

  Future<void> _initializeVideoIfAvailable() async {
    _initFailed = false;
    final guardKey = _mediaDecodeGuardKey(widget.metadata.id);
    if (!MediaDecodeGuard.instance.allowAttempt(guardKey)) {
      _markVideoInitFailed();
      return;
    }
    final path = widget.metadata.path?.trim();
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!await file.exists()) return;
    if (!_isVideoMetadataAllowed(widget.metadata)) {
      _markVideoInitFailed();
      return;
    }
    final length = await _safeFileLength(file);
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
    try {
      await controller.initialize().timeout(_attachmentVideoInitTimeout);
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
    } on Exception {
      if (!mounted) return;
      _disposeVideoController(controller);
      MediaDecodeGuard.instance.registerFailure(guardKey);
      _markVideoInitFailed();
    }
  }

  Future<int?> _safeFileLength(File file) async {
    try {
      return await file.length();
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
    const fallbackAspectRatio = 16 / 9;
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
    return fallbackAspectRatio;
  }
}

double _resolveAttachmentWidth(
  BoxConstraints constraints,
  BuildContext context, {
  required double? intrinsicWidth,
}) {
  final scope = _AttachmentSurfaceScope.maybeOf(context);
  final sizing = context.sizing;
  final maxWidthFraction =
      scope?.maxWidthFraction ?? sizing.dialogMaxHeightFraction;
  final availableWidth = constraints.maxWidth.isFinite
      ? constraints.maxWidth
      : MediaQuery.sizeOf(context).width;
  final targetWidth = intrinsicWidth != null && intrinsicWidth > 0
      ? intrinsicWidth
      : math.min(sizing.dialogMaxWidth, availableWidth);
  return math.min(targetWidth, availableWidth * maxWidthFraction);
}

Future<void> _openImagePreview(
  BuildContext context, {
  required File file,
  required FileMetadataData metadata,
  FileTypeReport? typeReport,
}) async {
  if (!await file.exists()) return;
  if (!context.mounted) return;
  await showFadeScaleDialog<void>(
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

  _PreviewGhostColors _previewGhostColors(BuildContext context) {
    final colors = context.colorScheme;
    final isDark = context.brightness == Brightness.dark;
    return _PreviewGhostColors(
      background: isDark ? colors.background : colors.foreground,
      foreground: isDark ? colors.foreground : colors.background,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final spacing = context.spacing;
    final sizing = context.sizing;
    final ghostColors = _previewGhostColors(context);
    final double maxWidth = math.max(0.0, mediaSize.width - spacing.xl);
    final double maxHeight = math.max(0.0, mediaSize.height - spacing.xl);
    final fallbackWidth = math.min(maxWidth, sizing.dialogMaxWidth);
    final fallbackHeight =
        math.min(maxHeight, fallbackWidth * sizing.dialogMaxHeightFraction);
    final intrinsic = _intrinsicSizeFrom(metadata);
    final targetSize = _fitWithinBounds(
      intrinsicSize: intrinsic,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      fallbackWidth: fallbackWidth,
      fallbackHeight: fallbackHeight,
    );
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: targetSize.width,
            height: targetSize.height,
            child: InteractiveViewer(
              maxScale: sizing.mediaPreviewMaxScale,
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
          SizedBox(height: spacing.s),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AxiIconButton.ghost(
                iconData: LucideIcons.save,
                color: ghostColors.foreground,
                backgroundColor: ghostColors.background,
                onPressed: () async {
                  final FileTypeReport report =
                      typeReport ?? metadata.declaredTypeReport;
                  final bool allowed = await confirmExportAllowed(
                    context,
                    metadata: metadata,
                    report: report,
                    confirmLabel: l10n.chatAttachmentExportConfirm,
                  );
                  if (!context.mounted || !allowed) return;
                  await saveAttachmentToDevice(
                    context,
                    file: file,
                    filename: metadata.filename,
                  );
                },
              ),
              SizedBox(width: spacing.xs),
              AxiIconButton.ghost(
                iconData: LucideIcons.share2,
                color: ghostColors.foreground,
                backgroundColor: ghostColors.background,
                onPressed: () async {
                  final FileTypeReport report =
                      typeReport ?? metadata.declaredTypeReport;
                  final bool allowed = await confirmExportAllowed(
                    context,
                    metadata: metadata,
                    report: report,
                    confirmLabel: l10n.chatActionShare,
                  );
                  if (!context.mounted || !allowed) return;
                  await shareAttachmentFromFile(
                    context,
                    file: file,
                    filename: metadata.filename,
                  );
                },
              ),
              SizedBox(width: spacing.xs),
              AxiIconButton.ghost(
                iconData: LucideIcons.x,
                color: ghostColors.foreground,
                backgroundColor: ghostColors.background,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
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
  required double fallbackWidth,
  required double fallbackHeight,
}) {
  final cappedWidth = math.max(0.0, maxWidth);
  final cappedHeight = math.max(0.0, maxHeight);
  if (intrinsicSize == null ||
      intrinsicSize.width <= 0 ||
      intrinsicSize.height <= 0) {
    final width = math.min(cappedWidth, fallbackWidth);
    final height = math.min(cappedHeight, fallbackHeight);
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

class _PreviewGhostColors {
  const _PreviewGhostColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
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
    required this.hasLocalFile,
    this.downloadDelegate,
    this.metadataReloadDelegate,
    this.typeReport,
  });

  final FileMetadataData metadata;
  final String stanzaId;
  final bool hasLocalFile;
  final AttachmentDownloadDelegate? downloadDelegate;
  final AttachmentMetadataReloadDelegate? metadataReloadDelegate;
  final FileTypeReport? typeReport;

  @override
  State<_FileAttachment> createState() => _FileAttachmentState();
}

class _AttachmentDownloadCancelledException implements Exception {
  const _AttachmentDownloadCancelledException();
}

class _FileAttachmentState extends State<_FileAttachment> {
  var _downloading = false;
  late final ShadPopoverController _actionsController;

  @override
  void initState() {
    super.initState();
    _actionsController = ShadPopoverController();
  }

  @override
  void dispose() {
    _actionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final metadata = widget.metadata;
    final FileTypeReport report =
        widget.typeReport ?? metadata.declaredTypeReport;
    final url = metadata.sourceUrls == null || metadata.sourceUrls!.isEmpty
        ? null
        : metadata.sourceUrls!.first;
    final path = metadata.path?.trim();
    final localFile =
        widget.hasLocalFile && path?.isNotEmpty == true ? File(path!) : null;
    final hasLocalFile = localFile != null;
    final canDownload = url != null || widget.downloadDelegate != null;
    final bool shareEnabled = hasLocalFile || canDownload;
    final FileOpenRisk risk = assessFileOpenRisk(
      report: report,
      fileName: metadata.filename,
    );
    final showWarningOpen = hasLocalFile && risk.isWarning;
    final IconData openIconData = showWarningOpen
        ? Icons.warning_amber_outlined
        : LucideIcons.externalLink;
    final String downloadAndOpenTooltip = l10n.chatAttachmentDownloadAndOpen;
    final String downloadAndSaveTooltip = l10n.chatAttachmentDownloadAndSave;
    final String downloadAndShareTooltip = l10n.chatAttachmentDownloadAndShare;
    final String openTooltip = showWarningOpen
        ? l10n.chatAttachmentTypeMismatchConfirm
        : hasLocalFile
            ? l10n.chatAttachmentView
            : downloadAndOpenTooltip;
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
    final border = context.borderSide;
    final Widget attachmentIcon = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.muted,
        shape: SquircleBorder(
          cornerRadius: context.radii.squircle,
          side: border,
        ),
      ),
      child: SizedBox.square(
        dimension: sizing.iconButtonTapTarget,
        child: Icon(
          LucideIcons.paperclip,
          size: sizing.iconButtonIconSize,
        ),
      ),
    );
    final sizeLabel = _formatAttachmentSize(
      bytes: metadata.sizeBytes,
      hasLocalFile: hasLocalFile,
      l10n: l10n,
    );
    final fileNameStyle =
        context.textTheme.small.copyWith(fontWeight: FontWeight.w600);
    final actionSpacing = spacing.s;
    const actionButtonCount = 3;
    final actionRowMinWidth = (sizing.iconButtonTapTarget * actionButtonCount) +
        (actionSpacing * (actionButtonCount - 1));
    final Widget attachmentActions = _downloading
        ? SizedBox.square(
            dimension: sizing.iconButtonTapTarget,
            child: Center(
              child: AxiProgressIndicator(color: colors.primary),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AxiIconButton(
                iconData: LucideIcons.save,
                tooltip: downloadAndSaveTooltip,
                onPressed: hasLocalFile || canDownload ? _saveAttachment : null,
              ),
              SizedBox(width: actionSpacing),
              AxiIconButton(
                iconData: LucideIcons.share2,
                tooltip: downloadAndShareTooltip,
                onPressed: shareEnabled ? _shareAttachment : null,
              ),
              SizedBox(width: actionSpacing),
              AxiIconButton(
                iconData: openIconData,
                tooltip: openTooltip,
                color: openColor,
                onPressed: openAction,
              ),
            ],
          );
    return _AttachmentSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final detailsWidth = availableWidth -
              sizing.iconButtonTapTarget -
              (spacing.m) -
              actionRowMinWidth;
          final shouldMeasureText = availableWidth.isFinite && detailsWidth > 0;
          final TextPainter painter = TextPainter(
            text: TextSpan(text: metadata.filename, style: fileNameStyle),
            maxLines: 1,
            textDirection: Directionality.of(context),
            ellipsis: '…',
          );
          final bool stackActions = !shouldMeasureText ||
              detailsWidth <= 0 ||
              (painter..layout(maxWidth: detailsWidth)).didExceedMaxLines;
          final int filenameMaxLines = stackActions ? 2 : 1;
          final Widget actionRow = stackActions
              ? _downloading
                  ? attachmentActions
                  : AxiPopover(
                      controller: _actionsController,
                      closeOnTapOutside: true,
                      padding: EdgeInsets.zero,
                      decoration: ShadDecoration.none,
                      shadows: const <BoxShadow>[],
                      popover: (context) {
                        return AxiMenu(
                          actions: [
                            AxiMenuAction(
                              icon: LucideIcons.save,
                              label: downloadAndSaveTooltip,
                              onPressed: () {
                                _actionsController.hide();
                                _saveAttachment();
                              },
                              enabled: hasLocalFile || canDownload,
                            ),
                            AxiMenuAction(
                              icon: LucideIcons.share2,
                              label: downloadAndShareTooltip,
                              onPressed: () {
                                _actionsController.hide();
                                _shareAttachment();
                              },
                              enabled: shareEnabled,
                            ),
                            AxiMenuAction(
                              icon: openIconData,
                              label: openTooltip,
                              onPressed: openAction == null
                                  ? null
                                  : () {
                                      _actionsController.hide();
                                      openAction();
                                    },
                              enabled: openAction != null,
                            ),
                          ],
                        );
                      },
                      child: AxiTooltip(
                        builder: (_) => Text(l10n.commonMoreOptions),
                        child: AxiIconButton(
                          iconData: Icons.more_horiz,
                          onPressed: _actionsController.toggle,
                        ),
                      ),
                    )
              : attachmentActions;
          final Widget attachmentDetails = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.xs,
            children: [
              _AttachmentFileNameText(
                filename: metadata.filename,
                style: fileNameStyle,
                maxLines: filenameMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                sizeLabel,
                style: context.textTheme.small.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            ],
          );
          if (stackActions) {
            return Row(
              children: [
                attachmentIcon,
                SizedBox(width: spacing.s),
                Expanded(child: attachmentDetails),
                SizedBox(width: spacing.s),
                actionRow,
              ],
            );
          }
          return Row(
            children: [
              attachmentIcon,
              SizedBox(width: spacing.s),
              Expanded(child: attachmentDetails),
              SizedBox(width: spacing.s),
              ConstrainedBox(
                constraints: BoxConstraints(minWidth: actionRowMinWidth),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: actionRow,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveAttachment() async {
    if (_downloading) return;
    final l10n = context.l10n;
    final FileTypeReport report =
        widget.typeReport ?? widget.metadata.declaredTypeReport;
    final bool allowed = await confirmExportAllowed(
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
      await saveAttachmentToDevice(
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
    final bool allowed = await confirmExportAllowed(
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
      await shareAttachmentFromFile(
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

  Future<String?> _downloadAndResolvePath() async {
    final downloadDelegate = widget.downloadDelegate;
    final reloadDelegate = widget.metadataReloadDelegate;
    if (downloadDelegate == null || reloadDelegate == null) return null;
    final downloaded = await downloadDelegate.download();
    if (!downloaded) return null;
    final refreshed = await reloadDelegate.reload();
    final refreshedPath = refreshed?.path?.trim();
    if (refreshedPath == null || refreshedPath.isEmpty) return null;
    final refreshedFile = File(refreshedPath);
    return await refreshedFile.exists() ? refreshedFile.path : null;
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
    if (await existingFile?.exists() ?? false) return existingFile!.path;
    return _resolveLocalPathAfterConfirmation(
      requireConfirmation: requireConfirmation,
      typeReport: typeReport,
    );
  }

  Future<String?> _resolveLocalPathAfterConfirmation({
    required bool requireConfirmation,
    FileTypeReport? typeReport,
  }) async {
    final allowed = await _confirmDownloadAllowed(
      context,
      metadata: widget.metadata,
      report: typeReport,
      requireConfirmation: requireConfirmation,
    );
    if (!allowed || !mounted) {
      throw const _AttachmentDownloadCancelledException();
    }
    return _downloadAndResolvePath();
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
    final spacing = context.spacing;
    final sizing = context.sizing;
    final openLabel = l10n.commonOpen;
    final openTooltip = l10n.chatAttachmentDownloadAndOpen;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final width = availableWidth * sizing.dialogMaxHeightFraction;
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
                spacing: spacing.m,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.lock,
                        size: sizing.iconButtonIconSize,
                        color: colors.mutedForeground,
                      ),
                      SizedBox(width: spacing.s),
                      Expanded(
                        child: _AttachmentFileNameText(
                          filename: filename,
                          style: context.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AxiTooltip(
                      builder: (_) => Text(openTooltip),
                      child: AxiButton(
                        variant: AxiButtonVariant.secondary,
                        loading: downloading,
                        onPressed: onPressed,
                        child: Text(
                          downloading ? l10n.chatAttachmentLoading : openLabel,
                        ),
                      ),
                    ),
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
    final spacing = context.spacing;
    final sizing = context.sizing;
    final openLabel = l10n.commonOpen;
    final openTooltip = l10n.chatAttachmentDownloadAndOpen;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final width = availableWidth * sizing.dialogMaxHeightFraction;
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
                spacing: spacing.m,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.image,
                        size: sizing.iconButtonIconSize,
                        color: colors.mutedForeground,
                      ),
                      SizedBox(width: spacing.s),
                      Expanded(
                        child: _AttachmentFileNameText(
                          filename: filename,
                          style: context.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AxiTooltip(
                      builder: (_) => Text(openTooltip),
                      child: AxiButton(
                        variant: AxiButtonVariant.secondary,
                        loading: downloading,
                        onPressed: onPressed,
                        child: Text(
                          downloading ? l10n.chatAttachmentLoading : openLabel,
                        ),
                      ),
                    ),
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
    final spacing = context.spacing;
    final sizing = context.sizing;
    final openLabel = l10n.commonOpen;
    final openTooltip = l10n.chatAttachmentDownloadAndOpen;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final width = availableWidth * sizing.dialogMaxHeightFraction;
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
                spacing: spacing.m,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.video,
                        size: sizing.iconButtonIconSize,
                        color: colors.mutedForeground,
                      ),
                      SizedBox(width: spacing.s),
                      Expanded(
                        child: _AttachmentFileNameText(
                          filename: filename,
                          style: context.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AxiTooltip(
                      builder: (_) => Text(openTooltip),
                      child: AxiButton(
                        variant: AxiButtonVariant.secondary,
                        loading: downloading,
                        onPressed: onPressed,
                        child: Text(
                          downloading ? l10n.chatAttachmentLoading : openLabel,
                        ),
                      ),
                    ),
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

class _AttachmentSurfaceScope extends InheritedWidget {
  const _AttachmentSurfaceScope({
    required this.shape,
    required this.maxWidthFraction,
    required super.child,
  });

  final OutlinedBorder shape;
  final double maxWidthFraction;

  static _AttachmentSurfaceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AttachmentSurfaceScope>();

  @override
  bool updateShouldNotify(_AttachmentSurfaceScope oldWidget) =>
      shape != oldWidget.shape ||
      maxWidthFraction != oldWidget.maxWidthFraction;
}

class _AttachmentSurface extends StatelessWidget {
  const _AttachmentSurface({
    required this.child,
    this.padding,
    this.backgroundColor,
    this.borderSide,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final BorderSide? borderSide;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final resolvedBackground = backgroundColor ?? colors.card;
    final resolvedBorder = borderSide ?? context.borderSide;
    final borderWidth = resolvedBorder.width;
    final scope = _AttachmentSurfaceScope.maybeOf(context);
    final OutlinedBorder baseShape = scope?.shape ??
        ContinuousRectangleBorder(
          borderRadius: context.radius,
        );
    final OutlinedBorder resolvedShape = baseShape.copyWith(
      side: resolvedBorder,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: resolvedBackground,
        shape: resolvedShape,
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: baseShape),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: (padding ?? EdgeInsets.all(spacing.m))
              .add(EdgeInsets.all(borderWidth)),
          child: child,
        ),
      ),
    );
  }
}

class _AttachmentImageTapTarget extends StatefulWidget {
  const _AttachmentImageTapTarget({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_AttachmentImageTapTarget> createState() =>
      _AttachmentImageTapTargetState();
}

class _AttachmentImageTapTargetState extends State<_AttachmentImageTapTarget> {
  final AxiTapBounceController _bounceController = AxiTapBounceController();

  @override
  Widget build(BuildContext context) {
    return ShadFocusable(
      canRequestFocus: true,
      builder: (context, focused, child) => child ?? const SizedBox.shrink(),
      child: ShadGestureDetector(
        cursor: SystemMouseCursors.click,
        hoverStrategies: mobileHoverStrategies,
        onTap: widget.onTap,
        onTapDown: _bounceController.handleTapDown,
        onTapUp: _bounceController.handleTapUp,
        onTapCancel: _bounceController.handleTapCancel,
        child: AxiTapBounce(
          controller: _bounceController,
          child: widget.child,
        ),
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
    final spacing = context.spacing;
    final sizing = context.sizing;
    return _AttachmentSurface(
      child: Row(
        children: [
          Icon(Icons.error_outline, size: sizing.iconButtonIconSize),
          SizedBox(width: spacing.s),
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
  final report = assessLinkSafety(raw: rawUrl, kind: LinkSafetyKind.attachment);
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
      ? l10n.chatOpenLinkWarningMessage(report.displayUri, hostLabel)
      : l10n.chatOpenLinkMessage(report.displayUri, hostLabel);
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
    await Clipboard.setData(ClipboardData(text: report.displayUri));
    return;
  }
  final launched = await launchUrl(
    report.uri,
    mode: LaunchMode.externalApplication,
  );
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

Future<void> shareAttachmentFromFile(
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
    await saveAttachmentToDevice(
      context,
      file: file,
      filename: filename,
      skipConfirm: true,
    );
    return;
  }
  File? sharedFile;
  try {
    sharedFile = await _prepareShareAttachmentFile(
      file: file,
      filename: filename,
      fallbackName: l10n.chatAttachmentFallbackLabel,
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
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(sharedFile.path)],
      ),
    );
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
  } finally {
    if (sharedFile != null) {
      _scheduleShareCleanup(sharedFile);
    }
  }
}

Future<void> saveAttachmentToDevice(
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
  final fallbackName = _resolveAttachmentFallbackName(
    fallbackPath: file.path,
    fallbackName: l10n.chatAttachmentFallbackLabel,
  );
  final resolvedName = sanitizeAttachmentFileName(
    rawName: filename,
    fallbackName: fallbackName,
    maxLength: _attachmentSaveNameMaxLength,
  );
  final savePath = await FilePicker.platform.saveFile(fileName: resolvedName);
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
  required String fallbackName,
}) async {
  if (!await file.exists()) {
    return null;
  }
  final entityType = await FileSystemEntity.type(file.path, followLinks: false);
  if (entityType != FileSystemEntityType.file) {
    return null;
  }
  final shareDir = await _createAttachmentShareDir();
  final shareFileName = _sanitizeShareFileName(
    explicitName: filename,
    fallbackPath: file.path,
    fallbackName: fallbackName,
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
  required String fallbackName,
}) {
  final resolvedFallbackName = _resolveAttachmentFallbackName(
    fallbackPath: fallbackPath,
    fallbackName: fallbackName,
  );
  return sanitizeAttachmentFileName(
    rawName: explicitName,
    fallbackName: resolvedFallbackName,
    maxLength: _attachmentShareNameMaxLength,
  );
}

String _resolveAttachmentFallbackName({
  required String fallbackPath,
  required String fallbackName,
}) {
  final trimmedPath = fallbackPath.trim();
  if (trimmedPath.isNotEmpty) {
    return trimmedPath;
  }
  return fallbackName;
}

void _scheduleShareCleanup(File sharedFile) {
  final String parentName = p.basename(sharedFile.parent.path);
  if (!parentName.startsWith(_attachmentShareDirPrefix)) {
    return;
  }
  final Directory shareDir = sharedFile.parent;
  Timer(
    _attachmentShareCleanupDelay,
    () async {
      try {
        if (await shareDir.exists()) {
          await shareDir.delete(recursive: true);
        }
      } on Exception {
        return;
      }
    },
  );
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
    final value = _macOsQuarantineValue();
    await Process.run(_attachmentMacOsQuarantineCommand, [
      _attachmentMacOsQuarantineWriteArg,
      _attachmentMacOsQuarantineAttribute,
      value,
      destination.path,
    ]);
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

String _macOsQuarantineValue() {
  final timestampSeconds =
      DateTime.now().millisecondsSinceEpoch ~/ _attachmentMillisecondsPerSecond;
  final timestampHex = timestampSeconds.toRadixString(
    _attachmentMacOsQuarantineRadix,
  );
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
      ? FeedbackToast.error(title: l10n.toastWhoopsTitle, message: message)
      : FeedbackToast.info(title: l10n.toastHeadsUpTitle, message: message);
  toaster?.show(toast);
}

String _formatAttachmentSize({
  required int? bytes,
  required bool hasLocalFile,
  required AppLocalizations l10n,
}) {
  if (bytes == null || bytes <= 0) {
    return hasLocalFile
        ? l10n.chatAttachmentUnknownSize
        : l10n.chatAttachmentNotDownloadedYet;
  }
  return _formatSize(bytes, l10n);
}

String _formatSize(int? bytes, AppLocalizations l10n) {
  if (bytes == null || bytes <= 0) return l10n.chatAttachmentUnknownSize;
  final units = [
    l10n.commonFileSizeUnitBytes,
    l10n.commonFileSizeUnitKilobytes,
    l10n.commonFileSizeUnitMegabytes,
    l10n.commonFileSizeUnitGigabytes,
    l10n.commonFileSizeUnitTerabytes,
  ];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}

String _attachmentTooLargeMessage(AppLocalizations l10n, int? maxBytes) {
  final resolvedLimit =
      maxBytes == null || maxBytes <= 0 ? null : _formatSize(maxBytes, l10n);
  if (resolvedLimit == null) {
    return l10n.chatAttachmentTooLargeMessageDefault;
  }
  return l10n.chatAttachmentTooLargeMessage(resolvedLimit);
}
