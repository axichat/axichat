import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/home/home_search_definitions.dart';
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
    final selectedFilter = context
            .watch<HomeSearchCubit?>()
            ?.state
            .stateFor(HomeTab.chats)
            .filterId ??
        chatsSearchFilters.first.id;
    return ShadPopover(
      controller: popoverController,
      popover: (context) {
        return IntrinsicWidth(
          child: Material(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in chatsSearchFilters)
                  ShadButton.ghost(
                    width: double.infinity,
                    foregroundColor: option.id == selectedFilter
                        ? context.colorScheme.primary
                        : context.colorScheme.foreground,
                    onPressed: () {
                      locate<HomeSearchCubit?>()
                          ?.updateFilter(option.id, tab: HomeTab.chats);
                      popoverController.toggle();
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(option.label),
                    ),
                  ).withTapBounce(),
              ],
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
