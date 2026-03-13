// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/change_password_form.dart';
import 'package:axichat/src/authentication/view/unregister_form.dart';
import 'package:axichat/src/common/capability.dart';
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
import 'package:axichat/src/update/view/update_prompt.dart';
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

const Curve _profileFadeCurve = Curves.easeInOutCubic;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    final endpointConfig = locate<SettingsCubit>().state.endpointConfig;
    final emailEnabled = endpointConfig.smtpEnabled;
    final EmailService? emailService = emailEnabled
        ? locate<EmailService>()
        : null;
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
  final ScrollController _profileScrollController = ScrollController();
  final ScrollController _settingsScrollController = ScrollController();
  final ValueNotifier<double> _settingsScrollOffset = ValueNotifier<double>(0);
  final SettingsSectionAnchors _settingsAnchors = SettingsSectionAnchors(
    importantKey: GlobalKey(),
    accountKey: GlobalKey(),
    dataKey: GlobalKey(),
    appearanceKey: GlobalKey(),
    securityKey: GlobalKey(),
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
    _settingsScrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, connectivityState) {
        final l10n = context.l10n;
        final colors = context.colorScheme;
        final spacing = context.spacing;
        final sizing = context.sizing;
        final demoOffline = context.read<XmppService>().demoOfflineMode;
        final profileSidebarColor = colors.background;
        final showingProfileSubpage = _profileRoute != _ProfileRoute.main;
        return PopScope(
          canPop: !showingProfileSubpage,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || !showingProfileSubpage) {
              return;
            }
            _setRoute(_ProfileRoute.main);
          },
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              leadingWidth: showingProfileSubpage
                  ? sizing.iconButtonTapTarget + spacing.m
                  : null,
              leading: showingProfileSubpage
                  ? Padding(
                      padding: EdgeInsets.only(left: spacing.m),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: sizing.iconButtonSize,
                          height: sizing.iconButtonSize,
                          child: AxiIconButton.ghost(
                            iconData: LucideIcons.arrowLeft,
                            tooltip: l10n.commonBack,
                            onPressed: () => _setRoute(_ProfileRoute.main),
                          ),
                        ),
                      ),
                    )
                  : null,
              title: Text(l10n.profileTitle),
              centerTitle: false,
              backgroundColor: profileSidebarColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              shape: Border(bottom: context.borderSide),
              actions: [
                if (kEnableDemoChats && demoOffline)
                  Padding(
                    padding: EdgeInsets.only(right: spacing.m),
                    child: AxiIconButton.ghost(
                      iconData: LucideIcons.refreshCcw,
                      tooltip: l10n.commonRetry,
                      onPressed: () async => await context
                          .read<XmppService>()
                          .resetDemoInteractivePhase(),
                    ),
                  ),
              ],
            ),
            body: Column(
              children: [
                MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: const ConnectivityIndicator(),
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final profileWideLayoutMinWidth =
                            sizing.profileWideSidebarMaxWidth +
                            sizing.profileWideSettingsMinWidth +
                            spacing.m +
                            (spacing.l * 2);
                        final isWideLayout =
                            constraints.maxWidth >= profileWideLayoutMinWidth;
                        final Duration animationDuration = context
                            .watch<SettingsCubit>()
                            .animationDuration;
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
                              settingsScrollController:
                                  _settingsScrollController,
                              profileScrollController: _profileScrollController,
                              settingsScrollOffset: _settingsScrollOffset,
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
                ),
              ],
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
    required this.settingsScrollOffset,
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
  final ValueNotifier<double> settingsScrollOffset;
  final T Function<T>() locate;
  final ValueChanged<_ProfileRoute> onNavigate;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    final emailEnabled = context
        .watch<SettingsCubit>()
        .state
        .endpointConfig
        .smtpEnabled;
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
    final showImportantSection = context.select<SettingsCubit, bool>(
      (cubit) => cubit.canForegroundService,
    );
    if (!isWideLayout) {
      final profileSectionPadding = EdgeInsets.symmetric(
        horizontal: spacing.s,
        vertical: spacing.s,
      );
      return SingleChildScrollView(
        controller: profileScrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: sidebarColor,
              child: Padding(
                padding: profileSectionPadding,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: sizing.profileCompactMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _ProfileStatusHeader(),
                        SizedBox(height: spacing.s),
                        card,
                        SizedBox(height: spacing.s),
                        const ProfileFingerprint(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing.s),
            settings,
          ],
        ),
      );
    }
    final sidebarPadding = EdgeInsets.symmetric(
      horizontal: spacing.l,
      vertical: spacing.m,
    );
    final jumpMenuPadding = EdgeInsetsDirectional.only(
      start: spacing.l,
      end: spacing.l,
      top: spacing.m,
      bottom: spacing.m,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: sizing.profileWideSidebarMaxWidth,
            minWidth: sizing.profileWideSidebarMinWidth,
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
                      SizedBox(height: spacing.m),
                      card,
                      SizedBox(height: spacing.s),
                      const ProfileFingerprint(),
                      SizedBox(height: spacing.s),
                    ],
                  ),
                ),
                ShadSeparator.horizontal(
                  thickness: context.borderSide.width,
                  color: context.colorScheme.border,
                ),
                Padding(
                  padding: jumpMenuPadding,
                  child: _SettingsJumpMenu(
                    anchors: settingsAnchors,
                    showImportantSection: showImportantSection,
                    emailEnabled: emailEnabled,
                    scrollController: settingsScrollController,
                    scrollOffsetListenable: settingsScrollOffset,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: context.borderSide.width,
          color: context.colorScheme.border,
        ),
        SizedBox(width: spacing.m),
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
              padding: EdgeInsets.only(right: spacing.l, top: spacing.m),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: sizing.profileWideSettingsMinWidth,
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
        final hideLogoutButton = context.select<AuthenticationCubit, bool>(
          (cubit) => cubit.passwordWasSkipped,
        );
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
            final spacing = context.spacing;
            final sizing = context.sizing;
            final headerSpacing = spacing.m;
            final bool wideCard =
                isWideLayout &&
                constraints.maxWidth >= sizing.composeWindowMinWidth;
            final double statusFieldMaxWidth = wideCard
                ? sizing.profileHeaderWideMaxWidth
                : sizing.profileHeaderCompactMaxWidth;
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
                      loading: profileState.avatarHydrating,
                      jid: profileState.jid,
                      onTap: () => context.push(
                        const AvatarEditorRoute().location,
                        extra: locate,
                      ),
                    ),
                    SizedBox(width: headerSpacing),
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
                          SizedBox(height: spacing.xs),
                          SelectionArea(
                            child: AxiTooltip(
                              builder: (_) => ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: sizing.menuMaxWidth,
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
                          ),
                        ],
                      ),
                    ),
                    if (!hideLogoutButton) ...[
                      SizedBox(width: headerSpacing),
                      const LogoutButton(),
                    ],
                  ],
                ),
              ),
            );
            final Widget profileCard = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing.s,
              children: [
                header,
                SizedBox(height: spacing.s),
                Align(
                  alignment: Alignment.center,
                  child: SessionCapabilityIndicators(
                    xmppState: connectionState,
                    emailState: _emailStateFor(
                      connectivityState,
                      demoOffline: demoOffline,
                    ),
                    emailEnabled: demoOffline
                        ? true
                        : connectivityState.emailEnabled,
                    compact: !wideCard,
                  ),
                ),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing.s,
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
  Widget build(BuildContext context) => const UpdateStatusBanner();
}

class _EditableAvatarButton extends StatefulWidget {
  const _EditableAvatarButton({
    required this.avatarPath,
    required this.loading,
    required this.jid,
    required this.onTap,
  });

  final String? avatarPath;
  final bool loading;
  final String jid;
  final VoidCallback onTap;

  @override
  State<_EditableAvatarButton> createState() => _EditableAvatarButtonState();
}

class _EditableAvatarButtonState extends State<_EditableAvatarButton> {
  bool _hovered = false;
  final AxiTapBounceController _bounceController = AxiTapBounceController();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final motion = context.motion;
    final sizing = context.sizing;
    final spacing = context.spacing;
    final Duration animationDuration = context.select<SettingsCubit, Duration>(
      (cubit) => cubit.animationDuration,
    );
    final overlayVisible = _hovered;
    final avatarSize = sizing.iconButtonTapTarget + spacing.s;
    final overlayTint = colors.background.withValues(
      alpha: motion.tapFocusAlpha + motion.tapHoverAlpha,
    );
    final Duration pressDuration = Duration(
      milliseconds:
          (animationDuration.inMilliseconds *
                  motion.iconButtonPressDurationFactor)
              .round(),
    );
    final Duration releaseDuration = Duration(
      milliseconds:
          (animationDuration.inMilliseconds *
                  motion.iconButtonReleaseDurationFactor)
              .round(),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (details) {
          _bounceController.handleTapDown(details);
          setState(() => _hovered = true);
        },
        onTapUp: (details) {
          _bounceController.handleTapUp(details);
          setState(() => _hovered = false);
        },
        onTapCancel: () {
          _bounceController.handleTapCancel();
          setState(() => _hovered = false);
        },
        onTap: widget.onTap,
        child: AxiTapBounce(
          controller: _bounceController,
          enabled: animationDuration != Duration.zero,
          scale: motion.iconButtonBounceScale,
          hoverScale: motion.iconButtonHoverScale,
          pressDuration: pressDuration,
          releaseDuration: releaseDuration,
          child: Hero(
            tag: 'avatar',
            child: Stack(
              alignment: Alignment.center,
              children: [
                AxiAvatar(
                  jid: widget.jid,
                  subscription: Subscription.both,
                  presence: null,
                  status: null,
                  active: false,
                  size: avatarSize,
                  avatarPath: widget.avatarPath,
                  loading: widget.loading,
                ),
                AnimatedSwitcher(
                  duration: animationDuration,
                  switchInCurve: _profileFadeCurve,
                  switchOutCurve: _profileFadeCurve,
                  child: overlayVisible
                      ? Container(
                          key: const ValueKey('profile_avatar_overlay'),
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            color: overlayTint,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.border),
                          ),
                          child: Icon(
                            LucideIcons.pencil,
                            color: colors.foreground,
                            size: sizing.iconButtonIconSize,
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('profile_avatar_overlay_hidden'),
                        ),
                ),
              ],
            ),
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
          fullWidthDividers: true,
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
    required this.showImportantSection,
    required this.emailEnabled,
    required this.scrollController,
    required this.scrollOffsetListenable,
    required this.textAlign,
  });

  final SettingsSectionAnchors anchors;
  final bool showImportantSection;
  final bool emailEnabled;
  final ScrollController scrollController;
  final ValueListenable<double> scrollOffsetListenable;
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
        oldWidget.showImportantSection != widget.showImportantSection ||
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
    final Duration animationDuration = context
        .watch<SettingsCubit>()
        .animationDuration;
    final sectionKeys = <GlobalKey?>[
      if (widget.showImportantSection) widget.anchors.importantKey,
      widget.anchors.accountKey,
      widget.anchors.dataKey,
      widget.anchors.appearanceKey,
      widget.anchors.securityKey,
      widget.anchors.chatPreferencesKey,
      if (widget.emailEnabled) widget.anchors.emailPreferencesKey,
      widget.anchors.aboutKey,
    ];
    final sectionLabels = <String>[
      if (widget.showImportantSection) context.l10n.settingsSectionImportant,
      context.l10n.settingsSectionAccount,
      context.l10n.settingsSectionData,
      context.l10n.settingsSectionAppearance,
      context.l10n.settingsSectionSecurity,
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
              spacing: context.spacing.xs,
              children: [
                for (final entry in sectionLabels.indexed)
                  _SettingsJumpLink(
                    label: entry.$2,
                    onTap: () async =>
                        await _jumpTo(sectionKeys[entry.$1], animationDuration),
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

  Future<void> _jumpTo(GlobalKey? anchor, Duration animationDuration) async {
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
        if (widget.showImportantSection) widget.anchors.importantKey,
        widget.anchors.accountKey,
        widget.anchors.dataKey,
        widget.anchors.appearanceKey,
        widget.anchors.securityKey,
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
      final RenderAbstractViewport viewport = RenderAbstractViewport.of(
        renderObject,
      );
      final double revealOffset = viewport
          .getOffsetToReveal(renderObject, 0.0)
          .offset;
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
    final double currentOffset = scrollOffset.clamp(0, double.infinity);
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
    final spacing = context.spacing;
    final sizing = context.sizing;
    final MainAxisAlignment alignment = switch (textAlign) {
      TextAlign.right => MainAxisAlignment.end,
      TextAlign.center => MainAxisAlignment.center,
      _ => MainAxisAlignment.start,
    };
    final jumpColor = colors.foreground.withValues(alpha: 0.7);
    const double selectedOpacity = 0.45;
    final Color selectedBackground = colors.secondary.withValues(
      alpha: selectedOpacity,
    );
    return ShadButton.ghost(
      height: sizing.listButtonHeight,
      padding: EdgeInsets.symmetric(horizontal: spacing.m, vertical: spacing.s),
      mainAxisAlignment: alignment,
      foregroundColor: jumpColor,
      hoverForegroundColor: jumpColor,
      textStyle: context.textTheme.small.copyWith(color: jumpColor),
      backgroundColor: selected ? selectedBackground : null,
      hoverBackgroundColor: selected ? selectedBackground : null,
      onPressed: onTap,
      child: Text(label, textAlign: textAlign),
    ).withTapBounce();
  }
}

class _ProfileFormPage extends StatelessWidget {
  const _ProfileFormPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final spacing = context.spacing;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: sizing.composeWindowExpandedWidth,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(spacing.m),
          child: child,
        ),
      ),
    );
  }
}
