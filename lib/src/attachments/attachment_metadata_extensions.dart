import 'package:axichat/src/storage/models.dart';

const List<String> _attachmentImageExtensions = <String>[
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
  '.heic',
];

const List<String> _attachmentVideoExtensions = <String>[
  '.mp4',
  '.mov',
  '.m4v',
  '.webm',
  '.mkv',
  '.avi',
  '.mpeg',
  '.mpg',
  '.3gp',
  '.3gpp',
];

enum AttachmentMediaKind {
  image,
  video,
  file,
}

extension AttachmentMetadataKind on FileMetadataData {
  bool get isImage {
    final mime = mimeType?.toLowerCase();
    if (mime?.startsWith('image/') ?? false) return true;
    final name = filename.toLowerCase();
    return _attachmentImageExtensions.any(name.endsWith);
  }

  bool get isVideo {
    final mime = mimeType?.toLowerCase();
    if (mime?.startsWith('video/') ?? false) return true;
    final name = filename.toLowerCase();
    return _attachmentVideoExtensions.any(name.endsWith);
  }

  AttachmentMediaKind get mediaKind {
    if (isImage) return AttachmentMediaKind.image;
    if (isVideo) return AttachmentMediaKind.video;
    return AttachmentMediaKind.file;
  }

  String get normalizedFilename => filename.trim().toLowerCase();
}
