import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';

/// Current version of the full-fidelity JSON export format.
const int kCalendarJsonExportVersion = 2;

enum CalendarExportFormat { ics, json }

extension CalendarExportFormatX on CalendarExportFormat {
  String get label => switch (this) {
        CalendarExportFormat.ics => 'ICS (iCalendar)',
        CalendarExportFormat.json => 'JSON (Axichat)',
      };

  String get extension => switch (this) {
        CalendarExportFormat.ics => 'ics',
        CalendarExportFormat.json => 'json',
      };
}

/// Result of importing a calendar file.
class CalendarImportResult {
  const CalendarImportResult({
    this.tasks = const [],
    this.dayEvents = const [],
    this.criticalPaths = const [],
    this.model,
    this.isFullModel = false,
  });

  /// Imported tasks (for legacy format or ICS).
  final List<CalendarTask> tasks;

  /// Imported day events (for full-model format).
  final List<DayEvent> dayEvents;

  /// Imported critical paths (for full-model format).
  final List<CalendarCriticalPath> criticalPaths;

  /// Full calendar model (for v2+ JSON format).
  final CalendarModel? model;

  /// True if this was imported from a full-model JSON format.
  final bool isFullModel;
}

class CalendarTransferService {
  const CalendarTransferService({
    Future<Directory> Function()? tempDirectoryProvider,
  }) : _tempDirectoryProvider = tempDirectoryProvider ?? getTemporaryDirectory;

  final Future<Directory> Function() _tempDirectoryProvider;

  /// Exports tasks only (legacy format, ICS-compatible).
  ///
  /// For full-fidelity backup including day events and critical paths,
  /// use [exportModel] instead.
  Future<File> exportTasks({
    required Iterable<CalendarTask> tasks,
    required CalendarExportFormat format,
    String? fileNamePrefix,
  }) async {
    final Directory directory = await _tempDirectoryProvider();
    final String prefix = fileNamePrefix ?? 'axichat_calendar';
    final String timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '');
    final String path =
        p.join(directory.path, '$prefix-$timestamp.${format.extension}');
    final String contents = switch (format) {
      CalendarExportFormat.ics => _CalendarIcsCodec.encode(tasks),
      CalendarExportFormat.json => jsonEncode({
          'version': 1,
          'generatedAt': DateTime.now().toIso8601String(),
          'tasks': tasks.map((task) => task.toJson()).toList(),
        }),
    };
    final file = File(path);
    await file.writeAsString(contents, flush: true);
    return file;
  }

  /// Exports the full calendar model with all data.
  ///
  /// Includes tasks, day events, critical paths, tombstones, and metadata.
  /// This is the recommended format for full-fidelity backup.
  Future<File> exportModel({
    required CalendarModel model,
    String? fileNamePrefix,
  }) async {
    final Directory directory = await _tempDirectoryProvider();
    final String prefix = fileNamePrefix ?? 'axichat_calendar_full';
    final String timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '');
    final String path = p.join(directory.path, '$prefix-$timestamp.json');

    final contents = jsonEncode({
      'version': kCalendarJsonExportVersion,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'checksum': model.calculateChecksum(),
      'calendar_model': model.toJson(),
    });

    final file = File(path);
    await file.writeAsString(contents, flush: true);
    return file;
  }

  /// Imports a calendar file.
  ///
  /// Returns a [CalendarImportResult] containing either:
  /// - A full [CalendarModel] (for v2+ JSON format)
  /// - A list of tasks (for v1 JSON or ICS format)
  Future<CalendarImportResult> importFromFile(File file) async {
    final String extension = p.extension(file.path).toLowerCase();
    final String data = await file.readAsString();

    if (extension == '.ics') {
      final tasks = _CalendarIcsCodec.decode(data);
      return CalendarImportResult(tasks: tasks);
    }

    if (extension == '.json') {
      return _decodeJson(data);
    }

    throw const FormatException('Unsupported calendar format');
  }

  /// Legacy method for importing tasks only.
  ///
  /// Prefer [importFromFile] which returns a [CalendarImportResult].
  Future<List<CalendarTask>> importTasksFromFile(File file) async {
    final result = await importFromFile(file);
    if (result.isFullModel && result.model != null) {
      return result.model!.tasks.values.toList();
    }
    return result.tasks;
  }

  CalendarImportResult _decodeJson(String input) {
    final dynamic decoded = jsonDecode(input);

    if (decoded is Map<String, dynamic>) {
      final version = decoded['version'] as int?;

      // Version 2+: Full model format
      if (version != null &&
          version >= 2 &&
          decoded['calendar_model'] != null) {
        final modelJson = decoded['calendar_model'] as Map<String, dynamic>;
        final model = CalendarModel.fromJson(modelJson);
        return CalendarImportResult(
          tasks: model.tasks.values.toList(),
          dayEvents: model.dayEvents.values.toList(),
          criticalPaths: model.criticalPaths.values.toList(),
          model: model,
          isFullModel: true,
        );
      }

      // Version 1: Tasks-only format
      if (decoded['tasks'] is List) {
        final List<dynamic> tasks = decoded['tasks'] as List<dynamic>;
        return CalendarImportResult(
          tasks: tasks
              .whereType<Map<String, dynamic>>()
              .map(CalendarTask.fromJson)
              .toList(),
        );
      }
    }

    // Legacy: Plain array of tasks
    if (decoded is List) {
      return CalendarImportResult(
        tasks: decoded
            .whereType<Map<String, dynamic>>()
            .map(CalendarTask.fromJson)
            .toList(),
      );
    }

    throw const FormatException('Invalid calendar JSON');
  }
}

/// ICS (iCalendar) codec for calendar tasks.
///
/// **Limitations:** ICS is a lossy format for Axichat calendars. The following
/// fields are NOT exported and will be lost when round-tripping through ICS:
/// - Recurrence rules (RRULE is not generated; recurring tasks export as single events)
/// - Checklists (VTODO subtasks are not supported in VEVENT)
/// - Reminders (VALARM is not generated)
/// - Critical path associations
/// - Occurrence overrides for recurring tasks
///
/// For full-fidelity backup and restore, use JSON format instead.
class _CalendarIcsCodec {
  static const _prodId = '-//Axichat//Calendar//EN';

  static String encode(Iterable<CalendarTask> tasks) {
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('PRODID:$_prodId')
      ..writeln('VERSION:2.0')
      ..writeln('CALSCALE:GREGORIAN');
    for (final task in tasks) {
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:${_escape(task.id)}@axichat');
      buffer.writeln('X-AXICHAT-ID:${_escape(task.id)}');
      buffer.writeln('SUMMARY:${_escape(task.title)}');
      if (task.description?.isNotEmpty == true) {
        buffer.writeln('DESCRIPTION:${_escape(task.description!)}');
      }
      if (task.location?.isNotEmpty == true) {
        buffer.writeln('LOCATION:${_escape(task.location!)}');
      }
      final DateTime created = task.createdAt;
      buffer.writeln('DTSTAMP:${_formatDateTime(task.modifiedAt)}');
      if (task.scheduledTime != null) {
        final DateTime start = task.scheduledTime!;
        buffer.writeln('DTSTART:${_formatDateTime(start)}');
        final DateTime end = task.effectiveEndDate ??
            start.add(task.duration ?? const Duration(hours: 1));
        buffer.writeln('DTEND:${_formatDateTime(end)}');
      } else {
        final DateTime dateOnly = DateTime(
          created.year,
          created.month,
          created.day,
        );
        buffer.writeln(
          'DTSTART;VALUE=DATE:${_formatDate(dateOnly)}',
        );
      }
      if (task.deadline != null) {
        buffer.writeln('DUE:${_formatDateTime(task.deadline!)}');
      }
      if (task.priority != null) {
        buffer.writeln('X-AXICHAT-PRIORITY:${task.priority!.name}');
      }
      buffer
          .writeln('STATUS:${task.isCompleted ? 'COMPLETED' : 'NEEDS-ACTION'}');
      buffer.writeln('END:VEVENT');
    }
    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static List<CalendarTask> decode(String data) {
    final lines = _unfoldLines(data);
    final List<CalendarTask> tasks = [];
    Map<String, String> current = {};
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line == 'BEGIN:VEVENT') {
        current = {};
        continue;
      }
      if (line == 'END:VEVENT') {
        final task = _taskFromMap(current);
        if (task != null) {
          tasks.add(task);
        }
        current = {};
        continue;
      }
      final separatorIndex = line.indexOf(':');
      if (separatorIndex <= 0) continue;
      final key = line.substring(0, separatorIndex);
      final value = line.substring(separatorIndex + 1);
      current[key] = value;
    }
    return tasks;
  }

  static List<String> _unfoldLines(String data) {
    final rawLines = data.split(RegExp(r'\r?\n'));
    final List<String> lines = [];
    for (final line in rawLines) {
      if (line.isEmpty) continue;
      if ((line.startsWith(' ') || line.startsWith('\t')) && lines.isNotEmpty) {
        lines.last = '${lines.last}${line.substring(1)}';
      } else {
        lines.add(line);
      }
    }
    return lines;
  }

  static CalendarTask? _taskFromMap(Map<String, String> fields) {
    if (fields.isEmpty) return null;
    final summary = _unescape(fields['SUMMARY']) ?? 'Untitled task';
    final description = _unescape(fields['DESCRIPTION']);
    final location = _unescape(fields['LOCATION']);
    final uid = _unescape(
          fields['X-AXICHAT-ID'] ?? fields['UID']?.split('@').first ?? '',
        ) ??
        const Uuid().v4();
    final status = fields['STATUS'];
    final isCompleted = status == 'COMPLETED';
    final DateTime createdAt =
        _parseDateTime(fields['DTSTAMP']) ?? DateTime.now();
    final DateTime? start = _parseDateTime(fields['DTSTART'] ?? '');
    final DateTime? end = _parseDateTime(fields['DTEND'] ?? '');
    final DateTime? due = _parseDateTime(fields['DUE'] ?? '');
    final duration =
        start != null && end != null ? end.difference(start) : null;
    final priorityName = fields['X-AXICHAT-PRIORITY'];
    final TaskPriority? priority = priorityName == null
        ? null
        : TaskPriority.values
            .where((value) => value.name == priorityName)
            .cast<TaskPriority?>()
            .firstWhere(
              (value) => value != null,
              orElse: () => null,
            );

    return CalendarTask(
      id: uid,
      title: summary,
      description: description?.isEmpty == true ? null : description,
      scheduledTime: start,
      duration: duration?.isNegative == true ? null : duration,
      isCompleted: isCompleted,
      createdAt: createdAt,
      modifiedAt: createdAt,
      location: location?.isEmpty == true ? null : location,
      deadline: due,
      priority: priority == TaskPriority.none ? null : priority,
      startHour: null,
      endDate: end,
      recurrence: null,
      occurrenceOverrides: const {},
    );
  }

  static String _escape(String input) {
    return input
        .replaceAll('\\', r'\\')
        .replaceAll('\n', r'\n')
        .replaceAll(',', r'\,')
        .replaceAll(';', r'\;');
  }

  static String? _unescape(String? input) {
    if (input == null) return null;
    return input
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\,', ',')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\\', '\\');
  }

  static String _formatDateTime(DateTime value) {
    final utc = value.toUtc();
    final buffer = StringBuffer()
      ..write(_pad(utc.year, 4))
      ..write(_pad(utc.month, 2))
      ..write(_pad(utc.day, 2))
      ..write('T')
      ..write(_pad(utc.hour, 2))
      ..write(_pad(utc.minute, 2))
      ..write(_pad(utc.second, 2))
      ..write('Z');
    return buffer.toString();
  }

  static String _formatDate(DateTime value) {
    return '${_pad(value.year, 4)}${_pad(value.month, 2)}${_pad(value.day, 2)}';
  }

  static DateTime? _parseDateTime(String? input) {
    if (input == null || input.isEmpty) return null;
    final value = input.contains(':') ? input.split(':').last : input;
    if (value.endsWith('Z') && value.length >= 16) {
      final cleaned = value.substring(0, value.length - 1);
      final year = int.tryParse(cleaned.substring(0, 4));
      final month = int.tryParse(cleaned.substring(4, 6));
      final day = int.tryParse(cleaned.substring(6, 8));
      final hour = int.tryParse(cleaned.substring(9, 11));
      final minute = int.tryParse(cleaned.substring(11, 13));
      final second = int.tryParse(cleaned.substring(13, 15)) ?? 0;
      if ([year, month, day, hour, minute].any((part) => part == null)) {
        return null;
      }
      return DateTime.utc(year!, month!, day!, hour!, minute!, second);
    }
    if (value.length == 8) {
      final year = int.tryParse(value.substring(0, 4));
      final month = int.tryParse(value.substring(4, 6));
      final day = int.tryParse(value.substring(6, 8));
      if (year == null || month == null || day == null) return null;
      return DateTime(year, month, day);
    }
    return null;
  }

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');
}
