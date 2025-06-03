import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatsFilterButton extends StatefulWidget {
  const ChatsFilterButton({
    super.key,
  });

  @override
  State<ChatsFilterButton> createState() => _ChatsFilterButtonState();
}

class _ChatsFilterButtonState extends State<ChatsFilterButton> {
  late final ShadPopoverController popoverController;

  @override
  void initState() {
    super.initState();
    popoverController = ShadPopoverController();
  }

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    return ShadPopover(
      controller: popoverController,
      popover: (context) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(
              value: locate<ChatsCubit>(),
            ),
            BlocProvider.value(
              value: locate<RosterCubit>(),
            ),
          ],
          child: IntrinsicWidth(
            child: Material(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShadButton.ghost(
                    width: double.infinity,
                    foregroundColor: context.colorScheme.foreground,
                    onPressed: () {
                      context.read<ChatsCubit?>()?.filterChats((chat) => true);
                      popoverController.toggle();
                    },
                    child: const Text('All'),
                  ),
                  ShadButton.ghost(
                    width: double.infinity,
                    foregroundColor: context.colorScheme.foreground,
                    onPressed: () {
                      context.read<ChatsCubit?>()?.filterChats((chat) => context
                          .read<RosterCubit>()
                          .contacts
                          .contains(chat.jid));
                      popoverController.toggle();
                    },
                    child: const Text('Contacts'),
                  ),
                  ShadButton.ghost(
                    width: double.infinity,
                    foregroundColor: context.colorScheme.foreground,
                    onPressed: () {
                      context.read<ChatsCubit?>()?.filterChats((chat) =>
                          !context
                              .read<RosterCubit>()
                              .contacts
                              .contains(chat.jid));
                      popoverController.toggle();
                    },
                    child: const Text('Non-contacts'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: AxiTooltip(
        builder: (_) => const Text('Filter'),
        child: ShadButton.secondary(
          onPressed: popoverController.toggle,
          child: const Icon(LucideIcons.listFilter),
        ),
      ),
    );
  }
}
