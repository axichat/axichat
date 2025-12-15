import 'package:axichat/src/calendar/utils/calendar_transfer_service.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<CalendarExportFormat?> showCalendarExportFormatSheet(
  BuildContext context, {
  String title = 'Choose export format',
}) {
  return showAdaptiveBottomSheet<CalendarExportFormat>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final colors = ShadTheme.of(sheetContext).colorScheme;
      return AxiSheetScaffold.scroll(
        header: AxiSheetHeader(
          title: Text(title),
          onClose: () => Navigator.of(sheetContext).maybePop(),
        ),
        children: [
          _CalendarTransferOption(
            icon: LucideIcons.calendarCheck2,
            label: sheetContext.l10n.calendarExportFormatIcsTitle,
            description: sheetContext.l10n.calendarExportFormatIcsSubtitle,
            onTap: () =>
                Navigator.of(sheetContext).pop(CalendarExportFormat.ics),
          ),
          const SizedBox(height: 8),
          _CalendarTransferOption(
            icon: LucideIcons.braces,
            label: sheetContext.l10n.calendarExportFormatJsonTitle,
            description: sheetContext.l10n.calendarExportFormatJsonSubtitle,
            onTap: () =>
                Navigator.of(sheetContext).pop(CalendarExportFormat.json),
          ),
        ],
      );
    },
  );
}

class _CalendarTransferOption extends StatelessWidget {
  const _CalendarTransferOption({
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
    final iconBackground = colors.muted.withValues(alpha: 0.12);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: AxiListTile(
        leading: DecoratedBox(
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 18,
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
