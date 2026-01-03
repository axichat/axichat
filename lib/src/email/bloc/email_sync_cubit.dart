// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:bloc/bloc.dart';

class EmailSyncCubit extends Cubit<EmailSyncState> {
  EmailSyncCubit({required EmailService emailService})
      : _emailService = emailService,
        super(emailService.syncState) {
    _syncSubscription = _emailService.syncStateStream.listen(emit);
  }

  final EmailService _emailService;
  late final StreamSubscription<EmailSyncState> _syncSubscription;

  @override
  Future<void> close() async {
    await _syncSubscription.cancel();
    await super.close();
  }
}
