import 'package:axichat/main.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks.dart';
import '../security_corpus/security_corpus.dart';

const String _pathSeparatorSlash = '/';
const String _pathSeparatorBackslash = '\\';
const String _pathTraversalToken = '..';
const String _attachmentId = 'attachment-id';
const String _attachmentFileName = '../unsafe.exe';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeUserAgent());
    registerOmemoFallbacks();
  });

  late XmppService xmppService;
  late XmppDatabase database;

  setUp(() {
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockNotificationService = MockNotificationService();
    database = XmppDrift.inMemory();

    prepareMockConnection();

    xmppService = XmppService(
      buildConnection: () => mockConnection,
      buildStateStore: (_, __) => mockStateStore,
      buildDatabase: (_, __) => database,
      notificationService: mockNotificationService,
    );
  });

  tearDown(() async {
    await xmppService.close();
  });

  test('sanitizeAttachmentFilename removes traversal segments', () {
    final corpus = SecurityCorpus.load();
    for (final rawName in corpus.attachmentPathTraversalNames) {
      final sanitized = xmppService.sanitizeAttachmentFilenameForTest(rawName);
      expect(sanitized.contains(_pathTraversalToken), isFalse);
      expect(sanitized.contains(_pathSeparatorSlash), isFalse);
      expect(sanitized.contains(_pathSeparatorBackslash), isFalse);
      expect(sanitized.trim().isNotEmpty, isTrue);
    }
  });

  test('buildAttachmentFileName prefixes metadata id', () {
    const metadata = FileMetadataData(
      id: _attachmentId,
      filename: _attachmentFileName,
    );
    final resolved = xmppService.buildAttachmentFileNameForTest(metadata);
    expect(resolved.startsWith('${_attachmentId}_'), isTrue);
  });
}
