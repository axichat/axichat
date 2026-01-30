part of 'share_intent_cubit.dart';

class ShareAttachmentPayload {
  const ShareAttachmentPayload({required this.path, required this.type});

  final String path;
  final SharedAttachmentType type;
}

extension SharedAttachmentTypeExtensions on SharedAttachmentType {
  bool get isImage => this == SharedAttachmentType.image;

  bool get isVideo => this == SharedAttachmentType.video;

  bool get isAudio => this == SharedAttachmentType.audio;

  bool get isFile => this == SharedAttachmentType.file;

  String get mimeTypeFallback => switch (this) {
        SharedAttachmentType.image => _sharedAttachmentImageMimeType,
        SharedAttachmentType.video => _sharedAttachmentVideoMimeType,
        SharedAttachmentType.audio => _sharedAttachmentAudioMimeType,
        SharedAttachmentType.file => _sharedAttachmentFileMimeType,
      };
}

class SharePayload {
  const SharePayload({
    this.text,
    this.attachments = const <ShareAttachmentPayload>[],
  });

  final String? text;
  final List<ShareAttachmentPayload> attachments;

  bool get hasText => text != null && text!.isNotEmpty;

  bool get hasAttachments => attachments.isNotEmpty;
}

class ShareIntentState {
  const ShareIntentState._(this.payload);

  const ShareIntentState.idle() : this._(null);

  const ShareIntentState.ready(SharePayload payload) : this._(payload);

  final SharePayload? payload;

  bool get hasPayload => payload != null;
}
