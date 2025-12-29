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

const List<String> _attachmentArchiveExtensions = <String>[
  '.zip',
  '.rar',
  '.7z',
  '.tar',
  '.gz',
  '.tgz',
  '.bz2',
  '.xz',
  '.jar',
];

const Set<String> _attachmentArchiveMimeTypes = <String>{
  'application/zip',
  'application/x-zip-compressed',
  'application/vnd.rar',
  'application/x-rar-compressed',
  'application/x-7z-compressed',
  'application/x-tar',
  'application/gzip',
  'application/x-gzip',
  'application/x-bzip2',
  'application/x-xz',
  'application/java-archive',
};

enum AttachmentMediaKind {
  image,
  video,
  file,
}

enum AttachmentDownloadCategory {
  image,
  video,
  document,
  archive,
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

  bool get isArchive {
    final mime = mimeType?.toLowerCase();
    if (mime != null && _attachmentArchiveMimeTypes.contains(mime)) {
      return true;
    }
    final name = filename.toLowerCase();
    return _attachmentArchiveExtensions.any(name.endsWith);
  }

  AttachmentMediaKind get mediaKind {
    if (isImage) return AttachmentMediaKind.image;
    if (isVideo) return AttachmentMediaKind.video;
    return AttachmentMediaKind.file;
  }

  AttachmentDownloadCategory get downloadCategory {
    if (isImage) return AttachmentDownloadCategory.image;
    if (isVideo) return AttachmentDownloadCategory.video;
    if (isArchive) return AttachmentDownloadCategory.archive;
    return AttachmentDownloadCategory.document;
  }

  String get normalizedFilename => filename.trim().toLowerCase();
}
