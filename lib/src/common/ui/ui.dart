import 'package:shadcn_ui/shadcn_ui.dart';

export 'axi_adaptive_layout.dart';
export 'axi_avatar.dart';
export 'axi_badge.dart';
export 'axi_confirm.dart';
export 'axi_icon_button.dart';
export 'axi_input_dialog.dart';
export 'axi_list_tile.dart';
export 'axi_progress_indicator.dart';
export 'axi_text_form_field.dart';
export 'axi_tooltip.dart';
export 'display_time_since.dart';
export 'list_item_padding.dart';
export 'presence_indicator.dart';

const smallScreen = 700.0;
const mediumScreen = 900.0;
const largeScreen = 1200.0;

const baseAnimationDuration = Duration(milliseconds: 300);
const basePageItemLimit = 15;

const mobileHoverStrategies = ShadHoverStrategies(
  hover: {ShadHoverStrategy.onLongPressDown},
  unhover: {
    ShadHoverStrategy.onLongPressUp,
    ShadHoverStrategy.onLongPressCancel,
  },
);
