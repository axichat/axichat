import 'dart:convert';
import 'dart:io';

import 'package:axichat/src/common/file_type_detector.dart';
import 'package:axichat/src/common/url_safety.dart';

const String _corpusPath =
    'test/security_corpus/chat_email_security_part3.json';
const String _attachmentsKey = 'attachments';
const String _attachmentRiskCasesKey = 'risk_cases';
const String _attachmentSniffCasesKey = 'sniff_cases';
const String _attachmentPathTraversalKey = 'path_traversal_names';
const String _linksKey = 'links';
const String _linksSafeKey = 'safe';
const String _linksWarnKey = 'warn';
const String _linksUnsafeKey = 'unsafe';
const String _htmlKey = 'html';
const String _htmlSafeKey = 'safe';
const String _htmlUnsafeKey = 'unsafe';
const String _mediaKey = 'media';
const String _mediaDecodeKey = 'decode_cases';
const String _messageOriginKey = 'message_origin';
const String _messageOriginCarbonsKey = 'carbons';
const String _messageOriginMamKey = 'mam';
const String _groupMutationsKey = 'group_mutations';
const String _groupMutationsCasesKey = 'cases';
const String _fileNameKey = 'file_name';
const String _declaredMimeTypeKey = 'declared_mime_type';
const String _detectedMimeTypeKey = 'detected_mime_type';
const String _extensionMimeTypeKey = 'extension_mime_type';
const String _expectedRiskKey = 'expected_risk';
const String _expectMismatchKey = 'expect_mismatch';
const String _expectedPreferredMimeTypeKey = 'expected_preferred_mime_type';
const String _labelKey = 'label';
const String _bytesBase64Key = 'bytes_base64';
const String _expectedDetectedMimeTypeKey = 'expected_detected_mime_type';
const String _urlKey = 'url';
const String _warningsKey = 'warnings';
const String _inputKey = 'input';
const String _expectContainsKey = 'expect_contains';
const String _expectNotContainsKey = 'expect_not_contains';
const String _expectSafeKey = 'expect_safe';
const String _fromKey = 'from';
const String _toKey = 'to';
const String _typeKey = 'type';
const String _isFromMamKey = 'is_from_mam';
const String _accountJidKey = 'account_jid';
const String _expectValidKey = 'expect_valid';
const String _expectAuthorizedKey = 'expect_authorized';

enum LinkSafetyExpectation {
  safe,
  warn,
  unsafe;
}

enum MessageOriginExpectation {
  valid,
  invalid;

  bool get isValid => this == valid;
}

enum GroupMutationExpectation {
  authorized,
  rejected;

  bool get isAuthorized => this == authorized;
}

extension LinkSafetyWarningParsing on LinkSafetyWarning {
  static LinkSafetyWarning parse(String raw) => switch (raw) {
        'punycode' => LinkSafetyWarning.punycode,
        'mixedScript' => LinkSafetyWarning.mixedScript,
        'bidiControl' => LinkSafetyWarning.bidiControl,
        'zeroWidth' => LinkSafetyWarning.zeroWidth,
        'shortener' => LinkSafetyWarning.shortener,
        _ => throw StateError('Unknown warning: $raw'),
      };
}

extension FileOpenRiskParsing on FileOpenRisk {
  static FileOpenRisk parse(String raw) => switch (raw) {
        'safe' => FileOpenRisk.safe,
        'warning' => FileOpenRisk.warning,
        _ => throw StateError('Unknown risk: $raw'),
      };
}

extension MessageOriginExpectationParsing on MessageOriginExpectation {
  static MessageOriginExpectation parse(bool raw) =>
      raw ? MessageOriginExpectation.valid : MessageOriginExpectation.invalid;
}

extension GroupMutationExpectationParsing on GroupMutationExpectation {
  static GroupMutationExpectation parse(bool raw) => raw
      ? GroupMutationExpectation.authorized
      : GroupMutationExpectation.rejected;
}

class AttachmentRiskCase {
  const AttachmentRiskCase({
    required this.fileName,
    required this.declaredMimeType,
    required this.detectedMimeType,
    required this.extensionMimeType,
    required this.expectedRisk,
    required this.expectMismatch,
    this.expectedPreferredMimeType,
  });

  final String fileName;
  final String? declaredMimeType;
  final String? detectedMimeType;
  final String? extensionMimeType;
  final FileOpenRisk expectedRisk;
  final bool expectMismatch;
  final String? expectedPreferredMimeType;

  FileTypeReport toReport() => FileTypeReport(
        detectedMimeType: detectedMimeType,
        declaredMimeType: declaredMimeType,
        extensionMimeType: extensionMimeType,
      );

  static AttachmentRiskCase fromJson(Map<String, dynamic> json) {
    return AttachmentRiskCase(
      fileName: json[_fileNameKey] as String? ?? '',
      declaredMimeType: json[_declaredMimeTypeKey] as String?,
      detectedMimeType: json[_detectedMimeTypeKey] as String?,
      extensionMimeType: json[_extensionMimeTypeKey] as String?,
      expectedRisk:
          FileOpenRiskParsing.parse(json[_expectedRiskKey] as String? ?? ''),
      expectMismatch: json[_expectMismatchKey] as bool? ?? false,
      expectedPreferredMimeType: json[_expectedPreferredMimeTypeKey] as String?,
    );
  }
}

class AttachmentSniffCase {
  const AttachmentSniffCase({
    required this.label,
    required this.bytesBase64,
    required this.declaredMimeType,
    required this.fileName,
    required this.expectedDetectedMimeType,
    required this.expectMismatch,
  });

  final String label;
  final String bytesBase64;
  final String? declaredMimeType;
  final String fileName;
  final String expectedDetectedMimeType;
  final bool expectMismatch;

  static AttachmentSniffCase fromJson(Map<String, dynamic> json) {
    return AttachmentSniffCase(
      label: json[_labelKey] as String? ?? '',
      bytesBase64: json[_bytesBase64Key] as String? ?? '',
      declaredMimeType: json[_declaredMimeTypeKey] as String?,
      fileName: json[_fileNameKey] as String? ?? '',
      expectedDetectedMimeType:
          json[_expectedDetectedMimeTypeKey] as String? ?? '',
      expectMismatch: json[_expectMismatchKey] as bool? ?? false,
    );
  }
}

class LinkCorpusCase {
  const LinkCorpusCase({
    required this.url,
    required this.expectation,
    required this.expectedWarnings,
  });

  final String url;
  final LinkSafetyExpectation expectation;
  final Set<LinkSafetyWarning> expectedWarnings;

  static LinkCorpusCase fromJson(
    Map<String, dynamic> json,
    LinkSafetyExpectation expectation,
  ) {
    final warningsRaw = json[_warningsKey];
    final warnings = warningsRaw is List
        ? warningsRaw
            .whereType<String>()
            .map(LinkSafetyWarningParsing.parse)
            .toSet()
        : <LinkSafetyWarning>{};
    return LinkCorpusCase(
      url: json[_urlKey] as String? ?? '',
      expectation: expectation,
      expectedWarnings: warnings,
    );
  }
}

class HtmlCorpusCase {
  const HtmlCorpusCase({
    required this.input,
    required this.expectContains,
    required this.expectNotContains,
  });

  final String input;
  final List<String> expectContains;
  final List<String> expectNotContains;

  static HtmlCorpusCase fromJson(Map<String, dynamic> json) {
    final containsRaw = json[_expectContainsKey];
    final notContainsRaw = json[_expectNotContainsKey];
    return HtmlCorpusCase(
      input: json[_inputKey] as String? ?? '',
      expectContains:
          containsRaw is List ? containsRaw.whereType<String>().toList() : [],
      expectNotContains: notContainsRaw is List
          ? notContainsRaw.whereType<String>().toList()
          : [],
    );
  }
}

class MediaDecodeCase {
  const MediaDecodeCase({
    required this.label,
    required this.bytesBase64,
    required this.expectSafe,
  });

  final String label;
  final String bytesBase64;
  final bool expectSafe;

  static MediaDecodeCase fromJson(Map<String, dynamic> json) {
    return MediaDecodeCase(
      label: json[_labelKey] as String? ?? '',
      bytesBase64: json[_bytesBase64Key] as String? ?? '',
      expectSafe: json[_expectSafeKey] as bool? ?? false,
    );
  }
}

class MessageOriginCase {
  const MessageOriginCase({
    required this.from,
    required this.to,
    required this.accountJid,
    required this.expectation,
    this.type,
  });

  final String from;
  final String to;
  final String accountJid;
  final MessageOriginExpectation expectation;
  final String? type;

  static MessageOriginCase fromJson(Map<String, dynamic> json) {
    return MessageOriginCase(
      from: json[_fromKey] as String? ?? '',
      to: json[_toKey] as String? ?? '',
      accountJid: json[_accountJidKey] as String? ?? '',
      expectation: MessageOriginExpectationParsing.parse(
        json[_expectValidKey] as bool? ?? false,
      ),
      type: json[_typeKey] as String?,
    );
  }
}

class GroupMutationCase {
  const GroupMutationCase({
    required this.label,
    required this.isFromMam,
    required this.expectation,
  });

  final String label;
  final bool isFromMam;
  final GroupMutationExpectation expectation;

  static GroupMutationCase fromJson(Map<String, dynamic> json) {
    return GroupMutationCase(
      label: json[_labelKey] as String? ?? '',
      isFromMam: json[_isFromMamKey] as bool? ?? false,
      expectation: GroupMutationExpectationParsing.parse(
        json[_expectAuthorizedKey] as bool? ?? false,
      ),
    );
  }
}

class SecurityCorpus {
  SecurityCorpus({
    required this.attachmentRiskCases,
    required this.attachmentSniffCases,
    required this.attachmentPathTraversalNames,
    required this.linkCases,
    required this.htmlUnsafeCases,
    required this.htmlSafeCases,
    required this.mediaDecodeCases,
    required this.messageOriginCarbons,
    required this.messageOriginMam,
    required this.groupMutationCases,
  });

  final List<AttachmentRiskCase> attachmentRiskCases;
  final List<AttachmentSniffCase> attachmentSniffCases;
  final List<String> attachmentPathTraversalNames;
  final List<LinkCorpusCase> linkCases;
  final List<HtmlCorpusCase> htmlUnsafeCases;
  final List<HtmlCorpusCase> htmlSafeCases;
  final List<MediaDecodeCase> mediaDecodeCases;
  final List<MessageOriginCase> messageOriginCarbons;
  final List<MessageOriginCase> messageOriginMam;
  final List<GroupMutationCase> groupMutationCases;

  static SecurityCorpus load() {
    final file = File(_corpusPath);
    final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final attachments = _mapSection(raw, _attachmentsKey);
    final links = _mapSection(raw, _linksKey);
    final html = _mapSection(raw, _htmlKey);
    final media = _mapSection(raw, _mediaKey);
    final messageOrigin = _mapSection(raw, _messageOriginKey);
    final groupMutations = _mapSection(raw, _groupMutationsKey);
    final linkCases = <LinkCorpusCase>[
      ..._parseList(
        links,
        _linksSafeKey,
        (entry) => LinkCorpusCase.fromJson(
          entry,
          LinkSafetyExpectation.safe,
        ),
      ),
      ..._parseList(
        links,
        _linksWarnKey,
        (entry) => LinkCorpusCase.fromJson(
          entry,
          LinkSafetyExpectation.warn,
        ),
      ),
      ..._parseList(
        links,
        _linksUnsafeKey,
        (entry) => LinkCorpusCase.fromJson(
          entry,
          LinkSafetyExpectation.unsafe,
        ),
      ),
    ];
    return SecurityCorpus(
      attachmentRiskCases: _parseList(
        attachments,
        _attachmentRiskCasesKey,
        AttachmentRiskCase.fromJson,
      ),
      attachmentSniffCases: _parseList(
        attachments,
        _attachmentSniffCasesKey,
        AttachmentSniffCase.fromJson,
      ),
      attachmentPathTraversalNames: _parseStringList(
        attachments,
        _attachmentPathTraversalKey,
      ),
      linkCases: linkCases,
      htmlUnsafeCases: _parseList(
        html,
        _htmlUnsafeKey,
        HtmlCorpusCase.fromJson,
      ),
      htmlSafeCases: _parseList(
        html,
        _htmlSafeKey,
        HtmlCorpusCase.fromJson,
      ),
      mediaDecodeCases: _parseList(
        media,
        _mediaDecodeKey,
        MediaDecodeCase.fromJson,
      ),
      messageOriginCarbons: _parseList(
        messageOrigin,
        _messageOriginCarbonsKey,
        MessageOriginCase.fromJson,
      ),
      messageOriginMam: _parseList(
        messageOrigin,
        _messageOriginMamKey,
        MessageOriginCase.fromJson,
      ),
      groupMutationCases: _parseList(
        groupMutations,
        _groupMutationsCasesKey,
        GroupMutationCase.fromJson,
      ),
    );
  }
}

Map<String, dynamic> _mapSection(Map<String, dynamic> root, String key) {
  final section = root[key];
  if (section is Map<String, dynamic>) {
    return section;
  }
  return <String, dynamic>{};
}

List<T> _parseList<T>(
  Map<String, dynamic> section,
  String key,
  T Function(Map<String, dynamic>) builder,
) {
  final raw = section[key];
  if (raw is! List) {
    return <T>[];
  }
  final items = <T>[];
  for (final entry in raw) {
    if (entry is Map<String, dynamic>) {
      items.add(builder(entry));
    }
  }
  return List<T>.unmodifiable(items);
}

List<String> _parseStringList(Map<String, dynamic> section, String key) {
  final raw = section[key];
  if (raw is! List) {
    return <String>[];
  }
  final items = raw.whereType<String>().toList();
  return List<String>.unmodifiable(items);
}
