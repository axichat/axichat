import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

enum CalendarSidebarSection { unscheduled, reminders }

/// Declarative UI controller for the calendar sidebar. This controller keeps
/// purely-presentational sidebar state out of the app-wide blocs while still
/// enabling widgets to rebuild reactively.
class CalendarSidebarController extends ChangeNotifier {
  CalendarSidebarController({
    required double width,
    required double minWidth,
    required double maxWidth,
  })  : assert(minWidth <= maxWidth, 'minWidth must be <= maxWidth'),
        _state = CalendarSidebarState(
          width: width.clamp(minWidth, maxWidth),
          minWidth: minWidth,
          maxWidth: maxWidth,
        );

  CalendarSidebarState _state;

  CalendarSidebarState get state => _state;

  void syncBounds({
    required double minWidth,
    required double maxWidth,
    required double defaultWidth,
  }) {
    if (minWidth == _state.minWidth &&
        maxWidth == _state.maxWidth &&
        _state.hasUserResized) {
      return;
    }

    final double clampedMin = minWidth;
    final double clampedMax = maxWidth < clampedMin ? clampedMin : maxWidth;
    final double nextWidth = _state.hasUserResized
        ? _state.width.clamp(clampedMin, clampedMax)
        : defaultWidth.clamp(clampedMin, clampedMax);

    _updateState(
      _state.copyWith(
        minWidth: clampedMin,
        maxWidth: clampedMax,
        width: nextWidth,
      ),
    );
  }

  void beginResize() {
    if (!_state.isResizing) {
      _updateState(_state.copyWith(isResizing: true));
    }
  }

  void endResize() {
    if (_state.isResizing) {
      _updateState(_state.copyWith(isResizing: false));
    }
  }

  void adjustWidth(double delta) {
    if (delta == 0) return;
    final double nextWidth =
        (_state.width + delta).clamp(_state.minWidth, _state.maxWidth);
    if (nextWidth != _state.width) {
      _updateState(
        _state.copyWith(
          width: nextWidth,
          hasUserResized: true,
        ),
      );
    }
  }

  void toggleAdvancedOptions() {
    _updateState(
      _state.copyWith(showAdvancedOptions: !_state.showAdvancedOptions),
    );
  }

  void setImportant(bool value) {
    if (value != _state.isImportant) {
      _updateState(_state.copyWith(isImportant: value));
    }
  }

  void setUrgent(bool value) {
    if (value != _state.isUrgent) {
      _updateState(_state.copyWith(isUrgent: value));
    }
  }

  void setSelectedDeadline(DateTime? value) {
    if (value != _state.selectedDeadline) {
      _updateState(_state.copyWith(selectedDeadline: value));
    }
  }

  void setAdvancedStart(DateTime? value) {
    if (value == null) {
      if (_state.advancedStartTime != null || _state.advancedEndTime != null) {
        _updateState(
          _state.copyWith(
            advancedStartTime: null,
            advancedEndTime: null,
          ),
        );
      }
      return;
    }

    DateTime? end = _state.advancedEndTime;
    if (end == null || end.isBefore(value)) {
      end = value.add(const Duration(hours: 1));
    }

    _updateState(
      _state.copyWith(
        advancedStartTime: value,
        advancedEndTime: end,
      ),
    );
  }

  void setAdvancedEnd(DateTime? value) {
    if (value == null) {
      if (_state.advancedEndTime != null) {
        _updateState(_state.copyWith(advancedEndTime: null));
      }
      return;
    }

    DateTime adjusted = value;
    final DateTime? start = _state.advancedStartTime;
    if (start != null && value.isBefore(start)) {
      adjusted = start.add(const Duration(minutes: 15));
    }

    if (adjusted != _state.advancedEndTime) {
      _updateState(_state.copyWith(advancedEndTime: adjusted));
    }
  }

  void toggleSection(CalendarSidebarSection section) {
    final CalendarSidebarSection next;
    if (_state.expandedSection == section) {
      next = section == CalendarSidebarSection.unscheduled
          ? CalendarSidebarSection.reminders
          : CalendarSidebarSection.unscheduled;
    } else {
      next = section;
    }

    if (next != _state.expandedSection) {
      _updateState(_state.copyWith(expandedSection: next));
    }
  }

  void setActivePopoverTaskId(String? taskId) {
    if (taskId != _state.activePopoverTaskId) {
      _updateState(_state.copyWith(activePopoverTaskId: taskId));
    }
  }

  void resetForm({bool preserveAdvancedVisibility = true}) {
    _updateState(
      _state.copyWith(
        showAdvancedOptions:
            preserveAdvancedVisibility ? _state.showAdvancedOptions : false,
        isImportant: false,
        isUrgent: false,
        selectedDeadline: null,
        advancedStartTime: null,
        advancedEndTime: null,
      ),
    );
  }

  void _updateState(CalendarSidebarState next) {
    if (identical(_state, next) || _state == next) {
      return;
    }
    _state = next;
    notifyListeners();
  }
}

class CalendarSidebarState extends Equatable {
  const CalendarSidebarState({
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    this.hasUserResized = false,
    this.isResizing = false,
    this.showAdvancedOptions = false,
    this.expandedSection = CalendarSidebarSection.unscheduled,
    this.isImportant = false,
    this.isUrgent = false,
    this.selectedDeadline,
    this.advancedStartTime,
    this.advancedEndTime,
    this.activePopoverTaskId,
  });

  final double width;
  final double minWidth;
  final double maxWidth;
  final bool hasUserResized;
  final bool isResizing;
  final bool showAdvancedOptions;
  final CalendarSidebarSection expandedSection;
  final bool isImportant;
  final bool isUrgent;
  final DateTime? selectedDeadline;
  final DateTime? advancedStartTime;
  final DateTime? advancedEndTime;
  final String? activePopoverTaskId;

  CalendarSidebarState copyWith({
    double? width,
    double? minWidth,
    double? maxWidth,
    bool? hasUserResized,
    bool? isResizing,
    bool? showAdvancedOptions,
    CalendarSidebarSection? expandedSection,
    bool? isImportant,
    bool? isUrgent,
    DateTime? selectedDeadline,
    DateTime? advancedStartTime,
    DateTime? advancedEndTime,
    String? activePopoverTaskId,
  }) {
    return CalendarSidebarState(
      width: width ?? this.width,
      minWidth: minWidth ?? this.minWidth,
      maxWidth: maxWidth ?? this.maxWidth,
      hasUserResized: hasUserResized ?? this.hasUserResized,
      isResizing: isResizing ?? this.isResizing,
      showAdvancedOptions: showAdvancedOptions ?? this.showAdvancedOptions,
      expandedSection: expandedSection ?? this.expandedSection,
      isImportant: isImportant ?? this.isImportant,
      isUrgent: isUrgent ?? this.isUrgent,
      selectedDeadline: selectedDeadline ?? this.selectedDeadline,
      advancedStartTime: advancedStartTime ?? this.advancedStartTime,
      advancedEndTime: advancedEndTime ?? this.advancedEndTime,
      activePopoverTaskId: activePopoverTaskId ?? this.activePopoverTaskId,
    );
  }

  @override
  List<Object?> get props => [
        width,
        minWidth,
        maxWidth,
        hasUserResized,
        isResizing,
        showAdvancedOptions,
        expandedSection,
        isImportant,
        isUrgent,
        selectedDeadline,
        advancedStartTime,
        advancedEndTime,
        activePopoverTaskId,
      ];
}
