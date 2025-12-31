import 'dart:async';
import 'dart:io';

import 'package:axichat/main.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart' hide uuid;
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:path/path.dart' as p;

import '../mocks.dart';

const String _accountJid = jid;
const String _peerJid = 'peer@axi.im';
const String _peerFullJid = 'peer@axi.im/resource';
const String _uploadServiceJid = 'upload.axi.im';
const String _slotPutUrl = 'https://upload.axi.im/put';
const String _slotGetUrl = 'https://upload.axi.im/get';
const String _slotPutUrlInsecure = 'http://upload.axi.im/put';
const String _slotGetUrlInsecure = 'http://upload.axi.im/get';
const String _oobUrl = 'https://files.axi.im/file.png';
const String _oobFtpUrl = 'ftp://files.axi.im/file.png';
const String _oobDesc = 'Sample File';
const String _oobDescWhitespace = '  Sample File  ';
const String _messageBody = 'hello';
const String _fileName = 'upload.png';
const String _mimeType = 'image/png';
const String _invalidSlotXmlns = 'urn:invalid';
const String _invalidUrl = 'https://%';
const String _tempDirPrefix = 'axi_xmpp_upload_';
const String _dataFormTypeResult = 'result';
const String _maxFileSizeFieldVar = 'max-file-size';
const int _maxFileSizeBytes = 1024;
const int _smallMaxFileSizeBytes = 1;
const int _declaredSizeBytesMismatch = 0;
const String _identityCategory = 'store';
const String _identityType = 'file';
const String _headerNameAuth = 'Authorization';
const String _headerValueAuth = 'Bearer token';
const String _headerNameExpires = 'eXpires';
const String _headerValueExpires = 'Sun, 01 Jan 2026 00:00:00 GMT';
const String _headerNameCookieRaw = 'Cookie\r\n';
const String _headerValueCookieRaw = 'session\r\n';
const String _headerNameDisallowed = 'X-Ignore';
const String _headerValueDisallowed = 'nope';
const String _slotTag = 'slot';
const String _putTag = 'put';
const String _getTag = 'get';
const String _headerTag = 'header';
const String _headerNameAttr = 'name';
const String _urlAttr = 'url';
const String _requestTag = 'request';
const String _filenameAttr = 'filename';
const String _sizeAttr = 'size';
const String _contentTypeAttr = 'content-type';
const String _iqTag = 'iq';
const String _typeAttr = 'type';
const String _toAttr = 'to';
const String _errorTag = 'error';
const String _notAcceptableTag = 'not-acceptable';
const String _iqTypeGet = 'get';
const String _iqTypeResult = 'result';
const String _iqTypeError = 'error';
const String _expectedFilenameFromUrl = 'file.png';
const String _expectedDescTrimmed = 'Sample File';
const String _expectedCookieName = 'Cookie';
const String _expectedCookieValue = 'session';
const int _expectedHeaderCount = 3;
const int _unknownContentLength = -1;
const int _httpStatusCreated = HttpStatus.created;
const int _httpStatusServerError = HttpStatus.internalServerError;
const List<int> _attachmentBytes = <int>[1, 2, 3, 4];
const List<String> _noInstructions = <String>[];
const List<mox.DataFormOption> _noOptions = <mox.DataFormOption>[];
const List<mox.DataFormField> _noReportedFields = <mox.DataFormField>[];
const List<List<mox.DataFormField>> _noFormItems = <List<mox.DataFormField>>[];
const List<mox.Identity> _noIdentities = <mox.Identity>[];
const List<String> _noFeatures = <String>[];
const List<mox.DataForm> _noExtendedInfo = <mox.DataForm>[];
const List<mox.XMLNode> _noHeaders = <mox.XMLNode>[];
const List<String> _expectedOobSourceUrls = <String>[_oobUrl];
const List<String> _expectedOobFtpSourceUrls = <String>[_oobFtpUrl];
const List<String> _expectedHeaderNames = <String>[
  _headerNameAuth,
  _headerNameExpires,
  _expectedCookieName,
];
const List<String> _expectedHeaderValues = <String>[
  _headerValueAuth,
  _headerValueExpires,
  _expectedCookieValue,
];
const List<String> _expectedUploadSourceUrls = <String>[_slotGetUrl];

class MockHttpFileUploadManager extends Mock
    implements mox.HttpFileUploadManager {}

class MockDiscoManager extends Mock implements mox.DiscoManager {}

class RecordingHttpHeaders extends Mock implements HttpHeaders {
  final Map<String, List<String>> _valuesByName = <String, List<String>>{};
  final List<String> _order = <String>[];
  int? _contentLength;
  ContentType? _contentType;

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    final normalized = name.toLowerCase();
    _valuesByName.putIfAbsent(normalized, () => <String>[]).add(
          value.toString(),
        );
    _order.add(name);
  }

  @override
  int get contentLength => _contentLength ?? _unknownContentLength;

  @override
  set contentLength(int value) => _contentLength = value;

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) => _contentType = value;

  List<String> get headerNamesInOrder => List<String>.unmodifiable(_order);

  List<String> valuesFor(String name) => List<String>.unmodifiable(
        _valuesByName[name.toLowerCase()] ?? const <String>[],
      );
}

class RecordingHttpResponse extends Mock implements HttpClientResponse {
  RecordingHttpResponse({
    required this.statusCode,
    List<int> body = const <int>[],
  }) : _stream = body.isEmpty
            ? const Stream<List<int>>.empty()
            : Stream<List<int>>.fromIterable(<List<int>>[body]);

  final Stream<List<int>> _stream;

  @override
  final int statusCode;

  @override
  HttpHeaders get headers => RecordingHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _stream.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
}

class RecordingHttpRequest extends Mock implements HttpClientRequest {
  RecordingHttpRequest({
    required this.method,
    required this.uri,
    required this.responseStatusCode,
    required this.responseBody,
  });

  @override
  final String method;
  @override
  final Uri uri;
  final RecordingHttpHeaders _headers = RecordingHttpHeaders();
  final List<int> bodyBytes = <int>[];
  final int responseStatusCode;
  final List<int> responseBody;

  @override
  HttpHeaders get headers => _headers;

  RecordingHttpHeaders get recordedHeaders => _headers;

  @override
  void add(List<int> data) {
    bodyBytes.addAll(data);
  }

  @override
  Future<HttpClientResponse> close() async => RecordingHttpResponse(
        statusCode: responseStatusCode,
        body: responseBody,
      );
}

class RecordingHttpClient extends Mock implements HttpClient {
  RecordingHttpClient({
    required this.responseStatusCode,
    List<int> responseBody = const <int>[],
  }) : _responseBody = responseBody;

  final int responseStatusCode;
  final List<int> _responseBody;
  RecordingHttpRequest? lastRequest;
  Duration? _connectionTimeout;

  @override
  Duration? get connectionTimeout => _connectionTimeout;

  @override
  set connectionTimeout(Duration? value) => _connectionTimeout = value;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = RecordingHttpRequest(
      method: method,
      uri: url,
      responseStatusCode: responseStatusCode,
      responseBody: _responseBody,
    );
    lastRequest = request;
    return request;
  }

  @override
  void close({bool force = false}) {}
}

class _AttachmentFixture {
  _AttachmentFixture({
    required this.directory,
    required this.attachment,
  });

  final Directory directory;
  final EmailAttachment attachment;

  Future<void> dispose() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

mox.MessageEvent _buildOobMessageEvent({
  required String fromJid,
  required String toJid,
  required String id,
  String? url,
  String? desc,
  String? body,
}) {
  final extensions = <mox.StanzaHandlerExtension>[
    mox.OOBData(url, desc),
    mox.MessageIdData(id),
    if (body != null) mox.MessageBodyData(body),
  ];
  return mox.MessageEvent(
    mox.JID.fromString(fromJid),
    mox.JID.fromString(toJid),
    false,
    mox.TypedMap<mox.StanzaHandlerExtension>.fromList(extensions),
    id: id,
  );
}

mox.XMLNode _buildHeaderNode({
  required String name,
  required String value,
}) {
  return mox.XMLNode(
    tag: _headerTag,
    attributes: {
      _headerNameAttr: name,
    },
    text: value,
  );
}

mox.Stanza _buildUploadSlotResult({
  required String putUrl,
  required String getUrl,
  List<mox.XMLNode> headers = _noHeaders,
}) {
  final putNode = mox.XMLNode(
    tag: _putTag,
    attributes: {
      _urlAttr: putUrl,
    },
    children: headers,
  );
  final getNode = mox.XMLNode(
    tag: _getTag,
    attributes: {
      _urlAttr: getUrl,
    },
  );
  final slotNode = mox.XMLNode.xmlns(
    tag: _slotTag,
    xmlns: mox.httpFileUploadXmlns,
    children: [
      putNode,
      getNode,
    ],
  );
  return mox.Stanza.iq(
    type: _iqTypeResult,
    children: [
      slotNode,
    ],
  );
}

mox.Stanza _buildUploadErrorResult({required String conditionTag}) {
  return mox.Stanza.iq(
    type: _iqTypeError,
    children: [
      mox.XMLNode(
        tag: _errorTag,
        children: [
          mox.XMLNode.xmlns(
            tag: conditionTag,
            xmlns: mox.fullStanzaXmlns,
          ),
        ],
      ),
    ],
  );
}

mox.DiscoInfo _buildUploadDiscoInfo({
  required String jid,
  required int? maxFileSizeBytes,
}) {
  final fields = maxFileSizeBytes == null
      ? const <mox.DataFormField>[]
      : <mox.DataFormField>[
          mox.DataFormField(
            options: _noOptions,
            values: [
              maxFileSizeBytes.toString(),
            ],
            isRequired: false,
            varAttr: _maxFileSizeFieldVar,
          ),
        ];
  final form = mox.DataForm(
    type: _dataFormTypeResult,
    instructions: _noInstructions,
    fields: fields,
    reported: _noReportedFields,
    items: _noFormItems,
  );
  return mox.DiscoInfo(
    const [
      mox.httpFileUploadXmlns,
    ],
    const [
      mox.Identity(
        category: _identityCategory,
        type: _identityType,
      ),
    ],
    [
      form,
    ],
    null,
    mox.JID.fromString(jid),
  );
}

mox.DiscoInfo _buildEmptyDiscoInfo({required String jid}) {
  return mox.DiscoInfo(
    _noFeatures,
    _noIdentities,
    _noExtendedInfo,
    null,
    mox.JID.fromString(jid),
  );
}

Future<_AttachmentFixture> _createAttachmentFixture({
  int? sizeBytes,
}) async {
  final directory = await Directory.systemTemp.createTemp(_tempDirPrefix);
  final file = File(p.join(directory.path, _fileName));
  await file.writeAsBytes(_attachmentBytes, flush: true);
  final attachment = EmailAttachment(
    path: file.path,
    fileName: _fileName,
    sizeBytes: sizeBytes ?? _attachmentBytes.length,
    mimeType: _mimeType,
  );
  return _AttachmentFixture(
    directory: directory,
    attachment: attachment,
  );
}

Future<void> _configureHttpUploadSupport({
  required StreamController<mox.XmppEvent> eventStreamController,
  required MockHttpFileUploadManager uploadManager,
  required MockDiscoManager discoManager,
  required mox.DiscoInfo uploadInfo,
}) async {
  when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
  when(() => mockConnection.requestRoster()).thenAnswer((_) async => null);
  when(() => mockConnection.requestBlocklist()).thenAnswer((_) async => null);
  when(() => mockConnection.getManager<mox.HttpFileUploadManager>())
      .thenReturn(uploadManager);
  when(() => mockConnection.getManager<mox.DiscoManager>())
      .thenReturn(discoManager);
  when(() => uploadManager.isSupported()).thenAnswer((_) async => true);
  when(() => discoManager.performDiscoSweep()).thenAnswer(
    (_) async => moxlib.Result<mox.DiscoError, List<mox.DiscoInfo>>(
      [
        uploadInfo,
      ],
    ),
  );
  when(() => discoManager.discoInfoQuery(any())).thenAnswer(
    (_) async => moxlib.Result<mox.StanzaError, mox.DiscoInfo>(
      _buildEmptyDiscoInfo(jid: _uploadServiceJid),
    ),
  );

  eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
  await pumpEventQueue();
}

Future<T> _runWithHttpClient<T>({
  required RecordingHttpClient client,
  required Future<T> Function() body,
}) {
  return HttpOverrides.runZoned(
    body,
    createHttpClient: (_) => client,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeMessageEvent());
    registerFallbackValue(FakeUserAgent());
    registerFallbackValue(FakeStanzaDetails());
    registerOmemoFallbacks();
    registerFallbackValue(mox.ChatMarker.received);
  });

  late XmppService xmppService;
  late XmppDatabase database;
  late StreamController<mox.XmppEvent> eventStreamController;

  setUp(() async {
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockNotificationService = MockNotificationService();
    database = XmppDrift.inMemory();
    eventStreamController = StreamController<mox.XmppEvent>.broadcast();

    prepareMockConnection();

    when(() => mockConnection.asBroadcastStream())
        .thenAnswer((_) => eventStreamController.stream);
    when(
      () => mockNotificationService.sendNotification(
        title: any(named: 'title'),
        body: any(named: 'body'),
        extraConditions: any(named: 'extraConditions'),
        allowForeground: any(named: 'allowForeground'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});

    xmppService = XmppService(
      buildConnection: () => mockConnection,
      buildStateStore: (_, __) => mockStateStore,
      buildDatabase: (_, __) => database,
      notificationService: mockNotificationService,
    );

    await connectSuccessfully(xmppService);
  });

  tearDown(() async {
    await eventStreamController.close();
    await database.deleteAll();
    await xmppService.close();
    resetMocktailState();
  });

  group('XEP-0066 OOB message handling', () {
    test('stores file metadata for jabber:x:oob messages', () async {
      final messageId = uuid.v4();
      final event = _buildOobMessageEvent(
        fromJid: _peerFullJid,
        toJid: _accountJid,
        id: messageId,
        url: _oobUrl,
      );

      eventStreamController.add(event);
      await pumpEventQueue();

      final stored = await database.getMessageByStanzaID(messageId);
      expect(stored, isNotNull);
      expect(stored?.fileMetadataID, isNotNull);
      expect(stored?.body?.contains(_expectedFilenameFromUrl), isTrue);

      final metadataId = stored!.fileMetadataID!;
      final metadata = await database.getFileMetadata(metadataId);
      expect(metadata, isNotNull);
      expect(metadata?.sourceUrls, equals(_expectedOobSourceUrls));
      expect(metadata?.filename, equals(_expectedFilenameFromUrl));
      expect(metadata?.path, isNull);
    });

    test('uses trimmed OOB desc as filename when present', () async {
      final messageId = uuid.v4();
      final event = _buildOobMessageEvent(
        fromJid: _peerFullJid,
        toJid: _accountJid,
        id: messageId,
        url: _oobUrl,
        desc: _oobDescWhitespace,
      );

      eventStreamController.add(event);
      await pumpEventQueue();

      final stored = await database.getMessageByStanzaID(messageId);
      final metadataId = stored?.fileMetadataID;
      expect(metadataId, isNotNull);

      final metadata = await database.getFileMetadata(metadataId!);
      expect(metadata?.filename, equals(_expectedDescTrimmed));
    });

    test('preserves the message body when OOB data is present', () async {
      final messageId = uuid.v4();
      final event = _buildOobMessageEvent(
        fromJid: _peerFullJid,
        toJid: _accountJid,
        id: messageId,
        url: _oobUrl,
        desc: _oobDesc,
        body: _messageBody,
      );

      eventStreamController.add(event);
      await pumpEventQueue();

      final stored = await database.getMessageByStanzaID(messageId);
      expect(stored, isNotNull);
      expect(stored?.body, equals(_messageBody));
      expect(stored?.fileMetadataID, isNotNull);
    });

    test('accepts non-http OOB urls without crashing', () async {
      final messageId = uuid.v4();
      final event = _buildOobMessageEvent(
        fromJid: _peerFullJid,
        toJid: _accountJid,
        id: messageId,
        url: _oobFtpUrl,
      );

      eventStreamController.add(event);
      await pumpEventQueue();

      final stored = await database.getMessageByStanzaID(messageId);
      expect(stored, isNotNull);
      final metadataId = stored?.fileMetadataID;
      expect(metadataId, isNotNull);

      final metadata = await database.getFileMetadata(metadataId!);
      expect(metadata?.sourceUrls, equals(_expectedOobFtpSourceUrls));
    });

    test('ignores OOB metadata when url is missing', () async {
      final messageId = uuid.v4();
      final event = _buildOobMessageEvent(
        fromJid: _peerFullJid,
        toJid: _accountJid,
        id: messageId,
        desc: _oobDesc,
      );

      eventStreamController.add(event);
      await pumpEventQueue();

      final stored = await database.getMessageByStanzaID(messageId);
      expect(stored, isNotNull);
      expect(stored?.fileMetadataID, isNull);
    });
  });

  group('XEP-0363 discovery', () {
    test('refreshes http upload support from disco sweep', () async {
      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _maxFileSizeBytes,
      );

      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      final support = xmppService.httpUploadSupport;
      expect(support.supported, isTrue);
      expect(support.entityJid, equals(_uploadServiceJid));
      expect(support.maxFileSizeBytes, equals(_maxFileSizeBytes));
    });

    test('missing max-file-size leaves maxFileSizeBytes null', () async {
      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: null,
      );

      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      final support = xmppService.httpUploadSupport;
      expect(support.supported, isTrue);
      expect(support.maxFileSizeBytes, isNull);
    });
  });

  group('XEP-0363 slot requests', () {
    test('includes filename, size, and content-type attributes', () async {
      final fixture = await _createAttachmentFixture();
      addTearDown(fixture.dispose);

      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _maxFileSizeBytes,
      );
      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      mox.StanzaDetails? capturedDetails;
      when(() => mockConnection.sendStanza(any())).thenAnswer(
        (invocation) async {
          capturedDetails =
              invocation.positionalArguments.first as mox.StanzaDetails;
          return _buildUploadSlotResult(
            putUrl: _slotPutUrl,
            getUrl: _slotGetUrl,
          );
        },
      );
      when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
      when(() => mockConnection.sendMessage(any()))
          .thenAnswer((_) async => true);

      final client =
          RecordingHttpClient(responseStatusCode: _httpStatusCreated);
      await _runWithHttpClient(
        client: client,
        body: () => xmppService.sendAttachment(
          jid: _peerJid,
          attachment: fixture.attachment,
        ),
      );

      final stanza = capturedDetails?.stanza;
      expect(stanza, isNotNull);
      expect(stanza?.tag, equals(_iqTag));
      expect(stanza?.attributes[_typeAttr], equals(_iqTypeGet));
      expect(stanza?.attributes[_toAttr], equals(_uploadServiceJid));

      final request = stanza?.firstTag(
        _requestTag,
        xmlns: mox.httpFileUploadXmlns,
      );
      expect(request, isNotNull);
      expect(request?.attributes[_filenameAttr], equals(_fileName));
      expect(
        request?.attributes[_sizeAttr],
        equals(_attachmentBytes.length.toString()),
      );
      expect(request?.attributes[_contentTypeAttr], equals(_mimeType));
    });

    test('uses actual file size when declared size mismatches', () async {
      final fixture = await _createAttachmentFixture(
        sizeBytes: _declaredSizeBytesMismatch,
      );
      addTearDown(fixture.dispose);

      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _maxFileSizeBytes,
      );
      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      mox.StanzaDetails? capturedDetails;
      when(() => mockConnection.sendStanza(any())).thenAnswer(
        (invocation) async {
          capturedDetails =
              invocation.positionalArguments.first as mox.StanzaDetails;
          return _buildUploadSlotResult(
            putUrl: _slotPutUrl,
            getUrl: _slotGetUrl,
          );
        },
      );
      when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
      when(() => mockConnection.sendMessage(any()))
          .thenAnswer((_) async => true);

      final client =
          RecordingHttpClient(responseStatusCode: _httpStatusCreated);
      await _runWithHttpClient(
        client: client,
        body: () => xmppService.sendAttachment(
          jid: _peerJid,
          attachment: fixture.attachment,
        ),
      );

      final stanza = capturedDetails?.stanza;
      final request = stanza?.firstTag(
        _requestTag,
        xmlns: mox.httpFileUploadXmlns,
      );
      expect(request, isNotNull);
      expect(
        request?.attributes[_sizeAttr],
        equals(_attachmentBytes.length.toString()),
      );
    });

    test('rejects uploads larger than advertised max file size', () async {
      final fixture = await _createAttachmentFixture();
      addTearDown(fixture.dispose);

      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _smallMaxFileSizeBytes,
      );
      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      expect(
        () => xmppService.sendAttachment(
          jid: _peerJid,
          attachment: fixture.attachment,
        ),
        throwsA(isA<XmppFileTooBigException>()),
      );
    });

    test('maps not-acceptable slot errors to file-too-big', () async {
      final fixture = await _createAttachmentFixture();
      addTearDown(fixture.dispose);

      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _maxFileSizeBytes,
      );
      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      when(() => mockConnection.sendStanza(any())).thenAnswer(
        (_) async => _buildUploadErrorResult(conditionTag: _notAcceptableTag),
      );

      expect(
        () => xmppService.sendAttachment(
          jid: _peerJid,
          attachment: fixture.attachment,
        ),
        throwsA(isA<XmppFileTooBigException>()),
      );
    });
  });

  group('XEP-0363 slot response parsing', () {
    test('rejects slots missing GET url', () async {
      final fixture = await _createAttachmentFixture();
      addTearDown(fixture.dispose);

      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _maxFileSizeBytes,
      );
      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      final putNode = mox.XMLNode(
        tag: _putTag,
        attributes: {
          _urlAttr: _slotPutUrl,
        },
      );
      final slotNode = mox.XMLNode.xmlns(
        tag: _slotTag,
        xmlns: mox.httpFileUploadXmlns,
        children: [
          putNode,
        ],
      );
      final stanza = mox.Stanza.iq(
        type: _iqTypeResult,
        children: [
          slotNode,
        ],
      );

      when(() => mockConnection.sendStanza(any()))
          .thenAnswer((_) async => stanza);

      expect(
        () => xmppService.sendAttachment(
          jid: _peerJid,
          attachment: fixture.attachment,
        ),
        throwsA(isA<XmppUploadMisconfiguredException>()),
      );
    });

    test('rejects slots missing PUT url', () async {
      final fixture = await _createAttachmentFixture();
      addTearDown(fixture.dispose);

      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _maxFileSizeBytes,
      );
      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      final getNode = mox.XMLNode(
        tag: _getTag,
        attributes: {
          _urlAttr: _slotGetUrl,
        },
      );
      final slotNode = mox.XMLNode.xmlns(
        tag: _slotTag,
        xmlns: mox.httpFileUploadXmlns,
        children: [
          getNode,
        ],
      );
      final stanza = mox.Stanza.iq(
        type: _iqTypeResult,
        children: [
          slotNode,
        ],
      );

      when(() => mockConnection.sendStanza(any()))
          .thenAnswer((_) async => stanza);

      expect(
        () => xmppService.sendAttachment(
          jid: _peerJid,
          attachment: fixture.attachment,
        ),
        throwsA(isA<XmppUploadMisconfiguredException>()),
      );
    });

    test('rejects slots with wrong namespace', () async {
      final fixture = await _createAttachmentFixture();
      addTearDown(fixture.dispose);

      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _maxFileSizeBytes,
      );
      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      final slotNode = mox.XMLNode.xmlns(
        tag: _slotTag,
        xmlns: _invalidSlotXmlns,
        children: [
          mox.XMLNode(
            tag: _putTag,
            attributes: {
              _urlAttr: _slotPutUrl,
            },
          ),
          mox.XMLNode(
            tag: _getTag,
            attributes: {
              _urlAttr: _slotGetUrl,
            },
          ),
        ],
      );
      final stanza = mox.Stanza.iq(
        type: _iqTypeResult,
        children: [
          slotNode,
        ],
      );

      when(() => mockConnection.sendStanza(any()))
          .thenAnswer((_) async => stanza);

      expect(
        () => xmppService.sendAttachment(
          jid: _peerJid,
          attachment: fixture.attachment,
        ),
        throwsA(isA<XmppUploadMisconfiguredException>()),
      );
    });
  });

  group('XEP-0363 slot url validation', () {
    test('rejects non-HTTPS slot urls', () async {
      final fixture = await _createAttachmentFixture();
      addTearDown(fixture.dispose);

      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _maxFileSizeBytes,
      );
      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      when(() => mockConnection.sendStanza(any())).thenAnswer(
        (_) async => _buildUploadSlotResult(
          putUrl: _slotPutUrlInsecure,
          getUrl: _slotGetUrlInsecure,
        ),
      );

      expect(
        () => xmppService.sendAttachment(
          jid: _peerJid,
          attachment: fixture.attachment,
        ),
        throwsA(isA<XmppUploadMisconfiguredException>()),
      );
    });

    test('rejects invalid slot urls', () async {
      final fixture = await _createAttachmentFixture();
      addTearDown(fixture.dispose);

      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _maxFileSizeBytes,
      );
      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      when(() => mockConnection.sendStanza(any())).thenAnswer(
        (_) async => _buildUploadSlotResult(
          putUrl: _invalidUrl,
          getUrl: _slotGetUrl,
        ),
      );

      expect(
        () => xmppService.sendAttachment(
          jid: _peerJid,
          attachment: fixture.attachment,
        ),
        throwsA(isA<XmppUploadMisconfiguredException>()),
      );
    });
  });

  group('XEP-0363 header handling + HTTP PUT', () {
    test('sanitizes and preserves allowed headers in order', () async {
      final fixture = await _createAttachmentFixture();
      addTearDown(fixture.dispose);

      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _maxFileSizeBytes,
      );
      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      final headers = <mox.XMLNode>[
        _buildHeaderNode(
          name: _headerNameAuth,
          value: _headerValueAuth,
        ),
        _buildHeaderNode(
          name: _headerNameExpires,
          value: _headerValueExpires,
        ),
        _buildHeaderNode(
          name: _headerNameCookieRaw,
          value: _headerValueCookieRaw,
        ),
        _buildHeaderNode(
          name: _headerNameDisallowed,
          value: _headerValueDisallowed,
        ),
      ];

      when(() => mockConnection.sendStanza(any())).thenAnswer(
        (_) async => _buildUploadSlotResult(
          putUrl: _slotPutUrl,
          getUrl: _slotGetUrl,
          headers: headers,
        ),
      );
      when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
      when(() => mockConnection.sendMessage(any()))
          .thenAnswer((_) async => true);

      final client =
          RecordingHttpClient(responseStatusCode: _httpStatusCreated);
      await _runWithHttpClient(
        client: client,
        body: () => xmppService.sendAttachment(
          jid: _peerJid,
          attachment: fixture.attachment,
        ),
      );

      final request = client.lastRequest;
      expect(request, isNotNull);
      final recordedHeaders = request!.recordedHeaders;
      final headerNames = recordedHeaders.headerNamesInOrder;
      final headerValues = <String>[
        ...recordedHeaders.valuesFor(_headerNameAuth),
        ...recordedHeaders.valuesFor(_headerNameExpires),
        ...recordedHeaders.valuesFor(_expectedCookieName),
      ];

      expect(headerNames.length, equals(_expectedHeaderCount));
      expect(headerNames, equals(_expectedHeaderNames));
      expect(headerValues, equals(_expectedHeaderValues));
      expect(recordedHeaders.valuesFor(_headerNameDisallowed), isEmpty);
    });

    test('sets content-length and content-type on upload', () async {
      final fixture = await _createAttachmentFixture();
      addTearDown(fixture.dispose);

      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _maxFileSizeBytes,
      );
      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      when(() => mockConnection.sendStanza(any())).thenAnswer(
        (_) async => _buildUploadSlotResult(
          putUrl: _slotPutUrl,
          getUrl: _slotGetUrl,
        ),
      );
      when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
      when(() => mockConnection.sendMessage(any()))
          .thenAnswer((_) async => true);

      final client =
          RecordingHttpClient(responseStatusCode: _httpStatusCreated);
      await _runWithHttpClient(
        client: client,
        body: () => xmppService.sendAttachment(
          jid: _peerJid,
          attachment: fixture.attachment,
        ),
      );

      final request = client.lastRequest;
      expect(request, isNotNull);
      final recordedHeaders = request!.recordedHeaders;
      expect(recordedHeaders.contentLength, equals(_attachmentBytes.length));
      expect(recordedHeaders.contentType?.mimeType, equals(_mimeType));
    });

    test('sends GET url via OOB after successful upload', () async {
      final fixture = await _createAttachmentFixture();
      addTearDown(fixture.dispose);

      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _maxFileSizeBytes,
      );
      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      when(() => mockConnection.sendStanza(any())).thenAnswer(
        (_) async => _buildUploadSlotResult(
          putUrl: _slotPutUrl,
          getUrl: _slotGetUrl,
        ),
      );
      when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
      mox.MessageEvent? sentMessage;
      when(() => mockConnection.sendMessage(any())).thenAnswer(
        (invocation) async {
          sentMessage =
              invocation.positionalArguments.first as mox.MessageEvent;
          return true;
        },
      );

      final client =
          RecordingHttpClient(responseStatusCode: _httpStatusCreated);
      await _runWithHttpClient(
        client: client,
        body: () => xmppService.sendAttachment(
          jid: _peerJid,
          attachment: fixture.attachment,
        ),
      );

      final oob = sentMessage?.extensions.get<mox.OOBData>();
      expect(oob, isNotNull);
      expect(oob?.url, equals(_slotGetUrl));
      expect(oob?.desc, equals(_fileName));
    });

    test('stores only the GET url in attachment metadata', () async {
      final fixture = await _createAttachmentFixture();
      addTearDown(fixture.dispose);

      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _maxFileSizeBytes,
      );
      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      when(() => mockConnection.sendStanza(any())).thenAnswer(
        (_) async => _buildUploadSlotResult(
          putUrl: _slotPutUrl,
          getUrl: _slotGetUrl,
        ),
      );

      final stanzaId = uuid.v4();
      var idIndex = 0;
      final generatedIds = <String>[stanzaId, uuid.v4()];
      when(() => mockConnection.generateId()).thenAnswer((_) {
        if (idIndex < generatedIds.length) {
          final id = generatedIds[idIndex];
          idIndex += 1;
          return id;
        }
        return uuid.v4();
      });
      when(() => mockConnection.sendMessage(any()))
          .thenAnswer((_) async => true);

      final client =
          RecordingHttpClient(responseStatusCode: _httpStatusCreated);
      await _runWithHttpClient(
        client: client,
        body: () => xmppService.sendAttachment(
          jid: _peerJid,
          attachment: fixture.attachment,
        ),
      );

      final stored = await database.getMessageByStanzaID(stanzaId);
      expect(stored, isNotNull);
      final metadataId = stored?.fileMetadataID;
      expect(metadataId, isNotNull);

      final metadata = await database.getFileMetadata(metadataId!);
      expect(metadata?.sourceUrls, equals(_expectedUploadSourceUrls));
    });

    test('reports upload failure on non-2xx status', () async {
      final fixture = await _createAttachmentFixture();
      addTearDown(fixture.dispose);

      final uploadManager = MockHttpFileUploadManager();
      final discoManager = MockDiscoManager();
      final uploadInfo = _buildUploadDiscoInfo(
        jid: _uploadServiceJid,
        maxFileSizeBytes: _maxFileSizeBytes,
      );
      await _configureHttpUploadSupport(
        eventStreamController: eventStreamController,
        uploadManager: uploadManager,
        discoManager: discoManager,
        uploadInfo: uploadInfo,
      );

      when(() => mockConnection.sendStanza(any())).thenAnswer(
        (_) async => _buildUploadSlotResult(
          putUrl: _slotPutUrl,
          getUrl: _slotGetUrl,
        ),
      );

      final stanzaId = uuid.v4();
      var idIndex = 0;
      final generatedIds = <String>[stanzaId, uuid.v4()];
      when(() => mockConnection.generateId()).thenAnswer((_) {
        if (idIndex < generatedIds.length) {
          final id = generatedIds[idIndex];
          idIndex += 1;
          return id;
        }
        return uuid.v4();
      });
      when(() => mockConnection.sendMessage(any()))
          .thenAnswer((_) async => true);

      final client = RecordingHttpClient(
        responseStatusCode: _httpStatusServerError,
      );

      await expectLater(
        () => _runWithHttpClient(
          client: client,
          body: () => xmppService.sendAttachment(
            jid: _peerJid,
            attachment: fixture.attachment,
          ),
        ),
        throwsA(isA<XmppMessageException>()),
      );

      final stored = await database.getMessageByStanzaID(stanzaId);
      expect(stored, isNotNull);
      expect(stored?.error, equals(MessageError.fileUploadFailure));
    });
  });
}
