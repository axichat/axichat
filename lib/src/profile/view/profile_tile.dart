// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/email/bloc/email_sync_cubit.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/view/session_capability_indicators.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
        return BlocBuilder<EmailSyncCubit, EmailSyncState>(
          builder: (context, emailSyncState) {
            final sessionEmailState =
                demoOffline ? const EmailSyncState.ready() : emailSyncState;
            return BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, state) {
                final colors = context.colorScheme;
                final sizing = context.sizing;
                final usernameStyle = context.textTheme.large.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.foreground,
                );
                final subtitleStyle = context.textTheme.muted.copyWith(
                  color: colors.mutedForeground,
                );
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final indicatorMaxWidth =
                        constraints.maxWidth < sizing.menuMaxWidth
                            ? constraints.maxWidth
                            : sizing.menuMaxWidth;
                    return ListTile(
                      tileColor: colors.background,
                      leading: Hero(
                        tag: 'avatar',
                        child: AxiAvatar(
                          jid: state.jid,
                          subscription: Subscription.both,
                          avatarPath: state.avatarPath,
                          // Presence is parsed for backend features but hidden in UI.
                          presence: null,
                          status: null,
                          active: false,
                        ),
                      ),
                      title: Hero(
                        tag: 'title',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            state.username,
                            style: usernameStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      subtitle: Hero(
                        tag: 'subtitle',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            state.jid,
                            style: subtitleStyle,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                      onTap: () => context.push(
                        const ProfileRoute().location,
                        extra: context.read,
                      ),
                      trailing: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: indicatorMaxWidth,
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SessionCapabilityIndicators(
                            xmppState: connectionState,
                            emailState: sessionEmailState,
                            emailEnabled: true,
                            compact: true,
                          ),
                        ),
                      ),
                    );
                  },
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
