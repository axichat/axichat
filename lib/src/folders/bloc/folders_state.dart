part of 'folders_cubit.dart';

enum FoldersActionType { createFolder, removeMembership }

enum FoldersFailureReason { invalidName, createFailed, removeFailed }

sealed class FoldersActionState extends Equatable {
  const FoldersActionState();
}

final class FoldersActionIdle extends FoldersActionState {
  const FoldersActionIdle();

  @override
  List<Object?> get props => const [];
}

final class FoldersActionLoading extends FoldersActionState {
  const FoldersActionLoading({
    required this.action,
    this.collectionId,
    this.chatJid,
    this.messageReferenceId,
  });

  final FoldersActionType action;
  final String? collectionId;
  final String? chatJid;
  final String? messageReferenceId;

  @override
  List<Object?> get props => [
    action,
    collectionId,
    chatJid,
    messageReferenceId,
  ];
}

final class FoldersActionSuccess extends FoldersActionState {
  const FoldersActionSuccess({
    required this.action,
    this.collectionId,
    this.chatJid,
    this.messageReferenceId,
  });

  final FoldersActionType action;
  final String? collectionId;
  final String? chatJid;
  final String? messageReferenceId;

  @override
  List<Object?> get props => [
    action,
    collectionId,
    chatJid,
    messageReferenceId,
  ];
}

final class FoldersActionFailure extends FoldersActionState {
  const FoldersActionFailure({
    required this.action,
    required this.reason,
    this.collectionId,
    this.chatJid,
    this.messageReferenceId,
    this.nameFailure,
  });

  final FoldersActionType action;
  final FoldersFailureReason reason;
  final String? collectionId;
  final String? chatJid;
  final String? messageReferenceId;
  final MessageCollectionNameFailure? nameFailure;

  @override
  List<Object?> get props => [
    action,
    reason,
    collectionId,
    chatJid,
    messageReferenceId,
    nameFailure,
  ];
}

class FoldersState extends Equatable {
  const FoldersState({
    required this.collectionId,
    required this.chatJid,
    required this.collections,
    required this.memberships,
    required this.contactFolderRules,
    required this.unreadChats,
    required this.items,
    required this.visibleItems,
    this.query = '',
    this.sortOrder = SearchSortOrder.newestFirst,
    this.actionState = const FoldersActionIdle(),
    this.loadingActions = const <FoldersActionLoading>{},
    this.actionId = 0,
  });

  final String collectionId;
  final String? chatJid;
  final List<MessageCollectionEntry>? collections;
  final List<MessageCollectionMembershipEntry>? memberships;
  final Map<String, String> contactFolderRules;
  final List<Chat>? unreadChats;
  final List<FolderMessageItem>? items;
  final List<FolderMessageItem>? visibleItems;
  final String query;
  final SearchSortOrder sortOrder;
  final FoldersActionState actionState;
  final Set<FoldersActionLoading> loadingActions;
  final int actionId;

  List<MessageCollectionEntry> get customCollections {
    final entries = collections;
    if (entries == null) {
      return const <MessageCollectionEntry>[];
    }
    return entries
        .where((collection) => collection.isCustom && collection.active)
        .toList(growable: false);
  }

  List<MessageCollectionEntry> get activeCollections {
    final entries = collections;
    if (entries == null) {
      return const <MessageCollectionEntry>[];
    }
    return entries
        .where((collection) => collection.active)
        .toList(growable: false);
  }

  Set<String> explicitActiveCollectionIdsForMessage({
    required Chat chat,
    required Message message,
  }) {
    final reference = message.collectionReference(
      isGroupChat: chat.type == ChatType.groupChat,
    );
    if (reference == null) {
      return const <String>{};
    }
    final entries = memberships;
    if (entries == null) {
      return const <String>{};
    }
    final aliases = message.referenceIds;
    final chatJid = chat.jid.trim();
    return entries
        .where(
          (entry) =>
              entry.active &&
              entry.chatJid.trim() == chatJid &&
              (entry.messageReferenceId == reference.value ||
                  aliases.contains(entry.messageReferenceId)),
        )
        .map((entry) => entry.collectionId)
        .toSet();
  }

  Set<String> ruleDerivedCollectionIdsForMessage({
    required Chat chat,
    required Message message,
  }) {
    if (chat.type == ChatType.groupChat ||
        message.collectionReference(isGroupChat: false) == null) {
      return const <String>{};
    }
    final activeCollectionIds = activeCollections
        .map((collection) => collection.id)
        .toSet();
    if (activeCollectionIds.isEmpty) {
      return const <String>{};
    }
    final collectionIds = <String>{};
    for (final address in <String?>[
      chat.jid,
      chat.emailAddress,
      chat.remoteJid,
      chat.emailFromAddress,
    ]) {
      final key = contactDirectoryAddressKey(address);
      if (key.isEmpty) {
        continue;
      }
      final collectionId = contactFolderRules[key]?.trim();
      if (collectionId != null &&
          collectionId.isNotEmpty &&
          activeCollectionIds.contains(collectionId)) {
        collectionIds.add(collectionId);
      }
    }
    return collectionIds;
  }

  FoldersState copyWith({
    String? collectionId,
    String? chatJid,
    List<MessageCollectionEntry>? collections,
    List<MessageCollectionMembershipEntry>? memberships,
    Map<String, String>? contactFolderRules,
    List<Chat>? unreadChats,
    List<FolderMessageItem>? items,
    List<FolderMessageItem>? visibleItems,
    String? query,
    SearchSortOrder? sortOrder,
    FoldersActionState? actionState,
    Set<FoldersActionLoading>? loadingActions,
    int? actionId,
  }) {
    final nextActionState = actionState ?? this.actionState;
    return FoldersState(
      collectionId: collectionId ?? this.collectionId,
      chatJid: chatJid ?? this.chatJid,
      collections: collections ?? this.collections,
      memberships: memberships ?? this.memberships,
      contactFolderRules: contactFolderRules ?? this.contactFolderRules,
      unreadChats: unreadChats ?? this.unreadChats,
      items: items ?? this.items,
      visibleItems: visibleItems ?? this.visibleItems,
      query: query ?? this.query,
      sortOrder: sortOrder ?? this.sortOrder,
      actionState: nextActionState,
      loadingActions: loadingActions ?? this.loadingActions,
      actionId:
          actionId ??
          (nextActionState is FoldersActionFailure &&
                  nextActionState != this.actionState
              ? this.actionId + 1
              : this.actionId),
    );
  }

  @override
  List<Object?> get props => [
    collectionId,
    chatJid,
    collections,
    memberships,
    contactFolderRules,
    unreadChats,
    items,
    visibleItems,
    query,
    sortOrder,
    actionState,
    loadingActions,
    actionId,
  ];
}

extension FoldersStateActionLoading on FoldersState {
  bool isFolderActionLoading(FoldersActionLoading action) {
    return loadingActions.contains(action);
  }

  FoldersState markFolderActionLoading(FoldersActionLoading action) {
    if (loadingActions.contains(action)) return this;
    return copyWith(
      actionState: action,
      loadingActions: Set<FoldersActionLoading>.unmodifiable({
        ...loadingActions,
        action,
      }),
    );
  }

  FoldersState clearFolderActionLoading(FoldersActionLoading action) {
    if (!loadingActions.contains(action)) return this;
    return copyWith(
      loadingActions: Set<FoldersActionLoading>.unmodifiable(
        Set<FoldersActionLoading>.from(loadingActions)..remove(action),
      ),
    );
  }
}
