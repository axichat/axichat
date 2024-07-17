import 'package:chat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
            TextButton(
              onPressed: disabled
                  ? null
                  : () => context.read<BlocklistCubit>().unblock(jid: jid),
              child: const Text('Unblock'),
            ),
          ],
        );
      },
    );
  }
}
