import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('attachment auto-download policy', () {
    final chat = Chat.fromJid('peer@example.com');
    const image = FileMetadataData(
      id: 'image',
      filename: 'photo.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 1024,
    );

    bool policyAllows({
      Chat? policyChat,
      FileMetadataData metadata = image,
      bool imagesEnabled = false,
      bool videosEnabled = false,
      bool documentsEnabled = false,
      bool archivesEnabled = false,
      bool chatBlocked = false,
      bool requireKnownSize = false,
      int maxBytes = maxAttachmentAutoDownloadBytes,
    }) {
      return allowsAttachmentAutoDownload(
        chat: policyChat ?? chat,
        metadata: metadata,
        imagesEnabled: imagesEnabled,
        videosEnabled: videosEnabled,
        documentsEnabled: documentsEnabled,
        archivesEnabled: archivesEnabled,
        chatBlocked: chatBlocked,
        requireKnownSize: requireKnownSize,
        maxBytes: maxBytes,
      );
    }

    test('inherits global category switches when chat has no override', () {
      expect(policyAllows(), isFalse);
      expect(policyAllows(imagesEnabled: true), isTrue);
    });

    test('chat override can allow or block low-risk downloads', () {
      expect(
        policyAllows(
          policyChat: chat.copyWith(
            attachmentAutoDownload: AttachmentAutoDownload.allowed,
          ),
        ),
        isTrue,
      );
      expect(
        policyAllows(
          policyChat: chat.copyWith(
            attachmentAutoDownload: AttachmentAutoDownload.blocked,
          ),
          imagesEnabled: true,
        ),
        isFalse,
      );
    });

    test(
      'self-equivalent downloads still honor inherited global categories',
      () {
        expect(policyAllows(), isFalse);
        expect(policyAllows(imagesEnabled: true), isTrue);
      },
    );

    test('self-equivalent downloads still honor per-chat override', () {
      expect(
        policyAllows(
          policyChat: chat.copyWith(
            attachmentAutoDownload: AttachmentAutoDownload.allowed,
          ),
        ),
        isTrue,
      );
      expect(
        policyAllows(
          policyChat: chat.copyWith(
            attachmentAutoDownload: AttachmentAutoDownload.blocked,
          ),
          imagesEnabled: true,
        ),
        isFalse,
      );
    });

    test(
      'never allows spam, blocked, high-risk, oversized, or unknown email',
      () {
        const executable = FileMetadataData(
          id: 'executable',
          filename: 'setup.exe',
          mimeType: 'application/x-msdownload',
          sizeBytes: 1024,
        );
        const oversized = FileMetadataData(
          id: 'oversized',
          filename: 'photo.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: maxAttachmentAutoDownloadBytes + 1,
        );
        const unknownSize = FileMetadataData(
          id: 'unknown-size',
          filename: 'photo.jpg',
          mimeType: 'image/jpeg',
        );
        final allowedChat = chat.copyWith(
          attachmentAutoDownload: AttachmentAutoDownload.allowed,
        );

        expect(
          policyAllows(policyChat: allowedChat.copyWith(spam: true)),
          isFalse,
        );
        expect(
          policyAllows(policyChat: allowedChat, chatBlocked: true),
          isFalse,
        );
        expect(
          policyAllows(policyChat: allowedChat, metadata: executable),
          isFalse,
        );
        expect(
          policyAllows(policyChat: allowedChat, metadata: oversized),
          isFalse,
        );
        expect(
          policyAllows(
            policyChat: allowedChat,
            metadata: unknownSize,
            requireKnownSize: true,
          ),
          isFalse,
        );
        expect(
          policyAllows(policyChat: allowedChat, metadata: unknownSize),
          isTrue,
        );
      },
    );
  });
}
