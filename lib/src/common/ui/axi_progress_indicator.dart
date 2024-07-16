import 'package:flutter/material.dart';

class AxiProgressIndicator extends StatelessWidget {
  const AxiProgressIndicator({
    super.key,
    this.color,
    this.semanticsLabel,
  });

  final Color? color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(
          color: color,
          semanticsLabel: semanticsLabel,
          strokeWidth: 2.0,
        ),
      ),
    );
  }
}
