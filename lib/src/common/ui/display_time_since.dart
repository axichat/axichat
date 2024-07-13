import 'package:chat/src/app.dart';
import 'package:flutter/material.dart';

class DisplayTimeSince extends StatelessWidget {
  const DisplayTimeSince({
    super.key,
    required this.timestamp,
  });

  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    // Using FutureBuilder incorrectly here gives the right behaviour.
    return FutureBuilder(
      future: Future.delayed(
        const Duration(minutes: 1),
        () => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final difference = snapshot.data!.difference(timestamp);
        final text = switch (difference) {
          < const Duration(minutes: 1) => 'Just now',
          < const Duration(hours: 1) => '${difference.inMinutes}min ago',
          < const Duration(hours: 2) => '1hr ago',
          < const Duration(days: 1) => '${difference.inHours}hrs ago',
          < const Duration(days: 7) => '${difference.inDays}days ago',
          < const Duration(days: 31) => '${difference.inDays ~/ 7}weeks ago',
          _ => 'Months ago',
        };
        return Text(
          text,
          style: context.textTheme.muted,
        );
      },
    );
  }
}
