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
      body: const SafeArea(
        child: Column(
          children: [
            ProfileCard(),
            SettingsControls(),
          ],
        ),
      ),
    );
  }
}
