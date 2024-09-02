import 'package:chat/src/app.dart';
import 'package:chat/src/blocklist/view/block_button_inline.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/roster/bloc/roster_cubit.dart';
import 'package:chat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RosterInvitesList extends StatelessWidget {
  const RosterInvitesList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RosterCubit, RosterState>(
      buildWhen: (_, current) => current is RosterInvitesAvailable,
      builder: (context, state) {
        late List<Invite> invites;
        if (state is! RosterInvitesAvailable) {
          invites = context.read<RosterCubit>()['invites'];
        } else {
          invites = state.invites;
        }
        if (invites.isEmpty) {
          return Center(
            child: Text(
              'No invites yet',
              style: context.textTheme.muted,
            ),
          );
        }
        return ListView.separated(
          separatorBuilder: (_, __) => const AxiListDivider(),
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final invite = invites[index];
            return BlocSelector<RosterCubit, RosterState, bool>(
              selector: (state) =>
                  state is RosterLoading && state.jid == invite.jid,
              builder: (context, disabled) {
                return AxiListTile(
                  key: Key(invite.jid),
                  onDismissed: disabled
                      ? null
                      : (_) => context
                          .read<RosterCubit>()
                          .rejectContact(jid: invite.jid),
                  dismissText: 'Reject invite from ${invite.jid}?',
                  leading: AxiAvatar(jid: invite.jid),
                  title: invite.title,
                  subtitle: invite.jid,
                  actions: [
                    AxiMore(
                      options: [
                        (toggle) => ShadButton.ghost(
                              width: double.infinity,
                              onPressed: disabled
                                  ? null
                                  : () {
                                      context.read<RosterCubit>().addContact(
                                          jid: invite.jid, title: invite.title);
                                      toggle();
                                    },
                              text: const Text('Add contact'),
                            ),
                        (toggle) => BlockButtonInline(
                              jid: invite.jid,
                              callback: toggle,
                            ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
