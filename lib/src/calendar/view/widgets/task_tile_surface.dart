// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class TaskTileSurface extends StatelessWidget {
  const TaskTileSurface({
    super.key,
    required this.margin,
    required this.decoration,
    required this.child,
    this.onTap,
    this.hoverColor,
    this.splashColor,
    this.highlightColor,
    this.focusColor,
    this.mouseCursor,
  });

  final EdgeInsets margin;
  final BoxDecoration decoration;
  final Widget child;
  final VoidCallback? onTap;
  final Color? hoverColor;
  final Color? splashColor;
  final Color? highlightColor;
  final Color? focusColor;
  final MouseCursor? mouseCursor;

  @override
  Widget build(BuildContext context) {
    final RoundedSuperellipseBorder shape =
        RoundedSuperellipseBorder(borderRadius: context.radius);
    final MouseCursor effectiveCursor = mouseCursor ??
        (onTap != null ? SystemMouseCursors.click : MouseCursor.defer);
    final BoxDecoration decorated = decoration.copyWith(
      borderRadius: BorderRadius.zero,
    );

    return Container(
      margin: margin,
      child: PhysicalShape(
        clipper: ShapeBorderClipper(shape: shape),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: decorated,
          child: Material(
            color: Colors.transparent,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: AxiTapBounce(
              enabled: onTap != null,
              child: InkWell(
                onTap: onTap,
                customBorder: shape,
                mouseCursor: effectiveCursor,
                hoverColor: hoverColor ?? Colors.transparent,
                splashColor: splashColor ?? Colors.transparent,
                highlightColor: highlightColor ?? Colors.transparent,
                focusColor: focusColor ?? Colors.transparent,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
