import 'package:chat/src/blocklist/bloc/blocklist_bloc.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BlocklistTile extends StatelessWidget {
  const BlocklistTile({super.key, required this.jid});

  final String jid;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BlocklistBloc, BlocklistState, bool>(
      selector: (state) =>
          state is BlocklistLoading && (state.jid == jid || state.jid == null),
      builder: (context, disabled) {
        return ListTile(
          leading: AxiAvatar(jid: jid),
          title: Text(jid),
          enabled: !disabled,
          trailing: TextButton(
            onPressed: disabled
                ? null
                : () => context
                    .read<BlocklistBloc>()
                    .add(BlocklistUnblocked(jid: jid)),
            child: const Text('Unblock'),
          ),
        );
      },
    );
  }
}
