import 'package:chat/src/app.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/draft/bloc/draft_cubit.dart';
import 'package:chat/src/draft/view/draft_form.dart';
import 'package:chat/src/storage/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DraftsList extends StatelessWidget {
  const DraftsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DraftCubit, DraftState>(
      buildWhen: (_, current) => current is DraftsAvailable,
      builder: (context, state) {
        late List<Draft> items;
        if (state is! DraftsAvailable) {
          items = context.read<DraftCubit>()['items'];
        } else {
          items = state.items;
        }
        if (items.isEmpty) {
          return Center(
            child: Text(
              'No drafts yet',
              style: context.textTheme.muted,
            ),
          );
        }
        return ListView.separated(
          separatorBuilder: (_, __) => const AxiListDivider(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return AxiListTile(
              key: Key(item.id.toString()),
              onTap: () => showDraft(
                context,
                id: item.id,
                jid: item.jid,
                body: item.body ?? '',
              ),
              onDismissed: (_) =>
                  context.read<DraftCubit>().deleteDraft(id: item.id),
              dismissText: 'Delete draft to ${item.jid}?',
              leading: AxiAvatar(
                jid: item.jid,
              ),
              title: item.jid,
              subtitle: item.body,
            );
          },
        );
      },
    );
  }
}
