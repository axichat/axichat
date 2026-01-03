// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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

  String get label => switch (this) {
        AppLanguage.system => 'System',
        AppLanguage.english => 'English',
        AppLanguage.german => 'Deutsch',
        AppLanguage.spanish => 'Español',
        AppLanguage.french => 'Français',
        AppLanguage.chineseSimplified => '简体中文',
        AppLanguage.chineseHongKong => '繁體中文 (香港)',
      };

  String get abbreviation => switch (this) {
        AppLanguage.system => 'SYS',
        AppLanguage.english => 'EN',
        AppLanguage.german => 'DE',
        AppLanguage.spanish => 'ES',
        AppLanguage.french => 'FR',
        AppLanguage.chineseSimplified => 'ZH',
        AppLanguage.chineseHongKong => 'ZH-HK',
      };

  String get flag => switch (this) {
        AppLanguage.system => '🌐',
        AppLanguage.english => '🇬🇧',
        AppLanguage.german => '🇩🇪',
        AppLanguage.spanish => '🇪🇸',
        AppLanguage.french => '🇫🇷',
        AppLanguage.chineseSimplified => '🇨🇳',
        AppLanguage.chineseHongKong => '🇭🇰',
      };
}
