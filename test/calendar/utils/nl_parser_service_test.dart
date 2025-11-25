import 'dart:isolate';

import 'package:axichat/src/calendar/utils/nl_parser_service.dart';
import 'package:axichat/src/calendar/utils/schedule_parser.dart';
import 'package:test/test.dart';

void main() {
  Future<Map<String, Object?>> parseInFreshIsolate(String input) {
    return Isolate.run(() async {
      final service = NlScheduleParserService(
        initializeTimezones: () => throw StateError('timezone init failed'),
      );
      final result = await service.parse(input);
      return <String, Object?>{
        'bucket': result.bucket.name,
        'timezoneId': result.context.timezoneId,
        'hasStart': result.start != null,
        'hasDeadline': result.deadline != null,
      };
    });
  }

  test('falls back to UTC when timezone init fails', () async {
    final snapshot = await parseInFreshIsolate('meet tomorrow at 2pm');

    expect(snapshot['timezoneId'], 'UTC');
    expect(snapshot['bucket'], TaskBucket.scheduled.name);
    expect(snapshot['hasStart'], isTrue);
  });
}
