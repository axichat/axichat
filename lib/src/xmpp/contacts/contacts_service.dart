// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

mixin ContactsService on XmppBase, BaseStreamService, RosterService {
  Stream<List<ContactDirectoryEntry>> contactsStream() {
    return rosterStream(start: 0, end: 0)
        .combineLatest(_savedEmailContactsStream(), (
          rosterItems,
          emailContacts,
        ) {
          return _ContactDirectorySources(
            rosterItems: rosterItems,
            emailContacts: emailContacts,
          );
        })
        .combineLatest(
          _contactsChatsStream(),
          (sources, chats) => _mergeContactDirectoryEntries(
            sources.rosterItems,
            sources.emailContacts,
            chats,
          ),
        );
  }

  Future<List<ContactDirectoryEntry>> loadContactsSnapshot() async {
    final roster = await loadRosterSnapshot();
    final emailContacts = await _dbOpReturning<XmppDatabase, List<Contact>>(
      (db) => db.getSavedEmailContacts(),
    );
    final chats = await _dbOpReturning<XmppDatabase, List<Chat>>(
      (db) => db.getChats(start: 0, end: 0),
    );
    return _mergeContactDirectoryEntries(roster, emailContacts, chats);
  }

  Stream<List<Contact>> _savedEmailContactsStream() {
    return createPaginatedStream<Contact, XmppDatabase>(
      watchFunction: (db) async => db.watchSavedEmailContacts(),
      getFunction: (db) => db.getSavedEmailContacts(),
    );
  }

  Stream<List<Chat>> _contactsChatsStream() {
    return createPaginatedStream<Chat, XmppDatabase>(
      watchFunction: (db) async => db.watchChats(start: 0, end: 0),
      getFunction: (db) => db.getChats(start: 0, end: 0),
    );
  }
}

List<ContactDirectoryEntry> _mergeContactDirectoryEntries(
  List<RosterItem> rosterItems,
  List<Contact> emailContacts,
  List<Chat> chats,
) {
  final rosterByAddress = <String, RosterItem>{};
  for (final item in rosterItems) {
    final key = contactDirectoryAddressKey(item.jid);
    if (key.isEmpty) {
      continue;
    }
    rosterByAddress[key] = item;
  }

  final emailByAddress = <String, _EmailContactAggregate>{};
  for (final contact in emailContacts) {
    final resolvedAddress = contact.resolvedAddress;
    final key = contactDirectoryAddressKey(resolvedAddress);
    if (key.isEmpty || resolvedAddress == null || resolvedAddress.isEmpty) {
      continue;
    }
    final aggregate = emailByAddress.putIfAbsent(
      key,
      () => _EmailContactAggregate(address: resolvedAddress),
    );
    final nativeId = contact.nativeID?.trim();
    if (nativeId != null &&
        nativeId.isNotEmpty &&
        !aggregate.nativeIds.contains(nativeId)) {
      aggregate.nativeIds.add(nativeId);
    }
    final displayName = contact.providedDisplayName?.trim();
    if (displayName != null &&
        displayName.isNotEmpty &&
        aggregate.displayName == null) {
      aggregate.displayName = displayName;
    }
  }

  final avatarPathsByAddress = <String, String>{};
  for (final chat in chats) {
    if (chat.type != ChatType.chat) {
      continue;
    }
    final avatarPath = _preferredContactAvatarPath(chat);
    if (avatarPath == null) {
      continue;
    }
    for (final candidate in <String?>[
      chat.jid,
      chat.emailAddress,
      chat.remoteJid,
    ]) {
      final key = contactDirectoryAddressKey(candidate);
      if (key.isEmpty || avatarPathsByAddress.containsKey(key)) {
        continue;
      }
      avatarPathsByAddress[key] = avatarPath;
    }
  }

  final addresses = <String>{
    ...rosterByAddress.keys,
    ...emailByAddress.keys,
  }.toList(growable: false)..sort();

  final items = <ContactDirectoryEntry>[];
  for (final address in addresses) {
    final roster = rosterByAddress[address];
    final email = emailByAddress[address];
    items.add(
      ContactDirectoryEntry(
        address: address,
        hasXmppRoster: roster != null,
        hasEmailContact: email != null,
        emailNativeIds: List<String>.unmodifiable(
          email?.nativeIds ?? const <String>[],
        ),
        xmppTitle: roster == null ? null : _contactDisplayName(roster),
        emailDisplayName: email?.displayName,
        avatarPath:
            _trimmedContactValue(roster?.avatarPath) ??
            avatarPathsByAddress[address],
        subscription: roster?.subscription,
      ),
    );
  }
  items.sort((a, b) {
    final aKey = a.displayName.toLowerCase();
    final bKey = b.displayName.toLowerCase();
    final byName = aKey.compareTo(bKey);
    if (byName != 0) {
      return byName;
    }
    return a.address.compareTo(b.address);
  });
  return List<ContactDirectoryEntry>.unmodifiable(items);
}

String? _contactDisplayName(RosterItem item) {
  final title = item.contactDisplayName?.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }
  final fallback = item.title.trim();
  if (fallback.isEmpty) {
    return null;
  }
  return fallback;
}

class _EmailContactAggregate {
  _EmailContactAggregate({required this.address});

  final String address;
  final List<String> nativeIds = <String>[];
  String? displayName;
}

class _ContactDirectorySources {
  const _ContactDirectorySources({
    required this.rosterItems,
    required this.emailContacts,
  });

  final List<RosterItem> rosterItems;
  final List<Contact> emailContacts;
}

String? _preferredContactAvatarPath(Chat chat) {
  return _trimmedContactValue(chat.avatarPath) ??
      _trimmedContactValue(chat.contactAvatarPath);
}

String? _trimmedContactValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
