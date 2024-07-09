import 'package:chat/src/app.dart';
import 'package:chat/src/authentication/view/logout_button.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:chat/src/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, this.active = false});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        return active
            ? ListTile(
                leading: AxiAvatar(
                  jid: state.jid,
                  presence: state.presence,
                  status: state.status,
                  active: true,
                ),
                title: Text(state.title),
                subtitle: Text(state.jid),
                onTap: () => context.push(const ProfileRoute().location,
                    extra: context.read),
                tileColor: context.colorScheme.accent,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 6.0,
                  horizontal: 12.0,
                ),
                trailing: const LogoutButton(),
              )
            : ShadCard(
                rowMainAxisSize: MainAxisSize.max,
                leading: AxiAvatar(
                  jid: state.jid,
                  presence: state.presence,
                  status: state.status,
                  active: true,
                ),
                title: Text(state.title),
                description: Text(state.jid),
                trailing: const LogoutButton(),
              );
      },
    );
  }
}
