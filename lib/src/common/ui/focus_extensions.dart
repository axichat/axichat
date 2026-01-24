// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/axi_editable_text.dart' as axi;
import 'package:flutter/material.dart';

extension TextInputFocusManager on FocusManager {
  bool get isTextInputFocused {
    final FocusNode? focusNode = primaryFocus;
    if (focusNode == null) {
      return false;
    }
    final BuildContext? focusContext = focusNode.context;
    if (focusContext == null) {
      return false;
    }
    final Widget focusedWidget = focusContext.widget;
    if (focusedWidget is EditableText || focusedWidget is axi.EditableText) {
      return true;
    }
    return focusContext.findAncestorWidgetOfExactType<EditableText>() != null ||
        focusContext.findAncestorWidgetOfExactType<axi.EditableText>() != null;
  }
}
