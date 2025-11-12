import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/storage/models.dart';
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
                  for (final option in _filterOptions(
                    context,
                    context.read<RosterCubit?>(),
                  ))
                    ShadButton.ghost(
                      width: double.infinity,
                      foregroundColor: context.colorScheme.foreground,
                      onPressed: () {
                        context
                            .read<ChatsCubit?>()
                            ?.filterChats(option.predicate);
                        popoverController.toggle();
                      },
                      child: Text(option.label),
                    ).withTapBounce(),
                ],
              ),
            ),
          ),
        );
      },
      child: AxiTooltip(
        builder: (_) => const Text('Filter'),
        child: ShadIconButton.secondary(
          onPressed: popoverController.toggle,
          icon: const Icon(LucideIcons.listFilter),
        ).withTapBounce(),
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption(this.label, this.predicate);

  final String label;
  final bool Function(Chat) predicate;
}

List<_FilterOption> _filterOptions(
  BuildContext context,
  RosterCubit? rosterCubit,
) {
  final contacts = rosterCubit?.contacts ?? const <String>[];
  final contactSet = contacts is Set<String> ? contacts : contacts.toSet();
  return [
    _FilterOption('All', (chat) => !chat.hidden),
    _FilterOption(
      'Contacts',
      (chat) => !chat.hidden && contactSet.contains(chat.jid),
    ),
    _FilterOption(
      'Non-contacts',
      (chat) => !chat.hidden && !contactSet.contains(chat.jid),
    ),
    _FilterOption(
      'XMPP only',
      (chat) => !chat.hidden && chat.transport.isXmpp,
    ),
    _FilterOption(
      'Email only',
      (chat) => !chat.hidden && chat.transport.isEmail,
    ),
    _FilterOption(
      'Hidden',
      (chat) => chat.hidden,
    ),
  ];
}
