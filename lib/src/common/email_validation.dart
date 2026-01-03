// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

const String _emailValidationPattern = r'^[^\s@]+@[^\s@]+\.[^\s@]+$';
final RegExp _emailValidationRegex = RegExp(_emailValidationPattern);

extension EmailAddressValidation on String {
  bool get isValidEmailAddress {
    final normalized = trim();
    if (normalized.isEmpty) {
      return false;
    }
    return _emailValidationRegex.hasMatch(normalized);
  }
}
