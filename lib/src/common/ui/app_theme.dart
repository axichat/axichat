// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart'
    show
        axiBorderRadius,
        axiBorders,
        gabaritoFontFallback,
        gabaritoFontFamily,
        inputSubtextInsets,
        interFontFallback,
        interFontFamily;
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
    this.backgroundDark = const Color(0xFF0B0B0B),
    this.cardDark = const Color(0xFF141414),
    this.borderDark = const Color(0xFF2A2A2A),
    this.foregroundDark = const Color(0xFFF5F5F5),
    this.mutedFgDark = const Color(0xFF9B9B9B),
    this.recvEdgeDark = const Color(0xFF3A3A3A),
    this.timestampDark = const Color(0xFF7B7B7B),
    this.scrollbarDark = const Color(0xFF3A3A3A),
    this.scrollbarHoverDark = const Color(0xFF4A4A4A),
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
    TextStyle inter(TextStyle style, Color color) {
      return style.copyWith(
        fontFamily: interFontFamily,
        fontFamilyFallback: interFontFallback,
        color: color,
      );
    }

    TextStyle gabarito(TextStyle style, Color color) {
      return style.copyWith(
        fontFamily: gabaritoFontFamily,
        fontFamilyFallback: gabaritoFontFallback,
        color: color,
      );
    }

    final Color foreground = patchedScheme.foreground;
    final Color mutedForeground = patchedScheme.mutedForeground;
    final textTheme = baseTextTheme.copyWith(
      h1Large: gabarito(baseTextTheme.h1Large, foreground),
      h1: gabarito(baseTextTheme.h1, foreground),
      h2: gabarito(baseTextTheme.h2, foreground),
      h3: gabarito(baseTextTheme.h3, foreground),
      h4: gabarito(baseTextTheme.h4, foreground),
      lead: inter(baseTextTheme.lead, foreground),
      large: inter(baseTextTheme.large, foreground),
      small: inter(baseTextTheme.small, foreground),
      p: inter(baseTextTheme.p, foreground),
      blockquote: inter(baseTextTheme.blockquote, foreground),
      table: inter(baseTextTheme.table, foreground),
      list: inter(baseTextTheme.list, foreground),
      muted: inter(baseTextTheme.muted, mutedForeground),
    );

    return ShadThemeData(
      brightness: brightness,
      colorScheme: patchedScheme,
      textTheme: textTheme,
      ghostButtonTheme: ShadButtonTheme(
        foregroundColor: patchedScheme.foreground,
        hoverForegroundColor: patchedScheme.primary,
        pressedForegroundColor: patchedScheme.primary,
      ),
      decoration: ShadDecoration(
        errorPadding: inputSubtextInsets,
        border: ShadBorder.fromBorderSide(
          ShadBorderSide(color: patchedScheme.border, width: axiBorders.width),
        ),
      ),
      radius: axiBorderRadius,
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
