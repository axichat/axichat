// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/home/bloc/home_bloc.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatsFilterButton extends StatefulWidget {
  const ChatsFilterButton({
    super.key,
    required this.locate,
    this.compact = false,
  });

  final T Function<T>() locate;
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
    return BlocBuilder<HomeBloc, HomeState>(
      bloc: widget.locate<HomeBloc>(),
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
          trigger = AxiIconButton.outline(
            iconData: LucideIcons.listFilter,
            iconSize: iconSize,
            tooltip: tooltip,
            onPressed: popoverController.toggle,
          );
        } else {
          trigger = AxiButton.secondary(
            onPressed: popoverController.toggle,
            tooltip: tooltip,
            leading: Icon(LucideIcons.listFilter, size: iconSize),
            child: Text(selectedFilter.label),
          );
        }
        return AxiPopover(
          controller: popoverController,
          closeOnTapOutside: true,
          padding: EdgeInsets.zero,
          decoration: ShadDecoration.none,
          shadows: const <BoxShadow>[],
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
                      widget.locate<HomeBloc>().add(
                        HomeSearchFilterChanged(option.id, tab: HomeTab.chats),
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
