// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'axi_editable_text.dart' as axi;

abstract class AxiTextSelectionGestureDetectorBuilderDelegate {
  GlobalKey<axi.EditableTextState> get editableTextKey;

  bool get forcePressEnabled;

  bool get selectionEnabled;
}

class AxiTextSelectionGestureDetectorBuilder {
  AxiTextSelectionGestureDetectorBuilder({required this.delegate});

  @protected
  final AxiTextSelectionGestureDetectorBuilderDelegate delegate;

  int _effectiveConsecutiveTapCount(int rawCount) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        return rawCount <= 3
            ? rawCount
            : (rawCount % 3 == 0 ? 3 : rawCount % 3);
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return math.min(rawCount, 3);
      case TargetPlatform.windows:
        return rawCount < 2 ? rawCount : 2 + rawCount % 2;
    }
  }

  // Shows the magnifier on supported platforms at the given offset, currently
  // only Android and iOS.
  void _showMagnifierIfSupportedByPlatform(Offset positionToShow) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        editableText.showMagnifier(positionToShow);
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
    }
  }

  // Hides the magnifier on supported platforms, currently only Android and iOS.
  void _hideMagnifierIfSupportedByPlatform() {
    if (!_isEditableTextMounted) {
      return;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        editableText.hideMagnifier();
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
    }
  }

  bool get _lastSecondaryTapWasOnSelection {
    assert(renderEditable.lastSecondaryTapDownPosition != null);
    if (renderEditable.selection == null) {
      return false;
    }

    final TextPosition textPosition = renderEditable.getPositionForPoint(
      renderEditable.lastSecondaryTapDownPosition!,
    );

    return renderEditable.selection!.start <= textPosition.offset &&
        renderEditable.selection!.end >= textPosition.offset;
  }

  bool _positionWasOnSelectionExclusive(TextPosition textPosition) {
    final TextSelection? selection = renderEditable.selection;
    if (selection == null) {
      return false;
    }

    return selection.start < textPosition.offset &&
        selection.end > textPosition.offset;
  }

  bool _positionWasOnSelectionInclusive(TextPosition textPosition) {
    final TextSelection? selection = renderEditable.selection;
    if (selection == null) {
      return false;
    }

    return selection.start <= textPosition.offset &&
        selection.end >= textPosition.offset;
  }

  // Expand the selection to the given global position.
  //
  // Either base or extent will be moved to the last tapped position, whichever
  // is closest. The selection will never shrink or pivot, only grow.
  //
  // If fromSelection is given, will expand from that selection instead of the
  // current selection in renderEditable.
  //
  // See also:
  //
  //   * [_extendSelection], which is similar but pivots the selection around
  //     the base.
  void _expandSelection(
    Offset offset,
    SelectionChangedCause cause, [
    TextSelection? fromSelection,
  ]) {
    assert(renderEditable.selection?.baseOffset != null);

    final TextPosition tappedPosition =
        renderEditable.getPositionForPoint(offset);
    final TextSelection selection = fromSelection ?? renderEditable.selection!;
    final bool baseIsCloser =
        (tappedPosition.offset - selection.baseOffset).abs() <
            (tappedPosition.offset - selection.extentOffset).abs();
    final TextSelection nextSelection = selection.copyWith(
      baseOffset: baseIsCloser ? selection.extentOffset : selection.baseOffset,
      extentOffset: tappedPosition.offset,
    );

    editableText.userUpdateTextEditingValue(
      editableText.textEditingValue.copyWith(selection: nextSelection),
      cause,
    );
  }

  // Extend the selection to the given global position.
  //
  // Holds the base in place and moves the extent.
  //
  // See also:
  //
  //   * [_expandSelection], which is similar but always increases the size of
  //     the selection.
  void _extendSelection(Offset offset, SelectionChangedCause cause) {
    assert(renderEditable.selection?.baseOffset != null);

    final TextPosition tappedPosition =
        renderEditable.getPositionForPoint(offset);
    final TextSelection selection = renderEditable.selection!;
    final TextSelection nextSelection =
        selection.copyWith(extentOffset: tappedPosition.offset);

    editableText.userUpdateTextEditingValue(
      editableText.textEditingValue.copyWith(selection: nextSelection),
      cause,
    );
  }

  bool get shouldShowSelectionToolbar => _shouldShowSelectionToolbar;
  bool _shouldShowSelectionToolbar = true;

  bool get shouldShowSelectionHandles => _shouldShowSelectionHandles;
  bool _shouldShowSelectionHandles = true;

  @protected
  axi.EditableTextState get editableText =>
      delegate.editableTextKey.currentState!;

  @protected
  RenderEditable get renderEditable => editableText.renderEditable;

  bool get _isEditableTextMounted =>
      delegate.editableTextKey.currentContext?.mounted ?? false;

  bool _isShiftPressed = false;

  double _dragStartScrollOffset = 0.0;

  double _dragStartViewportOffset = 0.0;

  double get _scrollPosition {
    final ScrollableState? scrollableState =
        delegate.editableTextKey.currentContext == null
            ? null
            : Scrollable.maybeOf(delegate.editableTextKey.currentContext!);
    return scrollableState == null ? 0.0 : scrollableState.position.pixels;
  }

  AxisDirection? get _scrollDirection {
    final ScrollableState? scrollableState =
        delegate.editableTextKey.currentContext == null
            ? null
            : Scrollable.maybeOf(delegate.editableTextKey.currentContext!);
    return scrollableState?.axisDirection;
  }

  // For a shift + tap + drag gesture, the TextSelection at the point of the
  // tap. Mac uses this value to reset to the original selection when an
  // inversion of the base and offset happens.
  TextSelection? _dragStartSelection;

  // For iOS long press behavior when the field is not focused. iOS uses this value
  // to determine if a long press began on a field that was not focused.
  //
  // If the field was not focused when the long press began, a long press will select
  // the word and a long press move will select word-by-word. If the field was
  // focused, the cursor moves to the long press position.
  bool _longPressStartedWithoutFocus = false;

  @protected
  void onTapTrackStart() {
    _isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed.intersection(
      <LogicalKeyboardKey>{
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.shiftRight
      },
    ).isNotEmpty;
  }

  @protected
  void onTapTrackReset() {
    _isShiftPressed = false;
  }

  @protected
  void onTapDown(TapDragDownDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }

    // TODO(Renzo-Olivares): Migrate text selection gestures away from saving state
    // in renderEditable. The gesture callbacks can use the details objects directly
    // in callbacks variants that provide them [TapGestureRecognizer.onSecondaryTap]
    // vs [TapGestureRecognizer.onSecondaryTapUp] instead of having to track state in
    // renderEditable. When this migration is complete we should remove this hack.
    // See https://github.com/flutter/flutter/issues/115130.
    renderEditable
        .handleTapDown(TapDownDetails(globalPosition: details.globalPosition));
    // The selection overlay should only be shown when the user is interacting
    // through a touch screen (via either a finger or a stylus). A mouse shouldn't
    // trigger the selection overlay.
    // For backwards-compatibility, we treat a null kind the same as touch.
    final PointerDeviceKind? kind = details.kind;
    // TODO(justinmc): Should a desktop platform show its selection toolbar when
    // receiving a tap event?  Say a Windows device with a touchscreen.
    // https://github.com/flutter/flutter/issues/106586
    _shouldShowSelectionToolbar = kind == null ||
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus;
    _shouldShowSelectionHandles = _shouldShowSelectionToolbar;

    // It is impossible to extend the selection when the shift key is pressed, if the
    // renderEditable.selection is invalid.
    final bool isShiftPressedValid =
        _isShiftPressed && renderEditable.selection?.baseOffset != null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (editableText.widget.stylusHandwritingEnabled) {
          final bool stylusEnabled = switch (kind) {
            PointerDeviceKind.stylus ||
            PointerDeviceKind.invertedStylus =>
              editableText.widget.stylusHandwritingEnabled,
            _ => false,
          };
          if (stylusEnabled) {
            Scribe.isFeatureAvailable().then((bool isAvailable) {
              if (isAvailable) {
                renderEditable.selectPosition(
                    cause: SelectionChangedCause.stylusHandwriting);
                Scribe.startStylusHandwriting();
              }
            });
          }
        }
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        // On mobile platforms the selection is set on tap up.
        break;
      case TargetPlatform.macOS:
        editableText.hideToolbar();
        // On macOS, a shift-tapped unfocused field expands from 0, not from the
        // previous selection.
        if (isShiftPressedValid) {
          final TextSelection? fromSelection = renderEditable.hasFocus
              ? null
              : const TextSelection.collapsed(offset: 0);
          _expandSelection(
              details.globalPosition, SelectionChangedCause.tap, fromSelection);
          return;
        }
        // On macOS, a tap/click places the selection in a precise position.
        // This differs from iOS/iPadOS, where if the gesture is done by a touch
        // then the selection moves to the closest word edge, instead of a
        // precise position.
        renderEditable.selectPosition(cause: SelectionChangedCause.tap);
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        editableText.hideToolbar();
        if (isShiftPressedValid) {
          _extendSelection(details.globalPosition, SelectionChangedCause.tap);
          return;
        }
        renderEditable.selectPosition(cause: SelectionChangedCause.tap);
    }
  }

  @protected
  void onForcePressStart(ForcePressDetails details) {
    assert(delegate.forcePressEnabled);
    _shouldShowSelectionToolbar = true;
    if (!delegate.selectionEnabled) {
      return;
    }
    renderEditable.selectWordsInRange(
      from: details.globalPosition,
      cause: SelectionChangedCause.forcePress,
    );
    editableText.showToolbar();
  }

  @protected
  void onForcePressEnd(ForcePressDetails details) {
    assert(delegate.forcePressEnabled);
    renderEditable.selectWordsInRange(
      from: details.globalPosition,
      cause: SelectionChangedCause.forcePress,
    );
    if (shouldShowSelectionToolbar) {
      editableText.showToolbar();
    }
  }

  @protected
  bool get onUserTapAlwaysCalled => false;

  @protected
  void onUserTap() {
    /* Subclass should override this method if needed. */
  }

  @protected
  void onSingleTapUp(TapDragUpDetails details) {
    if (!delegate.selectionEnabled) {
      editableText.requestKeyboard();
      return;
    }
    // It is impossible to extend the selection when the shift key is pressed, if the
    // renderEditable.selection is invalid.
    final bool isShiftPressedValid =
        _isShiftPressed && renderEditable.selection?.baseOffset != null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        break;
      // On desktop platforms the selection is set on tap down.
      case TargetPlatform.android:
        editableText.hideToolbar(false);
        if (isShiftPressedValid) {
          _extendSelection(details.globalPosition, SelectionChangedCause.tap);
          return;
        }
        renderEditable.selectPosition(cause: SelectionChangedCause.tap);
        editableText.showSpellCheckSuggestionsToolbar();
      case TargetPlatform.fuchsia:
        editableText.hideToolbar(false);
        if (isShiftPressedValid) {
          _extendSelection(details.globalPosition, SelectionChangedCause.tap);
          return;
        }
        renderEditable.selectPosition(cause: SelectionChangedCause.tap);
      case TargetPlatform.iOS:
        if (isShiftPressedValid) {
          // On iOS, a shift-tapped unfocused field expands from 0, not from
          // the previous selection.
          final TextSelection? fromSelection = renderEditable.hasFocus
              ? null
              : const TextSelection.collapsed(offset: 0);
          _expandSelection(
              details.globalPosition, SelectionChangedCause.tap, fromSelection);
          return;
        }
        switch (details.kind) {
          case PointerDeviceKind.mouse:
          case PointerDeviceKind.trackpad:
          case PointerDeviceKind.stylus:
          case PointerDeviceKind.invertedStylus:
            // TODO(camsim99): Determine spell check toolbar behavior in these cases:
            // https://github.com/flutter/flutter/issues/119573.
            // Precise devices should place the cursor at a precise position if the
            // word at the text position is not misspelled.
            renderEditable.selectPosition(cause: SelectionChangedCause.tap);
            editableText.hideToolbar();
          case PointerDeviceKind.touch:
          case PointerDeviceKind.unknown:
            // If the word that was tapped is misspelled, select the word and show the spell check suggestions
            // toolbar once. If additional taps are made on a misspelled word, toggle the toolbar. If the word
            // is not misspelled, default to the following behavior:
            //
            // Toggle the toolbar when the tap is exclusively within the bounds of a non-collapsed `previousSelection`,
            // and the editable is focused.
            //
            // Toggle the toolbar if the `previousSelection` is collapsed, the tap is on the selection, the
            // TextAffinity remains the same, the editable field is not read only, and the editable is focused.
            // The TextAffinity is important when the cursor is on the boundary of a line wrap, if the affinity
            // is different (i.e. it is downstream), the selection should move to the following line and not toggle
            // the toolbar.
            //
            // Selects the word edge closest to the tap when the editable is not focused, or if the tap was neither exclusively
            // or inclusively on `previousSelection`. If the selection remains the same after selecting the word edge, then we
            // toggle the toolbar, if the editable field is not read only. If the selection changes then we hide the toolbar.
            final TextSelection previousSelection = renderEditable.selection ??
                editableText.textEditingValue.selection;
            final TextPosition textPosition =
                renderEditable.getPositionForPoint(
              details.globalPosition,
            );
            final bool isAffinityTheSame =
                textPosition.affinity == previousSelection.affinity;
            final bool wordAtCursorIndexIsMisspelled = editableText
                    .findSuggestionSpanAtCursorIndex(textPosition.offset) !=
                null;

            if (wordAtCursorIndexIsMisspelled) {
              renderEditable.selectWord(cause: SelectionChangedCause.tap);
              if (previousSelection !=
                  editableText.textEditingValue.selection) {
                editableText.showSpellCheckSuggestionsToolbar();
              } else {
                editableText.toggleToolbar(false);
              }
            } else if (((_positionWasOnSelectionExclusive(textPosition) &&
                        !previousSelection.isCollapsed) ||
                    (_positionWasOnSelectionInclusive(textPosition) &&
                        previousSelection.isCollapsed &&
                        isAffinityTheSame &&
                        !renderEditable.readOnly)) &&
                renderEditable.hasFocus) {
              editableText.toggleToolbar(false);
            } else {
              renderEditable.selectWordEdge(cause: SelectionChangedCause.tap);
              if (previousSelection ==
                      editableText.textEditingValue.selection &&
                  renderEditable.hasFocus &&
                  !renderEditable.readOnly) {
                editableText.toggleToolbar(false);
              } else {
                editableText.hideToolbar(false);
              }
            }
        }
    }
    editableText.requestKeyboard();
  }

  @protected
  void onSingleTapCancel() {
    /* Subclass should override this method if needed. */
  }

  @protected
  void onSingleLongTapStart(LongPressStartDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        if (!renderEditable.hasFocus) {
          _longPressStartedWithoutFocus = true;
          renderEditable.selectWord(cause: SelectionChangedCause.longPress);
        } else if (renderEditable.readOnly) {
          renderEditable.selectWord(cause: SelectionChangedCause.longPress);
          if (editableText.context.mounted) {
            Feedback.forLongPress(editableText.context);
          }
        } else {
          renderEditable.selectPositionAt(
            from: details.globalPosition,
            cause: SelectionChangedCause.longPress,
          );
          // Show the floating cursor.
          final RawFloatingCursorPoint cursorPoint = RawFloatingCursorPoint(
            state: FloatingCursorDragState.Start,
            startLocation: (
              renderEditable.globalToLocal(details.globalPosition),
              TextPosition(
                offset: editableText.textEditingValue.selection.baseOffset,
                affinity: editableText.textEditingValue.selection.affinity,
              ),
            ),
            offset: Offset.zero,
          );
          editableText.updateFloatingCursor(cursorPoint);
        }
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        renderEditable.selectWord(cause: SelectionChangedCause.longPress);
        if (editableText.context.mounted) {
          Feedback.forLongPress(editableText.context);
        }
    }

    _showMagnifierIfSupportedByPlatform(details.globalPosition);

    _dragStartViewportOffset = renderEditable.offset.pixels;
    _dragStartScrollOffset = _scrollPosition;
  }

  @protected
  void onSingleLongTapMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }
    // Adjust the drag start offset for possible viewport offset changes.
    final Offset editableOffset = renderEditable.maxLines == 1
        ? Offset(renderEditable.offset.pixels - _dragStartViewportOffset, 0.0)
        : Offset(0.0, renderEditable.offset.pixels - _dragStartViewportOffset);
    final Offset scrollableOffset = switch (axisDirectionToAxis(
      _scrollDirection ?? AxisDirection.left,
    )) {
      Axis.horizontal => Offset(_scrollPosition - _dragStartScrollOffset, 0.0),
      Axis.vertical => Offset(0.0, _scrollPosition - _dragStartScrollOffset),
    };
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        if (_longPressStartedWithoutFocus || renderEditable.readOnly) {
          renderEditable.selectWordsInRange(
            from: details.globalPosition -
                details.offsetFromOrigin -
                editableOffset -
                scrollableOffset,
            to: details.globalPosition,
            cause: SelectionChangedCause.longPress,
          );
        } else {
          renderEditable.selectPositionAt(
            from: details.globalPosition,
            cause: SelectionChangedCause.longPress,
          );
          // Update the floating cursor.
          final RawFloatingCursorPoint cursorPoint = RawFloatingCursorPoint(
            state: FloatingCursorDragState.Update,
            offset: details.offsetFromOrigin,
          );
          editableText.updateFloatingCursor(cursorPoint);
        }
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        renderEditable.selectWordsInRange(
          from: details.globalPosition -
              details.offsetFromOrigin -
              editableOffset -
              scrollableOffset,
          to: details.globalPosition,
          cause: SelectionChangedCause.longPress,
        );
    }

    _showMagnifierIfSupportedByPlatform(details.globalPosition);
  }

  @protected
  void onSingleLongTapEnd(LongPressEndDetails details) {
    _onSingleLongTapEndOrCancel();
    if (shouldShowSelectionToolbar) {
      editableText.showToolbar();
    }
  }

  @protected
  void onSingleLongTapCancel() {
    _onSingleLongTapEndOrCancel();
  }

  @protected
  void onSecondaryTap() {
    if (!delegate.selectionEnabled) {
      return;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        if (!_lastSecondaryTapWasOnSelection || !renderEditable.hasFocus) {
          renderEditable.selectWord(cause: SelectionChangedCause.tap);
        }
        if (shouldShowSelectionToolbar) {
          editableText.hideToolbar();
          editableText.showToolbar();
        }
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        if (!renderEditable.hasFocus) {
          renderEditable.selectPosition(cause: SelectionChangedCause.tap);
        }
        editableText.toggleToolbar();
    }
  }

  @protected
  void onSecondaryTapDown(TapDownDetails details) {
    // TODO(Renzo-Olivares): Migrate text selection gestures away from saving state
    // in renderEditable. The gesture callbacks can use the details objects directly
    // in callbacks variants that provide them [TapGestureRecognizer.onSecondaryTap]
    // vs [TapGestureRecognizer.onSecondaryTapUp] instead of having to track state in
    // renderEditable. When this migration is complete we should remove this hack.
    // See https://github.com/flutter/flutter/issues/115130.
    renderEditable.handleSecondaryTapDown(
        TapDownDetails(globalPosition: details.globalPosition));
    _shouldShowSelectionToolbar = true;
    _shouldShowSelectionHandles = details.kind == null ||
        details.kind == PointerDeviceKind.touch ||
        details.kind == PointerDeviceKind.stylus;
  }

  @protected
  void onDoubleTapDown(TapDragDownDetails details) {
    if (delegate.selectionEnabled) {
      renderEditable.selectWord(cause: SelectionChangedCause.doubleTap);
      if (shouldShowSelectionToolbar) {
        editableText.showToolbar();
      }
    }
  }

  void _onSingleLongTapEndOrCancel() {
    _hideMagnifierIfSupportedByPlatform();
    _longPressStartedWithoutFocus = false;
    _dragStartViewportOffset = 0.0;
    _dragStartScrollOffset = 0.0;
    if (_isEditableTextMounted &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        delegate.selectionEnabled &&
        editableText.textEditingValue.selection.isCollapsed) {
      // Update the floating cursor.
      final RawFloatingCursorPoint cursorPoint = RawFloatingCursorPoint(
        state: FloatingCursorDragState.End,
      );
      editableText.updateFloatingCursor(cursorPoint);
    }
  }

  // Selects the set of paragraphs in a document that intersect a given range of
  // global positions.
  void _selectParagraphsInRange(
      {required Offset from, Offset? to, SelectionChangedCause? cause}) {
    final TextBoundary paragraphBoundary =
        ParagraphBoundary(editableText.textEditingValue.text);
    _selectTextBoundariesInRange(
        boundary: paragraphBoundary, from: from, to: to, cause: cause);
  }

  // Selects the set of lines in a document that intersect a given range of
  // global positions.
  void _selectLinesInRange(
      {required Offset from, Offset? to, SelectionChangedCause? cause}) {
    final TextBoundary lineBoundary = LineBoundary(renderEditable);
    _selectTextBoundariesInRange(
        boundary: lineBoundary, from: from, to: to, cause: cause);
  }

  // Returns the location of a text boundary at `extent`. When `extent` is at
  // the end of the text, returns the previous text boundary's location.
  TextRange _moveToTextBoundary(
      TextPosition extent, TextBoundary textBoundary) {
    assert(extent.offset >= 0);
    // Use extent.offset - 1 when `extent` is at the end of the text to retrieve
    // the previous text boundary's location.
    final int start = textBoundary.getLeadingTextBoundaryAt(
          extent.offset == editableText.textEditingValue.text.length
              ? extent.offset - 1
              : extent.offset,
        ) ??
        0;
    final int end = textBoundary.getTrailingTextBoundaryAt(extent.offset) ??
        editableText.textEditingValue.text.length;
    return TextRange(start: start, end: end);
  }

  // Selects the set of text boundaries in a document that intersect a given
  // range of global positions.
  //
  // The set of text boundaries selected are not strictly bounded by the range
  // of global positions.
  //
  // The first and last endpoints of the selection will always be at the
  // beginning and end of a text boundary respectively.
  void _selectTextBoundariesInRange({
    required TextBoundary boundary,
    required Offset from,
    Offset? to,
    SelectionChangedCause? cause,
  }) {
    final TextPosition fromPosition = renderEditable.getPositionForPoint(from);
    final TextRange fromRange = _moveToTextBoundary(fromPosition, boundary);
    final TextPosition toPosition =
        to == null ? fromPosition : renderEditable.getPositionForPoint(to);
    final TextRange toRange = toPosition == fromPosition
        ? fromRange
        : _moveToTextBoundary(toPosition, boundary);
    final bool isFromBoundaryBeforeToBoundary = fromRange.start < toRange.end;

    final TextSelection newSelection = isFromBoundaryBeforeToBoundary
        ? TextSelection(baseOffset: fromRange.start, extentOffset: toRange.end)
        : TextSelection(baseOffset: fromRange.end, extentOffset: toRange.start);

    editableText.userUpdateTextEditingValue(
      editableText.textEditingValue.copyWith(selection: newSelection),
      cause,
    );
  }

  @protected
  void onTripleTapDown(TapDragDownDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }
    if (renderEditable.maxLines == 1) {
      editableText.selectAll(SelectionChangedCause.tap);
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          _selectParagraphsInRange(
              from: details.globalPosition, cause: SelectionChangedCause.tap);
        case TargetPlatform.linux:
          _selectLinesInRange(
              from: details.globalPosition, cause: SelectionChangedCause.tap);
      }
    }
    if (shouldShowSelectionToolbar) {
      editableText.showToolbar();
    }
  }

  @protected
  void onDragSelectionStart(TapDragStartDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }
    final PointerDeviceKind? kind = details.kind;
    _shouldShowSelectionToolbar = kind == null ||
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus;
    _shouldShowSelectionHandles = _shouldShowSelectionToolbar;

    _dragStartSelection = renderEditable.selection;
    _dragStartScrollOffset = _scrollPosition;
    _dragStartViewportOffset = renderEditable.offset.pixels;

    if (_effectiveConsecutiveTapCount(
          details.consecutiveTapCount,
        ) >
        1) {
      // Do not set the selection on a consecutive tap and drag.
      return;
    }

    if (_isShiftPressed &&
        renderEditable.selection != null &&
        renderEditable.selection!.isValid) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          _expandSelection(details.globalPosition, SelectionChangedCause.drag);
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          _extendSelection(details.globalPosition, SelectionChangedCause.drag);
      }
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
              renderEditable.selectPositionAt(
                from: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
            case null:
          }
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
              renderEditable.selectPositionAt(
                from: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              // For Android, Fuchsia, and iOS platforms, a touch drag
              // does not initiate unless the editable has focus.
              if (renderEditable.hasFocus) {
                renderEditable.selectPositionAt(
                  from: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
                _showMagnifierIfSupportedByPlatform(details.globalPosition);
              }
            case null:
          }
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          renderEditable.selectPositionAt(
            from: details.globalPosition,
            cause: SelectionChangedCause.drag,
          );
      }
    }
  }

  @protected
  void onDragSelectionUpdate(TapDragUpdateDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }

    if (!_isShiftPressed) {
      // Adjust the drag start offset for possible viewport offset changes.
      final Offset editableOffset = renderEditable.maxLines == 1
          ? Offset(renderEditable.offset.pixels - _dragStartViewportOffset, 0.0)
          : Offset(
              0.0, renderEditable.offset.pixels - _dragStartViewportOffset);
      final Offset scrollableOffset = switch (axisDirectionToAxis(
        _scrollDirection ?? AxisDirection.left,
      )) {
        Axis.horizontal =>
          Offset(_scrollPosition - _dragStartScrollOffset, 0.0),
        Axis.vertical => Offset(0.0, _scrollPosition - _dragStartScrollOffset),
      };
      final Offset dragStartGlobalPosition =
          details.globalPosition - details.offsetFromOrigin;

      // Select word by word.
      if (_effectiveConsecutiveTapCount(
            details.consecutiveTapCount,
          ) ==
          2) {
        renderEditable.selectWordsInRange(
          from: dragStartGlobalPosition - editableOffset - scrollableOffset,
          to: details.globalPosition,
          cause: SelectionChangedCause.drag,
        );

        switch (details.kind) {
          case PointerDeviceKind.stylus:
          case PointerDeviceKind.invertedStylus:
          case PointerDeviceKind.touch:
          case PointerDeviceKind.unknown:
            return _showMagnifierIfSupportedByPlatform(details.globalPosition);
          case PointerDeviceKind.mouse:
          case PointerDeviceKind.trackpad:
          case null:
            return;
        }
      }

      // Select paragraph-by-paragraph.
      if (_effectiveConsecutiveTapCount(
            details.consecutiveTapCount,
          ) ==
          3) {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.iOS:
            switch (details.kind) {
              case PointerDeviceKind.mouse:
              case PointerDeviceKind.trackpad:
                return _selectParagraphsInRange(
                  from: dragStartGlobalPosition -
                      editableOffset -
                      scrollableOffset,
                  to: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
              case PointerDeviceKind.stylus:
              case PointerDeviceKind.invertedStylus:
              case PointerDeviceKind.touch:
              case PointerDeviceKind.unknown:
              case null:
                // Triple tap to drag is not present on these platforms when using
                // non-precise pointer devices at the moment.
                break;
            }
            return;
          case TargetPlatform.linux:
            return _selectLinesInRange(
              from: dragStartGlobalPosition - editableOffset - scrollableOffset,
              to: details.globalPosition,
              cause: SelectionChangedCause.drag,
            );
          case TargetPlatform.windows:
          case TargetPlatform.macOS:
            return _selectParagraphsInRange(
              from: dragStartGlobalPosition - editableOffset - scrollableOffset,
              to: details.globalPosition,
              cause: SelectionChangedCause.drag,
            );
        }
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          // With a mouse device, a drag should select the range from the origin of the drag
          // to the current position of the drag.
          //
          // With a touch device, nothing should happen.
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
              return renderEditable.selectPositionAt(
                from:
                    dragStartGlobalPosition - editableOffset - scrollableOffset,
                to: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
            case null:
              break;
          }
          return;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          // With a precise pointer device, such as a mouse, trackpad, or stylus,
          // the drag will select the text spanning the origin of the drag to the end of the drag.
          // With a touch device, the cursor should move with the drag.
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
              return renderEditable.selectPositionAt(
                from:
                    dragStartGlobalPosition - editableOffset - scrollableOffset,
                to: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              if (renderEditable.hasFocus) {
                renderEditable.selectPositionAt(
                  from: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
                return _showMagnifierIfSupportedByPlatform(
                    details.globalPosition);
              }
            case null:
              break;
          }
          return;
        case TargetPlatform.macOS:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          return renderEditable.selectPositionAt(
            from: dragStartGlobalPosition - editableOffset - scrollableOffset,
            to: details.globalPosition,
            cause: SelectionChangedCause.drag,
          );
      }
    }

    if (_dragStartSelection!.isCollapsed ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return _extendSelection(
          details.globalPosition, SelectionChangedCause.drag);
    }

    // If the drag inverts the selection, Mac and iOS revert to the initial
    // selection.
    final TextSelection selection = editableText.textEditingValue.selection;
    final TextPosition nextExtent =
        renderEditable.getPositionForPoint(details.globalPosition);
    final bool isShiftTapDragSelectionForward =
        _dragStartSelection!.baseOffset < _dragStartSelection!.extentOffset;
    final bool isInverted = isShiftTapDragSelectionForward
        ? nextExtent.offset < _dragStartSelection!.baseOffset
        : nextExtent.offset > _dragStartSelection!.baseOffset;
    if (isInverted && selection.baseOffset == _dragStartSelection!.baseOffset) {
      editableText.userUpdateTextEditingValue(
        editableText.textEditingValue.copyWith(
          selection: TextSelection(
            baseOffset: _dragStartSelection!.extentOffset,
            extentOffset: nextExtent.offset,
          ),
        ),
        SelectionChangedCause.drag,
      );
    } else if (!isInverted &&
        nextExtent.offset != _dragStartSelection!.baseOffset &&
        selection.baseOffset != _dragStartSelection!.baseOffset) {
      editableText.userUpdateTextEditingValue(
        editableText.textEditingValue.copyWith(
          selection: TextSelection(
            baseOffset: _dragStartSelection!.baseOffset,
            extentOffset: nextExtent.offset,
          ),
        ),
        SelectionChangedCause.drag,
      );
    } else {
      _extendSelection(details.globalPosition, SelectionChangedCause.drag);
    }
  }

  @protected
  void onDragSelectionEnd(TapDragEndDetails details) {
    if (_shouldShowSelectionToolbar &&
        _effectiveConsecutiveTapCount(
              details.consecutiveTapCount,
            ) ==
            2) {
      editableText.showToolbar();
    }

    if (_isShiftPressed) {
      _dragStartSelection = null;
    }

    _hideMagnifierIfSupportedByPlatform();
  }

  Widget buildGestureDetector(
      {Key? key, HitTestBehavior? behavior, required Widget child}) {
    return TextSelectionGestureDetector(
      key: key,
      onTapTrackStart: onTapTrackStart,
      onTapTrackReset: onTapTrackReset,
      onTapDown: onTapDown,
      onForcePressStart: delegate.forcePressEnabled ? onForcePressStart : null,
      onForcePressEnd: delegate.forcePressEnabled ? onForcePressEnd : null,
      onSecondaryTap: onSecondaryTap,
      onSecondaryTapDown: onSecondaryTapDown,
      onSingleTapUp: onSingleTapUp,
      onSingleTapCancel: onSingleTapCancel,
      onUserTap: onUserTap,
      onSingleLongTapStart: onSingleLongTapStart,
      onSingleLongTapMoveUpdate: onSingleLongTapMoveUpdate,
      onSingleLongTapEnd: onSingleLongTapEnd,
      onSingleLongTapCancel: onSingleLongTapCancel,
      onDoubleTapDown: onDoubleTapDown,
      onTripleTapDown: onTripleTapDown,
      onDragSelectionStart: onDragSelectionStart,
      onDragSelectionUpdate: onDragSelectionUpdate,
      onDragSelectionEnd: onDragSelectionEnd,
      onUserTapAlwaysCalled: onUserTapAlwaysCalled,
      behavior: behavior,
      child: child,
    );
  }
}
