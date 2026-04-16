part of 'contacts_cubit.dart';

final class ContactsViewCriteria extends Equatable {
  const ContactsViewCriteria({
    this.query = '',
    this.sort = SearchSortOrder.newestFirst,
  });

  final String query;
  final SearchSortOrder sort;

  @override
  List<Object?> get props => [query, sort];
}

enum ContactActionType { addEmail, removeEmail }

enum ContactFailureReason {
  invalidAddress,
  unavailable,
  addFailed,
  removeFailed,
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
  const ContactActionLoading({required this.action, required this.address});

  final ContactActionType action;
  final String address;

  @override
  List<Object?> get props => [action, address];
}

final class ContactActionSuccess extends ContactActionState {
  const ContactActionSuccess({required this.action, required this.address});

  final ContactActionType action;
  final String address;

  @override
  List<Object?> get props => [action, address];
}

final class ContactActionFailure extends ContactActionState {
  const ContactActionFailure({
    required this.action,
    required this.address,
    required this.reason,
  });

  final ContactActionType action;
  final String address;
  final ContactFailureReason reason;

  @override
  List<Object?> get props => [action, address, reason];
}

final class ContactsState extends Equatable {
  const ContactsState({
    this.items,
    this.visibleItems,
    this.criteria = const ContactsViewCriteria(),
    this.actionState = const ContactActionIdle(),
  });

  final List<ContactDirectoryEntry>? items;
  final List<ContactDirectoryEntry>? visibleItems;
  final ContactsViewCriteria criteria;
  final ContactActionState actionState;

  ContactsState copyWith({
    List<ContactDirectoryEntry>? items,
    List<ContactDirectoryEntry>? visibleItems,
    ContactsViewCriteria? criteria,
    ContactActionState? actionState,
  }) {
    return ContactsState(
      items: items ?? this.items,
      visibleItems: visibleItems ?? this.visibleItems,
      criteria: criteria ?? this.criteria,
      actionState: actionState ?? this.actionState,
    );
  }

  @override
  List<Object?> get props => [items, visibleItems, criteria, actionState];
}
