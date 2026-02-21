// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/localization/app_localizations.dart';

extension BlocklistNoticeLocalization on BlocklistNotice {
  String resolve(AppLocalizations l10n) => switch (type) {
    BlocklistNoticeType.invalidJid => l10n.blocklistInvalidJid,
    BlocklistNoticeType.blockFailed => l10n.blocklistBlockFailed(address ?? ''),
    BlocklistNoticeType.unblockFailed => l10n.blocklistUnblockFailed(
      address ?? '',
    ),
    BlocklistNoticeType.blocked => l10n.blocklistBlocked(address ?? ''),
    BlocklistNoticeType.unblocked => l10n.blocklistUnblocked(address ?? ''),
    BlocklistNoticeType.blockUnsupported => l10n.blocklistBlockingUnsupported,
    BlocklistNoticeType.unblockUnsupported =>
      l10n.blocklistUnblockingUnsupported,
    BlocklistNoticeType.unblockAllFailed => l10n.blocklistUnblockAllFailed,
    BlocklistNoticeType.unblockAllSuccess => l10n.blocklistUnblockAllSuccess,
  };
}
