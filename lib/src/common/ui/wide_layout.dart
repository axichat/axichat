import 'package:flutter/material.dart';

class WideLayout extends StatelessWidget {
  const WideLayout(
      {super.key, required this.smallChild, required this.largeChild});

  final Widget smallChild;
  final Widget largeChild;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          flex: 3,
          child: Center(
            child: smallChild,
          ),
        ),
        Container(
          height: double.infinity,
          width: 1.0,
          color: const Color(0xffdadcde),
        ),
        Flexible(
          flex: 7,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: largeChild,
            ),
          ),
        ),
      ],
    );
  }
}
