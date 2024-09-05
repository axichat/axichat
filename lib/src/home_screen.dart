import 'package:chat/src/app.dart';
import 'package:chat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:chat/src/blocklist/view/blocklist_button.dart';
import 'package:chat/src/blocklist/view/blocklist_list.dart';
import 'package:chat/src/chat/view/chat.dart';
import 'package:chat/src/chats/bloc/chats_cubit.dart';
import 'package:chat/src/chats/view/chats_filter_button.dart';
import 'package:chat/src/chats/view/chats_list.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/connectivity/view/connectivity_indicator.dart';
import 'package:chat/src/draft/bloc/draft_cubit.dart';
import 'package:chat/src/draft/view/draft_button.dart';
import 'package:chat/src/draft/view/drafts_list.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:chat/src/profile/view/profile_card.dart';
import 'package:chat/src/roster/bloc/roster_cubit.dart';
import 'package:chat/src/roster/view/roster_add_button.dart';
import 'package:chat/src/roster/view/roster_invites_list.dart';
import 'package:chat/src/roster/view/roster_list.dart';
import 'package:chat/src/settings/bloc/settings_cubit.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'chat/bloc/chat_bloc.dart';
import 'connectivity/bloc/connectivity_cubit.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final tabs = const [
    (
      'Chats',
      ChatsList(key: PageStorageKey('Chats')),
      Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ChatsFilterButton(),
          DraftButton(),
        ],
      )
    ),
    (
      'Contacts',
      RosterList(key: PageStorageKey('Contacts')),
      RosterAddButton()
    ),
    ('New', RosterInvitesList(key: PageStorageKey('New')), null),
    (
      'Blocked',
      BlocklistList(key: PageStorageKey('Blocked')),
      BlocklistAddButton(),
    ),
    ('Drafts', DraftsList(key: PageStorageKey('Drafts')), null),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DefaultTabController(
        length: tabs.length,
        animationDuration: context.watch<SettingsCubit>().animationDuration,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => ChatsCubit(
                xmppService: context.read<XmppService>(),
              ),
            ),
            BlocProvider(
              create: (context) => DraftCubit(
                xmppService: context.read<XmppService>(),
              ),
            ),
            BlocProvider(
              create: (context) => RosterCubit(
                xmppService: context.read<XmppService>(),
              ),
            ),
            BlocProvider(
              create: (context) => ProfileCubit(
                xmppService: context.read<XmppService>(),
              ),
            ),
            BlocProvider(
              create: (context) => BlocklistCubit(
                xmppService: context.read<XmppService>(),
              ),
            ),
            BlocProvider(
              create: (context) => ConnectivityCubit(
                xmppService: context.read<XmppService>(),
              ),
            ),
          ],
          child: Builder(
            builder: (context) {
              final openJid = context.watch<ChatsCubit>().state.openJid;
              return PopScope(
                canPop: false,
                onPopInvoked: (_) {
                  if (openJid case final jid?) {
                    context.read<ChatsCubit>().toggleChat(jid: jid);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ConnectivityIndicator(),
                    Expanded(
                      child: BlocBuilder<ConnectivityCubit, ConnectivityState>(
                        builder: (context, state) {
                          return SafeArea(
                            top: state is ConnectivityConnected,
                            child: AxiAdaptiveLayout(
                              invertPriority: openJid != null,
                              primaryChild: Nexus(tabs: tabs),
                              secondaryChild: openJid == null
                                  ? const GuestChat()
                                  : BlocProvider(
                                      key: Key(openJid),
                                      create: (context) => ChatBloc(
                                        jid: openJid,
                                        xmppService:
                                            context.read<XmppService>(),
                                      ),
                                      child: const Chat(),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
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
        const AxiAppBar(),
        MultiBlocListener(
          listeners: [
            BlocListener<RosterCubit, RosterState>(
              listener: (context, state) {
                if (showToast == null) return;
                if (state is RosterFailure) {
                  showToast(
                    ShadToast.destructive(
                      title: const Text('Whoops!'),
                      description: Text(state.message),
                      showCloseIconOnlyWhenHovered: false,
                    ),
                  );
                } else if (state is RosterSuccess) {
                  showToast(
                    ShadToast(
                      title: const Text('Success!'),
                      description: Text(state.message),
                      showCloseIconOnlyWhenHovered: false,
                    ),
                  );
                }
              },
            ),
            BlocListener<BlocklistCubit, BlocklistState>(
              listener: (context, state) {
                if (showToast == null) return;
                if (state is BlocklistFailure) {
                  showToast(
                    ShadToast.destructive(
                      title: const Text('Whoops!'),
                      description: Text(state.message),
                      showCloseIconOnlyWhenHovered: false,
                    ),
                  );
                } else if (state is BlocklistSuccess) {
                  showToast(
                    ShadToast(
                      title: const Text('Success!'),
                      description: Text(state.message),
                      showCloseIconOnlyWhenHovered: false,
                    ),
                  );
                }
              },
            ),
          ],
          child: Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.colorScheme.border),
                ),
              ),
              child: TabBarView(
                children: tabs.map((e) {
                  final (_, sliver, fab) = e;
                  return Scaffold(
                    extendBodyBehindAppBar: true,
                    body: sliver,
                    floatingActionButton: fab,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) => TabBar(
            isScrollable: constraints.maxWidth < tabs.length * 90,
            tabAlignment: constraints.maxWidth < tabs.length * 90
                ? TabAlignment.center
                : TabAlignment.fill,
            dividerHeight: 0.0,
            tabs: tabs.map((e) {
              final (label, _, _) = e;
              if (label == 'New') {
                final length = context.watch<RosterCubit>().inviteCount;
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
        const ProfileCard(
          active: true,
        ),
      ],
    );
  }
}
