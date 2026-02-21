// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

typedef AxiNowTickerBuilder =
    Widget Function(
      BuildContext context,
      ValueListenable<DateTime> nowListenable,
    );

class AxiNowTicker extends StatefulWidget {
  const AxiNowTicker({
    super.key,
    required this.builder,
    this.interval = const Duration(minutes: 1),
    this.now,
  });

  final AxiNowTickerBuilder builder;
  final Duration interval;
  final DateTime Function()? now;

  @override
  State<AxiNowTicker> createState() => _AxiNowTickerState();
}

class _AxiNowTickerState extends State<AxiNowTicker> {
  late final ValueNotifier<DateTime> _now;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _now = ValueNotifier<DateTime>(_resolveNow());
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant AxiNowTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final intervalChanged = oldWidget.interval != widget.interval;
    final nowChanged = oldWidget.now != widget.now;
    if (intervalChanged) {
      _startTicker();
    }
    if (intervalChanged || nowChanged) {
      _now.value = _resolveNow();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _now.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      widget.interval,
      (_) => _now.value = _resolveNow(),
    );
  }

  DateTime _resolveNow() => widget.now?.call() ?? DateTime.now();

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
