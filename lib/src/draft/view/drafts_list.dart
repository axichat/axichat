import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DraftsList extends StatelessWidget {
  const DraftsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftCubit, DraftState>(
      buildWhen: (_, current) => current is DraftsAvailable,
      builder: (context, state) {
        late final List<Draft>? items;

        if (state is! DraftsAvailable) {
          items = context.read<DraftCubit>()['items'];
        } else {
          items = state.items;
        }

        if (items == null) {
          return Center(
            child: AxiProgressIndicator(
              color: context.colorScheme.foreground,
            ),
          );
        }

        var visibleItems = List<Draft>.from(items);

        final searchState = context.watch<HomeSearchCubit?>()?.state;
        final tabState = searchState?.stateFor(HomeTab.drafts);
        final searchActive = searchState?.active ?? false;
        final query =
            searchActive ? (tabState?.query.trim().toLowerCase() ?? '') : '';
        final filterId = tabState?.filterId;
        final sortOrder = tabState?.sort ?? SearchSortOrder.newestFirst;

        if (filterId == 'attachments') {
          visibleItems = visibleItems
              .where((draft) => draft.fileMetadataID != null)
              .toList();
        }

        if (query.isNotEmpty) {
          visibleItems = visibleItems
              .where((draft) => _draftMatchesQuery(draft, query))
              .toList();
        }

        visibleItems.sort(
          (a, b) => sortOrder.isNewestFirst
              ? b.id.compareTo(a.id)
              : a.id.compareTo(b.id),
        );

        if (visibleItems.isEmpty) {
          return Center(
            child: Text(
              'No drafts yet',
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
              return ListItemPadding(
                child: AxiListTile(
                  key: Key(item.id.toString()),
                  onTap: () => context.push(
                    const ComposeRoute().location,
                    extra: {
                      'locate': context.read,
                      'id': item.id,
                      'jids': item.jids,
                      'body': item.body,
                    },
                  ),
                  menuItems: [
                    AxiDeleteMenuItem(
                      onPressed: () async {
                        if (await confirm(context, text: 'Delete draft?') ==
                                true &&
                            context.mounted) {
                          context.read<DraftCubit?>()?.deleteDraft(id: item.id);
                        }
                      },
                    )
                  ],
                  leading: AxiAvatar(
                    jid: recipients == 1 ? item.jids[0] : recipients.toString(),
                  ),
                  title: item.jids.join(', '),
                  subtitle: item.body,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

bool _draftMatchesQuery(Draft draft, String query) {
  final lower = query.toLowerCase();
  final recipients = draft.jids.join(', ').toLowerCase();
  return recipients.contains(lower) ||
      (draft.body?.toLowerCase().contains(lower) ?? false);
}
