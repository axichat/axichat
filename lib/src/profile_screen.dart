import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/change_password_form.dart';
import 'package:axichat/src/authentication/view/unregister_form.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/connectivity/view/connectivity_indicator.dart';
import 'package:axichat/src/email/bloc/email_sync_cubit.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/view/profile_fingerprint.dart';
import 'package:axichat/src/profile/view/session_capability_indicators.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/settings/view/settings_controls.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart' hide ConnectionState;
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
            value: locate<EmailSyncCubit>(),
          ),
          BlocProvider.value(
            value: locate<SettingsCubit>(),
          ),
          BlocProvider.value(
            value: locate<AuthenticationCubit>(),
          ),
        ],
        child: _ProfileBody(locate: locate),
      ),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.locate});

  final T Function<T>() locate;

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

  ConnectionState _xmppStateFor(ConnectivityState state) => switch (state) {
        ConnectivityConnected() => ConnectionState.connected,
        ConnectivityConnecting() => ConnectionState.connecting,
        ConnectivityError() => ConnectionState.error,
        ConnectivityNotConnected() => ConnectionState.notConnected,
      };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) {
        final ConnectionState connectionState = _xmppStateFor(state);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            backgroundColor: context.colorScheme.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leadingWidth: AxiIconButton.kDefaultSize + 24,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: AxiIconButton.kDefaultSize,
                  height: AxiIconButton.kDefaultSize,
                  child: AxiIconButton(
                    iconData: LucideIcons.arrowLeft,
                    tooltip: 'Back',
                    color: context.colorScheme.foreground,
                    borderColor: context.colorScheme.border,
                    onPressed: () => _profileRoute == _ProfileRoute.main
                        ? context.pop()
                        : setState(() {
                            _profileRoute = _ProfileRoute.main;
                          }),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                thickness: 1,
                color: context.colorScheme.border,
              ),
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWideLayout = constraints.maxWidth >= largeScreen;
                return IndexedStack(
                  index: _profileRoute.index,
                  children: [
                    _buildMainContent(
                      context: context,
                      isWideLayout: isWideLayout,
                      connectionState: connectionState,
                    ),
                    _buildFormPage(const ChangePasswordForm()),
                    _buildFormPage(const UnregisterForm()),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent({
    required BuildContext context,
    required bool isWideLayout,
    required ConnectionState connectionState,
  }) {
    final profileCard = _buildProfileCard(connectionState);
    final settingsContent = _buildSettingsContent();
    if (!isWideLayout) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const ConnectivityIndicator(),
                const ShorebirdChecker(),
                profileCard,
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: ProfileFingerprint(),
                ),
                const SizedBox(height: 8),
                settingsContent,
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420,
              minWidth: 340,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ConnectivityIndicator(),
                const SizedBox(height: 8),
                const ShorebirdChecker(),
                profileCard,
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: ProfileFingerprint(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: settingsContent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(ConnectionState connectionState) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, profileState) {
          final usernameStyle = context.textTheme.large.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colorScheme.foreground,
          );
          final subtitleStyle = context.textTheme.muted.copyWith(
            color: context.colorScheme.mutedForeground,
          );
          return ShadCard(
            rowMainAxisSize: MainAxisSize.max,
            columnCrossAxisAlignment: CrossAxisAlignment.center,
            leading: Hero(
              tag: 'avatar',
              child: AxiAvatar(
                jid: profileState.jid,
                subscription: Subscription.both,
                // Presence is ingested for MUC features
                // but we hide presence UI for contacts.
                presence: null,
                status: null,
                active: false,
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'title',
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      profileState.username,
                      style: usernameStyle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            description: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SelectionArea(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 0,
                      runSpacing: 2,
                      children: [
                        AxiTooltip(
                          builder: (_) => ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300.0),
                            child: const Text(
                              'This is your Jabber ID. Comprised of your '
                              'username and domain, it\'s a unique address '
                              'that represents you on the XMPP network.',
                              textAlign: TextAlign.left,
                            ),
                          ),
                          child: Hero(
                            tag: 'subtitle',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                profileState.jid,
                                style: subtitleStyle,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        if (profileState.resource.isNotEmpty)
                          AxiTooltip(
                            builder: (_) => ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 300.0),
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
                              style: subtitleStyle,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            trailing: const LogoutButton(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 8.0,
              children: [
                BlocBuilder<EmailSyncCubit, EmailSyncState>(
                  builder: (context, emailSyncState) {
                    return SizedBox(
                      width: double.infinity,
                      child: Center(
                        child: SessionCapabilityIndicators(
                          xmppState: connectionState,
                          emailState: emailSyncState,
                          emailEnabled: true,
                        ),
                      ),
                    );
                  },
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300.0),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: AxiTextFormField(
                      placeholder: const Text('Status message'),
                      initialValue: profileState.status,
                      onSubmitted: (value) => context
                          .read<ProfileCubit?>()
                          ?.updatePresence(status: value),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ShadButton.outline(
                      size: ShadButtonSize.sm,
                      child: const Text('View archives'),
                      onPressed: () => context.push(
                        const ArchivesRoute().location,
                        extra: widget.locate,
                      ),
                    ).withTapBounce(),
                    ShadButton.outline(
                      size: ShadButtonSize.sm,
                      child: const Text('Change password'),
                      onPressed: () => setState(() {
                        _profileRoute = _ProfileRoute.changePassword;
                      }),
                    ).withTapBounce(),
                    ShadButton.destructive(
                      size: ShadButtonSize.sm,
                      child: const Text('Delete account'),
                      onPressed: () => setState(() {
                        _profileRoute = _ProfileRoute.delete;
                      }),
                    ).withTapBounce(),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
    );
  }

  Widget _buildFormPage(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720.0),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    );
  }
}
