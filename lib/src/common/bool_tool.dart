import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension BoolTool on bool {
  int get toSign => this ? 1 : -1;

  int get toBinary => this ? 1 : 0;

  IconData get toIcon => this ? LucideIcons.check600 : LucideIcons.x600;

  IconData get toShieldIcon =>
      this ? LucideIcons.shieldHalf600 : LucideIcons.shieldX600;

  Color get toColor => this ? axiGreen : Colors.red;
}
