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
}

sealed class BlocklistState extends Equatable {
  const BlocklistState({this.items, this.visibleItems});

  final List<BlocklistEntry>? items;
  final List<BlocklistEntry>? visibleItems;

  @override
  List<Object?> get props => [items, visibleItems];
}

enum BlocklistNoticeType {
  invalidJid,
  blockFailed,
  unblockFailed,
  blocked,
  unblocked,
  blockUnsupported,
  unblockUnsupported,
  unblockAllFailed,
  unblockAllSuccess,
}

final class BlocklistNotice extends Equatable {
  const BlocklistNotice(this.type, {this.address});

  final BlocklistNoticeType type;
  final String? address;

  @override
  List<Object?> get props => [type, address];
}

final class BlocklistAvailable extends BlocklistState {
  const BlocklistAvailable({required super.items, required super.visibleItems});
}

final class BlocklistLoading extends BlocklistState {
  const BlocklistLoading({required this.jid, super.items, super.visibleItems});

  final String? jid;

  @override
  List<Object?> get props => [items, visibleItems, jid];
}

final class BlocklistSuccess extends BlocklistState {
  const BlocklistSuccess(this.notice, {super.items, super.visibleItems});

  final BlocklistNotice notice;

  @override
  List<Object?> get props => [items, visibleItems, notice];
}

final class BlocklistFailure extends BlocklistState {
  const BlocklistFailure(this.notice, {super.items, super.visibleItems});

  final BlocklistNotice notice;

  @override
  List<Object?> get props => [items, visibleItems, notice];
}
