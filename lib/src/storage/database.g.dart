// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: implicit_dynamic_parameter

part of 'database.dart';

// ignore_for_file: type=lint
mixin _$MessagesAccessorMixin on DatabaseAccessor<XmppDatabase> {
  $FileMetadataTable get fileMetadata => attachedDatabase.fileMetadata;
  $StickerPacksTable get stickerPacks => attachedDatabase.stickerPacks;
  $MessagesTable get messages => attachedDatabase.messages;
}
mixin _$FileMetadataAccessorMixin on DatabaseAccessor<XmppDatabase> {
  $FileMetadataTable get fileMetadata => attachedDatabase.fileMetadata;
}
mixin _$ChatsAccessorMixin on DatabaseAccessor<XmppDatabase> {
  $ContactsTable get contacts => attachedDatabase.contacts;
  $ChatsTable get chats => attachedDatabase.chats;
}
mixin _$RosterAccessorMixin on DatabaseAccessor<XmppDatabase> {
  $ContactsTable get contacts => attachedDatabase.contacts;
  $ChatsTable get chats => attachedDatabase.chats;
  $RosterTable get roster => attachedDatabase.roster;
}
mixin _$InvitesAccessorMixin on DatabaseAccessor<XmppDatabase> {
  $InvitesTable get invites => attachedDatabase.invites;
}
mixin _$BlocklistAccessorMixin on DatabaseAccessor<XmppDatabase> {
  $BlocklistTable get blocklist => attachedDatabase.blocklist;
}

class $FileMetadataTable extends FileMetadata
    with TableInfo<$FileMetadataTable, FileMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FileMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      clientDefault: () => uuid.v4());
  static const VerificationMeta _filenameMeta =
      const VerificationMeta('filename');
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
      'filename', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
      'path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceUrlsMeta =
      const VerificationMeta('sourceUrls');
  @override
  late final GeneratedColumnWithTypeConverter<List<String>?, String>
      sourceUrls = GeneratedColumn<String>('source_urls', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<List<String>?>(
              $FileMetadataTable.$convertersourceUrlsn);
  static const VerificationMeta _mimeTypeMeta =
      const VerificationMeta('mimeType');
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
      'mime_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sizeBytesMeta =
      const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
      'size_bytes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
      'width', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
      'height', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _encryptionKeyMeta =
      const VerificationMeta('encryptionKey');
  @override
  late final GeneratedColumn<String> encryptionKey = GeneratedColumn<String>(
      'encryption_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _encryptionIVMeta =
      const VerificationMeta('encryptionIV');
  @override
  late final GeneratedColumn<String> encryptionIV = GeneratedColumn<String>(
      'encryption_i_v', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _encryptionSchemeMeta =
      const VerificationMeta('encryptionScheme');
  @override
  late final GeneratedColumn<String> encryptionScheme = GeneratedColumn<String>(
      'encryption_scheme', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cipherTextHashesMeta =
      const VerificationMeta('cipherTextHashes');
  @override
  late final GeneratedColumnWithTypeConverter<Map<HashFunction, String>?,
      String> cipherTextHashes = GeneratedColumn<String>(
          'cipher_text_hashes', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false)
      .withConverter<Map<HashFunction, String>?>(
          $FileMetadataTable.$convertercipherTextHashesn);
  static const VerificationMeta _plainTextHashesMeta =
      const VerificationMeta('plainTextHashes');
  @override
  late final GeneratedColumnWithTypeConverter<Map<HashFunction, String>?,
      String> plainTextHashes = GeneratedColumn<String>(
          'plain_text_hashes', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false)
      .withConverter<Map<HashFunction, String>?>(
          $FileMetadataTable.$converterplainTextHashesn);
  static const VerificationMeta _thumbnailTypeMeta =
      const VerificationMeta('thumbnailType');
  @override
  late final GeneratedColumn<String> thumbnailType = GeneratedColumn<String>(
      'thumbnail_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _thumbnailDataMeta =
      const VerificationMeta('thumbnailData');
  @override
  late final GeneratedColumn<String> thumbnailData = GeneratedColumn<String>(
      'thumbnail_data', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        filename,
        path,
        sourceUrls,
        mimeType,
        sizeBytes,
        width,
        height,
        encryptionKey,
        encryptionIV,
        encryptionScheme,
        cipherTextHashes,
        plainTextHashes,
        thumbnailType,
        thumbnailData
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_metadata';
  @override
  VerificationContext validateIntegrity(Insertable<FileMetadataData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('filename')) {
      context.handle(_filenameMeta,
          filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta));
    } else if (isInserting) {
      context.missing(_filenameMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
          _pathMeta, path.isAcceptableOrUnknown(data['path']!, _pathMeta));
    }
    context.handle(_sourceUrlsMeta, const VerificationResult.success());
    if (data.containsKey('mime_type')) {
      context.handle(_mimeTypeMeta,
          mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta));
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta,
          sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    }
    if (data.containsKey('width')) {
      context.handle(
          _widthMeta, width.isAcceptableOrUnknown(data['width']!, _widthMeta));
    }
    if (data.containsKey('height')) {
      context.handle(_heightMeta,
          height.isAcceptableOrUnknown(data['height']!, _heightMeta));
    }
    if (data.containsKey('encryption_key')) {
      context.handle(
          _encryptionKeyMeta,
          encryptionKey.isAcceptableOrUnknown(
              data['encryption_key']!, _encryptionKeyMeta));
    }
    if (data.containsKey('encryption_i_v')) {
      context.handle(
          _encryptionIVMeta,
          encryptionIV.isAcceptableOrUnknown(
              data['encryption_i_v']!, _encryptionIVMeta));
    }
    if (data.containsKey('encryption_scheme')) {
      context.handle(
          _encryptionSchemeMeta,
          encryptionScheme.isAcceptableOrUnknown(
              data['encryption_scheme']!, _encryptionSchemeMeta));
    }
    context.handle(_cipherTextHashesMeta, const VerificationResult.success());
    context.handle(_plainTextHashesMeta, const VerificationResult.success());
    if (data.containsKey('thumbnail_type')) {
      context.handle(
          _thumbnailTypeMeta,
          thumbnailType.isAcceptableOrUnknown(
              data['thumbnail_type']!, _thumbnailTypeMeta));
    }
    if (data.containsKey('thumbnail_data')) {
      context.handle(
          _thumbnailDataMeta,
          thumbnailData.isAcceptableOrUnknown(
              data['thumbnail_data']!, _thumbnailDataMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FileMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileMetadataData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      filename: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}filename'])!,
      path: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}path']),
      sourceUrls: $FileMetadataTable.$convertersourceUrlsn.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}source_urls'])),
      mimeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mime_type']),
      sizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size_bytes']),
      width: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}width']),
      height: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}height']),
      encryptionKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}encryption_key']),
      encryptionIV: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}encryption_i_v']),
      encryptionScheme: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}encryption_scheme']),
      cipherTextHashes: $FileMetadataTable.$convertercipherTextHashesn.fromSql(
          attachedDatabase.typeMapping.read(DriftSqlType.string,
              data['${effectivePrefix}cipher_text_hashes'])),
      plainTextHashes: $FileMetadataTable.$converterplainTextHashesn.fromSql(
          attachedDatabase.typeMapping.read(DriftSqlType.string,
              data['${effectivePrefix}plain_text_hashes'])),
      thumbnailType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_type']),
      thumbnailData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_data']),
    );
  }

  @override
  $FileMetadataTable createAlias(String alias) {
    return $FileMetadataTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertersourceUrls =
      ListConverter();
  static TypeConverter<List<String>?, String?> $convertersourceUrlsn =
      NullAwareTypeConverter.wrap($convertersourceUrls);
  static TypeConverter<Map<HashFunction, String>, String>
      $convertercipherTextHashes = HashesConverter();
  static TypeConverter<Map<HashFunction, String>?, String?>
      $convertercipherTextHashesn =
      NullAwareTypeConverter.wrap($convertercipherTextHashes);
  static TypeConverter<Map<HashFunction, String>, String>
      $converterplainTextHashes = HashesConverter();
  static TypeConverter<Map<HashFunction, String>?, String?>
      $converterplainTextHashesn =
      NullAwareTypeConverter.wrap($converterplainTextHashes);
}

class FileMetadataData extends DataClass
    implements Insertable<FileMetadataData> {
  final String id;
  final String filename;
  final String? path;
  final List<String>? sourceUrls;
  final String? mimeType;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final String? encryptionKey;
  final String? encryptionIV;
  final String? encryptionScheme;
  final Map<HashFunction, String>? cipherTextHashes;
  final Map<HashFunction, String>? plainTextHashes;
  final String? thumbnailType;
  final String? thumbnailData;
  const FileMetadataData(
      {required this.id,
      required this.filename,
      this.path,
      this.sourceUrls,
      this.mimeType,
      this.sizeBytes,
      this.width,
      this.height,
      this.encryptionKey,
      this.encryptionIV,
      this.encryptionScheme,
      this.cipherTextHashes,
      this.plainTextHashes,
      this.thumbnailType,
      this.thumbnailData});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['filename'] = Variable<String>(filename);
    if (!nullToAbsent || path != null) {
      map['path'] = Variable<String>(path);
    }
    if (!nullToAbsent || sourceUrls != null) {
      map['source_urls'] = Variable<String>(
          $FileMetadataTable.$convertersourceUrlsn.toSql(sourceUrls));
    }
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || encryptionKey != null) {
      map['encryption_key'] = Variable<String>(encryptionKey);
    }
    if (!nullToAbsent || encryptionIV != null) {
      map['encryption_i_v'] = Variable<String>(encryptionIV);
    }
    if (!nullToAbsent || encryptionScheme != null) {
      map['encryption_scheme'] = Variable<String>(encryptionScheme);
    }
    if (!nullToAbsent || cipherTextHashes != null) {
      map['cipher_text_hashes'] = Variable<String>($FileMetadataTable
          .$convertercipherTextHashesn
          .toSql(cipherTextHashes));
    }
    if (!nullToAbsent || plainTextHashes != null) {
      map['plain_text_hashes'] = Variable<String>(
          $FileMetadataTable.$converterplainTextHashesn.toSql(plainTextHashes));
    }
    if (!nullToAbsent || thumbnailType != null) {
      map['thumbnail_type'] = Variable<String>(thumbnailType);
    }
    if (!nullToAbsent || thumbnailData != null) {
      map['thumbnail_data'] = Variable<String>(thumbnailData);
    }
    return map;
  }

  FileMetadataCompanion toCompanion(bool nullToAbsent) {
    return FileMetadataCompanion(
      id: Value(id),
      filename: Value(filename),
      path: path == null && nullToAbsent ? const Value.absent() : Value(path),
      sourceUrls: sourceUrls == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrls),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      width:
          width == null && nullToAbsent ? const Value.absent() : Value(width),
      height:
          height == null && nullToAbsent ? const Value.absent() : Value(height),
      encryptionKey: encryptionKey == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptionKey),
      encryptionIV: encryptionIV == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptionIV),
      encryptionScheme: encryptionScheme == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptionScheme),
      cipherTextHashes: cipherTextHashes == null && nullToAbsent
          ? const Value.absent()
          : Value(cipherTextHashes),
      plainTextHashes: plainTextHashes == null && nullToAbsent
          ? const Value.absent()
          : Value(plainTextHashes),
      thumbnailType: thumbnailType == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailType),
      thumbnailData: thumbnailData == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailData),
    );
  }

  factory FileMetadataData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileMetadataData(
      id: serializer.fromJson<String>(json['id']),
      filename: serializer.fromJson<String>(json['filename']),
      path: serializer.fromJson<String?>(json['path']),
      sourceUrls: serializer.fromJson<List<String>?>(json['sourceUrls']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      encryptionKey: serializer.fromJson<String?>(json['encryptionKey']),
      encryptionIV: serializer.fromJson<String?>(json['encryptionIV']),
      encryptionScheme: serializer.fromJson<String?>(json['encryptionScheme']),
      cipherTextHashes: serializer
          .fromJson<Map<HashFunction, String>?>(json['cipherTextHashes']),
      plainTextHashes: serializer
          .fromJson<Map<HashFunction, String>?>(json['plainTextHashes']),
      thumbnailType: serializer.fromJson<String?>(json['thumbnailType']),
      thumbnailData: serializer.fromJson<String?>(json['thumbnailData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'filename': serializer.toJson<String>(filename),
      'path': serializer.toJson<String?>(path),
      'sourceUrls': serializer.toJson<List<String>?>(sourceUrls),
      'mimeType': serializer.toJson<String?>(mimeType),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'encryptionKey': serializer.toJson<String?>(encryptionKey),
      'encryptionIV': serializer.toJson<String?>(encryptionIV),
      'encryptionScheme': serializer.toJson<String?>(encryptionScheme),
      'cipherTextHashes':
          serializer.toJson<Map<HashFunction, String>?>(cipherTextHashes),
      'plainTextHashes':
          serializer.toJson<Map<HashFunction, String>?>(plainTextHashes),
      'thumbnailType': serializer.toJson<String?>(thumbnailType),
      'thumbnailData': serializer.toJson<String?>(thumbnailData),
    };
  }

  FileMetadataData copyWith(
          {String? id,
          String? filename,
          Value<String?> path = const Value.absent(),
          Value<List<String>?> sourceUrls = const Value.absent(),
          Value<String?> mimeType = const Value.absent(),
          Value<int?> sizeBytes = const Value.absent(),
          Value<int?> width = const Value.absent(),
          Value<int?> height = const Value.absent(),
          Value<String?> encryptionKey = const Value.absent(),
          Value<String?> encryptionIV = const Value.absent(),
          Value<String?> encryptionScheme = const Value.absent(),
          Value<Map<HashFunction, String>?> cipherTextHashes =
              const Value.absent(),
          Value<Map<HashFunction, String>?> plainTextHashes =
              const Value.absent(),
          Value<String?> thumbnailType = const Value.absent(),
          Value<String?> thumbnailData = const Value.absent()}) =>
      FileMetadataData(
        id: id ?? this.id,
        filename: filename ?? this.filename,
        path: path.present ? path.value : this.path,
        sourceUrls: sourceUrls.present ? sourceUrls.value : this.sourceUrls,
        mimeType: mimeType.present ? mimeType.value : this.mimeType,
        sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
        width: width.present ? width.value : this.width,
        height: height.present ? height.value : this.height,
        encryptionKey:
            encryptionKey.present ? encryptionKey.value : this.encryptionKey,
        encryptionIV:
            encryptionIV.present ? encryptionIV.value : this.encryptionIV,
        encryptionScheme: encryptionScheme.present
            ? encryptionScheme.value
            : this.encryptionScheme,
        cipherTextHashes: cipherTextHashes.present
            ? cipherTextHashes.value
            : this.cipherTextHashes,
        plainTextHashes: plainTextHashes.present
            ? plainTextHashes.value
            : this.plainTextHashes,
        thumbnailType:
            thumbnailType.present ? thumbnailType.value : this.thumbnailType,
        thumbnailData:
            thumbnailData.present ? thumbnailData.value : this.thumbnailData,
      );
  @override
  String toString() {
    return (StringBuffer('FileMetadataData(')
          ..write('id: $id, ')
          ..write('filename: $filename, ')
          ..write('path: $path, ')
          ..write('sourceUrls: $sourceUrls, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('encryptionKey: $encryptionKey, ')
          ..write('encryptionIV: $encryptionIV, ')
          ..write('encryptionScheme: $encryptionScheme, ')
          ..write('cipherTextHashes: $cipherTextHashes, ')
          ..write('plainTextHashes: $plainTextHashes, ')
          ..write('thumbnailType: $thumbnailType, ')
          ..write('thumbnailData: $thumbnailData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      filename,
      path,
      sourceUrls,
      mimeType,
      sizeBytes,
      width,
      height,
      encryptionKey,
      encryptionIV,
      encryptionScheme,
      cipherTextHashes,
      plainTextHashes,
      thumbnailType,
      thumbnailData);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileMetadataData &&
          other.id == this.id &&
          other.filename == this.filename &&
          other.path == this.path &&
          other.sourceUrls == this.sourceUrls &&
          other.mimeType == this.mimeType &&
          other.sizeBytes == this.sizeBytes &&
          other.width == this.width &&
          other.height == this.height &&
          other.encryptionKey == this.encryptionKey &&
          other.encryptionIV == this.encryptionIV &&
          other.encryptionScheme == this.encryptionScheme &&
          other.cipherTextHashes == this.cipherTextHashes &&
          other.plainTextHashes == this.plainTextHashes &&
          other.thumbnailType == this.thumbnailType &&
          other.thumbnailData == this.thumbnailData);
}

class FileMetadataCompanion extends UpdateCompanion<FileMetadataData> {
  final Value<String> id;
  final Value<String> filename;
  final Value<String?> path;
  final Value<List<String>?> sourceUrls;
  final Value<String?> mimeType;
  final Value<int?> sizeBytes;
  final Value<int?> width;
  final Value<int?> height;
  final Value<String?> encryptionKey;
  final Value<String?> encryptionIV;
  final Value<String?> encryptionScheme;
  final Value<Map<HashFunction, String>?> cipherTextHashes;
  final Value<Map<HashFunction, String>?> plainTextHashes;
  final Value<String?> thumbnailType;
  final Value<String?> thumbnailData;
  final Value<int> rowid;
  const FileMetadataCompanion({
    this.id = const Value.absent(),
    this.filename = const Value.absent(),
    this.path = const Value.absent(),
    this.sourceUrls = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.encryptionKey = const Value.absent(),
    this.encryptionIV = const Value.absent(),
    this.encryptionScheme = const Value.absent(),
    this.cipherTextHashes = const Value.absent(),
    this.plainTextHashes = const Value.absent(),
    this.thumbnailType = const Value.absent(),
    this.thumbnailData = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FileMetadataCompanion.insert({
    this.id = const Value.absent(),
    required String filename,
    this.path = const Value.absent(),
    this.sourceUrls = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.encryptionKey = const Value.absent(),
    this.encryptionIV = const Value.absent(),
    this.encryptionScheme = const Value.absent(),
    this.cipherTextHashes = const Value.absent(),
    this.plainTextHashes = const Value.absent(),
    this.thumbnailType = const Value.absent(),
    this.thumbnailData = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : filename = Value(filename);
  static Insertable<FileMetadataData> custom({
    Expression<String>? id,
    Expression<String>? filename,
    Expression<String>? path,
    Expression<String>? sourceUrls,
    Expression<String>? mimeType,
    Expression<int>? sizeBytes,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? encryptionKey,
    Expression<String>? encryptionIV,
    Expression<String>? encryptionScheme,
    Expression<String>? cipherTextHashes,
    Expression<String>? plainTextHashes,
    Expression<String>? thumbnailType,
    Expression<String>? thumbnailData,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filename != null) 'filename': filename,
      if (path != null) 'path': path,
      if (sourceUrls != null) 'source_urls': sourceUrls,
      if (mimeType != null) 'mime_type': mimeType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (encryptionKey != null) 'encryption_key': encryptionKey,
      if (encryptionIV != null) 'encryption_i_v': encryptionIV,
      if (encryptionScheme != null) 'encryption_scheme': encryptionScheme,
      if (cipherTextHashes != null) 'cipher_text_hashes': cipherTextHashes,
      if (plainTextHashes != null) 'plain_text_hashes': plainTextHashes,
      if (thumbnailType != null) 'thumbnail_type': thumbnailType,
      if (thumbnailData != null) 'thumbnail_data': thumbnailData,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FileMetadataCompanion copyWith(
      {Value<String>? id,
      Value<String>? filename,
      Value<String?>? path,
      Value<List<String>?>? sourceUrls,
      Value<String?>? mimeType,
      Value<int?>? sizeBytes,
      Value<int?>? width,
      Value<int?>? height,
      Value<String?>? encryptionKey,
      Value<String?>? encryptionIV,
      Value<String?>? encryptionScheme,
      Value<Map<HashFunction, String>?>? cipherTextHashes,
      Value<Map<HashFunction, String>?>? plainTextHashes,
      Value<String?>? thumbnailType,
      Value<String?>? thumbnailData,
      Value<int>? rowid}) {
    return FileMetadataCompanion(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      path: path ?? this.path,
      sourceUrls: sourceUrls ?? this.sourceUrls,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      encryptionKey: encryptionKey ?? this.encryptionKey,
      encryptionIV: encryptionIV ?? this.encryptionIV,
      encryptionScheme: encryptionScheme ?? this.encryptionScheme,
      cipherTextHashes: cipherTextHashes ?? this.cipherTextHashes,
      plainTextHashes: plainTextHashes ?? this.plainTextHashes,
      thumbnailType: thumbnailType ?? this.thumbnailType,
      thumbnailData: thumbnailData ?? this.thumbnailData,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (sourceUrls.present) {
      map['source_urls'] = Variable<String>(
          $FileMetadataTable.$convertersourceUrlsn.toSql(sourceUrls.value));
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (encryptionKey.present) {
      map['encryption_key'] = Variable<String>(encryptionKey.value);
    }
    if (encryptionIV.present) {
      map['encryption_i_v'] = Variable<String>(encryptionIV.value);
    }
    if (encryptionScheme.present) {
      map['encryption_scheme'] = Variable<String>(encryptionScheme.value);
    }
    if (cipherTextHashes.present) {
      map['cipher_text_hashes'] = Variable<String>($FileMetadataTable
          .$convertercipherTextHashesn
          .toSql(cipherTextHashes.value));
    }
    if (plainTextHashes.present) {
      map['plain_text_hashes'] = Variable<String>($FileMetadataTable
          .$converterplainTextHashesn
          .toSql(plainTextHashes.value));
    }
    if (thumbnailType.present) {
      map['thumbnail_type'] = Variable<String>(thumbnailType.value);
    }
    if (thumbnailData.present) {
      map['thumbnail_data'] = Variable<String>(thumbnailData.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FileMetadataCompanion(')
          ..write('id: $id, ')
          ..write('filename: $filename, ')
          ..write('path: $path, ')
          ..write('sourceUrls: $sourceUrls, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('encryptionKey: $encryptionKey, ')
          ..write('encryptionIV: $encryptionIV, ')
          ..write('encryptionScheme: $encryptionScheme, ')
          ..write('cipherTextHashes: $cipherTextHashes, ')
          ..write('plainTextHashes: $plainTextHashes, ')
          ..write('thumbnailType: $thumbnailType, ')
          ..write('thumbnailData: $thumbnailData, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StickerPacksTable extends StickerPacks
    with TableInfo<$StickerPacksTable, StickerPack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StickerPacksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _hashAlgorithmMeta =
      const VerificationMeta('hashAlgorithm');
  @override
  late final GeneratedColumn<String> hashAlgorithm = GeneratedColumn<String>(
      'hash_algorithm', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _hashValueMeta =
      const VerificationMeta('hashValue');
  @override
  late final GeneratedColumn<String> hashValue = GeneratedColumn<String>(
      'hash_value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _restrictedMeta =
      const VerificationMeta('restricted');
  @override
  late final GeneratedColumn<bool> restricted = GeneratedColumn<bool>(
      'restricted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("restricted" IN (0, 1))'));
  static const VerificationMeta _addedTimestampMeta =
      const VerificationMeta('addedTimestamp');
  @override
  late final GeneratedColumn<DateTime> addedTimestamp =
      GeneratedColumn<DateTime>('added_timestamp', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        description,
        hashAlgorithm,
        hashValue,
        restricted,
        addedTimestamp
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sticker_packs';
  @override
  VerificationContext validateIntegrity(Insertable<StickerPack> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('hash_algorithm')) {
      context.handle(
          _hashAlgorithmMeta,
          hashAlgorithm.isAcceptableOrUnknown(
              data['hash_algorithm']!, _hashAlgorithmMeta));
    } else if (isInserting) {
      context.missing(_hashAlgorithmMeta);
    }
    if (data.containsKey('hash_value')) {
      context.handle(_hashValueMeta,
          hashValue.isAcceptableOrUnknown(data['hash_value']!, _hashValueMeta));
    } else if (isInserting) {
      context.missing(_hashValueMeta);
    }
    if (data.containsKey('restricted')) {
      context.handle(
          _restrictedMeta,
          restricted.isAcceptableOrUnknown(
              data['restricted']!, _restrictedMeta));
    } else if (isInserting) {
      context.missing(_restrictedMeta);
    }
    if (data.containsKey('added_timestamp')) {
      context.handle(
          _addedTimestampMeta,
          addedTimestamp.isAcceptableOrUnknown(
              data['added_timestamp']!, _addedTimestampMeta));
    } else if (isInserting) {
      context.missing(_addedTimestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StickerPack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StickerPack(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      hashAlgorithm: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}hash_algorithm'])!,
      hashValue: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}hash_value'])!,
      restricted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}restricted'])!,
      addedTimestamp: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}added_timestamp'])!,
    );
  }

  @override
  $StickerPacksTable createAlias(String alias) {
    return $StickerPacksTable(attachedDatabase, alias);
  }
}

class StickerPacksCompanion extends UpdateCompanion<StickerPack> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> description;
  final Value<String> hashAlgorithm;
  final Value<String> hashValue;
  final Value<bool> restricted;
  final Value<DateTime> addedTimestamp;
  final Value<int> rowid;
  const StickerPacksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.hashAlgorithm = const Value.absent(),
    this.hashValue = const Value.absent(),
    this.restricted = const Value.absent(),
    this.addedTimestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StickerPacksCompanion.insert({
    required String id,
    required String name,
    required String description,
    required String hashAlgorithm,
    required String hashValue,
    required bool restricted,
    required DateTime addedTimestamp,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        description = Value(description),
        hashAlgorithm = Value(hashAlgorithm),
        hashValue = Value(hashValue),
        restricted = Value(restricted),
        addedTimestamp = Value(addedTimestamp);
  static Insertable<StickerPack> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? hashAlgorithm,
    Expression<String>? hashValue,
    Expression<bool>? restricted,
    Expression<DateTime>? addedTimestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (hashAlgorithm != null) 'hash_algorithm': hashAlgorithm,
      if (hashValue != null) 'hash_value': hashValue,
      if (restricted != null) 'restricted': restricted,
      if (addedTimestamp != null) 'added_timestamp': addedTimestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StickerPacksCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? description,
      Value<String>? hashAlgorithm,
      Value<String>? hashValue,
      Value<bool>? restricted,
      Value<DateTime>? addedTimestamp,
      Value<int>? rowid}) {
    return StickerPacksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      hashAlgorithm: hashAlgorithm ?? this.hashAlgorithm,
      hashValue: hashValue ?? this.hashValue,
      restricted: restricted ?? this.restricted,
      addedTimestamp: addedTimestamp ?? this.addedTimestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (hashAlgorithm.present) {
      map['hash_algorithm'] = Variable<String>(hashAlgorithm.value);
    }
    if (hashValue.present) {
      map['hash_value'] = Variable<String>(hashValue.value);
    }
    if (restricted.present) {
      map['restricted'] = Variable<bool>(restricted.value);
    }
    if (addedTimestamp.present) {
      map['added_timestamp'] = Variable<DateTime>(addedTimestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StickerPacksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('hashAlgorithm: $hashAlgorithm, ')
          ..write('hashValue: $hashValue, ')
          ..write('restricted: $restricted, ')
          ..write('addedTimestamp: $addedTimestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      clientDefault: () => uuid.v4());
  static const VerificationMeta _stanzaIDMeta =
      const VerificationMeta('stanzaID');
  @override
  late final GeneratedColumn<String> stanzaID = GeneratedColumn<String>(
      'stanza_i_d', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _originIDMeta =
      const VerificationMeta('originID');
  @override
  late final GeneratedColumn<String> originID = GeneratedColumn<String>(
      'origin_i_d', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _occupantIDMeta =
      const VerificationMeta('occupantID');
  @override
  late final GeneratedColumn<String> occupantID = GeneratedColumn<String>(
      'occupant_i_d', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _myJidMeta = const VerificationMeta('myJid');
  @override
  late final GeneratedColumn<String> myJid = GeneratedColumn<String>(
      'my_jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderJidMeta =
      const VerificationMeta('senderJid');
  @override
  late final GeneratedColumn<String> senderJid = GeneratedColumn<String>(
      'sender_jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chatJidMeta =
      const VerificationMeta('chatJid');
  @override
  late final GeneratedColumn<String> chatJid = GeneratedColumn<String>(
      'chat_jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      clientDefault: () => DateTime.timestamp());
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumnWithTypeConverter<MessageError, int> error =
      GeneratedColumn<int>('error', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: const Constant(0))
          .withConverter<MessageError>($MessagesTable.$convertererror);
  static const VerificationMeta _warningMeta =
      const VerificationMeta('warning');
  @override
  late final GeneratedColumnWithTypeConverter<MessageWarning, int> warning =
      GeneratedColumn<int>('warning', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: const Constant(0))
          .withConverter<MessageWarning>($MessagesTable.$converterwarning);
  static const VerificationMeta _encryptedMeta =
      const VerificationMeta('encrypted');
  @override
  late final GeneratedColumn<bool> encrypted = GeneratedColumn<bool>(
      'encrypted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("encrypted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _noStoreMeta =
      const VerificationMeta('noStore');
  @override
  late final GeneratedColumn<bool> noStore = GeneratedColumn<bool>(
      'no_store', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("no_store" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _ackedMeta = const VerificationMeta('acked');
  @override
  late final GeneratedColumn<bool> acked = GeneratedColumn<bool>(
      'acked', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("acked" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _receivedMeta =
      const VerificationMeta('received');
  @override
  late final GeneratedColumn<bool> received = GeneratedColumn<bool>(
      'received', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("received" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _displayedMeta =
      const VerificationMeta('displayed');
  @override
  late final GeneratedColumn<bool> displayed = GeneratedColumn<bool>(
      'displayed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("displayed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _editedMeta = const VerificationMeta('edited');
  @override
  late final GeneratedColumn<bool> edited = GeneratedColumn<bool>(
      'edited', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("edited" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _retractedMeta =
      const VerificationMeta('retracted');
  @override
  late final GeneratedColumn<bool> retracted = GeneratedColumn<bool>(
      'retracted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("retracted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isFileUploadNotificationMeta =
      const VerificationMeta('isFileUploadNotification');
  @override
  late final GeneratedColumn<bool> isFileUploadNotification =
      GeneratedColumn<bool>(
          'is_file_upload_notification', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("is_file_upload_notification" IN (0, 1))'),
          defaultValue: const Constant(false));
  static const VerificationMeta _fileDownloadingMeta =
      const VerificationMeta('fileDownloading');
  @override
  late final GeneratedColumn<bool> fileDownloading = GeneratedColumn<bool>(
      'file_downloading', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("file_downloading" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _fileUploadingMeta =
      const VerificationMeta('fileUploading');
  @override
  late final GeneratedColumn<bool> fileUploading = GeneratedColumn<bool>(
      'file_uploading', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("file_uploading" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _fileMetadataIDMeta =
      const VerificationMeta('fileMetadataID');
  @override
  late final GeneratedColumn<String> fileMetadataID = GeneratedColumn<String>(
      'file_metadata_i_d', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES file_metadata (id)'));
  static const VerificationMeta _quotingMeta =
      const VerificationMeta('quoting');
  @override
  late final GeneratedColumn<String> quoting = GeneratedColumn<String>(
      'quoting', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _stickerPackIDMeta =
      const VerificationMeta('stickerPackID');
  @override
  late final GeneratedColumn<String> stickerPackID = GeneratedColumn<String>(
      'sticker_pack_i_d', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sticker_packs (id)'));
  static const VerificationMeta _pseudoMessageTypeMeta =
      const VerificationMeta('pseudoMessageType');
  @override
  late final GeneratedColumnWithTypeConverter<PseudoMessageType?, int>
      pseudoMessageType = GeneratedColumn<int>(
              'pseudo_message_type', aliasedName, true,
              type: DriftSqlType.int, requiredDuringInsert: false)
          .withConverter<PseudoMessageType?>(
              $MessagesTable.$converterpseudoMessageTypen);
  static const VerificationMeta _pseudoMessageDataMeta =
      const VerificationMeta('pseudoMessageData');
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>?, String>
      pseudoMessageData = GeneratedColumn<String>(
              'pseudo_message_data', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<Map<String, dynamic>?>(
              $MessagesTable.$converterpseudoMessageDatan);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        stanzaID,
        originID,
        occupantID,
        myJid,
        senderJid,
        chatJid,
        body,
        timestamp,
        error,
        warning,
        encrypted,
        noStore,
        acked,
        received,
        displayed,
        edited,
        retracted,
        isFileUploadNotification,
        fileDownloading,
        fileUploading,
        fileMetadataID,
        quoting,
        stickerPackID,
        pseudoMessageType,
        pseudoMessageData
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<Message> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('stanza_i_d')) {
      context.handle(_stanzaIDMeta,
          stanzaID.isAcceptableOrUnknown(data['stanza_i_d']!, _stanzaIDMeta));
    } else if (isInserting) {
      context.missing(_stanzaIDMeta);
    }
    if (data.containsKey('origin_i_d')) {
      context.handle(_originIDMeta,
          originID.isAcceptableOrUnknown(data['origin_i_d']!, _originIDMeta));
    }
    if (data.containsKey('occupant_i_d')) {
      context.handle(
          _occupantIDMeta,
          occupantID.isAcceptableOrUnknown(
              data['occupant_i_d']!, _occupantIDMeta));
    }
    if (data.containsKey('my_jid')) {
      context.handle(
          _myJidMeta, myJid.isAcceptableOrUnknown(data['my_jid']!, _myJidMeta));
    } else if (isInserting) {
      context.missing(_myJidMeta);
    }
    if (data.containsKey('sender_jid')) {
      context.handle(_senderJidMeta,
          senderJid.isAcceptableOrUnknown(data['sender_jid']!, _senderJidMeta));
    } else if (isInserting) {
      context.missing(_senderJidMeta);
    }
    if (data.containsKey('chat_jid')) {
      context.handle(_chatJidMeta,
          chatJid.isAcceptableOrUnknown(data['chat_jid']!, _chatJidMeta));
    } else if (isInserting) {
      context.missing(_chatJidMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    context.handle(_errorMeta, const VerificationResult.success());
    context.handle(_warningMeta, const VerificationResult.success());
    if (data.containsKey('encrypted')) {
      context.handle(_encryptedMeta,
          encrypted.isAcceptableOrUnknown(data['encrypted']!, _encryptedMeta));
    }
    if (data.containsKey('no_store')) {
      context.handle(_noStoreMeta,
          noStore.isAcceptableOrUnknown(data['no_store']!, _noStoreMeta));
    }
    if (data.containsKey('acked')) {
      context.handle(
          _ackedMeta, acked.isAcceptableOrUnknown(data['acked']!, _ackedMeta));
    }
    if (data.containsKey('received')) {
      context.handle(_receivedMeta,
          received.isAcceptableOrUnknown(data['received']!, _receivedMeta));
    }
    if (data.containsKey('displayed')) {
      context.handle(_displayedMeta,
          displayed.isAcceptableOrUnknown(data['displayed']!, _displayedMeta));
    }
    if (data.containsKey('edited')) {
      context.handle(_editedMeta,
          edited.isAcceptableOrUnknown(data['edited']!, _editedMeta));
    }
    if (data.containsKey('retracted')) {
      context.handle(_retractedMeta,
          retracted.isAcceptableOrUnknown(data['retracted']!, _retractedMeta));
    }
    if (data.containsKey('is_file_upload_notification')) {
      context.handle(
          _isFileUploadNotificationMeta,
          isFileUploadNotification.isAcceptableOrUnknown(
              data['is_file_upload_notification']!,
              _isFileUploadNotificationMeta));
    }
    if (data.containsKey('file_downloading')) {
      context.handle(
          _fileDownloadingMeta,
          fileDownloading.isAcceptableOrUnknown(
              data['file_downloading']!, _fileDownloadingMeta));
    }
    if (data.containsKey('file_uploading')) {
      context.handle(
          _fileUploadingMeta,
          fileUploading.isAcceptableOrUnknown(
              data['file_uploading']!, _fileUploadingMeta));
    }
    if (data.containsKey('file_metadata_i_d')) {
      context.handle(
          _fileMetadataIDMeta,
          fileMetadataID.isAcceptableOrUnknown(
              data['file_metadata_i_d']!, _fileMetadataIDMeta));
    }
    if (data.containsKey('quoting')) {
      context.handle(_quotingMeta,
          quoting.isAcceptableOrUnknown(data['quoting']!, _quotingMeta));
    }
    if (data.containsKey('sticker_pack_i_d')) {
      context.handle(
          _stickerPackIDMeta,
          stickerPackID.isAcceptableOrUnknown(
              data['sticker_pack_i_d']!, _stickerPackIDMeta));
    }
    context.handle(_pseudoMessageTypeMeta, const VerificationResult.success());
    context.handle(_pseudoMessageDataMeta, const VerificationResult.success());
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      stanzaID: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stanza_i_d'])!,
      myJid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}my_jid'])!,
      senderJid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_jid'])!,
      chatJid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_jid'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      originID: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}origin_i_d']),
      occupantID: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}occupant_i_d']),
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body']),
      error: $MessagesTable.$convertererror.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}error'])!),
      warning: $MessagesTable.$converterwarning.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}warning'])!),
      encrypted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}encrypted'])!,
      noStore: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}no_store'])!,
      acked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}acked'])!,
      received: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}received'])!,
      displayed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}displayed'])!,
      edited: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}edited'])!,
      retracted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}retracted'])!,
      isFileUploadNotification: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}is_file_upload_notification'])!,
      fileDownloading: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}file_downloading'])!,
      fileUploading: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}file_uploading'])!,
      fileMetadataID: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}file_metadata_i_d']),
      quoting: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}quoting']),
      stickerPackID: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}sticker_pack_i_d']),
      pseudoMessageType: $MessagesTable.$converterpseudoMessageTypen.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.int, data['${effectivePrefix}pseudo_message_type'])),
      pseudoMessageData: $MessagesTable.$converterpseudoMessageDatan.fromSql(
          attachedDatabase.typeMapping.read(DriftSqlType.string,
              data['${effectivePrefix}pseudo_message_data'])),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MessageError, int, int> $convertererror =
      const EnumIndexConverter<MessageError>(MessageError.values);
  static JsonTypeConverter2<MessageWarning, int, int> $converterwarning =
      const EnumIndexConverter<MessageWarning>(MessageWarning.values);
  static JsonTypeConverter2<PseudoMessageType, int, int>
      $converterpseudoMessageType =
      const EnumIndexConverter<PseudoMessageType>(PseudoMessageType.values);
  static JsonTypeConverter2<PseudoMessageType?, int?, int?>
      $converterpseudoMessageTypen =
      JsonTypeConverter2.asNullable($converterpseudoMessageType);
  static TypeConverter<Map<String, dynamic>, String>
      $converterpseudoMessageData = JsonConverter();
  static TypeConverter<Map<String, dynamic>?, String?>
      $converterpseudoMessageDatan =
      NullAwareTypeConverter.wrap($converterpseudoMessageData);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> stanzaID;
  final Value<String?> originID;
  final Value<String?> occupantID;
  final Value<String> myJid;
  final Value<String> senderJid;
  final Value<String> chatJid;
  final Value<String?> body;
  final Value<DateTime> timestamp;
  final Value<MessageError> error;
  final Value<MessageWarning> warning;
  final Value<bool> encrypted;
  final Value<bool> noStore;
  final Value<bool> acked;
  final Value<bool> received;
  final Value<bool> displayed;
  final Value<bool> edited;
  final Value<bool> retracted;
  final Value<bool> isFileUploadNotification;
  final Value<bool> fileDownloading;
  final Value<bool> fileUploading;
  final Value<String?> fileMetadataID;
  final Value<String?> quoting;
  final Value<String?> stickerPackID;
  final Value<PseudoMessageType?> pseudoMessageType;
  final Value<Map<String, dynamic>?> pseudoMessageData;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.stanzaID = const Value.absent(),
    this.originID = const Value.absent(),
    this.occupantID = const Value.absent(),
    this.myJid = const Value.absent(),
    this.senderJid = const Value.absent(),
    this.chatJid = const Value.absent(),
    this.body = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.error = const Value.absent(),
    this.warning = const Value.absent(),
    this.encrypted = const Value.absent(),
    this.noStore = const Value.absent(),
    this.acked = const Value.absent(),
    this.received = const Value.absent(),
    this.displayed = const Value.absent(),
    this.edited = const Value.absent(),
    this.retracted = const Value.absent(),
    this.isFileUploadNotification = const Value.absent(),
    this.fileDownloading = const Value.absent(),
    this.fileUploading = const Value.absent(),
    this.fileMetadataID = const Value.absent(),
    this.quoting = const Value.absent(),
    this.stickerPackID = const Value.absent(),
    this.pseudoMessageType = const Value.absent(),
    this.pseudoMessageData = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required String stanzaID,
    this.originID = const Value.absent(),
    this.occupantID = const Value.absent(),
    required String myJid,
    required String senderJid,
    required String chatJid,
    this.body = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.error = const Value.absent(),
    this.warning = const Value.absent(),
    this.encrypted = const Value.absent(),
    this.noStore = const Value.absent(),
    this.acked = const Value.absent(),
    this.received = const Value.absent(),
    this.displayed = const Value.absent(),
    this.edited = const Value.absent(),
    this.retracted = const Value.absent(),
    this.isFileUploadNotification = const Value.absent(),
    this.fileDownloading = const Value.absent(),
    this.fileUploading = const Value.absent(),
    this.fileMetadataID = const Value.absent(),
    this.quoting = const Value.absent(),
    this.stickerPackID = const Value.absent(),
    this.pseudoMessageType = const Value.absent(),
    this.pseudoMessageData = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : stanzaID = Value(stanzaID),
        myJid = Value(myJid),
        senderJid = Value(senderJid),
        chatJid = Value(chatJid);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? stanzaID,
    Expression<String>? originID,
    Expression<String>? occupantID,
    Expression<String>? myJid,
    Expression<String>? senderJid,
    Expression<String>? chatJid,
    Expression<String>? body,
    Expression<DateTime>? timestamp,
    Expression<int>? error,
    Expression<int>? warning,
    Expression<bool>? encrypted,
    Expression<bool>? noStore,
    Expression<bool>? acked,
    Expression<bool>? received,
    Expression<bool>? displayed,
    Expression<bool>? edited,
    Expression<bool>? retracted,
    Expression<bool>? isFileUploadNotification,
    Expression<bool>? fileDownloading,
    Expression<bool>? fileUploading,
    Expression<String>? fileMetadataID,
    Expression<String>? quoting,
    Expression<String>? stickerPackID,
    Expression<int>? pseudoMessageType,
    Expression<String>? pseudoMessageData,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (stanzaID != null) 'stanza_i_d': stanzaID,
      if (originID != null) 'origin_i_d': originID,
      if (occupantID != null) 'occupant_i_d': occupantID,
      if (myJid != null) 'my_jid': myJid,
      if (senderJid != null) 'sender_jid': senderJid,
      if (chatJid != null) 'chat_jid': chatJid,
      if (body != null) 'body': body,
      if (timestamp != null) 'timestamp': timestamp,
      if (error != null) 'error': error,
      if (warning != null) 'warning': warning,
      if (encrypted != null) 'encrypted': encrypted,
      if (noStore != null) 'no_store': noStore,
      if (acked != null) 'acked': acked,
      if (received != null) 'received': received,
      if (displayed != null) 'displayed': displayed,
      if (edited != null) 'edited': edited,
      if (retracted != null) 'retracted': retracted,
      if (isFileUploadNotification != null)
        'is_file_upload_notification': isFileUploadNotification,
      if (fileDownloading != null) 'file_downloading': fileDownloading,
      if (fileUploading != null) 'file_uploading': fileUploading,
      if (fileMetadataID != null) 'file_metadata_i_d': fileMetadataID,
      if (quoting != null) 'quoting': quoting,
      if (stickerPackID != null) 'sticker_pack_i_d': stickerPackID,
      if (pseudoMessageType != null) 'pseudo_message_type': pseudoMessageType,
      if (pseudoMessageData != null) 'pseudo_message_data': pseudoMessageData,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? stanzaID,
      Value<String?>? originID,
      Value<String?>? occupantID,
      Value<String>? myJid,
      Value<String>? senderJid,
      Value<String>? chatJid,
      Value<String?>? body,
      Value<DateTime>? timestamp,
      Value<MessageError>? error,
      Value<MessageWarning>? warning,
      Value<bool>? encrypted,
      Value<bool>? noStore,
      Value<bool>? acked,
      Value<bool>? received,
      Value<bool>? displayed,
      Value<bool>? edited,
      Value<bool>? retracted,
      Value<bool>? isFileUploadNotification,
      Value<bool>? fileDownloading,
      Value<bool>? fileUploading,
      Value<String?>? fileMetadataID,
      Value<String?>? quoting,
      Value<String?>? stickerPackID,
      Value<PseudoMessageType?>? pseudoMessageType,
      Value<Map<String, dynamic>?>? pseudoMessageData,
      Value<int>? rowid}) {
    return MessagesCompanion(
      id: id ?? this.id,
      stanzaID: stanzaID ?? this.stanzaID,
      originID: originID ?? this.originID,
      occupantID: occupantID ?? this.occupantID,
      myJid: myJid ?? this.myJid,
      senderJid: senderJid ?? this.senderJid,
      chatJid: chatJid ?? this.chatJid,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      encrypted: encrypted ?? this.encrypted,
      noStore: noStore ?? this.noStore,
      acked: acked ?? this.acked,
      received: received ?? this.received,
      displayed: displayed ?? this.displayed,
      edited: edited ?? this.edited,
      retracted: retracted ?? this.retracted,
      isFileUploadNotification:
          isFileUploadNotification ?? this.isFileUploadNotification,
      fileDownloading: fileDownloading ?? this.fileDownloading,
      fileUploading: fileUploading ?? this.fileUploading,
      fileMetadataID: fileMetadataID ?? this.fileMetadataID,
      quoting: quoting ?? this.quoting,
      stickerPackID: stickerPackID ?? this.stickerPackID,
      pseudoMessageType: pseudoMessageType ?? this.pseudoMessageType,
      pseudoMessageData: pseudoMessageData ?? this.pseudoMessageData,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (stanzaID.present) {
      map['stanza_i_d'] = Variable<String>(stanzaID.value);
    }
    if (originID.present) {
      map['origin_i_d'] = Variable<String>(originID.value);
    }
    if (occupantID.present) {
      map['occupant_i_d'] = Variable<String>(occupantID.value);
    }
    if (myJid.present) {
      map['my_jid'] = Variable<String>(myJid.value);
    }
    if (senderJid.present) {
      map['sender_jid'] = Variable<String>(senderJid.value);
    }
    if (chatJid.present) {
      map['chat_jid'] = Variable<String>(chatJid.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (error.present) {
      map['error'] =
          Variable<int>($MessagesTable.$convertererror.toSql(error.value));
    }
    if (warning.present) {
      map['warning'] =
          Variable<int>($MessagesTable.$converterwarning.toSql(warning.value));
    }
    if (encrypted.present) {
      map['encrypted'] = Variable<bool>(encrypted.value);
    }
    if (noStore.present) {
      map['no_store'] = Variable<bool>(noStore.value);
    }
    if (acked.present) {
      map['acked'] = Variable<bool>(acked.value);
    }
    if (received.present) {
      map['received'] = Variable<bool>(received.value);
    }
    if (displayed.present) {
      map['displayed'] = Variable<bool>(displayed.value);
    }
    if (edited.present) {
      map['edited'] = Variable<bool>(edited.value);
    }
    if (retracted.present) {
      map['retracted'] = Variable<bool>(retracted.value);
    }
    if (isFileUploadNotification.present) {
      map['is_file_upload_notification'] =
          Variable<bool>(isFileUploadNotification.value);
    }
    if (fileDownloading.present) {
      map['file_downloading'] = Variable<bool>(fileDownloading.value);
    }
    if (fileUploading.present) {
      map['file_uploading'] = Variable<bool>(fileUploading.value);
    }
    if (fileMetadataID.present) {
      map['file_metadata_i_d'] = Variable<String>(fileMetadataID.value);
    }
    if (quoting.present) {
      map['quoting'] = Variable<String>(quoting.value);
    }
    if (stickerPackID.present) {
      map['sticker_pack_i_d'] = Variable<String>(stickerPackID.value);
    }
    if (pseudoMessageType.present) {
      map['pseudo_message_type'] = Variable<int>($MessagesTable
          .$converterpseudoMessageTypen
          .toSql(pseudoMessageType.value));
    }
    if (pseudoMessageData.present) {
      map['pseudo_message_data'] = Variable<String>($MessagesTable
          .$converterpseudoMessageDatan
          .toSql(pseudoMessageData.value));
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('stanzaID: $stanzaID, ')
          ..write('originID: $originID, ')
          ..write('occupantID: $occupantID, ')
          ..write('myJid: $myJid, ')
          ..write('senderJid: $senderJid, ')
          ..write('chatJid: $chatJid, ')
          ..write('body: $body, ')
          ..write('timestamp: $timestamp, ')
          ..write('error: $error, ')
          ..write('warning: $warning, ')
          ..write('encrypted: $encrypted, ')
          ..write('noStore: $noStore, ')
          ..write('acked: $acked, ')
          ..write('received: $received, ')
          ..write('displayed: $displayed, ')
          ..write('edited: $edited, ')
          ..write('retracted: $retracted, ')
          ..write('isFileUploadNotification: $isFileUploadNotification, ')
          ..write('fileDownloading: $fileDownloading, ')
          ..write('fileUploading: $fileUploading, ')
          ..write('fileMetadataID: $fileMetadataID, ')
          ..write('quoting: $quoting, ')
          ..write('stickerPackID: $stickerPackID, ')
          ..write('pseudoMessageType: $pseudoMessageType, ')
          ..write('pseudoMessageData: $pseudoMessageData, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReactionsTable extends Reactions
    with TableInfo<$ReactionsTable, Reaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIDMeta =
      const VerificationMeta('messageID');
  @override
  late final GeneratedColumn<String> messageID = GeneratedColumn<String>(
      'message_i_d', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES messages (id)'));
  static const VerificationMeta _myJidMeta = const VerificationMeta('myJid');
  @override
  late final GeneratedColumn<String> myJid = GeneratedColumn<String>(
      'my_jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderJidMeta =
      const VerificationMeta('senderJid');
  @override
  late final GeneratedColumn<String> senderJid = GeneratedColumn<String>(
      'sender_jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
      'emoji', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [messageID, myJid, senderJid, emoji];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reactions';
  @override
  VerificationContext validateIntegrity(Insertable<Reaction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_i_d')) {
      context.handle(
          _messageIDMeta,
          messageID.isAcceptableOrUnknown(
              data['message_i_d']!, _messageIDMeta));
    } else if (isInserting) {
      context.missing(_messageIDMeta);
    }
    if (data.containsKey('my_jid')) {
      context.handle(
          _myJidMeta, myJid.isAcceptableOrUnknown(data['my_jid']!, _myJidMeta));
    } else if (isInserting) {
      context.missing(_myJidMeta);
    }
    if (data.containsKey('sender_jid')) {
      context.handle(_senderJidMeta,
          senderJid.isAcceptableOrUnknown(data['sender_jid']!, _senderJidMeta));
    } else if (isInserting) {
      context.missing(_senderJidMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
          _emojiMeta, emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta));
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageID, senderJid, emoji};
  @override
  Reaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reaction(
      messageID: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_i_d'])!,
      myJid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}my_jid'])!,
      senderJid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_jid'])!,
      emoji: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}emoji'])!,
    );
  }

  @override
  $ReactionsTable createAlias(String alias) {
    return $ReactionsTable(attachedDatabase, alias);
  }
}

class ReactionsCompanion extends UpdateCompanion<Reaction> {
  final Value<String> messageID;
  final Value<String> myJid;
  final Value<String> senderJid;
  final Value<String> emoji;
  final Value<int> rowid;
  const ReactionsCompanion({
    this.messageID = const Value.absent(),
    this.myJid = const Value.absent(),
    this.senderJid = const Value.absent(),
    this.emoji = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReactionsCompanion.insert({
    required String messageID,
    required String myJid,
    required String senderJid,
    required String emoji,
    this.rowid = const Value.absent(),
  })  : messageID = Value(messageID),
        myJid = Value(myJid),
        senderJid = Value(senderJid),
        emoji = Value(emoji);
  static Insertable<Reaction> custom({
    Expression<String>? messageID,
    Expression<String>? myJid,
    Expression<String>? senderJid,
    Expression<String>? emoji,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageID != null) 'message_i_d': messageID,
      if (myJid != null) 'my_jid': myJid,
      if (senderJid != null) 'sender_jid': senderJid,
      if (emoji != null) 'emoji': emoji,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReactionsCompanion copyWith(
      {Value<String>? messageID,
      Value<String>? myJid,
      Value<String>? senderJid,
      Value<String>? emoji,
      Value<int>? rowid}) {
    return ReactionsCompanion(
      messageID: messageID ?? this.messageID,
      myJid: myJid ?? this.myJid,
      senderJid: senderJid ?? this.senderJid,
      emoji: emoji ?? this.emoji,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageID.present) {
      map['message_i_d'] = Variable<String>(messageID.value);
    }
    if (myJid.present) {
      map['my_jid'] = Variable<String>(myJid.value);
    }
    if (senderJid.present) {
      map['sender_jid'] = Variable<String>(senderJid.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReactionsCompanion(')
          ..write('messageID: $messageID, ')
          ..write('myJid: $myJid, ')
          ..write('senderJid: $senderJid, ')
          ..write('emoji: $emoji, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationsTable extends Notifications
    with TableInfo<$NotificationsTable, Notification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _myJidMeta = const VerificationMeta('myJid');
  @override
  late final GeneratedColumn<String> myJid = GeneratedColumn<String>(
      'my_jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderJidMeta =
      const VerificationMeta('senderJid');
  @override
  late final GeneratedColumn<String> senderJid = GeneratedColumn<String>(
      'sender_jid', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _chatJidMeta =
      const VerificationMeta('chatJid');
  @override
  late final GeneratedColumn<String> chatJid = GeneratedColumn<String>(
      'chat_jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderNameMeta =
      const VerificationMeta('senderName');
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
      'sender_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _avatarPathMeta =
      const VerificationMeta('avatarPath');
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
      'avatar_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mediaMimeTypeMeta =
      const VerificationMeta('mediaMimeType');
  @override
  late final GeneratedColumn<String> mediaMimeType = GeneratedColumn<String>(
      'media_mime_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mediaPathMeta =
      const VerificationMeta('mediaPath');
  @override
  late final GeneratedColumn<String> mediaPath = GeneratedColumn<String>(
      'media_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        myJid,
        senderJid,
        chatJid,
        senderName,
        body,
        timestamp,
        avatarPath,
        mediaMimeType,
        mediaPath
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notifications';
  @override
  VerificationContext validateIntegrity(Insertable<Notification> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('my_jid')) {
      context.handle(
          _myJidMeta, myJid.isAcceptableOrUnknown(data['my_jid']!, _myJidMeta));
    } else if (isInserting) {
      context.missing(_myJidMeta);
    }
    if (data.containsKey('sender_jid')) {
      context.handle(_senderJidMeta,
          senderJid.isAcceptableOrUnknown(data['sender_jid']!, _senderJidMeta));
    }
    if (data.containsKey('chat_jid')) {
      context.handle(_chatJidMeta,
          chatJid.isAcceptableOrUnknown(data['chat_jid']!, _chatJidMeta));
    } else if (isInserting) {
      context.missing(_chatJidMeta);
    }
    if (data.containsKey('sender_name')) {
      context.handle(
          _senderNameMeta,
          senderName.isAcceptableOrUnknown(
              data['sender_name']!, _senderNameMeta));
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
          _avatarPathMeta,
          avatarPath.isAcceptableOrUnknown(
              data['avatar_path']!, _avatarPathMeta));
    }
    if (data.containsKey('media_mime_type')) {
      context.handle(
          _mediaMimeTypeMeta,
          mediaMimeType.isAcceptableOrUnknown(
              data['media_mime_type']!, _mediaMimeTypeMeta));
    }
    if (data.containsKey('media_path')) {
      context.handle(_mediaPathMeta,
          mediaPath.isAcceptableOrUnknown(data['media_path']!, _mediaPathMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Notification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Notification(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      senderJid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_jid']),
      chatJid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_jid'])!,
      senderName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_name']),
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      avatarPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_path']),
      mediaMimeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_mime_type']),
      mediaPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_path']),
    );
  }

  @override
  $NotificationsTable createAlias(String alias) {
    return $NotificationsTable(attachedDatabase, alias);
  }
}

class NotificationsCompanion extends UpdateCompanion<Notification> {
  final Value<int> id;
  final Value<String> myJid;
  final Value<String?> senderJid;
  final Value<String> chatJid;
  final Value<String?> senderName;
  final Value<String> body;
  final Value<DateTime> timestamp;
  final Value<String?> avatarPath;
  final Value<String?> mediaMimeType;
  final Value<String?> mediaPath;
  const NotificationsCompanion({
    this.id = const Value.absent(),
    this.myJid = const Value.absent(),
    this.senderJid = const Value.absent(),
    this.chatJid = const Value.absent(),
    this.senderName = const Value.absent(),
    this.body = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.mediaMimeType = const Value.absent(),
    this.mediaPath = const Value.absent(),
  });
  NotificationsCompanion.insert({
    this.id = const Value.absent(),
    required String myJid,
    this.senderJid = const Value.absent(),
    required String chatJid,
    this.senderName = const Value.absent(),
    required String body,
    required DateTime timestamp,
    this.avatarPath = const Value.absent(),
    this.mediaMimeType = const Value.absent(),
    this.mediaPath = const Value.absent(),
  })  : myJid = Value(myJid),
        chatJid = Value(chatJid),
        body = Value(body),
        timestamp = Value(timestamp);
  static Insertable<Notification> custom({
    Expression<int>? id,
    Expression<String>? myJid,
    Expression<String>? senderJid,
    Expression<String>? chatJid,
    Expression<String>? senderName,
    Expression<String>? body,
    Expression<DateTime>? timestamp,
    Expression<String>? avatarPath,
    Expression<String>? mediaMimeType,
    Expression<String>? mediaPath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (myJid != null) 'my_jid': myJid,
      if (senderJid != null) 'sender_jid': senderJid,
      if (chatJid != null) 'chat_jid': chatJid,
      if (senderName != null) 'sender_name': senderName,
      if (body != null) 'body': body,
      if (timestamp != null) 'timestamp': timestamp,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (mediaMimeType != null) 'media_mime_type': mediaMimeType,
      if (mediaPath != null) 'media_path': mediaPath,
    });
  }

  NotificationsCompanion copyWith(
      {Value<int>? id,
      Value<String>? myJid,
      Value<String?>? senderJid,
      Value<String>? chatJid,
      Value<String?>? senderName,
      Value<String>? body,
      Value<DateTime>? timestamp,
      Value<String?>? avatarPath,
      Value<String?>? mediaMimeType,
      Value<String?>? mediaPath}) {
    return NotificationsCompanion(
      id: id ?? this.id,
      myJid: myJid ?? this.myJid,
      senderJid: senderJid ?? this.senderJid,
      chatJid: chatJid ?? this.chatJid,
      senderName: senderName ?? this.senderName,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      avatarPath: avatarPath ?? this.avatarPath,
      mediaMimeType: mediaMimeType ?? this.mediaMimeType,
      mediaPath: mediaPath ?? this.mediaPath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (myJid.present) {
      map['my_jid'] = Variable<String>(myJid.value);
    }
    if (senderJid.present) {
      map['sender_jid'] = Variable<String>(senderJid.value);
    }
    if (chatJid.present) {
      map['chat_jid'] = Variable<String>(chatJid.value);
    }
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (mediaMimeType.present) {
      map['media_mime_type'] = Variable<String>(mediaMimeType.value);
    }
    if (mediaPath.present) {
      map['media_path'] = Variable<String>(mediaPath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationsCompanion(')
          ..write('id: $id, ')
          ..write('myJid: $myJid, ')
          ..write('senderJid: $senderJid, ')
          ..write('chatJid: $chatJid, ')
          ..write('senderName: $senderName, ')
          ..write('body: $body, ')
          ..write('timestamp: $timestamp, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('mediaMimeType: $mediaMimeType, ')
          ..write('mediaPath: $mediaPath')
          ..write(')'))
        .toString();
  }
}

class $ContactsTable extends Contacts with TableInfo<$ContactsTable, Contact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nativeIDMeta =
      const VerificationMeta('nativeID');
  @override
  late final GeneratedColumn<String> nativeID = GeneratedColumn<String>(
      'native_i_d', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jidMeta = const VerificationMeta('jid');
  @override
  late final GeneratedColumn<String> jid = GeneratedColumn<String>(
      'jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [nativeID, jid];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contacts';
  @override
  VerificationContext validateIntegrity(Insertable<Contact> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('native_i_d')) {
      context.handle(_nativeIDMeta,
          nativeID.isAcceptableOrUnknown(data['native_i_d']!, _nativeIDMeta));
    } else if (isInserting) {
      context.missing(_nativeIDMeta);
    }
    if (data.containsKey('jid')) {
      context.handle(
          _jidMeta, jid.isAcceptableOrUnknown(data['jid']!, _jidMeta));
    } else if (isInserting) {
      context.missing(_jidMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {nativeID};
  @override
  Contact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Contact(
      nativeID: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}native_i_d'])!,
      jid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jid'])!,
    );
  }

  @override
  $ContactsTable createAlias(String alias) {
    return $ContactsTable(attachedDatabase, alias);
  }
}

class Contact extends DataClass implements Insertable<Contact> {
  final String nativeID;
  final String jid;
  const Contact({required this.nativeID, required this.jid});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['native_i_d'] = Variable<String>(nativeID);
    map['jid'] = Variable<String>(jid);
    return map;
  }

  ContactsCompanion toCompanion(bool nullToAbsent) {
    return ContactsCompanion(
      nativeID: Value(nativeID),
      jid: Value(jid),
    );
  }

  factory Contact.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Contact(
      nativeID: serializer.fromJson<String>(json['nativeID']),
      jid: serializer.fromJson<String>(json['jid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'nativeID': serializer.toJson<String>(nativeID),
      'jid': serializer.toJson<String>(jid),
    };
  }

  Contact copyWith({String? nativeID, String? jid}) => Contact(
        nativeID: nativeID ?? this.nativeID,
        jid: jid ?? this.jid,
      );
  @override
  String toString() {
    return (StringBuffer('Contact(')
          ..write('nativeID: $nativeID, ')
          ..write('jid: $jid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(nativeID, jid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Contact &&
          other.nativeID == this.nativeID &&
          other.jid == this.jid);
}

class ContactsCompanion extends UpdateCompanion<Contact> {
  final Value<String> nativeID;
  final Value<String> jid;
  final Value<int> rowid;
  const ContactsCompanion({
    this.nativeID = const Value.absent(),
    this.jid = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsCompanion.insert({
    required String nativeID,
    required String jid,
    this.rowid = const Value.absent(),
  })  : nativeID = Value(nativeID),
        jid = Value(jid);
  static Insertable<Contact> custom({
    Expression<String>? nativeID,
    Expression<String>? jid,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (nativeID != null) 'native_i_d': nativeID,
      if (jid != null) 'jid': jid,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsCompanion copyWith(
      {Value<String>? nativeID, Value<String>? jid, Value<int>? rowid}) {
    return ContactsCompanion(
      nativeID: nativeID ?? this.nativeID,
      jid: jid ?? this.jid,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (nativeID.present) {
      map['native_i_d'] = Variable<String>(nativeID.value);
    }
    if (jid.present) {
      map['jid'] = Variable<String>(jid.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsCompanion(')
          ..write('nativeID: $nativeID, ')
          ..write('jid: $jid, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatsTable extends Chats with TableInfo<$ChatsTable, Chat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _jidMeta = const VerificationMeta('jid');
  @override
  late final GeneratedColumn<String> jid = GeneratedColumn<String>(
      'jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _myJidMeta = const VerificationMeta('myJid');
  @override
  late final GeneratedColumn<String> myJid = GeneratedColumn<String>(
      'my_jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _myNicknameMeta =
      const VerificationMeta('myNickname');
  @override
  late final GeneratedColumn<String> myNickname = GeneratedColumn<String>(
      'my_nickname', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumnWithTypeConverter<ChatType, int> type =
      GeneratedColumn<int>('type', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<ChatType>($ChatsTable.$convertertype);
  static const VerificationMeta _avatarPathMeta =
      const VerificationMeta('avatarPath');
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
      'avatar_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _avatarHashMeta =
      const VerificationMeta('avatarHash');
  @override
  late final GeneratedColumn<String> avatarHash = GeneratedColumn<String>(
      'avatar_hash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastMessageMeta =
      const VerificationMeta('lastMessage');
  @override
  late final GeneratedColumn<String> lastMessage = GeneratedColumn<String>(
      'last_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastChangeTimestampMeta =
      const VerificationMeta('lastChangeTimestamp');
  @override
  late final GeneratedColumn<DateTime> lastChangeTimestamp =
      GeneratedColumn<DateTime>('last_change_timestamp', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _unreadCountMeta =
      const VerificationMeta('unreadCount');
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
      'unread_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _openMeta = const VerificationMeta('open');
  @override
  late final GeneratedColumn<bool> open = GeneratedColumn<bool>(
      'open', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("open" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _mutedMeta = const VerificationMeta('muted');
  @override
  late final GeneratedColumn<bool> muted = GeneratedColumn<bool>(
      'muted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("muted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _encryptedMeta =
      const VerificationMeta('encrypted');
  @override
  late final GeneratedColumn<bool> encrypted = GeneratedColumn<bool>(
      'encrypted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("encrypted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _favouritedMeta =
      const VerificationMeta('favourited');
  @override
  late final GeneratedColumn<bool> favourited = GeneratedColumn<bool>(
      'favourited', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("favourited" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _contactIDMeta =
      const VerificationMeta('contactID');
  @override
  late final GeneratedColumn<String> contactID = GeneratedColumn<String>(
      'contact_i_d', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES contacts (native_i_d)'));
  static const VerificationMeta _contactDisplayNameMeta =
      const VerificationMeta('contactDisplayName');
  @override
  late final GeneratedColumn<String> contactDisplayName =
      GeneratedColumn<String>('contact_display_name', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactAvatarPathMeta =
      const VerificationMeta('contactAvatarPath');
  @override
  late final GeneratedColumn<String> contactAvatarPath =
      GeneratedColumn<String>('contact_avatar_path', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactAvatarHashMeta =
      const VerificationMeta('contactAvatarHash');
  @override
  late final GeneratedColumn<String> contactAvatarHash =
      GeneratedColumn<String>('contact_avatar_hash', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        jid,
        myJid,
        myNickname,
        title,
        type,
        avatarPath,
        avatarHash,
        lastMessage,
        lastChangeTimestamp,
        unreadCount,
        open,
        muted,
        encrypted,
        favourited,
        contactID,
        contactDisplayName,
        contactAvatarPath,
        contactAvatarHash
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chats';
  @override
  VerificationContext validateIntegrity(Insertable<Chat> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('jid')) {
      context.handle(
          _jidMeta, jid.isAcceptableOrUnknown(data['jid']!, _jidMeta));
    } else if (isInserting) {
      context.missing(_jidMeta);
    }
    if (data.containsKey('my_jid')) {
      context.handle(
          _myJidMeta, myJid.isAcceptableOrUnknown(data['my_jid']!, _myJidMeta));
    } else if (isInserting) {
      context.missing(_myJidMeta);
    }
    if (data.containsKey('my_nickname')) {
      context.handle(
          _myNicknameMeta,
          myNickname.isAcceptableOrUnknown(
              data['my_nickname']!, _myNicknameMeta));
    } else if (isInserting) {
      context.missing(_myNicknameMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    context.handle(_typeMeta, const VerificationResult.success());
    if (data.containsKey('avatar_path')) {
      context.handle(
          _avatarPathMeta,
          avatarPath.isAcceptableOrUnknown(
              data['avatar_path']!, _avatarPathMeta));
    }
    if (data.containsKey('avatar_hash')) {
      context.handle(
          _avatarHashMeta,
          avatarHash.isAcceptableOrUnknown(
              data['avatar_hash']!, _avatarHashMeta));
    }
    if (data.containsKey('last_message')) {
      context.handle(
          _lastMessageMeta,
          lastMessage.isAcceptableOrUnknown(
              data['last_message']!, _lastMessageMeta));
    }
    if (data.containsKey('last_change_timestamp')) {
      context.handle(
          _lastChangeTimestampMeta,
          lastChangeTimestamp.isAcceptableOrUnknown(
              data['last_change_timestamp']!, _lastChangeTimestampMeta));
    } else if (isInserting) {
      context.missing(_lastChangeTimestampMeta);
    }
    if (data.containsKey('unread_count')) {
      context.handle(
          _unreadCountMeta,
          unreadCount.isAcceptableOrUnknown(
              data['unread_count']!, _unreadCountMeta));
    }
    if (data.containsKey('open')) {
      context.handle(
          _openMeta, open.isAcceptableOrUnknown(data['open']!, _openMeta));
    }
    if (data.containsKey('muted')) {
      context.handle(
          _mutedMeta, muted.isAcceptableOrUnknown(data['muted']!, _mutedMeta));
    }
    if (data.containsKey('encrypted')) {
      context.handle(_encryptedMeta,
          encrypted.isAcceptableOrUnknown(data['encrypted']!, _encryptedMeta));
    }
    if (data.containsKey('favourited')) {
      context.handle(
          _favouritedMeta,
          favourited.isAcceptableOrUnknown(
              data['favourited']!, _favouritedMeta));
    }
    if (data.containsKey('contact_i_d')) {
      context.handle(
          _contactIDMeta,
          contactID.isAcceptableOrUnknown(
              data['contact_i_d']!, _contactIDMeta));
    }
    if (data.containsKey('contact_display_name')) {
      context.handle(
          _contactDisplayNameMeta,
          contactDisplayName.isAcceptableOrUnknown(
              data['contact_display_name']!, _contactDisplayNameMeta));
    }
    if (data.containsKey('contact_avatar_path')) {
      context.handle(
          _contactAvatarPathMeta,
          contactAvatarPath.isAcceptableOrUnknown(
              data['contact_avatar_path']!, _contactAvatarPathMeta));
    }
    if (data.containsKey('contact_avatar_hash')) {
      context.handle(
          _contactAvatarHashMeta,
          contactAvatarHash.isAcceptableOrUnknown(
              data['contact_avatar_hash']!, _contactAvatarHashMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {jid};
  @override
  Chat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chat.fromDb(
      jid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jid'])!,
      myJid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}my_jid'])!,
      myNickname: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}my_nickname'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      type: $ChatsTable.$convertertype.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!),
      avatarPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_path']),
      avatarHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_hash']),
      lastMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_message']),
      lastChangeTimestamp: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}last_change_timestamp'])!,
      unreadCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unread_count'])!,
      open: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}open'])!,
      muted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}muted'])!,
      encrypted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}encrypted'])!,
      favourited: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}favourited'])!,
      contactID: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_i_d']),
      contactDisplayName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}contact_display_name']),
      contactAvatarPath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}contact_avatar_path']),
      contactAvatarHash: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}contact_avatar_hash']),
    );
  }

  @override
  $ChatsTable createAlias(String alias) {
    return $ChatsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ChatType, int, int> $convertertype =
      const EnumIndexConverter<ChatType>(ChatType.values);
}

class ChatsCompanion extends UpdateCompanion<Chat> {
  final Value<String> jid;
  final Value<String> myJid;
  final Value<String> myNickname;
  final Value<String> title;
  final Value<ChatType> type;
  final Value<String?> avatarPath;
  final Value<String?> avatarHash;
  final Value<String?> lastMessage;
  final Value<DateTime> lastChangeTimestamp;
  final Value<int> unreadCount;
  final Value<bool> open;
  final Value<bool> muted;
  final Value<bool> encrypted;
  final Value<bool> favourited;
  final Value<String?> contactID;
  final Value<String?> contactDisplayName;
  final Value<String?> contactAvatarPath;
  final Value<String?> contactAvatarHash;
  final Value<int> rowid;
  const ChatsCompanion({
    this.jid = const Value.absent(),
    this.myJid = const Value.absent(),
    this.myNickname = const Value.absent(),
    this.title = const Value.absent(),
    this.type = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.avatarHash = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.lastChangeTimestamp = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.open = const Value.absent(),
    this.muted = const Value.absent(),
    this.encrypted = const Value.absent(),
    this.favourited = const Value.absent(),
    this.contactID = const Value.absent(),
    this.contactDisplayName = const Value.absent(),
    this.contactAvatarPath = const Value.absent(),
    this.contactAvatarHash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatsCompanion.insert({
    required String jid,
    required String myJid,
    required String myNickname,
    required String title,
    required ChatType type,
    this.avatarPath = const Value.absent(),
    this.avatarHash = const Value.absent(),
    this.lastMessage = const Value.absent(),
    required DateTime lastChangeTimestamp,
    this.unreadCount = const Value.absent(),
    this.open = const Value.absent(),
    this.muted = const Value.absent(),
    this.encrypted = const Value.absent(),
    this.favourited = const Value.absent(),
    this.contactID = const Value.absent(),
    this.contactDisplayName = const Value.absent(),
    this.contactAvatarPath = const Value.absent(),
    this.contactAvatarHash = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : jid = Value(jid),
        myJid = Value(myJid),
        myNickname = Value(myNickname),
        title = Value(title),
        type = Value(type),
        lastChangeTimestamp = Value(lastChangeTimestamp);
  static Insertable<Chat> custom({
    Expression<String>? jid,
    Expression<String>? myJid,
    Expression<String>? myNickname,
    Expression<String>? title,
    Expression<int>? type,
    Expression<String>? avatarPath,
    Expression<String>? avatarHash,
    Expression<String>? lastMessage,
    Expression<DateTime>? lastChangeTimestamp,
    Expression<int>? unreadCount,
    Expression<bool>? open,
    Expression<bool>? muted,
    Expression<bool>? encrypted,
    Expression<bool>? favourited,
    Expression<String>? contactID,
    Expression<String>? contactDisplayName,
    Expression<String>? contactAvatarPath,
    Expression<String>? contactAvatarHash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (jid != null) 'jid': jid,
      if (myJid != null) 'my_jid': myJid,
      if (myNickname != null) 'my_nickname': myNickname,
      if (title != null) 'title': title,
      if (type != null) 'type': type,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (avatarHash != null) 'avatar_hash': avatarHash,
      if (lastMessage != null) 'last_message': lastMessage,
      if (lastChangeTimestamp != null)
        'last_change_timestamp': lastChangeTimestamp,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (open != null) 'open': open,
      if (muted != null) 'muted': muted,
      if (encrypted != null) 'encrypted': encrypted,
      if (favourited != null) 'favourited': favourited,
      if (contactID != null) 'contact_i_d': contactID,
      if (contactDisplayName != null)
        'contact_display_name': contactDisplayName,
      if (contactAvatarPath != null) 'contact_avatar_path': contactAvatarPath,
      if (contactAvatarHash != null) 'contact_avatar_hash': contactAvatarHash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatsCompanion copyWith(
      {Value<String>? jid,
      Value<String>? myJid,
      Value<String>? myNickname,
      Value<String>? title,
      Value<ChatType>? type,
      Value<String?>? avatarPath,
      Value<String?>? avatarHash,
      Value<String?>? lastMessage,
      Value<DateTime>? lastChangeTimestamp,
      Value<int>? unreadCount,
      Value<bool>? open,
      Value<bool>? muted,
      Value<bool>? encrypted,
      Value<bool>? favourited,
      Value<String?>? contactID,
      Value<String?>? contactDisplayName,
      Value<String?>? contactAvatarPath,
      Value<String?>? contactAvatarHash,
      Value<int>? rowid}) {
    return ChatsCompanion(
      jid: jid ?? this.jid,
      myJid: myJid ?? this.myJid,
      myNickname: myNickname ?? this.myNickname,
      title: title ?? this.title,
      type: type ?? this.type,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarHash: avatarHash ?? this.avatarHash,
      lastMessage: lastMessage ?? this.lastMessage,
      lastChangeTimestamp: lastChangeTimestamp ?? this.lastChangeTimestamp,
      unreadCount: unreadCount ?? this.unreadCount,
      open: open ?? this.open,
      muted: muted ?? this.muted,
      encrypted: encrypted ?? this.encrypted,
      favourited: favourited ?? this.favourited,
      contactID: contactID ?? this.contactID,
      contactDisplayName: contactDisplayName ?? this.contactDisplayName,
      contactAvatarPath: contactAvatarPath ?? this.contactAvatarPath,
      contactAvatarHash: contactAvatarHash ?? this.contactAvatarHash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (jid.present) {
      map['jid'] = Variable<String>(jid.value);
    }
    if (myJid.present) {
      map['my_jid'] = Variable<String>(myJid.value);
    }
    if (myNickname.present) {
      map['my_nickname'] = Variable<String>(myNickname.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (type.present) {
      map['type'] = Variable<int>($ChatsTable.$convertertype.toSql(type.value));
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (avatarHash.present) {
      map['avatar_hash'] = Variable<String>(avatarHash.value);
    }
    if (lastMessage.present) {
      map['last_message'] = Variable<String>(lastMessage.value);
    }
    if (lastChangeTimestamp.present) {
      map['last_change_timestamp'] =
          Variable<DateTime>(lastChangeTimestamp.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (open.present) {
      map['open'] = Variable<bool>(open.value);
    }
    if (muted.present) {
      map['muted'] = Variable<bool>(muted.value);
    }
    if (encrypted.present) {
      map['encrypted'] = Variable<bool>(encrypted.value);
    }
    if (favourited.present) {
      map['favourited'] = Variable<bool>(favourited.value);
    }
    if (contactID.present) {
      map['contact_i_d'] = Variable<String>(contactID.value);
    }
    if (contactDisplayName.present) {
      map['contact_display_name'] = Variable<String>(contactDisplayName.value);
    }
    if (contactAvatarPath.present) {
      map['contact_avatar_path'] = Variable<String>(contactAvatarPath.value);
    }
    if (contactAvatarHash.present) {
      map['contact_avatar_hash'] = Variable<String>(contactAvatarHash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatsCompanion(')
          ..write('jid: $jid, ')
          ..write('myJid: $myJid, ')
          ..write('myNickname: $myNickname, ')
          ..write('title: $title, ')
          ..write('type: $type, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('avatarHash: $avatarHash, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastChangeTimestamp: $lastChangeTimestamp, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('open: $open, ')
          ..write('muted: $muted, ')
          ..write('encrypted: $encrypted, ')
          ..write('favourited: $favourited, ')
          ..write('contactID: $contactID, ')
          ..write('contactDisplayName: $contactDisplayName, ')
          ..write('contactAvatarPath: $contactAvatarPath, ')
          ..write('contactAvatarHash: $contactAvatarHash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RosterTable extends Roster with TableInfo<$RosterTable, RosterItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RosterTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _jidMeta = const VerificationMeta('jid');
  @override
  late final GeneratedColumn<String> jid = GeneratedColumn<String>(
      'jid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES chats (jid) ON DELETE CASCADE'));
  static const VerificationMeta _myJidMeta = const VerificationMeta('myJid');
  @override
  late final GeneratedColumn<String> myJid = GeneratedColumn<String>(
      'my_jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _presenceMeta =
      const VerificationMeta('presence');
  @override
  late final GeneratedColumnWithTypeConverter<Presence, String> presence =
      GeneratedColumn<String>('presence', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<Presence>($RosterTable.$converterpresence);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _avatarPathMeta =
      const VerificationMeta('avatarPath');
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
      'avatar_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _avatarHashMeta =
      const VerificationMeta('avatarHash');
  @override
  late final GeneratedColumn<String> avatarHash = GeneratedColumn<String>(
      'avatar_hash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _subscriptionMeta =
      const VerificationMeta('subscription');
  @override
  late final GeneratedColumnWithTypeConverter<Subscription, String>
      subscription = GeneratedColumn<String>('subscription', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<Subscription>($RosterTable.$convertersubscription);
  static const VerificationMeta _askMeta = const VerificationMeta('ask');
  @override
  late final GeneratedColumnWithTypeConverter<Ask?, String> ask =
      GeneratedColumn<String>('ask', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<Ask?>($RosterTable.$converteraskn);
  static const VerificationMeta _contactIDMeta =
      const VerificationMeta('contactID');
  @override
  late final GeneratedColumn<String> contactID = GeneratedColumn<String>(
      'contact_i_d', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES contacts (native_i_d)'));
  static const VerificationMeta _contactAvatarPathMeta =
      const VerificationMeta('contactAvatarPath');
  @override
  late final GeneratedColumn<String> contactAvatarPath =
      GeneratedColumn<String>('contact_avatar_path', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactDisplayNameMeta =
      const VerificationMeta('contactDisplayName');
  @override
  late final GeneratedColumn<String> contactDisplayName =
      GeneratedColumn<String>('contact_display_name', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        jid,
        myJid,
        title,
        presence,
        status,
        avatarPath,
        avatarHash,
        subscription,
        ask,
        contactID,
        contactAvatarPath,
        contactDisplayName
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'roster';
  @override
  VerificationContext validateIntegrity(Insertable<RosterItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('jid')) {
      context.handle(
          _jidMeta, jid.isAcceptableOrUnknown(data['jid']!, _jidMeta));
    } else if (isInserting) {
      context.missing(_jidMeta);
    }
    if (data.containsKey('my_jid')) {
      context.handle(
          _myJidMeta, myJid.isAcceptableOrUnknown(data['my_jid']!, _myJidMeta));
    } else if (isInserting) {
      context.missing(_myJidMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    context.handle(_presenceMeta, const VerificationResult.success());
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
          _avatarPathMeta,
          avatarPath.isAcceptableOrUnknown(
              data['avatar_path']!, _avatarPathMeta));
    }
    if (data.containsKey('avatar_hash')) {
      context.handle(
          _avatarHashMeta,
          avatarHash.isAcceptableOrUnknown(
              data['avatar_hash']!, _avatarHashMeta));
    }
    context.handle(_subscriptionMeta, const VerificationResult.success());
    context.handle(_askMeta, const VerificationResult.success());
    if (data.containsKey('contact_i_d')) {
      context.handle(
          _contactIDMeta,
          contactID.isAcceptableOrUnknown(
              data['contact_i_d']!, _contactIDMeta));
    }
    if (data.containsKey('contact_avatar_path')) {
      context.handle(
          _contactAvatarPathMeta,
          contactAvatarPath.isAcceptableOrUnknown(
              data['contact_avatar_path']!, _contactAvatarPathMeta));
    }
    if (data.containsKey('contact_display_name')) {
      context.handle(
          _contactDisplayNameMeta,
          contactDisplayName.isAcceptableOrUnknown(
              data['contact_display_name']!, _contactDisplayNameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {jid};
  @override
  RosterItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RosterItem.fromDb(
      jid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jid'])!,
      myJid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}my_jid'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      presence: $RosterTable.$converterpresence.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}presence'])!),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status']),
      avatarPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_path']),
      avatarHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_hash']),
      subscription: $RosterTable.$convertersubscription.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subscription'])!),
      ask: $RosterTable.$converteraskn.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ask'])),
      contactID: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_i_d']),
      contactAvatarPath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}contact_avatar_path']),
      contactDisplayName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}contact_display_name']),
    );
  }

  @override
  $RosterTable createAlias(String alias) {
    return $RosterTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Presence, String, String> $converterpresence =
      const EnumNameConverter<Presence>(Presence.values);
  static JsonTypeConverter2<Subscription, String, String>
      $convertersubscription =
      const EnumNameConverter<Subscription>(Subscription.values);
  static JsonTypeConverter2<Ask, String, String> $converterask =
      const EnumNameConverter<Ask>(Ask.values);
  static JsonTypeConverter2<Ask?, String?, String?> $converteraskn =
      JsonTypeConverter2.asNullable($converterask);
}

class RosterCompanion extends UpdateCompanion<RosterItem> {
  final Value<String> jid;
  final Value<String> myJid;
  final Value<String> title;
  final Value<Presence> presence;
  final Value<String?> status;
  final Value<String?> avatarPath;
  final Value<String?> avatarHash;
  final Value<Subscription> subscription;
  final Value<Ask?> ask;
  final Value<String?> contactID;
  final Value<String?> contactAvatarPath;
  final Value<String?> contactDisplayName;
  final Value<int> rowid;
  const RosterCompanion({
    this.jid = const Value.absent(),
    this.myJid = const Value.absent(),
    this.title = const Value.absent(),
    this.presence = const Value.absent(),
    this.status = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.avatarHash = const Value.absent(),
    this.subscription = const Value.absent(),
    this.ask = const Value.absent(),
    this.contactID = const Value.absent(),
    this.contactAvatarPath = const Value.absent(),
    this.contactDisplayName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RosterCompanion.insert({
    required String jid,
    required String myJid,
    required String title,
    required Presence presence,
    this.status = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.avatarHash = const Value.absent(),
    required Subscription subscription,
    this.ask = const Value.absent(),
    this.contactID = const Value.absent(),
    this.contactAvatarPath = const Value.absent(),
    this.contactDisplayName = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : jid = Value(jid),
        myJid = Value(myJid),
        title = Value(title),
        presence = Value(presence),
        subscription = Value(subscription);
  static Insertable<RosterItem> custom({
    Expression<String>? jid,
    Expression<String>? myJid,
    Expression<String>? title,
    Expression<String>? presence,
    Expression<String>? status,
    Expression<String>? avatarPath,
    Expression<String>? avatarHash,
    Expression<String>? subscription,
    Expression<String>? ask,
    Expression<String>? contactID,
    Expression<String>? contactAvatarPath,
    Expression<String>? contactDisplayName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (jid != null) 'jid': jid,
      if (myJid != null) 'my_jid': myJid,
      if (title != null) 'title': title,
      if (presence != null) 'presence': presence,
      if (status != null) 'status': status,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (avatarHash != null) 'avatar_hash': avatarHash,
      if (subscription != null) 'subscription': subscription,
      if (ask != null) 'ask': ask,
      if (contactID != null) 'contact_i_d': contactID,
      if (contactAvatarPath != null) 'contact_avatar_path': contactAvatarPath,
      if (contactDisplayName != null)
        'contact_display_name': contactDisplayName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RosterCompanion copyWith(
      {Value<String>? jid,
      Value<String>? myJid,
      Value<String>? title,
      Value<Presence>? presence,
      Value<String?>? status,
      Value<String?>? avatarPath,
      Value<String?>? avatarHash,
      Value<Subscription>? subscription,
      Value<Ask?>? ask,
      Value<String?>? contactID,
      Value<String?>? contactAvatarPath,
      Value<String?>? contactDisplayName,
      Value<int>? rowid}) {
    return RosterCompanion(
      jid: jid ?? this.jid,
      myJid: myJid ?? this.myJid,
      title: title ?? this.title,
      presence: presence ?? this.presence,
      status: status ?? this.status,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarHash: avatarHash ?? this.avatarHash,
      subscription: subscription ?? this.subscription,
      ask: ask ?? this.ask,
      contactID: contactID ?? this.contactID,
      contactAvatarPath: contactAvatarPath ?? this.contactAvatarPath,
      contactDisplayName: contactDisplayName ?? this.contactDisplayName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (jid.present) {
      map['jid'] = Variable<String>(jid.value);
    }
    if (myJid.present) {
      map['my_jid'] = Variable<String>(myJid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (presence.present) {
      map['presence'] = Variable<String>(
          $RosterTable.$converterpresence.toSql(presence.value));
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (avatarHash.present) {
      map['avatar_hash'] = Variable<String>(avatarHash.value);
    }
    if (subscription.present) {
      map['subscription'] = Variable<String>(
          $RosterTable.$convertersubscription.toSql(subscription.value));
    }
    if (ask.present) {
      map['ask'] =
          Variable<String>($RosterTable.$converteraskn.toSql(ask.value));
    }
    if (contactID.present) {
      map['contact_i_d'] = Variable<String>(contactID.value);
    }
    if (contactAvatarPath.present) {
      map['contact_avatar_path'] = Variable<String>(contactAvatarPath.value);
    }
    if (contactDisplayName.present) {
      map['contact_display_name'] = Variable<String>(contactDisplayName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RosterCompanion(')
          ..write('jid: $jid, ')
          ..write('myJid: $myJid, ')
          ..write('title: $title, ')
          ..write('presence: $presence, ')
          ..write('status: $status, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('avatarHash: $avatarHash, ')
          ..write('subscription: $subscription, ')
          ..write('ask: $ask, ')
          ..write('contactID: $contactID, ')
          ..write('contactAvatarPath: $contactAvatarPath, ')
          ..write('contactDisplayName: $contactDisplayName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InvitesTable extends Invites with TableInfo<$InvitesTable, Invite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvitesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _jidMeta = const VerificationMeta('jid');
  @override
  late final GeneratedColumn<String> jid = GeneratedColumn<String>(
      'jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _myJidMeta = const VerificationMeta('myJid');
  @override
  late final GeneratedColumn<String> myJid = GeneratedColumn<String>(
      'my_jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [jid, myJid, title];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'invites';
  @override
  VerificationContext validateIntegrity(Insertable<Invite> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('jid')) {
      context.handle(
          _jidMeta, jid.isAcceptableOrUnknown(data['jid']!, _jidMeta));
    } else if (isInserting) {
      context.missing(_jidMeta);
    }
    if (data.containsKey('my_jid')) {
      context.handle(
          _myJidMeta, myJid.isAcceptableOrUnknown(data['my_jid']!, _myJidMeta));
    } else if (isInserting) {
      context.missing(_myJidMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {jid};
  @override
  Invite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Invite(
      jid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jid'])!,
      myJid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}my_jid'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
    );
  }

  @override
  $InvitesTable createAlias(String alias) {
    return $InvitesTable(attachedDatabase, alias);
  }
}

class InvitesCompanion extends UpdateCompanion<Invite> {
  final Value<String> jid;
  final Value<String> myJid;
  final Value<String> title;
  final Value<int> rowid;
  const InvitesCompanion({
    this.jid = const Value.absent(),
    this.myJid = const Value.absent(),
    this.title = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvitesCompanion.insert({
    required String jid,
    required String myJid,
    required String title,
    this.rowid = const Value.absent(),
  })  : jid = Value(jid),
        myJid = Value(myJid),
        title = Value(title);
  static Insertable<Invite> custom({
    Expression<String>? jid,
    Expression<String>? myJid,
    Expression<String>? title,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (jid != null) 'jid': jid,
      if (myJid != null) 'my_jid': myJid,
      if (title != null) 'title': title,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvitesCompanion copyWith(
      {Value<String>? jid,
      Value<String>? myJid,
      Value<String>? title,
      Value<int>? rowid}) {
    return InvitesCompanion(
      jid: jid ?? this.jid,
      myJid: myJid ?? this.myJid,
      title: title ?? this.title,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (jid.present) {
      map['jid'] = Variable<String>(jid.value);
    }
    if (myJid.present) {
      map['my_jid'] = Variable<String>(myJid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvitesCompanion(')
          ..write('jid: $jid, ')
          ..write('myJid: $myJid, ')
          ..write('title: $title, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlocklistTable extends Blocklist
    with TableInfo<$BlocklistTable, BlocklistData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlocklistTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _jidMeta = const VerificationMeta('jid');
  @override
  late final GeneratedColumn<String> jid = GeneratedColumn<String>(
      'jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [jid];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blocklist';
  @override
  VerificationContext validateIntegrity(Insertable<BlocklistData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('jid')) {
      context.handle(
          _jidMeta, jid.isAcceptableOrUnknown(data['jid']!, _jidMeta));
    } else if (isInserting) {
      context.missing(_jidMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {jid};
  @override
  BlocklistData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlocklistData(
      jid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jid'])!,
    );
  }

  @override
  $BlocklistTable createAlias(String alias) {
    return $BlocklistTable(attachedDatabase, alias);
  }
}

class BlocklistData extends DataClass implements Insertable<BlocklistData> {
  final String jid;
  const BlocklistData({required this.jid});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['jid'] = Variable<String>(jid);
    return map;
  }

  BlocklistCompanion toCompanion(bool nullToAbsent) {
    return BlocklistCompanion(
      jid: Value(jid),
    );
  }

  factory BlocklistData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlocklistData(
      jid: serializer.fromJson<String>(json['jid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'jid': serializer.toJson<String>(jid),
    };
  }

  BlocklistData copyWith({String? jid}) => BlocklistData(
        jid: jid ?? this.jid,
      );
  @override
  String toString() {
    return (StringBuffer('BlocklistData(')
          ..write('jid: $jid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => jid.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlocklistData && other.jid == this.jid);
}

class BlocklistCompanion extends UpdateCompanion<BlocklistData> {
  final Value<String> jid;
  final Value<int> rowid;
  const BlocklistCompanion({
    this.jid = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlocklistCompanion.insert({
    required String jid,
    this.rowid = const Value.absent(),
  }) : jid = Value(jid);
  static Insertable<BlocklistData> custom({
    Expression<String>? jid,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (jid != null) 'jid': jid,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlocklistCompanion copyWith({Value<String>? jid, Value<int>? rowid}) {
    return BlocklistCompanion(
      jid: jid ?? this.jid,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (jid.present) {
      map['jid'] = Variable<String>(jid.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlocklistCompanion(')
          ..write('jid: $jid, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StickersTable extends Stickers with TableInfo<$StickersTable, Sticker> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StickersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stickerPackIDMeta =
      const VerificationMeta('stickerPackID');
  @override
  late final GeneratedColumn<String> stickerPackID = GeneratedColumn<String>(
      'sticker_pack_i_d', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sticker_packs (id)'));
  static const VerificationMeta _fileMetadataIDMeta =
      const VerificationMeta('fileMetadataID');
  @override
  late final GeneratedColumn<String> fileMetadataID = GeneratedColumn<String>(
      'file_metadata_i_d', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES file_metadata (id)'));
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _suggestionsMeta =
      const VerificationMeta('suggestions');
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, String>, String>
      suggestions = GeneratedColumn<String>('suggestions', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<Map<String, String>>(
              $StickersTable.$convertersuggestions);
  @override
  List<GeneratedColumn> get $columns =>
      [id, stickerPackID, fileMetadataID, description, suggestions];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stickers';
  @override
  VerificationContext validateIntegrity(Insertable<Sticker> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sticker_pack_i_d')) {
      context.handle(
          _stickerPackIDMeta,
          stickerPackID.isAcceptableOrUnknown(
              data['sticker_pack_i_d']!, _stickerPackIDMeta));
    } else if (isInserting) {
      context.missing(_stickerPackIDMeta);
    }
    if (data.containsKey('file_metadata_i_d')) {
      context.handle(
          _fileMetadataIDMeta,
          fileMetadataID.isAcceptableOrUnknown(
              data['file_metadata_i_d']!, _fileMetadataIDMeta));
    } else if (isInserting) {
      context.missing(_fileMetadataIDMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    context.handle(_suggestionsMeta, const VerificationResult.success());
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sticker map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sticker(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      stickerPackID: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}sticker_pack_i_d'])!,
      fileMetadataID: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}file_metadata_i_d'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      suggestions: $StickersTable.$convertersuggestions.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}suggestions'])!),
    );
  }

  @override
  $StickersTable createAlias(String alias) {
    return $StickersTable(attachedDatabase, alias);
  }

  static TypeConverter<Map<String, String>, String> $convertersuggestions =
      JsonConverter();
}

class StickersCompanion extends UpdateCompanion<Sticker> {
  final Value<String> id;
  final Value<String> stickerPackID;
  final Value<String> fileMetadataID;
  final Value<String> description;
  final Value<Map<String, String>> suggestions;
  final Value<int> rowid;
  const StickersCompanion({
    this.id = const Value.absent(),
    this.stickerPackID = const Value.absent(),
    this.fileMetadataID = const Value.absent(),
    this.description = const Value.absent(),
    this.suggestions = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StickersCompanion.insert({
    required String id,
    required String stickerPackID,
    required String fileMetadataID,
    required String description,
    required Map<String, String> suggestions,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        stickerPackID = Value(stickerPackID),
        fileMetadataID = Value(fileMetadataID),
        description = Value(description),
        suggestions = Value(suggestions);
  static Insertable<Sticker> custom({
    Expression<String>? id,
    Expression<String>? stickerPackID,
    Expression<String>? fileMetadataID,
    Expression<String>? description,
    Expression<String>? suggestions,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (stickerPackID != null) 'sticker_pack_i_d': stickerPackID,
      if (fileMetadataID != null) 'file_metadata_i_d': fileMetadataID,
      if (description != null) 'description': description,
      if (suggestions != null) 'suggestions': suggestions,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StickersCompanion copyWith(
      {Value<String>? id,
      Value<String>? stickerPackID,
      Value<String>? fileMetadataID,
      Value<String>? description,
      Value<Map<String, String>>? suggestions,
      Value<int>? rowid}) {
    return StickersCompanion(
      id: id ?? this.id,
      stickerPackID: stickerPackID ?? this.stickerPackID,
      fileMetadataID: fileMetadataID ?? this.fileMetadataID,
      description: description ?? this.description,
      suggestions: suggestions ?? this.suggestions,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (stickerPackID.present) {
      map['sticker_pack_i_d'] = Variable<String>(stickerPackID.value);
    }
    if (fileMetadataID.present) {
      map['file_metadata_i_d'] = Variable<String>(fileMetadataID.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (suggestions.present) {
      map['suggestions'] = Variable<String>(
          $StickersTable.$convertersuggestions.toSql(suggestions.value));
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StickersCompanion(')
          ..write('id: $id, ')
          ..write('stickerPackID: $stickerPackID, ')
          ..write('fileMetadataID: $fileMetadataID, ')
          ..write('description: $description, ')
          ..write('suggestions: $suggestions, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$XmppDatabase extends GeneratedDatabase {
  _$XmppDatabase(QueryExecutor e) : super(e);
  _$XmppDatabaseManager get managers => _$XmppDatabaseManager(this);
  late final $FileMetadataTable fileMetadata = $FileMetadataTable(this);
  late final $StickerPacksTable stickerPacks = $StickerPacksTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $ReactionsTable reactions = $ReactionsTable(this);
  late final $NotificationsTable notifications = $NotificationsTable(this);
  late final $ContactsTable contacts = $ContactsTable(this);
  late final $ChatsTable chats = $ChatsTable(this);
  late final $RosterTable roster = $RosterTable(this);
  late final $InvitesTable invites = $InvitesTable(this);
  late final $BlocklistTable blocklist = $BlocklistTable(this);
  late final $StickersTable stickers = $StickersTable(this);
  late final MessagesAccessor messagesAccessor =
      MessagesAccessor(this as XmppDatabase);
  late final FileMetadataAccessor fileMetadataAccessor =
      FileMetadataAccessor(this as XmppDatabase);
  late final ChatsAccessor chatsAccessor = ChatsAccessor(this as XmppDatabase);
  late final RosterAccessor rosterAccessor =
      RosterAccessor(this as XmppDatabase);
  late final InvitesAccessor invitesAccessor =
      InvitesAccessor(this as XmppDatabase);
  late final BlocklistAccessor blocklistAccessor =
      BlocklistAccessor(this as XmppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        fileMetadata,
        stickerPacks,
        messages,
        reactions,
        notifications,
        contacts,
        chats,
        roster,
        invites,
        blocklist,
        stickers
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('chats',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('roster', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$FileMetadataTableInsertCompanionBuilder = FileMetadataCompanion
    Function({
  Value<String> id,
  required String filename,
  Value<String?> path,
  Value<List<String>?> sourceUrls,
  Value<String?> mimeType,
  Value<int?> sizeBytes,
  Value<int?> width,
  Value<int?> height,
  Value<String?> encryptionKey,
  Value<String?> encryptionIV,
  Value<String?> encryptionScheme,
  Value<Map<HashFunction, String>?> cipherTextHashes,
  Value<Map<HashFunction, String>?> plainTextHashes,
  Value<String?> thumbnailType,
  Value<String?> thumbnailData,
  Value<int> rowid,
});
typedef $$FileMetadataTableUpdateCompanionBuilder = FileMetadataCompanion
    Function({
  Value<String> id,
  Value<String> filename,
  Value<String?> path,
  Value<List<String>?> sourceUrls,
  Value<String?> mimeType,
  Value<int?> sizeBytes,
  Value<int?> width,
  Value<int?> height,
  Value<String?> encryptionKey,
  Value<String?> encryptionIV,
  Value<String?> encryptionScheme,
  Value<Map<HashFunction, String>?> cipherTextHashes,
  Value<Map<HashFunction, String>?> plainTextHashes,
  Value<String?> thumbnailType,
  Value<String?> thumbnailData,
  Value<int> rowid,
});

class $$FileMetadataTableTableManager extends RootTableManager<
    _$XmppDatabase,
    $FileMetadataTable,
    FileMetadataData,
    $$FileMetadataTableFilterComposer,
    $$FileMetadataTableOrderingComposer,
    $$FileMetadataTableProcessedTableManager,
    $$FileMetadataTableInsertCompanionBuilder,
    $$FileMetadataTableUpdateCompanionBuilder> {
  $$FileMetadataTableTableManager(_$XmppDatabase db, $FileMetadataTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$FileMetadataTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$FileMetadataTableOrderingComposer(ComposerState(db, table)),
          getChildManagerBuilder: (p) =>
              $$FileMetadataTableProcessedTableManager(p),
          getUpdateCompanionBuilder: ({
            Value<String> id = const Value.absent(),
            Value<String> filename = const Value.absent(),
            Value<String?> path = const Value.absent(),
            Value<List<String>?> sourceUrls = const Value.absent(),
            Value<String?> mimeType = const Value.absent(),
            Value<int?> sizeBytes = const Value.absent(),
            Value<int?> width = const Value.absent(),
            Value<int?> height = const Value.absent(),
            Value<String?> encryptionKey = const Value.absent(),
            Value<String?> encryptionIV = const Value.absent(),
            Value<String?> encryptionScheme = const Value.absent(),
            Value<Map<HashFunction, String>?> cipherTextHashes =
                const Value.absent(),
            Value<Map<HashFunction, String>?> plainTextHashes =
                const Value.absent(),
            Value<String?> thumbnailType = const Value.absent(),
            Value<String?> thumbnailData = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FileMetadataCompanion(
            id: id,
            filename: filename,
            path: path,
            sourceUrls: sourceUrls,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            width: width,
            height: height,
            encryptionKey: encryptionKey,
            encryptionIV: encryptionIV,
            encryptionScheme: encryptionScheme,
            cipherTextHashes: cipherTextHashes,
            plainTextHashes: plainTextHashes,
            thumbnailType: thumbnailType,
            thumbnailData: thumbnailData,
            rowid: rowid,
          ),
          getInsertCompanionBuilder: ({
            Value<String> id = const Value.absent(),
            required String filename,
            Value<String?> path = const Value.absent(),
            Value<List<String>?> sourceUrls = const Value.absent(),
            Value<String?> mimeType = const Value.absent(),
            Value<int?> sizeBytes = const Value.absent(),
            Value<int?> width = const Value.absent(),
            Value<int?> height = const Value.absent(),
            Value<String?> encryptionKey = const Value.absent(),
            Value<String?> encryptionIV = const Value.absent(),
            Value<String?> encryptionScheme = const Value.absent(),
            Value<Map<HashFunction, String>?> cipherTextHashes =
                const Value.absent(),
            Value<Map<HashFunction, String>?> plainTextHashes =
                const Value.absent(),
            Value<String?> thumbnailType = const Value.absent(),
            Value<String?> thumbnailData = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FileMetadataCompanion.insert(
            id: id,
            filename: filename,
            path: path,
            sourceUrls: sourceUrls,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            width: width,
            height: height,
            encryptionKey: encryptionKey,
            encryptionIV: encryptionIV,
            encryptionScheme: encryptionScheme,
            cipherTextHashes: cipherTextHashes,
            plainTextHashes: plainTextHashes,
            thumbnailType: thumbnailType,
            thumbnailData: thumbnailData,
            rowid: rowid,
          ),
        ));
}

class $$FileMetadataTableProcessedTableManager extends ProcessedTableManager<
    _$XmppDatabase,
    $FileMetadataTable,
    FileMetadataData,
    $$FileMetadataTableFilterComposer,
    $$FileMetadataTableOrderingComposer,
    $$FileMetadataTableProcessedTableManager,
    $$FileMetadataTableInsertCompanionBuilder,
    $$FileMetadataTableUpdateCompanionBuilder> {
  $$FileMetadataTableProcessedTableManager(super.$state);
}

class $$FileMetadataTableFilterComposer
    extends FilterComposer<_$XmppDatabase, $FileMetadataTable> {
  $$FileMetadataTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get filename => $state.composableBuilder(
      column: $state.table.filename,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get path => $state.composableBuilder(
      column: $state.table.path,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<List<String>?, List<String>, String>
      get sourceUrls => $state.composableBuilder(
          column: $state.table.sourceUrls,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));

  ColumnFilters<String> get mimeType => $state.composableBuilder(
      column: $state.table.mimeType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sizeBytes => $state.composableBuilder(
      column: $state.table.sizeBytes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get width => $state.composableBuilder(
      column: $state.table.width,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get height => $state.composableBuilder(
      column: $state.table.height,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get encryptionKey => $state.composableBuilder(
      column: $state.table.encryptionKey,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get encryptionIV => $state.composableBuilder(
      column: $state.table.encryptionIV,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get encryptionScheme => $state.composableBuilder(
      column: $state.table.encryptionScheme,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<Map<HashFunction, String>?,
          Map<HashFunction, String>, String>
      get cipherTextHashes => $state.composableBuilder(
          column: $state.table.cipherTextHashes,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<Map<HashFunction, String>?,
          Map<HashFunction, String>, String>
      get plainTextHashes => $state.composableBuilder(
          column: $state.table.plainTextHashes,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));

  ColumnFilters<String> get thumbnailType => $state.composableBuilder(
      column: $state.table.thumbnailType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get thumbnailData => $state.composableBuilder(
      column: $state.table.thumbnailData,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$FileMetadataTableOrderingComposer
    extends OrderingComposer<_$XmppDatabase, $FileMetadataTable> {
  $$FileMetadataTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get filename => $state.composableBuilder(
      column: $state.table.filename,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get path => $state.composableBuilder(
      column: $state.table.path,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get sourceUrls => $state.composableBuilder(
      column: $state.table.sourceUrls,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get mimeType => $state.composableBuilder(
      column: $state.table.mimeType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sizeBytes => $state.composableBuilder(
      column: $state.table.sizeBytes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get width => $state.composableBuilder(
      column: $state.table.width,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get height => $state.composableBuilder(
      column: $state.table.height,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get encryptionKey => $state.composableBuilder(
      column: $state.table.encryptionKey,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get encryptionIV => $state.composableBuilder(
      column: $state.table.encryptionIV,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get encryptionScheme => $state.composableBuilder(
      column: $state.table.encryptionScheme,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get cipherTextHashes => $state.composableBuilder(
      column: $state.table.cipherTextHashes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get plainTextHashes => $state.composableBuilder(
      column: $state.table.plainTextHashes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get thumbnailType => $state.composableBuilder(
      column: $state.table.thumbnailType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get thumbnailData => $state.composableBuilder(
      column: $state.table.thumbnailData,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$ContactsTableInsertCompanionBuilder = ContactsCompanion Function({
  required String nativeID,
  required String jid,
  Value<int> rowid,
});
typedef $$ContactsTableUpdateCompanionBuilder = ContactsCompanion Function({
  Value<String> nativeID,
  Value<String> jid,
  Value<int> rowid,
});

class $$ContactsTableTableManager extends RootTableManager<
    _$XmppDatabase,
    $ContactsTable,
    Contact,
    $$ContactsTableFilterComposer,
    $$ContactsTableOrderingComposer,
    $$ContactsTableProcessedTableManager,
    $$ContactsTableInsertCompanionBuilder,
    $$ContactsTableUpdateCompanionBuilder> {
  $$ContactsTableTableManager(_$XmppDatabase db, $ContactsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ContactsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ContactsTableOrderingComposer(ComposerState(db, table)),
          getChildManagerBuilder: (p) =>
              $$ContactsTableProcessedTableManager(p),
          getUpdateCompanionBuilder: ({
            Value<String> nativeID = const Value.absent(),
            Value<String> jid = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ContactsCompanion(
            nativeID: nativeID,
            jid: jid,
            rowid: rowid,
          ),
          getInsertCompanionBuilder: ({
            required String nativeID,
            required String jid,
            Value<int> rowid = const Value.absent(),
          }) =>
              ContactsCompanion.insert(
            nativeID: nativeID,
            jid: jid,
            rowid: rowid,
          ),
        ));
}

class $$ContactsTableProcessedTableManager extends ProcessedTableManager<
    _$XmppDatabase,
    $ContactsTable,
    Contact,
    $$ContactsTableFilterComposer,
    $$ContactsTableOrderingComposer,
    $$ContactsTableProcessedTableManager,
    $$ContactsTableInsertCompanionBuilder,
    $$ContactsTableUpdateCompanionBuilder> {
  $$ContactsTableProcessedTableManager(super.$state);
}

class $$ContactsTableFilterComposer
    extends FilterComposer<_$XmppDatabase, $ContactsTable> {
  $$ContactsTableFilterComposer(super.$state);
  ColumnFilters<String> get nativeID => $state.composableBuilder(
      column: $state.table.nativeID,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get jid => $state.composableBuilder(
      column: $state.table.jid,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$ContactsTableOrderingComposer
    extends OrderingComposer<_$XmppDatabase, $ContactsTable> {
  $$ContactsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get nativeID => $state.composableBuilder(
      column: $state.table.nativeID,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get jid => $state.composableBuilder(
      column: $state.table.jid,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$BlocklistTableInsertCompanionBuilder = BlocklistCompanion Function({
  required String jid,
  Value<int> rowid,
});
typedef $$BlocklistTableUpdateCompanionBuilder = BlocklistCompanion Function({
  Value<String> jid,
  Value<int> rowid,
});

class $$BlocklistTableTableManager extends RootTableManager<
    _$XmppDatabase,
    $BlocklistTable,
    BlocklistData,
    $$BlocklistTableFilterComposer,
    $$BlocklistTableOrderingComposer,
    $$BlocklistTableProcessedTableManager,
    $$BlocklistTableInsertCompanionBuilder,
    $$BlocklistTableUpdateCompanionBuilder> {
  $$BlocklistTableTableManager(_$XmppDatabase db, $BlocklistTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$BlocklistTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$BlocklistTableOrderingComposer(ComposerState(db, table)),
          getChildManagerBuilder: (p) =>
              $$BlocklistTableProcessedTableManager(p),
          getUpdateCompanionBuilder: ({
            Value<String> jid = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BlocklistCompanion(
            jid: jid,
            rowid: rowid,
          ),
          getInsertCompanionBuilder: ({
            required String jid,
            Value<int> rowid = const Value.absent(),
          }) =>
              BlocklistCompanion.insert(
            jid: jid,
            rowid: rowid,
          ),
        ));
}

class $$BlocklistTableProcessedTableManager extends ProcessedTableManager<
    _$XmppDatabase,
    $BlocklistTable,
    BlocklistData,
    $$BlocklistTableFilterComposer,
    $$BlocklistTableOrderingComposer,
    $$BlocklistTableProcessedTableManager,
    $$BlocklistTableInsertCompanionBuilder,
    $$BlocklistTableUpdateCompanionBuilder> {
  $$BlocklistTableProcessedTableManager(super.$state);
}

class $$BlocklistTableFilterComposer
    extends FilterComposer<_$XmppDatabase, $BlocklistTable> {
  $$BlocklistTableFilterComposer(super.$state);
  ColumnFilters<String> get jid => $state.composableBuilder(
      column: $state.table.jid,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$BlocklistTableOrderingComposer
    extends OrderingComposer<_$XmppDatabase, $BlocklistTable> {
  $$BlocklistTableOrderingComposer(super.$state);
  ColumnOrderings<String> get jid => $state.composableBuilder(
      column: $state.table.jid,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class _$XmppDatabaseManager {
  final _$XmppDatabase _db;
  _$XmppDatabaseManager(this._db);
  $$FileMetadataTableTableManager get fileMetadata =>
      $$FileMetadataTableTableManager(_db, _db.fileMetadata);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db, _db.contacts);
  $$BlocklistTableTableManager get blocklist =>
      $$BlocklistTableTableManager(_db, _db.blocklist);
}
