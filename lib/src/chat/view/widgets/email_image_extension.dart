import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:axichat/src/common/network_safety.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mime/mime.dart';

const Duration _emailImageDownloadTimeout = Duration(seconds: 8);
const Duration _emailImageDecodeTimeout = Duration(seconds: 2);
const int _emailImageMaxBytes = 4 * 1024 * 1024;
const int _emailImageMaxPixels = 16 * 1024 * 1024;
const int _emailImageMaxFrames = 60;
const int _emailImageMinDimension = 1;
const int _emailImageMaxRedirects = 3;
const double _emailImageLoadingSize = 24.0;
const double _emailImageLoadingStroke = 2.0;
const String _emailImageMimePrefix = 'image/';
const String _emailImageMimeDetectPlaceholder = 'email-image';
const String _emailImageHttpsScheme = 'https';
const Set<String> _emailImageAllowedSchemes = <String>{
  _emailImageHttpsScheme,
};

/// Creates a flutter_html extension that blocks or allows external images.
///
/// When [shouldLoad] is false, displays a placeholder that can be tapped
/// to trigger [onLoadRequested].
TagExtension createEmailImageExtension({
  required bool shouldLoad,
  VoidCallback? onLoadRequested,
}) {
  return TagExtension(
    tagsToExtend: {'img'},
    builder: (extensionContext) {
      final src = extensionContext.attributes['src'];
      final uri = src == null || src.isEmpty ? null : _safeEmailImageUri(src);
      if (shouldLoad) {
        if (uri == null) {
          return const EmailImagePlaceholder(isError: true);
        }
        return EmailImageLoader(uri: uri);
      }
      if (uri == null) {
        return const EmailImagePlaceholder();
      }
      return EmailImagePlaceholder(onTap: onLoadRequested);
    },
  );
}

class EmailImageLoader extends StatefulWidget {
  const EmailImageLoader({super.key, required this.uri});

  final Uri uri;

  @override
  State<EmailImageLoader> createState() => _EmailImageLoaderState();
}

class _EmailImageLoaderState extends State<EmailImageLoader> {
  late Future<Uint8List?> _future = _downloadEmailImageBytes(widget.uri);

  @override
  void didUpdateWidget(covariant EmailImageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _future = _downloadEmailImageBytes(widget.uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: _emailImageLoadingSize,
            height: _emailImageLoadingSize,
            child: CircularProgressIndicator(
              strokeWidth: _emailImageLoadingStroke,
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const EmailImagePlaceholder(isError: true);
        }
        return Image.memory(
          bytes,
          errorBuilder: (context, error, stackTrace) {
            return const EmailImagePlaceholder(isError: true);
          },
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

Future<Uint8List?> _downloadEmailImageBytes(Uri uri) async {
  final safeHost = await isSafeHostForRemoteConnection(uri.host)
      .timeout(_emailImageDownloadTimeout);
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
      final response =
          await request.close().timeout(_emailImageDownloadTimeout);
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
      final allowed = await _passesEmailImageSafetyChecks(bytes);
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

Future<bool> _passesEmailImageSafetyChecks(Uint8List bytes) async {
  try {
    final codec =
        await ui.instantiateImageCodec(bytes).timeout(_emailImageDecodeTimeout);
    try {
      if (codec.frameCount <= 0 || codec.frameCount > _emailImageMaxFrames) {
        return false;
      }
      final frame = await codec.getNextFrame().timeout(
            _emailImageDecodeTimeout,
          );
      final image = frame.image;
      try {
        final width = image.width;
        final height = image.height;
        if (width < _emailImageMinDimension ||
            height < _emailImageMinDimension) {
          return false;
        }
        final pixelCount = width * height;
        if (pixelCount > _emailImageMaxPixels) {
          return false;
        }
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
    return true;
  } on Exception {
    return false;
  }
}

bool _isRedirectStatusCode(int statusCode) => switch (statusCode) {
      HttpStatus.movedPermanently ||
      HttpStatus.found ||
      HttpStatus.seeOther ||
      HttpStatus.temporaryRedirect ||
      HttpStatus.permanentRedirect =>
        true,
      _ => false,
    };

/// Placeholder widget shown when external images are blocked.
class EmailImagePlaceholder extends StatelessWidget {
  const EmailImagePlaceholder({
    super.key,
    this.onTap,
    this.isError = false,
  });

  final VoidCallback? onTap;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.broken_image_outlined : Icons.image_outlined,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              isError ? 'Image failed' : 'Image blocked',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
