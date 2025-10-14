import 'package:flutter/material.dart';

import '../../common/ui/ui.dart';

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
    required this.sidebarWidthFraction,
    this.quickAddMaxWidth,
    this.quickAddMaxHeight = calendarQuickAddModalMaxHeight,
  });

  final CalendarSizeClass sizeClass;
  final double minWidth;
  final double? maxWidth;
  final EdgeInsets contentPadding;
  final EdgeInsets modalMargin;
  final double gridHorizontalPadding;
  final double sidebarWidthFraction;
  final double? quickAddMaxWidth;
  final double quickAddMaxHeight;

  bool containsWidth(double width) {
    final withinMin = width >= minWidth;
    final withinMax = maxWidth == null || width < maxWidth!;
    return withinMin && withinMax;
  }
}

/// Helper class for responsive layout decisions based on shared descriptors.
class ResponsiveHelper {
  static const List<CalendarResponsiveSpec> _specs = [
    CalendarResponsiveSpec(
      sizeClass: CalendarSizeClass.compact,
      minWidth: 0,
      maxWidth: smallScreen,
      contentPadding: EdgeInsets.symmetric(
        horizontal: calendarSpacing12,
        vertical: calendarSpacing8,
      ),
      modalMargin: calendarPadding12,
      gridHorizontalPadding: calendarSpacing8,
      sidebarWidthFraction: 1.0,
      quickAddMaxWidth: calendarQuickAddModalCompactMaxWidth,
    ),
    CalendarResponsiveSpec(
      sizeClass: CalendarSizeClass.medium,
      minWidth: smallScreen,
      maxWidth: largeScreen,
      contentPadding: EdgeInsets.symmetric(
        horizontal: calendarSpacing16,
        vertical: calendarSpacing12,
      ),
      modalMargin: calendarPadding16,
      gridHorizontalPadding: calendarSpacing12,
      sidebarWidthFraction: calendarSidebarWidthDefaultFraction,
      quickAddMaxWidth: calendarQuickAddModalMaxWidth,
    ),
    CalendarResponsiveSpec(
      sizeClass: CalendarSizeClass.expanded,
      minWidth: largeScreen,
      contentPadding: EdgeInsets.symmetric(
        horizontal: calendarSpacing16,
        vertical: calendarSpacing16,
      ),
      modalMargin: calendarPadding16,
      gridHorizontalPadding: calendarSpacing16,
      sidebarWidthFraction: calendarSidebarWidthDefaultFraction,
      quickAddMaxWidth: calendarQuickAddModalMaxWidth,
    ),
  ];

  /// Returns the responsive specification for the current screen width.
  static CalendarResponsiveSpec spec(BuildContext context) =>
      specForWidth(MediaQuery.of(context).size.width);

  /// Returns the responsive specification for an arbitrary width.
  static CalendarResponsiveSpec specForWidth(double width) {
    for (final candidate in _specs) {
      if (candidate.containsWidth(width)) {
        return candidate;
      }
    }
    return _specs.last;
  }

  /// Returns the descriptor for a specific size class.
  static CalendarResponsiveSpec specForSizeClass(
    CalendarSizeClass sizeClass,
  ) {
    return _specs.firstWhere(
      (spec) => spec.sizeClass == sizeClass,
      orElse: () => _specs.last,
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
}
