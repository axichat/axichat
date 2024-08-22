// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: implicit_dynamic_parameter

part of 'database.dart';

// ignore_for_file: type=lint
mixin _$MessagesAccessorMixin on DatabaseAccessor<XmppDrift> {
  $FileMetadataTable get fileMetadata => attachedDatabase.fileMetadata;
  $StickerPacksTable get stickerPacks => attachedDatabase.stickerPacks;
  $MessagesTable get messages => attachedDatabase.messages;
}
mixin _$DraftsAccessorMixin on DatabaseAccessor<XmppDrift> {
  $FileMetadataTable get fileMetadata => attachedDatabase.fileMetadata;
  $DraftsTable get drafts => attachedDatabase.drafts;
}
mixin _$OmemoDevicesAccessorMixin on DatabaseAccessor<XmppDrift> {
  $OmemoDevicesTable get omemoDevices => attachedDatabase.omemoDevices;
}
mixin _$OmemoDeviceListsAccessorMixin on DatabaseAccessor<XmppDrift> {
  $OmemoDeviceListsTable get omemoDeviceLists =>
      attachedDatabase.omemoDeviceLists;
}
mixin _$OmemoRatchetsAccessorMixin on DatabaseAccessor<XmppDrift> {
  $OmemoRatchetsTable get omemoRatchets => attachedDatabase.omemoRatchets;
}
mixin _$FileMetadataAccessorMixin on DatabaseAccessor<XmppDrift> {
  $FileMetadataTable get fileMetadata => attachedDatabase.fileMetadata;
}
mixin _$ChatsAccessorMixin on DatabaseAccessor<XmppDrift> {
  $ContactsTable get contacts => attachedDatabase.contacts;
  $ChatsTable get chats => attachedDatabase.chats;
}
mixin _$RosterAccessorMixin on DatabaseAccessor<XmppDrift> {
  $ContactsTable get contacts => attachedDatabase.contacts;
  $RosterTable get roster => attachedDatabase.roster;
}
mixin _$InvitesAccessorMixin on DatabaseAccessor<XmppDrift> {
  $InvitesTable get invites => attachedDatabase.invites;
}
mixin _$BlocklistAccessorMixin on DatabaseAccessor<XmppDrift> {
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
  static const VerificationMeta _encryptionProtocolMeta =
      const VerificationMeta('encryptionProtocol');
  @override
  late final GeneratedColumnWithTypeConverter<EncryptionProtocol, int>
      encryptionProtocol = GeneratedColumn<int>(
              'encryption_protocol', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: const Constant(0))
          .withConverter<EncryptionProtocol>(
              $MessagesTable.$converterencryptionProtocol);
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
        senderJid,
        chatJid,
        body,
        timestamp,
        error,
        warning,
        encryptionProtocol,
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
    context.handle(_encryptionProtocolMeta, const VerificationResult.success());
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
  Set<GeneratedColumn> get $primaryKey => {stanzaID};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      stanzaID: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stanza_i_d'])!,
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
      encryptionProtocol: $MessagesTable.$converterencryptionProtocol.fromSql(
          attachedDatabase.typeMapping.read(DriftSqlType.int,
              data['${effectivePrefix}encryption_protocol'])!),
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
  static JsonTypeConverter2<EncryptionProtocol, int, int>
      $converterencryptionProtocol =
      const EnumIndexConverter<EncryptionProtocol>(EncryptionProtocol.values);
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
  final Value<String> senderJid;
  final Value<String> chatJid;
  final Value<String?> body;
  final Value<DateTime> timestamp;
  final Value<MessageError> error;
  final Value<MessageWarning> warning;
  final Value<EncryptionProtocol> encryptionProtocol;
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
    this.senderJid = const Value.absent(),
    this.chatJid = const Value.absent(),
    this.body = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.error = const Value.absent(),
    this.warning = const Value.absent(),
    this.encryptionProtocol = const Value.absent(),
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
    required String senderJid,
    required String chatJid,
    this.body = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.error = const Value.absent(),
    this.warning = const Value.absent(),
    this.encryptionProtocol = const Value.absent(),
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
        senderJid = Value(senderJid),
        chatJid = Value(chatJid);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? stanzaID,
    Expression<String>? originID,
    Expression<String>? occupantID,
    Expression<String>? senderJid,
    Expression<String>? chatJid,
    Expression<String>? body,
    Expression<DateTime>? timestamp,
    Expression<int>? error,
    Expression<int>? warning,
    Expression<int>? encryptionProtocol,
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
      if (senderJid != null) 'sender_jid': senderJid,
      if (chatJid != null) 'chat_jid': chatJid,
      if (body != null) 'body': body,
      if (timestamp != null) 'timestamp': timestamp,
      if (error != null) 'error': error,
      if (warning != null) 'warning': warning,
      if (encryptionProtocol != null) 'encryption_protocol': encryptionProtocol,
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
      Value<String>? senderJid,
      Value<String>? chatJid,
      Value<String?>? body,
      Value<DateTime>? timestamp,
      Value<MessageError>? error,
      Value<MessageWarning>? warning,
      Value<EncryptionProtocol>? encryptionProtocol,
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
      senderJid: senderJid ?? this.senderJid,
      chatJid: chatJid ?? this.chatJid,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      encryptionProtocol: encryptionProtocol ?? this.encryptionProtocol,
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
    if (encryptionProtocol.present) {
      map['encryption_protocol'] = Variable<int>($MessagesTable
          .$converterencryptionProtocol
          .toSql(encryptionProtocol.value));
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
          ..write('senderJid: $senderJid, ')
          ..write('chatJid: $chatJid, ')
          ..write('body: $body, ')
          ..write('timestamp: $timestamp, ')
          ..write('error: $error, ')
          ..write('warning: $warning, ')
          ..write('encryptionProtocol: $encryptionProtocol, ')
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

class $DraftsTable extends Drafts with TableInfo<$DraftsTable, Draft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _jidsMeta = const VerificationMeta('jids');
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> jids =
      GeneratedColumn<String>('jids', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<String>>($DraftsTable.$converterjids);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileMetadataIDMeta =
      const VerificationMeta('fileMetadataID');
  @override
  late final GeneratedColumn<String> fileMetadataID = GeneratedColumn<String>(
      'file_metadata_i_d', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES file_metadata (id)'));
  @override
  List<GeneratedColumn> get $columns => [id, jids, body, fileMetadataID];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(Insertable<Draft> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    context.handle(_jidsMeta, const VerificationResult.success());
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    }
    if (data.containsKey('file_metadata_i_d')) {
      context.handle(
          _fileMetadataIDMeta,
          fileMetadataID.isAcceptableOrUnknown(
              data['file_metadata_i_d']!, _fileMetadataIDMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Draft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Draft(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      jids: $DraftsTable.$converterjids.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jids'])!),
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body']),
      fileMetadataID: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}file_metadata_i_d']),
    );
  }

  @override
  $DraftsTable createAlias(String alias) {
    return $DraftsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterjids = ListConverter();
}

class Draft extends DataClass implements Insertable<Draft> {
  final int id;
  final List<String> jids;
  final String? body;
  final String? fileMetadataID;
  const Draft(
      {required this.id, required this.jids, this.body, this.fileMetadataID});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['jids'] = Variable<String>($DraftsTable.$converterjids.toSql(jids));
    }
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || fileMetadataID != null) {
      map['file_metadata_i_d'] = Variable<String>(fileMetadataID);
    }
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(
      id: Value(id),
      jids: Value(jids),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      fileMetadataID: fileMetadataID == null && nullToAbsent
          ? const Value.absent()
          : Value(fileMetadataID),
    );
  }

  factory Draft.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Draft(
      id: serializer.fromJson<int>(json['id']),
      jids: serializer.fromJson<List<String>>(json['jids']),
      body: serializer.fromJson<String?>(json['body']),
      fileMetadataID: serializer.fromJson<String?>(json['fileMetadataID']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'jids': serializer.toJson<List<String>>(jids),
      'body': serializer.toJson<String?>(body),
      'fileMetadataID': serializer.toJson<String?>(fileMetadataID),
    };
  }

  Draft copyWith(
          {int? id,
          List<String>? jids,
          Value<String?> body = const Value.absent(),
          Value<String?> fileMetadataID = const Value.absent()}) =>
      Draft(
        id: id ?? this.id,
        jids: jids ?? this.jids,
        body: body.present ? body.value : this.body,
        fileMetadataID:
            fileMetadataID.present ? fileMetadataID.value : this.fileMetadataID,
      );
  @override
  String toString() {
    return (StringBuffer('Draft(')
          ..write('id: $id, ')
          ..write('jids: $jids, ')
          ..write('body: $body, ')
          ..write('fileMetadataID: $fileMetadataID')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, jids, body, fileMetadataID);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Draft &&
          other.id == this.id &&
          other.jids == this.jids &&
          other.body == this.body &&
          other.fileMetadataID == this.fileMetadataID);
}

class DraftsCompanion extends UpdateCompanion<Draft> {
  final Value<int> id;
  final Value<List<String>> jids;
  final Value<String?> body;
  final Value<String?> fileMetadataID;
  const DraftsCompanion({
    this.id = const Value.absent(),
    this.jids = const Value.absent(),
    this.body = const Value.absent(),
    this.fileMetadataID = const Value.absent(),
  });
  DraftsCompanion.insert({
    this.id = const Value.absent(),
    required List<String> jids,
    this.body = const Value.absent(),
    this.fileMetadataID = const Value.absent(),
  }) : jids = Value(jids);
  static Insertable<Draft> custom({
    Expression<int>? id,
    Expression<String>? jids,
    Expression<String>? body,
    Expression<String>? fileMetadataID,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (jids != null) 'jids': jids,
      if (body != null) 'body': body,
      if (fileMetadataID != null) 'file_metadata_i_d': fileMetadataID,
    });
  }

  DraftsCompanion copyWith(
      {Value<int>? id,
      Value<List<String>>? jids,
      Value<String?>? body,
      Value<String?>? fileMetadataID}) {
    return DraftsCompanion(
      id: id ?? this.id,
      jids: jids ?? this.jids,
      body: body ?? this.body,
      fileMetadataID: fileMetadataID ?? this.fileMetadataID,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (jids.present) {
      map['jids'] =
          Variable<String>($DraftsTable.$converterjids.toSql(jids.value));
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (fileMetadataID.present) {
      map['file_metadata_i_d'] = Variable<String>(fileMetadataID.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('id: $id, ')
          ..write('jids: $jids, ')
          ..write('body: $body, ')
          ..write('fileMetadataID: $fileMetadataID')
          ..write(')'))
        .toString();
  }
}

class $OmemoDevicesTable extends OmemoDevices
    with TableInfo<$OmemoDevicesTable, OmemoDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OmemoDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _jidMeta = const VerificationMeta('jid');
  @override
  late final GeneratedColumn<String> jid = GeneratedColumn<String>(
      'jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _identityKeyMeta =
      const VerificationMeta('identityKey');
  @override
  late final GeneratedColumn<String> identityKey = GeneratedColumn<String>(
      'identity_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _signedPreKeyMeta =
      const VerificationMeta('signedPreKey');
  @override
  late final GeneratedColumn<String> signedPreKey = GeneratedColumn<String>(
      'signed_pre_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _oldSignedPreKeyMeta =
      const VerificationMeta('oldSignedPreKey');
  @override
  late final GeneratedColumn<String> oldSignedPreKey = GeneratedColumn<String>(
      'old_signed_pre_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _trustMeta = const VerificationMeta('trust');
  @override
  late final GeneratedColumnWithTypeConverter<BTBVTrustState, int> trust =
      GeneratedColumn<int>('trust', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: const Constant(2))
          .withConverter<BTBVTrustState>($OmemoDevicesTable.$convertertrust);
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _onetimePreKeysMeta =
      const VerificationMeta('onetimePreKeys');
  @override
  late final GeneratedColumn<String> onetimePreKeys = GeneratedColumn<String>(
      'onetime_pre_keys', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        jid,
        id,
        identityKey,
        signedPreKey,
        oldSignedPreKey,
        trust,
        enabled,
        onetimePreKeys
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'omemo_devices';
  @override
  VerificationContext validateIntegrity(Insertable<OmemoDevice> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('jid')) {
      context.handle(
          _jidMeta, jid.isAcceptableOrUnknown(data['jid']!, _jidMeta));
    } else if (isInserting) {
      context.missing(_jidMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('identity_key')) {
      context.handle(
          _identityKeyMeta,
          identityKey.isAcceptableOrUnknown(
              data['identity_key']!, _identityKeyMeta));
    } else if (isInserting) {
      context.missing(_identityKeyMeta);
    }
    if (data.containsKey('signed_pre_key')) {
      context.handle(
          _signedPreKeyMeta,
          signedPreKey.isAcceptableOrUnknown(
              data['signed_pre_key']!, _signedPreKeyMeta));
    } else if (isInserting) {
      context.missing(_signedPreKeyMeta);
    }
    if (data.containsKey('old_signed_pre_key')) {
      context.handle(
          _oldSignedPreKeyMeta,
          oldSignedPreKey.isAcceptableOrUnknown(
              data['old_signed_pre_key']!, _oldSignedPreKeyMeta));
    }
    context.handle(_trustMeta, const VerificationResult.success());
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('onetime_pre_keys')) {
      context.handle(
          _onetimePreKeysMeta,
          onetimePreKeys.isAcceptableOrUnknown(
              data['onetime_pre_keys']!, _onetimePreKeysMeta));
    } else if (isInserting) {
      context.missing(_onetimePreKeysMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {jid};
  @override
  OmemoDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OmemoDevice.fromDb(
      jid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jid'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      identityKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}identity_key'])!,
      signedPreKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}signed_pre_key'])!,
      oldSignedPreKey: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}old_signed_pre_key']),
      trust: $OmemoDevicesTable.$convertertrust.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trust'])!),
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      onetimePreKeys: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}onetime_pre_keys'])!,
    );
  }

  @override
  $OmemoDevicesTable createAlias(String alias) {
    return $OmemoDevicesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BTBVTrustState, int, int> $convertertrust =
      const EnumIndexConverter<omemo.BTBVTrustState>(
          omemo.BTBVTrustState.values);
}

class OmemoDevicesCompanion extends UpdateCompanion<OmemoDevice> {
  final Value<String> jid;
  final Value<int> id;
  final Value<String> identityKey;
  final Value<String> signedPreKey;
  final Value<String?> oldSignedPreKey;
  final Value<BTBVTrustState> trust;
  final Value<bool> enabled;
  final Value<String> onetimePreKeys;
  final Value<int> rowid;
  const OmemoDevicesCompanion({
    this.jid = const Value.absent(),
    this.id = const Value.absent(),
    this.identityKey = const Value.absent(),
    this.signedPreKey = const Value.absent(),
    this.oldSignedPreKey = const Value.absent(),
    this.trust = const Value.absent(),
    this.enabled = const Value.absent(),
    this.onetimePreKeys = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OmemoDevicesCompanion.insert({
    required String jid,
    required int id,
    required String identityKey,
    required String signedPreKey,
    this.oldSignedPreKey = const Value.absent(),
    this.trust = const Value.absent(),
    this.enabled = const Value.absent(),
    required String onetimePreKeys,
    this.rowid = const Value.absent(),
  })  : jid = Value(jid),
        id = Value(id),
        identityKey = Value(identityKey),
        signedPreKey = Value(signedPreKey),
        onetimePreKeys = Value(onetimePreKeys);
  static Insertable<OmemoDevice> custom({
    Expression<String>? jid,
    Expression<int>? id,
    Expression<String>? identityKey,
    Expression<String>? signedPreKey,
    Expression<String>? oldSignedPreKey,
    Expression<int>? trust,
    Expression<bool>? enabled,
    Expression<String>? onetimePreKeys,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (jid != null) 'jid': jid,
      if (id != null) 'id': id,
      if (identityKey != null) 'identity_key': identityKey,
      if (signedPreKey != null) 'signed_pre_key': signedPreKey,
      if (oldSignedPreKey != null) 'old_signed_pre_key': oldSignedPreKey,
      if (trust != null) 'trust': trust,
      if (enabled != null) 'enabled': enabled,
      if (onetimePreKeys != null) 'onetime_pre_keys': onetimePreKeys,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OmemoDevicesCompanion copyWith(
      {Value<String>? jid,
      Value<int>? id,
      Value<String>? identityKey,
      Value<String>? signedPreKey,
      Value<String?>? oldSignedPreKey,
      Value<BTBVTrustState>? trust,
      Value<bool>? enabled,
      Value<String>? onetimePreKeys,
      Value<int>? rowid}) {
    return OmemoDevicesCompanion(
      jid: jid ?? this.jid,
      id: id ?? this.id,
      identityKey: identityKey ?? this.identityKey,
      signedPreKey: signedPreKey ?? this.signedPreKey,
      oldSignedPreKey: oldSignedPreKey ?? this.oldSignedPreKey,
      trust: trust ?? this.trust,
      enabled: enabled ?? this.enabled,
      onetimePreKeys: onetimePreKeys ?? this.onetimePreKeys,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (jid.present) {
      map['jid'] = Variable<String>(jid.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (identityKey.present) {
      map['identity_key'] = Variable<String>(identityKey.value);
    }
    if (signedPreKey.present) {
      map['signed_pre_key'] = Variable<String>(signedPreKey.value);
    }
    if (oldSignedPreKey.present) {
      map['old_signed_pre_key'] = Variable<String>(oldSignedPreKey.value);
    }
    if (trust.present) {
      map['trust'] =
          Variable<int>($OmemoDevicesTable.$convertertrust.toSql(trust.value));
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (onetimePreKeys.present) {
      map['onetime_pre_keys'] = Variable<String>(onetimePreKeys.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OmemoDevicesCompanion(')
          ..write('jid: $jid, ')
          ..write('id: $id, ')
          ..write('identityKey: $identityKey, ')
          ..write('signedPreKey: $signedPreKey, ')
          ..write('oldSignedPreKey: $oldSignedPreKey, ')
          ..write('trust: $trust, ')
          ..write('enabled: $enabled, ')
          ..write('onetimePreKeys: $onetimePreKeys, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OmemoDeviceListsTable extends OmemoDeviceLists
    with TableInfo<$OmemoDeviceListsTable, OmemoDeviceList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OmemoDeviceListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _jidMeta = const VerificationMeta('jid');
  @override
  late final GeneratedColumn<String> jid = GeneratedColumn<String>(
      'jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _devicesMeta =
      const VerificationMeta('devices');
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String> devices =
      GeneratedColumn<String>('devices', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<int>>($OmemoDeviceListsTable.$converterdevices);
  @override
  List<GeneratedColumn> get $columns => [jid, devices];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'omemo_device_lists';
  @override
  VerificationContext validateIntegrity(Insertable<OmemoDeviceList> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('jid')) {
      context.handle(
          _jidMeta, jid.isAcceptableOrUnknown(data['jid']!, _jidMeta));
    } else if (isInserting) {
      context.missing(_jidMeta);
    }
    context.handle(_devicesMeta, const VerificationResult.success());
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {jid};
  @override
  OmemoDeviceList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OmemoDeviceList(
      jid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jid'])!,
      devices: $OmemoDeviceListsTable.$converterdevices.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}devices'])!),
    );
  }

  @override
  $OmemoDeviceListsTable createAlias(String alias) {
    return $OmemoDeviceListsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<int>, String> $converterdevices = ListConverter();
}

class OmemoDeviceList extends DataClass implements Insertable<OmemoDeviceList> {
  final String jid;
  final List<int> devices;
  const OmemoDeviceList({required this.jid, required this.devices});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['jid'] = Variable<String>(jid);
    {
      map['devices'] = Variable<String>(
          $OmemoDeviceListsTable.$converterdevices.toSql(devices));
    }
    return map;
  }

  OmemoDeviceListsCompanion toCompanion(bool nullToAbsent) {
    return OmemoDeviceListsCompanion(
      jid: Value(jid),
      devices: Value(devices),
    );
  }

  factory OmemoDeviceList.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OmemoDeviceList(
      jid: serializer.fromJson<String>(json['jid']),
      devices: serializer.fromJson<List<int>>(json['devices']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'jid': serializer.toJson<String>(jid),
      'devices': serializer.toJson<List<int>>(devices),
    };
  }

  OmemoDeviceList copyWith({String? jid, List<int>? devices}) =>
      OmemoDeviceList(
        jid: jid ?? this.jid,
        devices: devices ?? this.devices,
      );
  @override
  String toString() {
    return (StringBuffer('OmemoDeviceList(')
          ..write('jid: $jid, ')
          ..write('devices: $devices')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(jid, devices);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OmemoDeviceList &&
          other.jid == this.jid &&
          other.devices == this.devices);
}

class OmemoDeviceListsCompanion extends UpdateCompanion<OmemoDeviceList> {
  final Value<String> jid;
  final Value<List<int>> devices;
  final Value<int> rowid;
  const OmemoDeviceListsCompanion({
    this.jid = const Value.absent(),
    this.devices = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OmemoDeviceListsCompanion.insert({
    required String jid,
    required List<int> devices,
    this.rowid = const Value.absent(),
  })  : jid = Value(jid),
        devices = Value(devices);
  static Insertable<OmemoDeviceList> custom({
    Expression<String>? jid,
    Expression<String>? devices,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (jid != null) 'jid': jid,
      if (devices != null) 'devices': devices,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OmemoDeviceListsCompanion copyWith(
      {Value<String>? jid, Value<List<int>>? devices, Value<int>? rowid}) {
    return OmemoDeviceListsCompanion(
      jid: jid ?? this.jid,
      devices: devices ?? this.devices,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (jid.present) {
      map['jid'] = Variable<String>(jid.value);
    }
    if (devices.present) {
      map['devices'] = Variable<String>(
          $OmemoDeviceListsTable.$converterdevices.toSql(devices.value));
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OmemoDeviceListsCompanion(')
          ..write('jid: $jid, ')
          ..write('devices: $devices, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OmemoRatchetsTable extends OmemoRatchets
    with TableInfo<$OmemoRatchetsTable, OmemoRatchet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OmemoRatchetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _jidMeta = const VerificationMeta('jid');
  @override
  late final GeneratedColumn<String> jid = GeneratedColumn<String>(
      'jid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceMeta = const VerificationMeta('device');
  @override
  late final GeneratedColumn<int> device = GeneratedColumn<int>(
      'device', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dhsMeta = const VerificationMeta('dhs');
  @override
  late final GeneratedColumn<String> dhs = GeneratedColumn<String>(
      'dhs', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dhrMeta = const VerificationMeta('dhr');
  @override
  late final GeneratedColumn<String> dhr = GeneratedColumn<String>(
      'dhr', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rkMeta = const VerificationMeta('rk');
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String> rk =
      GeneratedColumn<String>('rk', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<int>>($OmemoRatchetsTable.$converterrk);
  static const VerificationMeta _cksMeta = const VerificationMeta('cks');
  @override
  late final GeneratedColumnWithTypeConverter<List<int>?, String> cks =
      GeneratedColumn<String>('cks', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<List<int>?>($OmemoRatchetsTable.$convertercksn);
  static const VerificationMeta _ckrMeta = const VerificationMeta('ckr');
  @override
  late final GeneratedColumnWithTypeConverter<List<int>?, String> ckr =
      GeneratedColumn<String>('ckr', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<List<int>?>($OmemoRatchetsTable.$converterckrn);
  static const VerificationMeta _nsMeta = const VerificationMeta('ns');
  @override
  late final GeneratedColumn<int> ns = GeneratedColumn<int>(
      'ns', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nrMeta = const VerificationMeta('nr');
  @override
  late final GeneratedColumn<int> nr = GeneratedColumn<int>(
      'nr', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _pnMeta = const VerificationMeta('pn');
  @override
  late final GeneratedColumn<int> pn = GeneratedColumn<int>(
      'pn', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _identityKeyMeta =
      const VerificationMeta('identityKey');
  @override
  late final GeneratedColumn<String> identityKey = GeneratedColumn<String>(
      'identity_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _associatedDataMeta =
      const VerificationMeta('associatedData');
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String>
      associatedData = GeneratedColumn<String>(
              'associated_data', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<int>>(
              $OmemoRatchetsTable.$converterassociatedData);
  static const VerificationMeta _mkSkippedMeta =
      const VerificationMeta('mkSkipped');
  @override
  late final GeneratedColumn<String> mkSkipped = GeneratedColumn<String>(
      'mk_skipped', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _keyExchangeDataMeta =
      const VerificationMeta('keyExchangeData');
  @override
  late final GeneratedColumn<String> keyExchangeData = GeneratedColumn<String>(
      'key_exchange_data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ackedMeta = const VerificationMeta('acked');
  @override
  late final GeneratedColumn<bool> acked = GeneratedColumn<bool>(
      'acked', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("acked" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        jid,
        device,
        dhs,
        dhr,
        rk,
        cks,
        ckr,
        ns,
        nr,
        pn,
        identityKey,
        associatedData,
        mkSkipped,
        keyExchangeData,
        acked
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'omemo_ratchets';
  @override
  VerificationContext validateIntegrity(Insertable<OmemoRatchet> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('jid')) {
      context.handle(
          _jidMeta, jid.isAcceptableOrUnknown(data['jid']!, _jidMeta));
    } else if (isInserting) {
      context.missing(_jidMeta);
    }
    if (data.containsKey('device')) {
      context.handle(_deviceMeta,
          device.isAcceptableOrUnknown(data['device']!, _deviceMeta));
    } else if (isInserting) {
      context.missing(_deviceMeta);
    }
    if (data.containsKey('dhs')) {
      context.handle(
          _dhsMeta, dhs.isAcceptableOrUnknown(data['dhs']!, _dhsMeta));
    } else if (isInserting) {
      context.missing(_dhsMeta);
    }
    if (data.containsKey('dhr')) {
      context.handle(
          _dhrMeta, dhr.isAcceptableOrUnknown(data['dhr']!, _dhrMeta));
    }
    context.handle(_rkMeta, const VerificationResult.success());
    context.handle(_cksMeta, const VerificationResult.success());
    context.handle(_ckrMeta, const VerificationResult.success());
    if (data.containsKey('ns')) {
      context.handle(_nsMeta, ns.isAcceptableOrUnknown(data['ns']!, _nsMeta));
    } else if (isInserting) {
      context.missing(_nsMeta);
    }
    if (data.containsKey('nr')) {
      context.handle(_nrMeta, nr.isAcceptableOrUnknown(data['nr']!, _nrMeta));
    } else if (isInserting) {
      context.missing(_nrMeta);
    }
    if (data.containsKey('pn')) {
      context.handle(_pnMeta, pn.isAcceptableOrUnknown(data['pn']!, _pnMeta));
    } else if (isInserting) {
      context.missing(_pnMeta);
    }
    if (data.containsKey('identity_key')) {
      context.handle(
          _identityKeyMeta,
          identityKey.isAcceptableOrUnknown(
              data['identity_key']!, _identityKeyMeta));
    } else if (isInserting) {
      context.missing(_identityKeyMeta);
    }
    context.handle(_associatedDataMeta, const VerificationResult.success());
    if (data.containsKey('mk_skipped')) {
      context.handle(_mkSkippedMeta,
          mkSkipped.isAcceptableOrUnknown(data['mk_skipped']!, _mkSkippedMeta));
    } else if (isInserting) {
      context.missing(_mkSkippedMeta);
    }
    if (data.containsKey('key_exchange_data')) {
      context.handle(
          _keyExchangeDataMeta,
          keyExchangeData.isAcceptableOrUnknown(
              data['key_exchange_data']!, _keyExchangeDataMeta));
    } else if (isInserting) {
      context.missing(_keyExchangeDataMeta);
    }
    if (data.containsKey('acked')) {
      context.handle(
          _ackedMeta, acked.isAcceptableOrUnknown(data['acked']!, _ackedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {jid, device};
  @override
  OmemoRatchet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OmemoRatchet.fromDb(
      jid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jid'])!,
      device: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}device'])!,
      dhs: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dhs'])!,
      dhr: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dhr']),
      rk: $OmemoRatchetsTable.$converterrk.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rk'])!),
      cks: $OmemoRatchetsTable.$convertercksn.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cks'])),
      ckr: $OmemoRatchetsTable.$converterckrn.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ckr'])),
      ns: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ns'])!,
      nr: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}nr'])!,
      pn: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pn'])!,
      identityKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}identity_key'])!,
      associatedData: $OmemoRatchetsTable.$converterassociatedData.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}associated_data'])!),
      mkSkipped: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mk_skipped'])!,
      keyExchangeData: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}key_exchange_data'])!,
      acked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}acked'])!,
    );
  }

  @override
  $OmemoRatchetsTable createAlias(String alias) {
    return $OmemoRatchetsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<int>, String> $converterrk = ListConverter();
  static TypeConverter<List<int>, String> $convertercks = ListConverter();
  static TypeConverter<List<int>?, String?> $convertercksn =
      NullAwareTypeConverter.wrap($convertercks);
  static TypeConverter<List<int>, String> $converterckr = ListConverter();
  static TypeConverter<List<int>?, String?> $converterckrn =
      NullAwareTypeConverter.wrap($converterckr);
  static TypeConverter<List<int>, String> $converterassociatedData =
      ListConverter();
}

class OmemoRatchetsCompanion extends UpdateCompanion<OmemoRatchet> {
  final Value<String> jid;
  final Value<int> device;
  final Value<String> dhs;
  final Value<String?> dhr;
  final Value<List<int>> rk;
  final Value<List<int>?> cks;
  final Value<List<int>?> ckr;
  final Value<int> ns;
  final Value<int> nr;
  final Value<int> pn;
  final Value<String> identityKey;
  final Value<List<int>> associatedData;
  final Value<String> mkSkipped;
  final Value<String> keyExchangeData;
  final Value<bool> acked;
  final Value<int> rowid;
  const OmemoRatchetsCompanion({
    this.jid = const Value.absent(),
    this.device = const Value.absent(),
    this.dhs = const Value.absent(),
    this.dhr = const Value.absent(),
    this.rk = const Value.absent(),
    this.cks = const Value.absent(),
    this.ckr = const Value.absent(),
    this.ns = const Value.absent(),
    this.nr = const Value.absent(),
    this.pn = const Value.absent(),
    this.identityKey = const Value.absent(),
    this.associatedData = const Value.absent(),
    this.mkSkipped = const Value.absent(),
    this.keyExchangeData = const Value.absent(),
    this.acked = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OmemoRatchetsCompanion.insert({
    required String jid,
    required int device,
    required String dhs,
    this.dhr = const Value.absent(),
    required List<int> rk,
    this.cks = const Value.absent(),
    this.ckr = const Value.absent(),
    required int ns,
    required int nr,
    required int pn,
    required String identityKey,
    required List<int> associatedData,
    required String mkSkipped,
    required String keyExchangeData,
    this.acked = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : jid = Value(jid),
        device = Value(device),
        dhs = Value(dhs),
        rk = Value(rk),
        ns = Value(ns),
        nr = Value(nr),
        pn = Value(pn),
        identityKey = Value(identityKey),
        associatedData = Value(associatedData),
        mkSkipped = Value(mkSkipped),
        keyExchangeData = Value(keyExchangeData);
  static Insertable<OmemoRatchet> custom({
    Expression<String>? jid,
    Expression<int>? device,
    Expression<String>? dhs,
    Expression<String>? dhr,
    Expression<String>? rk,
    Expression<String>? cks,
    Expression<String>? ckr,
    Expression<int>? ns,
    Expression<int>? nr,
    Expression<int>? pn,
    Expression<String>? identityKey,
    Expression<String>? associatedData,
    Expression<String>? mkSkipped,
    Expression<String>? keyExchangeData,
    Expression<bool>? acked,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (jid != null) 'jid': jid,
      if (device != null) 'device': device,
      if (dhs != null) 'dhs': dhs,
      if (dhr != null) 'dhr': dhr,
      if (rk != null) 'rk': rk,
      if (cks != null) 'cks': cks,
      if (ckr != null) 'ckr': ckr,
      if (ns != null) 'ns': ns,
      if (nr != null) 'nr': nr,
      if (pn != null) 'pn': pn,
      if (identityKey != null) 'identity_key': identityKey,
      if (associatedData != null) 'associated_data': associatedData,
      if (mkSkipped != null) 'mk_skipped': mkSkipped,
      if (keyExchangeData != null) 'key_exchange_data': keyExchangeData,
      if (acked != null) 'acked': acked,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OmemoRatchetsCompanion copyWith(
      {Value<String>? jid,
      Value<int>? device,
      Value<String>? dhs,
      Value<String?>? dhr,
      Value<List<int>>? rk,
      Value<List<int>?>? cks,
      Value<List<int>?>? ckr,
      Value<int>? ns,
      Value<int>? nr,
      Value<int>? pn,
      Value<String>? identityKey,
      Value<List<int>>? associatedData,
      Value<String>? mkSkipped,
      Value<String>? keyExchangeData,
      Value<bool>? acked,
      Value<int>? rowid}) {
    return OmemoRatchetsCompanion(
      jid: jid ?? this.jid,
      device: device ?? this.device,
      dhs: dhs ?? this.dhs,
      dhr: dhr ?? this.dhr,
      rk: rk ?? this.rk,
      cks: cks ?? this.cks,
      ckr: ckr ?? this.ckr,
      ns: ns ?? this.ns,
      nr: nr ?? this.nr,
      pn: pn ?? this.pn,
      identityKey: identityKey ?? this.identityKey,
      associatedData: associatedData ?? this.associatedData,
      mkSkipped: mkSkipped ?? this.mkSkipped,
      keyExchangeData: keyExchangeData ?? this.keyExchangeData,
      acked: acked ?? this.acked,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (jid.present) {
      map['jid'] = Variable<String>(jid.value);
    }
    if (device.present) {
      map['device'] = Variable<int>(device.value);
    }
    if (dhs.present) {
      map['dhs'] = Variable<String>(dhs.value);
    }
    if (dhr.present) {
      map['dhr'] = Variable<String>(dhr.value);
    }
    if (rk.present) {
      map['rk'] =
          Variable<String>($OmemoRatchetsTable.$converterrk.toSql(rk.value));
    }
    if (cks.present) {
      map['cks'] =
          Variable<String>($OmemoRatchetsTable.$convertercksn.toSql(cks.value));
    }
    if (ckr.present) {
      map['ckr'] =
          Variable<String>($OmemoRatchetsTable.$converterckrn.toSql(ckr.value));
    }
    if (ns.present) {
      map['ns'] = Variable<int>(ns.value);
    }
    if (nr.present) {
      map['nr'] = Variable<int>(nr.value);
    }
    if (pn.present) {
      map['pn'] = Variable<int>(pn.value);
    }
    if (identityKey.present) {
      map['identity_key'] = Variable<String>(identityKey.value);
    }
    if (associatedData.present) {
      map['associated_data'] = Variable<String>($OmemoRatchetsTable
          .$converterassociatedData
          .toSql(associatedData.value));
    }
    if (mkSkipped.present) {
      map['mk_skipped'] = Variable<String>(mkSkipped.value);
    }
    if (keyExchangeData.present) {
      map['key_exchange_data'] = Variable<String>(keyExchangeData.value);
    }
    if (acked.present) {
      map['acked'] = Variable<bool>(acked.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OmemoRatchetsCompanion(')
          ..write('jid: $jid, ')
          ..write('device: $device, ')
          ..write('dhs: $dhs, ')
          ..write('dhr: $dhr, ')
          ..write('rk: $rk, ')
          ..write('cks: $cks, ')
          ..write('ckr: $ckr, ')
          ..write('ns: $ns, ')
          ..write('nr: $nr, ')
          ..write('pn: $pn, ')
          ..write('identityKey: $identityKey, ')
          ..write('associatedData: $associatedData, ')
          ..write('mkSkipped: $mkSkipped, ')
          ..write('keyExchangeData: $keyExchangeData, ')
          ..write('acked: $acked, ')
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
  List<GeneratedColumn> get $columns => [messageID, senderJid, emoji];
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
  final Value<String> senderJid;
  final Value<String> emoji;
  final Value<int> rowid;
  const ReactionsCompanion({
    this.messageID = const Value.absent(),
    this.senderJid = const Value.absent(),
    this.emoji = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReactionsCompanion.insert({
    required String messageID,
    required String senderJid,
    required String emoji,
    this.rowid = const Value.absent(),
  })  : messageID = Value(messageID),
        senderJid = Value(senderJid),
        emoji = Value(emoji);
  static Insertable<Reaction> custom({
    Expression<String>? messageID,
    Expression<String>? senderJid,
    Expression<String>? emoji,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageID != null) 'message_i_d': messageID,
      if (senderJid != null) 'sender_jid': senderJid,
      if (emoji != null) 'emoji': emoji,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReactionsCompanion copyWith(
      {Value<String>? messageID,
      Value<String>? senderJid,
      Value<String>? emoji,
      Value<int>? rowid}) {
    return ReactionsCompanion(
      messageID: messageID ?? this.messageID,
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
    this.senderJid = const Value.absent(),
    required String chatJid,
    this.senderName = const Value.absent(),
    required String body,
    required DateTime timestamp,
    this.avatarPath = const Value.absent(),
    this.mediaMimeType = const Value.absent(),
    this.mediaPath = const Value.absent(),
  })  : chatJid = Value(chatJid),
        body = Value(body),
        timestamp = Value(timestamp);
  static Insertable<Notification> custom({
    Expression<int>? id,
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

class $RosterTable extends Roster with TableInfo<$RosterTable, RosterItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RosterTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _jidMeta = const VerificationMeta('jid');
  @override
  late final GeneratedColumn<String> jid = GeneratedColumn<String>(
      'jid', aliasedName, false,
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
        title = Value(title),
        presence = Value(presence),
        subscription = Value(subscription);
  static Insertable<RosterItem> custom({
    Expression<String>? jid,
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [jid, title];
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
  final Value<String> title;
  final Value<int> rowid;
  const InvitesCompanion({
    this.jid = const Value.absent(),
    this.title = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvitesCompanion.insert({
    required String jid,
    required String title,
    this.rowid = const Value.absent(),
  })  : jid = Value(jid),
        title = Value(title);
  static Insertable<Invite> custom({
    Expression<String>? jid,
    Expression<String>? title,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (jid != null) 'jid': jid,
      if (title != null) 'title': title,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvitesCompanion copyWith(
      {Value<String>? jid, Value<String>? title, Value<int>? rowid}) {
    return InvitesCompanion(
      jid: jid ?? this.jid,
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
          ..write('title: $title, ')
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
  static const VerificationMeta _myNicknameMeta =
      const VerificationMeta('myNickname');
  @override
  late final GeneratedColumn<String> myNickname = GeneratedColumn<String>(
      'my_nickname', aliasedName, true,
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
  static const VerificationMeta _encryptionProtocolMeta =
      const VerificationMeta('encryptionProtocol');
  @override
  late final GeneratedColumnWithTypeConverter<EncryptionProtocol, int>
      encryptionProtocol = GeneratedColumn<int>(
              'encryption_protocol', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: const Constant(0))
          .withConverter<EncryptionProtocol>(
              $ChatsTable.$converterencryptionProtocol);
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
  static const VerificationMeta _chatStateMeta =
      const VerificationMeta('chatState');
  @override
  late final GeneratedColumnWithTypeConverter<mox.ChatState?, String>
      chatState = GeneratedColumn<String>('chat_state', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<mox.ChatState?>($ChatsTable.$converterchatStaten);
  @override
  List<GeneratedColumn> get $columns => [
        jid,
        title,
        type,
        myNickname,
        avatarPath,
        avatarHash,
        lastMessage,
        lastChangeTimestamp,
        unreadCount,
        open,
        muted,
        favourited,
        encryptionProtocol,
        contactID,
        contactDisplayName,
        contactAvatarPath,
        contactAvatarHash,
        chatState
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
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    context.handle(_typeMeta, const VerificationResult.success());
    if (data.containsKey('my_nickname')) {
      context.handle(
          _myNicknameMeta,
          myNickname.isAcceptableOrUnknown(
              data['my_nickname']!, _myNicknameMeta));
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
    if (data.containsKey('favourited')) {
      context.handle(
          _favouritedMeta,
          favourited.isAcceptableOrUnknown(
              data['favourited']!, _favouritedMeta));
    }
    context.handle(_encryptionProtocolMeta, const VerificationResult.success());
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
    context.handle(_chatStateMeta, const VerificationResult.success());
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
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      type: $ChatsTable.$convertertype.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!),
      myNickname: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}my_nickname']),
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
      favourited: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}favourited'])!,
      encryptionProtocol: $ChatsTable.$converterencryptionProtocol.fromSql(
          attachedDatabase.typeMapping.read(DriftSqlType.int,
              data['${effectivePrefix}encryption_protocol'])!),
      contactID: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_i_d']),
      contactDisplayName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}contact_display_name']),
      contactAvatarPath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}contact_avatar_path']),
      contactAvatarHash: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}contact_avatar_hash']),
      chatState: $ChatsTable.$converterchatStaten.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_state'])),
    );
  }

  @override
  $ChatsTable createAlias(String alias) {
    return $ChatsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ChatType, int, int> $convertertype =
      const EnumIndexConverter<ChatType>(ChatType.values);
  static JsonTypeConverter2<EncryptionProtocol, int, int>
      $converterencryptionProtocol =
      const EnumIndexConverter<EncryptionProtocol>(EncryptionProtocol.values);
  static JsonTypeConverter2<mox.ChatState, String, String> $converterchatState =
      const EnumNameConverter<mox.ChatState>(mox.ChatState.values);
  static JsonTypeConverter2<mox.ChatState?, String?, String?>
      $converterchatStaten = JsonTypeConverter2.asNullable($converterchatState);
}

class ChatsCompanion extends UpdateCompanion<Chat> {
  final Value<String> jid;
  final Value<String> title;
  final Value<ChatType> type;
  final Value<String?> myNickname;
  final Value<String?> avatarPath;
  final Value<String?> avatarHash;
  final Value<String?> lastMessage;
  final Value<DateTime> lastChangeTimestamp;
  final Value<int> unreadCount;
  final Value<bool> open;
  final Value<bool> muted;
  final Value<bool> favourited;
  final Value<EncryptionProtocol> encryptionProtocol;
  final Value<String?> contactID;
  final Value<String?> contactDisplayName;
  final Value<String?> contactAvatarPath;
  final Value<String?> contactAvatarHash;
  final Value<mox.ChatState?> chatState;
  final Value<int> rowid;
  const ChatsCompanion({
    this.jid = const Value.absent(),
    this.title = const Value.absent(),
    this.type = const Value.absent(),
    this.myNickname = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.avatarHash = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.lastChangeTimestamp = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.open = const Value.absent(),
    this.muted = const Value.absent(),
    this.favourited = const Value.absent(),
    this.encryptionProtocol = const Value.absent(),
    this.contactID = const Value.absent(),
    this.contactDisplayName = const Value.absent(),
    this.contactAvatarPath = const Value.absent(),
    this.contactAvatarHash = const Value.absent(),
    this.chatState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatsCompanion.insert({
    required String jid,
    required String title,
    required ChatType type,
    this.myNickname = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.avatarHash = const Value.absent(),
    this.lastMessage = const Value.absent(),
    required DateTime lastChangeTimestamp,
    this.unreadCount = const Value.absent(),
    this.open = const Value.absent(),
    this.muted = const Value.absent(),
    this.favourited = const Value.absent(),
    this.encryptionProtocol = const Value.absent(),
    this.contactID = const Value.absent(),
    this.contactDisplayName = const Value.absent(),
    this.contactAvatarPath = const Value.absent(),
    this.contactAvatarHash = const Value.absent(),
    this.chatState = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : jid = Value(jid),
        title = Value(title),
        type = Value(type),
        lastChangeTimestamp = Value(lastChangeTimestamp);
  static Insertable<Chat> custom({
    Expression<String>? jid,
    Expression<String>? title,
    Expression<int>? type,
    Expression<String>? myNickname,
    Expression<String>? avatarPath,
    Expression<String>? avatarHash,
    Expression<String>? lastMessage,
    Expression<DateTime>? lastChangeTimestamp,
    Expression<int>? unreadCount,
    Expression<bool>? open,
    Expression<bool>? muted,
    Expression<bool>? favourited,
    Expression<int>? encryptionProtocol,
    Expression<String>? contactID,
    Expression<String>? contactDisplayName,
    Expression<String>? contactAvatarPath,
    Expression<String>? contactAvatarHash,
    Expression<String>? chatState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (jid != null) 'jid': jid,
      if (title != null) 'title': title,
      if (type != null) 'type': type,
      if (myNickname != null) 'my_nickname': myNickname,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (avatarHash != null) 'avatar_hash': avatarHash,
      if (lastMessage != null) 'last_message': lastMessage,
      if (lastChangeTimestamp != null)
        'last_change_timestamp': lastChangeTimestamp,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (open != null) 'open': open,
      if (muted != null) 'muted': muted,
      if (favourited != null) 'favourited': favourited,
      if (encryptionProtocol != null) 'encryption_protocol': encryptionProtocol,
      if (contactID != null) 'contact_i_d': contactID,
      if (contactDisplayName != null)
        'contact_display_name': contactDisplayName,
      if (contactAvatarPath != null) 'contact_avatar_path': contactAvatarPath,
      if (contactAvatarHash != null) 'contact_avatar_hash': contactAvatarHash,
      if (chatState != null) 'chat_state': chatState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatsCompanion copyWith(
      {Value<String>? jid,
      Value<String>? title,
      Value<ChatType>? type,
      Value<String?>? myNickname,
      Value<String?>? avatarPath,
      Value<String?>? avatarHash,
      Value<String?>? lastMessage,
      Value<DateTime>? lastChangeTimestamp,
      Value<int>? unreadCount,
      Value<bool>? open,
      Value<bool>? muted,
      Value<bool>? favourited,
      Value<EncryptionProtocol>? encryptionProtocol,
      Value<String?>? contactID,
      Value<String?>? contactDisplayName,
      Value<String?>? contactAvatarPath,
      Value<String?>? contactAvatarHash,
      Value<mox.ChatState?>? chatState,
      Value<int>? rowid}) {
    return ChatsCompanion(
      jid: jid ?? this.jid,
      title: title ?? this.title,
      type: type ?? this.type,
      myNickname: myNickname ?? this.myNickname,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarHash: avatarHash ?? this.avatarHash,
      lastMessage: lastMessage ?? this.lastMessage,
      lastChangeTimestamp: lastChangeTimestamp ?? this.lastChangeTimestamp,
      unreadCount: unreadCount ?? this.unreadCount,
      open: open ?? this.open,
      muted: muted ?? this.muted,
      favourited: favourited ?? this.favourited,
      encryptionProtocol: encryptionProtocol ?? this.encryptionProtocol,
      contactID: contactID ?? this.contactID,
      contactDisplayName: contactDisplayName ?? this.contactDisplayName,
      contactAvatarPath: contactAvatarPath ?? this.contactAvatarPath,
      contactAvatarHash: contactAvatarHash ?? this.contactAvatarHash,
      chatState: chatState ?? this.chatState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (jid.present) {
      map['jid'] = Variable<String>(jid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (type.present) {
      map['type'] = Variable<int>($ChatsTable.$convertertype.toSql(type.value));
    }
    if (myNickname.present) {
      map['my_nickname'] = Variable<String>(myNickname.value);
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
    if (favourited.present) {
      map['favourited'] = Variable<bool>(favourited.value);
    }
    if (encryptionProtocol.present) {
      map['encryption_protocol'] = Variable<int>($ChatsTable
          .$converterencryptionProtocol
          .toSql(encryptionProtocol.value));
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
    if (chatState.present) {
      map['chat_state'] = Variable<String>(
          $ChatsTable.$converterchatStaten.toSql(chatState.value));
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
          ..write('title: $title, ')
          ..write('type: $type, ')
          ..write('myNickname: $myNickname, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('avatarHash: $avatarHash, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastChangeTimestamp: $lastChangeTimestamp, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('open: $open, ')
          ..write('muted: $muted, ')
          ..write('favourited: $favourited, ')
          ..write('encryptionProtocol: $encryptionProtocol, ')
          ..write('contactID: $contactID, ')
          ..write('contactDisplayName: $contactDisplayName, ')
          ..write('contactAvatarPath: $contactAvatarPath, ')
          ..write('contactAvatarHash: $contactAvatarHash, ')
          ..write('chatState: $chatState, ')
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

abstract class _$XmppDrift extends GeneratedDatabase {
  _$XmppDrift(QueryExecutor e) : super(e);
  _$XmppDriftManager get managers => _$XmppDriftManager(this);
  late final $FileMetadataTable fileMetadata = $FileMetadataTable(this);
  late final $StickerPacksTable stickerPacks = $StickerPacksTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $DraftsTable drafts = $DraftsTable(this);
  late final $OmemoDevicesTable omemoDevices = $OmemoDevicesTable(this);
  late final $OmemoDeviceListsTable omemoDeviceLists =
      $OmemoDeviceListsTable(this);
  late final $OmemoRatchetsTable omemoRatchets = $OmemoRatchetsTable(this);
  late final $ReactionsTable reactions = $ReactionsTable(this);
  late final $NotificationsTable notifications = $NotificationsTable(this);
  late final $ContactsTable contacts = $ContactsTable(this);
  late final $RosterTable roster = $RosterTable(this);
  late final $InvitesTable invites = $InvitesTable(this);
  late final $ChatsTable chats = $ChatsTable(this);
  late final $BlocklistTable blocklist = $BlocklistTable(this);
  late final $StickersTable stickers = $StickersTable(this);
  late final MessagesAccessor messagesAccessor =
      MessagesAccessor(this as XmppDrift);
  late final DraftsAccessor draftsAccessor = DraftsAccessor(this as XmppDrift);
  late final OmemoDevicesAccessor omemoDevicesAccessor =
      OmemoDevicesAccessor(this as XmppDrift);
  late final OmemoDeviceListsAccessor omemoDeviceListsAccessor =
      OmemoDeviceListsAccessor(this as XmppDrift);
  late final OmemoRatchetsAccessor omemoRatchetsAccessor =
      OmemoRatchetsAccessor(this as XmppDrift);
  late final FileMetadataAccessor fileMetadataAccessor =
      FileMetadataAccessor(this as XmppDrift);
  late final ChatsAccessor chatsAccessor = ChatsAccessor(this as XmppDrift);
  late final RosterAccessor rosterAccessor = RosterAccessor(this as XmppDrift);
  late final InvitesAccessor invitesAccessor =
      InvitesAccessor(this as XmppDrift);
  late final BlocklistAccessor blocklistAccessor =
      BlocklistAccessor(this as XmppDrift);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        fileMetadata,
        stickerPacks,
        messages,
        drafts,
        omemoDevices,
        omemoDeviceLists,
        omemoRatchets,
        reactions,
        notifications,
        contacts,
        roster,
        invites,
        chats,
        blocklist,
        stickers
      ];
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
    _$XmppDrift,
    $FileMetadataTable,
    FileMetadataData,
    $$FileMetadataTableFilterComposer,
    $$FileMetadataTableOrderingComposer,
    $$FileMetadataTableProcessedTableManager,
    $$FileMetadataTableInsertCompanionBuilder,
    $$FileMetadataTableUpdateCompanionBuilder> {
  $$FileMetadataTableTableManager(_$XmppDrift db, $FileMetadataTable table)
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
    _$XmppDrift,
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
    extends FilterComposer<_$XmppDrift, $FileMetadataTable> {
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

  ComposableFilter draftsRefs(
      ComposableFilter Function($$DraftsTableFilterComposer f) f) {
    final $$DraftsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.drafts,
        getReferencedColumn: (t) => t.fileMetadataID,
        builder: (joinBuilder, parentComposers) => $$DraftsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.drafts, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$FileMetadataTableOrderingComposer
    extends OrderingComposer<_$XmppDrift, $FileMetadataTable> {
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

typedef $$DraftsTableInsertCompanionBuilder = DraftsCompanion Function({
  Value<int> id,
  required List<String> jids,
  Value<String?> body,
  Value<String?> fileMetadataID,
});
typedef $$DraftsTableUpdateCompanionBuilder = DraftsCompanion Function({
  Value<int> id,
  Value<List<String>> jids,
  Value<String?> body,
  Value<String?> fileMetadataID,
});

class $$DraftsTableTableManager extends RootTableManager<
    _$XmppDrift,
    $DraftsTable,
    Draft,
    $$DraftsTableFilterComposer,
    $$DraftsTableOrderingComposer,
    $$DraftsTableProcessedTableManager,
    $$DraftsTableInsertCompanionBuilder,
    $$DraftsTableUpdateCompanionBuilder> {
  $$DraftsTableTableManager(_$XmppDrift db, $DraftsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$DraftsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$DraftsTableOrderingComposer(ComposerState(db, table)),
          getChildManagerBuilder: (p) => $$DraftsTableProcessedTableManager(p),
          getUpdateCompanionBuilder: ({
            Value<int> id = const Value.absent(),
            Value<List<String>> jids = const Value.absent(),
            Value<String?> body = const Value.absent(),
            Value<String?> fileMetadataID = const Value.absent(),
          }) =>
              DraftsCompanion(
            id: id,
            jids: jids,
            body: body,
            fileMetadataID: fileMetadataID,
          ),
          getInsertCompanionBuilder: ({
            Value<int> id = const Value.absent(),
            required List<String> jids,
            Value<String?> body = const Value.absent(),
            Value<String?> fileMetadataID = const Value.absent(),
          }) =>
              DraftsCompanion.insert(
            id: id,
            jids: jids,
            body: body,
            fileMetadataID: fileMetadataID,
          ),
        ));
}

class $$DraftsTableProcessedTableManager extends ProcessedTableManager<
    _$XmppDrift,
    $DraftsTable,
    Draft,
    $$DraftsTableFilterComposer,
    $$DraftsTableOrderingComposer,
    $$DraftsTableProcessedTableManager,
    $$DraftsTableInsertCompanionBuilder,
    $$DraftsTableUpdateCompanionBuilder> {
  $$DraftsTableProcessedTableManager(super.$state);
}

class $$DraftsTableFilterComposer
    extends FilterComposer<_$XmppDrift, $DraftsTable> {
  $$DraftsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get jids =>
      $state.composableBuilder(
          column: $state.table.jids,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));

  ColumnFilters<String> get body => $state.composableBuilder(
      column: $state.table.body,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$FileMetadataTableFilterComposer get fileMetadataID {
    final $$FileMetadataTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.fileMetadataID,
        referencedTable: $state.db.fileMetadata,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$FileMetadataTableFilterComposer(ComposerState($state.db,
                $state.db.fileMetadata, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$DraftsTableOrderingComposer
    extends OrderingComposer<_$XmppDrift, $DraftsTable> {
  $$DraftsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get jids => $state.composableBuilder(
      column: $state.table.jids,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get body => $state.composableBuilder(
      column: $state.table.body,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$FileMetadataTableOrderingComposer get fileMetadataID {
    final $$FileMetadataTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.fileMetadataID,
        referencedTable: $state.db.fileMetadata,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$FileMetadataTableOrderingComposer(ComposerState($state.db,
                $state.db.fileMetadata, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$OmemoDeviceListsTableInsertCompanionBuilder
    = OmemoDeviceListsCompanion Function({
  required String jid,
  required List<int> devices,
  Value<int> rowid,
});
typedef $$OmemoDeviceListsTableUpdateCompanionBuilder
    = OmemoDeviceListsCompanion Function({
  Value<String> jid,
  Value<List<int>> devices,
  Value<int> rowid,
});

class $$OmemoDeviceListsTableTableManager extends RootTableManager<
    _$XmppDrift,
    $OmemoDeviceListsTable,
    OmemoDeviceList,
    $$OmemoDeviceListsTableFilterComposer,
    $$OmemoDeviceListsTableOrderingComposer,
    $$OmemoDeviceListsTableProcessedTableManager,
    $$OmemoDeviceListsTableInsertCompanionBuilder,
    $$OmemoDeviceListsTableUpdateCompanionBuilder> {
  $$OmemoDeviceListsTableTableManager(
      _$XmppDrift db, $OmemoDeviceListsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$OmemoDeviceListsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$OmemoDeviceListsTableOrderingComposer(ComposerState(db, table)),
          getChildManagerBuilder: (p) =>
              $$OmemoDeviceListsTableProcessedTableManager(p),
          getUpdateCompanionBuilder: ({
            Value<String> jid = const Value.absent(),
            Value<List<int>> devices = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OmemoDeviceListsCompanion(
            jid: jid,
            devices: devices,
            rowid: rowid,
          ),
          getInsertCompanionBuilder: ({
            required String jid,
            required List<int> devices,
            Value<int> rowid = const Value.absent(),
          }) =>
              OmemoDeviceListsCompanion.insert(
            jid: jid,
            devices: devices,
            rowid: rowid,
          ),
        ));
}

class $$OmemoDeviceListsTableProcessedTableManager
    extends ProcessedTableManager<
        _$XmppDrift,
        $OmemoDeviceListsTable,
        OmemoDeviceList,
        $$OmemoDeviceListsTableFilterComposer,
        $$OmemoDeviceListsTableOrderingComposer,
        $$OmemoDeviceListsTableProcessedTableManager,
        $$OmemoDeviceListsTableInsertCompanionBuilder,
        $$OmemoDeviceListsTableUpdateCompanionBuilder> {
  $$OmemoDeviceListsTableProcessedTableManager(super.$state);
}

class $$OmemoDeviceListsTableFilterComposer
    extends FilterComposer<_$XmppDrift, $OmemoDeviceListsTable> {
  $$OmemoDeviceListsTableFilterComposer(super.$state);
  ColumnFilters<String> get jid => $state.composableBuilder(
      column: $state.table.jid,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<List<int>, List<int>, String> get devices =>
      $state.composableBuilder(
          column: $state.table.devices,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));
}

class $$OmemoDeviceListsTableOrderingComposer
    extends OrderingComposer<_$XmppDrift, $OmemoDeviceListsTable> {
  $$OmemoDeviceListsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get jid => $state.composableBuilder(
      column: $state.table.jid,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get devices => $state.composableBuilder(
      column: $state.table.devices,
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
    _$XmppDrift,
    $ContactsTable,
    Contact,
    $$ContactsTableFilterComposer,
    $$ContactsTableOrderingComposer,
    $$ContactsTableProcessedTableManager,
    $$ContactsTableInsertCompanionBuilder,
    $$ContactsTableUpdateCompanionBuilder> {
  $$ContactsTableTableManager(_$XmppDrift db, $ContactsTable table)
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
    _$XmppDrift,
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
    extends FilterComposer<_$XmppDrift, $ContactsTable> {
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
    extends OrderingComposer<_$XmppDrift, $ContactsTable> {
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
    _$XmppDrift,
    $BlocklistTable,
    BlocklistData,
    $$BlocklistTableFilterComposer,
    $$BlocklistTableOrderingComposer,
    $$BlocklistTableProcessedTableManager,
    $$BlocklistTableInsertCompanionBuilder,
    $$BlocklistTableUpdateCompanionBuilder> {
  $$BlocklistTableTableManager(_$XmppDrift db, $BlocklistTable table)
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
    _$XmppDrift,
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
    extends FilterComposer<_$XmppDrift, $BlocklistTable> {
  $$BlocklistTableFilterComposer(super.$state);
  ColumnFilters<String> get jid => $state.composableBuilder(
      column: $state.table.jid,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$BlocklistTableOrderingComposer
    extends OrderingComposer<_$XmppDrift, $BlocklistTable> {
  $$BlocklistTableOrderingComposer(super.$state);
  ColumnOrderings<String> get jid => $state.composableBuilder(
      column: $state.table.jid,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class _$XmppDriftManager {
  final _$XmppDrift _db;
  _$XmppDriftManager(this._db);
  $$FileMetadataTableTableManager get fileMetadata =>
      $$FileMetadataTableTableManager(_db, _db.fileMetadata);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db, _db.drafts);
  $$OmemoDeviceListsTableTableManager get omemoDeviceLists =>
      $$OmemoDeviceListsTableTableManager(_db, _db.omemoDeviceLists);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db, _db.contacts);
  $$BlocklistTableTableManager get blocklist =>
      $$BlocklistTableTableManager(_db, _db.blocklist);
}
