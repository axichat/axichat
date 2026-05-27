import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late XmppDrift database;

  setUp(() {
    database = XmppDrift.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  DraftForwardedBlock forwardedBlock({
    DraftForwardedBlockConversionState conversionState =
        DraftForwardedBlockConversionState.originalHtml,
    String? convertedText,
  }) {
    return DraftForwardedBlock(
      blockId: 'forward-block-1',
      sourceMessageId: 'source-message-1',
      senderJid: 'sender@axi.im',
      senderLabel: 'Sender',
      timestamp: DateTime.utc(2026, 3, 11, 8),
      originalSubject: 'Original subject',
      originalPlainText: 'Original text',
      originalHtml: '<p>Original <strong>HTML</strong></p>',
      conversionState: conversionState,
      convertedText: convertedText,
    );
  }

  test('saveDraft clears nullable draft fields', () async {
    final task = CalendarTask(
      id: 'stored-task',
      title: 'Stored task',
      createdAt: DateTime.utc(2026, 3, 11, 8),
      modifiedAt: DateTime.utc(2026, 3, 11, 9),
    );
    final draftId = await database.saveDraft(
      jids: const ['peer@axi.im'],
      body: 'Body',
      draftSyncId: 'sync-save',
      draftUpdatedAt: DateTime.utc(2026, 3, 11, 10),
      draftSourceId: 'source',
      draftRecipients: const [],
      subject: 'Subject',
      quotingStanzaId: 'quoted-origin',
      quotingReferenceKind: MessageReferenceKind.originId,
      calendarTaskIcsMessage: CalendarTaskIcsMessage(
        task: task,
        readOnly: false,
      ),
    );

    await database.saveDraft(
      id: draftId,
      jids: const ['peer@axi.im'],
      body: 'Body',
      draftSyncId: 'sync-save',
      draftUpdatedAt: DateTime.utc(2026, 3, 11, 11),
      draftSourceId: 'source',
      draftRecipients: const [],
    );

    final saved = await database.getDraft(draftId);
    expect(saved?.subject, isNull);
    expect(saved?.quotingStanzaId, isNull);
    expect(saved?.quotingReferenceKind, isNull);
    expect(saved?.calendarTaskIcsMessage, isNull);
  });

  test('saveDraft rolls back when commit becomes stale', () async {
    final draftUpdatedAt = DateTime.utc(2026, 3, 11, 10);
    final draftId = await database.saveDraft(
      jids: const ['peer@axi.im'],
      body: 'Saved body',
      draftSyncId: 'sync-stale-save',
      draftUpdatedAt: draftUpdatedAt,
      draftSourceId: 'source',
      draftRecipients: const [],
    );
    var checks = 0;

    await expectLater(
      database.saveDraft(
        id: draftId,
        jids: const ['peer@axi.im'],
        body: 'Discarded body',
        draftSyncId: 'sync-stale-save',
        draftUpdatedAt: DateTime.utc(2026, 3, 11, 11),
        draftSourceId: 'source',
        draftRecipients: const [],
        shouldCommit: () {
          checks += 1;
          return checks == 1;
        },
      ),
      throwsA(isA<DraftSaveAbortedException>()),
    );

    final saved = await database.getDraft(draftId);
    expect(saved?.body, 'Saved body');
    expect(saved?.draftUpdatedAt, draftUpdatedAt);
  });

  test('saveDraft persists forwarded block conversion state', () async {
    final block = forwardedBlock(
      conversionState: DraftForwardedBlockConversionState.convertedText,
      convertedText: 'Edited forwarded text',
    );

    final draftId = await database.saveDraft(
      jids: const ['peer@axi.im'],
      body: 'Intro',
      draftSyncId: 'sync-forward-save',
      draftUpdatedAt: DateTime.utc(2026, 3, 11, 10),
      draftSourceId: 'source',
      draftRecipients: const [],
      forwardedBlocks: [block],
    );

    final saved = await database.getDraft(draftId);
    expect(saved?.body, 'Intro');
    expect(saved?.forwardedBlocks, [block]);
  });

  test('upsertDraftFromSync clears nullable draft fields', () async {
    final draftId = await database.upsertDraftFromSync(
      draftSyncId: 'sync-remote',
      jids: const ['peer@axi.im'],
      draftUpdatedAt: DateTime.utc(2026, 3, 11, 10),
      draftSourceId: 'source',
      draftRecipients: const [],
      body: 'Body',
      subject: 'Subject',
      quotingStanzaId: 'quoted-origin',
      quotingReferenceKind: MessageReferenceKind.originId,
    );

    await database.upsertDraftFromSync(
      draftSyncId: 'sync-remote',
      jids: const ['peer@axi.im'],
      draftUpdatedAt: DateTime.utc(2026, 3, 11, 11),
      draftSourceId: 'source',
      draftRecipients: const [],
      body: 'Body',
    );

    final saved = await database.getDraft(draftId);
    expect(saved?.subject, isNull);
    expect(saved?.quotingStanzaId, isNull);
    expect(saved?.quotingReferenceKind, isNull);
  });

  test('upsertDraftFromSync replaces forwarded blocks', () async {
    final draftId = await database.upsertDraftFromSync(
      draftSyncId: 'sync-forward-remote',
      jids: const ['peer@axi.im'],
      draftUpdatedAt: DateTime.utc(2026, 3, 11, 10),
      draftSourceId: 'source',
      draftRecipients: const [],
      body: 'Body',
      forwardedBlocks: [forwardedBlock()],
    );

    await database.upsertDraftFromSync(
      draftSyncId: 'sync-forward-remote',
      jids: const ['peer@axi.im'],
      draftUpdatedAt: DateTime.utc(2026, 3, 11, 11),
      draftSourceId: 'source',
      draftRecipients: const [],
      body: 'Body',
    );

    final saved = await database.getDraft(draftId);
    expect(saved?.forwardedBlocks, isEmpty);
  });
}
