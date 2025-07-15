import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/change_password_form.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/connectivity/view/connectivity_indicator.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/view/profile_card.dart';
import 'package:axichat/src/profile/view/profile_fingerprint.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/settings/view/settings_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum _ProfileRoute {
  main,
  changePassword,
  delete,
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.locate});

  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
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
          BlocProvider.value(
            value: locate<AuthenticationCubit>(),
          ),
        ],
        child: const _ProfileBody(),
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
  String? _applicationVersion;

  var _profileRoute = _ProfileRoute.main;

  @override
  void initState() {
    super.initState();
    _getApplicationVersion();
  }

  Future<void> _getApplicationVersion() async {
    final result = (await PackageInfo.fromPlatform()).version;
    setState(() {
      _applicationVersion = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            leading: ShadIconButton.ghost(
              icon: const Icon(
                LucideIcons.arrowLeft,
                size: 20.0,
              ),
              onPressed: () => _profileRoute == _ProfileRoute.main
                  ? context.pop()
                  : setState(() {
                      _profileRoute = _ProfileRoute.main;
                    }),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: IndexedStack(
                index: _profileRoute.index,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const ConnectivityIndicator(),
                      const ShorebirdChecker(),
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: ProfileCard(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShadButton.secondary(
                            child: const Text('Change password'),
                            onPressed: () => setState(() {
                              _profileRoute = _ProfileRoute.changePassword;
                            }),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: ProfileFingerprint(),
                      ),
                      const SizedBox(height: 8),
                      const SettingsControls(showDivider: true),
                      AboutListTile(
                        icon: const Icon(LucideIcons.info),
                        applicationName: appDisplayName,
                        applicationVersion: _applicationVersion,
                        applicationLegalese: 'Copyright (C) 2025 Eliot Lew\n\n'
                            'This program is free software: you can redistribute it and/or modify '
                            'it under the terms of the GNU Affero General Public License as '
                            'published by the Free Software Foundation, either version 3 of the '
                            'License, or (at your option) any later version.\n\n'
                            'This program is distributed in the hope that it will be useful, '
                            'but WITHOUT ANY WARRANTY; without even the implied warranty of '
                            'MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the '
                            'GNU Affero General Public License for more details.\n\n'
                            'You should have received a copy of the GNU Affero General Public License '
                            'along with this program. If not, see <https://www.gnu.org/licenses/>.',
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: ChangePasswordForm(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
