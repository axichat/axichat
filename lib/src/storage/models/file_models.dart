// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';

import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:axichat/src/storage/models/database_converters.dart';
import 'package:axichat/src/storage/models/message_models.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

part 'file_models.freezed.dart';

final class DraftDefaults {
  static const String sourceLegacyId = 'legacy';
}

final class DraftRecipientData {
  const DraftRecipientData({required this.jid, required this.role});

  static const String _jidKey = 'jid';
  static const String _roleKey = 'role';
  static const String _roleFallback = 'to';

  final String jid;
  final String role;

  static DraftRecipientData normalized({
    required String jid,
    String role = _roleFallback,
  }) {
    final normalizedJid = jid.trim();
    final normalizedRole = role.trim().isNotEmpty ? role.trim() : _roleFallback;
    return DraftRecipientData(jid: normalizedJid, role: normalizedRole);
  }

  DraftRecipientData copyWith({String? jid, String? role}) {
    return DraftRecipientData(jid: jid ?? this.jid, role: role ?? this.role);
  }

  Map<String, dynamic> toJson() => {_jidKey: jid, _roleKey: role};

  static DraftRecipientData? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final rawJid = json[_jidKey];
    if (rawJid is! String) return null;
    final trimmedJid = rawJid.trim();
    if (trimmedJid.isEmpty) return null;
    final rawRole = json[_roleKey];
    final role = rawRole is String && rawRole.trim().isNotEmpty
        ? rawRole.trim()
        : _roleFallback;
    return DraftRecipientData.normalized(jid: trimmedJid, role: role);
  }
}

class DraftRecipientListConverter
    extends TypeConverter<List<DraftRecipientData>, String> {
  const DraftRecipientListConverter();

  static final ListConverter<Map<String, dynamic>> _listConverter =
      ListConverter<Map<String, dynamic>>();

  @override
  List<DraftRecipientData> fromSql(String fromDb) {
    final List<Map<String, dynamic>> decoded = _listConverter.fromSql(fromDb);
    final recipients = <DraftRecipientData>[];
    for (final entry in decoded) {
      final DraftRecipientData? recipient = DraftRecipientData.fromJson(entry);
      if (recipient != null) {
        recipients.add(recipient);
      }
    }
    return List<DraftRecipientData>.unmodifiable(recipients);
  }

  @override
  String toSql(List<DraftRecipientData> value) {
    final List<Map<String, dynamic>> encoded = value
        .map((recipient) => recipient.toJson())
        .toList(growable: false);
    return _listConverter.toSql(encoded);
  }
}

class CalendarTaskIcsMessageConverter
    extends TypeConverter<CalendarTaskIcsMessage, String> {
  const CalendarTaskIcsMessageConverter();

  @override
  CalendarTaskIcsMessage fromSql(String fromDb) {
    final decoded = jsonDecode(fromDb);
    if (decoded is! Map) {
      throw const FormatException('Invalid calendar task draft payload.');
    }
    final parsed = CalendarTaskIcsMessage.tryParse(
      Map<String, dynamic>.from(decoded),
    );
    if (parsed == null) {
      throw const FormatException('Invalid calendar task draft payload.');
    }
    return parsed;
  }

  @override
  String toSql(CalendarTaskIcsMessage value) => jsonEncode(value.toJson());
}

final class DraftSyncMetadata {
  const DraftSyncMetadata({
    required this.id,
    required this.updatedAt,
    required this.sourceId,
  });

  final String id;
  final DateTime updatedAt;
  final String sourceId;

  String get normalizedId => id.trim();

  String get normalizedSourceId => sourceId.trim();

  DraftSyncMetadata resolved({
    required DateTime updatedAt,
    required String sourceId,
    required String Function() createId,
  }) {
    final resolvedId = normalizedId.isEmpty ? createId() : normalizedId;
    final resolvedSourceId = normalizedSourceId.isEmpty
        ? sourceId.trim()
        : normalizedSourceId;
    return DraftSyncMetadata(
      id: resolvedId,
      updatedAt: updatedAt.toUtc(),
      sourceId: resolvedSourceId,
    );
  }
}

final class DraftQuoteTarget {
  const DraftQuoteTarget({required this.stanzaId, required this.referenceKind});

  final String stanzaId;
  final MessageReferenceKind referenceKind;

  MessageReference get messageReference =>
      MessageReference(kind: referenceKind, value: stanzaId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DraftQuoteTarget &&
          other.stanzaId == stanzaId &&
          other.referenceKind == referenceKind;

  @override
  int get hashCode => Object.hash(stanzaId, referenceKind);

  static DraftQuoteTarget? fromDraft({
    required String? stanzaId,
    required MessageReferenceKind? referenceKind,
  }) {
    final normalizedStanzaId = stanzaId?.trim();
    if (normalizedStanzaId == null || normalizedStanzaId.isEmpty) {
      return null;
    }
    if (referenceKind == null) {
      return null;
    }
    return DraftQuoteTarget(
      stanzaId: normalizedStanzaId,
      referenceKind: referenceKind,
    );
  }
}

final class DraftAttachmentMetadataIds {
  DraftAttachmentMetadataIds(Iterable<String> ids)
    : _ids = _normalizeIds(ids).toList(growable: false);

  final List<String> _ids;

  List<String> get values => List<String>.unmodifiable(_ids);

  bool get isNotEmpty => _ids.isNotEmpty;

  List<String> limited({required int maxCount}) {
    if (_ids.length <= maxCount) {
      return values;
    }
    return List<String>.unmodifiable(
      _ids.take(maxCount).toList(growable: false),
    );
  }

  List<String> staleComparedTo(Iterable<String> incoming) {
    if (_ids.isEmpty) {
      return const <String>[];
    }
    final incomingIds = _normalizeIds(incoming).toSet();
    return _ids
        .where((metadataId) => !incomingIds.contains(metadataId))
        .toList(growable: false);
  }

  static Iterable<String> _normalizeIds(Iterable<String> ids) sync* {
    final seen = <String>{};
    for (final id in ids) {
      final normalized = id.trim();
      if (normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      yield normalized;
    }
  }
}

final class DraftRecipients {
  const DraftRecipients({
    required List<String> jids,
    required List<DraftRecipientData> storedRecipients,
  }) : _jids = jids,
       _storedRecipients = storedRecipients;

  final List<String> _jids;
  final List<DraftRecipientData> _storedRecipients;

  List<String> get jids => List<String>.unmodifiable(_jids);

  List<DraftRecipientData> get storedRecipients =>
      List<DraftRecipientData>.unmodifiable(_storedRecipients);

  List<DraftRecipientData> resolvedStoredRecipients() {
    if (_jids.isEmpty) {
      return const <DraftRecipientData>[];
    }
    final existingByJid = <String, DraftRecipientData>{};
    for (final recipient in _storedRecipients) {
      final normalized = recipient.jid.trim();
      if (normalized.isEmpty) {
        continue;
      }
      existingByJid[normalized] = recipient.copyWith(jid: normalized);
    }
    final resolved = <DraftRecipientData>[];
    final seen = <String>{};
    for (final jid in _jids) {
      final normalized = jid.trim();
      if (normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      final existing = existingByJid[normalized];
      if (existing != null) {
        resolved.add(existing);
        continue;
      }
      resolved.add(DraftRecipientData.normalized(jid: normalized));
    }
    return List<DraftRecipientData>.unmodifiable(resolved);
  }

  bool matchesSearchQuery(
    String lowerQuery, {
    required String? body,
    required String? subject,
  }) {
    if (lowerQuery.isEmpty) {
      return true;
    }
    final recipientText = _jids.join(', ').toLowerCase();
    return recipientText.contains(lowerQuery) ||
        (body?.toLowerCase().contains(lowerQuery) ?? false) ||
        (subject?.toLowerCase().contains(lowerQuery) ?? false);
  }
}

enum DraftForwardedBlockConversionState {
  originalHtml,
  convertedText;

  bool get isConverted => this == convertedText;

  static DraftForwardedBlockConversionState fromName(String? value) {
    return switch (value?.trim()) {
      'convertedText' => convertedText,
      _ => originalHtml,
    };
  }
}

final class DraftForwardedBlock {
  const DraftForwardedBlock({
    required this.blockId,
    required this.sourceMessageId,
    required this.senderJid,
    required this.senderLabel,
    required this.originalPlainText,
    this.timestamp,
    this.originalSubject,
    this.originalHtml,
    this.quotedContext,
    this.conversionState = DraftForwardedBlockConversionState.originalHtml,
    this.convertedText,
  });

  static const String _blockIdKey = 'blockId';
  static const String _sourceMessageIdKey = 'sourceMessageId';
  static const String _senderJidKey = 'senderJid';
  static const String _senderLabelKey = 'senderLabel';
  static const String _timestampKey = 'timestamp';
  static const String _originalSubjectKey = 'originalSubject';
  static const String _originalPlainTextKey = 'originalPlainText';
  static const String _originalHtmlKey = 'originalHtml';
  static const String _quotedContextKey = 'quotedContext';
  static const String _conversionStateKey = 'conversionState';
  static const String _convertedTextKey = 'convertedText';

  final String blockId;
  final String sourceMessageId;
  final String senderJid;
  final String senderLabel;
  final DateTime? timestamp;
  final String? originalSubject;
  final String originalPlainText;
  final String? originalHtml;
  final DraftForwardedQuoteContext? quotedContext;
  final DraftForwardedBlockConversionState conversionState;
  final String? convertedText;

  bool get isConverted => conversionState.isConverted;

  String get activePlainText {
    if (isConverted) {
      return convertedText ?? '';
    }
    return originalPlainText;
  }

  DraftForwardedBlock copyWith({
    String? blockId,
    String? sourceMessageId,
    String? senderJid,
    String? senderLabel,
    DateTime? timestamp,
    String? originalSubject,
    String? originalPlainText,
    String? originalHtml,
    DraftForwardedQuoteContext? quotedContext,
    DraftForwardedBlockConversionState? conversionState,
    String? convertedText,
  }) {
    return DraftForwardedBlock(
      blockId: blockId ?? this.blockId,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
      senderJid: senderJid ?? this.senderJid,
      senderLabel: senderLabel ?? this.senderLabel,
      timestamp: timestamp ?? this.timestamp,
      originalSubject: originalSubject ?? this.originalSubject,
      originalPlainText: originalPlainText ?? this.originalPlainText,
      originalHtml: originalHtml ?? this.originalHtml,
      quotedContext: quotedContext ?? this.quotedContext,
      conversionState: conversionState ?? this.conversionState,
      convertedText: convertedText ?? this.convertedText,
    );
  }

  DraftForwardedBlock asConverted(String text) {
    return copyWith(
      conversionState: DraftForwardedBlockConversionState.convertedText,
      convertedText: text,
    );
  }

  DraftForwardedBlock restoredOriginal() {
    return DraftForwardedBlock(
      blockId: blockId,
      sourceMessageId: sourceMessageId,
      senderJid: senderJid,
      senderLabel: senderLabel,
      timestamp: timestamp,
      originalSubject: originalSubject,
      originalPlainText: originalPlainText,
      originalHtml: originalHtml,
      quotedContext: quotedContext,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    _blockIdKey: blockId,
    _sourceMessageIdKey: sourceMessageId,
    _senderJidKey: senderJid,
    _senderLabelKey: senderLabel,
    if (timestamp != null) _timestampKey: timestamp!.toUtc().toIso8601String(),
    if (originalSubject?.trim().isNotEmpty == true)
      _originalSubjectKey: originalSubject,
    _originalPlainTextKey: originalPlainText,
    if (originalHtml?.trim().isNotEmpty == true) _originalHtmlKey: originalHtml,
    if (quotedContext != null) _quotedContextKey: quotedContext!.toJson(),
    _conversionStateKey: conversionState.name,
    if (convertedText?.trim().isNotEmpty == true)
      _convertedTextKey: convertedText,
  };

  static DraftForwardedBlock? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final rawBlockId = json[_blockIdKey];
    final rawSourceMessageId = json[_sourceMessageIdKey];
    final rawSenderJid = json[_senderJidKey];
    final rawSenderLabel = json[_senderLabelKey];
    final rawPlainText = json[_originalPlainTextKey];
    if (rawBlockId is! String ||
        rawSourceMessageId is! String ||
        rawSenderJid is! String ||
        rawSenderLabel is! String ||
        rawPlainText is! String) {
      return null;
    }
    final blockId = rawBlockId.trim();
    final sourceMessageId = rawSourceMessageId.trim();
    if (blockId.isEmpty || sourceMessageId.isEmpty) {
      return null;
    }
    final rawTimestamp = json[_timestampKey];
    final timestamp = rawTimestamp is String
        ? DateTime.tryParse(rawTimestamp)?.toUtc()
        : null;
    final rawSubject = json[_originalSubjectKey];
    final rawHtml = json[_originalHtmlKey];
    final rawQuotedContext = json[_quotedContextKey];
    final rawConvertedText = json[_convertedTextKey];
    final rawConversionState = json[_conversionStateKey];
    return DraftForwardedBlock(
      blockId: blockId,
      sourceMessageId: sourceMessageId,
      senderJid: rawSenderJid.trim(),
      senderLabel: rawSenderLabel.trim(),
      timestamp: timestamp,
      originalSubject: rawSubject is String && rawSubject.trim().isNotEmpty
          ? rawSubject
          : null,
      originalPlainText: rawPlainText,
      originalHtml: rawHtml is String && rawHtml.trim().isNotEmpty
          ? rawHtml
          : null,
      quotedContext: rawQuotedContext is Map
          ? DraftForwardedQuoteContext.fromJson(
              Map<String, dynamic>.from(rawQuotedContext),
            )
          : null,
      conversionState: DraftForwardedBlockConversionState.fromName(
        rawConversionState is String ? rawConversionState : null,
      ),
      convertedText:
          rawConvertedText is String && rawConvertedText.trim().isNotEmpty
          ? rawConvertedText
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DraftForwardedBlock &&
            other.blockId == blockId &&
            other.sourceMessageId == sourceMessageId &&
            other.senderJid == senderJid &&
            other.senderLabel == senderLabel &&
            other.timestamp == timestamp &&
            other.originalSubject == originalSubject &&
            other.originalPlainText == originalPlainText &&
            other.originalHtml == originalHtml &&
            other.quotedContext == quotedContext &&
            other.conversionState == conversionState &&
            other.convertedText == convertedText;
  }

  @override
  int get hashCode => Object.hash(
    blockId,
    sourceMessageId,
    senderJid,
    senderLabel,
    timestamp,
    originalSubject,
    originalPlainText,
    originalHtml,
    quotedContext,
    conversionState,
    convertedText,
  );
}

final class DraftForwardedQuoteContext {
  const DraftForwardedQuoteContext({
    required this.senderLabel,
    required this.plainText,
  });

  static const String _senderLabelKey = 'senderLabel';
  static const String _plainTextKey = 'plainText';

  final String senderLabel;
  final String plainText;

  Map<String, dynamic> toJson() => <String, dynamic>{
    _senderLabelKey: senderLabel,
    _plainTextKey: plainText,
  };

  static DraftForwardedQuoteContext? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final rawSenderLabel = json[_senderLabelKey];
    final rawPlainText = json[_plainTextKey];
    if (rawSenderLabel is! String || rawPlainText is! String) {
      return null;
    }
    final senderLabel = rawSenderLabel.trim();
    final plainText = rawPlainText.trim();
    if (senderLabel.isEmpty || plainText.isEmpty) {
      return null;
    }
    return DraftForwardedQuoteContext(
      senderLabel: senderLabel,
      plainText: plainText,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DraftForwardedQuoteContext &&
            other.senderLabel == senderLabel &&
            other.plainText == plainText;
  }

  @override
  int get hashCode => Object.hash(senderLabel, plainText);
}

class DraftForwardedBlockListConverter
    extends TypeConverter<List<DraftForwardedBlock>, String> {
  const DraftForwardedBlockListConverter();

  static final ListConverter<Map<String, dynamic>> _listConverter =
      ListConverter<Map<String, dynamic>>();

  @override
  List<DraftForwardedBlock> fromSql(String fromDb) {
    final List<Map<String, dynamic>> decoded = _listConverter.fromSql(fromDb);
    final blocks = <DraftForwardedBlock>[];
    for (final entry in decoded) {
      final block = DraftForwardedBlock.fromJson(entry);
      if (block != null) {
        blocks.add(block);
      }
    }
    return List<DraftForwardedBlock>.unmodifiable(blocks);
  }

  @override
  String toSql(List<DraftForwardedBlock> value) {
    return jsonEncode(
      value.map((block) => block.toJson()).toList(growable: false),
    );
  }
}

@Freezed(toJson: false, fromJson: false)
sealed class FileMetadataData
    with _$FileMetadataData
    implements Insertable<FileMetadataData> {
  const factory FileMetadataData({
    required String id,
    required String filename,
    String? path,
    List<String>? sourceUrls,
    String? mimeType,
    int? sizeBytes,
    int? width,
    int? height,
    String? encryptionKey,
    String? encryptionIV,
    String? encryptionScheme,
    Map<mox.HashFunction, String>? cipherTextHashes,
    Map<mox.HashFunction, String>? plainTextHashes,
    String? thumbnailType,
    String? thumbnailData,
  }) = _FileMetadataData;

  const FileMetadataData._();

  @override
  Map<String, Expression<Object>> toColumns(bool nullToAbsent) {
    Value<T?> nullableValue<T>(T? value) {
      if (nullToAbsent && value == null) {
        return const Value.absent();
      }
      return Value<T?>(value);
    }

    return FileMetadataCompanion(
      id: Value(id),
      filename: Value(filename),
      path: nullableValue(path),
      sourceUrls: nullableValue(sourceUrls),
      mimeType: nullableValue(mimeType),
      sizeBytes: nullableValue(sizeBytes),
      width: nullableValue(width),
      height: nullableValue(height),
      encryptionKey: nullableValue(encryptionKey),
      encryptionIV: nullableValue(encryptionIV),
      encryptionScheme: nullableValue(encryptionScheme),
      cipherTextHashes: nullableValue(cipherTextHashes),
      plainTextHashes: nullableValue(plainTextHashes),
      thumbnailType: nullableValue(thumbnailType),
      thumbnailData: nullableValue(thumbnailData),
    ).toColumns(nullToAbsent);
  }
}

final class AttachmentGalleryItem {
  const AttachmentGalleryItem({
    required this.message,
    required this.metadata,
    required this.chat,
  });

  final Message message;
  final FileMetadataData metadata;
  final Chat? chat;
}

@UseRowClass(FileMetadataData)
class FileMetadata extends Table {
  TextColumn get id => text().clientDefault(() => uuid.v4())();

  TextColumn get filename => text()();

  TextColumn get path => text().nullable()();

  TextColumn get sourceUrls => text().map(ListConverter<String>()).nullable()();

  TextColumn get mimeType => text().nullable()();

  IntColumn get sizeBytes => integer().nullable()();

  IntColumn get width => integer().nullable()();

  IntColumn get height => integer().nullable()();

  TextColumn get encryptionKey => text().nullable()();

  TextColumn get encryptionIV => text().nullable()();

  TextColumn get encryptionScheme => text().nullable()();

  TextColumn get cipherTextHashes => text().map(HashesConverter()).nullable()();

  TextColumn get plainTextHashes => text().map(HashesConverter()).nullable()();

  TextColumn get thumbnailType => text().nullable()();

  TextColumn get thumbnailData => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

@Freezed(toJson: false, fromJson: false)
abstract class Sticker with _$Sticker {
  const factory Sticker({
    required String id,
    required String stickerPackID,
    required String fileMetadataID,
    required String description,
    required Map<String, String> suggestions,
  }) = _Sticker;
}

@UseRowClass(Sticker)
class Stickers extends Table {
  TextColumn get id => text()();

  TextColumn get stickerPackID => text()();

  TextColumn get fileMetadataID => text()();

  TextColumn get description => text()();

  TextColumn get suggestions => text().map(const MapStringStringConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

@Freezed(toJson: false, fromJson: false)
abstract class StickerPack with _$StickerPack {
  const factory StickerPack({
    required String id,
    required String name,
    required String description,
    required String hashAlgorithm,
    required String hashValue,
    required bool restricted,
    required DateTime addedTimestamp,
    @Default(<Sticker>[]) List<Sticker> stickers,
    @Default(0) int sizeBytes,
    @Default(true) bool local,
  }) = _StickerPack;
}

@UseRowClass(StickerPack)
class StickerPacks extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get description => text()();

  TextColumn get hashAlgorithm => text()();

  TextColumn get hashValue => text()();

  BoolColumn get restricted => boolean()();

  DateTimeColumn get addedTimestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@Freezed(toJson: false, fromJson: false)
abstract class Draft with _$Draft implements Insertable<Draft> {
  const factory Draft({
    required int id,
    required List<String> jids,
    required String draftSyncId,
    required DateTime draftUpdatedAt,
    required String draftSourceId,
    @Default(<DraftRecipientData>[]) List<DraftRecipientData> draftRecipients,
    String? body,
    String? subject,
    String? quotingStanzaId,
    MessageReferenceKind? quotingReferenceKind,
    @Default(<String>[]) List<String> attachmentMetadataIds,
    CalendarTaskIcsMessage? calendarTaskIcsMessage,
    @Default(<DraftForwardedBlock>[]) List<DraftForwardedBlock> forwardedBlocks,
    @Default(false) bool autosaveEnabled,
  }) = _Draft;

  const Draft._();

  DraftSyncMetadata get syncMetadata => DraftSyncMetadata(
    id: draftSyncId,
    updatedAt: draftUpdatedAt,
    sourceId: draftSourceId,
  );

  DraftRecipients get recipients =>
      DraftRecipients(jids: jids, storedRecipients: draftRecipients);

  DraftAttachmentMetadataIds get attachmentMetadata =>
      DraftAttachmentMetadataIds(attachmentMetadataIds);

  DraftQuoteTarget? get quoteTarget => DraftQuoteTarget.fromDraft(
    stanzaId: quotingStanzaId,
    referenceKind: quotingReferenceKind,
  );

  bool get hasSyncIdentity => syncMetadata.normalizedId.isNotEmpty;

  bool get hasAttachments => attachmentMetadata.isNotEmpty;

  bool get hasCalendarTaskIcs => calendarTaskIcsMessage != null;

  bool get hasForwardedBlocks => forwardedBlocks.isNotEmpty;

  bool matchesSearchQuery(String lowerQuery) {
    return recipients.matchesSearchQuery(
      lowerQuery,
      body: _searchBody,
      subject: subject,
    );
  }

  String? get _searchBody {
    final values = <String>[
      if (body?.trim().isNotEmpty == true) body!,
      for (final block in forwardedBlocks) block.activePlainText,
    ];
    if (values.isEmpty) {
      return null;
    }
    return values.join('\n');
  }

  Draft copyWithSyncMetadata(DraftSyncMetadata metadata) {
    return copyWith(
      draftSyncId: metadata.id,
      draftUpdatedAt: metadata.updatedAt.toUtc(),
      draftSourceId: metadata.sourceId,
    );
  }

  Draft copyWithQuoteTarget(DraftQuoteTarget? target) {
    return copyWith(
      quotingStanzaId: target?.stanzaId,
      quotingReferenceKind: target?.referenceKind,
    );
  }

  @override
  Map<String, Expression<Object>> toColumns(bool nullToAbsent) {
    Value<T?> nullableValue<T>(T? value) {
      if (nullToAbsent && value == null) {
        return const Value.absent();
      }
      return Value<T?>(value);
    }

    return DraftsCompanion(
      id: Value(id),
      jids: Value(jids),
      draftSyncId: Value(draftSyncId),
      draftUpdatedAt: Value(draftUpdatedAt),
      draftSourceId: Value(draftSourceId),
      draftRecipients: Value(draftRecipients),
      body: nullableValue(body),
      subject: nullableValue(subject),
      quotingStanzaId: nullableValue(quotingStanzaId),
      quotingReferenceKind: nullableValue(quotingReferenceKind),
      attachmentMetadataIds: Value(attachmentMetadataIds),
      calendarTaskIcsMessage: nullableValue(calendarTaskIcsMessage),
      forwardedBlocks: Value(forwardedBlocks),
      autosaveEnabled: Value(autosaveEnabled),
    ).toColumns(nullToAbsent);
  }
}

@UseRowClass(Draft)
class Drafts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get jids => text().map(ListConverter<String>())();

  TextColumn get draftSyncId => text().withDefault(const Constant(''))();

  DateTimeColumn get draftUpdatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  TextColumn get draftSourceId =>
      text().withDefault(const Constant(DraftDefaults.sourceLegacyId))();

  TextColumn get draftRecipients => text()
      .map(const DraftRecipientListConverter())
      .withDefault(const Constant('[]'))();

  TextColumn get body => text().nullable()();

  TextColumn get subject => text().nullable()();

  TextColumn get quotingStanzaId => text().nullable()();

  IntColumn get quotingReferenceKind =>
      intEnum<MessageReferenceKind>().nullable()();

  TextColumn get attachmentMetadataIds =>
      text().map(ListConverter<String>()).withDefault(const Constant('[]'))();

  TextColumn get calendarTaskIcsMessage => text()
      .named('calendar_task_ics')
      .map(const CalendarTaskIcsMessageConverter())
      .nullable()();

  TextColumn get forwardedBlocks => text()
      .named('forwarded_blocks')
      .map(const DraftForwardedBlockListConverter())
      .withDefault(const Constant('[]'))();

  BoolColumn get autosaveEnabled =>
      boolean().named('autosave_enabled').withDefault(const Constant(false))();
}

@DataClassName('DraftAttachmentRef')
class DraftAttachmentRefs extends Table {
  IntColumn get draftId => integer().references(Drafts, #id)();

  TextColumn get fileMetadataId => text().references(FileMetadata, #id)();

  @override
  Set<Column> get primaryKey => {draftId, fileMetadataId};

  List<Index> get indexes => [
    Index('idx_draft_attachment_file', 'file_metadata_id'),
  ];
}
