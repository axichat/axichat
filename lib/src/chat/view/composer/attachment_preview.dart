// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:axichat/src/attachments/view/attachment_file_preview.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/file_name_safety.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/media_decode_safety.dart';
import 'package:axichat/src/common/unicode_safety.dart';
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
const String _attachmentShareDirName = attachmentShareTempDirectoryName;
const String _attachmentShareDirPrefix = 'share_';
const int _attachmentShareNameMaxLength = 120;
const int _attachmentSaveNameMaxLength = _attachmentShareNameMaxLength;
const Duration _attachmentShareCleanupAge = Duration(days: 1);
const Duration _attachmentShareCleanupDelay = Duration(minutes: 10);
const bool _attachmentShareCleanupFollowLinks = false;
const double _attachmentImagePreviewMaxDevicePixelRatio = 2;
const int _attachmentImagePreviewMaxCacheDimension = 1280;
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

void openSingleAttachmentComposeDraft({
  required BuildContext context,
  required FileMetadataData metadata,
}) {
  final metadataId = metadata.id.trim();
  if (metadataId.isEmpty || !context.mounted) return;
  openComposeDraft(
    context,
    jids: const [''],
    forwardedSourceAttachmentMetadataIds: [metadataId],
  );
}

List<AttachmentPreviewDialogAction> localAttachmentPreviewDialogActions({
  required BuildContext ownerContext,
  required File file,
  required FileMetadataData metadata,
  required FileTypeReport report,
  required AppLocalizations l10n,
  bool closeBeforeSend = true,
  bool enabled = true,
}) {
  return [
    AttachmentPreviewDialogAction(
      iconData: LucideIcons.save,
      tooltip: l10n.chatAttachmentExportConfirm,
      enabled: enabled,
      onPressed: (context) async {
        final allowed = await confirmExportAllowed(
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
    AttachmentPreviewDialogAction(
      iconData: LucideIcons.share2,
      tooltip: l10n.chatActionShare,
      enabled: enabled,
      onPressed: (context) async {
        final allowed = await confirmExportAllowed(
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
    AttachmentPreviewDialogAction(
      iconData: LucideIcons.send,
      tooltip: l10n.commonSend,
      enabled: enabled,
      onPressed: (context) {
        if (closeBeforeSend) {
          Navigator.of(context).pop();
        }
        if (!ownerContext.mounted) return;
        openSingleAttachmentComposeDraft(
          context: ownerContext,
          metadata: metadata,
        );
      },
    ),
  ];
}

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
const int _attachmentImagePreviewValidationCacheMaxEntries = 256;
const int _acknowledgedHighRiskAttachmentMaxEntries = 256;
final LinkedHashSet<String> _acknowledgedHighRiskAttachmentIds =
    LinkedHashSet<String>();
final LinkedHashSet<Object> _allowedImagePreviewValidationKeys =
    LinkedHashSet<Object>();

enum _FileAttachmentAction { save, share, preview }

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
}) async {
  final declaredLabel = report.declaredLabel;
  final detectedLabel = report.detectedLabel;
  final hasMismatchWarning =
      report.hasMismatch && declaredLabel != null && detectedLabel != null;
  if (hasMismatchWarning) {
    final l10n = context.l10n;
    final approved = await confirm(
      context,
      title: l10n.chatAttachmentTypeMismatchTitle,
      message: l10n.chatAttachmentTypeMismatchMessage(
        declaredLabel,
        detectedLabel,
      ),
      confirmLabel: confirmLabel,
      destructiveConfirm: true,
    );
    if (approved != true || !context.mounted) {
      return false;
    }
  }
  if (!context.mounted) {
    return false;
  }
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
    required this.metadata,
    this.metadataPending = false,
    required this.allowed,
    this.downloadDelegate,
    this.metadataReloadDelegate,
    this.onAllowPressed,
    this.surfaceShape,
    this.maxWidthFraction,
    this.messageDetails = const <InlineSpan>[],
    this.detailOpticalOffsetFactors = const <int, double>{},
  });

  final String stanzaId;
  final FileMetadataData? metadata;
  final bool metadataPending;
  final bool allowed;
  final AttachmentDownloadDelegate? downloadDelegate;
  final AttachmentMetadataReloadDelegate? metadataReloadDelegate;
  final VoidCallback? onAllowPressed;
  final OutlinedBorder? surfaceShape;
  final double? maxWidthFraction;
  final List<InlineSpan> messageDetails;
  final Map<int, double> detailOpticalOffsetFactors;

  @override
  State<ChatAttachmentPreview> createState() => _ChatAttachmentPreviewState();
}

class _ChatAttachmentPreviewState extends State<ChatAttachmentPreview> {
  static final Map<String, bool> _fileExistsCacheByPath = <String, bool>{};
  static final Map<int, FileTypeReport> _typeReportCacheByKey =
      <int, FileTypeReport>{};

  Future<FileTypeReport>? _typeReportFuture;
  int? _typeReportKey;
  FileTypeReport? _resolvedTypeReport;
  int? _resolvedTypeReportKey;
  Future<bool>? _fileExistsFuture;
  int? _fileExistsKey;
  bool? _resolvedFileExists;
  int? _resolvedFileExistsKey;

  int _typeReportCacheKey({
    required FileMetadataData metadata,
    required File file,
  }) {
    return Object.hash(
      metadata.id,
      file.path,
      metadata.mimeType,
      metadata.filename,
      metadata.sizeBytes,
    );
  }

  Future<FileTypeReport> _resolveTypeReportFuture({
    required FileMetadataData metadata,
    required File file,
  }) {
    final nextKey = _typeReportCacheKey(metadata: metadata, file: file);
    final cachedReport = _typeReportCacheByKey[nextKey];
    if (cachedReport != null) {
      _resolvedTypeReport = cachedReport;
      _resolvedTypeReportKey = nextKey;
      return SynchronousFuture<FileTypeReport>(cachedReport);
    }
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
    unawaited(
      nextFuture.then<void>((report) {
        if (_typeReportKey != nextKey) return;
        _typeReportCacheByKey[nextKey] = report;
        _resolvedTypeReport = report;
        _resolvedTypeReportKey = nextKey;
      }, onError: (Object error, StackTrace stackTrace) {}),
    );
    return nextFuture;
  }

  void _clearTypeReportCache() {
    _typeReportFuture = null;
    _typeReportKey = null;
    _resolvedTypeReport = null;
    _resolvedTypeReportKey = null;
  }

  Future<bool> _resolveFileExistsFuture(File file) {
    final path = file.path;
    final cachedExists = _fileExistsCacheByPath[path];
    if (cachedExists != null) {
      final nextKey = path.hashCode;
      _resolvedFileExists = cachedExists;
      _resolvedFileExistsKey = nextKey;
      return SynchronousFuture<bool>(cachedExists);
    }
    final nextKey = path.hashCode;
    final cachedFuture = _fileExistsFuture;
    if (cachedFuture != null && _fileExistsKey == nextKey) {
      return cachedFuture;
    }
    _fileExistsKey = nextKey;
    final nextFuture = file.exists();
    _fileExistsFuture = nextFuture;
    unawaited(
      nextFuture.then<void>((exists) {
        if (_fileExistsKey != nextKey) return;
        if (exists) {
          _fileExistsCacheByPath[path] = true;
        } else {
          _fileExistsCacheByPath.remove(path);
        }
        _resolvedFileExists = exists;
        _resolvedFileExistsKey = nextKey;
        if (!exists) {
          _clearTypeReportCache();
        }
      }, onError: (Object error, StackTrace stackTrace) {}),
    );
    return nextFuture;
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final OutlinedBorder resolvedShape =
        widget.surfaceShape ??
        ContinuousRectangleBorder(borderRadius: context.radius);
    final maxWidthFraction =
        widget.maxWidthFraction ?? sizing.dialogMaxHeightFraction;
    return RepaintBoundary(
      child: _AttachmentSurfaceScope(
        shape: resolvedShape,
        maxWidthFraction: maxWidthFraction,
        child: Builder(
          builder: (context) {
            final l10n = context.l10n;
            final colors = context.colorScheme;
            final stanzaId = widget.stanzaId;
            final onAllowPressed = widget.onAllowPressed;
            final downloadDelegate = widget.downloadDelegate;
            final allowed = widget.allowed;
            final metadata = widget.metadata;
            if (metadata == null) {
              if (widget.metadataPending) {
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
              final fileExistsKey = localFile.path.hashCode;
              final cachedHasLocalFile = _resolvedFileExistsKey == fileExistsKey
                  ? _resolvedFileExists
                  : _fileExistsCacheByPath[localFile.path];
              final existsFuture = _resolveFileExistsFuture(localFile);
              return FutureBuilder<bool>(
                future: existsFuture,
                initialData: cachedHasLocalFile ?? true,
                builder: (context, existsSnapshot) {
                  final hasLocalFile = existsSnapshot.data ?? true;
                  if (hasLocalFile != true) {
                    _clearTypeReportCache();
                  }
                  if (hasLocalFile == true) {
                    final typeReportKey = _typeReportCacheKey(
                      metadata: metadata,
                      file: localFile,
                    );
                    final cachedTypeReport =
                        _resolvedTypeReportKey == typeReportKey
                        ? _resolvedTypeReport
                        : _typeReportCacheByKey[typeReportKey];
                    final typeReportFuture = _resolveTypeReportFuture(
                      metadata: metadata,
                      file: localFile,
                    );
                    return FutureBuilder<FileTypeReport>(
                      future: typeReportFuture,
                      initialData: cachedTypeReport ?? declaredReport,
                      builder: (context, typeSnapshot) {
                        final FileTypeReport resolvedReport =
                            typeSnapshot.data ?? declaredReport;
                        final bool useDeclaredFallback =
                            !resolvedReport.hasReliableDetection;
                        final bool isImage =
                            resolvedReport.isDetectedImage ||
                            (useDeclaredFallback &&
                                resolvedReport.isDeclaredImage);
                        final bool isVideo =
                            resolvedReport.isDetectedVideo ||
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
                            messageDetails: widget.messageDetails,
                            detailOpticalOffsetFactors:
                                widget.detailOpticalOffsetFactors,
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
                            messageDetails: widget.messageDetails,
                            detailOpticalOffsetFactors:
                                widget.detailOpticalOffsetFactors,
                          );
                        }
                        return _FileAttachment(
                          metadata: metadata,
                          stanzaId: stanzaId,
                          hasLocalFile: true,
                          downloadDelegate: downloadDelegate,
                          metadataReloadDelegate: widget.metadataReloadDelegate,
                          typeReport: resolvedReport,
                          messageDetails: widget.messageDetails,
                          detailOpticalOffsetFactors:
                              widget.detailOpticalOffsetFactors,
                        );
                      },
                    );
                  }
                  if (!allowed) {
                    return _BlockedAttachment(
                      metadata: metadata,
                      onAllowPressed: onAllowPressed,
                      messageDetails: widget.messageDetails,
                      detailOpticalOffsetFactors:
                          widget.detailOpticalOffsetFactors,
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
                      messageDetails: widget.messageDetails,
                      detailOpticalOffsetFactors:
                          widget.detailOpticalOffsetFactors,
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
                      messageDetails: widget.messageDetails,
                      detailOpticalOffsetFactors:
                          widget.detailOpticalOffsetFactors,
                    );
                  }
                  return _FileAttachment(
                    metadata: metadata,
                    stanzaId: stanzaId,
                    hasLocalFile: false,
                    downloadDelegate: downloadDelegate,
                    metadataReloadDelegate: widget.metadataReloadDelegate,
                    typeReport: declaredReport,
                    messageDetails: widget.messageDetails,
                    detailOpticalOffsetFactors:
                        widget.detailOpticalOffsetFactors,
                  );
                },
              );
            }
            if (!allowed) {
              return _BlockedAttachment(
                metadata: metadata,
                onAllowPressed: onAllowPressed,
                messageDetails: widget.messageDetails,
                detailOpticalOffsetFactors: widget.detailOpticalOffsetFactors,
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
                messageDetails: widget.messageDetails,
                detailOpticalOffsetFactors: widget.detailOpticalOffsetFactors,
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
                messageDetails: widget.messageDetails,
                detailOpticalOffsetFactors: widget.detailOpticalOffsetFactors,
              );
            }
            return _FileAttachment(
              metadata: metadata,
              stanzaId: stanzaId,
              hasLocalFile: false,
              downloadDelegate: downloadDelegate,
              metadataReloadDelegate: widget.metadataReloadDelegate,
              typeReport: declaredReport,
              messageDetails: widget.messageDetails,
              detailOpticalOffsetFactors: widget.detailOpticalOffsetFactors,
            );
          },
        ),
      ),
    );
  }
}

class _BlockedAttachment extends StatelessWidget {
  const _BlockedAttachment({
    required this.metadata,
    required this.messageDetails,
    required this.detailOpticalOffsetFactors,
    this.onAllowPressed,
  });

  final FileMetadataData metadata;
  final List<InlineSpan> messageDetails;
  final Map<int, double> detailOpticalOffsetFactors;
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
          if (messageDetails.isNotEmpty)
            _AttachmentTimelineDetails(
              details: messageDetails,
              detailOpticalOffsetFactors: detailOpticalOffsetFactors,
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: AxiButton(
                    variant: AxiButtonVariant.secondary,
                    constrainChild: true,
                    onPressed: onAllowPressed,
                    child: Text(
                      l10n.chatAttachmentLoad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            },
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
    required this.messageDetails,
    required this.detailOpticalOffsetFactors,
  });

  final FileMetadataData metadata;
  final String stanzaId;
  final bool hasLocalFile;
  final AttachmentDownloadDelegate? downloadDelegate;
  final AttachmentMetadataReloadDelegate? metadataReloadDelegate;
  final FileTypeReport? typeReport;
  final List<InlineSpan> messageDetails;
  final Map<int, double> detailOpticalOffsetFactors;

  @override
  State<_ImageAttachment> createState() => _ImageAttachmentState();
}

class _ImageAttachmentState extends State<_ImageAttachment> {
  var _downloading = false;
  Future<bool>? _previewAllowed;
  Object? _previewValidationRequestKey;

  bool get _encrypted =>
      widget.metadata.encryptionScheme?.trim().isNotEmpty == true;

  @override
  void didUpdateWidget(covariant _ImageAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPath = oldWidget.metadata.path?.trim();
    final nextPath = widget.metadata.path?.trim();
    if (oldPath != nextPath) {
      _previewAllowed = null;
      _previewValidationRequestKey = null;
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
    final localFile = widget.hasLocalFile && path?.isNotEmpty == true
        ? File(path!)
        : null;
    final hasLocalFile = localFile != null;
    final canDownload = url != null || widget.downloadDelegate != null;
    if (!hasLocalFile && !canDownload) {
      return _AttachmentError(message: context.l10n.chatAttachmentUnavailable);
    }
    if (!hasLocalFile) {
      if (_encrypted) {
        return _EncryptedAttachment(
          metadata: metadata,
          downloading: _downloading,
          messageDetails: widget.messageDetails,
          detailOpticalOffsetFactors: widget.detailOpticalOffsetFactors,
          onPressed: _downloading
              ? null
              : () => _downloadAttachment(
                  showFeedback: true,
                  requireConfirmation: true,
                ),
        );
      }
      return _RemoteImageAttachment(
        metadata: metadata,
        downloading: _downloading,
        messageDetails: widget.messageDetails,
        detailOpticalOffsetFactors: widget.detailOpticalOffsetFactors,
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
      metadata: metadata,
    );
    return FutureBuilder<bool>(
      future: previewAllowedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _AttachmentSurface(
            child: Center(child: AxiProgressIndicator(color: colors.primary)),
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
            messageDetails: widget.messageDetails,
            detailOpticalOffsetFactors: widget.detailOpticalOffsetFactors,
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final targetWidth = _resolveAttachmentWidth(
              constraints,
              context,
              intrinsicWidth: widget.metadata.width?.toDouble(),
              minimumWidth: _attachmentMetadataOverlayMinWidth(context),
            );
            final aspectRatio = _aspectRatio(metadata);
            final cacheDimensions = _attachmentImageCacheDimensions(
              targetWidth: targetWidth,
              aspectRatio: aspectRatio,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
              intrinsicWidth: metadata.width,
              intrinsicHeight: metadata.height,
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
                        Image.file(
                          previewFile,
                          fit: BoxFit.cover,
                          cacheWidth: cacheDimensions?.width,
                          cacheHeight: cacheDimensions?.height,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                        _AttachmentMetadataVignette(
                          metadata: metadata,
                          hasLocalFile: hasLocalFile,
                          details: widget.messageDetails,
                          detailOpticalOffsetFactors:
                              widget.detailOpticalOffsetFactors,
                          trailing: AxiIconButton.ghost(
                            iconData: LucideIcons.eye,
                            tooltip: context.l10n.chatAttachmentPreview,
                            onPressed: () => _openImagePreview(
                              context,
                              file: previewFile,
                              metadata: metadata,
                              typeReport: widget.typeReport,
                              messageDetails: widget.messageDetails,
                              detailOpticalOffsetFactors:
                                  widget.detailOpticalOffsetFactors,
                            ),
                          ),
                        ),
                      ],
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
    required FileMetadataData metadata,
  }) {
    final requestKey = _imagePreviewValidationRequestKey(
      file: file,
      metadata: metadata,
    );
    final cachedFuture = _previewAllowed;
    if (cachedFuture != null && _previewValidationRequestKey == requestKey) {
      return cachedFuture;
    }
    _previewValidationRequestKey = requestKey;
    final nextFuture = _isImagePreviewAllowed(file, metadata: metadata);
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
    required this.messageDetails,
    required this.detailOpticalOffsetFactors,
  });

  final FileMetadataData metadata;
  final String stanzaId;
  final bool hasLocalFile;
  final AttachmentDownloadDelegate? downloadDelegate;
  final AttachmentMetadataReloadDelegate? metadataReloadDelegate;
  final FileTypeReport? typeReport;
  final List<InlineSpan> messageDetails;
  final Map<int, double> detailOpticalOffsetFactors;

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
    final localFile = widget.hasLocalFile && path?.isNotEmpty == true
        ? File(path!)
        : null;
    final hasLocalFile = localFile != null;
    final canDownload = url != null || widget.downloadDelegate != null;
    if (!hasLocalFile && !canDownload) {
      return _AttachmentError(message: context.l10n.chatAttachmentUnavailable);
    }
    if (!hasLocalFile) {
      if (_encrypted) {
        return _EncryptedAttachment(
          metadata: metadata,
          downloading: _downloading,
          messageDetails: widget.messageDetails,
          detailOpticalOffsetFactors: widget.detailOpticalOffsetFactors,
          onPressed: _downloading
              ? null
              : () => _downloadAttachment(
                  showFeedback: true,
                  requireConfirmation: true,
                ),
        );
      }
      return _RemoteVideoAttachment(
        metadata: metadata,
        downloading: _downloading,
        messageDetails: widget.messageDetails,
        detailOpticalOffsetFactors: widget.detailOpticalOffsetFactors,
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
        messageDetails: widget.messageDetails,
        detailOpticalOffsetFactors: widget.detailOpticalOffsetFactors,
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
    final actions = localAttachmentPreviewDialogActions(
      ownerContext: context,
      file: localFile,
      metadata: metadata,
      report: widget.typeReport ?? metadata.declaredTypeReport,
      l10n: context.l10n,
      closeBeforeSend: false,
      enabled: !_downloading,
    );
    final actionButtons = Positioned(
      top: spacing.s,
      right: spacing.s,
      child: AttachmentPreviewActionRow(
        closeTooltip: context.l10n.commonClose,
        actions: actions,
        showClose: false,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = _resolveAttachmentWidth(
          constraints,
          context,
          intrinsicWidth: metadata.width?.toDouble(),
          minimumWidth: math.max(
            _attachmentMetadataOverlayMinWidth(context),
            _attachmentPreviewActionRowMinWidth(
                  context,
                  actionCount: actions.length,
                  showClose: false,
                ) +
                (spacing.s * 2),
          ),
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
                          iconData: playing
                              ? LucideIcons.pause
                              : LucideIcons.play,
                          onPressed: _togglePlayback,
                        ),
                      ),
                    if (initialized) actionButtons,
                    _AttachmentMetadataVignette(
                      metadata: metadata,
                      hasLocalFile: hasLocalFile,
                      details: widget.messageDetails,
                      detailOpticalOffsetFactors:
                          widget.detailOpticalOffsetFactors,
                    ),
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
  double? minimumWidth,
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
  final maxWidth = availableWidth * maxWidthFraction;
  final resolvedWidth = math.min(targetWidth, maxWidth);
  if (minimumWidth == null || minimumWidth <= 0) {
    return resolvedWidth;
  }
  return math.max(resolvedWidth, math.min(minimumWidth, maxWidth));
}

double _attachmentMetadataOverlayMinWidth(BuildContext context) =>
    context.sizing.attachmentPreviewExtent * 2;

double _attachmentPreviewActionRowMinWidth(
  BuildContext context, {
  required int actionCount,
  required bool showClose,
}) {
  final spacing = context.spacing;
  final sizing = context.sizing;
  final totalButtons = actionCount + (showClose ? 1 : 0);
  if (totalButtons <= 0) return 0;
  return (sizing.iconButtonTapTarget * totalButtons) +
      (spacing.xs * (totalButtons - 1));
}

({int width, int height})? _attachmentImageCacheDimensions({
  required double targetWidth,
  required double aspectRatio,
  required double devicePixelRatio,
  required int? intrinsicWidth,
  required int? intrinsicHeight,
}) {
  if (!targetWidth.isFinite ||
      targetWidth <= 0 ||
      !aspectRatio.isFinite ||
      aspectRatio <= 0 ||
      !devicePixelRatio.isFinite ||
      devicePixelRatio <= 0) {
    return null;
  }
  final targetHeight = targetWidth / aspectRatio;
  if (!targetHeight.isFinite || targetHeight <= 0) {
    return null;
  }
  final effectiveDevicePixelRatio = math.min(
    devicePixelRatio,
    _attachmentImagePreviewMaxDevicePixelRatio,
  );
  final desiredWidth = targetWidth * effectiveDevicePixelRatio;
  final desiredHeight = targetHeight * effectiveDevicePixelRatio;
  var scale = 1.0;
  if (desiredWidth > _attachmentImagePreviewMaxCacheDimension) {
    scale = math.min(
      scale,
      _attachmentImagePreviewMaxCacheDimension / desiredWidth,
    );
  }
  if (desiredHeight > _attachmentImagePreviewMaxCacheDimension) {
    scale = math.min(
      scale,
      _attachmentImagePreviewMaxCacheDimension / desiredHeight,
    );
  }
  if (intrinsicWidth != null &&
      intrinsicWidth > 0 &&
      desiredWidth > intrinsicWidth) {
    scale = math.min(scale, intrinsicWidth / desiredWidth);
  }
  if (intrinsicHeight != null &&
      intrinsicHeight > 0 &&
      desiredHeight > intrinsicHeight) {
    scale = math.min(scale, intrinsicHeight / desiredHeight);
  }
  final cacheWidth = (desiredWidth * scale).ceil();
  final cacheHeight = (desiredHeight * scale).ceil();
  if (cacheWidth <= 0 || cacheHeight <= 0) {
    return null;
  }
  return (width: cacheWidth, height: cacheHeight);
}

Future<void> _openImagePreview(
  BuildContext context, {
  required File file,
  required FileMetadataData metadata,
  FileTypeReport? typeReport,
  List<InlineSpan> messageDetails = const <InlineSpan>[],
  Map<int, double> detailOpticalOffsetFactors = const <int, double>{},
}) async {
  if (!await file.exists()) return;
  if (!context.mounted) return;
  await showFadeScaleDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return _ImageAttachmentPreviewDialog(
        composeContext: context,
        file: file,
        metadata: metadata,
        typeReport: typeReport,
        messageDetails: messageDetails,
        detailOpticalOffsetFactors: detailOpticalOffsetFactors,
      );
    },
  );
}

class _ImageAttachmentPreviewDialog extends StatelessWidget {
  const _ImageAttachmentPreviewDialog({
    required this.composeContext,
    required this.file,
    required this.metadata,
    this.typeReport,
    required this.messageDetails,
    required this.detailOpticalOffsetFactors,
  });

  final BuildContext composeContext;
  final File file;
  final FileMetadataData metadata;
  final FileTypeReport? typeReport;
  final List<InlineSpan> messageDetails;
  final Map<int, double> detailOpticalOffsetFactors;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final spacing = context.spacing;
    final sizing = context.sizing;
    final intrinsic = _intrinsicSizeFrom(metadata);
    final l10n = context.l10n;
    final actions = localAttachmentPreviewDialogActions(
      ownerContext: composeContext,
      file: file,
      metadata: metadata,
      report: typeReport ?? metadata.declaredTypeReport,
      l10n: l10n,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaSize.width;
        final double availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mediaSize.height;
        final double maxWidth = math.max(0.0, availableWidth - spacing.xl);
        final double maxHeight = math.max(0.0, availableHeight - spacing.xl);
        final double actionRowHeight = sizing.iconButtonTapTarget;
        final double actionRowMinWidth = _attachmentPreviewActionRowMinWidth(
          context,
          actionCount: actions.length,
          showClose: true,
        );
        final double minimumPreviewWidth = math.max(
          _attachmentMetadataOverlayMinWidth(context),
          actionRowMinWidth,
        );
        final double metadataHeight =
            sizing.menuItemHeight * (messageDetails.isEmpty ? 2 : 3);
        final double previewMaxHeight = math.max(
          0.0,
          maxHeight - spacing.s - metadataHeight - spacing.s - actionRowHeight,
        );
        final double fallbackWidth = math.min(maxWidth, sizing.dialogMaxWidth);
        final double fallbackHeight = math.min(
          previewMaxHeight,
          fallbackWidth * sizing.dialogMaxHeightFraction,
        );
        final fittedImageSize = _fitWithinBounds(
          intrinsicSize: intrinsic,
          maxWidth: maxWidth,
          maxHeight: previewMaxHeight,
          fallbackWidth: fallbackWidth,
          fallbackHeight: fallbackHeight,
        );
        final contentWidth = _resolvePreviewContentWidth(
          imageWidth: fittedImageSize.width,
          minimumWidth: minimumPreviewWidth,
          maxWidth: maxWidth,
        );
        final imageSize = _expandPreviewImageSizeForWidth(
          size: fittedImageSize,
          targetWidth: contentWidth,
          maxHeight: previewMaxHeight,
        );
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: contentWidth,
                child: Center(
                  child: SizedBox(
                    width: imageSize.width,
                    height: imageSize.height,
                    child: InteractiveViewer(
                      maxScale: sizing.mediaPreviewMaxScale,
                      child: Image.file(file, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              SizedBox(height: spacing.s),
              SizedBox(
                width: contentWidth,
                child: _AttachmentMetadataSummary(
                  metadata: metadata,
                  hasLocalFile: true,
                  details: messageDetails,
                  detailOpticalOffsetFactors: detailOpticalOffsetFactors,
                ),
              ),
              SizedBox(height: spacing.s),
              SizedBox(
                width: contentWidth,
                height: actionRowHeight,
                child: Center(
                  child: AttachmentPreviewActionRow(
                    closeTooltip: l10n.commonClose,
                    actions: actions,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
  if (cappedWidth <= 0 || cappedHeight <= 0) {
    return Size(cappedWidth, cappedHeight);
  }
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

double _resolvePreviewContentWidth({
  required double imageWidth,
  required double minimumWidth,
  required double maxWidth,
}) {
  if (imageWidth <= 0 ||
      !imageWidth.isFinite ||
      minimumWidth <= 0 ||
      maxWidth <= 0) {
    return imageWidth;
  }
  return math.min(math.max(imageWidth, minimumWidth), maxWidth);
}

Size _expandPreviewImageSizeForWidth({
  required Size size,
  required double targetWidth,
  required double maxHeight,
}) {
  if (size.width <= 0 ||
      size.height <= 0 ||
      !size.width.isFinite ||
      !size.height.isFinite ||
      targetWidth <= 0 ||
      maxHeight <= 0) {
    return size;
  }
  if (size.width >= targetWidth) {
    return size;
  }
  final aspectRatio = size.width / size.height;
  if (!aspectRatio.isFinite || aspectRatio <= 0) {
    return size;
  }
  final expandedHeight = targetWidth / aspectRatio;
  if (expandedHeight <= maxHeight) {
    return Size(targetWidth, expandedHeight);
  }
  return size;
}

String _mediaDecodeGuardKey(String metadataId) =>
    '$_mediaDecodeGuardKeyPrefix$metadataId';

Future<bool> _isImagePreviewAllowed(
  File file, {
  required FileMetadataData metadata,
}) async {
  final guardKey = _mediaDecodeGuardKey(metadata.id);
  if (!MediaDecodeGuard.instance.allowAttempt(guardKey)) {
    return false;
  }
  late final FileStat stat;
  try {
    stat = await file.stat();
  } on FileSystemException {
    return false;
  }
  final cacheKey = _imagePreviewValidationCacheKey(
    file: file,
    metadata: metadata,
    stat: stat,
  );
  if (_allowedImagePreviewValidationKeys.remove(cacheKey)) {
    _allowedImagePreviewValidationKeys.add(cacheKey);
    return true;
  }
  final allowed = await isSafeImageFile(file, _attachmentImageDecodeLimits);
  if (!allowed) {
    MediaDecodeGuard.instance.registerFailure(guardKey);
    return false;
  }
  MediaDecodeGuard.instance.registerSuccess(guardKey);
  _rememberAllowedImagePreview(cacheKey);
  return true;
}

Object _imagePreviewValidationRequestKey({
  required File file,
  required FileMetadataData metadata,
}) {
  return (
    path: file.path,
    id: metadata.id.trim(),
    sizeBytes: metadata.sizeBytes,
    width: metadata.width,
    height: metadata.height,
    mimeType: metadata.mimeType?.trim().toLowerCase(),
  );
}

Object _imagePreviewValidationCacheKey({
  required File file,
  required FileMetadataData metadata,
  required FileStat stat,
}) {
  return (
    path: file.path,
    id: metadata.id.trim(),
    sizeBytes: metadata.sizeBytes,
    width: metadata.width,
    height: metadata.height,
    mimeType: metadata.mimeType?.trim().toLowerCase(),
    fileSize: stat.size,
    modifiedAt: stat.modified.millisecondsSinceEpoch,
  );
}

void _rememberAllowedImagePreview(Object key) {
  _allowedImagePreviewValidationKeys
    ..remove(key)
    ..add(key);
  while (_allowedImagePreviewValidationKeys.length >
      _attachmentImagePreviewValidationCacheMaxEntries) {
    _allowedImagePreviewValidationKeys.remove(
      _allowedImagePreviewValidationKeys.first,
    );
  }
}

class _FileAttachment extends StatefulWidget {
  const _FileAttachment({
    required this.metadata,
    required this.stanzaId,
    required this.hasLocalFile,
    this.downloadDelegate,
    this.metadataReloadDelegate,
    this.typeReport,
    required this.messageDetails,
    required this.detailOpticalOffsetFactors,
  });

  final FileMetadataData metadata;
  final String stanzaId;
  final bool hasLocalFile;
  final AttachmentDownloadDelegate? downloadDelegate;
  final AttachmentMetadataReloadDelegate? metadataReloadDelegate;
  final FileTypeReport? typeReport;
  final List<InlineSpan> messageDetails;
  final Map<int, double> detailOpticalOffsetFactors;

  @override
  State<_FileAttachment> createState() => _FileAttachmentState();
}

class _AttachmentDownloadCancelledException implements Exception {
  const _AttachmentDownloadCancelledException();
}

class _FileAttachmentState extends State<_FileAttachment> {
  _FileAttachmentAction? _activeAction;
  late final ShadPopoverController _actionsController;
  String? _downloadedLocalPath;

  bool get _busy => _activeAction != null;

  String? get _effectiveLocalPath {
    final metadataPath = widget.metadata.path?.trim();
    if (widget.hasLocalFile && metadataPath?.isNotEmpty == true) {
      return metadataPath;
    }
    final downloadedPath = _downloadedLocalPath?.trim();
    if (downloadedPath?.isNotEmpty == true) {
      return downloadedPath;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _actionsController = ShadPopoverController();
  }

  @override
  void didUpdateWidget(covariant _FileAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metadata.id != widget.metadata.id ||
        oldWidget.metadata.path != widget.metadata.path) {
      _downloadedLocalPath = null;
    }
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
    final localPath = _effectiveLocalPath;
    final localFile = localPath == null ? null : File(localPath);
    final hasLocalFile = localFile != null;
    final canDownload = url != null || widget.downloadDelegate != null;
    final saveEnabled = hasLocalFile || canDownload;
    final shareEnabled = hasLocalFile || canDownload;
    final previewKind = resolveAttachmentPreviewKind(
      report: report,
      fileName: metadata.filename,
      path: metadata.path,
      declaredMimeType: metadata.mimeType,
    );
    final previewEnabled =
        (hasLocalFile || canDownload) &&
        (previewKind == AttachmentPreviewKind.pdf ||
            previewKind == AttachmentPreviewKind.text);
    final String saveTooltip = hasLocalFile
        ? l10n.chatAttachmentExportConfirm
        : l10n.chatAttachmentDownloadAndSave;
    final String shareTooltip = hasLocalFile
        ? l10n.chatActionShare
        : l10n.chatAttachmentDownloadAndShare;
    final String previewTooltip = hasLocalFile
        ? l10n.chatAttachmentPreview
        : l10n.chatAttachmentDownloadAndPreview;
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
        child: Icon(LucideIcons.paperclip, size: sizing.iconButtonIconSize),
      ),
    );
    final sizeLabel = _formatAttachmentSize(
      bytes: metadata.sizeBytes,
      hasLocalFile: hasLocalFile,
      l10n: l10n,
    );
    final fileNameStyle = context.textTheme.small.copyWith(
      fontWeight: FontWeight.w600,
    );
    final actionSpacing = spacing.s;
    final actionButtonCount = previewEnabled ? 3 : 2;
    final actionRowMinWidth =
        (sizing.iconButtonTapTarget * actionButtonCount) +
        (actionSpacing * (actionButtonCount - 1));
    final Widget attachmentActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AxiIconButton(
          iconData: LucideIcons.save,
          tooltip: saveTooltip,
          loading: _activeAction == _FileAttachmentAction.save,
          onPressed: saveEnabled && !_busy ? _saveAttachment : null,
        ),
        SizedBox(width: actionSpacing),
        AxiIconButton(
          iconData: LucideIcons.share2,
          tooltip: shareTooltip,
          loading: _activeAction == _FileAttachmentAction.share,
          onPressed: shareEnabled && !_busy ? _shareAttachment : null,
        ),
        if (previewEnabled) ...[
          SizedBox(width: actionSpacing),
          AxiIconButton(
            iconData: LucideIcons.eye,
            tooltip: previewTooltip,
            loading: _activeAction == _FileAttachmentAction.preview,
            onPressed: !_busy ? _previewAttachment : null,
          ),
        ],
      ],
    );
    return _AttachmentSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final detailsWidth =
              availableWidth -
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
          final bool stackActions =
              !shouldMeasureText ||
              detailsWidth <= 0 ||
              (painter..layout(maxWidth: detailsWidth)).didExceedMaxLines;
          final compactRowMinWidth =
              (sizing.iconButtonTapTarget * 2) + (spacing.s * 2);
          final placeActionsBelow =
              stackActions && availableWidth < compactRowMinWidth;
          final int filenameMaxLines = stackActions ? 2 : 1;
          final Widget actionRow = stackActions
              ? AxiPopover(
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
                          label: saveTooltip,
                          onPressed: () {
                            _actionsController.hide();
                            _saveAttachment();
                          },
                          enabled: saveEnabled && !_busy,
                        ),
                        AxiMenuAction(
                          icon: LucideIcons.share2,
                          label: shareTooltip,
                          onPressed: () {
                            _actionsController.hide();
                            _shareAttachment();
                          },
                          enabled: shareEnabled && !_busy,
                        ),
                        if (previewEnabled)
                          AxiMenuAction(
                            icon: LucideIcons.eye,
                            label: previewTooltip,
                            onPressed: () {
                              _actionsController.hide();
                              _previewAttachment();
                            },
                            enabled: !_busy,
                          ),
                      ],
                    );
                  },
                  child: AxiTooltip(
                    builder: (_) => Text(l10n.commonMoreOptions),
                    child: AxiIconButton(
                      iconData: _busy
                          ? LucideIcons.loaderCircle
                          : Icons.more_horiz,
                      loading: _busy,
                      onPressed: _busy ? null : _actionsController.toggle,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.small.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
              if (widget.messageDetails.isNotEmpty)
                _AttachmentTimelineDetails(
                  details: widget.messageDetails,
                  detailOpticalOffsetFactors: widget.detailOpticalOffsetFactors,
                ),
            ],
          );
          if (placeActionsBelow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.s,
              children: [
                Row(
                  children: [
                    attachmentIcon,
                    SizedBox(width: spacing.s),
                    Expanded(child: attachmentDetails),
                  ],
                ),
                Align(alignment: Alignment.centerRight, child: actionRow),
              ],
            );
          }
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
    if (_busy) return;
    final l10n = context.l10n;
    setState(() {
      _activeAction = _FileAttachmentAction.save;
    });
    final toaster = ShadToaster.maybeOf(context);
    try {
      final path = await _resolveLocalPath(
        existingPath: _effectiveLocalPath,
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
      final report = await inspectFileType(
        file: file,
        declaredMimeType: widget.metadata.mimeType,
        fileName: widget.metadata.filename,
      );
      if (!mounted) return;
      final allowed = await confirmExportAllowed(
        context,
        metadata: widget.metadata,
        report: report,
        confirmLabel: l10n.chatAttachmentExportConfirm,
      );
      if (!allowed || !mounted) return;
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
          _activeAction = null;
        });
      }
    }
  }

  Future<void> _shareAttachment() async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() {
      _activeAction = _FileAttachmentAction.share;
    });
    final toaster = ShadToaster.maybeOf(context);
    try {
      final path = await _resolveLocalPath(
        existingPath: _effectiveLocalPath,
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
      final report = await inspectFileType(
        file: file,
        declaredMimeType: widget.metadata.mimeType,
        fileName: widget.metadata.filename,
      );
      if (!mounted) return;
      final allowed = await confirmExportAllowed(
        context,
        metadata: widget.metadata,
        report: report,
        confirmLabel: l10n.chatActionShare,
      );
      if (!allowed || !mounted) return;
      final approved = await _confirmAttachmentShare(context);
      if (!mounted) return;
      if (approved != true) return;
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
          _activeAction = null;
        });
      }
    }
  }

  Future<void> _previewAttachment() async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() {
      _activeAction = _FileAttachmentAction.preview;
    });
    final toaster = ShadToaster.maybeOf(context);
    try {
      final path = await _resolveLocalPath(
        existingPath: _effectiveLocalPath,
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
      final report = await inspectFileType(
        file: file,
        declaredMimeType: widget.metadata.mimeType,
        fileName: widget.metadata.filename,
      );
      if (!mounted) return;
      final allowed = await confirmExportAllowed(
        context,
        metadata: widget.metadata,
        report: report,
        confirmLabel: l10n.chatAttachmentPreview,
      );
      if (!allowed || !mounted) return;
      final previewData = await resolveAttachmentPreviewData(
        file: file,
        attachment: attachmentPreviewSourceFromMetadata(
          metadata: widget.metadata,
          file: file,
        ),
        typeReport: report,
      );
      if (!mounted) return;
      if (previewData == null || !previewData.kind.opensDialog) {
        _showToast(
          l10n,
          toaster,
          l10n.chatAttachmentUnavailable,
          destructive: true,
        );
        return;
      }
      await showAttachmentPreviewDialog(
        context: context,
        data: previewData,
        closeTooltip: l10n.commonClose,
        actions: localAttachmentPreviewDialogActions(
          ownerContext: context,
          file: file,
          metadata: widget.metadata,
          report: report,
          l10n: l10n,
        ),
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
          _activeAction = null;
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
    if (!await refreshedFile.exists()) return null;
    _downloadedLocalPath = refreshedFile.path;
    return refreshedFile.path;
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
    required this.metadata,
    required this.downloading,
    required this.messageDetails,
    required this.detailOpticalOffsetFactors,
    required this.onPressed,
  });

  final FileMetadataData metadata;
  final bool downloading;
  final List<InlineSpan> messageDetails;
  final Map<int, double> detailOpticalOffsetFactors;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final openLabel = l10n.chatAttachmentPreview;
    final openTooltip = l10n.chatAttachmentDownloadAndPreview;
    final sizeLabel = _formatAttachmentSize(
      bytes: metadata.sizeBytes,
      hasLocalFile: false,
      l10n: l10n,
    );
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
                          filename: metadata.filename,
                          style: context.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    sizeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.small.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                  if (messageDetails.isNotEmpty)
                    _AttachmentTimelineDetails(
                      details: messageDetails,
                      detailOpticalOffsetFactors: detailOpticalOffsetFactors,
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
    required this.metadata,
    required this.downloading,
    required this.messageDetails,
    required this.detailOpticalOffsetFactors,
    required this.onPressed,
  });

  final FileMetadataData metadata;
  final bool downloading;
  final List<InlineSpan> messageDetails;
  final Map<int, double> detailOpticalOffsetFactors;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final openLabel = l10n.chatAttachmentPreview;
    final openTooltip = l10n.chatAttachmentDownloadAndPreview;
    final sizeLabel = _formatAttachmentSize(
      bytes: metadata.sizeBytes,
      hasLocalFile: false,
      l10n: l10n,
    );
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
                          filename: metadata.filename,
                          style: context.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    sizeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.small.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                  if (messageDetails.isNotEmpty)
                    _AttachmentTimelineDetails(
                      details: messageDetails,
                      detailOpticalOffsetFactors: detailOpticalOffsetFactors,
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
    required this.metadata,
    required this.downloading,
    required this.messageDetails,
    required this.detailOpticalOffsetFactors,
    required this.onPressed,
  });

  final FileMetadataData metadata;
  final bool downloading;
  final List<InlineSpan> messageDetails;
  final Map<int, double> detailOpticalOffsetFactors;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final openLabel = l10n.chatAttachmentPreview;
    final openTooltip = l10n.chatAttachmentDownloadAndPreview;
    final sizeLabel = _formatAttachmentSize(
      bytes: metadata.sizeBytes,
      hasLocalFile: false,
      l10n: l10n,
    );
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
                          filename: metadata.filename,
                          style: context.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    sizeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.small.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                  if (messageDetails.isNotEmpty)
                    _AttachmentTimelineDetails(
                      details: messageDetails,
                      detailOpticalOffsetFactors: detailOpticalOffsetFactors,
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

class _AttachmentTimelineDetails extends StatelessWidget {
  const _AttachmentTimelineDetails({
    required this.details,
    required this.detailOpticalOffsetFactors,
  });

  final List<InlineSpan> details;
  final Map<int, double> detailOpticalOffsetFactors;

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) {
      return const SizedBox.shrink();
    }
    return ChatInlineDetails(
      details: details,
      detailOpticalOffsetFactors: detailOpticalOffsetFactors,
    );
  }
}

class _AttachmentMetadataVignette extends StatelessWidget {
  const _AttachmentMetadataVignette({
    required this.metadata,
    required this.hasLocalFile,
    required this.details,
    required this.detailOpticalOffsetFactors,
    this.trailing,
  });

  final FileMetadataData metadata;
  final bool hasLocalFile;
  final List<InlineSpan> details;
  final Map<int, double> detailOpticalOffsetFactors;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final curveDepth = spacing.m;
    final metadataSummary = _AttachmentMetadataSummary(
      metadata: metadata,
      hasLocalFile: hasLocalFile,
      details: details,
      detailOpticalOffsetFactors: detailOpticalOffsetFactors,
      foregroundColor: colors.foreground,
      supportingColor: colors.foreground,
    );
    final content = CustomPaint(
      painter: _AttachmentVignettePainter(
        topColor: colors.card.withValues(alpha: 0),
        bottomColor: colors.card.withValues(alpha: 0.88),
        curveDepth: curveDepth,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          spacing.s,
          spacing.l + curveDepth,
          spacing.s,
          spacing.s,
        ),
        child: trailing == null
            ? metadataSummary
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: IgnorePointer(child: metadataSummary)),
                  SizedBox(width: spacing.s),
                  trailing!,
                ],
              ),
      ),
    );
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: trailing == null ? IgnorePointer(child: content) : content,
    );
  }
}

class _AttachmentVignettePainter extends CustomPainter {
  const _AttachmentVignettePainter({
    required this.topColor,
    required this.bottomColor,
    required this.curveDepth,
  });

  final Color topColor;
  final Color bottomColor;
  final double curveDepth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shaderTop = math.min(curveDepth, size.height);
    final shaderRect = Rect.fromLTWH(
      0,
      shaderTop,
      size.width,
      math.max(curveDepth, size.height - shaderTop),
    );
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size.width / 2, curveDepth * 2, size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, bottomColor],
      ).createShader(shaderRect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AttachmentVignettePainter oldDelegate) =>
      topColor != oldDelegate.topColor ||
      bottomColor != oldDelegate.bottomColor ||
      curveDepth != oldDelegate.curveDepth;
}

class _AttachmentMetadataSummary extends StatelessWidget {
  const _AttachmentMetadataSummary({
    required this.metadata,
    required this.hasLocalFile,
    required this.details,
    required this.detailOpticalOffsetFactors,
    this.foregroundColor,
    this.supportingColor,
  });

  final FileMetadataData metadata;
  final bool hasLocalFile;
  final List<InlineSpan> details;
  final Map<int, double> detailOpticalOffsetFactors;
  final Color? foregroundColor;
  final Color? supportingColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizeLabel = _formatAttachmentSize(
      bytes: metadata.sizeBytes,
      hasLocalFile: hasLocalFile,
      l10n: context.l10n,
    );
    final resolvedForeground = foregroundColor ?? colors.foreground;
    final resolvedSupporting = supportingColor ?? colors.mutedForeground;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.xxs,
      children: [
        _AttachmentFileNameText(
          filename: metadata.filename,
          maxLines: 2,
          style: context.textTheme.small.copyWith(
            color: resolvedForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          sizeLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.muted.copyWith(color: resolvedSupporting),
        ),
        if (details.isNotEmpty)
          _AttachmentTimelineDetails(
            details: details,
            detailOpticalOffsetFactors: detailOpticalOffsetFactors,
          ),
      ],
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
    final OutlinedBorder baseShape =
        scope?.shape ?? ContinuousRectangleBorder(borderRadius: context.radius);
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
          padding: (padding ?? EdgeInsets.all(spacing.m)).add(
            EdgeInsets.all(borderWidth),
          ),
          child: child,
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
      ShareParams(files: <XFile>[XFile(sharedFile.path)]),
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
  try {
    final savePath = await saveAttachmentFileWithPicker(
      file: file,
      filename: resolvedName,
      platform: defaultTargetPlatform,
    );
    if (attachmentSaveShouldWriteBytes(defaultTargetPlatform)) {
      return;
    }
    if (savePath == null || savePath.trim().isEmpty) return;
    final destination = File(savePath);
    if (p.equals(destination.path, file.path)) return;
    if (await destination.exists()) {
      await destination.delete();
    }
    await file.copy(destination.path);
    await _applyDownloadProtections(destination);
  } on PlatformException {
    _showToast(
      l10n,
      toaster,
      l10n.chatAttachmentUnavailable,
      destructive: true,
    );
  } on FileSystemException {
    _showToast(
      l10n,
      toaster,
      l10n.chatAttachmentUnavailable,
      destructive: true,
    );
  }
}

@visibleForTesting
bool attachmentSaveShouldWriteBytes(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => false,
  };
}

@visibleForTesting
Future<String?> saveAttachmentFileWithPicker({
  required File file,
  required String filename,
  required TargetPlatform platform,
  FilePicker? filePicker,
}) async {
  final picker = filePicker ?? FilePicker.platform;
  if (attachmentSaveShouldWriteBytes(platform)) {
    return picker.saveFile(fileName: filename, bytes: await file.readAsBytes());
  }
  return picker.saveFile(fileName: filename);
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
  Timer(_attachmentShareCleanupDelay, () async {
    try {
      if (await shareDir.exists()) {
        await shareDir.delete(recursive: true);
      }
    } on Exception {
      return;
    }
  });
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
  final status = hasLocalFile
      ? l10n.chatAttachmentOnThisDevice
      : l10n.chatAttachmentNotDownloadedYet;
  if (bytes == null || bytes <= 0) {
    return hasLocalFile
        ? '$status • ${l10n.chatAttachmentUnknownSize}'
        : status;
  }
  return '$status • ${_formatSize(bytes, l10n)}';
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
  final resolvedLimit = maxBytes == null || maxBytes <= 0
      ? null
      : _formatSize(maxBytes, l10n);
  if (resolvedLimit == null) {
    return l10n.chatAttachmentTooLargeMessageDefault;
  }
  return l10n.chatAttachmentTooLargeMessage(resolvedLimit);
}
