// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ContactRenameDialog extends StatefulWidget {
  const ContactRenameDialog({
    required this.initialValue,
    super.key,
  });

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
    return ShadDialog(
      title: Text(
        l10n.chatContactRenameTitle,
        style: context.modalHeaderTextStyle,
      ),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ).withTapBounce(),
        ShadButton.outline(
          onPressed: _reset,
          child: Text(l10n.chatContactRenameReset),
        ).withTapBounce(),
        ShadButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(l10n.chatContactRenameSave),
        ).withTapBounce(enabled: _canSubmit),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.chatContactRenameDescription),
          const SizedBox(height: 12),
          AxiTextFormField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
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
  return showShadDialog<String>(
    context: context,
    builder: (dialogContext) => ContactRenameDialog(
      initialValue: initialValue,
    ),
  );
}
