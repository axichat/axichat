// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';

/// Describes a location suggestion along with its source metadata.
class LocationSuggestion {
  const LocationSuggestion({
    required this.label,
    this.isHistory = false,
  });

  final String label;
  final bool isHistory;
}

class InlineLocationCompletion {
  const InlineLocationCompletion({
    required this.suggestion,
    required this.remainingText,
  });

  final LocationSuggestion suggestion;
  final String remainingText;
}

class LocationAutocompleteHelper {
  LocationAutocompleteHelper._(this._entries);

  factory LocationAutocompleteHelper.fromState(CalendarState state) {
    final seeds = <String>{};

    void collect(CalendarTask task) {
      final value = task.location?.trim();
      if (value != null && value.isNotEmpty) {
        seeds.add(value);
      }
    }

    state.model.tasks.values.forEach(collect);
    for (final task in state.unscheduledTasks) {
      collect(task);
    }

    return LocationAutocompleteHelper.fromSeeds(seeds);
  }

  factory LocationAutocompleteHelper.fromSeeds(Iterable<String> seeds) {
    final unique = <String>{
      ...seeds.map((value) => value.trim()).where(
            (value) => value.isNotEmpty,
          )
    };
    final entries = <_LocationEntry>[
      ...unique.map(
        (value) => _LocationEntry(
          label: value,
          isHistory: true,
        ),
      ),
    ];

    for (final fallback in _fallbackCorpus) {
      if (unique.add(fallback)) {
        entries.add(_LocationEntry(label: fallback));
      }
    }

    return LocationAutocompleteHelper._(entries);
  }

  static const List<String> _fallbackCorpus = [
    'Axichat HQ, 415 Mission St, San Francisco',
    'Conference Room A, 2nd Floor',
    'Union Square, San Francisco',
    'Civic Center Plaza, 355 McAllister St',
    'Pier 39, Beach Street & The Embarcadero',
    '1 Hacker Way, Menlo Park',
    '500 Terry Francois Blvd, San Francisco',
    'Moscone Center, 747 Howard St',
  ];

  final List<_LocationEntry> _entries;

  List<LocationSuggestion> search(String query, {int limit = 5}) {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) {
      return const [];
    }

    final ranked = <_RankedLocation>[];
    for (final entry in _entries) {
      final index = entry.labelLower.indexOf(normalized);
      if (index == -1) continue;

      final bool isPrefix = index == 0;
      final int score = (entry.isHistory ? 0 : 1) + (isPrefix ? 0 : 2);
      ranked.add(_RankedLocation(entry: entry, score: score));
    }

    ranked.sort((a, b) {
      if (a.score != b.score) {
        return a.score.compareTo(b.score);
      }
      return a.entry.labelLower.compareTo(b.entry.labelLower);
    });

    return ranked
        .take(limit)
        .map((rankedEntry) => rankedEntry.entry.toSuggestion())
        .toList();
  }

  InlineLocationCompletion? inlineCompletion(String rawQuery) {
    final trimmed = rawQuery.trimLeft();
    if (trimmed.length < 2) {
      return null;
    }
    final suggestion = search(trimmed, limit: 1).firstOrNull;
    if (suggestion == null) {
      return null;
    }
    final lowerSuggestion = suggestion.label.toLowerCase();
    final lowerQuery = trimmed.toLowerCase();
    if (!lowerSuggestion.startsWith(lowerQuery)) {
      return null;
    }
    final remainder = suggestion.label.substring(trimmed.length);
    if (remainder.isEmpty) {
      return null;
    }
    return InlineLocationCompletion(
      suggestion: suggestion,
      remainingText: remainder,
    );
  }
}

class _LocationEntry {
  _LocationEntry({required this.label, this.isHistory = false})
      : labelLower = label.toLowerCase();

  final String label;
  final String labelLower;
  final bool isHistory;

  LocationSuggestion toSuggestion() =>
      LocationSuggestion(label: label, isHistory: isHistory);
}

class _RankedLocation {
  const _RankedLocation({required this.entry, required this.score});

  final _LocationEntry entry;
  final int score;
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
