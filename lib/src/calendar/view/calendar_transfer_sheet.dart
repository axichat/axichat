import 'package:flutter/material.dart';

import '../utils/calendar_transfer_service.dart';

Future<CalendarExportFormat?> showCalendarExportFormatSheet(
  BuildContext context, {
  String title = 'Choose export format',
}) {
  return showModalBottomSheet<CalendarExportFormat>(
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
          title: const Text('ICS (iCalendar)'),
          subtitle: const Text('Share with any calendar client'),
          onTap: () => Navigator.of(sheetContext).pop(CalendarExportFormat.ics),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('JSON (Axichat backup)'),
          subtitle: const Text('Keep a portable, lossless backup file'),
          onTap: () =>
              Navigator.of(sheetContext).pop(CalendarExportFormat.json),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}
