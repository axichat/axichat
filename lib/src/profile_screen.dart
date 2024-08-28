import 'package:chat/src/common/capability.dart';
import 'package:chat/src/common/shorebird_push.dart';
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
        child: RepositoryProvider.value(
          value: locate<Capability>(),
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
                  FutureBuilder(
                    future: checkShorebird(context.read<Capability>()),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AxiProgressIndicator(),
                              SizedBox.square(
                                dimension: 8.0,
                              ),
                              Text('Checking for updates'),
                            ],
                          ),
                        );
                      }
                      if (!snapshot.requireData) {
                        return const SizedBox.shrink();
                      }
                      return const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Text('Update available: restart required'),
                      );
                    },
                  ),
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
      ),
    );
  }
}
