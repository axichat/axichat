part of 'update_cubit.dart';

final class UpdateState extends Equatable {
  const UpdateState({
    this.channel = UpdateChannel.none,
    this.shorebirdStatus = ShorebirdUpdateStatus.unavailable,
    this.installedVersion,
    this.installedBuild,
    this.currentOffer,
    this.dismissedOfferId,
    this.dismissedAt,
    this.isChecking = false,
    this.isPerformingAction = false,
    this.actionFailure,
  });

  final UpdateChannel channel;
  final ShorebirdUpdateStatus shorebirdStatus;
  final String? installedVersion;
  final int? installedBuild;
  final UpdateOffer? currentOffer;
  final String? dismissedOfferId;
  final DateTime? dismissedAt;
  final bool isChecking;
  final bool isPerformingAction;
  final UpdateActionFailure? actionFailure;

  UpdateOffer? get pendingOffer {
    final currentOffer = this.currentOffer;
    if (currentOffer == null) {
      return null;
    }
    if (dismissedOfferId == currentOffer.id) {
      return null;
    }
    return currentOffer;
  }

  bool get hasUpdate => currentOffer != null;

  UpdateState copyWith({
    UpdateChannel? channel,
    ShorebirdUpdateStatus? shorebirdStatus,
    String? installedVersion,
    int? installedBuild,
    UpdateOffer? currentOffer,
    String? dismissedOfferId,
    DateTime? dismissedAt,
    bool? isChecking,
    bool? isPerformingAction,
    UpdateActionFailure? actionFailure,
    bool clearInstalledVersion = false,
    bool clearInstalledBuild = false,
    bool clearCurrentOffer = false,
    bool clearDismissedOfferId = false,
    bool clearActionFailure = false,
  }) => UpdateState(
    channel: channel ?? this.channel,
    shorebirdStatus: shorebirdStatus ?? this.shorebirdStatus,
    installedVersion: clearInstalledVersion
        ? null
        : installedVersion ?? this.installedVersion,
    installedBuild: clearInstalledBuild
        ? null
        : installedBuild ?? this.installedBuild,
    currentOffer: clearCurrentOffer ? null : currentOffer ?? this.currentOffer,
    dismissedOfferId: clearDismissedOfferId
        ? null
        : dismissedOfferId ?? this.dismissedOfferId,
    dismissedAt: clearDismissedOfferId ? null : dismissedAt ?? this.dismissedAt,
    isChecking: isChecking ?? this.isChecking,
    isPerformingAction: isPerformingAction ?? this.isPerformingAction,
    actionFailure: clearActionFailure
        ? null
        : actionFailure ?? this.actionFailure,
  );

  @override
  List<Object?> get props => [
    channel,
    shorebirdStatus,
    installedVersion,
    installedBuild,
    currentOffer?.id,
    currentOffer?.kind,
    currentOffer?.channel,
    currentOffer?.availableVersion,
    currentOffer?.availableBuild,
    currentOffer?.storeUrl,
    dismissedOfferId,
    dismissedAt,
    isChecking,
    isPerformingAction,
    actionFailure,
  ];
}
