// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShortcutHint extends StatelessWidget {
  const ShortcutHint({super.key, required this.shortcut, this.dense = false});

  final MenuSerializableShortcut shortcut;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final label = shortcutLabel(context, shortcut);
    final parts = shortcutParts(shortcut, localizations);
    if (parts.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: label,
      child: _ShortcutKeycaps(parts: parts, dense: dense),
    );
  }
}

String shortcutLabel(BuildContext context, MenuSerializableShortcut shortcut) =>
    shortcutParts(
      shortcut,
      MaterialLocalizations.of(context),
    ).join(_usesSymbolicModifiers() ? ' ' : ' + ');

List<String> shortcutParts(
  MenuSerializableShortcut shortcut,
  MaterialLocalizations localizations,
) {
  final serialized = shortcut.serializeForMenu();
  final usesSymbols = _usesSymbolicModifiers();
  final labels = <String>[];

  void addModifier(bool? flag, LogicalKeyboardKey key) {
    if (flag ?? false) {
      labels.add(_modifierLabel(key, localizations));
    }
  }

  if (serialized.trigger != null) {
    final trigger = serialized.trigger!;
    if (usesSymbols) {
      addModifier(serialized.control, LogicalKeyboardKey.control);
      addModifier(serialized.alt, LogicalKeyboardKey.alt);
      addModifier(serialized.shift, LogicalKeyboardKey.shift);
      addModifier(serialized.meta, LogicalKeyboardKey.meta);
    } else {
      addModifier(serialized.alt, LogicalKeyboardKey.alt);
      addModifier(serialized.control, LogicalKeyboardKey.control);
      addModifier(serialized.meta, LogicalKeyboardKey.meta);
      addModifier(serialized.shift, LogicalKeyboardKey.shift);
    }
    final triggerLabel = _triggerLabel(trigger, localizations);
    if (triggerLabel.isNotEmpty) {
      labels.add(triggerLabel);
    }
  } else if (serialized.character != null) {
    if (usesSymbols) {
      addModifier(serialized.control, LogicalKeyboardKey.control);
      addModifier(serialized.alt, LogicalKeyboardKey.alt);
      addModifier(serialized.meta, LogicalKeyboardKey.meta);
    } else {
      addModifier(serialized.alt, LogicalKeyboardKey.alt);
      addModifier(serialized.control, LogicalKeyboardKey.control);
      addModifier(serialized.meta, LogicalKeyboardKey.meta);
    }
    labels.add(serialized.character!.toUpperCase());
  }

  return labels;
}

MenuSerializableShortcut findActionShortcut(TargetPlatform platform) {
  final isApple =
      platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
  return SingleActivator(
    LogicalKeyboardKey.keyK,
    meta: isApple,
    control: !isApple,
  );
}

List<ShortcutActivator> findActionActivators(TargetPlatform platform) {
  final isApple =
      platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
  return <ShortcutActivator>[
    SingleActivator(LogicalKeyboardKey.keyK, meta: isApple, control: !isApple),
    const SingleActivator(LogicalKeyboardKey.keyK, meta: true),
    const SingleActivator(LogicalKeyboardKey.keyK, control: true),
    LogicalKeySet(
      isApple ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
      LogicalKeyboardKey.keyK,
    ),
    // Allow either modifier set in case the platform reports both.
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK),
  ];
}

String _modifierLabel(
  LogicalKeyboardKey modifier,
  MaterialLocalizations localizations,
) {
  switch (modifier) {
    case LogicalKeyboardKey.meta ||
        LogicalKeyboardKey.metaLeft ||
        LogicalKeyboardKey.metaRight:
      switch (defaultTargetPlatform) {
        case TargetPlatform.android ||
            TargetPlatform.fuchsia ||
            TargetPlatform.linux:
          return localizations.keyboardKeyMeta;
        case TargetPlatform.windows:
          return localizations.keyboardKeyMetaWindows;
        case TargetPlatform.iOS || TargetPlatform.macOS:
          return '⌘';
      }
    case LogicalKeyboardKey.alt ||
        LogicalKeyboardKey.altLeft ||
        LogicalKeyboardKey.altRight:
      switch (defaultTargetPlatform) {
        case TargetPlatform.android ||
            TargetPlatform.fuchsia ||
            TargetPlatform.linux ||
            TargetPlatform.windows:
          return localizations.keyboardKeyAlt;
        case TargetPlatform.iOS || TargetPlatform.macOS:
          return '⌥';
      }
    case LogicalKeyboardKey.control ||
        LogicalKeyboardKey.controlLeft ||
        LogicalKeyboardKey.controlRight:
      switch (defaultTargetPlatform) {
        case TargetPlatform.android ||
            TargetPlatform.fuchsia ||
            TargetPlatform.linux ||
            TargetPlatform.windows:
          return localizations.keyboardKeyControl;
        case TargetPlatform.iOS || TargetPlatform.macOS:
          return '⌃';
      }
    case LogicalKeyboardKey.shift ||
        LogicalKeyboardKey.shiftLeft ||
        LogicalKeyboardKey.shiftRight:
      switch (defaultTargetPlatform) {
        case TargetPlatform.android ||
            TargetPlatform.fuchsia ||
            TargetPlatform.linux ||
            TargetPlatform.windows:
          return localizations.keyboardKeyShift;
        case TargetPlatform.iOS || TargetPlatform.macOS:
          return '⇧';
      }
  }
  return modifier.keyLabel;
}

String _triggerLabel(
  LogicalKeyboardKey trigger,
  MaterialLocalizations localizations,
) {
  final graphicEquivalents = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.arrowLeft: '←',
    LogicalKeyboardKey.arrowRight: '→',
    LogicalKeyboardKey.arrowUp: '↑',
    LogicalKeyboardKey.arrowDown: '↓',
    LogicalKeyboardKey.enter: '↵',
  };
  final graphic = graphicEquivalents[trigger];
  if (graphic != null) return graphic;
  if (trigger == LogicalKeyboardKey.escape) {
    return localizations.keyboardKeyEscape;
  }
  final label = trigger.keyLabel;
  if (label.isNotEmpty) {
    return label.toUpperCase();
  }
  return trigger.debugName ?? '';
}

bool _usesSymbolicModifiers() {
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

MenuSerializableShortcut escapeShortcut() =>
    const SingleActivator(LogicalKeyboardKey.escape);

class _ShortcutKeycaps extends StatelessWidget {
  const _ShortcutKeycaps({required this.parts, required this.dense});

  final List<String> parts;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    const double keyTopSheenBlend = 0.08;
    const double keyMidToneBlend = 0.04;
    const double keyShadowBlend = 0.65;
    final keyShadowAlpha =
        context.motion.tapFocusAlpha + (context.motion.tapHoverAlpha / 2);
    final keyShadowOverlayAlpha =
        context.motion.tapFocusAlpha + context.motion.tapHoverAlpha;
    final keyTopShadowAlpha = context.motion.tapFocusAlpha;
    final keyOverlayTopAlpha = context.motion.tapHoverAlpha / 2;
    final keyOverlayMidAlpha =
        context.motion.tapHoverAlpha - context.motion.tapHoverAlpha;
    final keyOverlayBottomAlpha = context.motion.tapSplashAlpha;
    const keyGradientStops = [0.0, 0.45, 1.0];
    const overlayGradientStops = [0.0, 0.5, 1.0];
    final keyBase = context.colorScheme.card;
    final topSheen = Color.lerp(
      keyBase,
      context.colorScheme.foreground,
      keyTopSheenBlend,
    )!;
    final midTone = Color.lerp(
      keyBase,
      context.colorScheme.foreground,
      keyMidToneBlend,
    )!;
    final keyShadow = Color.lerp(
      context.colorScheme.background,
      context.colorScheme.foreground,
      keyShadowBlend,
    )!;
    final borderWidth = dense
        ? context.sizing.progressIndicatorStrokeWidth
        : context.sizing.progressIndicatorStrokeWidth * 2;
    final padding = EdgeInsets.symmetric(
      horizontal: dense ? spacing.s : spacing.s,
      vertical: dense ? spacing.xs : spacing.xs,
    );
    final radius = context.radius;
    final drop = dense
        ? context.sizing.sheetDragHandleHeight
        : context.sizing.sheetDragHandleHeight * 2;

    Widget keycap(String label) {
      final backplateColor = Color.alphaBlend(
        keyShadow.withValues(alpha: keyShadowAlpha),
        keyBase,
      );
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: drop,
            left: 0,
            right: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backplateColor,
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: keyShadow.withValues(alpha: keyShadowOverlayAlpha),
                    offset: Offset(0, drop / 2),
                    blurRadius: drop * 2,
                    spreadRadius: 0.0,
                  ),
                ],
              ),
              child: Padding(
                padding: padding,
                child: Opacity(
                  opacity:
                      context.motion.tapHoverAlpha -
                      context.motion.tapHoverAlpha,
                  child: Text(label, style: context.textTheme.small),
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [topSheen, midTone, context.colorScheme.card],
                stops: keyGradientStops,
              ),
              border: Border.all(
                color: context.colorScheme.border,
                width: borderWidth,
              ),
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: keyShadow.withValues(alpha: keyTopShadowAlpha),
                  offset: Offset(0, context.sizing.modalShadowOffsetY / 8),
                  blurRadius: context.sizing.modalShadowBlur / 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  Padding(
                    padding: padding,
                    child: Text(label, style: context.textTheme.small),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            context.colorScheme.foreground.withValues(
                              alpha: keyOverlayTopAlpha,
                            ),
                            context.colorScheme.background.withValues(
                              alpha: keyOverlayMidAlpha,
                            ),
                            keyShadow.withValues(alpha: keyOverlayBottomAlpha),
                          ],
                          stops: overlayGradientStops,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final widgets = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      widgets.add(keycap(parts[i]));
      final hasNext = i < parts.length - 1;
      if (hasNext) {
        widgets.add(Text('+', style: context.textTheme.muted));
      }
    }
    return Wrap(
      spacing: spacing.s,
      runSpacing: spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: widgets,
    );
  }
}
