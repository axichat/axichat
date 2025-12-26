import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/storage/calendar_state_storage_codec.dart';
import 'package:test/test.dart';

final DateTime _selectedDate = DateTime(2024, 1, 1);
const CalendarView _selectedView = CalendarView.month;
const int _selectedDayIndex = 2;

void main() {
  group('CalendarStateStorageCodec', () {
    test('round-trips calendar state', () {
      final model = CalendarModel.empty();
      final state = CalendarState(
        model: model,
        selectedDate: _selectedDate,
        viewMode: _selectedView,
        selectedDayIndex: _selectedDayIndex,
      );

      final encoded = CalendarStateStorageCodec.encode(state);

      expect(encoded, isNotNull);
      final decoded = CalendarStateStorageCodec.decode(encoded!);

      expect(decoded, isNotNull);
      expect(decoded!.model, state.model);
      expect(decoded.selectedDate, state.selectedDate);
      expect(decoded.viewMode, state.viewMode);
      expect(decoded.selectedDayIndex, state.selectedDayIndex);
    });

    test('returns null for incomplete payloads', () {
      final missingModel = CalendarStateStorageCodec.decode({
        'selectedDate': _selectedDate.toIso8601String(),
        'viewMode': _selectedView.name,
      });
      final missingDate = CalendarStateStorageCodec.decode({
        'model': CalendarModel.empty().toJson(),
        'viewMode': _selectedView.name,
      });
      final missingView = CalendarStateStorageCodec.decode({
        'model': CalendarModel.empty().toJson(),
        'selectedDate': _selectedDate.toIso8601String(),
      });

      expect(missingModel, isNull);
      expect(missingDate, isNull);
      expect(missingView, isNull);
    });
  });
}
