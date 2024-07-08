import 'package:chat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsControls extends StatelessWidget {
  const SettingsControls({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Theme Mode'),
              trailing: DropdownButton<ThemeMode>(
                value: state.themeMode,
                onChanged: (themeMode) =>
                    context.read<SettingsCubit>().updateTheme(themeMode),
                items: ThemeMode.values
                    .map((themeMode) => DropdownMenuItem<ThemeMode>(
                          value: themeMode,
                          child: Text(themeMode.name),
                        ))
                    .toList(),
              ),
            ),
            SwitchListTile(
              title: const Text('Low Motion'),
              subtitle: const Text(
                  'Disables most animations. Better for slow devices.'),
              value: state.lowMotion,
              onChanged: (lowMotion) =>
                  context.read<SettingsCubit>().toggleLowMotion(lowMotion),
            ),
          ],
        );
      },
    );
  }
}
