// ignore_for_file: avoid_renaming_method_parameters

import 'dart:io';
import 'dart:math';

import 'package:axichat/src/common/bool_tool.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:omemo_dart/omemo_dart.dart' as omemo;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import 'models.dart';

part 'database.g.dart';

abstract interface class Database {
  /// Must be idempotent.
  Future<void> close();
}

abstract interface class XmppDatabase implements Database {
  Stream<List<Message>> watchChatMessages(
    String jid, {
    required int start,
    required int end,
  });

  Future<List<Message>> getChatMessages(
    String jid, {
    required int start,
    required int end,
  });

  Future<Message?> getMessageByStanzaID(String stanzaID);

  Future<Message?> getMessageByOriginID(String originID);

  Future<void> saveMessage(Message message);

  Future<void> saveMessageError({
    required String stanzaID,
    required MessageError error,
  });

  Future<void> saveMessageDevice({
    required String stanzaID,
    required int deviceID,
    required String to,
  });

  Future<void> saveMessageEdit({
    required String stanzaID,
    required String? body,
  });

  Future<void> markMessageRetracted(String stanzaID);

  Future<void> markMessageAcked(String stanzaID);

  Future<void> markMessageReceived(String stanzaID);

  Future<void> markMessageDisplayed(String stanzaID);

  Future<void> removeChatMessages(String jid);

  Stream<List<Draft>> watchDrafts({required int start, required int end});

  Future<List<Draft>> getDrafts({required int start, required int end});

  Future<Draft?> getDraft(int id);

  Future<void> saveDraft({
    int? id,
    required List<String> jids,
    required String body,
  });

  Future<void> removeDraft(int id);

  Future<OmemoDevice?> getOmemoDevice(String jid);

  Future<void> saveOmemoDevice(OmemoDevice device);

  Future<OmemoDeviceList?> getOmemoDeviceList(String jid);

  Future<void> saveOmemoDeviceList(OmemoDeviceList data);

  Future<List<OmemoTrust>> getOmemoTrusts(String jid);

  Future<OmemoTrust?> getOmemoTrust(String jid, int device);

  Future<void> setOmemoTrust(OmemoTrust trust);

  Future<void> setOmemoTrustLabel({
    required String jid,
    required int device,
    required String? label,
  });

  Future<void> resetOmemoTrust(String jid);

  Future<List<OmemoRatchet>> getOmemoRatchets(String jid);

  Future<void> saveOmemoRatchets(List<OmemoRatchet> ratchets);

  Future<void> removeOmemoRatchets(List<(String, int)> ratchets);

  Future<void> saveFileMetadata(FileMetadataData metadata);

  Stream<List<Chat>> watchChats({required int start, required int end});

  Future<List<Chat>> getChats({required int start, required int end});

  Future<Chat?> getChat(String jid);

  Future<void> createChat(Chat chat);

  Future<void> updateChat(Chat chat);

  Stream<Chat?> watchChat(String jid);

  Future<Chat?> openChat(String jid);

  Future<Chat?> closeChat();

  Future<void> markChatMuted({
    required String jid,
    required bool muted,
  });

  Future<void> markChatFavorited({
    required String jid,
    required bool favorited,
  });

  Future<void> markChatMarkerResponsive({
    required String jid,
    required bool responsive,
  });

  Future<void> markChatsMarkerResponsive({required bool responsive});

  Future<void> updateChatState({
    required String chatJid,
    required mox.ChatState state,
  });

  Future<void> updateChatEncryption({
    required String chatJid,
    required EncryptionProtocol protocol,
  });

  Future<void> updateChatAlert({
    required String chatJid,
    required String? alert,
  });

  Future<void> removeChat(String jid);

  Stream<List<RosterItem>> watchRoster({required int start, required int end});

  Future<List<RosterItem>> getRoster();

  Future<RosterItem?> getRosterItem(String jid);

  Future<void> saveRosterItem(RosterItem item);

  Future<void> saveRosterItems(List<RosterItem> items);

  Future<void> updateRosterItem(RosterItem item);

  Future<void> updateRosterItems(List<RosterItem> items);

  Future<void> removeRosterItem(String jid);

  Future<void> removeRosterItems(List<String> jids);

  Future<void> updatePresence({
    required String jid,
    required Presence presence,
    String? status,
  });

  Future<void> markSubscriptionBoth(String jid);

  Stream<List<Invite>> watchInvites({required int start, required int end});

  Future<List<Invite>> getInvites({required int start, required int end});

  Future<void> saveInvite(Invite invite);

  Future<void> deleteInvite(String jid);

  Stream<List<BlocklistData>> watchBlocklist({
    required int start,
    required int end,
  });

  Future<List<BlocklistData>> getBlocklist({
    required int start,
    required int end,
  });

  Future<void> blockJid(String jid);

  Future<void> blockJids(List<String> jids);

  Future<void> unblockJid(String jid);

  Future<void> unblockJids(List<String> jids);

  Future<void> replaceBlocklist(List<String> blocks);

  Future<void> deleteBlocklist();

  Future<void> deleteAll();

  Future<void> deleteFile();
}

abstract class BaseAccessor<D, T extends TableInfo<Table, D>>
    extends DatabaseAccessor<XmppDrift> {
  BaseAccessor(super.attachedDatabase);

  T get table;

  Stream<List<D>> watchAll() => select(table).watch();

  Future<List<D>> selectAll() => select(table).get();

  Future<D?> selectOne(covariant Object value);

  Future<void> insertOne(Insertable<D> data) =>
      into(table).insert(data, mode: InsertMode.insertOrIgnore);

  Future<void> insertOrUpdateOne(Insertable<D> data) =>
      into(table).insertOnConflictUpdate(data);

  Future<void> updateOne(Insertable<D> data) =>
      (update(table)..whereSamePrimaryKey(data)).write(data);

  Future<void> deleteOne(covariant Object value);
}

@DriftAccessor(tables: [Messages])
class MessagesAccessor extends BaseAccessor<Message, $MessagesTable>
    with _$MessagesAccessorMixin {
  MessagesAccessor(super.attachedDatabase);

  @override
  $MessagesTable get table => messages;

  Stream<List<Message>> watchChat(String jid, {int limit = 50}) =>
      (select(table)
            ..where((table) => table.chatJid.equals(jid))
            ..orderBy([
              (t) => OrderingTerm(
                    expression: t.timestamp,
                    mode: OrderingMode.desc,
                  )
            ])
            ..limit(limit))
          .watch();

  Future<List<Message>> selectChatMessages(String jid) =>
      (select(table)..where((table) => table.chatJid.equals(jid))).get();

  @override
  Future<Message?> selectOne(String stanzaID) =>
      (select(table)..where((table) => table.stanzaID.equals(stanzaID)))
          .getSingleOrNull();

  Future<Message?> selectOneByOriginID(String originID) =>
      (select(table)..where((table) => table.originID.equals(originID)))
          .getSingleOrNull();

  Future<void> updateTrust(int device, BTBVTrustState trust, bool trusted) =>
      (update(table)..where((table) => table.deviceID.equals(device)))
          .write(MessagesCompanion(trust: Value(trust)));

  @override
  Future<void> deleteOne(String stanzaID) =>
      (delete(table)..where((item) => item.stanzaID.equals(stanzaID))).go();

  Future<void> deleteChatMessages(String jid) =>
      (delete(table)..where((item) => item.chatJid.equals(jid))).go();
}

@DriftAccessor(tables: [Drafts])
class DraftsAccessor extends BaseAccessor<Draft, $DraftsTable>
    with _$DraftsAccessorMixin {
  DraftsAccessor(super.attachedDatabase);

  @override
  $DraftsTable get table => drafts;

  @override
  Future<Draft?> selectOne(int id) =>
      (select(table)..where((table) => table.id.equals(id))).getSingleOrNull();

  @override
  Future<void> deleteOne(int id) =>
      (delete(table)..where((item) => item.id.equals(id))).go();
}

@DriftAccessor(tables: [OmemoDevices])
class OmemoDevicesAccessor extends BaseAccessor<OmemoDevice, $OmemoDevicesTable>
    with _$OmemoDevicesAccessorMixin {
  OmemoDevicesAccessor(super.attachedDatabase);

  @override
  $OmemoDevicesTable get table => omemoDevices;

  @override
  Future<OmemoDevice?> selectOne(String value) =>
      (select(table)..where((table) => table.jid.equals(value)))
          .getSingleOrNull();

  Future<OmemoDevice?> selectByID(int value) =>
      (select(table)..where((table) => table.id.equals(value)))
          .getSingleOrNull();

  Future<List<OmemoDevice>> selectByJid(String jid) =>
      (select(table)..where((table) => table.jid.equals(jid))).get();

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((table) => table.jid.equals(value))).go();
}

@DriftAccessor(tables: [OmemoTrusts])
class OmemoTrustsAccessor extends BaseAccessor<OmemoTrust, $OmemoTrustsTable>
    with _$OmemoTrustsAccessorMixin {
  OmemoTrustsAccessor(super.attachedDatabase);

  @override
  $OmemoTrustsTable get table => omemoTrusts;

  @override
  Future<OmemoTrust?> selectOne(OmemoTrust value) =>
      (select(table)..whereSamePrimaryKey(value)).getSingleOrNull();

  Future<List<OmemoTrust>> selectByJid(String jid) =>
      (select(table)..where((table) => table.jid.equals(jid))).get();

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((table) => table.jid.equals(value))).go();
}

@DriftAccessor(tables: [OmemoDeviceLists])
class OmemoDeviceListsAccessor
    extends BaseAccessor<OmemoDeviceList, $OmemoDeviceListsTable>
    with _$OmemoDeviceListsAccessorMixin {
  OmemoDeviceListsAccessor(super.attachedDatabase);

  @override
  $OmemoDeviceListsTable get table => omemoDeviceLists;

  @override
  Future<OmemoDeviceList?> selectOne(String value) =>
      (select(table)..where((table) => table.jid.equals(value)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((table) => table.jid.equals(value))).go();
}

@DriftAccessor(tables: [OmemoRatchets])
class OmemoRatchetsAccessor
    extends BaseAccessor<OmemoRatchet, $OmemoRatchetsTable>
    with _$OmemoRatchetsAccessorMixin {
  OmemoRatchetsAccessor(super.attachedDatabase);

  @override
  $OmemoRatchetsTable get table => omemoRatchets;

  @override
  Future<OmemoRatchet?> selectOne(String value) =>
      (select(table)..where((table) => table.jid.equals(value)))
          .getSingleOrNull();

  Future<List<OmemoRatchet>> selectByJid(String jid) =>
      (select(table)..where((table) => table.jid.equals(jid))).get();

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((table) => table.jid.equals(value))).go();
}

@DriftAccessor(tables: [FileMetadata])
class FileMetadataAccessor
    extends BaseAccessor<FileMetadataData, $FileMetadataTable>
    with _$FileMetadataAccessorMixin {
  FileMetadataAccessor(super.attachedDatabase);

  @override
  $FileMetadataTable get table => fileMetadata;

  @override
  Future<FileMetadataData?> selectOne(Object value) {
    // TODO: implement selectOne
    throw UnimplementedError();
  }

  Future<FileMetadataData?> selectOneByPlaintextHashes(
          Map<HashFunction, String> hashes) =>
      (select(table)
            ..where((table) => table.plainTextHashes.equalsValue(hashes)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne(String id) =>
      (delete(table)..where((item) => item.id.equals(id))).go();
}

@DriftAccessor(tables: [Chats])
class ChatsAccessor extends BaseAccessor<Chat, $ChatsTable>
    with _$ChatsAccessorMixin {
  ChatsAccessor(super.attachedDatabase);

  @override
  $ChatsTable get table => chats;

  @override
  Stream<List<Chat>> watchAll() => (select(table)
        ..orderBy([
          (t) => OrderingTerm(
                expression: t.favorited,
                mode: OrderingMode.desc,
              ),
          (t) => OrderingTerm(
                expression: t.lastChangeTimestamp,
                mode: OrderingMode.desc,
              ),
        ]))
      .watch();

  Stream<Chat?> watchOne(String jid) =>
      (select(table)..where((table) => table.jid.equals(jid)))
          .watchSingleOrNull();

  @override
  Future<Chat?> selectOne(String value) =>
      (select(table)..where((table) => table.jid.equals(value)))
          .getSingleOrNull();

  Future<Chat?> selectOpen() =>
      (select(table)..where((table) => table.open.equals(true)))
          .getSingleOrNull();

  Future<List<Chat>> closeOpen() =>
      (update(table)..where((table) => table.open.equals(true))).writeReturning(
          const ChatsCompanion(
              open: Value(false), chatState: Value(mox.ChatState.gone)));

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((item) => item.jid.equals(value))).go();
}

@DriftAccessor(tables: [Roster])
class RosterAccessor extends BaseAccessor<RosterItem, $RosterTable>
    with _$RosterAccessorMixin {
  RosterAccessor(super.attachedDatabase);

  @override
  $RosterTable get table => roster;

  @override
  Future<RosterItem?> selectOne(String value) =>
      (select(table)..where((table) => table.jid.equals(value)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((table) => table.jid.equals(value))).go();
}

@DriftAccessor(tables: [Invites])
class InvitesAccessor extends BaseAccessor<Invite, $InvitesTable>
    with _$InvitesAccessorMixin {
  InvitesAccessor(super.attachedDatabase);

  @override
  $InvitesTable get table => invites;

  @override
  Future<Invite?> selectOne(String value) =>
      (select(table)..where((table) => table.jid.equals(value)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((item) => item.jid.equals(value))).go();
}

@DriftAccessor(tables: [Blocklist])
class BlocklistAccessor extends BaseAccessor<BlocklistData, $BlocklistTable>
    with _$BlocklistAccessorMixin {
  BlocklistAccessor(super.attachedDatabase);

  @override
  $BlocklistTable get table => blocklist;

  @override
  Future<BlocklistData?> selectOne(String value) =>
      (select(table)..where((table) => table.jid.equals(value)))
          .getSingleOrNull();

  @override
  Future<void> deleteOne(String value) =>
      (delete(table)..where((item) => item.jid.equals(value))).go();

  Future<void> deleteAll() => delete(blocklist).go();
}

@DriftDatabase(tables: [
  Messages,
  Drafts,
  OmemoDevices,
  OmemoTrusts,
  OmemoDeviceLists,
  OmemoRatchets,
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
], daos: [
  MessagesAccessor,
  DraftsAccessor,
  OmemoDevicesAccessor,
  OmemoTrustsAccessor,
  OmemoDeviceListsAccessor,
  OmemoRatchetsAccessor,
  FileMetadataAccessor,
  ChatsAccessor,
  RosterAccessor,
  InvitesAccessor,
  BlocklistAccessor,
])
class XmppDrift extends _$XmppDrift implements XmppDatabase {
  XmppDrift._(this._file, super.e) : super();

  static XmppDrift? _instance;

  factory XmppDrift({
    required File file,
    required String passphrase,
    QueryExecutor? executor,
  }) =>
      _instance ??=
          XmppDrift._(file, executor ?? _openDatabase(file, passphrase));

  final _log = Logger('XmppDrift');
  final File _file;

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

  @override
  Stream<List<Message>> watchChatMessages(
    String jid, {
    required int start,
    required int end,
  }) {
    return messagesAccessor.watchChat(jid, limit: end);
  }

  @override
  Future<List<Message>> getChatMessages(
    String jid, {
    required int start,
    required int end,
  }) {
    return messagesAccessor.selectChatMessages(jid);
  }

  Future<Message?> getLastMessageForChat(String jid) async {
    final messages = await getChatMessages(jid, start: 0, end: 1);

    if (messages.isEmpty) {
      return null;
    }
    return messages.last;
  }

  @override
  Future<Message?> getMessageByStanzaID(String stanzaID) =>
      messagesAccessor.selectOne(stanzaID);

  @override
  Future<Message?> getMessageByOriginID(String originID) =>
      messagesAccessor.selectOneByOriginID(originID);

  @override
  Future<void> saveMessage(Message message) async {
    _log.info('Saving message: ${message.stanzaID} with body: '
        '${message.body?.substring(0, min(10, message.body!.length))}...');
    final hasBody = message.body != null;
    await transaction(() async {
      await into(chats).insert(
        ChatsCompanion.insert(
          jid: message.chatJid,
          title: mox.JID.fromString(message.chatJid).local,
          type: ChatType.chat,
          unreadCount: Value(hasBody.toBinary),
          lastMessage: Value.absentIfNull(message.body),
          lastChangeTimestamp: DateTime.timestamp(),
          encryptionProtocol: Value(message.encryptionProtocol),
        ),
        onConflict: DoUpdate.withExcluded(
          (old, excluded) => ChatsCompanion.custom(
            unreadCount: const Constant(0).iif(
              old.open.isValue(true),
              old.unreadCount + Constant(hasBody.toBinary),
            ),
            lastMessage: excluded.lastMessage,
            lastChangeTimestamp: excluded.lastChangeTimestamp,
          ),
        ),
      );
      BTBVTrustState? trust;
      bool? trusted;
      if (message.deviceID case final int deviceID) {
        final trustData = await omemoTrustsAccessor
            .selectOne(OmemoTrust(jid: message.senderJid, device: deviceID));
        trust = trustData?.state;
        trusted = trustData?.trusted;
      }
      await messagesAccessor.insertOne(message.copyWith(
        trust: trust,
        trusted: trusted,
      ));
    });
  }

  @override
  Future<void> saveMessageError({
    required String stanzaID,
    required MessageError error,
  }) async {
    _log.info('Updating message: $stanzaID with error: ${error.name}...');
    await messagesAccessor.updateOne(MessagesCompanion(
      stanzaID: Value(stanzaID),
      error: Value(error),
    ));
  }

  @override
  Future<void> saveMessageDevice({
    required String stanzaID,
    required int deviceID,
    required String to,
  }) async {
    _log.info('Updating message: $stanzaID with device: $deviceID...');
    await messagesAccessor.updateOne(MessagesCompanion(
      stanzaID: Value(stanzaID),
      deviceID: Value(deviceID),
      trusted: const Value(true),
    ));
  }

  @override
  Future<void> saveMessageEdit({
    required String stanzaID,
    required String? body,
  }) async {
    _log.info('Editing message: $stanzaID with body: '
        '${body?.substring(0, min(10, body.length))}...');
    await messagesAccessor.updateOne(MessagesCompanion(
      stanzaID: Value(stanzaID),
      edited: const Value(true),
      body: Value(body),
    ));
  }

  @override
  Future<void> markMessageRetracted(String stanzaID) async {
    _log.info('Retracting message: $stanzaID...');
    await transaction(() async {
      final message = await (update(messages)
            ..where((messages) => messages.stanzaID.equals(stanzaID)))
          .writeReturning(const MessagesCompanion(
        retracted: Value(true),
        body: Value(null),
        fileMetadataID: Value(null),
        error: Value(MessageError.none),
        warning: Value(MessageWarning.none),
      ));
      if (message.firstOrNull?.fileMetadataID case final id?) {
        await fileMetadataAccessor.deleteOne(id);
      }
    });
  }

  @override
  Future<void> markMessageAcked(String stanzaID) async {
    _log.info('Marking message: $stanzaID acked...');
    await messagesAccessor.updateOne(MessagesCompanion(
      stanzaID: Value(stanzaID),
      acked: const Value(true),
    ));
  }

  @override
  Future<void> markMessageReceived(String stanzaID) async {
    _log.info('Marking message: $stanzaID received...');
    await messagesAccessor.updateOne(MessagesCompanion(
      stanzaID: Value(stanzaID),
      received: const Value(true),
    ));
  }

  @override
  Future<void> markMessageDisplayed(String stanzaID) async {
    _log.info('Marking message: $stanzaID displayed...');
    await messagesAccessor.updateOne(MessagesCompanion(
      stanzaID: Value(stanzaID),
      displayed: const Value(true),
    ));
  }

  @override
  Future<void> removeChatMessages(String jid) =>
      messagesAccessor.deleteChatMessages(jid);

  @override
  Stream<List<Draft>> watchDrafts({required int start, required int end}) {
    return draftsAccessor.watchAll();
  }

  @override
  Future<List<Draft>> getDrafts({required int start, required int end}) {
    return draftsAccessor.selectAll();
  }

  @override
  Future<Draft?> getDraft(int id) => draftsAccessor.selectOne(id);

  @override
  Future<void> saveDraft({
    int? id,
    required List<String> jids,
    required String body,
  }) =>
      draftsAccessor.insertOrUpdateOne(DraftsCompanion(
        id: Value.absentIfNull(id),
        jids: Value(jids),
        body: Value(body),
      ));

  @override
  Future<void> removeDraft(int id) => draftsAccessor.deleteOne(id);

  @override
  Future<OmemoDevice?> getOmemoDevice(String jid) =>
      omemoDevicesAccessor.selectOne(jid);

  @override
  Future<void> saveOmemoDevice(OmemoDevice device) async {
    _log.info('Saving OMEMO device: $device from jid: ${device.jid}');
    await omemoDevicesAccessor.insertOrUpdateOne(await device.toDb());
  }

  @override
  Future<OmemoDeviceList?> getOmemoDeviceList(String jid) =>
      omemoDeviceListsAccessor.selectOne(jid);

  @override
  Future<void> saveOmemoDeviceList(OmemoDeviceList data) =>
      omemoDeviceListsAccessor.insertOrUpdateOne(data);

  @override
  Future<List<OmemoTrust>> getOmemoTrusts(String jid) =>
      omemoTrustsAccessor.selectByJid(jid);

  @override
  Future<OmemoTrust?> getOmemoTrust(String jid, int device) =>
      omemoTrustsAccessor.selectOne(OmemoTrust(jid: jid, device: device));

  @override
  Future<void> setOmemoTrust(OmemoTrust trust) async {
    await transaction(() async {
      await messagesAccessor.updateTrust(
        trust.device,
        trust.state,
        trust.trusted,
      );
      return omemoTrustsAccessor.insertOrUpdateOne(OmemoTrust(
        device: trust.device,
        jid: trust.jid,
        trust: trust.state,
        enabled: trust.enabled,
        trusted: trust.trusted,
      ));
    });
  }

  @override
  Future<void> setOmemoTrustLabel({
    required String jid,
    required int device,
    required String? label,
  }) =>
      omemoTrustsAccessor.updateOne(OmemoTrustsCompanion(
        device: Value(device),
        jid: Value(jid),
        label: Value(label),
      ));

  @override
  Future<void> resetOmemoTrust(String jid) async {
    await transaction(() async {
      final trusts = await (delete(omemoTrusts)
            ..where((table) => table.jid.equals(jid)))
          .goAndReturn();
      for (final trust in trusts) {
        await messagesAccessor.updateTrust(
          trust.device,
          trust.state,
          trust.trusted,
        );
      }
    });
  }

  @override
  Future<List<OmemoRatchet>> getOmemoRatchets(String jid) =>
      omemoRatchetsAccessor.selectByJid(jid);

  @override
  Future<void> saveOmemoRatchets(List<OmemoRatchet> ratchets) async {
    await transaction(() async {
      for (final ratchet in ratchets) {
        await omemoRatchetsAccessor.insertOrUpdateOne(await ratchet.toDb());
      }
    });
  }

  @override
  Future<void> removeOmemoRatchets(List<(String, int)> ratchets) async {
    await transaction(() async {
      for (final (jid, deviceID) in ratchets) {
        await (delete(omemoRatchets)
              ..where((omemoRatchets) =>
                  omemoRatchets.jid.equals(jid) &
                  omemoRatchets.device.equals(deviceID)))
            .go();
      }
    });
  }

  @override
  Future<void> saveFileMetadata(FileMetadataData metadata) async {
    await fileMetadataAccessor.insertOne(metadata);
  }

  @override
  Stream<List<Chat>> watchChats({required int start, required int end}) {
    return chatsAccessor.watchAll();
  }

  @override
  Future<List<Chat>> getChats({required int start, required int end}) {
    return chatsAccessor.selectAll();
  }

  @override
  Future<Chat?> getChat(String jid) => chatsAccessor.selectOne(jid);

  @override
  Future<void> createChat(Chat chat) async {
    final lastMessage = await getLastMessageForChat(chat.jid);

    return await chatsAccessor.insertOne(chat.copyWith(
      lastMessage: lastMessage?.body,
      lastChangeTimestamp: lastMessage?.timestamp ?? chat.lastChangeTimestamp,
    ));
  }

  @override
  Future<void> updateChat(Chat chat) => chatsAccessor.updateOne(chat);

  @override
  Stream<Chat?> watchChat(String jid) {
    return chatsAccessor.watchOne(jid);
  }

  @override
  Future<Chat?> openChat(String jid) async {
    final lastMessage = await getLastMessageForChat(jid);

    return await transaction(() async {
      final closed = await closeChat();
      await into(chats).insert(
        ChatsCompanion.insert(
          jid: jid,
          title: mox.JID.fromString(jid).local,
          type: ChatType.chat,
          open: const Value(true),
          unreadCount: const Value(0),
          chatState: const Value(mox.ChatState.active),
          lastMessage: Value(lastMessage?.body),
          lastChangeTimestamp: lastMessage?.timestamp ?? DateTime.timestamp(),
        ),
        onConflict: DoUpdate(
          (old) => const ChatsCompanion(
            open: Value(true),
            unreadCount: Value(0),
            chatState: Value(mox.ChatState.active),
          ),
        ),
      );
      return closed;
    });
  }

  @override
  Future<Chat?> closeChat() async =>
      (await chatsAccessor.closeOpen()).firstOrNull;

  @override
  Future<void> markChatMuted({
    required String jid,
    required bool muted,
  }) async {
    _log.info('Marking chat: $jid as muted: $muted');
    await (update(chats)..where((chats) => chats.jid.equals(jid)))
        .write(ChatsCompanion(muted: Value(muted)));
  }

  @override
  Future<void> markChatFavorited({
    required String jid,
    required bool favorited,
  }) async {
    _log.info('Marking chat: $jid as favorited: $favorited');
    await (update(chats)..where((chats) => chats.jid.equals(jid)))
        .write(ChatsCompanion(favorited: Value(favorited)));
  }

  @override
  Future<void> markChatMarkerResponsive({
    required String jid,
    required bool responsive,
  }) async {
    _log.info('Marking chat: $jid as marker responsive: $responsive');
    await (update(chats)..where((chats) => chats.jid.equals(jid)))
        .write(ChatsCompanion(markerResponsive: Value(responsive)));
  }

  @override
  Future<void> markChatsMarkerResponsive({required bool responsive}) async {
    _log.info('Marking all chats as marker responsive: $responsive');
    await (update(chats))
        .write(ChatsCompanion(markerResponsive: Value(responsive)));
  }

  @override
  Future<void> updateChatState({
    required String chatJid,
    required mox.ChatState state,
  }) async {
    _log.info('Updating chat state to ${state.name}...');
    await chatsAccessor.updateOne(ChatsCompanion(
      jid: Value(chatJid),
      chatState: Value(state),
    ));
  }

  @override
  Future<void> updateChatAlert({
    required String chatJid,
    required String? alert,
  }) async {
    _log.info('Updating chat alert to $alert...');
    await chatsAccessor.updateOne(ChatsCompanion(
      jid: Value(chatJid),
      alert: Value(alert),
    ));
  }

  @override
  Future<void> updateChatEncryption({
    required String chatJid,
    required EncryptionProtocol protocol,
  }) async {
    _log.info('Updating chat encryption protocol to ${protocol.name}...');
    await chatsAccessor.updateOne(ChatsCompanion(
      jid: Value(chatJid),
      encryptionProtocol: Value(protocol),
    ));
  }

  @override
  Future<void> removeChat(String jid) {
    return chatsAccessor.deleteOne(jid);
  }

  @override
  Stream<List<RosterItem>> watchRoster({required int start, required int end}) {
    return rosterAccessor.watchAll();
  }

  @override
  Future<List<RosterItem>> getRoster() async {
    _log.info('Loading roster from database...');
    return await rosterAccessor.selectAll();
  }

  @override
  Future<RosterItem?> getRosterItem(String jid) async {
    return rosterAccessor.selectOne(jid);
  }

  @override
  Future<void> saveRosterItem(RosterItem item) async {
    _log.info('Adding ${item.jid} to roster...');
    await transaction(() async {
      await createChat(Chat.fromJid(item.jid));
      await rosterAccessor.insertOrUpdateOne(item);
      await invitesAccessor.deleteOne(item.jid);
    });
  }

  @override
  Future<void> saveRosterItems(List<RosterItem> items) async {
    await transaction(() async {
      for (final item in items) {
        _log.info('Adding ${item.jid} to roster...');
        await createChat(Chat.fromJid(item.jid));
        await rosterAccessor.insertOrUpdateOne(item);
        await invitesAccessor.deleteOne(item.jid);
      }
    });
  }

  @override
  Future<void> updateRosterItem(RosterItem item) async {
    _log.info('Updating ${item.jid} in roster...');
    await transaction(() async {
      await rosterAccessor.updateOne(item);
      await invitesAccessor.deleteOne(item.jid);
    });
  }

  @override
  Future<void> updateRosterItems(List<RosterItem> items) async {
    await transaction(() async {
      for (final item in items) {
        _log.info('Updating ${item.jid} in roster...');
        await rosterAccessor.updateOne(item);
        await invitesAccessor.deleteOne(item.jid);
      }
    });
  }

  @override
  Future<void> removeRosterItem(String jid) async {
    _log.info('Removing $jid from roster...');
    await transaction(() async {
      await rosterAccessor.deleteOne(jid);
      await chatsAccessor.deleteOne(jid);
    });
  }

  @override
  Future<void> removeRosterItems(List<String> jids) async {
    await transaction(() async {
      for (final jid in jids) {
        _log.info('Removing $jid from roster...');
        await rosterAccessor.deleteOne(jid);
        await chatsAccessor.deleteOne(jid);
      }
    });
  }

  @override
  Future<void> updatePresence({
    required String jid,
    required Presence presence,
    String? status,
  }) async {
    _log.info('Saving ${jid.toString()} presence: $presence '
        'and status: $status...');
    await rosterAccessor.updateOne(RosterCompanion(
      jid: Value(jid),
      presence: Value(presence),
      status: Value(status),
    ));
  }

  @override
  Future<void> markSubscriptionBoth(String jid) async {
    _log.info('Marking $jid as subscription: both...');
    await transaction(() async {
      await rosterAccessor.updateOne(RosterCompanion(
        jid: Value(jid),
        subscription: const Value(Subscription.both),
      ));
      await invitesAccessor.deleteOne(jid);
    });
  }

  @override
  Stream<List<Invite>> watchInvites({required int start, required int end}) {
    _log.info('Loading invites from database...');
    return invitesAccessor.watchAll();
  }

  @override
  Future<List<Invite>> getInvites(
      {required int start, required int end}) async {
    return await invitesAccessor.selectAll();
  }

  @override
  Future<void> saveInvite(Invite invite) async {
    _log.info('Saving invite from ${invite.jid}...');
    await invitesAccessor.insertOne(invite);
  }

  @override
  Future<void> deleteInvite(String jid) async {
    _log.info('Deleting invite from $jid...');
    await invitesAccessor.deleteOne(jid);
  }

  @override
  Stream<List<BlocklistData>> watchBlocklist({
    required int start,
    required int end,
  }) {
    return blocklistAccessor.watchAll();
  }

  @override
  Future<List<BlocklistData>> getBlocklist({
    required int start,
    required int end,
  }) {
    return blocklistAccessor.selectAll();
  }

  @override
  Future<void> blockJid(String jid) async {
    _log.info('Adding $jid to blocklist...');
    await blocklistAccessor.insertOne(BlocklistCompanion(jid: Value(jid)));
  }

  @override
  Future<void> blockJids(List<String> jids) async {
    await transaction(() async {
      for (final jid in jids) {
        _log.info('Adding $jid to blocklist...');
        await blocklistAccessor.insertOne(BlocklistCompanion(jid: Value(jid)));
      }
    });
  }

  @override
  Future<void> unblockJid(String jid) async {
    _log.info('Removing $jid from blocklist...');
    await blocklistAccessor.deleteOne(jid);
  }

  @override
  Future<void> unblockJids(List<String> jids) async {
    await transaction(() async {
      for (final jid in jids) {
        _log.info('Removing $jid from blocklist...');
        await blocklistAccessor.deleteOne(jid);
      }
    });
  }

  @override
  Future<void> replaceBlocklist(List<String> blocks) async {
    _log.info('Replacing blocklist...');
    await transaction(() async {
      await blocklistAccessor.deleteAll();
      for (final blocked in blocks) {
        await blocklistAccessor.insertOne(BlocklistData(jid: blocked));
      }
    });
  }

  @override
  Future<void> deleteBlocklist() async {
    _log.info('Deleting blocklist...');
    await blocklistAccessor.deleteAll();
  }

  @override
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

  @override
  Future<void> close() async {
    await super.close();
    _instance = null;
  }

  @override
  Future<void> deleteFile() => _file.delete();
}

QueryExecutor _openDatabase(File file, String passphrase) {
  return LazyDatabase(() async {
    final token = RootIsolateToken.instance!;
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

Future<File> dbFileFor(String prefix) async {
  final path = (await getApplicationDocumentsDirectory()).path;
  return File(p.join(path, '$prefix.axichat.drift'));
}

typedef HashFunction = mox.HashFunction;
