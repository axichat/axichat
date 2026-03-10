// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:axichat/src/common/transport.dart';

enum ContactExportFormat { csv, vcard }

extension ContactExportFormatMetadata on ContactExportFormat {
  bool get isCsv => this == ContactExportFormat.csv;

  bool get isVcard => this == ContactExportFormat.vcard;

  String get fileExtension => switch (this) {
    ContactExportFormat.csv => 'csv',
    ContactExportFormat.vcard => 'vcf',
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

class ContactExportLabels {
  const ContactExportLabels({
    required this.csvHeaderName,
    required this.csvHeaderAddress,
    required this.fallbackLabel,
  });

  final String csvHeaderName;
  final String csvHeaderAddress;
  final String fallbackLabel;
}

class ContactExporter {
  const ContactExporter._();

  static Future<File> exportContacts({
    required List<ContactExportEntry> contacts,
    required ContactExportFormat format,
    required String fileLabel,
    required ContactExportLabels labels,
  }) async {
    final String exportBody = format.isCsv
        ? _buildCsv(contacts, labels)
        : _buildVcard(contacts);
    final String sanitizedLabel = _sanitizeLabel(
      fileLabel,
      labels.fallbackLabel,
    );
    return _writeExportFile(exportBody, sanitizedLabel, format.fileExtension);
  }
}

String _buildCsv(
  List<ContactExportEntry> contacts,
  ContactExportLabels labels,
) {
  final String csvHeaderLine =
      '${_escapeCsvField(labels.csvHeaderName)},${_escapeCsvField(labels.csvHeaderAddress)}';
  final StringBuffer buffer = StringBuffer()..writeln(csvHeaderLine);
  for (final contact in contacts) {
    final String name = contact.displayName?.trim() ?? '';
    final String address = contact.address.trim();
    buffer
      ..write(_escapeCsvField(name))
      ..write(',')
      ..writeln(_escapeCsvField(address));
  }
  return buffer.toString().trim();
}

String _buildVcard(List<ContactExportEntry> contacts) {
  final StringBuffer buffer = StringBuffer();
  for (final contact in contacts) {
    final String address = contact.address.trim();
    final String name = (contact.displayName?.trim() ?? '').isNotEmpty
        ? contact.displayName!.trim()
        : address;
    final String escapedName = _escapeVcardValue(name);
    final String escapedAddress = _escapeVcardValue(address);
    final String addressLine = contact.transport.isXmpp
        ? 'IMPP:xmpp:$escapedAddress'
        : 'EMAIL:$escapedAddress';
    buffer
      ..writeln('BEGIN:VCARD')
      ..writeln('VERSION:3.0')
      ..writeln('FN:$escapedName')
      ..writeln(addressLine)
      ..writeln('END:VCARD')
      ..writeln();
  }
  return buffer.toString().trim();
}

String _escapeCsvField(String value) {
  final bool needsQuotes =
      value.contains(',') || value.contains('"') || value.contains('\n');
  final String escaped = value.replaceAll('"', '""');
  if (!needsQuotes) {
    return escaped;
  }
  return '"$escaped"';
}

String _escapeVcardValue(String value) {
  return value
      .replaceAll('\\', '\\\\')
      .replaceAll('\r', '\\n')
      .replaceAll('\n', '\\n')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,');
}

String _sanitizeLabel(String input, String fallbackLabel) {
  final String trimmed = input.trim().toLowerCase();
  final RegExp pattern = RegExp(r'[^a-z0-9_-]');
  final String sanitized = trimmed.replaceAll(pattern, '_');
  if (sanitized.isEmpty) {
    return fallbackLabel;
  }
  return sanitized;
}

Future<File> _writeExportFile(
  String text,
  String label,
  String extension,
) async {
  final Directory tempDir = await appOwnedTemporaryDirectory(
    contactExportTempDirectoryName,
  );
  if (!await tempDir.exists()) {
    await tempDir.create(recursive: true);
  }
  final int timestamp = DateTime.now().millisecondsSinceEpoch;
  final String fileName = '$label-$timestamp.$extension';
  final File file = File('${tempDir.path}/$fileName');
  await file.writeAsString(text);
  return file;
}
