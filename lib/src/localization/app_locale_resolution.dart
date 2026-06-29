// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/widgets.dart';

const Locale appDefaultLocale = Locale('en');

Locale resolveAppLocale(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  final supported = supportedLocales.toList(growable: false);
  if (supported.isEmpty) {
    return appDefaultLocale;
  }
  final fallbackLocale = supported.firstWhere(
    (locale) => locale.languageCode == appDefaultLocale.languageCode,
    orElse: () => supported.first,
  );
  final preferred = preferredLocales ?? const <Locale>[];
  if (preferred.isEmpty) {
    return fallbackLocale;
  }

  for (final locale in preferred) {
    final match = _firstSupportedLocale(supported, locale);
    if (match != null) {
      return match;
    }
  }
  return fallbackLocale;
}

Locale? _firstSupportedLocale(List<Locale> supported, Locale preferred) {
  for (final locale in supported) {
    if (_sameLocale(locale, preferred)) {
      return locale;
    }
  }
  if (preferred.scriptCode != null) {
    for (final locale in supported) {
      if (locale.languageCode == preferred.languageCode &&
          locale.scriptCode == preferred.scriptCode) {
        return locale;
      }
    }
  }
  if (preferred.countryCode != null) {
    for (final locale in supported) {
      if (locale.languageCode == preferred.languageCode &&
          locale.countryCode == preferred.countryCode) {
        return locale;
      }
    }
  }
  for (final locale in supported) {
    if (locale.languageCode == preferred.languageCode) {
      return locale;
    }
  }
  return null;
}

bool _sameLocale(Locale left, Locale right) {
  return left.languageCode == right.languageCode &&
      left.scriptCode == right.scriptCode &&
      left.countryCode == right.countryCode;
}
