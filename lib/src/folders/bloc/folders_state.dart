part of 'folders_cubit.dart';

class FoldersState extends Equatable {
  const FoldersState({
    required this.folder,
    required this.chatJid,
    required this.items,
    required this.visibleItems,
    this.query = '',
    this.sortOrder = SearchSortOrder.newestFirst,
  });

  final FolderCollection folder;
  final String? chatJid;
  final List<FolderMessageItem>? items;
  final List<FolderMessageItem>? visibleItems;
  final String query;
  final SearchSortOrder sortOrder;

  FoldersState copyWith({
    FolderCollection? folder,
    String? chatJid,
    List<FolderMessageItem>? items,
    List<FolderMessageItem>? visibleItems,
    String? query,
    SearchSortOrder? sortOrder,
  }) {
    return FoldersState(
      folder: folder ?? this.folder,
      chatJid: chatJid ?? this.chatJid,
      items: items ?? this.items,
      visibleItems: visibleItems ?? this.visibleItems,
      query: query ?? this.query,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [
    folder,
    chatJid,
    items,
    visibleItems,
    query,
    sortOrder,
  ];
}
