import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:chat/src/profile/view/profile_card.dart';
import 'package:chat/src/settings/view/settings_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.locate});

  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(
              value: locate<ProfileCubit>(),
            ),
            BlocProvider.value(
              value: locate<ConnectivityCubit>(),
            ),
          ],
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: ProfileCard(),
                ),
                // const Padding(
                //   padding: EdgeInsets.all(12.0),
                //   child: ProfileFingerprint(),
                // ),
                ShadButton.ghost(
                  onPressed: () {
                    showAboutDialog(
                      context: context,
                      applicationName: appDisplayName,
                    );
                  },
                  text: const Text('Legal'),
                ),
                const SizedBox(height: 8),
                const SettingsControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
