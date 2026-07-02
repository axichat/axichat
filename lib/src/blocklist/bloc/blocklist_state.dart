// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'blocklist_cubit.dart';

class BlocklistEntry {
  const BlocklistEntry({
    required this.address,
    required this.blockedAt,
    required this.transport,
  });

  final String address;
  final DateTime blockedAt;
  final MessageTransport transport;

  bool get isEmail => transport.isEmail;

  bool get isXmpp => transport.isXmpp;

  bool matchesAddress(String? address) {
    return BlocklistOperation(
      type: BlocklistOperationType.block,
      address: this.address,
      transport: transport,
    ).matches(address: address, transport: transport);
  }
}

class BlocklistAddressEntry {
  const BlocklistAddressEntry({
    required this.address,
    required this.blockedAt,
    required this.entries,
  });

  final String address;
  final DateTime blockedAt;
  final List<BlocklistEntry> entries;

  bool get hasEmail => entries.any((entry) => entry.isEmail);

  bool get hasXmpp => entries.any((entry) => entry.isXmpp);

  bool matchesAddress(String? address) {
    return entries.any((entry) => entry.matchesAddress(address));
  }
}

final class BlocklistTarget extends Equatable {
  const BlocklistTarget({required this.address, required this.transport});

  final String address;
  final MessageTransport transport;

  bool matches({String? address, MessageTransport? transport}) {
    if (transport != null && this.transport != transport) {
      return false;
    }
    return _normalizedBlocklistOperationAddress(address, this.transport) ==
        _normalizedBlocklistOperationAddress(this.address, this.transport);
  }

  @override
  List<Object?> get props => [address, transport];
}

enum BlocklistOperationType {
  block,
  blockMany,
  blockContact,
  unblock,
  unblockContact,
  unblockAll,
}

final class BlocklistOperation extends Equatable {
  const BlocklistOperation({
    required this.type,
    this.address,
    this.transport,
    this.targets = const <BlocklistTarget>[],
  });

  const BlocklistOperation.block({
    required String address,
    required MessageTransport transport,
  }) : this(
         type: BlocklistOperationType.block,
         address: address,
         transport: transport,
       );

  const BlocklistOperation.blockMany({required List<BlocklistTarget> targets})
    : this(type: BlocklistOperationType.blockMany, targets: targets);

  const BlocklistOperation.blockContact({required String address})
    : this(type: BlocklistOperationType.blockContact, address: address);

  const BlocklistOperation.unblock({
    required String address,
    required MessageTransport transport,
  }) : this(
         type: BlocklistOperationType.unblock,
         address: address,
         transport: transport,
       );

  const BlocklistOperation.unblockContact({required String address})
    : this(type: BlocklistOperationType.unblockContact, address: address);

  const BlocklistOperation.unblockAll()
    : this(type: BlocklistOperationType.unblockAll);

  final BlocklistOperationType type;
  final String? address;
  final MessageTransport? transport;
  final List<BlocklistTarget> targets;

  bool get isBlock =>
      type == BlocklistOperationType.block ||
      type == BlocklistOperationType.blockMany ||
      type == BlocklistOperationType.blockContact;

  bool get isUnblock =>
      type == BlocklistOperationType.unblock ||
      type == BlocklistOperationType.unblockContact ||
      type == BlocklistOperationType.unblockAll;

  bool get isUnblockAll => type == BlocklistOperationType.unblockAll;

  bool matches({
    String? address,
    MessageTransport? transport,
    BlocklistOperationType? type,
  }) {
    if (type != null && this.type != type) {
      return false;
    }
    if (isUnblockAll) {
      return true;
    }
    if (targets.isNotEmpty) {
      return targets.any(
        (target) => target.matches(address: address, transport: transport),
      );
    }
    final operationTransport = this.transport;
    if (operationTransport != null &&
        transport != null &&
        operationTransport != transport) {
      return false;
    }
    final operationAddress = _normalizedBlocklistOperationAddress(
      this.address,
      operationTransport ?? transport,
    );
    final targetAddress = _normalizedBlocklistOperationAddress(
      address,
      transport ?? operationTransport,
    );
    if (operationAddress == null ||
        targetAddress == null ||
        operationAddress != targetAddress) {
      return false;
    }
    return true;
  }

  @override
  List<Object?> get props => [type, address, transport, targets];
}

String? _normalizedBlocklistOperationAddress(
  String? address,
  MessageTransport? transport,
) {
  if (transport?.isEmail == true) {
    return normalizedAddressValue(address);
  }
  if (transport?.isXmpp == true) {
    return normalizedAddressKey(address);
  }
  return normalizedAddressKey(address) ?? normalizedAddressValue(address);
}

sealed class BlocklistState extends Equatable {
  const BlocklistState({this.items, this.visibleItems});

  final List<BlocklistEntry>? items;
  final List<BlocklistEntry>? visibleItems;

  List<BlocklistAddressEntry>? get visibleAddressItems {
    final entries = visibleItems;
    if (entries == null) {
      return null;
    }
    return groupBlocklistEntries(entries);
  }

  @override
  List<Object?> get props => [items, visibleItems];
}

List<BlocklistAddressEntry> groupBlocklistEntries(
  Iterable<BlocklistEntry> entries,
) {
  final groups = <String, List<BlocklistEntry>>{};
  final displayAddresses = <String, String>{};
  for (final entry in entries) {
    final key =
        normalizedAddressKey(entry.address) ??
        normalizedAddressValue(entry.address) ??
        entry.address.trim().toLowerCase();
    if (key.isEmpty) {
      continue;
    }
    groups.putIfAbsent(key, () => <BlocklistEntry>[]).add(entry);
    displayAddresses.putIfAbsent(key, () => entry.address);
  }
  final grouped = <BlocklistAddressEntry>[
    for (final item in groups.entries)
      BlocklistAddressEntry(
        address: displayAddresses[item.key] ?? item.key,
        blockedAt: item.value
            .map((entry) => entry.blockedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b),
        entries: List<BlocklistEntry>.unmodifiable(item.value),
      ),
  ];
  return grouped;
}

List<BlocklistEntry> blocklistEntriesForAddress({
  required String address,
  required Iterable<BlocklistEntry> entries,
}) {
  return entries
      .where((entry) => entry.matchesAddress(address))
      .toList(growable: false);
}

BlocklistEntry? blocklistEntryForChat({
  required Chat chat,
  required Iterable<BlocklistEntry> entries,
}) {
  if (chat.type != ChatType.chat) {
    return null;
  }
  if (chat.defaultTransport.isEmail) {
    final normalizedCandidate = normalizedAddressValue(
      chat.antiAbuseTargetAddress,
    );
    if (normalizedCandidate == null || normalizedCandidate.isEmpty) {
      return null;
    }
    for (final entry in entries) {
      if (entry.transport.isEmail &&
          normalizedAddressValue(entry.address) == normalizedCandidate) {
        return entry;
      }
    }
    return null;
  }
  final chatBareJid = normalizedAddressKey(chat.remoteJid);
  if (chatBareJid == null || chatBareJid.isEmpty) {
    return null;
  }
  for (final entry in entries) {
    if (entry.transport.isXmpp &&
        normalizedAddressKey(entry.address) == chatBareJid) {
      return entry;
    }
  }
  return null;
}

enum BlocklistNoticeType {
  invalidJid,
  blockFailed,
  blockMultipleFailed,
  unblockFailed,
  blocked,
  blockedMultiple,
  unblocked,
  blockUnsupported,
  unblockUnsupported,
  unblockAllFailed,
  unblockAllSuccess,
}

final class BlocklistNotice extends Equatable {
  const BlocklistNotice(this.type, {this.address, this.count});

  final BlocklistNoticeType type;
  final String? address;
  final int? count;

  @override
  List<Object?> get props => [type, address, count];
}

final class BlocklistAvailable extends BlocklistState {
  const BlocklistAvailable({required super.items, required super.visibleItems});
}

final class BlocklistLoading extends BlocklistState {
  const BlocklistLoading({
    required this.operation,
    super.items,
    super.visibleItems,
  });

  final BlocklistOperation operation;

  String? get jid => operation.address;

  @override
  List<Object?> get props => [items, visibleItems, operation];
}

final class BlocklistSuccess extends BlocklistState {
  const BlocklistSuccess(
    this.notice, {
    this.operation,
    super.items,
    super.visibleItems,
  });

  final BlocklistNotice notice;
  final BlocklistOperation? operation;

  @override
  List<Object?> get props => [items, visibleItems, notice, operation];
}

final class BlocklistFailure extends BlocklistState {
  const BlocklistFailure(
    this.notice, {
    this.operation,
    super.items,
    super.visibleItems,
  });

  final BlocklistNotice notice;
  final BlocklistOperation? operation;

  @override
  List<Object?> get props => [items, visibleItems, notice, operation];
}
