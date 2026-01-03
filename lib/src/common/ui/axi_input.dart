// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' hide SpellCheckConfiguration;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide SpellCheckConfiguration;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/src/components/disabled.dart';
import 'package:shadcn_ui/src/theme/components/decorator.dart';
import 'package:shadcn_ui/src/theme/theme.dart';
import 'package:shadcn_ui/src/utils/separated_iterable.dart';

import 'package:axichat/src/settings/bloc/settings_cubit.dart';

import 'axi_editable_text.dart' as axi;
import 'axi_spell_check.dart';
import 'axi_system_context_menu.dart';
import 'axi_text_selection.dart';
import 'typing_text_input.dart';

const double _transparentCursorAlpha = 0.0;
const int _singleLineCount = 1;

class AxiInput extends StatefulWidget {
  const AxiInput({
    super.key,
    this.initialValue,
    this.placeholder,
    this.controller,
    this.focusNode,
    this.decoration,
    this.undoController,
    TextInputType? keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.readOnly = false,
    this.showCursor,
    this.autofocus = false,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    SmartDashesType? smartDashesType,
    SmartQuotesType? smartQuotesType,
    this.enableSuggestions = true,
    this.maxLines = _singleLineCount,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onAppPrivateCommand,
    this.inputFormatters,
    this.enabled = true,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorOpacityAnimates,
    this.cursorColor,
    this.selectionHeightStyle = ui.BoxHeightStyle.tight,
    this.selectionWidthStyle = ui.BoxWidthStyle.tight,
    this.keyboardAppearance,
    this.scrollPadding = const EdgeInsets.all(20),
    this.dragStartBehavior = DragStartBehavior.start,
    bool? enableInteractiveSelection,
    this.selectionControls,
    this.onPressed,
    this.onPressedAlwaysCalled = false,
    this.onPressedOutside,
    this.mouseCursor,
    this.scrollController,
    this.scrollPhysics,
    this.autofillHints = const <String>[],
    this.contentInsertionConfiguration,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.scribbleEnabled = true,
    this.enableIMEPersonalizedLearning = true,
    this.contextMenuBuilder,
    this.spellCheckConfiguration,
    this.magnifierConfiguration = TextMagnifierConfiguration.disabled,
    this.selectionColor,
    this.padding,
    this.leading,
    this.trailing,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.placeholderStyle,
    this.placeholderAlignment,
    this.inputPadding,
    this.gap,
    this.constraints,
    this.stylusHandwritingEnabled =
        axi.EditableText.defaultStylusHandwritingEnabled,
    this.groupId,
    this.scrollbarPadding,
  })  : smartDashesType = smartDashesType ??
            (obscureText ? SmartDashesType.disabled : SmartDashesType.enabled),
        smartQuotesType = smartQuotesType ??
            (obscureText ? SmartQuotesType.disabled : SmartQuotesType.enabled),
        keyboardType = keyboardType ??
            (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
        enableInteractiveSelection =
            enableInteractiveSelection ?? (!readOnly || !obscureText),
        assert(
          initialValue == null || controller == null,
          'Either initialValue or controller must be specified',
        );

  final String? initialValue;

  final Widget? placeholder;

  final TextEditingController? controller;

  final FocusNode? focusNode;

  final ShadDecoration? decoration;

  final UndoHistoryController? undoController;

  final TextInputType keyboardType;

  final TextInputAction? textInputAction;

  final TextCapitalization textCapitalization;

  final TextStyle? style;

  final StrutStyle? strutStyle;

  final TextAlign textAlign;

  final TextDirection? textDirection;

  final bool readOnly;

  final bool? showCursor;

  final bool autofocus;

  final String obscuringCharacter;

  final bool obscureText;

  final bool autocorrect;

  final SmartDashesType smartDashesType;

  final SmartQuotesType smartQuotesType;

  final bool enableSuggestions;

  final int? maxLines;

  final int? minLines;

  final bool expands;

  final int? maxLength;

  final MaxLengthEnforcement? maxLengthEnforcement;

  final ValueChanged<String>? onChanged;

  final VoidCallback? onEditingComplete;

  final ValueChanged<String>? onSubmitted;

  final AppPrivateCommandCallback? onAppPrivateCommand;

  final List<TextInputFormatter>? inputFormatters;

  final bool enabled;

  final double cursorWidth;

  final double? cursorHeight;

  final Radius? cursorRadius;

  final bool? cursorOpacityAnimates;

  final Color? cursorColor;

  final ui.BoxHeightStyle selectionHeightStyle;

  final ui.BoxWidthStyle selectionWidthStyle;

  final Brightness? keyboardAppearance;

  final EdgeInsets scrollPadding;

  final DragStartBehavior dragStartBehavior;

  final bool enableInteractiveSelection;

  final TextSelectionControls? selectionControls;

  final GestureTapCallback? onPressed;

  final bool onPressedAlwaysCalled;

  final TapRegionCallback? onPressedOutside;

  final MouseCursor? mouseCursor;

  final ScrollController? scrollController;

  final ScrollPhysics? scrollPhysics;

  final Iterable<String>? autofillHints;

  final ContentInsertionConfiguration? contentInsertionConfiguration;

  final Clip clipBehavior;

  final String? restorationId;

  final bool scribbleEnabled;

  final bool stylusHandwritingEnabled;

  final bool enableIMEPersonalizedLearning;

  final axi.EditableTextContextMenuBuilder? contextMenuBuilder;

  final SpellCheckConfiguration? spellCheckConfiguration;

  final TextMagnifierConfiguration magnifierConfiguration;

  final Color? selectionColor;

  final EdgeInsets? padding;

  final Widget? leading;

  final Widget? trailing;

  final MainAxisAlignment? mainAxisAlignment;

  final CrossAxisAlignment? crossAxisAlignment;

  final TextStyle? placeholderStyle;

  final Alignment? placeholderAlignment;

  final EdgeInsets? inputPadding;

  final double? gap;

  final BoxConstraints? constraints;

  final Object? groupId;

  final EdgeInsets? scrollbarPadding;

  static const int noMaxLength = -1;

  bool get selectionEnabled => enableInteractiveSelection;

  @override
  State<AxiInput> createState() => AxiInputState();
}

class AxiInputState extends State<AxiInput>
    with RestorationMixin
    implements AxiTextSelectionGestureDetectorBuilderDelegate {
  // ignore: use_late_for_private_fields_and_variables
  FocusNode? _focusNode;
  FocusNode get effectiveFocusNode => widget.focusNode ?? _focusNode!;
  final hasFocus = ValueNotifier(false);
  RestorableTextEditingController? _controller;
  TextEditingController get _sourceController =>
      widget.controller ?? _controller!.value;
  late TypingTextEditingController _typingController;
  TextEditingController get effectiveController => _typingController;
  bool _showSelectionHandles = false;
  final _groupId = UniqueKey();

  ScrollController? _scrollController;

  ScrollController get effectiveScrollController =>
      widget.scrollController ?? _scrollController!;

  bool get isScrollable {
    if (!effectiveScrollController.hasClients) {
      return false;
    }
    return effectiveScrollController.position.maxScrollExtent > 0;
  }

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _focusNode = FocusNode(canRequestFocus: !widget.readOnly);
    }
    effectiveFocusNode.addListener(onFocusChange);

    if (widget.controller == null) {
      _createLocalController(TextEditingValue(text: widget.initialValue ?? ''));
    }
    _typingController = TypingTextEditingController(source: _sourceController);
    if (widget.scrollController == null) _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(AxiInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(onFocusChange);
      effectiveFocusNode.addListener(onFocusChange);
    }
    if (widget.controller == null && oldWidget.controller != null) {
      _createLocalController(oldWidget.controller!.value);
    } else if (widget.controller != null && oldWidget.controller == null) {
      unregisterFromRestoration(_controller!);
      _controller!.dispose();
      _controller = null;
    }
    _typingController.updateSource(_sourceController, null);

    if (widget.readOnly != oldWidget.readOnly) {
      effectiveFocusNode.canRequestFocus = !widget.readOnly;
      if (effectiveFocusNode.hasFocus &&
          effectiveController.selection.isCollapsed) {
        _showSelectionHandles = !widget.readOnly;
      }
    }
  }

  @override
  void dispose() {
    effectiveFocusNode.removeListener(onFocusChange);

    if (widget.focusNode == null) effectiveFocusNode.dispose();
    _controller?.dispose();
    _typingController.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  void _registerController() {
    assert(_controller != null);
    registerForRestoration(_controller!, 'controller');
  }

  void _createLocalController([TextEditingValue? value]) {
    assert(_controller == null);
    _controller = value == null
        ? RestorableTextEditingController()
        : RestorableTextEditingController.fromValue(value);
    if (!restorePending) {
      _registerController();
    }
  }

  void onFocusChange() {
    hasFocus.value = effectiveFocusNode.hasFocus;
  }

  @override
  final GlobalKey<axi.EditableTextState> editableTextKey =
      GlobalKey<axi.EditableTextState>();

  late final _selectionGestureDetectorBuilder =
      _AxiInputSelectionGestureDetectorBuilder(state: this);

  @override
  bool get forcePressEnabled {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS => true,
      _ => false,
    };
  }

  @override
  bool get selectionEnabled => widget.enableInteractiveSelection;

  @override
  String? get restorationId => widget.restorationId;

  axi.EditableTextState? get _editableText => editableTextKey.currentState;

  bool get isMultiline {
    final int? maxLines =
        widget.obscureText ? _singleLineCount : widget.maxLines;
    return maxLines != _singleLineCount;
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    if (_controller != null) _registerController();
  }

  void _handleSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    final willShowSelectionHandles = _shouldShowSelectionHandles(cause);
    if (willShowSelectionHandles != _showSelectionHandles) {
      setState(() {
        _showSelectionHandles = willShowSelectionHandles;
      });
    }

    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
      case TargetPlatform.android:
        if (cause == SelectionChangedCause.longPress) {
          _editableText?.bringIntoView(selection.extent);
        }
    }

    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.android:
        break;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        if (cause == SelectionChangedCause.drag) {
          _editableText?.hideToolbar();
        }
    }
  }

  bool _shouldShowSelectionHandles(SelectionChangedCause? cause) {
    // When the text field is activated by something that doesn't trigger the
    // selection overlay, we shouldn't show the handles either.
    if (!_selectionGestureDetectorBuilder.shouldShowSelectionToolbar) {
      return false;
    }

    if (cause == SelectionChangedCause.keyboard) {
      return false;
    }

    if (widget.readOnly && effectiveController.selection.isCollapsed) {
      return false;
    }

    if (!widget.enabled) {
      return false;
    }

    if (cause == SelectionChangedCause.longPress ||
        // ignore: deprecated_member_use
        cause == SelectionChangedCause.scribble) {
      return true;
    }

    if (effectiveController.text.isNotEmpty) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final materialTheme = Theme.of(context);
    final effectiveTextStyle = theme.textTheme.muted
        .copyWith(
          color: theme.colorScheme.foreground,
        )
        .merge(theme.inputTheme.style)
        .merge(widget.style);

    final effectiveDecoration =
        (theme.inputTheme.decoration ?? const ShadDecoration())
            .mergeWith(widget.decoration);

    final effectivePadding = widget.padding ??
        theme.inputTheme.padding ??
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    final effectiveInputPadding =
        widget.inputPadding ?? theme.inputTheme.inputPadding ?? EdgeInsets.zero;

    final effectivePlaceholderStyle = theme.textTheme.muted
        .merge(theme.inputTheme.placeholderStyle)
        .merge(widget.placeholderStyle);

    final effectivePlaceholderAlignment = widget.placeholderAlignment ??
        theme.inputTheme.placeholderAlignment ??
        Alignment.topLeft;

    final effectiveMainAxisAlignment = widget.mainAxisAlignment ??
        theme.inputTheme.mainAxisAlignment ??
        MainAxisAlignment.start;

    final effectiveCrossAxisAlignment = widget.crossAxisAlignment ??
        theme.inputTheme.crossAxisAlignment ??
        CrossAxisAlignment.center;
    final effectiveMouseCursor =
        widget.mouseCursor ?? WidgetStateMouseCursor.textable;

    final effectiveGap = widget.gap ?? theme.inputTheme.gap ?? 8.0;

    final defaultSelectionControls = switch (Theme.of(context).platform) {
      TargetPlatform.iOS => cupertinoTextSelectionHandleControls,
      TargetPlatform.macOS => cupertinoDesktopTextSelectionHandleControls,
      TargetPlatform.android ||
      TargetPlatform.fuchsia =>
        materialTextSelectionHandleControls,
      TargetPlatform.linux ||
      TargetPlatform.windows =>
        desktopTextSelectionHandleControls,
    };
    final effectiveSelectionControls =
        widget.selectionControls ?? defaultSelectionControls;

    final effectiveContextMenuBuilder = widget.contextMenuBuilder ??
        (context, editableState) {
          final bool supportsSystemMenu =
              AxiSystemContextMenu.isSupported(context) &&
                  !editableState.widget.readOnly;
          if (supportsSystemMenu) {
            return AxiSystemContextMenu.editableText(
              editableTextState: editableState,
            );
          }
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editableState.contextMenuAnchors,
            buttonItems: editableState.contextMenuButtonItems,
          );
        };
    final Color resolvedCursorColor =
        widget.cursorColor ?? theme.colorScheme.primary;
    final Color transparentCursorColor =
        resolvedCursorColor.withValues(alpha: _transparentCursorAlpha);

    final effectiveMaxLengthEnforcement = widget.maxLengthEnforcement ??
        LengthLimitingTextInputFormatter.getDefaultMaxLengthEnforcement(
          Theme.of(context).platform,
        );

    final effectiveInputFormatters = <TextInputFormatter>[
      ...?widget.inputFormatters,
      if (widget.maxLength != null)
        LengthLimitingTextInputFormatter(
          widget.maxLength,
          maxLengthEnforcement: effectiveMaxLengthEnforcement,
        ),
    ];
    final bool isObscured = widget.obscureText;
    final int? effectiveMaxLines =
        isObscured ? _singleLineCount : widget.maxLines;
    final int? effectiveMinLines =
        isObscured ? _singleLineCount : widget.minLines;
    final bool effectiveExpands = isObscured ? false : widget.expands;

    final textScaler = MediaQuery.textScalerOf(context);

    final maxFontSize = max(
      (effectivePlaceholderStyle.fontSize ?? 0) *
          (effectivePlaceholderStyle.height ?? 0),
      (effectiveTextStyle.fontSize ?? 0) * (effectiveTextStyle.height ?? 0),
    );
    final maxFontSizeScaled = textScaler.scale(maxFontSize);

    final effectiveConstraints = widget.constraints ??
        BoxConstraints(
          minHeight: maxFontSizeScaled,
        );

    final effectiveGroupId = widget.groupId ?? _groupId;

    final effectiveScrollbarPadding =
        widget.scrollbarPadding ?? theme.inputTheme.scrollbarPadding;

    return ShadDisabled(
      disabled: !widget.enabled,
      child: _selectionGestureDetectorBuilder.buildGestureDetector(
        behavior: HitTestBehavior.translucent,
        child: ValueListenableBuilder(
          valueListenable: hasFocus,
          builder: (context, focused, _) {
            return ValueListenableBuilder(
              valueListenable: effectiveController,
              builder: (context, textEditingValue, child) {
                return ShadDecorator(
                  decoration: effectiveDecoration,
                  focused: focused,
                  child: RawScrollbar(
                    mainAxisMargin:
                        materialTheme.scrollbarTheme.mainAxisMargin ?? 0,
                    crossAxisMargin:
                        materialTheme.scrollbarTheme.crossAxisMargin ?? 0,
                    radius: materialTheme.scrollbarTheme.radius,
                    thickness:
                        materialTheme.scrollbarTheme.thickness?.resolve({}),
                    thumbVisibility: isMultiline && isScrollable,
                    controller: effectiveScrollController,
                    padding: effectiveScrollbarPadding,
                    child: SingleChildScrollView(
                      controller: effectiveScrollController,
                      padding: effectivePadding,
                      physics: widget.scrollPhysics,
                      child: Row(
                        mainAxisAlignment: effectiveMainAxisAlignment,
                        crossAxisAlignment: effectiveCrossAxisAlignment,
                        children: [
                          if (widget.leading != null) widget.leading!,
                          Flexible(
                            child: ConstrainedBox(
                              constraints: effectiveConstraints,
                              child: AbsorbPointer(
                                // AbsorbPointer is needed when the input is
                                // readOnly so the onTap callback is fired on
                                // each part of the input
                                absorbing: widget.readOnly,
                                child: Padding(
                                  padding: effectiveInputPadding,
                                  child: Stack(
                                    children: [
                                      // placeholder
                                      if (textEditingValue.text.isEmpty &&
                                          widget.placeholder != null)
                                        Positioned.fill(
                                          child: Align(
                                            alignment:
                                                effectivePlaceholderAlignment,
                                            child: DefaultTextStyle(
                                              style: effectivePlaceholderStyle,
                                              child: widget.placeholder!,
                                            ),
                                          ),
                                        ),
                                      RepaintBoundary(
                                        child: UnmanagedRestorationScope(
                                          bucket: bucket,
                                          child: axi.EditableText(
                                            showSelectionHandles:
                                                _showSelectionHandles,
                                            key: editableTextKey,
                                            controller: effectiveController,
                                            obscuringCharacter:
                                                widget.obscuringCharacter,
                                            readOnly: widget.readOnly,
                                            focusNode: effectiveFocusNode,
                                            // ! Selection handler section here
                                            onSelectionChanged:
                                                _handleSelectionChanged,
                                            selectionColor: focused
                                                ? widget.selectionColor ??
                                                    theme.colorScheme.selection
                                                : null,
                                            selectionHeightStyle:
                                                widget.selectionHeightStyle,
                                            selectionWidthStyle:
                                                widget.selectionWidthStyle,
                                            contextMenuBuilder:
                                                effectiveContextMenuBuilder,
                                            selectionControls:
                                                effectiveSelectionControls,
                                            // ! End of selection handler
                                            // ! section
                                            mouseCursor: effectiveMouseCursor,
                                            enableInteractiveSelection: widget
                                                .enableInteractiveSelection,
                                            style: effectiveTextStyle,
                                            strutStyle: widget.strutStyle,
                                            cursorColor: transparentCursorColor,
                                            typingCaretColor:
                                                resolvedCursorColor,
                                            typingAnimationDuration: context
                                                .watch<SettingsCubit>()
                                                .animationDuration,
                                            backgroundCursorColor: Colors.grey,
                                            keyboardType: widget.keyboardType,
                                            keyboardAppearance:
                                                widget.keyboardAppearance ??
                                                    theme.brightness,
                                            textInputAction:
                                                widget.textInputAction,
                                            textCapitalization:
                                                widget.textCapitalization,
                                            autofocus: widget.autofocus,
                                            obscureText: widget.obscureText,
                                            autocorrect: widget.autocorrect,
                                            magnifierConfiguration:
                                                widget.magnifierConfiguration,
                                            smartDashesType:
                                                widget.smartDashesType,
                                            smartQuotesType:
                                                widget.smartQuotesType,
                                            enableSuggestions:
                                                widget.enableSuggestions,
                                            maxLines: effectiveMaxLines,
                                            minLines: effectiveMinLines,
                                            expands: effectiveExpands,
                                            onChanged: widget.onChanged,
                                            onEditingComplete:
                                                widget.onEditingComplete,
                                            onSubmitted: widget.onSubmitted,
                                            onAppPrivateCommand:
                                                widget.onAppPrivateCommand,
                                            inputFormatters:
                                                effectiveInputFormatters,
                                            cursorWidth: widget.cursorWidth,
                                            cursorHeight: widget.cursorHeight,
                                            cursorRadius: widget.cursorRadius,
                                            scrollPadding: widget.scrollPadding,
                                            dragStartBehavior:
                                                widget.dragStartBehavior,
                                            scrollPhysics: widget.scrollPhysics,
                                            // Disable the internal scrollbars
                                            // because there is already a
                                            // Scrollbar above.
                                            scrollBehavior:
                                                ScrollConfiguration.of(
                                              context,
                                            ).copyWith(
                                              scrollbars: false,
                                              overscroll: false,
                                            ),
                                            autofillHints: widget.autofillHints,
                                            clipBehavior: widget.clipBehavior,
                                            restorationId: 'editable',
                                            // ignore: deprecated_member_use
                                            scribbleEnabled:
                                                widget.scribbleEnabled,
                                            stylusHandwritingEnabled:
                                                widget.stylusHandwritingEnabled,
                                            // ignore: lines_longer_than_80_chars
                                            enableIMEPersonalizedLearning: widget
                                                .enableIMEPersonalizedLearning,
                                            // ignore: lines_longer_than_80_chars
                                            contentInsertionConfiguration: widget
                                                .contentInsertionConfiguration,
                                            undoController:
                                                widget.undoController,
                                            spellCheckConfiguration:
                                                widget.spellCheckConfiguration,
                                            textAlign: widget.textAlign,
                                            onTapOutside:
                                                widget.onPressedOutside,
                                            rendererIgnoresPointer: true,
                                            showCursor: widget.showCursor,
                                            groupId: effectiveGroupId,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (widget.trailing != null) widget.trailing!,
                        ].separatedBy(SizedBox(width: effectiveGap)),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AxiInputSelectionGestureDetectorBuilder
    extends AxiTextSelectionGestureDetectorBuilder {
  _AxiInputSelectionGestureDetectorBuilder({
    required AxiInputState state,
  })  : _state = state,
        super(delegate: state);

  final AxiInputState _state;

  @override
  void onForcePressStart(ForcePressDetails details) {
    super.onForcePressStart(details);
    if (delegate.selectionEnabled && shouldShowSelectionToolbar) {
      editableText.showToolbar();
    }
  }

  @override
  void onForcePressEnd(ForcePressDetails details) {
    // Not required.
  }

  @override
  void onUserTap() {
    _state.widget.onPressed?.call();
  }

  @override
  bool get onUserTapAlwaysCalled => _state.widget.onPressedAlwaysCalled;

  @override
  void onSingleLongTapStart(LongPressStartDetails details) {
    super.onSingleLongTapStart(details);
    if (delegate.selectionEnabled) {
      switch (Theme.of(_state.context).platform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          break;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          Feedback.forLongPress(_state.context);
      }
    }
  }
}
