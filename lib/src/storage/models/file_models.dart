// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models/database_converters.dart';
import 'package:axichat/src/storage/models/message_models.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

part 'file_models.freezed.dart';

const String draftSyncIdFallback = '';
const String draftSourceLegacyId = 'legacy';
const String draftRecipientsFallbackJson = '[]';
const String _draftRecipientJidKey = 'jid';
const String _draftRecipientRoleKey = 'role';
const String _draftRecipientRoleFallback = 'to';

final class DraftRecipientData {
  const DraftRecipientData({
    required this.jid,
    required this.role,
  });

  final String jid;
  final String role;

  DraftRecipientData copyWith({
    String? jid,
    String? role,
  }) {
    return DraftRecipientData(
      jid: jid ?? this.jid,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => {
        _draftRecipientJidKey: jid,
        _draftRecipientRoleKey: role,
      };

  static DraftRecipientData? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final rawJid = json[_draftRecipientJidKey];
    if (rawJid is! String) return null;
    final trimmedJid = rawJid.trim();
    if (trimmedJid.isEmpty) return null;
    final rawRole = json[_draftRecipientRoleKey];
    final role = rawRole is String && rawRole.trim().isNotEmpty
        ? rawRole.trim()
        : _draftRecipientRoleFallback;
    return DraftRecipientData(
      jid: trimmedJid,
      role: role,
    );
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
    final List<Map<String, dynamic>> encoded =
        value.map((recipient) => recipient.toJson()).toList(growable: false);
    return _listConverter.toSql(encoded);
  }
}

@Freezed(toJson: false, fromJson: false)
class FileMetadataData
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
  Map<String, Expression<Object>> toColumns(bool nullToAbsent) =>
      FileMetadataCompanion(
        id: Value(id),
        filename: Value(filename),
        path: Value.absentIfNull(path),
        sourceUrls: Value.absentIfNull(sourceUrls),
        mimeType: Value.absentIfNull(mimeType),
        sizeBytes: Value.absentIfNull(sizeBytes),
        width: Value.absentIfNull(width),
        height: Value.absentIfNull(height),
        encryptionKey: Value.absentIfNull(encryptionKey),
        encryptionIV: Value.absentIfNull(encryptionIV),
        encryptionScheme: Value.absentIfNull(encryptionScheme),
        cipherTextHashes: Value.absentIfNull(cipherTextHashes),
        plainTextHashes: Value.absentIfNull(plainTextHashes),
        thumbnailType: Value.absentIfNull(thumbnailType),
        thumbnailData: Value.absentIfNull(thumbnailData),
      ).toColumns(nullToAbsent);
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
class Sticker with _$Sticker {
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
class StickerPack with _$StickerPack {
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
class Draft with _$Draft implements Insertable<Draft> {
  const factory Draft({
    required int id,
    required List<String> jids,
    required String draftSyncId,
    required DateTime draftUpdatedAt,
    required String draftSourceId,
    @Default(<DraftRecipientData>[]) List<DraftRecipientData> draftRecipients,
    String? body,
    String? subject,
    @Default(<String>[]) List<String> attachmentMetadataIds,
  }) = _Draft;

  const Draft._();

  @override
  Map<String, Expression<Object>> toColumns(bool nullToAbsent) =>
      DraftsCompanion(
        id: Value(id),
        jids: Value(jids),
        draftSyncId: Value(draftSyncId),
        draftUpdatedAt: Value(draftUpdatedAt),
        draftSourceId: Value(draftSourceId),
        draftRecipients: Value(draftRecipients),
        body: Value.absentIfNull(body),
        subject: Value.absentIfNull(subject),
        attachmentMetadataIds: Value(attachmentMetadataIds),
      ).toColumns(nullToAbsent);
}

@UseRowClass(Draft)
class Drafts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get jids => text().map(ListConverter<String>())();

  TextColumn get draftSyncId =>
      text().withDefault(const Constant(draftSyncIdFallback))();

  DateTimeColumn get draftUpdatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  TextColumn get draftSourceId =>
      text().withDefault(const Constant(draftSourceLegacyId))();

  TextColumn get draftRecipients => text()
      .map(const DraftRecipientListConverter())
      .withDefault(const Constant(draftRecipientsFallbackJson))();

  TextColumn get body => text().nullable()();

  TextColumn get subject => text().nullable()();

  TextColumn get attachmentMetadataIds =>
      text().map(ListConverter<String>()).withDefault(const Constant('[]'))();
}
