// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/update/update_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'update_state.dart';

class UpdateCubit extends Cubit<UpdateState> {
  UpdateCubit({required UpdateService updateService})
    : _updateService = updateService,
      super(const UpdateState());

  final UpdateService _updateService;

  Future<void> initialize() => refresh(force: true);

  Future<void> refresh({bool force = false}) async {
    if (!force && state.isChecking) {
      return;
    }
    emit(state.copyWith(isChecking: true, clearActionFailure: true));
    final result = await _updateService.checkForUpdates();
    final currentOffer = result.currentOffer;
    final dismissedOfferId =
        currentOffer != null && currentOffer.id == state.dismissedOfferId
        ? state.dismissedOfferId
        : null;
    emit(
      state.copyWith(
        channel: result.channel,
        shorebirdStatus: result.shorebirdStatus,
        installedVersion: result.installedVersion,
        installedBuild: result.installedBuild,
        currentOffer: currentOffer,
        dismissedOfferId: dismissedOfferId,
        isChecking: false,
        clearActionFailure: true,
      ),
    );
  }

  void dismissCurrentOffer() {
    final currentOffer = state.currentOffer;
    if (currentOffer == null) {
      return;
    }
    emit(
      state.copyWith(
        dismissedOfferId: currentOffer.id,
        clearActionFailure: true,
      ),
    );
  }

  Future<bool> startUpdate() async {
    final offer = state.pendingOffer;
    if (offer == null || offer.kind == UpdateOfferKind.shorebirdRestart) {
      dismissCurrentOffer();
      return true;
    }
    emit(state.copyWith(isPerformingAction: true, clearActionFailure: true));
    final failure = await _updateService.startUpdate(offer);
    if (failure == null || failure == UpdateActionFailure.userDeclined) {
      emit(
        state.copyWith(
          dismissedOfferId: offer.id,
          isPerformingAction: false,
          clearActionFailure: true,
        ),
      );
      await refresh(force: true);
      return true;
    }
    emit(state.copyWith(isPerformingAction: false, actionFailure: failure));
    return false;
  }

  @override
  Future<void> close() {
    _updateService.dispose();
    return super.close();
  }
}
