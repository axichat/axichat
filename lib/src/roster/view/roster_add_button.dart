import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/roster/bloc/roster_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RosterAddButton extends StatelessWidget {
  const RosterAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    return FloatingActionButton(
      tooltip: 'Add to roster',
      child: const Icon(Icons.person_add),
      onPressed: () => showDialog(
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
                        labelText: 'JID',
                        hintText: 'friend@axi.im',
                        onChanged: (value) {
                          setState(() => jid = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      AxiTextFormField(
                        labelText: 'Nickname (optional)',
                        onChanged: (value) {
                          setState(() => title = value);
                        },
                      ),
                    ],
                  ),
                  callback: () => jid.isEmpty
                      ? null
                      : context
                          .read<RosterBloc>()
                          .add(RosterSubscriptionAdded(jid: jid, title: title)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
