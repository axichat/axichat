import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/connectivity/view/connectivity_indicator.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/view/profile_card.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/settings/view/settings_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
              BlocProvider.value(
                value: locate<SettingsCubit>(),
              ),
            ],
            child: const SingleChildScrollView(
              child: _ProfileBody(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody();

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const ConnectivityIndicator(),
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: ProfileCard(),
            ),
            // const Padding(
            //   padding: EdgeInsets.all(12.0),
            //   child: ProfileFingerprint(),
            // ),
            const ShorebirdChecker(),
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
        );
      },
    );
  }
}
