import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

/// Unique type id for the calendar2 duration adapter to avoid collisions with
/// the legacy calendar adapters.
const int calendar2DurationTypeId = 132;

/// Hive adapter that persists [Duration] values as microseconds.
class Calendar2DurationAdapter extends TypeAdapter<Duration> {
  @override
  final int typeId = calendar2DurationTypeId;

  @override
  Duration read(BinaryReader reader) {
    final microseconds = reader.readInt();
    return Duration(microseconds: microseconds);
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    writer.writeInt(obj.inMicroseconds);
  }
}

/// JSON converter used by the calendar2 models to encode [Duration] values as
/// microseconds. This keeps the serialized payloads deterministic and avoids
/// the default ISO8601 duration strings, which are harder to diff.
class DurationJsonConverter extends JsonConverter<Duration?, int?> {
  const DurationJsonConverter();

  @override
  Duration? fromJson(int? json) {
    if (json == null) {
      return null;
    }
    return Duration(microseconds: json);
  }

  @override
  int? toJson(Duration? object) => object?.inMicroseconds;
}
