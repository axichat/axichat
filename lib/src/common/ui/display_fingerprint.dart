import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

class DisplayFingerprint extends StatelessWidget {
  const DisplayFingerprint({super.key, required this.fingerprint});

  static const blockLength = 8;

  final String fingerprint;

  @override
  Widget build(BuildContext context) {
    final strings = [];
    for (var i = 0; i < fingerprint.length; i += blockLength) {
      strings.add(fingerprint.substring(i, i + blockLength).toUpperCase());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 12.0,
      children: [
        for (double i = 0; i < blockLength; i += blockLength / 4)
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            spacing: 24.0,
            children: [
              for (double j = i; j < i + blockLength / 4; j++)
                Text(
                  strings[j.toInt()],
                  style: context.textTheme.small.copyWith(
                    color: stringToColor(strings[j.toInt()]),
                  ),
                )
            ],
          )
      ],
    );
  }
}
