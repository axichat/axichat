import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class DisplayFingerprint extends StatelessWidget {
  const DisplayFingerprint({super.key, required this.fingerprint});

  static const blockLength = 8;
  static const _columns = 2;

  static final _logger = Logger('DisplayFingerprint');

  final String fingerprint;

  @override
  Widget build(BuildContext context) {
    final normalized = fingerprint.trim();
    if (normalized.isEmpty) {
      return Text(
        'Fingerprint unavailable',
        style: context.textTheme.small,
      );
    }

    final chunks = <String>[];
    for (var i = 0; i < normalized.length; i += blockLength) {
      final end = math.min(i + blockLength, normalized.length);
      if (end <= i) {
        _logger.warning('Skipping fingerprint slice due to invalid bounds',
            null, StackTrace.current);
        continue;
      }
      try {
        chunks.add(normalized.substring(i, end).toUpperCase());
      } catch (error, stackTrace) {
        _logger.warning(
          'Failed to extract fingerprint chunk (i=$i, end=$end, len=${normalized.length}).',
          error,
          stackTrace,
        );
        break;
      }
    }

    final rows = (chunks.length / _columns).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 12.0,
      children: [
        for (var row = 0; row < rows; row++)
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            spacing: 24.0,
            children: [
              for (var column = 0; column < _columns; column++)
                if (row * _columns + column < chunks.length)
                  Text(
                    chunks[row * _columns + column],
                    style: context.textTheme.small.copyWith(
                      color: stringToColor(chunks[row * _columns + column]),
                    ),
                  ),
            ],
          ),
      ],
    );
  }
}
