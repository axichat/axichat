import 'package:axichat/src/attachments/view/attachment_file_preview.dart';
import 'package:axichat/src/common/file_type_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies in-app previewable attachment types', () {
    expect(
      _kind(fileName: 'photo.png', mimeType: 'image/png'),
      AttachmentPreviewKind.image,
    );
    expect(
      _kind(fileName: 'clip.mp4', mimeType: 'video/mp4'),
      AttachmentPreviewKind.video,
    );
    expect(
      _kind(fileName: 'document.pdf', mimeType: 'application/pdf'),
      AttachmentPreviewKind.pdf,
    );
    expect(
      _kind(fileName: 'notes.txt', mimeType: 'text/plain'),
      AttachmentPreviewKind.text,
    );
    expect(
      _kind(fileName: 'data.json', mimeType: 'application/json'),
      AttachmentPreviewKind.text,
    );
    expect(_kind(fileName: 'README.md'), AttachmentPreviewKind.text);
    expect(
      _kind(fileName: 'notes.txt', mimeType: 'application/octet-stream'),
      AttachmentPreviewKind.text,
    );
    expect(
      _kind(fileName: 'document.pdf', mimeType: 'application/octet-stream'),
      AttachmentPreviewKind.pdf,
    );
  });

  test('keeps archives, docx, and unknown binaries non-previewable', () {
    expect(_kind(fileName: 'bundle.zip', mimeType: 'application/zip'), isNull);
    expect(
      _kind(
        fileName: 'letter.docx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ),
      isNull,
    );
    expect(
      _kind(fileName: 'blob.bin', mimeType: 'application/octet-stream'),
      isNull,
    );
  });
}

AttachmentPreviewKind? _kind({required String fileName, String? mimeType}) {
  return resolveAttachmentPreviewKind(
    report: buildDeclaredFileTypeReport(
      declaredMimeType: mimeType,
      fileName: fileName,
    ),
    fileName: fileName,
    path: fileName,
    declaredMimeType: mimeType,
  );
}
