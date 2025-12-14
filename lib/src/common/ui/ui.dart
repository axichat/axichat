import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

export 'axi_adaptive_layout.dart';
export 'axi_app_bar.dart';
export 'axi_context_menu_region.dart';
export 'axi_avatar.dart';
export 'axi_badge.dart';
export 'axi_navigation_rail.dart';
export 'axi_confirm.dart';
export 'axi_checkbox_form_field.dart';
export 'axi_cutout.dart';
export 'axi_dialog_fab.dart';
export 'axi_delete_menu_item.dart';
export 'axi_fab.dart';
export 'axi_icon_button.dart';
export 'axi_input_dialog.dart';
export 'axi_link.dart';
export 'axi_list_divider.dart';
export 'axi_list_tile.dart';
export 'axi_more.dart';
export 'axi_menu.dart';
export 'axi_progress_indicator.dart';
export 'axi_text_form_field.dart';
export 'axi_tooltip.dart';
export 'axi_transport_chip.dart';
export 'axi_tap_bounce.dart';
export 'axi_animated_size.dart';
export 'axi_version.dart';
export 'cutout.dart';
export 'selection_indicator.dart';
export 'display_fingerprint.dart';
export 'display_time_since.dart';
export 'axi_tab_bar.dart';
export 'dynamic_inline_text.dart';
export 'jid_input.dart';
export 'list_item_padding.dart';
export 'password_input.dart';
export 'presence_indicator.dart';
export 'string_to_color.dart';
export 'squircle_border.dart';
export 'axi_adaptive_sheet.dart';

const appDisplayName = 'axichat';
const androidIconPath = 'app_icon';

const emojiFontFamily = 'NotoColorEmoji';
const emojiFontFallback = <String>[emojiFontFamily];
const dmSansFontFamily = 'DMSans';
const dmSansFontFallback = <String>[emojiFontFamily];
const dmSansOpticalSizeAxis = 'opsz';
const dmSansDefaultOpticalSize = 16.0;
const dmSansMinOpticalSize = 9.0;
const dmSansMaxOpticalSize = 40.0;
const dmSansWeightAxis = 'wght';
const dmSansDefaultWeight = 600.0;
const dmSansMinWeight = 400.0;
const dmSansMaxWeight = 700.0;
const interFontFamily = 'Inter';
const interFontFallback = <String>[dmSansFontFamily, emojiFontFamily];
const gabaritoFontFamily = 'Gabarito';
const gabaritoFontFallback = <String>[
  interFontFamily,
  dmSansFontFamily,
  emojiFontFamily,
];

extension ModalTypography on BuildContext {
  TextStyle get modalHeaderTextStyle {
    final ShadTextTheme theme = ShadTheme.of(this).textTheme;
    final ShadColorScheme colors = ShadTheme.of(this).colorScheme;
    return theme.h3.copyWith(color: colors.foreground);
  }
}

const smallScreen = 820.0;
const mediumScreen = 900.0;
const largeScreen = 1200.0;
const compactDeviceBreakpoint = 600.0;

const baseAnimationDuration = Duration(milliseconds: 300);

/// Duration for cross-fading calendar view transitions.
const calendarViewTransitionDuration = Duration(milliseconds: 400);
const double calendarViewModeMinWidth = 120.0;
const calendarClockTickInterval = Duration(minutes: 1);
const calendarDragWidthDebounceDelay = Duration(milliseconds: 120);
const calendarTaskSplitPreviewAnimationDuration = Duration(milliseconds: 120);
const calendarScrollAnimationDuration = Duration(milliseconds: 250);
const calendarSlotHoverAnimationDuration = Duration(milliseconds: 200);
const basePageItemLimit = 15;

const axiGreen = Color(0xff80ffa0);

class CalendarPalette {
  CalendarPalette._();

  static Color _primary = const Color(0xFF0969DA);
  static Color _primaryHover = const Color(0xFF0860CA);

  static Color get primary => _primary;
  static Color get primaryHover => _primaryHover;

  static void update({
    required ShadColorScheme scheme,
    required Brightness brightness,
  }) {
    _primary = scheme.primary;
    final mixTarget =
        brightness == Brightness.dark ? Colors.white : Colors.black;
    _primaryHover = Color.lerp(_primary, mixTarget, 0.12) ?? _primary;
  }
}

Color get calendarPrimaryColor => CalendarPalette.primary;
Color get calendarPrimaryHoverColor => CalendarPalette.primaryHover;
// Ultrathink calendar color palette
const calendarBackgroundColor = Color(0xFFFFFFFF);
const calendarContainerColor = Color(0xFFFFFFFF);
const calendarSidebarBackgroundColor = Color(0xFFF7F8FA);
const calendarBorderColor = Color(0xFFE1E4E8);
const calendarBorderDarkColor = Color(0xFFD1D5DA);
const calendarBorderLightColor = Color(0xFFF0F0F0);
const calendarSelectedDayColor = Color(0xFFF6F8FA);
const calendarSlotHoverColor = Color(0xFFE8F1FF);

// Typography colors
const calendarTitleColor = Color(0xFF24292E);
const calendarSubtitleColor = Color(0xFF6A737D);
const calendarTextLightColor = Color(0xFF959DA5);
const calendarTimeLabelColor = Color(0xFF6A737D);

// Status colors for task priorities
const calendarSuccessColor = Color(0xFF28A745);
const calendarDangerColor = Color(0xFFDC3545);
const calendarWarningColor = Color(0xFFFD7E14);
const calendarYellowColor = Color(0xFFFFC107);
const calendarNeutralColor = Color(0xFF9CA3AF);

// Sidebar specific colors
const sidebarBackgroundColor = Color(0xFFF7F8FA);

// Complete shadow system for visual hierarchy
const calendarLightShadow = [
  BoxShadow(
    color: Color(0x10000000), // rgba(0,0,0,0.06)
    blurRadius: 6,
    offset: Offset(0, 1),
  ),
];

const calendarMediumShadow = [
  BoxShadow(
    color: Color(0x18000000), // rgba(0,0,0,0.09)
    blurRadius: 12,
    offset: Offset(0, 2),
  ),
];

const calendarStrongShadow = [
  BoxShadow(
    color: Color(0x20000000), // rgba(0,0,0,0.12)
    blurRadius: 16,
    offset: Offset(0, 4),
  ),
];

// Elevation levels
const calendarElevation1 = calendarLightShadow; // Cards, containers
const calendarElevation2 = calendarMediumShadow; // Floating elements
const calendarElevation3 = calendarStrongShadow; // Modals, dropdowns

// Clean spacing constants
const calendarBorderRadius = 6.0;
const calendarEventRadius = 4.0;
const calendarHeaderHeight = 44.0;
const calendarDayHeaderHeight = 20.0;
const calendarTimeSlotHeight = 60.0;
const calendarSlotHoverOpacity = 0.05;
const calendarSlotPreviewOpacity = 0.12;
const calendarSlotPreviewAnchorOpacity = 0.2;
const calendarSplitPreviewBorderOpacity = 0.6;
const calendarSlotSplashOpacity = 0.2;
const calendarSlotHighlightOpacity = 0.1;
const calendarTaskGhostOpacity = 0.45;
const calendarSplitPreviewGhostOpacity = 0.55;
const calendarSplitPreviewBaseFadeOpacity = 0.28;
const calendarZoomControlsBackgroundOpacity = 0.95;
const calendarDayHeaderHighlightOpacity = 0.05;
const calendarTimeDividerOpacity = 0.3;
const calendarTodayColumnHighlightOpacity = 0.03;
const calendarTodaySlotLightOpacity = 0.01;
const calendarTodaySlotDarkOpacity = 0.02;
const calendarStripedSlotColor = Color(0xFFFAFBFC);
const calendarDayHeaderLetterSpacing = 0.5;

// Standard spacing values
// Insets handle tight adjustments inside components, while gutters separate larger regions.
const calendarInsetSm = 2.0;
const calendarInsetMd = 4.0;
const calendarInsetLg = 6.0;
const calendarGutterSm = 8.0;
const calendarGutterMd = 12.0;
const calendarGutterLg = 16.0;
// Dedicated form spacing between stacked controls.
const calendarCheckboxTapTarget = 36.0;
const calendarFormGap = 10.0;
const calendarTaskDetailGap = 3.0;
const calendarCompactDayColumnWidth = 120.0;
const calendarRecurrenceEndGap = 14.0;
const calendarRecurrenceFieldGap = calendarGutterMd;
const calendarRecurrenceCompactFieldGap = 14.0;
const calendarRecurrenceCompactWeekdayGap = calendarFormGap;

// Event layout constraints
const calendarEventMinHeight = 20.0;
const calendarEventMinWidth = 32.0;
const calendarTaskColumnInset = 6.0;
const calendarTaskColumnGap = 0.0;
const calendarDayViewDefaultHourHeight = 192.0;
const calendarDayViewDefaultSubdivisions = 4;
const calendarVisibleHourRows = 25;

// Structural layout metrics
const calendarWeekHeaderHeight = 40.0;
const calendarBorderStroke = 1.0;
const calendarSubSlotBorderStroke = 0.5;

// Popover and overlay geometry
/// Fixed width for task popovers so layout matches legacy design.
const calendarTaskPopoverWidth = 360.0;

/// Maximum height before scrollbars appear for calendar grid popovers.
const calendarGridPopoverMaxHeight = 728.0;

/// Maximum height for sidebar popovers which have a slightly smaller viewport.
const calendarSidebarPopoverMaxHeight = 644.0;

/// Fallback height while popover size is measured asynchronously.
const calendarTaskPopoverFallbackHeight = 560.0;

/// Minimum usable height for popovers to prevent truncated controls.
const calendarTaskPopoverMinHeight = 160.0;

/// Safe margin between popovers and the screen edge for pointer affordances.
const calendarPopoverScreenMargin = 16.0;

/// Desired vertical gap between a task tile and its overlay content.
const calendarPopoverPreferredVerticalGap = 8.0;

/// Desired horizontal gap between a task tile and its overlay content.
const calendarPopoverPreferredHorizontalGap = 12.0;

// Quick add modal sizing
/// Maximum width the quick add modal can occupy on desktop breakpoints.
const calendarQuickAddModalMaxWidth = 400.0;

/// Maximum height the quick add modal can occupy before scrolling.
const calendarQuickAddModalMaxHeight = 540.0;

/// Maximum width for the quick add modal on compact layouts.
const calendarQuickAddModalCompactMaxWidth = 360.0;

// Device-specific layout tokens
/// Collapsed task sidebar height when rendered on phones.
const calendarMobileSidebarHeight = 200.0;

// Standard EdgeInsets
const calendarPaddingSm = EdgeInsets.all(4.0);
const calendarPaddingMd = EdgeInsets.all(8.0);
const calendarPaddingLg = EdgeInsets.all(12.0);
const calendarPaddingXl = EdgeInsets.all(16.0);

// Purpose-specific paddings for shared surfaces.
const calendarMenuItemPadding =
    EdgeInsets.symmetric(horizontal: 14, vertical: 12);
const calendarFieldPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 10);
const calendarActionButtonPadding =
    EdgeInsets.symmetric(horizontal: 14, vertical: 14);
const calendarAccordionPadding =
    EdgeInsets.fromLTRB(14, 6, 14, calendarFormGap);

const calendarMarginSmall = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
const calendarMarginMedium = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
const calendarMarginLarge = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

// Sidebar layout metrics
const calendarSidebarMinWidth = 220.0;
const calendarSidebarWidthMinFraction = 0.25;
const calendarSidebarWidthDefaultFraction = 0.33;
const calendarSidebarWidthMaxFraction = 0.5;
const calendarSidebarScrollbarThickness = 6.0;
const calendarSidebarScrollbarRadius = 8.0;
const calendarSidebarSectionPadding = EdgeInsets.all(20.0);
const calendarSidebarSectionSpacing = 16.0;
const calendarSidebarToggleSpacing = 12.0;
const calendarSidebarScrollPadding = EdgeInsets.only(bottom: 24.0);
const calendarSidebarAdvancedAnimationDuration = Duration(milliseconds: 220);

// Sidebar completion tile metrics
const calendarCompletionTileBorderRadius = 10.0;
const calendarCompletionTilePaddingHorizontal = 12.0;
const calendarCompletionTilePaddingVertical = 10.0;
const calendarCompletionTileActiveBorderWidth = 2.0;
const calendarCompletionTileInactiveBorderWidth = 1.0;
const calendarCompletionTileGap = 10.0;
const calendarSidebarToggleDuration = Duration(milliseconds: 180);

// Zoom control metrics
const calendarZoomControlsElevation = 3.0;
const calendarZoomControlsBorderRadius = 24.0;
const calendarZoomControlsPaddingHorizontal = 6.0;
const calendarZoomControlsPaddingVertical = 2.0;
const calendarZoomControlsLabelPaddingHorizontal = 8.0;
const calendarZoomControlsIconSize = 18.0;
const calendarZoomLabelTextStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.4,
);

// Typography constants - Complete hierarchy system
const calendarTitleTextStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w600,
  color: calendarTitleColor,
  letterSpacing: -0.4,
);

const calendarSubtitleTextStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w400,
  color: calendarSubtitleColor,
  letterSpacing: -0.1,
);

const calendarTimeLabelTextStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w400,
  color: calendarTimeLabelColor,
);

const calendarMinorTimeLabelTextStyle = TextStyle(
  fontSize: 9,
  fontWeight: FontWeight.w500,
  color: calendarTimeLabelColor,
);

// Additional typography hierarchy
const calendarHeaderTextStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: calendarTitleColor,
  letterSpacing: -0.2,
);

const calendarBodyTextStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: calendarTitleColor,
  letterSpacing: -0.1,
);

const calendarCaptionTextStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: calendarSubtitleColor,
  letterSpacing: 0.0,
);

// Task-specific typography - updated to match target design
const taskTitleTextStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: 0.1,
);

const taskTitleCompactTextStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: 0.1,
);

const taskDescriptionTextStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w400,
  color: calendarSubtitleColor,
  letterSpacing: -0.1,
);

const taskMetadataTextStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w400,
  color: calendarTimeLabelColor,
  letterSpacing: 0.0,
);

// Section headers - uppercase with proper letter-spacing
const sectionHeaderTextStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: calendarTitleColor,
  letterSpacing: 0.5,
);

// Legacy gradient definitions (to be removed in favor of clean design)
const calendarPrimaryGradient = LinearGradient(
  colors: [Color(0xff80ffa0), Color(0xff40e0a0)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const calendarCardShadow = [
  BoxShadow(
    color: Color(0x1f000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
];

// Task-specific constants - updated to match target design
Color get taskCompletedColor => calendarPrimaryColor;
const calendarCardRadius = 6.0;

// Task priority colors matching target HTML design exactly
const taskCriticalColor =
    Color(0xFFDC3545); // Red - critical (important + urgent)
const taskImportantColor = Color(0xFF28A745); // Green - important only
const taskUrgentColor = Color(0xFFFD7E14); // Orange - urgent only
const taskNormalColor = Color(0xFF0969DA); // Blue - normal

// Legacy colors (kept for backward compatibility)
const taskHighPriorityColor = Color(0xffff3b30);
const taskMediumPriorityColor = Color(0xffff9500);
const taskLowPriorityColor = Color(0xff34c759);

const mobileHoverStrategies = ShadHoverStrategies(
  hover: {ShadHoverStrategy.onLongPressDown},
  unhover: {
    ShadHoverStrategy.onLongPressUp,
    ShadHoverStrategy.onLongPressCancel,
  },
);

const inputSubtextInsets = EdgeInsets.only(
  left: 8.0,
  top: 2.0,
  right: 8.0,
  bottom: 4.0,
);

const loginSubmitKey = Key('loginSubmit');
const loginUsernameKey = Key('loginUsername');
const loginPasswordKey = Key('loginPassword');
