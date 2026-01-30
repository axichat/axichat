// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ContactRenameDialog extends StatefulWidget {
  const ContactRenameDialog({required this.initialValue, super.key});

  final String initialValue;

  @override
  State<ContactRenameDialog> createState() => _ContactRenameDialogState();
}

class _ContactRenameDialogState extends State<ContactRenameDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _controller.addListener(_handleChanged);
    _canSubmit = widget.initialValue.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChanged() {
    final enabled = _controller.text.trim().isNotEmpty;
    if (enabled == _canSubmit) return;
    setState(() {
      _canSubmit = enabled;
    });
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  void _reset() {
    Navigator.of(context).pop('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    return ShadDialog(
      title: Text(
        l10n.chatContactRenameTitle,
        style: context.modalHeaderTextStyle,
      ),
      actions: [
        AxiButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        AxiButton.outline(
          onPressed: _reset,
          child: Text(l10n.chatContactRenameReset),
        ),
        AxiButton.primary(
          onPressed: _canSubmit ? _submit : null,
          child: Text(l10n.chatContactRenameSave),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.chatContactRenameDescription),
          SizedBox(height: spacing.s),
          AxiTextFormField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            placeholder: Text(l10n.chatContactRenamePlaceholder),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
    );
  }
}

Future<String?> showContactRenameDialog({
  required BuildContext context,
  required String initialValue,
}) {
  return showFadeScaleDialog<String>(
    context: context,
    builder: (dialogContext) => ContactRenameDialog(initialValue: initialValue),
  );
}
