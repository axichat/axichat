// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/update/update_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'update_state.dart';

class UpdateCubit extends Cubit<UpdateState> {
  UpdateCubit({
    required UpdateService updateService,
    DateTime Function()? nowProvider,
    Duration? dismissSnoozeDuration,
    Duration? flexibleUpdatePollInterval,
    int? flexibleUpdatePollAttempts,
    Duration? automaticRefreshInterval,
  }) : _updateService = updateService,
       _nowProvider = nowProvider ?? DateTime.now,
       _dismissSnoozeDuration =
           dismissSnoozeDuration ?? const Duration(hours: 12),
       _flexibleUpdatePollInterval =
           flexibleUpdatePollInterval ?? const Duration(seconds: 15),
       _flexibleUpdatePollAttempts = flexibleUpdatePollAttempts ?? 12,
       _automaticRefreshInterval =
           automaticRefreshInterval ?? const Duration(minutes: 5),
       super(const UpdateState());

  final UpdateService _updateService;
  final DateTime Function() _nowProvider;
  final Duration _dismissSnoozeDuration;
  final Duration _flexibleUpdatePollInterval;
  final int _flexibleUpdatePollAttempts;
  final Duration _automaticRefreshInterval;

  Timer? _flexibleUpdatePollTimer;
  Future<void>? _ongoingFlexibleUpdatePoll;
  Future<void>? _refreshInFlight;
  DateTime? _lastRefreshStartedAt;

  Future<void> initialize() => refresh(force: true);

  Future<void> refresh({bool force = false}) async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    if (!force && _automaticRefreshRecentlyStarted) return;
    final refresh = _runRefresh();
    _refreshInFlight = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    }
  }

  bool get _automaticRefreshRecentlyStarted {
    final lastStartedAt = _lastRefreshStartedAt;
    return lastStartedAt != null &&
        _nowProvider().difference(lastStartedAt) < _automaticRefreshInterval;
  }

  Future<void> _runRefresh() async {
    _lastRefreshStartedAt = _nowProvider();
    emit(state.copyWith(isChecking: true, clearActionFailure: true));
    final result = await _updateService.checkForUpdates();
    final currentOffer = result.currentOffer;
    final dismissedOfferId = _dismissedOfferIdFor(currentOffer);
    final dismissedAt = dismissedOfferId == null ? null : state.dismissedAt;
    emit(
      state.copyWith(
        channel: result.channel,
        shorebirdStatus: result.shorebirdStatus,
        installedVersion: result.installedVersion,
        installedBuild: result.installedBuild,
        currentOffer: currentOffer,
        dismissedOfferId: dismissedOfferId,
        dismissedAt: dismissedAt,
        isChecking: false,
        clearDismissedOfferId: dismissedOfferId == null,
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
        dismissedAt: _nowProvider(),
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
      if (offer.kind == UpdateOfferKind.playFlexible && failure == null) {
        _startFlexibleUpdateMonitor();
      }
      emit(
        state.copyWith(
          dismissedOfferId: offer.id,
          dismissedAt: _nowProvider(),
          isPerformingAction: false,
          clearActionFailure: true,
        ),
      );
      return true;
    }
    emit(state.copyWith(isPerformingAction: false, actionFailure: failure));
    return false;
  }

  @override
  Future<void> close() async {
    _flexibleUpdatePollTimer?.cancel();
    _flexibleUpdatePollTimer = null;
    final ongoingFlexibleUpdatePoll = _ongoingFlexibleUpdatePoll;
    if (ongoingFlexibleUpdatePoll != null) {
      await ongoingFlexibleUpdatePoll;
    }
    final refreshInFlight = _refreshInFlight;
    if (refreshInFlight != null) {
      await refreshInFlight;
    }
    _updateService.dispose();
    return super.close();
  }

  String? _dismissedOfferIdFor(UpdateOffer? currentOffer) {
    final dismissedOfferId = state.dismissedOfferId;
    final dismissedAt = state.dismissedAt;
    if (currentOffer == null ||
        dismissedOfferId == null ||
        dismissedAt == null ||
        currentOffer.id != dismissedOfferId) {
      return null;
    }
    final dismissedAge = _nowProvider().difference(dismissedAt);
    if (dismissedAge >= _dismissSnoozeDuration) {
      return null;
    }
    return dismissedOfferId;
  }

  void _startFlexibleUpdateMonitor() {
    _flexibleUpdatePollTimer?.cancel();
    _scheduleFlexibleUpdatePoll(_flexibleUpdatePollAttempts);
  }

  void _scheduleFlexibleUpdatePoll(int remainingAttempts) {
    if (remainingAttempts <= 0) {
      _flexibleUpdatePollTimer = null;
      return;
    }
    _flexibleUpdatePollTimer = Timer(_flexibleUpdatePollInterval, () {
      _ongoingFlexibleUpdatePoll = _runFlexibleUpdatePoll(
        remainingAttempts: remainingAttempts,
      );
    });
  }

  Future<void> _runFlexibleUpdatePoll({required int remainingAttempts}) async {
    await refresh(force: true);
    if (state.currentOffer?.kind == UpdateOfferKind.playCompleteFlexible) {
      _flexibleUpdatePollTimer = null;
      _ongoingFlexibleUpdatePoll = null;
      return;
    }
    _scheduleFlexibleUpdatePoll(remainingAttempts - 1);
    _ongoingFlexibleUpdatePoll = null;
  }
}
