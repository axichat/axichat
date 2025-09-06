import 'package:flutter/material.dart';

/// Helper class for responsive layout decisions based on screen width breakpoints.
class ResponsiveHelper {
  /// Mobile breakpoint: < 600px width
  static const double mobileBreakpoint = 600.0;

  /// Tablet breakpoint: 600-1200px width
  static const double tabletBreakpoint = 1200.0;

  /// Returns true if screen width is less than 600px (mobile)
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  /// Returns true if screen width is between 600-1200px (tablet)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Returns true if screen width is greater than 1200px (desktop)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  /// Returns appropriate layout based on screen size
  static T layoutBuilder<T>(
    BuildContext context, {
    required T mobile,
    required T tablet,
    required T desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }
}
