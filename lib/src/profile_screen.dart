// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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
import 'package:axichat/src/localization/localization_extensions.dart';
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

const double _profileActionSpacing = 8.0;
const double _profileHeaderSpacing = 12.0;
const double _profileCardSectionSpacing = 10.0;
const double _profileStatusFieldPadding = 8.0;
const Curve _profileFadeCurve = Curves.easeInOutCubic;

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

  ConnectionState _xmppStateFor(
    ConnectivityState state, {
    required bool demoOffline,
  }) {
    if (demoOffline) return ConnectionState.connected;
    return switch (state) {
      ConnectivityConnected() => ConnectionState.connected,
      ConnectivityConnecting() => ConnectionState.connecting,
      ConnectivityError() => ConnectionState.error,
      ConnectivityNotConnected() => ConnectionState.notConnected,
    };
  }

  void _setRoute(_ProfileRoute route) {
    setState(() {
      _profileRoute = route;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) {
        final l10n = context.l10n;
        final demoOffline =
            context.read<XmppService?>()?.demoOfflineMode ?? false;
        final ConnectionState connectionState =
            _xmppStateFor(state, demoOffline: demoOffline);
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.profileTitle),
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
                  child: AxiIconButton.ghost(
                    iconData: LucideIcons.arrowLeft,
                    tooltip: l10n.commonBack,
                    onPressed: () => _profileRoute == _ProfileRoute.main
                        ? context.pop()
                        : _setRoute(_ProfileRoute.main),
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
                final Duration animationDuration =
                    context.watch<SettingsCubit>().animationDuration;
                return AxiFadeIndexedStack(
                  index: _profileRoute.index,
                  duration: animationDuration,
                  curve: _profileFadeCurve,
                  children: [
                    _ProfileMainView(
                      isWideLayout: isWideLayout,
                      connectionState: connectionState,
                      demoOffline: demoOffline,
                      applicationVersion: _applicationVersion,
                      locate: widget.locate,
                      onNavigate: _setRoute,
                    ),
                    const _ProfileFormPage(child: ChangePasswordForm()),
                    const _ProfileFormPage(child: UnregisterForm()),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ProfileMainView extends StatelessWidget {
  const _ProfileMainView({
    required this.isWideLayout,
    required this.connectionState,
    required this.demoOffline,
    required this.applicationVersion,
    required this.locate,
    required this.onNavigate,
  });

  final bool isWideLayout;
  final ConnectionState connectionState;
  final bool demoOffline;
  final String? applicationVersion;
  final T Function<T>() locate;
  final ValueChanged<_ProfileRoute> onNavigate;

  @override
  Widget build(BuildContext context) {
    final card = _ProfileCardSection(
      connectionState: connectionState,
      demoOffline: demoOffline,
      isWideLayout: isWideLayout,
      locate: locate,
      onNavigate: onNavigate,
    );
    final settings = _SettingsPanel(
      showTopDivider: !isWideLayout,
      applicationVersion: applicationVersion,
    );
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
                card,
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: ProfileFingerprint(),
                ),
                const SizedBox(height: 8),
                settings,
              ],
            ),
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 460,
            minWidth: 340,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ConnectivityIndicator(),
              const SizedBox(height: 8),
              const ShorebirdChecker(),
              card,
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
            child: settings,
          ),
        ),
      ],
    );
  }
}

class _ProfileCardSection extends StatelessWidget {
  const _ProfileCardSection({
    required this.connectionState,
    required this.demoOffline,
    required this.isWideLayout,
    required this.locate,
    required this.onNavigate,
  });

  final ConnectionState connectionState;
  final bool demoOffline;
  final bool isWideLayout;
  final T Function<T>() locate;
  final ValueChanged<_ProfileRoute> onNavigate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
          return LayoutBuilder(
            builder: (context, constraints) {
              final bool wideCard =
                  isWideLayout && constraints.maxWidth >= 360.0;
              final double statusFieldMaxWidth = wideCard ? 420.0 : 320.0;
              final actions = <AxiMenuAction>[
                AxiMenuAction(
                  label: l10n.profileEditAvatar,
                  icon: LucideIcons.image,
                  onPressed: () => context.push(
                    const AvatarEditorRoute().location,
                    extra: locate,
                  ),
                ),
                AxiMenuAction(
                  label: l10n.profileArchives,
                  icon: LucideIcons.archive,
                  onPressed: () => context.push(
                    const ArchivesRoute().location,
                    extra: locate,
                  ),
                ),
                AxiMenuAction(
                  label: l10n.draftAttachmentsLabel,
                  icon: LucideIcons.paperclip,
                  onPressed: () => context.push(
                    const AttachmentGalleryRoute().location,
                    extra: locate,
                  ),
                ),
                AxiMenuAction(
                  label: l10n.profileLinkedEmailAccounts,
                  icon: LucideIcons.mail,
                  onPressed: () => context.push(
                    const LinkedEmailAccountsRoute().location,
                    extra: locate,
                  ),
                ),
                AxiMenuAction(
                  label: l10n.profileChangePassword,
                  icon: LucideIcons.keyRound,
                  onPressed: () => onNavigate(_ProfileRoute.changePassword),
                ),
                AxiMenuAction(
                  label: l10n.profileDeleteAccount,
                  icon: LucideIcons.trash2,
                  destructive: true,
                  onPressed: () => onNavigate(_ProfileRoute.delete),
                ),
              ];
              final attachmentButton = AxiIconButton(
                iconData: LucideIcons.image,
                tooltip: l10n.draftAttachmentsLabel,
                onPressed: () => context.push(
                  const AttachmentGalleryRoute().location,
                  extra: locate,
                ),
              );
              final actionButtons = Wrap(
                alignment: WrapAlignment.center,
                spacing: _profileActionSpacing,
                runSpacing: _profileActionSpacing,
                children: [
                  const LogoutButton(),
                  attachmentButton,
                  AxiMore(actions: actions),
                ],
              );
              final header = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: _profileHeaderSpacing,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: _EditableAvatarButton(
                      avatarPath: profileState.avatarPath,
                      jid: profileState.jid,
                      status: profileState.status,
                      onTap: () => context.push(
                        const AvatarEditorRoute().location,
                        extra: locate,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: SelectionArea(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 0,
                                runSpacing: 2,
                                children: [
                                  AxiTooltip(
                                    builder: (_) => ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 300.0,
                                      ),
                                      child: Text(
                                        l10n.profileJidDescription,
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
                                        constraints: const BoxConstraints(
                                          maxWidth: 300.0,
                                        ),
                                        child: Text(
                                          l10n.profileResourceDescription,
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
                    ],
                  ),
                ],
              );
              return ShadCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: _profileCardSectionSpacing,
                  children: [
                    header,
                    Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: statusFieldMaxWidth),
                        child: Padding(
                          padding: const EdgeInsets.all(
                            _profileStatusFieldPadding,
                          ),
                          child: AxiTextFormField(
                            placeholder: Text(l10n.profileStatusPlaceholder),
                            initialValue: profileState.status,
                            onSubmitted: (value) => context
                                .read<ProfileCubit?>()
                                ?.updatePresence(status: value),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: BlocBuilder<EmailSyncCubit, EmailSyncState>(
                        builder: (context, emailSyncState) {
                          final displayedEmailState = demoOffline
                              ? const EmailSyncState.ready()
                              : emailSyncState;
                          return SessionCapabilityIndicators(
                            xmppState: connectionState,
                            emailState: displayedEmailState,
                            emailEnabled: true,
                            compact: !wideCard,
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: actionButtons,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EditableAvatarButton extends StatefulWidget {
  const _EditableAvatarButton({
    required this.avatarPath,
    required this.jid,
    required this.status,
    required this.onTap,
  });

  final String? avatarPath;
  final String jid;
  final String? status;
  final VoidCallback onTap;

  @override
  State<_EditableAvatarButton> createState() => _EditableAvatarButtonState();
}

class _EditableAvatarButtonState extends State<_EditableAvatarButton> {
  bool _hovered = false;
  static const _size = 74.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final overlayVisible = _hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hovered = true),
        onTapUp: (_) => setState(() => _hovered = false),
        onTapCancel: () => setState(() => _hovered = false),
        onTap: widget.onTap,
        child: Hero(
          tag: 'avatar',
          child: Stack(
            alignment: Alignment.center,
            children: [
              AxiAvatar(
                jid: widget.jid,
                subscription: Subscription.both,
                presence: null,
                status: widget.status,
                active: false,
                size: _size,
                avatarPath: widget.avatarPath,
              ),
              AnimatedOpacity(
                opacity: overlayVisible ? 0.9 : 0.0,
                duration: baseAnimationDuration,
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    color: colors.background.withAlpha((0.4 * 255).round()),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(
                    LucideIcons.pencil,
                    color: colors.foreground,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.showTopDivider,
    required this.applicationVersion,
  });

  final bool showTopDivider;
  final String? applicationVersion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsControls(
          showDivider: showTopDivider,
          showAppearanceDivider: showTopDivider,
        ),
        ListTileTheme(
          data: const ListTileThemeData(
            dense: true,
            minVerticalPadding: 0,
            contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
            visualDensity: VisualDensity(horizontal: 0, vertical: -2),
          ),
          child: AboutListTile(
            icon: const Icon(LucideIcons.info),
            applicationName: appDisplayName,
            applicationVersion: applicationVersion,
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
        ),
      ],
    );
  }
}

class _ProfileFormPage extends StatelessWidget {
  const _ProfileFormPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
