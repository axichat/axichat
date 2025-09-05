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
