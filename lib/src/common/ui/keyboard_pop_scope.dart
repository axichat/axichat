// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/focus_extensions.dart';
import 'package:flutter/material.dart';

class KeyboardPopScope extends StatelessWidget {
  const KeyboardPopScope({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FocusManager.instance,
      builder: (context, _) {
        final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        return PopScope(
          canPop:
              keyboardInset == 0 || !FocusManager.instance.isTextInputFocused,
          onPopInvokedWithResult: (didPop, __) {
            if (didPop) {
              return;
            }
            if (keyboardInset > 0 && FocusManager.instance.isTextInputFocused) {
              FocusManager.instance.primaryFocus?.unfocus();
            }
          },
          child: child,
        );
      },
    );
  }
}
