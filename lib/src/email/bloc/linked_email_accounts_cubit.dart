import 'dart:async';

import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';

part 'linked_email_accounts_state.dart';

const int _singleAccountLimit = 1;
const String _loadFailureLogMessage = 'Failed to load linked email accounts';
const String _linkFailureLogMessage = 'Failed to link email account';
const String _provisionFailureLogMessage =
    'Failed to provision linked email account';
const String _unlinkFailureLogMessage = 'Failed to unlink email account';
const String _setPrimaryFailureLogMessage =
    'Failed to set default email account';
const String _updatePasswordFailureLogMessage =
    'Failed to update linked email password';

class LinkedEmailAccountsCubit extends Cubit<LinkedEmailAccountsState> {
  LinkedEmailAccountsCubit({
    required EmailService emailService,
    required String jid,
  })  : _emailService = emailService,
        _jid = jid,
        _log = Logger('LinkedEmailAccountsCubit'),
        super(
          LinkedEmailAccountsState(
            supportsMultipleAccounts:
                emailService.supportsMultipleLinkedAccounts,
            maxAccounts: _maxAccountsFor(emailService),
            extraAccountLimit: emailService.linkedAccountLimit,
          ),
        ) {
    unawaited(load());
  }

  final EmailService _emailService;
  final String _jid;
  final Logger _log;

  static int _maxAccountsFor(EmailService emailService) {
    final bool supportsMultiple = emailService.supportsMultipleLinkedAccounts;
    if (!supportsMultiple) {
      return _singleAccountLimit;
    }
    return emailService.linkedAccountTotalLimit;
  }

  Future<void> load() async {
    emit(state.copyWith(status: RequestStatus.loading));
    try {
      final List<EmailAccountProfile> accounts =
          await _emailService.linkedAccounts(_jid);
      emit(
        state.copyWith(
          status: RequestStatus.success,
          accounts: accounts,
        ),
      );
    } on Exception catch (error, stackTrace) {
      final String errorType = error.runtimeType.toString();
      _log.warning('$_loadFailureLogMessage ($errorType)', null, stackTrace);
      emit(state.copyWith(status: RequestStatus.failure));
    }
  }

  Future<void> linkAccount({
    required String address,
    required String password,
    bool setPrimary = false,
  }) async {
    if (!state.supportsMultipleAccounts && state.accounts.isNotEmpty) {
      emit(
        state.copyWith(
          actionStatus: RequestStatus.failure,
          action: LinkedEmailAccountsAction.link,
          actionFailure: const LinkedEmailAccountsActionFailure(
            type: LinkedEmailAccountsFailureType.unsupported,
          ),
        ),
      );
      return;
    }
    if (!state.canAddAccount) {
      emit(
        state.copyWith(
          actionStatus: RequestStatus.failure,
          action: LinkedEmailAccountsAction.link,
          actionFailure: LinkedEmailAccountsActionFailure(
            type: LinkedEmailAccountsFailureType.limitReached,
            limit: state.extraAccountLimit,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        actionStatus: RequestStatus.loading,
        action: LinkedEmailAccountsAction.link,
        clearActionFailure: true,
        clearActionAccountId: true,
      ),
    );
    try {
      final bool shouldSetPrimary = setPrimary;
      final EmailAccountProfile? previousPrimary = shouldSetPrimary
          ? await _emailService.primaryLinkedAccount(_jid)
          : null;
      final EmailAccountProfile profile = await _emailService.linkAccount(
        jid: _jid,
        address: address,
        password: password,
        setPrimary: setPrimary,
      );
      try {
        await _emailService.provisionLinkedAccount(
          jid: _jid,
          accountId: profile.id,
        );
      } on EmailProvisioningException catch (error) {
        if (error.shouldWipeCredentials) {
          try {
            await _emailService.unlinkAccount(
              jid: _jid,
              accountId: profile.id,
            );
          } on Exception catch (cleanupError, stackTrace) {
            final String errorType = cleanupError.runtimeType.toString();
            _log.warning(
              '$_unlinkFailureLogMessage ($errorType)',
              null,
              stackTrace,
            );
          }
        }
        if (shouldSetPrimary && previousPrimary != null) {
          try {
            await _emailService.setPrimaryLinkedAccount(
              jid: _jid,
              accountId: previousPrimary.id,
            );
          } on Exception catch (fallbackError, stackTrace) {
            final String errorType = fallbackError.runtimeType.toString();
            _log.warning(
              '$_setPrimaryFailureLogMessage ($errorType)',
              null,
              stackTrace,
            );
          }
        }
        final List<EmailAccountProfile> accounts =
            await _emailService.linkedAccounts(_jid);
        emit(
          state.copyWith(
            status: RequestStatus.success,
            accounts: accounts,
            actionStatus: RequestStatus.failure,
            action: LinkedEmailAccountsAction.link,
            actionAccountId: profile.id,
            actionFailure: LinkedEmailAccountsActionFailure(
              type: LinkedEmailAccountsFailureType.generic,
              message: error.message,
            ),
          ),
        );
        return;
      } on Exception catch (error, stackTrace) {
        final String errorType = error.runtimeType.toString();
        _log.warning(
          '$_provisionFailureLogMessage ($errorType)',
          null,
          stackTrace,
        );
        final List<EmailAccountProfile> accounts =
            await _emailService.linkedAccounts(_jid);
        emit(
          state.copyWith(
            status: RequestStatus.success,
            accounts: accounts,
            actionStatus: RequestStatus.failure,
            action: LinkedEmailAccountsAction.link,
            actionAccountId: profile.id,
            actionFailure: const LinkedEmailAccountsActionFailure(
              type: LinkedEmailAccountsFailureType.generic,
            ),
          ),
        );
        return;
      }
      if (shouldSetPrimary) {
        await _emailService.setPrimaryLinkedAccount(
          jid: _jid,
          accountId: profile.id,
        );
      }
      final List<EmailAccountProfile> accounts =
          await _emailService.linkedAccounts(_jid);
      emit(
        state.copyWith(
          status: RequestStatus.success,
          accounts: accounts,
          actionStatus: RequestStatus.success,
          action: LinkedEmailAccountsAction.link,
          actionAccountId: profile.id,
          clearActionFailure: true,
        ),
      );
    } on EmailAccountLimitException catch (error) {
      emit(
        state.copyWith(
          actionStatus: RequestStatus.failure,
          action: LinkedEmailAccountsAction.link,
          actionFailure: LinkedEmailAccountsActionFailure(
            type: LinkedEmailAccountsFailureType.limitReached,
            limit: error.limit,
          ),
        ),
      );
    } on Exception catch (error, stackTrace) {
      final String errorType = error.runtimeType.toString();
      _log.warning('$_linkFailureLogMessage ($errorType)', null, stackTrace);
      emit(
        state.copyWith(
          actionStatus: RequestStatus.failure,
          action: LinkedEmailAccountsAction.link,
          actionFailure: const LinkedEmailAccountsActionFailure(
            type: LinkedEmailAccountsFailureType.generic,
          ),
        ),
      );
    }
  }

  Future<void> unlinkAccount({required EmailAccountId accountId}) async {
    if (state.actionStatus.isLoading) {
      return;
    }
    emit(
      state.copyWith(
        actionStatus: RequestStatus.loading,
        action: LinkedEmailAccountsAction.unlink,
        actionAccountId: accountId,
        clearActionFailure: true,
      ),
    );
    try {
      await _emailService.unlinkAccount(
        jid: _jid,
        accountId: accountId,
      );
      final List<EmailAccountProfile> accounts =
          await _emailService.linkedAccounts(_jid);
      emit(
        state.copyWith(
          status: RequestStatus.success,
          accounts: accounts,
          actionStatus: RequestStatus.success,
          action: LinkedEmailAccountsAction.unlink,
          actionAccountId: accountId,
          clearActionFailure: true,
        ),
      );
    } on Exception catch (error, stackTrace) {
      final String errorType = error.runtimeType.toString();
      _log.warning('$_unlinkFailureLogMessage ($errorType)', null, stackTrace);
      emit(
        state.copyWith(
          actionStatus: RequestStatus.failure,
          action: LinkedEmailAccountsAction.unlink,
          actionAccountId: accountId,
          actionFailure: const LinkedEmailAccountsActionFailure(
            type: LinkedEmailAccountsFailureType.generic,
          ),
        ),
      );
    }
  }

  Future<void> setPrimaryAccount({required EmailAccountId accountId}) async {
    if (state.actionStatus.isLoading) {
      return;
    }
    emit(
      state.copyWith(
        actionStatus: RequestStatus.loading,
        action: LinkedEmailAccountsAction.setPrimary,
        actionAccountId: accountId,
        clearActionFailure: true,
      ),
    );
    try {
      await _emailService.setPrimaryLinkedAccount(
        jid: _jid,
        accountId: accountId,
      );
      final List<EmailAccountProfile> accounts =
          await _emailService.linkedAccounts(_jid);
      emit(
        state.copyWith(
          status: RequestStatus.success,
          accounts: accounts,
          actionStatus: RequestStatus.success,
          action: LinkedEmailAccountsAction.setPrimary,
          actionAccountId: accountId,
          clearActionFailure: true,
        ),
      );
    } on Exception catch (error, stackTrace) {
      final String errorType = error.runtimeType.toString();
      _log.warning(
          '$_setPrimaryFailureLogMessage ($errorType)', null, stackTrace);
      emit(
        state.copyWith(
          actionStatus: RequestStatus.failure,
          action: LinkedEmailAccountsAction.setPrimary,
          actionAccountId: accountId,
          actionFailure: const LinkedEmailAccountsActionFailure(
            type: LinkedEmailAccountsFailureType.generic,
          ),
        ),
      );
    }
  }

  Future<void> updatePassword({
    required EmailAccountId accountId,
    required String password,
  }) async {
    if (state.actionStatus.isLoading) {
      return;
    }
    emit(
      state.copyWith(
        actionStatus: RequestStatus.loading,
        action: LinkedEmailAccountsAction.updatePassword,
        actionAccountId: accountId,
        clearActionFailure: true,
      ),
    );
    try {
      await _emailService.updateLinkedAccountPassword(
        jid: _jid,
        accountId: accountId,
        password: password,
      );
      final List<EmailAccountProfile> accounts =
          await _emailService.linkedAccounts(_jid);
      emit(
        state.copyWith(
          status: RequestStatus.success,
          accounts: accounts,
          actionStatus: RequestStatus.success,
          action: LinkedEmailAccountsAction.updatePassword,
          actionAccountId: accountId,
          clearActionFailure: true,
        ),
      );
    } on EmailProvisioningException catch (error) {
      emit(
        state.copyWith(
          actionStatus: RequestStatus.failure,
          action: LinkedEmailAccountsAction.updatePassword,
          actionAccountId: accountId,
          actionFailure: LinkedEmailAccountsActionFailure(
            type: LinkedEmailAccountsFailureType.generic,
            message: error.message,
          ),
        ),
      );
    } on Exception catch (error, stackTrace) {
      final String errorType = error.runtimeType.toString();
      _log.warning(
        '$_updatePasswordFailureLogMessage ($errorType)',
        null,
        stackTrace,
      );
      emit(
        state.copyWith(
          actionStatus: RequestStatus.failure,
          action: LinkedEmailAccountsAction.updatePassword,
          actionAccountId: accountId,
          actionFailure: const LinkedEmailAccountsActionFailure(
            type: LinkedEmailAccountsFailureType.generic,
          ),
        ),
      );
    }
  }

  void clearActionStatus() {
    emit(
      state.copyWith(
        actionStatus: RequestStatus.none,
        action: LinkedEmailAccountsAction.none,
        clearActionFailure: true,
        clearActionAccountId: true,
      ),
    );
  }
}
