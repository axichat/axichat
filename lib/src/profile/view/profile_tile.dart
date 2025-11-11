import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ProfileTile extends StatelessWidget {
  const ProfileTile({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.read<ProfileCubit?>() == null) {
      return const SizedBox();
    }
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final usernameStyle = context.textTheme.large.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colorScheme.foreground,
        );
        final subtitleStyle = context.textTheme.muted.copyWith(
          color: context.colorScheme.mutedForeground,
        );
        return ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
          child: ListTile(
            leading: Hero(
              tag: 'avatar',
              child: AxiAvatar(
                jid: state.jid,
                subscription: Subscription.both,
                presence: state.presence,
                status: state.status,
                active: true,
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
                ),
              ),
            ),
            onTap: () => context.push(
              const ProfileRoute().location,
              extra: context.read,
            ),
            shape: Border(
              top: BorderSide(color: context.colorScheme.border),
            ),
            trailing: AxiIconButton(
              iconData: LucideIcons.bug,
              onPressed: () => context.push(
                const ComposeRoute().location,
                extra: {
                  'locate': context.read,
                  'jids': ['feedback@axi.im'],
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
