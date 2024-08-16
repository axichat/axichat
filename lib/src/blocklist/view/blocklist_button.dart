import 'package:chat/src/app.dart';
import 'package:chat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BlocklistAddButton extends StatelessWidget {
  const BlocklistAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    return AxiTooltip(
      builder: (_) => const Text('Add to blocklist'),
      child: FloatingActionButton(
        child: const Icon(LucideIcons.userX),
        onPressed: () => showShadDialog(
          context: context,
          builder: (context) {
            String jid = '';
            return BlocProvider.value(
              value: locate<BlocklistCubit>(),
              child: Form(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return AxiInputDialog(
                      title: const Text('Block user'),
                      content: JidInput(
                        onChanged: (value) {
                          setState(() => jid = value);
                        },
                      ),
                      callback: jid.isEmpty
                          ? null
                          : () {
                              if (!Form.of(context).validate()) return;
                              context.read<BlocklistCubit>().block(jid: jid);
                            },
                    );
                  },
                ),
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
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) => state is BlocklistLoading && state.jid == null,
      builder: (context, disabled) {
        return ShadButton.destructive(
          enabled: !disabled,
          onPressed: () async {
            if ((await confirm(context) ?? false) && context.mounted) {
              context.read<BlocklistCubit>().unblockAll();
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
