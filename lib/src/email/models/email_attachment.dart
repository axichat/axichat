class EmailAttachment {
  const EmailAttachment({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    this.mimeType,
    this.width,
    this.height,
    this.caption,
    this.metadataId,
  });

  final String path;
  final String fileName;
  final int sizeBytes;
  final String? mimeType;
  final int? width;
  final int? height;
  final String? caption;
  final String? metadataId;

  EmailAttachment copyWith({
    String? path,
    String? fileName,
    int? sizeBytes,
    String? mimeType,
    int? width,
    int? height,
    String? caption,
    String? metadataId,
  }) =>
      EmailAttachment(
        path: path ?? this.path,
        fileName: fileName ?? this.fileName,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        mimeType: mimeType ?? this.mimeType,
        width: width ?? this.width,
        height: height ?? this.height,
        caption: caption ?? this.caption,
        metadataId: metadataId ?? this.metadataId,
      );

  bool get isImage =>
      mimeType != null && mimeType!.toLowerCase().startsWith('image/');

  bool get isGif => mimeType?.toLowerCase() == 'image/gif';

  bool get isVideo =>
      mimeType != null && mimeType!.toLowerCase().startsWith('video/');

  bool get isAudio =>
      mimeType != null && mimeType!.toLowerCase().startsWith('audio/');
}
