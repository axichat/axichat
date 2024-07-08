import 'package:flutter/material.dart';

class RosterCard extends StatelessWidget {
  const RosterCard({super.key, required this.content, required this.buttons});

  final Widget content;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            flex: 3,
            child: content,
          ),
          Flexible(
            flex: 2,
            child: OverflowBar(
              spacing: 4.0,
              overflowSpacing: 4.0,
              overflowAlignment: OverflowBarAlignment.center,
              children: buttons,
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),
    );
  }
}
