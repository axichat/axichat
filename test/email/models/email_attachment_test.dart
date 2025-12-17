import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:test/test.dart';

void main() {
  group('EmailAttachment', () {
    test('treats common image extensions as images when mimeType is missing',
        () {
      const attachment = EmailAttachment(
        path: '/tmp/photo.png',
        fileName: 'photo.png',
        sizeBytes: 1,
      );

      expect(attachment.isImage, isTrue);
      expect(attachment.isGif, isFalse);
    });

    test('falls back to path extension when fileName lacks an extension', () {
      const attachment = EmailAttachment(
        path: '/tmp/photo.jpg',
        fileName: 'photo',
        sizeBytes: 1,
      );

      expect(attachment.isImage, isTrue);
    });

    test('detects gifs by extension when mimeType is missing', () {
      const attachment = EmailAttachment(
        path: '/tmp/anim.gif',
        fileName: 'anim.gif',
        sizeBytes: 1,
      );

      expect(attachment.isImage, isTrue);
      expect(attachment.isGif, isTrue);
    });
  });
}
