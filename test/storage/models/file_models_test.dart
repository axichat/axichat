import 'package:axichat/src/storage/models/file_models.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileMetadataData.toColumns', () {
    test('preserves nullable fields for full-row writes', () {
      const metadata = FileMetadataData(
        id: 'metadata-id',
        filename: 'file.txt',
      );

      final columns = metadata.toColumns(false);

      expect(columns['path'], isA<Variable<String>>());
      expect(
        columns['path'],
        isA<Variable<String>>().having((v) => v.value, 'value', isNull),
      );
      expect(columns, contains('source_urls'));
      expect(columns, contains('mime_type'));
      expect(columns, contains('size_bytes'));
      expect(columns, contains('width'));
      expect(columns, contains('height'));
      expect(columns, contains('encryption_key'));
      expect(columns, contains('encryption_i_v'));
      expect(columns, contains('encryption_scheme'));
      expect(columns, contains('cipher_text_hashes'));
      expect(columns, contains('plain_text_hashes'));
      expect(columns, contains('thumbnail_type'));
      expect(columns, contains('thumbnail_data'));
    });

    test('omits nullable fields for insert-style writes', () {
      const metadata = FileMetadataData(
        id: 'metadata-id',
        filename: 'file.txt',
      );

      final columns = metadata.toColumns(true);

      expect(columns, isNot(contains('path')));
      expect(columns, isNot(contains('source_urls')));
      expect(columns, isNot(contains('mime_type')));
      expect(columns, isNot(contains('size_bytes')));
      expect(columns, isNot(contains('width')));
      expect(columns, isNot(contains('height')));
      expect(columns, isNot(contains('encryption_key')));
      expect(columns, isNot(contains('encryption_i_v')));
      expect(columns, isNot(contains('encryption_scheme')));
      expect(columns, isNot(contains('cipher_text_hashes')));
      expect(columns, isNot(contains('plain_text_hashes')));
      expect(columns, isNot(contains('thumbnail_type')));
      expect(columns, isNot(contains('thumbnail_data')));
    });
  });

  group('Draft.toColumns', () {
    test('preserves nullable fields for full-row writes', () {
      final draft = Draft(
        id: 1,
        jids: const ['peer@example.com'],
        draftSyncId: 'sync-id',
        draftUpdatedAt: DateTime.utc(2024, 1, 1),
        draftSourceId: 'source-id',
      );

      final columns = draft.toColumns(false);

      expect(columns['body'], isA<Variable<String>>());
      expect(
        columns['body'],
        isA<Variable<String>>().having((v) => v.value, 'value', isNull),
      );
      expect(columns, contains('subject'));
      expect(columns, contains('quoting_stanza_id'));
      expect(columns, contains('quoting_reference_kind'));
    });

    test('omits nullable fields for insert-style writes', () {
      final draft = Draft(
        id: 1,
        jids: const ['peer@example.com'],
        draftSyncId: 'sync-id',
        draftUpdatedAt: DateTime.utc(2024, 1, 1),
        draftSourceId: 'source-id',
      );

      final columns = draft.toColumns(true);

      expect(columns, isNot(contains('body')));
      expect(columns, isNot(contains('subject')));
      expect(columns, isNot(contains('quoting_stanza_id')));
      expect(columns, isNot(contains('quoting_reference_kind')));
    });
  });
}
