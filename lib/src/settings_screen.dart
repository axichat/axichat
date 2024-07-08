import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/profile/view/profile_card.dart';
import 'package:chat/src/settings/view/settings_controls.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return const NarrowLayout(
              child: Column(
                children: [
                  ProfileCard(),
                  SettingsControls(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
