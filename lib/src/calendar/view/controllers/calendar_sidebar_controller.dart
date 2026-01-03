// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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

  void toggleSection(CalendarSidebarSection section) {
    final CalendarSidebarSection? next =
        _state.expandedSection == section ? null : section;
    if (next != _state.expandedSection) {
      _updateState(
        _state.copyWith(
          expandedSection: next,
          expandedSectionSpecified: true,
        ),
      );
    }
  }

  void expandSection(CalendarSidebarSection section) {
    if (_state.expandedSection == section) {
      return;
    }
    _updateState(
      _state.copyWith(
        expandedSection: section,
        expandedSectionSpecified: true,
      ),
    );
  }

  void setActivePopoverTaskId(String? taskId) {
    if (taskId != _state.activePopoverTaskId) {
      _updateState(
        _state.copyWith(
          activePopoverTaskId: taskId,
          activePopoverTaskIdSpecified: true,
        ),
      );
    }
  }

  void resetForm({bool preserveAdvancedVisibility = true}) {
    final bool nextShowAdvanced =
        preserveAdvancedVisibility ? _state.showAdvancedOptions : false;
    if (nextShowAdvanced != _state.showAdvancedOptions) {
      _updateState(_state.copyWith(showAdvancedOptions: nextShowAdvanced));
    }
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
    this.expandedSection,
    this.activePopoverTaskId,
  });

  final double width;
  final double minWidth;
  final double maxWidth;
  final bool hasUserResized;
  final bool isResizing;
  final bool showAdvancedOptions;
  final CalendarSidebarSection? expandedSection;
  final String? activePopoverTaskId;

  CalendarSidebarState copyWith({
    double? width,
    double? minWidth,
    double? maxWidth,
    bool? hasUserResized,
    bool? isResizing,
    bool? showAdvancedOptions,
    CalendarSidebarSection? expandedSection,
    bool expandedSectionSpecified = false,
    String? activePopoverTaskId,
    bool activePopoverTaskIdSpecified = false,
  }) {
    return CalendarSidebarState(
      width: width ?? this.width,
      minWidth: minWidth ?? this.minWidth,
      maxWidth: maxWidth ?? this.maxWidth,
      hasUserResized: hasUserResized ?? this.hasUserResized,
      isResizing: isResizing ?? this.isResizing,
      showAdvancedOptions: showAdvancedOptions ?? this.showAdvancedOptions,
      expandedSection: expandedSectionSpecified
          ? expandedSection
          : (expandedSection ?? this.expandedSection),
      activePopoverTaskId: activePopoverTaskIdSpecified
          ? activePopoverTaskId
          : (activePopoverTaskId ?? this.activePopoverTaskId),
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
        activePopoverTaskId,
      ];
}
