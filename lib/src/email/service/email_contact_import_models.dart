// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:equatable/equatable.dart';

const String _csvExtension = 'csv';
const String _vcardExtension = 'vcf';
const String _vcardAlternateExtension = 'vcard';
const int _emptyCount = 0;
const List<String> _csvExtensions = <String>[_csvExtension];
const List<String> _vcardExtensions = <String>[
  _vcardExtension,
  _vcardAlternateExtension,
];

enum EmailContactImportFormat {
  gmail,
  outlook,
  yahoo,
  genericCsv,
  vcard,
}

extension EmailContactImportFormatMetadata on EmailContactImportFormat {
  bool get isVcard => this == EmailContactImportFormat.vcard;

  bool get isCsv => !isVcard;

  List<String> get allowedExtensions =>
      isVcard ? _vcardExtensions : _csvExtensions;
}

enum EmailContactImportFailureReason {
  noEmailAccount,
  emptyFile,
  readFailure,
  unsupportedFileType,
  noContacts,
  importFailed,
}

class EmailContactImportContact extends Equatable {
  const EmailContactImportContact({
    required this.address,
    this.displayName,
  });

  final String address;
  final String? displayName;

  @override
  List<Object?> get props => [address, displayName];
}

class EmailContactImportSummary extends Equatable {
  const EmailContactImportSummary({
    required this.total,
    required this.imported,
    required this.duplicates,
    required this.invalid,
    required this.failed,
  });

  final int total;
  final int imported;
  final int duplicates;
  final int invalid;
  final int failed;

  int get skipped => duplicates + invalid + failed;

  bool get hasFailures => failed > _emptyCount;

  bool get hasImported => imported > _emptyCount;

  @override
  List<Object?> get props => [
        total,
        imported,
        duplicates,
        invalid,
        failed,
      ];
}
