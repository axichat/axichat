// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/axi_editable_text.dart' as axi;
import 'package:flutter/material.dart';

extension TextInputFocusManager on FocusManager {
  bool get isTextInputFocused {
    final FocusNode? focusNode = primaryFocus;
    return focusNode?.isTextInputFocused ?? false;
  }
}

extension TextInputFocusNode on FocusNode {
  bool get isTextInputFocused {
    if (axi.isRegisteredEditableTextFocusNode(this)) {
      return true;
    }
    final BuildContext? focusContext = context;
    if (focusContext == null || !focusContext.mounted) {
      return false;
    }
    return _isTextInputWidget(focusContext.widget);
  }
}

bool _isTextInputWidget(Widget widget) {
  return widget is EditableText || widget is axi.EditableText;
}
