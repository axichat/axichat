// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/media_decode_safety.dart';
import 'package:axichat/src/common/unicode_safety.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:video_player/video_player.dart';

enum AttachmentPreviewKind {
  image,
  video,
  pdf,
  text,
  unsupported;

  bool get opensDialog => switch (this) {
    AttachmentPreviewKind.image ||
    AttachmentPreviewKind.video ||
    AttachmentPreviewKind.pdf ||
    AttachmentPreviewKind.text ||
    AttachmentPreviewKind.unsupported => true,
  };
}

const int _attachmentVideoPreviewMaxBytes = 64 * 1024 * 1024;
const int _attachmentVideoMaxPixels = 32 * 1024 * 1024;
const int _attachmentVideoMinBytes = 1;
const int _attachmentVideoMinDimensionPixels = 1;
const double _attachmentVideoMinDimension = 1.0;
const Duration _attachmentVideoInitTimeout = Duration(seconds: 3);
const String _attachmentPreviewDecodeGuardPrefix = 'attachment-preview:';

bool get supportsAttachmentVideoPlayback {
  if (kIsWeb) return true;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => true,
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.windows => false,
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
    this.enabled = true,
  });

  final IconData iconData;
  final String tooltip;
  final FutureOr<void> Function(BuildContext context) onPressed;
  final bool destructive;
  final bool enabled;
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
  if (Platform.isMacOS) {
    return _decodeAttachmentTextWithDartCodecs(bytes);
  }
  const candidates = <String>['utf-8', 'utf-16', 'iso-8859-1'];
  for (final encoding in candidates) {
    try {
      return await CharsetConverter.decode(encoding, bytes);
    } on Exception {
      continue;
    }
  }
  return _decodeAttachmentTextWithDartCodecs(bytes);
}

String _decodeAttachmentTextWithDartCodecs(Uint8List bytes) {
  final utf16 = _decodeUtf16WithBom(bytes) ?? _decodeLikelyUtf16(bytes);
  if (utf16 != null) {
    return utf16;
  }
  try {
    return const Utf8Decoder().convert(bytes);
  } on FormatException {
    return const Latin1Decoder().convert(bytes);
  }
}

String? _decodeUtf16WithBom(Uint8List bytes) {
  if (bytes.length < 2) {
    return null;
  }
  if (bytes[0] == 0xff && bytes[1] == 0xfe) {
    return _decodeUtf16(bytes, littleEndian: true, offset: 2);
  }
  if (bytes[0] == 0xfe && bytes[1] == 0xff) {
    return _decodeUtf16(bytes, littleEndian: false, offset: 2);
  }
  return null;
}

String? _decodeLikelyUtf16(Uint8List bytes) {
  if (bytes.length < 4) {
    return null;
  }
  final sampleLength = math.min(bytes.length - bytes.length.remainder(2), 128);
  final pairs = sampleLength ~/ 2;
  var evenNulls = 0;
  var oddNulls = 0;
  for (var i = 0; i < sampleLength; i += 2) {
    if (bytes[i] == 0) {
      evenNulls++;
    }
    if (bytes[i + 1] == 0) {
      oddNulls++;
    }
  }
  if (oddNulls > pairs ~/ 2) {
    return _decodeUtf16(bytes, littleEndian: true);
  }
  if (evenNulls > pairs ~/ 2) {
    return _decodeUtf16(bytes, littleEndian: false);
  }
  return null;
}

String _decodeUtf16(
  Uint8List bytes, {
  required bool littleEndian,
  int offset = 0,
}) {
  final codeUnits = <int>[];
  for (var i = offset; i + 1 < bytes.length; i += 2) {
    final codeUnit = littleEndian
        ? bytes[i] | (bytes[i + 1] << 8)
        : (bytes[i] << 8) | bytes[i + 1];
    codeUnits.add(codeUnit);
  }
  return String.fromCharCodes(codeUnits);
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
        final metadataHeight = sizing.menuItemHeight * 2;
        final previewMaxHeight = math.max(
          0.0,
          maxHeight - spacing.s - metadataHeight - spacing.s - actionRowHeight,
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
                width: maxWidth,
                child: AttachmentPreviewMetadataSummary(
                  attachment: data.attachment,
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

class AttachmentPreviewActionRow extends StatefulWidget {
  const AttachmentPreviewActionRow({
    super.key,
    required this.closeTooltip,
    required this.actions,
    this.showClose = true,
  });

  final String closeTooltip;
  final List<AttachmentPreviewDialogAction> actions;
  final bool showClose;

  @override
  State<AttachmentPreviewActionRow> createState() =>
      _AttachmentPreviewActionRowState();
}

class _AttachmentPreviewActionRowState
    extends State<AttachmentPreviewActionRow> {
  int? _activeActionIndex;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colorScheme;
    final ghostColors = AttachmentPreviewGhostColors.resolve(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in widget.actions.asMap().entries) ...[
          if (action.key > 0) SizedBox(width: spacing.xs),
          AxiIconButton.ghost(
            iconData: action.value.iconData,
            tooltip: action.value.tooltip,
            color: action.value.destructive
                ? colors.destructive
                : ghostColors.foreground,
            backgroundColor: ghostColors.background,
            loading: _activeActionIndex == action.key,
            onPressed: action.value.enabled && _activeActionIndex == null
                ? () => _runAction(action.key, action.value)
                : null,
          ),
        ],
        if (widget.showClose) ...[
          if (widget.actions.isNotEmpty) SizedBox(width: spacing.xs),
          AxiIconButton.ghost(
            iconData: LucideIcons.x,
            tooltip: widget.closeTooltip,
            color: ghostColors.foreground,
            backgroundColor: ghostColors.background,
            onPressed: _activeActionIndex == null
                ? () => Navigator.of(context).pop()
                : null,
          ),
        ],
      ],
    );
  }

  void _runAction(int index, AttachmentPreviewDialogAction action) {
    final result = action.onPressed(context);
    if (result is! Future<void>) return;
    if (mounted) {
      setState(() {
        _activeActionIndex = index;
      });
    }
    unawaited(
      result.whenComplete(() {
        if (!mounted) return;
        setState(() {
          _activeActionIndex = null;
        });
      }),
    );
  }
}

class AttachmentPreviewMetadataSummary extends StatelessWidget {
  const AttachmentPreviewMetadataSummary({super.key, required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final ghostColors = AttachmentPreviewGhostColors.resolve(context);
    final spacing = context.spacing;
    final sizeLabel = _formatAttachmentPreviewSize(
      context,
      attachment.sizeBytes,
    );
    final mimeType = attachment.mimeType?.trim();
    final detailText = mimeType == null || mimeType.isEmpty
        ? sizeLabel
        : '$sizeLabel - $mimeType';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sanitizeUnicodeControls(attachment.fileName).value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.small.copyWith(
            color: ghostColors.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: spacing.xxs),
        Text(
          detailText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.small.copyWith(
            color: ghostColors.foreground,
          ),
        ),
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
      AttachmentPreviewKind.video => AttachmentVideoPreviewContent(
        data: data,
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

class AttachmentVideoPreviewContent extends StatefulWidget {
  const AttachmentVideoPreviewContent({
    super.key,
    required this.data,
    required this.maxWidth,
    required this.maxHeight,
  });

  final AttachmentPreviewData data;
  final double maxWidth;
  final double maxHeight;

  @override
  State<AttachmentVideoPreviewContent> createState() =>
      _AttachmentVideoPreviewContentState();
}

class _AttachmentVideoPreviewContentState
    extends State<AttachmentVideoPreviewContent> {
  VideoPlayerController? _controller;
  var _initFailed = false;
  var _videoInitGeneration = 0;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant AttachmentVideoPreviewContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.file.path == widget.data.file.path &&
        oldWidget.data.attachment.metadataId ==
            widget.data.attachment.metadataId) {
      return;
    }
    _resetController();
    _initializeVideo();
  }

  @override
  void dispose() {
    _resetController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initFailed) {
      return AttachmentUnsupportedPreviewContent(
        fileName: widget.data.attachment.fileName,
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
      );
    }

    final colors = context.colorScheme;
    final controller = _controller;
    final ghostColors = AttachmentPreviewGhostColors.resolve(context);
    final targetSize = AttachmentPreviewSize(
      intrinsicSize: _videoIntrinsicSize(controller),
      maxWidth: widget.maxWidth,
      maxHeight: widget.maxHeight,
      fallbackAspectRatio: 16 / 9,
    ).resolve(context);
    return SizedBox(
      width: targetSize.width,
      height: targetSize.height,
      child: AxiModalSurface(
        backgroundColor: colors.card,
        padding: EdgeInsets.zero,
        child: controller == null
            ? Center(child: AxiProgressIndicator(color: colors.primary))
            : ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (value.isInitialized)
                        VideoPlayer(controller)
                      else
                        Center(
                          child: AxiProgressIndicator(color: colors.primary),
                        ),
                      if (value.isInitialized)
                        Center(
                          child: AxiIconButton.ghost(
                            iconData: value.isPlaying
                                ? LucideIcons.pause
                                : LucideIcons.play,
                            tooltip: context.l10n.chatAttachmentPreview,
                            color: ghostColors.foreground,
                            backgroundColor: ghostColors.background,
                            onPressed: _togglePlayback,
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Future<void> _initializeVideo() async {
    final generation = ++_videoInitGeneration;
    _initFailed = false;
    if (!supportsAttachmentVideoPlayback) {
      _markInitFailed(generation);
      return;
    }
    final guardKey = _attachmentPreviewVideoGuardKey(widget.data);
    if (!MediaDecodeGuard.instance.allowAttempt(guardKey)) {
      _markInitFailed(generation);
      return;
    }
    final file = widget.data.file;
    if (!await file.exists()) {
      _markInitFailed(generation);
      return;
    }
    if (!_isActiveVideoInit(generation)) return;
    if (!_isVideoMetadataAllowed(widget.data.attachment)) {
      _markInitFailed(generation);
      return;
    }
    final length = await _safeFileLength(file);
    if (!_isActiveVideoInit(generation)) return;
    if (length == null ||
        length < _attachmentVideoMinBytes ||
        length > _attachmentVideoPreviewMaxBytes) {
      _markInitFailed(generation);
      return;
    }

    final controller = VideoPlayerController.file(file);
    _controller = controller;
    try {
      await controller.initialize().timeout(_attachmentVideoInitTimeout);
      if (!_isActiveVideoController(controller, generation)) return;
      if (!_isVideoFrameAllowed(controller.value.size)) {
        _disposeVideoController(controller);
        MediaDecodeGuard.instance.registerFailure(guardKey);
        _markInitFailed(generation);
        return;
      }
      MediaDecodeGuard.instance.registerSuccess(guardKey);
      setState(() {});
    } on Exception {
      if (!_isActiveVideoController(controller, generation)) return;
      _disposeVideoController(controller);
      MediaDecodeGuard.instance.registerFailure(guardKey);
      _markInitFailed(generation);
    }
  }

  Future<int?> _safeFileLength(File file) async {
    try {
      return await file.length();
    } on Exception {
      return null;
    }
  }

  bool _isVideoMetadataAllowed(Attachment attachment) {
    if (attachment.sizeBytes > _attachmentVideoPreviewMaxBytes) {
      return false;
    }
    final width = attachment.width;
    final height = attachment.height;
    if (width == null || height == null) return true;
    if (width < _attachmentVideoMinDimensionPixels ||
        height < _attachmentVideoMinDimensionPixels) {
      return true;
    }
    return width * height <= _attachmentVideoMaxPixels;
  }

  bool _isVideoFrameAllowed(Size size) {
    final width = size.width;
    final height = size.height;
    if (width < _attachmentVideoMinDimension ||
        height < _attachmentVideoMinDimension) {
      return false;
    }
    return width * height <= _attachmentVideoMaxPixels.toDouble();
  }

  Size? _videoIntrinsicSize(VideoPlayerController? controller) {
    final controllerValue = controller?.value;
    final controllerSize = controllerValue?.size;
    if (controllerSize != null &&
        controllerSize.width > 0 &&
        controllerSize.height > 0) {
      return controllerSize;
    }
    final width = widget.data.attachment.width;
    final height = widget.data.attachment.height;
    if (width != null && height != null && width > 0 && height > 0) {
      return Size(width.toDouble(), height.toDouble());
    }
    return null;
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  void _markInitFailed(int generation) {
    if (generation != _videoInitGeneration) return;
    if (!mounted) {
      _initFailed = true;
      return;
    }
    setState(() {
      _initFailed = true;
    });
  }

  bool _isActiveVideoInit(int generation) =>
      mounted && generation == _videoInitGeneration;

  bool _isActiveVideoController(
    VideoPlayerController controller,
    int generation,
  ) => _isActiveVideoInit(generation) && identical(_controller, controller);

  void _disposeVideoController(VideoPlayerController controller) {
    controller.dispose();
    if (identical(_controller, controller)) {
      _controller = null;
    }
  }

  void _resetController() {
    _videoInitGeneration++;
    final controller = _controller;
    if (controller == null) return;
    controller.dispose();
    _controller = null;
    _initFailed = false;
  }
}

String _attachmentPreviewVideoGuardKey(AttachmentPreviewData data) {
  final metadataId = data.attachment.metadataId?.trim();
  if (metadataId != null && metadataId.isNotEmpty) {
    return '$_attachmentPreviewDecodeGuardPrefix$metadataId';
  }
  return '$_attachmentPreviewDecodeGuardPrefix${data.file.path}';
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

String _formatAttachmentPreviewSize(BuildContext context, int bytes) {
  if (bytes <= 0) return context.l10n.chatAttachmentUnknownSize;
  final l10n = context.l10n;
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

class AttachmentPreviewSize {
  const AttachmentPreviewSize({
    required this.intrinsicSize,
    required this.maxWidth,
    required this.maxHeight,
    this.fallbackAspectRatio,
  });

  final Size? intrinsicSize;
  final double maxWidth;
  final double maxHeight;
  final double? fallbackAspectRatio;

  Size resolve(BuildContext context) {
    final cappedWidth = math.max(0.0, maxWidth);
    final cappedHeight = math.max(0.0, maxHeight);
    final size = intrinsicSize;
    if (size == null || size.width <= 0 || size.height <= 0) {
      final width = math.min(cappedWidth, context.sizing.dialogMaxWidth);
      final aspectRatio = fallbackAspectRatio;
      if (aspectRatio != null && aspectRatio > 0 && aspectRatio.isFinite) {
        var fallbackWidth = width;
        var fallbackHeight = fallbackWidth / aspectRatio;
        if (fallbackHeight > cappedHeight) {
          fallbackHeight = cappedHeight;
          fallbackWidth = fallbackHeight * aspectRatio;
        }
        return Size(fallbackWidth, fallbackHeight);
      }
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
