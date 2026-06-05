import 'package:axichat/src/chat/models/chat_timeline_projection.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('previewTextForMessage', () {
    test('uses attachment fallback when message text is empty', () {
      const message = Message(
        stanzaID: 'stanza-1',
        senderJid: 'sender@example.com',
        chatJid: 'chat@example.com',
        fileMetadataID: 'file-1',
      );

      expect(
        previewTextForMessage(message, attachmentPreviewFallback: 'photo.jpg'),
        'photo.jpg',
      );
    });

    test('keeps real message text before attachment fallback', () {
      const message = Message(
        stanzaID: 'stanza-1',
        senderJid: 'sender@example.com',
        chatJid: 'chat@example.com',
        body: 'caption',
        fileMetadataID: 'file-1',
      );

      expect(
        previewTextForMessage(message, attachmentPreviewFallback: 'photo.jpg'),
        'caption',
      );
    });
  });
}
