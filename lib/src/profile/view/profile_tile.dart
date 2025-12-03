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

const double _sessionIndicatorMaxWidth = 220.0;

class ProfileTile extends StatelessWidget {
  const ProfileTile({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.read<ProfileCubit?>() == null) {
      return const SizedBox();
    }
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, connectivityState) {
        final connectionState = _xmppStateFor(connectivityState);
        return BlocBuilder<EmailSyncCubit, EmailSyncState>(
          builder: (context, emailSyncState) {
            return BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, state) {
                final colors = context.colorScheme;
                final usernameStyle = context.textTheme.large.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.foreground,
                );
                final subtitleStyle = context.textTheme.muted.copyWith(
                  color: colors.mutedForeground,
                );
                return ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width),
                  child: ListTile(
                    tileColor: colors.background,
                    leading: Hero(
                      tag: 'avatar',
                      child: AxiAvatar(
                        jid: state.jid,
                        subscription: Subscription.both,
                        // Presence is parsed for backend features but hidden in UI.
                        presence: null,
                        status: null,
                        active: false,
                      ),
                    ),
                    title: Hero(
                      tag: 'title',
                      child: Material(
                        color: Colors.transparent,
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
                        color: Colors.transparent,
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
                      constraints: const BoxConstraints(
                        maxWidth: _sessionIndicatorMaxWidth,
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SessionCapabilityIndicators(
                          xmppState: connectionState,
                          emailState: emailSyncState,
                          emailEnabled: true,
                          compact: true,
                        ),
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
  }
}

ConnectionState _xmppStateFor(ConnectivityState state) => switch (state) {
      ConnectivityConnected() => ConnectionState.connected,
      ConnectivityConnecting() => ConnectionState.connecting,
      ConnectivityError() => ConnectionState.error,
      ConnectivityNotConnected() => ConnectionState.notConnected,
    };
