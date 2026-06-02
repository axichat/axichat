import 'package:axichat/src/chat/models/rfc_email_group.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildRfcEmailGroupsByMessageStanzaId', () {
    test('groups RFC email parts across Delta backing chats', () {
      const messages = [
        Message(
          stanzaID: 'dc-msg-1',
          senderJid: 'sender@example.com',
          chatJid: 'sender@example.com',
          body: 'First body',
          originID: 'shared@example.com',
          deltaAccountId: 1,
          deltaChatId: 10,
          deltaMsgId: 1,
        ),
        Message(
          stanzaID: 'dc-msg-2',
          senderJid: 'sender@example.com',
          chatJid: 'sender@example.com',
          fileMetadataID: 'attachment-1',
          originID: 'shared@example.com',
          deltaAccountId: 1,
          deltaChatId: 11,
          deltaMsgId: 2,
        ),
      ];

      final groups = buildRfcEmailGroupsByMessageStanzaId(
        messages: messages,
        attachmentsForMessage: (message) => message.fileMetadataID == null
            ? const []
            : [message.fileMetadataID!],
        bodyTextForMessage: (message) =>
            rfcEmailBodyText(message: message, resolvedHtmlBody: null),
        requireMeaningfulBody: false,
      );

      expect(groups['dc-msg-1'], same(groups['dc-msg-2']));
      expect(groups['dc-msg-1']?.messages, messages);
    });

    test('prefers authoritative RFC822 body over generated header text', () {
      const header = Message(
        stanzaID: 'header',
        senderJid: 'sender@example.com',
        chatJid: 'sender@example.com',
        body:
            'Date: Jan 1, 2024\n'
            'From: Sender <sender@example.com>\n'
            'To: Me <me@example.com>\n'
            'Subject: Photos\n\n'
            'Body',
        originID: 'shared@example.com',
        deltaAccountId: 1,
        deltaChatId: 10,
        deltaMsgId: 1,
      );
      const htmlBody = Message(
        stanzaID: 'html',
        senderJid: 'sender@example.com',
        chatJid: 'sender@example.com',
        body: 'Body',
        htmlBody: '<p>Body</p>',
        pseudoMessageData: {'emailRfc822Body': true},
        originID: 'shared@example.com',
        deltaAccountId: 1,
        deltaChatId: 10,
        deltaMsgId: 2,
      );

      final groups = buildRfcEmailGroupsByMessageStanzaId(
        messages: const [header, htmlBody],
        attachmentsForMessage: (_) => const [],
        bodyTextForMessage: (message) => rfcEmailBodyText(
          message: message,
          resolvedHtmlBody: message.htmlBody,
        ),
        isAuthoritativeBody: (message) => message.hasRfc822BodyContent,
        requireMeaningfulBody: false,
      );
      final group = groups[header.stanzaID]!;

      expect(group.leader, htmlBody);
      expect(group.bodySources, [htmlBody]);
      expect(group.shouldHideTimelineMessage(header), isTrue);
    });

    test(
      'anchors authoritative attachment body on first non-attachment row',
      () {
        const header = Message(
          stanzaID: 'header',
          senderJid: 'sender@example.com',
          chatJid: 'sender@example.com',
          body:
              'Date: Jan 1, 2024\n'
              'From: Sender <sender@example.com>\n'
              'To: Me <me@example.com>\n'
              'Subject: Photos',
          originID: 'shared@example.com',
          deltaAccountId: 1,
          deltaChatId: 10,
          deltaMsgId: 1,
        );
        const attachment = Message(
          stanzaID: 'attachment',
          senderJid: 'sender@example.com',
          chatJid: 'sender@example.com',
          body: 'Real body',
          htmlBody: '<p>Real body</p>',
          fileMetadataID: 'file-1',
          pseudoMessageData: {'emailRfc822Body': true},
          originID: 'shared@example.com',
          deltaAccountId: 1,
          deltaChatId: 10,
          deltaMsgId: 2,
        );

        final groups = buildRfcEmailGroupsByMessageStanzaId(
          messages: const [header, attachment],
          attachmentsForMessage: (message) => message.fileMetadataID == null
              ? const []
              : [message.fileMetadataID!],
          bodyTextForMessage: (message) => rfcEmailBodyText(
            message: message,
            resolvedHtmlBody: message.htmlBody,
          ),
          isAuthoritativeBody: (message) => message.hasRfc822BodyContent,
          requireMeaningfulBody: false,
        );
        final group = groups[header.stanzaID]!;

        expect(group.leader, header);
        expect(group.bodySources, [attachment]);
        expect(group.shouldSuppressTimelineText(attachment), isTrue);
      },
    );
  });

  group('rfcEmailBodyText', () {
    test('ignores generated email attachment captions', () {
      const message = Message(
        stanzaID: 'stanza-1',
        senderJid: 'sender@example.com',
        chatJid: 'chat@example.com',
        body: 'receipt.pdf (24 KB)',
        pseudoMessageData: {'emailAttachmentCaption': true},
      );

      expect(
        rfcEmailBodyText(message: message, resolvedHtmlBody: null),
        isEmpty,
      );
    });

    test('keeps real text that looks like an attachment label', () {
      const message = Message(
        stanzaID: 'stanza-1',
        senderJid: 'sender@example.com',
        chatJid: 'chat@example.com',
        body: 'receipt.pdf (24 KB)',
      );

      expect(
        rfcEmailBodyText(message: message, resolvedHtmlBody: null),
        'receipt.pdf (24 KB)',
      );
    });
  });
}
