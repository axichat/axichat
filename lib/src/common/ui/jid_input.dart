// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension ValidJid on String {
  bool get isValidJid => RegExp(
          r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
      .hasMatch(this);
}

class JidInput extends StatelessWidget {
  const JidInput({
    super.key,
    required this.onChanged,
    required this.jidOptions,
    this.initialValue,
    this.error,
    this.enabled = true,
    this.describe = true,
  });

  final void Function(String) onChanged;
  final List<String> jidOptions;
  final String? initialValue;
  final String? error;
  final bool enabled;
  final bool describe;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue:
          initialValue == null ? null : TextEditingValue(text: initialValue!),
      onSelected: onChanged,
      optionsBuilder: (value) {
        if (value.text.isEmpty) return const [];
        return jidOptions
            .where((e) =>
                e.toLowerCase().contains(value.text.toLowerCase()) &&
                e.toLowerCase() != value.text.toLowerCase())
            .toList();
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          shape: RoundedRectangleBorder(
            side: BorderSide(color: context.colorScheme.border),
            borderRadius: context.radius,
          ),
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
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(option),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      fieldViewBuilder: (context, controller, focus, __) {
        Widget child = AxiTextInput(
          controller: controller,
          focusNode: focus,
          autocorrect: false,
          keyboardType: TextInputType.emailAddress,
          enabled: enabled,
          placeholder: Text(context.l10n.jidInputPlaceholder),
          // description: describe
          //     ? const Padding(
          //         padding: EdgeInsets.only(left: 8.0),
          //         child: Text('e.g: john@xmpp.social'),
          //       )
          //     : null,
          onChanged: onChanged,
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
        if (error != null ||
            (!focus.hasFocus &&
                controller.text.isNotEmpty &&
                !controller.text.isValidJid)) {
          child = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              Padding(
                padding: inputSubtextInsets,
                child: Text(
                  error ?? context.l10n.jidInputInvalid,
                  style: TextStyle(
                    color: context.colorScheme.destructive,
                  ),
                ),
              ),
            ],
          );
        }
        return child;
      },
    );
  }
}
