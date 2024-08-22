import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:hsluv/extensions.dart';

Color stringToColor(String string) {
  final bytes = sha1.convert(utf8.encode(string)).bytes;
  final angle = ((bytes[1] << 8) + bytes[0]) / 65536 * 360;
  return hsluvToRGBColor([angle, 67, 67]);
}
