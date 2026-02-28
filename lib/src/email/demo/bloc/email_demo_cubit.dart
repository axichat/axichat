// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/storage/credential_store.dart';

part 'email_demo_state.dart';
part 'email_demo_cubit.freezed.dart';

class EmailDemoCubit extends Cubit<EmailDemoState> {
  EmailDemoCubit({
    required EmailService emailService,
    required CredentialStore credentialStore,
    Logger? log,
  }) : _emailService = emailService,
       _credentialStore = credentialStore,
       _log = log ?? Logger('EmailDemoCubit'),
       super(
         const EmailDemoState(
           status: EmailDemoStatus.idle,
           account: null,
           failure: null,
           detail: null,
         ),
       );

  final EmailService _emailService;
  final CredentialStore _credentialStore;
  final Logger _log;

  Future<void> loadAccount() async {
    final jidKey = CredentialStore.registerKey('jid');
    final jid = await _credentialStore.read(key: jidKey);
    if (jid == null) {
      emit(
        state.copyWith(
          status: EmailDemoStatus.loginToProvision,
          account: null,
          failure: null,
          detail: null,
        ),
      );
      return;
    }
    final account = await _emailService.currentAccount(jid);
    emit(
      state.copyWith(
        status: account == null
            ? EmailDemoStatus.notProvisioned
            : EmailDemoStatus.ready,
        account: account,
        failure: null,
        detail: null,
      ),
    );
  }

  Future<void> provision() async {
    emit(
      state.copyWith(
        status: EmailDemoStatus.provisioning,
        failure: null,
        detail: null,
      ),
    );
    if (kEnableDemoChats) {
      emit(
        state.copyWith(
          status: EmailDemoStatus.provisioned,
          account: const EmailAccount(address: kDemoSelfJid, password: 'demo'),
          failure: null,
          detail: null,
        ),
      );
      return;
    }
    try {
      final jidKey = CredentialStore.registerKey('jid');
      final jid = await _credentialStore.read(key: jidKey);
      if (jid == null) {
        emit(
          state.copyWith(
            status: EmailDemoStatus.provisionFailed,
            failure: EmailDemoFailure.missingProfile,
            detail: null,
          ),
        );
        return;
      }
      final prefixKey = CredentialStore.registerKey('${jid}_database_prefix');
      final databasePrefix = await _credentialStore.read(key: prefixKey);
      if (databasePrefix == null) {
        emit(
          state.copyWith(
            status: EmailDemoStatus.provisionFailed,
            failure: EmailDemoFailure.missingPrefix,
            detail: null,
          ),
        );
        return;
      }
      final passphraseKey = CredentialStore.registerKey(
        '${databasePrefix}_database_passphrase',
      );
      final passphrase = await _credentialStore.read(key: passphraseKey);
      if (passphrase == null) {
        emit(
          state.copyWith(
            status: EmailDemoStatus.provisionFailed,
            failure: EmailDemoFailure.missingPassphrase,
            detail: null,
          ),
        );
        return;
      }
      final account = await _emailService.ensureProvisioned(
        displayName: addressLocalPart(jid) ?? jid,
        databasePrefix: databasePrefix,
        databasePassphrase: passphrase,
        jid: jid,
      );
      emit(
        state.copyWith(
          status: EmailDemoStatus.provisioned,
          account: account,
          failure: null,
          detail: null,
        ),
      );
    } on EmailProvisioningException catch (error, stackTrace) {
      const String logMessage = 'Provisioning failed';
      _log.warning(logMessage, error, stackTrace);
      emit(
        state.copyWith(
          status: EmailDemoStatus.provisionFailed,
          failure: EmailDemoFailure.unexpected,
          detail: null,
        ),
      );
    }
  }

  Future<void> sendDemoMessage({
    required EmailAccount? account,
    required FanOutTarget? demoTarget,
    required String body,
    required String displayName,
  }) async {
    if (!kEnableDemoChats && account == null) {
      emit(
        state.copyWith(
          status: EmailDemoStatus.provisionFirst,
          failure: null,
          detail: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: EmailDemoStatus.sending,
        failure: null,
        detail: null,
      ),
    );
    try {
      if (kEnableDemoChats) {
        if (demoTarget == null) {
          emit(
            state.copyWith(
              status: EmailDemoStatus.sendFailed,
              failure: EmailDemoFailure.unexpected,
              detail: null,
            ),
          );
          return;
        }
        final report = await _emailService.fanOutSend(
          targets: [demoTarget],
          body: body,
        );
        if (report.hasFailures) {
          emit(
            state.copyWith(
              status: EmailDemoStatus.sendFailed,
              failure: EmailDemoFailure.unexpected,
              detail: null,
            ),
          );
          return;
        }
        final detail = report.statuses.isNotEmpty
            ? report.statuses.first.deltaMsgId?.toString() ?? report.shareId
            : report.shareId;
        emit(
          state.copyWith(
            status: EmailDemoStatus.sent,
            detail: detail,
            failure: null,
          ),
        );
        return;
      }
      final msgId = await _emailService.sendToAddress(
        address: account!.address,
        displayName: displayName,
        body: body,
      );
      emit(
        state.copyWith(
          status: EmailDemoStatus.sent,
          detail: '$msgId',
          failure: null,
        ),
      );
    } on FanOutValidationException catch (error, stackTrace) {
      const String logMessage = 'Failed to send demo message';
      _log.warning(logMessage, error, stackTrace);
      emit(
        state.copyWith(
          status: EmailDemoStatus.sendFailed,
          failure: EmailDemoFailure.unexpected,
          detail: null,
        ),
      );
    } on DeltaChatException catch (error, stackTrace) {
      const String logMessage = 'Failed to send demo message';
      _log.warning(logMessage, error, stackTrace);
      emit(
        state.copyWith(
          status: EmailDemoStatus.sendFailed,
          failure: EmailDemoFailure.unexpected,
          detail: null,
        ),
      );
    }
  }
}
