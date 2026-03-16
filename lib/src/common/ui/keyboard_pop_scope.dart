// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/focus_extensions.dart';
import 'package:flutter/material.dart';

class KeyboardPopScope extends StatelessWidget {
  const KeyboardPopScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FocusManager.instance,
      builder: (context, _) {
        final hasTextInputFocus = FocusManager.instance.isTextInputFocused;
        return PopScope(
          canPop: !hasTextInputFocus,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              return;
            }
            if (hasTextInputFocus) {
              FocusManager.instance.primaryFocus?.unfocus();
            }
          },
          child: child,
        );
      },
    );
  }
}

Future<void> closeSheetWithKeyboardDismiss(
  BuildContext context,
  VoidCallback onClose,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  if (!context.mounted) return;
  onClose();
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  if (route is! PopupRoute<dynamic> || !route.isCurrent) {
    return;
  }
  final navigator = Navigator.maybeOf(context);
  if (navigator == null || !navigator.canPop()) {
    return;
  }
  navigator.pop();
}
