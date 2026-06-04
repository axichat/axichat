// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/unicode_safety.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum AttachmentPreviewKind {
  image,
  video,
  pdf,
  text,
  unsupported;

  bool get opensDialog => switch (this) {
    AttachmentPreviewKind.image ||
    AttachmentPreviewKind.pdf ||
    AttachmentPreviewKind.text ||
    AttachmentPreviewKind.unsupported => true,
    AttachmentPreviewKind.video => false,
  };
}

class AttachmentPreviewData {
  const AttachmentPreviewData._({
    required this.file,
    required this.attachment,
    required this.report,
    required this.kind,
    this.intrinsicSize,
    this.textContent,
    this.truncatedText = false,
  });

  factory AttachmentPreviewData.image({
    required File file,
    required Attachment attachment,
    required FileTypeReport report,
    Size? intrinsicSize,
  }) => AttachmentPreviewData._(
    file: file,
    attachment: attachment,
    report: report,
    kind: AttachmentPreviewKind.image,
    intrinsicSize: intrinsicSize,
  );

  factory AttachmentPreviewData.video({
    required File file,
    required Attachment attachment,
    required FileTypeReport report,
  }) => AttachmentPreviewData._(
    file: file,
    attachment: attachment,
    report: report,
    kind: AttachmentPreviewKind.video,
  );

  factory AttachmentPreviewData.pdf({
    required File file,
    required Attachment attachment,
    required FileTypeReport report,
  }) => AttachmentPreviewData._(
    file: file,
    attachment: attachment,
    report: report,
    kind: AttachmentPreviewKind.pdf,
  );

  factory AttachmentPreviewData.text({
    required File file,
    required Attachment attachment,
    required FileTypeReport report,
    required String textContent,
    required bool truncated,
  }) => AttachmentPreviewData._(
    file: file,
    attachment: attachment,
    report: report,
    kind: AttachmentPreviewKind.text,
    textContent: textContent,
    truncatedText: truncated,
  );

  factory AttachmentPreviewData.unsupported({
    required File file,
    required Attachment attachment,
    required FileTypeReport report,
  }) => AttachmentPreviewData._(
    file: file,
    attachment: attachment,
    report: report,
    kind: AttachmentPreviewKind.unsupported,
  );

  final File file;
  final Attachment attachment;
  final FileTypeReport report;
  final AttachmentPreviewKind kind;
  final Size? intrinsicSize;
  final String? textContent;
  final bool truncatedText;
}

class AttachmentPreviewDialogAction {
  const AttachmentPreviewDialogAction({
    required this.iconData,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData iconData;
  final String tooltip;
  final void Function(BuildContext context) onPressed;
  final bool destructive;
}

Future<AttachmentPreviewData?> resolveAttachmentPreviewData({
  required File file,
  required Attachment attachment,
  FileTypeReport? typeReport,
}) async {
  final report =
      typeReport ??
      await inspectFileType(
        file: file,
        declaredMimeType: attachment.mimeType,
        fileName: attachment.fileName,
      );
  final kind = resolveAttachmentPreviewKind(
    report: report,
    fileName: attachment.fileName,
    path: attachment.path,
    declaredMimeType: attachment.mimeType,
  );
  if (kind == null) {
    return null;
  }
  switch (kind) {
    case AttachmentPreviewKind.image:
      final intrinsicSize = await resolveAttachmentPreviewSize(
        attachment: attachment,
        file: file,
      );
      return AttachmentPreviewData.image(
        file: file,
        attachment: attachment,
        report: report,
        intrinsicSize: intrinsicSize,
      );
    case AttachmentPreviewKind.video:
      return AttachmentPreviewData.video(
        file: file,
        attachment: attachment,
        report: report,
      );
    case AttachmentPreviewKind.pdf:
      return AttachmentPreviewData.pdf(
        file: file,
        attachment: attachment,
        report: report,
      );
    case AttachmentPreviewKind.text:
      final textContent = await readAttachmentTextPreview(file);
      return AttachmentPreviewData.text(
        file: file,
        attachment: attachment,
        report: report,
        textContent: textContent.content,
        truncated: textContent.truncated,
      );
    case AttachmentPreviewKind.unsupported:
      return AttachmentPreviewData.unsupported(
        file: file,
        attachment: attachment,
        report: report,
      );
  }
}

AttachmentPreviewKind? resolveAttachmentPreviewKind({
  required FileTypeReport report,
  required String fileName,
  required String? path,
  required String? declaredMimeType,
}) {
  final useDeclaredFallback = !report.hasReliableDetection;
  if (report.isDetectedImage ||
      (useDeclaredFallback && report.isDeclaredImage)) {
    return AttachmentPreviewKind.image;
  }
  if (report.isDetectedVideo ||
      (useDeclaredFallback && report.isDeclaredVideo)) {
    return AttachmentPreviewKind.video;
  }
  final preferredMime = resolveAttachmentPreviewMime(
    report: report,
    fileName: fileName,
    path: path,
    declaredMimeType: declaredMimeType,
  );
  if (isAttachmentPdfPreviewType(preferredMime)) {
    return AttachmentPreviewKind.pdf;
  }
  if (isAttachmentTextPreviewType(preferredMime, fileName)) {
    return AttachmentPreviewKind.text;
  }
  return null;
}

String? resolveAttachmentPreviewMime({
  required FileTypeReport report,
  required String fileName,
  required String? path,
  required String? declaredMimeType,
}) {
  final preferredMime = normalizedAttachmentPreviewMime(
    report.preferredMimeType,
  );
  if (!_isGenericAttachmentPreviewMime(preferredMime)) {
    return preferredMime;
  }
  final extensionMime = normalizedAttachmentPreviewMime(
    report.extensionMimeType,
  );
  if (!_isGenericAttachmentPreviewMime(extensionMime)) {
    return extensionMime;
  }
  final declaredMime = normalizedAttachmentPreviewMime(declaredMimeType);
  if (!_isGenericAttachmentPreviewMime(declaredMime)) {
    return declaredMime;
  }
  return extensionBasedAttachmentPreviewMime(fileName, path);
}

String? normalizedAttachmentPreviewMime(String? mime) {
  final normalized = mime?.split(';').first.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}

bool _isGenericAttachmentPreviewMime(String? mime) =>
    mime == null || mime == 'application/octet-stream';

bool isAttachmentPdfPreviewType(String? mime) =>
    normalizedAttachmentPreviewMime(mime) == 'application/pdf';

bool isAttachmentTextPreviewType(String? mime, String filename) {
  const textMimeWhitelist = <String>{
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
  const textExtensions = <String>{
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
    '.rtf',
  };
  final normalizedMime = normalizedAttachmentPreviewMime(mime);
  if (normalizedMime != null && normalizedMime.startsWith('text/')) {
    return true;
  }
  if (normalizedMime != null && textMimeWhitelist.contains(normalizedMime)) {
    return true;
  }
  final extension = attachmentPreviewExtensionFromName(filename);
  if (extension != null && textExtensions.contains(extension)) {
    return true;
  }
  return false;
}

String? extensionBasedAttachmentPreviewMime(String fileName, String? path) {
  final extension =
      attachmentPreviewExtensionFromName(fileName) ??
      attachmentPreviewExtensionFromName(path ?? '');
  if (extension == null) return null;
  return switch (extension) {
    '.md' => 'text/markdown',
    '.csv' => 'text/csv',
    '.tsv' => 'text/tab-separated-values',
    '.json' => 'application/json',
    '.xml' => 'application/xml',
    '.txt' => 'text/plain',
    '.yaml' || '.yml' => 'text/yaml',
    '.log' => 'text/plain',
    '.ini' || '.cfg' => 'text/plain',
    '.rtf' => 'application/rtf',
    _ => null,
  };
}

String? attachmentPreviewExtensionFromName(String name) {
  final index = name.lastIndexOf('.');
  if (index == -1) return null;
  return name.substring(index).toLowerCase();
}

Future<AttachmentTextPreviewResult> readAttachmentTextPreview(File file) async {
  const maxTextPreviewBytes = 256 * 1024;
  const truncationSuffix = '\n…';
  late final int totalBytes;
  try {
    totalBytes = await file.length();
  } on Exception {
    return const AttachmentTextPreviewResult(content: '', truncated: false);
  }
  final readSize = math.min(totalBytes, maxTextPreviewBytes);
  final bytes = <int>[];
  final stream = file.openRead(0, readSize);
  await for (final chunk in stream) {
    bytes.addAll(chunk);
  }
  final truncated = totalBytes > bytes.length;
  final decoded = await decodeAttachmentTextWithFallback(
    Uint8List.fromList(bytes),
  );
  return AttachmentTextPreviewResult(
    content: truncated ? '$decoded$truncationSuffix' : decoded,
    truncated: truncated,
  );
}

Future<String> decodeAttachmentTextWithFallback(Uint8List bytes) async {
  const candidates = <String>['utf-8', 'utf-16', 'iso-8859-1'];
  for (final encoding in candidates) {
    try {
      return await CharsetConverter.decode(encoding, bytes);
    } on Exception {
      continue;
    }
  }
  return const Utf8Decoder(allowMalformed: true).convert(bytes);
}

class AttachmentTextPreviewResult {
  const AttachmentTextPreviewResult({
    required this.content,
    required this.truncated,
  });

  final String content;
  final bool truncated;
}

Future<Size?> resolveAttachmentPreviewSize({
  required Attachment attachment,
  required File file,
}) async {
  final width = attachment.width;
  final height = attachment.height;
  if (width != null && height != null && width > 0 && height > 0) {
    return Size(width.toDouble(), height.toDouble());
  }
  const maxImageDecodeBytes = 16 * 1024 * 1024;
  if (attachment.sizeBytes > maxImageDecodeBytes) {
    return null;
  }
  try {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
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

Attachment attachmentPreviewSourceFromMetadata({
  required FileMetadataData metadata,
  required File file,
}) {
  return Attachment(
    path: file.path,
    fileName: metadata.filename,
    sizeBytes: metadata.sizeBytes ?? 0,
    mimeType: metadata.mimeType,
    width: metadata.width,
    height: metadata.height,
    metadataId: metadata.id,
  );
}

Future<void> showAttachmentPreviewDialog({
  required BuildContext context,
  required AttachmentPreviewData data,
  required String closeTooltip,
  List<AttachmentPreviewDialogAction> actions =
      const <AttachmentPreviewDialogAction>[],
}) async {
  if (!context.mounted) return;
  await showFadeScaleDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AttachmentPreviewDialog(
        data: data,
        closeTooltip: closeTooltip,
        actions: actions,
      );
    },
  );
}

class AttachmentPreviewDialog extends StatelessWidget {
  const AttachmentPreviewDialog({
    super.key,
    required this.data,
    required this.closeTooltip,
    this.actions = const <AttachmentPreviewDialogAction>[],
  });

  final AttachmentPreviewData data;
  final String closeTooltip;
  final List<AttachmentPreviewDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final spacing = context.spacing;
    final sizing = context.sizing;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaSize.width;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mediaSize.height;
        final maxWidth = math.max(0.0, availableWidth - spacing.xl);
        final maxHeight = math.max(0.0, availableHeight - spacing.xl);
        final actionRowHeight = sizing.iconButtonTapTarget;
        final previewMaxHeight = math.max(
          0.0,
          maxHeight - spacing.s - actionRowHeight,
        );
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: previewMaxHeight,
                ),
                child: AttachmentPreviewContent(
                  data: data,
                  maxWidth: maxWidth,
                  maxHeight: previewMaxHeight,
                ),
              ),
              SizedBox(height: spacing.s),
              SizedBox(
                height: actionRowHeight,
                child: AttachmentPreviewActionRow(
                  closeTooltip: closeTooltip,
                  actions: actions,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AttachmentPreviewActionRow extends StatelessWidget {
  const AttachmentPreviewActionRow({
    super.key,
    required this.closeTooltip,
    required this.actions,
  });

  final String closeTooltip;
  final List<AttachmentPreviewDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colorScheme;
    final ghostColors = AttachmentPreviewGhostColors.resolve(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AxiIconButton.ghost(
          iconData: LucideIcons.x,
          tooltip: closeTooltip,
          color: ghostColors.foreground,
          backgroundColor: ghostColors.background,
          onPressed: () => Navigator.of(context).pop(),
        ),
        for (final action in actions) ...[
          SizedBox(width: spacing.xs),
          AxiIconButton.ghost(
            iconData: action.iconData,
            tooltip: action.tooltip,
            color: action.destructive
                ? colors.destructive
                : ghostColors.foreground,
            backgroundColor: ghostColors.background,
            onPressed: () => action.onPressed(context),
          ),
        ],
      ],
    );
  }
}

class AttachmentPreviewContent extends StatelessWidget {
  const AttachmentPreviewContent({
    super.key,
    required this.data,
    required this.maxWidth,
    required this.maxHeight,
  });

  final AttachmentPreviewData data;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return switch (data.kind) {
      AttachmentPreviewKind.image => AttachmentImagePreviewContent(
        data: data,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      AttachmentPreviewKind.pdf => AttachmentPdfPreviewContent(
        file: data.file,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      AttachmentPreviewKind.text => AttachmentTextPreviewContent(
        textContent: data.textContent ?? '',
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      AttachmentPreviewKind.video => AttachmentUnsupportedPreviewContent(
        fileName: data.attachment.fileName,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      AttachmentPreviewKind.unsupported => AttachmentUnsupportedPreviewContent(
        fileName: data.attachment.fileName,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
    };
  }
}

class AttachmentImagePreviewContent extends StatelessWidget {
  const AttachmentImagePreviewContent({
    super.key,
    required this.data,
    required this.maxWidth,
    required this.maxHeight,
  });

  final AttachmentPreviewData data;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final targetSize = AttachmentPreviewSize(
      intrinsicSize: data.intrinsicSize,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    ).resolve(context);
    return SizedBox(
      width: targetSize.width,
      height: targetSize.height,
      child: InteractiveViewer(
        maxScale: sizing.mediaPreviewMaxScale,
        child: Image.file(data.file, fit: BoxFit.contain),
      ),
    );
  }
}

class AttachmentPdfPreviewContent extends StatelessWidget {
  const AttachmentPdfPreviewContent({
    super.key,
    required this.file,
    required this.maxWidth,
    required this.maxHeight,
  });

  final File file;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: PdfViewer.file(file.path, params: const PdfViewerParams()),
    );
  }
}

class AttachmentTextPreviewContent extends StatelessWidget {
  const AttachmentTextPreviewContent({
    super.key,
    required this.textContent,
    required this.maxWidth,
    required this.maxHeight,
  });

  final String textContent;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: AxiModalSurface(
        backgroundColor: colors.background,
        padding: EdgeInsets.all(spacing.m),
        child: Scrollbar(
          child: SingleChildScrollView(
            child: SelectableText(
              textContent,
              style: context.textTheme.p.copyWith(color: colors.foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class AttachmentUnsupportedPreviewContent extends StatelessWidget {
  const AttachmentUnsupportedPreviewContent({
    super.key,
    required this.fileName,
    required this.maxWidth,
    required this.maxHeight,
  });

  final String fileName;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: AxiModalSurface(
        backgroundColor: colors.card,
        padding: EdgeInsets.all(spacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sanitizeUnicodeControls(fileName).value,
              style: context.textTheme.p,
            ),
            SizedBox(height: spacing.xs),
            Text(
              context.l10n.chatAttachmentUnavailable,
              style: context.textTheme.small.copyWith(
                color: colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttachmentPreviewSize {
  const AttachmentPreviewSize({
    required this.intrinsicSize,
    required this.maxWidth,
    required this.maxHeight,
  });

  final Size? intrinsicSize;
  final double maxWidth;
  final double maxHeight;

  Size resolve(BuildContext context) {
    final cappedWidth = math.max(0.0, maxWidth);
    final cappedHeight = math.max(0.0, maxHeight);
    final size = intrinsicSize;
    if (size == null || size.width <= 0 || size.height <= 0) {
      final width = math.min(cappedWidth, context.sizing.dialogMaxWidth);
      final height = math.min(cappedHeight, width);
      return Size(width, height);
    }
    return AttachmentPreviewScale(size, cappedWidth, cappedHeight).resolve();
  }
}

class AttachmentPreviewScale {
  const AttachmentPreviewScale(this.size, this.maxWidth, this.maxHeight);

  final Size size;
  final double maxWidth;
  final double maxHeight;

  Size resolve() {
    var width = size.width;
    var height = size.height;
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
}

class AttachmentPreviewGhostColors {
  const AttachmentPreviewGhostColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;

  static AttachmentPreviewGhostColors resolve(BuildContext context) {
    final colors = context.colorScheme;
    final isDark = context.brightness == Brightness.dark;
    return AttachmentPreviewGhostColors(
      background: isDark ? colors.background : colors.foreground,
      foreground: isDark ? colors.foreground : colors.background,
    );
  }
}
