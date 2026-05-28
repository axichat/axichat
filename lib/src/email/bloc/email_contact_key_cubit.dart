// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/email/service/email_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'email_contact_key_state.dart';

class EmailContactKeyCubit extends Cubit<EmailContactKeyState> {
  EmailContactKeyCubit({required EmailService emailService})
    : _emailService = emailService,
      super(const EmailContactKeyIdle());

  final EmailService _emailService;
  String? _address;
  String? _displayName;
  String? _pendingImportPath;
  EmailOpenPgpKeyMetadata? _pendingMetadata;

  Future<void> load({
    required String address,
    required String displayName,
  }) async {
    _address = address;
    _displayName = displayName;
    await _emitIdle();
  }

  Future<void> inspectPublicKey(File file) async {
    final address = _address;
    if (address == null) {
      emit(
        const EmailContactKeyFailure(
          EmailContactKeyFailureReason.noActiveAccount,
        ),
      );
      return;
    }
    emit(const EmailContactKeyInspecting());
    try {
      final metadata = await _emailService.inspectContactPublicKey(
        address: address,
        source: file,
      );
      _pendingImportPath = file.path;
      _pendingMetadata = metadata;
      if (metadata.requiresIdentityConfirmation) {
        emit(EmailContactKeyConfirmationRequired(metadata));
        return;
      }
      await confirmImport();
    } on EmailContactKeyException catch (error) {
      _clearPendingImport();
      emit(EmailContactKeyFailure(_failureReasonFor(error)));
      await _emitIdle();
    }
  }

  Future<void> confirmImport() async {
    final address = _address;
    final importPath = _pendingImportPath;
    final metadata = _pendingMetadata;
    if (address == null || importPath == null || metadata == null) {
      emit(
        const EmailContactKeyFailure(EmailContactKeyFailureReason.importFailed),
      );
      await _emitIdle();
      return;
    }
    emit(const EmailContactKeyImporting());
    try {
      await _emailService.importTrustedContactPublicKey(
        address: address,
        displayName: _displayName ?? address,
        source: File(importPath),
        identityBinding: metadata.defaultIdentityBinding,
        expectedFingerprint: metadata.fingerprint,
      );
      _clearPendingImport();
      emit(const EmailContactKeySuccess(EmailContactKeySuccessKind.imported));
      await _emitIdle();
    } on EmailContactKeyException catch (error) {
      _clearPendingImport();
      emit(EmailContactKeyFailure(_failureReasonFor(error)));
      await _emitIdle();
    }
  }

  Future<void> cancelImport() async {
    _clearPendingImport();
    await _emitIdle();
  }

  Future<void> remove() async {
    final address = _address;
    if (address == null) {
      emit(
        const EmailContactKeyFailure(
          EmailContactKeyFailureReason.noActiveAccount,
        ),
      );
      return;
    }
    emit(const EmailContactKeyRemoving());
    try {
      await _emailService.removeTrustedContactPublicKey(address);
      emit(const EmailContactKeySuccess(EmailContactKeySuccessKind.removed));
      await _emitIdle();
    } on EmailContactKeyException catch (error) {
      emit(EmailContactKeyFailure(_failureReasonFor(error)));
      await _emitIdle();
    }
  }

  Future<void> _emitIdle() async {
    final address = _address;
    if (address == null) {
      emit(const EmailContactKeyIdle());
      return;
    }
    try {
      final account = await _emailService.activeEncryptionAccountInfo();
      if (account == null) {
        emit(const EmailContactKeyIdle());
        return;
      }
      final key = await _emailService.trustedContactKeyForAddress(address);
      emit(
        EmailContactKeyIdle(
          account: account,
          trustedKey: key,
          normalizedAddress: key?.normalizedAddress,
        ),
      );
    } on EmailEncryptionNoActiveAccountException {
      emit(const EmailContactKeyIdle());
    }
  }

  void _clearPendingImport() {
    _pendingImportPath = null;
    _pendingMetadata = null;
  }

  EmailContactKeyFailureReason _failureReasonFor(
    EmailContactKeyException error,
  ) => switch (error) {
    EmailContactKeyNoActiveAccountException() =>
      EmailContactKeyFailureReason.noActiveAccount,
    EmailContactKeyUnsupportedFormatException() =>
      EmailContactKeyFailureReason.unsupportedFormat,
    EmailContactKeyImportFailedException() =>
      EmailContactKeyFailureReason.importFailed,
    EmailContactKeyRemoveFailedException() =>
      EmailContactKeyFailureReason.removeFailed,
  };
}
