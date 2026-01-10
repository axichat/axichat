// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:moxxmpp/moxxmpp.dart' as mox;

extension PubSubErrorMissingNode on mox.PubSubError {
  bool get indicatesMissingNode =>
      this is mox.ItemNotFoundError ||
      this is mox.UnknownPubSubError ||
      this is mox.MalformedResponseError;
}
