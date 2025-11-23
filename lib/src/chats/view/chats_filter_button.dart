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
    this.compact = false,
  });

  final bool compact;

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
    final selectedFilterId = context
            .watch<HomeSearchCubit?>()
            ?.state
            .stateFor(HomeTab.chats)
            .filterId ??
        chatsSearchFilters.first.id;
    final selectedFilter = chatsSearchFilters.firstWhere(
      (filter) => filter.id == selectedFilterId,
      orElse: () => chatsSearchFilters.first,
    );
    Widget trigger;
    if (widget.compact) {
      trigger = ShadButton.secondary(
        size: ShadButtonSize.sm,
        onPressed: popoverController.toggle,
        child: const Icon(LucideIcons.listFilter, size: 16),
      ).withTapBounce();
      trigger = AxiTooltip(
        builder: (_) => Text('Filter • ${selectedFilter.label}'),
        child: trigger,
      );
    } else {
      trigger = AxiTooltip(
        builder: (_) => Text('Filter • ${selectedFilter.label}'),
        child: ShadButton.secondary(
          onPressed: popoverController.toggle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.listFilter, size: 16),
              const SizedBox(width: 8),
              Text(selectedFilter.label),
            ],
          ),
        ).withTapBounce(),
      );
    }
    return ShadPopover(
      controller: popoverController,
      popover: (context) {
        return IntrinsicWidth(
          child: Material(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.listFilter, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        selectedFilter.label,
                        style: context.textTheme.small,
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: context.colorScheme.border,
                ),
                for (final option in chatsSearchFilters)
                  ShadButton.ghost(
                    width: double.infinity,
                    foregroundColor: option.id == selectedFilter.id
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
      child: trigger,
    );
  }
}
