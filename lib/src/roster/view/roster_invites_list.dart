import 'package:chat/src/app.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/roster/bloc/roster_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RosterInvitesList extends StatelessWidget {
  const RosterInvitesList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RosterCubit, RosterState>(
      buildWhen: (_, current) => current is RosterInvitesAvailable,
      builder: (context, state) {
        final invites = (state as RosterInvitesAvailable).invites;
        if (invites.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text(
                'No invites yet',
                style: context.textTheme.muted,
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final invite = invites[index];
              return BlocSelector<RosterCubit, RosterState, bool>(
                selector: (state) =>
                    state is RosterLoading && state.jid == invite.jid,
                builder: (context, disabled) {
                  return AxiListTile(
                    leading: AxiAvatar(jid: invite.jid),
                    title: invite.title,
                    subtitle: invite.jid,
                    actions: [
                      TextButton(
                        onPressed: disabled
                            ? null
                            : () => context.read<RosterCubit>().addContact(
                                jid: invite.jid, title: invite.title),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                        child: const Text('Connect'),
                      ),
                      TextButton(
                        onPressed: disabled
                            ? null
                            : () => context
                                .read<RosterCubit>()
                                .rejectContact(jid: invite.jid),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Reject'),
                      ),
                    ],
                  );
                },
              );
            },
            childCount: invites.length,
          ),
        );
      },
    );
  }
}
