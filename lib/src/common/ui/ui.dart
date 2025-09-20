import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

export 'axi_adaptive_layout.dart';
export 'axi_app_bar.dart';
export 'axi_avatar.dart';
export 'axi_badge.dart';
export 'axi_confirm.dart';
export 'axi_delete_menu_item.dart';
export 'axi_fab.dart';
export 'axi_icon_button.dart';
export 'axi_input_dialog.dart';
export 'axi_link.dart';
export 'axi_list_divider.dart';
export 'axi_list_tile.dart';
export 'axi_more.dart';
export 'axi_progress_indicator.dart';
export 'axi_text_form_field.dart';
export 'axi_tooltip.dart';
export 'axi_version.dart';
export 'display_fingerprint.dart';
export 'display_time_since.dart';
export 'dynamic_inline_text.dart';
export 'jid_input.dart';
export 'list_item_padding.dart';
export 'password_input.dart';
export 'presence_indicator.dart';
export 'string_to_color.dart';

const appDisplayName = 'axichat';
const androidIconPath = 'app_icon';

const smallScreen = 700.0;
const mediumScreen = 900.0;
const largeScreen = 1200.0;

const baseAnimationDuration = Duration(milliseconds: 300);
const basePageItemLimit = 15;

const axiGreen = Color(0xff80ffa0);

// Ultrathink calendar color palette
const calendarPrimaryColor = Color(0xFF0969DA);
const calendarPrimaryHoverColor = Color(0xFF0860CA);
const calendarBackgroundColor = Color(0xFFFFFFFF);
const calendarContainerColor = Color(0xFFFFFFFF);
const calendarSidebarBackgroundColor = Color(0xFFF7F8FA);
const calendarBorderColor = Color(0xFFE1E4E8);
const calendarBorderDarkColor = Color(0xFFD1D5DA);
const calendarBorderLightColor = Color(0xFFF0F0F0);
const calendarSelectedDayColor = Color(0xFFF6F8FA);

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

// Standard spacing values
const calendarSpacing2 = 2.0;
const calendarSpacing4 = 4.0;
const calendarSpacing6 = 6.0;
const calendarSpacing8 = 8.0;
const calendarSpacing12 = 12.0;
const calendarSpacing16 = 16.0;

// Standard EdgeInsets
const calendarPadding4 = EdgeInsets.all(4.0);
const calendarPadding8 = EdgeInsets.all(8.0);
const calendarPadding12 = EdgeInsets.all(12.0);
const calendarPadding16 = EdgeInsets.all(16.0);

const calendarMarginSmall = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
const calendarMarginMedium = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
const calendarMarginLarge = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

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
const taskCompletedColor = calendarPrimaryColor;
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
