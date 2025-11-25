import 'package:axichat/src/common/ui/ui.dart'
    show inputSubtextInsets, interFontFallback, interFontFamily;
import 'package:axichat/src/settings/bloc/settings_cubit.dart' show ShadColor;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Neutral palette that mirrors the designer-provided CSS tokens.
class ChatNeutrals {
  const ChatNeutrals({
    this.backgroundLight = const Color(0xFFFAFBFC),
    this.cardLight = const Color(0xFFFFFFFF),
    this.borderLight = const Color(0xFFE2E8F0),
    this.foregroundLight = const Color(0xFF1E293B),
    this.mutedFgLight = const Color(0xFF64748B),
    this.recvEdgeLight = const Color(0xFFE5E7EB),
    this.timestampLight = const Color(0xFF9CA3AF),
    this.scrollbarLight = const Color(0xFFCBD5E1),
    this.scrollbarHoverLight = const Color(0xFF94A3B8),
    this.backgroundDark = const Color(0xFF111827),
    this.cardDark = const Color(0xFF1F2937),
    this.borderDark = const Color(0xFF374151),
    this.foregroundDark = const Color(0xFFF9FAFB),
    this.mutedFgDark = const Color(0xFF9CA3AF),
    this.recvEdgeDark = const Color(0xFF4B5563),
    this.timestampDark = const Color(0xFF6B7280),
    this.scrollbarDark = const Color(0xFF4B5563),
    this.scrollbarHoverDark = const Color(0xFF6B7280),
  });

  final Color backgroundLight;
  final Color cardLight;
  final Color borderLight;
  final Color foregroundLight;
  final Color mutedFgLight;
  final Color recvEdgeLight;
  final Color timestampLight;
  final Color scrollbarLight;
  final Color scrollbarHoverLight;

  final Color backgroundDark;
  final Color cardDark;
  final Color borderDark;
  final Color foregroundDark;
  final Color mutedFgDark;
  final Color recvEdgeDark;
  final Color timestampDark;
  final Color scrollbarDark;
  final Color scrollbarHoverDark;
}

@immutable
class ChatThemeTokens extends ThemeExtension<ChatThemeTokens> {
  const ChatThemeTokens({
    required this.recvEdge,
    required this.timestamp,
    required this.scrollbar,
    required this.scrollbarHover,
  });

  final Color recvEdge;
  final Color timestamp;
  final Color scrollbar;
  final Color scrollbarHover;

  factory ChatThemeTokens.fromNeutrals(
    ChatNeutrals neutrals,
    Brightness brightness,
  ) {
    if (brightness == Brightness.light) {
      return ChatThemeTokens(
        recvEdge: neutrals.recvEdgeLight,
        timestamp: neutrals.timestampLight,
        scrollbar: neutrals.scrollbarLight,
        scrollbarHover: neutrals.scrollbarHoverLight,
      );
    }
    return ChatThemeTokens(
      recvEdge: neutrals.recvEdgeDark,
      timestamp: neutrals.timestampDark,
      scrollbar: neutrals.scrollbarDark,
      scrollbarHover: neutrals.scrollbarHoverDark,
    );
  }

  @override
  ChatThemeTokens copyWith({
    Color? recvEdge,
    Color? timestamp,
    Color? scrollbar,
    Color? scrollbarHover,
  }) {
    return ChatThemeTokens(
      recvEdge: recvEdge ?? this.recvEdge,
      timestamp: timestamp ?? this.timestamp,
      scrollbar: scrollbar ?? this.scrollbar,
      scrollbarHover: scrollbarHover ?? this.scrollbarHover,
    );
  }

  @override
  ChatThemeTokens lerp(ThemeExtension<ChatThemeTokens>? other, double t) {
    if (other is! ChatThemeTokens) return this;
    return ChatThemeTokens(
      recvEdge: Color.lerp(recvEdge, other.recvEdge, t) ?? recvEdge,
      timestamp: Color.lerp(timestamp, other.timestamp, t) ?? timestamp,
      scrollbar: Color.lerp(scrollbar, other.scrollbar, t) ?? scrollbar,
      scrollbarHover:
          Color.lerp(scrollbarHover, other.scrollbarHover, t) ?? scrollbarHover,
    );
  }
}

/// Centralizes how the app builds Shad themes so visual updates stay in sync
/// with the persisted settings state.
class AppTheme {
  const AppTheme._();

  static ShadThemeData build({
    required ShadColor shadColor,
    required Brightness brightness,
    ChatNeutrals neutrals = const ChatNeutrals(),
  }) {
    final baseScheme = ShadColorScheme.fromName(
      shadColor.name,
      brightness: brightness,
    );

    final patchedScheme = brightness == Brightness.light
        ? _lightScheme(baseScheme, neutrals)
        : _darkScheme(baseScheme, neutrals);
    final baseTextTheme = ShadTextTheme();
    TextStyle inter(TextStyle style) {
      return style.copyWith(
        fontFamily: interFontFamily,
        fontFamilyFallback: interFontFallback,
      );
    }

    final textTheme = baseTextTheme.copyWith(
      h1Large: inter(baseTextTheme.h1Large),
      h1: inter(baseTextTheme.h1),
      h2: inter(baseTextTheme.h2),
      h3: inter(baseTextTheme.h3),
      h4: inter(baseTextTheme.h4),
      lead: inter(baseTextTheme.lead),
      large: inter(baseTextTheme.large),
      small: inter(baseTextTheme.small),
      p: inter(baseTextTheme.p),
      muted: inter(baseTextTheme.muted),
    );

    return ShadThemeData(
      brightness: brightness,
      colorScheme: patchedScheme,
      textTheme: textTheme,
      decoration: const ShadDecoration(
        errorPadding: inputSubtextInsets,
      ),
      radius: const BorderRadius.all(Radius.circular(12)),
    );
  }

  static ChatThemeTokens tokens({
    required Brightness brightness,
    ChatNeutrals neutrals = const ChatNeutrals(),
  }) {
    return ChatThemeTokens.fromNeutrals(neutrals, brightness);
  }

  static ShadColorScheme _lightScheme(
    ShadColorScheme base,
    ChatNeutrals neutrals,
  ) {
    return base.copyWith(
      background: neutrals.backgroundLight,
      card: neutrals.cardLight,
      popover: neutrals.cardLight,
      border: neutrals.borderLight,
      foreground: neutrals.foregroundLight,
      mutedForeground: neutrals.mutedFgLight,
    );
  }

  static ShadColorScheme _darkScheme(
    ShadColorScheme base,
    ChatNeutrals neutrals,
  ) {
    return base.copyWith(
      background: neutrals.backgroundDark,
      card: neutrals.cardDark,
      popover: neutrals.cardDark,
      border: neutrals.borderDark,
      foreground: neutrals.foregroundDark,
      mutedForeground: neutrals.mutedFgDark,
    );
  }
}
