import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BlocklistTile extends StatelessWidget {
  const BlocklistTile({super.key, required this.jid});

  final String jid;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) =>
          state is BlocklistLoading && (state.jid == jid || state.jid == null),
      builder: (context, disabled) {
        return AxiListTile(
          leading: AxiAvatar(jid: jid),
          title: jid,
          actions: [
            ShadButton.ghost(
              onPressed: disabled
                  ? null
                  : () => context.read<BlocklistCubit?>()?.unblock(jid: jid),
              foregroundColor: context.colorScheme.destructive,
              text: const Text('Unblock'),
            ),
          ],
        );
      },
    );
  }
}
