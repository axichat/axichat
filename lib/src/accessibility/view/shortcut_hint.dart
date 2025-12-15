import 'package:axichat/src/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ShortcutHint extends StatelessWidget {
  const ShortcutHint({
    super.key,
    required this.shortcut,
    this.dense = false,
  });

  final MenuSerializableShortcut shortcut;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final label = shortcutLabel(context, shortcut);
    final parts = shortcutParts(shortcut, localizations);
    if (parts.isEmpty) return const SizedBox.shrink();
    final colors = context.colorScheme;

    return Semantics(
      label: label,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: _buildKeycaps(
          parts: parts,
          dense: dense,
          colors: colors,
          textStyle: context.textTheme.small,
        ),
      ),
    );
  }
}

String shortcutLabel(
  BuildContext context,
  MenuSerializableShortcut shortcut,
) =>
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
    SingleActivator(
      LogicalKeyboardKey.keyK,
      meta: isApple,
      control: !isApple,
    ),
    const SingleActivator(
      LogicalKeyboardKey.keyK,
      meta: true,
    ),
    const SingleActivator(
      LogicalKeyboardKey.keyK,
      control: true,
    ),
    LogicalKeySet(
      isApple ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
      LogicalKeyboardKey.keyK,
    ),
    // Allow either modifier set in case the platform reports both.
    LogicalKeySet(
      LogicalKeyboardKey.meta,
      LogicalKeyboardKey.keyK,
    ),
    LogicalKeySet(
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.keyK,
    ),
  ];
}

const MenuSerializableShortcut escapeShortcut =
    SingleActivator(LogicalKeyboardKey.escape);

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
  final graphic = _shortcutGraphicEquivalents[trigger];
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

final Map<LogicalKeyboardKey, String> _shortcutGraphicEquivalents =
    <LogicalKeyboardKey, String>{
  LogicalKeyboardKey.arrowLeft: '←',
  LogicalKeyboardKey.arrowRight: '→',
  LogicalKeyboardKey.arrowUp: '↑',
  LogicalKeyboardKey.arrowDown: '↓',
  LogicalKeyboardKey.enter: '↵',
};

List<Widget> _buildKeycaps({
  required List<String> parts,
  required bool dense,
  required ShadColorScheme colors,
  required TextStyle textStyle,
}) {
  final keyBase = colors.card;
  final topSheen = Color.lerp(keyBase, colors.foreground, 0.08)!;
  final midTone = Color.lerp(keyBase, colors.foreground, 0.04)!;
  final keyShadow = Color.lerp(colors.background, Colors.black, 0.65)!;
  final borderWidth = dense ? 1.0 : 1.2;
  const paddingDense = EdgeInsets.symmetric(horizontal: 7, vertical: 4);
  const paddingComfort = EdgeInsets.symmetric(horizontal: 9, vertical: 5);
  final EdgeInsets padding = dense ? paddingDense : paddingComfort;
  const radiusValue = 8.5;
  final radius = BorderRadius.circular(radiusValue);
  final drop = dense ? 3.0 : 4.2;
  final keyStyle = textStyle.copyWith(
    color: colors.foreground,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );
  final connectorStyle = textStyle.copyWith(
    color: colors.mutedForeground,
    fontWeight: FontWeight.w600,
  );

  Widget keycap(String label) {
    final backplateColor = Color.alphaBlend(
      keyShadow.withValues(alpha: 0.35),
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
                  color: keyShadow.withValues(alpha: 0.45),
                  offset: Offset(0, drop / 2),
                  blurRadius: drop * 1.6,
                  spreadRadius: 0.0,
                ),
              ],
            ),
            child: Padding(
              padding: padding,
              child: Opacity(
                opacity: 0,
                child: Text(label, style: keyStyle),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                topSheen,
                midTone,
                colors.card,
              ],
              stops: const [0, 0.45, 1],
            ),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.95),
              width: borderWidth,
            ),
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: keyShadow.withValues(alpha: 0.3),
                offset: const Offset(0, 1.2),
                blurRadius: 3.2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                Padding(
                  padding: padding,
                  child: Text(label, style: keyStyle),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.04),
                          Colors.transparent,
                          keyShadow.withValues(alpha: 0.12),
                        ],
                        stops: const [0, 0.5, 1],
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
      widgets.add(Text('+', style: connectorStyle));
    }
  }
  return widgets;
}
