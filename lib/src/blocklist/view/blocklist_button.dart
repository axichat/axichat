import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BlocklistAddButton extends StatelessWidget {
  const BlocklistAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    return AxiTooltip(
      builder: (_) => const Text('Add to blocklist'),
      child: AxiFab(
        iconData: LucideIcons.userX,
        text: 'Block',
        onPressed: () => showShadDialog(
          context: context,
          builder: (context) {
            String jid = '';
            return MultiBlocProvider(
              providers: [
                BlocProvider.value(
                  value: locate<BlocklistCubit>(),
                ),
                BlocProvider.value(
                  value: locate<RosterCubit>(),
                ),
              ],
              child: StatefulBuilder(
                builder: (context, setState) {
                  return AxiInputDialog(
                    title: const Text('Block user'),
                    content: BlocConsumer<BlocklistCubit, BlocklistState>(
                      listener: (context, state) {
                        if (state is BlocklistSuccess) {
                          context.pop();
                        }
                      },
                      builder: (context, state) {
                        return JidInput(
                          enabled: state is! BlocklistLoading,
                          error:
                              state is! BlocklistFailure ? null : state.message,
                          jidOptions:
                              locate<RosterCubit?>()?.contacts.toList() ?? [],
                          onChanged: (value) {
                            setState(() => jid = value);
                          },
                        );
                      },
                    ),
                    callback: jid.isEmpty
                        ? null
                        : () =>
                            context.read<BlocklistCubit?>()?.block(jid: jid),
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
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) => state is BlocklistLoading && state.jid == null,
      builder: (context, disabled) {
        return ShadButton.destructive(
          enabled: !disabled,
          onPressed: () async {
            if (await confirm(context) != true) return;
            if (context.mounted) {
              context.read<BlocklistCubit?>()?.unblockAll();
            }
          },
          leading: disabled
              ? AxiProgressIndicator(
                  color: context.colorScheme.foreground,
                  semanticsLabel: 'Waiting for unblock',
                )
              : null,
          child: const Text('Unblock all'),
        ).withTapBounce(enabled: !disabled);
      },
    );
  }
}
