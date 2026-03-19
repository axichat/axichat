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
    final BuildContext? focusContext = context;
    if (focusContext == null || !focusContext.mounted) {
      return false;
    }
    final Element focusElement = focusContext as Element;
    if (_isTextInputElement(focusElement)) {
      return true;
    }
    var isFocusedTextInput = false;
    focusElement.visitAncestorElements((ancestor) {
      if (_isTextInputElement(ancestor)) {
        isFocusedTextInput = true;
        return false;
      }
      return true;
    });
    return isFocusedTextInput;
  }
}

bool _isTextInputElement(Element element) {
  final Widget widget = element.widget;
  return widget is EditableText || widget is axi.EditableText;
}
