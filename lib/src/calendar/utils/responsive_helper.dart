// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';

/// High level responsive buckets used across the calendar surfaces.
enum CalendarSizeClass { compact, medium, expanded }

/// Describes breakpoints and layout metrics for a given width range.
class CalendarResponsiveSpec {
  const CalendarResponsiveSpec({
    required this.sizeClass,
    required this.minWidth,
    this.maxWidth,
    required this.contentPadding,
    required this.modalMargin,
    required this.gridHorizontalPadding,
    required this.sidebarMinWidthFraction,
    required this.sidebarWidthFraction,
    required this.sidebarMaxWidthFraction,
    this.quickAddMaxWidth,
    this.quickAddMaxHeight = calendarQuickAddModalMaxHeight,
    this.dayColumnWidth,
  });

  final CalendarSizeClass sizeClass;
  final double minWidth;
  final double? maxWidth;
  final EdgeInsets contentPadding;
  final EdgeInsets modalMargin;
  final double gridHorizontalPadding;
  final double sidebarMinWidthFraction;
  final double sidebarWidthFraction;
  final double sidebarMaxWidthFraction;
  final double? quickAddMaxWidth;
  final double quickAddMaxHeight;
  final double? dayColumnWidth;

  bool containsWidth(double width) {
    final withinMin = width >= minWidth;
    final withinMax = maxWidth == null || width < maxWidth!;
    return withinMin && withinMax;
  }

  CalendarSidebarDimensions resolveSidebarDimensions(double screenWidth) {
    final double minWidth = (screenWidth * sidebarMinWidthFraction)
        .clamp(calendarSidebarMinWidth, screenWidth)
        .toDouble();
    final double maxWidth = (screenWidth * sidebarMaxWidthFraction)
        .clamp(minWidth, screenWidth)
        .toDouble();
    final double defaultWidth = (screenWidth * sidebarWidthFraction)
        .clamp(minWidth, maxWidth)
        .toDouble();
    return CalendarSidebarDimensions(
      minWidth: minWidth,
      maxWidth: maxWidth,
      defaultWidth: defaultWidth,
    );
  }

  double resolveDayColumnWidth(double fallback) => dayColumnWidth ?? fallback;
}

class CalendarSidebarDimensions {
  const CalendarSidebarDimensions({
    required this.minWidth,
    required this.maxWidth,
    required this.defaultWidth,
  });

  final double minWidth;
  final double maxWidth;
  final double defaultWidth;
}

/// Helper class for responsive layout decisions based on shared descriptors.
class ResponsiveHelper {
  static List<CalendarResponsiveSpec> _specs(AxiSpacing spacing) => [
        CalendarResponsiveSpec(
          sizeClass: CalendarSizeClass.compact,
          minWidth: calendarViewModeMinWidth - calendarViewModeMinWidth,
          maxWidth: smallScreen,
          contentPadding: EdgeInsets.symmetric(
            horizontal: spacing.m,
            vertical: spacing.s,
          ),
          modalMargin: EdgeInsets.all(spacing.m),
          gridHorizontalPadding: spacing.s,
          sidebarMinWidthFraction: 1.0,
          sidebarWidthFraction: 1.0,
          sidebarMaxWidthFraction: 1.0,
          quickAddMaxWidth: calendarQuickAddModalCompactMaxWidth,
          dayColumnWidth: calendarCompactDayColumnWidth,
        ),
        CalendarResponsiveSpec(
          sizeClass: CalendarSizeClass.medium,
          minWidth: smallScreen,
          maxWidth: largeScreen,
          contentPadding: EdgeInsets.symmetric(
            horizontal: spacing.m,
            vertical: spacing.m,
          ),
          modalMargin: EdgeInsets.all(spacing.m),
          gridHorizontalPadding: 0,
          sidebarMinWidthFraction: calendarSidebarWidthMinFraction,
          sidebarWidthFraction: calendarSidebarWidthDefaultFraction,
          sidebarMaxWidthFraction: calendarSidebarWidthMaxFraction,
          quickAddMaxWidth: calendarQuickAddModalMaxWidth,
        ),
        CalendarResponsiveSpec(
          sizeClass: CalendarSizeClass.expanded,
          minWidth: largeScreen,
          contentPadding: EdgeInsets.symmetric(
            horizontal: spacing.m,
            vertical: spacing.m,
          ),
          modalMargin: EdgeInsets.all(spacing.m),
          gridHorizontalPadding: 0,
          sidebarMinWidthFraction: calendarSidebarWidthMinFraction,
          sidebarWidthFraction: calendarSidebarWidthDefaultFraction,
          sidebarMaxWidthFraction: calendarSidebarWidthMaxFraction,
          quickAddMaxWidth: calendarQuickAddModalMaxWidth,
        ),
      ];

  /// Returns the responsive specification for the current screen width.
  static CalendarResponsiveSpec spec(BuildContext context) =>
      specForWidth(MediaQuery.of(context).size.width, context.spacing);

  /// Returns the responsive specification for an arbitrary width.
  static CalendarResponsiveSpec specForWidth(
    double width,
    AxiSpacing spacing,
  ) {
    final specs = _specs(spacing);
    for (final candidate in specs) {
      if (candidate.containsWidth(width)) {
        return candidate;
      }
    }
    return specs.last;
  }

  /// Returns the descriptor for a specific size class.
  static CalendarResponsiveSpec specForSizeClass(
    BuildContext context,
    CalendarSizeClass sizeClass,
  ) {
    final specs = _specs(context.spacing);
    return specs.firstWhere(
      (spec) => spec.sizeClass == sizeClass,
      orElse: () => specs.last,
    );
  }

  /// Whether the current width maps to the compact (mobile) size class.
  static bool isCompact(BuildContext context) =>
      spec(context).sizeClass == CalendarSizeClass.compact;

  /// Whether the current width maps to the medium (tablet) size class.
  static bool isMedium(BuildContext context) =>
      spec(context).sizeClass == CalendarSizeClass.medium;

  /// Whether the current width maps to the expanded (desktop) size class.
  static bool isExpanded(BuildContext context) =>
      spec(context).sizeClass == CalendarSizeClass.expanded;

  /// Legacy alias retained while the codebase migrates to the new helpers.
  static bool isMobile(BuildContext context) => isCompact(context);

  /// Legacy alias retained while the codebase migrates to the new helpers.
  static bool isTablet(BuildContext context) => isMedium(context);

  /// Legacy alias retained while the codebase migrates to the new helpers.
  static bool isDesktop(BuildContext context) => isExpanded(context);

  /// Returns appropriate layout based on the active size class.
  static T layoutBuilder<T>(
    BuildContext context, {
    required T mobile,
    required T tablet,
    required T desktop,
  }) {
    final spec = ResponsiveHelper.spec(context);
    switch (spec.sizeClass) {
      case CalendarSizeClass.compact:
        return mobile;
      case CalendarSizeClass.medium:
        return tablet;
      case CalendarSizeClass.expanded:
        return desktop;
    }
  }

  static CalendarSidebarDimensions sidebarDimensions(BuildContext context) {
    final spec = ResponsiveHelper.spec(context);
    final double width = MediaQuery.of(context).size.width;
    return spec.resolveSidebarDimensions(width);
  }

  static CalendarSidebarDimensions sidebarDimensionsForWidth(
    double width,
    AxiSpacing spacing,
  ) =>
      specForWidth(width, spacing).resolveSidebarDimensions(width);

  static double dayColumnWidth(
    BuildContext context, {
    double fallback = calendarCompactDayColumnWidth,
  }) =>
      spec(context).resolveDayColumnWidth(fallback);

  static double dayColumnWidthForWidth(
    double width, {
    double fallback = calendarCompactDayColumnWidth,
    required AxiSpacing spacing,
  }) =>
      specForWidth(width, spacing).resolveDayColumnWidth(fallback);
}
