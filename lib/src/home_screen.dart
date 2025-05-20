// ignore_for_file: unnecessary_type_check
import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/blocklist/view/blocklist_button.dart';
import 'package:axichat/src/blocklist/view/blocklist_list.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/view/chat.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/chats_filter_button.dart';
import 'package:axichat/src/chats/view/chats_list.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/connectivity/view/connectivity_indicator.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/draft_button.dart';
import 'package:axichat/src/draft/view/drafts_list.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/view/profile_card.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/roster/view/roster_add_button.dart';
import 'package:axichat/src/roster/view/roster_invites_list.dart';
import 'package:axichat/src/roster/view/roster_list.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final getService = context.read<XmppService>;

    final isChat = getService() is ChatsService;
    final isMessage = getService() is MessageService;
    final isRoster = getService() is RosterService;
    final isPresence = getService() is PresenceService;
    final isOmemo = getService() is OmemoService;
    final isBlocking = getService() is BlockingService;

    final tabs = [
      if (isChat)
        (
          'Chats',
          const ChatsList(key: PageStorageKey('Chats')),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [ChatsFilterButton(), DraftButton()],
          )
        ),
      if (isRoster)
        (
          'Contacts',
          const RosterList(key: PageStorageKey('Contacts')),
          const RosterAddButton()
        ),
      if (isRoster)
        ('New', const RosterInvitesList(key: PageStorageKey('New')), null),
      if (isBlocking)
        (
          'Blocked',
          const BlocklistList(key: PageStorageKey('Blocked')),
          const BlocklistAddButton(),
        ),
      if (isMessage)
        ('Drafts', const DraftsList(key: PageStorageKey('Drafts')), null),
    ];

    return Scaffold(
      body: DefaultTabController(
        length: tabs.length,
        animationDuration: context.watch<SettingsCubit>().animationDuration,
        child: MultiBlocProvider(
          providers: [
            if (isChat)
              BlocProvider(
                create: (context) => ChatsCubit(
                  chatsService: context.read<XmppService>(),
                ),
              ),
            if (isMessage)
              BlocProvider(
                create: (context) => DraftCubit(
                  messageService: context.read<XmppService>(),
                ),
              ),
            if (isRoster)
              BlocProvider(
                create: (context) => RosterCubit(
                  rosterService: context.read<XmppService>(),
                ),
              ),
            if (isPresence)
              BlocProvider(
                create: (context) => ProfileCubit(
                  presenceService: context.read<XmppService>(),
                  omemoService: isOmemo ? context.read<XmppService>() : null,
                ),
              ),
            if (isBlocking)
              BlocProvider(
                create: (context) => BlocklistCubit(
                  blockingService: context.read<XmppService>(),
                ),
              ),
            BlocProvider(
              create: (context) => ConnectivityCubit(
                xmppBase: context.read<XmppService>(),
              ),
            ),
          ],
          child: Builder(
            builder: (context) {
              final openJid = context.watch<ChatsCubit?>()?.state.openJid;
              return PopScope(
                canPop: false,
                onPopInvoked: (_) {
                  if (openJid case final jid?) {
                    context.read<ChatsCubit?>()?.toggleChat(jid: jid);
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
                              secondaryChild: openJid == null ||
                                      context.read<XmppService?>() == null
                                  ? const GuestChat()
                                  : BlocProvider(
                                      key: Key(openJid),
                                      create: (context) => ChatBloc(
                                        jid: openJid,
                                        messageService:
                                            context.read<XmppService>(),
                                        chatsService:
                                            context.read<XmppService>(),
                                        notificationService:
                                            context.read<NotificationService>(),
                                        omemoService: isOmemo
                                            ? context.read<XmppService>()
                                            : null,
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
            if (context.read<RosterCubit?>() != null)
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
            if (context.read<BlocklistCubit?>() != null)
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
          builder: (context, constraints) => Material(
            child: TabBar(
              isScrollable: constraints.maxWidth < tabs.length * 90,
              tabAlignment: constraints.maxWidth < tabs.length * 90
                  ? TabAlignment.center
                  : TabAlignment.fill,
              dividerHeight: 0.0,
              tabs: tabs.map((e) {
                final (label, _, _) = e;
                if (label == 'New') {
                  final length = context.watch<RosterCubit?>()?.inviteCount;
                  return Tab(
                    child: AxiBadge(
                      count: length ?? 0,
                      child: Text(label),
                    ),
                  );
                }
                return Tab(text: label);
              }).toList(),
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
