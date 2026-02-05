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
    required this.attachmentPreviewExtent,
    required this.appBarHeight,
    required this.appBarElevation,
    required this.appBarScrolledUnderElevation,
    required this.dialogMaxWidth,
    required this.dialogMaxHeightFraction,
    required this.composeWindowWidth,
    required this.composeWindowExpandedWidth,
    required this.composeWindowHeight,
    required this.composeWindowExpandedHeight,
    required this.composeWindowMinWidth,
    required this.composeWindowMinHeight,
    required this.composeWindowPadding,
    required this.composeWindowStackOffset,
    required this.mediaPreviewMaxScale,
    required this.inputSuffixButtonSize,
    required this.inputSuffixIconSize,
    required this.sheetDragHandleWidth,
    required this.sheetDragHandleHeight,
    required this.modalShadowBlur,
    required this.modalShadowOffsetY,
    required this.progressIndicatorSize,
    required this.progressIndicatorStrokeWidth,
    required this.progressIndicatorBarHeight,
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
  final double attachmentPreviewExtent;
  final double appBarHeight;
  final double appBarElevation;
  final double appBarScrolledUnderElevation;
  final double dialogMaxWidth;
  final double dialogMaxHeightFraction;
  final double composeWindowWidth;
  final double composeWindowExpandedWidth;
  final double composeWindowHeight;
  final double composeWindowExpandedHeight;
  final double composeWindowMinWidth;
  final double composeWindowMinHeight;
  final double composeWindowPadding;
  final double composeWindowStackOffset;
  final double mediaPreviewMaxScale;
  final double inputSuffixButtonSize;
  final double inputSuffixIconSize;
  final double sheetDragHandleWidth;
  final double sheetDragHandleHeight;
  final double modalShadowBlur;
  final double modalShadowOffsetY;
  final double progressIndicatorSize;
  final double progressIndicatorStrokeWidth;
  final double progressIndicatorBarHeight;

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
    double? attachmentPreviewExtent,
    double? appBarHeight,
    double? appBarElevation,
    double? appBarScrolledUnderElevation,
    double? dialogMaxWidth,
    double? dialogMaxHeightFraction,
    double? composeWindowWidth,
    double? composeWindowExpandedWidth,
    double? composeWindowHeight,
    double? composeWindowExpandedHeight,
    double? composeWindowMinWidth,
    double? composeWindowMinHeight,
    double? composeWindowPadding,
    double? composeWindowStackOffset,
    double? mediaPreviewMaxScale,
    double? inputSuffixButtonSize,
    double? inputSuffixIconSize,
    double? sheetDragHandleWidth,
    double? sheetDragHandleHeight,
    double? modalShadowBlur,
    double? modalShadowOffsetY,
    double? progressIndicatorSize,
    double? progressIndicatorStrokeWidth,
    double? progressIndicatorBarHeight,
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
      attachmentPreviewExtent:
          attachmentPreviewExtent ?? this.attachmentPreviewExtent,
      appBarHeight: appBarHeight ?? this.appBarHeight,
      appBarElevation: appBarElevation ?? this.appBarElevation,
      appBarScrolledUnderElevation:
          appBarScrolledUnderElevation ?? this.appBarScrolledUnderElevation,
      dialogMaxWidth: dialogMaxWidth ?? this.dialogMaxWidth,
      dialogMaxHeightFraction:
          dialogMaxHeightFraction ?? this.dialogMaxHeightFraction,
      composeWindowWidth: composeWindowWidth ?? this.composeWindowWidth,
      composeWindowExpandedWidth:
          composeWindowExpandedWidth ?? this.composeWindowExpandedWidth,
      composeWindowHeight: composeWindowHeight ?? this.composeWindowHeight,
      composeWindowExpandedHeight:
          composeWindowExpandedHeight ?? this.composeWindowExpandedHeight,
      composeWindowMinWidth:
          composeWindowMinWidth ?? this.composeWindowMinWidth,
      composeWindowMinHeight:
          composeWindowMinHeight ?? this.composeWindowMinHeight,
      composeWindowPadding: composeWindowPadding ?? this.composeWindowPadding,
      composeWindowStackOffset:
          composeWindowStackOffset ?? this.composeWindowStackOffset,
      mediaPreviewMaxScale: mediaPreviewMaxScale ?? this.mediaPreviewMaxScale,
      inputSuffixButtonSize:
          inputSuffixButtonSize ?? this.inputSuffixButtonSize,
      inputSuffixIconSize: inputSuffixIconSize ?? this.inputSuffixIconSize,
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
  buttonHeightSm: 24,
  buttonHeightRegular: 40,
  buttonHeightLg: 48,
  menuItemHeight: 32,
  menuItemIconSize: 16,
  menuMinWidth: 0,
  menuMaxWidth: 320,
  menuMaxHeight: 320,
  listButtonHeight: 48,
  attachmentPreviewExtent: 72,
  appBarHeight: 56,
  appBarElevation: 0,
  appBarScrolledUnderElevation: 0,
  dialogMaxWidth: 640,
  dialogMaxHeightFraction: 0.9,
  composeWindowWidth: 520,
  composeWindowExpandedWidth: 720,
  composeWindowHeight: 560,
  composeWindowExpandedHeight: 640,
  composeWindowMinWidth: 360,
  composeWindowMinHeight: 260,
  composeWindowPadding: 12,
  composeWindowStackOffset: 20,
  mediaPreviewMaxScale: 4,
  inputSuffixButtonSize: 24,
  inputSuffixIconSize: 16,
  sheetDragHandleWidth: 32,
  sheetDragHandleHeight: 4,
  modalShadowBlur: 32,
  modalShadowOffsetY: 16,
  progressIndicatorSize: 16,
  progressIndicatorStrokeWidth: 2,
  progressIndicatorBarHeight: 8,
);
