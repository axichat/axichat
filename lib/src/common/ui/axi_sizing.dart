// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:ui';

import 'package:flutter/material.dart';

class AxiSizing extends ThemeExtension<AxiSizing> {
  const AxiSizing({
    required this.iconButtonSize,
    required this.iconButtonTapTarget,
    required this.iconButtonIconSize,
    required this.buttonHeightSm,
    required this.buttonHeightRegular,
    required this.buttonHeightLg,
    required this.menuItemHeight,
    required this.sheetDragHandleWidth,
    required this.sheetDragHandleHeight,
    required this.modalShadowBlur,
    required this.modalShadowOffsetY,
    required this.progressIndicatorSize,
  });

  final double iconButtonSize;
  final double iconButtonTapTarget;
  final double iconButtonIconSize;
  final double buttonHeightSm;
  final double buttonHeightRegular;
  final double buttonHeightLg;
  final double menuItemHeight;
  final double sheetDragHandleWidth;
  final double sheetDragHandleHeight;
  final double modalShadowBlur;
  final double modalShadowOffsetY;
  final double progressIndicatorSize;

  @override
  AxiSizing copyWith({
    double? iconButtonSize,
    double? iconButtonTapTarget,
    double? iconButtonIconSize,
    double? buttonHeightSm,
    double? buttonHeightRegular,
    double? buttonHeightLg,
    double? menuItemHeight,
    double? sheetDragHandleWidth,
    double? sheetDragHandleHeight,
    double? modalShadowBlur,
    double? modalShadowOffsetY,
    double? progressIndicatorSize,
  }) {
    return AxiSizing(
      iconButtonSize: iconButtonSize ?? this.iconButtonSize,
      iconButtonTapTarget: iconButtonTapTarget ?? this.iconButtonTapTarget,
      iconButtonIconSize: iconButtonIconSize ?? this.iconButtonIconSize,
      buttonHeightSm: buttonHeightSm ?? this.buttonHeightSm,
      buttonHeightRegular: buttonHeightRegular ?? this.buttonHeightRegular,
      buttonHeightLg: buttonHeightLg ?? this.buttonHeightLg,
      menuItemHeight: menuItemHeight ?? this.menuItemHeight,
      sheetDragHandleWidth: sheetDragHandleWidth ?? this.sheetDragHandleWidth,
      sheetDragHandleHeight:
          sheetDragHandleHeight ?? this.sheetDragHandleHeight,
      modalShadowBlur: modalShadowBlur ?? this.modalShadowBlur,
      modalShadowOffsetY: modalShadowOffsetY ?? this.modalShadowOffsetY,
      progressIndicatorSize:
          progressIndicatorSize ?? this.progressIndicatorSize,
    );
  }

  @override
  AxiSizing lerp(AxiSizing? other, double t) {
    if (other == null) return this;
    return AxiSizing(
      iconButtonSize: lerpDouble(iconButtonSize, other.iconButtonSize, t) ??
          iconButtonSize,
      iconButtonTapTarget:
          lerpDouble(iconButtonTapTarget, other.iconButtonTapTarget, t) ??
              iconButtonTapTarget,
      iconButtonIconSize:
          lerpDouble(iconButtonIconSize, other.iconButtonIconSize, t) ??
              iconButtonIconSize,
      buttonHeightSm:
          lerpDouble(buttonHeightSm, other.buttonHeightSm, t) ??
              buttonHeightSm,
      buttonHeightRegular:
          lerpDouble(buttonHeightRegular, other.buttonHeightRegular, t) ??
              buttonHeightRegular,
      buttonHeightLg:
          lerpDouble(buttonHeightLg, other.buttonHeightLg, t) ??
              buttonHeightLg,
      menuItemHeight:
          lerpDouble(menuItemHeight, other.menuItemHeight, t) ??
              menuItemHeight,
      sheetDragHandleWidth:
          lerpDouble(sheetDragHandleWidth, other.sheetDragHandleWidth, t) ??
              sheetDragHandleWidth,
      sheetDragHandleHeight:
          lerpDouble(sheetDragHandleHeight, other.sheetDragHandleHeight, t) ??
              sheetDragHandleHeight,
      modalShadowBlur:
          lerpDouble(modalShadowBlur, other.modalShadowBlur, t) ??
              modalShadowBlur,
      modalShadowOffsetY:
          lerpDouble(modalShadowOffsetY, other.modalShadowOffsetY, t) ??
              modalShadowOffsetY,
      progressIndicatorSize:
          lerpDouble(progressIndicatorSize, other.progressIndicatorSize, t) ??
              progressIndicatorSize,
    );
  }
}

const AxiSizing axiSizing = AxiSizing(
  iconButtonSize: 32,
  iconButtonTapTarget: 48,
  iconButtonIconSize: 24,
  buttonHeightSm: 32,
  buttonHeightRegular: 40,
  buttonHeightLg: 48,
  menuItemHeight: 48,
  sheetDragHandleWidth: 32,
  sheetDragHandleHeight: 4,
  modalShadowBlur: 32,
  modalShadowOffsetY: 16,
  progressIndicatorSize: 16,
);
