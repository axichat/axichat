// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const int _maxTextPreviewBytes = 256 * 1024;
const int _maxImageDecodeBytes = 16 * 1024 * 1024;

Future<void> showPendingAttachmentPreview({
  required BuildContext context,
  required PendingAttachment pending,
  required VoidCallback onRemove,
  required String removeTooltip,
  String? closeTooltip,
}) async {
  if (!context.mounted) return;
  final l10n = context.l10n;
  final closeLabel = closeTooltip ?? l10n.commonClose;
  final file = File(pending.attachment.path);
  if (!await file.exists()) {
    _showPreviewToast(
      context,
      l10n.chatAttachmentUnavailable,
      destructive: true,
    );
    return;
  }

  final previewData = await _buildPreviewData(
    file: file,
    attachment: pending.attachment,
  );
  if (previewData == null) {
    _showPreviewToast(
      context,
      l10n.chatAttachmentUnavailable,
      destructive: true,
    );
    return;
  }

  await showFadeScaleDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return _PendingAttachmentPreviewDialog(
        data: previewData,
        l10n: l10n,
        closeTooltip: closeLabel,
        removeTooltip: removeTooltip,
        onRemove: onRemove,
      );
    },
  );
}

Future<_PendingAttachmentPreviewData?> _buildPreviewData({
  required File file,
  required EmailAttachment attachment,
}) async {
  final report = await inspectFileType(
    file: file,
    declaredMimeType: attachment.mimeType,
    fileName: attachment.fileName,
  );
  final useDeclaredFallback = !report.hasReliableDetection;
  final bool isImageKind =
      report.isDetectedImage || (useDeclaredFallback && report.isDeclaredImage);
  final String? preferredMime = report.preferredMimeType ??
      attachment.mimeType?.toLowerCase() ??
      _extensionBasedMime(attachment.fileName, attachment.path);
  if (isImageKind) {
    final intrinsicSize = await resolveEmailAttachmentSize(
      attachment: attachment,
      file: file,
    );
    return _PendingAttachmentPreviewData.image(
      file: file,
      attachment: attachment,
      report: report,
      intrinsicSize: intrinsicSize,
    );
  }
  if (_isPdfMime(preferredMime)) {
    return _PendingAttachmentPreviewData.pdf(
      file: file,
      attachment: attachment,
      report: report,
    );
  }
  if (_isTextLikeMime(preferredMime, attachment.fileName)) {
    final textContent = await _readTextPreview(file);
    return _PendingAttachmentPreviewData.text(
      file: file,
      attachment: attachment,
      report: report,
      textContent: textContent.content,
      truncated: textContent.truncated,
    );
  }
  return _PendingAttachmentPreviewData.metadata(
    file: file,
    attachment: attachment,
    report: report,
  );
}

Future<_TextPreviewResult> _readTextPreview(File file) async {
  late final int totalBytes;
  try {
    totalBytes = await file.length();
  } on Exception {
    return const _TextPreviewResult(content: '', truncated: false);
  }
  final readSize = math.min(totalBytes, _maxTextPreviewBytes);
  final bytes = <int>[];
  final stream = file.openRead(0, readSize);
  await for (final chunk in stream) {
    bytes.addAll(chunk);
  }
  final truncated = totalBytes > bytes.length;
  final decoded = await _decodeWithFallback(Uint8List.fromList(bytes));
  return _TextPreviewResult(
    content: truncated ? '$decoded${_truncationSuffix}' : decoded,
    truncated: truncated,
  );
}

Future<String> _decodeWithFallback(Uint8List bytes) async {
  const candidates = ['utf-8', 'utf-16', 'iso-8859-1'];
  for (final encoding in candidates) {
    try {
      return await CharsetConverter.decode(encoding, bytes);
    } catch (_) {
      continue;
    }
  }
  return const Utf8Decoder(allowMalformed: true).convert(bytes);
}

const String _truncationSuffix = '\n…';

bool _isPdfMime(String? mime) =>
    mime != null && mime.toLowerCase() == 'application/pdf';

final Set<String> _textMimeWhitelist = {
  'application/json',
  'application/xml',
  'application/rss+xml',
  'application/atom+xml',
  'application/x-yaml',
  'application/x-ndjson',
  'application/javascript',
  'application/ecmascript',
  'application/xhtml+xml',
  'application/rtf',
};

final Set<String> _textExtensions = {
  '.txt',
  '.md',
  '.log',
  '.csv',
  '.tsv',
  '.yaml',
  '.yml',
  '.json',
  '.xml',
  '.ini',
  '.cfg',
};

bool _isTextLikeMime(String? mime, String filename) {
  if (mime != null && mime.toLowerCase().startsWith('text/')) {
    return true;
  }
  if (mime != null && _textMimeWhitelist.contains(mime.toLowerCase())) {
    return true;
  }
  final extension = _extensionFromName(filename);
  if (extension != null && _textExtensions.contains(extension)) {
    return true;
  }
  return false;
}

String? _extensionFromName(String name) {
  try {
    final index = name.lastIndexOf('.');
    if (index == -1) return null;
    return name.substring(index).toLowerCase();
  } on Exception {
    return null;
  }
}

String? _extensionBasedMime(String fileName, String path) {
  final extension = _extensionFromName(fileName) ?? _extensionFromName(path);
  if (extension == null) return null;
  if (extension == '.md') return 'text/markdown';
  if (extension == '.csv') return 'text/csv';
  if (extension == '.json') return 'application/json';
  if (extension == '.xml') return 'application/xml';
  if (extension == '.txt') return 'text/plain';
  if (extension == '.yaml' || extension == '.yml') return 'text/yaml';
  return null;
}

Future<Size?> resolveEmailAttachmentSize({
  required EmailAttachment attachment,
  required File file,
}) async {
  final width = attachment.width;
  final height = attachment.height;
  if (width != null && height != null && width > 0 && height > 0) {
    return Size(width.toDouble(), height.toDouble());
  }
  final sizeBytes = attachment.sizeBytes;
  if (sizeBytes > _maxImageDecodeBytes) {
    return null;
  }
  try {
    final codec = await instantiateImageCodec(await file.readAsBytes());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final result = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    codec.dispose();
    return result;
  } on Exception {
    return null;
  }
}

class _PendingAttachmentPreviewData {
  const _PendingAttachmentPreviewData._({
    required this.file,
    required this.attachment,
    required this.report,
    required this.kind,
    this.intrinsicSize,
    this.textContent,
    this.truncatedText = false,
  });

  factory _PendingAttachmentPreviewData.image({
    required File file,
    required EmailAttachment attachment,
    required FileTypeReport report,
    Size? intrinsicSize,
  }) =>
      _PendingAttachmentPreviewData._(
        file: file,
        attachment: attachment,
        report: report,
        kind: _AttachmentPreviewKind.image,
        intrinsicSize: intrinsicSize,
      );

  factory _PendingAttachmentPreviewData.pdf({
    required File file,
    required EmailAttachment attachment,
    required FileTypeReport report,
  }) =>
      _PendingAttachmentPreviewData._(
        file: file,
        attachment: attachment,
        report: report,
        kind: _AttachmentPreviewKind.pdf,
      );

  factory _PendingAttachmentPreviewData.text({
    required File file,
    required EmailAttachment attachment,
    required FileTypeReport report,
    required String textContent,
    required bool truncated,
  }) =>
      _PendingAttachmentPreviewData._(
        file: file,
        attachment: attachment,
        report: report,
        kind: _AttachmentPreviewKind.text,
        textContent: textContent,
        truncatedText: truncated,
      );

  factory _PendingAttachmentPreviewData.metadata({
    required File file,
    required EmailAttachment attachment,
    required FileTypeReport report,
  }) =>
      _PendingAttachmentPreviewData._(
        file: file,
        attachment: attachment,
        report: report,
        kind: _AttachmentPreviewKind.metadata,
      );

  final File file;
  final EmailAttachment attachment;
  final FileTypeReport report;
  final _AttachmentPreviewKind kind;
  final Size? intrinsicSize;
  final String? textContent;
  final bool truncatedText;
}

enum _AttachmentPreviewKind { image, text, pdf, metadata }

class _TextPreviewResult {
  const _TextPreviewResult({
    required this.content,
    required this.truncated,
  });

  final String content;
  final bool truncated;
}

void _showPreviewToast(
  BuildContext context,
  String message, {
  bool destructive = false,
}) {
  final l10n = context.l10n;
  final toaster = ShadToaster.maybeOf(context);
  final toast = destructive
      ? FeedbackToast.error(title: l10n.toastWhoopsTitle, message: message)
      : FeedbackToast.info(title: l10n.toastHeadsUpTitle, message: message);
  toaster?.show(toast);
}

class _PendingAttachmentPreviewDialog extends StatelessWidget {
  const _PendingAttachmentPreviewDialog({
    required this.data,
    required this.l10n,
    required this.closeTooltip,
    required this.removeTooltip,
    required this.onRemove,
  });

  final _PendingAttachmentPreviewData data;
  final AppLocalizations l10n;
  final String closeTooltip;
  final String removeTooltip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final spacing = context.spacing;
    final maxWidth = math.max(0.0, mediaSize.width - spacing.xl);
    final maxHeight = math.max(0.0, mediaSize.height - spacing.xl);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: _PendingAttachmentPreviewContent(
              data: data,
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
          ),
          SizedBox(height: spacing.s),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AxiIconButton.ghost(
                iconData: LucideIcons.x,
                tooltip: closeTooltip,
                onPressed: () => Navigator.of(context).pop(),
              ),
              SizedBox(width: spacing.xs),
              AxiIconButton.ghost(
                iconData: LucideIcons.trash2,
                tooltip: removeTooltip,
                onPressed: () {
                  Navigator.of(context).pop();
                  onRemove();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingAttachmentPreviewContent extends StatelessWidget {
  const _PendingAttachmentPreviewContent({
    required this.data,
    required this.maxWidth,
    required this.maxHeight,
  });

  final _PendingAttachmentPreviewData data;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    switch (data.kind) {
      case _AttachmentPreviewKind.image:
        return _buildImagePreview(context, spacing);
      case _AttachmentPreviewKind.pdf:
        return _buildPdfPreview(context);
      case _AttachmentPreviewKind.text:
        return _buildTextPreview(context);
      case _AttachmentPreviewKind.metadata:
        return _buildMetadataPreview(context);
    }
  }

  Widget _buildImagePreview(BuildContext context, AxiSpacing spacing) {
    final sizing = context.sizing;
    final targetSize = _fitWithinBounds(
      intrinsicSize: data.intrinsicSize,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    return SizedBox(
      width: targetSize.width,
      height: targetSize.height,
      child: InteractiveViewer(
        maxScale: sizing.mediaPreviewMaxScale,
        child: Image.file(
          data.file,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildPdfPreview(BuildContext context) {
    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: PdfViewer.file(
        data.file.path,
        params: const PdfViewerParams(),
      ),
    );
  }

  Widget _buildTextPreview(BuildContext context) {
    final colors = context.colorScheme;
    final textContent = data.textContent ?? '';
    return Material(
      color: Colors.transparent,
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.spacing.m),
          child: SelectableText(
            textContent,
            style: context.textTheme.p.copyWith(color: colors.foreground),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataPreview(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final l10n = context.l10n;
    final sizeLabel = _formatBytes(
      data.attachment.sizeBytes,
      l10n,
    );
    return Container(
      padding: EdgeInsets.all(spacing.m),
      decoration: ShapeDecoration(
        color: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.sizing.containerRadius),
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.attachment.fileName,
            style: context.textTheme.p,
          ),
          SizedBox(height: spacing.xs),
          Text(
            sizeLabel,
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
          SizedBox(height: spacing.s),
          Text(
            l10n.chatAttachmentPreviewUnsupported,
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
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
    return _scaleWithinBounds(intrinsicSize, cappedWidth, cappedHeight);
  }

  Size _scaleWithinBounds(Size size, double maxWidth, double maxHeight) {
    var width = math.min(size.width, maxWidth);
    var height = math.min(size.height, maxHeight);
    if (width <= 0 || height <= 0) {
      return Size(width, height);
    }
    final aspectRatio = size.width / size.height;
    if (width > maxWidth) {
      width = maxWidth;
      height = width / aspectRatio;
    }
    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspectRatio;
    }
    return Size(width, height);
  }

  String _formatBytes(int bytes, AppLocalizations l10n) {
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
}
