// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class ContextActionButton extends StatelessWidget {
  const ContextActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.destructive = false,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final destructiveColor = destructive
        ? context.colorScheme.destructive
        : null;
    final textStyle = destructive
        ? context.textTheme.small.copyWith(color: destructiveColor)
        : null;
    final textScaler = MediaQuery.of(context).textScaler;
    double scaled(double value) => textScaler.scale(value);
    return Semantics(
      button: true,
      enabled: onPressed != null && !loading,
      label: label,
      child: AxiButton.outline(
        onPressed: onPressed,
        loading: loading,
        child: IconTheme.merge(
          data: IconThemeData(color: destructiveColor),
          child: DefaultTextStyle.merge(
            style: textStyle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                icon,
                SizedBox(width: scaled(6)),
                Flexible(
                  child: Text(
                    label,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
