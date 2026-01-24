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
        return PopScope(
          canPop: !FocusManager.instance.isTextInputFocused,
          onPopInvokedWithResult: (didPop, __) {
            if (didPop) {
              return;
            }
            if (FocusManager.instance.isTextInputFocused) {
              FocusManager.instance.primaryFocus?.unfocus();
            }
          },
          child: child,
        );
      },
    );
  }
}
