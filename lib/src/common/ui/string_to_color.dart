import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:hsluv/extensions.dart';

Color stringToColor(String string) {
  final bytes = sha1.convert(utf8.encode(string)).bytes;
  const minSaturation = 60.0;
  const maxSaturation = 80.0;
  const minLightness = 55.0;
  const maxLightness = 75.0;
  final angle = ((bytes[1] << 8) + bytes[0]) / 65536 * 360;
  final saturation =
      minSaturation + (bytes[2] / 255) * (maxSaturation - minSaturation);
  final lightness =
      minLightness + (bytes[3] / 255) * (maxLightness - minLightness);
  return hsluvToRGBColor([angle, saturation, lightness]);
}
