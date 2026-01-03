// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'linked_email_accounts_cubit.dart';

enum LinkedEmailAccountsAction {
  none,
  link,
  unlink,
  setPrimary,
  updatePassword,
}

extension LinkedEmailAccountsActionFlags on LinkedEmailAccountsAction {
  bool get isNone => this == LinkedEmailAccountsAction.none;

  bool get isLink => this == LinkedEmailAccountsAction.link;

  bool get isUnlink => this == LinkedEmailAccountsAction.unlink;

  bool get isSetPrimary => this == LinkedEmailAccountsAction.setPrimary;

  bool get isUpdatePassword => this == LinkedEmailAccountsAction.updatePassword;
}

enum LinkedEmailAccountsFailureType {
  limitReached,
  unsupported,
  generic,
}

extension LinkedEmailAccountsFailureTypeFlags
    on LinkedEmailAccountsFailureType {
  bool get isLimitReached =>
      this == LinkedEmailAccountsFailureType.limitReached;

  bool get isUnsupported => this == LinkedEmailAccountsFailureType.unsupported;

  bool get isGeneric => this == LinkedEmailAccountsFailureType.generic;
}

final class LinkedEmailAccountsActionFailure extends Equatable {
  const LinkedEmailAccountsActionFailure({
    required this.type,
    this.limit,
    this.message,
  });

  final LinkedEmailAccountsFailureType type;
  final int? limit;
  final String? message;

  @override
  List<Object?> get props => [type, limit, message];
}

final class LinkedEmailAccountsState extends Equatable {
  const LinkedEmailAccountsState({
    required this.supportsMultipleAccounts,
    required this.maxAccounts,
    required this.extraAccountLimit,
    this.status = RequestStatus.none,
    this.actionStatus = RequestStatus.none,
    this.action = LinkedEmailAccountsAction.none,
    this.accounts = const <EmailAccountProfile>[],
    this.actionAccountId,
    this.actionFailure,
  });

  final RequestStatus status;
  final RequestStatus actionStatus;
  final LinkedEmailAccountsAction action;
  final List<EmailAccountProfile> accounts;
  final EmailAccountId? actionAccountId;
  final LinkedEmailAccountsActionFailure? actionFailure;
  final bool supportsMultipleAccounts;
  final int maxAccounts;
  final int extraAccountLimit;

  bool get canAddAccount => accounts.length < maxAccounts;

  LinkedEmailAccountsState copyWith({
    RequestStatus? status,
    RequestStatus? actionStatus,
    LinkedEmailAccountsAction? action,
    List<EmailAccountProfile>? accounts,
    EmailAccountId? actionAccountId,
    LinkedEmailAccountsActionFailure? actionFailure,
    bool clearActionFailure = false,
    bool clearActionAccountId = false,
    bool? supportsMultipleAccounts,
    int? maxAccounts,
    int? extraAccountLimit,
  }) {
    final LinkedEmailAccountsActionFailure? resolvedActionFailure =
        clearActionFailure ? null : actionFailure ?? this.actionFailure;
    final EmailAccountId? resolvedActionAccountId =
        clearActionAccountId ? null : actionAccountId ?? this.actionAccountId;
    return LinkedEmailAccountsState(
      status: status ?? this.status,
      actionStatus: actionStatus ?? this.actionStatus,
      action: action ?? this.action,
      accounts: accounts ?? this.accounts,
      actionAccountId: resolvedActionAccountId,
      actionFailure: resolvedActionFailure,
      supportsMultipleAccounts:
          supportsMultipleAccounts ?? this.supportsMultipleAccounts,
      maxAccounts: maxAccounts ?? this.maxAccounts,
      extraAccountLimit: extraAccountLimit ?? this.extraAccountLimit,
    );
  }

  @override
  List<Object?> get props => [
        status,
        actionStatus,
        action,
        accounts,
        actionAccountId,
        actionFailure,
        supportsMultipleAccounts,
        maxAccounts,
        extraAccountLimit,
      ];
}
