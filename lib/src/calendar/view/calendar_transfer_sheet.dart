import 'package:axichat/src/common/ui/axi_adaptive_sheet.dart';
import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/utils/calendar_transfer_service.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

Future<CalendarExportFormat?> showCalendarExportFormatSheet(
  BuildContext context, {
  String title = 'Choose export format',
}) {
  return showAdaptiveBottomSheet<CalendarExportFormat>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.event_available_outlined),
          title: Text(context.l10n.calendarExportFormatIcsTitle),
          subtitle: Text(context.l10n.calendarExportFormatIcsSubtitle),
          onTap: () => Navigator.of(sheetContext).pop(CalendarExportFormat.ics),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: Text(context.l10n.calendarExportFormatJsonTitle),
          subtitle: Text(context.l10n.calendarExportFormatJsonSubtitle),
          onTap: () =>
              Navigator.of(sheetContext).pop(CalendarExportFormat.json),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}
