import 'package:chat/src/app.dart';
import 'package:chat/src/blocklist/bloc/blocklist_bloc.dart';
import 'package:chat/src/blocklist/view/blocklist_button.dart';
import 'package:chat/src/blocklist/view/blocklist_list.dart';
import 'package:chat/src/chat/view/chat.dart';
import 'package:chat/src/chats/bloc/chats_cubit.dart';
import 'package:chat/src/chats/view/chats_list.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:chat/src/profile/view/profile_card.dart';
import 'package:chat/src/roster/bloc/roster_bloc.dart';
import 'package:chat/src/roster/view/roster_add_button.dart';
import 'package:chat/src/roster/view/roster_invites_list.dart';
import 'package:chat/src/roster/view/roster_list.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'chat/bloc/chat_bloc.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final tabs = const [
    ('Chats', ChatsList(), null),
    ('Contacts', RosterList(), RosterAddButton()),
    ('New', RosterInvitesList(), null),
    (
      'Blocked',
      BlocklistList(),
      BlocklistAddButton(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: DefaultTabController(
          length: tabs.length,
          child: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) => ChatsCubit(
                  xmppService: context.read<XmppService>(),
                ),
              ),
              BlocProvider(
                create: (context) => RosterBloc(
                  xmppService: context.read<XmppService>(),
                ),
              ),
              BlocProvider(
                create: (context) => ProfileCubit(
                  xmppService: context.read<XmppService>(),
                ),
              ),
              BlocProvider(
                create: (context) => BlocklistBloc(
                  xmppService: context.read<XmppService>(),
                ),
              ),
            ],
            child: AxiAdaptiveLayout(
              primaryChild: Nexus(tabs: tabs),
              secondaryChild: Builder(builder: (context) {
                final openJid = context.watch<ChatsCubit>().state.openJid;
                return openJid == null
                    ? const GuestChat()
                    : BlocProvider(
                        key: Key(openJid),
                        create: (context) => ChatBloc(
                          jid: openJid,
                          xmppService: context.read<XmppService>(),
                        ),
                        child: const Chat(),
                      );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class Nexus extends StatelessWidget {
  const Nexus({super.key, required this.tabs});

  final List tabs;

  @override
  Widget build(BuildContext context) {
    final showToast = ShadToaster.maybeOf(context)?.show;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => NestedScrollView(
              floatHeaderSlivers: true,
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverOverlapAbsorber(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverAppBar(
                    title: Text(
                      'Axichat',
                      style: context.textTheme.h3,
                    ),
                    floating: true,
                    forceElevated: innerBoxIsScrolled,
                    bottom: TabBar(
                      isScrollable: constraints.maxWidth < smallScreen / 2,
                      tabAlignment: constraints.maxWidth < smallScreen / 2
                          ? TabAlignment.center
                          : TabAlignment.fill,
                      dividerColor: context.colorScheme.border,
                      tabs: tabs.map((e) {
                        final (label, _, _) = e;
                        if (label == 'New') {
                          final length =
                              context.watch<RosterBloc>().state.invites.length;
                          return Tab(
                            child: AxiBadge(
                              count: length,
                              child: Text(label),
                            ),
                          );
                        }
                        return Tab(text: label);
                      }).toList(),
                    ),
                  ),
                ),
              ],
              body: MultiBlocListener(
                listeners: [
                  BlocListener<RosterBloc, RosterState>(
                    listener: (context, state) {
                      if (showToast == null) return;
                      if (state is RosterFailure) {
                        showToast(
                          ShadToast.destructive(
                            title: const Text('Whoops!'),
                            description: Text(state.message),
                          ),
                        );
                      } else if (state is RosterSuccess) {
                        showToast(
                          ShadToast(
                            title: const Text('Success!'),
                            description: Text(state.message),
                          ),
                        );
                      }
                    },
                  ),
                  BlocListener<BlocklistBloc, BlocklistState>(
                    listener: (context, state) {
                      if (showToast == null) return;
                      if (state is BlocklistFailure) {
                        showToast(
                          ShadToast.destructive(
                            title: const Text('Whoops!'),
                            description: Text(state.message),
                          ),
                        );
                      } else if (state is BlocklistSuccess) {
                        showToast(
                          ShadToast(
                            title: const Text('Success!'),
                            description: Text(state.message),
                          ),
                        );
                      }
                    },
                  ),
                ],
                child: TabBarView(
                  children: tabs.map((e) {
                    final (label, sliver, fab) = e;
                    return Builder(builder: (context) {
                      return Scaffold(
                        body: CustomScrollView(
                          key: PageStorageKey(label),
                          slivers: [
                            SliverOverlapInjector(
                              handle: NestedScrollView
                                  .sliverOverlapAbsorberHandleFor(context),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.all(12.0),
                              sliver: sliver,
                            ),
                          ],
                        ),
                        floatingActionButton: fab,
                      );
                    });
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const ProfileCard(
          active: true,
        ),
      ],
    );
  }
}
