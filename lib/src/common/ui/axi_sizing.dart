// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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
    required this.menuItemIconSize,
    required this.menuMinWidth,
    required this.menuMaxWidth,
    required this.menuMaxHeight,
    required this.listButtonHeight,
    required this.appBarElevation,
    required this.appBarScrolledUnderElevation,
    required this.dialogMaxWidth,
    required this.dialogMaxHeightFraction,
    required this.sheetDragHandleWidth,
    required this.sheetDragHandleHeight,
    required this.modalShadowBlur,
    required this.modalShadowOffsetY,
    required this.progressIndicatorSize,
    required this.progressIndicatorStrokeWidth,
    required this.progressIndicatorBarHeight,
    required this.containerRadius,
  });

  final double iconButtonSize;
  final double iconButtonTapTarget;
  final double iconButtonIconSize;
  final double buttonHeightSm;
  final double buttonHeightRegular;
  final double buttonHeightLg;
  final double menuItemHeight;
  final double menuItemIconSize;
  final double menuMinWidth;
  final double menuMaxWidth;
  final double menuMaxHeight;
  final double listButtonHeight;
  final double appBarElevation;
  final double appBarScrolledUnderElevation;
  final double dialogMaxWidth;
  final double dialogMaxHeightFraction;
  final double sheetDragHandleWidth;
  final double sheetDragHandleHeight;
  final double modalShadowBlur;
  final double modalShadowOffsetY;
  final double progressIndicatorSize;
  final double progressIndicatorStrokeWidth;
  final double progressIndicatorBarHeight;
  final double containerRadius;

  @override
  AxiSizing copyWith({
    double? iconButtonSize,
    double? iconButtonTapTarget,
    double? iconButtonIconSize,
    double? buttonHeightSm,
    double? buttonHeightRegular,
    double? buttonHeightLg,
    double? menuItemHeight,
    double? menuItemIconSize,
    double? menuMinWidth,
    double? menuMaxWidth,
    double? menuMaxHeight,
    double? listButtonHeight,
    double? appBarElevation,
    double? appBarScrolledUnderElevation,
    double? dialogMaxWidth,
    double? dialogMaxHeightFraction,
    double? sheetDragHandleWidth,
    double? sheetDragHandleHeight,
    double? modalShadowBlur,
    double? modalShadowOffsetY,
    double? progressIndicatorSize,
    double? progressIndicatorStrokeWidth,
    double? progressIndicatorBarHeight,
    double? containerRadius,
  }) {
    return AxiSizing(
      iconButtonSize: iconButtonSize ?? this.iconButtonSize,
      iconButtonTapTarget: iconButtonTapTarget ?? this.iconButtonTapTarget,
      iconButtonIconSize: iconButtonIconSize ?? this.iconButtonIconSize,
      buttonHeightSm: buttonHeightSm ?? this.buttonHeightSm,
      buttonHeightRegular: buttonHeightRegular ?? this.buttonHeightRegular,
      buttonHeightLg: buttonHeightLg ?? this.buttonHeightLg,
      menuItemHeight: menuItemHeight ?? this.menuItemHeight,
      menuItemIconSize: menuItemIconSize ?? this.menuItemIconSize,
      menuMinWidth: menuMinWidth ?? this.menuMinWidth,
      menuMaxWidth: menuMaxWidth ?? this.menuMaxWidth,
      menuMaxHeight: menuMaxHeight ?? this.menuMaxHeight,
      listButtonHeight: listButtonHeight ?? this.listButtonHeight,
      appBarElevation: appBarElevation ?? this.appBarElevation,
      appBarScrolledUnderElevation:
          appBarScrolledUnderElevation ?? this.appBarScrolledUnderElevation,
      dialogMaxWidth: dialogMaxWidth ?? this.dialogMaxWidth,
      dialogMaxHeightFraction:
          dialogMaxHeightFraction ?? this.dialogMaxHeightFraction,
      sheetDragHandleWidth: sheetDragHandleWidth ?? this.sheetDragHandleWidth,
      sheetDragHandleHeight:
          sheetDragHandleHeight ?? this.sheetDragHandleHeight,
      modalShadowBlur: modalShadowBlur ?? this.modalShadowBlur,
      modalShadowOffsetY: modalShadowOffsetY ?? this.modalShadowOffsetY,
      progressIndicatorSize:
          progressIndicatorSize ?? this.progressIndicatorSize,
      progressIndicatorStrokeWidth:
          progressIndicatorStrokeWidth ?? this.progressIndicatorStrokeWidth,
      progressIndicatorBarHeight:
          progressIndicatorBarHeight ?? this.progressIndicatorBarHeight,
      containerRadius: containerRadius ?? this.containerRadius,
    );
  }

  @override
  AxiSizing lerp(AxiSizing? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

const AxiSizing axiSizing = AxiSizing(
  iconButtonSize: 40,
  iconButtonTapTarget: 48,
  iconButtonIconSize: 20,
  buttonHeightSm: 32,
  buttonHeightRegular: 40,
  buttonHeightLg: 48,
  menuItemHeight: 32,
  menuItemIconSize: 16,
  menuMinWidth: 0,
  menuMaxWidth: 320,
  menuMaxHeight: 320,
  listButtonHeight: 48,
  appBarElevation: 0,
  appBarScrolledUnderElevation: 0,
  dialogMaxWidth: 640,
  dialogMaxHeightFraction: 0.9,
  sheetDragHandleWidth: 32,
  sheetDragHandleHeight: 4,
  modalShadowBlur: 32,
  modalShadowOffsetY: 16,
  progressIndicatorSize: 16,
  progressIndicatorStrokeWidth: 2,
  progressIndicatorBarHeight: 8,
  containerRadius: 8,
);
