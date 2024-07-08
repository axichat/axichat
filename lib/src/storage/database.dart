part of '../../main.dart';

abstract interface class Database {}

abstract interface class RelationalDatabase implements Database {}

abstract class ProtectedDatabase {
  ProtectedDatabase._(this.username, this.passphrase);

  final String username;
  final String passphrase;
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
class _XmppDatabase extends _$XmppDatabase
    implements ProtectedDatabase, RelationalDatabase {
  _XmppDatabase._(this.username, this.passphrase)
      : super(_openDatabase(username, passphrase));

  @override
  final String username;

  @override
  final String passphrase;

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
  Future<void> insertRosterItem(Insertable<RosterItem> item) =>
      into(roster).insert(item, mode: InsertMode.insertOrIgnore);
  Future<void> insertOrUpdateRosterItem(Insertable<RosterItem> item) =>
      into(roster).insertOnConflictUpdate(item);
  Future<void> updateRosterItem(Insertable<RosterItem> item) =>
      update(roster).replace(item);
  Future<void> deleteRosterItem(String jid) =>
      (delete(roster)..where((item) => item.jid.equals(jid))).go();

  Stream<List<Invite>> watchInvites() => select(invites).watch();
  Future<List<Invite>> selectInvites() => select(invites).get();
  Future<Invite?> selectInvite(String jid) =>
      (select(invites)..where((invites) => invites.jid.equals(jid)))
          .getSingleOrNull();
  Future<void> insertInvite(Insertable<Invite> item) =>
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
