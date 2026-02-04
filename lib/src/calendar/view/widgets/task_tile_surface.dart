// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';

class TaskTileSurface extends StatefulWidget {
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
    this.leadingStripeColor,
    this.leadingStripeWidth,
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
  final Color? leadingStripeColor;
  final double? leadingStripeWidth;

  @override
  State<TaskTileSurface> createState() => _TaskTileSurfaceState();
}

class _TaskTileSurfaceState extends State<TaskTileSurface> {
  final AxiTapBounceController _bounceController = AxiTapBounceController();
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    if (!mounted) return;
    setState(() {
      _hovered = value;
    });
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    if (!mounted) return;
    setState(() {
      _pressed = value;
    });
  }

  Color? _resolveOverlayColor({required bool focused}) {
    if (_pressed) {
      return widget.highlightColor ?? widget.splashColor;
    }
    if (_hovered) {
      return widget.hoverColor;
    }
    if (focused) {
      return widget.focusColor;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant TaskTileSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null && (_hovered || _pressed)) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final RoundedSuperellipseBorder shape = RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(context.radii.squircle));
    final bool enabled = widget.onTap != null;
    final MouseCursor effectiveCursor = widget.mouseCursor ??
        (enabled ? SystemMouseCursors.click : MouseCursor.defer);
    final Border? border = widget.decoration.border is Border
        ? widget.decoration.border as Border
        : null;
    final BorderSide? uniformSide =
        border == null || !border.isUniform ? null : border.top;
    final RoundedSuperellipseBorder decoratedShape = uniformSide == null
        ? shape
        : RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(context.radii.squircle),
            side: uniformSide,
          );
    final ShapeDecoration shapedDecoration = ShapeDecoration(
      color: widget.decoration.color,
      shape: decoratedShape,
      shadows: widget.decoration.boxShadow,
    );
    final double? stripeWidth = widget.leadingStripeWidth;
    final Color? stripeColor = widget.leadingStripeColor;
    final Widget content =
        stripeColor != null && stripeWidth != null && stripeWidth > 0
            ? CustomPaint(
                painter: _TaskTileStripePainter(
                  shape: decoratedShape,
                  color: stripeColor,
                  width: stripeWidth,
                ),
                child: widget.child,
              )
            : widget.child;

    return Container(
      margin: widget.margin,
      child: AxiTapBounce(
        enabled: enabled,
        controller: _bounceController,
        child: ShadFocusable(
          canRequestFocus: enabled,
          builder: (context, focused, _) {
            final Color? overlayColor = _resolveOverlayColor(focused: focused);
            final Widget overlay = overlayColor == null
                ? const SizedBox.shrink()
                : DecoratedBox(
                    decoration: ShapeDecoration(
                      color: overlayColor,
                      shape: decoratedShape,
                    ),
                  );
            final Widget decoratedContent = Stack(
              fit: StackFit.passthrough,
              children: [
                DecoratedBox(decoration: shapedDecoration, child: content),
                if (overlayColor != null)
                  Positioned.fill(child: IgnorePointer(child: overlay)),
              ],
            );

            return Material(
              type: MaterialType.transparency,
              shape: decoratedShape,
              clipBehavior: Clip.antiAlias,
              child: ShadGestureDetector(
                cursor: effectiveCursor,
                onHoverChange: enabled ? _setHovered : null,
                onTap: enabled ? widget.onTap : null,
                onTapDown: enabled
                    ? (details) {
                        _setPressed(true);
                        _bounceController.handleTapDown(details);
                      }
                    : null,
                onTapUp: enabled
                    ? (details) {
                        _setPressed(false);
                        _bounceController.handleTapUp(details);
                      }
                    : null,
                onTapCancel: enabled
                    ? () {
                        _setPressed(false);
                        _bounceController.handleTapCancel();
                      }
                    : null,
                child: decoratedContent,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TaskTileStripePainter extends CustomPainter {
  _TaskTileStripePainter({
    required this.shape,
    required this.color,
    required this.width,
  });

  final ShapeBorder shape;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Path shapePath = shape.getOuterPath(bounds);
    final Rect stripeRect = Rect.fromLTWH(0, 0, width, size.height);
    final Path stripePath = Path.combine(
      PathOperation.intersect,
      shapePath,
      Path()..addRect(stripeRect),
    );
    final Paint paint = Paint()..color = color;
    canvas.drawPath(stripePath, paint);
  }

  @override
  bool shouldRepaint(covariant _TaskTileStripePainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.color != color ||
        oldDelegate.width != width;
  }
}
