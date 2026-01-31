// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/utils/contact_exporter.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<ContactExportFormat?> showContactExportFormatSheet(
  BuildContext context, {
  String? title,
}) {
  return showAdaptiveBottomSheet<ContactExportFormat>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    surfacePadding: EdgeInsets.zero,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      final spacing = sheetContext.spacing;
      final String resolvedTitle = title ?? l10n.profileExportFormatTitle;
      return AxiSheetScaffold.scroll(
        header: AxiSheetHeader(
          title: Text(resolvedTitle),
          onClose: () => Navigator.of(sheetContext).maybePop(),
        ),
        children: [
          for (final format in ContactExportFormat.values) ...[
            _ContactExportOption(
              icon: format.icon,
              label: format.title(l10n),
              description: format.subtitle(l10n),
              onTap: () => Navigator.of(sheetContext).pop(format),
            ),
            SizedBox(height: spacing.s),
          ],
        ],
      );
    },
  );
}

extension ContactExportFormatLabels on ContactExportFormat {
  String title(AppLocalizations l10n) => switch (this) {
        ContactExportFormat.csv => l10n.profileExportFormatCsvTitle,
        ContactExportFormat.vcard => l10n.profileExportFormatVcardTitle,
      };

  String subtitle(AppLocalizations l10n) => switch (this) {
        ContactExportFormat.csv => l10n.profileExportFormatCsvSubtitle,
        ContactExportFormat.vcard => l10n.profileExportFormatVcardSubtitle,
      };

  IconData get icon => switch (this) {
        ContactExportFormat.csv => LucideIcons.fileSpreadsheet,
        ContactExportFormat.vcard => LucideIcons.idCard,
      };
}

class _ContactExportOption extends StatelessWidget {
  const _ContactExportOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final radii = context.radii;
    final iconBackground = colors.muted;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xxs),
      child: AxiListTile(
        leading: DecoratedBox(
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(radii.squircleSm),
            border: Border.fromBorderSide(context.borderSide),
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.s),
            child: Icon(
              icon,
              size: sizing.menuItemIconSize,
              color: colors.primary,
            ),
          ),
        ),
        title: label,
        subtitle: description,
        onTap: onTap,
      ),
    );
  }
}
