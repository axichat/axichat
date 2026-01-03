// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

/// Shared scaffold for the mobile calendar view. Hosts the tab header, the
/// drag overlays, and the schedule/tasks TabBarView panes so both the guest
/// and authenticated experiences can reuse the same chrome.
class CalendarMobileSplitScaffold extends StatelessWidget {
  const CalendarMobileSplitScaffold({
    super.key,
    required this.tabController,
    required this.primaryPane,
    required this.secondaryPane,
    required this.dragOverlay,
    required this.tabBar,
    required this.headerBuilder,
    this.safeAreaTop = false,
    this.safeAreaBottom = false,
  });

  final TabController tabController;
  final Widget primaryPane;
  final Widget secondaryPane;
  final Widget dragOverlay;
  final Widget tabBar;
  final Widget Function(BuildContext context, bool showingPrimaryTab)
      headerBuilder;
  final bool safeAreaTop;
  final bool safeAreaBottom;

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: tabController,
          builder: (context, _) {
            final bool showingPrimary = tabController.index == 0;
            return headerBuilder(context, showingPrimary);
          },
        ),
        Expanded(
          child: Stack(
            children: [
              TabBarView(
                controller: tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  primaryPane,
                  secondaryPane,
                ],
              ),
              dragOverlay,
            ],
          ),
        ),
        tabBar,
      ],
    );

    if (safeAreaTop || safeAreaBottom) {
      content = SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        child: content,
      );
    }

    return content;
  }
}

/// Shared scaffold for the desktop calendar view. Keeps the sidebar and grid
/// layout identical for the guest and authenticated surfaces while allowing
/// each host to inject its own navigation/error chrome.
class CalendarDesktopSplitScaffold extends StatelessWidget {
  const CalendarDesktopSplitScaffold({
    super.key,
    required this.sidebar,
    required this.content,
    this.topHeader,
    this.bodyHeader,
  });

  final Widget sidebar;
  final Widget content;
  final Widget? topHeader;
  final Widget? bodyHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topHeader != null) topHeader!,
        Expanded(
          child: Row(
            children: [
              sidebar,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (bodyHeader != null) bodyHeader!,
                    Expanded(child: content),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
