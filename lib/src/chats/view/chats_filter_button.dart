// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/home/home_search_definitions.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
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
    final l10n = context.l10n;
    final filters = chatsSearchFilters(l10n);
    final selectedFilterId = context
            .watch<HomeSearchCubit?>()
            ?.state
            .stateFor(HomeTab.chats)
            .filterId ??
        filters.first.id;
    final selectedFilter = filters.firstWhere(
      (filter) => filter.id == selectedFilterId,
      orElse: () => filters.first,
    );
    Widget trigger;
    if (widget.compact) {
      trigger = ShadButton.secondary(
        size: ShadButtonSize.sm,
        onPressed: popoverController.toggle,
        child: const Icon(LucideIcons.listFilter, size: 16),
      ).withTapBounce();
      trigger = AxiTooltip(
        builder: (_) => Text(l10n.filterTooltip(selectedFilter.label)),
        child: trigger,
      );
    } else {
      trigger = AxiTooltip(
        builder: (_) => Text(l10n.filterTooltip(selectedFilter.label)),
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
      closeOnTapOutside: true,
      padding: EdgeInsets.zero,
      popover: (context) {
        return AxiMenu(
          actions: [
            for (final option in filters)
              AxiMenuAction(
                icon: option.id == selectedFilter.id ? LucideIcons.check : null,
                label: option.label,
                onPressed: () {
                  locate<HomeSearchCubit?>()
                      ?.updateFilter(option.id, tab: HomeTab.chats);
                  popoverController.hide();
                },
              ),
          ],
        );
      },
      child: trigger,
    );
  }
}
