// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/email/service/email_contact_import_models.dart';
import 'package:axichat/src/email/service/email_contact_import_service.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'email_contact_import_state.dart';

class EmailContactImportCubit extends Cubit<EmailContactImportState> {
  EmailContactImportCubit({required EmailService emailService})
      : _importService = EmailContactImportService(emailService: emailService),
        super(const EmailContactImportInitial());

  final EmailContactImportService _importService;

  Future<void> importContacts({
    required File file,
    required EmailContactImportFormat format,
  }) async {
    emit(const EmailContactImportInProgress());
    try {
      final EmailContactImportSummary summary =
          await _importService.importContacts(
        file: file,
        format: format,
      );
      emit(EmailContactImportSuccess(summary));
    } on EmailContactImportException catch (error) {
      emit(EmailContactImportFailure(error.reason));
    } catch (_) {
      emit(
        const EmailContactImportFailure(
          EmailContactImportFailureReason.importFailed,
        ),
      );
    }
  }

  void reset() => emit(const EmailContactImportInitial());
}
