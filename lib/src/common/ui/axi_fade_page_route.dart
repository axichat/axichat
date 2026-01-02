import 'package:flutter/material.dart';

const Curve _fadePageCurve = Curves.easeInOutCubic;

class AxiFadePageRoute<T> extends PageRouteBuilder<T> {
  AxiFadePageRoute({
    required WidgetBuilder builder,
    required Duration duration,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) : super(
          settings: settings,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          fullscreenDialog: fullscreenDialog,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: _fadePageCurve,
              reverseCurve: _fadePageCurve,
            );
            return FadeTransition(
              opacity: curved,
              child: child,
            );
          },
        );
}
