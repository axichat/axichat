import 'package:chat/src/app.dart';
import 'package:chat/src/blocklist/bloc/blocklist_bloc.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BlocklistAddButton extends StatelessWidget {
  const BlocklistAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    return ShadTooltip(
      builder: (_) => const Text('Add to blocklist'),
      child: FloatingActionButton(
        child: const Icon(LucideIcons.userX),
        onPressed: () => showShadDialog(
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
                      placeholder: const Text('JID'),
                      description: const Text('Example: friend@axi.im'),
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
        return ShadButton.destructive(
          enabled: !disabled,
          onPressed: () async {
            if ((await confirm(context) ?? false) && context.mounted) {
              context.read<BlocklistBloc>().add(const BlocklistAllUnblocked());
            }
          },
          text: const Text('Unblock all'),
          icon: disabled
              ? AxiProgressIndicator(
                  color: context.colorScheme.foreground,
                  semanticsLabel: 'Waiting for unblock',
                )
              : null,
        );
      },
    );
  }
}
