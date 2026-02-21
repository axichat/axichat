// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/chats_list.dart';
import 'package:axichat/src/chats/view/widgets/transport_aware_avatar.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

typedef _SpamSearchInputs = ({bool active, TabSearchState tabState});

class SpamList extends StatelessWidget {
  const SpamList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<HomeSearchCubit, HomeSearchState, _SpamSearchInputs>(
      selector: (state) =>
          (active: state.active, tabState: state.stateFor(HomeTab.spam)),
      builder: (context, searchInputs) => _SpamSearchSync(
        searchInputs: searchInputs,
        child: BlocBuilder<ChatsCubit, ChatsState>(
          buildWhen: (previous, current) =>
              previous.items != current.items ||
              previous.spamVisibleItems != current.spamVisibleItems ||
              previous.spamUpdatingJids != current.spamUpdatingJids,
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
      ),
    );
  }
}

class _SpamSearchSync extends StatefulWidget {
  const _SpamSearchSync({required this.searchInputs, required this.child});

  final _SpamSearchInputs searchInputs;
  final Widget child;

  @override
  State<_SpamSearchSync> createState() => _SpamSearchSyncState();
}

class _SpamSearchSyncState extends State<_SpamSearchSync> {
  _SpamSearchInputs? _lastInputs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncIfNeeded(widget.searchInputs);
  }

  @override
  void didUpdateWidget(covariant _SpamSearchSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchInputs != widget.searchInputs) {
      _syncIfNeeded(widget.searchInputs);
    }
  }

  void _syncIfNeeded(_SpamSearchInputs inputs) {
    if (_lastInputs == inputs) {
      return;
    }
    _lastInputs = inputs;
    context.read<ChatsCubit>().updateSpamSearchSnapshot(
      active: inputs.active,
      query: inputs.tabState.query,
      filterId: inputs.tabState.filterId,
      sortOrder: inputs.tabState.sort,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SpamListBody extends StatelessWidget {
  const _SpamListBody({required this.items, required this.updatingJids});

  final List<Chat> items;
  final Set<String> updatingJids;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profileJid = context.watch<ProfileCubit>().state.jid;
    final resolvedProfileJid = profileJid.trim();
    final String? selfJid = resolvedProfileJid.isNotEmpty
        ? resolvedProfileJid
        : null;
    final selfIdentity = SelfIdentitySnapshot(
      selfJid: selfJid,
      avatarPath: context.watch<ProfileCubit>().state.avatarPath,
    );
    if (items.isEmpty) {
      return Center(
        child: Text(l10n.spamEmpty, style: context.textTheme.muted),
      );
    }

    return AxiNowTicker(
      now: kEnableDemoChats ? demoNow : DateTime.now,
      builder: (context, nowListenable) => ValueListenableBuilder<DateTime>(
        valueListenable: nowListenable,
        builder: (context, timestampNow, _) {
          return ColoredBox(
            color: context.colorScheme.background,
            child: ListView.builder(
              padding: EdgeInsets.only(top: context.spacing.m),
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
                        timestampNow: timestampNow,
                        selfIdentity: selfIdentity,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AxiButton.secondary(
                          loading: isUpdating,
                          onPressed: isUpdating
                              ? null
                              : () => _moveToInbox(context, chat),
                          child: Text(l10n.spamMoveToInbox),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
