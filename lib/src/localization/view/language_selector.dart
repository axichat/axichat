// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum LanguageLabelStyle { full, compact }

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    super.key,
    this.compact = false,
    this.labelStyle = LanguageLabelStyle.full,
  });

  final bool compact;
  final LanguageLabelStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsCubit, SettingsState, AppLanguage>(
      selector: (state) => state.language,
      builder: (context, language) {
        final maxWidth = compact ? 200.0 : 280.0;
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: AxiSelect<AppLanguage>(
            initialValue: language,
            shrinkWrap: true,
            onChanged: (value) {
              if (value == null) return;
              context.read<SettingsCubit>().updateLanguage(value);
            },
            options: AppLanguage.values
                .map(
                  (entry) => ShadOption<AppLanguage>(
                    value: entry,
                    child: _LanguageLabel(language: entry, style: labelStyle),
                  ),
                )
                .toList(),
            selectedOptionBuilder: (context, value) => _LanguageLabel(
              language: value,
              style: labelStyle,
              resolveSystemLanguage: true,
            ),
          ),
        );
      },
    );
  }
}

class _LanguageLabel extends StatelessWidget {
  const _LanguageLabel({
    required this.language,
    required this.style,
    this.resolveSystemLanguage = false,
  });

  final AppLanguage language;
  final LanguageLabelStyle style;
  final bool resolveSystemLanguage;

  AppLanguage _resolveCompactSystemLanguage(BuildContext context) {
    if (!resolveSystemLanguage ||
        style != LanguageLabelStyle.compact ||
        language != AppLanguage.system) {
      return language;
    }
    final locale = Localizations.maybeLocaleOf(context);
    if (locale == null) {
      return language;
    }
    for (final entry in AppLanguage.values) {
      final entryLocale = entry.locale;
      if (entryLocale == null) {
        continue;
      }
      final sameLanguage = entryLocale.languageCode == locale.languageCode;
      final sameCountry =
          (entryLocale.countryCode ?? '') == (locale.countryCode ?? '');
      if (sameLanguage && sameCountry) {
        return entry;
      }
    }
    for (final entry in AppLanguage.values) {
      final entryLocale = entry.locale;
      if (entryLocale == null) {
        continue;
      }
      if (entryLocale.languageCode == locale.languageCode) {
        return entry;
      }
    }
    return language;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final resolvedLanguage = _resolveCompactSystemLanguage(context);
    final textStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.foreground,
    );
    final bool showCompactAbbreviation =
        style == LanguageLabelStyle.compact &&
        !(resolveSystemLanguage && language == AppLanguage.system);
    final text = showCompactAbbreviation
        ? resolvedLanguage.abbreviation(l10n)
        : resolvedLanguage.label(l10n);
    return DefaultTextStyle.merge(
      style: textStyle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(resolvedLanguage.flag(l10n)),
          SizedBox(width: context.spacing.xs),
          Text(text),
        ],
      ),
    );
  }
}
