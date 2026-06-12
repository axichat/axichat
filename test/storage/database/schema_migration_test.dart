import 'dart:io';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('opens and migrates a v0.7.2 schema 39 database', () async {
    final file = await _createSchema39Database();
    final database = XmppDrift(
      file: file,
      passphrase: '',
      executor: NativeDatabase(file),
    );

    try {
      expect(await _userVersion(database), database.schemaVersion);

      expect(
        await _tableNames(database),
        containsAll(<String>{
          'contact_preferences',
          'private_contact_records',
          'private_contact_detail_fields',
          'message_pins',
          'email_trusted_contact_keys',
        }),
      );
      expect(
        await _columnNames(database, 'messages'),
        containsAll(<String>{
          'manual_send_again_stanza_i_d',
          'sender_real_jid',
        }),
      );
      expect(
        await _columnNames(database, 'chats'),
        containsAll(<String>{
          'email_remote_images_enabled',
          'typing_indicators_enabled',
          'email_read_receipts_enabled',
          'email_send_confirmation_enabled',
          'email_composer_watermark_enabled',
          'chat_settings_updated_at',
          'chat_settings_source_id',
          'chat_settings_confirmed_json',
          'chat_settings_confirmed_updated_at',
          'chat_settings_confirmed_source_id',
          'notification_behavior',
        }),
      );
      expect(
        await _columnNames(database, 'drafts'),
        containsAll(<String>{
          'calendar_task_ics',
          'forwarded_blocks',
          'autosave_enabled',
        }),
      );
      expect(
        await _columnNames(database, 'message_attachments'),
        containsAll(<String>{
          'group_quoted_reference',
          'group_quoted_reference_kind',
        }),
      );

      final peerChat = await database.getChat('peer@example.com');
      expect(peerChat?.title, 'Peer');
      expect(peerChat?.transport, MessageTransport.xmpp);

      final mailChat = await database.getChat('mail@example.com');
      expect(mailChat?.title, 'Mail');
      expect(mailChat?.transport, MessageTransport.email);
      expect(
        await database.getDeltaChatIdForAccount(
          chatJid: 'mail@example.com',
          deltaAccountId: 0,
        ),
        42,
      );

      final message = await database.getMessageByStanzaID('stanza-1');
      expect(message?.body, 'hello from schema 39');
      expect(message?.manualSendAgainStanzaID, isNull);
      expect(message?.senderRealJid, isNull);

      final draft = await database.getDraft(1);
      expect(draft?.body, 'draft body');
      expect(draft?.calendarTaskIcsMessage, isNull);
      expect(draft?.forwardedBlocks, isEmpty);
      expect(draft?.autosaveEnabled, isFalse);

      expect(
        await _rowCount(database, '''
SELECT COUNT(*) AS count
FROM pinned_messages
WHERE message_stanza_id = 'stanza-1'
  AND chat_jid = 'peer@example.com'
'''),
        1,
      );
      expect(
        await _rowCount(database, '''
SELECT COUNT(*) AS count
FROM message_attachments
WHERE message_id = 'stanza-1'
  AND file_metadata_id = 'file-1'
'''),
        1,
      );
      expect(await _indexColumns(database, 'messages_delta_locator'), [
        'delta_account_id',
        'delta_msg_id',
      ]);
      expect(await _indexIsUnique(database, 'messages_delta_locator'), isTrue);
    } finally {
      await database.close();
    }
  });

  test('schema 63 repairs over-promoted email chat transports', () async {
    final file = await _createSchema62OverpromotedTransportDatabase();
    final database = XmppDrift(
      file: file,
      passphrase: '',
      executor: NativeDatabase(file),
    );

    try {
      expect(await _userVersion(database), database.schemaVersion);
      expect(
        (await database.getChat('legacy-orphan@example.com'))?.transport,
        MessageTransport.email,
      );
      expect(
        (await database.getChat('rostered@example.com'))?.transport,
        MessageTransport.xmpp,
      );
      expect(
        (await database.getChat('xmpp-evidence@example.com'))?.transport,
        MessageTransport.xmpp,
      );
    } finally {
      await database.close();
    }
  });
}

Future<File> _createSchema39Database() async {
  final directory = await Directory.systemTemp.createTemp(
    'axichat_schema39_migration_test',
  );
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  final file = File('${directory.path}/schema39.axichat.drift');
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw
      ..execute(_schema39Sql)
      ..execute(_seedSchema39Sql)
      ..execute('PRAGMA user_version = 39');
    expect(raw.select('PRAGMA user_version').single['user_version'], 39);
  } finally {
    raw.dispose();
  }
  return file;
}

Future<File> _createSchema62OverpromotedTransportDatabase() async {
  final directory = await Directory.systemTemp.createTemp(
    'axichat_schema62_transport_repair_test',
  );
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  final file = File('${directory.path}/schema62.axichat.drift');
  final database = XmppDrift(
    file: file,
    passphrase: '',
    executor: NativeDatabase(file),
  );
  try {
    await _seedOverpromotedEmailChat(
      database,
      'legacy-orphan@example.com',
      deltaChatId: 101,
    );
    await _seedOverpromotedEmailChat(
      database,
      'rostered@example.com',
      deltaChatId: 102,
      withRoster: true,
    );
    await _seedOverpromotedEmailChat(
      database,
      'xmpp-evidence@example.com',
      deltaChatId: 103,
      withXmppEvidence: true,
    );
    await database.customStatement('PRAGMA user_version = 62');
    expect(await _userVersion(database), 62);
  } finally {
    await database.close();
  }
  return file;
}

Future<void> _seedOverpromotedEmailChat(
  XmppDrift database,
  String jid, {
  required int deltaChatId,
  bool withRoster = false,
  bool withXmppEvidence = false,
}) async {
  await database.createChat(
    Chat(
      jid: jid,
      title: jid,
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2026, 1, 1),
      transport: MessageTransport.email,
      deltaChatId: deltaChatId,
      emailAddress: jid,
    ),
  );
  await database.upsertEmailChatAccount(
    chatJid: jid,
    deltaAccountId: 0,
    deltaChatId: deltaChatId,
  );
  await database.saveMessage(
    Message(
      stanzaID: 'legacy-orphan-$jid',
      senderJid: jid,
      chatJid: jid,
      timestamp: DateTime.utc(2026, 1, 2),
      body: 'legacy orphan',
      encryptionProtocol: withXmppEvidence
          ? EncryptionProtocol.omemo
          : EncryptionProtocol.none,
    ),
  );
  if (withRoster) {
    await database.saveRosterItemOnly(RosterItem.fromJid(jid));
  }
  await database.updateChat(
    (await database.getChat(jid))!.copyWith(transport: MessageTransport.xmpp),
  );
}

Future<int> _userVersion(XmppDrift database) async {
  final row = await database.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

Future<Set<String>> _tableNames(XmppDrift database) async {
  final rows = await database
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Set<String>> _columnNames(XmppDrift database, String tableName) async {
  final rows = await database
      .customSelect('PRAGMA table_info("$tableName")')
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<List<String>> _indexColumns(XmppDrift database, String indexName) async {
  final rows = await database
      .customSelect('PRAGMA index_info("$indexName")')
      .get();
  final ordered = rows.toList()
    ..sort((a, b) => a.read<int>('seqno').compareTo(b.read<int>('seqno')));
  return ordered.map((row) => row.read<String>('name')).toList();
}

Future<bool> _indexIsUnique(XmppDrift database, String indexName) async {
  final rows = await database
      .customSelect("PRAGMA index_list('messages')")
      .get();
  for (final row in rows) {
    if (row.read<String>('name') == indexName) {
      return row.read<int>('unique') == 1;
    }
  }
  return false;
}

Future<int> _rowCount(XmppDrift database, String sql) async {
  final row = await database.customSelect(sql).getSingle();
  return row.read<int>('count');
}

const String _schema39Sql = r'''
CREATE TABLE IF NOT EXISTS "messages" ("id" TEXT NOT NULL, "stanza_i_d" TEXT NOT NULL, "origin_i_d" TEXT NULL, "muc_stanza_id" TEXT NULL, "occupant_i_d" TEXT NULL, "sender_jid" TEXT NOT NULL, "chat_jid" TEXT NOT NULL, "body" TEXT NULL, "subject" TEXT NULL, "html_body" TEXT NULL, "timestamp" TEXT NOT NULL, "error" INTEGER NOT NULL DEFAULT 0, "warning" INTEGER NOT NULL DEFAULT 0, "encryption_protocol" INTEGER NOT NULL DEFAULT 0, "trust" INTEGER NULL, "trusted" INTEGER NULL CHECK ("trusted" IN (0, 1)), "device_i_d" INTEGER NULL, "no_store" INTEGER NOT NULL DEFAULT 0 CHECK ("no_store" IN (0, 1)), "acked" INTEGER NOT NULL DEFAULT 0 CHECK ("acked" IN (0, 1)), "received" INTEGER NOT NULL DEFAULT 0 CHECK ("received" IN (0, 1)), "displayed" INTEGER NOT NULL DEFAULT 0 CHECK ("displayed" IN (0, 1)), "edited" INTEGER NOT NULL DEFAULT 0 CHECK ("edited" IN (0, 1)), "retracted" INTEGER NOT NULL DEFAULT 0 CHECK ("retracted" IN (0, 1)), "is_file_upload_notification" INTEGER NOT NULL DEFAULT 0 CHECK ("is_file_upload_notification" IN (0, 1)), "file_downloading" INTEGER NOT NULL DEFAULT 0 CHECK ("file_downloading" IN (0, 1)), "file_uploading" INTEGER NOT NULL DEFAULT 0 CHECK ("file_uploading" IN (0, 1)), "file_metadata_i_d" TEXT NULL, "quoting" TEXT NULL, "quoting_reference_kind" INTEGER NULL, "sticker_pack_i_d" TEXT NULL, "pseudo_message_type" INTEGER NULL, "pseudo_message_data" TEXT NULL, "delta_chat_id" INTEGER NULL, "delta_msg_id" INTEGER NULL, "delta_account_id" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("stanza_i_d"));
CREATE TABLE IF NOT EXISTS "message_collections" ("id" TEXT NOT NULL, "title" TEXT NULL, "is_system" INTEGER NOT NULL DEFAULT 0 CHECK ("is_system" IN (0, 1)), "sort_order" INTEGER NOT NULL DEFAULT 0, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "active" INTEGER NOT NULL DEFAULT 1 CHECK ("active" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE IF NOT EXISTS "message_collection_memberships" ("collection_id" TEXT NOT NULL, "chat_jid" TEXT NOT NULL, "message_reference_id" TEXT NOT NULL, "message_stanza_id" TEXT NULL, "message_origin_id" TEXT NULL, "message_muc_stanza_id" TEXT NULL, "delta_account_id" INTEGER NULL, "delta_msg_id" INTEGER NULL, "added_at" TEXT NOT NULL, "active" INTEGER NOT NULL DEFAULT 1 CHECK ("active" IN (0, 1)), PRIMARY KEY ("collection_id", "chat_jid", "message_reference_id"));
CREATE TABLE IF NOT EXISTS "pinned_messages" ("message_stanza_id" TEXT NOT NULL, "chat_jid" TEXT NOT NULL, "pinned_at" TEXT NOT NULL, "active" INTEGER NOT NULL DEFAULT 1 CHECK ("active" IN (0, 1)), PRIMARY KEY ("message_stanza_id", "chat_jid"));
CREATE TABLE IF NOT EXISTS "message_attachments" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "message_id" TEXT NOT NULL, "file_metadata_id" TEXT NOT NULL, "sort_order" INTEGER NOT NULL DEFAULT 0, "transport_group_id" TEXT NULL, UNIQUE(message_id, file_metadata_id));
CREATE TABLE IF NOT EXISTS "message_shares" ("share_id" TEXT NOT NULL, "originator_dc_msg_id" INTEGER NULL, "subject_token" TEXT NULL, "subject" TEXT NULL, "created_at" TEXT NOT NULL, "participant_count" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("share_id"), UNIQUE(subject_token));
CREATE TABLE IF NOT EXISTS "message_participants" ("share_id" TEXT NOT NULL REFERENCES message_shares (share_id), "contact_jid" TEXT NOT NULL, "role" TEXT NOT NULL, PRIMARY KEY ("share_id", "contact_jid"));
CREATE TABLE IF NOT EXISTS "message_copies" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "share_id" TEXT NOT NULL REFERENCES message_shares (share_id), "dc_msg_id" INTEGER NOT NULL, "dc_chat_id" INTEGER NOT NULL, "dc_account_id" INTEGER NOT NULL DEFAULT 0, UNIQUE(dc_msg_id, dc_account_id));
CREATE TABLE IF NOT EXISTS "drafts" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "jids" TEXT NOT NULL, "draft_sync_id" TEXT NOT NULL DEFAULT '', "draft_updated_at" TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP), "draft_source_id" TEXT NOT NULL DEFAULT 'legacy', "draft_recipients" TEXT NOT NULL DEFAULT '[]', "body" TEXT NULL, "subject" TEXT NULL, "quoting_stanza_id" TEXT NULL, "quoting_reference_kind" INTEGER NULL, "attachment_metadata_ids" TEXT NOT NULL DEFAULT '[]');
CREATE TABLE IF NOT EXISTS "file_metadata" ("id" TEXT NOT NULL, "filename" TEXT NOT NULL, "path" TEXT NULL, "source_urls" TEXT NULL, "mime_type" TEXT NULL, "size_bytes" INTEGER NULL, "width" INTEGER NULL, "height" INTEGER NULL, "encryption_key" TEXT NULL, "encryption_i_v" TEXT NULL, "encryption_scheme" TEXT NULL, "cipher_text_hashes" TEXT NULL, "plain_text_hashes" TEXT NULL, "thumbnail_type" TEXT NULL, "thumbnail_data" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE IF NOT EXISTS "draft_attachment_refs" ("draft_id" INTEGER NOT NULL REFERENCES drafts (id), "file_metadata_id" TEXT NOT NULL REFERENCES file_metadata (id), PRIMARY KEY ("draft_id", "file_metadata_id"));
CREATE TABLE IF NOT EXISTS "omemo_devices" ("jid" TEXT NOT NULL, "id" INTEGER NOT NULL, "identity_key" TEXT NOT NULL, "signed_pre_key" TEXT NOT NULL, "old_signed_pre_key" TEXT NULL, "onetime_pre_keys" TEXT NOT NULL, "label" TEXT NULL, PRIMARY KEY ("jid", "id"));
CREATE TABLE IF NOT EXISTS "omemo_trusts" ("jid" TEXT NOT NULL, "device" INTEGER NOT NULL, "trust" INTEGER NOT NULL DEFAULT 1, "enabled" INTEGER NOT NULL DEFAULT 1 CHECK ("enabled" IN (0, 1)), "trusted" INTEGER NOT NULL DEFAULT 0 CHECK ("trusted" IN (0, 1)), "label" TEXT NULL, PRIMARY KEY ("jid", "device"));
CREATE TABLE IF NOT EXISTS "omemo_device_lists" ("jid" TEXT NOT NULL, "devices" TEXT NOT NULL, PRIMARY KEY ("jid"));
CREATE TABLE IF NOT EXISTS "omemo_ratchets" ("jid" TEXT NOT NULL, "device" INTEGER NOT NULL, "serialized" TEXT NOT NULL, PRIMARY KEY ("jid", "device"));
CREATE TABLE IF NOT EXISTS "omemo_bundle_caches" ("jid" TEXT NOT NULL, "device" INTEGER NOT NULL, "bundle_json" TEXT NOT NULL, "updated_at" TEXT NOT NULL, PRIMARY KEY ("jid", "device"));
CREATE TABLE IF NOT EXISTS "reactions" ("message_i_d" TEXT NOT NULL REFERENCES messages (stanza_i_d), "sender_jid" TEXT NOT NULL, "emoji" TEXT NOT NULL, PRIMARY KEY ("message_i_d", "sender_jid", "emoji"));
CREATE TABLE IF NOT EXISTS "reaction_states" ("message_i_d" TEXT NOT NULL REFERENCES messages (stanza_i_d), "sender_jid" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "identity_verified" INTEGER NOT NULL DEFAULT 1 CHECK ("identity_verified" IN (0, 1)), PRIMARY KEY ("message_i_d", "sender_jid"));
CREATE TABLE IF NOT EXISTS "notifications" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "sender_jid" TEXT NULL, "chat_jid" TEXT NOT NULL, "sender_name" TEXT NULL, "body" TEXT NOT NULL, "timestamp" TEXT NOT NULL, "avatar_path" TEXT NULL, "media_mime_type" TEXT NULL, "media_path" TEXT NULL);
CREATE TABLE IF NOT EXISTS "roster" ("jid" TEXT NOT NULL, "title" TEXT NOT NULL, "presence" TEXT NOT NULL, "status" TEXT NULL, "avatar_path" TEXT NULL, "avatar_hash" TEXT NULL, "subscription" TEXT NOT NULL, "ask" TEXT NULL, "contact_i_d" TEXT NULL, "contact_avatar_path" TEXT NULL, "contact_display_name" TEXT NULL, PRIMARY KEY ("jid"));
CREATE TABLE IF NOT EXISTS "invites" ("jid" TEXT NOT NULL, "title" TEXT NOT NULL, PRIMARY KEY ("jid"));
CREATE TABLE IF NOT EXISTS "chats" ("jid" TEXT NOT NULL, "title" TEXT NOT NULL, "type" INTEGER NOT NULL, "primary_view" INTEGER NOT NULL DEFAULT 0, "transport" INTEGER NOT NULL DEFAULT 0, "my_nickname" TEXT NULL, "avatar_path" TEXT NULL, "avatar_hash" TEXT NULL, "last_message" TEXT NULL, "alert" TEXT NULL, "last_change_timestamp" TEXT NOT NULL, "unread_count" INTEGER NOT NULL DEFAULT 0, "open" INTEGER NOT NULL DEFAULT 0 CHECK ("open" IN (0, 1)), "muted" INTEGER NOT NULL DEFAULT 0 CHECK ("muted" IN (0, 1)), "notification_preview_setting" INTEGER NULL, "favorited" INTEGER NOT NULL DEFAULT 0 CHECK ("favorited" IN (0, 1)), "archived" INTEGER NOT NULL DEFAULT 0 CHECK ("archived" IN (0, 1)), "hidden" INTEGER NOT NULL DEFAULT 0 CHECK ("hidden" IN (0, 1)), "spam" INTEGER NOT NULL DEFAULT 0 CHECK ("spam" IN (0, 1)), "spam_updated_at" TEXT NULL, "marker_responsive" INTEGER NULL CHECK ("marker_responsive" IN (0, 1)), "share_signature_enabled" INTEGER NULL CHECK ("share_signature_enabled" IN (0, 1)), "attachment_auto_download" INTEGER NULL, "encryption_protocol" INTEGER NOT NULL DEFAULT 1, "contact_i_d" TEXT NULL, "contact_display_name" TEXT NULL, "contact_avatar_path" TEXT NULL, "contact_avatar_hash" TEXT NULL, "contact_jid" TEXT NULL, "chat_state" TEXT NULL, "delta_chat_id" INTEGER NULL, "email_address" TEXT NULL, "email_from_address" TEXT NULL, PRIMARY KEY ("jid"));
CREATE TABLE IF NOT EXISTS "recipient_addresses" ("address" TEXT NOT NULL, "last_seen" TEXT NOT NULL, PRIMARY KEY ("address"));
CREATE TABLE IF NOT EXISTS "email_chat_accounts" ("chat_jid" TEXT NOT NULL REFERENCES chats (jid), "delta_account_id" INTEGER NOT NULL DEFAULT 0, "delta_chat_id" INTEGER NOT NULL, PRIMARY KEY ("chat_jid", "delta_account_id"), UNIQUE(delta_account_id, delta_chat_id));
CREATE TABLE IF NOT EXISTS "contacts" ("native_i_d" TEXT NOT NULL, "jid" TEXT NOT NULL, "display_name" TEXT NULL, PRIMARY KEY ("native_i_d"));
CREATE TABLE IF NOT EXISTS "blocklist" ("jid" TEXT NOT NULL, "blocked_at" TEXT NOT NULL, PRIMARY KEY ("jid"));
CREATE TABLE IF NOT EXISTS "stickers" ("id" TEXT NOT NULL, "sticker_pack_i_d" TEXT NOT NULL, "file_metadata_i_d" TEXT NOT NULL, "description" TEXT NOT NULL, "suggestions" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE IF NOT EXISTS "sticker_packs" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "description" TEXT NOT NULL, "hash_algorithm" TEXT NOT NULL, "hash_value" TEXT NOT NULL, "restricted" INTEGER NOT NULL CHECK ("restricted" IN (0, 1)), "added_timestamp" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE IF NOT EXISTS "email_blocklist" ("address" TEXT NOT NULL, "blocked_at" TEXT NOT NULL, "blocked_message_count" INTEGER NOT NULL DEFAULT 0, "last_blocked_message_at" TEXT NULL, "source_id" TEXT NULL, PRIMARY KEY ("address"));
CREATE TABLE IF NOT EXISTS "email_spamlist" ("address" TEXT NOT NULL, "flagged_at" TEXT NOT NULL, "source_id" TEXT NULL, PRIMARY KEY ("address"));
CREATE VIRTUAL TABLE messages_fts
USING fts5(
  body,
  content='messages',
  content_rowid='rowid'
);
CREATE TRIGGER messages_ai
AFTER INSERT ON messages
BEGIN
  INSERT INTO messages_fts(rowid, body)
  VALUES (new.rowid, new.body);
END;
CREATE TRIGGER messages_ad
AFTER DELETE ON messages
BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, body)
  VALUES ('delete', old.rowid, old.body);
END;
CREATE TRIGGER messages_au
AFTER UPDATE ON messages
BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, body)
  VALUES ('delete', old.rowid, old.body);
  INSERT INTO messages_fts(rowid, body)
  VALUES (new.rowid, new.body);
END;
CREATE TRIGGER recipient_addresses_messages_ai
AFTER INSERT ON messages
BEGIN
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.sender_jid)), new.timestamp
  WHERE new.sender_jid IS NOT NULL
    AND trim(new.sender_jid) != ''
    AND instr(new.sender_jid, '@') > 0
  ON CONFLICT(address) DO UPDATE SET last_seen = CASE WHEN excluded.last_seen > recipient_addresses.last_seen THEN excluded.last_seen ELSE recipient_addresses.last_seen END;
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.chat_jid)), new.timestamp
  WHERE new.chat_jid IS NOT NULL
    AND trim(new.chat_jid) != ''
    AND instr(new.chat_jid, '@') > 0
  ON CONFLICT(address) DO UPDATE SET last_seen = CASE WHEN excluded.last_seen > recipient_addresses.last_seen THEN excluded.last_seen ELSE recipient_addresses.last_seen END;
END;
CREATE TRIGGER recipient_addresses_chats_ai
AFTER INSERT ON chats
BEGIN
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.jid)), new.last_change_timestamp
  WHERE new.jid IS NOT NULL
    AND trim(new.jid) != ''
    AND instr(new.jid, '@') > 0
  ON CONFLICT(address) DO UPDATE SET last_seen = CASE WHEN excluded.last_seen > recipient_addresses.last_seen THEN excluded.last_seen ELSE recipient_addresses.last_seen END;
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.contact_jid)), new.last_change_timestamp
  WHERE new.contact_jid IS NOT NULL
    AND trim(new.contact_jid) != ''
    AND instr(new.contact_jid, '@') > 0
  ON CONFLICT(address) DO UPDATE SET last_seen = CASE WHEN excluded.last_seen > recipient_addresses.last_seen THEN excluded.last_seen ELSE recipient_addresses.last_seen END;
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.email_address)), new.last_change_timestamp
  WHERE new.email_address IS NOT NULL
    AND trim(new.email_address) != ''
    AND instr(new.email_address, '@') > 0
  ON CONFLICT(address) DO UPDATE SET last_seen = CASE WHEN excluded.last_seen > recipient_addresses.last_seen THEN excluded.last_seen ELSE recipient_addresses.last_seen END;
END;
CREATE TRIGGER recipient_addresses_chats_au
AFTER UPDATE OF last_change_timestamp, jid, contact_jid, email_address ON chats
BEGIN
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.jid)), new.last_change_timestamp
  WHERE new.jid IS NOT NULL
    AND trim(new.jid) != ''
    AND instr(new.jid, '@') > 0
  ON CONFLICT(address) DO UPDATE SET last_seen = CASE WHEN excluded.last_seen > recipient_addresses.last_seen THEN excluded.last_seen ELSE recipient_addresses.last_seen END;
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.contact_jid)), new.last_change_timestamp
  WHERE new.contact_jid IS NOT NULL
    AND trim(new.contact_jid) != ''
    AND instr(new.contact_jid, '@') > 0
  ON CONFLICT(address) DO UPDATE SET last_seen = CASE WHEN excluded.last_seen > recipient_addresses.last_seen THEN excluded.last_seen ELSE recipient_addresses.last_seen END;
  INSERT INTO recipient_addresses(address, last_seen)
  SELECT lower(trim(new.email_address)), new.last_change_timestamp
  WHERE new.email_address IS NOT NULL
    AND trim(new.email_address) != ''
    AND instr(new.email_address, '@') > 0
  ON CONFLICT(address) DO UPDATE SET last_seen = CASE WHEN excluded.last_seen > recipient_addresses.last_seen THEN excluded.last_seen ELSE recipient_addresses.last_seen END;
END;
''';

const String _seedSchema39Sql = r'''
INSERT INTO chats(jid, title, type, primary_view, transport, last_change_timestamp)
VALUES(
  'peer@example.com',
  'Peer',
  0,
  0,
  0,
  '2026-01-02T03:04:05.000Z'
);
INSERT INTO chats(
  jid,
  title,
  type,
  primary_view,
  transport,
  last_change_timestamp,
  delta_chat_id,
  email_address
) VALUES(
  'mail@example.com',
  'Mail',
  0,
  0,
  1,
  '2026-01-03T03:04:05.000Z',
  42,
  'mail@example.com'
);
INSERT INTO messages(id, stanza_i_d, sender_jid, chat_jid, body, timestamp)
VALUES(
  'message-row',
  'stanza-1',
  'peer@example.com',
  'peer@example.com',
  'hello from schema 39',
  '2026-01-02T03:04:05.000Z'
);
INSERT INTO messages(id, stanza_i_d, sender_jid, chat_jid, body, timestamp)
VALUES(
  'mail-orphan-row',
  'mail-orphan',
  'mail@example.com',
  'mail@example.com',
  'legacy mail orphan',
  '2026-01-03T04:04:05.000Z'
);
INSERT INTO pinned_messages(message_stanza_id, chat_jid, pinned_at, active)
VALUES(
  'stanza-1',
  'peer@example.com',
  '2026-01-02T04:04:05.000Z',
  1
);
INSERT INTO email_chat_accounts(chat_jid, delta_account_id, delta_chat_id)
VALUES('mail@example.com', 0, 42);
INSERT INTO file_metadata(id, filename, mime_type)
VALUES('file-1', 'report.pdf', 'application/pdf');
INSERT INTO drafts(
  jids,
  draft_sync_id,
  draft_updated_at,
  draft_source_id,
  draft_recipients,
  body,
  attachment_metadata_ids
) VALUES(
  '["peer@example.com"]',
  'draft-sync',
  '2026-01-02T05:04:05.000Z',
  'legacy',
  '[]',
  'draft body',
  '["file-1"]'
);
INSERT INTO message_attachments(message_id, file_metadata_id, sort_order)
VALUES('stanza-1', 'file-1', 0);
''';
