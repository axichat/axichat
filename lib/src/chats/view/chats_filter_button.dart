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
  const ChatsFilterButton({super.key, this.compact = false});

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
    return BlocBuilder<HomeSearchCubit, HomeSearchState>(
      builder: (context, searchState) {
        final l10n = context.l10n;
        final sizing = context.sizing;
        final filters = chatsSearchFilters(l10n);
        final selectedFilterId =
            searchState.stateFor(HomeTab.chats).filterId ?? filters.first.id;
        final selectedFilter = filters.firstWhere(
          (filter) => filter.id == selectedFilterId,
          orElse: () => filters.first,
        );
        final tooltip = l10n.filterTooltip(selectedFilter.label);
        final iconSize = sizing.menuItemIconSize;
        Widget trigger;
        if (widget.compact) {
          trigger = AxiIconButton.secondary(
            iconData: LucideIcons.listFilter,
            iconSize: iconSize,
            tooltip: tooltip,
            onPressed: popoverController.toggle,
          );
        } else {
          trigger = AxiTooltip(
            builder: (_) => Text(tooltip),
            child: AxiButton.secondary(
              onPressed: popoverController.toggle,
              leading: Icon(LucideIcons.listFilter, size: iconSize),
              child: Text(selectedFilter.label),
            ),
          );
        }
        return AxiPopover(
          controller: popoverController,
          closeOnTapOutside: true,
          padding: EdgeInsets.zero,
          popover: (context) {
            return AxiMenu(
              actions: [
                for (final option in filters)
                  AxiMenuAction(
                    icon: option.id == selectedFilter.id
                        ? LucideIcons.check
                        : null,
                    label: option.label,
                    onPressed: () {
                      context.read<HomeSearchCubit>().updateFilter(
                            option.id,
                            tab: HomeTab.chats,
                          );
                      popoverController.hide();
                    },
                  ),
              ],
            );
          },
          child: trigger,
        );
      },
    );
  }
}
