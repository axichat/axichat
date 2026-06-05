part of 'home_bloc.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

final class HomeActiveTabChanged extends HomeEvent {
  const HomeActiveTabChanged(this.tab);

  final HomeTab? tab;

  @override
  List<Object?> get props => [tab];
}

final class HomeSearchVisibilityChanged extends HomeEvent {
  const HomeSearchVisibilityChanged(this.active);

  final bool active;

  @override
  List<Object?> get props => [active];
}

final class HomeSearchToggled extends HomeEvent {
  const HomeSearchToggled();
}

final class HomeSearchQueryChanged extends HomeEvent {
  const HomeSearchQueryChanged(this.value, {this.tab, this.slot});

  final String value;
  final HomeTab? tab;
  final HomeSearchSlot? slot;

  @override
  List<Object?> get props => [value, tab, slot];
}

final class HomeSearchSortChanged extends HomeEvent {
  const HomeSearchSortChanged(this.sort, {this.tab, this.slot});

  final SearchSortOrder sort;
  final HomeTab? tab;
  final HomeSearchSlot? slot;

  @override
  List<Object?> get props => [sort, tab, slot];
}

final class HomeSearchFilterChanged extends HomeEvent {
  const HomeSearchFilterChanged(this.filterId, {this.tab, this.slot});

  final SearchFilterId? filterId;
  final HomeTab? tab;
  final HomeSearchSlot? slot;

  @override
  List<Object?> get props => [filterId, tab, slot];
}

final class HomeRefreshRequested extends HomeEvent {
  const HomeRefreshRequested();
}

final class HomeRefreshStatusCleared extends HomeEvent {
  const HomeRefreshStatusCleared();
}

final class HomeEmailServiceChanged extends HomeEvent {
  const HomeEmailServiceChanged(this.emailService);

  final EmailService? emailService;

  @override
  List<Object?> get props => [emailService];
}

final class _HomeEmailUnreadRefreshRequested extends HomeEvent {
  const _HomeEmailUnreadRefreshRequested();
}
