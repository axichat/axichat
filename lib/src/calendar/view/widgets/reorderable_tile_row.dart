import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/widgets.dart';

/// Simple row that keeps the task tile and drag handle aligned consistently.
class ReorderableTileRow extends StatelessWidget {
  const ReorderableTileRow({
    super.key,
    required this.tile,
    required this.handle,
  });

  final Widget tile;
  final Widget handle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: tile),
        const SizedBox(width: calendarInsetSm),
        handle,
      ],
    );
  }
}
