import 'package:chat/src/blocklist/bloc/blocklist_bloc.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BlocklistAddButton extends StatelessWidget {
  const BlocklistAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    return FloatingActionButton(
      tooltip: 'Add to blocklist',
      child: const Icon(Icons.person_off),
      onPressed: () => showDialog(
        context: context,
        builder: (context) {
          String jid = '';
          return BlocProvider.value(
            value: locate<BlocklistBloc>(),
            child: StatefulBuilder(
              builder: (context, setState) {
                return AxiInputDialog(
                  title: const Text('Block user'),
                  content: AxiTextFormField(
                    labelText: 'JID',
                    hintText: 'friend@axi.im',
                    onChanged: (value) {
                      setState(() => jid = value);
                    },
                  ),
                  callback: () => jid.isEmpty
                      ? null
                      : context
                          .read<BlocklistBloc>()
                          .add(BlocklistBlocked(jid: jid)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class BlocklistUnblockAllButton extends StatelessWidget {
  const BlocklistUnblockAllButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BlocklistBloc, BlocklistState, bool>(
      selector: (state) => state is BlocklistLoading && state.jid == null,
      builder: (context, disabled) {
        return TextButton(
          onPressed: disabled
              ? null
              : () async {
                  if ((await confirm(context) ?? false) && context.mounted) {
                    context
                        .read<BlocklistBloc>()
                        .add(const BlocklistAllUnblocked());
                  }
                },
          child: const Text('Unblock all'),
        );
      },
    );
  }
}
