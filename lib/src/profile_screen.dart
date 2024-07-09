import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:chat/src/profile/view/profile_card.dart';
import 'package:chat/src/settings/view/settings_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
        child: BlocProvider.value(
          value: locate<ProfileCubit>(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return const NarrowLayout(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(12.0),
                      child: ProfileCard(),
                    ),
                    SizedBox(height: 8),
                    SettingsControls(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
