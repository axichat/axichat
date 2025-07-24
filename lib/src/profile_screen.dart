import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/change_password_form.dart';
import 'package:axichat/src/authentication/view/unregister_form.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/connectivity/view/connectivity_indicator.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/view/profile_fingerprint.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/settings/view/settings_controls.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'authentication/view/logout_button.dart';

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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500.0),
                child: SingleChildScrollView(
                  child: IndexedStack(
                    index: _profileRoute.index,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const ConnectivityIndicator(),
                          const ShorebirdChecker(),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: BlocBuilder<ProfileCubit, ProfileState>(
                              builder: (context, profileState) => ShadCard(
                                rowMainAxisSize: MainAxisSize.max,
                                columnCrossAxisAlignment:
                                    CrossAxisAlignment.center,
                                leading: Hero(
                                  tag: 'avatar',
                                  child: AxiAvatar(
                                    jid: profileState.jid,
                                    subscription: Subscription.both,
                                    presence: profileState.presence,
                                    status: profileState.status,
                                    active: true,
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Hero(
                                      tag: 'title',
                                      child: Text(profileState.username),
                                    ),
                                  ],
                                ),
                                description: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            WidgetSpan(
                                              child: AxiTooltip(
                                                builder: (_) => ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                          maxWidth: 300.0),
                                                  child: const Text(
                                                    'This is your Jabber ID. Comprised of your '
                                                    'username and domain, it\'s a unique address '
                                                    'that represents you on the XMPP network.',
                                                    textAlign: TextAlign.left,
                                                  ),
                                                ),
                                                child: Hero(
                                                  tag: 'subtitle',
                                                  child: SelectableText(
                                                    profileState.jid,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (profileState
                                                .resource.isNotEmpty)
                                              WidgetSpan(
                                                child: AxiTooltip(
                                                  builder: (_) =>
                                                      ConstrainedBox(
                                                    constraints:
                                                        const BoxConstraints(
                                                            maxWidth: 300.0),
                                                    child: const Text(
                                                      'This is your XMPP resource. Every device '
                                                      'you use has a different one, which is why '
                                                      'your phone can have a different presence '
                                                      'to your desktop.',
                                                      textAlign: TextAlign.left,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '/${profileState.resource}',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const LogoutButton(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 8.0,
                                  children: [
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 300.0),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: AxiTextFormField(
                                          placeholder:
                                              const Text('Status message'),
                                          initialValue: profileState.status,
                                          onSubmitted: (value) => context
                                              .read<ProfileCubit?>()
                                              ?.updatePresence(status: value),
                                        ),
                                      ),
                                    ),
                                    OverflowBar(
                                      overflowAlignment:
                                          OverflowBarAlignment.center,
                                      spacing: 8.0,
                                      overflowSpacing: 8.0,
                                      children: [
                                        ShadButton.secondary(
                                          child: const Text('Change password'),
                                          onPressed: () => setState(() {
                                            _profileRoute =
                                                _ProfileRoute.changePassword;
                                          }),
                                        ),
                                        ShadButton.secondary(
                                          child: Text(
                                            'Delete account',
                                            style: TextStyle(
                                                color: context
                                                    .colorScheme.destructive),
                                          ),
                                          onPressed: () => setState(() {
                                            _profileRoute =
                                                _ProfileRoute.delete;
                                          }),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
                            applicationLegalese:
                                'Copyright (C) 2025 Eliot Lew\n\n'
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
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: UnregisterForm(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
