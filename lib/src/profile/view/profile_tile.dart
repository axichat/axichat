// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/common/ui/connection_status_indicators.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ProfileTile extends StatelessWidget {
  const ProfileTile({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, connectivityState) {
        final demoOffline = context.watch<XmppService>().demoOfflineMode;
        final connectionState = _xmppStateFor(
          connectivityState,
          demoOffline: demoOffline,
        );
        final sessionEmailState = demoOffline
            ? const EmailSyncState.ready()
            : connectivityState.emailState;
        final emailEnabled = demoOffline
            ? true
            : connectivityState.emailEnabled;
        return BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            final sizing = context.sizing;
            final baseTitleStyle = context.textTheme.h4;
            final usernameStyle = baseTitleStyle.copyWith(
              fontSize: context.textTheme.large.fontSize,
            );
            final subtitleStyle = context.textTheme.muted;
            return LayoutBuilder(
              builder: (context, constraints) {
                final indicatorMaxWidth =
                    constraints.maxWidth < sizing.menuMaxWidth
                    ? constraints.maxWidth
                    : sizing.menuMaxWidth;
                return _ProfileTileSurface(
                  onTap: () => context.push(const ProfileRoute().location),
                  child: _ProfileTileLayout(
                    username: state.username,
                    jid: state.jid,
                    usernameStyle: usernameStyle,
                    subtitleStyle: subtitleStyle,
                    indicatorMaxWidth: indicatorMaxWidth,
                    connectionState: connectionState,
                    sessionEmailState: sessionEmailState,
                    emailEnabled: emailEnabled,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
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

class _ProfileTileSurface extends StatefulWidget {
  const _ProfileTileSurface({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_ProfileTileSurface> createState() => _ProfileTileSurfaceState();
}

class _ProfileTileSurfaceState extends State<_ProfileTileSurface> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    final hoverColor = colors.card;
    final backgroundColor = colors.background;
    final surfaceColor = (_hovered || _focused) ? hoverColor : backgroundColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: context.borderSide),
      ),
      child: ShadFocusable(
        canRequestFocus: true,
        onFocusChange: (value) => setState(() => _focused = value),
        builder: (context, focused, child) => child ?? const SizedBox.shrink(),
        child: ShadGestureDetector(
          cursor: SystemMouseCursors.click,
          hoverStrategies: ShadTheme.of(context).hoverStrategies,
          onHoverChange: (value) => setState(() => _hovered = value),
          onTap: widget.onTap,
          child: AxiTapBounce(
            enabled: true,
            child: Material(
              color: Colors.transparent,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(context.radii.squircle),
              ),
              clipBehavior: Clip.antiAlias,
              child: AnimatedContainer(
                duration: animationDuration,
                color: surfaceColor,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTileLayout extends StatelessWidget {
  const _ProfileTileLayout({
    required this.username,
    required this.jid,
    required this.usernameStyle,
    required this.subtitleStyle,
    required this.indicatorMaxWidth,
    required this.connectionState,
    required this.sessionEmailState,
    required this.emailEnabled,
  });

  final String username;
  final String jid;
  final TextStyle usernameStyle;
  final TextStyle subtitleStyle;
  final double indicatorMaxWidth;
  final ConnectionState connectionState;
  final EmailSyncState sessionEmailState;
  final bool emailEnabled;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.m, vertical: spacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Hero(tag: 'avatar', child: const SelfAxiAvatar()),
          SizedBox(width: spacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'title',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      username,
                      style: usernameStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Hero(
                  tag: 'subtitle',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      jid,
                      style: subtitleStyle,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.m),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: indicatorMaxWidth),
            child: Align(
              alignment: Alignment.centerRight,
              child: ConnectionStatusIndicators(
                xmppState: connectionState,
                emailState: sessionEmailState,
                emailEnabled: emailEnabled,
                compact: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
