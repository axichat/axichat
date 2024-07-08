import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import 'models.dart';

part 'database.g.dart';

abstract interface class Database {
  Future<void> close();
}

@DriftDatabase(tables: [
  Messages,
  Reactions,
  Notifications,
  FileMetadata,
  Roster,
  Invites,
  Chats,
  Contacts,
  Blocklist,
  Stickers,
  StickerPacks,
])
class XmppDatabase extends _$XmppDatabase implements Database {
  XmppDatabase._(super.e) : super();

  static XmppDatabase? _instance;

  factory XmppDatabase({
    required String username,
    required String passphrase,
    QueryExecutor? executor,
  }) =>
      _instance ??=
          XmppDatabase._(executor ?? _openDatabase(username, passphrase));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (_) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> deleteAll() async {
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        for (final table in allTables) {
          await delete(table).go();
        }
      });
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  Stream<List<RosterItem>> watchRoster() => select(roster).watch();
  Future<List<RosterItem>> selectRoster() => select(roster).get();
  Future<RosterItem?> selectRosterItem(String jid) =>
      (select(roster)..where((roster) => roster.jid.equals(jid)))
          .getSingleOrNull();
  Future<void> insertRosterItem(RosterItem item) =>
      into(roster).insert(item, mode: InsertMode.insertOrIgnore);
  Future<void> insertOrUpdateRosterItem(RosterItem item) =>
      into(roster).insertOnConflictUpdate(item);
  Future<void> updateRosterItem(RosterItem item) =>
      update(roster).replace(item);
  Future<void> deleteRosterItem(String jid) =>
      (delete(roster)..where((item) => item.jid.equals(jid))).go();

  Stream<List<Invite>> watchInvites() => select(invites).watch();
  Future<List<Invite>> selectInvites() => select(invites).get();
  Future<Invite?> selectInvite(String jid) =>
      (select(invites)..where((invites) => invites.jid.equals(jid)))
          .getSingleOrNull();
  Future<void> insertInvite(Invite item) =>
      into(invites).insert(item, mode: InsertMode.insertOrIgnore);
  Future<void> deleteInvite(String jid) =>
      (delete(invites)..where((item) => item.jid.equals(jid))).go();

  Stream<List<BlocklistData>> watchBlocklist() => select(blocklist).watch();
  Future<List<BlocklistData>> selectBlocklist() => select(blocklist).get();
  Future<BlocklistData?> selectBlocklistData(String jid) =>
      (select(blocklist)..where((blocklist) => blocklist.jid.equals(jid)))
          .getSingleOrNull();
  Future<void> insertBlocklistData(String jid) =>
      into(blocklist).insert(BlocklistCompanion(jid: Value(jid)),
          mode: InsertMode.insertOrIgnore);
  Future<void> deleteBlocklistData(String jid) =>
      (delete(blocklist)..where((item) => item.jid.equals(jid))).go();
  Future<void> deleteBlocklist() => delete(blocklist).go();

  Stream<List<Chat>> watchChats() => select(chats).watch();
  Future<List<Chat>> selectChats() => select(chats).get();
  Future<Chat?> selectChat(String jid) =>
      (select(chats)..where((chats) => chats.jid.equals(jid)))
          .getSingleOrNull();
  Future<void> insertChat(Insertable<Chat> item) =>
      into(chats).insert(item, mode: InsertMode.insertOrIgnore);
  Future<void> insertOrUpdateChat(Insertable<Chat> item) =>
      into(chats).insertOnConflictUpdate(item);
  Future<void> updateChat(Insertable<Chat> item) => update(chats).replace(item);
  Future<void> deleteChat(String jid) =>
      (delete(roster)..where((item) => item.jid.equals(jid))).go();

  @override
  Future<void> close() async {
    await super.close();
    _instance = null;
  }
}

QueryExecutor _openDatabase(String username, String passphrase) {
  return LazyDatabase(() async {
    final token = RootIsolateToken.instance!;
    final file = await dbFilePathFor(username);
    if (kDebugMode) {
      // await file.delete();
    }
    return NativeDatabase.createInBackground(
      file,
      isolateSetup: () async {
        BackgroundIsolateBinaryMessenger.ensureInitialized(token);
        await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
        open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
        // ..overrideFor(OperatingSystem.linux,
        //     () => DynamicLibrary.open('libsqlcipher.so'))
        // ..overrideFor(OperatingSystem.windows,
        //     () => DynamicLibrary.open('sqlcipher.dll'));
      },
      setup: (rawDb) {
        final result = rawDb.select('PRAGMA cipher_version');
        if (result.isEmpty) {
          throw UnsupportedError('SQLCipher library unavailable');
        }

        // This will be used with PBKDF2 to get the actual key.
        final escapedKey = passphrase.replaceAll("'", "''");
        rawDb.execute("PRAGMA key = '$escapedKey'");
      },
    );
  });
}

Future<File> dbFilePathFor(String username) async {
  final path = (await getApplicationDocumentsDirectory()).path;
  return File(p.join(path, '${storagePrefixFor(username)}.axichat.drift'));
}

String generatePassphrase() {
  final random = Random.secure();
  return utf8.decode(List<int>.generate(32, (_) => random.nextInt(33) + 89));
}

// Using SHA-1 as this is only to obfuscate the username in file paths.
String storagePrefixFor(String username) =>
    sha1.convert(utf8.encode(username)).toString();
