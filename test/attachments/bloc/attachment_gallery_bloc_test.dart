import 'dart:async';

import 'package:axichat/src/attachments/bloc/attachment_gallery_bloc.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  test(
    'received gallery entries honor global auto-download categories',
    () async {
      final controller = StreamController<List<AttachmentGalleryItem>>();
      final xmppService = _MockXmppService();
      when(
        () => xmppService.attachmentGalleryStream(chatJid: null),
      ).thenAnswer((_) => controller.stream);
      when(() => xmppService.myJid).thenReturn('me@example.com');
      when(() => xmppService.autoDownloadImages).thenReturn(true);
      when(() => xmppService.autoDownloadVideos).thenReturn(false);
      when(() => xmppService.autoDownloadDocuments).thenReturn(false);
      when(() => xmppService.autoDownloadArchives).thenReturn(false);

      final bloc = AttachmentGalleryBloc(
        xmppService: xmppService,
        showChatLabel: true,
      );
      addTearDown(() async {
        await bloc.close();
        await controller.close();
      });

      final entriesUpdated = bloc.stream.firstWhere(
        (state) => state.entries.length == 2,
      );
      final chat = Chat.fromJid('peer@example.com');
      controller.add([
        AttachmentGalleryItem(
          message: const Message(
            stanzaID: 'image-stanza',
            senderJid: 'peer@example.com',
            chatJid: 'peer@example.com',
          ),
          metadata: const FileMetadataData(
            id: '',
            filename: 'photo.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 1024,
          ),
          chat: chat,
        ),
        AttachmentGalleryItem(
          message: const Message(
            stanzaID: 'document-stanza',
            senderJid: 'peer@example.com',
            chatJid: 'peer@example.com',
          ),
          metadata: const FileMetadataData(
            id: '',
            filename: 'notes.txt',
            mimeType: 'text/plain',
            sizeBytes: 1024,
          ),
          chat: chat,
        ),
      ]);

      final state = await entriesUpdated;

      expect(
        state.entries
            .firstWhere((entry) => entry.item.metadata.filename == 'photo.jpg')
            .allowByTrust,
        isTrue,
      );
      expect(
        state.entries
            .firstWhere((entry) => entry.item.metadata.filename == 'notes.txt')
            .allowByTrust,
        isFalse,
      );
    },
  );
}

class _MockXmppService extends Mock implements XmppService {}
