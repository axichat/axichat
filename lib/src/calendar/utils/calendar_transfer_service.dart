import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/utils/calendar_ics_codec.dart';

/// Current version of the full-fidelity JSON export format.
const int kCalendarJsonExportVersion = 2;
const String _taskIcsExportPrefix = 'axichat_task';
const String _dayEventIcsExportPrefix = 'axichat_event';

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

  /// Imported tasks (for legacy format or tasks-only JSON).
  final List<CalendarTask> tasks;

  /// Imported day events (for full-model formats).
  final List<DayEvent> dayEvents;

  /// Imported critical paths (for full-model formats).
  final List<CalendarCriticalPath> criticalPaths;

  /// Full calendar model (for v2+ JSON or iCalendar formats).
  final CalendarModel? model;

  /// True if this was imported from a full-model format.
  final bool isFullModel;
}

class CalendarTransferService {
  const CalendarTransferService({
    Future<Directory> Function()? tempDirectoryProvider,
  }) : _tempDirectoryProvider = tempDirectoryProvider ?? getTemporaryDirectory;

  final Future<Directory> Function() _tempDirectoryProvider;
  static const CalendarIcsCodec _icsCodec = CalendarIcsCodec();

  /// Exports tasks only for share flows.
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
      CalendarExportFormat.ics => _icsCodec.encode(
          _modelFromTasks(tasks),
        ),
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

  Future<File> exportTaskIcs({
    required CalendarTask task,
    String? fileNamePrefix,
  }) async {
    return exportTasks(
      tasks: <CalendarTask>[task],
      format: CalendarExportFormat.ics,
      fileNamePrefix: fileNamePrefix ?? _taskIcsExportPrefix,
    );
  }

  Future<File> exportDayEventIcs({
    required DayEvent event,
    String? fileNamePrefix,
  }) async {
    final CalendarModel model = _modelFromDayEvents(<DayEvent>[event]);
    return exportIcs(
      model: model,
      fileNamePrefix: fileNamePrefix ?? _dayEventIcsExportPrefix,
    );
  }

  /// Exports the full calendar model in iCalendar format.
  Future<File> exportIcs({
    required CalendarModel model,
    String? fileNamePrefix,
  }) async {
    final Directory directory = await _tempDirectoryProvider();
    final String prefix = fileNamePrefix ?? 'axichat_calendar';
    final String timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '');
    final String path = p.join(directory.path, '$prefix-$timestamp.ics');
    final String contents = _icsCodec.encode(model);
    final file = File(path);
    await file.writeAsString(contents, flush: true);
    return file;
  }

  CalendarModel _modelFromTasks(Iterable<CalendarTask> tasks) {
    final Map<String, CalendarTask> mapped =
        Map<String, CalendarTask>.fromEntries(
      tasks.map((task) => MapEntry(task.id, task)),
    );
    final DateTime now = DateTime.now();
    final CalendarModel model = CalendarModel(
      tasks: mapped,
      lastModified: now,
      checksum: '',
    );
    return model.copyWith(checksum: model.calculateChecksum());
  }

  CalendarModel _modelFromDayEvents(Iterable<DayEvent> events) {
    final Map<String, DayEvent> mapped = Map<String, DayEvent>.fromEntries(
      events.map((event) => MapEntry(event.id, event)),
    );
    final DateTime now = DateTime.now();
    final CalendarModel model = CalendarModel(
      dayEvents: mapped,
      lastModified: now,
      checksum: '',
    );
    return model.copyWith(checksum: model.calculateChecksum());
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
  /// - A list of tasks (for v1 JSON format)
  Future<CalendarImportResult> importFromFile(File file) async {
    final String extension = p.extension(file.path).toLowerCase();
    final String data = await file.readAsString();

    if (extension == '.ics') {
      final CalendarModel model = _icsCodec.decode(data);
      return CalendarImportResult(
        tasks: model.tasks.values.toList(),
        dayEvents: model.dayEvents.values.toList(),
        criticalPaths: model.criticalPaths.values.toList(),
        model: model,
        isFullModel: true,
      );
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
