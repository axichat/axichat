// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

extension LocalizationX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
