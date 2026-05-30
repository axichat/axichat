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
      quotedContext: const DraftForwardedQuoteContext(
        senderLabel: 'Original sender',
        plainText: 'Quoted text',
      ),
      conversionState: conversionState,
      convertedText: convertedText,
    );
  }

  Future<void> recreateDraftsTableWithLegacyAutosaveDefault() async {
    final row = await database
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'drafts'",
        )
        .getSingle();
    final createSql = row.read<String>('sql');
    final legacySql = createSql.replaceFirstMapped(
      RegExp(r'("autosave_enabled"\s+INTEGER\s+NOT NULL\s+DEFAULT\s+)0'),
      (match) => '${match[1]}1',
    );
    expect(legacySql, isNot(createSql));

    await database.customStatement('PRAGMA foreign_keys = OFF');
    await database.customStatement('DROP TABLE drafts');
    await database.customStatement(legacySql);
    await database.customStatement('PRAGMA foreign_keys = ON');
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

  test('saveDraft persists the autosave preference', () async {
    final draftId = await database.saveDraft(
      jids: const ['peer@axi.im'],
      body: 'Saved body',
      draftSyncId: 'sync-autosave-preference',
      draftUpdatedAt: DateTime.utc(2026, 3, 11, 10),
      draftSourceId: 'source',
      draftRecipients: const [],
      autosaveEnabled: false,
    );

    final saved = await database.getDraft(draftId);
    expect(saved?.autosaveEnabled, isFalse);
  });

  test(
    'updateDraftAutosaveEnabled changes only the autosave preference',
    () async {
      final draftId = await database.saveDraft(
        jids: const ['peer@axi.im'],
        body: 'Saved body',
        draftSyncId: 'sync-autosave-toggle',
        draftUpdatedAt: DateTime.utc(2026, 3, 11, 10),
        draftSourceId: 'source',
        draftRecipients: const [],
        subject: 'Saved subject',
      );

      await database.updateDraftAutosaveEnabled(id: draftId, enabled: false);

      final saved = await database.getDraft(draftId);
      expect(saved?.body, 'Saved body');
      expect(saved?.subject, 'Saved subject');
      expect(saved?.autosaveEnabled, isFalse);
    },
  );

  test('saveDraft preserves autosave preference for existing drafts', () async {
    final draftId = await database.saveDraft(
      jids: const ['peer@axi.im'],
      body: 'Saved body',
      draftSyncId: 'sync-autosave-preserve',
      draftUpdatedAt: DateTime.utc(2026, 3, 11, 10),
      draftSourceId: 'source',
      draftRecipients: const [],
      autosaveEnabled: false,
    );

    await database.saveDraft(
      id: draftId,
      jids: const ['peer@axi.im'],
      body: 'Updated body',
      draftSyncId: 'sync-autosave-preserve',
      draftUpdatedAt: DateTime.utc(2026, 3, 11, 11),
      draftSourceId: 'source',
      draftRecipients: const [],
      autosaveEnabled: true,
    );

    final saved = await database.getDraft(draftId);
    expect(saved?.body, 'Updated body');
    expect(saved?.autosaveEnabled, isFalse);
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

  test('saveDraft persists attachment metadata before draft refs', () async {
    const metadataId = 'draft-attachment-meta';
    const metadata = FileMetadataData(
      id: ' draft-attachment-meta ',
      filename: 'attachment.txt',
      path: '/tmp/attachment.txt',
      mimeType: 'text/plain',
      sizeBytes: 42,
    );

    final draftId = await database.saveDraft(
      jids: const ['peer@axi.im'],
      body: 'Body with attachment',
      draftSyncId: 'sync-attachment-save',
      draftUpdatedAt: DateTime.utc(2026, 3, 11, 10),
      draftSourceId: 'source',
      draftRecipients: const [],
      attachmentMetadataIds: const [metadataId],
      attachmentMetadata: const [metadata],
    );

    final saved = await database.getDraft(draftId);
    final savedMetadata = await database.getFileMetadata(metadataId);
    expect(saved?.attachmentMetadataIds, [metadataId]);
    expect(savedMetadata, metadata.copyWith(id: metadataId));
  });

  test(
    'upsertDraftFromSync persists attachment metadata before draft refs',
    () async {
      const metadataId = 'synced-draft-attachment-meta';
      const metadata = FileMetadataData(
        id: ' synced-draft-attachment-meta ',
        filename: 'synced-attachment.txt',
        sourceUrls: ['https://example.com/synced-attachment.txt'],
        mimeType: 'text/plain',
        sizeBytes: 84,
      );

      final draftId = await database.upsertDraftFromSync(
        draftSyncId: 'sync-attachment-upsert',
        jids: const ['peer@axi.im'],
        draftUpdatedAt: DateTime.utc(2026, 3, 11, 10),
        draftSourceId: 'source',
        draftRecipients: const [],
        body: 'Synced body with attachment',
        attachmentMetadataIds: const [metadataId],
        attachmentMetadata: const [metadata],
      );

      final saved = await database.getDraft(draftId);
      final savedMetadata = await database.getFileMetadata(metadataId);
      expect(saved?.attachmentMetadataIds, [metadataId]);
      expect(savedMetadata, metadata.copyWith(id: metadataId));
    },
  );

  test('saveFileMetadata normalizes metadata IDs at the DB boundary', () async {
    const metadata = FileMetadataData(
      id: ' normalized-metadata-id ',
      filename: 'attachment.txt',
      path: '/tmp/attachment.txt',
      mimeType: 'text/plain',
      sizeBytes: 42,
    );
    const normalizedMetadata = FileMetadataData(
      id: 'normalized-metadata-id',
      filename: 'attachment.txt',
      path: '/tmp/attachment.txt',
      mimeType: 'text/plain',
      sizeBytes: 42,
    );

    await database.saveFileMetadata(metadata);

    expect(
      await database.getFileMetadata('normalized-metadata-id'),
      normalizedMetadata,
    );
    expect(
      await database.getFileMetadata(' normalized-metadata-id '),
      normalizedMetadata,
    );
    expect(
      await database.getFileMetadataForIds(const [
        ' normalized-metadata-id ',
        'normalized-metadata-id',
      ]),
      [normalizedMetadata],
    );
  });

  test('saveMessage normalizes message attachment metadata refs', () async {
    const metadata = FileMetadataData(
      id: ' message-attachment-meta ',
      filename: 'message.txt',
      path: '/tmp/message.txt',
      mimeType: 'text/plain',
      sizeBytes: 42,
    );
    await database.saveFileMetadata(metadata);

    await database.saveMessage(
      Message(
        stanzaID: 'message-with-normalized-attachment',
        senderJid: 'peer@axi.im',
        chatJid: 'peer@axi.im',
        body: 'Body',
        timestamp: DateTime.utc(2026, 3, 11, 10),
        fileMetadataID: ' message-attachment-meta ',
      ),
    );

    final saved = await database.getMessageByStanzaID(
      'message-with-normalized-attachment',
    );
    final attachments = await database.getMessageAttachments(saved!.id!);

    expect(saved.fileMetadataID, 'message-attachment-meta');
    expect(attachments.single.fileMetadataId, 'message-attachment-meta');
  });

  test('updateMessageAttachment normalizes metadata and refs', () async {
    await database.saveMessage(
      Message(
        stanzaID: 'message-update-normalized-attachment',
        senderJid: 'peer@axi.im',
        chatJid: 'peer@axi.im',
        body: 'Body',
        timestamp: DateTime.utc(2026, 3, 11, 10),
      ),
    );

    await database.updateMessageAttachment(
      stanzaID: 'message-update-normalized-attachment',
      metadata: const FileMetadataData(
        id: ' updated-message-attachment-meta ',
        filename: 'updated.txt',
        path: '/tmp/updated.txt',
        mimeType: 'text/plain',
        sizeBytes: 42,
      ),
    );

    final saved = await database.getMessageByStanzaID(
      'message-update-normalized-attachment',
    );
    final attachments = await database.getMessageAttachments(saved!.id!);

    expect(saved.fileMetadataID, 'updated-message-attachment-meta');
    expect(
      attachments.single.fileMetadataId,
      'updated-message-attachment-meta',
    );
    expect(
      await database.getFileMetadata('updated-message-attachment-meta'),
      isNotNull,
    );
  });

  test(
    'saveDraft preserves existing refs when new metadata is missing',
    () async {
      const metadata = FileMetadataData(
        id: 'existing-draft-attachment-meta',
        filename: 'existing.txt',
        path: '/tmp/existing.txt',
        mimeType: 'text/plain',
        sizeBytes: 42,
      );
      await database.saveFileMetadata(metadata);
      final draftId = await database.saveDraft(
        jids: const ['peer@axi.im'],
        body: 'Old body',
        draftSyncId: 'sync-preserve-missing',
        draftUpdatedAt: DateTime.utc(2026, 3, 11, 10),
        draftSourceId: 'source',
        draftRecipients: const [],
        attachmentMetadataIds: const ['existing-draft-attachment-meta'],
      );

      await expectLater(
        database.saveDraft(
          id: draftId,
          jids: const ['peer@axi.im'],
          body: 'New body',
          draftSyncId: 'sync-preserve-missing',
          draftUpdatedAt: DateTime.utc(2026, 3, 11, 11),
          draftSourceId: 'source',
          draftRecipients: const [],
          attachmentMetadataIds: const ['missing-draft-attachment-meta'],
        ),
        throwsA(isA<FormatException>()),
      );

      final saved = await database.getDraft(draftId);
      expect(saved?.body, 'Old body');
      expect(saved?.attachmentMetadataIds, ['existing-draft-attachment-meta']);
    },
  );

  test(
    'replaceMessageAttachments preserves refs when metadata is missing',
    () async {
      const metadata = FileMetadataData(
        id: 'existing-message-attachment-meta',
        filename: 'existing.txt',
        path: '/tmp/existing.txt',
        mimeType: 'text/plain',
        sizeBytes: 42,
      );
      await database.saveFileMetadata(metadata);
      await database.addMessageAttachment(
        messageId: 'message-preserve-missing',
        fileMetadataId: metadata.id,
      );

      await expectLater(
        database.replaceMessageAttachments(
          messageId: 'message-preserve-missing',
          fileMetadataIds: const ['missing-message-attachment-meta'],
        ),
        throwsA(isA<FormatException>()),
      );

      final attachments = await database.getMessageAttachments(
        'message-preserve-missing',
      );
      expect(attachments.single.fileMetadataId, metadata.id);
    },
  );

  test(
    'upsertDraftFromSync disables autosave even with legacy table default',
    () async {
      await recreateDraftsTableWithLegacyAutosaveDefault();

      final draftId = await database.upsertDraftFromSync(
        draftSyncId: 'sync-remote-legacy-default',
        jids: const ['peer@axi.im'],
        draftUpdatedAt: DateTime.utc(2026, 3, 11, 10),
        draftSourceId: 'source',
        draftRecipients: const [],
        body: 'Body',
      );

      final saved = await database.getDraft(draftId);
      expect(saved?.autosaveEnabled, isFalse);
    },
  );

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

  test('message attachment group quote metadata persists', () async {
    await database.saveFileMetadata(
      const FileMetadataData(id: 'file-1', filename: 'file.txt'),
    );
    await database.addMessageAttachment(
      messageId: 'message-1',
      fileMetadataId: 'file-1',
      transportGroupId: 'attachment-group',
      sortOrder: 0,
      groupQuotedReference: const MessageReference(
        kind: MessageReferenceKind.originId,
        value: 'quoted-origin',
      ),
    );

    final attachments = await database.getMessageAttachments('message-1');

    expect(attachments, hasLength(1));
    expect(attachments.single.groupQuotedReference, 'quoted-origin');
    expect(
      attachments.single.groupQuotedReferenceKind,
      MessageReferenceKind.originId,
    );
  });
}
