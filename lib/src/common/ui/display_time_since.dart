import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';

class DisplayTimeSince extends StatefulWidget {
  const DisplayTimeSince({
    super.key,
    required this.timestamp,
    this.style,
  });

  final DateTime timestamp;
  final TextStyle? style;

  @override
  State<DisplayTimeSince> createState() => _DisplayTimeSinceState();
}

class _DisplayTimeSinceState extends State<DisplayTimeSince> {
  late final Timer _timer;

  var _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = formatTimeSinceLabel(_now, widget.timestamp);
    final style = widget.style ?? context.textTheme.muted;
    return Text(text, style: style);
  }
}

String formatTimeSinceLabel(DateTime now, DateTime timestamp) {
  final difference = now.difference(timestamp);
  return switch (difference) {
    < const Duration(minutes: 1) => 'Just now',
    < const Duration(hours: 1) => '${difference.inMinutes}min ago',
    < const Duration(hours: 2) => '1 hr ago',
    < const Duration(days: 1) => '${difference.inHours}hrs ago',
    < const Duration(days: 2) => '1 day ago',
    < const Duration(days: 7) => '${difference.inDays} days ago',
    < const Duration(days: 14) => '1 week ago',
    < const Duration(days: 31) => '${difference.inDays ~/ 7} weeks ago',
    _ => 'Months ago',
  };
}
