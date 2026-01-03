// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:bloc/bloc.dart';

mixin BlocCache<S> on BlocBase<S> {
  final cache = <String, dynamic>{};

  @override
  Future<void> close() {
    cache.clear();
    return super.close();
  }

  operator [](String key) => cache[key];
}
