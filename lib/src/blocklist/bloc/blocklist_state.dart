// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'blocklist_cubit.dart';

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

extension BlocklistNoticeL10n on BlocklistNotice {
  String resolve(AppLocalizations l10n) => switch (type) {
        BlocklistNoticeType.invalidJid => l10n.blocklistInvalidJid,
        BlocklistNoticeType.blockFailed =>
          l10n.blocklistBlockFailed(address ?? ''),
        BlocklistNoticeType.unblockFailed =>
          l10n.blocklistUnblockFailed(address ?? ''),
        BlocklistNoticeType.blocked => l10n.blocklistBlocked(address ?? ''),
        BlocklistNoticeType.unblocked => l10n.blocklistUnblocked(address ?? ''),
        BlocklistNoticeType.blockUnsupported =>
          l10n.blocklistBlockingUnsupported,
        BlocklistNoticeType.unblockUnsupported =>
          l10n.blocklistUnblockingUnsupported,
        BlocklistNoticeType.unblockAllFailed => l10n.blocklistUnblockAllFailed,
        BlocklistNoticeType.unblockAllSuccess =>
          l10n.blocklistUnblockAllSuccess,
      };
}

final class BlocklistAvailable extends BlocklistState {
  const BlocklistAvailable({
    required super.items,
    required super.visibleItems,
  });
}

final class BlocklistLoading extends BlocklistState {
  const BlocklistLoading({
    required this.jid,
    super.items,
    super.visibleItems,
  });

  final String? jid;

  @override
  List<Object?> get props => [items, visibleItems, jid];
}

final class BlocklistSuccess extends BlocklistState {
  const BlocklistSuccess(
    this.notice, {
    super.items,
    super.visibleItems,
  });

  final BlocklistNotice notice;

  @override
  List<Object?> get props => [items, visibleItems, notice];
}

final class BlocklistFailure extends BlocklistState {
  const BlocklistFailure(
    this.notice, {
    super.items,
    super.visibleItems,
  });

  final BlocklistNotice notice;

  @override
  List<Object?> get props => [items, visibleItems, notice];
}
