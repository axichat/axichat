import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/chat_selection_bar.dart';
import 'package:axichat/src/chats/view/chats_list.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ArchivesScreen extends StatelessWidget {
  const ArchivesScreen({super.key, required this.locate});

  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: locate<ChatsCubit>(),
      child: _ArchivesView(locate: locate),
    );
  }
}

class _ArchivesView extends StatelessWidget {
  const _ArchivesView({required this.locate});

  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    final chatsCubit = context.watch<ChatsCubit?>();
    List<Chat> selectedChats = const <Chat>[];
    if (chatsCubit != null &&
        chatsCubit.state.selectedJids.isNotEmpty &&
        chatsCubit.state.items != null) {
      selectedChats = chatsCubit.state.items!
          .where(
            (chat) => chatsCubit.state.selectedJids.contains(chat.jid),
          )
          .toList();
    }
    final selectionActive = selectedChats.isNotEmpty && chatsCubit != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive'),
        leadingWidth: AxiIconButton.kDefaultSize + 24,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: AxiIconButton.kDefaultSize,
              height: AxiIconButton.kDefaultSize,
              child: AxiIconButton(
                iconData: LucideIcons.arrowLeft,
                tooltip: 'Back',
                color: context.colorScheme.foreground,
                borderColor: context.colorScheme.border,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: context.colorScheme.border,
          ),
        ),
      ),
      body: BlocSelector<ChatsCubit, ChatsState, List<Chat>?>(
        selector: (state) =>
            state.items?.where((chat) => chat.archived).toList(growable: false),
        builder: (context, items) {
          if (items == null) {
            return Center(
              child: AxiProgressIndicator(
                color: context.colorScheme.foreground,
              ),
            );
          }
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No archived chats yet',
                style: context.textTheme.muted,
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => ListItemPadding(
              child: ChatListTile(
                item: items[index],
                archivedContext: true,
                onArchivedTap: (chat) => GoRouter.of(context).push(
                  ArchivedChatRoute(jid: chat.jid).location,
                  extra: locate,
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: selectionActive
          ? ChatSelectionActionBar(
              chatsCubit: chatsCubit,
              selectedChats: selectedChats,
            )
          : null,
    );
  }
}
