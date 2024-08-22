import 'package:flutter/material.dart';

class AxiProgressIndicator extends StatelessWidget {
  const AxiProgressIndicator({
    super.key,
    this.dimension = 16.0,
    this.color,
    this.semanticsLabel,
  });

  final double dimension;
  final Color? color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: CircularProgressIndicator(
        color: color,
        semanticsLabel: semanticsLabel,
        strokeWidth: 2.0,
      ),
    );
  }
}
