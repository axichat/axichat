// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'axi_editable_text.dart' as axi;

class AxiSystemContextMenu extends StatefulWidget {
  const AxiSystemContextMenu._({
    super.key,
    required this.anchor,
    required this.items,
    this.onSystemHide,
  });

  factory AxiSystemContextMenu.editableText({
    Key? key,
    required axi.EditableTextState editableTextState,
    List<IOSSystemContextMenuItem>? items,
  }) {
    final (
      startGlyphHeight: double startGlyphHeight,
      endGlyphHeight: double endGlyphHeight
    ) = editableTextState.getGlyphHeights();

    return AxiSystemContextMenu._(
      key: key,
      anchor: TextSelectionToolbarAnchors.getSelectionRect(
        editableTextState.renderEditable,
        startGlyphHeight,
        endGlyphHeight,
        editableTextState.renderEditable.getEndpointsForSelection(
          editableTextState.textEditingValue.selection,
        ),
      ),
      items: items ?? getDefaultItems(editableTextState),
      onSystemHide: () => editableTextState.hideToolbar(false),
    );
  }

  final Rect anchor;
  final List<IOSSystemContextMenuItem> items;
  final VoidCallback? onSystemHide;

  static bool isSupported(BuildContext context) {
    return defaultTargetPlatform == TargetPlatform.iOS &&
        (MediaQuery.maybeSupportsShowingSystemContextMenu(context) ?? false);
  }

  static bool isSupportedByField(axi.EditableTextState editableTextState) {
    return !editableTextState.widget.readOnly &&
        isSupported(editableTextState.context);
  }

  static List<IOSSystemContextMenuItem> getDefaultItems(
    axi.EditableTextState editableTextState,
  ) {
    return <IOSSystemContextMenuItem>[
      if (editableTextState.copyEnabled) const IOSSystemContextMenuItemCopy(),
      if (editableTextState.cutEnabled) const IOSSystemContextMenuItemCut(),
      if (editableTextState.pasteEnabled) const IOSSystemContextMenuItemPaste(),
      if (editableTextState.selectAllEnabled)
        const IOSSystemContextMenuItemSelectAll(),
      if (editableTextState.lookUpEnabled)
        const IOSSystemContextMenuItemLookUp(),
      if (editableTextState.searchWebEnabled)
        const IOSSystemContextMenuItemSearchWeb(),
      if (editableTextState.liveTextInputEnabled)
        const IOSSystemContextMenuItemLiveText(),
    ];
  }

  @override
  State<AxiSystemContextMenu> createState() => _AxiSystemContextMenuState();
}

class _AxiSystemContextMenuState extends State<AxiSystemContextMenu> {
  late final SystemContextMenuController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SystemContextMenuController(
      onSystemHide: widget.onSystemHide,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(AxiSystemContextMenu.isSupported(context));

    if (widget.items.isNotEmpty) {
      final WidgetsLocalizations localizations =
          WidgetsLocalizations.of(context);
      final List<IOSSystemContextMenuItemData> itemDatas = widget.items
          .map(
            (IOSSystemContextMenuItem item) => item.getData(localizations),
          )
          .toList();
      _controller.showWithItems(widget.anchor, itemDatas);
    }

    return const SizedBox.shrink();
  }
}
