import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _kCutoutDepth = 30;
const double _kCutoutThickness = 49;
const double _kCutoutCornerRadius = 18;
const double _kHorizontalInset = 34;
const double _kVerticalInset = 20;

class ChatComposerAccessory {
  const ChatComposerAccessory({
    required this.child,
    required this.edge,
    this.alignment,
    this.depth = _kCutoutDepth,
    this.thickness = _kCutoutThickness,
    this.cornerRadius = _kCutoutCornerRadius,
  });

  final Widget child;
  final CutoutEdge edge;
  final Alignment? alignment;
  final double depth;
  final double thickness;
  final double cornerRadius;

  factory ChatComposerAccessory.leading({
    required Widget child,
    double depth = _kCutoutDepth,
    double thickness = _kCutoutThickness,
    double cornerRadius = _kCutoutCornerRadius,
  }) {
    return ChatComposerAccessory(
      child: child,
      edge: CutoutEdge.left,
      alignment: const Alignment(-1.04, 0),
      depth: depth,
      thickness: thickness,
      cornerRadius: cornerRadius,
    );
  }

  factory ChatComposerAccessory.trailing({
    required Widget child,
    double depth = _kCutoutDepth,
    double thickness = _kCutoutThickness,
    double cornerRadius = _kCutoutCornerRadius,
  }) {
    return ChatComposerAccessory(
      child: child,
      edge: CutoutEdge.right,
      alignment: const Alignment(1.02, 0),
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
    this.minLines = 1,
    this.maxLines = 6,
    this.header,
    this.semanticsLabel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final VoidCallback onSend;
  final List<ChatComposerAccessory> actions;
  final bool sendEnabled;
  final int minLines;
  final int maxLines;
  final Widget? header;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textScaler = MediaQuery.of(context).textScaler;
    double scaled(double value) => textScaler.scale(value);
    final horizontalInset = scaled(_kHorizontalInset);
    final verticalInset = scaled(_kVerticalInset);
    final headerAwareTopInset = header == null ? verticalInset : scaled(8);
    final padding = EdgeInsetsDirectional.fromSTEB(
      horizontalInset,
      headerAwareTopInset,
      horizontalInset,
      verticalInset,
    );
    final shortcuts = sendEnabled
        ? const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): _SendMessageIntent(),
          }
        : const <ShortcutActivator, Intent>{};
    final actionsMap = {
      _SendMessageIntent: CallbackAction<_SendMessageIntent>(
        onInvoke: (_) {
          if (sendEnabled) onSend();
          return null;
        },
      ),
    };

    final textStyle = context.textTheme.p.copyWith(
      fontSize: 16,
      height: 1.35,
    );
    final cursorHeight = textStyle.fontSize == null
        ? null
        : textScaler.scale(textStyle.fontSize!) * (textStyle.height ?? 1);

    return CutoutSurface(
      backgroundColor: colors.card,
      borderColor: colors.border,
      shape: SquircleBorder(
        cornerRadius: scaled(18),
        side: BorderSide(color: colors.border),
      ),
      cutouts: actions
          .map(
            (action) => CutoutSpec(
              edge: action.edge,
              alignment: action.alignment ?? _alignmentFor(action.edge),
              depth: action.depth,
              thickness: action.thickness,
              cornerRadius: action.cornerRadius,
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
                padding: EdgeInsets.only(bottom: scaled(2)),
                child: header!,
              ),
              Divider(
                height: 1,
                thickness: scaled(1),
                color: colors.border.withValues(alpha: 0.5),
              ),
              SizedBox(height: scaled(8)),
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
                    minLines: minLines,
                    maxLines: maxLines,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: textStyle,
                    cursorHeight: cursorHeight,
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
                      if (sendEnabled) onSend();
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
