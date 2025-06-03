import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BlockButtonInline extends StatelessWidget {
  const BlockButtonInline({
    super.key,
    required this.jid,
    this.callback,
    this.showIcon = false,
    this.mainAxisAlignment,
  });

  final String jid;
  final void Function()? callback;
  final bool showIcon;
  final MainAxisAlignment? mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) =>
          state is BlocklistLoading && (state.jid == jid || state.jid == null),
      builder: (context, disabled) {
        return ShadButton.ghost(
          width: double.infinity,
          mainAxisAlignment: mainAxisAlignment,
          onPressed: disabled
              ? null
              : () {
                  context.read<BlocklistCubit?>()?.block(jid: jid);
                  if (callback != null) {
                    callback!();
                  }
                },
          foregroundColor: context.colorScheme.destructive,
          leading: showIcon
              ? const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(LucideIcons.userX),
                )
              : null,
          child: const Text('Block'),
        );
      },
    );
  }
}
