// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:flutter/widgets.dart';

class AxiErrorText extends StatelessWidget {
  const AxiErrorText(this.data, {super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: context.textTheme.small.copyWith(
        color: context.colorScheme.destructive,
      ),
    );
  }
}
