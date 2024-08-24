import 'dart:math';

String generateRandomString({int length = 32, int? seed}) {
  final random = seed != null ? Random(seed) : Random.secure();
  const field =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  const fieldSize = field.length;
  final buffer = StringBuffer();
  while (length > 0) {
    buffer.writeCharCode(field.codeUnitAt(random.nextInt(fieldSize)));
    length--;
  }
  final result = buffer.toString();
  buffer.clear();
  return result;
}
