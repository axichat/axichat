import 'package:axichat/src/draft/view/drafts_list.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('draft list subtitle normalizes multiline body to one line', () {
    final draft = Draft(
      id: 1,
      jids: const ['peer@example.com'],
      body: ' First line\n\nSecond\tline  ',
      draftSyncId: 'draft-sync',
      draftUpdatedAt: DateTime.utc(2026),
      draftSourceId: 'source',
    );

    expect(draftListSubtitleLabel(draft), 'First line Second line');
  });

  test('draft list subtitle normalizes forwarded fallback text', () {
    final draft = Draft(
      id: 2,
      jids: const ['peer@example.com'],
      draftSyncId: 'draft-sync',
      draftUpdatedAt: DateTime.utc(2026),
      draftSourceId: 'source',
      forwardedBlocks: const [
        DraftForwardedBlock(
          blockId: 'forward-block',
          sourceMessageId: 'source-message',
          senderJid: 'sender@example.com',
          senderLabel: 'Sender',
          originalPlainText: 'Forwarded\n\nbody',
        ),
      ],
    );

    expect(draftListSubtitleLabel(draft), 'Forwarded body');
  });
}
