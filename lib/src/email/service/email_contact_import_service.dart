// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:axichat/src/common/email_validation.dart';
import 'package:axichat/src/email/service/email_contact_import_models.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/util/email_address.dart';
import 'package:path/path.dart' as p;

const int _byteOrderMark = 0xfeff;
const int _utf16CodeUnitSize = 2;
const List<int> _utf8BomBytes = <int>[0xef, 0xbb, 0xbf];
const List<int> _utf16LeBomBytes = <int>[0xff, 0xfe];
const List<int> _utf16BeBomBytes = <int>[0xfe, 0xff];
const int _startIndex = 0;
const int _nextIndex = 1;
const int _headerRowIndex = 0;
const int _firstDataRowIndex = 1;
const int _vcardLastNameIndex = 0;
const int _vcardFirstNameIndex = 1;
const int _vcardAdditionalNameIndex = 2;
const int _vcardPrefixIndex = 3;
const int _vcardSuffixIndex = 4;
const String _csvDelimiter = ',';
const String _csvAlternateDelimiter = ';';
const String _csvQuote = '"';
const String _lineFeed = '\n';
const String _carriageReturn = '\r';
const String _extensionDelimiter = '.';
const String _vcardGroupDelimiter = '.';
const String _emptyValue = '';
const String _spaceValue = ' ';
const String _tabValue = '\t';
const String _angleBracketOpen = '<';
const String _angleBracketClose = '>';
const String _emailAtSymbol = '@';
const String _dotValue = '.';
const String _vcardBeginKey = 'BEGIN:VCARD';
const String _vcardEndKey = 'END:VCARD';
const String _vcardFullNameKey = 'FN';
const String _vcardNameKey = 'N';
const String _vcardEmailKey = 'EMAIL';
const String _vcardValueDelimiter = ':';
const String _vcardNameSeparator = ';';
const String _mailtoPrefix = 'mailto:';
const String _emailHeaderToken = 'email';
const String _emailHeaderTypeToken = 'type';
const String _headerNameKey = 'name';
const String _headerFullNameKey = 'fullname';
const String _headerDisplayNameKey = 'displayname';
const String _headerFileAsKey = 'fileas';
const String _headerFirstNameKey = 'firstname';
const String _headerGivenNameKey = 'givenname';
const String _headerFirstKey = 'first';
const String _headerMiddleNameKey = 'middlename';
const String _headerAdditionalNameKey = 'additionalname';
const String _headerMiddleKey = 'middle';
const String _headerLastNameKey = 'lastname';
const String _headerFamilyNameKey = 'familyname';
const String _headerSurnameKey = 'surname';
const String _headerLastKey = 'last';
const String _headerNicknameKey = 'nickname';
const String _headerShortNameKey = 'shortname';
const String _headerNickKey = 'nick';
const String _newlinePattern = r'\r\n|\n|\r';
const String _vcardEmailSplitPattern = r'[,;]';

final RegExp _lineSplitExpression = RegExp(_newlinePattern);
final RegExp _vcardEmailSplitExpression = RegExp(_vcardEmailSplitPattern);
final RegExp _headerSanitizer = RegExp(r'[^a-z0-9]');

const Set<String> _fullNameHeaderKeys = <String>{
  _headerNameKey,
  _headerFullNameKey,
  _headerDisplayNameKey,
  _headerFileAsKey,
};

const Set<String> _firstNameHeaderKeys = <String>{
  _headerFirstNameKey,
  _headerGivenNameKey,
  _headerFirstKey,
};

const Set<String> _middleNameHeaderKeys = <String>{
  _headerMiddleNameKey,
  _headerAdditionalNameKey,
  _headerMiddleKey,
};

const Set<String> _lastNameHeaderKeys = <String>{
  _headerLastNameKey,
  _headerFamilyNameKey,
  _headerSurnameKey,
  _headerLastKey,
};

const Set<String> _nicknameHeaderKeys = <String>{
  _headerNicknameKey,
  _headerShortNameKey,
  _headerNickKey,
};

class EmailContactImportException implements Exception {
  const EmailContactImportException(this.reason);

  final EmailContactImportFailureReason reason;
}

class EmailContactImportService {
  const EmailContactImportService({required EmailService emailService})
      : _emailService = emailService;

  final EmailService _emailService;

  Future<EmailContactImportSummary> importContacts({
    required File file,
    required EmailContactImportFormat format,
  }) async {
    if (!_emailService.hasActiveSession) {
      throw const EmailContactImportException(
        EmailContactImportFailureReason.noEmailAccount,
      );
    }
    _validateFileExtension(file, format: format);
    final String content = await _readFile(file);
    if (content.trim().isEmpty) {
      throw const EmailContactImportException(
        EmailContactImportFailureReason.emptyFile,
      );
    }
    final List<EmailContactImportContact> contacts =
        _parseContacts(content, format: format);
    if (contacts.isEmpty) {
      throw const EmailContactImportException(
        EmailContactImportFailureReason.noContacts,
      );
    }
    return _importContacts(contacts);
  }

  void _validateFileExtension(
    File file, {
    required EmailContactImportFormat format,
  }) {
    final String extension = p.extension(file.path).toLowerCase();
    if (extension.isEmpty) {
      return;
    }
    final String normalizedExtension = extension.startsWith(_extensionDelimiter)
        ? extension.substring(_nextIndex)
        : extension;
    if (!format.allowedExtensions.contains(normalizedExtension)) {
      throw const EmailContactImportException(
        EmailContactImportFailureReason.unsupportedFileType,
      );
    }
  }

  Future<String> _readFile(File file) async {
    try {
      final List<int> bytes = await file.readAsBytes();
      final String content = _decodeFileBytes(bytes);
      return _stripBom(content);
    } catch (_) {
      throw const EmailContactImportException(
        EmailContactImportFailureReason.readFailure,
      );
    }
  }

  String _decodeFileBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      return _emptyValue;
    }
    if (_startsWithBytes(bytes, _utf8BomBytes)) {
      return utf8.decode(bytes.sublist(_utf8BomBytes.length));
    }
    if (_startsWithBytes(bytes, _utf16LeBomBytes)) {
      return _decodeUtf16(
        bytes.sublist(_utf16LeBomBytes.length),
        Endian.little,
      );
    }
    if (_startsWithBytes(bytes, _utf16BeBomBytes)) {
      return _decodeUtf16(
        bytes.sublist(_utf16BeBomBytes.length),
        Endian.big,
      );
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  bool _startsWithBytes(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) {
      return false;
    }
    for (int index = _startIndex; index < prefix.length; index += _nextIndex) {
      if (bytes[index] != prefix[index]) {
        return false;
      }
    }
    return true;
  }

  String _decodeUtf16(List<int> bytes, Endian endian) {
    if (bytes.isEmpty) {
      return _emptyValue;
    }
    final int length = bytes.length - (bytes.length % _utf16CodeUnitSize);
    if (length <= _startIndex) {
      return _emptyValue;
    }
    final Uint8List data =
        Uint8List.fromList(bytes.sublist(_startIndex, length));
    final ByteData byteData = ByteData.sublistView(data);
    final int codeUnitCount = length ~/ _utf16CodeUnitSize;
    final List<int> codeUnits = List<int>.filled(codeUnitCount, _startIndex);
    for (int index = _startIndex; index < codeUnitCount; index += _nextIndex) {
      final int offset = index * _utf16CodeUnitSize;
      codeUnits[index] = byteData.getUint16(offset, endian);
    }
    return String.fromCharCodes(codeUnits);
  }

  String _stripBom(String content) {
    if (content.isEmpty) {
      return content;
    }
    if (content.codeUnitAt(_startIndex) == _byteOrderMark) {
      return content.substring(_nextIndex);
    }
    return content;
  }

  List<EmailContactImportContact> _parseContacts(
    String content, {
    required EmailContactImportFormat format,
  }) {
    if (format.isVcard) {
      return _parseVcardContacts(content);
    }
    return _parseCsvContacts(content);
  }

  List<EmailContactImportContact> _parseCsvContacts(String content) {
    final String delimiter = _detectCsvDelimiter(content);
    final List<List<String>> rows =
        _CsvParser(delimiter: delimiter).parse(content);
    if (rows.isEmpty) {
      return const <EmailContactImportContact>[];
    }
    final List<String> headers = rows[_headerRowIndex];
    final _CsvHeaderMap headerMap = _CsvHeaderMap.fromHeaders(headers);
    if (headerMap.emailIndices.isEmpty) {
      return _parseHeaderlessCsvContacts(rows);
    }
    final List<EmailContactImportContact> contacts =
        <EmailContactImportContact>[];
    for (int index = _firstDataRowIndex;
        index < rows.length;
        index += _nextIndex) {
      final List<String> row = rows[index];
      final String? displayName = headerMap.displayNameFor(row);
      for (final int emailIndex in headerMap.emailIndices) {
        final String? email = _fieldAt(row, emailIndex);
        if (email == null) {
          continue;
        }
        final List<String> candidates = _extractEmailCandidates(email);
        if (candidates.isEmpty) {
          continue;
        }
        for (final String candidate in candidates) {
          contacts.add(
            EmailContactImportContact(
              address: candidate,
              displayName: displayName,
            ),
          );
        }
      }
    }
    return contacts;
  }

  List<EmailContactImportContact> _parseHeaderlessCsvContacts(
    List<List<String>> rows,
  ) {
    final List<EmailContactImportContact> contacts =
        <EmailContactImportContact>[];
    for (final List<String> row in rows) {
      final _HeaderlessRowParseResult parsed = _parseHeaderlessRow(row);
      if (parsed.emails.isEmpty) {
        continue;
      }
      for (final String email in parsed.emails) {
        contacts.add(
          EmailContactImportContact(
            address: email,
            displayName: parsed.displayName,
          ),
        );
      }
    }
    return contacts;
  }

  _HeaderlessRowParseResult _parseHeaderlessRow(List<String> row) {
    final List<String> emails = <String>[];
    final List<String> nameParts = <String>[];
    for (final String value in row) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final String? bracketed = _extractBracketedEmail(trimmed);
      if (bracketed != null) {
        final List<String> resolved = _filterEmailCandidates(
          _extractEmailCandidates(bracketed),
        );
        if (resolved.isNotEmpty) {
          emails.addAll(resolved);
          final String nameCandidate = trimmed
              .substring(_startIndex, trimmed.indexOf(_angleBracketOpen))
              .trim();
          if (nameCandidate.isNotEmpty) {
            nameParts.add(nameCandidate);
          }
          continue;
        }
      }
      final List<String> candidates = _extractEmailCandidates(trimmed);
      final List<String> resolved = _filterEmailCandidates(candidates);
      if (resolved.isNotEmpty) {
        emails.addAll(resolved);
        continue;
      }
      nameParts.add(trimmed);
    }
    final String? displayName = nameParts.isEmpty ? null : nameParts.first;
    return _HeaderlessRowParseResult(
      emails: emails,
      displayName: displayName,
    );
  }

  List<String> _extractEmailCandidates(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }
    final String? bracketed = _extractBracketedEmail(trimmed);
    final String candidate = bracketed ?? trimmed;
    final String normalized = candidate.toLowerCase();
    final bool hasMailto = normalized.startsWith(_mailtoPrefix);
    final String sanitized =
        hasMailto ? candidate.substring(_mailtoPrefix.length) : candidate;
    final Iterable<String> parts = sanitized.split(_vcardEmailSplitExpression);
    return parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  String? _extractBracketedEmail(String value) {
    final int start = value.indexOf(_angleBracketOpen);
    if (start < _startIndex) {
      return null;
    }
    final int end = value.indexOf(_angleBracketClose, start + _nextIndex);
    if (end <= start) {
      return null;
    }
    return value.substring(start + _nextIndex, end);
  }

  List<String> _filterEmailCandidates(Iterable<String> candidates) {
    final List<String> resolved = <String>[];
    for (final String candidate in candidates) {
      final String normalized = normalizeEmailAddress(candidate);
      if (normalized.isEmpty) {
        continue;
      }
      if (_looksLikeEmail(normalized)) {
        resolved.add(candidate.trim());
      }
    }
    return resolved;
  }

  bool _looksLikeEmail(String value) {
    final String normalized = normalizeEmailAddress(value);
    if (normalized.isEmpty) {
      return false;
    }
    if (normalized.isValidEmailAddress) {
      return true;
    }
    final int atIndex = normalized.indexOf(_emailAtSymbol);
    if (atIndex <= _startIndex || atIndex >= normalized.length - _nextIndex) {
      return false;
    }
    final int dotIndex = normalized.indexOf(
      _dotValue,
      atIndex + _nextIndex,
    );
    if (dotIndex <= atIndex + _nextIndex) {
      return false;
    }
    return dotIndex < normalized.length - _nextIndex;
  }

  String _detectCsvDelimiter(String content) {
    final int lineBreakIndex = content.indexOf(_lineSplitExpression);
    final String sample = lineBreakIndex < _startIndex
        ? content
        : content.substring(_startIndex, lineBreakIndex);
    final int commaCount = _countOccurrences(sample, _csvDelimiter);
    final int semicolonCount =
        _countOccurrences(sample, _csvAlternateDelimiter);
    return semicolonCount > commaCount ? _csvAlternateDelimiter : _csvDelimiter;
  }

  int _countOccurrences(String value, String pattern) {
    if (pattern.isEmpty) {
      return _startIndex;
    }
    int count = _startIndex;
    int start = _startIndex;
    while (true) {
      final int index = value.indexOf(pattern, start);
      if (index < _startIndex) {
        break;
      }
      count += _nextIndex;
      start = index + _nextIndex;
    }
    return count;
  }

  List<EmailContactImportContact> _parseVcardContacts(String content) {
    final List<String> lines = _unfoldVcardLines(content);
    final List<EmailContactImportContact> contacts =
        <EmailContactImportContact>[];
    String? currentName;
    List<String> currentEmails = <String>[];

    void flushCurrentCard() {
      if (currentEmails.isEmpty) {
        currentName = null;
        currentEmails = <String>[];
        return;
      }
      for (final String email in currentEmails) {
        contacts.add(
          EmailContactImportContact(
            address: email,
            displayName: currentName,
          ),
        );
      }
      currentName = null;
      currentEmails = <String>[];
    }

    for (final String line in lines) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final String upper = trimmed.toUpperCase();
      if (upper.startsWith(_vcardBeginKey)) {
        currentName = null;
        currentEmails = <String>[];
        continue;
      }
      if (upper.startsWith(_vcardEndKey)) {
        flushCurrentCard();
        continue;
      }
      if (_isVcardField(upper, _vcardFullNameKey)) {
        final String? value = _vcardValue(trimmed);
        if (value != null && value.trim().isNotEmpty) {
          currentName = value.trim();
        }
        continue;
      }
      if (_isVcardField(upper, _vcardNameKey) &&
          (currentName == null || currentName!.trim().isEmpty)) {
        final String? value = _vcardValue(trimmed);
        final String? name = _displayNameFromVcardName(value);
        if (name != null && name.isNotEmpty) {
          currentName = name;
        }
        continue;
      }
      if (_isVcardField(upper, _vcardEmailKey)) {
        final String? value = _vcardValue(trimmed);
        if (value == null || value.trim().isEmpty) {
          continue;
        }
        final List<String> emails = _splitVcardEmails(value);
        if (emails.isNotEmpty) {
          currentEmails.addAll(emails);
        }
      }
    }

    flushCurrentCard();
    return contacts;
  }

  List<String> _unfoldVcardLines(String content) {
    final List<String> rawLines = content.split(_lineSplitExpression);
    final List<String> unfolded = <String>[];
    final StringBuffer buffer = StringBuffer();
    bool hasBuffer = false;
    for (final String line in rawLines) {
      if (_isVcardContinuationLine(line)) {
        buffer.write(line.trimLeft());
        hasBuffer = true;
        continue;
      }
      if (hasBuffer) {
        unfolded.add(buffer.toString());
        buffer.clear();
        hasBuffer = false;
      }
      if (line.isNotEmpty) {
        buffer.write(line);
        hasBuffer = true;
      }
    }
    if (hasBuffer) {
      unfolded.add(buffer.toString());
    }
    return unfolded;
  }

  bool _isVcardContinuationLine(String line) {
    return line.startsWith(_spaceValue) || line.startsWith(_tabValue);
  }

  bool _isVcardField(String upperLine, String key) {
    final String? field = _vcardFieldName(upperLine);
    return field == key;
  }

  String? _vcardFieldName(String upperLine) {
    final int delimiterIndex = _vcardDelimiterIndex(upperLine);
    if (delimiterIndex <= _startIndex) {
      return null;
    }
    final String rawName = upperLine.substring(_startIndex, delimiterIndex);
    final int groupIndex = rawName.lastIndexOf(_vcardGroupDelimiter);
    if (groupIndex < _startIndex) {
      return rawName;
    }
    return rawName.substring(groupIndex + _nextIndex);
  }

  int _vcardDelimiterIndex(String value) {
    final int valueIndex = value.indexOf(_vcardValueDelimiter);
    final int paramIndex = value.indexOf(_vcardNameSeparator);
    if (valueIndex < _startIndex) {
      return paramIndex;
    }
    if (paramIndex < _startIndex) {
      return valueIndex;
    }
    return valueIndex < paramIndex ? valueIndex : paramIndex;
  }

  String? _vcardValue(String line) {
    final int index = line.indexOf(_vcardValueDelimiter);
    if (index < _startIndex) {
      return null;
    }
    return line.substring(index + _nextIndex);
  }

  String? _displayNameFromVcardName(String? value) {
    final String? normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final List<String> parts = normalized.split(_vcardNameSeparator);
    final List<String?> ordered = <String?>[
      _safePart(parts, _vcardPrefixIndex),
      _safePart(parts, _vcardFirstNameIndex),
      _safePart(parts, _vcardAdditionalNameIndex),
      _safePart(parts, _vcardLastNameIndex),
      _safePart(parts, _vcardSuffixIndex),
    ];
    return _joinNonEmpty(ordered);
  }

  String? _safePart(List<String> parts, int index) {
    if (index < _startIndex || index >= parts.length) {
      return null;
    }
    final String value = parts[index].trim();
    return value.isEmpty ? null : value;
  }

  List<String> _splitVcardEmails(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }
    final String sanitized = trimmed.toLowerCase().startsWith(_mailtoPrefix)
        ? trimmed.substring(_mailtoPrefix.length)
        : trimmed;
    final Iterable<String> parts = sanitized.split(_vcardEmailSplitExpression);
    return parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  Future<EmailContactImportSummary> _importContacts(
    List<EmailContactImportContact> contacts,
  ) async {
    final Set<String> seen = <String>{};
    int duplicates = _startIndex;
    int invalid = _startIndex;
    int failed = _startIndex;
    int imported = _startIndex;

    for (final EmailContactImportContact contact in contacts) {
      final String normalized = normalizeEmailAddress(contact.address);
      if (normalized.isEmpty || !normalized.isValidEmailAddress) {
        invalid += _nextIndex;
        continue;
      }
      if (!seen.add(normalized)) {
        duplicates += _nextIndex;
        continue;
      }
      try {
        await _emailService.ensureChatForAddress(
          address: normalized,
          displayName: contact.displayName,
        );
        imported += _nextIndex;
      } catch (_) {
        failed += _nextIndex;
      }
    }

    if (imported > _startIndex) {
      await _emailService.syncContactsFromCore();
    }

    if (imported == _startIndex && failed > _startIndex) {
      throw const EmailContactImportException(
        EmailContactImportFailureReason.importFailed,
      );
    }

    return EmailContactImportSummary(
      total: contacts.length,
      imported: imported,
      duplicates: duplicates,
      invalid: invalid,
      failed: failed,
    );
  }
}

class _CsvHeaderMap {
  const _CsvHeaderMap({
    required this.emailIndices,
    this.nameIndex,
    this.firstNameIndex,
    this.middleNameIndex,
    this.lastNameIndex,
    this.nicknameIndex,
  });

  final List<int> emailIndices;
  final int? nameIndex;
  final int? firstNameIndex;
  final int? middleNameIndex;
  final int? lastNameIndex;
  final int? nicknameIndex;

  factory _CsvHeaderMap.fromHeaders(List<String> headers) {
    final List<String> normalized =
        headers.map((header) => _canonicalHeaderKey(header)).toList();
    final List<int> emailIndices = <int>[];
    for (int index = _startIndex;
        index < normalized.length;
        index += _nextIndex) {
      if (_isEmailHeader(normalized[index])) {
        emailIndices.add(index);
      }
    }
    return _CsvHeaderMap(
      emailIndices: emailIndices,
      nameIndex: _firstIndexForKeys(normalized, _fullNameHeaderKeys),
      firstNameIndex: _firstIndexForKeys(normalized, _firstNameHeaderKeys),
      middleNameIndex: _firstIndexForKeys(normalized, _middleNameHeaderKeys),
      lastNameIndex: _firstIndexForKeys(normalized, _lastNameHeaderKeys),
      nicknameIndex: _firstIndexForKeys(normalized, _nicknameHeaderKeys),
    );
  }

  String? displayNameFor(List<String> row) {
    final String? direct = _fieldAt(row, nameIndex);
    if (direct != null) {
      return direct;
    }
    final String? composed = _joinNonEmpty(<String?>[
      _fieldAt(row, firstNameIndex),
      _fieldAt(row, middleNameIndex),
      _fieldAt(row, lastNameIndex),
    ]);
    if (composed != null) {
      return composed;
    }
    return _fieldAt(row, nicknameIndex);
  }
}

class _CsvParser {
  const _CsvParser({required this.delimiter});

  final String delimiter;

  List<List<String>> parse(String content) {
    if (content.isEmpty) {
      return const <List<String>>[];
    }
    final List<List<String>> rows = <List<String>>[];
    List<String> row = <String>[];
    final StringBuffer field = StringBuffer();
    bool inQuotes = false;
    int index = _startIndex;

    void flushField() {
      row.add(field.toString());
      field.clear();
    }

    void flushRow() {
      if (_rowHasValue(row)) {
        rows.add(row);
      }
      row = <String>[];
    }

    while (index < content.length) {
      final String char = content[index];
      if (char == _csvQuote) {
        final int next = index + _nextIndex;
        final bool hasNext = next < content.length;
        final bool escaped = hasNext && content[next] == _csvQuote;
        if (inQuotes && escaped) {
          field.write(_csvQuote);
          index = next;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes && char == delimiter) {
        flushField();
      } else if (!inQuotes && _isLineBreak(char)) {
        flushField();
        flushRow();
        final int next = index + _nextIndex;
        if (char == _carriageReturn &&
            next < content.length &&
            content[next] == _lineFeed) {
          index = next;
        }
      } else {
        field.write(char);
      }
      index += _nextIndex;
    }

    if (field.length > _startIndex || row.isNotEmpty) {
      flushField();
      flushRow();
    }

    return rows;
  }

  bool _isLineBreak(String char) {
    return char == _lineFeed || char == _carriageReturn;
  }

  bool _rowHasValue(List<String> row) {
    for (final String value in row) {
      if (value.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }
}

class _HeaderlessRowParseResult {
  const _HeaderlessRowParseResult({
    required this.emails,
    this.displayName,
  });

  final List<String> emails;
  final String? displayName;
}

String _canonicalHeaderKey(String value) {
  final String normalized = value.trim().toLowerCase();
  return normalized.replaceAll(_headerSanitizer, _emptyValue);
}

int? _firstIndexForKeys(List<String> headers, Set<String> keys) {
  for (int index = _startIndex; index < headers.length; index += _nextIndex) {
    if (keys.contains(headers[index])) {
      return index;
    }
  }
  return null;
}

bool _isEmailHeader(String header) {
  if (header.isEmpty) {
    return false;
  }
  if (!header.contains(_emailHeaderToken)) {
    return false;
  }
  return !header.contains(_emailHeaderTypeToken);
}

String? _joinNonEmpty(List<String?> parts) {
  final List<String> filtered = <String>[];
  for (final String? part in parts) {
    final String? value = part?.trim();
    if (value != null && value.isNotEmpty) {
      filtered.add(value);
    }
  }
  if (filtered.isEmpty) {
    return null;
  }
  return filtered.join(_spaceValue);
}

String? _fieldAt(List<String> row, int? index) {
  if (index == null || index < _startIndex || index >= row.length) {
    return null;
  }
  final String value = row[index].trim();
  return value.isEmpty ? null : value;
}
