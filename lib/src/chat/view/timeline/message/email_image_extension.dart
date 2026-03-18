// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/media_decode_safety.dart';
import 'package:axichat/src/common/network_safety.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mime/mime.dart';

const Duration _emailImageDownloadTimeout = Duration(seconds: 15);
const Duration _emailImageDecodeTimeout = Duration(seconds: 2);
const int _emailImageMaxBytes = 4 * 1024 * 1024;
const int _emailImageMaxPixels = 16 * 1024 * 1024;
const int _emailImageMaxFrames = 60;
const int _emailImageMinDimension = 1;
const int _emailImageMaxRedirects = 3;
const String _emailImageMimePrefix = 'image/';
const String _emailImageMimeDetectPlaceholder = 'email-image';
const String _emailImageHttpsScheme = 'https';
const String _emailImageDataScheme = 'data';
const Set<String> _emailImageAllowedSchemes = <String>{_emailImageHttpsScheme};
const ImageDecodeLimits _emailImageDecodeLimits = ImageDecodeLimits(
  maxBytes: _emailImageMaxBytes,
  maxPixels: _emailImageMaxPixels,
  maxFrames: _emailImageMaxFrames,
  minDimension: _emailImageMinDimension,
  decodeTimeout: _emailImageDecodeTimeout,
);
final _cachedEmailImageBytes = <String, Uint8List>{};
final _pendingEmailImageDownloads = <String, Future<Uint8List?>>{};

/// Creates a flutter_html extension for inline email images.
TagExtension createEmailImageExtension({required bool shouldLoad}) {
  return TagExtension(
    tagsToExtend: {'img'},
    builder: (extensionContext) {
      final src = extensionContext.attributes['src'];
      if (src == null || src.trim().isEmpty) {
        return const SizedBox.shrink();
      }
      return _EmailHtmlImage(
        src: src,
        shouldLoad: shouldLoad,
        layout: _emailImageLayoutFromAttributes(extensionContext.attributes),
      );
    },
  );
}

List<HtmlExtension> createEmailHtmlExtensions({
  required bool shouldLoadImages,
}) {
  return <HtmlExtension>[
    createEmailImageExtension(shouldLoad: shouldLoadImages),
  ];
}

Map<String, Style> createEmailHtmlStyles({
  required double fallbackFontSize,
  Color? textColor,
  Color? linkColor,
}) {
  Style inlineStyle({
    Color? color,
    FontSize? fontSize,
    TextDecoration? textDecoration,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
  }) => Style(
    color: color,
    fontSize: fontSize,
    textDecoration: textDecoration,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    verticalAlign: VerticalAlign.bottom,
  );

  Style blockStyle({Color? color, FontSize? fontSize}) => Style(
    margin: Margins.zero,
    padding: HtmlPaddings.zero,
    color: color,
    fontSize: fontSize,
  );

  final bodyStyle = blockStyle(
    color: textColor,
    fontSize: FontSize(fallbackFontSize),
  );
  final quoteStyle = blockStyle(
    color: textColor,
    fontSize: FontSize(fallbackFontSize),
  ).copyWith(border: Border.fromBorderSide(BorderSide.none));
  final tableCellStyle = Style(
    color: textColor,
    fontSize: FontSize(fallbackFontSize),
    margin: Margins.zero,
    padding: HtmlPaddings.zero,
  );

  return <String, Style>{
    'html': bodyStyle,
    'body': bodyStyle,
    'p': bodyStyle,
    'div': bodyStyle,
    'span': inlineStyle(color: textColor, fontSize: FontSize(fallbackFontSize)),
    'blockquote': quoteStyle,
    'ul': bodyStyle,
    'ol': bodyStyle,
    'li': bodyStyle,
    'table': bodyStyle,
    'thead': tableCellStyle,
    'tbody': tableCellStyle,
    'tfoot': tableCellStyle,
    'tr': tableCellStyle,
    'td': tableCellStyle,
    'th': tableCellStyle,
    'h1': bodyStyle,
    'h2': bodyStyle,
    'h3': bodyStyle,
    'h4': bodyStyle,
    'h5': bodyStyle,
    'h6': bodyStyle,
    'strong': inlineStyle(
      color: textColor,
      fontSize: FontSize(fallbackFontSize),
      fontWeight: FontWeight.w700,
    ),
    'em': inlineStyle(
      color: textColor,
      fontSize: FontSize(fallbackFontSize),
      fontStyle: FontStyle.italic,
    ),
    'b': inlineStyle(
      color: textColor,
      fontSize: FontSize(fallbackFontSize),
      fontWeight: FontWeight.w700,
    ),
    'i': inlineStyle(
      color: textColor,
      fontSize: FontSize(fallbackFontSize),
      fontStyle: FontStyle.italic,
    ),
    'u': inlineStyle(
      color: textColor,
      fontSize: FontSize(fallbackFontSize),
      textDecoration: TextDecoration.underline,
    ),
    'img': inlineStyle(),
    'a': inlineStyle(
      color: linkColor,
      fontSize: FontSize(fallbackFontSize),
      textDecoration: TextDecoration.underline,
    ),
  };
}

class _EmailHtmlImage extends StatelessWidget {
  const _EmailHtmlImage({
    required this.src,
    required this.shouldLoad,
    required this.layout,
  });

  final String src;
  final bool shouldLoad;
  final _EmailImageLayoutSpec layout;

  @override
  Widget build(BuildContext context) {
    final embeddedBytes = _embeddedEmailImageBytes(src);
    if (embeddedBytes != null) {
      return _EmailEmbeddedImage(bytes: embeddedBytes, layout: layout);
    }
    final uri = _safeEmailImageUri(src);
    if (uri == null) {
      return const SizedBox.shrink();
    }
    if (!shouldLoad) {
      return const SizedBox.shrink();
    }
    return _EmailImageLoader(uri: uri, layout: layout);
  }
}

class _EmailImageLoader extends StatefulWidget {
  const _EmailImageLoader({required this.uri, required this.layout});

  final Uri uri;
  final _EmailImageLayoutSpec layout;

  @override
  State<_EmailImageLoader> createState() => _EmailImageLoaderState();
}

class _EmailImageLoaderState extends State<_EmailImageLoader> {
  late Future<Uint8List?> _future = _loadEmailImageBytes(widget.uri);

  @override
  void didUpdateWidget(covariant _EmailImageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _future = _loadEmailImageBytes(widget.uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AxiProgressIndicator();
        }
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const EmailImagePlaceholder(isError: true);
        }
        return _EmailHtmlImageFrame(
          layout: widget.layout,
          builder: (width, height) => Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return const EmailImagePlaceholder(isError: true);
            },
          ),
        );
      },
    );
  }
}

class _EmailEmbeddedImage extends StatefulWidget {
  const _EmailEmbeddedImage({required this.bytes, required this.layout});

  final Uint8List bytes;
  final _EmailImageLayoutSpec layout;

  @override
  State<_EmailEmbeddedImage> createState() => _EmailEmbeddedImageState();
}

class _EmailEmbeddedImageState extends State<_EmailEmbeddedImage> {
  late Future<Uint8List?> _future = _validateEmbeddedEmailImageBytes(
    widget.bytes,
  );

  @override
  void didUpdateWidget(covariant _EmailEmbeddedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes) {
      _future = _validateEmbeddedEmailImageBytes(widget.bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AxiProgressIndicator();
        }
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const EmailImagePlaceholder(isError: true);
        }
        return _EmailHtmlImageFrame(
          layout: widget.layout,
          builder: (width, height) => Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return const EmailImagePlaceholder(isError: true);
            },
          ),
        );
      },
    );
  }
}

class _EmailImageLayoutSpec {
  const _EmailImageLayoutSpec({
    this.widthPx,
    this.widthPercent,
    this.heightPx,
    this.heightPercent,
    this.maxWidthPx,
    this.maxWidthPercent,
  });

  final double? widthPx;
  final double? widthPercent;
  final double? heightPx;
  final double? heightPercent;
  final double? maxWidthPx;
  final double? maxWidthPercent;
}

class _EmailHtmlImageFrame extends StatelessWidget {
  const _EmailHtmlImageFrame({required this.layout, required this.builder});

  final _EmailImageLayoutSpec layout;
  final Widget Function(double? width, double? height) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = MediaQuery.sizeOf(context).width;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : fallbackWidth;
        final maxWidth =
            _resolveImageLength(
              pixels: layout.maxWidthPx,
              percent: layout.maxWidthPercent,
              availableWidth: availableWidth,
            ) ??
            availableWidth;
        final resolvedMaxWidth = math.min(availableWidth, maxWidth);
        final width = _resolveImageLength(
          pixels: layout.widthPx,
          percent: layout.widthPercent,
          availableWidth: availableWidth,
        );
        final height = _resolveImageLength(
          pixels: layout.heightPx,
          percent: layout.heightPercent,
          availableWidth: availableWidth,
        );
        final resolvedWidth = width == null
            ? null
            : math.min(width, resolvedMaxWidth);
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
          child: builder(resolvedWidth, height),
        );
      },
    );
  }
}

Uri? _safeEmailImageUri(String src) {
  final trimmed = src.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  final scheme = uri.scheme.trim().toLowerCase();
  if (!_emailImageAllowedSchemes.contains(scheme)) return null;
  if (uri.userInfo.trim().isNotEmpty) return null;
  if (uri.host.trim().isEmpty) return null;
  return uri;
}

Uint8List? _embeddedEmailImageBytes(String src) {
  final trimmed = src.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.scheme.trim().toLowerCase() != _emailImageDataScheme) {
    return null;
  }
  UriData? data;
  try {
    data = uri.data;
  } on FormatException {
    return null;
  }
  final mimeType = data?.mimeType.trim().toLowerCase() ?? '';
  if (!mimeType.startsWith(_emailImageMimePrefix)) {
    return null;
  }
  final bytes = data?.contentAsBytes();
  if (bytes == null || bytes.isEmpty || bytes.length > _emailImageMaxBytes) {
    return null;
  }
  return Uint8List.fromList(bytes);
}

Future<Uint8List?> _validateEmbeddedEmailImageBytes(Uint8List bytes) async {
  if (bytes.isEmpty || bytes.length > _emailImageMaxBytes) {
    return null;
  }
  final detectedMime = lookupMimeType(
    _emailImageMimeDetectPlaceholder,
    headerBytes: bytes,
  );
  if (detectedMime == null || !detectedMime.startsWith(_emailImageMimePrefix)) {
    return null;
  }
  final allowed = await isSafeImageBytes(bytes, _emailImageDecodeLimits);
  if (!allowed) {
    return null;
  }
  return bytes;
}

Future<Uint8List?> _loadEmailImageBytes(Uri uri) async {
  final cacheKey = uri.toString();
  final cached = _cachedEmailImageBytes[cacheKey];
  if (cached != null) {
    return cached;
  }
  final pending = _pendingEmailImageDownloads.putIfAbsent(
    cacheKey,
    () => _downloadEmailImageBytes(uri),
  );
  try {
    final bytes = await pending;
    if (bytes != null && bytes.isNotEmpty) {
      _cachedEmailImageBytes[cacheKey] = bytes;
    }
    return bytes;
  } finally {
    _pendingEmailImageDownloads.remove(cacheKey);
  }
}

Future<Uint8List?> _downloadEmailImageBytes(Uri uri) async {
  final safeHost = await isSafeHostForRemoteConnection(
    uri.host,
  ).timeout(_emailImageDownloadTimeout);
  if (!safeHost) return null;

  final client = HttpClient()..connectionTimeout = _emailImageDownloadTimeout;
  try {
    var redirects = 0;
    var current = uri;
    while (true) {
      final request =
          await client.getUrl(current).timeout(_emailImageDownloadTimeout)
            ..followRedirects = false
            ..maxRedirects = 0
            ..headers.removeAll(HttpHeaders.cookieHeader);
      final response = await request.close().timeout(
        _emailImageDownloadTimeout,
      );
      final statusCode = response.statusCode;

      if (_isRedirectStatusCode(statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.listen((_) {}).cancel();
        if (location == null || location.trim().isEmpty) {
          return null;
        }
        if (redirects >= _emailImageMaxRedirects) {
          return null;
        }
        final redirected = current.resolve(location.trim());
        final redirectedScheme = redirected.scheme.toLowerCase();
        if (!_emailImageAllowedSchemes.contains(redirectedScheme)) {
          return null;
        }
        final safeRedirect = await isSafeHostForRemoteConnection(
          redirected.host,
        ).timeout(_emailImageDownloadTimeout);
        if (!safeRedirect) {
          return null;
        }
        current = redirected;
        redirects += 1;
        continue;
      }

      final success = statusCode >= 200 && statusCode < 300;
      if (!success) {
        return null;
      }

      final responseLength = response.contentLength;
      if (responseLength != -1 && responseLength > _emailImageMaxBytes) {
        return null;
      }
      final bytes = await _readResponseBytes(response);
      if (bytes == null) return null;
      final detectedMime = lookupMimeType(
        _emailImageMimeDetectPlaceholder,
        headerBytes: bytes,
      );
      if (detectedMime == null ||
          !detectedMime.startsWith(_emailImageMimePrefix)) {
        return null;
      }
      final allowed = await isSafeImageBytes(bytes, _emailImageDecodeLimits);
      if (!allowed) {
        return null;
      }
      return bytes;
    }
  } finally {
    client.close(force: true);
  }
}

Future<Uint8List?> _readResponseBytes(HttpClientResponse response) async {
  final sink = BytesBuilder(copy: false);
  var received = 0;
  await for (final chunk in response.timeout(_emailImageDownloadTimeout)) {
    received += chunk.length;
    if (received > _emailImageMaxBytes) {
      return null;
    }
    sink.add(chunk);
  }
  return sink.takeBytes();
}

_EmailImageLayoutSpec _emailImageLayoutFromAttributes(
  Map<String, String> attributes,
) {
  final styles = _parseInlineStyleMap(attributes['style']);
  final widthValue = styles['width'] ?? attributes['width'];
  final heightValue = styles['height'] ?? attributes['height'];
  final maxWidthValue = styles['max-width'];
  return _EmailImageLayoutSpec(
    widthPx: _parsePixelLength(widthValue),
    widthPercent: _parsePercentLength(widthValue),
    heightPx: _parsePixelLength(heightValue),
    heightPercent: _parsePercentLength(heightValue),
    maxWidthPx: _parsePixelLength(maxWidthValue),
    maxWidthPercent: _parsePercentLength(maxWidthValue),
  );
}

Map<String, String> _parseInlineStyleMap(String? style) {
  final trimmed = style?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return const <String, String>{};
  }
  final map = <String, String>{};
  for (final declaration in trimmed.split(';')) {
    final separatorIndex = declaration.indexOf(':');
    if (separatorIndex <= 0) {
      continue;
    }
    final property = declaration
        .substring(0, separatorIndex)
        .trim()
        .toLowerCase();
    final value = declaration.substring(separatorIndex + 1).trim();
    if (property.isEmpty || value.isEmpty) {
      continue;
    }
    map[property] = value;
  }
  return map;
}

double? _parsePixelLength(String? value) {
  final trimmed = value?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final normalized = trimmed.endsWith('px')
      ? trimmed.substring(0, trimmed.length - 2).trim()
      : trimmed;
  return double.tryParse(normalized);
}

double? _parsePercentLength(String? value) {
  final trimmed = value?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty || !trimmed.endsWith('%')) {
    return null;
  }
  return double.tryParse(trimmed.substring(0, trimmed.length - 1).trim());
}

double? _resolveImageLength({
  required double? pixels,
  required double? percent,
  required double availableWidth,
}) {
  if (pixels != null && pixels > 0) {
    return pixels;
  }
  if (percent != null && percent > 0) {
    return availableWidth * (percent / 100);
  }
  return null;
}

bool _isRedirectStatusCode(int statusCode) => switch (statusCode) {
  HttpStatus.movedPermanently ||
  HttpStatus.found ||
  HttpStatus.seeOther ||
  HttpStatus.temporaryRedirect ||
  HttpStatus.permanentRedirect => true,
  _ => false,
};

/// Placeholder widget shown when external images are blocked.
class EmailImagePlaceholder extends StatefulWidget {
  const EmailImagePlaceholder({super.key, this.onTap, this.isError = false});

  final VoidCallback? onTap;
  final bool isError;

  @override
  State<EmailImagePlaceholder> createState() => _EmailImagePlaceholderState();
}

class _EmailImagePlaceholderState extends State<EmailImagePlaceholder> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final label = widget.isError
        ? context.l10n.chatEmailImageFailedLabel
        : context.l10n.chatEmailImageBlockedLabel;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(context.radii.squircle),
      side: context.borderSide,
    );
    final content = DecoratedBox(
      decoration: ShapeDecoration(color: colors.card, shape: shape),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.s,
          vertical: spacing.xs,
        ),
        child: Wrap(
          spacing: spacing.s,
          runSpacing: spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isError
                      ? Icons.broken_image_outlined
                      : Icons.image_outlined,
                  size: sizing.menuItemIconSize,
                  color: colors.mutedForeground,
                ),
                SizedBox(width: spacing.xs),
                Text(
                  label,
                  style: context.textTheme.small.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
            if (widget.onTap != null)
              AxiButton.outline(
                size: AxiButtonSize.sm,
                onPressed: widget.onTap,
                child: Text(context.l10n.commonShow),
              ),
          ],
        ),
      ),
    );
    return content;
  }
}
