// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter/services.dart';

class ChatComposerAccessory {
  const ChatComposerAccessory({
    required this.child,
    required this.edge,
    this.alignment,
    this.depth,
    this.thickness,
    this.cornerRadius,
  });

  final Widget child;
  final CutoutEdge edge;
  final Alignment? alignment;
  final double? depth;
  final double? thickness;
  final double? cornerRadius;

  factory ChatComposerAccessory.leading({
    required Widget child,
    double? depth,
    double? thickness,
    double? cornerRadius,
  }) {
    return ChatComposerAccessory(
      child: child,
      edge: CutoutEdge.left,
      alignment: Alignment.centerLeft,
      depth: depth,
      thickness: thickness,
      cornerRadius: cornerRadius,
    );
  }

  factory ChatComposerAccessory.trailing({
    required Widget child,
    double? depth,
    double? thickness,
    double? cornerRadius,
  }) {
    return ChatComposerAccessory(
      child: child,
      edge: CutoutEdge.right,
      alignment: Alignment.centerRight,
      depth: depth,
      thickness: thickness,
      cornerRadius: cornerRadius,
    );
  }
}

class ChatCutoutComposer extends StatelessWidget {
  const ChatCutoutComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onSend,
    required this.actions,
    required this.sendEnabled,
    required this.sendOnEnter,
    this.minLines = 1,
    this.maxLines = 6,
    this.header,
    this.semanticsLabel,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final VoidCallback onSend;
  final List<ChatComposerAccessory> actions;
  final bool sendEnabled;
  final bool sendOnEnter;
  final int minLines;
  final int maxLines;
  final Widget? header;
  final String? semanticsLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final horizontalInset = spacing.l;
    final verticalInset = spacing.m;
    final headerAwareTopInset = header == null ? verticalInset : spacing.s;
    final padding = EdgeInsetsDirectional.fromSTEB(
      horizontalInset,
      headerAwareTopInset,
      horizontalInset,
      verticalInset,
    );
    final shortcuts = enabled && sendEnabled && sendOnEnter
        ? const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): _SendMessageIntent(),
          }
        : const <ShortcutActivator, Intent>{};
    final actionsMap = {
      _SendMessageIntent: CallbackAction<_SendMessageIntent>(
        onInvoke: (_) {
          if (enabled && sendEnabled) onSend();
          return null;
        },
      ),
    };

    final textStyle = context.textTheme.p.copyWith(height: 1.2);
    final textStrutStyle = StrutStyle.fromTextStyle(
      textStyle,
      forceStrutHeight: true,
      height: textStyle.height,
      leading: 0,
    );
    final cutoutGap = spacing.xxs;
    final iconButtonSize = sizing.iconButtonSize;
    final defaultCutoutThickness = iconButtonSize + (cutoutGap * 2);
    final defaultCutoutDepth = (iconButtonSize / 2) + cutoutGap;
    final defaultCutoutCornerRadius = context.radii.squircle;

    return CutoutSurface(
      backgroundColor: colors.card,
      borderColor: context.borderSide.color,
      shape: SquircleBorder(
        cornerRadius: defaultCutoutCornerRadius,
        side: BorderSide(
          color: context.borderSide.color,
          width: context.borderSide.width,
        ),
      ),
      cutouts: actions
          .map(
            (action) => CutoutSpec(
              edge: action.edge,
              alignment: action.alignment ?? _alignmentFor(action.edge),
              depth: action.depth ?? defaultCutoutDepth,
              thickness: action.thickness ?? defaultCutoutThickness,
              cornerRadius: action.cornerRadius ?? defaultCutoutCornerRadius,
              child: action.child,
            ),
          )
          .toList(),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[
              Padding(
                padding: EdgeInsets.only(bottom: spacing.xxs),
                child: header!,
              ),
              ShadSeparator.horizontal(
                thickness: context.borderSide.width,
                color: context.borderSide.color,
                margin: EdgeInsets.zero,
              ),
              SizedBox(height: spacing.s),
            ],
            Shortcuts(
              shortcuts: shortcuts,
              child: Actions(
                actions: actionsMap,
                child: Semantics(
                  label: semanticsLabel ?? hintText,
                  textField: true,
                  child: AxiTextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: true,
                    readOnly: !enabled,
                    showCursor: enabled,
                    enableInteractiveSelection: enabled,
                    minLines: minLines,
                    maxLines: maxLines,
                    keyboardType: TextInputType.multiline,
                    textInputAction: sendOnEnter
                        ? TextInputAction.send
                        : TextInputAction.newline,
                    style: textStyle,
                    strutStyle: textStrutStyle,
                    cursorHeight: textStyle.fontSize,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: hintText,
                      hintStyle: context.textTheme.muted.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                    onSubmitted: (_) {
                      if (enabled && sendEnabled && sendOnEnter) onSend();
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Alignment _alignmentFor(CutoutEdge edge) {
    switch (edge) {
      case CutoutEdge.left:
        return const Alignment(-1, 0);
      case CutoutEdge.right:
        return const Alignment(1, 0);
      case CutoutEdge.top:
        return const Alignment(0, -1);
      case CutoutEdge.bottom:
        return const Alignment(0, 1);
    }
  }
}

class _SendMessageIntent extends Intent {
  const _SendMessageIntent();
}
