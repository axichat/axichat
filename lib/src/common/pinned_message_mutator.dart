// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/models.dart';

abstract interface class PinnedMessageMutator {
  Future<void> pinMessage({required String chatJid, required Message message});

  Future<void> unpinMessage({
    required String chatJid,
    required Message message,
  });
}
