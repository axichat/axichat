part of 'contacts_cubit.dart';

final class ContactsViewCriteria extends Equatable {
  const ContactsViewCriteria({
    this.query = '',
    this.sort = SearchSortOrder.newestFirst,
    this.filterId,
  });

  final String query;
  final SearchSortOrder sort;
  final SearchFilterId? filterId;

  @override
  List<Object?> get props => [query, sort, filterId];
}

enum ContactActionType {
  addManual,
  removeManual,
  addEmail,
  removeEmail,
  favorite,
  unfavorite,
  rename,
  resetRename,
  setFolderRule,
  clearFolderRule,
}

enum ContactFailureReason {
  invalidAddress,
  unavailable,
  addFailed,
  removeFailed,
  updateFailed,
}

sealed class ContactActionState extends Equatable {
  const ContactActionState();
}

final class ContactActionIdle extends ContactActionState {
  const ContactActionIdle();

  @override
  List<Object?> get props => const [];
}

final class ContactActionLoading extends ContactActionState {
  const ContactActionLoading({
    required this.action,
    required this.address,
    this.collectionId,
  });

  final ContactActionType action;
  final String address;
  final String? collectionId;

  @override
  List<Object?> get props => [action, address, collectionId];
}

final class ContactActionSuccess extends ContactActionState {
  const ContactActionSuccess({
    required this.action,
    required this.address,
    this.collectionId,
  });

  final ContactActionType action;
  final String address;
  final String? collectionId;

  @override
  List<Object?> get props => [action, address, collectionId];
}

final class ContactActionFailure extends ContactActionState {
  const ContactActionFailure({
    required this.action,
    required this.address,
    required this.reason,
    this.collectionId,
  });

  final ContactActionType action;
  final String address;
  final ContactFailureReason reason;
  final String? collectionId;

  @override
  List<Object?> get props => [action, address, reason, collectionId];
}

final class ContactsState extends Equatable {
  const ContactsState({
    this.items,
    this.visibleItems,
    this.criteria = const ContactsViewCriteria(),
    this.actionState = const ContactActionIdle(),
    this.actionId = 0,
  });

  final List<ContactDirectoryEntry>? items;
  final List<ContactDirectoryEntry>? visibleItems;
  final ContactsViewCriteria criteria;
  final ContactActionState actionState;
  final int actionId;

  ContactsState copyWith({
    List<ContactDirectoryEntry>? items,
    List<ContactDirectoryEntry>? visibleItems,
    ContactsViewCriteria? criteria,
    ContactActionState? actionState,
    int? actionId,
  }) {
    final nextActionState = actionState ?? this.actionState;
    return ContactsState(
      items: items ?? this.items,
      visibleItems: visibleItems ?? this.visibleItems,
      criteria: criteria ?? this.criteria,
      actionState: nextActionState,
      actionId:
          actionId ??
          (nextActionState is ContactActionFailure &&
                  nextActionState != this.actionState
              ? this.actionId + 1
              : this.actionId),
    );
  }

  @override
  List<Object?> get props => [
    items,
    visibleItems,
    criteria,
    actionState,
    actionId,
  ];
}
