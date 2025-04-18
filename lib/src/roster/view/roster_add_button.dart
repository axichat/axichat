import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RosterAddButton extends StatelessWidget {
  const RosterAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    return AxiTooltip(
      builder: (_) => const Text('Add to roster'),
      child: AxiFab(
        iconData: LucideIcons.userPlus,
        text: 'Contact',
        onPressed: () => showShadDialog(
          context: context,
          builder: (context) {
            String jid = '';
            String? title;
            return MultiBlocProvider(
              providers: [
                BlocProvider.value(
                  value: locate<RosterCubit>(),
                ),
                BlocProvider.value(
                  value: locate<AuthenticationCubit>(),
                ),
              ],
              child: StatefulBuilder(
                builder: (context, setState) {
                  return AxiInputDialog(
                    title: const Text('Add contact'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BlocConsumer<RosterCubit, RosterState>(
                          listener: (context, state) {
                            if (state is RosterSuccess && context.canPop()) {
                              context.pop();
                            }
                          },
                          builder: (context, state) {
                            return JidInput(
                              enabled: state is! RosterLoading,
                              error: state is! RosterFailure
                                  ? null
                                  : state.message,
                              jidOptions: [
                                '${jid.split('@').first}'
                                    '@${context.read<AuthenticationCubit>().state.server}'
                              ],
                              onChanged: (value) {
                                setState(() => jid = value);
                              },
                            );
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
                        : () => context
                            .read<RosterCubit>()
                            .addContact(jid: jid, title: title),
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
