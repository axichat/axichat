// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardPopScope extends StatelessWidget {
  const KeyboardPopScope({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: MediaQuery.viewInsetsOf(context).bottom == 0,
      onPopInvokedWithResult: (didPop, __) {
        if (didPop) {
          return;
        }
        if (MediaQuery.viewInsetsOf(context).bottom > 0) {
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        }
      },
      child: child,
    );
  }
}
