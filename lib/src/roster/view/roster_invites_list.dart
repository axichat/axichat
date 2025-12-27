import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/view/block_menu_item.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/storage/models.dart';
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
        final List<Invite>? invites = (state as RosterInvitesAvailable).invites;

        if (invites == null) {
          return Center(
            child: AxiProgressIndicator(
              color: context.colorScheme.foreground,
            ),
          );
        }

        return BlocBuilder<HomeSearchCubit, HomeSearchState>(
          builder: (context, searchState) => _RosterInvitesBody(
            invites: invites,
            searchState: searchState,
          ),
        );
      },
    );
  }
}

class _RosterInvitesBody extends StatelessWidget {
  const _RosterInvitesBody({
    required this.invites,
    this.searchState,
  });

  final List<Invite> invites;
  final HomeSearchState? searchState;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tabState = searchState?.stateFor(HomeTab.invites);
    final searchActive = searchState?.active ?? false;
    final query =
        searchActive ? (tabState?.query.trim().toLowerCase() ?? '') : '';
    final sortOrder = tabState?.sort ?? SearchSortOrder.newestFirst;

    var visibleInvites = List<Invite>.from(invites);

    if (query.isNotEmpty) {
      visibleInvites = visibleInvites
          .where((invite) => _inviteMatchesQuery(invite, query))
          .toList();
    }

    visibleInvites.sort(
      (a, b) => sortOrder.isNewestFirst
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : b.title.toLowerCase().compareTo(a.title.toLowerCase()),
    );

    if (visibleInvites.isEmpty) {
      return Center(
        child: Text(
          l10n.rosterInvitesEmpty,
          style: context.textTheme.muted,
        ),
      );
    }

    return ColoredBox(
      color: context.colorScheme.background,
      child: ListView.builder(
        itemCount: visibleInvites.length,
        itemBuilder: (context, index) {
          final invite = visibleInvites[index];
          return BlocSelector<RosterCubit, RosterState, bool>(
            selector: (state) =>
                state is RosterLoading && state.jid == invite.jid,
            builder: (context, disabled) {
              return ListItemPadding(
                child: AxiListTile(
                  key: Key(invite.jid),
                  menuItems: [
                    AxiDeleteMenuItem(
                      onPressed: () async {
                        if (!disabled &&
                            await confirm(context,
                                    text: l10n.rosterRejectInviteConfirm(
                                      invite.jid,
                                    )) ==
                                true &&
                            context.mounted) {
                          context
                              .read<RosterCubit>()
                              .rejectContact(jid: invite.jid);
                        }
                      },
                    ),
                    BlockMenuItem(jid: invite.jid),
                    ReportSpamMenuItem(jid: invite.jid),
                  ],
                  leading: AxiAvatar(jid: invite.jid),
                  title: invite.title,
                  subtitle: invite.jid,
                  actions: [
                    AxiIconButton(
                      tooltip: l10n.rosterAddContactTooltip,
                      iconData: LucideIcons.userPlus,
                      color: axiGreen,
                      onPressed: disabled
                          ? null
                          : () {
                              context.read<RosterCubit?>()?.addContact(
                                    jid: invite.jid,
                                    title: invite.title,
                                  );
                            },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

bool _inviteMatchesQuery(Invite invite, String query) {
  final lower = query.toLowerCase();
  return invite.title.toLowerCase().contains(lower) ||
      invite.jid.toLowerCase().contains(lower);
}
