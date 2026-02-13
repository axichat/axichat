// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/compose_launcher.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axichat/src/localization/app_localizations.dart';

class DraftsList extends StatefulWidget {
  const DraftsList({super.key});

  @override
  State<DraftsList> createState() => _DraftsListState();
}

class _DraftsListState extends State<DraftsList> {
  void _syncSearchSnapshot(HomeSearchState searchState) {
    final tabState = searchState.stateFor(HomeTab.drafts);
    final query = searchState.active ? tabState.query.trim().toLowerCase() : '';
    final filterAttachmentsOnly =
        tabState.filterId == SearchFilterId.attachments;
    final sortOrder = switch (tabState.sort) {
      SearchSortOrder.oldestFirst => DraftSortOrder.oldestFirst,
      _ => DraftSortOrder.newestFirst,
    };
    context.read<DraftCubit>().updateSearchSnapshot(
          DraftSearchSnapshot(
            query: query,
            filterAttachmentsOnly: filterAttachmentsOnly,
            sortOrder: sortOrder,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeSearchCubit, HomeSearchState>(
      listener: (context, searchState) => _syncSearchSnapshot(searchState),
      child: BlocBuilder<DraftCubit, DraftState>(
        buildWhen: (_, current) => current is DraftsAvailable,
        builder: (context, state) {
          final l10n = context.l10n;
          final List<Draft>? items = state.items;

          if (items == null) {
            return Center(
              child: AxiProgressIndicator(
                color: context.colorScheme.foreground,
              ),
            );
          }

          return BlocBuilder<RosterCubit, RosterState>(
            buildWhen: (previous, current) => previous.items != current.items,
            builder: (context, rosterState) {
              final rosterItems = rosterState.items ??
                  (context.watch<RosterCubit>()['items']
                      as List<RosterItem>?) ??
                  const <RosterItem>[];
              final avatarByJid = <String, String?>{
                for (final item in rosterItems)
                  item.jid.normalizedJidKey ?? item.jid.toLowerCase():
                      item.avatarPath,
              };
              return _DraftsListBody(
                items: state.visibleItems ?? items,
                l10n: l10n,
                avatarByJid: avatarByJid,
              );
            },
          );
        },
      ),
    );
  }
}

class _DraftsListBody extends StatelessWidget {
  const _DraftsListBody({
    required this.items,
    required this.l10n,
    required this.avatarByJid,
  });

  final List<Draft> items;
  final AppLocalizations l10n;
  final Map<String, String?> avatarByJid;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(l10n.draftsEmpty, style: context.textTheme.muted),
      );
    }

    final spacing = context.spacing;
    final sizing = context.sizing;
    final listItemPadding = EdgeInsets.symmetric(
      horizontal: spacing.m,
      vertical: spacing.xs,
    );
    return ColoredBox(
      color: context.colorScheme.background,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final recipients = item.jids.length;
          final Widget leadingAvatar;
          if (recipients == 1) {
            final normalizedJid = item.jids[0].normalizedJidKey;
            final resolvedKey = normalizedJid ?? item.jids[0].toLowerCase();
            leadingAvatar = AxiAvatar(
              jid: item.jids[0],
              avatarPath: avatarByJid[resolvedKey],
            );
          } else {
            leadingAvatar = AxiAvatar(jid: recipients.toString());
          }
          return ListItemPadding(
            padding: listItemPadding,
            child: AxiListTile(
              key: Key(item.id.toString()),
              onTap: () => openComposeDraft(
                context,
                id: item.id,
                jids: item.jids,
                body: item.body ?? '',
                subject: item.subject ?? '',
                attachmentMetadataIds: item.attachmentMetadataIds,
              ),
              menuItems: [
                AxiDeleteMenuItem(
                  onPressed: () async {
                    if (await confirm(
                              context,
                              text: l10n.draftsDeleteConfirm,
                            ) ==
                            true &&
                        context.mounted) {
                      context.read<DraftCubit>().deleteDraft(id: item.id);
                    }
                  },
                ),
              ],
              leading: leadingAvatar,
              title:
                  '${_subjectLabel(context, item)} — ${_recipientLabel(context, item)}',
              minTileHeight: sizing.listButtonHeight,
              subtitle: item.body?.isNotEmpty == true
                  ? item.body
                  : item.jids.join(', '),
            ),
          );
        },
      ),
    );
  }
}

String _subjectLabel(BuildContext context, Draft draft) {
  final subject = draft.subject?.trim();
  if (subject == null || subject.isEmpty) {
    return context.l10n.draftNoSubject;
  }
  return subject;
}

String _recipientLabel(BuildContext context, Draft draft) {
  final count = draft.jids.length;
  return context.l10n.draftRecipientCount(count);
}
