// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';

final class AttachmentApprovalDecision {
  const AttachmentApprovalDecision({
    required this.approved,
    required this.autoDownloadValue,
    required this.updateAutoDownloadValue,
  });

  final bool approved;
  final AttachmentAutoDownload? autoDownloadValue;
  final bool updateAutoDownloadValue;
}

class AttachmentApprovalDialog extends StatefulWidget {
  const AttachmentApprovalDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.showAutoTrustToggle,
    required this.autoDownloadValue,
    required this.inheritedAutoDownloadEnabled,
    required this.autoTrustLabel,
    required this.autoTrustHint,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool showAutoTrustToggle;
  final AttachmentAutoDownload? autoDownloadValue;
  final bool inheritedAutoDownloadEnabled;
  final String autoTrustLabel;
  final String autoTrustHint;

  @override
  State<AttachmentApprovalDialog> createState() =>
      _AttachmentApprovalDialogState();
}

class _AttachmentApprovalDialogState extends State<AttachmentApprovalDialog> {
  late var _autoDownloadValue = widget.autoDownloadValue;

  @override
  Widget build(BuildContext context) {
    final pop = Navigator.of(context).pop;
    final spacing = context.spacing;
    return AxiDialog(
      constraints: BoxConstraints(maxWidth: context.sizing.dialogMaxWidth),
      title: Text(widget.title, style: context.modalHeaderTextStyle),
      actions: [
        AxiButton(
          onPressed: () => pop(
            const AttachmentApprovalDecision(
              approved: false,
              autoDownloadValue: null,
              updateAutoDownloadValue: false,
            ),
          ),
          variant: AxiButtonVariant.outline,
          child: Text(widget.cancelLabel),
        ),
        AxiButton(
          onPressed: () => pop(
            AttachmentApprovalDecision(
              approved: true,
              autoDownloadValue: _autoDownloadValue,
              updateAutoDownloadValue:
                  widget.showAutoTrustToggle &&
                  _autoDownloadValue != widget.autoDownloadValue,
            ),
          ),
          variant: AxiButtonVariant.secondary,
          child: Text(widget.confirmLabel),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.s,
        children: [
          Text(widget.message, style: context.textTheme.muted),
          if (widget.showAutoTrustToggle)
            _AttachmentAutoDownloadSelect(
              label: widget.autoTrustLabel,
              hint: widget.autoTrustHint,
              inheritedEnabled: widget.inheritedAutoDownloadEnabled,
              value: _autoDownloadValue,
              onChanged: (value) => setState(() {
                _autoDownloadValue = value;
              }),
            ),
        ],
      ),
    );
  }
}

class _AttachmentAutoDownloadSelect extends StatelessWidget {
  const _AttachmentAutoDownloadSelect({
    required this.label,
    required this.hint,
    required this.inheritedEnabled,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final bool inheritedEnabled;
  final AttachmentAutoDownload? value;
  final ValueChanged<AttachmentAutoDownload?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.xs,
      children: [
        Text(label, style: context.textTheme.small),
        Text(hint, style: context.textTheme.muted),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: sizing.menuMaxWidth),
          child: AxiDropdown<AttachmentAutoDownload?>(
            maxWidth: sizing.menuMaxWidth,
            value: value,
            onChanged: onChanged,
            options:
                <AttachmentAutoDownload?>[
                      null,
                      AttachmentAutoDownload.allowed,
                      AttachmentAutoDownload.blocked,
                    ]
                    .map(
                      (option) => AxiDropdownOption<AttachmentAutoDownload?>(
                        value: option,
                        label: _label(l10n, option),
                        child: Text(_label(l10n, option)),
                      ),
                    )
                    .toList(),
            selectedBuilder: (_, option) => Text(_label(l10n, option)),
          ),
        ),
      ],
    );
  }

  String _label(AppLocalizations l10n, AttachmentAutoDownload? option) {
    return switch (option) {
      null => l10n.chatSettingInheritOption(
        inheritedEnabled ? l10n.chatSettingStateOn : l10n.chatSettingStateOff,
      ),
      AttachmentAutoDownload.allowed => l10n.settingsAutoDownloadScopeAlways,
      AttachmentAutoDownload.blocked => l10n.sessionCapabilityStatusOff,
    };
  }
}
