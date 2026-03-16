// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

enum MucStatusCode {
  selfPresence('110'),
  nickChange('303'),
  roomCreated('201'),
  nickAssigned('210'),
  configurationChanged('104'),
  banned('301'),
  kicked('307'),
  removedByAffiliationChange('321'),
  removedByMembersOnlyChange('322'),
  roomShutdown('332');

  const MucStatusCode(this.code);

  final String code;
}

enum MucJoinErrorCondition {
  registrationRequired('registration-required'),
  forbidden('forbidden'),
  notAuthorized('not-authorized'),
  itemNotFound('item-not-found'),
  serviceUnavailable('service-unavailable'),
  other('');

  const MucJoinErrorCondition(this.xmlValue);

  final String xmlValue;

  bool get blocksAutoRejoin => switch (this) {
    MucJoinErrorCondition.registrationRequired ||
    MucJoinErrorCondition.forbidden ||
    MucJoinErrorCondition.notAuthorized ||
    MucJoinErrorCondition.itemNotFound => true,
    _ => false,
  };

  static MucJoinErrorCondition? fromString(String? value) => switch (value) {
    'registration-required' => registrationRequired,
    'forbidden' => forbidden,
    'not-authorized' => notAuthorized,
    'item-not-found' => itemNotFound,
    'service-unavailable' => serviceUnavailable,
    null || '' => null,
    _ => other,
  };
}
