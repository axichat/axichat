import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/roster/bloc/roster_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RosterAddButton extends StatelessWidget {
  const RosterAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    return ShadTooltip(
      builder: (_) => const Text('Add to roster'),
      child: FloatingActionButton(
        child: const Icon(LucideIcons.userPlus),
        onPressed: () => showShadDialog(
          context: context,
          builder: (context) {
            String jid = '';
            String? title;
            return BlocProvider.value(
              value: locate<RosterBloc>(),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return AxiInputDialog(
                    title: const Text('Add contact'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AxiTextFormField(
                          placeholder: const Text('JID'),
                          description: const Text('Example: friend@axi.im'),
                          onChanged: (value) {
                            setState(() => jid = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        AxiTextFormField(
                          placeholder: const Text('Nickname (optional)'),
                          onChanged: (value) {
                            setState(() => title = value);
                          },
                        ),
                      ],
                    ),
                    callback: () => jid.isEmpty
                        ? null
                        : context.read<RosterBloc>().add(
                            RosterSubscriptionAdded(jid: jid, title: title)),
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
