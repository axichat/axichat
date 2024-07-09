import 'package:chat/src/app.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/roster/bloc/roster_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RosterInvitesList extends StatelessWidget {
  const RosterInvitesList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RosterBloc, RosterState>(
      builder: (context, state) {
        final invites = state.invites;
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
              final disabled =
                  state is RosterLoading && state.jid == invite.jid;
              return ShadCard(
                leading: AxiAvatar(jid: invite.jid),
                title: Text(invite.title),
                description: Text(invite.jid),
                trailing: OverflowBar(
                  spacing: 4.0,
                  overflowSpacing: 4.0,
                  overflowAlignment: OverflowBarAlignment.center,
                  children: [
                    TextButton(
                      onPressed: disabled
                          ? null
                          : () => context.read<RosterBloc>().add(
                              RosterSubscriptionAdded(
                                  jid: invite.jid, title: invite.title)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                      child: const Text('Connect'),
                    ),
                    TextButton(
                      onPressed: disabled
                          ? null
                          : () => context
                              .read<RosterBloc>()
                              .add(RosterSubscriptionRejected(item: invite)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              );
            },
            childCount: invites.length,
          ),
        );
      },
    );
  }
}
