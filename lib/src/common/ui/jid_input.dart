// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/address_autocomplete.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class JidInput extends StatelessWidget {
  const JidInput({
    super.key,
    required this.onChanged,
    required this.jidOptions,
    this.suggestionDomains = const <String>{},
    this.initialValue,
    this.error,
    this.enabled = true,
    this.describe = true,
    this.textInputAction,
    this.onSubmitted,
  });

  final void Function(String) onChanged;
  final List<String> jidOptions;
  final Set<String> suggestionDomains;
  final String? initialValue;
  final String? error;
  final bool enabled;
  final bool describe;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: initialValue == null
          ? null
          : TextEditingValue(text: initialValue!),
      onSelected: onChanged,
      optionsBuilder: (value) {
        if (value.text.isEmpty) {
          return const <String>[];
        }
        return addressAutocompleteSuggestions(
          input: value.text,
          knownDomains: suggestionDomains,
          knownAddresses: jidOptions,
          requireEmailAddress: false,
        );
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: AxiModalSurface(
          borderColor: context.borderSide.color,
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final option in options)
                  ShadGestureDetector(
                    cursor: SystemMouseCursors.click,
                    hoverStrategies: mobileHoverStrategies,
                    onTap: () => onSelected(option),
                    child: AxiTapBounce(
                      child: Padding(
                        padding: EdgeInsets.all(context.spacing.m),
                        child: Text(option, style: context.textTheme.small),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      fieldViewBuilder: (context, controller, focus, _) {
        final input = AxiTextInput(
          controller: controller,
          focusNode: focus,
          autocorrect: false,
          keyboardType: TextInputType.emailAddress,
          textInputAction: textInputAction,
          enabled: enabled,
          placeholder: Text(context.l10n.jidInputPlaceholder),
          // description: describe
          //     ? const Padding(
          //         padding: EdgeInsets.only(left: 8.0),
          //         child: Text('e.g: john@xmpp.social'),
          //       )
          //     : null,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          // validator: (text) {
          //   if (text.isEmpty) {
          //     return 'Enter a JID';
          //   }
          //
          //   if (!text.isValidJid) {
          //     return 'Enter a valid jid';
          //   }
          //
          //   return null;
          // },
        );
        final errorText =
            error ??
            (!focus.hasFocus &&
                    controller.text.isNotEmpty &&
                    !AddressStringExtensions(controller.text).isValidJid
                ? context.l10n.jidInputInvalid
                : null);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            input,
            if (errorText != null)
              Padding(
                padding: inputSubtextInsets,
                child: Text(
                  errorText,
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
