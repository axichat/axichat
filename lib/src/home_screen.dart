import 'package:chat/src/blocklist/bloc/blocklist_bloc.dart';
import 'package:chat/src/blocklist/view/blocklist_button.dart';
import 'package:chat/src/blocklist/view/blocklist_list.dart';
import 'package:chat/src/chat/view/chat.dart';
import 'package:chat/src/chats/bloc/chats_bloc.dart';
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final tabs = const [
    ('Chats', Chats(), null),
    ('Contacts', RosterList(), RosterAddButton()),
    ('Invites', RosterInvitesList(), null),
    (
      'Blocklist',
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
              BlocProvider(create: (context) => ChatsBloc()),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 1200) {
                  return WideLayout(
                    smallChild: Nexus(tabs: tabs),
                    largeChild: const Chat(),
                  );
                }

                return NarrowLayout(child: Nexus(tabs: tabs));
              },
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
    final showSnackBar = ScaffoldMessenger.maybeOf(context)?.showSnackBar;
    return Column(
      children: [
        Expanded(
          child: NestedScrollView(
            floatHeaderSlivers: true,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverOverlapAbsorber(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverAppBar(
                  title: Text(
                    'Axichat',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  floating: true,
                  forceElevated: innerBoxIsScrolled,
                  bottom: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    tabs: tabs.map((e) {
                      final (label, _, _) = e;
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
                    if (showSnackBar == null) return;
                    if (state is RosterFailure) {
                      showSnackBar(
                        SnackBar(
                          content: Text(
                            state.message,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      );
                    } else if (state is RosterSuccess) {
                      showSnackBar(
                        SnackBar(content: Text(state.message)),
                      );
                    }
                  },
                ),
                BlocListener<BlocklistBloc, BlocklistState>(
                  listener: (context, state) {
                    if (showSnackBar == null) return;
                    if (state is BlocklistFailure) {
                      showSnackBar(
                        SnackBar(
                          content: Text(
                            state.message,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      );
                    } else if (state is BlocklistSuccess) {
                      showSnackBar(
                        SnackBar(content: Text(state.message)),
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
                            handle:
                                NestedScrollView.sliverOverlapAbsorberHandleFor(
                                    context),
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
        const ProfileCard(
          active: true,
        ),
      ],
    );
  }
}
