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

const EdgeInsets _draftListItemPadding =
    EdgeInsets.symmetric(horizontal: 16, vertical: 6);
const double _draftTileHeight = 56.0;

class DraftsList extends StatelessWidget {
  const DraftsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftCubit, DraftState>(
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

        return BlocBuilder<HomeSearchCubit, HomeSearchState>(
          builder: (context, searchState) => _DraftsListBody(
            items: items,
            l10n: l10n,
            searchState: searchState,
          ),
        );
      },
    );
  }
}

class _DraftsListBody extends StatelessWidget {
  const _DraftsListBody({
    required this.items,
    required this.l10n,
    this.searchState,
  });

  final List<Draft> items;
  final AppLocalizations l10n;
  final HomeSearchState? searchState;

  @override
  Widget build(BuildContext context) {
    var visibleItems = List<Draft>.from(items);

    final tabState = searchState?.stateFor(HomeTab.drafts);
    final searchActive = searchState?.active ?? false;
    final query =
        searchActive ? (tabState?.query.trim().toLowerCase() ?? '') : '';
    final filterId = tabState?.filterId;
    final sortOrder = tabState?.sort ?? SearchSortOrder.newestFirst;

    if (filterId == 'attachments') {
      visibleItems = visibleItems
          .where((draft) => draft.attachmentMetadataIds.isNotEmpty)
          .toList();
    }

    if (query.isNotEmpty) {
      visibleItems = visibleItems
          .where((draft) => _draftMatchesQuery(draft, query))
          .toList();
    }

    visibleItems.sort(
      (a, b) =>
          sortOrder.isNewestFirst ? b.id.compareTo(a.id) : a.id.compareTo(b.id),
    );

    if (visibleItems.isEmpty) {
      return Center(
        child: Text(
          l10n.draftsEmpty,
          style: context.textTheme.muted,
        ),
      );
    }

    return ColoredBox(
      color: context.colorScheme.background,
      child: ListView.builder(
        itemCount: visibleItems.length,
        itemBuilder: (context, index) {
          final item = visibleItems[index];
          final recipients = item.jids.length;
          final Widget leadingAvatar = recipients == 1
              ? context.read<RosterCubit?>() == null
                  ? AxiAvatar(jid: item.jids[0])
                  : BlocBuilder<RosterCubit, RosterState>(
                      buildWhen: (_, current) => current is RosterAvailable,
                      builder: (context, rosterState) {
                        final cachedItems = rosterState is RosterAvailable
                            ? rosterState.items
                            : context.read<RosterCubit>()['items']
                                as List<RosterItem>?;
                        final normalizedJid = item.jids[0].trim().toLowerCase();
                        String? avatarPath;
                        if (cachedItems != null) {
                          for (final rosterItem in cachedItems) {
                            if (rosterItem.jid.toLowerCase() == normalizedJid) {
                              avatarPath = rosterItem.avatarPath;
                              break;
                            }
                          }
                        }
                        return AxiAvatar(
                          jid: item.jids[0],
                          avatarPath: avatarPath,
                        );
                      },
                    )
              : AxiAvatar(jid: recipients.toString());
          return ListItemPadding(
            padding: _draftListItemPadding,
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
                      context.read<DraftCubit?>()?.deleteDraft(id: item.id);
                    }
                  },
                )
              ],
              leading: leadingAvatar,
              title:
                  '${_subjectLabel(context, item)} — ${_recipientLabel(context, item)}',
              minTileHeight: _draftTileHeight,
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

bool _draftMatchesQuery(Draft draft, String query) {
  final lower = query.toLowerCase();
  final recipients = draft.jids.join(', ').toLowerCase();
  return recipients.contains(lower) ||
      (draft.body?.toLowerCase().contains(lower) ?? false) ||
      (draft.subject?.toLowerCase().contains(lower) ?? false);
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
