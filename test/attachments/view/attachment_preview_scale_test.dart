import 'dart:ui';

import 'package:axichat/src/attachments/view/attachment_file_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'preserves image aspect ratio when preview bounds constrain one axis',
    () {
      expect(
        const AttachmentPreviewScale(Size(4000, 1000), 1000, 800).resolve(),
        const Size(1000, 250),
      );
      expect(
        const AttachmentPreviewScale(Size(1000, 4000), 1000, 800).resolve(),
        const Size(200, 800),
      );
      expect(
        const AttachmentPreviewScale(Size(100, 50), 1000, 800).resolve(),
        const Size(100, 50),
      );
    },
  );
}
