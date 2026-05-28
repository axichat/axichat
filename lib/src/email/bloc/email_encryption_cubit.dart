// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'email_encryption_state.dart';

class EmailEncryptionCubit extends Cubit<EmailEncryptionState> {
  EmailEncryptionCubit({required EmailService emailService})
    : _emailService = emailService,
      super(const EmailEncryptionIdle());

  final EmailService _emailService;
  CancelableOperation<EmailEncryptionKeyExport>? _exportOperation;
  Uint8List? _pendingExportBytes;
  String? _pendingPrivateKeyPath;
  EmailOpenPgpKeyMetadata? _pendingPrivateKeyMetadata;

  Future<void> refreshActiveAccount() async {
    final account = await _emailService.activeEncryptionAccountInfo();
    emit(EmailEncryptionIdle(account: account));
  }

  Future<void> importPrivateKey(File file) async {
    emit(const EmailEncryptionImportRunning());
    try {
      final metadata = await _emailService.inspectEmailEncryptionPrivateKey(
        file,
      );
      _pendingPrivateKeyPath = file.path;
      _pendingPrivateKeyMetadata = metadata;
      if (metadata.requiresIdentityConfirmation) {
        emit(
          EmailEncryptionSelfKeyConfirmationRequired(
            path: file.path,
            metadata: metadata,
          ),
        );
        return;
      }
      await confirmPrivateKeyImport();
    } on EmailEncryptionKeyException catch (error) {
      _clearPendingPrivateKeyImport();
      emit(EmailEncryptionFailure(_failureReasonFor(error)));
    }
  }

  Future<void> confirmPrivateKeyImport() async {
    final path = _pendingPrivateKeyPath;
    final metadata = _pendingPrivateKeyMetadata;
    if (path == null || metadata == null) {
      emit(
        const EmailEncryptionFailure(EmailEncryptionFailureReason.importFailed),
      );
      return;
    }
    emit(const EmailEncryptionImportRunning());
    try {
      final account = await _emailService.importEmailEncryptionPrivateKey(
        File(path),
        expectedFingerprint: metadata.fingerprint,
        allowIdentityMismatch: metadata.requiresIdentityConfirmation,
      );
      _clearPendingPrivateKeyImport();
      emit(EmailEncryptionActivationReady(account.normalizedAddress));
    } on EmailEncryptionKeyException catch (error) {
      _clearPendingPrivateKeyImport();
      emit(EmailEncryptionFailure(_failureReasonFor(error)));
    }
  }

  Future<void> cancelPrivateKeyImport() async {
    _clearPendingPrivateKeyImport();
    await refreshActiveAccount();
  }

  Future<void> activateExistingKey() async {
    final account = await _emailService.activeEncryptionAccountInfo();
    if (account == null) {
      emit(
        const EmailEncryptionFailure(
          EmailEncryptionFailureReason.noActiveAccount,
        ),
      );
      return;
    }
    if (!account.hasSelfKey) {
      emit(
        const EmailEncryptionFailure(
          EmailEncryptionFailureReason.noPrivateKeyFound,
        ),
      );
      return;
    }
    emit(EmailEncryptionActivationReady(account.normalizedAddress));
  }

  Future<void> createExport() async {
    await _cancelPendingExport();
    _clearPendingExportBytes();
    emit(const EmailEncryptionExportRunning());
    final operation = CancelableOperation<EmailEncryptionKeyExport>.fromFuture(
      _emailService.createEmailEncryptionKeyExport(),
    );
    _exportOperation = operation;
    try {
      final export = await operation.valueOrCancellation();
      if (_exportOperation != operation) {
        return;
      }
      _exportOperation = null;
      if (export == null) {
        return;
      }
      _pendingExportBytes = export.archiveBytes;
      emit(
        EmailEncryptionExportReady(normalizedAddress: export.normalizedAddress),
      );
    } on EmailEncryptionKeyException catch (error) {
      if (_exportOperation != operation) {
        return;
      }
      _exportOperation = null;
      emit(EmailEncryptionFailure(_failureReasonFor(error)));
    } finally {
      if (_exportOperation == operation) {
        _exportOperation = null;
      }
    }
  }

  Future<void> saveExport(String destinationPath) async {
    final current = state;
    final exportBytes = _pendingExportBytes;
    if (current is! EmailEncryptionExportReady || exportBytes == null) {
      emit(
        const EmailEncryptionFailure(EmailEncryptionFailureReason.saveFailed),
      );
      return;
    }
    emit(EmailEncryptionSaveRunning(current.normalizedAddress));
    try {
      await _emailService.saveEmailEncryptionKeyExport(
        archiveBytes: exportBytes,
        destinationPath: destinationPath,
        normalizedAddress: current.normalizedAddress,
      );
      _clearPendingExportBytes();
      emit(EmailEncryptionActivationReady(current.normalizedAddress));
    } on EmailEncryptionKeyException catch (error) {
      _clearPendingExportBytes();
      emit(EmailEncryptionFailure(_failureReasonFor(error)));
    }
  }

  Future<void> completePlatformSavedExport(String platformResultPath) async {
    final current = state;
    final exportBytes = _pendingExportBytes;
    if (current is! EmailEncryptionExportReady || exportBytes == null) {
      emit(
        const EmailEncryptionFailure(EmailEncryptionFailureReason.saveFailed),
      );
      return;
    }
    emit(EmailEncryptionSaveRunning(current.normalizedAddress));
    try {
      await _emailService.completeEmailEncryptionKeyExportAfterPlatformSave(
        archiveBytes: exportBytes,
        platformResultPath: platformResultPath,
        normalizedAddress: current.normalizedAddress,
      );
      _clearPendingExportBytes();
      emit(EmailEncryptionActivationReady(current.normalizedAddress));
    } on EmailEncryptionKeyException catch (error) {
      _clearPendingExportBytes();
      emit(EmailEncryptionFailure(_failureReasonFor(error)));
    }
  }

  Future<Uint8List?> exportBytesForSave(
    EmailEncryptionExportReady export,
  ) async {
    final current = state;
    final exportBytes = _pendingExportBytes;
    if (current != export || exportBytes == null) {
      _clearPendingExportBytes();
      emit(
        const EmailEncryptionFailure(EmailEncryptionFailureReason.saveFailed),
      );
      return null;
    }
    return exportBytes;
  }

  Future<void> failExportSave() async {
    _clearPendingExportBytes();
    emit(const EmailEncryptionFailure(EmailEncryptionFailureReason.saveFailed));
  }

  Future<void> cancelExport() async {
    _clearPendingExportBytes();
    await refreshActiveAccount();
  }

  void disable(String normalizedAddress) {
    emit(EmailEncryptionDisableReady(normalizedAddress));
  }

  @override
  Future<void> close() async {
    await _cancelPendingExport();
    _clearPendingExportBytes();
    return super.close();
  }

  Future<void> _cancelPendingExport() async {
    final operation = _exportOperation;
    _exportOperation = null;
    if (operation == null) {
      return;
    }
    await operation.cancel();
    await _emailService.cancelEmailEncryptionKeyExport();
  }

  void _clearPendingExportBytes() {
    final bytes = _pendingExportBytes;
    if (bytes == null) {
      return;
    }
    bytes.fillRange(0, bytes.length, 0);
    _pendingExportBytes = null;
  }

  void _clearPendingPrivateKeyImport() {
    _pendingPrivateKeyPath = null;
    _pendingPrivateKeyMetadata = null;
  }

  EmailEncryptionFailureReason _failureReasonFor(
    EmailEncryptionKeyException error,
  ) => switch (error) {
    EmailEncryptionNoActiveAccountException() =>
      EmailEncryptionFailureReason.noActiveAccount,
    EmailEncryptionUnsupportedKeyFormatException() =>
      EmailEncryptionFailureReason.unsupportedKeyFormat,
    EmailEncryptionNoPrivateKeyFoundException() =>
      EmailEncryptionFailureReason.noPrivateKeyFound,
    EmailEncryptionAmbiguousKeyArchiveException() =>
      EmailEncryptionFailureReason.ambiguousKeyArchive,
    EmailEncryptionImportFailedException() =>
      EmailEncryptionFailureReason.importFailed,
    EmailEncryptionExportFailedException() =>
      EmailEncryptionFailureReason.exportFailed,
    EmailEncryptionSaveFailedException() =>
      EmailEncryptionFailureReason.saveFailed,
  };
}
