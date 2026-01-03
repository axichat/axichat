// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/widgets.dart';

import 'package:axichat/src/home/home_search_cubit.dart';

class HomeSearchFilter {
  const HomeSearchFilter({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class HomeTabEntry {
  const HomeTabEntry({
    required this.id,
    required this.label,
    required this.body,
    this.fab,
    this.searchFilters = const [],
  });

  final HomeTab id;
  final String label;
  final Widget body;
  final Widget? fab;
  final List<HomeSearchFilter> searchFilters;
}
