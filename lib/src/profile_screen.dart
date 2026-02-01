// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/change_password_form.dart';
import 'package:axichat/src/authentication/view/unregister_form.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/connectivity/view/connectivity_indicator.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/email/bloc/email_contact_import_cubit.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/bloc/profile_export_cubit.dart';
import 'package:axichat/src/profile/view/profile_fingerprint.dart';
import 'package:axichat/src/profile/view/session_capability_indicators.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/settings/view/settings_controls.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'authentication/view/logout_button.dart';

enum _ProfileRoute { main, changePassword, delete }

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

EmailSyncState _emailStateFor(
  ConnectivityState state, {
  required bool demoOffline,
}) {
  if (demoOffline) return const EmailSyncState.ready();
  return state.emailState;
}

const double _profileHeaderSpacing = 12.0;
const double _profileHeaderTextSpacing = 4.0;
const double _profileHeaderWrapSpacing = 2.0;
const double _profileCardSectionSpacing = 10.0;
const double _profileStatusFieldPadding = 8.0;
const double _profileIndicatorSpacing = 8.0;
const double _profileWideHeaderSpacing = 12.0;
const double _profileWideHorizontalPadding = 32.0;
const double _profileWideColumnSpacing = 16.0;
const double _profileColumnMinWidth = 340.0;
const double _profileColumnMaxWidth = 460.0;
const double _profileSettingsMinWidth = 300.0;
const double _profileWideLayoutMinWidth = _profileColumnMaxWidth +
    _profileSettingsMinWidth +
    _profileWideColumnSpacing +
    _profileWideHorizontalPadding * 2;
const Curve _profileFadeCurve = Curves.easeInOutCubic;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.locate});

  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    final endpointConfig = locate<AuthenticationCubit>().endpointConfig;
    final emailEnabled = endpointConfig.enableSmtp;
    final EmailService? emailService =
        emailEnabled ? locate<EmailService>() : null;
    return RepositoryProvider.value(
      value: locate<Capability>(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: locate<ProfileCubit>()),
          BlocProvider.value(value: locate<ConnectivityCubit>()),
          if (emailEnabled && emailService != null)
            BlocProvider(
              create: (context) =>
                  EmailContactImportCubit(emailService: emailService),
            ),
          BlocProvider.value(value: locate<SettingsCubit>()),
          BlocProvider.value(value: locate<AuthenticationCubit>()),
          BlocProvider(
            create: (context) => ProfileExportCubit(
              xmppService: locate<XmppService>(),
              emailService: emailService,
            ),
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
  final GlobalKey _profileHeaderKey = GlobalKey();
  final ScrollController _profileScrollController = ScrollController();
  final ScrollController _settingsScrollController = ScrollController();
  final ValueNotifier<double> _profileScrollOffset = ValueNotifier<double>(0);
  final ValueNotifier<double> _settingsScrollOffset = ValueNotifier<double>(0);
  final SettingsSectionAnchors _settingsAnchors = SettingsSectionAnchors(
    accountKey: GlobalKey(),
    dataKey: GlobalKey(),
    appearanceKey: GlobalKey(),
    chatPreferencesKey: GlobalKey(),
    emailPreferencesKey: GlobalKey(),
    aboutKey: GlobalKey(),
  );

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

  void _setRoute(_ProfileRoute route) {
    setState(() {
      _profileRoute = route;
    });
  }

  @override
  void dispose() {
    _settingsScrollController.dispose();
    _profileScrollController.dispose();
    _profileScrollOffset.dispose();
    _settingsScrollOffset.dispose();
    super.dispose();
  }

  double _resolveSettingsBaseOffset() {
    final double headerHeight =
        _profileHeaderKey.currentContext?.size?.height ?? 0;
    return headerHeight + _profileIndicatorSpacing;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, connectivityState) {
        final l10n = context.l10n;
        final colors = context.colorScheme;
        final demoOffline = context.read<XmppService>().demoOfflineMode;
        final profileSidebarColor = colors.background;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.profileTitle),
            backgroundColor: profileSidebarColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              if (kEnableDemoChats && demoOffline)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: AxiIconButton.ghost(
                    iconData: LucideIcons.refreshCcw,
                    tooltip: l10n.commonRetry,
                    onPressed: () async => await context
                        .read<XmppService>()
                        .resetDemoInteractivePhase(),
                  ),
                ),
            ],
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
                final isWideLayout =
                    constraints.maxWidth >= _profileWideLayoutMinWidth;
                final Duration animationDuration =
                    context.watch<SettingsCubit>().animationDuration;
                return AxiFadeIndexedStack(
                  index: _profileRoute.index,
                  duration: animationDuration,
                  curve: _profileFadeCurve,
                  children: [
                    _ProfileMainView(
                      isWideLayout: isWideLayout,
                      connectivityState: connectivityState,
                      demoOffline: demoOffline,
                      applicationVersion: _applicationVersion,
                      sidebarColor: profileSidebarColor,
                      settingsAnchors: _settingsAnchors,
                      settingsScrollController: _settingsScrollController,
                      profileScrollController: _profileScrollController,
                      profileScrollOffset: _profileScrollOffset,
                      settingsScrollOffset: _settingsScrollOffset,
                      profileHeaderKey: _profileHeaderKey,
                      baseOffsetResolver: _resolveSettingsBaseOffset,
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
    required this.connectivityState,
    required this.demoOffline,
    required this.applicationVersion,
    required this.sidebarColor,
    required this.settingsAnchors,
    required this.settingsScrollController,
    required this.profileScrollController,
    required this.profileScrollOffset,
    required this.settingsScrollOffset,
    required this.profileHeaderKey,
    required this.baseOffsetResolver,
    required this.locate,
    required this.onNavigate,
  });

  final bool isWideLayout;
  final ConnectivityState connectivityState;
  final bool demoOffline;
  final String? applicationVersion;
  final Color sidebarColor;
  final SettingsSectionAnchors settingsAnchors;
  final ScrollController settingsScrollController;
  final ScrollController profileScrollController;
  final ValueNotifier<double> profileScrollOffset;
  final ValueNotifier<double> settingsScrollOffset;
  final GlobalKey profileHeaderKey;
  final double Function() baseOffsetResolver;
  final T Function<T>() locate;
  final ValueChanged<_ProfileRoute> onNavigate;

  @override
  Widget build(BuildContext context) {
    final emailEnabled =
        context.watch<AuthenticationCubit>().endpointConfig.enableSmtp;
    final card = _ProfileCardSection(
      connectivityState: connectivityState,
      demoOffline: demoOffline,
      isWideLayout: isWideLayout,
      locate: locate,
      onNavigate: onNavigate,
    );
    final settings = _SettingsPanel(
      showTopDivider: !isWideLayout,
      isWideLayout: isWideLayout,
      applicationVersion: applicationVersion,
      anchors: settingsAnchors,
      locate: locate,
      onNavigate: onNavigate,
    );
    if (!isWideLayout) {
      final Duration animationDuration =
          context.watch<SettingsCubit>().animationDuration;
      const profileSectionPadding = EdgeInsets.symmetric(
        horizontal: _profileHeaderSpacing,
        vertical: _profileHeaderSpacing,
      );
      return Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.vertical) {
                profileScrollOffset.value = notification.metrics.pixels;
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: profileScrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KeyedSubtree(
                    key: profileHeaderKey,
                    child: ColoredBox(
                      color: sidebarColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: profileSectionPadding,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 500.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const _ProfileStatusHeader(),
                                    const SizedBox(
                                      height: _profileCardSectionSpacing,
                                    ),
                                    card,
                                    const SizedBox(
                                      height: _profileCardSectionSpacing,
                                    ),
                                    const ProfileFingerprint(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: context.colorScheme.border,
                          ),
                          Padding(
                            padding: profileSectionPadding,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 500.0),
                                child: _SettingsJumpMenu(
                                  anchors: settingsAnchors,
                                  emailEnabled: emailEnabled,
                                  scrollController: profileScrollController,
                                  scrollOffsetListenable: profileScrollOffset,
                                  baseOffsetResolver: baseOffsetResolver,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: _profileIndicatorSpacing),
                  settings,
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: profileScrollController,
              builder: (context, child) {
                final double headerHeight =
                    profileHeaderKey.currentContext?.size?.height ?? 0;
                if (headerHeight == 0 ||
                    !profileScrollController.hasClients ||
                    profileScrollController.offset <= headerHeight) {
                  return const SizedBox.shrink();
                }
                return Align(
                  alignment: Alignment.bottomRight,
                  child: SafeArea(
                    minimum: const EdgeInsets.all(16),
                    child: AxiIconButton.ghost(
                      iconData: LucideIcons.arrowUp,
                      tooltip: context.l10n.profileJumpToTop,
                      onPressed: () async {
                        if (!profileScrollController.hasClients) {
                          return;
                        }
                        await profileScrollController.animateTo(
                          0,
                          duration: animationDuration,
                          curve: _profileFadeCurve,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
    const sidebarPadding = EdgeInsets.symmetric(
      horizontal: _profileWideHorizontalPadding,
      vertical: _profileWideHeaderSpacing,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: _profileColumnMaxWidth,
            minWidth: _profileColumnMinWidth,
          ),
          child: ColoredBox(
            color: sidebarColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: sidebarPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ProfileStatusHeader(),
                      const SizedBox(height: _profileWideHeaderSpacing),
                      card,
                      const SizedBox(height: _profileCardSectionSpacing),
                      const ProfileFingerprint(),
                      const SizedBox(height: _profileCardSectionSpacing),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: context.colorScheme.border,
                ),
                Padding(
                  padding: sidebarPadding,
                  child: _SettingsJumpMenu(
                    anchors: settingsAnchors,
                    emailEnabled: emailEnabled,
                    scrollController: settingsScrollController,
                    scrollOffsetListenable: settingsScrollOffset,
                    baseOffsetResolver: () => 0,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: context.colorScheme.border),
        const SizedBox(width: _profileWideColumnSpacing),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.vertical) {
                settingsScrollOffset.value = notification.metrics.pixels;
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: settingsScrollController,
              padding: const EdgeInsets.only(
                right: _profileWideHorizontalPadding,
                top: _profileWideHeaderSpacing,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: _profileSettingsMinWidth,
                ),
                child: settings,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileCardSection extends StatelessWidget {
  const _ProfileCardSection({
    required this.connectivityState,
    required this.demoOffline,
    required this.isWideLayout,
    required this.locate,
    required this.onNavigate,
  });

  final ConnectivityState connectivityState;
  final bool demoOffline;
  final bool isWideLayout;
  final T Function<T>() locate;
  final ValueChanged<_ProfileRoute> onNavigate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profileState) {
        final ConnectionState connectionState = _xmppStateFor(
          connectivityState,
          demoOffline: demoOffline,
        );
        final usernameStyle = context.textTheme.large.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colorScheme.foreground,
        );
        final subtitleStyle = context.textTheme.muted.copyWith(
          color: context.colorScheme.mutedForeground,
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final bool wideCard = isWideLayout && constraints.maxWidth >= 360.0;
            final double statusFieldMaxWidth = wideCard ? 420.0 : 320.0;
            final header = Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: statusFieldMaxWidth),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _EditableAvatarButton(
                      avatarPath: profileState.avatarPath,
                      jid: profileState.jid,
                      status: profileState.status,
                      onTap: () => context.push(
                        const AvatarEditorRoute().location,
                        extra: locate,
                      ),
                    ),
                    const SizedBox(width: _profileHeaderSpacing + 4),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(
                            tag: 'title',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                profileState.username,
                                style: usernameStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: _profileHeaderTextSpacing / 2,
                          ),
                          SelectionArea(
                            child: Wrap(
                              alignment: WrapAlignment.start,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 0,
                              runSpacing: _profileHeaderWrapSpacing / 2,
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
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
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
                        ],
                      ),
                    ),
                    const SizedBox(width: _profileHeaderSpacing),
                    const LogoutButton(),
                  ],
                ),
              ),
            );
            final Widget profileCard = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _profileCardSectionSpacing,
              children: [
                header,
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: statusFieldMaxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(
                        _profileStatusFieldPadding,
                      ),
                      child: AxiTextFormField(
                        placeholder: Text(l10n.profileStatusPlaceholder),
                        initialValue: profileState.status,
                        onSubmitted: (value) => context
                            .read<ProfileCubit>()
                            .updatePresence(status: value),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: SessionCapabilityIndicators(
                    xmppState: connectionState,
                    emailState: _emailStateFor(
                      connectivityState,
                      demoOffline: demoOffline,
                    ),
                    emailEnabled:
                        demoOffline ? true : connectivityState.emailEnabled,
                    compact: !wideCard,
                  ),
                ),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _profileCardSectionSpacing,
              children: [profileCard],
            );
          },
        );
      },
    );
  }
}

class _ProfileStatusHeader extends StatelessWidget {
  const _ProfileStatusHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConnectivityIndicator(),
        SizedBox(height: _profileIndicatorSpacing),
        ShorebirdChecker(),
      ],
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
  static const _size = 59.2;

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
    required this.isWideLayout,
    required this.applicationVersion,
    required this.anchors,
    required this.locate,
    required this.onNavigate,
  });

  final bool showTopDivider;
  final bool isWideLayout;
  final String? applicationVersion;
  final SettingsSectionAnchors anchors;
  final T Function<T>() locate;
  final ValueChanged<_ProfileRoute> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsControls(
          showDivider: showTopDivider,
          fullWidthDividers: isWideLayout,
          anchors: anchors,
          locate: locate,
          onChangePassword: () => onNavigate(_ProfileRoute.changePassword),
          onDeleteAccount: () => onNavigate(_ProfileRoute.delete),
          applicationVersion: applicationVersion,
        ),
      ],
    );
  }
}

class _SettingsJumpMenu extends StatefulWidget {
  const _SettingsJumpMenu({
    required this.anchors,
    required this.emailEnabled,
    required this.scrollController,
    required this.scrollOffsetListenable,
    required this.baseOffsetResolver,
    required this.textAlign,
  });

  final SettingsSectionAnchors anchors;
  final bool emailEnabled;
  final ScrollController scrollController;
  final ValueListenable<double> scrollOffsetListenable;
  final double Function() baseOffsetResolver;
  final TextAlign textAlign;

  @override
  State<_SettingsJumpMenu> createState() => _SettingsJumpMenuState();
}

class _SettingsJumpMenuState extends State<_SettingsJumpMenu> {
  final List<double> _sectionOffsets = [];
  final List<double> _sectionHeights = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshSectionOffsets();
  }

  @override
  void didUpdateWidget(covariant _SettingsJumpMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController ||
        oldWidget.anchors != widget.anchors ||
        oldWidget.scrollOffsetListenable != widget.scrollOffsetListenable ||
        oldWidget.emailEnabled != widget.emailEnabled) {
      _refreshSectionOffsets();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Duration animationDuration =
        context.watch<SettingsCubit>().animationDuration;
    final sectionKeys = <GlobalKey?>[
      widget.anchors.accountKey,
      widget.anchors.dataKey,
      widget.anchors.appearanceKey,
      widget.anchors.chatPreferencesKey,
      if (widget.emailEnabled) widget.anchors.emailPreferencesKey,
      widget.anchors.aboutKey,
    ];
    final sectionLabels = <String>[
      context.l10n.settingsSectionAccount,
      context.l10n.settingsSectionData,
      context.l10n.settingsSectionAppearance,
      context.l10n.settingsSectionChats,
      if (widget.emailEnabled) context.l10n.settingsSectionEmail,
      context.l10n.settingsSectionAbout,
    ];
    final Alignment menuAlignment = switch (widget.textAlign) {
      TextAlign.right => Alignment.centerRight,
      TextAlign.center => Alignment.center,
      _ => Alignment.centerLeft,
    };
    return ValueListenableBuilder<double>(
      valueListenable: widget.scrollOffsetListenable,
      builder: (context, scrollOffset, child) {
        final int selectedIndex = _resolveSelectedIndex(scrollOffset);
        return Align(
          alignment: menuAlignment,
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _profileHeaderTextSpacing,
              children: [
                for (final entry in sectionLabels.indexed)
                  _SettingsJumpLink(
                    label: entry.$2,
                    onTap: () async => await _jumpTo(
                      sectionKeys[entry.$1],
                      animationDuration,
                    ),
                    textAlign: widget.textAlign,
                    selected: selectedIndex == entry.$1,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _jumpTo(
    GlobalKey? anchor,
    Duration animationDuration,
  ) async {
    final BuildContext? targetContext = anchor?.currentContext;
    if (targetContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      targetContext,
      duration: animationDuration,
      curve: _profileFadeCurve,
    );
  }

  void _refreshSectionOffsets() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final keys = <GlobalKey?>[
        widget.anchors.accountKey,
        widget.anchors.dataKey,
        widget.anchors.appearanceKey,
        widget.anchors.chatPreferencesKey,
        if (widget.emailEnabled) widget.anchors.emailPreferencesKey,
        widget.anchors.aboutKey,
      ];
      _sectionOffsets
        ..clear()
        ..addAll(_calculateSectionMetrics(keys));
      setState(() {});
    });
  }

  List<double> _calculateSectionMetrics(List<GlobalKey?> keys) {
    final List<double> offsets = [];
    _sectionHeights.clear();
    for (final key in keys) {
      final BuildContext? context = key?.currentContext;
      if (context == null) {
        offsets.add(0);
        _sectionHeights.add(0);
        continue;
      }
      final RenderObject? renderObject = context.findRenderObject();
      if (renderObject is! RenderBox) {
        offsets.add(0);
        _sectionHeights.add(0);
        continue;
      }
      final RenderAbstractViewport viewport =
          RenderAbstractViewport.of(renderObject);
      final double revealOffset =
          viewport.getOffsetToReveal(renderObject, 0.0).offset;
      offsets.add(revealOffset);
      _sectionHeights.add(renderObject.size.height);
    }
    return offsets;
  }

  int _resolveSelectedIndex(double scrollOffset) {
    if (_sectionOffsets.isEmpty ||
        _sectionOffsets.length != _sectionHeights.length) {
      return 0;
    }
    final double baseOffset = widget.baseOffsetResolver();
    final double currentOffset =
        (scrollOffset - baseOffset).clamp(0, double.infinity);
    const double sectionThreshold = 2 / 3;
    int selectedIndex = 0;
    for (final entry in _sectionOffsets.indexed) {
      if (entry.$1 >= _sectionOffsets.length - 1) {
        break;
      }
      final double thresholdOffset =
          entry.$2 + (_sectionHeights[entry.$1] * sectionThreshold);
      if (currentOffset >= thresholdOffset) {
        selectedIndex = entry.$1 + 1;
      } else {
        break;
      }
    }
    return selectedIndex;
  }
}

class _SettingsJumpLink extends StatelessWidget {
  const _SettingsJumpLink({
    required this.label,
    required this.onTap,
    required this.textAlign,
    required this.selected,
  });

  final String label;
  final VoidCallback onTap;
  final TextAlign textAlign;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final MainAxisAlignment alignment = switch (textAlign) {
      TextAlign.right => MainAxisAlignment.end,
      TextAlign.center => MainAxisAlignment.center,
      _ => MainAxisAlignment.start,
    };
    final jumpColor = colors.foreground.withValues(alpha: 0.7);
    const double selectedOpacity = 0.45;
    final Color selectedBackground =
        colors.secondary.withValues(alpha: selectedOpacity);
    return ShadButton.ghost(
      size: ShadButtonSize.sm,
      mainAxisAlignment: alignment,
      foregroundColor: jumpColor,
      hoverForegroundColor: jumpColor,
      backgroundColor: selected ? selectedBackground : null,
      hoverBackgroundColor: selected ? selectedBackground : null,
      onPressed: onTap,
      child: DefaultTextStyle.merge(
        style: context.textTheme.small.copyWith(
          color: jumpColor,
        ),
        child: Text(
          label,
          textAlign: textAlign,
        ),
      ),
    ).withTapBounce();
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
