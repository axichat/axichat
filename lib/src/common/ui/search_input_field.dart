// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/common/ui/buttons/axi_icon_button.dart';
import 'axi_input.dart';

class SearchInputField extends StatelessWidget {
  const SearchInputField({
    super.key,
    required this.controller,
    this.focusNode,
    this.placeholder,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.onClear,
    this.clearTooltip,
    this.clearButtonSize,
    this.clearIconSize,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final Widget? placeholder;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final VoidCallback? onClear;
  final String? clearTooltip;
  final double? clearButtonSize;
  final double? clearIconSize;

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = controller.text.trim();
    final VoidCallback? clearAction =
        trimmedQuery.isEmpty ? null : (onClear ?? controller.clear);
    final sizing = context.sizing;
    final resolvedButtonSize = clearButtonSize ?? sizing.inputSuffixButtonSize;
    final resolvedIconSize = clearIconSize ?? sizing.inputSuffixIconSize;
    return AxiInput(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      autofocus: autofocus,
      trailing: clearAction == null
          ? null
          : AxiIconButton.ghost(
              iconData: LucideIcons.x,
              tooltip: clearTooltip,
              buttonSize: resolvedButtonSize,
              tapTargetSize: resolvedButtonSize,
              iconSize: resolvedIconSize,
              onPressed: clearAction,
            ),
    );
  }
}
