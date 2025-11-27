import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
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
        return Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ShadSelect<AppLanguage>(
              initialValue: language,
              onChanged: (value) {
                if (value == null) return;
                context.read<SettingsCubit>().updateLanguage(value);
              },
              options: AppLanguage.values
                  .map(
                    (entry) => ShadOption<AppLanguage>(
                      value: entry,
                      child: _LanguageLabel(
                        language: entry,
                        style: labelStyle,
                      ),
                    ),
                  )
                  .toList(),
              selectedOptionBuilder: (context, value) => _LanguageLabel(
                language: value,
                style: labelStyle,
              ),
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
  });

  final AppLanguage language;
  final LanguageLabelStyle style;

  @override
  Widget build(BuildContext context) {
    final text = style == LanguageLabelStyle.compact
        ? language.abbreviation
        : language.label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(language.flag),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
