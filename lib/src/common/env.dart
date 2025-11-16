import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum FormFactor {
  handset,
  tablet,
  desktop,
}

enum NavPlacement {
  bottom,
  rail,
}

enum CommandSurface {
  sheet,
  menu,
}

@immutable
class Env {
  Env({
    required this.size,
    required this.platform,
  }) : formFactor = _formFactorFor(size.width);

  final Size size;
  final TargetPlatform platform;
  final FormFactor formFactor;

  static FormFactor _formFactorFor(double width) {
    if (width >= 900) return FormFactor.desktop;
    if (width >= 600) return FormFactor.tablet;
    return FormFactor.handset;
  }

  bool get isDesktopPlatform {
    if (kIsWeb) {
      return formFactor == FormFactor.desktop;
    }
    return platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.windows;
  }

  NavPlacement get navPlacement => formFactor == FormFactor.desktop
      ? NavPlacement.rail
      : NavPlacement.bottom;

  CommandSurface get commandSurface =>
      isDesktopPlatform ? CommandSurface.menu : CommandSurface.sheet;

  bool get supportsDesktopShortcuts => isDesktopPlatform;

  bool get usesDesktopMenu => isDesktopPlatform;

  Env copyWith({Size? size, TargetPlatform? platform}) {
    return Env(
      size: size ?? this.size,
      platform: platform ?? this.platform,
    );
  }

  @override
  int get hashCode => Object.hash(size, platform, formFactor);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Env &&
            runtimeType == other.runtimeType &&
            size == other.size &&
            platform == other.platform;
  }
}

class EnvScope extends StatelessWidget {
  const EnvScope({
    super.key,
    required this.child,
  });

  final Widget child;

  static Env of(BuildContext context) {
    final env = context.dependOnInheritedWidgetOfExactType<_EnvInherited>();
    assert(env != null, 'EnvScope.of() called with no EnvScope in context');
    return env!.env;
  }

  static Env? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_EnvInherited>()?.env;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final platform = Theme.of(context).platform;
    final env = Env(size: size, platform: platform);
    return _EnvInherited(env: env, child: child);
  }
}

class _EnvInherited extends InheritedWidget {
  const _EnvInherited({
    required this.env,
    required super.child,
  });

  final Env env;

  @override
  bool updateShouldNotify(_EnvInherited oldWidget) {
    return env != oldWidget.env;
  }
}
