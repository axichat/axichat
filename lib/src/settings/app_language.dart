// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';

enum AppLanguage {
  system,
  english,
  german,
  spanish,
  french,
  chineseSimplified,
  chineseHongKong,
}

extension AppLanguageX on AppLanguage {
  Locale? get locale => switch (this) {
        AppLanguage.system => null,
        AppLanguage.english => const Locale('en'),
        AppLanguage.german => const Locale('de'),
        AppLanguage.spanish => const Locale('es'),
        AppLanguage.french => const Locale('fr'),
        AppLanguage.chineseSimplified => const Locale('zh'),
        AppLanguage.chineseHongKong => const Locale('zh', 'HK'),
      };

  String label(AppLocalizations l10n) => switch (this) {
        AppLanguage.system => l10n.languageSystem,
        AppLanguage.english => l10n.languageEnglish,
        AppLanguage.german => l10n.languageGerman,
        AppLanguage.spanish => l10n.languageSpanish,
        AppLanguage.french => l10n.languageFrench,
        AppLanguage.chineseSimplified => l10n.languageChineseSimplified,
        AppLanguage.chineseHongKong => l10n.languageChineseHongKong,
      };

  String abbreviation(AppLocalizations l10n) => switch (this) {
        AppLanguage.system => l10n.languageSystemShort,
        AppLanguage.english => l10n.languageEnglishShort,
        AppLanguage.german => l10n.languageGermanShort,
        AppLanguage.spanish => l10n.languageSpanishShort,
        AppLanguage.french => l10n.languageFrenchShort,
        AppLanguage.chineseSimplified => l10n.languageChineseSimplifiedShort,
        AppLanguage.chineseHongKong => l10n.languageChineseHongKongShort,
      };

  String flag(AppLocalizations l10n) => switch (this) {
        AppLanguage.system => l10n.languageSystemFlag,
        AppLanguage.english => l10n.languageEnglishFlag,
        AppLanguage.german => l10n.languageGermanFlag,
        AppLanguage.spanish => l10n.languageSpanishFlag,
        AppLanguage.french => l10n.languageFrenchFlag,
        AppLanguage.chineseSimplified => l10n.languageChineseSimplifiedFlag,
        AppLanguage.chineseHongKong => l10n.languageChineseHongKongFlag,
      };
}
