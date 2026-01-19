// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';

class DisplayTimeSince extends StatefulWidget {
  const DisplayTimeSince({super.key, required this.timestamp, this.style});

  final DateTime timestamp;
  final TextStyle? style;

  @override
  State<DisplayTimeSince> createState() => _DisplayTimeSinceState();
}

class _DisplayTimeSinceState extends State<DisplayTimeSince> {
  late final Timer _timer;

  var _now = demoNow();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() => _now = demoNow()),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = formatTimeSinceLabel(context.l10n, _now, widget.timestamp);
    final style = widget.style ?? context.textTheme.muted;
    return Text(text, style: style);
  }
}

String formatTimeSinceLabel(
  AppLocalizations l10n,
  DateTime now,
  DateTime timestamp,
) {
  final difference = now.difference(timestamp);
  return switch (difference) {
    < const Duration(minutes: 1) => l10n.commonTimeJustNow,
    < const Duration(hours: 1) =>
      l10n.commonTimeMinutesAgo(difference.inMinutes),
    < const Duration(hours: 2) => l10n.commonTimeHoursAgo(1),
    < const Duration(days: 1) => l10n.commonTimeHoursAgo(difference.inHours),
    < const Duration(days: 2) => l10n.commonTimeDaysAgo(1),
    < const Duration(days: 7) => l10n.commonTimeDaysAgo(difference.inDays),
    < const Duration(days: 14) => l10n.commonTimeWeeksAgo(1),
    < const Duration(days: 31) =>
      l10n.commonTimeWeeksAgo(difference.inDays ~/ 7),
    _ => l10n.commonTimeMonthsAgo,
  };
}
