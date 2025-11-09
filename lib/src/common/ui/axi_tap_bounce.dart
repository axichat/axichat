import 'package:flutter/material.dart';

class AxiTapBounce extends StatefulWidget {
  const AxiTapBounce({
    super.key,
    required this.child,
    this.scale = 0.96,
    this.enabled = true,
    this.pressDuration = const Duration(milliseconds: 80),
    this.releaseDuration = const Duration(milliseconds: 180),
    this.pressCurve = Curves.easeOutCubic,
    this.releaseCurve = Curves.easeOutBack,
  });

  final Widget child;
  final double scale;
  final bool enabled;
  final Duration pressDuration;
  final Duration releaseDuration;
  final Curve pressCurve;
  final Curve releaseCurve;

  @override
  State<AxiTapBounce> createState() => _AxiTapBounceState();
}

class _AxiTapBounceState extends State<AxiTapBounce> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() {
      _pressed = value;
    });
  }

  void _handlePointerDown(PointerDownEvent event) => _setPressed(true);

  void _handlePointerEnd(PointerEvent event) => _setPressed(false);

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final targetScale = _pressed ? widget.scale : 1.0;
    final duration = _pressed ? widget.pressDuration : widget.releaseDuration;
    final curve = _pressed ? widget.pressCurve : widget.releaseCurve;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: AnimatedScale(
        scale: targetScale,
        duration: duration,
        curve: curve,
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

extension AxiTapBounceExtension on Widget {
  Widget withTapBounce({bool enabled = true}) =>
      AxiTapBounce(enabled: enabled, child: this);
}
