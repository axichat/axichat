import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _dialogSpacing = 12.0;

class LinkedEmailOnboardingDialog extends StatelessWidget {
  const LinkedEmailOnboardingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ShadDialog(
      title: Text(
        l10n.linkedEmailAccountsTitle,
        style: context.modalHeaderTextStyle,
      ),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ).withTapBounce(),
        ShadButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.linkedEmailAccountsLinkAction),
        ).withTapBounce(),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.linkedEmailAccountsDescription),
          const SizedBox(height: _dialogSpacing),
          Text(l10n.linkedEmailAccountsDefaultHint),
        ],
      ),
    );
  }
}

Future<bool?> showLinkedEmailOnboardingDialog({
  required BuildContext context,
}) =>
    showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => const LinkedEmailOnboardingDialog(),
    );
