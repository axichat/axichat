import 'dart:io';

import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class EmailAttachmentOptimizer {
  const EmailAttachmentOptimizer._();

  static const _maxDimension = 2048;
  static const _jpegQuality = 82;

  static Future<EmailAttachment> optimize(EmailAttachment attachment) async {
    if (!attachment.isImage || attachment.isGif) {
      return attachment;
    }
    final file = File(attachment.path);
    if (!await file.exists()) {
      return attachment;
    }
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return attachment;
      }
      final oriented = img.bakeOrientation(decoded);
      final resized = _resizeIfNeeded(oriented);
      final encodeAsJpeg = !resized.hasAlpha;
      final encodedBytes = encodeAsJpeg
          ? img.encodeJpg(resized, quality: _jpegQuality)
          : img.encodePng(resized, level: 6);
      final tempPath = await _writeOptimizedFile(
        bytes: encodedBytes,
        extension: encodeAsJpeg ? '.jpg' : p.extension(attachment.fileName),
      );
      final sanitizedName = encodeAsJpeg
          ? '${p.basenameWithoutExtension(attachment.fileName)}.jpg'
          : attachment.fileName;
      final mimeType =
          encodeAsJpeg ? 'image/jpeg' : (attachment.mimeType ?? 'image/png');
      return attachment.copyWith(
        path: tempPath,
        fileName: sanitizedName,
        mimeType: mimeType,
        sizeBytes: encodedBytes.length,
        width: resized.width,
        height: resized.height,
      );
    } on Exception {
      return attachment;
    }
  }

  static img.Image _resizeIfNeeded(img.Image image) {
    final maxSide = image.width > image.height ? image.width : image.height;
    if (maxSide <= _maxDimension) {
      return image;
    }
    return img.copyResize(
      image,
      width: image.width >= image.height ? _maxDimension : null,
      height: image.height > image.width ? _maxDimension : null,
      interpolation: img.Interpolation.cubic,
    );
  }

  static Future<String> _writeOptimizedFile({
    required List<int> bytes,
    required String extension,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final directory = Directory(p.join(tempDir.path, 'email_attachments'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final fileName =
        'attachment_${DateTime.now().microsecondsSinceEpoch}$extension';
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
