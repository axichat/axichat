// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/chats_list.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SpamList extends StatefulWidget {
  const SpamList({super.key});

  @override
  State<SpamList> createState() => _SpamListState();
}

class _SpamListState extends State<SpamList> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final searchState = context.read<HomeSearchCubit>().state;
    final tabState = searchState.stateFor(HomeTab.spam);
    context.read<ChatsCubit>().updateSpamSearchSnapshot(
          active: searchState.active,
          query: tabState.query,
          filterId: tabState.filterId,
          sortOrder: tabState.sort,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeSearchCubit, HomeSearchState>(
      listenWhen: (previous, current) {
        final previousTab = previous.stateFor(HomeTab.spam);
        final currentTab = current.stateFor(HomeTab.spam);
        return previous.active != current.active ||
            previousTab.query != currentTab.query ||
            previousTab.filterId != currentTab.filterId ||
            previousTab.sort != currentTab.sort;
      },
      listener: (context, searchState) {
        final tabState = searchState.stateFor(HomeTab.spam);
        context.read<ChatsCubit>().updateSpamSearchSnapshot(
              active: searchState.active,
              query: tabState.query,
              filterId: tabState.filterId,
              sortOrder: tabState.sort,
            );
      },
      child: BlocBuilder<ChatsCubit, ChatsState>(
        builder: (context, state) {
          if (state.items == null) {
            return Center(
              child: AxiProgressIndicator(
                color: context.colorScheme.foreground,
              ),
            );
          }
          return _SpamListBody(
            items: state.spamVisibleItems,
            updatingJids: state.spamUpdatingJids,
          );
        },
      ),
    );
  }
}

class _SpamListBody extends StatelessWidget {
  const _SpamListBody({
    required this.items,
    required this.updatingJids,
  });

  final List<Chat> items;
  final Set<String> updatingJids;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (items.isEmpty) {
      return Center(
        child: Text(l10n.spamEmpty, style: context.textTheme.muted),
      );
    }

    return ColoredBox(
      color: context.colorScheme.background,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final chat = items[index];
          final isUpdating = updatingJids.contains(chat.jid);
          return ListItemPadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChatListTile(
                  item: chat,
                  selectionActive: false,
                  isSelected: false,
                  isOpen: false,
                  timestampNow: DateTime.now(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: AxiButton.secondary(
                    size: AxiButtonSize.sm,
                    loading: isUpdating,
                    onPressed:
                        isUpdating ? null : () => _moveToInbox(context, chat),
                    child: Text(l10n.spamMoveToInbox),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<void> _moveToInbox(BuildContext context, Chat chat) async {
  final toaster = ShadToaster.maybeOf(context);
  final success = await context.read<ChatsCubit>().moveSpamToInbox(chat: chat);
  if (!context.mounted) {
    return;
  }
  if (success == null) {
    return;
  }
  if (!success) {
    toaster?.show(
      FeedbackToast.error(message: context.l10n.chatSpamUpdateFailed),
    );
    return;
  }
  toaster?.show(
    FeedbackToast.success(
      title: context.l10n.spamMoveToastTitle,
      message: context.l10n.spamMoveToastMessage(chat.title),
    ),
  );
}
