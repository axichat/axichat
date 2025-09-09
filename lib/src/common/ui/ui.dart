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

// Clean professional calendar design constants
// Event colors (7-color rotation system)
const calendarEventColors = [
  Color(0xff007AFF), // Blue
  Color(0xff5856d6), // Purple
  Color(0xffff9500), // Orange
  Color(0xffff3b30), // Red
  Color(0xff34c759), // Green
  Color(0xff5ac8fa), // Teal
  Color(0xffffcc02), // Yellow
];

// Clean background colors
const calendarBackgroundColor = Color(0xfff7f7f7);
const calendarContainerColor = Color(0xffffffff);
const calendarBorderColor = Color(0xffe5e5e5);
const calendarSelectedDayColor = Color(0xfff5f5f5);

// Professional typography colors
const calendarTitleColor = Color(0xff1d1d1f);
const calendarSubtitleColor = Color(0xff6e6e73);
const calendarTimeLabelColor = Color(0xff8e8e93);

// Subtle shadow system
const calendarLightShadow = [
  BoxShadow(
    color: Color(0x14000000), // rgba(0,0,0,0.08)
    blurRadius: 4,
    offset: Offset(0, 1),
  ),
];

const calendarMediumShadow = [
  BoxShadow(
    color: Color(0x1f000000), // rgba(0,0,0,0.12)
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
];

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

// Typography constants
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

// Task-specific constants
const taskCompletedColor = Color(0xff8e8e93);
const calendarCardRadius = 6.0;
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
