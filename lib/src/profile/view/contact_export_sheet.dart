// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/utils/contact_exporter.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _contactExportSheetPadding = 8.0;
const double _contactExportOptionSpacing = 8.0;
const double _contactExportIconPadding = 10.0;
const double _contactExportIconSize = 18.0;
const double _contactExportOptionRadius = 12.0;
const double _contactExportIconAlpha = 0.12;

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
      final String resolvedTitle = title ?? l10n.profileExportFormatTitle;
      return AxiSheetScaffold.scroll(
        header: AxiSheetHeader(
          title: Text(resolvedTitle),
          onClose: () => Navigator.of(sheetContext).maybePop(),
          padding: const EdgeInsets.fromLTRB(
            _contactExportSheetPadding,
            _contactExportSheetPadding,
            _contactExportSheetPadding,
            _contactExportSheetPadding,
          ),
        ),
        bodyPadding: const EdgeInsets.fromLTRB(
          _contactExportSheetPadding,
          0,
          _contactExportSheetPadding,
          _contactExportSheetPadding,
        ),
        children: [
          for (final format in ContactExportFormat.values) ...[
            _ContactExportOption(
              icon: format.icon,
              label: format.title(l10n),
              description: format.subtitle(l10n),
              onTap: () => Navigator.of(sheetContext).pop(format),
            ),
            const SizedBox(height: _contactExportOptionSpacing),
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
    final colors = ShadTheme.of(context).colorScheme;
    final iconBackground =
        colors.muted.withValues(alpha: _contactExportIconAlpha);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: AxiListTile(
        leading: DecoratedBox(
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(_contactExportOptionRadius),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(_contactExportIconPadding),
            child: Icon(
              icon,
              size: _contactExportIconSize,
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
