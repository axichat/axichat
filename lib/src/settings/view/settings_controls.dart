import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SettingsControls extends StatelessWidget {
  const SettingsControls({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (context.read<Capability>().canForegroundService)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: NotificationRequest(
                  notificationService: context.read<NotificationService>(),
                ),
              ),
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
                label: const Text('Mute notifications'),
                sublabel: const Text('Stop receiving message notifications.'),
                value: state.mute,
                onChanged: (mute) =>
                    context.read<SettingsCubit>().toggleMute(mute),
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
