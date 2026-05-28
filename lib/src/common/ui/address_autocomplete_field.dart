// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/address_autocomplete.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AddressAutocompleteField extends StatelessWidget {
  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.knownAddresses,
    this.suggestionDomains = const <String>{},
    this.primaryDomain,
    this.placeholder,
    this.error,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.requireEmailAddress = true,
    this.tapRegionGroup,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final Iterable<String> knownAddresses;
  final Set<String> suggestionDomains;
  final String? primaryDomain;
  final Widget? placeholder;
  final String? error;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool requireEmailAddress;
  final Object? tapRegionGroup;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (option) => option,
      onSelected: (value) {
        onChanged(value);
        focusNode.requestFocus();
      },
      optionsBuilder: (value) {
        if (value.text.trim().isEmpty) {
          return const <String>[];
        }
        return addressAutocompleteSuggestions(
          input: value.text,
          knownDomains: suggestionDomains,
          knownAddresses: knownAddresses,
          primaryDomain: primaryDomain,
          requireEmailAddress: requireEmailAddress,
        );
      },
      optionsViewBuilder: (context, onSelected, options) =>
          _AddressAutocompleteOptions(options: options, onSelected: onSelected),
      fieldViewBuilder: (context, controller, focusNode, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AxiTextInput(
              groupId: tapRegionGroup,
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              textInputAction: textInputAction,
              placeholder: placeholder,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
            if (error != null)
              Padding(
                padding: inputSubtextInsets,
                child: Text(
                  error!,
                  style: context.textTheme.small.copyWith(
                    color: context.colorScheme.destructive,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AddressAutocompleteOptions extends StatelessWidget {
  const _AddressAutocompleteOptions({
    required this.options,
    required this.onSelected,
  });

  final Iterable<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final renderedOptions = options.toList(growable: false);
    return Align(
      alignment: Alignment.topLeft,
      child: AxiModalSurface(
        borderColor: context.borderSide.color,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight.isFinite
                ? math.min(context.sizing.menuMaxHeight, constraints.maxHeight)
                : context.sizing.menuMaxHeight;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final option in renderedOptions)
                        ShadGestureDetector(
                          cursor: SystemMouseCursors.click,
                          hoverStrategies: mobileHoverStrategies,
                          onTap: () => onSelected(option),
                          child: AxiTapBounce(
                            child: Padding(
                              padding: EdgeInsets.all(context.spacing.m),
                              child: Text(
                                option,
                                style: context.textTheme.small,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
