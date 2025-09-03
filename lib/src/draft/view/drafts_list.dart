import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
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
            final item = items![index];
            final recipients = item.jids.length;
            return AxiListTile(
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
                    if (await confirm(context, text: 'Delete draft?') == true &&
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
            );
          },
        );
      },
    );
  }
}
