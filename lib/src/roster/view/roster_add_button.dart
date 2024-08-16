import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/roster/bloc/roster_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RosterAddButton extends StatelessWidget {
  const RosterAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    return AxiTooltip(
      builder: (_) => const Text('Add to roster'),
      child: FloatingActionButton(
        child: const Icon(LucideIcons.userPlus),
        onPressed: () => showShadDialog(
          context: context,
          builder: (context) {
            String jid = '';
            String? title;
            return BlocProvider.value(
              value: locate<RosterCubit>(),
              child: Form(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return AxiInputDialog(
                      title: const Text('Add contact'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          JidInput(
                            onChanged: (value) {
                              setState(() => jid = value);
                            },
                          ),
                          // const SizedBox(height: 12),
                          // AxiTextFormField(
                          //   placeholder: const Text('Nickname (optional)'),
                          //   onChanged: (value) {
                          //     setState(() => title = value);
                          //   },
                          // ),
                        ],
                      ),
                      callback: jid.isEmpty
                          ? null
                          : () {
                              if (!Form.of(context).validate()) return;
                              context
                                  .read<RosterCubit>()
                                  .addContact(jid: jid, title: title);
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
