import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/chats_list.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ArchivesScreen extends StatelessWidget {
  const ArchivesScreen({super.key, required this.locate});

  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: locate<ChatsCubit>(),
      child: const _ArchivesView(),
    );
  }
}

class _ArchivesView extends StatelessWidget {
  const _ArchivesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived chats'),
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
              ),
            ),
          );
        },
      ),
    );
  }
}
