// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/common/transport.dart';
import 'package:path_provider/path_provider.dart';

const String _csvExtension = 'csv';
const String _vcardExtension = 'vcf';
const String _fileNameSeparator = '-';
const String _fileNameExtensionSeparator = '.';
const String _csvDelimiter = ',';
const String _csvQuote = '"';
const String _csvHeaderName = 'Name';
const String _csvHeaderAddress = 'Address';
const String _csvLineBreak = '\n';
const String _vcardLineBreak = '\n';
const String _vcardBegin = 'BEGIN:VCARD';
const String _vcardEnd = 'END:VCARD';
const String _vcardVersion = 'VERSION:3.0';
const String _vcardFullNamePrefix = 'FN:';
const String _vcardEmailPrefix = 'EMAIL:';
const String _vcardImppPrefix = 'IMPP:xmpp:';
const String _vcardEscapeBackslash = '\\\\';
const String _vcardEscapeComma = '\\,';
const String _vcardEscapeSemicolon = '\\;';
const String _vcardEscapeNewline = '\\n';
const String _vcardBackslash = '\\';
const String _vcardComma = ',';
const String _vcardSemicolon = ';';
const String _vcardNewline = '\n';
const String _vcardNewlineCarriage = '\r';
const String _csvHeaderLine = '$_csvHeaderName$_csvDelimiter$_csvHeaderAddress';
const String _emptyValue = '';
const String _labelFallback = 'contacts';
const String _fileSafePattern = r'[^a-z0-9_-]';

enum ContactExportFormat { csv, vcard }

extension ContactExportFormatMetadata on ContactExportFormat {
  bool get isCsv => this == ContactExportFormat.csv;

  bool get isVcard => this == ContactExportFormat.vcard;

  String get fileExtension => switch (this) {
        ContactExportFormat.csv => _csvExtension,
        ContactExportFormat.vcard => _vcardExtension,
      };
}

class ContactExportEntry {
  const ContactExportEntry({
    required this.address,
    required this.transport,
    this.displayName,
  });

  final String address;
  final MessageTransport transport;
  final String? displayName;
}

class ContactExporter {
  const ContactExporter._();

  static Future<File> exportContacts({
    required List<ContactExportEntry> contacts,
    required ContactExportFormat format,
    required String fileLabel,
  }) async {
    final String exportBody =
        format.isCsv ? _buildCsv(contacts) : _buildVcard(contacts);
    final String sanitizedLabel = _sanitizeLabel(fileLabel);
    return _writeExportFile(
      exportBody,
      sanitizedLabel,
      format.fileExtension,
    );
  }
}

String _buildCsv(List<ContactExportEntry> contacts) {
  final StringBuffer buffer = StringBuffer()..writeln(_csvHeaderLine);
  for (final contact in contacts) {
    final String name = contact.displayName?.trim() ?? _emptyValue;
    final String address = contact.address.trim();
    buffer
      ..write(_escapeCsvField(name))
      ..write(_csvDelimiter)
      ..writeln(_escapeCsvField(address));
  }
  return buffer.toString().trim();
}

String _buildVcard(List<ContactExportEntry> contacts) {
  final StringBuffer buffer = StringBuffer();
  for (final contact in contacts) {
    final String address = contact.address.trim();
    final String name = (contact.displayName?.trim() ?? _emptyValue).isNotEmpty
        ? contact.displayName!.trim()
        : address;
    final String escapedName = _escapeVcardValue(name);
    final String escapedAddress = _escapeVcardValue(address);
    final String addressLine = contact.transport.isXmpp
        ? '$_vcardImppPrefix$escapedAddress'
        : '$_vcardEmailPrefix$escapedAddress';
    buffer
      ..writeln(_vcardBegin)
      ..writeln(_vcardVersion)
      ..writeln('$_vcardFullNamePrefix$escapedName')
      ..writeln(addressLine)
      ..writeln(_vcardEnd)
      ..writeln(_vcardLineBreak);
  }
  return buffer.toString().trim();
}

String _escapeCsvField(String value) {
  final bool needsQuotes = value.contains(_csvDelimiter) ||
      value.contains(_csvQuote) ||
      value.contains(_csvLineBreak);
  final String escaped = value.replaceAll(_csvQuote, '$_csvQuote$_csvQuote');
  if (!needsQuotes) {
    return escaped;
  }
  return '$_csvQuote$escaped$_csvQuote';
}

String _escapeVcardValue(String value) {
  return value
      .replaceAll(_vcardBackslash, _vcardEscapeBackslash)
      .replaceAll(_vcardNewlineCarriage, _vcardEscapeNewline)
      .replaceAll(_vcardNewline, _vcardEscapeNewline)
      .replaceAll(_vcardSemicolon, _vcardEscapeSemicolon)
      .replaceAll(_vcardComma, _vcardEscapeComma);
}

String _sanitizeLabel(String input) {
  final String trimmed = input.trim().toLowerCase();
  final RegExp pattern = RegExp(_fileSafePattern);
  final String sanitized = trimmed.replaceAll(pattern, '_');
  if (sanitized.isEmpty) {
    return _labelFallback;
  }
  return sanitized;
}

Future<File> _writeExportFile(
  String text,
  String label,
  String extension,
) async {
  final Directory tempDir = await getTemporaryDirectory();
  final int timestamp = DateTime.now().millisecondsSinceEpoch;
  final String fileName =
      '$label$_fileNameSeparator$timestamp$_fileNameExtensionSeparator$extension';
  final File file = File('${tempDir.path}/$fileName');
  await file.writeAsString(text);
  return file;
}
