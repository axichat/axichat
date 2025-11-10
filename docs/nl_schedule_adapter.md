## NL Schedule Adapter

`lib/src/calendar/utils/nl_schedule_adapter.dart` bridges the offline parser
(`ScheduleParser`) with our calendar models (`CalendarTask`). The adapter keeps
bucket classification, priority mapping, recurrence conversion, and parse
metadata in one place so we don't mutate the app models directly.

### Timezone + parser initialization

```dart
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:axichat/src/calendar/utils/nl_schedule_adapter.dart';
import 'package:axichat/src/calendar/utils/schedule_parser.dart';

Future<NlAdapterResult> parseInput(String raw) async {
  tzdata.initializeTimeZones();
  final tzName = await FlutterNativeTimezone.getLocalTimezone();
  final location = tz.getLocation(tzName);

  final ctx = ParseContext(
    location: location,
    timezoneId: tzName,
  );
  final adapter = const NlScheduleAdapter();
  final parser = adapter.buildParser(ctx);

  final ScheduleItem item = parser.parse(raw);
  return adapter.mapToAppTypes(item, ctx: ctx);
}
```

Persist the `NlAdapterResult.task` plus the `NlZonedDateTime` metadata when you
need to retain the originating timezone (UTC instant + `timezoneId`). UI can
surface `result.parseNotes` whenever `confidence` falls below the configured
threshold or when the parser raised ambiguity flags.

### Configuration knobs

Use `NlAdapterConfig` to override:

- default duration (when parser finds a start but no end),
- minimum allowable duration,
- all-day span length and end-of-day hour,
- `strictNextWeekday` / `preferDmyDates` flags that flow through to
  `FuzzyPolicy`,
- `urgentHorizon` and `confidenceNoteThreshold`.

`NlScheduleAdapter(config: …)` automatically feeds the derived `FuzzyPolicy`
back into the parser via `buildParser`.

### Runtime service

`lib/src/calendar/utils/nl_parser_service.dart` exposes
`NlScheduleParserService`, which lazily initializes timezone data, resolves the
device timezone (falling back to UTC when the platform channel is unavailable),
and returns `NlAdapterResult` instances. UI layers (inline composer, guest
composer) and bloc handlers (`CalendarQuickTaskAdded`) depend on this service so
we keep parser wiring and configuration in a single place.
