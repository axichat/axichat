import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BlockMenuItem extends StatelessWidget {
  const BlockMenuItem({
    super.key,
    required this.jid,
  });

  final String jid;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) =>
          state is BlocklistLoading && (state.jid == jid || state.jid == null),
      builder: (context, disabled) {
        return ShadContextMenuItem(
          onPressed: disabled
              ? null
              : () => context.read<BlocklistCubit?>()?.block(jid: jid),
          leading: Icon(
            LucideIcons.userX,
            color: context.colorScheme.destructive,
          ),
          child: const Text('Block'),
        );
      },
    );
  }
}
