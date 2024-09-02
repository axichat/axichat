import 'package:chat/src/common/capability.dart';
import 'package:chat/src/notifications/view/notification_request.dart';
import 'package:chat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SettingsControls extends StatelessWidget {
  const SettingsControls({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return ListView(
          shrinkWrap: true,
          children: [
            if (context.read<Capability>().canForegroundService)
              const NotificationRequest(),
            ListTile(
              title: const Text('Theme Mode'),
              trailing: ShadSelect<ThemeMode>(
                initialValue: state.themeMode,
                onChanged: (themeMode) =>
                    context.read<SettingsCubit>().updateThemeMode(themeMode),
                options: ThemeMode.values
                    .map((themeMode) => ShadOption<ThemeMode>(
                          value: themeMode,
                          child: Text(themeMode.name),
                        ))
                    .toList(),
                selectedOptionBuilder:
                    (BuildContext context, ThemeMode value) => Text(value.name),
              ),
            ),
            ListTile(
              title: const Text('Color Scheme'),
              trailing: ShadSelect<ShadColor>(
                anchor: const ShadAnchorAuto(preferBelow: false),
                initialValue: state.shadColor,
                onChanged: (colorScheme) => context
                    .read<SettingsCubit>()
                    .updateColorScheme(colorScheme),
                options: ShadColor.values
                    .map((colorScheme) => ShadOption<ShadColor>(
                          value: colorScheme,
                          child: Text(colorScheme.name),
                        ))
                    .toList(),
                selectedOptionBuilder:
                    (BuildContext context, ShadColor value) => Text(value.name),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: const Text('Low motion'),
                sublabel: const Text(
                    'Disables most animations. Better for slow devices.'),
                value: state.lowMotion,
                onChanged: (lowMotion) =>
                    context.read<SettingsCubit>().toggleLowMotion(lowMotion),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: const Text('Send typing indicators'),
                sublabel: const Text(
                    'Let other people in a chat see when you are typing.'),
                value: state.indicateTyping,
                onChanged: (indicateTyping) => context
                    .read<SettingsCubit>()
                    .toggleIndicateTyping(indicateTyping),
              ),
            ),
          ],
        );
      },
    );
  }
}
