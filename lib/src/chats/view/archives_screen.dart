// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/chat_selection_bar.dart';
import 'package:axichat/src/chats/view/chats_list.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
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
    return BlocBuilder<ChatsCubit, ChatsState>(
      builder: (context, chatsState) {
        final l10n = context.l10n;
        final selectedJids = chatsState.selectedJids;
        final selectedChats = selectedJids.isEmpty
            ? const <Chat>[]
            : (chatsState.items ?? const <Chat>[])
                .where((chat) => selectedJids.contains(chat.jid))
                .toList();
        final selectionActive = selectedChats.isNotEmpty;
        final archivedItems = chatsState.items
            ?.where((chat) => chat.archived)
            .toList(growable: false);
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.chatsArchiveTitle),
            leadingWidth: AxiIconButton.kDefaultSize + 24,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: AxiIconButton.kDefaultSize,
                  height: AxiIconButton.kDefaultSize,
                  child: AxiIconButton.ghost(
                    iconData: LucideIcons.arrowLeft,
                    tooltip: l10n.commonBack,
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
          body: archivedItems == null
              ? Center(
                  child: AxiProgressIndicator(
                    color: context.colorScheme.foreground,
                  ),
                )
              : archivedItems.isEmpty
                  ? Center(
                      child: Text(
                        l10n.chatsArchiveEmpty,
                        style: context.textTheme.muted,
                      ),
                    )
                  : ListView.builder(
                      itemCount: archivedItems.length,
                      itemBuilder: (context, index) => ListItemPadding(
                        child: ChatListTile(
                          item: archivedItems[index],
                          archivedContext: true,
                          onArchivedTap: (chat) => GoRouter.of(context).push(
                            ArchivedChatRoute(jid: chat.jid).location,
                            extra: locate,
                          ),
                        ),
                      ),
                    ),
          bottomNavigationBar: selectionActive
              ? ChatSelectionActionBar(
                  selectedChats: selectedChats,
                )
              : null,
        );
      },
    );
  }
}
